# eval_solution.py - 统一严格评估函数（使用实际飞行距离）

import numpy as np

def eval_solution(assignment, data, cfg):
    """
    统一的严格评估函数

    硬性约束：
    1. 所有订单必须被分配
    2. 载重约束：每趟总重量 <= W_max
    3. 电池约束：每趟总飞行时间 <= T_max
    4. 时间窗约束：到达时间 = max(就绪时间, 无人机可用时间) + 飞行时间
    5. 换电池时间：两趟之间间隔 T_swap

    返回: (cost, total_time, total_late, valid)
    """
    n_drones = cfg.n_drones
    m = data.n_orders

    # === 硬性约束 1：所有订单必须被分配 ===
    if any(d <= 0 or d > n_drones for d in assignment):
        return 1e9, 0, 0, False

    # 按无人机分组
    drone_orders = [[] for _ in range(n_drones)]
    for j, d in enumerate(assignment):
        drone_orders[d - 1].append(j)

    total_time = 0
    total_late = 0

    for i in range(n_drones):
        if not drone_orders[i]:
            continue

        orders_d = drone_orders[i]
        # 按就绪时间排序
        orders_d.sort(key=lambda j: data.orders[j].S)

        # 选最近起降点（用实际距离）
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

        # === 趟内逐件顺序处理 ===
        cur_node = depot_idx
        drone_time = 0       # 无人机当前可用时间
        trip_load = 0        # 当前趟载重
        trip_fly = 0         # 当前趟飞行时间
        trip_late = 0        # 当前趟超时

        for j in orders_d:
            order = data.orders[j]
            pk = data.node_ids.index(order.pickup_id)
            dk = data.node_ids.index(order.delivery_id)

            # 预计算飞行距离
            d1 = data.dist[cur_node, pk]
            d2 = data.dist[pk, dk]
            d_ret_j = data.dist[dk, depot_idx]
            tf1 = d1 / (cfg.v_cruise * 3600)
            tf2 = d2 / (cfg.v_cruise * 3600)
            td = cfg.t_deliver_min / 60
            t_ret_j = d_ret_j / (cfg.v_cruise * 3600)

            # === 硬性约束 2 & 3：载重或电池超限 → 返回起降点开新趟 ===
            need_new_trip = False
            if trip_load + order.weight > cfg.W_max:
                need_new_trip = True
            if trip_fly + tf1 + tf2 + td + t_ret_j > cfg.t_max_h:
                need_new_trip = True

            if need_new_trip:
                # 返回起降点
                d_ret = data.dist[cur_node, depot_idx]
                t_ret = d_ret / (cfg.v_cruise * 3600)
                total_time += trip_fly + t_ret
                total_late += trip_late
                drone_time += trip_fly + t_ret + cfg.t_swap_min / 60

                # 开新趟
                cur_node = depot_idx
                trip_load = 0
                trip_fly = 0
                trip_late = 0

                d1 = data.dist[cur_node, pk]
                tf1 = d1 / (cfg.v_cruise * 3600)

            # === 硬性约束 4：出发时间逻辑 ===
            depart = max(order.S, drone_time)
            arrive = depart + tf1 + tf2 + td

            # 超时
            trip_late_here = max(0, arrive - order.b)
            trip_late += trip_late_here

            # 更新状态
            drone_time = depart + tf1 + tf2 + td
            trip_fly += tf1 + tf2 + td
            trip_load += order.weight
            cur_node = dk

        # 最后一趟返回起降点
        d_ret = data.dist[cur_node, depot_idx]
        t_ret = d_ret / (cfg.v_cruise * 3600)
        total_time += trip_fly + t_ret
        total_late += trip_late

    n_enabled = sum(1 for orders in drone_orders if orders)
    cost = n_enabled * cfg.enable_cost + cfg.alpha * total_time + cfg.gamma * total_late

    return cost, total_time, total_late, True
