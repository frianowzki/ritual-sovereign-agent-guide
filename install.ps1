# ═══════════════════════════════════════════════════════════════
#  ◆ Ritual Sovereign Agent — Windows PowerShell Installer
#
#  One-command setup for Sovereign Agents on Ritual Chain 1979.
#  Works on: Windows 10/11 (PowerShell 5.1+)
#
#  Usage:
#    powershell -ExecutionPolicy Bypass -File install.ps1
#
#  Or one-liner:
#    irm https://raw.githubusercontent.com/frianowzki/ritual-sovereign-agent-guide/master/install.ps1 | iex
# ═══════════════════════════════════════════════════════════════

param(
    [switch]$SkipDeploy,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ── Colors ──────────────────────────────────────────────────
$RED    = "`e[91m"
$GREEN  = "`e[92m"
$YELLOW = "`e[93m"
$BLUE   = "`e[94m"
$MAGENTA= "`e[95m"
$CYAN   = "`e[96m"
$WHITE  = "`e[97m"
$DIM    = "`e[2m"
$BOLD   = "`e[1m"
$RESET  = "`e[0m"

# Check if ANSI is supported (Windows 10 1511+)
if ($PSVersionTable.PSVersion.Major -lt 5 -or ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -lt 1)) {
    Write-Host "PowerShell 5.1+ required. Please update PowerShell." -ForegroundColor Red
    exit 1
}

# Enable ANSI on older Windows
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# ── Helpers ─────────────────────────────────────────────────
function Info($msg)    { Write-Host "  ${BLUE}`u{2022}${RESET}  $msg" }
function Success($msg) { Write-Host "  ${GREEN}`u{2713}${RESET}  $msg" }
function Warn($msg)    { Write-Host "  ${YELLOW}`u{26A0}${RESET}  $msg" }
function Error($msg)   { Write-Host "  ${RED}`u{2717}${RESET}  $msg" }
function Step($msg)    { Write-Host ""; Write-Host "  ${CYAN}${BOLD}`u{25C6} $msg${RESET}" }
function Divider()     { Write-Host "  ${DIM}$([string]::new([char]0x2500, 58))${RESET}" }
function Blank()       { Write-Host "" }

function Ask($prompt, $default = "") {
    $suffix = ""
    if ($default) { $suffix = " ${DIM}[$default]${RESET}" }
    $val = Read-Host -Prompt "  ${CYAN}`u{276F}${RESET}  $prompt$suffix"
    if (-not $val -and $default) { return $default }
    return $val
}

function AskSecret($prompt) {
    $secure = Read-Host -Prompt "  ${CYAN}`u{276F}${RESET}  $prompt (hidden)" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Pick($title, $options) {
    Write-Host "  ${WHITE}$title${RESET}"
    Blank
    for ($i = 0; $i -lt $options.Count; $i++) {
        $idx = $i + 1
        $name = $options[$i].Name
        $desc = $options[$i].Desc
        if ($i -eq 0) {
            Write-Host "  ${GREEN}`u{25B8}${RESET} ${BOLD}$idx${RESET}. ${WHITE}$name${RESET}"
        } else {
            Write-Host "    ${BOLD}$idx${RESET}. ${WHITE}$name${RESET}"
        }
        Write-Host "       ${DIM}$desc${RESET}"
    }
    Blank
    $choice = Ask "Select [1-$($options.Count), default: 1]"
    if (-not $choice) { $choice = "1" }
    try {
        $idx = [int]$choice
        if ($idx -ge 1 -and $idx -le $options.Count) {
            Success "Selected: ${WHITE}$($options[$idx-1].Name)${RESET}"
            return $idx
        }
    } catch {}
    Warn "Invalid choice, using default"
    return 1
}

function Progress($current, $total, $label) {
    $pct = [math]::Floor($current * 100 / $total)
    $filled = [math]::Floor($pct / 2)
    $empty = 50 - $filled
    $bar = "$([string]::new([char]0x2588, $filled))$([string]::new([char]0x2591, $empty))"
    Write-Host "  ${CYAN}[${RESET}${GREEN}$bar${RESET}${CYAN}]${RESET} ${WHITE}${pct}%${RESET} ${DIM}$label${RESET}"
}

function Banner {
    Write-Host "${MAGENTA}${BOLD}"
    Write-Host "    $([char]0x2554)$([string]::new([char]0x2550, 58))$([char]0x2557)"
    Write-Host "    $([char]0x2551)                                                          $([char]0x2551)"
    Write-Host "    $([char]0x2551)           $([char]0x25C6)  RITUAL SOVEREIGN AGENT  $([char]0x25C6)                  $([char]0x2551)"
    Write-Host "    $([char]0x2551)                                                          $([char]0x2551)"
    Write-Host "    $([char]0x2551)     Autonomous AI Agents on Ritual Chain (ID 1979)      $([char]0x2551)"
    Write-Host "    $([char]0x2551)                                                          $([char]0x2551)"
    Write-Host "    $([char]0x2551)  Factory Harness  $([char]0x2022)  TEE Execution  $([char]0x2022)  Async Callbacks  $([char]0x2551)"
    Write-Host "    $([char]0x2551)                                                          $([char]0x2551)"
    Write-Host "    $([char]0x2551)              Created by @frianowzki                      $([char]0x2551)"
    Write-Host "    $([char]0x2551)           github.com/frianowzki                          $([char]0x2551)"
    Write-Host "    $([char]0x2551)                                                          $([char]0x2551)"
    Write-Host "    $([char]0x255A)$([string]::new([char]0x2550, 58))$([char]0x255D)"
    Write-Host "${RESET}"
    Write-Host "  ${DIM}Deploy production-grade AI agents that run autonomously${RESET}"
    Write-Host "  ${DIM}on-chain, execute in Trusted Execution Environments,${RESET}"
    Write-Host "  ${DIM}and deliver results via async callbacks.${RESET}"
    Blank
}

function Subbox($title) {
    Write-Host "  ${DIM}$([char]0x2560)$([string]::new([char]0x2550, 56))$([char]0x2563)${RESET}"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BOLD}$title${RESET}"
    Write-Host "  ${DIM}$([char]0x2560)$([string]::new([char]0x2550, 56))$([char]0x2563)${RESET}"
}

