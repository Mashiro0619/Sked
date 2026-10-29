# 贡献指南

Sked 的行为说明见 [使用逻辑](docs/USAGE_LOGIC.md)，界面约定见 [设计规范](DESIGN.md)。修改存储、导入、提醒或平台代码前，先阅读 [可靠性验证指南](docs/RELIABILITY_BASELINE.md) 和对应测试。

## 准备环境

使用 [pubspec.yaml](pubspec.yaml) 要求的 Flutter 和 Dart；目前为 Flutter 3.47.7 或更高、Dart 3.13.5 兼容版本。[CI](.github/workflows/flutter.yml) 固定 Flutter 3.47.7，提交前优先使用同版本检查。原生开发还需安装目标平台工具链，可用 `flutter doctor -v` 检查。

在仓库根目录逐项运行，并确认每步退出码：

```powershell
flutter pub get --enforce-lockfile
Push-Location packages/android_productivity_plugin
flutter pub get --enforce-lockfile
Pop-Location
git config core.hooksPath tool/hooks
flutter devices
flutter run -d windows
```

`windows` 可替换为实际设备 ID。内部 Android 插件维护独立锁文件，不能只安装根项目依赖。WebView 的 Git override 有专门的平台兼容原因，修改前检查 [依赖维护](docs/DEPENDENCY_UPGRADES.md)，不要顺手升级锁定依赖。

使用合成数据验证导入、恢复、清空或迁移；避免让测试打开个人存档。脚本、运行日志、截图、临时密钥和一次性报告放在系统临时目录，长期有效的说明整理进仓库文档。不要提交生成缓存、机器签名配置或强行加入被忽略的内部文档。

本地交接、阶段审查报告、语言统计快照和商店填写草稿不进入版本控制。现有本地材料由 `.gitignore` 保留，新产生的临时工件仍使用系统临时目录；公开文档维护当前行为、可复现流程和必要的设计结论，不累计本机执行日志或一次性通过数。清理文档时同步引用，公开页面不能依赖被忽略的本地文件。

## 实现与原子提交

每个提交只解决一个问题，并能独立编译、通过相关检查和回退：

- 修复与证明该修复的回归测试放在同一个提交；行为变化同时更新对应文档。
- ARB 与生成的 `app_localizations*.dart` 一起提交。
- 大规模重构与行为修改分开；纯重构先验证原行为保持，再处理功能变化。
- 模型、文案表或测试组分别迁移，不把无关格式化、重命名和清理混入修复。
- 修改存储或异步流程时，验证真实完成、取消、回滚和失败路径；不以固定等待代替完成信号。

提交消息使用单行中文 `type(范围): 摘要`。类型可用 `fix`、`feat`、`refactor`、`perf`、`test`、`docs`、`chore`、`ci`，例如 `fix(导入): 取消确认后保留输入草稿`。维护提交使用 SSH 签名；使用自己的 Git 身份和签名密钥，提交后以 `git verify-commit HEAD` 验证。

提交前检查 `git diff --staged`，只暂存本条目文件。仓库钩子检查暂存的 Dart 内容，不自动改写或暂存文件。

## 验证

先运行改动涉及的测试，再运行适用门禁。以下命令以 PowerShell 为例：

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test --no-pub test/services/data_transfer_codec_test.dart
git diff --check
```

上面的测试文件只是命令示例，应替换为本次修改对应的测试。里程碑完成时运行 `flutter test --no-pub --concurrency=4`；需要覆盖率时使用 CI 的 `--coverage` 选项。日期、时区或重复规则改动还需按 CI 的五个 `TZ` 与 `SKED_DST_TEST_ZONE` 组合运行专项；在支持这些时区设置的环境中执行，不把 Windows 本机单一时区结果当作五区通过。

CI 将完整 VM 测试按 `--total-shards=4 --shard-index=0..3` 分配，每个分片以 `--concurrency=2` 运行并保存自己的覆盖率。`tool/merge_lcov.dart` 要求四份报告齐全后才合并默认行覆盖率，重新计算命中总数；若未来启用函数或分支覆盖率，需先扩展合并器，不能丢弃未知记录。原 `test` 门禁等待质量检查、所有分片和覆盖率合并成功，失败、取消或缺片均不能通过；浏览器、五个时区及平台构建仍分别运行。

按名称单跑或分片运行时，每个用例也必须具备完整前置条件。测试自行初始化所需的进程内服务和注册项，不依赖其他用例的执行顺序或遗留状态。

独立设置页组件测试通过 `test/support/notification_test_scope.dart` 的 `MaterialApp.builder` 注入内存通知网关和运行时存储，或显式传入测试自己的通知服务。同文件的 `setUpNotificationTestPlatform` 只为当前测试注册自动启动能力读取的替身，并在每项结束时移除；未知平台调用仍会报错。不要屏蔽 `debugPrint`、吞掉平台错误或全局替换通知插件来消除日志；通知网关专项仍需覆盖真实失败反馈。

构建命令与平台验收入口见 [可靠性验证指南](docs/RELIABILITY_BASELINE.md)。常用本地命令为 `flutter build windows --release` 和 `flutter build apk --debug`；正式 Android 签名、MSIX 身份与商店配置遵守对应发布文档，不使用或提交他人的签名材料。

性能修改先按 [基准说明](benchmark/README.md) 保存改动前后结果，固定源码、数据和协议；测量期间不并发运行分析、测试或构建。报告每轮值和退化，不能只保留有利样本。

CI 重跑失败分片时，保留同一次工作流运行中已成功分片的覆盖率，只替换重跑分片的工件。最终检查仍要求所有分片及覆盖率合并成功；缺片、取消或失败不会通过。GitHub 的[重跑说明](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs)明确重跑使用原提交和引用。

## 本地化

编辑 `lib/l10n/app_*.arb`，以 `app_en.arb` 为模板；占位符名称、类型及消息含义保持一致。新文案至少提供英文、简体中文、繁体中文；其他语言暂用英文时，按现有机制显式加入 [allowedFallbacks](test/l10n_completeness_test.dart)，并记录后续补译范围。

```powershell
flutter gen-l10n
flutter test --no-pub test/l10n_completeness_test.dart
git status --short -- lib/l10n
git diff -- lib/l10n
```

确认生成改动只对应本次 ARB 修改，并一同提交。不要直接修改生成类，也不要把键齐全或自动检查通过写成已经完成母语复核。

## 提交评审

PR 描述写清触发问题、修改后的行为、实际运行的验证与仍待完成的条件；结果关联提交和日志，历史测试不移作当前版本证明。界面修改说明平台、窗口、字号和主题范围；截图、模拟器、原生 API 和实体设备分别记录。

学校站点贡献请提供公开入口、系统名称、复现步骤及脱敏样例，配置位置为 [assets/school_sites.json](assets/school_sites.json)。不要提交账号、密码、Cookie、API Key 或含个人课表的原始数据。

本地提交、推送、发布和商店提交是不同动作。实现完成不代表已发布；发布约束与实际验收记录见 [发布验收](docs/RELEASE_ACCEPTANCE.md)。
