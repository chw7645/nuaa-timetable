# 项目资产索引

本目录（`C:\WorkSpace\WorkBuddyWorkSpace\nuaa_timetable`）是本会话全部产物的唯一存放位置。
下面按"工程 / 文档 / 制品 / 证据 / 工具链"说明每个位置放什么、能不能删。

## 1. 工程源码（维护基线）

| 路径 | 说明 |
|---|---|
| `lib/` | Flutter 业务代码（认证、抓取、解析、周视图、设置、提醒、小组件桥） |
| `android/` | 原生层：权限、网络安全策略、AppWidget（Kotlin + 资源） |
| `test/` | 50 项测试；`test/fixtures/` 为**脱敏后**的真实教务响应样本 |
| `tool/live_probe.dart` | 联调诊断脚本（凭据从环境变量读取，不落盘） |

## 2. 文档

| 文件 | 内容 |
|---|---|
| `README.md` | 环境、构建、安装、目录说明、已知限制 |
| `docs/REVERSE_ENGINEERING.md` | 逆向分析：构建指纹、接口契约、解析规则、校区作息、不可还原边界 |
| `docs/DARK_MODE_FIX.md` | 深色弹窗文字不可见的成因、修复与防回归 |
| `docs/WIDGET.md` | 桌面小组件数据协议、刷新策略、布局约束 |
| `docs/IMPLEMENTATION_PLAN.md` | 本会话确认过的实施方案（含风险登记） |

## 3. 制品（可直接安装）

| 文件 | 用途 |
|---|---|
| `dist/南航课程表-1.10.0-arm64.apk` | **推荐**：唯一在库版本（周次偏移已修正 / 手势分离 / 高对比配色 / 学分），arm64 |
| `dist/南航课程表-1.10.0-通用.apk` | 同版本通用包，含全部 ABI（兼容性最好，56 MB） |

> 安装提示：与学校原版签名不同，需先卸载旧应用；卸载会清除本机保存的学号、密码与课表缓存。

## 4. 证据与素材

| 路径 | 内容 |
|---|---|
| `artifacts/original/课程表_1.7.0.apk` | **用户提供的原始应用**（18 MB，Flutter release AOT）。属逆向取证输入，不是本工程的构建产物，故保留 |
| `artifacts/reference/widget-design.jpg` | 桌面小组件的设计参考图 |
| `artifacts/reference/original-ui/*.jpg` | 原版三屏界面截图（今日 / 周课表 / 设置），本工程 UI 的对齐依据 |
| `artifacts/visual/*.png` | 本工程渲染快照（真实教务数据 + 系统中文字体），用于比对排版；重新生成见下方命令 |
| `artifacts/issues/today-column-tint.jpg` | 用户反馈"今日列染色"缺陷的截图 |
| `artifacts/analysis/cas-encrypt.js` | 统一身份认证前端加密实现（AES-128-CBC 定案的直接依据） |
| `artifacts/analysis/cas-login.js` | CAS 登录页交互脚本 |
| `artifacts/analysis/probes/*.py` | 初期的 Python 探针（登录、课表、TaskActivity 解析原型） |

> **历史构建版本已全部删除**（1.7.1 / 1.8.0 / 1.8.1 / 1.9.0 / 1.9.1 / 1.9.2 / 1.9.3，含 `dist/archive/`），
> 按要求不留备份。`dist/` 现在只保留当前版本的两个包。

> 所有教务原始响应中的学号/姓名/课表 id 均已脱敏后才进入 `test/fixtures/`；
> 含会话 Cookie 的临时文件已删除，未归档。

## 5. 工具链（可重建，不必备份）

`/.toolchain`（6.2 GB，隐藏目录）：

```
.toolchain/
├─ env.sh                 # 唯一入口：source 后即可 flutter/gradle
├─ jdk/                   # Temurin 17
├─ flutter/               # Flutter 3.47.8 / Dart 3.13.7
└─ android-sdk/           # platform-36、build-tools-36.0.0、platform-tools
```

构建命令：

```bash
cd C:/WorkSpace/WorkBuddyWorkSpace/nuaa_timetable
source .toolchain/env.sh
flutter pub get
flutter test
flutter build apk --release --split-per-abi
```

需要腾出空间时可直接删除整个 `.toolchain` 后重新安装（不承载任何业务数据）。
`build/`、`.dart_tool/`、`android/.gradle/` 均为可再生产物。

## 6. 本会话已做的清理

- 工作区根目录不再散落任何本会话文件（APK、截图、临时脚本）。
- `.tmp/` 已删除：其中包含带**真实会话 Cookie** 的 `cookies.json`、`cas_cookies.txt`，
  以及含学号/id 的原始响应；有价值的探针脚本已转存至 `artifacts/analysis/probes/`。
- `.toolchain/downloads/`（2.2 GB 安装包）已删除；工具链本体已迁入本目录。
