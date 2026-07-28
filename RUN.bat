@echo off
if "%~1"=="min" goto main
start /min "" "%~f0" min
exit /b

:main
chcp 65001 >nul
setlocal

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: Windows PowerShell was not found.
    echo Windows PowerShell 5.1 is included with Windows 10 and 11.
    pause
    exit /b 1
)

if not exist "%~dp0GUI_Compress.ps1" (
    echo ERROR: GUI_Compress.ps1 was not found next to RUN.bat.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0GUI_Compress.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo Application exited with error code: %EXIT_CODE%
    pause
)

exit /b %EXIT_CODE%