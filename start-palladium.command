#!/bin/bash
# start-palladium.command - macOS double-click launcher
# Launches Server (Python TUI), falls back to Palladium bash menu

DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$DIR/Server"

# Try Python TUI first
if command -v python3 &>/dev/null && [ -f "$SERVER_DIR/server.py" ]; then
    python3 -m pip install -q rich psutil 2>/dev/null
    cd "$SERVER_DIR"
    exec python3 server.py
fi

# Fallback to bash menu
cd "$DIR/palladium"
exec bash palladium
