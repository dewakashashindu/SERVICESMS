# ============================================================
#  MM RESTAURANT SMS - CLIENT PACKAGE BUILDER
#
#  DEV machine eken run karanna (dotnet SDK 10 + repo one).
#  Admin ONI NA - build witharai!
#
#  Meka karanne:
#   [1] Worker publish (fix wela thiyena aluth code)
#   [2] Aluth exe eka Installer ekata embed
#   [3] Installer publish -> SINGLE EXE (client laata yanne eka!)
#   [4] Client install guide ekakuth hadanawa
#
#  RUN:
#    powershell -ExecutionPolicy Bypass -File build-client-package.ps1
# ============================================================

$ErrorActionPreference = "Stop"

function Write-OK($msg)   { Write-Host "  [OK]  $msg" -ForegroundColor Green }
function Write-BAD($msg)  { Write-Host "  [XX]  $msg" -ForegroundColor Red }
function Write-INFO($msg) { Write-Host "  [i]   $msg" -ForegroundColor Gray }

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  CLIENT PACKAGE BUILDER" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Repo find ---
$repo = $null
foreach ($guess in @(".", ".\SERVICESMS", "$env:USERPROFILE\Downloads\SERVICESMS", "E:\SmsServiceApp\MMRestaurantSMS", "$env:USERPROFILE\Source\Repos\SERVICESMS")) {
    if (Test-Path "$guess\SMSService.Installer\SMSService.Installer.csproj") { $repo = (Resolve-Path $guess).Path; break }
}
if (-not $repo) {
    $repo = Read-Host "  Repo path eka type karanaya (eg E:\SmsServiceApp\MMRestaurantSMS)"
    if (-not (Test-Path "$repo\SMSService.Installer\SMSService.Installer.csproj")) {
        Write-BAD "Repo hambune na!"; exit 1
    }
}
Write-INFO "Repo: $repo"

# --- SNI fix check (installer + worker csproj) ---
foreach ($p in @("$repo\SMSService.Worker\SMSService.Worker.csproj", "$repo\SMSService.Installer\SMSService.Installer.csproj")) {
    $raw = Get-Content $p -Raw
    if ($raw -notmatch 'IncludeNativeLibrariesForSelfExtract') {
        $raw = $raw -replace '<PublishSingleFile>true</PublishSingleFile>',
            "<PublishSingleFile>true</PublishSingleFile>`r`n    <IncludeNativeLibrariesForSelfExtract>true</IncludeNativeLibrariesForSelfExtract>"
        Set-Content -Path $p -Value $raw -Encoding UTF8
        Write-OK "SNI fix add una: $(Split-Path $p -Leaf)"
    }
}

# ------------------------------------------------------------
Write-Host "`n[1/3] WORKER PUBLISH" -ForegroundColor Yellow
dotnet publish "$repo\SMSService.Worker" -c Release --nologo -v q
if ($LASTEXITCODE -ne 0) { Write-BAD "Worker publish fail!"; exit 1 }

$newWorkerExe = "$repo\SMSService.Worker\bin\Release\net10.0-windows\win-x64\publish\SMSService.Worker.exe"
if (-not (Test-Path $newWorkerExe)) { Write-BAD "Worker exe hambune na!"; exit 1 }
Write-OK "Worker publish una! ($([math]::Round((Get-Item $newWorkerExe).Length/1MB)) MB)"

# ------------------------------------------------------------
Write-Host "`n[2/3] INSTALLER EKATA EMBED" -ForegroundColor Yellow
Copy-Item $newWorkerExe "$repo\SMSService.Installer\worker\SMSService.Worker.exe" -Force
Write-OK "Aluth worker exe eka installer ekata embed una!"

# ------------------------------------------------------------
Write-Host "`n[3/3] INSTALLER PUBLISH (SINGLE EXE)" -ForegroundColor Yellow
dotnet publish "$repo\SMSService.Installer" -c Release --nologo -v q
if ($LASTEXITCODE -ne 0) { Write-BAD "Installer publish fail!"; exit 1 }

$installerExe = "$repo\SMSService.Installer\bin\Release\net10.0-windows\win-x64\publish\SMSService.Installer.exe"
if (-not (Test-Path $installerExe)) { Write-BAD "Installer exe hambune na!"; exit 1 }

# --- Client guide eka hadanaya ---
$guide = @"
================================================
 MM RESTAURANT SMS SERVICE - INSTALL GUIDE
================================================

1) Me "SMSService.Installer.exe" file eka DOUBLE-CLICK karanaya
   (Windows "Yes" kiyan UAC prompt ekak enna - eka allow karanaya)

2) Fields 3i fill karanaya:
   - Database Server : SQL server eke name eka
                       (eg: SERVERNAME\SQLEXPRESS nathnam SERVERNAME\SQL2008)
   - SMS API Key     : text.lk dashboard eken API Token eka
   - Sender ID       : text.lk eke approved sender id eka (case sensitive!)

3) "Test Connection" click karanaya
   -> "Database connection successful!" pennanna one

4) "Install Service" click karanaya
   -> Service eka background eke start wei!

5) WEDA KARANAWADA balanna:
   - Log file eka: C:\ProgramData\MMRESTAURANTSMS? -> C:\ProgramData\MMRestaurantSMS\logs\service.log

REQUIREMENTS:
   - Windows 10/11 nathnam Windows Server (64-bit)
   - SQL Server eka network eke access karanna puluwan wenna one
   - Internet (text.lk API ekata)

UNINSTALL (2 widiyata puluwan):
   A) Installer exe eka ayeth run karala "Uninstall" click karanaya
   B) uninstall.ps1 eka run karanaya (Admin PowerShell eken):
      powershell -ExecutionPolicy Bypass -File uninstall.ps1

================================================
"@

$outDir = "$repo\CLIENT_PACKAGE"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
Copy-Item $installerExe "$outDir\SMSService.Installer.exe" -Force
Set-Content -Path "$outDir\HOW-TO-INSTALL.txt" -Value $guide -Encoding UTF8

# Standalone uninstaller ekauth package ekata daanawa
if (Test-Path "$PSScriptRoot\uninstall.ps1") {
    Copy-Item "$PSScriptRoot\uninstall.ps1" "$outDir\uninstall.ps1" -Force
} elseif (Test-Path "$repo\uninstall.ps1") {
    Copy-Item "$repo\uninstall.ps1" "$outDir\uninstall.ps1" -Force
}

Write-OK "Installer build una! ($([math]::Round((Get-Item $installerExe).Length/1MB)) MB)"

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  PACKAGE READY!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-INFO "Folder: $outDir"
Write-INFO "Files:"
Get-ChildItem $outDir | ForEach-Object { Write-INFO ("   " + $_.Name + "  (" + [math]::Round($_.Length/1MB) + " MB)") }
Write-Host ""
Write-INFO "Me folder eka (ZIP karala) client laata yawanaya!"
Write-INFO "  - SMSService.Installer.exe  = install karanna one EXE eka"
Write-INFO "  - HOW-TO-INSTALL.txt        = client laata guide eka"
Write-Host ""
pause
