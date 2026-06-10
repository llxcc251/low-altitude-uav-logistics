function sol = simulated_annealing(data, cfg)
% SIMULATED_ANNEALING 模拟退火算法（能耗版，使用data.dist）

    n_drones = cfg.n_drones;
    m = data.n_orders;
    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    dep = data.nodes(depot_idx);

    % === 用随机算法的最佳解作为初始解 ===
    init_sol = random_search(data, cfg, 500);
    current = sol_to_assignment(init_sol, n_drones, m);
    current_cost = calc_cost(current, data, cfg, dep);
    fprintf('  SA 初始: 成本=%.1f, 启用=%d架\n', current_cost, init_sol.n_enabled);

    best = current;
    best_cost = current_cost;

    % 退火参数
    T = 50; T_min = 0.1; alpha = 0.93; max_iter = 200;
    K = 5;

    % 构建时间邻域表
    a_vals = [data.orders.a];
    [~, sort_idx] = sort(a_vals);
    time_order = sort_idx;
    pos_of = zeros(1, m);
    for p = 1:m
        pos_of(time_order(p)) = p;
    end

    while T > T_min
        for iter = 1:max_iter
            r = rand();
            if r < 0.45
                j1 = randi(m);
                p1 = pos_of(j1);
                offset = randi([-K, K]);
                p2 = max(1, min(m, p1 + offset));
                j2 = time_order(p2);
                if j1 == j2, continue; end
                candidate = current;
                candidate(j1) = current(j2);
                candidate(j2) = current(j1);
            elseif r < 0.75
                j1 = randi(m);
                d1 = current(j1);
                d2 = randi(n_drones);
                if d1 == d2, continue; end
                candidate = current;
                candidate(j1) = d2;
            elseif r < 0.90
                d = randi(n_drones);
                idx = find(current == d);
                if length(idx) < 2, continue; end
                candidate = current;
                shuffle = idx(randperm(length(idx)));
                candidate(idx) = shuffle;
            else
                drone_cnt = zeros(n_drones, 1);
                for j = 1:m
                    if current(j) > 0 && current(j) <= n_drones
                        drone_cnt(current(j)) = drone_cnt(current(j)) + 1;
                    end
                end
                [min_cnt, src_drone] = min(drone_cnt);
                if min_cnt == 0, continue; end
                candidates = find(drone_cnt > 0 & (1:n_drones)' ~= src_drone);
                if isempty(candidates), continue; end
                dst_drone = candidates(randi(length(candidates)));
                candidate = current;
                candidate(current == src_drone) = dst_drone;
            end

            cc = calc_cost(candidate, data, cfg, dep);
            if cc >= 1e9, continue; end

            delta = cc - current_cost;
            if delta < 0 || rand() < exp(-delta / T)
                current = candidate;
                current_cost = cc;
                if current_cost < best_cost
                    best = current;
                    best_cost = current_cost;
                end
            end
        end
        T = T * alpha;
    end

    sol = assignment_to_sol(best, data, cfg, dep);
end

function assignment = sol_to_assignment(sol, n_drones, m)
    assignment = zeros(1, m);
    for r = 1:length(sol.routes)
        route = sol.routes{r};
        for jj = route.orders
            assignment(jj) = route.drone;
        end
    end
end

function cost = calc_cost(assignment, data, cfg, dep)
    [cost, ~, ~, ~] = eval_solution(assignment, data, cfg, dep);
end

% === 双层队列装箱解码器 ===
function sol = assignment_to_sol(assignment, data, cfg, dep)
    n_use = cfg.n_drones;
    drone_orders = cell(n_use, 1);
    for j = 1:length(assignment)
        d = assignment(j);
        if d > 0 && d <= n_use, drone_orders{d} = [drone_orders{d}, j]; end
    end

    sol.routes = {}; sol.n_enabled = 0;
    sol.total_energy = 0; sol.total_late = 0; sol.total_swaps = 0;
    total_energy = 0; total_late = 0; total_swaps = 0;

    for i = 1:n_use
        if isempty(drone_orders{i}), continue; end
        sol.n_enabled = sol.n_enabled + 1;

        orders_d = drone_orders{i};
        S_vals = [data.orders(orders_d).S];
        [~, sidx] = sort(S_vals);
        orders_d = orders_d(sidx);

        % 选最近起降点
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

        % === 双层队列逻辑开始 ===
        unassigned_queue = orders_d;
        cur_node = depot_idx;
        drone_time = 0;

        while ~isempty(unassigned_queue)
            current_trip_orders = [];
            next_trip_queue = [];
            trip_load = 0;

            for kk = 1:length(unassigned_queue)
                j = unassigned_queue(kk);
                w = data.orders(j).weight;
                if trip_load + w <= cfg.W_max
                    current_trip_orders(end+1) = j;
                    trip_load = trip_load + w;
                else
                    next_trip_queue(end+1) = j;
                end
            end

            trip_fly = 0; trip_energy = 0; trip_late = 0;
            trip_details = {};

            for kk = 1:length(current_trip_orders)
                j = current_trip_orders(kk);
                pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
                dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));

                d1 = data.dist(cur_node, pk); d2 = data.dist(pk, dk);
                tf1 = d1/(cfg.v_cruise*3600); tf2 = d2/(cfg.v_cruise*3600);
                td = cfg.t_deliver_min/60;

                e_empty = cfg.e0 * d1;
                e_loaded = (cfg.e0 + cfg.e1 * trip_load) * d2;
                e_segment = e_empty + e_loaded;

                if trip_energy + e_segment > cfg.E_max
                    total_energy = total_energy + trip_energy;
                    total_late = total_late + trip_late;
                    total_swaps = total_swaps + 1;
                    drone_time = drone_time + cfg.t_swap_min/60;
                    trip_energy = 0; trip_late = 0; trip_fly = 0;

                    d1 = data.dist(cur_node, pk);
                    tf1 = d1/(cfg.v_cruise*3600);
                    e_empty = cfg.e0 * d1;
                    e_loaded = (cfg.e0 + cfg.e1 * trip_load) * d2;
                    e_segment = e_empty + e_loaded;
                end

                depart = max(data.orders(j).S, drone_time);
                arrive = depart + tf1 + tf2 + td;
                if arrive < data.orders(j).a, arrive = data.orders(j).a; end
                trip_late_here = max(0, arrive - data.orders(j).b);

                drone_time = arrive;
                trip_fly = trip_fly + tf1 + tf2 + td;
                trip_energy = trip_energy + e_segment;
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

            d_ret = data.dist(cur_node, depot_idx);
            e_ret = cfg.e0 * d_ret;
            t_ret = d_ret/(cfg.v_cruise*3600);
            total_energy = total_energy + trip_energy + e_ret;
            total_late = total_late + trip_late;
            drone_time = drone_time + t_ret + cfg.t_swap_min/60;

            route.drone = i;
            route.orders = cellfun(@(d) d.order_id, trip_details);
            route.trips = {cellfun(@(d) d.order_id, trip_details)};
            route.energy = trip_energy + e_ret;
            route.late = trip_late;
            route.cost = cfg.alpha*(trip_energy+e_ret) + cfg.gamma*trip_late;
            route.depot_name = drone_dep.name;
            route.details = trip_details;
            sol.routes{end+1} = route;

            cur_node = depot_idx;
            unassigned_queue = next_trip_queue;
        end
    end
    sol.total_energy = total_energy;
    sol.total_late = total_late;
    sol.total_swaps = total_swaps;
    sol.total_cost = sol.n_enabled * cfg.enable_cost + cfg.alpha * total_energy + cfg.gamma * total_late + cfg.swap_cost * total_swaps;
end
