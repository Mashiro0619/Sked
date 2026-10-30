# Agent 全软件能力契约规划

## 状态与目标

本文是待实施的能力契约，研究基线为源码 `ea784f3a16e5d4a23aedae410544492fb6fa0f6f`。文中的工具名、注册表、管理入口和验收门禁均为设计目标，不表示当前版本已经实现 Agent。当前行为仍以[使用逻辑](USAGE_LOGIC.md)、[可靠性验证指南](RELIABILITY_BASELINE.md)和实际源码为准；实施改变既有行为时，须同步这些说明。

已实现的应用层读取基础为 `ResourceQueries`，可查询课表、课程、时间集、分类、日程系列和实际实例，支持 summary/detail/edit 与显式字段选择。默认包含隐藏分类和停用工作区；只读取快照，不改变当前选择。每页最多 100 项、64 KiB，实例范围最多 366 天、匹配总数最多 20,000；结果返回总匹配数与下一页，超限明确失败。游标绑定数据世代、快照版本和查询条件。此基础尚未作为联网 Agent 工具公开；下文其余未标记能力仍是实施目标。

`ResourceMutationCompiler` 已支持分类的创建/字段修改/删除/复制，以及日程的创建/字段修改/删除/复制/跨分类移动。它一次编译整个批次，固定宿主生成的 ID 和时间，严格拒绝未知字段、失效目标和非法日期/重复/提醒配置；未涉及字段保留。分类排序实际调整列表位置，并记录相邻分类的顺序变化。原选择仍合法时保持，隐藏或删除当前分类、全隐藏状态新增可见分类时按原模型回退并明确记录影响；删除最后分类生成新的空默认分类。输出包含实际候选与完整差异，尚未开放模型写入；持久提交与撤销由后续协调器接入。学生资源和单个重复实例编辑仍待补齐。

`AgendaQueries` 已提供计数、空闲时间和冲突计算。它复用同一实例读取，按来源筛选后只展开一次，最多处理 2,000 个实例，结果最多 100 项并明确标记还有结果；超大范围要求缩小查询。空闲时段合并重叠/相接占用，冲突仅返回实际相交部分，均保留读取世代与快照版本，不由模型自行估算。

`SettingRegistry` 已登记主库偏好及设备/平台适配入口，提供类型、枚举、范围、默认来源、null/reset 语义和显式工作区。纯准备支持 keep/set/reset，批次按最终组合校验；必要派生变化进入差异，显式 keep 与派生变化冲突时拒绝。它不改变当前工作区、不持久化、不代替通知或系统授权。Agent 配置、设备布局、站点和系统能力等需要专属适配器，未接通时返回 requiresAdapter；隐私同意事实等只读值不能被当作普通偏好写入。

严格编译器现也覆盖课表、课程和时间集的增删改/复制，以及跨课表移动课程。普通课程修改保持原列表位置和旧周次、时间来源；移动一次合成两端数据，保留共享名称颜色。时间集要求连续节次、合法且不重叠的时间；使用中的时间集不能直接删除，缩短或更换时间集不能新引入失效课程绑定，须先明确调整课程。活动课表、冲突选择与共享颜色的实际联动进入差异。重复实例与提醒动作仍待接入。

Sked 只提供一个跨平台内置 Agent，通过用户选择的 API 查看和管理所有课表、课程、日历、日程、共享资源、应用设置及未来新增的可配置功能。这个 Agent 可以拥有多个会话；会话分别保存消息和运行记录，共用同一套 Agent 设置、工具与 Skills。产品不提供创建多个独立 Agent 的管理系统。

权限只有三种：**只读计划模式、每次修改前询问、完全权限模式**。用户直接选择模式，不增加按 Agent、资源范围或授权期限配置的权限面板。全软件能力保持完整，执行器按当前模式判断是否允许修改、是否需要本次操作确认，并持续执行严格的业务校验。

普通界面和 Agent 共用应用命令、校验与持久化边界。模型处理意图、检索、规划和工具选择；宿主负责解析参数、解析资源、验证授权、执行、持久化和回报结果。模型不直接改写存档，也不依赖打开页面或模拟点击才能操作数据。

## 功能入口与启用开关

Agent 纳入现有功能管理，使用一个开关控制启用与入口显示。开关存于单例 `AgentSettings.enabled`，不新增独立 Agent 列表，也不把 Agent 当作课表/日程之外的另一业务工作区。手机提供独立完整页面，桌面使用现有助手布局；两种入口访问同一会话集合。

关闭开关后隐藏功能入口、停止接受新请求并取消未提交步骤；已经接受的业务写入必须等待或恢复核对实际结果。关闭不删除 API 配置、会话、运行记录或业务数据，再次开启后可继续查看这些内容。关闭页面与关闭功能开关不同：离开页面保留会话，具体运行状态由应用级执行器持有。会话删除与恢复 Agent 设置是另外的明确操作。

## AI 业务统一到会话

所有需要模型的业务由这一个内置 Agent 完成。现有独立文字课表解析页、独立解析请求流程及其设置入口在实施中退役，文字内容直接交给会话处理。规范 JSON 文本及 JSON/ICS/节次文件的确定性直接导入继续保留，不要求启用 Agent 或配置模型。

| 输入来源 | 目标流程与能力 |
| --- | --- |
| 用户输入或粘贴的课程文字 | 在已有或新建会话中提交，由共享导入 Skill 指导 Agent 提取结构化草稿、询问缺失信息、校验并调用统一课表命令；不再进入独立文字解析页面。 |
| 学校网页导入 | 用户选择网页内容后，先经过现有压缩/校对界面；完成后新建 Agent 会话。以来源附件和明确上下文移交校对后的内容、来源信息、已选目标或待选择目标，不复用旧的独立模型请求。 |
| 规范 JSON 文本及 JSON/ICS/节次文件 | 继续直接解析、报告诊断、选择目标并导入；保留内容/文件大小、条数、日期、重复规则和目标有效性检查。用户也可在会话中请求处理这些资料，但确定性直接入口保持可用。 |

