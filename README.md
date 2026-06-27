<div align="center">

# ◈ Ritual Sovereign Agent

**Deploy autonomous AI agents on Ritual Chain**

[![Chain](https://img.shields.io/badge/Chain-Ritual_Testnet-8b5cf6?style=for-the-badge&logo=ethereum&logoColor=white)](https://explorer.ritualfoundation.org)
[![Deploy](https://img.shields.io/badge/Live-Deployer-22c55e?style=for-the-badge&logo=vercel&logoColor=white)](https://sovereign-deployer.vercel.app)
[![License](https://img.shields.io/badge/License-MIT-b49eff?style=for-the-badge)](LICENSE)

*Sovereign agents run on-chain, execute in TEE, and deliver results via async callbacks.*

```
┌─────────────────────────────────────────────────────────┐
│                  SovereignAgentFactory                    │
│  predictHarness(user, salt) → harness address            │
│  deployHarness(salt) → deploys proxy harness             │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│                    Harness (Proxy)                        │
│  configureFundAndStart(params, schedule, rolling, lock)  │
│  stop() / restart() / deposit()                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │            RitualWallet (0x532F)                  │    │
│  │  depositFor(user, lockDuration)                  │    │
│  └─────────────────────────────────────────────────┘    │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│                   TEE Executor Node                      │
│  1. Decrypt secrets (ECIES)                              │
│  2. Run LLM inference (Ritual precompile / external)     │
│  3. Execute agent logic                                  │
│  4. Deliver results via callback                         │
└─────────────────────────────────────────────────────────┘
```

</div>

---

## ◦ Features

| Feature | Status |
|---------|--------|
| 🔗 Web Deploy (browser, no CLI) | ✅ Live |
| 🧠 LLM Simulation (test before deploy) | ✅ Live |
| 📦 HuggingFace integration | ✅ Live |
| 🖥️ CLI Runtime selector (Crush/ZeroClaw) | ✅ Live |
| 📊 My Agents dashboard | ✅ Live |
| ⚡ Quick actions (stop/deposit/restart) | ✅ Live |
| 🔍 On-chain status checker | ✅ Live |
| 📋 .env generator | ✅ Live |
| 🏥 Health scoring | ✅ Live |
| 💰 Cost estimation | ✅ Live |
| 🔄 Batch operations | ✅ Live |
| 🌐 Network detection | ✅ Live |

---

## ◦ Quick Start

### Web Deploy (Recommended)

Deploy agents directly from your browser — connect wallet, configure, done.

**→ [sovereign-deployer.vercel.app](https://sovereign-deployer.vercel.app)**

```
1. Connect wallet (MetaMask / Rabby)
2. Configure: Salt, Prompt, HuggingFace, LLM Provider, Executor
3. CLI Runtime: Select Crush (5) or ZeroClaw (6)
4. Click Deploy → approve 2 transactions
5. Check status → My Agents → Manage
```

### CLI Deploy

```bash
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide

# Setup
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env && nano .env

# Deploy
python3 scripts/deploy.py

# Check status
python3 scripts/check-status.py --harness 0xYOUR_HARNESS

# Reconfigure
python3 scripts/reconfigure.py --harness 0xYOUR_HARNESS
```

---

## ◦ Web UI Guide

### Deploy Tab

Configure your agent with 5 steps:

| Step | What | Required |
|------|------|----------|
| 1. Agent Config | Salt (unique ID) + Prompt | ✅ |
| 2. HuggingFace | Dataset repo + Write token | ✅ |
| 3. LLM Provider | Provider + Model + API key | ✅ |
| 4. TEE Executor | Select executor + CLI Runtime | ✅ |
| 5. Schedule & Budget | Frequency, calls, fund amount | ✅ |

**Before deploy:** Run Smoke Test (validates HF + LLM) and LLM Test (verifies provider).

### My Agents Tab

All agents deployed on Ritual Chain, regardless of deployer:

| Feature | Description |
|---------|-------------|
| 🔍 Explorer API | Primary source — fetches ALL agents on-chain |
| ➕ Manual Input | Add agents not indexed by explorer |
| ✅ Owner Verification | On-chain `owner()` check |
| 🏥 Health Score | 🟢 Healthy / 🟡 Warning / 🔴 Critical / ⚪ Stopped |
| 💰 Cost Tracker | Daily cost estimate + days remaining |
| ⚡ Quick Actions | One-click stop, deposit, restart |
| 📦 Batch Operations | Stop/deposit multiple agents at once |
| 🔄 Wallet Detection | Auto-reload on wallet/network switch |
| 🌐 Network Check | Warns if not on Ritual Chain |

### Manage Tab

| Action | What it does |
|--------|-------------|
| **Deposit** | `wallet.depositFor()` — fund RitualWallet |
| **Restart/Reconfigure** | `stop()` → Deploy tab (same salt = same address) |
| **Stop** | `stop()` on harness — cancels scheduler |

---

## ◦ LLM Providers

### Native (Recommended — No API Key)

Runs on-chain via Ritual precompile. Set `LLM_PROVIDER=native` in `.env`.

| Model | Description |
|-------|-------------|
| `zai-org/GLM-4.7-FP8` | Default — fast, efficient |
| `meta-llama/Llama-3.3-70B-Instruct` | High quality reasoning |
| `Qwen/Qwen3-32B` | Strong multilingual |
| `deepseek-ai/DeepSeek-R1` | Deep reasoning chain |

### External

| Provider | Get Key | Model | Cost |
|----------|---------|-------|------|
| OpenRouter | [openrouter.ai/keys](https://openrouter.ai/keys) | `google/gemini-2.5-flash` | ~$0.01/run |
| OpenAI | [platform.openai.com](https://platform.openai.com/api-keys) | `gpt-4o-mini` | ~$0.01/run |
| Anthropic | [console.anthropic.com](https://console.anthropic.com/settings/keys) | `claude-sonnet-4-5-20250929` | ~$0.03/run |
| Gemini | [aistudio.google.com](https://aistudio.google.com/apikey) | `gemini-2.5-flash` | Free tier |

---

## ◦ HuggingFace Setup

> **Required:** Write-access token. Read-only tokens will not work.

1. Create account at [huggingface.co](https://huggingface.co)
2. Settings → Access Tokens → [Create token](https://huggingface.co/settings/tokens) (Write access)
3. [Create dataset](https://huggingface.co/new-dataset) (e.g. `username/agent-data`)

---

## ◦ Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PRIVATE_KEY` | ✅ | — | Wallet private key |
| `RPC_URL` | ✅ | `https://rpc.ritualfoundation.org` | Ritual RPC endpoint |
| `HF_TOKEN` | ✅ | — | HuggingFace write token |
| `HF_REPO_ID` | ✅ | — | Dataset repo (e.g. `user/agent-data`) |
| `LLM_PROVIDER` | ✅ | `native` | `native` / `openrouter` / `openai` / `anthropic` / `gemini` |
| `MODEL` | ✅ | `zai-org/GLM-4.7-FP8` | LLM model ID |
| `SALT` | ✅ | — | Unique agent identifier |
| `CLI_TYPE` | ✅ | `6` | Harness type (5=Crush, 6=ZeroClaw) |
| `FREQUENCY` | ✅ | `2000` | Blocks between executions (~12 min) |
| `WINDOW_NUM_CALLS` | ✅ | `5` | Calls per window |
| `FUND_AMOUNT` | ✅ | `0.25` | RITUAL to deposit (min 0.25) |
| `LOCK_DURATION` | ✅ | `1728000` | Blocks to lock funds (7 days) |

---

## ◦ CLI Reference

### deploy.py

```bash
python3 scripts/deploy.py \
  --rpc https://rpc.ritualfoundation.org \
  --salt my-agent \
  --cli-type 6 \
  --model zai-org/GLM-4.7-FP8 \
  --hf-token hf_xxx \
  --hf-repo-id username/agent-data \
  --prompt "You are a sovereign agent on Ritual Chain" \
  --fund 0.25 \
  --frequency 2000 \
  --window-calls 5
```

### check-status.py

```bash
python3 scripts/check-status.py \
  --harness 0xEC87F4Cf6f1AD2fd47bfbB25b7FDAE093Fb6b097
```

### reconfigure.py

```bash
python3 scripts/reconfigure.py \
  --harness 0xEC87F4Cf6f1AD2fd47bfbB25b7FDAE093Fb6b097 \
  --salt my-agent \
  --fund 0.5
```

---

## ◦ Contracts

| Contract | Address |
|----------|---------|
| SovereignAgentFactory | [`0x9dC4...f304`](https://explorer.ritualfoundation.org/address/0x9dC4C054e53bCc4Ce0A0Ff09E890A7a8e817f304) |
| Registry | [`0x9644...f47F`](https://explorer.ritualfoundation.org/address/0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F) |
| Tracker | [`0xC069...AEF5`](https://explorer.ritualfoundation.org/address/0xC069FFCa0389f44eCA2C626e55491b0ab045AEF5) |
| RitualWallet | [`0x532F...3948`](https://explorer.ritualfoundation.org/address/0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948) |

---

## ◦ Block Time Reference

Ritual Chain — **350ms block time**

| Duration | Blocks | Duration | Blocks |
|----------|--------|----------|--------|
| 2 hours | 20,571 | 15 days | 3,702,857 |
| 4 hours | 41,143 | 30 days | 7,405,714 |
| 6 hours | 61,714 | 3 months | 22,217,143 |
| 12 hours | 123,429 | 6 months | 44,434,286 |
| 1 day | 246,857 | 9 months | 66,651,429 |
| 3 days | 740,571 | 12 months | 88,868,571 |
| 7 days | 1,728,000 | | |

---

## ◦ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  SovereignAgentFactory                    │
│  predictHarness(user, salt) → harness address            │
│  deployHarness(salt) → deploys proxy harness             │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│                    Harness (Proxy)                        │
│  configureFundAndStart(params, schedule, rolling, lock)  │
│  stop() / restart() / deposit()                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │            RitualWallet (0x532F)                  │    │
│  │  depositFor(user, lockDuration)                  │    │
│  └─────────────────────────────────────────────────┘    │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│                   TEE Executor Node                      │
│  1. Decrypt secrets (ECIES)                              │
│  2. Run LLM inference (Ritual precompile / external)     │
│  3. Execute agent logic                                  │
│  4. Deliver results via callback                         │
└─────────────────────────────────────────────────────────┘
```

---

## ◦ Project Structure

```
ritual-sovereign-agent-guide/
├── deployer/
│   ├── index.html          # Sovereign Deployer UI
│   ├── api/
│   │   ├── encode.py       # ECIES encryption + ABI encoding
│   │   └── executors.py    # TEE executor registry
│   └── vercel.json
├── scripts/
│   ├── deploy.py           # Full deploy pipeline
│   ├── check-status.py     # On-chain status check
│   └── reconfigure.py      # Reconfigure existing agent
├── templates/
│   ├── default-prompt.txt
│   ├── market-monitor.txt
│   └── research-agent.txt
├── references/
│   └── factory-harness-deployment.md
├── .env.example
├── install.sh / install.ps1
└── auto-install.sh
```

---

<div align="center">

**Built by [Frianowzki](https://github.com/frianowzki) on Ritual Testnet**

*Agent is sovereign. Data is on-chain. TEE keeps secrets.*

</div>
