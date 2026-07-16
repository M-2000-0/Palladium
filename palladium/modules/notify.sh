#!/bin/bash
# notify.sh - Notifications and alerts

NOTIFY_CONFIG="$DATA_DIR/notify.conf"

notify_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Notifications ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Setup notifications${NC}   Email or Telegram"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Test notifications${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Service watch${NC}        Alert when service goes down"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}View alerts${NC}          Recent notifications"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) setup_notifications ;;
        2) test_notification ;;
        3) service_watch ;;
        4) view_alerts ;;
        0) return ;;
    esac
}

setup_notifications() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Setup Notifications ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Telegram${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Email (SMTP)${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) setup_telegram ;;
        2) setup_email ;;
        0) return ;;
    esac
}

setup_telegram() {
    echo ""
    echo -e "${DIM}To get your Telegram bot token:${NC}"
    echo -e "${DIM}1. Message @BotFather on Telegram${NC}"
    echo -e "${DIM}2. Send /newbot${NC}"
    echo -e "${DIM}3. Copy the token${NC}"
    echo ""

    local bot_token=$(prompt_password "  Bot token")
    local chat_id=$(prompt_value "  Chat ID (message @userinfobot)")
    [ -z "$bot_token" ] || [ -z "$chat_id" ] && return

    cat > "$NOTIFY_CONFIG" << EOF
METHOD=telegram
BOT_TOKEN=$bot_token
CHAT_ID=$chat_id
EOF

    chmod 600 "$NOTIFY_CONFIG"
    echo -e "${GREEN}Telegram notifications configured!${NC}"
    press_enter
}

setup_email() {
    echo ""
    local smtp_host=$(prompt_value "  SMTP host (e.g. smtp.gmail.com)")
    local smtp_port=$(prompt_value "  SMTP port" "587")
    local smtp_user=$(prompt_value "  Email address")
    local smtp_pass=$(prompt_password "  Email password/app password")
    local to_email=$(prompt_value "  Send to (email address)")

    cat > "$NOTIFY_CONFIG" << EOF
METHOD=email
SMTP_HOST=$smtp_host
SMTP_PORT=$smtp_port
SMTP_USER=$smtp_user
SMTP_PASS=$smtp_pass
TO_EMAIL=$to_email
EOF

    chmod 600 "$NOTIFY_CONFIG"
    echo -e "${GREEN}Email notifications configured!${NC}"
    press_enter
}

send_notification() {
    local message="$1"
    local title="${2:-Palladium Alert}"

    if [ ! -f "$NOTIFY_CONFIG" ]; then return 1; fi

    source "$NOTIFY_CONFIG"

    case "$METHOD" in
        telegram)
            curl -s "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
                -d "chat_id=$CHAT_ID" \
                -d "text=$title: $message" \
                -d "parse_mode=HTML" 2>/dev/null
            ;;
        email)
            echo -e "Subject: $title\n\n$message" | \
                sendmail -S "$SMTP_HOST:$SMTP_PORT" -au "$SMTP_USER" -ap "$SMTP_PASS" "$TO_EMAIL" 2>/dev/null
            ;;
    esac
}

test_notification() {
    if [ ! -f "$NOTIFY_CONFIG" ]; then
        echo -e "${RED}No notifications configured.${NC}"
        press_enter; return
    fi

    echo -e "${YELLOW}Sending test notification...${NC}"
    send_notification "Test notification from Palladium. If you see this, notifications are working!" "Test"
    echo -e "${GREEN}Test sent!${NC}"
    press_enter
}

service_watch() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Service Watch ═══${NC}"
    echo ""
    echo -e "  ${DIM}Monitor services and alert when they go down.${NC}"
    echo ""

    local services=()
    local i=1
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        services+=("$name")
        local watching=""
        [ -f "$MONITOR_DIR/watch_$name" ] && watching=" ${GREEN}[watching]${NC}"
        echo -e "  ${BOLD}[$i]${NC}  $name$watching"
        ((i++))
    done

    [ ${#services[@]} -eq 0 ] && { echo -e "  ${DIM}No services.${NC}"; press_enter; return; }

    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Toggle watch for service: " choice
    [ "$choice" = "0" ] && return

    local selected="${services[$((choice-1))]}"
    local watch_file="$MONITOR_DIR/watch_$selected"

    if [ -f "$watch_file" ]; then
        rm -f "$watch_file"
        echo -e "${YELLOW}Stopped watching $selected${NC}"
    else
        touch "$watch_file"
        echo -e "${GREEN}Now watching $selected${NC}"
    fi

    press_enter
}

check_service_health() {
    # Called periodically to check watched services
    [ ! -f "$NOTIFY_CONFIG" ] && return

    for watch_file in "$MONITOR_DIR"/watch_*; do
        [ -f "$watch_file" ] || continue
        local name=$(basename "$watch_file" | sed 's/^watch_//')

        if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
            send_notification "Service '$name' is DOWN!" "Service Alert"
            echo "$name DOWN $(date)" >> "$MONITOR_DIR/alerts.log"
        fi
    done
}

view_alerts() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Recent Alerts ═══${NC}"
    echo ""

    if [ -f "$MONITOR_DIR/alerts.log" ]; then
        tail -20 "$MONITOR_DIR/alerts.log" 2>/dev/null | while read -r line; do
            echo -e "  ${RED}$line${NC}"
        done
    else
        echo -e "  ${DIM}No alerts yet.${NC}"
    fi

    press_enter
}

