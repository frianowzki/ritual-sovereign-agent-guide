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

[Quick Start](#quick-start) · [Platform Setup](#platform-setup) · [Environment](#environment-configuration) · [Deploy](#deployment) · [Custom Prompts](#custom-prompts) · [Monitoring](#monitoring) · [Troubleshooting](#troubleshooting)

</div>

---

## Table of Contents

- [What You'll Build](#what-youll-build)
- [Quick Start](#quick-start)
- [Platform Setup](#platform-setup)
  - [Linux](#linux)
  - [macOS](#macos)
  - [Windows](#windows)
- [Environment Configuration](#environment-configuration)
  - [LLM Providers](#llm-providers)
  - [HuggingFace Setup](#huggingface-setup)
  - [Full Variable Reference](#full-variable-reference)
- [Deployment](#deployment)
  - [Step 1: Deploy Harness](#step-1-deploy-harness)
  - [Step 2: Verify on Explorer](#step-2-verify-on-explorer)
  - [Step 3: Monitor Agent](#step-3-monitor-agent)
- [Custom Prompts](#custom-prompts)
- [Reconfiguration](#reconfiguration)
- [Monitoring & Management](#monitoring--management)
- [Architecture](#architecture)
- [Cost Breakdown](#cost-breakdown)
- [Troubleshooting](#troubleshooting)
- [File Structure](#file-structure)
- [References](#references)

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

## Quick Start

```bash
# 1. Clone
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide

# 2. Install dependencies
pip install web3 eciespy eth-abi

# 3. Configure
cp .env.example .env
# Edit .env with your keys (see Environment Configuration below)

# 4. Deploy
python3 scripts/deploy.py
```

**That's it.** The script handles prediction, deployment, ECIES encryption, calldata encoding, and scheduler configuration in one run.

---

## Platform Setup

### Linux

**Ubuntu / Debian:**
```bash
# Python 3.10+
sudo apt update
sudo apt install -y python3 python3-pip python3-venv git

# Clone and setup
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python3 -m venv venv
source venv/bin/activate
pip install web3 eciespy eth-abi
```

**Fedora / RHEL:**
```bash
sudo dnf install -y python3 python3-pip git
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python3 -m venv venv
source venv/bin/activate
pip install web3 eciespy eth-abi
```

**Arch Linux:**
```bash
sudo pacman -S python python-pip git
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python3 -m venv venv
source venv/bin/activate
pip install web3 eciespy eth-abi
```

---

### macOS

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Python 3.10+ and Git
brew install python git

# Clone and setup
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python3 -m venv venv
source venv/bin/activate
pip install web3 eciespy eth-abi
```

> **Note:** macOS comes with Python 3.9 pre-installed. `brew install python` gives you 3.12+ which is required.

**Apple Silicon (M1/M2/M3) users:**
If you hit build errors with `eciespy`, install Rust first:
```bash
brew install rust
pip install web3 eciespy eth-abi
```

---

### Windows

**Option A — Python directly (recommended):**

1. **Install Python 3.10+** from [python.org](https://www.python.org/downloads/)
   - ✅ Check **"Add Python to PATH"** during installation
   - ✅ Check **"Install pip"**

2. **Install Git** from [git-scm.com](https://git-scm.com/download/win)
   - Use default settings during installation

3. **Open PowerShell** and run:
```powershell
# Clone
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide

# Create virtual environment
python -m venv venv
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install web3 eciespy eth-abi
```

> **If `Activate.ps1` is blocked**, run this first:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

**Option B — WSL (Windows Subsystem for Linux):**

```powershell
# In PowerShell (as Administrator)
wsl --install
# Restart computer, then open "Ubuntu" from Start menu

# Inside WSL Ubuntu
sudo apt update && sudo apt install -y python3 python3-pip git
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python3 -m venv venv
source venv/bin/activate
pip install web3 eciespy eth-abi
```

> **Recommendation:** Use WSL if you're comfortable with it — the Linux toolchain is more reliable for Web3 development.

**Windows-specific notes:**
- Use `python` instead of `python3` in PowerShell
- Use `.\venv\Scripts\Activate.ps1` instead of `source venv/bin/activate`
- Use backslashes `\` in paths, or forward slashes `/` in Python scripts
- If `eciespy` fails to install, try: `pip install eciespy --only-binary :all:`

---

## Environment Configuration

Copy the example and fill in your values:

```bash
cp .env.example .env
```

### LLM Providers

Choose **one** provider and set the corresponding API key.

**◆ OpenRouter** (recommended — cheapest, access to 100+ models)
```env
LLM_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-v1-your-key-here
MODEL=google/gemini-2.5-flash
```
Get key → [openrouter.ai/keys](https://openrouter.ai/keys)

**◆ OpenAI**
```env
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-your-key-here
MODEL=gpt-4o-mini
```
Get key → [platform.openai.com/api-keys](https://platform.openai.com/api-keys)

**◆ Anthropic**
```env
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-your-key-here
MODEL=claude-sonnet-4-5-20250929
```
Get key → [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)

**◆ Google Gemini**
```env
LLM_PROVIDER=gemini
GEMINI_API_KEY=your-key-here
MODEL=gemini-2.5-flash
```
Get key → [aistudio.google.com/apikey](https://aistudio.google.com/apikey)

---

### HuggingFace Setup

HuggingFace stores your agent's conversation history and artifacts.

1. Create account at [huggingface.co](https://huggingface.co)
2. Go to **Settings > Access Tokens** → [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
3. Create a token with **write** access
4. Go to **New Dataset** → [huggingface.co/new-dataset](https://huggingface.co/new-dataset)
5. Create a dataset (e.g., `yourname/agent-data`)
6. Set in `.env`:
   ```env
   HF_TOKEN=hf_your_token_here
   HF_REPO_ID=yourname/agent-data
   ```

> **Important:** `HF_REPO_ID` must be in `username/repo-name` format. Not a URL, not a token.

---

### Full Variable Reference

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

### Step 1: Deploy Harness

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

### Step 2: Verify on Explorer

1. Open your harness on the explorer:
   ```
   https://explorer.ritualfoundation.org/address/0xYOUR_HARNESS
   ```

2. Check the **Agents** page:
   ```
   https://explorer.ritualfoundation.org/agents?kind=sovereign
   ```

3. Your agent should show as **Sovereign + Monitored** ✅

### Step 3: Monitor Agent

```bash
python3 scripts/check-status.py --harness 0xYourHarnessAddress
```

---

## Custom Prompts

Your agent's prompt defines what it does every time it wakes up. Edit `templates/default-prompt.txt` or set `AGENT_PROMPT` in `.env`.

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

### Prompt from File

```env
# In .env
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

### Cast Commands (with [Foundry](https://book.getfoundry.sh/getting-started/installation))

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
**Fix:** The script sets 3M by default. If you're calling manually:
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
