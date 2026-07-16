#!/bin/bash
# network.sh - LAN sharing, reverse proxy, domain management

network_menu() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Network & Sharing ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}LAN Access${NC}          Share services on your network"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Reverse Proxy${NC}       Nginx proxy manager"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Port Scanner${NC}        See what's running"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Network Info${NC}        IP, hostname, DNS"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) lan_access ;;
        2) reverse_proxy ;;
        3) port_scanner ;;
        4) network_info ;;
        0) return ;;
    esac
}

lan_access() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ LAN Access ═══${NC}"
    echo ""
    echo -e "  ${DIM}Make your services accessible from other devices.${NC}"
    echo ""

    local local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo -e "  ${GREEN}Your IP:${NC} $local_ip"
    echo ""

    echo -e "  ${BOLD}Running services:${NC}"
    echo ""
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        [ -f "$svc_dir/.port" ] || continue
        local port=$(cat "$svc_dir/.port")
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
            echo -e "  ${GREEN}$name${NC}"
            echo -e "    Local:   http://localhost:$port"
            echo -e "    Network: http://$local_ip:$port"
        fi
    done

    echo ""
    echo -e "  ${DIM}Other devices on your network can access these URLs.${NC}"
    echo -e "  ${DIM}Make sure your firewall allows the ports.${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  Open all service ports in firewall"
    echo -e "  ${BOLD}[2]${NC}  Generate QR code for LAN URL"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1)
            for svc_dir in "$INSTALLED_DIR"/*/; do
                [ -d "$svc_dir" ] || continue
                [ -f "$svc_dir/.port" ] || continue
                local port=$(cat "$svc_dir/.port")
                sudo ufw allow "$port" 2>/dev/null
            done
            echo -e "${GREEN}Ports opened.${NC}"
            press_enter
            ;;
        2)
            if command -v qrencode &>/dev/null; then
                local port=$(prompt_value "  Service port")
                qrencode -t ANSIUTF8 "http://$local_ip:$port" 2>/dev/null | sed 's/^/  /'
            else
                echo -e "${RED}Install qrencode first.${NC}"
            fi
            press_enter
            ;;
        0) return ;;
    esac
}

reverse_proxy() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Reverse Proxy ═══${NC}"
    echo ""
    echo -e "  ${DIM}Route traffic to your services with custom domains.${NC}"
    echo ""

    # Check if nginx proxy manager is running
    local has_proxy=false
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        if echo "$name" | grep -qi "proxy\|nginx"; then
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$name"; then
                has_proxy=true
                local port=$(cat "$svc_dir/.port" 2>/dev/null)
                echo -e "  ${GREEN}Proxy Manager running:${NC} http://localhost:$port"
            fi
        fi
    done

    if ! $has_proxy; then
        echo -e "  ${YELLOW}No reverse proxy installed.${NC}"
        echo ""
        echo -e "  ${BOLD}[1]${NC}  ${GREEN}Install Nginx Proxy Manager${NC} (recommended)"
        echo -e "  ${BOLD}[2]${NC}  ${GREEN}Install Traefik${NC}"
        echo -e "  ${BOLD}[0]${NC}  Back"
        echo ""
        read -p "  Select: " choice
        case $choice in
            1) marketplace_install_tool "nginx-proxy-manager" "jc21/nginx-proxy-manager:latest" "81" ;;
            2) marketplace_install_tool "traefik" "traefik:v3.0" "8080" ;;
            0) return ;;
        esac
        return
    fi

    echo ""
    echo -e "  ${BOLD}[1]${NC}  Open Proxy Manager"
    echo -e "  ${BOLD}[2]${NC}  Generate proxy config"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1)
            local port=""
            for svc_dir in "$INSTALLED_DIR"/*/; do
                [ -d "$svc_dir" ] || continue
                local name=$(basename "$svc_dir")
                if echo "$name" | grep -qi "proxy\|nginx"; then
                    port=$(cat "$svc_dir/.port" 2>/dev/null)
                    break
                fi
            done
            local url="http://localhost:$port"
            if command -v xdg-open &>/dev/null; then xdg-open "$url" 2>/dev/null &
            elif command -v chromium-browser &>/dev/null; then chromium-browser "$url" 2>/dev/null &
            fi
            press_enter
            ;;
        2) generate_proxy_config ;;
        0) return ;;
    esac
}

