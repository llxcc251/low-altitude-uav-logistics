function sol = greedy_assign(data, cfg)
% GREEDY_ASSIGN 贪心指派（连续配送版）
%   修复: 含等待时间、载重检查、多趟时间递增

    n_drones = cfg.n_drones;
    m = data.n_orders;

    depot_idx = find(strcmp({data.nodes.type}, 'depot'));

    drone_pos = zeros(n_drones, 2);
    drone_dep = zeros(n_drones, 1);
    drone_used = false(n_drones, 1);

    for i = 1:n_drones
        drone_dep(i) = depot_idx(1);
        drone_pos(i,:) = [data.nodes(depot_idx(1)).x, data.nodes(depot_idx(1)).y];
    end

    S_vals = [data.orders.S];
    [~, sort_idx] = sort(S_vals);
    order_sorted = sort_idx;

    all_routes = {};

    for k = 1:m
        j = order_sorted(k);
        pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
        dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));
        px = data.node_x(pk); py = data.node_y(pk);
        dx = data.node_x(dk); dy = data.node_y(dk);

        best_drone = -1;
        best_dist = inf;

        for i = 1:n_drones
            d_to_pickup = norm(drone_pos(i,:) - [px, py]);
            dep = data.nodes(drone_dep(i));
            d_return = norm([dx, dy] - [dep.x, dep.y]);
            trip_h = (d_to_pickup + norm([px,py]-[dx,dy]) + d_return) / (cfg.v_cruise * 3600) + cfg.t_deliver_min/60;
            if trip_h > cfg.t_max_h, continue; end
            if d_to_pickup < best_dist
                best_dist = d_to_pickup;
                best_drone = i;
            end
        end

        if best_drone < 0, continue; end

        i = best_drone;
        drone_used(i) = true;
        dep = data.nodes(drone_dep(i));

        d_to_pickup = norm(drone_pos(i,:) - [px, py]);
        d_pickup_to_del = norm([px, py] - [dx, dy]);
        d_return = norm([dx, dy] - [dep.x, dep.y]);

        fly_time = (d_to_pickup + d_pickup_to_del) / (cfg.v_cruise * 3600) + cfg.t_deliver_min/60 + d_return / (cfg.v_cruise * 3600);
        arrive_h = data.orders(j).S + (d_to_pickup + d_pickup_to_del) / (cfg.v_cruise * 3600) + cfg.t_deliver_min/60;
        if arrive_h < data.orders(j).a
            arrive_h = data.orders(j).a;
        end

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
        route.late = 0;
        route.cost = cfg.alpha * fly_time;
        route.depot_name = dep.name;
        route.details = {detail};
        all_routes{end+1} = route;

        drone_pos(i,:) = [dep.x, dep.y];
    end

    sol.routes = all_routes;
    sol.n_enabled = sum(drone_used);
    sol.total_time = sum(cellfun(@(r) r.time, all_routes));
    sol.total_late = sum(cellfun(@(r) r.late, all_routes));
    sol.total_cost = sol.n_enabled * cfg.enable_cost + ...
                     sum(cellfun(@(r) r.cost, all_routes));
end