# ── Check Command Exists ───────────────────────────────────
function Test-Command($cmd) {
    try { Get-Command $cmd -ErrorAction Stop | Out-Null; return $true }
    catch { return $false }
}

# ═══════════════════════════════════════════════════════════════
#  Step 1: System Check
# ═══════════════════════════════════════════════════════════════

function Step-System {
    Step "System Check"
    Info "Platform: ${WHITE}Windows ${RESET}($([Environment]::OSVersion.Version))"
    Progress 1 5 "Checking system"
    Blank

    # Git
    if (Test-Command "git") {
        $gitVer = (git --version) -replace 'git version ', ''
        Success "Git ${DIM}$gitVer${RESET}"
    } else {
        Warn "Git not found — will install"
        $script:NeedGit = $true
    }

    # Python
    $pythonCmd = $null
    if (Test-Command "python") {
        try {
            $pyVer = (python --version 2>&1) -replace 'Python ', ''
            $pyParts = $pyVer.Split('.')
            if ([int]$pyParts[0] -ge 3 -and [int]$pyParts[1] -ge 10) {
                Success "Python ${WHITE}$pyVer${RESET}"
                $script:PythonCmd = "python"
            } else {
                Warn "Python $pyVer found but 3.10+ required"
                $script:NeedPython = $true
            }
        } catch {
            Warn "Python not working properly"
            $script:NeedPython = $true
        }
    } elseif (Test-Command "python3") {
        try {
            $pyVer = (python3 --version 2>&1) -replace 'Python ', ''
            $pyParts = $pyVer.Split('.')
            if ([int]$pyParts[0] -ge 3 -and [int]$pyParts[1] -ge 10) {
                Success "Python ${WHITE}$pyVer${RESET}"
                $script:PythonCmd = "python3"
            } else {
                Warn "Python $pyVer found but 3.10+ required"
                $script:NeedPython = $true
            }
        } catch {
            $script:NeedPython = $true
        }
    } else {
        Warn "Python not found — will install"
        $script:NeedPython = $true
    }

    # pip
    $pipCmd = if ($script:PythonCmd) { "$($script:PythonCmd) -m pip" } else { "pip" }
    try {
        $pipVer = (& $script:PythonCmd -m pip --version 2>&1) -split ' ' | Select-Object -Index 1
        Success "pip ${DIM}$pipVer${RESET}"
    } catch {
        Warn "pip not found"
        $script:NeedPip = $true
    }

    Blank
    Progress 2 5 "System check complete"
}

# ═══════════════════════════════════════════════════════════════
#  Step 2: Install Dependencies
# ═══════════════════════════════════════════════════════════════

