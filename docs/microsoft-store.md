# Microsoft Store 发布

本项目使用 MSIX 提交路线，不使用 EXE/MSI 安装器路线。商店提交包由 Microsoft Store 在认证通过后重新签名；本地构建不需要 PFX、证书密码，也不会安装证书、上传或送审。

## 产品身份

身份来源：Partner Center → 产品管理 → 产品标识。唯一配置文件是 `tool/microsoft_store.json`；不要把复制文本里的 `&#x20;` 或尾部空格写入。

| 字段 | 值 |
| --- | --- |
| Package/Identity/Name | `Mashiro0619.Sked` |
| Package/Identity/Publisher | `CN=6F54C1EE-2D68-4470-95B1-DC94E15256D4` |
| Package/Properties/PublisherDisplayName | `Mashiro0619` |
| Package Family Name | `Mashiro0619.Sked_8xjzenwxj0w1p` |
| Store ID | `9NWRR6ZP6K6T` |

Package SID 由 Windows 根据包身份派生，不作为打包参数。以上值是公开产品元数据，不是凭证。

站外 MSIX 继续使用原有的 `Mashiro.Sked` 身份；商店包在构建时覆盖身份，而不修改 `pubspec.yaml` 中的站外配置。应用 ID 保持 `sked`，通知激活 CLSID 保持 `5d9d8f6a-4d1a-4f3a-9b0a-6a3e7d2c1f58`。打包应用的通知使用操作系统提供的包身份；不要把未打包程序的备用 AUMID 错改成商店包名称。

## 本地构建

在 x64 Windows 上安装 Flutter、Visual Studio 的 C++ 桌面开发工具及 Windows SDK 后，在仓库根目录执行（当前脚本不构建 ARM64 包）：

```powershell
Set-Location 'D:\Project\Flutter\sked'
flutter pub get --enforce-lockfile
pwsh -NoProfile -File tool/build_msix.ps1 -Store
```

脚本会：

1. 校验产品身份和版本数字范围。
2. 重新编译 Windows x64 Release，并注入 `SKED_MICROSOFT_STORE_ID=9NWRR6ZP6K6T`。
3. 使用 `msix:create --store` 打包，不读取站外签名环境变量。
4. 从生成的 MSIX 中读取 `AppxManifest.xml`，核对名称、Publisher、显示发布者、版本、架构、应用 ID 和通知激活器，拒绝带本地签名的提交包。
5. 在 `build/microsoft-store/` 输出独立命名的商店提交文件。

当前输出为 `build/microsoft-store/sked-v2.3.0-alpha.1-store-x64.msix`。这是供 Partner Center 使用的未签名提交包，不是可以直接双击侧载的受信任安装包。

**不要把上次的构建目录直接拿来切换渠道。** 脚本的 Store、Unsigned 和签名模式均会重新编译正确渠道。普通便携 ZIP 仍需先运行不带商店标记的 `flutter build windows --release`，再打包完整 Release 目录。

## 版本映射

应用展示与更新比较仍使用 `pubspec.yaml` 的完整 SemVer。商店四段版本采用 **major.minor.build.0**，第四段固定为商店要求的零：

| 应用版本 | Store 包版本 |
| --- | --- |
| `2.3.0-alpha.1+14` | `2.3.14.0` |
| `2.3.0-alpha.2+15` | `2.3.15.0` |
| `2.3.0+16` | `2.3.16.0` |

构建号必须明确填写、为正整数并持续递增，不要在 Alpha、RC 或正式版之间重置；各数字段须在 0–65535 内，主版本不能为零。补丁版本变化同样需要递增构建号，因为 Store 包版本第三段不使用 SemVer patch。上传前还须核对后台既有版本，不能把本地规则当成后台已接受的证明。

站外包继续使用 **major.minor.patch.build**，例如 `2.3.0.14`。站外与商店版本规则不同，不能混用。

## 更新行为

- 商店构建的“检测更新”由用户主动打开此产品的 Microsoft Store 页面；协议不可用时回退到同一产品的官方网页。
- 不请求 GitHub 或自定义更新源，不显示 GitHub 的旧更新徽标，也不显示“接收预发布更新”开关。
- 启动检查不会自动打开商店或联网；应用不自行声明商店有可用更新。
- 从备份恢复的 GitHub 更新偏好保留但不用于商店更新，避免破坏跨平台备份。
- 商店页面须产品上线后才对用户可用；当前链接配置不代表页面已经发布。
- `-alpha.1` 不会自动建立商店测试渠道。首次发布的可见性由 Partner Center 单独设置；完成首次发布后，才能按后台条件使用 Package flights 向已知测试用户分发。

## CI

Windows CI 先验证站外未签名 MSIX，再单独构建 Store 包并自动校验清单。工作流只上传 `microsoft-store-msix` 构建产物，不调用提交 API，不持有商店密码、PFX 或发布权限。

## 提交前检查

- 对最终包运行 Windows App Certification Kit；自动清单检查不能代替 WACK 或商店认证。
- 在隔离测试环境验证启动、导入导出、保存、通知送达／操作／激活和升级后的数据保留，不直接使用生产用户数据测试。需要本地安装时另行准备测试签名副本，不将测试证书附到商店提交包。
- 站外包与商店包身份不同，不保证覆盖安装或数据自动迁移。切换前导出完整备份，首次安装后检查数据并按需恢复；避免同时启用两份程序的提醒。
- 填写商店名称、说明、类别、年龄分级、市场范围、截图、支持联系方式、隐私政策和测试说明。
- 确认 `runFullTrust` 等能力申明与实际功能一致；如后台要求，说明 Flutter Win32 桌面程序、本地文件操作和系统提醒的用途。
- 上传 `.msix` 到对应产品的 Packages 页面，检查后台解析出的版本和产品身份，完成认证并确认发布范围后再提交。

参考：[微软 MSIX 包要求](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements)、[Flutter Windows 发布指南](https://docs.flutter.dev/deployment/windows)、[Package flights](https://learn.microsoft.com/en-us/windows/apps/publish/package-flights)。
