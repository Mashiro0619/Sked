# Windows Profile startup benchmark

This harness measures a fresh Windows process running the production
`runSkedApp → AppBootstrap → MyApp` startup path. It reports the first raster,
verified ready raster, and response to a selected-day input. Use it separately
from host JIT microbenchmarks and in-process UI workloads.

Every sample starts a new executable with isolated writable files. OS page,
shader, and font caches are retained, so these are process-cold measurements,
not disk-cold measurements. The input is injected through Flutter's
`GestureBinding`; this is not native Win32 or physical input evidence.

## Source layout

| File | Responsibility |
| --- | --- |
| `startup_main.dart` | Standalone Profile entry point, production startup composition, isolation, and post-measurement checks |
| `startup_fixture_test.dart` | Fixture preparation in a separate, unmeasured process |
| `src/startup_protocol.dart` | Run specification, path checks, fixed dates, and semantic signatures |
| `src/startup_runtime_adapter.dart` | Runtime/provider adaptation without changing the measured business algorithms |
| `src/startup_probe.dart` | Framework state, engine frame association, input, clocks, and observer costs |
| `src/startup_clock.dart` | Pure QPC/FILETIME conversion, begin association, and clock validation |
| `src/startup_native_clock.dart` | Independent native QPC/frequency and precise FILETIME sampling |
| `src/startup_native_window.dart` | Read-only Win32 ownership and visibility evidence |
| `run_startup_windows.ps1` | Artifact checks, process creation, independent lock probes, and report aggregation |
| `../test/benchmark_startup_clock_test.dart` | Pure clock, uncertainty, overflow, and association regressions in the standard test suite |

Run the commands below from the repository root using PowerShell 7.2 or newer.
Pin one Flutter SDK for both builds. Check formatting, analysis, and relevant
correctness tests before taking measurements; avoid concurrent builds, tests,
indexing, or other performance runs during sampling.

## Prepare shared inputs

Create a new evidence directory. Keep its absolute path when switching between
the two comparison checkouts.

```powershell
$startupEvidence = [IO.Path]::GetFullPath((Join-Path $PWD ('.scratch\startup-' + [Guid]::NewGuid().ToString('N'))))
New-Item -ItemType Directory -Path $startupEvidence | Out-Null
$startupFixtureRoot = Join-Path $startupEvidence 'fixtures'
flutter test benchmark/startup_fixture_test.dart "--dart-define=SKED_STARTUP_FIXTURES=$startupFixtureRoot"
if ($LASTEXITCODE -ne 0) { throw 'Startup fixture preparation failed.' }
```

Preparation writes the `sparse`, `1000`, and `5000` datasets once. Each has a
`fixture.json`, normalized archive and school-site data, and file-backed
desktop/developer preferences. The fixed selected day is `2026-08-17`; the
probe selects `2026-08-18`. Privacy version `2026-08-07` is accepted and
notifications are enabled. Dataset versions and semantic/file hashes are
recorded with the inputs.

The launcher verifies and copies these same bytes into every sample directory.
The measured child does not build fixtures or preload the repository. When an
older comparison revision lacks the current UI fixture definitions, prepare
inputs on the current checkout and reuse that fixture directory for both sides.

## Build and record both sides

Use two isolated, pinned comparison checkouts. Keep the instrumentation,
isolation boundaries, SDK, and engine equivalent. If the older revision needs
an adapter or dependency-injection overlay, retain its business algorithms and
archive the exact overlay, including untracked files. A source commit alone
does not identify an instrumented build with additional local changes.

The shared launcher, lazy startup dependency factories, home-widget identity
boundary, and scoped notification lock must be equivalent on both sides.
Keep the notification scope around binding initialization and app launch, and
propagate the scope explicitly into spawned isolates. Observational getters
needed by an older provider must not load or mutate its state.

Run the following once per checkout, setting `$startupSide` to `before` or
`after`. Reuse the evidence directory from preparation. The script creates an
immutable artifact copy and a manifest containing every copied artifact hash.

