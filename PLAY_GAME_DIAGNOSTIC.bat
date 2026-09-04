@echo off
setlocal
set "LOG_DIR=%APPDATA%\Godot\app_userdata\Shit-Tacular\logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

"%~dp0Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0." --log-file "%LOG_DIR%\startup-diagnostic.log"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo Shit-Tacular exited with code %EXIT_CODE%.
    echo Diagnostic log: %LOG_DIR%\startup-diagnostic.log
    echo Please send that file to the developer.
    pause
)

endlocal & exit /b %EXIT_CODE%
