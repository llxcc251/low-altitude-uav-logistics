import json
import mimetypes
import os
import shutil
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse

from solve_python import solve_and_export
from team_solver import solve_team


ROOT = Path(__file__).resolve().parent
DATA_DIR = ROOT / "data"
ORDERS_FILE = DATA_DIR / "orders.json"
DRONE_FILE = DATA_DIR / "drone_params.json"
NODES_FILE = DATA_DIR / "campus_nodes.json"
RESULTS_FILE = DATA_DIR / "results.json"
MATLAB_TIMEOUT_SECONDS = 180


def read_json(path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def write_json(path, data):
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def node_name(node_id):
    nodes = read_json(NODES_FILE)["nodes"]
    for node in nodes:
        if node["id"] == node_id:
            return node["name"]
    return node_id


def response_state(include_results=True):
    return {
        "nodes": read_json(NODES_FILE),
        "orders": read_json(ORDERS_FILE),
        "drone_params": read_json(DRONE_FILE),
        "results": read_json(RESULTS_FILE) if include_results and RESULTS_FILE.exists() else None,
    }


def find_matlab_command():
    env_cmd = os.environ.get("MATLAB_CMD")
    if env_cmd:
        return env_cmd
    for name in ("matlab", "matlab.exe"):
        found = shutil.which(name)
        if found:
            return found
    matlab_root = Path("C:/Program Files/MATLAB")
    if matlab_root.exists():
        candidates = sorted(matlab_root.glob("R*/bin/matlab.exe"), reverse=True)
        if candidates:
            return str(candidates[0])
    return None


def solve_with_matlab():
    matlab = find_matlab_command()
    if not matlab:
        raise RuntimeError("MATLAB command was not found. Install MATLAB or set MATLAB_CMD.")

    print(f"[solve] MATLAB start: {matlab}", flush=True)
    batch = (
        "try, "
        "run('main.m'); "
        "catch ME, disp(getReport(ME,'extended')); exit(1); "
        "end; exit(0);"
    )
    completed = subprocess.run(
        [matlab, "-batch", batch],
        cwd=str(ROOT),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=MATLAB_TIMEOUT_SECONDS,
        check=False,
    )
    if completed.returncode != 0:
        tail = "\n".join(completed.stdout.splitlines()[-12:])
        print("[solve] MATLAB failed", flush=True)
        raise RuntimeError("MATLAB solve failed:\n" + tail)
    if not RESULTS_FILE.exists():
        raise RuntimeError("MATLAB finished but results.json was not generated.")
    print("[solve] MATLAB success: results.json loaded", flush=True)
    return read_json(RESULTS_FILE)


def solve_with_matlab_or_python():
    try:
        result = solve_with_matlab()
        result["source"] = "MATLAB main.m"
        return result, None
    except Exception as exc:
        print(f"[solve] MATLAB unavailable, fallback to Python: {exc}", flush=True)
        result = solve_and_export()
        result["source"] = "Python fallback after MATLAB failure"
        return result, str(exc)


def normalize_order(payload, existing_orders):
    next_id = max([int(o["id"]) for o in existing_orders] + [0]) + 1
    pickup_id = str(payload["pickup_id"])
    delivery_id = str(payload["delivery_id"])
    order = {
        "id": int(payload.get("id") or next_id),
        "pickup_id": pickup_id,
        "pickup_name": payload.get("pickup_name") or node_name(pickup_id),
        "delivery_id": delivery_id,
        "delivery_name": payload.get("delivery_name") or node_name(delivery_id),
        "weight_kg": float(payload["weight_kg"]),
        "ready_time_h": float(payload["ready_time_h"]),
        "tw_early_h": float(payload["tw_early_h"]),
        "tw_late_h": float(payload["tw_late_h"]),
    }
    if order["weight_kg"] <= 0:
        raise ValueError("weight_kg must be positive")
    if order["tw_early_h"] > order["tw_late_h"]:
        raise ValueError("tw_early_h cannot exceed tw_late_h")
    return order


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args))

    def send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/state":
            self.send_json(200, response_state())
            return
        if parsed.path == "/api/solve":
            try:
                result = solve_team()
                self.send_json(200, {"ok": True, "results": result, "state": response_state(False)})
            except Exception as exc:
                self.send_json(500, {"ok": False, "error": str(exc)})
            return
        if parsed.path == "/api/solve_team":
            try:
                method = dict([part.split("=", 1) for part in parsed.query.split("&") if "=" in part]).get("method", "ga")
                result = solve_team(method)
                self.send_json(200, {"ok": True, "results": result, "state": response_state(False)})
            except Exception as exc:
                self.send_json(500, {"ok": False, "error": str(exc)})
            return
        if parsed.path == "/api/solve_matlab":
            try:
                result, warning = solve_with_matlab_or_python()
                self.send_json(200, {"ok": True, "results": result, "state": response_state(False), "warning": warning})
            except Exception as exc:
                self.send_json(500, {"ok": False, "error": str(exc)})
            return
        self.serve_static(parsed.path)

    def do_POST(self):
        parsed = urlparse(self.path)
        try:
            payload = self.read_body()
            if parsed.path == "/api/orders":
                data = read_json(ORDERS_FILE)
                data["orders"].append(normalize_order(payload, data["orders"]))
                data["description"] = f"鏍″洯蹇€掕鍗曟暟鎹紙{len(data['orders'])}浠讹紝{data.get('drone_count', 6)}鏋舵棤浜烘満锛屽弻璧烽檷鐐癸級"
                write_json(ORDERS_FILE, data)
                self.send_json(200, {"ok": True, "state": response_state()})
                return
            if parsed.path == "/api/orders/delete":
                order_id = int(payload["id"])
                data = read_json(ORDERS_FILE)
                data["orders"] = [o for o in data["orders"] if int(o["id"]) != order_id]
                data["description"] = f"鏍″洯蹇€掕鍗曟暟鎹紙{len(data['orders'])}浠讹紝{data.get('drone_count', 6)}鏋舵棤浜烘満锛屽弻璧烽檷鐐癸級"
                write_json(ORDERS_FILE, data)
                self.send_json(200, {"ok": True, "state": response_state()})
                return
            if parsed.path == "/api/drone":
                orders = read_json(ORDERS_FILE)
                drone = read_json(DRONE_FILE)
                if "drone_count" in payload:
                    orders["drone_count"] = int(payload["drone_count"])
                    orders["description"] = f"鏍″洯蹇€掕鍗曟暟鎹紙{len(orders.get('orders', []))}浠讹紝{orders['drone_count']}鏋舵棤浜烘満锛屽弻璧烽檷鐐癸級"
                d = drone["drone"]
                mapping = {
                    "max_payload_kg": "max_payload_kg",
                    "battery_capacity_wh": "battery_capacity_wh",
                    "cruise_speed_ms": "cruise_speed_ms",
                    "max_flight_time_min": "max_flight_time_min",
                    "enable_cost": "enable_cost",
                }
                for src, dst in mapping.items():
                    if src in payload:
                        d[dst] = float(payload[src])
                write_json(ORDERS_FILE, orders)
                write_json(DRONE_FILE, drone)
                self.send_json(200, {"ok": True, "state": response_state()})
                return
            if parsed.path == "/api/solve":
                result = solve_team(payload.get("method", "ga"))
                self.send_json(200, {"ok": True, "results": result, "state": response_state(False)})
                return
            if parsed.path == "/api/solve_team":
                result = solve_team(payload.get("method", "ga"))
                self.send_json(200, {"ok": True, "results": result, "state": response_state(False)})
                return
            if parsed.path == "/api/solve_matlab":
                result, warning = solve_with_matlab_or_python()
                self.send_json(200, {"ok": True, "results": result, "state": response_state(False), "warning": warning})
                return
            self.send_json(404, {"ok": False, "error": "unknown api"})
        except Exception as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})

    def serve_static(self, request_path):
        rel = unquote(request_path.lstrip("/")) or "实验数据面板.html"
        path = (ROOT / rel).resolve()
        if ROOT not in path.parents and path != ROOT:
            self.send_error(403)
            return
        if not path.exists() or path.is_dir():
            self.send_error(404)
            return
        ctype = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        if path.suffix.lower() in {".html", ".js", ".json"}:
            ctype += "; charset=utf-8"
        body = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 5173), Handler)
    print("Backend started: http://127.0.0.1:5173/")
    print("Press Ctrl+C to stop.")
    server.serve_forever()


if __name__ == "__main__":
    main()
