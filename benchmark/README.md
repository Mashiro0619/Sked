# Performance benchmarks

This suite measures the performance-sensitive paths covered by phase 8. It is
not a CI timing gate. Correctness is enforced by fixed workload checksums and
unit tests; timings are evidence for engineering decisions and must only be
compared between runs from the same environment.

Fresh Windows process startup, visible readiness, input response, and four
whole-process RSS observations use the separate [startup protocol](STARTUP.md).
Its memory samples include precise observation times, read costs, entry-to-ready
and entry-to-end changes, and the process lifetime peak through measurement end.
These are separate from this suite's warmed host JIT and UI frame workloads.

The current runtime no longer has a remote privacy-version service to replace
with an offline fake. Older baselines must retain their own frozen runtime
adapters and dependency isolation; do not apply current composition changes to
historical comparison samples without recording and validating the adaptation.

## Protocol

- Fixtures are built before timing and contain 1,000/5,000 calendar events,
  5,000 courses, 128 school sites, and table HTML near the 240,000-code-unit
  input limit.
- Each case verifies its checksum, calibrates a batch toward 250 ms, runs five
  warm-up batches, then records eleven samples.
- Reports contain raw samples, median, median absolute deviation, minimum,
  workload metadata, and checksums.
- Run three independent processes for each side of a comparison. Compare the
  median of those three per-process medians.
- Windows host JIT and Android profile AOT results are separate populations.
  Never compare their absolute values with each other.
- Do not add absolute millisecond pass/fail thresholds to CI.

## Windows host JIT

```powershell
$revision = (git rev-parse --short=12 HEAD).Trim()
flutter test benchmark/performance_benchmark_test.dart `
  --concurrency=1 --timeout=none --reporter=expanded `
  --dart-define=SKED_BENCHMARK_LABEL=local-r1 `
  --dart-define=SKED_BENCHMARK_REVISION=$revision
