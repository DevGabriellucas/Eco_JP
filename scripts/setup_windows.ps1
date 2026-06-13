# Setup automatizado do EcoJP para Windows.
#
# Uso (PowerShell, na raiz do projeto):
#   powershell -ExecutionPolicy Bypass -File .\scripts\setup_windows.ps1
#
# O que este script faz:
#  1. Libera a execucao de scripts para o usuario atual (necessario para o npm/dart/flutterfire funcionarem)
#  2. Roda "flutter pub get"
#  3. Instala o firebase-tools (CLI do Firebase) se necessario
#  4. Instala/atualiza o FlutterFire CLI
#  5. Garante que o Pub Cache (onde o flutterfire e instalado) esta no PATH do usuario
#
# Depois de rodar este script, siga os passos manuais que ele imprime no final
# (login no Firebase e "flutterfire configure"), pois exigem sua conta Google.

$ErrorActionPreference = "Stop"

Write-Host "=== EcoJP - Setup Windows ===" -ForegroundColor Cyan

# 1. Politica de execucao do PowerShell
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted" -or $policy -eq "Undefined") {
    Write-Host "Liberando execucao de scripts para o usuario atual (Set-ExecutionPolicy CurrentUser RemoteSigned)..." -ForegroundColor Yellow
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
} else {
    Write-Host "Politica de execucao OK ($policy)" -ForegroundColor Green
}

# 2. Verifica o Flutter
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter nao encontrado no PATH." -ForegroundColor Red
    Write-Host "Instale o Flutter antes de continuar: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Red
    exit 1
}

Write-Host "Instalando dependencias do Flutter (flutter pub get)..." -ForegroundColor Cyan
flutter pub get

# 3. firebase-tools
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Host "npm nao encontrado no PATH. Instale o Node.js antes de continuar: https://nodejs.org" -ForegroundColor Red
        exit 1
    }
    Write-Host "Instalando firebase-tools (npm install -g firebase-tools)..." -ForegroundColor Cyan
    npm install -g firebase-tools
} else {
    Write-Host "firebase-tools ja instalado" -ForegroundColor Green
}

# 4. FlutterFire CLI
Write-Host "Instalando/atualizando o FlutterFire CLI (dart pub global activate flutterfire_cli)..." -ForegroundColor Cyan
dart pub global activate flutterfire_cli

# 5. PATH do Pub Cache (onde o comando "flutterfire" e instalado)
$pubCacheBin = Join-Path $env:LOCALAPPDATA "Pub\Cache\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$pubCacheBin*") {
    Write-Host "Adicionando '$pubCacheBin' ao PATH do usuario..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$pubCacheBin", "User")
    $env:Path += ";$pubCacheBin"
    Write-Host "PATH atualizado. Abra um NOVO terminal para o comando 'flutterfire' funcionar." -ForegroundColor Yellow
} else {
    Write-Host "PATH ja contem o Pub Cache do Dart" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Setup automatico concluido! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Proximos passos (manuais, exigem sua conta Google):" -ForegroundColor Cyan
Write-Host "  1. Abra um NOVO terminal (para o PATH atualizar)"
Write-Host "  2. firebase login"
Write-Host "  3. flutterfire configure"
Write-Host "  4. Configure Google Maps e Cloudinary -> veja CONFIGURACAO.md"
Write-Host "  5. flutter run"