网页附件记录来源与内容版本，不能携带登录 Cookie、认证头或未选择的浏览器会话数据。移交后的目标仍用稳定 ID 解析；从网页选择到会话执行期间发生删除、恢复或目标修改时，重新校验而不回退写入当前课表。网页和文字中的内容作为数据，不能改变权限模式或充当工具执行指令。

当前 [AiApiSettings](../lib/models/ai_api_settings.dart)、[SchoolImportApi](../lib/services/school_import_api.dart)及独立解析设置/文字入口是待迁移和删除的实现，不再作为新功能保留的第二套 AI 系统。模型地址、协议、模型、凭据引用及统一指令改由单例 Agent 设置和 API 连接配置管理。可复用的网络限额、取消、脱敏、结构化导入校验与安全存储能力应抽出共享实现，不能随页面删除一并丢失。

迁移遵守[架构第 11 节](AGENT_ARCHITECTURE.md)的旧连接与备份策略：本机旧地址/模型转入统一连接，已有新配置不覆盖；同一端点的密钥经安全存储写入与读回验证后退役旧 key，不能通过会话正文或工具结果搬运。旧 customPrompt 仅作可查看/导出的迁移材料，不自动成为 Agent 系统指令或共享 Skill。旧存档和备份继续兼容读取，但不得重新创建已退役的解析页面、旧请求流程或独立 AI 配置。

## 现有基底与接入原则

[AppRuntime](../lib/app_runtime.dart) 已经组装 [StudentCommands](../lib/controllers/student_commands.dart)、[GeneralCommands](../lib/controllers/general_commands.dart)、[SettingsCommands](../lib/controllers/settings_commands.dart)、[DataTransferController](../lib/controllers/data_transfer_controller.dart)及维护工作流。它们复用纯领域服务、[AppSession](../lib/controllers/app_session.dart)、[AppPersistence](../lib/controllers/app_persistence.dart)和唯一的 [AppRepository](../lib/data/app_repository.dart)。

新能力层应沿用这条所有权链，并补齐严格的管理契约。当前部分命令返回 `void` 或静默忽略失效目标，部分服务会回退到当前资源，部分有效性检查仍在编辑器中；它们不能未经适配直接成为工具 API。应把可复用的验证和变换放到应用层，再让既有界面入口与新管理入口共享。

所有命令至少遵守以下约定：

- 用稳定 ID 明确目标；更新、删除和批量操作不能在原目标失效后改用“当前课表”或“当前分类”。名称只用于检索和展示。
- 区分创建、字段修改、移动、删除、重排、恢复默认和维护动作；不以一个任意 JSON 写入工具替代全部业务能力。
- 修改采用明确字段集合，保留未涉及字段。旧课程时间表示、嵌套自定义字段、重复例外、提醒策略等不能因普通内容编辑丢失。
- 返回实际创建的 ID、实际变更字段、关联影响、数据提交回执及待完成副作用。排入保存队列不代表保存成功。
- 执行前重验资源版本、数据会话和计划有效性；不让模型数分钟前读取的对象覆盖用户后续编辑。
- 查询有范围、分页或有界结果；明确返回是否还有数据。不得把截断结果描述为全量。

## 全局管理与工作区可见性

全局管理覆盖当前和非当前课表、显示和隐藏分类、启用和停用工作区中保留的数据。这是相对于当前界面命令的有意新增行为：现有命令通常要求工作区启用，而新管理 API 可以在工作区停用时读取和修改其数据。

实现应拆开“数据管理授权”和“界面工作区可用性”，增加显式管理命令或执行上下文。不得通过临时启用工作区、切换 `activeMode`、打开页面或伪造当前选择来绕过限制。共享纯服务和存储门禁仍适用，现有界面入口可以继续要求工作区启用。

管理停用域时必须保持以下行为：

1. 保留 `enabledWorkspaces`、当前工作区及重新启用提醒时间界线，除非本次明确执行工作区启停命令。
2. 新增、改时、删除或更改提醒偏好均不启动停用域的提醒，不创建其系统通知或后台投影。
3. 将来用户显式重新启用该域时，继续按工作区命令确定新的提醒时间界线；管理动作不能回填该事实。
4. 查询返回资源所属域、域启用状态及分类可见状态。隐藏和停用不是数据不存在。
5. 恢复、清空、关闭应用数据会话、损坏恢复写门禁和其他维护边界仍可阻止管理写入；管理权限不绕过数据完整性约束。

[AgendaProjectionService](../lib/services/agenda_projection_service.dart) 当前默认只投影所选课表、过滤隐藏分类并跳过停用工作区。因此，Agent 的全局数据查询应另建明确的管理查询层，按需复用课程和日程的纯展开器；不能直接把现有通知投影结果当作“全部资源”，也不能为扩大查询范围改变通知消费者的过滤政策。

管理列表建议使用显式查询 `scope`，例如 `all`、指定工作区或指定资源集合，并回报生效范围。这里的 scope 是查询或变更目标选择，不是额外的用户权限配置。界面当前选择可以帮助解析“这张课表”，不会限制查询全部资源。查找歧义目标时返回候选；删除集合在准备阶段固化 ID 与数量，提交时不重新执行自然语言过滤吸收后来新增的对象。

## 资源能力矩阵

以下矩阵定义首轮完整覆盖范围。能力层应为每一行登记读取、变更、重置或不适用的明确理由；“支持管理”不意味着所有资源都有相同 CRUD 语义。

