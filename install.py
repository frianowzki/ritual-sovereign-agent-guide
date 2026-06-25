#!/usr/bin/env python3
"""
◆ Ritual Sovereign Agent — Interactive Installer

One-script setup: guides you through environment configuration,
dependency installation, and deployment in one flow.

Usage:
    python3 install.py

Works on: Linux, macOS, Windows (PowerShell + WSL)
"""

import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

# ═══════════════════════════════════════════════════════════════
#  Constants
# ═══════════════════════════════════════════════════════════════

VERSION = "1.0.0"
REPO_URL = "https://github.com/frianowzki/ritual-sovereign-agent-guide"
RITUAL_RPC = "https://rpc.ritualfoundation.org"
CHAIN_ID = 1979
EXPLORER_URL = "https://explorer.ritualfoundation.org"

# ═══════════════════════════════════════════════════════════════
#  Colors (cross-platform)
# ═══════════════════════════════════════════════════════════════

class C:
    """ANSI color codes — gracefully degrades on unsupported terminals."""
    _enabled = sys.stdout.isatty() and os.environ.get("TERM", "") != "dumb"

    RESET   = "\033[0m"   if _enabled else ""
    BOLD    = "\033[1m"    if _enabled else ""
    DIM     = "\033[2m"    if _enabled else ""
    RED     = "\033[91m"   if _enabled else ""
    GREEN   = "\033[92m"   if _enabled else ""
    YELLOW  = "\033[93m"   if _enabled else ""
    BLUE    = "\033[94m"   if _enabled else ""
    MAGENTA = "\033[95m"   if _enabled else ""
    CYAN    = "\033[96m"   if _enabled else ""
    WHITE   = "\033[97m"   if _enabled else ""

# ═══════════════════════════════════════════════════════════════
#  Helpers
# ═══════════════════════════════════════════════════════════════

def clear():
    os.system("cls" if platform.system() == "Windows" else "clear")

def banner():
    print(f"""
{C.MAGENTA}{C.BOLD}  ◆ ═══════════════════════════════════════════════════════ ◆
  ║                                                       ║
  ║        Ritual Sovereign Agent Installer v{VERSION}       ║
  ║                                                       ║
  ║   Deploy autonomous AI agents on Ritual Chain 1979    ║
  ║                                                       ║
  ◆ ═══════════════════════════════════════════════════════ ◆{C.RESET}
""")

def section(title):
    print(f"\n{C.CYAN}{C.BOLD}  ── {title} {'─' * max(0, 50 - len(title))}{C.RESET}\n")

def info(msg):
    print(f"  {C.BLUE}ℹ{C.RESET}  {msg}")

def success(msg):
    print(f"  {C.GREEN}✔{C.RESET}  {msg}")

def warn(msg):
    print(f"  {C.YELLOW}⚠{C.RESET}  {msg}")

def error(msg):
    print(f"  {C.RED}✘{C.RESET}  {msg}")

def ask(prompt, default=None, validate=None, password=False):
    """Prompt user for input with optional default and validation."""
    while True:
        suffix = f" {C.DIM}[{default}]{C.RESET}" if default else ""
        if password:
            import getpass
            sys.stdout.write(f"  {C.WHITE}?{C.RESET}  {prompt}{suffix}: ")
            sys.stdout.flush()
            value = getpass.getpass("")
        else:
            value = input(f"  {C.WHITE}?{C.RESET}  {prompt}{suffix}: ").strip()

        if not value and default is not None:
            value = str(default)

        if not value:
            error("This field is required.")
            continue

        if validate:
            ok, msg = validate(value)
            if not ok:
                error(msg)
                continue

        return value

def choose(prompt, options, default=1):
    """Let user pick from numbered options."""
    print(f"\n  {C.WHITE}?{C.RESET}  {prompt}")
    for i, (key, label, desc) in enumerate(options, 1):
        marker = f"{C.GREEN}▶{C.RESET}" if i == default else " "
        print(f"  {marker} {C.BOLD}{i}{C.RESET}. {label} {C.DIM}— {desc}{C.RESET}")

    while True:
        choice = input(f"\n  {C.WHITE}?{C.RESET}  Select [1-{len(options)}] {C.DIM}[{default}]{C.RESET}: ").strip()
        if not choice:
            choice = default
        try:
            idx = int(choice)
            if 1 <= idx <= len(options):
                selected = options[idx - 1]
                print(f"  {C.GREEN}✔{C.RESET}  Selected: {selected[1]}")
                return selected[0]
        except ValueError:
            if choice in [o[0] for o in options]:
                print(f"  {C.GREEN}✔{C.RESET}  Selected: {choice}")
                return choice
        error(f"Please enter a number between 1 and {len(options)}")

