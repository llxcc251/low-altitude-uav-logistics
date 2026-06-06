function routes = generate_routes(data, cfg)
% GENERATE_ROUTES 为每架无人机生成候选调度方案
%   支持多趟连续配送：每架无人机可以执行 1~2 趟
%   路线结构: (起降点 -> 取货 -> 配送 -> 起降点) x K 趟

    m = data.n_orders;
    max_q = min(cfg.max_orders_per_trip, m);

    % === 第一步：枚举所有可行的单趟路线 ===
    fprintf('  枚举可行单趟路线...\n');
    feasible_trips = {};

    for q = 1:max_q
        combos = nchoosek(1:m, q);
        for c = 1:size(combos, 1)
            order_ids = combos(c, :);
            total_weight = sum([data.orders(order_ids).weight]);
            if total_weight > cfg.W_max
                continue;
            end
            seq = nearest_neighbor_seq(order_ids, data);
            [ok, trip] = evaluate_trip(seq, data, cfg);
            if ok
                feasible_trips{end+1} = trip;
            end
        end
    end
    fprintf('    可行单趟路线: %d 条\n', length(feasible_trips));

    % === 第二步：按时间排序，贪心组合多趟方案 ===
    % 根据电池容量自动决定能飞几趟
    fprintf('  组合多趟方案（按电池容量自动决定趟数）...\n');
    schemes = {};

    % 按首单出发时间排序
    trip_starts = zeros(1, length(feasible_trips));
    for t = 1:length(feasible_trips)
        trip_starts(t) = min(feasible_trips{t}.order_S);
    end
    [~, sort_idx] = sort(trip_starts);
    feasible_trips = feasible_trips(sort_idx);

    % 贪心组合：从每条单趟路线出发，尝试追加后续路线
    for start = 1:length(feasible_trips)
        % 尝试 1 趟、2 趟、3 趟...直到超电池
        for n_t = 1:min(4, length(feasible_trips) - start + 1)
            trip_range = start:start+n_t-1;
            selected = feasible_trips(trip_range);
            [ok, scheme] = check_multi_trip(selected, data, cfg);
            if ok
                schemes{end+1} = scheme;
            else
                break;  % 超电池/超时，不再追加
            end
        end
    end

    % 每架无人机共享
    routes = cell(cfg.n_drones, 1);
    for i = 1:cfg.n_drones
        routes{i} = schemes;
    end

    fprintf('    候选方案: %d 条\n', length(schemes));

    covered = zeros(1, m);
    for s = 1:length(schemes)
        covered = covered | schemes{s}.A;
    end
    uncovered = find(~covered);
    if ~isempty(uncovered)
        fprintf('    警告: 快递 %s 无覆盖\n', mat2str(uncovered));
    else
        fprintf('    全部 %d 件快递均有覆盖\n', m);
    end
end

% ====================================================================
% 最近邻排序（自动选最近起降点）
% ====================================================================
function seq = nearest_neighbor_seq(order_ids, data)
    remaining = order_ids;
    seq = [];
    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    best_dist = inf;
    best_dep = depot_idx(1);
    for d = 1:length(depot_idx)
        dx = data.nodes(depot_idx(d)).x;
        dy = data.nodes(depot_idx(d)).y;
        total_d = 0;
        for k = 1:length(order_ids)
            pk = find(strcmp(data.node_ids, data.orders(order_ids(k)).pickup_id));
            total_d = total_d + norm([dx, dy] - [data.node_x(pk), data.node_y(pk)]);
        end
        if total_d < best_dist
            best_dist = total_d;
            best_dep = depot_idx(d);
        end
    end
    cx = data.nodes(best_dep).x;
    cy = data.nodes(best_dep).y;

    while ~isempty(remaining)
        best_dist = inf;
        best_idx = 1;
        for k = 1:length(remaining)
            pk = find(strcmp(data.node_ids, data.orders(remaining(k)).pickup_id));
            d = norm([cx, cy] - [data.node_x(pk), data.node_y(pk)]);
            if d < best_dist
                best_dist = d;
                best_idx = k;
            end
        end
        seq = [seq, remaining(best_idx)];
        pk = find(strcmp(data.node_ids, data.orders(remaining(best_idx)).pickup_id));
        cx = data.node_x(pk);
        cy = data.node_y(pk);
        remaining(best_idx) = [];
    end
end

