@echo off
setlocal DisableDelayedExpansion
set "LOG_DIR=%APPDATA%\Godot\app_userdata\Shit-Tacular\logs"
set "LOG_FILE=%LOG_DIR%\startup-diagnostic.log"
if not exist "%LOG_DIR%\" mkdir "%LOG_DIR%" 2>nul

rem Write the log before launching Godot so missing executables are recorded too.
(type nul > "%LOG_FILE%") 2>nul
if errorlevel 1 goto log_unavailable
echo Writing startup diagnostics to "%LOG_FILE%".
call :launch >> "%LOG_FILE%" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo Shit-Tacular exited with code %EXIT_CODE%.
    echo Please send "%LOG_FILE%" to the developer.
    pause
)
exit /b %EXIT_CODE%

:log_unavailable
echo Could not write "%LOG_FILE%". Startup diagnostics will appear here.
call :launch
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" pause
exit /b %EXIT_CODE%

:launch
echo Starting Shit-Tacular from "%~dp0."
set "GODOT_NAME=Godot_v4.7.2-stable_win64"
set "GODOT_DIR=%~dp0%GODOT_NAME%"
if not exist "%GODOT_DIR%\%GODOT_NAME%.exe" set "GODOT_DIR=%~dp0%GODOT_NAME%.exe"
if not exist "%GODOT_DIR%\%GODOT_NAME%.exe" set "GODOT_DIR=%~dp0."

if not exist "%GODOT_DIR%\%GODOT_NAME%.exe" goto missing_godot
if exist "%GODOT_DIR%\%GODOT_NAME%.exe\" goto missing_godot
if not exist "%GODOT_DIR%\%GODOT_NAME%_console.exe" goto missing_godot
if exist "%GODOT_DIR%\%GODOT_NAME%_console.exe\" goto missing_godot

"%GODOT_DIR%\%GODOT_NAME%_console.exe" --path "%~dp0."
exit /b %ERRORLEVEL%

:missing_godot
echo Godot 4.7.2 for Windows or its console executable was not found.
echo Extract both executables into the "%GODOT_NAME%" folder next to this launcher.
echo See Windows setup from source in README.md.
exit /b 1
