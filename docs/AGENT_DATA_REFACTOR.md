# 面向 Agent 的数据与应用重构规划

## 状态与结论

源码调查基线：`ea784f3a16e5d4a23aedae410544492fb6fa0f6f`，研究与表示实验日期：2026-10-30。查询投影、严格变更编译与共享保存边界已开始实现，AppData v5 已增加本机 Agent 配置和有界回执并分离便携/恢复编码；其余未标记的数据模型与紧凑格式仍是研究方案。合成数据表示对照单独记录在本文末尾；它不构成生产 token、任务正确率或运行性能的验收。

相关文档：[架构提案](AGENT_ARCHITECTURE.md)、[能力全集](AGENT_CAPABILITIES.md)、[共享 Skills](AGENT_SKILLS.md)、[实施计划](AGENT_IMPLEMENTATION_PLAN.md)、[harness 研究](AGENT_HARNESS_RESEARCH.md)。产品范围保持一个内置 Agent、多个会话、功能管理单开关、手机完整页面、共享 Skills，以及只读计划、每次修改前询问、完全权限三种模式。独立 AI 解析按既定方案退役；文字直接进入会话，网页保留压缩校对后新建会话，规范 JSON 文本及 JSON/ICS/节次文件继续支持确定性直接导入。

最先值得做的是**让模型只读取任务相关的投影，并用明确的语义 patch 修改数据**。这不需要先更换现有存档。随后补齐严格命令、索引、批事务和持久版本；紧凑磁盘格式、Course/Meeting 拆分及数据库替换分别按收益与迁移风险决策。

| 顺序 | 建议 | 主要收益 | 前提 |
| --- | --- | --- | --- |
| 先做 | 摘要/详情/编辑视图、过滤、聚合、短引用、typed patch | 减少无关模型输入和整对象输出，明确修改目标 | 契约清晰、完整性可知、未读取字段不被清空 |
| 同步做 | 草稿编译、时钟/ID、操作结果、版本与统一写协调 | UI 与 Agent 行为一致，重试与并发可核对 | 共享应用层和原有存储门禁 |
| 随领域做 | 复用日历索引、补课程索引、按需展开、批量一次保存 | 减少查询和变换工作量 | 不破坏已有结构共享、时区与缓存规则 |
| 后评估 | 版本化紧凑 StorageCodec | 减少磁盘冗余和全量编码体积 | 默认解释、严格解码、备份/journal兼容验证 |
| 独立决策 | Course/Meeting、SQLite、分区或增量存储 | 更丰富领域关系或解决实际读写瓶颈 | 真实需求和测量，不作为首个 Agent 闭环的前置 |

## 1. 分开磁盘、领域模型和模型 DTO

