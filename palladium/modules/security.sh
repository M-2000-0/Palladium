#!/bin/bash
# security.sh - Firewall, secrets, HTTPS, password management

SECRETS_FILE="$DATA_DIR/.secrets"

security_menu() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Security ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Secrets Manager${NC}     Store API keys, passwords securely"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Password audit${NC}      Check for weak/default passwords"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Firewall${NC}            Open/close ports"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}HTTPS setup${NC}         SSL/TLS certificates"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}Scan for issues${NC}     Full security checkup"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) secrets_manager ;;
        2) password_audit ;;
        3) firewall_setup ;;
        4) https_setup ;;
        5) security_scan ;;
        0) return ;;
    esac
}

secrets_manager() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Secrets Manager ═══${NC}"
    echo ""
    echo -e "  ${DIM}Store API keys, passwords, and tokens securely.${NC}"
    echo -e "  ${DIM}Encrypted with your master password.${NC}"
    echo ""

    if [ ! -f "$SECRETS_FILE" ]; then
        echo -e "  ${YELLOW}No vault found. Let's create one.${NC}"
        echo ""
        local master=$(prompt_password "  Create master password")
        [ -z "$master" ] && return
        echo "$master" | openssl enc -aes-256-cbc -salt -out "$SECRETS_FILE" 2>/dev/null <<< ""
        echo "# Palladium Secrets Vault" > /tmp/secrets_plain
        echo "# Master: $master" >> /tmp/secrets_plain
        cat /tmp/secrets_plain | openssl enc -aes-256-cbc -salt -pass "pass:$master" -out "$SECRETS_FILE" 2>/dev/null
        rm -f /tmp/secrets_plain
        chmod 600 "$SECRETS_FILE"
        echo -e "${GREEN}Vault created!${NC}"
    fi

    echo ""
    echo -e "  ${BOLD}[1]${NC}  Add secret"
    echo -e "  ${BOLD}[2]${NC}  List secrets"
    echo -e "  ${BOLD}[3]${NC}  Get secret"
    echo -e "  ${BOLD}[4]${NC}  Delete secret"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) secrets_add ;;
        2) secrets_list ;;
        3) secrets_get ;;
        4) secrets_delete ;;
        0) return ;;
    esac
}

secrets_add() {
    local master=$(prompt_password "  Master password")
    local key=$(prompt_value "  Secret name (e.g. OPENAI_API_KEY)")
    local value=$(prompt_password "  Secret value")
    [ -z "$key" ] || [ -z "$value" ] && return

    # Decrypt, add, re-encrypt
    openssl enc -aes-256-cbc -d -salt -pass "pass:$master" -in "$SECRETS_FILE" 2>/dev/null > /tmp/secrets_plain
    echo "$key=$value" >> /tmp/secrets_plain
    cat /tmp/secrets_plain | openssl enc -aes-256-cbc -salt -pass "pass:$master" -out "$SECRETS_FILE" 2>/dev/null
    rm -f /tmp/secrets_plain
    echo -e "${GREEN}Secret added: $key${NC}"
    press_enter
}

secrets_list() {
    local master=$(prompt_password "  Master password")
    openssl enc -aes-256-cbc -d -salt -pass "pass:$master" -in "$SECRETS_FILE" 2>/dev/null | grep -v "^#" | while read -r line; do
        local key=$(echo "$line" | cut -d= -f1)
        echo -e "  ${GREEN}$key${NC}"
    done
    press_enter
}

secrets_get() {
    local master=$(prompt_password "  Master password")
    local key=$(prompt_value "  Secret name")
    local value=$(openssl enc -aes-256-cbc -d -salt -pass "pass:$master" -in "$SECRETS_FILE" 2>/dev/null | grep "^$key=" | cut -d= -f2-)
    if [ -n "$value" ]; then
        echo -e "  ${GREEN}$key${NC} = ${DIM}$value${NC}"
    else
        echo -e "${RED}Secret not found.${NC}"
    fi
    press_enter
}

secrets_delete() {
    local master=$(prompt_password "  Master password")
    local key=$(prompt_value "  Secret name to delete")
    openssl enc -aes-256-cbc -d -salt -pass "pass:$master" -in "$SECRETS_FILE" 2>/dev/null | grep -v "^$key=" > /tmp/secrets_plain
    cat /tmp/secrets_plain | openssl enc -aes-256-cbc -salt -pass "pass:$master" -out "$SECRETS_FILE" 2>/dev/null
    rm -f /tmp/secrets_plain
    echo -e "${GREEN}Secret deleted.${NC}"
    press_enter
}

