# 可靠性验证指南

本文维护存储、安全、生命周期与持续集成的验证约束，不记录某次检查的通过状态。每次发布的实际证据和未完成事项集中在 [发布验收](RELEASE_ACCEPTANCE.md)；依赖迁移见 [依赖维护](DEPENDENCY_UPGRADES.md)。历史运行日志、测试计数和产物指纹从 Git 历史或对应构建记录追溯，不能复用为当前版本结论。

合成原生验收和性能入口需显式提供会话、知识、附件、凭据、选择恢复 journal 与独立暂存库；不能依赖 `test/flutter_test_config.dart` 的全局替身，因为原生和独立基准入口不继承它。共享 `workspaceProvider` 默认每个运行时创建独立内存 owner，调用者传入的故障或持久化存储优先。直接构造 `AppRuntime` 的合成入口同样隔离新增侧库，同时保留各协议原本的真实主存储、旧恢复 journal、锁和偏好 owner。生产默认存储不随测试隔离改变。对应回归直接调用共享辅助和原生／基准组合，并让默认平台存储工厂拒绝访问。

这一隔离改变需要重新采集比较双方；历史隐式侧库样本不能混入新性能结论。固定数据、操作顺序与计时范围，仍按各基准协议单独记录来源和平台。

## 需要保持的行为

`AppRuntime` 组装领域对象和共享生命周期，界面通过 `AppScope` 订阅对应领域视图。业务命令共用 `AppSession` 与仓储，不另持一份可写快照。启动取得实例租约后创建运行时与偏好；退出等待加载、业务写入静止及偏好刷新，再释放租约。入口见 [运行时](../lib/app_runtime.dart)、[启动流程](../lib/main.dart) 和 [启动回归](../test/widgets/app_bootstrap_test.dart)。

通知锁的显式作用域使用规范化绝对文件路径确定 broker 身份，调用方使用同一路径，不依赖符号链接或硬链接别名。新 isolate 接收路径和 namespace 并安装自己的作用域，重入令牌只在所属锁及有效期间复用。见 [通知运行时锁](../lib/services/agenda_runtime_mutation_lock.dart) 与 [锁作用域回归](../test/services/agenda_runtime_mutation_lock_test.dart)。

