# ============================================================
#  MM RESTAURANT SMS - UNINSTALLER (standalone)
#
#  Installer exe eka nathi welawakata meka use karanaya.
#  Karanawa:
#    - Service stop + delete
#    - C:\Program Files\MMRestaurantSMS  folder eka delete
#    - C:\ProgramData\MMRestaurantSMS    (config + logs) delete
#
#  RUN (Admin PowerShell):
#    powershell -ExecutionPolicy Bypass -File uninstall.ps1
# ============================================================

$ErrorActionPreference = "Continue"

function Write-OK($msg)   { Write-Host "  [OK]  $msg" -ForegroundColor Green }
function Write-BAD($msg)  { Write-Host "  [XX]  $msg" -ForegroundColor Red }
function Write-INFO($msg) { Write-Host "  [i]   $msg" -ForegroundColor Gray }

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  MM RESTAURANT SMS - UNINSTALLER" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Admin check ---
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-BAD "Me PowerShell window eka ADMIN wela NE!"
    Write-INFO "Start right-click -> 'Terminal (Admin)' nathnam 'PowerShell (Admin)'"
    Read-Host "  ENTER karanna exit karanna" | Out-Null
    exit 1
}

# --- Confirm ---
$ans = Read-Host "  SMS Service eka UNINSTALL karanna? (y/n)"
if ($ans -ne "y") { Write-INFO "Cancel una."; exit 0 }

# --- 1. Service stop ---
Write-Host "`n[1/4] SERVICE STOP" -ForegroundColor Yellow
$svc = Get-Service -Name "MMRestaurantSMSService" -ErrorAction SilentlyContinue
if ($svc) {
    Stop-Service -Name "MMRestaurantSMSService" -Force -ErrorAction SilentlyContinue
    $tries = 0
    while ((Get-Process -Name "SMSService.Worker" -ErrorAction SilentlyContinue) -and $tries -lt 10) {
        Start-Sleep 1; $tries++
    }
    if (Get-Process -Name "SMSService.Worker" -ErrorAction SilentlyContinue) {
        taskkill /f /im SMSService.Worker.exe 2>$null | Out-Null
        Start-Sleep 2
    }
    Write-OK "Service stop una"
} else {
    Write-INFO "Service install wela na (witharak clean karanna)"
}

# --- 2. Service delete ---
Write-Host "`n[2/4] SERVICE DELETE" -ForegroundColor Yellow
sc.exe delete MMRestaurantSMSService
Write-OK "Service delete command eka run una"

# --- 3. Program Files folder ---
Write-Host "`n[3/4] FILES DELETE" -ForegroundColor Yellow
$pf = "C:\Program Files\MMRestaurantSMS"
if (Test-Path $pf) {
    Remove-Item $pf -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $pf) { Write-BAD "Delete karanne na: $pf (restart karala ayeth run karanaya)" }
    else { Write-OK "Delete una: $pf" }
} else { Write-INFO "$pf nathiwela thiyenawa" }

# --- 4. Config + logs ---
Write-Host "`n[4/4] CONFIG + LOGS DELETE" -ForegroundColor Yellow
$pd = "$env:ProgramData\MMRestaurantSMS"
if (Test-Path $pd) {
    Remove-Item $pd -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $pd) { Write-BAD "Delete karanne na: $pd" }
    else { Write-OK "Delete una: $pd (config + logs)" }
} else { Write-INFO "$pd nathiwela thiyenawa" }

Write-Host "`n============================================" -ForegroundColor Green
Write-Host "  UNINSTALL COMPLETE!" -ForegroundColor Green
Write-Host "  (Database eke Tbl_SMS table eka nathi karanne" -ForegroundColor Gray
Write-Host "   na - eka POS system ekema)" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Green
Read-Host "  ENTER karanna exit karanna" | Out-Null
