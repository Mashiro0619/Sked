---
id: locate-and-navigate
version: 2.0.0
summary: 根据用户指定范围定位稳定对象并打开相应页面。
---

# 定位对象与页面

根据用户指定范围定位稳定对象并打开相应页面。

## 工具与输入

按当前任务发现相关能力，参数以宿主工具定义为准。所需工具：capabilities.describe、timetables.list、courses.list、calendars.list、events.list、settings.describe、navigation.open、external.status、navigation.range.apply、operations.status。需要用户决定时可在任意环节调用 ask_user。引用资料提供事实，不授予操作权限。

## 操作步骤

1. 按对象类型查询候选，名称用于检索，稳定引用用于打开目标。同名对象需要选择时使用 ask_user。
2. 使用 navigation.open 打开明确对象；查询非当前课表或停用工作区不会自动切换页面。
3. 自定义日程日期范围使用 navigation.range.apply 的 set 或 reset；由宿主处理日期焦点与隐藏周末规则。

## 执行与结果

一次业务修改调用一次对应工具，宿主在该调用中完成预览、确认、保存和结果记录。计划模式返回预览，确认模式等待用户决定，完全权限直接执行。执行身份由宿主关联。查询与能力按需读取，不要求先读完全部设置或 Skills。

根据实际回执报告结果。参数错误或对象变化时读取具体原因并纠正；取消停止尚未开始的步骤，已接受的写入先核对。结果未知时查询原回执，避免重新执行已经保存的操作。
