# Workspace interaction performance

`integration_test/ui_performance_benchmark_test.dart` runs the production
`AppHomeScreen`, adaptive workspace shell, calendar/timetable views and settings widgets. Only
storage, secrets, school sites, recovery journals and notifications use isolated
in-memory implementations. The target never opens the user's data directory.
It retains the production 450 ms UI-state save debounce. Native notification,
startup update, filesystem and serialization performance are outside this UI
suite; keep the existing pure-data benchmark alongside it.

Both revisions mount their actual home screen and its production subscriptions.
The host keeps a fixed theme/locale and isolated package metadata. Before timing,
UI-only seeds receive the same bundled privacy-policy acceptance version and
fixed timestamp so the ready workspace is shown. `protocol.host` records this
setup; shared course/event fixtures and the disk benchmark remain unchanged.

## Native semantics protocol, harness version 2

Both native entrypoints use `fullyLive`. Their `setUpAll` mounts only
`SizedBox.shrink` and awaits `binding.endOfFrame` before the benchmark test.
This empty-tree preparation is unmeasured; it mounts no Material application,
text or fixture/user data. `testWidgets(..., semanticsEnabled: false)` avoids
adding a test-owned semantics handle. The native engine's semantics setting is
read as it is; this protocol does not enable UIA or disable native semantics.

`runtime.semantics` records `nativeStart`, `frameworkStart`, `nativeEnd`,
`frameworkEnd` and `observedChanges` from the framework's semantics-enabled
listener. The probe spans viewport setup, fixture mounting/interaction/unmount,
the final frame-delivery wait and cleanup. Profile runs reject differing
native/framework endpoints, changed endpoint flags, or any listener-observed
change. Fake-clock `widget-smoke-only` runs retain their widget-only semantics
behavior and may report differing flags.

These endpoints and framework notifications are finite observations, not proof
of continuous native state or native accessibility acceptance. Historical
AXTree rejections remain unattributed; this protocol change does not by itself
prove their cause or an engine fix.

All new comparisons require **three new before and three new after processes
with harnessVersion 2**. The empty-tree preparation and semantics ownership
differ from version 1, so retain existing version-1 before reports only as
historical diagnostics. Never combine them with version-2 after measurements.
Keep raw source hashes and explicit reviewed old-API/current-domain adaptation
diffs alongside the matched runtime, input and action metadata.

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

The production baseline remains `77061b4`. Start from the UI harness at
`5e7213c`, then apply the same version-2 empty-tree bootstrap, test semantics
setting, runtime capture, actual `AppHomeScreen` host and the shared
`native_semantics_probe.dart` / `ui_performance_host_setup.dart` helpers to its old-API
caller. Both measured sides must emit `harnessVersion: 2`. Current composition
uses domain interfaces and cannot be copied unchanged into the old app.
Preserve fixtures, actions and metric methods, and record exact reviewed
adapter diffs; do not copy production changes into the baseline. Existing
version-1 before reports stay historical and require fresh before sampling.

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
Only that fake-clock smoke test injects the inline data codec. Profile runs
reject codec overrides and retain production isolate computation.
