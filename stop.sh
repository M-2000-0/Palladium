#!/bin/bash
# stop.sh - Stop Palladium services
# Usage: ./stop.sh <service-name>

BASE="$(cd "$(dirname "$0")" && pwd)"
exec "$BASE/palladium/palladium" stop "$@"
