#!/bin/bash
# setup.sh - First-time Palladium setup
set -e

BASE="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
SILVER='\033[1;37m'
NC='\033[0m'

echo -e "${SILVER}${GREEN}=== Palladium - First Time Setup ===${NC}"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not found. Installing...${NC}"
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y docker.io docker-compose-v2
        sudo usermod -aG docker $USER
        sudo service docker start
    else
        echo -e "${YELLOW}Please install Docker manually: https://docs.docker.com/engine/install/${NC}"
        exit 1
    fi
fi

# Check docker compose
if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Installing docker compose plugin...${NC}"
    sudo apt install -y docker-compose-v2
fi

# Create default .env if not exists
if [ ! -f .env ]; then
    echo -e "${GREEN}Creating default configuration...${NC}"
    cp .env.example .env
    chmod 600 .env
fi

# Create data directories
mkdir -p data data/workspace/databases data/workspace/exports data/workspace/queries

# Install CLI system-wide for a smoother plug-and-play experience
if [ -x "$BASE/install.sh" ]; then
    echo -e "${GREEN}Installing Palladium CLI system-wide...${NC}"
    "$BASE/install.sh" >/dev/null 2>&1 || true
fi

# Enable automatic startup on Linux/ChromeOS when possible
if command -v systemctl >/dev/null 2>&1 && systemctl --user list-units >/dev/null 2>&1; then
    echo -e "${GREEN}Configuring automatic startup...${NC}"
    bash "$BASE/palladium/install-autorun.sh" >/dev/null 2>&1 || true
elif command -v crontab >/dev/null 2>&1; then
    echo -e "${GREEN}Adding reboot startup entry...${NC}"
    (crontab -l 2>/dev/null | grep -v "watch-usb.sh"; echo "@reboot $BASE/palladium/watch-usb.sh") | crontab - 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  Run ${SILVER}palladium${NC} to launch the menu"
echo -e "  Run ${SILVER}palladium stack starter${NC} to start n8n + PostgreSQL"
echo ""
echo -e "  Quick start:"
echo -e "    ${SILVER}palladium stack starter${NC}   # n8n + PostgreSQL"
echo -e "    ${SILVER}palladium install ollama${NC}   # Local LLM"
echo -e "    ${SILVER}palladium marketplace${NC}      # Browse all tools"
echo -e "${GREEN}========================================${NC}"
