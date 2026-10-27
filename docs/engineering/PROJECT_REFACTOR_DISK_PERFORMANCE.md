# Sked 磁盘操作性能：完整 30 项

对应原始版 `77061b4172ef` 与当前版 `1205c6ed0816`，每版三个独立 Windows Profile 进程、每个进程 30 个动作。此附表来自已通过校验的比较产物，数值源为 `summary.json`，保留每个动作的三轮原始值、中位数、范围和 MAD；不重新合并样本或捏造帧统计。

交接文档已更新到 `d328a174e4047438feae79950b9b782c5fc2876c`，本附表的 after 采样版本仍是 `1205c6ed0816`。后续编辑输入、画布语义、原生工具、v2 首页、UI60 协议和最终滑块滚动修复有独立提交与证据。本附表的 30 行数字、六份原始报告路径和 SHA 均保留；新比较工具对原报告离线复算仍完全一致，不据此重写原报告 revision 或声称新增测量。

下表为墙钟耗时和进程 RSS 等读写指标，没有采集 UI 帧或编辑输入延迟。变化率为（当前中位数 − 原始中位数）/ 原始中位数；有正负号的 RSS 差值不计算百分比。三次重复不构成统计显著性或因果证明。

[完整数值、输入/源码和回执索引](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/results-disk30/summary.json>) · [逐进程原始分布](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/results-disk30/distributions.json>) · [比较清单](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/manifest.disk30.json>)

后续 [v2 校验器复核](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/results-disk30-v2validator/summary.json>) 仍为 30 项可比，逐项比较与进程指标同原汇总一致；[14 项历史规则检查](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/verification-v2.json>) 保留当时证据。最新 [最终采样审计](<D:/Project/Flutter/sked/.scratch/refactor-20261014/performance-comparison/audit-final-d328a17.json>) 再次复现原磁盘数值与分布。这些复核不是新增磁盘进程；UI60/Host11 已另行完成正式比较，编辑 before 的 AX 错误导致数值比较无效，详见 [UI/Host 性能报告](PROJECT_REFACTOR_UI_PERFORMANCE.md)。

这些执行工件保存在本地，不随产品源码分发。原始报告 SHA 和 JSON Pointer 用于追溯具体观测；启动回执中的 PID 是命令启动器 PID，不是 `sked.exe` 的 PID。完整协议和限制见 [磁盘基准说明](../../benchmark/DATA_OPERATIONS.md)，项目结果见 [实施报告](PROJECT_REFACTOR_REPORT.md)。

## 全部 30 项操作

Comparison status: **comparable**.


