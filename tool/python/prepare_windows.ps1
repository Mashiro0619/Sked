param([Parameter(Mandatory = $true)][string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
$configuration = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runtime.json') -Raw | ConvertFrom-Json
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
if ([IO.Path]::GetFileName($outputPath) -ne 'python') {
    throw 'The generated runtime directory must be named python.'
}
$parentPath = [IO.Path]::GetDirectoryName($outputPath)
if ([string]::IsNullOrEmpty($parentPath) -or $parentPath -eq [IO.Path]::GetPathRoot($outputPath)) {
    throw 'The Python runtime must be generated inside the build directory.'
}
New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
$stagingPath = Join-Path $parentPath ('python-stage-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stagingPath | Out-Null
try {
    $archivePath = Join-Path $stagingPath 'python.zip'
    Invoke-WebRequest -Uri $configuration.url -OutFile $archivePath
    if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $configuration.sha256) {
        throw 'The downloaded CPython archive does not match runtime.json.'
    }
    $runtimePath = Join-Path $stagingPath 'python'
    Expand-Archive -LiteralPath $archivePath -DestinationPath $runtimePath
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'bootstrap.py'), (Join-Path $PSScriptRoot 'sked_runtime.py') -Destination $runtimePath
    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $runtimePath 'python311._pth'), "python311.zip`n.`nLib/site-packages`n", $utf8)
    $files = [ordered]@{}
    Get-ChildItem -LiteralPath $runtimePath -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($runtimePath.Length + 1).Replace('\', '/')
        $files[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $manifest = [ordered]@{
        schema = 1
        version = $configuration.version
        architecture = $configuration.architecture
        archiveDigest = $configuration.sha256
        dependencies = $configuration.dependencies
        files = $files
    }
    [IO.File]::WriteAllText((Join-Path $runtimePath 'manifest.json'), ($manifest | ConvertTo-Json -Depth 8), $utf8)
    if (Test-Path -LiteralPath $outputPath) {
        $previousManifest = Join-Path $outputPath 'manifest.json'
        if (-not (Test-Path -LiteralPath $previousManifest) -and
            (Get-ChildItem -LiteralPath $outputPath -Force | Select-Object -First 1)) {
            throw 'The output directory already exists and is not a generated Sked Python bundle.'
        }
        Remove-Item -LiteralPath $outputPath -Recurse -Force
    }
    Move-Item -LiteralPath $runtimePath -Destination $outputPath
} finally {
    if (Test-Path -LiteralPath $stagingPath) {
        Remove-Item -LiteralPath $stagingPath -Recurse -Force
    }
}