| 层 | 当前源码事实 | 目标 | 不能据此推断 |
| --- | --- | --- | --- |
| 磁盘格式 | [AppData.encode](../lib/models/app_data.dart#L502) 使用 `jsonEncode(toJson())`；[AppDataCodec](../lib/data/app_data_codec.dart#L12) 编码完整快照 | 可恢复、可迁移、合理空间与写放大 | 压缩文件变小，不代表模型 token 同比例减少；当前存档已经是无缩进 JSON |
| 内存领域模型 | 两个工作区分别持有课表/课程和分类/日程；纯服务产生新分支 | 身份、关系、不变量、结构共享、索引和持久提交 | List 改 Map 不天然更省内存或磁盘；当前日历已有索引 |
| 模型工具 DTO | 新 Agent 工具尚待实现，可以独立设计 | 任务相关字段、有界结果、稳定引用、明确变更、可纠正错误 | 模型不需要看懂或回吐整份磁盘格式 |

建议明确三个转换边界：`StorageCodec`、`PortableExportCodec`、`AgentProjectionCodec`。完整恢复 journal 与便携备份还应使用不同编码契约：前者保留本机恢复操作和目标数据世代，后者不携带旧运行许可。

一个日程实例在内存中持有 `GeneralEvent` 与 `GeneralSchedule` 引用，分类又含事件列表，见 [GeneralEventOccurrence](../lib/models/general_event_occurrence.dart#L11)。这对 UI 不等于复制了整分类；若直接序列化这个对象图给模型，才可能反复发送无关事件。应增加专门投影，不能为解决传输问题盲目重写内存对象图。

## 2. 模型查询视图与修改协议

### 2.1 具名视图与字段选择

先提供少量明确的 `summary`、`detail`、`edit` 视图，必要时增加受 schema 限制的字段选择。列表通常只返回 ID/ref、名称、所属资源、相关时间、必要状态和版本；备注、自定义字段、完整重复规则、审计和诊断按需读取。这个方向参考 [Google AIP-157 的部分响应设计](https://google.aip.dev/157)与 [Anthropic 的工具结果设计](https://www.anthropic.com/research/writing-tools-for-agents)，具体视图仍由 Sked 任务与评测决定。

- `timetables.list`：名称、开学日期、总周数、课程数、时间集引用，默认不展开所有课程。
- `courses.query`：按课表、名称、教师、周次或日期筛选；只返回任务所需课程字段。
- `events.query`：明确查询系列记录还是实际实例，不把无限重复全部展开。
- `agenda.free_slots/conflicts/count`：由确定性代码计算空闲、冲突和数量，不让模型阅读全库后心算。
- `settings.describe/get`：只返回指定 key/设置组的类型、值、默认与 reset 语义。
- `operations.status`：返回实际变更数量、对象引用、提交版本与效果状态；完整 before/after 供 UI 或后续工具展开。

查询结果必须说明视图版本、字段集、范围、基线和完整性。没有返回 `notes` 只表示此视图未提供，不表示备注为空。只读投影可以省略不相关内容，写入必须保留这些内容。

### 2.2 先过滤，再展开和分页

当前 [GeneralOccurrenceService.occurrencesForQuery](../lib/services/general_occurrence_service.dart#L39) 先展开，再按文字/颜色匹配；[GeneralOccurrenceQuery](../lib/models/general_event_occurrence.dart#L157) 尚无精确分类/事件 ID 过滤。新工具查询应先限定资源集合和可前置的 metadata 条件，再展开相关系列；依赖实际实例的条件保留在展开后。

分页不能简单 `take(20)` 后隐藏剩余结果。游标绑定查询条件、排序和数据基线，数据变化导致失效时明确返回 stale。优先返回可继续读取的有界结果，避免先建立全量巨大 List 再截断。[MCP 分页规范](https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/pagination)提供 opaque cursor 的参考，但不会自动为 Sked 的业务工具实现分页。

页数过多也可能增加工具往返、重复上下文和总 token。用户要求“修改所有符合条件的课程”时，应固定完整选择集合并返回 `selectionRef`、数量、摘要和可查看的完整预览；不要求模型分页读出每个对象后逐字重发。

### 2.3 短 ref 与完整结果分层

可用宿主生成的短 `ref` 指向真实稳定 ID；映射需包含资源类型、数据世代和版本，并随相应会话/结果记录保存。不能使用随排序变化的行号、随意截断 UUID 或只留在模型记忆里的别名。`ref` 只是寻址，不授予写权限。

长网页、原始导入资料、完整诊断和大查询结果可保存为 `sourceRef/resultRef`，先返回摘要，再按段落、行或字段读取。共享分类名、课表名、时区等可放在结果头部，混合数据使用显式覆盖。

宿主保留 canonical result，为 UI 和模型分别生成投影。不能假设 MCP 的 `structuredContent` 对模型免费或不可见；[MCP tools 规范](https://modelcontextprotocol.io/specification/2026-07-28/server/tools)还描述兼容文本表示，客户端若重复拼接两份结果仍会增加上下文。内置 provider adapter 应明确只发送一份需要的模型投影。

### 2.4 Typed patch 保持未修改字段

以下是拟议工具参数和合成数据，不是当前 API：

```json
{
  "target": {"kind": "course", "timetableId": "t1", "ref": "c7"},
  "ifRevision": 12,
  "set": {"location": "A302"}
}
```

“改教室”无需重新生成教师、学分、周次、分钟、`timeRange` 和 `customFields`。宿主解析 ref，读取当前实体，编译意图、校验并保存；返回实际新版本。批量同一变更使用 `patchMany(selectionRef, set)`，不让模型重复输出几十份完整对象。

| 表达 | 必须固定的语义 |
| --- | --- |
| 字段未出现 | 保持原值 |
| `set.notes = ""` | 明确清空备注 |
| `set.color = null` | 仅对允许继承的字段清除显式覆盖 |
| 默认提醒分钟设为 null | 关闭默认提醒，不是未修改 |
| `reset` | 恢复 descriptor 指定的默认/继承，不盲删必需存档字段 |
| 修改重复日程 | 明确实例引用和本次/以后/全系列范围，复用专门变换 |
| 修改自定义字段 | 明确整个 Map 替换或受控 key patch；不能因读取截断覆盖完整值 |

现有 [GeneralEvent.copyWith](../lib/models/general_event.dart#L329) 已区分 sentinel 与 null，但只传 reminders 还会联动改变提醒策略。工具应把提醒作为语义对象校验，不能把 Dart 的宽松构造参数直接搬成外部 schema。新工具拒绝未知字段和非法目标；兼容解码中的 fallback 不能让一次错误修改变成“成功创建默认数据”。

询问模式针对每个明确变更操作确认，完整原子批可一次确认；不延伸成后续免确认。完全权限不新增固定逐次确认；只读计划不提交业务修改。短 ref、小 DTO 和批量接口均不改变三种模式。

## 3. 课表、日程和设置的具体冗余

| 当前表示 | 源码依据 | 可做的优化 | 兼容边界 |
| --- | --- | --- | --- |
| 课程分钟与 `timeRange` 同存 | [CourseItem.toJson](../lib/models/course_item.dart#L180)、[课程归一化](../lib/services/student_timetable_service.dart#L381) | 写 DTO 不要 timeRange；新磁盘 codec 可省略并派生 | [存档校验](../lib/models/app_data_storage_validation.dart#L389) 当前要求其与分钟一致，不能只删字段 |
| 分类内每个事件再存 calendarId | [GeneralSchedule](../lib/models/general_schedule.dart#L61)、[GeneralEvent](../lib/models/general_event.dart#L262) | 新嵌套磁盘格式由父分类注入；内存/全局 DTO 保留明确归属 | 独立事件或跨分类结果仍需父引用；旧校验要求一致 |
| 节次 index 与数组位置重复 | [CoursePeriodTime](../lib/models/course_item.dart#L18)、[节次构造](../lib/utils/time_utils.dart#L239) | 新磁盘可按有序起止列表恢复编号 | 重排会改变引用含义；工具仍使用可理解节次编号 |
| 分类 sortOrder 与列表顺序重复 | [分类模型](../lib/models/general_schedule.dart#L61)、[增量归一化](../lib/models/general_schedule_normalization.dart#L120) | 只选择一个持久顺序真源 | 保留用户重排，不能擅自改成字母序 |
| 空备注/地点/例外/提醒及 none 规则重复 | [GeneralEvent.toJson](../lib/models/general_event.dart#L262) | DTO 按需省略；版本化 codec 可省安全空值和不重复对象 | 当前严格校验大量必填；提醒策略缺省有历史语义 |
| 固定频率同时保存 type/unit | [GeneralEventRecurrenceRule](../lib/models/general_event.dart#L108) | DTO 用清晰的频率、间隔、边界；新 codec 可去掉未使用字段 | 不能丢 COUNT、UNTIL、月末锚点及例外 |
| 两域设置每次完整序列化 | [StudentModeData](../lib/models/student_mode_data.dart#L127)、[GeneralScheduleData](../lib/models/general_schedule_data.dart#L366) | 模型按 key/组读取；磁盘稀疏默认后评估 | 两域主题是独立用户配置，不因值相同合并成共享可变值 |
| 长正文、timestamps、提醒处理历史 | [课程字段](../lib/models/course_item.dart#L165)、[事件字段](../lib/models/general_event.dart#L222) | 列表给必要摘要与详情引用 | 不为 token 删除业务原文或处理记录；updatedAt 不是并发版本 |
| 整份 AppData 编码保存 | [AppRepository.save](../lib/data/app_repository.dart#L215)、[文件写入](../lib/data/timetable_storage_io.dart#L354) | 先让一批变更只保存一次 | 小工具 patch 不代表磁盘已支持增量更新 |

默认偏好数量是固定开销，课程/日程正文与重复记录随数据增长。优先剔除模型不需要的对象和字段，再决定是否值得为少量磁盘默认键承担迁移成本。

## 4. 默认值、未知字段与紧凑存储

### 4.1 不能按构造函数默认值统一删字段

当前已有局部省略：默认面板模式、默认通知对象、null 元数据、默认课程继承提醒等，见 [AppData.toJson](../lib/models/app_data.dart#L254)与 [CourseItem.toJson](../lib/models/course_item.dart#L196)。这些局部合同不能推广为通用规则。

| 陷阱 | 当前证据 | 影响 |
| --- | --- | --- |
| 新建默认与旧存档缺失值不同 | `includePrereleaseUpdates` 构造默认 true，但[读取缺失值为 false](../lib/models/app_data.dart#L398)；[新用户默认](../lib/controllers/app_data_defaults.dart#L39)还取决于发布渠道 | 省略“等于构造默认”的 true，回读可能变 false |
| 缺提醒策略不等于新建 inherit | [GeneralEvent 构造](../lib/models/general_event.dart#L204)依据 reminders 推导 disabled/custom | 省略 inherit 可能关闭提醒 |
| 空周次代表每周 | [matchesSemesterWeek](../lib/utils/semester_helpers.dart#L32)；[校验保留超学期显式周次](../lib/models/app_data_storage_validation.dart#L354) | 缩短学期后把周次裁空会意外变成每周 |
| null 有不同含义 | 日宽 null 为自动；提醒 null 为关闭；颜色 null 为继承 | 通用 merge/delete 会混淆用户意图 |
| 等于默认不证明用户选择来源 | 大多数现有字段只保存有效值，没有“显式设置/跟随默认”的 provenance | 不得推断用户愿意未来随默认变化 |

推荐领域内存保留完整有效值，紧凑 StorageCodec 使用**版本固定的默认表**。先按旧版本默认物化，再迁移；新默认改变时，需要保留的旧值成为显式覆盖。若以后产品需要“始终跟随当前默认”，才增加 overrides/provenance，并规定显式 set 与 reset 的不同含义。

当前课程文本、周次、节次、分钟、学分、自定义字段以及事件归属、全天、例外、重复对象、提醒集合有严格必填规则，见[课程校验](../lib/models/app_data_storage_validation.dart#L276)与[事件校验](../lib/models/app_data_storage_validation.dart#L494)。新紧凑格式必须先经过对应版本解码并恢复完整语义，不能保存后在重启时被既有校验判断成损坏。

### 4.2 未知字段不是已有的无损扩展系统

`fromJson` 和 `toJson` 主要选择已知字段；[MigrationRunner](../lib/data/migrations/migration_runner.dart#L38) 暂时深拷贝未知字段，不代表最终 typed round-trip 会保留它们。`CourseItem.customFields` 才是明确支持的用户扩展 Map，内部合法 JSON 结构需保真。

新写工具拒绝未知参数，避免拼写错误被静默忽略；旧存档继续按已发布 schema 兼容读取；未来版本继续拒写。若将来需要第三方扩展无损往返，应设计有命名空间、预算和维护规则的 `extensions`，不把任意未知字段自动升为设置或指令。

改变 List/Map 结构、范围编码或扩展袋时，同时更新[导入计数](../lib/models/import_count_limits.dart#L6)，包括未知数据和未归一化原始条目。工具 token 预算不能替代文件字节、深度和集合数量限制。

### 4.3 紧凑格式必须独立于恢复协议

新增持久版本、operationId 和回执会增加少量元数据，但能简化可靠修改与重试，这是必要的正确性成本。便携备份排除本机执行资格，本机恢复 journal 保留恢复操作及预先固定的目标世代。不能在共同 `toJson` 中统一删字段，导致恢复证据和普通导出一起消失。

## 5. Course/Meeting、时间与重复规则

### 5.1 CourseItem 当前更接近授课安排

[CourseItem](../lib/models/course_item.dart#L165) 同时包含课程资料和单个星期、周次集合、时段。一门课每周多次上课时可能重复名称、教师、学分和其他元数据。

只有当产品经常需要“修改整门课程的公共资料”“调整一条授课安排”或可靠课程分组时，才独立考虑 `CourseDefinition + CourseMeeting`。公共字段与 meeting 覆盖必须明确；不同教师、班级或学期的同名课不能自动合并。现有 courseId 关联通知、冲突和编辑目标，迁移可保留为 meetingId，新增 definitionId，并验证关联状态。

把每条旧记录先迁成一个 definition+meeting 最稳，但最初反而可能增大数据。去重收益必须来自可靠源标识或明确分组；不能为追求体积直接合并同名课程。这个拆分也不自动获得“仅某日期调课”，后者还需要例外/覆盖模型。

首期用现有 CourseItem、精确查询和批量命令即可完成 Agent 任务；Course/Meeting 不成为 P3 的前置。

### 5.2 时间来源不能被压缩抹平

[resolveCourseTimeRange](../lib/utils/semester_helpers.dart#L9) 规定有效显式分钟优先，只有 `(0,0)` 才从节次推导。即使分钟碰巧等于作息，也不能推断它应该跟随未来时间集变化。

工具可采用 `keep / explicitMinutes / periodBinding` 的时间意图；查询返回来源与显示值。新的持久 tagged union 若要替代当前双字段，须按已有含义迁移。只改课程名称不得把推导时间固化。

工具周次可使用 `all`、有序范围和 step，由宿主转换成合法集合；存档可暂时保留整数列表。不要让模型计算位掩码，也不要按当前总周数裁掉历史休眠周次。范围编码收益可测后再决定是否落盘。

日程仍区分本地浮动、UTC/显式偏移和全天民用日期。全部换成 Unix timestamp 会丢失浮动重复意图，全部改成无时区钟面字符串又会丢失确定瞬间。任意 IANA 时区的持久重复模型是独立产品设计，不应以字符串压缩名义顺带改变。

### 5.3 精简重复表示，保留重复数学

固定频率的 type/unit 可以在 DTO 中归一为清晰表示，但 COUNT、UNTIL、月末锚点、排除日期与实例编辑范围不是冗余。[hasSameGeneralRecurrenceStep](../lib/models/general_event_occurrence.dart#L850) 已比较实际步长，[例外映射](../lib/models/general_event_occurrence.dart#L872)已区分同频平移与变频。新工具和 Skill 调这些规则，不让模型自行展开/拆分无限系列。

## 6. 内存查询与更新：保留已有优化

| 当前实现 | 可继续改进 | 不应采用的捷径 |
| --- | --- | --- |
| [GeneralScheduleSnapshot](../lib/models/general_schedule_normalization.dart#L3) 按分类保留 eventsById、byScheduleId 和未变分支 | 按 `(calendarId,eventId)` 精确查询，复用索引；必要时增加查询适配 | 改成每次复制整域的大 Map，再声称必然更快 |
| [StudentTimetableService.saveCourse](../lib/services/student_timetable_service.dart#L100) 查课表、复制目标列表、收集全域 ID | 可补 StudentSnapshot、每表 course 索引和 ID membership；批量只变换一次 | 在每次查询 deep copy 全库，或同时持久保存 list/map 双真源 |
| [GeneralOccurrenceCache](../lib/services/general_occurrence_cache.dart#L23) 已有有界 LRU；[ExpansionCache](../lib/services/general_event_expansion_cache.dart#L8)限制保留值并避开本地时区相关几何 | Agent 查询使用独立预算，避免宽范围任务逐出 UI 热点；共享只读索引 | 用当前 UTC offset 充当历史时区版本，或无界缓存所有实例 |
| 部分 normalized 路径冻结集合，但 public 构造器仍接收 List/Map | 在新输入/命令/发布边界验证并深冻结，保留未变分支 identity | 以 `final` 字段等同所有嵌套内容不可变 |
| [严格解码](../lib/models/app_data.dart#L508) 先迁移，随后 fromJson 再经迁移 runner | 独立评估消除重复深拷贝，保留公共宽松与严格入口 | 未验证就合并所有解码、丢失原有拒写/恢复语义 |

进一步的全文索引、区间树、worker 池、共享大缓存或 SQLite 索引必须有实际工作量证据。精确过滤下推可先用 spy expander 验证“不展开无关系列”，不依赖机器速度断言。

## 7. 全软件还需要哪些应用层重构

这些改动与存储编码分开，直接决定 Agent 是否能正确操作现有软件。

| 重构点 | 具体问题与源码 | 建议边界 |
| --- | --- | --- |
| 数据工作区、功能、导航分离 | [功能页](../lib/screens/workspace_features_page.dart#L149)遍历 AppMode；[导航映射](../lib/screens/adaptive_sked_shell.dart#L113)围绕两个域 | Agent 用功能注册/单开关与独立 destination，不加入第三 AppMode，不影响至少一个数据域启用或提醒计数 |
| 草稿编译与时钟/ID | [课程提交](../lib/widgets/course_editor_sheet.dart#L971)包含保留旧时间的意图；[日程提交](../lib/widgets/general_event_editor_sheet.dart#L368)构造时间戳 | `DraftCompiler(baseline,intent,context)` 返回严格命令/字段问题；Clock、ID allocator、locale、时间基准显式注入 |
| 操作与路由生命周期分离 | [TaskSession](../lib/widgets/sked_task_session.dart#L14)含 Route；[提交控制器](../lib/widgets/sked_task_submission_controller.dart#L37)结合 saved、mounted 和 isCurrent 返回 bool | `OperationScope` 管数据世代/取消/模式；`RouteScope` 只管页面关闭与草稿展示；页面消失不把已提交结果改成失败 |
| 结果与问题协议 | [UI 命令反馈](../lib/widgets/ui_command.dart#L10)主要给通用保存失败 | typed outcome 区分 committed/noChange/conflict/cancelled/failed/unknown；业务 InputRequest 与操作 ApprovalRequest 分开 |
| 来源、候选、计划三段 | [PreparedDataImport](../lib/controllers/data_transfer_controller.dart#L14)绑定 controller/session/workspace | `SourceAsset → DecodedCandidate → PreparedMutation`；纯外部材料解释不依赖当前页面或可写快照，提交才绑定实时目标 |
| 字段约束同源 | 模型、服务、Commands、ViewState、控件分别罗列设置 | `FieldSpec` 复用 type/enum/range/default/reset/单位/翻译键，生成或构建工具 schema 与描述；组合不变量仍用纯业务校验，不替换所有 UI 为万能表单 |
| 通知效果归属 | [reconcileNow](../lib/services/agenda_coordinator.dart#L262)返回 void，内部可能重试/被新 epoch 替代 | `EffectTicket` 关联数据世代、desired revision和投影 epoch，返回 pending/applied/superseded/failed/unknown；复用原 owner |
| 平台动作能力状态 | [通知网关](../lib/services/agenda_notification_flutter_gateway.dart#L1025)、[Android 桥接](../lib/services/android_productivity_bridge.dart)的能力与授权不同 | `CapabilityState` 区分 implemented、availableNow、observableState、requiredAction；unknown/unsupported/denied 不互换 |
| 分享与保存结果 | [ExportService](../lib/services/export_service.dart#L51)包含不同平台路径和分享返回 | 文件生成、保存、打开分享面板和实际送达分别回报；不把 Future 完成描述成已送给某个人 |
| 发布与聊天流分离 | [ObservableViewState](../lib/controllers/observable_view_state.dart#L19)、[AppScope](../lib/providers/app_scope.dart#L43)已有分域发布 | 单独 ConversationViewState/RunProgress/TokenBuffer，显示节流不吞工具提交事件；token 不进入 AppData 保存或提醒链 |
| 多会话调度与退出 | [AppQuiescence](../lib/controllers/app_quiescence.dart#L26)尚需认识运行队列 | 每会话有序、应用共享写协调和模型预算；长任务在显式批边界让出执行，不能持主数据锁等待模型 |

关闭功能与离开页面保持不同语义：离开页面只移除观察者；关闭 Agent 隐藏入口、拒绝新请求、取消未提交步骤并核对已接受写入，保留会话和配置。以上不需要多 Agent 系统，也不要求全面更换当前状态管理框架。

UI 与工具可以选择性共用合成 `ScenarioSpec`：初始数据、意图、固定时钟/ID、应变和不应变字段、失败点。它用于语义断言，不把整个测试套件改造成与实现互相复制的 DSL。

## 8. 紧凑 JSON、表格、压缩和 SQLite 的取舍

| 表示/技术 | 合适位置 | 结论与验证要求 |
| --- | --- | --- |
| 可读 JSON 对象 | 稀疏/嵌套结果、复杂编辑、重复规则 | 作为模型基线；字段语义明确，先优化投影 |
| 无缩进 JSON | 机器生成的工具正文或存档 | 去无意义空白；当前 AppData 已使用这一形式，不能重复计算收益 |
| `columns + rows` JSON | 同质平坦查询列表 | 减少逐行键重复；必须验证列序、行宽、类型、null/缺失和截断；读表示可试，写入仍用 typed command |
| TSV/CSV/TOON | 受控只读表格实验 | 按同一信息量比较，计入格式说明/表头；嵌套、换行、引号与混合类型需回归和模型评测 |
| 共享头/字典 | 重复分类、课表名、时区与字段说明 | 保留局部覆盖，字典本身也计入文本体积 |
| gzip 或其他二进制压缩 | 磁盘、附件或传输 | 与模型语义输入分开；模型最终读取解压内容时仍承担对应上下文 |
| gzip 后 Base64 放进文本 | 程序间封装 | 不是可靠的模型可读压缩方式；不因字符串看起来短就采用 |
| SQLite/分区存储 | 已证实的随机查询、增量写入、事务或档案规模瓶颈 | 不直接减少模型 token；跨平台驱动、Web、迁移、备份和原生消费者需独立验证 |

如果将来选择 SQLite，应按实体建立可索引结构，并明确事务与迁移协议；只把整份 AppData 放入一个 JSON BLOB，仍可能保留整快照变换/重写问题。[SQLite JSONB](https://sqlite.org/json1.html)主要减少解析及内部表示成本，不承诺普遍 O(1) JSON 元素查找；[WAL](https://sqlite.org/wal.html)仍有单写入者、checkpoint 和附属文件的管理要求，也不提供跨多个数据库文件的整体事务。先用实际 Agent 工作量比较，不能从“换了数据库”直接推出空间、token 和所有读写都改善。

[TOON 固定版本 benchmark](https://github.com/toon-format/toon/blob/e247c423e0a38bca3477b17fecdf6ef4feeb5584/benchmarks/README.md)分别测试文本 token 与检索理解，并明确不测试模型生成 TOON 的能力。因此不能把上游比例直接应用到 Sked 的编辑正确率或所有自选 API。[Anthropic 工具设计](https://www.anthropic.com/research/writing-tools-for-agents)也将结果格式作为需要按任务评测的选择。

不建议把所有键缩成单字母、让模型计算位图、持久 ID 全部重编号、为省 token 删除时区/范围语义，或开放 `execute(anything)`/任意 JSON 覆盖工具。也不因“AI 会读取很多数据”立即引入向量库、全文引擎、区间树或新状态框架。

## 9. 大量共享 Skills 与上下文预算

丰富共享 Skills 与小常驻上下文可以同时存在。先提供技能目录摘要，命中任务时加载正文，复杂规则附录再按需读取；这符合 [Agent Skills 的 progressive disclosure](https://agentskills.io/specification)。具体 Sked 的 24 项任务包、manifest、版本和回归见[共享 Skills 设计](AGENT_SKILLS.md)，不在这里另建一套私有技能模型。

工具 schema 也按任务包加载。宿主必须把后续将使用的工具真正注册到 provider 请求，而不是只把 schema 文本写进工具结果就假定模型能调用。对不支持原生工具搜索的自选 API，可由宿主选包或在下一请求重建工具集；简单任务不必为了发现工具强制多走一轮。

Schema、结果投影、Skill 和当前执行模式分别记录版本。历史压缩保留意图、来源引用、未决问题、计划和 operationId；业务状态重新查询，不能把模型摘要当新的数据库真相或确认凭证。完整诊断和来源可在宿主持有，不每轮重复回传。

## 10. Token、缓存与格式指标分开

| 指标 | 能说明什么 | 不能说明什么 |
| --- | --- | --- |
| UTF-8 bytes / gzip bytes | 当前表示或文件的大小 | 模型输入 token、运行正确率、真实网络流量 |
| 指定编码器的正文 token | 这份解码后文本在该编码器下的代理计数 | 任意自选模型的完整请求或账单 |
| 官方完整请求计数 | 指定 model/messages/tools/schema 的发送前计数 | 模型最终输出、任务重试和全部费用 |
| 真实 usage | 本次调用输入/输出/推理/缓存等实际返回值 | 其他 provider 的字段口径或未来任务效果 |
| 任务累计 | 所有轮次、分页、补查、纠错、摘要和重试成本 | 单个工具结果变小就一定更省 |
| 最终任务正确性 | 对象、重复范围、真实存档和回执是否正确 | JSON 可解析就代表模型会正确操作 |

[OpenAI token counting](https://developers.openai.com/api/docs/guides/token-counting)明确完整请求包含角色、边界和工具/schema 等开销，本地文本编码器不能代表整个请求。不能直接对原始 HTTP envelope 做 tiktoken 后标成真实模型输入；应比较 provider 解码后实际进入模型的工具正文，并单列尚未计入的结构。

缓存复用稳定前缀的计算，不会使那部分上下文 token 消失。[OpenAI prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)说明工具定义/顺序、格式 schema 和其他前缀内容会影响复用；会话存在本身不保证命中。建议稳定公共指令与工具包在前，变化资料在后，避免在可复用前缀中无谓插入随机值。

不同 provider 的缓存参数、usage 字段、计费口径分别适配；不能向所有“兼容 API”发送同一套缓存选项。原始输入、cache read/write、输出/推理、总轮数分别记录，避免 input 已包含 cached 时重复相加。权限收紧和实时事实必须正确更新，不能为了缓存命中继续使用旧模式或旧目标。

## 11. 对齐 P0–P8 的实施优先级

| 既有阶段 | 本文补充的落地点 | 阶段判据 |
| --- | --- | --- |
| P0 | 三层 codec/view 契约、FieldSpec、默认/null/reset、时钟/ID、持久版本、来源交接和计量口径 | 旧默认陷阱、显式/继承、未知字段和回执边界有确定规则；不冻结未经测量的省 token 比例 |
| P1 | summary/detail/edit、精确过滤下推、稳定分页/ref、严格 DraftCompiler 和 typed patch | 未返回字段不丢；同名/失效目标不回退；不展开无关系列；所有配置仍可发现 |
| P2 | selectionRef、共享读取—变换—提交、一次批保存、资源版本、操作/effect 回执和撤销 | 覆盖旧 UI 乐观内存窗口；重试不重复；短引用/游标/计划跨世代失效 |
| P3 | provider 正文/完整请求/usage 分层、最小共享 Skill 包、独立聊天发布与基础调度 | 一个完整任务可实际执行和核对；不依赖全库序列化或模型自报成功 |
| P4 | 课表/日程投影与语义 patch、学生域索引、重复范围和提醒处理 Skills | 原有时间/周次/重复/关联状态保持；Course/Meeting 作为独立可选升级，不阻塞此阶段 |
| P5 | 设置同源描述、旧 AI 退休、来源—候选—计划、凭据迁移、平台/effect adapter | 网页压缩后交接去重、JSON 文本/文件直导保留；旧 customPrompt 不升级为系统指令 |
| P6 | 在 P1/P3 已完成的操作作用域与基础导航之上完善正式 UI、聊天分页和流发布 | 手机完整页面与桌面一致；关功能和关页面行为不同；不会因页面销毁误报保存失败；基础 OperationScope 不延后到 P6 |
| P7 | 24 项共享 Skills、按需工具/schema、摘要/ref 恢复、provider 用量归一化 | 长会话不丢关键回执；加载成本、轮数和查询完整性可观测 |
| P8 | 同义编码对照、必要存储迁移回归、真实模型任务评测与平台/性能证据 | 字节/token/正确性/延迟分别报告；只有实际瓶颈证据才决定 SQLite、分区或复杂索引 |

FieldSpec、功能/导航、来源交接、平台状态与 Skills 可按文件所有权并行；全应用写协调、存储格式和迁移收口需串行核对。不要在同一轮同时更换日期模型、课程身份、默认语义、存储后端和 UI 框架。

## 12. 合成数据表示对照

### 12.1 方法与范围

在 Windows 上用真实 `AppData.encode()` 导出两组纯合成数据，并用 `AppData.decodeStorageSnapshot` 严格回读。没有打开个人存档、运行模型或修改产品存储实现。

- **小样本**：2 张课表共 60 条课程，3 个分类共 120 条日程；中英文名称，空/非空备注，普通/每周重复，继承/自定义提醒，连续/隔周周次及一个隐藏分类。ID 和时刻固定，不使用随机数据或当前时间。
- **规模夹具**：[PerformanceFixtures](../benchmark/src/benchmark_fixtures.dart) 的 version 5，5,000 条课程 + 5,000 条日程，直接使用其 `appData`；不是性能协议中的延迟采样。
- **编码**：Python 3.10.11，tiktoken 0.14.0，明确选择 `o200k_base` 与 `cl100k_base`。下面是候选工具正文/参数 JSON 文本的离线代理计数，不把它们映射为某个自选模型。
- **大小**：UTF-8 字节；gzip level 6，mtime=0。未测文件系统分配大小、实际 HTTP 流量、压缩耗时或内存。
- **检查**：两组稀疏表示展开后逐字段值相同，再通过生产严格解码并比较重新编码结果；列表对象与列/行表示也逐行比较值一致。这些检查不验证模型读写准确率。

工具比较计入了结果中的表头、列名、分页和基线字段；未计入额外格式教学、system/role、工具 schema、前序查询、对话历史、失败重试与真实模型输出。当前 Sked 尚无正式 Agent，本实验比较的是拟议接口，不是测得现有 Agent 已经减少费用。

### 12.2 模型侧的表示与修改接口

| 对照对象 | UTF-8 字节 | o200k_base 文本 token | cl100k_base 文本 token |
| --- | ---: | ---: | ---: |
| 20 条日程完整记录 | 8,909 | 3,042 | 3,047 |
| 同 20 条的列表摘要 JSON | 3,192 | 1,265 | 1,288 |
| 同一摘要值，改为 columns + rows JSON | 2,291 | 963 | 1,005 |
| 同一摘要值，带两空格缩进 | 4,395 | 1,690 | 1,715 |
| 改一个地点，提交整条日程 | 556 | 187 | 190 |
| 同一修改，提交 ID + revision + 字段 patch | 90 | 27 | 27 |
| 同时改 20 条地点，提交完整记录集合 | 8,948 | 3,078 | 3,091 |
| 同一修改，固定 20 个 ID + 公共 patch | 426 | 123 | 123 |
| 同一修改，仅 selectionRef + 公共 patch 的写参数 | 94 | 26 | 27 |
| 样本两工作区已序列化偏好子集 | 1,594 | 389 | 382 |
| 仅查询日程 showWeekends 与 timeGridMinutes | 104 | 26 | 26 |

摘要保留 `id/title/start/end/isAllDay/repeats`、分类头和分页基线；没有提供完整备注、提醒策略、例外和审计时间。它适合概览和选目标，**不等价于完整编辑视图**。按 o200k_base 计，完整记录到摘要减少 58.42%；这是任务投影收益，不能称作全数据无损压缩。

这 20 条记录取自小样本首个分类；本节百分比使用 o200k_base。设置子集来自两工作区的序列化偏好，排除了课程/日程资源、当前资源选择、提醒处理记录和课程名称颜色映射等内容；389 不是整个软件全部配置的 token 数。

同一摘要值由对象 JSON 改列/行 JSON，再减少 23.87%。这一步保留了同样的值，也仍需评测模型的列对齐、换行文本和缺省理解。未来若需要额外格式说明，应把它算入任务总成本；本结果不直接决定默认改用表格。

单项 patch 的写参数比整对象减少 85.56%；20 项公共 patch 比逐条完整对象减少 96.00%。两者都依赖宿主保留未修改字段和核验版本。selectionRef 数字**仅是写参数**，没有免掉先前建立完整选择集合的查询与确认成本，不应单独当作整任务节省比例。

设置的二字段结果只服务那两个设置的问题；用户询问全部设置时仍需完整目录/分页。减少结果不意味着缩减软件可管理范围。

### 12.3 磁盘稀疏表示实验

实验采用明确标注 `sked-sparse-study-v1` 的临时封装，没有交给当前 Sked 当存档使用。编码只做以下可逆变换：

1. 省略等于已固定默认的课程空字符串、0.0 学分、空 customFields；事件的空位置/备注/例外/提醒、false 全天和精确匹配的 none 规则。**保留 reminderBehavior，不省略设置默认值。**
2. 事件 calendarId 与父分类相同时省略，展开时从父级恢复；不一致时保留原值。
3. timeRange 仅在与分钟按既定格式推导出的字符串完全相同时省略；其他文本保留。
4. 连续周次可变为有序起止范围，只有表示确实更短时采用；隔周列表不强行展开成更长范围。不按总周数裁剪。
5. 节次编号仅在等于数组位置 + 1 时省略；其他编号保留。没有改变分类顺序或把已有课程合并。

| 数据 | 当前 UTF-8 | 稀疏候选 UTF-8 | 原始字节变化 | 当前 gzip | 候选 gzip | gzip 变化 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 60 课程 + 120 日程 | 76,105 | 52,426 | −31.11% | 4,552 | 3,932 | −13.62% |
| 5,000 课程 + 5,000 日程 | 4,100,734 | 3,120,910 | −23.89% | 208,440 | 211,387 | **+1.41%** |

两组候选均恢复了原始 JSON 的全部字段值，且生产严格解码后的结果一致；这不等于已完成一个通用的新 StorageCodec。真实迁移还需要缺省/非法/旧版本、损坏恢复、未知字段、字节/集合预算、journal、原生消费者和全部平台测试。

规模夹具的原始字节更少，但 gzip 结果反而稍大，说明去掉结构冗余会改变压缩模式，不能承诺所有空间指标同时改善。规模夹具有较多重复文本，压缩率也不能外推到长篇独特备注或真实用户数据。gzip 只在存储/传输层使用时节省字节，不能把 gzip 字节数标成模型 token。

用于识别此次导出的 SHA-256：

| 导出 | SHA-256 |
| --- | --- |
| 小样本当前存档 | `b3af8165522c4d7d06d53cdd06c01bbbcf17795cf78d69c98566a01340bd4476` |
| 规模夹具当前存档 | `d67df06f19571a619deea7c83622581e830f14cd291d4ddeb333a6d20cec9160` |

### 12.4 执行证据与下一轮验收

生成脚本、计数脚本、依赖、导出和原始结果保留在系统临时目录。执行命令形态如下；没有将临时脚本或 tokenizer 加入项目依赖：

```text
flutter test --no-pub --concurrency=1 --reporter=expanded <临时目录>/export_samples_test.dart
python <临时目录>/measure_representations.py
flutter test --no-pub --concurrency=1 --reporter=expanded <临时目录>/verify_roundtrips_test.dart
```

导出检查、两组候选的生产严格解码往返，以及同投影表格的值比较均完成。未运行应用完整测试或发布构建；未测 provider 完整请求计数、真实 usage、任务准确率、工具轮数、首字/总延迟、实际网络字节或生产成本。

这组结果支持先实施投影和语义 patch，列/行格式保留为模型评测候选，紧凑存储作为独立迁移实验。正式采用前，必须比较同名对象选择、复杂重复编辑、null/继承、分页完整性、引号/换行文本、错误纠正和重试后的最终业务状态；验收按完整任务累计 token，而不是只选最好看的单条结果。
