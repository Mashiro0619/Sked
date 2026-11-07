# Agent 主界面原生验证

[主界面与设置入口](../integration_test/agent_overhaul_native_test.dart)在 Windows 的真实 Flutter surface 上验证内嵌聊天、资源历史、紧凑活动及二三级设置导航。窗口尺寸通过现有 Win32 窗口脚本调整，等待实际 View 更新；不覆盖测试 View 的尺寸或 DPR。

主库和凭据使用合成内容；聊天与知识使用测试独占临时目录中的后台 SQLite。活动历史夹具保存 7 条消息、1 个轮次、2 次查询和 1 次 `mutation.apply`；一条已保存回执包含课表及两门课程。报告分别记录持久历史展示、脚本 Provider 驱动的真实运行时、原生绘制和框架输入。

## 覆盖与工件

入口依次请求四组简体中文窗口：浅色 1× 宽窗 1440×900、深色 2× 宽窗 1280×820、浅色 1× 窄窗 640×900、深色 2× 窄窗 640×900。验证未发送会话不进入存档、主标题与统一新建入口、完成过程默认折叠、查询与操作详情内联展开，以及辅助面板在宽窗内联和窄窗底部展示。设置旅程核对模型保存后父连接草稿保留，以及返回取消与丢弃。每个配置还运行六种状态，截图清单记录实际 View 尺寸、DPR、字号、语言、主题和源码 SHA。

跨平台入口 [agent_run_states_native_test.dart](../integration_test/agent_run_states_native_test.dart) 在 Windows 或 Android 主界面复用相同的六态场景：

| 状态 | 数据与执行来源 | 核对内容 |
| --- | --- | --- |
| 进行中 | 脚本流式回复，真实统一运行时 | 草稿区可用；先排队，再立即补充；切回业务页并重开后保留会话与运行；停止后不执行排队项 |
| 待确认 | 真实 `mutation.apply` 编译与询问模式审批 | 一个操作行、可见确认入口、主库保持审批前内容 |
| 待回答 | 真实 `ask_user` 与持久问题 | 问题输入可见，待答记录已进入 SQLite |
| 完成 | 真实 `mutation.apply` 保存合成日程 | 一个已保存操作行和唯一业务结果 |
| 错误 | 脚本传输错误经过运行时结算 | 错误反馈及继续入口 |
| 恢复 | SQLite 重读合成待核对结果，再调用实际恢复流程 | 待核对提示、继续入口及业务内容保持 |

运行与问答由受控 Provider 提供事件，HTTP 客户端拒绝网络调用。Provider 的异步事件回调使用 `expectSync` 校验空凭据、取消令牌与请求轮次，允许原生帧泵同时推进。恢复夹具表示已有结果无法核对的存档状态；进程强杀、实体设备与真实模型另按各自入口记录。

跨平台入口参数包括 `SKED_SOURCE_SHA`、`SKED_AGENT_STATES_CAPTURE_DIR`、`SKED_AGENT_STATES_DARK`、`SKED_AGENT_STATES_TEXT_SCALE`、`SKED_AGENT_STATES_RTL` 和 `SKED_AGENT_STATES_KEYBOARD`。主题、字号和布局方向可独立组合；RTL 使用中文内容核对镜像布局。`SKED_AGENT_STATES_ACCESSIBLE=true` 是深色、2× 的便捷默认值。

Windows 最低覆盖上述四组窗口，以及独立的深色 1×、浅色 2×、RTL 各一轮；Android 实际窄屏浅/深、2×、RTL 和软件键盘各一轮。Android 键盘场景使用真实 IME 和 `View.viewInsets`，拒绝零键盘避让量，不注入测试视口高度。PNG 是 Flutter View 内容，报告另存实际键盘避让量；系统键盘本身的画面可在同一轮补采设备截图。

场景失败时保留当前可绘制界面与输入框位置作为诊断工件，仍按原失败退出；失败画面不计入通过场景的截图清单。六态等待遇到非预期运行失败时立即记录目标状态、实际状态、请求计数及运行时已脱敏的错误详情；执行 Future 的原异常与堆栈继续上抛。立即补充按 runId 区分仍在收尾的旧请求取消与新请求失败，保留两次请求、新 owner 和流式回复的完整条件；报告记录等待期间的 owner、状态、停止与继续入口及相对耗时。未达到目标的超时也保存同一诊断，两个原生入口均将其写入报告。

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

跨平台六态可使用 `flutter drive --no-pub -d <设备> --target=integration_test/agent_run_states_native_test.dart --driver=test_driver/agent_run_states_native_driver.dart`，传入前述 Dart defines；每轮为 `FLUTTER_TEST_OUTPUTS_DIR` 分配新的系统临时目录。Android 使用独立测试 applicationId；原生包身份与 Dart 的 PackageInfo 测试值分别核对。功能旅程继续负责知识、附件、编辑重做和选择恢复；原生主旅程负责长历史阅读、流式输入和重开。

## 现有连接与真实模型

[真实模型入口](../integration_test/agent_live_model_test.dart) 使用现有 Agent 连接和合成业务内容，验证创建课表与两门课程、只读计划、问答和审批、自动压缩与手动压缩。用 [driver](../test_driver/agent_live_model_driver.dart) 保存主机报告。

`SKED_AGENT_LIVE_PROFILE_FILE` 指向显式选定的现有 AppData 主存档；也可用 `SKED_AGENT_LIVE_CONNECTION_FILE` 指向其独立 AgentSettings JSON，两者选一。入口读取连接后新建合成主库、临时 SQLite 与附件目录，结束时核对连接来源字节不变。`SKED_AGENT_LIVE_REPORT_FILE` 是原生进程可写的临时报告绝对路径，`SKED_SOURCE_SHA` 记录候选源码。

Windows 默认通过原生安全存储只读 active/pending 槽，复制到本轮内存凭据库。Android 独立测试包使用 `SKED_AGENT_LIVE_CREDENTIALS_FILE`：文件放在该测试包 `getTemporaryDirectory()` 内，JSON 的 `active`、`pending` 值为现有安全槽原文或 null。文件路径经实际路径核对，读取成功或解析失败均在 finally 删除；槽内容不写入命令行、Dart defines、APK 或验收报告。连接文件只携带 AgentSettings，不复制个人课表。

Android 可先构建并安装独立调试包，把连接与凭据经标准输入写入 `run-as <测试包>` 的私有缓存，然后以 `flutter drive --use-application-binary=<已构建APK> --target=integration_test/agent_live_model_test.dart --driver=test_driver/agent_live_model_driver.dart` 启动同一构建。Dart defines 只包含该包内的输入/报告路径；驱动结束后取回报告并清理测试包。
