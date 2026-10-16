# Workspace scrolling and switching performance

`integration_test/ui_workspace_performance_benchmark_test.dart` captures a
fresh `workspace60-v1` population. It mounts the production `AppHomeScreen`
and shares UI66's fixtures, ten workspace actions, frame statistics, viewport
handling and isolated services. Three datasets (sparse/1,000/5,000), cold and
warm phases produce 60 actions plus three separate mount rows per process.

This protocol does not visit `settings.general.toggle` or close a settings
route. The original revision's settings Slider overlays can produce native
AXTree errors that affect subsequent observations. Capture this workload in
new processes; deleting settings rows from a full UI66 report cannot repair
that history. Workspace warm results also have different settings/cache
history and must only be compared with new workspace60-v1 results.

Keep the complete original UI66 diagnostics and require the current full
UI66 journey to pass without native errors. This supplement measures calendar,
timetable and workspace interactions; settings UI, native accessibility and
process-cold startup remain separate acceptance boundaries. The disk suite's
settings-save duration does not measure settings UI rendering.

## Run and compare

Run three independent Profile processes per revision on the same device,
with the same viewport, refresh rate and observed native semantics state.
The entrypoint fixes all three datasets and one warm iteration.

```powershell
flutter drive --profile -d windows `
  --driver=test_driver/ui_workspace_performance_benchmark_driver.dart `
  --target=integration_test/ui_workspace_performance_benchmark_test.dart `
  --dart-define=SKED_UI_WORKSPACE_PERF_LABEL=after-r1 `
  --dart-define=SKED_UI_WORKSPACE_PERF_REVISION=<actual-commit>
```

Use an attached Android device ID for Android Profile measurements. Keep
each process's raw report, stdout/stderr, start/end/exit receipt and source
hashes. Reports use `measurement: profile-workspace-engine-frames`, native
semantics harness version 2, and `protocol.scope.id: workspace60-v1`.
The driver requires the complete matrix and passed action validation.

## Primary canvas scrolling

New reports declare `protocol.scrollTargeting.version: 1` and
`id: workspace-canvas-scroll-v1`. Native semantics remain harness version 2;
the ten actions remain `workspace60-v1`. The targeting version is a separate
protocol dimension and must match on both sides of a comparison.

Vertical workspace actions only search inside that workspace's
`workspace-canvas`. Existing timeline/timetable primary keys take precedence;
other views use the largest visible vertical surface within the canvas. A
primary surface that fits its viewport performs no gesture. Resource,
reminder and detail panes cannot become substitute scrolling targets.
Reports retain the scope, target and final extent as well as the original
initial extent and offsets. The two 400 ms gestures and settling behavior
are unchanged.

The former largest-surface search across the entire workspace could choose
a long reminder list while a shorter calendar was visible. The new protocol
requires newly captured processes and identical reviewed sources on both
sides. Preserve older reports without adding fields or recategorizing their
measurements. Reports without `scrollTargeting` belong to the legacy
targeting protocol and cannot be mixed with version 1. Geometry, viewport,
native semantics and zero-AX checks still apply.

The `77061b4` baseline uses its own production home and original business
APIs, with the same benchmark scope/entrypoint/driver changes applied to the
reviewed UI harness described in [UI_PERFORMANCE.md](UI_PERFORMANCE.md).
Only the existing provider/domain caller adaptations may differ. Preserve
production baseline sources, fixtures, metrics, input setup and all ten
action implementations; record exact adapter diffs and hashes.

Reject missing frames, changed scope/input/targets, mismatched native state,
or any AXTree rejection in either measured population. Do not combine these
60 actions with UI66 as additional feature coverage, or label widget-only
smoke tests as native performance evidence.
