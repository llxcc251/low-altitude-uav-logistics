function cfg = config()
% CONFIG 参数配置函数
%   cfg = config() 返回默认参数结构体

    % === 无人机参数（美团 M4）===
    cfg.n_drones = 8;              % 无人机数量
    cfg.W_max = 2.5;               % 最大载重 (kg)
    cfg.v_cruise = 15.0;           % 巡航速度 (m/s)
    cfg.t_deliver_min = 0.5;       % 送货时间 (min)
    cfg.t_max_h = 2.0;             % 单趟最长待机时间 (h)，从起飞到返回起降点
    cfg.t_swap_min = 5.0;          % 换电池时间 (min)
    cfg.enable_cost = 0.5;         % 启用固定成本
    cfg.idle_cost = 0;             % 待机成本 (元/h)，回起降点不收

    % === 成本权重 ===
    cfg.alpha = 1.0;               % 时间成本权重
    cfg.gamma = 2.0;               % 超时惩罚权重

    % === 候选方案生成 ===
    cfg.max_orders_per_trip = 3;   % 单趟最多携带快递数
    cfg.max_trips_per_drone = 3;   % 每架无人机最多趟数

    % === 求解器参数 ===
    cfg.MaxTime = 300;             % intlinprog 最大求解时间 (s)
end