% ====================================================================
% 评估单趟路线
% ====================================================================
function [ok, trip] = evaluate_trip(seq, data, cfg)
    ok = false;
    trip = struct();

    m_orders = length(seq);
    flight_time_h = 0;
    elapsed_time_h = 0;
    total_late_h = 0;
    current_load_kg = sum([data.orders(seq).weight]);

    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    best_dist = inf;
    best_dep = depot_idx(1);
    for d = 1:length(depot_idx)
        dx = data.nodes(depot_idx(d)).x;
        dy = data.nodes(depot_idx(d)).y;
        total_d = 0;
        for k = 1:length(seq)
            pk = find(strcmp(data.node_ids, data.orders(seq(k)).pickup_id));
            total_d = total_d + norm([dx, dy] - [data.node_x(pk), data.node_y(pk)]);
        end
        if total_d < best_dist
            best_dist = total_d;
            best_dep = depot_idx(d);
        end
    end
    cx = data.nodes(best_dep).x;
    cy = data.nodes(best_dep).y;

    for k = 1:m_orders
        j = seq(k);
        pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
        ppx = data.node_x(pk);
        ppy = data.node_y(pk);

        % 飞到取货点
        d1 = norm([cx, cy] - [ppx, ppy]);
        t1 = calc_cost_segment(d1, 0, cfg);
        flight_time_h = flight_time_h + t1;
        elapsed_time_h = elapsed_time_h + t1;

        % 飞到配送点
        dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));
        dkx = data.node_x(dk);
        dky = data.node_y(dk);
        d2 = norm([ppx, ppy] - [dkx, dky]);
        t2 = calc_cost_segment(d2, 0, cfg);
        flight_time_h = flight_time_h + t2;
        elapsed_time_h = elapsed_time_h + t2;

        % 送货耗时
        elapsed_time_h = elapsed_time_h + cfg.t_deliver_min / 60;

        % 到达时间检查
        arrive_time = data.orders(j).S + elapsed_time_h;
        if arrive_time < data.orders(j).a
            elapsed_time_h = elapsed_time_h + (data.orders(j).a - arrive_time);
            arrive_time = data.orders(j).a;
        end
        if arrive_time > data.orders(j).b
            total_late_h = total_late_h + (arrive_time - data.orders(j).b);
        end

        current_load_kg = current_load_kg - data.orders(j).weight;
        cx = dkx;
        cy = dky;
    end

    % 返回起降点
    d_return = norm([cx, cy] - [data.nodes(best_dep).x, data.nodes(best_dep).y]);
    t_ret = calc_cost_segment(d_return, 0, cfg);
    flight_time_h = flight_time_h + t_ret;
    elapsed_time_h = elapsed_time_h + t_ret;

    ok = true;
    trip.seq = seq;
    trip.order_ids = seq;
    trip.order_S = [data.orders(seq).S];
    trip.time_h = elapsed_time_h;
    trip.flight_h = flight_time_h;
    trip.late_h = total_late_h;
    trip.depot = best_dep;
end

% ====================================================================
% 检查多趟方案可行性（绝对时间线）
% ====================================================================
function [ok, scheme] = check_multi_trip(selected_trips, data, cfg)
    ok = false;
    scheme = struct();

    % 检查订单不重复
    all_orders = [];
    for t = 1:length(selected_trips)
        all_orders = [all_orders, selected_trips{t}.order_ids];
    end
    if length(all_orders) ~= length(unique(all_orders))
        return;
    end

    % 按首单出发时间排序
    starts = zeros(1, length(selected_trips));
    for t = 1:length(selected_trips)
        starts(t) = min(selected_trips{t}.order_S);
    end
    [~, sort_idx] = sort(starts);
    selected_trips = selected_trips(sort_idx);

    % 绝对时间线检查
    current_time = 0;
    total_flight_h = 0;
    block_out_h = 0;  % 当前电池块在基地外已用时间（飞行+取货+送货+等待+返回）
    total_late_h = 0;

    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    dep = data.nodes(depot_idx(1));

    for t = 1:length(selected_trips)
        trip = selected_trips{t};

        % 估算本趟在基地外的时间（飞行+送货+等待）
        trip_out_h = trip.time_h;  % 已包含飞行+送货+等待

        % 检查本趟是否超过当前电池块剩余时间
        if block_out_h + trip_out_h > cfg.t_max_h
            % 时间不够，需要换电池
            current_time = current_time + cfg.t_swap_min / 60;
            block_out_h = 0;  % 新电池块
        end

        % 跳到该趟最早可出发时间
        trip_min_S = min(trip.order_S);
        if current_time < trip_min_S
            current_time = trip_min_S;
        end

        cx = dep.x;
        cy = dep.y;

        for k = 1:length(trip.seq)
            j = trip.seq(k);
            pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
            dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));

            % 飞到取货点
            ppx = data.node_x(pk); ppy = data.node_y(pk);
            d1 = norm([cx, cy] - [ppx, ppy]);
            t1 = calc_cost_segment(d1, 0, cfg);
            total_flight_h = total_flight_h + t1;
            block_out_h = block_out_h + t1;
            current_time = current_time + t1;

            % 飞到配送点
            dkx = data.node_x(dk); dky = data.node_y(dk);
            d2 = norm([ppx, ppy] - [dkx, dky]);
            t2 = calc_cost_segment(d2, 0, cfg);
            total_flight_h = total_flight_h + t2;
            block_out_h = block_out_h + t2;
            current_time = current_time + t2;

            % 送货耗时
            current_time = current_time + cfg.t_deliver_min / 60;
            block_out_h = block_out_h + cfg.t_deliver_min / 60;

            % 时间窗检查（等待时间也计入基地外时间）
            arrive = current_time;
            if arrive < data.orders(j).a
                wait_h = data.orders(j).a - arrive;
                current_time = data.orders(j).a;
                block_out_h = block_out_h + wait_h;
            end
            if arrive > data.orders(j).b
                total_late_h = total_late_h + (arrive - data.orders(j).b);
            end

            cx = dkx;
            cy = dky;
        end

        % 返回起降点
        d_ret = norm([cx, cy] - [dep.x, dep.y]);
        t_ret = calc_cost_segment(d_ret, 0, cfg);
        total_flight_h = total_flight_h + t_ret;
        block_out_h = block_out_h + t_ret;
        current_time = current_time + t_ret;
    end

    ok = true;
    scheme.trips = selected_trips;
    scheme.n_trips = length(selected_trips);
    scheme.order_ids = all_orders;
    scheme.A = zeros(1, data.n_orders);
    scheme.A(all_orders) = 1;
    scheme.T = current_time;
    scheme.L = total_late_h;
    scheme.C = cfg.alpha * current_time + cfg.gamma * total_late_h;
end