notify_setup_telegram() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Telegram Setup ═══${NC}"
    echo ""

    echo -e "  ${DIM}Create a bot with @BotFather on Telegram,${NC}"
    echo -e "  ${DIM}then enter the token and your chat ID.${NC}"
    echo ""

    local bot_token=$(prompt_password "  Bot token")
    local chat_id=$(prompt_value "  Chat ID")
    [ -z "$bot_token" ] || [ -z "$chat_id" ] && return

    mkdir -p "$DATA_DIR/notify"
    cat > "$DATA_DIR/notify/telegram.conf" << EOF
BOT_TOKEN=$bot_token
CHAT_ID=$chat_id
EOF

    chmod 600 "$DATA_DIR/notify/telegram.conf"
    echo -e "${GREEN}Telegram configured.${NC}"
    press_enter
}

notify_setup_email() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Email Setup ═══${NC}"
    echo ""

    local smtp_host=$(prompt_value "  SMTP server")
    local smtp_port=$(prompt_value "  SMTP port" "587")
    local smtp_user=$(prompt_value "  Username")
    local smtp_pass=$(prompt_password "  Password")
    local from_addr=$(prompt_value "  From address")
    local to_addr=$(prompt_value "  To address")

    mkdir -p "$DATA_DIR/notify"
    cat > "$DATA_DIR/notify/email.conf" << EOF
SMTP_HOST=$smtp_host
SMTP_PORT=$smtp_port
SMTP_USER=$smtp_user
SMTP_PASS=$smtp_pass
FROM_ADDR=$from_addr
TO_ADDR=$to_addr
EOF

    chmod 600 "$DATA_DIR/notify/email.conf"
    echo -e "${GREEN}Email configured.${NC}"
    press_enter
}

notify_setup_watch() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Setup Service Watch ═══${NC}"
    echo ""

    local services=()
    local i=1
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        services+=("$name")
        echo -e "  ${BOLD}[$i]${NC}  ${GREEN}$name${NC}"
        ((i++))
    done

    [ ${#services[@]} -eq 0 ] && { echo -e "  ${DIM}No services.${NC}"; press_enter; return; }

    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select service: " choice
    [ "$choice" = "0" ] && return

    local selected="${services[$((choice-1))]}"
    mkdir -p "$DATA_DIR/notify/watches"
    cat > "$DATA_DIR/notify/watches/$selected.conf" << EOF
service=$selected
enabled=true
EOF

    echo -e "${GREEN}Watch configured for $selected.${NC}"
    press_enter
}

notify_history() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Notification History ═══${NC}"
    echo ""

    local logs=()
    for f in "$DATA_DIR/notify"/*.log; do
        [ -f "$f" ] || continue
        logs+=("$f")
    done

    if [ ${#logs[@]} -eq 0 ]; then
        echo -e "  ${DIM}No notification logs found.${NC}"
    else
        for log in "${logs[@]}"; do
            echo -e "${SILVER}File: $(basename "$log")${NC}"
            tail -20 "$log" 2>/dev/null | sed 's/^/  /'
            echo ""
        done
    fi

    press_enter
}

notify_test() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Test Notifications ═══${NC}"
    echo ""

    local tested=false

    if [ -f "$DATA_DIR/notify/telegram.conf" ]; then
        source "$DATA_DIR/notify/telegram.conf"
        echo -e "${YELLOW}Sending test Telegram message...${NC}"
        curl -s -o /dev/null "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d "chat_id=$CHAT_ID" \
            -d "text=Test notification from Palladium" 2>/dev/null && \
        echo -e "${GREEN}Telegram test sent.${NC}" || \
        echo -e "${RED}Telegram test failed.${NC}"
        tested=true
    fi

    if [ -f "$DATA_DIR/notify/email.conf" ]; then
        echo -e "${YELLOW}Sending test email...${NC}"
        source "$DATA_DIR/notify/email.conf"
        echo -e "Subject: Palladium Test\n\nThis is a test notification." | \
            curl -s --ssl-reqd --mail-from "$FROM_ADDR" --mail-rcpt "$TO_ADDR" \
            --user "$SMTP_USER:$SMTP_PASS" \
            -T - "smtp://$SMTP_HOST:$SMTP_PORT" 2>/dev/null && \
        echo -e "${GREEN}Email test sent.${NC}" || \
        echo -e "${RED}Email test failed.${NC}"
        tested=true
    fi

    if ! $tested; then
        echo -e "${YELLOW}No notification methods configured.${NC}"
        echo -e "  ${DIM}Run setup notifications first.${NC}"
    fi

    press_enter
}
