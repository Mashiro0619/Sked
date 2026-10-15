# Sked 项目交接

交接日期：2026-10-07（Asia/Shanghai）。本文件是当前代码与工作区的交接快照；接手时先核对 Git 状态，长期规则以本文链接的维护文档及当前实现为准。

## 1. 当前状态与接手边界

| 项目 | 本次核实结果 |
| --- | --- |
| 工作目录 | `D:\Project\Flutter\sked` |
| 分支 | `main` |
| HEAD | `ae5690b2a4d376542c5922a14b7d3c688626ebc4` |
| 最新提交 | `fix(更新设置): 恢复默认接收预发布版本` |
| 应用版本 | `pubspec.yaml` 为 `2.3.0-rc.2+16`；版本号不表示 HEAD 等同于发布标签 |
| 工作区 | 有未提交的文档整理；应用实现、测试和依赖文件没有已跟踪差异 |
| 本次验证 | 已核对代码入口、配置、文档引用和 Git 差异；未重新运行 Flutter 测试、构建、设备验收或远端 CI |

最近提交已包含更新渠道统一、启动更新检查、更新弹窗及默认接收预发布更新等变化。当前远端发布、商店状态和 HEAD 对应 CI 结果本轮没有查询，应按实际任务重新核实。

**不要继续执行已经撤销的“Sked 2.3.0 完整体验优化最终计划”。** 该计划中的六类设置重组、紧凑启动提醒摘要、空日程引导、共享浮层描边和双面板预算修复及配套测试已撤回。当前设置目录最多七组，停用工作区会减少可见分组，以 [settings_catalog.dart](../lib/models/settings_catalog.dart) 为准。不要把旧会话的“4257 项通过”用于证明撤回后的代码通过。

用户要求对前提保持批判性：先核对实际实现和证据，发现错误假设应直接指出。当前任务只生成交接文档，没有授权恢复旧计划、提交、推送或发布。

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
| Flutter | `>=3.47.0`；CI 固定 stable `3.47.0` |
| Dart | `^3.13.0` |
| 状态管理 | `provider`，主要业务状态由 `TimetableProvider` 管理 |
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

以上是接手运行方式，本次没有执行。运行应用前确认测试环境和数据位置；不要用真实用户存档做破坏性验证。不要提交本机签名文件、密钥或生成缓存。

WebView 的 Android、iOS、macOS override 固定了不可变 Git 提交，原因在 [pubspec.yaml](../pubspec.yaml) 注释中。安全存储仍锁定 10.3.1，大版本升级需要真实旧密钥迁移验证。两者均不能仅为消除版本提示而顺手升级，详见 [依赖维护](DEPENDENCY_UPGRADES.md)。

## 4. 架构与代码入口

主要数据流：界面操作 → Provider／领域服务 → AppRepository 串行持久化 → 已提交快照 → 通知协调与平台投影。

| 领域 | 入口及职责 |
| --- | --- |
| 启动与生命周期 | [main.dart](../lib/main.dart)：`AppBootstrap` 获取实例租约、加载 Provider；`MyApp` 接入通知协调和应用壳，显式退出等待保存 |
| 业务状态 | [timetable_provider.dart](../lib/providers/timetable_provider.dart)：工作区、课表、日程、设置、事务和提交状态；阅读相关 part 文件，不只看主文件 |
| 数据模型 | [models](../lib/models)：`AppData`、课表、日程、设置、工作区；[重复实例展开](../lib/models/general_event_occurrence.dart) 管理重复日程计算 |
| 持久化 | [app_repository.dart](../lib/data/app_repository.dart)：串行写入、内存与已提交快照、失败门禁；[timetable_storage.dart](../lib/data/timetable_storage.dart) 连接平台存储与恢复 |
| 通知 | [agenda_coordinator.dart](../lib/services/agenda_coordinator.dart)：消费 `committedData`；[agenda_notification_service.dart](../lib/services/agenda_notification_service.dart) 与 [runtime store](../lib/services/agenda_notification_runtime_store.dart) 管理排程和登记证据 |
| 主界面与布局 | [app_home_screen.dart](../lib/screens/app_home_screen.dart)、[workspace_frame.dart](../lib/widgets/workspace_frame.dart)、[workbench_layout_policy.dart](../lib/widgets/workbench_layout_policy.dart) |
| 浮层、表单会话 | [sked_task_session.dart](../lib/widgets/sked_task_session.dart)、[sked_task_route.dart](../lib/widgets/sked_task_route.dart)、[sked_task_submission_controller.dart](../lib/widgets/sked_task_submission_controller.dart) |
| 设置 | [settings_page.dart](../lib/screens/settings_page.dart)、[settings_catalog.dart](../lib/models/settings_catalog.dart)、[adaptive_settings_scaffold.dart](../lib/widgets/adaptive_settings_scaffold.dart) |
| 导入与密钥 | [school_import_workflow.dart](../lib/services/school_import_workflow.dart)、[secret_store.dart](../lib/services/secret_store.dart) |
| 更新 | [update_service.dart](../lib/services/update_service.dart)、[update_prompt_scope.dart](../lib/widgets/update_prompt_scope.dart)；渠道规则见 [updates.md](updates.md) |
| 本地化与主题 | [lib/l10n](../lib/l10n)、[lib/theme](../lib/theme)；修改 ARB 后生成，保留用户精确色值 |
| 工具与 CI | [tool](../tool)、[flutter.yml](../.github/workflows/flutter.yml)：覆盖率、产物安全检查、MSIX、截图导出 |

必须保留的边界：

