# random_search.py - 随机搜索算法

import random
from eval_solution import eval_solution

class Route:
    def __init__(self):
        self.drone = 0
        self.orders = []
        self.time = 0
        self.late = 0
        self.cost = 0
        self.depot_name = ""
        self.details = []

class Solution:
    def __init__(self):
        self.routes = []
        self.n_enabled = 0
        self.total_time = 0
        self.total_late = 0
        self.total_cost = 0

def random_search(data, cfg, n_trials=100):
    """
    随机搜索算法
    对每种无人机数量（1~n_drones），各随机 n_trials 次，取全局最优
    """
    best_cost = float('inf')
    best_sol = Solution()

    # 按时间窗排序
    time_order = sorted(range(data.n_orders), key=lambda j: data.orders[j].a)

    for n_use in range(1, cfg.n_drones + 1):
        for trial in range(n_trials):
            # 随机分配
            assignment = [0] * data.n_orders
            for k in range(data.n_orders):
                assignment[time_order[k]] = random.randint(1, n_use)

            # 评估
            cost, _, _, valid = eval_solution(assignment, data, cfg)

            if valid and cost < best_cost:
                best_cost = cost
                best_sol = build_sol(assignment, data, cfg, n_use)

    return best_sol

def build_sol(assignment, data, cfg, n_use):
    """从 assignment 构建解结构"""
    drone_orders = [[] for _ in range(n_use)]
    for j, d in enumerate(assignment):
        if 1 <= d <= n_use:
            drone_orders[d - 1].append(j)

    sol = Solution()
    sol.routes = []
    sol.n_enabled = 0
    sol.total_time = 0
    sol.total_late = 0
    total_time = 0
    total_late = 0

    for i in range(n_use):
        if not drone_orders[i]:
            continue
        sol.n_enabled += 1

        orders_d = drone_orders[i]
        orders_d.sort(key=lambda j: data.orders[j].S)

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

        # 趟内逐件顺序处理
        cur_node = depot_idx
        drone_time = 0
        trip_load = 0
        trip_fly = 0
        trip_late = 0
        trip_details = []

        for j in orders_d:
            order = data.orders[j]

            # 载重检查
            if trip_load + order.weight > cfg.W_max:
                d_ret = data.dist[cur_node, depot_idx]
                t_ret = d_ret / (cfg.v_cruise * 3600)
                total_time += trip_fly + t_ret
                total_late += trip_late
                drone_time += trip_fly + t_ret + cfg.t_swap_min / 60

                route = Route()
                route.drone = i + 1
                route.orders = [d["order_id"] for d in trip_details]
                route.time = trip_fly + t_ret
                route.late = trip_late
                route.cost = cfg.alpha * (trip_fly + t_ret) + cfg.gamma * trip_late
                route.depot_name = drone_dep.name
                route.details = trip_details
                sol.routes.append(route)

                cur_node = depot_idx
                trip_load = 0
                trip_fly = 0
                trip_late = 0
                trip_details = []

            pk = data.node_ids.index(order.pickup_id)
            dk = data.node_ids.index(order.delivery_id)

            d1 = data.dist[cur_node, pk]
            d2 = data.dist[pk, dk]
            tf1 = d1 / (cfg.v_cruise * 3600)
            tf2 = d2 / (cfg.v_cruise * 3600)
            td = cfg.t_deliver_min / 60

            depart = max(order.S, drone_time)
            arrive = depart + tf1 + tf2 + td
            trip_late_here = max(0, arrive - order.b)

            drone_time = depart + tf1 + tf2 + td
            trip_fly += tf1 + tf2 + td
            trip_load += order.weight
            trip_late += trip_late_here
            cur_node = dk

            detail = {
                "order_id": j + 1,
                "pickup": order.pickup_name,
                "delivery": order.delivery_name,
                "weight": order.weight,
                "start": drone_dep.name,
                "arrive_h": arrive,
                "deadline_h": order.b,
            }
            trip_details.append(detail)

        # 最后一趟返回
        d_ret = data.dist[cur_node, depot_idx]
        t_ret = d_ret / (cfg.v_cruise * 3600)
        total_time += trip_fly + t_ret
        total_late += trip_late

        route = Route()
        route.drone = i + 1
        route.orders = [d["order_id"] for d in trip_details]
        route.time = trip_fly + t_ret
        route.late = trip_late
        route.cost = cfg.alpha * (trip_fly + t_ret) + cfg.gamma * trip_late
        route.depot_name = drone_dep.name
        route.details = trip_details
        sol.routes.append(route)

    sol.total_time = total_time
    sol.total_late = total_late
    sol.total_cost = sol.n_enabled * cfg.enable_cost + sum(r.cost for r in sol.routes)

    return sol
