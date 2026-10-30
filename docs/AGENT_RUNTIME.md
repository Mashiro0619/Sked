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
