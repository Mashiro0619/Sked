# 依赖与构建工具维护

本文保留持续适用的升级约束；版本以 [pubspec.yaml](../pubspec.yaml)、[pubspec.lock](../pubspec.lock) 和 [CI](../.github/workflows/flutter.yml) 为准。历史升级批次、测试计数和本机构建结果从 Git 历史追溯，不作为当前版本的验收证据。

## 升级流程

1. 阅读上游 changelog，明确最低 SDK、原生工具链、数据格式和 API 的变化。按相关依赖分批升级，SDK 升级独立评估，避免无选择地升级整个依赖树。
2. 检查直接依赖与连带解析变化，一并审查声明和 lock 差异。应用及内部 Android 插件都是私有包，两个 `pubspec.lock` 都需跟踪；分别执行 `flutter pub get --enforce-lockfile` 验证可复现解析。
3. 按受影响功能执行回归，并按 [可靠性验证指南](RELIABILITY_BASELINE.md) 验证分析、格式、本地化、平台构建和产物契约。UI 依赖升级还需视觉与交互验收，widget 测试通过不能替代截图或真机检查。
4. 发布前将对应提交、平台、执行命令和实际结果记入 [发布验收](RELEASE_ACCEPTANCE.md)，区分本地、CI、真实设备和分发渠道证据。

## 需要单独评估的依赖

### WebView Git 固定版本

`dependency_overrides` 中的不可变 Git 提交用于上游尚未发布的原生兼容性修复：Android 的 edge-to-edge API，以及 Apple 插件的 Xcode 可用性边界。具体提交和原因保留在 `pubspec.yaml` 注释中。

移除 override 前，确认 pub.dev 发布版本确实包含对应修复，并分别验证 Android 与 Apple 构建和网页导入。不要将不可变提交换成浮动分支，或仅凭 Dart 分析通过就移除原生补丁。Linux 构建还依赖兼容的 WPE WebKit 系统库，版本检查以 CI 为准。

固定提交、许可证、本地完整历史 bundle 与自有镜像的切换验收见 [WebView 镜像准备](WEBVIEW_MIRROR_PREPARATION.md)。本地资料已准备不表示远端仓库已经创建，也不改变现有 override 来源。

### 安全存储大版本迁移

目前声明 `flutter_secure_storage: ^11.2.0`。项目引入安全存储时已使用 10.3.1 的默认加密算法，没有配置 v11 移除的旧算法或 `encryptedSharedPreferences`。这不能代替已安装版本的实际升级验证；[v11 的迁移说明](https://pub.dev/packages/flutter_secure_storage/changelog) 明确要求使用 v9 或更早加密路径的数据先经过 v10 迁移，不能通过打开迁移备份让 v11 直接恢复已移除的算法。

[FlutterSecureSecretStore](../lib/services/secret_store.dart) 保持原有 key、默认 namespace 和各平台的密钥位置，Android 开启 `migrateWithBackup` 保护仍受支持的算法迁移。插件原有的默认算法和 `resetOnError` 恢复行为保持不变；关闭后，部分无法初始化的存储连现有显式清除路径也无法恢复。插件抛出的异常继续交给现有密钥控制器处理，读取异常不能冒充“未保存密钥”，也不能因此清理旧 AppData 中唯一可恢复的密钥。[适配器回归测试](../test/services/secret_store_test.dart) 验证插件接收的参数、读写清除和错误传播；它们不证明 Android KeyStore 或其他平台原生存储迁移成功。

11.2.0 已从 11.0.0 的固定 compileSdk 37 改回继承 Flutter；本项目 Flutter 3.47.7 提供 compile/target SDK 36、min SDK 24，满足本次解析版本的要求。后续升级仍须核对插件实际 Gradle 配置，并至少提供：

- 相同签名的真实旧安装升级后读取旧密钥，包括跨版本直接升级路径。
- 新密钥写入、读取、清除，以及失败、升级中断和恢复验证。
- Android compileSdk 要求与 SDK、Gradle、CI、产物检查的同步评估；当前 Gradle 从 Flutter 继承 SDK，CI 产物检查要求 target SDK 36，compileSdk 和 targetSdk 不应混为一谈。
- Windows、Linux 和 Apple 原生安全存储验证；模拟 SecretStore 不能证明原生迁移成功。
- 卸载重装、系统备份恢复的预期说明；普通 AppData 备份仍不应携带 API Key。

### XML 与平台安全检查

发布检查器使用 XML 7 的 `namespaceUri:` API，并捕获 `XmlException`。升级解析器时，保留 [产物检查测试](../test/tool/platform_artifact_check_test.dart) 和 [平台安全配置测试](../test/platform/platform_security_config_test.dart) 中的命名空间与损坏 XML 回归。

安全属性必须按命名空间 URI 判断；前缀名称相同不代表命名空间正确，解析成功也不代表属性安全。检查实际 merged manifest 和安全资源，不能只检查源码或依赖更新日志。

## 验证边界

依赖升级不应同时重写通知状态机、调整课表规则或迁移 AppData 格式。需要这些变化时单独明确范围和恢复策略。原生权限、后台限制和真实设备行为参见 [Android 通知验收矩阵](ANDROID_NOTIFICATION_ACCEPTANCE.md)；发布签名和商店分发也必须独立验收。
