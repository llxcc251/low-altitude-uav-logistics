function cfg = config()
% CONFIG 参数配置函数
%   cfg = config() 返回默认参数结构体

    % === 无人机参数（美团 M4）===
    cfg.n_drones = 6;              % 无人机数量
    cfg.W_max = 2.5;               % 最大载重 (kg)
    cfg.E_battery = 1000;          % 电池容量 (Wh)
    cfg.v_cruise = 15.0;           % 巡航速度 (m/s)
    cfg.t_max_min = 11.0;          % 最大续航 (min)
    cfg.t_prep_min = 1.0;          % 起飞/装载准备时间 (min)
    cfg.t_swap_min = 2.0;          % 换电/充电时间 (min)
    cfg.enable_cost = 100;         % 启用固定成本
    cfg.split_penalty = 50;        % 拆分惩罚

    % === 能耗参数 ===
    cfg.e0 = 0.5;                  % 基础能耗系数
    cfg.e1 = 0.05;                 % 载重相关能耗系数

    % === 成本权重 ===
    cfg.alpha = 1.0;               % 时间成本权重
    cfg.beta  = 0.3;               % 能耗成本权重
    cfg.gamma = 2.0;               % 超时惩罚权重

    % === 候选方案生成 ===
    cfg.max_orders_per_trip = 3;   % 单趟最多携带快递数
    cfg.max_trips_per_drone = 3;   % 每架无人机最多趟数

    % === 求解器参数 ===
    cfg.MaxTime = 60;              % intlinprog 最大求解时间 (s)
end
