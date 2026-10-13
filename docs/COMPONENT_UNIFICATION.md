# 同类组件与任务入口清单

本文维护应用组件的复用边界和真实入口，不记录某次运行的测试计数。组件完成迁移后，仍需按下方矩阵核对用户操作与视觉表现。

## 共同约定

- 触屏底部任务使用普通标题，默认隐藏顶部拖动提示条及其占位，保留正文下拉关闭。编辑正文采用课程编辑器的字段、分区和主次操作样式；短表单按内容收紧，长表单保留正文滚动及固定操作区。
- `SkedTaskHeader`、`SkedTaskBody` 与 `SkedActionArea` 负责标题、滚动正文和操作排列。业务组件提供内容、回调和禁用状态，不再复制整套间距、字体和窄屏换行逻辑。
- `AppSheetScaffold.editor` 负责编辑任务的公共呈现；`WorkspaceEditorScaffold` 保留桌面浮动／停靠宿主的几何、焦点、拖动与缩放。根通知入口和独立页面中的编辑器也使用公共内容样式。
- 下拉、Back、关闭和取消共用草稿退出策略。`EditorExitGuard` 判断草稿是否改变；`SkedGuardedBottomSheetRoute` 遵守任务的退出门禁。保存、恢复或子任务进行中不能靠拖拽绕过保护；成功提交通过 `completeSkedTaskRoute` 完成本任务。
- `SkedEditorTextField`、`SkedEditorValueField`、`SkedEditorChoiceField` 根据输入平台提供触屏或桌面密度。业务仍持有 controller、校验、选择值、锚点和提交逻辑。
- 课程提醒的模式／自定义分钟和日程重复的间隔／单位／次数／结束日期也使用公共字段。`SkedEditorOption` 负责星期和重复／提醒选项的选中样式；星期短名称、间隔边界和提醒默认值仍由业务提供。
- `SkedTaskBody.status` 是正文之外的固定状态槽，仅忙碌时占位。`SkedTaskDialog.contentOwnsScroll` 将有界空间交给惰性列表，标题可以独立滚动；普通内容使用 `scrollable`，不能把惰性列表嵌入需要固有尺寸的滚动内容。
- 所有普通决策对话框通过 `SkedConfirmationDialog` 呈现。该组件不替调用者决定默认答案、写入时机或同意策略；异步危险操作继续使用 `SkedMutationConfirmationDialog` 的提交门禁。

## 家族与入口

