# Startup preview experiment, 2026-10-28

The cold-start preview candidate was **not adopted**. Readable content appeared
earlier, but complete initialization did not consistently improve, memory did
not consistently decrease, and an initial-input delay repeated in a targeted
follow-up. Production retains its full storage load and original startup UI;
the unused preview API and storage split were removed.

## Source and protocol

Both experimental sides used source `02d7d846c6bd523221b1b9cbb2e7df23167b23e1`
plus the same 67-file overlay. Only the benchmark storage observer was disabled
or enabled. The candidate had an independent, read-only cold-start summary,
never replaced session or committed data, required the bundled privacy policy
to be accepted, and did not advance the authoritative load future, notification
readiness, or writable business UI. Ordinary retry kept its original path.

The retained complete candidate source archive contains 1,229 files and is
24,308,736 bytes; its SHA-256 is
`7200C5B17ED2067DC0072D8EF457481337FB3142D23195CEA4BBBB850C14B80E`.
Extraction into a separate directory reproduced every file byte-for-byte.
The source-overlay manifest SHA-256 is
`411444BA5DB93E1E3AAA6920F4878DB023458B1F546999E0FE9549FFD3400603`.
The complete native artifact trees, build commands, fixtures, original failed
window, 36-process window, 12-process follow-up and diagnostic reports were
retained with their own hashes. These local audit artifacts are not a published
release. Replaying the preview side requires that archived candidate source;
the current baseline benchmark has no production preview API.

Flutter 3.47.7 / Dart 3.13.5, Windows 11 build 26200, Profile mode, fresh processes,
retained OS caches, and isolated synthetic files were used. Each input group
contained sparse, 1,000 and 5,000 size classes; the 5,000 fixture contains 5,000
events and 5,000 courses. Main-only and main-plus-distinct-valid-backup fixtures
were measured separately. Every side used identical fixture bytes per group.
The original first-ready-raster report and date-cell input protocol remained
unchanged, including the 16 ms pointer hold. This is Flutter GestureBinding
input with native window visibility checks, not physical mouse/device evidence.

The complete window ran from 17:39:26.779 to 17:42:05.634 UTC+08:00 on 2026-10-28.
All 36 processes passed the clock, native visibility, memory, input, semantic,
notification-planning and physical-lock checks. All other work lines explicitly
stopped SDK and disk work. Source hashes matched before and after. Each table
cell below preserves the three process samples in repetition order; deltas use
their medians. Three samples do not support a useful p95 or general guarantee.

An earlier complete main-only group had 17 passing processes and one failed
launcher clock correlation (10,067 microseconds versus the unchanged 5,000
microsecond limit); its application child passed, and the backup group was not
started. That incomplete comparison remains separate. The valid window first
called the host UTC/Stopwatch APIs three times; it did not preload Sked or the
fixtures, relax the clock gate, or replace only a selected failed sample. The
retained failure alone does not prove a first-call runtime cause.

## Startup milestones

Values are milliseconds from OS process creation. “Readable” is an actual
engine-correlated raster containing the expected complete title and visible
glyphs on the current route. It is not the preview callback time. “Authority”
is the full storage result; “writable” is the original completed lifecycle;
“ready raster” is the original live-home frame.

