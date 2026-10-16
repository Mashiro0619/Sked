# Sked 项目交接

交接日期：2026-10-17（Asia/Shanghai）。本文件以 `d328a174e4047438feae79950b9b782c5fc2876c` 为已提交代码快照。最终滑块保留独立 Semantics 和全局 Overlay，无 headerSliver 的完整单表单改用 SingleChildScrollView，使离屏锚点保持在树中并标为 hidden；局部/page Overlay 均已废弃。57 项定向、四个滚动边缘对照与完整 UI66 已有通过证据；本 SHA 的 Source 阶段 9 步全部通过，完整 VM 为 4,861 通过、1 跳过。各次验收保留实际采样版本，候选通过已记录的源码哈希对应到提交，不能直接重写原报告 revision。长期规则以本文链接的维护文档及当前实现为准。

## 1. 当前状态与接手边界

| 项目 | 本次核实结果 |
| --- | --- |
| 工作目录 | `D:\Project\Flutter\sked` |
| 分支 | `main` |
| HEAD（文档检查点） | `d328a174e4047438feae79950b9b782c5fc2876c` |
| 最新提交 | `fix(设置滚动): 保留离屏语义锚点与完整滑块提示` |
| 应用版本 | `pubspec.yaml` 为 `2.3.0+17`；版本号不表示 HEAD 等同于发布标签 |
| 工作区 | 原始基线后共 129 个实现提交；d328a17 的 Source、正式性能采样和本轮本机平台阶段均已结束。四份报告按同一文档提交合入，文档汇总提交不计入本文的 129 条实现时间线；写入时观察的 HEAD/工作区另存 manifest |
| 磁盘 Profile | 原始版与当前版各 3 个独立进程、每进程 30 动作的比较已通过；24 项墙钟中位数下降、6 项上升，进程最大 RSS 中位数约 +3.01%，见[全部 30 项附表](PROJECT_REFACTOR_DISK_PERFORMANCE.md) |
| 最新全量与修复 | `d328a17` 完整 VM 为 4,861 通过、1 跳过，Source 共 9 步全部通过。修正前 4,848/1/6 与 `ce915f5` 的 103 项定向仅保留为历史，不与新全量相加 |
| 最终 Windows 构建与包检查 | d328a17 两次 Release 重建、Unsigned/Store MSIX 和归档 Store verifier 全通过；身份、Publisher、x64、AppId、Toast、capabilities、三份 payload 及包 SHA 已独立复核。版本为 2.3.0.17 / 2.3.17.0；先归档 Unsigned 再构建 Store，未安装、WACK 或发布 |
| Android 构建与 JVM | `d328a17` 的 APK、JVM、AAB、合并安全产物及安全检查共 5 步通过；APK/AAB 归档哈希已复核。JVM 10 项、0 failure/error/skip，实际任务行与 XML 时间窗口支持本次执行；独立 sidecar 修正原回执对 CRLF 行的漏捕获，原回执保持不变，未作真机验收 |
| Linux 专项与 Web | 同 SHA 的纽约/柏林/上海各 18 项、Linux Chrome 租约 4 项通过；Web Release 构建 exit0，归档 index/main.dart.js。Web 有 CupertinoIcons 字体扫描提示，Wasm 仅 dry run；不表示 Linux native build 或 Web 页面视觉验收 |
| 最终 Windows MSAA | d328a17 的明确预构建 Profile 目标完成 27/27 阶段、69 updates、5 次 MSAA、28 buttons、2 text checks，graph/AX/fatal 均 0，退出 0；3 个编译快照前后哈希一致。integrationPluginWarning=true 保留，实际报告与探针完整 |
| Windows Chrome | 同一实例租约测试经任务内 Flutter 工具适配通过 4 项。原版 CLI 在启动阶段失败；一个工具副本文件的两处 URI path 修复已验哈希，全局 SDK、应用和测试源未改，不能写成原版 CLI 直接通过 |
| 滑块最终实现 | `d328a17` 保留各 Slider 的独立 Semantics 和原有全局 Overlay；完整单表单使用 SingleChildScrollView，离屏锚点保留且 hidden。57 项针对测试通过，900/1440 真实设置滚动/关闭场景包含其中；没有新增局部或页面 Overlay |
| 滑块边缘对照 | 4 个滚动边缘场景的全 RGBA、几何与滚动偏移完全相同，viewport 内/边界/外均 0 像素差异、通道容差 0。旧局部 Overlay 丢失 871 像素和页面 owner 回归失败仅保留为废弃方案诊断；新对照仍是 widget-raster，不是原生窗口截图 |
| 完整 UI66 正确性 | 提交前完整 Windows Profile 覆盖 3 规模 / 66 actions + 3 mounts，0 AX、原生/框架起止状态均 true 且无变化。报告保留 `ef1aea31ed79`，六文件候选哈希关联 `d328a17`；一进程完整正确性不等于性能前后六进程比较 |
| UI60 正式 Profile | `workspace60-v1` 两端各 3 个独立进程已完成，比较器接受 60 项动作与 3 类 mount，全部进程记录 0 AX。旧单进程 pilot 仍保留 `4169dc72313d`；正式样本另存 `ui-workspace-before/after-final-d328a17`，不裁剪 UI66 或混用 warm 样本 |
| Host11 正式比较 | 两端各 3 个独立 host 进程完成，11 项纯数据操作可比；保留 host JIT 与原生 Profile/真实 UI 响应的区别 |
| 真实编辑正式采样 | 两端各 3 次已运行；before 三进程有 199/204/201 条 AX 拒绝，数值比较 invalid、0 项，不据此给出改善百分比。after 三进程共 36 动作、磁盘独立读回均通过，0 AX；只作为新版正确性证据 |
| 性能比较工具 | UI60/预构建准入的 45 项 stdlib 检查通过；正式三套样本已采集并审计，既有 disk30 的 30 项与分布复算不变。旧 legacy-no-build-driver pilot 始终只作历史诊断，未混入正式总体 |
| WSL 与 Chrome | 任务内 Chrome 155 的初次准备、版本/headless 探针与项目测试分层保留；`d328a17` Linux 阶段已通过 3 步，锁定源码后执行三个时区和 Chrome 租约测试。没有据此宣称 Linux native Release 构建 |
| 最终验收 | 已安排的 Source、Android、Linux 专项、Web、Windows Native/Chrome/Packages 与性能系列均有终态。编辑数值比较受原始版 AX 限制；整进程冷启动和 Android 真机未验收，压力场景仍有长帧与内存回退。远端 CI、推送、安装、WACK 和发布本轮未执行 |

