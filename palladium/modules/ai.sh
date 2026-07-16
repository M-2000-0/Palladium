#!/bin/bash
# ai.sh - AI toolkit (Ollama, API connectors, RAG)

ai_menu() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ AI Toolkit ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Local LLMs${NC}         Run AI models on your SSD (Ollama)"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}API Connectors${NC}     OpenAI, Claude, Gemini"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}RAG Pipeline${NC}       Vector DB + embeddings"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}AI Agent${NC}           Build custom AI agents"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}Custom AI Tool${NC}     Install any AI Docker image"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) ai_local_llm ;;
        2) ai_api_connector ;;
        3) ai_rag_pipeline ;;
        4) ai_agent ;;
        5) ai_custom ;;
        0) return ;;
    esac
}

ai_local_llm() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ Local LLMs (Ollama) ═══${NC}"
    echo ""
    echo -e "  ${DIM}Run AI models locally on your SSD. No API keys needed.${NC}"
    echo ""

    # Check if Ollama is already installed
    local ollama_running=false
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        if echo "$name" | grep -qi "ollama"; then
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$name"; then
                ollama_running=true
            fi
        fi
    done

    if $ollama_running; then
        echo -e "  ${GREEN}Ollama is running!${NC}"
        echo ""
        echo -e "  ${BOLD}[1]${NC}  Pull a model"
        echo -e "  ${BOLD}[2]${NC}  List installed models"
        echo -e "  ${BOLD}[3]${NC}  Open Ollama Web UI"
        echo -e "  ${BOLD}[4]${NC}  Stop Ollama"
        echo -e "  ${BOLD}[0]${NC}  Back"
        echo ""
        read -p "  Select: " choice
        case $choice in
            1) ai_pull_model ;;
            2) ai_list_models ;;
            3) ai_open_ollama_ui ;;
            4) svc_stop "ollama"; press_enter ;;
            0) return ;;
        esac
        return
    fi

    echo -e "  Available models (by size):"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Tiny${NC}     (1B)    - Quick tasks, low RAM"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Small${NC}    (3B)    - Good balance"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Medium${NC}   (7B)    - Better quality"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Large${NC}    (13B)   - High quality"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}Custom${NC}   - Enter model name"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select model size: " choice

    local model=""
    case $choice in
        1) model="tinyllama" ;;
        2) model="mistral" ;;
        3) model="llama2" ;;
        4) model="llama2:13b" ;;
        5) model=$(prompt_value "  Model name (e.g. codellama, phi2)") ;;
        0) return ;;
    esac

    echo ""
    confirm "  Install Ollama with $model?" || { press_enter; return; }

    check_docker_available || { press_enter; return; }
    check_storage "$PALLADIUM_HOME" || { press_enter; return; }

    local target="$INSTALLED_DIR/ollama"
    mkdir -p "$target/data"

    cat > "$target/docker-compose.yml" << 'COMPOSE'
version: "3.8"
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - ./data:/root/.ollama
COMPOSE

    echo "11434" > "$target/.port"
    cat > "$target/.meta" << EOF
service=ai
instance=ollama
type=local-llm
model=$model
port=11434
EOF

    echo -e "${YELLOW}Pulling Ollama...${NC}"
    cd "$target"
    pull_image_with_fallback "ollama/ollama:latest" "" "$target/docker-compose.yml" || {
        show_install_error "ollama" "Could not pull image"
        press_enter; return
    }

    echo -e "${YELLOW}Starting Ollama...${NC}"
    run_with_retry "docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null" 3 5 || {
        show_install_error "ollama" "Failed to start"
        press_enter; return
    }

    # Wait for Ollama to be ready
    echo -e "${DIM}Waiting for Ollama...${NC}"
    sleep 5

    # Pull the model
    echo -e "${YELLOW}Pulling model: $model...${NC}"
    docker exec ollama ollama pull "$model" 2>/dev/null || {
        echo -e "${YELLOW}Model will download when you first use it.${NC}"
    }

    echo ""
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    echo -e "${GREEN}  Ollama is running!${NC}"
    echo -e "${GREEN}  Model: $model${NC}"
    echo -e "${GREEN}  API: http://localhost:11434${NC}"
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    echo ""
    echo -e "  ${DIM}Use the API in your apps:${NC}"
    echo -e "  ${DIM}curl http://localhost:11434/api/generate -d '{\"model\":\"$model\",\"prompt\":\"Hello\"}'${NC}"
    echo ""
    press_enter
}

