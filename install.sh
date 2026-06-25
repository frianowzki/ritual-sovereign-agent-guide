#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  ◆ Ritual Sovereign Agent — Interactive Installer
#
#  One-command setup for Sovereign Agents on Ritual Chain 1979.
#  Handles everything: system deps, project setup, config, deploy.
#
#  Works on: Linux (Ubuntu/Debian/Fedora/Arch), macOS (Intel/Apple Silicon)
#
#  Usage:
#    bash install.sh
#
#  One-liner:
#    curl -sSL https://raw.githubusercontent.com/frianowzki/ritual-sovereign-agent-guide/master/install.sh | bash
# ═══════════════════════════════════════════════════════════════

set -e

# ── Colors & Formatting ────────────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;91m'
    GREEN='\033[0;92m'
    YELLOW='\033[0;93m'
    BLUE='\033[0;94m'
    MAGENTA='\033[0;95m'
    CYAN='\033[0;96m'
    WHITE='\033[1;97m'
    DIM='\033[2m'
    BOLD='\033[1m'
    RESET='\033[0m'
    BG_BLACK='\033[40m'
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE=''
    DIM='' BOLD='' RESET='' BG_BLACK=''
fi

# ── Unicode Box Drawing ────────────────────────────────────
BOX_TL="╔" BOX_TR="╗" BOX_BL="╚" BOX_BR="╝"
BOX_H="═" BOX_V="║" BOX_ML="╠" BOX_MR="╣"
BOX_TT="╦" BOX_BT="╩" BOX_MH="─" BOX_MV="│"
DOT="●" ARROW="▸" CHECK="✓" CROSS="✗" WARN="⚠"
PROMPT="❯" STAR="◆" BULLET="•"

# ── Helpers ─────────────────────────────────────────────────
info()      { echo -e "  ${BLUE}${BULLET}${RESET}  $*"; }
success()   { echo -e "  ${GREEN}${CHECK}${RESET}  $*"; }
warn()      { echo -e "  ${YELLOW}${WARN}${RESET}  $*"; }
error()     { echo -e "  ${RED}${CROSS}${RESET}  $*"; }
step()      { echo -e "\n${CYAN}${BOLD}  ${STAR} $1${RESET}"; }
divider()   { echo -e "  ${DIM}$(printf '%.0s─' {1..58})${RESET}"; }
blank()     { echo ""; }

box() {
    local title="$1"
    local len=${#title}
    local pad=$((56 - len))
    echo -e "${MAGENTA}${BOLD}"
    echo "  ${BOX_TL}$(printf '%.0s${BOX_H}' {1..56})${BOX_TR}"
    echo "  ${BOX_V}  ${title}$(printf '%.0s ' {1..$((pad - 2))})${BOX_V}"
    echo "  ${BOX_BL}$(printf '%.0s${BOX_H}' {1..56})${BOX_BR}"
    echo -e "${RESET}"
}

subbox() {
    local title="$1"
    echo -e "  ${DIM}${BOX_ML}$(printf '%.0s${BOX_H}' {1..56})${BOX_MR}${RESET}"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BOLD}${title}${RESET}"
    echo -e "  ${DIM}${BOX_ML}$(printf '%.0s${BOX_H}' {1..56})${BOX_MR}${RESET}"
}

progress() {
    local current=$1 total=$2 label="$3"
    local pct=$((current * 100 / total))
    local filled=$((pct / 2))
    local empty=$((50 - filled))
    echo -ne "  ${CYAN}[${RESET}"
    echo -ne "${GREEN}$(printf '%.0s█' {1..$filled})${RESET}"
    echo -ne "${DIM}$(printf '%.0s░' {1..$empty})${RESET}"
    echo -e "${CYAN}]${RESET} ${WHITE}${pct}%${RESET} ${DIM}${label}${RESET}"
}

ask() {
    local prompt="$1" default="$2"
    if [ -n "$default" ]; then
        echo -ne "  ${CYAN}${PROMPT}${RESET}  ${prompt} ${DIM}[$default]${RESET}: "
    else
        echo -ne "  ${CYAN}${PROMPT}${RESET}  ${prompt}: "
    fi
    read -r REPLY
    echo "${REPLY:-$default}"
}

ask_secret() {
    local prompt="$1"
    echo -ne "  ${CYAN}${PROMPT}${RESET}  ${prompt} ${DIM}(hidden)${RESET}: "
    stty -echo 2>/dev/null || true
    read -r REPLY
    stty echo 2>/dev/null || true
    echo ""
    echo "$REPLY"
}

