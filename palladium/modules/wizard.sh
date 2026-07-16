#!/bin/bash
wizard_install() {
    local svc="$1"
    local template="$SERVICES_DIR/$svc.yml"
    [ ! -f "$template" ] && { echo -e "${RED}Template '$svc' not found.${NC}"; press_enter; return; }

    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Installing: $svc ═══${NC}"
    echo ""
    local desc=$(grep "^# desc:" "$template" 2>/dev/null | head -1 | sed 's/^# desc: //')
    [ -n "$desc" ] && echo -e "  ${DIM}$desc${NC}" && echo ""

    # Safety checks
    check_docker_available || { press_enter; return; }
    check_storage "$PALLADIUM_HOME" || { press_enter; return; }

    local instance_name
    instance_name=$(prompt_value "  Instance name" "$svc")

    # Check if already exists
    check_existing_service "$instance_name" "" 
    local exist_result=$?
    [ $exist_result -eq 1 ] && { press_enter; return; }

    echo ""
    local env_vars=()
    local port=""

    case "$svc" in
        n8n)
            local u=$(prompt_value "  Username" "admin")
            local p=$(prompt_password "  Password" "changeme")
            local tz=$(prompt_value "  Timezone" "UTC")
            local pg=$(prompt_password "  DB password" "changeme")
            local pt=$(prompt_value "  Port" "5678")

            # Check port availability
            check_existing_service "$instance_name" "$pt"
            local port_result=$?
            if [ $port_result -eq 2 ]; then
                pt=$(prompt_value "  Choose a different port" "5679")
            fi

            port="$pt"
            env_vars=("N8N_USER=$u" "N8N_PASSWORD=$p" "TZ=$tz" "POSTGRES_PASSWORD=$pg" "DB_POSTGRESDB_PASSWORD=$pg" "PORT=$pt")
            ;;
        nginx)
            local pt=$(prompt_value "  Port" "80")
            check_existing_service "$instance_name" "$pt"
            local port_result=$?
            if [ $port_result -eq 2 ]; then
                pt=$(prompt_value "  Choose a different port" "8080")
            fi
            port="$pt"; env_vars=("PORT=$pt")
            ;;
        postgres)
            local u=$(prompt_value "  DB user" "admin")
            local p=$(prompt_password "  DB password" "changeme")
            local db=$(prompt_value "  DB name" "mydb")
            local pt=$(prompt_value "  Port" "5432")
            check_existing_service "$instance_name" "$pt"
            local port_result=$?
            if [ $port_result -eq 2 ]; then
                pt=$(prompt_value "  Choose a different port" "5433")
            fi
            port="$pt"
            env_vars=("POSTGRES_USER=$u" "POSTGRES_PASSWORD=$p" "POSTGRES_DB=$db" "PORT=$pt")
            ;;
        *)
            local pt=$(prompt_value "  Port" "8080")
            check_existing_service "$instance_name" "$pt"
            local port_result=$?
            if [ $port_result -eq 2 ]; then
                pt=$(prompt_value "  Choose a different port" "9090")
            fi
            port="$pt"; env_vars=("PORT=$pt")
            ;;
    esac

    echo ""
    echo -e "${CYAN}  Installing $instance_name on port $port...${NC}"
    confirm "  Proceed?" || { echo -e "${YELLOW}Cancelled.${NC}"; press_enter; return; }

    local target="$INSTALLED_DIR/$instance_name"
    mkdir -p "$target/data"
    cp "$template" "$target/docker-compose.yml"

    for var in "${env_vars[@]}"; do
        local k="${var%%=*}"
        local v="${var#*=}"
        sed -i "s/\${$k}/$v/g" "$target/docker-compose.yml"
    done

    echo "$port" > "$target/.port"
    printf '%s\n' "${env_vars[@]}" > "$target/.env"
    cat > "$target/.meta" << EOF
