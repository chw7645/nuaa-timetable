# 桌面小组件（Android AppWidget）

小组件为**纯新增功能**：原 1.7.0 APK 中不存在任何 `AppWidgetProvider`（已核实清单），因此不与旧实现冲突。

## 1. 结构

```
Dart                                    Android 原生
──────────────────────────────────      ─────────────────────────────────────
TimetableSnapshot                       TimetableWidgetProvider (AppWidgetProvider)
      │                                        │ onUpdate / onEnabled / 尺寸变化
      ▼                                        ▼
WidgetPayload.build()  ──预计算文案──►   WidgetUpdater.refreshAll()
  · dateText / weekdayText                     │ 读 payload + 渲染
  · periodText / timeText / place              ▼
  · remaining / remainingText            WidgetRenderer → RemoteViews
  · focus(正在上课 / 下一节 / 今日课程)         │
      │                                        ▼
WidgetSyncService  ──MethodChannel──►     widget_today.xml
  "nuaa/timetable_widget"                      │
   sync / clear / refresh                WidgetAlarmScheduler
                                               · 次日 00:00:30 换日
                                               · 今日每节课结束时刻
```

**为什么不用 shared_preferences 传数据**：原 APK 内含 `libdatastore_shared_counter.so`，说明 shared_preferences 走 DataStore（protobuf）后端，原生 `getSharedPreferences()` 读不到。因此改为 **Dart 通过 MethodChannel 下发 JSON，原生原子写入 `filesDir/nuaa_widget/payload.json`**（tmp + rename），互不干扰、可存较大内容。

## 2. 数据协议

`WidgetSyncService.sync()` 下发：

```json
{
  "schemaVersion": 2,
  "generatedAt": "2026-10-29T18:20:00.000+08:00",
  "semester": "2026-2027 学年第1学期",
  "accent": "#2F6FD0",
  "days": [
    {
      "date": "2026-10-29",
      "dateText": "10月29日",
      "weekdayText": "星期四",
      "week": 9,
      "empty": false,
      "remaining": 1,
      "remainingText": "今天剩余1门课",
      "focus": {
        "periodText": "7-8",
        "name": "基础会计学Ⅰ",
        "place": "T1403(天目湖)",
        "timeText": "16:00-17:45",
        "noon": false,
        "startMinutes": 975,
        "endMinutes": 1080,
        "state": "正在上课"
      },
      "sessions": [ ... ]
    }
  ]
}
```

设计原则：**所有文案与时间在 Dart 侧算完**，原生只做"按 `date` 选今天 + 赋值"，
Kotlin 侧不重复实现周次、节次、作息逻辑，避免两端算法漂移。

- `days` 覆盖 **今天起 8 天**；原生按系统日期匹配，匹配不到回退第一条。
- 作息按课程校区取：天目湖 7-8 节为 `16:00-17:45`，将军路/明故宫为 `16:15-18:00`。
- `startMinutes/endMinutes` 让原生零解析；`午间加课` 的 `timeText` 为 `午间`、分钟数为 0（不参与排序，也不排闹钟）。
- `generatedAt` 超过 7 天 → 头部小字改为「数据可能过期，点按更新」。

### 今日文案规则（Dart 侧，可单测）

| 情况 | remainingText |
|---|---|
| 今天无课 | 今天没有课程安排 |
| 剩余 0 门（都已下课） | 今天的课已结束 |
| 其余 | 今天剩余 N 门课 |

`focus` 选取优先级：**正在上课 > 今天下一节 > 今天最后一节 > 空**。

## 3. 刷新策略（三层兜底）

| 层 | 机制 | 作用 |
|---|---|---|
| 粗粒度 | `updatePeriodMillis = 1800000`（系统下限 30 分钟） | 常规兜底，会被系统合并 |
| 精确 | `AlarmManager.setExactAndAllowWhileIdle` | ① 次日 00:00:30 换日；② 今日每节课结束时刻 → "剩余 N 门课"立刻正确；无精确闹钟权限时退化为 `setWindow(10min)` |
| 事件 | `BOOT_COMPLETED`、`MY_PACKAGE_REPLACED`、`TIME_SET`、`TIMEZONE_CHANGED`、`DATE_CHANGED` | 开机/改时间/换时区后重建 |
| 主动 | Dart 侧抓取成功、清除数据、切换作息轨道、App 回到前台且跨天 | 秒级刷新 |

