<div align="center">

# ❖ Ritual Sovereign Agent

### Factory Harness Deployment Guide

[![Chain](https://img.shields.io/badge/Chain-Ritual%201979-purple?style=flat-square)](https://explorer.ritualfoundation.org)
[![Python](https://img.shields.io/badge/Python-3.10+-blue?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

Deploy a **production-grade Sovereign Agent** on Ritual Chain using the factory-backed harness pattern.

*Autonomous AI agents that run on-chain, execute in TEE, and deliver results via async callbacks.*

</div>

---

## ⚡ Quick Install

**Linux & macOS — two commands:**

```bash
curl -sSL https://raw.githubusercontent.com/frianowzki/ritual-sovereign-agent-guide/master/install.sh -o install.sh && bash install.sh
```

**Windows PowerShell — one command:**

```powershell
irm https://raw.githubusercontent.com/frianowzki/ritual-sovereign-agent-guide/master/install.ps1 | iex
```

That's it. The installer will:
- Install Python, pip, and git if missing
- Clone the project
- Install all dependencies
- Walk you through configuration step by step
- Deploy your agent

> **No coding knowledge required.** The installer asks simple questions and handles everything automatically.

---

## 📋 What You Need Before Starting

| What | How to Get It | Cost |
|------|---------------|------|
| **Ritual Chain wallet** | Any EVM wallet (MetaMask, Rabby, etc.) with RITUAL tokens | ≥ 0.2 RITUAL |
| **LLM API key** | Pick one below | Free — $5 |
| **HuggingFace account** | [Sign up free](https://huggingface.co) | Free |

### Getting an API Key (pick one)

| Provider | Get Key Here | Recommended Model | Cost |
|----------|-------------|-------------------|------|
| **OpenRouter** ← easiest | [openrouter.ai/keys](https://openrouter.ai/keys) | `google/gemini-2.5-flash` | Free / ~$0.01/run |
| **OpenAI** | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) | `gpt-4o-mini` | ~$0.01/run |
| **Anthropic** | [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) | `claude-sonnet-4-5-20250929` | ~$0.03/run |
| **Gemini** | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) | `gemini-2.5-flash` | Free tier |

> **Recommendation:** Start with **OpenRouter** + **Gemini 2.5 Flash** — it's the cheapest combo and works great.

### Getting a HuggingFace Token

1. Go to [huggingface.co](https://huggingface.co) and create a free account
2. Go to **Settings > Access Tokens** → [Create a token](https://huggingface.co/settings/tokens)
3. Click **New token** → select **Write** access → copy the token (starts with `hf_`)
4. Go to **New Dataset** → [Create a dataset](https://huggingface.co/new-dataset)
5. Name it anything (e.g., `yourname/agent-data`) → copy the `username/repo-name`

---

## 🖥️ Installation Guide

### Linux & macOS

**Step 1: Open Terminal**

- **Linux:** Press `Ctrl+Alt+T` or search "Terminal" in your apps
- **macOS:** Press `Cmd+Space`, type "Terminal", press Enter

**Step 2: Run the installer**

```bash
curl -sSL https://raw.githubusercontent.com/frianowzki/ritual-sovereign-agent-guide/master/install.sh -o install.sh && bash install.sh
```

The installer will:

```
  ◆ ═══════════════════════════════════════════════════════ ◆
  ║        Ritual Sovereign Agent Installer v1.0.0        ║
  ◆ ═══════════════════════════════════════════════════════ ◆

  ── System Dependencies ──────────────────────────────────
  ✔  Git: 2.43.0
  ✔  Python: 3.12
  ✔  pip: 24.0

  ── Download Project ─────────────────────────────────────
  ✔  Cloned to ~/ritual-sovereign-agent-guide

  ── Python Dependencies ──────────────────────────────────
  ✔  Virtual environment created
  ✔  Dependencies installed

  ── Agent Configuration ──────────────────────────────────
  ?  Enter private key: ****
  ✔  Valid private key format

  ?  Select LLM provider:
  ▶ 1. OpenRouter — Cheapest, 100+ models (recommended)
    2. OpenAI
    3. Anthropic
    4. Google

  ?  Enter OPENROUTER_API_KEY: ****
  ✔  API key saved

  ?  Model [default: google/gemini-2.5-flash]:
  ✔  Model: google/gemini-2.5-flash

  ?  HuggingFace token (hf_...): ****
  ✔  Token saved

  ?  HuggingFace dataset (username/repo-name): myname/agent-data
  ✔  Dataset: myname/agent-data

  ?  Select prompt:
  ▶ 1. Default Analytics — DeFi analytics + market summary
    2. Market Monitor
    3. Research Agent
    4. Custom

  ?  Frequency:
  ▶ 1. ~12 min
    2. ~29 min (recommended)
    3. ~58 min
    4. ~2.9 hr

  ?  Fund amount [default: 0.1]:

  ── Review ───────────────────────────────────────────────
  Configuration Summary
  ──────────────────────────────────────────────────────
  Wallet:          0x63C5...d39c
  LLM Provider:    openrouter
  Model:           google/gemini-2.5-flash
  HuggingFace:     myname/agent-data
  Frequency:       every 5000 blocks (~29.2 min)
  Fund Amount:     0.1 RITUAL
  ──────────────────────────────────────────────────────

  ?  Deploy now? [Y/n]: Y
```

**Step 3: Done!**

Your agent is now live on Ritual Chain. Check it at:
```
https://explorer.ritualfoundation.org/agents?kind=sovereign
```

---

### Windows

**Option A — PowerShell installer (easiest):**

Open **PowerShell** and run:

```powershell
irm https://raw.githubusercontent.com/frianowzki/ritual-sovereign-agent-guide/master/install.ps1 | iex
```

> If script execution is blocked, run this first:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
> ```

The installer handles everything: installs Python, Git, dependencies, and walks you through configuration.

**Option B — WSL (Windows Subsystem for Linux):**

1. Open **PowerShell** as Administrator
2. Run: `wsl --install`
3. Restart your computer
4. Open **Ubuntu** from the Start menu
5. Run:
```bash
curl -sSL https://raw.githubusercontent.com/frianowzki/ritual-sovereign-agent-guide/master/install.sh -o install.sh && bash install.sh
```

**Option C — Manual setup:**

1. Install [Python 3.10+](https://www.python.org/downloads/) (check "Add to PATH")
2. Install [Git](https://git-scm.com/download/win)
3. Open **PowerShell** and run:
```powershell
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install web3 eciespy eth-abi
python scripts\deploy.py
```

---

## 📖 How It Works

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

**What happens after deployment:**

1. **Scheduler** triggers your harness every N blocks (~11-29 min)
2. **Harness** calls the `0x080C` precompile with your prompt + encrypted secrets
3. **TEE executor** runs AI inference off-chain (cost paid by executor, not you)
4. **Phase 2 callback** delivers results back to your harness on-chain
5. Your agent appears on the [Explorer](https://explorer.ritualfoundation.org/agents?kind=sovereign) as **Sovereign + Monitored**

---

## 🔧 Commands Reference

After deployment, use these commands to manage your agent:

```bash
# Navigate to project
cd ~/ritual-sovereign-agent-guide

# Check status
python3 scripts/check-status.py --harness 0xYourHarnessAddress

# Change prompt
python3 scripts/reconfigure.py --harness 0xYourHarnessAddress --prompt "New task here"

# Change model
python3 scripts/reconfigure.py --harness 0xYourHarnessAddress --model gpt-4o

# Add funding (reconfigure method — stops and restarts schedule)
python3 scripts/reconfigure.py --harness 0xYourHarnessAddress --fund 0.05

# Redeploy from scratch
python3 scripts/deploy.py
```

### Add Funding Without Redeploying

Use `depositFor` on RitualWallet to add funds directly without stopping the schedule:

```bash
cast send 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948 \
  "depositFor(address,uint256)" \
  0xYourHarnessAddress \
  100000000 \
  --value 0.5ether \
  --rpc-url https://rpc.ritualfoundation.org \
  --private-key $PRIVATE_KEY
```

- `0xYourHarnessAddress` — your harness contract address
- `100000000` — lock duration in blocks
- `--value 0.5ether` — amount of RITUAL to deposit

This keeps your agent running while adding more funds.

---

## 💰 Cost Breakdown

| Step | Gas Used | Cost (~250 gwei) |
|------|----------|------------------|
| `deployHarness` | ~943k | ~0.005 RITUAL |
| `configureFundAndStart` | ~3.2M | ~0.016 RITUAL |
| Fund harness (deposit) | — | 0.1 RITUAL |
| **Total setup** | — | **~0.12 RITUAL** |
| Per heartbeat (on-chain) | ~200k | ~0.002 RITUAL |

> **0.1 RITUAL** funds ~50 heartbeats (~1 month at 1x/day).
> TEE execution cost is paid by the executor, **not your contract**.

---

## 📝 Custom Prompts

Your agent's prompt defines what it does every time it wakes up.

### Ready-Made Templates

| Template | Description | Best For |
|----------|-------------|----------|
| `templates/default-prompt.txt` | General DeFi analytics | Getting started |
| `templates/market-monitor.txt` | Price tracking + alerts | Traders |
| `templates/research-agent.txt` | Web research + summarization | Researchers |

### Writing Your Own

```
◆ Good — specific task with clear output
"You are a DeFi analytics agent. Fetch the top 10 altcoin prices from
CoinGecko API, calculate 24h change percentages, and identify the
biggest movers. Return a concise market summary with buy/sell signals."

◆ Bad — too vague
"Do something useful."
```

Set via `.env`:
```env
AGENT_PROMPT=You are a sovereign agent. Your task is to...
```

Or via reconfigure:
```bash
python3 scripts/reconfigure.py --harness 0xYourAddr --prompt "Your prompt here"
```

---

## 🏗️ Architecture

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
                                          ↑ 50% threshold → schedule Window 2
Window 2: [call1] [call2] [call3] [call4] [call5]
                                          ↑ → schedule Window 3
                    ...continuous operation...
```

---

## 🐛 Troubleshooting

<details>
<summary><strong>◆ <code>DeploymentFailed()</code> (0x30116425)</strong></summary>

**Cause:** `deployHarness` gas limit too low (< 3M).
**Fix:** Set gas limit to 3,000,000+.
</details>

<details>
<summary><strong>◆ <code>configureFundAndStart</code> reverts silently</strong></summary>

**Cause:** Gas limit too low (~3M). Actual usage: ~3.2M.
**Fix:** Set gas limit to 5,000,000.
</details>

<details>
<summary><strong>◆ ECIES silent failure</strong></summary>

**Cause:** Wrong nonce length (16 instead of 12).
**Fix:** Always set `ECIES_CONFIG.symmetric_nonce_length = 12`.
</details>

<details>
<summary><strong>◆ Sender locked</strong></summary>

**Cause:** Another async job pending for your EOA.
**Fix:** Wait for current job to settle, or use a different key.
</details>

<details>
<summary><strong>◆ <code>eciespy</code> install fails on macOS</strong></summary>

**Cause:** Missing Rust compiler.
**Fix:** `brew install rust && pip install eciespy`
</details>

<details>
<summary><strong>◆ PowerShell script execution blocked</strong></summary>

**Fix:** `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
</details>

---

## 📁 File Structure

```
ritual-sovereign-agent-guide/
├── install.sh                         Linux/macOS installer
├── install.ps1                        Windows PowerShell installer
├── README.md                          This file
├── .env.example                       Environment template
├── .gitignore
├── scripts/
│   ├── deploy.py                      Full deployment
│   ├── reconfigure.py                 Update existing harness
│   └── check-status.py                Check harness status
├── templates/
│   ├── default-prompt.txt             General DeFi analytics
│   ├── market-monitor.txt             Price tracking + alerts
│   └── research-agent.txt             Web research + summarization
└── references/
    └── factory-harness-deployment.md  Technical reference
```

---

## 📚 References

- [Ritual dApp Skills](https://github.com/ritual-foundation/ritual-dapp-skills) — Official skills + examples
- [Ritual Docs](https://docs.ritualfoundation.org) — Chain documentation
- [Ritual Explorer](https://explorer.ritualfoundation.org) — Block explorer
- [Ritual Explorer — Agents](https://explorer.ritualfoundation.org/agents?kind=sovereign) — Sovereign agents

---

## License

MIT

---

<div align="center">

**Built on [Ritual Chain](https://ritualfoundation.org) — Chain ID 1979**

*Block time: ~350ms · EIP-1559 supported · Precompile `0x080C`*

</div>
