#Requires -Version 7.2
param(
  [Parameter(Mandatory)][string[]]$BuildManifests,
  [Parameter(Mandatory)][string]$FixtureRoot,
  [Parameter(Mandatory)][string]$OutputRoot,
  [ValidateSet('sparse', '1000', '5000')][string[]]$Datasets = @('sparse', '1000', '5000'),
  [ValidateRange(1, 3)][int]$Repetitions = 3,
  [ValidateRange(30, 240)][int]$TimeoutSeconds = 110
)
$ErrorActionPreference = 'Stop'
$startupClockProtocolId = 'win32-qpc-precise-filetime-v2'
$startupMemoryProtocolId = 'process-rss-v1'

function Is-ReportInteger([object]$Value) {
  return ($Value -is [int] -or $Value -is [long])
}
function Get-MemoryContractIssues([object]$Child) {
  $problems = [System.Collections.Generic.List[string]]::new()
  $memory = $Child.measurement.memory
  $points = @('entry', 'readyRasterReportObserved', 'responseRasterReportObserved', 'measurementEnd')
  $samples = @($memory.samples)
  if ($memory.protocolId -ne $startupMemoryProtocolId -or $memory.validated -ne $true -or
      $memory.source -ne 'dart:io ProcessInfo' -or $memory.unit -ne 'bytes' -or $samples.Count -ne 4) {
    $problems.Add('Memory protocol requires four validated process-rss-v1 observations.')
    return $problems.ToArray()
  }
  $nativeSamples = @($Child.measurement.clock.nativeSamples)
  $previousPeak = [long]0
  $previousEnd = [long]-1
  for ($index = 0; $index -lt 4; $index++) {
    $sample = $samples[$index]
    if ($sample.point -ne $points[$index]) { $problems.Add('Unexpected memory observation order.') }
    if (-not (Is-ReportInteger $sample.currentRssBytes) -or $sample.currentRssBytes -le 0 -or
        -not (Is-ReportInteger $sample.maxRssBytes) -or $sample.maxRssBytes -lt $sample.currentRssBytes -or
        $sample.maxRssBytes -lt $previousPeak -or $sample.readFailure) {
      $problems.Add('Invalid process RSS or non-monotonic peak at ' + $points[$index])
    } else { $previousPeak = [long]$sample.maxRssBytes }
    if (-not (Is-ReportInteger $sample.readCostUs) -or $sample.readCostUs -lt 0 -or
        -not (Is-ReportInteger $sample.observerCostUs) -or $sample.observerCostUs -lt $sample.readCostUs) {
      $problems.Add('Invalid memory observation cost at ' + $points[$index])
    }
    foreach ($stamp in @($sample.observationStart, $sample.observationEnd)) {
      if ($stamp.utcSourceIsPrecise -ne 1 -or -not (Is-ReportInteger $stamp.nativeSampleIndex) -or
          $stamp.nativeSampleIndex -lt 0 -or $stamp.nativeSampleIndex -ge $nativeSamples.Count) {
        $problems.Add('Memory observation has no precise native clock source.')
        continue
      }
      $native = $nativeSamples[$stamp.nativeSampleIndex]
      $remainder = [long]0
      $nativeUtc = [Math]::DivRem(([long]$native.preciseFileTimeTicks - [long]116444736000000000), [long]10, [ref]$remainder)
      if ($native.index -ne $stamp.nativeSampleIndex -or $nativeUtc -ne $stamp.utcUs -or
          $native.elapsedBeforeUs -ne $stamp.elapsedBeforeUs -or $native.elapsedAfterUs -ne $stamp.elapsedAfterUs) {
        $problems.Add('Memory timestamp does not match its native clock sample.')
      }
    }
    if ($sample.observationStart.nativeSampleIndex -le $previousEnd -or
        $sample.observationEnd.nativeSampleIndex -le $sample.observationStart.nativeSampleIndex) {
      $problems.Add('Memory observation timestamps are not ordered.')
    }
    $previousEnd = [long]$sample.observationEnd.nativeSampleIndex
    if ($index -eq 1 -or $index -eq 2) {
      $raster = if ($index -eq 1) { $Child.measurement.readyRaster } else { $Child.measurement.responseRaster }
      if ($sample.frameNumber -ne $raster.frameNumber -or
          $sample.rasterFinishWallTimeUs -ne $raster.rasterFinishWallTimeUs -or
          $sample.reportStamp.nativeSampleIndex -ne $raster.callbackReceipt.nativeSampleIndex -or
          $sample.reportStamp.utcUs -ne $raster.callbackReceipt.utcUs -or
          $sample.observationStart.nativeSampleIndex -lt $sample.reportStamp.nativeSampleIndex) {
        $problems.Add('Memory observation is not tied to its ready/response raster report.')
      }
    }
  }
  if ($samples[0].observationStart.nativeSampleIndex -le $Child.measurement.entry.nativeSampleIndex -or
      $previousEnd -gt $Child.measurement.measurementEnd.nativeSampleIndex) {
    $problems.Add('Memory observations fall outside the entry/measurement-end boundary.')
  }
  return $problems.ToArray()
}

