# 原生场景与截图采集

## Agent 原生页面冒烟

`agent_platform_smoke_test.dart` 在原生 Flutter 界面运行真实 Agent 页面、运行时和工具注册表。使用专用模拟器或测试设备，先以 `flutter devices` 确认目标，再运行：

```powershell
flutter test --no-pub -d <device-id> --reporter expanded `
  integration_test/agent_platform_smoke_test.dart
```

入口核对发送、通过实际询问按钮批准后保存一条日程及提醒配置、主库操作回执、关闭/重开页面与切换会话后的独立草稿，以及停止后取消 provider、保持业务数据和显示继续入口。测试等待运行、存储和按钮状态，不用固定延时推断保存完成。
会话选择使用实际桌面侧栏或窄屏抽屉；选择后检查当前会话与输入草稿，抽屉关闭，
桌面侧栏仍可继续选择其他会话。

存储、凭据、模型传输和原生副作用网关均为合成实现；文本使用测试键盘，点击由框架注入。这只证明该原生 Flutter 页面上的业务闭环，不证明真实输入法、系统手势、读屏、进程重启持久化、真实模型或系统通知投递。Android 模拟器与实体设备结果分别记录。

## Agent 正式入口与长历史连续性

`agent_native_journey_test.dart` 从真实 `AppHomeScreen` 的侧边导航进入完整 Agent 页面，
在 Windows 和 Android 都核对向上阅读 → 关闭完整页 → 从侧边导航重开。
入口遵循实际布局；手机先打开主导航抽屉，桌面使用侧栏，必要时滚动到 Agent。
独立的原生进程使用明确合成的主库、聊天、知识、附件、凭据、两类恢复日志、
备份 staging、站点及设备偏好；正式 `AppRuntime`、codec、工具注册表与保存调度
保持接入。该入口没有挂载历史布局预览，也没有替换 Agent 页面或导航 delegate。

固定输入包含一条 512 消息长会话和一条 2 消息对照会话。用例在真实 transcript
上拖动，以实际可见 message ID、消息内归一化位置和渲染文本摘要记录阅读锚点；
流式回复到达时核对草稿、输入选择、焦点和“回到最新”状态。跨宿主后，同一应用、
会话仓库、当前会话与草稿仍在，只发出一次受控 provider 请求。结束后核对原有
512 条消息的完整摘要、新输入和最终回复各一条、实际返回末尾及两条独立草稿。
运行中与跨宿主时要求取消 token 保持未取消；正常收尾也会取消 token 以释放资源，
因此完成后另外核对已保存的运行和单次请求均为完成状态，并保留 token 的实际值。

每个平台分别运行 `baseline`（浅色、1×、普通动态效果）和 `accessible`
（深色、2×、框架 reduced-motion）。配置只作用于框架主题、`TextScaler` 和
motion scope；不修改原生窗口尺寸、DPR 或系统无障碍选项。Windows 必须先有至少
1100×600 逻辑像素的真实窗口；Android 使用已确认的任务专用模拟器。入口拒绝
`flutter_tester` 的 VM 回退，并记录 PID、实际窗口、DPR、运行模式及 Android
API／ABI／QEMU 标志。未知 Android 硬件类型不会自动记作实体设备。

Windows 测试构建先按[原生隔离约定](../docs/WINDOWS_NATIVE_ACCEPTANCE.md)
设置独立的 CMake 命名空间，隔离窗口注册表与再次启动通知；使用已配置构建树中
记录的同一 CMake 可执行文件，不修改生产身份。随后使用专用 driver 保存成功或
失败的完整检查点，例如：

```powershell
$agentNativeOutput = Join-Path ([IO.Path]::GetTempPath()) ('sked-agent-native-' + [guid]::NewGuid().ToString('N'))
$agentNativeRevision = '<full40-source-sha>'
$agentNativePreviousOutput = $env:FLUTTER_TEST_OUTPUTS_DIR
$agentNativePreviousNoProxy = $env:NO_PROXY
flutter build windows --debug --config-only --no-pub `
  --target=integration_test/agent_native_journey_test.dart
if ($LASTEXITCODE -ne 0) { throw 'Windows configuration failed.' }
$agentNativeCmake = (Select-String -LiteralPath build/windows/x64/CMakeCache.txt -Pattern '^CMAKE_COMMAND:INTERNAL=(.+)$').Matches.Groups[1].Value
& $agentNativeCmake -S windows -B build/windows/x64 `
  "-DSKED_WINDOWS_TEST_NAMESPACE=agent-$([guid]::NewGuid().ToString('N'))" `
  -DSKED_BUILD_WINDOWS_RUNNER_TESTS=ON
if ($LASTEXITCODE -ne 0) { throw 'Windows test namespace configuration failed.' }
try {
  $env:FLUTTER_TEST_OUTPUTS_DIR = $agentNativeOutput
  $env:NO_PROXY = '127.0.0.1,localhost'
  flutter drive --no-pub -d windows `
    --driver=test_driver/agent_native_journey_driver.dart `
    --target=integration_test/agent_native_journey_test.dart `
    --dart-define=SKED_AGENT_NATIVE_CONFIG=baseline `
    --dart-define=SKED_AGENT_NATIVE_LABEL=windows-baseline `
    "--dart-define=SKED_AGENT_NATIVE_REVISION=$agentNativeRevision"
  if ($LASTEXITCODE -ne 0) { throw 'Agent native journey failed.' }
} finally {
  $env:FLUTTER_TEST_OUTPUTS_DIR = $agentNativePreviousOutput
  $env:NO_PROXY = $agentNativePreviousNoProxy
}
```

每次更换配置或实际设备 ID 时使用新的输出目录与 label。`SKED_AGENT_NATIVE_REVISION`
必须对应构建输入的完整源码 SHA；隔离归档候选可用
`SKED_AGENT_NATIVE_SOURCE_NOTE` 另记候选树，不能在没有 `.git` 的归档目录推断
当前分支。driver 保存相关源码文件的 SHA-256 清单，标明它是相关源文件清单，
不将它表述为全部受跟踪文件或二进制与源码的一致性证明。

输出为 `agent-native-journey-raw.json` 和
`agent-native-journey-assessment.json`。原始响应和相关源文件清单先保存，随后才
校验 `native-functional` 协议、平台、配置、检查点次序、归档和 provider 计数。
失败保留先前步骤、当前异常与独立清理结果；已有输出不覆盖。卸载页面后停止
未完成合成流、排空运行及仓储，等待 Agent／备份 staging／session 关闭，再排空
主写队列并释放自有偏好。超时或关闭失败都不记为清理成功。

`support/agent_native_session.dart` 的 `AgentNativeSession(provider: ...)` 可为
后续独立功能入口注入其他 scripted `ProviderClient`；`AgentNativeApp` 仍挂载正式
主页。核心 `runAgentNativeJourney` 只使用默认单流 provider，不放宽一次请求断言。
HTTP guard 在独立原生 UI isolate 阻止意外 Dart HTTP 操作；正常空闲 client 的创建
和关闭不算请求，也不把它推广为平台原生网络或其他进程的审计。

这是一条原生 Flutter 功能流程，输入来自框架点击、拖动与测试键盘；不等同于
OS IME、系统返回手势、物理键鼠、读屏或实体设备验收。没有采集引擎帧或 RSS，
不产出 Profile 性能结论。知识、附件、历史重做、选择恢复与原生无障碍由各自
独立入口补齐，不能从本条通过推断全矩阵通过。运行时同时保存命令、退出码和
完整原生日志；AXTree／fatal 错误仍需按失败处理，不能只凭 JSON 的通过字段放行。

## Agent 浏览器协议与存储

`agent_web_probe.dart` 是独立浏览器验收入口，通过正常 Flutter Web 构建注册真实插件。它只接受 localhost、127.0.0.1 和映射到回环地址的 `sked-insecure.test`，请求使用固定合成凭据；不要在正式站点或个人浏览器配置中运行。

```powershell
$agentProbeOutput = Join-Path ([IO.Path]::GetTempPath()) ('sked-agent-web-' + [guid]::NewGuid().ToString('N'))
flutter build web --release --no-web-resources-cdn `
  --target integration_test/agent_web_probe.dart --output $agentProbeOutput
```