def confirm(prompt, default=True):
    """Yes/no confirmation."""
    suffix = "Y/n" if default else "y/N"
    while True:
        ans = input(f"  {C.WHITE}?{C.RESET}  {prompt} {C.DIM}[{suffix}]{C.RESET}: ").strip().lower()
        if not ans:
            return default
        if ans in ("y", "yes"):
            return True
        if ans in ("n", "no"):
            return False
        error("Please enter y or n")

def run(cmd, check=True, capture=False):
    """Run a shell command."""
    result = subprocess.run(cmd, shell=True, capture_output=capture, text=True)
    if check and result.returncode != 0:
        if capture:
            return result.stdout.strip()
        error(f"Command failed: {cmd}")
        if result.stderr:
            print(f"  {C.DIM}{result.stderr.strip()}{C.RESET}")
        return None
    if capture:
        return result.stdout.strip()
    return True

# ═══════════════════════════════════════════════════════════════
#  Validators
# ═══════════════════════════════════════════════════════════════

def validate_private_key(key):
    key = key.strip()
    if not key.startswith("0x"):
        return False, "Private key must start with 0x"
    if len(key) != 66:
        return False, f"Private key must be 64 hex chars (got {len(key) - 2})"
    try:
        int(key, 16)
    except ValueError:
        return False, "Private key must be valid hex"
    return True, ""

def validate_eth_address(addr):
    addr = addr.strip()
    if not addr.startswith("0x") or len(addr) != 42:
        return False, "Address must be 0x + 40 hex chars"
    try:
        int(addr, 16)
    except ValueError:
        return False, "Address must be valid hex"
    return True, ""

def validate_api_key(key, prefix=None):
    key = key.strip()
    if len(key) < 8:
        return False, "API key seems too short"
    if prefix and not key.startswith(prefix):
        return False, f"API key should start with {prefix}"
    return True, ""

def validate_hf_token(token):
    token = token.strip()
    if not token.startswith("hf_"):
        return False, "HuggingFace token should start with hf_"
    return True, ""

def validate_hf_repo(repo):
    repo = repo.strip()
    if "/" not in repo:
        return False, "Must be in format: username/repo-name"
    parts = repo.split("/")
    if len(parts) != 2 or not all(parts):
        return False, "Must be in format: username/repo-name"
    return True, ""

def validate_number(val, min_val=None, max_val=None, float_ok=False):
    try:
        num = float(val) if float_ok else int(val)
        if min_val is not None and num < min_val:
            return False, f"Minimum value is {min_val}"
        if max_val is not None and num > max_val:
            return False, f"Maximum value is {max_val}"
        return True, ""
    except ValueError:
        return False, "Must be a number"

# ═══════════════════════════════════════════════════════════════
#  Step 1: System Check
# ═══════════════════════════════════════════════════════════════

def step_system_check():
    section("System Check")

    # OS
    os_name = platform.system()
    os_version = platform.platform()
    info(f"OS: {os_version}")

    # Python
    py_ver = sys.version_info
    if py_ver < (3, 10):
        error(f"Python 3.10+ required (found {py_ver.major}.{py_ver.minor})")
        info("Install from: https://www.python.org/downloads/")
        sys.exit(1)
    success(f"Python {py_ver.major}.{py_ver.minor}.{py_ver.micro}")

    # Git
    git = shutil.which("git")
    if git:
        git_ver = run("git --version", capture=True)
        success(f"Git: {git_ver}")
    else:
        warn("Git not found — install from https://git-scm.com")
        info("You can still install manually by downloading the zip from GitHub")

    # pip
    pip_cmd = f"{sys.executable} -m pip"
    pip_ver = run(f"{pip_cmd} --version", capture=True, check=False)
    if pip_ver:
        success(f"pip: {pip_ver.split()[1]}")
    else:
        error("pip not found")
        sys.exit(1)

    return os_name, pip_cmd

# ═══════════════════════════════════════════════════════════════
#  Step 2: Install Dependencies
# ═══════════════════════════════════════════════════════════════

