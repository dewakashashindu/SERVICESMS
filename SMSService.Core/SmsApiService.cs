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
            // Eka nathnam API eka 422 validation error ekak denne.
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

            LogService.Log($"SMS API → To:{formattedNo} Status:{(int)response.StatusCode} Body:{body}");

            // FIX 2: HTTP 200 aawath body eke "status":"error" thiyanawa nam
            // eka fail ekak. Body eke status field ekath check karanawa.
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
            catch (System.Text.Json.JsonException)
            {
                // Body eka JSON wenne na nam — HTTP status eka witharai gaamu
            }

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

        // Spaces සහ dashes remove කරන්න
        var cleaned = mobileNo.Trim().Replace(" ", "").Replace("-", "").Replace("+", "");

        // 07XXXXXXXX → 947XXXXXXXX
        if (cleaned.StartsWith("0") && cleaned.Length == 10)
            return "94" + cleaned.Substring(1);

        // 947XXXXXXXX → as is
        if (cleaned.StartsWith("94") && cleaned.Length == 11)
            return cleaned;

        return cleaned;
    }

    public void Dispose() => _http.Dispose();
}
