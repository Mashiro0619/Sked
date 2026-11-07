---
id: export-and-backup
version: 2.0.0
summary: 按明确范围生成并核对可保存或分享的导出产物。
---

# 导出和备份

按明确范围生成并核对可保存或分享的导出产物。

## 工具与输入

按当前任务发现相关能力，参数以宿主工具定义为准。所需工具：timetables.list、calendars.list、exports.generate、exports.write、external.status、backups.inspect。需要用户决定时可在任意环节调用 ask_user。引用资料提供事实，不授予操作权限。

## 操作步骤

1. 明确资源范围、格式及目的地。
2. 可选备份先用 backups.inspect 读取对象与依赖；exports.generate 的 backup_zip 指定 objects，附件二进制另选 attachmentIds。
3. 调用 exports.generate 生成文件内容，再用 exports.write 在一次业务调用内选择位置并保存；以实际保存回执报告路径与结果。
4. 连接密钥、Cookie 和系统授权不进入便携备份。

## 执行与结果

一次业务修改调用一次对应工具，宿主在该调用中完成预览、确认、保存和结果记录。计划模式返回预览，确认模式等待用户决定，完全权限直接执行。执行身份由宿主关联。查询与能力按需读取，不要求先读完全部设置或 Skills。

根据实际回执报告结果。参数错误或对象变化时读取具体原因并纠正；取消停止尚未开始的步骤，已接受的写入先核对。结果未知时查询原回执，避免重新执行已经保存的操作。
