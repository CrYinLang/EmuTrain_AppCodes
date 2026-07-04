# EmuTrain 网页版 - 部署交接文档

## 项目概述

动车组 & 列车信息查询工具网页版，从 Flutter App 迁移而来。

- **前端**: Vue 3 + Vite（已构建为静态文件）
- **后端**: Python FastAPI
- **数据**: 本地 JSON 文件（动车组/车站/客车/机车）

## 目录结构

```
emutrain/
├── vue/                      # 前端 + 后端（完整项目）
│   ├── src/                  # Vue 3 前端源码
│   │   ├── api/              # API 接口定义
│   │   ├── components/       # 通用组件
│   │   ├── layouts/          # 布局组件
│   │   ├── router/           # 路由配置
│   │   ├── stores/           # Pinia 状态管理
│   │   └── views/            # 页面组件
│   ├── assets/               # 数据文件 + 图标
│   │   ├── train.json        # 动车组数据
│   │   ├── stations.json     # 车站数据
│   │   ├── coach.json        # 客车数据
│   │   ├── loco.json         # 机车数据
│   │   └── icon/             # 车型/路局图标
│   ├── server/               # FastAPI 后端
│   │   ├── main.py           # 入口
│   │   ├── data_loader.py    # 数据加载器
│   │   ├── icon_mapping.py   # 车型图标映射
│   │   ├── search.py         # 搜索核心逻辑
│   │   └── routes/           # API 路由
│   ├── dist/                 # ← 前端构建产物
│   └── vite.config.js
└── .gitignore
```

## 部署步骤

### 1. 后端部署

```bash
# 安装依赖
pip install fastapi uvicorn httpx

# 启动（生产环境去掉 reload）
cd vue/server
uvicorn main:app --host 0.0.0.0 --port 8000
```

后端启动时自动加载 `assets/` 目录下的 JSON 数据文件。

### 2. 前端部署

前端已构建为静态文件在 `vue/dist/` 目录，用 Nginx 或任何静态文件服务器托管即可。

**Nginx 配置示例:**

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # 前端静态文件
    location / {
        root /path/to/emutrain/vue/dist;
        try_files $uri $uri/ /index.html;
    }

    # API 代理
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
    }

    # 资源文件代理（车型图标等）
    location /assets/ {
        proxy_pass http://127.0.0.1:8000;
    }
}
```

### 3. 数据更新

数据文件在 `assets/` 目录，替换 JSON 文件后重启后端即可生效。

## API 接口一览

| 接口 | 方法 | 说明 |
|---|---|---|
| `/api/health` | GET | 健康检查，返回数据统计 |
| `/api/emu/search?input=3001&type=trainId` | GET | 车组搜索（本地数据） |
| `/api/emu/bureaus` | GET | 获取所有路局名称 |
| `/api/emu/depots` | GET | 获取所有动车所名称 |
| `/api/emu/types` | GET | 获取所有车型代号 |
| `/api/emu/route?emu_no=3001` | GET | 查询车组交路 |
| `/api/train/stops?trainNumber=G1234&date=2026-07-02&source=ctrip` | GET | 车次经停查询 |
| `/api/station/search?keyword=北京` | GET | 车站搜索 |
| `/api/station/screen?stationCode=IZQ&stationName=广州南` | GET | 车站大屏 |
| `/api/coach/search?input=080003` | GET | 客车搜索 |
| `/api/loco/search?input=0001` | GET | 机车搜索 |

## 外部数据源依赖

| 数据源 | 用途 | 是否必须 |
|---|---|---|
| 12306 | 车次经停、车站大屏 | 否（有备用源） |
| ctrip（携程） | 车次经停查询 | 推荐 |
| rail.re | 车次经停、交路查询 | 备用 |
| moefactory | 车站大屏、交路查询 | 是（车站大屏） |

## 注意事项

1. **数据文件编码**: JSON 文件必须是 UTF-8 编码
2. **图标文件**: `assets/icon/train/` 和 `assets/icon/bureau/` 目录必须保留
3. **CORS**: 后端已配置允许所有来源，生产环境建议限制
4. **12306 接口**: 部分接口需要完整 Cookie，小站可能查不到数据
5. **车站大屏**: 使用 moefactory 接口，凌晨时段数据较少
