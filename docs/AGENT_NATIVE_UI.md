# Agent 主界面原生验证

正式 Agent 界面由 `AgentApplication` 装配 Rust 核心。[原生离线旅程](../integration_test/agent_rust_offline_journey_test.dart)在 Windows／Android 上通过真实 FRB、JSONL、SQLite、业务保存和 Flutter 页面验证完整调用链。模型回复使用预置传输内容。

## 功能旅程

[主流程](../integration_test/support/agent_rust_offline_journey.dart)检查草稿、分页、来源引用、标题、流式回复、三种权限、队列、停止继续、页面关闭期间的已接纳保存，以及关闭后重新读取业务与 Agent 存档。

同一入口继续执行：

- [历史流程](../integration_test/support/agent_rust_history_journey.dart)：重新生成、编辑重做、跨业务与知识仓储的撤销和恢复预约。
- [选择恢复流程](../integration_test/support/agent_rust_backup_journey.dart)：新 Agent 备份、业务对象选择、固定目标、回执丢失后恢复、附件缺失，以及恢复完全成功时才丢弃未发送草稿。
- [清空流程](../integration_test/support/agent_rust_clear_journey.dart)：关库、失败后重开、旧核心迟到回执隔离和成功清空后的写入关闭。

这些流程使用[独立原生工作区](../integration_test/support/agent_rust_offline_workspace.dart)。可见组件和系统输入的覆盖以入口实际调用为准；数据保存由实际文件读回核对。布局、菜单、输入行、模型浮层、回执文案和编辑表单继续由 [Agent 组件回归](../test/agent/ui)检查。

## 原生读屏

[Windows 读屏入口](../integration_test/native_accessibility_smoke_test.dart)保留同一原生进程的 MSAA 探针。其 [Agent 场景](../integration_test/support/agent_native_accessibility.dart)使用正式应用与原生存档，检查设置、偏好、Skills、Memory、计划预览分页、首末项详情、输入框及允许／拒绝入口，操作完成后核对持久回执。

读屏场景通过 [Agent 原生工作区](../integration_test/support/agent_native_accessibility_workspace.dart)构造合成内容，分别运行 baseline 和 accessible 配置。报告记录实际窗口、DPR、字号、主题、进程与探针结果。运行方式和系统探针前置条件见[原生可访问性验证](NATIVE_ACCESSIBILITY_SMOKE.md)。

## 运行与证据

先在独立测试 checkout/build tree 中安装锁定依赖。Windows 需按[原生隔离约定](WINDOWS_NATIVE_ACCEPTANCE.md)设置唯一的 `SKED_WINDOWS_TEST_NAMESPACE`；Android 使用独立测试 applicationId。构建与运行使用同一个候选工作区。

Windows 执行前把 `TEMP`、`TMP`、`TMPDIR` 指向本轮 F 盘目录；Android 数据位于独立测试包的私有临时目录，模拟器与主机工件保存在 F 盘。

```powershell
$agentRevision = (git rev-parse HEAD).Trim()
flutter test --no-pub -d windows integration_test/agent_rust_offline_journey_test.dart `
  "--dart-define=SKED_AGENT_NATIVE_REVISION=$agentRevision"
if ($LASTEXITCODE -ne 0) { throw 'Rust Agent offline journey failed' }
```

Android 将设备参数替换为本轮核实的测试设备 ID。报告通过 `IntegrationTestWidgetsFlutterBinding.reportData` 提供 `agentRustOfflineJourney`，包括源码基点、平台、临时目录、有序检查点和失败信息。保存完整命令与进程日志；候选有未提交改动时，同时保留差异与文件摘要。

真实模型调用和性能对照保持暂停。Windows／Android 的编译、离线旅程、原生读屏、模拟器和实体设备分别记录实际执行结果。
