# generate_elevation.py - 获取OSM建筑物数据 + A*寻路计算真实绕行系数

import numpy as np
import json
import csv
import heapq

# === 配置 ===
CENTER_LAT = 22.803
CENTER_LON = 113.952
RADIUS_M = 1200

# 网格参数（正方形网格）
GRID_SIZE = 1000  # 1000x1000网格
CELL_SIZE_M = 2   # 每格2米

# 根据CELL_SIZE计算经纬度范围
LAT_RANGE = [CENTER_LAT - (GRID_SIZE/2 * CELL_SIZE_M) / 111000,
             CENTER_LAT + (GRID_SIZE/2 * CELL_SIZE_M) / 111000]
LON_RANGE = [CENTER_LON - (GRID_SIZE/2 * CELL_SIZE_M) / (111000 * np.cos(np.radians(CENTER_LAT))),
             CENTER_LON + (GRID_SIZE/2 * CELL_SIZE_M) / (111000 * np.cos(np.radians(CENTER_LAT)))]

# 无人机参数
DRONE_ALTITUDE = 50.0   # 无人机飞行高度（米）
SAFETY_MARGIN = 5.0     # 安全余量（米）
# 所有建筑物都视为障碍物，无人机必须绕过，不能飞越
# 任何建筑物高度 > 0 都会阻挡路径

# 节点坐标
NODES = [
    {"id": "DEP_W", "name": "西区起降点", "lat": 22.8012, "lon": 113.9456},
    {"id": "DEP_E", "name": "东区起降点", "lat": 22.8053, "lon": 113.9534},
    {"id": "CANTEEN_W", "name": "西园食堂", "lat": 22.8004, "lon": 113.9411},
    {"id": "CANTEEN_E", "name": "东园食堂", "lat": 22.8041, "lon": 113.9572},
    {"id": "RESTAURANT_X", "name": "相山餐厅", "lat": 22.8021, "lon": 113.9483},
    {"id": "GATE_S", "name": "南门服务点", "lat": 22.8025, "lon": 113.9562},
    {"id": "DORM_W", "name": "西园宿舍区", "lat": 22.8020, "lon": 113.9401},
    {"id": "DORM_E", "name": "东园宿舍区", "lat": 22.8053, "lon": 113.9592},
    {"id": "LIB", "name": "图书馆学习区", "lat": 22.8051, "lon": 113.9493},
]


def latlon_to_grid(lat, lon):
    """经纬度转网格坐标"""
    gi = int((lat - LAT_RANGE[0]) / (LAT_RANGE[1] - LAT_RANGE[0]) * GRID_SIZE)
    gj = int((lon - LON_RANGE[0]) / (LON_RANGE[1] - LON_RANGE[0]) * GRID_SIZE)
    gi = max(0, min(GRID_SIZE - 1, gi))
    gj = max(0, min(GRID_SIZE - 1, gj))
    return gi, gj


def grid_to_latlon(gi, gj):
    """网格坐标转经纬度"""
    lat = LAT_RANGE[0] + (gi + 0.5) * (LAT_RANGE[1] - LAT_RANGE[0]) / GRID_SIZE
    lon = LON_RANGE[0] + (gj + 0.5) * (LON_RANGE[1] - LON_RANGE[0]) / GRID_SIZE
    return lat, lon


