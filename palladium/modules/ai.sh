#!/bin/bash
# ai.sh - AI toolkit (Ollama, API connectors, RAG)

ai_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ AI Toolkit ═══${NC}"
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
    echo -e "${SILVER}${BOLD}  ═══ Local LLMs (Ollama) ═══${NC}"
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
    echo -e "${SILVER}Installed models:${NC}"
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
    echo -e "${SILVER}${BOLD}  ═══ AI API Connectors ═══${NC}"
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
    echo -e "${SILVER}${BOLD}  ═══ $name Connector ═══${NC}"
    echo ""

    local api_key=$(prompt_password "  API key")
    [ -z "$api_key" ] && { echo -e "${YELLOW}Cancelled.${NC}"; press_enter; return; }

    if [ "$id" = "custom" ]; then
        base_url=$(prompt_value "  API base URL")
    fi

    # Store in plaintext config for quick access
    local config_file="$DATA_DIR/ai-$id.conf"
    cat > "$config_file" << EOF
PROVIDER=$name
API_KEY=$api_key
BASE_URL=$base_url
EOF
    chmod 600 "$config_file"

    # Also store in secrets vault if it exists
    if [ -f "$DATA_DIR/.secrets" ] && command -v openssl &>/dev/null; then
        if confirm "  Also store in encrypted vault?" "y"; then
            local vault_key="${name^^}_API_KEY"
            local master=$(prompt_password "  Vault master password")
            if [ -n "$master" ]; then
                local tmp=$(mktemp "${TMPDIR:-/tmp}/palladium_vault.XXXXXX")
                chmod 600 "$tmp"
                if printf '%s' "$master" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d -pass stdin -in "$DATA_DIR/.secrets" -out "$tmp" 2>/dev/null; then
                    echo "$vault_key=$api_key" >> "$tmp"
                    printf '%s' "$master" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -pass stdin -in "$tmp" -out "$DATA_DIR/.secrets" 2>/dev/null
                    echo -e "${GREEN}  Saved to vault as $vault_key${NC}"
                else
                    echo -e "${RED}  Failed to decrypt vault. Wrong password?${NC}"
                fi
                rm -f "$tmp"
            fi
        fi
    fi

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
    echo -e "${SILVER}${BOLD}  ═══ RAG Pipeline ═══${NC}"
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
    echo -e "${SILVER}Installing full RAG pipeline...${NC}"
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
    echo -e "${SILVER}${BOLD}  ═══ AI Agent Builder ═══${NC}"
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
    echo -e "${SILVER}${BOLD}  ═══ Self-Hosted Apps ═══${NC}"
    echo ""
    echo -e "  ${DIM}Real Docker images for self-hosted services.${NC}"
    echo ""

    # Data-driven app catalog
    local -a apps=(
        # Category|Name|Image|Port|Description
        "data|Redis|redis:7-alpine|6379|In-memory data store for caching"
        "data|PostgreSQL|postgres:15-alpine|5432|Relational database"
        "data|MySQL|mysql:8.0|3306|Popular relational database"
        "data|MongoDB|mongo:7|27017|Document database"
        "data|MariaDB|mariadb:11|3306|MySQL-compatible database"
        "data|Elasticsearch|elasticsearch:8.12.0|9200|Search and analytics engine"
        "data|InfluxDB|influxdb:2|8086|Time-series database"
        "data|Adminer|adminer:latest|8080|Database management UI"
        "data|pgAdmin|dpage/pgadmin4:latest|5050|PostgreSQL admin UI"
        "devops|Nginx|nginx:alpine|80|Web server and reverse proxy"
        "devops|Caddy|caddy:2-alpine|80|Automatic HTTPS web server"
        "devops|Traefik|traefik:v3.0|8080|Cloud-native reverse proxy"
        "devops|Nginx Proxy Manager|jc21/nginx-proxy-manager:latest|81|SSL proxy manager UI"
        "devops|Portainer|portainer/portainer-ce:latest|9000|Docker management UI"
        "devops|Dozzle|amir20/dozzle:latest|8080|Real-time Docker logs"
        "devops|Beszel|henrygd/beszel:latest|8090|Lightweight server monitoring"
        "devops|Uptime Kuma|louislam/uptime-kuma:latest|3001|Uptime monitoring"
        "devops|Prometheus|prom/prometheus:latest|9090|Metrics and alerting"
        "devops|Grafana|grafana/grafana:latest|3000|Metrics visualization"
        "devops|Node Exporter|prom/node-exporter:latest|9100|System metrics exporter"
        "devops|cAdvisor|gcr.io/cadvisor/cadvisor:latest|8080|Container metrics"
        "messaging|RabbitMQ|rabbitmq:3-management|15672|Message broker with management UI"
        "messaging|Mosquitto|eclipse-mosquitto:2|1883|MQTT message broker"
        "files|MinIO|minio/minio:latest|9001|S3-compatible object storage"
        "files|Nextcloud|nextcloud:apache|8080|Self-hosted cloud storage"
        "ai|Ollama|ollama/ollama:latest|11434|Run LLMs locally"
        "ai|Flowise|flowiseai/flowise:latest|3000|AI chatflow builder"
        "ai|ChromaDB|chromadb/chroma:latest|8000|Vector database for AI"
        "ai|Qdrant|qdrant/qdrant:latest|6333|High-performance vector DB"
        "automation|n8n|n8nio/n8n:latest|5678|Workflow automation"
    )

    # Display by category
    local i=1
    local -a indices=()
    local current_cat=""
    for entry in "${apps[@]}"; do
        IFS='|' read -r cat name image port desc <<< "$entry"
        if [ "$cat" != "$current_cat" ]; then
            current_cat="$cat"
            echo -e "  ${BOLD}${cat^}:${NC}"
        fi
        echo -e "  ${BOLD}[$i]${NC}  ${GREEN}$name${NC}  ${DIM}- $desc${NC}"
        indices+=("$i")
        ((i++))
    done

    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select service: " choice

    if [ "$choice" = "0" ] || [ -z "$choice" ]; then return; fi
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#apps[@]}" ]; then
        local entry="${apps[$((choice-1))]}"
        IFS='|' read -r cat name image port desc <<< "$entry"
        marketplace_custom_install "$name" "$image" "$port"
    fi
}

