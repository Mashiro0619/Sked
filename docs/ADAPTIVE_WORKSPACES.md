# Sked 融合自适应工作台：实施与验收

更新：2026-09-09。最新桌面／平板 UI 修订承接工作区安全基础，未提交、未推送。本轮结果单独记录于 `WORKBENCH_UI_REVISION.md`；以下融合方案的历史验收不能替代修订后的验证。

## 实现边界与布局

继续使用 Material 3 Expressive、用户精确配色、本地优先及现有框架。保留课程、重复规则、平台限制和安全契约，不新增云同步、拖拽改期或真正的 AI 对话／执行能力。

`WorkbenchLayoutPolicy` 统一计算实际任务预算。600 / 840 / 1200 dp 是窗口等级，不是机械单双栏阈值。

| 区域 | 正常字号预算 | 行为 |
|---|---:|---|
| 展开资源导航 | 224 dp | 工作区、课表／分类及管理入口合并 |
| 紧凑导航 | 鼠标 56 / 触控 80 dp | Android 保持至少 48 dp 触控目标 |
| 画布并栏预算 | 通用 600 / 七日周视图 800 dp | 仅判断能否增加旁栏，不限制窄窗口运行 |
| 详情／编辑 | 默认 360，最低 320 dp | 可调宽；关闭后归还空间 |
| AI | 默认 400，最低 360 dp | 独立于详情，支持并排和覆盖 |
| 设置 | 类别 224 + 内容 520 + 分隔 1 dp | 正常字号下 800 dp 竖屏可双栏 |

预算随字体放大。空间不足先折叠／隐藏资源，再覆盖详情，最后覆盖 AI；不覆写用户的打开状态和宽度偏好。两个覆盖任务只显示最近操作的一项，另一个保持会话但不取得焦点。

- 课表保留完整画布、日期、空闲节次与间隔；日／周日历默认不重复当天清单。月历横向预算充足时旁置安排，竖屏有足够高度时月历＋下方安排填满空间；窄窗口使用单滚动面并在选中月底后返回安排。列表采用列表—详情。
- 周视图表头、全天区域和时间网格对齐并共用横向滚动；不足时不删日期、不缩字；横向滚动不与切周竞争。日期导航保留月末裁剪等原语义。
- 连续表面和细分隔取代整栏浮动大卡片；课表／日历使用剩余空间，普通表单限制阅读宽度。
- `WorkspacePaneController` 保留稳定编辑 Navigator；`WorkspaceTaskScope` 让编辑填满面板，输入法高度只扣一次。
- 嵌套 Navigator 的语义容器不会遮掉仍可见的导航、资源与画布；隐藏区域移除焦点和语义。Esc 使用专用任务 Intent，避免被输入框的选择工具栏吞掉。
- 课程、事件、学校站点编辑在宽屏就地接续、窄屏为单一任务，旋转不重建草稿。节次使用顺序表格／条目。

## Windows 与 AI 接口

`DesktopWindowBridge` 与 runner 使用 `com.mashiro.sked/window`。应用操作和窗口控制共用顶行；引导、恢复、设置和管理使用同一宿主，不增加第二条标题栏。原生实现保留移动、边缘缩放、双击最大化／还原、最小化、系统菜单、关闭、DPI 消息和最大化边界。

最大化区域返回 `HTMAXBUTTON`，非客户区鼠标消息交给 DWM / DefWindowProc，避免 Flutter 吞掉悬停。关窗先执行草稿守卫、flush UI 保存并等待在途写入；取消或失败不关闭。

**命中测试不等于贴靠菜单验收。** 本轮记录证明正常窗口无独立标题栏、DPI 120 下命中、真实拖动 70×35 px、最大化／还原／最小化、编辑中缩放及关闭草稿确认取消。悬停探针截图未显示贴靠菜单，因此菜单展示／选择、多显示器 DPI、系统菜单及边缘贴靠仍未验收。旧拖动失败源于集成测试未传播设备指针，已修复测试绑定而非移除断言；前台／遮挡保护保留。详情见 `WORKBENCH_UI_REVISION.md`。

