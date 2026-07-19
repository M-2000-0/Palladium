#!/bin/bash
# security.sh - Firewall, secrets, HTTPS, password management

SECRETS_FILE="$DATA_DIR/.secrets"

# Secure temp file handling
make_secure_temp() {
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/palladium_secrets.XXXXXX")
    chmod 600 "$tmp"
    echo "$tmp"
}

secure_shred() {
    local file="$1"
    [ -f "$file" ] || return 0
    if command -v shred &>/dev/null; then
        shred -u "$file" 2>/dev/null
    else
        dd if=/dev/urandom of="$file" bs=1k count=1 conv=notrunc 2>/dev/null
        rm -f "$file"
    fi
}

# port_in_use() and port_exposed() are defined in safety.sh

# Encrypt using master password from stdin
encrypt_secrets() {
    local master="$1"
    local infile="$2"
    local outfile="$3"
    printf '%s' "$master" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -pass stdin -in "$infile" -out "$outfile" 2>/dev/null
}

# Decrypt using master password from stdin
decrypt_secrets() {
    local master="$1"
    local infile="$2"
    local outfile="$3"
    printf '%s' "$master" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d -pass stdin -in "$infile" -out "$outfile" 2>/dev/null
}

security_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Security ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Secrets Manager${NC}     Store API keys, passwords securely"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Password audit${NC}      Check for weak/default passwords"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Firewall${NC}            Open/close ports"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}HTTPS setup${NC}         SSL/TLS certificates"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}Scan for issues${NC}     Full security checkup"
    echo ""
    echo -e "  ${BOLD}Security Hardening:${NC}"
    echo -e "  ${BOLD}[6]${NC}  ${YELLOW}2FA (TOTP)${NC}          Two-factor authentication"
    echo -e "  ${BOLD}[7]${NC}  ${YELLOW}Audit Log${NC}           View security events"
    echo -e "  ${BOLD}[8]${NC}  ${YELLOW}Secrets Rotation${NC}    Rotate/expire secrets"
    echo -e "  ${BOLD}[9]${NC}  ${YELLOW}CIS Docker Bench${NC}    Docker security audit"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) secrets_manager ;;
        2) password_audit ;;
        3) firewall_setup ;;
        4) https_setup ;;
        5) security_scan ;;
        6) security_2fa ;;
        7) security_audit_log ;;
        8) security_secrets_rotation ;;
        9) security_cis_docker_bench ;;
        0) return ;;
    esac
}

secrets_manager() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Secrets Manager ═══${NC}"
    echo ""
    echo -e "  ${DIM}Store API keys, passwords, and tokens securely.${NC}"
    echo -e "  ${DIM}Encrypted with your master password.${NC}"
    echo ""

    if [ ! -f "$SECRETS_FILE" ]; then
        echo -e "  ${YELLOW}No vault found. Let's create one.${NC}"
        echo ""
        local master=$(prompt_password "  Create master password")
        [ -z "$master" ] && return
    local tmp=$(make_secure_temp)
    echo "# Palladium Secrets Vault" > "$tmp"
    encrypt_secrets "$master" "$tmp" "$SECRETS_FILE"
    secure_shred "$tmp"
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

    local tmp=$(make_secure_temp)
    decrypt_secrets "$master" "$SECRETS_FILE" "$tmp" || { secure_shred "$tmp"; return; }
    echo "$key=$value" >> "$tmp"
    encrypt_secrets "$master" "$tmp" "$SECRETS_FILE"
    secure_shred "$tmp"
    echo -e "${GREEN}Secret added: $key${NC}"
    press_enter
}

secrets_list() {
    local master=$(prompt_password "  Master password")
    local tmp=$(make_secure_temp)
    decrypt_secrets "$master" "$SECRETS_FILE" "$tmp" || { secure_shred "$tmp"; return; }
    grep -v "^#" "$tmp" 2>/dev/null | while IFS= read -r line; do
        local key=$(echo "$line" | cut -d= -f1)
        echo -e "  ${GREEN}$key${NC}"
    done
    secure_shred "$tmp"
    press_enter
}

