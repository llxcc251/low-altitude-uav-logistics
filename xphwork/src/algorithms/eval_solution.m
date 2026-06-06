function [cost, total_time, total_late, valid] = eval_solution(assignment, data, cfg, dep)
% EVAL_SOLUTION 统一的严格评估函数（使用实际飞行距离）
%   支持一趟多单（VRP拼单）：
%   - 无人机从起降点出发，连续飞往多个取货-配送点对
%   - 送完一件后直接飞下一件的取货点（不回基地）
%   - 超过载重或电池限制才返回起降点
%   - 每件订单的到达时间 = 出发时间 + 飞行 + 送货

    n_drones = cfg.n_drones;
    m = data.n_orders;

    % === 硬性约束 1：所有订单必须被分配 ===
    if any(assignment <= 0) || any(assignment > n_drones)
        cost = 1e9; total_time = 0; total_late = 0; valid = false;
        return;
    end

    drone_orders = cell(n_drones, 1);
    for j = 1:length(assignment)
        d = assignment(j);
        drone_orders{d} = [drone_orders{d}, j];
    end

    total_time = 0;
    total_late = 0;
    valid = true;

    for i = 1:n_drones
        if isempty(drone_orders{i}), continue; end

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

        % === 趟内逐件顺序处理 ===
        cur_node = depot_idx;
        drone_time = 0;       % 无人机当前可用时间
        trip_load = 0;        % 当前趟载重
        trip_fly = 0;         % 当前趟飞行时间
        trip_late = 0;        % 当前趟超时

        for kk = 1:length(orders_d)
            j = orders_d(kk);

            % 预计算飞行距离（用于载重/电池检查）
            pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
            dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));

            d1 = data.dist(cur_node, pk);
            d2 = data.dist(pk, dk);
            d_ret_j = data.dist(dk, depot_idx);
            tf1 = d1 / (cfg.v_cruise * 3600);
            tf2 = d2 / (cfg.v_cruise * 3600);
            td = cfg.t_deliver_min / 60;
            t_ret_j = d_ret_j / (cfg.v_cruise * 3600);

            % === 硬性约束 2 & 3：载重或电池超限 → 返回起降点开新趟 ===
            need_new_trip = false;
            if trip_load + data.orders(j).weight > cfg.W_max
                need_new_trip = true;
            end
            if trip_fly + tf1 + tf2 + td + t_ret_j > cfg.t_max_h
                need_new_trip = true;
            end

            if need_new_trip
                % 返回起降点
                d_ret = data.dist(cur_node, depot_idx);
                t_ret = d_ret / (cfg.v_cruise * 3600);
                total_time = total_time + trip_fly + t_ret;
                total_late = total_late + trip_late;
                drone_time = drone_time + trip_fly + t_ret + cfg.t_swap_min/60;

                % 开新趟后重新计算距离（从起降点出发）
                cur_node = depot_idx;
                trip_load = 0;
                trip_fly = 0;
                trip_late = 0;

                d1 = data.dist(cur_node, pk);
                tf1 = d1 / (cfg.v_cruise * 3600);
            end

            % === 硬性约束 4：出发时间逻辑 ===
            depart = max(data.orders(j).S, drone_time);
            arrive = depart + tf1 + tf2 + td;

            % 超时
            trip_late_here = max(0, arrive - data.orders(j).b);
            trip_late = trip_late + trip_late_here;

            % 更新状态
            drone_time = depart + tf1 + tf2 + td;
            trip_fly = trip_fly + tf1 + tf2 + td;
            trip_load = trip_load + data.orders(j).weight;
            cur_node = dk;
        end

        % 最后一趟返回起降点
        d_ret = data.dist(cur_node, depot_idx);
        t_ret = d_ret / (cfg.v_cruise * 3600);
        total_time = total_time + trip_fly + t_ret;
        total_late = total_late + trip_late;
    end

    n_enabled = sum(cellfun(@(x) ~isempty(x), drone_orders));
    cost = n_enabled * cfg.enable_cost + cfg.alpha * total_time + cfg.gamma * total_late;
end
