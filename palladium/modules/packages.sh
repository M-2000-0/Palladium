#!/bin/bash
# packages.sh - Cross-platform package detection and installation

detect_os() {
    local os=""
    if [ -n "$WINDIR" ] || [ -n "$SYSTEMROOT" ]; then
        os="windows"
    elif [ "$(uname)" = "Darwin" ]; then
        os="macos"
    else
        os="linux"
    fi
    echo "$os"
}

find_windows_exe() {
    local name="$1"
    local exe
    exe=$(command -v "$name" 2>/dev/null || true)
    if [ -n "$exe" ]; then
        echo "$exe"
        return 0
    fi
    for p in \
        "/c/Program Files/$name/$name.exe" \
        "/c/Program Files/$name/bin/$name.exe" \
        "/c/Program Files (x86)/$name/$name.exe" \
        "/c/Program Files (x86)/$name/bin/$name.exe" \
        "$LOCALAPPDATA/Programs/$name/$name.exe" \
        "$LOCALAPPDATA/Programs/$name/bin/$name.exe"; do
        if [ -f "$p" ]; then echo "$p"; return 0; fi
    done
    return 1
}

find_docker_cli() {
    local docker_cmd
    docker_cmd=$(command -v docker 2>/dev/null || true)
    if [ -n "$docker_cmd" ]; then
        echo "$docker_cmd"
        return 0
    fi
    for p in \
        "/c/Program Files/Docker/Docker/resources/bin/docker.exe" \
        "/c/Program Files/Docker/Docker/docker.exe" \
        "$LOCALAPPDATA/Docker/Programs/Docker Desktop/resources/bin/docker.exe"; do
        if [ -f "$p" ]; then echo "$p"; return 0; fi
    done
    return 1
}

palladium_install() {
    local name="$1"
    local os
    os=$(detect_os)

    echo -e "${SILVER}  Installing $name...${NC}"
    echo ""

    case "$os" in
        windows)
            if command -v winget &> /dev/null; then
                echo -e "  ${DIM}Using winget...${NC}"
                winget install --exact --id "$2" --silent --accept-package-agreements 2>&1 && return 0
                echo -e "  ${YELLOW}winget failed, trying direct...${NC}"
            fi
            if command -v choco &> /dev/null; then
                echo -e "  ${DIM}Using Chocolatey...${NC}"
                choco install "$name" -y 2>&1 && return 0
            fi
            echo -e "  Please install $name from:"
            echo -e "  ${SILVER}$3${NC}"
            return 1
            ;;
        macos)
            if command -v brew &> /dev/null; then
                brew install "$4" 2>&1 && return 0
            fi
            echo -e "  Install Homebrew first, then: ${SILVER}brew install $4${NC}"
            return 1
            ;;
        linux)
            if ! command -v sudo &> /dev/null && [ "$(id -u)" -ne 0 ]; then
                echo -e "${YELLOW}  sudo not available and not running as root.${NC}"
                echo -e "  Run as root or install sudo first."
                return 1
            fi
            local pkgs=("${@:4}")
            if command -v apt &> /dev/null; then
                sudo apt update -qq && sudo apt install -y -qq "${pkgs[@]}" 2>&1
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y "${pkgs[@]}" 2>&1
            elif command -v yum &> /dev/null; then
                sudo yum install -y "${pkgs[@]}" 2>&1
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm "${pkgs[@]}" 2>&1
            elif command -v zypper &> /dev/null; then
                sudo zypper install -y "${pkgs[@]}" 2>&1
            fi
            return $?
            ;;
    esac
}

