# 南航课程表 App：逆向分析 + 深色弹窗修复 + 桌面小组件

## 0. 核心结论（先说判断）

1. **Dart 源码不可还原。** APK 为 Flutter **release AOT** 构建，只有 `libapp.so`(5.3MB) + `libflutter.so`(11.7MB)，**无 kernel_blob.bin、无 Dart 源码**，本机也无 jadx/apktool/JDK。AOT 是 ARM64 机器码，现有工具链（Blutter 等）只能恢复符号与部分结构，**无法产出可编译 Dart 代码**。
2. 因此"修 bug + 加小组件"**不可能以 patch 方式完成**，必须**重建可编译工程**。逆向的产出是**行为契约**（接口、字段、文案、时序、资源规格），而非源码。
3. 好消息：**快照未被混淆**，业务契约几乎完整可读（URL、正则、字段名、中文文案、缓存键全部命中）。重建的准确度可以做到"接口级 1:1、UI 级高度近似"，但**不是逐像素还原**。
4. **小组件是纯新增**：原 APK 无任何 `AppWidgetProvider`（清单已核实），不存在冲突。

---

## 1. 逆向分析结果（作为交付文档 `docs/REVERSE_ENGINEERING.md` 的骨架）

### 1.1 工程体检
| 项 | 值 | 依据 |
|---|---|---|
| 包名 / 版本 | `cn.edu.nuaa.nuaa_timetable` / 1.7.0 (versionCode 8) | 二进制 AXML |
| SDK | minSdk 24 / target 36 / compile 36 | 同上 |
| ABI | 仅 arm64-v8a | zip |
| 权限 | INTERNET、ACCESS_NETWORK_STATE、POST_NOTIFICATIONS、SCHEDULE_EXACT_ALARM、USE_EXACT_ALARM、USE_FULL_SCREEN_INTENT、RECEIVE_BOOT_COMPLETED、VIBRATE、WAKE_LOCK | 清单 |
| 网络安全 | 已有 `networkSecurityConfig`：仅 `nuaa.edu.cn` 及其子域放开明文 | res |
| 依赖 | `shared_preferences`(Pigeon)、`flutter_local_notifications`、`package_info_plus` | dex 类描述符 + AOT 符号 |
| 关键推断 | 含 `libdatastore_shared_counter.so` → **shared_preferences 走 DataStore 后端**，原生读不到 XML | zip |

### 1.2 模块划分（由契约反推）
- **认证层**：CAS 统一身份认证（学号/密码 → ticket → EAMS 会话 Cookie）
- **抓取层**：`dart:io HttpClient` + 正则/JS 片段解析（**无 dio、无 html 解析包**）
- **领域层**：学期、周次、节次、校区、课程会话
- **展示层**：周视图网格、今日面板、课程详情、设置
- **通知层**：上课提醒（zonedSchedule）
- **持久层**：`timetable_cache_v1` 快照缓存 + 凭据

### 1.3 接口契约（全部为 APK 内明文命中）
```
登录页   GET  https://authserver.nuaa.edu.cn/authserver/login?service=<eams>
         正则① id="pwdEncryptSalt"\s+value="([^"]*)"     正则② name="pwdEncryptSalt"[^>]*value="([^"]*)"（降级）
         失败文案：无法解析登录页参数（pwdEncryptSalt），教务系统…
提交     POST 同上，字段 userNameLogin / generalLogin；页面 token：execution / lt / _eventId
学期     GET  http://aao-eas.nuaa.edu.cn/eams/dataQuery.action
         正则：\.semesterCalendar\(\{[^}]*value:"(\d+)"
课表入口 GET  /eams/courseTableForStd.action          （提供默认学期、week1Monday、unitCount）
课表数据 GET  /eams/courseTableForStd!courseTable.action?ignoreHead=1&setting.kind=std&semesterId=…&startWeek=…
本地登录     /eams/localLogin.action                   （ticket 兑换落点候选）
UA 伪装      Mozilla/5.0 … Chrome/120.0.0.0
```
数据字段：`semester.id`、`weekCount`、`week1Monday`、`startDate`、`defaultCampus`、`campusSchedules[].sessions[]`、`unscheduledCourses`、`courseName/courseCode/courseCategory`、`dayOfWeek`、`startWeek`、`weekText`、`week-union`（周并集兜底路径）。
缓存/通道键：`timetable_cache_v1`、`nuaa_class_notice`、`nuaa_class_alarm`、`nuaa_class_*` 调度元数据 `scheduledDateTimeISO8601`。

