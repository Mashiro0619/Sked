# 桌面／平板工作台 UI 修订

更新：2026-09-10。承接融合重构，未提交、未推送。旧版截图和 2166 项测试记录只是历史基线。

## 本轮实现

- Windows 独立工具栏：统一 48 dp 顶行与窗口按钮；32–36 dp 操作；字号放大同步行高。运行时把命中矩形交给 runner，保留原生窗口行为及关闭保护。
- 资源导航：折叠按钮有 8 dp 留白，分类为色点＋名称＋显隐；同名分类按 ID 独立。设置仅留导航底部，工作区切换不再混入管理菜单。
- 分类／课表标题菜单直接进入管理、导入或导出；不再进入“显示设置＋导入导出”中转。显示与交互从功能工具栏进入。
- 周／日网格：固定日期表头、小型今天标记、同一列宽与滚动；全天两行预览、展开后限高滚动；并发按宽度和字体分栏，溢出为小数量入口和稳定冲突清单，短事件不虚增时长。
- 课表表头、节次标尺与课程块调整；保留空闲日期、节次、用户间隔。列表桌面版使用时间／标题／地点／分类列；月视图在横向预算足够时旁置安排，竖屏预算足够时上方月历＋下方安排，窄窗口共用单一滚动面。
- 月历按真实列宽、农历及字体预算分配高度；紧凑布局不产生第二个纵向滚动。选择月底日期后通过稳定控制器回到安排区，不依赖已被列表卸载的元素；覆盖 1／1.3／2 倍字体与旋转。
- 设置无全局搜索；语言列表搜索保留。外观改为紧凑下拉与名称／控件对齐，局部预览不切工作区；共享设置行、管理和详情采用平台密度。
- 课程“系统提醒”：原覆盖值不变，跟随默认／不提醒／自定义；只读查询权限，显示总开关、未配置默认、系统异常及送达限制；通知设置往返保留草稿。
- 开发者 AI 开关：DeveloperUiPreferences 独立本机偏好，写成功后发布，本机值覆盖编译默认。手动关闭同步、布局降级不写回；隐藏保留本次草稿并移除焦点。发送不可用，无网络请求、聊天存储或数据执行。

## 证据与验证边界

本轮密集内存数据包含 15 个分类、同名分类、3／6 个并发事件、5 行全天事件、5 分钟事件和长名称。不读取或改写用户资料。

- `integration_test/workbench_revision_visual_test.dart`：Windows 实际 Flutter 渲染，含桌面和平板／手机模拟布局；不是 Android 实机。
- `integration_test/workspace_pages_visual_test.dart`：管理、导入和设置子页渲染。
- `integration_test/workbench_window_test.dart` 与 `tool/capture_workbench_window.ps1`：完整 Windows 原生窗口；遮挡或前台归属失败时拒绝操作或截图，不去掉保护。
- 实机／模拟器／Windows 渲染分别记录，缺少设备不记为通过。

<!-- revision-results -->
### 工程结果（2026-09-09，大轮 UI 修订基线；最新复验见文末）

| 项目 | 结果 |
|---|---|
| 格式 | `dart format --output=none --set-exit-if-changed .`：393 个 Dart 文件，0 变更 |
| 静态分析 | `flutter analyze --no-pub`：No issues found |
| Windows 正常入口构建 | `flutter build windows --debug --no-pub -t lib/main.dart` 成功；`build/windows/x64/runner/Debug/sked.exe` 为应用入口，不是截图测试 |
| 全量测试 | **2205 通过，1 项专用 DST 测试跳过，0 失败** |
| 总覆盖率 | **33696 / 37543 = 89.7531%**，高于 81.76% |
| 修改行覆盖率 | **4407 / 4807 = 91.6788%**，高于 90% |
| 源码清单及 diff 检查 | source inventory 与 `git diff --check` 均通过 |

未修改覆盖率排除规则，未删除业务断言来消除失败。月底交互回归实际滚动、点击并检查安排可达；全天事件测试分别检查包含日、排除日与选中日期安排，避免把新月格上的合法标题误判为越界。唯一跳过项需要启动前指定 `SKED_DST_TEST_ZONE` 与 `TZ` 的专用 CI 环境。

日志：`.scratch/revision-format-delivery.log`、`revision-analyze-delivery.log`、`revision-full-delivery.log`、`revision-coverage-delivery.log`；以同目录最新 delivery 文件为准，不使用早期失败日志充当最终结果。

### 视觉和平台证据

