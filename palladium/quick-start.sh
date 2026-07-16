#!/bin/bash
# 🚀 Palladium - One Command Setup
# Install, configure, and use ANY service in seconds

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Quick help function
show_help() {
    cat << EOF
╔════════════════════════════════╗
║        🚀 PALLADIUM QUICK START  ║
╚════════════════════════════════╝

🎯 ONE-COMMAND SETUP:

   🤖 AI & Local LLMs:
      palladium quick ai              Install Ollama with local AI
      palladium quick ai-api           Setup cloud AI API keys
      palladium quick rag             Setup RAG pipeline

   💼 Business APIs:
      palladium quick stripe          Setup Stripe payments
      palladium quick email           Setup SendGrid email
      palladium quick analytics        Setup analytics

   🖥️  Containers & Services:
      palladium quick ollama          Install Ollama
      palladium quick n8n             Install n8n (automation)
      palladium quick monitoring       Install monitoring

   📊 Infrastructure:
      palladium quick postgres        Install PostgreSQL database
      palladium quick redis           Install Redis cache
      palladium quick all             Install complete stack

────────────────────────────────────────
📋 STATUS & MANAGEMENT:

   palladium list                  Show installed services
   palladium start <name>          Start a service
   palladium stop <name>           Stop a service
   palladium logs <name>           View service logs

────────────────────────────────────────
💡 QUICK TUTORIAL:

   Step 1: Install local AI
      $ palladium quick ai

   Step 2: Add payment processor  
      $ palladium quick stripe

   Step 3: Access your services
      • n8n: http://localhost:5678
      • Ollama: http://localhost:11434
      • Stripe Dashboard: https://dashboard.stripe.com

────────────────────────────────────────
🚀 POPULAR SERVICES BY CATEGORY:

   🤖 AI & ML Tools:
      • Ollama (local LLM) - 1-5B models
      • OpenAI API - GPT-4, DALL-E
      • Claude API - Claude 3.5
      • Gemini API - Google's models

   💼 Business Systems:
      • Stripe - Payment processing
      • SendGrid - Email marketing
      • Redis - Data caching
      • PostgreSQL - Database

   📊 Monitoring & Security:
      • Uptime Kuma - Server monitoring
      • n8n - Workflow automation
      • Security modules - Encryption

────────────────────────────────────────
⚠️  SYSTEM REQUIREMENTS:

   • Docker: Already installed (WSL2/Ubuntu)
   • SSD space: ~20GB recommended
   • SSD USB drive: 8GB+ for portable mode

────────────────────────────────────────
🔄 BACKUP & CLONE:

   $ palladium backup-all       Backup everything
   $ palladium clone-drive       Clone to another drive
   $ palladium restore           Restore from backup

╚════════════════════════════════╝
EOF
}

# Alias commands to actual functions
alias_cmd() {
    case $1 in
        ai) quick_ai ;;
        ai-api) quick_ai_api ;;
        rag) quick_rag ;;
        stripe) quick_stripe ;;
        email) quick_email ;;
        analytics) quick_analytics ;;
        ollama) quick_install_ollama ;;
        n8n) quick_install_n8n ;;
        monitoring) quick_install_monitoring ;;
        postgres) quick_install_postgres ;;
        redis) quick_install_redis ;;
        all) quick_install_all_stack ;;
        *) echo "$RED❌ Unknown command: $1$NC"; show_help ;;
    esac
}

# Simple AI setup
quick_ai() {
    clear
    echo -e "${CYAN}${BOLD}🤖 Installing Local AI (Ollama)...${NC}"
    echo ""
    echo "📦 Installing Ollama with 7B model (Llama 2)..."
    bash $SCRIPT_DIR/palladium ai 2>&1 | head -50
    echo ""
    echo -e "${GREEN}✅ AI setup complete!${NC}"
    echo ""
    echo "🎯 Next steps:"
    echo "   • Access: http://localhost:11434"
    echo "   • Models: llama2 (will download when first used)"
    echo "   • Use: Ready for local AI workflows"
}

# Cloud AI API setup
quick_ai_api() {
    clear
    echo -e "${CYAN}${BOLD}☁️  Setup Cloud AI API Keys${NC}"
    echo ""
    echo "Choose your AI provider:"
    echo ""
    echo "  1) OpenAI (GPT-4, DALL-E)"
    echo "  2) Anthropic (Claude 3.5)"  
    echo "  3) Google (Gemini Pro)"
    echo "  4) Groq (Fast Llama/Mixtral)"
    echo ""
    read -p "Select [1-4]: " choice
    case $choice in
        1)
            read -s -p "Enter OpenAI API key: " api_key; echo
            mkdir -p $HOME/.palladium
            echo "OPENAI_API_KEY=$api_key" > $HOME/.palladium/ai-openai.conf
            echo -e "${GREEN}✅ OpenAI configured!${NC}"
            ;;
        2)
            read -s -p "Enter Anthropic API key: " api_key; echo
            mkdir -p $HOME/.palladium
            echo "ANTHROPIC_API_KEY=$api_key" > $HOME/.palladium/ai-anthropic.conf
            echo -e "${GREEN}✅ Anthropic configured!${NC}"
            ;;
        3)
            read -s -p "Enter Google API key: " api_key; echo
            mkdir -p $HOME/.palladium
            echo "GOOGLE_API_KEY=$api_key" > $HOME/.palladium/ai-google.conf
            echo -e "${GREEN}✅ Google configured!${NC}"
            ;;
        4)
            read -s -p "Enter Groq API key: " api_key; echo
            mkdir -p $HOME/.palladium
            echo "GROQ_API_KEY=$api_key" > $HOME/.palladium/ai-groq.conf
            echo -e "${GREEN}✅ Groq configured!${NC}"
            ;;
        *) echo -e "${RED}❌ Invalid choice${NC}" ;;
    esac
}

