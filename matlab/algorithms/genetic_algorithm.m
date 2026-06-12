function sol = genetic_algorithm(data, cfg, time_budget)
% GENETIC_ALGORITHM 遗传算法（固定时间预算版）

    if nargin < 3, time_budget = 20; end
    n_drones = cfg.n_drones;
    m = data.n_orders;
    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    dep = data.nodes(depot_idx);

    pop_size = 100;
    end_time = tic;
    gen = 0;

    % === 初始化：用随机搜索的解 + 智能随机 ===
    init_sol = random_search(data, cfg, time_budget * 0.2);
    pop = cell(pop_size, 1);
    fitness = inf(pop_size, 1);

    if toc(end_time) >= time_budget
        fprintf('  GA init: timed out\n');
        sol = init_sol; return;
    end

    pop{1} = sol_to_assignment(init_sol, n_drones, m);
    fitness(1) = calc_cost(pop{1}, data, cfg, dep);

    for p = 2:pop_size
        if toc(end_time) >= time_budget, break; end
        pop{p} = smart_random_assignment(n_drones, m, data, cfg);
        fitness(p) = calc_cost(pop{p}, data, cfg, dep);
    end

    if isempty(pop{1})
        sol = init_sol; return;
    end

    [best_cost, best_idx] = min(fitness);
    best = pop{best_idx};

    fprintf('  GA init: best_cost=%.1f\n', best_cost);

    % === 进化 ===
    while toc(end_time) < time_budget
        gen = gen + 1;
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

            % 直接添加子代
            new_pop{p} = child;
            new_fit(p) = cc;
        end

        % (u+lambda) 合并父代+子代，取前 pop_size
        combined_pop = [pop; new_pop];
        combined_fit = [fitness; new_fit];
        [~, sort_idx] = sort(combined_fit);
        pop = combined_pop(sort_idx(1:pop_size));
        fitness = combined_fit(sort_idx(1:pop_size));

        [gen_best, gen_best_idx] = min(fitness);
        if gen_best < best_cost
            best = pop{gen_best_idx};
            best_cost = gen_best;
        end
    end

    fprintf('  GA final: best_cost=%.1f (%d gen)\n', best_cost, gen);
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

function assignment = smart_random_assignment(n_drones, m, ~, ~)
    % 纯随机分配（取一送一模式下无需载重约束）
    assignment = randi(n_drones, 1, m);
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
