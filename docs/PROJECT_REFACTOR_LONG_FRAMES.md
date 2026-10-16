# 压力场景长帧后续优化

本轮接续全项目重构，以 `041c6fdfbc7761f6eb9fa37c0170334fd317c06d` 为起点。该提交只汇总文档，生产代码与上一轮 `d328a17` 相同；历史验收和磁盘性能仍保留各自的实际版本，见 [主报告](PROJECT_REFACTOR_REPORT.md) 与 [工作区性能报告](PROJECT_REFACTOR_UI_PERFORMANCE.md)。

## 定位与基线

隔离的 Windows Profile UI60 CPU 诊断记录了 5,590 个样本，其中 338 个截断、10 个空栈，RPC 错误为零。5,000 事件的重点窗口中，月分桶出现于 134 个采样栈，127 个同时包含本地时区换算；提醒确认匹配只出现于 10 个。73.3% 的重点样本没有 Dart 父栈，不能完整归因，也不能把采样栈次数当成调用次数。

可见热点包含 `tryParseStrictIsoDateTime → _isValidDateTimeParts → DateTime → 本地时区换算`，以及月页分桶内重复的日期归一化、日期字符串和下一日计算。因此先处理日期路径。提醒确认索引候选尚未应用，现有证据不足以将它列为主要长帧来源。

CPU 诊断含采样与序列化开销，只用于定位。正式 before 另行完成三个独立进程，每次 60 动作与 3 次挂载，均通过，AXTree、graph、fatal 日志计数均为零。九份 workload 来源完全一致；只构建一次，每次使用预构建二进制，运行前后核验源码与 exe/AOT/engine 哈希。

- CPU 汇总：`.scratch/refactor-20261017/long-frames/perf-tools/ui60-cpu-before-inspected.md`。
- 正式 before 回执：`build/benchmarks/ui-workspace-before-long-frames-20261017/provenance.json`。
- 冻结来源：`.scratch/refactor-20261017/long-frames/perf-tools/source-review-ui60/manifest.fragment.json`。

## 日期校验

严格 ISO 校验改为按公历规则计算月天数，去掉仅为校验日期而构造本地 `DateTime` 的操作。保留原有格式、输入年份与时钟范围、偏移解析、最终 `DateTime.tryParse` 和本地时间处理；偏移转换后的 UTC 跨年行为也保持不变。加载、存档和普通导入继续使用同一校验入口。

新增两个参数化行为测试，覆盖闰年与世纪年、月日溢出、严格格式、偏移和本地解析。日期、模型、存档、导入及重复日程的八个测试文件共 255 项通过；不复制现有存档和 DST 保护。日志为 `.scratch/refactor-20261014/long-frames-date-validation.log`。

## 月页日期复用

每次月页分桶最多缓存 128 个日期项，复用日期归一化、日期字符串和下一日计算。键包含 UTC/本地标志与年月日；可见日期先入缓存，超过上限的额外端点仍按原逻辑计算，缓存随该次分桶结束释放。

保留事件引用、原排序比较器、结束时刻减一微秒、范围裁剪和隐藏周末处理。循环仍比较实际时刻，缓存的日期推进共用公共日界助手。现有三个月投影缓存的保留范围与失效规则不变。

月投影、日历工具、时间线、首页、桌面月页和紧凑月页的六个文件共 197 项测试通过，包括新增的范围裁剪、长期事件身份和跨日分桶用例。原有月份切换、筛选失效、字号、面板尺寸及滚动行为保护保留。日志为 `.scratch/refactor-20261014/long-frames-month-projection.log`；默认 Windows 时区通过不代表命名时区已经验收。

## 缺失午夜时的日界修正

在真实 `America/Sao_Paulo` 进程中复现了原有问题：2018-11-04 的午夜会归一到 01:00，原日期推进又把该时间带到 11-05。当地 11-03 23:00 至 11-06 00:00 的事件因此只落入 11-03、11-04，漏掉 11-05。未改动的 `e5615f9` 归档运行两个复现断言均失败；首次因本地测试连接代理而未加载的日志另行保留，不计入产品复现。

`nextCalendarDate` 和 `previousCalendarDate` 现在直接构造目标公历日的起点；目标日缺失的午夜仍由平台构造器处理。月缓存调用同一助手，`addCalendarDays` 继续保留墙钟时间。没有改存档格式、UTC/本地标志、全天事件与网格的原比较规则。

两个回归并入现有 `date_dst_regression_test.dart` 的圣保罗分支，运行前强制检查历史偏移及缺失午夜；CI 增加对应时区步骤，未新增独立历史测试文件。七个针对测试文件共 161 项通过，静态分析通过。新候选归档在纽约、柏林、上海各通过 41 项，圣保罗通过 25 项；同一 SHA-256 的两个外部复现断言在修复后全部通过，源文件回读哈希与候选一致。

- 修复前复现：`.scratch/refactor-20261017/long-frames/date-midnight-review/before-e5615f9-noproxy.log`。
- 候选归档、四时区和复现验证：`.scratch/refactor-20261017/long-frames/midnight-candidate-20261016T194600820Z/`。
- Windows 针对回归：`.scratch/refactor-20261014/long-frames-midnight-boundaries.log`。

## 滚动采样的目标修正

