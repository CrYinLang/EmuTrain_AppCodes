"""动车组搜索 API"""

from datetime import datetime
from fastapi import APIRouter, HTTPException, Query
import httpx

import data_loader
from icon_mapping import get_train_icon_path
from search import (
    score_and_select,
    filter_by_bureau,
    filter_by_car_type,
    filter_by_depot,
)

router = APIRouter(prefix="/api/emu", tags=["emu"])


def _format_result(r: dict) -> dict:
    bureau = (r.get("配属路局") or "").strip()
    model = r.get("type_code", "")
    number = r.get("车组号", "")
    return {
        "model": model,
        "number": number,
        "bureau": bureau,
        "bureauFullName": bureau,
        "depot": r.get("配属动车所"),
        "manufacturer": r.get("生产厂家"),
        "remarks": r.get("备注"),
        "routeInfo": None,
        "iconPath": get_train_icon_path(model, number),
        "bureauIconPath": f"icon/bureau/{bureau}.png" if bureau else None,
        "queryTime": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    }


@router.get("/search")
async def search_emu(
    input: str = Query(..., min_length=1, description="搜索关键词"),
    type: str = Query("trainId", description="搜索类型: trainId|bureau|carType|depot"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """车组搜索（本地数据）"""
    train_data = data_loader.train_data
    if not train_data:
        raise HTTPException(500, "数据未加载")

    if type == "trainId":
        matched = score_and_select(train_data, input)
        if matched is None:
            return {"results": [], "total": 0, "page": 1, "totalPages": 0}
        if not matched:
            return {"results": [], "total": 0, "page": 1, "totalPages": 0}
    elif type == "bureau":
        matched = filter_by_bureau(train_data, input)
    elif type == "carType":
        matched = filter_by_car_type(train_data, input)
    elif type == "depot":
        matched = filter_by_depot(train_data, input)
    else:
        raise HTTPException(400, f"未知搜索类型: {type}")

    total = len(matched)
    total_pages = (total + page_size - 1) // page_size
    start = (page - 1) * page_size
    end = start + page_size
    page_data = matched[start:end]

    return {
        "results": [_format_result(r) for r in page_data],
        "total": total,
        "page": page,
        "totalPages": total_pages,
    }


@router.get("/bureaus")
async def get_bureaus():
    """获取所有路局名称（去重排序）"""
    return data_loader.bureau_names


@router.get("/depots")
async def get_depots():
    """获取所有动车所名称（去重排序）"""
    return data_loader.depot_names


@router.get("/types")
async def get_types():
    """获取所有车型代号（去重排序）"""
    return data_loader.car_types


@router.get("/route")
async def get_emu_route(
    emu_no: str = Query(..., description="车组号"),
    source: str = Query("railRe", description="数据源: railRe|moeFactory|railGo"),
):
    """查询车组当前担当交路"""
    try:
        if source == "moeFactory":
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.post(
                    "https://rail.moefactory.com/api/emuSerialNumber/query",
                    data={"keyword": emu_no},
                    headers={"Content-Type": "application/x-www-form-urlencoded"},
                )
                if resp.status_code == 200:
                    body = resp.json()
                    if body.get("code") == 200 and body.get("data"):
                        item = body["data"][0]
                        train_no = item.get("trainNumber", "")
                        date = item.get("date", "")
                        if train_no:
                            return {"route": f"正在担当: {date}\n本务车次: {train_no}"}
            return {"route": None}

        elif source == "railGo":
            url = f"https://emu.data.railgo.zenglingkun.cn/emu/{emu_no}"
        else:
            url = f"https://api.rail.re/emu/{emu_no}"

        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url)
            if resp.status_code == 200 and resp.text and resp.text != "[]":
                data = resp.json()
                if data:
                    item = data[0]
                    train_no = item.get("train_no", "")
                    date = item.get("date", "")
                    if train_no:
                        return {"route": f"正在担当: {date}\n本务车次: {train_no}"}
        return {"route": None}
    except Exception as e:
        raise HTTPException(502, f"数据源请求失败: {e}")
