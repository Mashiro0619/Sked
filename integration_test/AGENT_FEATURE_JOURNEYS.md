# Agent 原生功能旅程

入口为 `agent_feature_journeys_test.dart`，driver 为 `../test_driver/agent_feature_journeys_driver.dart`。当前只实现 `SKED_AGENT_FEATURE_JOURNEY=knowledge`，用于验证实际主页 → Agent → 独立 Agent 设置页的知识编辑流程。附件、审批、历史撤销、选择性恢复和原生系统能力需要各自独立的旅程；本入口通过不能代替这些验收。

## knowledge 的固定流程

1. 使用 `AgentNativeSession(provider:)` 的显式合成内存存储装载真实 `AppRuntime`，主页挂载前后均核对 Agent 历史尚未加载。
2. Windows 从主页 Agent 按钮进入真实 `AgentAssistantPane`；Android 从通用工作区“更多”菜单进入真实 `AgentPage`。核对同一 `AgentApplication`、主会话、会话仓库及 512 条历史，并通过输入框保存一条未发送草稿。
3. 通过会话菜单进入独立 Agent 设置页，在 Memory 页签创建并保存一条合成记忆。等待知识仓库写入完成，再调用生产知识服务 `initialize(reload: true)` 读回存储，核对 ID、内容、版本及实际保存回执。
4. 点击同一记录，编辑标题和正文并保存，再次读回存储。记录保持同一 ID，版本从 1 增至 2，档案中仍只有一条 Memory。
5. 点击设置页返回按钮回到原聊天，再从会话菜单重新进入设置，打开同一 Memory，核对实际编辑框内容。点击对话框“取消”，访问 Skills 页签及可用的添加按钮，并确认内置目录已经加载。再次读回知识存储，核对取消和页签切换没有新增写入。
6. 返回原聊天，核对可见草稿与持久草稿一致，另一会话的草稿及两份历史均未改变，主工作区快照保持进入 Agent 时的内容。
7. 卸载界面，取消运行、排空写入并关闭全部会话所有者、provider、备份暂存和偏好，再恢复本旅程拥有的边界。任何清理失败都使本轮失败。

所有写入来自真实 UI 的保存动作。直接仓库调用只用于等待完成及重新加载后核对存储，不用于创建记录、修改草稿或模拟成功回执。Knowledge 专属 provider 拒绝任何模型请求，driver 要求请求数和传输尝试数都为零。本旅程没有文件选择器替身，也不读取个人数据库或凭据。共享 HTTP guard 只阻止当前原生 UI isolate 中的 `dart:io` HTTP 操作；它不证明其他 isolate、原生代码或其他进程完全没有网络活动。

## 原生平台与框架配置

每个平台、配置组合使用独立进程及独立输出目录：

| 平台 | 实际 surface | baseline | accessible |
| --- | --- | --- | --- |
| Windows | 原生桌面窗口，至少 1100 × 600 逻辑像素 | 浅色、1× 字号、reduceMotion=false | 深色、2× 字号、reduceMotion=true |
| Android | 原生 Android Flutter surface，报告记录 API、ABI 和 qemu 属性 | 浅色、1× 字号、reduceMotion=false | 深色、2× 字号、reduceMotion=true |

两种配置均使用相同的真实原生 surface，不覆盖物理尺寸或 DPR。主题、`TextScaler` 和减少动态效果来自框架配置，`disableAnimations` 保持 false；不能将这些配置记作系统主题、原生无障碍服务、实体设备或 IME 验收。框架键盘和按钮/滚动操作只验证 Flutter 产品路径。Android 的 qemu 属性为 `1` 时报告明确标注 emulator，其余情况保留为未分类的原生 Android surface，不能据此推断实体设备。

报告记录平台、系统版本、Dart 版本/ABI、构建模式、进程、实际物理/逻辑尺寸、DPR、刷新率和观察到的无障碍标志。Windows `flutter_tester`、Web 及其他平台均被拒绝。测试不安装帧时间或内存采样器；性能取样期间不得并发执行本旅程、分析或构建。

## 执行与证据

先按 [贡献指南](../CONTRIBUTING.md) 完成依赖和静态检查，核对源码、工作区与正在运行的任务。以下示例从仓库根目录运行；执行者须将源码 SHA 与实际构建输入、完整命令、平台和输出关联。不要把 driver 读取到的文件哈希当成原生二进制证明。