function Write-JsonAtomic([string]$File, [object]$Value) {
  $temporary = $File + '.tmp'
  [System.IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 30) + "`n",
    [System.Text.UTF8Encoding]::new($false))
  [System.IO.File]::Move($temporary, $File)
}
function Under-Root([string]$Root, [string]$Relative) {
  if ([System.IO.Path]::IsPathRooted($Relative)) { throw 'Relative path required.' }
  $resolved = [System.IO.Path]::GetFullPath((Join-Path $Root $Relative))
  $prefix = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
  if (-not $resolved.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw ('Path escaped root: ' + $Relative)
  }
  return $resolved
}
function Require-RegularFile([string]$File) {
  $item = Get-Item -LiteralPath $File
  if ($item.PSIsContainer -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
    throw ('Expected a regular file: ' + $File)
  }
}
function Probe-PhysicalLock([string]$File) {
  Require-RegularFile $File
  $stream = $null
  $locked = $false
  try {
    $stream = [System.IO.FileStream]::new($File, [System.IO.FileMode]::Open,
      [System.IO.FileAccess]::ReadWrite,
      ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
    $stream.Lock(0, 1)
    $locked = $true
    return @{ path = $File; blocked = $false; nativeError = 0 }
  } catch [System.IO.IOException] {
    $native = $_.Exception.HResult -band 0xffff
    return @{ path = $File; blocked = ($native -eq 33); nativeError = $native;
      error = $_.Exception.Message }
  } finally {
    if ($locked) { $stream.Unlock(0, 1) }
    if ($null -ne $stream) { $stream.Dispose() }
  }
}
function Since-ProcessStartUs([object]$Frame, [DateTime]$StartUtc) {
  if ($null -eq $Frame) { return $null }
  $ticks = [long]$Frame.rasterFinishWallTimeUs * [long]10 + [DateTime]::UnixEpoch.Ticks
  $remainder = [long]0
  return [Math]::DivRem([long]($ticks - $StartUtc.Ticks), [long]10, [ref]$remainder)
}

if (-not $IsWindows) { throw 'The launcher requires Windows.' }
if ($BuildManifests.Count -lt 1 -or $BuildManifests.Count -gt 2) { throw 'Use one smoke build or a before/after pair.' }
if (@($Datasets | Select-Object -Unique).Count -ne $Datasets.Count) { throw 'Duplicate datasets.' }
$fixtures = (Resolve-Path -LiteralPath $FixtureRoot).ProviderPath
$output = [System.IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $output) { throw 'Use a new output root; reports are never overwritten.' }
New-Item -ItemType Directory -Path $output | Out-Null
$builds = foreach ($manifestPath in $BuildManifests) {
  $source = (Resolve-Path -LiteralPath $manifestPath).ProviderPath
  $build = Get-Content -Raw -LiteralPath $source | ConvertFrom-Json
  if ($build.target -ne 'benchmark/startup_main.dart' -or $build.mode -ne 'profile' -or
      $build.platform -ne 'windows' -or $build.revision -notmatch '^[0-9a-f]{40}$' -or
      $build.side -notin @('before', 'after') -or -not $build.buildCommand -or
      -not $build.engineRevision -or -not $build.sdkRevision) {
    throw ('Incomplete Profile build provenance: ' + $source)
  }
  $directory = (Resolve-Path -LiteralPath $build.artifactDirectory).ProviderPath
  foreach ($required in @($build.executable, 'data/app.so', 'flutter_windows.dll', 'data/icudtl.dat')) {
    if ($build.files.PSObject.Properties.Name -notcontains $required) {
      throw ('A required native/Profile artifact has no SHA256: ' + $required)
    }
  }
  foreach ($artifact in $build.files.PSObject.Properties) {
    $file = Under-Root $directory $artifact.Name
    Require-RegularFile $file
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash -ine $artifact.Value) {
      throw ('Build artifact hash mismatch: ' + $file)
    }
  }
  $exe = Under-Root $directory $build.executable
  if ($build.files.PSObject.Properties.Name -notcontains $build.executable) {
    throw 'The executable must have a recorded SHA256.'
  }
  [pscustomobject]@{ value = $build; directory = $directory; exe = $exe; manifest = $source }
}
if (@($builds.value.side | Select-Object -Unique).Count -ne @($builds).Count) {
  throw 'Build sides must be unique.'
}
if (@($builds.value.engineRevision | Select-Object -Unique).Count -ne 1 -or
    @($builds.value.sdkRevision | Select-Object -Unique).Count -ne 1) {
  throw 'Comparison builds must use the same Flutter SDK and engine.'
}
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $output 'launcher.ps1')
$rows = [System.Collections.Generic.List[object]]::new()
for ($repeat = 1; $repeat -le $Repetitions; $repeat++) {
  foreach ($dataset in $Datasets) {
    $fixtureDirectory = Under-Root $fixtures $dataset
    $fixture = Get-Content -Raw -LiteralPath (Join-Path $fixtureDirectory 'fixture.json') | ConvertFrom-Json
    if ($fixture.protocolVersion -ne 1 -or $fixture.dataset -ne $dataset) { throw 'Fixture protocol mismatch.' }
    $orderedBuilds = @($builds | Sort-Object { $_.value.side })
    if ($repeat % 2 -eq 0) { [array]::Reverse($orderedBuilds) }
    foreach ($build in $orderedBuilds) {
      $name = '{0}-{1}-r{2}-{3}' -f $build.value.side, $dataset, $repeat, [Guid]::NewGuid().ToString('N').Substring(0, 8)
      $runRoot = Under-Root $output $name
      New-Item -ItemType Directory -Path $runRoot | Out-Null
      foreach ($entry in $fixture.files.PSObject.Properties) {
        $source = Under-Root $fixtureDirectory $entry.Name
        Require-RegularFile $source
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash -ine $entry.Value) {
          throw ('Fixture hash mismatch: ' + $source)
        }
        $destination = Under-Root $runRoot $entry.Name
        New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination
      }
      Write-JsonAtomic (Join-Path $runRoot 'run.json') @{
        protocolVersion = 1; dataset = $dataset; repetition = $repeat;
        clockProtocolId = $startupClockProtocolId;
        memoryProtocolId = $startupMemoryProtocolId;
        side = $build.value.side; revision = $build.value.revision;
        fixture = $fixture; build = $build.value
      }
      $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
      $startInfo.FileName = $build.exe
      $startInfo.WorkingDirectory = $build.directory
      $startInfo.UseShellExecute = $false
      # This child is the measured GUI. Its first ShowWindow must not inherit
      # SW_HIDE through STARTUPINFO; build/helper processes remain separate.
      $startInfo.CreateNoWindow = $false
      $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
      $startInfo.RedirectStandardOutput = $true
      $startInfo.RedirectStandardError = $true
      $startInfo.ArgumentList.Add('--run-root=' + $runRoot)
      $process = [System.Diagnostics.Process]::new()
      $process.StartInfo = $startInfo
      $invocationUtc = [DateTime]::UtcNow
      $launchTimer = [System.Diagnostics.Stopwatch]::StartNew()
      try { [void]$process.Start() } catch {
        $failedStart = [ordered]@{ side = $build.value.side; dataset = $dataset;
          repetition = $repeat; status = 'failed'; runRoot = $runRoot;
          invocationUtc = $invocationUtc.ToString('o'); failures = @($_.ToString()) }
        Write-JsonAtomic (Join-Path $runRoot 'launcher-result.json') $failedStart
        $rows.Add([pscustomobject]$failedStart)
        $process.Dispose()
        continue
      }
      $processStartUtc = $process.StartTime.ToUniversalTime()
      $startReturnedUtc = [DateTime]::UtcNow
      $stdout = $process.StandardOutput.ReadToEndAsync()
      $stderr = $process.StandardError.ReadToEndAsync()
      Write-JsonAtomic (Join-Path $runRoot 'process.json') @{
        pid = $process.Id; processStartTimeUtc = $processStartUtc.ToString('o');
        invocationUtc = $invocationUtc.ToString('o'); executable = $build.exe;
        startReturnedUtc = $startReturnedUtc.ToString('o');
        launchWindowStyle = 'Normal'; createNoWindow = $false;
        osVersion = [Environment]::OSVersion.VersionString;
        stopwatchFrequency = [System.Diagnostics.Stopwatch]::Frequency
      }
      $timedOut = $false
      $lockProbeHandled = $false
      $launcherFailures = [System.Collections.Generic.List[string]]::new()
      while (-not $process.HasExited) {
        $requestPath = Join-Path $runRoot 'lock-probe-request.json'
        if (-not $lockProbeHandled -and (Test-Path -LiteralPath $requestPath)) {
          $request = $null
          try { $request = Get-Content -Raw -LiteralPath $requestPath | ConvertFrom-Json } catch { }
          if ($null -ne $request) {
            $expectedNotification = Under-Root $runRoot 'notification-runtime.lock'
            $expectedInstance = Under-Root $runRoot 'archive/Sked_instance.lock'
            try {
              if ($request.pid -ne $process.Id -or
                  [System.IO.Path]::GetFullPath($request.notification) -ine $expectedNotification -or
                  [System.IO.Path]::GetFullPath($request.instance) -ine $expectedInstance) {
                throw 'Lock probe requested an unexpected PID or path.'
              }
              $notificationProof = Probe-PhysicalLock $expectedNotification
              $instanceProof = Probe-PhysicalLock $expectedInstance
              $proof = @{ pid = $process.Id; probeProcessId = $PID;
                notification = $notificationProof; instance = $instanceProof;
                allBlockedByLockViolation = ($notificationProof.blocked -and $instanceProof.blocked) }
            } catch {
              $launcherFailures.Add($_.ToString())
              $proof = @{ pid = $process.Id; probeProcessId = $PID;
                allBlockedByLockViolation = $false; error = $_.ToString() }
            }
            Write-JsonAtomic (Join-Path $runRoot 'lock-probe-result.json') $proof
            $lockProbeHandled = $true
          }
        }
        if ($launchTimer.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
          $timedOut = $true
          try { $process.Kill($true) } catch { $launcherFailures.Add($_.ToString()) }
          break
        }
        Start-Sleep -Milliseconds 50
        $process.Refresh()
      }
      if (-not $process.WaitForExit(5000)) {
        Write-JsonAtomic (Join-Path $runRoot 'launcher-result.json') @{
          side = $build.value.side; dataset = $dataset; repetition = $repeat;
          status = 'failed'; pid = $process.Id; runRoot = $runRoot;
          failures = @('Owned benchmark child did not exit; stop before launching another sample.')
        }
        throw ('Owned benchmark process did not exit: ' + $process.Id)
      }
      [System.IO.File]::WriteAllText((Join-Path $runRoot 'stdout.log'), $stdout.GetAwaiter().GetResult())
      [System.IO.File]::WriteAllText((Join-Path $runRoot 'stderr.log'), $stderr.GetAwaiter().GetResult())
      $exitUtc = [DateTime]::UtcNow
      $launcherClockDriftUs = ($exitUtc - $invocationUtc).TotalMilliseconds * 1000 -
        $launchTimer.Elapsed.TotalMilliseconds * 1000
      if ([Math]::Abs($launcherClockDriftUs) -gt 5000 -or
          $processStartUtc -lt $invocationUtc.AddMilliseconds(-5) -or
          $processStartUtc -gt $startReturnedUtc.AddMilliseconds(5)) {
        $launcherFailures.Add('Launcher UTC/monotonic clock correlation failed.')
      }
      $child = $null
      $resultPath = Join-Path $runRoot 'result.json'
      if (Test-Path -LiteralPath $resultPath) {
        try { $child = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json } catch { }
      }
      if ($null -ne $child -and $child.measurement.clock.protocolId -ne $startupClockProtocolId) {
        $launcherFailures.Add('Unsupported startup clock protocol; rebuild both artifacts for ' + $startupClockProtocolId + '.')
      }
      if ($null -ne $child) {
        try {
          foreach ($memoryIssue in @(Get-MemoryContractIssues $child)) { $launcherFailures.Add($memoryIssue) }
        } catch {
          $launcherFailures.Add('Memory contract validation failed: ' + $_.ToString())
        }
      }
      $valid = -not $timedOut -and $launcherFailures.Count -eq 0 -and $process.ExitCode -eq 0 -and
        $child.status -eq 'ok' -and $child.pid -eq $process.Id -and
        $child.compiledRevision -eq $build.value.revision -and
        $child.compiledEngine -eq $build.value.engineRevision -and
        $child.measurement.clock.protocolId -eq $startupClockProtocolId -and
        $child.measurement.clock.utcCorrelationValid -eq $true -and
        $child.measurement.memory.protocolId -eq $startupMemoryProtocolId -and
        $child.measurement.memory.validated -eq $true -and
        $child.measurement.nativeWindowVisibility.validated -eq $true -and $lockProbeHandled
      $firstUs = $null; $readyUs = $null; $responseUs = $null; $inputUs = $null
      if ($valid) {
        $firstUs = Since-ProcessStartUs $child.measurement.firstRaster $processStartUtc
        $readyUs = Since-ProcessStartUs $child.measurement.readyRaster $processStartUtc
        $responseUs = Since-ProcessStartUs $child.measurement.responseRaster $processStartUtc
        $inputUs = [long]$child.measurement.responseRaster.rasterFinishWallTimeUs -
          [long]$child.measurement.input.stamp.utcUs
        if ($firstUs -lt 0 -or $readyUs -lt $firstUs -or $responseUs -lt $readyUs -or $inputUs -lt 0) {
          $launcherFailures.Add('Raster milestones do not follow OS process creation and input order.')
          $valid = $false
        }
      }
      if ($timedOut) { $launcherFailures.Add('Owned benchmark process timed out.') }
      if ($null -eq $child) { $launcherFailures.Add('No complete child result JSON; inspect stderr.log.') }
      if ($process.ExitCode -ne 0) { $launcherFailures.Add('Child exited with code ' + $process.ExitCode) }
      $row = [ordered]@{
        side = $build.value.side; dataset = $dataset; repetition = $repeat;
        pid = $process.Id; exitCode = $process.ExitCode; timedOut = $timedOut;
        status = $(if ($valid) { 'ok' } else { 'failed' }); runRoot = $runRoot;
        processStartTimeUtc = $processStartUtc.ToString('o');
        launcherClockDriftUs = $launcherClockDriftUs;
        clockProtocolId = $child.measurement.clock.protocolId;
        memoryProtocolId = $child.measurement.memory.protocolId;
        memory = $child.measurement.memory;
        entryRssBytes = $(if ($valid) { [long]$child.measurement.memory.samples[0].currentRssBytes } else { $null });
        readyRssBytes = $(if ($valid) { [long]$child.measurement.memory.samples[1].currentRssBytes } else { $null });
        responseRssBytes = $(if ($valid) { [long]$child.measurement.memory.samples[2].currentRssBytes } else { $null });
        endRssBytes = $(if ($valid) { [long]$child.measurement.memory.samples[3].currentRssBytes } else { $null });
        entryToReadyRssDeltaBytes = $(if ($valid) { [long]$child.measurement.memory.samples[1].currentRssBytes - [long]$child.measurement.memory.samples[0].currentRssBytes } else { $null });
        entryToEndRssDeltaBytes = $(if ($valid) { [long]$child.measurement.memory.samples[3].currentRssBytes - [long]$child.measurement.memory.samples[0].currentRssBytes } else { $null });
        peakRssBytes = $(if ($valid) { [long]$child.measurement.memory.samples[3].maxRssBytes } else { $null });
        peakRssGrowthFromEntryBytes = $(if ($valid) { [long]$child.measurement.memory.samples[3].maxRssBytes - [long]$child.measurement.memory.samples[0].maxRssBytes } else { $null });
        processToFirstRasterUs = $(if ($valid) { $firstUs } else { $null });
        processToReadyRasterUs = $(if ($valid) { $readyUs } else { $null });
        inputToResponseRasterUs = $(if ($valid) { $inputUs } else { $null });
        processToTestedResponseRasterUs = $(if ($valid) { $responseUs } else { $null });
        readyObservationDelayUs = $(if ($valid) { [long]$child.measurement.input.stamp.utcUs -
          [long]$child.measurement.readyRaster.rasterFinishWallTimeUs } else { $null });
        resultSha256 = $(if (Test-Path -LiteralPath $resultPath) {
          (Get-FileHash -Algorithm SHA256 -LiteralPath $resultPath).Hash } else { $null });
        readyView = $child.measurement.readyView; responseView = $child.measurement.responseView;
        launchWindowStyle = 'Normal';
        nativeWindowVisibility = $child.measurement.nativeWindowVisibility;
        semanticsTrajectory = (@($child.measurement.semantics | ForEach-Object {
          '{0}/{1}' -f $_.native, $_.framework }) -join '>');
        failures = @($child.failures) + @($launcherFailures)
      }
      Write-JsonAtomic (Join-Path $runRoot 'launcher-result.json') $row
      $rows.Add([pscustomobject]$row)
      Write-Output ('{0} {1} r{2}: {3} pid {4}' -f $row.side, $dataset, $repeat, $row.status, $row.pid)
      $process.Dispose()
      Start-Sleep -Seconds 2
    }
  }
}
$groups = foreach ($group in ($rows | Group-Object side, dataset)) {
  $valid = @($group.Group | Where-Object status -eq 'ok')
  $stats = [ordered]@{}
  foreach ($metric in @('processToFirstRasterUs', 'processToReadyRasterUs', 'inputToResponseRasterUs',
      'entryRssBytes', 'readyRssBytes', 'responseRssBytes', 'endRssBytes',
      'entryToReadyRssDeltaBytes', 'entryToEndRssDeltaBytes', 'peakRssBytes', 'peakRssGrowthFromEntryBytes')) {
    $values = @($valid | ForEach-Object { $_.$metric } | Sort-Object)
    $stats[$metric] = if ($values.Count -eq 0) { $null } else {
      $middle = [int][Math]::Floor($values.Count / 2)
      $median = if ($values.Count % 2 -eq 0) {
        ($values[$middle - 1] + $values[$middle]) / 2.0
      } else { $values[$middle] }
      @{ samples = $values; median = $median;
        min = $values[0]; max = $values[-1] }
    }
  }
  @{ group = $group.Name; planned = $group.Count; valid = $valid.Count;
    completeThreeProcesses = ($valid.Count -eq 3 -and $group.Count -eq 3); metrics = $stats }
}
$viewSignatures = @($rows | Where-Object status -eq 'ok' | ForEach-Object {
  [ordered]@{ width = $_.readyView.physicalWidth; height = $_.readyView.physicalHeight;
    dpr = $_.readyView.devicePixelRatio; hz = $_.readyView.refreshRateHz;
    nativeSemantics = $_.readyView.nativeSemantics;
    frameworkSemantics = $_.readyView.frameworkSemantics;
    win32Visible = $_.readyView.nativeWindow.isWindowVisible;
    win32Minimized = $_.readyView.nativeWindow.isIconic;
    win32Cloaked = $_.readyView.nativeWindow.dwmCloaked;
    win32ClientWidth = $_.readyView.nativeWindow.clientWidth;
    win32ClientHeight = $_.readyView.nativeWindow.clientHeight;
    win32ClientOnScreen = $_.readyView.nativeWindow.intersectsMonitor;
    win32Foreground = $_.readyView.nativeWindow.isForeground;
    semanticsTrajectory = $_.semanticsTrajectory;
    focused = $_.readyView.nativeWindowFocused;
    reduceMotion = $_.readyView.reduceMotion; disableAnimations = $_.readyView.disableAnimations
  } | ConvertTo-Json -Compress
} | Select-Object -Unique)
$allNativeWindowsVisible = ($rows.Count -gt 0 -and
  @($rows | Where-Object { $_.nativeWindowVisibility.validated -ne $true }).Count -eq 0)
