"""EmuTrain 后端 - FastAPI"""

import sys
from pathlib import Path

# 把 backend 目录加到 Python path
sys.path.insert(0, str(Path(__file__).parent))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

import data_loader
from routes import emu, train, station, coach, loco


app = FastAPI(title="EmuTrain API", version="1.0.0")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 路由
app.include_router(emu.router)
app.include_router(train.router)
app.include_router(station.router)
app.include_router(coach.router)
app.include_router(loco.router)

# 静态文件 - 车型图标
assets_dir = Path(__file__).parent.parent / "assets"
if assets_dir.exists():
    app.mount("/assets", StaticFiles(directory=str(assets_dir)), name="assets")


@app.on_event("startup")
async def startup():
    data_loader.load_all()


@app.get("/api/health")
async def health():
    return {
        "status": "ok",
        "trains": len(data_loader.train_data),
        "stations": len(data_loader.station_data),
        "coaches": len(data_loader.coach_data),
        "locos": len(data_loader.loco_data),
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8001)
