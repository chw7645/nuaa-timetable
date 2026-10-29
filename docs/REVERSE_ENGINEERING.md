# 南航课程表（cn.edu.nuaa.nuaa_timetable）逆向分析报告

> 对象：`课程表_1.7.0.apk`（18 MB）
> 方法：ZIP 结构解包 + 二进制 AXML 解析 + dex/AOT 字符串提取 + 线上接口实测复现
> 结论一句话：**Dart 源码不可还原**，本报告交付的是"行为契约"，并据此重建了可编译工程 `nuaa_timetable/`。

---

## 1. 构建指纹

| 项 | 值 | 证据来源 |
|---|---|---|
| 包名 | `cn.edu.nuaa.nuaa_timetable` | AndroidManifest（AXML 字符串池） |
| 版本 | versionName `1.7.0`，versionCode `8` | 同上 |
| SDK | minSdk 24 / targetSdk 36 / compileSdk 36 | 同上 |
| 运行时 | Flutter **release AOT** | `lib/arm64-v8a/libapp.so` 5.3 MB（ELF，AArch64）、`libflutter.so` 11.7 MB |
| ABI | 仅 `arm64-v8a` | ZIP 条目 |
| 引擎特征 | Dart 3.13.x（`3.13.3 (stable)` 字符串）、Impeller、Material 3 | `libflutter.so` 字符串 |
| 混淆 | **未混淆**（业务常量明文可读） | AOT 字符串 |
| 无源码残留 | 无 `kernel_blob.bin`、无 `.dill`、无 Dart 源 | ZIP 条目清单（390 项） |

### 关键判断：为什么不能"直接改"
Flutter release 构建会把 Dart 编译成 AOT 机器码写入 `libapp.so`，**不保留可反编译的中间表示**。现有工具（Blutter 等）只能恢复类/函数符号与部分对象池字符串，无法产出可编译 Dart 代码。因此本项目的正确路径是：

```
APK → 行为契约（本报告） → 重建可编译工程 → 在其上修 bug / 加功能
```

---

## 2. 工程结构还原

ZIP 顶层分布（390 项）：

```
res/                 302  (drawable/layout/mipmap/xml 等原生资源)
META-INF/             60
assets/               11  flutter_assets（AssetManifest.bin、FontManifest.json、NOTICES.Z、
                          MaterialIcons、shaders/ink_sparkle.frag 等）
kotlin/                8  Kotlin stdlib builtins
lib/                   3  libapp.so / libflutter.so / libdatastore_shared_counter.so
classes.dex + classes2.dex   1.02 MB + 0.19 MB（Flutter Java 嵌入层 + 插件）
AndroidManifest.xml / resources.arsc
```

**推断的 Dart 侧分层**（由字符串与调用链反推）：

| 层 | 职责 | 证据 |
|---|---|---|
| 认证 | CAS 统一身份认证 → ticket → EAMS 会话 | `userNameLogin`、`generalLogin`、`pwdEncryptSalt`、`/authserver/login?service=` |
| 网络 | `dart:io HttpClient` + 手工 Cookie + 正则解析 | 无 `dio`/`html` 包符号；`set-cookie`、`User-Agent` 伪装 |
| 解析 | TaskActivity 脚本解析、周位图、校区判定 | `campusSchedules`、`week-union`、`defaultCampus` |
| 领域 | 学期/周次/节次/课程会话 | `semester.id`、`weekCount`、`week1Monday`、`dayOfWeek`、`startWeek` |
| 展示 | 周视图、今日面板、课程详情、设置 | 文案：`上课安排`、`下一节：`、`正在上课：`、`今天没有课程安排，好好休息` |
| 通知 | 上课提醒 | `nuaa_class_notice`、`nuaa_class_alarm`、`scheduledDateTimeISO8601`、`zonedSchedule` |
| 持久化 | 课表缓存 + 凭据 | `timetable_cache_v1` |

### 插件依赖（dex 类描述符确证）

| 插件 | 证据 |
|---|---|
| `shared_preferences` | `io/flutter/plugins/sharedpreferences/SharedPreferencesPlugin`、Pigeon `SharedPreferencesApi.*` |
| `flutter_local_notifications` | `com/dexterous/flutterlocalnotifications/*`（含 `ScheduledNotificationReceiver`、`ScheduledNotificationBootReceiver`） |
| `package_info_plus` | `dev.fluttercommunity.plus/package_info` |

