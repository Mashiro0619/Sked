# 原生场景与截图采集

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
失败并列出可选值；不默认运行全部组。可省略输出参数，已迁移组每次在
系统临时目录创建独立输出，并在日志报告绝对路径；清单见 [输出约定](CAPTURE_OUTPUT.md)。
其余组在完成各自迁移前保留原默认位置。`floating-panels` 保留分类与查看面板的组合
采集，子组使用各自默认目录；需要统一目录时显式指定 `SKED_VISUAL_OUTPUT`。
为重复采集使用新的输出目录，结合退出码与本次完整场景清单判断成功，
不把旧目录的图片当作新证据。

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
为本次结果创建新的 `.scratch` 子目录：

```powershell
$auditProjectRoot = (Resolve-Path .).Path
$auditFlutterCommand = Get-Command flutter -ErrorAction Stop
$auditFlutterRoot = Split-Path (Split-Path $auditFlutterCommand.Source -Parent) -Parent
$auditOutput = Join-Path $auditProjectRoot ('.scratch/native-audit-' + [guid]::NewGuid().ToString('N'))
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