function Step-InstallDeps {
    Step "Install Dependencies"
    Progress 3 5 "Installing dependencies"

    # Install Git if needed
    if ($script:NeedGit) {
        Info "Installing Git..."
        try {
            winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            Success "Git installed (restart PowerShell if not found)"
        } catch {
            Warn "Could not install Git automatically"
            Info "Download from: ${CYAN}https://git-scm.com/download/win${RESET}"
            $continue = Ask "Continue anyway? [y/N]" "N"
            if ($continue -ne "y" -and $continue -ne "Y") { exit 1 }
        }
    }

    # Install Python if needed
    if ($script:NeedPython) {
        Info "Installing Python 3.12..."
        try {
            winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            Success "Python installed (restart PowerShell if not found)"
            $script:PythonCmd = "python"
        } catch {
            Warn "Could not install Python automatically"
            Info "Download from: ${CYAN}https://www.python.org/downloads/${RESET}"
            Info "Check 'Add Python to PATH' during installation"
            $continue = Ask "Continue anyway? [y/N]" "N"
            if ($continue -ne "y" -and $continue -ne "Y") { exit 1 }
        }
    }

    Blank

    # Clone project
    $script:InstallDir = Join-Path $env:USERPROFILE "ritual-sovereign-agent-guide"

    if (Test-Path $script:InstallDir) {
        Warn "Project already exists at ${WHITE}$($script:InstallDir)${RESET}"
        Blank
        $choice = Pick "What to do?" @(
            @{Name="Update and continue"; Desc="Pull latest changes and continue setup"},
            @{Name="Use existing"; Desc="Skip download, use current files"},
            @{Name="Delete and reclone"; Desc="Remove and download fresh copy"}
        )
        Blank

        switch ($choice) {
            1 {
                Set-Location $script:InstallDir
                git pull origin master 2>&1 | Out-Null
                Success "Updated to latest"
            }
            2 {
                Set-Location $script:InstallDir
                Success "Using existing files"
            }
            3 {
                Remove-Item -Recurse -Force $script:InstallDir
                git clone --quiet https://github.com/frianowzki/ritual-sovereign-agent-guide.git $script:InstallDir 2>&1 | Out-Null
                Set-Location $script:InstallDir
                Success "Fresh clone"
            }
        }
    } else {
        Info "Downloading project..."
        git clone --quiet https://github.com/frianowzki/ritual-sovereign-agent-guide.git $script:InstallDir 2>&1 | Out-Null
        Set-Location $script:InstallDir
        Success "Downloaded to ${WHITE}$($script:InstallDir)${RESET}"
    }

    Blank

    # Python deps
    Info "Installing Python packages..."
    Blank

    # Create venv
    try {
        & $script:PythonCmd -m venv (Join-Path $script:InstallDir "venv") 2>&1 | Out-Null
        $venvActivate = Join-Path $script:InstallDir "venv\Scripts\Activate.ps1"
        . $venvActivate
        Success "Virtual environment created"
        $script:VenvActive = $true
    } catch {
        Warn "Could not create venv, installing globally"
        $script:VenvActive = $false
    }

    # Install packages
    Write-Host "  ${DIM}  Installing web3...${RESET}" -NoNewline
    pip install web3 2>&1 | Out-Null
    Write-Host "`r  ${DIM}  Installing web3...${RESET}     ${GREEN}`u{2713}${RESET} web3"

    Write-Host "  ${DIM}  Installing eciespy...${RESET}" -NoNewline
    try {
        pip install eciespy 2>&1 | Out-Null
        Write-Host "`r  ${DIM}  Installing eciespy...${RESET}   ${GREEN}`u{2713}${RESET} eciespy"
    } catch {
        Write-Host ""
        Warn "eciespy install failed — trying alternative..."
        try {
            pip install eciespy --no-build-isolation 2>&1 | Out-Null
            Write-Host "  ${DIM}  Installing eciespy...${RESET}   ${GREEN}`u{2713}${RESET} eciespy (alternative)"
        } catch {
            Error "Could not install eciespy"
            Info "Try installing Visual Studio Build Tools:"
            Info "  ${CYAN}https://visualstudio.microsoft.com/visual-cpp-build-tools/${RESET}"
            Info "Then re-run this installer"
            exit 1
        }
    }

    Write-Host "  ${DIM}  Installing eth-abi...${RESET}" -NoNewline
    pip install eth-abi 2>&1 | Out-Null
    Write-Host "`r  ${DIM}  Installing eth-abi...${RESET}   ${GREEN}`u{2713}${RESET} eth-abi"

    Blank
    Success "All Python dependencies installed"
    Progress 4 5 "Dependencies ready"
}

# ═══════════════════════════════════════════════════════════════
#  Step 3: Blockchain Configuration
# ═══════════════════════════════════════════════════════════════

