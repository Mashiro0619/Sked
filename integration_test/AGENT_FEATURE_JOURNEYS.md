# Agent 原生功能旅程

入口为 `agent_feature_journeys_test.dart`，driver 为 `../test_driver/agent_feature_journeys_driver.dart`。`SKED_AGENT_FEATURE_JOURNEY` 显式选择 `knowledge`、`attachments`、`history` 或 `selective-backup`，各自使用独立进程、检查点和结果校验。审批和原生系统能力仍需要各自的旅程，不能由这些结果代替。

## knowledge 的固定流程

1. 使用 `AgentNativeSession(provider:)` 的显式合成内存存储装载真实 `AppRuntime`，主页挂载前后均核对 Agent 历史尚未加载。
2. Windows 从主页侧栏进入真实 `AgentPage`；Android 通过主页导航按钮打开现有侧抽屉，再进入同一完整聊天。核对同一 `AgentApplication`、主会话、会话仓库及 512 条历史，并通过输入框保存一条未发送草稿。
3. 通过会话菜单进入 Agent 设置总览，打开 Memory 二级页，再在三级编辑页创建并保存一条合成记忆。等待知识仓库写入完成，再调用生产知识服务 `initialize(reload: true)` 读回存储，核对 ID、内容、版本及实际保存回执。
4. 点击同一记录，编辑标题和正文并保存，再次读回存储。记录保持同一 ID，版本从 1 增至 2，档案中仍只有一条 Memory。
5. 从 Memory 页返回设置总览，再返回原聊天；通过会话菜单重新进入设置并打开同一 Memory，核对三级编辑页的实际输入内容。修改正文后点击“取消”，再明确确认丢弃未保存修改。返回总览并进入 Skills 二级页，核对可用的添加按钮和已加载的内置目录。再次读回知识存储，核对取消和分类页面导航没有新增写入。
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

driver 使用协议 `agent-native-feature-journey-v1`，先保存原始响应和其 checkout 中相关源码的 SHA-256，再校验所选功能的有序检查点、实际存储读回、草稿/历史、对应请求次数和完整清理。已有报告文件拒绝覆盖。配置错误、UI 失败和清理失败均保留在 `agent-feature-journey-raw.json`；`agent-feature-journey-assessment.json` 记录 driver 的通过或失败判断。未产生响应、进程崩溃或设备断开仍需保留命令日志，不能制造完整 JSON 证据。

JSON 通过之后，仍需复核本轮原生进程日志中的 Flutter 错误、AXTree 或平台 fatal 信息。原生运行、模拟器、框架配置、实际系统能力与实体设备结果分别记录，不能互相替代。运行报告和日志保留在系统临时目录供检查，不提交到仓库；清理时只处理本轮拥有且已核对绝对路径的目录。

## attachments 的固定流程

在独立进程中将上例的 `SKED_AGENT_FEATURE_JOURNEY=knowledge` 改为 `SKED_AGENT_FEATURE_JOURNEY=attachments`，使用附件专属标签和新输出目录，并继续遵守同一原生平台、Windows 测试命名空间与代理准备要求。不得以文件选择器替身代替 Windows 原生测试进程隔离。