> 未使用自动轮播：RemoteViews 无轻量轮播能力且干扰阅读；`focus` 之外的多节课保留在 `sessions` 中，后续如需轮播可基于 `AdapterViewFlipper` 扩展。

## 4. 布局与设计稿对齐

参考图七要素：**日期 / 今天剩余 N 门课 / 星期 / 节次区间 / 课程名 / 地点 / 时间段**。

```
FrameLayout  @drawable/bg_widget_outer（浅蓝灰渐变，26dp 圆角）
└ LinearLayout(vertical)  @drawable/bg_widget_card（白底 22dp 圆角，margin 5dp）
  ├ Header 56dp  @drawable/bg_widget_header（仅上两角 22dp）
  │   ├ 左：10月29日(15sp bold) / 今天剩余1门课(11sp 次文色)
  │   └ 右：星期四（20sp bold，强调蓝）
  └ Body（paddingStart 16dp / end 14dp）
      ├ 7-8（30sp bold，固定 66dp 列宽）
      ├ 基础会计学Ⅰ（19sp bold，单行省略）
      │   └ [定位图标 14dp] T1403(天目湖)（12.5sp 次文色）
      └ [时钟图标 14dp] 16:00-17:45（12sp 次文色，右对齐）
```

### RemoteViews 限制与规避

| 限制 | 规避方式 |
|---|---|
| 不支持 `ConstraintLayout` | 纯 `LinearLayout` + `layout_weight` |
| 不支持 `clipToOutline` / 圆角裁剪 | 圆角由 shape drawable 提供；**头部单独做"仅上两角"的 shape**，否则会戳出卡片直角 |
| 不支持自定义字体 | 仅用系统字体 + `textStyle="bold"` |
| 不支持 `app:tint` 的稳定行为 | 图标用 vector drawable，`fillColor` 直接引用 `@color/widget_text_secondary` |
| 高度自适应差 | 主体 `layout_height=0dp + weight=1 + gravity=center_vertical` |

尺寸：`minWidth 250dp / minHeight 110dp`，`targetCellWidth 4 / targetCellHeight 2`，`resizeMode="horizontal|vertical"`，`previewLayout` 供选择器预览。

## 5. 深色适配

`values-night/colors.xml` 覆盖 7 个色值（与 App 内 `AppSemanticColors.dark` 对齐）：

| 令牌 | 浅色 | 深色 |
|---|---|---|
| widget_card_bg | `#FFFFFF` | `#1C2027` |
| widget_header_bg | `#F1F2F4` | `#23272E` |
| widget_text_primary | `#1A1C1F` | `#ECEDEF` |
| widget_text_secondary | `#6B7280` | `#9AA0A6` |
| widget_accent | `#2F6FD0` | `#7FB2FF` |

> 强调色会在运行时被 payload 的 `accent` 覆盖（跟随 App 主题色），资源里的值仅作兜底。
| widget_outer 渐变 | `#DCE8F2 → #C7D7E6` | `#12171C → #1B232B` |

RemoteViews 在宿主重新 inflate 时按当前 `uiMode` 取色；若个别启动器不重建，`refreshAll()` 会主动 `updateAppWidget` 强制重绘。

## 6. 交互

- 点击卡片任意位置 → 打开 App（`PendingIntent` + `FLAG_IMMUTABLE`，requestCode 固定避免泄漏）。
- 无数据：显示「打开应用登录后同步」。
- 今日无课：显示「今天没有课程安排」，节次位「—」。

## 7. 扩展指引

- 想改成"下一节课"卡片：只需在 `WidgetPayload._pickFocus` 调整优先级，原生无需改动。
- 想加"周次/学期"角标：在 payload 顶层增加字段，`WidgetRenderer` 读取后 `setTextViewText`。
- 想支持多尺寸布局：新增 `layout-w2h1/` 变体并在 `previewLayout` 之外用 `RemoteViews` 按 `AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH` 选择。
- 想加轮播：新增 `RemoteViewsService` + `AdapterViewFlipper`，数据源直接用 payload 的 `sessions` 数组。
