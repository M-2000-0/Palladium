#!/bin/bash
main_menu() {
    while true; do
        # First-run welcome
        if [ ! -f "$PALLADIUM_HOME/.welcome_shown" ]; then
            clear 2>/dev/null || true
            echo ""
            echo -e "${SILVER}${BOLD}  ═══ Welcome to Palladium! ═══${NC}"
            echo ""
            echo -e "  ${GREEN}You're all set up and ready to go.${NC}"
            echo ""
            echo -e "  ${BOLD}Quick start:${NC}"
            echo -e "  ${DIM}  [1] Pre-built stacks  → One-click n8n + database${NC}"
            echo -e "  ${DIM}  [4] Marketplace       → Browse 20+ self-hosted tools${NC}"
            echo -e "  ${DIM}  [5] AI Toolkit        → Local LLMs and API connectors${NC}"
            echo ""
            echo -e "  ${DIM}Type '${SILVER}t${DIM}' to install Docker, Git, and other tools.${NC}"
            echo ""
            press_enter
            touch "$PALLADIUM_HOME/.welcome_shown"
        fi

        local running=0
        local docker_ok=false
        if find_docker_cli &> /dev/null && docker info &> /dev/null 2>&1; then
            docker_ok=true
            running=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
        fi

        local drive_label=""
        local drives
        drives=$(detect_usb_drive 2>/dev/null)
        if [ -n "$drives" ]; then
            local first_mount=$(echo "$drives" | head -1 | cut -d'|' -f1)
            local drive_type=$(get_drive_type "$first_mount" "$(df -m "$first_mount" 2>/dev/null | awk 'NR==2 {print $2}')")
            if [ "$drive_type" = "usb" ]; then
                drive_label=" ${YELLOW}[USB]${NC}"
            elif [ "$drive_type" = "ssd" ]; then
                drive_label=" ${GREEN}[SSD]${NC}"
            fi
        fi

        clear 2>/dev/null || true

        # Banner
        echo ""
        echo -e "${SILVER}${BOLD}██████╗  █████╗ ██╗     ██╗      █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗${NC}"
        echo -e "${SILVER}${BOLD}██╔══██╗██╔══██╗██║     ██║     ██╔══██╗██╔══██╗██║██║   ██║████╗ ████║${NC}"
        echo -e "${SILVER}${BOLD}██████╔╝███████║██║     ██║     ███████║██║  ██║██║██║   ██║██╔████╔██║${NC}"
        echo -e "${SILVER}${BOLD}██╔═══╝ ██╔══██║██║     ██║     ██╔══██║██║  ██║██║██║   ██║██║╚██╔╝██║${NC}"
        echo -e "${SILVER}${BOLD}██║     ██║  ██║███████╗███████╗██║  ██║██████╔╝██║╚██████╔╝██║ ╚═╝ ██║${NC}"
        echo -e "${SILVER}${BOLD}╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚═╝ ╚═════╝ ╚═╝     ╚═╝${NC}"
        echo -e "${DIM}  Portable Server Manager — Plug in. Power up. Host anything.${NC}"
        echo ""

        # Menu items: 2-column column-major grid
        local items=(
            "1:Pre-built stacks"
            "2:Install a service"
            "3:Manage services"
            "4:Marketplace"
            "5:AI Toolkit"
            "6:Data Dashboard"
            "7:Supabase"
            "8:Security & encryption"
            "9:Network & access"
            "10:Monitoring & limits"
            "11:Updates & versions"
            "12:Notifications & alerts"
            "13:Profiles & users"
            "14:Backup & restore"
            "15:Clone & migrate"
            "16:Drives & install"
            "17:Tutorials"
            "0:Exit"
        )
        local total=${#items[@]}
        local rows=$(( (total + 1) / 2 ))

        for row in $(seq 0 $((rows - 1))); do
            local left_item="${items[$row]}"
            local left_num="${left_item%%:*}"
            local left_label="${left_item#*:}"
            printf "  ${BOLD}[%2s]${NC}  %-26s" "$left_num" "$left_label"

            local right_idx=$((row + rows))
            if [ $right_idx -lt $total ]; then
                local right_item="${items[$right_idx]}"
                local right_num="${right_item%%:*}"
                local right_label="${right_item#*:}"
                printf "${BOLD}[%2s]${NC}  %s" "$right_num" "$right_label"
            fi
            printf "\n"
        done

        echo ""
        if $docker_ok; then
            echo -e "  ${GREEN}Docker: Running${NC}  |  ${SILVER}Services: $running active${NC}$drive_label"
        else
            echo -e "  ${RED}Docker: Not running${NC}  |  ${YELLOW}Install from Settings${NC}$drive_label"
        fi
        echo -e "  ${DIM}Type '${SILVER}t${DIM}' tools  '${SILVER}d${DIM}' dashboard${NC}"
        echo ""
        read -p "  Select option: " choice
        case $choice in
            1)  stacks_menu ;;
            2)  install_menu ;;
            3)  manage_menu ;;
            4)  marketplace_browse ;;
            5)  ai_menu ;;
            6)  dashboard_launch ;;
            7)  supabase_menu ;;
            8)  security_menu ;;
            9)  network_menu ;;
            10) monitor_menu ;;
            11) updates_menu ;;
            12) notify_menu ;;
            13) profiles_menu ;;
            14) backup_menu ;;
            15) clone_menu ;;
            16) tools_menu ;;
            17) tutorials_menu ;;
            d|D) server_dashboard ;;
            t|T) install_tools ;;
            0|q|Q) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *)  echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

