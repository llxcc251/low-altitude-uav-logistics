import json
import random
import re
import sys
import time
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parent
DATA_DIR = ROOT / "data"
TEAM_DIR = ROOT / "team_python"
if str(TEAM_DIR) not in sys.path:
    sys.path.insert(0, str(TEAM_DIR))

from config import Config  # noqa: E402
from genetic_algorithm import genetic_algorithm  # noqa: E402
from load_data import load_data  # noqa: E402
from random_search import random_search  # noqa: E402


RESULTS_FILE = DATA_DIR / "results.json"
HANDDRAWN_MAP_FILE = ROOT / "generated_elevation" / "uav_network_map.html"
SOLVER_SEED = 42
RANDOM_TRIALS = 500


def read_json(name):
    with (DATA_DIR / name).open("r", encoding="utf-8") as f:
        return json.load(f)


def build_config():
    cfg = Config()
    orders = read_json("orders.json")
    drone = read_json("drone_params.json")["drone"]
    cfg.n_drones = int(orders.get("drone_count", cfg.n_drones))
    cfg.W_max = float(drone.get("max_payload_kg", cfg.W_max))
    cfg.v_cruise = float(drone.get("cruise_speed_ms", cfg.v_cruise))
    cfg.E_max = float(drone.get("battery_capacity_wh", cfg.E_max))
    cfg.enable_cost = float(drone.get("enable_cost", cfg.enable_cost))
    return cfg


def reset_solver_seed(seed=SOLVER_SEED):
    random.seed(seed)
    np.random.seed(seed)


def run_genetic_with_warmup(data, cfg, seed=SOLVER_SEED):
    """Reproduce run_all: seed, random-search warmup, then GA."""
    reset_solver_seed(seed)
    random_search(data, cfg, RANDOM_TRIALS)
    return genetic_algorithm(data, cfg)


def node_map(data):
    return {n.id: n for n in data.nodes}


def order_map(data):
    return {o.id: o for o in data.orders}


def point(node):
    p = {"x": float(node.x), "y": float(node.y)}
    if getattr(node, "lat", None) is not None and getattr(node, "lon", None) is not None:
        p["lat"] = float(node.lat)
        p["lon"] = float(node.lon)
    return p


def matrix_distance(data, from_node, to_node):
    try:
        fi = data.node_ids.index(from_node.id)
        ti = data.node_ids.index(to_node.id)
        return float(data.dist[fi, ti])
    except Exception:
        dx = float(from_node.x) - float(to_node.x)
        dy = float(from_node.y) - float(to_node.y)
        return float((dx * dx + dy * dy) ** 0.5)


def _downsample(points, max_points=90):
    if len(points) <= max_points:
        return points
    step = (len(points) - 1) / (max_points - 1)
    return [points[round(i * step)] for i in range(max_points)]


def load_corridor_paths(data):
    if not HANDDRAWN_MAP_FILE.exists():
        return {}

    html = HANDDRAWN_MAP_FILE.read_text(encoding="utf-8")
    match = re.search(r"var\s+corridors\s*=\s*(\[.*?\]);\s*var\s+canvas", html, re.S)
    if not match:
        return {}
    raw = json.loads(match.group(1))

    nodes = node_map(data)
    samples = []
    for item in raw:
        path = item.get("path_latlon") or []
        if not path or item.get("from") not in nodes or item.get("to") not in nodes:
            continue
        samples.append((path[0][0], path[0][1], nodes[item["from"]].x, nodes[item["from"]].y))
        samples.append((path[-1][0], path[-1][1], nodes[item["to"]].x, nodes[item["to"]].y))

    if len(samples) < 3:
        return {}

    a = np.array([[lon, lat, 1.0] for lon, lat, _, _ in samples], dtype=float)
    bx = np.array([x for _, _, x, _ in samples], dtype=float)
    by = np.array([y for _, _, _, y in samples], dtype=float)
    coef_x = np.linalg.lstsq(a, bx, rcond=None)[0]
    coef_y = np.linalg.lstsq(a, by, rcond=None)[0]

    def convert(path_latlon, from_node, to_node):
        points = []
        for lon, lat in path_latlon:
            row = np.array([float(lon), float(lat), 1.0])
            points.append({"x": float(row @ coef_x), "y": float(row @ coef_y), "lon": float(lon), "lat": float(lat)})
        if len(points) >= 2:
            start_dx = float(from_node.x) - points[0]["x"]
            start_dy = float(from_node.y) - points[0]["y"]
            end_dx = float(to_node.x) - points[-1]["x"]
            end_dy = float(to_node.y) - points[-1]["y"]
            n = len(points) - 1
            for i, p in enumerate(points):
                ratio = i / n
                p["x"] += start_dx * (1 - ratio) + end_dx * ratio
                p["y"] += start_dy * (1 - ratio) + end_dy * ratio
            points[0] = point(from_node)
            points[-1] = point(to_node)
        return _downsample(points)

    corridors = {}
    for item in raw:
        path = item.get("path_latlon") or []
        if not path:
            continue
        from_id = item.get("from")
        to_id = item.get("to")
        if from_id not in nodes or to_id not in nodes:
            continue
        path_xy = convert(path, nodes[from_id], nodes[to_id])
        distance_m = float(item.get("route_distance_m") or 0)
        corridors[(from_id, to_id)] = {"path": path_xy, "distance_m": distance_m}
        corridors[(to_id, from_id)] = {"path": list(reversed(path_xy)), "distance_m": distance_m}
    return corridors


