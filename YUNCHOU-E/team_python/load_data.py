# load_data.py - 加载校区节点和订单数据

import json
import csv
import numpy as np

class Order:
    def __init__(self, id, pickup_id, pickup_name, delivery_id, delivery_name, weight, S, a, b):
        self.id = id
        self.pickup_id = pickup_id
        self.pickup_name = pickup_name
        self.delivery_id = delivery_id
        self.delivery_name = delivery_name
        self.weight = weight
        self.S = S          # 就绪时间 (h)
        self.a = a          # 最早可送达 (h)
        self.b = b          # 最晚可送达 (h)

class Node:
    def __init__(self, id, name, type, x, y, lat=None, lon=None):
        self.id = id
        self.name = name
        self.type = type
        self.x = x
        self.y = y
        self.lat = lat
        self.lon = lon

class Data:
    pass

def load_data(data_dir):
    """加载校区节点和订单数据"""
    data = Data()

    # === 加载校区节点 ===
    with open(f"{data_dir}/campus_nodes.json", "r", encoding="utf-8") as f:
        raw = json.load(f)

    data.nodes = []
    for n in raw["nodes"]:
        data.nodes.append(Node(n["id"], n["name"], n["type"], n["x"], n["y"], n.get("lat"), n.get("lon")))

    data.node_ids = [n.id for n in data.nodes]
    data.node_x = [n.x for n in data.nodes]
    data.node_y = [n.y for n in data.nodes]

    # 找出起降点
    data.depots = [n for n in data.nodes if n.type == "depot"]

    # === 加载订单数据 ===
    with open(f"{data_dir}/orders.json", "r", encoding="utf-8") as f:
        raw_order = json.load(f)

    data.n_orders = len(raw_order["orders"])
    data.orders = []
    for o in raw_order["orders"]:
        data.orders.append(Order(
            id=o["id"],
            pickup_id=o["pickup_id"],
            pickup_name=o["pickup_name"],
            delivery_id=o["delivery_id"],
            delivery_name=o["delivery_name"],
            weight=o["weight_kg"],
            S=o["ready_time_h"],
            a=o["tw_early_h"],
            b=o["tw_late_h"]
        ))

    # === 加载距离矩阵（实际飞行距离）===
    dist_file = f"{data_dir}/distance_matrix.csv"
    N = len(data.nodes)
    data.dist = np.zeros((N, N))

    try:
        with open(dist_file, "r", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            for row in reader:
                fi = data.node_ids.index(row["from_node"].strip())
                ti = data.node_ids.index(row["to_node"].strip())
                data.dist[fi, ti] = float(row["distance_m"])
        print(f"距离矩阵: 从 distance_matrix.csv 加载（实际飞行距离）")
    except FileNotFoundError:
        # 回退：用直线距离
        for u in range(N):
            for v in range(N):
                dx = data.node_x[u] - data.node_x[v]
                dy = data.node_y[u] - data.node_y[v]
                data.dist[u, v] = np.sqrt(dx**2 + dy**2)
        print("距离矩阵: 使用直线距离（未找到 distance_matrix.csv）")

    print(f"数据加载完成: 8 架无人机, {data.n_orders} 件快递, {N} 个节点")
    return data