**未使用**：dio、provider/riverpod、sqflite、html、workmanager、home_widget。
**重要副作用**：`libdatastore_shared_counter.so` 存在 → shared_preferences 走 **DataStore（protobuf）后端**，原生 `getSharedPreferences()` **读不到** Flutter 写入的偏好。这是本次小组件改用独立文件桥接的直接原因。

### 权限清单（原样保留）
`INTERNET`、`ACCESS_NETWORK_STATE`、`POST_NOTIFICATIONS`、`RECEIVE_BOOT_COMPLETED`、`SCHEDULE_EXACT_ALARM`、`USE_EXACT_ALARM`、`USE_FULL_SCREEN_INTENT`、`VIBRATE`、`WAKE_LOCK`。
`networkSecurityConfig`：仅 `nuaa.edu.cn`（含子域）放开明文 HTTP。

---

## 3. 接口契约（已线上实测复现）

### 3.1 统一身份认证（CAS，金智）

```
GET  https://authserver.nuaa.edu.cn/authserver/login?service=http://aao-eas.nuaa.edu.cn/eams/localLogin.action
     → 200，约 22 KB，Set-Cookie: JSESSIONID
     页面含：
       <input id="pwdEncryptSalt" value="16位随机串">
       <input name="execution" value="e1s1">
       <input name="lt" value="">            ← 可能为空，可为空提交
       <input name="_eventId" value="submit">
       <form id="loginFromId" action="/authserver/login">
```

**密码加密**（`nuaaTheme1020/static/common/encrypt.js` 原文）：

```js
function getAesString(n, f, c) {        // n=明文, f=key, c=iv
  f = CryptoJS.enc.Utf8.parse(f); c = CryptoJS.enc.Utf8.parse(c);
  return CryptoJS.AES.encrypt(n, f, {iv: c, mode: CBC, padding: Pkcs7}).toString();
}
function encryptAES(n, f) { return f ? getAesString(randomString(64) + n, f, randomString(16)) : n; }
```

即：**AES-128-CBC，key = UTF8(pwdEncryptSalt)，IV = 16 位随机串，明文 = 64 位随机前缀 + 密码，PKCS7，Base64 输出**。
64 位随机前缀只为填充首块，服务端解密后按固定长度截断，因此 **IV 随机不影响服务端还原**。

```
POST 同上 URL，body：
  username=<学号>&password=<密文>&lt=&execution=e1s1&_eventId=submit
  &dllt=generalLogin&cllt=userNameLogin&rmShown=1
     → 302 → /eams/localLogin.action?ticket=ST-... → 302 → /eams/homeExt.action（实测落地页）
```

失败分支：`密码错误` / `用户名或密码` → "统一身份认证失败：请检查学号与密码"；`checkNeedCaptcha.htl` 判定需要验证码（未实现自动绕过，直接提示）。

> **客户端实现约束（实测踩坑）**：CAS 在 `https://authserver.nuaa.edu.cn`，EAMS 在 `http://aao-eas.nuaa.edu.cn`，
> 登录跳转是 **https → http 的降级跳转**。Dart `HttpClient` 默认不跟随降级跳转，会把 302 直接返回，
> 表现为"登录成功但被判未放行"。因此必须 `followRedirects = false` 并手工跟随；
> 且关闭自动跟随后 `HttpClientResponse.isRedirect` 恒为 `false`，需按状态码判断。
> 完整链路为：`POST /authserver/login` → `302 localLogin.action?ticket=ST-…` →
> `302 localLogin.action;jsessionid=…` → `302 /eams/homeExt.action` → `200`。

### 3.2 课表入口页

```
GET http://aao-eas.nuaa.edu.cn/eams/courseTableForStd.action
```
从中提取（**实测值**）：

| 参数 | 提取方式 | 实测 |
|---|---|---|
| `semester.id` | `\.semesterCalendar\(\{[^}]*value:"(\d+)"` | `402` |
| `ids` | `addInput\(form,"ids","(\d+)"\)` | 学生课表对象 id（本例 `137754`，已脱敏） |
| `weekCount` | `<option value="N">第N周</option>` 取最大 | `20` |

> 注意：表单字段名是 **`semester.id`**，不是 `semesterId`；用错会返回 500（FreeMarker `prompt.ftl` 缺失）。

### 3.3 课表数据

```
GET http://aao-eas.nuaa.edu.cn/eams/courseTableForStd!courseTable.action
    ?ignoreHead=1&setting.kind=std&startWeek=&semester.id=402&ids=<id>
    → 200，约 72 KB，TaskActivity 脚本
```

