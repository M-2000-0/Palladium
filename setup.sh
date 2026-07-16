#!/bin/bash
# setup.sh - First-time Palladium setup
set -e

BASE="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}${GREEN}=== Palladium - First Time Setup ===${NC}"
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

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  Run ${CYAN}./palladium/palladium${NC} to launch the menu"
echo -e "  Run ${CYAN}./install.sh${NC} to install the CLI system-wide"
echo ""
echo -e "  Quick start:"
echo -e "    ${CYAN}palladium stack starter${NC}   # n8n + PostgreSQL"
echo -e "    ${CYAN}palladium install ollama${NC}   # Local LLM"
echo -e "    ${CYAN}palladium marketplace${NC}      # Browse all tools"
echo -e "${GREEN}========================================${NC}"
