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
execution or mismatched source revision. It requires all 27 original labelled
phases followed by 17 Agent phases in each of two configurations (61 total).

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

## Agent coverage

After the original workspace tree is unmounted, each Agent scenario creates a
fresh `AgentNativeSession` with explicit memory owners and production codecs.
The real home side navigation opens the central Agent workspace; New
conversation leads to the actual composer. The conversation menu opens the
Agent settings overview. Its four category entrances must publish distinct
actionable button semantics and open their matching child routes. The named
native control must use the MSAA push-button role (43); static-text (41), window
and container matches never pass. Each child page must become the current
route, hide its overview entrance, and return to the same overview through Back.
This smoke checks the overview and category routes. Knowledge record editing
is covered by the separate Agent feature journey.
Returning from settings must preserve the registered-input draft and make no
provider request or main-data change.

Action checks resolve the unique published tap node inside the requested
control's render subtree. Merged text and category labels may use their nearest
published ancestor; unrelated actions elsewhere in that ancestor never count.
Hidden nodes and ambiguous controls fail the check.

Both configurations test the exact composer value, Ask approve/reject buttons,
Show more changes and expanded first/last change details through same-PID MSAA.
A scripted provider requests real `capabilities.describe`, `mutation.prepare`
and `mutation.commit` tools. The 21 synthetic events exceed the initial 20-row
preview: Show more is observed through MSAA and tapped through Flutter to
reveal the complete target list. A pointer drag on the actual transcript enters
earlier-history reading before inspecting the rows; its offset and the visible
Jump to latest control confirm that ordinary follow-latest behavior is paused.
The first and last displayed records are expanded through the product UI; their
complete before/after JSON is checked against the host plan, and their detail
sentinels must appear as native text rather than a window/container match.
Each detail waits for its own expansion clip to expose the full body with
stable geometry before it is scrolled into view. The active approval spinner
does not need to settle. Before/after clip geometry and the actual text node's
label, value, hidden flag and root reachability remain in the report; a local
debug semantics node alone is not proof that native clients can read it.

The baseline configuration is light with 1× text and normal motion. It rejects
the plan and requires the entire committed and persisted main snapshots to stay
identical. The accessible configuration uses dark theme, 2× text and the
framework reduced-motion policy, with animations still enabled. It approves
the plan and checks every new event's full content, all original data, the
21-change stored receipt and the corresponding receipt card. No controller
assignment, direct approval callback or model prose substitutes for those
checks. Configuration observations, input diagnostics, pre-decision hashes,
pagination, native roles and cleanup are retained separately from the original
two editor-input diagnostics.

Rejection ends the real host run after three provider requests, with the
`cancelled` commit tool result persisted in the conversation and no subsequent
provider reply. Approval makes a fourth request and must finish with the same
stored tool result followed by the final reply. The v2 report checks the exact
tool-call identity, saved/current conversation equality, settled request/tool
accounting, terminal status and absence of pending approval for both outcomes.

An HTTP guard and rejecting provider transport must observe zero network
operations. Each UI tree is unmounted before all session owners are explicitly
closed; missing/failed cleanup fails the assessment. Native semantics remains
enabled across both trees. These are Windows MSAA and framework-injected UI
checks; the theme/text/motion settings are framework configuration, not changes
to Windows accessibility settings or complete screen-reader acceptance.

## Running

The report assessor has a separate deterministic CLI regression:

```powershell
python -B test/tool/assess_native_accessibility_test.py
```

It verifies the hierarchy, destination pages and native push-button roles from
synthetic reports, and rejects the retired tab protocol. Flutter VM tests do not
run this Python entry; this check does not replace the native run below.

Run from the root of a fresh, isolated test checkout or source export in system
Temp, outside any performance sampling window. Follow the build-time namespace
requirement in [Windows native acceptance](WINDOWS_NATIVE_ACCEPTANCE.md):
synthetic Dart data alone does not isolate native window-state registry keys or
the single-instance mutex. Configure a unique `SKED_WINDOWS_TEST_NAMESPACE`
before building/running the test application, and retain its CMake cache with
the result. Use a separate fresh build tree for production release/MSIX builds
and confirm that its namespace is empty; test build trees are not packaging
inputs.

