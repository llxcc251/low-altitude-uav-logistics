# 实验数据面板运行说明

## 目录结构

```text
.
├─ 实验数据面板.html
├─ start_web.bat
├─ backend_server.py
├─ solve_python.py
├─ team_solver.py
├─ generate_sensitivity.py
├─ echarts.min.js
├─ data/
├─ team_python/
├─ generated_elevation/
└─ map_versions/
```

## 文件说明

### 启动入口

- `start_web.bat`：一键启动脚本，双击后会启动本地 Python 后端，并自动打开网页。
- `实验数据面板.html`：主网页文件，负责页面展示、按钮交互、图表和地图区域。

### 前端资源

- `echarts.min.js`：图表库文件，用于绘制甘特图、柱状图和敏感性分析图。
- `generated_elevation/uav_network_map.html`：手绘航线地图页面，主网页会读取其中的建筑和航线数据用于地图展示。
- `map_versions/中深/SYSU_Shenzhen_annotated_map.svg`：中深校园标注版底图。
- `map_versions/中深/SYSU_Shenzhen_routed_distance_map.svg`：中深校园路由距离版底图。
- `map_versions/中深/SYSU_Shenzhen_straight_distance_map.svg`：中深校园直线距离版底图。

### 后端与算法

- `backend_server.py`：本地后端服务，提供网页需要调用的接口，并负责读写数据文件。
- `solve_python.py`：Python 求解备用脚本，用于生成配送结果。
- `team_solver.py`：连接网页后端和 `team_python` 算法模块的求解脚本。
- `generate_sensitivity.py`：重新生成敏感性分析结果的脚本。
- `team_python/config.py`：算法参数配置。
- `team_python/load_data.py`：读取节点、订单和距离矩阵数据。
- `team_python/eval_solution.py`：评估配送方案的成本、耗时和超时情况。
- `team_python/random_search.py`：随机搜索算法。
- `team_python/genetic_algorithm.py`：遗传算法。

### 数据文件

- `data/campus_nodes.json`：校园节点数据，包括起降点、取货点和配送点。
- `data/orders.json`：订单数据，包括取货点、配送点、重量和时间窗。
- `data/drone_params.json`：无人机参数，包括载重、速度、电池容量等。
- `data/distance_matrix.csv`：节点之间的距离矩阵。
- `data/results.json`：当前求解结果，网页会读取它展示路径、指标和甘特图。
- `data/sensitivity_results.json`：敏感性分析结果，网页会读取它绘制分析图。

## 运行方式

双击项目文件夹里的：

```text
start_web.bat
```

启动后会自动打开浏览器页面。

使用网页时，请保持弹出的命令行窗口打开；关闭窗口后，本地后端也会停止。

## 手动访问

如果浏览器没有自动打开，可以手动访问：

```text
http://127.0.0.1:5173/
```

或：

```text
http://127.0.0.1:5173/实验数据面板.html
```

## 运行环境

电脑需要安装 Python 3。

如果运行或求解时报 `numpy` 相关错误，在命令行安装：

```bash
pip install numpy
```

然后重新双击 `start_web.bat`。

## 注意事项

- 不要直接双击 `实验数据面板.html` 运行，否则新增订单、删除订单、修改参数、求解等功能可能无法使用。
- 新增订单、删除订单、修改无人机参数会写入 `data/` 目录下的数据文件。
- 点击求解会更新 `data/results.json`。
