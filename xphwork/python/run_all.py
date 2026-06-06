# run_all.py - 算法对比主脚本

import time
from config import Config
from load_data import load_data
from random_search import random_search
from genetic_algorithm import genetic_algorithm

def run_all():
    """跑全部算法并输出对比表"""
    print("=" * 50)
    print("  算法对比实验")
    print("=" * 50)
    print()

    # 加载数据
    cfg = Config()
    data = load_data("../data/raw")

    print(f"数据: {cfg.n_drones} 架无人机, {data.n_orders} 件快递")
    print(f"费用: 启用={cfg.enable_cost}, 时间={cfg.alpha}, 超时={cfg.gamma}")
    print()

    methods = [
        ("random_search", "随机×100/架"),
        ("genetic_algorithm", "遗传算法"),
    ]

    results = []
    times = []

    for method_key, method_name in methods:
        print(f"运行 {method_name} ...")
        start = time.time()

        if method_key == "random_search":
            sol = random_search(data, cfg, 100)
        elif method_key == "genetic_algorithm":
            sol = genetic_algorithm(data, cfg)

        elapsed = time.time() - start
        print(f"  完成 ({elapsed:.2f} s)")
        results.append(sol)
        times.append(elapsed)

    # 找最优成本
    costs = [r.total_cost for r in results]
    best_cost = min(costs)

    # 输出对比表
    print()
    print("=" * 70)
    print("  对比结果")
    print("=" * 70)
    print(f"{'方法':<12} {'总成本':>8} {'启用数':>6} {'超时(min)':>8} {'总用时(min)':>10} {'计算耗时(s)':>10}")
    print("-" * 70)

    for m, (method_key, method_name) in enumerate(methods):
        r = results[m]
        gap = (r.total_cost - best_cost) / best_cost * 100 if best_cost > 0 else 0
        print(f"{method_name:<12} {r.total_cost:>8.1f} {r.n_enabled:>6} {r.total_late * 60:>8.1f} {r.total_time * 60:>10.1f} {times[m]:>10.2f}  (gap {gap:.1f}%)")

    print()

    # 输出最优方案的详细配送计划
    best_idx = costs.index(min(costs))
    best = results[best_idx]
    print("=" * 50)
    print(f"  最优方案详细配送计划 ({methods[best_idx][1]})")
    print("=" * 50)

    for k, route in enumerate(best.routes):
        depot_name = route.depot_name if route.depot_name else "驿站"
        print(f"\n无人机 {route.drone} [{depot_name}]  {route.time * 60:.1f}min:")

        if route.details:
            print(f"  详细路径:")
            print(f"  {depot_name}", end="")
            for d in route.details:
                arr_h = int(d["arrive_h"])
                arr_m = round((d["arrive_h"] - arr_h) * 60)
                print(f"\n  -> {d['pickup']}({d['weight']:.1f}kg) -> {d['delivery']} "
                      f"(完成订单 #{d['order_id']:03d}, {arr_h:02d}:{arr_m:02d})", end="")
            print(f"\n  -> {depot_name}")
        else:
            print(f"  路线: {depot_name}", end="")
            for j in route.orders:
                order = data.orders[j - 1]
                print(f" -> {order.pickup_name}({order.weight:.1f}kg) -> {order.delivery_name}", end="")
            print(f" -> {depot_name}")

    print()

if __name__ == "__main__":
    run_all()