generate_proxy_config() {
    echo ""
    local service=$(prompt_value "  Service to proxy (e.g. n8n)")
    local domain=$(prompt_value "  Domain (e.g. n8n.local)")
    local port=$(prompt_value "  Service port" "5678")

    local config_file="$DATA_WORKSPACE/exports/proxy-${service}.conf"

    cat > "$config_file" << EOF
# Nginx Proxy Manager config for $service
# Import this into Nginx Proxy Manager UI

Domain: $domain
Forward Host: $service
Forward Port: $port
SSL: Let's Encrypt

# Or manual nginx config:
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://$service:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

    echo -e "${GREEN}Config saved: $config_file${NC}"
    echo ""
    echo -e "  ${DIM}Import this into Nginx Proxy Manager:${NC}"
    echo -e "  ${DIM}1. Open http://localhost:81${NC}"
    echo -e "  ${DIM}2. Add Proxy Host${NC}"
    echo -e "  ${DIM}3. Domain: $domain${NC}"
    echo -e "  ${DIM}4. Forward to: $service:$port${NC}"
    press_enter
}

port_scanner() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Port Scanner ═══${NC}"
    echo ""

    local local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo -e "  ${CYAN}Scanning localhost...${NC}"
    echo ""

    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        [ -f "$svc_dir/.port" ] || continue
        local port=$(cat "$svc_dir/.port")
        local status="${RED}closed${NC}"

        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
            if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null | grep -qE "200|301|302|401"; then
                status="${GREEN}open${NC}"
            else
                status="${YELLOW}listening${NC}"
            fi
        fi

        echo -e "  $name  port $port  [$status]"
    done

    echo ""
    echo -e "  ${CYAN}All listening ports:${NC}"
    ss -tlnp 2>/dev/null | grep -v "^State" | awk '{print "  " $4 " " $6}' | head -20
    press_enter
}

network_info() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Network Information ═══${NC}"
    echo ""

    echo -e "  ${CYAN}Interfaces:${NC}"
    ip addr show 2>/dev/null | grep -E "inet |^[0-9]" | awk '{print "  " $0}' | head -20
    echo ""

    echo -e "  ${CYAN}Default Gateway:${NC}"
    ip route 2>/dev/null | grep default | awk '{print "  " $0}'
    echo ""

    echo -e "  ${CYAN}DNS Servers:${NC}"
    cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print "  " $2}'
    echo ""

    echo -e "  ${CYAN}Public IP:${NC}"
    curl -s ifconfig.me 2>/dev/null && echo ""
    echo ""

    echo -e "  ${CYAN}Hostname:${NC}"
    echo "  $(hostname 2>/dev/null)"
    press_enter
}

reverse_proxy_menu() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Reverse Proxy Options ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Nginx Proxy Manager${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Traefik${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Caddy${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) marketplace_custom_install ;;
        2) echo -e "${YELLOW}Traefik support coming soon.${NC}" ;;
        3) echo -e "${YELLOW}Caddy support coming soon.${NC}" ;;
        0) return ;;
    esac
    press_enter
}

show_lan_access() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ LAN Access URLs ═══${NC}"
    echo ""

    local lan_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -z "$lan_ip" ]; then
        lan_ip=$(ip addr show 2>/dev/null | grep -E "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -1)
    fi

    if [ -z "$lan_ip" ]; then
        echo -e "${RED}Could not determine LAN IP.${NC}"
        press_enter
        return
    fi

    echo -e "  ${GREEN}Your LAN IP:${NC} $lan_ip"
    echo ""

    echo -e "  ${BOLD}Running services:${NC}"
    echo ""
    local found=false
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        [ -f "$svc_dir/.port" ] || continue
        local port=$(cat "$svc_dir/.port")
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
            found=true
            echo -e "  ${GREEN}$name${NC}"
            echo -e "    Local:   http://localhost:$port"
            echo -e "    Network: http://$lan_ip:$port"
            echo ""
        fi
    done

    if ! $found; then
        echo -e "  ${DIM}No running services found.${NC}"
    fi

    echo -e "  ${DIM}Other devices on your network can access these URLs.${NC}"
    press_enter
}
