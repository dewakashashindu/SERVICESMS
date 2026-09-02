using SMSService.Worker;

var builder = Host.CreateApplicationBuilder(args);
builder.Services.AddWindowsService(options =>
{
    options.ServiceName = "MMRestaurantSMSService";
});
builder.Services.AddHostedService<SmsWorker>();
builder.Build().Run();