#!/bin/bash
# monitor.sh - Resource monitoring, uptime tracking, alerts

MONITOR_DIR="$DATA_DIR/monitor"
mkdir -p "$MONITOR_DIR"

monitor_menu() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Monitoring ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Resource usage${NC}      CPU, RAM, disk"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Service status${NC}      Uptime for all services"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Live monitor${NC}        Real-time dashboard"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Set limits${NC}          CPU/RAM limits per service"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) resource_usage ;;
        2) service_uptime ;;
        3) live_monitor ;;
        4) set_limits ;;
        0) return ;;
    esac
}

resource_usage() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Resource Usage ═══${NC}"
    echo ""

    # CPU
    echo -e "${CYAN}CPU:${NC}"
    local cpu_usage=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' || echo "N/A")
    echo -e "  Usage: ${BOLD}${cpu_usage}%${NC}"
    echo ""

    # RAM
    echo -e "${CYAN}Memory:${NC}"
    free -h 2>/dev/null | awk 'NR==2{printf "  Used: %s / %s (%s free)\n", $3, $2, $4}'
    echo ""

    # Disk
    echo -e "${CYAN}Disk:${NC}"
    df -h 2>/dev/null | awk 'NR==2{printf "  Used: %s / %s (%s free, %s used)\n", $3, $2, $4, $5}'
    echo ""

    # Docker
    echo -e "${CYAN}Docker:${NC}"
    docker system df 2>/dev/null | awk 'NR>1{printf "  %s: %s used\n", $1, $3}'
    echo ""

    # Per-service resource usage
    echo -e "${CYAN}Per-service Docker usage:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null | head -20
    press_enter
}

service_uptime() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Service Uptime ═══${NC}"
    echo ""

    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        local port=""
        [ -f "$svc_dir/.port" ] && port=":$(cat "$svc_dir/.port")"

        local status="${RED}stopped${NC}"
        local uptime=""
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
            status="${GREEN}running${NC}"
            uptime=$(docker inspect --format '{{.State.StartedAt}}' "$name" 2>/dev/null)
            if [ -n "$uptime" ]; then
                local start_epoch=$(date -d "$uptime" +%s 2>/dev/null || echo 0)
                local now_epoch=$(date +%s)
                local diff=$((now_epoch - start_epoch))
                local hours=$((diff / 3600))
                local mins=$(( (diff % 3600) / 60 ))
                uptime=" (${hours}h ${mins}m)"
            fi
        fi

        echo -e "  $name  [$status]$uptime"
    done

    echo ""
    # Save status snapshot
    local snapshot_file="$MONITOR_DIR/status_$(date +%Y%m%d_%H%M%S).log"
    {
        echo "=== Palladium Status Snapshot ==="
        echo "Date: $(date)"
        echo ""
        for svc_dir in "$INSTALLED_DIR"/*/; do
            [ -d "$svc_dir" ] || continue
            local name=$(basename "$svc_dir")
            local status="stopped"
            docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$" && status="running"
            echo "$name: $status"
        done
    } > "$snapshot_file"

    press_enter
}

live_monitor() {
    echo -e "${CYAN}Live monitor (press Ctrl+C to exit)${NC}"
    echo ""

    while true; do
        clear 2>/dev/null || true
        echo -e "${CYAN}${BOLD}  ═══ Live Monitor ═══$(date +%H:%M:%S)═══${NC}"
        echo ""

        # System resources
        local cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' || echo "0")
        echo -e "  CPU: ${BOLD}${cpu}%${NC}"
        free -h 2>/dev/null | awk 'NR==2{printf "  RAM: %s / %s\n", $3, $2}'
        df -h 2>/dev/null | awk 'NR==2{printf "  Disk: %s / %s (%s)\n", $3, $2, $5}'
        echo ""

        # Services
        echo -e "  ${CYAN}Services:${NC}"
        for svc_dir in "$INSTALLED_DIR"/*/; do
            [ -d "$svc_dir" ] || continue
            local name=$(basename "$svc_dir")
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
                echo -e "  ${GREEN}  ●${NC} $name"
            else
                echo -e "  ${RED}  ○${NC} $name"
            fi
        done
        echo ""

        echo -e "  ${DIM}Refreshing every 5s... (Ctrl+C to exit)${NC}"
        sleep 5
    done
}

set_limits() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Resource Limits ═══${NC}"
    echo ""
    echo -e "  ${DIM}Set CPU and memory limits for services.${NC}"
    echo ""

    local services=()
    local i=1
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        services+=("$name")
        echo -e "  ${BOLD}[$i]${NC}  $name"
        ((i++))
    done

    [ ${#services[@]} -eq 0 ] && { echo -e "  ${DIM}No services.${NC}"; press_enter; return; }

    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select service: " choice
    [ "$choice" = "0" ] && return

    local selected="${services[$((choice-1))]}"
    echo ""

    local cpu_limit=$(prompt_value "  CPU limit (e.g. 0.5 = half core, 2 = 2 cores)" "0")
    local mem_limit=$(prompt_value "  Memory limit (e.g. 512m, 1g)" "0")

    local target="$INSTALLED_DIR/$selected"
    [ ! -f "$target/docker-compose.yml" ] && { echo -e "${RED}Not found.${NC}"; press_enter; return; }

    # Add deploy limits to docker-compose.yml
    if [ "$cpu_limit" != "0" ] || [ "$mem_limit" != "0" ]; then
        # Add deploy section
        cat >> "$target/docker-compose.yml" << EOF

  $selected:
    deploy:
      resources:
        limits:
EOF
        [ "$cpu_limit" != "0" ] && echo "          cpus: '$cpu_limit'" >> "$target/docker-compose.yml"
        [ "$mem_limit" != "0" ] && echo "          memory: $mem_limit" >> "$target/docker-compose.yml"

        echo -e "${GREEN}Limits set for $selected.${NC}"
        echo -e "${DIM}Restart the service to apply: palladium stop $selected && palladium start $selected${NC}"
    fi

    press_enter
}

set_service_limits() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Service Resource Limits ═══${NC}"
    echo ""

    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Docker not found.${NC}"
        press_enter
        return
    fi

    local services=()
    local i=1
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
            services+=("$name")
            echo -e "  ${BOLD}[$i]${NC}  ${GREEN}$name${NC} ${DIM}(running)${NC}"
            ((i++))
        fi
    done

    [ ${#services[@]} -eq 0 ] && { echo -e "  ${DIM}No running services.${NC}"; press_enter; return; }

    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select service: " choice
    [ "$choice" = "0" ] && return

    local selected="${services[$((choice-1))]}"
    echo ""

    local cpu_limit=$(prompt_value "  CPU limit (e.g. 0.5, 2.0)" "0")
    local mem_limit=$(prompt_value "  Memory limit (e.g. 512m, 1g)" "0")

    echo ""
    if [ "$cpu_limit" != "0" ] || [ "$mem_limit" != "0" ]; then
        local cmd="docker update"
        [ "$cpu_limit" != "0" ] && cmd="$cmd --cpus=$cpu_limit"
        [ "$mem_limit" != "0" ] && cmd="$cmd --memory=$mem_limit"
        cmd="$cmd $selected"

        echo -e "${YELLOW}Running: $cmd${NC}"
        if eval "$cmd" 2>/dev/null; then
            echo -e "${GREEN}Limits applied to $selected.${NC}"
        else
            echo -e "${RED}Failed to apply limits.${NC}"
        fi
    else
        echo -e "${YELLOW}No limits specified.${NC}"
    fi

    press_enter
}
