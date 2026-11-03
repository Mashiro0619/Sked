# Agent transcript and host performance

`integration_test/agent_ui_performance_benchmark_test.dart` records native
Profile engine frames for the actual Agent entry, long-history scrolling,
full-page close/reopen transitions and return to the latest message. It reuses
the [native functional host](../integration_test/README.md), including its real
`AppRuntime`, `AppHomeScreen`, production codecs and normal save scheduling.
The fixture has 512 deterministic Markdown/code messages in the selected
conversation and two messages in an independent conversation. Every store and
credential owner is explicitly synthetic and isolated in memory.

This is an idle transcript population. Every action starts and ends with zero
provider requests, and the final report requires no provider activity or HTTP
operation attempts. Streaming, approval, mutation and draft-editing correctness
belong to the native functional journeys. There is no active model spinner or
artificial provider wait in these frame samples.

## Fixed population

Protocol `agent-ui-frames-v2` fixes **three independent native processes per
revision, platform and configuration**. Each process creates one session and
performs one `cold` sequence followed by one `warm` sequence in that same
runtime and conversation repository.

Version 2 follows the full Agent page on both platforms. Historical v1 reports
retain their original pane/workspace population and must not be merged with or
directly compared against v2 results. Keep those raw reports unchanged; a new
v2 before/after comparison needs fresh evidence for each source revision.

`cold` means the first Agent open and first action sequence in that process,
after the main snapshot and actual home page have been prepared outside action
timing. It does not mean an operating-system cold start, a cold Flutter engine,
or cold global font/shader caches. Home preparation must leave Agent dormant
and conversation loads at zero. The measured first entry performs the first
archive load. `warm` opens Agent again with that same loaded repository; the
archive load count must remain one. No second session replaces the warm input.

Each action below has its own nonoverlapping timing window:

| Order | Windows | Android |
| --- | --- | --- |
| 1 | Sidebar Agent entry → full Agent page | Main navigation drawer Agent entry → full Agent page |
| 2 | Page transcript: three older-history drags | Page transcript: three older-history drags |
| 3 | Close page while reading earlier history | Close page while reading earlier history |
| 4 | Reopen from side navigation, preserving the anchor | Reopen from main navigation, preserving the anchor |
| 5 | Jump to latest | Jump to latest |
| 6 | Close the page at latest | Close the page at latest |

Home actions use `workspace-agent-entry` in the sidebar or open the mobile
`workspace-main-navigation` drawer first. An entry is brought into view before
it is tapped. Reopening repeats the actual home entry; closing uses the full
page Back control. The chosen path is recorded in `entry`, and drawer opening
or entry scrolling remains inside the action window.

There are 12 action windows per process on each platform. Returning home
at the end of each sequence is measured too. Platform populations differ and
must not be pooled. The short comparison conversation remains unchanged; this
protocol does not time history selection or add extra feature scenarios.

Two configurations run in separate processes:

- `baseline`: light theme, 1× text, normal framework motion.
- `accessible`: dark theme, 2× text, framework reduced motion.

The requested values are checked on every visible Agent host. These are theme,
`TextScaler` and `SkedMotionPolicyScope` inputs, not changes to OS accessibility
settings. `disableAnimations` remains false; reduced spatial motion follows the
product's existing policy. Neither entry overrides physical size, DPR nor the
logical render surface. Windows requires an actual window of at least
1100×600 logical pixels. Android uses its actual native surface; record a
confirmed task emulator ID when no physical device is available. Emulator
results remain a separate population and never substitute for physical-device
acceptance.

## Frame and semantics protocol

The entry uses `fullyLive`. Before the benchmark test, `setUpAll` mounts only
`SizedBox.shrink` and awaits `endOfFrame`. No Material app, fixture, text or
Agent host is prewarmed in that empty-tree bootstrap.
`testWidgets(semanticsEnabled: false)` creates no test-owned semantics handle.