| 资源 | 必须提供的能力 | 关键语义与现有实现 |
| --- | --- | --- |
| 课表 | 列表、详情、创建、修改名称/开学日期/总周数/时间集绑定、复制、删除、批量操作、显式选择显示 | [TimetableData](../lib/models/timetable_data.dart)、`StudentCommands.updateTimetableConfigFor`、[StudentTimetableService](../lib/services/student_timetable_service.dart)。零课表合法；缩短学期要返回受影响课程，不把隐藏的周次当作课程已删除。复制和批量事务需要新增应用命令。 |
| 课程 | 列表、详情、创建、字段修改、跨课表移动/复制、删除、批量移动或调整时间 | [CourseItem](../lib/models/course_item.dart)、`StudentCommands.saveCourse/deleteCourse`。覆盖名称、教师、地点、星期、周次、节次、显式起止分钟、学分、备注、自定义字段、提醒策略。移动不能通过静默重用 ID 覆盖其他记录。 |
| 课程实例 | 按日期/周次查询、定位实际课程、查询冲突、为编辑解析所属课表和课程 | 实例由课表和课程规则投影，不是可直接写回的独立资源。现有课程模型没有日程式的“仅本次”例外结构；若需单次调课，应另设模型与迁移，不能把整门课改时冒充单次调整。 |
| 节次时间集 | 列表、详情、创建、重命名、编辑有序节次、复制、删除、查询引用、批量重绑 | `StudentCommands.addPeriodTimeSet/updatePeriodTimeSet/deletePeriodTimeSet/assignPeriodTimeSetToTimetable`。使用中的集合不能直接删除；重绑后删除可以构成一个明确批事务。管理共享资源和修改某课表绑定是不同动作。 |
| 课程冲突展示 | 查询真实冲突组、读取/设置/清除所显示课程 | `setDisplayedCourseForConflict` 与 `filterStudentConflictDisplayCourseIds`。选择展示项不等于解决冲突，更不删除其他课程；仅接受属于当前冲突组的课程 ID。 |
| 课程名称颜色 | 查询名称到颜色的映射、设置、恢复自动分配 | `courseNameColorValues` 按规范化课程名称共享，见 `buildStudentCourseNameColorValuesForTimetables`。它不是每个课程对象独立的颜色字段；改名和删除可能改变派生映射。 |
| 日历分类 | 全量列表、详情、创建、修改名称/颜色/可见性、重排、复制、删除、显式选择显示 | [GeneralSchedule](../lib/models/general_schedule.dart)、`GeneralCommands`。分类 metadata patch 不接受顺带替换 `events`。删除最后一个分类目前会创建默认分类，结果必须解释这个实际变化；重排/复制需补明确命令。 |
| 日程记录 | 列表、详情、创建、字段修改、移动分类、复制、删除、批量操作 | [GeneralEvent](../lib/models/general_event.dart)、[GeneralCalendarService](../lib/services/general_calendar_service.dart)。覆盖标题、起止时间、全天、重复规则、例外日期、地点、备注、颜色、提醒；创建/更新时间由执行器维护。 |
| 重复日程实例 | 范围展开、详情、复制为单次、按仅本次/本次及以后/整个系列修改或删除 | `GeneralCommands.prepareOccurrenceEdit/editOccurrence/deleteOccurrenceScope`。使用 `occurrenceKey` 和明确编辑范围；复用 `GeneralCalendarService.editOccurrence` 的拆分、例外映射和提醒状态处理。 |
| 提醒处理记录 | 查询有效提醒、标记某实例已处理、恢复该实例提醒、查询稍后提醒等运行状态 | `dismissReminder/restoreReminder` 与通知动作工作流。已处理提醒不等于任务完成；内部运行记录通过语义动作维护，不提供任意 JSON 修改。 |
| 综合日程查询 | 跨全部课表和日历检索、有限范围实例展开、空闲区间/冲突查询、返回可导航资源引用 | [GeneralOccurrenceService](../lib/services/general_occurrence_service.dart)和课程投影逻辑可复用。新增全局聚合、分页及空闲区间计算；注明纳入的隐藏/停用范围、时间基准与结果边界。 |
| 学校站点 | 列表、详情、添加、改名/改 URL、删除、导入、导出、恢复内置列表 | [SchoolSiteService](../lib/services/school_site_service.dart)、[SchoolSite](../lib/models/school_site_models.dart)。当前对象只有名称和 URL，需稳定 ID 迁移，或在迁移前使用来源版本绑定的稳定句柄；不能用页面 index 执行并发删除。 |
| 学校网页登录会话 | 查询可操作状态、退出本机学校网页会话、清理后重建页面 | [SchoolWebSessionService](../lib/services/school_web_session_service.dart)。本机 Cookie/缓存清理不等于注销远端学校全部会话。 |
| 课表/日程/节次导入导出 | 准备候选、查看完整诊断、选择资源和追加/替换目标、应用、生成 JSON/ICS 文件产物 | `DataTransferController` 与 [ImportExportService](../lib/services/import_export_service.dart)。来源和目标显式固定；文件生成、写入用户选定位置、分享/外传是不同能力。 |
| 完整备份 | 生成备份、读取备份清单/影响、恢复、查询恢复进度及待恢复状态 | [AppBackupController](../lib/controllers/app_backup_controller.dart)。复用多存储日志和维护门禁，不等同普通数据导入；备份不包含密钥。独立解析配置退役后，按统一 Agent 连接的新迁移契约处理旧备份，并同步恢复规则与回归。 |
| 应用数据清除 | 描述清除范围、执行清除和退出、回报实际清除/退出状态 | [AppDataClearCoordinator](../lib/services/app_data_clear_coordinator.dart)。涉及主存档、侧存储、学校网页、设备偏好与通知；不能只写一个空 AppData 后回报全部清除成功。 |
| 恢复与维护 | 读取诊断、重试加载、导出受控恢复工件、按既有条件开始新存档、重建通知投影 | [AppLifecycle](../lib/controllers/app_lifecycle.dart)、`AppRepository` 及现有维护服务。只暴露语义动作，不允许改写恢复阶段、文件候选顺序或写门禁状态。 |

