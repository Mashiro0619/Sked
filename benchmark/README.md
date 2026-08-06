# Performance benchmarks

This suite measures the performance-sensitive paths covered by phase 8. It is
not a CI timing gate. Correctness is enforced by fixed workload checksums and
unit tests; timings are evidence for engineering decisions and must only be
compared between runs from the same environment.

## Protocol

- Fixtures are built before timing and contain 1,000/5,000 calendar events,
  5,000 courses, 128 school sites, and table HTML near the 240,000-code-unit
  input limit.
- Each case verifies its checksum, calibrates a batch toward 250 ms, runs five
  warm-up batches, then records eleven samples.
- Reports contain raw samples, median, median absolute deviation, minimum,
  workload metadata, and checksums.
- Run three independent processes for each side of a comparison. Compare the
  median of those three per-process medians.
- Windows host JIT and Android profile AOT results are separate populations.
  Never compare their absolute values with each other.
- Do not add absolute millisecond pass/fail thresholds to CI.

## Windows host JIT

```powershell
$revision = (git rev-parse --short=12 HEAD).Trim()
flutter test benchmark/performance_benchmark_test.dart `
  --concurrency=1 --timeout=none --reporter=expanded `
  --dart-define=SKED_BENCHMARK_LABEL=local-r1 `
  --dart-define=SKED_BENCHMARK_REVISION=$revision
```

The report is written to
`build/benchmarks/windows-host-<label>.json`.

## Android profile

Use a physical release-representative device for conclusions that influence
shipping decisions. Emulators are useful only for transport checks and
directional before/after evidence.

```powershell
$deviceId = Read-Host 'Android device ID from flutter devices'
$revision = (git rev-parse --short=12 HEAD).Trim()
$previousNoProxy = $env:NO_PROXY
$previousOutputs = $env:FLUTTER_TEST_OUTPUTS_DIR
$env:NO_PROXY = '127.0.0.1,localhost'
$env:FLUTTER_TEST_OUTPUTS_DIR = "$PWD\build\benchmarks\android-local-r1"
flutter drive --profile -d $deviceId `
  --driver=test_driver/performance_benchmark_driver.dart `
  --target=integration_test/performance_benchmark_test.dart `
  --dart-define=SKED_BENCHMARK_LABEL=local-r1 `
  --dart-define=SKED_BENCHMARK_REVISION=$revision `
  --dart-define=SKED_BENCHMARK_RUNTIME=android-physical-device-profile `
  --no-enable-dart-profiling
if ($null -eq $previousOutputs) {
  Remove-Item Env:FLUTTER_TEST_OUTPUTS_DIR
} else {
  $env:FLUTTER_TEST_OUTPUTS_DIR = $previousOutputs
}
if ($null -eq $previousNoProxy) {
  Remove-Item Env:NO_PROXY
} else {
  $env:NO_PROXY = $previousNoProxy
}
```

Set `SKED_BENCHMARK_RUNTIME=android-emulator-x86_64-profile` for emulator
runs. The localhost proxy bypass is required on hosts whose `HTTP_PROXY`
would otherwise intercept Flutter's VM service connection.

## Phase 8 evidence

Measurements on 2026-08-06 used Flutter 3.44.0 / Dart 3.12.0. Windows ran on
Windows 11 x64 with 32 logical processors. Android directional measurements
used an API 36 x86_64 emulator, not a physical device.

| Runtime | Metric | FIFO | LRU |
| --- | ---: | ---: | ---: |
| Windows host JIT | cache-churn service calls | 736 | 640 |
| Windows host JIT | cache-churn median (us/op) | 340.008 | 356.760 |
| Windows host JIT | hot-hit median (us/op) | 0.054 | 0.166 |
| Android emulator profile | cache-churn service calls | 736 | 640 |
| Android emulator profile | cache-churn median (us/op) | 354.421 | 361.911 |
| Android emulator profile | hot-hit median (us/op) | 0.082 | 0.183 |

The LRU policy reduced expensive service recomputations by 13.0% in the fixed
churn workload. Promotion makes a pure cache hit cost roughly 0.1 us more in
these environments. All eleven workload checksums remained unchanged. The
remaining timing differences were not treated as causal evidence because they
also appeared in unrelated encode, decode, and sanitizer cases.
