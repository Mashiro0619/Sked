# Sked 全应用 M3 Expressive 视觉重做与工具链升级计划

## 结论与设计依据

当前 Flutter 稳定版没有 Compose 文章中的 MotionScheme、ButtonGroup、SplitButton 或 Expressive LoadingIndicator 同名 API。Flutter 官方提供的是标准 Material 3 组件和动画基础设施，因此本项目采用：

- 官方 NavigationBar、NavigationRail、NavigationDrawer、SegmentedButton、FAB、Dialog、Bottom Sheet 等组件，保留其语义、键盘和无障碍能力。
- Sked 内部增加轻量的形状、弹簧和响应式组件层，不引入第三方仿制 M3 Expressive 包，也不使用 Compose/PlatformView。
- 保留当前用户选择的精确主题色、课程颜色和日历颜色；不启用 DynamicSchemeVariant.expressive，不新增色相旋转、渐变或自动改色。
- 设计依据：
  - https://m3.material.io/blog/building-with-m3-expressive
  - https://m3.material.io/blog/m3-expressive-motion-theming
  - https://docs.flutter.dev/ui/widgets/material

### Flutter API 边界

- Flutter 3.44.9 提供官方 Material 组件、`Durations`、`Easing`、`RoundedSuperellipseBorder`、`StarBorder` 和 `SpringSimulation` 等基础能力，但没有 Compose M3 Expressive 中同名且数值等价的 `MotionScheme`、`ButtonGroup`、`SplitButton` 或 `LoadingIndicator` API。
- `DynamicSchemeVariant.expressive` 只是一种动态配色方案，不是 Expressive 形状或动效系统；为保留用户精确主题色，本项目不使用它。
- Sked 的 shape 与 motion token 是应用内部实现。非弹簧过渡以 Flutter 官方 `Durations` / `Easing` 为 Material fallback，但不宣称与 Compose Expressive 的内部参数完全等价。
- Flutter 官方 `SegmentedButton` 不开放单个分段的 shape 插值：通用封装只负责官方语义、48dp 触控区和 Sked 样式；真正的移动形状指示器在阶段三的具体模式/视图选择器中实现。

阶段一基线为 1232 项测试通过、1 项跳过；阶段二验收当前为 1260 项测试通过、1 项跳过。工作树应在每个大阶段开始前保持干净。

## 阶段一：升级工具链

目标版本已由官方 Flutter release manifest 核实：

- Flutter 3.44.9 stable
- Dart 3.12.2
- Flutter revision 6b182d2c7585eba26d4edce0f97630effd256c33

实施内容：

- 升级本机 D:\Soft\Flutter 到上述 stable 版本，确认 SDK 工作树没有本地改动。
- pubspec.yaml 更新为 Dart ^3.12.2、Flutter >=3.44.9。
- .github/workflows/flutter.yml 中两个 Flutter 安装步骤统一改为 3.44.9。
- 使用 flutter pub get --enforce-lockfile 同步 pubspec.lock；不执行依赖大版本升级。
- 重新运行 l10n 生成并只接受 Flutter 生成器产生的必要差异。
- 不手动修改 .metadata 中的 Flutter 创建 revision。

## 阶段二：建立 Sked Expressive 基础设施

新增内部主题和组件能力，不改变 Provider、数据模型、存储、备份或导入导出接口。

### 主题形状与动效

新增：

- SkedShapeScheme：页面容器、卡片、字段、菜单、对话框、底部面板、选择指示器、FAB、工具栏等语义形状。
- SkedMotionScheme：fast/default/slow 三档 spatial motion 与 effects motion。
- SkedMotionPolicy：统一处理系统关闭动画、TickerMode 和运行时动画策略。
- SkedSpringBuilder：基于 AnimationController.unbounded、SpringSimulation 和 snapToEnd，支持快速反向操作时继承当前速度。

规则：

- 位置、尺寸、旋转、形状使用可回弹 spatial spring。
- 颜色和透明度使用无回弹 effects motion。
- 禁用动画时立即到达终态；Dialog 和 Sheet 路由使用 `AnimationStyle.noAnimation`，Switcher 则绕过动画或使用零时长。
- 根 MaterialApp 通过现有 WidgetsBindingObserver 响应系统辅助功能变化。
- 形状只实现实际使用的 6 组受控变体，不复制完整 35 形状库；形状 morph 仅用于选择指示器、工具栏、预览和少量 hero 元素。
- 不给课表格线、日历单元格和长列表项逐个创建动画控制器。

