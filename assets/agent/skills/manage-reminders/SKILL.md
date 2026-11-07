---
id: manage-reminders
version: 2.0.0
summary: 区分提醒策略、实例处理状态和真实通知效果。
---

# 调整和处理提醒

区分提醒策略、实例处理状态和真实通知效果。

## 工具与输入

按当前任务发现相关能力，参数以宿主工具定义为准。所需工具：notifications.status、notifications.reminders、notifications.snooze.apply、occurrences.get、mutation.apply、settings.update、external.status、operations.status。需要用户决定时可在任意环节调用 ask_user。引用资料提供事实，不授予操作权限。

## 操作步骤

1. 读取事件、课程和通知状态，区分继承默认、关闭与自定义提前时间。
2. 对象提醒通过 mutation.apply，默认提醒通过 settings.update。
3. 稍后提醒先读取 notifications.reminders 的当前身份，再用 notifications.snooze.apply；保留隐藏分类与停用工作区的真实业务规则。
4. 分别报告业务数据保存与提醒安排结果；仅在与用户任务有关时说明无法观测的系统投递。

## 执行与结果

一次业务修改调用一次对应工具，宿主在该调用中完成预览、确认、保存和结果记录。计划模式返回预览，确认模式等待用户决定，完全权限直接执行。执行身份由宿主关联。查询与能力按需读取，不要求先读完全部设置或 Skills。

根据实际回执报告结果。参数错误或对象变化时读取具体原因并纠正；取消停止尚未开始的步骤，已接受的写入先核对。结果未知时查询原回执，避免重新执行已经保存的操作。
