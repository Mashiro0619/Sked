# Sked 代码审查报告（2026-09-25）

审查对象：`main` 分支 `de7c87a`（版本 2.3.0+14）的 `lib/` 目录，不含生成的多语言文件。
原始审查阶段只读代码、没有修改项目文件。复现测试放在已被 git 忽略的 `.scratch/review_repro_test.dart`。

> **2026-09-26 状态更新**：以下保留原始审查记录和当时的源码行号。十项修复／清理现已完成，复核更正、验证范围和提交说明见文末。

## 结论

`flutter analyze` 零问题，整体代码质量较高：数据写入有原子替换、备份轮换、写入门禁和恢复日志，通知系统有防重登记与跨进程锁。本次共发现 10 个问题：

| 级别 | 数量 | 说明 |
| --- | --- | --- |
| 已确认 | 5 | 能说清触发条件和错误结果，其中 2 个已用测试复现 |
| 可能存在 | 3 | 机制成立，但触发依赖时序或环境 |
| 整理建议 | 2 | 重复代码与无效检查，不影响行为 |

建议优先修复第 1、2 项：一个会让用户设置悄悄丢失，一个会让 Windows 窗口无法关闭。

## 项目概览

- **定位**：本地优先的课表与日程应用，包含学生课表和通用日程两个工作区，可单独启用。Android、Windows 为发布平台，其余平台只保证能编译。
- **规模**：`lib/` 约 10 万行（不含生成文件）；193 个测试文件，约 30 个集成视觉测试；CI 检查格式、静态分析、多语言同步和覆盖率（改动行不低于 90%）。
- **启动**：`main.dart` 中的 `AppBootstrap` 先获取单实例租约，再创建 `TimetableProvider` 并异步加载；`MyApp` 创建 `AgendaCoordinator` 管理系统通知。
- **状态**：单个 `TimetableProvider`（6 个 part mixin）持有不可变的 `AppData` 快照。修改流程是：替换 `_appData` → `_saveAndNotify` → `normalizeAppData` → `AppRepository` 串行写入（失败回滚、关闭写入门禁）→ 通过 `committedData` 流发布已提交快照。
- **存储**：先写 `.tmp`，再把主文件轮换为 `.bak`，最后把 `.tmp` 改名为 `Sked_data.json`。加载时逐一判断三个文件的状态，损坏文件隔离到恢复目录。整份备份恢复有日志（journal）保证中断后可继续。
- **密钥**：API Key 只存在 flutter_secure_storage 中；`AiApiSettings.toJson` 不输出它，所以备份里不会带密钥。
- **重复日程**：由 `models/general_event_occurrence.dart` 中的 `expandGeneralEventOccurrences` 展开。带 `Z` 或时区偏移的时间解析为 UTC，应用内创建的日程是本地时间。
- **通知**：`lib/services/agenda_*` 约 1.4 万行，契约见 `DESIGN.md` 与 `docs/NOTIFICATION_DEDUPLICATION.md`。

## 问题清单

### 1. 切换日期会清空自定义日程列宽【已确认，已复现】

- 位置：[general_calendar_service.dart:127](lib/services/general_calendar_service.dart:127)
- 原因：`setSelectedDate` 没有用 `copyWith`，而是手动逐个字段重建 `GeneralScheduleData`，漏掉了 78b26fc 新增的 `customDayMinWidth`。
- 影响：在显示设置里把日程列宽设为 160 后，点"下一周""今天"或任意日期，列宽就变回默认，并在 450 ms 后存盘。清除自定义范围和点击通知跳转也会触发。
- 复现结果：修改前为 `160`，修改后为 `null`。
- 修复：改成 `return data.copyWith(selectedDateIso: selectedDateIso);`

### 2. API 密钥保存失败一次后，Windows 窗口再也关不掉【已确认】

- 位置：[timetable_provider.dart:1007](lib/providers/timetable_provider.dart:1007)、[timetable_provider.dart:661](lib/providers/timetable_provider.dart:661)
- 原因：密钥保存失败后，`_pendingSecretWrite` 一直是一个失败的 future，没有重置。`prepareForWindowClose` 和停用学生工作区时直接 `await` 它、没有捕获错误；另外两处等待它的地方（312 行、1133 行）已经捕获了。
- 影响：Windows 上 secure storage 写入或回读失败后，点击标题栏关闭按钮只会弹"保存失败，请重试"，窗口保持打开，重试也一样，只能强制结束进程。停用学生工作区也会一直失败。
- 修复：这两处改为捕获错误后重新读取密钥状态，或者在写入失败后把 `_pendingSecretWrite` 替换为已完成的 future。