function Step-Blockchain {
    Step "Blockchain Configuration"

    Subbox "Ritual Chain Details"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BULLET} Chain ID:    ${WHITE}1979${RESET}"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BULLET} RPC:         ${WHITE}https://rpc.ritualfoundation.org${RESET}"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BULLET} Explorer:    ${WHITE}https://explorer.ritualfoundation.org${RESET}"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BULLET} Block time:  ${WHITE}~350ms${RESET}"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BULLET} Gas type:    ${WHITE}EIP-1559 (type 0x02)${RESET}"
    Write-Host "  ${DIM}$([char]0x255A)$([string]::new([char]0x2550, 56))$([char]0x255D)${RESET}"
    Blank

    Info "Your wallet's ${WHITE}private key${RESET} is needed to deploy contracts."
    Warn "Stored locally in ${WHITE}.env${RESET} — ${RED}never shared or uploaded${RESET}"
    Blank

    while ($true) {
        $script:PrivateKey = AskSecret "Enter your private key (0x-prefixed)"
        if ($script:PrivateKey -match '^0x[a-fA-F0-9]{64}$') {
            Success "Valid private key format"
            try {
                $addr = & $script:PythonCmd -c "from eth_account import Account; print(Account.from_key('$($script:PrivateKey)').address)" 2>&1
                if ($addr) { Success "Wallet: ${WHITE}$addr${RESET}" }
            } catch {}
            break
        } elseif (-not $script:PrivateKey) {
            Error "Private key cannot be empty"
        } else {
            Error "Invalid format. Must be 0x + 64 hex characters (66 total)"
        }
    }
    Blank
}

# ═══════════════════════════════════════════════════════════════
#  Step 4: LLM Provider & Model
# ═══════════════════════════════════════════════════════════════

function Step-LLM {
    Step "LLM Provider"

    Info "The LLM is the brain of your agent — it processes your prompt"
    Info "and generates responses every time the agent wakes up."
    Blank

    $providerChoice = Pick "Select your LLM provider:" @(
        @{Name="OpenRouter"; Desc="Cheapest. Access to 100+ models. Recommended for beginners."},
        @{Name="OpenAI"; Desc="GPT-4o and GPT-4o-mini. Best for structured tasks."},
        @{Name="Anthropic"; Desc="Claude Sonnet 4.5 and Haiku 4.5. Best reasoning."},
        @{Name="Google Gemini"; Desc="Gemini 2.5 Flash/Pro. Free tier available."}
    )
    Blank

    switch ($providerChoice) {
        1 {
            $script:LlmProvider = "openrouter"
            $script:KeyName = "OPENROUTER_API_KEY"
            $script:KeyUrl = "https://openrouter.ai/keys"
            $script:KeyPrefix = "sk-or-v1-"

            Info "OpenRouter gives you access to models from ${WHITE}all providers${RESET}"
            Info "through a single API key. Great for experimentation."
            Blank

            $modelChoice = Pick "Select a model:" @(
                @{Name="Gemini 2.5 Flash"; Desc="Fast, cheap (~`$0.01/run). Best value. Recommended."},
                @{Name="Gemini 2.5 Pro"; Desc="Best quality Google model. More expensive (~`$0.05/run)."},
                @{Name="Claude Sonnet 4.5 (via OR)"; Desc="Best reasoning model. ~`$0.03/run."},
                @{Name="GPT-4o Mini (via OR)"; Desc="Fast OpenAI model. ~`$0.01/run."},
                @{Name="Llama 4 Maverick"; Desc="Open source. FREE on OpenRouter."},
                @{Name="DeepSeek V3"; Desc="Open source. FREE on OpenRouter. Good quality."}
            )

            $models = @("google/gemini-2.5-flash", "google/gemini-2.5-pro", "anthropic/claude-sonnet-4-5-20250929", "openai/gpt-4o-mini", "meta-llama/llama-4-maverick", "deepseek/deepseek-chat-v3-0324")
            $script:Model = $models[$modelChoice - 1]
        }
        2 {
            $script:LlmProvider = "openai"
            $script:KeyName = "OPENAI_API_KEY"
            $script:KeyUrl = "https://platform.openai.com/api-keys"
            $script:KeyPrefix = "sk-"

            $modelChoice = Pick "Select a model:" @(
                @{Name="GPT-4o Mini"; Desc="Fast, cheap (`$0.15/M input). Recommended."},
                @{Name="GPT-4o"; Desc="Best quality OpenAI model (`$2.50/M input)."},
                @{Name="GPT-4.1 Mini"; Desc="Latest mini model, improved reasoning."},
                @{Name="o3-mini"; Desc="Reasoning model. Best for complex analysis."}
            )

            $models = @("gpt-4o-mini", "gpt-4o", "gpt-4.1-mini", "o3-mini")
            $script:Model = $models[$modelChoice - 1]
        }
        3 {
            $script:LlmProvider = "anthropic"
            $script:KeyName = "ANTHROPIC_API_KEY"
            $script:KeyUrl = "https://console.anthropic.com/settings/keys"
            $script:KeyPrefix = "sk-ant-"

            $modelChoice = Pick "Select a model:" @(
                @{Name="Claude Sonnet 4.5"; Desc="Best balance of speed, quality, and cost. Recommended."},
                @{Name="Claude Haiku 4.5"; Desc="Fastest, cheapest. Good for simple tasks."},
                @{Name="Claude Opus 4"; Desc="Best reasoning. Most expensive."}
            )

            $models = @("claude-sonnet-4-5-20250929", "claude-haiku-4-5-20250929", "claude-opus-4-20250514")
            $script:Model = $models[$modelChoice - 1]
        }
        4 {
            $script:LlmProvider = "gemini"
            $script:KeyName = "GEMINI_API_KEY"
            $script:KeyUrl = "https://aistudio.google.com/apikey"
            $script:KeyPrefix = ""

            $modelChoice = Pick "Select a model:" @(
                @{Name="Gemini 2.5 Flash"; Desc="Fast, free tier available. Recommended."},
                @{Name="Gemini 2.5 Pro"; Desc="Best quality, higher cost."},
                @{Name="Gemini 2.0 Flash"; Desc="Previous gen, very fast, very cheap."}
            )

            $models = @("gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash")
            $script:Model = $models[$modelChoice - 1]
        }
    }

    Blank
    Success "Provider: ${WHITE}$($script:LlmProvider)${RESET}"
    Success "Model: ${WHITE}$($script:Model)${RESET}"
    Blank

    # API Key
    Divider
    Info "Get your API key at: ${CYAN}$($script:KeyUrl)${RESET}"
    Info "The key is used to authenticate with the LLM provider."
    Blank

    while ($true) {
        $script:ApiKey = AskSecret "Enter $($script:KeyName)"
        if (-not $script:ApiKey) {
            Error "API key cannot be empty"
        } elseif ($script:ApiKey.Length -lt 8) {
            Error "API key seems too short (expected 20+ characters)"
        } elseif ($script:KeyPrefix -and -not $script:ApiKey.StartsWith($script:KeyPrefix)) {
            Warn "Key usually starts with '$($script:KeyPrefix)' — continue anyway?"
            $confirm = Ask "[y/N]" "N"
            if ($confirm -eq "y" -or $confirm -eq "Y") {
                Success "API key saved"
                break
            }
        } else {
            Success "API key saved"
            break
        }
    }
    Blank
}