`DeveloperUiPreferences` 在本机记住开发者页 AI 显隐开关，不进入 AppData 或备份；保存值优先于默认 false 的 `SKED_AI_LAYOUT_PREVIEW`。显式关闭同步偏好，布局降级不改变它。只有开启预览后显示未接入的上下文、对话区域和输入草稿，发送不可用，不调用解析 API。`AssistantPaneController` 独立保存打开状态、宽度和草稿；`WorkspaceContextSnapshot` 仅包含启用域、资源标识、日期／视图及选择标识，不包含密钥、记录正文或停用域。未来数据修改必须复用现有校验和持久化命令。

## 旧设置与新入口映射

首页仅列必要状态及六类（已删除设置中心搜索）：外观、通知与提醒、语言、数据与隐私、功能管理、关于。类别导航与窄屏页面共享状态；常用配置不以嵌套折叠作为导航。

| 原入口 / 配置 | 新入口 | 保存与状态契约 |
| --- | --- | --- |
| 全局设置中的课表 / 日程切换 | 主功能导航；隐藏导航时的显式工作区菜单 | 切换持久化成功后才发布活动模式；普通切换保留两边会话 |
| 隐藏底部 / 工作区导航 | 设置 → 功能管理（仅双工作区显示） | 即时保存；隐藏不是停用 |
| 大屏导航展开 / 收起 | 同一个资源侧栏的折叠按钮 | 沿用原持久化偏好；尺寸变化不写回偏好 |
| 主题、主题模式、单色 / 五彩、UI 配色 | 设置 → 外观 | 显式工作区编辑目标，预览使用局部 Theme；不切换应用当前工作区 |
| 课程名称色、课程文字色、课程描边 | 设置 → 外观 → 课表目标 | 停用课表后不提供这些选项；描边草稿保留保存 / 取消 |
| 分类颜色、月历文字颜色 | 设置 → 外观 → 日程目标 | 停用日程后隐藏，继续使用原配置字段 |
| 语言 | 设置 → 语言 | 内联搜索；保存失败可重试；宽屏保留当前类别 |
| 通知总开关、默认提醒、锁屏标题 | 设置 → 通知与提醒 | 仅列出启用域的默认提醒；常见异常保持可见 |
| 通知 / 精确闹钟 / 电池与厂商权限说明 | 通知与提醒 → 权限与排障 | 保留真实平台状态，不将厂商设置误报成已授权 |
| 课表外部点击关闭、时间间隔、过去 / 未来课程、网格线 | 课表工具栏 → 显示与交互 | 即时保存 |
| 课表日期列适配、周列适配、切周手势 | 课表工具栏 → 显示与交互 | 不擅自删除空闲日期、节次或间隔 |
| 课表工具栏顺序、隐藏项目、更多菜单、添加与长按 | 课表工具栏 → 显示与交互 | 仅影响手机／触控工具栏；Windows 固定日期、今天、文字视图、显示及新增，不读写这些旧字段 |
| 日程默认视图、视图切换方式、工具栏宽度、日期格式 | 日历工具栏 → 显示与交互 | 日 / 周 / 月共用日期与选择；桌面使用独立紧凑工具栏 |
| 周末、农历、开始 / 结束小时、密度与小时高度 | 日历工具栏 → 显示与交互 | 即时保存，保留原日历计算 |
| 日程外部点击关闭、工具栏顺序 / 隐藏、快捷添加 | 日历工具栏 → 显示与交互 | 沿用原字段及即时保存行为 |
| 课表名称、学期起始日、总周数与节次集分配 | 课表资源列表 → 编辑 | 共享原校验和保存逻辑；宽屏面板、窄屏任务页；失败保留草稿 |
| 节次集新增、分配与编辑 | 课表管理 → 节次时间集 | 宽屏列表—详情；无课表时也可维护模板 |
| 节次名称 / 起止时间、增加 / 删除、模板导入导出 | 节次时间集 → 编辑 | 时间顺序表格 / 条目；自动保存、失败重试和离开保护 |
| 学校站点、站点导入导出 | 课表导入 → 学校站点 | 宽屏列表—编辑、窄屏单任务；共享校验、失败重试、取消及草稿保护 |
| 文本 / HTML 解析、学校网页导入 | 课表导入流程 | 宽屏来源、解析状态与结果校对分区；保留 WebView 会话、平台限制和失败恢复 |
| AI Base URL、API 密钥、模型、提示词 | 课表导入 → AI API 配置 | 连接 / 模型 / 高级提示词分区；自动保存与重试；密钥仍使用安全存储 |
| 无课表时配置解析服务 | 课表空状态 → 导入 → 配置入口 | 不要求先建立课表，不联网探测用户内容 |
| 课表文件 / 文本导入与导出 | 课表资源菜单 → 导入／导出 | 不改变工作区启用范围 |
| 分类显隐、新增、重命名、删除 | 日程分类区域 → 管理 | 显隐即时保存；管理列表—详情；保存失败保留编辑内容 |
| 日程 JSON / ICS 导入与导出 | 分类标题菜单 → 导入／导出 | 保留显式替换目标及选择范围，不改变启用范围 |
| 完整备份与恢复、恢复文件 | 设置 → 数据与隐私 | 恢复前显示启用范围变化并确认；备份保留停用域数据，不导出 API 密钥 |
| 隐私政策与清除数据 | 设置 → 数据与隐私 | 危险操作独立着色并确认；清除后的永久写入门禁和退出保护保留 |
| 版本更新、许可、项目链接、开发者入口 | 设置 → 关于 | 保留现有平台限制和开发者解锁手势 |
| 开发者 AI 布局显隐（本轮） | 设置 → 关于 → 原开发者入口 | 本机独立偏好，成功后发布；失败保持原状态并重试；不存聊天、不调用解析 API |
| 课程“应用内提醒”旧文案 | 课程编辑 → 系统提醒 | 保留 CourseReminderSettings；跟随默认／不提醒／自定义，显示全局开关和权限条件 |
| 工作区启用范围（新增） | 设置 → 功能管理 | 至少启用一个；停用当前域时原子切换；重新启用不主动切换 |


