# Agent 原生功能旅程

入口是 [agent_rust_offline_journey_test.dart](agent_rust_offline_journey_test.dart)。它通过正式 `AppRuntime`／`AgentApplication` 调用 Rust 核心与 Dart 业务宿主，使用真实 FRB、JSONL、SQLite 和主库文件；模型回包由原生离线传输提供。

| 流程 | 核对内容 | 实现 |
| --- | --- | --- |
| 会话与执行 | 未发送草稿、来源、分页、AI 标题、工具发现、权限、队列、停止继续、页面关闭和重开 | [主流程](support/agent_rust_offline_journey.dart) |
| 历史 | 回复重新生成、编辑重做、业务与知识逆变更、恢复预约与实际存档 | [历史流程](support/agent_rust_history_journey.dart) |
| 备份 | 新格式导出与选择恢复、固定对象映射、阶段中断重试、附件缺失、草稿清理边界 | [备份流程](support/agent_rust_backup_journey.dart) |
| 清空 | 关库后清空、失败重开、迟到回执归属、成功后的写入关闭 | [清空流程](support/agent_rust_clear_journey.dart) |

[独立工作区](support/agent_rust_offline_workspace.dart)负责合成主库、凭据、原生目录和共享生命周期。检查等待实际完成信号，保留每次已接纳保存的真实回执；清理错误使本轮失败。临时数据不得指向个人存档。

附件的协议编码、分块上传、上下文引用和原生回收还由 [Rust 离线核心旅程](../rust/src/runtime/journey.rs)与[请求体检查](../rust/src/model_client/request_body.rs)验证。知识编辑、回执展示和输入交互由 [Flutter 组件回归](../test/agent/ui)保持；组件测试采用明确的展示夹具，核心执行和持久化由原生旅程验证。

Windows／Android 运行方式、报告字段、测试包隔离和原生读屏入口见 [Agent 主界面原生验证](../docs/AGENT_NATIVE_UI.md)。每次结果关联实际源码、完整命令、平台和候选文件摘要。真实模型与性能对照保持暂停。
