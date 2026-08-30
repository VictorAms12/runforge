$ErrorActionPreference = 'Stop'

$repo = 'VictorAms12/runforge'
$alias = 'runforge'
$backupDir = Join-Path $env:USERPROFILE '.runforge\signing'
$keystorePath = Join-Path $backupDir 'runforge-release.jks'
$credentialsPath = Join-Path $backupDir 'KEEP-PRIVATE.txt'

function New-RandomHexPassword {
  $bytes = New-Object byte[] 24
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $rng.GetBytes($bytes)
  } finally {
    $rng.Dispose()
  }
  return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}

if (-not (Get-Command keytool -ErrorAction SilentlyContinue)) {
  throw 'keytool não encontrado. Instale/configure JDK 17 e confirme que keytool está no PATH.'
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw 'GitHub CLI (gh) não encontrado. Instale o GitHub CLI e execute gh auth login antes deste script.'
}

Write-Host 'Validando autenticação do GitHub CLI...'
gh auth status | Out-Host

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

if (Test-Path $credentialsPath) {
  $saved = Get-Content $credentialsPath -Raw
  $passwordMatch = [regex]::Match($saved, '(?m)^password=(.+)$')
  if (-not $passwordMatch.Success) {
    throw "Arquivo de credenciais existente inválido: $credentialsPath"
  }
  $password = $passwordMatch.Groups[1].Value.Trim()
} else {
  $password = New-RandomHexPassword
}

if (-not (Test-Path $keystorePath)) {
  Write-Host 'Criando a chave de assinatura permanente do RunForge...'
  & keytool -genkeypair -v `
    -keystore $keystorePath `
    -storetype JKS `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias $alias `
    -storepass $password `
    -keypass $password `
    -dname 'CN=RunForge, OU=Mobile, O=RunForge, C=BR' | Out-Host
}

$credentials = @"
RUNFORGE ANDROID SIGNING BACKUP - KEEP PRIVATE

repository=$repo
alias=$alias
password=$password
keystore=$keystorePath

IMPORTANTE:
- Guarde este arquivo e o .jks em local seguro e com backup.
- Não faça commit destes arquivos.
- Perder esta chave impede atualizar instalações assinadas por ela fora de mecanismos de rotação compatíveis.
"@
[System.IO.File]::WriteAllText($credentialsPath, $credentials, [System.Text.UTF8Encoding]::new($false))

$base64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($keystorePath))

Write-Host 'Enviando credenciais criptografadas para GitHub Actions Secrets...'
gh secret set ANDROID_KEYSTORE_BASE64 --repo $repo --body $base64 | Out-Host
gh secret set ANDROID_KEY_ALIAS --repo $repo --body $alias | Out-Host
gh secret set ANDROID_KEY_PASSWORD --repo $repo --body $password | Out-Host
gh secret set ANDROID_STORE_PASSWORD --repo $repo --body $password | Out-Host

Write-Host ''
Write-Host 'Assinatura persistente configurada.' -ForegroundColor Green
Write-Host "Backup privado: $backupDir" -ForegroundColor Yellow
Write-Host 'A partir do primeiro APK gerado com estes Secrets, mantenha esta mesma chave para permitir atualização por cima.'
