@echo off
cd /d "D:\masar_app\masar_app"
echo Starting Ehtiraf server on port 8123...
netstat -an | findstr /R /C:":8123 .*LISTENING" >nul
if errorlevel 1 (
  start "ehtiraf-server" /min cmd /c "node server.js > server.log 2>&1"
  timeout /t 2 /nobreak >nul
) else (
  echo Server already running.
)
echo Opening app in two browser profiles (camera/audio allowed)...
start "" "msedge.exe" --user-data-dir="C:\chrome-user-B" --new-window --unsafely-treat-insecure-origin-as-secure=http://192.168.0.129:8123 http://192.168.0.129:8123
start "" "msedge.exe" --user-data-dir="C:\chrome-user-C" --new-window --unsafely-treat-insecure-origin-as-secure=http://192.168.0.129:8123 http://192.168.0.129:8123
echo Done.
