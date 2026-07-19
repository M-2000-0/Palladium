#!/bin/bash
# Windows Native Installer (MSI/Chocolatey/Winget support)
# Run on Windows or via WSL

set -e

PALLADIUM_VERSION="1.2.0"
REPO_URL="https://github.com/M-2000-0/Palladium"
INSTALL_DIR="${INSTALL_DIR:-C:\Program Files\Palladium}"

echo "=========================================="
echo "  Palladium Windows Installer v$PALLADIUM_VERSION"
echo "=========================================="
echo ""

# Check if running on Windows
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "cygwin" && -z "$WSL_DISTRO_NAME" ]]; then
    echo "This script is for Windows (MSYS2/Git Bash/WSL)."
    echo "For Linux/macOS, use: curl -fsSL $REPO_URL/install.sh | bash"
    exit 1
fi

# Functions
log() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# Check for admin rights
check_admin() {
    if ! net session >/dev/null 2>&1; then
        error "This installer requires Administrator privileges."
        echo "Right-click your terminal and select 'Run as Administrator'."
        exit 1
    fi
    success "Running as Administrator"
}

# Install Chocolatey if not present
install_chocolatey() {
    if command -v choco >/dev/null 2>&1; then
        success "Chocolatey already installed"
        return 0
    fi
    
    log "Installing Chocolatey..."
    powershell -NoProfile -ExecutionPolicy Bypass -Command \
        "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    
    # Refresh PATH
    export PATH="$PATH:/c/ProgramData/chocolatey/bin"
    success "Chocolatey installed"
}

# Install via Chocolatey
install_chocolatey_package() {
    log "Installing Palladium via Chocolatey..."
    choco install palladium --version="$PALLADIUM_VERSION" -y
    success "Palladium installed via Chocolatey"
}

# Install via Winget
install_winget() {
    log "Installing Palladium via Winget..."
    winget install --id M-2000-0.Palladium --version "$PALLADIUM_VERSION" --accept-source-agreements --accept-package-agreements
    success "Palladium installed via Winget"
}

# Manual installation (fallback)
install_manual() {
    log "Performing manual installation..."
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Download release
    local url="https://github.com/M-2000-0/Palladium/releases/download/v${PALLADIUM_VERSION}/palladium-windows.zip"
    log "Downloading from $url..."
    
    powershell -Command "Invoke-WebRequest -Uri '$url' -OutFile '$INSTALL_DIR/palladium.zip'"
    
    # Extract
    log "Extracting..."
    powershell -Command "Expand-Archive -Path '$INSTALL_DIR/palladium.zip' -DestinationPath '$INSTALL_DIR' -Force"
    
    # Add to PATH
    log "Adding to system PATH..."
    powershell -Command "[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';$INSTALL_DIR', 'Machine')"
    
    # Create start menu shortcut
    powershell -Command "
        \$ws = New-Object -ComObject WScript.Shell
        \$shortcut = \$ws.CreateShortcut('\$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Palladium.lnk')
        \$shortcut.TargetPath = '$INSTALL_DIR\palladium.bat'
        \$shortcut.WorkingDirectory = '$INSTALL_DIR'
        \$shortcut.Description = 'Palladium - Universal Portable Server Manager'
        \$shortcut.Save()
    "
    
    # Install Docker Desktop if not present
    if ! command -v docker >/dev/null 2>&1; then
        log "Docker not found. Installing Docker Desktop..."
        choco install docker-desktop -y
        warn "Docker Desktop installed. Please log out and back in, then start Docker Desktop manually."
    fi
    
    success "Manual installation complete"
}

# Create uninstaller
create_uninstaller() {
    cat > "$INSTALL_DIR/uninstall.ps1" << 'EOF'
# Palladium Uninstaller
$installDir = "C:\Program Files\Palladium"

# Remove from PATH
$path = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$newPath = $path -replace ";?$installDir;?", ";"
[Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')

# Remove start menu shortcut
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Palladium.lnk" -ErrorAction SilentlyContinue

# Remove install directory
Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Palladium uninstalled successfully"
EOF
}

# Main menu
main() {
    check_admin
    
    echo "Select installation method:"
    echo "  [1] Chocolatey (recommended)"
    echo "  [2] Winget (Windows Package Manager)"
    echo "  [3] Manual (download & extract)"
    echo "  [4] WSL2 Integration (install in WSL)"
    echo ""
    read -p "Select [1-4]: " choice
    
    case $choice in
        1)
            install_chocolatey
            install_chocolatey_package
            ;;
        2)
            install_winget
            ;;
        3)
            install_manual
            ;;
        4)
            install_wsl2
            ;;
        *)
            error "Invalid choice"
            exit 1
            ;;
    esac
    
    create_uninstaller
    
    echo ""
    echo "=========================================="
    success "Palladium v$PALLADIUM_VERSION installed!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Open a NEW terminal (to get updated PATH)"
    echo "  2. Run: palladium"
    echo "  3. Follow the first-run setup"
    echo ""
    echo "Uninstall: PowerShell -File \"$INSTALL_DIR\uninstall.ps1\""
    echo ""
}

# WSL2 installation
install_wsl2() {
    log "Setting up Palladium in WSL2..."
    
    # Check if WSL is installed
    if ! wsl --list --verbose | grep -q "Running"; then
        log "Installing WSL2..."
        wsl --install -d Ubuntu
        warn "WSL2 installed. Please restart your computer and run this installer again."
        exit 0
    fi
    
    # Install in WSL
    wsl -d Ubuntu -- bash -c "
        curl -fsSL https://raw.githubusercontent.com/M-2000-0/Palladium/main/install.sh | bash
    "
    
    success "Palladium installed in WSL2 Ubuntu"
    echo "Run: wsl -d Ubuntu palladium"
}

# Run
main "$@"