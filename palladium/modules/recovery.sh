#!/bin/bash
# recovery.sh - Recovery advisor: ask user what to do when things go wrong

recovery_ask() {
    local error_type="$1"
    local service="$2"
    local details="$3"

    clear 2>/dev/null || true
    echo -e "${RED}${BOLD}  ═══ Something went wrong ═══${NC}"
    echo ""
    echo -e "  ${DIM}$details${NC}"
    echo ""

    case "$error_type" in
        docker_not_installed)
            echo -e "  Docker is not installed on this system."
            echo -e "  Palladium needs Docker to run services."
            echo ""
            echo -e "  ${BOLD}[1]${NC}  Install Docker now (recommended)"
            echo -e "  ${BOLD}[2]${NC}  Show me how to install manually"
            echo -e "  ${BOLD}[3]${NC}  Go back"
            echo ""
            read -p "  What would you like to do? " choice
            case $choice in
                1) install_docker && echo -e "${GREEN}Docker installed! Try again.${NC}"; press_enter ;;
                2) show_manual_docker_install; press_enter ;;
                3) return ;;
            esac
            ;;

        docker_not_running)
            echo -e "  Docker is installed but not running."
            echo ""
            echo -e "  ${BOLD}[1]${NC}  Start Docker automatically"
            echo -e "  ${BOLD}[2]${NC}  Show me the command to run"
            echo -e "  ${BOLD}[3]${NC}  Go back"
            echo ""
            read -p "  What would you like to do? " choice
            case $choice in
                1)
                    sudo service docker start 2>/dev/null || sudo systemctl start docker 2>/dev/null
                    sleep 3
                    if docker info &>/dev/null 2>&1; then
                        echo -e "${GREEN}Docker started! Try again.${NC}"
                    else
                        echo -e "${RED}Could not start Docker. You may need to restart your computer.${NC}"
                    fi
                    press_enter
                    ;;
                2) echo -e "  Run: ${CYAN}sudo service docker start${NC}"; press_enter ;;
                3) return ;;
            esac
            ;;

        image_pull_failed)
            echo -e "  Could not download the Docker image."
            echo -e "  This usually means no internet connection."
            echo ""
            echo -e "  ${BOLD}[1]${NC}  Check my internet connection"
            echo -e "  ${BOLD}[2]${NC}  Try again"
            echo -e "  ${BOLD}[3]${NC}  Skip this service and continue"
            echo -e "  ${BOLD}[4]${NC}  Go back"
            echo ""
            read -p "  What would you like to do? " choice
            case $choice in
                1) check_internet; press_enter ;;
                2) return 0 ;;  # Signal retry
                3) return 2 ;;  # Signal skip
                4) return 1 ;;  # Signal cancel
            esac
            ;;

        port_in_use)
            echo -e "  Port $details is already being used by another program."
            echo ""
            echo -e "  ${BOLD}[1]${NC}  Use a different port"
            echo -e "  ${BOLD}[2]${NC}  Show what's using the port"
            echo -e "  ${BOLD}[3]${NC}  Stop the other program"
            echo -e "  ${BOLD}[4]${NC}  Go back"
            echo ""
            read -p "  What would you like to do? " choice
            case $choice in
                1) return 0 ;;  # Signal to ask for new port
                2)
                    echo ""
                    echo -e "${CYAN}  Programs using port $details:${NC}"
                    ss -tlnp 2>/dev/null | grep ":$details " || netstat -tlnp 2>/dev/null | grep ":$details " || echo "  Could not determine."
                    press_enter
                    ;;
                3)
                    echo -e "  Run: ${CYAN}sudo kill \$(lsof -t -i:$details)${NC}"
                    press_enter
                    ;;
                4) return 1 ;;
            esac
            ;;

        container_failed)
            echo -e "  The service container started but stopped immediately."
            echo -e "  This usually means a configuration error."
            echo ""
            echo -e "  ${BOLD}[1]${NC}  Show me the error logs"
            echo -e "  ${BOLD}[2]${NC}  Restart the service"
            echo -e "  ${BOLD}[3]${NC}  Reset to defaults and try again"
            echo -e "  ${BOLD}[4]${NC}  Remove this service"
            echo -e "  ${BOLD}[5]${NC}  Go back"
            echo ""
            read -p "  What would you like to do? " choice
            case $choice in
                1)
                    echo ""
                    if [ -d "$INSTALLED_DIR/$service" ]; then
                        cd "$INSTALLED_DIR/$service"
                        docker compose logs --tail=30 2>/dev/null || docker-compose logs --tail=30 2>/dev/null
                    fi
                    press_enter
                    ;;
                2) svc_start "$service"; press_enter ;;
                3)
                    if [ -d "$INSTALLED_DIR/$service" ]; then
                        cd "$INSTALLED_DIR/$service"
                        docker compose down 2>/dev/null || docker-compose down 2>/dev/null
                        docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null
                        echo -e "${GREEN}Restarted.${NC}"
                    fi
                    press_enter
                    ;;
                4)
                    if confirm "  Remove $service?" "n"; then
                        svc_remove "$service"
                    fi
                    ;;
                5) return ;;
            esac
            ;;

        storage_full)
            echo -e "  Not enough storage space on your SSD."
            echo ""
            echo -e "  ${BOLD}[1]${NC}  Clean up Docker (frees space)"
            echo -e "  ${BOLD}[2]${NC}  Show disk usage"
            echo -e "  ${BOLD}[3]${NC}  Remove a service to free space"
            echo -e "  ${BOLD}[4]${NC}  Go back"
            echo ""
            read -p "  What would you like to do? " choice
            case $choice in
                1) cleanup_all; press_enter ;;
                2) df -h; press_enter ;;
                3)
                    echo ""
                    echo -e "${CYAN}  Installed services (by size):${NC}"
                    du -sh "$INSTALLED_DIR"/*/ 2>/dev/null | sort -rh | head -10
                    echo ""
                    echo -e "  Run ${CYAN}palladium remove <name>${NC} to free space."
                    press_enter
                    ;;
                4) return ;;
            esac
            ;;

        compose_failed)
            echo -e "  Docker Compose failed to start the service."
            echo ""
            echo -e "  ${BOLD}[1]${NC}  Show the error output"
            echo -e "  ${BOLD}[2]${NC}  Validate the compose file"
            echo -e "  ${BOLD}[3]${NC}  Recreate the compose file from template"
            echo -e "  ${BOLD}[4]${NC}  Go back"
            echo ""
            read -p "  What would you like to do? " choice
            case $choice in
                1)
                    echo ""
                    echo -e "${DIM}$details${NC}"
                    press_enter
                    ;;
                2)
                    if [ -d "$INSTALLED_DIR/$service" ]; then
                        cd "$INSTALLED_DIR/$service"
                        docker compose config 2>/dev/null || docker-compose config 2>/dev/null
                    fi
                    press_enter
                    ;;
                3)
                    echo -e "${YELLOW}  This will reset the compose file. Your data will be kept.${NC}"
                    if confirm "  Continue?"; then
                        local meta="$INSTALLED_DIR/$service/.meta"
                        if [ -f "$meta" ]; then
                            local svc_type=$(grep "^service=" "$meta" | cut -d= -f2)
                            if [ -f "$SERVICES_DIR/$svc_type.yml" ]; then
                                cp "$SERVICES_DIR/$svc_type.yml" "$INSTALLED_DIR/$service/docker-compose.yml"
                                echo -e "${GREEN}  Compose file reset. Try: palladium start $service${NC}"
                            fi
                        fi
                    fi
                    press_enter
                    ;;
                4) return ;;
            esac
            ;;

        unknown)
            echo -e "  An unexpected error occurred."
            echo ""
            echo -e "  ${BOLD}[1]${NC}  Show the error details"
            echo -e "  ${BOLD}[2]${NC}  Try again"
            echo -e "  ${BOLD}[3]${NC}  Report this issue"
            echo -e "  ${BOLD}[4]${NC}  Go back"
            echo ""
            read -p "  What would you like to do? " choice
            case $choice in
                1) echo -e "${DIM}$details${NC}"; press_enter ;;
                2) return 0 ;;
                3)
                    echo ""
                    echo -e "  Please report this at:"
                    echo -e "  ${CYAN}https://github.com/your-repo/palladium/issues${NC}"
                    echo ""
                    echo -e "  Include this information:"
                    echo -e "    Service: $service"
                    echo -e "    Error: $details"
                    echo -e "    Date: $(date)"
                    press_enter
                    ;;
                4) return ;;
            esac
            ;;
    esac
}

check_internet() {
    echo ""
    if ping -c 1 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}  Internet connection is working.${NC}"
    elif curl -s --max-time 5 https://google.com &>/dev/null; then
        echo -e "${GREEN}  Internet connection is working.${NC}"
    else
        echo -e "${RED}  No internet connection detected.${NC}"
        echo -e "  Check your WiFi or Ethernet connection."
    fi
}

show_manual_docker_install() {
    echo ""
    echo -e "${CYAN}  Manual Docker Installation:${NC}"
    echo ""
    echo -e "  ${BOLD}Ubuntu/Debian:${NC}"
    echo -e "    sudo apt update"
    echo -e "    sudo apt install -y docker.io docker-compose-v2"
    echo -e "    sudo usermod -aG docker \$USER"
    echo -e "    newgrp docker"
    echo ""
    echo -e "  ${BOLD}After installing, run:${NC}"
    echo -e "    sudo service docker start"
    echo ""
    echo -e "  ${BOLD}Then try palladium again.${NC}"
}

recovery_wrapper() {
    # Wrapper that catches errors and routes to recovery
    local cmd="$1"
    local service="$2"
    local error_type="${3:-unknown}"

    local output
    local exit_code

    output=$(eval "$cmd" 2>&1)
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        recovery_ask "$error_type" "$service" "$output"
        return $?
    fi

    echo "$output"
    return 0
}