1. 从真实主页进入 Agent，清空合成长会话的输入框，然后点击 `agent-attach-file`。本旅程独占并最终恢复 `FileSelectorPlatform.instance`，只返回一次内存中的 4 × 4 合成 PNG；产品正常执行本地复制、摘要核验和草稿引用发布。
2. 等待文件成为本地已保存状态，读取实际聊天存储和 `attachmentStore.readBytes`，核对原始 79 字节、SHA-256、稳定 ID 和唯一文件。聊天 JSON 不得包含来源路径或 Base64 正文，选择文件不发起请求，也不自动预览。
3. 从草稿附件菜单点击“预览文件”，等待真实 `RawImage` / `RenderImage` 完成解码，核对其内存图片字节和非零实际渲染尺寸。随后点击真实“关闭”按钮。仅构造 `Image` 组件不能视为解码通过。
4. 保持输入框为空，点击发送。生产 `ProviderClient` 完成预算检查、文件读取、`image_url` 原生内容块编码、进度和响应解码；专属离线 `http.BaseClient` 接收编码后的请求，核对 Base64 中的原始 PNG 字节与摘要，再返回一次合成 HTTP 200 JSON 回复。
5. 核对聊天只新增一条正文为空的附件用户消息和一条脚本回复，引用从草稿转到用户消息。编码、发送和已接受状态来自生产 provider 对该合成响应的处理；这里的“已接受”只表示测试 transport 的响应，不代表远端服务或模型已接收、理解文件。
6. 输入下一条未发送草稿，通过真实会话列表切到短会话，再回到长会话。核对两份原始历史、独立草稿和同一文件身份；附件菜单不在可见区域时，按实际几何方向拖动消息区，确认菜单可点击后，再从已保存消息显式预览同一图片。报告保留拖动次数与方向，不能用不改变跟随状态的程序定位代替用户滚动。重开和预览不重新发送请求，也不复制二进制文件；主工作区保持进入 Agent 时的快照。
7. 先由公共 runner 卸载界面并关闭全部运行时 owner，再逐项完成本旅程捕获的图片缓存清理和 picker 恢复。driver 要求一次 picker 选择、一次脚本 provider/transport 请求、两次实际图片预览、完整流结束及零 `dart:io` HTTP 操作。

输入来自 `XFile.fromData`，不创建源文件或读取个人路径。文件选择器及 HTTP transport 均为本旅程显式拥有的合成边界；本轮不证明系统文件对话框、文件权限、外部分享、真实模型或跨进程附件重启恢复。故障注入、取消、未知投递及原生存储重开仍按[附件协议](../docs/AGENT_ATTACHMENTS.md)的对应验证入口分别记录。

中央 driver 先验证原生环境、源码、框架配置、主页入口和运行时清理，再调用附件专属 assessor 核对实际字节、稳定引用、显式操作和精确请求计数。新增其他 feature 必须显式添加完整检查点及专属 assessor，未知名称直接失败，不能靠任意自报检查点获得通过。

## history 的固定流程

在独立进程中选择 `SKED_AGENT_FEATURE_JOURNEY=history`，另设本轮标签和新的系统 Temp 输出目录。继续使用真实主页、`AgentNativeSession` 的明确合成存储，以及同一平台与框架配置。Windows 使用独立测试 checkout/build tree 和非空 `SKED_WINDOWS_TEST_NAMESPACE`；最终 `flutter drive` 必须使用已经核对过该 namespace 的同一 CMakeCache。参见 [Windows 原生验收](../docs/WINDOWS_NATIVE_ACCEPTANCE.md)。

1. 从正式主页进入当前 Agent 长会话，经可见输入框和发送按钮发出一个合成请求。受控 provider 只返回 `capabilities.describe → mutation.prepare → mutation.commit` 的真实工具调用，以及最终文字回复。应用工具创建一个隐藏的空合成日历；旅程通过生产 codec 读回主库和聊天，核对真实可逆回执及宿主记录的运行/工具/轮次归属。
2. 再通过输入框发送一个后续纯文字请求。保留两个独立轮次，原日历操作仍只属于首轮。
3. 点击实际回复的“重新生成回复”按钮。受控 provider 检查这次请求没有工具目录，只返回新文字。原回复 ID、消息顺序、操作归属和主库保持不变，两份回复文字版本均保留；同时读取实际 RenderParagraph / RenderEditable 核对可见的新正文。
4. 保存一条未发送的聊天草稿。通过首轮用户消息的“编辑并重做”进入实际对话框，修改文字后点击“取消”；聊天内容、主库和 provider 次数不变。重新打开同一对话框，实际输入框仍保存刚取消的编辑内容，聊天输入草稿保持独立。
5. 点击实际确认按钮。正式历史协调器完整预检并撤销原日历创建，保留两个旧轮次和旧消息后缀，再仅执行选中的一个编辑后请求。通过真实主库逆回执、持久批次与存档读回核对：只有一次逆操作、批次完成、原日历已消失、除操作账本外的全部主库字段恢复原值；后续旧请求不重放。历史预约和恢复标记释放，普通聊天与主库可继续写入。 若阅读位置仍在旧历史中，通过实际“回到最新”按钮查看重做后的回复；核对可点击状态和真实渲染正文，不以固定次数滚动代替完整长历史中的正式导航。
6. 从会话菜单打开“消息历史”，分别展开旧后缀和两份回复版本。核对实际可见旧文字，关闭对话框后请求数、当前上下文与存储摘要不变，未发草稿保持。原 512 条历史、短对照会话和共享知识也保持各自原状态。
7. 沿公共清理流程卸载界面，排空写入并关闭运行时、仓储、provider 和偏好。provider 和 transport 均只关闭一次；本功能不安装文件选择器或平台 channel 替身。

