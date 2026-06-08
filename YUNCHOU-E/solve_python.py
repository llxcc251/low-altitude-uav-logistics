import itertools
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DATA_DIR = ROOT / "data"


def load_json(name):
    with (DATA_DIR / name).open("r", encoding="utf-8") as f:
        return json.load(f)


def dist(a, b):
    return math.hypot(a["x"] - b["x"], a["y"] - b["y"])


def segment_cost(distance_m, load_kg, cfg):
    time_h = distance_m / (cfg["v_cruise"] * 3600.0)
    distance_km = distance_m / 1000.0
    energy_wh = cfg["e0"] * distance_km + cfg["e1"] * distance_km * load_kg
    return time_h, energy_wh


def build_config(drone_raw):
    drone = drone_raw["drone"]
    return {
        "n_drones": 6,
        "W_max": float(drone["max_payload_kg"]),
        "E_battery": float(drone["battery_capacity_wh"]),
        "v_cruise": float(drone["cruise_speed_ms"]),
        "t_max_min": float(drone["max_flight_time_min"]),
        "t_prep_min": 1.0,
        "t_swap_min": 2.0,
        "enable_cost": float(drone["enable_cost"]),
        "split_penalty": float(drone.get("split_penalty", 50)),
        "e0": 0.5,
        "e1": 0.05,
        "alpha": 1.0,
        "beta": 0.3,
        "gamma": 2.0,
        "max_orders_per_trip": 3,
        "max_trips_per_drone": 3,
    }


def load_data():
    nodes_raw = load_json("campus_nodes.json")
    orders_raw = load_json("orders.json")
    drone_raw = load_json("drone_params.json")
    nodes = nodes_raw["nodes"]
    node_by_id = {n["id"]: n for n in nodes}
    depots = [n for n in nodes if n["type"] == "depot"]
    orders = []
    for o in orders_raw["orders"]:
        orders.append(
            {
                "id": int(o["id"]),
                "pickup_id": o["pickup_id"],
                "pickup_name": o["pickup_name"],
                "delivery_id": o["delivery_id"],
                "delivery_name": o["delivery_name"],
                "weight": float(o["weight_kg"]),
                "S": float(o["ready_time_h"]),
                "a": float(o["tw_early_h"]),
                "b": float(o["tw_late_h"]),
            }
        )
    cfg = build_config(drone_raw)
    cfg["n_drones"] = int(orders_raw.get("drone_count", cfg["n_drones"]))
    return nodes, node_by_id, depots, orders, cfg


def nearest_depot(order_indices, depots, orders, node_by_id):
    best = None
    best_distance = float("inf")
    for depot in depots:
        total = 0.0
        for idx in order_indices:
            pickup = node_by_id[orders[idx]["pickup_id"]]
            total += dist(depot, pickup)
        if total < best_distance:
            best = depot
            best_distance = total
    return best


def nearest_sequence(order_indices, depot, orders, node_by_id):
    remaining = list(order_indices)
    sequence = []
    current = depot
    while remaining:
        best_pos = min(
            range(len(remaining)),
            key=lambda k: dist(current, node_by_id[orders[remaining[k]]["pickup_id"]]),
        )
        chosen = remaining.pop(best_pos)
        sequence.append(chosen)
        current = node_by_id[orders[chosen]["pickup_id"]]
    return sequence


