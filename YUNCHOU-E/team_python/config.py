# config.py - 参数配置

class Config:
    def __init__(self):
        # === 无人机参数（美团 M4）===
        self.n_drones = 8               # 无人机数量
        self.W_max = 2.5                # 最大载重 (kg)
        self.v_cruise = 15.0            # 巡航速度 (m/s)
        self.t_deliver_min = 0.5        # 送货时间 (min)
        self.t_max_h = 2.0              # 单趟最长待机时间 (h)
        self.t_swap_min = 5.0           # 换电池时间 (min)
        self.enable_cost = 0.5          # 启用固定成本

        # === 成本权重 ===
        self.alpha = 1.0                # 时间成本权重
        self.gamma = 2.0                # 超时惩罚权重
