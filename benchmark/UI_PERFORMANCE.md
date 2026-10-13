# Workspace interaction performance

`integration_test/ui_performance_benchmark_test.dart` runs production Provider,
adaptive workspace shell, calendar/timetable views and settings widgets. Only
storage, secrets, school sites, recovery journals and notifications use isolated
in-memory implementations. The target never opens the user's data directory.
It retains the production 450 ms UI-state save debounce. Native notification,
startup update, filesystem and serialization performance are outside this UI
suite; keep the existing pure-data benchmark alongside it.

## Run

Use a profile build on the same Windows machine or physical Android device for
both revisions. Debug widget tests validate the journey but cannot produce frame
performance evidence. There are no timing assertions in CI.

```powershell
$uiPerfRevision = (git rev-parse --short=12 HEAD).Trim()
$uiPerfOldNoProxy = $env:NO_PROXY
$uiPerfOldOutputs = $env:FLUTTER_TEST_OUTPUTS_DIR
try {
  $env:NO_PROXY = '127.0.0.1,localhost'
  $env:FLUTTER_TEST_OUTPUTS_DIR = "$PWD\build\benchmarks\ui"
  flutter drive --profile -d windows `
    --driver=test_driver/ui_performance_benchmark_driver.dart `
    --target=integration_test/ui_performance_benchmark_test.dart `
    --dart-define=SKED_UI_PERF_LABEL=before-r1 `
    --dart-define=SKED_UI_PERF_REVISION=$uiPerfRevision
} finally {
  if ($null -eq $uiPerfOldNoProxy) {
    Remove-Item Env:NO_PROXY -ErrorAction SilentlyContinue
  } else {
    $env:NO_PROXY = $uiPerfOldNoProxy
  }
  if ($null -eq $uiPerfOldOutputs) {
    Remove-Item Env:FLUTTER_TEST_OUTPUTS_DIR -ErrorAction SilentlyContinue
  } else {
    $env:FLUTTER_TEST_OUTPUTS_DIR = $uiPerfOldOutputs
  }
}
```

Replace `windows` with the Android device ID for physical-device measurements.
The JSON is `build/benchmarks/ui/ui-performance-before-r1.json`. Repeat in three
independent processes with distinct labels on each revision, keeping the device,
display refresh rate, window size, system scaling and power mode unchanged.
Do not compare Windows and Android absolute numbers.

Optional defines keep local diagnosis short:

- `SKED_UI_PERF_DATASETS=sparse,1000,5000` (default), or a subset such as `1000`.
- `SKED_UI_PERF_WARM_RUNS=1` (default), from 0 to 5 additional journeys.
- `SKED_UI_PERF_LABEL` accepts 1–80 filename-safe letters, digits, dots, `_`, `-`.
- `SKED_UI_PERF_REVISION` identifies the measured production revision.

The harness is independent of production implementation changes: copy its
`benchmark/src/ui_performance_*.dart`, integration target and driver onto an
older checkout with the existing `PerformanceFixtures` API to capture a baseline.

## Workload and report interpretation

The 1,000/5,000 event datasets reuse the existing fixed recurrence fixtures.
Sparse takes three events from each of their eight calendars (24 events).
Timetables contain 60/1,000/5,000 total courses respectively. Each dataset starts
with a fresh Provider, a six-week August 2026 month, Chinese lunar labels and
enabled weekends. Fixture creation occurs outside measured windows.

Each journey performs month swipes in both directions, a month scroll in a
short viewport, day/week/list navigation and scrolling, workspace switches,
timetable switches and scrolling, student day view, and a persisted display
setting toggled twice. Gestures assert that the selected month, timetable,
workspace, setting or scroll position actually changes. When a sparse list fits
the viewport its report explicitly says `content-fits-viewport`.

Windows uses up to a 1280×720 logical content surface (bounded by the native
window) and a 360-high scroll scenario;
Android uses its native logical surface and a 360-high scroll scenario. The
window and native display sizes, DPR and reported refresh rate accompany every
report. The native frame budget uses that refresh rate, falling back to 60 Hz
only when the engine supplies no valid value.

`cold` is the first journey with a new Provider, not a promise of cold shader or
global font/lunar caches. Only the first mount in a process has
`processFirstMount: true`. Use one dataset per process when comparing cold starts.
`warm` revisits the same views in the same mounted shell.

A single engine `FrameTiming` listener captures the run. Frames are assigned by
their monotonic vsync timestamp to each action window; delayed engine batches do
not bleed into the next action. The final 1.2-second delivery wait is unmeasured.
Reports preserve every frame plus nearest-rank P50/P95/P99/max build, raster,
total-span and vsync-overhead durations, stage frame-budget exceedances, wall
duration, in-memory write counts, and process RSS before/after. RSS is not a Dart
heap measurement; the process high-water RSS is not a per-scenario peak. A stage
over budget is not an inferred presentation drop or an FPS measurement.

Check raw distributions and scenario metadata before comparing medians from the
three processes. Any empty profile frame sample or failed interaction fails the
run instead of producing a successful zero. Keep frame budgets advisory across
machines, and use the deterministic journey assertions for CI correctness.

## Harness validation

```powershell
flutter test --no-pub test/benchmark_ui_performance_test.dart
```

This verifies percentile/missing-data handling, workload sizes, and the real UI
journey through an in-memory boundary. It is explicitly labeled
`widget-smoke-only` and is rejected by the profile report driver.