def evaluate_trip(sequence, depot, orders, node_by_id, cfg, n_orders):
    total_weight = sum(orders[i]["weight"] for i in sequence)
    if total_weight > cfg["W_max"]:
        return None

    flight_time_h = 0.0
    elapsed_time_h = cfg["t_prep_min"] / 60.0
    energy_wh = 0.0
    late_h = 0.0
    current_load = total_weight
    current = depot
    segments = []

    for idx in sequence:
        order = orders[idx]
        pickup = node_by_id[order["pickup_id"]]
        delivery = node_by_id[order["delivery_id"]]

        d1 = dist(current, pickup)
        t1, e1 = segment_cost(d1, current_load, cfg)
        flight_time_h += t1
        elapsed_time_h += t1
        energy_wh += e1
        segments.append(
            {
                "from_id": current["id"],
                "to_id": pickup["id"],
                "from": {"x": current["x"], "y": current["y"]},
                "to": {"x": pickup["x"], "y": pickup["y"]},
                "type": "empty",
                "order_id": order["id"],
                "desc": "to pickup",
            }
        )

        d2 = dist(pickup, delivery)
        t2, e2 = segment_cost(d2, current_load, cfg)
        flight_time_h += t2
        elapsed_time_h += t2
        energy_wh += e2
        segments.append(
            {
                "from_id": pickup["id"],
                "to_id": delivery["id"],
                "from": {"x": pickup["x"], "y": pickup["y"]},
                "to": {"x": delivery["x"], "y": delivery["y"]},
                "type": "loaded",
                "order_id": order["id"],
                "desc": "鍙栬揣鐐光啋閰嶉€佺偣",
            }
        )

        arrival = order["S"] + elapsed_time_h
        if arrival < order["a"]:
            elapsed_time_h += order["a"] - arrival
            arrival = order["a"]
        if arrival > order["b"]:
            late_h += arrival - order["b"]

        current_load -= order["weight"]
        current = delivery

    d_return = dist(current, depot)
    t_ret, e_ret = segment_cost(d_return, 0.0, cfg)
    flight_time_h += t_ret
    elapsed_time_h += t_ret
    energy_wh += e_ret
    segments.append(
        {
            "from_id": current["id"],
            "to_id": depot["id"],
            "from": {"x": current["x"], "y": current["y"]},
            "to": {"x": depot["x"], "y": depot["y"]},
            "type": "empty",
            "order_id": 0,
            "desc": "return to depot",
        }
    )

    if energy_wh > cfg["E_battery"]:
        return None
    if flight_time_h > cfg["t_max_min"] / 60.0:
        return None

    mask = 0
    for idx in sequence:
        mask |= 1 << idx

    cost = cfg["alpha"] * elapsed_time_h + cfg["beta"] * energy_wh + cfg["gamma"] * late_h
    return {
        "mask": mask,
        "depot_id": depot["id"],
        "orders": [orders[i]["id"] for i in sequence],
        "order_indices": list(sequence),
        "segments": segments,
        "time_h": elapsed_time_h,
        "time_s": elapsed_time_h * 3600.0,
        "energy_wh": energy_wh,
        "late_h": late_h,
        "late_s": late_h * 3600.0,
        "cost": cost,
        "weight": total_weight,
    }


def generate_trips(depots, orders, node_by_id, cfg):
    trips = []
    max_q = min(cfg["max_orders_per_trip"], len(orders))
    for q in range(1, max_q + 1):
        for combo in itertools.combinations(range(len(orders)), q):
            if sum(orders[i]["weight"] for i in combo) > cfg["W_max"]:
                continue
            depot = nearest_depot(combo, depots, orders, node_by_id)
            sequence = nearest_sequence(combo, depot, orders, node_by_id)
            trip = evaluate_trip(sequence, depot, orders, node_by_id, cfg, len(orders))
            if trip:
                trips.append(trip)
    return trips


def solve_set_partition(trips, n_orders, cfg):
    full = (1 << n_orders) - 1
    if cfg["n_drones"] < 1:
        raise RuntimeError("drone_count must be greater than 0")

    trips_by_order = [[] for _ in range(n_orders)]
    for trip in trips:
        for idx in trip["order_indices"]:
            trips_by_order[idx].append(trip)

    memo = {full: (0.0, [])}

    def search(mask):
        if mask in memo:
            return memo[mask]

        first = None
        for idx in range(n_orders):
            if not (mask & (1 << idx)):
                first = idx
                break

        best_cost = float("inf")
        best_chosen = None
        for trip in trips_by_order[first]:
            if mask & trip["mask"]:
                continue
            tail_cost, tail_chosen = search(mask | trip["mask"])
            if math.isinf(tail_cost):
                continue
            cost = trip["cost"] + tail_cost
            if cost < best_cost:
                best_cost = cost
                best_chosen = [trip] + tail_chosen

        memo[mask] = (best_cost, best_chosen)
        return memo[mask]

    best_cost, selected = search(0)
    if not selected or math.isinf(best_cost):
        raise RuntimeError(
            "No feasible solution under current parameters. Check payload, endurance, or time windows."
        )
    return assign_trips_to_drones(selected, cfg)

