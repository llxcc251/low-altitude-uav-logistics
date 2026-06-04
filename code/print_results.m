function print_results(sol, data, cfg)
% PRINT_RESULTS 格式化输出求解结果
%   print_results(sol, data, cfg)

    if sol.Z == inf
        fprintf('无可行解。\n');
        return;
    end

    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════╗\n');
    fprintf('║         配 送 方 案 汇 总                    ║\n');
    fprintf('╚══════════════════════════════════════════════╝\n\n');

    % 总览
    fprintf('  快递总数:     %d 件\n', data.n_orders);
    fprintf('  无人机总数:   %d 架\n', cfg.n_drones);
    fprintf('  启用无人机:   %d 架\n', sol.n_enabled);
    fprintf('  总成本 Z:     %.2f\n', sol.Z);
    fprintf('  总配送时间:   %.2f h\n', sol.total_time_h);
    fprintf('  总能耗:       %.2f Wh\n', sol.total_energy_wh);
    fprintf('  总超时:       %.4f h\n', sol.total_late_h);

    % 成本分解
    fprintf('\n  成本分解:\n');
    fprintf('    启用成本:   %d × %d = %d\n', ...
            cfg.enable_cost, sol.n_enabled, cfg.enable_cost * sol.n_enabled);
    fprintf('    运行成本:   %.2f\n', sol.Z - cfg.enable_cost * sol.n_enabled);

    % 各无人机详情
    fprintf('\n');
    fprintf('┌──────────────────────────────────────────────┐\n');
    fprintf('│              各 无 人 机 方 案                │\n');
    fprintf('└──────────────────────────────────────────────┘\n');

    for k = 1:sol.selected_count
        drone_idx = sol.selected(k).drone;
        scheme = sol.selected(k).scheme;

        fprintf('\n  [无人机 %d]  启用成本: %d\n', drone_idx, cfg.enable_cost);
        fprintf('  趟数: %d, 覆盖快递: %d 件\n', scheme.n_trips, sum(scheme.A));

        for t = 1:scheme.n_trips
            trip = scheme.trips{t};
            fprintf('    趋 %d: ', t);

            % 路径
            fprintf('驿站');
            for k2 = 1:length(trip.seq)
                j = trip.seq(k2);
                fprintf(' → %s', data.orders(j).name);
            end
            fprintf(' → 驿站\n');

            % 指标
            fprintf('         时间: %.2f min, 能耗: %.2f Wh, 超时: %.4f min\n', ...
                    trip.time_h*60, trip.energy_wh, trip.late_h*60);
        end

        fprintf('  方案小计: T=%.2f min, E=%.2f Wh, L=%.4f min, C=%.2f\n', ...
                scheme.T*60, scheme.E, scheme.L*60, scheme.C);
    end

    fprintf('\n');
end