secrets_get() {
    local master=$(prompt_password "  Master password")
    local key=$(prompt_value "  Secret name")
    local tmp=$(make_secure_temp)
    decrypt_secrets "$master" "$SECRETS_FILE" "$tmp" || { secure_shred "$tmp"; return; }
    local value=$(grep "^$key=" "$tmp" 2>/dev/null | cut -d= -f2-)
    secure_shred "$tmp"
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
    local tmp=$(make_secure_temp)
    decrypt_secrets "$master" "$SECRETS_FILE" "$tmp" || { secure_shred "$tmp"; return; }
    grep -v "^$key=" "$tmp" > "${tmp}.new" 2>/dev/null || true
    encrypt_secrets "$master" "${tmp}.new" "$SECRETS_FILE"
    secure_shred "$tmp"
    secure_shred "${tmp}.new"
    echo -e "${GREEN}Secret deleted.${NC}"
    press_enter
}

password_audit() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Password Audit ═══${NC}"
    echo ""

    local issues=0

    # Check .env files for default passwords
    echo -e "${SILVER}Checking for default/weak passwords...${NC}"
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
    echo -e "${SILVER}Checking exposed ports...${NC}"
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        [ -f "$svc_dir/.port" ] || continue
        local port=$(cat "$svc_dir/.port")

        # Check if port is accessible from all interfaces
        if port_exposed "$port"; then
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
    echo -e "${SILVER}${BOLD}  ═══ Firewall ═══${NC}"
    echo ""

    if ! command -v ufw &>/dev/null; then
        echo -e "${YELLOW}UFW not installed.${NC}"
        if confirm "  Install UFW firewall?"; then
            sudo apt install -y ufw
        else
            return
        fi
    fi

    echo -e "${SILVER}Current firewall status:${NC}"
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
    echo -e "${SILVER}${BOLD}  ═══ HTTPS Setup ═══${NC}"
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
    echo -e "${SILVER}${BOLD}  ═══ Security Scan ═══${NC}"
    echo ""

    local score=100
    local issues=()

    # Check 1: Docker running as root
    echo -e "${SILVER}[1/6]${NC} Checking Docker permissions..."
    if groups | grep -q docker; then
        echo -e "  ${GREEN}  User in docker group${NC}"
    else
        echo -e "  ${YELLOW}  User not in docker group${NC}"
        ((score-=5))
    fi

    # Check 2: Default passwords
    echo -e "${SILVER}[2/6]${NC} Checking default passwords..."
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
    echo -e "${SILVER}[3/6]${NC} Checking exposed ports..."
    local open_count=0
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        [ -f "$svc_dir/.port" ] || continue
        local port=$(cat "$svc_dir/.port")
        if port_exposed "$port"; then
            ((open_count++))
        fi
    done
    echo -e "  ${YELLOW}  $open_count service(s) accessible from network${NC}"

    # Check 4: Firewall
    echo -e "${SILVER}[4/6]${NC} Checking firewall..."
    if command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -q "active"; then
        echo -e "  ${GREEN}  Firewall active${NC}"
    else
        echo -e "  ${YELLOW}  Firewall not active${NC}"
        ((score-=10))
    fi

    # Check 5: Disk encryption
    echo -e "${SILVER}[5/6]${NC} Checking encryption..."
    echo -e "  ${DIM}  Manual check required for disk encryption${NC}"

    # Check 6: Updates
    echo -e "${SILVER}[6/6]${NC} Checking for updates..."
    echo -e "  ${DIM}  Run: palladium update${NC}"

    echo ""
    echo -e "${SILVER}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ $score -ge 80 ]; then
        echo -e "  ${GREEN}Security Score: $score/100 - Good${NC}"
    elif [ $score -ge 60 ]; then
        echo -e "  ${YELLOW}Security Score: $score/100 - Fair${NC}"
    else
        echo -e "  ${RED}Security Score: $score/100 - Needs attention${NC}"
    fi
    echo -e "${SILVER}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    press_enter
}

