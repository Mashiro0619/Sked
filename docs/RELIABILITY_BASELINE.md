# Sked 可靠性与发布基线

日期：**2026-09-08**。这是一次已执行的检查记录，不是对尚未运行项目的承诺。首次实施的结果保留在下文；**最新的审查修复与验证结果以第 8 节为准**。

## 1. 基线与改动范围

- 基线提交：`56405627de2462fb3b9a90dfe029ecd4f692af02`；应用版本 `2.2.0+12`。
- 恢复任务时，工作区只有 `.github/workflows/flutter.yml` 存在修改。原会话提到的另外两个文件当时已没有未提交差异；没有按旧快照覆盖它们。
- 本轮源码状态为 **上述 HEAD + 未提交补丁**，没有创建提交、改写历史、推送、打标签或发布产物。
- 没有改变 AppData schema、课表业务规则、通知调度规则或用户配置的 Endpoint；API 错误展示新增脱敏，依赖维护变化见 [升级记录](DEPENDENCY_UPGRADES.md)。
- 内部插件 lock 的本轮差异仅增加 `flutter_lints 6.0.0` / `lints 6.1.0`，用于独立解析继承的 lint 配置；原来的锁定项保持不变。

### 本地工具链

| 项目 | 实际环境 |
| --- | --- |
| OS / shell | Windows 11 / PowerShell；32 个逻辑处理器 |
| Flutter / Dart | 3.47.0 / 3.13.0 |
| Android SDK | platform 36 / build-tools 36.1.0 |
| 本地 Android JDK | Android Studio 内置 OpenJDK 21.0.9 |
| Windows 工具链 | Visual Studio Community 2026 18.2.1 / Windows SDK 10.0.26100.0 |
| Chrome | 152.0.7977.76 |
| Android 真机 | `adb devices -l` 无连接设备 |
| Linux | 有 WSL Ubuntu，但没有找到可用的独立 Linux Flutter SDK；PATH 指向 Windows SDK，未复用其缓存或修改它 |

CI 继续固定 Flutter 3.47.0；新增 Android job 显式使用 Java 17。**本地 JDK 21 的成功不能冒充 CI Java 17 的远端执行证据。**

## 2. 已实施修复

### CI / 发布准备

- 修复上海时区任务的“假覆盖”：测试真正支持 `asia-shanghai`，作为无 DST 的对照；未知环境值直接失败，不再静默跳过。
- Android APK / AAB Release 独立到一个 job，使用仅供 CI 的随机临时签名；保留正式 Release 必须签名的检查，不降级为 Debug 签名，也不把发布密钥暴露给 PR。
- 增加 Android JVM 单测与报告、内部插件 lock 校验，以及 6 项 YAML workflow 契约测试。
- 原有 coverage gate、生成本地化检查、Chrome lease 测试、平台 artifact 检查、Windows / Linux / Apple 构建保留；Web 改为 Release。

### 通知 / 保存生命周期

- 新增进程内服务重建后的丢失排程恢复、通知权限 / 精确闹钟权限 / 电池条件撤回与恢复、失败重试后诊断更新、同一网关重读时区的回归。
- 新增 `dispose` 与 debounce / in-flight flush 的顺序、最新快照、失败可观测性测试，使用明确的开始 / 完成信号，不使用固定等待时间推断业务完成。
- 实际退出入口仍在 `lib/main.dart` 等待 `provider.quiesceForShutdown()`；普通生命周期暂停会请求 flush。同步 `dispose()` 只能启动最佳努力保存，不能承诺操作系统强杀前尚未开始的写入一定落盘。

### 存储 / 敏感数据