本轮已完成领域状态与组合根迁移、存储和计算边界、两个工作区缓存与投影、编辑及导入任务、通知分层，以及测试和 CI 精简。模块处理、测试取舍与逐项提交见 [全项目重构实施报告](PROJECT_REFACTOR_REPORT.md)。`d328a17` 的完整源码检查、正式 UI60/Host11、Windows 原生检查及 Windows/Android/Web 构建已有本次回执；磁盘性能保留 `1205c6e` 实测版本，Android 真机与整进程冷启动仍待补齐。

历史上已撤销的“Sked 2.3.0 完整体验优化最终计划”仍不应自动恢复；六类设置等撤回方案和旧“4257 项通过”不构成本轮的实现依据或测试证据。当前设置目录与工作区可见性以 [settings_catalog.dart](../lib/models/settings_catalog.dart) 为准。

用户已另行明确授权本次全项目重构、性能优化、测试精简与持续本地原子提交。每个独立改动经过针对性验证后立即提交，采用现有 SSH 签名与单行中文 `type(范围): 摘要`，逐次核对暂存内容和签名；推送、发布另行安排。Android 真机暂未提供时，先完成其余可做工作，最后补齐真机验收。接手时继续核对实际实现和证据，不把历史任务限制误作本轮尚待授权。

