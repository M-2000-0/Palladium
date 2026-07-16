#!/bin/bash
# autorun.sh - Configure USB autorun for Palladium (Windows/Mac/Linux)
# Called by: palladium setup-autorun

autorun_setup() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ USB Autorun Setup ═══${NC}"
    echo ""

    local target_dir="$PALLADIUM_HOME/.."

    echo -e "  ${BOLD}Copying autorun files to USB root:${NC}"
    echo -e "    ${target_dir}"
    echo ""

    echo -e "  ${SILVER}Cross-platform launchers:${NC}"

    # Windows
    cp "$PALLADIUM_HOME/autorun.inf" "$target_dir/autorun.inf" 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} autorun.inf        (Windows AutoPlay)" || \
        echo -e "  ${YELLOW}✗${NC} autorun.inf"
    cp "$PALLADIUM_HOME/start-palladium.bat" "$target_dir/start-palladium.bat" 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} start-palladium.bat (Windows batch)" || \
        echo -e "  ${YELLOW}✗${NC} start-palladium.bat"

    # Linux / macOS
    cp "$PALLADIUM_HOME/start-palladium.sh" "$target_dir/start-palladium.sh" 2>/dev/null && \
        chmod +x "$target_dir/start-palladium.sh" 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} start-palladium.sh  (Linux/Mac shell)" || \
        echo -e "  ${YELLOW}✗${NC} start-palladium.sh"

    # macOS double-click
    if [ -f "$PALLADIUM_HOME/start-palladium.command" ]; then
        cp "$PALLADIUM_HOME/start-palladium.command" "$target_dir/start-palladium.command" && \
            chmod +x "$target_dir/start-palladium.command" && \
            echo -e "  ${GREEN}✓${NC} start-palladium.command (macOS double-click)" || \
            echo -e "  ${YELLOW}✗${NC} start-palladium.command"
    fi

    echo ""
    echo -e "  ${SILVER}Background monitor scripts (inside palladium/):${NC}"
    echo -e "  ${GREEN}✓${NC} watch-usb.ps1         (Windows PowerShell)"
    echo -e "  ${GREEN}✓${NC} watch-usb.sh          (Linux/Mac shell)"
    echo -e "  ${GREEN}✓${NC} install-autorun.ps1   (Windows Task Scheduler installer)"
    echo -e "  ${GREEN}✓${NC} install-autorun.sh    (Linux/Mac systemd/launchd installer)"
    echo -e "  ${GREEN}✓${NC} com.palladium.watch.plist (macOS launchd agent)"

    echo ""
    echo -e "${GREEN}  Autorun files ready on USB root!${NC}"
    echo ""

    # --- Detect OS ---
    local os=""
    if [ -n "$WINDIR" ] || [ -n "$SYSTEMROOT" ]; then
        os="windows"
    elif [ "$(uname)" = "Darwin" ]; then
        os="macos"
    elif command -v lsblk &>/dev/null || [ -d /sys/class/dmi ]; then
        os="linux"
    else
        os="other"
    fi

    case "$os" in
        windows)
            echo -e "  ${BOLD}${SILVER}Windows setup:${NC}"
            echo ""
            echo -e "    ${GREEN}1.${NC} Double-click ${SILVER}start-palladium.bat${NC} on the USB"
            echo -e "    ${GREEN}2.${NC} Install Task Scheduler (auto-start on USB insert)"
            echo ""
            if confirm "  Install Task Scheduler autorun?"; then
                echo ""
                echo -e "  ${SILVER}Launching PowerShell installer...${NC}"
                echo ""
                if command -v powershell &>/dev/null; then
                    powershell -NoProfile -ExecutionPolicy Bypass -File "$PALLADIUM_HOME/install-autorun.ps1"
                    echo ""
                    echo -e "  ${GREEN}Task Scheduler installed!${NC}"
                else
                    echo -e "  ${RED}PowerShell not found. Run manually:${NC}"
                    echo -e "  ${SILVER}powershell -File palladium\\install-autorun.ps1${NC}"
                fi
            fi
            ;;
        macos)
            echo -e "  ${BOLD}${SILVER}macOS setup:${NC}"
            echo ""
            echo -e "    ${GREEN}1.${NC} Double-click ${SILVER}start-palladium.command${NC} on the USB"
            echo -e "    ${GREEN}2.${NC} Install launchd agent (auto-start on USB insert)"
            echo ""
            if confirm "  Install launchd autorun?"; then
                echo ""
                echo -e "  ${SILVER}Running installer...${NC}"
                echo ""
                if command -v osascript &>/dev/null; then
                    osascript -e "tell application \"Terminal\" to do script \"bash '$PALLADIUM_HOME/install-autorun.sh'\"" &
                    echo -e "  ${GREEN}Installer launched in Terminal.${NC}"
                    echo -e "  ${DIM}Follow the prompts in the Terminal window.${NC}"
                else
                    bash "$PALLADIUM_HOME/install-autorun.sh"
                fi
            fi
            ;;
        linux)
            echo -e "  ${BOLD}${SILVER}Linux setup:${NC}"
            echo ""
            echo -e "    ${GREEN}1.${NC} Double-click ${SILVER}start-palladium.sh${NC} in your file manager"
            echo -e "    ${GREEN}2.${NC} Install systemd user service (auto-start on USB insert)"
            echo ""
            if confirm "  Install systemd autorun?"; then
                echo ""
                echo -e "  ${SILVER}Running installer...${NC}"
                echo ""
                bash "$PALLADIUM_HOME/install-autorun.sh"
            fi
            ;;
        other)
            echo -e "  ${YELLOW}Unknown OS. Manual setup:${NC}"
            echo ""
            echo -e "    Run: ${SILVER}bash palladium/start-palladium.sh${NC} from USB root"
            ;;
    esac

    echo ""
    local choice
    read -n 1 -s -r -p "  Press any key to return..." choice
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Run via: palladium setup-autorun"
    exit 1
fi