- 新增 **70 项**主文件、backup、temporary 组合 / 未来版本 / 模拟权限失败用例，并验证重建存储实例后状态保持。
- 新增 **6 项**密钥清理事务的 rollback / staged output / 已提交主文件 / 不安全目标恢复用例。
- 复现并修复 API 错误回显凭据：4 项 API 回归先失败再通过，另有 13 项脱敏边界测试。覆盖 API Key、认证头、URL user-info / query / fragment、编码值及被截断的长密钥。
- 脱敏只作用于错误输出；正常请求认证头、成功的导入内容、正常流式片段及取消传播保持原行为。

## 3. 实际验证结果

| 检查 | 结果 / 证据 |
| --- | --- |
| 初始全量 Flutter 测试 | 1961 通过，1 个时区占位跳过 |
| 最终全量 VM 测试 | **2072 通过，1 个时区占位跳过**；`flutter test --no-pub --coverage --concurrency=4` |
| Coverage gate | **PASS**；总覆盖 30937/34558 = **89.5220%**；改动行 52/53 = **98.1132%** |
| 改动覆盖范围 | HEAD → working tree，含新增 Dart 文件；绝对门槛 81.76%，改动行门槛 90%；没有在本机重测 HEAD 的同平台 LCOV 基线 |
| 主项目 / 内部插件 analyze | **通过，无问题** |
| Dart format | **通过，345 个文件、0 个变化** |
| generated l10n | 重新生成后 `lib/l10n` 无 Git 差异 |
| 根项目 / 插件 lockfile | `--enforce-lockfile` 通过 |
| git diff --check | **通过** |
| HTML / 清理 / 存储批次 | 41 项通过 |
| UI 依赖批次 | 648 项 widget 测试通过；没有进行逐像素视觉验收 |
| XML / 平台 / workflow 批次 | 37 项通过 |
| API / 脱敏专项 | 78 项通过 |
| Android JVM 单测 | **3 项通过，0 failure/error/skip**；使用 `--rerun` 实际重跑，非仅复用缓存结果 |
| 上海无 DST 对照 | Windows 进程级 `TZ=CST-8` / `SKED_DST_TEST_ZONE=asia-shanghai`，12 项通过 |
| 无效时区负向检查 | 未知值返回非零，符合预期，不伪装成跳过 |
| launcher-icons 工具编译 | `dart run flutter_launcher_icons --help` 通过；未重新生成图标 |

### 需要保留的失败 / 限制信息

- 本机默认高并发的一次最终复验中，3 个现有 CLI 测试触发了 30 / 45 秒超时。对应的 3 个文件串行复验 **4 项通过**，再以 4 并发完成全量 2072 项。没有降低断言、延长用例超时或跳过这些测试。
- 普通全量套件的 1 个 skip 是按设计留给专门时区任务的占位，不是三种时区都已验证。
- Windows 使用 `EST5EDT` 的纽约尝试未满足真实 DST 偏移前提（期望 -04:00，实际 -05:00）；**纽约 / 柏林仍待 Linux runner 验证**。没有改变宿主系统时区或弱化偏移断言。
- 附加 Chrome 回归停在加载阶段：测试宿主的 `/canvaskit/chromium/canvaskit.js` 和 `.wasm` 返回 404，但对应 SDK 文件存在。定位到 Flutter 3.47 本机 SDK 测试服务将 URI 转为 Windows 路径后仍匹配 `canvaskit/` 前缀。已停止该测试及自建调试会话，**没有得到浏览器测试通过结果，也没有修改全局 SDK**。CI 中已有的 Linux Chrome 检查仍需远端结果。
- 预期注入的存储 / 排程异常仍可能输出栈；不能把日志中出现 exception 等同于测试失败。最终以退出码和用例结果判定。本次全量日志未出现已知测试密钥回显，不据此宣称对任意日志做了完备证明。

## 4. Release 构建与平台矩阵

