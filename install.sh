#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  ◆ Ritual Sovereign Agent — Auto Installer
#
#  One-command setup for Sovereign Agents on Ritual Chain.
#  Works on: Linux (Ubuntu/Debian/Fedora/Arch), macOS (Intel/Apple Silicon)
#
#  Usage:
#    bash install.sh
#
#  Or one-liner:
#    curl -sSL https://raw.githubusercontent.com/frianowzki/ritual-sovereign-agent-guide/master/install.sh | bash
# ═══════════════════════════════════════════════════════════════

set -e

# ── Colors ──────────────────────────────────────────────────
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

# ── Helpers ─────────────────────────────────────────────────
info()    { echo -e "  ${BLUE}ℹ${RESET}  $*"; }
success() { echo -e "  ${GREEN}✔${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
error()   { echo -e "  ${RED}✘${RESET}  $*"; }
ask()     { echo -ne "  ${WHITE}?${RESET}  $*: "; read -r REPLY; echo "$REPLY"; }
ask_secret() {
    echo -ne "  ${WHITE}?${RESET}  $*: "
    stty -echo 2>/dev/null || true
    read -r REPLY
    stty echo 2>/dev/null || true
    echo ""
    echo "$REPLY"
}

banner() {
    echo -e "${MAGENTA}${BOLD}"
    echo '  ◆ ═══════════════════════════════════════════════════════ ◆'
    echo '  ║                                                       ║'
    echo '  ║        Ritual Sovereign Agent Installer v1.0.0        ║'
    echo '  ║                                                       ║'
    echo '  ║   Deploy autonomous AI agents on Ritual Chain 1979    ║'
    echo '  ║                                                       ║'
    echo '  ◆ ═══════════════════════════════════════════════════════ ◆'
    echo -e "${RESET}"
}

section() {
    echo ""
    echo -e "${CYAN}${BOLD}  ── $1 $(printf '─%.0s' {1..50})${RESET}"
    echo ""
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
            else
                DISTRO="unknown"
            fi
            ;;
        Darwin*)
            DISTRO="macos"
            ;;
        *)
            DISTRO="unknown"
            ;;
    esac
}

# ── Check & Install Dependencies ───────────────────────────
check_command() {
    command -v "$1" &>/dev/null
}

install_system_deps() {
    section "System Dependencies"

    # Git
    if check_command git; then
        success "Git: $(git --version | cut -d' ' -f3)"
    else
        info "Installing git..."
        case "$DISTRO" in
            ubuntu|debian) sudo apt update && sudo apt install -y git ;;
            fedora)        sudo dnf install -y git ;;
            arch)          sudo pacman -S --noconfirm git ;;
            macos)         brew install git ;;
            *)             error "Install git manually: https://git-scm.com"; exit 1 ;;
        esac
        success "Git installed"
    fi

    # Python 3.10+
    if check_command python3; then
        PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
        PY_MAJOR=$(echo "$PY_VER" | cut -d. -f1)
        PY_MINOR=$(echo "$PY_VER" | cut -d. -f2)
        if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 10 ]; then
            success "Python: $PY_VER"
        else
            warn "Python $PY_VER found but 3.10+ required"
            info "Installing Python 3.12..."
            case "$DISTRO" in
                ubuntu|debian) sudo apt update && sudo apt install -y python3 python3-pip python3-venv ;;
                fedora)        sudo dnf install -y python3 python3-pip ;;
                arch)          sudo pacman -S --noconfirm python python-pip ;;
                macos)         brew install python ;;
                *)             error "Install Python 3.10+ manually"; exit 1 ;;
            esac
            success "Python installed"
        fi
    else
        info "Installing Python 3..."
        case "$DISTRO" in
            ubuntu|debian) sudo apt update && sudo apt install -y python3 python3-pip python3-venv ;;
            fedora)        sudo dnf install -y python3 python3-pip ;;
            arch)          sudo pacman -S --noconfirm python python-pip ;;
            macos)         brew install python ;;
            *)             error "Install Python 3.10+ manually"; exit 1 ;;
        esac
        success "Python installed"
    fi

    # pip
    if python3 -m pip --version &>/dev/null; then
        success "pip: $(python3 -m pip --version | cut -d' ' -f2)"
    else
        info "Installing pip..."
        case "$DISTRO" in
            ubuntu|debian) sudo apt install -y python3-pip ;;
            fedora)        sudo dnf install -y python3-pip ;;
            *)             python3 -m ensurepip ;;
        esac
        success "pip installed"
    fi
}

