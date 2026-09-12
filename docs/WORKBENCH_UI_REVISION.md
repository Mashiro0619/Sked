# 桌面／平板工作台 UI 修订

更新：2026-09-12。承接融合重构，未提交、未推送。旧版截图和 2166 项测试记录只是历史基线。

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

## 自定义日期选择与导航（2026-09-10，上一阶段基线）

本节记录先前固定自然周选择器的实现与验证。自由始末、范围持久化和新的最终结果以文末“自由日期范围修订”为准；本节截图及测试数字不计入本轮范围验收。

### 实现与兼容

- 使用 SkedDatePicker / showSkedDatePicker 替换应用内五处内置日期弹窗调用及侧栏小月历；没有新增框架或日期组件依赖，时间选择器保持原样。
- 日视图选择单日；周视图连续高亮周一至周日并保留点击日期作为日焦点；月视图顶栏直接选月并裁剪月底日号；列表选择后续 180 天安排的起始日，不再误显示周范围。
- 侧栏左右箭头只浏览小月历。点击日期、主工具栏前后／今天或画布日期导航才更新主日期并重新定位小月历；分类显隐、导航折叠和尺寸变化保留浏览月份。
- 弹出内容提供日历、月份网格、年份快速跳转、严格校验的本地化手动输入及键盘导航；整周背景、日焦点边框和今日小标记彼此独立。星期表头视觉为短标签，辅助技术读取完整日期、星期及选择范围。
- 桌面使用紧凑锚定浮层，触屏采用居中弹窗／窄屏任务页，触控日期区域不小于 48 dp。旋转、缩放、IME 变化不重建选择会话；极小横屏高度允许整体滚动，避免标题和按钮将输入区压到不可用。
- 导航点击即提交；事件起止日期、重复截止日、学期和导入校对仍需确认，取消不改原草稿。表单只接收日期，不绕过原保存、校验、失败重试和工作区约束；停用域或移除父任务后，旧回调不返回可提交结果。
- 桌面与窄屏标题共同遵循原日期格式设置。中文本地化为“2026年9月7日–13日”、“2026年9月28日–10月4日”和“2026年12月28日–2027年1月3日”；斜杠／ISO 保留分隔与补零，跨年保留两端年份。原默认值及用户保存的设置均不覆盖。
- 新增 DateSelectionUnit 仅用于 UI，持久化仍为一个日焦点日期；不增加 AppData 字段、迁移或任意日期范围／农历业务。

### 入口对应

| 原入口 | 新组件行为 | 原业务约束 |
|---|---|---|
| 日程工具栏及触屏资源日期入口 | 按日／周／月导航单位选择，立即跳转 | 1970-01-01 至 2100-01-01；隐藏周末规则仅属于导航 |
| 桌面资源小月历 | 独立浏览月份；周模式整行选择，其余按日 | 日焦点与主画布同源，普通浏览不写入 Provider |
| 事件开始／结束日期 | 单日确认后更新编辑草稿 | 保留原起止日期联动、事件保存和取消 |
| 重复规则截止日 | 单日确认后更新规则草稿 | 最早可选日期仍为事件开始日 |
| 课表学期起始日 | 单日确认后更新课表草稿 | 2020-01-01 至 2035-01-01；不改变课表提交目标 |
| 解析结果及 Web 导入校对 | 单日确认后更新同一导入会话 | 2020-01-01 至 2035-01-01；不重建解析／WebView 会话 |

### 验证记录

新测试检查日期范围、跨月／跨年／闰日、各格式与语言、整周语义、年月快速导航、手动输入错误、界限与禁用日期、侧栏浏览保持、视图切换日焦点、全部表单入口确认／取消、父路由移除、工作区停用、焦点恢复和小高度软键盘可达性。既有日期组件测试改用新组件的真实点击／输入，不再直接调用内置日历回调替代用户操作。

小高度回归先复现输入区仅剩 16 dp（.scratch/date-picker-small-height-before.log），修复后相关组件与导航回归通过。命名时区套件新增选择器范围／换月的 civil-date 边界断言；纽约／柏林 DST 与上海对照沿用既有 CI 环境，不改变系统时区。

### 日期选择器最终结果

