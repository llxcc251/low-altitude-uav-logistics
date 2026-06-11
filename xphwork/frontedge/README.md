# 校园多无人机快递配送调度

面向中山大学深圳校区场景的多无人机配送调度系统。项目包含 120/300 单数据集、随机搜索与遗传算法、能耗与时间窗约束，以及交互式网页看板。

## 功能

- 读取校园节点、手绘飞行距离和订单数据
- 随机搜索与遗传算法对比
- 双层队列装箱、多趟配送和节点换电
- 展示配送路径、甘特图、成本和准时率
- 展示无人机数、速度和载重上限的敏感性分析

## 模型参数

- 最大无人机数：20
- 最大载重：2.5 kg
- 巡航速度：15 m/s
- 电池容量：1000 Wh
- 基础能耗：0.1 Wh/m
- 载重附加能耗：0.01 Wh/(m·kg)
- 换电时间：5 min
- 固定启用成本：2.0
- 能耗权重：0.001
- 超时权重：10.0
- 换电成本：0.1/次

## 目录结构

```text
.
├─ 实验数据面板.html       # 交互式网页看板
├─ backend_server.py       # 本地 HTTP 服务与 API
├─ team_solver.py          # 网页与算法的适配层
├─ generate_sensitivity.py # 敏感性分析生成脚本
├─ import_order_data.py    # CSV 订单转换脚本
├─ assets/videos/          # 前端场景展示视频
├─ team_python/            # 随机搜索、遗传算法与评估函数
├─ data/                   # 节点、订单、距离和结果数据
├─ generated_elevation/    # 手绘航路地图
└─ map_versions/           # 地图版本
```

## 安装与运行

需要 Python 3.9 或更高版本。

```bash
pip install -r requirements.txt
python backend_server.py
```

Windows 也可以双击 `start_web.bat`。启动后访问：

```text
http://127.0.0.1:5173/
```

不要直接双击 HTML 文件，否则求解和数据编辑 API 无法使用。

## 数据集

- `data/orders.json`：默认新版 120 单
- `data/orders_120.json`：新版 120 单
- `data/orders_300.json`：新版 300 单压力测试数据
- `data/order_info_120_new.csv`、`data/order_info_300_new.csv`：原始 CSV

重新转换数据：

```bash
python import_order_data.py
```

也可以指定其他 CSV：

```bash
python import_order_data.py --orders-120 path/to/120.csv --orders-300 path/to/300.csv
```

CSV 中的时间以 08:00 为起点，转换时会加 8 小时。CSV 坐标不会覆盖项目地图坐标。

## 求解与复现

网页正式遗传算法固定随机种子为 `42`，执行流程为：

1. 随机搜索 500 次/无人机数量作为预热
2. 运行遗传算法

当前 120 单基准结果约为：总成本 50.57、启用 9 架、总能耗 28718.93 Wh。

重新生成敏感性分析：

```bash
python generate_sensitivity.py
```

该过程需要数分钟，并会更新 `data/sensitivity_results.json`。

## 说明

- 点击求解会覆盖 `data/results.json`。
- 新增或删除订单会修改 `data/orders.json`。
- 地图影像来自 ArcGIS 在线瓦片，离线时底图可能无法显示，但本地节点和路径数据仍可使用。