| 家族 | 公共组件 | 必须覆盖的入口 |
| --- | --- | --- |
| 课表、课程、日程编辑 | `AppSheetScaffold.editor`、`SkedEditorActions`、公共字段 | 资源侧栏、课表切换列表、空状态新增、顶栏／溢出菜单、日历空白入口、详情编辑、提醒与根通知打开的编辑器。核心入口见 [课表管理](../lib/screens/home_screen_timetable_management.dart)、[课程入口](../lib/screens/home_screen_course_actions.dart)、[日程主页](../lib/screens/general_schedule_home_screen.dart)、[通知入口](../lib/main.dart)。 |
| 短名称与站点编辑 | 公共字段和操作、`SkedTaskDialog`／编辑表壳 | 分类新增／重命名；学校站点新增／修改与网页地址编辑。保留站点列表在宽窗双栏、窄窗覆盖之间重排时的稳定 Navigator、草稿与焦点。见 [分类管理](../lib/screens/general_schedule_calendar_manager.dart)、[学校站点](../lib/screens/school_sites_page.dart)、[学校网页](../lib/screens/school_web_import_page.dart)。 |
| 导入复核与配置 | 公共文本／选择字段、`SkedDetailRow`、公共编辑表壳与自定义固定 footer | HTML 导入后的复核、解析页面的直接新增／替换、开始日期、总周数、节次方案、结果重新编辑。新增／替换／取消及恢复反馈保留各自含义。见 [复核 sheet](../lib/widgets/school_web_import_result_sheet.dart)、[解析页面](../lib/screens/school_import_parse_page.dart)。 |
| 详情与属性 | `WorkspaceViewPanel`、`SkedTaskHeader`、`SkedTaskBody`、`SkedDetailRow/Group` | 课程、日程、提醒、当天安排、更多日程及导入摘要。保留查看面板、悬停预览、独立详情和普通模态的生命周期差异；内容滚动不带走必要操作。见 [课程详情](../lib/widgets/course_details_sheet.dart)、[日程详情](../lib/widgets/general_event_details_sheet.dart)、[独立详情宿主](../lib/screens/general_event_list_details_host.dart)。 |
| 选择和子配置 | `ExpressiveDialogOption`、`SkedTaskDialog`、`SkedPickerActions`、现有自适应 picker | 语言、课表、节次集、课程星期／周次／节次、日程重复／提醒、编辑范围、日期／时间／颜色。选择确认只更新父草稿；立即提交的选择仍按原流程完成。见 [语言](../lib/screens/language_settings_page.dart)、[节次选择](../lib/widgets/period_time_set_picker_dialog.dart)。 |
| 设置与数据传输动作 | `SettingsConnectedGroup/Tile`、`SettingsSwitchTile`、`SettingsSliderTile`、`SettingsChoiceTile`、公共任务头 | 外观、语言、通知、学生／通用偏好、解析设置、工作区功能、开发设置、备份与各业务导入导出。页面和底部动作 sheet 复用同一传输行；长说明完整换行。见 [设置基础](../lib/widgets/settings_list.dart)、[传输入口](../lib/screens/settings_data_transfer_controller.dart)。 |
| 管理集合 | `AdaptiveCollectionScaffold`、公共选择行、`CalendarVisibilityButton`、`CalendarManagementMenu` | 节次时间集、课表资源、分类和学校站点。多动作行保留每个按钮的焦点、语义与禁用状态，不把可见性切换和重命名合并成一个动作。 |
| 确认、退出及恢复 | `SkedConfirmationDialog`、`SkedDiscardDraftDialog`、`SkedMutationConfirmationDialog` | 删除、覆盖导入、备份恢复、清除数据、停用工作区、放弃草稿、隐私入口、HTTP 同意、恢复资料列表、导出权限／路径问题。检查所有 `showDialog`／`showExpressiveDialog` 调用的任务所有权和关闭对象。 |
| 菜单与通用动作 | `SkedPopupMenuButton`、`SkedActionArea`、`SkedEditorActions` | 顶栏与紧凑溢出、管理行、详情次操作、编辑取消／保存／删除、导入复核 footer、更新操作。菜单保留原有锚点、键盘与嵌套任务保护。 |
| 加载、失败与空状态 | `UiCommandBusyIndicator`、`UiCommandFeedbackHost`、`ExpressiveEmptyState` | 页面加载、保存、异步管理操作、无数据和可重试错误。存储恢复的 `SchoolImportSaveFeedback`、自动保存状态和解析进度继续表达业务状态，不替换成笼统的成功／失败提示。 |

## 逐入口与回归对应

下表按生产调用点核对接入，不把独立组件示例视为用户入口。平台列描述应适用的呈现；测试列给出真实操作或公共契约的证据位置，执行结果以本轮验收日志为准。同行入口汇入同一个业务编辑器时，业务目标和关闭所有权仍分别验证。

