#!/bin/bash

API_KEYS_FILE="$DATA_DIR/.api_keys"

# Load previously saved API keys into SAVED_* variables
load_saved_api_keys() {
    if [ -f "$API_KEYS_FILE" ]; then
        while IFS='=' read -r key value; do
            [ -z "$key" ] && continue
            export "SAVED_${key}=$value"
        done < "$API_KEYS_FILE"
    fi
}

# Save API keys to shared store for reuse across services
save_api_keys() {
    > "$API_KEYS_FILE"
    local var
    for var in "${env_vars[@]}"; do
        local k="${var%%=*}"
        local v="${var#*=}"
        case "$k" in
            OPENAI_API_KEY|ANTHROPIC_API_KEY|GROQ_API_KEY|COHERE_API_KEY|MISTRAL_API_KEY|HUGGINGFACE_API_KEY|AZURE_OPENAI_API_KEY|PINECONE_API_KEY|QDRANT_API_KEY|SUPABASE_URL|SUPABASE_SERVICE_KEY)
                [ -n "$v" ] && echo "$k=$v" >> "$API_KEYS_FILE"
                ;;
        esac
    done
    chmod 600 "$API_KEYS_FILE" 2>/dev/null
    # Windows: restrict to current user
    if command -v icacls &>/dev/null; then
        local win_user="${USERNAME:-$(whoami 2>/dev/null)}"
        [ -n "$win_user" ] && icacls "$API_KEYS_FILE" /inheritance:r /grant "${win_user}:F" >/dev/null 2>&1
    fi
}

# Prompt for an optional API key, use saved value as default
prompt_and_add_key() {
    local var_name="$1"
    local display_name="$2"
    local saved_val="${3:-}"
    local default=""
    [ -n "$saved_val" ] && default="$saved_val"

    local val
    if [ -n "$default" ]; then
        local masked=$(echo "$default" | cut -c1-4)
        masked="${masked}****"
        echo -e "  ${DIM}$display_name already saved ($masked). Keep it?${NC}"
        if confirm "  Use saved $display_name?" "y"; then
            val="$default"
        else
            val=$(prompt_password "  New $display_name (leave empty to skip)")
        fi
    else
        val=$(prompt_password "  $display_name (optional)")
    fi

    if [ -n "$val" ]; then
        env_vars+=("$var_name=$val")
    fi
}

# Generate a secure random password
generate_password() {
    local length="${1:-16}"
    # Use /dev/urandom for secure random generation
    if [ -c /dev/urandom ]; then
        tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' < /dev/urandom | head -c "$length"
    else
        # Fallback for systems without /dev/urandom
        date +%s%N | sha256sum | head -c "$length"
    fi
    echo
}

