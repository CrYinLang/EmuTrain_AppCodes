# 更新日志

## [未发布] - 2026-06-19

### 模块分离重构

**旅途记录** 和 **行程管理** 现在是完全独立的两个模块，数据不再混合。

### 新增

- 行程管理详情页新增「开始测速」按钮，可在旅途中实时记录速度。
- 过期行程自动移交：行程日期过期后，下次打开 App 会自动将过期行程转为旅途记录，并从行程管理中移除。
- `TrainRecord.fromSearchResult` 工厂方法，支持从搜索结果直接创建记录，不经过行程模块。
- `JourneyProvider.removeExpiredJourneys` 方法，支持批量清理并返回过期行程。

### 变更

- `AddJourneyPage` 新增 `title` 和 `onSave` 参数，支持自定义标题和保存回调，供其他模块复用搜索 UI。
- 旅途记录（RecordScreen）不再依赖 `JourneyProvider`，添加记录时直接保存到 `RecordProvider`。
- 旅途记录详情页移除「开始测速」按钮（记录是过去式，不需要计速）。
- 记录搜索页隐藏「自定义旅途」菜单（自定义旅途属于行程管理模块）。
- TravelScreen 改为 StatefulWidget，支持初始化时自动检测并移交过期行程。

### 数据隔离

| 模块 | Provider | 存储方式 |
|------|----------|----------|
| 行程管理（旅行 Tab） | JourneyProvider | SharedPreferences `journeys_data` |
| 旅途记录（工具箱） | RecordProvider | 文件 `train_record.json` |

两个模块的数据完全独立，不再有 Journey → TrainRecord 的自动复制流程。

### 项目结构变更

```text
lib/
  journey/                      行程管理（未来行程）
    journey.dart                添加旅途（支持自定义保存回调）
    custom_journey_page.dart    自定义旅途
    journey_detail_page.dart    旅途详情（含开始测速）
  record/                       旅途记录（过去行程）
    record_screen.dart          记录首页（独立添加流程）
    record_detail_page.dart     记录详情（测速关联、图片）
  travel/
    travel_screen.dart          行程管理首页（含过期自动移交）
  models/
    record_model.dart           TrainRecord 新增 fromSearchResult
  providers/
    journey_provider.dart       新增 removeExpiredJourneys
```
