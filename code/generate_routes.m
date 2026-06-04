function routes = generate_routes(data, cfg)
% GENERATE_ROUTES 为每架无人机生成候选调度方案
%   简化版: 每条候选路线 = 一趟配送（驿站→若干配送点→驿站）
%   所有无人机共享同一组候选路线

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

    % 每架无人机共享
    routes = cell(cfg.n_drones, 1);
    for i = 1:cfg.n_drones
        routes{i} = schemes;
    end

    fprintf('    候选方案: %d 条\n', length(schemes));

    % 验证覆盖
    covered = zeros(1, m);
    for s = 1:length(schemes)
        covered = covered | schemes{s}.A;
    end
    uncovered = find(~covered);
    if ~isempty(uncovered)
        fprintf('    ⚠ 快递 %s 无覆盖\n', mat2str(uncovered));
    else
        fprintf('    ✓ 全部 %d 件快递均有覆盖\n', m);
    end
end

% ====================================================================
% 最近邻排序
% ====================================================================
function seq = nearest_neighbor_seq(order_ids, data)
    remaining = order_ids;
    seq = [];
    current_pos = [data.station.x, data.station.y];
    while ~isempty(remaining)
        best_dist = inf;
        best_idx = 1;
        for k = 1:length(remaining)
            pt_id = data.orders(remaining(k)).point_id;
            d = norm(current_pos - [data.points(pt_id).x, data.points(pt_id).y]);
            if d < best_dist
                best_dist = d;
                best_idx = k;
            end
        end
        seq = [seq, remaining(best_idx)];
        pt_id = data.orders(remaining(best_idx)).point_id;
        current_pos = [data.points(pt_id).x, data.points(pt_id).y];
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
    elapsed_time_h = cfg.t_prep_min / 60;
    total_energy_wh = 0;
    total_late_h = 0;
    current_load_kg = sum([data.orders(seq).weight]);

    cx = data.station.x;
    cy = data.station.y;

    for k = 1:m_orders
        j = seq(k);
        pt_id = data.orders(j).point_id;
        px = data.points(pt_id).x;
        py = data.points(pt_id).y;

        d = norm([cx, cy] - [px, py]);
        [t_seg, e_seg] = calc_cost_segment(d, current_load_kg, cfg);
        flight_time_h = flight_time_h + t_seg;
        elapsed_time_h = elapsed_time_h + t_seg;
        total_energy_wh = total_energy_wh + e_seg;

        arrive_time = data.orders(j).S + elapsed_time_h;
        if arrive_time < data.orders(j).a
            elapsed_time_h = elapsed_time_h + (data.orders(j).a - arrive_time);
            arrive_time = data.orders(j).a;
        end
        if arrive_time > data.orders(j).b
            total_late_h = total_late_h + (arrive_time - data.orders(j).b);
        end

        current_load_kg = current_load_kg - data.orders(j).weight;
        cx = px;
        cy = py;
    end

    d_return = norm([cx, cy] - [data.station.x, data.station.y]);
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
