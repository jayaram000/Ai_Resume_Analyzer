@echo off
echo Building ResumeAI Production Release...
echo This will create an obfuscated APK to protect the source code.

call flutter clean
call flutter pub get

:: Obfuscate the code and output the debug info to a separate folder
call flutter build apk --release --obfuscate --split-debug-info=./debug_info

echo Build complete! The APK is located at build\app\outputs\flutter-apk\app-release.apk
pause