在全新浏览器上下文中，以本地 HTTPS 服务加载产物，并用另一源的合成 JSON/SSE 服务调用 `window.skedAgentWebProbe`；入口中的调用示例和 operation 列表定义探针协议。分别验证允许/拒绝 Authorization 预检、没有 CORS 许可时 POST 未发出、HTTPS 到非可信 HTTP 的混合内容拦截、token/订阅取消后服务端观察到流中止，以及重定向未转发敏感请求。

`seedStorage` 后真实刷新页面，再调用 `readStorage`，应看到内存密钥消失而会话双槽保留；随后验证单槽损坏恢复、删除后不复活和较新格式拒读。HTTP 非可信别名用于单独验证安全上下文差异，不能用浏览器将 loopback 视为可信来源的例外假充混合内容检查。临时证书只可在该隔离上下文接受，不关闭 Web 安全策略或修改系统信任库。服务器、驱动脚本、日志和证书放在系统临时目录；浏览器 API 测试不证明任意第三方端点都提供相同 CORS 配置。

附件使用同一探针的 `seedAttachments`、`readAttachments`、`requestAttachment` 和 `deleteAttachments`，在另一份全新配置及独立 origin 中运行。`seedAttachments` 通过实际会话和附件服务保存合成二进制历史消息及 ICS 草稿；驱动必须真正刷新页面后调用 `readAttachments`，再关闭并重新启动同一临时浏览器配置重新读取。每次核对相同的文件 ID、字节数、声明摘要、实际字节摘要、历史与草稿引用，并确认原 `sending` 状态恢复为 `unknown`、读取没有发起 API 请求、二进制不进入 LocalStorage。

