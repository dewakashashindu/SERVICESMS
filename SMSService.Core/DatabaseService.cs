using Microsoft.Data.SqlClient;

namespace SMSService.Core;

public class DatabaseService
{
    private readonly string _connectionString;

    public DatabaseService(string dbServer)
    {
        var dbPassword = CredentialProtector.GetDbPassword();
        _connectionString =
            $"Server={dbServer};" +
            $"Database=MMRESTAURANT;" +
            $"User Id=MMREST;" +
            $"Password={dbPassword};" +
            $"TrustServerCertificate=True;";
    }

    public List<SmsRecord> GetPendingSms()
    {
        var records = new List<SmsRecord>();
        using var conn = new SqlConnection(_connectionString);
        conn.Open();
        using var cmd = new SqlCommand(
            "SELECT MessageId, MobileNo, Message, SmsType FROM Tbl_SMS WHERE Sent = 0", conn);
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            records.Add(new SmsRecord
            {
                MessageId = reader.GetInt32(0),
                MobileNo  = reader.GetString(1),
                Message   = reader.GetString(2),
                SmsType   = reader.IsDBNull(3) ? "" : reader.GetString(3)
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
        catch { return false; }
    }
}