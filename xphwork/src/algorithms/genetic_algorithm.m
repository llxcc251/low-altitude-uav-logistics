function sol = genetic_algorithm(data, cfg)
% GENETIC_ALGORITHM 遗传算法（能耗版，简化稳定版）

    n_drones = cfg.n_drones;
    m = data.n_orders;
    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    dep = data.nodes(depot_idx);

    pop_size = 100;
    n_gen = 500;

    % === 初始化：用随机搜索的解 + 智能随机 ===
    init_sol = random_search(data, cfg, 500);
    pop = cell(pop_size, 1);
    fitness = inf(pop_size, 1);

    % 第1个：随机搜索最优解
    pop{1} = sol_to_assignment(init_sol, n_drones, m);
    fitness(1) = calc_cost(pop{1}, data, cfg, dep);

    % 其余：智能随机分配（按重量排序，贪心分配）
    for p = 2:pop_size
        pop{p} = smart_random_assignment(n_drones, m, data, cfg);
        fitness(p) = calc_cost(pop{p}, data, cfg, dep);
    end

    [best_cost, best_idx] = min(fitness);
    best = pop{best_idx};

    fprintf('  GA init: best_cost=%.1f\n', best_cost);

    % === 进化 ===
    for gen = 1:n_gen
        new_pop = cell(pop_size, 1);
        new_fit = inf(pop_size, 1);

        % 精英保留
        n_elite = max(1, round(pop_size * 0.05));
        [~, sort_idx] = sort(fitness);
        for e = 1:n_elite
            new_pop{e} = pop{sort_idx(e)};
            new_fit(e) = fitness(sort_idx(e));
        end

        % 生成后代
        for p = (n_elite+1):pop_size
            % 锦标赛选择
            p1 = pop{tournament_select_idx(fitness, 5)};
            p2 = pop{tournament_select_idx(fitness, 5)};

            % 交叉 + 变异
            child = crossover_mutation(p1, p2, n_drones, m);
            cc = calc_cost(child, data, cfg, dep);

            % 贪心替换：比父代差就保留父代
            if cc < fitness(sort_idx(min(p, length(sort_idx))))
                new_pop{p} = child;
                new_fit(p) = cc;
            else
                new_pop{p} = p1;
                new_fit(p) = fitness(sort_idx(min(p, length(sort_idx))));
            end
        end

        pop = new_pop;
        fitness = new_fit;

        [gen_best, gen_best_idx] = min(fitness);
        if gen_best < best_cost
            best = pop{gen_best_idx};
            best_cost = gen_best;
        end
    end

    fprintf('  GA final: best_cost=%.1f\n', best_cost);
    sol = assignment_to_sol(best, data, cfg, dep);
end

function idx = tournament_select_idx(fitness, k)
    pop_size = length(fitness);
    candidates = randperm(pop_size, k);
    [~, best_local] = min(fitness(candidates));
    idx = candidates(best_local);
end

function child = crossover_mutation(p1, p2, n_drones, m)
    % 均匀交叉
    child = zeros(1, m);
    for j = 1:m
        if rand() < 0.5
            child(j) = p1(j);
        else
            child(j) = p2(j);
        end
    end
    % 变异
    if rand() < 0.15
        j = randi(m);
        child(j) = randi(n_drones);
    end
end

function assignment = smart_random_assignment(n_drones, m, data, cfg)
    % 按重量排序后贪心分配
    assignment = zeros(1, m);
    weights = [data.orders.weight];
    [~, weight_order] = sort(weights, 'descend');
    drone_load = zeros(1, n_drones);

    for k = 1:m
        j = weight_order(k);
        w = data.orders(j).weight;
        candidates = find(drone_load + w <= cfg.W_max);
        if ~isempty(candidates)
            d = candidates(randi(length(candidates)));
            assignment(j) = d;
            drone_load(d) = drone_load(d) + w;
        else
            assignment(j) = randi(n_drones);
        end
    end
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

            % 贪心装箱
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

            % 逐单配送
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

                % 能耗超限换电
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

                % 记录详情
                detail.order_id = j;
                detail.pickup = data.orders(j).pickup_name;
                detail.delivery = data.orders(j).delivery_name;
                detail.weight = data.orders(j).weight;
                detail.start = drone_dep.name;
                detail.arrive_h = arrive;
                detail.deadline_h = data.orders(j).b;
                trip_details{end+1} = detail;
            end

            % 返程结算（本趟结束）
            d_ret = data.dist(cur_node, depot_idx);
            e_ret = cfg.e0 * d_ret;
            t_ret = d_ret/(cfg.v_cruise*3600);
            total_energy = total_energy + trip_energy + e_ret;
            total_late = total_late + trip_late;
            drone_time = drone_time + t_ret + cfg.t_swap_min/60;

            % 将本趟写入总路线
            route.drone = i;
            route.orders = cellfun(@(d) d.order_id, trip_details);
            route.trips = {cellfun(@(d) d.order_id, trip_details)};
            route.energy = trip_energy + e_ret;
            route.late = trip_late;
            route.cost = cfg.alpha*(trip_energy+e_ret) + cfg.gamma*trip_late;
            route.depot_name = drone_dep.name;
            route.details = trip_details;
            sol.routes{end+1} = route;

            % 准备下一趟
            cur_node = depot_idx;
            unassigned_queue = next_trip_queue;
        end
    end
    sol.total_energy = total_energy;
    sol.total_late = total_late;
    sol.total_swaps = total_swaps;
    sol.total_cost = sol.n_enabled * cfg.enable_cost + cfg.alpha * total_energy + cfg.gamma * total_late + cfg.swap_cost * total_swaps;
end
