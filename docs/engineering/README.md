# 工程记录

历史重构与性能结果保留为公开工程文档，统一收录在 `docs/engineering/`。迁移时保留实际提交、测量协议、数据、退化及验收限制；移动文件不会使历史结果成为当前版本的验收。

公开链接指向仓库内文档、工具、测试或已存在的提交。原始日志、截图和本机临时工件不随源码发布；历史记录可以保留来源标识，但不把开发者电脑上的路径作为读者可打开的链接。不复制临时目录，也不借整理文档改变原有通过、失败或待验结论。

新增运行证据使用系统临时目录；需要长期公开的内容整理为可审阅的摘要、协议与提交索引。现行行为与发布约束仍以 [使用逻辑](../USAGE_LOGIC.md)、[可靠性验证指南](../RELIABILITY_BASELINE.md) 和 [发布验收](../RELEASE_ACCEPTANCE.md) 为准。

## 历史结果索引

| 文档 | 范围 |
| --- | --- |
| [重构实施报告](PROJECT_REFACTOR_REPORT.md) | 提交链、实现范围与各阶段验收归属 |
| [续验结果](PROJECT_REFACTOR_CONTINUATION_RESULTS.md) | 后续采样、候选撤回与遗留边界 |
| [磁盘性能](PROJECT_REFACTOR_DISK_PERFORMANCE.md) | 保存、加载、导入和恢复的对照 |
| [工作区性能](PROJECT_REFACTOR_UI_PERFORMANCE.md) | UI、Host 与编辑操作的测量 |
| [长帧优化记录](PROJECT_REFACTOR_LONG_FRAMES.md) | 日期路径与滚动协议 |
| [长帧结果](PROJECT_REFACTOR_LONG_FRAME_RESULTS.md) | 各动作完整比较及退化 |
| [启动边界](PROJECT_REFACTOR_STARTUP.md) | 组合根、通知锁与启动协议 |
| [启动结果](PROJECT_REFACTOR_STARTUP_RESULTS.md) | 独立进程时间、RSS 与取样限制 |
