function sol = genetic_algorithm(data, cfg)
% GENETIC_ALGORITHM 遗传算法求解无人机配送路径优化
%   种群并行搜索 + 交叉重组，比SA搜索范围更广

    n_drones = cfg.n_drones;
    m = data.n_orders;
    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    dep = data.nodes(depot_idx);

    % === GA 参数 ===
    pop_size = 100;       % 种群大小
    n_gen = 200;          % 迭代代数
    pc = 0.85;            % 交叉概率
    pm = 0.15;            % 变异概率
    elite_ratio = 0.05;   % 精英比例
    tournament_k = 5;     % 锦标赛选择大小

    % === 初始化种群 ===
    pop = cell(pop_size, 1);
    fitness = zeros(pop_size, 1);

    % 第1个：随机搜索的最优解
    seed_sol = random_search(data, cfg, 200);
    pop{1} = sol_to_assignment(seed_sol, n_drones, m);
    fitness(1) = calc_fitness(pop{1}, data, cfg, dep);

    % 其余：随机生成可行解
    for p = 2:pop_size
        pop{p} = random_assignment(n_drones, m);
        fitness(p) = calc_fitness(pop{p}, data, cfg, dep);
    end

    fprintf('  GA: pop=%d, gen=%d\n', pop_size, n_gen);

    best_fitness = inf;
    best_ever = pop{1};

    % === 迭代 ===
    for gen = 1:n_gen
        % 精英保留
        n_elite = max(1, round(pop_size * elite_ratio));
        [~, sort_idx] = sort(fitness);
        new_pop = cell(pop_size, 1);
        new_fit = zeros(pop_size, 1);

        for e = 1:n_elite
            new_pop{e} = pop{sort_idx(e)};
            new_fit(e) = fitness(sort_idx(e));
        end

        % 生成剩余个体
        for p = (n_elite+1):pop_size
            % 锦标赛选择父代1
            p1 = tournament_select(pop, fitness, tournament_k);
            % 锦标赛选择父代2
            p2 = tournament_select(pop, fitness, tournament_k);

            % 交叉
            if rand() < pc
                child = crossover(p1, p2, n_drones);
            else
                child = p1;
            end

            % 变异
            if rand() < pm
                child = mutate(child, n_drones, m);
            end

            new_pop{p} = child;
            new_fit(p) = calc_fitness(child, data, cfg, dep);
        end

        pop = new_pop;
        fitness = new_fit;

        % 更新全局最优
        [gen_best, gen_best_idx] = min(fitness);
        if gen_best < best_fitness
            best_fitness = gen_best;
            best_ever = pop{gen_best_idx};
        end

        if mod(gen, 50) == 0
            fprintf('  GA gen %d: best=%.1f\n', gen, best_fitness);
        end
    end

    sol = assignment_to_sol(best_ever, data, cfg, dep);
    fprintf('  GA 最终: 成本=%.1f, 启用=%d架\n', sol.total_cost, sol.n_enabled);
end

%% === 辅助函数 ===

function fit = calc_fitness(assignment, data, cfg, dep)
% 计算适应度（成本越低越好）
    [cost, ~, ~, ~] = eval_solution(assignment, data, cfg, dep);
    fit = cost;
end

function parent = tournament_select(pop, fitness, k)
% 锦标赛选择：随机选k个，取最优
    pop_size = length(pop);
    idx = randperm(pop_size, k);
    [~, best_local] = min(fitness(idx));
    parent = pop{idx(best_local)};
end

function child = crossover(p1, p2, n_drones)
% 均匀交叉：每个订单随机选一个父代的分配
    m = length(p1);
    child = zeros(1, m);
    for j = 1:m
        if rand() < 0.5
            child(j) = p1(j);
        else
            child(j) = p2(j);
        end
    end
    % 确保至少有一架无人机被使用
    if all(child == 0)
        child(randi(m)) = randi(n_drones);
    end
