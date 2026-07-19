#!/bin/bash
stack_install() {
    local stack="$1"
    local stack_file="$STACK_DIR/$stack.stack"

    if [ ! -f "$stack_file" ]; then
        echo -e "${RED}Stack '$stack' not found.${NC}"
        return 1
    fi

    clear 2>/dev/null || true
    local desc=$(grep "^# desc:" "$stack_file" | head -1 | sed 's/^# desc: //')
    local services=$(grep "^# services:" "$stack_file" | head -1 | sed 's/^# services: //')

    echo -e "${SILVER}${BOLD}  ═══ Installing Stack: $stack ═══${NC}"
    echo ""
    echo -e "  ${DIM}$desc${NC}"
    echo -e "  ${DIM}Services: $services${NC}"
    echo ""

    # Safety checks
    check_docker_available || { press_enter; return; }
    check_storage "$PALLADIUM_HOME" || { press_enter; return; }

    local stack_name
    stack_name=$(prompt_value "  Stack name" "$stack")

    echo ""
    echo -e "${SILVER}  This will install:${NC}"

    local svc_list=()
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        local svc_name=$(echo "$line" | cut -d'|' -f1)
        local svc_port=$(echo "$line" | cut -d'|' -f2)
        svc_list+=("$line")
        echo -e "    ${GREEN}$svc_name${NC} on port $svc_port"
    done < <(grep -v "^#" "$stack_file" | grep -v "^$")

    echo ""

    if ! confirm "  Install this stack?"; then
        echo -e "${YELLOW}Cancelled.${NC}"
        press_enter
        return
    fi

    echo ""

    local installed_count=0
    local total=${#svc_list[@]}
    local failed=0

    for entry in "${svc_list[@]}"; do
        local svc_name=$(echo "$entry" | cut -d'|' -f1)
        local svc_port=$(echo "$entry" | cut -d'|' -f2)
        local instance="${stack_name}-${svc_name}"

        ((installed_count++))
        echo -e "${SILVER}  [$installed_count/$total] Installing $svc_name...${NC}"

        if [ ! -f "$SERVICES_DIR/$svc_name.yml" ]; then
            echo -e "${RED}    Template '$svc_name' not found. Skipping.${NC}"
            ((failed++))
            continue
        fi

        # Check if already exists
        if [ -d "$INSTALLED_DIR/$instance" ]; then
            echo -e "${YELLOW}    '$instance' already exists. Skipping.${NC}"
            continue
        fi

        local target="$INSTALLED_DIR/$instance"
        mkdir -p "$target/data"
        cp "$SERVICES_DIR/$svc_name.yml" "$target/docker-compose.yml"

        sed_inplace "s/\${PORT}/$svc_port/g" "$target/docker-compose.yml"

        case "$svc_name" in
            n8n)
                local n8n_pg_pass=$(generate_password)
                sed_inplace "s/\${N8N_USER:-admin}/admin/g" "$target/docker-compose.yml"
                sed_inplace "s/\${N8N_PASSWORD:-changeme}/admin/g" "$target/docker-compose.yml"
                sed_inplace "s/\${TZ:-UTC}/UTC/g" "$target/docker-compose.yml"
                sed_inplace "s/\${POSTGRES_PASSWORD:-changeme}/$n8n_pg_pass/g" "$target/docker-compose.yml"
                ;;
            postgres)
                local pg_pass=$(generate_password)
                sed_inplace "s/\${POSTGRES_USER:-admin}/admin/g" "$target/docker-compose.yml"
                sed_inplace "s/\${POSTGRES_PASSWORD:-changeme}/$pg_pass/g" "$target/docker-compose.yml"
                sed_inplace "s/\${POSTGRES_DB:-mydb}/$stack_name/g" "$target/docker-compose.yml"
                ;;
        esac

        echo "$svc_port" > "$target/.port"
        cat > "$target/.meta" << EOF
service=$svc_name
instance=$instance
stack=$stack_name
port=$svc_port
EOF

        # Pull with fallback
        local image=$(grep "image:" "$target/docker-compose.yml" | head -1 | awk '{print $2}' | sed 's/"//g')
        if [ -n "$image" ]; then
            pull_image_with_fallback "$image" "" "$target/docker-compose.yml" || {
                echo -e "${RED}    Failed to pull $image. Skipping.${NC}"
                ((failed++))
                continue
            }
        fi

        cd "$target"
        if run_with_retry "docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null" 2 3; then
            echo -e "${GREEN}    $svc_name running on port $svc_port${NC}"
        else
            echo -e "${RED}    $svc_name failed to start${NC}"
            ((failed++))
        fi
        echo ""
    done

    echo -e "${GREEN}  ═══════════════════════════════════════${NC}"
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}  Stack '$stack_name' installed!${NC}"
    else
        echo -e "${YELLOW}  Stack '$stack_name' installed with $failed issue(s)${NC}"
    fi
    echo -e "${GREEN}  ═══════════════════════════════════════${NC}"
    echo ""

    echo -e "${SILVER}  Your services:${NC}"
    for entry in "${svc_list[@]}"; do
        local svc_name=$(echo "$entry" | cut -d'|' -f1)
        local svc_port=$(echo "$entry" | cut -d'|' -f2)
        local instance="${stack_name}-${svc_name}"
        if [ -d "$INSTALLED_DIR/$instance" ]; then
            echo -e "    ${GREEN}$svc_name${NC}  →  http://localhost:$svc_port"
        else
            echo -e "    ${RED}$svc_name${NC}  →  failed to install"
        fi
    done

    echo ""

    # Auto-open first service
    if [ ${#svc_list[@]} -gt 0 ]; then
        local first_port=$(echo "${svc_list[0]}" | cut -d'|' -f2)
        local url="http://localhost:$first_port"
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
            echo -e "${SILVER}  Scan for mobile access:${NC}"
            qrencode -t ANSIUTF8 "$url" 2>/dev/null | sed 's/^/  /'
        fi
    fi

    echo ""
    press_enter
}
