#!/bin/bash
# remote.sh - REST API server and multi-host management

API_PORT="${PALLADIUM_API_PORT:-8080}"
API_PID_FILE="$DATA_DIR/api.pid"
API_LOG_FILE="$DATA_DIR/api.log"
NODES_FILE="$DATA_DIR/nodes.conf"

# Start REST API server
remote_api_start() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ REST API Server ═══${NC}"
    echo ""
    
    if [ -f "$API_PID_FILE" ] && kill -0 "$(cat "$API_PID_FILE")" 2>/dev/null; then
        echo -e "${YELLOW}API already running on port $API_PORT (PID: $(cat "$API_PID_FILE"))${NC}"
        press_enter
        return
    fi
    
    echo -e "  Starting REST API on port ${GREEN}$API_PORT${NC}..."
    echo -e "  ${DIM}Endpoints:${NC}"
    echo -e "  ${DIM}  GET  /api/v1/status${NC}"
    echo -e "  ${DIM}  GET  /api/v1/services${NC}"
    echo -e "  ${DIM}  POST /api/v1/services/start${NC}"
    echo -e "  ${DIM}  POST /api/v1/services/stop${NC}"
    echo -e "  ${DIM}  GET  /api/v1/metrics${NC}"
    echo -e "  ${DIM}  GET  /api/v1/nodes${NC}"
    echo -e "  ${DIM}  POST /api/v1/nodes${NC}"
    echo ""
    
    # Create simple HTTP server using socat or python
    if command -v python3 &>/dev/null; then
        cat > "$DATA_DIR/api_server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server
import json
import subprocess
import os
import sys
from urllib.parse import urlparse, parse_qs

PALLADIUM_HOME = os.environ.get('PALLADIUM_HOME', '/opt/palladium')
DATA_DIR = os.environ.get('DATA_DIR', '/opt/palladium/data')
INSTALLED_DIR = os.path.join(DATA_DIR, 'installed')

class PalladiumAPI(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        
        if parsed.path == '/api/v1/status':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                'status': 'ok',
                'version': os.environ.get('PALLADIUM_VERSION', '1.1.0'),
                'api_port': os.environ.get('PALLADIUM_API_PORT', '8080')
            }).encode())
        
        elif parsed.path == '/api/v1/services':
            services = []
            for svc in os.listdir(INSTALLED_DIR):
                svc_dir = os.path.join(INSTALLED_DIR, svc)
                if not os.path.isdir(svc_dir):
                    continue
                running = False
                try:
                    result = subprocess.run(['docker', 'ps', '--format', '{{.Names}}'], capture_output=True, text=True)
                    running = svc in result.stdout
                except:
                    pass
                port = None
                port_file = os.path.join(svc_dir, '.port')
                if os.path.exists(port_file):
                    with open(port_file) as f:
                        port = f.read().strip()
                services.append({
                    'name': svc,
                    'running': running,
                    'port': port
                })
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'services': services}).encode())
        
        elif parsed.path == '/api/v1/metrics':
            # Basic metrics
            import psutil
            cpu = psutil.cpu_percent(interval=0.1)
            mem = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                'cpu_percent': cpu,
                'memory_percent': mem.percent,
                'memory_used_gb': round(mem.used / 1e9, 2),
                'memory_total_gb': round(mem.total / 1e9, 2),
                'disk_percent': round(disk.used / disk.total * 100, 1),
                'disk_used_gb': round(disk.used / 1e9, 2),
                'disk_total_gb': round(disk.total / 1e9, 2)
            }).encode())
        
        elif parsed.path == '/api/v1/nodes':
            nodes = []
            nodes_file = os.path.join(DATA_DIR, 'nodes.conf')
            if os.path.exists(nodes_file):
                with open(nodes_file) as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith('#'):
                            parts = line.split('|')
                            if len(parts) >= 3:
                                nodes.append({
                                    'name': parts[0],
                                    'host': parts[1],
                                    'port': parts[2],
                                    'status': 'unknown'
                                })
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'nodes': nodes}).encode())
        
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not found')
    
    def do_POST(self):
        parsed = urlparse(self.path)
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode() if content_length > 0 else '{}'
        
        try:
            data = json.loads(body)
        except:
            data = {}
        
        if parsed.path == '/api/v1/services/start':
            svc = data.get('service')
            if not svc:
                self.send_error(400, 'service required')
                return
            result = subprocess.run(['bash', '-c', f'source {PALLADIUM_HOME}/palladium/palladium && svc_start {svc}'], capture_output=True, text=True)
            self.send_response(200 if result.returncode == 0 else 500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'success': result.returncode == 0, 'output': result.stdout, 'error': result.stderr}).encode())
        
        elif parsed.path == '/api/v1/services/stop':
            svc = data.get('service')
            if not svc:
                self.send_error(400, 'service required')
                return
            result = subprocess.run(['bash', '-c', f'source {PALLADIUM_HOME}/palladium/palladium && svc_stop {svc}'], capture_output=True, text=True)
            self.send_response(200 if result.returncode == 0 else 500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'success': result.returncode == 0, 'output': result.stdout, 'error': result.stderr}).encode())
        
        elif parsed.path == '/api/v1/nodes':
            name = data.get('name')
            host = data.get('host')
            port = data.get('port', '22')
            if not name or not host:
                self.send_error(400, 'name and host required')
                return
            nodes_file = os.path.join(DATA_DIR, 'nodes.conf')
            with open(nodes_file, 'a') as f:
                f.write(f'{name}|{host}|{port}\n')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'success': True, 'node': {'name': name, 'host': host, 'port': port}}).encode())
        
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not found')
    
    def log_message(self, format, *args):
        # Suppress default log messages
        pass

