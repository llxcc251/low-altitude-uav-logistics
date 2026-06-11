# config.py - 参数配置

class Config:
    def __init__(self):
        # === 无人机参数（美团 M4）===
        self.n_drones = 20              # 无人机数量
        self.W_max = 2.5                # 最大载重 (kg)
        self.v_cruise = 15.0            # 巡航速度 (m/s)
        self.t_deliver_min = 0.5        # 送货时间 (min)
        self.t_swap_min = 5.0           # 换电池时间 (min)
        self.enable_cost = 2.0          # 启用固定成本

        # === 能耗参数 ===
        self.e0 = 0.1                   # 基础能耗系数 (Wh/m)
        self.e1 = 0.01                  # 载重附加系数 (Wh/(m·kg))
        self.E_max = 1000.0             # 电池容量 (Wh)，单趟总能耗上限

        # === 成本权重 ===
        self.alpha = 0.001              # 能耗成本权重 (Wh -> 元)
        self.gamma = 10.0               # 超时惩罚权重
        self.swap_cost = 0.1            # 换电成本（每次换电的惩罚）
