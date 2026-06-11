import argparse
import csv
import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DATA_DIR = ROOT / "data"
TIME_ORIGIN_H = 8.0

NODE_NAMES = {
    "CANTEEN_E": "东园食堂",
    "CANTEEN_W": "西园食堂",
    "GATE_S": "南门服务点",
    "RESTAURANT_X": "相山餐厅",
    "DORM_E": "东园宿舍区",
    "DORM_W": "西园宿舍区",
    "LIB": "图书馆学习区",
}


def convert_csv(source: Path, output: Path) -> dict:
    with source.open("r", encoding="utf-8-sig", newline="") as file:
        rows = list(csv.DictReader(file))

    orders = []
    for index, row in enumerate(rows, start=1):
        pickup_id = row["pickup_node"]
        delivery_id = row["delivery_node"]
        orders.append(
            {
                "id": index,
                "source_order_id": row["order_id"],
                "pickup_id": pickup_id,
                "pickup_name": NODE_NAMES[pickup_id],
                "delivery_id": delivery_id,
                "delivery_name": NODE_NAMES[delivery_id],
                "weight_kg": float(row["weight_kg"]),
                "volume_l": float(row["volume_l"]),
                "ready_time_h": round(TIME_ORIGIN_H + float(row["S_j_h"]), 4),
                "tw_early_h": round(TIME_ORIGIN_H + float(row["a_j_h"]), 4),
                "tw_late_h": round(TIME_ORIGIN_H + float(row["b_j_h"]), 4),
                "service_deadline_s": int(row["service_deadline_s"]),
                "priority": row["priority"],
                "splittable": bool(int(row["splittable"])),
                "order_type": row["order_type"],
            }
        )

    payload = {
        "description": f"中山大学深圳校区无人机配送订单（新版 {len(orders)} 单）",
        "source_file": source.name,
        "time_origin": "08:00",
        "drone_count": 20,
        "depots": ["DEP_W", "DEP_E"],
        "orders": orders,
    }
    with output.open("w", encoding="utf-8", newline="\n") as file:
        json.dump(payload, file, ensure_ascii=False, indent=2)
        file.write("\n")
    return payload


def parse_args():
    parser = argparse.ArgumentParser(description="Convert order CSV files to project JSON datasets.")
    parser.add_argument(
        "--orders-120",
        type=Path,
        default=DATA_DIR / "order_info_120_new.csv",
        help="Path to the 120-order CSV file.",
    )
    parser.add_argument(
        "--orders-300",
        type=Path,
        default=DATA_DIR / "order_info_300_new.csv",
        help="Path to the 300-order CSV file.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    sources = {
        120: args.orders_120.resolve(),
        300: args.orders_300.resolve(),
    }

    current = DATA_DIR / "orders.json"
    backup = DATA_DIR / "orders_before_20260610.json"
    if current.exists() and not backup.exists():
        shutil.copy2(current, backup)

    for size, source in sources.items():
        if not source.exists():
            raise FileNotFoundError(source)
        destination_csv = DATA_DIR / f"order_info_{size}_new.csv"
        if source != destination_csv.resolve():
            shutil.copy2(source, destination_csv)
        payload = convert_csv(source, DATA_DIR / f"orders_{size}.json")
        print(f"Imported {len(payload['orders'])} orders -> orders_{size}.json")

    shutil.copy2(DATA_DIR / "orders_120.json", current)
    print("Default dataset -> orders.json (120 orders)")


if __name__ == "__main__":
    main()
