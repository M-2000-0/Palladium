#!/bin/bash
# watch-usb.sh - Background USB monitor for Linux/macOS
# Polls for the Palladium USB drive and auto-launches in a terminal.
# Used by: systemd user service (Linux), launchd (macOS)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MARKER="$USB_ROOT/autorun.inf"
LAUNCHER="$USB_ROOT/start-palladium.sh"
POLL_INTERVAL=3
LOG="$HOME/.palladium-watch.log"

echo "[$(date)] watch-usb.sh started. Watching for: $MARKER" >> "$LOG"

while true; do
    if [ -f "$MARKER" ] && [ -f "$LAUNCHER" ]; then
        echo "[$(date)] USB detected - launching Palladium" >> "$LOG"

        # Open in terminal (platform-specific)
        if [ "$(uname)" = "Darwin" ]; then
            osascript -e "tell application \"Terminal\" to do script \"cd '$SCRIPT_DIR' && bash palladium\""
        elif command -v x-terminal-emulator &>/dev/null; then
            x-terminal-emulator -e "cd '$SCRIPT_DIR' && bash palladium; echo 'Palladium stopped. Press Enter.'; read" &
        elif command -v gnome-terminal &>/dev/null; then
            gnome-terminal -- bash -c "cd '$SCRIPT_DIR' && bash palladium; echo 'Palladium stopped. Press Enter.'; read" &
        elif command -v xterm &>/dev/null; then
            xterm -e "cd '$SCRIPT_DIR' && bash palladium; echo 'Palladium stopped. Press Enter.'; read" &
        else
            cd "$SCRIPT_DIR" && bash palladium
        fi

        # Block until USB is removed
        while [ -f "$MARKER" ]; do
            sleep "$POLL_INTERVAL"
        done
        echo "[$(date)] USB removed" >> "$LOG"
    fi
    sleep "$POLL_INTERVAL"
done
