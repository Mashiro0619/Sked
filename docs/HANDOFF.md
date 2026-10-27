# Sked 项目交接

RC.4 发布准备（2026-10-22）：当前候选为 `2.3.0-rc.4+19`，拟使用标签 `v2.3.0-rc.4` 并标记预发布；[公开发布说明](releases/2.3.0-rc.4.md)与 CHANGELOG 已整理。当前处于本地准备阶段，尚未创建发布标签、上传附件或发布 Release。最终候选的本地构建、对应 CI、正式签名和实际设备验收分别记录；下方历史性能与平台回执保留原版本归属。AppData 顶层保持 v4，日程格式保持 RC.3 的 schema 6；升级与回退按发布说明保留旧备份。

以下为 2026-10-18（Asia/Shanghai）的历史性能专项交接：当时实现、定向回归和同协议采样已完成，对应最终代码为 `0f5a8f96b04b7580f1759ef48dc9b91073f6c708`。改动涵盖日期与提醒候选复用、课表排版与语义复用、导航回调与 ticker 订阅边界，以及透明点击层去冗余。最新 8 文件回归 **143 项通过**，2 文件格式和 fatal-info 分析通过；日期 304/128 次按未变源码哈希关联，104 次本地补充单列。最终六轮 Profile 对照覆盖 `df5676f → 0f5a8f9` 完整改动集，严格可比且独立来源与数值审计通过，未隔离最后一项 Material 改动的单独收益；压力长帧及原平台边界仍保留，详见[续验结果](engineering/PROJECT_REFACTOR_CONTINUATION_RESULTS.md)。

## 1. 当前状态与接手边界

