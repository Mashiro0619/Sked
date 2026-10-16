# Sked 全项目重构实施报告

本轮从 `77061b4172efdfac2c7cdd30f0b4953b6be31004` 开始，目标是在保留 Windows、Android 用户流程、存档兼容和编辑草稿的前提下，拆分共享状态与平台服务，减少无关重建和重复计算，并整理重复测试与采集入口。

本文记录截至 `d328a174e4047438feae79950b9b782c5fc2876c` 的实现，更新于 2026-10-17。本区间为 129 个本地实现提交；四份文档汇总提交单独记录。最终滑块保留独立 Semantics、全局 Overlay 和完整单表单 SingleChildScrollView，57 项定向、4 边缘全 RGBA 与完整 UI66 正确性通过。Source 9 步通过，完整 VM 为 4,861 通过、1 跳过；Android、Linux 专项、Web、Windows Native/Chrome/Packages 均已有终态。正式 UI60 60+3、Host11 11 项可比；编辑六次运行已完成，但 before AX 使数值比较 invalid，after 36 动作与读回 / 0 AX 单独保留。**Android 真机、具备通知隔离的整进程冷启动和无 AX 错误的原版编辑对照仍缺证据；压力长帧与内存回退仍存在。** 各类结果保留实际源码和运行边界。

## 计划覆盖与实现边界

| 计划项 | 已落地实现 | 主要证据 |
| --- | --- | --- |
| 共享状态拆分与明确依赖 | `AppSession` 持有唯一可写的当前快照；课表、日程、设置、工作区分别提供命令与只读视图；`AppScope` 注册领域实例 | `246a6f9`、`eaf8cfb`、`2a3596b`、`b1f490b`、`559b7d5`、`4276e92`；会话、领域发布、作用域与界面隔离回归 |
| 持久化、恢复、生命周期 | 维护预约、延迟保存、默认数据、备份恢复、加载、清除、退出和密钥写入分别有明确所有者 | `f1b58ab`、`9b0124d`、`8375449`、`16e41f8`、`b7b8e9c`、`f653133`；恢复、未知写入状态、保存竞争与退出回归 |
| 编解码与数据模型 | 原生存档编解码和导入预处理移到计算 isolate；严格存档校验与模型分离；普通变更只校验涉及分支并复用未变对象 | `0d67b98`、`da1b01a`、`40ca12b`、`18fe814`、`2841672`、`a1411f5`；编解码、增量模型与持久化不变量测试 |
| 日程、课表渲染与查询 | 浏览日期保留事件查询缓存；月、列表、时间轴使用只读投影；课表复用周投影与日期列布局；月页、文字测量和像素网格复用 | `350ea1f`、`3a15260`、`cd2707e`、`70ab36c`、`a36091e`、`0b23437`、`2e2cf7c`；投影、缓存失效、DPR/RTL、几何与真实交互测试 |
| 编辑、导入与跨路由归属 | 课程和事件入口复用任务控制器；异步解析、确认、保存绑定目标与会话；跨 Navigator 保留同一领域实例 | `0eec1f1`、`6200bbb`、`0adbe4f`、`ba31c14`、`426df37`、`8316388`、`80989cc`；草稿、晚返回、重复点击与失效恢复测试 |
| 通知分层与重排范围 | 通知契约、身份、内存/原生网关、文案、载荷、后台处理和运行存储分离；协调器按耐久提交的相关领域筛选重排 | `755a2ea`、`2f8ad0e`、`cbc357a`、`690bdb6`、`357275c`、`2222b7e`；身份、去重、锁顺序、后台动作与排程测试 |
| 测试、CI 与采集整理 | 合并等价夹具，删除转发层自证测试和重复采集入口；37 个历史脚本改为统一选择入口；CI 只测当前提交，覆盖率作为诊断附件 | `844d59b`、`86ccb0c`、`b35809e`、`44bc4ad`、`55371aa`、`73d1a80`、`6ca27c3`、`d8cd94f`；替代测试与删除理由见下文 |
| 可比性能与最终验收 | 既有磁盘 30 动作保留；正式 UI60 两端各三进程得 60+3 可比项，Host11 得 11 项；当前完整 UI66 为 66+3 / 0 AX 正确性运行 | 编辑 before AX 199/204/201 导致 invalid、0 比较；after 36 动作与读回 / 0 AX 保留。各本机平台阶段已完成，历史错误不删除或改标签 |
| 无障碍回归修复 | 保留日期标题/liveRegion；稳定画布关闭动作与子控件语义；最终 Slider 保留独立 Semantics、全局 Overlay，完整单表单的离屏锚点稳定且 hidden | `ce915f5`、`fb1ef2a`、`57751c2`、`d328a17` 的对应流程；旧局部/page Overlay 均废弃，新设计有独立 57 项、4 边缘和完整 UI66 证据 |

## 最终运行时与数据所有权

`4276e92` 完成最终 124 个路径的组装切换，删除此前仍有 **1015 行**的 `lib/providers/timetable_provider.dart`。此前课表、日程、设置、生命周期和开发者业务 mixin 已分别移出并删除。

新的 [AppRuntime](../lib/app_runtime.dart) 是 `final`、非 `Listenable` 的组合根，公开表面只含构造、19 个领域字段和 `dispose`。它没有业务转发 getter/method、全局通知、数据复制入口或旧符号重导出。稳定视图的发布器在构造内部连接各领域；`dispose` 保持幂等，触发待保存状态的收尾并释放同一组实例。显式退出时等待写入完成的职责保留在 `AppShutdownController.quiesce` 和 AppBootstrap 的退出顺序中。

| 职责 | AppRuntime 公开字段 |
| --- | --- |
| 会话、维护与保存 | `session`、`maintenance`、`persistence` |
| 学生课表 | `studentView`、`studentCommands` |
| 通用日程 | `generalView`、`generalCommands`、`generalNavigation` |
| 工作区 | `workspaceView`、`workspaces` |
| 设置与密钥 | `settingsView`、`settingsCommands`、`schoolImportSecrets` |
| 传输与备份 | `transfers`、`backups` |
| 生命周期与操作 | `lifecycle`、`dataClear`、`shutdown`、`developer` |

[AppScope](../lib/providers/app_scope.dart) 注册 19 个领域实例及独立 readiness 桥，已移除全局 `ChangeNotifierProvider<TimetableProvider>`，也没有 `Provider<AppRuntime>` 订阅入口。捕获的作用域在跨路由时复用同一实例，实例生命周期仍由应用所有者管理。启动入口为 `AppRuntimeFactory`、`AppBootstrap(runtimeFactory: ...)` 和 `MyApp(app: ..., dataReady: ...)`。

[AppSession](../lib/controllers/app_session.dart) 管理当前快照、变更代际、写入状态和已接受快照的提交事件。各领域命令不持有另一份可写 `AppData`。仓储成功接受写入后才发布 [AppDataCommit](../lib/models/app_data_commit.dart)；失败回滚继续尊重变更代际、恢复写门禁与运行时密钥覆盖层。`AppSessionReadiness` 独立发布加载、可写和未知写入状态。

`AppDataVersions` 分别记录 `student`、`general`、`settings`、`agenda`、`dataSession`。无关显示与浏览提交不会触发提醒重排；语言、提醒设置、工作区可用性以及有效课程/事件变化仍计入 `agenda`。通知继续消费耐久快照。

工作区与日期导航事务继续隔离尚未稳定的状态。就绪/写门禁单独发布，各只读视图比较自己的输入后通知订阅者；界面回归验证了无关领域变化时原控件身份保留，以及所属课程/日程变化后的实际刷新。