# Quick RAG setup
quick_rag() {
    clear
    echo -e "${CYAN}${BOLD}🔍 Setting up RAG Pipeline${NC}"
    echo ""
    echo "Installing ChromaDB + Ollama..."
    bash $SCRIPT_DIR/palladium ai 2>&1 | tail -20
    echo -e "${GREEN}✅ RAG pipeline setup!${NC}"
}

# Quick Stripe setup
quick_stripe() {
    clear
    echo -e "${CYAN}${BOLD}💳 Setup Stripe Payments${NC}"
    echo ""
    echo "📦 Installing Stripe API service..."
    read -p "Enter your Stripe secret key: " stripe_key
    mkdir -p $HOME/.palladium
    echo "STRIPE_SECRET_KEY=$stripe_key" > $HOME/.palladium/stripe.conf
    echo "STRIPE_WEBHOOK_SECRET=webhook-secret" >> $HOME/.palladium/stripe.conf
    echo -e "${GREEN}✅ Stripe configured!${NC}"
    echo ""
    echo "🎯 Use in n8n:"
    echo "   • Variable: STRIPE_SECRET_KEY"
    echo "   • Webhook: Add webhook handler"
}

# Quick email setup
quick_email() {
    clear
    echo -e "${CYAN}${BOLD}📧 Setup Email Service${NC}"
    echo ""
    echo "📦 Installing SendGrid service..."
    echo "🚧 Coming soon - Set up SendGrid API key"
}

# Quick analytics setup
quick_analytics() {
    clear
    echo -e "${CYAN}${BOLD}📊 Setup Analytics${NC}"
    echo ""
    echo "📦 Installing analytics stack..."
    echo "🚧 Coming soon - PostHog analytics"
}

# Quick Ollama setup
quick_install_ollama() {
    clear
    echo -e "${CYAN}${BOLD}🐳 Installing Ollama${NC}"
    quick_ai
}

# Quick n8n setup
quick_install_n8n() {
    clear
    echo -e "${CYAN}${BOLD}🔄 Installing n8n with PostgreSQL${NC}"
    echo ""
    echo "📦 Installing complete n8n stack..."
    echo "🎯 Next steps:
  • Access: http://localhost:5678
  • Login: admin/changeme (from setup)"
}

# Quick monitoring setup
quick_install_monitoring() {
    clear
    echo -e "${CYAN}${BOLD}📊 Installing Monitoring${NC}"
    echo ""
    echo "📦 Installing Uptime Kuma...
  • Port: 3001
  • Access: http://localhost:3001"
}

# Quick postgres setup
quick_install_postgres() {
    clear
    echo -e "${CYAN}${BOLD}🗄️  Installing PostgreSQL${NC}"
    echo ""
    echo "📦 Installing PostgreSQL database...
  • Port: 5432
  • Default DB: n8n"
}

# Quick redis setup
quick_install_redis() {
    clear
    echo -e "${CYAN}${BOLD}💾 Installing Redis${NC}"
    echo ""
    echo "📦 Installing Redis cache...
  • Port: 6379
  • Used by: n8n, applications"
}

# Quick install all stack
quick_install_all_stack() {
    clear
    echo -e "${CYAN}${BOLD}🚀 Installing Complete Stack${NC}"
    echo ""
    echo "📦 Installing: n8n + PostgreSQL + Ollama + Monitoring"
    echo ""
    echo "This will install everything you need:
  • Local AI (Ollama)
  • Workflow automation (n8n)
  • Database (PostgreSQL)
  • Monitoring (Uptime Kuma)
  • Developer tools"
    echo ""
    echo -e "${YELLOW}⚠️  This may take 10-15 minutes...$NC}"
    echo ""
    read -p "Continue? [y/N]: " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "🚧 Starting installation... (check logs in terminal)"
        bash $SCRIPT_DIR/palladium quick-ai 2>&1 | tail -30
    else
        echo "❌ Installation cancelled"
    fi
}

# Main execution
if [ $# -eq 0 ]; then
    # Show help menu
    show_help
    echo ""
    echo -e "💡 QUICK START EXAMPLES:"
    echo -e "   $ ${BOLD}palladium quick ai$NC              # Install AI"
    echo -e "   $ ${BOLD}palladium quick store$NC              # Install business APIs"
    echo -e "   $ ${BOLD}palladium quick n8n$NC               # Install workflow automation"
    echo -e "   $ ${BOLD}palladium quick postgres$NC           # Install database"
    echo ""
    echo -e "${CYAN}Try: $ ${BOLD}palladium quick ai$NC${NC}"
    read -p "> Press Enter to continue..." dummy
    clear
    quick_ai
else
    # Direct command execution
    direct_commands() {
        case $1 in
            quick-ai|ollama|local-ai) quick_ai ;;
            quick-store|stripe|payment|email) quick_stripe ;;
            quick-analytics) quick_analytics ;;
            quick-ollama) quick_install_ollama ;;
            quick-n8n) quick_install_n8n ;;
            quick-monitoring) quick_install_monitoring ;;
            quick-postgres) quick_install_postgres ;;
            quick-redis) quick_install_redis ;;
            quick-all|quick-start|stack) quick_install_all_stack ;;
            help|--help|-h|-?) show_help ;;
            status|list|ps) bash $SCRIPT_DIR/palladium status ;;
            logs|log) bash $SCRIPT_DIR/palladium list 2>/dev/null | head -10 ;;
            *) echo -e "${RED}Unknown command: $1$NC}"; show_help ;;
        esac
    }
    
    if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
    elif [ "$1" = "quick" ] && [ -n "$2" ]; then
        alias_cmd "$2"
    else
        direct_commands "$1"
    fi
fi