| Input / size | Milestone | Before, three processes (ms) | Candidate, three processes (ms) | Median change |
| --- | --- | --- | --- | ---: |
| main-only / sparse | Readable | 588.031 / 580.201 / 640.064 | 565.613 / 456.766 / 571.214 | -3.81% |
| main-only / sparse | Authority | 466.439 / 430.15 / 549.727 | 547.678 / 440.044 / 473.869 | 1.59% |
| main-only / sparse | Writable | 483.575 / 438.57 / 555.947 | 573.256 / 456.947 / 481.116 | -0.51% |
| main-only / sparse | Ready raster | 588.031 / 580.201 / 640.064 | 671.141 / 552.884 / 571.214 | -2.86% |
| main-only / 1000 | Readable | 857.003 / 823.524 / 828.874 | 530.36 / 552.16 / 505.478 | -36.01% |
| main-only / 1000 | Authority | 525.47 / 508.971 / 511.244 | 526.406 / 548.299 / 501.88 | 2.97% |
| main-only / 1000 | Writable | 614.806 / 600.949 / 599.463 | 614.201 / 639.911 / 597.43 | 2.21% |
| main-only / 1000 | Ready raster | 857.003 / 823.524 / 828.874 | 842.42 / 885.338 / 808.294 | 1.63% |
| main-only / 5000 | Readable | 2334.734 / 2008.954 / 2235.289 | 935.445 / 999.187 / 980.669 | -56.13% |
| main-only / 5000 | Authority | 917.722 / 908.57 / 1071.285 | 916.288 / 999.105 / 981.641 | 6.96% |
| main-only / 5000 | Writable | 1430.085 / 1356.621 / 1517.048 | 1400.437 / 1462.784 / 1467.905 | 2.29% |
| main-only / 5000 | Ready raster | 2334.734 / 2008.954 / 2235.289 | 2104.64 / 2200.652 / 2159.669 | -3.38% |
| backup / sparse | Readable | 556.236 / 561.403 / 531.971 | 450.371 / 458.375 / 453.911 | -18.4% |
| backup / sparse | Authority | 448.544 / 458.918 / 436.141 | 453.419 / 457.763 / 444.561 | 1.09% |
| backup / sparse | Writable | 470.508 / 475.017 / 451.987 | 469.123 / 473.984 / 462.586 | -0.29% |
| backup / sparse | Ready raster | 556.236 / 561.403 / 531.971 | 548.883 / 553.81 / 544.132 | -1.32% |
| backup / 1000 | Readable | 911.315 / 860.978 / 906.341 | 515.662 / 512.323 / 495.098 | -43.47% |
| backup / 1000 | Authority | 593.38 / 586.108 / 593.773 | 607.218 / 589.609 / 575.738 | -0.64% |
| backup / 1000 | Writable | 691.198 / 672.382 / 686.687 | 698.427 / 677.955 / 666.867 | -1.27% |
| backup / 1000 | Ready raster | 911.315 / 860.978 / 906.341 | 933.623 / 898.542 / 856.217 | -0.86% |
| backup / 5000 | Readable | 2500.603 / 2388.55 / 2523.543 | 916.57 / 840.124 / 881.52 | -64.75% |
| backup / 5000 | Authority | 1324.464 / 1265.861 / 1368.213 | 1362.784 / 1259.495 / 1280.514 | -3.32% |
| backup / 5000 | Writable | 1788.01 / 1697.606 / 1817.496 | 1856.704 / 1717.845 / 1742.246 | -2.56% |
| backup / 5000 | Ready raster | 2500.603 / 2388.55 / 2523.543 | 2507.756 / 2454.772 / 2353.751 | -1.83% |

Seventeen of eighteen candidate processes rendered a preview. One main-only
sparse process went straight to the original ready frame. Of eight main-only
previews, only one raster preceded storage authority; seven of nine backup
previews preceded it, including every 1,000/5,000 backup sample. Thus the whole
readable improvement cannot be attributed only to deferred backup decoding.
Writable/complete initialization did not consistently improve: main-only
1,000/5,000 writable medians increased 2.21%/2.29%. This is not evidence of a
faster completed startup.

## Initial input and resident memory

Input time runs from the original pointer-down stamp to the response raster.
Ready RSS is observed when the ready raster report arrives. Peak RSS is the
process-lifetime maximum through measurement end, not preview-only allocation.

| Input / size | Metric | Before, three processes | Candidate, three processes | Median change |
| --- | --- | --- | --- | ---: |
| main-only / sparse | Input to response, ms | 135.325 / 34.83 / 89.393 | 103.017 / 105.474 / 94.517 | 15.24% |
| main-only / sparse | Ready RSS, MiB | 225.965 / 226.305 / 238.219 | 222.762 / 227.145 / 224.926 | -0.61% |
| main-only / sparse | Peak RSS, MiB | 246.402 / 237.684 / 240.129 | 243.262 / 244.23 / 244.07 | 1.64% |
| main-only / 1000 | Input to response, ms | 161.441 / 86.821 / 180.166 | 89.348 / 158.772 / 94.048 | -41.74% |
| main-only / 1000 | Ready RSS, MiB | 274.18 / 290.496 / 275.965 | 291.703 / 276.598 / 291.09 | 5.48% |
| main-only / 1000 | Peak RSS, MiB | 299.051 / 297.707 / 294.777 | 295.445 / 300.035 / 297.809 | 0.03% |
| main-only / 5000 | Input to response, ms | 174.06 / 553.735 / 153.757 | 465.26 / 177.683 / 201.231 | 15.61% |
| main-only / 5000 | Ready RSS, MiB | 443.094 / 409.145 / 437.754 | 410.082 / 443.289 / 444.371 | 1.26% |
| main-only / 5000 | Peak RSS, MiB | 479.441 / 462.438 / 470.48 | 483.941 / 470.785 / 469.715 | 0.06% |
| backup / sparse | Input to response, ms | 94.98 / 95.16 / 90.148 | 102.854 / 96.503 / 90.478 | 1.6% |
| backup / sparse | Ready RSS, MiB | 221.738 / 227.969 / 225.906 | 227.027 / 226.801 / 230.859 | 0.5% |
| backup / sparse | Peak RSS, MiB | 242.387 / 239.867 / 244.902 | 244.121 / 245.062 / 242.758 | 0.72% |
| backup / 1000 | Input to response, ms | 91.665 / 139.246 / 102.509 | 87.729 / 94.89 / 156.18 | -7.43% |
| backup / 1000 | Ready RSS, MiB | 291.227 / 278.848 / 287.824 | 289.762 / 290.383 / 275.18 | 0.67% |
| backup / 1000 | Peak RSS, MiB | 296.023 / 296.605 / 298.316 | 297.742 / 298.363 / 297.73 | 0.38% |
| backup / 5000 | Input to response, ms | 210.187 / 162.027 / 156.38 | 397.759 / 162.053 / 410.495 | 145.49% |
| backup / 5000 | Ready RSS, MiB | 451.102 / 443.977 / 439.254 | 409.383 / 437.676 / 412.098 | -7.18% |
| backup / 5000 | Peak RSS, MiB | 466.004 / 472.422 / 470.895 | 483.043 / 473.473 / 472.559 | 0.55% |