最终切换前，723 个 Dart 源文件经过接收者类型扫描，剩余业务成员迁移数为 0。最后两个全局监听点属于旧门面自身和 AppScope 的旧注册，已随最终切换删除。120 个调用方的最后变更限定为类型、导入和组装参数；测试名称与可执行字面值保持一致。

## 计算、查询与任务流程

[AppDataCodec](../lib/data/app_data_codec.dart) 与 [DataTransferCodec](../lib/services/data_transfer_codec.dart) 承担存档、课表、日程 JSON/ICS、备份与加载规范化等纯计算。原生默认仍使用 `compute`。解析候选只携带数据，合并、维护预约和耐久写入保留在当前会话中；预览确认复用已解析候选，避免重复解析。

[严格存档校验](../lib/models/app_data_storage_validation.dart) 保留在读入、导入与恢复边界。普通命令维护所修改分支的不变量，未变课程、日程和索引对象继续复用。AppData v4 与已有备份格式继续兼容；恢复门禁、失败回滚、停用工作区保留数据以及密钥不入普通备份的边界继续由专门测试覆盖。

日程查询、月页、列表、时间轴和课表周投影分离了稳定输入与动态呈现。日期浏览可以保留原事件集合；视图缓存根据所属数据与布局输入失效。月页位移不再要求每帧重新建立整页子树，文字测量与物理像素布局单独复用。课程实时描边仍保持独立更新。这里记录的是实现方式，速度收益以同协议的重构后测量为准。

`CourseTaskController` 与 `GeneralEventTaskController` 统一主界面、提醒和通知详情的编辑提交归属。维护状态、目标存在性、工作区可用性与会话代际分别参与失效判断。原生文件选择前捕获会话；晚解析、备份确认和模型列表请求只处理所属任务。保存完成时只关闭所属路由，保留其上新打开的编辑草稿。相关修复分别落在 `8b82316`、`f8a508a`、`9951b28`。

通知服务拆分后保留原 Android 后台入口的文件 URI、顶层函数名和 entry-point pragma，保留持久化身份与存储键、锁顺序和去重栅栏。内存网关与诊断编号分配不再混入原生实现。普通 VM 回归不替代 Android/Windows 系统通知行为验收。

## 删除、合并与测试取舍

| 删除或整理 | 理由与保留的验证 |
| --- | --- |
| 旧 `TimetableProvider`、五个业务 mixin、任务会话兼容参数 | 真实调用方已使用领域接口。最终组合没有全局业务门面；领域发布、作用域、生命周期、保存/恢复与界面回归替代对旧全局通知的依赖 |
| `SchoolImportApplyService` 转发层及其注入式自证用例 | 原层只转交应用请求，已由真实学校导入工作流及课表业务命令处理；保留实际导入行为测试 |
| `TimetableJsonImportService` 与单独测试文件 | 由异步候选接口替代。携带节次、完整/空/旧格式等有效案例移入 `data_transfer_codec_test.dart`；界面继续验证晚解析与会话失效 |
| `tool/coverage_base*`、`tool/coverage_gate*` 及四个配套工具测试 | 删除覆盖率百分比门槛和为门槛检出基准重跑的流程。当前源码的完整 VM 测试仍是 CI 阻断项，LCOV 保留作诊断；workflow 与结构化平台安全测试继续验证配置行为 |
| 根级重复夹具与混杂回归 | 等价内存存储收敛为共享测试支持；模型解码、服务行为、日期/学期和几何案例回到对应测试文件。序列化、失败、门禁、计数和延迟写入的专用夹具保留 |
| 历史视觉采集入口 | 前期删除三个重复入口并保留有效场景；`d8cd94f` 将其后现存的 37 个独立脚本归入按功能命名的模块，由一个 `SKED_CAPTURE_SCENE` 入口选择，40 个 `testWidgets` 注册和原生指针保护均保留；既有 32 张公开截图未改写 |
| `windows_notification_config_test.dart` 的字符串断言 | 相同通知身份和配置已有结构化平台配置、CI 契约与后端行为验证，删除重复的源文本匹配 |

测试修订保留了数据、回滚、草稿、可访问性树、布局及真实用户操作的断言。用实际存储/维护预约替代全局 `notifyListeners()` 和可覆盖的门面假对象；仅改变依赖组装的批次与行为修复分别验证、提交。重构后的测试通过数不与旧总数相加，也不以删除行数判断质量。

补充整理的当前检查点如下，状态不扩展到未执行的平台行为：

| 补充项 | 当前状态 | 结案需要 |
| --- | --- | --- |
| 共享简单存储夹具 | `ab9613b` 已签名；12 文件删除 11 个重复普通类，15 个调用点保留原 `memory://` 路径；专用故障夹具保留 | 与测试归属调整合并验证，500 项通过 |
| 原 provider 测试归属 | `ba7c5ff` 已签名；18 个文件移至 `test/controllers`，移动时文件字节哈希保持一致；相关文档引用同步 | 与夹具整理合并验证，500 项通过 |
| 提交钩子批量检查 | `7bd7940` 已签名；批量检查暂存快照并保留逐项失败定位 | `pre_commit_hook_test.dart` 的 2 项行为测试通过 |
| 原生采集入口统一 | `d8cd94f` 已提交；37 个入口、40 个 `testWidgets` 的迁移完成，61 个相对导入目标保持一致；`mobile-calendar-grids` Windows 原生冒烟通过，48 张 PNG 与 manifest 已生成 | 不代表其他 36 组都重新运行；公开文档图片仍由独立文档入口维护 |
| 原生 AX 诊断与修复 | r6/trace1 确认 batch 26 的原生 reparent 丢失 tooltip overlay 351/352；最初单层 container 候选合并子控件，已废弃。`fb1ef2a` 的独立子控件候选完成 27 步 MSAA、0 AX/graph 错误 | isolated 原报告保留提交前 revision；`canvas-isolated-validated-hashes.json` 的两文件哈希对应到 `fb1ef2a`，不能将已废弃 stable 候选或诊断截断过程算成此通过 |
| 真实磁盘测量 | `206e307` 的 8 动作基础与 `4492184` 的 JSON/ICS 扩展已提交；Debug 原生全规模通过，前后两版各 3 × 30 动作的 Profile 比较也通过数字、输入、公共源码、运行环境/协议及启动回执校验 | [全部 30 项附表](PROJECT_REFACTOR_DISK_PERFORMANCE.md) 保留每项耗时/RSS/写入数和 6 份原始报告的路径/SHA；原始重复值与 JSON Pointer 在配套 summary 中 |
| 真实编辑测量 | `1205c6e` 的 3 × 4 动作 Debug 原生冒烟通过；`94d7c4c` 输入修复的提交前候选又完成 1 个 Profile 进程、3 规模 12 动作，`validation=passed` | 历史 pilot 保留 `1205c6ed0816` 与源码哈希；后续 v2 六进程已完成，before AX 使数值比较无效，after 正确性另列 |
| 日期选择器语义 | `ce915f5` 修复标题文本、保存 liveRegion 与提示语义，103 项定向回归通过 | 此后 d328a17 完整 VM 已为 4,861 通过 / 1 跳过；原定向结果不重复计入 |
| 原生工具推广 | `57751c2` 已提交五文件；live 路径 27/27 阶段、68 updates、5 次 MSAA、0 AX/graph、退出 0 | 原报告保留 precommit `01a98c534031`，工具文件按验证哈希关联提交；不将当时运行重新标为纯 HEAD |
| 设置滑块最终修复 | `d328a17` 保留独立 Slider Semantics 与全局 Overlay；无 headerSliver 的完整单表单从 ListView 改为 SingleChildScrollView，离屏锚点保留且 hidden | 57 项针对测试、4 个边缘全 RGBA 对照、完整 UI66 66+3 / 0 AX；局部/page Overlay 的失败仅留作历史诊断，不用于当前设计 |
| 独立工作区测量 | `ef1aea3` 提交 UI60 协议与入口；6 项 widget 冒烟和原单进程 pilot 有各自来源，正式 d328a17 系列完成双方各三进程、60+3 可比项 | 原 pilot 保留 `4169dc72313d`，不混入正式样本；[UI/Host 性能报告](PROJECT_REFACTOR_UI_PERFORMANCE.md) 保留正式数值、退化和来源 |

