@echo off
title Palladium Portable Server
color 0B
mode con: cols=90 lines=30 2>nul

echo.
echo  ============================================================
echo        __        __   _ _    _    ____    __  __  _   _   _
echo        \ \      / /__^| ^| ^|  ^| ^|  / ___^|  ^|  \/  ^| ^| ^| ^| ^| ^|
echo         \ \ /\ / / _ \ ^| ^|  ^| ^| ^| ^|  _   ^| ^|\  /^| ^| ^| ^| ^| ^| ^|
echo          \ V  V /  __/ ^| ^|__^| ^|___^| ^|_^| ^|  ^| ^| \/^| ^| ^|_^| ^| ^|_^|
echo           \_/\_/ \___^|_^|\____/^|_____^|  ^|_^|  ^|_^|  ^|\__,_^| \__,_^|
echo.
echo     Portable Server Manager
echo     Plug in. Power up. Host anything.
echo  ============================================================
echo.
echo  Starting Palladium...
echo.

cd /d "%~dp0palladium"

REM Try Git Bash first (most compatible)
if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" palladium
    goto done
)

REM Fallback: any bash in PATH (WSL, etc.)
where bash >nul 2>nul
if %errorlevel% equ 0 (
    bash palladium
    goto done
)

REM WSL direct
where wsl >nul 2>nul
if %errorlevel% equ 0 (
    wsl -e bash palladium
    goto done
)

REM Last resort: PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File palladium.ps1

:done
echo.
echo  Palladium has stopped. You may close this window.
pause
