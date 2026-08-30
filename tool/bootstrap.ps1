$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter não encontrado no PATH. Instale/configure o Flutter antes de executar este script.'
}

$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("runforge_" + [guid]::NewGuid().ToString('N'))

Write-Host 'Gerando shells Android/iOS com identidade fixa do RunForge...'
flutter create $temp --project-name runforge --org com.runforge --platforms=android,ios | Out-Host

foreach ($platform in @('android', 'ios')) {
  $target = Join-Path $root $platform
  if (Test-Path $target) { Remove-Item $target -Recurse -Force }
  Copy-Item (Join-Path $temp $platform) $target -Recurse -Force
}
if (Test-Path (Join-Path $temp '.metadata')) {
  Copy-Item (Join-Path $temp '.metadata') (Join-Path $root '.metadata') -Force
}
Remove-Item $temp -Recurse -Force

$privateSigningDir = Join-Path $env:USERPROFILE '.runforge\signing'
$privateKeystore = Join-Path $privateSigningDir 'runforge-release.jks'
$privateCredentials = Join-Path $privateSigningDir 'KEEP-PRIVATE.txt'

if ((Test-Path $privateKeystore) -and (Test-Path $privateCredentials)) {
  $saved = Get-Content $privateCredentials -Raw
  $passwordMatch = [regex]::Match($saved, '(?m)^password=(.+)$')
  $aliasMatch = [regex]::Match($saved, '(?m)^alias=(.+)$')

  if ($passwordMatch.Success -and $aliasMatch.Success) {
    $password = $passwordMatch.Groups[1].Value.Trim()
    $alias = $aliasMatch.Groups[1].Value.Trim()
    $androidKeystore = Join-Path $root 'android/app/runforge-release.jks'
    $keyProperties = Join-Path $root 'android/key.properties'

    Copy-Item $privateKeystore $androidKeystore -Force
    $properties = @"
storePassword=$password
keyPassword=$password
keyAlias=$alias
storeFile=runforge-release.jks
"@
    [System.IO.File]::WriteAllText($keyProperties, $properties, [System.Text.UTF8Encoding]::new($false))
    Write-Host 'Assinatura Android persistente aplicada ao projeto local.' -ForegroundColor Green
  }
}

Push-Location $root
try {
  dart run tool/configure_platforms.dart all | Out-Host
  dart run tool/release_guard.dart | Out-Host
  flutter pub get | Out-Host
  Write-Host ''
  Write-Host 'RunForge pronto. Execute: flutter run' -ForegroundColor Green
  Write-Host 'Para APK release: flutter build apk --release'
} finally {
  Pop-Location
}