| 真实入口 | 接入组件与保留的业务规则 | 平台 | 回归位置与检查点 |
| --- | --- | --- | --- |
| 课表空状态“新建”、课表切换列表“新建”、资源栏新增 | [课表管理](../lib/screens/home_screen_timetable_management.dart) → `TimetableInformationDialogSurface` → `AppSheetScaffold.editor`；提交前不创建占位课表 | 手机、平板、桌面 | [home_screen_timetable_management_test](../test/widgets/home_screen_timetable_management_test.dart)：空状态和切换列表只打开一份草稿、校验／失败重试／选择节次集后保存 |
| 切换列表的课表编辑、资源栏课表编辑 | 同一课表表单、`SkedEditorActions` 和公共字段；保留删除最后一份课表及当前课表切换规则 | 触屏、浮窗／并排 | [shared_editor_contract_test](../test/widgets/shared_editor_contract_test.dart)、[timetable_information_sheet_layout_test](../test/widgets/timetable_information_sheet_layout_test.dart)：唯一标题、固定操作区、正文与键盘；[home_screen_timetable_management_test](../test/widgets/home_screen_timetable_management_test.dart)：删除失败／晚完成不关闭新任务 |
| 课程新增按钮、顶栏／紧凑入口、网格长按空白节次 | [课程入口](../lib/screens/home_screen_course_actions.dart) → `CourseEditorSheet`；保留初始星期／节次／周次 | 触屏、桌面 | [mobile_task_sheets_test](../test/widgets/mobile_task_sheets_test.dart)、[windows_compact_toolbar_actions_test](../test/widgets/windows_compact_toolbar_actions_test.dart)、[course_editor_sheet_test](../test/widgets/course_editor_sheet_test.dart)：真实新增入口、草稿与默认值 |
| 课程块详情中的“编辑” | `CourseDetailsSheet` → 公共编辑表壳；详情动作与子选择器继续绑定所属任务 | 手机、桌面查看面板 | [course_details_sheet_test](../test/widgets/course_details_sheet_test.dart)、[mobile_task_sheets_test](../test/widgets/mobile_task_sheets_test.dart)：详情编辑、失败重试、子选择器不被父关闭误关 |
| 日程新增按钮、顶栏／紧凑入口、时间轴空白／月历新增 | [日程主页](../lib/screens/general_schedule_home_screen.dart) → `GeneralEventEditorSheet`；保留初始日期、时间和分类 | 触屏、桌面 | [shared_editor_contract_test](../test/widgets/shared_editor_contract_test.dart)、[general_schedule_creation_test](../test/widgets/general_schedule_creation_test.dart)、[windows_compact_toolbar_actions_test](../test/widgets/windows_compact_toolbar_actions_test.dart)：正确草稿目标、公共字段与操作 |
| 日程详情中的编辑／重复范围编辑 | `GeneralEventDetailsSheet`、编辑范围确认与公共编辑表壳；单次／后续／全部范围保持原语义 | 手机、桌面查看／独立面板 | [general_event_details_sheet_test](../test/widgets/general_event_details_sheet_test.dart)、[general_event_policy_ui_test](../test/widgets/general_event_policy_ui_test.dart)、[general_schedule_editor_delete_test](../test/widgets/general_schedule_editor_delete_test.dart) |
| Android 通知／小组件唤起课程或日程，再进入编辑 | [main.dart](../lib/main.dart) 的实际平台 channel → 详情 → 编辑器；无 `WorkspaceEditorScope` 时仍使用公共组件 | Android 手机、平板宽度 | [agenda_task_entrypoints_test](../test/widgets/agenda_task_entrypoints_test.dart)：两种业务 × 两种尺寸，目标内容、单一表壳、脏稿放弃且原数据不变 |
| 分类资源栏新增、分类管理新增／重命名、行更多菜单重命名 | [分类管理](../lib/screens/general_schedule_calendar_manager.dart) → `SkedTaskDialog`、公共名称字段与编辑操作；子任务取消恢复父列表位置 | 触屏、桌面浮窗 | [category_manager_dialog_test](../test/widgets/category_manager_dialog_test.dart)、[category_manager_panel_test](../test/widgets/category_manager_panel_test.dart)：空白草稿、1 次提交、失效目标、键盘／缩放与父子任务保护 |
| 分类行的可见性／颜色／更多删除 | `CalendarVisibilityButton`、公共颜色选择和 `CalendarManagementMenu`；多动作保留独立焦点与禁用状态 | 触屏、桌面 | [calendar_management_actions_test](../test/widgets/calendar_management_actions_test.dart)、[category_manager_panel_test](../test/widgets/category_manager_panel_test.dart)：显示状态回滚、颜色取消、删除失败重试 |
| 学校站点新增、站点行编辑、空状态新增 | [学校站点](../lib/screens/school_sites_page.dart) → `AppSheetScaffold.editor`、公共名称／URL 字段；稳定的嵌套 Navigator 保留草稿 | 窄覆盖、宽双栏、旋转 | [school_sites_page_test](../test/widgets/school_sites_page_test.dart)：宽窄转换、URL 校验、失败草稿、重复点击与恢复资料 |
| 学校网页地址编辑、返回导入流程 | [学校网页](../lib/screens/school_web_import_page.dart) → 公共输入／确认；保留 URL 校验、HTTP 同意和网页退出规则 | 触屏、桌面 | [school_web_import_page_test](../test/widgets/school_web_import_page_test.dart)、[school_import_persistence_flow_test](../test/widgets/school_import_persistence_flow_test.dart)：网页子任务、取消放弃和恢复边界 |
| HTML／文本解析后的导入复核 | [SchoolWebImportResultSheet](../lib/widgets/school_web_import_result_sheet.dart) → 公共编辑表壳、字段、属性行和自定义 footer；新增／替换仍是不同操作 | 手机、桌面浮窗／并排 | [school_web_import_result_sheet_test](../test/widgets/school_web_import_result_sheet_test.dart)、[school_preview_exit_guard_test](../test/widgets/school_preview_exit_guard_test.dart)：subtitle／footer 透传、键盘、拖拽守卫、失败重试和重复提交 |
| 解析页面直接新增／替换、配置重编辑 | [school_import_parse_page](../lib/screens/school_import_parse_page.dart) 使用公共字段／摘要／动作；保留解析进度、恢复反馈和周数告警 | 触屏、桌面 | [school_import_parse_page_test](../test/widgets/school_import_parse_page_test.dart)、[school_import_parse_page_stream_test](../test/widgets/school_import_parse_page_stream_test.dart)、[school_import_persistence_flow_test](../test/widgets/school_import_persistence_flow_test.dart) |
| 课程／日程详情、详情独立打开 | `WorkspaceViewPanel`／`SkedTaskBody`、`SkedDetailRow/Group`；悬停、独立窗口及任务面板保留各自生命周期 | 手机、桌面 | [course_details_spacing_test](../test/widgets/course_details_spacing_test.dart)、[general_event_details_sheet_test](../test/widgets/general_event_details_sheet_test.dart)、[desktop_view_panels_test](../test/widgets/desktop_view_panels_test.dart)：属性对齐、固定忙碌状态、必要动作可达 |
| 提醒列表、当天安排、月历更多日程中的条目 | [日程详情宿主](../lib/screens/general_event_list_details_host.dart) 复用同一详情内容；来源预览升级独立详情后保留元素／滚动与正确目标 | 手机列表、桌面固定／浮动面板 | [day_agenda_details_test](../test/widgets/day_agenda_details_test.dart)、[reminder_companion_details_test](../test/widgets/reminder_companion_details_test.dart)、[reminder_independent_safety_test](../test/widgets/reminder_independent_safety_test.dart)：跨来源、缩放、来源关闭、编辑和删除失败 |
| 课表导航周次、课程星期／周次／节次选择 | `showSkedWeekPicker`、`SkedTaskDialog`、`SkedEditorOption` 与多选控件；父草稿只在子确认时更新 | 触屏、桌面锚定选择器 | [sked_week_picker_test](../test/widgets/sked_week_picker_test.dart)、[desktop_secondary_pickers_test](../test/widgets/desktop_secondary_pickers_test.dart)、[course_editor_sheet_test](../test/widgets/course_editor_sheet_test.dart)：键盘、选中语义、取消和父草稿 |
| 课表编辑／导入复核的节次集选择，选择器内新增／编辑／管理 | `SkedTaskDialog.contentOwnsScroll`、公共选项与动作；有界惰性列表保留自身滚动 | 窄手机、平板、桌面 | [period_time_set_picker_dialog_test](../test/widgets/period_time_set_picker_dialog_test.dart)、[period_time_set_manager_navigation_test](../test/widgets/period_time_set_manager_navigation_test.dart)、[floating_resize_scrollbar_test](../test/widgets/floating_resize_scrollbar_test.dart)：长语言／大字号、48dp 触摸目标、滚动与缩放命中区 |
| 课程系统提醒：继承／关闭／自定义提前分钟 | `SkedEditorChoiceField`／`SkedEditorTextField`；保留学生工作区所有权、权限读取和父草稿回调，选择不调度通知 | Android、Windows；普通／大字号 | [course_system_reminder_field_test](../test/widgets/course_system_reminder_field_test.dart)：公共控件、禁用后的旧回调、权限失败重试、不发送通知 |
| 日程重复、间隔／单位／次数／结束日期，日程提醒模式／预设 | `SkedTaskDialog`、公共字段与 `SkedEditorOption`；间隔 1–999、次数校验和导入的自定义提醒值保留 | 触屏、桌面浮窗 | [general_event_editor_sheet_test](../test/widgets/general_event_editor_sheet_test.dart)、[general_event_floating_pickers_test](../test/widgets/general_event_floating_pickers_test.dart)：父草稿确认、结束日期嵌套、失败重试和间隔边界 |
| 日期、时间、颜色子配置 | 现有 `SkedDatePicker`、`SkedTimePicker`、颜色 picker 加公共操作；网格／拨盘／光谱仍为专用交互 | 触屏、鼠标／键盘 | [sked_date_picker_test](../test/widgets/sked_date_picker_test.dart)、[sked_time_picker_test](../test/widgets/sked_time_picker_test.dart)、[sked_color_draft_test](../test/widgets/sked_color_draft_test.dart)、[mobile_secondary_pickers_test](../test/widgets/mobile_secondary_pickers_test.dart) |
| 解析设置的连接／密钥／模型／提示词、模型查询选择 | 公共字段、设置分组和确认壳；模型列表保留 `RadioGroup`，文本设置继续防抖自动保存 | 触屏、桌面 | [school_import_parser_settings_page_test](../test/widgets/school_import_parser_settings_page_test.dart)：等待保存退出、模型请求快照、HTTP 同意边界、失败重试与过期结果 |
| 设置的导入／导出页、顶栏／资源菜单的传输 sheet | [传输控制器](../lib/screens/settings_data_transfer_controller.dart) → 同一 `SettingsConnectedTile` 和任务头；每种传输保留方向、目标和恢复反馈 | 手机 sheet、桌面页／浮窗 | [settings_transfer_layout_test](../test/widgets/settings_transfer_layout_test.dart)、[settings_data_transfer_controller_test](../test/widgets/settings_data_transfer_controller_test.dart)、[timetable_import_flow_test](../test/widgets/timetable_import_flow_test.dart)：长文案、作用域、选择目标和窄屏可达性 |
| 设置中的备份／课表／分类／学校站点选择、导出文本／文件 | 公共确认／选项／操作；保留覆盖、格式校验、原始导出快照及系统文件选择器 | 触屏、桌面 | [settings_page_test](../test/widgets/settings_page_test.dart)、[export_save_flow_test](../test/widgets/export_save_flow_test.dart)、[text_transfer_widgets_test](../test/widgets/text_transfer_widgets_test.dart) |
| 外观／语言／通知／学生／通用／工作区／开发设置 | 公共设置分组、开关／滑块／选择行；语言搜索和原生系统权限入口保持用途 | 触屏、宽窄桌面 | [settings_list_test](../test/widgets/settings_list_test.dart)、[theme_settings_page_test](../test/widgets/theme_settings_page_test.dart)、[language_settings_page_test](../test/widgets/language_settings_page_test.dart)、[notification_settings_page_test](../test/widgets/notification_settings_page_test.dart)、[developer_mode_page_test](../test/widgets/developer_mode_page_test.dart) |
| 节次时间集／分类／学校站点管理页与资源栏 | 公共集合宿主、选项、空状态和菜单；节次编辑仍自动保存 | 触屏、桌面 | [period_times_page_test](../test/widgets/period_times_page_test.dart)、[period_task_safety_test](../test/widgets/period_task_safety_test.dart)、[timetable_resource_row_test](../test/widgets/timetable_resource_row_test.dart)、[school_sites_page_test](../test/widgets/school_sites_page_test.dart) |
| 删除、覆盖、备份恢复、清空数据、停用工作区 | `SkedMutationConfirmationDialog`／`SkedConfirmationDialog`；执行规则、危险动作颜色与失败重试保留 | 全平台 | [workspace_disable_transaction_test](../test/widgets/workspace_disable_transaction_test.dart)、[settings_backup_restore_progress_test](../test/widgets/settings_backup_restore_progress_test.dart)、[school_import_replace_confirmation_test](../test/widgets/school_import_replace_confirmation_test.dart) |
| 隐私同意、HTTP 同意、恢复资料导出／恢复 | 公共确认内容和操作；强制同意仍不能通过遮罩或返回绕过，恢复保留原始资料 | 全平台 | [home_screen_timetable_management_test](../test/widgets/home_screen_timetable_management_test.dart)、[school_sites_page_test](../test/widgets/school_sites_page_test.dart)、[school_import_parser_settings_page_test](../test/widgets/school_import_parser_settings_page_test.dart) |
| 编辑取消、关闭、系统返回、正文下拉和遮罩无障碍关闭 | `EditorExitGuard`、`SkedDiscardDraftDialog`、`SkedGuardedBottomSheetRoute`；授权完成只退出所属任务，恢复清理使用明确边界 | Android 手势、桌面键盘／关闭 | [guarded_editor_sheet_test](../test/widgets/guarded_editor_sheet_test.dart)、[guarded_existing_tasks_test](../test/widgets/guarded_existing_tasks_test.dart)、[editor_route_completion_test](../test/widgets/editor_route_completion_test.dart)：慢拖／快甩、干净／脏稿、忙碌、取消放弃、晚完成与恢复边界 |
| 编辑／详情忙碌、失败重试、更新提示 | 固定 `status`、`UiCommandFeedbackHost`、公共标题／操作；自动保存、解析进度和恢复结果保持独立含义 | 全平台 | [shared_editor_contract_test](../test/widgets/shared_editor_contract_test.dart)、[course_details_sheet_test](../test/widgets/course_details_sheet_test.dart)、[app_update_dialog_test](../test/widgets/app_update_dialog_test.dart)、[settings_feedback_revision_test](../test/widgets/settings_feedback_revision_test.dart) |

