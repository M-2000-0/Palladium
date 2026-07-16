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

# Track launched Palladium instance PID
PALLADIUM_PID=""

# When USB is removed or watch script stops, clean up Docker services
cleanup_palladium() {
    if [ -n "$PALLADIUM_PID" ] && kill -0 "$PALLADIUM_PID" 2>/dev/null; then
        echo "[$(date)] Stopping Palladium (PID $PALLADIUM_PID)..." >> "$LOG"
        kill "$PALLADIUM_PID" 2>/dev/null
        wait "$PALLADIUM_PID" 2>/dev/null
    fi
    # Stop any remaining Palladium-managed Docker containers
    for svc_dir in "$SCRIPT_DIR"/data/installed/*/; do
        [ -d "$svc_dir" ] || continue
        (cd "$svc_dir" && docker compose down 2>/dev/null || docker-compose down 2>/dev/null)
    done
}
trap cleanup_palladium EXIT SIGINT SIGTERM

echo "[$(date)] watch-usb.sh started. Watching for: $MARKER" >> "$LOG"

while true; do
    if [ -f "$MARKER" ] && [ -f "$LAUNCHER" ]; then
        echo "[$(date)] USB detected - launching Palladium" >> "$LOG"

        # Open in terminal (platform-specific)
        # Use the launcher script which auto-selects Server (Python TUI) or Palladium
        if [ "$(uname)" = "Darwin" ]; then
            osascript -e "tell application \"Terminal\" to do script \"cd '$USB_ROOT' && bash '$LAUNCHER'\""
        elif command -v x-terminal-emulator &>/dev/null; then
            x-terminal-emulator -e "cd '$USB_ROOT' && bash '$LAUNCHER'; echo 'Server stopped. Press Enter.'; read" &
        elif command -v gnome-terminal &>/dev/null; then
            gnome-terminal -- bash -c "cd '$USB_ROOT' && bash '$LAUNCHER'; echo 'Server stopped. Press Enter.'; read" &
        elif command -v xterm &>/dev/null; then
            xterm -e "cd '$USB_ROOT' && bash '$LAUNCHER'; echo 'Server stopped. Press Enter.'; read" &
        else
            cd "$USB_ROOT" && bash "$LAUNCHER"
        fi

        # Block until USB is removed
        while [ -f "$MARKER" ]; do
            sleep "$POLL_INTERVAL"
        done
        echo "[$(date)] USB removed" >> "$LOG"
    fi
    sleep "$POLL_INTERVAL"
done