def step_install_deps(pip_cmd):
    section("Dependencies")

    deps = ["web3", "eciespy", "eth-abi"]
    info(f"Installing: {', '.join(deps)}")

    # Check if already installed
    all_ok = True
    for dep in deps:
        check_name = dep.replace("-", "_")
        try:
            __import__(check_name)
            success(f"{dep} already installed")
        except ImportError:
            all_ok = False

    if all_ok and confirm("All dependencies already installed. Skip?", default=True):
        return

    # Install
    print()
    cmd = f"{pip_cmd} install {' '.join(deps)}"
    info(f"Running: {cmd}")

    if os_name == "Windows":
        result = subprocess.run(cmd, shell=True)
    else:
        result = subprocess.run(cmd, shell=True)

    if result.returncode != 0:
        # macOS: try with rust for eciespy
        if os_name == "Darwin":
            warn("eciespy may need Rust compiler")
            info("Try: brew install rust && pip install eciespy")
        error("Dependency installation failed")
        info("Try manually: pip install web3 eciespy eth-abi")
        if not confirm("Continue anyway?", default=False):
            sys.exit(1)
    else:
        success("All dependencies installed")

# ═══════════════════════════════════════════════════════════════
#  Step 3: Blockchain Config
# ═══════════════════════════════════════════════════════════════

def step_blockchain():
    section("Blockchain Configuration")

    info(f"Chain: Ritual Chain (ID {CHAIN_ID})")
    info(f"RPC: {RITUAL_RPC}")
    info(f"Explorer: {EXPLORER_URL}")
    print()

    private_key = ask(
        "Enter your private key (0x-prefixed)",
        validate=validate_private_key,
        password=True
    )

    # Try to derive address
    try:
        from eth_account import Account
        account = Account.from_key(private_key)
        success(f"Wallet: {account.address}")
    except Exception:
        warn("Could not derive address (will verify during deployment)")

    return private_key

# ═══════════════════════════════════════════════════════════════
#  Step 4: LLM Provider
# ═══════════════════════════════════════════════════════════════

LLM_PROVIDERS = [
    ("openrouter", "OpenRouter", "Cheapest, 100+ models, recommended"),
    ("openai",     "OpenAI",     "GPT-4o, GPT-4o-mini"),
    ("anthropic",  "Anthropic",  "Claude Sonnet 4.5, Claude Haiku 4.5"),
    ("gemini",     "Google",     "Gemini 2.5 Flash/Pro, free tier available"),
]

LLM_MODELS = {
    "openrouter": [
        ("google/gemini-2.5-flash",         "Gemini 2.5 Flash",     "Fast, cheap, good quality"),
        ("google/gemini-2.5-pro",           "Gemini 2.5 Pro",       "Best quality, more expensive"),
        ("anthropic/claude-sonnet-4-5-20250929",  "Claude Sonnet 4.5 (via OR)", "Best reasoning"),
        ("openai/gpt-4o-mini",             "GPT-4o Mini (via OR)", "Fast, cheap"),
        ("meta-llama/llama-4-maverick",     "Llama 4 Maverick",     "Open source, free on OR"),
        ("deepseek/deepseek-chat-v3-0324",  "DeepSeek V3",          "Free, good quality"),
    ],
    "openai": [
        ("gpt-4o-mini",     "GPT-4o Mini",  "Fast, cheap ($0.15/M)"),
        ("gpt-4o",          "GPT-4o",       "Best quality ($2.50/M)"),
        ("gpt-4.1-mini",    "GPT-4.1 Mini", "Latest mini model"),
        ("o3-mini",         "o3-mini",      "Reasoning model"),
    ],
    "anthropic": [
        ("claude-sonnet-4-5-20250929",  "Claude Sonnet 4.5", "Best balance of speed/quality"),
        ("claude-haiku-4-5-20250929",   "Claude Haiku 4.5",  "Fastest, cheapest"),
        ("claude-opus-4-20250514",      "Claude Opus 4",     "Best reasoning, most expensive"),
    ],
    "gemini": [
        ("gemini-2.5-flash",   "Gemini 2.5 Flash",  "Fast, free tier available"),
        ("gemini-2.5-pro",     "Gemini 2.5 Pro",    "Best quality"),
        ("gemini-2.0-flash",   "Gemini 2.0 Flash",  "Previous gen, very fast"),
    ],
}

API_KEY_INFO = {
    "openrouter": ("OPENROUTER_API_KEY", "sk-or-v1-", "https://openrouter.ai/keys"),
    "openai":     ("OPENAI_API_KEY",     "sk-",       "https://platform.openai.com/api-keys"),
    "anthropic":  ("ANTHROPIC_API_KEY",  "sk-ant-",   "https://console.anthropic.com/settings/keys"),
    "gemini":     ("GEMINI_API_KEY",     None,        "https://aistudio.google.com/apikey"),
}

