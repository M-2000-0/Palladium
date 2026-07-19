#!/usr/bin/env bash
# wsl2-setup.ps1 - WSL2 integration setup for Palladium on Windows

param(
    [switch]$InstallDocker,
    [switch]$ImportDistro,
    [string]$DistroPath
)

Write-Host "=== Palladium WSL2 Setup ===" -ForegroundColor Cyan

# Check if WSL2 is installed
$wslVersion = wsl --version 2>$null
if (-not $wslVersion) {
    Write-Host "WSL2 not found. Installing..." -ForegroundColor Yellow
    wsl --install
    Write-Host "Please restart your computer and run this script again." -ForegroundColor Green
    exit 0
}

Write-Host "WSL2 detected: $wslVersion" -ForegroundColor Green

# Set default WSL version to 2
wsl --set-default-version 2

# Check for existing Palladium distro
$distros = wsl --list --verbose
if ($distros -match "palladium") {
    Write-Host "Palladium WSL distro already exists" -ForegroundColor Green
} else {
    if ($ImportDistro -and $DistroPath) {
        Write-Host "Importing Palladium distro from $DistroPath..." -ForegroundColor Yellow
        wsl --import palladium $env:USERPROFILE\palladium-wsl $DistroPath --version 2
    } else {
        Write-Host "Creating new Palladium WSL distro (Ubuntu base)..." -ForegroundColor Yellow
        # Use Ubuntu as base
        wsl --install -d Ubuntu
        # Wait for install
        Start-Sleep 10
        # Rename to palladium
        wsl --export Ubuntu $env:TEMP\palladium.tar
        wsl --unregister Ubuntu
        wsl --import palladium $env:USERPROFILE\palladium-wsl $env:TEMP\palladium.tar --version 2
        Remove-Item $env:TEMP\palladium.tar
    }
    Write-Host "Palladium WSL distro created" -ForegroundColor Green
}

# Configure WSL for Palladium
Write-Host "Configuring WSL for Palladium..." -ForegroundColor Yellow

# Enable systemd
$wslConfig = @"
[boot]
systemd=true

[network]
generateResolvConf=true
"@
$wslConfig | Out-File -FilePath "$env:USERPROFILE\.wslconfig" -Encoding utf8

# Setup Palladium in WSL
$setupScript = @"
#!/bin/bash
set -e

# Install Docker if needed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
fi

# Install Palladium dependencies
sudo apt-get update
sudo apt-get install -y git curl wget jq qrencode

# Clone or update Palladium
if [ ! -d "/opt/palladium" ]; then
    git clone https://github.com/M-2000-0/Palladium.git /opt/palladium
else
    cd /opt/palladium && git pull
fi

# Create symlink
sudo ln -sf /opt/palladium/palladium/palladium /usr/local/bin/palladium

echo "Palladium installed in WSL2"
"@

# Write setup script to temp and run in WSL
$setupScript | Out-File -FilePath "$env:TEMP\palladium-wsl-setup.sh" -Encoding utf8
wsl -d palladium bash "$env:TEMP\palladium-wsl-setup.sh"
Remove-Item "$env:TEMP\palladium-wsl-setup.sh"

# Configure Docker Desktop WSL integration
if ($InstallDocker) {
    Write-Host "Enabling Docker Desktop WSL2 integration..." -ForegroundColor Yellow
    # This requires Docker Desktop to be installed
    $dockerConfig = @"
{
  "experimental": false,
  "features": {
    "buildkit": true
  },
  "wsldistros": ["palladium"]
}
"@
    $dockerConfig | Out-File -FilePath "$env:APPDATA\Docker\settings.json" -Encoding utf8
}

# Create Windows Terminal profile for Palladium
$wtProfile = @"
{
  "guid": "{$(New-Guid)}",
  "name": "Palladium (WSL2)",
  "commandline": "wsl.exe -d palladium -u root palladium",
  "icon": "ms-appx:///ProfileIcons/{9acb9455-ca41-5af7-950f-6bca1bc9722f}.png",
  "startingDirectory": "//wsl$/palladium/opt/palladium",
  "tabTitle": "Palladium"
}
"@

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Palladium is now available in WSL2!" -ForegroundColor Green
Write-Host ""
Write-Host "To use Palladium:" -ForegroundColor Yellow
Write-Host "  wsl -d palladium palladium" -ForegroundColor Cyan
Write-Host ""
Write-Host "Or from Windows Terminal (after restart):" -ForegroundColor Yellow
Write-Host "  Select 'Palladium (WSL2)' profile" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your Palladium data will be at:" -ForegroundColor Yellow
Write-Host "  \\wsl$\palladium\opt\palladium\data" -ForegroundColor Cyan