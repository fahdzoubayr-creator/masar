@echo off
cd /d D:\masar_app\masar_app
call "D:\flutter\bin\flutter.bat" build apk --release --split-per-abi > "D:\masar_app\masar_app\build_apk.log" 2>&1
