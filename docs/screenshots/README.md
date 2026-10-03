# 文档截图 / Documentation screenshots

## 已收录大屏快照（待更新）

> **截图待更新**：截至 2026-10-04，README 的手机和大屏图库均未更新到最新界面。大屏图仍来自下面记录的 2026-09-29 修订，不包含后续浮动面板、分类管理和选择器调整。本次仅更新说明，不替换图片或改写原采集清单。

- 版本：`2.3.0-rc.1+15`；UI 来源修订：`c55a661`；采集日期：2026-09-29。
- 每种语言 8 张，共 16 张，位于 `zh/*-desktop.jpg` 和 `en/*-desktop.jpg`。
- README 的「平板 / 桌面」共用这些 **Windows 大屏渲染图**，不另放平板图片，也不将它们标为 Android 平板实机截图。触控设备的实际导航和窗口按钮可能不同。
- **Android 手机原有 16 张图片本次未更新**，可能与 RC.1 的工具栏、菜单有所不同；它们不在本次 [manifest.json](manifest.json) 中。
- 图片由 Windows 原生 Flutter 渲染器运行采集修订的生产组件后，通过 `RepaintBoundary.toImage` 输出，不是设计稿、Web 仿制图或带合成设备边框的图片。窗口按钮来自应用自身组件；不包含操作系统桌面或阴影。
- 独立内存数据与模拟通知网关，不读取用户存档、不发系统提醒。双语示例使用 2026-09-28 当周，月视图展示 2026 年 10 月；运行时“今天”高亮仍取决于系统日期。
- 桌面截图仅证明所展示界面的渲染结果，不代替 Android 真机、触控、通知、安装包或商店验收，也不代表 RC 已发布。

## 场景 / Scenes

| 文件名（语言目录内） / Filename | 内容 / Content | 尺寸 / Size |
| --- | --- | --- |
| `student-week-desktop.jpg` | 课表周视图，完整侧栏 / Timetable week, expanded sidebar | 1440 × 900 |
| `general-week-desktop.jpg` | 日程周视图，完整侧栏 / Schedule week, expanded sidebar | 1440 × 900 |
| `general-month-desktop.jpg` | 月视图与当天安排 / Month view and agenda | 1440 × 900 |
| `course-editor-desktop.jpg` | 课程编辑面板 / Course editor panel | 1440 × 900 |
| `settings-desktop.jpg` | 设置总览与分组导航 / Settings overview and navigation | 1440 × 900 |
| `course-details-desktop.jpg` | 课程详情 / Course details | 1440 × 900 |
| `event-details-desktop.jpg` | 日程详情 / Event details | 1440 × 900 |
| `event-editor-desktop.jpg` | 日程编辑 / Event editor | 1440 × 900 |

所有大屏截图统一为 1440 × 900、浅色主题，像素比与字体倍率均为 1。

## 复现 / Reproduce

需要 Windows、项目所需 Flutter SDK / Visual Studio 桌面工具链，以及 Python 3.10+ 和 Pillow。在仓库根目录执行（PowerShell）：

~~~powershell
flutter pub get
$revision = git rev-parse --short HEAD
# 读取实际版本；上方历史快照及 manifest 不随升版修改。
# Read the current version without rewriting historical capture provenance.
$versionLine = Select-String -LiteralPath 'pubspec.yaml' -Pattern '^version:\s*(\S+)\s*$'
if (@($versionLine).Count -ne 1) { throw 'Expected one version in pubspec.yaml.' }
$version = $versionLine.Matches[0].Groups[1].Value
$capture = Join-Path (Get-Location) '.scratch/docs-desktop'
flutter test integration_test/documentation_screenshots_test.dart -d windows `
  --dart-define="SKED_VISUAL_OUTPUT=$capture" `
  --dart-define="SKED_DOC_REVISION=$revision" `
  --dart-define="SKED_DOC_VERSION=$version" --reporter expanded
if ($LASTEXITCODE -ne 0) { throw 'Capture failed; do not export.' }
python tool/export_documentation_screenshots.py --input $capture
if ($LASTEXITCODE -ne 0) { throw 'Export failed.' }
~~~

以上换行使用 PowerShell 续行符。仅运行已通过的完整采集结果的导出；勿将旧目录中的 manifest 当作本次测试成功的证明。复现其他 UI 修订时应记录实际修订，并注明尚未提交的 UI 修改。

- [采集测试](../../integration_test/documentation_screenshots_test.dart)使用真实详情和编辑入口，验证页面出现后才截图；采集结束清理组件和内存状态。
- [导出工具](../../tool/export_documentation_screenshots.py)先检查完整的 16 张清单、路径、格式与尺寸，再输出 JPEG（质量 90、4:4:4，不缩放、不裁剪）；不会覆盖手机图片。
- `manifest.json`记录版本、UI 修订、采集时间、宿主平台、语言、场景、尺寸、主题、文件大小与 SHA-256。原始 PNG 留在忽略的 `.scratch/` 下，不进入仓库。
- 导出后逐张检查原图、确认双语 README 图片链接有效，并核实手机文件没有变动，再提交文档。商店素材需另行处理，本工具不更新商店截图包。

## English notes

As of October 4, 2026, both README galleries are awaiting an update to the latest UI. The Tablet / Desktop galleries still share eight Windows-rendered views per language (16 images total), captured on September 29, 2026 at revision `c55a661`; they do not show the subsequent floating-panel, category-management and picker changes. They use real production Flutter widgets from that revision, isolated in-memory sample data and no notification delivery, and are not Android tablet device captures. Existing Android phone images are also outdated and excluded from this manifest. This documentation update does not replace image assets or alter capture provenance.

All desktop captures use the same 1440 × 900 viewport, a light theme, and 1× pixel and text scale. Event dates are fixed, but today's highlight follows the runtime clock.

Run the PowerShell commands above from the repository root with Windows Flutter tooling and Python/Pillow installed. Export only after a successful capture test, inspect every image, and check the README links and unchanged phone assets. The manifest records provenance and SHA-256 hashes. These are UI documentation snapshots, not release, installer, notification, touch-device or app-store acceptance evidence.
