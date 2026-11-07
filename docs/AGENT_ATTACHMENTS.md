# Agent 附件

附件先保存到应用私有存储，长度和 SHA-256 核对成功后发布引用。SQLite 保存稳定 ID、名称、媒体类型、长度和摘要，二进制独立保存。选择文件不自动调用模型，也不自动导入课表或日程。

## 草稿、队列与历史

任意扩展名的文件均可加入本地附件；是否能发送由实际协议和模型能力决定。文件大小、单条消息附件数量及整次请求附件总量没有 Sked 固定额度。

新会话尚未接纳输入时，草稿引用属于当前应用生命周期，不建立历史记录；首次接纳输入时与用户消息一起保存。已有持久会话的草稿和排队项保留各自引用。队列消费把完整输入和文件引用一起移入用户消息。

移除草稿中的文件不会删除仍被其他消息、队列或历史版本引用的内容。垃圾回收读取数据库保存的全部引用，不依赖当前页面是否加载了旧聊天。先保存元数据变更，再删除已经没有引用的二进制。

重试复用已经核验的文件身份，并允许取消读取和核验。保存失败不宣称引用已发布；迟到的选择结果仍须属于原会话和本次导入。

## 流式处理与展示

原生文件分块读取、复制和编码，上传使用流式请求体。进度对应已经处理的实际字节；发送阶段只表达客户端能够观测的状态。成功 HTTP 响应表示服务接纳了请求，不表示模型已经理解文件。

附件显示紧凑缩略图或文件条目，支持预览、移除和取消。长名称通过提示、预览和读屏提供完整内容。预览只读取用户选择的本地私有文件；切换会话或关闭所属宿主后，旧读取和迟到回调不能操作新的页面。

停止会取消尚未完成的复制、核验、编码和传输。已经保存的引用保留。缺失文件、长度变化、摘要变化和协议不支持分别报告实际原因，保持原消息可重试。

## 模型协议

附件由当前协议的原生内容块发送，不自动进行 OCR、音频转码或视频抽帧。

| 内容 | Chat Completions | Responses |
| --- | --- | --- |
| 已登记图像 | `image_url` 数据 URL | `input_image` 数据 URL |
| WAV、MP3 | `input_audio` | 当前附件链路报告不支持 |
| PDF | `file` | `input_file` |
| 文件目录中登记的文本与文档 | 按当前 `file` 能力检查 | `input_file` |
| 其他类型 | 保留本地文件并说明实际能力 | 保留本地文件并说明实际能力 |

精确类型以[媒体类型目录](../lib/agent/attachments/attachment_media_types.dart)和[协议编码器](../lib/agent/provider/provider_protocol.dart)为准。编码在发送前使用附件元数据计算长度，并在读取流中核对实际内容。服务拒绝后不自动换模型或只发送文件名。

活动上下文保留文件引用。压缩不会删除原文件；重新生成使用所选回复之前的有效附件。仅由退役历史版本引用的文件不会自动进入当前模型请求。

## 平台与维护

原生二进制位于应用支持目录的 `Sked_agent_attachments`；写入临时文件由同一拥有者管理。Web 使用独立 IndexedDB Blob。附件元数据和引用使用新的 Agent 库，不再写入聊天双槽 JSON。

恢复和清空先取消未接纳工作并排空已经接纳的写入。原生清空先关闭 SQLite isolate，释放文件句柄，再删除应用管理的数据。失败后重新读取实际存储，不能用旧内存复活已经清除的内容。

备份中的附件元数据随聊天保存，二进制单独选择；未携带的文件在恢复后保持缺失。恢复前的空会话草稿只在全部恢复完成后丢弃。

## 验证入口

- [附件仓储](../test/agent/attachments/attachment_repository_test.dart)：复制、核验、取消、重开和保存失败。
- [流式上传](../test/agent/provider/provider_streaming_upload_test.dart)与[协议附件](../test/agent/provider/provider_attachments_test.dart)：实际请求编码、字节流、取消及能力错误。
- [历史引用回收](../test/agent/attachments/attachment_history_collection_test.dart)与[SQLite 分页](../test/agent/store/agent_store_test.dart)：未加载历史的引用保留。
- [运行时附件](../test/agent/runtime/agent_attachments_test.dart)、[菜单与预览](../test/agent/ui/agent_attachment_view_test.dart)、[浏览器 Blob](../test/agent/attachments/attachment_storage_browser_test.dart)：各自环境中的交互与存储行为。

Windows、Android 文件选择和真实模型接收能力按正式平台场景另行记录。