```

The report is written as `windows-host-<label>.json` in a unique system temporary
directory. `SKED_CAPTURE_OUTPUT` and `Benchmark report:` log its absolute path.
Set `--dart-define=SKED_BENCHMARK_OUTPUT_DIR=<absolute-directory>` to collect
multiple named reports in a chosen location. Explicit directories and existing
artifacts are retained; relative overrides are rejected.

## Durable preference write batching

`preference_write_batch_benchmark_test.dart` uses a fixed 5,000-event snapshot
and the real `AppRuntime` settings commands with `IoTimetableStorage`. The
reference leaves the optional preference callback unconnected, preserving the
ordinary complete-snapshot path in the same source. The candidate connects it.
This comparison isolates batching; it is not a historical binary comparison.

Each new process runs a single preference, five disjoint preferences, and five
successive edits to the same field. Every case has five warm-ups and eleven
one-sequence samples; disk sequences are not calibrated to 250 ms. Field values
alternate so every command changes its requested preference. After every
sequence, validation checks the complete ordered snapshots passed to successful
disk saves, the session/repository snapshot, and a new storage instance's full
readback. Single and same-field controls retain one and five writes respectively;
the five disjoint commands may share one transaction.

Use `SKED_BENCHMARK_COALESCING=false` for the reference and `true` for the
candidate. `SKED_BENCHMARK_VERIFY_ONLY=true` performs one protocol operation per
case with no warm-up and explicitly labels it as verification, not performance
evidence. Reports use the normal `SKED_BENCHMARK_LABEL`,
`SKED_BENCHMARK_REVISION` and absolute `SKED_BENCHMARK_OUTPUT_DIR` options.

Timing starts at command invocation and stops after every command future
completes. Seed creation, load, checksums, independent readback, memory reads and
cleanup are outside the measured sequence. AppData, journal and school-site
paths use synthetic temporary directories and the secret store is empty in
memory. Production flush, verification and rename remain enabled; the OS page
cache may be warm. Reports preserve each elapsed time, write count, before/after
whole-process RSS and process-lifetime maximum. RSS is neither Dart allocation
count nor a per-sequence peak. These host JIT results do not measure UI frames,
native startup, Android devices or power-loss recovery.

The 2026-10-28 comparison used six fresh Windows host JIT processes in ABBAAB
order, with the same source, runtime metadata, 1,600,623-byte seed snapshot and
full result checksums. The clean window was 15:24:58–15:30:54 UTC+08:00; other
SDK jobs and directory enumeration were stopped. A preceding window was
interrupted after a reported concurrent directory scan and excluded in full,
including both completed results. Its raw evidence was retained separately.

| Command sequence (ms) | Reference process medians | Candidate process medians | Median change | Writes per sequence |
| --- | --- | --- | ---: | --- |
| One preference | 87.656 / 83.780 / 83.021 | 81.759 / 80.872 / 80.496 | −3.47% | 1 → 1 |
| Five disjoint preferences | 422.599 / 426.882 / 435.054 | 76.273 / 78.444 / 76.703 | −82.03% | 5 → 1 |
| Five edits to one field | 440.293 / 446.042 / 425.284 | 403.543 / 410.414 / 388.751 | −8.35% | 5 → 5 |

The five disjoint requests completed about 350 ms sooner in this workload,
with all their fields in the shared durable snapshot. The controls preserve
their original write counts; their lower recorded times are not attributed to
coalescing. Cases run in a fixed order, and preceding write counts can affect
process and garbage-collection state. The result applies to eligible queued
commands; a single edit, already started write or overlapping field does not
receive the five-to-one reduction.

Only the five explicitly declared preference command types participate.
Course saves, general event saves and recurring-instance edits still use
individual snapshot writes. This benchmark does not measure or establish a
latency or throughput improvement for those editing paths.

For the disjoint case, the three process medians of post-sequence RSS were
295.90 / 295.65 / 304.45 MiB for the reference and 315.03 / 303.90 / 308.63 MiB
for the candidate. The candidate's observed endpoints were higher; fewer
writes do not establish lower resident memory or fewer allocations. Lifetime
process peaks across the entire protocol were 395.89 / 442.50 / 400.17 MiB and
409.48 / 443.00 / 400.42 MiB respectively, with substantial overlap. Raw RSS
before/after values and negative as well as positive deltas are retained in
every report. The batching change is retained for its scoped durable latency
and write-count reduction, without claiming a memory improvement.

## Focused strict date parsing comparison

`date_parsing_benchmark_test.dart` measures the 10,000 start/end fields from
the fixed 5,000-event fixture, its 42-day cold occurrence query, and a hot-cache
control. It uses the same calibration, five warm-ups, eleven samples and
three-process comparison protocol. Valid fixture dates are checked against
the native ISO parser before and after timing; occurrence checksums stay fixed.
This target uses the same temporary default and absolute
`SKED_BENCHMARK_OUTPUT_DIR` override as the host suite. Compare a production
baseline and candidate with the identical benchmark source, and do not infer
allocation counts from timing alone.

The 2026-10-28 Windows host JIT comparison used `4f3011e` as the production
baseline. The candidate only moved the strict ISO RegExp factory call to a
top-level final field with the same pattern. Six new processes ran serially in
ABBAAB order, each using the protocol above; other project validation jobs were
stopped during this window. All workload checksums, fixture metadata and runtime
metadata matched. The host was Windows 11 x64, Dart 3.13.5, 32 logical processors.

| Case | Baseline process medians | Candidate process medians | Median change |
| --- | --- | --- | ---: |
| 10,000 strict ISO fields (ms/op) | 18.068 / 18.402 / 19.544 | 19.662 / 18.843 / 16.728 | +2.40% |
| 5,000 events, 42-day cold query (ms/op) | 16.685 / 17.138 / 16.676 | 18.070 / 16.175 / 17.682 | +5.97% |
| 5,000 events, 180-day hot cache (µs/op) | 0.163 / 0.162 / 0.176 | 0.173 / 0.163 / 0.164 | +0.71% |

These overlapping samples do not establish a stable benefit, so the production
candidate was not retained. Separately, 10,000 identical RegExp constructions
returned one object identity on this runtime; the factory call's location alone
does not prove a new allocation per date. This conclusion concerns this host and
candidate, not all Dart runtimes or all RegExp workloads.

## Focused event-cache comparison

`event_cache_benchmark_test.dart` compares the first 42-day query, two successive
single-event edits with one or three 42-day windows, and an exact hot-query
control over the fixed 5,000-event fixture. The edited and unedited snapshots
are normalized before measurement; the actual calendar save command creates
the edited state, and a precheck requires 4,999 unchanged event identities.
The snapshots alternate within each operation. Both complete results, including
their order, are checked against uncached queries before and after timing.
`SKED_BENCHMARK_VERIFY_ONLY=true` runs a one-operation protocol check and labels
its report `verification-only`; those timings are not performance evidence.

Reports use the same unique system temporary default and absolute
`SKED_BENCHMARK_OUTPUT_DIR` override as the host suite.

Event reuse keys retain the event identity and exact start/end instants plus
their UTC/local representation. Repeated events do not borrow a containing
range. Cached geometry is rebound to the current calendar before the original
global sort and filtering; mutable exception lists are checked on lookup.
Retention is restricted to geometry independent of the process's local
timezone: start/end must have an explicit UTC offset, a repeating UNTIL must
also have an explicit offset if present, and repeating all-day events require
a UTC query start. Floating events, floating UNTIL values and local all-day
query arithmetic use the original expansion path. They do not receive this
cross-snapshot acceleration. Equal current offsets do not establish equal
historical timezone rules.
The default cache retains at most 20,000 entries and 250,000 values (occurrences
plus exception strings), evicts least-recently-used entries, and drops removed
events. Oversized expansions are returned in full without being retained.
Injected occurrence services continue to own their existing query behavior.

The historical unguarded 2026-10-28 Windows host JIT comparison used the
unchanged expansion strategy
at `b328481` and the bounded cache candidate, with identical benchmark sources.
Six new processes ran in ABBAAB order while other project validation jobs were
stopped. All four complete-result checksums, normalized fixture metadata and
runtime metadata matched. The host was Windows 11 x64, Dart 3.13.5, 32 logical
processors. These are query timings, not editor save latency or rendered frames.

| Case | Baseline process medians | Candidate process medians | Median change |
| --- | --- | --- | ---: |
| First 42-day query (ms/op) | 20.247 / 21.475 / 22.017 | 22.909 / 24.895 / 25.843 | +15.93% |
| Two snapshots, one 42-day query each (ms/op) | 43.593 / 43.835 / 44.803 | 3.094 / 3.351 / 3.391 | −92.36% |
| Two snapshots, three 42-day queries each (ms/op) | 139.686 / 141.920 / 144.486 | 13.286 / 14.651 / 13.941 | −90.18% |
| Exact hot query (µs/op) | 0.189 / 0.192 / 0.189 | 0.205 / 0.223 / 0.222 | +17.05% |

These measurements describe the superseded unguarded candidate `b0d8367`.
Review found stale local geometry after a process timezone change followed by
an unrelated event edit; separate-process timezone tests did not detect it.
The first query costs about 3.42 ms more at the median to populate the cache;
the hot-query difference is about 0.032 µs. Three repeats describe this workload
and do not establish a universal platform or UI performance improvement. The
entry/value limits bound retained geometry, not the application's total RSS.

The timezone-switch regression runs alone in a Linux test process, explicitly
enabled with `SKED_TEST_TIMEZONE_SWITCH=1 flutter test --no-pub --concurrency=1
test/services/general_event_cache_timezone_switch_test.dart`. It changes only
that process's TZ and restores it afterward. It checks New York/Detroit
historical rules with equal current offsets, and Apia's skipped date with a
floating UNTIL. Normal Windows runs skip this Linux-only test.

The corrected comparison ran six new processes on 2026-10-28,
12:23:48–12:28:23 UTC+08:00, with the same exclusive ABBAAB protocol. It adds
5,000 floating events as a bypass control, preserving 4,999 event identities
across a real edit in each dataset. All six complete-result checksums and all
runtime/dataset metadata matched across the six processes; shared source
hashes stayed fixed. Each case used five warm-ups and eleven measured batches.

| Case | Baseline process medians | Guarded cache process medians | Median change |
| --- | --- | --- | ---: |
| UTC first 42-day query (ms/op) | 17.337 / 17.484 / 17.486 | 19.908 / 20.245 / 21.070 | +15.79% |
| UTC two snapshots, one query each (ms/op) | 33.778 / 35.193 / 34.815 | 4.849 / 4.622 / 4.522 | −86.72% |
| UTC two snapshots, three queries each (ms/op) | 107.288 / 113.149 / 110.926 | 18.021 / 17.398 / 17.981 | −83.79% |
| UTC exact hot query (µs/op) | 0.160 / 0.169 / 0.164 | 0.181 / 0.178 / 0.175 | +8.06% |
| Floating first 42-day query (ms/op) | 171.366 / 174.543 / 173.387 | 173.686 / 168.728 / 171.070 | −1.34% |
| Floating two snapshots, one query each (ms/op) | 352.284 / 352.926 / 349.562 | 348.377 / 343.950 / 341.027 | −2.37% |

The guarded cache retains the large reduction for eligible events, at a first
query cost of about 2.76 ms and hot-hit difference of about 0.013 µs in this
workload. Floating results overlap across repeats and do not establish an
improvement: that path deliberately recomputes. Date-only UNTIL values also
bypass retention, including normalized product events with an end date. These
are Windows host JIT query results, without a UI-frame, device or save-latency
claim; they do not compare timings across the two separate measurement windows.

## Indexed reminder preparation

Run `flutter test --no-pub --concurrency=1 --reporter=expanded
benchmark/indexed_reminder_cache_benchmark_test.dart` for the indexed reminder
workload. It uses 100 daily events, a 129-day reminder lead and 6,000 earlier
handled occurrences, normalized through the production model. The controls
cover a first query, four distinct instants within one minute, four separate
minutes, and an exact hot query. Every result row is checked outside timing,
including status, occurrence key, end time, sequence and owner metadata.
`SKED_BENCHMARK_VERIFY_ONLY=true` runs protocol checks without performance
claims. Output defaults to a unique system temporary directory;
`SKED_BENCHMARK_OUTPUT_DIR` overrides must be absolute.

Only filtering, effective lead times and handled-key lookup are reused for the
minute. Each changed instant still builds the original precise recurrence
range and status sections. Source calendar/event identities and reminder,
exception and history list contents are checked before a result hit; raw list
aliases cannot preserve stale preparation. Minute, representation, settings,
query-window and filter changes replace the single retained preparation.
Custom injected services retain their existing indexed query entry point.
The final lazy result keeps its existing 256-row limit; the input snapshot is
proportional to the current input, without retaining a history of minutes.

On 2026-10-28, 12:54:45–12:58:31 UTC+08:00, six independent Windows host JIT
processes ran in exclusive ABBAAB order. The baseline has the preparation API
but builds it afresh for each exact-time miss. Only the occurrence-cache
implementation differs; benchmark, model, service and helper hashes are fixed.
All four full-result checksums, runtime metadata and normalized dataset values
match in all six reports. Each case uses five warm-ups and eleven samples.

| Case | Baseline process medians | Prepared-cache process medians | Median change |
| --- | --- | --- | ---: |
| First query (ms/op) | 22.677 / 20.668 / 21.120 | 20.767 / 21.046 / 21.039 | −0.39% |
| Four same-minute queries (ms/op) | 91.403 / 82.361 / 83.782 | 60.897 / 65.494 / 62.083 | −25.90% |
| Four separate-minute queries (ms/op) | 94.716 / 82.928 / 81.625 | 84.748 / 83.947 / 84.080 | +1.39% |
| Exact hot query (µs/op) | 0.140 / 0.140 / 0.136 | 14.250 / 13.401 / 14.291 | +10090.60% |

Same-minute queries save about 21.70 ms per four-query operation at the median.
First and separate-minute samples overlap and do not show a stable improvement.
The exact hot path adds about 14.11 µs to verify 6,000 history entries and event
inputs before reuse; this is a real regression, retained to observe mutable
source aliases as well as normal snapshots. This evidence covers Windows host
JIT query construction, without a device, rendered-frame or save-latency claim.
The Linux same-process timezone test also verifies that prepared input reuse
does not preserve old local occurrence times when TZ changes within a minute.

## Home field subscriptions

`flutter test --no-pub --concurrency=1 --reporter=expanded
benchmark/general_home_subscription_benchmark_test.dart` runs 100 events at
1280×900, text scale 1, in week/month/list views. Each sample makes four
settings or calendar-name changes, awaits their in-memory saves, then times
only widget pumps until settled. It uses five warm-ups and eleven fixed-size
samples rather than the service benchmark's 250 ms calibration. Visible text
and workspace-context checksums are verified, and home rebuild/pump counts
are recorded. The reminder clock and selected date are fixed to June 1, 2026.
The common output-directory helper and verification-only option apply.

The 2026-10-28 comparison ran six independent Windows widget-test JIT processes
in exclusive ABBAAB order, 13:16:19–13:20:43 UTC+08:00. Shared source hashes,
runtime/dataset metadata and all six result checksums matched. The source
change removes the broad `GeneralViewState` subscription inside the home
frame helper, allowing its existing field selector to control home rebuilds.
Reminder strips, timelines and supporting panels retain their own listeners.

| View/update, four changes (ms/op) | Baseline process medians | Field-selector process medians | Median change |
| --- | --- | --- | ---: |
| Week, popup setting | 290.956 / 209.030 / 168.266 | 85.182 / 78.567 / 79.085 | −62.17% |
| Week, visible calendar name | 304.605 / 208.576 / 180.753 | 204.749 / 248.931 / 199.102 | −1.83% |
| Month, popup setting | 155.584 / 138.096 / 111.082 | 41.385 / 50.322 / 34.891 | −70.03% |
| Month, visible calendar name | 400.111 / 315.099 / 258.473 | 323.805 / 334.170 / 275.391 | +2.76% |
| List, popup setting | 181.170 / 115.695 / 95.636 | 30.388 / 35.443 / 24.809 | −73.73% |
| List, visible calendar name | 230.100 / 160.293 / 142.533 | 161.652 / 171.110 / 137.386 | +0.85% |

All popup-setting cases reduce home rebuilds from four to zero; all visible
name controls retain four. Baseline timing drifts considerably across processes,
and visible-update samples overlap, so the percentages describe only this
instrumented test window. Popup samples remain separated across all three
processes, supporting reduced work in that scenario. These are widget-pump
costs after a memory save, not real-device frame rates or full save latency.
Regression tests also verify reminder-default updates, calendar visibility,
calendar names and date navigation remain live in all three views.

## Period-rail label measurements: candidate not retained

`flutter test --no-pub --concurrency=1 --reporter=expanded
benchmark/timetable_period_label_benchmark_test.dart` measures an empty grid
with preserved gaps: 12 normal 45-minute periods or 48 dense 25-minute periods.
It covers first mount, eight repeated layouts with unchanged labels, and eight
period-time edits. Each case uses five warm-ups and eleven fixed-size samples
without 250 ms calibration. Full rail/column geometry and rendered-text
checksums are verified. The surface is 1280×900, grid width 1120 and text scale 1.

The candidate retained one width measurement per grid, keyed by period values,
text styles, complete text scaler, direction and locale, with system-font
invalidation. It addressed the rail and did not restore the course-card
candidate `1d45d46`, which was previously withdrawn. The new comparison used
six independent Windows widget-test JIT processes in exclusive ABBAAB order,
2026-10-28 14:12:41–14:14:42 UTC+08:00. All checksums, runtime/dataset metadata
and shared-source hashes matched.

| Case (ms/op) | Baseline process medians | Candidate process medians | Median change |
| --- | --- | --- | ---: |
| 12 periods, first mount | 31.346 / 29.080 / 30.308 | 34.202 / 32.322 / 30.819 | +6.65% |
| 12 periods, eight repeated layouts | 47.404 / 37.733 / 39.450 | 45.502 / 47.472 / 39.750 | +15.34% |
| 12 periods, eight edits | 67.763 / 57.740 / 63.806 | 70.300 / 76.214 / 64.306 | +10.18% |
| 48 periods, first mount | 46.383 / 47.465 / 45.706 | 43.958 / 43.855 / 42.286 | −5.45% |
| 48 periods, eight repeated layouts | 93.031 / 75.400 / 78.023 | 56.503 / 50.625 / 49.434 | −35.12% |
| 48 periods, eight edits | 147.952 / 108.664 / 109.065 | 105.935 / 115.607 / 107.376 | −1.55% |

The 48-period repeated-layout samples improve, but the common 12-period cases
show higher medians and no reliable benefit. The general cache candidate is
not retained, and production grid bytes were restored to the baseline. These
two fixture sizes do not establish a justified activation threshold. The
benchmark and all gains/regressions remain available; this is an evaluated,
unadopted candidate, without a claim that period layouts are now faster.

An earlier 10-minute fixture exposed an existing short-slot label overflow.
Ten-minute periods are valid input. That layout defect is handled separately
from this performance comparison, preserving time proportions and semantics.
The timings here describe widget-test pumps, not device frame rates or app RSS.
The separate short-slot correction now chooses labels by their actual height;
the table above predates that renderer and remains historical evidence.

## Android profile

Use a physical release-representative device for conclusions that influence
shipping decisions. Emulators are useful only for transport checks and
directional before/after evidence.

```powershell
$deviceId = Read-Host 'Android device ID from flutter devices'
$revision = (git rev-parse --short=12 HEAD).Trim()
$previousNoProxy = $env:NO_PROXY
$previousOutputs = $env:FLUTTER_TEST_OUTPUTS_DIR
$env:NO_PROXY = '127.0.0.1,localhost'
$androidBenchmarkOutput = Join-Path ([IO.Path]::GetTempPath()) ('sked-android-benchmark-' + [guid]::NewGuid().ToString('N'))
$env:FLUTTER_TEST_OUTPUTS_DIR = $androidBenchmarkOutput
flutter drive --profile -d $deviceId `
  --driver=test_driver/performance_benchmark_driver.dart `
  --target=integration_test/performance_benchmark_test.dart `
  --dart-define=SKED_BENCHMARK_LABEL=local-r1 `
  --dart-define=SKED_BENCHMARK_REVISION=$revision `
  --dart-define=SKED_BENCHMARK_RUNTIME=android-physical-device-profile `
  --no-enable-dart-profiling
