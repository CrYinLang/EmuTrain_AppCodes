"""数据加载器 - 启动时加载所有 JSON 数据到内存"""

import json
import os
from pathlib import Path

ASSETS_DIR = Path(__file__).parent.parent / "assets"

# 全局数据容器
train_data: list[dict] = []       # 动车组列表（每条带 type_code）
station_data: list[dict] = []     # 车站列表
coach_data: list[dict] = []       # 客车列表（每条带 model）
loco_data: list[dict] = []        # 机车列表（每条带 model）

# 辅助索引
bureau_names: list[str] = []
depot_names: list[str] = []
car_types: list[str] = []


def _load_json(filename: str) -> dict | list:
    path = ASSETS_DIR / filename
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def load_all():
    """加载所有数据文件，应在 app 启动时调用"""
    global train_data, station_data, coach_data, loco_data
    global bureau_names, depot_names, car_types

    # ---- 动车组 ----
    raw = _load_json("train.json")
    train_data = []
    for model, records in raw.items():
        for r in records:
            r = dict(r)
            r["type_code"] = model
            train_data.append(r)

    # 提取路局、动车所、车型
    bureau_names = sorted({
        (r.get("配属路局") or "").strip()
        for r in train_data if r.get("配属路局")
    })
    depot_names = sorted({
        (r.get("配属动车所") or "").strip()
        for r in train_data if r.get("配属动车所")
    })
    car_types = sorted({r["type_code"] for r in train_data})

    # ---- 车站 ----
    station_data = _load_json("stations.json")

    # ---- 客车 ----
    raw = _load_json("coach.json")
    coach_data = []
    for model, records in raw.items():
        for r in records:
            r = dict(r)
            r["model"] = model
            coach_data.append(r)

    # ---- 机车 ----
    raw = _load_json("loco.json")
    loco_data = []
    for model, records in raw.items():
        for r in records:
            r = dict(r)
            r["model"] = model
            loco_data.append(r)

    print(
        f"[Data] Loaded: {len(train_data)} trains, "
        f"{len(station_data)} stations, "
        f"{len(coach_data)} coaches, "
        f"{len(loco_data)} locos"
    )
