# ============================================================
#  MM Restaurant SMS - FULL DIAGNOSTIC SCRIPT
#  Meka build karanna one NA - Windows eke direct run karanawa.
#
#  Run karanna (PowerShell eken):
#    powershell -ExecutionPolicy Bypass -File diagnose.ps1
#
#  Check karanne:
#   [1] Windows Service status eka
#   [2] Config file eka + decrypt karala values
#   [3] DB connection + pending SMS count
#   [4] text.lk API key eka + test SMS ekak
#   [5] Log file eke last lines
# ============================================================

$ErrorActionPreference = "Continue"

# TLS 1.2 enable (PS 5.1 + old .NET nisa)
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function Write-OK($msg)   { Write-Host "    [OK]  $msg" -ForegroundColor Green }
function Write-BAD($msg)  { Write-Host "    [XX]  $msg" -ForegroundColor Red }
function Write-INFO($msg) { Write-Host "    [i]   $msg" -ForegroundColor Gray }

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  MM RESTAURANT SMS - DIAGNOSTIC" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# ------------------------------------------------------------
Write-Host "`n[1] WINDOWS SERVICE" -ForegroundColor Yellow
$svc = Get-Service -Name "MMRestaurantSMSService" -ErrorAction SilentlyContinue
if ($svc) {
    if ($svc.Status -eq "Running") { Write-OK "Service RUNNING" }
    else { Write-BAD "Service installed but status: $($svc.Status)" }
    $exe = (Get-CimInstance Win32_Service -Filter "Name='MMRestaurantSMSService'" -ErrorAction SilentlyContinue).PathName
    if ($exe) {
        Write-INFO "EXE: $exe"
        $exePath = $exe.Trim('"')
        if (Test-Path $exePath) {
            $dt = (Get-Item $exePath).LastWriteTime
            $size = [math]::Round((Get-Item $exePath).Length / 1MB)
            Write-INFO "EXE date: $dt  ($size MB)"
            if ($dt -lt (Get-Date).AddDays(-7)) { Write-BAD "EXE eka PARA (7 dinata wada gammulis)! Fix deploy wela NA!" }
        } else { Write-BAD "EXE file eka neme ne! ($exePath)" }
    }
} else {
    Write-BAD "Service INSTALL wela NEY!"
    Write-INFO "Installer eken install karanna, nathnam:"
    Write-INFO "  sc create MMRestaurantSMSService binPath= `"C:\Program Files\MMRestaurantSMS\SMSService.Worker.exe`" start= auto"
}

# ------------------------------------------------------------
Write-Host "`n[2] CONFIG FILE" -ForegroundColor Yellow
$configPath = "$env:ProgramData\MMRestaurantSMS\config.enc"
$dbServer = $null; $apiKey = $null; $senderId = $null

if (Test-Path $configPath) {
    Write-OK "config.enc heiyanheiyan"
    try {
        $key = [byte[]](0x4D,0x4D,0x52,0x45,0x53,0x54,0x5F,0x53,0x45,0x43,0x52,0x45,0x54,0x5F,0x4B,0x45,0x59,0x5F,0x32,0x30,0x32,0x34,0x5F,0x58,0x59,0x5A,0x41,0x42,0x43,0x44,0x45,0x46)
        $iv  = [byte[]](0x53,0x4D,0x53,0x53,0x56,0x43,0x5F,0x49,0x56,0x5F,0x4D,0x4D,0x52,0x45,0x53,0x54)

        function Decrypt-Value([string]$b64) {
            $bytes = [Convert]::FromBase64String($b64)
            $aes = [System.Security.Cryptography.Aes]::Create()
            $aes.Key = $key; $aes.IV = $iv; $aes.Mode = "CBC"; $aes.Padding = "PKCS7"
            $dec = $aes.CreateDecryptor().TransformFinalBlock($bytes, 0, $bytes.Length)
            [System.Text.Encoding]::UTF8.GetString($dec)
        }

        $json = Get-Content $configPath -Raw | ConvertFrom-Json
        $dbServer = Decrypt-Value $json.DbServer
        $apiKey   = Decrypt-Value $json.ApiKey
        $senderId = Decrypt-Value $json.SenderId

        Write-INFO "DbServer : $dbServer"
        if ($apiKey) {
            $mask = $apiKey.Substring(0, [Math]::Min(4, $apiKey.Length)) + "..." + $apiKey.Substring([Math]::Max(0, $apiKey.Length - 2))
            Write-INFO "ApiKey   : $mask  (length: $($apiKey.Length) chars)"
            if ($apiKey.Length -lt 20) { Write-BAD "API key eka podi wage - waradi thiyenna puluwan!" }
        } else { Write-BAD "ApiKey   : EMPTY!" }
        Write-INFO "SenderId : $senderId"
    } catch {
        Write-BAD "Decrypt fail una: $($_.Exception.Message)"
    }
} else {
    Write-BAD "config.enc NEY: $configPath"
    Write-INFO "Installer eken install karahama meka hadenne. N athnam service eka Config not found kiyala witharai tikak."
}

# ------------------------------------------------------------
Write-Host "`n[3] DATABASE TEST" -ForegroundColor Yellow
if ($dbServer) {
    try {
        $dbPassword = "SPEC"
        $cs = "Server=$dbServer;Database=MMRESTAURANT;User Id=MMREST;Password=$dbPassword;Connect Timeout=15;"
        $conn = New-Object System.Data.SqlClient.SqlConnection $cs
        $conn.Open()

        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT COUNT(*) FROM Tbl_SMS WHERE Sent IS NULL OR Sent = 0"
        $pending = $cmd.ExecuteScalar()
        Write-OK "DB connect OK - pending SMS: $pending"

        if ($pending -eq 0) {
            Write-BAD "Pending SMS 0! POS eka rows insert karanne na / Sent flag eka 0 walata set karanne na!"
            Write-INFO "Tbl_SMS eke last rows balanna:"
            $cmd2 = $conn.CreateCommand()
            $cmd2.CommandText = "SELECT TOP 5 * FROM Tbl_SMS ORDER BY 1 DESC"
            try {
                $r = $cmd2.ExecuteReader()
                while ($r.Read()) { Write-INFO ("  " + $r[0].ToString().PadRight(8) + $r[1].ToString().PadRight(18) + ($r[2].ToString().Substring(0, [Math]::Min(30, $r[2].ToString().Length)))) }
                $r.Close()
            } catch { Write-INFO "  (read fail: $($_.Exception.Message))" }
        }
        $conn.Close()
    } catch {
        Write-BAD "DB connect FAIL: $($_.Exception.Message)"
    }
} else {
    Write-INFO "DB test skip - config eke DbServer na"
}

# ------------------------------------------------------------
Write-Host "`n[4] TEXT.LK API TEST" -ForegroundColor Yellow
if ($apiKey) {
    Write-Host "    Test SMS ekak yawanawada? (mobile no ekak type karanawa - eg 0771234567 / skip karanna ENTER):" -ForegroundColor White
    $testNo = Read-Host "    Mobile"
    if ($testNo) {
        $cleaned = $testNo.Trim().Replace(" ", "").Replace("-", "").Replace("+", "")
        if ($cleaned.StartsWith("0")) { $cleaned = "94" + $cleaned.Substring(1) }

        $payload = @{
            recipient = $cleaned
            sender_id = $senderId
            type      = "plain"
            message   = "Diag test - $((Get-Date).ToString('HH:mm:ss'))"
        } | ConvertTo-Json

        try {
            $resp = Invoke-RestMethod -Uri "https://app.text.lk/api/v3/sms/send" `
                -Method Post `
                -Headers @{ "Authorization" = "Bearer $apiKey"; "Accept" = "application/json" } `
                -ContentType "application/json" `
                -Body $payload

            if ($resp.status -eq "success") {
                Write-OK "API OK! SMS SEND UNA! - $($resp.message)"
                Write-INFO "Response: $($resp | ConvertTo-Json -Compress)"
                Write-OK "=> API + Sender ID + credit siyalle hari. Problem eka DB/service side eken!"
            } else {
                Write-BAD "API response: $($resp | ConvertTo-Json -Compress)"
            }
        } catch {
            $status = $null
            try { $status = $_.Exception.Response.StatusCode.value__ } catch {}
            $body = $null
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
            } catch {}
            Write-BAD "API FAIL - HTTP $status"
            Write-BAD "Body: $body"
            if ($status -eq 401) { Write-INFO "=> API TOKEN eka WARADI/EXPIRED. text.lk dashboard -> API -> API Token aranna!" }
            if ($status -eq 422) { Write-INFO "=> Validation error - sender id wrong d balanna (case-sensitive + approved wenna one)" }
        }
    } else {
        Write-INFO "API test skip una"
    }
} else {
    Write-INFO "API test skip - config eke ApiKey na"
}

# ------------------------------------------------------------
Write-Host "`n[5] LOG FILE (last 15 lines)" -ForegroundColor Yellow
$logPath = "$env:ProgramData\MMRestaurantSMS\logs\service.log"
if (Test-Path $logPath) {
    Write-INFO "Log: $logPath (last write: $((Get-Item $logPath).LastWriteTime))"
    if ((Get-Item $logPath).LastWriteTime -lt (Get-Date).AddMinutes(-10)) {
        Write-BAD "Log eka 10 minata wada update wela NEY - service eka loop ekaka NEY!"
    }
    Get-Content $logPath -Tail 15 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
} else {
    Write-BAD "Log file NEY: $logPath"
    Write-INFO "Service eka start wela log hadanne na - service eka run wenne na!"
}

# ------------------------------------------------------------
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  DIAGNOSTIC COMPLETE" -ForegroundColor Cyan
Write-Host "  Me output eka COPY karala chat ekata paste karanney!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
pause
