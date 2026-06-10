function run_all()
% RUN_ALL 跑全部算法并输出对比表
%   run_all() 运行 5 种算法并对比结果

    fprintf('============================================\n');
    fprintf('  算法对比实验\n');
    fprintf('============================================\n\n');

    % 添加路径
    src_dir = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(src_dir, 'preprocessing'));
    addpath(fullfile(src_dir, 'utils'));
    addpath(fullfile(src_dir, 'model'));

    % 加载数据
    cfg = config();
    data = load_data();

    fprintf('数据: %d 架无人机, %d 件快递\n', cfg.n_drones, data.n_orders);
    fprintf('费用: 启用=%.1f, 能耗=%.3f, 超时=%.1f, 换电=%.1f\n\n', ...
            cfg.enable_cost, cfg.alpha, cfg.gamma, cfg.swap_cost);

    methods = {'random_search', 'genetic_algorithm'};
    names = {'随机×500/架', '遗传算法'};

    results = cell(length(methods), 1);
    times = zeros(length(methods), 1);

    for m = 1:length(methods)
        fprintf('运行 %s ...\n', names{m});
        tic;
        switch methods{m}
            case 'greedy_assign'
                results{m} = greedy_assign(data, cfg);
            case 'nearest_neighbor'
                results{m} = nearest_neighbor(data, cfg);
            case 'savings'
                results{m} = savings(data, cfg);
            case 'random_search'
                results{m} = random_search(data, cfg, 500);
            case 'genetic_algorithm'
                results{m} = genetic_algorithm(data, cfg);
        end
        times(m) = toc;
        fprintf('  完成 (%.2f s)\n', times(m));
    end

    % 也跑 MILP（如果规模小的话）
    if data.n_orders <= 30
        fprintf('运行 MILP (整数规划) ...\n');
        tic;
        routes = generate_routes(data, cfg);
        [milp_sol, exitflag] = solve_model(routes, data, cfg);
        milp_time = toc;
        if exitflag > 0
            fprintf('  完成 (%.2f s)\n', milp_time);
            has_milp = true;
        else
            fprintf('  无可行解\n');
            has_milp = false;
        end
    else
        has_milp = false;
        fprintf('规模太大，跳过 MILP\n');
    end

    % 输出对比表
    fprintf('\n');
    fprintf('============================================\n');
    fprintf('  对比结果\n');
    fprintf('============================================\n');
    fprintf('%-12s %8s %6s %10s %8s %10s\n', '方法', '总成本', '启用数', '总能耗(Wh)', '超时(min)', '计算耗时(s)');
    fprintf('%-12s %8s %6s %10s %8s %10s\n', '--------', '--------', '------', '----------', '--------', '----------');

    % 找最优成本
    costs = cellfun(@(r) r.total_cost, results);
    if has_milp
        all_costs = [costs, milp_sol.Z];
        best_cost = min(all_costs);
    else
        best_cost = min(costs);
    end

    if has_milp
        gap_milp = 0;
        fprintf('%-12s %8.1f %6d %8.4f %8.2f  (MILP最优)\n', ...
                'MILP', milp_sol.Z, milp_sol.n_enabled, milp_sol.total_late, milp_time);
    end

    for m = 1:length(methods)
        r = results{m};
        if best_cost > 0
            gap = (r.total_cost - best_cost) / best_cost * 100;
            fprintf('%-12s %8.1f %6d %10.0f %8.1f %10.2f  (gap %.1f%%)\n', ...
                    names{m}, r.total_cost, r.n_enabled, r.total_energy, r.total_late*60, times(m), gap);
        else
            fprintf('%-12s %8.1f %6d %10.0f %8.1f %10.2f\n', ...
                    names{m}, r.total_cost, r.n_enabled, r.total_energy, r.total_late*60, times(m));
        end
    end
    fprintf('\n');

    % 输出最优方案的详细配送计划
    [~, best_idx] = min(cellfun(@(r) r.total_cost, results));
    best = results{best_idx};
    fprintf('============================================\n');
    fprintf('  最优方案详细配送计划 (%s)\n', names{best_idx});
    fprintf('============================================\n');

    for k = 1:length(best.routes)
        route = best.routes{k};
        depot_name = '驿站';
        if isfield(route, 'depot_name'), depot_name = route.depot_name; end
        if isfield(route, 'energy')
            fprintf('\n无人机 %d [%s]  %.0fWh:\n', route.drone, depot_name, route.energy);
        else
            fprintf('\n无人机 %d [%s]:\n', route.drone, depot_name);
        end

        if isfield(route, 'details') && ~isempty(route.details)
            fprintf('  详细路径:\n');
            fprintf('  %s', depot_name);
            for kk = 1:length(route.details)
                d = route.details{kk};
                arr_h = floor(d.arrive_h);
                arr_m = round((d.arrive_h - arr_h) * 60);
                fprintf('\n  -> %s(%.1fkg) -> %s (完成订单 #%03d, %02d:%02d)', ...
                        d.pickup, d.weight, d.delivery, d.order_id, arr_h, arr_m);
            end
            fprintf('\n  -> %s\n', depot_name);
        else
            fprintf('  路线: %s', depot_name);
            for kk = 1:length(route.orders)
                j = route.orders(kk);
                fprintf(' -> %s(%.1fkg) -> %s', ...
                        data.orders(j).pickup_name, data.orders(j).weight, ...
                        data.orders(j).delivery_name);
            end
            fprintf(' -> %s\n', depot_name);
        end
    end
    fprintf('\n');
end