pick() {
    local title="$1"
    shift
    local items=("$@")
    local count=$(( ${#items[@]} / 2 ))

    echo -e "  ${WHITE}${title}${RESET}"
    blank

    for ((i=0; i<count; i++)); do
        local idx=$((i + 1))
        local name="${items[$((i * 2))]}"
        local desc="${items[$((i * 2 + 1))]}"
        if [ $idx -eq 1 ]; then
            echo -e "  ${GREEN}${ARROW}${RESET} ${BOLD}${idx}${RESET}. ${WHITE}${name}${RESET}"
        else
            echo -e "    ${BOLD}${idx}${RESET}. ${WHITE}${name}${RESET}"
        fi
        echo -e "       ${DIM}${desc}${RESET}"
    done

    blank
    echo -ne "  ${CYAN}${PROMPT}${RESET}  Select ${DIM}[1-${count}, default: 1]${RESET}: "
    read -r choice
    choice=${choice:-1}

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
        local selected_idx=$(( (choice - 1) * 2 ))
        local selected="${items[$selected_idx]}"
        success "Selected: ${WHITE}${selected}${RESET}"
        echo "$choice"
    else
        warn "Invalid choice, using default"
        echo "1"
    fi
}

banner() {
    echo -e "${MAGENTA}${BOLD}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════╗
    ║                                                          ║
    ║           ◆  RITUAL SOVEREIGN AGENT  ◆                  ║
    ║                                                          ║
    ║     Autonomous AI Agents on Ritual Chain (ID 1979)      ║
    ║                                                          ║
    ║  Factory Harness  •  TEE Execution  •  Async Callbacks  ║
    ║                                                          ║
    ║              Created by @frianowzki                      ║
    ║           github.com/frianowzki                          ║
    ║                                                          ║
    ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${RESET}"
    echo -e "  ${DIM}Deploy production-grade AI agents that run autonomously${RESET}"
    echo -e "  ${DIM}on-chain, execute in Trusted Execution Environments,${RESET}"
    echo -e "  ${DIM}and deliver results via async callbacks.${RESET}"
    blank
}

# ── Detect OS ───────────────────────────────────────────────
detect_os() {
    OS="$(uname -s)"
    ARCH="$(uname -m)"

    case "$OS" in
        Linux*)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO="$ID"
                DISTRO_NAME="$PRETTY_NAME"
            else
                DISTRO="unknown"
                DISTRO_NAME="Linux"
            fi
            ;;
        Darwin*)
            DISTRO="macos"
            if [[ "$ARCH" == "arm64" ]]; then
                DISTRO_NAME="macOS (Apple Silicon)"
            else
                DISTRO_NAME="macOS (Intel)"
            fi
            ;;
        *)
            DISTRO="unknown"
            DISTRO_NAME="$OS"
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
#  Step 1: System Check
# ═══════════════════════════════════════════════════════════════

step_system() {
    step "System Check"

    info "Platform: ${WHITE}${DISTRO_NAME}${RESET} (${ARCH})"
    progress 1 5 "Checking system"
    blank

    # Git
    if command -v git &>/dev/null; then
        success "Git ${DIM}$(git --version | cut -d' ' -f3)${RESET}"
    else
        warn "Git not found — will install"
        NEED_GIT=true
    fi

    # Python
    if command -v python3 &>/dev/null; then
        PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")')
        PY_MAJOR=$(python3 -c 'import sys; print(sys.version_info.major)')
        PY_MINOR=$(python3 -c 'import sys; print(sys.version_info.minor)')
        if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 10 ]; then
            success "Python ${WHITE}${PY_VER}${RESET}"
        else
            warn "Python ${PY_VER} found but 3.10+ required"
            NEED_PYTHON=true
        fi
    else
        warn "Python not found — will install"
        NEED_PYTHON=true
    fi

    # pip
    if python3 -m pip --version &>/dev/null 2>&1; then
        PIP_VER=$(python3 -m pip --version 2>/dev/null | cut -d' ' -f2)
        success "pip ${DIM}${PIP_VER}${RESET}"
    else
        warn "pip not found — will install"
        NEED_PIP=true
    fi

    # curl
    if command -v curl &>/dev/null; then
        success "curl available"
    else
        warn "curl not found — some features may not work"
    fi

    blank
    progress 2 5 "System check complete"
}

# ═══════════════════════════════════════════════════════════════
#  Step 2: Install Dependencies
# ═══════════════════════════════════════════════════════════════