def step_llm():
    section("LLM Provider")

    provider = choose(
        "Select your LLM provider:",
        LLM_PROVIDERS,
        default=1
    )

    # API key
    key_name, key_prefix, key_url = API_KEY_INFO[provider]
    info(f"Get your key at: {C.CYAN}{key_url}{C.RESET}")
    print()

    validators = [lambda k: validate_api_key(k, key_prefix)] if key_prefix else [lambda k: validate_api_key(k)]
    api_key = ask(
        f"Enter your {key_name}",
        validate=validators[0] if key_prefix else lambda k: validate_api_key(k),
        password=True
    )
    success("API key saved")

    # Model
    print()
    models = LLM_MODELS[provider]
    default_model_idx = 1  # first model is default
    model = choose(
        "Select a model:",
        models,
        default=default_model_idx
    )

    return provider, key_name, api_key, model

# ═══════════════════════════════════════════════════════════════
#  Step 5: HuggingFace
# ═══════════════════════════════════════════════════════════════

def step_huggingface():
    section("HuggingFace (Conversation History)")

    info("HuggingFace stores your agent's conversation history and artifacts.")
    info(f"Create token at: {C.CYAN}https://huggingface.co/settings/tokens{C.RESET}")
    info(f"Create dataset at: {C.CYAN}https://huggingface.co/new-dataset{C.RESET}")
    print()

    hf_token = ask(
        "HuggingFace token (hf_...)",
        validate=validate_hf_token,
        password=True
    )
    success("Token saved")

    print()
    info("Dataset must be in format: username/repo-name")
    info("Example: myname/sovereign-agent-data")
    hf_repo = ask(
        "HuggingFace dataset ID",
        validate=validate_hf_repo
    )
    success(f"Dataset: {hf_repo}")

    return hf_token, hf_repo

# ═══════════════════════════════════════════════════════════════
#  Step 6: Agent Prompt
# ═══════════════════════════════════════════════════════════════

TEMPLATES = {
    "default": """You are a sovereign AI agent on Ritual Chain. Your task is to analyze on-chain data and provide actionable insights for DeFi builders.

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

Be concise. Focus on signal over noise.""",

    "market": """You are a market monitoring agent on Ritual Chain. Your task is to track cryptocurrency prices and identify trading opportunities.

Instructions:
1. Fetch current prices for top 20 altcoins from CoinGecko
2. Calculate 24h and 7d price changes
3. Identify the top 3 biggest movers (up and down)
4. Check for unusual volume spikes
5. Monitor RITUAL token specifically

Return a structured report:
- 🔴 Top losers (with % drop)
- 🟢 Top gainers (with % rise)
- 📊 Volume anomalies
- 🎯 Trading signals (if any)
- 💡 Market sentiment (bullish/bearish/neutral)

Be data-driven. No speculation without evidence.""",

    "research": """You are a research agent on Ritual Chain. Your task is to gather and summarize information about blockchain and DeFi developments.

Instructions:
1. Search for recent news about blockchain technology and DeFi
2. Focus on developments relevant to Ritual Chain ecosystem
3. Identify new protocols, partnerships, or technical upgrades
4. Summarize key findings in a digestible format

Return a research brief:
- 📰 Top 3 news items of the day
- 🔬 Technical developments to watch
- 🌐 Ecosystem updates
- ⚡ Quick takes (one-liners)

Focus on actionable intelligence. Quality over quantity.""",
}

def step_prompt():
    section("Agent Prompt")

    info("This is what your agent will do every time it wakes up.")
    info("You can always change it later with reconfigure.py.")
    print()

    prompt_options = [
        ("default", "Default Analytics",   "DeFi analytics + market summary"),
        ("market",  "Market Monitor",      "Price tracking + trading signals"),
        ("research", "Research Agent",     "Web research + news summarization"),
        ("custom",  "Write Your Own",      "Enter a custom prompt"),
    ]

    choice = choose("Select a prompt template:", prompt_options, default=1)

    if choice == "custom":
        print()
        info("Enter your prompt (press Enter twice to finish):")
        lines = []
        empty_count = 0
        while True:
            line = input("  > ")
            if line == "":
                empty_count += 1
                if empty_count >= 2:
                    break
                lines.append("")
            else:
                empty_count = 0
                lines.append(line)

        prompt = "\n".join(lines).strip()
        if not prompt:
            warn("Empty prompt, using default")
            prompt = TEMPLATES["default"]
    else:
        prompt = TEMPLATES[choice]

    # Show preview
    print()
    info(f"Prompt preview ({len(prompt)} chars):")
    print(f"  {C.DIM}{'─' * 56}{C.RESET}")
    for line in prompt.split("\n")[:8]:
        print(f"  {C.DIM}{line}{C.RESET}")
    if len(prompt.split("\n")) > 8:
        print(f"  {C.DIM}  ... ({len(prompt.split(chr(10))) - 8} more lines){C.RESET}")
    print(f"  {C.DIM}{'─' * 56}{C.RESET}")

    if not confirm("Use this prompt?", default=True):
        return step_prompt()

    return prompt

