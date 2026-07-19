#!/bin/bash
# data.sh - Data analysis workspace: SQL + AI

DATA_WORKSPACE="$DATA_DIR/workspace"
mkdir -p "$DATA_WORKSPACE/databases" "$DATA_WORKSPACE/exports" "$DATA_WORKSPACE/queries"

# Basic SQL injection prevention - block dangerous patterns
validate_sql_input() {
    local query="$1"
    # Block common SQL injection patterns
    if echo "$query" | grep -qiE ";\s*(DROP|DELETE|TRUNCATE|ALTER|CREATE|INSERT|UPDATE)"; then
        echo -e "${RED}  Blocked: multi-statement destructive queries not allowed.${NC}"
        return 1
    fi
    if echo "$query" | grep -qiE "\b(DROP|TRUNCATE|ALTER)\s+(TABLE|DATABASE)"; then
        echo -e "${RED}  Blocked: schema modification queries require confirmation.${NC}"
        if ! confirm "  This will modify the database schema. Continue?"; then
            return 1
        fi
    fi
    return 0
}

data_menu() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Data Analysis Workspace ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}Create database${NC}        New SQL database in seconds"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}Query database${NC}         Run SQL queries"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}AI analysis${NC}            Ask questions about your data"
    echo -e "  ${BOLD}[4]${NC}  ${GREEN}Import data${NC}            CSV, JSON, SQL files"
    echo -e "  ${BOLD}[5]${NC}  ${GREEN}Export data${NC}            Download results"
    echo -e "  ${BOLD}[6]${NC}  ${GREEN}Saved queries${NC}          Reuse past queries"
    echo -e "  ${BOLD}[7]${NC}  ${GREEN}AI + SQL combined${NC}      Natural language → SQL"
    echo -e "  ${BOLD}[8]${NC}  ${GREEN}Visualize${NC}              Charts from query results"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) data_create_db ;;
        2) data_query ;;
        3) data_ai_analysis ;;
        4) data_import ;;
        5) data_export ;;
        6) data_saved_queries ;;
        7) data_nl2sql ;;
        8) data_visualize ;;
        0) return ;;
    esac
}

data_create_db() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Create Database ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}SQLite${NC}        Fast, no setup, file-based"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}PostgreSQL${NC}    Full-featured, production-ready"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}Supabase${NC}      Cloud PostgreSQL (if connected)"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select type: " choice
    case $choice in
        1) data_create_sqlite ;;
        2) data_create_postgres ;;
        3) data_create_supabase ;;
        0) return ;;
    esac
}

data_create_sqlite() {
    echo ""
    local name=$(prompt_value "  Database name" "mydata")
    local db_file="$DATA_WORKSPACE/databases/$name.db"

    if [ -f "$db_file" ]; then
        echo -e "${YELLOW}Database '$name' already exists.${NC}"
        echo -e "  ${DIM}Location: $db_file${NC}"
        echo ""
        echo -e "  ${BOLD}[1]${NC}  Use existing"
        echo -e "  ${BOLD}[2]${NC}  Delete and create new"
        echo ""
        read -p "  Select: " choice
        [ "$choice" = "2" ] && rm -f "$db_file"
        [ "$choice" != "2" ] && [ "$choice" != "1" ] && return
    fi

    echo -e "${GREEN}  Creating SQLite database: $name${NC}"

    # Create with sample schema
    sqlite3 "$db_file" << 'SQL'
CREATE TABLE IF NOT EXISTS analysis_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    query TEXT NOT NULL,
    result TEXT,
    ai_insight TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS data_imports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT NOT NULL,
    table_name TEXT,
    row_count INTEGER,
    imported_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS saved_queries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    query TEXT NOT NULL,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
SQL

    # Save metadata
    cat > "$DATA_WORKSPACE/databases/$name.meta" << EOF
type=sqlite
name=$name
file=$db_file
created=$(date -Iseconds)
EOF

    echo ""
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    echo -e "${GREEN}  Database created!${NC}"
    echo -e "${GREEN}  Location: $db_file${NC}"
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    echo ""
    echo -e "  ${DIM}Tables created:${NC}"
    echo -e "    - analysis_results    (AI analysis storage)"
    echo -e "    - data_imports        (Import tracking)"
    echo -e "    - saved_queries       (Query library)"
    echo ""
    echo -e "  ${DIM}Next: [2] Query database or [4] Import data${NC}"
    press_enter
}

