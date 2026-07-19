#!/bin/bash
# safety.sh - Storage checks, error handling, fallbacks, cleanup

MIN_STORAGE_MB=500
WARN_STORAGE_MB=1000

# Portable port check - works on Linux, macOS, Windows (Git Bash/WSL)
port_in_use() {
    local port="$1"
    local host="${2:-127.0.0.1}"
    timeout 1 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null
}

# Check if port is listening on all interfaces (0.0.0.0)
port_exposed() {
    local port="$1"
    if command -v ss &>/dev/null; then
        ss -tln 2>/dev/null | grep -q ":$port "
    elif command -v netstat &>/dev/null; then
        netstat -tln 2>/dev/null | grep -q ":$port "
    else
        port_in_use "$port" "0.0.0.0"
    fi
}

# File locking for INSTALLED_DIR operations
LOCK_DIR="${TMPDIR:-/tmp}/palladium_locks"
mkdir -p "$LOCK_DIR"

lock_acquire() {
    local lock_name="$1"
    local lock_file="$LOCK_DIR/${lock_name}.lock"
    local timeout="${2:-10}"
    local start_time=$(date +%s)
    
    while ! mkdir "$lock_file" 2>/dev/null; do
        if [ $(($(date +%s) - start_time)) -ge "$timeout" ]; then
            echo -e "${RED}  Timeout acquiring lock: $lock_name${NC}" >&2
            return 1
        fi
        sleep 0.1
    done
    return 0
}

lock_release() {
    local lock_name="$1"
    local lock_file="$LOCK_DIR/${lock_name}.lock"
    rmdir "$lock_file" 2>/dev/null
}

# Wrapper to run a command with locking
with_lock() {
    local lock_name="$1"
    shift
    lock_acquire "$lock_name" || return 1
    "$@"
    local ret=$?
    lock_release "$lock_name"
    return $ret
}

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
        echo -e "    ${SILVER}palladium cleanup${NC}"
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
    local docker_cmd
    docker_cmd=$(find_docker_cli)
    if [ -z "$docker_cmd" ]; then
        echo -e "${RED}  Docker is not installed.${NC}"
        echo ""
        if confirm "  Install Docker now?"; then
            install_docker
            return $?
        fi
        return 1
    fi

    # Ensure docker CLI is in PATH for subsequent commands
    if ! command -v docker &> /dev/null; then
        local docker_dir
        docker_dir=$(dirname "$docker_cmd")
        export PATH="$docker_dir:$PATH"
    fi

    if ! docker info &> /dev/null 2>&1; then
        echo -e "${YELLOW}  Docker daemon is not running. Starting...${NC}"

        # Windows: try launching Docker Desktop
        if [ -n "$WINDIR" ] || [ -n "$SYSTEMROOT" ]; then
            local dd=""
            for p in "$PROGRAMFILES/Docker/Docker/Docker Desktop.exe" \
                     "$PROGRAMW6432/Docker/Docker/Docker Desktop.exe" \
                     "/c/Program Files/Docker/Docker/Docker Desktop.exe"; do
                [ -f "$p" ] && { dd="$p"; break; }
            done
            if [ -n "$dd" ]; then
                echo -e "  ${DIM}Launching Docker Desktop...${NC}"
                "$dd" &>/dev/null &
                sleep 5
                if docker info &> /dev/null 2>&1; then
                    echo -e "${GREEN}Docker Desktop started.${NC}"
                    return 0
                fi
                echo -e "${YELLOW}Docker Desktop may still be starting.${NC}"
            else
                echo -e "${YELLOW}Docker Desktop executable not found. Try reinstalling.${NC}"
            fi
            echo -e "  ${YELLOW}Check the system tray icon for Docker.${NC}"
            return 1
        fi

        # Linux / macOS
        sudo service docker start 2>/dev/null || sudo systemctl start docker 2>/dev/null
        sleep 3

        if ! docker info &> /dev/null 2>&1; then
            echo -e "${RED}  Failed to start Docker.${NC}"
            if [ "$(uname)" = "Darwin" ]; then
                echo -e "  Open Docker Desktop from Applications."
            else
                echo -e "  Try: ${SILVER}sudo service docker start${NC}"
            fi
            return 1
        fi
    fi

    return 0
}