The 5,000-with-backup input median increased 145.49%. It was not dropped as an
outlier. Main-only 5,000 also contained high samples on both sides. Peak-RSS
medians increased in all six original groups; readiness endpoints moved in both
directions. There is no memory or input-responsiveness improvement claim.

## Targeted input follow-up and frame diagnosis

The same frozen binaries, source, backup/5,000 fixture, readiness point, input
sequence and acceptance thresholds were retested in two ABBAAB batches, with
six new processes per side. All twelve processes passed. This is a targeted
single-dataset supplement: the launcher's full three-dataset `matrixComplete`
flag remains false, while both three-process side groups are complete. The
original 36-process results were preserved separately.

| Follow-up batch | Before input to response (ms) | Candidate input to response (ms) | Median change |
| --- | --- | --- | ---: |
| all | 257.751 / 459.934 / 211.777 / 257.324 / 271.971 / 197.382 | 199.944 / 407.726 / 219.358 / 410.718 / 549.591 / 682.09 | 58.9% |
| 1 | 257.751 / 459.934 / 211.777 | 199.944 / 407.726 / 219.358 | -14.9% |
| 2 | 257.324 / 271.971 / 197.382 | 410.718 / 549.591 / 682.09 | 113.58% |

Across the original backup/5,000 group and the supplement, input preceded the
heavy frame immediately following the ready frame in six of nine candidate
processes versus one of nine references. Both sides had that heavy frame.
Different FrameTiming-report arrival phases changed whether input crossed it;
the reported regression remains a real wait in the tested first-input sequence.
Changing the input stamp, waiting for settlement, or discarding those samples
would hide the observation and was not done.

A separate diagnostic Profile build wrapped `BuildOwner.onBuildScheduled`,
delegated to the original callback, and recorded dirty widget types before the
first four loaded draws. Both diagnostic processes passed their operational
checks. Their timings are excluded from performance comparisons because stack
capture and tree traversal add overhead. Both showed the same cause chain:

`_scheduleStartupReminders` → `WorkspacePaneController.show/_showRoute` →
`notifyListeners` → `AnimatedBuilder`, scheduled by the first live-home
post-frame callback. The next draw in both cases had 88,754 elements, dirty
workspace/overlay/modal/details-host widgets, and then a
`_EventListDetailsHost._syncPortal` post-frame update. The preview did not issue
an extra business notification or open an extra reminder pane. This shared
startup presentation still interacted unfavorably with first-input timing in
the candidate. No GC trace was recorded; RSS alone cannot establish a GC cause.

The experiment was rejected without changing the automatic reminder feature,
readiness definition, or input timing to retain it. Current production storage,
repository and loading UI return to the original implementation. The result is
“design and measurement completed; candidate not adopted,” not “startup
optimized.” Physical-device, MSIX click and production-release acceptance remain
separate.

For future diagnosis, add `--dart-define=SKED_F5_BUILD_DIAGNOSTIC=true` to a separate
Profile build. Its report contains `diagnostic.build.scheduled` stacks and
`diagnostic.draw.dirty` counts. The child and launcher mark it diagnostic-only,
and it cannot become a completed performance matrix. Leave the flag absent for
the normal benchmark and keep every diagnostic artifact separate.
