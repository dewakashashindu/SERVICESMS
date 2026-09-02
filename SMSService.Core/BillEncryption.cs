using System.Security.Cryptography;
using System.Text;

namespace SMSService.Core;

/// <summary>
/// Bill number encryption (AES-128-CBC, PKCS7) — SMS e bill link එකට
/// encrypted bill number යවන්න පාවිච්චි වෙනවා.
///
/// ⚠️ Key එක + IV එක දෙපැත්තෙම (SMS service + bill viewer web app)
/// එකම තියෙන්න ඕන. Secret — කාටවත් කියන්න එපා!
/// </summary>
public static class BillEncryption
{
    // Default values — appsettings.json → "SmsBill" section එකෙන් override කරන්න පුළුවන්
    private static byte[] _key = Encoding.UTF8.GetBytes("MySecretKey12345"); // 16 characters
    private static byte[] _iv =
    {
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
    };
    public static string BaseUrl { get; private set; } =
        "https://microechefbillviewer.netlify.app/bill";

    /// <summary>
    /// Worker එක start වුනාම appsettings.json අගයන් load කරලා දානවා.
    /// </summary>
    public static void Configure(string key, string ivHex, string baseUrl)
    {
        _key    = Encoding.UTF8.GetBytes(key);
        _iv     = Convert.FromHexString(ivHex);
        BaseUrl = baseUrl.TrimEnd('/');
    }

    // Encrypt කරන method
    public static string EncryptBillNumber(string billNumber)
    {
        using var aes = Aes.Create();
        aes.Key     = _key;
        aes.IV      = _iv;
        aes.Mode    = CipherMode.CBC;
        aes.Padding = PaddingMode.PKCS7;

        using var encryptor = aes.CreateEncryptor();
        var plainBytes = Encoding.UTF8.GetBytes(billNumber);
        var encrypted  = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);

        // URL එකට දාන්න පුළුවන් විදියට Base64 URL-Safe කරනවා (no + / =)
        return Convert.ToBase64String(encrypted)
            .Replace("+", "-")
            .Replace("/", "_")
            .Replace("=", "");
    }

    // Decrypt කරන method
    public static string DecryptBillNumber(string encryptedBillNumber)
    {
        try
        {
            // URL-Safe Base64 එක normal එකට convert කරනවා
            string base64 = encryptedBillNumber
                .Replace("-", "+")
                .Replace("_", "/");

            // Padding එකත් දාගන්නවා
            switch (base64.Length % 4)
            {
                case 2: base64 += "=="; break;
                case 3: base64 += "=";  break;
            }

            var cipherText = Convert.FromBase64String(base64);

            using var aes = Aes.Create();
            aes.Key     = _key;
            aes.IV      = _iv;
            aes.Mode    = CipherMode.CBC;
            aes.Padding = PaddingMode.PKCS7;

            using var decryptor = aes.CreateDecryptor();
            var decrypted = decryptor.TransformFinalBlock(cipherText, 0, cipherText.Length);
            return Encoding.UTF8.GetString(decrypted);
        }
        catch
        {
            return null; // Decrypt වෙන්නේ නැත්නම් null return කරනවා
        }
    }

    // Full bill link: https://.../bill?id=<encrypted bill number>
    public static string BuildBillUrl(string billNumber)
        => $"{BaseUrl}?id={EncryptBillNumber(billNumber)}";
}
