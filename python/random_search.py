# random_search.py - 随机搜索算法（队列装箱版）

import random
import time
from eval_solution import eval_solution


def smart_random_assignment(n_drones, n_orders, data, cfg):
    """纯随机分配（取一送一模式下无需载重约束）"""
    return [random.randint(1, n_drones) for _ in range(n_orders)]


def random_search(data, cfg, time_budget=20):
    best_cost = float('inf')
    best_sol = None
    end_time = time.time() + time_budget
    n_use = 1

    while time.time() < end_time:
        assignment = smart_random_assignment(n_use, data.n_orders, data, cfg)
        cost, _, _, valid = eval_solution(assignment, data, cfg)

        if valid and cost < best_cost:
            best_cost = cost
            best_sol = build_sol(assignment, data, cfg, n_use)

        n_use = (n_use % cfg.n_drones) + 1

    return best_sol


def build_sol(assignment, data, cfg, n_use):
    drone_orders = [[] for _ in range(n_use)]
    for j, d in enumerate(assignment):
        if 1 <= d <= n_use:
            drone_orders[d - 1].append(j)

    sol = type('Solution', (), {
        'routes': [], 'n_enabled': 0, 'total_energy': 0,
        'total_late': 0, 'total_swaps': 0, 'total_cost': float('inf')
    })()
    total_energy = 0
    total_late = 0
    total_swaps = 0

    for i in range(n_use):
        if not drone_orders[i]:
            continue
        sol.n_enabled += 1

        orders_d = sorted(drone_orders[i], key=lambda j: data.orders[j].S)

        # 选最近起降点
        best_dep_idx = 0
        best_dep_dist = float('inf')
        for dd, dep in enumerate(data.depots):
            dep_node_idx = data.node_ids.index(dep.id)
            total_d = sum(data.dist[dep_node_idx, data.node_ids.index(data.orders[j].pickup_id)]
                         for j in orders_d)
            if total_d < best_dep_dist:
                best_dep_dist = total_d
                best_dep_idx = dd

        drone_dep = data.depots[best_dep_idx]
        depot_idx = data.node_ids.index(drone_dep.id)

        # === 逐件配送，电量不够就回去换电 ===
        cur_node = depot_idx
        drone_time = 0
        remaining_battery = cfg.E_max
        trip_orders = []
        trip_energy_acc = 0
        trip_late_acc = 0
        trip_details = []

        for idx, j in enumerate(orders_d):
            order = data.orders[j]
            pk = data.node_ids.index(order.pickup_id)
            dk = data.node_ids.index(order.delivery_id)

            d1 = data.dist[cur_node, pk]
            d2 = data.dist[pk, dk]
            tf1 = d1 / (cfg.v_cruise * 3600)
            tf2 = d2 / (cfg.v_cruise * 3600)
            td = cfg.t_deliver_min / 60

            e_empty = cfg.e0 * d1
            e_loaded = (cfg.e0 + cfg.e1 * order.weight) * d2
            e_needed = e_empty + e_loaded
            e_return = cfg.e0 * data.dist[dk, depot_idx]

            # 电量不够（本次+回程）→ 回起降点换电
            if e_needed + e_return > remaining_battery:
                d_ret = data.dist[cur_node, depot_idx]
                e_ret = cfg.e0 * d_ret
                t_ret = d_ret / (cfg.v_cruise * 3600)

                # 结清当前这趟（如有）
                if trip_details:
                    total_energy += trip_energy_acc + e_ret
                    total_late += trip_late_acc
                    drone_time += t_ret
                    sol.routes.append({
                        'drone': i + 1,
                        'orders': [t['order_id'] for t in trip_details],
                        'energy': trip_energy_acc + e_ret,
                        'late': trip_late_acc,
                        'cost': cfg.alpha * (trip_energy_acc + e_ret) + cfg.gamma * trip_late_acc,
                        'depot_name': drone_dep.name,
                        'details': trip_details,
                    })

                total_swaps += 1
                drone_time += cfg.t_swap_min / 60
                remaining_battery = cfg.E_max
                cur_node = depot_idx
                trip_orders = []
                trip_energy_acc = 0
                trip_late_acc = 0
                trip_details = []

                d1 = data.dist[cur_node, pk]
                tf1 = d1 / (cfg.v_cruise * 3600)
                e_empty = cfg.e0 * d1
                e_needed = e_empty + e_loaded

            # 执行配送
            depart = max(order.S, drone_time)
            arrive = depart + tf1 + tf2 + td
            if arrive < order.a:
                arrive = order.a

            trip_energy_acc += e_needed
            remaining_battery -= e_needed
            trip_late_acc += max(0, arrive - order.b)
            drone_time = arrive
            cur_node = dk

            trip_details.append({
                "order_id": j + 1, "pickup": order.pickup_name,
                "delivery": order.delivery_name, "weight": order.weight,
                "start": drone_dep.name, "arrive_h": arrive, "deadline_h": order.b,
            })

        # 最后一趟结清
        if trip_energy_acc > 0:
            d_ret = data.dist[cur_node, depot_idx]
            e_ret = cfg.e0 * d_ret
            t_ret = d_ret / (cfg.v_cruise * 3600)

            total_energy += trip_energy_acc + e_ret
            total_late += trip_late_acc
            drone_time += t_ret + cfg.t_swap_min / 60

            sol.routes.append({
                'drone': i + 1,
                'orders': [t['order_id'] for t in trip_details],
                'energy': trip_energy_acc + e_ret,
                'late': trip_late_acc,
                'cost': cfg.alpha * (trip_energy_acc + e_ret) + cfg.gamma * trip_late_acc,
                'depot_name': drone_dep.name,
                'details': trip_details,
            })

    sol.total_energy = total_energy
    sol.total_late = total_late
    sol.total_swaps = total_swaps
    sol.total_cost = sol.n_enabled * cfg.enable_cost + cfg.alpha * total_energy + cfg.gamma * total_late + cfg.swap_cost * total_swaps
    return sol
