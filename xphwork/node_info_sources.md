# node_info.csv 坐标来源说明

`node_info.csv` 已精简为模型输入表，只保留坐标和起降相关字段。各节点坐标来源如下。

## 字段口径

- `x_m`、`y_m`、`z_m`：模型平面坐标，单位为米，用于距离矩阵和路线计算。
- `lat_wgs84`、`lon_wgs84`：经纬度坐标，坐标系为 WGS84。
- `can_takeoff`：是否可作为无人机起飞点。
- `can_land`：是否可作为无人机降落或任务交接点。

## 节点来源

| node_id | 节点名称 | 经纬度来源 | 说明 |
| --- | --- | --- | --- |
| `DEP_W` | 西区无人机起降点 | 模型估算 | 场景假设点，未找到同名公开地图 POI；经纬度由平面坐标换算得到 |
| `DEP_E` | 东区无人机起降点 | 模型估算 | 场景假设点，未找到同名公开地图 POI；经纬度由平面坐标换算得到 |
| `CANTEEN_W` | 西园食堂 | OpenStreetMap | OSM `way/856305164`，名称为“西园食堂” |
| `CANTEEN_E` | 东园食堂 | OpenStreetMap | OSM `way/925797333`，名称为“东区食堂”，对应本模型东园食堂 |
| `RESTAURANT_X` | 相山餐厅 | OpenStreetMap | OSM `way/919752762`，名称为“相山餐厅” |
| `GATE_S` | 南门临时服务点 | OpenStreetMap 邻近点 | 模型中的临时服务点，坐标匹配到 OSM `node/12055422212` “中山大学东南门” |
| `DORM_W` | 西园宿舍区 | OpenStreetMap 楼栋平均 | 由西园 1 栋、西园 2 号楼、西园 3 号楼、西园 6 号楼、西园 7 号楼中心点平均得到 |
| `DORM_E` | 东园宿舍区 | OpenStreetMap 楼栋平均 | 由东区 1 至 7 栋宿舍楼中心点平均得到 |
| `LIB` | 图书馆学习区 | 模型估算 | 未找到同名公开地图 POI；经纬度由平面坐标换算得到 |

## 参考链接

- OpenStreetMap 西园食堂：`https://www.openstreetmap.org/way/856305164`
- OpenStreetMap 东区食堂：`https://www.openstreetmap.org/way/925797333`
- OpenStreetMap 相山餐厅：`https://www.openstreetmap.org/way/919752762`
- OpenStreetMap 中山大学东南门：`https://www.openstreetmap.org/node/12055422212`
- 中山大学深圳校区校园地图：`https://shenzhen.sysu.edu.cn/node/84`

