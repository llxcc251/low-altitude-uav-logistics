function sol = random_search(data, cfg, time_budget)
% RANDOM_SEARCH 随机策略（固定时间预算版）

    if nargin < 3, time_budget = 20; end
    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    dep = data.nodes(depot_idx);

    best_cost = inf;
    best_sol = struct();
    best_sol.routes = {}; best_sol.n_enabled = 0;
    best_sol.total_energy = 0; best_sol.total_late = 0; best_sol.total_swaps = 0; best_sol.total_cost = inf;

    n_use = 1;
    t_start = tic;
    while toc(t_start) < time_budget
        % 智能随机分配：按重量排序，贪心分配
        weights = [data.orders.weight];
        [~, weight_order] = sort(weights, 'descend');
        assignment = zeros(1, data.n_orders);
        drone_load = zeros(1, n_use);

        for kk = 1:data.n_orders
            j = weight_order(kk);
            w = data.orders(j).weight;
            candidates = find(drone_load + w <= cfg.W_max);
            if ~isempty(candidates)
                d = candidates(randi(length(candidates)));
                assignment(j) = d;
                drone_load(d) = drone_load(d) + w;
            else
                assignment(j) = randi(n_use);
            end
        end

        [cost, ~, ~, valid] = eval_solution(assignment, data, cfg, dep);
        if valid && cost < best_cost
            best_cost = cost;
            best_sol = build_sol(assignment, data, cfg, dep, n_use);
        end

        n_use = mod(n_use, cfg.n_drones) + 1;
    end
    sol = best_sol;
end

function sol = build_sol(assignment, data, cfg, dep, n_use)
% BUILD_SOL 队列式解构建函数（与评估函数严格对齐）

    drone_orders = cell(n_use, 1);
    for j = 1:length(assignment)
        d = assignment(j);
        if d > 0 && d <= n_use, drone_orders{d} = [drone_orders{d}, j]; end
    end

    sol.routes = {}; sol.n_enabled = 0; sol.total_energy = 0; sol.total_late = 0; sol.total_swaps = 0;
    total_energy = 0; total_late = 0; total_swaps = 0;

    for i = 1:n_use
        if isempty(drone_orders{i}), continue; end
        sol.n_enabled = sol.n_enabled + 1;

        orders_d = drone_orders{i};
        S_vals = [data.orders(orders_d).S];
        [~, sidx] = sort(S_vals);
        orders_d = orders_d(sidx);

        % 选择最近的起降点
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

        % === 逐件配送，电量不够就回去换电 ===
        cur_node = depot_idx;
        drone_time = 0;
        remaining_battery = cfg.E_max;
        trip_energy_acc = 0;
        trip_late_acc = 0;
        trip_details = {};

        for j_idx = 1:length(orders_d)
            j = orders_d(j_idx);
            pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
            dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));

            d1 = data.dist(cur_node, pk); d2 = data.dist(pk, dk);
            tf1 = d1/(cfg.v_cruise*3600); tf2 = d2/(cfg.v_cruise*3600);
            td = cfg.t_deliver_min/60;

            e_empty = cfg.e0 * d1;
            e_loaded = (cfg.e0 + cfg.e1 * data.orders(j).weight) * d2;
            e_needed = e_empty + e_loaded;
            e_return = cfg.e0 * data.dist(dk, depot_idx);

            % 电量不够（本次+回程）→ 回起降点换电
            if e_needed + e_return > remaining_battery
                d_ret = data.dist(cur_node, depot_idx);
                e_ret = cfg.e0 * d_ret;
                t_ret = d_ret/(cfg.v_cruise*3600);

                if ~isempty(trip_details)
                    total_energy = total_energy + trip_energy_acc + e_ret;
                    total_late = total_late + trip_late_acc;
                    drone_time = drone_time + t_ret;

                    route.drone = i;
                    route.orders = cellfun(@(d) d.order_id, trip_details);
                    route.energy = trip_energy_acc + e_ret;
                    route.late = trip_late_acc;
                    route.cost = cfg.alpha*(trip_energy_acc+e_ret) + cfg.gamma*trip_late_acc;
                    route.depot_name = drone_dep.name;
                    route.details = trip_details;
                    sol.routes{end+1} = route;
                end

                total_swaps = total_swaps + 1;
                drone_time = drone_time + cfg.t_swap_min/60;
                remaining_battery = cfg.E_max;
                cur_node = depot_idx;
                trip_energy_acc = 0;
                trip_late_acc = 0;
                trip_details = {};

                d1 = data.dist(cur_node, pk);
                tf1 = d1/(cfg.v_cruise*3600);
                e_empty = cfg.e0 * d1;
                e_needed = e_empty + e_loaded;
            end

            depart = max(data.orders(j).S, drone_time);
            arrive = depart + tf1 + tf2 + td;
            if arrive < data.orders(j).a, arrive = data.orders(j).a; end
            trip_late_here = max(0, arrive - data.orders(j).b);

            trip_energy_acc = trip_energy_acc + e_needed;
            remaining_battery = remaining_battery - e_needed;
            trip_late_acc = trip_late_acc + trip_late_here;
            drone_time = arrive;
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

        % 最后一趟结清
        if ~isempty(trip_details)
            d_ret = data.dist(cur_node, depot_idx);
            e_ret = cfg.e0 * d_ret;
            t_ret = d_ret/(cfg.v_cruise*3600);
            total_energy = total_energy + trip_energy_acc + e_ret;
            total_late = total_late + trip_late_acc;
            drone_time = drone_time + t_ret + cfg.t_swap_min/60;

            route.drone = i;
            route.orders = cellfun(@(d) d.order_id, trip_details);
            route.energy = trip_energy_acc + e_ret;
            route.late = trip_late_acc;
            route.cost = cfg.alpha*(trip_energy_acc+e_ret) + cfg.gamma*trip_late_acc;
            route.depot_name = drone_dep.name;
            route.details = trip_details;
            sol.routes{end+1} = route;
        end
    end
    sol.total_energy = total_energy;
    sol.total_late = total_late;
    sol.total_swaps = total_swaps;
    sol.total_cost = sol.n_enabled * cfg.enable_cost + cfg.alpha * total_energy + cfg.gamma * total_late + cfg.swap_cost * total_swaps;
end