| 范围 | 约束与验证入口 |
| --- | --- |
| 快照恢复 | 普通候选按已刷新的 temporary → main → backup 处理，不按 mtime 猜测新旧。未来 schema 或 I/O 不确定状态阻止写入；已有隔离文件时不能误判为首次启动。见 [恢复矩阵](../test/data/timetable_storage_recovery_matrix_test.dart) 与 [存储测试](../test/data/timetable_storage_io_test.dart)。 |
| 密钥清理事务 | `.secret-scrub.rollback` / `.secret-scrub.tmp` 属于迁移事务，先处理事务恢复，再选择普通快照；rollback 不是第四个普通候选。不删除唯一可恢复的旧原件。见 [密钥存储测试](../test/services/app_storage_secret_io_test.dart)。 |
| 选择性备份恢复 | 预览按稳定 ID 列出新增、替换和依赖复制，未选对象保留。恢复先排空侧写并冻结参与仓储，再固定映射、数据世代和各仓储目标；逐阶段读取实际内容核验，中断后沿用同一 journal。聊天仅恢复历史，密钥、Cookie、系统授权和运行许可不导出。见[选择性备份约定](SELECTIVE_BACKUP.md)、[文件仓储重开回归](../test/backup/selective_backup_recovery_test.dart)与[恢复协调器](../test/backup/selective_restore_coordinator_test.dart)。 |
| 旧完整 JSON 兼容 | 旧 JSON 与 AppData 导出不带本机 Agent 配置、回执、聊天或原始密钥，导入也不从兼容默认值补造这些内容。设置入口使用同一对象选择恢复；旧整体恢复 API 继续保留，固定恢复实际开始时的本机 Agent 配置、站点身份及新数据世代。重放沿用已持久目标，不重新生成执行身份或激活旧入口。见 [备份流程测试](../test/controllers/app_backup_workflow_test.dart) 与 [Agent 迁移测试](../test/data/migrations/agent_state_migration_test.dart)。 |
| 保存与退出 | 显式退出入口等待 `quiesceForShutdown()`；暂停请求 flush，同步 `dispose()` 只能发起最佳努力保存。用明确开始/完成信号验证并发与最新快照，不用固定等待推测完成。见 [保存竞争测试](../test/controllers/app_persistence_race_test.dart)。 |
| 敏感数据 | 普通 AppData、聊天、工具记录和备份不包含 API Key 值。宿主安全输入只给模型一个绑定运行与目的地的短期句柄，使用、取消和到期后清理；更换目的地不能保留旧凭据。错误不得带出认证头、原始网络错误体或密钥。见 [连接持久化](../test/agent/connection/agent_connection_manager_test.dart)、[安全输入工具](../test/agent/tools/agent_control_tool_adapters_test.dart) 与 [旧密钥兼容](../test/controllers/school_import_secret_persistence_test.dart)。 |
| 学校网页会话清除 | 清除应用数据前先关闭学校浏览器的原生页面并清除 Cookie、站点存储及缓存；Android/iOS 使用对应 WebView 数据接口，Windows 使用同一默认 WebView2 profile 的 `ClearBrowsingDataAll`。清理失败时保留主存档和 API 密钥，不假报成功；页面重开使用新的文档，不复用旧登录上下文。见 [清除服务测试](../test/services/app_data_clear_service_io_test.dart) 与 [网页会话测试](../test/services/school_web_session_service_test.dart)。 |
| HTTP Endpoint | 询问和只读计划模式使用独立的 HTTP 传输确认，完全权限模式允许按该模式发送；传输确认不产生业务修改票据。人工连接诊断通过明确风险提示与该次按钮操作授权。确认与请求绑定同一端点和凭据快照，任何模式都不跟随重定向。见 [运行时测试](../test/agent/runtime/agent_runtime_controller_test.dart)、[诊断协议](../test/agent/connection/agent_connection_diagnostics_test.dart) 与 [协议测试](../test/agent/provider/provider_client_test.dart)。 |
| 原生安全 | Android 云备份和旧版整包备份关闭；设备间迁移仅使用先过滤当前及旧版密钥的受控主数据工件，恢复不覆盖已有存档。通知 receiver 不导出；可配置 HTTP Endpoint 的网络策略需与前述确认配合。Apple 权限与 Windows 通知身份也需检查。见 [设备迁移约定](ANDROID_DEVICE_TRANSFER.md)、[平台测试](../test/platform) 和 [产物检查器](../tool/platform_artifact_check.dart)。 |
| Android 文件导出 | 二进制内容先写入原生分配的私有缓存文件，再凭一次性令牌流式复制到用户选择的目标；源路径不从通道传入。准备、选择和复制共用一个名额，成功、取消与失败保留实际结果并清理源文件。见 [导出约定与验证入口](ANDROID_FILE_EXPORT.md)。 |
| 日视图末卡 | 手机添加按钮的避让空间属于可滚动内容，不压缩日视图视口；末卡尾部可滚到真实按钮上方并打开正确课程详情，关闭按钮后释放避让空间。可容纳的卡片验证整卡可见，超过可用高度的大字卡片验证顶部和尾部能分别完整阅读。见 [真实主页日视图测试](../test/widgets/student_day_agenda_workflow_test.dart)。 |

统一 Agent 连接兼容 HTTP 与 HTTPS，不用固定域名白名单限制用户的自建服务，也不设置默认明文地址。Android 的动态端点网络配置保留明文兼容；这项平台能力不能代替宿主的授权判断。HTTP 提示说明 API 密钥和提交内容在传输途中可能被读取或篡改；取消传输确认不发送，接受也不改变只读计划模式或授权其他业务操作。显式同意只在当前运行时中复用于相同端点、协议、模型和凭据快照，连接变化或功能关闭后失效；完全权限的放行不产生可被之后只读／询问模式复用的同意。设置页的人工诊断使用已保存连接，HTTP 风险提示与测试／获取模型按钮一起呈现，点击只授权该次请求。