### Expressive 组件映射

| M3 Expressive 概念 | Sked 实现 | 使用位置 |
| --- | --- | --- |
| Button groups | SkedExpressiveSegmentedButton，底层仍为官方 SegmentedButton；移动形状指示器由具体选择器实现 | 日/周/月/列表、主题选项 |
| App bars/toolbars | SkedWorkspaceToolbar | 两种首页上下文与时间导航 |
| FAB / Extended FAB | SkedPrimaryFab | 唯一新增课程/事件操作 |
| Loading indicator | SkedExpressiveLoadingIndicator，关闭动画时回退官方进度指示器 | 启动、导入、长时间保存 |
| Shape morph | SkedShapeScheme + ShapeBorderTween | 选中状态、主题预览、展开区 |
| Motion scheme | SkedMotionScheme | 所有新增自定义动效 |

所有交互目标至少 48×48dp，文字不使用 FittedBox 压缩；当前支持语言、键盘焦点和屏幕阅读器语义必须保持有效。

## 阶段三：统一自适应 App Shell

AppHomeScreen 在恢复门禁、首次引导和隐私逻辑完成后，渲染统一的 AdaptiveSkedShell。

### 一级导航

课程模式和通用日程模式完全同等突出：

- <600dp：带文字的两项 NavigationBar。
- 600–839dp：紧凑 NavigationRail。
- 840–1199dp：扩展 NavigationRail。
- >=1200dp：约 240dp 的永久 NavigationDrawer。
- 设置作为全局次级入口，在顶栏或 Rail/Drawer 底部显示，不再在两个领域 AppBar 中重复放置模式切换按钮。
- 切换模式沿用 provider.switchMode()；保存期间显示忙碌语义，失败后保持原模式。

### 状态与生命周期

- 两个工作区使用 IndexedStack 保留用户的周次、日期、视图和滚动位置。
- 非活动工作区包裹 TickerMode(false)、ExcludeSemantics 和不可聚焦作用域。
- 非活动课程实时刷新定时器和日程提醒定时器必须暂停，重新激活时立即刷新。
- 隐藏页面不得抢夺键盘焦点、注册快捷键或重复执行导航。
- 恢复门禁和首次引导继续位于 Shell 外部，不能被导航或动画遮盖。

### 统一上下文契约

阶段三只由 Shell 建立两种工作区共享的导航、生命周期和内容承载契约；以下领域内上下文由阶段四、阶段五分别落地，不能把旧工作区直接嵌入 Shell 视为已经完成重做：

1. 当前课表/日历选择器。
2. 上一周期、中心日期/周次、回到当前、下一周期。
3. 视图选择组。
4. 唯一主操作。
5. 设置和集合管理等次级操作。

阶段三完成模式切换的 fade-through；日期/周次切换的方向一致 spatial motion 随阶段四、阶段五的工作区重做实现。

### 完成记录（2026-08-09）

- 已建立统一 `AdaptiveSkedShell`：紧凑宽度使用双目的地 `NavigationBar`，中等与扩展宽度依次切换 `NavigationRail` 和永久 `NavigationDrawer`。
- 两个工作区保持持久挂载，跨 600/840/1200dp 断点及模式往返均保留本地视图和页码状态；非活动工作区同时停止语义、输入、焦点与业务计时器，课程实时刷新和日程提醒的分钟边界、前后台及 Ticker 生命周期均有行为测试。
- 模式切换使用可反向的 fade-through，并在系统关闭动画时直接完成；连续完成态切换、快速反向、保存失败和保存期间主题快照均有回归测试。
- Provider 已采用已提交模式可见层、串行模式事务和保存屏障，模式保存失败只回滚模式字段，不覆盖同期的日期或设置编辑。
- 全量验收基线：`flutter analyze` 无问题，1291 项测试通过、1 项按环境跳过；总覆盖率 84.7648%，改动行覆盖率 96.4132%；Android Debug APK、Release App Bundle、Windows Debug 和 Web Debug 构建通过，Impeccable 检测无问题。

## 阶段四：课程模式重做

