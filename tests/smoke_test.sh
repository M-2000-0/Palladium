#!/bin/bash
cd "$(dirname "$0")/.."
PALLADIUM_CLI="palladium/palladium"
echo "=== Smoke Test ==="

run_test() {
    local name="$1" cmd="$2" expected="$3"
    output=$(bash "$PALLADIUM_CLI" $cmd 2>&1)
    code=$?
    if echo "$output" | grep -q "$expected"; then
        echo "  PASS  $name"
    else
        echo "  FAIL  $name (exit=$code)"
        echo "  Output: $(echo "$output" | head -2 | cat -v)"
    fi
}

run_test "launch shows usage" "launch" "Usage"
run_test "help shows commands" "help" "Commands"
run_test "menu has Quick Start" "" "Quick Start"

echo "=== Done ==="
