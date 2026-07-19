#!/bin/bash
# marketplace.sh - Install commands and service catalog

MARKETPLACE_DIR="$PALLADIUM_HOME/marketplace"
PLUGINS_DIR="$DATA_DIR/plugins"
mkdir -p "$MARKETPLACE_DIR" "$PLUGINS_DIR"

marketplace_browse() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Marketplace ═══${NC}"
    echo ""
    echo -e "  ${DIM}Browse and install tools, AI services, and integrations.${NC}"
    echo ""

    # Categories
    echo -e "  ${BOLD}Categories:${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}AI & ML${NC}           Local LLMs, API connectors, RAG"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Data Tools${NC}        Databases, dashboards, analytics"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Automation${NC}        n8n, workflows, scheduling"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Web & APIs${NC}        Reverse proxies, web servers"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}DevOps${NC}            Monitoring, CI/CD, containers"
    echo -e "  ${BOLD}[6]${NC}  ${GREEN}Messaging${NC}         Message brokers, MQTT, queues"
    echo -e "  ${BOLD}[7]${NC}  ${GREEN}Storage${NC}           Object storage, cloud drives"
    echo -e "  ${BOLD}[8]${NC}  ${GREEN}All Tools${NC}         Browse everything"
    echo ""
    echo -e "  ${BOLD}Marketplace v2:${NC}"
    echo -e "  ${BOLD}[r]${NC}  ${YELLOW}Ratings${NC}           View community ratings"
    echo -e "  ${BOLD}[u]${NC}  ${YELLOW}Check Updates${NC}     Check for tool updates"
    echo -e "  ${BOLD}[s]${NC}  ${YELLOW}Submit Tool${NC}       Contribute to marketplace"
    echo ""
    echo -e "  ${BOLD}[9]${NC}  ${MAGENTA}Custom Install${NC}    Install from Docker image or URL"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select category: " choice

    case $choice in
        1) marketplace_category "ai" ;;
        2) marketplace_category "data" ;;
        3) marketplace_category "automation" ;;
        4) marketplace_category "web" ;;
        5) marketplace_category "devops" ;;
        6) marketplace_category "messaging" ;;
        7) marketplace_category "files" ;;
        8) marketplace_category "all" ;;
        r|R) marketplace_ratings ;;
        u|U) marketplace_check_updates ;;
        s|S) marketplace_submit ;;
        9) marketplace_custom_install ;;
        0) return ;;
    esac
}

