<div align="center">

# ◆ Ritual Sovereign Agent

### Factory Harness Deployment Guide

[![Chain](https://img.shields.io/badge/Chain-Ritual%201979-purple?style=flat-square)](https://explorer.ritualfoundation.org)
[![Python](https://img.shields.io/badge/Python-3.10+-blue?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

Deploy a **production-grade Sovereign Agent** on Ritual Chain using the factory-backed harness pattern.

*Autonomous AI agents that run on-chain, execute in TEE, and deliver results via async callbacks.*

<br/>

```
Your EOA ──deployHarness──▶ Factory ──CREATE3──▶ Harness Contract
   │
   │  configureFundAndStart
   ▼
Harness ──schedule()──▶ Scheduler
   │
   │  wakeUp() every 2000 blocks
   ▼
Precompile 0x080C ──TEE──▶ AI Model (Gemini / GPT / Claude)
   │
   │  Phase 2 callback
   ▼
Harness ◀──onSovereignAgentResult── Executor
```

<br/>

[Quick Start](#quick-start) · [What It Does](#what-it-does) · [Installer Walkthrough](#installer-walkthrough) · [Manual Setup](#manual-setup) · [Deploy](#deployment) · [Custom Prompts](#custom-prompts) · [Monitoring](#monitoring--management) · [Troubleshooting](#troubleshooting)

</div>

---

## Table of Contents

- [Quick Start](#quick-start)
- [What You'll Build](#what-youll-build)
- [Prerequisites](#prerequisites)
- [Installer Walkthrough](#installer-walkthrough)
  - [Step 1: Launch Installer](#step-1-launch-installer)
  - [Step 2: System Check](#step-2-system-check)
  - [Step 3: Install Dependencies](#step-3-install-dependencies)
  - [Step 4: Blockchain Setup](#step-4-blockchain-setup)
  - [Step 5: LLM Provider](#step-5-llm-provider)
  - [Step 6: HuggingFace](#step-6-huggingface)
  - [Step 7: Agent Prompt](#step-7-agent-prompt)
  - [Step 8: Deployment Config](#step-8-deployment-config)
  - [Step 9: Review & Deploy](#step-9-review--deploy)
- [Manual Setup](#manual-setup)
  - [Platform-Specific Instructions](#platform-specific-instructions)
  - [Environment Configuration](#environment-configuration)
- [Deployment](#deployment)
  - [Deploy Script](#deploy-script)
  - [Verify on Explorer](#verify-on-explorer)
- [Custom Prompts](#custom-prompts)
- [Reconfiguration](#reconfiguration)
- [Monitoring & Management](#monitoring--management)
- [Architecture](#architecture)
- [Cost Breakdown](#cost-breakdown)
- [Troubleshooting](#troubleshooting)
- [File Structure](#file-structure)
- [References](#references)

---

## Quick Start

**One command — the interactive installer does everything:**

```bash
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python3 install.py
```

The installer guides you through:
1. System check (Python, pip, git)
2. Dependency installation (web3, eciespy, eth-abi)
3. Private key input + validation
4. LLM provider selection (OpenRouter / OpenAI / Anthropic / Gemini)
5. API key input + model selection
6. HuggingFace token + dataset setup
7. Agent prompt (choose template or write custom)
8. Deployment config (frequency, funding, salt)
9. Review summary
10. One-click deploy

No manual `.env` editing needed.

---

## What You'll Build

A **Sovereign Agent** — an on-chain AI agent that:

- ◆ Runs autonomously on a rolling schedule (~every 11.7 min)
- ◆ Calls the `0x080C` precompile via a factory-deployed harness
- ◆ Uses **TEE-verified executors** for off-chain AI inference
- ◆ Delivers results via async Phase 2 callbacks
- ◆ Stores conversation history on **HuggingFace**
- ◆ Supports any LLM provider (OpenRouter, OpenAI, Anthropic, Gemini)

The agent appears on the [Ritual Explorer](https://explorer.ritualfoundation.org/agents?kind=sovereign) as **Sovereign + Monitored**.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| **Python 3.10+** | [python.org](https://www.python.org/downloads/) |
| **Git** | [git-scm.com](https://git-scm.com) |
| **Ritual Chain wallet** | With ≥ 0.2 RITUAL (testnet) |
| **LLM API key** | Any of: OpenRouter, OpenAI, Anthropic, or Gemini |
| **HuggingFace account** | Free at [huggingface.co](https://huggingface.co) |

---

## Installer Walkthrough

The `install.py` script is an interactive wizard that walks you through every step. Here's what to expect:

### Step 1: Launch Installer

```bash
python3 install.py
```

```
  ◆ ═══════════════════════════════════════════════════════ ◆
  ║                                                       ║
  ║        Ritual Sovereign Agent Installer v1.0.0        ║
  ║                                                       ║
  ║   Deploy autonomous AI agents on Ritual Chain 1979    ║
  ║                                                       ║
  ◆ ═══════════════════════════════════════════════════════ ◆
```

### Step 2: System Check

The installer verifies your environment:

```
  ── System Check ──────────────────────────────────────────

  ℹ  OS: Linux-6.8.0-x86_64-with-glibc2.39
  ✔  Python 3.12.3
  ✔  Git: git version 2.43.0
  ✔  pip: 24.0
```

- **Linux**: Ubuntu, Fedora, Arch — all supported
- **macOS**: Intel + Apple Silicon (M1/M2/M3)
- **Windows**: Native PowerShell or WSL

### Step 3: Install Dependencies

Auto-installs required Python packages:

```
  ── Dependencies ──────────────────────────────────────────

  ℹ  Installing: web3, eciespy, eth-abi
  ✔  web3 already installed
  ✔  eciespy already installed
  ✔  eth-abi already installed
```

> **macOS users**: If `eciespy` fails, the installer will suggest `brew install rust`.

### Step 4: Blockchain Setup

Enter your wallet private key:

```
  ── Blockchain Configuration ──────────────────────────────

  ℹ  Chain: Ritual Chain (ID 1979)
  ℹ  RPC: https://rpc.ritualfoundation.org
  ℹ  Explorer: https://explorer.ritualfoundation.org

  ?  Enter your private key (0x-prefixed) [hidden]: ****
  ✔  Wallet: 0x63C5341454f66a32553ce598e06861e11095d39c
```

The key is masked during input and auto-validates format.

### Step 5: LLM Provider

Choose your AI model provider:

```
  ── LLM Provider ──────────────────────────────────────────

  ?  Select your LLM provider:
  ▶ 1. OpenRouter — Cheapest, 100+ models, recommended
    2. OpenAI — GPT-4o, GPT-4o-mini
    3. Anthropic — Claude Sonnet 4.5, Claude Haiku 4.5
    4. Google — Gemini 2.5 Flash/Pro, free tier available

  ?  Select [1-4] [1]: 1
  ✔  Selected: OpenRouter
```

Then enter your API key and select a model:

```
  ℹ  Get your key at: https://openrouter.ai/keys

  ?  Enter your OPENROUTER_API_KEY [hidden]: ****
  ✔  API key saved

  ?  Select a model:
  ▶ 1. Gemini 2.5 Flash — Fast, cheap, good quality
    2. Gemini 2.5 Pro — Best quality, more expensive
    3. Claude Sonnet 4.5 (via OR) — Best reasoning
    4. GPT-4o Mini (via OR) — Fast, cheap
    5. Llama 4 Maverick — Open source, free on OR
    6. DeepSeek V3 — Free, good quality

  ?  Select [1-6] [1]: 1
  ✔  Selected: Gemini 2.5 Flash
```

### Step 6: HuggingFace

Set up conversation history storage:

```
  ── HuggingFace (Conversation History) ────────────────────

  ℹ  HuggingFace stores your agent's conversation history and artifacts.
  ℹ  Create token at: https://huggingface.co/settings/tokens
  ℹ  Create dataset at: https://huggingface.co/new-dataset

  ?  HuggingFace token (hf_...) [hidden]: ****
  ✔  Token saved

  ℹ  Dataset must be in format: username/repo-name
  ℹ  Example: myname/sovereign-agent-data

  ?  HuggingFace dataset ID: myname/agent-data
  ✔  Dataset: myname/agent-data
```

### Step 7: Agent Prompt

Choose what your agent does every time it wakes up:

```
  ── Agent Prompt ──────────────────────────────────────────

  ℹ  This is what your agent will do every time it wakes up.
  ℹ  You can always change it later with reconfigure.py.

  ?  Select a prompt template:
  ▶ 1. Default Analytics — DeFi analytics + market summary
    2. Market Monitor — Price tracking + trading signals
    3. Research Agent — Web research + news summarization
    4. Write Your Own — Enter a custom prompt

  ?  Select [1-4] [1]: 1
```

If you choose **Write Your Own**, you can type/paste your prompt directly:

```
  ℹ  Enter your prompt (press Enter twice to finish):
  > You are a DeFi monitoring agent...
  > Check RITUAL token price and analyze recent transactions...
  > 
  >
```

### Step 8: Deployment Config

Fine-tune your agent's behavior:

```
  ── Deployment Configuration ──────────────────────────────

  ?  Unique salt (for deterministic address) [my-sovereign-agent]: 
  ✔  Using default

  ?  Agent runtime:
  ▶ 1. Crush — Default runtime — recommended
    2. ZeroClaw — Alternative runtime

  ?  Select [1-2] [1]: 1
  ✔  Selected: Crush

  ?  Execution frequency:
  ▶ 1. ~12 min — Frequent — higher cost, more data
    2. ~29 min — Balanced — good for monitoring
    3. ~58 min — Hourly — lower cost
    4. ~2.9 hr — Every few hours — daily summary
    5. ~8.4 hr — Twice daily — low cost

  ?  Select [1-5] [2]: 2
  ✔  Selected: ~29 min

  ?  Calls per rolling window [5]: 5

  ℹ  RITUAL to deposit into your harness RitualWallet
  ℹ  This pays for on-chain gas (~0.002-0.005 per heartbeat)

  ?  Fund amount (RITUAL) [0.1]: 0.1

  ℹ  At 5000 blocks/call with 0.1 RITUAL:
  ✔  ~33 heartbeats
  ✔  ~16 days of operation
```

### Step 9: Review & Deploy

Review everything before deploying:

```
  ── Review Configuration ──────────────────────────────────

  Configuration Summary
  ──────────────────────────────────────────────────────────
  Wallet:          0x63C5...d39c
  Chain:           Ritual Chain (ID 1979)

  LLM Provider:    openrouter
  API Key:         OPENROUTER_API_KEY (sk-or-v1-...)
  Model:           google/gemini-2.5-flash

  HuggingFace:     myname/agent-data
  HF Token:        hf_abc12...

  Salt:            my-sovereign-agent
  CLI Type:        5
  Frequency:       every 5000 blocks (~29.2 min)
  Window Calls:    5
  Fund Amount:     0.1 RITUAL

  Est. Runtime:    ~16 days
  ──────────────────────────────────────────────────────────

  ?  Deploy now? [Y/n]: Y
```

After deployment, you'll see:

```
  ◆ ═══════════════════════════════════════════════════════ ◆
  ║                                                       ║
  ║              Sovereign Agent Deployed!                ║
  ║                                                       ║
  ◆ ═══════════════════════════════════════════════════════ ◆

  ℹ  Useful commands:

  Deploy:     python3 scripts/deploy.py
  Status:     python3 scripts/check-status.py --harness 0xYourAddr
  Reconfig:   python3 scripts/reconfigure.py --harness 0xYourAddr --prompt "New task"
  Explorer:   https://explorer.ritualfoundation.org/agents?kind=sovereign

  ℹ  Docs: https://github.com/frianowzki/ritual-sovereign-agent-guide
```

---

## Manual Setup

If you prefer to set up manually (or the installer doesn't work on your system):

### Platform-Specific Instructions

**Linux (Ubuntu / Debian):**
```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv git
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python3 -m venv venv
source venv/bin/activate
pip install web3 eciespy eth-abi
```

**Linux (Fedora / RHEL):**
```bash
sudo dnf install -y python3 python3-pip git
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python3 -m venv venv
source venv/bin/activate
pip install web3 eciespy eth-abi
```

**Linux (Arch):**
```bash
sudo pacman -S python python-pip git
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python3 -m venv venv
source venv/bin/activate
pip install web3 eciespy eth-abi
```

**macOS:**
```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install python git
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python3 -m venv venv
source venv/bin/activate
pip install web3 eciespy eth-abi
```

> **Apple Silicon (M1/M2/M3):** If `eciespy` fails, run `brew install rust` first.

**Windows (PowerShell):**

1. Install [Python 3.10+](https://www.python.org/downloads/) (check "Add to PATH")
2. Install [Git](https://git-scm.com/download/win)
3. Open PowerShell:

```powershell
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install web3 eciespy eth-abi
```

> If `Activate.ps1` is blocked: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

**Windows (WSL):**
```powershell
# In PowerShell (Admin)
wsl --install
# Restart, open Ubuntu from Start menu

# Inside WSL
sudo apt update && sudo apt install -y python3 python3-pip git
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python3 -m venv venv
source venv/bin/activate
pip install web3 eciespy eth-abi
```

> **Tip:** Use `python` (not `python3`) on Windows PowerShell. Use WSL if you can — it's more reliable for Web3 tooling.

---

### Environment Configuration

Copy the example and fill in your values:

```bash
cp .env.example .env
```

**LLM Providers** — choose one:

| Provider | Env Variable | Get Key |
|----------|-------------|---------|
| **OpenRouter** (recommended) | `OPENROUTER_API_KEY=sk-or-v1-...` | [openrouter.ai/keys](https://openrouter.ai/keys) |
| **OpenAI** | `OPENAI_API_KEY=sk-...` | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| **Anthropic** | `ANTHROPIC_API_KEY=sk-ant-...` | [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) |
| **Gemini** | `GEMINI_API_KEY=...` | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |

**HuggingFace:**
1. Create token at [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) (write access)
2. Create dataset at [huggingface.co/new-dataset](https://huggingface.co/new-dataset)
3. Set `HF_TOKEN=hf_...` and `HF_REPO_ID=username/repo-name`

**Full variable reference:**

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `PRIVATE_KEY` | ✅ | EOA private key (0x-prefixed) | — |
| `HF_TOKEN` | ✅ | HuggingFace write token | — |
| `HF_REPO_ID` | ✅ | HuggingFace dataset (`user/repo`) | — |
| `LLM_PROVIDER` | ✅ | `openrouter` / `openai` / `anthropic` / `gemini` | — |
| `*_API_KEY` | ✅ | API key for chosen provider | — |
| `RPC_URL` | — | Ritual Chain RPC | `https://rpc.ritualfoundation.org` |
| `MODEL` | — | LLM model identifier | Provider default |
| `AGENT_PROMPT` | — | Custom agent prompt (overrides template) | `templates/default-prompt.txt` |
| `SALT` | — | Unique salt for deterministic deploy | `my-sovereign-agent` |
| `CLI_TYPE` | — | Runtime type (5=Crush, 6=ZeroClaw) | `5` |
| `FREQUENCY` | — | Blocks between executions | `2000` (~11.7 min) |
| `WINDOW_NUM_CALLS` | — | Calls per rolling window | `5` |
| `ROLLOVER_THRESHOLD_BPS` | — | Rollover threshold (basis points) | `5000` (50%) |
| `FUND_AMOUNT` | — | RITUAL to fund harness | `0.1` |

---

## Deployment

### Deploy Script

```bash
python3 scripts/deploy.py
```

The script automatically:
1. Checks for pending async jobs (sender lock)
2. Predicts harness address via `predictHarness`
3. Deploys harness via `deployHarness` (3M gas)
4. Discovers TEE executor from registry
5. Encrypts LLM credentials with ECIES (12-byte nonce)
6. Builds 23-field `SovereignAgentParams`
7. Calls `configureFundAndStart` (5M gas)

**Expected output:**
```
Sender: 0x63C5...
Chain: 1979
Balance: 0.5432 RITUAL
Salt: my-sovereign-agent

✅ No pending jobs

Predicted harness: 0xEc87...

── Step 1: deployHarness ──
  tx: 0xabc...
  status: ✅ OK (gas 943627)
✅ Harness deployed: 0xEc87...

── Step 2: Build calldata ──
Executor: 0x1234...
Secrets encrypted (184 bytes)
Model: google/gemini-2.5-flash

── Step 3: configureFundAndStart ──
Funding: 0.1 RITUAL
  tx: 0xdef...
  status: ✅ OK (gas 3178666)

════════════════════════════════════════════════════════════
✅ SOVEREIGN AGENT DEPLOYED + CONFIGURED!
Harness: 0xEc87F4Cf6f1AD2fd47bfbB25b7FDAE093Fb6b097
Explorer: https://explorer.ritualfoundation.org/address/0xEc87...
Schedule: every 2000 blocks (~11.7 min)
Window: 5 calls per window
Funding: 0.1 RITUAL
Model: google/gemini-2.5-flash
════════════════════════════════════════════════════════════
```

### Verify on Explorer

1. Open your harness:
   ```
   https://explorer.ritualfoundation.org/address/0xYOUR_HARNESS
   ```

2. Check the Agents page:
   ```
   https://explorer.ritualfoundation.org/agents?kind=sovereign
   ```

3. Your agent should show as **Sovereign + Monitored** ✅

---

## Custom Prompts

Your agent's prompt defines what it does every time it wakes up.

### Writing Effective Prompts

```
◆ Good — specific task with clear output format
"You are a DeFi analytics agent. Fetch the top 10 altcoin prices from
CoinGecko API, calculate 24h change percentages, and identify the
biggest movers. Return a concise market summary with buy/sell signals."

◆ Good — on-chain monitoring
"You are Hive, a sovereign AI agent on Ritual Chain. Monitor RITUAL
token price, check recent transactions on the explorer, and provide
a brief market sentiment analysis. Focus on unusual activity."

◆ Bad — too vague
"Do something useful."
```

### Prompt Templates

Ready-made prompts in `templates/`:

| Template | Description | Best For |
|----------|-------------|----------|
| `default-prompt.txt` | General DeFi analytics | Getting started |
| `market-monitor.txt` | Price tracking + alerts | Traders |
| `research-agent.txt` | Web research + summarization | Researchers |

### Set via .env

```env
AGENT_PROMPT=You are a sovereign agent. Your task is to...
```

Or edit the template file directly:
```bash
nano templates/default-prompt.txt
```

---

## Reconfiguration

Update prompt, model, or funding on an existing harness:

```bash
# New prompt
python3 scripts/reconfigure.py --harness 0xYourHarness --prompt "New prompt here"

# New model
python3 scripts/reconfigure.py --harness 0xYourHarness --model gpt-4o

# Add funding
python3 scripts/reconfigure.py --harness 0xYourHarness --fund 0.05

# All together
python3 scripts/reconfigure.py --harness 0xYourHarness \
  --prompt "New task" \
  --model anthropic/claude-sonnet-4-5-20250929 \
  --fund 0.1
```

---

## Monitoring & Management

### Check Status

```bash
python3 scripts/check-status.py --harness 0xYourHarnessAddress
```

### Cast Commands (requires [Foundry](https://book.getfoundry.sh/getting-started/installation))

```bash
# Is it configured?
cast call 0xYOUR_HARNESS "configured()(bool)" \
  --rpc-url https://rpc.ritualfoundation.org

# Wake mode (needs --from owner)
cast call 0xYOUR_HARNESS "wakeMode()(uint8)" \
  --from YOUR_EOA \
  --rpc-url https://rpc.ritualfoundation.org

# Schedule config
cast call 0xYOUR_HARNESS "scheduleConfig()(uint32,uint32,uint32,uint256,uint256,uint256)" \
  --from YOUR_EOA \
  --rpc-url https://rpc.ritualfoundation.org

# RitualWallet balance
cast call 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948 \
  "balanceOf(address)(uint256)" 0xYOUR_HARNESS \
  --rpc-url https://rpc.ritualfoundation.org
```

### Top-Up Funding

```bash
cast send 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948 \
  "deposit(uint256)" 100000000 \
  --value 0.1ether \
  --private-key $PRIVATE_KEY \
  --rpc-url https://rpc.ritualfoundation.org
```

---

## Architecture

### System Contracts

| Contract | Address | Purpose |
|----------|---------|---------|
| SovereignAgentFactory | `0x9dC4...304` | Deploys harnesses via CREATE3 |
| TEEServiceRegistry | `0x9644...47F` | Executor discovery + validation |
| AsyncJobTracker | `0xC069...EF5` | Job lifecycle + sender locks |
| AsyncDelivery | `0x5A16...9F6` | Phase 2 callback delivery |
| RitualWallet | `0x532F...948` | Fee escrow + lock management |
| Scheduler | `0x56e7...58B` | Recurring execution triggers |

### Rolling Window Lifecycle

```
Window 1: [call1] [call2] [call3] [call4] [call5]
                                          ↑ 50% threshold
                                          Window 2 auto-scheduled
Window 2: [call1] [call2] [call3] [call4] [call5]
                                          ↑
                                          Window 3 auto-scheduled
                    ...continuous operation...
```

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `windowNumCalls` | 5 | 5 calls per window |
| `frequency` | 2000 | ~11.7 min between calls |
| `rolloverThresholdBps` | 5000 | Schedule next window at 50% |
| `rolloverRetryEveryCalls` | 1 | Retry scheduling every call |

---

## Cost Breakdown

| Step | Gas Used | Cost (~250 gwei) |
|------|----------|------------------|
| `deployHarness` | ~943k | ~0.005 RITUAL |
| `configureFundAndStart` | ~3.2M | ~0.016 RITUAL |
| Fund harness (deposit) | — | 0.1 RITUAL |
| **Total setup** | — | **~0.12 RITUAL** |
| Per heartbeat (on-chain) | ~200k | ~0.002 RITUAL |

> **0.1 RITUAL** funds ~50 heartbeats (~1 month at 1x/day, ~2 months at every-other-day).
>
> TEE execution cost is paid by the executor, **not your contract**.

---

## Troubleshooting

<details>
<summary><strong>◆ <code>DeploymentFailed()</code> (0x30116425)</strong></summary>

**Cause:** `deployHarness` gas limit too low (< 3M).
**Fix:** The script sets 3M by default. If calling manually:
```python
send_tx(w3, deploy_data, FACTORY, gas_limit=3_000_000)
```
</details>

<details>
<summary><strong>◆ <code>configureFundAndStart</code> reverts silently</strong></summary>

**Cause:** Gas limit too low (~3M). Actual usage: ~3.2M.
**Fix:** Set gas limit to 5,000,000.
</details>

<details>
<summary><strong>◆ ECIES silent failure</strong></summary>

**Cause:** Wrong nonce length (16 instead of 12).
**Fix:** Always set before encrypting:
```python
ECIES_CONFIG.symmetric_nonce_length = 12
```
</details>

<details>
<summary><strong>◆ <code>InvalidDeliveryTarget()</code></strong></summary>

**Cause:** `deliveryTarget` doesn't match predicted harness address.
**Fix:** Use `predictHarness()` result as delivery target, not the factory address.
</details>

<details>
<summary><strong>◆ Sender locked</strong></summary>

**Cause:** Another async job pending for your EOA.
**Check:**
```bash
cast call 0xC069FFCa0389f44eCA2C626e55491b0ab045AEF5 \
  "hasPendingJobForSender(address)(bool)" YOUR_ADDRESS \
  --rpc-url https://rpc.ritualfoundation.org
```
**Fix:** Wait for current job to settle, or use a different key.
</details>

<details>
<summary><strong>◆ <code>ModeNotSupported()</code> on <code>wakeMode()</code></strong></summary>

**Cause:** Function requires `msg.sender == owner`.
**Fix:** Use `--from OWNER_ADDRESS` when calling via cast.
</details>

<details>
<summary><strong>◆ <code>pip install eciespy</code> fails on macOS</strong></summary>

**Cause:** Missing Rust compiler for native extensions.
**Fix:**
```bash
brew install rust
pip install eciespy
```
</details>

<details>
<summary><strong>◆ PowerShell: script execution is blocked</strong></summary>

**Cause:** Windows default execution policy.
**Fix:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
</details>

---

## File Structure

```
ritual-sovereign-agent-guide/
│
├── README.md                          You are here
├── install.py                         Interactive one-script installer
├── .env.example                       Environment template
├── .gitignore                         Git ignore rules
│
├── scripts/
│   ├── deploy.py                      Full deployment (predict → deploy → configure)
│   ├── reconfigure.py                 Update existing harness
│   └── check-status.py                Check harness status + balance
│
├── templates/
│   ├── default-prompt.txt             General DeFi analytics prompt
│   ├── market-monitor.txt             Price tracking + alerts prompt
│   └── research-agent.txt             Web research + summarization prompt
│
└── references/
    └── factory-harness-deployment.md  Technical reference + pitfalls
```

---

## References

- [Ritual dApp Skills](https://github.com/ritual-foundation/ritual-dapp-skills) — Official skills + examples
- [Ritual Docs](https://docs.ritualfoundation.org) — Chain documentation
- [Ritual Explorer](https://explorer.ritualfoundation.org) — Block explorer
- [Ritual Explorer — Agents](https://explorer.ritualfoundation.org/agents?kind=sovereign) — Sovereign agents page

---

## License

MIT

---

<div align="center">

**Built on [Ritual Chain](https://ritualfoundation.org) — Chain ID 1979**

*Block time: ~350ms · EIP-1559 supported · Precompile `0x080C`*

</div>
