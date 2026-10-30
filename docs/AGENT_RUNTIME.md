# 内置 Agent 的运行行为

本页说明已接入的实现与恢复边界；产品范围和分阶段验收见[实施计划](AGENT_IMPLEMENTATION_PLAN.md)。测试 provider、真实模型 API、组件测试和原生设备验收分别记录。

## 会话附件

会话接收 JSON、ICS、TXT、HTML 和 HTM 文本文件，单份最多 512 KiB。文件读取严格校验 UTF-8 和实际字节数，不截断超限内容；添加附件只保存本地来源，不自动发起模型请求或导入业务数据。

附件记录固定身份、内容摘要、数据世代、文件名以及添加时的消息/运行边界。尚未用于后续输入的附件可移除；已进入历史的来源保持可追溯。保存失败后，在本进程显式恢复并重试时沿用同一身份；数据世代或输入边界改变会拒绝旧附件。尚未保存的重试缓冲不保证跨进程保留。

实现与回归：[附件服务](../lib/agent/imports/conversation_file_attachments.dart)、[文件读取](../lib/services/text_file_picker.dart)、[附件恢复测试](../test/agent/imports/conversation_file_attachments_test.dart)。

## 提醒动作与只读核对

提醒入口只接受设备运行时实际保存、仍属于当前投影的通知身份。读取可操作提醒和稍后提醒状态不清理过期存储，也不根据模型参数伪造通知载荷。稍后提醒复用通知卡片的十分钟动作；执行前重读身份，完成后读取保存状态，过期卡片不能报告成功。外部回执核对只读取结果，不再次延后提醒。

实现与回归：[通知服务](../lib/services/agenda_notification_service.dart)、[运行时存储测试](../test/services/agenda_notification_runtime_store_test.dart)、[通知服务测试](../test/services/agenda_notification_service_test.dart)。

## 清空本机凭据

统一连接的 active/pending 安全存储槽位位于普通数据目录之外。清空本机数据时先移除两个槽位并逐一读回核验，再删除最后可恢复的主库存档；删除未能核验时保留主库存档并报告失败。测试覆盖安全存储拒绝实际删除的路径，不能据此替代各系统钥匙串的原生验收。

实现与回归：[清空服务](../lib/services/app_data_clear_service_io.dart)、[清空失败测试](../test/services/app_data_clear_service_io_test.dart)。

## 模型运行、权限与恢复

运行时通过独立 UI 状态发布流式文本，消息持久化与主库事务分离。会话保存输入队列，区分当前步骤调整与后续请求；停止、关闭功能和收紧模式会取消尚未提交的步骤。重启后需要显式继续，并先核对中断工具的持久回执；新消息或宿主操作不能绕过未决写入。

只有只读计划、逐次询问和完全权限三种模式。计划可以查询和生成候选，但不能提交业务修改；询问批准仅绑定当前计划；完全权限允许直接执行通过校验的计划。模型无法修改自己的权限模式。HTTP 传输确认与业务审批分离：计划/询问模式向当前连接首次发送前确认，许可只对进程内同一端点、协议、模型和凭据引用复用；完全权限按当前政策允许 HTTP，不伪造显式许可。连接变化或政策收紧重新检查。

长会话上下文按完整工具调用/结果组压缩，保留用户原文、操作身份与已加载技能引用；超过预算时要求缩小查询。原始历史保持可读，不将摘要当作执行回执。宿主动作先保存实际计划/操作身份，再开始执行，因此“已执行但回复丢失”可从主库账本核对，不重复动作。运行内 usage 用于预算，不代表已经具备完整任务费用统计。

实现与回归：[运行控制器](../lib/agent/runtime/agent_runtime_controller.dart)、[上下文](../lib/agent/runtime/conversation_context.dart)、[运行回归](../test/agent/runtime/agent_runtime_controller_test.dart)、[恢复回归](../test/agent/runtime/operation_recovery_test.dart)。

## 全域工具宿主

工具宿主按运行按需发现 schema 和共享 Skills，所有工具参数通过严格字段校验。六类资源查询覆盖非当前、隐藏及停用域，分页结果明确是否完整；查询不切换或启用工作区。固定选择集合保留实际 ID，公共 patch 只作用于准备时完整选中的对象，数据世代或版本变化后旧选择失效。

主库修改通过 prepare/commit 和持久操作回执执行，支持查看完整差异及有条件撤销。标准资源与设置计划记录目标、父资源元数据、共享节次及联动设置的读取依赖，固定准备时的 ID 和时钟；提交时在当前已保存快照上重新编译，并要求完整前后差异仍与审批一致。无关已保存编辑可以保留，同对象、语义依赖和未保存 UI 草稿仍会阻止提交；撤销记录使用实际提交位置。宿主导入/显示等 prepareDraft、待提交撤销及已被其他 Agent 提交推进的回执序列仍保留较严格的重新准备要求，不代表所有路径都支持细粒度并发合并。

工具结果超出预算会要求缩小分页或字段，不把截断解释为数据不存在。并发边界见[提交竞争回归](../test/application/mutation_coordinator_test.dart)和[共享保存门禁](../test/controllers/app_session_mutation_test.dart)。

设置描述通过 adapterTool 指向拥有该语义的入口。Agent 开关属于可准备的普通设置，权限模式仍只能由用户切换；旧解析配置只读保留用于迁移，不再提供第二套连接写入口。

实现与回归：[工具宿主](../lib/agent/tools/application_tool_host.dart)、[选择集合工具测试](../test/agent/tools/selection_tool_test.dart)、[资源字段覆盖](../test/agent/resource_field_coverage_test.dart)。后续适配器在应用组合层注册后才向正式会话提供完整能力。