```powershell
$startupSide = 'after'
$startupRevision = (git rev-parse HEAD).Trim()
$startupSdk = flutter --version --machine | ConvertFrom-Json
$startupBuildArguments = @(
  'build', 'windows', '--profile', '--target=benchmark/startup_main.dart',
  "--dart-define=SKED_STARTUP_REVISION=$startupRevision",
  "--dart-define=SKED_STARTUP_ENGINE=$($startupSdk.engineRevision)"
)
flutter @startupBuildArguments
if ($LASTEXITCODE -ne 0) { throw 'Startup Profile build failed.' }

$startupArtifact = Join-Path $startupEvidence ('artifacts-' + $startupSide)
$startupManifest = Join-Path $startupEvidence ('build-' + $startupSide + '.json')
if ((Test-Path -LiteralPath $startupArtifact) -or (Test-Path -LiteralPath $startupManifest)) {
  throw 'Use a new artifact directory and manifest; preserve previous builds.'
}
Copy-Item -LiteralPath 'build/windows/x64/runner/Profile' -Destination $startupArtifact -Recurse
$startupFiles = [ordered]@{}
Get-ChildItem -LiteralPath $startupArtifact -File -Recurse -Force |
  Sort-Object FullName |
  ForEach-Object {
    $startupRelative = [IO.Path]::GetRelativePath($startupArtifact, $_.FullName).Replace('\', '/')
    $startupFiles[$startupRelative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  }
[ordered]@{
  side = $startupSide
  platform = 'windows'
  mode = 'profile'
  target = 'benchmark/startup_main.dart'
  revision = $startupRevision
  sdkRevision = $startupSdk.frameworkRevision
  engineRevision = $startupSdk.engineRevision
  buildCommand = 'flutter ' + ($startupBuildArguments -join ' ')
  flutterExecutable = (Get-Command flutter).Source
  buildArguments = $startupBuildArguments
  artifactDirectory = $startupArtifact
  executable = 'sked.exe'
  files = $startupFiles
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $startupManifest -Encoding utf8
```

Preserve build output and the exact source overlay alongside the manifest.
The launcher requires a full 40-character source revision and hashes for at
least the executable, `data/app.so`, `flutter_windows.dll`, and
`data/icudtl.dat`; include the full artifact tree as above. Separate before and
after artifact directories prevent later builds from replacing measured files.

Do not measure `flutter run`, an integration-test binding, or a reused process.
The child accepts exactly one `--run-root=<absolute prepared directory>`
argument; let the launcher prepare and supply that directory.

## Smoke, then sample

Run one sparse process for each side before the complete matrix. Use fresh
output paths for every invocation.

```powershell
$startupBeforeManifest = Join-Path $startupEvidence 'build-before.json'
$startupAfterManifest = Join-Path $startupEvidence 'build-after.json'
$startupSmoke = Join-Path $startupEvidence 'smoke'
& .\benchmark\run_startup_windows.ps1 -BuildManifests @($startupBeforeManifest, $startupAfterManifest) -FixtureRoot $startupFixtureRoot -OutputRoot $startupSmoke -Datasets @('sparse') -Repetitions 1
```

Accept the smoke only when both processes satisfy all of these conditions:

1. The first, ready, and response rasters have usable engine frame IDs and
   ordered timestamps. Both child and launcher clock checks pass.
2. The real day-cell hit test succeeds; selected-date state and rendered
   `Semantics.properties.selected` both switch to the expected day. Ready
   `AppData` matches the prepared semantic hash.
3. The same child-owned Win32 window passes every required visibility
   observation, including input and response. First-show confirmation reaches
   a normal ready frame without hanging.
4. Real notification initialization and planning finish successfully. The
   repository uses the isolated physical archive, and the independent process
   observes both physical locks with Windows error 33.
5. Exit code is zero; complete reports and logs are present; native/framework
   semantics, view geometry, focus, and accessibility conditions are compatible
   across sides.

Then run three processes per revision and dataset: 18 processes in total.

