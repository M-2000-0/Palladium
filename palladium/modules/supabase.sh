#!/bin/bash
# supabase.sh - Supabase Cloud integration

SUPABASE_CONFIG="$DATA_DIR/supabase.conf"

supabase_menu() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Supabase Integration ═══${NC}"
    echo ""

    if [ -f "$SUPABASE_CONFIG" ]; then
        local url=$(grep "^SUPABASE_URL" "$SUPABASE_CONFIG" | cut -d'=' -f2)
        local project=$(grep "^PROJECT_NAME" "$SUPABASE_CONFIG" | cut -d'=' -f2)
        echo -e "  ${GREEN}Connected${NC} to: ${BOLD}$project${NC}"
        echo -e "  ${DIM}URL: $url${NC}"
        echo ""
        echo -e "  ${BOLD}[1]${NC}  Open Supabase Dashboard"
        echo -e "  ${BOLD}[2]${NC}  View connection details"
        echo -e "  ${BOLD}[3]${NC}  Test connection"
        echo -e "  ${BOLD}[4]${NC}  Disconnect"
        echo -e "  ${BOLD}[5]${NC}  Use in a service"
        echo -e "  ${BOLD}[0]${NC}  Back"
        echo ""
        read -p "  Select: " choice
        case $choice in
            1) open_supabase_dashboard ;;
            2) supabase_show_details ;;
            3) supabase_test_connection ;;
            4) supabase_disconnect ;;
            5) supabase_use_in_service ;;
            0) return ;;
        esac
    else
        echo -e "  ${DIM}No Supabase account connected.${NC}"
        echo ""
        echo -e "  Connect your Supabase Cloud project to use it"
        echo -e "  as the database for your services."
        echo ""
        echo -e "  ${BOLD}[1]${NC}  Connect Supabase account"
        echo -e "  ${BOLD}[2]${NC}  What is Supabase?"
        echo -e "  ${BOLD}[0]${NC}  Back"
        echo ""
        read -p "  Select: " choice
        case $choice in
            1) supabase_connect ;;
            2) supabase_what_is ;;
            0) return ;;
        esac
    fi
}

supabase_connect() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Connect Supabase ═══${NC}"
    echo ""
    echo -e "  ${DIM}Enter your Supabase project credentials.${NC}"
    echo -e "  ${DIM}Find these at: https://supabase.com/dashboard → Project Settings → API${NC}"
    echo ""

    local project_name=$(prompt_value "  Project name")
    local supabase_url=$(prompt_value "  Supabase URL (https://xxx.supabase.co)")
    local anon_key=$(prompt_password "  Anonymous/public key")
    local service_key=$(prompt_password "  Service role key (optional, for admin)")
    local db_password=$(prompt_password "  Database password")

    # Build connection string
    local db_host=$(echo "$supabase_url" | sed 's|https://||' | sed 's|\.supabase\.co||')
    local connection_string="postgresql://postgres.$db_host:5432/postgres?sslmode=require"

    echo ""
    echo -e "${CYAN}  Connection Details:${NC}"
    echo -e "  Project:    $project_name"
    echo -e "  URL:        $supabase_url"
    echo -e "  Host:       db.$db_host.supabase.co"
    echo -e "  Connection: $connection_string"
    echo ""

    if ! confirm "  Save this connection?"; then
        echo -e "${YELLOW}Cancelled.${NC}"; press_enter; return
    fi

    # Save config
    cat > "$SUPABASE_CONFIG" << EOF
PROJECT_NAME=$project_name
SUPABASE_URL=$supabase_url
SUPABASE_ANON_KEY=$anon_key
SUPABASE_SERVICE_KEY=$service_key
DB_HOST=db.$db_host.supabase.co
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=$db_password
DB_CONNECTION=$connection_string
EOF

    chmod 600 "$SUPABASE_CONFIG"

    echo -e "${GREEN}Supabase connected!${NC}"
    echo ""

    # Test connection
    supabase_test_connection
    press_enter
}

