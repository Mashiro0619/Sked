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

主库修改通过 prepare/commit 和持久操作回执执行，支持查看完整差异及有条件撤销。当前采用整库快照/版本的保守冲突检查，无关 UI 编辑也可能要求重新准备；不能声称已实现细粒度 readSet/writeSet 并发合并。工具结果超出预算会要求缩小分页或字段，不把截断解释为数据不存在。

设置描述通过 adapterTool 指向拥有该语义的入口。Agent 开关属于可准备的普通设置，权限模式仍只能由用户切换；旧解析配置只读保留用于迁移，不再提供第二套连接写入口。

实现与回归：[工具宿主](../lib/agent/tools/application_tool_host.dart)、[选择集合工具测试](../test/agent/tools/selection_tool_test.dart)、[资源字段覆盖](../test/agent/resource_field_coverage_test.dart)。后续适配器在应用组合层注册后才向正式会话提供完整能力。

## 网页交接与课表候选

网页来源先压缩和校对，再以固定 handoffId 原子保存新会话、初始请求和不可变附件。重复交接复用已有会话，同身份但内容或目标改变会被拒绝。交接记录保留来源、截断状态、日期和数据世代；创建会话不意味着远端推理或业务保存已成功。

候选解码是有界纯计算，与模型请求和主库写入分离。imports.prepare 要求明确创建或替换目标，并校验实际开学日期、周次、时间、作息引用及来源所属会话；缺失事实不得静默填写为当前日期。准备后仍需 mutation.commit 按会话模式执行，最终回执决定是否导入成功。

实现与回归：[交接](../lib/agent/imports/school_web_handoff.dart)、[候选工具](../lib/agent/imports/school_import_tool_adapter.dart)、[导入专项](../test/agent/imports/school_import_tool_adapter_test.dart)、[交接去重](../test/agent/imports/school_web_handoff_test.dart)。

## 测试存储边界

默认会话存储在 test/flutter_test_config.dart 中替换为每项独立的内存实例，覆盖直接构造 AppRuntime 的历史测试。一个测试内的重启共享同一实例；后续测试换新实例，迟到回调只持有旧实例。显式构造原生会话存储的专项继续使用系统临时目录验证真实 IO，不由默认替身替代。

恢复测试分别验证便携备份和本机 journal：便携文件排除 Agent 本机配置与账本，journal 使用恢复专用编码保留这些状态，两者均不得包含密钥。每次恢复采用独立数据世代并发布 ledger 变更；学校站点保留自身格式版本，不能跟随主库版本升级。