def get_building_heights():
    """从OSM获取建筑物楼高"""
    print("正在从 OpenStreetMap 获取建筑物数据...")

    try:
        import osmnx as ox

        buildings = ox.features_from_point(
            (CENTER_LAT, CENTER_LON),
            tags={'building': True},
            dist=RADIUS_M
        )

        print(f"获取到 {len(buildings)} 个建筑物")

        building_data = []
        for idx, row in buildings.iterrows():
            if row.geometry is not None:
                geom = row.geometry
                if geom.geom_type == 'Polygon':
                    coords = list(geom.exterior.coords)
                    centroid = geom.centroid

                    # 获取楼高
                    h = None
                    if 'height' in row and row['height'] is not None:
                        try:
                            h = float(str(row['height']).replace('m', '').strip())
                        except:
                            pass
                    if h is None and 'building:levels' in row and row['building:levels'] is not None:
                        try:
                            h = int(row['building:levels']) * 3.0
                        except:
                            pass
                    if h is None or np.isnan(h):
                        btype = str(row.get('building', 'yes')).lower()
                        h_map = {
                            'dormitory': 30, 'apartments': 30, 'residential': 30,
                            'university': 20, 'school': 20, 'college': 20,
                            'restaurant': 10, 'canteen': 10, 'cafe': 10,
                            'sports': 12, 'gymnasium': 12,
                            'hospital': 18, 'clinic': 18,
                            'retail': 15, 'commercial': 15,
                            'industrial': 12, 'warehouse': 12,
                            'construction': 15, 'yes': 15,
                        }
                        h = h_map.get(btype, 15)

                    building_data.append({
                        'lat': centroid.y,
                        'lon': centroid.x,
                        'height': h,
                        'type': str(row.get('building', 'unknown')),
                        'polygon': coords
                    })

        with open('buildings_osm.json', 'w', encoding='utf-8-sig') as f:
            json.dump(building_data, f, ensure_ascii=False, indent=2)

        print(f"已保存 {len(building_data)} 个建筑物到 buildings_osm.json")
        return building_data

    except Exception as e:
        print(f"获取OSM数据失败: {e}，使用模拟数据...")
        return get_simulated_buildings()


def get_simulated_buildings():
    """模拟建筑物数据"""
    buildings = [
        {"lat": 22.8012, "lon": 113.9456, "height": 5, "type": "depot"},
        {"lat": 22.8053, "lon": 113.9534, "height": 5, "type": "depot"},
        {"lat": 22.8004, "lon": 113.9411, "height": 10, "type": "canteen"},
        {"lat": 22.8041, "lon": 113.9572, "height": 10, "type": "canteen"},
        {"lat": 22.8021, "lon": 113.9483, "height": 12, "type": "restaurant"},
        {"lat": 22.8025, "lon": 113.9562, "height": 8, "type": "service"},
        {"lat": 22.8020, "lon": 113.9401, "height": 35, "type": "dormitory"},
        {"lat": 22.8053, "lon": 113.9592, "height": 35, "type": "dormitory"},
        {"lat": 22.8051, "lon": 113.9493, "height": 25, "type": "library"},
        {"lat": 22.8035, "lon": 113.9500, "height": 22, "type": "teaching"},
        {"lat": 22.8040, "lon": 113.9510, "height": 22, "type": "teaching"},
        {"lat": 22.8045, "lon": 113.9520, "height": 20, "type": "teaching"},
        {"lat": 22.8015, "lon": 113.9465, "height": 15, "type": "lab"},
        {"lat": 22.8025, "lon": 113.9475, "height": 18, "type": "office"},
        {"lat": 22.8030, "lon": 113.9490, "height": 30, "type": "dormitory"},
        {"lat": 22.8035, "lon": 113.9495, "height": 30, "type": "dormitory"},
        {"lat": 22.8050, "lon": 113.9550, "height": 12, "type": "sports"},
        {"lat": 22.8048, "lon": 113.9540, "height": 10, "type": "canteen"},
        {"lat": 22.8020, "lon": 113.9450, "height": 20, "type": "teaching"},
        {"lat": 22.8025, "lon": 113.9440, "height": 20, "type": "teaching"},
        {"lat": 22.8030, "lon": 113.9430, "height": 18, "type": "lab"},
    ]
    with open('buildings_osm.json', 'w', encoding='utf-8-sig') as f:
        json.dump(buildings, f, ensure_ascii=False, indent=2)
    print(f"已生成 {len(buildings)} 个建筑物模拟数据")
    return buildings