end

function assignment = mutate(assignment, n_drones, m)
% 变异：随机选一种操作
    r = rand();
    if r < 0.4
        % 单点变异：随机改变一个订单的无人机
        j = randi(m);
        assignment(j) = randi(n_drones);
    elseif r < 0.7
        % 双点交换：交换两个订单的无人机
        j1 = randi(m);
        j2 = randi(m);
        if j1 ~= j2
            temp = assignment(j1);
            assignment(j1) = assignment(j2);
            assignment(j2) = temp;
        end
    else
        % 随机打乱一架无人机的所有订单分配
        d = randi(n_drones);
        idx = find(assignment == d);
        if length(idx) > 1
            % 将这些订单随机分配给不同无人机
            for k = 1:length(idx)
                assignment(idx(k)) = randi(n_drones);
            end
        end
    end
end

function assignment = random_assignment(n_drones, m)
% 生成随机分配（每架无人机至少有概率被选中）
    assignment = zeros(1, m);
    % 先随机选2-4架无人机作为"活跃"无人机
    n_active = randi([2, min(4, n_drones)]);
    active_drones = randperm(n_drones, n_active);
    for j = 1:m
        assignment(j) = active_drones(randi(n_active));
    end
end

function assignment = sol_to_assignment(sol, n_drones, m)
% 解向量转换
    assignment = zeros(1, m);
    for r = 1:length(sol.routes)
        route = sol.routes{r};
        for jj = route.orders
            assignment(jj) = route.drone;
        end
    end
end

function sol = assignment_to_sol(assignment, data, cfg, dep)
% 分配向量转解结构（使用实际飞行距离）
    n_drones = cfg.n_drones;
    drone_orders = cell(n_drones, 1);
    for j = 1:length(assignment)
        d = assignment(j);
        if d > 0 && d <= n_drones
            drone_orders{d} = [drone_orders{d}, j];
        end
    end

    sol.routes = {};
    sol.n_enabled = 0;
    sol.total_time = 0;
    sol.total_late = 0;

    for i = 1:n_drones
        if isempty(drone_orders{i}), continue; end
        sol.n_enabled = sol.n_enabled + 1;

        orders_d = drone_orders{i};
        S_vals = [data.orders(orders_d).S];
        [~, sidx] = sort(S_vals);
        orders_d = orders_d(sidx);

        % 选最近起降点（用实际距离）
        best_dep_idx = 1;
        best_dep_dist = inf;
        for dd = 1:length(dep)
            dep_node_idx = find(strcmp(data.node_ids, dep(dd).id));
            total_d = 0;
            for kk = 1:length(orders_d)
                pk = find(strcmp(data.node_ids, data.orders(orders_d(kk)).pickup_id));
                total_d = total_d + data.dist(dep_node_idx, pk);
            end
            if total_d < best_dep_dist
                best_dep_dist = total_d;
                best_dep_idx = dd;
            end
        end
        drone_dep = dep(best_dep_idx);
        depot_idx = find(strcmp(data.node_ids, drone_dep.id));

        drone_time = 0;
        cur_node = depot_idx;
        trip_load = 0;
        trip_fly = 0;
        trip_late = 0;
        trip_details = {};

        for kk = 1:length(orders_d)
            j = orders_d(kk);

            % 载重检查：超重则返回起降点开新趟
            if trip_load + data.orders(j).weight > cfg.W_max
                d_ret = data.dist(cur_node, depot_idx);
                t_ret = d_ret/(cfg.v_cruise*3600);
                sol.total_time = sol.total_time + trip_fly + t_ret;
                sol.total_late = sol.total_late + trip_late;
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
        sol.total_time = sol.total_time + trip_fly + t_ret;
        sol.total_late = sol.total_late + trip_late;

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

    sol.total_cost = sol.n_enabled * cfg.enable_cost + ...
                     sum(cellfun(@(r) r.cost, sol.routes));
end