The shared `NativeSemanticsProbe(requireStableNative: true)` spans preparation,
home and Agent mounts, all actions, UI unmount, owner cleanup, and the final
frame-delivery wait. It rejects native/framework disagreement, endpoint
changes, or any framework-listener-observed change. Reports retain its raw
successful endpoint/listener observations; failures retain the error plus
separate before-preparation/after-cleanup endpoint snapshots. No native
accessibility provider is activated for sampling. These finite observations
do not constitute a native accessibility or continuous OS-state audit.

Exactly one engine `FrameTiming` listener is attached and removed. Action
boundaries use monotonic `Timeline.now`; frames belong to the half-open range
`startUs <= FramePhase.vsyncStart < endUs`. Callback arrival time does not assign
late batches to the next action. After UI unmount and owner cleanup, the entry
waits 1.2 seconds for engine batch delivery outside every action window before
removing the listener. Unassigned frames from preparation and cleanup are
retained separately, with no action performance label.

Only `agent-transcript-native-long-history` is a valid scroll target. There is
no fallback to a history sidebar, main calendar, settings list or detail pane.
Each scrolling action performs three downward 400 ms timed drags at the
framework's default 60 pointer samples per second. Distance is 72% of the
current transcript viewport, bounded to 180–520 logical pixels. The actual
first visible message must change and the reader must leave the latest region.

The entry records visible message IDs, text from actual `RenderParagraph` and
`RenderEditable` objects, viewport-relative rectangles, first-message fraction,
actual scroll metrics and follow-latest state before and after the gestures
and host transitions. SelectableText and selectable Markdown use RenderEditable,
so the collector does not rely on a RichText widget for message-body evidence.
Closing/reopening the full page compares the same visible message and its normalized within-message
position using four logical pixels of tolerance. Raw extent estimates are
diagnostics; they are not a substitute for content/anchor evidence. Jump to
latest must expose the final seeded reply and leave at most two logical pixels
after the viewport.

State waits use bounded 16 ms pumps; production animation settling uses 50 ms
`pumpAndSettle` with a 15 second deadline. Read-only visible-message observation
work remains inside the action window and is never subtracted from its cost.
Fixture hashes are computed before measured work; reading-text hashes and
frame summaries are computed after all action windows.

## Run

Windows runs must use a dedicated test checkout/build tree configured with a
nonempty, task-owned `SKED_WINDOWS_TEST_NAMESPACE`, as required by
[Windows native acceptance](../docs/WINDOWS_NATIVE_ACCEPTANCE.md). The CMake
namespace isolates the native window-placement registry and single-instance
notification/mutex space before Dart starts; in-memory Dart stores alone do
not isolate those runner effects. Configure and verify the namespace in the
same generated `CMakeCache.txt` used by the subsequent build/drive invocation.
Record that cache/namespace receipt with the process evidence. Never share this
test CMake/build tree with a production MSIX or ordinary production runner
build. The command below assumes this native isolation is already configured.

Finish source checks, builds and the native functional acceptance first. Fix
the source, data and protocol before opening the exclusive sampling window;
do not run analysis, tests, dependency installs, builds or other sampling
concurrently with a measured process. Keep device, window, system scaling,
refresh rate, power mode and observed semantics population the same across
comparison sides.