| 项目 | 结果 |
|---|---|
| 格式 | 402 个 Dart 文件，0 变更 |
| 静态分析 | No issues found |
| 全量测试 | **2287 通过，1 项专用 DST 测试跳过，0 失败** |
| 总覆盖率 | **34534 / 38271 = 90.2354%**，门槛 81.76% |
| 修改行覆盖率 | **753 / 764 = 98.5602%**，门槛 90%；比较当前 HEAD 与工作区 |
| 本地化同步 | 重新生成后全部 app_localizations 文件哈希不变，ARB 与生成代码一致 |
| 上海非 DST 对照 | **13 项全部通过**，包含请求时区前置断言和新选择器 civil-date 范围断言 |
| 实际 Flutter 渲染 | **1 项集成测试通过，45 张截图**：9 组布局 × 主周视图／周选择／月份网格／表单选日／手动输入 |
| Windows 正常入口构建 | flutter build windows --debug --no-pub -t lib/main.dart 成功；build/windows/x64/runner/Debug/sked.exe 已恢复为正常应用入口 |

最终截图与清单：.scratch/date-picker-visual-final/manifest.json。Windows 桌面 1440／1920、800 分屏、深色 2 倍字，以及 Android 样式 800 竖屏／1280 横屏、1.3 倍字、360 手机及 2 倍字分别标注。所有截图来自 Windows 上的真实 Flutter 渲染；Android 样式与尺寸是模拟布局，**不是 Android 模拟器或实机**，也不代替 Windows 外部原生边框／贴靠操作验收。实际查看截图后修正了今日小点与数字重叠，并增加对应几何断言；年月标题增加下拉指示。

时区说明：最初直接在 Windows 子进程设置 TZ=Asia/Shanghai 会得到 UTC，时区前置断言因此失败；保留失败日志 .scratch/date-picker-timezone-control.log。最终仅清除子进程 TZ 覆盖，使用已核实的本机 China Standard Time（UTC+8）运行对照，13 项全部通过，**没有修改系统时区**。纽约／柏林真实 DST 转换仍需既有 Linux CI 环境运行，本轮不宣称它们已验证。

日志：.scratch/date-picker-{format-final,analyze-final,full-final,coverage-final,l10n,timezone-control-final,visual-final,build-final}.log。第三方 WebView 的现有 CMake 开发警告保留，不影响编译；无新增覆盖率排除，不弱化业务断言。

当前未连接 Android 设备，手机／平板实机软键盘、系统返回与旋转验收仍未完成；当前尺寸、焦点、返回和草稿连续性由 widget 测试及上述 Windows 模拟布局检查覆盖。工作区改动未提交、未推送，原本地 Windows 缓存文件未删除或纳入源码。


## 自由日期范围修订（2026-09-10）

### 实现与兼容

