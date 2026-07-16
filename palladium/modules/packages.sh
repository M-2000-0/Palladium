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

    echo -e "${CYAN}  Installing $name...${NC}"
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
            echo -e "  ${CYAN}$3${NC}"
            return 1
            ;;
        macos)
            if command -v brew &> /dev/null; then
                brew install "$4" 2>&1 && return 0
            fi
            echo -e "  Install Homebrew first, then: ${CYAN}brew install $4${NC}"
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
