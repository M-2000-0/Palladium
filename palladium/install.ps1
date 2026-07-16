<# 
.SYNOPSIS
    Palladium One-Line Installer for Windows
.DESCRIPTION
    Installs Palladium on Windows (WSL, Git Bash, or native PowerShell + Docker Desktop).
    Usage: irm https://raw.githubusercontent.com/M-2000-0/Palladium/main/install.ps1 | iex
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "$env:USERPROFILE\.palladium",
    [string]$RepoUrl    = "https://github.com/M-2000-0/Palladium",
    [string]$Branch     = "main",
    [switch]$NoDocker,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Colors
$C = @{
    Red    = [ConsoleColor]::Red
    Green  = [ConsoleColor]::Green
    Yellow = [ConsoleColor]::Yellow
    Cyan   = [ConsoleColor]::Cyan
    Gray   = [ConsoleColor]::DarkGray
}

function WC($msg, $color) { Write-Host $msg -ForegroundColor $color }
function OK($msg)   { WC "  [OK] $msg" $C.Green }
function WRN($msg)  { WC "  [!] $msg" $C.Yellow }
function ERR($msg)  { WC "  [ERR] $msg" $C.Red }
function STEP($msg) { WC "`n$msg" $C.Cyan }

function TryCmd($sb, $err) { try { & $sb; $true } catch { WRN $err; $false } }

# Banner
$banner = @"
██████╗  █████╗ ██╗     ██╗      █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗
██╔══██╗██╔══██╗██║     ██║     ██╔══██╗██╔══██╗██║██║   ██║████╗ ████║
██████╔╝███████║██║     ██║     ███████║██║  ██║██║██║   ██║██╔████╔██║
██╔═══╝ ██╔══██║██║     ██║     ██╔══██║██║  ██║██║██║   ██║██║╚██╔╝██║
██║     ██║  ██║███████╗███████╗██║  ██║██████╔╝██║╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚═╝ ╚═════╝ ╚═╝     ╚═╝
"@
WC $banner $C.Cyan
Write-Host ""

# 1. Prerequisites
STEP "[1/5] Checking prerequisites..."

# Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    WRN "Git not found. Installing via winget..."
    TryCmd { winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements } "Install Git manually: https://git-scm.com/download/win"
}
else { OK "Git: $(git --version)" }

# Docker
if ($NoDocker) { WRN "Skipping Docker (--NoDocker)" }
elseif (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    WRN "Docker not found."
    $ans = Read-Host "Install Docker Desktop? (Y/n)"
    if ($Force -or $ans -notmatch '^[Nn]$') {
        WC "Opening Docker Desktop download..." $C.Cyan
        Start-Process "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        WRN "Install Docker Desktop, enable WSL 2 integration, then re-run this installer."
        exit 1
    }
    else { ERR "Docker is required."; exit 1 }
}
else {
    OK "Docker: $(docker --version)"
    if (-not (docker info 2>$null)) {
        WRN "Docker daemon not running. Starting..."
        Start-Process "Docker Desktop" -WindowStyle Hidden
        $t = 0
        while (-not (docker info 2>$null) -and $t -lt 30) { Start-Sleep 2; $t++ }
        if (-not (docker info 2>$null)) { ERR "Docker failed to start. Open Docker Desktop manually."; exit 1 }
        OK "Docker daemon started"
    }
    else { OK "Docker daemon running" }
}

# 2. Clone / Update
STEP "[2/5] Fetching Palladium..."
if (Test-Path "$InstallDir\.git") {
    WC "Updating existing installation..." $C.Cyan
    Push-Location $InstallDir
    git fetch --quiet
    git reset --hard "origin/$Branch" --quiet
    Pop-Location
    OK "Updated to latest $Branch"
}
else {
    WC "Cloning repository..." $C.Cyan
    git clone --quiet --branch $Branch $RepoUrl $InstallDir
    OK "Cloned to $InstallDir"
}

# 3. Permissions
STEP "[3/5] Setting permissions..."
$scripts = @(
    Get-ChildItem "$InstallDir\modules\*.sh" -ErrorAction SilentlyContinue
    Get-ChildItem "$InstallDir\palladium" -ErrorAction SilentlyContinue
    Get-ChildItem "$InstallDir\palladium.ps1" -ErrorAction SilentlyContinue
    Get-ChildItem "$InstallDir\palladium.bat" -ErrorAction SilentlyContinue
)
foreach ($s in $scripts) { TryCmd { icacls $s.FullName /grant "$env:USERNAME:(R,W,X)" /inheritance:r } "Could not set permissions on $($s.Name)" }
OK "Scripts are executable"

# 4. Data directories
STEP "[4/5] Creating data directories..."
$dirs = "installed","workspace/databases","workspace/exports","workspace/queries","secrets","profiles","backups","logs","notify"
foreach ($d in $dirs) { $null = New-Item -ItemType Directory -Path "$InstallDir\data\$d" -Force -ErrorAction SilentlyContinue }
OK "Data directories ready"

# 5. PATH / Alias
STEP "[5/5] Setting up command..."
$profilePath = $PROFILE.CurrentUserAllHosts
$alias = "function palladium { & `"$InstallDir\palladium.ps1`" `@Args }"
if (-not (Test-Path $profilePath) -or (Get-Content $profilePath -ErrorAction SilentlyContinue) -notmatch "function palladium") {
    Add-Content $profilePath "`n# Palladium`n$alias"
    OK "Added palladium command to PowerShell profile"
}
else { OK "palladium command already in profile" }

$bashRc = "$env:USERPROFILE\.bashrc"
if (Test-Path $bashRc) {
    $bashAlias = "alias palladium=""$InstallDir/palladium"""
    if ((Get-Content $bashRc) -notmatch "alias palladium=") {
        Add-Content $bashRc "`n# Palladium`n$bashAlias"
        OK "Added alias to ~/.bashrc"
    }
}

Write-Host ""
WC "═══════════════════════════════════════════════════════════════════════" $C.Green
WC "  Palladium installed successfully!" $C.Green
WC "═══════════════════════════════════════════════════════════════════════" $C.Green
Write-Host ""
WC "Location: $InstallDir" $C.Cyan
Write-Host ""
WC "Next steps:" $C.Yellow
Write-Host "  1. Restart terminal (or run: . `$PROFILE)"
Write-Host "  2. Run: palladium"
Write-Host ""
WC "Quick commands:" $C.Gray
Write-Host "  palladium                  # Launch interactive menu"
Write-Host "  palladium install ollama   # Install Ollama (local LLM)"
Write-Host "  palladium start ollama     # Start it"
Write-Host "  palladium status           # Show all services"
Write-Host ""
WC "For USB/SSD: Copy $InstallDir to your drive and run ./palladium.ps1 or ./palladium.bat" $C.Gray
Write-Host ""

# Offer to launch
if ($Host.UI.RawUI.WindowTitle -ne "Visual Studio Code Host") {
    $choice = Read-Host "Start Palladium now? (Y/n)"
    if ($choice -notmatch '^[Nn]$') {
        & "$InstallDir\palladium.ps1"
    }
}