当前没有独立 Todo/任务完成模型、通用标签实体、CalDAV/WebDAV 同步配置或已实现的 Android 桌面小组件配置。新增这些产品能力时，应在同一变更中接入能力注册与验收；不能把它们算作当前已有工具。

## 业务规则必须下沉到共享应用层

`ResourceMutationSchema` 与严格编译器共用六类资源的允许字段集合，提供类型、创建必填项、动作和语义约束；查询投影仍独立按 summary/detail/edit 装载。调用方先查字段目录，再提交显式字段，不能把磁盘兼容解码当成新命令校验。重复实例的三种范围和提醒动作在同一目录中说明，课程与事件保持各自模型。

Agent 参数校验不能依赖 Flutter 表单是否打开。需从 [CourseEditorSheet](../lib/widgets/course_editor_sheet.dart)、[GeneralEventEditorSheet](../lib/widgets/general_event_editor_sheet.dart)及[课表管理界面](../lib/screens/home_screen_timetable_management.dart)抽出可复用规则与影响计算。

- 课程新建要求有效名称、至少一周及有效时间；历史空周次表示每周的兼容含义应保留。只修改文字时，旧课程依靠节次推导时间的表示不得被固化。
- 节次必须位于当天、结束晚于开始并顺序不重叠；新增节次不得越过当天上界。课表必须引用有效时间集。
- 日程全天日期、排他结束、UTC/偏移/浮动本地时间分别处理。自然语言中的“明天”“下周”在一次计划上固定时钟和时区，预览输出明确日期。
- 重复实例的三种编辑范围、包含排除候选的计数、月末锚点、同频平移与变频后的例外保留规则，全部复用现有纯服务。
- 日程继承、关闭、自定义提醒不同；临时关闭默认提醒或隐藏分类不能抹掉已处理记录。隐藏分类的提醒仍由其专门偏好控制，停用工作区则始终不提醒。
- 容错导入与严格新命令分开。现有服务对非法目标的 fallback 或归一化不能令 Agent 的明确更新悄悄写到另一对象。

上述规则是数据语义，不因用户选择完全权限模式而取消。缩短学期、改变重复步长、覆盖导入等影响应计算成结构化计划：只读计划模式仅展示计划；每次修改前询问模式在本次明确操作前确认；完全权限模式校验后可连续执行，不增加固定逐次确认。准备计划本身不等于强制人工确认。

## 设置 API 与描述注册表

新增 `SettingDescriptor` 作为可配置项的完整目录；现有 [settingsCatalog](../lib/models/settings_catalog.dart)只是界面导航索引，不能充当字段级工具注册表。

每个 descriptor 至少包含：

| 项目 | 要求 |
| --- | --- |
| 稳定标识 | `key`、公开名称、说明、schema 版本；公开 key 不直接等于任意存储 JSON 路径。 |
| 所有权 | `scope`（应用、工作区、资源、设备、单例 Agent 设置、API 连接）、存储归属、是否参与备份。该范围描述数据归属，不是按 Agent 划分的权限配置。 |
| 数据类型 | 类型、可选值、范围、单位、是否允许 null、完整对象/字段 patch 语义。 |
| 默认与继承 | 默认来源、当前显式值、有效值、继承来源、`reset` 的准确动作。 |
| 操作 | read/set/reset 或专用语义动作；只读事实的不可写理由。 |
| 平台 | 平台是否支持、当前设备是否生效、是否需系统操作及可读取的状态。 |
| 执行 | 读取/写入集合、依赖字段、关联影响、提交归属，以及只读或变更操作分类。 |
| 敏感性 | 数据是否进入模型结果、是否脱敏、是否只能通过宿主安全输入 handle 管理。 |

拟定基础接口：

- `settings.describe`：按 scope/key/类别查询描述，包含当前值、默认/有效值与平台状态；支持分页。
- `settings.get`：获取指定稳定 key 的值和版本；不返回凭据原文、内部缓存或无关整份 AppData。
- `settings.prepare`：以 `action: set` 和明确的 key/value 集合准备修改，或以 `action: reset` 和明确的 key/命名组准备恢复默认；先验证组合约束，返回规范化值、影响和 PreparedMutation，不写入数据。未知 key 和未声明字段失败。
- `mutation.commit`：接受有效计划句柄，按当前三种权限模式拒绝、询问或执行；仅在实际持久化后返回生效值、提交版本及副作用状态。

能力矩阵中的 set/reset 表示操作语义，不是两套额外的提交 API；不另注册语义重复的 `settings.set/reset/preview` 工具。准备结果不是已生效回执，删除必需 JSON 字段也不是 reset 的实现。只在数据类型本身允许时接受 `null`：通知提前分钟的 `null` 表示关闭，`customDayMinWidth` 的 `null` 表示自动布局，事件颜色的 `null` 表示继承分类色，三者不能共用“缺失值”解释。颜色和工具栏复合项需要单字段 reset 与整组 reset 的清晰范围。

## 主数据设置覆盖矩阵

下列字段来自当前模型和命令层。公开 key 可采用稳定命名空间，执行时映射至现有字段；不得因属性名与旧存储 key 不同而漏项。例如 `hideHomeWorkspaceNavigation` 仍序列化为兼容 key `hideHomeBottomNavigationBar`。已确定退役的独立 AI 设置登记其迁移和删除去向，不再为旧入口新增工具。