```powershell
$startupMatrix = Join-Path $startupEvidence 'matrix'
& .\benchmark\run_startup_windows.ps1 -BuildManifests @($startupBeforeManifest, $startupAfterManifest) -FixtureRoot $startupFixtureRoot -OutputRoot $startupMatrix -Repetitions 3
```

The launcher alternates side order across repetitions and waits two seconds
after each exited child. Each process receives a new writable run root. The
GUI launches with `WindowStyle.Normal` and `CreateNoWindow = false`; its first
`ShowWindow` must not inherit `SW_HIDE`. Keep display, scaling, refresh rate,
semantics, accessibility settings, and background load stable across runs.

## What is measured

| Field | Meaning |
| --- | --- |
| `processToFirstRasterUs` | Windows process creation to first engine-reported raster finish |
| `processToReadyRasterUs` | Process creation to raster finish for verified ready application state |
| `inputToResponseRasterUs` | Flutter input dispatch to raster finish for the verified day-selection response |
| `processToTestedResponseRasterUs` | Process creation to the tested response, including delay before dispatching the probe |
| `readyObservationDelayUs` | Ready raster finish to input dispatch, including report delivery and observer work |

Process creation comes from `Process.StartTime` in UTC. The normal binding saves
a pending begin sample and assigns its real engine frame ID at draw entry:
this SDK updates `frameData` after the synchronous begin callback returns.
Frame IDs are never guessed or incremented. Raw-null production warm-up
callbacks remain separate; raster-only engine redraws may legitimately lack
a Dart begin, while ready/response frames must have one. Callback receipt is
recorded separately and is never substituted for raster time. Missing IDs
invalidate the corresponding measured milestone.

Readiness requires a loaded, non-loading, writable runtime; accepted privacy;
a successful main repository load without unknown write state; ready,
error-free preferences; the actual home route; the desktop bridge; the expected
selected day; and a hit-testable next-day cell. The binding is an observational
subclass of ordinary `WidgetsFlutterBinding`; no empty tree, preloaded runtime,
integration-test binding, or warm-up process precedes the measured app.

Input uses unique mouse pointer/device IDs, monotonic timestamps, a real
Flutter day-cell hit test, and a 16 ms down/up hold. Rendered selection is
checked independently of the model. This does not verify selection in the
native accessibility tree or physical mouse delivery.

The Win32 probe finds exactly one `FLUTTER_RUNNER_WIN32_WINDOW` owned by the
child PID and verifies the same HWND at the ready framework frame, its timing
report observation, input dispatch, the response framework frame, and its
timing report observation. It requires `IsWindowVisible`, an enabled and
non-minimized window, zero DWM cloak state, and nonempty native window/client
rectangles with the client intersecting a monitor. Foreground state and all
query results are recorded separately; Flutter focus or route visibility
cannot replace these checks.

The runner first shows its window after first raster, so first raster is not a
first-visible-presentation metric. If a ready candidate is still hidden, a
16 ms observer timer waits for Win32 visibility and requests normal engine
frames as needed until visible readiness is captured. It retries while
framework lifecycle delivery temporarily disables scheduling. Polling costs,
timestamps, and requested-frame counts remain in the report and in elapsed
startup time. Win32 snapshots do not establish that all pixels were unobscured
or presented at a historical raster timestamp.

## Clocks and isolation

Clock protocol `win32-qpc-precise-filetime-v2` requires new before/after builds;
the launcher rejects old/missing clock protocol IDs. Official child UTC stamps
use `GetSystemTimePreciseAsFileTime`, bracketed by native QPC reads with QPF
queried before and after. Ordinary Dart `DateTime.now()` is diagnostic only.
FILETIME's 1601 epoch offset is subtracted explicitly, and quotient/remainder
QPC conversion uses `BigInt` products to prevent intermediate Int64 overflow.

