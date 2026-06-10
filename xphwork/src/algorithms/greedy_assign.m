function sol = greedy_assign(data, cfg)
% GREEDY_ASSIGN 贪心指派（能耗版）

    n_drones = cfg.n_drones;
    m = data.n_orders;

    depot_idx = find(strcmp({data.nodes.type}, 'depot'));

    drone_node = zeros(n_drones, 1);  % 无人机当前节点索引
    drone_dep = zeros(n_drones, 1);   % 无人机起降点索引
    drone_used = false(n_drones, 1);

    for i = 1:n_drones
        drone_dep(i) = depot_idx(1);
        drone_node(i) = depot_idx(1);
    end

    S_vals = [data.orders.S];
    [~, sort_idx] = sort(S_vals);
    order_sorted = sort_idx;

    all_routes = {};

    for k = 1:m
        j = order_sorted(k);
        pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
        dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));

        best_drone = -1;
        best_dist = inf;

        for i = 1:n_drones
            d_to_pickup = data.dist(drone_node(i), pk);
            d_return = data.dist(dk, drone_dep(i));
            trip_h = (d_to_pickup + data.dist(pk, dk) + d_return) / (cfg.v_cruise * 3600) + cfg.t_deliver_min/60;
            if d_to_pickup < best_dist
                best_dist = d_to_pickup;
                best_drone = i;
            end
        end

        if best_drone < 0, continue; end

        i = best_drone;
        drone_used(i) = true;
        dep = data.nodes(drone_dep(i));

        d_to_pickup = data.dist(drone_node(i), pk);
        d_pickup_to_del = data.dist(pk, dk);
        d_return = data.dist(dk, drone_dep(i));

        fly_time = (d_to_pickup + d_pickup_to_del) / (cfg.v_cruise * 3600) + cfg.t_deliver_min/60 + d_return / (cfg.v_cruise * 3600);
        arrive_h = data.orders(j).S + (d_to_pickup + d_pickup_to_del) / (cfg.v_cruise * 3600) + cfg.t_deliver_min/60;
        if arrive_h < data.orders(j).a
            arrive_h = data.orders(j).a;
        end

        % 能耗计算
        e_empty = cfg.e0 * d_to_pickup;
        e_loaded = (cfg.e0 + cfg.e1 * 0) * d_pickup_to_del;  % 当前载重为0（单件）
        e_return = cfg.e0 * d_return;
        energy = e_empty + e_loaded + e_return;

        detail.order_id = j;
        detail.pickup = data.orders(j).pickup_name;
        detail.delivery = data.orders(j).delivery_name;
        detail.weight = data.orders(j).weight;
        detail.start = dep.name;
        detail.arrive_h = arrive_h;
        detail.deadline_h = data.orders(j).b;

        route.drone = i;
        route.orders = j;
        route.trips = {j};
        route.time = fly_time;
        route.energy = energy;
        route.late = 0;
        route.cost = cfg.alpha * energy;
        route.depot_name = dep.name;
        route.details = {detail};
        all_routes{end+1} = route;

        drone_node(i) = dk;
    end

    sol.routes = all_routes;
    sol.n_enabled = sum(drone_used);
    sol.total_energy = sum(cellfun(@(r) r.energy, all_routes));
    sol.total_late = sum(cellfun(@(r) r.late, all_routes));
    sol.total_cost = sol.n_enabled * cfg.enable_cost + ...
                     sum(cellfun(@(r) r.cost, all_routes));
end