## 2. 产品范围

Sked 是本地优先的 Flutter 课表与日程应用，两个工作区可以单独启用：

- 学生课表：学期、教学周、节次、课程、多课表及学校网页／文本／HTML 导入。
- 通用日程：分类日历、日／周／月／列表、全天或定时事件、重复规则、应用内提醒及 JSON／ICS 导入导出。
- 共用能力：备份恢复、精确主题配色、多语言、系统通知、更新提示和自适应编辑界面。

Android 与 Windows 是主要发布和交互平台；Apple／Linux 工程保留构建兼容，Web 不作为已交付在线产品。仓库中的平台目录或 CI 构建不等于已有正式分发和运行验收。

课表解析调用用户配置的 OpenAI 兼容服务，项目不提供内置公共解析服务。`/models` 与 `/chat/completions` 属于该外部端点；开发者 AI 布局预览尚不是聊天或自动执行功能。

产品与视觉边界见 [PRODUCT](../PRODUCT.md)、[DESIGN](../DESIGN.md)。现有实现使用 `material_ui`、`cupertino_ui` 等 Flutter 包，不要把其他项目的前端依赖偏好套到本项目。

## 3. 环境与启动

| 依赖 | 仓库声明／配置 |
| --- | --- |
| Flutter | `>=3.47.7`；CI 固定 stable `3.47.7`，本机已准备版本也是 `3.47.7` |
| Dart | `^3.13.5` |
| 状态管理 | `provider` 注入明确领域接口；`AppRuntime` 是非 `Listenable` 的组合根，不是全局状态订阅入口 |
| 内部插件 | [android_productivity_plugin](../packages/android_productivity_plugin)，独立锁文件 |
| Android CI | Ubuntu、Java 17；具体 SDK 和构建步骤以 workflow 为准 |
| Windows | Flutter Windows 桌面工具链；MSIX 与 Store 构建使用 PowerShell 脚本 |

在项目根目录依次执行，逐项检查退出码：

```powershell
git status --short
flutter --version
flutter doctor -v
flutter pub get --enforce-lockfile
Push-Location packages/android_productivity_plugin
flutter pub get --enforce-lockfile
Pop-Location
flutter devices
flutter run -d windows
# Android：改为 flutter run -d <设备ID>
```

以上是接手运行说明，不代表这些命令在本次文档更新中重新执行。Profile 采样期间保持源码与构建输入稳定，不并发启动分析、测试、构建或改写依赖。运行应用前确认测试环境和数据位置；不用真实用户存档做破坏性验证，不提交本机签名文件、密钥或生成缓存。

WebView 的 Android、iOS、macOS override 固定了不可变 Git 提交，原因在 [pubspec.yaml](../pubspec.yaml) 注释中。安全存储仍锁定 10.3.1，大版本升级需要真实旧密钥迁移验证。两者均不能仅为消除版本提示而顺手升级，详见 [依赖维护](DEPENDENCY_UPGRADES.md)。

## 4. 架构与代码入口

主要数据流：界面操作 → 领域命令与任务控制器 → 同一 AppSession／AppRepository 串行持久化 → 带领域版本的耐久提交 → 相关视图、通知与平台投影。各控制器不另存可写 AppData 副本。