Write-JsonAtomic (Join-Path $output 'summary.json') @{
  protocolVersion = 1; rows = @($rows); groups = @($groups);
  clockProtocolId = $startupClockProtocolId;
  memoryProtocolId = $startupMemoryProtocolId;
  matrixComplete = (@($builds).Count -eq 2 -and $Datasets.Count -eq 3 -and
    $Repetitions -eq 3 -and @($rows | Where-Object status -ne 'ok').Count -eq 0);
  comparableViewAndSemanticsState = ($viewSignatures.Count -eq 1);
  allMeasuredNativeWindowsVisible = $allNativeWindowsVisible;
  observedViewSignatures = $viewSignatures;
  claim = $(if ($allNativeWindowsVisible) {
    'Fresh normal-window Profile processes with verified Win32 visibility at ready/input/response; OS page cache retained; isolated native adapters.'
  } else {
    'Win32 visibility acceptance failed or is incomplete; no normal-window startup comparison.'
  });
  warning = 'Review process RSS observation times/costs, Win32 visibility, native/framework semantics, view metrics and all failures before comparing groups.'
}
if (@($rows | Where-Object status -ne 'ok').Count -ne 0) {
  throw 'Startup samples failed; all reports are preserved in the output directory.'
}
if (-not $allNativeWindowsVisible -or $viewSignatures.Count -ne 1) {
  throw 'Startup visibility or view/semantics comparison failed; inspect summary.json.'
}
