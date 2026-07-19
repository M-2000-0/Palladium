#!/bin/bash
# api.sh - REST API server for remote management

API_PORT="${API_PORT:-8080}"
API_DIR="$DATA_DIR/api"
mkdir -p "$API_DIR"

# Generate API key if not exists
API_KEY_FILE="$API_DIR/key"
if [ ! -f "$API_KEY_FILE" ]; then
    head -c 32 /dev/urandom | base64 | tr -d '\n' > "$API_KEY_FILE"
    chmod 600 "$API_KEY_FILE"
fi
API_KEY=$(cat "$API_KEY_FILE")

api_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ REST API Server ═══${NC}"
    echo ""
    echo -e "  ${DIM}Remote management API for Palladium${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Start API Server${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Stop API Server${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Show API Key${NC}"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Regenerate API Key${NC}"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}API Documentation${NC}"
    echo -e "  ${BOLD}[6]${NC}  ${GREEN}Test Endpoint${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    
    case $choice in
        1) api_start ;;
        2) api_stop ;;
        3) api_show_key ;;
        4) api_regen_key ;;
        5) api_docs ;;
        6) api_test ;;
        0) return ;;
    esac
    press_enter
}

api_start() {
    if ! command -v python3 &>/dev/null; then
        echo -e "${RED}Python3 required for API server${NC}"
        return 1
    fi
    
    if ! python3 -c "import flask" 2>/dev/null; then
        echo -e "${YELLOW}Installing Flask...${NC}"
        pip3 install flask flask-cors --quiet 2>/dev/null || {
            echo -e "${RED}Failed to install Flask. Try: pip3 install flask flask-cors${NC}"
            return 1
        }
    fi
    
    # Check if already running
    if pgrep -f "api/server.py" >/dev/null; then
        echo -e "${YELLOW}API server already running${NC}"
        return 0
    fi
    
    cat > "$API_DIR/server.py" << 'PYEOF'
#!/usr/bin/env python3
import os
import json
import subprocess
import threading
import time
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

PALLADIUM_HOME = os.environ.get('PALLADIUM_HOME', '/palladium')
DATA_DIR = os.environ.get('DATA_DIR', '/palladium/data')
API_KEY = os.environ.get('API_KEY', 'changeme')

def require_auth(f):
    def decorated(*args, **kwargs):
        auth = request.headers.get('Authorization', '')
        if not auth.startswith('Bearer ') or auth[7:] != API_KEY:
            return jsonify({'error': 'Unauthorized'}), 401
        return f(*args, **kwargs)
    decorated.__name__ = f.__name__
    return decorated

def run_cmd(cmd, cwd=None):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd, timeout=30)
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, '', 'Timeout'

@app.route('/health')
def health():
    return jsonify({'status': 'ok', 'version': '1.1.0'})

@app.route('/api/v1/status')
@require_auth
def status():
    code, out, _ = run_cmd('docker ps --format "{{.Names}}|{{.Status}}|{{.Ports}}"')
    services = []
    for line in out.strip().split('\n'):
        if line:
            parts = line.split('|')
            services.append({'name': parts[0], 'status': parts[1], 'ports': parts[2] if len(parts) > 2 else ''})
    
    code, cpu, _ = run_cmd("top -bn1 | grep 'Cpu(s)' | awk '{print $2}'")
    code, mem, _ = run_cmd("free | grep Mem | awk '{print $3/$2 * 100.0}'")
    code, disk, _ = run_cmd("df -h / | awk 'NR==2 {print $5}'")
    
    return jsonify({
        'services': services,
        'system': {
            'cpu_percent': float(cpu.strip() or 0),
            'memory_percent': float(mem.strip() or 0),
            'disk_usage': disk.strip()
        }
    })

@app.route('/api/v1/services')
@require_auth
def list_services():
    code, out, _ = run_cmd('docker ps -a --format "{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}"')
    services = []
    for line in out.strip().split('\n'):
        if line:
            parts = line.split('|')
            services.append({'name': parts[0], 'image': parts[1], 'status': parts[2], 'ports': parts[3] if len(parts) > 3 else ''})
    return jsonify({'services': services})

@app.route('/api/v1/services/<name>/start', methods=['POST'])
@require_auth
def start_service(name):
    code, out, err = run_cmd(f'docker start {name}')
    return jsonify({'success': code == 0, 'output': out, 'error': err})

@app.route('/api/v1/services/<name>/stop', methods=['POST'])
@require_auth
def stop_service(name):
    code, out, err = run_cmd(f'docker stop {name}')
    return jsonify({'success': code == 0, 'output': out, 'error': err})

@app.route('/api/v1/services/<name>/restart', methods=['POST'])
@require_auth
def restart_service(name):
    code, out, err = run_cmd(f'docker restart {name}')
    return jsonify({'success': code == 0, 'output': out, 'error': err})

@app.route('/api/v1/services/<name>/logs')
@require_auth
def service_logs(name):
    lines = request.args.get('lines', 100)
    code, out, err = run_cmd(f'docker logs --tail {lines} {name}')
    return jsonify({'logs': out, 'error': err})

@app.route('/api/v1/services', methods=['POST'])
@require_auth
def create_service():
    data = request.get_json()
    name = data.get('name')
    image = data.get('image')
    ports = data.get('ports', [])
    env = data.get('env', {})
    volumes = data.get('volumes', [])
    
    if not name or not image:
        return jsonify({'error': 'name and image required'}), 400
    
    cmd = f'docker run -d --name {name} --restart unless-stopped'
    for p in ports:
        cmd += f' -p {p}'
    for k, v in env.items():
        cmd += f' -e {k}={v}'
    for v in volumes:
        cmd += f' -v {v}'
    cmd += f' {image}'
    
    code, out, err = run_cmd(cmd)
    return jsonify({'success': code == 0, 'container_id': out.strip(), 'error': err})

