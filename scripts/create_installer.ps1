# Build Flowdesk Windows release and compile the Inno Setup installer.
#
# Usage:
#   .\scripts\create_installer.ps1
#   .\scripts\create_installer.ps1 -Version 1.0.2
#   .\scripts\create_installer.ps1 -SkipBuild

param(
    [string]$Version = "1.0.1",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$releaseDir = Join-Path $root "build\windows\x64\runner\Release"
$iscc = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"

if (-not $SkipBuild) {
    Write-Host "Building Windows release..."
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }
}

if (-not (Test-Path $releaseDir)) {
    throw "Release folder not found: $releaseDir`nRun: flutter build windows --release"
}

if (-not (Test-Path $iscc)) {
    throw @"
Inno Setup 6 not found at:
  $iscc

Install from: https://jrsoftware.org/isinfo.php
"@
}

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Path $dist -Force | Out-Null

$iss = Join-Path $root "installer\invisible_ai_assistant.iss"
Write-Host "Compiling installer (version $Version)..."
& $iscc "/DMyAppVersion=$Version" $iss
if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE" }

$installer = Join-Path $dist "invisible_ai_assistant_setup_$Version.exe"
if (-not (Test-Path $installer)) {
    throw "Expected installer not found: $installer"
}

Write-Host ""
Write-Host "Done: $installer"