# ── Clone & Setup Project ──────────────────────────────────
clone_repo() {
    section "Download Project"

    INSTALL_DIR="$HOME/ritual-sovereign-agent-guide"

    if [ -d "$INSTALL_DIR" ]; then
        warn "Directory already exists: $INSTALL_DIR"
        echo -ne "  ${WHITE}?${RESET}  Update and continue? ${DIM}[Y/n]${RESET}: "
        read -r CONFIRM
        CONFIRM=${CONFIRM:-Y}
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            cd "$INSTALL_DIR"
            git pull origin master 2>/dev/null || true
            success "Updated"
        else
            cd "$INSTALL_DIR"
            success "Using existing"
        fi
    else
        info "Cloning to $INSTALL_DIR..."
        git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        success "Cloned"
    fi
}

install_python_deps() {
    section "Python Dependencies"

    info "Installing: web3, eciespy, eth-abi"

    # Try venv first, fall back to --user
    if python3 -m venv "$INSTALL_DIR/venv" 2>/dev/null; then
        source "$INSTALL_DIR/venv/bin/activate"
        success "Virtual environment created"
        VENV_ACTIVE=true
    else
        warn "Could not create venv, installing with --user"
        VENV_ACTIVE=false
    fi

    pip install web3 eciespy eth-abi 2>&1 | tail -5
    success "Dependencies installed"
}

