@echo off
title Server
cd /d "%~dp0"

:: ── Create desktop shortcut on first run ──
if not exist "%APPDATA%\Server\installed.txt" (
    mkdir "%APPDATA%\Server" 2>nul
    echo installed > "%APPDATA%\Server\installed.txt"
    powershell -NoProfile -Command ^
        "$WS = New-Object -ComObject WScript.Shell;" ^
        "$SC = $WS.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\My Server.lnk');" ^
        "$SC.TargetPath = '%~f0';" ^
        "$SC.WorkingDirectory = '%~dp0';" ^
        "$SC.Description = 'My personal server';" ^
        "$SC.WindowStyle = 1;" ^
        "$SC.IconLocation = '%%SystemRoot%%\system32\imageres.dll, 25';" ^
        "$SC.Save();"
)

:: ── Make sure Python + deps are ready ──
where python >nul 2>nul
if %errorlevel% neq 0 (
    where winget >nul 2>nul
    if %errorlevel% equ 0 winget install --exact --id Python.Python.3.12 --silent --accept-package-agreements >nul 2>nul
)
python -c "import rich" 2>nul
if %errorlevel% neq 0 python -m pip install --quiet rich psutil >nul 2>nul

:: ── Launch the terminal app ──
cd /d "%~dp0Server"
python server.py

:: ── After quitting ──
echo.
echo  Server closed. You can close this window.
pause >nul
