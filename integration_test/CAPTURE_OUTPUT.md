# 集成验收工件目录

迁移后的采集入口通过 `createCaptureOutputDirectory` 申请输出目录：默认使用带任务标签的唯一系统临时目录，并打印 `SKED_CAPTURE_OUTPUT <标签> "<绝对路径>"`。同一测试保持这一个目录，图片与清单写在一起；不同测试默认互不覆盖。

需要固定输出位置时，以 `--dart-define=SKED_VISUAL_OUTPUT=<绝对目录>` 显式指定。覆盖值必须是当前宿主可用的绝对路径；原目录和已有工件保留，不自动清空，也不自动添加子目录。多次使用同一显式目录时，应按测试原有的场景命名协议分别保存，或为每次执行指定新的目录。

截图、清单、原生交互记录用于测试结束后的人工复核，不在 `tearDown` 中自动删除。普通临时测试数据及验证目录工具本身的单元测试仍负责清理自己的目录。新采集结果应记录源码版本、平台、实际窗口与输入方式，不能把宿主模拟画面当作物理设备验收。

已迁移入口：

| 分组 | 场景 |
| --- | --- |
| 移动捕获会话 | `mobile-calendar-grids`、`m3-expressive-controls`、`mobile-home`、`mobile-ui-fixes`、`school-sites-mobile` |
| 手机布局与交互 | `adaptive-layout`、`mobile-calendar-interactions`、`mobile-picker-surfaces`、`mobile-secondary-pickers`、`mobile-tasks` |
| 课表与节次资源 | `student-day-agenda`、`student-resources`、`teaching-weeks`、`period-time-sets`、`period-times-editor` |
| 工作区与设置 | `compact-toolbars`、`desktop-panels`、`desktop-resize`、`workspace-chrome`、`workspace-pages`、`settings-layout`、`settings-transfer`、`theme-tasks` |
| 分类与浮层 | `category-manager`、`category-panels`、`workspace-editor`、`floating-panels`、`floating-panel-anchors` |
| 控件、日期与提醒 | `component-gallery`、`control-gallery`、`date-navigation`、`date-range-highlights`、`day-agenda`、`dropdown-focus`、`event-pickers`、`modal-chrome`、`reminder-hover`、`reminder-summary` |
| 多步编辑与标题 | `course-details`、`editor-layouts`、`panel-headings` |

移动捕获会话的图片与 `manifest.json` 位于同一目录；只有完成预期的全部截图后才写成功清单，重复文件名会被拒绝。其他场景保留原有文件名和清单协议。

多步编辑与标题组在每个测试开始时申请一次目录，将其传给全部截图和清单写入步骤，避免每次截图分别创建新目录。组件画廊继续在一个组内汇总多个带独立 profile 文件名的测试。
