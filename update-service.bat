@echo off
REM ============================================================
REM  MM Restaurant SMS Service - Fast Update Script
REM  FIX: Worker publish -> service stop -> exe replace -> start
REM  USAGE: Right-click -> Run as administrator
REM ============================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Please run as Administrator!
    pause
    exit /b 1
)

echo.
echo [1/5] Publishing SMSService.Worker...
dotnet publish "%~dp0SMSService.Worker" -c Release
if errorlevel 1 (
    echo [X] Publish failed!
    pause
    exit /b 1
)

set PUBLISH_EXE=%~dp0SMSService.Worker\bin\Release\net10.0-windows\win-x64\publish\SMSService.Worker.exe
set INSTALL_EXE=C:\Program Files\MMRestaurantSMS\SMSService.Worker.exe

if not exist "%PUBLISH_EXE%" (
    echo [X] Published exe not found: %PUBLISH_EXE%
    pause
    exit /b 1
)

if not exist "%INSTALL_EXE%" (
    echo [!] Service not installed yet. Run the Installer first ^(Option 3^).
    echo     Or install manually:
    echo     sc create MMRestaurantSMSService binPath= "%INSTALL_EXE%" start= auto
    pause
    exit /b 1
)

echo.
echo [2/5] Stopping service...
sc stop MMRestaurantSMSService >nul 2>&1
timeout /t 3 /nobreak >nul

echo.
echo [3/5] Replacing exe...
taskkill /f /im SMSService.Worker.exe >nul 2>&1
copy /Y "%PUBLISH_EXE%" "%INSTALL_EXE%"
if errorlevel 1 (
    echo [X] Copy failed!
    pause
    exit /b 1
)

echo.
echo [4/5] Starting service...
sc start MMRestaurantSMSService

echo.
echo [5/5] Done! Showing log (Ctrl+C to exit)...
echo     Log: C:\ProgramData\MMRestaurantSMS\logs\service.log
echo.
timeout /t 3 /nobreak >nul
powershell -NoProfile -Command "Get-Content 'C:\ProgramData\MMRestaurantSMS\logs\service.log' -Tail 20 -Wait"
pause