ai_pull_model() {
    local model=$(prompt_value "  Model to pull (e.g. codellama, phi2, mistral)")
    [ -z "$model" ] && return
    echo -e "${YELLOW}Pulling $model...${NC}"
    docker exec ollama ollama pull "$model" 2>/dev/null
    echo -e "${GREEN}Model $model ready.${NC}"
    press_enter
}

ai_list_models() {
    echo -e "${CYAN}Installed models:${NC}"
    echo ""
    docker exec ollama ollama list 2>/dev/null || echo "  Could not list models."
    press_enter
}

ai_open_ollama_ui() {
    echo -e "${GREEN}Opening Ollama API...${NC}"
    if command -v xdg-open &>/dev/null; then xdg-open "http://localhost:11434" 2>/dev/null &
    elif command -v chromium-browser &>/dev/null; then chromium-browser "http://localhost:11434" 2>/dev/null &
    fi
    press_enter
}

ai_api_connector() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ AI API Connectors ═══${NC}"
    echo ""
    echo -e "  ${DIM}Connect to cloud AI APIs. You need API keys.${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}OpenAI${NC}      GPT-4, DALL-E, Whisper, Embeddings"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Anthropic${NC}   Claude 3.5, Claude 3"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Google${NC}      Gemini Pro, PaLM, Embeddings"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Groq${NC}        Fast inference (Llama, Mixtral, Gemma)"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}Cohere${NC}     Command, Embed"
    echo -e "  ${BOLD}[6]${NC}  ${GREEN}AwsBedrock${NC}  Titan, Claude, Llama models"
    echo -e "  ${BOLD}[7]${NC}  ${GREEN}HuggingFace${NC} Open-source models, APIs"
    echo -e "  ${BOLD}[8]${NC}  ${GREEN}Stability${NC}   Image generation (SDXL, Firefly)"
    echo -e "  ${BOLD}[9]${NC}  ${GREEN}Replicate${NC}   Run any ML model via API"
    echo -e "  ${BOLD}[10]${NC} ${GREEN}ElevenLabs${NC}  Text-to-speech and voice AI"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select provider: " choice
    case $choice in
        1) ai_setup_connector "openai" "OpenAI" "https://api.openai.com/v1" ;;
        2) ai_setup_connector "anthropic" "Anthropic" "https://api.anthropic.com" ;;
        3) ai_setup_connector "google" "Google AI" "https://generativelanguage.googleapis.com" ;;
        4) ai_setup_connector "groq" "Groq" "https://api.groq.com/openai/v1" ;;
        5) ai_setup_connector "cohere" "Cohere" "https://api.cohere.com/v1" ;;
        6) ai_setup_connector "awsbedrock" "AWS Bedrock" "https://bedrock-runtime.aws.amazon.com" ;;
        7) ai_setup_connector "huggingface" "Hugging Face" "https://api-inference.huggingface.co" ;;
        8) ai_setup_connector "stability" "Stability AI" "https://api.stability.ai" ;;
        9) ai_setup_connector "replicate" "Replicate" "https://api.replicate.com" ;;
        10) ai_setup_connector "elevenlabs" "ElevenLabs" "https://api.elevenlabs.io" ;;
        0) return ;;
    esac
}