step_install_deps() {
    step "Install Dependencies"
    progress 3 5 "Installing dependencies"

    # Install missing system deps
    if [ "$NEED_GIT" = true ] || [ "$NEED_PYTHON" = true ] || [ "$NEED_PIP" = true ]; then
        info "Installing system dependencies..."
        blank

        case "$DISTRO" in
            ubuntu|debian)
                info "Using ${WHITE}apt${RESET} package manager"
                sudo apt update -qq 2>/dev/null
                [ "$NEED_GIT" = true ] && sudo apt install -y -qq git 2>/dev/null && success "Git installed"
                [ "$NEED_PYTHON" = true ] && sudo apt install -y -qq python3 python3-venv 2>/dev/null && success "Python installed"
                [ "$NEED_PIP" = true ] && sudo apt install -y -qq python3-pip 2>/dev/null && success "pip installed"
                ;;
            fedora|rhel|centos)
                info "Using ${WHITE}dnf${RESET} package manager"
                [ "$NEED_GIT" = true ] && sudo dnf install -y -q git 2>/dev/null && success "Git installed"
                [ "$NEED_PYTHON" = true ] && sudo dnf install -y -q python3 python3-pip 2>/dev/null && success "Python installed"
                ;;
            arch|manjaro)
                info "Using ${WHITE}pacman${RESET} package manager"
                [ "$NEED_GIT" = true ] && sudo pacman -S --noconfirm --quiet git 2>/dev/null && success "Git installed"
                [ "$NEED_PYTHON" = true ] && sudo pacman -S --noconfirm --quiet python python-pip 2>/dev/null && success "Python installed"
                ;;
            macos)
                if command -v brew &>/dev/null; then
                    info "Using ${WHITE}Homebrew${RESET}"
                    [ "$NEED_GIT" = true ] && brew install git 2>/dev/null && success "Git installed"
                    [ "$NEED_PYTHON" = true ] && brew install python 2>/dev/null && success "Python installed"
                else
                    warn "Homebrew not found"
                    info "Install Homebrew first:"
                    echo -e "    ${CYAN}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${RESET}"
                    info "Then re-run this installer"
                    exit 1
                fi
                ;;
            *)
                error "Unknown distro. Please install manually:"
                echo -e "    ${DIM}• Git: https://git-scm.com${RESET}"
                echo -e "    ${DIM}• Python 3.10+: https://python.org${RESET}"
                exit 1
                ;;
        esac
    else
        success "All system dependencies already installed"
    fi

    blank

    # Clone project
    INSTALL_DIR="$HOME/ritual-sovereign-agent-guide"

    if [ -d "$INSTALL_DIR" ]; then
        warn "Project already exists at ${WHITE}~/ritual-sovereign-agent-guide${RESET}"
        blank
        local choice=$(pick "What to do?" \
            "Update and continue" "Pull latest changes and continue setup" \
            "Use existing" "Skip download, use current files" \
            "Delete and reclone" "Remove and download fresh copy")
        blank

        case "$choice" in
            1)
                cd "$INSTALL_DIR"
                git pull origin master 2>/dev/null || true
                success "Updated to latest"
                ;;
            2)
                cd "$INSTALL_DIR"
                success "Using existing files"
                ;;
            3)
                rm -rf "$INSTALL_DIR"
                git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git "$INSTALL_DIR" 2>/dev/null
                cd "$INSTALL_DIR"
                success "Fresh clone"
                ;;
        esac
    else
        info "Downloading project..."
        git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git "$INSTALL_DIR" 2>/dev/null
        cd "$INSTALL_DIR"
        success "Downloaded to ${WHITE}~/ritual-sovereign-agent-guide${RESET}"
    fi

    blank

    # Python deps
    info "Installing Python packages..."
    blank

    # Try venv first
    if python3 -m venv "$INSTALL_DIR/venv" 2>/dev/null; then
        source "$INSTALL_DIR/venv/bin/activate"
        success "Virtual environment: ${WHITE}$INSTALL_DIR/venv${RESET}"
        VENV_ACTIVE=true
    else
        warn "Could not create venv, using --user install"
        VENV_ACTIVE=false
    fi

    # Install packages with progress
    echo -ne "  ${DIM}  Installing web3...${RESET}\r"
    pip install web3 2>/dev/null && echo -e "  ${DIM}  Installing web3...${RESET}    ${GREEN}${CHECK}${RESET} web3"

    echo -ne "  ${DIM}  Installing eciespy...${RESET}\r"
    if pip install eciespy 2>/dev/null; then
        echo -e "  ${DIM}  Installing eciespy...${RESET}  ${GREEN}${CHECK}${RESET} eciespy"
    else
        echo ""
        warn "eciespy install failed"
        if [ "$DISTRO" = "macos" ]; then
            info "Try: ${CYAN}brew install rust${RESET} then re-run"
        fi
        info "Attempting alternative: pip install eciespy --no-build-isolation"
        pip install eciespy --no-build-isolation 2>/dev/null || {
            error "Could not install eciespy. Install Rust and try again:"
            echo -e "    ${CYAN}curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh${RESET}"
            echo -e "    ${CYAN}pip install eciespy${RESET}"
            exit 1
        }
    fi

    echo -ne "  ${DIM}  Installing eth-abi...${RESET}\r"
    pip install eth-abi 2>/dev/null && echo -e "  ${DIM}  Installing eth-abi...${RESET}   ${GREEN}${CHECK}${RESET} eth-abi"

    blank
    success "All Python dependencies installed"
    progress 4 5 "Dependencies ready"
}

# ═══════════════════════════════════════════════════════════════
#  Step 3: Blockchain Configuration
# ═══════════════════════════════════════════════════════════════

step_blockchain() {
    step "Blockchain Configuration"

    subbox "Ritual Chain Details"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BULLET} Chain ID:    ${WHITE}1979${RESET}"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BULLET} RPC:         ${WHITE}https://rpc.ritualfoundation.org${RESET}"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BULLET} Explorer:    ${WHITE}https://explorer.ritualfoundation.org${RESET}"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BULLET} Block time:  ${WHITE}~350ms${RESET}"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BULLET} Gas type:    ${WHITE}EIP-1559 (type 0x02)${RESET}"
    echo -e "  ${DIM}${BOX_BL}$(printf '%.0s${BOX_H}' {1..56})${BOX_BR}${RESET}"
    blank

    info "Your wallet's ${WHITE}private key${RESET} is needed to deploy contracts."
    warn "Stored locally in ${WHITE}.env${RESET} — ${RED}never shared or uploaded${RESET}"
    blank

    while true; do
        PRIVATE_KEY=$(ask_secret "Enter your private key (0x-prefixed)")
        if [[ "$PRIVATE_KEY" =~ ^0x[a-fA-F0-9]{64}$ ]]; then
            success "Valid private key format"
            # Try to derive address
            if command -v python3 &>/dev/null; then
                ADDR=$(python3 -c "
from eth_account import Account
a = Account.from_key('$PRIVATE_KEY')
print(a.address)
" 2>/dev/null || echo "")
                if [ -n "$ADDR" ]; then
                    success "Wallet: ${WHITE}${ADDR}${RESET}"
                fi
            fi
            break
        elif [ -z "$PRIVATE_KEY" ]; then
            error "Private key cannot be empty"
        else
            error "Invalid format. Must be 0x + 64 hex characters (66 total)"
        fi
    done

    blank
}

