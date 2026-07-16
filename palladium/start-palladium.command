#!/bin/bash
# start-palladium.command - macOS double-click launcher
# Rename this file to start-palladium.command (macOS executes .command files in Terminal)

DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  ============================================================"
echo "        __        __   _ _    _    ____    __  __  _   _   _"
echo "        \ \      / /__| | |  | |  / ___|  |  \/  | | | | | |"
echo "         \ \ /\ / / _ \ | |  | | | |  _   | |\  /| | | | | |"
echo "          \ V  V /  __/ | |__| |___| |_| |  | | \/| | |_| | |_|"
echo "           \_/\_/ \___|_|\____/|_____|  |_|  |_|  |\__,_| \__,_|"
echo ""
echo "     Portable Server Manager"
echo "     Plug in. Power up. Host anything."
echo "  ============================================================"
echo ""
echo "  Starting Palladium..."
echo "  Close this window to stop the server."
echo ""

cd "$DIR/palladium"
exec bash palladium