## 当前验收结果与历史证据

| 检查 | 当前结果 | 范围与来源 |
| --- | --- | --- |
| Source | d328a17 共 9 步 exit0；完整 VM 4,861 通过、1 跳过 | SDK、两份锁文件、插件/主分析、本地化、格式、VM 和 diff；原始阶段回执与 LCOV 归档保留 |
| 设置与滑块 | 57 项定向通过，4 个边缘全 RGBA 对照为 0 差异、容差 0 | 独立 Semantics、全局 Overlay、完整单表单 SingleChildScrollView；widget-raster 不冒充原生截图 |
| 当前完整 UI66 | 3 规模、66 actions + 3 mounts、0 AX、原生/框架语义稳定 true | 原报告保留 ef1aea31ed79，六文件候选映射 d328a17；一进程完整正确性与正式性能比较分开 |
| 最终 Windows MSAA | d328a17 明确预构建目标，27/27 阶段、69 updates、5 probes、28 buttons、2 text checks，graph/AX/fatal 均 0 | 三个编译快照前后哈希一致；实际进程/探针与报告完整，integrationPluginWarning=true 保留，不是设备或安装验收 |
| Android | 5 步 exit0；APK/AAB 归档 SHA/大小已复核；JVM 10 项、0 failure/error/skip | sidecar 核对任务行与 XML 时间窗口，支持 JVM 本次执行；原回执 CRLF 捕获缺项未被覆盖，真机未验收 |
| Linux 专项 | checkout/时区/Chrome 共 3 步 exit0；纽约/柏林/上海各 18 项、Chrome 租约 4 项 | 新源码 d328a17 与归档日志已核对；没有 Linux native build |
| Windows Chrome | 任务内工具适配后，同一实例租约测试 4 项通过 | 原版 CLI 在浏览器启动阶段失败；只改工具副本一个文件两处 URI path，全局 SDK、应用和测试源保持原样 |
| Web Release | 默认 JavaScript Release 构建 exit0，index.html/main.dart.js 归档 | CupertinoIcons 字体族扫描提示保留；Wasm 仅 dry run，没有实际 Wasm 或页面视觉验收 |
| UI60 / Host11 | 两端各 3 进程；UI60 60+3、Host11 11 项可比 | 完整数值、长尾与回退见 UI/Host 附表；与旧 pilot、UI66 不混用 |
| 真实编辑 | 六次运行完成；before AX 199/204/201，invalid、0 数值比较 | after 三进程 36 动作、独立读回和 0 AX 仅作新版正确性证据 |
| 既有 Disk30 | 原版/1205c6e 各 3 进程，30 项可比；24 项耗时中位下降、6 项上升，max RSS 中位 +3.01% | 最新工具离线复算与原结果一致；不把 after 改成 d328a17 或声称重新采样 |
| 最终 Windows 包 | d328a17 两次 Release 重建、Unsigned/Store MSIX 与归档 Store verifier 全通过 | 新包身份/版本、三份 payload、归档 SHA 均经独立复核；未安装、WACK 或发布，94d7c4c 包只保留历史 |

较早批次用于说明重构过程：4276e92 的 522 项领域/运行时回归、基准适配的 324 项、夹具/归属整理的 500 项与提交钩子 2 项，均不与当前全量相加。旧 4492184 全量的 4,848/1/6 已由日期语义修正及本次最终 VM 结果承接。d8cd94f 的选定采集组生成 48 PNG，40 个 selector 注册和 32 张公开 JPEG 的保留范围仍沿用原记录，没有宣称重跑所有截图组。

[最终 Windows 包回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-d328a174e4047438feae79950b9b782c5fc2876c/windows-packages-20261016T175255916Z/receipt.json>) 记录 4 步 exit0、12 次 source-clean 检查。Unsigned/Store 分别为 Mashiro.Sked 2.3.0.17 与 Mashiro0619.Sked 2.3.17.0；Publisher、x64、AppId sked、Toast CLSID、internetClient/runFullTrust 和签名缺席均核对。Unsigned 在 Store 重建前归档，两包的 sked.exe、app.so、engine 均对应各自 Release。新归档 SHA 为 `3a038f5e8ff4fe41a0f1885915fd0cdac4338b68909da9fc3cb1080f957a302e` 与 `5775c7a335190e84d237e3f97e6e1e7935ec77e63f0748bf35a4ff27379b8dc7`，独立 ZIP/payload 重算与原回执一致；没有安装、WACK 或发布。

历史批次日志继续保存在 `.scratch/refactor-20261014/`，当前 Source 全量日志已生成，不再以旧定向结果代替。复测协议见 [UI66](../benchmark/UI_PERFORMANCE.md)、[磁盘操作](../benchmark/DATA_OPERATIONS.md)、[真实编辑](../benchmark/UI_EDIT_PERFORMANCE.md) 和 [可靠性指南](RELIABILITY_BASELINE.md)。

初次 WSL 回执 [wsl-readonly-94d7c4c.json](<D:/Project/Flutter/sked/.scratch/refactor-20261014/acceptance-audit/wsl-readonly-94d7c4c.json>) 和旧 `ba31c14` Linux 日志保持历史来源。主代理后来准备锁定 `d328a17` 的源码副本，完成 [Linux 阶段](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-d328a174e4047438feae79950b9b782c5fc2876c/linux-20261016T152036849Z/receipt.json>)：3 步 exit0，纽约/柏林/上海各 18 项，Linux Chrome 租约 4 项通过；归档日志 SHA 已核对。任务 Chrome 的初次准备、版本/headless 探针和这次项目测试分别见 [Chrome 说明](<D:/Project/Flutter/sked/.scratch/refactor-20261014/acceptance-audit/CHROME_PREPARATION.md>)。没有运行 Linux native build，不把 SDK/engine 缓存或测试通过视为原生产物构建证据。

[Android 阶段回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-d328a174e4047438feae79950b9b782c5fc2876c/android-20261016T151208801Z/receipt.json>) 的 5 步全部 exit0。APK SHA 为 `9f5b0b8010c59fe0c781454fa024e96bec08b61d85b3f2f53cd032109bbfd656`，AAB SHA 为 `2c86d782943da9f98ca5d7b6dfbd36b5842e93abfb0bba870f3dd24b5e1a3e31`，归档大小和哈希已独立复核。JVM 的原 receipt 保持不变；[执行审计 sidecar](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-d328a174e4047438feae79950b9b782c5fc2876c/android-20261016T151208801Z/jvm-execution-audit.json>) 记录日志第 449 行为裸 `> Task :app:testDebugUnitTest`，无 UP-TO-DATE/FROM-CACHE，XML 内嵌 15:14:28.204Z/.310Z、写入 15:14:29.500Z，均在 JVM 的 15:13:34.3250790Z–15:14:29.8676564Z 内；10 项、0 失败/错误/跳过，支持 JVM 测试任务本次执行。旧解析器在 CRLF 前漏匹配状态行，空数组不能直接证明未用缓存；后续 scratch 脚本已修正，但没有重写已保存结果或把其他 Gradle 任务也称为 fresh。

[Web 阶段回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-d328a174e4047438feae79950b9b782c5fc2876c/web-20261016T152611846Z/receipt.json>) 为默认 JavaScript Release 构建成功，归档 index.html 与 main.dart.js。日志中的 Wasm 成功只属于 dry run，CupertinoIcons 字体族扫描提示保持记录；没有发布 Web 产品或声称实际 Wasm/页面视觉验收。

