#!/bin/bash
# start.sh - Start Palladium services
# Usage: ./start.sh [service-name]

BASE="$(cd "$(dirname "$0")" && pwd)"
PALLADIUM="$BASE/palladium/palladium"

if [ ! -f "$PALLADIUM" ]; then
    echo "Error: palladium not found at $PALLADIUM"
    echo "Run setup.sh first."
    exit 1
fi

if [ -n "$1" ]; then
    exec "$PALLADIUM" start "$@"
else
    # No args: launch the interactive menu
    exec "$PALLADIUM"
fi