# ═══════════════════════════════════════════════════════════════
#  Step 4: LLM Provider & Model
# ═══════════════════════════════════════════════════════════════

step_llm() {
    step "LLM Provider"

    info "The LLM is the brain of your agent — it processes your prompt"
    info "and generates responses every time the agent wakes up."
    blank

    local provider_choice=$(pick "Select your LLM provider:" \
        "OpenRouter" "Cheapest option. Access to 100+ models from all providers. Recommended for beginners." \
        "OpenAI" "GPT-4o and GPT-4o-mini. Best for structured tasks and code generation." \
        "Anthropic" "Claude Sonnet 4.5 and Haiku 4.5. Best reasoning and analysis." \
        "Google Gemini" "Gemini 2.5 Flash/Pro. Free tier available, fast inference.")

    blank

    case "$provider_choice" in
        1)
            LLM_PROVIDER="openrouter"
            KEY_NAME="OPENROUTER_API_KEY"
            KEY_URL="https://openrouter.ai/keys"
            KEY_PREFIX="sk-or-v1-"
            DEFAULT_MODEL="google/gemini-2.5-flash"

            info "OpenRouter gives you access to models from ${WHITE}all providers${RESET}"
            info "through a single API key. Great for experimentation."
            blank

            local model_choice=$(pick "Select a model:" \
                "Gemini 2.5 Flash" "Fast, cheap (~\$0.01/run). Best value. Recommended." \
                "Gemini 2.5 Pro" "Best quality Google model. More expensive (~\$0.05/run)." \
                "Claude Sonnet 4.5 (via OR)" "Best reasoning model. ~\$0.03/run." \
                "GPT-4o Mini (via OR)" "Fast OpenAI model. ~\$0.01/run." \
                "Llama 4 Maverick" "Open source. FREE on OpenRouter." \
                "DeepSeek V3" "Open source. FREE on OpenRouter. Good quality.")

            case "$model_choice" in
                1) MODEL="google/gemini-2.5-flash" ;;
                2) MODEL="google/gemini-2.5-pro" ;;
                3) MODEL="anthropic/claude-sonnet-4-5-20250929" ;;
                4) MODEL="openai/gpt-4o-mini" ;;
                5) MODEL="meta-llama/llama-4-maverick" ;;
                6) MODEL="deepseek/deepseek-chat-v3-0324" ;;
            esac
            ;;
        2)
            LLM_PROVIDER="openai"
            KEY_NAME="OPENAI_API_KEY"
            KEY_URL="https://platform.openai.com/api-keys"
            KEY_PREFIX="sk-"
            DEFAULT_MODEL="gpt-4o-mini"

            local model_choice=$(pick "Select a model:" \
                "GPT-4o Mini" "Fast, cheap (\$0.15/M input). Recommended." \
                "GPT-4o" "Best quality OpenAI model (\$2.50/M input)." \
                "GPT-4.1 Mini" "Latest mini model, improved reasoning." \
                "o3-mini" "Reasoning model. Best for complex analysis.")

            case "$model_choice" in
                1) MODEL="gpt-4o-mini" ;;
                2) MODEL="gpt-4o" ;;
                3) MODEL="gpt-4.1-mini" ;;
                4) MODEL="o3-mini" ;;
            esac
            ;;
        3)
            LLM_PROVIDER="anthropic"
            KEY_NAME="ANTHROPIC_API_KEY"
            KEY_URL="https://console.anthropic.com/settings/keys"
            KEY_PREFIX="sk-ant-"
            DEFAULT_MODEL="claude-sonnet-4-5-20250929"

            local model_choice=$(pick "Select a model:" \
                "Claude Sonnet 4.5" "Best balance of speed, quality, and cost. Recommended." \
                "Claude Haiku 4.5" "Fastest, cheapest. Good for simple tasks." \
                "Claude Opus 4" "Best reasoning. Most expensive.")

            case "$model_choice" in
                1) MODEL="claude-sonnet-4-5-20250929" ;;
                2) MODEL="claude-haiku-4-5-20250929" ;;
                3) MODEL="claude-opus-4-20250514" ;;
            esac
            ;;
        4)
            LLM_PROVIDER="gemini"
            KEY_NAME="GEMINI_API_KEY"
            KEY_URL="https://aistudio.google.com/apikey"
            KEY_PREFIX=""
            DEFAULT_MODEL="gemini-2.5-flash"

            local model_choice=$(pick "Select a model:" \
                "Gemini 2.5 Flash" "Fast, free tier available. Recommended." \
                "Gemini 2.5 Pro" "Best quality, higher cost." \
                "Gemini 2.0 Flash" "Previous gen, very fast, very cheap.")

            case "$model_choice" in
                1) MODEL="gemini-2.5-flash" ;;
                2) MODEL="gemini-2.5-pro" ;;
                3) MODEL="gemini-2.0-flash" ;;
            esac
            ;;
    esac

    blank
    success "Provider: ${WHITE}${LLM_PROVIDER}${RESET}"
    success "Model: ${WHITE}${MODEL}${RESET}"
    blank

    # API Key
    divider
    info "Get your API key at: ${CYAN}${KEY_URL}${RESET}"
    info "The key is used to authenticate with the LLM provider."
    blank

    while true; do
        API_KEY=$(ask_secret "Enter ${KEY_NAME}")
        if [ -z "$API_KEY" ]; then
            error "API key cannot be empty"
        elif [ ${#API_KEY} -lt 8 ]; then
            error "API key seems too short (expected 20+ characters)"
        elif [ -n "$KEY_PREFIX" ] && [[ ! "$API_KEY" == ${KEY_PREFIX}* ]]; then
            warn "Key usually starts with '${KEY_PREFIX}' — continue anyway?"
            echo -ne "  ${CYAN}${PROMPT}${RESET}  ${DIM}[y/N]${RESET}: "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                success "API key saved"
                break
            fi
        else
            success "API key saved"
            break
        fi
    done

    blank
}

# ═══════════════════════════════════════════════════════════════
#  Step 5: HuggingFace Setup
# ═══════════════════════════════════════════════════════════════

step_huggingface() {
    step "HuggingFace Setup"

    info "HuggingFace stores your agent's ${WHITE}conversation history${RESET}"
    info "and ${WHITE}artifacts${RESET} (outputs, logs, etc.)."
    blank

    subbox "Setup Guide"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BOLD}1.${RESET} Go to ${CYAN}https://huggingface.co${RESET} and sign up (free)"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BOLD}2.${RESET} Go to ${CYAN}Settings > Access Tokens${RESET}"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BOLD}3.${RESET} Click ${WHITE}New token${RESET} → select ${WHITE}Write${RESET} access"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BOLD}4.${RESET} Copy the token (starts with ${WHITE}hf_${RESET})"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BOLD}5.${RESET} Go to ${CYAN}New Dataset${RESET} → create one (e.g., ${WHITE}yourname/agent-data${RESET})"
    echo -e "  ${DIM}${BOX_BL}$(printf '%.0s${BOX_H}' {1..56})${BOX_BR}${RESET}"
    blank

    # Token
    while true; do
        HF_TOKEN=$(ask_secret "HuggingFace token (hf_...)")
        if [[ "$HF_TOKEN" =~ ^hf_ ]]; then
            success "Token saved"
            break
        elif [ -z "$HF_TOKEN" ]; then
            error "Token cannot be empty"
        else
            error "Token should start with 'hf_'"
        fi
    done

    blank

    # Dataset
    info "Dataset format: ${WHITE}username/repo-name${RESET}"
    info "Example: ${WHITE}myname/sovereign-agent-data${RESET}"
    blank

    while true; do
        HF_REPO=$(ask "HuggingFace dataset ID")
        if [[ "$HF_REPO" == *"/"* ]] && [ ${#HF_REPO} -gt 3 ]; then
            success "Dataset: ${WHITE}${HF_REPO}${RESET}"
            break
        elif [ -z "$HF_REPO" ]; then
            error "Dataset ID cannot be empty"
        else
            error "Must be in format: username/repo-name"
        fi
    done

    blank
}

# ═══════════════════════════════════════════════════════════════
#  Step 6: Agent Prompt
# ═══════════════════════════════════════════════════════════════

step_prompt() {
    step "Agent Prompt"

    info "The prompt defines ${WHITE}what your agent does${RESET} every time it wakes up."
    info "You can change it later with ${WHITE}reconfigure.py${RESET}."
    blank

    local prompt_choice=$(pick "Select a prompt template:" \
        "Default Analytics" "DeFi market analysis. Checks prices, trends, on-chain activity. Good starting point." \
        "Market Monitor" "Price tracking with buy/sell signals. Focused on trading opportunities." \
        "Research Agent" "Web research and news summarization. Great for staying informed." \
        "On-Chain Watcher" "Monitors Ritual Chain transactions. Alerts on unusual activity." \
        "Custom" "Write your own prompt from scratch. Full control over agent behavior.")

    blank

    case "$prompt_choice" in
        1)
            AGENT_PROMPT="You are a sovereign AI agent on Ritual Chain. Your task is to analyze on-chain data and provide actionable insights for DeFi builders.

Instructions:
1. Check the current RITUAL token price and market conditions
2. Analyze recent transactions on the Ritual Chain explorer
3. Identify any unusual activity or trending patterns
4. Provide a brief market summary with key takeaways

Format your response as a concise report with:
- Market snapshot (price, volume, trends)
- Notable on-chain activity
- Builder insights (opportunities, risks)
- One actionable recommendation

Be concise. Focus on signal over noise."
            success "Template: ${WHITE}Default Analytics${RESET}"
            ;;
        2)
            AGENT_PROMPT="You are a market monitoring agent on Ritual Chain. Your task is to track cryptocurrency prices and identify trading opportunities.

Instructions:
1. Fetch current prices for top 20 altcoins from CoinGecko
2. Calculate 24h and 7d price changes
3. Identify the top 3 biggest movers (up and down)
4. Check for unusual volume spikes
5. Monitor RITUAL token specifically

Return a structured report:
- Top losers (with percentage drop)
- Top gainers (with percentage rise)
- Volume anomalies
- Trading signals (if any)
- Market sentiment (bullish/bearish/neutral)

Be data-driven. No speculation without evidence."
            success "Template: ${WHITE}Market Monitor${RESET}"
            ;;
        3)
            AGENT_PROMPT="You are a research agent on Ritual Chain. Your task is to gather and summarize information about blockchain and DeFi developments.