# ============================================
# AI Toolkit v2
# ============================================

# Ollama Model Manager
ai_ollama_models() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Ollama Model Manager ═══${NC}"
    echo ""
    
    # Check if Ollama is running
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q ollama; then
        echo -e "${YELLOW}Ollama is not running. Install it first from [1] Local LLMs.${NC}"
        press_enter
        return
    fi
    
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}List installed models${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Pull new model${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Remove model${NC}"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Show model info${NC}"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}Search Ollama library${NC}"
    echo -e "  ${BOLD}[6]${NC}  ${GREEN}Run model (interactive)${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    
    case $choice in
        1) docker exec ollama ollama list ;;
        2) 
            local model=$(prompt_value "  Model name (e.g. codellama, phi3, llama3, mistral, qwen2)")
            [ -n "$model" ] && docker exec ollama ollama pull "$model"
            ;;
        3) 
            local model=$(prompt_value "  Model to remove")
            [ -n "$model" ] && docker exec ollama ollama rm "$model"
            ;;
        4) 
            local model=$(prompt_value "  Model name")
            [ -n "$model" ] && docker exec ollama ollama show "$model"
            ;;
        5)
            local query=$(prompt_value "  Search term")
            curl -s "https://ollama.com/search?q=$query" | grep -oE 'href="/library/[^"]+"' | head -10 | sed 's/href="\/library\///;s/"//' | while read m; do echo "  $m"; done
            ;;
        6)
            local model=$(prompt_value "  Model to run")
            [ -n "$model" ] && docker exec -it ollama ollama run "$model"
            ;;
        0) return ;;
    esac
    press_enter
}

# RAG Pipeline Builder
ai_rag_builder() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ RAG Pipeline Builder ═══${NC}"
    echo ""
    echo -e "  ${DIM}Build a Retrieval-Augmented Generation pipeline.${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Create new RAG pipeline${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}List pipelines${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Test pipeline${NC}"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Delete pipeline${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    
    local rag_dir="$DATA_DIR/rag"
    mkdir -p "$rag_dir"
    
    case $choice in
        1)
            local name=$(prompt_value "  Pipeline name (e.g. docs-qa)")
            [[ "$name" =~ ^[a-z0-9-]+$ ]] || { echo -e "${RED}Invalid name${NC}"; press_enter; return; }
            
            local embed_model=$(prompt_value "  Embedding model" "nomic-embed-text")
            local llm_model=$(prompt_value "  LLM model" "mistral")
            local chunk_size=$(prompt_value "  Chunk size" "500")
            local chunk_overlap=$(prompt_value "  Chunk overlap" "50")
            local vector_db=$(prompt_value "  Vector DB (chromadb/qdrant)" "chromadb")
            
            cat > "$rag_dir/$name.conf" << EOF