### 3. 东八区下，UTC 存储的重复日程会漏掉查询窗口里的第一次【已确认，已复现】

- 位置：[general_event_occurrence.dart:588](lib/models/general_event_occurrence.dart:588)
- 原因：`_firstCandidateIndex` 用日程开始时间的 UTC 日期，去减查询起点的本地日期。在 UTC 以东的时区会多算一天，于是跳过了窗口里的第一个重复实例。
- 影响：ICS 导入的每日日程 `2026-09-01T23:30:00Z`（北京时间 07:30），查询本地 9 月 10 日 06:00–09:00 返回空，应返回 07:30 那一次。受影响的是以"当前时间"为起点的查询：凌晨约 1–9 点打开应用时，提醒条会漏掉前一天的逾期提醒；通知规划的 2 天回看窗口会漏掉最早一次。以零点为起点的日、周、月视图在东八区不受影响（前提是日程短于 16 小时）。
- 修复：先把 `rangeStart` 转成与 `eventStart` 相同的时区（`eventStart.isUtc ? rangeStart.toUtc() : rangeStart.toLocal()`）再计算日期差，按月重复的分支也做同样处理。

### 4. 启动时等待超过 15 秒，通知协调器就永久失效【已确认】

- 位置：[agenda_coordinator.dart:134](lib/services/agenda_coordinator.dart:134)
- 原因：如果 15 秒内 Provider 仍然不可写（例如用户停在数据恢复页），`_start` 捕获超时后不会再启动。`main.dart` 只调用一次 `start()`，也没有传入 `onError`，所以失败是静默的。
- 影响：用户在恢复页看了超过 15 秒才点"重新开始"或"重试"，本次运行期间新增、修改的提醒都不会排程，已删除的日程仍按旧计划通知，直到下次回到前台；Android 的通知点击也不再跳转。
- 修复：超时后继续监听 Provider 的变化，等它变为可写再启动；或者在恢复操作成功后重新调用 `start()`。

### 5. 任何保存失败都会让课表跳回当前周【已确认】

- 位置：[timetable_provider.dart:910](lib/providers/timetable_provider.dart:910)
- 原因：`_saveAndNotify` 的失败分支无条件执行 `_selectedWeek = _currentWeekForActiveTimetable()`。
- 影响：用户正在看第 12 周，修改课程或某个设置时保存失败（磁盘满、写入门禁关闭），课表立即跳回本周。通用日程的保存失败也会改动学生课表的周次。
- 修复：只在回滚的改动涉及当前课表（切换、新增或删除课表）时才重置周次。

### 6. 报告保存失败的修改，重启后可能又出现【可能存在】

- 位置：[timetable_storage_io.dart:366](lib/data/timetable_storage_io.dart:366)
- 原因：`.tmp` 已经完整写入后，如果轮换步骤失败（Windows 上主文件被杀毒软件或索引服务占用），`_save` 不会删除 `.tmp`；而 `load()` 会把可读的 `.tmp` 当作最新快照提升为主文件（165 行）。
- 影响：界面上提示保存失败并撤回修改，但重试加载或重启后，这次修改又回来了，而且不会触发通知重新规划。
- 确认方法：在测试里让 `_beforeMainReplace` 钩子抛出异常，再调用 `load()`。
- 修复：轮换失败且旧主文件仍在时，先删除 `.tmp` 再抛出异常。

### 7. 运行时存储出错时，这次提交的通知更新会丢失【可能存在】

- 位置：[agenda_coordinator.dart:453](lib/services/agenda_coordinator.dart:453)
- 原因：`_drainCommits` 由 `scheduleMicrotask` 启动，返回的 future 被丢弃；`activateProjectionAfterDurableData()`（453 行）和 `readProjectionFence()`（245 行）都不在 try 块里。
- 影响：SharedPreferences 读取失败时（例如 prefs 文件损坏），错误成为未处理的异步错误，刚编辑或删除的提醒不会重新规划，也不会触发 5 秒后的重试，要等下一次提交或回到前台。
- 修复：把这两个调用放进 try 块，失败时走 `_scheduleNotificationRetry`。

### 8. 回到前台时的通知对账用的是未落盘的数据【可能存在】

- 位置：[agenda_coordinator.dart:247](lib/services/agenda_coordinator.dart:247)
- 原因：`reconcileNow` 在没有传入 `data` 时读取 `_provider.appData`（乐观更新后的内存快照），而不是已提交的数据。这违背了类注释中"保存失败不能排出通知"的约定。
- 影响：新建一个带提醒的日程，写入还没完成时应用切到后台又回来（Windows 上失去焦点即可），就会按新日程排出通知。如果写入随后失败，Provider 会回滚，但回滚不发出提交事件，这条通知会一直留着。
- 修复：`data` 为 null 时改用 `_provider.committedAppData`。

