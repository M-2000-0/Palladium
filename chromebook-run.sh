#!/bin/bash
set -e

BASE="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE"

echo "Palladium Chromebook launcher"
echo "Looking for the project on the mounted SSD..."

for candidate in \
    "$BASE" \
    /media/*/*/palladium \
    /mnt/*/*/palladium \
    /media/*/palladium \
    /mnt/*/palladium; do
    if [ -f "$candidate/palladium/palladium" ]; then
        echo "Found project at $candidate"
        cd "$candidate"
        exec ./plug-and-play.sh
    fi
done

echo "Could not find the Palladium project on the mounted SSD."
echo "Please make sure the SSD is shared with Linux and mounted in /media or /mnt."
exit 1