| Case / raw JSON Pointer | wall ms | RSS before MiB | RSS after MiB | RSS delta MiB | AppData writes | pre-flush writes |
| --- | --- | --- | --- | --- | --- | --- |
| sparse/lifecycle.disk_load /results/0 | 28.357 → 29.584 (+4.33%) | 119.266 → 120.957 (+1.42%) | 123.746 → 125.859 (+1.71%) | 4.48047 → 4.88672 (delta +0.40625; no percent) | 0 → 0 (delta +0; no percent) | unavailable |
| sparse/student.edit_commit /results/1 | 24.801 → 17.311 (-30.20%) | 130.039 → 132.285 (+1.73%) | 132.438 → 133.949 (+1.14%) | 2.39844 → 1.66016 (delta -0.738281; no percent) | 1 → 1 (+0.00%) | unavailable |
| sparse/general.edit_commit /results/2 | 29.903 → 17.574 (-41.23%) | 123.875 → 119.965 (-3.16%) | 120.539 → 121.797 (+1.04%) | -4.23047 → 1.83203 (delta +6.0625; no percent) | 1 → 1 (+0.00%) | unavailable |
| sparse/settings.save /results/3 | 31.034 → 19.584 (-36.90%) | 128.453 → 127.98 (-0.37%) | 114.25 → 116.348 (+1.84%) | -14.2031 → -12.0898 (delta +2.11328; no percent) | 1 → 1 (+0.00%) | unavailable |
| sparse/backup.export /results/4 | 3.215 → 3.656 (+13.72%) | 122.789 → 123.953 (+0.95%) | 123.887 → 125.203 (+1.06%) | 1.09766 → 1.31641 (delta +0.21875; no percent) | 0 → 0 (delta +0; no percent) | unavailable |
| sparse/timetables.import_end_to_end /results/5 | 59.598 → 39.571 (-33.60%) | 118.941 → 120.527 (+1.33%) | 113.273 → 127.484 (+12.55%) | -4.73828 → 7.43359 (delta +12.1719; no percent) | 1 → 1 (+0.00%) | unavailable |
| sparse/general.json_import_end_to_end /results/6 | 47 → 29.078 (-38.13%) | 116.965 → 116.719 (-0.21%) | 121.277 → 118.73 (-2.10%) | 4.32031 → 2.88281 (delta -1.4375; no percent) | 1 → 1 (+0.00%) | unavailable |
| sparse/general.ics_import_end_to_end /results/7 | 58.026 → 34.169 (-41.11%) | 119.578 → 119.305 (-0.23%) | 124.016 → 122.383 (-1.32%) | 4.4375 → 3.08203 (delta -1.35547; no percent) | 1 → 1 (+0.00%) | unavailable |
| sparse/backup.restore_end_to_end /results/8 | 191.39 → 183.851 (-3.94%) | 124.777 → 124.738 (-0.03%) | 124.422 → 125.809 (+1.11%) | 0.65625 → 1.07031 (delta +0.414062; no percent) | 1 → 1 (+0.00%) | unavailable |
| sparse/shutdown.flush /results/9 | 27.264 → 16.684 (-38.81%) | 121.234 → 121.637 (+0.33%) | 123.914 → 123.496 (-0.34%) | 2.625 → 1.85547 (delta -0.769531; no percent) | 1 → 1 (+0.00%) | 0 → 0 (delta +0; no percent) |
| 1000/lifecycle.disk_load /results/10 | 709.266 → 733.352 (+3.40%) | 117.723 → 123.227 (+4.68%) | 128.098 → 135.023 (+5.41%) | 6.59375 → 11.7969 (delta +5.20312; no percent) | 0 → 0 (delta +0; no percent) | unavailable |
| 1000/student.edit_commit /results/11 | 417.48 → 70.001 (-83.23%) | 145.488 → 150.625 (+3.53%) | 132.555 → 135.094 (+1.92%) | -12.9336 → -15.5312 (delta -2.59766; no percent) | 1 → 1 (+0.00%) | unavailable |
| 1000/general.edit_commit /results/12 | 554.288 → 81.508 (-85.30%) | 150.074 → 168.188 (+12.07%) | 143.625 → 150.352 (+4.68%) | -6.96875 → -17.8359 (delta -10.8672; no percent) | 1 → 1 (+0.00%) | unavailable |
| 1000/settings.save /results/13 | 447.168 → 88.123 (-80.29%) | 152.094 → 167.562 (+10.17%) | 139.438 → 140.629 (+0.85%) | -22.1719 → -26.1836 (delta -4.01172; no percent) | 1 → 1 (+0.00%) | unavailable |
| 1000/backup.export /results/14 | 11.208 → 19.697 (+75.74%) | 150.855 → 169.656 (+12.46%) | 150.793 → 130.699 (-13.33%) | 0.390625 → -32.1602 (delta -32.5508; no percent) | 0 → 0 (delta +0; no percent) | unavailable |
| 1000/timetables.import_end_to_end /results/15 | 1621.31 → 843.171 (-47.99%) | 153.148 → 143.074 (-6.58%) | 144.914 → 154.805 (+6.83%) | -8.37109 → 5.375 (delta +13.7461; no percent) | 1 → 1 (+0.00%) | unavailable |
| 1000/general.json_import_end_to_end /results/16 | 1372.75 → 573.769 (-58.20%) | 135.902 → 146.809 (+8.03%) | 157.793 → 154.656 (-1.99%) | 14.4531 → 10.3477 (delta -4.10547; no percent) | 1 → 1 (+0.00%) | unavailable |
| 1000/general.ics_import_end_to_end /results/17 | 1691.75 → 781.065 (-53.83%) | 146.734 → 149.836 (+2.11%) | 154.312 → 154.07 (-0.16%) | 7.57812 → 11.0508 (delta +3.47266; no percent) | 1 → 1 (+0.00%) | unavailable |
| 1000/backup.restore_end_to_end /results/18 | 3114.9 → 2750.12 (-11.71%) | 161.578 → 152.684 (-5.50%) | 176.457 → 178.504 (+1.16%) | 16.4102 → 28.9062 (delta +12.4961; no percent) | 1 → 1 (+0.00%) | unavailable |
| 1000/shutdown.flush /results/19 | 436.393 → 98.545 (-77.42%) | 156.695 → 176.027 (+12.34%) | 161.438 → 160.234 (-0.75%) | 5.60938 → -16.4727 (delta -22.082; no percent) | 1 → 1 (+0.00%) | 0 → 0 (delta +0; no percent) |
| 5000/lifecycle.disk_load /results/20 | 3421.47 → 3656.1 (+6.86%) | 141.285 → 145.094 (+2.70%) | 203.949 → 187.527 (-8.05%) | 61.1484 → 42.4336 (delta -18.7148; no percent) | 0 → 0 (delta +0; no percent) | unavailable |
| 5000/student.edit_commit /results/21 | 1996.65 → 295.915 (-85.18%) | 199.332 → 205.828 (+3.26%) | 204.18 → 214.555 (+5.08%) | 3.27734 → 8.69531 (delta +5.41797; no percent) | 1 → 1 (+0.00%) | unavailable |
| 5000/general.edit_commit /results/22 | 2648.05 → 366.086 (-86.18%) | 208.883 → 193.156 (-7.53%) | 211.379 → 200.336 (-5.22%) | 3.15234 → 7.27344 (delta +4.12109; no percent) | 1 → 1 (+0.00%) | unavailable |
| 5000/settings.save /results/23 | 2053.27 → 363.88 (-82.28%) | 208.535 → 198.887 (-4.63%) | 217.168 → 203.934 (-6.09%) | 8.63281 → 9.34375 (delta +0.710938; no percent) | 1 → 1 (+0.00%) | unavailable |
| 5000/backup.export /results/24 | 58.406 → 83.45 (+42.88%) | 212.312 → 195.059 (-8.13%) | 214.43 → 174.344 (-18.69%) | 2.17188 → -20.4297 (delta -22.6016; no percent) | 0 → 0 (delta +0; no percent) | unavailable |
| 5000/timetables.import_end_to_end /results/25 | 8058.15 → 4382.13 (-45.62%) | 247.195 → 218.98 (-11.41%) | 267.262 → 256.535 (-4.01%) | 34.6484 → 37.0938 (delta +2.44531; no percent) | 1 → 1 (+0.00%) | unavailable |
| 5000/general.json_import_end_to_end /results/26 | 6763.2 → 2872.07 (-57.53%) | 235.152 → 236.535 (+0.59%) | 259.348 → 263.09 (+1.44%) | 24.1953 → 26.5547 (delta +2.35938; no percent) | 1 → 1 (+0.00%) | unavailable |
| 5000/general.ics_import_end_to_end /results/27 | 8429.43 → 3916.7 (-53.54%) | 238.855 → 249.957 (+4.65%) | 284.031 → 279.883 (-1.46%) | 33.5898 → 28.6797 (delta -4.91016; no percent) | 1 → 1 (+0.00%) | unavailable |
| 5000/backup.restore_end_to_end /results/28 | 15105.9 → 13825.2 (-8.48%) | 249.566 → 248.406 (-0.46%) | 362.66 → 341.523 (-5.83%) | 66.6641 → 91.4688 (delta +24.8047; no percent) | 1 → 1 (+0.00%) | unavailable |
| 5000/shutdown.flush /results/29 | 2175.42 → 481.576 (-77.86%) | 229.516 → 266.539 (+16.13%) | 294.414 → 267.156 (-9.26%) | 37.5938 → 0.34375 (delta -37.25; no percent) | 1 → 1 (+0.00%) | 0 → 0 (delta +0; no percent) |

