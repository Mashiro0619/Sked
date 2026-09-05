param(
  [switch]$Unsigned
)

$ErrorActionPreference = 'Stop'

$versionMatch = Select-String -Path 'pubspec.yaml' -Pattern '^\s*version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?\s*$'
if ($null -eq $versionMatch) {
  throw 'Could not read the Flutter version from pubspec.yaml.'
}
$pubspecVersion = $versionMatch.Matches[0].Groups[1].Value
$buildNumber = if ($versionMatch.Matches[0].Groups[2].Success) {
  $versionMatch.Matches[0].Groups[2].Value
} else {
  '0'
}
$msixVersion = "$pubspecVersion.$buildNumber"

$msixArgs = @(
  'run',
  'msix:create',
  '--build-windows',
  'false',
  '--version',
  $msixVersion,
  '--install-certificate',
  'false'
)

if ($Unsigned) {
  $msixArgs += @(
    '--sign-msix',
    'false',
    '--publisher',
    'CN=Mashiro, O=Mashiro, C=CN'
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
    '--certificate-path',
    $certificatePath,
    '--certificate-password',
    $certificatePassword,
    '--publisher',
    $publisher
  )
}

& dart @msixArgs
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