Agent 请求使用已经确认的连接快照，禁止敏感请求自动跟随重定向；返回 3xx 时报告失败，不将密钥或内容转发到新地址。HTTPS 不需要明文传输确认，但使用相同的重定向保护。学校网页访问和内容压缩不请求模型；用户继续时先原子保存来源、首条消息与交接标识，再由统一运行时发起请求。见 [协议边界](../test/agent/provider/provider_client_test.dart)、[来源交接](../test/agent/imports/school_web_handoff_test.dart) 与 [来源页](../test/widgets/school_html_import_page_test.dart)。

Windows 学校页面清理需要等待锁定 WebView 插件 `dispose` 通道的原生回复，不能用一帧结束代替原生页面销毁。尚在创建的页面或销毁失败会阻止数据清理；失败后重试仍需完成销毁确认。清理期间新打开的学校页面保持挂起，新登记的浏览器必须纳入清理后才能报告成功。

学校网页页头提供“退出登录”，确认后清理 Sked 内学校页面的 Cookie、站点存储与缓存，并重新建立网页；保留已经导入的课表、应用设置及 Agent 连接。取消确认不清理，清理失败不显示成功并保留重试入口。此动作只影响本机内嵌浏览器，不声称学校服务端的所有会话都已退出。

统一连接中的凭据绑定实际端点；更换目的地不得自动转移旧密钥或发送旧会话。连接草稿在保存成功前保留，后台、销毁或模型工具不得伪造用户同意。旧本机解析连接仅在新连接字段尚未配置时迁移，单独修改统一指令或预算不阻止迁移。旧密钥只有同一端点的新安全存储写入并读回成功后才退役，失败保留恢复材料。旧专用提示词不变成 Agent 系统指令。暂存密钥期间发生的偏好变更必须从最新提交继承，不能随旧连接草稿覆盖。见 [连接迁移测试](../test/agent/connection/agent_connection_manager_test.dart)、[连接表单](../test/agent/ui/agent_model_settings_form_test.dart) 与 [旧密钥兼容](../test/controllers/school_import_secret_persistence_test.dart)。

安全存储的 active 或 pending 记录使用较新格式时，连接初始化、取钥与替换请求保持阻断；另一有效槽不作为降级覆盖的依据。两槽原文、本机配置和兼容旧密钥保留。对应[连接回归](../test/agent/connection/agent_connection_manager_test.dart)先通过真实管理器生成当前记录，再提升其中一槽的格式版本，核对拒绝及零写入；安全存储使用明确替身，不代表原生 keyring 验收。

未选择 Agent 连接组或恢复旧 JSON 时，本机未配置的 Agent 连接仍保持未配置。选择性归档可以显式恢复连接地址和模型目录，密钥始终不参与便携备份；连接目的地改变时先按 journal 清理旧凭据，目的地相同则保留本机凭据。兼容存留的旧解析密钥另按旧恢复策略处理。恢复预览之后本机内容发生变化时必须重新核对；目标写入恢复日志后，失败重试沿用该目标。

## Agent 保存、会话与外部效果

课程冲突显示和自定义日期范围由确定性适配器生成主数据计划，复用课程投影及普通日期导航的纯变换，经 `mutation.commit` 保存。显示选择核对指定课表、周次、实际完整冲突键与可选课程；日期范围和必要焦点变化一起记入回执。停用工作区、非当前课表、旧格式冲突重置、三种权限模式、保存失败、重复操作和撤销冲突由[适配器专项](../test/agent/tools/display_range_tool_adapters_test.dart)验证。