Instructions:
1. Search for recent news about blockchain technology and DeFi
2. Focus on developments relevant to Ritual Chain ecosystem
3. Identify new protocols, partnerships, or technical upgrades
4. Summarize key findings in a digestible format

Return a research brief:
- Top 3 news items of the day
- Technical developments to watch
- Ecosystem updates
- Quick takes (one-liners)

Focus on actionable intelligence. Quality over quantity."
            success "Template: ${WHITE}Research Agent${RESET}"
            ;;
        4)
            AGENT_PROMPT="You are an on-chain watcher on Ritual Chain. Your task is to monitor blockchain transactions and detect unusual activity.

Instructions:
1. Check recent blocks on Ritual Chain for notable transactions
2. Look for large transfers, contract deployments, or unusual patterns
3. Monitor known whale wallets for activity
4. Track gas prices and network congestion
5. Identify any potential security concerns

Return an alert report:
- Unusual transactions detected
- Large transfers (if any)
- New contract deployments
- Network health status
- Risk assessment

Alert level: Green (normal), Yellow (watch), Red (concerning)."
            success "Template: ${WHITE}On-Chain Watcher${RESET}"
            ;;
        5)
            info "Enter your custom prompt below."
            info "Be specific about what your agent should do."
            info "Press ${WHITE}Enter${RESET} when done."
            blank
            echo -ne "  ${DIM}  > ${RESET}"
            read -r AGENT_PROMPT
            if [ -z "$AGENT_PROMPT" ]; then
                warn "Empty prompt, using default template"
                AGENT_PROMPT=""
            else
                success "Custom prompt saved (${#AGENT_PROMPT} chars)"
            fi
            ;;
    esac

    # Show preview
    blank
    divider
    info "Prompt preview:"
    blank
    echo -e "  ${DIM}┌$(printf '%.0s─' {1..56})┐${RESET}"
    local line_count=0
    while IFS= read -r line; do
        if [ $line_count -lt 10 ]; then
            # Truncate long lines
            if [ ${#line} -gt 54 ]; then
                line="${line:0:51}..."
            fi
            printf "  ${DIM}│${RESET} %-54s ${DIM}│${RESET}\n" "$line"
            ((line_count++))
        fi
    done <<< "$AGENT_PROMPT"
    if [ $(echo "$AGENT_PROMPT" | wc -l) -gt 10 ]; then
        printf "  ${DIM}│${RESET} ${DIM}... ($((${#AGENT_PROMPT} - 10)) more lines)${RESET}%*s${DIM}│${RESET}\n" 36 ""
    fi
    echo -e "  ${DIM}└$(printf '%.0s─' {1..56})┘${RESET}"

    blank
}

# ═══════════════════════════════════════════════════════════════
#  Step 7: Deployment Configuration
# ═══════════════════════════════════════════════════════════════

step_config() {
    step "Deployment Configuration"

    # Salt
    info "A ${WHITE}unique salt${RESET} generates a deterministic harness address."
    info "Change this if deploying multiple agents."
    blank
    SALT=$(ask "Unique salt" "my-sovereign-agent")
    success "Salt: ${WHITE}${SALT}${RESET}"

    blank

    # CLI Type
    info "The ${WHITE}runtime type${RESET} determines which executor harness is used."
    blank
    local cli_choice=$(pick "Agent runtime:" \
        "Crush (CLI Type 5)" "Default runtime. Recommended for most use cases. Stable and well-tested." \
        "ZeroClaw (CLI Type 6)" "Alternative runtime. May have different capabilities. Experimental.")

    CLI_TYPE=$((cli_choice + 4))  # 5 or 6
    blank

    # Frequency
    info "How often your agent wakes up to execute its task."
    info "Lower frequency = more data, higher cost."
    blank

    local freq_choice=$(pick "Execution frequency:" \
        "~12 minutes (2000 blocks)" "Very frequent. Good for real-time monitoring. Higher gas cost." \
        "~29 minutes (5000 blocks)" "Balanced. Good for most monitoring tasks. Recommended." \
        "~58 minutes (10000 blocks)" "Hourly. Lower cost, good for periodic summaries." \
        "~2.9 hours (30000 blocks)" "Every few hours. Low cost, good for daily digests." \
        "~8.4 hours (86400 blocks)" "Twice daily. Lowest cost, good for daily reports.")

    case "$freq_choice" in
        1) FREQUENCY=2000 ;;
        2) FREQUENCY=5000 ;;
        3) FREQUENCY=10000 ;;
        4) FREQUENCY=30000 ;;
        5) FREQUENCY=86400 ;;
    esac

    FREQ_MIN=$(echo "scale=1; $FREQUENCY * 0.35 / 60" | bc 2>/dev/null || echo "?")
    blank
    success "Frequency: every ${WHITE}${FREQUENCY}${RESET} blocks (~${FREQ_MIN} min)"

    blank

    # Fund amount
    info "RITUAL to deposit into your harness's ${WHITE}RitualWallet${RESET}."
    info "This pays for on-chain gas (~0.002-0.005 RITUAL per heartbeat)."
    info "TEE execution cost is paid by the executor, ${GREEN}not you${RESET}."
    blank

    FUND_AMOUNT=$(ask "Fund amount (RITUAL)" "0.1")

    # Cost estimate
    HEARTBEATS=$(echo "$FUND_AMOUNT / 0.003" | bc 2>/dev/null | cut -d. -f1 || echo "?")
    DAYS=$(echo "$HEARTBEATS * $FREQUENCY * 0.35 / 86400" | bc 2>/dev/null | cut -d. -f1 || echo "?")

    blank
    subbox "Cost Estimate"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BULLET} Fund amount:     ${WHITE}${FUND_AMOUNT} RITUAL${RESET}"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BULLET} Est. heartbeats: ${WHITE}~${HEARTBEATS}${RESET}"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BULLET} Est. runtime:    ${WHITE}~${DAYS} days${RESET}"
    echo -e "  ${DIM}${BOX_V}${RESET}  ${BULLET} Per heartbeat:   ${WHITE}~0.003 RITUAL${RESET} (on-chain gas)"
    echo -e "  ${DIM}${BOX_BL}$(printf '%.0s${BOX_H}' {1..56})${BOX_BR}${RESET}"

    blank
}

