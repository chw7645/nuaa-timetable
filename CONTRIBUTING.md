# 贡献指南

感谢关注。本项目是一个**非官方**的课程表客户端，主要服务于个人日常使用与 Flutter 工程实践。
提交前请先阅读以下约定，它们大多来自已经踩过的坑。

## 1. 先决条件

- Flutter **3.47.8**（Dart 3.13.7），与 `pubspec.yaml` 的 SDK 约束一致
- JDK 17、Android SDK platform 36 / build-tools 36.0.0
- 不要提交 `.toolchain/`、`build/`、`.dart_tool/`、`dist/`、`artifacts/original/`（已在 `.gitignore`）

## 2. 提交前必须通过

```bash
flutter analyze          # 必须 0 issue
flutter test             # 必须全绿
```

两条都不是"建议"。本项目对以下三类问题有强制约束，违反会直接导致测试失败：

| 约束 | 守护测试 | 说明 |
|---|---|---|
| 颜色只能来自主题 | `test/theme/theme_guard_test.dart` | `lib/` 下除 `theme/` 外禁止 `Colors.black`、`Color(0xFF…)` |
| 课程配色对比度 | `test/theme/contrast_test.dart` | 课程块对底色 ≥1.30:1、对正文 ≥7:1、色相差 ≥25° |
| 周次位图偏移 | `test/parsers/course_table_parser_test.dart` | 有一组「与教务页面逐门对照」用例，改动解析逻辑前请先读懂 |

## 3. 代码约定

1. **颜色**：一律通过 `context.semantic`（`AppSemanticColors`）取色。新增语义色请同时补齐
   `light` / `dark` / `lerp` / `copyWith` 四处，否则深色模式会破功。
2. **弹窗**：统一走 `AppDialog.show` / `AppDialog.confirm`，不要直接调用 `showDialog`。
3. **状态**：全局状态用 `AppController` + `AppScope`（`InheritedNotifier`），不引入额外状态管理库。
   翻页等高频操作使用 `syncWeekSilently` 这类不触发 `notifyListeners` 的通道，避免整屏重建。
4. **几何常量**：课表网格的行高、列宽只能改 `lib/features/home/grid_metrics.dart`，
   布局与几何测试共用这一份真值。
5. **注释**：解释"为什么"，不解释"是什么"。若某段代码是为了绕开某个具体缺陷，
   请把缺陷现象一并写进注释（本仓库多处采用这种风格）。

## 4. 解析层改动

`lib/data/parsers/` 直接对应教务系统的返回结构，任何改动都必须有真实样本支撑：

1. 用 `tool/live_probe.dart` 抓一份真实响应；
2. **脱敏**后放入 `test/fixtures/`（学号、姓名、课表 id 全部替换）；
3. 新增/更新断言，并在 PR 描述中贴出与教务页面比对的结果。

> 学号、密码、Cookie 一律不得进入仓库。`tool/live_probe.dart` 从环境变量读取凭据，
> 不要改成硬编码或命令行参数。

## 5. 提交信息

采用 Conventional Commits 前缀，便于生成 CHANGELOG：

```
feat: 课程块显示学分
fix: 修正 weeks 位图起始偏移导致周次整体延后一周
refactor: 周视图分页器按签名缓存
docs: 补充校区作息对照表
test: 增加窄屏 320dp 布局回归
```

## 6. 发布流程（维护者）

```bash
# 1. 更新版本号（pubspec.yaml 的 version）
# 2. 更新 CHANGELOG.md
# 3. 提交后打 tag 并推送，CI 会自动构建并发布 Release
git tag v1.10.0
git push origin v1.10.0
```

`Release` 工作流会产出两个 APK：

- `nuaa_timetable-arm64.apk`（约 22 MB，绝大多数手机）
- `nuaa_timetable-universal.apk`（约 56 MB，含全部 ABI）

## 7. 不接受的内容

- 任何形式的教务系统数据、凭据、Cookie、抓包原始响应（未脱敏）
- 原始客户端安装包或其反编译产物
- 绕过验证码、绕过风控的实现
- 商业用途的定制需求