service=$svc
instance=$instance_name
port=$port
EOF

    # Pull image with fallback
    local image=$(grep "image:" "$target/docker-compose.yml" | head -1 | awk '{print $2}' | sed 's/"//g')
    if [ -n "$image" ]; then
        pull_image_with_fallback "$image" "" "$target/docker-compose.yml" || {
            show_install_error "$instance_name" "Could not pull Docker image"
            press_enter
            return
        }
    fi

    echo -e "${YELLOW}Starting $instance_name...${NC}"
    cd "$target"

    if ! run_with_retry "docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null" 3 5; then
        show_install_error "$instance_name" "Docker Compose failed to start"
        press_enter
        return
    fi

    # Health check
    health_check "$instance_name" "http://localhost:$port" 15

    echo ""
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    echo -e "${GREEN}  $instance_name is running!${NC}"
    echo -e "${GREEN}  http://localhost:$port${NC}"
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    echo ""

    # Auto-open in browser
    local url="http://localhost:$port"
    echo -e "${DIM}  Opening $url...${NC}"
    if command -v xdg-open &>/dev/null; then
        xdg-open "$url" 2>/dev/null &
    elif command -v open &>/dev/null; then
        open "$url" 2>/dev/null &
    elif command -v google-chrome &>/dev/null; then
        google-chrome "$url" 2>/dev/null &
    elif command -v chromium-browser &>/dev/null; then
        chromium-browser "$url" 2>/dev/null &
    fi

    # Show QR code
    if command -v qrencode &>/dev/null; then
        echo ""
        echo -e "${CYAN}  Scan for mobile access:${NC}"
        qrencode -t ANSIUTF8 "$url" 2>/dev/null | sed 's/^/  /'
    fi

    echo ""
    press_enter
}

wizard_custom() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Custom Docker Container ═══${NC}"
    echo ""

    # Safety checks
    check_docker_available || { press_enter; return; }
    check_storage "$PALLADIUM_HOME" || { press_enter; return; }

    local name=$(prompt_value "  Instance name")

    check_existing_service "$name" ""
    local exist_result=$?
    [ $exist_result -eq 1 ] && { press_enter; return; }

    local image=$(prompt_value "  Docker image (e.g. nginx:latest)")
    local pt=$(prompt_value "  Port" "8080")

    check_existing_service "$name" "$pt"
    local port_result=$?
    if [ $port_result -eq 2 ]; then
        pt=$(prompt_value "  Choose a different port" "9090")
    fi

    local container=$(prompt_value "  Container name" "$name")
    local restart=$(prompt_value "  Restart policy" "unless-stopped")

    echo ""
    confirm "  Install $image as $name on port $pt?" || { echo -e "${YELLOW}Cancelled.${NC}"; press_enter; return; }

    local target="$INSTALLED_DIR/$name"
    mkdir -p "$target/data"

    cat > "$target/docker-compose.yml" << COMPOSE
version: "3.8"
services:
  $container:
    image: $image
    container_name: $container
    restart: $restart
    ports:
      - "$pt:$pt"
COMPOSE

    echo "$pt" > "$target/.port"
    cat > "$target/.meta" << EOF
service=custom
instance=$name
image=$image
port=$pt
EOF

    # Pull image with fallback
    pull_image_with_fallback "$image" "" "$target/docker-compose.yml" || {
        show_install_error "$name" "Could not pull Docker image"
        press_enter
        return
    }

    echo -e "${YELLOW}Starting $name...${NC}"
    cd "$target"

    if ! run_with_retry "docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null" 3 5; then
        show_install_error "$name" "Docker Compose failed to start"
        press_enter
        return
    fi

    # Health check
    health_check "$name" "http://localhost:$pt" 15

    echo ""
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    echo -e "${GREEN}  $name is running!${NC}"
    echo -e "${GREEN}  http://localhost:$pt${NC}"
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"

    # Auto-open in browser
    local url="http://localhost:$pt"
    echo -e "${DIM}  Opening $url...${NC}"
    if command -v xdg-open &>/dev/null; then
        xdg-open "$url" 2>/dev/null &
    elif command -v open &>/dev/null; then
        open "$url" 2>/dev/null &
    elif command -v google-chrome &>/dev/null; then
        google-chrome "$url" 2>/dev/null &
    elif command -v chromium-browser &>/dev/null; then
        chromium-browser "$url" 2>/dev/null &
    fi

    if command -v qrencode &>/dev/null; then
        echo ""
        echo -e "${CYAN}  Scan for mobile access:${NC}"
        qrencode -t ANSIUTF8 "$url" 2>/dev/null | sed 's/^/  /'
    fi

    echo ""
    press_enter
}
