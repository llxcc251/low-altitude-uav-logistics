function sol = savings(data, cfg)
% SAVINGS 简化版节约算法
%   按时间窗相近 + 距离近的订单优先合并

    m = data.n_orders;
    depot_idx = find(strcmp({data.nodes.type}, 'depot'));
    dep = data.nodes(depot_idx(1));

    % 初始：每件快递单独一条路线
    route_of = 1:m;
    route_orders = cell(m, 1);
    for j = 1:m
        route_orders{j} = j;
    end
    n_routes = m;

    % 计算所有订单对的合并收益
    pairs = [];
    for i = 1:m
        for j = i+1:m
            % 时间窗相近程度
            t_i = data.orders(i).S;
            t_j = data.orders(j).S;
            time_diff = abs(t_i - t_j);

            % 距离接近程度
            pi = find(strcmp(data.node_ids, data.orders(i).pickup_id));
            pj = find(strcmp(data.node_ids, data.orders(j).pickup_id));
            di = find(strcmp(data.node_ids, data.orders(i).delivery_id));
            dj = find(strcmp(data.node_ids, data.orders(j).delivery_id));

            d_pickup = norm([data.node_x(pi), data.node_y(pi)] - [data.node_x(pj), data.node_y(pj)]);
            d_del = norm([data.node_x(di), data.node_y(di)] - [data.node_x(dj), data.node_y(dj)]);

            % 收益 = 距离近 + 时间近（越大越值得合并）
            benefit = 1000 / (1 + d_pickup + d_del + time_diff * 100);
            pairs = [pairs; benefit, i, j];
        end
    end

    % 按收益从大到小排序
    [~, sort_idx] = sort(pairs(:,1), 'descend');
    pairs = pairs(sort_idx, :);

    % 合并
    for p = 1:size(pairs, 1)
        i = pairs(p, 2);
        j = pairs(p, 3);

        ri = route_of(i);
        rj = route_of(j);
        if ri == rj, continue; end

        % 合并后的订单
        new_orders = [route_orders{ri}, route_orders{rj}];
        total_w = sum([data.orders(new_orders).weight]);
        if total_w > cfg.W_max, continue; end

        % 检查时间
        new_time = calc_route_time(new_orders, data, cfg, dep);
        if new_time > cfg.t_max_h, continue; end

        % 合并
        route_orders{ri} = new_orders;
        route_orders{rj} = [];
        route_of(route_of == rj) = ri;
    end

    % 重新扫描，找出所有有效路线
    valid_routes = {};
    for r = 1:m
        if ~isempty(route_orders{r})
            valid_routes{end+1} = route_orders{r};
        end
    end

    % 构造输出
    sol.routes = {};
    sol.n_enabled = 0;
    sol.total_time = 0;
    sol.total_late = 0;

    for r = 1:length(valid_routes)
        sol.n_enabled = sol.n_enabled + 1;
        [time, late] = eval_route(valid_routes{r}, data, cfg, dep);

        route.drone = sol.n_enabled;
        route.orders = valid_routes{r};
        route.trips = {valid_routes{r}};
        route.time = time;
        route.late = late;
        route.cost = cfg.alpha * time + cfg.gamma * late;
        sol.routes{end+1} = route;
        sol.total_time = sol.total_time + time;
        sol.total_late = sol.total_late + late;
    end

    sol.total_cost = sol.n_enabled * cfg.enable_cost + ...
                     sum(cellfun(@(r) r.cost, sol.routes));
end

function t = calc_route_time(order_ids, data, cfg, dep)
    t = 0;
    cx = dep.x; cy = dep.y;
    for k = 1:length(order_ids)
        j = order_ids(k);
        pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
        dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));
        px = data.node_x(pk); py = data.node_y(pk);
        dx = data.node_x(dk); dy = data.node_y(dk);
        d1 = norm([cx,cy] - [px,py]);
        d2 = norm([px,py] - [dx,dy]);
        t = t + (d1 + d2) / (cfg.v_cruise * 3600) + cfg.t_deliver_min / 60;
        cx = dx; cy = dy;
    end
    d_ret = norm([cx,cy] - [dep.x,dep.y]);
    t = t + d_ret / (cfg.v_cruise * 3600);
end

function [t, late] = eval_route(order_ids, data, cfg, dep)
    t = 0; late = 0;
    cx = dep.x; cy = dep.y;
    for k = 1:length(order_ids)
        j = order_ids(k);
        pk = find(strcmp(data.node_ids, data.orders(j).pickup_id));
        dk = find(strcmp(data.node_ids, data.orders(j).delivery_id));
        px = data.node_x(pk); py = data.node_y(pk);
        dx = data.node_x(dk); dy = data.node_y(dk);
        d1 = norm([cx,cy] - [px,py]);
        d2 = norm([px,py] - [dx,dy]);
        t = t + (d1 + d2) / (cfg.v_cruise * 3600) + cfg.t_deliver_min / 60;
        if t > data.orders(j).b
            late = late + (t - data.orders(j).b);
        end
        cx = dx; cy = dy;
    end
    d_ret = norm([cx,cy] - [dep.x,dep.y]);
    t = t + d_ret / (cfg.v_cruise * 3600);
end