各平台完整聊天共享 [应用级 Agent](../lib/agent/agent_application.dart)，界面销毁不拥有或终止唯一执行器。功能关闭、停止、维护预约和退出都会阻止未接受的新步骤；已接受的主数据写入或外部效果必须完成核对。外部队列中尚未开始的操作可以因取消立即返回，避免清空或退出等待另一个排在自己后面的会话；已经开始的操作仍等待真实结果。见 [运行时](../test/agent/runtime/agent_runtime_controller_test.dart)、[双会话维护队列](../test/agent/runtime/agent_maintenance_queue_test.dart) 与 [工作台入口](../test/widgets/agent_workspace_entry_test.dart)。

主数据候选与持久回执一次保存。旧操作 ID 配不同参数会拒绝，淘汰回执之后的旧请求不能重新执行。跨主库、学校站点、安全存储、设备偏好和原生系统的动作使用独立的 pending/结果回执；不能把多个存储当成一个原子事务。停止或回复保存失败后先读取已有回执，平台状态未知不能改成成功。外部重试使用原请求与原版本，只核对结果，不再次发送通知、保存文件或清空数据。见 [操作协调器](../test/application/mutation_coordinator_test.dart)、[外部效果](../test/application/external_operation_coordinator_test.dart) 和 [设备适配器](../test/agent/tools/device_tool_adapters_test.dart)。

清空前先停止运行并排空已接受写入，冻结会话存储，再处理网页会话、通知运行时、设备偏好、应用数据及安全存储。安全存储删除要读回确认；退出回调返回或失败后，独立会话库也不能重新写回已删除内容。清理失败可能留下部分结果，不能自动把旧内存快照当作完整存档继续写入；会话恢复需重新读取存储。见 [组合层回归](../test/agent/agent_application_test.dart) 与 [清空服务](../test/services/app_data_clear_service_io_test.dart)。

[原生清空组合回归](../test/services/app_data_clear_service_io_test.dart)通过真实文件拥有者写入主库、聊天和附件引用、共享技能与记忆、历史恢复标记、选择恢复 journal 和二进制暂存，先读回内容，再统一清空并使用新拥有者核对空库、空标记及缺失文件。测试仅使用系统临时目录中的合成内容；凭据和网页会话是明确替身，原生 keyring、WebView 与进程强杀仍需单独验收。

聊天、共享知识和选择恢复 journal 的任一文件槽包含较新的封装或内层版本时，另一有效槽不能成为降级覆盖的依据。[原生侧库版本回归](../test/agent/sidecar_future_version_io_test.dart)使用当前文件写入器生成合成内容并读回，只提升一层版本及其派生校验摘要，再由新拥有者核对读取、普通写入、恢复写入或 journal 清理均被阻断，两槽字节保持不变。聊天和知识仓储退出维护后仍须保持阻断；该文件回归不代表跨版本安装、物理断电或原生安全存储验收。

学校网页交接的来源、首条消息和交接标识一起持久化，普通文件附件按本地添加流程单独保存到会话。成功删除同步两个存储副本，迟到模型响应不能复活会话。归档和删除先处理当前运行，删除聊天不撤销业务操作。保留策略只清理超过期限、无草稿、无运行或排队输入的已完成会话；中断运行与需要核对的结果不自动重放。上下文摘要不改写原始消息，不冒充实时数据查询。见 [会话仓库](../test/agent/conversations/conversation_repository_test.dart)、[上下文](../test/agent/runtime/conversation_context_test.dart) 与 [会话工具](../test/agent/tools/conversation_tool_adapters_test.dart)。

