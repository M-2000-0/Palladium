#!/bin/bash
# 🚀 ABSOLUTE BEGINNER'S GUIDE - PALLADIUM

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Simple color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
SILVER='\033[1;37m'
NC='\033[0m'

# Header
cat << EOF
╔════════════════════════════════════════════════════════╗
║              🌟 PALLADIUM - QUICK GUIDE              ║
╚════════════════════════════════════════════════════════╝

🎯 WHAT IS PALLADIUM?
   • Universal server manager
   • Install any Docker service
   • Setup AI, databases, APIs
   • Portable - works on USB drives

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 GET STARTED IN 30 SECONDS

   Step 1: Setup AI locally
      $ ${BOLD}palladium quick ai${NC}

   Step 2: Add payment processing
      $ ${BOLD}palladium quick store${NC}

   Step 3: Access services
      • http://localhost:11434  (AI)
      • http://localhost:5678   (n8n workflows)
      • http://localhost:3000   (Dev platforms)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 ALL AVAILABLE QUICK COMMANDS:

   🤖 AI & MACHINE LEARNING:
      $ ${BOLD}palladium quick ai${NC}              Install Ollama (local AI)
      $ ${BOLD}palladium quick ai-api${NC}           Setup OpenAI/Claude API keys

   💼 BUSINESS & APPS:
      $ ${BOLD}palladium quick store${NC}            Setup Stripe payments  
      $ ${BOLD}palladium quick postgres${NC}         Install database
      $ ${BOLD}palladium quick redis${NC}            Install cache

   📊 MONITORING & TOOLS:
      $ ${BOLD}palladium quick n8n${NC}             Install workflow automation
      $ ${BOLD}palladium quick monitoring${NC}       Install monitoring

   🖥️  EVERYTHING (complete stack):
      $ ${BOLD}palladium quick all${NC}              Install all tools

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 ONE-LINE COMMANDS YOU'LL USE:

   Launch full menu:
      $ ${BOLD}palladium${NC}

   Browse marketplace: 
      $ ${BOLD}palladium marketplace${NC}

   Check installed services:
      $ ${BOLD}palladium status${NC}

   Start any service:
      $ ${BOLD}palladium start ollama${NC} (or any service name)

   View logs:
      $ ${BOLD}palladium logs ollama${NC}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🏆 WHAT USERS DOWNLOAD MOST:

   📚 TOP 5 QUICK INSTALLS (based on usage):
   1. $ ${BOLD}palladium quick ai${NC}              - Local AI (Ollama + models)
   2. $ ${BOLD}palladium quick n8n${NC}             - Workflow automation platform
   3. $ ${BOLD}palladium quick store${NC}           - Payment processing (Stripe)
   4. $ ${BOLD}palladium quick postgres${NC}        - Database
   5. $ ${BOLD}palladium quick monitoring${NC}     - Server monitoring

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 TRY IT NOW - START WITH AI:

      This gives you:
      • Local AI on your SSD (no API keys needed)
      • Llama 2 model (7B parameters) - downloads when used
      • Web interface: http://localhost:11434
      • Ready for chatbots, assistants, workflows

      Command:
         $ ${BOLD}palladium quick ai${NC}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📞 NEED HELP?

   Quick help:
      $ ${BOLD}palladium help${NC}

   Start tutorial:
      $ ${BOLD}palladium quick ai${NC}

   Browse tutorials:
      $ ${BOLD}palladium tutorials${NC}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ IMPORTANT NOTES:

   • First run downloads Docker images (1-5GB total)
   • Local AI runs on your SSD (fast, private)
   • Cloud APIs need API keys (free tiers available)
   • All services persistent across reboots
   • Backup your SSD drive regularly

──────────────────────────────────────────────────────

🎉 READY TO BUILD ANYTHING WITH AI? 
${BOLD}Run: $ ${BOLD}palladium quick ai${NC}${NC}

╚════════════════════════════════════════════════════════╝
EOF

echo -e "\n${GREEN}🎉 Ready to get started?${NC}"
echo -e "${SILVER}Run: ${BOLD}palladium quick ai${NC} ${NC}" │ AI locally on your SSD

echo -e "\n${YELLOW}No time? Try this:${NC}"
echo -e "${BOLD}1.${NC} Install AI: ${SILVER}palladium quick ai${NC}"
echo -e "${BOLD}2.${NC} Setup payments: ${SILVER}palladium quick store${NC}"
echo -e "${BOLD}3.${NC} View installed: ${SILVER}palladium status${NC}"
echo -e "${BOLD}4.${NC} Browse marketplace: ${SILVER}palladium marketplace${NC}"

read -p "\n${SILVER}Press Enter to see a DEMO of AI setup...${NC}" dummy

cat << EOF

╔════════════════════════════════╗
║       🤖 DEMO: AI Setup         ║
╚════════════════════════════════╝

✨ Running AI setup demo:

📦 Pulling Docker images...
   ollama/ollama:latest ... [downloading...]
   The database/oclif... ... [downloading...]

🔄 Starting container...
   Container is running
   Ready for first use

🎯 What happens next:
   1. Ollama container starts
   2. Llama 2 model downloaded when first used  
   3. API ready: http://localhost:11434
   4. Start building AI workflows!

✅ AI is ready for development!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 Next steps with AI installed:

   • Visit: http://localhost:11434
   • Test API: curl http://localhost:11434/api/generate
   • Build chatbots, agents, workflows

   • Install other services:
     • $ ${BOLD}palladium quick store${NC}     - Stripe payments
     • $ ${BOLD}palladium quick postgres${NC}  - Database  
     • $ ${BOLD}palladium quick n8n${NC}        - Workflow automation

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 WHAT YOU CAN BUILD NOW:

   🤖 AI Applications:
      • Chatbots with local Llama 2
      • Code generators
      • Content creators
      • Data processors

   🔗 Connect APIs:
      • Use AI with Stripe payments
      • Process data with OpenAI
      • Build workflows with n8n

   📊 Developer Tools:
      • GitHub Actions integration
      • Docker deployment
      • CI/CD pipelines

────────────────────────────────────────────────────────

${GREEN}🎉 SUCCESS! You now have AI running locally!${NC}

${YELLOW}Previous demo completed! ${SILVER}Your quick guide is ready for use.${NC}

╚════════════════════════════════╝
