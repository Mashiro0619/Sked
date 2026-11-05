# Agent 主界面原生验证

[主界面与设置入口](../integration_test/agent_overhaul_native_test.dart)在 Windows 的真实 Flutter surface 上验证内嵌聊天、资源历史、紧凑活动及二三级设置导航。窗口尺寸通过现有 Win32 窗口脚本调整，等待实际 View 更新；不覆盖测试 View 的尺寸或 DPR。

测试使用合成主库、聊天、凭据与内存存储。活动展示使用显式保存的 11 条消息、1 个轮次、8 项工具和已结束运行；不请求模型或重放工具。原生绘制与窗口尺寸、框架注入的点击／文字／返回、合成存储结果分别记录，不代表实体设备、原生输入法或实际模型质量验收。

## 覆盖与工件

入口分别运行简体中文浅色 1× 和深色 2× 场景，验证未发送会话不进入存档、主标题与统一新建入口、活动折叠／列表／单项详情、模型保存后父连接草稿保留，以及返回取消与丢弃。每轮捕获 8 张实际 View 绘制图片，记录源码 SHA、客户区与图片尺寸、DPR、字号、语言和主题。

场景失败时保留当前可绘制界面与输入框位置作为诊断工件，仍按原失败退出；失败画面不计入通过场景的截图清单。

`SKED_SOURCE_SHA` 必须是该测试树对应的完整提交 SHA，`SKED_AGENT_OVERHAUL_WINDOW_SCRIPT` 必须指向同一 checkout 内窗口脚本的绝对路径，不依赖原生进程的工作目录。`SKED_AGENT_OVERHAUL_CAPTURE_DIR` 可通过 Dart define 或进程环境指定，必须是系统临时目录中的独立绝对路径；显式目录保留截图和 `agent-overhaul-evidence.json`。未指定时由测试创建并清理自己的临时目录。

## 运行

先按[原生隔离运行说明](NATIVE_ACCESSIBILITY_SMOKE.md#running)创建路径较短的系统临时 checkout，安装根项目和内部 Android 插件的锁定依赖，并在构建前配置唯一的 `SKED_WINDOWS_TEST_NAMESPACE`。合成 Dart 数据不能隔离 Windows 实例互斥量与窗口状态；不能使用生产构建目录或个人存档运行入口。

在已配置隔离命名空间的测试 checkout 根目录执行：

```powershell
$agentUiRevision = (git rev-parse HEAD).Trim()
$agentUiWindowScript = (Resolve-Path -LiteralPath 'tool/capture_workbench_window.ps1').ProviderPath
$agentUiCaptures = Join-Path ([IO.Path]::GetTempPath()) ('sked-agent-ui-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $agentUiCaptures -ErrorAction Stop | Out-Null
flutter test --no-pub -d windows integration_test/agent_overhaul_native_test.dart `
  "--dart-define=SKED_SOURCE_SHA=$agentUiRevision" `
  "--dart-define=SKED_AGENT_OVERHAUL_WINDOW_SCRIPT=$agentUiWindowScript" `
  "--dart-define=SKED_AGENT_OVERHAUL_CAPTURE_DIR=$agentUiCaptures"
if ($LASTEXITCODE -ne 0) { throw 'Agent native UI verification failed' }
```

同时保留 CMake cache、命令日志和截图清单，并确认构建后命名空间仍一致。工作树有源码改动时，SHA 仅标识基点，需另存实际候选差异与文件摘要。临时截图与日志不进入仓库。

与[主工作区运行冒烟](../integration_test/agent_platform_smoke_test.dart)、[平台功能旅程](../integration_test/AGENT_FEATURE_JOURNEYS.md)及[原生读屏门禁](NATIVE_ACCESSIBILITY_SMOKE.md)分别执行；本入口不替代它们的运行、持久化和原生输入范围。