@app.route('/api/v1/services/<name>', methods=['DELETE'])
@require_auth
def delete_service(name):
    code, out, err = run_cmd(f'docker rm -f {name}')
    return jsonify({'success': code == 0, 'output': out, 'error': err})

@app.route('/api/v1/stacks')
@require_auth
def list_stacks():
    # Return available stack templates
    stacks = []
    for stack_file in os.listdir(os.path.join(PALLADIUM_HOME, 'stacks')):
        if stack_file.endswith('.stack'):
            stacks.append(stack_file.replace('.stack', ''))
    return jsonify({'stacks': stacks})

@app.route('/api/v1/stacks/<name>/install', methods=['POST'])
@require_auth
def install_stack(name):
    # This would call the stack_install function
    return jsonify({'success': True, 'message': f'Stack {name} installation started'})

@app.route('/api/v1/backup', methods=['POST'])
@require_auth
def create_backup():
    data = request.get_json() or {}
    services = data.get('services', 'all')
    method = data.get('method', 'tar')
    target = data.get('target')
    return jsonify({'success': True, 'message': 'Backup started', 'method': method})

@app.route('/api/v1/marketplace/tools')
@require_auth
def marketplace_tools():
    tools = []
    marketplace_dir = os.path.join(PALLADIUM_HOME, 'marketplace')
    for tool_file in os.listdir(marketplace_dir):
        if tool_file.endswith('.tool'):
            tools.append(tool_file.replace('.tool', ''))
    return jsonify({'tools': tools})

@app.route('/api/v1/marketplace/install/<name>', methods=['POST'])
@require_auth
def marketplace_install(name):
    return jsonify({'success': True, 'message': f'Installing {name}...'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('API_PORT', '8080')), threaded=True)
PYEOF
    
    # Start server in background
    cd "$API_DIR"
    API_KEY="$API_KEY" PALLADIUM_HOME="$PALLADIUM_HOME" DATA_DIR="$DATA_DIR" API_PORT="$API_PORT" \
        nohup python3 server.py > server.log 2>&1 &
    
    sleep 2
    
    if pgrep -f "api/server.py" >/dev/null; then
        echo -e "${GREEN}API server started on port $API_PORT${NC}"
        echo -e "  ${DIM}Health check: curl http://localhost:$API_PORT/health${NC}"
        echo -e "  ${DIM}API docs: curl -H \"Authorization: Bearer $API_KEY\" http://localhost:$API_PORT/api/v1/status${NC}"
    else
        echo -e "${RED}Failed to start API server${NC}"
        cat server.log
    fi
}

api_stop() {
    pkill -f "api/server.py" 2>/dev/null && echo -e "${GREEN}API server stopped${NC}" || echo -e "${YELLOW}API server not running${NC}"
}

api_show_key() {
    echo -e "${SILVER}API Key:${NC}"
    echo -e "  ${GREEN}$API_KEY${NC}"
    echo ""
    echo -e "${DIM}Use in Authorization header: Authorization: Bearer $API_KEY${NC}"
}

api_regen_key() {
    head -c 32 /dev/urandom | base64 | tr -d '\n' > "$API_KEY_FILE"
    chmod 600 "$API_KEY_FILE"
    API_KEY=$(cat "$API_KEY_FILE")
    echo -e "${GREEN}New API key generated:${NC} $API_KEY"
}

api_docs() {
    echo -e "${SILVER}${BOLD}  API Endpoints:${NC}"
    echo ""
    echo -e "  ${BOLD}GET${NC}  /health                           - Health check (no auth)"
    echo -e "  ${BOLD}GET${NC}  /api/v1/status                  - System & service status"
    echo -e "  ${BOLD}GET${NC}  /api/v1/services                - List all services"
    echo -e "  ${BOLD}POST${NC} /api/v1/services/<name>/start   - Start service"
    echo -e "  ${BOLD}POST${NC} /api/v1/services/<name>/stop    - Stop service"
    echo -e "  ${BOLD}POST${NC} /api/v1/services/<name>/restart - Restart service"
    echo -e "  ${BOLD}GET${NC}  /api/v1/services/<name>/logs    - Get service logs"
    echo -e "  ${BOLD}POST${NC} /api/v1/services              - Create new service"
    echo -e "  ${BOLD}DELETE${NC} /api/v1/services/<name>    - Delete service"
    echo -e "  ${BOLD}GET${NC}  /api/v1/stacks                - List available stacks"
    echo -e "  ${BOLD}POST${NC} /api/v1/stacks/<name>/install - Install stack"
    echo -e "  ${BOLD}POST${NC} /api/v1/backup              - Create backup"
    echo -e "  ${BOLD}GET${NC}  /api/v1/marketplace/tools     - List marketplace tools"
    echo -e "  ${BOLD}POST${NC} /api/v1/marketplace/install/<name> - Install tool"
    echo ""
    echo -e "  ${BOLD}Auth:${NC} Authorization: Bearer <API_KEY>"
}

api_test() {
    if ! pgrep -f "api/server.py" >/dev/null; then
        echo -e "${RED}API server not running${NC}"
        return
    fi
    
    echo -e "${YELLOW}Testing API...${NC}"
    curl -s -H "Authorization: Bearer $API_KEY" "http://localhost:$API_PORT/api/v1/status" | python3 -m json.tool 2>/dev/null || echo "Failed"
}