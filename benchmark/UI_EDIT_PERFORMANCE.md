# Native UI editor benchmarks

`integration_test/ui_edit_benchmark_test.dart` is separate from the frozen
66-scenario scrolling suite. It reuses its fixed sparse/1,000/5,000-event
fixtures and frame statistics, with `UiPerformanceApp` hosting the production
`AppHomeScreen` and workspace widgets. A test-only
session adapter supplies real `IoTimetableStorage` within a checked temporary
directory instead of the scrolling suite's in-memory data store. Production
codec defaults and the save debounce are retained.

Both revisions use their actual home-screen subscriptions. UI-only seed setup
supplies the same bundled privacy-policy acceptance version/timestamp and
isolated package metadata before measured work. `protocol.host` records it;
`inputSha256` covers the prepared, normalized snapshot actually written to disk.
Shared course/event fixture files and the separate disk workload are unchanged.

## Native semantics protocol, harness version 2

The native entrypoint retains `fullyLive` and runs an unmeasured
`runApp(const SizedBox.shrink())` / `binding.endOfFrame` bootstrap in `setUpAll`.
It mounts no Material application, text or fixture/user data. The benchmark's
`testWidgets` uses `semanticsEnabled: false` rather than adding a test-owned
handle; actual native semantics is neither disabled nor activated by a UIA
probe.

`runtime.semantics` contains actual native/framework start/end flags and
`observedChanges` from the framework semantics-enabled listener. Capture spans
viewport setup, all mounting/edit/save/unmount work, the frame-delivery wait and
cleanup. Profile requires agreement at both endpoints, unchanged endpoint
flags and no listener-observed changes. Debug/widget-only smoke may record
differing states; it remains separate from Profile evidence.

This does not prove continuous native state or native accessibility acceptance,
and does not attribute historical AXTree errors to a cause. Registered text
input still uses the actual editor client and retains the caller's registration.
The four actions, fixed fixtures, target selection, timing windows and frame
statistics are unchanged.

Use **three newly captured version-2 before and three version-2 after processes**.
Older editor pilots validate correctness only, and version-1 UI before reports
remain historical diagnostics; neither substitutes for the new before set.
Apply this protocol to both source adapters before sampling and preserve the
exact source hashes/diffs for reviewed old-API/current-domain adaptations.

There are four action windows per dataset:

- Course card → course details → actual edit action → visible editor.
- Enter the fixed course title → actual Save button → durable completion and
  editor closure.
- Timed event card → details → edit action → entire-series choice for a
  recurring event → visible editor.
- Enter the fixed event title → actual Save button → durable completion and
  editor closure.

Seed creation, mounting, workspace/view selection, initial flush and independent
disk readbacks are outside action windows. Dense courses use the last-painted
card in the first slot and an exposed hit region. Timed events use the first
column of the first overlap group, which remains visible when later columns
collapse. Both revisions use the same production ordering. Card IDs, hit
alignment and recurrence scope accompany the report and must match. Draft typing is
asserted not to write before Save. Separate disk readbacks verify the saved
titles and preservation of the other business domain. The host retains isolated
preferences, secrets, privacy, school-site files and a disabled memory
notification service. It never registers the user's toast identity.

```powershell
$editRevision = (git rev-parse --short=12 HEAD).Trim()
$editOldNoProxy = $env:NO_PROXY
$editOldOutputs = $env:FLUTTER_TEST_OUTPUTS_DIR
try {
  $env:NO_PROXY = '127.0.0.1,localhost,::1'
  $env:FLUTTER_TEST_OUTPUTS_DIR = "$PWD\build\benchmarks\ui-edit-after\r1"
  flutter drive --profile -d windows `
    --driver=test_driver/ui_edit_benchmark_driver.dart `
    --target=integration_test/ui_edit_benchmark_test.dart `
    --dart-define=SKED_UI_EDIT_LABEL=after-r1 `
    --dart-define=SKED_UI_EDIT_REVISION=$editRevision
} finally {
  if ($null -eq $editOldNoProxy) { Remove-Item Env:NO_PROXY -ErrorAction SilentlyContinue } else { $env:NO_PROXY = $editOldNoProxy }
  if ($null -eq $editOldOutputs) { Remove-Item Env:FLUTTER_TEST_OUTPUTS_DIR -ErrorAction SilentlyContinue } else { $env:FLUTTER_TEST_OUTPUTS_DIR = $editOldOutputs }
}
```

Use three independent processes per revision, matching device, power mode,
logical viewport, scaling, refresh rate and workload. Android uses its physical
device ID in place of `windows`; simulated Android style is not device evidence.
The Windows viewport is bounded by the native window and 1280×720 logical units.
`SKED_UI_EDIT_DATASETS=sparse` selects a smaller correctness/transport run.

The JSON is `ui-edit-<label>.json`. It retains every engine frame, P50/P95/P99/max
build/raster/total-span times, over-budget ratio, wall duration, successful
AppData write count and RSS. Engine batches are attributed by monotonic vsync
timestamp; the final delivery wait is excluded. Empty Profile frame samples or
failed real interactions invalidate the report. There is no millisecond gate.

For `--no-build`, use the label and revision compiled into that binary and
separate output directories for repeated processes. Never relabel an unchanged
binary as another source revision.

## Original revision replay

The original `77061b4` production source remains untouched. Use the frozen UI
harness files from `5e7213c` in that checkout, as described in
[UI_PERFORMANCE.md](UI_PERFORMANCE.md). Copy the shared editor-session interface,
scenario, integration target and driver onto it, together with
`data_operations_runtime.dart`. Replace only `ui_edit_runtime_adapter.dart`
with `compatibility/ui_edit_runtime_77061b4.dart.txt`. Apply the same native
semantics version-2 entrypoint/scenario changes and copy
`native_semantics_probe.dart` and `ui_performance_host_setup.dart` onto both
checkouts before recording new runs. Both hosts mount their production
`AppHomeScreen` rather than duplicating its subscription logic.

The current adapter uses AppRuntime domains; the original adapter calls the
original provider. Neither rewrites editing, persistence or validation logic.
Record source hashes for shared scenario/fixture/metric files and compare input
checksums and target IDs before comparing the three-process distributions.

## Evidence boundaries

Input is injected through Flutter's real pointer/text interfaces, so this
measures editor behavior and rendering with native fonts and real file writes.
The text transport is registered for the run, allowing Profile input to use
the editor's real `TextInput.setClient` ID; it does not replace controllers or
save callbacks. Any registration owned by the caller is retained afterward.
It does not measure the Windows/Android OS keyboard or IME service latency.
Interaction timings include production route animations and settling; use the
separate disk suite for command-only I/O timing.

The process is already running before fixture setup; this is not OS cold
startup. RSS is whole-process memory, and over-budget frames are not measured
FPS or presentation-drop counts. A debug native smoke can use
`SKED_UI_EDIT_ALLOW_DEBUG_SMOKE=true`; its `native-ui-edit-smoke` report is
rejected by the Profile driver. No inline codec override exists in this target.
