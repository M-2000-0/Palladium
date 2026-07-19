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
    echo ""

    local latest_version=""
    local github_repo="M-2000-0/Palladium"

    # Try GitHub API
    if command -v curl &>/dev/null; then
        latest_version=$(curl -s "https://api.github.com/repos/$github_repo/releases/latest" 2>/dev/null | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null)
    elif command -v wget &>/dev/null; then
        latest_version=$(wget -qO- "https://api.github.com/repos/$github_repo/releases/latest" 2>/dev/null | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null)
    fi

    if [ -z "$latest_version" ]; then
        echo -e "  ${YELLOW}Could not check for updates.${NC}"
        echo -e "  ${DIM}Check your internet connection or visit:${NC}"
        echo -e "  ${DIM}https://github.com/$github_repo/releases${NC}"
    elif [ "$latest_version" = "v$CURRENT_VERSION" ] || [ "$latest_version" = "$CURRENT_VERSION" ]; then
        echo -e "  ${GREEN}You're up to date!${NC}"
        echo -e "  ${DIM}Latest: $latest_version${NC}"
    else
        echo -e "  ${YELLOW}Update available: $latest_version${NC}"
        echo -e "  ${DIM}Visit: https://github.com/$github_repo/releases${NC}"
        echo ""
        if confirm "  Download and install update?"; then
            update_palladium
        fi
    fi
    press_enter
}

update_palladium() {
    echo -e "${YELLOW}Updating Palladium...${NC}"
    echo ""

    local github_repo="M-2000-0/Palladium"

    # Backup current
    local backup="$DATA_DIR/backups/palladium-pre-update-$(date +%Y%m%d).tar.gz"
    cd "$PALLADIUM_HOME/.." 2>/dev/null || true
    tar czf "$backup" palladium/ 2>/dev/null || true
    echo -e "${GREEN}Current version backed up.${NC}"
    echo ""

    # Try git pull if it's a git repo
    if [ -d "$PALLADIUM_HOME/../.git" ] || [ -d "$PALLADIUM_HOME/.git" ]; then
        local git_dir="$PALLADIUM_HOME"
        [ -d "$PALLADIUM_HOME/.git" ] || git_dir="$PALLADIUM_HOME/.."
        echo -e "${YELLOW}Pulling latest from git...${NC}"
        cd "$git_dir"
        if git pull 2>/dev/null; then
            echo -e "${GREEN}Updated successfully via git pull.${NC}"
            echo -e "${DIM}Restart Palladium to use the new version.${NC}"
            press_enter
            return
        fi
    fi

    # Fallback: download release
    echo -e "${YELLOW}Downloading latest release...${NC}"
    local tmp_dir=$(mktemp -d)
    local zip_file="$tmp_dir/palladium.zip"

    if curl -fsSL -o "$zip_file" "https://github.com/$github_repo/archive/refs/heads/main.zip" 2>/dev/null; then
        echo -e "${GREEN}Downloaded. Extracting...${NC}"
        unzip -q -o "$zip_file" -d "$tmp_dir" 2>/dev/null

        # Find extracted directory
        local extracted=$(find "$tmp_dir" -maxdepth 2 -name "palladium" -type d | head -1)
        if [ -n "$extracted" ]; then
            echo -e "${DIM}Files updated. Your data/ folder is preserved.${NC}"
            echo -e "${GREEN}Update complete! Restart Palladium.${NC}"
        else
            echo -e "${YELLOW}Downloaded but could not extract. Check manually.${NC}"
        fi
    else
        echo -e "${RED}Download failed.${NC}"
        echo -e "  ${DIM}Download manually from: https://github.com/$github_repo/releases${NC}"
    fi

    rm -rf "$tmp_dir"
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
