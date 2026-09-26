param(
  [Parameter(Mandatory = $true)][string]$PackagePath,
  [Parameter(Mandatory = $true)][string]$ExpectedVersion
)

$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'microsoft_store.json') -Raw -Encoding utf8 | ConvertFrom-Json
if ($ExpectedVersion -notmatch '^[1-9][0-9]*\.[0-9]+\.[0-9]+\.0$') {
  throw 'Store package versions must have a nonzero major version and a zero revision.'
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $PackagePath).Path)
try {
  $entry = $archive.GetEntry('AppxManifest.xml')
  if ($null -eq $entry) { throw 'Store package is missing AppxManifest.xml.' }
  $stream = $entry.Open()
  try {
    $readerSettings = [System.Xml.XmlReaderSettings]::new()
    $readerSettings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $reader = [System.Xml.XmlReader]::Create($stream, $readerSettings)
    try {
      $manifest = [System.Xml.XmlDocument]::new()
      $manifest.XmlResolver = $null
      $manifest.Load($reader)
    } finally { $reader.Dispose() }
  } finally { $stream.Dispose() }
  $identity = $manifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Identity']")
  $publisher = $manifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Properties']/*[local-name()='PublisherDisplayName']")
  if ($null -eq $identity -or $null -eq $publisher -or
      $identity.GetAttribute('Name') -cne $config.identityName -or
      $identity.GetAttribute('Publisher') -cne $config.publisher -or
      $publisher.InnerText -cne $config.publisherDisplayName -or
      $identity.GetAttribute('Version') -cne $ExpectedVersion -or
      $identity.GetAttribute('ProcessorArchitecture') -cne 'x64') {
    throw 'Store package identity, publisher, architecture or version does not match the submission configuration.'
  }
  # Windows derives the PublisherId from the first 64 bits of SHA-256 over
  # the exact UTF-16LE Publisher, encoded with its package-identity alphabet.
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try { $publisherHash = $sha256.ComputeHash([System.Text.Encoding]::Unicode.GetBytes($identity.GetAttribute('Publisher'))) }
  finally { $sha256.Dispose() }
  $bits = (($publisherHash[0..7] | ForEach-Object { [Convert]::ToString($_, 2).PadLeft(8, '0') }) -join '') + '0'
  $alphabet = '0123456789abcdefghjkmnpqrstvwxyz'
  $publisherId = (0..12 | ForEach-Object { $alphabet[[Convert]::ToInt32($bits.Substring($_ * 5, 5), 2)] }) -join ''
  if (($identity.GetAttribute('Name') + '_' + $publisherId) -cne $config.packageFamilyName) {
    throw 'Store package family name does not match Partner Center.'
  }
  $application = $manifest.SelectSingleNode("/*[local-name()='Package']/*[local-name()='Applications']/*[local-name()='Application']")
  if ($null -eq $application -or $application.GetAttribute('Id') -cne 'sked') {
    throw 'Store package application ID must remain sked to preserve its AUMID.'
  }
  $toast = $manifest.SelectSingleNode("//*[local-name()='ToastNotificationActivation']")
  if ($null -eq $toast -or $toast.GetAttribute('ToastActivatorCLSID') -cne '5d9d8f6a-4d1a-4f3a-9b0a-6a3e7d2c1f58') {
    throw 'Store package is missing the expected notification activator.'
  }
  if ($null -ne $archive.GetEntry('AppxSignature.p7x')) {
    throw 'Store submission packages must not carry the local sideload signing certificate.'
  }
} finally { $archive.Dispose() }
Write-Output "Verified Store identity: $($config.packageFamilyName); product: $($config.storeId)"