### 9. 通知目标的实例查找逻辑重复了三份【整理建议】

- 位置：[main.dart:588](lib/main.dart:588)、[agenda_coordinator.dart:506](lib/services/agenda_coordinator.dart:506)、`agenda_action_router.dart` 约 526 行
- 说明：三处都在做同一件事：解析 occurrence key，在前 2 天到后 3 天内搜索可见日历，再匹配日历、事件和 key。点击通知、打开详情和"已处理"必须定位到同一个实例，以后调整搜索窗口时只要漏改一处，就会出现点通知打不开或"已处理"被静默跳过。
- 建议：抽取一个共用的 `resolveNotificationOccurrence(provider, AgendaTarget)`。

### 10. 重复且无效的工作区启用检查【整理建议】

- 位置：[timetable_provider_general.dart:101](lib/providers/timetable_provider_general.dart:101) 等
- 说明：9 个通用模式的修改方法连续调用两次 `requireWorkspaceEnabled(AppMode.general)`（101–102、142–143、155–156、229–230、321–322、346–347、360–361、412–413、424–425 行）。两个 mixin 中"先检查、再计算、再检查"的写法中间也没有 `await`，第二次检查永远不起作用，只有 `addPeriodTimeSet` 的两次检查之间隔着 `await`。
- 建议：每个方法保留一次检查，只在中间有 `await` 时才加第二次。

## 复现方法

```bash
flutter test --no-pub .scratch/review_repro_test.dart
```

在东八区运行，修复前第 1、3 项的两个测试都会失败；修复后应全部通过。建议修复时把这两个用例移到 `test/` 下作为回归测试。

## 审查范围

逐行读过的文件：

- `lib/main.dart`
- `lib/providers/` 下的全部 Provider 文件
- `lib/data/app_repository.dart`、`timetable_storage.dart`、`timetable_storage_io.dart`
- `lib/providers/timetable_provider_import_export.dart`（备份导入与恢复）
- `lib/services/agenda_coordinator.dart`、`desktop_window_bridge.dart`
- `lib/services/general_calendar_service.dart`、`general_occurrence_service.dart`
- `lib/models/general_event_occurrence.dart`、`general_schedule_data.dart`（部分）
- `lib/utils/calendar_date_utils.dart`、`time_utils.dart`（部分）

尚未逐行审查：

- 通知服务本体（`agenda_notification_service.dart` 约 4.9k 行、`agenda_notification_runtime_store.dart` 约 2.6k 行）
- ICS 导入导出（`general_calendar_ics_service.dart`）
- 学校导入（`school_import_api.dart` 及相关页面）
- 数据模型（`app_data.dart` 等）
- 各 UI 页面与选择器组件


## 2026-09-26 复核更正与修复结果

### 原始结论的边界更正

- **第 2 项**：原来的失败 Future 会反复阻止关窗和停用工作区，但并非“只能强制结束进程”；修复前成功执行一次新的密钥写入也能恢复。现在已确认的失败不再阻止关窗；结果仍未知时必须重新确认，不能简单吞错放行。
- **第 3 项**：UTC 存储数据的候选索引缺陷成立，但“正常 ICS 导入”不是准确触发路径：现有 ICS 导入器会转换成本地时间。修复针对持久化 UTC／偏移时间数据，不修改 ICS 或历史 occurrence key 的语义。
- **第 4 项**：原来恢复前台可以补做一次通知对账，但不会重新建立提交／Intent 订阅；并非所有通知能力彻底永久失效。现在超时后的就绪变化可恢复启动和订阅。
- **第 5 项**：原来的无条件跳周发生于 `_saveAndNotify` 失败，不包括所有保存入口。
- **第 6 项**：失败修改重新出现可复现，但“重启也不会重排通知”不准确；新启动的协调器原本就会初始对账。问题在于已报告失败的快照仍参与自动恢复，以及同进程重新加载不一定发布提交。
- **第 7、8 项**：通过故障注入和受控保存时序确认，不再仅归类为代码推测。未将测试替身故障冒充真实杀毒软件占用或真机通知实验。
- **第 9、10 项**：属于维护清理，不作为已发生的用户功能故障。修复优先级也不应只关注第 1、2 项，第 4、8 项同样重要。

### 已实施变更