# ═══════════════════════════════════════════════════════════════
#  Step 5: HuggingFace Setup
# ═══════════════════════════════════════════════════════════════

function Step-HuggingFace {
    Step "HuggingFace Setup"

    Info "HuggingFace stores your agent's ${WHITE}conversation history${RESET}"
    Info "and ${WHITE}artifacts${RESET} (outputs, logs, etc.)."
    Blank

    Subbox "Setup Guide"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BOLD}1.${RESET} Go to ${CYAN}https://huggingface.co${RESET} and sign up (free)"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BOLD}2.${RESET} Go to ${CYAN}Settings > Access Tokens${RESET}"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BOLD}3.${RESET} Click ${WHITE}New token${RESET} -> select ${RED}Write${RESET} access ${RED}(REQUIRED)${RESET}"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BOLD}4.${RESET} Copy the token (starts with ${WHITE}hf_${RESET})"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BOLD}5.${RESET} Go to ${CYAN}New Dataset${RESET} -> create one (e.g., ${WHITE}yourname/agent-data${RESET})"
    Write-Host "  ${DIM}$([char]0x255A)$([string]::new([char]0x2550, 56))$([char]0x255D)${RESET}"
    Blank

    while ($true) {
        $script:HfToken = AskSecret "HuggingFace token (hf_...)"
        if ($script:HfToken -match '^hf_') {
            Success "Token saved"
            break
        } elseif (-not $script:HfToken) {
            Error "Token cannot be empty"
        } else {
            Error "Token should start with 'hf_'"
        }
    }
    Blank

    Info "Dataset format: ${WHITE}username/repo-name${RESET}"
    Info "Example: ${WHITE}myname/sovereign-agent-data${RESET}"
    Blank

    while ($true) {
        $script:HfRepo = Ask "HuggingFace dataset ID"
        if ($script:HfRepo -match '/' -and $script:HfRepo.Length -gt 3) {
            Success "Dataset: ${WHITE}$($script:HfRepo)${RESET}"
            break
        } elseif (-not $script:HfRepo) {
            Error "Dataset ID cannot be empty"
        } else {
            Error "Must be in format: username/repo-name"
        }
    }
    Blank
}

# ═══════════════════════════════════════════════════════════════
#  Step 6: Agent Prompt
# ═══════════════════════════════════════════════════════════════

