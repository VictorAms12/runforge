$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter não encontrado no PATH. Instale/configure o Flutter antes de executar este script.'
}

$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("runforge_" + [guid]::NewGuid().ToString('N'))

Write-Host 'Gerando shells Android/iOS com a versão local do Flutter...'
flutter create $temp --project-name runforge --org com.runforge --platforms=android,ios | Out-Host

foreach ($platform in @('android', 'ios')) {
  $target = Join-Path $root $platform
  if (Test-Path $target) { Remove-Item $target -Recurse -Force }
  Copy-Item (Join-Path $temp $platform) $target -Recurse -Force
}
if (Test-Path (Join-Path $temp '.metadata')) {
  Copy-Item (Join-Path $temp '.metadata') (Join-Path $root '.metadata') -Force
}

$manifestPath = Join-Path $root 'android/app/src/main/AndroidManifest.xml'
$manifest = Get-Content $manifestPath -Raw
if ($manifest -notmatch 'ACCESS_FINE_LOCATION') {
  $permissions = @'
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
'@
  $manifestReplacement = '$1' + "`r`n" + $permissions
  $manifest = [regex]::Replace($manifest, '(<manifest[^>]*>)', $manifestReplacement, 1)
  [System.IO.File]::WriteAllText($manifestPath, $manifest, [System.Text.UTF8Encoding]::new($false))
}

$plistPath = Join-Path $root 'ios/Runner/Info.plist'
$plist = Get-Content $plistPath -Raw
if ($plist -notmatch 'NSLocationWhenInUseUsageDescription') {
  $locationKey = @'
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>RunForge usa sua localização durante o treino para calcular distância e ritmo.</string>
'@
  $plist = [regex]::Replace($plist, '</dict>\s*</plist>', "$locationKey`r`n</dict>`r`n</plist>", 1)
  [System.IO.File]::WriteAllText($plistPath, $plist, [System.Text.UTF8Encoding]::new($false))
}

$podfilePath = Join-Path $root 'ios/Podfile'
if (Test-Path $podfilePath) {
  $podfile = Get-Content $podfilePath -Raw
  if ($podfile -notmatch 'BYPASS_PERMISSION_LOCATION_ALWAYS') {
    $needle = 'flutter_additional_ios_build_settings(target)'
    $replacement = @'
flutter_additional_ios_build_settings(target)
    if target.name == 'geolocator_apple'
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
          '$(inherited)',
          'BYPASS_PERMISSION_LOCATION_ALWAYS=1'
        ]
      end
    end
'@
    $podfile = $podfile.Replace($needle, $replacement)
    [System.IO.File]::WriteAllText($podfilePath, $podfile, [System.Text.UTF8Encoding]::new($false))
  }
}

Remove-Item $temp -Recurse -Force
Push-Location $root
try {
  flutter pub get | Out-Host
  Write-Host ''
  Write-Host 'RunForge pronto. Execute: flutter run' -ForegroundColor Green
} finally {
  Pop-Location
}