Windows 在独立测试 checkout/build tree 中先按[原生隔离约定](../docs/WINDOWS_NATIVE_ACCEPTANCE.md)配置非空 `SKED_WINDOWS_TEST_NAMESPACE`，使用已配置 CMakeCache 记录的 CMake 可执行文件。最终 `flutter drive` 使用同一构建树；`NO_PROXY` 仅为本轮 driver 的回环连接设置并在结束后恢复。下例沿用[核心原生旅程](README.md)的实际准备命令，将 target 和 driver 改为本功能入口。归档候选须显式填入与构建输入一致的完整源码 SHA，并用 `SKED_AGENT_NATIVE_SOURCE_NOTE` 另记候选树。

```powershell
$featureRevision = '<full40-source-sha>'
$featureDevice = 'windows'
$featureConfig = 'baseline'
$featureLabel = 'windows-knowledge-baseline'
$featureOutput = Join-Path ([IO.Path]::GetTempPath()) ('sked-agent-knowledge-' + [guid]::NewGuid().ToString('N'))
$previousFeatureOutputs = $env:FLUTTER_TEST_OUTPUTS_DIR
$previousFeatureNoProxy = $env:NO_PROXY
if ($featureDevice -eq 'windows') {
  flutter build windows --debug --config-only --no-pub `
    --target=integration_test/agent_feature_journeys_test.dart
  if ($LASTEXITCODE -ne 0) { throw 'Windows configuration failed.' }
  $featureCmake = (Select-String -LiteralPath build/windows/x64/CMakeCache.txt -Pattern '^CMAKE_COMMAND:INTERNAL=(.+)$').Matches.Groups[1].Value
  & $featureCmake -S windows -B build/windows/x64 `
    "-DSKED_WINDOWS_TEST_NAMESPACE=agent-feature-$([guid]::NewGuid().ToString('N'))" `
    -DSKED_BUILD_WINDOWS_RUNNER_TESTS=ON
  if ($LASTEXITCODE -ne 0) { throw 'Windows test namespace configuration failed.' }
}
try {
  $env:FLUTTER_TEST_OUTPUTS_DIR = $featureOutput
  $env:NO_PROXY = '127.0.0.1,localhost'
  flutter drive --no-pub -d $featureDevice --driver=test_driver/agent_feature_journeys_driver.dart --target=integration_test/agent_feature_journeys_test.dart --dart-define=SKED_AGENT_FEATURE_JOURNEY=knowledge "--dart-define=SKED_AGENT_NATIVE_CONFIG=$featureConfig" "--dart-define=SKED_AGENT_NATIVE_REVISION=$featureRevision" "--dart-define=SKED_AGENT_NATIVE_LABEL=$featureLabel"
  if ($LASTEXITCODE -ne 0) { throw 'Agent knowledge native journey failed.' }
} finally {
  $env:NO_PROXY = $previousFeatureNoProxy
  if ($null -eq $previousFeatureOutputs) {
    Remove-Item Env:FLUTTER_TEST_OUTPUTS_DIR -ErrorAction SilentlyContinue
  } else {
    $env:FLUTTER_TEST_OUTPUTS_DIR = $previousFeatureOutputs
  }
}
```

`accessible` 单独运行，改动配置和标签并新建输出目录；Android 改用 `flutter devices` 中本轮核实的设备 ID，同时记录模拟器/设备来源。`SKED_AGENT_NATIVE_SOURCE_NOTE` 可以补充候选来源，但不能代替完整 SHA 和构建输入核对。

driver 使用协议 `agent-native-feature-journey-v1`，先保存原始响应和其 checkout 中相关源码的 SHA-256，再校验 knowledge 专属的有序检查点、实际记录读回、版本变化、草稿/历史、零请求和完整清理。已有报告文件拒绝覆盖。配置错误、UI 失败和清理失败均保留在 `agent-feature-journey-raw.json`；`agent-feature-journey-assessment.json` 记录 driver 的通过或失败判断。未产生响应、进程崩溃或设备断开仍需保留命令日志，不能制造完整 JSON 证据。

JSON 通过之后，仍需复核本轮原生进程日志中的 Flutter 错误、AXTree 或平台 fatal 信息。原生运行、模拟器、框架配置、实际系统能力与实体设备结果分别记录，不能互相替代。运行报告和日志保留在系统临时目录供检查，不提交到仓库；清理时只处理本轮拥有且已核对绝对路径的目录。
