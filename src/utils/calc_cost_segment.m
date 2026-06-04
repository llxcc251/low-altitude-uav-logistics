function [time_h, energy_wh] = calc_cost_segment(d_m, load_kg, cfg)
% CALC_COST_SEGMENT 计算单段飞行的时间和能耗
%   [time_h, energy_wh] = calc_cost_segment(d_m, load_kg, cfg)
%
%   输入:
%     d_m     - 飞行距离 (m)
%     load_kg - 当前载重 (kg)，空载段为 0
%     cfg     - 参数配置
%
%   输出:
%     time_h    - 飞行时间 (h)
%     energy_wh - 能耗 (Wh)

    % 时间 = 距离 / 速度
    time_h = d_m / (cfg.v_cruise * 3600);  % m / (m/s * 3600) = h

    % 能耗 = 基础能耗 + 载重能耗
    d_km = d_m / 1000;
    energy_wh = cfg.e0 * d_km + cfg.e1 * d_km * load_kg;
end
