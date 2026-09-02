# ============================================================
#  MM RESTAURANT SMS - ONE-SHOT INSTALLER + PATCHER
#
#  Meka karanne:
#   [1] Repo source eka PATCH karanna (SMS fixes 3 - type field, SQL2008, NULL Sent)
#   [2] Config file eka hadanna (encrypted)
#   [3] Worker publish + service install + start
#   [4] Test SMS ekak yanna (full pipeline test)
#
#  RUN (Admin PowerShell):
#    powershell -ExecutionPolicy Bypass -File install-service.ps1
# ============================================================

$ErrorActionPreference = "Continue"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$SvcName   = "MMRestaurantSMSService"
$InstallDir = "C:\Program Files\MMRestaurantSMS"
$ConfigDir = "$env:ProgramData\MMRestaurantSMS"

function Write-OK($msg)   { Write-Host "  [OK]  $msg" -ForegroundColor Green }
function Write-BAD($msg)  { Write-Host "  [XX]  $msg" -ForegroundColor Red }
function Write-INFO($msg) { Write-Host "  [i]   $msg" -ForegroundColor Gray }
function Pause-Step() { Read-Host "  ENTER karanna continue karanna" | Out-Null }

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  MM RESTAURANT SMS - INSTALLER" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Admin check (.NET method - PowerShell redirect issue na) ---
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-BAD "Me PowerShell window eka ADMIN wela NE!"
    Write-INFO "1. Start button eka RIGHT-CLICK karanaya"
    Write-INFO "2. 'Terminal (Admin)' nathnam 'Windows PowerShell (Admin)' select karanaya"
    Write-INFO "3. Dan me commands tika run karanaya:"
    Write-INFO "     cd $env:USERPROFILE\Downloads"
    Write-INFO "     powershell -ExecutionPolicy Bypass -File install-service.ps1"
    Pause-Step; exit 1
}

# ------------------------------------------------------------
Write-Host "`n[1/6] REPO FOLDER EKA" -ForegroundColor Yellow
$repo = $null
foreach ($guess in @(".", ".\SERVICESMS", "$env:USERPROFILE\Downloads\SERVICESMS", "$env:USERPROFILE\Source\Repos\SERVICESMS", "$env:USERPROFILE\Desktop\SERVICESMS")) {
    if (Test-Path "$guess\SMSService.Core\SmsApiService.cs") { $repo = (Resolve-Path $guess).Path; break }
}
if ($repo) { Write-INFO "Repo hambuna: $repo" }
else {
    $repo = Read-Host "  SERVICESMS repo folder path eka type karanaya (eg C:\Users\dewak\Downloads\SERVICESMS)"
    if (-not (Test-Path "$repo\SMSService.Core\SmsApiService.cs")) {
        Write-BAD "Meka SERVICESMS repo ekak neme! (SMSService.Core folder eka na)"
        Pause-Step; exit 1
    }
}

# ------------------------------------------------------------
Write-Host "`n[2/6] SOURCE PATCH (SMS fixes)" -ForegroundColor Yellow

$smsApiSrc = @'
namespace SMSService.Core;

public class SmsApiService : IDisposable
{
    private readonly string _apiKey;
    private readonly string _senderId;
    private readonly HttpClient _http = new();

    public SmsApiService(string apiKey, string senderId)
    {
        _apiKey   = apiKey;
        _senderId = senderId;
    }

    public async Task<bool> SendSmsAsync(string mobileNo, string message)
    {
        try
        {
            var formattedNo = FormatNumber(mobileNo);

            // Text.lk API
            var url = "https://app.text.lk/api/v3/sms/send";

            // FIX 1: text.lk API ekata "type": "plain" REQUIRED field ekak.
            var payload = new
            {
                recipient = formattedNo,
                sender_id = _senderId,
                type      = "plain",
                message   = message
            };

            var json    = System.Text.Json.JsonSerializer.Serialize(payload);
            var content = new StringContent(json,
                System.Text.Encoding.UTF8, "application/json");

            using var request = new HttpRequestMessage(HttpMethod.Post, url);
            request.Headers.Add("Authorization", $"Bearer {_apiKey}");
            request.Headers.Add("Accept", "application/json");
            request.Content = content;

            var response = await _http.SendAsync(request);
            var body     = await response.Content.ReadAsStringAsync();

            LogService.Log($"SMS API -> To:{formattedNo} Status:{(int)response.StatusCode} Body:{body}");

            if (!response.IsSuccessStatusCode)
                return false;

            try
            {
                using var doc = System.Text.Json.JsonDocument.Parse(body);
                if (doc.RootElement.TryGetProperty("status", out var status) &&
                    status.GetString() == "error")
                {
                    LogService.Log($"SMS API returned status:error for {formattedNo}");
                    return false;
                }
            }
            catch (System.Text.Json.JsonException) { }

            return true;
        }
        catch (Exception ex)
        {
            LogService.Log($"SMS Error: {ex.Message}");
            return false;
        }
    }