ai_setup_connector() {
    local id="$1"
    local name="$2"
    local base_url="$3"

    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ $name Connector ═══${NC}"
    echo ""

    local api_key=$(prompt_password "  API key")
    [ -z "$api_key" ] && { echo -e "${YELLOW}Cancelled.${NC}"; press_enter; return; }

    if [ "$id" = "custom" ]; then
        base_url=$(prompt_value "  API base URL")
    fi

    local config_file="$DATA_DIR/ai-$id.conf"
    cat > "$config_file" << EOF
PROVIDER=$name
API_KEY=$api_key
BASE_URL=$base_url
EOF
    chmod 600 "$config_file"

    echo ""
    echo -e "${GREEN}  $name connected!${NC}"
    echo ""
    echo -e "  ${DIM}Use in your apps:${NC}"
    echo -e "  ${DIM}Source $config_file${NC}"
    echo -e "  ${DIM}curl $base_url/chat/completions -H \"Authorization: Bearer \$API_KEY\"${NC}"
    echo ""
    press_enter
}

ai_rag_pipeline() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ RAG Pipeline ═══${NC}"
    echo ""
    echo -e "  ${DIM}Retrieval-Augmented Generation: search your documents with AI.${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}ChromaDB${NC}       Vector database"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Qdrant${NC}         High-performance vector DB"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Full RAG${NC}       Vector DB + embeddings + LLM"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) marketplace_install_tool "chromadb" "chromadb/chroma:latest" "8000" ;;
        2) marketplace_install_tool "qdrant" "qdrant/qdrant:latest" "6333" ;;
        3) ai_full_rag ;;
        0) return ;;
    esac
}

ai_full_rag() {
    echo -e "${CYAN}Installing full RAG pipeline...${NC}"
    echo ""

    # Check for Ollama
    local has_ollama=false
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        if echo "$(basename "$svc_dir")" | grep -qi "ollama"; then
            has_ollama=true
            break
        fi
    done

    if ! $has_ollama; then
        echo -e "${YELLOW}Ollama not found. Install it first for local LLMs.${NC}"
        echo -e "${DIM}Or use an API connector (OpenAI, etc.)${NC}"
        echo ""
    fi

    confirm "  Install ChromaDB + embeddings?" || { press_enter; return; }

    # Install ChromaDB
    marketplace_install_tool "chromadb" "chromadb/chroma:latest" "8000"
}

ai_agent() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ AI Agent Builder ═══${NC}"
    echo ""
    echo -e "  ${DIM}Build custom AI agents with tools and memory.${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Langflow${NC}     Visual agent builder"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Flowise${NC}      Chatflow builder"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Dify${NC}         AI app development platform"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) marketplace_install_tool "langflow" "langflow/langflow:latest" "7860" ;;
        2) marketplace_install_tool "flowise" "flowiseai/flowise:latest" "3000" ;;
        3) marketplace_install_tool "dify" "langgenius/dify:latest" "3000" ;;
        0) return ;;
    esac
}

ai_custom() {
    wizard_custom
}