def generate_elevation_grid(buildings):
    """生成高程网格：地面高程 + 楼高 = 障碍物高度"""
    print("生成高程网格...")

    # 地面高程（中山大学深圳校区约40-60米）
    BASE_ELEVATION = 45.0

    # 初始化网格：只存建筑物高度（障碍物高度）
    obstacle_grid = np.zeros((GRID_SIZE, GRID_SIZE))

    for b in buildings:
        # 用原始建筑物轮廓，不缩小
        if 'polygon' in b and len(b['polygon']) > 2:
            for coord in b['polygon']:
                lat, lon = coord[1], coord[0]
                gi, gj = latlon_to_grid(lat, lon)
                if 0 <= gi < GRID_SIZE and 0 <= gj < GRID_SIZE:
                    obstacle_grid[gi, gj] = max(obstacle_grid[gi, gj], b['height'])
        else:
            # 没有轮廓，用质心 + 扩散
            gi, gj = latlon_to_grid(b['lat'], b['lon'])
            radius = max(1, int(b['height'] / 15))
            for di in range(-radius, radius + 1):
                for dj in range(-radius, radius + 1):
                    ni, nj = gi + di, gj + dj
                    if 0 <= ni < GRID_SIZE and 0 <= nj < GRID_SIZE:
                        obstacle_grid[ni, nj] = max(obstacle_grid[ni, nj], b['height'])

    # 保存
    np.save('elevation_grid.npy', obstacle_grid)

    grid_info = {
        'grid_size': GRID_SIZE,
        'lat_range': LAT_RANGE,
        'lon_range': LON_RANGE,
        'base_elevation': BASE_ELEVATION,
        'drone_altitude': DRONE_ALTITUDE,
        'obstacle_rule': '所有建筑物视为障碍物，必须绕过',
    }
    with open('elevation_grid_info.json', 'w') as f:
        json.dump(grid_info, f)

    max_h = np.max(obstacle_grid)
    print(f"高程网格: {GRID_SIZE}x{GRID_SIZE}, 最高障碍物: {max_h:.1f}m, 飞行高度: {DRONE_ALTITUDE}m")
    return obstacle_grid


def heuristic(a, b):
    """A* 启发函数：欧氏距离"""
    return np.sqrt((a[0] - b[0])**2 + (a[1] - b[1])**2)


def astar(grid, start, goal):
    """
    A* 寻路算法
    在高程网格上寻找从 start 到 goal 的最短路径
    避开所有建筑物（任何高度都视为障碍）
    """
    rows, cols = grid.shape

    # 8方向移动
    neighbors = [(-1, 0, 1.0), (1, 0, 1.0), (0, -1, 1.0), (0, 1, 1.0),
                 (-1, -1, 1.414), (-1, 1, 1.414), (1, -1, 1.414), (1, 1, 1.414)]

    open_set = [(0, start)]
    came_from = {}
    g_score = {start: 0}
    f_score = {start: heuristic(start, goal)}
    closed_set = set()

    while open_set:
        _, current = heapq.heappop(open_set)

        if current == goal:
            # 重建路径
            path = [current]
            while current in came_from:
                current = came_from[current]
                path.append(current)
            return path[::-1]

        if current in closed_set:
            continue
        closed_set.add(current)

        for di, dj, cost in neighbors:
            ni, nj = current[0] + di, current[1] + dj

            if 0 <= ni < rows and 0 <= nj < cols:
                # 检查是否有建筑物（任何高度都视为障碍）
                if grid[ni, nj] > 0:
                    continue

                neighbor = (ni, nj)
                if neighbor in closed_set:
                    continue

                # 移动成本 + 障碍物高度惩罚（高处绕行代价更大）
                height_penalty = 1.0 + grid[ni, nj] / 100.0
                tentative_g = g_score[current] + cost * height_penalty

                if neighbor not in g_score or tentative_g < g_score[neighbor]:
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g
                    f_score[neighbor] = tentative_g + heuristic(neighbor, goal)
                    heapq.heappush(open_set, (f_score[neighbor], neighbor))

    return None  # 无路径


def grid_distance(path):
    """计算网格路径的距离（与A*一致，用网格坐标）"""
    if path is None or len(path) < 2:
        return float('inf')

    total = 0
    for i in range(1, len(path)):
        di = path[i][0] - path[i-1][0]
        dj = path[i][1] - path[i-1][1]
        d = np.sqrt(di**2 + dj**2) * CELL_SIZE_M
        total += d

    return total


def straight_distance(lat1, lon1, lat2, lon2):
    """计算两点间直线距离（米），用网格坐标（与A*一致）"""
    # 转换为网格坐标
    gi1, gj1 = latlon_to_grid(lat1, lon1)
    gi2, gj2 = latlon_to_grid(lat2, lon2)

    # 计算网格距离
    di = gi2 - gi1
    dj = gj2 - gj1
    d = np.sqrt(di**2 + dj**2) * CELL_SIZE_M

    return d


