#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
SILVER='\033[1;37m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

show_banner() {
    echo ""
    echo -e "${SILVER}${BOLD}"
    cat << 'EOF'
██████╗  █████╗ ██╗     ██╗      █████╗ ██████╗ ██╗██╗   ██╗███╗   ███╗
██╔══██╗██╔══██╗██║     ██║     ██╔══██╗██╔══██╗██║██║   ██║████╗ ████║
██████╔╝███████║██║     ██║     ███████║██║  ██║██║██║   ██║██╔████╔██║
██╔═══╝ ██╔══██║██║     ██║     ██╔══██║██║  ██║██║██║   ██║██║╚██╔╝██║
██║     ██║  ██║███████╗███████╗██║  ██║██████╔╝██║╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚═╝ ╚═════╝ ╚═╝     ╚═╝
EOF
    echo -e "${NC}"
    echo -e "  ${SILVER}${BOLD}Portable Server Manager${NC}"
    echo -e "  ${DIM}Plug in. Power up. Host anything.${NC}"
    echo ""
}

show_server_banner() {
    echo ""
    echo -e "${SILVER}${BOLD}"
    echo "  ███████╗ ███████╗ ██████╗  ██╗   ██╗ ███████╗ ██████╗ "
    echo "  ██╔════╝ ██╔════╝ ██╔══██╗ ██║   ██║ ██╔════╝ ██╔══██╗"
    echo "  ███████╗ █████╗   ██████╔╝ ██║   ██║ █████╗   ██████╔╝"
    echo "  ╚════██║ ██╔══╝   ██╔══██╗ ╚██╗ ██╔╝ ██╔══╝   ██╔══██╗"
    echo "  ███████║ ███████╗ ██║  ██║  ╚████╔╝  ███████╗ ██║  ██║"
    echo "  ╚══════╝ ╚═══════╝ ╚═╝  ╚═╝   ╚═══╝   ╚═══════╝ ╚═╝  ╚═╝"
    echo -e "${NC}"
}

show_help() {
    show_banner
    echo -e "${SILVER}Usage:${NC}"
    echo "  palladium              Launch interactive menu"
    echo "  palladium install      Install a service"
    echo "  palladium start <svc>  Start a service"
    echo "  palladium stop <svc>   Stop a service"
    echo "  palladium status       Show all services"
    echo "  palladium logs <svc>   View service logs"
    echo "  palladium remove <svc> Remove a service"
    echo "  palladium list         List installed services"
    echo ""
}

ensure_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker not found.${NC}"
        echo "Install: sudo apt update && sudo apt install -y docker.io docker-compose-v2"
        return 1
    fi
    if ! docker info &> /dev/null 2>&1; then
        echo -e "${YELLOW}Starting Docker...${NC}"
        sudo service docker start 2>/dev/null || sudo systemctl start docker 2>/dev/null
        sleep 3
    fi
    return 0
}

prompt_value() {
    local prompt="$1"
    local default="${2:-}"
    local result
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " result
        echo "${result:-$default}"
    else
        read -p "$prompt: " result
        echo "$result"
    fi
}

prompt_password() {
    local prompt="$1"
    local default="${2:-}"
    local result
    if [ -n "$default" ]; then
        read -s -p "$prompt [$default]: " result
        echo
        echo "${result:-$default}"
    else
        read -s -p "$prompt: " result
        echo
        echo "$result"
    fi
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local result
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " result
        result="${result:-y}"
    else
        read -p "$prompt [y/N]: " result
        result="${result:-n}"
    fi
    [[ "$result" =~ ^[Yy] ]]
}

press_enter() {
    echo ""
    read -p "Press Enter to continue..."
}

ensure_docker_in_path() {
    if ! command -v docker &> /dev/null; then
        local docker_cmd
        docker_cmd=$(find_docker_cli 2>/dev/null || true)
        if [ -n "$docker_cmd" ]; then
            local docker_dir
            docker_dir=$(dirname "$docker_cmd")
            export PATH="$docker_dir:$PATH"
        fi
    fi
}

# Input validation functions
validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

validate_instance_name() {
    local name="$1"
    [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,62}$ ]]
}