# ═══════════════════════════════════════════════════════════════
#  Step 8: Generate .env
# ═══════════════════════════════════════════════════════════════

step_generate() {
    step "Generate Configuration"

    ENV_FILE="$INSTALL_DIR/.env"

    cat > "$ENV_FILE" << EOF
# ═══════════════════════════════════════════════════════════════
#  Ritual Sovereign Agent — Generated by install.sh
#  https://github.com/frianowzki/ritual-sovereign-agent-guide
# ═══════════════════════════════════════════════════════════════

# ── Blockchain ─────────────────────────────────────────────────
PRIVATE_KEY=$PRIVATE_KEY
RPC_URL=https://rpc.ritualfoundation.org

# ── LLM Provider ──────────────────────────────────────────────
LLM_PROVIDER=$LLM_PROVIDER
${KEY_NAME}=$API_KEY
MODEL=$MODEL

# ── HuggingFace ───────────────────────────────────────────────
HF_TOKEN=$HF_TOKEN
HF_REPO_ID=$HF_REPO

# ── Agent Prompt ──────────────────────────────────────────────
AGENT_PROMPT=$AGENT_PROMPT

# ── Deployment Config ─────────────────────────────────────────
SALT=$SALT
CLI_TYPE=$CLI_TYPE
FREQUENCY=$FREQUENCY
WINDOW_NUM_CALLS=5
ROLLOVER_THRESHOLD_BPS=5000
FUND_AMOUNT=$FUND_AMOUNT
EOF

    chmod 600 "$ENV_FILE"
    success "Configuration saved to ${WHITE}${ENV_FILE}${RESET}"
    success "File permissions: ${WHITE}600${RESET} (owner read/write only)"

    progress 5 5 "Configuration complete"
    blank
}