# ── Interactive Config ──────────────────────────────────────
setup_config() {
    section "Agent Configuration"

    # ── Private Key ──
    info "Your wallet private key (0x-prefixed hex)"
    warn "This is stored locally in .env — never shared"
    while true; do
        PRIVATE_KEY=$(ask_secret "Enter private key")
        if [[ "$PRIVATE_KEY" =~ ^0x[a-fA-F0-9]{64}$ ]]; then
            success "Valid private key format"
            break
        else
            error "Invalid format. Must be 0x + 64 hex characters"
        fi
    done

    # ── LLM Provider ──
    echo ""
    info "Select your LLM provider:"
    echo -e "  ${GREEN}▶${RESET} ${BOLD}1${RESET}. OpenRouter  ${DIM}— Cheapest, 100+ models (recommended)${RESET}"
    echo -e "    ${BOLD}2${RESET}. OpenAI      ${DIM}— GPT-4o, GPT-4o-mini${RESET}"
    echo -e "    ${BOLD}3${RESET}. Anthropic   ${DIM}— Claude Sonnet 4.5, Claude Haiku 4.5${RESET}"
    echo -e "    ${BOLD}4${RESET}. Google      ${DIM}— Gemini 2.5 Flash/Pro${RESET}"
    echo ""
    echo -ne "  ${WHITE}?${RESET}  Select ${DIM}[1-4, default: 1]${RESET}: "
    read -r LLM_CHOICE
    LLM_CHOICE=${LLM_CHOICE:-1}

    case "$LLM_CHOICE" in
        1)
            LLM_PROVIDER="openrouter"
            KEY_NAME="OPENROUTER_API_KEY"
            KEY_URL="https://openrouter.ai/keys"
            DEFAULT_MODEL="google/gemini-2.5-flash"
            ;;
        2)
            LLM_PROVIDER="openai"
            KEY_NAME="OPENAI_API_KEY"
            KEY_URL="https://platform.openai.com/api-keys"
            DEFAULT_MODEL="gpt-4o-mini"
            ;;
        3)
            LLM_PROVIDER="anthropic"
            KEY_NAME="ANTHROPIC_API_KEY"
            KEY_URL="https://console.anthropic.com/settings/keys"
            DEFAULT_MODEL="claude-sonnet-4-5-20250929"
            ;;
        4)
            LLM_PROVIDER="gemini"
            KEY_NAME="GEMINI_API_KEY"
            KEY_URL="https://aistudio.google.com/apikey"
            DEFAULT_MODEL="gemini-2.5-flash"
            ;;
        *)
            warn "Invalid choice, defaulting to OpenRouter"
            LLM_PROVIDER="openrouter"
            KEY_NAME="OPENROUTER_API_KEY"
            KEY_URL="https://openrouter.ai/keys"
            DEFAULT_MODEL="google/gemini-2.5-flash"
            ;;
    esac

    success "Provider: $LLM_PROVIDER"

    # ── API Key ──
    echo ""
    info "Get your key at: ${CYAN}$KEY_URL${RESET}"
    while true; do
        API_KEY=$(ask_secret "Enter $KEY_NAME")
        if [ ${#API_KEY} -ge 8 ]; then
            success "API key saved"
            break
        else
            error "API key seems too short"
        fi
    done

    # ── Model ──
    echo ""
    info "Model ${DIM}[default: $DEFAULT_MODEL]${RESET}"
    MODEL=$(ask "Model")
    MODEL=${MODEL:-$DEFAULT_MODEL}
    success "Model: $MODEL"

    # ── HuggingFace ──
    echo ""
    info "HuggingFace stores your agent's conversation history"
    info "Create token: ${CYAN}https://huggingface.co/settings/tokens${RESET}"
    info "Create dataset: ${CYAN}https://huggingface.co/new-dataset${RESET}"
    echo ""
    while true; do
        HF_TOKEN=$(ask_secret "HuggingFace token (hf_...)")
        if [[ "$HF_TOKEN" =~ ^hf_ ]]; then
            success "Token saved"
            break
        else
            error "Token should start with hf_"
        fi
    done

    while true; do
        HF_REPO=$(ask "HuggingFace dataset (username/repo-name)")
        if [[ "$HF_REPO" == *"/"* ]]; then
            success "Dataset: $HF_REPO"
            break
        else
            error "Must be in format: username/repo-name"
        fi
    done

    # ── Agent Prompt ──
    echo ""
    info "Choose a prompt for your agent:"
    echo -e "  ${GREEN}▶${RESET} ${BOLD}1${RESET}. Default Analytics  ${DIM}— DeFi analytics + market summary${RESET}"
    echo -e "    ${BOLD}2${RESET}. Market Monitor     ${DIM}— Price tracking + trading signals${RESET}"
    echo -e "    ${BOLD}3${RESET}. Research Agent     ${DIM}— Web research + news summarization${RESET}"
    echo -e "    ${BOLD}4${RESET}. Custom             ${DIM}— Write your own prompt${RESET}"
    echo ""
    echo -ne "  ${WHITE}?${RESET}  Select ${DIM}[1-4, default: 1]${RESET}: "
    read -r PROMPT_CHOICE
    PROMPT_CHOICE=${PROMPT_CHOICE:-1}

    case "$PROMPT_CHOICE" in
        1) AGENT_PROMPT="" ;;  # Will use default template
        2)
            AGENT_PROMPT="You are a market monitoring agent on Ritual Chain. Track cryptocurrency prices and identify trading opportunities. Fetch current prices for top 20 altcoins, calculate 24h changes, identify top movers, and check for unusual volume spikes. Return a structured report with top gainers, top losers, volume anomalies, trading signals, and market sentiment."
            ;;
        3)
            AGENT_PROMPT="You are a research agent on Ritual Chain. Gather and summarize information about blockchain and DeFi developments. Search for recent news, focus on Ritual Chain ecosystem developments, identify new protocols and partnerships, and summarize key findings. Return a research brief with top news items, technical developments, and ecosystem updates."
            ;;
        4)
            info "Enter your prompt (press Enter when done):"
            echo -ne "  > "
            read -r AGENT_PROMPT
            if [ -z "$AGENT_PROMPT" ]; then
                warn "Empty prompt, using default"
                AGENT_PROMPT=""
            fi
            ;;
        *) AGENT_PROMPT="" ;;
    esac

    success "Prompt configured"

    # ── Config ──
    echo ""
    info "Deployment settings:"
    SALT=$(ask "Salt ${DIM}[default: my-sovereign-agent]${RESET}")
    SALT=${SALT:-my-sovereign-agent}

    echo ""
    info "Execution frequency:"
    echo -e "  ${GREEN}▶${RESET} ${BOLD}1${RESET}. ~12 min   ${DIM}— Frequent${RESET}"
    echo -e "    ${BOLD}2${RESET}. ~29 min   ${DIM}— Balanced (recommended)${RESET}"
    echo -e "    ${BOLD}3${RESET}. ~58 min   ${DIM}— Hourly${RESET}"
    echo -e "    ${BOLD}4${RESET}. ~2.9 hr   ${DIM}— Every few hours${RESET}"
    echo ""
    echo -ne "  ${WHITE}?${RESET}  Select ${DIM}[1-4, default: 2]${RESET}: "
    read -r FREQ_CHOICE
    FREQ_CHOICE=${FREQ_CHOICE:-2}

    case "$FREQ_CHOICE" in
        1) FREQUENCY=2000 ;;
        2) FREQUENCY=5000 ;;
        3) FREQUENCY=10000 ;;
        4) FREQUENCY=30000 ;;
        *) FREQUENCY=5000 ;;
    esac

    FUND_AMOUNT=$(ask "Fund amount in RITUAL ${DIM}[default: 0.1]${RESET}")
    FUND_AMOUNT=${FUND_AMOUNT:-0.1}

    success "Config complete"
}

