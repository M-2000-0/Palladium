#!/bin/bash
# tests/unit_test.sh - Unit tests for Palladium core functions
# Usage: bash tests/unit_test.sh

export TEST_MODE=1
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo -e "  ${GREEN}PASS${NC}  $name"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC}  $name"
        echo -e "        Expected: $expected"
        echo -e "        Actual:   $actual"
        ((FAIL++))
    fi
}

assert_contains() {
    local name="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo -e "  ${GREEN}PASS${NC}  $name"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC}  $name"
        echo -e "        Expected to contain: $needle"
        ((FAIL++))
    fi
}

# Source module files for testing
PALLADIUM_HOME="$(cd "$(dirname "$0")/../palladium" && pwd)"
MODULES_DIR="$PALLADIUM_HOME/modules"
DATA_DIR="$PALLADIUM_HOME/data"
INSTALLED_DIR="$DATA_DIR/installed"
mkdir -p "$INSTALLED_DIR"

source "$MODULES_DIR/core.sh"
source "$MODULES_DIR/menu.sh"
source "$MODULES_DIR/safety.sh"
source "$MODULES_DIR/docker.sh"
source "$MODULES_DIR/services.sh"
source "$MODULES_DIR/marketplace.sh"
source "$MODULES_DIR/wizard.sh"

echo -e "${CYAN}Palladium Unit Tests${NC}"
echo "========================================"

echo ""
echo "--- Color Variables ---"
assert_contains "RED defined" "$RED" "31m"
assert_contains "GREEN defined" "$GREEN" "32m"
assert_contains "NC defined" "$NC" "0m"

echo ""
echo "--- prompt_value() ---"
result=$(echo "testvalue" | prompt_value "Enter value" "default" 2>/dev/null)
assert_eq "prompt_value accepts input" "testvalue" "$result"

result=$(echo "" | prompt_value "Enter value" "default" 2>/dev/null)
assert_eq "prompt_value uses default" "default" "$result"

echo ""
echo "--- prompt_password() ---"
result=$(echo "secret123" | prompt_password "Password" 2>/dev/null | tail -1)
assert_eq "prompt_password accepts input" "secret123" "$result"
result=$(echo "" | prompt_password "Password" "mypass" 2>/dev/null | tail -1)
assert_eq "prompt_password uses default" "mypass" "$result"

echo ""
echo "--- confirm() ---"
confirm_result=$(echo "y" | confirm "Proceed?" 2>/dev/null && echo "yes" || echo "no")
assert_eq "confirm 'y' returns true" "yes" "$confirm_result"

confirm_result=$(echo "n" | confirm "Proceed?" 2>/dev/null && echo "yes" || echo "no")
assert_eq "confirm 'n' returns false" "no" "$confirm_result"

confirm_result=$(echo "" | confirm "Proceed?" "y" 2>/dev/null && echo "yes" || echo "no")
assert_eq "confirm default 'y' returns true" "yes" "$confirm_result"

confirm_result=$(echo "" | confirm "Proceed?" "n" 2>/dev/null && echo "yes" || echo "no")
assert_eq "confirm default 'n' returns false" "no" "$confirm_result"

echo ""
echo "--- main_menu() ---"
assert_contains "main_menu has Pre-built stacks" "$(declare -f main_menu)" "Pre-built stacks"
assert_contains "main_menu has Marketplace" "$(declare -f main_menu)" "Marketplace"
assert_contains "main_menu has AI Toolkit" "$(declare -f main_menu)" "AI Toolkit"
assert_contains "main_menu has Security" "$(declare -f main_menu)" "Security"
assert_contains "main_menu has Backup" "$(declare -f main_menu)" "Backup"
assert_contains "main_menu has Exit" "$(declare -f main_menu)" "Exit"

echo ""
echo "--- ensure_docker() ---"
assert_contains "ensure_docker checks docker command" "$(declare -f ensure_docker)" "command -v docker"
assert_contains "ensure_docker checks docker info" "$(declare -f ensure_docker)" "docker info"

echo ""
echo "--- safety.sh functions ---"
assert_contains "check_storage defined" "$(declare -f check_storage)" "available_mb"
assert_contains "check_docker_available defined" "$(declare -f check_docker_available)" "docker info"
assert_contains "install_docker defined" "$(declare -f install_docker)" "Installing Docker"
assert_contains "pull_image_with_fallback defined" "$(declare -f pull_image_with_fallback)" "docker pull"
assert_contains "run_with_retry defined" "$(declare -f run_with_retry)" "max_attempts"
assert_contains "health_check defined" "$(declare -f health_check)" "curl"
assert_contains "cleanup_all defined" "$(declare -f cleanup_all)" "docker system"

echo ""
echo "--- wizard.sh functions ---"
assert_contains "wizard_install accepts svc param" "$(declare -f wizard_install)" 'svc='
assert_contains "wizard_custom prompts for name" "$(declare -f wizard_custom)" "Instance name"

echo ""
echo "--- services.sh functions ---"
assert_contains "svc_list_installed defined" "$(declare -f svc_list_installed)" "Installed services"
assert_contains "svc_start defined" "$(declare -f svc_start)" "docker compose up"
assert_contains "svc_stop defined" "$(declare -f svc_stop)" "docker compose down"
assert_contains "svc_remove defined" "$(declare -f svc_remove)" "rm -rf"

echo ""
echo "=== Summary ==="
echo "Passed: $PASS, Failed: $FAIL"
echo ""
exit $((FAIL > 0 ? 1 : 0))