# ═══════════════════════════════════════════════════════════════
#  Step 7: Deployment Config
# ═══════════════════════════════════════════════════════════════

def step_config():
    section("Deployment Configuration")

    # Salt
    salt = ask(
        "Unique salt (for deterministic address)",
        default="my-sovereign-agent"
    )

    # CLI type
    cli_options = [
        ("5", "Crush",    "Default runtime — recommended"),
        ("6", "ZeroClaw", "Alternative runtime"),
    ]
    cli_type = choose("Agent runtime:", cli_options, default=1)

    # Frequency
    print()
    freq_options = [
        ("2000",  "~12 min",  "Frequent — higher cost, more data"),
        ("5000",  "~29 min",  "Balanced — good for monitoring"),
        ("10000", "~58 min",  "Hourly — lower cost"),
        ("30000", "~2.9 hr",  "Every few hours — daily summary"),
        ("86400", "~8.4 hr",  "Twice daily — low cost"),
    ]
    freq = choose("Execution frequency:", freq_options, default=2)

    # Window calls
    window = ask(
        "Calls per rolling window",
        default="5",
        validate=lambda v: validate_number(v, min_val=1, max_val=50)
    )

    # Fund amount
    print()
    info("RITUAL to deposit into your harness RitualWallet")
    info("This pays for on-chain gas (~0.002-0.005 per heartbeat)")
    fund = ask(
        "Fund amount (RITUAL)",
        default="0.1",
        validate=lambda v: validate_number(v, min_val=0.01, max_val=10.0, float_ok=True)
    )

    # Cost estimate
    freq_val = int(freq)
    fund_val = float(fund)
    heartbeats = int(fund_val / 0.003)
    days = int(heartbeats * (freq_val * 0.35) / 86400)

    print()
    info(f"At {freq_val} blocks/call with {fund_val} RITUAL:")
    success(f"  ~{heartbeats} heartbeats")
    success(f"  ~{days} days of operation")

    return salt, cli_type, freq, window, fund

# ═══════════════════════════════════════════════════════════════
#  Step 8: Generate .env
# ═══════════════════════════════════════════════════════════════

def step_generate_env(config):
    section("Generate Configuration")

    env_path = Path(__file__).parent / ".env"

    if env_path.exists():
        if not confirm(f".env already exists. Overwrite?", default=False):
            info("Keeping existing .env")
            return

    env_content = f"""# ═══════════════════════════════════════════════════════════════
#  Ritual Sovereign Agent — Generated by install.py
#  {REPO_URL}
# ═══════════════════════════════════════════════════════════════

# ── Blockchain ─────────────────────────────────────────────────
PRIVATE_KEY={config['private_key']}
RPC_URL={RITUAL_RPC}

# ── LLM Provider ──────────────────────────────────────────────
LLM_PROVIDER={config['provider']}
{config['key_name']}={config['api_key']}
MODEL={config['model']}

# ── HuggingFace ───────────────────────────────────────────────
HF_TOKEN={config['hf_token']}
HF_REPO_ID={config['hf_repo']}

# ── Agent Prompt ──────────────────────────────────────────────
AGENT_PROMPT={config['prompt']}

# ── Deployment Config ─────────────────────────────────────────
SALT={config['salt']}
CLI_TYPE={config['cli_type']}
FREQUENCY={config['frequency']}
WINDOW_NUM_CALLS={config['window']}
ROLLOVER_THRESHOLD_BPS=5000
FUND_AMOUNT={config['fund']}
"""

    with open(env_path, "w") as f:
        f.write(env_content)

    success(f".env written to {env_path}")

# ═══════════════════════════════════════════════════════════════
#  Step 9: Review & Deploy
# ═══════════════════════════════════════════════════════════════

