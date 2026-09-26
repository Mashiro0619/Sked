param(
  [switch]$Unsigned,
  [switch]$Store
)

$ErrorActionPreference = 'Stop'
if ($Unsigned -and $Store) {
  throw 'Choose either -Store or -Unsigned, not both.'
}
if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne [System.Runtime.InteropServices.Architecture]::X64) {
  throw 'This MSIX script currently supports x64 build hosts only.'
}

$versionPattern = '^\s*version:\s*(?<version>(?<major>0|[1-9][0-9]*)\.(?<minor>0|[1-9][0-9]*)\.(?<patch>0|[1-9][0-9]*)(?:-(?<prerelease>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+(?<build>[0-9]+))?)\s*$'
$versionMatches = @(Select-String -LiteralPath 'pubspec.yaml' -Pattern $versionPattern)
if ($versionMatches.Count -ne 1) {
  throw 'Could not read the Flutter version from pubspec.yaml.'
}
$groups = $versionMatches[0].Matches[0].Groups
$flutterVersion = $groups['version'].Value
$releaseVersion = $flutterVersion.Split('+')[0]
if ($groups['prerelease'].Success) {
  foreach ($identifier in $groups['prerelease'].Value.Split('.')) {
    if ($identifier -match '^0[0-9]+$') {
      throw 'Could not read the Flutter version: numeric prerelease identifiers cannot have leading zeroes.'
    }
  }
}
$components = @{}
foreach ($component in @('major', 'minor', 'patch', 'build')) {
  $raw = if ($groups[$component].Success) { $groups[$component].Value } else { '0' }
  $number = 0
  if (-not [int]::TryParse($raw, [ref]$number) -or $number -gt 65535) {
    throw "MSIX version component '$component' must be between 0 and 65535."
  }
  $components[$component] = $number
}

# Store revisions must be zero. The globally increasing Flutter build number
# occupies the third component so Alpha/RC/final builds remain upgradable.
# Sideloaded packages retain the historical major.minor.patch.build mapping.
$msixVersion = '{0}.{1}.{2}.{3}' -f $components['major'], $components['minor'], $components['patch'], $components['build']
$storeId = ''
$storeConfig = $null
$packagePath = $null
$msixArgs = @(
  'run', 'msix:create',
  '--build-windows', 'false',
  '--architecture', 'x64',
  '--install-certificate', 'false'
)

if ($Store) {
  if ($components['major'] -eq 0 -or -not $groups['build'].Success -or $components['build'] -eq 0) {
    throw 'Store packages require a nonzero major version and an explicit positive build number.'
  }
  $configPath = Join-Path $PSScriptRoot 'microsoft_store.json'
  $storeConfig = Get-Content -LiteralPath $configPath -Raw -Encoding utf8 | ConvertFrom-Json
  foreach ($field in @('identityName', 'publisher', 'publisherDisplayName', 'packageFamilyName', 'storeId')) {
    $value = $storeConfig.$field
    if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value) -or $value.Trim() -cne $value -or $value.Contains('&#')) {
      throw "Invalid Microsoft Store identity field: $field. Copy the exact value from Partner Center."
    }
  }
  if ($storeConfig.identityName -cnotmatch '^[A-Za-z0-9.-]{3,50}$' -or
      $storeConfig.publisher -cnotmatch '^CN=[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$' -or
      $storeConfig.storeId -cnotmatch '^[A-Z0-9]{12}$' -or
      $storeConfig.packageFamilyName -cnotmatch ('^' + [regex]::Escape($storeConfig.identityName) + '_[a-z0-9]{13}$')) {
    throw 'Invalid Microsoft Store product identity configuration.'
  }
  $storeId = $storeConfig.storeId
  $msixVersion = '{0}.{1}.{2}.0' -f $components['major'], $components['minor'], $components['build']
  $outputPath = Join-Path (Get-Location).ProviderPath 'build/microsoft-store'
  $outputName = "sked-v$releaseVersion-store-x64"
  $packagePath = Join-Path $outputPath "$outputName.msix"
  $msixArgs += @(
    '--store', '--sign-msix', 'false',
    '--identity-name', $storeConfig.identityName,
    '--publisher', $storeConfig.publisher,
    '--publisher-display-name', $storeConfig.publisherDisplayName,
    '--output-path', $outputPath,
    '--output-name', $outputName
  )
} elseif ($Unsigned) {
  $msixArgs += @(
    '--sign-msix', 'false',
    '--publisher', 'CN=Mashiro, O=Mashiro, C=CN'
  )
} else {
  $certificatePath = $env:SKED_MSIX_CERTIFICATE_PATH
  $certificatePassword = $env:SKED_MSIX_CERTIFICATE_PASSWORD
  $publisher = $env:SKED_MSIX_PUBLISHER
  if ([string]::IsNullOrWhiteSpace($certificatePath) -or
      [string]::IsNullOrWhiteSpace($certificatePassword) -or
      [string]::IsNullOrWhiteSpace($publisher)) {
    throw 'Set SKED_MSIX_CERTIFICATE_PATH, SKED_MSIX_CERTIFICATE_PASSWORD, and SKED_MSIX_PUBLISHER for a signed release MSIX.'
  }
  if (-not (Test-Path -LiteralPath $certificatePath -PathType Leaf)) {
    throw "MSIX certificate was not found: $certificatePath"
  }
  $msixArgs += @(
    '--certificate-path', $certificatePath,
    '--certificate-password', $certificatePassword,
    '--publisher', $publisher
  )
}
$msixArgs += @('--version', $msixVersion)

# Always rebuild the requested distribution. Merely changing the manifest must
# never package an executable left over from the other update channel.
$buildArgs = @(
  'build', 'windows', '--release',
  "--dart-define=SKED_MICROSOFT_STORE_ID=$storeId"
)
& flutter @buildArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& dart @msixArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($Store) {
  & (Join-Path $PSScriptRoot 'verify_store_msix.ps1') -PackagePath $packagePath -ExpectedVersion $msixVersion
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Output "Store submission package: $packagePath"
  Write-Output "App version: $flutterVersion; Store package version: $msixVersion"
  Write-Output 'This unsigned submission package is for Partner Center, not direct sideload installation.'
}
