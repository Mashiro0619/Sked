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