secrets_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Secrets Menu ═══${NC}"
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
    echo -e "${SILVER}${BOLD}  ═══ Generate HTTPS Certs ═══${NC}"
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

# ============================================
# Security Hardening v2
# ============================================

AUDIT_LOG="$DATA_DIR/audit.log"

# Log security events
audit_log() {
    local event="$1"
    local details="$2"
    local level="${3:-INFO}"
    echo "[$(date -Iseconds)] [$level] $event: $details" >> "$AUDIT_LOG"
}

# 2FA (TOTP) setup
security_2fa() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Two-Factor Authentication (TOTP) ═══${NC}"
    echo ""
    
    if ! command -v oathtool &>/dev/null; then
        echo -e "${YELLOW}oathtool not installed. Install: sudo apt install oathtool${NC}"
        press_enter
        return
    fi
    
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Enable 2FA for Palladium${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Show 2FA QR code${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Verify 2FA code${NC}"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Disable 2FA${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    
    local totp_file="$DATA_DIR/.totp"
    
    case $choice in
        1)
            echo -e "${DIM}Generating TOTP secret...${NC}"
            local secret=$(head -c 20 /dev/urandom | base32 | tr -d '=' | tr '[:lower:]' '[:upper:]')
            echo "TOTP_SECRET=$secret" > "$totp_file"
            chmod 600 "$totp_file"
            
            local label="Palladium:$(hostname)"
            local uri="otpauth://totp/$label?secret=$secret&issuer=Palladium"
            
            echo -e "${GREEN}2FA Enabled!${NC}"
            echo ""
            echo -e "  ${BOLD}Secret:${NC} $secret"
            echo -e "  ${BOLD}URI:${NC} $uri"
            echo ""
            echo -e "  ${DIM}Save the secret to your authenticator app (Google Authenticator, Authy, etc.)${NC}"
            echo -e "  ${DIM}Or scan the QR code below:${NC}"
            echo ""
            
            # Generate QR code if qrencode available
            if command -v qrencode &>/dev/null; then
                qrencode -t ANSIUTF8 "$uri"
            else
                echo -e "  ${DIM}Install qrencode for QR code display${NC}"
            fi
            audit_log "2FA_ENABLED" "Two-factor authentication enabled"
            ;;
        2)
            [ -f "$totp_file" ] || { echo -e "${RED}2FA not enabled${NC}"; press_enter; return; }
            source "$totp_file"
            local label="Palladium:$(hostname)"
            local uri="otpauth://totp/$label?secret=$TOTP_SECRET&issuer=Palladium"
            if command -v qrencode &>/dev/null; then
                qrencode -t ANSIUTF8 "$uri"
            else
                echo "URI: $uri"
            fi
            ;;
        3)
            [ -f "$totp_file" ] || { echo -e "${RED}2FA not enabled${NC}"; press_enter; return; }
            source "$totp_file"
            local code=$(prompt_value "  Enter 6-digit code")
            local expected=$(oathtool --base32 --totp "$TOTP_SECRET")
            if [ "$code" = "$expected" ]; then
                echo -e "${GREEN}Code valid!${NC}"
                audit_log "2FA_VERIFY" "TOTP verification successful" "SUCCESS"
            else
                echo -e "${RED}Invalid code. Expected: $expected${NC}"
                audit_log "2FA_VERIFY" "TOTP verification failed" "FAILURE"
            fi
            ;;
        4)
            [ -f "$totp_file" ] && rm "$totp_file" && echo -e "${GREEN}2FA disabled${NC}" && audit_log "2FA_DISABLED" "Two-factor authentication disabled"
            ;;
        0) return ;;
    esac
    press_enter
}

