@echo off
setlocal DisableDelayedExpansion
set "GODOT_NAME=Godot_v4.7.2-stable_win64"
set "GODOT_DIR=%~dp0%GODOT_NAME%"
if not exist "%GODOT_DIR%\%GODOT_NAME%.exe" set "GODOT_DIR=%~dp0%GODOT_NAME%.exe"
if not exist "%GODOT_DIR%\%GODOT_NAME%.exe" set "GODOT_DIR=%~dp0."

if not exist "%GODOT_DIR%\%GODOT_NAME%.exe" goto missing_godot
if exist "%GODOT_DIR%\%GODOT_NAME%.exe\" goto missing_godot

"%GODOT_DIR%\%GODOT_NAME%.exe" --path "%~dp0."
exit /b %ERRORLEVEL%

:missing_godot
echo Godot 4.7.2 for Windows was not found.
echo Extract both executables into the "%GODOT_NAME%" folder next to this launcher.
echo See Windows setup from source in README.md.
pause
exit /b 1