if __name__ == '__main__':
    port = int(os.environ.get('PALLADIUM_API_PORT', '8080'))
    server = http.server.HTTPServer(('', port), PalladiumAPI)
    print(f"Palladium API server starting on port {port}")
    server.serve_forever()
PYEOF
        
        # Run in background
        PALLADIUM_HOME="$PALLADIUM_HOME" DATA_DIR="$DATA_DIR" PALLADIUM_API_PORT="$API_PORT" PALLADIUM_VERSION="$PALLADIUM_VERSION" python3 "$DATA_DIR/api_server.py" > "$API_LOG_FILE" 2>&1 &
        echo $! > "$API_PID_FILE"
        
        sleep 1
        
        if kill -0 "$(cat "$API_PID_FILE")" 2>/dev/null; then
            echo -e "${GREEN}API server started!${NC}"
            echo -e "  PID: $(cat "$API_PID_FILE")"
            echo -e "  Log: $API_LOG_FILE"
            echo -e "  Test: curl http://localhost:$API_PORT/api/v1/status"
        else
            echo -e "${RED}Failed to start API server${NC}"
            cat "$API_LOG_FILE"
        fi
    else
        echo -e "${RED}python3 required for REST API${NC}"
        echo -e "Install: sudo apt install python3"
    fi
    press_enter
}

# Stop API server
remote_api_stop() {
    if [ -f "$API_PID_FILE" ] && kill -0 "$(cat "$API_PID_FILE")" 2>/dev/null; then
        kill "$(cat "$API_PID_FILE")"
        rm -f "$API_PID_FILE"
        echo -e "${GREEN}API server stopped${NC}"
    else
        echo -e "${YELLOW}API server not running${NC}"
    fi
    press_enter
}

# Multi-host node management
remote_nodes_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${SILVER}${BOLD}  ═══ Multi-Host Nodes ═══${NC}"
        echo ""
        
        [ -f "$NODES_FILE" ] || touch "$NODES_FILE"
        
        echo -e "  ${BOLD}Configured Nodes:${NC}"
        local i=1
        while IFS='|' read -r name host port; do
            [ -z "$name" ] && continue
            echo -e "  [$i] ${GREEN}$name${NC} → $host:$port"
            ((i++))
        done < "$NODES_FILE"
        
        [ $i -eq 1 ] && echo -e "  ${DIM}(none)${NC}"
        
        echo ""
        echo -e "  ${BOLD}[a]${NC}  ${GREEN}Add node${NC}"
        echo -e "  ${BOLD}[r]${NC}  ${GREEN}Remove node${NC}"
        echo -e "  ${BOLD}[t]${NC}  ${GREEN}Test connection${NC}"
        echo -e "  ${BOLD}[s]${NC}  ${GREEN}Sync services${NC}"
        echo -e "  ${BOLD}[0]${NC}  Back"
        echo ""
        read -p "  Select: " choice
        
        case $choice in
            a|A)
                local name=$(prompt_value "  Node name")
                local host=$(prompt_value "  Host/IP")
                local port=$(prompt_value "  SSH port" "22")
                local user=$(prompt_value "  SSH user" "root")
                echo "$name|$host|$port|$user" >> "$NODES_FILE"
                echo -e "${GREEN}Node added${NC}"
                press_enter
                ;;
            r|R)
                local name=$(prompt_value "  Node name to remove")
                sed -i "/^$name|/d" "$NODES_FILE"
                echo -e "${GREEN}Node removed${NC}"
                press_enter
                ;;
            t|T)
                while IFS='|' read -r name host port user; do
                    [ -z "$name" ] && continue
                    echo -n "  Testing $name ($host:$port)... "
                    if ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$port" "$user@$host" "echo ok" 2>/dev/null; then
                        echo -e "${GREEN}OK${NC}"
                    else
                        echo -e "${RED}FAILED${NC}"
                    fi
                done < "$NODES_FILE"
                press_enter
                ;;
            s|S)
                remote_sync_services
                ;;
            0) return ;;
        esac
    done
}

