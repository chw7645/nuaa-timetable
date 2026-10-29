# 深色模式弹窗文字不可见：成因与修复

## 1. 现象

深色模式下，部分弹窗（最典型的是设置页「主题模式」切换提示弹窗）**文字颜色过深，与深色背景融为一体，几乎不可读**；浅色模式下一切正常。

## 2. 成因

原实现不是"没配 darkTheme"，而是**取色来源分裂**——同一个弹窗的背景与文字来自不同色源。归纳为四类，均可叠加出现：

| 类型 | 具体写法 | 后果 |
|---|---|---|
| **A. 背景写死浅色** | 弹窗内容自绘 `Container(color: Colors.white)` / `Card(color: Color(0xFFF7F7F7))` | 文字若取 `textTheme`（深色下为近白）→ 浅底白字，白茫茫 |
| **B. 文字写死深色** | `TextStyle(color: Colors.black87)` / `Color(0xFF333333)` | 背景随主题变暗 → **深底黑字，即用户所见"看不见"** |
| **C. 只改背景不改前景** | `AlertDialog(backgroundColor: …)` 覆盖了背景，但 `title/content` 仍继承另一套色 | 标题可读、正文不可读（或反之） |
| **D. 局部子树锁死浅色** | `Theme(data: ThemeData.light(), child: …)` 包裹设置项 | 该子树永远按浅色算色，深色下必然错配 |

「切换主题提示弹窗」正是 **A + B** 的组合高发点：由设置项触发、内容为"主题模式 / 浅色·深色说明"、背景取自主题、文字却写死深色 → 深色下整体消失。

> 说明：原 APK 的 Dart 代码无法反编译（release AOT），以上为**基于 AOT 文案与 UI 行为还原出的缺陷模式**，并已在重建工程中按该模式复现与修复。

## 3. 修复点

修复不是逐处补颜色，而是**收敛取色源**，从结构上消除 D 类错配的可能：

### 3.1 单一颜色源

- `lib/theme/app_theme.dart`
  `light()` / `dark()` 由**同一个 `_build()`** 生成，只替换色值；`ColorScheme.fromSeed` 后显式覆盖 `surface / onSurface / surfaceContainer* / primary / outlineVariant`。
  同时配置 `dialogTheme`：`backgroundColor`、`titleTextStyle`、`contentTextStyle` 一次性给定，**弹窗不再需要各自指定颜色**。
- `lib/theme/app_semantic_colors.dart`
  `ThemeExtension<AppSemanticColors>` 承载业务语义色：`cardBackground / cardBorder / dialogBackground / textPrimary / textSecondary / textTertiary / gridLine / periodColumn / todayHighlight / accent / courseBackgrounds / courseForeground / danger`，light/dark 两套同构。
  统一入口：`context.semantic`。

### 3.2 弹窗唯一入口

- `lib/widgets/app_dialog.dart`
  `AppDialog.show()`（提示）与 `AppDialog.confirm()`（二次确认）是全应用**唯一**弹窗入口，内部只使用 `ctx.semantic.*`：

```dart
title:   TextStyle(color: ctx.semantic.textPrimary,   fontWeight: w700)
content: TextStyle(color: ctx.semantic.textSecondary, height: 1.55)
```

  业务代码**禁止直接调用 `showDialog`**。主题提示、清除凭据确认、"统一身份认证失败"、"无法开启提醒"全部走这里。

### 3.3 主题模式真正落到 MaterialApp

- `lib/theme/theme_controller.dart` + `lib/app.dart`
  `theme` + `darkTheme` + `themeMode: controller.theme.mode` 三件套齐备，`ThemeMode` 持久化到 `theme_mode_v1`，切换即时生效。
- 清理任何 `Theme(data: 固定 light)` 包裹（本工程内不存在）。

### 3.4 原生侧同构

- `android/app/src/main/res/values/colors.xml` 与 `values-night/colors.xml`
  小组件的 7 个语义色（外层渐变、卡片底、头部底、主文、次文、强调）在 night 下整体替换；布局**只引用 `@color/*`**，不出现 `#FFFFFF` 字面量。

## 4. 防回归

| 手段 | 文件 | 拦截内容 |
|---|---|---|
| 静态扫描 | `test/theme/theme_guard_test.dart` | `lib/`（除 `lib/theme/**`、`lib/core/config/**`）出现 `Colors.black` / `Colors.white` / `Color(0xFF…)` 即失败，并打印文件与行号 |
| 对比度断言 | 同上 | 8 组前景/背景组合（主文/卡片、次文/弹窗、课程文字/课程块…）在 light 与 dark 下均须 ≥ 3.0:1 |
| 行为回归 | `test/theme/dark_dialog_test.dart` | 在**深色主题**下真实渲染设置页 → 点开「主题模式」→ 断言标题为 `dark.textPrimary`、正文为 `dark.textSecondary`、三个选项均为 `dark.textPrimary`；浅色主题下取对应浅色令牌 |

## 5. 人工验收清单

每个条目在 浅色 / 深色 下各过一遍：

- [ ] 设置页：主题模式弹窗（标题、说明、三个选项、取消按钮）
- [ ] 设置页：提前提醒时间弹窗、作息轨道弹窗
- [ ] 设置页：清除凭据确认弹窗（含红色危险按钮）
- [ ] 登录页：登录失败弹窗
- [ ] 课表页：更新失败弹窗、"课表已更新"提示条
- [ ] 课表页：课程详情底部弹层（课程名、教师、地点、周次）
- [ ] 桌面小组件：浅色 / 深色桌面各放置一次

## 6. 结论

深色模式下的文字可读性不再依赖"每位开发记得改颜色"，而由 **单一颜色源 + 唯一弹窗入口 + 静态扫描 + 对比度断言 + 行为回归** 五道闸门共同保证。新增任何弹窗只要走 `AppDialog`，就不会再出现同类问题。