| 项目 | 结果 | 实施与回归保护 |
| --- | --- | --- |
| 1 | 已修复 | 日期选择改用 `copyWith`；普通导航、自定义范围清除后列宽保持 160，并确认持久化值。 |
| 2 | 已修复 | 关窗和停用工作区复用稳定密钥队列确认；已知失败可继续，未知结果需读回，写入代次防止旧读回覆盖新值。 |
| 3 | 已修复 | 日／周／月及自定义间隔的起始索引统一查询边界时间表示；保留次数、截止日期及 ICS 本地化行为。 |
| 4 | 已修复 | 保留单次 15 秒启动上限；事件驱动恢复启动，不重复订阅，遵守显式就绪门禁，释放后不再启动。 |
| 5 | 已修复 | 同一活动课表保持选中周，仅在身份变化或周次越界时校正；普通日程保存失败保留第 12 周。 |
| 6 | 已修复 | 分阶段校验并撤回失败写入；失败副本隔离为恢复产物，不参与正常提升。回滚失败使用 `StorageWriteStateUnknownException`、只读门禁和 26 个语言资源中的明确提示；保护较新文件及唯一恢复副本。 |
| 7 | 已修复 | 栅栏激活、读取和完整投影位于统一错误边界；单次自动重试携带原任务权限、快照和 revision；新提交／清除／释放使旧任务失效。 |
| 8 | 已修复 | 默认投影只读 `committedAppData`；暂停保存期间恢复前台不再排出未落盘事件，失败后不残留该通知。 |
| 9 | 已清理 | 路由、详情和 handled 同步共用只读 `resolveNotificationOccurrence`；统一 key 时刻搜索，保留各入口校验和无 key 导航。 |
| 10 | 已清理 | 删除 9 对相邻重复检查及同步路径中的其他冗余检查，共删除 28 处；保留跨 `await` 的检查。 |

新增正式回归集中在 [test/review_regression_test.dart](test/review_regression_test.dart)，跨时区用例加入 [test/date_dst_regression_test.dart](test/date_dst_regression_test.dart)。临时核验中原先断言错误现象的用例已改写为正式测试中的正确行为断言。

### 验证结果与限制

- **完整测试**：`flutter test --no-pub --coverage`，3395 项通过、1 项按现有规则跳过；跳过项是未指定环境变量时的命名时区入口。
- **核心回归**：独立运行 Provider、协调器、路由、磁盘存储、恢复矩阵和 Repository 相关测试，192 项通过。
- **原始复现**：原报告的 2 条临时复现现在均通过，列宽为 `160 → 160`，本地 `07:30` 的 UTC 实例可被找到。
- **时区专项**：上海整组 18 项通过；新增混合时间表示的 4 个场景分别在固定 UTC−5、UTC+1 下通过。Windows 的 `TZ` 不能准确模拟纽约／柏林 DST，未宣称本机完成这两地完整 DST 验证；对应场景已纳入现有 Linux CI 时区入口。
- **静态与生成检查**：`flutter analyze --no-pub` 无问题；本轮 Dart 文件格式检查、`git diff --check` 通过；重新生成本地化文件后内容不变。
- **覆盖率门禁**：以独立的 Store 提交为基线，整体 `39349/43058 = 91.3860%`，本轮改动行 `290/300 = 96.6667%`，通过现有整体门槛与 90% 改动行门槛。
- **Windows 构建**：隔离烟测入口与正式 `lib/main.dart` 的 Debug 构建均通过；已恢复正式入口调试产物。第三方 WebView 插件的 CMake／MSVC 警告未纳入本轮无关修改。
- **Windows 原生烟测**：使用纯内存课表、密钥、学校站点与恢复日志，不读取真实用户课表。实际启动 Windows runner，日期导航后列宽仍为 160；注入密钥失败后，外部向该测试进程发送原生 `WM_CLOSE`，触发关闭回调并获准关闭，进程退出码为 0。此项是原生关窗与导航烟测，不等同于完整鼠标交互端到端测试。
- **尚未执行**：Android 真机通知投递／点击，以及真实磁盘满、杀毒软件占用实验。相关逻辑已做单元、组件与受控故障回归；平台限制不能用替身测试代替宣称通过。

### 提交与发布边界

微软商店批次已独立提交为 `fec74b55f2b6ddd7fe193737a1729d573167751c`（`feat: 支持 Microsoft Store 分发和商店更新`）；本报告与十项修复作为后续独立提交。按照后续用户要求，本轮会做本地 commit，但不 push。

AppData／备份 JSON schema、通知 payload 格式、应用版本与依赖声明均未调整。本轮没有新建或上传 Microsoft Store MSIX 包；之前的商店提交包尚未包含本轮修复，需要后续重新打包才能发布这些修复。