## 网页交接与课表候选

网页来源先压缩和校对，再以固定 handoffId 原子保存新会话、初始请求和不可变附件。重复交接复用已有会话，同身份但内容或目标改变会被拒绝。交接记录保留来源、截断状态、日期和数据世代；创建会话不意味着远端推理或业务保存已成功。

候选解码是有界纯计算，与模型请求和主库写入分离。imports.prepare 要求明确创建或替换目标，并校验实际开学日期、周次、时间、作息引用及来源所属会话；缺失事实不得静默填写为当前日期。准备后仍需 mutation.commit 按会话模式执行，最终回执决定是否导入成功。

实现与回归：[交接](../lib/agent/imports/school_web_handoff.dart)、[候选工具](../lib/agent/imports/school_import_tool_adapter.dart)、[导入专项](../test/agent/imports/school_import_tool_adapter_test.dart)、[交接去重](../test/agent/imports/school_web_handoff_test.dart)。

## 测试存储边界

默认会话存储在 test/flutter_test_config.dart 中替换为每项独立的内存实例，覆盖直接构造 AppRuntime 的历史测试。一个测试内的重启共享同一实例；后续测试换新实例，迟到回调只持有旧实例。显式构造原生会话存储的专项继续使用系统临时目录验证真实 IO，不由默认替身替代。

使用真实文件的 AppRuntime 测试在清理临时目录前等待 shutdown.quiesce()，再 dispose 并等待会话关闭；只调用同步 dispose 不表示启动迁移或异步写入已经完成。清理不依赖固定延时。

恢复测试分别验证便携备份和本机 journal：便携文件排除 Agent 本机配置与账本，journal 使用恢复专用编码保留这些状态，两者均不得包含密钥。每次恢复采用独立数据世代并发布 ledger 变更；学校站点保留自身格式版本，不能跟随主库版本升级。

## 设备、站点和系统动作

外部适配器共用先记录计划、执行并读回的协调器。设备布局与偏好写入等待实际 flush；窗口、通知、系统设置入口按平台能力返回支持情况。打开自启动设置页只证明入口已打开，无法观测授权时保留 unknown。未绑定应用服务或平台不支持时返回明确错误。

学校站点使用稳定的版本句柄及共享写队列；预览期间发生其他读写不能改变该预览的版本前提。通知动作只操作当前设备拥有的真实提醒，外部核对使用原操作身份，不重复系统动作。

实现与回归：[平台适配器](../lib/agent/tools/platform_tool_adapters.dart)、[设备适配器](../lib/agent/tools/device_tool_adapters.dart)、[平台回归](../test/agent/tools/platform_tool_adapters_test.dart)、[设备回归](../test/agent/tools/device_tool_adapters_test.dart)。

## 文件、维护和显示工作流

确定性文件检查与准备支持课表/日程 JSON、ICS、节次和备份，保留大小、目标、缺失日期与兼容报告。导出、工作区切换、页面导航、恢复和清空使用 external.commit；纯主库计划使用 mutation.commit。维护先暂停旧运行并排空已接受写入，恢复后数据世代使旧计划失效。

courses.display.list 返回真实周投影中的冲突组；courses.display.prepare 的 set/reset 只选择展示课程，复用 UI 服务并清理等价旧键，不改变课程时间。navigation.range.prepare 复用显示范围 reducer，保存范围及必要焦点调整。两者均支持停用域管理、完整差异、模式门禁与撤销，不隐式切换或启用工作区。

实现与回归：[工作流适配器](../lib/agent/tools/workflow_tool_adapters.dart)、[工作流测试](../test/agent/tools/workflow_tool_adapters_test.dart)、[显示范围测试](../test/agent/tools/display_range_tool_adapters_test.dart)。

## 会话管理与统一连接

会话管理支持查看历史、归档/恢复、重命名、删除、保留设置和导出；写动作绑定真实会话版本及运行作用域，不能复活已删除会话。导出产物只包含获准的对话内容与结果，不包含安全凭据。

连接工具使用宿主安全输入句柄，原始密钥不经过模型参数。配置替换、清除、连接诊断和模型列表均绑定已保存的目的地与版本。诊断明确区分传输可达和实际工具调用能力；模型列表有边界，后续分页读取同一回执，不再次发出网络请求。共享偏好可准备修改，权限模式仍由用户控制。

实现与回归：[连接控制工具](../lib/agent/tools/agent_control_tool_adapters.dart)、[会话工具](../lib/agent/tools/conversation_tool_adapters.dart)、[连接控制测试](../test/agent/tools/agent_control_tool_adapters_test.dart)、[会话工具测试](../test/agent/tools/conversation_tool_adapters_test.dart)。

## 应用所有权与双端入口

AppRuntime 持有一个 AgentApplication，手机完整页面与桌面并排/覆盖面板共享会话和运行。功能关闭隐藏入口并停止未提交步骤，保留已有会话；关闭面板或返回来源页不会转移运行所有权。配置页面分开连接与偏好草稿，输入区支持附件、停止、继续和有序追加请求；操作卡从真实计划与回执提供预览、撤销和对象查看。

旧独立文字解析、解析设置、专用结果页和网络执行链路随新入口切换退役。网页仍先压缩校对，然后创建一次 Agent 会话并进入可见页面；直接粘贴文字使用普通会话。确定性 JSON、ICS 和节次导入入口继续使用各自领域解码。

清空前先排空写入并冻结会话存储。清空成功后，即使退出回调返回也保持冻结；失败后需要显式恢复读取真实侧存储，旧内存不能自动重建文件。测试覆盖两个会话并发维护、迟到回复、关闭与恢复，原生权限和物理设备结果另验。
