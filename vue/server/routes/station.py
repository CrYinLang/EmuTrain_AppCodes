"""车站相关 API"""

from fastapi import APIRouter, HTTPException, Query
import httpx

import data_loader

router = APIRouter(prefix="/api/station", tags=["station"])


@router.get("/search")
async def search_station(
    keyword: str = Query(..., min_length=1, description="站名/拼音/编码"),
    limit: int = Query(20, ge=1, le=100),
):
    """车站搜索（本地数据，支持中文名/拼音/编码）"""
    kw = keyword.strip().lower()
    results = []
    for s in data_loader.station_data:
        name = (s.get("name") or "").lower()
        pinyin = (s.get("pinyin") or "").lower()
        short = (s.get("short_code") or "").lower()
        code = (s.get("code") or "").lower()
        telecode = (s.get("telecode") or "").lower()

        if kw in name or kw in pinyin or kw in short or kw in code or kw in telecode:
            results.append({
                "name": s.get("name"),
                "code": s.get("code"),
                "telecode": s.get("telecode"),
                "pinyin": s.get("pinyin"),
                "shortCode": s.get("short_code"),
                "city": s.get("city"),
                "province": s.get("province"),
                "district": s.get("district"),
                "location": s.get("location"),
            })
            if len(results) >= limit:
                break
    return results


@router.get("/screen")
async def station_screen(
    stationCode: str = Query(..., description="车站编码"),
    stationName: str = Query("", description="车站名称"),
    date: str = Query(..., description="日期 yyyy-MM-dd"),
    direction: int = Query(0, description="0=全部 1=出发 2=到达"),
    page: int = Query(1, ge=1),
    page_size: int = Query(40, ge=1, le=100),
):
    """车站大屏 - 查询车站到发信息（moefactory 接口）"""
    try:
        results = []
        dirs = ['D', 'A'] if direction == 0 else ['D'] if direction == 1 else ['A']

        for dir_code in dirs:
            cursor = (page - 1) * page_size
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.post(
                    "https://rail.moefactory.com/api/station/getBigScreenInfo",
                    headers={"Content-Type": "application/x-www-form-urlencoded"},
                    data={
                        "direction": dir_code,
                        "stationName": stationName or stationCode,
                        "cursor": str(cursor),
                        "count": str(page_size),
                    },
                )
                if resp.status_code == 200:
                    body = resp.json()
                    if body.get("code") == 200:
                        data = body.get("data", {})
                        train_list = data.get("data", [])
                        results.extend(train_list)

        # 按时间排序
        results.sort(key=lambda t: t.get("actualTime") or t.get("scheduledTime") or "")

        total = len(results)
        total_pages = (total + page_size - 1) // page_size if total else 0

        return {
            "data": [
                {
                    "trainCode": t.get("trainNumber"),
                    "from": t.get("beginStationName"),
                    "to": t.get("endStationName"),
                    "arriveTime": t.get("scheduledTime"),
                    "leaveTime": t.get("actualTime"),
                    "dayAfter": None,
                }
                for t in results
            ],
            "total": total,
            "page": page,
            "totalPages": total_pages,
        }
    except Exception as e:
        raise HTTPException(502, f"查询失败: {e}")


@router.get("/list")
async def get_station_list():
    """获取全部车站数据"""
    return [
        {
            "name": s.get("name"),
            "code": s.get("code"),
            "telecode": s.get("telecode"),
            "pinyin": s.get("pinyin"),
        }
        for s in data_loader.station_data
    ]