function Step-Prompt {
    Step "Agent Prompt"

    Info "The prompt defines ${WHITE}what your agent does${RESET} every time it wakes up."
    Info "You can change it later with ${WHITE}reconfigure.py${RESET}."
    Blank

    $promptChoice = Pick "Select a prompt template:" @(
        @{Name="Default Analytics"; Desc="DeFi market analysis. Good starting point."},
        @{Name="Market Monitor"; Desc="Price tracking with buy/sell signals."},
        @{Name="Research Agent"; Desc="Web research and news summarization."},
        @{Name="On-Chain Watcher"; Desc="Monitors Ritual Chain transactions."},
        @{Name="Custom"; Desc="Write your own prompt from scratch."}
    )
    Blank

    switch ($promptChoice) {
        1 {
            $script:AgentPrompt = @"
You are a sovereign AI agent on Ritual Chain. Your task is to analyze on-chain data and provide actionable insights for DeFi builders.

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

Be concise. Focus on signal over noise.
"@
            Success "Template: ${WHITE}Default Analytics${RESET}"
        }
        2 {
            $script:AgentPrompt = @"
You are a market monitoring agent on Ritual Chain. Your task is to track cryptocurrency prices and identify trading opportunities.

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

Be data-driven. No speculation without evidence.
"@
            Success "Template: ${WHITE}Market Monitor${RESET}"
        }
        3 {
            $script:AgentPrompt = @"
You are a research agent on Ritual Chain. Your task is to gather and summarize information about blockchain and DeFi developments.

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

Focus on actionable intelligence. Quality over quantity.
"@
            Success "Template: ${WHITE}Research Agent${RESET}"
        }
        4 {
            $script:AgentPrompt = @"
You are an on-chain watcher on Ritual Chain. Your task is to monitor blockchain transactions and detect unusual activity.

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

Alert level: Green (normal), Yellow (watch), Red (concerning).
"@
            Success "Template: ${WHITE}On-Chain Watcher${RESET}"
        }
        5 {
            Info "Enter your custom prompt below."
            Info "Be specific about what your agent should do."
            Blank
            $script:AgentPrompt = Ask "Your prompt"
            if (-not $script:AgentPrompt) {
                Warn "Empty prompt, using default template"
                $script:AgentPrompt = ""
            } else {
                Success "Custom prompt saved ($($script:AgentPrompt.Length) chars)"
            }
        }
    }
    Blank
}

# ═══════════════════════════════════════════════════════════════
#  Step 7: Deployment Configuration
# ═══════════════════════════════════════════════════════════════

function Step-Config {
    Step "Deployment Configuration"

    Info "A ${WHITE}unique salt${RESET} generates a deterministic harness address."
    Info "Change this if deploying multiple agents."
    Blank
    $script:Salt = Ask "Unique salt" "my-sovereign-agent"
    Success "Salt: ${WHITE}$($script:Salt)${RESET}"
    Blank

    Info "The ${WHITE}runtime type${RESET} determines which executor harness is used."
    Blank
    $cliChoice = Pick "Agent runtime:" @(
        @{Name="Crush (CLI Type 5)"; Desc="Default runtime. Recommended. Stable and well-tested."},
        @{Name="ZeroClaw (CLI Type 6)"; Desc="Alternative runtime. Experimental."}
    )
    $script:CliType = $cliChoice + 4
    Blank

    Info "How often your agent wakes up to execute its task."
    Info "Lower frequency = more data, higher cost."
    Blank

    $freqChoice = Pick "Execution frequency:" @(
        @{Name="~12 minutes (2000 blocks)"; Desc="Very frequent. Good for real-time monitoring. Higher cost."},
        @{Name="~29 minutes (5000 blocks)"; Desc="Balanced. Good for most tasks. Recommended."},
        @{Name="~58 minutes (10000 blocks)"; Desc="Hourly. Lower cost, good for periodic summaries."},
        @{Name="~2.9 hours (30000 blocks)"; Desc="Every few hours. Low cost, good for daily digests."},
        @{Name="~8.4 hours (86400 blocks)"; Desc="Twice daily. Lowest cost, good for daily reports."}
    )

    $freqs = @(2000, 5000, 10000, 30000, 86400)
    $script:Frequency = $freqs[$freqChoice - 1]
    $script:FreqMin = [math]::Round($script:Frequency * 0.35 / 60, 1)
    Blank
    Success "Frequency: every ${WHITE}$($script:Frequency)${RESET} blocks (~$($script:FreqMin) min)"
    Blank

    Info "RITUAL to deposit into your harness's ${WHITE}RitualWallet${RESET}."
    Info "This pays for on-chain gas (~0.002-0.005 RITUAL per heartbeat)."
    Info "TEE execution cost is paid by the executor, ${GREEN}not you${RESET}."
    Blank

    $script:FundAmount = Ask "Fund amount (RITUAL)" "0.1"

    $script:Heartbeats = [math]::Floor([double]$script:FundAmount / 0.003)
    $script:Days = [math]::Floor($script:Heartbeats * $script:Frequency * 0.35 / 86400)

    Blank
    Subbox "Cost Estimate"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BULLET} Fund amount:     ${WHITE}$($script:FundAmount) RITUAL${RESET}"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BULLET} Est. heartbeats: ${WHITE}~$($script:Heartbeats)${RESET}"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BULLET} Est. runtime:    ${WHITE}~$($script:Days) days${RESET}"
    Write-Host "  ${DIM}$([char]0x2551)${RESET}  ${BULLET} Per heartbeat:   ${WHITE}~0.003 RITUAL${RESET} (on-chain gas)"
    Write-Host "  ${DIM}$([char]0x255A)$([string]::new([char]0x2550, 56))$([char]0x255D)${RESET}"
    Blank
}

