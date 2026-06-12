function [cost, total_energy, total_late, valid] = eval_solution(assignment, data, cfg, dep)
% EVAL_SOLUTION 统一的严格评估函数（队列装箱版）
%   硬性约束：
%   1. 所有订单必须被分配
%   2. 载重超限：采用队列装箱，超重订单顺延至该无人机的下一趟
%   3. 电池约束：单趟能耗 > E_max → 触发当前节点换电（加换电成本）
%   4. 时间窗约束：早于a_j等待，晚于b_j记录超时累积

    n_drones = cfg.n_drones;
    m = data.n_orders;

    if any(assignment <= 0) || any(assignment > n_drones)
        cost = 1e9; total_energy = 0; total_late = 0; valid = false;
        return;
    end

    drone_orders = cell(n_drones, 1);
    for j = 1:length(assignment)
        d = assignment(j);
        drone_orders{d} = [drone_orders{d}, j];
    end

    total_energy = 0;
    total_late = 0;
    total_swaps = 0;
    delivered = false(1, m);

    for i = 1:n_drones
        if isempty(drone_orders{i}), continue; end

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

        % === 双层队列：趟次规划与执行 ===
        unassigned_queue = orders_d;
        cur_node = depot_idx;
        drone_time = 0;

        while ~isempty(unassigned_queue)
            current_trip_orders = [];
            next_trip_queue = [];
            trip_load = 0;

            % 1. 贪心装箱：尝试装满当前这趟
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

            trip_fly = 0;
            trip_energy = 0;
            trip_late = 0;

            % 2. 执行本趟订单配送
            for kk = 1:length(current_trip_orders)
                j = current_trip_orders(kk);
                pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
                dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));

                d1 = data.dist(cur_node, pk);
                d2 = data.dist(pk, dk);
                tf1 = d1 / (cfg.v_cruise * 3600);
                tf2 = d2 / (cfg.v_cruise * 3600);
                td = cfg.t_deliver_min / 60;

                e_empty = cfg.e0 * d1;
                e_loaded = (cfg.e0 + cfg.e1 * data.orders(j).weight) * d2;
                e_segment = e_empty + e_loaded;

                % 能耗超限 → 当前节点换电
                if trip_energy + e_segment > cfg.E_max
                    total_energy = total_energy + trip_energy;
                    total_late = total_late + trip_late;
                    total_swaps = total_swaps + 1;
                    drone_time = drone_time + cfg.t_swap_min/60;
                    trip_energy = 0; trip_late = 0; trip_fly = 0;

                    % 重新计算
                    d1 = data.dist(cur_node, pk);
                    tf1 = d1 / (cfg.v_cruise * 3600);
                    e_empty = cfg.e0 * d1;
                    e_loaded = (cfg.e0 + cfg.e1 * data.orders(j).weight) * d2;
                    e_segment = e_empty + e_loaded;
                end

                % 时间窗
                depart = max(data.orders(j).S, drone_time);
                arrive = depart + tf1 + tf2 + td;
                if arrive < data.orders(j).a, arrive = data.orders(j).a; end

                trip_late_here = max(0, arrive - data.orders(j).b);
                trip_late = trip_late + trip_late_here;

                drone_time = arrive;
                trip_fly = trip_fly + tf1 + tf2 + td;
                trip_energy = trip_energy + e_segment;
                cur_node = dk;
                delivered(j) = true;
            end

            % 3. 一趟结束，返回起降点补电/补货
            d_ret = data.dist(cur_node, depot_idx);
            e_ret = cfg.e0 * d_ret;
            t_ret = d_ret / (cfg.v_cruise * 3600);

            total_energy = total_energy + trip_energy + e_ret;
            total_late = total_late + trip_late;
            drone_time = drone_time + t_ret + cfg.t_swap_min/60;

            cur_node = depot_idx;
            unassigned_queue = next_trip_queue;
        end
    end

    n_enabled = sum(cellfun(@(x) ~isempty(x), drone_orders));

    if ~all(delivered)
        cost = 1e9; total_energy = 0; total_late = 0; valid = false;
        return;
    end

    cost = n_enabled * cfg.enable_cost + cfg.alpha * total_energy + cfg.gamma * total_late + cfg.swap_cost * total_swaps;
    valid = true;
end