wizard_install() {
    local svc="$1"
    local template="$SERVICES_DIR/$svc.yml"
    [ ! -f "$template" ] && { echo -e "${RED}Template '$svc' not found.${NC}"; press_enter; return; }

    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Installing: $svc ═══${NC}"
    echo ""
    local desc=$(grep "^# desc:" "$template" 2>/dev/null | head -1 | sed 's/^# desc: //')
    [ -n "$desc" ] && echo -e "  ${DIM}$desc${NC}" && echo ""

    # Safety checks
    check_docker_available || { press_enter; return; }
    check_storage "$PALLADIUM_HOME" || { press_enter; return; }

    local instance_name
    instance_name=$(prompt_instance_name "  Instance name" "$svc")

    # Check if already exists
    check_existing_service "$instance_name" "" 
    local exist_result=$?
    [ $exist_result -eq 1 ] && { press_enter; return; }

    echo ""
    local env_vars=()
    local port=""

    # Load any previously saved API keys from shared store
    load_saved_api_keys

    case "$svc" in
        n8n)
            echo -e "  ${YELLOW}Note: n8n 1.0+ uses owner account setup in the browser.${NC}"
            echo -e "  ${DIM}      You'll create your admin account when you first open n8n.${NC}"
            echo ""
            local tz=$(prompt_value "  Timezone" "UTC")
            local pg=$(prompt_password "  DB password" "$(generate_password)")
            local pt=$(prompt_port "  Port" "5678")

            # Check port availability
            check_existing_service "$instance_name" "$pt"
            local port_result=$?
            if [ $port_result -eq 2 ]; then
                pt=$(prompt_value "  Choose a different port" "5679")
            fi

            port="$pt"
            env_vars=("TZ=$tz" "POSTGRES_PASSWORD=$pg" "DB_POSTGRESDB_PASSWORD=$pg" "PORT=$pt" "INSTANCE_NAME=$instance_name")

            # Detect LAN IP for webhooks
            local detected_ip=""
            if command -v hostname &>/dev/null && hostname -I &>/dev/null 2>&1; then
                detected_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
            elif command -v ipconfig &>/dev/null; then
                detected_ip=$(ipconfig 2>/dev/null | grep -i "IPv4" | head -1 | awk '{print $NF}')
            fi
            if [ -n "$detected_ip" ]; then
                echo ""
                echo -e "  ${SILVER}Webhook URL${NC}"
                echo -e "  ${DIM}If you use webhooks with external services (Zapier, Slack, etc.),${NC}"
                echo -e "  ${DIM}they need to reach your n8n over the network.${NC}"
                if confirm "  Use $detected_ip for webhook URLs?" "y"; then
                    env_vars+=("N8N_HOST=$detected_ip" "WEBHOOK_URL=http://$detected_ip:$pt/")
                fi
            fi

            # Prompt for optional API keys (n8n uses these for AI nodes)
            echo ""
            echo -e "  ${SILVER}Optional: Add API keys for AI services${NC}"
            echo -e "  ${DIM}These let n8n connect to AI providers like OpenAI.${NC}"
            echo -e "  ${DIM}Skip any you don't need.${NC}"
            echo ""
            prompt_and_add_key "OPENAI_API_KEY" "OpenAI API key" "$SAVED_OPENAI_API_KEY"
            prompt_and_add_key "ANTHROPIC_API_KEY" "Anthropic API key" "$SAVED_ANTHROPIC_API_KEY"
            prompt_and_add_key "GROQ_API_KEY" "Groq API key" "$SAVED_GROQ_API_KEY"
            prompt_and_add_key "COHERE_API_KEY" "Cohere API key" "$SAVED_COHERE_API_KEY"
            prompt_and_add_key "MISTRAL_API_KEY" "Mistral API key" "$SAVED_MISTRAL_API_KEY"
            ;;
        nginx)
            local pt=$(prompt_port "  Port" "80")
            check_existing_service "$instance_name" "$pt"
            local port_result=$?
            if [ $port_result -eq 2 ]; then
                pt=$(prompt_value "  Choose a different port" "8080")
            fi
            port="$pt"; env_vars=("PORT=$pt")
            ;;
        postgres)
            local u=$(prompt_value "  DB user" "admin")
            local p=$(prompt_password "  DB password" "$(generate_password)")
            local db=$(prompt_value "  DB name" "mydb")
            local pt=$(prompt_port "  Port" "5432")
            check_existing_service "$instance_name" "$pt"
            local port_result=$?
            if [ $port_result -eq 2 ]; then
                pt=$(prompt_value "  Choose a different port" "5433")
            fi
            port="$pt"
            env_vars=("POSTGRES_USER=$u" "POSTGRES_PASSWORD=$p" "POSTGRES_DB=$db" "PORT=$pt")
            ;;
        *)
            local pt=$(prompt_port "  Port" "8080")
            check_existing_service "$instance_name" "$pt"
            local port_result=$?
            if [ $port_result -eq 2 ]; then
                pt=$(prompt_value "  Choose a different port" "9090")
            fi
            port="$pt"; env_vars=("PORT=$pt")
            ;;
    esac

    # Merge any saved API keys that weren't already prompted
    if [ -f "$API_KEYS_FILE" ]; then
        while IFS='=' read -r k v; do
            [ -z "$k" ] && continue
            local already_set=false
            for existing in "${env_vars[@]}"; do
                [ "${existing%%=*}" = "$k" ] && already_set=true && break
            done
            $already_set || env_vars+=("$k=$v")
        done < "$API_KEYS_FILE"
    fi

    # Save any new API keys for reuse
    save_api_keys

    echo ""
    echo -e "${SILVER}  Installing $instance_name on port $port...${NC}"
    confirm "  Proceed?" || { echo -e "${YELLOW}Cancelled.${NC}"; press_enter; return; }

    local target="$INSTALLED_DIR/$instance_name"
    
    # Use lock to prevent concurrent modifications
    with_lock "install_${instance_name}" bash -c "
        mkdir -p \"$target/data\"
        cp \"$template\" \"$target/docker-compose.yml\"
        
        for var in \"${env_vars[@]}\"; do
            local k=\"\${var%%=*}\"
            local v=\"\${var#*=}\"
            sed -i \"s/\\\${\$k}/\$v/g\" \"$target/docker-compose.yml\"
        done
        
        echo \"$port\" > \"$target/.port\"
        printf '%s\n' \"${env_vars[@]}\" > \"$target/.env\"
        cat > \"$target/.meta\" << EOF