二进制会话附件先完成私有存储写入和读回核验，再发布草稿引用，不自动调用模型；每份上限 32 MB，每条消息最多 20 份，请求原始字节合计上限 48 MB。原生私有文件与 Web IndexedDB Blob 使用相同的长度、摘要、取消和引用规则；请求按原生协议编码，文本上下文与 Base64 开销分别核算。重试复用已核验文件身份，最终读回核验仍可取消；会话、消息边界和数据世代变化后拒绝发布旧引用。未发布的重试缓冲不等同于持久草稿。见[附件协议与验证入口](AGENT_ATTACHMENTS.md)、[应用生命周期](../test/agent/attachments/attachment_application_lifecycle_test.dart)和[聊天入口](../test/agent/ui/agent_binary_attachment_view_test.dart)。旧网页/文本来源接口仍保留原有严格 UTF-8 和小文本预算，不作为二进制文件入口的限制。

连接诊断使用合成小请求，分别报告收到有效响应与观察到工具调用，不使用私人课表或聊天。模型目录只使用已配置来源的已知路径或明确的同源地址，拒绝重定向、超时、超量和无效响应；完整目录保存在操作回执中，分页读取不重复联网。诊断测试覆盖协议、取消与输出边界，不能代替具体服务、账号、原生 keyring 或实体设备验收。见 [诊断协议](../test/agent/connection/agent_connection_diagnostics_test.dart) 与 [连接工具](../test/agent/tools/agent_control_tool_adapters_test.dart)。

系统通知的兼容接口返回值不作为权限事实。打开设置不表示授权成功，OEM 自启动状态可保持 unknown。稍后提醒只作用于当前有效通知身份，读回保存的时间也不证明系统已投递；诊断通知与清除诊断通知不改变生产提醒。精确闹钟工具核对实际观测状态，不以兼容接口返回 true 当作授权；通知重建工具使用已提交日程，报告排程结果及未验证投递，结果未知后的核对不重复排程。Windows 原生状态、Android 通知/后台行为及构建结果分别验收。见 [平台适配](../test/agent/tools/platform_tool_adapters_test.dart) 与 [通知服务](../test/services/agenda_notification_service_test.dart)。

文件夹具不能证明真实断电恢复或原生 keyring 迁移；显式退出保存不能保证操作系统强杀前落盘。通知重排、权限撤回、后台回收与厂商限制应结合 [通知验收矩阵](ANDROID_NOTIFICATION_ACCEPTANCE.md) 验证。

仓库保存完成后返回实际落盘快照、写入编号及数据会话编号；会话根据回执发布提交，不用队列中较新的内存快照替代已经完成的写入，也不再次发布同一编号。接收入队不代表保存完成，失败不产生成功回执。见 [仓库串行保存测试](../test/data/app_repository_test.dart) 与 [提交发布测试](../test/controllers/app_session_commit_test.dart)。

语言、预发布更新开关、主页导航显示与折叠、面板显示方式使用明确的偏好写集合；预发布开关同时包含清空更新候选。只合并尚未开始落盘、同一数据会话和已提交基点、字段互不覆盖且输入输出快照逐项连续的命令。每个命令先核对未声明字段保持不变；自定义设置服务若扩大修改范围，继续逐份保存。同字段连续编辑保留每份中间值，不能只落盘最后一份后把之前的调用也报为成功。

当前合并仅覆盖上述五类偏好命令。课程保存、普通日程保存和重复实例编辑继续逐份持久化；五项偏好突发写入的基准不代表这些编辑的延迟或吞吐已有改善。扩大合并范围需要先为对应命令定义可靠的写集合并验证事务边界。

合并批次仍执行原来的完整文件事务，所有调用仅在该事务成功后得到同一实际快照回执；有发布请求时提交流发布一次，全部静默保存时不发布。失败时所有批内调用失败，继续执行原有写门禁、结果未知和较新草稿的 epoch 回滚规则。普通完整快照保存、加载、恢复与清除预约、工作区事务、显式 flush、退出等待和关闭会话均终止当前批次；不能跨这些边界合并。见 [批次及磁盘故障测试](../test/data/app_repository_batch_test.dart)、[真实偏好命令与发布测试](../test/controllers/app_preference_batch_test.dart) 和 [写集合校验](../test/models/app_preference_write_test.dart)。

