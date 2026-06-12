# Changelog

## 2026-06-12：改配送路径为批量取-批量送

**问题**：原逻辑为"取一送一"——每件货独立执行 `cur_node → pickup_j → delivery_j`，趟次装箱的 `trip_load` 仅用于载重分组，飞行时机上最多只有 1 件货，能耗和路径均不真实。

**修复**：拆分为两个阶段执行：
- Phase 1：`depot → pickup_1 → pickup_2 → ...`，取货段 `cur_load` 逐件累加
- Phase 2：`... → delivery_1 → delivery_2 → ...`，配送段 `cur_load` 逐件递减
- 取货时等待 `order.S`（就绪时间），配送时等待 `order.a`（时间窗开始）

| 文件 | 改动 |
|------|------|
| `python/eval_solution.py` | 将单 for 循环拆为 Phase1 取货 + Phase2 配送两段；能耗按实时 `cur_load` 计算 |

---

## 2026-06-12：公平对比改造

**改动**：所有算法改为固定时间预算，而非固定迭代次数，确保比较公平。

| 文件 | 改动 |
|------|------|
| `random_search.py` | 参数 `n_trials=500` → `time_budget=20`；嵌套循环改为 while 超时循环 |
| `genetic_algorithm.py` | 去掉 `n_gen=500`，改为 `time_budget=20`；`end_time` 在初始化前设定 |
| `eval_solution.py` | 新增 `EVAL_COUNT` 计数器 + `reset_eval_count()` / `get_eval_count()` |
| `run_all.py` | 统一传 `time_budget`；对比表新增"评估次数"列 |

---

## 2026-06-12：修 P0-1 能耗载重未递减

**问题**：`e_loaded = (e0 + e1 × trip_load) × d2`，`trip_load` 是整趟总载重且不递减。"取一送一"模式下每段实载只有当前订单重量，高估能耗。

**修复**：`trip_load` → `order.weight`

| 文件 | 改动 |
|------|------|
| `python/eval_solution.py` | `trip_load` → `order.weight`（2 处） |
| `python/random_search.py` | `trip_load` → `order.weight`（2 处） |
| `matlab/eval_solution.m` | `trip_load` → `data.orders(j).weight`（2 处） |
| `matlab/genetic_algorithm.m` | `trip_load` → `data.orders(j).weight`（2 处） |
| `matlab/random_search.m` | `trip_load` → `data.orders(j).weight`（2 处） |

---

## 2026-06-12：修打印错误（8 架 → 20 架）

**问题**：`load_data.py` 的 print 写死了 `8 架无人机`，实际数据是 20 架。

**修复**：从 `orders.json` 的 `drone_count` 字段读取真实数量。

| 文件 | 改动 |
|------|------|
| `python/load_data.py` | 读取 `raw_order["drone_count"]` 存入 `data.n_drones_data`；print 改为变量输出 |