```powershell
$agentProfileRevision = '<full40-source-sha>'
$agentProfileOldNoProxy = $env:NO_PROXY
$agentProfileOldOutput = $env:FLUTTER_TEST_OUTPUTS_DIR
$agentProfileOutput = Join-Path ([IO.Path]::GetTempPath()) ('sked-agent-profile-' + [guid]::NewGuid().ToString('N'))
try {
  $env:NO_PROXY = '127.0.0.1,localhost'
  $env:FLUTTER_TEST_OUTPUTS_DIR = $agentProfileOutput
  flutter drive --profile --no-pub -d windows `
    --driver=test_driver/agent_ui_performance_driver.dart `
    --target=integration_test/agent_ui_performance_benchmark_test.dart `
    --dart-define=SKED_AGENT_UI_PERF_CONFIG=baseline `
    --dart-define=SKED_AGENT_UI_PERF_LABEL=before-windows-baseline-r1 `
    "--dart-define=SKED_AGENT_UI_PERF_REVISION=$agentProfileRevision"
  if ($LASTEXITCODE -ne 0) { throw 'Agent Profile process failed; retain its report and native logs.' }
} finally {
  if ($null -eq $agentProfileOldNoProxy) {
    Remove-Item Env:NO_PROXY -ErrorAction SilentlyContinue
  } else {
    $env:NO_PROXY = $agentProfileOldNoProxy
  }
  if ($null -eq $agentProfileOldOutput) {
    Remove-Item Env:FLUTTER_TEST_OUTPUTS_DIR -ErrorAction SilentlyContinue
  } else {
    $env:FLUTTER_TEST_OUTPUTS_DIR = $agentProfileOldOutput
  }
}
```

Repeat in three fresh processes with distinct labels/output directories on
each comparison side. Repeat the complete three-process set for `accessible`
and the confirmed Android target ID. Retain three distinct native PIDs and
their start/end receipts; a hot restart or a second driver attached to an
existing process is not a fresh-process sample. The source revision must be the full
40-character SHA for the actual build input. Archived candidates can add
`SKED_AGENT_UI_PERF_SOURCE_NOTE` to record the reviewed candidate tree; never
infer an archived checkout's revision with a failing `git rev-parse` command.

The entry rejects debug, host VM and non-native runs. There is no codec override,
timing-disabled flag or alternate widget-only path in this protocol. The
separate native functional entry provides the debug behavior-checking route.

## Reports and interpretation

The driver first saves `agent-ui-profile-raw.json`, including failed windows,
previous successful windows and a manifest of relevant source files. It then
validates the complete protocol and saves `agent-ui-profile-assessment.json`.
Existing files are never replaced; each process uses a new system Temp output
directory. The source manifest describes files read from the driver checkout,
not all tracked files or binary attestation. Record the full build/run command,
source/candidate tree, SDK/toolchain, start/end/exit receipt and native logs
alongside it.

Each window retains every engine frame, nearest-rank P50/P95/P99/max build,
raster, total-span and vsync-overhead durations, stage budget exceedances,
elapsed wall time, provider counters, actual native dimensions/DPR, and process
RSS before/after. The shared `ui_performance_metrics.dart` computes statistics;
the driver recalculates them from the retained raw frames. It also checks
ordered cold/warm actions, transcript text hashes, reading continuity, one
archive load, stable semantics and complete cleanup.

The [population contract regression](../test/agent_ui_performance_protocol_test.dart)
checks the benchmark and driver together, including rejection of v1 reports,
legacy pane actions and incomplete cold/warm requirements. It does not collect
native frames or replace a v2 process run.

The frame budget uses the reported native refresh rate; a missing/invalid
engine rate explicitly records a 60 Hz fallback. Over-budget stages are
diagnostics, not inferred presentation drops or FPS. RSS is whole-process
resident memory, not Dart heap. The process high-water value includes
preparation and reporting and is not a per-action peak.

An empty frame window, failed action, unexpected provider activity, changed
semantics or failed cleanup invalidates the process. Preserve all failures and
unfavorable values. Native AXTree/fatal errors in stdout/stderr also invalidate
the run even if a JSON field says passed. A driver assessment covers one
process; comparisons require the full three-process set with matched sources,
configuration, action protocol and 512-message input hashes. Summarize each
process before comparing distributions and their three-process medians.

These native Agent reports are separate from host JIT benchmarks, the original
workspace UI66/workspace60 matrix, functional test counts, Windows mobile-size
simulations and physical-device evidence. Historical reports cannot acquire
this protocol's missing metadata or be relabeled as Agent transcript samples.
