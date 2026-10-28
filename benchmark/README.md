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

The report is written to
`build/benchmarks/windows-host-<label>.json`.

## Focused strict date parsing comparison

`date_parsing_benchmark_test.dart` measures the 10,000 start/end fields from
the fixed 5,000-event fixture, its 42-day cold occurrence query, and a hot-cache
control. It uses the same calibration, five warm-ups, eleven samples and
three-process comparison protocol. Valid fixture dates are checked against
the native ISO parser before and after timing; occurrence checksums stay fixed.
Set `SKED_BENCHMARK_OUTPUT_DIR` to a system temporary directory when collecting
local evidence. Compare a production baseline and candidate with the identical
benchmark source, and do not infer allocation counts from timing alone.

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
$env:FLUTTER_TEST_OUTPUTS_DIR = "$PWD\build\benchmarks\android-local-r1"
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