data_create_postgres() {
    echo ""

    # Check if PostgreSQL is running
    local pg_running=false
    local pg_port=""
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        if echo "$name" | grep -qi "postgres"; then
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$name"; then
                pg_running=true
                pg_port=$(cat "$svc_dir/.port" 2>/dev/null)
                break
            fi
        fi
    done

    if ! $pg_running; then
        echo -e "${YELLOW}PostgreSQL not running.${NC}"
        echo -e "  ${DIM}Install PostgreSQL first (from [2] Install service)${NC}"
        echo -e "  ${DIM}Or use SQLite (no setup needed)${NC}"
        press_enter; return
    fi

    local db_name=$(prompt_value "  Database name" "mydata")
    local db_user=$(prompt_value "  Database user" "postgres")
    local db_pass=$(prompt_password "  Database password")

    echo -e "${GREEN}  Creating PostgreSQL database: $db_name${NC}"

    # Find postgres container
    local pg_container=""
    for svc_dir in "$INSTALLED_DIR"/*/; do
        [ -d "$svc_dir" ] || continue
        local name=$(basename "$svc_dir")
        if echo "$name" | grep -qi "postgres"; then
            pg_container="$name"
            break
        fi
    done

    # Create database
    docker exec "$pg_container" psql -U "$db_user" -c "CREATE DATABASE $db_name;" 2>/dev/null

    # Create analysis tables
    docker exec "$pg_container" psql -U "$db_user" -d "$db_name" << 'SQL'
CREATE TABLE IF NOT EXISTS analysis_results (
    id SERIAL PRIMARY KEY,
    query TEXT NOT NULL,
    result JSONB,
    ai_insight TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS data_imports (
    id SERIAL PRIMARY KEY,
    filename TEXT NOT NULL,
    table_name TEXT,
    row_count INTEGER,
    imported_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS saved_queries (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    query TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
SQL

    # Save metadata
    cat > "$DATA_WORKSPACE/databases/$db_name.meta" << EOF
type=postgres
name=$db_name
host=localhost
port=$pg_port
user=$db_user
container=$pg_container
created=$(date -Iseconds)
EOF

    echo ""
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    echo -e "${GREEN}  PostgreSQL database created!${NC}"
    echo -e "${GREEN}  Database: $db_name${NC}"
    echo -e "${GREEN}  Port: $pg_port${NC}"
    echo -e "${GREEN}  ═══════════════════════════════════${NC}"
    press_enter
}

data_create_supabase() {
    if [ ! -f "$DATA_DIR/supabase.conf" ]; then
        echo -e "${RED}Supabase not connected.${NC}"
        echo -e "  ${DIM}Go to [7] Supabase to connect first.${NC}"
        press_enter; return
    fi

    [ -f "$DATA_DIR/supabase.conf" ] && source "$DATA_DIR/supabase.conf"
    echo -e "${GREEN}Using Supabase: $PROJECT_NAME${NC}"

    local db_name=$(prompt_value "  Table name" "analysis_results")

    # Create via Supabase SQL API
    curl -s "$SUPABASE_URL/rest/v1/rpc/exec_sql" \
        -H "apikey: $SUPABASE_ANON_KEY" \
        -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"CREATE TABLE IF NOT EXISTS $db_name (id SERIAL PRIMARY KEY, data JSONB, insight TEXT, created_at TIMESTAMP DEFAULT NOW())\"}" \
        2>/dev/null

    echo -e "${GREEN}Table created in Supabase!${NC}"
    press_enter
}

data_query() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Query Database ═══${NC}"
    echo ""

    # List available databases
    local databases=()
    local i=1

    for meta_file in "$DATA_WORKSPACE/databases"/*.meta; do
        [ -f "$meta_file" ] || continue
        local name=$(grep "^name=" "$meta_file" | cut -d= -f2)
        local type=$(grep "^type=" "$meta_file" | cut -d= -f2)
        databases+=("$meta_file")
        echo -e "  ${BOLD}[$i]${NC}  ${GREEN}$name${NC} ($type)"
        ((i++))
    done

    # Add Supabase if connected
    if [ -f "$DATA_DIR/supabase.conf" ]; then
        [ -f "$DATA_DIR/supabase.conf" ] && source "$DATA_DIR/supabase.conf"
        databases+=("supabase")
        echo -e "  ${BOLD}[$i]${NC}  ${GREEN}Supabase Cloud${NC} ($PROJECT_NAME)"
        ((i++))
    fi

    if [ ${#databases[@]} -eq 0 ]; then
        echo -e "  ${DIM}No databases yet. Create one first.${NC}"
        press_enter; return
    fi

    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select database: " choice

    if [ "$choice" = "0" ] || [ -z "$choice" ]; then return; fi
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#databases[@]}" ]; then
        local selected="${databases[$((choice-1))]}"
        data_run_query "$selected"
    fi
}

data_run_query() {
    local db_ref="$1"
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ SQL Query ═══${NC}"
    echo ""

    # Get connection info
    local db_type=""
    local db_name=""
    if [ "$db_ref" = "supabase" ]; then
        db_type="supabase"
        [ -f "$DATA_DIR/supabase.conf" ] && source "$DATA_DIR/supabase.conf"
        db_name="$PROJECT_NAME"
    elif [ -f "$db_ref" ]; then
        db_type=$(grep "^type=" "$db_ref" | cut -d= -f2)
        db_name=$(grep "^name=" "$db_ref" | cut -d= -f2)
    fi

    echo -e "  ${DIM}Database: $db_name ($db_type)${NC}"
    echo -e "  ${DIM}Type SQL queries below. Enter 'done' to finish.${NC}"
    echo ""

    local query=""
    local line=""

    while true; do
        echo -ne "${GREEN}sql> ${NC}"
        read -r line
        [ "$line" = "done" ] && break
        [ -z "$line" ] && continue
        query="$query $line"
    done

    [ -z "$query" ] && { echo -e "${YELLOW}No query entered.${NC}"; press_enter; return; }

    validate_sql_input "$query" || { press_enter; return; }

    echo ""
    echo -e "${SILVER}Running:${NC}"
    echo -e "${DIM}$query${NC}"
    echo ""

    local result=""

    case "$db_type" in
        sqlite)
            local db_file=$(grep "^file=" "$db_ref" | cut -d= -f2)
            result=$(sqlite3 -header -column "$db_file" "$query" 2>&1)
            ;;
        postgres)
            local container=$(grep "^container=" "$db_ref" | cut -d= -f2)
            local user=$(grep "^user=" "$db_ref" | cut -d= -f2)
            local name=$(grep "^name=" "$db_ref" | cut -d= -f2)
            result=$(docker exec "$container" psql -U "$user" -d "$name" -c "$query" 2>&1)
            ;;
        supabase)
            result=$(curl -s "$SUPABASE_URL/rest/v1/rpc/exec_sql" \
                -H "apikey: $SUPABASE_ANON_KEY" \
                -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
                -H "Content-Type: application/json" \
                -d "{\"query\": \"$query\"}" 2>&1)
            ;;
    esac

    echo -e "${GREEN}Result:${NC}"
    echo "$result"
    echo ""

    # Save to analysis_results
    echo -e "${DIM}  Saving query to history...${NC}"
    case "$db_type" in
        sqlite)
            local db_file=$(grep "^file=" "$db_ref" | cut -d= -f2)
            sqlite3 "$db_file" "INSERT INTO analysis_results (query, result) VALUES ('$query', '$(echo "$result" | head -20)');"
            ;;
    esac

    echo ""
    echo -e "  ${BOLD}[1]${NC}  Run another query"
    echo -e "  ${BOLD}[2]${NC}  Ask AI about this result"
    echo -e "  ${BOLD}[3]${NC}  Save this query"
    echo -e "  ${BOLD}[4]${NC}  Export result to CSV"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1) data_run_query "$db_ref" ;;
        2) data_ai_about_result "$result" "$db_ref" ;;
        3) data_save_query "$query" ;;
        4) data_export_result "$result" ;;
        0) return ;;
    esac
}

data_ai_about_result() {
    local result="$1"
    local db_ref="$2"

    echo ""
    local question=$(prompt_value "  Ask about this data")
    [ -z "$question" ] && return

    echo ""
    echo -e "${YELLOW}Analyzing with AI...${NC}"

    # Check for AI API key
    local api_key=""
    local api_url=""
    local model=""

    if [ -f "$DATA_DIR/ai-openai.conf" ]; then
        source "$DATA_DIR/ai-openai.conf"
        api_key="$API_KEY"
        api_url="https://api.openai.com/v1/chat/completions"
        model="gpt-4"
    elif [ -f "$DATA_DIR/ai-groq.conf" ]; then
        source "$DATA_DIR/ai-groq.conf"
        api_key="$API_KEY"
        api_url="https://api.groq.com/openai/v1/chat/completions"
        model="llama-3.1-70b-versatile"
    elif command -v docker &>/dev/null && docker ps --format '{{.Names}}' 2>/dev/null | grep -q "ollama"; then
        api_url="http://localhost:11434/api/generate"
        model="llama2"
    fi

    if [ -z "$api_url" ]; then
        echo -e "${RED}No AI provider configured.${NC}"
        echo -e "  ${DIM}Go to [5] AI Toolkit → [2] API Connectors to set up.${NC}"
        echo -e "  ${DIM}Or install Ollama for local AI.${NC}"
        press_enter; return
    fi

    local prompt="You are a data analyst. Here is the SQL query result:\n\n$result\n\nQuestion: $question\n\nProvide a clear, concise analysis. If appropriate, suggest follow-up queries."

    local response=""

    if [ -n "$api_key" ]; then
        response=$(curl -s "$api_url" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $api_key" \
            -d "{
                \"model\": \"$model\",
                \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
                \"temperature\": 0.3
            }" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'])" 2>/dev/null)
    else
        response=$(curl -s "$api_url" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"$model\",
                \"prompt\": \"$prompt\",
                \"stream\": false
            }" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])" 2>/dev/null)
    fi

    if [ -n "$response" ]; then
        echo ""
        echo -e "${GREEN}AI Analysis:${NC}"
        echo -e "$response"
        echo ""

        # Store the insight
        case "$db_ref" in
            *.meta)
                local db_type=$(grep "^type=" "$db_ref" | cut -d= -f2)
                if [ "$db_type" = "sqlite" ]; then
                    local db_file=$(grep "^file=" "$db_ref" | cut -d= -f2)
                    sqlite3 "$db_file" "INSERT INTO analysis_results (query, ai_insight) VALUES ('AI analysis of result', '$(echo "$response" | sed "s/'/''/g")');"
                fi
                ;;
        esac

        echo -e "${DIM}  Insight saved to database.${NC}"
    else
        echo -e "${RED}AI request failed. Check your API connection.${NC}"
    fi

    press_enter
}

data_nl2sql() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Natural Language → SQL ═══${NC}"
    echo ""
    echo -e "  ${DIM}Describe what you want in plain English.${NC}"
    echo -e "  ${DIM}AI will convert it to SQL for you.${NC}"
    echo ""

    # List databases
    local databases=()
    local i=1
    for meta_file in "$DATA_WORKSPACE/databases"/*.meta; do
        [ -f "$meta_file" ] || continue
        local name=$(grep "^name=" "$meta_file" | cut -d= -f2)
        databases+=("$meta_file")
        echo -e "  ${BOLD}[$i]${NC}  $name"
        ((i++))
    done

    if [ ${#databases[@]} -eq 0 ]; then
        echo -e "  ${DIM}No databases. Create one first.${NC}"
        press_enter; return
    fi

    echo ""
    read -p "  Select database: " choice
    [ "$choice" = "0" ] || [ -z "$choice" ] && return

    local selected="${databases[$((choice-1))]}"
    local db_name=$(grep "^name=" "$selected" | cut -d= -f2)

    echo ""
    local question=$(prompt_value "  What do you want to query? (e.g. 'Show me all users who signed up this week')")

    echo -e "${YELLOW}  Generating SQL...${NC}"

    # Check for AI
    local api_key=""
    local api_url=""
    local model=""

    if [ -f "$DATA_DIR/ai-openai.conf" ]; then
        source "$DATA_DIR/ai-openai.conf"
        api_key="$API_KEY"
        api_url="https://api.openai.com/v1/chat/completions"
        model="gpt-4"
    elif [ -f "$DATA_DIR/ai-groq.conf" ]; then
        source "$DATA_DIR/ai-groq.conf"
        api_key="$API_KEY"
        api_url="https://api.groq.com/openai/v1/chat/completions"
        model="llama-3.1-70b-versatile"
    elif command -v docker &>/dev/null && docker ps --format '{{.Names}}' 2>/dev/null | grep -q "ollama"; then
        api_url="http://localhost:11434/api/generate"
        model="llama2"
    fi

    if [ -z "$api_url" ]; then
        echo -e "${RED}No AI provider configured.${NC}"
        press_enter; return
    fi

    local prompt="Convert this natural language request to SQL. Only return the SQL query, no explanation. Database: $db_name.\n\nRequest: $question"

    local sql=""
    if [ -n "$api_key" ]; then
        sql=$(curl -s "$api_url" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $api_key" \
            -d "{
                \"model\": \"$model\",
                \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
                \"temperature\": 0.1
            }" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'])" 2>/dev/null)
    else
        sql=$(curl -s "$api_url" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"$model\",
                \"prompt\": \"$prompt\",
                \"stream\": false
            }" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])" 2>/dev/null)
    fi

    # Clean up SQL (remove markdown code blocks)
    sql=$(echo "$sql" | sed 's/```sql//g' | sed 's/```//g' | sed 's/^ *//')

    echo ""
    echo -e "${GREEN}Generated SQL:${NC}"
    echo -e "${BOLD}$sql${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  Run this query"
    echo -e "  ${BOLD}[2]${NC}  Edit and run"
    echo -e "  ${BOLD}[3]${NC}  Save for later"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1)
            # Run directly
            local result=""
            local db_type=$(grep "^type=" "$selected" | cut -d= -f2)
            case "$db_type" in
                sqlite)
                    local db_file=$(grep "^file=" "$selected" | cut -d= -f2)
                    result=$(sqlite3 -header -column "$db_file" "$sql" 2>&1)
                    ;;
                postgres)
                    local container=$(grep "^container=" "$selected" | cut -d= -f2)
                    local user=$(grep "^user=" "$selected" | cut -d= -f2)
                    local name=$(grep "^name=" "$selected" | cut -d= -f2)
                    result=$(docker exec "$container" psql -U "$user" -d "$name" -c "$sql" 2>&1)
                    ;;
            esac
            echo ""
            echo -e "${GREEN}Result:${NC}"
            echo "$result"
            press_enter
            ;;
        2)
            echo ""
            echo -e "${DIM}Edit the SQL below (or press Enter to keep):${NC}"
            echo -e "${BOLD}$sql${NC}"
            local new_sql=$(prompt_value "  SQL" "$sql")
            data_run_query "$selected"
            ;;
        3) data_save_query "$sql" ;;
        0) return ;;
    esac
}

