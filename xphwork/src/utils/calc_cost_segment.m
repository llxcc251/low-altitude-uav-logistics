function time_h = calc_cost_segment(d_m, load_kg, cfg)
% CALC_COST_SEGMENT 计算单段飞行时间
%   time_h = calc_cost_segment(d_m, load_kg, cfg)
%
%   输入:
%     d_m     - 飞行距离 (m)
%     load_kg - 当前载重 (kg)，未使用，保留接口
%     cfg     - 参数配置
%
%   输出:
%     time_h  - 飞行时间 (h)

    % 时间 = 距离 / 速度
    time_h = d_m / (cfg.v_cruise * 3600);  % m / (m/s * 3600) = h
end
