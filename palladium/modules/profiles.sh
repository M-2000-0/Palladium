#!/bin/bash
# profiles.sh - Multi-user, profiles, configurations

PROFILES_DIR="$DATA_DIR/profiles"
mkdir -p "$PROFILES_DIR"

profiles_menu() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Profiles & Users ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Switch profile${NC}       Different configurations"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Create profile${NC}      New configuration set"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Export profile${NC}      Save current setup"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Import profile${NC}      Load a setup"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}User management${NC}     Add/remove users (SSH)"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) switch_profile ;;
        2) create_profile ;;
        3) export_profile ;;
        4) import_profile ;;
        5) user_management ;;
        0) return ;;
    esac
}

switch_profile() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Profiles ═══${NC}"
    echo ""

    local profiles=()
    local i=1

    # Current profile
    local current=$(cat "$DATA_DIR/.profile" 2>/dev/null || echo "default")
    echo -e "  ${YELLOW}Current: $current${NC}"
    echo ""

    for profile_dir in "$PROFILES_DIR"/*/; do
        [ -d "$profile_dir" ] || continue
        local name=$(basename "$profile_dir")
        profiles+=("$name")
        local marker=""
        [ "$name" = "$current" ] && marker=" ${GREEN}(active)${NC}"
        echo -e "  ${BOLD}[$i]${NC}  ${GREEN}$name${NC}$marker"
        ((i++))
    done

    # Add default
    echo -e "  ${BOLD}[$i]${NC}  ${GREEN}default${NC}"
    profiles+=("default")

    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select profile: " choice

    if [ "$choice" = "0" ] || [ -z "$choice" ]; then return; fi
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#profiles[@]}" ]; then
        local selected="${profiles[$((choice-1))]}"
        echo "$selected" > "$DATA_DIR/.profile"

        # Copy profile data
        if [ "$selected" != "default" ] && [ -d "$PROFILES_DIR/$selected" ]; then
            cp -r "$PROFILES_DIR/$selected/"* "$INSTALLED_DIR/" 2>/dev/null
        fi

        echo -e "${GREEN}Switched to profile: $selected${NC}"
    fi
    press_enter
}

create_profile() {
    echo ""
    local name=$(prompt_value "  Profile name")
    [ -z "$name" ] && return

    mkdir -p "$PROFILES_DIR/$name"

    # Save current services as profile
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local svc_name=$(basename "$svc_dir")
        cp -r "$svc_dir" "$PROFILES_DIR/$name/"
    done

    # Save metadata
    cat > "$PROFILES_DIR/$name/.profile_meta" << EOF
name=$name
created=$(date -Iseconds)
services=$(ls "$INSTALLED_DIR" 2>/dev/null | tr '\n' ',')
EOF

    echo -e "${GREEN}Profile created: $name${NC}"
    press_enter
}

export_profile() {
    echo ""
    local name=$(prompt_value "  Profile name" "default")
    local export_file="$DATA_WORKSPACE/exports/profile-$name-$(date +%Y%m%d).tar.gz"

    cd "$DATA_DIR"
    tar czf "$export_file" profiles/$name/ installed/ 2>/dev/null

    echo -e "${GREEN}Profile exported: $export_file${NC}"
    press_enter
}

import_profile() {
    echo ""
    local file=$(prompt_value "  Profile archive path")
    [ -z "$file" ] || [ ! -f "$file" ] && { echo -e "${RED}File not found.${NC}"; press_enter; return; }

    echo -e "${YELLOW}Importing profile...${NC}"
    cd "$DATA_DIR"
    tar xzf "$file" 2>/dev/null

    echo -e "${GREEN}Profile imported.${NC}"
    press_enter
}

user_management() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ User Management ═══${NC}"
    echo ""
    echo -e "  ${DIM}Manage system users for SSH access.${NC}"
    echo ""

    echo -e "  ${BOLD}[1]${NC}  Add a user"
    echo -e "  ${BOLD}[2]${NC}  Remove a user"
    echo -e "  ${BOLD}[3]${NC}  List users"
    echo -e "  ${BOLD}[4]${NC}  Set user password"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1)
            local username=$(prompt_value "  Username")
            sudo adduser "$username" 2>/dev/null
            echo -e "${GREEN}User $username created.${NC}"
            ;;
        2)
            local username=$(prompt_value "  Username to remove")
            sudo deluser "$username" 2>/dev/null
            echo -e "${GREEN}User $username removed.${NC}"
            ;;
        3)
            echo ""
            echo -e "${CYAN}System users:${NC}"
            cat /etc/passwd | grep -v nologin | grep -v false | awk -F: '{print "  " $1 " (uid:" $3 ")"}'
            ;;
        4)
            local username=$(prompt_value "  Username")
            sudo passwd "$username" 2>/dev/null
            ;;
        0) return ;;
    esac
    press_enter
}

profile_create() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Create Profile ═══${NC}"
    echo ""

    local name=$(prompt_value "  Profile name")
    [ -z "$name" ] && return

    mkdir -p "$PROFILES_DIR/$name"

    cat > "$PROFILES_DIR/$name/.meta" << EOF
name=$name
created=$(date -Iseconds)
EOF

    echo -e "${GREEN}Profile created: $name${NC}"
    press_enter
}

profile_switch() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Switch Profile ═══${NC}"
    echo ""

    local profiles=()
    local i=1
    for profile_dir in "$PROFILES_DIR"/*/; do
        [ -d "$profile_dir" ] || continue
        local name=$(basename "$profile_dir")
        profiles+=("$name")
        echo -e "  ${BOLD}[$i]${NC}  ${GREEN}$name${NC}"
        ((i++))
    done

    [ ${#profiles[@]} -eq 0 ] && { echo -e "  ${DIM}No profiles found.${NC}"; press_enter; return; }

    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select profile: " choice
    [ "$choice" = "0" ] && return

    local selected="${profiles[$((choice-1))]}"
    echo "$selected" > "$DATA_DIR/.active_profile"

    echo -e "${GREEN}Switched to profile: $selected${NC}"
    press_enter
}

profile_export() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Export Profile ═══${NC}"
    echo ""

    local profiles=()
    local i=1
    for profile_dir in "$PROFILES_DIR"/*/; do
        [ -d "$profile_dir" ] || continue
        local name=$(basename "$profile_dir")
        profiles+=("$name")
        echo -e "  ${BOLD}[$i]${NC}  ${GREEN}$name${NC}"
        ((i++))
    done

    [ ${#profiles[@]} -eq 0 ] && { echo -e "  ${DIM}No profiles.${NC}"; press_enter; return; }
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select profile: " choice
    [ "$choice" = "0" ] && return

    local selected="${profiles[$((choice-1))]}"
    local export_path=$(prompt_value "  Export path")
    [ -z "$export_path" ] && return

    mkdir -p "$export_path"
    cp -r "$PROFILES_DIR/$selected" "$export_path/"
    echo -e "${GREEN}Profile exported to $export_path/$selected${NC}"
    press_enter
}

profile_import() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Import Profile ═══${NC}"
    echo ""

    local source=$(prompt_value "  Source profile path")
    [ -z "$source" ] && return

    if [ ! -d "$source" ]; then
        echo -e "${RED}Source not found.${NC}"
        press_enter
        return
    fi

    cp -r "$source" "$PROFILES_DIR/"
    echo -e "${GREEN}Profile imported.${NC}"
    press_enter
}

profile_manage_users() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ SSH User Management ═══${NC}"
    echo ""

    echo -e "  ${DIM}Manage system users for SSH access.${NC}"
    echo ""
    echo -e "  ${YELLOW}To add a user:${NC}"
    echo -e "    ${CYAN}sudo adduser <username>${NC}"
    echo ""
    echo -e "  ${YELLOW}To modify a user:${NC}"
    echo -e "    ${CYAN}sudo usermod -aG sudo <username>${NC}"
    echo ""
    echo -e "  ${CYAN}Current users:${NC}"
    cat /etc/passwd 2>/dev/null | grep -v nologin | grep -v false | awk -F: '{print "    " $1 " (uid:" $3 ")"}'

    press_enter
}
