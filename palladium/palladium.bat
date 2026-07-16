@echo off
rem palladium.bat - Windows Batch wrapper for Palladium
rem Tries Git Bash, WSL, or falls back to PowerShell

set PALLADIUM_ROOT=%~dp0
set BASH_ENTRY=%PALLADIUM_ROOT%palladium

rem Try Git Bash first (most compatible)
if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" "%BASH_ENTRY%" %*
    goto :eof
)

rem Try WSL
where wsl >nul 2>nul
if %errorlevel% equ 0 (
    wsl -e bash "%BASH_ENTRY%" %*
    goto :eof
)

rem Try any bash in PATH
where bash >nul 2>nul
if %errorlevel% equ 0 (
    bash "%BASH_ENTRY%" %*
    goto :eof
)

rem Fallback to PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File "%PALLADIUM_ROOT%palladium.ps1" %*
