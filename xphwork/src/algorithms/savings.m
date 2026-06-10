function sol = savings(data, cfg)
% SAVINGS 节约算法（能耗版，使用data.dist）

    m = data.n_orders;
    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    dep = data.nodes(depot_idx(1));
    dep_node = find(strcmp(data.node_ids, dep.id));

    % 初始：每件快递单独一条路线
    route_of = 1:m;
    route_orders = cell(m, 1);
    for j = 1:m
        route_orders{j} = j;
    end

    % 计算所有订单对的合并收益
    pairs = [];
    for i = 1:m
        for j = i+1:m
            t_i = data.orders(i).S;
            t_j = data.orders(j).S;
            time_diff = abs(t_i - t_j);

            pi = find(strcmp(data.node_ids, data.orders(i).pickup_id));
            pj = find(strcmp(data.node_ids, data.orders(j).pickup_id));
            di = find(strcmp(data.node_ids, data.orders(i).delivery_id));
            dj = find(strcmp(data.node_ids, data.orders(j).delivery_id));

            d_pickup = data.dist(pi, pj);
            d_del = data.dist(di, dj);

            benefit = 1000 / (1 + d_pickup + d_del + time_diff * 100);
            pairs = [pairs; benefit, i, j];
        end
    end

    [~, sort_idx] = sort(pairs(:,1), 'descend');
    pairs = pairs(sort_idx, :);

    % 合并
    for p = 1:size(pairs, 1)
        i = pairs(p, 2);
        j = pairs(p, 3);
        ri = route_of(i);
        rj = route_of(j);
        if ri == rj, continue; end

        new_orders = [route_orders{ri}, route_orders{rj}];
        total_w = sum([data.orders(new_orders).weight]);
        if total_w > cfg.W_max, continue; end

        % 检查能耗
        [energy, ~] = calc_route_energy(new_orders, data, cfg, dep_node);
        if energy > cfg.E_max, continue; end

        route_orders{ri} = new_orders;
        route_orders{rj} = [];
        route_of(route_of == rj) = ri;
    end

    % 找出有效路线
    valid_routes = {};
    for r = 1:m
        if ~isempty(route_orders{r})
            valid_routes{end+1} = route_orders{r};
        end
    end

    % 构造输出
    sol.routes = {};
    sol.n_enabled = 0;
    sol.total_energy = 0;
    sol.total_late = 0;

    for r = 1:length(valid_routes)
        sol.n_enabled = sol.n_enabled + 1;
        [energy, late] = eval_route(valid_routes{r}, data, cfg, dep_node);

        route.drone = sol.n_enabled;
        route.orders = valid_routes{r};
        route.trips = {valid_routes{r}};
        route.energy = energy;
        route.late = late;
        route.cost = cfg.alpha * energy + cfg.gamma * late;
        sol.routes{end+1} = route;
        sol.total_energy = sol.total_energy + energy;
        sol.total_late = sol.total_late + late;
    end

    sol.total_cost = sol.n_enabled * cfg.enable_cost + ...
                     sum(cellfun(@(r) r.cost, sol.routes));
end

function [energy, late] = calc_route_energy(order_ids, data, cfg, dep_node)
    energy = 0; late = 0;
    cur_node = dep_node;
    trip_load = 0;
    trip_energy = 0;
    drone_time = 0;

    for k = 1:length(order_ids)
        j = order_ids(k);
        pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
        dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));

        d1 = data.dist(cur_node, pk);
        d2 = data.dist(pk, dk);
        tf1 = d1 / (cfg.v_cruise * 3600);
        tf2 = d2 / (cfg.v_cruise * 3600);
        td = cfg.t_deliver_min / 60;

        e_empty = cfg.e0 * d1;
        e_loaded = (cfg.e0 + cfg.e1 * trip_load) * d2;
        e_segment = e_empty + e_loaded;

        % 检查是否需要换电
        d_ret_j = data.dist(dk, dep_node);
        t_ret_j = d_ret_j / (cfg.v_cruise * 3600);
        if trip_energy + e_segment > cfg.E_max || trip_load + data.orders(j).weight > cfg.W_max
            % 返回起降点
            e_ret = cfg.e0 * data.dist(cur_node, dep_node);
            energy = energy + trip_energy + e_ret;
            trip_energy = 0;
            trip_load = 0;
            cur_node = dep_node;
            drone_time = drone_time + cfg.t_swap_min / 60;
            % 重新计算
            d1 = data.dist(cur_node, pk);
            e_empty = cfg.e0 * d1;
            e_loaded = (cfg.e0 + cfg.e1 * trip_load) * d2;
            e_segment = e_empty + e_loaded;
        end

        depart = max(data.orders(j).S, drone_time);
        arrive = depart + d1/(cfg.v_cruise*3600) + d2/(cfg.v_cruise*3600) + td;
        if arrive < data.orders(j).a, arrive = data.orders(j).a; end
        late = late + max(0, arrive - data.orders(j).b);

        drone_time = arrive;
        trip_energy = trip_energy + e_segment;
        trip_load = trip_load + data.orders(j).weight;
        cur_node = dk;
    end

    % 返回起降点
    e_ret = cfg.e0 * data.dist(cur_node, dep_node);
    energy = energy + trip_energy + e_ret;
end

function [energy, late] = eval_route(order_ids, data, cfg, dep_node)
    [energy, late] = calc_route_energy(order_ids, data, cfg, dep_node);
end