install_tools() {
    local os
    os=$(detect_os)
    local all_ok=true

    echo -e "${SILVER}${BOLD}  ═══ Installing Essential Tools ═══${NC}"
    echo ""
    echo -e "  ${DIM}Palladium will install the following tools automatically:${NC}"
    echo ""
    echo -e "  ${GREEN}•${NC}  Git         ${DIM}Version control${NC}"
    echo -e "  ${GREEN}•${NC}  Docker      ${DIM}Container runtime${NC}"
    echo -e "  ${GREEN}•${NC}  curl        ${DIM}HTTP client${NC}"
    echo -e "  ${GREEN}•${NC}  wget        ${DIM}Download tool${NC}"
    echo -e "  ${GREEN}•${NC}  Python      ${DIM}Scripting & AI tools${NC}"
    echo -e "  ${GREEN}•${NC}  Node.js     ${DIM}JavaScript runtime${NC}"
    echo ""
    if ! confirm "  Proceed with installation?"; then
        echo -e "  ${YELLOW}Cancelled.${NC}"
        return 1
    fi
    echo ""

    case "$os" in
        windows)
            if ! command -v winget &> /dev/null; then
                echo -e "${YELLOW}  winget not available. Install from Microsoft Store first.${NC}"
                echo -e "  ${DIM}https://www.microsoft.com/p/app-installer/9nblggh4nns1${NC}"
                return 1
            fi

            echo -e "${SILVER}  Step 1/5: Installing Git...${NC}"
            winget install --exact --id Git.Git --silent --accept-package-agreements 2>&1 && \
                echo -e "${GREEN}  ✓ Git installed${NC}" || { echo -e "${RED}  ✗ Git failed${NC}"; all_ok=false; }

            echo ""
            echo -e "${SILVER}  Step 2/5: Installing Docker Desktop...${NC}"
            if find_docker_cli &> /dev/null; then
                echo -e "${GREEN}  ✓ Docker already installed${NC}"
            else
                winget install --exact --id Docker.DockerDesktop --silent --accept-package-agreements 2>&1 && \
                    echo -e "${GREEN}  ✓ Docker Desktop installed${NC}" || { echo -e "${RED}  ✗ Docker failed${NC}"; all_ok=false; }
            fi

            echo ""
            echo -e "${SILVER}  Step 3/5: Installing Python...${NC}"
            winget install --exact --id Python.Python.3.12 --silent --accept-package-agreements 2>&1 && \
                echo -e "${GREEN}  ✓ Python installed${NC}" || { echo -e "${RED}  ✗ Python failed${NC}"; all_ok=false; }

            echo ""
            echo -e "${SILVER}  Step 4/5: Installing Node.js...${NC}"
            winget install --exact --id OpenJS.NodeJS.LTS --silent --accept-package-agreements 2>&1 && \
                echo -e "${GREEN}  ✓ Node.js installed${NC}" || { echo -e "${RED}  ✗ Node.js failed${NC}"; all_ok=false; }

            echo ""
            echo -e "${SILVER}  Step 5/5: Installing VS Code...${NC}"
            winget install --exact --id Microsoft.VisualStudioCode --silent --accept-package-agreements 2>&1 && \
                echo -e "${GREEN}  ✓ VS Code installed${NC}" || { echo -e "${RED}  ✗ VS Code failed${NC}"; all_ok=false; }
            ;;

        macos)
            if ! command -v brew &> /dev/null; then
                echo -e "${YELLOW}  Installing Homebrew first...${NC}"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi

            echo -e "${SILVER}  Installing tools via Homebrew...${NC}"
            brew install git curl wget python node 2>&1 || all_ok=false
            brew install --cask docker visual-studio-code 2>&1 || all_ok=false
            ;;

        linux)
            local pm=""
            local update_cmd="" install_cmd=""
            if command -v apt &> /dev/null; then
                pm="apt"; update_cmd="sudo apt update -qq"; install_cmd="sudo apt install -y -qq"
            elif command -v dnf &> /dev/null; then
                pm="dnf"; update_cmd="sudo dnf check-update -q"; install_cmd="sudo dnf install -y"
            elif command -v yum &> /dev/null; then
                pm="yum"; update_cmd="sudo yum check-update -q"; install_cmd="sudo yum install -y"
            elif command -v pacman &> /dev/null; then
                pm="pacman"; update_cmd="sudo pacman -Sy"; install_cmd="sudo pacman -S --noconfirm"
            fi

            if [ -n "$pm" ]; then
                echo -e "${SILVER}  Updating package list...${NC}"
                eval "$update_cmd" 2>&1 || true
                echo ""
                echo -e "${SILVER}  Installing tools...${NC}"
                eval "$install_cmd git curl wget python3 python3-pip nodejs build-essential" 2>&1 || all_ok=false
            else
                echo -e "${RED}  No supported package manager found.${NC}"
                all_ok=false
            fi
            ;;
    esac

    echo ""
    if $all_ok; then
        echo -e "${GREEN}${BOLD}  All tools installed successfully!${NC}"
        echo -e "  ${DIM}Some tools may require a terminal restart.${NC}"
    else
        echo -e "${YELLOW}  Some tools failed. Check messages above.${NC}"
    fi
    press_enter
}