marketplace_category() {
    local category="$1"
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ ${category} Tools ═══${NC}"
    echo ""

    local tools=()
    local i=1

    # Load tools from marketplace YAML files
    for tool_file in "$MARKETPLACE_DIR"/*.tool; do
        [ -f "$tool_file" ] || continue
        local tool_cat=$(grep "^category:" "$tool_file" | head -1 | cut -d' ' -f2)
        if [ "$category" = "all" ] || [ "$tool_cat" = "$category" ]; then
            local name=$(basename "$tool_file" .tool)
            local desc=$(grep "^desc:" "$tool_file" | head -1 | sed 's/^desc: //')
            local image=$(grep "^image:" "$tool_file" | head -1 | sed 's/^image: //')
            local port=$(grep "^port:" "$tool_file" | head -1 | sed 's/^port: //')
            tools+=("$name|$image|$port|$desc")
            echo -e "  ${BOLD}[$i]${NC}  ${GREEN}$name${NC}"
            echo -e "        ${DIM}$desc${NC}"
            echo -e "        ${DIM}Image: $image | Port: $port${NC}"
            ((i++))
        fi
    done

    if [ ${#tools[@]} -eq 0 ]; then
        echo -e "  ${DIM}No tools in this category yet.${NC}"
        echo -e "  ${DIM}Use [7] Custom Install to add your own.${NC}"
        press_enter
        return
    fi

    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select tool to install: " choice

    if [ "$choice" = "0" ] || [ -z "$choice" ]; then return; fi
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#tools[@]}" ]; then
        local selected="${tools[$((choice-1))]}"
        local name=$(echo "$selected" | cut -d'|' -f1)
        local image=$(echo "$selected" | cut -d'|' -f2)
        local port=$(echo "$selected" | cut -d'|' -f3)
        marketplace_install_tool "$name" "$image" "$port"
    fi
}

marketplace_install_tool() {
    local name="$1"
    local image="$2"
    local port="$3"

    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Installing: $name ═══${NC}"
    echo ""

    local desc=$(grep "^desc:" "$MARKETPLACE_DIR/$name.tool" 2>/dev/null | head -1 | sed 's/^desc: //')
    local vars=$(grep "^vars:" "$MARKETPLACE_DIR/$name.tool" 2>/dev/null | head -1 | sed 's/^vars: //')

    [ -n "$desc" ] && echo -e "  ${DIM}$desc${NC}" && echo ""

    # Safety checks
    check_docker_available || { press_enter; return; }
    check_storage "$PALLADIUM_HOME" || { press_enter; return; }
    check_existing_service "$name" "$port"
    local exist_result=$?
    [ $exist_result -eq 1 ] && { press_enter; return; }

    if [ $exist_result -eq 2 ]; then
        port=$(prompt_value "  Choose a different port" "$((port + 1))")
    fi

    # Gather variables
    local env_vars=()
    if [ -n "$vars" ]; then
        echo -e "${SILVER}  Configuration:${NC}"
        IFS=',' read -ra VAR_ARRAY <<< "$vars"
        for var in "${VAR_ARRAY[@]}"; do
            local var_name=$(echo "$var" | cut -d'=' -f1)
            local var_default=$(echo "$var" | cut -d'=' -f2)
            local value=$(prompt_value "  $var_name" "$var_default")
            env_vars+=("$var_name=$value")
        done
    fi

    echo ""
    confirm "  Install $name?" || { echo -e "${YELLOW}Cancelled.${NC}"; press_enter; return; }

    # Create instance
    local target="$INSTALLED_DIR/$name"
    mkdir -p "$target/data"

    cat > "$target/docker-compose.yml" << COMPOSE
services:
  $name:
    image: $image
    container_name: $name
    restart: unless-stopped
    ports:
      - "$port:$port"
COMPOSE

    # Add environment variables
    if [ ${#env_vars[@]} -gt 0 ]; then
        echo "    environment:" >> "$target/docker-compose.yml"
        for var in "${env_vars[@]}"; do
            echo "      - $var" >> "$target/docker-compose.yml"
        done
    fi

    echo "$port" > "$target/.port"
    cat > "$target/.meta" << EOF
service=marketplace
instance=$name
image=$image
port=$port
installed=$(date -Iseconds)
EOF

    # Pull and start
    echo -e "${YELLOW}Pulling $image...${NC}"
    pull_image_with_fallback "$image" "" "$target/docker-compose.yml" || {
        show_install_error "$name" "Could not pull image"
        press_enter; return
    }

    echo -e "${YELLOW}Starting $name...${NC}"
    cd "$target"

    if ! run_with_retry "docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null" 3 5; then
        show_install_error "$name" "Failed to start"
        press_enter; return
    fi

    health_check "$name" "http://localhost:$port" 20

    echo ""
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    echo -e "${GREEN}  $name is running!${NC}"
    echo -e "${GREEN}  http://localhost:$port${NC}"
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"

    # Auto-open
    local url="http://localhost:$port"
    if command -v xdg-open &>/dev/null; then xdg-open "$url" 2>/dev/null &
    elif command -v chromium-browser &>/dev/null; then chromium-browser "$url" 2>/dev/null &
    fi

    if command -v qrencode &>/dev/null; then
        echo ""
        echo -e "${SILVER}  Scan for mobile:${NC}"
        qrencode -t ANSIUTF8 "$url" 2>/dev/null | sed 's/^/  /'
    fi

    echo ""
    press_enter
}

marketplace_custom_install() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Custom Install ═══${NC}"
    echo ""

    check_docker_available || { press_enter; return; }
    check_storage "$PALLADIUM_HOME" || { press_enter; return; }

    local name=$(prompt_value "  Tool name")
    local image=$(prompt_value "  Docker image (e.g. ollama/ollama:latest)")
    local port=$(prompt_value "  Port" "8080")

    check_existing_service "$name" "$port"
    local exist_result=$?
    [ $exist_result -eq 1 ] && { press_enter; return; }
    [ $exist_result -eq 2 ] && port=$(prompt_value "  Different port" "9090")

    local extra_ports=$(prompt_value "  Extra port mappings (e.g. 11434:11434, empty to skip)" "")
    local volumes=$(prompt_value "  Volumes (e.g. /data:/data, empty to skip)" "")
    local env_input=$(prompt_value "  Env vars (KEY=VAL,KEY2=VAL2, empty to skip)" "")

    echo ""
    confirm "  Install $image as $name?" || { press_enter; return; }

    local target="$INSTALLED_DIR/$name"
    mkdir -p "$target/data"

    cat > "$target/docker-compose.yml" << COMPOSE
services:
  $name:
    image: $image
    container_name: $name
    restart: unless-stopped
    ports:
      - "$port:$port"
COMPOSE

    # Extra ports
    if [ -n "$extra_ports" ]; then
        # Remove the last port line and rebuild
        sed_inplace "/$port:$port/d" "$target/docker-compose.yml"
        echo "    ports:" >> "$target/docker-compose.yml"
        echo "      - \"$port:$port\"" >> "$target/docker-compose.yml"
        IFS=',' read -ra PORT_ARRAY <<< "$extra_ports"
        for p in "${PORT_ARRAY[@]}"; do
            echo "      - \"$p\"" >> "$target/docker-compose.yml"
        done
    fi

    # Volumes
    if [ -n "$volumes" ]; then
        echo "    volumes:" >> "$target/docker-compose.yml"
        IFS=',' read -ra VOL_ARRAY <<< "$volumes"
        for v in "${VOL_ARRAY[@]}"; do
            echo "      - $v" >> "$target/docker-compose.yml"
        done
    fi

    # Environment
    if [ -n "$env_input" ]; then
        echo "    environment:" >> "$target/docker-compose.yml"
        IFS=',' read -ra ENV_ARRAY <<< "$env_input"
        for e in "${ENV_ARRAY[@]}"; do
            echo "      - $e" >> "$target/docker-compose.yml"
        done
    fi

    echo "$port" > "$target/.port"
    cat > "$target/.meta" << EOF
service=custom
instance=$name
image=$image
port=$port
EOF

    pull_image_with_fallback "$image" "" "$target/docker-compose.yml" || {
        show_install_error "$name" "Could not pull image"
        press_enter; return
    }

    cd "$target"
    if ! run_with_retry "docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null" 3 5; then
        show_install_error "$name" "Failed to start"
        press_enter; return
    fi

    health_check "$name" "http://localhost:$port" 20

    echo ""
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    echo -e "${GREEN}  $name is running!${NC}"
    echo -e "${GREEN}  http://localhost:$port${NC}"
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    echo ""
    press_enter
}

marketplace_search() {
    local query="$1"
    echo -e "${SILVER}Searching for: $query${NC}"
    echo ""
    for tool_file in "$MARKETPLACE_DIR"/*.tool; do
        [ -f "$tool_file" ] || continue
        local name=$(basename "$tool_file" .tool)
        local desc=$(grep "^desc:" "$tool_file" | head -1 | sed 's/^desc: //')
        if echo "$name $desc" | grep -qi "$query"; then
            echo -e "  ${GREEN}$name${NC} - $desc"
        fi
    done
}

# ============================================
# Marketplace v2 Features
# ============================================

# Rate a tool (1-5 stars)
marketplace_rate() {
    local tool_file="$1"
    local name=$(basename "$tool_file" .tool)
    local rating_file="$DATA_DIR/marketplace/ratings/$name.rating"
    
    mkdir -p "$(dirname "$rating_file")"
    
    echo -e "${SILVER}${BOLD}  ═══ Rate $name ═══${NC}"
    echo ""
    
    local current_avg=$(cat "$rating_file" 2>/dev/null || echo "0:0")
    local avg=$(echo "$current_avg" | cut -d: -f1)
    local count=$(echo "$current_avg" | cut -d: -f2)
    echo -e "  Current rating: ${YELLOW}$avg${NC} stars (${count} votes)"
    echo ""
    
    local rating=$(prompt_value "  Your rating (1-5)" "5")
    [[ "$rating" =~ ^[1-5]$ ]] || { echo -e "${RED}Invalid rating${NC}"; return 1; }
    
    local new_count=$((count + 1))
    local new_avg=$(awk "BEGIN {printf \"%.1f\", (($avg * $count) + $rating) / $new_count}")
    echo "$new_avg:$new_count" > "$rating_file"
    
    echo -e "${GREEN}  Thanks! New average: $new_avg stars ($new_count votes)${NC}"
    press_enter
}

# Check for tool updates
marketplace_check_updates() {
    echo -e "${SILVER}${BOLD}  ═══ Checking Tool Updates ═══${NC}"
    echo ""
    
    local updates_found=0
    
    for tool_file in "$MARKETPLACE_DIR"/*.tool; do
        [ -f "$tool_file" ] || continue
        local name=$(basename "$tool_file" .tool)
        local image=$(grep "^image:" "$tool_file" | head -1 | sed 's/^image: //')
        local current_digest=$(docker inspect --format='{{.Id}}' "$image" 2>/dev/null | cut -d: -f2 | head -c 12)
        
        # Check if image exists locally
        if [ -z "$current_digest" ]; then
            echo -e "  ${YELLOW}$name${NC} - Not installed locally"
            continue
        fi
        
        # Pull latest to check
        echo -n "  Checking $name... "
        local latest_digest=$(docker pull "$image" 2>/dev/null | grep -oE 'sha256:[a-f0-9]{12}' | head -1)
        
        if [ -n "$latest_digest" ] && [ "$latest_digest" != "$current_digest" ]; then
            echo -e "${GREEN}Update available${NC} (current: ${current_digest}, latest: ${latest_digest})"
            updates_found=1
        else
            echo -e "${GREEN}Up to date${NC}"
        fi
    done
    
    echo ""
    if [ $updates_found -eq 1 ]; then
        echo -e "${YELLOW}Updates available. Use 'palladium marketplace update <tool>' to update.${NC}"
    else
        echo -e "${GREEN}All tools up to date!${NC}"
    fi
    press_enter
}

# Update a specific tool
marketplace_update_tool() {
    local name="$1"
    local tool_file="$MARKETPLACE_DIR/$name.tool"
    
    [ -f "$tool_file" ] || { echo -e "${RED}Tool not found: $name${NC}"; return 1; }
    
    local image=$(grep "^image:" "$tool_file" | head -1 | sed 's/^image: //')
    local target="$INSTALLED_DIR/$name"
    
    [ -d "$target" ] || { echo -e "${RED}Tool not installed: $name${NC}"; return 1; }
    
    echo -e "${YELLOW}Updating $name...${NC}"
    
    # Pull latest image
    docker pull "$image" || { echo -e "${RED}Failed to pull image${NC}"; return 1; }
    
    # Restart with new image
    cd "$target"
    docker compose down 2>/dev/null || docker-compose down 2>/dev/null
    docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null
    
    echo -e "${GREEN}$name updated successfully!${NC}"
    press_enter
}

# Submit a new tool to marketplace (generates PR template)
marketplace_submit() {
    echo -e "${SILVER}${BOLD}  ═══ Submit Tool to Marketplace ═══${NC}"
    echo ""
    echo "This will generate a .tool file and GitHub PR template."
    echo ""
    
    local name=$(prompt_value "  Tool name (lowercase, no spaces)")
    [[ "$name" =~ ^[a-z0-9-]+$ ]] || { echo -e "${RED}Invalid name${NC}"; return 1; }
    
    local desc=$(prompt_value "  Short description")
    local image=$(prompt_value "  Docker image")
    local port=$(prompt_value "  Port" "8080")
    local category=$(prompt_value "  Category (ai/data/automation/web/devops/messaging/storage)" "web")
    local volumes=$(prompt_value "  Volumes (comma-separated, e.g. ./data:/data)" "")
    local env=$(prompt_value "  Environment vars (KEY=VAL,KEY2=VAL2)" "")
    
    local tool_file="$MARKETPLACE_DIR/$name.tool"
    
    cat > "$tool_file" << EOF
# Generated by marketplace_submit on $(date)
# Submit via PR to https://github.com/M-2000-0/Palladium
name: $name
desc: $desc
image: $image
port: $port
category: $category
EOF
    
    [ -n "$volumes" ] && echo "volumes: $volumes" >> "$tool_file"
    [ -n "$env" ] && echo "env: $env" >> "$tool_file"
    
    echo ""
    echo -e "${GREEN}Tool file created: $tool_file${NC}"
    echo ""
    echo "To submit to the official marketplace:"
    echo "  1. Fork https://github.com/M-2000-0/Palladium"
    echo "  2. Add this file to palladium/marketplace/"
    echo "  3. Create a Pull Request"
    echo ""
    press_enter
}

# View tool ratings
marketplace_ratings() {
    echo -e "${SILVER}${BOLD}  ═══ Tool Ratings ═══${NC}"
    echo ""
    
    for tool_file in "$MARKETPLACE_DIR"/*.tool; do
        [ -f "$tool_file" ] || continue
        local name=$(basename "$tool_file" .tool)
        local rating_file="$DATA_DIR/marketplace/ratings/$name.rating"
        local current_avg=$(cat "$rating_file" 2>/dev/null || echo "0:0")
        local avg=$(echo "$current_avg" | cut -d: -f1)
        local count=$(echo "$current_avg" | cut -d: -f2)
        
        local stars=""
        for i in $(seq 1 5); do
            if [ $(echo "$avg >= $i" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
                stars="${stars}★"
            else
                stars="${stars}☆"
            fi
        done
        printf "  %-20s %s (%.1f, %d votes)\n" "$name" "$stars" "$avg" "$count"
    done
    echo ""
    press_enter
}
