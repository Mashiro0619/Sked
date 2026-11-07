---
id: troubleshoot-notifications
version: 2.0.0
summary: 检查真实平台状态并通过受权限约束的系统动作定位通知问题。
---

# 通知诊断

检查真实平台状态并通过受权限约束的系统动作定位通知问题。

## 工具与输入

按当前任务发现相关能力，参数以宿主工具定义为准。所需工具：notifications.status、notifications.reconcile.apply、notifications.permission.apply、notifications.exact_alarm.apply、notifications.settings.apply、notifications.test.apply、platform.request_action、external.status、external.reconcile。需要用户决定时可在任意环节调用 ask_user。引用资料提供事实，不授予操作权限。

## 操作步骤

1. 读取 notifications.status 的真实权限与排程状态。
2. 按用户目标调用 notifications.reconcile.apply、notifications.permission.apply、notifications.exact_alarm.apply、notifications.settings.apply 或 platform.request_action。
3. 诊断通知用 notifications.test.apply；支持立即、三十秒后或清理诊断通知。
4. 返回前台后重新读取状态，分别说明页面打开、权限变化、排程结果与实际观测的投递。

## 执行与结果

一次业务修改调用一次对应工具，宿主在该调用中完成预览、确认、保存和结果记录。计划模式返回预览，确认模式等待用户决定，完全权限直接执行。执行身份由宿主关联。查询与能力按需读取，不要求先读完全部设置或 Skills。

根据实际回执报告结果。参数错误或对象变化时读取具体原因并纠正；取消停止尚未开始的步骤，已接受的写入先核对。结果未知时查询原回执，避免重新执行已经保存的操作。