- 日程顶栏和侧栏共享同一个范围会话。第一次点击仅选择起点，第二次有效点击才应用；首尾计入，1–14 天，允许反向点选、同日、跨月、跨年。15 天不截断，保留起点并显示错误。
- 手动输入为本地化始末两个字段；非法日期、倒置、越界和超长范围给出行内错误。保存中禁用重复操作；失败保留候选范围并可重试，手动改动字段后会撤销旧候选的重试入口，避免保存过期始末；Esc、系统返回和外部关闭取消待选范围，不改已应用范围。
- “周”仍是自然周快捷预设；手工七天同样标记“自定义 · 7天”。自定义始末与日焦点分离；在范围内点击日期不移动边界。选择“周”清除当前自定义状态，并在原自然周内处理隐藏周末的焦点；本次界面会话记住上次自定义范围，便于再次选择“自定义”。明确清除后重启不会暗中恢复已清除的活动范围。
- 前后和允许的翻页手势按真实天数平移，保持焦点相对位置；无法完整平移时禁用方向。今天／外部日期定位保留长度，上界附近整体调整；日／月／列表之间切换保留范围，返回自定义时根据外部日焦点重新定位。
- 标题、真实日期列、全天条带、事件查询和只读工作区上下文共用始末。自定义范围显示全部周末，但不改周预设的周末偏好。8–14 列以最小列宽横向滚动，禁用竞争翻页手势；辅助栏预算最多使用已有七日画布预算。
- 触屏日期按钮直接显示“自定义 · N天”，不只依赖长按提示；英文等语言的一天标签使用正确单数。无日焦点字段的已保存范围默认聚焦其起点；重新进入自定义时，已有焦点在范围外则按原长度重新定位。
- 独立 UI 滚动会话保存横向位置与分钟锚点，范围翻页及日／月／列表往返不丢时间上下文。今天和外部日期跳转有独立的非持久化定位信号，确保横滚后目标日期真正可见；普通范围翻页不强行回到首列。
- 实际截图检查发现横滚会带走时间标尺，已将月份标尺、时间标尺及全天控制固定；RTL、触控点击、窗口缩放均有回归。对照：.scratch/custom-range-before-fixed-ruler.png 与最终 windows-1440-large-custom-fourteen-end.png。
- 范围分页采用围绕当前日期的有界窗口，靠近窗口边缘重定位；不生成跨整个 1970–2100 区间的巨型滚动坐标。已复现并修复小数宽度和旋转触发的 Flutter scrollExtent 精度异常，未削弱断言。
- GeneralDateRange 负责 civil-date 规范化、长度、边界与整体平移。GeneralScheduleData 子 schema v4 → v5，根 schema 仍 v3。旧数据缺范围不猜测；v4 严格校验仍保留，v5 非法范围进入既有错误恢复。
- 范围和日焦点用既有运行时互斥、持久化屏障一次提交，成功后才发布；失败不会暴露半更新，也不覆盖同期其他设置。完整备份不会捕获尚未成功发布的范围／日焦点；完整恢复预约使日期选择会话失效，即使恢复后仍启用同一工作区；禁用和父任务移除的排队回调同样受保护。
- 完整备份含范围；普通分类 JSON／ICS 导入保留当前范围。事件、重复截止日、学期及导入表单继续使用单日期确认／取消；未修改时间选择器、课表学期周、重复规则和密钥边界。
- 性能基准样本版本同步升至 4，只更新受日程 schema 标签影响的四个序列化校验和；新增对照断言证明还原 v4 标签后与原校验和完全相同，事件、缓存和清洗校验和未改。

### 本轮入口与状态验收

| 入口／行为 | 检查内容 |
|---|---|
| 顶栏日期按钮、桌面侧栏 | 两次点选共享状态，待选时主日期不变；浏览、分类显隐、折叠、尺寸变化不重建会话 |
| 范围与视图菜单 | 自定义天数标签、周预设、日／月／列表往返、保留日焦点 |
| 前后、今天、外部日期、手势 | 真实长度平移、上／下界完整范围、失败回到已保存页 |
| 日期输入与键盘 | 本地化双字段校验、PageUp／PageDown、方向键、Enter、取消与焦点恢复 |
| 主画布与辅助内容 | 5 天和 14 天真实列、首尾查询、全天／每日重复事件、周末与只读上下文一致 |
| 编辑和数据生命周期 | 编辑草稿保留，恢复／停用／父任务失效保护，写入失败和重试无重复提交 |
| 触控与旋转 | 360／800／1280／1440／1920 dp，48 dp 日期触点，2 倍字及手机横屏＋软键盘保留输入 |

### 最终复验与证据

最终复验日期：2026-09-11。以下数字仅来自本轮自由始末实现，不使用上方固定周选择器的历史验收。

| 项目 | 结果 |
|---|---|
| 格式 | 410 个 Dart 文件，0 变更 |
| 静态分析 | No issues found；最后一处测试字符串 lint 修正后单独复验通过 |
| 全量测试 | **2338 通过，1 项专用 DST 套件跳过，0 失败** |
| 最后测试样式修改复验 | custom_range_navigation_test：18 项全部通过；未修改生产逻辑或弱化断言 |
| 总覆盖率 | **35271 / 39028 = 90.3736%**，门槛 81.76% |
| 修改行覆盖率 | **1655 / 1678 = 98.6293%**，门槛 90%；HEAD → 工作区；无新增排除规则 |
| 本地化同步 | 再次生成后全部 app_localizations 文件哈希不变；一天及各语言复数形式有独立测试 |
| 非 DST 对照 | 本机 China Standard Time，清除子进程 TZ 后 **14 项全部通过**；未更改系统时区 |
| 实际 Flutter 渲染 | 集成测试通过，**107 张 PNG**（Windows 样式 47 张，Android 样式模拟触屏布局 60 张） |
| Windows 正常入口 | lib/main.dart 的 debug 构建成功；sked.exe 已恢复为应用入口，不是视觉测试入口 |
| 源码与 diff | source inventory 和 git diff --check 通过；HEAD 未改变，未暂存、未提交、未推送 |