手机从页面／明确菜单进入，平板和桌面从同一资源或类别导航进入；不复制配置真值。普通选项最多两层，独立复杂任务才进入第三层。首页六类由 `settingsCatalog` 驱动；目的地统一负责工作区可用性。设置中心搜索及搜索定位 UI 已删除，语言页内部搜索保留。

外观以显式工作区目标和局部预览编辑，不改变活动工作区；通知突出当前异常，权限说明独立；语言紧凑可搜索；解析 API 分为连接、模型、高级提示词，不混为未来对话 AI 配置。

开关即时保存，节次／API 自动保存与重试，课程／事件／站点显式保存／取消。站点失败在表单内反馈，不用遮住底部保存按钮的 Snackbar 代替重试状态。JSON 校对在宽屏并排显示实时摘要，窄屏保留同一原始文本；确认保留空白和未知字段，返回保护未确认修改。文本／HTML 导入只扣除一次输入法高度。

## 持久化、停用与恢复

- schema v3 的 `enabledWorkspaces`、提醒恢复边界与 `activeMode` 分离；v1 / v2 迁移为两域启用，v3 空集合、重复／非法值和活动域不一致进入错误恢复，不静默重新启用。
- 首次选择仅课表／仅日程／两者，和隐私同意一起在保存成功后生效；旧用户保留两域，至少保留一个。
- `setWorkspaceEnabled` 串行化，停用当前域时原子切换；重新启用不强制切换。`switchMode` 拒绝停用域。
- 停用保留数据、配色和配置，卸载页面并拦截独立路由、计时器、解析、模型网络请求和 WebView 在途结果；普通模式切换保留会话。
- 导航、导入导出、主题和默认提醒均过滤停用域；仅功能管理保留重新启用入口。单域不显示单项工作区导航；隐藏导航与停用相互独立。
- 通知读取 `AppRepository.persisted` 已提交快照；事务、运行时互斥和版本边界阻止旧异步任务回写。清除数据不扩大运行时锁，避免回入等待。
- 按来源清除排程、已展示通知与稍后提醒；旧通知不会恢复工作区。重新启用以 UTC 边界排除停用期间已到期提醒。
- 写入失败维持旧启用状态；提醒清理失败维持停用标记，显示异常及重试。Windows 散装程序的通知历史限制仍按原发布契约处理。
- 完整备份含停用域数据和启用选择，仍排除 API 密钥；恢复确认启用变化，并处理所有被覆盖域的草稿（包括恢复后仍启用的域）。批准丢弃后退役旧编辑会话，普通导入不改变启用范围。

## 验收状态矩阵

A = 自动化行为／模拟尺寸；E = Android 模拟器实际运行；R = Windows 上的 Flutter 客户区运行截图；W = 原生 Windows 完整窗口记录。R 不证明 Windows 原生窗口行为，以上均不能冒充 Android 手机／平板硬件。