service=$svc
instance=$instance_name
port=$port
EOF
    " || {
        echo -e "${RED}Failed to acquire lock for installation${NC}"
        press_enter
        return
    }

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

    if ! run_with_retry "docker compose up -d || docker-compose up -d" 3 5; then
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
        echo -e "${SILVER}  Scan for mobile access:${NC}"
        qrencode -t ANSIUTF8 "$url" 2>/dev/null | sed 's/^/  /'
    fi

    echo ""
    press_enter
}

wizard_custom() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Custom Docker Container ═══${NC}"
    echo ""

    # Safety checks
    check_docker_available || { press_enter; return; }
    check_storage "$PALLADIUM_HOME" || { press_enter; return; }

    local name=$(prompt_instance_name "  Instance name")

    check_existing_service "$name" ""
    local exist_result=$?
    [ $exist_result -eq 1 ] && { press_enter; return; }

    local image=$(prompt_value "  Docker image (e.g. nginx:latest)")
    local pt=$(prompt_port "  Port" "8080")

    check_existing_service "$name" "$pt"
    local port_result=$?
    if [ $port_result -eq 2 ]; then
        pt=$(prompt_port "  Choose a different port" "9090")
    fi

    local container=$(prompt_value "  Container name" "$name")
    local restart=$(prompt_value "  Restart policy" "unless-stopped")

    echo ""
    confirm "  Install $image as $name on port $pt?" || { echo -e "${YELLOW}Cancelled.${NC}"; press_enter; return; }

    local target="$INSTALLED_DIR/$name"
    
    # Use lock to prevent concurrent modifications
    with_lock "install_${name}" bash -c "
        mkdir -p \"$target/data\"
        
        cat > \"$target/docker-compose.yml\" << COMPOSE
version: \"3.8\"
services:
  $container:
    image: $image
    container_name: $container
    restart: $restart
    ports:
      - \"$pt:$pt\"
COMPOSE
        
        echo \"$pt\" > \"$target/.port\"
        cat > \"$target/.meta\" << EOF
service=custom
instance=$name
image=$image
port=$pt
EOF
    " || {
        echo -e "${RED}Failed to acquire lock for installation${NC}"
        press_enter
        return
    }

    # Pull image with fallback
    pull_image_with_fallback "$image" "" "$target/docker-compose.yml" || {
        show_install_error "$name" "Could not pull Docker image"
        press_enter
        return
    }

    echo -e "${YELLOW}Starting $name...${NC}"
    cd "$target"

    if ! run_with_retry "docker compose up -d || docker-compose up -d" 3 5; then
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
        echo -e "${SILVER}  Scan for mobile access:${NC}"
        qrencode -t ANSIUTF8 "$url" 2>/dev/null | sed 's/^/  /'
    fi

    echo ""
    press_enter
}
