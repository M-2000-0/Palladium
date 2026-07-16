#!/bin/bash
# tutorials.sh - In-app tutorials and guided onboarding

tutorials_menu() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Tutorials & Guides ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Getting Started${NC}     First-time walkthrough"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Install your first app${NC}  Step-by-step guide"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}AI Setup${NC}            Connect AI providers"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Data Analysis${NC}       SQL + AI workflow"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}Networking${NC}          LAN sharing guide"
    echo -e "  ${BOLD}[6]${NC}  ${GREEN}Security${NC}            Hardening guide"
    echo -e "  ${BOLD}[7]${NC}  ${GREEN}All Commands${NC}        Quick reference"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select tutorial: " choice
    case $choice in
        1) tutorial_getting_started ;;
        2) tutorial_first_app ;;
        3) tutorial_ai_setup ;;
        4) tutorial_data ;;
        5) tutorial_networking ;;
        6) tutorial_security ;;
        7) tutorial_commands ;;
        0) return ;;
    esac
}

tutorial_getting_started() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Getting Started with Palladium ═══${NC}"
    echo ""
    echo -e "  ${GREEN}Welcome!${NC} Palladium turns your USB/SSD into a portable server."
    echo ""
    echo -e "  ${BOLD}Step 1: Plug in your drive${NC}"
    echo -e "  ${DIM}Insert your USB or SSD. Palladium runs from it.${NC}"
    echo ""
    echo -e "  ${BOLD}Step 2: Run palladium${NC}"
    echo -e "  ${DIM}Type 'palladium' in your terminal to launch.${NC}"
    echo ""
    echo -e "  ${BOLD}Step 3: Install your first service${NC}"
    echo -e "  ${DIM}Pick [1] Quick Start → [1] Starter (n8n + DB).${NC}"
    echo ""
    echo -e "  ${BOLD}Step 4: Open in browser${NC}"
    echo -e "  ${DIM}Palladium opens it automatically. Or scan the QR code.${NC}"
    echo ""
    echo -e "  ${BOLD}That's it!${NC} Your server is running."
    echo ""
    echo -e "  ${DIM}Next: Try [2] Install your first app for more options.${NC}"
    press_enter
}

tutorial_first_app() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Install Your First App ═══${NC}"
    echo ""
    echo -e "  ${BOLD}Option A: Quick Stack (easiest)${NC}"
    echo -e "  ${DIM}1. palladium${NC}"
    echo -e "  ${DIM}2. Pick [1] Quick Start${NC}"
    echo -e "  ${DIM}3. Pick [1] Starter${NC}"
    echo -e "  ${DIM}4. Follow the prompts${NC}"
    echo -e "  ${DIM}5. Done! Browser opens automatically.${NC}"
    echo ""
    echo -e "  ${BOLD}Option B: Single Service${NC}"
    echo -e "  ${DIM}1. palladium${NC}"
    echo -e "  ${DIM}2. Pick [2] Install a service${NC}"
    echo -e "  ${DIM}3. Choose a service (ollama, n8n, postgres, etc.)${NC}"
    echo -e "  ${DIM}4. Set name, port, credentials${NC}"
    echo -e "  ${DIM}5. Wait for install, browser opens.${NC}"
    echo ""
    echo -e "  ${BOLD}Option C: Marketplace${NC}"
    echo -e "  ${DIM}1. palladium${NC}"
    echo -e "  ${DIM}2. Pick [4] Marketplace${NC}"
    echo -e "  ${DIM}3. Browse categories (AI, Data, DevOps)${NC}"
    echo -e "  ${DIM}4. Pick a tool, confirm install${NC}"
    echo ""
    press_enter
}

tutorial_ai_setup() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ AI Setup Guide ═══${NC}"
    echo ""
    echo -e "  ${BOLD}Option A: Local AI (free, private)${NC}"
    echo -e "  ${DIM}1. palladium → [5] AI Toolkit${NC}"
    echo -e "  ${DIM}2. Pick [1] Local LLMs${NC}"
    echo -e "  ${DIM}3. Pick a model size:${NC}"
    echo -e "  ${DIM}   - Tiny (1B) for quick tasks${NC}"
    echo -e "  ${DIM}   - Medium (7B) for best balance${NC}"
    echo -e "  ${DIM}4. Wait for install, that's it!${NC}"
    echo ""
    echo -e "  ${BOLD}Option B: Cloud AI (better quality)${NC}"
    echo -e "  ${DIM}1. palladium → [5] AI Toolkit${NC}"
    echo -e "  ${DIM}2. Pick [2] API Connectors${NC}"
    echo -e "  ${DIM}3. Choose provider (OpenAI, Claude, etc.)${NC}"
    echo -e "  ${DIM}4. Enter your API key${NC}"
    echo -e "  ${DIM}5. Use it in Data Analysis or services${NC}"
    echo ""
    echo -e "  ${BOLD}After setup:${NC}"
    echo -e "  ${DIM}- Use AI in Data Workspace (palladium data)${NC}"
    echo -e "  ${DIM}- Use AI in automation workflows (n8n, etc.)${NC}"
    echo -e "  ${DIM}- Ask questions about your data${NC}"
    press_enter
}