if ($null -eq $previousOutputs) {
  Remove-Item Env:FLUTTER_TEST_OUTPUTS_DIR
} else {
  $env:FLUTTER_TEST_OUTPUTS_DIR = $previousOutputs
}
if ($null -eq $previousNoProxy) {
  Remove-Item Env:NO_PROXY
} else {
  $env:NO_PROXY = $previousNoProxy
}
```

Set `SKED_BENCHMARK_RUNTIME=android-emulator-x86_64-profile` for emulator
runs. The localhost proxy bypass is required on hosts whose `HTTP_PROXY`
would otherwise intercept Flutter's VM service connection.

The benchmark drivers and native accessibility driver preserve an explicit
absolute `FLUTTER_TEST_OUTPUTS_DIR`. When it is absent or empty, each report uses
a unique system temporary directory and logs `SKED_CAPTURE_OUTPUT` with its
location. Relative overrides fail clearly. Report filenames, result validation
and measurement protocols remain unchanged; this only redirects custom reports,
not Flutter or Gradle build/cache output. Copy the shared
`test_driver/support/report_output_directory.dart` and
`integration_test/support/capture_output_directory.dart` alongside a driver when
adapting the same harness to an older checkout.

## Phase 8 evidence

Measurements on 2026-08-06 used Flutter 3.44.0 / Dart 3.12.0. Windows ran on
Windows 11 x64 with 32 logical processors. Android directional measurements
used an API 36 x86_64 emulator, not a physical device.

| Runtime | Metric | FIFO | LRU |
| --- | ---: | ---: | ---: |
| Windows host JIT | cache-churn service calls | 736 | 640 |
| Windows host JIT | cache-churn median (us/op) | 340.008 | 356.760 |
| Windows host JIT | hot-hit median (us/op) | 0.054 | 0.166 |
| Android emulator profile | cache-churn service calls | 736 | 640 |
| Android emulator profile | cache-churn median (us/op) | 354.421 | 361.911 |
| Android emulator profile | hot-hit median (us/op) | 0.082 | 0.183 |

The LRU policy reduced expensive service recomputations by 13.0% in the fixed
churn workload. Promotion makes a pure cache hit cost roughly 0.1 us more in
these environments. The seven non-serialization workload checksums remain
unchanged; the four AppData and app-backup checksums were refreshed for the
new persisted layout settings. The remaining timing differences were not
treated as causal evidence because they also appeared in unrelated encode,
decode, and sanitizer cases.

## Dataset version 5: persisted update preference

New AppData fixtures default to prerelease updates and explicitly serialize
`includePrereleaseUpdates: true`. Dataset version 5 refreshes only the four
AppData/app-backup serialization checksums for this added field; the seven
non-serialization checksums and workload record counts remain unchanged.
The fixture regression test removes the schema/display/update-preference
additions and still checks the original workload checksums. The timing results
above remain historical measurements, not new measurements of this dataset.
