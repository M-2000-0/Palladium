#!/bin/bash
# dashboard.sh - Data management web dashboard

DASHBOARD_PORT=8090
DASHBOARD_DIR="$PALLADIUM_HOME/dashboard"

dashboard_launch() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Data Dashboard ═══${NC}"
    echo ""

    # Check if already running
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^palladium-dashboard$"; then
        echo -e "  ${GREEN}Dashboard is already running.${NC}"
        local port=$(cat "$INSTALLED_DIR/palladium-dashboard/.port" 2>/dev/null || echo "$DASHBOARD_PORT")
        echo -e "  ${GREEN}http://localhost:$port${NC}"
        echo ""
        echo -e "  ${BOLD}[1]${NC}  Open in browser"
        echo -e "  ${BOLD}[2]${NC}  Stop dashboard"
        echo -e "  ${BOLD}[0]${NC}  Back"
        echo ""
        read -p "  Select: " choice
        case $choice in
            1) open_dashboard_url ;;
            2) dashboard_stop ;;
            0) return ;;
        esac
        return
    fi

    echo -e "  The Data Dashboard provides:"
    echo ""
    echo -e "    ${GREEN}Database Browser${NC}   - View and edit tables"
    echo -e "    ${GREEN}Query Editor${NC}        - Run SQL queries"
    echo -e "    ${GREEN}Visualizations${NC}     - Charts and graphs"
    echo -e "    ${GREEN}API Playground${NC}      - Test your API endpoints"
    echo -e "    ${GREEN}Data Export${NC}         - Export to CSV/JSON"
    echo -e "    ${GREEN}Schema Viewer${NC}      - See table relationships"
    echo ""

    # Connect to Supabase or local Postgres
    local db_choice=""
    if [ -f "$DATA_DIR/supabase.conf" ]; then
        source "$DATA_DIR/supabase.conf"
        echo -e "  ${GREEN}Supabase connected:${NC} $PROJECT_NAME"
        db_choice="supabase"
    else
        # Check for local postgres
        local pg_running=false
        for svc_dir in "$INSTALLED_DIR"/*/; do
            [ -d "$svc_dir" ] || continue
            local svc_name=$(basename "$svc_dir")
            if echo "$svc_name" | grep -qi "postgres"; then
                if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$svc_name"; then
                    pg_running=true
                    break
                fi
            fi
        done

        if $pg_running; then
            echo -e "  ${GREEN}Local PostgreSQL detected${NC}"
            db_choice="local"
        fi
    fi

    if [ -z "$db_choice" ]; then
        echo -e "  ${YELLOW}No database connected.${NC}"
        echo -e "  ${DIM}Connect Supabase or install PostgreSQL first.${NC}"
        echo ""
    fi

    local port=$(prompt_value "  Dashboard port" "$DASHBOARD_PORT")

    echo ""
    confirm "  Start Data Dashboard?" || { press_enter; return; }

    dashboard_start "$port" "$db_choice"
}

dashboard_start() {
    local port="${1:-$DASHBOARD_PORT}"
    local db_type="${2:-}"

    echo -e "${YELLOW}Starting Data Dashboard...${NC}"

    local target="$INSTALLED_DIR/palladium-dashboard"
    mkdir -p "$target/data"

    # Use a lightweight database UI image
    cat > "$target/docker-compose.yml" << 'COMPOSE'
version: "3.8"
services:
  dashboard:
    image:coleifer/sqlite-web:latest
    container_name: palladium-dashboard
    restart: unless-stopped
    ports:
      - "PORT:PORT"
    volumes:
      - ./data:/data
COMPOSE

    sed -i "s/PORT/$port/g" "$target/docker-compose.yml"

    echo "$port" > "$target/.port"
    cat > "$target/.meta" << EOF
service=dashboard
instance=palladium-dashboard
port=$port
EOF

    cd "$target"

    # Build a custom dashboard if Supabase is connected
    if [ "$db_type" = "supabase" ] && [ -f "$DATA_DIR/supabase.conf" ]; then
        source "$DATA_DIR/supabase.conf"
        dashboard_create_supabase_ui "$target" "$port"
    fi

    if run_with_retry "docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null" 3 5; then
        echo ""
        echo -e "${GREEN}  ═══════════════════════════════════${NC}"
        echo -e "${GREEN}  Data Dashboard running!${NC}"
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
    else
        show_install_error "palladium-dashboard" "Failed to start"
    fi

    echo ""
    press_enter
}

dashboard_create_supabase_ui() {
    local target="$1"
    local port="$2"

    source "$DATA_DIR/supabase.conf"

    # Create a custom HTML dashboard for Supabase
    mkdir -p "$target/data"

    cat > "$target/data/index.html" << HTMLEOF
<!DOCTYPE html>
<html>
<head>
    <title>Palladium Data Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0a0a0a; color: #e0e0e0; }
        .header { background: #1a1a2e; padding: 20px; border-bottom: 1px solid #333; }
        .header h1 { color: #00d4aa; font-size: 24px; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .card { background: #1a1a2e; border-radius: 8px; padding: 20px; margin: 10px 0; border: 1px solid #333; }
        .card h2 { color: #00d4aa; margin-bottom: 10px; }
        .btn { background: #00d4aa; color: #000; border: none; padding: 10px 20px; border-radius: 6px; cursor: pointer; font-weight: bold; }
        .btn:hover { background: #00b894; }
        .btn-secondary { background: #333; color: #fff; }
        .btn-secondary:hover { background: #444; }
        .input { background: #0d0d1a; border: 1px solid #333; color: #fff; padding: 10px; border-radius: 6px; width: 100%; margin: 5px 0; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .stat { text-align: center; padding: 20px; }
        .stat h3 { font-size: 36px; color: #00d4aa; }
        .stat p { color: #888; margin-top: 5px; }
        textarea { background: #0d0d1a; border: 1px solid #333; color: #00ff88; padding: 15px; border-radius: 6px; width: 100%; height: 200px; font-family: monospace; resize: vertical; }
        pre { background: #0d0d1a; padding: 15px; border-radius: 6px; overflow-x: auto; font-size: 13px; }
        .tabs { display: flex; gap: 5px; margin-bottom: 20px; }
        .tab { padding: 10px 20px; background: #1a1a2e; border: 1px solid #333; border-radius: 6px; cursor: pointer; }
        .tab.active { background: #00d4aa; color: #000; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #333; }
        th { color: #00d4aa; }
        .hidden { display: none; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Palladium Data Dashboard</h1>
        <p style="color: #888; margin-top: 5px;">Connected to: $PROJECT_NAME</p>
    </div>
    <div class="container">
        <div class="tabs">
            <div class="tab active" onclick="showTab('overview')">Overview</div>
            <div class="tab" onclick="showTab('query')">Query Editor</div>
            <div class="tab" onclick="showTab('tables')">Tables</div>
            <div class="tab" onclick="showTab('api')">API Playground</div>
        </div>

        <div id="overview" class="tab-content">
            <div class="grid">
                <div class="card stat">
                    <h3 id="table-count">-</h3>
                    <p>Tables</p>
                </div>
                <div class="card stat">
                    <h3 id="row-count">-</h3>
                    <p>Total Rows</p>
                </div>
                <div class="card stat">
                    <h3>Connected</h3>
                    <p style="color: #00d4aa;">Supabase Cloud</p>
                </div>
            </div>
            <div class="card">
                <h2>Quick Actions</h2>
                <button class="btn" onclick="showTab('query')">Open Query Editor</button>
                <button class="btn btn-secondary" onclick="showTab('tables')">Browse Tables</button>
                <button class="btn btn-secondary" onclick="exportData()">Export Data</button>
            </div>
        </div>

        <div id="query" class="tab-content hidden">
            <div class="card">
                <h2>SQL Query Editor</h2>
                <textarea id="sql-input" placeholder="SELECT * FROM your_table LIMIT 10;"></textarea>
                <br><br>
                <button class="btn" onclick="runQuery()">Run Query</button>
                <button class="btn btn-secondary" onclick="clearQuery()">Clear</button>
                <div id="query-result" style="margin-top: 15px;"></div>
            </div>
        </div>

        <div id="tables" class="tab-content hidden">
            <div class="card">
                <h2>Database Tables</h2>
                <p style="color: #888;">Connect Supabase to browse your tables.</p>
                <div id="tables-list"></div>
            </div>
        </div>

        <div id="api" class="tab-content hidden">
            <div class="card">
                <h2>API Playground</h2>
                <p style="color: #888; margin-bottom: 15px;">Test your Supabase REST API endpoints.</p>
                <input class="input" id="api-endpoint" placeholder="/rest/v1/your_table" value="/rest/v1/">
                <br><br>
                <button class="btn" onclick="callAPI()">Send Request</button>
                <div id="api-result" style="margin-top: 15px;"><pre>Response will appear here...</pre></div>
            </div>
        </div>
    </div>

    <script>
        const SUPABASE_URL = '$SUPABASE_URL';
        const SUPABASE_KEY = '$SUPABASE_ANON_KEY';

        function showTab(name) {
            document.querySelectorAll('.tab-content').forEach(t => t.classList.add('hidden'));
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.getElementById(name).classList.remove('hidden');
            event.target.classList.add('active');
        }

        async function runQuery() {
            const sql = document.getElementById('sql-input').value;
            const result = document.getElementById('query-result');
            result.innerHTML = '<p style="color: #888;">Running...</p>';
            try {
                const res = await fetch(SUPABASE_URL + '/rest/v1/rpc/exec_sql', {
                    method: 'POST',
                    headers: { 'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY, 'Content-Type': 'application/json' },
                    body: JSON.stringify({ query: sql })
                });
                const data = await res.json();
                result.innerHTML = '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
            } catch(e) {
                result.innerHTML = '<pre style="color: #ff6b6b;">' + e.message + '</pre>';
            }
        }

        async function callAPI() {
            const endpoint = document.getElementById('api-endpoint').value;
            const result = document.getElementById('api-result');
            result.innerHTML = '<pre>Loading...</pre>';
            try {
                const res = await fetch(SUPABASE_URL + endpoint, {
                    headers: { 'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY }
                });
                const data = await res.json();
                result.innerHTML = '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
            } catch(e) {
                result.innerHTML = '<pre style="color: #ff6b6b;">' + e.message + '</pre>';
            }
        }

        function clearQuery() { document.getElementById('sql-input').value = ''; }
        function exportData() { alert('Use the Query Editor to SELECT data, then copy the JSON output.'); }

        // Load table count
        fetch(SUPABASE_URL + '/rest/v1/', { headers: { 'apikey': SUPABASE_KEY } })
            .then(r => r.json())
            .then(d => { if(d.paths) document.getElementById('table-count').textContent = Object.keys(d.paths).length; })
            .catch(() => {});
    </script>
</body>
</html>
HTMLEOF

    # Update docker-compose to serve the custom HTML
    cat > "$target/docker-compose.yml" << COMPOSE
version: "3.8"
services:
  dashboard:
    image: nginx:alpine
    container_name: palladium-dashboard
    restart: unless-stopped
    ports:
      - "$port:80"
    volumes:
      - ./data/index.html:/usr/share/nginx/html/index.html:ro
COMPOSE
}

dashboard_stop() {
    local target="$INSTALLED_DIR/palladium-dashboard"
    if [ -d "$target" ]; then
        cd "$target"
        docker compose down 2>/dev/null || docker-compose down 2>/dev/null
        echo -e "${GREEN}Dashboard stopped.${NC}"
    fi
    press_enter
}

open_dashboard_url() {
    local port=$(cat "$INSTALLED_DIR/palladium-dashboard/.port" 2>/dev/null || echo "$DASHBOARD_PORT")
    local url="http://localhost:$port"
    if command -v xdg-open &>/dev/null; then xdg-open "$url" 2>/dev/null &
    elif command -v chromium-browser &>/dev/null; then chromium-browser "$url" 2>/dev/null &
    fi
    echo -e "${GREEN}Opening $url${NC}"
    press_enter
}