| 页面／任务 | 手机／窄窗口 | 平板竖屏／横屏 | Windows | 尚缺证据 |
|---|---|---|---|---|
| 课表、详情、编辑 | A + R：360 及断点 | A + E + R：800 / 1280，含课程系统提醒 | A + R；编辑 W | 实机与硬件输入体验 |
| 周／日／月／列表 | A + R；E：手机月底选择和回显 | A + E + R：四种视图，月历竖屏上下结构 | A + R；周视图 W | 用户视觉验收、Android 实机 |
| 编辑／输入法 | A：草稿与保存失败 | E：系统旋转、返回收键盘、设置往返、保存 | W：缩放、关闭确认及取消；Esc 有 A | 硬件输入法、原生保存失败关窗 |
| 课表／分类／节次管理 | A + R：校验与保存契约 | A + R：列表—详情、大字降级 | A + R | Android 实机流程 |
| 学校站点 | A + R：校验、失败重试 | A + R：列表—编辑、旋转、退出确认 | A + R | Android 实机视觉 |
| 导入／WebView／校对 | A + R：配置、来源、JSON／结构校对 | A + R：来源／校对并排、大字降级 | A + R | OEM WebView、真实学校登录与解析 |
| 外观／语言 | A + R：选择和搜索 | A + E：800 双栏、暗色、2 倍字体 | A + R，含描边子页 | 实机与所有本地化人工校对 |
| 通知／数据／功能／关于 | A + R：目录、状态、守卫 | A + R；E：功能管理、关于、开发者开关 | A + R，含排障、许可与开发者页 | Android 实机、真实系统权限与提醒 |
| 工作区停用／完整恢复 | A：迁移、失败、旧通知、恢复 | A + E：单域导航、最后域保护、停用当前域 | 共用命令 A | 系统通知历史清理与后台续排实机 |
| Windows 窗口 | 不适用 | Android 不显示窗口按钮 | W：无独立标题栏、命中、拖动、最小化／最大化、关闭草稿确认 | 贴靠菜单、系统菜单、多显示器 DPI、边缘贴靠 |
| AI 预留 | A：覆盖和会话 | A + E：开发者开关、旋转、关闭同步与草稿恢复 | A + R + W：并排样板 | 本机重启仍以偏好单测为证据；不宣称 AI 业务已接入 |

### 上一轮子页视觉矩阵（历史基线）

`integration_test/workspace_pages_visual_test.dart` 在 Windows 上运行 **24 个页面／任务 × 5 个布局 = 120 个场景**，包括六类设置、课程描边、分类编辑、许可、开发者、节次管理与编辑、站点列表与编辑、解析配置、配置缺失、文本／HTML 来源、JSON 实时校对与结构化校对。覆盖 360、800、1280、1440 dp，含浅／深色与 2 倍字体。

输出为 `.scratch/fusion-pages/manifest.json`、对应 PNG 和 contact sheets；测试 **1 passed**，全场景无 Flutter 布局异常，并对分类名称编辑、许可内容等关键目标做显式断言。数据、通知权限和解析结果使用内存样例，不联网；许可证截图使用仓库真实 LICENSE。它们是 Flutter 客户区内容截图，不是 Android 截图，也不证明 Windows 系统贴靠或真实权限状态。

解析完成后，有配置表单的新流程定位到学期元数据，而不是旧的输出末尾；旧转录跟随行为和用户主动停止跟随仍保留。

### 上一轮工程结果（不包含本次 UI 修订）

<!-- verification-results -->
- `flutter analyze --no-pub`：No issues found。
- `flutter test --no-pub --coverage --concurrency=4 --timeout=120s --reporter expanded`：**2166 通过，1 跳过，0 失败**。
- 覆盖率门禁：总计 **33281 / 37111 = 89.6796%**；修改行 **3210 / 3542 = 90.6268%**，两项通过；source inventory 通过。
- 日志：`.scratch/fusion-final-analyze.log`、`.scratch/fusion-final-suite.log`、`.scratch/fusion-coverage-final.log`。
- 格式检查（与 CI 相同的 `dart format --output=none --set-exit-if-changed .`）：382 个 Dart 文件，0 变更；`git diff --check` 通过，暂存区为空。
- 1 项跳过为需要 `SKED_DST_TEST_ZONE` 与 `TZ` 的专用 DST CI 测试，本次 Windows 本地运行未执行该时区矩阵。
- 以上不包括已因前台／遮挡条件失败的 Windows 扩展原生交互测试，也不代替 Android 实机。
<!-- /verification-results -->