冷启动继续等待完整存储判定及原初始化流程，不提前显示候选快照。2026-10-28 的只读预览候选虽让内容较早出现，但完整就绪与内存没有一致改善，首次交互存在重复出现的延迟负项，因此未采用；可选预览入口与专属存储拆分已移除。temporary、main、backup 沿用原完整解码、恢复和写入门禁。实验协议与正负结果见 [启动测量](../benchmark/STARTUP.md)。

## 外部 JSON 与备份导入的条数边界

AppData schema 6 的 `AgentSettings` 不保存原始密钥；新装和旧本机数据的一次性迁移开启入口，默认采用询问模式。后续关闭状态及恢复开始时的本机配置保持不变；`ApplicationLedger` 与业务数据属于同一快照，首次操作前可为 null。回执保留连续末尾，最多 128 条且 JSON 合计不超过 4 MiB；单条结果与撤销材料超过 1 MiB 时整体拒绝，不截断。淘汰的序号必须由执行器按过期请求处理，不能重新创建同一操作。外部动作可在保持操作 ID、摘要、序号和顺序的前提下更新回执；容量淘汰遇到尚未核对的 pending/unknown 外部回执时拒绝新写入，先通过对应工作流核对，不能为腾出空间重做动作。账本变更有独立版本域，不单独触发提醒重排。

旧 JSON 便携导出排除本机 Agent 配置与账本，兼容导入忽略这些字段；选择性 ZIP 只在显式勾选后携带连接和偏好组，仍排除密钥、运行权限和可执行回执。恢复固定新的数据世代并以恢复专用编码写入 journal，继续时使用已固定的世代、配置和映射。Android 受控设备迁移继续清除本机 Agent 权限、连接和回执，具体见[设备迁移约定](ANDROID_DEVICE_TRANSFER.md)。模型、实际文件、恢复工作流和 JVM 检查分别覆盖这些路径，不能替代物理断电或真实换机验收。

外部导入在 JSON 解析后、迁移复制和领域模型构建前统一检查原始条数。课表 JSON、普通日程 JSON、节次时间 JSON、完整备份、旧版 AppData 备份和学校站点 JSON 共用 [计数规则](../lib/models/import_count_limits.dart)。候选预览和实际导入使用同一入口；超过任一上限即整份拒绝，不截断或部分保存。错误提供英文、简体中文、繁体中文，其余语言明确登记英文回退。

| 原始集合 | 每次导入的上限 |
| --- | --- |
| 课表、日历、节次方案 | 各 100 个 |
| 课程和事件 | 两个工作区合计 20,000 条，跨课表和日历累计 |
| 节次时间 | 所有方案及旧版课表配置合计 10,000 条 |
| 学校站点 | 1,000 条 |
| 全部嵌套 List 元素 | 合计 250,000 个，包括周次、节次、提醒、重复例外、工具栏及自定义数据 |
| 全部嵌套 Map 条目 | 合计 1,000,000 个，包括附加字段和未知字段 |
| 集合嵌套深度 | 64 层，从导入 data（学校站点为根 List）算第一层 |

计数超限使用独立异常类型跨 compute 返回；课表入口按该类型显示当前界面的本地化提示。未知解析异常仍显示通用错误，不把任意错误文本或导入内容直接展示。拒绝时保留现有数据和输入草稿。

这些是单次外部输入的资源预算：容器上限允许多年学期和多个日历，20,000 条课程/事件保留长期个人档案余量；较大的 List/Map 总预算容纳每条记录的周次、提醒和附加字段，同时约束归一化前的复制、遍历与索引规模。重复项、无效项也计入，不能依赖过滤去重来绕过，亦不能将超量内容分散到多个子集合绕过。旧版单课表、平铺 AppData、历史 schema 别名使用相同规则。这里只限制已经解析的集合，不构成 JSON 字符串或文件字节上限。

