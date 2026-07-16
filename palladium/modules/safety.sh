#!/bin/bash
# safety.sh - Storage checks, error handling, fallbacks, cleanup

MIN_STORAGE_MB=500
WARN_STORAGE_MB=1000

check_storage() {
    local path="${1:-.}"
    local available_mb=$(df -m "$path" 2>/dev/null | awk 'NR==2 {print $4}')

    if [ -z "$available_mb" ]; then
        echo -e "${YELLOW}  Warning: Could not check storage. Proceeding anyway.${NC}"
        return 0
    fi

    if [ "$available_mb" -lt "$MIN_STORAGE_MB" ]; then
        echo -e "${RED}  ═══ STORAGE ERROR ═══${NC}"
        echo -e "${RED}  Only ${available_mb}MB available.${NC}"
        echo -e "${RED}  Need at least ${MIN_STORAGE_MB}MB free.${NC}"
        echo ""
        echo -e "  Free up space by running:"
        echo -e "    ${CYAN}palladium cleanup${NC}"
        echo ""
        return 1
    fi

    if [ "$available_mb" -lt "$WARN_STORAGE_MB" ]; then
        echo -e "${YELLOW}  Warning: Low storage (${available_mb}MB free)${NC}"
        echo -e "${YELLOW}  Consider running: palladium cleanup${NC}"
        echo ""
    fi

    return 0
}

check_docker_available() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}  Docker is not installed.${NC}"
        echo ""
        if confirm "  Install Docker now?"; then
            install_docker
            return $?
        fi
        return 1
    fi

    if ! docker info &> /dev/null 2>&1; then
        echo -e "${YELLOW}  Docker daemon is not running. Starting...${NC}"
        sudo service docker start 2>/dev/null || sudo systemctl start docker 2>/dev/null
        sleep 3

        if ! docker info &> /dev/null 2>&1; then
            echo -e "${RED}  Failed to start Docker.${NC}"
            echo -e "  Try running manually: ${CYAN}sudo service docker start${NC}"
            return 1
        fi
    fi

    return 0
}

install_docker() {
    echo -e "${CYAN}  Installing Docker...${NC}"
    if sudo apt update -qq && sudo apt install -y -qq docker.io docker-compose-v2 2>/dev/null; then
        sudo usermod -aG docker "$USER" 2>/dev/null
        sudo service docker start 2>/dev/null || sudo systemctl start docker 2>/dev/null
        sleep 3
        if docker info &> /dev/null 2>&1; then
            echo -e "${GREEN}  Docker installed successfully.${NC}"
            return 0
        fi
    fi

    echo -e "${RED}  Docker installation failed.${NC}"
    echo -e "  Try manually: ${CYAN}sudo apt update && sudo apt install docker.io${NC}"
    return 1
}

pull_image_with_fallback() {
    local image="$1"
    local fallback="${2:-}"

    echo -e "${DIM}  Pulling $image...${NC}"

    if docker pull "$image" 2>/dev/null; then
        return 0
    fi

    echo -e "${YELLOW}  Failed to pull $image${NC}"

    if [ -n "$fallback" ]; then
        echo -e "${YELLOW}  Trying fallback: $fallback${NC}"
        if docker pull "$fallback" 2>/dev/null; then
            # Replace image in compose file
            local compose_file="${3:-docker-compose.yml}"
            if [ -f "$compose_file" ]; then
                sed -i "s|$image|$fallback|g" "$compose_file"
            fi
            return 0
        fi
    fi

    echo -e "${RED}  Could not pull image. Check your internet connection.${NC}"
    return 1
}

run_with_retry() {
    local cmd="$1"
    local max_attempts="${2:-3}"
    local delay="${3:-5}"
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if eval "$cmd" 2>/dev/null; then
            return 0
        fi

        echo -e "${YELLOW}  Attempt $attempt/$max_attempts failed. Retrying in ${delay}s...${NC}"
        sleep $delay
        ((attempt++))
    done

    echo -e "${RED}  Failed after $max_attempts attempts.${NC}"
    return 1
}

health_check() {
    local name="$1"
    local url="$2"
    local max_wait="${3:-30}"

    echo -e "${DIM}  Waiting for $name to be ready...${NC}"

    for i in $(seq 1 $max_wait); do
        if curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null | grep -qE "200|301|302|401|403"; then
            echo -e "${GREEN}  $name is ready!${NC}"
            return 0
        fi
        sleep 1
    done

    echo -e "${YELLOW}  $name may still be starting. Try opening $url in your browser.${NC}"
    return 0
}

show_install_error() {
    local svc="$1"
    local error="$2"

    echo ""
    echo -e "${RED}  ═══ Installation Failed ═══${NC}"
    echo -e "${RED}  $svc could not be started.${NC}"
    echo ""
    echo -e "  Common fixes:"
    echo -e "    1. Check internet connection"
    echo -e "    2. Run: ${CYAN}palladium cleanup${NC}"
    echo -e "    3. Check logs: ${CYAN}palladium logs $svc${NC}"
    echo -e "    4. Restart Docker: ${CYAN}sudo service docker restart${NC}"
    echo ""
    if [ -n "$error" ]; then
        echo -e "  ${DIM}Error: $error${NC}"
    fi
}

cleanup_all() {
    echo -e "${CYAN}${BOLD}  ═══ Cleanup ═══${NC}"
    echo ""

    # Show current usage
    echo -e "${CYAN}  Current Docker usage:${NC}"
    docker system df 2>/dev/null || echo "  (Docker not available)"
    echo ""

    # Stop all palladium containers
    echo -e "${YELLOW}  Stopping all Palladium services...${NC}"
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        cd "$svc_dir"
        docker compose down 2>/dev/null || docker-compose down 2>/dev/null
    done

    # Prune Docker
    echo -e "${YELLOW}  Removing unused Docker images...${NC}"
    docker image prune -f 2>/dev/null
    docker container prune -f 2>/dev/null
    docker volume prune -f 2>/dev/null
    docker network prune -f 2>/dev/null

    # Show freed space
    echo ""
    echo -e "${GREEN}  Cleanup complete.${NC}"
    echo ""
    docker system df 2>/dev/null || true
}

cleanup_docker_full() {
    echo -e "${RED}  This will remove ALL Docker data (not just Palladium).${NC}"
    if confirm "  Are you sure?" "n"; then
        docker system prune -a -f 2>/dev/null
        echo -e "${GREEN}  Full Docker cleanup done.${NC}"
    fi
}

check_existing_service() {
    local name="$1"
    if [ -d "$INSTALLED_DIR/$name" ]; then
        echo -e "${RED}  Instance '$name' already exists.${NC}"
        echo -e "  Use a different name or remove it first."
        return 1
    fi

    # Check if port is already in use
    local port="$2"
    if [ -n "$port" ]; then
        if ss -tlnp 2>/dev/null | grep -q ":$port " || netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "${YELLOW}  Warning: Port $port is already in use.${NC}"
            if ! confirm "  Use a different port?"; then
                return 1
            fi
            return 2
        fi
    fi

    return 0
}
