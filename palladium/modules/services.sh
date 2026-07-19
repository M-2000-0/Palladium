#!/bin/bash
svc_list_installed() {
    echo -e "${SILVER}Installed services:${NC}"
    echo ""
    local found=0
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        local status="${RED}stopped${NC}"
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
            status="${GREEN}running${NC}"
        fi
        local port=""
        [ -f "$svc_dir/.port" ] && port=" (port $(cat "$svc_dir/.port"))"
        echo -e "  $name  [$status]$port"
        found=1
    done
    [ $found -eq 0 ] && echo -e "  ${DIM}No services installed.${NC}"
}

svc_start() {
    local svc="$1"
    [ -z "$svc" ] && { echo -e "${RED}Service name required.${NC}"; return 1; }
    local d="$INSTALLED_DIR/$svc"
    [ ! -d "$d" ] && { echo -e "${RED}Service '$svc' not found.${NC}"; return 1; }
    ensure_docker || return 1
    cd "$d" || { echo -e "${RED}Cannot access $d${NC}"; return 1; }
    with_lock "service_${svc}" bash -c "
        echo -e '${GREEN}Starting $svc...${NC}'
        docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null
    " && echo -e "${GREEN}$svc started.${NC}" || echo -e "${RED}Failed to start $svc${NC}"
}

svc_stop() {
    local svc="$1"
    [ -z "$svc" ] && { echo -e "${RED}Service name required.${NC}"; return 1; }
    local d="$INSTALLED_DIR/$svc"
    [ ! -d "$d" ] && { echo -e "${RED}Service '$svc' not found.${NC}"; return 1; }
    cd "$d" || { echo -e "${RED}Cannot access $d${NC}"; return 1; }
    echo -e "${YELLOW}Stopping $svc...${NC}"
    docker compose down 2>/dev/null || docker-compose down 2>/dev/null
    echo -e "${GREEN}$svc stopped.${NC}"
}

svc_status() {
    if [ -n "$1" ]; then
        [ ! -d "$INSTALLED_DIR/$1" ] && { echo -e "${RED}Not found.${NC}"; return 1; }
        cd "$INSTALLED_DIR/$1" || { echo -e "${RED}Cannot access directory${NC}"; return 1; }
        docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null
    else
        echo -e "${SILVER}All services:${NC}"
        for d in "$INSTALLED_DIR"/*/; do
            [ -d "$d" ] || continue
            echo -e "${BOLD}$(basename "$d"):${NC}"
            cd "$d" || continue
            docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null
            echo ""
        done
    fi
}

svc_logs() {
    local svc="$1"
    [ -z "$svc" ] && { echo -e "${RED}Service name required.${NC}"; return 1; }
    [ ! -d "$INSTALLED_DIR/$svc" ] && { echo -e "${RED}Not found.${NC}"; return 1; }
    cd "$INSTALLED_DIR/$svc" || { echo -e "${RED}Cannot access directory${NC}"; return 1; }
    docker compose logs -f --tail=100 2>/dev/null || docker-compose logs -f --tail=100
}

svc_remove() {
    local svc="$1"
    [ -z "$svc" ] && { echo -e "${RED}Service name required.${NC}"; return 1; }
    [ ! -d "$INSTALLED_DIR/$svc" ] && { echo -e "${RED}Not found.${NC}"; return 1; }
    cd "$INSTALLED_DIR/$svc" || { echo -e "${RED}Cannot access directory${NC}"; return 1; }
    echo -e "${YELLOW}Stopping $svc...${NC}"
    docker compose down -v 2>/dev/null || docker-compose down -v 2>/dev/null
    rm -rf "$INSTALLED_DIR/$svc"
    echo -e "${GREEN}$svc removed.${NC}"
}

svc_install() {
    local svc="$1"
    if [ -z "$svc" ]; then
        # No service name given — show install menu
        wizard_custom
        return
    fi

    # Check if already installed
    if [ -d "$INSTALLED_DIR/$svc" ]; then
        echo -e "${YELLOW}$svc is already installed. Starting it...${NC}"
        svc_start "$svc"
        return
    fi

    # Check service template
    local template="$SERVICES_DIR/$svc.yml"
    if [ -f "$template" ]; then
        wizard_install "$svc"
    else
        # Check marketplace
        local tool="$MARKETPLACE_DIR/$svc.tool"
        if [ -f "$tool" ]; then
            local image=$(grep "^image:" "$tool" | head -1 | sed 's/^image: //')
            local port=$(grep "^port:" "$tool" | head -1 | sed 's/^port: //')
            marketplace_install_tool "$svc" "$image" "$port"
        else
            echo -e "${RED}No template or marketplace entry for '$svc'.${NC}"
            echo -e "Use ${SILVER}palladium marketplace${NC} to browse available tools."
            return 1
        fi
    fi
}

svc_launch() {
    local svc="$1"
    if [ -z "$svc" ]; then
        show_banner
        echo -e "${YELLOW}Usage: palladium launch <service-name>${NC}"
        echo ""
        echo -e "  ${DIM}Launch installs and starts a service in one command.${NC}"
        echo ""
        echo -e "  ${DIM}Examples:${NC}"
        echo -e "  ${SILVER}palladium launch ollama${NC}    Install & start Ollama (local AI)"
        echo -e "  ${SILVER}palladium launch n8n${NC}       Install & start n8n (automation)"
        echo -e "  ${SILVER}palladium launch postgres${NC}  Install & start PostgreSQL"
        echo ""
        echo -e "  ${DIM}Browse all available tools: ${SILVER}palladium marketplace${NC}"
        return
    fi
    show_banner
    echo -e "${SILVER}Launching ${GREEN}$svc${NC}..."
    echo ""
    svc_install "$svc"
    if [ -d "$INSTALLED_DIR/$svc" ]; then
        svc_start "$svc"
    fi
}