### 1.4 抓取与解析逻辑（还原结论）
1. 完整抓取优先：一次取全 → 解析出 `campusSchedules` + `sessions`。
2. 判定失败即降级**逐周抓取**（逐周 `startWeek=w`，串行 + 退避），再对同一 `(课程, 星期, 节次, 地点)` 取**按位或**得到最终周位图 —— 这就是 `week-union` 的实现位置。
3. 两套解析器并存：**JSON 分支**（`campusSchedules`）与**经典 EAMS 网格分支**（`var unitCount=N` + `index=d*unitCount+p` 推导 `dayOfWeek/startPeriod`）。
4. 校区由地点前缀自动判定（"当前按地点自动判定"），并保留手动切换。

### 1.5 主题/深色模式实现方式（还原结论）
- `MaterialApp` 具备 `theme / darkTheme / themeMode` 三件套，设置页三态（浅色 / 深色 / 跟随系统），持久化偏好。
- 业务语义色与组件色混用：大量局部 `Container(color: …)`、`TextStyle(color: …)` 直接赋值，未统一到 `ThemeExtension`。
- 这就是深色 bug 的结构性温床（详见 §2）。

---

## 2. 深色模式弹窗文字不可见的成因与修复

### 2.1 成因（四类叠加，均可在重建代码中复现并定点修复）
| # | 成因 | 表现 |
|---|---|---|
| A | 弹窗内容自绘 `Container/Card` 用**固定浅色底**，而文字取 `Theme.of(context).textTheme`（深色下为近白） | 浅底白字，白茫茫一片 |
| B | 文字**硬编码深色**（`Colors.black87` / `0xFF333333`），底色随主题变暗 | 深底黑字，即你描述的"看不见" |
| C | `AlertDialog(backgroundColor:)` 只覆盖了背景，**未覆盖 `title/content` 的继承色**，二者来自不同色源 | 标题与正文对比不一致，部分不可读 |
| D | `ThemeMode` 只做了持久化，局部子树用 `Theme(data: 固定 light)` 包裹 | 该子树永远按浅色算色，深色下错配 |

**"切换主题时提示主题的弹窗"**正是 A+B 的组合高发点：弹窗由设置项触发，内容为 "主题模式：深色/浅色" + 说明文案，背景取自主题、文字写死深色 → 深色模式下直接消失。

### 2.2 修复点（系统性，非局部打补丁）
1. `lib/theme/app_theme.dart`：唯一色源，`ColorScheme.fromSeed` + 显式覆盖 `surface/surfaceContainer*/onSurface/onSurfaceVariant`，**light/dark 两套同构**。
2. `lib/theme/app_semantic_colors.dart`：`ThemeExtension` 承载业务色（卡片底、次级文字、节次列底、今日高亮、8 色课程盘），`context.semantic` 唯一访问入口。
3. `lib/widgets/app_dialog.dart`：**全应用弹窗唯一入口** `showAppDialog / showConfirmDialog`，只使用主题令牌，业务代码**禁止直接调用 `showDialog`**。主题提示、清除凭据确认、"统一身份认证失败"、"课表已更新"全部改走此处。
4. `MaterialApp` 三件套落地 + `ThemeMode` 持久化（key `theme_mode_v1`）；清理任何 `Theme(data: light)` 硬包裹。
5. 原生侧：`values-night/colors.xml` 覆盖小组件 6 个语义色，布局只引用 `@color/*`。
6. **防回归**：`test/theme/no_hardcoded_colors_test.dart` 静态扫描 `lib/` 禁止 `Colors.black|Colors.white|Color(0x` 字面量（`lib/theme/**`、`lib/core/config/**` 白名单）；`contrast_test` 对 8 组前/背景算 WCAG 对比度断言 ≥ 4.5。