install_docker() {
    echo -e "${SILVER}  Installing Docker...${NC}"

    # Windows (Git Bash / WSL bash without WSL)
    if [ -n "$WINDIR" ] || [ -n "$SYSTEMROOT" ]; then
        echo -e "  ${DIM}Detected Windows — installing Docker Desktop...${NC}"

        # Check if Docker Desktop is already installed
        if command -v docker &> /dev/null && docker info &> /dev/null 2>&1; then
            echo -e "${GREEN}  Docker is already running.${NC}"
            return 0
        fi

        # Try winget (built-in Windows package manager)
        if command -v winget &> /dev/null; then
            echo -e "  ${DIM}Using winget package manager...${NC}"
            winget install --exact --id Docker.DockerDesktop --silent --accept-package-agreements 2>&1
            local wret=$?
            if [ $wret -eq 0 ]; then
                echo -e "${GREEN}  Docker Desktop installed. Starting...${NC}"
                # Start Docker Desktop
                for p in "$PROGRAMFILES/Docker/Docker/Docker Desktop.exe" \
                         "$PROGRAMW6432/Docker/Docker/Docker Desktop.exe" \
                         "/c/Program Files/Docker/Docker/Docker Desktop.exe"; do
                    [ -f "$p" ] && { "$p" &>/dev/null & break; }
                done
                echo -e "  ${YELLOW}Docker Desktop is starting. This may take a minute.${NC}"
                echo -e "  ${YELLOW}The system tray icon will show when ready.${NC}"
                sleep 3
                return 0
            else
                echo -e "  ${YELLOW}winget install failed (code $wret). Trying direct download...${NC}"
            fi
        fi

        # Fallback: direct download
        echo -e "  ${DIM}Downloading Docker Desktop installer...${NC}"
        local installer="$TMPDIR/docker-desktop-installer.exe"
        if curl -fsSL -o "$installer" "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"; then
            echo -e "  ${DIM}Running installer (this may take a few minutes)...${NC}"
            "$installer" install --accept-license --quiet 2>&1 || "$installer" --quiet 2>&1
            echo -e "${GREEN}  Docker Desktop installed. Please restart your terminal.${NC}"
            return 0
        else
            echo -e "${RED}  Failed to download Docker Desktop.${NC}"
            echo -e "  Download manually from: ${SILVER}https://docs.docker.com/desktop/setup/install/windows-install/${NC}"
            return 1
        fi
    fi

    # macOS
    if [ "$(uname)" = "Darwin" ]; then
        if command -v brew &> /dev/null; then
            brew install --cask docker 2>&1
            echo -e "${GREEN}  Docker installed via Homebrew.${NC}"
            return 0
        fi
        echo -e "${RED}  Install Homebrew first, then run: brew install --cask docker${NC}"
        echo -e "  Or download from: ${SILVER}https://docs.docker.com/desktop/setup/install/mac-install/${NC}"
        return 1
    fi

    # Linux - try multiple package managers
    local pm=""
    local install_cmd=""
    if command -v apt &> /dev/null; then
        pm="apt"; install_cmd="sudo apt update -qq && sudo apt install -y -qq docker.io docker-compose-v2"
    elif command -v dnf &> /dev/null; then
        pm="dnf"; install_cmd="sudo dnf install -y docker docker-compose"
    elif command -v yum &> /dev/null; then
        pm="yum"; install_cmd="sudo yum install -y docker docker-compose-plugin"
    elif command -v pacman &> /dev/null; then
        pm="pacman"; install_cmd="sudo pacman -S --noconfirm docker docker-compose"
    elif command -v zypper &> /dev/null; then
        pm="zypper"; install_cmd="sudo zypper install -y docker docker-compose"
    fi

    if [ -n "$pm" ]; then
        if ! command -v sudo &> /dev/null; then
            echo -e "${YELLOW}  sudo is not installed. Trying as root...${NC}"
            install_cmd="${install_cmd/sudo /}"
        fi
        if eval "$install_cmd" 2>&1; then
            sudo usermod -aG docker "$USER" 2>/dev/null
            sudo service docker start 2>/dev/null || sudo systemctl start docker 2>/dev/null || true
            sleep 3
            if docker info &> /dev/null 2>&1; then
                echo -e "${GREEN}  Docker installed successfully.${NC}"
                return 0
            fi
        fi
    fi

    echo -e "${RED}  Docker installation failed.${NC}"
    if [ -n "$pm" ]; then
        echo -e "  Try manually: ${SILVER}sudo $pm install docker${NC}"
    else
        echo -e "  See: ${SILVER}https://docs.docker.com/engine/install/${NC}"
    fi
    return 1
}

pull_image_with_fallback() {
    local image="$1"
    local fallback="${2:-}"

    echo -e "${DIM}  Pulling $image...${NC}"

    if docker pull "$image"; then
        return 0
    fi

    echo -e "${YELLOW}  Failed to pull $image${NC}"

    if [ -n "$fallback" ]; then
        echo -e "${YELLOW}  Trying fallback: $fallback${NC}"
        if docker pull "$fallback" 2>/dev/null; then
            # Replace image in compose file
            local compose_file="${3:-docker-compose.yml}"
            if [ -f "$compose_file" ]; then
                sed_inplace "s|$image|$fallback|g" "$compose_file"
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
    return 1
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
    echo -e "    2. Run: ${SILVER}palladium cleanup${NC}"
    echo -e "    3. Check logs: ${SILVER}palladium logs $svc${NC}"
    echo -e "    4. Restart Docker: ${SILVER}sudo service docker restart${NC}"
    echo ""
    if [ -n "$error" ]; then
        echo -e "  ${DIM}Error: $error${NC}"
    fi
}

cleanup_all() {
    echo -e "${SILVER}${BOLD}  ═══ Cleanup ═══${NC}"
    echo ""

    # Show current usage
    echo -e "${SILVER}  Current Docker usage:${NC}"
    docker system df 2>/dev/null || echo "  (Docker not available)"
    echo ""

    # Stop all palladium containers
    echo -e "${YELLOW}  Stopping all Palladium services...${NC}"
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        cd "$svc_dir"
        docker compose down 2>/dev/null || docker-compose down 2>/dev/null
    done || true

    # Prune Docker
    echo -e "${YELLOW}  Removing unused Docker images...${NC}"
    docker image prune -f 2>/dev/null || true
    docker container prune -f 2>/dev/null || true
    docker volume prune -f 2>/dev/null || true
    docker network prune -f 2>/dev/null || true

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
        if port_in_use "$port"; then
            echo -e "${YELLOW}  Warning: Port $port is already in use.${NC}"
            if ! confirm "  Use a different port?"; then
                return 1
            fi
            return 2
        fi
    fi

    return 0
}