    private static string FormatNumber(string mobileNo)
    {
        if (string.IsNullOrWhiteSpace(mobileNo))
            return "";

        var cleaned = mobileNo.Trim().Replace(" ", "").Replace("-", "").Replace("+", "");

        // 07XXXXXXXX -> 947XXXXXXXX
        if (cleaned.StartsWith("0") && cleaned.Length == 10)
            return "94" + cleaned.Substring(1);

        // 947XXXXXXXX -> as is
        if (cleaned.StartsWith("94") && cleaned.Length == 11)
            return cleaned;

        return cleaned;
    }

    public void Dispose() => _http.Dispose();
}
'@

$dbSrc = @'
using Microsoft.Data.SqlClient;

namespace SMSService.Core;

public class DatabaseService
{
    private readonly string _connectionString;

    public DatabaseService(string dbServer)
    {
        var dbPassword = CredentialProtector.GetDbPassword();
        // FIX 2: SQL Server 2008 ekata Encrypt default true nisa fail wenna.
        _connectionString =
            $"Server={dbServer};" +
            $"Database=MMRESTAURANT;" +
            $"User Id=MMREST;" +
            $"Password={dbPassword};" +
            $"Encrypt=False;" +
            $"TrustServerCertificate=True;" +
            $"Connect Timeout=15;";
    }

    public List<SmsRecord> GetPendingSms()
    {
        var records = new List<SmsRecord>();
        using var conn = new SqlConnection(_connectionString);
        conn.Open();
        // FIX 3: Sent = NULL unath record eka ganna
        using var cmd = new SqlCommand(
            "SELECT MessageId, MobileNo, Message FROM Tbl_SMS " +
            "WHERE Sent IS NULL OR Sent = 0", conn);
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            records.Add(new SmsRecord
            {
                MessageId = reader.GetInt32(0),
                MobileNo  = reader.IsDBNull(1) ? "" : reader.GetString(1),
                Message   = reader.IsDBNull(2) ? "" : reader.GetString(2)
            });
        }
        return records;
    }

    public void DeleteSmsRecord(int messageId)
    {
        using var conn = new SqlConnection(_connectionString);
        conn.Open();
        using var cmd = new SqlCommand(
            "DELETE FROM Tbl_SMS WHERE MessageId = @id", conn);
        cmd.Parameters.AddWithValue("@id", messageId);
        cmd.ExecuteNonQuery();
    }

    public bool TestConnection()
    {
        try
        {
            using var conn = new SqlConnection(_connectionString);
            conn.Open();
            return true;
        }
        catch (Exception ex)
        {
            LogService.Log($"DB Connection Error: {ex.Message}");
            return false;
        }
    }
}
'@

$workerSrc = @'
using SMSService.Core;

namespace SMSService.Worker;

public class SmsWorker : BackgroundService
{
    private readonly ILogger<SmsWorker> _logger;

    public SmsWorker(ILogger<SmsWorker> logger)
    {
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        LogService.Log("=== SMS Service Started ===");

        int loopCount = 0;

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (!ConfigManager.ConfigExists())
                {
                    LogService.Log("Config not found. Waiting 30s...");
                    await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
                    continue;
                }

                var (dbServer, apiKey, senderId) = ConfigManager.LoadConfig();

                using var sms = new SmsApiService(apiKey, senderId);
                var db = new DatabaseService(dbServer);

                var list = db.GetPendingSms();
                if (list.Count > 0)
                    LogService.Log($"Found {list.Count} pending SMS");
                else if (++loopCount % 10 == 0)
                    LogService.Log("Still running, no pending SMS");

                foreach (var record in list)
                {
                    if (string.IsNullOrWhiteSpace(record.MobileNo))
                    {
                        LogService.Log($"Skipped ID={record.MessageId} - MobileNo empty");
                        continue;
                    }

                    var ok = await sms.SendSmsAsync(record.MobileNo, record.Message);
                    if (ok)
                    {
                        db.DeleteSmsRecord(record.MessageId);
                        LogService.Log($"OK Sent+Deleted ID={record.MessageId} To={record.MobileNo}");
                    }
                    else
                    {
                        LogService.Log($"FAIL ID={record.MessageId}");
                    }
                }
            }
            catch (Exception ex)
            {
                LogService.Log($"ERROR: {ex.Message}");
            }

            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
        }

        LogService.Log("=== SMS Service Stopped ===");
    }
}
'@