| 领域 | 入口及职责 |
| --- | --- |
| 启动与生命周期 | [main.dart](../lib/main.dart)：`AppRuntimeFactory`、`AppBootstrap(runtimeFactory: ...)` 与 `MyApp(app: ...)`；实例租约、加载写门禁及显式退出 flush 保持前置 |
| 组合与依赖 | [app_runtime.dart](../lib/app_runtime.dart) 统一持有 19 个领域实例；[app_scope.dart](../lib/providers/app_scope.dart) 注册领域与独立 readiness 桥，跨 Navigator 捕获同一组实例 |
| 会话与业务入口 | [app_session.dart](../lib/controllers/app_session.dart) 管理会话、写入状态、版本及提交；[controllers](../lib/controllers) 分别提供 Student、General、Settings、Workspace 的命令和只读视图，旧 TimetableProvider 与共享业务 mixin 已删除 |
| 数据模型 | [models](../lib/models)：`AppData`、课表、日程、设置、工作区；[重复实例展开](../lib/models/general_event_occurrence.dart) 管理重复日程计算 |
| 持久化 | [app_repository.dart](../lib/data/app_repository.dart)：串行写入、内存与已提交快照、失败门禁；[timetable_storage.dart](../lib/data/timetable_storage.dart) 连接平台存储与恢复 |
| 通知 | [agenda_coordinator.dart](../lib/services/agenda_coordinator.dart) 按耐久提交的相关领域筛选对账；[agenda_notification_service.dart](../lib/services/agenda_notification_service.dart)、平台 gateway 与 [runtime store](../lib/services/agenda_notification_runtime_store.dart) 分别管理计划、登记和平台调用 |
| 主界面与布局 | [app_home_screen.dart](../lib/screens/app_home_screen.dart)、[workspace_frame.dart](../lib/widgets/workspace_frame.dart)、[workbench_layout_policy.dart](../lib/widgets/workbench_layout_policy.dart) |
| 浮层、表单会话 | [sked_task_session.dart](../lib/widgets/sked_task_session.dart)、[sked_task_route.dart](../lib/widgets/sked_task_route.dart)、[sked_task_submission_controller.dart](../lib/widgets/sked_task_submission_controller.dart) |
| 设置 | [settings_page.dart](../lib/screens/settings_page.dart)、[settings_catalog.dart](../lib/models/settings_catalog.dart)、[adaptive_settings_scaffold.dart](../lib/widgets/adaptive_settings_scaffold.dart) |
| 导入、备份与密钥 | [data_transfer_controller.dart](../lib/controllers/data_transfer_controller.dart) 分离解析候选与确认应用；[app_backup_controller.dart](../lib/controllers/app_backup_controller.dart)、[school_import_workflow.dart](../lib/services/school_import_workflow.dart)、[secret_store.dart](../lib/services/secret_store.dart) 保留恢复和密钥隔离 |
| 计算与视图投影 | [app_data_codec.dart](../lib/data/app_data_codec.dart)、[data_transfer_codec.dart](../lib/services/data_transfer_codec.dart) 原生默认使用计算 isolate；月页、时间轴、列表与课表周投影按内容版本和实际布局输入复用 |
| 更新 | [update_service.dart](../lib/services/update_service.dart)、[update_prompt_scope.dart](../lib/widgets/update_prompt_scope.dart)；渠道规则见 [updates.md](updates.md) |
| 本地化与主题 | [lib/l10n](../lib/l10n)、[lib/theme](../lib/theme)；修改 ARB 后生成，保留用户精确色值 |
| 工具与 CI | [tool](../tool)、[flutter.yml](../.github/workflows/flutter.yml)：当前提交测试、诊断覆盖率、平台构建、安全产物、MSIX 与截图导出；专用 coverage base/gate 工具已删除 |

必须保留的边界：

- AppData 顶层格式为 v4。恢复、未来版本和 I/O 不确定状态遵循写入门禁，不能绕过门禁强行保存。
- 通知依据已持久化快照，不投影 UI 乐观状态；锁顺序、登记凭据、代际隔离和稍后提醒语义不能靠新增超时或清空记录规避。
- 工作区停用保留数据和配置，停止对应运行时工作；停用、活动工作区和导航可见性是三个独立概念。
- API Key 不进入普通 AppData／备份；HTTP 端点发送前确认，错误输出脱敏，保留重定向防护。
- 关闭、切换和异步返回必须尊重草稿、忙碌状态和会话有效性，不能盲目 pop 当前路由。
- 桌面浮层与触控 sheet/dialog 按宿主规则工作；视觉整理不应改变持久化、权限或模态保护。
- AppRuntime 本身没有全局 notifyListeners 或业务转发门面。就绪、领域内容和界面导航分别发布；保留未变对象身份，不重新引入无关领域全量更新。

