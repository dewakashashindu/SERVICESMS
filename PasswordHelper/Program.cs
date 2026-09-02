using System.Security.Cryptography;
using System.Text;

byte[] key = new byte[]
{
    0x4D, 0x4D, 0x52, 0x45, 0x53, 0x54, 0x5F, 0x53,
    0x45, 0x43, 0x52, 0x45, 0x54, 0x5F, 0x4B, 0x45,
    0x59, 0x5F, 0x32, 0x30, 0x32, 0x34, 0x5F, 0x58,
    0x59, 0x5A, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46
};

byte[] iv = new byte[]
{
    0x53, 0x4D, 0x53, 0x53, 0x56, 0x43, 0x5F, 0x49,
    0x56, 0x5F, 0x4D, 0x4D, 0x52, 0x45, 0x53, 0x54
};

string password = "SPEC";

using var aes = Aes.Create();
aes.Key = key;
aes.IV  = iv;
var encryptor   = aes.CreateEncryptor();
var plainBytes  = Encoding.UTF8.GetBytes(password);
var cipherBytes = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);
var encrypted   = Convert.ToBase64String(cipherBytes);

Console.WriteLine("==================================");
Console.WriteLine("Encrypted Password:");
Console.WriteLine(encrypted);
Console.WriteLine("==================================");
Console.WriteLine("CredentialProtector.cs එකට copy කරන්න!");