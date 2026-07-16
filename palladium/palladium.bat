@echo off
rem palladium.bat - Windows Batch wrapper for Palladium
rem Runs via WSL, Git Bash, or falls back to PowerShell

set PALLADIUM_ROOT=%~dp0
set BASH_ENTRY=%PALLADIUM_ROOT%palladium

rem Helper to check if command exists
where wsl >nul 2>nul && set HAS_WSL=1
where bash >nul 2>nul && set HAS_BASH=1
where "C:\Program Files\Git\bin\bash.exe" >nul 2>nul && set HAS_GIT_BASH=1

if defined HAS_WSL (
    wsl -e bash "%BASH_ENTRY%" %*
    goto :eof
)

if defined HAS_BASH (
    bash "%BASH_ENTRY%" %*
    goto :eof
)

if defined HAS_GIT_BASH (
    "C:\Program Files\Git\bin\bash.exe" "%BASH_ENTRY%" %*
    goto :eof
)

rem Fallback to PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File "%PALLADIUM_ROOT%palladium.ps1" %*