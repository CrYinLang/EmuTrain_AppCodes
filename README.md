<div align="center">
  <img src="./assets/icon/app_icon.png" alt="EmuTrain" width="72" />
  <h1>EmuTrain</h1>
  <p>写给铁路爱好者的动车组查询、旅途记录和线路工具箱。</p>
</div>

---

EmuTrain 最开始看起来像一个“查车次、查车号”的小工具，但它实际想做的事情更完整一点：把追车时常用的信息、自己坐过的车、常看的线路和现场速度记录放在同一个 App 里。

如果你经常需要查某趟车今天用什么车、某组车现在可能在跑哪条交路，或者只是想把自己的乘车记录保存得更清楚，EmuTrain 大概就是为这类场景准备的。

## 主要功能

### 旅途记录

- 保存自己的乘车行程，记录车次、上下车站、时间、日期和座位信息。
- 行程卡片会显示当前状态，比如今天、明天、已上车、已到达、已过期。
- 详情页可以查看完整站点、区间耗时和线路图。
- 支持自定义旅途，适合补录非标准线路或临时记录。

### 动车组查询

- 按车次查询当日运行信息、停靠站点和所用车组。
- 按车号查询动车组配属、厂家、路局、动车所等信息。
- 可选显示当前交路信息，并支持多个数据源切换。
- 支持按车型、路局、动车所进行本地数据筛选。

### 更多铁路工具

- 车站大屏：查看指定车站的实时到发信息。
- 客车查询：查询普速客车配属和相关信息。
- 机车查询：查询机车编号、配属段和车型。
- 线路制造处：新建、编辑、导入、导出线路，并查看线路走向图。
- GPS 速度计：记录行驶速度、最高速度、移动距离和历史轨迹。
- 动车图鉴：整理了一批特殊车型和车次资料，方便快速查看。

### 个性化和数据管理

- 支持深色模式、跟随系统主题、Android 12+ 莫奈取色和预设主题色。
- 可开关列车图片、路局图标、自动更新提示等显示项。
- 内置数据版本管理，可单独更新车站、动车组配属、普速客车配属和机车配属数据。
- 支持 Gitee、GitHub 和镜像源作为远程数据来源。

## 数据来源

EmuTrain 会结合本地数据和网络数据使用，主要来源包括：

| 数据源 | 用途 |
| --- | --- |
| 12306 | 车次时刻、车站和部分车型信息 |
| rail.re | 动车组交路、车次和车号查询 |
| RailGo | 动车组交路、车次和车号查询 |
| MoeFactory | 车站大屏、车号和相关铁路数据 |
| 项目内置 JSON | 车站、动车组、客车、机车和线路基础数据 |

这些数据会随官方或第三方服务变化而变化，查询结果仅供参考。涉及实际出行时，请以 12306、车站公告和现场信息为准。

## 使用前请知道

EmuTrain 不是 12306 官方应用，也不是铁路部门官方工具。

项目中包含远程版本检查、公告获取、数据更新和相关远程信息能力。请特别注意：EmuTrain 系列软件配有云控系统，包括远程指令和远程信息推送功能。如果你介意这类能力，请不要安装或使用。

GPS 速度计需要定位权限；网络查询、数据更新和版本检查需要联网。不同数据源的可用性、准确性和响应速度可能不一致。

## 运行项目

这个仓库目前主要保留 Android 端工程配置。你需要先准备好 Flutter 环境。

```bash
flutter pub get
flutter run
```

构建 Android 安装包：

```bash
flutter build apk --release
```

项目使用的 Dart SDK 约束以 `pubspec.yaml` 为准。当前应用版本也请以 `pubspec.yaml` 和 `lib/main.dart` 中的版本号为准。

## 项目结构

```text
lib/
  main.dart                     应用入口、主题、全局设置和数据加载
  journey_model.dart            旅途数据模型
  journey_provider.dart         旅途状态管理
  ui/
    travel_screen.dart          旅途首页
    emu_search_page.dart        动车组查询
    journey.dart                添加旅途
    journey_detail_page.dart    旅途详情
    function/
      station_screen.dart       车站大屏
      more_search.dart          客车和机车查询
      route_hub_page.dart       线路管理
      route_edit_page.dart      线路编辑
      route_map_page.dart       线路走向图
      gps.dart                  GPS 速度计
      gallery_page.dart         动车图鉴
      settings.dart             设置和数据版本管理

assets/
  stations.json                 车站数据
  train.json                    动车组配属数据
  coach.json                    普速客车数据
  loco.json                     机车数据
  icon/                         App、车型、路局和友情链接图标

lines/
  lines.json                    线路索引
  line*.json                    内置线路数据
```

## 适合谁用

EmuTrain 更像是铁路爱好者的随身记录本，而不是一个只为买票服务的工具。它适合想查交路、看车底、记旅途、整理线路和做现场速度记录的人。

如果你只是想快速确认一趟车能不能坐、几点发车，官方渠道会更可靠；如果你想把一次次乘车和追车变成可回看的资料，EmuTrain 会更有意思。

## 版权和联系

如果你认为本项目中的内容侵犯了你的版权、著作权或名誉权，请发送邮件至 `iceiswpan@163.com`，我会及时跟进处理。

开发者相关链接：

- GitHub: <https://github.com/CrYinLang>
- Gitee: <https://gitee.com/CrYinLang>
- QQ 群: <https://qm.qq.com/q/AJ71AadV5K>