# ═══════════════════════════════════════════════════════════════
#  Step 8: Generate .env
# ═══════════════════════════════════════════════════════════════

function Step-Generate {
    Step "Generate Configuration"

    $envFile = Join-Path $script:InstallDir ".env"

    $envContent = @"
# ═══════════════════════════════════════════════════════════════
#  Ritual Sovereign Agent — Generated by install.ps1
#  https://github.com/frianowzki/ritual-sovereign-agent-guide
# ═══════════════════════════════════════════════════════════════

# ── Blockchain ─────────────────────────────────────────────────
PRIVATE_KEY=$($script:PrivateKey)
RPC_URL=https://rpc.ritualfoundation.org

# ── LLM Provider ──────────────────────────────────────────────
LLM_PROVIDER=$($script:LlmProvider)
$($script:KeyName)=$($script:ApiKey)
MODEL=$($script:Model)

# ── HuggingFace ───────────────────────────────────────────────
HF_TOKEN=$($script:HfToken)
HF_REPO_ID=$($script:HfRepo)

# ── Agent Prompt ──────────────────────────────────────────────
AGENT_PROMPT=$($script:AgentPrompt)

# ── Deployment Config ─────────────────────────────────────────
SALT=$($script:Salt)
CLI_TYPE=$($script:CliType)
FREQUENCY=$($script:Frequency)
WINDOW_NUM_CALLS=5
ROLLOVER_THRESHOLD_BPS=5000
FUND_AMOUNT=$($script:FundAmount)
"@

    Set-Content -Path $envFile -Value $envContent -Encoding UTF8
    Success "Configuration saved to ${WHITE}$envFile${RESET}"

    Progress 5 5 "Configuration complete"
    Blank
}

# ═══════════════════════════════════════════════════════════════
#  Step 9: Review & Deploy
# ═══════════════════════════════════════════════════════════════

