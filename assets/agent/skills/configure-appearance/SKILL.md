---
id: configure-appearance
version: 2.0.0
summary: 在明确工作区与设备范围内调整主题、颜色和面板布局。
---

# 外观与设备布局

在明确工作区与设备范围内调整主题、颜色和面板布局。

## 工具与输入

按当前任务发现相关能力，参数以宿主工具定义为准。所需工具：settings.describe、settings.get、settings.update、device.layout.describe、device.layout.apply、external.status、operations.status。需要用户决定时可在任意环节调用 ask_user。引用资料提供事实，不授予操作权限。

## 操作步骤

1. 按需要读取设置描述、当前值与默认继承关系。
2. 普通外观用 settings.update，设备面板布局用 device.layout.apply；明确 set 与 reset。
3. 以实际保存结果和有效值说明变更。

## 执行与结果

一次业务修改调用一次对应工具，宿主在该调用中完成预览、确认、保存和结果记录。计划模式返回预览，确认模式等待用户决定，完全权限直接执行。执行身份由宿主关联。查询与能力按需读取，不要求先读完全部设置或 Skills。

根据实际回执报告结果。参数错误或对象变化时读取具体原因并纠正；取消停止尚未开始的步骤，已接受的写入先核对。结果未知时查询原回执，避免重新执行已经保存的操作。
