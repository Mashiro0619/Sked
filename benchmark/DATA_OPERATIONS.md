# Native disk operation benchmarks

This separate target measures production lifecycle, business commands and real
filesystem persistence with the fixed sparse/1,000/5,000-event UI fixtures. It
does not change the existing 66-scenario [UI suite](UI_PERFORMANCE.md).

Each dataset records ten raw action samples: disk-backed lifecycle load,
one course save, one event save, an update-preference save, backup export,
end-to-end additive timetable and General JSON/ICS imports, complete backup restore and shutdown
flush. Input creation, post-action disk readback, checksums and cleanup happen
outside measured windows. The seeded data is normalized once before saving;
its checksum must match across revisions. The actual runtime still uses its
production loading and native codec implementation during measured operations.

The target uses real `IoTimetableStorage`, school-site files and restore
journals within a checked system temporary directory. Synthetic secrets,
offline privacy, in-memory preferences and a local notification mutation lock
keep it away from user data, keyring and notification state. These substitutions
do not replace storage, serialization, normalization or import algorithms.

Every sample includes wall time, whole-process RSS before/after and successful
AppData save count. Site and journal writes contribute to action time, but are
not included in that count. No timing threshold controls success. Real disk
readbacks must preserve the accepted snapshot; course/event/settings commands
must preserve the other domains; additive import preserves existing records;
export never carries the synthetic secret; completed restore removes its
journal and restores both workspaces and all 128 school sites.

## Current revision

Run on the same Windows machine or physical Android device for both revisions.
Use three independent Profile processes. Keep system power mode and competing
work consistent. Example Windows process:

```powershell
$dataPerfRevision = (git rev-parse --short=12 HEAD).Trim()
$dataPerfOldNoProxy = $env:NO_PROXY
$dataPerfOldOutputs = $env:FLUTTER_TEST_OUTPUTS_DIR
$dataPerfOutput = Join-Path ([IO.Path]::GetTempPath()) ('sked-data-benchmark-' + [guid]::NewGuid().ToString('N'))
try {
  $env:NO_PROXY = '127.0.0.1,localhost,::1'
  $env:FLUTTER_TEST_OUTPUTS_DIR = $dataPerfOutput
  flutter drive --profile -d windows `
    --driver=test_driver/data_operations_benchmark_driver.dart `
    --target=integration_test/data_operations_benchmark_test.dart `
    --dart-define=SKED_DATA_PERF_LABEL=after-r1 `
    --dart-define=SKED_DATA_PERF_REVISION=$dataPerfRevision
} finally {
  if ($null -eq $dataPerfOldNoProxy) { Remove-Item Env:NO_PROXY -ErrorAction SilentlyContinue } else { $env:NO_PROXY = $dataPerfOldNoProxy }
  if ($null -eq $dataPerfOldOutputs) { Remove-Item Env:FLUTTER_TEST_OUTPUTS_DIR -ErrorAction SilentlyContinue } else { $env:FLUTTER_TEST_OUTPUTS_DIR = $dataPerfOldOutputs }
}
```

Repeat as `r2`/`r3` with matching labels and output directories. A device ID
replaces `windows` for Android; do not compare absolute Windows/Android values.
Optional `SKED_DATA_PERF_DATASETS=sparse` limits a smoke run. With `--no-build`,
the label/revision must still match the compiled binary, so use one label and
distinct output directories for independent invocations of that build.

Reports are `data-operations-<label>.json`. Compare matching dataset checksums,
operation names and runtime/toolchain metadata before comparing the median of
three independent wall-time samples. Preserve the individual samples and RSS
deltas. A missing report or failed data check invalidates the run.

## Original 77061b4 comparison

Copy the three `benchmark/src/data_operations_*.dart` files, this integration
target and driver, and the same fixed fixture helpers onto the original
checkout. Replace only `benchmark/src/data_operations_runtime_adapter.dart`
with the contents of
`benchmark/compatibility/data_operations_runtime_77061b4.dart.txt`. This is a
test-only adapter for the original public API. No baseline production file is
changed. Keep a hash manifest proving the common workload/fixture files are
identical across revisions. Build Profile with the original revision and run
the same three-process protocol under `before` labels.

The old adapter uses original synchronous codecs where that was the original
behavior; the new adapter retains the default native asynchronous codecs.
Both call the same user-level operations and await their durable completion.
The General JSON/ICS actions include parsing and durable application; the new
adapter uses the production asynchronous prepare/apply APIs. ICS DTSTAMP is fixed
before timing. Its comparison covers supported event fields, repeat boundaries
and exception dates; the exported ICS does not carry Sked reminder/color metadata.

Generated IDs and collision-avoiding names in additive imports are not timing
checksums; validation compares original records and imported course/config/
period content, including its per-timetable grouping.

## Evidence limits

`lifecycle.disk_load` is not OS cold startup: the native process is already
running, seed creation can warm the filesystem cache, and the keyring is
isolated. This target invokes commands directly and does not measure editor
opening, typing, route focus, first usable frame or frame timing. Those require
separate UI/native startup journeys. RSS is not Dart heap or per-action peak.

The 450 ms production navigation debounce is retained. `shutdown.flush` starts
immediately after selecting the fixed next date and records writes that already
completed before flush; inspect that field when comparing samples.

For correctness-only native transport checks, add
`SKED_DATA_PERF_ALLOW_DEBUG_SMOKE=true` to a debug integration invocation. Its
report is labeled `native-disk-smoke`; the Profile report driver rejects it.
This flag cannot turn debug timing into performance acceptance.