- 移除课程首页独立 Scaffold、领域 AppBar、模式切换按钮和重复新增按钮，改为 Shell 内的 StudentWorkspace。
- 保留课表切换、周次选择、显示设置和所有现有课程操作。
- 新增日视图：窄屏或大字体首次进入默认日视图，显示可横向滚动的日期条和单日时间轴。
- 周视图在窄屏使用固定时间栏、日期列最小宽度和横向滚动，禁止无限压缩列。
- 修正课程卡片固定最小高度和 Clip.none 造成的视觉覆盖；视觉卡片遵循真实时间几何，交互层提供经过边界裁剪的最小触控区域。
- 空课表提供“创建课表”为主操作、“导入课表”为次操作；已有课表但无课程时继续显示真实网格。

### 完成记录（2026-08-09）

- 学生课表已由 Shell 承载为单一工作区，移除生产路径中的重复 Scaffold、AppBar、模式切换和新增入口；课表选择在窄屏使用不可拖拽的底部面板，在宽屏使用居中面板，保存中保持门禁并支持失败重试。
- 日/周视图、日期条、固定时间栏、同步横向滚动和空课表状态均按窗口宽度及文字缩放适配；矮屏和大字体环境下周次、今天、视图切换及设置入口保持可达。
- 课程视觉严格按真实节次时间几何绘制，短课程交互层按相邻边界扩展并裁剪；旧版 `00:00–00:00` 且带节次索引的课程按当前节次时间集恢复显示，长按课程不会误触发空槽创建。
- 周次导航支持可中断、可反向的空间过渡；快速连续操作、键盘方向、系统减少动效、选择状态语义和保存中模态关闭门禁均有回归测试。
- 阶段四验收：`flutter analyze` 无问题，1309 项测试通过、1 项按环境跳过；总覆盖率 85.0240%，改动行覆盖率 93.7572%；Android Debug APK、Release App Bundle、Windows Debug 和 Web Debug 构建通过，Impeccable 检测无问题。

## 阶段五：通用日程模式重做

- 移除独立 AppBar 中重复的新增、模式切换和设置入口。
- 统一日、周、月、列表四种视图的日期导航和视图选择组，删除内部重复的上一月、下一月、今天控制。
- 保持时间轴和月历的数据主体克制，优化 48dp 触控区域、当前日期和下一事件的单一强调层级。
- 窄屏时间控件纵向排列，宽屏并排排列；提醒条只在活动工作区运行。
- 保留日历管理、筛选、重复、提醒、全天事件和所有现有数据行为。
- FAB 是唯一“添加日程”主操作；编辑器或键盘弹出时隐藏或禁用。

### 完成记录（2026-08-09）

- 通用日程已纳入统一 Sked 工作区，日、周、月、列表视图共用工具栏、日期导航和视图选择；重复的 AppBar、日期跳转栏、月份控制和新增入口已移除。
- 手机月视图优先显示选中日期议程，选择后会自动把议程带回可见区域；宽屏保留日历与议程并排布局，提醒条仅在活动工作区运行。
- 日期导航已覆盖隐藏周末、跨月边界、方向性箭头和完整本地化日期/周次信息；程序化时间轴跳页延迟到 attach 后执行，不再在 build 阶段回写 Provider。
- 阶段五验收：`flutter analyze` 无问题，1323 项测试通过、1 项按环境跳过；总覆盖率 85.2664%，改动行覆盖率 91.5033%；Android Debug APK、Release App Bundle、Windows Debug 和 Web Debug 构建通过。

## 阶段六：设置、编辑器与次级页面

### 设置与主题

- 设置页由卡片墙改为“当前课表/日历”“外观与语言”“数据与安全”“关于 Sked”连接式分组。
- 窄屏单列，宽屏双栏，内容宽度统一限制。
- 主题页增加不含真实用户数据的实时预览；主题模式和单色/多彩模式改为连接式选择组。
- 课程描边继续使用独立页面和“应用后保存”，只强化形状、层级和过渡动效。
- 保留精确主题色和现有颜色配置，不改写用户已保存的颜色。

### 编辑器与弹窗

- 课程编辑器按“课程信息—上课安排—更多信息”渐进披露。
- 日程编辑器按“事件信息—时间—重复与提醒—更多细节”渐进披露。
- 有已有值、校验错误或恢复草稿的分组自动展开，折叠不得清空数据。
- 复杂选择在窄屏使用可滚动底部模态面，在中大屏使用最大宽度约 560dp 的居中对话框。
- 标题和固定操作栏保持可见，正文独立滚动，键盘弹出时不产生溢出。
- 恢复、删除确认、隐私同意和错误状态保持克制，不使用趣味性形变。

