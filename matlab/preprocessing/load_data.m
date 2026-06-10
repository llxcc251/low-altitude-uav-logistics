function data = load_data()
% LOAD_DATA 加载校区节点和订单数据
%   data = load_data() 返回包含节点坐标、订单信息的结构体

    base_dir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data');

    % === 加载校区节点 ===
    raw = jsondecode(fileread(fullfile(base_dir, 'campus_nodes.json')));

    data.nodes = struct();
    for i = 1:length(raw.nodes)
        data.nodes(i).id = raw.nodes(i).id;
        data.nodes(i).name = raw.nodes(i).name;
        data.nodes(i).type = raw.nodes(i).type;
        data.nodes(i).x = raw.nodes(i).x;
        data.nodes(i).y = raw.nodes(i).y;
    end

    % 找出起降点
    data.depots = {};
    for i = 1:length(data.nodes)
        if strcmp(data.nodes(i).type, 'depot')
            data.depots{end+1} = data.nodes(i);
        end
    end

    % === 加载订单数据 ===
    raw_order = jsondecode(fileread(fullfile(base_dir, 'orders.json')));

    data.n_orders = length(raw_order.orders);
    data.orders = struct();
    for j = 1:data.n_orders
        data.orders(j).id = raw_order.orders(j).id;
        data.orders(j).pickup_id = raw_order.orders(j).pickup_id;
        data.orders(j).pickup_name = raw_order.orders(j).pickup_name;
        data.orders(j).delivery_id = raw_order.orders(j).delivery_id;
        data.orders(j).delivery_name = raw_order.orders(j).delivery_name;
        data.orders(j).weight = raw_order.orders(j).weight_kg;
        data.orders(j).S = raw_order.orders(j).ready_time_h;
        data.orders(j).a = raw_order.orders(j).tw_early_h;
        data.orders(j).b = raw_order.orders(j).tw_late_h;
    end

    % === 计算节点坐标表 ===
    data.node_ids = {data.nodes.id};
    data.node_x = [data.nodes.x];
    data.node_y = [data.nodes.y];

    % === 加载距离矩阵（实际飞行距离，含绕行系数）===
    dist_file = fullfile(base_dir, 'distance_matrix.csv');
    if exist(dist_file, 'file')
        fid = fopen(dist_file, 'r');
        fgetl(fid);  % 跳过表头
        N = length(data.nodes);
        data.dist = zeros(N, N);
        while ~feof(fid)
            line = fgetl(fid);
            parts = strsplit(line, ',');
            from = strtrim(parts{1});
            to = strtrim(parts{2});
            d = str2double(parts{3});
            fi = find(strcmp(data.node_ids, from));
            ti = find(strcmp(data.node_ids, to));
            if ~isempty(fi) && ~isempty(ti)
                data.dist(fi, ti) = d;
            end
        end
        fclose(fid);
        fprintf('距离矩阵: 从 distance_matrix.csv 加载（实际飞行距离）\n');
    else
        % 回退：用直线距离
        N = length(data.nodes);
        data.dist = zeros(N, N);
        for u = 1:N
            for v = 1:N
                data.dist(u, v) = norm([data.node_x(u)-data.node_x(v), ...
                                         data.node_y(u)-data.node_y(v)]);
            end
        end
        fprintf('距离矩阵: 使用直线距离（未找到 distance_matrix.csv）\n');
    end

    fprintf('数据加载完成: %d 架无人机, %d 件快递, %d 个节点\n', ...
            raw_order.drone_count, data.n_orders, length(data.nodes));
end
