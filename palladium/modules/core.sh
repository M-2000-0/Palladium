#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

show_banner() {
    echo ""
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
    echo -e "  ${CYAN}${BOLD}Portable Server Manager${NC}"
    echo -e "  ${DIM}Plug in. Power up. Host anything.${NC}"
    echo ""
}

show_server_banner() {
    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "  ███████╗ ███████╗ ██████╗  ██╗   ██╗ ███████╗ ██████╗ "
    echo "  ██╔════╝ ██╔════╝ ██╔══██╗ ██║   ██║ ██╔════╝ ██╔══██╗"
    echo "  ███████╗ █████╗   ██████╔╝ ██║   ██║ █████╗   ██████╔╝"
    echo "  ╚════██║ ██╔══╝   ██╔══██╗ ╚██╗ ██╔╝ ██╔══╝   ██╔══██╗"
    echo "  ███████║ ███████╗ ██║  ██║  ╚████╔╝  ███████╗ ██║  ██║"
    echo "  ╚══════╝ ╚═══════╝ ╚═╝  ╚═╝   ╚═══╝   ╚═══════╝ ╚═╝  ╚═╝"
    echo -e "${NC}"
}

show_help() {
    show_banner
    echo -e "${CYAN}Usage:${NC}"
    echo "  palladium              Launch interactive menu"
    echo "  palladium install      Install a service"
    echo "  palladium start <svc>  Start a service"
    echo "  palladium stop <svc>   Stop a service"
    echo "  palladium status       Show all services"
    echo "  palladium logs <svc>   View service logs"
    echo "  palladium remove <svc> Remove a service"
    echo "  palladium list         List installed services"
    echo ""
}

ensure_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker not found.${NC}"
        echo "Install: sudo apt update && sudo apt install -y docker.io docker-compose-v2"
        return 1
    fi
    if ! docker info &> /dev/null 2>&1; then
        echo -e "${YELLOW}Starting Docker...${NC}"
        sudo service docker start 2>/dev/null || sudo systemctl start docker 2>/dev/null
        sleep 3
    fi
    return 0
}

prompt_value() {
    local prompt="$1"
    local default="${2:-}"
    local result
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " result
        echo "${result:-$default}"
    else
        read -p "$prompt: " result
        echo "$result"
    fi
}

prompt_password() {
    local prompt="$1"
    local default="${2:-}"
    local result
    if [ -n "$default" ]; then
        read -s -p "$prompt [$default]: " result
        echo
        echo "${result:-$default}"
    else
        read -s -p "$prompt: " result
        echo
        echo "$result"
    fi
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local result
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " result
        result="${result:-y}"
    else
        read -p "$prompt [y/N]: " result
        result="${result:-n}"
    fi
    [[ "$result" =~ ^[Yy] ]]
}

press_enter() {
    echo ""
    read -p "Press Enter to continue..."
}
