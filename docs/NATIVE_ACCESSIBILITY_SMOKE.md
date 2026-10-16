# Native Windows accessibility regression

This focused integration target exercises populated workspaces, hovered picker
routes, keyboard focus/Escape, retained event drafts, a settings round trip,
cancel/discard and a successful in-memory save. It audits serialized semantics
updates and current-tree traversal, then reads the test runner's default
Windows MSAA provider to confirm the editor value and discard-dialog text.

The fixture selects `WorkspacePanelDisplayMode.sideBySide` before mounting,
so workspace controls stay available while the retained editor draft is open.
The assessor requires this recorded mode and enabled engine/framework semantics
before and after every phase.

The driver report alone is insufficient: the assessor rejects any AXTree/crash
log line, missing stage, invalid graph, missing native MSAA result, non-Profile
execution or mismatched source revision. It requires all 27 labelled phases.

The native test opts out of testWidgets' automatic artificial semantics handle.
Its initial provider query must enable engine semantics before the populated
production tree is mounted. Both engine/framework state and update counts are
recorded. A native container alone cannot pass: the first populated provider
probe must expose actual buttons. Native accessibility is never disabled.
Initial activation runs in setUpAll before testWidgets records its handle
baseline; the platform-owned handle remains enabled without suppressing the
framework's ordinary test-handle leak check. Bootstrap state is recorded.

Text input uses a registered Flutter test TextInputClient, including its real
client ID in Profile. Both drafts are checked at controller, rendered text and
published editable semantic node, with compact field diagnostics retained in
the report. The saved draft must also match an exact native MSAA text-field
value. The probe uses OBJID_CLIENT/IAccessible and AccessibleChildren only on
the target PID's FlutterView HWNDs. It labels reports nativeApi=MSAA and never
counts the window frame as app controls. Direct UIA is compile-time gated in
the default Flutter Windows embedder; a UIA container is not app-tree evidence.
No controller assignment or direct business callback substitutes for input.

All data and side stores are isolated memory fixtures, including layout and
developer preferences, secrets, school sites, journal and disabled notification
runtime. Pointer/key input is injected through Flutter in a real Windows
runner. This is not physical input, Android or complete screen-reader task
acceptance. The native client must be at least 1100 x 600 logical pixels; no
physical-size or DPR override is applied.

## Running

Run from the repository root, after any quiet performance measurement. The
absolute PowerShell probe path is a required compile-time define. Never rely
on the native process CWD, and rebuild when changing the compiled probe path.

```powershell
$nativeRevision = (git rev-parse --short=12 HEAD).Trim()
$nativeProbe = (Resolve-Path -LiteralPath 'tool/probe_native_accessibility.ps1').ProviderPath
$nativeRun = Join-Path (Get-Location).Path ('build/native-accessibility/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $nativeRun -ErrorAction Stop | Out-Null
$previousNativeOutputs = $env:FLUTTER_TEST_OUTPUTS_DIR
$previousNativeNoProxy = $env:NO_PROXY
try {
  $env:FLUTTER_TEST_OUTPUTS_DIR = $nativeRun
  $env:NO_PROXY = '127.0.0.1,localhost'
  flutter drive --profile --no-pub -d windows `
    --driver=test_driver/native_accessibility_driver.dart `
    --target=integration_test/native_accessibility_smoke_test.dart `
    "--dart-define=SKED_A11Y_PROBE=$nativeProbe" `
    --dart-define=SKED_A11Y_REVISION=$nativeRevision `
    --timeout=360 2>&1 | Tee-Object -FilePath (Join-Path $nativeRun 'run.log')
  $nativeExitCode = $LASTEXITCODE
  python tool/assess_native_accessibility.py `
    --log (Join-Path $nativeRun 'run.log') `
    --report (Join-Path $nativeRun 'native-accessibility.json') `
    --exit-code $nativeExitCode --revision $nativeRevision
  if ($LASTEXITCODE -ne 0) { throw "Native accessibility did not pass: $nativeRun" }
} finally {
  $env:FLUTTER_TEST_OUTPUTS_DIR = $previousNativeOutputs
  $env:NO_PROXY = $previousNativeNoProxy
}
```

Preserve the report, assessment and run.log together. They contain the revision,
viewport/DPR, probe path, native CWD, per-phase update ranges and compact MSAA
counts. Avoid dumping raw driver frame payloads or entire native trees.
If the checkout is dirty, the revision field only identifies its base commit;
retain the actual source diff and hashes with the run before claiming an exact
revision result.

The matching `test/widgets/workspace_canvas_semantics_test.dart` regression
also checks that the canvas dismiss action stays on a stable parent while
toolbar controls retain distinct semantics and their own bounds. Passing this
smoke alone does not establish those geometry and action-isolation properties,
or the broader UI benchmark's native safety.

## Interpreting a failure

An invalid Dart traversal update implicates the source/framework graph sent to
the bridge; it does not identify which layer introduced it. A valid Dart graph
with native AXTree rejections needs a reduced standard-widget control before
assigning an engine defect. Missing MSAA observations leave native provider
acceptance unverified. Historical baseline errors and an all-tests-passed line
must never be used to waive current native errors.

Flutter 3.47.7's desktop launcher inherits the CLI CWD; its project bundle
resolves engine resource paths relative to the executable without changing CWD.
The explicit probe define removes reliance on either convention or other
launchers. This regression target performs no user-data I/O or notification
registration.
