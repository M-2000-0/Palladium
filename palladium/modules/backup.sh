#!/bin/bash
# backup.sh - Backup and restore services

BACKUP_DIR="$DATA_DIR/backups"
mkdir -p "$BACKUP_DIR"

backup_all() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Backup All Services ═══${NC}"
    echo ""

    local count=0
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] && ((count++))
    done

    if [ $count -eq 0 ]; then
        echo -e "  ${DIM}No services installed. Nothing to backup.${NC}"
        press_enter
        return
    fi

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name=$(prompt_value "  Backup name" "palladium-backup-$timestamp")
    local backup_file="$BACKUP_DIR/$backup_name.tar.gz"

    echo ""
    echo -e "${CYAN}  Services to backup:${NC}"
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        local size=$(du -sh "$svc_dir" 2>/dev/null | cut -f1)
        echo -e "    ${GREEN}$name${NC} ($size)"
    done

    local total_size=$(du -sh "$INSTALLED_DIR" 2>/dev/null | cut -f1)
    echo ""
    echo -e "  Total size: ${YELLOW}$total_size${NC}"

    # Check storage for backup
    local available_mb=$(df -m "$BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
    echo -e "  Available: ${available_mb}MB"
    echo ""

    if ! confirm "  Create backup?"; then
        echo -e "${YELLOW}Cancelled.${NC}"
        press_enter
        return
    fi

    echo ""
    echo -e "${YELLOW}  Creating backup...${NC}"

    # Stop all services for consistent backup
    echo -e "${DIM}  Stopping services for consistent backup...${NC}"
    local stopped_svcs=()
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${name}$"; then
            cd "$svc_dir"
            docker compose down 2>/dev/null || docker-compose down 2>/dev/null
            stopped_svcs+=("$name")
        fi
    done

    # Create backup archive (excluding postgres data to save space, include if user wants)
    local include_data=true
    if [ $count -gt 0 ]; then
        echo ""
        if confirm "  Include service data (databases, files)?" "y"; then
            include_data=true
        else
            include_data=false
        fi
    fi

    local tar_flags="czf"
    local exclude_flags="--exclude='*/data/postgres/*' --exclude='*/data/redis/*'"

    if [ "$include_data" = true ]; then
        exclude_flags=""
    fi

    # Create the backup
    cd "$INSTALLED_DIR"
    if tar $tar_flags "$backup_file" . $exclude_flags 2>/dev/null; then
        local backup_size=$(du -sh "$backup_file" 2>/dev/null | cut -f1)
        echo ""
        echo -e "${GREEN}  ═══════════════════════════════════${NC}"
        echo -e "${GREEN}  Backup created!${NC}"
        echo -e "${GREEN}  $backup_file${NC}"
        echo -e "${GREEN}  Size: $backup_size${NC}"
        echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    else
        echo -e "${RED}  Backup failed.${NC}"
    fi

    # Restart stopped services
    echo ""
    echo -e "${DIM}  Restarting services...${NC}"
    for svc_name in "${stopped_svcs[@]}"; do
        svc_start "$svc_name" 2>/dev/null
    done

    press_enter
}

backup_single() {
    local svc="$1"
    local svc_dir="$INSTALLED_DIR/$svc"

    if [ ! -d "$svc_dir" ]; then
        echo -e "${RED}Service '$svc' not found.${NC}"
        return 1
    fi

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/${svc}-$timestamp.tar.gz"

    echo -e "${YELLOW}  Backing up $svc...${NC}"

    cd "$INSTALLED_DIR"
    if tar czf "$backup_file" "$svc" 2>/dev/null; then
        local size=$(du -sh "$backup_file" 2>/dev/null | cut -f1)
        echo -e "${GREEN}  Backup saved: $backup_file ($size)${NC}"
    else
        echo -e "${RED}  Backup failed.${NC}"
        return 1
    fi
}

