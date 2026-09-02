using System.Text.Json;

namespace SMSService.Core;

public class AppConfig
{
    public string DbServer { get; set; } = "";
    public string ApiKey   { get; set; } = "";
    public string SenderId { get; set; } = "";
}

public static class ConfigManager
{
    public static string ConfigPath =>
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "MMRestaurantSMS",
            "config.enc");

    public static void SaveConfig(string dbServer, string apiKey, string senderId)
    {
        var config = new AppConfig
        {
            DbServer = CredentialProtector.Encrypt(dbServer),
            ApiKey   = CredentialProtector.Encrypt(apiKey),
            SenderId = CredentialProtector.Encrypt(senderId)
        };
        Directory.CreateDirectory(Path.GetDirectoryName(ConfigPath)!);
        File.WriteAllText(ConfigPath, JsonSerializer.Serialize(config));
    }

    public static (string DbServer, string ApiKey, string SenderId) LoadConfig()
    {
        if (!File.Exists(ConfigPath))
            throw new FileNotFoundException("Config not found.");
        var config = JsonSerializer.Deserialize<AppConfig>(File.ReadAllText(ConfigPath))!;
        return (
            CredentialProtector.Decrypt(config.DbServer),
            CredentialProtector.Decrypt(config.ApiKey),
            CredentialProtector.Decrypt(config.SenderId)
        );
    }

    public static bool ConfigExists() => File.Exists(ConfigPath);
}