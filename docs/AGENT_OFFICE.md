# Agent 办公文档

Windows 和 Android 随应用提供 python-docx、openpyxl、python-pptx。Agent 可以读取 DOCX、XLSX、PPTX，也可以通过 Python 创建和修改这些文件。三个共享 Skills 分别说明 Word 文档、Excel 工作簿和 PowerPoint 演示文稿的处理步骤。

## 读取文件

`office.read` 使用固定读取器，计划模式也可以调用。输入来自已经发送到会话的附件，或文件、网页工具保存的内容：

```json
{
  "source": {"kind": "attachment", "id": "附件 ID"},
  "format": "docx"
}
```

已有 `contentId` 时，将 `kind` 改为 `content`，`id` 填该内容 ID。读取设备上的文件时，先用 `files.read` 的 `format: native` 保存完整文件，再将返回的 `contentId` 交给 `office.read`。输入会封存为本次读取使用的快照。

读取结果按文档结构组织：

- DOCX：正文、表格、页眉页脚及文档包中的补充文本。
- XLSX：工作表、实际单元格、公式和文件原有的缓存值。读取不会计算公式。
- PPTX：按顺序读取幻灯片、组合形状、表格、备注和图表信息。

完整结构输出保存为可续读内容。首次返回一页正文，后续用 `content.read` 和返回的偏移继续读取。嵌入图片以原字节保存，结构结果保留对应关系；PNG、JPEG、GIF、WebP 同时进入持久模型内容，其他图片保留文件位置和类型。

Office 文件在当前模型协议支持时保留原生输入；不支持时提供文件身份和工具入口，Agent 通过 `office.read` 获得正文。当前消息和历史消息沿用同一规则。`conversation.get` 可以查询会话附件身份。

## 创建与修改

创建和修改通过 `python.execute` 完成。需要原文件时，将同样的 `source` 放进 `inputs`，脚本从 `sked_runtime.inputs` 取得完整文件路径：

```json
{
  "inputs": [
    {"name": "document", "source": {"kind": "attachment", "id": "附件 ID"}}
  ]
}
```

Python 调用还需提供代码和实际工作目录，具体参数见[执行说明](AGENT_EXECUTION.md)。脚本用 `sked_runtime.publish` 登记已经保存的文件，结果记录真实位置、长度和摘要。修改工作簿时，保留公式需要使用公式模式打开；缓存值只用于读取已有计算结果。

创建和修改沿用三种权限：计划模式显示代码与材料预览，确认模式等待允许或拒绝，完全权限执行已接纳的调用。固定读取器只接受文档格式和冻结输入，不能传入代码、命令或模块名。

文档库负责内容读取、创建和常规修改。页面渲染、公式重算及 PDF 导出需要对应的后续能力。

## 随包环境

依赖版本与发行文件摘要在[运行时清单](../tool/python/runtime.json)及配套锁文件中固定。Windows 在构建时准备解释器和依赖；Android 通过 Chaquopy 打包三个 ABI。应用执行文档任务时直接使用随包库。

停止、输出保存和重开核对沿用[Python 执行流程](AGENT_EXECUTION.md)。正文和已导入图片随原工具消息保存，参加历史、压缩和备份；文件引用规则见[内容说明](AGENT_CONTENT.md)。