stacks_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Quick Start Stacks ═══${NC}"
    echo ""
    echo -e "  ${DIM}One click. Complete setup. No configuration needed.${NC}"
    echo ""

    if ! check_docker_available 2>/dev/null; then
        echo -e "${RED}  Docker is required. Install it from the main menu.${NC}"
        press_enter; return
    fi

    local drives
    drives=$(detect_usb_drive 2>/dev/null)
    if [ -n "$drives" ]; then
        local first_mount=$(echo "$drives" | head -1 | cut -d'|' -f1)
        check_usb_storage "$first_mount" || { press_enter; return; }
    else
        check_storage "$PALLADIUM_HOME" 2>/dev/null || { press_enter; return; }
    fi

    local stacks=()
    local i=1
    for stack_file in "$STACK_DIR"/*.stack; do
        [ -f "$stack_file" ] || continue
        local name=$(basename "$stack_file" .stack)
        local desc=$(grep "^# desc:" "$stack_file" | head -1 | sed 's/^# desc: //')
        local services=$(grep "^# services:" "$stack_file" | head -1 | sed 's/^# services: //')
        stacks+=("$name")

        local usb_hint=""
        if [ "${PALLADIUM_MODE:-ssd}" = "usb" ]; then
            local svc_count=$(echo "$services" | tr ',' '\n' | wc -l)
            [ "$svc_count" -gt 2 ] && usb_hint=" ${YELLOW}(heavy for USB)${NC}"
        fi

        echo -e "  ${BOLD}[$i]${NC}  ${GREEN}$name${NC}$usb_hint"
        echo -e "        ${DIM}$desc${NC}"
        echo -e "        ${DIM}→ $services${NC}"
        ((i++))
    done
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select stack: " choice
    if [ "$choice" = "0" ]; then return; fi
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#stacks[@]}" ]; then
        stack_install "${stacks[$((choice-1))]}"
    else
        echo -e "${RED}Invalid option${NC}"; sleep 1
    fi
}

install_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Install a Service ═══${NC}"
    echo ""

    if ! check_docker_available 2>/dev/null; then
        echo -e "${RED}  Docker is required. Install it from the main menu.${NC}"
        press_enter; return
    fi

    local services=()
    local i=1
    for svc_file in "$SERVICES_DIR"/*.yml; do
        [ -f "$svc_file" ] || continue
        local name=$(basename "$svc_file" .yml)
        local desc=$(grep "^# desc:" "$svc_file" 2>/dev/null | head -1 | sed 's/^# desc: //')
        services+=("$name")
        echo -e "  ${BOLD}[$i]${NC}  ${GREEN}$name${NC}  -  ${DIM}$desc${NC}"
        ((i++))
    done
    echo -e "  ${BOLD}[$i]${NC}  ${MAGENTA}custom${NC}  -  ${DIM}Deploy any Docker image${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select service to install: " choice
    if [ "$choice" = "0" ]; then return; fi
    if [ "$choice" = "$i" ]; then
        wizard_custom
    elif [ "$choice" -ge 1 ] && [ "$choice" -le "${#services[@]}" ]; then
        wizard_install "${services[$((choice-1))]}"
    else
        echo -e "${RED}Invalid option${NC}"; sleep 1
    fi
}

manage_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Manage Services ═══${NC}"
    echo ""
    local installed=()
    local i=1
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        local status="${RED}stopped${NC}"
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
            status="${GREEN}running${NC}"
        fi
        local port=""
        [ -f "$svc_dir/.port" ] && port=" (port $(cat "$svc_dir/.port"))"
        installed+=("$name")
        echo -e "  ${BOLD}[$i]${NC}  $name  [$status]$port"
        ((i++))
    done
    if [ ${#installed[@]} -eq 0 ]; then
        echo -e "  ${DIM}No services installed yet.${NC}"
        echo -e "  ${DIM}Try [1] Quick Start or [4] Marketplace!${NC}"
        press_enter; return
    fi
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select service: " choice
    if [ "$choice" = "0" ] || [ -z "$choice" ]; then return; fi
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#installed[@]}" ]; then
        service_action_menu "${installed[$((choice-1))]}"
    fi
}

service_action_menu() {
    local svc="$1"
    while true; do
        clear 2>/dev/null || true
        echo -e "${SILVER}${BOLD}  ═══ $svc ═══${NC}"
        echo ""

        local port_file="$INSTALLED_DIR/$svc/.port"
        if [ -f "$port_file" ]; then
            local port=$(cat "$port_file")
            local local_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
            echo -e "  ${DIM}Local:   http://localhost:$port${NC}"
            echo -e "  ${DIM}Network: http://$local_ip:$port${NC}"
            echo ""
        fi

        echo -e "  ${BOLD}[1]${NC}  Start"
        echo -e "  ${BOLD}[2]${NC}  Stop"
        echo -e "  ${BOLD}[3]${NC}  Restart"
        echo -e "  ${BOLD}[4]${NC}  Open in browser"
        echo -e "  ${BOLD}[5]${NC}  View logs"
        echo -e "  ${BOLD}[6]${NC}  Backup this service"
        echo -e "  ${BOLD}[7]${NC}  Set resource limits"
        echo -e "  ${BOLD}[8]${NC}  Remove"
        echo -e "  ${BOLD}[0]${NC}  Back"
        echo ""
        read -p "  Select action: " choice
        case $choice in
            1) svc_start "$svc"; press_enter ;;
            2) svc_stop "$svc"; press_enter ;;
            3) svc_stop "$svc" 2>/dev/null; svc_start "$svc"; press_enter ;;
            4) open_service_url "$svc"; press_enter ;;
            5) svc_logs "$svc"; press_enter ;;
            6) backup_single "$svc"; press_enter ;;
            7) set_service_limits "$svc"; press_enter ;;
            8) if confirm "  Remove $svc?" "n"; then svc_remove "$svc"; return; fi ;;
            0|q|Q) return ;;
            *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
        esac
    done
}

open_service_url() {
    local svc="$1"
    local port_file="$INSTALLED_DIR/$svc/.port"
    if [ ! -f "$port_file" ]; then
        echo -e "${RED}No port configured.${NC}"
        return
    fi
    local port=$(cat "$port_file")
    local url="http://localhost:$port"

    echo -e "${GREEN}Opening $url...${NC}"
    if command -v xdg-open &>/dev/null; then xdg-open "$url" 2>/dev/null &
    elif command -v open &>/dev/null; then open "$url" 2>/dev/null &
    elif command -v google-chrome &>/dev/null; then google-chrome "$url" 2>/dev/null &
    elif command -v chromium-browser &>/dev/null; then chromium-browser "$url" 2>/dev/null &
    fi

    show_qr "$url"
}

show_qr() {
    local url="$1"
    if command -v qrencode &>/dev/null; then
        echo ""
        echo -e "${SILVER}  Scan for mobile access:${NC}"
        qrencode -t ANSIUTF8 "$url" 2>/dev/null | sed 's/^/  /'
        echo ""
    fi
}

tools_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Drives & Install ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  View drive information"
    echo -e "  ${BOLD}[2]${NC}  Install Palladium to a USB/SSD"
    echo -e "  ${BOLD}[3]${NC}  View logs"
    echo -e "  ${BOLD}[4]${NC}  Cleanup & settings"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) show_usb_info ;;
        2) install_palladium_to_drive ;;
        3) logs_menu ;;
        4) settings_menu ;;
        0) return ;;
    esac
}

install_palladium_to_drive() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Install to USB/SSD ═══${NC}"
    echo ""

    show_usb_info

    local target=$(prompt_value "  Target path (e.g. /media/user/MYUSB)")
    [ -z "$target" ] && return

    if [ ! -d "$target" ]; then
        echo -e "${RED}Directory not found: $target${NC}"
        press_enter; return
    fi

    check_usb_storage "$target" || { press_enter; return; }

    echo ""
    install_to_drive "$target"
}

backup_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Backup & Restore ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  Backup all services"
    echo -e "  ${BOLD}[2]${NC}  Restore from backup"
    echo -e "  ${BOLD}[3]${NC}  List backups"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) backup_all ;;
        2) restore_backup ;;
        3) list_backups; press_enter ;;
        0) return ;;
    esac
}

security_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Security & Encryption ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  Secrets manager (store API keys, passwords)"
    echo -e "  ${BOLD}[2]${NC}  Password audit (check strength)"
    echo -e "  ${BOLD}[3]${NC}  Firewall (UFW) setup"
    echo -e "  ${BOLD}[4]${NC}  Generate self-signed HTTPS certs"
    echo -e "  ${BOLD}[5]${NC}  Security scan (score /100)"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) secrets_menu ;;
        2) password_audit ;;
        3) firewall_setup ;;
        4) generate_https_certs ;;
        5) security_scan ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
}

network_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Network & Access ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  Show LAN access URLs for all services"
    echo -e "  ${BOLD}[2]${NC}  Reverse proxy setup (Nginx/Traefik)"
    echo -e "  ${BOLD}[3]${NC}  Port scanner (find open ports)"
    echo -e "  ${BOLD}[4]${NC}  Network info (IP, interfaces)"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) show_lan_access ;;
        2) reverse_proxy_menu ;;
        3) port_scanner ;;
        4) network_info ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
}

monitor_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Monitoring & Limits ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  Resource usage (CPU, RAM, disk)"
    echo -e "  ${BOLD}[2]${NC}  Service uptime & health"
    echo -e "  ${BOLD}[3]${NC}  Live monitor (auto-refresh)"
    echo -e "  ${BOLD}[4]${NC}  Set CPU/RAM limits for a service"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) resource_usage ;;
        2) service_uptime ;;
        3) live_monitor ;;
        4) limits_menu ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
}

updates_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Updates & Versions ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  Check for Palladium updates"
    echo -e "  ${BOLD}[2]${NC}  Update Palladium"
    echo -e "  ${BOLD}[3]${NC}  Update Docker images"
    echo -e "  ${BOLD}[4]${NC}  Update all services"
    echo -e "  ${BOLD}[5]${NC}  Version info"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) check_updates ;;
        2) update_palladium ;;
        3) update_docker_images ;;
        4) update_all_services ;;
        5) version_info; press_enter ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
}

notify_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Notifications & Alerts ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  Configure Telegram notifications"
    echo -e "  ${BOLD}[2]${NC}  Configure email notifications"
    echo -e "  ${BOLD}[3]${NC}  Set up service watch (alert on down)"
    echo -e "  ${BOLD}[4]${NC}  View alert history"
    echo -e "  ${BOLD}[5]${NC}  Test notifications"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) notify_setup_telegram ;;
        2) notify_setup_email ;;
        3) notify_setup_watch ;;
        4) notify_history ;;
        5) notify_test ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
}

profiles_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Profiles & Users ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  Switch profile"
    echo -e "  ${BOLD}[2]${NC}  Create new profile"
    echo -e "  ${BOLD}[3]${NC}  Export profile"
    echo -e "  ${BOLD}[4]${NC}  Import profile"
    echo -e "  ${BOLD}[5]${NC}  Manage SSH users"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) profile_switch ;;
        2) profile_create ;;
        3) profile_export ;;
        4) profile_import ;;
        5) profile_manage_users ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
}

clone_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Clone & Migrate ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  Clone Palladium to another drive"
    echo -e "  ${BOLD}[2]${NC}  Clone from another drive"
    echo -e "  ${BOLD}[3]${NC}  Full backup (all data, configs, images)"
    echo -e "  ${BOLD}[4]${NC}  Full restore from backup"
    echo -e "  ${BOLD}[5]${NC}  Compare two drives"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) clone_to_drive ;;
        2) clone_from_drive ;;
        3) full_backup ;;
        4) full_restore ;;
        5) compare_drives ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
}

limits_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Set Resource Limits ═══${NC}"
    echo ""

    local installed=()
    local i=1
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        installed+=("$(basename "$svc_dir")")
        echo -e "  ${BOLD}[$i]${NC}  $(basename "$svc_dir")"
        ((i++))
    done
    if [ ${#installed[@]} -eq 0 ]; then echo -e "  ${DIM}No services installed.${NC}"; press_enter; return; fi
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select service: " choice
    if [ "$choice" = "0" ] || [ -z "$choice" ]; then return; fi
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#installed[@]}" ]; then
        set_service_limits "${installed[$((choice-1))]}"
    fi
}

logs_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ View Logs ═══${NC}"
    echo ""
    local installed=()
    local i=1
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        installed+=("$(basename "$svc_dir")")
        echo -e "  ${BOLD}[$i]${NC}  $(basename "$svc_dir")"
        ((i++))
    done
    if [ ${#installed[@]} -eq 0 ]; then echo -e "  ${DIM}No services installed.${NC}"; press_enter; return; fi
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select service: " choice
    if [ "$choice" = "0" ] || [ -z "$choice" ]; then return; fi
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#installed[@]}" ]; then
        svc_logs "${installed[$((choice-1))]}"
    fi
}

settings_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Cleanup & Settings ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  Install Docker"
    echo -e "  ${BOLD}[2]${NC}  Install qrencode (QR codes)"
    echo -e "  ${BOLD}[3]${NC}  Quick cleanup (remove unused images)"
    echo -e "  ${BOLD}[4]${NC}  Full cleanup (remove ALL Docker data)"
    echo -e "  ${BOLD}[5]${NC}  Docker status"
    echo -e "  ${BOLD}[6]${NC}  Disk usage"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) install_docker; press_enter ;;
        2) sudo apt install -y qrencode 2>/dev/null && echo -e "${GREEN}qrencode installed.${NC}" || echo -e "${RED}Failed.${NC}"; press_enter ;;
        3) cleanup_all; press_enter ;;
        4) cleanup_docker_full; press_enter ;;
        5) echo ""; docker info 2>/dev/null || echo -e "${RED}Docker not running${NC}"; press_enter ;;
        6) echo ""; df -h 2>/dev/null; echo ""; echo -e "${SILVER}Palladium services:${NC}"; du -sh "$INSTALLED_DIR"/*/ 2>/dev/null | sort -rh; press_enter ;;
        0) return ;;
    esac
}