data_save_query() {
    local query="$1"
    local name=$(prompt_value "  Query name")
    local desc=$(prompt_value "  Description (optional)")
    [ -z "$name" ] && return

    local saved_file="$DATA_WORKSPACE/queries/$name.sql"
    echo "$query" > "$saved_file"

    echo -e "${GREEN}Query saved: $name${NC}"
    press_enter
}

data_saved_queries() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Saved Queries ═══${NC}"
    echo ""

    local queries=()
    local i=1
    for q_file in "$DATA_WORKSPACE/queries"/*.sql; do
        [ -f "$q_file" ] || continue
        local name=$(basename "$q_file" .sql)
        local preview=$(head -1 "$q_file" | cut -c1-60)
        queries+=("$q_file")
        echo -e "  ${BOLD}[$i]${NC}  ${GREEN}$name${NC}"
        echo -e "        ${DIM}$preview${NC}"
        ((i++))
    done

    if [ ${#queries[@]} -eq 0 ]; then
        echo -e "  ${DIM}No saved queries yet.${NC}"
        press_enter; return
    fi

    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select query: " choice

    if [ "$choice" = "0" ] || [ -z "$choice" ]; then return; fi
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#queries[@]}" ]; then
        local selected="${queries[$((choice-1))]}"
        echo ""
        echo -e "${SILVER}Query:${NC}"
        cat "$selected"
        echo ""
        echo -e "  ${BOLD}[1]${NC}  Run this query"
        echo -e "  ${BOLD}[2]${NC}  Delete"
        echo -e "  ${BOLD}[0]${NC}  Back"
        echo ""
        read -p "  Select: " choice
        case $choice in
            1) data_query ;;
            2) rm "$selected" && echo -e "${GREEN}Deleted.${NC}"; press_enter ;;
        esac
    fi
}

data_import() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Import Data ═══${NC}"
    echo ""
    echo -e "  ${BOLD}[1]${NC}  ${GREEN}CSV file${NC}"
    echo -e "  ${BOLD}[2]${NC}  ${GREEN}JSON file${NC}"
    echo -e "  ${BOLD}[3]${NC}  ${GREEN}SQL dump${NC}"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select format: " choice
    case $choice in
        1) data_import_csv ;;
        2) data_import_json ;;
        3) data_import_sql ;;
        0) return ;;
    esac
}

data_import_csv() {
    echo ""
    local file=$(prompt_value "  CSV file path")
    [ -z "$file" ] || [ ! -f "$file" ] && { echo -e "${RED}File not found.${NC}"; press_enter; return; }

    local table=$(prompt_value "  Table name")
    [ -z "$table" ] && return

    # Choose database
    local databases=()
    local i=1
    for meta_file in "$DATA_WORKSPACE/databases"/*.meta; do
        [ -f "$meta_file" ] || continue
        local name=$(grep "^name=" "$meta_file" | cut -d= -f2)
        databases+=("$meta_file")
        echo -e "  ${BOLD}[$i]${NC}  $name"
        ((i++))
    done

    [ ${#databases[@]} -eq 0 ] && { echo -e "${RED}No databases.${NC}"; press_enter; return; }

    read -p "  Select database: " db_choice
    local selected="${databases[$((db_choice-1))]}"
    local db_type=$(grep "^type=" "$selected" | cut -d= -f2)

    echo -e "${YELLOW}Importing $file into $table...${NC}"

    case "$db_type" in
        sqlite)
            local db_file=$(grep "^file=" "$selected" | cut -d= -f2)
            # Create table from CSV header
            local header=$(head -1 "$file" | tr ',' '\n' | sed 's/^/"/;s/$/"/' | paste -sd ',' -)
            local cols=$(head -1 "$file" | sed 's/ /_/g')

            # Import using CSV mode
            sqlite3 "$db_file" << SQL
.mode csv
.import "$file" "$table"
SQL
            local rows=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM $table;")
            echo -e "${GREEN}Imported $rows rows into $table.${NC}"
            ;;
        postgres)
            local container=$(grep "^container=" "$selected" | cut -d= -f2)
            local user=$(grep "^user=" "$selected" | cut -d= -f2)
            local name=$(grep "^name=" "$selected" | cut -d= -f2)

            docker cp "$file" "$container:/tmp/import.csv"
            docker exec "$container" psql -U "$user" -d "$name" -c "\copy $table FROM '/tmp/import.csv' WITH CSV HEADER;"
            echo -e "${GREEN}Imported into $table.${NC}"
            ;;
    esac

    press_enter
}

data_import_json() {
    echo ""
    local file=$(prompt_value "  JSON file path")
    [ -z "$file" ] || [ ! -f "$file" ] && { echo -e "${RED}File not found.${NC}"; press_enter; return; }

    local table=$(prompt_value "  Table name")
    [ -z "$table" ] && return

    local databases=()
    local i=1
    for meta_file in "$DATA_WORKSPACE/databases"/*.meta; do
        [ -f "$meta_file" ] || continue
        local name=$(grep "^name=" "$meta_file" | cut -d= -f2)
        databases+=("$meta_file")
        echo -e "  ${BOLD}[$i]${NC}  $name"
        ((i++))
    done

    [ ${#databases[@]} -eq 0 ] && { echo -e "${RED}No databases.${NC}"; press_enter; return; }

    read -p "  Select database: " db_choice
    local selected="${databases[$((db_choice-1))]}"
    local db_type=$(grep "^type=" "$selected" | cut -d= -f2)

    echo -e "${YELLOW}Importing $file...${NC}"

    case "$db_type" in
        sqlite)
            local db_file=$(grep "^file=" "$selected" | cut -d= -f2)
            # Create table and insert JSON
            sqlite3 "$db_file" "CREATE TABLE IF NOT EXISTS $table (id INTEGER PRIMARY KEY AUTOINCREMENT, data TEXT);"
            local json_data=$(cat "$file")
            sqlite3 "$db_file" "INSERT INTO $table (data) VALUES ('$json_data');"
            echo -e "${GREEN}Imported JSON data into $table.${NC}"
            ;;
        postgres)
            local container=$(grep "^container=" "$selected" | cut -d= -f2)
            local user=$(grep "^user=" "$selected" | cut -d= -f2)
            local name=$(grep "^name=" "$selected" | cut -d= -f2)
            local json_data=$(cat "$file")

            docker exec "$container" psql -U "$user" -d "$name" -c "CREATE TABLE IF NOT EXISTS $table (id SERIAL PRIMARY KEY, data JSONB);"
            docker exec "$container" psql -U "$user" -d "$name" -c "INSERT INTO $table (data) VALUES ('$json_data'::jsonb);"
            echo -e "${GREEN}Imported JSON data into $table.${NC}"
            ;;
    esac

    press_enter
}

data_import_sql() {
    echo ""
    local file=$(prompt_value "  SQL file path")
    [ -z "$file" ] || [ ! -f "$file" ] && { echo -e "${RED}File not found.${NC}"; press_enter; return; }

    local databases=()
    local i=1
    for meta_file in "$DATA_WORKSPACE/databases"/*.meta; do
        [ -f "$meta_file" ] || continue
        local name=$(grep "^name=" "$meta_file" | cut -d= -f2)
        databases+=("$meta_file")
        echo -e "  ${BOLD}[$i]${NC}  $name"
        ((i++))
    done

    [ ${#databases[@]} -eq 0 ] && { echo -e "${RED}No databases.${NC}"; press_enter; return; }

    read -p "  Select database: " db_choice
    local selected="${databases[$((db_choice-1))]}"
    local db_type=$(grep "^type=" "$selected" | cut -d= -f2)

    case "$db_type" in
        sqlite)
            local db_file=$(grep "^file=" "$selected" | cut -d= -f2)
            sqlite3 "$db_file" < "$file"
            ;;
        postgres)
            local container=$(grep "^container=" "$selected" | cut -d= -f2)
            local user=$(grep "^user=" "$selected" | cut -d= -f2)
            local name=$(grep "^name=" "$selected" | cut -d= -f2)
            docker cp "$file" "$container:/tmp/import.sql"
            docker exec "$container" psql -U "$user" -d "$name" -f /tmp/import.sql
            ;;
    esac

    echo -e "${GREEN}SQL import complete.${NC}"
    press_enter
}

data_export() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Export Data ═══${NC}"
    echo ""

    # List databases
    local databases=()
    local i=1
    for meta_file in "$DATA_WORKSPACE/databases"/*.meta; do
        [ -f "$meta_file" ] || continue
        local name=$(grep "^name=" "$meta_file" | cut -d= -f2)
        databases+=("$meta_file")
        echo -e "  ${BOLD}[$i]${NC}  $name"
        ((i++))
    done

    [ ${#databases[@]} -eq 0 ] && { echo -e "${DIM}No databases.${NC}"; press_enter; return; }

    echo ""
    read -p "  Select database: " choice
    local selected="${databases[$((choice-1))]}"
    local db_type=$(grep "^type=" "$selected" | cut -d= -f2)
    local db_name=$(grep "^name=" "$selected" | cut -d= -f2)

    echo ""
    local table=$(prompt_value "  Table to export")
    [ -z "$table" ] && return

    local format=$(prompt_value "  Format (csv/json/sql)" "csv")
    local export_file="$DATA_WORKSPACE/exports/${db_name}_${table}_$(date +%Y%m%d_%H%M%S).$format"

    case "$db_type" in
        sqlite)
            local db_file=$(grep "^file=" "$selected" | cut -d= -f2)
            case "$format" in
                csv) sqlite3 -header -csv "$db_file" "SELECT * FROM $table;" > "$export_file" ;;
                json) sqlite3 -json "$db_file" "SELECT * FROM $table;" > "$export_file" ;;
                sql) sqlite3 "$db_file" ".dump $table" > "$export_file" ;;
            esac
            ;;
        postgres)
            local container=$(grep "^container=" "$selected" | cut -d= -f2)
            local user=$(grep "^user=" "$selected" | cut -d= -f2)
            local name=$(grep "^name=" "$selected" | cut -d= -f2)
            case "$format" in
                csv) docker exec "$container" psql -U "$user" -d "$name" -c "\copy $table TO '/tmp/export.csv' WITH CSV HEADER"; docker cp "$container:/tmp/export.csv" "$export_file" ;;
                json) docker exec "$container" psql -U "$user" -d "$name" -t -A -c "SELECT row_to_json(t) FROM $table t;" > "$export_file" ;;
                sql) docker exec "$container" pg_dump -U "$user" -d "$name" -t "$table" > "$export_file" ;;
            esac
            ;;
    esac

    echo -e "${GREEN}Exported to: $export_file${NC}"
    press_enter
}

data_export_result() {
    local result="$1"
    local export_file="$DATA_WORKSPACE/exports/query_$(date +%Y%m%d_%H%M%S).txt"
    echo "$result" > "$export_file"
    echo -e "${GREEN}Exported to: $export_file${NC}"
    press_enter
}

data_visualize() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ Data Visualization ═══${NC}"
    echo ""
    echo -e "  ${DIM}Generate charts from your data.${NC}"
    echo ""

    # List databases
    local databases=()
    local i=1
    for meta_file in "$DATA_WORKSPACE/databases"/*.meta; do
        [ -f "$meta_file" ] || continue
        local name=$(grep "^name=" "$meta_file" | cut -d= -f2)
        databases+=("$meta_file")
        echo -e "  ${BOLD}[$i]${NC}  $name"
        ((i++))
    done

    [ ${#databases[@]} -eq 0 ] && { echo -e "${DIM}No databases.${NC}"; press_enter; return; }

    echo ""
    read -p "  Select database: " choice
    local selected="${databases[$((choice-1))]}"
    local db_type=$(grep "^type=" "$selected" | cut -d= -f2)
    local db_name=$(grep "^name=" "$selected" | cut -d= -f2)

    echo ""
    echo -e "  ${BOLD}[1]${NC}  Bar chart"
    echo -e "  ${BOLD}[2]${NC}  Line chart"
    echo -e "  ${BOLD}[3]${NC}  Pie chart"
    echo ""
    local chart_type=$(prompt_value "  Chart type" "1")
    local table=$(prompt_value "  Table name")
    local x_col=$(prompt_value "  X-axis column (labels)")
    local y_col=$(prompt_value "  Y-axis column (values)")

    # Generate HTML chart
    local query="SELECT $x_col, $y_col FROM $table"
    local result=""

    case "$db_type" in
        sqlite)
            local db_file=$(grep "^file=" "$selected" | cut -d= -f2)
            result=$(sqlite3 -json "$db_file" "$query" 2>/dev/null)
            ;;
        postgres)
            local container=$(grep "^container=" "$selected" | cut -d= -f2)
            local user=$(grep "^user=" "$selected" | cut -d= -f2)
            local name=$(grep "^name=" "$selected" | cut -d= -f2)
            result=$(docker exec "$container" psql -U "$user" -d "$name" -t -A -c "SELECT row_to_json(t) FROM ($query) t;" 2>/dev/null)
            ;;
    esac

    # Create HTML with Chart.js
    local chart_file="$DATA_WORKSPACE/exports/chart_$(date +%Y%m%d_%H%M%S).html"
    cat > "$chart_file" << HTMLEOF
<!DOCTYPE html>
<html>
<head>
    <title>Data Chart - $db_name</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: sans-serif; background: #0a0a0a; color: #fff; padding: 20px; }
        canvas { max-width: 800px; margin: 20px auto; }
        h1 { color: #00d4aa; text-align: center; }
    </style>
</head>
<body>
    <h1>$db_name - $table</h1>
    <canvas id="chart"></canvas>
    <script>
        const data = $result;
        const labels = data.map(d => d.$x_col);
        const values = data.map(d => d.$y_col);
        new Chart(document.getElementById('chart'), {
            type: '$([ "bar", "line", "pie" ][$chart_type - 1])',
            data: {
                labels: labels,
                datasets: [{
                    label: '$y_col',
                    data: values,
                    backgroundColor: 'rgba(0, 212, 170, 0.5)',
                    borderColor: '#00d4aa',
                    borderWidth: 1
                }]
            },
            options: {
                scales: { y: { beginAtZero: true } },
                plugins: { legend: { labels: { color: '#fff' } } }
            }
        });
    </script>
</body>
</html>
HTMLEOF

    echo -e "${GREEN}Chart created: $chart_file${NC}"

    if command -v xdg-open &>/dev/null; then xdg-open "$chart_file" 2>/dev/null &
    elif command -v chromium-browser &>/dev/null; then chromium-browser "$chart_file" 2>/dev/null &
    fi

    press_enter
}

data_ai_analysis() {
    clear 2>/dev/null || true
    echo -e "${SILVER}${BOLD}  ═══ AI Data Analysis ═══${NC}"
    echo ""
    echo -e "  ${DIM}Ask questions about your data in plain English.${NC}"
    echo ""

    # Check for AI
    local has_ai=false
    if [ -f "$DATA_DIR/ai-openai.conf" ] || [ -f "$DATA_DIR/ai-groq.conf" ]; then
        has_ai=true
    elif command -v docker &>/dev/null && docker ps --format '{{.Names}}' 2>/dev/null | grep -q "ollama"; then
        has_ai=true
    fi

    if ! $has_ai; then
        echo -e "${YELLOW}No AI provider configured.${NC}"
        echo -e "  ${DIM}Set up AI first: [5] AI Toolkit → [2] API Connectors${NC}"
        echo -e "  ${DIM}Or install Ollama for local AI.${NC}"
        press_enter; return
    fi

    # Show recent analysis results
    echo -e "${SILVER}Recent analyses:${NC}"
    for meta_file in "$DATA_WORKSPACE/databases"/*.meta; do
        [ -f "$meta_file" ] || continue
        local db_type=$(grep "^type=" "$meta_file" | cut -d= -f2)
        if [ "$db_type" = "sqlite" ]; then
            local db_file=$(grep "^file=" "$meta_file" | cut -d= -f2)
            sqlite3 "$db_file" "SELECT '  ' || created_at || ': ' || substr(ai_insight, 1, 60) || '...' FROM analysis_results WHERE ai_insight IS NOT NULL ORDER BY created_at DESC LIMIT 5;" 2>/dev/null
        fi
    done
    echo ""

    echo -e "  ${BOLD}[1]${NC}  New analysis"
    echo -e "  ${BOLD}[2]${NC}  View all insights"
    echo -e "  ${BOLD}[0]${NC}  Back"
    echo ""
    read -p "  Select: " choice
    case $choice in
        1)
            echo ""
            local question=$(prompt_value "  What do you want to know?")
            [ -z "$question" ] && return
            data_ai_about_result "No specific result. Question: $question" ""
            ;;
        2)
            echo ""
            for meta_file in "$DATA_WORKSPACE/databases"/*.meta; do
                [ -f "$meta_file" ] || continue
                local db_type=$(grep "^type=" "$meta_file" | cut -d= -f2)
                local name=$(grep "^name=" "$meta_file" | cut -d= -f2)
                if [ "$db_type" = "sqlite" ]; then
                    local db_file=$(grep "^file=" "$meta_file" | cut -d= -f2)
                    echo -e "${GREEN}$name:${NC}"
                    sqlite3 "$db_file" "SELECT '  [' || created_at || '] ' || ai_insight FROM analysis_results WHERE ai_insight IS NOT NULL ORDER BY created_at DESC;" 2>/dev/null
                    echo ""
                fi
            done
            press_enter
            ;;
        0) return ;;
    esac
}
