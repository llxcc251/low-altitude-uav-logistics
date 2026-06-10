% GENERATE_300 生成300条合法订单数据
%   pickup: 4个取货点 (GATE_S, CANTEEN_W, CANTEEN_E, RESTAURANT_X)
%   delivery: 3个配送点 (DORM_W, DORM_E, LIB)
%   weight: 0.3 ~ 1.5 kg (W_max = 2.5)
%   时间窗: 8:00 ~ 19:00, 保证 ready < early < late

rng(42);  % 固定随机种子，可复现

pickup_ids = {'GATE_S', 'CANTEEN_W', 'CANTEEN_E', 'RESTAURANT_X'};
pickup_names = {'南门临时服务点', '西园食堂', '东园食堂', '相山餐厅'};
delivery_ids = {'DORM_W', 'DORM_E', 'LIB'};
delivery_names = {'西园宿舍区', '东园宿舍区', '图书馆学习区'};

% 时间分布：午高峰 11-13 点占 40%，晚高峰 17-19 点占 30%，其他 30%
n = 300;
orders = struct('id', {}, 'pickup_id', {}, 'pickup_name', {}, ...
                'delivery_id', {}, 'delivery_name', {}, ...
                'weight_kg', {}, 'ready_time_h', {}, ...
                'tw_early_h', {}, 'tw_late_h', {});

for i = 1:n
    % 随机选时间段
    r = rand();
    if r < 0.30
        % 早高峰 8:00-11:00
        base_time = 8 + rand() * 3;
    elseif r < 0.70
        % 午高峰 11:00-13:00
        base_time = 11 + rand() * 2;
    else
        % 晚高峰 17:00-19:00
        base_time = 17 + rand() * 2;
    end

    % ready_time: 快递到达时间（比窗口早 10-30 分钟）
    ready = base_time - (10 + rand()*20)/60;

    % tw_early: 最早可送达（ready 后 15-25 分钟）
    early = ready + (15 + rand()*10)/60;

    % tw_late: 最晚可送达（early 后 30-60 分钟）
    late = early + (30 + rand()*30)/60;

    % 确保不超 19:00
    if late > 19.0
        late = 19.0;
        early = min(early, late - 15/60);
        ready = min(ready, early - 10/60);
    end

    % 随机选配送点（3个均匀分布）
    d_idx = randi(3);

    % 随机选取货点（4个，但离配送点近的更可能）
    % 简单起见：均匀随机
    p_idx = randi(4);

    orders(i).id = i;
    orders(i).pickup_id = pickup_ids{p_idx};
    orders(i).pickup_name = pickup_names{p_idx};
    orders(i).delivery_id = delivery_ids{d_idx};
    orders(i).delivery_name = delivery_names{d_idx};
    orders(i).weight_kg = round(0.3 + rand() * 1.2, 2);  % 0.3 ~ 1.5
    orders(i).ready_time_h = round(ready, 2);
    orders(i).tw_early_h = round(early, 2);
    orders(i).tw_late_h = round(late, 2);
end

% 写入 JSON
json.description = '校园快递订单数据（300件，午晚高峰密集）';
json.drone_count = 8;
json.depots = {'DEP_W', 'DEP_E'};
json.orders = orders;

fid = fopen('orders_300.json', 'w');
fprintf(fid, '%s', jsonencode(json));
fclose(fid);

fprintf('已生成 orders_300.json (%d 条订单)\n', n);
