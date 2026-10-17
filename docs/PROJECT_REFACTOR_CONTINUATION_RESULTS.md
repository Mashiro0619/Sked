# 重构续验：列表优化与分阶段验收

最新代码检查点为 `d9d98af879e024595bd676c30ba5363fb552b361`（2026-10-17）。本次完成逐条列表构建和事件焦点修复；上轮 `e522134` 的完整 VM、平台包、UI66、Linux 与浏览器记录仍保留原始版本，不重标为本次结果。

## 逐条列表构建与事件焦点续改

原列表仅按日期组懒加载：一天进入视口时，该日全部事件都会构建。`d9d98af` 改为按日期标题和单条日程索引，只构建视口附近的条目；累计索引复用原分组，不为渲染再复制整份事件列表。稳定的日期、日历、事件与开始时间身份也修复了另一项可复现问题：在前面插入日程后，键盘焦点和 Enter 仍指向原事件。日期标题具有标题语义，列表语义计数只计算事件。

[本次本地闭环回执](<D:/Project/Flutter/sked/.scratch/refactor-20261017/list-virtualization/closure.json>)关联以下范围：

- 相关回归 **123 项通过**，覆盖分组、首页、工作区语义及 Windows/Android widget 行程；测试风格整理后的新增列表 **4 项最终复验通过**，两组不相加。四个改动文件格式检查零改动，静态分析包含信息级检查并通过。
- 高密度夹具包含同日 160 个事件和次日 1 个事件。桌面 1280×720、窄屏 Windows 390×844、Android 风格 390×844／1.5 倍文字／RTL 均验证按需构建、跨日滚动、详情打开、161 个事件的滚动语义计数与日期标题；插入后键盘焦点与 Enter 另在 Windows 桌面 1280×720 验证。增量语义图检查无错误。这些是 widget 平台样式，不包含 Android 真机验收。
- 固定测试字体下，首屏构建的同日事件数从 160 降为 13／15／5；六组首屏/滚动后图像的内容位置一致，两个 Windows 滚动图仅右侧滚动条存在像素差异。另以 Segoe UI／Material Icons 复核可读的列表行；部分无关控件仍显示测试占位字形。这些图像均为本地 widget 渲染，未宣称原生窗口或浏览器视觉验收。
- `08bedc4 → d9d98af` 两侧各 **3 个新 Windows Profile 进程**，依次 ABBAAB，每进程完整执行 60 个交互和 3 次挂载；六轮均通过，AXTree／语义图／fatal 日志计数全部为 0。冻结的完整源码、程序目录和 9 个共同采集文件在每次启动前后核对。运行时间为 `2026-10-17 18:25:51 +0800` 至 `2026-10-17 18:38:02 +0800`。构建在此前完成，源检查、其他构建、CPU 诊断和截图测试未并行混入采样。

## 本次性能观察与严格比较边界

未修改的 [UI60 严格比较结果](<D:/Project/Flutter/sked/.scratch/refactor-20261017/list-virtualization/comparison/strict/summary.json>)为 **`invalid`**：首次拒绝位置的列表长度估算由 `13525.6` 变为 `12955.4` 逻辑像素，超过原有 1 物理像素门槛。逐条懒加载会改变 `maxScrollExtent` 估算；对所有样本复核，超出该门槛的 36 个初始/最终记录仅出现在 `general.list.open_scroll`。原门槛与失败报告保留，未改写为“可比”。

[逐轮校验后的观察数据](<D:/Project/Flutter/sked/.scratch/refactor-20261017/list-virtualization/comparison/observations.json>)使用原校验器复核六个单独报告、原始帧统计、进程来源、完整 workload、输入/目标和共享源码，并保留实际滚动偏移。下表完整列出六种列表场景，只是这些实际样本的描述；不作为通过严格比较、统计显著性、独立因果或相同物理滚动轨迹的证明。`cold` 仍表示会话中第一次动作，不是 OS/磁盘冷启动。

