#!/bin/bash
# Plugin: hello-world
# Description: A simple hello world plugin demonstrating the plugin system

plugin_hello-world_init() {
    log_message "Plugin hello-world initialized" "DEBUG"
}

plugin_hello-world_menu() {
    echo "  [h] Hello World - Say hello"
}

plugin_hello-world_handle() {
    case "$1" in
        h)
            echo -e "${GREEN}Hello from the plugin system!${NC}"
            echo "This plugin was loaded dynamically."
            press_enter
            ;;
    esac
}