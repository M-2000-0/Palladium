#!/bin/bash
# updates.sh - Self-update and service version tracking

if [ -f "$PALLADIUM_HOME/../VERSION" ]; then
    CURRENT_VERSION=$(cat "$PALLADIUM_HOME/../VERSION")
else
    CURRENT_VERSION="dev"
fi

[ -f "$VERSION_FILE" ] && CURRENT_VERSION=$(cat "$VERSION_FILE")

updates_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Updates ═══${NC}"
    echo ""
    echo -e "  Palladium version: ${GREEN}v$CURRENT_VERSION${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Check for updates${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Update Palladium${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Update Docker images${NC}"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Update all services${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) check_updates ;;
        2) update_palladium ;;
        3) update_images ;;
        4) update_all_services ;;
        0) return ;;
    esac
}

check_updates() {
    echo -e "${YELLOW}Checking for updates...${NC}"
    echo ""
    echo -e "  Current version: ${GREEN}v$CURRENT_VERSION${NC}"
    echo -e "  ${DIM}Update check requires internet connection.${NC}"
    echo -e "  ${DIM}Visit: https://github.com/your-repo/palladium/releases${NC}"
    echo ""
    echo -e "  ${DIM}To update manually:${NC}"
    echo -e "  ${DIM}1. Download latest palladium${NC}"
    echo -e "  ${DIM}2. Replace palladium folder${NC}"
    echo -e "  ${DIM}3. Run: palladium update${NC}"
    press_enter
}

update_palladium() {
    echo -e "${YELLOW}Updating Palladium...${NC}"
    echo ""

    # Backup current
    local backup="$DATA_DIR/backups/palladium-pre-update-$(date +%Y%m%d).tar.gz"
    cd "$PALLADIUM_HOME/.."
    tar czf "$backup" palladium/ 2>/dev/null

    echo -e "${GREEN}Current version backed up.${NC}"
    echo ""
    echo -e "  ${DIM}To complete the update:${NC}"
    echo -e "  ${DIM}1. Download new version to a temp folder${NC}"
    echo -e "  ${DIM}2. Copy new modules/ and palladium file${NC}"
    echo -e "  ${DIM}3. Keep your data/ folder intact${NC}"
    echo -e "  ${DIM}4. Run: palladium${NC}"
    press_enter
}

update_images() {
    echo -e "${YELLOW}Updating Docker images...${NC}"
    echo ""

    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        local image=$(grep "image:" "$svc_dir/docker-compose.yml" 2>/dev/null | head -1 | awk '{print $2}' | sed 's/"//g')

        if [ -n "$image" ]; then
            echo -e "  Updating $name ($image)..."
            docker pull "$image" 2>/dev/null && echo -e "  ${GREEN}  Updated${NC}" || echo -e "  ${RED}  Failed${NC}"
        fi
    done

    echo ""
    echo -e "${GREEN}Image update complete. Restart services to apply.${NC}"
    press_enter
}

update_all_services() {
    echo -e "${YELLOW}Updating and restarting all services...${NC}"
    echo ""

    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        local image=$(grep "image:" "$svc_dir/docker-compose.yml" 2>/dev/null | head -1 | awk '{print $2}' | sed 's/"//g')

        if [ -n "$image" ]; then
            echo -e "  Updating $name..."
            docker pull "$image" 2>/dev/null
            cd "$svc_dir"
            docker compose down 2>/dev/null || docker-compose down 2>/dev/null
            docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null
            echo -e "  ${GREEN}  $name updated and restarted${NC}"
        fi
    done

    echo ""
    echo -e "${GREEN}All services updated.${NC}"
    press_enter
}

update_docker_images() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Update All Docker Images ═══${NC}"
    echo ""

    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Docker not found.${NC}"
        press_enter
        return
    fi

    local images=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>' 2>/dev/null)

    if [ -z "$images" ]; then
        echo -e "${YELLOW}No Docker images found.${NC}"
        press_enter
        return
    fi

    echo -e "${YELLOW}Pulling latest versions...${NC}"
    echo ""
    echo "$images" | while read -r image; do
        echo -e "  Pulling ${SILVER}$image${NC}..."
        docker pull "$image" 2>/dev/null && echo -e "  ${GREEN}  Done${NC}" || echo -e "  ${RED}  Failed${NC}"
        echo ""
    done

    echo -e "${GREEN}All images updated.${NC}"
    press_enter
}

version_info() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Version Information ═══${NC}"
    echo ""
    echo -e "  Palladium version: ${GREEN}$CURRENT_VERSION${NC}"
    echo ""

    local git_commit=$(git log --oneline -1 2>/dev/null)
    if [ -n "$git_commit" ]; then
        echo -e "  Git commit: ${SILVER}$git_commit${NC}"
    else
        echo -e "  Git commit: ${DIM}Not available${NC}"
    fi

    if command -v docker &>/dev/null; then
        local docker_ver=$(docker --version 2>/dev/null)
        echo -e "  Docker: ${SILVER}$docker_ver${NC}"
    else
        echo -e "  Docker: ${RED}Not installed${NC}"
    fi

    echo ""
    echo -e "  ${DIM}System info:${NC}"
    echo -e "  $(uname -a 2>/dev/null)"

    press_enter
}
