@echo off
title Server - Self-Hosted Control Panel
color 0F
mode con: cols=100 lines=35 2>nul

echo.
echo  ============================================================
echo     ███████  ███████  ██████  ██    ██  ███████  ██████
echo     ██       ██       ██   ██ ██    ██ ██       ██   ██
echo     ███████  █████    ██████  ██    ██ █████    ██████
echo          ██  ██       ██   ██  ██  ██  ██       ██   ██
echo     ███████  ███████  ██   ██   ████   ███████  ██   ██
echo.
echo     Self-host. Your way.
echo  ============================================================
echo.
echo  Starting Server...

cd /d "%~dp0Server"

REM Find Python
set PYTHON_CMD=
where python >nul 2>nul
if %errorlevel% equ 0 set PYTHON_CMD=python
if "%PYTHON_CMD%"=="" (
    where py >nul 2>nul
    if %errorlevel% equ 0 set PYTHON_CMD=py
)

if not "%PYTHON_CMD%"=="" (
    "%PYTHON_CMD%" server.py
    goto done
)

REM No Python — try Java
where java >nul 2>nul
if %errorlevel% equ 0 (
    if not exist Server\Server.class javac Server\Server.java 2>nul
    if exist Server\Server.class (
        java -cp Server Server
        goto done
    )
)

REM No Python or Java — try Git Bash as fallback
cd /d "%~dp0palladium"
if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" palladium
    goto done
)
if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    "C:\Program Files (x86)\Git\bin\bash.exe" palladium
    goto done
)
where bash >nul 2>nul
if %errorlevel% equ 0 (
    bash palladium
    goto done
)
where wsl >nul 2>nul
if %errorlevel% equ 0 (
    wsl -e bash palladium
    goto done
)
powershell -NoProfile -ExecutionPolicy Bypass -File ..\palladium\palladium.ps1

:done
echo.
echo  Server has stopped. You may close this window.
pause
