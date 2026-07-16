#!/bin/bash
# tests/run.sh - Run all Palladium tests
set -e

BASE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(dirname "$BASE")"
PASS=0
FAIL=0

red()   { echo -e "\033[0;31m$1\033[0m"; }
green() { echo -e "\033[0;32m$1\033[0m"; }
cyan()  { echo -e "\033[0;36m$1\033[0m"; }

echo ""
cyan "============================================"
cyan "  Palladium Test Suite"
cyan "============================================"
echo ""

# 1. Python syntax and structural tests
echo ""
cyan "--- Phase 1: Structural Tests (Python) ---"
cd "$BASE"
if command -v python &>/dev/null; then
    python "$BASE/test_syntax.py" && phase1=0 || phase1=1
else
    red "  Python not found, skipping structural tests"
    phase1=1
fi

echo ""
cyan "--- Phase 2: Bash Unit Tests ---"
cd "$BASE"
if command -v bash &>/dev/null; then
    bash "$BASE/unit_test.sh" && phase2=0 || phase2=1
else
    red "  Bash not found, skipping unit tests"
    phase2=1
fi

echo ""
cyan "--- Phase 3: File Integrity ---"
cd "$PROJECT"
issues=0

# Check all .sh files have execute permission or shebang
for f in *.sh palladium/*.sh palladium/modules/*.sh; do
    [ -f "$f" ] || continue
    if ! head -1 "$f" | grep -q "^#!/bin/bash" 2>/dev/null; then
        red "  Missing shebang: $f"
        ((issues++))
    fi
done
[ "$issues" -eq 0 ] && green "  All files have proper shebang"
issues=0

# Check .tool files consistency
for f in palladium/marketplace/*.tool; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .tool)
    firstline=$(head -1 "$f" | tr '[:upper:]' '[:lower:]')
    desired="name: $name"
    if [ "$firstline" != "$desired" ]; then
        red "  $f: name field mismatch (expected: $name)"
        ((issues++))
    fi
done
[ "$issues" -eq 0 ] && green "  All .tool files have matching name fields"

echo ""

# Summary
TOTAL_FAIL=$((phase1 + phase2 + issues))
if [ "$TOTAL_FAIL" -eq 0 ]; then
    green "============================================"
    green "  ALL TESTS PASSED"
    green "============================================"
    exit 0
else
    red "============================================"
    red "  $TOTAL_FAIL phase(s) had failures"
    red "============================================"
    exit 1
fi
