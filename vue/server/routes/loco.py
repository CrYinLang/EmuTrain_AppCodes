"""机车查询 API"""

from fastapi import APIRouter, HTTPException, Query
import data_loader
from search import filter_by_loco_depot

router = APIRouter(prefix="/api/loco", tags=["loco"])


@router.get("/search")
async def search_loco(
    input: str = Query(..., min_length=1, description="车号或配属段"),
    type: str = Query("number", description="搜索类型: number|depot"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """机车搜索"""
    kw = input.strip()

    loco_data = data_loader.loco_data
    if type == "number":
        matched = [r for r in loco_data if kw in (r.get("车组号") or "")]
    elif type == "depot":
        matched = filter_by_loco_depot(loco_data, kw)
    else:
        raise HTTPException(400, f"未知搜索类型: {type}")

    total = len(matched)
    total_pages = (total + page_size - 1) // page_size if total else 0
    start = (page - 1) * page_size
    page_data = matched[start:start + page_size]

    return {
        "results": [
            {
                "model": r.get("model", ""),
                "number": r.get("车组号", ""),
                "depot": r.get("配属段", ""),
            }
            for r in page_data
        ],
        "total": total,
        "page": page,
        "totalPages": total_pages,
    }