`startWeek=9` 只返回第 9 周的 17 条活动（全量 26 条）→ **逐周降级抓取可行**。

### 3.4 学期列表（仅用于展示学期名）

```
GET http://aao-eas.nuaa.edu.cn/eams/dataQuery.action?dataType=semesterCalendar
    → {yearDom:..., termDom:..., semesters:{y0:[{id:11,schoolYear:"2013-2014",name:"1"},...]}}
```
不含开学日期，因此**无法从接口获取第 1 周日期**（见 §5）。

---

## 4. 课表解析（核心）

真实响应结构：

```js
var table0 = new CourseTable(2026, 91);
var unitCount = 13;

activity = new TaskActivity(
    actTeacherId.join(','),      // 0 教师 id 列表
    actTeacherName.join(','),    // 1 教师姓名
    "2064",                      // 2 课程代码
    "线性代数",                   // 3 课程名称
    "",                          // 4
    "2323",                      // 5 教学任务 id
    "T2111(天目湖)",              // 6 上课地点
    "00000001111111111111000...",// 7 周次位图（53 字符）
    "448767",                    // 8 活动 id
    null,                        // 9
    assistantName,               // 10 助教
    "", "",                      // 11,12
    "0925001 0925801 ...");      // 13 合班班级

index = 1*unitCount + 2;         // 星期 = index / unitCount（0 基，周一 = 0）
table0.activities[index][...] = activity;
index = 1*unitCount + 3;         // 连堂课：多条 index
```

### 4.1 网格行序（关键发现）

`unitCount = 13` 不是 13 节课，而是 **4 + 2 + 7**：

```
第一节 第二节 第三节 第四节  午一节 午二节  第五节 第六节 第七节 第八节 第九节 第十节 第十一节
 row0  row1  row2  row3     row4   row5    row6  row7  row8  row9  row10 row11 row12
```

页面内 `<td>第一节</td>…` 顺序与该列表完全一致（正则提取验证）。
**因此 `p=8,9` → 第七、八节**，与桌面小组件设计稿「基础会计学Ⅰ · 7-8」精确吻合；若误按"第 8、9 节"解释就会整体偏移一节。

### 4.1.1 作息必须按校区区分（对原实现的修正）

教务处《校历 / 上课时间》（2026-2027）：

| 节次 | 将军路 / 明故宫 | 天目湖 |
|---|---|---|
| 1 | 08:00-08:50 | 08:30-09:20 |
| 2 | 08:55-09:45 | 09:25-10:15 |
| 3 | 10:15-11:05 | 10:30-11:20 |
| 4 | 11:10-12:00 | 11:25-12:15 |
| 5 | 14:00-14:50 | 14:00-14:50 |
| 6 | 14:55-15:45 | 14:55-15:45 |
| 7 | 16:15-17:05 | **16:00-16:50** |
| 8 | 17:10-18:00 | **16:55-17:45** |
| 9 | 18:45-19:35 | 18:45-19:35 |
| 10 | 19:40-20:30 | 19:40-20:30 |
| 11 | 20:35-21:25 | 20:35-21:25 |

原 APK 只内置了一套（主校区）时刻，因此**天目湖的课程时间整体偏晚 15 分钟**；
参考截图里的「16:15-18:00」正是该缺陷的体现，本工程已改为按课程校区取表。

### 4.2 周次位图（含一处已修正的偏移陷阱）

- **53 字符定长**，覆满一个自然年。**第 0 个字符是「第 0 周」占位，真正的第 1 周在第 1 个字符**，
  即「索引 i = 第 i 周」；
- 落库为 64 位整型位图（`1 << (w-1)`），展示时反推为 `4-18周` 文本；

> ⚠️ **曾经的缺陷**：早期实现按「第 0 个字符 = 第 1 周」解释，导致**所有课程整体延后一周**。
> 用教务页面「我的课表」逐条比对 24 条课程确认：线性代数（周二 1-2）教务 `7-16 周`，
> 位图 `1` 落在索引 7..16；应用统计学（周一 1-2）教务 `1-10 周`，位图索引 1..10；
> 基础会计学Ⅰ（周四 7-8）教务 `3-6,8-17 周`，位图索引 3..6、8..17 —— 全部以「索引 i = 第 i 周」吻合。
> 现在的判定逻辑：位图长度明显大于学期周数即视为定长格式并跳过第 0 位；
> 若某校下发的是长度恰等于周数的紧凑位图，仍按「第 0 位 = 第 1 周」处理。
> 回归用例见 `test/parsers/course_table_parser_test.dart` 的「与教务页面逐门对照」分组。
- 同一 `(课程, 教师, 星期, 起止行, 地点)` 多次下发时按 **按位或** 合并 —— 即 AOT 中 `week-union` 的语义；
- 位图全 0 时标记 `weeksUnknown`，按"每周都上"渲染，避免看起来漏课。