---

## 3. 桌面小组件（Android AppWidget）方案

参考图七要素：日期 / 今天剩余 N 门课 / 星期 / 节次区间 / 课程名 / 地点 / 时间段。

### 3.1 布局（RemoteViews 可行域内逼近设计稿）
```
FrameLayout  bg_widget_outer（浅蓝灰渐变）
└ LinearLayout(vertical) bg_widget_card（白底 22dp 圆角）
  ├ Header 54dp bg_widget_header（仅上两角圆角）
  │   ├ 左：10月29日(15sp bold) + 今天剩余1门课(11sp 次级色)
  │   └ 右：星期四（20sp bold，强调蓝）
  └ Body（左右 padding 16dp，垂直居中）
      ├ 节次 7-8（30sp bold，固定 66dp 列宽）
      ├ 课程名(19sp bold, maxLines=1 ellipsize) + [定位图标] T1403(天目湖)
      └ [时钟图标] 16:15-18:00（右对齐，次级色）
```
约束与规避：RemoteViews 不支持 ConstraintLayout/自定义字体/`clipToOutline` → **纯 LinearLayout + weight**，圆角全部用 shape drawable，头部单独做"仅上两角"shape，图标用 vector drawable（`fillColor=@color/*`，不用 `app:tint`）。尺寸 `minWidth 250dp / minHeight 110dp`，`updatePeriodMillis=1800000`。

### 3.2 数据桥（关键决策）
**不能走 shared_preferences**（已确认其为 DataStore/protobuf 后端，原生 `getSharedPreferences` 读不到）。
```
MethodChannel "nuaa/timetable_widget"（单向 Dart→原生）
  sync(json) → 原子写 filesDir/nuaa_widget/payload.json（tmp+rename）→ 刷新 widget + 重排闹钟
  clear()    → 删文件 → widget 显示"打开应用登录后同步"
```
payload 由 Dart **预计算全部展示文案**（`dateText/weekdayText/periodText/name/place/timeText/startMinutes/endMinutes/noon` + 未来 7 天），原生只做"选哪节课 + 赋值"，Kotlin 侧零业务解析。

### 3.3 选取与刷新
- 选取：正在上课 > 今天下一节 > 今天最后一节 > 空态（"今天没有课程安排"）；头部小字恒为"今天剩余 N 门课"（N=尚未结束的课程数，0 且非空 → "今天的课已结束"）。**不做自动轮播**（保留 candidates 便于后续扩展）。
- 刷新三层：① `updatePeriodMillis` 30 分钟；② `AlarmManager.setExactAndAllowWhileIdle` 排**午夜换日**与**每节课结束时刻**（原 APK 已有精确闹钟权限）；③ 事件驱动：BOOT_COMPLETED / MY_PACKAGE_REPLACED / TIME_SET / TIMEZONE_CHANGED / DATE_CHANGED + Dart 侧抓取成功、清缓存、换主题即时 sync。
- 点击卡片 → 打开 App 并定位到本周今天。深色随 `values-night` 自动生效。

---

## 4. 实施步骤（P0→P7）

工程根：**`C:\WorkSpace\WorkBuddyWorkSpace\nuaa_timetable`**（ASCII 路径，避开 Gradle 中文路径问题）。原 APK 与参考图保留原位不动。

