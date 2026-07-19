#!/bin/bash
# start-palladium.sh - Terminal launcher for Linux/macOS
# Run this from the USB root to open Palladium in a visible terminal.

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

find_project_dir() {
    if [ -d "$DIR/palladium" ]; then
        echo "$DIR/palladium"
        return 0
    fi

    for candidate in \
        "$DIR" \
        "$DIR/../palladium" \
        /media/*/*/palladium \
        /mnt/*/*/palladium \
        /media/*/palladium \
        /mnt/*/palladium; do
        [ -d "$candidate" ] && { echo "$candidate"; return 0; }
    done
    return 1
}

PROJECT_DIR="$(find_project_dir)"

if [ -z "$PROJECT_DIR" ]; then
    echo "Palladium project directory not found."
    echo "Make sure the SSD is mounted and contains the project folder."
    exit 1
fi

# Try to open in a new terminal window, fall back to current shell
if command -v x-terminal-emulator &>/dev/null; then
    x-terminal-emulator -e "cd '$PROJECT_DIR' && bash palladium; echo 'Palladium stopped. Press Enter to close.'; read"
elif command -v gnome-terminal &>/dev/null; then
    gnome-terminal -- bash -c "cd '$PROJECT_DIR' && bash palladium; echo 'Palladium stopped. Press Enter to close.'; read"
elif command -v xterm &>/dev/null; then
    xterm -e "cd '$PROJECT_DIR' && bash palladium; echo 'Palladium stopped. Press Enter to close.'; read"
elif command -v konsole &>/dev/null; then
    konsole --hold -e "cd '$PROJECT_DIR' && bash palladium"
elif [ "$(uname)" = "Darwin" ]; then
    osascript -e "tell application \"Terminal\" to do script \"cd '$PROJECT_DIR' && bash palladium\""
else
    echo "  ============================================================"
    echo "    PALLADIUM PORTABLE SERVER"
    echo "    Plug in. Power up. Host anything."
    echo "  ============================================================"
    echo ""
    cd "$PROJECT_DIR"
    exec bash palladium
fi