| 列表场景 | 三个进程最大 build 原值，前 → 后（ms） | 最大 build 中位数（ms） | raster P95 中位数（ms） | 动作后 RSS 中位数（MiB） |
| --- | --- | ---: | ---: | ---: |
| `sparse/cold/general.list.open_scroll` | 19.679 / 22.509 / 20.593 → 21.911 / 17.596 / 17.903 | 20.593 → 17.903 | 1.021 → 1.055 | 253.12 → 246.96 |
| `sparse/warm/general.list.open_scroll` | 19.418 / 24.281 / 21.551 → 20.426 / 21.050 / 20.457 | 21.551 → 20.457 | 0.946 → 0.956 | 267.70 → 262.94 |
| `1000/cold/general.list.open_scroll` | 87.544 / 86.840 / 88.506 → 80.575 / 87.347 / 89.247 | 87.544 → 87.347 | 1.008 → 1.169 | 313.22 → 314.68 |
| `1000/warm/general.list.open_scroll` | 70.778 / 69.158 / 77.899 → 66.146 / 67.713 / 70.026 | 70.778 → 67.713 | 0.956 → 1.055 | 340.40 → 331.52 |
| `5000/cold/general.list.open_scroll` | 383.059 / 391.875 / 516.162 → 332.996 / 334.416 / 343.871 | 391.875 → 334.416 | 1.058 → 1.121 | 485.47 → 474.46 |
| `5000/warm/general.list.open_scroll` | 328.033 / 306.969 / 294.609 → 265.004 / 278.978 / 280.779 | 306.969 → 278.978 | 1.096 → 1.087 | 522.05 → 509.05 |

六个列表场景中，5 个 raster P95 中位数升高，1,000 条 cold 的动作后 RSS 也升高；所有原值未筛选。整进程峰值 RSS 中位数为 **709.37 → 718.69 MiB**，不能据此宣称内存全面改善。完整 60 个动作及 3 个挂载的观察值也保留在同一 JSON，不把表中较好的方向推广到整套性能。

仍有 **23/60 → 23/60** 个动作至少一次出现 ≥100 ms build，挂载为 2/3 → 2/3。后测全局最坏 build 为 **806.724 ms**，来自 `5000/cold/mount` 的 r3。六次记录的总帧数分别为 before `[14970, 14869, 12227]`、after `[14893, 14912, 15014]`；稀疏 cold 月视图的相邻 vsync 间隔中位数均为 4.167 ms，但该局部中位数不能证明整个运行具有相同帧节奏、负载或温度。

源码与键盘问题已修复，剩余长帧及本次严格比较失败仍未消除。下一轮若建立适合懒加载的比较协议，应独立冻结两侧采集输入，并直接验证可见内容和滚动行为；不得修改这批原始回执以补成通过。Android 真机、Windows 安装升级/认证、完整辅助技术以及其他平台产物的最新版本验收仍有各自边界。本次未重新运行 4,901 项全量或整套平台矩阵，也未推送、部署或发布。早期编译、测试断言定位及截图异步等待失败日志均留在本地回执索引中。

## 此前 e522134：日期复用与完整平台矩阵

以下为上轮原始记录；其中“最终”只指 `e522134` 阶段。

本轮从 `5ef639cc5a5e31fb80acf637cc25c6bdca227b05` 继续，最终代码检查点为 `e522134ac8db262c30c9823568d867dbaf4f860b`。`e522134` 的 Git tree 与 `1139840` 精确一致；本轮最终仅保留日程列表单次投影内的本地日界复用。`1d45d46` 的课表文字测量缓存已由签名提交 `e522134` 撤回，候选性能和浏览器证据保留各自版本。本文更新于 2026-10-17，所有“最终”结果仅来自下列 e522134 独立回执与最终交替样本。

### 最终实现与候选历史

| 检查点 | 实现及处理 | 当前状态 |
| --- | --- | --- |
| `1139840` | `lib/widgets/general_list_projection.dart` 每次投影内复用同一年月日的本地日界；保留 `DateTime` 分组、全天 UTC 声明日期、定时本地日期、午夜归一化、顺序及日程对象身份，缓存不跨快照 | 最终保留 |
| `1d45d46` | 同一次课表布局内复用同字段、同行数限制的文字测量；字体、缩放、宽度、方向和 locale 仍来自当次布局 | 仅候选；已撤回 |
| `e522134` | 交替原生比较未证实文字缓存的稳定收益后撤回该候选；tree 回到 `1139840` | 最终代码检查点 |