### 4.3 校区判定

地点形如 `T1403(天目湖)`、`C210(天目湖)`、`实地讲习（天目湖）(天目湖)`：
优先取括号内文字精确匹配"天目湖/将军路/明故宫"，其次按楼栋前缀（T→天目湖，J/D→将军路，M/A/B→明故宫），最后回落接口默认校区。

---

## 5. 周次与校历（推断 + 反证）

接口不下发开学日期，原 APK 的 `week1Monday` 只能来自内置校历表。本次通过**数据反证**确定：

| 候选第 1 周 | 2026-10-29 所属周 | 该周是否有"基础会计学Ⅰ(周四 7-8, T1403，3-6,8-17 周)" |
|---|---|---|
| 2026-08-31 | 第 9 周 | **有**（9 落在 8-17 内） |
| 2026-09-07 | 第 8 周 | 有（8 也落在 8-17 内） |

单独用"这天有没有课"已不足以区分两个候选，因此还用了两条独立证据：

1. 教务登录后落地页 `homeExt.action` 自带文案 **「2026-2027第1学期 第9教学周」**，
   而当天是 2026-10-29 → 该周为第 9 周 → 倒推第 1 周周一 = **2026-08-31**；
2. 周次位图修正偏移后，第 9 周的全部课程与页面显示逐条一致（见 4.2 的对照表）。

故 **第 1 周周一 = 2026-08-31**，写入 `SemesterCalendar` 常量表（未收录学期按"含 9 月 1 日的那一周周一"推断，UI 上标注"由规则推断"）。

---

## 6. 主题与深色模式实现（还原结果）

AOT 中的文案证明原实现具备完整三态能力：

- `主题模式`、`浅色`、`深色`、
- 「浅色 / 深色可手动指定，也可跟随系统的深浅色设置自动切换」

但**取色方式不统一**：`MaterialApp` 有 `theme/darkTheme/themeMode`，同时存在大量局部 `Container(color:)` 与 `TextStyle(color:)` 直写。这正是"切换主题提示弹窗在深色下文字看不见"的结构性根因，详见 `docs/DARK_MODE_FIX.md`。

---

## 7. 不可还原的边界（务必知悉）

| 项 | 状态 |
|---|---|
| Dart 源码 / 类名 / 方法体 | **不可还原**（AOT 机器码） |
| 布局像素与动画曲线 | 不可精确还原，按文案 + 交互语义 + 参考截图重建 |
| 原签名私钥 | 不可获得 → 新包必须卸载旧版安装 |
| 内置校历表全量 | 仅反证出 402 学期；其余按规则推断 |
| 原 `weekText` 的生成规则 | 已按位图重新实现，文本形态可能与原版略有差异 |

---

## 8. 重建工程的对应关系

| 契约 | 实现文件 |
|---|---|
| CAS 登录页解析 | `lib/data/parsers/cas_login_parser.dart` |
| 密码加密 | `lib/core/crypto/pwd_encryptor.dart` |
| Cookie / 302 跟随 | `lib/core/network/http_session.dart`、`cookie_store.dart` |
| 入口参数 | `lib/data/parsers/course_table_entry_parser.dart` |
| 课表解析 + week-union | `lib/data/parsers/course_table_parser.dart` |
| 抓取与降级 | `lib/data/repositories/eams_repository.dart` |
| 节次时刻（13 行） | `lib/core/time/period_table.dart` |
| 周次换算 | `lib/core/time/week_calendar.dart`、`lib/data/semester_calendar.dart` |
| 校区判定 | `lib/data/campus_resolver.dart` |
| 主题与深色修复 | `lib/theme/*`、`lib/widgets/app_dialog.dart` |
| 桌面小组件 | `lib/widget_bridge/*` + `android/.../widget/*` |

**验证方式**：`test/fixtures/` 下为脱敏后的真实响应样本，`flutter test` 覆盖登录页解析、入口参数、课表解析、节次映射、周次、校区、小组件 payload 与主题对比度。
