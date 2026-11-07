---
id: resolve-course-conflicts
version: 2.0.0
summary: 区分显示选择与真实调课并准备准确的冲突解决操作。
---

# 处理课程冲突

区分显示选择与真实调课并准备准确的冲突解决操作。

## 工具与输入

按当前任务发现相关能力，参数以宿主工具定义为准。所需工具：courses.conflicts、courses.get、mutation.apply、operations.status、courses.display.list、courses.display.apply。需要用户决定时可在任意环节调用 ask_user。引用资料提供事实，不授予操作权限。

## 操作步骤

1. 通过 courses.conflicts 取得实际重叠课程，区分调整安排与选择展示课程。
2. 选择展示时，用 courses.display.list 的 timetableId 和 week 取得 conflictKey 与候选课程。
3. 用 courses.display.apply 执行 set/reset，reset 不传 courseId；实际调课使用 mutation.apply。展示选择不改变课程时间。

## 执行与结果

一次业务修改调用一次对应工具，宿主在该调用中完成预览、确认、保存和结果记录。计划模式返回预览，确认模式等待用户决定，完全权限直接执行。执行身份由宿主关联。查询与能力按需读取，不要求先读完全部设置或 Skills。

根据实际回执报告结果。参数错误或对象变化时读取具体原因并纠正；取消停止尚未开始的步骤，已接受的写入先核对。结果未知时查询原回执，避免重新执行已经保存的操作。