restore_backup() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Restore from Backup ═══${NC}"
    echo ""

    # List available backups
    local backups=()
    local i=1
    for backup_file in "$BACKUP_DIR"/*.tar.gz; do
        [ -f "$backup_file" ] || continue
        local name=$(basename "$backup_file" .tar.gz)
        local size=$(du -sh "$backup_file" 2>/dev/null | cut -f1)
        local date=$(stat -c %y "$backup_file" 2>/dev/null | cut -d. -f1 || stat -f %Sm "$backup_file" 2>/dev/null)
        backups+=("$backup_file")
        echo -e "  ${BOLD}[$i]${NC}  ${GREEN}$name${NC}"
        echo -e "        ${DIM}Size: $size | Date: $date${NC}"
        ((i++))
    done

    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "  ${DIM}No backups found.${NC}"
        echo -e "  ${DIM}Create one with: palladium backup${NC}"
        press_enter
        return
    fi

    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select backup to restore: " choice

    if [ "$choice" = "0" ] || [ -z "$choice" ]; then return; fi
    if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#backups[@]}" ]; then
        echo -e "${RED}Invalid option${NC}"
        press_enter
        return
    fi

    local selected="${backups[$((choice-1))]}"
    local backup_name=$(basename "$selected" .tar.gz)

    echo ""
    echo -e "${CYAN}  Backup contents:${NC}"
    tar tzf "$selected" 2>/dev/null | head -20 | sed 's/^/    /'
    echo ""

    echo -e "${YELLOW}  This will restore services from: $backup_name${NC}"
    echo -e "${YELLOW}  Existing services with the same name will be replaced.${NC}"
    echo ""

    if ! confirm "  Proceed with restore?" "n"; then
        echo -e "${YELLOW}Cancelled.${NC}"
        press_enter
        return
    fi

    echo ""
    echo -e "${YELLOW}  Restoring...${NC}"

    # Stop any running services that will be restored
    local services_to_restore=$(tar tzf "$selected" 2>/dev/null | grep -oP '(?<=\./)[^/]+' | sort -u)
    for svc in $services_to_restore; do
        if [ -d "$INSTALLED_DIR/$svc" ]; then
            echo -e "${DIM}  Stopping $svc...${NC}"
            cd "$INSTALLED_DIR/$svc"
            docker compose down 2>/dev/null || docker-compose down 2>/dev/null
        fi
    done

    # Extract backup
    cd "$INSTALLED_DIR"
    if tar xzf "$selected" 2>/dev/null; then
        echo -e "${GREEN}  Files restored.${NC}"

        # Start restored services
        echo -e "${YELLOW}  Starting restored services...${NC}"
        for svc in $services_to_restore; do
            if [ -d "$INSTALLED_DIR/$svc" ]; then
                svc_start "$svc" 2>/dev/null
            fi
        done

        echo ""
        echo -e "${GREEN}  ═══════════════════════════════════${NC}"
        echo -e "${GREEN}  Restore complete!${NC}"
        echo -e "${GREEN}  ═══════════════════════════════════${NC}"

        # Show restored services
        echo ""
        for svc in $services_to_restore; do
            if [ -f "$INSTALLED_DIR/$svc/.port" ]; then
                local port=$(cat "$INSTALLED_DIR/$svc/.port")
                echo -e "    ${GREEN}$svc${NC} → http://localhost:$port"
            fi
        done
    else
        echo -e "${RED}  Restore failed. Backup may be corrupted.${NC}"
    fi

    press_enter
}

list_backups() {
    echo -e "${CYAN}Available backups:${NC}"
    echo ""
    local found=0
    for backup_file in "$BACKUP_DIR"/*.tar.gz; do
        [ -f "$backup_file" ] || continue
        local name=$(basename "$backup_file" .tar.gz)
        local size=$(du -sh "$backup_file" 2>/dev/null | cut -f1)
        echo -e "  $name  ($size)"
        found=1
    done
    [ $found -eq 0 ] && echo -e "  ${DIM}No backups yet.${NC}"
}

delete_backup() {
    local backup_file="$1"
    if [ -f "$backup_file" ]; then
        rm -f "$backup_file"
        echo -e "${GREEN}Backup deleted.${NC}"
    fi
}