当前实现、分批回归、正式对照与阶段审计见[续验](engineering/PROJECT_REFACTOR_CONTINUATION_RESULTS.md)。[透明层 r2 回执（来源记录）](engineering/LEGACY_EVIDENCE_INDEX.md#e066)记录 143 项回归，9 个源文件哈希对应当前提交；[日期验收汇总（来源记录）](engineering/LEGACY_EVIDENCE_INDEX.md#e040)只按 7 个未变关键文件关联。下表仍保留 **e522134 检查点**的综合验收，不表示当前代码已重跑全量、整套发布包、UI66、Linux 应用构建或完整浏览器矩阵。

| 项目 | e522134 检查点的结果与范围 |
| --- | --- |
| 工作目录／分支 | `D:\Project\Flutter\sked`，`main` |
| 应用与工具链 | `2.3.0+17`；Flutter 3.47.7 / Dart 3.13.5；Windows 包版本 2.3.0.17 / 2.3.17.0 |
| 提交范围 | `1139840` 列表日期复用保留，`1d45d46` 课表文字缓存候选由 `e522134` 签名撤回；最终 tree 与 `1139840` 相同。三个提交签名历史保留；截至 `1142cfc` 的历史 139 条链路见主报告，总数不是当前未推送数 |
| Source | [最终回执（来源记录）](engineering/LEGACY_EVIDENCE_INDEX.md#e011)；9 步全部退出 0；完整 VM **4,901 通过、1 跳过**；754 文件格式检查零改动，应用和内部插件分析通过。候选首次 OOM 中断与降并发完整重跑另行保留，不混入本次计数 |
| Windows Packages | [最终回执（来源记录）](engineering/LEGACY_EVIDENCE_INDEX.md#e014)；Unsigned/Store 两类 Release/MSIX、身份/Toast/capabilities/payload 与归档 verifier 通过，两包未签名；未安装、升级、WACK 或发布 |
| Android 构建与 JVM | [最终回执（来源记录）](engineering/LEGACY_EVIDENCE_INDEX.md#e010)；APK/AAB 与合并安全产物归档；JUnit XML 10 项、0 失败/错误/跳过；Gradle 报告结果复用（`> Task :app:testDebugUnitTest UP-TO-DATE`），不能计作本 SHA 新执行；无真机 |
| Linux 四时区／Chrome | [最终回执（来源记录）](engineering/LEGACY_EVIDENCE_INDEX.md#e084)；纽约 23 项、柏林 23 项、上海 23 项、圣保罗 7 项，共 76 次、零失败/跳过。最终范围为日期回归与列表投影两文件；此前较大时区矩阵和 Chrome 租约 4 项仍属于 `1142cfc` |
| Web Release | [最终回执（来源记录）](engineering/LEGACY_EVIDENCE_INDEX.md#e012)；JavaScript Release 与[该 SHA 的有限浏览器流程（来源记录）](engineering/LEGACY_EVIDENCE_INDEX.md#e087)通过；范围按独立回执。`1d45d46` 的 RGB/Enter/Escape 是候选历史，课程 Enter 超时与窄屏 DOM overflow 不改写为通过 |
| Windows MSAA | [最终回执（来源记录）](engineering/LEGACY_EVIDENCE_INDEX.md#e013)；27/27 阶段、66 次语义更新、5 次同 PID MSAA、28 个按钮与 2 个文本检查；AX/graph/fatal 均 0；integrationPluginWarning=true 原样保留 |
| 完整 UI66 正确性 | [最终回执（来源记录）](engineering/LEGACY_EVIDENCE_INDEX.md#e085)；e522134 新进程直接通过 66 actions + 3 mounts、6 settings/36 scroll、0 AX/graph/fatal。旧 `1142cfc` failed/sidecar 不重写 |
| 后续长帧比较 | 最终 `5ef639c → e522134` 两侧各三进程、ABBAAB、60+3 可比；5k 首次列表最大 build 中位数 886.417 → 374.376 ms。仍有 27/60 个交互至少一次 ≥100 ms，含挂载后后测全局最坏 937.056 ms；实际帧节奏不同，整体 P95 仅作描述。全部不利结果见[续验结果](engineering/PROJECT_REFACTOR_CONTINUATION_RESULTS.md)；1d 候选样本另列 |
| 独立进程启动 | 原版 `77061b4` 加存档启动/隔离适配层 → `1142cfc`，18 个 Windows Profile 进程。5k 就绪 raster 中位数 5.459 → 2.267 s（−58.47%），就绪报告 RSS 386.71 → 444.41 MiB（+14.92%）；详见[启动结果](engineering/PROJECT_REFACTOR_STARTUP_RESULTS.md) |
| 历史性能系列 | [Disk30](engineering/PROJECT_REFACTOR_DISK_PERFORMANCE.md) 的 after 保留 `1205c6e`；[UI60/Host11/编辑](engineering/PROJECT_REFACTOR_UI_PERFORMANCE.md) 保留 `d328a17` 系列。编辑 before AX 199/204/201 使数值比较 invalid，after 36 动作与读回 / 0 AX 仅作正确性证据 |
| Linux native | [最终回执（来源记录）](engineering/LEGACY_EVIDENCE_INDEX.md#e084)；e522134 独立 Debian 13 Release/动态链接/四时区通过，1,026 个非生成文件字节不变，7 个生成文件只允许 CRLF→LF 后冻结；未图形运行、安装、通知或原生输入 |
| 尚未覆盖 | Android 真机按约定延期；Windows 安装/同签名升级/干净机器/WACK、物理输入、完整辅助技术，Linux 图形运行/安装/通知及 Web 离线/Wasm 仍未覆盖。最终压力长帧与内存/raster 代价保留；未推送、远端 CI、部署或发布 |

本轮已完成领域状态与组合根迁移、存储和计算边界、两个工作区投影与缓存、编辑及导入任务、通知分层，以及测试和 CI 精简；后续又修正公历校验、月页日期复用、缺失午夜日界与启动依赖组装。逐项实现和验收来源见[全项目重构实施报告](engineering/PROJECT_REFACTOR_REPORT.md)。启动比较包含显式基线适配、外部服务隔离与保留的 OS/字体/shader 缓存，不能写成未修改发布包、磁盘冷启动或真实像素呈现对照。

历史上已撤销的“Sked 2.3.0 完整体验优化最终计划”不自动恢复；六类设置等撤回方案和旧“4257 项通过”不构成本轮依据。设置目录与工作区可见性以 [settings_catalog.dart](../lib/models/settings_catalog.dart) 为准。

用户已明确授权全项目重构、性能优化、测试精简与持续本地原子提交。独立改动验证后立即采用现有 SSH 签名与单行中文 `type(范围): 摘要` 提交，逐次核对暂存内容和签名；推送、发布另行安排。Android 真机暂未提供时先完成其余工作，设备可用后再补真机验收。继续执行时核对实际实现和证据，不重复询问已明确授权的范围。

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

WebView 的 Android、iOS、macOS override 固定了不可变 Git 提交，原因在 [pubspec.yaml](../pubspec.yaml) 注释中。安全存储声明 `^11.2.0`，当前 [锁文件](../pubspec.lock) 解析为 `11.2.0`；[密钥存储](../lib/services/secret_store.dart) 使用 `AndroidOptions(migrateWithBackup: true)`。配置存在不能代替真实旧密钥迁移验证；适用的迁移范围及设备验收边界见 [依赖维护](DEPENDENCY_UPGRADES.md)。

## 4. 架构与代码入口

主要数据流：界面操作 → 领域命令与任务控制器 → 同一 AppSession／AppRepository 串行持久化 → 带领域版本的耐久提交 → 相关视图、通知与平台投影。各控制器不另存可写 AppData 副本。

| 领域 | 入口及职责 |
| --- | --- |
| 启动与生命周期 | [main.dart](../lib/main.dart)：`runSkedApp` 统一平台初始化；`AppBootstrap` 接收运行时工厂和 `AppStartupDependencies`，`MyApp` 保留同一首页实例；实例租约、加载写门禁及显式退出 flush 保持前置 |
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

普通全量测试不能替代 Linux Chrome 实例租约和纽约／柏林／上海／圣保罗四时区专项。CI 的完整 VM 测试只运行当前提交，不再检出覆盖率基线重跑；总覆盖率与 90% 改动行硬门禁已删除，LCOV 只保留为诊断附件。格式、分析、本地化一致性、核心行为、浏览器/时区和平台产物安全检查继续保留。

构建入口：

```powershell
flutter build apk --release
flutter build appbundle --release --dart-define=SKED_DISTRIBUTION_CHANNEL=google-play
flutter build windows --release
pwsh -NoProfile -File tool/build_msix.ps1 -Store
```

构建不是发布。Android 签名、包类型与升级验证独立核对；Windows 分发完整运行目录。Store 包与站外包使用不同身份和版本映射，见 [Microsoft Store 指南](microsoft-store.md)。Debug／原生测试后构建 Release 保留正常 Flutter 插件准备流程，避免用 `--no-pub` 复用错误注册器；不要并发构建并改写同一工作区的生成文件。

## 6. 最近完成的实现与验收入口

| 提交／入口 | 已完成范围 |
| --- | --- |
| `4276e92` | AppRuntime 组装切换并删除旧门面；领域与就绪订阅分离，后续全量已承接 |
| `ab9613b`、`ba7c5ff` | 合并普通内存夹具，18 个旧全局状态测试按业务归入 `test/controllers`；故障/竞争专用夹具保留 |
| `206e307`、`4492184`、`1205c6e` | 真实隔离磁盘操作、JSON/ICS 导入及课程/事件编辑基准；历史采样保留原版本和协议 |
| `d8cd94f` | 37 个历史界面采集入口归并为一个 selector，保留 40 个场景注册；选定原生组生成 48 张 PNG，未声称重跑全部场景 |
| `fb1ef2a`、`57751c2`、`d328a17` | 稳定画布子控件语义与 MSAA 工具；Slider 保留独立 Semantics/全局 Overlay，完整单表单滚动保留离屏锚点；57 项定向和 4 边缘全 RGBA 是该批历史证据 |
| `61446c3`、`e5615f9`、`4d54cc3` | 公历校验避免重复时区查询，月页复用日期计算，修正缺失午夜后的跨日事件日界；CI 增加圣保罗专项 |
| `199f021`、`d517f78` | 通知锁增加独立作用域；启动外部服务工厂按根生命周期装配并保持首页实例，支持显式隔离测量 |
| `895ed70` | UI60/UI66 日周滚动固定到主画布，记录目标协议与几何；旧错误目标样本保留为失效证据 |
| `c286e2c`、`1142cfc` | 增加正常窗口独立进程启动、原生时钟、分阶段 RSS/峰值和启动交互协议；[18 进程结果](engineering/PROJECT_REFACTOR_STARTUP_RESULTS.md) 已另表保存 |
| `1139840`、`1d45d46`、`e522134` | 列表日期复用保留；文字测量缓存候选经交替测量后撤回，最终 tree 与 `1139840` 相同；[最终续验与候选历史](engineering/PROJECT_REFACTOR_CONTINUATION_RESULTS.md)分别记录 |
| `d9d98af` | 列表逐条构建、稳定事件焦点与日期标题语义；相关回归和前后各三轮原生流程通过，严格性能比较因长度估算变化拒绝，见[续验](engineering/PROJECT_REFACTOR_CONTINUATION_RESULTS.md) |
| `df5676f`、`423d030`、`5da71f9` | 冻结 workspace60-v2 可见内容/位移协议；复用本地日界、月页区间和提醒候选窗口，304/128 次跨时区定向与 104 次本地补充单列 |
| `32cf799`、`08026f9`、`9cd2c4c` | 复用卡片数值布局、完整单行与二分探针；77、139 等回归及 080 阶段比较保留各自版本与范围 |
| `00c096b`、`d782a02` | 稳定导航回调、按星期列隔离 ticker 通知；138 项阶段回归与 d782 独立六轮比较保留所有长帧及资源代价 |
| `86b95ff` | 复用未变语义属性并保留当前动作与目标；142 项阶段回归、六轮 ABBAAB、严格可比性及统计/来源审计通过，保留实际帧节奏混杂和所有长帧/资源代价 |
| `0f5a8f9` | 仅显式指定 CourseHitTarget 的透明 Material 类型；143 项回归、独立六轮严格比较及来源/数值审计通过，墨水绘制/命中/语义和所有压力边界保留 |

这些是各自提交的验证与来源，不相加为全项目总通过数。采集命令见[原生场景入口](../integration_test/README.md)，通过 `capture_scenarios_test.dart` 与 `SKED_CAPTURE_SCENE` 选择组。公开文档的 32 张 JPEG 保持原样，继续使用[文档截图流程](screenshots/README.md)。场景截图不代替行为回归、原生辅助技术或 Profile 采样。

## 7. 继续执行与证据限制

1. **以当前实现和分范围回执交接。** 0f5a8f9 的 143 项回归与 9 个源文件哈希已核对；304/128 按 7 个未变关键文件关联，104 仍为本地诊断。215 成功加 1 个加载失败、17/14 独立复验、77/138/139/142 阶段回归及 e522 的 4,901/1 各自保留，不相加为当前全量。透明层 r1 的 142 通过/1 hover 断言失败、单项时序修正复验，以及语义 r1 的 139 成功/3 清理失败均保留，文档更新不增加执行数。
2. **保留本轮完成范围与压力边界。** 0f5a8f9 的六个新进程于 2026-10-18 01:22:25–01:35:10（UTC+08:00）按 ABBAAB 完成，各 60 actions + 3 mounts，严格比较 comparable，独立来源与数值复核通过。本轮实现和本地验证完成，仍有 18/60 个动作至少一次 build ≥100 ms；cold `student.day.open_scroll` 的最大 build 中位数升高 2.65%，完整窗口含返回周视图的工作。三次重复只作描述，源码/完整 bundle 已冻结，外部 SDK/pub cache 未整体归档；详见[续验](engineering/PROJECT_REFACTOR_CONTINUATION_RESULTS.md)。旧阶段与 CPU 诊断不混入本轮因果判断。
3. **按实际剩余平台范围继续。** 当前 WSL 结果覆盖冻结实际源码的定向测试，e522 的 Linux Release/链接仍属于原版本；当前 Linux 图形运行、安装、通知和原生输入未验收。Android 真机按约定延期，设备可用后补通知、恢复、真实交互、旧数据/密钥升级和性能；完整辅助技术另列。
4. **保留发布边界。** e522 的 Windows 两包、Android APK/AAB 与 Linux bundle 为原版本归档；本轮阶段 Profile 对照、诊断和定向回归不替代整套发布包、安装、同签名升级、干净机器、WACK/认证或远端 CI。e522 的有限浏览器结果保留原范围；本轮未推送、部署或发布。
5. **历史线索不冒充当前缺陷。** 2026-10-07 撤回前的提醒/AI 预览与拖宽跳变没有当前复现结论；旧 Overlay 方案已废弃。Windows Chrome 工具适配、Linux Chrome 租约、候选 Chromium 视觉均保留各自来源，不能合并成最新完整浏览器验收。
6. **整批缓存清理仍暂停。** 用户此前接受暂不删除日志、coverage、widget preview 等本地资料；`.scratch` 含隔离源码、构建、包、截图和原始报告。后续清理需重新核对具体路径，不沿用旧大小统计。

## 8. 推荐阅读顺序

1. 本文与[全项目重构实施报告](engineering/PROJECT_REFACTOR_REPORT.md)。
2. [最新续验](engineering/PROJECT_REFACTOR_CONTINUATION_RESULTS.md) → [此前长帧结果](engineering/PROJECT_REFACTOR_LONG_FRAME_RESULTS.md) → [启动结果](engineering/PROJECT_REFACTOR_STARTUP_RESULTS.md) → [历史 UI/Host](engineering/PROJECT_REFACTOR_UI_PERFORMANCE.md)／[Disk30](engineering/PROJECT_REFACTOR_DISK_PERFORMANCE.md)。
3. [PRODUCT](../PRODUCT.md)／[README](../README.md) → [DESIGN](../DESIGN.md) → [自适应规范](ADAPTIVE_WORKSPACES.md)／[桌面浮层](DESKTOP_FLOATING_PANELS.md)。
4. [可靠性](RELIABILITY_BASELINE.md) → [通知契约](NOTIFICATION_DEDUPLICATION.md) → [依赖维护](DEPENDENCY_UPGRADES.md)。
5. [发布验收](RELEASE_ACCEPTANCE.md) → [Android 通知矩阵](ANDROID_NOTIFICATION_ACCEPTANCE.md) → [更新机制](updates.md)／[Store 指南](microsoft-store.md)。

只更新发生变化的交接状态，不新增按日期命名的重复审查报告；长期约定维护在对应规范中。
