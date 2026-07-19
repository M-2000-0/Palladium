#!/bin/bash
# backup.sh - Backup and restore services

BACKUP_DIR="$DATA_DIR/backups"
mkdir -p "$BACKUP_DIR"

backup_all() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Backup All Services ═══${NC}"
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
    echo -e "${SILVER}  Services to backup:${NC}"
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
    echo -e "${SILVER}${BOLD}  ═══ Restore from Backup ═══${NC}"
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
    echo -e "${SILVER}  Backup contents:${NC}"
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
    echo -e "${SILVER}Available backups:${NC}"
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

# ============================================
# Backup/Clone v2 - Advanced Features
# ============================================

# Incremental backup using rsync
backup_incremental() {
    local svc="$1"
    local target_dir="$2"
    
    [ -z "$svc" ] && { echo "Usage: backup_incremental <service> <target_dir>"; return 1; }
    [ -z "$target_dir" ] && { echo "Usage: backup_incremental <service> <target_dir>"; return 1; }
    
    local svc_dir="$INSTALLED_DIR/$svc"
    [ -d "$svc_dir" ] || { echo -e "${RED}Service '$svc' not found.${NC}"; return 1; }
    
    mkdir -p "$target_dir"
    
    echo -e "${YELLOW}Running incremental backup for $svc...${NC}"
    
    # Use rsync for incremental backup
    if command -v rsync &>/dev/null; then
        rsync -av --delete \
            --exclude='*/node_modules' \
            --exclude='*/.git' \
            --exclude='*/tmp/*' \
            --exclude='*/cache/*' \
            "$svc_dir/" "$target_dir/$svc/" 2>/dev/null
        echo -e "${GREEN}Incremental backup complete: $target_dir/$svc${NC}"
    else
        echo -e "${RED}rsync not installed. Install rsync for incremental backups.${NC}"
        return 1
    fi
}

# Restic-based backup (encrypted, deduplicated, incremental)
backup_restic() {
    local svc="$1"
    local repo="$2"
    local password="$3"
    
    [ -z "$svc" ] && { echo "Usage: backup_restic <service> <repo> [password]"; return 1; }
    [ -z "$repo" ] && { echo "Usage: backup_restic <service> <repo> [password]"; return 1; }
    
    local svc_dir="$INSTALLED_DIR/$svc"
    [ -d "$svc_dir" ] || { echo -e "${RED}Service '$svc' not found.${NC}"; return 1; }
    
    if ! command -v restic &>/dev/null; then
        echo -e "${RED}restic not installed. Install: https://restic.net${NC}"
        return 1
    fi
    
    export RESTIC_REPOSITORY="$repo"
    export RESTIC_PASSWORD="${password:-$(prompt_password "  Restic repository password")}"
    
    # Initialize repo if needed
    restic snapshots &>/dev/null || restic init
    
    echo -e "${YELLOW}Backing up $svc to restic repo...${NC}"
    restic backup "$svc_dir" --tag "palladium,$svc,$(date +%Y%m%d)" --verbose
    
    echo -e "${GREEN}Restic backup complete.${NC}"
}

# Rclone-based cloud backup (S3, Google Drive, Azure, etc.)
backup_rclone() {
    local svc="$1"
    local remote="$2"
    local remote_path="$3"
    
    [ -z "$svc" ] && { echo "Usage: backup_rclone <service> <remote> <remote_path>"; return 1; }
    [ -z "$remote" ] && { echo "Usage: backup_rclone <service> <remote> <remote_path>"; return 1; }
    [ -z "$remote_path" ] && { echo "Usage: backup_rclone <service> <remote> <remote_path>"; return 1; }
    
    local svc_dir="$INSTALLED_DIR/$svc"
    [ -d "$svc_dir" ] || { echo -e "${RED}Service '$svc' not found.${NC}"; return 1; }
    
    if ! command -v rclone &>/dev/null; then
        echo -e "${RED}rclone not installed. Install: https://rclone.org${NC}"
        return 1
    fi
    
    # Check if remote is configured
    if ! rclone listremotes | grep -q "^${remote}:$"; then
        echo -e "${RED}Remote '$remote' not configured. Run 'rclone config' first.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Syncing $svc to $remote:$remote_path...${NC}"
    rclone sync "$svc_dir" "$remote:$remote_path/$svc" \
        --progress \
        --exclude "/data/postgres/**" \
        --exclude "/data/redis/**" \
        --exclude "*.log" \
        --exclude "tmp/**"
    
    echo -e "${GREEN}Rclone sync complete.${NC}"
}