| 平台 / 产物 | CI 配置 | 本轮实际结果 |
| --- | --- | --- |
| Android APK Release | 独立 Ubuntu job、Java 17、临时 CI 签名 | **本地构建通过** |
| Android AAB Release | 同上 | **本地构建通过** |
| Android merged manifest / 安全资源 | 目标 SDK 36、应用 ID、权限、exported、backup / network 规则 | **本地实际产物检查通过** |
| Web（默认 JS Release） | Ubuntu test job | **本地构建通过**；Wasm dry run 成功不代表已验收 Wasm 运行 |
| Windows Release | 对应 Windows runner | **本地构建通过**；未制作或安装 MSIX |
| Linux Release | Ubuntu host + Debian 13 / WPE 依赖 | 仅确认配置，未在本机运行 |
| macOS Release / unsigned iOS | 对应 Apple runner | 仅确认配置，未在 Windows 上声称通过 |
| 本轮远端 CI | 配置已更新 | **未运行未提交补丁，不是远端绿色证明** |

### 重要的 Flutter / Gradle 边界

1. 当前配置只暴露 `testDebugUnitTest`，没有 `testReleaseUnitTest`。原生 JVM 测试使用实际存在的 Debug 变体，APK / AAB 的 Release 编译、混淆与打包单独检查。
2. Flutter 3.47 的 `--no-pub` 也会跳过相应平台的注册器准备。曾在 Debug 单测后使用它构建 Release，导致注册器残留 `integration_test`，但 Release classpath 已排除该开发插件。**改用正常的 `flutter build apk --release` / `flutter build appbundle --release` 后两者通过**。没有手改生成的 Java 文件，没有把测试插件挪到运行时依赖。
3. 本地使用项目已有签名配置；CI 一次性签名仅供 smoke 构建，不用于正式升级或发布。
4. 仍有上游警告：`flutter_timezone` 的旧 KGP 用法，以及 Windows WebView 的 CMake CMP0175 警告。目前构建成功，升级 Flutter / Gradle / CMake 前需要单独处理，未简单静音。

### 本次本地产物指纹

以下是组件指纹，不是完整分发包验收。Windows 应连同 AOT 载荷、Flutter DLL 和资源目录一起分发；不能只复制 exe。

| 产物 | 路径 | 字节 | SHA-256 |
| --- | --- | ---: | --- |
| Android APK | `build/app/outputs/flutter-apk/app-release.apk` | 77091523 | `86e45c8651808388e9efc87b1d34533eaa937dcd7912be4c5748b574da01c27d` |
| Android AAB | `build/app/outputs/bundle/release/app-release.aab` | 73689965 | `5c4d0a2c2333d44c3f3f6f509a15f1f6a8d55ce8be5ca9d7ffe3c54559f1eb7a` |
| Windows executable | `build/windows/x64/runner/Release/sked.exe` | 58880 | `5169ccd1642578f1fe8d39c1fb625930f19c287b8696a3e46a85899e946e2006` |
| Web main bundle | `build/web/main.dart.js` | 7673518 | `707c8d68a49d013df6f4713a34f815899f2a4c43f785c2ab2460f10b5fdd6265` |
| Windows AOT payload | `build/windows/x64/runner/Release/data/app.so` | 14779272 | `62638a0d620828845c2984571fc5a199fee95fe693cb5b231f19d9881c027fc7` |

## 5. 持久化与 HTTP 策略说明

