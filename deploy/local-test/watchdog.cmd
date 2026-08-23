@echo off
rem حارس خوادم مسار — يشغّل ما لا يعمل فقط، دون قتل أي شيء
set LIVEKIT_API_KEY=APIlocalTest123
set LIVEKIT_API_SECRET=localSecret456localSecret456localSecret
set LIVEKIT_URL=ws://192.168.0.129:7880

netstat -ano | findstr ":8123" | findstr "LISTENING" >nul
if errorlevel 1 (
  cd /d D:\masar_app\masar_app
  start "" /b cmd /c "node server.js >> server_watch.log 2>&1"
  echo %date% %time% started backend >> D:\masar_app\masar_app\deploy\local-test\watchdog.log
)

netstat -ano | findstr ":7880" | findstr "LISTENING" >nul
if errorlevel 1 (
  start "" /b cmd /c ""D:\masar_app\masar_app\deploy\local-test\livekit-server.exe" --config "D:\masar_app\masar_app\deploy\local-test\livekit-local.yaml" >> D:\masar_app\masar_app\deploy\local-test\watchdog.log 2>&1"
  echo %date% %time% started livekit >> D:\masar_app\masar_app\deploy\local-test\watchdog.log
)
