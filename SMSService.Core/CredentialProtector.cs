using System.Security.Cryptography;
using System.Text;

namespace SMSService.Core;

public static class CredentialProtector
{
    private static readonly byte[] _key = new byte[]
    {
        0x4D, 0x4D, 0x52, 0x45, 0x53, 0x54, 0x5F, 0x53,
        0x45, 0x43, 0x52, 0x45, 0x54, 0x5F, 0x4B, 0x45,
        0x59, 0x5F, 0x32, 0x30, 0x32, 0x34, 0x5F, 0x58,
        0x59, 0x5A, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46
    };

    private static readonly byte[] _iv = new byte[]
    {
        0x53, 0x4D, 0x53, 0x53, 0x56, 0x43, 0x5F, 0x49,
        0x56, 0x5F, 0x4D, 0x4D, 0x52, 0x45, 0x53, 0x54
    };

    // PasswordHelper එකෙන් ආව encrypted value මෙතන දැම්මා
    private static readonly byte[] _encryptedDbPassword = Convert.FromBase64String(
        "gc+uZd17VQkj6zeqToZubg=="
    );

    public static string GetDbPassword() => DecryptBytes(_encryptedDbPassword);

    public static string Encrypt(string plainText)
    {
        using var aes   = Aes.Create();
        aes.Key         = _key;
        aes.IV          = _iv;
        var encryptor   = aes.CreateEncryptor();
        var plainBytes  = Encoding.UTF8.GetBytes(plainText);
        var cipherBytes = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);
        return Convert.ToBase64String(cipherBytes);
    }

    public static string Decrypt(string cipherText)
    {
        var cipherBytes = Convert.FromBase64String(cipherText);
        return DecryptBytes(cipherBytes);
    }

    private static string DecryptBytes(byte[] cipherBytes)
    {
        using var aes  = Aes.Create();
        aes.Key        = _key;
        aes.IV         = _iv;
        var decryptor  = aes.CreateDecryptor();
        var plainBytes = decryptor.TransformFinalBlock(cipherBytes, 0, cipherBytes.Length);
        return Encoding.UTF8.GetString(plainBytes);
    }
}