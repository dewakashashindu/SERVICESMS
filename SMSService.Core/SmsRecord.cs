namespace SMSService.Core;

public class SmsRecord
{
    public int    MessageId { get; set; }
    public string MobileNo  { get; set; } = "";
    public string Message   { get; set; } = "";
    public string SmsType   { get; set; } = ""; // "TXT" = normal text, "BLL" = bill link
}
