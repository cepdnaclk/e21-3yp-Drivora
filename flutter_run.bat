@echo off
REM Flutter runner with proper path handling for spaces in user directory
setlocal enabledelayedexpansion

REM Set proper Flutter home with quotes
set FLUTTER_ROOT=C:\Users\ASUS TUF\Flutter\flutter
set PATH="!FLUTTER_ROOT!\bin";"!FLUTTER_ROOT!\bin\cache\dart-sdk\bin";!PATH!

REM Navigate to app directory
cd /d D:\e21-3yp-Drivora\code\software\drivora

REM Run flutter with all arguments
"!FLUTTER_ROOT!\bin\flutter.bat" %*

endlocal