三个实现/撤回提交均保留独立 SSH 签名历史。`cpu-before` 的基线 CPU 诊断、列表局部 JIT 诊断和最终原生帧比较分别归档。诊断 fixture 的 5,000 个事件展开为 29,626 个实例、181 个日期组，说明单次投影内存在大量相同日界；这是独立诊断 population。JIT `after-cache-r1` 的 `sourceRevision` 仍为 `5ef639cc5a5e-list-date-candidate`，不重标为最终版本。这些结果不混为同一测量或独立因果证明。课表几何扫描未得到主要热点证据，本轮未据此改写几何算法。

候选 `1d45d46` 最初分时三轮曾记录首次列表最大 build 中位数 753.558 → 381.307 ms，同时 60 项 build P95、59 项 raster P95、53 项动作耗时升高。原始 `5ef639c` 的单进程控制重跑又显示基线时间漂移，因此没有把控制样本混入三轮统计，也没有把全部变化归因于代码。随后候选交替三轮中首次列表为 771.805 → 401.539 ms；build P95 有 38 项升高、raster P95 有 40 项升高，课表文字相关动作没有一致收益。这些均为 `5ef639c → 1d45d46` 候选历史，不能称为 `e522134` 最终结果。原始数据和所有退化未删除。

### 最终同协议 Windows Profile 比较

最终两侧为 `5ef639cc5a5e31fb80acf637cc25c6bdca227b05` → `e522134ac8db262c30c9823568d867dbaf4f860b`，按 **前、后、后、前、前、后（ABBAAB）** 顺序串行采集，两侧各三个新 Windows Profile 进程；各执行 `workspace60-v1` 的 60 个交互与 3 次独立挂载。采样时间为 `2026-10-17T07:19:50.605757+00:00` 至 `2026-10-17T07:32:37.914645+00:00`。最终六个原始报告及其进程来源的 SHA-256、完整源码 revision、60+3 数量、无重叠次序与摘要数值均在生成本文前核对。另有[独立交替审计](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/final-interleaved-audit.json>)从原始逐帧记录复算，19,873 次检查中未记录不一致；其评估仍为 `Share with caveats`，帧节奏等限制按原审计保留。

fixture、输入、测量与驱动源码按比较器核对；滚动限定主画布，语义状态启用。已构建二进制复用并关联原始构建来源，每次执行前后校验 exe/AOT/engine 哈希。Profile runner 的 `productionMatchesRevision` 具体检查 HEAD、`lib`、`pubspec.yaml` 与 `pubspec.lock`，另行核对 9 个冻结 harness 文件和 compiled artifacts；该守卫未覆盖 `windows`、`assets` 等全部生产构建输入。当前封存文件及 SHA-256 的复核是本地来源一致性证据，不是从采样瞬间起的不可篡改认证。

Source、平台构建、Linux、UI66 与 CPU/JIT 诊断不并行混入这组六进程；专用 WSL 在最终采样前停止。旧候选三轮、控制样本及旧启动、磁盘测量均保留独立分母与真实版本。

下表只使用最终 `5ef639c → e522134` 交替样本，单位 ms。最大 build 中位数为三个进程各自最大帧的中位数；三轮最坏值保留所有运行观察到的最大帧。固定列出六类 5,000 数据动作的 cold/warm 结果，不按变化方向筛选。