ai_setup_apps() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}  ═══ AI & Business Apps ═══${NC}"
    echo ""
    echo -e "  ${DIM}Popular business APIs for n8n workflows.${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Stripe${NC}           Payment processing, subscriptions"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}SendGrid${NC}        Email marketing and delivery"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}PostHog${NC}         Product analytics and feature flags"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Redis${NC}           In-memory data store for caching"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}PostgreSQL${NC}      Relational database for workflows"
    echo -e "  ${BOLD}[6]${NC}  ${GREEN}MySQL${NC}           Popular database for n8n"
    echo -e "  ${BOLD}[7]${NC}  ${GREEN}MongoDB${NC}        Document database"
    echo -e "  ${BOLD}[8]${NC}  ${GREEN}Elasticsearch${NC}  Search and analytics"
    echo -e "  ${BOLD}[9]${NC}  ${GREEN}Kafka${NC}           Event streaming platform"
    echo -e "  ${BOLD}[10]${NC} ${GREEN}RabbitMQ${NC}        Message broker"
    echo -e "  ${BOLD}[11]${NC} ${GREEN}GraphQL${NC}         API query language"
    echo -e "  ${BOLD}[12]${NC} ${GREEN}REST API${NC}        Standard web service protocol"
    echo -e "  ${BOLD}[13]${NC} ${GREEN}Webhook${NC}         Event-driven HTTP callbacks"
    echo -e "  ${BOLD}[14]${NC} ${GREEN}Telegram Bot${NC}   Chat bot API"
    echo -e "  ${BOLD}[15]${NC} ${GREEN}Slack${NC}           Team collaboration API"
    echo -e "  ${BOLD}[16]${NC} ${GREEN}Discord${NC}         Gaming/communication API"
    echo -e "  ${BOLD}[17]${NC} ${GREEN}Twilio${NC}          SMS, voice, and messaging API"
    echo -e "  ${BOLD}[18]${NC} ${GREEN}Auth0${NC}           User authentication and identity"
    echo -e "  ${BOLD}[19]${NC} ${GREEN}Firebase${NC}        Backend-as-a-service platform"
    echo -e "  ${BOLD}[20]${NC} ${GREEN}Cloudinary${NC}      Image/video hosting and optimization"
    echo -e "  ${BOLD}[21]${NC} ${GREEN}AWS Lambda${NC}      Serverless compute"
    echo -e "  ${BOLD}[22]${NC} ${GREEN}GCP Cloud Functions${NC} Serverless platform"
    echo -e "  ${BOLD}[23]${NC} ${GREEN}CloudWatch${NC}      Monitoring and logging"
    echo -e "  ${BOLD}[24]${NC} ${GREEN}DynamoDB${NC}      NoSQL database"
    echo -e "  ${BOLD}[25]${NC} ${GREEN}S3${NC}             Object storage"
    echo -e "  ${BOLD}[26]${NC} ${GREEN}CloudFront${NC}     CDN distribution"
    echo -e "  ${BOLD}[27]${NC} ${GREEN}Route53${NC}         DNS management"
    echo -e "  ${BOLD}[28]${NC} ${GREEN}Docker Hub${NC}     Container registry"
    echo -e "  ${BOLD}[29]${NC} ${GREEN}GitHub${NC}          Code hosting and CI/CD"
    echo -e "  ${BOLD}[30]${NC} ${GREEN}GitLab${NC}          DevOps platform"
    echo -e "  ${BOLD}[31]${NC} ${GREEN}Jenkins${NC}         CI/CD automation"
    echo -e "  ${BOLD}[32]${NC} ${GREEN}Ansible${NC}         Configuration management"
    echo -e "  ${BOLD}[33]${NC} ${GREEN}Terraform${NC}      Infrastructure as code"
    echo -e "  ${BOLD}[34]${NC} ${GREEN}Vault${NC}           Secrets management"
    echo -e "  ${BOLD}[35]${NC} ${GREEN}Consul${NC}          Service discovery and mesh"
    echo -e "  ${BOLD}[36]${NC} ${GREEN}Prometheus${NC}     Monitoring and alerting"
    echo -e "  ${BOLD}[37]${NC} ${GREEN}Grafana${NC}        Visualization and monitoring"
    echo -e "  ${BOLD}[38]${NC} ${GREEN}Jenkins${NC}         CI/CD automation"
    echo -e "  ${BOLD}[39]${NC} ${GREEN}Nginx${NC}           Reverse proxy and load balancer"
    echo -e "  ${BOLD}[40]${NC} ${GREEN}WordPress${NC}       Content management system"
    echo -e "  ${BOLD}[41]${NC} ${GREEN}Shopify${NC}         E-commerce platform"
    echo -e "  ${BOLD}[42]${NC} ${GREEN}Selenium${NC}       Web automation"
    echo -e "  ${BOLD}[43]${NC} ${GREEN}TestRail${NC}       Test management"
    echo -e "  ${BOLD}[44]${NC} ${GREEN}Jira${NC}           Project tracking"
    echo -e "  ${BOLD}[45]${NC} ${GREEN}Confluence${NC}      Documentation"
    echo -e "  ${BOLD}[46]${NC} ${GREEN}Slack${NC}           Team communication"
    echo -e "  ${BOLD}[47]${NC} ${GREEN}Zoom${NC}            Video conferencing"
    echo -e "  ${BOLD}[48]${NC} ${GREEN}Stripe${NC}         Payment processing"
    echo -e "  ${BOLD}[49]${NC} ${GREEN}PayPal${NC}         Alternative payment processor"
    echo -e "  ${BOLD}[50]${NC} ${GREEN}Adyen${NC}          Global payment platform"
    echo -e "  ${BOLD}[51]${NC} ${GREEN}Square${NC}          POS and payment processing"
    echo -e "  ${BOLD}[52]${NC} ${GREEN}QuickBooks${NC}      Accounting software"
    echo -e "  ${BOLD}[53]${NC} ${GREEN}Xero${NC}           Accounting platform"
    echo -e "  ${BOLD}[54]${NC} ${GREEN}Mailchimp${NC}      Email marketing"
    echo -e "  ${BOLD}[55]${NC} ${GREEN}HubSpot${NC}        CRM and marketing"
    echo -e "  ${BOLD}[56]${NC} ${GREEN}Salesforce${NC}      Enterprise CRM"
    echo -e "  ${BOLD}[57]${NC} ${GREEN}Zoho${NC}            Business suite"
    echo -e "  ${BOLD}[58]${NC} ${GREEN}Google Workspace${NC} Suite of productivity tools"
    echo -e "  ${BOLD}[59]${NC} ${GREEN}Microsoft 365${NC}   Office 365 suite"
    echo -e "  ${BOLD}[60]${NC} ${GREEN}Dropbox${NC}         File storage and sharing"
    echo -e "  ${BOLD}[61]${NC} ${GREEN}Box${NC}             Cloud storage platform"
    echo -e "  ${BOLD}[62]${NC} ${GREEN}OneDrive${NC}        Microsoft cloud storage"
    echo -e "  ${BOLD}[63]${NC} ${GREEN}Google Drive${NC}    File hosting service"
    echo -e "  ${BOLD}[64]${NC} ${GREEN}Onedrive${NC}        Microsoft cloud storage"
    echo -e "  ${BOLD}[65]${NC} ${GREEN}SharePoint${NC}      Microsoft collaboration platform"
    echo -e "  ${BOLD}[66]${NC} ${GREEN}Basecamp${NC}       Project management"
    echo -e "  ${BOLD}[67]${NC} ${GREEN}Trello${NC}         Project board"
    echo -e "  ${BOLD}[68]${NC} ${GREEN}Asana${NC}          Project management"
    echo -e "  ${BOLD}[69]${NC} ${GREEN}Monday.com${NC}      Work OS"
    echo -e "  ${BOLD}[70]${NC} ${GREEN}Notion${NC}          All-in-one workspace"
    echo -e "  ${BOLD}[71]${NC} ${GREEN}Airtable${NC}        Database and spreadsheet"
    echo -e "  ${BOLD}[72]${NC} ${GREEN}Civictech${NC}      Civic technology solutions"
    echo -e "  ${BOLD}[73]${NC} ${GREEN}OpenAI${NC}         GPT and DALL-E APIs"
    echo -e "  ${BOLD}[74]${NC} ${GREEN}Anthropic${NC}       Claude models"
    echo -e "  ${BOLD}[75]${NC} ${GREEN}Google AI${NC}      Gemini and PaLM"
    echo -e "  ${BOLD}[76]${NC} ${GREEN}Groq${NC}            Fast inference"
    echo -e "  ${BOLD}[77]${NC} ${GREEN}Cohere${NC}         Command and Embed"
    echo -e "  ${BOLD}[78]${NC} ${GREEN}AwsBedrock${NC}     Bedrock models"
    echo -e "  ${BOLD}[79]${NC} ${GREEN}HuggingFace${NC}   Open source models"
    echo -e "  ${BOLD}[80]${NC} ${GREEN}Stability${NC}      SDXL and Firefly"
    echo -e "  ${BOLD}[81]${NC} ${GREEN}Replicate${NC}      Any ML model"
    echo -e "  ${BOLD}[82]${NC} ${GREEN}ElevenLabs${NC}     Voice and TTS"
    echo -e "  ${BOLD}[83]${NC} ${GREEN}API Tools${NC}      Other useful APIs"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select service: " choice
    case $choice in
        1) marketplace_custom_install "stripe" "stripe/stripe:latest" "3000" ;;
        2) marketplace_custom_install "sendgrid" "sendgrid/sendgrid:latest" "3000" ;;
        3) marketplace_custom_install "posthog" "posthog/posthog:latest" "3000" ;;
        4) marketplace_custom_install "redis" "redis:latest" "6379" ;;
        5) marketplace_custom_install "postgresql" "postgres:15-alpine" "5432" ;;
        6) marketplace_custom_install "mysql" "mysql:8.0" "3306" ;;
        7) marketplace_custom_install "mongodb" "mongo:latest" "27017" ;;
        8) marketplace_custom_install "elasticsearch" "elasticsearch:8" "9200" ;;
        9) marketplace_custom_install "kafka" "confluentinc/cp-kafka:latest" "9092" ;;
        10) marketplace_custom_install "rabbitmq" "rabbitmq:3" "5672" ;;
        11) marketplace_custom_install "graphql" "graphql/graphql-server:latest" "8080" ;;
        12) marketplace_custom_install "rest-api" "nginx:latest" "80" ;;
        13) marketplace_custom_install "webhook" "webhook/webhook-server:latest" "8000" ;;
        14) marketplace_custom_install "telegram" "telegraf/gravatar:latest" "80" ;;
        15) marketplace_custom_install "slack" "slack/api:latest" "80" ;;
        16) marketplace_custom_install "discord" "discord/api:latest" "80" ;;
        17) marketplace_custom_install "twilio" "twilio/api:latest" "80" ;;
        18) marketplace_custom_install "auth0" "auth0/api:latest" "80" ;;
        19) marketplace_custom_install "firebase" "firebase/api:latest" "80" ;;
        20) marketplace_custom_install "cloudinary" "cloudinary/api:latest" "80" ;;
        21) marketplace_custom_install "aws-lambda" "aws/lambda:latest" "80" ;;
        22) marketplace_custom_install "gcp-functions" "gcp/functions:latest" "80" ;;
        23) marketplace_custom_install "cloudwatch" "aws/cloudwatch:latest" "80" ;;
        24) marketplace_custom_install "dynamodb" "aws/dynamodb:latest" "80" ;;
        25) marketplace_custom_install "s3" "aws/s3:latest" "80" ;;
        26) marketplace_custom_install "cloudfront" "aws/cloudfront:latest" "80" ;;
        27) marketplace_custom_install "route53" "aws/route53:latest" "80" ;;
        28) marketplace_custom_install "dockerhub" "dockerhub/api:latest" "80" ;;
        29) marketplace_custom_install "github" "github/api:latest" "80" ;;
        30) marketplace_custom_install "gitlab" "gitlab/api:latest" "80" ;;
        31) marketplace_custom_install "jenkins" "jenkins/api:latest" "80" ;;
        32) marketplace_custom_install "ansible" "ansible/api:latest" "80" ;;
        33) marketplace_custom_install "terraform" "hashicorp/terraform:latest" "80" ;;
        34) marketplace_custom_install "vault" "hashicorp/vault:latest" "80" ;;
        35) marketplace_custom_install "consul" "hashicorp/consul:latest" "80" ;;
        36) marketplace_custom_install "prometheus" "prometheus/prometheus:latest" "80" ;;
        37) marketplace_custom_install "grafana" "grafana/grafana:latest" "80" ;;
        38) marketplace_custom_install "jenkins-2" "jenkinsci/jenkins:latest" "8080" ;;
        39) marketplace_custom_install "nginx" "nginx/nginx:latest" "80" ;;
        40) marketplace_custom_install "wordpress" "wordpress:latest" "80" ;;
        41) marketplace_custom_install "shopify" "shopify/shopify:latest" "80" ;;
        42) marketplace_custom_install "selenium" "selenium/standalone-chrome:latest" "4444" ;;
        43) marketplace_custom_install "testrail" "testrail/api:latest" "80" ;;
        44) marketplace_custom_install "jira" "atlassian/jira:latest" "8080" ;;
        45) marketplace_custom_install "confluence" "atlassian/confluence:latest" "8090" ;;
        46) marketplace_custom_install "slack-2" "slack/api:latest" "80" ;;
        47) marketplace_custom_install "zoom" "zoom/api:latest" "80" ;;
        48) marketplace_custom_install "stripe-2" "stripe/stripe:latest" "3000" ;;
        49) marketplace_custom_install "paypal" "paypal/api:latest" "80" ;;
        50) marketplace_custom_install "adyen" "adyen/api:latest" "80" ;;
        51) marketplace_custom_install "square" "square/api:latest" "80" ;;
        52) marketplace_custom_install "quickbooks" "intuit/quickbooks:latest" "80" ;;
        53) marketplace_custom_install "xero" "xero/api:latest" "80" ;;
        54) marketplace_custom_install "mailchimp" "mailchimp/api:latest" "80" ;;
        55) marketplace_custom_install "hubspot" "hubspot/api:latest" "80" ;;
        56) marketplace_custom_install "salesforce" "salesforce/api:latest" "80" ;;
        57) marketplace_custom_install "zoho" "zoho/api:latest" "80" ;;
        58) marketplace_custom_install "google-workspace" "google/workspace:latest" "80" ;;
        59) marketplace_custom_install "microsoft365" "microsoft/365:latest" "80" ;;
        60) marketplace_custom_install "dropbox" "dropbox/api:latest" "80" ;;
        61) marketplace_custom_install "box" "box/api:latest" "80" ;;
        62) marketplace_custom_install "onedrive" "microsoft/onedrive:latest" "80" ;;
        63) marketplace_custom_install "googledrive" "google/drive:latest" "80" ;;
        64) marketplace_custom_install "onedrive-2" "microsoft/onedrive:latest" "80" ;;
        65) marketplace_custom_install "sharepoint" "microsoft/sharepoint:latest" "80" ;;
        66) marketplace_custom_install "basecamp" "basecamp/api:latest" "80" ;;
        67) marketplace_custom_install "trello" "trello/api:latest" "80" ;;
        68) marketplace_custom_install "asana" "asana/api:latest" "80" ;;
        69) marketplace_custom_install "monday" "monday/api:latest" "80" ;;
        70) marketplace_custom_install "notion" "notion/api:latest" "80" ;;
        71) marketplace_custom_install "airtable" "airtable/api:latest" "80" ;;
        72) marketplace_custom_install "civictech" "civictech/api:latest" "80" ;;
        73) marketplace_custom_install "openai" "openai/api:latest" "80" ;;
        74) marketplace_custom_install "anthropic" "anthropic/api:latest" "80" ;;
        75) marketplace_custom_install "google-ai" "google/ai:latest" "80" ;;
        76) marketplace_custom_install "groq" "groq/api:latest" "80" ;;
        77) marketplace_custom_install "cohere" "cohere/api:latest" "80" ;;
        78) marketplace_custom_install "awsbedrock" "aws/bedrock:latest" "80" ;;
        79) marketplace_custom_install "huggingface" "huggingface/api:latest" "80" ;;
        80) marketplace_custom_install "stability" "stability/api:latest" "80" ;;
        81) marketplace_custom_install "replicate" "replicate/api:latest" "80" ;;
        82) marketplace_custom_install "elevenlabs" "elevenlabs/api:latest" "80" ;;
        83) marketplace_custom_install "api-tools" "generic/api:latest" "80" ;;
        0) return ;;
    esac
}