provider 固定为七次本地受控响应：首轮四次、后续文字一次、重新生成一次、编辑重做一次。普通请求保持正式工具目录，只有重新生成请求为空；重做请求不得包含已退役的两条用户消息，也不得发送仍在输入框中的草稿。原始报告记录各次用户消息列表、工具名、工具参数和实际回执来源；不记录凭据。注入的 HTTP client 拒绝任何发送，不访问真实模型。

这组验证的是原生 Flutter 产品 UI、正式历史协调器、主库撤销及纯文字重新生成的组合。它不注入存储故障，也不覆盖跨仓储中断、知识逆变更、恢复后继续、冲突降级、原生文件持久化、系统强杀、真实模型或实体设备。相关故障/恢复证明仍分别见 [历史协议](../docs/AGENT_HISTORY.md) 中的专项入口。界面打开、返回、主题和 2× 字号是实际运行配置的证据，不等同于 OS IME、物理手势或原生无障碍验收。

## selective-backup 的固定流程

在独立进程中选择 `SKED_AGENT_FEATURE_JOURNEY=selective-backup`，使用备份专属标签和新输出目录，并遵守同一原生平台、Windows 测试命名空间与代理准备要求。

1. 从真实主页进入 Agent，经实际输入框保存一条未发送草稿。根据合成主库构造旧 JSON 文件：同 ID 日历和其事件具有新的标题；输入还包含名称不同的未选课表及一个仅存在于归档中的额外日历。构造输入使用 `encodeAppBackup`，不向运行时写入测试目标。
2. Android 通过 Agent 页的真实返回按钮回到主页；Windows 使用已有主页的设置入口，包括桌面资源侧栏底部的设置。按实际可点击控件进入设置，紧凑布局先打开“更多”菜单；报告记录真实入口及菜单路径，driver 核对二者一致。进入实际全局设置，点击“备份与恢复”及“从文件恢复”。本旅程拥有并最终恢复 `FileSelectorPlatform.instance`，只返回一次内存中的合成 JSON；产品负责读取字节、解码并打开同一应用服务拥有的对象选择页。
3. 点击“清除选择”，在实际搜索框输入目标日历名称，并勾选唯一日历。核对真实复选框、“已选择 1 项”及过滤文本，实际来源中仍有两项未选对照对象。
4. 点击“查看恢复清单”，核对真实确认框显示新增 0、替换 1 和所选日历名称，恢复服务尚未开始执行。点击“取消”后，主库、完整聊天快照、写入计数、数据世代和空 journal 保持原值，选择及过滤仍然保留。
5. 再次查看同一选择并点击“恢复”。等待应用所有者完成实际恢复并返回设置页，重新解码主库和聊天存储、读取 journal。选中日历的完整内容与输入目标一致，主库已有新数据世代；未选课表保持本地内容，额外日历未导入，Agent 设置、两份历史和独立草稿保持原值。聊天恢复的仓储修订号单独记录，聊天内容摘要排除此修订号后核对全部内容保留。
6. 核对 journal 已清空、恢复不再占用且主库和聊天均可写。公共 runner 卸载界面并关闭运行时后，释放输入字节并恢复原 picker。driver 要求一次文件选择、两次实际确认预览、零模型请求和完整清理。

该旅程覆盖一次选择、预览取消和单日历恢复，使用真实设置路由、选择页、恢复服务与生产 codec。文件对话框和存储介质为显式合成边界；它不证明系统文件对话框、磁盘断电恢复、跨进程重启或真实模型行为。ZIP 校验、依赖重绑、故障继续和原生仓储重开由[对象选择备份与恢复](../docs/SELECTIVE_BACKUP.md)列出的专项分别验证。
