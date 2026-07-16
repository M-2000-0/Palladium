#!/bin/bash
# clone.sh - Clone/migrate full setup between drives

clone_menu() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Clone & Migrate ═══${NC}"
    echo ""
    echo -e "  ${DIM}Copy your entire Palladium setup to another drive.${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Clone to another drive${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Clone from another drive${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Full backup (all data)${NC}"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Full restore${NC}"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}Compare drives${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) clone_to ;;
        2) clone_from ;;
        3) full_backup ;;
        4) full_restore ;;
        5) compare_drives ;;
        0) return ;;
    esac
}

clone_to() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Clone to Another Drive ═══${NC}"
    echo ""

    # Show available drives
    show_usb_info

    local target=$(prompt_value "  Target drive path (e.g. /media/user/MYUSB)")
    [ -z "$target" ] && return

    if [ ! -d "$target" ]; then
        echo -e "${RED}Target not found: $target${NC}"
        press_enter; return
    fi

    # Check space
    local source_size=$(du -sh "$PALLADIUM_HOME" 2>/dev/null | cut -f1)
    local target_free=$(df -m "$target" 2>/dev/null | awk 'NR==2 {print $4}')

    echo ""
    echo -e "  Source size: ${BOLD}$source_size${NC}"
    echo -e "  Target free: ${BOLD}${target_free}MB${NC}"
    echo ""

    if ! confirm "  Clone Palladium to $target?"; then return; fi

    echo ""
    echo -e "${YELLOW}Cloning...${NC}"

    # Copy everything
    rsync -av --progress "$PALLADIUM_HOME/" "$target/palladium/" 2>/dev/null || \
    cp -rv "$PALLADIUM_HOME" "$target/palladium" 2>/dev/null

    chmod +x "$target/palladium/palladium"
    chmod +x "$target/palladium/install.sh"

    echo ""
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    echo -e "${GREEN}  Clone complete!${NC}"
    echo -e "${GREEN}  Target: $target/palladium${NC}"
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    press_enter
}

clone_from() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Clone from Another Drive ═══${NC}"
    echo ""

    local source=$(prompt_value "  Source drive path")
    [ -z "$source" ] && return

    if [ ! -d "$source/palladium" ]; then
        echo -e "${RED}No Palladium found at $source/palladium${NC}"
        press_enter; return
    fi

    echo -e "${YELLOW}This will merge/overwrite your current setup.${NC}"
    if ! confirm "  Continue?" "n"; then return; fi

    echo -e "${YELLOW}Cloning...${NC}"
    rsync -av --progress "$source/palladium/" "$PALLADIUM_HOME/" 2>/dev/null || \
    cp -rv "$source/palladium/"* "$PALLADIUM_HOME/" 2>/dev/null

    echo -e "${GREEN}Clone complete!${NC}"
    press_enter
}

full_backup() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Full Backup ═══${NC}"
    echo ""

    local backup_dir="$DATA_DIR/backups"
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/full-backup-$(date +%Y%m%d_%H%M%S).tar.gz"

    local total_size=$(du -sh "$PALLADIUM_HOME" 2>/dev/null | cut -f1)
    echo -e "  Total size: ${BOLD}$total_size${NC}"
    echo ""

    if ! confirm "  Create full backup?"; then return; fi

    echo -e "${YELLOW}Creating full backup...${NC}"

    # Stop services for consistency
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        docker compose -f "$svc_dir/docker-compose.yml" down 2>/dev/null
    done

    cd "$PALLADIUM_HOME/.."
    tar czf "$backup_file" palladium/ 2>/dev/null

    # Restart services
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        cd "$svc_dir"
        docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null
    done

    local backup_size=$(du -sh "$backup_file" 2>/dev/null | cut -f1)
    echo ""
    echo -e "${GREEN}Full backup created: $backup_file ($backup_size)${NC}"
    press_enter
}

full_restore() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Full Restore ═══${NC}"
    echo ""

    local backups=()
    local i=1
    for f in "$DATA_DIR/backups"/full-backup-*.tar.gz; do
        [ -f "$f" ] || continue
        backups+=("$f")
        local size=$(du -sh "$f" 2>/dev/null | cut -f1)
        echo -e "  ${BOLD}[$i]${NC}  $(basename "$f") ($size)"
        ((i++))
    done

    [ ${#backups[@]} -eq 0 ] && { echo -e "  ${DIM}No full backups found.${NC}"; press_enter; return; }

    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select backup: " choice
    [ "$choice" = "0" ] && return

    local selected="${backups[$((choice-1))]}"
    echo -e "${RED}This will REPLACE your current setup!${NC}"
    if ! confirm "  Are you sure?" "n"; then return; fi

    echo -e "${YELLOW}Restoring...${NC}"
    cd "$PALLADIUM_HOME/.."
    tar xzf "$selected" 2>/dev/null

    echo -e "${GREEN}Full restore complete!${NC}"
    echo -e "${DIM}You may need to restart services.${NC}"
    press_enter
}

compare_drives() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Compare Drives ═══${NC}"
    echo ""

    local source=$(prompt_value "  Source drive path")
    local target=$(prompt_value "  Target drive path")

    echo ""
    echo -e "${CYAN}Source:${NC}"
    du -sh "$source/palladium" 2>/dev/null || echo "  Not found"
    ls "$source/palladium/data/installed" 2>/dev/null | sed 's/^/  /'

    echo ""
    echo -e "${CYAN}Target:${NC}"
    du -sh "$target/palladium" 2>/dev/null || echo "  Not found"
    ls "$target/palladium/data/installed" 2>/dev/null | sed 's/^/  /'

    echo ""
    echo -e "${CYAN}Differences:${NC}"
    diff <(ls "$source/palladium/data/installed" 2>/dev/null) <(ls "$target/palladium/data/installed" 2>/dev/null) 2>/dev/null || echo "  (comparison shown above)"

    press_enter
}

clone_to_drive() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Clone to Drive ═══${NC}"
    echo ""

    local target=$(prompt_value "  Target path")
    [ -z "$target" ] && return

    if [ ! -d "$target" ]; then
        echo -e "${RED}Target does not exist: $target${NC}"
        press_enter
        return
    fi

    local target_free=$(df -m "$target" 2>/dev/null | awk 'NR==2 {print $4}')
    local source_size=$(du -sh "$PALLADIUM_HOME" 2>/dev/null | cut -f1)
    echo ""
    echo -e "  Source size: ${BOLD}$source_size${NC}"
    echo -e "  Target free: ${BOLD}${target_free}MB${NC}"
    echo ""

    if ! confirm "  Clone to $target?"; then return; fi

    echo -e "${YELLOW}Cloning Palladium to $target...${NC}"
    rsync -av --progress "$PALLADIUM_HOME/" "$target/palladium/" 2>/dev/null || \
    cp -ra "$PALLADIUM_HOME" "$target/palladium" 2>/dev/null

    echo -e "${GREEN}Clone complete.${NC}"
    press_enter
}

clone_from_drive() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Clone from Drive ═══${NC}"
    echo ""

    local source=$(prompt_value "  Source path containing palladium")
    [ -z "$source" ] && return

    if [ ! -d "$source" ]; then
        echo -e "${RED}Source not found: $source${NC}"
        press_enter
        return
    fi

    echo -e "${YELLOW}Cloning from $source...${NC}"
    rsync -av --progress "$source/" "$PALLADIUM_HOME/" 2>/dev/null || \
    cp -ra "$source"/* "$PALLADIUM_HOME/" 2>/dev/null

    echo -e "${GREEN}Clone complete.${NC}"
    press_enter
}