function Step-Review {
    Step "Review & Deploy"

    $maskedKey = "$($script:PrivateKey.Substring(0,6))...$($script:PrivateKey.Substring($script:PrivateKey.Length-4))"
    $maskedApi = "$($script:ApiKey.Substring(0,8))..."
    $maskedHf  = "$($script:HfToken.Substring(0,8))..."

    Write-Host "  ${BOLD}${WHITE}Configuration Summary${RESET}"
    Divider
    Write-Host "  ${BULLET} Wallet:          ${WHITE}$maskedKey${RESET}"
    Write-Host "  ${BULLET} Chain:           ${WHITE}Ritual Chain (ID 1979)${RESET}"
    Write-Host "  ${BULLET} Chain Type:      ${WHITE}EIP-1559 (type 0x02)${RESET}"
    Blank
    Write-Host "  ${BULLET} LLM Provider:    ${WHITE}$($script:LlmProvider)${RESET}"
    Write-Host "  ${BULLET} API Key:         ${WHITE}$($script:KeyName)${RESET} (${DIM}$maskedApi${RESET})"
    Write-Host "  ${BULLET} Model:           ${WHITE}$($script:Model)${RESET}"
    Blank
    Write-Host "  ${BULLET} HuggingFace:     ${WHITE}$($script:HfRepo)${RESET}"
    Write-Host "  ${BULLET} HF Token:        ${DIM}$maskedHf${RESET}"
    Blank
    Write-Host "  ${BULLET} Salt:            ${WHITE}$($script:Salt)${RESET}"
    Write-Host "  ${BULLET} CLI Type:        ${WHITE}$($script:CliType)${RESET}"
    Write-Host "  ${BULLET} Frequency:       ${WHITE}every $($script:Frequency) blocks${RESET} (~$($script:FreqMin) min)"
    Write-Host "  ${BULLET} Window Calls:    ${WHITE}5${RESET}"
    Write-Host "  ${BULLET} Fund Amount:     ${WHITE}$($script:FundAmount) RITUAL${RESET}"
    Blank
    Write-Host "  ${BULLET} Est. Runtime:    ${GREEN}~$($script:Days) days${RESET}"
    Write-Host "  ${BULLET} Est. Heartbeats: ${GREEN}~$($script:Heartbeats)${RESET}"
    Divider
    Blank

    $deployChoice = Pick "What would you like to do?" @(
        @{Name="Deploy now"; Desc="Run the deployment script immediately. Agent goes live on-chain."},
        @{Name="Save config only"; Desc="Save .env file. Deploy later manually."},
        @{Name="Edit config"; Desc="Go back and modify settings before deploying."}
    )
    Blank

    switch ($deployChoice) {
        1 {
            Info "Starting deployment..."
            Blank

            if ($script:VenvActive) {
                $venvActivate = Join-Path $script:InstallDir "venv\Scripts\Activate.ps1"
                . $venvActivate 2>&1 | Out-Null
            }

            $deployScript = Join-Path $script:InstallDir "scripts\deploy.py"
            try {
                & $script:PythonCmd $deployScript
                Blank
                Write-Host "${GREEN}${BOLD}"
                Write-Host "    $([char]0x2554)$([string]::new([char]0x2550, 58))$([char]0x2557)"
                Write-Host "    $([char]0x2551)                                                          $([char]0x2551)"
                Write-Host "    $([char]0x2551)           $([char]0x25C6)  SOVEREIGN AGENT DEPLOYED!  $([char]0x25C6)               $([char]0x2551)"
                Write-Host "    $([char]0x2551)                                                          $([char]0x2551)"
                Write-Host "    $([char]0x2551)     Your agent is now live on Ritual Chain 1979.         $([char]0x2551)"
                Write-Host "    $([char]0x2551)                                                          $([char]0x2551)"
                Write-Host "    $([char]0x2551)              Created by @frianowzki                      $([char]0x2551)"
                Write-Host "    $([char]0x2551)           github.com/frianowzki                          $([char]0x2551)"
                Write-Host "    $([char]0x2551)                                                          $([char]0x2551)"
                Write-Host "    $([char]0x255A)$([string]::new([char]0x2550, 58))$([char]0x255D)"
                Write-Host "${RESET}"
            } catch {
                Blank
                Error "Deployment failed!"
                Info "Check the error messages above and try again."
                Info "Try again with:"
                Write-Host "    ${CYAN}cd ~\ritual-sovereign-agent-guide${RESET}"
                Write-Host "    ${CYAN}venv\Scripts\Activate.ps1${RESET}"
                Write-Host "    ${CYAN}python scripts\deploy.py${RESET}"
            }
        }
        2 {
            Info "Configuration saved to ${WHITE}$($script:InstallDir)\.env${RESET}"
            Blank
            Info "Deploy later with:"
            Write-Host "    ${CYAN}cd ~\ritual-sovereign-agent-guide${RESET}"
            Write-Host "    ${CYAN}venv\Scripts\Activate.ps1${RESET}"
            Write-Host "    ${CYAN}python scripts\deploy.py${RESET}"
        }
        3 {
            Info "Going back to edit config..."
            Step-Config
            Step-Generate
            Step-Review
            return
        }
    }

    Blank
    Info "Useful commands:"
    Write-Host "    ${CYAN}cd ~\ritual-sovereign-agent-guide${RESET}"
    Write-Host "    ${CYAN}python scripts\check-status.py --harness 0xYourAddr${RESET}   ${DIM}# Check status${RESET}"
    Write-Host "    ${CYAN}python scripts\reconfigure.py --harness 0xYourAddr${RESET}   ${DIM}# Reconfigure${RESET}"
    Blank
    Info "Explorer:  ${CYAN}https://explorer.ritualfoundation.org/agents?kind=sovereign${RESET}"
    Info "Docs:      ${CYAN}https://github.com/frianowzki/ritual-sovereign-agent-guide${RESET}"
    Blank
}

# ═══════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════

function Main {
    Clear-Host
    Banner

    Info "Platform: ${WHITE}Windows ${RESET}($([Environment]::OSVersion.Version))"
    Info "This installer will guide you through setting up a"
    Info "Sovereign Agent on Ritual Chain step by step."
    Blank
    Info "You'll need:"
    Write-Host "    ${DIM}${BULLET} A wallet private key with >= 0.2 RITUAL${RESET}"
    Write-Host "    ${DIM}${BULLET} An LLM API key (OpenRouter, OpenAI, Anthropic, or Gemini)${RESET}"
    Write-Host "    ${DIM}${BULLET} A HuggingFace account (free)${RESET}"
    Blank

    $go = Ask "Ready to start? [Y/n]" "Y"
    if ($go -ne "Y" -and $go -ne "y" -and $go -ne "") {
        Info "Goodbye!"
        exit 0
    }

    Blank
    Step-System
    Step-InstallDeps
    Step-Blockchain
    Step-LLM
    Step-HuggingFace
    Step-Prompt
    Step-Config
    Step-Generate
    Step-Review
}

if ($Help) {
    Write-Host "Ritual Sovereign Agent — Windows PowerShell Installer"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File install.ps1"
    Write-Host ""
    Write-Host "One-liner:"
    Write-Host "  irm https://raw.githubusercontent.com/frianowzki/ritual-sovereign-agent-guide/master/install.ps1 | iex"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -SkipDeploy    Save config without deploying"
    Write-Host "  -Help          Show this help"
    exit 0
}

Main
