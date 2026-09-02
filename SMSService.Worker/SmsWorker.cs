using SMSService.Core;

namespace SMSService.Worker;

public class SmsWorker : BackgroundService
{
    private readonly ILogger<SmsWorker> _logger;
    private readonly IConfiguration _config;

    public SmsWorker(ILogger<SmsWorker> logger, IConfiguration config)
    {
        _logger = logger;
        _config = config;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        LogService.Log("=== SMS Service Started ===");

        // Bill link settings (appsettings.json → "SmsBill")
        BillEncryption.Configure(
            _config["SmsBill:Key"]     ?? "MySecretKey12345",
            _config["SmsBill:Iv"]      ?? "000102030405060708090A0B0C0D0E0F",
            _config["SmsBill:BaseUrl"] ?? "https://microechefbillviewer.netlify.app/bill");

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
                var db  = new DatabaseService(dbServer);
                var sms = new SmsApiService(apiKey, senderId);

                var list = db.GetPendingSms();
                if (list.Count > 0)
                    LogService.Log($"Found {list.Count} pending SMS");

                foreach (var record in list)
                {
                    var message = record.Message;

                    // SmsType = "BLL" → bill number encrypt කරලා link එක send කරනවා
                    if (record.SmsType?.Trim().Equals("BLL", StringComparison.OrdinalIgnoreCase) == true)
                    {
                        message = BillEncryption.BuildBillUrl(record.Message.Trim());
                    }

                    var ok = await sms.SendSmsAsync(record.MobileNo, message);
                    if (ok)
                    {
                        db.DeleteSmsRecord(record.MessageId);
                        LogService.Log($"✓ Sent+Deleted ID={record.MessageId} To={record.MobileNo} Msg={message}");
                    }
                    else
                    {
                        LogService.Log($"✗ Failed ID={record.MessageId}");
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