- AppData 顶层格式为 v4。恢复、未来版本和 I/O 不确定状态遵循写入门禁，不能绕过门禁强行保存。
- 通知依据已持久化快照，不投影 UI 乐观状态；锁顺序、登记凭据、代际隔离和稍后提醒语义不能靠新增超时或清空记录规避。
- 工作区停用保留数据和配置，停止对应运行时工作；停用、活动工作区和导航可见性是三个独立概念。
- API Key 不进入普通 AppData／备份；HTTP 端点发送前确认，错误输出脱敏，保留重定向防护。
- 关闭、切换和异步返回必须尊重草稿、忙碌状态和会话有效性，不能盲目 pop 当前路由。
- 桌面浮层与触控 sheet/dialog 按宿主规则工作；视觉整理不应改变持久化、权限或模态保护。

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

普通全量测试不能替代 Linux Chrome 实例租约和纽约／柏林／上海时区专项。覆盖率需使用同平台基准与当前提交，门禁参数以 CI 为准，不把历史 LCOV 当作当前证明。

构建入口：

```powershell
flutter build apk --release
flutter build appbundle --release --dart-define=SKED_DISTRIBUTION_CHANNEL=google-play
flutter build windows --release
pwsh -NoProfile -File tool/build_msix.ps1 -Store
```

构建不是发布。Android 签名、包类型与升级验证独立核对；Windows 分发完整运行目录。Store 包与站外包使用不同身份和版本映射，见 [Microsoft Store 指南](microsoft-store.md)。Debug／原生测试后构建 Release 保留正常 Flutter 插件准备流程，避免用 `--no-pub` 复用错误注册器；不要并发构建并改写同一工作区的生成文件。

## 6. 本轮已完成与未提交改动

撤销优化计划后，本轮只整理项目文档与一次性审查资料：

| Git 状态 | 文件与处理 |
| --- | --- |
| 删除 | 根目录旧代码审查报告；原工作台修订过程文档 |
| 修改 | `ADAPTIVE_WORKSPACES.md`：改为当前规范；`DEPENDENCY_UPGRADES.md`：改为依赖维护指南；`RELIABILITY_BASELINE.md`：改为可靠性指南；`NOTIFICATION_DEDUPLICATION.md`：修正旧引用 |
| 新增 | [RELEASE_ACCEPTANCE.md](RELEASE_ACCEPTANCE.md)：集中通用发布验收与遗留项；本交接文档也是新增文件 |
| 本地未跟踪／忽略资料删除 | 旧视觉审查报告、15 个 `release_230_*.dart` 采集脚本、Alpha 与 RC.2 的一次性检查清单；这些删除不会全部显示在 Git diff 中 |

整理前后的 45 个本地文档链接检查与 `git diff --check` 已通过；没有重跑应用测试。上述改动未提交、未暂存、未推送。接手时审查当前 diff，不用全量 restore 丢弃这批整理。

正式发布说明、公开截图、产品／设计文档、长期回归测试及 `.scratch` 均保留。历史采集脚本已删除，重新截图应使用 [文档截图流程](screenshots/README.md) 及现存 `documentation_screenshots_test.dart`，不能继续引用删除的审查入口。

## 7. 待接手事项与证据限制

1. **先确认下一项开发目标。** 用户已撤销上一轮体验计划，没有新的功能实施授权；不要自行恢复六类设置或其他撤回改动。
2. **整理提交尚待处理。** 审查本轮文档 diff 与交接文件，再按后续指示提交。提交时只纳入本次相关文件，遵循仓库中文提交习惯。
3. **发布验收仍需真实证据。** Android 键盘／返回／安全区／厂商 WebView／通知后台行为、同签名升级、Windows 干净环境与原生浮窗、商店认证等见 [发布验收](RELEASE_ACCEPTANCE.md)；本轮没有重新查询设备连接或认证状态。
4. **UI 历史回归线索尚未复核。** 撤回前审查曾复现“启动提醒与 AI 预览共存、拖宽跨阈值时画布跳变”；相关修复已随计划撤回，撤回后没有重新测试。若后续任务涉及此处，应先按当前代码复现，不将其列为已修复，也不据此推断默认主流程普遍损坏。
5. **公开截图待更新。** README 手机图和 2026-09-29 的 Windows 大屏图仍是旧快照；Windows 模拟 Android 尺寸不能标为 Android 真机证据。
6. **缓存清理已暂停。** 根目录日志、coverage、widget preview、误建目录等因执行工具拒绝删除而保留，工具只返回 `blocked by policy`。用户随后明确接受暂不删除，不要把继续清理或反复请求确认设为接手前置条件。`.scratch` 曾盘点约 20 GB，混有源码副本、构建和发布包、截图与日志；该大小会变化，后续若另行授权清理需重新盘点。

## 8. 推荐阅读顺序

1. 本文的当前状态与未提交改动。
2. [PRODUCT](../PRODUCT.md) → [README](../README.md)：产品能力与平台边界。
3. [DESIGN](../DESIGN.md) → [自适应规范](ADAPTIVE_WORKSPACES.md) → [桌面浮层](DESKTOP_FLOATING_PANELS.md)：界面任务与生命周期。
4. [可靠性](RELIABILITY_BASELINE.md) → [通知契约](NOTIFICATION_DEDUPLICATION.md) → [依赖维护](DEPENDENCY_UPGRADES.md)：数据、平台和升级限制。
5. [发布验收](RELEASE_ACCEPTANCE.md) → [Android 通知矩阵](ANDROID_NOTIFICATION_ACCEPTANCE.md) → [更新机制](updates.md)／[Store 指南](microsoft-store.md)。

接手后只更新本文件中发生变化的交接状态，不再新增按日期命名的重复审查报告；长期约定更新到对应规范中。