def segment(from_node, to_node, seg_type, order_id, desc, data, corridors):
    corridor = corridors.get((from_node.id, to_node.id), {})
    path = corridor.get("path") or [point(from_node), point(to_node)]
    distance_m = corridor.get("distance_m") or matrix_distance(data, from_node, to_node)
    return {
        "from_id": from_node.id,
        "to_id": to_node.id,
        "from": point(from_node),
        "to": point(to_node),
        "path": path,
        "distance_m": float(distance_m),
        "type": seg_type,
        "order_id": int(order_id),
        "desc": desc,
    }


def route_to_trip(route, data, cfg, corridors):
    route_get = route.get if isinstance(route, dict) else lambda key, default=None: getattr(route, key, default)
    nodes = node_map(data)
    orders = order_map(data)
    depot = next((n for n in data.depots if n.name == route_get("depot_name", "")), data.depots[0])
    current = depot
    segments = []
    order_ids = []
    weight = 0.0

    details = route_get("details", [])
    for detail in details:
        order_id = int(detail["order_id"])
        order = orders[order_id]
        pickup = nodes[order.pickup_id]
        delivery = nodes[order.delivery_id]
        order_ids.append(order_id)
        weight += float(order.weight)
        segments.append(segment(current, pickup, "empty", order_id, "沿轨道前往取货点", data, corridors))
        segments.append(segment(pickup, delivery, "loaded", order_id, "沿轨道配送", data, corridors))
        current = delivery

    segments.append(segment(current, depot, "empty", 0, "沿轨道返回起降点", data, corridors))
    flight_time_s = sum(item["distance_m"] for item in segments) / cfg.v_cruise
    service_time_s = len(details) * cfg.t_deliver_min * 60.0
    return {
        "depot_id": depot.id,
        "orders": order_ids,
        "segments": segments,
        "time_s": flight_time_s + service_time_s,
        "energy_wh": float(route_get("energy", 0.0)),
        "late_s": float(route_get("late", 0.0)) * 3600.0,
        "weight": weight,
    }


def solution_to_result(sol, data, cfg, method, elapsed):
    corridors = load_corridor_paths(data)
    drones = [
        {
            "id": i + 1,
            "enabled": False,
            "trips": [],
            "total_time_s": 0.0,
            "total_energy_wh": 0.0,
            "total_late_s": 0.0,
        }
        for i in range(cfg.n_drones)
    ]

    for route in sol.routes:
        route_get = route.get if isinstance(route, dict) else lambda key, default=None: getattr(route, key, default)
        idx = int(route_get("drone", 0)) - 1
        if idx < 0 or idx >= len(drones):
            continue
        trip = route_to_trip(route, data, cfg, corridors)
        drones[idx]["enabled"] = True
        drones[idx]["trips"].append(trip)
        drones[idx]["total_time_s"] += trip["time_s"]
        drones[idx]["total_energy_wh"] += trip["energy_wh"]
        drones[idx]["total_late_s"] += trip["late_s"]

    total_time_s = sum(drone["total_time_s"] for drone in drones)

    result = {
        "source": "Team Python algorithm",
        "method": method,
        "status": "ok",
        "runtime_s": elapsed,
        "summary": {
            "total_cost": float(sol.total_cost),
            "enabled_drones": int(sol.n_enabled),
            "total_time_h": total_time_s / 3600.0,
            "total_time_s": total_time_s,
            "total_energy_wh": float(sol.total_energy),
            "total_late_h": float(sol.total_late),
            "total_late_s": float(sol.total_late) * 3600.0,
            "order_count": int(data.n_orders),
            "drone_count": int(cfg.n_drones),
        },
        "drones": drones,
    }
    with RESULTS_FILE.open("w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return result


def solve_team(method="ga"):
    cfg = build_config()
    data = load_data(str(DATA_DIR))
    start = time.time()
    if method in {"random", "random_search"}:
        reset_solver_seed()
        sol = random_search(data, cfg, RANDOM_TRIALS)
        method_name = "随机搜索"
    else:
        sol = run_genetic_with_warmup(data, cfg)
        method_name = "遗传算法"
    elapsed = time.time() - start
    return solution_to_result(sol, data, cfg, method_name, elapsed)


if __name__ == "__main__":
    result = solve_team(sys.argv[1] if len(sys.argv) > 1 else "ga")
    print(f"{result['method']} cost={result['summary']['total_cost']:.2f} runtime={result['runtime_s']:.2f}s")
