#!/bin/bash
# usb.sh - USB drive detection and management

USB_MIN_STORAGE_MB=200
USB_WARN_STORAGE_MB=500
USB_RECOMMENDED_MB=2000

detect_usb_drive() {
    # Find all mounted removable drives
    local drives=()

    # Method 1: lsblk (Linux)
    if command -v lsblk &>/dev/null; then
        while IFS= read -r line; do
            local dev=$(echo "$line" | awk '{print $1}')
            local mount=$(echo "$line" | awk '{print $7}')
            local size=$(echo "$line" | awk '{print $4}')
            local rm=$(echo "$line" | awk '{print $2}')
            if [ "$rm" = "1" ] && [ -n "$mount" ] && [ "$mount" != "/" ]; then
                drives+=("$mount|$size|$dev")
            fi
        done < <(lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,RM -rn 2>/dev/null | grep "part")
    fi

    # Method 2: findmnt (Linux)
    if [ ${#drives[@]} -eq 0 ] && command -v findmnt &>/dev/null; then
        while IFS= read -r line; do
            local mount=$(echo "$line" | awk '{print $1}')
            local fstype=$(echo "$line" | awk '{print $2}')
            local size=$(df -m "$mount" 2>/dev/null | awk 'NR==2 {print $2}')
            if [ -n "$mount" ] && [ "$fstype" != "tmpfs" ] && [ "$fstype" != "squashfs" ]; then
                drives+=("$mount|${size}M|auto")
            fi
        done < <(findmnt -rno TARGET,FSTYPE 2>/dev/null)
    fi

    # Method 3: /media/ scan
    if [ ${#drives[@]} -eq 0 ]; then
        for dir in /media/*/  /media/*/*/; do
            [ -d "$dir" ] || continue
            if [ -f "$dir/palladium" ] || [ -d "$dir/palladium" ]; then
                local size=$(df -m "$dir" 2>/dev/null | awk 'NR==2 {print $2}')
                drives+=("$dir|${size}M|auto")
            fi
        done
    fi

    # Method 4: Check if palladium is running from a removable drive
    if [ ${#drives[@]} -eq 0 ]; then
        local palladium_dev=$(df "$PALLADIUM_HOME" 2>/dev/null | awk 'NR==2 {print $1}')
        if [ -n "$palladium_dev" ]; then
            local is_removable=false
            if [ -b "$palladium_dev" ]; then
                local dev_name=$(basename "$palladium_dev")
                if [ -f "/sys/block/$dev_name/removable" ]; then
                    local removable=$(cat "/sys/block/$dev_name/removable" 2>/dev/null)
                    [ "$removable" = "1" ] && is_removable=true
                fi
            fi

            if $is_removable; then
                local mount=$(df "$PALLADIUM_HOME" 2>/dev/null | awk 'NR==2 {print $6}')
                local size=$(df -m "$PALLADIUM_HOME" 2>/dev/null | awk 'NR==2 {print $2}')
                drives+=("$mount|${size}M|$palladium_dev")
            fi
        fi
    fi

    # Return results
    if [ ${#drives[@]} -gt 0 ]; then
        printf '%s\n' "${drives[@]}"
    fi

    return 0
}

get_drive_type() {
    local mount="$1"
    local size_mb="${2:-0}"

    # Check removable flag
    local is_removable=false
    local dev_name=$(lsblk -no PKNAME,MOUNTPOINT 2>/dev/null | grep "$mount" | awk '{print $1}' | head -1)
    if [ -n "$dev_name" ] && [ -f "/sys/block/$dev_name/removable" ]; then
        local removable=$(cat "/sys/block/$dev_name/removable" 2>/dev/null)
        [ "$removable" = "1" ] && is_removable=true
    fi

    if ! $is_removable; then
        echo "internal"
        return
    fi

    # Classify by size
    if [ "$size_mb" -lt 32000 ]; then
        echo "usb"       # < 32GB = USB drive
    elif [ "$size_mb" -lt 256000 ]; then
        echo "ssd-small" # 32GB - 256GB = small SSD or large USB
    else
        echo "ssd"       # > 256GB = SSD
    fi
}

check_usb_storage() {
    local mount="$1"
    local available_mb=$(df -m "$mount" 2>/dev/null | awk 'NR==2 {print $4}')

    if [ -z "$available_mb" ]; then
        echo -e "${YELLOW}  Could not check storage.${NC}"
        return 0
    fi

    local drive_type=$(get_drive_type "$mount" "$(( $(df -m "$mount" 2>/dev/null | awk 'NR==2 {print $2}') ))")

    echo -e "${SILVER}  Drive: ${BOLD}$mount${NC}"
    echo -e "  Type:  ${BOLD}$drive_type${NC}"
    echo -e "  Free:  ${BOLD}${available_mb}MB${NC}"
    echo ""

    if [ "$drive_type" = "usb" ]; then
        echo -e "  ${YELLOW}USB Drive Detected${NC}"
        echo ""

        if [ "$available_mb" -lt "$USB_MIN_STORAGE_MB" ]; then
            echo -e "${RED}  Not enough space. Need at least ${USB_MIN_STORAGE_MB}MB.${NC}"
            echo -e "  ${DIM}Remove files from the USB or use a larger drive.${NC}"
            return 1
        fi

        if [ "$available_mb" -lt "$USB_WARN_STORAGE_MB" ]; then
            echo -e "${YELLOW}  Low space. Only ${available_mb}MB free.${NC}"
            echo -e "  ${DIM}Consider a larger USB or removing files.${NC}"
            echo ""
        fi

        # Warn about USB performance
        echo -e "  ${DIM}Note: USB drives are slower than SSDs.${NC}"
        echo -e "  ${DIM}Services may take longer to start.${NC}"
        echo ""
        return 0
    fi

    # SSD or internal - less restrictive
    if [ "$available_mb" -lt "$USB_MIN_STORAGE_MB" ]; then
        echo -e "${RED}  Not enough space. Need at least ${USB_MIN_STORAGE_MB}MB.${NC}"
        return 1
    fi

    if [ "$available_mb" -lt "$USB_WARN_STORAGE_MB" ]; then
        echo -e "${YELLOW}  Low space: ${available_mb}MB free.${NC}"
        echo ""
    fi

    return 0
}

usb_optimize_mode() {
    local mount="$1"
    local drive_type=$(get_drive_type "$mount" "$(df -m "$mount" 2>/dev/null | awk 'NR==2 {print $2}')")

    if [ "$drive_type" = "usb" ]; then
        echo -e "${SILVER}  USB Mode: Minimal footprint activated${NC}"
        echo ""

        # Set environment for minimal mode
        export PALLADIUM_MODE="usb"

        # Recommendations
        echo -e "  ${DIM}Recommendations for USB drives:${NC}"
        echo -e "    - Use smaller Docker images (alpine variants)"
        echo -e "    - Limit log sizes"
        echo -e "    - Use SQLite instead of PostgreSQL"
        echo -e "    - Avoid large datasets"
        echo ""
        return 0
    fi

    export PALLADIUM_MODE="ssd"
    return 1
}

show_usb_info() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Drive Information ═══${NC}"
    echo ""

    local drives
    drives=$(detect_usb_drive)

    if [ -z "$drives" ]; then
        echo -e "  ${DIM}No removable drives detected.${NC}"
        echo -e "  ${DIM}Plug in a USB or SSD to use Palladium.${NC}"
        echo ""
        echo -e "  ${BOLD}Supported drives:${NC}"
        echo -e "    - USB flash drives (8GB+)"
        echo -e "    - External SSDs"
        echo -e "    - External HDDs"
        echo ""
        press_enter
        return
    fi

    echo -e "  ${BOLD}Detected drives:${NC}"
    echo ""

    while IFS='|' read -r mount size dev; do
        local drive_type=$(get_drive_type "$mount" "$(echo "$size" | tr -d 'M')")
        local type_color="${GREEN}"
        [ "$drive_type" = "usb" ] && type_color="${YELLOW}"
        [ "$drive_type" = "ssd-small" ] && type_color="${SILVER}"

        echo -e "    ${BOLD}$mount${NC}"
        echo -e "      Type: ${type_color}$drive_type${NC}"
        echo -e "      Size: $size"
        echo -e "      Device: $dev"
        echo ""

        # Check for palladium
        if [ -f "$mount/palladium/palladium" ] || [ -f "$mount/palladium" ]; then
            echo -e "      ${GREEN}Palladium detected!${NC}"
        else
            echo -e "      ${DIM}Palladium not found.${NC}"
            echo -e "      ${DIM}Run: cp -r palladium/ $mount/${NC}"
        fi
        echo ""
    done <<< "$drives"

    press_enter
}

install_to_drive() {
    local target_drive="$1"

    echo -e "${YELLOW}Installing Palladium to $target_drive...${NC}"

    # Copy palladium files
    cp -r "$PALLADIUM_HOME" "$target_drive/palladium"

    if [ -f "$target_drive/palladium/palladium" ]; then
        chmod +x "$target_drive/palladium/palladium"
        chmod +x "$target_drive/palladium/install.sh"
        echo -e "${GREEN}Palladium installed to $target_drive!${NC}"
        echo ""
        echo -e "  To use on another computer:"
        echo -e "    1. Plug in the drive"
        echo -e "    2. Run: ${SILVER}$target_drive/palladium/install.sh${NC}"
        echo -e "    3. Then: ${SILVER}palladium${NC}"
    else
        echo -e "${RED}Installation failed.${NC}"
    fi

    press_enter
}
