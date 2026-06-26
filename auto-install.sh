#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  ◆ Ritual Sovereign Agent — Universal Auto Installer
#
#  One script for all platforms. Auto-detects OS, installs deps,
#  clones repo, sets up environment. No questions asked.
#
#  Works on: Linux (Ubuntu/Debian/Fedora/Arch), macOS, Windows (WSL)
#
#  Usage:
#    curl -LsSf https://raw.githubusercontent.com/frianowzki/ritual-sovereign-agent-guide/master/auto-install.sh | bash
#
#  After install, edit ~/.env with your credentials:
#    nano ~/ritual-sovereign-agent-guide/.env
# ═══════════════════════════════════════════════════════════════

set -e

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
BLUE='\033[0;94m'
CYAN='\033[0;96m'
WHITE='\033[1;97m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

CHECK="✓"
CROSS="✗"
WARN="⚠"
BULLET="•"

info()    { echo -e "  ${BLUE}${BULLET}${RESET}  $*"; }
success() { echo -e "  ${GREEN}${CHECK}${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}${WARN}${RESET}  $*"; }
error()   { echo -e "  ${RED}${CROSS}${RESET}  $*"; }
step()    { echo -e "\n${CYAN}${BOLD}  ◆ $*${RESET}"; }

INSTALL_DIR="$HOME/ritual-sovereign-agent-guide"
REPO_URL="https://github.com/frianowzki/ritual-sovereign-agent-guide.git"

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
        MINGW*|MSYS*|CYGWIN*)
            DISTRO="windows"
            ;;
        *)
            DISTRO="unknown"
            ;;
    esac
}

# ── Install System Dependencies ─────────────────────────────
install_system_deps() {
    step "Installing system dependencies"

    case "$DISTRO" in
        ubuntu|debian)
            info "apt update + upgrade..."
            sudo apt update -qq 2>/dev/null
            sudo apt upgrade -y -qq 2>/dev/null

            info "Installing packages..."
            sudo apt install -y -qq \
                git curl wget unzip \
                python3 python3-pip python3-venv python3-dev \
                build-essential pkg-config libssl-dev \
                2>/dev/null
            success "System packages installed"
            ;;
        fedora|rhel|centos)
            info "dnf update..."
            sudo dnf update -y -q 2>/dev/null

            info "Installing packages..."
            sudo dnf install -y -q \
                git curl wget unzip \
                python3 python3-pip python3-devel \
                gcc openssl-devel pkg-config \
                2>/dev/null
            success "System packages installed"
            ;;
        arch|manjaro)
            info "pacman update..."
            sudo pacman -Syu --noconfirm --quiet 2>/dev/null

            info "Installing packages..."
            sudo pacman -S --noconfirm --quiet \
                git curl wget unzip \
                python python-pip \
                base-devel openssl \
                2>/dev/null
            success "System packages installed"
            ;;
        macos)
            if ! command -v brew &>/dev/null; then
                info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>/dev/null
            fi
            info "Installing packages..."
            brew install git python openssl 2>/dev/null
            success "System packages installed"
            ;;
        windows)
            info "Windows detected (WSL/MSYS)"
            info "Make sure Git and Python are installed"
            ;;
        *)
            warn "Unknown OS — install manually: git, python3, pip"
            ;;
    esac
}

# ── Install uv (fast Python package manager) ────────────────
install_uv() {
    step "Installing uv (fast Python package manager)"

    if command -v uv &>/dev/null; then
        success "uv already installed: $(uv --version)"
        return
    fi

    info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh 2>/dev/null | sh 2>/dev/null
    export PATH="$HOME/.local/bin:$PATH"

    if command -v uv &>/dev/null; then
        success "uv installed: $(uv --version)"
    else
        warn "uv install failed, falling back to pip"
    fi
}

# ── Clone Repository ────────────────────────────────────────
clone_repo() {
    step "Setting up project"

    if [ -d "$INSTALL_DIR" ]; then
        info "Project exists, pulling latest..."
        cd "$INSTALL_DIR"
        git pull origin master 2>/dev/null || true
        success "Updated to latest"
    else
        info "Cloning repository..."
        git clone --quiet "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        success "Cloned to $INSTALL_DIR"
    fi
}

