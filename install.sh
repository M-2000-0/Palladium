#!/bin/bash
# install.sh - Install palladium CLI system-wide
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PALLADIUM_CLI="$SCRIPT_DIR/palladium/palladium"

if [ ! -f "$PALLADIUM_CLI" ]; then
    echo "Error: palladium script not found at $PALLADIUM_CLI"
    exit 1
fi

echo -e "${CYAN}=== Palladium Installer ===${NC}"
echo ""

chmod +x "$PALLADIUM_CLI"
sudo cp "$PALLADIUM_CLI" /usr/local/bin/palladium
sudo chmod +x /usr/local/bin/palladium

echo -e "${GREEN}Palladium installed!${NC}"
echo ""
echo "Usage:"
echo "  palladium              Launch interactive menu"
echo "  palladium install      Install a service"
echo "  palladium start        Start a service"
echo "  palladium stop         Stop a service"
echo "  palladium status       Check status"
echo "  palladium logs         View logs"
echo "  palladium marketplace  Browse tools"
echo "  palladium stack        Quick-start stacks"
