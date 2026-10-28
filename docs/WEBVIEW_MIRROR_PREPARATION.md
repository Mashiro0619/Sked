# WebView 镜像准备与切换验收

截至 2026-10-28，三个 WebView 平台 override 仍使用 [pubspec.yaml](../pubspec.yaml) 中的原来源和不可变提交。已从本机完整 Git 缓存准备并验证可独立恢复的镜像资料；尚未选定或创建目标远端，也未切换依赖 URL。远端归属、创建与推送需要项目所有者明确授权后执行。

## 固定来源

此次清单对应项目源码 `65b1307f2ff270c02f468c3d8ef53ba41dc7085c`。下列提交与 `pubspec.lock` 的 `resolved-ref` 相同，平台包版本均为 `1.2.0-beta.3`。这是本地锁文件和 Git 对象核对，不代表此次重新验证了远端可用性。

| 平台包路径 | 声明来源 | 不可变提交 | 平台包 tree 对象 |
|---|---|---|---|
| `flutter_inappwebview_android` | `pichillilorenzo/flutter_inappwebview` | `e879b0350f3a09e6e0eb0667569bcaa74cc59acb` | `92017a363e700d3f59dd60500540da64e1e0029a` |
| `flutter_inappwebview_ios` | `wangqiang1588/flutter_inappwebview` | `fc33a449b9290b127a471808e22eb7b0edebad92` | `0f78056978bbf4e008cba01989a2dc35d01ae85a` |
| `flutter_inappwebview_macos` | `wangqiang1588/flutter_inappwebview` | `fc33a449b9290b127a471808e22eb7b0edebad92` | `1ffff8d908ec051cd3909fdaa9a479ec6cb5cb5f` |

Android 根 tree 为 `1cd8326aa26fafa9ec4c7bd83ad1f16a136b76fd`，Apple 根 tree 为 `86b48eaedae96ca785fe0bfeeb4f82ea445f54cd`。原兼容性原因分别为 Android edge-to-edge API 和 Apple Xcode 可用性边界；镜像仅改变来源托管，继续使用这些原提交与包路径，不顺带升级或重写补丁。

## 本地恢复资料

两个非浅克隆来源分别含所固定提交可达的 1,809 条历史提交。此次准备保留以下本地引用，并合并为一个 Git bundle：

- `refs/heads/codex/sked-android-pin` → Android 固定提交。
- `refs/heads/codex/sked-apple-pin` → Apple 固定提交。

bundle 共 90,806,251 字节，SHA-256 为 `E3BCA95C34C9862F6AD8A6E25F058389AA35F2BB4820D6D327163F761BFE806A`。这些名字用于让对象保持可达，应用配置仍引用完整提交 SHA。

在全新的空 bare 仓库中执行 `git bundle verify`，结果为完整历史且无先决对象；从 bundle 恢复两个引用后，`git fsck --full --strict` 通过。恢复后的两个根 tree 和三个平台包 tree 与原缓存逐一相同。准备仓库、独立恢复仓库、bundle、原始日志及许可证归档保存在本次系统临时验收资料中，不随应用仓库提交；这些临时文件的保留时限不等同于远端镜像可用性。

两个固定提交的根 `LICENSE` 及三个所用平台包的 `LICENSE` 均为原有 Apache License 2.0 文本，对应相同 blob `6ccd8da42c29a4c8852de67b619e987feccb77af`。本地 bundle 保留完整原始树、历史、许可证与版权信息，另提供原文件的 tar 归档便于检查。此项只记录原始文件和内容一致性，不更改许可或作者归属。

## 目标远端确定后的最小变更

一个自有仓库可以保留上述两个固定提交；也可分别托管，具体以所有者选定的地址为准。授权完成远端准备后：

1. 先核对目标仓库中的两个保留引用确实指向上述 SHA，再从独立目录或干净缓存取回对象，比较根与平台包 tree。已有缓存中的对象不能代替目标地址可用性的证明。
2. 只修改 `dependency_overrides` 的三个 Git URL，保持 `ref`、`path` 和包版本不变。重新解析后审查 `pubspec.lock`：允许对应 URL 变化，`resolved-ref`、版本和其他依赖必须保持预期。
3. 对应用和内部 Android 插件分别运行 `flutter pub get --enforce-lockfile`，随后执行分析、格式、平台安全配置与学校网页会话相关回归。Android 与 Apple 的构建和网页导入验收仍分别执行；本地 bundle 校验不替代网络取回、原生编译或设备网页行为。
4. 以单独的 `chore(依赖)` 提交记录 URL 切换及实际结果。切换前任一步失败时保留现有来源；切换后的回退范围是这次 URL 与锁文件改动，不删除原有远端资料。

以下仅为待填入所有者已确认地址后的配置形态，不是已经应用的配置：

```yaml
flutter_inappwebview_android:
  git:
    url: <已确认的镜像 Git URL>
    ref: e879b0350f3a09e6e0eb0667569bcaa74cc59acb
    path: flutter_inappwebview_android
flutter_inappwebview_ios:
  git:
    url: <已确认的镜像 Git URL>
    ref: fc33a449b9290b127a471808e22eb7b0edebad92
    path: flutter_inappwebview_ios
flutter_inappwebview_macos:
  git:
    url: <已确认的镜像 Git URL>
    ref: fc33a449b9290b127a471808e22eb7b0edebad92
    path: flutter_inappwebview_macos
```

镜像创建、依赖切换和后续原生验收是尚待执行的步骤。持续升级与移除 override 的约束仍见 [依赖维护](DEPENDENCY_UPGRADES.md)。