# ═══════════════════════════════════════════════════════════════
#  Step 9: Review & Deploy
# ═══════════════════════════════════════════════════════════════

step_review() {
    step "Review & Deploy"

    MASKED_KEY="${PRIVATE_KEY:0:6}...${PRIVATE_KEY: -4}"
    MASKED_API="${API_KEY:0:8}..."
    MASKED_HF="${HF_TOKEN:0:8}..."

    echo -e "  ${BOLD}${WHITE}Configuration Summary${RESET}"
    divider
    echo -e "  ${BULLET} Wallet:          ${WHITE}${MASKED_KEY}${RESET}"
    echo -e "  ${BULLET} Chain:           ${WHITE}Ritual Chain (ID 1979)${RESET}"
    echo -e "  ${BULLET} Chain Type:      ${WHITE}EIP-1559 (type 0x02)${RESET}"
    blank
    echo -e "  ${BULLET} LLM Provider:    ${WHITE}${LLM_PROVIDER}${RESET}"
    echo -e "  ${BULLET} API Key:         ${WHITE}${KEY_NAME}${RESET} (${DIM}${MASKED_API}${RESET})"
    echo -e "  ${BULLET} Model:           ${WHITE}${MODEL}${RESET}"
    blank
    echo -e "  ${BULLET} HuggingFace:     ${WHITE}${HF_REPO}${RESET}"
    echo -e "  ${BULLET} HF Token:        ${DIM}${MASKED_HF}${RESET}"
    blank
    echo -e "  ${BULLET} Salt:            ${WHITE}${SALT}${RESET}"
    echo -e "  ${BULLET} CLI Type:        ${WHITE}${CLI_TYPE}${RESET}"
    echo -e "  ${BULLET} Frequency:       ${WHITE}every ${FREQUENCY} blocks${RESET} (~${FREQ_MIN} min)"
    echo -e "  ${BULLET} Window Calls:    ${WHITE}5${RESET}"
    echo -e "  ${BULLET} Fund Amount:     ${WHITE}${FUND_AMOUNT} RITUAL${RESET}"
    blank
    echo -e "  ${BULLET} Est. Runtime:    ${GREEN}~${DAYS} days${RESET}"
    echo -e "  ${BULLET} Est. Heartbeats: ${GREEN}~${HEARTBEATS}${RESET}"
    divider
    blank

    local deploy_choice=$(pick "What would you like to do?" \
        "Deploy now" "Run the deployment script immediately. Agent goes live on-chain." \
        "Save config only" "Save .env file. Deploy later manually with: python3 scripts/deploy.py" \
        "Edit config" "Go back and modify settings before deploying.")

    blank

    case "$deploy_choice" in
        1)
            info "Starting deployment..."
            blank

            if [ "$VENV_ACTIVE" = true ]; then
                source "$INSTALL_DIR/venv/bin/activate" 2>/dev/null || true
            fi

            if python3 "$INSTALL_DIR/scripts/deploy.py"; then
                blank
                echo -e "${GREEN}${BOLD}"
                cat << 'EOF'
    ╔══════════════════════════════════════════════════════════╗
    ║                                                          ║
    ║           ◆  SOVEREIGN AGENT DEPLOYED!  ◆               ║
    ║                                                          ║
    ║     Your agent is now live on Ritual Chain 1979.         ║
    ║                                                          ║
    ║              Created by @frianowzki                      ║
    ║           github.com/frianowzki                          ║
    ║                                                          ║
    ╚══════════════════════════════════════════════════════════╝