`041c6fd` 与 `4d54cc3` 两侧各三进程均完成 60 动作和 3 次挂载，原生日志为零错误；比较器仍因四项 5,000 事件日／周场景的滚动范围不一致而拒绝整个数值比较。原始六进程和拒绝结果保留在 `.scratch/refactor-20261017/long-frames/comparison/`，没有生成改善百分比。

随后只增加观察信息的原生诊断确认：旧定位器选中的是右侧 `general-reminders-list` 内的 `workspace-view-body`，其范围为 2744.6／2723.6；同页真正时间网格仍为 763.6／757.6。按整个工作区的最大滚动范围选控件会受提醒列表长度影响。

采样现在限定 `workspace-canvas`，优先已有时间网格／课表主滚动 key；主画布内容无需滚动时不改滚其它面板。保持原有 fixture、60 动作、两次 400 ms 手势和等待，新增独立的 `protocol.scrollTargeting.version=1` 及范围、目标、最终滚动范围记录。两种原生 driver 均拒绝缺失该协议的结果。历史 native semantics 的 `harnessVersion=2` 含义不变，旧新定位协议不可混用，详见 [协议](../benchmark/WORKSPACE_PERFORMANCE.md)。

新增两个实际指针行为用例，保护较长旁栏和主画布无需滚动的情形；含 Windows／Android 稀疏真实页面流程在内的 8 项测试通过。完整 Windows 候选预检也通过 60 动作与 3 次挂载，0 AX，四项日／周场景重新落在 763.6／757.6，初末滚动范围相同。此单进程预检保留 `199f021bb22e` 和候选源码哈希，不充作正式三进程样本。

- 控件观察：`.scratch/refactor-20261017/long-frames/comparison/geometry-diagnosis-observed.md`。
- 新定位预检：`.scratch/refactor-20261017/long-frames/canvas-pilot-199f021/validation.json`。
- `4d54cc3` 的 Source 9 步通过，完整 VM 为 4,870 通过、1 跳过；Windows Native 为 27 阶段、68 次语义更新、5 次 MSAA，graph／AX／fatal 均零。完整回执在 `.scratch/refactor-20261014/final-4d54cc3aa1371e2fb7c32ba55dd902948bb5572d/`。

## 新协议的正式性能比较

`041c6fd` 与 `d517f78` 已使用新定位协议各完成三个独立 Windows Profile 进程。九对测量源码一致，60 个动作与 3 个挂载场景全部通过跨进程来源、几何和数据一致性检查；六次原生日志的 AXTree、graph、fatal 均为零。报告记录刷新率为 240 Hz，单阶段帧预算为 4.166667 ms。

下表为三个进程各自构建帧分位数的中位数，单位 ms；cold 表示对应数据集首次执行该工作区动作，不代表应用进程冷启动。

| 月份往返场景 | build P95 前 → 后 | build P99 前 → 后 | 三进程最坏构建帧 前 → 后 |
| --- | --- | --- | --- |
| 稀疏 cold | 19.827 → 17.586 | 34.659 → 30.485 | 42.725 → 36.301 |
| 稀疏 warm | 17.175 → 12.808 | 36.365 → 26.896 | 44.212 → 29.039 |
| 1,000 cold | 95.557 → 30.544 | 292.307 → 81.008 | 316.758 → 92.117 |
| 1,000 warm | 94.090 → 26.029 | 227.975 → 61.048 | 245.461 → 68.480 |
| 5,000 cold | 410.955 → 97.736 | 1368.565 → 255.067 | 1387.377 → 298.223 |
| 5,000 warm | 214.387 → 59.950 | 799.420 → 189.914 | 838.496 → 203.877 |

60 项动作中，构建 P95 有 41 项降低、19 项升高，P99 有 52 项降低、8 项升高。5,000 事件的工作区切换构建 P95 从约 2.15–2.30 秒降到 0.575–0.628 秒，仍超过帧预算。1,000 事件首次课表切换 P95 从 89.644 升到 96.471 ms；raster P95 有 32 项升高。5,000 事件课表周滚动还出现单进程 317.790 ms 构建帧，必须与中位数一起保留。进程峰值 RSS 中位数仅下降 0.226%，最坏值反而上升，尚不能确认内存改善。

稀疏月垂直滚动和课表周滚动在三个进程均未超预算；月份往返仍有约 8.1%–9.3% 的帧在 build 或 raster 阶段超预算。包含打开视图的日／周／列表动作、短窗口分母、挂载分位数及所有退化，见 [完整 60 项比较](PROJECT_REFACTOR_LONG_FRAME_RESULTS.md)。独立复算 378 条记录、28,270 帧及 13,080 项汇总统计未发现差异；不跨进程合池，也不以三个样本宣称统计显著性。

- 新前测与后测：`build/benchmarks/ui-workspace-before-canvas-scroll-v1/`、`build/benchmarks/ui-workspace-after-canvas-scroll-v1/`。
- 正式比较及完整分布：`.scratch/refactor-20261017/long-frames/comparison-canvas-v1/results/`。
- 九对冻结来源：`.scratch/refactor-20261017/long-frames/perf-tools/source-review-canvas/manifest.fragment.json`。

日期路径优化已获得实际测量支持，长帧尚未全部解决。Android 真机和真实进程冷启动仍需单独验收，启动隔离工作见 [启动附表](PROJECT_REFACTOR_STARTUP.md)。
