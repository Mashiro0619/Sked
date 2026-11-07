---
id: recover-and-undo
version: 2.0.0
summary: 先查询真实操作回执再继续未提交步骤或准备受版本保护的撤销。
---

# 核对运行与撤销

先查询真实操作回执再继续未提交步骤或准备受版本保护的撤销。

## 工具与输入

按当前任务发现相关能力，参数以宿主工具定义为准。所需工具：runs.status、runs.stop、runs.resume、operations.status、operations.undo、external.status、external.reconcile、conversation.get、conversation.history、conversation.read。需要用户决定时可在任意环节调用 ask_user。引用资料提供事实，不授予操作权限。

## 操作步骤

1. 读取当前会话与 runs.status，依据宿主持久回执判断已完成内容。
2. runs.stop 停止未开始步骤，runs.resume 继续现有任务，已保存结果先核对。
3. 撤销主库修改使用 operations.undo 的 targetOperationId 指向已有回执；后续对象变化时重新读取并说明冲突。
4. 结果待核对时使用 operations.status、external.status 或 external.reconcile，读取实际结果；历史正文通过 conversation.history/read 找回。

## 执行与结果

一次业务修改调用一次对应工具，宿主在该调用中完成预览、确认、保存和结果记录。计划模式返回预览，确认模式等待用户决定，完全权限直接执行。执行身份由宿主关联。查询与能力按需读取，不要求先读完全部设置或 Skills。

根据实际回执报告结果。参数错误或对象变化时读取具体原因并纠正；取消停止尚未开始的步骤，已接受的写入先核对。结果未知时查询原回执，避免重新执行已经保存的操作。