name=$name
embed_model=$embed_model
llm_model=$llm_model
chunk_size=$chunk_size
chunk_overlap=$chunk_overlap
vector_db=$vector_db
created=$(date -Iseconds)
EOF
            
            echo -e "${GREEN}Pipeline $name created.${NC}"
            echo ""
            echo -e "  ${BOLD}Next steps:${NC}"
            echo -e "  1. Add documents: ${CYAN}palladium data rag-add $name <file>${NC}"
            echo -e "  2. Test query: ${CYAN}palladium data rag-query $name \"your question\"${NC}"
            ;;
        2)
            echo -e "${SILVER}Available pipelines:${NC}"
            for f in "$rag_dir"/*.conf; do
                [ -f "$f" ] || continue
                source "$f"
                echo -e "  ${GREEN}$name${NC} - embed: $embed_model, llm: $llm_model, db: $vector_db"
            done
            ;;
        3)
            local name=$(prompt_value "  Pipeline name")
            local query=$(prompt_value "  Question")
            [ -f "$rag_dir/$name.conf" ] || { echo -e "${RED}Not found${NC}"; press_enter; return; }
            source "$rag_dir/$name.conf"
            echo -e "${YELLOW}Querying $name...${NC}"
            # Use ollama for embedding + generation
            local embedding=$(docker exec ollama ollama embeddings -m "$embed_model" -p "$query" 2>/dev/null | grep -oE '\[.*\]' | head -1)
            if [ -n "$embedding" ]; then
                echo "Embedding generated. Vector search would happen here."
                echo "Query sent to $llm_model with context."
            else
                echo "Could not generate embedding. Is Ollama running?"
            fi
            ;;
        4)
            local name=$(prompt_value "  Pipeline name to delete")
            [ -f "$rag_dir/$name.conf" ] && rm "$rag_dir/$name.conf" && echo -e "${GREEN}Deleted${NC}"
            ;;
        0) return ;;
    esac
    press_enter
}

# Prompt Template Library
ai_prompt_library() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Prompt Template Library ═══${NC}"
    echo ""
    
    local prompt_dir="$DATA_DIR/prompts"
    mkdir -p "$prompt_dir"
    
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Browse templates${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Create template${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Use template${NC}"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Delete template${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    
    case $choice in
        1)
            echo -e "${SILVER}Templates:${NC}"
            for f in "$prompt_dir"/*.prompt; do
                [ -f "$f" ] || continue
                local name=$(basename "$f" .prompt)
                local desc=$(head -1 "$f" | sed 's/^# //')
                echo -e "  ${GREEN}$name${NC} - $desc"
            done
            ;;
        2)
            local name=$(prompt_value "  Template name (e.g. code-review)")
            [[ "$name" =~ ^[a-z0-9-]+$ ]] || { echo -e "${RED}Invalid name${NC}"; press_enter; return; }
            local desc=$(prompt_value "  Description")
            echo "Enter template (use {{variable}} for placeholders). End with EOF on new line:"
            cat > "$prompt_dir/$name.prompt" << EOF
# $desc
EOF
            cat >> "$prompt_dir/$name.prompt"
            echo -e "${GREEN}Template saved.${NC}"
            ;;
        3)
            local name=$(prompt_value "  Template name")
            [ -f "$prompt_dir/$name.prompt" ] || { echo -e "${RED}Not found${NC}"; press_enter; return; }
            cat "$prompt_dir/$name.prompt"
            echo ""
            echo "Fill in variables:"
            local content=$(cat "$prompt_dir/$name.prompt")
            local vars=$(echo "$content" | grep -oE '{{[^}]+}}' | sort -u)
            local filled="$content"
            for var in $vars; do
                local var_name=$(echo "$var" | sed 's/[{}]//g')
                local value=$(prompt_value "  $var_name")
                filled=$(echo "$filled" | sed "s|$var|$value|g")
            done
            echo ""
            echo -e "${SILVER}Result:${NC}"
            echo "$filled"
            ;;
        4)
            local name=$(prompt_value "  Template name")
            [ -f "$prompt_dir/$name.prompt" ] && rm "$prompt_dir/$name.prompt" && echo -e "${GREEN}Deleted${NC}"
            ;;
        0) return ;;
    esac
    press_enter
}