[最终 Windows Native 回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-d328a174e4047438feae79950b9b782c5fc2876c/windows-native-20261016T174146441Z/receipt.json>) 固定 d328a17 和实际预构建目标，完成 27/27 阶段、69 次语义更新、5 次 MSAA 探针（同 PID 62528）、28 个按钮和 2 项文本检查；graph、AX、fatal 均为 0。三个编译产物与保留快照的运行前后哈希一致。日志的 integrationPluginWarning=true 保持原样；实际 MSAA/report 完成证据已经核对，不靠该警告或驱动出口单独判断成功，也不扩大为物理输入/安装验收。

[Windows Chrome 成功回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-d328a174e4047438feae79950b9b782c5fc2876c/windows-chrome-adapted-20261016T154115565Z/receipt.json>) 记录同一租约测试 4 项通过、exit0。原版 Flutter 3.47.7 CLI 在测试断言前因 Windows URL 路径转换导致 CanvasKit 404 和错误 selector，[原失败/CDP 诊断](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-d328a174e4047438feae79950b9b782c5fc2876c/windows-chrome-20261016T152856475Z/browser-startup-diagnostic.json>) 保留。[任务内适配清单](<D:/Project/Flutter/sked/.scratch/refactor-20261014/windows-web-tool/adaptation.json>) 仅把工具副本 `flutter_web_platform.dart` 的两处 fromUri 改为 request.url.path，并重定位 package_config；两处精确替换、原全局 SDK 文件和适配文件哈希已核对。应用/测试源与全局 SDK 未修改，因此结论限定为适配后 Windows Chrome 通过。

历史原生诊断保留在各原始工件和交接 manifest：fb1ef2a 的 isolated 与 57751c2 的推广流程各保留提交前 revision，不替代当前 69-update 流程。旧 canvas-stable 因合并子控件被废弃；4169dc7 局部 Overlay 的八组位置对照未覆盖 [顶部 871 像素裁切](<D:/Project/Flutter/sked/.scratch/refactor-20261014/slider-indicator-edge.log>)，后续页面 Overlay 候选又有 [25 通过 / 2 失败](<D:/Project/Flutter/sked/.scratch/refactor-20261014/slider-route-overlay-tests.log>)。两类 Overlay 均不是当前设计；旧 26+2 项和 sparse 诊断只保留历史范围。

最终候选通过 [57 项定向回归](<D:/Project/Flutter/sked/.scratch/refactor-20261014/settings-finite-form-final.log>)；[四边缘对照](<D:/Project/Flutter/sked/.scratch/refactor-20261014/slider-finite-viewport-edge.log>) 对相同全局 Overlay 的 ListView/SingleChildScrollView 比较每个完整场景像素，4 项均 `identical-rgba`、通道容差 0、内/边界/外/总差异 0，几何和偏移相同。曾被裁掉的 871 像素在两侧均完整保留，不能将此新证据与旧局部 Overlay 的八组位置对照混用；这仍是 widget-raster 验证。

[完整 UI66 原报告](<D:/Project/Flutter/sked/.scratch/refactor-20261014/ui66-finite-form-ef1aea3/ui-performance-finite-form-candidate.json>) 记录三个规模的 66 actions + 3 mounts，四个语义起止状态 true 且期间无变化；[完整 stdout](<D:/Project/Flutter/sked/.scratch/refactor-20261014/ui66-finite-form-ef1aea3.log>) 与 stderr 没有 AXTree 拒绝，驱动完整通过。原报告保持 `ef1aea31ed79`、harnessVersion 2、`profile-engine-frames`；该 UI66 格式未写 validation 字段，不补写或套用 UI60 schema。[六文件候选哈希](<D:/Project/Flutter/sked/.scratch/refactor-20261014/ui66-finite-form-ef1aea3/candidate-hashes.json>) 与对应 patch 关联到 `d328a17`，这只证明候选来源，不将该次运行重标为纯 HEAD。一进程完整正确性仍不是正式性能六进程比较。

原始 UI 协议由 `5e7213c` 的测试 harness 接到未修改生产代码的 `77061b4`。当前领域版 harness 不能原样覆盖到旧源码。数据、动作、帧计算与测量窗口保持一致，才能比较组装适配前后的报告。正式 Profile 保留原生计算与 450 ms UI 状态保存延迟；只有标为 `widget-smoke-only` 的假时钟测试注入内联 codec。

真实编辑协议必须使用同一个共享场景文件及各自的薄适配器。固定压力课表的首记录可能被同时间课程覆盖，因此选择同一首时段最后绘制的课程，并在显露区域做命中检查后真实点击。日程使用 `layoutTimelineEventColumns` 排序后的第一重叠组首列，首列不会因窗口宽度折叠；不能直接取数据查询的第一个短事件。课程 ID、点击 alignment、日程 ID、发生时间与重复编辑范围写入报告，任何前后目标差异都使该比较无效。此修正只改变基准目标选择，不改变生产排序、夹具或用户行为。

正式报告保留各自测量格式：旧 UI66 的 `profile-engine-frames` 没有 validation、input SHA 或 PID，不能回填；磁盘 30 和编辑 12 要求 validation=passed，携带规范化输入指纹，磁盘另有 JSON/ICS 指纹。UI60/编辑 v2 记录真实 AppHomeScreen 宿主、原生/框架语义起止状态和 observedChanges；正式 d328a17 系列已保存两端各三进程的启动、退出、预构建产物快照与来源。语义端点稳定不能豁免实际 AX 日志，编辑 before 因此被拒绝。不同文件名或时间戳本身不证明独立进程。

帧分位数按每个进程分别计算，再对三个进程作汇总，不把全部帧混合后当三次独立重复。超预算比例按 build 或 raster 任一阶段超过实际刷新间隔计算；RSS 是整个进程驻留量。UI 滚动报告的偏移和滚动范围属于观测值，不能被当作固定输入哈希；缺少帧、未完成交互或输入/目标不一致都必须在比较前拒绝。

### 已完成的磁盘 Profile 比较

<!-- DISK30_SUMMARY_START -->
原始 `77061b4172ef` 与当前 `1205c6ed0816` 各运行三个独立 Windows Profile 进程，每个进程覆盖 sparse、1,000、5,000 三个固定数据规模的 30 个动作。比较器已通过数字、输入/公共源码哈希、运行环境/协议和启动回执检查；30 项中 24 项墙钟中位数下降、6 项上升。

文档现已同步到 `d328a17`，上述 after 数值仍属于 `1205c6e` 实测。后续比较器对同六份磁盘报告复核，仍为 30 项可比且 comparisons 与 processMetrics 不变；最新 UI60/预构建准入的 45 项检查属于离线工具验证，不增加采样次数。

以下是各动作三次墙钟耗时的中位数，单位 ms，箭头表示原始版 → 当前版，括号为变化率。这些动作从业务命令计到耐久完成，尚不能表示真实 UI 编辑耗时或帧性能。

| 操作 | sparse：24 事件 | 1,000 事件 | 5,000 事件 |
| --- | ---: | ---: | ---: |
| 保存课程 | 24.801 → 17.311 (-30.20%) | 417.480 → 70.001 (-83.23%) | 1,996.654 → 295.915 (-85.18%) |
| 保存日程 | 29.903 → 17.574 (-41.23%) | 554.288 → 81.508 (-85.30%) | 2,648.054 → 366.086 (-86.18%) |
| 修改设置 | 31.034 → 19.584 (-36.90%) | 447.168 → 88.123 (-80.29%) | 2,053.273 → 363.880 (-82.28%) |
| JSON 导入 | 47.000 → 29.078 (-38.13%) | 1,372.753 → 573.769 (-58.20%) | 6,763.199 → 2,872.068 (-57.53%) |
| ICS 导入 | 58.026 → 34.169 (-41.11%) | 1,691.745 → 781.065 (-53.83%) | 8,429.434 → 3,916.695 (-53.54%) |

