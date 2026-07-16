#!/bin/bash
# start-palladium.sh - Terminal launcher for Linux/macOS
# Run this from the USB root to open Palladium in a visible terminal.

DIR="$(cd "$(dirname "$0")" && pwd)"

# Try to open in a new terminal window, fall back to current shell
if command -v x-terminal-emulator &>/dev/null; then
    x-terminal-emulator -e "cd '$DIR/palladium' && bash palladium; echo 'Palladium stopped. Press Enter to close.'; read"
elif command -v gnome-terminal &>/dev/null; then
    gnome-terminal -- bash -c "cd '$DIR/palladium' && bash palladium; echo 'Palladium stopped. Press Enter to close.'; read"
elif command -v xterm &>/dev/null; then
    xterm -e "cd '$DIR/palladium' && bash palladium; echo 'Palladium stopped. Press Enter to close.'; read"
elif command -v konsole &>/dev/null; then
    konsole --hold -e "cd '$DIR/palladium' && bash palladium"
elif [ "$(uname)" = "Darwin" ]; then
    osascript -e "tell application \"Terminal\" to do script \"cd '$DIR/palladium' && bash palladium\""
else
    echo "  ============================================================"
    echo "    PALLADIUM PORTABLE SERVER"
    echo "    Plug in. Power up. Host anything."
    echo "  ============================================================"
    echo ""
    cd "$DIR/palladium"
    exec bash palladium
fi
