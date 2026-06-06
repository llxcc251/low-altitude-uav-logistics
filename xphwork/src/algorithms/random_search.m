function sol = random_search(data, cfg, n_trials)
% RANDOM_SEARCH 随机策略（支持一趟多单VRP拼单）

    if nargin < 3, n_trials = 100; end
    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    dep = data.nodes(depot_idx);
    a_vals = [data.orders.a];
    [~, time_order] = sort(a_vals);

    best_cost = inf;
    best_sol = struct();
    best_sol.routes = {}; best_sol.n_enabled = 0;
    best_sol.total_time = 0; best_sol.total_late = 0; best_sol.total_cost = inf;

    for n_use = 1:cfg.n_drones
        for trial = 1:n_trials
            assignment = zeros(1, data.n_orders);
            for k = 1:data.n_orders
                assignment(time_order(k)) = randi(n_use);
            end
            [cost, ~, ~, ~] = eval_solution(assignment, data, cfg, dep);
            if cost < best_cost
                best_cost = cost;
                best_sol = build_sol(assignment, data, cfg, dep, n_use);
            end
        end
    end
    sol = best_sol;
end

function sol = build_sol(assignment, data, cfg, dep, n_use)
    drone_orders = cell(n_use, 1);
    for j = 1:length(assignment)
        d = assignment(j);
        if d > 0 && d <= n_use, drone_orders{d} = [drone_orders{d}, j]; end
    end

    sol.routes = {}; sol.n_enabled = 0; sol.total_time = 0; sol.total_late = 0;
    total_time = 0; total_late = 0;

    for i = 1:n_use
        if isempty(drone_orders{i}), continue; end
        sol.n_enabled = sol.n_enabled + 1;

        orders_d = drone_orders{i};
        S_vals = [data.orders(orders_d).S];
        [~, sidx] = sort(S_vals);
        orders_d = orders_d(sidx);

        % 选最近起降点（用实际距离）
        best_dep_idx = 1; best_dep_dist = inf;
        for dd = 1:length(dep)
            dep_node_idx = find(strcmp(data.node_ids, dep(dd).id));
            total_d = 0;
            for kk = 1:length(orders_d)
                pk = find(strcmp(data.node_ids, data.orders(orders_d(kk)).pickup_id));
                total_d = total_d + data.dist(dep_node_idx, pk);
            end
            if total_d < best_dep_dist, best_dep_dist = total_d; best_dep_idx = dd; end
        end
        drone_dep = dep(best_dep_idx);
        depot_idx = find(strcmp(data.node_ids, drone_dep.id));

        % 趟内逐件顺序处理
        cur_node = depot_idx;
        drone_time = 0; trip_load = 0; trip_fly = 0; trip_late = 0;
        trip_details = {};

        for kk = 1:length(orders_d)
            j = orders_d(kk);

            % 载重检查：超重则返回起降点开新趟
            if trip_load + data.orders(j).weight > cfg.W_max
                d_ret = data.dist(cur_node, depot_idx);
                t_ret = d_ret / (cfg.v_cruise * 3600);
                total_time = total_time + trip_fly + t_ret;
                total_late = total_late + trip_late;
                drone_time = drone_time + trip_fly + t_ret + cfg.t_swap_min/60;

                route.drone = i;
                route.orders = cellfun(@(d) d.order_id, trip_details);
                route.trips = {cellfun(@(d) d.order_id, trip_details)};
                route.time = trip_fly + t_ret;
                route.late = trip_late;
                route.cost = cfg.alpha*(trip_fly+t_ret) + cfg.gamma*trip_late;
                route.depot_name = drone_dep.name;
                route.details = trip_details;
                sol.routes{end+1} = route;

                cur_node = depot_idx;
                trip_load = 0; trip_fly = 0; trip_late = 0; trip_details = {};
            end

            % 飞到取货点
            pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
            dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));

            d1 = data.dist(cur_node, pk);
            d2 = data.dist(pk, dk);
            tf1 = d1/(cfg.v_cruise*3600); tf2 = d2/(cfg.v_cruise*3600);
            td = cfg.t_deliver_min/60;

            depart = max(data.orders(j).S, drone_time);
            arrive = depart + tf1 + tf2 + td;
            trip_late_here = max(0, arrive - data.orders(j).b);

            drone_time = depart + tf1 + tf2 + td;
            trip_fly = trip_fly + tf1 + tf2 + td;
            trip_load = trip_load + data.orders(j).weight;
            trip_late = trip_late + trip_late_here;
            cur_node = dk;

            detail.order_id = j;
            detail.pickup = data.orders(j).pickup_name;
            detail.delivery = data.orders(j).delivery_name;
            detail.weight = data.orders(j).weight;
            detail.start = drone_dep.name;
            detail.arrive_h = arrive;
            detail.deadline_h = data.orders(j).b;
            trip_details{end+1} = detail;
        end

        % 最后一趟返回
        d_ret = data.dist(cur_node, depot_idx);
        t_ret = d_ret/(cfg.v_cruise*3600);
        total_time = total_time + trip_fly + t_ret;
        total_late = total_late + trip_late;

        route.drone = i;
        route.orders = cellfun(@(d) d.order_id, trip_details);
        route.trips = {cellfun(@(d) d.order_id, trip_details)};
        route.time = trip_fly + t_ret;
        route.late = trip_late;
        route.cost = cfg.alpha*(trip_fly+t_ret) + cfg.gamma*trip_late;
        route.depot_name = drone_dep.name;
        route.details = trip_details;
        sol.routes{end+1} = route;
    end
    sol.total_time = total_time;
    sol.total_late = total_late;
    sol.total_cost = sol.n_enabled * cfg.enable_cost + sum(cellfun(@(r) r.cost, sol.routes));
end