| 5,000 数据场景 | 最大 build 中位数 前 → 后 | 三轮最坏 build 前 → 后 | 中位数变化 |
| --- | ---: | ---: | ---: |
| `5000/cold/general.month.swipe` | 299.006 → 269.196 | 302.712 → 281.701 | -9.97% |
| `5000/cold/general.list.open_scroll` | 886.417 → 374.376 | 931.852 → 395.942 | -57.77% |
| `5000/cold/workspace.student.open` | 679.820 → 592.103 | 724.938 → 623.411 | -12.90% |
| `5000/cold/student.timetable.switch` | 599.039 → 539.148 | 600.784 → 615.233 | -10.00% |
| `5000/cold/student.day.open_scroll` | 598.376 → 586.435 | 684.588 → 604.027 | -2.00% |
| `5000/cold/workspace.general.open` | 630.912 → 615.572 | 742.901 → 638.464 | -2.43% |
| `5000/warm/general.month.swipe` | 172.362 → 186.349 | 227.108 → 208.740 | +8.11% |
| `5000/warm/general.list.open_scroll` | 725.426 → 340.712 | 728.555 → 390.782 | -53.03% |
| `5000/warm/workspace.student.open` | 609.361 → 602.140 | 671.985 → 666.027 | -1.19% |
| `5000/warm/student.timetable.switch` | 514.292 → 519.408 | 515.867 → 555.581 | +0.99% |
| `5000/warm/student.day.open_scroll` | 623.354 → 626.445 | 658.393 → 650.551 | +0.50% |
| `5000/warm/workspace.general.open` | 689.884 → 618.924 | 807.661 → 680.145 | -10.29% |

实际帧节奏并未固定。按各侧 r1/r2/r3 顺序，60 个交互与 3 个挂载测量窗口合计记录的帧数为 before `[4806, 7933, 5205]`、after `[4789, 4812, 14662]`。稀疏数据 cold 月视图的相邻 `vsyncStartUs` 间隔中位数为 before **16.667 / 4.167 / 4.167 ms**、after **16.667 / 16.667 / 4.167 ms**，同时存在约 16.667 ms 与 4.167 ms 的节奏。相同显示/runtime 配置不能证明实际帧节奏、后台负载或温度一致。

完整 60 项的方向计数如下，所有升高项与原始三值保留在完整报告中。由于记录的帧数、节奏与短帧比例不同，整体 P95 方向仅描述这组六个实际样本，不能解释为固定帧节奏下的性能变化，也不独立证明代码因果或所有场景改善：

- 动作耗时：38 项降低、22 项升高、0 项相同。
- build P95：40 项降低、20 项升高、0 项相同。
- 最大 build 中位数：34 项降低、26 项升高、0 项相同。
- raster P95：38 项降低、22 项升高、0 项相同。
- 动作结束 RSS：23 项降低、37 项升高、0 项相同。

至少出现一次 ≥100 ms build 的交互为 28/60 → 27/60，挂载为 2/3 → 2/3。仅在交互中，最终后测最坏帧为 `5000/warm/workspace.general.open` 的 680.145 ms；包含挂载后，全局最坏 build 为 **937.056 ms**，来自 `5000/cold/mount`（`after/r2`）。仍存在的长帧不能从中位数改善中省略。

整进程最大 RSS 中位数为 681.53 → 695.41 MiB（+2.04%）。RSS 是整个进程驻留内存，不是 Dart heap、单动作分配量或精确显示时刻的内存；这些数据不支持“内存全面改善”的结论。

`cold` 是该数据会话第一次执行动作，不是 OS、磁盘或整个应用的冷启动。每个动作先按单进程帧分布计算分位数，再汇总三次值；短窗口 P99 可能等于最大帧。三次重复只提供描述性比较，不证明统计显著性或某一处改动的独立因果收益。注入输入、Profile 和隔离服务也不等于物理设备交互或正式安装包验收。

### 最终 e522134 代码验收

