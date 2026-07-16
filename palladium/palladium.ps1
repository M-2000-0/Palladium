<# 
.SYNOPSIS
    Palladium - Universal Portable Server Manager (Windows Launcher)
.DESCRIPTION
    Cross-platform launcher that detects the best available shell and runs Palladium.
    Works on Windows (PowerShell), WSL, Git Bash, and forwards to bash on Linux/macOS.
#>

param(
    [string[]]$Args
)

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$PalladiumRoot = Resolve-Path $PSScriptRoot
$BashEntry = Join-Path $PalladiumRoot "palladium"

function Test-Command($cmd) {
    try { Get-Command $cmd -ErrorAction Stop | Out-Null; return $true }
    catch { return $false }
}

function Find-Bash() {
    # Priority: WSL > Git Bash > MSYS2 > Cygwin > PowerShell fallback
    if (Test-Command "wsl") { return "wsl" }
    if (Test-Command "bash") { return "bash" }
    if (Test-Command "C:\Program Files\Git\bin\bash.exe") { return "C:\Program Files\Git\bin\bash.exe" }
    if (Test-Command "C:\Program Files (x86)\Git\bin\bash.exe") { return "C:\Program Files (x86)\Git\bin\bash.exe" }
    if (Test-Command "C:\msys64\usr\bin\bash.exe") { return "C:\msys64\usr\bin\bash.exe" }
    if (Test-Command "C:\cygwin64\bin\bash.exe") { return "C:\cygwin64\bin\bash.exe" }
    return $null
}

function Show-Banner() {
    Write-Host ""
    Write-Host "       ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "       ║                                                              ║" -ForegroundColor Cyan
    Write-Host "       ║   ▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄    ║" -ForegroundColor Cyan
    Write-Host "       ║  █████████ █████████ █████████ █████████ █████████ █████████  ║" -ForegroundColor Cyan
    Write-Host "       ║  ███      ███       ███       ███       ███       ███        ║" -ForegroundColor Cyan
    Write-Host "       ║  ███  ▄▄▄ ███  ▄▄▄▄ ███  ▄▄▄▄ ███  ▄▄▄ ███  ▄▄▄▄ ███  ▄▄▄▄  ║" -ForegroundColor Cyan
    Write-Host "       ║  ███ █████ ███ █████ ███ █████ ███ █████ ███ █████ ███ █████ ║" -ForegroundColor Cyan
    Write-Host "       ║  ███  ▀▀▀▀ ███  ▀▀▀▀ ███  ▀▀▀▀ ███  ▀▀▀▀ ███  ▀▀▀▀ ███  ▀▀▀▀ ║" -ForegroundColor Cyan
    Write-Host "       ║  █████████ █████████ █████████ █████████ █████████ █████████ ║" -ForegroundColor Cyan
    Write-Host "       ║       ███       ███       ███       ███       ███       ███  ║" -ForegroundColor Cyan
    Write-Host "       ║  ▄▄▄▄▄███ ▄▄▄▄▄▄▄███ ▄▄▄▄▄▄▄███ ▄▄▄▄▄▄▄███ ▄▄▄▄▄▄▄███ ▄▄▄▄▄███ ║" -ForegroundColor Cyan
    Write-Host "       ║  ▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀ ║" -ForegroundColor Cyan
    Write-Host "       ║                                                              ║" -ForegroundColor Cyan
    Write-Host "       ║     ██████╗ ██████╗ ███████╗ ██████╗ ██████╗ ███████╗        ║" -ForegroundColor Cyan
    Write-Host "       ║     ██╔══██╗██╔══██╗██╔════╝██╔═══██╗██╔══██╗██╔════╝        ║" -ForegroundColor Cyan
    Write-Host "       ║     ██████╔╝██████╔╝█████╗  ██║   ██║██████╔╝█████╗          ║" -ForegroundColor Cyan
    Write-Host "       ║     ██╔═══╝ ██╔══██╗██╔══╝  ██║   ██║██╔══██╗██╔══╝          ║" -ForegroundColor Cyan
    Write-Host "       ║     ██║     ██║  ██║███████╗╚██████╔╝██║  ██║███████╗        ║" -ForegroundColor Cyan
    Write-Host "       ║     ╚═╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝        ║" -ForegroundColor Cyan
    Write-Host "       ║                                                              ║" -ForegroundColor Cyan
    Write-Host "       ╚═════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Portable Server Manager" -ForegroundColor Cyan -NoNewline
    Write-Host "  Plug in. Power up. Host anything." -ForegroundColor DarkGray
    Write-Host ""
}

function Show-Help() {
    Show-Banner
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  palladium.ps1              Launch interactive menu"
    Write-Host "  palladium.ps1 install      Install a service"
    Write-Host "  palladium.ps1 start <svc>  Start a service"
    Write-Host "  palladium.ps1 stop <svc>   Stop a service"
    Write-Host "  palladium.ps1 status       Show all services"
    Write-Host "  palladium.ps1 logs <svc>   View service logs"
    Write-Host "  palladium.ps1 remove <svc> Remove a service"
    Write-Host "  palladium.ps1 list         List installed services"
    Write-Host "  palladium.ps1 help         Show this help"
    Write-Host ""
    Write-Host "Windows Requirements:" -ForegroundColor Yellow
    Write-Host "  • WSL 2 (recommended): wsl --install"
    Write-Host "  • Or Git Bash: https://git-scm.com/download/win"
    Write-Host "  • Or MSYS2: https://www.msys2.org/"
    Write-Host "  • Docker Desktop: https://docker.com/products/docker-desktop"
    Write-Host ""
}

# Main
$bash = Find-Bash

if (-not $bash) {
    Write-Host "❌ No bash environment found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install one of:" -ForegroundColor Yellow
    Write-Host "  • WSL 2 (recommended):  wsl --install" -ForegroundColor Cyan
    Write-Host "  • Git Bash:             https://git-scm.com/download/win" -ForegroundColor Cyan
    Write-Host "  • MSYS2:                https://www.msys2.org/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Then restart this terminal and try again."
    exit 1
}

# Convert Windows path to Unix path for WSL
if ($bash -eq "wsl") {
    $UnixPath = $PalladiumRoot.Path -replace '^([A-Z]):', '/mnt/$1' -replace '\\', '/'
    $BashEntryUnix = $UnixPath + "/palladium"
    $argsUnix = $Args | ForEach-Object { $_ -replace '\\', '/' }
    & wsl -e bash "$BashEntryUnix" $argsUnix
}
elseif ($bash -like "*bash.exe") {
    $UnixPath = $PalladiumRoot.Path -replace '^([A-Z]):', '/mnt/$1' -replace '\\', '/'
    $BashEntryUnix = $UnixPath + "/palladium"
    $argsUnix = $Args | ForEach-Object { $_ -replace '\\', '/' }
    & $bash "$BashEntryUnix" $argsUnix
}
else {
    # Native bash (Linux/macOS/WSL internal)
    & $bash "$BashEntry" $Args
}

exit $LASTEXITCODE