- 普通快照恢复优先级是 **已刷新的 temporary → main → backup**，而不是按文件 mtime 猜测新旧。空文件按损坏处理；无可用候选且已有隔离文件时，重开仍保持恢复门禁，不误认首次启动。
- 未来 schema / I/O 不确定状态优先关闭写入；只保留阻断候选之前已安全读取的数据，不擅自用旧备份覆盖可能更高版本的数据。
- **rollback 不是第四个普通快照候选。** `.secret-scrub.rollback` / `.secret-scrub.tmp` 属于旧 API Key 清理事务，先完成其恢复，再进入普通快照选择。已提交主文件优先；未提交且临时目标安全时提升；只有 rollback 时恢复原件；不安全临时目标保留原件并阻止写入。
- 新生成的普通 AppData / 备份不包含 API Key 字段值；旧版原件可能仍需先迁移到安全存储，不能为“清理秘密”删除唯一可恢复的数据。真实系统断电和原生 keyring 迁移不等价于这些文件夹具测试。
- Android manifest 继续禁止普通系统备份并保持通知 receiver 非导出；`network_security_config.xml` 的明文允许是可配置 HTTP Endpoint 的产品约束，不是没有风险。
- 现有应用对 **所有 HTTP Endpoint（含 loopback / 私网 / 公网）** 在发送前提示密钥和课表可能被读取 / 篡改，并按端点在当前进程内记住同意；退出后失效。HTTPS 不触发 HTTP 确认。保留这一比“私网仅提示”更严格的既有策略，不按主机名字符串推断安全而弱化保护。
- 重定向防护、HTTP 确认与实际请求使用同一设置快照的既有回归均保留。

## 6. 可复现命令

在仓库根目录运行。Windows 高核数机器推荐限制测试并发，避免 CLI 子进程测试被资源竞争拖到超时。

```powershell
flutter pub get --enforce-lockfile
Push-Location packages/android_productivity_plugin
flutter pub get --enforce-lockfile
flutter analyze --no-pub
Pop-Location
flutter gen-l10n
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test --no-pub --coverage --concurrency=4
dart run tool/coverage_gate.dart --base-ref HEAD --minimum-total 81.76 --minimum-diff 90
git diff --check

# 使用本机 Flutter doctor 确认的 JDK；不要为此修改全局 SDK。
$env:JAVA_HOME='D:\Soft\Android Studio\jbr'
# 首次 Flutter Android 构建会生成被 Git 忽略的 gradlew 和 wrapper JAR。
flutter build apk --release
Push-Location android
.\gradlew.bat :app:testDebugUnitTest --rerun --offline --no-daemon
Pop-Location
# 原生 Debug 测试之后仍需 Flutter 准备 Release 注册器，不加 --no-pub。
flutter build appbundle --release
dart run tool/platform_artifact_check.dart android-manifest --manifest build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml --resource-root build/app/intermediates/merged-not-compiled-resources/release --application-id com.mashiro.sked --target-sdk 36
flutter build web --release
flutter build windows --release
```

`--offline` 仅适用于本机已有完整 Gradle 缓存时；CI 使用正常在线解析。跨 Debug / Release 构建不要为省略 pub get 而跳过平台注册器准备，也不要让多个平台构建同时改写同一工作区的生成文件。

Linux runner 上的时区命令（本轮未在 Linux 执行）：

```bash
TZ=America/New_York SKED_DST_TEST_ZONE=america-new-york flutter test test/date_dst_regression_test.dart
TZ=Europe/Berlin SKED_DST_TEST_ZONE=europe-berlin flutter test test/date_dst_regression_test.dart
TZ=Asia/Shanghai SKED_DST_TEST_ZONE=asia-shanghai flutter test test/date_dst_regression_test.dart
```

本地日志位于被忽略的 `.scratch/reliability-20260908/`：最终全量为 `final-tests-coverage-concurrency4.log`，另保留默认并发超时记录、CLI 串行复验、Chrome 启动诊断、时区结果、构建日志与产物 JSON。LCOV 和门禁报告位于 `coverage/`。

## 7. 尚未完成 / 下一批优先级

1. 按 [Android 真机验收矩阵](ANDROID_NOTIFICATION_ACCEPTANCE.md) 填写实际记录。当前 Pixel / Samsung / 国产 ROM 全部未执行；强行停止与普通进程回收不得混淆。
2. 在 Linux CI 取得纽约 / 柏林 DST 与 Chrome lease 的结果，在对应 runner 取得 Apple / Linux 构建结果；本轮补丁提交后才能取得远端证据。
3. `flutter_secure_storage 11` 保持独立迁移，当前仍为 10.3.1；先验证真实旧密钥、相同签名升级及 API 37 工具链，见 [依赖记录](DEPENDENCY_UPGRADES.md)。
4. 大文件重构尚未实施；当前规模记录如下。应另开纯结构迁移批次，不同时改变提醒规则或数据格式，也不把这次新增测试当成已完成职责拆分。

