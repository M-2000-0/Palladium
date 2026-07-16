#!/bin/bash
# uninstall.sh - Cleanly remove Palladium from the system
# Usage: sudo ./uninstall.sh

set -e

PALLADIUM_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  ═══ Palladium Uninstall ═══"
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo "  Note: Running without sudo. System-wide files may remain."
    echo "  Re-run with: sudo ./uninstall.sh"
    echo ""
fi

echo "  This will remove:"
echo "    • /usr/local/bin/palladium (symlink)"
echo "    • Shell aliases in ~/.bashrc, ~/.zshrc, ~/.profile"
echo "    • Docker containers created by Palladium"
echo "    • All installed service data"
echo ""

read -p "  Uninstall Palladium? [y/N]: " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "  Cancelled."
    exit 0
fi

echo ""
echo -e "  \033[0;36mRemoving system-wide symlink...\033[0m"
if [ -f /usr/local/bin/palladium ]; then
    rm -f /usr/local/bin/palladium && echo "  ✓ Removed /usr/local/bin/palladium"
elif [ -f /usr/bin/palladium ]; then
    rm -f /usr/bin/palladium && echo "  ✓ Removed /usr/bin/palladium"
else
    echo "  - Not found in system PATH"
fi

echo ""
echo -e "  \033[0;36mRemoving shell aliases...\033[0m"
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$rc" ]; then
        sed -i '/palladium/d' "$rc" 2>/dev/null && echo "  ✓ Cleaned $rc"
    fi
done

echo ""
echo -e "  \033[0;36mStopping and removing Docker containers...\033[0m"
if command -v docker &>/dev/null; then
    for svc_dir in "$PALLADIUM_DIR/palladium/data/installed"/*/; do
        if [ -d "$svc_dir" ]; then
            name=$(basename "$svc_dir")
            echo "  Stopping $name..."
            (cd "$svc_dir" && docker compose down -v 2>/dev/null) || true
        fi
    done
    echo "  ✓ Containers stopped"
else
    echo "  - Docker not available, skipping container cleanup"
fi

echo ""
echo -e "  \033[0;36mRemoving Palladium data...\033[0m"
if [ -d "$PALLADIUM_DIR/palladium/data" ]; then
    rm -rf "$PALLADIUM_DIR/palladium/data"
    echo "  ✓ Removed palladium/data/"
fi

echo ""
echo "  ═══════════════════════════════════════════"
echo ""
echo -e "  \033[0;32mPalladium has been uninstalled.\033[0m"
echo ""
echo "  Your project files are still at:"
echo "    $PALLADIUM_DIR"
echo ""
echo "  To remove them manually:"
echo "    rm -rf \"$PALLADIUM_DIR\""
echo ""