细节分别见 [可靠性指南](RELIABILITY_BASELINE.md)、[通知契约](NOTIFICATION_DEDUPLICATION.md)、[自适应工作台规范](ADAPTIVE_WORKSPACES.md)、[桌面浮层规范](DESKTOP_FLOATING_PANELS.md)。

## 5. 测试与构建

日常检查的完整说明见 [可靠性指南](RELIABILITY_BASELINE.md)。从根目录运行：

```powershell
flutter gen-l10n
git diff --exit-code -- lib/l10n
git status --short -- lib/l10n
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test --no-pub --coverage --concurrency=4
git diff --check
```

生成差异需结合修改前的工作区判断；新增译文导致的预期生成变化应审查，不能机械要求永远无差异。未跟踪文件也需要检查。

按实际改动选择专项，不为文档变更重复跑全套：

| 改动 | 现有验证入口示例 |
| --- | --- |
| 持久化、恢复、密钥 | [test/data](../test/data)、[test/controllers](../test/controllers)、[保存竞争测试](../test/controllers/app_persistence_race_test.dart) |
| 通知并发 | [notification_runtime_lock_order_test.dart](../test/services/notification_runtime_lock_order_test.dart) 及相关通知服务测试 |
| 工作台、提醒、设置 | [面板几何测试](../test/widgets/workspace_panel_resize_geometry_test.dart)、[提醒预览测试](../test/widgets/reminder_summary_preview_test.dart)、[设置测试](../test/widgets/settings_page_test.dart) |
| 更新 | [update_service_test.dart](../test/services/update_service_test.dart)、[app_update_coordinator_test.dart](../test/services/app_update_coordinator_test.dart)、[更新弹窗测试](../test/widgets/app_update_dialog_test.dart) |
| 原生交互／截图 | [integration_test](../integration_test)、[test_driver](../test_driver)；普通 `flutter test` 不等于这些原生场景已运行 |

普通全量测试不能替代 Linux Chrome 实例租约和纽约／柏林／上海时区专项。CI 的完整 VM 测试只运行当前提交，不再检出覆盖率基线重跑；总覆盖率与 90% 改动行硬门禁已删除，LCOV 只保留为诊断附件。格式、分析、本地化一致性、核心行为、浏览器/时区和平台产物安全检查继续保留。

构建入口：

```powershell
flutter build apk --release
flutter build appbundle --release --dart-define=SKED_DISTRIBUTION_CHANNEL=google-play
flutter build windows --release
pwsh -NoProfile -File tool/build_msix.ps1 -Store
```

构建不是发布。Android 签名、包类型与升级验证独立核对；Windows 分发完整运行目录。Store 包与站外包使用不同身份和版本映射，见 [Microsoft Store 指南](microsoft-store.md)。Debug／原生测试后构建 Release 保留正常 Flutter 插件准备流程，避免用 `--no-pub` 复用错误注册器；不要并发构建并改写同一工作区的生成文件。

## 6. 最近完成的实现与验收入口