门槛保持总覆盖率 **81.76%**、修改行覆盖率 **90%**；没有排除新文件或弱化断言规避失败。

### 复现与证据边界

~~~powershell
flutter analyze --no-pub
flutter test --no-pub --coverage --concurrency=4 --timeout=120s --reporter expanded
dart run tool/coverage_gate.dart --base-ref HEAD
dart format --output=none --set-exit-if-changed .
git diff --check
~~~

- `integration_test/workspace_visual_test.dart`：Flutter 内容截图与逻辑尺寸，不能证明 Windows 原生行为或 Android 实机。
- `integration_test/workbench_window_test.dart` + `tool/capture_workbench_window.ps1`：内存样例的原生 Windows 验证。操作要求测试窗口未遮挡且拥有前台焦点。
- `integration_test/workbench_preview.dart`：交互式内存样板，以 `--dart-define=SKED_AI_LAYOUT_PREVIEW=true` 显式展示 AI，不打开课程、密钥或站点用户存储。
- 上一轮 Android 历史样板为 API 36、密度 320 的只读 AVD（1600×2560 / 2560×1600 px）；本轮修订使用同型隔离 AVD、密度 160，800×1280 / 1280×800 dp 和 360×800 dp。使用真实 Android 系统旋转与软键盘，但仍不是平板硬件。最新 32 张 PNG／XML 见 `.scratch/revision-android-delivery/manifest.json`。
- 预览 Dart 入口不含生产后台入口；AVD 既有 WorkManager 任务曾尝试启动生产入口而失败。此隔离预览环境限制不代表生产通知已通过验证，本轮未为预览接入用户存储。
- `.scratch/fusion-android/`、`.scratch/fusion-window/`、`.scratch/fusion-*.log` 是历史样板；本轮截图与日志使用 `revision-*-delivery` 和 `revision-window-verified`。本轮编辑草稿为 `Rotation draft A`，设置往返和旋转后保存，列表可见；AI 输入草稿 `Assistant layout draft` 在关闭／重开后保留。此次只读模拟器已关闭。历史截图不替代本次证据。

**仍未完成最终验收：** Android 手机和平板实机，Windows 完整原生操作，Android 管理／导入及设置子页的实机视觉，以及真实权限／提醒流程。在这些完成前，不宣称整份融合计划已通过验收。

## 附录：历史选项的迁移核对清单

以下 ID 是上一轮 58 个静态选项的核对编号，不再是搜索索引或 Widget Key。当前 settingsCatalog 仅含六类；具体控件仍使用原 Provider 字段，手机、平板与 Windows 共用目的地和域过滤。此表用于防止功能遗漏，不代表实机已验收。