Keep the physical build-root path short, for example
`[system Temp]/sked-win-<8 random characters>/source`; plugin headers, link
outputs and MSBuild tracking files can exceed Windows path limits under deeply
nested candidate directories. Evidence may use a separate longer Temp path.
Do not change repository or SDK paths to compensate for a long test root.

The absolute PowerShell probe path is a required compile-time define. Never
rely on the native process CWD, and rebuild when changing the compiled probe
path. For a Git source export, supply its manifest's full source SHA instead
of invoking `git rev-parse` in the exported directory.

```powershell
$nativeRevision = (git rev-parse HEAD).Trim()
$nativeProbe = (Resolve-Path -LiteralPath 'tool/probe_native_accessibility.ps1').ProviderPath
$nativeRun = Join-Path ([IO.Path]::GetTempPath()) ('sked-native-accessibility-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $nativeRun -ErrorAction Stop | Out-Null
$nativeNamespace = 'sked.a11y.' + [Guid]::NewGuid().ToString('N')
$previousNativeOutputs = $env:FLUTTER_TEST_OUTPUTS_DIR
$previousNativeNoProxy = $env:NO_PROXY
try {
  $env:FLUTTER_TEST_OUTPUTS_DIR = $nativeRun
  $env:NO_PROXY = '127.0.0.1,localhost'
  flutter build windows --profile --no-pub --config-only
  if ($LASTEXITCODE -ne 0) { throw 'Native test CMake preparation failed' }
  $nativeCache = 'build/windows/x64/CMakeCache.txt'
  $nativeCmakeLine = Select-String -LiteralPath $nativeCache -Pattern '^CMAKE_COMMAND:INTERNAL=(.+)$'
  if ($nativeCmakeLine.Count -ne 1) { throw 'Cannot identify the configured CMake executable' }
  $nativeCmake = $nativeCmakeLine.Matches[0].Groups[1].Value
  & $nativeCmake -S windows -B build/windows/x64 `
    "-DSKED_WINDOWS_TEST_NAMESPACE=$nativeNamespace" `
    -DSKED_BUILD_WINDOWS_RUNNER_TESTS=ON
  if ($LASTEXITCODE -ne 0) { throw 'Native test namespace configuration failed' }
  $nativeNamespaceLine = "SKED_WINDOWS_TEST_NAMESPACE:STRING=$nativeNamespace"
  if (-not ((Get-Content -LiteralPath $nativeCache) -contains $nativeNamespaceLine)) {
    throw 'The native test namespace was not retained in CMake'
  }
  Copy-Item -LiteralPath $nativeCache -Destination (Join-Path $nativeRun 'CMakeCache-before.txt')
  flutter drive --profile --no-pub -d windows `
    --driver=test_driver/native_accessibility_driver.dart `
    --target=integration_test/native_accessibility_smoke_test.dart `
    "--dart-define=SKED_A11Y_PROBE=$nativeProbe" `
    --dart-define=SKED_A11Y_REVISION=$nativeRevision `
    --timeout=840 2>&1 | Tee-Object -FilePath (Join-Path $nativeRun 'run.log')
  $nativeExitCode = $LASTEXITCODE
  Copy-Item -LiteralPath $nativeCache -Destination (Join-Path $nativeRun 'CMakeCache-after.txt')
  if (-not ((Get-Content -LiteralPath $nativeCache) -contains $nativeNamespaceLine)) {
    throw 'The native test namespace changed during the build'
  }
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

The integration target is bounded to 12 minutes, the driver to 13 and the
outer command to 14. Individual native queries and Agent state waits retain
20-second limits; original workspace phases retain their 15-second settle
limits. Active Agent phases use bounded state predicates and explicit
semantics pumps so a waiting approval does not require all animations to
settle. A timeout is a failed run, never an accepted partial result.

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

The companion `test/widgets/settings_slider_semantics_test.dart` checks
independent slider actions, disabled controls, hidden offscreen anchors and
route closure. The prebuilt settings form retains its offscreen semantic
nodes while marking them hidden; value indicators keep their normal global
overlay and are not clipped to an individual control or the scroll viewport.

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