def assign_trips_to_drones(selected_trips, cfg):
    drone_plans = [{"trips": [], "time_s": 0.0, "energy_wh": 0.0, "late_s": 0.0} for _ in range(cfg["n_drones"])]
    ordered = sorted(selected_trips, key=lambda t: t["time_s"], reverse=True)
    swap_s = cfg["t_swap_min"] * 60.0
    for trip in ordered:
        best_idx = min(range(cfg["n_drones"]), key=lambda i: drone_plans[i]["time_s"])
        plan = drone_plans[best_idx]
        if plan["trips"]:
            plan["time_s"] += swap_s
        plan["trips"].append(trip)
        plan["time_s"] += trip["time_s"]
        plan["energy_wh"] += trip["energy_wh"]
        plan["late_s"] += trip["late_s"]
    enabled = sum(1 for p in drone_plans if p["trips"])
    running_cost = sum(sum(t["cost"] for t in p["trips"]) for p in drone_plans)
    total_cost = cfg["enable_cost"] * enabled + running_cost
    return total_cost, drone_plans


def export_result(drone_plans, total_cost, orders, cfg):
    drones = []
    for i in range(cfg["n_drones"]):
        plan = drone_plans[i]
        if plan["trips"]:
            drones.append(
                {
                    "id": i + 1,
                    "enabled": True,
                    "trips": [
                        {
                            "depot_id": trip["depot_id"],
                            "orders": trip["orders"],
                            "segments": trip["segments"],
                            "time_s": trip["time_s"],
                            "energy_wh": trip["energy_wh"],
                            "late_s": trip["late_s"],
                        }
                        for trip in plan["trips"]
                    ],
                    "total_time_s": plan["time_s"],
                    "total_energy_wh": plan["energy_wh"],
                    "total_late_s": plan["late_s"],
                }
            )
        else:
            drones.append(
                {
                    "id": i + 1,
                    "enabled": False,
                    "trips": [],
                    "total_time_s": 0,
                    "total_energy_wh": 0,
                    "total_late_s": 0,
                }
            )

    active_plans = [p for p in drone_plans if p["trips"]]
    total_time_s = sum(p["time_s"] for p in active_plans)
    total_energy = sum(p["energy_wh"] for p in active_plans)
    total_late_s = sum(p["late_s"] for p in active_plans)
    result = {
        "source": "Python port of MATLAB candidate-route IP",
        "method": "candidate-route set optimization",
        "status": "ok",
        "summary": {
            "total_cost": total_cost,
            "enabled_drones": len(active_plans),
            "total_time_h": total_time_s / 3600.0,
            "total_time_s": total_time_s,
            "total_energy_wh": total_energy,
            "total_late_h": total_late_s / 3600.0,
            "total_late_s": total_late_s,
            "order_count": len(orders),
            "drone_count": cfg["n_drones"],
        },
        "drones": drones,
    }
    with (DATA_DIR / "results.json").open("w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    return result


def solve_and_export():
    _, node_by_id, depots, orders, cfg = load_data()
    trips = generate_trips(depots, orders, node_by_id, cfg)
    total_cost, drone_plans = solve_set_partition(trips, len(orders), cfg)
    return export_result(drone_plans, total_cost, orders, cfg)


def main():
    result = solve_and_export()
    print("Generated results.json")
    print(f"Enabled drones: {result['summary']['enabled_drones']}")
    print(f"Total cost: {result['summary']['total_cost']:.2f}")
    print(f"Total energy: {result['summary']['total_energy_wh']:.2f} Wh")


if __name__ == "__main__":
    main()