`requestAttachment` 显式读取恢复后的 ICS，向驱动提供的本地 Responses 端点发送原生 `input_file`；同时核对浏览器返回和服务端实际收到的字节摘要，不能只检查文件名。最后执行 `deleteAttachments` 并真实刷新，确认会话和最后一个二进制引用都没有复活。这条流程验证正常 Web 插件、SharedPreferences、IndexedDB、页面刷新及浏览器进程重开；文件选择由合成 `XFile` 输入，端点也是本地合成服务，不替代平台文件选择器、真实模型、正式聊天页面或实体设备验收。

独立的 IndexedDB 关闭、重开和事务删除回归位于 `test/agent/attachments/attachment_storage_browser_test.dart`，以 `flutter test --platform chrome` 显式运行。该文件标记为仅浏览器测试；普通 VM 门禁不把它计作已经完成的浏览器验证。

## 界面采集

当前界面采集统一从 `capture_scenarios_test.dart` 选择场景组。场景模块按
功能命名，保留原有交互、数据检查及原生指针保护，不再以历史改版脚本
作为独立入口。每次原生进程只运行一个组，避免不同组注册时的 binding、
焦点和原生指针设置互相影响。

从仓库根目录运行，例如：

```powershell
$captureRoot = Join-Path ([IO.Path]::GetTempPath()) ('sked-workspace-pages-' + [guid]::NewGuid().ToString('N'))
flutter test integration_test/capture_scenarios_test.dart -d windows --no-pub `
  --dart-define=SKED_CAPTURE_SCENE=workspace-pages `
  "--dart-define=SKED_VISUAL_OUTPUT=$captureRoot" `
  --reporter expanded