## 保留的专用行为

- 分类名称等单字段子配置保留短对话框宿主，复用 `SkedTaskDialog` 的标题／正文／操作布局以及公共字段和退出守卫；这些入口没有底部横条或下拉手势。课表、课程、日程及导入复核的触屏底部编辑任务使用 `AppSheetScaffold.editor`。
- 节次时间表和解析设置是自动保存页面。字段复用不引入新的整页保存／取消；离开页面仍等待 pending 写入或原有恢复流程。
- 节次时间集的名称在 `PeriodTimesPage` 内直接编辑，通过公共文本字段防抖保存，提交输入时刷新待写内容；它没有独立的名称保存弹窗。
- 模型选择保留 `RadioGroup` 的单选和键盘行为；日期网格、时间拨盘、颜色光谱、可重排导航和表格编辑保持专用交互。公共外壳和操作区仍适用。
- 分类行同时含重命名、可见性开关及更多菜单；恢复资料行含导出和恢复等独立动作。业务包装组件可继续存在，但采用公共按钮、菜单、字段或信息行。
- `ExpressiveDialogOption` 根据输入平台提供紧凑桌面行与触屏选项；课表切换条目、提醒摘要、导入站点／课程摘要及备份变更预览复用它。只读项不增加选择回调，提醒状态和全天／跨日时间仍由 `_ReminderSummaryRow` 解释。
- 导入的新增／替换动作、替换确认、周数警告和恢复反馈不可被通用“保存”替代。原始 JSON／HTML 是长文本编辑任务，保留代码字体、格式化、校验和阶段性提交。
- 语言搜索框、助手消息输入、原始 JSON／HTML 编辑以及日期／时间／颜色组件内部的专用输入保留各自控件语义；恢复资料路径保留 `SelectableText`／`SelectionArea` 的复制能力和独立导出按钮。这些控件不转换为普通业务表单字段。
- 课表网格、月历、时间轴、课程块、预览画布以及系统文件／权限界面不属于通用表单或列表行迁移；它们外围的标题、菜单、操作和状态仍遵循共同约定。