| 范围 | 要覆盖的当前配置 | 操作、默认和关联约束 |
| --- | --- | --- |
| 全局导航与语言 | `localeCode`、`hideHomeWorkspaceNavigation`、`homeWorkspaceNavigationCollapsed`、`workspacePanelDisplayMode` | describe/get/set/reset；隐藏导航与停用工作区不同；面板方式沿用 `overlay` / `sideBySide` / `automatic` 模型有效值。来源：[AppData](../lib/models/app_data.dart)、`SettingsCommands`。 |
| 工作区可用性 | `enabledWorkspaces`、`activeMode` | 使用启用/停用/切换命令；至少一个工作区启用，切换不得指向停用域。`workspaceReminderNotBefore` 由启用命令产生，不允许任意 set。来源：[WorkspaceCommands](../lib/controllers/workspace_commands.dart)。 |
| 更新偏好 | `includePrereleaseUpdates`、被忽略版本 | 预发布开关变更同时清空旧渠道候选；忽略/取消忽略使用命名动作。`availableUpdateVersion` 属探测结果，提供检查更新和读取结果，不能伪造版本。 |
| 系统通知偏好 | `enabled`、`courseDefaultMinutesBefore`、`generalDefaultMinutesBefore`、`lockScreenShowTitles`、`remindHiddenGeneralCalendars` | describe/get/set/reset；数据保存与平台授权/排程结果分开。来源：[NotificationSettings](../lib/models/notification_settings.dart)、`SettingsCommands.updateNotificationSettings`。 |
| 课表显示与交互 | `closeCoursePopupOnOutsideTap`、`preserveTimetableGaps`、`showPastEndedCourses`、`showFutureCourses`、`showTimetableGridLines`、`showAddCourseFab`、`enableLongPressAddCourse`、`fitDaySelectorToWidth`、`fitWeekColumnsToWidth`、`enableWeekSwipeNavigation` | 全部可管理；当前桌面 UI 不显示的移动端偏好仍需 descriptor，并说明在哪个平台生效。来源：[StudentModeData](../lib/models/student_mode_data.dart)。 |
| 课表工具栏 | `toolbarNavigationOrder`、`hiddenToolbarNavigationIds`、`toolbarHiddenItemsBehavior` | set/reset、重排/显隐动作；ID 必须属于已知集合，按现有规范化处理缺项和顺序。 |
| 两个工作区各自主题 | `themeMode`、`themeColorMode`、`themeSeedColorValue`、`colorfulUiColorValues` | 必须显式目标工作区；不能按 activeMode 猜目标。主题槽和固定颜色不同，整组 reset 与单槽 reset 分开。来源：[SettingsService](../lib/services/settings_service.dart)。 |
| 课表课程文字颜色 | `colorfulCourseTextColorMode`、课程文字相关 `colorfulUiColorValues` 槽、`courseNameColorValues` | 复合修改使用现有联动逻辑；课程名称颜色遵循资源矩阵的共享映射语义。 |
| 课表实时高亮 | `liveCourseOutlineColorValue`、`liveCourseOutlineEnabled`、`liveCourseOutlineFollowTheme`、`liveCourseOutlineMode`、`liveCourseOutlineWidth` | 组内一致提交；`liveCourseOutlineCustomColorInitialized` 为派生实现状态，选择颜色或 reset 时由领域动作维护，不向模型开放任意写入。 |
| 日程视图与日期显示 | `defaultView`、`viewSwitchBehavior`、`toolbarWidthPolicy`、`dateLabelFormat`、`fitWeekColumnsToWidth`、`customDayMinWidth`、`showWeekends`、`showLunarCalendar` | 全部 describe/get/set/reset；自定义日宽沿用自动或合法范围/步长。来源：[GeneralScheduleData](../lib/models/general_schedule_data.dart)、`GeneralCommands.updateDisplaySettings`。 |
| 日程时间网格 | `dayStartHour`、`dayEndHour`、`timeGridMinutes`、`timeGridHourHeight` | 验证时段组合、网格和高度，不逐字段制造无效中间值。 |
| 日程交互 | `closeEventPopupOnOutsideTap`、`showAddEventFab`、`enableLongPressAddEvent`、`allDayTimelineCollapsed` | describe/get/set/reset；保持当前平台的布局生效范围。 |
| 日程工具栏 | `toolbarNavigationOrder`、`hiddenToolbarNavigationIds`、`toolbarHiddenItemsBehavior` | 与课表独立的字段集合和 known IDs；支持重排、显隐、reset。 |
| 导航与选择状态 | 课表 `activeTimetableId`、日历 `activeScheduleId`、`selectedDateIso`、`customDateRange`、运行时选中周次 | 通过 `navigation` 命名动作显示指定资源或日期；数据查询/管理不依赖这些值。运行时周次不能伪装为跨设备持久偏好。来源：[GeneralNavigationController](../lib/controllers/general_navigation_controller.dart)、[StudentViewState](../lib/controllers/student_view_state.dart)。 |
| 独立学校解析配置（退役） | 现有 `source`、`customBaseUrl`、`customModel`、`customPrompt`、独立密钥入口 | 迁移到统一 Agent 模型连接和共享导入 Skill 后移除独立字段/设置页/调用入口；不暴露另一套学校解析配置工具。旧备份兼容和凭据迁移需有明确规则。来源：[AiApiSettings](../lib/models/ai_api_settings.dart)。 |
| 隐私政策接受记录 | 已接受版本、接受时间 | 只读真实同意事实；可展示政策并发起宿主同意流程，不能通过通用设置变更生成或修改用户同意。 |

只读描述可以告知内部关联事实，但不应暴露不必要的存储实现字段。对于既有模型中的版本号、ID、时间戳、缓存和派生标志，覆盖清单必须登记为由哪个语义动作维护，不能为了“100%字段覆盖”全部开放为可写。

## 侧存储、设备配置与系统能力

“所有配置”横跨主数据、学校站点、安全存储、设备偏好和原生能力，不能只扫描 AppData 字段。