| 提交／入口 | 当前状态与范围 |
| --- | --- |
| `4276e92` | 最终 AppRuntime 组装切换并删除旧门面；522 项定向回归通过 |
| `ab9613b`、`ba7c5ff` | 合并普通内存夹具，18 个原全局状态测试按业务归入 `test/controllers`；对应 500 项回归通过，故障/竞争专用夹具保留 |
| `206e307`、`4492184` | 真实隔离磁盘操作及 JSON/ICS 导入基准；sparse/1,000/5,000 全规模 Debug 原生冒烟通过 |
| `d8cd94f` | 37 个历史界面采集入口归并为一个 selector，保留 40 个场景注册；`mobile-calendar-grids` 原生冒烟生成 48 张 PNG 与 manifest |
| `ce915f5` | 日期标题/liveRegion 与提示语义修复，103 项定向通过；此后 d328a17 完整 VM 已通过，旧批次不重复计数 |
| `1205c6e` | 真实课程和日程卡片 → 详情 → 编辑 → 保存，独立读回磁盘；三个规模 Debug 原生冒烟通过 |
| `94d7c4c` | 修复 Profile 模式的有效文字输入客户端；提交前 1 进程、3 规模、12 动作 pilot 通过；本提交的两种 Windows MSIX 构建和包检查通过。后续正式采样另有独立来源和结论 |
| `fb1ef2a` | 固定画布关闭动作的语义父节点，并保留独立子控件语义；10 项定向测试及两文件分析通过。isolated 原生流程 27/27、0 AX/graph，候选的两文件哈希已对应到该签名提交 |
| `01a98c5` | 9 个基准文件完成真实首页装配与原生语义状态协议。UI 编辑 v2 的 12 动作/0 AX pilot 保留提交前 `fb1ef2a` revision，源码哈希对应本提交；不与后续正式六进程样本混用 |
| `57751c2` | 五个原生无障碍工具文件已提交；live 入口 27 阶段、68 updates、5 次 MSAA、0 AX/graph。报告保留提交前 revision，原工具候选/验证哈希可追溯 |
| `4169dc7` | 历史局部 Overlay 曾通过限定场景，后因顶部裁切被废弃；d328a17 已改用全局 Overlay 与完整表单滚动，并有独立新证据 |
| `ef1aea3` | 独立 UI60 工作区场景及协议已提交；6 项 widget 冒烟、1 进程 60 actions + 3 mounts / 0 AX pilot 通过。原报告保留 `4169dc72313d`，正式两端各三进程另以 d328a17 系列采集 |
| `d328a17` | 保留独立 Slider Semantics 和全局 Overlay；完整单表单改为 SingleChildScrollView。57 项定向、4 边缘全 RGBA 对照、完整 UI66 66+3 / 0 AX 通过；原 UI66 revision 保留 `ef1aea31ed79`，六文件候选哈希可追溯 |

这些是各自提交的验证，不相加为全项目总通过数。采集命令见 [原生场景入口](../integration_test/README.md)，使用 `capture_scenarios_test.dart` 与 `SKED_CAPTURE_SCENE`；每个进程选择一个组，复合 `floating-panels` 组需要统一输出目录时显式指定 `SKED_VISUAL_OUTPUT`。

公开文档的 32 张 JPEG 保持原样，继续使用 [文档截图流程](screenshots/README.md) 与 `documentation_screenshots_test.dart`。场景截图用于几何、字体和状态审查，不能代替自动行为回归、原生辅助技术或 Profile 性能证据。

## 7. 继续执行与证据限制

