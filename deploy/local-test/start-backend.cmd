@echo off
set LIVEKIT_API_KEY=APIlocalTest123
set LIVEKIT_API_SECRET=localSecret456localSecret456localSecret
set LIVEKIT_URL=ws://192.168.0.129:7880
cd /d D:\masar_app\masar_app
node server.js > server_lan_test.log 2>&1