# Sync services to remote nodes
remote_sync_services() {
    echo -e "${YELLOW}Syncing services to remote nodes...${NC}"
    
    while IFS='|' read -r name host port user; do
        [ -z "$name" ] && continue
        
        echo -e "  ${BOLD}Syncing to $name ($host)...${NC}"
        
        # Sync installed services
        rsync -avz -e "ssh -p $port" \
            --exclude='*/data/postgres/*' \
            --exclude='*/data/redis/*' \
            --exclude='*/node_modules' \
            --exclude='*.log' \
            "$INSTALLED_DIR/" "$user@$host:$INSTALLED_DIR/" 2>/dev/null
        
        # Sync marketplace
        rsync -avz -e "ssh -p $port" \
            "$MARKETPLACE_DIR/" "$user@$host:$MARKETPLACE_DIR/" 2>/dev/null
        
        echo -e "  ${GREEN}Done${NC}"
    done < "$NODES_FILE"
    
    press_enter
}

# Agent-based orchestration (runs on remote nodes)
remote_agent_install() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Install Agent on Remote Node ═══${NC}"
    echo ""
    
    local host=$(prompt_value "  Target host/IP")
    local port=$(prompt_value "  SSH port" "22")
    local user=$(prompt_value "  SSH user" "root")
    
    echo -e "${YELLOW}Installing Palladium agent on $host...${NC}"
    
    # Create agent install script
    cat > "$DATA_DIR/agent_install.sh" << 'AGENTEOF'
#!/bin/bash
# Palladium Agent - runs on remote nodes
set -e

PALLADIUM_HOME="/opt/palladium"
mkdir -p "$PALLADIUM_HOME"

# Download palladium
curl -fsSL https://github.com/M-2000-0/Palladium/releases/latest/download/palladium.tar.gz | tar xz -C /tmp
cp -r /tmp/palladium/* "$PALLADIUM_HOME/"

# Install dependencies
apt-get update && apt-get install -y docker.io docker-compose python3

# Start Docker
systemctl enable --now docker

# Create agent service
cat > /etc/systemd/system/palladium-agent.service << 'SVC'
[Unit]
Description=Palladium Agent
After=docker.service
Requires=docker.service

[Service]
Type=simple
Environment=PALLADIUM_HOME=/opt/palladium
Environment=DATA_DIR=/opt/palladium/data
ExecStart=/opt/palladium/palladium/palladium agent
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable --now palladium-agent

echo "Agent installed and started!"
AGENTEOF
    
    chmod +x "$DATA_DIR/agent_install.sh"
    
    # Copy and run on remote
    scp -P "$port" "$DATA_DIR/agent_install.sh" "$user@$host:/tmp/"
    ssh -p "$port" "$user@$host" "bash /tmp/agent_install.sh"
    
    echo -e "${GREEN}Agent installation complete on $host${NC}"
    press_enter
}

# Remote API menu
remote_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${SILVER}${BOLD}  ═══ Remote Management ═══${NC}"
        echo ""
        echo -e "  ${BOLD}[1]${NC}  ${GREEN}Start REST API${NC}        HTTP API on port $API_PORT"
        echo -e "  ${BOLD}[2]${NC}  ${GREEN}Stop REST API${NC}"
        echo -e "  ${BOLD}[3]${NC}  ${GREEN}Multi-Host Nodes${NC}      Manage remote Palladium nodes"
        echo -e "  ${BOLD}[4]${NC}  ${GREEN}Install Agent${NC}         Deploy agent to remote host"
        echo -e "  ${BOLD}[5]${NC}  ${GREEN}API Status${NC}"
        echo -e "  ${BOLD}[0]${NC}  Back"
        echo ""
        read -p "  Select: " choice
        
        case $choice in
            1) remote_api_start ;;
            2) remote_api_stop ;;
            3) remote_nodes_menu ;;
            4) remote_agent_install ;;
            5) 
                if [ -f "$API_PID_FILE" ] && kill -0 "$(cat "$API_PID_FILE")" 2>/dev/null; then
                    echo -e "${GREEN}Running${NC} (PID: $(cat "$API_PID_FILE"))"
                    echo -e "Port: $API_PORT"
                    echo -e "Test: curl http://localhost:$API_PORT/api/v1/status"
                else
                    echo -e "${RED}Stopped${NC}"
                fi
                press_enter
                ;;
            0) return ;;
        esac
    done
}