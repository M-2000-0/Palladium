#!/bin/bash
# debug_test.sh - Debug the palladium CLI
cd "$(dirname "$0")/.."
echo "=== Debug: Running palladium launch ==="

# Run with set -e disabled, capture all output
set +e
output=$(bash -x palladium/palladium launch 2>&1)
code=$?
echo "Exit code: $code"
echo "--- stdout/stderr (last 20 lines) ---"
echo "$output" | tail -20
echo "---"
