"""客车查询 API"""

from fastapi import APIRouter, HTTPException, Query
import data_loader
from search import filter_by_coach_owner

router = APIRouter(prefix="/api/coach", tags=["coach"])


@router.get("/search")
async def search_coach(
    input: str = Query(..., min_length=1, description="车号或配属"),
    type: str = Query("number", description="搜索类型: number|owner"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """客车搜索"""
    kw = input.strip()

    coach_data = data_loader.coach_data
    if type == "number":
        matched = [r for r in coach_data if kw in (r.get("车号") or "")]
    elif type == "owner":
        matched = filter_by_coach_owner(coach_data, kw)
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
                "number": r.get("车号", ""),
                "owner": r.get("现配属", ""),
                "capacity": r.get("定员"),
            }
            for r in page_data
        ],
        "total": total,
        "page": page,
        "totalPages": total_pages,
    }