### 其他页面

统一应用布局、形状、间距和无障碍规则到课表/日历显示设置、节次时间集、学校站点与导入、语言设置、数据传输和主题颜色管理页；不改变业务流程、网络边界、存储格式或权限策略。

### 完成记录（2026-08-10）

- 设置页、课程/日程编辑器、节次时间集、学校站点与导入等次级页面已统一采用安全区、内容宽度上限、窄屏重排和键盘可滚动布局；保存中状态、返回门禁、触控目标和选中语义保持不变。
- 移除阿拉伯语资源及受支持语言注册；旧存档中的 `ar` locale 会在严格解码后归一化为英语，启动门页在加载用户数据前固定使用英语，应用不会再因该语言启用 RTL。
- Android 320dp、2x 字体下的长设置标题改为可横向滚动且保留完整语义；减少动效日期条测试改为按当前选中日期计算目标，避免日期相关的假失败。
- 阶段六验收：`flutter analyze` 无问题，`flutter test --coverage` 通过（1340 项通过、1 项按环境跳过）；覆盖率总计 85.7149%，改动行覆盖率 91.0044%；覆盖率门禁、Android Debug APK、Release App Bundle、Windows Debug 和 Web Debug 构建通过。

## 阶段七：视觉收口与验收

只设置两个主要 hero moments：

1. 首页模式/视图选择指示器的形状移动与弹簧过渡。
2. 日期/周次导航到新周期时的方向性标题与内容过渡。

其他地方只使用短促按压反馈、透明度变化和必要的展开动画，避免全屏持续弹跳。

验收矩阵：

- 尺寸：320×568、360×640、430×776、575/576、600×800、900×360、1024×768、1120×680、1200+。
- 字体缩放：1.0x、1.3x、2.0x。
- 语言：中文、英语、德语及其他已注册语言（均采用 LTR 排版）。
- 主题：浅色、深色、用户自定义精确主题色。
- 动效：正常动画、系统关闭动画、快速反向点击、键盘/鼠标/触控。
- 状态：首次引导、无课表、空日历、加载、保存中、保存失败、恢复门禁、筛选无结果。
- 无障碍：语义选中状态、live region、焦点恢复、快捷键、主要操作 48×48dp。
- 性能：Android 真机检查 60Hz 帧预算；禁止为网格和长列表创建逐项 Spring controller。

验证命令：

~~~
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
dart run tool/coverage_gate.dart --base-ref HEAD
flutter build apk --debug
flutter build appbundle --release
flutter build windows --debug
flutter build web --debug
~~~

### 完成记录（2026-08-10）

- 首页工作区与视图选择器、学生周次和通用日程日期导航已完成形状移动、弹簧过渡和方向性内容过渡；快速反向、首帧、视图切换竞态、RTL 轴向、系统关闭/减少动效和运行时无障碍设置均有回归覆盖。
- Android 紧凑导航在大字体下动态保留标签空间，移动指示器与图标区域保持对齐；Flutter 原生 `NavigationBar` 的目的地动画现在遵循 Sked 动效策略，关闭或减少动效时立即完成。
- 独立 review 发现并修复了方向为零但触发值不变时未清理空间动画、日期过渡与视图切换叠加，以及原生导航栏忽略系统动效设置三项问题；未发现新的 P0/P1 阻断项。
- 阶段七验收：`dart format`、`flutter analyze` 通过；`flutter test --coverage` 为 1355 项通过、1 项按环境跳过；总覆盖率 85.8124%，改动行覆盖率 94.4290%，覆盖率门禁通过；Android Debug APK、Release App Bundle、Windows Debug 和 Web Debug 构建通过。Windows 构建仅保留第三方 WebView 插件的 CMake 开发警告。

## 约束与交付

- 不修改数据 schema、Provider 持久化接口、备份/恢复协议、导入导出格式或网络行为。
- 新增主题、动效和布局类型均为应用内部类型，不作为包公共 API。
- 首次引导内联隐私同意、首次浅色主题、恢复门禁和精确颜色逻辑全部保留。
- Web 不作为交付平台，但继续编译共享响应式代码和相关测试。
- 每个大阶段完成后执行 review、修复 review findings、完整验证，再只创建一个中文 Conventional Commit；不把多个大阶段混在同一提交中。
- 计划文件本身保留在 docs/M3_EXPRESSIVE_PLAN.md，除非用户之后明确要求删除。
