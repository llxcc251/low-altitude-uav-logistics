function sol = simulated_annealing(data, cfg)
% SIMULATED_ANNEALING 模拟退火算法（重构版）
%   1. 按时间窗排序初始化
%   2. 邻域搜索限制在时间相近的订单之间
%   3. 空路线惩罚

    n_drones = cfg.n_drones;
    m = data.n_orders;
    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    dep = data.nodes(depot_idx);  % 所有起降点

    % === 用随机算法的最佳解作为初始解 ===
    init_sol = random_search(data, cfg, 150);
    current = sol_to_assignment(init_sol, n_drones, m);
    current_cost = calc_cost(current, data, cfg, dep);
    fprintf('  SA 初始: 成本=%.1f, 启用=%d架\n', current_cost, init_sol.n_enabled);

    best = current;
    best_cost = current_cost;

    % 退火参数
    T = 50; T_min = 0.1; alpha = 0.93; max_iter = 200;
    K = 5;

    % 构建时间邻域表：按时间窗排序
    a_vals = [data.orders.a];
    [~, sort_idx] = sort(a_vals);
    time_order = sort_idx;
    pos_of = zeros(1, m);  % pos_of(j) = 订单 j 在排序序列中的位置
    for p = 1:m
        pos_of(time_order(p)) = p;
    end

    while T > T_min
        for iter = 1:max_iter
            r = rand();
            if r < 0.45
                % Swap (45%): 交换两个时间相近的订单
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
                % Insert (30%): 把一个订单移到另一架无人机
                j1 = randi(m);
                d1 = current(j1);
                d2 = randi(n_drones);
                if d1 == d2, continue; end
                candidate = current;
                candidate(j1) = d2;

            elseif r < 0.90
                % Reorder (15%): 打乱一架无人机的订单顺序
                d = randi(n_drones);
                idx = find(current == d);
                if length(idx) < 2, continue; end
                candidate = current;
                shuffle = idx(randperm(length(idx)));
                candidate(idx) = shuffle;

            else
                % Merge (10%): 合并两架无人机
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

            % 拒绝非法解（成本=1e9 表示约束违反）
            if cc >= 1e9
                continue;
            end

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
% CALC_COST 调用统一评估函数
    [cost, ~, ~, ~] = eval_solution(assignment, data, cfg, dep);
end

function sol = assignment_to_sol(assignment, data, cfg, dep)
    n_drones = cfg.n_drones;
    drone_orders = cell(n_drones, 1);
    for j = 1:length(assignment)
        d = assignment(j);
        if d > 0 && d <= n_drones, drone_orders{d} = [drone_orders{d}, j]; end
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

        % 选最近起降点
        best_dep_idx = 1;
        best_dep_dist = inf;
        for dd = 1:length(dep)
            dx = dep(dd).x; dy = dep(dd).y;
            total_d = 0;
            for kk = 1:length(orders_d)
                pk = find(strcmp(data.node_ids, data.orders(orders_d(kk)).pickup_id));
                total_d = total_d + norm([dx,dy] - [data.node_x(pk), data.node_y(pk)]);
            end
            if total_d < best_dep_dist
                best_dep_dist = total_d;
                best_dep_idx = dd;
            end
        end
        drone_dep = dep(best_dep_idx);

        drone_time = 0; cx = drone_dep.x; cy = drone_dep.y;
        trip_load = 0; trip_fly = 0; trip_late = 0; trip_details = {};

        for kk = 1:length(orders_d)
            j = orders_d(kk);

            % 载重检查：超重则返回起降点开新趟
            if trip_load + data.orders(j).weight > cfg.W_max
                d_ret = norm([cx,cy]-[drone_dep.x,drone_dep.y]);
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

                cx = drone_dep.x; cy = drone_dep.y;
                trip_load = 0; trip_fly = 0; trip_late = 0; trip_details = {};
            end

            pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
            dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));
            px = data.node_x(pk); py = data.node_y(pk);
            dx = data.node_x(dk); dy = data.node_y(dk);

            d1 = norm([cx,cy]-[px,py]); d2 = norm([px,py]-[dx,dy]);
            tf1 = d1/(cfg.v_cruise*3600); tf2 = d2/(cfg.v_cruise*3600);
            td = cfg.t_deliver_min/60;

            depart = max(data.orders(j).S, drone_time);
            arrive = depart + tf1 + tf2 + td;
            trip_late_here = max(0, arrive - data.orders(j).b);

            drone_time = depart + tf1 + tf2 + td;
            trip_fly = trip_fly + tf1 + tf2 + td;
            trip_load = trip_load + data.orders(j).weight;
            trip_late = trip_late + trip_late_here;
            cx = dx; cy = dy;

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
        d_ret = norm([cx,cy]-[drone_dep.x,drone_dep.y]);
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