def generate_corridors(obstacle_grid):
    """用A*寻路计算真实走廊距离"""
    print("用 A* 寻路计算走廊...")

    corridors = []

    for i, n1 in enumerate(NODES):
        for j, n2 in enumerate(NODES):
            if i >= j:
                continue

            # 直线距离
            s_dist = straight_distance(n1['lat'], n1['lon'], n2['lat'], n2['lon'])

            # 网格坐标
            g1 = latlon_to_grid(n1['lat'], n1['lon'])
            g2 = latlon_to_grid(n2['lat'], n2['lon'])

            # A* 寻路
            path = astar(obstacle_grid, g1, g2)

            if path is not None:
                r_dist = grid_distance(path)
                detour = r_dist / s_dist if s_dist > 0 else 1.0

                # 检查路径上最高障碍物
                max_obs = max(obstacle_grid[p[0], p[1]] for p in path)

                # 所有建筑物都视为障碍，能找到路径就是可飞
                status = "可飞"
                if detour > 1.3:
                    status = "条件可飞"  # 绕行太大，需人工复核

                # 把路径点转成经纬度
                path_latlon = []
                for p in path:
                    lat, lon = grid_to_latlon(p[0], p[1])
                    path_latlon.append([round(lon, 6), round(lat, 6)])

                corridors.append({
                    'from': n1['id'],
                    'to': n2['id'],
                    'from_name': n1['name'],
                    'to_name': n2['name'],
                    'straight_distance_m': round(s_dist, 1),
                    'route_distance_m': round(r_dist, 1),
                    'detour_ratio': round(detour, 3),
                    'path_cells': len(path),
                    'max_obstacle_height_m': round(max_obs, 1),
                    'status': status,
                    'path_latlon': path_latlon,
                })

                print(f"  {n1['id']:>12} -> {n2['id']:<12}: {s_dist:>6.0f}m -> {r_dist:>6.0f}m "
                      f"(绕行{detour:.2f}) 最高障碍{max_obs:.0f}m [{status}]")
            else:
                print(f"  {n1['id']:>12} -> {n2['id']:<12}: 无路径！")

    # 保存走廊数据
    with open('corridors_elevation.json', 'w', encoding='utf-8-sig') as f:
        json.dump(corridors, f, ensure_ascii=False, indent=2)

    # 生成邻接矩阵
    node_ids = [n['id'] for n in NODES]
    adj_matrix = np.zeros((len(NODES), len(NODES)))

    for c in corridors:
        if c['status'] != '不建议':
            i = node_ids.index(c['from'])
            j = node_ids.index(c['to'])
            adj_matrix[i, j] = 1
            adj_matrix[j, i] = 1

    with open('adjacency_matrix_elevation.csv', 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.writer(f)
        writer.writerow(['node_id'] + node_ids)
        for i, nid in enumerate(node_ids):
            writer.writerow([nid] + list(adj_matrix[i].astype(int)))

    # 生成距离矩阵（给算法用）
    dist_matrix = np.zeros((len(NODES), len(NODES)))
    for c in corridors:
        i = node_ids.index(c['from'])
        j = node_ids.index(c['to'])
        dist_matrix[i, j] = c['route_distance_m']
        dist_matrix[j, i] = c['route_distance_m']

    with open('distance_matrix_elevation.csv', 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.writer(f)
        writer.writerow(['from_node', 'to_node', 'distance_m'])
        for i, n1 in enumerate(NODES):
            for j, n2 in enumerate(NODES):
                writer.writerow([n1['id'], n2['id'], dist_matrix[i, j]])

    print(f"\n共 {len(corridors)} 条走廊")
    return corridors


def main():
    print("=" * 60)
    print("  高程网格 + A*寻路 走廊生成器")
    print("=" * 60)

    # 1. 获取建筑物数据
    buildings = get_building_heights()

    # 2. 生成高程网格
    obstacle_grid = generate_elevation_grid(buildings)

    # 3. A*寻路生成走廊
    corridors = generate_corridors(obstacle_grid)

    print("\n" + "=" * 60)
    print("  完成！输出文件：")
    print("  - buildings_osm.json (建筑物数据)")
    print("  - elevation_grid.npy (高程网格)")
    print("  - corridors_elevation.json (走廊数据)")
    print("  - adjacency_matrix_elevation.csv (邻接矩阵)")
    print("  - distance_matrix_elevation.csv (距离矩阵)")
    print("=" * 60)


if __name__ == "__main__":
    main()