try {
    Set-Content -Path "$repo\SMSService.Core\SmsApiService.cs" -Value $smsApiSrc -Encoding UTF8
    Set-Content -Path "$repo\SMSService.Core\DatabaseService.cs" -Value $dbSrc -Encoding UTF8
    Set-Content -Path "$repo\SMSService.Worker\SmsWorker.cs" -Value $workerSrc -Encoding UTF8
    Write-OK "Fixes 3 apply una (type field + SQL2008 + NULL Sent)"
} catch {
    Write-BAD "Patch fail: $($_.Exception.Message)"
}

# --- FIX 4: TdsParser single-file SNI issue eka (EXACT error eka log eke thiyanawa!) ---
$csprojPath = "$repo\SMSService.Worker\SMSService.Worker.csproj"
try {
    $raw = Get-Content $csprojPath -Raw
    if ($raw -notmatch 'IncludeNativeLibrariesForSelfExtract') {
        $raw = $raw -replace '<PublishSingleFile>true</PublishSingleFile>',
            "<PublishSingleFile>true</PublishSingleFile>`r`n    <IncludeNativeLibrariesForSelfExtract>true</IncludeNativeLibrariesForSelfExtract>"
        Set-Content -Path $csprojPath -Value $raw -Encoding UTF8
        Write-OK "csproj patch una - IncludeNativeLibrariesForSelfExtract (TdsParser fix)"
    } else {
        Write-INFO "csproj eke TdsParser fix athi"
    }
} catch {
    Write-BAD "csproj patch fail: $($_.Exception.Message)"
}

# ------------------------------------------------------------
Write-Host "`n[3/6] SETTINGS" -ForegroundColor Yellow

$dbServer = Read-Host "  Database Server [ENTER = DEWAKA\SQL2008]"
if ([string]::IsNullOrWhiteSpace($dbServer)) { $dbServer = "DEWAKA\SQL2008" }

$apiKey = Read-Host "  text.lk API Token (dashboard -> API -> API Token)"
while ([string]::IsNullOrWhiteSpace($apiKey)) { $apiKey = Read-Host "  API Token eka ONE! " }

$senderId = Read-Host "  Sender ID (text.lk eke approved eka - case sensitive)"
while ([string]::IsNullOrWhiteSpace($senderId)) { $senderId = Read-Host "  Sender ID eka ONE! " }

# --- Config file eka hadanna (encrypted) ---
$key = [byte[]](0x4D,0x4D,0x52,0x45,0x53,0x54,0x5F,0x53,0x45,0x43,0x52,0x45,0x54,0x5F,0x4B,0x45,0x59,0x5F,0x32,0x30,0x32,0x34,0x5F,0x58,0x59,0x5A,0x41,0x42,0x43,0x44,0x45,0x46)
$iv  = [byte[]](0x53,0x4D,0x53,0x53,0x56,0x43,0x5F,0x49,0x56,0x5F,0x4D,0x4D,0x52,0x45,0x53,0x54)

function Encrypt-Value([string]$plain) {
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key; $aes.IV = $iv; $aes.Mode = "CBC"; $aes.Padding = "PKCS7"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($plain)
    $enc = $aes.CreateEncryptor().TransformFinalBlock($bytes, 0, $bytes.Length)
    [Convert]::ToBase64String($enc)
}

$configJson = @{
    DbServer = Encrypt-Value $dbServer
    ApiKey   = Encrypt-Value $apiKey
    SenderId = Encrypt-Value $senderId
} | ConvertTo-Json

New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
Set-Content -Path "$ConfigDir\config.enc" -Value $configJson -Encoding UTF8
Write-OK "Config save una: $ConfigDir\config.enc"