| 项目 | 最终执行结果 | 范围与来源 |
| --- | --- | --- |
| Source | 9 步全部退出 0；完整 VM **4,901 通过、1 跳过**；754 文件格式检查零改动，应用和内部插件分析通过 | [最终回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-e522134ac8db262c30c9823568d867dbaf4f860b/source-20261017T064226756Z/receipt.json>)；Windows 命名时区入口的跳过与 Linux 独立执行分开记录，不相加 |
| Windows Native | 27/27 阶段、66 次语义更新、5 次同 PID MSAA、28 个按钮与 2 个文本检查；AX/graph/fatal 均 0 | [最终回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-e522134ac8db262c30c9823568d867dbaf4f860b/windows-native-20261017T070331240Z/receipt.json>)；integrationPluginWarning=true 原样保留；不替代物理输入或完整辅助技术 |
| UI66 | 新进程 66 个动作、3 次挂载，6 个设置与 36 个滚动动作；直接校验通过、0 AX/graph/fatal | [最终回执](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/tools/ui66/runs/ui66-correctness-e522134ac8db-20261017T070507875Z/receipt.json>)；单进程正确性，不混入 UI60 性能三轮 |
| Windows Packages | 两类 Release/MSIX、身份、Toast、capabilities、payload 与归档 Store verifier 通过 | [最终回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-e522134ac8db262c30c9823568d867dbaf4f860b/windows-packages-20261017T071315555Z/receipt.json>)；两包未签名，未安装、升级、WACK 或上传 |
| Android | APK/AAB 与合并 manifest/资源安全检查通过；JUnit XML 10 项、0 失败/错误/跳过；Gradle 报告结果复用（`> Task :app:testDebugUnitTest UP-TO-DATE`），不能计作本 SHA 新执行 | [最终回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-e522134ac8db262c30c9823568d867dbaf4f860b/android-20261017T071003773Z/receipt.json>)；没有 Android 真机验收 |
| Linux native | 独立 Debian 13 WSL2 x64 Release 与动态链接检查通过，bundle 已归档 | [最终回执](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/linux-native/runs/acceptance-e522134ac8db-20261017T071537812Z/receipt.json>)；未图形启动、安装、通知或原生输入 |
| Linux 四时区 | 纽约 23 项、柏林 23 项、上海 23 项、圣保罗 7 项，共 76 次实际执行、零失败/跳过 | 同一最终 Linux 回执；日期回归与列表投影两文件，不重标此前更大矩阵 |
| Web | JavaScript Release 与[该 SHA 的有限浏览器流程](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/web-visual/final-flow.json>)通过；范围按独立回执 | [最终回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-e522134ac8db262c30c9823568d867dbaf4f860b/web-20261017T070850958Z/receipt.json>)；Web 为源码兼容工程，未发布在线产品或执行实际 Wasm |

最终 Linux 的 1,033 个源码文件中，1,026 个非生成文件逐字节保持不变；另 7 个 Flutter 插件注册生成文件只允许 CRLF→LF。生成前后原文、diff 和哈希保留，本次生成文档再次核对换行归一化且内容不变；构建结束的 source-integrity 也必须匹配生成后快照。7 个执行步骤均为独立成功终态，归档文件数不是测试数。

### 中断、失败与候选验收的保留

候选 `1d45d46` 的首次 Source 覆盖率运行与 Linux 工作并行、测试并发为 4，发生 Dart VM 内存不足和服务断开，中断记录保留，不能算作成功。失败文件单独带覆盖率重跑 55 项通过；降低测试并发至 2、停止其他构建后，独立完整重跑得到 4,901 通过、1 跳过，见 [候选 Source 成功回执](<D:/Project/Flutter/sked/.scratch/refactor-20261014/final-1d45d46d80f0d0a7a28b406db192adc11d4ae306/source-20261017T045603688Z/receipt.json>)。最终 Source 表格来自 e522134 的新运行，没有拼接候选结果。

Linux 曾在旧 Ubuntu 缺少 WPE 开发包，Docker Desktop 初始化又失败；后来新建专用 `Sked-Refactor-Debian13` 并校验官方镜像与固定 Flutter/engine。候选阶段较早运行中断，另一次虽产出 Release，但时区测试因 localhost 代理目标错误而加载失败，整体仍保留失败。仅为测试子进程配置回环代理绕过、Ninja 并发 2、测试并发 1 后，`1d45d46` 独立 Debian 13 验收已通过。该候选成功及其 1,026 个不变文件/7 个只作 CRLF→LF 的记录保留；最终 Linux 使用上表 e522134 的另一次完整运行，不能以候选或旧较大时区矩阵替代。

### 浏览器视觉与交互边界