六项回退全部来自磁盘加载与备份导出，不能写成全链路更快：

| 操作 | sparse：24 事件 | 1,000 事件 | 5,000 事件 |
| --- | ---: | ---: | ---: |
| 磁盘加载 | 28.357 → 29.584 (+4.33%) | 709.266 → 733.352 (+3.40%) | 3,421.467 → 3,656.095 (+6.86%) |
| 备份导出 | 3.215 → 3.656 (+13.72%) | 11.208 → 19.697 (+75.74%) | 58.406 → 83.450 (+42.88%) |

进程最大 RSS 的三次中位数为 434.191 → 447.250 MiB（+3.01%），不能宣称内存全面下降。各动作的 RSS 增减也不是分配量或该动作的峰值。三次重复只是描述性结果，不说明统计显著性或单一代码变化的因果作用。

[完整 30 项附表](PROJECT_REFACTOR_DISK_PERFORMANCE.md) 保留课表导入、恢复和退出 flush 等其余动作，以及六份原始报告的路径/SHA、逐项 JSON Pointer、每轮值和启动证据。磁盘 load 在建种子后测量，OS 页缓存可能已热；上述结果不是整进程冷启动、UI 帧率或原生无障碍验收。
<!-- DISK30_SUMMARY_END -->

### UI Profile 协议与历史来源

旧 UI66 三次 before 和 `ui-after-v2-home-pilot` 保持诊断用途，后者有 5,211 条 AX 拒绝，驱动 exit0 不能准入。当前协议与源码已经冻结并完成新的正式采样；旧 before、旧 pilot 和当前 UI66 正确性运行均未混入 UI60/编辑正式总体。

已提交的 [UI60 协议](../benchmark/WORKSPACE_PERFORMANCE.md) 为独立 `workspace60-v1`，measurement=`profile-workspace-engine-frames`，suite=`ui60`，复用 native frame harness v2、真实 AppHomeScreen、原 fixtures 与 metrics；设计与两端适配见 [协议工作目录](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/workspace60-protocol/README.md>)。它排除 `settings.general.toggle` 及进入/关闭设置的步骤，保留 10 场景 × cold/warm × 3 规模，共 60 项及另列的 3 个 mount。两端都必须新采三个独立进程并全程 0 AX，不能裁剪或重标旧 UI66；其 warm 前序不再经过设置开关，也不能与 UI66 warm 混比。原始设置错误保留，当前完整 UI66 的三个规模已由上述独立运行验证；UI60 本身不承担设置、无障碍或整进程冷启动验收，也不与 UI66 重复累计覆盖。

`ef1aea3` 的六个协议/基准/测试文件已经提交，[widget 冒烟日志](<D:/Project/Flutter/sked/.scratch/refactor-20261014/ui60-widget-smoke.log>) 记录 6 项通过。首个 [UI60 pilot 报告](<D:/Project/Flutter/sked/build/benchmarks/ui-workspace-after-workspace60-pilot/r1/ui-workspace-performance-after.json>) 为一进程、3 规模、60 actions + 3 mounts，`validation=passed`，0 AX；原生/框架起止状态均 true 且 `observedChanges=[]`。原 revision 是 `4169dc72313d`，[provenance](<D:/Project/Flutter/sked/build/benchmarks/ui-workspace-after-workspace60-pilot/provenance.json>) 保留完整提交前 SHA、9 个 harness 原始哈希以及 build/r1 的启动、退出 0 回执。[六文件验证清单](<D:/Project/Flutter/sked/.scratch/refactor-20261014/ui60-validated-hashes.json>) 对应 `ef1aea3`；三个文件的 CRLF 原始字节与 LF Git blob 分别保存在 manifest，明确行尾规范化比较，不把运行重标为纯 HEAD。

性能代理的 [UI60/预构建准入回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/verification-ui60-v1.json>) 记录 45 项 stdlib 检查、9.904 s、退出 0，并完成独立静态审查；旧 pilot 仍为 `legacy-no-build-driver`，只作一进程正确性/诊断。[操作准备清单](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/operations-ready.json>) 固定显式应用二进制、sked.exe/data/app.so/engine 快照哈希与六进程相同启动模式。工具验证与主代理后来实际执行的正式采样分别计证据，不增加实测次数。

### 最终 UI60、Host11 与编辑采样

最终 UI/Host 数值、逐项退化和原始来源见 [UI/Host 性能报告](PROJECT_REFACTOR_UI_PERFORMANCE.md)。 60/60 个动作的 build P95 三轮汇总下降，但 9 项 build 最大值、20 项 raster 最大值、4 项动作耗时和 47 项结束 RSS 上升。5k warm 月页 build P95 从 2909.154 降至 0.332 ms，P99 仍为 222.816 ms；5k 工作区打开仍有约 2.1 秒长帧，独立挂载最坏接近 3 秒，不能据此宣称全部卡顿消失。原始系列位于 `build/benchmarks/ui-workspace-before-final-d328a17`、`ui-workspace-after-final-d328a17`、`host-before-final-d328a17`、`host-after-final-d328a17` 和对应 ui-edit 两个目录；这些与历史 pilot 分开保存。

| 正式系列 | 实际执行与准入结论 | 可使用的结论 |
| --- | --- | --- |
| UI60 | before/after 各 3 个进程，60 个动作比较与 3 类 mount 比较，status=comparable，全进程 0 AX | 只比较 workspace60-v1 的滚动/切换与对应挂载，不扩展到设置或整进程冷启动 |
| Host11 | before/after 各 3 个 host 进程，11 项比较，status=comparable | 纯数据 host JIT 指标，不能代替原生帧或实际 UI 体验 |
| UIedit12 | before/after 各 3 次运行；before AX 为 199/204/201，status=invalid、0 个数值比较 | after 三进程共 36 动作、独立磁盘读回和 0 AX 只证明新版相应路径正确，不能给出前后改善百分比 |

准入结果分别保存在 [UI60 summary](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/results-ui60-final-d328a17/summary.json>)、[Host11 summary](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/results-host11-final-d328a17/summary.json>) 与 [UIedit summary](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/results-uiedit12-final-d328a17/summary.json>)。每个系列的 manifest、源码审查、分布和运行回执保留在同一 performance-comparison 目录；不截取通过片段替代失败的编辑基线，不将 UI60 与完整 UI66 重复累计成更多独立覆盖。

最终验收清单与剩余项目：