supabase_test_connection() {
    echo -e "${DIM}Testing connection...${NC}"

    if [ ! -f "$SUPABASE_CONFIG" ]; then
        echo -e "${RED}No Supabase configured.${NC}"
        return 1
    fi

    source "$SUPABASE_CONFIG"

    # Test with curl
    local response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "apikey: $SUPABASE_ANON_KEY" \
        -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
        "$SUPABASE_URL/rest/v1/" 2>/dev/null)

    if [ "$response" = "200" ] || [ "$response" = "404" ]; then
        echo -e "${GREEN}  Connection successful!${NC}"
        return 0
    else
        echo -e "${RED}  Connection failed (HTTP $response)${NC}"
        echo -e "  ${DIM}Check your URL and API keys.${NC}"
        return 1
    fi
}

supabase_show_details() {
    if [ ! -f "$SUPABASE_CONFIG" ]; then
        echo -e "${RED}No Supabase configured.${NC}"
        press_enter; return
    fi

    source "$SUPABASE_CONFIG"
    echo ""
    echo -e "${CYAN}  Connection Details:${NC}"
    echo -e "  Project:     $PROJECT_NAME"
    echo -e "  URL:         $SUPABASE_URL"
    echo -e "  Dashboard:   https://supabase.com/dashboard"
    echo -e "  Host:        $DB_HOST"
    echo -e "  Port:        $DB_PORT"
    echo -e "  Database:    $DB_NAME"
    echo -e "  User:        $DB_USER"
    echo ""
    echo -e "  ${YELLOW}Connection string (for other services):${NC}"
    echo -e "  ${DIM}$DB_CONNECTION${NC}"
    echo ""
    echo -e "  ${DIM}API Keys stored securely in: $SUPABASE_CONFIG${NC}"
    press_enter
}

supabase_what_is() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ What is Supabase? ═══${NC}"
    echo ""
    echo -e "  Supabase is an open-source alternative to Firebase."
    echo -e "  It gives you:"
    echo ""
    echo -e "    ${GREEN}PostgreSQL Database${NC}  - Full SQL database in the cloud"
    echo -e "    ${GREEN}Realtime${NC}             - Live data updates"
    echo -e "    ${GREEN}Auth${NC}                  - User authentication"
    echo -e "    ${GREEN}Storage${NC}               - File storage"
    echo -e "    ${GREEN}Edge Functions${NC}        - Serverless functions"
    echo -e "    ${GREEN}Vector/AI${NC}             - pgvector for AI embeddings"
    echo ""
    echo -e "  ${CYAN}Free tier includes:${NC}"
    echo -e "    - 500MB database"
    echo -e "    - 1GB file storage"
    echo -e "    - 50,000 monthly active users"
    echo -e "    - 500MB bandwidth"
    echo ""
    echo -e "  ${CYAN}Sign up:${NC} https://supabase.com"
    echo ""
    press_enter
}

supabase_disconnect() {
    if confirm "  Disconnect Supabase?" "n"; then
        rm -f "$SUPABASE_CONFIG"
        echo -e "${GREEN}Disconnected.${NC}"
    fi
    press_enter
}

supabase_use_in_service() {
    if [ ! -f "$SUPABASE_CONFIG" ]; then
        echo -e "${RED}Connect Supabase first.${NC}"
        press_enter; return
    fi

    source "$SUPABASE_CONFIG"

    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Use Supabase in a Service ═══${NC}"
    echo ""
    echo -e "  Copy these environment variables into your service's"
    echo -e "  docker-compose.yml to connect it to Supabase:"
    echo ""
    echo -e "  ${GREEN}environment:${NC}"
    echo -e "    - SUPABASE_URL=$SUPABASE_URL"
    echo -e "    - SUPABASE_ANON_KEY=<your-anon-key>"
    echo -e "    - DATABASE_URL=$DB_CONNECTION"
    echo ""
    echo -e "  ${DIM}Or use the connection string directly:${NC}"
    echo -e "  ${DIM}$DB_CONNECTION${NC}"
    echo ""
    press_enter
}

supabase_get_env() {
    # Returns env vars for use in other scripts
    if [ -f "$SUPABASE_CONFIG" ]; then
        source "$SUPABASE_CONFIG"
        echo "SUPABASE_URL=$SUPABASE_URL SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY DATABASE_URL=$DB_CONNECTION"
    fi
}