# Encrypted backup using age (modern encryption)
backup_encrypted() {
    local svc="$1"
    local output="$2"
    local key_file="$3"
    
    [ -z "$svc" ] && { echo "Usage: backup_encrypted <service> <output.tar.gz.age> [key_file]"; return 1; }
    [ -z "$output" ] && { echo "Usage: backup_encrypted <service> <output.tar.gz.age> [key_file]"; return 1; }
    
    local svc_dir="$INSTALLED_DIR/$svc"
    [ -d "$svc_dir" ] || { echo -e "${RED}Service '$svc' not found.${NC}"; return 1; }
    
    if ! command -v age &>/dev/null; then
        echo -e "${RED}age not installed. Install: https://github.com/FiloSottile/age${NC}"
        return 1
    fi
    
    local key=""
    if [ -n "$key_file" ] && [ -f "$key_file" ]; then
        key="-r $(cat "$key_file")"
    else
        key="$(prompt_password "  Encryption password" | age -p)"
    fi
    
    echo -e "${YELLOW}Creating encrypted backup...${NC}"
    
    tar czf - -C "$INSTALLED_DIR" "$svc" \
        --exclude='*/data/postgres/*' \
        --exclude='*/data/redis/*' 2>/dev/null | \
    age -e $key > "$output"
    
    echo -e "${GREEN}Encrypted backup saved: $output${NC}"
}

# Decrypt and restore encrypted backup
restore_encrypted() {
    local input="$1"
    local key_file="$2"
    
    [ -z "$input" ] && { echo "Usage: restore_encrypted <input.tar.gz.age> [key_file]"; return 1; }
    [ -f "$input" ] || { echo -e "${RED}File not found: $input${NC}"; return 1; }
    
    if ! command -v age &>/dev/null; then
        echo -e "${RED}age not installed.${NC}"
        return 1
    fi
    
    local key=""
    if [ -n "$key_file" ] && [ -f "$key_file" ]; then
        key="-i $key_file"
    else
        key="$(prompt_password "  Decryption password")"
    fi
    
    echo -e "${YELLOW}Decrypting and restoring...${NC}"
    
    age -d $key "$input" | tar xzf - -C "$INSTALLED_DIR"
    
    echo -e "${GREEN}Encrypted backup restored.${NC}"
}

# Scheduled backup management
backup_schedule() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Scheduled Backups ═══${NC}"
    echo ""
    
    local schedule_file="$DATA_DIR/backup-schedule.conf"
    mkdir -p "$(dirname "$schedule_file")"
    
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Add schedule${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}List schedules${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Remove schedule${NC}"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Run schedule now${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    
    case $choice in
        1)
            local name=$(prompt_value "  Schedule name")
            local services=$(prompt_value "  Services (comma-separated, 'all' for all)")
            local method=$(prompt_value "  Method (tar/restic/rclone/encrypted)" "tar")
            local target=$(prompt_value "  Target (path/repo/remote:path)")
            local schedule=$(prompt_value "  Cron schedule (e.g. '0 2 * * *' for daily 2AM)" "0 2 * * *")
            local encrypt=$(prompt_value "  Encrypt? (y/n)" "n")
            
            echo "$name|$services|$method|$target|$schedule|$encrypt" >> "$schedule_file"
            echo -e "${GREEN}Schedule added.${NC}"
            echo "Add to crontab: $schedule $PALLADIUM_HOME/palladium backup-run-schedule $name"
            ;;
        2)
            echo -e "${SILVER}Scheduled backups:${NC}"
            [ -f "$schedule_file" ] && cat "$schedule_file" | while IFS='|' read -r name services method target schedule encrypt; do
                echo -e "  ${GREEN}$name${NC} - $services via $method to $target [$schedule] ${encrypt}"
            done || echo "  (none)"
            ;;
        3)
            local name=$(prompt_value "  Schedule name to remove")
            sed -i "/^$name|/d" "$schedule_file" 2>/dev/null
            echo -e "${GREEN}Schedule removed.${NC}"
            ;;
        4)
            local name=$(prompt_value "  Schedule name to run")
            backup_run_schedule "$name"
            ;;
        0) return ;;
    esac
    press_enter
}

# Run a specific scheduled backup
backup_run_schedule() {
    local name="$1"
    local schedule_file="$DATA_DIR/backup-schedule.conf"
    
    [ -z "$name" ] && { echo "Usage: backup_run_schedule <name>"; return 1; }
    [ -f "$schedule_file" ] || { echo -e "${RED}No schedules found.${NC}"; return 1; }
    
    local line=$(grep "^$name|" "$schedule_file")
    [ -z "$line" ] && { echo -e "${RED}Schedule not found: $name${NC}"; return 1; }
    
    IFS='|' read -r _ services method target schedule encrypt <<< "$line"
    
    echo -e "${YELLOW}Running scheduled backup: $name${NC}"
    
    if [ "$services" = "all" ]; then
        local svc_list=$(ls "$INSTALLED_DIR" 2>/dev/null)
    else
        local svc_list=$(echo "$services" | tr ',' ' ')
    fi
    
    for svc in $svc_list; do
        case $method in
            tar)
                backup_single "$svc"
                ;;
            restic)
                backup_restic "$svc" "$target"
                ;;
            rclone)
                backup_rclone "$svc" $(echo "$target" | cut -d: -f1) $(echo "$target" | cut -d: -f2-)
                ;;
            encrypted)
                backup_encrypted "$svc" "$target"
                ;;
        esac
    done
    
    echo -e "${GREEN}Scheduled backup complete.${NC}"
}