password_audit() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Password Audit ═══${NC}"
    echo ""

    local issues=0

    # Check .env files for default passwords
    echo -e "${CYAN}Checking for default/weak passwords...${NC}"
    echo ""

    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")

        if [ -f "$svc_dir/.env" ]; then
            if grep -q "changeme" "$svc_dir/.env" 2>/dev/null; then
                echo -e "  ${RED}  $name${NC} - contains default password 'changeme'"
                ((issues++))
            fi
        fi

        if [ -f "$svc_dir/docker-compose.yml" ]; then
            if grep -q "changeme" "$svc_dir/docker-compose.yml" 2>/dev/null; then
                echo -e "  ${RED}  $name${NC} - contains default password in compose"
                ((issues++))
            fi
        fi
    done

    # Check for open ports without auth
    echo ""
    echo -e "${CYAN}Checking exposed ports...${NC}"
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        [ -f "$svc_dir/.port" ] || continue
        local port=$(cat "$svc_dir/.port")

        # Check if port is accessible from all interfaces
        if ss -tlnp 2>/dev/null | grep -q ":$port.*0.0.0.0" || netstat -tlnp 2>/dev/null | grep -q ":$port.*0.0.0.0"; then
            echo -e "  ${YELLOW}  $name${NC} (port $port) - accessible from network"
        fi
    done

    echo ""
    if [ $issues -eq 0 ]; then
        echo -e "${GREEN}  No critical issues found.${NC}"
    else
        echo -e "${RED}  Found $issues issue(s). Change default passwords!${NC}"
    fi
    press_enter
}

firewall_setup() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Firewall ═══${NC}"
    echo ""

    if ! command -v ufw &>/dev/null; then
        echo -e "${YELLOW}UFW not installed.${NC}"
        if confirm "  Install UFW firewall?"; then
            sudo apt install -y ufw
        else
            return
        fi
    fi

    echo -e "${CYAN}Current firewall status:${NC}"
    sudo ufw status 2>/dev/null
    echo ""

    echo -e "  ${BOLD}[1]${NC}  Enable firewall (allow SSH only)"
    echo -e "  ${BOLD}[2]${NC}  Allow a port"
    echo -e "  ${BOLD}[3]${NC}  Deny a port"
    echo -e "  ${BOLD}[4]${NC}  Disable firewall"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) sudo ufw allow ssh && sudo ufw enable && echo -e "${GREEN}Firewall enabled.${NC}" ;;
        2) local port=$(prompt_value "  Port to allow"); sudo ufw allow "$port" && echo -e "${GREEN}Port $port allowed.${NC}" ;;
        3) local port=$(prompt_value "  Port to deny"); sudo ufw deny "$port" && echo -e "${GREEN}Port $port denied.${NC}" ;;
        4) sudo ufw disable && echo -e "${YELLOW}Firewall disabled.${NC}" ;;
        0) return ;;
    esac
    press_enter
}

https_setup() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ HTTPS Setup ═══${NC}"
    echo ""
    echo -e "  ${DIM}Generate self-signed SSL certificates for local use.${NC}"
    echo ""

    local domain=$(prompt_value "  Domain/hostname (or 'localhost')")
    local port=$(prompt_value "  Port for HTTPS" "443")

    local cert_dir="$DATA_DIR/certs"
    mkdir -p "$cert_dir"

    echo -e "${YELLOW}Generating self-signed certificate...${NC}"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/$domain.key" \
        -out "$cert_dir/$domain.crt" \
        -subj "/CN=$domain" 2>/dev/null

    echo ""
    echo -e "${GREEN}Certificate created:${NC}"
    echo -e "  ${DIM}Certificate: $cert_dir/$domain.crt${NC}"
    echo -e "  ${DIM}Key:         $cert_dir/$domain.key${NC}"
    echo ""
    echo -e "  ${DIM}Use in your docker-compose.yml:${NC}"
    echo -e "  ${DIM}volumes:${NC}"
    echo -e "  ${DIM}  - $cert_dir/$domain.crt:/etc/ssl/certs/$domain.crt:ro${NC}"
    echo -e "  ${DIM}  - $cert_dir/$domain.key:/etc/ssl/private/$domain.key:ro${NC}"
    press_enter
}