tutorial_data() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Data Analysis Tutorial ═══${NC}"
    echo ""
    echo -e "  ${BOLD}Create a database:${NC}"
    echo -e "  ${DIM}1. palladium data → [1] Create database${NC}"
    echo -e "  ${DIM}2. Pick SQLite (easiest)${NC}"
    echo -e "  ${DIM}3. Name it and done!${NC}"
    echo ""
    echo -e "  ${BOLD}Import data:${NC}"
    echo -e "  ${DIM}1. palladium data → [4] Import data${NC}"
    echo -e "  ${DIM}2. Pick CSV, JSON, or SQL file${NC}"
    echo -e "  ${DIM}3. Enter table name${NC}"
    echo -e "  ${DIM}4. Done!${NC}"
    echo ""
    echo -e "  ${BOLD}Query with AI:${NC}"
    echo -e "  ${DIM}1. palladium data → [7] Natural Language → SQL${NC}"
    echo -e "  ${DIM}2. Describe what you want in English${NC}"
    echo -e "  ${DIM}3. AI generates SQL${NC}"
    echo -e "  ${DIM}4. Review and run${NC}"
    echo ""
    echo -e "  ${BOLD}Visualize:${NC}"
    echo -e "  ${DIM}1. palladium data → [8] Visualize${NC}"
    echo -e "  ${DIM}2. Pick chart type${NC}"
    echo -e "  ${DIM}3. Pick table and columns${NC}"
    echo -e "  ${DIM}4. Chart opens in browser!${NC}"
    press_enter
}

tutorial_networking() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Networking Tutorial ═══${NC}"
    echo ""
    echo -e "  ${BOLD}Access from other devices:${NC}"
    echo -e "  ${DIM}1. palladium → [9] Tools → [1] Drive info${NC}"
    echo -e "  ${DIM}2. Or: palladium network${NC}"
    echo -e "  ${DIM}3. Note your IP address${NC}"
    echo -e "  ${DIM}4. From any device: http://YOUR_IP:PORT${NC}"
    echo ""
    echo -e "  ${BOLD}Setup reverse proxy:${NC}"
    echo -e "  ${DIM}1. palladium network → [2] Reverse Proxy${NC}"
    echo -e "  ${DIM}2. Install Nginx Proxy Manager${NC}"
    echo -e "  ${DIM}3. Open http://localhost:81${NC}"
    echo -e "  ${DIM}4. Add proxy hosts for your services${NC}"
    echo ""
    echo -e "  ${BOLD}Firewall:${NC}"
    echo -e "  ${DIM}1. palladium security → [3] Firewall${NC}"
    echo -e "  ${DIM}2. Enable and allow needed ports${NC}"
    press_enter
}

tutorial_security() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Security Tutorial ═══${NC}"
    echo ""
    echo -e "  ${BOLD}Essential steps:${NC}"
    echo ""
    echo -e "  ${GREEN}1. Change default passwords${NC}"
    echo -e "  ${DIM}   palladium security → [2] Password audit${NC}"
    echo -e "  ${DIM}   Fix any 'changeme' entries.${NC}"
    echo ""
    echo -e "  ${GREEN}2. Enable firewall${NC}"
    echo -e "  ${DIM}   palladium security → [3] Firewall${NC}"
    echo -e "  ${DIM}   Enable UFW, allow only needed ports.${NC}"
    echo ""
    echo -e "  ${GREEN}3. Store secrets securely${NC}"
    echo -e "  ${DIM}   palladium security → [1] Secrets Manager${NC}"
    echo -e "  ${DIM}   Don't hardcode API keys.${NC}"
    echo ""
    echo -e "  ${GREEN}4. Run security scan${NC}"
    echo -e "  ${DIM}   palladium security → [5] Scan for issues${NC}"
    echo ""
    echo -e "  ${GREEN}5. Setup HTTPS${NC}"
    echo -e "  ${DIM}   palladium security → [4] HTTPS setup${NC}"
    press_enter
}

tutorial_commands() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ All Commands ═══${NC}"
    echo ""
    echo -e "  ${GREEN}Core:${NC}"
    echo "    palladium                  Launch menu"
    echo "    palladium stack            Quick start stacks"
    echo "    palladium install          Install service"
    echo "    palladium start <name>     Start service"
    echo "    palladium stop <name>      Stop service"
    echo "    palladium status           Show all"
    echo "    palladium remove <name>    Remove service"
    echo ""
    echo -e "  ${GREEN}Platform:${NC}"
    echo "    palladium marketplace      Browse tools"
    echo "    palladium ai               AI toolkit"
    echo "    palladium data             Data workspace"
    echo "    palladium dashboard        Data dashboard"
    echo "    palladium supabase         Cloud DB"
    echo ""
    echo -e "  ${GREEN}Tools:${NC}"
    echo "    palladium security         Security tools"
    echo "    palladium network          Network tools"
    echo "    palladium monitor          Resource monitoring"
    echo "    palladium updates          Update Palladium"
    echo "    palladium notify           Notifications"
    echo "    palladium profiles         User profiles"
    echo "    palladium tutorials        Learning guides"
    echo ""
    echo -e "  ${GREEN}Data:${NC}"
    echo "    palladium backup           Backup all"
    echo "    palladium restore          Restore backup"
    echo "    palladium cleanup          Free space"
    echo "    palladium drive            Drive info"
    press_enter
}
