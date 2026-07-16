#!/bin/bash
# start-palladium.command - macOS double-click launcher
# Rename this file to start-palladium.command (macOS executes .command files in Terminal)

DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  ============================================================"
echo "    ███████  ███████  ██████  ██    ██  ███████  ██████  ██████"
echo "    ██       ██       ██   ██ ██    ██ ██       ██   ██ ██   ██"
echo "    ███████  █████    ██████  ██    ██ █████    ██████  ██████"
echo "         ██  ██       ██   ██  ██  ██  ██       ██   ██ ██"
echo "    ███████  ███████  ██   ██   ████   ███████  ██   ██ ██"
echo ""
echo "    Self-host. Your way."
echo "  ============================================================"
echo ""
echo "  Starting Server..."
echo "  Close this window to stop the server."
echo ""

cd "$DIR/palladium"
exec bash palladium