截图清单：.scratch/custom-range-visual-final/manifest.json。9 组尺寸／字号／明暗：Windows 1440／1920、800 分屏、2 倍字深色；触屏模拟 800×1280 竖屏、1280×800 横屏、1.3 倍字深色、360 手机及 2 倍字。每组包含自然周、未选范围、起点待选、5 天画布与高亮、月份网格、双字段输入、14 天画布与跨行高亮、可横滚时的末列，以及单日期业务表单确认／输入。

实际抽查截图确认：跨行高亮按真实端点绘制；桌面浮层保持紧凑，触屏不缩小日期触点；触屏顶栏可见自定义天数；14 天横滚至末列仍显示固定时间标尺及全天控制。最后一列可见、LTR／RTL 对齐、滚动后按钮命中及缩放保持均有几何／真实输入断言。

代表截图：
- .scratch/custom-range-visual-final/windows-1440-range-fourteen-selected.png
- .scratch/custom-range-visual-final/windows-1440-large-custom-fourteen-end.png
- .scratch/custom-range-visual-final/tablet-landscape-simulated-custom-five-days.png
- .scratch/custom-range-visual-final/tablet-portrait-simulated-range-input.png
- .scratch/custom-range-visual-final/phone-large-simulated-custom-fourteen-days.png

日志：.scratch/custom-range-{format-final,analyze-final,full-final,coverage-final,l10n-final,timezone-final,visual-final,build-final}.log；测试样式复验：custom-range-final-test-lint-recheck.log。保留第三方 WebView 既有 CMake 开发警告，未通过禁用检查隐藏问题。

### 未完成的平台验收

- adb devices 当前为空；**Android 手机／平板实机、真实软键盘、返回手势与系统旋转未验收**。本轮 Android 样式图片来自 Windows Flutter 渲染，并非 Android 模拟器或实机证据。
- 纽约／柏林真实 DST 仍需既有 Linux CI 命名时区步骤；常规套件按原约定跳过，上海对照不能替代 DST 转换验收。
- 本轮截图验证应用内容与布局，不替代 Windows 外部原生边框、拖动、贴靠和多显示器 DPI 的人工重验；未修改 runner，保留原平台验收边界。
- 未提交／推送；原本地 %SystemDrive% 缓存没有删除、暂存或纳入源码。


## 2026-09-12：范围交互与自研时间选择器

本节取代上文有关「普通周也两次点选」「侧栏单击开始范围」和「未修改时间选择器」的交互描述；既有数据迁移及范围导航边界不变。

- 普通周日期入口单击跳周；自定义侧栏单击保留天数并定位日期。侧栏可用主键拖选，或从「调整范围」进入同一范围弹层；成功后自动生效，无额外应用按钮。
- 选择器独立声明 none / dragOnly / full 交互模式及 displayRange。悬停、键盘预览和拖选不写入、不重建主画布；起止端点可单独修改，也可重新选择。无效范围不截断，取消指针与移出月历不提交，拖动结束不再触发点击导航。
- 日期／时间复用同一自适应弹层宿主，包括触发点定位、主题、焦点恢复、IME／缩放保持和工作区／数据会话失效保护。
- 时间使用时分列表＋数字输入，滚动仅浏览，确定才返回草稿；精确到分钟。日程、课程、节次入口全部替换，业务校验、课程节次匹配、草稿及自动保存保持原有职责。
- 验证入口：sked_time_picker_test、sked_date_range_controller_test、sked_date_range_picker_test、custom_range_navigation_test，以及三个时间调用方的回归测试。date_picker_visual_test 扩展了普通周、侧栏拖选预览、时间列表、分钟输入与滚轮浏览的实际 Flutter 渲染检查。
- 平台证据需区分：Windows 集成运行是 Windows Flutter 运行时；Android 风格画面仍是布局模拟，不代表 Android 实机、系统软键盘或真实 DST 转换已验收。


