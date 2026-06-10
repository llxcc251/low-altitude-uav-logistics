# 问题清单

## 1. 配置冲突：参数值不统一

数据源（`drone_params.json`，官方真实参数）与代码中实际使用的参数存在多处矛盾：

| 参数 | JSON 数据 | config.m / config.py | 差异 |
|------|:-:|:-:|:---:|
| 启用固定成本 | 100 | 0.5 | 差 200 倍 |
| 最大续航 | 11 min | 120 min（2.0 h） | 差 10 倍 |
| 最大载重 | 2.5 kg | 2.5 kg | ✅ 一致 |

`t_max_h = 2.0h` 意味着代码允许无人机连续飞行 2 小时，而真机 M4 的续航只有 11 分钟，绝大部分方案按真实参数会直接被判为不可行。

## 2. 能耗（β）缺失：模型与代码脱节

`model.md` 定义了完整的三项成本：

$$C = \alpha T + \beta E + \gamma L$$

并给出了分段能耗公式（空载 vs 载货，与载重和距离相关），但：

- `config.m` / `config.py` **没有定义 β**
- `eval_solution` 和所有评估逻辑 **未计算能耗**
- `solve_model.m:116` 打印 `sol.total_energy_wh`，但该字段 **从未赋值**，运行会报错

目前的实际成本只算了时间和超时两项，等价于 β = 0。

## 3. 候选方案未按起降点区分成本

MILP 路径的候选方案由 `generate_routes.m` 一次性生成后复制给所有无人机（`routes{i} = schemes`），但方案的成本是在生成时就计算好的，没有区分从哪个起降点出发。

同一套方案从不同起降点出发的成本差异很大：

| 路线 | 西区出发总路程 | 东区出发总路程 |
|------|:-:|:-:|
| → 相山餐厅 → 西园宿舍 → 回 | 297+559 = **856m** | 835+1582 = **2417m** |
| → 东园食堂 → 东园宿舍 → 回 | 1280+1479 = **2759m** | 411+624 = **1035m** |

目前的方案成本是固定的，求解器选方案时并不知道这笔账。更好的做法是：为不同起降点单独生成候选方案并重新计算成本。

## 4. 代码冗余：核心逻辑重复 5 次以上

"逐件配送 → 载重检查 → 超时检查 → 返回起降点"这套流程：

- `random_search.m` 的 `build_sol` 写了一遍
- `genetic_algorithm.m` 的 `assignment_to_sol` 写了一遍
- `simulated_annealing.m` 的 `assignment_to_sol` 又写了一遍
- Python 版 `random_search.py` 的 `build_sol` 写了一遍
- Python 版 `genetic_algorithm.py` 的 `build_sol` 也写了类似逻辑（通过调用前者，但两者耦合不清晰）

- `greedy_assign.m` 和 `nearest_neighbor.m` 逻辑基本相同

每次修改评估规则都需要同步 5 个地方，极易不一致。

## 5. 距离矩阵与欧氏距离混用

- `eval_solution.m` 使用 `data.dist`（手绘实际飞行距离）
- `simulated_annealing.m:149,194,219` 使用 `norm()` 欧氏距离
- `savings.m:32-33` 使用 `norm()` 欧氏距离
- `greedy_assign.m` 和 `nearest_neighbor.m` 使用 `norm()` 欧氏距离

同一项目内两套距离体系，结果不可比较。

## 6. 高程数据未接入

`elevation_grid.npy`（~8MB）、`corridors_elevation.json`、`adjacency_matrix_elevation.csv` 等文件存在但未被任何调度算法使用。

## 7. MILP 规模增长过快

候选方案生成对 120 件快递枚举 C(120,1)+C(120,2)+C(120,3) ≈ 28 万种子集，虽然大部分会被过滤，但方案数仍可能很大，intlinprog 求解时间不可控。`run_all.m:49` 注释写着"规模太大会跳过 MILP"。

## 8. 订单超时与实际判断不严谨

`eval_solution.m:104` 超时计算方式：

```matlab
trip_late_here = max(0, arrive - data.orders(j).b);
```

只累计了单个订单的超时，但没有考虑"当前趟超时严重但后续订单时间窗尚可"的情况。实际上只要时间超过了 b，后续所有订单都会连锁延迟，但代码对每个订单独立计算超时，没有传递累计延迟。

## 9. 换电必须回起降点，不能就近补能

当前代码在电量/载重超限时，无人机必须飞回起降点换电（`eval_solution.m:82-93`）：

```matlab
d_ret = data.dist(cur_node, depot_idx);     % 飞回起降点
drone_time = drone_time + ... + cfg.t_swap_min/60;  % 换电 5 min
cur_node = depot_idx;                        % 重置到起降点
```

所有配送节点（食堂、宿舍、图书馆等）的 `can_takeoff = false`，不具备起飞/充电能力。

如果无人机在配送途中电量不足，必须原路折返回起降点，换完电再重新飞出来，白白增加了不必要的回程距离。更合理的场景是允许在部分配送节点就近补能，减少无效折返飞行。
