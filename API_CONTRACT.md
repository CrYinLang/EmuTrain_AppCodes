# EmuTrain 网页版 - 前后端接口约定

前端已就绪，后端 FastAPI 需实现以下接口。

## 基础约定

- Base URL: `/api`
- 响应格式: JSON
- 错误响应: `{ "detail": "错误信息" }`

## 接口列表

### 1. 车组搜索
```
GET /api/emu/search?input=CR400AF
```
响应: `List[EmuResult]`
```json
[
  {
    "model": "CR400AF",
    "number": "CR400AF-3001",
    "bureau": "京局",
    "bureauFullName": "北京铁路局",
    "depot": "北京南动车所",
    "manufacturer": "中车青岛四方",
    "remarks": null,
    "routeInfo": "G1/G3/G5...",
    "queryTime": "2026-07-02"
  }
]
```

### 2. 车次经停查询
```
GET /api/train/stops?trainNumber=G1234&date=2026-07-02&source=ctrip
```
- source: `12306` | `ctrip` | `railRe`

响应: `List[StopInfo]`
```json
[
  {
    "station_name": "北京南",
    "arrive_time": null,
    "leave_time": "08:00",
    "stop_duration": null
  },
  {
    "station_name": "济南西",
    "arrive_time": "09:30",
    "leave_time": "09:32",
    "stop_duration": "2分钟"
  }
]
```

### 3. 车站搜索
```
GET /api/station/search?keyword=北京
```
响应: `List[Station]`
```json
[
  { "name": "北京", "code": "BJP", "pinyin": "beijing" }
]
```

### 4. 车站车次列表 (车站大屏)
```
GET /api/station/trains?stationCode=BJP&date=2026-07-02&direction=0&page=1
```
- direction: 0=全部, 1=出发, 2=到达

响应: `{ "data": [...], "total": 100, "page": 1, "totalPages": 3 }`

### 5. 车次搜索（按始发终到）
```
GET /api/train/search?fromStation=BJP&toStation=SHH&date=2026-07-02&source=ctrip
```

## 数据源

后端需要对接的外部 API:
- 12306: `kyfw.12306.cn/otn/czxx/queryByTrainNo`
- 携程: `m.ctrip.com/restapi/soa2/14674/json/GetTrainStopTimeInfo`
- rail.re: `rail.re/api/train/{trainNo}`
- 车组本地数据: 需提供 `train_data.json` (约 3000+ 条动车组记录)

## 后端依赖 (FastAPI)

```
fastapi
uvicorn
httpx  # 异步 HTTP 客户端
```
