#!/bin/bash
# install-autorun.sh - Install USB autorun for Linux (systemd) or macOS (launchd)
# Usage: bash install-autorun.sh [--remove]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WATCH_SCRIPT="$SCRIPT_DIR/watch-usb.sh"

remove_autorun() {
    echo "Removing autorun..."
    if [ "$(uname)" = "Darwin" ]; then
        launchctl unload ~/Library/LaunchAgents/com.palladium.watch.plist 2>/dev/null || true
        rm -f ~/Library/LaunchAgents/com.palladium.watch.plist
        echo "  Removed macOS launchd agent."
    elif systemctl --user &>/dev/null 2>&1; then
        systemctl --user stop palladium-watch.service 2>/dev/null || true
        systemctl --user disable palladium-watch.service 2>/dev/null || true
        rm -f ~/.config/systemd/user/palladium-watch.service
        systemctl --user daemon-reload 2>/dev/null || true
        echo "  Removed Linux systemd service."
    fi
    echo "Done."
    exit 0
}

if [ "$1" = "--remove" ]; then
    remove_autorun
fi

echo ""
echo "  ============================================================"
echo "    Palladium USB Autorun - Linux/macOS Installer"
echo "  ============================================================"
echo ""
echo "  USB root: $USB_ROOT"
echo "  Watch script: $WATCH_SCRIPT"
echo ""

if [ ! -f "$WATCH_SCRIPT" ]; then
    echo "  ERROR: $WATCH_SCRIPT not found."
    exit 1
fi

if [ "$(uname)" = "Darwin" ]; then
    # --- macOS: install launchd LaunchAgent ---
    echo "  Installing macOS launchd agent..."
    mkdir -p ~/Library/LaunchAgents

    cp "$SCRIPT_DIR/com.palladium.watch.plist" ~/Library/LaunchAgents/
    launchctl load ~/Library/LaunchAgents/com.palladium.watch.plist

    echo ""
    echo "  SUCCESS: Palladium USB autorun installed (launchd agent)."
    echo ""
    echo "  How it works:"
    echo "    - Runs at every login in the background"
    echo "    - Checks every 5s if the Palladium USB is mounted"
    echo "    - When detected -> opens Terminal with Palladium"
    echo ""
    echo "  To remove:"
    echo "    bash install-autorun.sh --remove"
    echo ""

elif systemctl --user &>/dev/null 2>&1; then
    # --- Linux: install systemd user service ---
    echo "  Installing Linux systemd user service..."

    mkdir -p ~/.config/systemd/user

    cat > ~/.config/systemd/user/palladium-watch.service << EOF
[Unit]
Description=Palladium USB Autorun
After=network.target

[Service]
Type=simple
ExecStart=$WATCH_SCRIPT
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable palladium-watch.service
    systemctl --user start palladium-watch.service

    echo ""
    echo "  SUCCESS: Palladium USB autorun installed (systemd service)."
    echo ""
    echo "  How it works:"
    echo "    - Runs at every login in the background"
    echo "    - Checks every 3s if the Palladium USB is mounted"
    echo "    - When detected -> opens terminal with Palladium"
    echo ""
    echo "  To remove:"
    echo "    bash install-autorun.sh --remove"
    echo ""
    echo "  For udev-based autorun (auto-start on plug, no polling):"
    echo "    Not installed by default (needs root). See palladium setup-autorun."
    echo ""

else
    echo "  Neither launchd (macOS) nor systemd (Linux) detected."
    echo "  Falling back to crontab entry..."
    echo ""

    # Fallback: crontab entry
    (crontab -l 2>/dev/null | grep -v "watch-usb.sh"; echo "@reboot $WATCH_SCRIPT") | crontab -
    echo "  Added @reboot crontab entry for $WATCH_SCRIPT"
    echo ""
    echo "  SUCCESS: Crontab entry added."
    echo ""
fi

echo "  Press any key to return..."
read -n 1 -s -r
echo ""