本地存档和已经写入的恢复日志沿用原来的完整解码与校验；它们可能来自更早版本，或由多次合法导入累积超过单次预算。恢复日志显式调用本地恢复解码入口，仍执行格式与版本检查，不把新导入的预算追溯为本地数据损坏。相关边界、累计、旧格式和 compute 入口证据见 [导入计数测试](../test/models/import_count_limits_test.dart)。

## 外部课表缺失开学日期的确认

选择导入课表时，缺失、空白或无法解析的开学日期必须在应用前明确确认。解码在填入旧版兼容默认值前记录缺失标记，标记随 worker 结果及模型归一化保留，不写入 JSON，也不信任输入中的同名字段。预览日期由可注入时钟在本次准备开始时捕获一次；界面说明它暂以今天填写，并复用日期选择器让用户逐项修改。

只确认本次选中的缺失日期课表；多课表可分别选择日期，有效的原日期不会被确认表覆盖。所有确认完成后才应用导入，直接调用应用入口也必须提供对应确认日期。取消整体确认保留数据和粘贴草稿；取消日期选择器只放弃该次日期修改。清除、恢复或工作区切换使旧候选失效，不能用旧确认继续写入。

完整备份、旧 AppData 备份及本地恢复日志原先就通过严格存档校验拒绝缺失或非法的持久化日期，本项保持该规则，不为这些路径新增交互门禁。已有有效日期的旧快照继续按原日期读取。见 [日期来源与备份测试](../test/models/import_start_dates_test.dart)、[应用门禁测试](../test/controllers/data_transfer_controller_test.dart) 和 [真实导入流程测试](../test/widgets/timetable_import_flow_test.dart)。

## 隐私政策版本来源

本机隐私确认以随应用分发的政策版本为依据；移除未接入生产流程的远程版本抓取，不因启动、恢复或切换工作区请求隐私网页。用户主动打开隐私政策的现有链接继续保留。版本格式校验、已保存的接受版本与接受时间、首次启动及恢复后的确认规则保持不变；不能把删除网络检测当作用户已经同意新的政策。

## 日常检查

从仓库根目录运行以下 PowerShell 命令，逐项确认退出码。测试并发可按机器资源调整；遇到超时先区分资源竞争与业务失败，不通过弱化断言或跳过用例消除失败。

```powershell
flutter pub get --enforce-lockfile
Push-Location packages/android_productivity_plugin
flutter pub get --enforce-lockfile
flutter analyze --no-pub
Pop-Location
flutter gen-l10n
git diff --exit-code -- lib/l10n
# 另检查新生成的未跟踪文件；与修改前状态比较。
git status --short -- lib/l10n
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test --no-pub --coverage --concurrency=4
git diff --check
```

覆盖率用于定位尚未验证的代码路径。[CI](../.github/workflows/flutter.yml) 只对当前提交执行一次完整 VM 测试，并保留生成的 `coverage/lcov.info` 作为诊断附件，不设总覆盖率或改动行百分比门槛，也不为覆盖率检出基准提交重跑全套。测试取舍以数据完整性、故障恢复、真实交互和已发生的回归为依据；测试失败仍阻止 CI 通过。

## CI 与平台检查

下表描述仓库配置，不表示当前提交已经通过。实际结果必须关联提交与 CI run。

| 检查 | 当前配置及边界 |
| --- | --- |
| 通用 | 固定 Flutter 版本、双 lock 校验、本地化生成一致性、格式、分析、VM 测试；coverage 仅作为诊断附件。 |
| 浏览器与日期 | Linux Chrome 验证实例 lease；纽约、柏林 DST、上海无 DST 对照、圣保罗午夜缺口及 Apia 跳整日分别执行。命名时区步骤同时验证重复实例范围、新提醒索引、缓存与 Windows 提前提醒计划；原生偏移和缺失日期断言确保 TZ 实际生效。普通全量测试不能代替这些专门任务。 |
| Android | Ubuntu / Java 17，以临时 CI 密钥构建 APK 和 Google Play 渠道 AAB；Debug JVM 单测与 Release 编译/混淆分别检查，再检查 merged manifest 与资源。 |
| Web | Release 构建；构建成功不代表浏览器运行、视觉或 Wasm 已验收。 |
| Linux | Debian 容器和 WPE WebKit 系统依赖下构建 Release。 |
| Windows | 构建未签名通知 MSIX、检查 toast 身份，并构建 Microsoft Store 提交包；不等于已安装验证或商店发布。 |
| Apple | 构建 macOS 和未签名 iOS，并检查 macOS 实际 bundle 的签名、plist 与 entitlement；不等于商店分发成功。 |

