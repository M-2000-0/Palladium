#!/bin/bash
# Palladium One-Line Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/M-2000-0/Palladium/main/install.sh | bash
# Or: wget -qO- https://raw.githubusercontent.com/M-2000-0/Palladium/main/install.sh | bash

set -euo pipefail

# ─── Colors ───
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── Spinner ───
spinner() {
    local pid=$1 msg=$2 spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
    tput civis
    while kill -0 $pid 2>/dev/null; do
        printf "\r${CYAN}${spin:i++%${#spin}:1}${NC} $msg"
        sleep 0.1
    done
    tput cnorm
    printf "\r${GREEN}✓${NC} $msg\n"
}

run() { eval "$1" &>/dev/null & spinner $! "$2"; }

# ─── Banner ───
echo -e "${CYAN}${BOLD}"
cat << 'EOF'
██████╗  █████╗ ██╗     ██╗      █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗
██╔══██╗██╔══██╗██║     ██║     ██╔══██╗██╔══██╗██║██║   ██║████╗ ████║
██████╔╝███████║██║     ██║     ███████║██║  ██║██║██║   ██║██╔████╔██║
██╔═══╝ ██╔══██║██║     ██║     ██╔══██║██║  ██║██║██║   ██║██║╚██╔╝██║
██║     ██║  ██║███████╗███████╗██║  ██║██████╔╝██║╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚═╝ ╚═════╝ ╚═╝     ╚═╝
EOF
echo -e "${NC}"

# ─── Detect platform ───
OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
    Linux)   PLATFORM="linux" ;;
    Darwin)  PLATFORM="macos" ;;
    *)       echo -e "${RED}Unsupported OS: $OS${NC}"; exit 1 ;;
esac

# ─── Install directory ───
INSTALL_DIR="${PALLADIUM_INSTALL_DIR:-$HOME/.palladium}"
REPO_URL="${PALLADIUM_REPO_URL:-https://github.com/M-2000-0/Palladium}"
BRANCH="${PALLADIUM_BRANCH:-main}"

echo -e "${CYAN}Installing Palladium to ${BOLD}$INSTALL_DIR${NC}"
echo ""

# ─── 1. Install prerequisites ───
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

# Git
if ! command -v git &>/dev/null; then
    run "sudo apt-get update -qq && sudo apt-get install -y -qq git 2>/dev/null || sudo dnf install -y -q git 2>/dev/null || sudo yum install -y -q git 2>/dev/null || sudo pacman -S --noconfirm git 2>/dev/null || sudo apk add git 2>/dev/null" "Installing git"
fi

# Docker
if ! command -v docker &>/dev/null; then
    echo -e "${CYAN}Installing Docker...${NC}"
    if [[ "$OS" == "Linux" ]]; then
        run "curl -fsSL https://get.docker.com | sh" "Installing Docker (official script)"
        sudo usermod -aG docker "$USER" 2>/dev/null || true
    elif [[ "$OS" == "Darwin" ]]; then
        if command -v brew &>/dev/null; then
            run "brew install --cask docker" "Installing Docker Desktop via Homebrew"
        else
            echo -e "${YELLOW}Please install Docker Desktop: https://desktop.docker.com/mac/main/arm64/Docker.dmg${NC}"
            exit 1
        fi
    fi
else
    echo -e "${GREEN}✓${NC} Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
fi

# Docker daemon
if ! docker info &>/dev/null; then
    echo -e "${CYAN}Starting Docker daemon...${NC}"
    if [[ "$OS" == "Linux" ]]; then
        sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
        sleep 3
    elif [[ "$OS" == "Darwin" ]]; then
        open -a Docker
        echo -e "${YELLOW}Waiting for Docker Desktop to start...${NC}"
        while ! docker info &>/dev/null; do sleep 2; done
    fi
fi
echo -e "${GREEN}✓${NC} Docker daemon running"

# ─── 2. Clone / Update ───
echo -e "${YELLOW}[2/5] Fetching Palladium...${NC}"
if [[ -d "$INSTALL_DIR/.git" ]]; then
    run "cd '$INSTALL_DIR' && git fetch --quiet && git reset --hard origin/$BRANCH --quiet" "Updating existing installation"
else
    run "git clone --quiet --branch '$BRANCH' '$REPO_URL' '$INSTALL_DIR'" "Cloning repository"
fi

# ─── 3. Make executable ───
echo -e "${YELLOW}[3/5] Setting permissions...${NC}"
chmod +x "$INSTALL_DIR/palladium"
chmod +x "$INSTALL_DIR/modules"/*.sh 2>/dev/null || true
chmod +x "$INSTALL_DIR/services"/*.yml 2>/dev/null || true

# ─── 4. Create data dirs ───
echo -e "${YELLOW}[4/5] Creating data directories...${NC}"
mkdir -p "$INSTALL_DIR/data"/{installed,workspace/{databases,exports,queries},secrets,profiles,backups,logs,notify}

# ─── 5. PATH setup ───
echo -e "${YELLOW}[5/5] Setting up PATH...${NC}"

SHELL_RC=""
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == */bash ]]; then
    SHELL_RC="$HOME/.bashrc"
else
    SHELL_RC="$HOME/.profile"
fi

ALIAS_LINE="alias palladium='$INSTALL_DIR/palladium'"
if ! grep -q "alias palladium=" "$SHELL_RC" 2>/dev/null; then
    echo -e "\n# Palladium\n$ALIAS_LINE" >> "$SHELL_RC"
    echo -e "${GREEN}✓${NC} Added alias to $SHELL_RC"
else
    echo -e "${GREEN}✓${NC} Alias already in $SHELL_RC"
fi

# ─── Done ───
echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  Palladium installed successfully!${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Location: ${CYAN}$INSTALL_DIR${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  ${CYAN}source $SHELL_RC${NC}   (or restart your terminal)"
echo -e "  ${CYAN}palladium${NC}            (launch the menu)"
echo ""
echo -e "${DIM}Quick commands:${NC}"
echo -e "  ${CYAN}palladium${NC}                  Launch interactive menu"
echo -e "  ${CYAN}palladium install ollama${NC}   Install Ollama (local LLM)"
echo -e "  ${CYAN}palladium start ollama${NC}     Start it"
echo -e "  ${CYAN}palladium status${NC}           Show all services"
echo ""
echo -e "${DIM}For USB/SSD install: copy $INSTALL_DIR to your drive and run ./palladium from there${NC}"
echo ""

# Offer to start now
if [[ -t 0 ]]; then
    read -p "Start Palladium now? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        exec "$INSTALL_DIR/palladium"
    fi
fi