1. **保留最终源码和专项回执。** `d328a17` 的 Source 9 步全部通过，完整 VM 为 4,861 通过、1 跳过，见 [Source 回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-d328a174e4047438feae79950b9b782c5fc2876c/source-20261016T135646651Z/receipt.json>)。同 SHA 的 Android 5 步、Linux 三时区各 18 项和 Chrome 租约 4 项、Web 构建也有独立结果。旧 103 项或 57 项定向不与全量相加。
2. **按各自边界使用正式性能结果。** 磁盘 30 动作保留 `1205c6e` 实测；当前完整 [UI66](../benchmark/UI_PERFORMANCE.md) 为 66+3 / 0 AX 的正确性运行。新 [UI60](../benchmark/WORKSPACE_PERFORMANCE.md) 两端各三进程得到 60+3 可比项，Host11 得到 11 项可比操作，数值及退化见 [UI/Host 性能报告](PROJECT_REFACTOR_UI_PERFORMANCE.md)。真实编辑 before 的 AX 199/204/201 使比较 invalid，不能提供改善百分比；after 的 36 动作与读回 / 0 AX 单独保留。UI60 warm 与 UI66 前序不同，不混合或重复累计覆盖。
3. **保持样本来源可审查。** 不修改 `77061b4` 的生产代码来适配基线；仅使用兼容测试适配器。旧 UI 报告没有运行时 input SHA 或 PID，保留冻结输入源码、原始报告/日志与启动证据，不事后伪造字段。v2 的两端必须同协议重采各三进程；旧 before 与含 5,211 条 AXTree 错误的 `ui-after-v2-home-pilot` 均只作历史诊断。`cold` 只表示该基准的新会话；磁盘 load 与 UI mount 都不是 OS 整进程冷启动。
4. **保留滑块最终设计与验收范围。** `d328a17` 的 SingleChildScrollView、独立 Semantics 和全局 Overlay 已有 57 项定向、4 边缘全 RGBA 与完整 UI66 证据，见 [原生无障碍说明](NATIVE_ACCESSIBILITY_SMOKE.md)。旧 per-slider/page Overlay、8 组位置对照和 26+2 项测试只保留为历史，不再描述为当前实现。后续相关生产修改应重新判断证据适用范围；实际 AppBootstrap 冷启动仍受 Windows 默认通知 FFI 身份隔离限制，Android 平台流程与辅助技术待真机接入后验收。
5. **保留产物与发布边界。** d328a17 的 Windows Unsigned/Store 新包已构建、归档和核验，见 [最终包回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-d328a174e4047438feae79950b9b782c5fc2876c/windows-packages-20261016T175255916Z/receipt.json>)；94d7c4c 包只保留为历史。Android APK/JVM/AAB/安全检查、Linux 时区/Chrome 和 Web Release 均有对应结果；这不等于真机、Linux native、Web 视觉或实际 Wasm 构建通过。同签名升级、干净机器与商店认证见 [发布验收](RELEASE_ACCEPTANCE.md)。本轮未安装、推送、WACK 或发布。
6. **保留历史线索，按当前版本判断。** 2026-10-07 撤回前的“启动提醒与 AI 预览共存、拖宽跨阈值时画布跳变”仅是当时记录；本检查点没有独立复现结论，不将其写成当前仍存在或已经修复。历史图像和模拟 Android 布局也不作为当前真机证据。
7. **整批缓存清理仍暂停。** 用户此前接受暂不删除日志、coverage、widget preview 等本地资料；不把再次清理或反复确认设为接手前置条件。`.scratch` 混有隔离源码、构建、发布包、截图、性能报告和日志，旧大小统计已过时，任何后续清理都应重新核对具体清单与目标路径。

## 8. 推荐阅读顺序

1. 本文的当前状态与 [全项目重构实施报告](PROJECT_REFACTOR_REPORT.md)。
2. [PRODUCT](../PRODUCT.md) → [README](../README.md)：产品能力与平台边界。
3. [DESIGN](../DESIGN.md) → [自适应规范](ADAPTIVE_WORKSPACES.md) → [桌面浮层](DESKTOP_FLOATING_PANELS.md)：界面任务与生命周期。
4. [可靠性](RELIABILITY_BASELINE.md) → [通知契约](NOTIFICATION_DEDUPLICATION.md) → [依赖维护](DEPENDENCY_UPGRADES.md)：数据、平台和升级限制。
5. [发布验收](RELEASE_ACCEPTANCE.md) → [Android 通知矩阵](ANDROID_NOTIFICATION_ACCEPTANCE.md) → [更新机制](updates.md)／[Store 指南](microsoft-store.md)。

接手后只更新本文件中发生变化的交接状态，不再新增按日期命名的重复审查报告；长期约定更新到对应规范中。