# ── Generate .env ───────────────────────────────────────────
generate_env() {
    section "Generate Configuration"

    ENV_FILE="$INSTALL_DIR/.env"

    # Determine agent prompt file path
    if [ -z "$AGENT_PROMPT" ]; then
        PROMPT_LINE=""
    else
        PROMPT_LINE="$AGENT_PROMPT"
    fi

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
AGENT_PROMPT=$PROMPT_LINE

# ── Deployment Config ─────────────────────────────────────────
SALT=$SALT
CLI_TYPE=5
FREQUENCY=$FREQUENCY
WINDOW_NUM_CALLS=5
ROLLOVER_THRESHOLD_BPS=5000
FUND_AMOUNT=$FUND_AMOUNT
EOF

    # Secure the .env file
    chmod 600 "$ENV_FILE"
    success ".env written to $ENV_FILE"
    success "File permissions set to 600 (owner-only)"
}

# ── Review & Deploy ─────────────────────────────────────────
review_and_deploy() {
    section "Review"

    MASKED_KEY="${PRIVATE_KEY:0:6}...${PRIVATE_KEY: -4}"
    MASKED_API="${API_KEY:0:8}..."
    MASKED_HF="${HF_TOKEN:0:8}..."

    echo -e "  ${BOLD}Configuration Summary${RESET}"
    echo -e "  ──────────────────────────────────────────────────────"
    echo -e "  Wallet:          $MASKED_KEY"
    echo -e "  Chain:           Ritual Chain (ID 1979)"
    echo -e ""
    echo -e "  LLM Provider:    $LLM_PROVIDER"
    echo -e "  API Key:         $KEY_NAME ($MASKED_API)"
    echo -e "  Model:           $MODEL"
    echo -e ""
    echo -e "  HuggingFace:     $HF_REPO"
    echo -e "  HF Token:        $MASKED_HF"
    echo -e ""
    echo -e "  Salt:            $SALT"
    echo -e "  Frequency:       every $FREQUENCY blocks (~$(echo "scale=1; $FREQUENCY * 0.35 / 60" | bc) min)"
    echo -e "  Fund Amount:     $FUND_AMOUNT RITUAL"
    echo -e "  ──────────────────────────────────────────────────────"
    echo ""

    echo -ne "  ${WHITE}?${RESET}  Deploy now? ${DIM}[Y/n]${RESET}: "
    read -r DEPLOY_CONFIRM
    DEPLOY_CONFIRM=${DEPLOY_CONFIRM:-Y}

    if [[ "$DEPLOY_CONFIRM" =~ ^[Yy]$ ]]; then
        echo ""
        info "Running deployment..."
        echo ""

        if [ "$VENV_ACTIVE" = true ]; then
            source "$INSTALL_DIR/venv/bin/activate" 2>/dev/null || true
        fi

        python3 "$INSTALL_DIR/scripts/deploy.py"

        echo ""
        echo -e "${GREEN}${BOLD}"
        echo '  ◆ ═══════════════════════════════════════════════════════ ◆'
        echo '  ║                                                       ║'
        echo '  ║              Sovereign Agent Deployed!                ║'
        echo '  ║                                                       ║'
        echo '  ◆ ═══════════════════════════════════════════════════════ ◆'
        echo -e "${RESET}"
    else
        info "Configuration saved to $INSTALL_DIR/.env"
        info "Deploy later with:"
        echo -e "    ${CYAN}cd $INSTALL_DIR && python3 scripts/deploy.py${RESET}"
    fi

    echo ""
    info "Useful commands:"
    echo -e "    ${CYAN}cd $INSTALL_DIR${RESET}"
    echo -e "    ${CYAN}python3 scripts/deploy.py${RESET}                    # Deploy"
    echo -e "    ${CYAN}python3 scripts/check-status.py --harness 0x...${RESET}  # Check status"
    echo -e "    ${CYAN}python3 scripts/reconfigure.py --harness 0x...${RESET}   # Reconfigure"
    echo ""
    info "Explorer: https://explorer.ritualfoundation.org/agents?kind=sovereign"
    info "Docs: https://github.com/frianowzki/ritual-sovereign-agent-guide"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════

main() {
    clear 2>/dev/null || true
    banner

    info "Platform: $(uname -s) ($(uname -m))"
    info "This installer will set up a Sovereign Agent step by step."
    echo ""

    echo -ne "  ${WHITE}?${RESET}  Continue? ${DIM}[Y/n]${RESET}: "
    read -r GO
    GO=${GO:-Y}
    if [[ ! "$GO" =~ ^[Yy]$ ]]; then
        info "Goodbye!"
        exit 0
    fi

    detect_os
    install_system_deps
    clone_repo
    install_python_deps
    setup_config
    generate_env
    review_and_deploy
}

main "$@"