| 验收项 | 已完成事实与保留边界 |
| --- | --- |
| 最终全量 VM 测试 | **已完成**：`d328a17` 为 4,861 通过、1 跳过，Source 共 9 步全部通过，见 [阶段回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-d328a174e4047438feae79950b9b782c5fc2876c/source-20261016T135646651Z/receipt.json>)；旧 4,848/1/6 和各批定向结果不加入新全量计数 |
| Windows 构建与包检查 | **最终重建和归档核验已完成**：d328a17 的 Unsigned/Store 两次 Release/MSIX、身份/payload 检查与归档 Store verifier 通过；安装、同签名升级、WACK 与商店认证未运行 |
| Android 构建与安全产物 | **已完成对应步骤**：d328a17 的 APK、JVM、AAB、合并 manifest/资源与安全检查通过；JVM 10 项的本次执行由独立 sidecar 支持。未安装或进行 Android 真机验收 |
| Linux/Web/DST 专项 | **对应范围已完成**：d328a17 Linux checkout/三时区/Chrome 3 步通过，每区 18 项、Chrome 租约 4 项；Web Release 构建通过。保留字体扫描提示、Wasm 仅 dry run 与 Linux native 未构建的边界；Windows Chrome 的 4 项结果依赖上述任务内工具适配，原版 CLI 启动失败保留 |
| 当前完整 UI66 与独立 UI60 | **已有对应结果**：当前 UI66 三规模 66+3 / 0 AX，保留 precommit revision；正式 UI60 双方各三进程得到 60+3 可比项，不沿用旧 UI66 warm 或删除旧设置错误 |
| 真实磁盘 Profile 比较 | **已完成**：两版各三次独立进程，输入/源码、运行环境/协议、启动回执与 30 动作数据通过比较器校验；[附表](PROJECT_REFACTOR_DISK_PERFORMANCE.md) 保留逐项结果和原始报告索引。后续生产变化若影响此链路需重新判定适用版本 |
| 真实编辑 Profile | **采样完成，数值比较无效**：before 三进程 AX 199/204/201 导致 invalid、0 比较；after 三进程 36 动作、独立读回和 0 AX 保留为正确性证据，不发布改善百分比 |
| host 纯数据对比 | **已完成**：相同夹具的原始版/最终版各三次独立 host 进程，11 项 comparable；保留 JIT 与原生 Profile 的区别 |
| Windows 原生无障碍 | **最终指定流程已通过**：d328a17 明确预构建 Native 27/27、69 updates、5 MSAA、graph/AX/fatal 0；3 个快照前后哈希一致，integrationPluginWarning=true 保留。历史 fb1ef2a/57751c2 记录不替代此终态 |
| 最终滑块流程 | **对应范围已通过**：d328a17 独立 Semantics / 全局 Overlay / 完整单表单滚动有 57 项、4 边缘全 RGBA 和完整 UI66 证据；旧 per-slider/page Overlay 仅作废弃方案诊断 |
| Android 真机及辅助技术 | 等用户设备可用后执行实际平台流程，记录通知/恢复/交互和辅助技术结果 |
| 最终提交与签名回执 | **已完成整段审计**：基线之后至 d328a17 的 129 项均通过 SSH 签名、对象 ID、线性父链、单行格式与中文摘要检查，失败 0；128 项范围含汉字，844d59b 的 CI 为技术缩写，保留历史。文档汇总提交单独记录 |

## 已证实的剩余组合限制

真实 Windows 整进程冷启动的隔离仍有一个具体缺口：`MyApp._createAgendaCoordinator()` 内部构造默认通知服务，继续创建 Windows 原生网关及直接 FFI 后端；现有 AppRuntime/lease 注入不能替换这个入口的通知后端。仅修改 `APPDATA`、SharedPreferences、MethodChannel 或全局平台实例不会替换实际 toast 身份初始化。这个调用链已做源码核对，尚未进行原生冷启动测量。

因此，目前的 UI mount、磁盘 load 与编辑计时应保留各自边界。真正的 ready AppBootstrap 进程启动测量需要隔离 Windows 用户/虚拟机环境，或两侧均能遵守同一原生隔离协议的受支持入口；不能修改原始生产代码或替换插件 DLL 来制造可比基线。此限制不影响已经验证的领域状态拆分，但它使“正常整进程冷启动已测量”仍不成立。

后续 [冷启动源码复核](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/cold-startup-review/README.md>) 再次确认原始版本没有所需通知注入入口，且内部 bootstrap ready 早于完整数据就绪/画面呈现；没有创建隔离用户/虚拟机或执行冷启动采样。

原始三次 Profile 的 `build/benchmarks/ui-before/r1..r3/run.log` 各有 1998、2013、1986 条 AXTree 拒绝记录，驱动成功不保证原生语义正确。r5 的 overlay 模态正确阻止了侧边栏点击；r6 改为 sideBySide 后暴露真实 AX 缺陷。随后 [trace1 检查](<D:/Project/Flutter/sked/.scratch/refactor-20261014/native-a11y-94d7c4c-trace1/serialized-semantics-inspection.json>) 将首次错误对应到 batch 26、节点 150 从父 148 移到 353，原生移除后 tooltip overlay 351/352 没有在增量包中重发。该诊断明确 `diagnosticOnly=true`，不能将它的驱动通过记作验收。

`fb1ef2a` 用恒定语义父承载画布关闭动作，保留显式子节点，并由 GestureDetector 复用同一个操作回调而不重复生成手势语义；isolated 完整流程和子控件行为均通过。被废弃的单层 container `canvas-stable` 只解决 AX 日志却合并子控件，因此不用于最终结论。原生通过的具体来源与版本映射见上表；它不替代新的 UI v2 性能采样或真实 Windows 整进程冷启动。

[HANDOFF.md](HANDOFF.md) 已同步本检查点的领域入口、Flutter 3.47.7 / Dart 3.13.5 约束及最终验收结果，并保留旧计划撤回、平台分发、密钥迁移、缓存清理暂停等历史边界。四份文档以 d328a17 为实现终点，在同一个文档汇总提交中交付。

## 本轮签名提交时间线

起点为原始 `77061b4`，以下 129 条实现提交按顺序列到 d328a17，时间均为 UTC+08:00。[完整提交审计](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/commit-audit-d328a17.json>) 实际运行 129 次 verify-commit：SSH 签名、原始对象 ID、线性父链、单行 type(scope): 中文摘要均 129 项通过，失败 0。128 个范围含汉字，844d59b 的范围 CI 是保留的技术缩写；未改写历史。四份报告的文档汇总提交不计入这张实现表。

