%% 主程序：校园驿站快递配送 — 多无人机协同调度
%  中山大学深圳校区 · 运筹学大作业
%
%  流程: 加载数据 → 生成候选方案 → 求解整数规划 → 输出结果

clc; clear; close all;

% 添加子目录到路径
src_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(src_dir, 'model'));
addpath(fullfile(src_dir, 'preprocessing'));
addpath(fullfile(src_dir, 'utils'));
addpath(fullfile(src_dir, 'algorithms'));

fprintf('============================================\n');
fprintf('  校园驿站快递配送 — 多无人机协同调度\n');
fprintf('  中山大学深圳校区 · 运筹学大作业\n');
fprintf('============================================\n\n');

%% Step 1: 加载参数和数据
fprintf('[Step 1] 加载参数和数据...\n');
cfg = config();
data = load_data();
fprintf('\n');

%% Step 2: 显示订单信息
fprintf('[Step 2] 订单信息:\n');
fprintf('%3s  %-10s -> %-8s  %5s  %6s  %s\n', ...
        'ID', '取货', '配送', '重量', '可出发', '时间窗');
for j = 1:data.n_orders
    fprintf('%3d  %-10s -> %-8s  %5.1fkg  %5.2fh  [%.2f, %.2f]\n', ...
            data.orders(j).id, data.orders(j).pickup_name, ...
            data.orders(j).delivery_name, data.orders(j).weight, ...
            data.orders(j).S, data.orders(j).a, data.orders(j).b);
end
fprintf('\n');

%% Step 3: 生成候选方案
fprintf('[Step 3] 生成候选调度方案...\n');
tic;
routes = generate_routes(data, cfg);
gen_time = toc;
fprintf('候选方案生成耗时: %.2f s\n\n', gen_time);

%% Step 4: 求解整数规划
fprintf('[Step 4] 求解整数规划模型...\n');
tic;
[sol, exitflag] = solve_model(routes, data, cfg);
solve_time = toc;
fprintf('求解耗时: %.2f s\n\n', solve_time);

%% Step 5: 输出详细方案
if exitflag > 0
    fprintf('[Step 5] 详细配送方案:\n');
    fprintf('============================================\n');

    for k = 1:sol.selected_count
        drone_idx = sol.selected(k).drone;
        scheme = sol.selected(k).scheme;

        fprintf('\n无人机 %d (启用成本 %d):\n', drone_idx, cfg.enable_cost);
        fprintf('  总时间: %.2f h, 超时: %.4f h\n', scheme.T, scheme.L);
        fprintf('  综合成本 C = %.2f\n', scheme.C);

        for t = 1:scheme.n_trips
            trip = scheme.trips{t};
            fprintf('  趟 %d: 起降点', t);
            for k2 = 1:length(trip.seq)
                j = trip.seq(k2);
                fprintf(' → %s(%.1fkg) → %s', ...
                        data.orders(j).pickup_name, data.orders(j).weight, ...
                        data.orders(j).delivery_name);
            end
            fprintf(' → 起降点\n');
            fprintf('    时间 %.2fh, 超时 %.4fh\n', trip.time_h, trip.late_h);
        end
    end

    fprintf('\n============================================\n');
    fprintf('总成本 Z = %.2f\n', sol.Z);
    fprintf('  其中: 启用成本 = %d × %d = %d\n', ...
            cfg.enable_cost, sol.n_enabled, cfg.enable_cost * sol.n_enabled);
    fprintf('        运行成本 = %.2f\n', sol.Z - cfg.enable_cost * sol.n_enabled);
    fprintf('============================================\n');
else
    fprintf('求解失败，无法输出方案。\n');
end
