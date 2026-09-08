# 依赖与构建工具升级记录

日期：2026-09-08。基线提交：`56405627de2462fb3b9a90dfe029ecd4f692af02`。

## 执行原则

- 使用 Flutter 3.47.0 / Dart 3.13.0，不顺带升级 SDK。
- 先读取上游 changelog，再按批次提高最低版本并执行 `flutter pub get`；没有执行全仓库无选择的 `pub upgrade`。
- 应用与内部 Android 插件的 lock 文件都继续跟踪；CI 使用 `--enforce-lockfile`。内部插件是本仓库私有包（`publish_to: none`），不采用忽略 lock 的策略。
- 不修改现有 WebView 不可变 Git pin；不混入安全存储大版本迁移。

## 已执行的批次

| 批次 | 包 | 原版本 → 当前锁定版本 | 理由与验证 |
| --- | --- | --- | --- |
| A | html | 0.15.6 → 0.15.7 | 修复外来命名空间文本转义、CDATA 结束处理、异常深层格式标签解析复杂度及 htmlToCodeMarkup 转义问题；相关导入 / 清理 / 存储测试 41 项通过 |
| B | cupertino_ui | 1.0.0 → 1.0.2 | 文档与 Cupertino 路由、TabBar 维护修复；与 Material 批次一起通过 648 项 widget 测试 |
| B | material_ui | 1.0.0 → 1.1.1 | 修复 Slider 标签、异步搜索结果、RangeSlider overlay；核对 shader 资源变化后进行 widget 回归，未重设计应用界面 |
| C | xml | 6.6.1 → 7.0.1 | 单独迁移发布检查器的命名空间 API；平台安全 / artifact / workflow 共 37 项测试通过 |
| C（连带） | image | 4.8.0 → 4.9.2 | 4.9.2 移除了对 xml 的依赖，解开旧 image 对 XML 6 的限制；是 XML 批次实际解析出的连带升级，未隐藏或当成“只变了 xml” |
| 测试依赖 | yaml | 3.1.3（版本未变） | 从传递依赖改为直接 dev dependency，用真实 YAML 解析 workflow 契约，不依赖脆弱的纯字符串计数 |
| 内部插件 | flutter_lints / lints | 新增 6.0.0 / 6.1.0 | 插件继承仓库 analysis_options，但独立 package config 原本无法解析 Flutter lint include；补齐声明与插件 lock 后，独立锁定解析和分析通过 |

### XML 7 兼容性处理

项目只有以下两个文件直接导入 XML：

- `tool/src/platform_artifact_check.dart`
- `test/platform/platform_security_config_test.dart`

迁移将 `namespace:` 改为 `namespaceUri:`，并让发布检查器捕获完整的 `XmlException` 层级，把 XML 结构错误转为可读的校验失败，而不是抛出未处理异常。

验证覆盖：合法 manifest、变更命名空间前缀但保持 URI、未声明的 Android 前缀不能满足安全属性、错误嵌套标签、权限与 exported 漂移、网络安全资源、Apple plist 与实际文件 CLI。没有更改 AppData 格式，也没有执行用户数据迁移。

注意：XML 7 的 DOM 解析默认行为不等同于“自动拒绝所有未声明前缀”。安全判断仍以正确的命名空间 URI 和既有 manifest 策略为准，不能仅凭升级日志推断安全属性已经被验证。

### 上游依据

- [html changelog](https://pub.dev/packages/html/changelog)
- [cupertino_ui changelog](https://pub.dev/packages/cupertino_ui/changelog)
- [material_ui changelog](https://pub.dev/packages/material_ui/changelog)
- [xml changelog](https://pub.dev/packages/xml/changelog)
- [image changelog](https://pub.dev/packages/image/changelog)

## 明确未执行：flutter_secure_storage 11

仍锁定 **10.3.1**，不是遗漏升级。

[11.0.0 的 breaking changes](https://pub.dev/packages/flutter_secure_storage/changelog) 明确移除了 v10 中弃用的加密算法 / EncryptedSharedPreferences 路径；尚未经过 v10 迁移的数据可能无法读取，同时 Android compileSdk 提高到 37。当前项目 Android 平台基线仍是 36，不能把这当成普通补丁升级。

下一次独立升级至少要有：

1. 真实旧安装和相同签名下的旧密钥读取证据，包括用户可能跨版本直接升级的路径。
2. 新密钥写入、写后读取、清除、读写失败、升级中断与恢复测试。
3. Android API 37 工具链和平台 artifact 检查的同步评估。
4. Windows / Linux keyring、Apple Keychain 的对应平台验证；不以模拟 SecretStore 代替真实平台迁移。
5. 卸载重装与备份恢复的预期说明，确保普通备份仍不携带 API Key。

## 尚未宣称完成的验证

- 真实设备 / 原生权限 / 厂商后台限制仍按 [Android 通知验收矩阵](ANDROID_NOTIFICATION_ACCEPTANCE.md) 执行。
- widget 测试不等于逐像素视觉验收；本轮没有提供真机截图或像素比较结果。
- 发布签名、商店分发、远端 CI 的本轮状态与本地编译是不同证据，详见 [可靠性基线](RELIABILITY_BASELINE.md)。
- 大型通知 / 设置文件的职责拆分留给独立、纯结构迁移批次；本轮只新增独立的错误脱敏模块，不在安全修复与依赖升级中同时重写通知状态机。
