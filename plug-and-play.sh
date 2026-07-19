#!/bin/bash
set -e

BASE="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
SILVER='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

OS=$(detect_os)

clear 2>/dev/null || true
echo ""
echo -e "${SILVER}${BOLD}"
cat << 'EOF'
██████╗  █████╗ ██╗     ██╗      █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗
██╔══██╗██╔══██╗██║     ██║     ██╔══██╗██╔══██╗██║██║   ██║████╗ ████║
██████╔╝███████║██║     ██║     ███████║██║  ██║██║██║   ██║██╔████╔██║
██╔═══╝ ██╔══██║██║     ██║     ██╔══██║██║  ██║██║██║   ██║██║╚██╔╝██║
██║     ██║  ██║███████╗███████╗██║  ██║██████╔╝██║╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚═╝ ╚═════╝ ╚═╝     ╚═╝
EOF
echo -e "${NC}"
echo -e "  ${SILVER}${BOLD}Portable Server Manager${NC}"
echo -e "  ${DIM}Plug in. Power up. Host anything.${NC}"
echo ""

DRIVE_TYPE=""
MOUNT_POINT=""
if command -v lsblk &>/dev/null; then
    DEVICE=$(df "$BASE" 2>/dev/null | tail -1 | awk '{print $1}')
    if echo "$DEVICE" | grep -qE "sd[a-z]|nvme"; then
        DRIVE_TYPE="USB/SSD"
        MOUNT_POINT=$(df "$BASE" 2>/dev/null | tail -1 | awk '{print $6}')
    fi
elif [ "$OS" = "windows" ]; then
    DRIVE_TYPE="Local"
fi

if [ -n "$DRIVE_TYPE" ]; then
    echo -e "  ${GREEN}Running from:${NC} $DRIVE_TYPE"
    [ -n "$MOUNT_POINT" ] && echo -e "  ${GREEN}Location:${NC} $MOUNT_POINT"
    echo ""
fi

echo -e "  ${SILVER}Checking requirements...${NC}"
if command -v docker &>/dev/null; then
    if docker info &>/dev/null 2>&1; then
        echo -e "  ${GREEN}Docker:${NC} Running"
    else
        echo -e "  ${YELLOW}Docker:${NC} Installed but not running"
        echo -e "  ${DIM}Starting Docker...${NC}"
        case "$OS" in
            linux)
                sudo service docker start 2>/dev/null || sudo systemctl start docker 2>/dev/null || true
                sleep 3
                ;;
            windows)
                for p in "$PROGRAMFILES/Docker/Docker/Docker Desktop.exe" \
                         "$PROGRAMW6432/Docker/Docker/Docker Desktop.exe"; do
                    [ -f "$p" ] && { "$p" &>/dev/null & break; }
                done
                echo -e "  ${DIM}Waiting for Docker Desktop...${NC}"
                sleep 8
                ;;
            macos)
                open -a Docker 2>/dev/null || true
                echo -e "  ${DIM}Waiting for Docker Desktop...${NC}"
                sleep 8
                ;;
        esac
    fi
else
    echo -e "  ${RED}Docker:${NC} Not installed"
    echo ""
    echo -e "  Docker is required to run Palladium services."
    if [ -f "$BASE/setup.sh" ]; then
        echo -e "  ${DIM}Running setup to install Docker...${NC}"
        bash "$BASE/setup.sh" --install-docker-only 2>/dev/null || true
    fi
fi
echo ""

if [ ! -f "$BASE/.initialized" ]; then
    echo -e "  ${YELLOW}First time? Let's get you set up!${NC}"
    echo ""
    echo -e "  ${DIM}This will:${NC}"
    echo -e "  ${DIM}  1. Configure Palladium for this machine${NC}"
    echo -e "  ${DIM}  2. Set up your data directory${NC}"
    echo -e "  ${DIM}  3. Launch the main menu${NC}"
    echo ""
    read -p "  Press Enter to continue..."
    echo ""

    if [ -f "$BASE/setup.sh" ]; then
        bash "$BASE/setup.sh"
    fi

    touch "$BASE/.initialized"
    echo ""
    echo -e "${GREEN}  Setup complete!${NC}"
    echo ""
    sleep 1
else
    echo -e "  ${GREEN}Ready.${NC}"
    echo ""
fi

echo -e "  ${DIM}Launching Palladium...${NC}"
echo ""
exec "$BASE/palladium/palladium"