# ------------------------------------------------------------
Write-Host "`n[4/6] DB CONNECTION TEST" -ForegroundColor Yellow
try {
    $cs = "Server=$dbServer;Database=MMRESTAURANT;User Id=MMREST;Password=SPEC;Connect Timeout=15;"
    $conn = New-Object System.Data.SqlClient.SqlConnection $cs
    $conn.Open()
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT COUNT(*) FROM Tbl_SMS WHERE Sent IS NULL OR Sent = 0"
    $pending = $cmd.ExecuteScalar()
    $conn.Close()
    Write-OK "DB OK! Pending SMS: $pending"
} catch {
    Write-BAD "DB FAIL: $($_.Exception.Message)"
    $cont = Read-Host "  Continue karanna? (y/n)"
    if ($cont -ne "y") { Pause-Step; exit 1 }
}

# ------------------------------------------------------------
Write-Host "`n[5/6] WORKER PUBLISH + SERVICE INSTALL" -ForegroundColor Yellow

$workerExe = $null
$dotnetOk = $false
try { $v = dotnet --version 2>$null; if ($v -match "^1[0-9]\.") { $dotnetOk = $true } } catch {}

if ($dotnetOk) {
    Write-INFO "dotnet SDK ($v) hambuna - aluth code publish karanawa..."
    dotnet publish "$repo\SMSService.Worker" -c Release --nologo -v q
    $pub = "$repo\SMSService.Worker\bin\Release\net10.0-windows\win-x64\publish\SMSService.Worker.exe"
    if (Test-Path $pub) { $workerExe = $pub; Write-OK "Publish OK!" }
}

if (-not $workerExe) {
    $fallback = "$repo\SMSService.Installer\worker\SMSService.Worker.exe"
    if (Test-Path $fallback) {
        Write-BAD "Publish fail/na - PAR exe eka use karanawa (type fix EKA ATHI NEME!)"
        $workerExe = $fallback
    } else {
        Write-BAD "Worker exe ekak hambune na! dotnet SDK install karanna (aka.ms/dotnet)."
        Pause-Step; exit 1
    }
}

# Service stop + copy + install
$existing = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
if ($existing) {
    Write-INFO "Service athi - restart karanawa..."
    Stop-Service -Name $SvcName -Force -ErrorAction SilentlyContinue
    # EXE lock wennaatha nisa process eka fully exit wenna balanawa
    $tries = 0
    while ((Get-Process -Name "SMSService.Worker" -ErrorAction SilentlyContinue) -and $tries -lt 10) {
        Start-Sleep 1; $tries++
    }
    if (Get-Process -Name "SMSService.Worker" -ErrorAction SilentlyContinue) {
        taskkill /f /im SMSService.Worker.exe 2>$null | Out-Null
        Start-Sleep 2
    }
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item $workerExe "$InstallDir\SMSService.Worker.exe" -Force
Write-OK "Worker exe copy una: $InstallDir\SMSService.Worker.exe"

if (-not $existing) {
    New-Service -Name $SvcName -BinaryPathName "$InstallDir\SMSService.Worker.exe" `
        -StartupType Automatic -DisplayName "MM Restaurant SMS Service" | Out-Null
    Write-OK "Service create una!"
}

Start-Service -Name $SvcName
Start-Sleep 8

$svcNow = Get-Service -Name $SvcName
if ($svcNow.Status -eq "Running") { Write-OK "Service RUNNING!" }
else { Write-BAD "Service start wenne na! Status: $($svcNow.Status)" }

# ------------------------------------------------------------
Write-Host "`n[6/6] TEST SMS (full pipeline)" -ForegroundColor Yellow
$testNo = Read-Host "  Test SMS ekak yawanawada? Mobile no ekak type karanaya (skip = ENTER)"
if ($testNo) {
    try {
        $conn = New-Object System.Data.SqlClient.SqlConnection $cs
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO Tbl_SMS (MobileNo, Message, Sent) VALUES ('$($testNo.Trim())', 'MM Restaurant test SMS', 0)"
        $cmd.ExecuteNonQuery()
        $conn.Close()
        Write-OK "Test row insert una! 35 sec balanawa service eka eka arala yanna..."
        Start-Sleep 35

        $log = "$ConfigDir\logs\service.log"
        if (Test-Path $log) {
            Write-INFO "LOG (last 10):"
            Get-Content $log -Tail 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        } else { Write-BAD "Log file ekakuth na - service eka crash una wage!" }
    } catch {
        Write-BAD "Test row insert FAIL: $($_.Exception.Message)"
    }
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  INSTALL COMPLETE!" -ForegroundColor Cyan
Write-Host "  Log: $ConfigDir\logs\service.log" -ForegroundColor Cyan
Write-Host "  Output eka COPY karala chat ekata paste karanney!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Pause-Step