| 模块 | 当前行数 | 状态 |
| --- | ---: | --- |
| `lib/services/agenda_notification_service.dart` | 4315 | 尚未做结构拆分 |
| `lib/services/agenda_notification_runtime_store.dart` | 2269 | 尚未做结构拆分 |
| `lib/screens/settings_page.dart` | 2499 | 尚未做结构拆分 |

## 8. 代码审查后的修复与追加验证

### 修复内容

- **Android CI 冷启动顺序**：仓库不跟踪 `android/gradlew` 和 wrapper JAR，`flutter pub get` 不会生成它们。调整为 APK Release → Debug JVM 单测 → AAB Release → merged artifact 检查；首次 Flutter Android 构建负责准备 wrapper。新增顺序契约测试，所有直接 Gradle 调用都必须位于首次 Android 构建之后。
- **JSON 斜杠转义**：错误中的 `https:\/\/…` 现在同样剥离 URL user-info、query 与 fragment；已截断、不完整的 JSON 也受保护，不依赖整段正文能成功 `jsonDecode`。已知 API Key 的 JSON 转义变体同时覆盖可选的斜杠转义。
- **带引号的认证头**：正确处理转义引号和反斜杠，不再提前结束并留下密钥后缀；值在错误截断边界结束或留下单个转义符时，也完整隐藏该值并保留截断提示。正常请求头、成功结果和流式正文不做改写。
- 新增 **9 个**回归用例，并扩展既有编码用例。先确认对应泄露和 CI 顺序断言失败，再修复通过；覆盖公开 API、未知认证凭据及长密钥的截断回显。

### 追加验证

| 检查 | 结果 |
| --- | --- |
| API / 脱敏 / workflow 定向测试 | **93 项通过** |
| 最终全量 VM 测试 | **2081 项通过，1 个按设计跳过的时区占位**；`flutter test --no-pub --coverage --concurrency=4` |
| 最新 Coverage gate | **PASS**；总覆盖 30939/34560 = **89.5226%**，改动行 54/55 = **98.1818%**；HEAD → working tree |
| 主项目 / 内部插件 analyze | **通过，无问题** |
| 全仓库 Dart format | **345 个文件，0 个变化** |
| 独立目录 Android 顺序验证 | APK Release、Debug JVM 单测、AAB Release、merged security artifact 检查全部通过 |
| Android JVM 实际重跑 | **3 项通过，0 failure/error/skip**；使用 `--rerun` |
| 临时签名 | 独立生成，仅用于验证；key.properties 和 keystore 已清理，未触碰工作区正式签名 |

冷启动验证从单独导出的源码目录开始：根项目与插件锁定解析成功后，确认 wrapper 仍不存在；首次 APK 构建后确认 `gradlew`、`gradlew.bat` 与 wrapper JAR 均已生成。复用了本机已安装 SDK / 依赖缓存，并非空缓存下载测试。仍是 **Windows / JDK 21** 的本地执行，**不代替 Ubuntu / Java 17 的远端 CI 或真机验收**。

本轮日志位于 `.scratch/review-fixes-20260908/`，包括 RED / GREEN 回归记录、全量测试、静态检查和冷构建日志。`clean-android-verification.json` 保留顺序验证与签名清理结果，JUnit XML 已保存到 `native-test-reports/`。验证后仅移除了本次生成的独立构建副本，避免其深层 Windows 构建路径干扰日常工具扫描；清理操作没有删除主工作区源码或依赖缓存。
