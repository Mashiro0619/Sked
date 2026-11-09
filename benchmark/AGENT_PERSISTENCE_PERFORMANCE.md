# Agent 持久化性能协议

> 历史协议：下文记录旧 Dart Agent 实现的测量方法和字段。对应执行入口随 Rust 切换退役，既有报告保留原源码与数据身份。真实模型和性能对照保持暂停；重新开始时须为正式 Rust 装配建立新的固定基线。

`agent-persistence-v1` 在 Windows 或 Android 的原生 Profile 进程中测量正式会话仓储。消息夹具与 `agent-ui-frames-v3`、`agent-stream-frames-v1` 共用：一个 512 条消息的长会话和一个 2 条消息的独立短会话，正文、身份、日期和初始草稿固定。

每个进程使用新的系统临时目录和真实持久后端。当前实现使用后台 SQLite；对照旧版本时使用该版本正式的 `PlatformConversationStorage` 双槽 JSON，并仅适配测试入口。主仓库的生产存储不提供回退选项。

## 测量动作

每个样本顺序记录 35 个区间：写入固定夹具、关闭后首次加载、连续 32 次草稿持久更新、再次关闭并重开加载。每次更新通过 `ConversationRepository.update` 并等待实际保存；第一次更新包含正式仓储按需加载完整历史的成本。

计时使用 `Timeline.now`，每个区间同时记录前后进程 RSS。摘要计算、最终完整读取、文件大小统计和临时目录清理在计时区间之外。最终读回必须确认版本增加 32、长会话草稿为最后一次值、短会话草稿不变、两份原始消息摘要不变。

区间记录加载路径的实际行为：JSON 可以整档读取，SQLite 可以只读选中页；`loadedMessagesAfterColdLoad` 保留实际数量。不能先读取完整归档再测量首次加载。

## 运行与来源

先完成依赖安装和构建准备，在没有并发测试、分析、构建或其他性能进程时采样。每个版本、平台及设备分别运行三个独立进程，固定夹具、协议、构建模式和环境。每轮使用新的 `FLUTTER_TEST_OUTPUTS_DIR` 绝对目录，并保存完整标准输出及错误输出。

```powershell
flutter drive --profile -d windows `
  --driver=test_driver/agent_persistence_performance_driver.dart `
  --target=integration_test/agent_persistence_performance_benchmark_test.dart `
  --dart-define=SKED_AGENT_PERSISTENCE_REVISION=<完整源码SHA> `
  --dart-define=SKED_AGENT_PERSISTENCE_LABEL=<本轮标识>
```

入口要求 Profile、原生 Windows/Android 和完整源码 SHA，不属于默认 VM 测试目录。驱动保存全部原始区间、读回结果、后端类型、关闭后的持久文件大小及相关源码 SHA-256；失败也保留报告。含未提交变更时，报告的源码 SHA 与文件摘要共同标识实际来源。

旧版本对照需要保存可审查的测试适配补丁与文件摘要。适配仅调整真实存储构造和测试观察接口，保持消息、32 次草稿值、计时区间及读回条件相同。选择旧基线时确认其应用实际使用 JSON，不能把尚未接入的 SQLite 基础提交当成新后端。

本协议提供持久写入与重开证据；页面加载、滚动和流式更新分别使用 `agent-ui-frames-v3` 与 `agent-stream-frames-v1`，按各自原生帧协议关联比较。
