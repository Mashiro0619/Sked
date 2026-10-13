# 可靠性验证指南

本文维护存储、安全、生命周期与持续集成的验证约束，不记录某次检查的通过状态。每次发布的实际证据和未完成事项集中在 [发布验收](RELEASE_ACCEPTANCE.md)；依赖迁移见 [依赖维护](DEPENDENCY_UPGRADES.md)。历史运行日志、测试计数和产物指纹从 Git 历史或对应构建记录追溯，不能复用为当前版本结论。

## 需要保持的行为

| 范围 | 约束与验证入口 |
| --- | --- |
| 快照恢复 | 普通候选按已刷新的 temporary → main → backup 处理，不按 mtime 猜测新旧。未来 schema 或 I/O 不确定状态阻止写入；已有隔离文件时不能误判为首次启动。见 [恢复矩阵](../test/data/timetable_storage_recovery_matrix_test.dart) 与 [存储测试](../test/data/timetable_storage_io_test.dart)。 |
| 密钥清理事务 | `.secret-scrub.rollback` / `.secret-scrub.tmp` 属于迁移事务，先处理事务恢复，再选择普通快照；rollback 不是第四个普通候选。不删除唯一可恢复的旧原件。见 [密钥存储测试](../test/services/app_storage_secret_io_test.dart)。 |
| 保存与退出 | 显式退出入口等待 `quiesceForShutdown()`；暂停请求 flush，同步 `dispose()` 只能发起最佳努力保存。用明确开始/完成信号验证并发与最新快照，不用固定等待推测完成。见 [保存竞争测试](../test/providers/timetable_provider_save_race_test.dart)。 |
| 敏感数据 | 普通 AppData 和备份不包含 API Key 值；错误展示需脱敏认证头、URL 凭据及已知密钥的编码/截断形式，同时保持正常认证、成功响应和取消语义。见 [密钥持久化](../test/providers/timetable_provider_secret_persistence_test.dart) 与 [错误脱敏测试](../test/services/school_import_error_redactor_test.dart)。 |
| HTTP Endpoint | 所有 HTTP Endpoint，包括 loopback、私网和公网，都需要发送前确认；同意按端点保留于当前进程，HTTPS 不触发该确认。确认和请求必须使用同一设置快照，并保留重定向防护。见 [导入流程测试](../test/services/school_import_workflow_test.dart)。 |
| 原生安全 | Android 禁止普通系统备份，通知 receiver 不导出；允许可配置 HTTP Endpoint 的网络策略需与前述确认配合。Apple 权限与 Windows 通知身份也需检查。见 [平台测试](../test/platform) 和 [产物检查器](../tool/platform_artifact_check.dart)。 |

文件夹具不能证明真实断电恢复或原生 keyring 迁移；显式退出保存不能保证操作系统强杀前落盘。通知重排、权限撤回、后台回收与厂商限制应结合 [通知验收矩阵](ANDROID_NOTIFICATION_ACCEPTANCE.md) 验证。

## 日常检查

从仓库根目录运行以下 PowerShell 命令，逐项确认退出码。测试并发可按机器资源调整；遇到超时先区分资源竞争与业务失败，不通过弱化断言或跳过用例消除失败。

```powershell
flutter pub get --enforce-lockfile
Push-Location packages/android_productivity_plugin
flutter pub get --enforce-lockfile
flutter analyze --no-pub
Pop-Location
flutter gen-l10n
git diff --exit-code -- lib/l10n
# 另检查新生成的未跟踪文件；与修改前状态比较。
git status --short -- lib/l10n
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test --no-pub --coverage --concurrency=4
git diff --check
```

覆盖率用于定位尚未验证的代码路径。[CI](../.github/workflows/flutter.yml) 只对当前提交执行一次完整 VM 测试，并保留生成的 `coverage/lcov.info` 作为诊断附件，不设总覆盖率或改动行百分比门槛，也不为覆盖率检出基准提交重跑全套。测试取舍以数据完整性、故障恢复、真实交互和已发生的回归为依据；测试失败仍阻止 CI 通过。

## CI 与平台检查

下表描述仓库配置，不表示当前提交已经通过。实际结果必须关联提交与 CI run。

| 检查 | 当前配置及边界 |
| --- | --- |
| 通用 | 固定 Flutter 版本、双 lock 校验、本地化生成一致性、格式、分析、VM 测试；coverage 仅作为诊断附件。 |
| 浏览器与日期 | Linux Chrome 验证实例 lease；纽约、柏林 DST 与上海无 DST 对照单独执行。普通全量测试不能代替这些专门任务。 |
| Android | Ubuntu / Java 17，以临时 CI 密钥构建 APK 和 Google Play 渠道 AAB；Debug JVM 单测与 Release 编译/混淆分别检查，再检查 merged manifest 与资源。 |
| Web | Release 构建；构建成功不代表浏览器运行、视觉或 Wasm 已验收。 |
| Linux | Debian 容器和 WPE WebKit 系统依赖下构建 Release。 |
| Windows | 构建未签名通知 MSIX、检查 toast 身份，并构建 Microsoft Store 提交包；不等于已安装验证或商店发布。 |
| Apple | 构建 macOS 和未签名 iOS，并检查 macOS 实际 bundle 的签名、plist 与 entitlement；不等于商店分发成功。 |

Linux 上的专门检查命令：

```bash
flutter test --platform chrome test/services/app_instance_lease_web_test.dart
TZ=America/New_York SKED_DST_TEST_ZONE=america-new-york flutter test test/date_dst_regression_test.dart
TZ=Europe/Berlin SKED_DST_TEST_ZONE=europe-berlin flutter test test/date_dst_regression_test.dart
TZ=Asia/Shanghai SKED_DST_TEST_ZONE=asia-shanghai flutter test test/date_dst_regression_test.dart
```

Android 的直接 Gradle 调用应放在首次 Flutter Android 构建之后，因为 wrapper 文件由构建准备。Debug JVM 单测后构建 Release 时保持正常 `flutter build` 准备流程，避免 `--no-pub` 遗留开发插件注册器；不要手改生成文件或把测试插件移入运行时依赖。具体步骤以 CI 及 [workflow 契约测试](../test/tool/ci_workflow_test.dart) 为准。多个平台构建不要同时改写同一工作区的生成文件。

## 发布证据

每次发布需分别记录本地检查、对应 runner 的远端结果、真实设备验收、正式签名和实际分发包验证。CI 临时签名仅用于构建检查，不能验证相同签名升级；Windows 可执行文件也必须随完整运行库和资源分发，单个 exe 指纹不是完整包验收。

未执行、环境阻塞、已失败和已通过应明确区分；预期注入异常以断言和退出码判断，不能仅凭日志含有 exception 判失败。实际设备记录及遗留验收统一维护在 [发布验收](RELEASE_ACCEPTANCE.md)，本指南不保留容易过时的完成率、机器配置或包哈希。