security_scan() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Security Scan ═══${NC}"
    echo ""

    local score=100
    local issues=()

    # Check 1: Docker running as root
    echo -e "${CYAN}[1/6]${NC} Checking Docker permissions..."
    if groups | grep -q docker; then
        echo -e "  ${GREEN}  User in docker group${NC}"
    else
        echo -e "  ${YELLOW}  User not in docker group${NC}"
        ((score-=5))
    fi

    # Check 2: Default passwords
    echo -e "${CYAN}[2/6]${NC} Checking default passwords..."
    local default_pwds=0
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        [ -f "$svc_dir/.env" ] && grep -q "changeme" "$svc_dir/.env" 2>/dev/null && ((default_pwds++))
    done
    if [ $default_pwds -gt 0 ]; then
        echo -e "  ${RED}  Found $default_pwds services with default passwords${NC}"
        ((score-=default_pwds*10))
    else
        echo -e "  ${GREEN}  No default passwords${NC}"
    fi

    # Check 3: Open ports
    echo -e "${CYAN}[3/6]${NC} Checking exposed ports..."
    local open_count=0
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        [ -f "$svc_dir/.port" ] || continue
        local port=$(cat "$svc_dir/.port")
        if ss -tlnp 2>/dev/null | grep -q ":$port.*0.0.0.0"; then
            ((open_count++))
        fi
    done
    echo -e "  ${YELLOW}  $open_count service(s) accessible from network${NC}"

    # Check 4: Firewall
    echo -e "${CYAN}[4/6]${NC} Checking firewall..."
    if command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -q "active"; then
        echo -e "  ${GREEN}  Firewall active${NC}"
    else
        echo -e "  ${YELLOW}  Firewall not active${NC}"
        ((score-=10))
    fi

    # Check 5: Disk encryption
    echo -e "${CYAN}[5/6]${NC} Checking encryption..."
    echo -e "  ${DIM}  Manual check required for disk encryption${NC}"

    # Check 6: Updates
    echo -e "${CYAN}[6/6]${NC} Checking for updates..."
    echo -e "  ${DIM}  Run: palladium update${NC}"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ $score -ge 80 ]; then
        echo -e "  ${GREEN}Security Score: $score/100 - Good${NC}"
    elif [ $score -ge 60 ]; then
        echo -e "  ${YELLOW}Security Score: $score/100 - Fair${NC}"
    else
        echo -e "  ${RED}Security Score: $score/100 - Needs attention${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    press_enter
}

secrets_menu() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Secrets Menu ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Add secret${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}List secrets${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Get secret${NC}"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Delete secret${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) secrets_add ;;
        2) secrets_list ;;
        3) secrets_get ;;
        4) secrets_delete ;;
        0) return ;;
    esac
    press_enter
}

generate_https_certs() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Generate HTTPS Certs ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Self-signed certificate${NC} (openssl)"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Let's Encrypt${NC} (certbot)"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1)
            local domain=$(prompt_value "  Domain or IP")
            [ -z "$domain" ] && return

            local cert_dir="$DATA_DIR/certs"
            mkdir -p "$cert_dir"

            echo -e "${YELLOW}Generating self-signed certificate...${NC}"
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout "$cert_dir/$domain.key" \
                -out "$cert_dir/$domain.crt" \
                -subj "/CN=$domain" 2>/dev/null

            if [ -f "$cert_dir/$domain.crt" ]; then
                echo -e "${GREEN}Certificate generated:${NC}"
                echo -e "  ${DIM}Cert: $cert_dir/$domain.crt${NC}"
                echo -e "  ${DIM}Key:  $cert_dir/$domain.key${NC}"
            else
                echo -e "${RED}Failed to generate certificate.${NC}"
            fi
            ;;
        2)
            if ! command -v certbot &>/dev/null; then
                echo -e "${RED}certbot not installed.${NC}"
                echo -e "${YELLOW}Install: sudo apt install -y certbot${NC}"
            else
                local email=$(prompt_value "  Email for Let's Encrypt")
                local domain=$(prompt_value "  Domain name")
                [ -z "$email" ] || [ -z "$domain" ] && return
                echo -e "${YELLOW}Running certbot...${NC}"
                sudo certbot certonly --standalone --non-interactive --agree-tos \
                    --email "$email" -d "$domain" 2>/dev/null && \
                echo -e "${GREEN}Certificate obtained for $domain${NC}" || \
                echo -e "${RED}Failed to obtain certificate.${NC}"
            fi
            ;;
        0) return ;;
    esac
    press_enter
}