```

将 `SKED_CAPTURE_SCENE` 替换为表中的一个 ID。省略或拼错 ID 会在采集前
失败并列出可选值；不默认运行全部组。可省略输出参数，各组每次在
系统临时目录创建独立输出，并在日志报告绝对路径；清单见 [输出约定](CAPTURE_OUTPUT.md)。
`floating-panels` 保留分类与查看面板的组合
采集，子组使用各自默认目录；需要统一目录时显式指定 `SKED_VISUAL_OUTPUT`。
为重复采集使用新的输出目录，结合退出码与本次完整场景清单判断成功，
不把旧目录的图片当作新证据。

`editor-layouts` 的日程时间行按实际字体宽度选择同排或上方标签布局。
采集断言检查两种布局中的标签与全天开关对齐、日期时间列对齐及控件
互不覆盖，不将英文原生字体合法触发的换行视为失败。默认浮层图先于
几何断言保存，失败时也能检查对应画面；退出码仍决定该组是否通过。

部分组保留 `SKED_NATIVE_POINTER_CHECK=true`，用于显式运行原生鼠标路径。
这些路径会核对当前测试进程、前台窗口和无遮挡位置；不要删除保护来
绕过环境阻塞。组内模拟 Android 平台、尺寸、安全区或键盘 inset 的
Windows 渲染必须标为模拟布局，不能称为 Android 真机验收。

| 场景 ID | 内容 | 模块 |
| --- | --- | --- |
| `category-panels` | 分类保存中、颜色草稿、双语 RTL、窄窗口与受保护原生拖动 | [category_panels.dart](capture_scenarios/category_panels.dart) |
| `category-manager` | 分类列表、重命名与添加；桌面拖动和模拟触控键盘 | [category_manager.dart](capture_scenarios/category_manager.dart) |
| `modal-chrome` | 模态与窗口边界 | [modal_chrome.dart](capture_scenarios/modal_chrome.dart) |
| `component-gallery` | 共用组件及编辑面板 | [component_gallery.dart](capture_scenarios/component_gallery.dart) |
| `course-details` | 课程详情和长内容布局 | [course_details.dart](capture_scenarios/course_details.dart) |
| `date-navigation` | 日期导航、区间拖动及日期时间表单；可选原生指针 | [date_navigation.dart](capture_scenarios/date_navigation.dart) |
| `date-range-highlights` | 日期区间端点、跨月、键盘焦点与 RTL | [date_range_highlights.dart](capture_scenarios/date_range_highlights.dart) |
| `day-agenda` | 当天安排及详情 | [day_agenda.dart](capture_scenarios/day_agenda.dart) |
| `student-day-agenda` | 课程日视图：1362×768／1920 桌面、320／430 手机模拟、1／2 倍字体及浅深色；真实节次时间、完整与部分冲突、长名称、缺少元信息、空态 | [student_day_agenda.dart](capture_scenarios/student_day_agenda.dart) |
| `desktop-resize` | 桌面布局随窗口变化 | [desktop_resize.dart](capture_scenarios/desktop_resize.dart) |
| `desktop-panels` | 桌面视图面板 | [desktop_panels.dart](capture_scenarios/desktop_panels.dart) |
| `dropdown-focus` | 下拉选择与焦点 | [dropdown_focus.dart](capture_scenarios/dropdown_focus.dart) |
| `floating-panel-anchors` | 浮层锚点和窗口边界 | [floating_panel_anchors.dart](capture_scenarios/floating_panel_anchors.dart) |
| `floating-panels` | 桌面浮层流程 | [floating_panels.dart](capture_scenarios/floating_panels.dart) |
| `event-pickers` | 日程编辑浮层与选择器 | [event_pickers.dart](capture_scenarios/event_pickers.dart) |
| `editor-layouts` | 编辑器自适应宿主 | [editor_layouts.dart](capture_scenarios/editor_layouts.dart) |
| `control-gallery` | 共用控件和视觉密度 | [control_gallery.dart](capture_scenarios/control_gallery.dart) |
| `mobile-calendar-interactions` | 触控日期拖动、实际字形与学生工作区 | [mobile_calendar_interactions.dart](capture_scenarios/mobile_calendar_interactions.dart) |
| `mobile-calendar-grids` | 手机日期、月份和年份选择；语义日期及字号 | [mobile_calendar_grids.dart](capture_scenarios/mobile_calendar_grids.dart) |
| `mobile-home` | 手机主页及区间导航 | [mobile_home.dart](capture_scenarios/mobile_home.dart) |
| `home-typography` | 固定跨年数据；`SKED_VISUAL_GROUP=status` 采集320dp／2×英文课程状态，`range` 采集600dp／2×非紧凑触屏日期标题 | [home_typography.dart](capture_scenarios/home_typography.dart) |
| `adaptive-layout` | 移动布局、安全区、横屏和字号 | [adaptive_layout.dart](capture_scenarios/adaptive_layout.dart) |
| `mobile-picker-surfaces` | 移动选择器呈现 | [mobile_picker_surfaces.dart](capture_scenarios/mobile_picker_surfaces.dart) |
| `mobile-secondary-pickers` | 移动次级选择器 | [mobile_secondary_pickers.dart](capture_scenarios/mobile_secondary_pickers.dart) |
| `mobile-tasks` | 移动端编辑任务 | [mobile_tasks.dart](capture_scenarios/mobile_tasks.dart) |
| `mobile-ui-fixes` | 日期内边距、课表切换、设置标题、提醒控件及月历按压 | [mobile_ui_fixes.dart](capture_scenarios/mobile_ui_fixes.dart) |
| `m3-expressive-controls` | 日期与周次状态反馈、键盘调色、可读滑块进度及静态加载 | [m3_expressive_controls.dart](capture_scenarios/m3_expressive_controls.dart) |
| `school-sites-mobile` | 学校单站点初始状态、短名与长链接、独立编辑、模拟 IME、返回与取消草稿、20 条列表滚动折叠；320 英文 2 倍、360／393 中文、800 横屏及 1280 桌面共 54 张 | [school_sites_mobile.dart](capture_scenarios/school_sites_mobile.dart) |
| `panel-headings` | 面板标题及内容起点 | [panel_headings.dart](capture_scenarios/panel_headings.dart) |
| `period-time-sets` | 节次时间组管理 | [period_time_sets.dart](capture_scenarios/period_time_sets.dart) |
| `period-times-editor` | 节次编辑 | [period_times_editor.dart](capture_scenarios/period_times_editor.dart) |
| `reminder-hover` | 提醒悬浮详情 | [reminder_hover.dart](capture_scenarios/reminder_hover.dart) |
| `reminder-summary` | 提醒摘要与浮层 | [reminder_summary.dart](capture_scenarios/reminder_summary.dart) |
| `settings-layout` | 设置分组与自适应布局 | [settings_layout.dart](capture_scenarios/settings_layout.dart) |
| `settings-transfer` | 设置与导入导出呈现 | [settings_transfer.dart](capture_scenarios/settings_transfer.dart) |
| `student-resources` | 学生工作区资源菜单 | [student_resources.dart](capture_scenarios/student_resources.dart) |
| `theme-tasks` | 主题编辑任务 | [theme_tasks.dart](capture_scenarios/theme_tasks.dart) |
| `teaching-weeks` | 教学周选择、键盘与大字号 | [teaching_weeks.dart](capture_scenarios/teaching_weeks.dart) |
| `compact-toolbars` | 紧凑 Windows 工具栏 | [compact_toolbars.dart](capture_scenarios/compact_toolbars.dart) |
| `workspace-chrome` | 工作区工具栏及反馈 | [workspace_chrome.dart](capture_scenarios/workspace_chrome.dart) |
| `workspace-editor` | 工作区编辑流程 | [workspace_editor.dart](capture_scenarios/workspace_editor.dart) |
| `workspace-pages` | 学生与通用工作区主要页面 | [workspace_pages.dart](capture_scenarios/workspace_pages.dart) |

## 采集与行为回归的区别

截图用于审查实际字体、像素、溢出、层次和状态呈现。组中的行为断言
保证所拍场景已真正打开，但截图采集本身不能代替完整行为回归。
日常回归仍运行 `test/`；存储恢复、通知防重、保存竞争、重复日程和
草稿生命周期的保护不依赖截图数量或历史组件树。

`home-typography` 每次只采集一个子组并生成一张图。清单的`observations`
记录原生段落宽高、最大行数、实际截断、缺失字形和拉丁词自然宽度及
所跨行位置，用于固定协议下的前后比较。已知基线问题仍允许保存画面；
退出成功表示场景与点击／取消断言通过，不表示观测文字全部可读。
课程组使用实际英文“Off week”，不替换成虚构长词；日期组固定为
2026-12-29至2027-01-04，并确认没有进入紧凑工具栏分支。

独立原生行为入口保留：`data_lifecycle_smoke_test.dart` 使用隔离目录验证
编辑、重新加载和恢复；`notification_queue_native_test.dart` 验证平台队列；
`startup_window_drag_test.dart` 验证原生标题栏拖动；学校 WebView 导航由
`school_web_import_webview_redirect_test.dart` 验证。它们不作为截图分组。

公开文档图片继续使用 [文档截图流程](../docs/screenshots/README.md) 中的
`documentation_screenshots_test.dart` 和导出工具。现有 32 张发布图片及其
历史 provenance 不随采集入口调整而重写。

性能数据使用 [UI Profile 基准](../benchmark/UI_PERFORMANCE.md) 与
[纯数据基准](../benchmark/README.md)。调试截图、模拟设备布局及行为
通过数都不是 Profile 帧耗时或真机性能证据。

## Windows 原生行为审计

以下入口使用隔离数据目录。每次运行先在仓库根目录执行公共准备，
为本次结果创建新的系统临时子目录：

```powershell
$auditProjectRoot = (Resolve-Path .).Path
$auditFlutterCommand = Get-Command flutter -ErrorAction Stop
$auditFlutterRoot = Split-Path (Split-Path $auditFlutterCommand.Source -Parent) -Parent
$auditOutput = Join-Path ([IO.Path]::GetTempPath()) ('sked-native-audit-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $auditOutput | Out-Null
```

`audit_native_gate_test.dart` 使用真实子进程持有 Windows 文件锁，验证
锁占用时重试仍被阻止，以及释放后通过一次鼠标或键盘重试完成启动：

```powershell
$auditGateData = Join-Path $auditOutput 'gate'
flutter test integration_test/audit_native_gate_test.dart -d windows --no-pub `
  "--dart-define=SKED_AUDIT_NATIVE_GATE_DATA=$auditGateData" `
  "--dart-define=SKED_AUDIT_FLUTTER_ROOT=$auditFlutterRoot" `
  "--dart-define=SKED_AUDIT_PROJECT_ROOT=$auditProjectRoot" `
  --reporter expanded
```

`audit_native_workflows_test.dart` 验证课程和日程表单、悬浮与工作区切换，
再通过第二次独立原生进程读取同一隔离目录，检查持久化结果。先运行
`exercise`；确认退出码为 0 后，再运行 `read`：

课程和日程各执行 10 轮创建，再分别编辑一次；`read` 核对完整工作区
快照和保存实体数量。样例以运行当天生成，日志记录关键步骤，结果
JSON 记录进程 ID 和生命周期状态。帧等待、加载和工作区切换均设置
限时，异常清理保留最初的错误。

```powershell
$auditWorkflowData = Join-Path $auditOutput 'workflows'
flutter test integration_test/audit_native_workflows_test.dart -d windows --no-pub `
  "--dart-define=SKED_AUDIT_NATIVE_DATA=$auditWorkflowData" `
  --dart-define=SKED_AUDIT_NATIVE_PHASE=exercise `
  --reporter expanded
```

```powershell
flutter test integration_test/audit_native_workflows_test.dart -d windows --no-pub `
  "--dart-define=SKED_AUDIT_NATIVE_DATA=$auditWorkflowData" `
  --dart-define=SKED_AUDIT_NATIVE_PHASE=read `
  --reporter expanded
```

Gate 的锁竞争来自真实 Windows 子进程，workflows 使用实际隔离文件存储。
两项测试的鼠标、键盘和悬浮事件均由 Flutter 测试绑定分发，不属于
OS SendInput 或物理键鼠验收。结果 JSON 写入上述本次输出目录；结合
各次进程退出码检查结果，不复用旧目录中的证据。
