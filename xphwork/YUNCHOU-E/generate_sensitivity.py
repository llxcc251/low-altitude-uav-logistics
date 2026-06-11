import json
import random
import time
from datetime import datetime
from pathlib import Path

from team_solver import ROOT, SOLVER_SEED, build_config, run_genetic_with_warmup

TEAM_DIR = ROOT / "team_python"
import sys

if str(TEAM_DIR) not in sys.path:
    sys.path.insert(0, str(TEAM_DIR))

from genetic_algorithm import genetic_algorithm  # noqa: E402
from load_data import load_data  # noqa: E402


OUT_FILE = ROOT / "data" / "sensitivity_results.json"
BASE_SEED = SOLVER_SEED


def run_case(data, base_cfg, *, drone_count=None, speed_ms=None, capacity_kg=None):
    cfg = build_config()
    cfg.n_drones = int(drone_count if drone_count is not None else base_cfg.n_drones)
    cfg.v_cruise = float(speed_ms if speed_ms is not None else base_cfg.v_cruise)
    cfg.W_max = float(capacity_kg if capacity_kg is not None else base_cfg.W_max)
    cfg.t_deliver_min = base_cfg.t_deliver_min
    cfg.t_swap_min = base_cfg.t_swap_min
    cfg.e0 = base_cfg.e0
    cfg.e1 = base_cfg.e1
    cfg.E_max = base_cfg.E_max
    cfg.enable_cost = base_cfg.enable_cost
    cfg.alpha = base_cfg.alpha
    cfg.gamma = base_cfg.gamma
    cfg.swap_cost = base_cfg.swap_cost

    start = time.time()
    sol = run_genetic_with_warmup(data, cfg, BASE_SEED)
    runtime_s = time.time() - start
    return {
        "total_cost": round(float(sol.total_cost), 6),
        "enabled_drones": int(sol.n_enabled),
        "total_energy_wh": round(float(sol.total_energy), 6),
        "total_swaps": int(sol.total_swaps),
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
        "drones": [4, 8, 12, 16, 20],
        "speed": [10, 12, 15, 18, 20],
        "capacity": [1.5, 2.0, 2.5, 3.0, 3.5],
    }

    output = {
        "method": "genetic_algorithm",
        "note": "基于新版120单数据和能耗模型重算；全部参数点使用随机种子42，并按随机搜索预热后运行遗传算法，除当前变量外其余参数保持基准值。",
        "random_seed": BASE_SEED,
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "baseline": baseline,
        "drones": [],
        "speed": [],
        "capacity": [],
    }

    for value in cases["drones"]:
        print(f"[sensitivity] drone_count={value}")
        result = run_case(data, base_cfg, drone_count=value)
        output["drones"].append({"value": value, **result})

    for value in cases["speed"]:
        print(f"[sensitivity] speed_ms={value}")
        result = run_case(data, base_cfg, speed_ms=value)
        output["speed"].append({"value": value, **result})

    for value in cases["capacity"]:
        print(f"[sensitivity] capacity_kg={value}")
        result = run_case(data, base_cfg, capacity_kg=value)
        output["capacity"].append({"value": value, **result})

    with OUT_FILE.open("w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"[sensitivity] saved: {OUT_FILE}")


if __name__ == "__main__":
    main()
