function cfg = config()
% CONFIG 参数配置函数
%   cfg = config() 返回默认参数结构体

    % === 无人机参数（美团 M4）===
    cfg.n_drones = 20;             % 无人机数量
    cfg.W_max = 2.5;               % 最大载重 (kg)
    cfg.v_cruise = 15.0;           % 巡航速度 (m/s)
    cfg.t_deliver_min = 0.5;       % 送货时间 (min)
    cfg.t_swap_min = 5.0;          % 换电池时间 (min)
    cfg.enable_cost = 2.0;         % 启用固定成本

    % === 能耗参数 ===
    cfg.e0 = 0.1;                 % 基础能耗系数 (Wh/m)
    cfg.e1 = 0.01;                % 载重附加系数 (Wh/(m·kg))
    cfg.E_max = 1000.0;           % 电池容量 (Wh)，单趟总能耗上限

    % === 成本权重 ===
    cfg.alpha = 0.001;             % 能耗成本权重 (Wh -> 元)
    cfg.gamma = 10.0;              % 超时惩罚权重
    cfg.swap_cost = 0.1;           % 换电成本（每次换电的惩罚）

    % === 候选方案生成 ===
    cfg.max_orders_per_trip = 3;   % 单趟最多携带快递数
    cfg.max_trips_per_drone = 3;   % 每架无人机最多趟数

    % === 求解器参数 ===
    cfg.MaxTime = 300;             % intlinprog 最大求解时间 (s)
end
