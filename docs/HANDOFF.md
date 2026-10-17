# Sked 项目交接

交接日期：2026-10-17（Asia/Shanghai）。已提交实现检查点为 `1142cfce894449df36994e866b179b706bec742e`，后续纯文档提交另计。Source、Windows Native/Packages、Android 构建、Linux 四时区/Chrome 及 Web Release 均已保留该 SHA 的终态；当前完整 UI66 由离线 sidecar 补齐验收。性能样本保留各自的真实版本与适配条件，详见下表；长期规则以本文链接的维护文档及当前实现为准。

## 1. 当前状态与接手边界

| 项目 | 已核实结果与范围 |
| --- | --- |
| 工作目录／分支 | `D:\Project\Flutter\sked`，`main` |
| 应用与工具链 | `2.3.0+17`；Flutter 3.47.7 / Dart 3.13.5；Windows 包版本 2.3.0.17 / 2.3.17.0 |
| 提交范围 | `77061b4` 之后至 `1142cfc` 的历史共 139 个提交：137 个实现或测试提交、2 个纯文档提交。对象、父链、单行中文摘要和 SSH 签名均有回执；本次交接文档提交不计入 137，历史总数也不表示当前未推送数 |
| Source | [9 步全部通过](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-1142cfce894449df36994e866b179b706bec742e/source-20261016T234624419Z/receipt.json>)；完整 VM **4,901 通过、1 跳过**，格式检查 754 文件、0 改动，应用和内部插件分析通过。旧全量与定向结果不相加 |
| Windows Packages | [4 步通过](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-1142cfce894449df36994e866b179b706bec742e/windows-packages-20261017T001804579Z/receipt.json>)；Unsigned/Store 各自 Release 重建、MSIX 归档、身份/Toast/capabilities/payload 检查及归档 Store verifier 通过。未安装、WACK 或发布 |
| Android 构建与 JVM | [5 步通过](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-1142cfce894449df36994e866b179b706bec742e/android-20261017T000729778Z/receipt.json>)；APK/AAB 和合并安全产物已归档。JVM 任务为 `UP-TO-DATE`，保留 XML 的 10 项、0 失败/错误/跳过，不能写成当前 SHA 新执行 10 项 |
| Linux 四时区／Chrome | [同 SHA 专项通过](<D:/Project/Flutter/sked/.scratch/refactor-20261017/final-audit/linux-final-1142cfce8944-20261017T002055669751Z/receipt.json>)；纽约/柏林/上海各 41 项、圣保罗 25 项，Chrome 155.0.8059.84 的实例租约 4 项。148 是按时区执行次数，不能和 VM 总数相加 |
| Web Release | [默认 JavaScript Release 构建通过](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-1142cfce894449df36994e866b179b706bec742e/web-20261017T002340535Z/receipt.json>)；index.html / main.dart.js 哈希已归档。CupertinoIcons 字体扫描提示保留，Wasm 仅 dry run，页面视觉未验收 |
| Windows MSAA | [当前原生流程通过](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-1142cfce894449df36994e866b179b706bec742e/windows-native-20261016T235958921Z/receipt.json>)；27/27 阶段、66 updates、5 次同 PID MSAA、28 buttons / 2 text checks，graph/AX/fatal 均 0。三份编译快照前后哈希一致；integrationPluginWarning=true 保留 |
| 完整 UI66 正确性 | [离线补验通过](<D:/Project/Flutter/sked/.scratch/refactor-20261017/resume-20261017/ui66/offline-20261017T002119423Z/sidecar.json>)；当前 SHA 的一进程、三规模 66 actions + 3 mounts，设置 6 项、scroll 36 项，0 AX/graph/fatal。原回执仍保留日期字符串误解析造成的 failed；sidecar 以正确类型重读，未重跑、未改断言，报告哈希本轮首次封存 |
| 后续长帧比较 | `041c6fd → d517f78` 的新主画布滚动协议，两侧各 3 进程、60+3 可比项。5k 月份 cold build P95 410.955 → 97.736 ms；工作区切换仍约 0.575–0.628 s，raster 与 RSS 仍有上升项，见[长帧结果](PROJECT_REFACTOR_LONG_FRAME_RESULTS.md) |
| 独立进程启动 | 原版 `77061b4` 加存档启动/隔离适配层 → `1142cfc`，18 个 Windows Profile 进程。5k 就绪 raster 中位数 5.459 → 2.267 s（−58.47%），就绪报告 RSS 386.71 → 444.41 MiB（+14.92%）；详见[启动结果](PROJECT_REFACTOR_STARTUP_RESULTS.md) |
| 历史性能系列 | [Disk30](PROJECT_REFACTOR_DISK_PERFORMANCE.md) 的 after 保留 `1205c6e`；[UI60/Host11/编辑](PROJECT_REFACTOR_UI_PERFORMANCE.md) 保留 `d328a17` 系列。编辑 before AX 199/204/201 使数值比较 invalid，after 36 动作与读回 / 0 AX 仅作正确性证据 |
| Linux native | [本地环境仍阻塞](<D:/Project/Flutter/sked/.scratch/refactor-20261017/resume-20261017/linux-native-environment/receipt.json>)：Ubuntu 源缺 WPE 开发包；Docker Desktop 后端在初始化时退出，未拉镜像、未运行 Linux Release。四时区和 Chrome 专项不受此影响 |
| 尚未覆盖 | Android 真机按用户约定延期；Windows 安装/同签名升级/WACK、完整辅助技术及 Web 视觉仍有各自边界。未推送、运行远端 CI、部署或发布 |