# Audit log viewer
security_audit_log() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Security Audit Log ═══${NC}"
    echo ""
    
    [ -f "$AUDIT_LOG" ] || { echo -e "${DIM}No audit events yet.${NC}"; press_enter; return; }
    
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}View all events${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}View failures only${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}View by event type${NC}"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Clear log${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    
    case $choice in
        1) tail -50 "$AUDIT_LOG" ;;
        2) grep "FAILURE" "$AUDIT_LOG" | tail -20 ;;
        3)
            local event=$(prompt_value "  Event type (e.g. 2FA_VERIFY, LOGIN, SECRET_ACCESS)")
            grep "$event" "$AUDIT_LOG" | tail -20
            ;;
        4) > "$AUDIT_LOG"; echo -e "${GREEN}Log cleared${NC}" ;;
        0) return ;;
    esac
    press_enter
}

# Secrets rotation
security_secrets_rotation() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Secrets Rotation ═══${NC}"
    echo ""
    
    [ -f "$SECRETS_FILE" ] || { echo -e "${RED}No vault found${NC}"; press_enter; return; }
    
    local master=$(prompt_password "  Master password")
    [ -z "$master" ] && return
    
    local tmp=$(make_secure_temp)
    if ! decrypt_secrets "$master" "$SECRETS_FILE" "$tmp"; then
        echo -e "${RED}Wrong password${NC}"
        rm -f "$tmp"
        audit_log "SECRET_ROTATION" "Failed - wrong password" "FAILURE"
        press_enter
        return
    fi
    
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}List secrets with age${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Rotate specific secret${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Rotate all secrets older than N days${NC}"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Set expiration on secret${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    
    case $choice in
        1)
            echo -e "${SILVER}Secrets:${NC}"
            grep -v '^#' "$tmp" | while IFS='=' read -r key value; do
                [ -z "$key" ] && continue
                local age="unknown"
                local created=$(grep "^# $key created:" "$tmp" 2>/dev/null | cut -d' ' -f3)
                [ -n "$created" ] && age=$(date -d "$created" +%s 2>/dev/null || echo "unknown")
                if [ "$age" != "unknown" ]; then
                    local days=$(( ($(date +%s) - age) / 86400 ))
                    echo -e "  ${GREEN}$key${NC} - created $created (${days} days ago)"
                else
                    echo -e "  ${GREEN}$key${NC} - no age info"
                fi
            done
            ;;
        2)
            local key=$(prompt_value "  Secret name to rotate")
            grep -q "^$key=" "$tmp" || { echo -e "${RED}Not found${NC}"; rm -f "$tmp"; press_enter; return; }
            local new_val=$(prompt_password "  New value for $key")
            sed_inplace "/^$key=/d" "$tmp"
            echo "$key=$new_val" >> "$tmp"
            echo "# $key created: $(date -I)" >> "$tmp"
            encrypt_secrets "$master" "$tmp" "$SECRETS_FILE"
            echo -e "${GREEN}Secret rotated${NC}"
            audit_log "SECRET_ROTATED" "Rotated $key" "SUCCESS"
            ;;
        3)
            local days=$(prompt_value "  Rotate secrets older than (days)" "90")
            local now=$(date +%s)
            local rotated=0
            while IFS='=' read -r key value; do
                [ -z "$key" ] && continue
                local created=$(grep "^# $key created:" "$tmp" 2>/dev/null | cut -d' ' -f3)
                [ -z "$created" ] && continue
                local age_sec=$(date -d "$created" +%s 2>/dev/null || echo 0)
                local age_days=$(( (now - age_sec) / 86400 ))
                if [ $age_days -gt $days ]; then
                    local new_val=$(prompt_password "  New value for $key (current age: ${age_days}d)")
                    sed_inplace "/^$key=/d" "$tmp"
                    echo "$key=$new_val" >> "$tmp"
                    echo "# $key created: $(date -I)" >> "$tmp"
                    ((rotated++))
                fi
            done < <(grep -v '^#' "$tmp")
            [ $rotated -gt 0 ] && { encrypt_secrets "$master" "$tmp" "$SECRETS_FILE"; echo -e "${GREEN}Rotated $rotated secrets${NC}"; audit_log "SECRET_BULK_ROTATE" "Rotated $rotated secrets" "SUCCESS"; }
            ;;
        4)
            local key=$(prompt_value "  Secret name")
            grep -q "^$key=" "$tmp" || { echo -e "${RED}Not found${NC}"; rm -f "$tmp"; press_enter; return; }
            local days=$(prompt_value "  Expires in (days)" "90")
            local expiry=$(date -d "+$days days" -I)
            echo "# $key expires: $expiry" >> "$tmp"
            encrypt_secrets "$master" "$tmp" "$SECRETS_FILE"
            echo -e "${GREEN}Expiration set for $key: $expiry${NC}"
            ;;
        0) ;;
    esac
    rm -f "$tmp"
    press_enter
}