## 入口验收矩阵

每个家族至少记录以下组合，不以单一宽桌面截图作为覆盖依据：

1. 新增／编辑／查看、主页／资源列表／详情／通知、正常入口／紧凑溢出菜单。
2. Android 触屏、窄桌面、宽桌面；正常字号与大字号；中英文及必要的 RTL。
3. 无修改退出、有修改取消放弃、有修改确认放弃、保存成功、保存失败与重试。
4. 键盘出现／收起、拖拽关闭、窗口缩放、嵌套选择返回、工作区或目标数据失效。
5. 同一设备条件下并排比较同类标题、字段、动作、选择状态和错误反馈；确认按钮仍可触达且没有重复标题或双重 IME inset。

已有回归入口包括 `mobile_task_sheets_test`、`timetable_information_sheet_layout_test`、课程／日程编辑器测试、`category_manager_dialog_test`、`school_sites_page_test`、`school_web_import_result_sheet_test`、`school_import_parser_settings_page_test`、`settings_transfer_layout_test`、`language_settings_page_test` 及工作区焦点／缩放测试。实际设备和视觉结果应与执行环境、代码版本一起记录，不能从构造器已替换推断验收通过。

新增入口时检查 `AlertDialog`、`showDialog`、`showAppModalSheet`、自制 header/footer 和输入／选择行。应用代码中的原生 `AlertDialog` 构造应集中在确认适配器；直接出现的原生菜单或专用列表控件需能说明其保留的行为。

