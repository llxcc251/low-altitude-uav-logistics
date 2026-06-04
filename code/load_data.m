function data = load_data()
% LOAD_DATA 加载校区节点和订单数据
%   data = load_data() 返回包含节点坐标、订单信息的结构体

    % === 加载校区节点 ===
    node_file = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'raw', 'campus_nodes.json');
    raw = jsondecode(fileread(node_file));

    % 驿站坐标
    data.station.x = raw.station.x;
    data.station.y = raw.station.y;
    data.station.name = raw.station.name;

    % 配送点坐标
    n_points = length(raw.delivery_points);
    data.points = struct();
    for i = 1:n_points
        data.points(i).id = raw.delivery_points(i).id;
        data.points(i).name = raw.delivery_points(i).name;
        data.points(i).x = raw.delivery_points(i).x;
        data.points(i).y = raw.delivery_points(i).y;
    end

    % === 加载订单数据 ===
    order_file = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'raw', 'orders.json');
    raw_order = jsondecode(fileread(order_file));

    data.n_orders = length(raw_order.orders);
    data.orders = struct();
    for j = 1:data.n_orders
        data.orders(j).id = raw_order.orders(j).id;
        data.orders(j).point_id = raw_order.orders(j).delivery_point;
        data.orders(j).name = raw_order.orders(j).name;
        data.orders(j).weight = raw_order.orders(j).weight_kg;
        data.orders(j).S = raw_order.orders(j).ready_time_h;       % 可出发时间
        data.orders(j).a = raw_order.orders(j).tw_early_h;         % 最早送达
        data.orders(j).b = raw_order.orders(j).tw_late_h;          % 最晚送达
    end

    % === 计算距离矩阵 ===
    N = 1 + n_points;  % 驿站 + 配送点
    data.dist = zeros(N, N);
    coords = [data.station.x, data.station.y];
    for i = 1:n_points
        coords = [coords; data.points(i).x, data.points(i).y];
    end
    for u = 1:N
        for v = 1:N
            data.dist(u, v) = norm(coords(u,:) - coords(v,:));
        end
    end

    fprintf('数据加载完成: %d 架无人机, %d 件快递, %d 个配送点\n', ...
            raw_order.drone_count, data.n_orders, n_points);
end