EOF
                echo -e "${RESET}"
            else
                blank
                error "Deployment failed!"
                info "Check the error messages above and try again."
                info "Common issues: insufficient balance, gas too low, sender locked."
                info ""
                info "Try again with:"
                echo -e "    ${CYAN}cd ~/ritual-sovereign-agent-guide && python3 scripts/deploy.py${RESET}"
            fi
            ;;
        2)
            info "Configuration saved to ${WHITE}~/ritual-sovereign-agent-guide/.env${RESET}"
            blank
            info "Deploy later with:"
            echo -e "    ${CYAN}cd ~/ritual-sovereign-agent-guide${RESET}"
            echo -e "    ${CYAN}source venv/bin/activate${RESET}"
            echo -e "    ${CYAN}python3 scripts/deploy.py${RESET}"
            ;;
        3)
            info "Going back to edit config..."
            step_config
            step_generate
            step_review
            return
            ;;
    esac

    # Post-deploy commands
    blank
    info "Useful commands:"
    echo -e "    ${CYAN}cd ~/ritual-sovereign-agent-guide${RESET}"
    echo -e "    ${CYAN}python3 scripts/check-status.py --harness 0xYourAddr${RESET}   ${DIM}# Check status${RESET}"
    echo -e "    ${CYAN}python3 scripts/reconfigure.py --harness 0xYourAddr${RESET}   ${DIM}# Reconfigure${RESET}"
    echo -e "       ${DIM}--prompt \"New prompt\"${RESET}"
    echo -e "       ${DIM}--model gpt-4o${RESET}"
    echo -e "       ${DIM}--fund 0.05${RESET}"
    blank
    info "Explorer:  ${CYAN}https://explorer.ritualfoundation.org/agents?kind=sovereign${RESET}"
    info "Docs:      ${CYAN}https://github.com/frianowzki/ritual-sovereign-agent-guide${RESET}"
    blank
}

# ═══════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════

main() {
    clear 2>/dev/null || true
    banner

    info "Platform: ${WHITE}${DISTRO_NAME:-$(uname -s)}${RESET} ($(uname -m))"
    info "This installer will guide you through setting up a"
    info "Sovereign Agent on Ritual Chain step by step."
    blank
    info "You'll need:"
    echo -e "    ${DIM}${BULLET} A wallet private key with ≥ 0.2 RITUAL${RESET}"
    echo -e "    ${DIM}${BULLET} An LLM API key (OpenRouter, OpenAI, Anthropic, or Gemini)${RESET}"
    echo -e "    ${DIM}${BULLET} A HuggingFace account (free)${RESET}"
    blank

    echo -ne "  ${CYAN}${PROMPT}${RESET}  Ready to start? ${DIM}[Y/n]${RESET}: "
    read -r GO
    GO=${GO:-Y}
    if [[ ! "$GO" =~ ^[Yy]$ ]]; then
        info "Goodbye!"
        exit 0
    fi

    blank
    detect_os
    step_system
    step_install_deps
    step_blockchain
    step_llm
    step_huggingface
    step_prompt
    step_config
    step_generate
    step_review
}

main "$@"