| 范围 | 管理契约 | 现有来源与边界 |
| --- | --- | --- |
| 学校站点列表 | 独立资源命令、版本检查、导入/导出/恢复默认 | `SchoolSiteService` 有恢复状态和 generation；与主数据跨存储批处理需恢复工作流，不能声称一个 AppData 写入全部原子完成。 |
| 安全凭据 | 创建、替换、删除、绑定统一 Agent 的 API 连接、读取是否存在/验证状态 | 参考现有 [SecretStore](../lib/services/secret_store.dart)及 [SchoolImportSecretController](../lib/controllers/school_import_secret_controller.dart)的写入验证与失败恢复，迁移后退役独立学校解析密钥入口。凭据值由宿主安全输入或受控导入获得，工具接收 handle；不在参数、结果、消息、备份或日志里传递原文。 |
| 设备面板尺寸 | 按角色读取、设置、清除单维度、重置角色/全部角色，并等待 flush | [DesktopLayoutPreferences](../lib/services/desktop_layout_preferences.dart)。`width`、`height`、`dockedWidth` 属设备偏好，不进 AppData/完整备份；布局约束后的测量值不能自动写回偏好。普通 reset 不得调用会冻结存储的清除流程。 |
| 开发者入口 | 读取/修改/恢复已有开发者偏好 | [DeveloperUiPreferences](../lib/services/developer_ui_preferences.dart)。现有助手预览入口属于旧开发者功能；正式 Agent 改用功能管理中的单一开关，不要求同时开启开发者入口。 |
| 开发者样例与诊断 | 查询能力、按明确命令生成样例、测试通知、清理测试运行状态 | [DeveloperCommands](../lib/controllers/developer_commands.dart)、[AgendaCoordinator](../lib/services/agenda_coordinator.dart)。生成样例是数据修改，不能作为普通设置字段或默认日程整理步骤。 |
| 通知运行时 | 查询排程/稍后提醒/处理结果、重排、清理或恢复 | claim ledger、projection fence、内部通知 ID、恢复阶段都是一致性状态，只能由对应工作流维护。 |
| Android 通知/精确闹钟/电池优化 | 读取可读状态、发起系统授权或打开设置、返回后复查 | [AndroidProductivityBridge](../lib/services/android_productivity_bridge.dart)和[通知网关](../lib/services/agenda_notification_flutter_gateway.dart)。打开设置不等于授权成功；拒绝和未知状态原样返回。 |
| OEM 自启动 | 查询厂商入口能力并打开设置 | 当前没有可信“是否允许自启动”读取接口，应返回 unknown 或 user_action_required，不能设置虚构布尔状态。 |
| Windows 通知 | 查询应用与平台诊断、调用可用的通知操作 | 系统授权状态可能为 unknown；兼容接口返回 true 不能作为真实授权证据。 |
| Windows 窗口操作 | 读取可用状态、最小化/最大化、请求关闭 | [DesktopWindowBridge](../lib/services/desktop_window_bridge.dart)。关闭走保存与退出守卫，不能直接结束进程冒充安全关闭；其他平台按实际能力返回支持状态。 |
| 平台尚未实现的能力 | 可发现且返回 unsupported，并说明可用替代操作 | 当前通知网关的平台覆盖与 Flutter 应用构建平台不同；保存通知偏好不证明任意平台已支持系统投递。 |

设备面板角色初始覆盖 `resources`、`settingsNavigation`、`periodTimeSets`、`schoolSites`、`importPreview`、`themePreview`、`monthAgenda`、`monthAgendaBottom`、`allDayTimeline`、`courseEditor`、`timetableEditor`、`eventEditor`、`courseDetails`、`eventDetails`、`reminderList`、`dayAgenda`、`occurrenceList`、`calendarManager`、`categoryManager`、`categoryNameEditor` 和 `assistant`。新增 [DesktopLayoutRegion](../lib/services/desktop_layout_preferences.dart) 成员必须进入描述与 reset 覆盖，不靠手写工具列表记忆同步。

## 单例 Agent 设置与多会话

应用持有一个 `AgentSettings`。多个 `Conversation` 通过各自的 `conversationId` 管理聊天上下文和 `Run`，共享 Agent 设置与执行器。以下统一配置取代当前独立学校解析配置，而不是与它长期并存。

| 新资源 | 必须提供的能力与约束 |
| --- | --- |
| 单例 AgentSettings | 查询、修改、恢复默认：功能启用开关、所选 API 连接/模型、统一指令、运行预算、历史保留偏好。权限模式由用户通过宿主三选一；模型不能修改模式以跳过询问。设置带 schema 和配置版本，不提供创建/复制/删除 Agent 的动作。 |
| API 连接配置 | 可保存自选连接，支持创建、查询、修改名称/协议类型/base URL/model/受支持参数、测试连接、获取模型、替换/删除凭据引用、删除连接。连接用于这个唯一 Agent，切换连接不创建另一个 Agent；被使用的连接删除时需处理引用和运行边界。 |
| Conversation | 新建、列表、读取有界历史、重命名、归档、按保留政策删除。会话只隔离对话上下文，不拥有独立 Agent、长期记忆库或 Skills 配置。删除运行中会话先持久化终止标记，阻止新/未提交步骤，核对已接受写入，再清理本会话正文与附件；迟到结果不得复活会话。删除不撤销已提交的课表/日程，操作层按保留规则保存幂等所需最小回执。 |
| Run | 属于一个 Conversation；开始、查询阶段/动作结果、继续、停止。停止阻止后续步骤，已接受写入仍核对结果；同一会话消息重试不创建重复业务操作。 |
| 统一长期记忆与偏好 | 若实现，属于这个内置 Agent 的共享设置，需可列举来源、查看、修改、删除、禁用及重置；不为各会话建立独立 Agent 记忆系统。业务实时状态仍以查询结果为准。 |
| 统一工具与 Skills | 使用应用级注册表和统一领域 Skills；可描述当前版本及适用能力，不按会话或独立 Agent 配置隔离。加载指导文本不能改变权限模式，任意代码执行不是通用配置写入的默认后门。 |

