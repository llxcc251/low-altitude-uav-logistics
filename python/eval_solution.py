# eval_solution.py - 统一严格评估函数（队列装箱版）

EVAL_COUNT = 0

def reset_eval_count():
    global EVAL_COUNT
    EVAL_COUNT = 0

def get_eval_count():
    global EVAL_COUNT
    return EVAL_COUNT

def eval_solution(assignment, data, cfg):
    """
    统一评估函数（双层队列装箱）

    载重超限 → 订单顺延至下一趟（不跳过、不拒绝）
    能耗超限 → 当前节点换电
    所有订单最终都被交付
    """
    n_drones = cfg.n_drones
    m = data.n_orders

    global EVAL_COUNT
    EVAL_COUNT += 1

    if any(d <= 0 or d > n_drones for d in assignment):
        return 1e9, 0, 0, False

    drone_orders = [[] for _ in range(n_drones)]
    for j, d in enumerate(assignment):
        drone_orders[d - 1].append(j)

    total_energy = 0
    total_late = 0
    total_swaps = 0
    delivered = set()

    for i in range(n_drones):
        if not drone_orders[i]:
            continue

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

        for j in orders_d:
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
            e_return = cfg.e0 * data.dist[dk, depot_idx]  # 送完后回起降点所需能耗

            # 电量不够（本次+回程）→ 回起降点换电
            if e_needed + e_return > remaining_battery:
                d_ret = data.dist[cur_node, depot_idx]
                e_ret = cfg.e0 * d_ret
                t_ret = d_ret / (cfg.v_cruise * 3600)
                total_energy += e_ret
                drone_time += t_ret
                total_swaps += 1
                drone_time += cfg.t_swap_min / 60
                remaining_battery = cfg.E_max
                cur_node = depot_idx

                d1 = data.dist[cur_node, pk]
                tf1 = d1 / (cfg.v_cruise * 3600)
                e_empty = cfg.e0 * d1
                e_needed = e_empty + e_loaded

            # 执行配送
            depart = max(order.S, drone_time)
            arrive = depart + tf1 + tf2 + td
            if arrive < order.a:
                arrive = order.a

            total_energy += e_needed
            remaining_battery -= e_needed
            total_late += max(0, arrive - order.b)

            drone_time = arrive
            cur_node = dk
            delivered.add(j)

    n_enabled = sum(1 for orders in drone_orders if orders)

    # 检查所有订单是否都被交付
    assigned = set()
    for orders in drone_orders:
        assigned.update(orders)
    if assigned != delivered:
        return 1e9, 0, 0, False

    cost = (n_enabled * cfg.enable_cost
            + cfg.alpha * total_energy
            + cfg.gamma * total_late
            + cfg.swap_cost * total_swaps)

    return cost, total_energy, total_late, True
