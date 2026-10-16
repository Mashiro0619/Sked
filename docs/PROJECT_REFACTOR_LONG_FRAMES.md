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

保留事件引用、原排序比较器、结束时刻减一微秒、范围裁剪和隐藏周末处理。午夜不存在时，日期归一化得到的时间及原循环比较顺序也保持不变。现有三个月投影缓存的保留范围与失效规则不变。

月投影、日历工具、时间线、首页、桌面月页和紧凑月页的六个文件共 197 项测试通过，包括新增的范围裁剪、长期事件身份和跨日分桶用例。原有月份切换、筛选失效、字号、面板尺寸及滚动行为保护保留。日志为 `.scratch/refactor-20261014/long-frames-month-projection.log`；默认 Windows 时区通过不代表命名时区已经验收。

此处只记录已执行的针对性验证。修复后的三进程性能比较、命名时区和当前提交的跨模块验收将追加各自的实际结果；尚不据此宣称长帧已解决。Android 真机和真实进程冷启动仍需单独验收。