| 类型 | 本轮结果 | 证据 |
|---|---|---|
| Flutter 实际渲染 | 10 个主页面 × 7 组尺寸／字号／明暗／平台样式 = **70 场景通过** | `.scratch/revision-visual-delivery/manifest.json` |
| 设置／管理／导入子页 | 24 页 × 5 组布局 = **120 场景通过**；360／800／1280 使用 Android 触控样式，1440／2 倍字桌面使用 Windows 样式 | `.scratch/revision-pages-delivery/manifest.json` |
| Windows 完整原生窗口 | **1 项集成测试通过**，9 张完整窗口；正常窗口无独立标题栏，DPI 120；真实拖动 70×35 px、最大化／还原／最小化、编辑缩放、关闭草稿确认及取消通过 | `.scratch/revision-window-verified/manifest.json`、`revision-window-verified.log` |
| Android 模拟器 | API 36 只读 AVD，160 dpi；800×1280 / 1280×800 平板、360×800 手机、系统旋转及 2 倍字；**32 张 PNG＋语义 XML**；进程日志未发现 Flutter 溢出或未处理异常 | `.scratch/revision-android-delivery/manifest.json`、同目录 `runtime.log` |

Android 通过 ADB 的真实系统输入、旋转和软键盘核对：

- 编辑草稿在旋转、系统返回收键盘、进入设置及返回后保留；取消放弃保留草稿，单次保存后在列表看到新事件。
- 手机滚到月底可点击日期，并回到当天安排；改变系统字体大小保留日期。
- AI 开关显示预览，显式关闭同步开发者开关，重开保留本次输入；隐藏面板从无障碍树移除。
- 两种单工作区状态、最后一个开关保护、停用当前域后切换，以及课表数据重新可用；日常导航与外观过滤停用域。
- 课程编辑显示“系统提醒”、跟随默认与通知总开关关闭条件。

预览使用隔离内存数据。Android 预览中的 DeveloperUiPreferences 也是内存替身，**模拟器证据不证明重启持久化或系统提醒清理**；本机偏好读写优先级、失败重试与备份排除由自动化测试覆盖。未接入真实 AI 对话、发送或执行。

Windows 的 `windows-snap-menu.png` 仅记录悬停探针，图中**未出现贴靠菜单**；`HTMAXBUTTON=9` 不能证明菜单展示或选择完成。拖动验证已允许集成测试接收设备指针事件，但继续保留前台／遮挡保护。

对比：`.scratch/revision-week-before-after.png`（上为用户原图，下为当前隔离样例完整窗口，数据集不同）；其它联系表为 `revision-contact-*.png`。模拟平台渲染、Android 模拟器和 Windows 原生窗口分别标注，均不冒充 Android 实机。截图用于检查入口、对齐与密度，不以通过数量代替用户视觉验收。

### 复现

~~~powershell
flutter test integration_test/workbench_revision_visual_test.dart -d windows --no-pub --dart-define=SKED_VISUAL_OUTPUT=D:/Project/Flutter/sked/.scratch/revision-visual-delivery
flutter test integration_test/workspace_pages_visual_test.dart -d windows --no-pub --dart-define=SKED_VISUAL_OUTPUT=D:/Project/Flutter/sked/.scratch/revision-pages-delivery
flutter build apk --debug --no-pub --target-platform android-x64 -t integration_test/workbench_preview.dart
flutter build windows --debug --no-pub -t lib/main.dart
flutter test --no-pub --coverage --concurrency=4 --timeout=120s --reporter expanded
dart run tool/coverage_gate.dart --base-ref HEAD
~~~

原生窗口测试需前台和无遮挡；Android APK 仅供隔离模拟器检查，不是生产构建。此次创建的 emulator-5570 已关闭。暂存区为空，未提交、未推送。
<!-- /revision-results -->

## 尚需人工或设备验收

- Android 手机和平板硬件、真实学校 WebView 登录和解析、OEM 权限与后台提醒。
- Windows 悬停贴靠菜单的实际展示与选择、多显示器 DPI、系统菜单及边缘贴靠完整矩阵；已通过的拖动、最小化／最大化和关闭草稿保护不重复列为未验证。
- 所有本地化的人工文案、视觉与触控检查。

这些项目在取得对应证据前保持未验收。测试数量或多栏数量不作为 UI 合格的替代标准。

## 弹窗下顶栏遮罩修复（2026-09-09）

用户报告的顶栏亮线与窗口按钮白块源于同一绘制层级遗漏：DesktopWindowHost 在根 Navigator 上方绘制窗口按钮及全宽分隔线，根弹窗的 ModalBarrier 无法覆盖这些外层内容。

