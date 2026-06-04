function routes = generate_routes(data, cfg)
% GENERATE_ROUTES 为每架无人机生成候选调度方案
%   支持多个起降点：每条路线从最近的起降点出发并返回
%   路线结构: 起降点 -> (取货->配送) x N -> 起降点

    m = data.n_orders;
    max_q = min(cfg.max_orders_per_trip, m);

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

    % 转为候选方案格式
    schemes = {};
    for t = 1:length(feasible_trips)
        trip = feasible_trips{t};
        scheme = struct();
        scheme.trips = {trip};
        scheme.n_trips = 1;
        scheme.order_ids = trip.order_ids;
        scheme.A = trip.A;
        scheme.T = trip.time_h;
        scheme.E = trip.energy_wh;
        scheme.L = trip.late_h;
        scheme.C = cfg.alpha * trip.time_h + cfg.beta * trip.energy_wh + cfg.gamma * trip.late_h;
        schemes{end+1} = scheme;
    end

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

    % 找最近的起降点作为起点
    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    best_dist = inf;
    best_dep = depot_idx(1);
    for d = 1:length(depot_idx)
        dx = data.nodes(depot_idx(d)).x;
        dy = data.nodes(depot_idx(d)).y;
        % 算到所有待送订单取货点的总距离
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
            j = remaining(k);
            pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
            px = data.node_x(pk);
            py = data.node_y(pk);
            d = norm([cx, cy] - [px, py]);
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
%   路径: 起降点 -> (取货->配送) x N -> 起降点
% ====================================================================
function [ok, trip] = evaluate_trip(seq, data, cfg)
    ok = false;
    trip = struct();

    m_orders = length(seq);
    flight_time_h = 0;
    elapsed_time_h = cfg.t_prep_min / 60;
    total_energy_wh = 0;
    total_late_h = 0;
    current_load_kg = sum([data.orders(seq).weight]);

    % 自动选最近起降点
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

        % 飞到取货点
        pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
        ppx = data.node_x(pk);
        ppy = data.node_y(pk);
        d1 = norm([cx, cy] - [ppx, ppy]);
        [t1, e1] = calc_cost_segment(d1, current_load_kg, cfg);
        flight_time_h = flight_time_h + t1;
        elapsed_time_h = elapsed_time_h + t1;
        total_energy_wh = total_energy_wh + e1;

        % 飞到配送点
        dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));
        dkx = data.node_x(dk);
        dky = data.node_y(dk);
        d2 = norm([ppx, ppy] - [dkx, dky]);
        [t2, e2] = calc_cost_segment(d2, current_load_kg, cfg);
        flight_time_h = flight_time_h + t2;
        elapsed_time_h = elapsed_time_h + t2;
        total_energy_wh = total_energy_wh + e2;

        % 到达时间
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
    [t_ret, e_ret] = calc_cost_segment(d_return, 0, cfg);
    flight_time_h = flight_time_h + t_ret;
    elapsed_time_h = elapsed_time_h + t_ret;
    total_energy_wh = total_energy_wh + e_ret;

    if total_energy_wh > cfg.E_battery
        return;
    end
    if flight_time_h > cfg.t_max_min / 60
        return;
    end

    ok = true;
    trip.seq = seq;
    trip.order_ids = seq;
    trip.A = zeros(1, data.n_orders);
    trip.A(seq) = 1;
    trip.time_h = elapsed_time_h;
    trip.energy_wh = total_energy_wh;
    trip.late_h = total_late_h;
end