The Dart API describes `rasterFinishWallTime` as wall time without explicitly
promising a UTC epoch. The audited engine installs the Dart timeline as FML's
monotonic source; the pinned Windows VM returns absolute QPC ticks/frequency.
The engine converts those to nanoseconds and exports frame phases in
microseconds. Source evidence and per-process native calibration must agree.
Recheck that source chain when changing Flutter SDKs:

- `flow/frame_timings.cc`: raster and wall timestamp recording.
- `fml/time/time_point.cc`: wall-clock implementation.
- `runtime/dart_vm_initializer.cc` and `runtime/dart_timestamp_provider.cc`:
  actual FML monotonic source and quotient/remainder conversion.
- Pinned Dart `runtime/vm/os_win.cc`: QPC/frequency and ordinary FILETIME APIs.
- `shell/common/animator.cc`: separate build-start recording and vsync target
  passed to Dart's begin-frame callback.
- `dart:ui` frame timing and frame-number API documentation.

Native QPC brackets may not exceed 5 ms. The child limits independent native
wall-minus-QPC drift, engine wall-minus-monotonic drift from the first engine
frame, and every engine offset's conservative residual against the independent
calibration interval to 5 ms. Both ends of the uncertainty interval must fit
the tolerance; a wide bracket cannot relax it. Plausible native entry/report
bounds constrain raster timestamps. The launcher independently checks its
UTC/Stopwatch drift and brackets OS process creation. These are clock-quality
gates, not startup-speed thresholds.

Each observed begin's QPC bracket must lie inside its associated build interval
with only microsecond quantization allowance. The begin UTC residual and raw
vsync-target difference are scheduling diagnostics, not additional 5 ms clock
gates. Preserve a failed correlation sample rather than relaxing the tolerance.
Input begins after the ready timing report is observed, so process-to-tested-
response is not the earliest possible time to interactive.

Storage, instance lease, repository codec/debounce, and notification
coordination/planning use their production implementations. Archive,
preferences, journal, school-site, and lock paths are isolated; aliases and
pre-existing locks are rejected. The repository's actual `filePath()` must
match the isolated archive.

Secrets are synthetic, privacy/update responses are offline, and notification
gateway/runtime persistence use memory adapters. Real notification planning
must still succeed. Its clock remains the real wall clock while fixture dates
are fixed, so success can produce zero scheduled reminders. No OS notification
delivery conclusion follows. Flutter's generated plugin registration remains
intact and may load the notification DLL; memory injection is not process-wide
FFI interception.

After measured milestones, both `notification-runtime.lock` and
`archive/Sked_instance.lock` must already exist as canonical regular files. The
child holds the actual scoped notification lock while the launcher validates
the PID/paths and independently attempts to lock byte zero of both files. Only
`ERROR_LOCK_VIOLATION` (33) proves the required contention; permission and
sharing failures do not. The child flushes its report and requests the normal
desktop close path. The launcher records the exit and only terminates its own
timed-out child.

## Results and maintenance

Each run root retains its process metadata, child report, launcher result,
stdout/stderr, and lock proof. Failed starts, timeouts, missing reports, and
failed validation remain evidence. An unreaped child stops further sampling.
The harness does not overwrite or clean up earlier output directories.
Failed samples or incompatible visibility/view/semantics conditions make the
launcher return an error after preserving the reports.

`summary.json` retains every row and per-group samples, median, min/max, and
`completeThreeProcesses`. Review `matrixComplete`,
`allMeasuredNativeWindowsVisible`, and `comparableViewAndSemanticsState`
together with raw evidence. A failed clock or visibility gate suppresses that
row's comparable durations. Failed/incomplete visibility explicitly prevents a
normal-window comparison claim. Report failed/missing samples and do not
present a partial group as a complete comparison. Three processes do not
support a useful p95 estimate.

When changing readiness, fixture dates, the runner class, isolation, timing
association, or native observations, rerun both smokes before the matrix and
retain source/artifact provenance for each protocol. Keep observer overhead
visible in reports. Historical results belong to their recorded protocol and
environment; Windows results do not establish Android physical-device or
production acceptance.
