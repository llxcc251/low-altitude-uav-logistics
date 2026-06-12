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

        # === 双层队列：趟次规划与执行 ===
        unassigned_queue = orders_d[:]
        cur_node = depot_idx
        drone_time = 0

        while unassigned_queue:
            current_trip_orders = []
            next_trip_queue = []
            trip_load = 0

            # 1. 贪心装箱
            for j in unassigned_queue:
                w = data.orders[j].weight
                if trip_load + w <= cfg.W_max:
                    current_trip_orders.append(j)
                    trip_load += w
                else:
                    next_trip_queue.append(j)

            trip_fly = 0
            trip_energy = 0
            trip_late = 0

            # 2. Phase 1：依次取货（cur_node → pickup_1 → pickup_2 → ...）
            cur_load = 0
            for j in current_trip_orders:
                order = data.orders[j]
                pk = data.node_ids.index(order.pickup_id)

                d = data.dist[cur_node, pk]
                e = (cfg.e0 + cfg.e1 * cur_load) * d
                tf = d / (cfg.v_cruise * 3600)

                if trip_energy + e > cfg.E_max:
                    total_energy += trip_energy
                    total_late += trip_late
                    total_swaps += 1
                    drone_time += cfg.t_swap_min / 60
                    trip_energy = 0
                    trip_late = 0
                    trip_fly = 0
                    e = (cfg.e0 + cfg.e1 * cur_load) * d

                arrive_pickup = drone_time + tf
                if arrive_pickup < order.S:
                    arrive_pickup = order.S

                drone_time = arrive_pickup
                trip_fly += tf
                trip_energy += e
                cur_load += order.weight
                cur_node = pk

            # 3. Phase 2：依次配送（... → delivery_1 → delivery_2 → ...）
            for j in current_trip_orders:
                order = data.orders[j]
                dk = data.node_ids.index(order.delivery_id)

                d = data.dist[cur_node, dk]
                e = (cfg.e0 + cfg.e1 * cur_load) * d
                tf = d / (cfg.v_cruise * 3600)
                td = cfg.t_deliver_min / 60

                if trip_energy + e > cfg.E_max:
                    total_energy += trip_energy
                    total_late += trip_late
                    total_swaps += 1
                    drone_time += cfg.t_swap_min / 60
                    trip_energy = 0
                    trip_late = 0
                    trip_fly = 0
                    e = (cfg.e0 + cfg.e1 * cur_load) * d

                arrive = drone_time + tf + td
                if arrive < order.a:
                    arrive = order.a

                trip_late_here = max(0, arrive - order.b)
                trip_late += trip_late_here

                drone_time = arrive
                trip_fly += tf + td
                trip_energy += e
                cur_load -= order.weight
                cur_node = dk
                delivered.add(j)

            # 4. 一趟结束，返回起降点
            d_ret = data.dist[cur_node, depot_idx]
            e_ret = cfg.e0 * d_ret
            t_ret = d_ret / (cfg.v_cruise * 3600)

            total_energy += trip_energy + e_ret
            total_late += trip_late
            drone_time += t_ret + cfg.t_swap_min / 60

            cur_node = depot_idx
            unassigned_queue = next_trip_queue

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