def step_review(config):
    section("Review Configuration")

    freq_val = int(config['frequency'])
    fund_val = float(config['fund'])

    print(f"""
  {C.BOLD}Configuration Summary{C.RESET}
  {'─' * 50}
  Wallet:          {config['private_key'][:6]}...{config['private_key'][-4:]}
  Chain:           Ritual Chain (ID {CHAIN_ID})

  LLM Provider:    {config['provider']}
  API Key:         {config['key_name']} ({config['api_key'][:8]}...)
  Model:           {config['model']}

  HuggingFace:     {config['hf_repo']}
  HF Token:        {config['hf_token'][:8]}...

  Salt:            {config['salt']}
  CLI Type:        {config['cli_type']}
  Frequency:       every {freq_val} blocks (~{freq_val * 0.35 / 60:.1f} min)
  Window Calls:    {config['window']}
  Fund Amount:     {config['fund']} RITUAL

  Est. Runtime:    ~{int(fund_val / 0.003 * freq_val * 0.35 / 86400)} days
  {'─' * 50}
""")

def step_deploy():
    section("Deploy")

    if not confirm("Deploy now?", default=True):
        info("You can deploy later with: python3 scripts/deploy.py")
        return False

    print()
    info("Running deployment script...")
    print()

    deploy_script = Path(__file__).parent / "scripts" / "deploy.py"
    if not deploy_script.exists():
        error(f"Deployment script not found: {deploy_script}")
        info("Make sure you're in the ritual-sovereign-agent-guide directory")
        return False

    result = subprocess.run([sys.executable, str(deploy_script)])
    return result.returncode == 0

# ═══════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════

def main():
    clear()
    banner()

    info(f"Platform: {platform.system()} ({platform.machine()})")
    info(f"Python: {sys.version.split()[0]}")
    info(f"Working dir: {Path(__file__).parent}")
    print()
    info("This installer will guide you through setting up a")
    info("Sovereign Agent on Ritual Chain step by step.")
    print()

    if not confirm("Continue?", default=True):
        info("Goodbye!")
        return

    # ── System check ──
    global os_name
    os_name, pip_cmd = step_system_check()

    # ── Dependencies ──
    step_install_deps(pip_cmd)

    # ── Blockchain ──
    private_key = step_blockchain()

    # ── LLM ──
    provider, key_name, api_key, model = step_llm()

    # ── HuggingFace ──
    hf_token, hf_repo = step_huggingface()

    # ── Prompt ──
    prompt = step_prompt()

    # ── Config ──
    salt, cli_type, frequency, window, fund = step_config()

    # ── Compile config ──
    config = {
        "private_key": private_key,
        "provider": provider,
        "key_name": key_name,
        "api_key": api_key,
        "model": model,
        "hf_token": hf_token,
        "hf_repo": hf_repo,
        "prompt": prompt,
        "salt": salt,
        "cli_type": cli_type,
        "frequency": frequency,
        "window": window,
        "fund": fund,
    }

    # ── Review ──
    step_review(config)

    # ── Generate .env ──
    step_generate_env(config)

    # ── Deploy ──
    deployed = step_deploy()

    # ── Done ──
    section("Setup Complete")

    if deployed:
        print(f"""
  {C.GREEN}{C.BOLD}  ◆ ═══════════════════════════════════════════════════════ ◆
  ║                                                       ║
  ║              Sovereign Agent Deployed!                ║
  ║                                                       ║
  ◆ ═══════════════════════════════════════════════════════ ◆{C.RESET}
""")
    else:
        print(f"""
  {C.YELLOW}{C.BOLD}  ◆ ═══════════════════════════════════════════════════════ ◆
  ║                                                       ║
  ║             Configuration Saved to .env               ║
  ║                                                       ║
  ◆ ═══════════════════════════════════════════════════════ ◆{C.RESET}
""")

    info("Useful commands:")
    print()
    print(f"  {C.CYAN}Deploy:{C.RESET}     python3 scripts/deploy.py")
    print(f"  {C.CYAN}Status:{C.RESET}     python3 scripts/check-status.py --harness 0xYourAddr")
    print(f"  {C.CYAN}Reconfig:{C.RESET}   python3 scripts/reconfigure.py --harness 0xYourAddr --prompt \"New task\"")
    print(f"  {C.CYAN}Explorer:{C.RESET}   {EXPLORER_URL}/agents?kind=sovereign")
    print()
    info("Docs: " + REPO_URL)
    print()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n  {C.YELLOW}Interrupted. Configuration not saved.{C.RESET}\n")
        sys.exit(1)