Output size/hash, import counts and timing diagnostics remain in summary.json and the separate original reports. A blank applicability is written as unavailable, never zero.

| Scope | report wall ms | launcher wall ms | process max RSS MiB |
| --- | --- | --- | --- |
| whole process | 132771 → 114104 (-14.06%) | 154474 → 130008 (-15.84%) | 434.191 → 447.25 (+3.01%) |


| Run | revision | raw report | SHA-256 | launcher PID | AXTree rejections |
| --- | --- | --- | --- | --- | --- |
| disk30/before/r1 | 77061b4172ef | [raw report](<D:/Project/Flutter/sked/build/benchmarks/data-before/r1/data-operations-before.json>) | e0d84119839ecb9c4afce4116156101c92a69e2e33e11d150998a087fb0a3b1b | 86900 | 0 |
| disk30/before/r2 | 77061b4172ef | [raw report](<D:/Project/Flutter/sked/build/benchmarks/data-before/r2/data-operations-before.json>) | 7381e440255a3522ea7d6f30f95970ce6e0ac1bbdc76e4bc58cf8f1ef658b445 | 80884 | 0 |
| disk30/before/r3 | 77061b4172ef | [raw report](<D:/Project/Flutter/sked/build/benchmarks/data-before/r3/data-operations-before.json>) | 6481cad2af7865d6bb8515ba20d8a533965544772b96aafaf2241b1f7287963d | 4332 | 0 |
| disk30/after/r1 | 1205c6ed0816 | [raw report](<D:/Project/Flutter/sked/build/benchmarks/data-after/r1/data-operations-after.json>) | eb8bf8572d0b3a26b1e26bb45c8623bf791aeec1ebb2470d215dc067fa7b4cc4 | 45316 | 0 |
| disk30/after/r2 | 1205c6ed0816 | [raw report](<D:/Project/Flutter/sked/build/benchmarks/data-after/r2/data-operations-after.json>) | 1e1ae4029ee39dc08b70476beca9c433d909db7628961e3625260762770397f0 | 104160 | 0 |
| disk30/after/r3 | 1205c6ed0816 | [raw report](<D:/Project/Flutter/sked/build/benchmarks/data-after/r3/data-operations-after.json>) | 52148f72ff0d53a45a2bf0cb7dc927167e7cbfc3fb097a2f26084bc0a1120ad9 | 61716 | 0 |

Native accessibility acceptance is **not established by this comparison**. AXTree log rejections are retained per run; zero recorded errors alone is not an accessibility pass.

Limitations and interpretation:

- Three independent processes per side are descriptive repeats; they do not establish statistical significance or causality.
- Revision defines identify the declared production checkout; shared benchmark sources and adapters are recorded separately.
- Runtime equality does not prove identical background load, power state, thermal conditions, CPU model, Flutter engine or executable bytes.
- RSS is whole-process resident memory at action boundaries; its delta is not allocation or per-action peak memory.
- Benchmark validation and absence of log errors do not establish native accessibility acceptance.
- Launcher receipts identify the command launcher PID, not sked.exe's PID. Legacy reports have neither.
- One wall-time sample exists per action/dataset/process; no frame or editor-input latency was measured.
- Disk load follows seed creation, so OS page cache may be warm; this is not process-cold startup.
- Backup outputSha256 contains exported timestamp effects and is preserved as an outcome, not an input equality gate.
- navigationWritesBeforeFlush is a timing-boundary diagnostic; successful AppData writes exclude site/journal write counts.
- The launcher did not store a report hash; this comparison hashes the preserved report linked by path, revision and interval.
