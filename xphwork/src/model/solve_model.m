function [sol, exitflag] = solve_model(routes, data, cfg)
% SOLVE_MODEL 求解整数规划模型
%
%   变量布局: [x_1..x_n | y_{1,1}..y_{1,R1} | y_{2,1}..y_{2,R2} | ... | y_{n,1}..y_{n,Rn}]
%   总变量数: n + sum(R_i)
%
%   min  sum_i F_i*x_i + sum_i sum_r C_ir*y_ir
%   s.t. sum_i sum_r A_jr*y_ir = 1     (覆盖)
%        sum_r y_ir <= x_i              (每架无人机最多选一个方案)

    n_drones = cfg.n_drones;
    m = data.n_orders;

    % === 统计变量布局 ===
    R_per_drone = zeros(n_drones, 1);
    for i = 1:n_drones
        R_per_drone(i) = length(routes{i});
    end
    R_total = sum(R_per_drone);
    n_vars = n_drones + R_total;

    fprintf('求解模型: %d 架无人机, %d 件快递, %d 个候选方案\n', ...
            n_drones, m, R_total);

    % === 构造目标函数 ===
    f = zeros(n_vars, 1);
    for i = 1:n_drones
        f(i) = cfg.enable_cost;
    end
    offset = n_drones;
    for i = 1:n_drones
        for r = 1:R_per_drone(i)
            f(offset + r) = routes{i}{r}.C;
        end
        offset = offset + R_per_drone(i);
    end

    % === 约束 1: 覆盖 (等式) ===
    Aeq = zeros(m, n_vars);
    beq = ones(m, 1);
    offset = n_drones;
    for i = 1:n_drones
        for r = 1:R_per_drone(i)
            Aeq(:, offset + r) = routes{i}{r}.A';
        end
        offset = offset + R_per_drone(i);
    end

    % === 约束 2: 每架无人机最多选一个方案 (不等式) ===
    A_ineq = zeros(n_drones, n_vars);
    b_ineq = zeros(n_drones, 1);

    offset = n_drones;
    for i = 1:n_drones
        A_ineq(i, i) = -1;  % -x_i
        for r = 1:R_per_drone(i)
            A_ineq(i, offset + r) = 1;  % +y_{i,r}
        end
        offset = offset + R_per_drone(i);
    end

    % === 求解 ===
    intcon = 1:n_vars;
    lb = zeros(n_vars, 1);
    ub = ones(n_vars, 1);

    options = optimoptions('intlinprog', ...
        'Display', 'final', ...
        'MaxTime', cfg.MaxTime, ...
        'RelativeGapTolerance', 1e-4);

    [x_sol, fval, exitflag] = intlinprog(f, intcon, A_ineq, b_ineq, ...
                                          Aeq, beq, lb, ub, options);

    % === 解析结果 ===
    sol = struct();
    if exitflag <= 0
        warning('求解失败! exitflag = %d', exitflag);
        sol.x = zeros(n_drones, 1);
        sol.Z = inf;
        return;
    end

    sol.x = x_sol(1:n_drones);
    sol.Z = fval;

    % 选出被选中的方案
    sol.selected = struct();
    sol.selected_count = 0;
    offset = n_drones;
    for i = 1:n_drones
        for r = 1:R_per_drone(i)
            if x_sol(offset + r) > 0.5
                sol.selected_count = sol.selected_count + 1;
                sol.selected(sol.selected_count).drone = i;
                sol.selected(sol.selected_count).scheme = routes{i}{r};
            end
        end
        offset = offset + R_per_drone(i);
    end

    % 统计
    sol.n_enabled = sum(sol.x > 0.5);
    sol.total_time_h = 0;
    sol.total_late_h = 0;
    for k = 1:sol.selected_count
        s = sol.selected(k).scheme;
        sol.total_time_h = sol.total_time_h + s.T;
        sol.total_late_h = sol.total_late_h + s.L;
    end

    fprintf('\n=== 求解结果 ===\n');
    fprintf('总成本 Z = %.2f\n', sol.Z);
    fprintf('启用无人机: %d / %d\n', sol.n_enabled, n_drones);
    fprintf('总配送时间: %.2f h\n', sol.total_time_h);
    fprintf('总能耗: %.2f Wh\n', sol.total_energy_wh);
    fprintf('总超时: %.4f h\n', sol.total_late_h);
end