show_help() {
    show_banner
    echo -e "${SILVER}Commands:${NC}"
    echo "  palladium                  Launch interactive menu"
    echo "  palladium launch <name>    Install + start in one command"
    echo "  palladium stack            Install a pre-built stack"
    echo "  palladium install          Install a single service"
    echo "  palladium start <name>     Start a service"
    echo "  palladium stop <name>      Stop a service"
    echo "  palladium marketplace      Browse marketplace"
    echo "  palladium ai               AI toolkit"
    echo "  palladium data             Data workspace"
    echo "  palladium dashboard        Data dashboard"
    echo "  palladium supabase         Supabase integration"
    echo "  palladium security         Security & encryption"
    echo "  palladium network          Network & access"
    echo "  palladium monitor          Monitoring & limits"
    echo "  palladium updates          Updates & versions"
    echo "  palladium notify           Notifications & alerts"
    echo "  palladium profile          Profiles & users"
    echo "  palladium clone            Clone & migrate"
    echo "  palladium tutorials        In-app tutorials"
    echo "  palladium drive            View drive information"
    echo "  palladium install-to       Install to USB/SSD"
    echo "  palladium backup           Backup all services"
    echo "  palladium restore          Restore from backup"
    echo "  palladium cleanup          Free up Docker space"
    echo "  palladium setup-autorun    Enable plug-and-play on USB"
    echo "  palladium install-tools    Install Git, Docker, Python, Node.js, curl & more"
    echo "  palladium dashboard        Live server dashboard (Claude Code-style TUI)"
    echo ""
}