| 序号 | 提交 | 时间（2026 年） | 主题 | 签名 |
| ---: | --- | --- | --- | --- |
| 起点 | `77061b4` | 10-14 00:27:20 | fix(Windows构建): 兼容网页插件命令策略 | G |
| 1 | `0d67b98` | 10-14 01:11:18 | perf(存储): 将快照编解码移出界面线程 | G |
| 2 | `844d59b` | 10-14 01:13:50 | refactor(CI): 移除覆盖率门禁与重复基准测试 | G |
| 3 | `350ea1f` | 10-14 01:16:29 | perf(日程): 浏览日期时保留事件查询缓存 | G |
| 4 | `da1b01a` | 10-14 01:19:38 | refactor(存档): 分离模型与严格快照校验 | G |
| 5 | `0eec1f1` | 10-14 01:24:46 | refactor(日程任务): 统一编辑提交与目标生命周期 | G |
| 6 | `755a2ea` | 10-14 01:30:02 | perf(通知): 按提交领域筛选提醒重排 | G |
| 7 | `cc2cf1b` | 10-14 01:39:50 | test(编辑流程): 通过实际编辑按钮定位课表任务 | G |
| 8 | `6200bbb` | 10-14 01:39:53 | refactor(课程任务): 统一编辑入口与提交归属 | G |
| 9 | `246a6f9` | 10-14 01:47:29 | refactor(数据会话): 独立管理快照与耐久提交 | G |
| 10 | `5e7213c` | 10-14 01:47:32 | test(性能): 增加双端真实交互帧测量 | G |
| 11 | `3a15260` | 10-14 01:50:12 | perf(课表): 复用周投影与日期列布局 | G |
| 12 | `86ccb0c` | 10-14 01:55:03 | refactor(课表导入): 移除无业务价值的提交转发层 | G |
| 13 | `eaf8cfb` | 10-14 02:07:03 | refactor(课表状态): 分离业务命令与浏览状态 | G |
| 14 | `2a3596b` | 10-14 07:41:08 | refactor(日程状态): 分离业务命令与查询视图 | G |
| 15 | `537b95e` | 10-14 07:45:04 | perf(月视图): 复用滑动月页并保持像素对齐 | G |
| 16 | `8f675c5` | 10-14 07:47:14 | refactor(工作区): 统一导航事务与提交屏障 | G |
| 17 | `c4bb0dd` | 10-14 07:47:45 | perf(课表导入): 异步预处理内容并隔离失效任务 | G |
| 18 | `b35809e` | 10-14 07:49:22 | refactor(测试): 合并重复夹具并归整业务回归 | G |
| 19 | `2f8ad0e` | 10-14 07:54:35 | refactor(通知契约): 分离平台接口与通知身份规则 | G |
| 20 | `40ca12b` | 10-14 08:00:33 | perf(数据提交): 按领域维护不变量并停止全树重建 | G |
| 21 | `cd2707e` | 10-14 08:02:38 | perf(月视图): 缓存相邻月投影与日程分桶 | G |
| 22 | `b1f490b` | 10-14 08:06:43 | refactor(设置状态): 分离设置命令与工作区可见快照 | G |
| 23 | `767a4e4` | 10-14 08:06:54 | refactor(通知实现): 分离内存网关与诊断编号分配 | G |
| 24 | `9b0124d` | 10-14 08:16:58 | refactor(密钥状态): 独立管理安全写入与读回验证 | G |
| 25 | `55371aa` | 10-14 08:17:06 | refactor(视觉验收): 合并采集协议与重复导航场景 | G |
| 26 | `fb5374c` | 10-14 08:22:04 | refactor(通知文案): 分离本地化文本与平台动作协议 | G |
| 27 | `70ab36c` | 10-14 08:22:20 | perf(月视图): 复用文字测量与像素网格布局 | G |
| 28 | `cbc357a` | 10-14 08:35:07 | refactor(通知平台): 独立原生网关并保留后台回调身份 | G |
| 29 | `f1b58ab` | 10-14 08:39:55 | refactor(保存流程): 分离维护预约与延迟持久化调度 | G |
| 30 | `73d1a80` | 10-14 08:49:04 | refactor(视觉验收): 删除重复整页采集并验证文档编辑链路 | G |
| 31 | `0adbe4f` | 10-14 08:49:42 | refactor(编辑任务): 直接依赖领域命令与工作区会话 | G |
| 32 | `690bdb6` | 10-14 08:51:36 | refactor(后台提醒): 分离载荷校验与无界面动作处理 | G |
| 33 | `99c3739` | 10-14 08:57:27 | refactor(数据传输): 独立选中数据的预览导出与应用入口 | G |
| 34 | `ea626f6` | 10-14 09:01:23 | refactor(设置入口): 直接调用通知配置与密钥业务接口 | G |
| 35 | `357275c` | 10-14 09:04:42 | refactor(提醒存储): 分离运行协议与持久化实现 | G |
| 36 | `4067e0f` | 10-14 09:23:18 | refactor(工作区导航): 独立日期事务与退出守卫 | G |
| 37 | `18fe814` | 10-14 09:32:26 | refactor(导入编解码): 提供异步计算与预解析应用接口 | G |
| 38 | `06b67d7` | 10-14 09:32:53 | refactor(显示设置): 让共享控件消费领域配置与命令 | G |
| 39 | `ba31c14` | 10-14 09:44:37 | refactor(导入会话): 复用解析结果并隔离过期异步任务 | G |
| 40 | `9ec7f93` | 10-14 11:53:34 | refactor(会话加载): 独立发布就绪状态与存储写门禁 | G |
| 41 | `74ef189` | 10-14 11:55:50 | refactor(设置会话): 迁移语言与工作区业务调用 | G |
| 42 | `2841672` | 10-14 11:56:47 | perf(日程数据): 增量校验变更分支并复用未变对象 | G |
| 43 | `44bc4ad` | 10-14 12:22:26 | refactor(课表导入): 复用解析候选并隔离过期会话 | G |
| 44 | `a36091e` | 10-14 12:22:55 | refactor(日程列表): 用只读快照复用日期分组 | G |
| 45 | `8375449` | 10-14 12:27:35 | refactor(备份恢复): 抽离恢复预约和默认数据构建 | G |
| 46 | `7e3c2fd` | 10-14 12:29:23 | refactor(主题设置): 通过业务入口保存工作区主题 | G |
| 47 | `0b23437` | 10-14 12:34:28 | refactor(月历): 分离领域查询与只读月页渲染 | G |
| 48 | `426df37` | 10-14 12:41:26 | refactor(数据导入导出): 统一候选确认并异步编码 | G |
| 49 | `559b7d5` | 10-14 12:50:15 | refactor(状态订阅): 按业务域发布变化并注册明确依赖 | G |
| 50 | `bba5ff4` | 10-14 12:52:42 | refactor(任务会话): 用领域状态管理失效和退出保护 | G |
| 51 | `d8e833b` | 10-14 12:54:46 | test(设置夹具): 统一领域依赖和异步编解码注入 | G |
| 52 | `2e2cf7c` | 10-14 13:04:31 | refactor(日周视图): 缓存事件分组并分离时间轴快照 | G |
| 53 | `bdc131c` | 10-14 13:13:56 | test(导入夹具): 使用领域依赖和真实会话代际 | G |
| 54 | `b7f8ebb` | 10-14 13:30:26 | refactor(备份数据): 后台编解码并复用会话绑定的恢复候选 | G |
| 55 | `8c32d13` | 10-14 13:38:46 | test(工作区夹具): 显式装配页面领域依赖 | G |
| 56 | `b03932d` | 10-14 13:40:26 | test(启动导入): 为界面夹具注入确定性计算接口 | G |
| 57 | `8316388` | 10-14 13:44:55 | refactor(依赖作用域): 跨路由复用原业务实例 | G |
| 58 | `16e41f8` | 10-14 21:53:57 | refactor(应用生命周期): 抽离加载恢复和隐私状态 | G |
| 59 | `d2afa77` | 10-14 22:00:27 | refactor(通知路由): 直接使用工作区和日程业务接口 | G |
| 60 | `bf84590` | 10-14 22:02:58 | refactor(设置订阅): 隔离语言工作区和维护门禁状态 | G |
| 61 | `28441d0` | 10-15 13:13:11 | refactor(弹层依赖): 保留跨路由任务的业务作用域 | G |
| 62 | `43c7458` | 10-15 13:15:16 | refactor(日程工作区): 改用领域订阅并切断无关重建 | G |
| 63 | `b7b8e9c` | 10-15 13:17:41 | refactor(数据清除): 独立管理清除门禁和写入收尾 | G |
| 64 | `f653133` | 10-15 13:34:06 | refactor(退出流程): 独立管理编辑收尾与持久化等待 | G |
| 65 | `809d821` | 10-15 13:34:43 | refactor(主题订阅): 使用领域依赖保留工作区草稿归属 | G |
| 66 | `3e24e5e` | 10-15 13:35:51 | refactor(节次选择): 捕获领域作用域并移除全局参数 | G |
| 67 | `58fa1a4` | 10-15 14:00:56 | refactor(开发者命令): 拆出示例写入并删除共享状态混入 | G |
| 68 | `2d7ea2b` | 10-15 14:01:50 | refactor(显示设置): 按工作区领域订阅配置 | G |
| 69 | `0567092` | 10-15 14:02:41 | refactor(导入入口): 保持文件选择前的业务会话归属 | G |
| 70 | `2222b7e` | 10-15 14:03:26 | refactor(通知协调): 直接订阅耐久提交与独立就绪门禁 | G |
| 71 | `a1411f5` | 10-15 16:10:42 | perf(数据加载): 后台完成规范化与持久字段比较 | G |
| 72 | `64d91ba` | 10-15 16:13:54 | refactor(设置业务): 解析器与通知页面直接使用领域接口 | G |
| 73 | `f43cc7d` | 10-15 16:14:53 | refactor(节次管理): 用领域命令保留延迟保存和退出归属 | G |
| 74 | `4a15e28` | 10-15 16:16:34 | refactor(课表工作区): 用当前课表快照隔离无关重建 | G |
| 75 | `c786671` | 10-15 16:29:57 | refactor(任务守卫): 直接绑定维护与工作区生命周期 | G |
| 76 | `777517e` | 10-15 16:31:02 | refactor(更新检查): 按会话与设置状态共享请求 | G |
| 77 | `a08f487` | 10-15 16:32:12 | refactor(学校导入): 将应用请求归入课表业务命令 | G |
| 78 | `b7eafb5` | 10-15 16:54:08 | test(更新检查): 补齐集成场景的新入口调用 | G |
| 79 | `08a692c` | 10-15 16:55:07 | refactor(应用外壳): 以工作区接口驱动布局和导航 | G |
| 80 | `05d9938` | 10-15 16:56:19 | refactor(应用入口): 隔离主题订阅与通知详情业务 | G |
| 81 | `0de3a13` | 10-15 16:57:59 | refactor(通用选择器): 保留领域作用域与任务失效边界 | G |
| 82 | `cacb941` | 10-15 16:59:13 | refactor(学校入口): 使用解析配置并捕获跨页作用域 | G |
| 83 | `9d62647` | 10-15 17:18:16 | refactor(恢复草稿): 用领域门禁保留可重试导入 | G |
| 84 | `185f409` | 10-15 17:19:10 | refactor(设置主页): 直接使用业务接口并保留异步任务归属 | G |
| 85 | `f8ee967` | 10-15 17:20:24 | test(领域状态): 用真实通知与仓储替代全局夹具 | G |
| 86 | `678048f` | 10-15 17:29:28 | refactor(启动首页): 按生命周期和领域快照处理恢复 | G |
| 87 | `f2fe42e` | 10-15 17:30:14 | refactor(课程详情): 使用课表领域状态隔离无关更新 | G |
| 88 | `a9df4c2` | 10-15 17:31:09 | refactor(课程提醒): 只订阅通知设置 | G |
| 89 | `4a7d903` | 10-15 17:32:34 | refactor(导入保存): 通过真实领域门禁管理恢复反馈 | G |
| 90 | `b965269` | 10-15 17:41:03 | test(业务状态): 将旧门面断言迁移到领域接口 | G |
| 91 | `7715638` | 10-15 17:42:25 | refactor(开发者页面): 使用领域命令与通知配置 | G |
| 92 | `8065ab9` | 10-15 17:43:42 | refactor(导入确认): 绑定课表目标与领域会话 | G |
| 93 | `34ad64d` | 10-15 17:53:43 | test(服务边界): 让通知存储与界面夹具直接依赖业务域 | G |
| 94 | `78dab11` | 10-15 17:54:52 | refactor(学校解析): 显式区分预览与导入并订阅领域状态 | G |
| 95 | `bf046d2` | 10-15 18:14:24 | test(日程界面): 按领域接口验证日程与提醒行为 | G |
| 96 | `8b82316` | 10-15 18:16:25 | fix(设置路由): 保存完成时只关闭所属页面 | G |
| 97 | `169cdf2` | 10-15 21:12:34 | refactor(导入校对): 用领域状态管理目标与草稿归属 | G |
| 98 | `a22547b` | 10-15 21:18:22 | chore(验收入口): 同步业务接口并补齐格式检查 | G |
| 99 | `6d5184b` | 10-15 22:40:43 | test(课表界面): 通过领域接口验证课表编辑与导入 | G |
| 100 | `f8a508a` | 10-15 22:41:20 | fix(模型选择): 过期请求只退出所属选择窗口 | G |
| 101 | `f74e2a0` | 10-15 22:50:12 | refactor(网页导入): 用领域接口管理导入页面与异步归属 | G |
| 102 | `9951b28` | 10-15 22:50:31 | fix(文本导入): 提交完成后保留上层任务草稿 | G |
| 103 | `80989cc` | 10-15 22:55:21 | refactor(任务会话): 删除全局状态兼容参数 | G |
| 104 | `8f6e1ed` | 10-15 22:55:40 | test(设置界面): 使用领域命令验证设置与草稿行为 | G |
| 105 | `75ed665` | 10-15 22:59:44 | test(工作区导航): 迁移领域接口并保留交互回归 | G |
| 106 | `6ca27c3` | 10-15 23:07:19 | test(通知配置): 删除已被结构化配置和行为测试覆盖的字符串断言 | G |
| 107 | `e930bbc` | 10-15 23:07:31 | test(桌面面板): 使用领域接口保留缩放与编辑连续性回归 | G |
| 108 | `c679f6f` | 10-15 23:08:32 | test(触控界面): 按领域接口验证移动布局与输入行为 | G |
| 109 | `69178e6` | 10-15 23:21:37 | test(应用边界): 用领域接口维护跨模块回归 | G |
| 110 | `286dd25` | 10-15 23:21:41 | test(学校导入): 通过领域接口验证解析校对与恢复 | G |
| 111 | `1d3c0a9` | 10-15 23:21:56 | test(任务会话): 直接验证工作区命令与任务失效 | G |
| 112 | `0cc760f` | 10-16 00:19:18 | test(性能入口): 迁移领域接口并隔离冒烟测试时钟 | G |
| 113 | `bace637` | 10-16 00:19:45 | test(原生入口): 以领域接口维护采集与集成场景 | G |
| 114 | `4276e92` | 10-16 00:32:57 | refactor(应用组装): 移除全局门面并由领域运行时统一管理生命周期 | G |
| 115 | `7bd7940` | 10-16 00:44:54 | perf(提交检查): 批量校验暂存快照并保留逐项失败定位 | G |
| 116 | `ab9613b` | 10-16 00:47:44 | test(公共夹具): 合并重复的内存存储实现 | G |
| 117 | `ba7c5ff` | 10-16 00:47:47 | test(控制器): 按业务职责归置原全局状态测试 | G |
| 118 | `206e307` | 10-16 01:01:10 | test(磁盘性能): 增加隔离数据的原生读写与恢复基准 | G |
| 119 | `d8cd94f` | 10-16 01:06:37 | test(界面采集): 统一当前场景入口并归并历史截图脚本 | G |
| 120 | `4492184` | 10-16 01:22:16 | test(日程导入性能): 覆盖原生 JSON 与 ICS 压力导入 | G |
| 121 | `ce915f5` | 10-16 13:11:14 | fix(日期选择器): 恢复标题文本与保存反馈的无障碍语义 | G |
| 122 | `1205c6e` | 10-16 13:18:03 | test(编辑性能): 增加真实课程与日程编辑保存的原生基准 | G |
| 123 | `94d7c4c` | 10-16 14:17:26 | fix(性能基准): 在 Profile 中使用有效的编辑文字输入客户端 | G |
| 124 | `fb1ef2a` | 10-16 19:21:59 | fix(工作区无障碍): 稳定画布关闭动作并保留子控件语义 | G |
| 125 | `01a98c5` | 10-16 19:44:14 | test(性能基准): 通过真实首页采样并记录原生语义状态 | G |
| 126 | `57751c2` | 10-16 19:56:22 | test(Windows无障碍): 增加原生控件读回与完整交互验收 | G |
| 127 | `4169dc7` | 10-16 20:14:40 | fix(设置无障碍): 修复滑块提示在滚动和返回时遗留节点 | G |
| 128 | `ef1aea3` | 10-16 20:52:17 | test(工作区性能): 独立采集滚动与切换的共同基准场景 | G |
| 129 | `d328a17` | 10-16 21:52:47 | fix(设置滚动): 保留离屏语义锚点与完整滑块提示 | G |