# CIS Docker Benchmark
security_cis_docker_bench() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ CIS Docker Benchmark ═══${NC}"
    echo ""
    echo -e "  ${DIM}Running Docker security checks...${NC}"
    echo ""
    
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Docker not installed${NC}"
        press_enter
        return
    fi
    
    local issues=0
    local warnings=0
    
    # 1.1 Host configuration
    echo -e "${BOLD}1. Host Configuration:${NC}"
    
    # 1.1.1 - Create a separate partition for containers
    echo -n "  1.1.1 Separate partition for /var/lib/docker: "
    if mountpoint -q /var/lib/docker; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${YELLOW}WARN${NC} (not on separate partition)"
        ((warnings++))
    fi
    
    # 1.1.2 - Use updated Docker
    echo -n "  1.1.2 Docker version up to date: "
    local docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    echo -e "${GREEN}$docker_version${NC}"
    
    # 1.2 - Docker daemon configuration
    echo -e "${BOLD}1.2 Daemon Configuration:${NC}"
    
    # Check daemon.json
    local daemon_json="/etc/docker/daemon.json"
    if [ -f "$daemon_json" ]; then
        echo -n "  1.2.1 daemon.json exists: "
        echo -e "${GREEN}YES${NC}"
        
        # Check for live-restore
        if grep -q "live-restore" "$daemon_json"; then
            echo -n "  1.2.2 live-restore enabled: "
            echo -e "${GREEN}YES${NC}"
        else
            echo -n "  1.2.2 live-restore enabled: "
            echo -e "${YELLOW}NO${NC} (recommended for HA)"
            ((warnings++))
        fi
        
        # Check for log driver
        if grep -q '"log-driver"' "$daemon_json"; then
            echo -n "  1.2.3 Log driver configured: "
            echo -e "${GREEN}YES${NC}"
        else
            echo -n "  1.2.3 Log driver configured: "
            echo -e "${YELLOW}NO${NC} (default json-file)"
            ((warnings++))
        fi
        
        # Check for userns-remap
        if grep -q '"userns-remap"' "$daemon_json"; then
            echo -n "  1.2.4 User namespace remap: "
            echo -e "${GREEN}YES${NC}"
        else
            echo -n "  1.2.4 User namespace remap: "
            echo -e "${YELLOW}NO${NC} (recommended)"
            ((warnings++))
        fi
    else
        echo -e "  1.2.1 daemon.json exists: ${RED}NO${NC} (using defaults)"
        ((issues++))
    fi
    
    # 1.3 - Docker daemon file permissions
    echo -e "${BOLD}1.3 File Permissions:${NC}"
    for file in /var/run/docker.sock /etc/docker/daemon.json; do
        if [ -e "$file" ]; then
            local perms=$(stat -c "%a %U:%G" "$file")
            echo -n "  $file: "
            if [[ "$perms" == "660 root:docker"* ]] || [[ "$perms" == "600 root:root"* ]]; then
                echo -e "${GREEN}$perms${NC}"
            else
                echo -e "${YELLOW}$perms${NC} (review)"
                ((warnings++))
            fi
        fi
    done
    
    # 2 - Docker daemon configuration (running containers)
    echo -e "${BOLD}2. Container Runtime:${NC}"
    
    # Check for privileged containers
    echo -n "  2.1 No privileged containers: "
    local priv=$(docker ps --format '{{.Names}}' | xargs -I {} docker inspect {} --format '{{.HostConfig.Privileged}} {{.Name}}' 2>/dev/null | grep "^true" | wc -l)
    if [ "$priv" -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}$priv privileged container(s) running${NC}"
        ((issues++))
    fi
    
    # Check for host network mode
    echo -n "  2.2 No host network mode: "
    local hostnet=$(docker ps --format '{{.Names}}' | xargs -I {} docker inspect {} --format '{{.HostConfig.NetworkMode}} {{.Name}}' 2>/dev/null | grep "^host" | wc -l)
    if [ "$hostnet" -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${YELLOW}$hostnet container(s) on host network${NC}"
        ((warnings++))
    fi
    
    # Check for host pid mode
    echo -n "  2.3 No host PID mode: "
    local hostpid=$(docker ps --format '{{.Names}}' | xargs -I {} docker inspect {} --format '{{.HostConfig.PidMode}} {{.Name}}' 2>/dev/null | grep "^host" | wc -l)
    if [ "$hostpid" -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${YELLOW}$hostpid container(s) with host PID${NC}"
        ((warnings++))
    fi
    
    # Check for host ipc mode
    echo -n "  2.4 No host IPC mode: "
    local hostipc=$(docker ps --format '{{.Names}}' | xargs -I {} docker inspect {} --format '{{.HostConfig.IpcMode}} {{.Name}}' 2>/dev/null | grep "^host" | wc -l)
    if [ "$hostipc" -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${YELLOW}$hostipc container(s) with host IPC${NC}"
        ((warnings++))
    fi
    
    # Check for capabilities
    echo -n "  2.5 Minimal capabilities: "
    local caps=$(docker ps --format '{{.Names}}' | xargs -I {} docker inspect {} --format '{{.HostConfig.CapAdd}} {{.Name}}' 2>/dev/null | grep -v "^<no value>" | wc -l)
    if [ "$caps" -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${YELLOW}$caps container(s) with added capabilities${NC}"
        ((warnings++))
    fi
    
    # Check for read-only root filesystem
    echo -n "  2.6 Read-only root filesystem: "
    local ro=$(docker ps --format '{{.Names}}' | xargs -I {} docker inspect {} --format '{{.HostConfig.ReadonlyRootfs}} {{.Name}}' 2>/dev/null | grep "^false" | wc -l)
    if [ "$ro" -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${YELLOW}$ro container(s) without read-only rootfs${NC}"
        ((warnings++))
    fi
    
    # Check for user namespace
    echo -n "  2.7 Non-root user: "
    local root=$(docker ps --format '{{.Names}}' | xargs -I {} docker inspect {} --format '{{.Config.User}} {{.Name}}' 2>/dev/null | grep -E "^( |root)" | wc -l)
    if [ "$root" -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${YELLOW}$root container(s) running as root${NC}"
        ((warnings++))
    fi
    
    # 4 - Docker images
    echo -e "${BOLD}4. Docker Images:${NC}"
    
    # Check for HEALTHCHECK
    echo -n "  4.1 HEALTHCHECK defined: "
    local no_health=$(docker images --format '{{.Repository}}:{{.Tag}}' | xargs -I {} docker inspect {} --format '{{.Config.Healthcheck}} {{.RepoTags}}' 2>/dev/null | grep "^<nil>" | wc -l)
    local total=$(docker images --format '{{.Repository}}:{{.Tag}}' | wc -l)
    echo -e "${GREEN}$((total - no_health))/$total${NC} images have healthchecks"
    
    # Summary
    echo ""
    echo -e "${BOLD}Summary:${NC}"
    echo -e "  Issues: ${RED}$issues${NC}"
    echo -e "  Warnings: ${YELLOW}$warnings${NC}"
    echo -e "  ${DIM}Run 'docker bench security' for full CIS benchmark${NC}"
    
    audit_log "CIS_DOCKER_BENCH" "Issues: $issues, Warnings: $warnings" "INFO"
    press_enter
}