Linux 上的专门检查命令：

```bash
flutter test --platform chrome test/services/app_instance_lease_web_test.dart
indexed_timezone_tests=(
  test/named_timezone_indexed_reminder_test.dart
  test/models/general_event_occurrence_range_test.dart
  test/services/general_reminder_indexed_items_test.dart
  test/services/general_occurrence_cache_test.dart
  test/services/windows_agenda_notification_coverage_test.dart
)
TZ=America/New_York SKED_DST_TEST_ZONE=america-new-york flutter test test/date_dst_regression_test.dart "${indexed_timezone_tests[@]}"
TZ=Europe/Berlin SKED_DST_TEST_ZONE=europe-berlin flutter test test/date_dst_regression_test.dart "${indexed_timezone_tests[@]}"
TZ=Asia/Shanghai SKED_DST_TEST_ZONE=asia-shanghai flutter test test/date_dst_regression_test.dart "${indexed_timezone_tests[@]}"
TZ=America/Sao_Paulo SKED_DST_TEST_ZONE=america-sao-paulo flutter test test/date_dst_regression_test.dart "${indexed_timezone_tests[@]}"
TZ=Pacific/Apia SKED_DST_TEST_ZONE=pacific-apia flutter test "${indexed_timezone_tests[@]}"
```

命名时区索引专项在未设置 `SKED_DST_TEST_ZONE` 时明确跳过；声明了时区但 `TZ`、原生历史偏移或缺失日期不符时失败，不将宿主默认时区结果计入该时区。500 天实例范围和 600 天提前量覆盖快速索引路径，并与完整展开器对照顺序、状态、排除和缓存失效。捆绑时区候选表的完整性检查不能代替这些原生 `DateTime` 检查。

Windows 通知服务回归也在五个原生时区中执行，检查提前提醒候选、通知动作身份、稍后提醒及本地 9999 年边界；它使用内存网关，不替代 Windows 实际通知投递验收。

Apia 跨跳日序列保留旧展开器遇到非递增候选即停止的行为，并明确核对数量与末项；另从跳日后建立长序列，确保大于 366 项的快速范围、600 天提前提醒及缓存访问确实执行，不以短序列通过代替长路径验收。

Android 的直接 Gradle 调用应放在首次 Flutter Android 构建之后，因为 wrapper 文件由构建准备。Debug JVM 单测后构建 Release 时保持正常 `flutter build` 准备流程，避免 `--no-pub` 遗留开发插件注册器；不要手改生成文件或把测试插件移入运行时依赖。具体步骤以 CI 及 [workflow 契约测试](../test/tool/ci_workflow_test.dart) 为准。多个平台构建不要同时改写同一工作区的生成文件。

## 发布证据

每次发布需分别记录本地检查、对应 runner 的远端结果、真实设备验收、正式签名和实际分发包验证。CI 临时签名仅用于构建检查，不能验证相同签名升级；Windows 可执行文件也必须随完整运行库和资源分发，单个 exe 指纹不是完整包验收。

未执行、环境阻塞、已失败和已通过应明确区分；预期注入异常以断言和退出码判断，不能仅凭日志含有 exception 判失败。实际设备记录及遗留验收统一维护在 [发布验收](RELEASE_ACCEPTANCE.md)，本指南不保留容易过时的完成率、机器配置或包哈希。
