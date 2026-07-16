#!/bin/bash
# dashboard-tui.sh - Interactive terminal dashboard (Claude Code-style TUI)

server_dashboard() {
    local cols rows
    cols=$(tput cols 2>/dev/null || echo 90)
    rows=$(tput lines 2>/dev/null || echo 30)

    while true; do
        clear 2>/dev/null || true

        # ── HEADER ──────────────────────────────────────────────
        printf "\e[1;36m"
        printf "  ╔══════════════════════════════════════════════════════════════════════╗\n"
        printf "  ║                       PALLADIUM SERVER DASHBOARD                      ║\n"
        printf "  ╚══════════════════════════════════════════════════════════════════════╝\e[0m\n"
        echo ""

        # ── SYSTEM INFO ─────────────────────────────────────────
        local hostname=$(hostname 2>/dev/null || echo "unknown")
        local os
        os=$(detect_os 2>/dev/null || echo "unknown")
        local docker_status="\e[31mNot running\e[0m"
        local docker_icon="\e[31m●\e[0m"
        if docker info &>/dev/null 2>&1; then
            docker_status="\e[32mRunning\e[0m"
            docker_icon="\e[32m●\e[0m"
        fi
        local services_count=0
        local services_running=0
        for svc_dir in "$INSTALLED_DIR"/*/; do
            [ -d "$svc_dir" ] || continue
            ((services_count++))
            local name=$(basename "$svc_dir")
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$" 2>/dev/null; then
                ((services_running++))
            fi
        done

        printf "  \e[1mHost:\e[0m %-20s \e[1mOS:\e[0m %-10s \e[1mServices:\e[0m %d/%d  %s Docker\n" \
            "$hostname" "$os" "$services_running" "$services_count" "$docker_status"
        echo ""

        # ── SERVICES TABLE ──────────────────────────────────────
        printf "  \e[1m%-4s %-20s %-8s %-12s %s\e[0m\n" "#" "Service" "Status" "Port" "URL"
        printf "  \e[2m%-4s %-20s %-8s %-12s %s\e[0m\n" "────" "────────────────────" "────────" "────────────" "────────────────"

        local index=1
        for svc_dir in "$INSTALLED_DIR"/*/; do
            [ -d "$svc_dir" ] || continue
            local name=$(basename "$svc_dir")
            local status_icon="\e[31m●\e[0m"
            local status_text="\e[31mstopped\e[0m"
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$" 2>/dev/null; then
                status_icon="\e[32m●\e[0m"
                status_text="\e[32mrunning\e[0m"
            fi
            local port=""
            local port_file="$svc_dir/.port"
            [ -f "$port_file" ] && port=$(cat "$port_file")
            local url=""
            if [ -n "$port" ]; then
                url="http://localhost:$port"
            fi
            printf "  \e[1m[%2d]\e[0m %-20s %b %-4s %-12s %s\n" \
                "$index" "$name" "$status_icon" "$status_text" "$port" "$url"
            ((index++))
        done

        if [ "$services_count" -eq 0 ]; then
            printf "  \e[2m(no services installed — use Marketplace or Quick Start)\e[0m\n"
        fi
        echo ""

        # ── RESOURCE USAGE ──────────────────────────────────────
        printf "  \e[1mResources\e[0m\n"
        if command -v free &>/dev/null; then
            local mem_total mem_used mem_pct
            mem_total=$(free -m | awk '/^Mem:/ {print $2}')
            mem_used=$(free -m | awk '/^Mem:/ {print $3}')
            if [ -n "$mem_total" ] && [ "$mem_total" -gt 0 ]; then
                mem_pct=$((mem_used * 100 / mem_total))
                printf "  RAM   %s\e[0m %d%% (%d/%d MB)\n" "$(bar "$mem_pct" 20)" "$mem_pct" "$mem_used" "$mem_total"
            fi
        fi
        if command -v df &>/dev/null; then
            local disk_pct
            disk_pct=$(df -m "$PALLADIUM_HOME" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
            if [ -n "$disk_pct" ]; then
                printf "  Disk  %s\e[0m %d%%\n" "$(bar "$disk_pct" 20)" "$disk_pct"
            fi
        fi
        echo ""

        # ── COMMAND PROMPT (Claude Code style) ──────────────────
        printf "  \e[1;36m╭─\e[0m \e[2mPalladium CLI\e[0m\n"
        printf "  \e[1;36m├\e[0m  \e[2mCommands: status, start <n>, stop <n>, logs <n>, restart <n>, help, q\e[0m\n"
        printf "  \e[1;36m╰─\e[0m \e[1m>\e[0m "
        read -r cmd

        case "$cmd" in
            q|quit|exit)
                echo -e "${GREEN}  Goodbye!${NC}"
                break
                ;;
            help|?)
                echo ""
                echo -e "  ${SILVER}Commands:${NC}"
                echo -e "    ${BOLD}status${NC}           Show this dashboard"
                echo -e "    ${BOLD}start <n>${NC}        Start service by number"
                echo -e "    ${BOLD}stop <n>${NC}         Stop service by number"
                echo -e "    ${BOLD}restart <n>${NC}      Restart service by number"
                echo -e "    ${BOLD}logs <n>${NC}         Show logs for service"
                echo -e "    ${BOLD}open <n>${NC}         Open service in browser"
                echo -e "    ${BOLD}urls${NC}             Show all service URLs"
                echo -e "    ${BOLD}q${NC}                Quit dashboard"
                echo ""
                press_enter
                continue
                ;;
            status|refresh)
                continue
                ;;
            urls|url|links)
                echo ""
                show_lan_access 2>/dev/null || {
                    echo -e "  ${YELLOW}Network info unavailable in this session.${NC}"
                    for svc_dir in "$INSTALLED_DIR"/*/; do
                        [ -d "$svc_dir" ] || continue
                        local name=$(basename "$svc_dir")
                        local port_file="$svc_dir/.port"
                        if [ -f "$port_file" ]; then
                            local port=$(cat "$port_file")
                            echo -e "  ${GREEN}$name${NC}: http://localhost:$port"
                        fi
                    done
                }
                echo ""
                press_enter
                continue
                ;;
            start\ *)
                local num="${cmd#start }"
                local i=1
                for svc_dir in "$INSTALLED_DIR"/*/; do
                    [ -d "$svc_dir" ] || continue
                    if [ "$i" -eq "$num" ] 2>/dev/null; then
                        local name=$(basename "$svc_dir")
                        echo ""
                        svc_start "$name" 2>/dev/null || echo -e "${RED}  Failed to start $name${NC}"
                        press_enter
                        break
                    fi
                    ((i++))
                done
                [ $i -le "$num" ] 2>/dev/null && { echo -e "${RED}  Invalid number${NC}"; press_enter; }
                continue
                ;;
            stop\ *)
                local num="${cmd#stop }"
                local i=1
                for svc_dir in "$INSTALLED_DIR"/*/; do
                    [ -d "$svc_dir" ] || continue
                    if [ "$i" -eq "$num" ] 2>/dev/null; then
                        local name=$(basename "$svc_dir")
                        echo ""
                        svc_stop "$name" 2>/dev/null || echo -e "${RED}  Failed to stop $name${NC}"
                        press_enter
                        break
                    fi
                    ((i++))
                done
                continue
                ;;
            restart\ *)
                local num="${cmd#restart }"
                local i=1
                for svc_dir in "$INSTALLED_DIR"/*/; do
                    [ -d "$svc_dir" ] || continue
                    if [ "$i" -eq "$num" ] 2>/dev/null; then
                        local name=$(basename "$svc_dir")
                        echo ""
                        svc_stop "$name" 2>/dev/null
                        svc_start "$name" 2>/dev/null || echo -e "${RED}  Failed to restart $name${NC}"
                        press_enter
                        break
                    fi
                    ((i++))
                done
                continue
                ;;
            logs\ *)
                local num="${cmd#logs }"
                local i=1
                for svc_dir in "$INSTALLED_DIR"/*/; do
                    [ -d "$svc_dir" ] || continue
                    if [ "$i" -eq "$num" ] 2>/dev/null; then
                        local name=$(basename "$svc_dir")
                        echo ""
                        svc_logs "$name" 2>/dev/null || echo -e "${RED}  No logs for $name${NC}"
                        press_enter
                        break
                    fi
                    ((i++))
                done
                continue
                ;;
            open\ *)
                local num="${cmd#open }"
                local i=1
                for svc_dir in "$INSTALLED_DIR"/*/; do
                    [ -d "$svc_dir" ] || continue
                    if [ "$i" -eq "$num" ] 2>/dev/null; then
                        local name=$(basename "$svc_dir")
                        echo ""
                        open_service_url "$name" 2>/dev/null || echo -e "${YELLOW}  Cannot open $name${NC}"
                        press_enter
                        break
                    fi
                    ((i++))
                done
                continue
                ;;
            "")
                continue
                ;;
            *)
                echo ""
                echo -e "  ${YELLOW}Unknown command: ${BOLD}$cmd${NC}"
                echo -e "  ${DIM}Type ${SILVER}help${DIM} for available commands${NC}"
                sleep 1
                continue
                ;;
        esac
    done
}

bar() {
    local pct=$1 width=$2
    local filled=$((pct * width / 100))
    local empty=$((width - filled))
    local color="\e[32m"
    [ "$pct" -gt 80 ] && color="\e[31m"
    [ "$pct" -gt 50 ] && [ "$pct" -le 80 ] && color="\e[33m"
    printf "${color}"
    for ((i=0; i<filled; i++)); do printf "█"; done
    printf "\e[2m"
    for ((i=0; i<empty; i++)); do printf "░"; done
}
