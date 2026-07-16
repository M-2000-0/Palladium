#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
SILVER='\033[1;37m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

show_banner() {
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
}

show_server_banner() {
    echo ""
    echo -e "${SILVER}${BOLD}"
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
    echo -e "${SILVER}Usage:${NC}"
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

ensure_docker_in_path() {
    if ! command -v docker &> /dev/null; then
        local docker_cmd
        docker_cmd=$(find_docker_cli 2>/dev/null || true)
        if [ -n "$docker_cmd" ]; then
            local docker_dir
            docker_dir=$(dirname "$docker_cmd")
            export PATH="$docker_dir:$PATH"
        fi
    fi
}

# Input validation functions
validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

validate_instance_name() {
    local name="$1"
    [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,62}$ ]]
}

validate_password() {
    local pwd="$1"
    [ ${#pwd} -ge 8 ] || return 1
    # At least one letter and one number
    [[ "$pwd" =~ [A-Za-z] ]] && [[ "$pwd" =~ [0-9] ]]
}

prompt_port() {
    local prompt="$1"
    local default="${2:-}"
    local port
    while true; do
        port=$(prompt_value "$prompt" "$default")
        if validate_port "$port"; then
            echo "$port"
            return 0
        else
            echo -e "${RED}  Invalid port. Must be 1-65535.${NC}"
        fi
    done
}

prompt_instance_name() {
    local prompt="$1"
    local default="${2:-}"
    local name
    while true; do
        name=$(prompt_value "$prompt" "$default")
        if validate_instance_name "$name"; then
            echo "$name"
            return 0
        else
            echo -e "${RED}  Invalid name. Use alphanumeric, hyphen, underscore (1-63 chars).${NC}"
        fi
    done
}