| 阶段 | 内容 | 验收 |
|---|---|---|
| **P0** 环境与骨架 | 装 Temurin JDK17 + cmdline-tools + platform/build-tools 36 + Flutter stable；`flutter create`（包名/版本 1.7.0+8/SDK 对齐）；权限 + `network_security_config` 照抄原策略；主题骨架 + `showAppDialog`；开启 core library desugaring（`desugar_jdk_libs 2.1.4`，通知插件 v18+ 硬要求） | `flutter build apk --debug` 成功；启动见登录页；深色下骨架页文字可读 |
| **P1** 认证 | CAS 页解析（salt 双正则 + execution/lt/_eventId 回填）、`PwdEncryptor` 四策略可切换、`HttpSession`+`CookieStore`（关自动跳转、手工跟随 302 收集 Set-Cookie）、错误文案对齐 | 用联调账号登录成功进课表页；错误密码提示"统一身份认证失败：请检查学号与密码" |
| **P2** 抓取解析 | 学期枚举、路径 A→B 降级、双解析器、`week-union`、`CampusResolver`、`test/fixtures` 离线样本单测 | 单测全绿；真机抓到完整课表且周数自洽；异常响应不崩 |
| **P3** 模型与周视图 | 模型/周位图/节次表/缓存；周视图网格、课程块并排、详情"上课安排"、今日面板、下拉"更新课表" | 与教务网页逐格一致；切周正常；重启秒开（缓存命中） |
| **P4** 提醒 | 渠道 `nuaa_class_notice`/`nuaa_class_alarm`、权限申请、`zonedSchedule` 批量重建、提前 N 分钟、午间加课不排 | 改系统时间可触发；改设置后旧提醒全清；重启后仍在 |
| **P5** 深色收口 | 硬编码色全量替换为语义令牌；6 页 × 3 弹窗 × 2 主题人工验收；lint + 对比度单测 | §2 的 A–D 四类问题全部消失；回归测试通过 |
| **P6** 小组件 | 布局/形状/矢量图标/`values-night`、MethodChannel 桥、payload 预计算、三层刷新、点击跳转、选择器预览 | 七要素齐全、与设计稿一致；午夜自动换日；抓课后 1s 内更新 |
| **P7** 打包回归 | 签名 keystore、release 构建、卸载重装全流程 | `app-release.apk` 可用；验证清单 100% |

关键常量：节次时刻表以 **7-8 节 = 16:15–18:00** 为锚点（与参考图一致），午一节/午二节时刻为 `null`、显示"—"、不参与提醒（官方作息未定义，不臆造）。

---

## 5. 交付物
1. `docs/REVERSE_ENGINEERING.md` — 完整逆向说明（结构/模块/依赖/接口/时序/主题实现/证据清单/AOT 不可还原的边界声明）
2. `C:\WorkSpace\WorkBuddyWorkSpace\nuaa_timetable\` — 可编译 Flutter 工程（新维护基线）
3. `docs/DARK_MODE_FIX.md` — 成因、修复点、防回归
4. `docs/WIDGET.md` — 小组件数据协议、刷新策略、扩展指引
5. `build\app\outputs\flutter-apk\app-release.apk` — 可安装产物

## 6. 已知风险与前置提示
- **R1 签名冲突**：重建包签名不同，`adb install` 覆盖会 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`，**必须先卸载原 App，本机凭据与课表缓存会丢失**。
- **R2 密码加密算法**：`pwdEncryptSalt` 的 AES 模式有 3 种可能，默认 `AES-CBC(key=iv=salt, PKCS7, Base64)`；若联调不通，用浏览器 DevTools 抓一次真实 POST 密文做向量单测即可定死（P1 首要排障项）。
- **R3 作息表为推断**：以 AOT 时刻字面量反推，需联调对照官方作息表校正一次。
- **R4 UI 非逐像素**：原 Flutter 布局代码不可见，按 AOT 文案 + 参考截图重建，交互与信息结构对齐、细节像素可能微差。
- **R5 凭据处理**：账号仅在联调时从本机私有环境变量读取，**不写入计划、文档、仓库或日志**；建议联调后修改密码。