- 新增 DesktopWindowModalObserver，仅跟踪应用根导航，按实际 ModalRoute.barrierColor、barrierCurve 与路由动画计算遮罩；叠加弹窗、反向关闭动画、移除／替换和不透明页面均清理对应状态。
- 只给窗口按钮与宿主分隔线补齐遮罩绘制，不再次加深已经覆盖的应用工具栏；不增加模态路由、输入拦截或焦点域，窗口按钮与关闭草稿守卫保留。
- 根导航观察器由应用／启动页生命周期持有；局部面板弹窗不导致整个窗口变暗。
- 像素测试直接比较普通顶栏、窗口按钮背景及分隔线在动画前中后的颜色，覆盖浅色、深色及 2 倍字号；另验证透明菜单、嵌套根路由、叠加弹窗和窗口按钮操作。
- 同一快捷跳周弹窗的运行证据：.scratch/chrome-modal-visual/manifest.json，3 组布局 × 打开前／弹窗中／关闭后 = 9 张实际 Flutter 渲染图；这不是原生边框截图。
- 本次完整窗口截图被前台／遮挡保护中止，日志保留于 .scratch/chrome-modal-window.log，不将它标记为通过。默认构建目录被用户正在运行的 Sked 锁定，因此使用进程级隔离 Flutter 配置及 .scratch/chrome-modal-build 构建；未关闭用户窗口、未改全局构建配置。

遮罩修复后的最终验证：格式检查 **395 文件、0 变更**，静态分析无问题，**2210 通过／1 项专用 DST 跳过／0 失败**；总覆盖率 **33780 / 37629 = 89.7712%**，修改行覆盖率 **4494 / 4896 = 91.7892%**。新增遮罩观察器覆盖率 57 / 59（96.61%）；覆盖率排除规则未改，`git diff --check` 通过。日志为 `.scratch/chrome-modal-{format,analyze,full,coverage,visual,build}.log`。

正常 Windows 应用入口已在 `.scratch/chrome-modal-build/windows/x64/runner/Debug/sked.exe` 构建成功（不是集成测试入口）；用户原先打开的进程未关闭，默认构建目录没有强行替换。本次未提交、未推送。

## 未提交更改 Review 修复（2026-09-10）

本次仅修复审查发现的数据目标、草稿离开保护与日期范围问题，不重置先前的工作台、工作区停用或备份基础，也不改写 Git 历史。

### 修复内容

1. **课程编辑始终绑定打开时的课表。** Provider 的保存／删除命令支持显式目标课表，课程详情、普通编辑与通知入口均传递该目标；学期周数与节次也取自目标课表。切换当前课表、切换工作区或普通导入产生新课表，不再重定向旧草稿的保存／删除，保存也不强制切回原课表。目标课表已删除时拒绝写入，保留编辑草稿及失败反馈。详情本身按所属课表查找课程和冲突排序；失效时只移除自己的路由，不再误关叠在上方的编辑。
2. **描边草稿接入统一离开保护。** 课程描边页以完整草稿指纹判断修改，设置类别导航等待异步确认后再完成原先的跳转。取消确认保留同一表单 State 和未应用值；未修改时不询问；保存中阻止离开。窗口关闭、工作区停用和完整恢复复用同一守卫。底部明确的“取消”仍直接放弃，应用成功也不重复询问。异步导航在宿主卸载后停止。
3. **桌面课表周范围与画布对齐。** 工具栏复用 startOfWeekFor，开学日非周一或跨年时也按画布的周一到周日显示，不再从开学当天机械累加。

### 回归与工程结果

新增 18 个回归用例／平台变体，覆盖：新建草稿与已有课程的修改／删除、编辑期间导入、不同课表内相同课程 ID、冲突排序、目标课表删除、写入失败后重试、Windows／Android 样式的设置类别切换、取消及确认放弃、关闭窗口守卫，以及周一／周三开学和跨年日期。已有的保存失败、原子保存和显式取消断言保留。

修复前的红测记录：.scratch/review-fix-before.log（2 通过、7 失败），.scratch/review-existing-before.log（已有课程切表的 2 个用例均失败）。修复后相关测试 148 项通过；以下为最终全仓复验，不使用局部测试替代全量结果。

| 项目 | 最终结果 |
|---|---|
| 格式检查 | 396 个 Dart 文件，0 变更 |
| 静态分析 | No issues found |
| 全量测试 | **2228 通过／1 项专用 DST 测试跳过／0 失败** |
| Windows 正常入口 | flutter build windows --debug --no-pub -t lib/main.dart 成功，build/windows/x64/runner/Debug/sked.exe；不是集成测试入口 |
| 总覆盖率 | **33906 / 37694 = 89.9507%**，门槛 81.76% |
| 修改行覆盖率 | **4594 / 4986 = 92.1380%**，门槛 90%；比较 HEAD 与全部当前未提交更改 |
| 源码清单及 diff 检查 | source inventory、git diff --check 通过；暂存区为空 |

未增加覆盖率排除或弱化断言。AdaptiveNavigationScope 与 EditorExitGuard 的可测行覆盖率均为 100%。最终日志为 .scratch/review-fix-{format,analyze,regression,full,coverage,build}.log。Windows 构建保留现有第三方 WebView 的 CMake 开发警告，编译成功；没有启动应用或关闭用户窗口。

本次没有新增 Windows 完整原生窗口或 Android 设备操作证据；上文历史截图不作为这些修复的实机验收。Android 手机／平板硬件、Windows 贴靠菜单与多显示器 DPI 等未完成项保持未验收。工作区改动未提交、未推送。
