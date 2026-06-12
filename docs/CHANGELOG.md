# Changelog

## 2026-06-12：改为按电量判断换电，去掉装箱逻辑

**问题**：原逻辑每趟结束强制换电（5min），且用 `W_max` 装箱划分趟次。取一送一模式下载重约束无意义，且大量趟次耗电不到 50% 也白等换电时间。

**改动**：

1. **去掉装箱逻辑**——不再用 `W_max` 分组，每件订单独立配送
2. **跟踪每架无人机剩余电量**——`remaining_battery` 初始 1000 Wh，每次执行订单后递减
3. **按电量判断换电**——如果当前订单能耗 + 回程能耗 > 剩余电量，才回起降点换电
4. **保障回程**——判断条件包含飞回起降点的能耗预留

**涉及文件**：Python 和 MATLAB 的 `eval_solution`、`build_sol`/`assignment_to_sol`（`random_search`、`genetic_algorithm`）共 6 个文件。

## 2026-06-12：修复 GA 替换准则 + smart_random_assignment

**P0-1 GA 替换准则错配**：
- 原代码子代 fitness 与上一代错位索引比较，进化压力近乎随机
- 改为标准 `(μ+λ)` 选择：合并父代和子代，按 fitness 排序取前 pop_size

**P0-3 smart_random_assignment 载重错误**：
- `drone_load + w ≤ W_max` 错误限制了一架无人机累计总载重 ≤2.5 kg
- 改为纯随机分配（取一送一模式下载重约束不适用于分配阶段）

**文件**：Python 和 MATLAB 的 `genetic_algorithm.py/m`、`random_search.py/m`

## 2026-06-12：公平对比改造

所有算法改为固定时间预算（默认 20s），新增评估计数器。MATLAB 同步对齐。