最终 `e522134` 已有 [独立有限浏览器回执](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/web-visual/final-flow.json>)，状态为 `passed-scoped-flow`。该回执明确记录的流程为：首次选择课表与日程工作区；创建合成日程并保存，刷新页面后在列表读回；日程 Enter 打开详情、Escape 关闭；创建课表和课程，刷新页面后读回课程；窄屏点击课程打开详情并关闭，完整可访问名称保留；固定桌面视口与窄屏列表、课表截图复核。 尺寸为 1440×900、390×844。 课程键盘附加尝试原记录：最终流程未执行课程键盘激活，只接受点击打开；候选版程序化 focus/Enter 超时仍按候选历史保留。 DOM 几何按最终回执独立保留：`{"fixedDesktop":{"width":1440,"height":900,"devicePixelRatio":1.0000000149011612,"bodyClientWidth":1440,"bodyScrollWidth":1440},"desktopListRow":{"x":241,"y":54,"width":1183,"height":91},"narrowListRow":{"x":16,"y":54,"width":358.3999938964844,"height":101},"narrowListBodyScrollWidth":390,"narrowTimetableCourse":{"x":53,"y":116,"width":40.912498474121094,"height":126},"narrowBodyClientWidth":390,"narrowTimetableBodyScrollWidth":509,"bodyOverflow":"hidden","windowScrollX":0}`。 最初会话内调整视口后的启动/列表截图出现右侧裁切，未作为通过依据；固定视口再导航后的补拍内容完整，未据此认定原尺寸变化问题已修复。补拍时一次快速自动填表触发空标题校验，另一次读输入值使用了变化前的可访问名称而超时；重新聚焦并用键盘输入后保存成功。失败截图、表单状态和最终选用截图均在回执中逐项区分。 本文仅承接列明的有限范围，不把候选版 RGB 比较、完整辅助技术、离线或实际 Wasm 验收补入该记录。

候选 `1d45d46` 的 Chromium 156.0.8078.12 检查使用合成数据，在 1440×900、390×844 下覆盖起始工作区、课表/课程创建、日程创建保存与重载读回，以及日程 Enter 打开、Escape 关闭。启动页和两种宽度的课表截图与 `1142cfc` 基线 RGB 一致；列表动态时间不同，仅检查布局与内容。这些图像未重新标记为 `e522134`。

候选窄屏课表 DOM `scrollWidth=509`、`clientWidth=390`，body 为 `overflow:hidden`、window.scrollX 为 0，因此不能宣称 DOM 完全无溢出。课程完整可访问名称有记录，但额外程序化 DOM focus/Enter 未在超时前出现预期标题，课程键盘打开不能计作通过。候选控制台零错误/警告，CanvasKit 与字体仍有外网请求，不是离线验收。原始失败尝试与截图均保留。

### 证据与剩余范围

生成器只选择最终 SHA 的 `passed` 平台/Native/UI66/Linux 回执，并校验列出的归档文件与最终性能来源哈希；独立最终审计核对 697 份文件（平台 574、Linux 123），记录 23 个平台步骤与 7 个 Linux 步骤。文件数不是测试数；当前文件核验不构成采样时起的不可篡改认证。原始失败回执未重写。原始日志、截图、源码快照及逐帧分布保留在本地 `.scratch` 与 `build/benchmarks`，不纳入实现提交。本文不是远端 CI、真机或发布成功声明。

- [最终串行验收主管回执](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/final-closure.json>)
- [最终回执与归档独立审计](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/final-receipt-audit.json>)
- [最终交替性能的独立逐帧审计与限制](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/final-interleaved-audit.json>)
- [最终性能数值与六个原始来源](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/comparison-final/results/summary.json>)
- [最终关键数值摘要](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/comparison-final/key-results.json>)
- [候选交替性能及所有退化](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/comparison-interleaved/results/summary.json>)
- [候选最初分时性能及所有退化](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/comparison/results/summary.json>)
- [原始提交单进程控制重跑](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/drift-control.json>)
- [候选浏览器流程与截图索引](<D:/Project/Flutter/sked/.scratch/refactor-20261017/remaining-performance/web-visual/current-flow.json>)

Android 真机按约定延期。Windows 安装、同签名升级、干净机器、WACK/商店认证、物理输入与完整辅助技术仍需对应环境。Linux 图形运行、安装、通知与原生输入尚未验收。Web 仅承接明确版本和有限流程；实际 Wasm、离线与完整辅助技术未覆盖。压力长帧、raster 与内存的所有反向变化按最终数值保留。本轮未推送、运行远端 CI、部署或发布；没有整批清理既有缓存与证据。