| 目录 ID | 静态标签 | 目的地 | 可用范围 |
|---|---|---|---|
| `appearance` | 外观 | 设置 → 外观 | 通用 |
| `notifications` | 提醒与通知 | 设置 → 通知与提醒 | 通用 |
| `language` | 语言 | 设置 → 语言 | 通用 |
| `data` | 数据与隐私 | 设置 → 数据与隐私 | 通用 |
| `features` | 功能管理 | 设置 → 功能管理 | 通用 |
| `about` | 关于 Sked | 设置 → 关于 | 通用 |
| `theme` | 主题 | 设置 → 外观 | 通用 |
| `theme-color` | 主题色 | 设置 → 外观 | 通用 |
| `theme-mode` | 跟随系统 | 设置 → 外观 | 通用 |
| `backup` | 完整应用备份与恢复 | 设置 → 数据与隐私 | 通用 |
| `privacy` | 隐私政策 | 设置 → 数据与隐私 | 通用 |
| `clear` | 清除数据 | 设置 → 数据与隐私 | 通用 |
| `licenses` | 开源许可 | 设置 → 关于 | 通用 |
| `updates` | 检测更新 | 设置 → 关于 | 通用 |
| `navigation` | 隐藏主界面工作区导航 | 设置 → 功能管理 | 双工作区 |
| `notification-enable` | 启用提醒与通知 | 设置 → 通知与提醒 | 通用 |
| `notification-permission` | 通知权限 | 通知与提醒 → 权限与排障 | 通用 |
| `notification-privacy` | 在锁屏上显示标题 | 设置 → 通知与提醒 | 通用 |
| `course-reminder` | 课程默认提醒 | 设置 → 通知与提醒 | 课表启用时 |
| `event-reminder` | 日程默认提醒 | 设置 → 通知与提醒 | 日程启用时 |
| `student-display` | 课表显示与交互 | 课表工具栏 → 显示与交互 | 课表启用时 |
| `period-times` | 节次时间集 | 课表管理 → 节次时间集 | 课表启用时 |
| `student-data` | 导入导出数据 | 课表资源菜单 → 导入／导出 | 课表启用时 |
| `schools` | 从学校网页导入 | 课表导入 → 学校站点 | 课表启用时 |
| `parser` | 课表解析 API | 课表导入 → 解析 API 配置 | 课表启用时 |
| `general-display` | 通用显示设置 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `general-data` | 分类导入导出 | 分类标题菜单 → 导入／导出 | 日程启用时 |
| `studentPreferences-coursePopupDismissSetting` | 允许点击空白处关闭课程弹窗 | 课表工具栏 → 显示与交互 | 课表启用时 |
| `studentPreferences-preserveTimetableGaps` | 保留课表空白时间 | 课表工具栏 → 显示与交互 | 课表启用时 |
| `studentPreferences-showPastEndedCourses` | 显示已结束课程 | 课表工具栏 → 显示与交互 | 课表启用时 |
| `studentPreferences-showFutureCourses` | 显示之后的课程 | 课表工具栏 → 显示与交互 | 课表启用时 |
| `studentPreferences-fitDaySelectorToWidth` | 日期选择条适应屏幕 | 课表工具栏 → 显示与交互 | 课表启用时 |
| `studentPreferences-fitWeekColumnsToWidth` | 周课表列适应屏幕 | 课表工具栏 → 显示与交互 | 课表启用时 |
| `studentPreferences-enableWeekSwipeNavigation` | 允许滑动切换周数 | 课表工具栏 → 显示与交互 | 课表启用时 |
| `studentPreferences-showTimetableGridLines` | 显示课表网格线 | 课表工具栏 → 显示与交互 | 课表启用时 |
| `studentPreferences-toolbarNavigationSection` | 工具栏导航 | 课表工具栏 → 显示与交互 | 课表启用时 |
| `studentPreferences-showAddCourseFab` | 显示悬浮添加课程按钮 | 课表工具栏 → 显示与交互 | 课表启用时 |
| `studentPreferences-enableLongPressAddCourse` | 长按空白网格添加课程 | 课表工具栏 → 显示与交互 | 课表启用时 |
| `generalPreferences-defaultView` | 默认视图 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-generalViewSwitchBehavior` | 视图切换按钮 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-generalToolbarWidthPolicy` | 工具栏空间分配 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-generalDateLabelFormat` | 日期显示格式 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-showWeekends` | 显示周末 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-showLunarCalendar` | 显示农历 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-startHour` | 开始小时 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-endHour` | 结束小时 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-timeGridDensity` | 时间网格密度 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-timeGridHourHeight` | 每小时高度 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-closePopupOnOutsideTap` | 点击外部关闭弹窗 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-toolbarNavigationSection` | 工具栏导航 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-showAddEventFab` | 显示悬浮添加日程按钮 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `generalPreferences-enableLongPressAddEvent` | 长按空白网格添加日程 | 日历工具栏 → 显示与交互 | 日程启用时 |
| `parser-schoolImportParserBaseUrl` | Base URL | 课表导入 → 解析 API 配置 | 课表启用时 |
| `parser-schoolImportParserApiKey` | API 密钥 | 课表导入 → 解析 API 配置 | 课表启用时 |
| `parser-schoolImportParserModel` | 模型名称 | 课表导入 → 解析 API 配置 | 课表启用时 |
| `parser-schoolImportParserCustomPromptTitle` | 自定义提示词 | 课表导入 → 解析 API 配置 | 课表启用时 |
| `appearance-themeColorCourseText` | 课程文字色 | 设置 → 外观 | 课表启用时 |
| `appearance-liveCourseOutlineEnabled` | 开启课程描边 | 设置 → 外观 | 课表启用时 |