### 本轮最终验证

- 全量：2370 项通过，1 项需专用时区环境的 DST 用例按原约定跳过；未放宽断言或超时。
- 静态分析无问题；覆盖率门槛通过：总体 35795 / 39536 = 90.5377%，修改行 753 / 768 = 98.0469%。源文件清单检查通过，无新增覆盖率排除。
- Windows 正常入口 Debug 构建成功。现成进程占用构建输出时使用隔离副本验证，没有强制关闭用户窗口。
- 实际 Flutter 渲染集成测试通过：9 组窗口／字号／主题，共 136 张图（Windows 风格 61，模拟触屏风格 75）。抽查了桌面范围／时间弹层以及手机 2 倍字号；范围预览、错误、保存阶段保持月历单元格位置，时间列表显示完整五行。
- 新增回归验证了原始 PointerCancel 不会被当作成功拖选、主画布不随预览重建、鼠标拖选不调用窗口 startDrag、时间列表滚轮不滚动后台、范围手动输入保留端点草稿。
- 原生鼠标验收提供 opt-in：SKED_NATIVE_POINTER_CHECK=true，必要时用 SKED_NATIVE_TOOL 指向捕获脚本的绝对路径。本环境两次因测试窗口无法取得前台而被安全检查阻止，未发送原生鼠标输入；此项不记为实机通过。Android 实机、真实 IME 与专用 DST 环境仍需另行验收。

证据：.scratch/picker-full-verified.log、picker-analyze-verified.log、picker-coverage-verified.log、picker-windows-build.log、picker-visual-verified.log；截图清单位于 .scratch/picker-interaction-visual-final/manifest.json。time-picker-preview.png 是其中一张桌面实测渲染的裁剪预览。


### 同日交互收敛：移除冗余内容、优化时间列表

用户截图中的两块常驻辅助区域已移除：侧栏不再显示拖选说明及「调整范围」，范围弹层不再重复显示操作步骤、起止摘要、天数、单端按钮或「重新选择」。当前范围通过月历高亮表达；需要改起止日期时使用保留的日期输入模式。范围弹层从已有「自定义」视图菜单或日期标题打开。必要的错误／保存状态和重试使用原有标题栏，正常状态不预留额外空白，也不让日期网格随错误消息跳动。

时间输入与列表列宽对齐，数字使用等宽数码和明确的选中样式。点击已经可见的值不会再把列表强制回中；只有离开可视区的选中值才平滑定位，减弱动态效果时直接定位。每列只保留一根边缘细滚动条，滚动结束自动淡出；支持鼠标拖动浏览、键盘 PageUp／PageDown，保持滚动不修改时间、确认后才返回草稿的规则。触控行仍满足 48 dp 命中尺寸。

本次收敛复验（2026-09-12）：

- `dart analyze` 无问题，20 个改动 Dart 文件格式检查无变化，`git diff --check` 通过。
- 五组针对性回归共 72 项通过；全套以 `flutter test --no-pub --concurrency=2` 复跑，2377 项通过，1 项需指定命名时区的 DST 回归按预设跳过。
- 首次全量覆盖率运行中，两项现有通知后台用例出现时序失败；该文件单独复跑 107 项通过，随后完整复跑通过，未更改通知逻辑或其测试来绕过失败。
- 覆盖率门禁通过：总行覆盖率 90.5215%，变更行 97.7992%；覆盖数据来自首次全量覆盖率运行，最终完整复跑未开启覆盖采集。
- 隔离工作目录中的 Windows 视觉集成测试通过，生成 136 张、9 组布局截图；已检查紧凑范围弹层和桌面／大字号模拟触控时间列表。手机和平板样式为 Windows 上的模拟布局，不作为移动设备实机结论；本次未完成操作系统级指针实机验证。
- 证据：`.scratch/picker-compact-full-verified.log`、`picker-compact-analyze.log`、`picker-compact-regression.log`、`picker-compact-notification-recheck.log`、`picker-compact-coverage.log`、`picker-compact-visual.log`；截图清单为 `.scratch/picker-compact-visual/manifest.json`，并排预览为同目录 `pickers-preview.png`。
