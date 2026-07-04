"""车次查询 API"""

from fastapi import APIRouter, HTTPException, Query
import httpx

router = APIRouter(prefix="/api/train", tags=["train"])

DEFAULT_HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}


@router.get("/stops")
async def get_train_stops(
    trainNumber: str = Query(..., description="车次号"),
    date: str = Query(..., description="日期 yyyy-MM-dd"),
    source: str = Query("ctrip", description="数据源: 12306|ctrip|railRe"),
):
    """查询车次经停信息"""
    try:
        if source == "ctrip":
            return await _search_ctrip(trainNumber, date)
        elif source == "12306":
            return await _search_12306(trainNumber, date)
        elif source == "railRe":
            return await _search_railre(trainNumber, date)
        else:
            raise HTTPException(400, f"未知数据源: {source}")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(502, f"查询失败: {e}")


async def _search_ctrip(train_number: str, date: str) -> list:
    """携程接口"""
    url = "https://m.ctrip.com/restapi/soa2/14674/json/GetTrainStopTimeInfo"
    headers = {
        **DEFAULT_HEADERS,
        "Content-Type": "application/json",
        "Referer": "https://m.ctrip.com/",
        "Origin": "https://m.ctrip.com",
    }
    body = {"TrainNumber": train_number, "DepartDate": date}

    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.post(url, headers=headers, json=body)
        if resp.status_code == 200:
            data = resp.json()
            if data.get("RetCode") == 1 and data.get("StopList"):
                return [
                    {
                        "station_name": s.get("StationName"),
                        "arrive_time": s.get("ArriveTime"),
                        "leave_time": s.get("StartTime"),
                        "stop_duration": s.get("StopTime"),
                    }
                    for s in data["StopList"]
                ]
            return []
        raise HTTPException(502, f"携程接口返回 {resp.status_code}")


async def _search_12306(train_number: str, date: str) -> list:
    """12306接口"""
    formatted_date = date.replace("-", "")
    url = (
        f"https://kyfw.12306.cn/otn/czxx/queryByTrainNo"
        f"?train_no={train_number.upper()}&start_station_telecode="
        f"&end_station_telecode=&depart_date={formatted_date}"
    )
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(url, headers=DEFAULT_HEADERS)
        if resp.status_code == 200:
            data = resp.json()
            stop_list = data.get("data", {}).get("data", [])
            return [
                {
                    "station_name": s.get("station_name"),
                    "arrive_time": s.get("arrive_time"),
                    "leave_time": s.get("start_time"),
                    "stop_duration": s.get("stopover_time"),
                }
                for s in stop_list
            ]
        raise HTTPException(502, f"12306接口返回 {resp.status_code}")


async def _search_railre(train_number: str, date: str) -> list:
    """rail.re接口"""
    url = f"https://rail.re/api/train/{train_number.upper()}?date={date}"
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(url, headers=DEFAULT_HEADERS)
        if resp.status_code == 200:
            data = resp.json()
            if isinstance(data, list) and data:
                return [
                    {
                        "station_name": s.get("station_name"),
                        "arrive_time": s.get("arrive_time"),
                        "leave_time": s.get("departure_time"),
                        "stop_duration": s.get("stop_time"),
                    }
                    for s in data
                ]
            return []
        raise HTTPException(502, f"rail.re接口返回 {resp.status_code}")


@router.get("/search-by-station")
async def search_train_by_station(
    fromStation: str = Query(..., description="出发站 telecode"),
    toStation: str = Query(..., description="到达站 telecode"),
    date: str = Query(..., description="日期 yyyy-MM-dd"),
    source: str = Query("railRe"),
):
    """按始发终到查询车次"""
    try:
        formatted_date = date.replace("-", "")
        url = (
            f"https://kyfw.12306.cn/otn/leftTicket/queryG"
            f"?leftTicketDTO.train_date={formatted_date}"
            f"&leftTicketDTO.from_station={fromStation}"
            f"&leftTicketDTO.to_station={toStation}"
            f"&purpose_codes=ADULT"
        )
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Cookie": "_uab_collina=172000000000000; JSESSIONID=0",
        }
        async with httpx.AsyncClient(timeout=15, follow_redirects=True) as client:
            resp = await client.get(url, headers=headers)
            if resp.status_code == 200:
                try:
                    data = resp.json()
                    result_list = data.get("data", {}).get("result", [])
                    station_map = data.get("data", {}).get("map", {})
                    trains = []
                    for item in result_list:
                        parts = item.split("|")
                        if len(parts) > 10:
                            trains.append({
                                "trainCode": parts[3],
                                "from": station_map.get(parts[6], parts[6]),
                                "to": station_map.get(parts[7], parts[7]),
                                "leaveTime": parts[8],
                                "arriveTime": parts[9],
                                "duration": parts[10],
                            })
                    return trains
                except Exception:
                    pass
        return []
    except Exception as e:
        raise HTTPException(502, f"查询失败: {e}")


@router.get("/search-by-code")
async def search_train_by_code(
    trainCode: str = Query(..., description="车次号，如 G1234"),
    date: str = Query(..., description="日期 yyyy-MM-dd"),
):
    """通过车次号查询 emu_no（12306 搜索接口）"""
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                f"https://search.12306.cn/search/v1/train/search?keyword={trainCode}&date={date}",
                headers=DEFAULT_HEADERS,
            )
            if resp.status_code == 200:
                data = resp.json()
                if data.get("status") and data.get("data"):
                    results = []
                    for train in data["data"]:
                        code = train.get("station_train_code", "").strip()
                        from_s = train.get("from_station", "").strip()
                        to_s = train.get("to_station", "").strip()
                        if code == trainCode and from_s and to_s:
                            results.append({
                                "trainCode": code,
                                "from": from_s,
                                "to": to_s,
                            })
                    return results
            return []
    except Exception as e:
        raise HTTPException(502, f"查询失败: {e}")