# ── Setup Python Environment ────────────────────────────────
setup_python() {
    step "Setting up Python environment"

    cd "$INSTALL_DIR"

    # Remove broken venv if exists
    if [ -d "venv" ] && [ ! -f "venv/bin/activate" ] && [ ! -f "venv/Scripts/activate" ]; then
        warn "Removing broken venv..."
        rm -rf venv
    fi

    # Create venv
    info "Creating virtual environment..."
    VENV_OK=false

    # Try python3 -m venv
    if python3 -m venv venv 2>/dev/null; then
        VENV_OK=true
    elif python -m venv venv 2>/dev/null; then
        VENV_OK=true
    # Fallback: uv venv
    elif command -v uv &>/dev/null; then
        info "python3 venv failed, trying uv venv..."
        if uv venv venv 2>/dev/null; then
            VENV_OK=true
        fi
    fi

    # Activate venv
    if $VENV_OK; then
        if [ -f "venv/bin/activate" ]; then
            source venv/bin/activate
        elif [ -f "venv/Scripts/activate" ]; then
            source venv/Scripts/activate
        fi
        success "Virtual environment ready"
    else
        warn "Could not create venv, using system Python"
    fi

    # Install packages
    info "Installing Python packages..."

    if command -v uv &>/dev/null; then
        if $VENV_OK; then
            info "Using uv (venv mode)..."
            uv pip install web3 eciespy eth-abi 2>/dev/null
        else
            info "Using uv (system mode)..."
            uv pip install --system web3 eciespy eth-abi 2>/dev/null
        fi
    else
        if $VENV_OK; then
            info "Using pip..."
            pip install web3 eciespy eth-abi 2>/dev/null
        else
            info "Using pip --user..."
            pip install --user web3 eciespy eth-abi 2>/dev/null
        fi
    fi

    # Verify installation
    if python3 -c "import web3; print('web3', web3.__version__)" 2>/dev/null; then
        success "Python packages installed"
    else
        error "web3 not found — run manually: pip install web3 eciespy eth-abi"
    fi
}

# ── Check Rust (needed for eciespy) ─────────────────────────
check_rust() {
    if command -v rustc &>/dev/null || [ -f "$HOME/.cargo/bin/rustc" ]; then
        return
    fi

    step "Installing Rust (needed for eciespy)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs 2>/dev/null | sh -s -- -y 2>/dev/null
    export PATH="$HOME/.cargo/bin:$PATH"

    if command -v rustc &>/dev/null; then
        success "Rust installed"
    else
        warn "Rust install failed — eciespy may fail"
    fi
}

# ── Create .env template ────────────────────────────────────
create_env_template() {
    step "Creating .env template"

    ENV_FILE="$INSTALL_DIR/.env"

    if [ -f "$ENV_FILE" ]; then
        success ".env already exists"
        return
    fi

    cat > "$ENV_FILE" << 'EOF'
# ═══════════════════════════════════════════════════════════════
#  Ritual Sovereign Agent — Configuration
#  https://github.com/frianowzki/ritual-sovereign-agent-guide
# ═══════════════════════════════════════════════════════════════

# ── Blockchain ─────────────────────────────────────────────────
PRIVATE_KEY=0xYOUR_PRIVATE_KEY_HERE
RPC_URL=https://rpc.ritualfoundation.org

# ── LLM Provider ──────────────────────────────────────────────
# Options: openrouter, openai, anthropic, gemini
LLM_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-v1-YOUR_KEY_HERE
MODEL=google/gemini-2.5-flash

# ── HuggingFace ───────────────────────────────────────────────
HF_TOKEN=hf_YOUR_TOKEN_HERE
HF_REPO_ID=yourname/agent-data

# ── Agent Prompt ──────────────────────────────────────────────
AGENT_PROMPT=You are a sovereign AI agent on Ritual Chain. Analyze on-chain data and provide actionable insights.

# ── Deployment Config ─────────────────────────────────────────
SALT=my-sovereign-agent
CLI_TYPE=5
FREQUENCY=2000
WINDOW_NUM_CALLS=5
ROLLOVER_THRESHOLD_BPS=5000
FUND_AMOUNT=0.1
EOF

    chmod 600 "$ENV_FILE"
    success "Created $ENV_FILE"
    warn "Edit it with your credentials before deploying!"
}

# ── Print Summary ────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║                                                          ║"
    echo "  ║           ◆  INSTALLATION COMPLETE!  ◆                  ║"
    echo "  ║                                                          ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo ""
    echo -e "  ${BOLD}Next steps:${RESET}"
    echo ""
    echo -e "  ${CYAN}1.${RESET} Edit your credentials:"
    echo -e "     ${DIM}nano ~/ritual-sovereign-agent-guide/.env${RESET}"
    echo ""
    echo -e "  ${CYAN}2.${RESET} Deploy your agent:"
    echo -e "     ${DIM}cd ~/ritual-sovereign-agent-guide${RESET}"
    echo -e "     ${DIM}source venv/bin/activate${RESET}"
    echo -e "     ${DIM}python3 scripts/deploy.py${RESET}"
    echo ""
    echo -e "  ${BOLD}Need help?${RESET}"
    echo -e "  ${DIM}https://github.com/frianowzki/ritual-sovereign-agent-guide${RESET}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════

main() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ◆ RITUAL SOVEREIGN AGENT — AUTO INSTALLER"
    echo -e "${RESET}"
    echo -e "  ${DIM}Detecting system and installing dependencies...${RESET}"
    echo ""

    detect_os
    info "OS: $DISTRO ($ARCH)"

    install_system_deps
    check_rust
    install_uv
    clone_repo
    setup_python
    create_env_template
    print_summary
}

main "$@"
