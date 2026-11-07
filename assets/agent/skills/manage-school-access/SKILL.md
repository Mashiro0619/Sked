---
id: manage-school-access
version: 2.0.0
summary: 管理学校入口和本机网页登录清理并说明实际退出范围。
---

# 学校站点与网页登录

管理学校入口和本机网页登录清理并说明实际退出范围。

## 工具与输入

按当前任务发现相关能力，参数以宿主工具定义为准。所需工具：school_sites.list、school_sites.get、school_sites.apply、school_session.status、school_session.clear.apply、external.status、external.reconcile。需要用户决定时可在任意环节调用 ask_user。引用资料提供事实，不授予操作权限。

## 操作步骤

1. 查询学校站点的稳定引用、地址和版本，明确修改入口或退出本机网页登录会话。
2. 用 school_sites.apply 修改站点，用 school_session.clear.apply 清理本机网页会话。
3. 以实际回执说明结果；清理失败后核对原操作，不根据 URL 猜测学校类型。

## 执行与结果

一次业务修改调用一次对应工具，宿主在该调用中完成预览、确认、保存和结果记录。计划模式返回预览，确认模式等待用户决定，完全权限直接执行。执行身份由宿主关联。查询与能力按需读取，不要求先读完全部设置或 Skills。

根据实际回执报告结果。参数错误或对象变化时读取具体原因并纠正；取消停止尚未开始的步骤，已接受的写入先核对。结果未知时查询原回执，避免重新执行已经保存的操作。