API 连接与凭据分离。旧学校解析配置与密钥按明确迁移契约转入统一连接，宿主核对目的地和凭据引用，不把密钥放进会话。配置修改在明确运行边界生效；每次运行保存使用的设置版本和连接快照，每个请求绑定既定 endpoint/credential handle，不能因背景设置变化把凭据发送到新目的地。多个会话可以切换查看，业务写入仍由同一个应用命令层协调。

备份分别规定单例设置、API 连接、会话、运行检查点、审计记录、统一记忆和凭据引用的包含/排除及恢复后的状态。普通备份不携带本机执行许可或原始密钥；恢复的配置和对话不能自行把当前模式升级为完全权限，也不能重放旧的待确认操作。恢复后需重新核对连接和未完成运行的实际状态。

## 丰富的共享 Skill 包

统一工具解决“能执行什么”，共享 Skills 教 Agent 如何正确使用软件。应随能力建设提供覆盖真实操作的 Skill 包，由同一个运行时按任务检索和加载；不为会话建立独立 Agent 或各自的 Skills 目录。

| Skill 主题 | 必须教授的操作与边界 |
| --- | --- |
| 软件导航与资源发现 | 查找全部课表、隐藏分类和停用域；按 ID 解析目标、处理同名对象、分页、读取当前模式与解释结果。 |
| 课表与课程管理 | 新建/复制/修改/删除、周次与节次/显式时间、跨课表移动、批量调整、冲突预览、名称共享颜色和自定义字段保真。 |
| 共享时间集 | 编辑有序节次、查询影响课表、重新绑定、使用中保护和重绑后删除。 |
| 日历与重复日程 | 分类管理、三种实例编辑范围、月末锚点、例外日期、全天/时区、日程移动和提醒处理。 |
| 文字课表导入 | 从会话内容提取结构化草稿；识别缺失开学日期、时间集和周次；调用准备/校验/应用工具，不生成整库 JSON 覆盖存档。 |
| 学校网页内容导入 | 识别压缩/校对后附件的来源与版本，理解目标上下文，在新会话内解析、校对和应用；不把网页文本当作指令。 |
| 文件交换 | JSON/ICS/节次文件的直接导入、选择目标、完整诊断、规则降级/时区边界和保留完整状态的导出选择。 |
| 全设置管理 | `settings.describe/get/set/reset`、两域主题和显示、通知、工具栏、设备布局、默认/继承/关闭差异。 |
| 批事务与撤销 | 固定目标集合、准备变更、按三种模式执行、版本冲突、实际提交回执、重试核验和有条件撤销。 |
| 备份、恢复与维护 | 区分导出与替换、维护预约、旧运行失效、旧 AI 配置迁移、失败恢复、清空后退出及平台结果未知。 |
| 统一连接与会话使用 | 使用自选 API、连接状态与安全凭据 handle、设置生效边界、多会话上下文、停止与恢复结果核对。 |

每个 Skill 包应包含适用任务、前置查询、相关工具 schema 引用、正常步骤、容易混淆的业务语义、三种权限模式下的处理、失败/重试/撤销路径及合成示例。Skill 版本与工具契约关联，修改工具或业务规则时同步更新对应指导和场景评测。Skills 不能跳过工具校验、代替模式判断、保存密钥或自创未注册的能力；不需要外部可执行插件才能满足这些指导需求。

## 执行协议与用户选择的权限模式

工具层先生成规范化的 `MutationPlan`，包含稳定 action ID、明确目标、最终参数、读取/写入集合、基线版本、影响列表及外部副作用。宿主执行器按用户选择的三种模式检查，允许执行或返回等待用户状态。执行票据绑定当前模式版本和这一次计划；模型自填 `confirmed: true` 不构成确认。

| 权限模式 | 执行契约 |
| --- | --- |
| 只读计划模式 | 可以查询、分析并生成变更计划；不调用修改软件数据、设置、文件或平台状态的工具。保存正常聊天和运行日志是宿主内部行为，不因此获得业务写权限。 |
| 每次修改前询问 | 每个明确的变更操作执行前，展示最终目标和变化并请求本次确认。一个真正原子批量操作可以用一份完整预览确认；不能把确认扩展成“本会话以后自动放行”，也不能把多批已分别提交的步骤伪装成一次原子修改。计划或目标发生变化后重新询问。 |
| 完全权限模式 | 可以连续执行全部可配置范围的合法修改，包括批量删除、覆盖恢复和清空；不额外加入按影响等级固定的逐次确认。缺少必要输入、对象歧义、数据冲突或系统要求的用户操作仍如实返回。 |

只提供上述三种模式，由用户在宿主界面选择。模式变化在实际提交前重验；从完全权限切回询问或只读后，旧执行票据不得继续提交。询问模式的确认仅用于对应操作及其幂等结果核对，不能授权后续新操作。

现有 HTTP 发送前确认、凭据目的地变更、导入警告等应用交互应映射到这三种模式：询问模式展示本次明确操作及目的地，完全权限模式可满足对应应用许可而不重复弹窗；只读计划模式不执行变更。请求绑定规范化端点和连接快照，敏感请求重定向保护继续执行。系统原生授权不会因完全权限模式而自动获得。实施时同步原行为文档和测试。

不论模式如何，schema/类型、数据引用、时间与重复规则、版本冲突、数据会话、存储恢复门禁和实际系统权限都必须验证。操作系统授权及用户真实同意事实由其所属系统产生，不能由模型写值代替。

