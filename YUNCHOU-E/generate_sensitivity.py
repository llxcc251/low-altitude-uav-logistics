import json
import random
import time
from datetime import datetime
from pathlib import Path

from team_solver import ROOT, build_config

TEAM_DIR = ROOT / "team_python"
import sys

if str(TEAM_DIR) not in sys.path:
    sys.path.insert(0, str(TEAM_DIR))

from genetic_algorithm import genetic_algorithm  # noqa: E402
from load_data import load_data  # noqa: E402


OUT_FILE = ROOT / "data" / "sensitivity_results.json"
BASE_SEED = 20260607


def run_case(data, base_cfg, *, drone_count=None, speed_ms=None, capacity_kg=None, seed_offset=0):
    cfg = build_config()
    cfg.n_drones = int(drone_count if drone_count is not None else base_cfg.n_drones)
    cfg.v_cruise = float(speed_ms if speed_ms is not None else base_cfg.v_cruise)
    cfg.W_max = float(capacity_kg if capacity_kg is not None else base_cfg.W_max)
    cfg.t_deliver_min = base_cfg.t_deliver_min
    cfg.t_max_h = base_cfg.t_max_h
    cfg.t_swap_min = base_cfg.t_swap_min
    cfg.enable_cost = base_cfg.enable_cost
    cfg.alpha = base_cfg.alpha
    cfg.gamma = base_cfg.gamma

    random.seed(BASE_SEED + seed_offset)
    start = time.time()
    sol = genetic_algorithm(data, cfg)
    runtime_s = time.time() - start
    return {
        "total_cost": round(float(sol.total_cost), 6),
        "enabled_drones": int(sol.n_enabled),
        "total_time_h": round(float(sol.total_time), 6),
        "total_time_s": round(float(sol.total_time) * 3600.0, 3),
        "total_late_h": round(float(sol.total_late), 6),
        "runtime_s": round(runtime_s, 3),
    }


def main():
    data = load_data(str(ROOT / "data"))
    base_cfg = build_config()
    baseline = {
        "drone_count": int(base_cfg.n_drones),
        "speed_ms": float(base_cfg.v_cruise),
        "capacity_kg": float(base_cfg.W_max),
    }

    cases = {
        "drones": [1, 2, 3, 4, 5, 6, 7, 8],
        "speed": [10, 12, 15, 18, 20],
        "capacity": [1.5, 2.0, 2.5, 3.0, 3.5],
    }

    output = {
        "method": "genetic_algorithm",
        "note": "每个参数点单次重新运行 team_python 遗传算法；除当前变量外，其余参数保持基准值。",
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "baseline": baseline,
        "drones": [],
        "speed": [],
        "capacity": [],
    }

    idx = 0
    for value in cases["drones"]:
        idx += 1
        print(f"[sensitivity] drone_count={value}")
        result = run_case(data, base_cfg, drone_count=value, seed_offset=idx)
        output["drones"].append({"value": value, **result})

    for value in cases["speed"]:
        idx += 1
        print(f"[sensitivity] speed_ms={value}")
        result = run_case(data, base_cfg, speed_ms=value, seed_offset=idx)
        output["speed"].append({"value": value, **result})

    for value in cases["capacity"]:
        idx += 1
        print(f"[sensitivity] capacity_kg={value}")
        result = run_case(data, base_cfg, capacity_kg=value, seed_offset=idx)
        output["capacity"].append({"value": value, **result})

    with OUT_FILE.open("w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"[sensitivity] saved: {OUT_FILE}")


if __name__ == "__main__":
    main()