## 视觉矩阵与证据入口

原有 [mobile_tasks_visual_test.dart](../integration_test/mobile_tasks_visual_test.dart) 保留手机任务与外观菜单的场景。本轮课表／课程／日程及其他组件家族的完整对照矩阵位于 [component_unification_visual_test.dart](../integration_test/component_unification_visual_test.dart)。后者支持 `SKED_VISUAL_PROFILE`（单个或逗号分隔的配置名）、`SKED_VISUAL_OUTPUT`（绝对输出目录）和 `SKED_VISUAL_REVISION`（源码版本标识）。

在 Windows 上分两个独立进程运行，不把原生 Windows 和模拟 Android 配置合并为同一进程：

```powershell
$skedVisualRoot = Join-Path (Get-Location) '.scratch/component-unification'
$skedTouchProfiles = 'phone-393-zh,phone-320-2x-ime,phone-landscape,phone-landscape-ime,phone-dark-rtl,tablet-1280-en'
flutter test integration_test/component_unification_visual_test.dart -d windows --dart-define="SKED_VISUAL_PROFILE=$skedTouchProfiles" --dart-define="SKED_VISUAL_OUTPUT=$skedVisualRoot/windows-touch-final" --reporter expanded
flutter test integration_test/component_unification_visual_test.dart -d windows --dart-define=SKED_VISUAL_PROFILE=windows-overlay,windows-side-by-side --dart-define="SKED_VISUAL_OUTPUT=$skedVisualRoot/windows-desktop-final" --reporter expanded
```

手机和 Windows 代表配置还采集时间／重复选择、分类管理／重命名、详情进入编辑、放弃草稿确认、设置及导入复核。导入复核采集使用本地解析结果数据，其 manifest 单独标注未经过源网页和网络解析；这些链路由导入流回归测试另行验证。

本地交付证据集中在 `.scratch/component-unification/`：`comparison.html` 和 `comparison-manifest.json` 提供原图对照，`visual-snapshot-source.json` 记录独立采集快照的逐文件哈希，`windows-touch-final.log` 和 `windows-desktop-final.log` 保存分批结果。`android-device/` 保存 Android 36 模拟器上的真实系统键盘、返回和旋转验收；Windows 渲染中的键盘占位不得替代这些证据。截图和本地运行记录不作为源码提交。