validate_password() {
    local pwd="$1"
    [ ${#pwd} -ge 8 ] || return 1
    # At least one letter and one number
    [[ "$pwd" =~ [A-Za-z] ]] && [[ "$pwd" =~ [0-9] ]]
}

prompt_port() {
    local prompt="$1"
    local default="${2:-}"
    local port
    while true; do
        port=$(prompt_value "$prompt" "$default")
        if validate_port "$port"; then
            echo "$port"
            return 0
        else
            echo -e "${RED}  Invalid port. Must be 1-65535.${NC}"
        fi
    done
}

prompt_instance_name() {
    local prompt="$1"
    local default="${2:-}"
    local name
    while true; do
        name=$(prompt_value "$prompt" "$default")
        if validate_instance_name "$name"; then
            echo "$name"
            return 0
        else
            echo -e "${RED}  Invalid name. Use alphanumeric, hyphen, underscore (1-63 chars).${NC}"
        fi
    done
}

# Cross-platform sed -i (macOS requires backup extension)
sed_inplace() {
    if [ "$(uname)" = "Darwin" ]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# ============================================
# Plugin System
# ============================================

PLUGINS_DIR="$PALLADIUM_HOME/plugins"

# Load all enabled plugins
load_plugins() {
    mkdir -p "$PLUGINS_DIR/enabled"
    
    for plugin_dir in "$PLUGINS_DIR/enabled"/*/; do
        [ -d "$plugin_dir" ] || continue
        local plugin_name=$(basename "$plugin_dir")
        local plugin_main="$plugin_dir/$plugin_name.sh"
        
        if [ -f "$plugin_main" ]; then
            log_message "Loading plugin: $plugin_name" "DEBUG"
            source "$plugin_main" 2>/dev/null || {
                log_message "Failed to load plugin: $plugin_name" "WARN"
            }
            # Call plugin init if it exists
            if declare -f "plugin_${plugin_name}_init" >/dev/null; then
                "plugin_${plugin_name}_init"
            fi
        fi
    done
}

# Install a plugin from a git repo or local path
plugin_install() {
    local source="$1"
    local name="$2"
    
    [ -z "$source" ] && { echo "Usage: plugin_install <git-repo|path> [name]"; return 1; }
    
    local plugin_name="${name:-$(basename "$source" .git)}"
    local target="$PLUGINS_DIR/available/$plugin_name"
    
    if [ -d "$target" ]; then
        echo -e "${YELLOW}Plugin $plugin_name already exists. Updating...${NC}"
        if [ -d "$target/.git" ]; then
            git -C "$target" pull
        fi
    else
        if [[ "$source" =~ ^https?://|^git@ ]]; then
            git clone "$source" "$target" || return 1
        else
            cp -r "$source" "$target" || return 1
        fi
    fi
    
    # Validate plugin structure
    if [ ! -f "$target/$plugin_name.sh" ]; then
        echo -e "${RED}Invalid plugin: missing $plugin_name.sh${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Plugin $plugin_name installed.${NC}"
    echo "Enable with: plugin_enable $plugin_name"
}

# Enable a plugin (symlink to enabled/)
plugin_enable() {
    local name="$1"
    [ -z "$name" ] && { echo "Usage: plugin_enable <name>"; return 1; }
    
    local src="$PLUGINS_DIR/available/$name"
    local dst="$PLUGINS_DIR/enabled/$name"
    
    [ -d "$src" ] || { echo -e "${RED}Plugin not found: $name${NC}"; return 1; }
    
    ln -sfn "$src" "$dst"
    echo -e "${GREEN}Plugin $name enabled. Restart Palladium to load.${NC}"
}

# Disable a plugin
plugin_disable() {
    local name="$1"
    [ -z "$name" ] && { echo "Usage: plugin_disable <name>"; return 1; }
    
    rm -f "$PLUGINS_DIR/enabled/$name"
    echo -e "${YELLOW}Plugin $name disabled. Restart Palladium to unload.${NC}"
}

# List installed plugins
plugin_list() {
    echo -e "${SILVER}${BOLD}Available Plugins:${NC}"
    for dir in "$PLUGINS_DIR/available"/*/; do
        [ -d "$dir" ] || continue
        local name=$(basename "$dir")
        local status="${RED}disabled${NC}"
        [ -L "$PLUGINS_DIR/enabled/$name" ] && status="${GREEN}enabled${NC}"
        local desc=""
        [ -f "$dir/plugin.conf" ] && desc=" - $(grep '^description=' "$dir/plugin.conf" | cut -d= -f2-)"
        echo -e "  $name [$status]$desc"
    done
}

# Create plugin scaffold
plugin_create() {
    local name="$1"
    [ -z "$name" ] && { echo "Usage: plugin_create <name>"; return 1; }
    
    local dir="$PLUGINS_DIR/available/$name"
    mkdir -p "$dir"
    
    cat > "$dir/$name.sh" << 'EOF'
#!/bin/bash
# Plugin: {{NAME}}
# Description: {{DESCRIPTION}}

plugin_{{NAME}}_init() {
    # Called when plugin loads
    log_message "Plugin {{NAME}} initialized" "DEBUG"
}

# Add menu items by defining plugin_{{NAME}}_menu()
# plugin_{{NAME}}_menu() {
#     echo "  [x] {{NAME}} - Custom action"
# }

# Handle menu selections by defining plugin_{{NAME}}_handle()
# plugin_{{NAME}}_handle() {
#     case "$1" in
#         x) echo "Custom action" ;;
#     esac
# }
EOF
    sed_inplace "s/{{NAME}}/$name/g" "$dir/$name.sh"
    
    cat > "$dir/plugin.conf" << EOF
name=$name
version=1.0.0
description=A new Palladium plugin
author=Your Name
EOF
    
    cat > "$dir/README.md" << EOF
# $name Plugin

Description here.

## Usage

EOF
    
    echo -e "${GREEN}Plugin scaffold created at $dir${NC}"
    echo "Edit $dir/$name.sh to implement functionality."
}
