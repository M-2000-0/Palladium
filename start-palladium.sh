#!/bin/bash
# start-palladium.sh - Terminal launcher for Linux/macOS
# Launches the Server terminal app (Python TUI) with auto-setup.
# Falls back to Palladium bash menu if Python is unavailable.

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$DIR/Server"
PALLADIUM_DIR="$DIR/palladium"

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

PALLADIUM_DIR="$(find_project_dir || true)"

if [ -z "$PALLADIUM_DIR" ]; then
    echo "Palladium project directory not found."
    echo "Make sure the SSD is mounted and contains the project folder."
    exit 1
fi

SERVER_DIR="$DIR/Server"
if [ ! -d "$SERVER_DIR" ]; then
    SERVER_DIR="$PALLADIUM_DIR/../Server"
fi

launch_server() {
    # Find Python
    PYTHON=""
    for cmd in python3 python; do
        command -v "$cmd" &>/dev/null && { PYTHON="$cmd"; break; }
    done

    if [ -n "$PYTHON" ] && [ -f "$SERVER_DIR/server.py" ]; then
        # Auto-install deps
        if ! "$PYTHON" -c "import rich" 2>/dev/null; then
            "$PYTHON" -m pip install -q rich psutil 2>/dev/null
        fi
        cd "$SERVER_DIR"
        exec "$PYTHON" server.py
    fi
    return 1
}

# Try Server first (Python TUI)
launch_server && exit 0

# Fallback: open Palladium bash menu in a terminal window
if command -v x-terminal-emulator &>/dev/null; then
    x-terminal-emulator -e "cd '$PALLADIUM_DIR' && bash palladium; echo 'Stopped. Press Enter.'; read"
elif command -v gnome-terminal &>/dev/null; then
    gnome-terminal -- bash -c "cd '$PALLADIUM_DIR' && bash palladium; echo 'Stopped. Press Enter.'; read"
elif command -v xterm &>/dev/null; then
    xterm -e "cd '$PALLADIUM_DIR' && bash palladium; echo 'Stopped. Press Enter.'; read"
elif command -v konsole &>/dev/null; then
    konsole --hold -e "cd '$PALLADIUM_DIR' && bash palladium"
elif [ "$(uname)" = "Darwin" ]; then
    osascript -e "tell application \"Terminal\" to do script \"cd '$PALLADIUM_DIR' && bash palladium\""
else
    cd "$PALLADIUM_DIR"
    exec bash palladium
fi