结果应区分 `notFound`、`invalidArgument`、`conflict`、`authorizationRequired`、`writeBlocked`、`unsupported`、`cancelled` 和外部效果未完成，具体编码在协议落地时固定。成功回执包含实际对象 ID、数据版本和效果状态；重复 action ID 的重试返回原结果，不能重新创建数据。

当前 [AppDataVersions](../lib/models/app_data_commit.dart)是进程内域版本，不足以独立实现跨重启幂等。动作执行记录与业务写入必须建立可恢复关联，覆盖“业务保存成功、工具回复丢失、进程重启”窗口。不能只往另一个聊天日志写成功标志后宣称 exactly-once。

纯主数据批量变更应先用纯服务计算完整候选，再一次提交；循环执行多次 `saveCourse` 不等于原子批操作。现有仅五类偏好命令的队列合并不能自动推广为跨课表/日程事务。跨主库、学校站点、凭据、设备布局和平台效果时，使用分阶段可恢复工作流，明确 `dataCommitted` 与 `effectsPending`，不伪装成一个数据库事务。

撤销是受版本保护的新命令：核对受影响对象仍等于原操作的结果，再应用逆变更；不能整份恢复旧备份覆盖之后用户编辑。系统通知、外发文件和进程退出有各自效果边界，回执须如实说明。

## 覆盖门禁与实施验收

“全软件可管理”应由清单和契约测试持续保证，而不是靠首次手工列几十个工具。新增用户可配置字段或功能时，其能力描述、管理入口、权限标识、默认/reset、平台生效说明和验证应与功能一起进入同一原子变更。

建立以下覆盖门禁：

1. **字段分类清单**：逐个登记主数据序列化字段、侧存储 schema、设备偏好和新 Agent 配置。每项必须映射为可配置 descriptor、资源命令、派生/事实/内部状态或明确不适用理由。遗漏使契约检查失败；不是把全部 JSON 字段自动开放写入。
2. **枚举与扩展覆盖**：工作区、布局角色、工具栏 known IDs、设置目的地、平台能力、Agent/provider 字段及新增 agenda source 有对应覆盖断言。来源模型改变后必须更新描述或理由。
3. **同源行为**：UI 和 Agent 对相同合法输入产生相同领域结果；非法值、未知 key、无效引用和过期目标都不会靠默认 fallback 修改别的对象。UI 独有交互不成为业务必需依赖。
4. **停用域管理**：全部资源可查可改，不切工作区、不启用域、不产生该域提醒；重新启用时继续遵守提醒时间界线。隐藏分类按既有独立提醒偏好处理。
5. **完整字段与 reset**：所有配置支持有效 get/set/reset 或明确语义动作；验证默认值、null/继承、复合约束、存储兼容 key 与平台生效状态。
6. **凭据和事实**：创建/替换/删除凭据可完成且有读回验证，模型和日志不可见原文；不能写 OS 授权、接受时间、更新探测结果或内部恢复状态来制造成功。
7. **三种权限模式**：只读计划不写业务数据；询问模式每次明确修改前确认，原子批确认不扩展到后续操作；完全权限没有额外固定逐次确认。模式变化使旧票据失效，模型不能通过修改设置升级模式。
8. **并发与持久性**：用户编辑与 Agent 编辑冲突保留双方意图；批量失败不产生未声明部分提交；写成功而回执丢失后可恢复，不重复执行；恢复/清空让旧计划失效。
9. **平台与生命周期**：未知、拒绝、未实现与已授予状态分开；手机独立页面与桌面共享会话，离开页面/切换工作区不改变执行所有权。功能管理单开关关闭后隐藏入口、保留配置和全部会话、停止新请求并取消未提交步骤；已接受写入核对结果，不删除业务数据。退出等待已接收写入确定结果，但不无限等待模型网络回复。
10. **统一 AI 入口**：独立文字解析页、学校解析设置和旧独立模型调用退出产品；文字直接在会话处理，网页内容经过原压缩/校对后新建会话，JSON/ICS 文件直导不依赖 Agent。旧配置/密钥/备份迁移不能重新启用退役入口。
11. **共享 Skills**：所有领域能力都有相应操作指导；文字和网页导入、重复范围、批量设置、冲突及恢复都有合成场景，确认 Skill 所用工具和当前契约一致。
12. **真实场景**：使用合成数据验证“调整全部课表中的指定课程”“修改隐藏分类中的重复日程本次及以后”“批量修改停用域主题与默认提醒”“恢复所有显示设置”“网页校对后在新会话导入课程”“更换自选 API 凭据并开始新运行”等流程，以实际存储状态和回执为依据。

现有可复用回归入口包括[显式课表目标](../test/controllers/student_timetable_test.dart)、[课程服务](../test/services/student_timetable_service_test.dart)、[重复范围编辑](../test/services/general_event_scope_edit_test.dart)、[数据传输](../test/controllers/data_transfer_controller_test.dart)、[保存回执](../test/controllers/app_session_commit_test.dart)、[仓库批边界](../test/data/app_repository_batch_test.dart)、[备份隔离](../test/controllers/app_backup_restore_isolation_test.dart)、[密钥持久化](../test/controllers/school_import_secret_persistence_test.dart)、[端点授权](../test/services/school_import_http_consent_test.dart)、[设备布局](../test/services/desktop_layout_preferences_test.dart)和[Android 能力桥接](../test/services/android_productivity_bridge_test.dart)。新增能力需补目标明确的回归，不以旧测试存在代替新功能验收。

日期和重复改动遵守贡献指南中的五区原生时区检查。Widget、内存通知网关、模拟器、平台构建和实体设备分别记录范围；跨平台内置 Agent 不等于移动系统允许其全天后台运行，后台执行和进程恢复须另按平台约束验收。