本轮已完成领域状态与组合根迁移、存储和计算边界、两个工作区投影与缓存、编辑及导入任务、通知分层，以及测试和 CI 精简；后续又修正公历校验、月页日期复用、缺失午夜日界与启动依赖组装。逐项实现和验收来源见[全项目重构实施报告](PROJECT_REFACTOR_REPORT.md)。启动比较包含显式基线适配、外部服务隔离与保留的 OS/字体/shader 缓存，不能写成未修改发布包、磁盘冷启动或真实像素呈现对照。

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

WebView 的 Android、iOS、macOS override 固定了不可变 Git 提交，原因在 [pubspec.yaml](../pubspec.yaml) 注释中。安全存储仍锁定 10.3.1，大版本升级需要真实旧密钥迁移验证。两者均不能仅为消除版本提示而顺手升级，详见 [依赖维护](DEPENDENCY_UPGRADES.md)。

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
| `c286e2c`、`1142cfc` | 增加正常窗口独立进程启动、原生时钟、分阶段 RSS/峰值和启动交互协议；[18 进程结果](PROJECT_REFACTOR_STARTUP_RESULTS.md) 已另表保存 |

这些是各自提交的验证与来源，不相加为全项目总通过数。采集命令见[原生场景入口](../integration_test/README.md)，通过 `capture_scenarios_test.dart` 与 `SKED_CAPTURE_SCENE` 选择组。公开文档的 32 张 JPEG 保持原样，继续使用[文档截图流程](screenshots/README.md)。场景截图不代替行为回归、原生辅助技术或 Profile 采样。

## 7. 继续执行与证据限制

1. **以当前检查点回执交接。** Source、Native、Packages、Android、Linux 四时区/Chrome、Web 和 UI66 的本次结果见上表。[独立只读审计](<D:/Project/Flutter/sked/.scratch/refactor-20261017/resume-20261017/evidence-audit/receipt-and-commit-audit-1142cfce.json>)核对归档哈希及 139 个提交；Source 的 diff-whitespace 只有 exit0 回执，零输出日志未单独落盘。纯文档更新不需要重跑整个矩阵。
2. **保留性能样本的真实版本和代价。** 原始版编辑 AX 使改善比例不可用；新主画布比较仍有长帧/raster/RSS 上升。独立进程启动比较明确包含基线覆盖层、Profile、服务隔离和缓存条件；就绪报告 RSS 不是精确 raster 时刻 RSS，注入输入不是物理鼠标投递。
3. **补齐平台环境后再做相应验收。** Linux native 的 WPE 缺包与 Docker 初始化失败均有回执，尚无 Release 产物；本轮没有升级 Ubuntu、改源或重置 Docker。Android 真机按用户约定延期，设备可用后验证通知、恢复、真实交互和数据升级；完整辅助技术另列为尚未验收。
4. **保留发布边界。** 当前 Windows 两包与 Android APK/AAB 已构建归档；安装、同签名升级、干净机器、WACK/商店认证、远端 CI 与发布仍未执行，见[发布验收](RELEASE_ACCEPTANCE.md)。Web 是 JavaScript Release 构建，未作实际 Wasm 或页面视觉验收。
5. **历史线索不冒充当前缺陷。** 2026-10-07 撤回前的提醒/AI 预览和拖宽跳变记录没有当前复现结论；旧局部/page Overlay 方案已废弃。旧 Windows Chrome 的工具路径适配结果仍属于 `d328a17`，最新浏览器证据来自 Linux。
6. **整批缓存清理仍暂停。** 用户此前接受暂不删除日志、coverage、widget preview 等本地资料；`.scratch` 含隔离源码、构建、包、截图和原始报告。后续清理需重新核对具体路径，不沿用旧大小统计。

## 8. 推荐阅读顺序

1. 本文与[全项目重构实施报告](PROJECT_REFACTOR_REPORT.md)。
2. [长帧结果](PROJECT_REFACTOR_LONG_FRAME_RESULTS.md) → [启动结果](PROJECT_REFACTOR_STARTUP_RESULTS.md) → [历史 UI/Host](PROJECT_REFACTOR_UI_PERFORMANCE.md)／[Disk30](PROJECT_REFACTOR_DISK_PERFORMANCE.md)。
3. [PRODUCT](../PRODUCT.md)／[README](../README.md) → [DESIGN](../DESIGN.md) → [自适应规范](ADAPTIVE_WORKSPACES.md)／[桌面浮层](DESKTOP_FLOATING_PANELS.md)。
4. [可靠性](RELIABILITY_BASELINE.md) → [通知契约](NOTIFICATION_DEDUPLICATION.md) → [依赖维护](DEPENDENCY_UPGRADES.md)。
5. [发布验收](RELEASE_ACCEPTANCE.md) → [Android 通知矩阵](ANDROID_NOTIFICATION_ACCEPTANCE.md) → [更新机制](updates.md)／[Store 指南](microsoft-store.md)。

只更新发生变化的交接状态，不新增按日期命名的重复审查报告；长期约定维护在对应规范中。
