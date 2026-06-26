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

## 🌐 Web Deploy (Recommended)

Use the **Sovereign Deployer** UI to deploy agents directly from your browser — no CLI needed.

**→ [sovereign-deployer.vercel.app](https://sovereign-deployer.vercel.app)**

Features:
- Connect wallet → configure → deploy in one flow
- Ritual Native LLM (no API key) or external providers (OpenRouter, OpenAI, Anthropic, Gemini)
- My Agents dashboard with on-chain data
- Deposit, Restart, Stop agents from the UI
- ECIES encryption + ABI encoding handled server-side

---

## 🖥️ CLI Deploy

### Prerequisites

| What | How to Get It | Cost |
|------|---------------|------|
| **Ritual Chain wallet** | Any EVM wallet (MetaMask, Rabby, etc.) with RITUAL tokens | ≥ 0.2 RITUAL |
| **LLM API key** (external only) | See providers below | Free — $5 |
| **HuggingFace account** | [Sign up free](https://huggingface.co) | Free |

### Getting an API Key (external providers only)

| Provider | Get Key Here | Recommended Model | Cost |
|----------|-------------|-------------------|------|
| **OpenRouter** ← easiest | [openrouter.ai/keys](https://openrouter.ai/keys) | `google/gemini-2.5-flash` | Free / ~$0.01/run |
| **OpenAI** | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) | `gpt-4o-mini` | ~$0.01/run |
| **Anthropic** | [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) | `claude-sonnet-4-5-20250929` | ~$0.03/run |
| **Gemini** | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) | `gemini-2.5-flash` | Free tier |

> **Note:** Ritual Native LLM runs on-chain via precompile — no API key needed. Set `LLM_PROVIDER=native` in your `.env`.
>
> Available native models:
> - `zai-org/GLM-4.7-FP8` (default)
> - `meta-llama/Llama-3.3-70B-Instruct`
> - `Qwen/Qwen3-32B`
> - `deepseek-ai/DeepSeek-R1`

### Getting a HuggingFace Token

> **Important:** You need a token with **WRITE** access. Read-only tokens will not work.

1. Go to [huggingface.co](https://huggingface.co) and create a free account
2. Go to **Settings > Access Tokens** → [Create a token](https://huggingface.co/settings/tokens)
3. Click **New token** → select **Write** access → copy the token (starts with `hf_`)
4. Go to **New Dataset** → [Create a dataset](https://huggingface.co/new-dataset)

### Setup

```bash
git clone https://github.com/frianowzki/ritual-sovereign-agent-guide.git
cd ritual-sovereign-agent-guide

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
nano .env  # fill in your credentials
```

### Deploy

```bash
python3 scripts/deploy.py
```

### Check Status

```bash
python3 scripts/check-status.py
```

### Reconfigure

```bash
python3 scripts/reconfigure.py
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SovereignAgentFactory                 │
│  0x9dC4C054e53bCc4Ce0A0Ff09E890A7a8e817f304             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  predictHarness(user, salt) → harness address           │
│  deployHarness(salt) → deploys proxy harness            │
│                                                         │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│                     Harness (Proxy)                      │
│                                                         │
│  configureFundAndStart(params, schedule, rolling, lock) │
│  restart()                                              │
│  stop()                                                 │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │              RitualWallet (0x532F)               │    │
│  │  depositFor(user, lockDuration)                 │    │
│  │  balanceOf(user) → RITUAL balance               │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│                   TEE Executor Node                      │
│                                                         │
│  1. Decrypt secrets (ECIES)                             │
│  2. Run LLM inference (Ritual precompile / external)    │
│  3. Execute agent logic                                 │
│  4. Deliver results via callback                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
ritual-sovereign-agent-guide/
├── .env.example          # Environment template
├── scripts/
│   ├── deploy.py         # Full deploy: predict → deploy → configure → fund → start
│   ├── check-status.py   # Check agent status on-chain
│   └── reconfigure.py    # Reconfigure existing agent
├── templates/
│   ├── default-prompt.txt
│   ├── market-monitor.txt
│   └── research-agent.txt
└── references/
    └── factory-harness-deployment.md
```

---

## ⚙️ Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PRIVATE_KEY` | ✅ | Wallet private key (testnet burner recommended) |
| `RPC_URL` | ✅ | Ritual RPC: `https://rpc.ritualfoundation.org` |
| `HF_TOKEN` | ✅ | HuggingFace write-access token |
| `HF_REPO_ID` | ✅ | HuggingFace dataset repo (e.g. `username/agent-data`) |
| `MODEL` | ✅ | LLM model ID (e.g. `zai-org/GLM-4.7-FP8` for native) |
| `LLM_PROVIDER` | External only | `openrouter`, `openai`, `anthropic`, `gemini` |
| `OPENROUTER_API_KEY` | External only | OpenRouter API key |
| `SALT` | ✅ | Unique agent identifier (e.g. `my-sovereign-agent`) |
| `CLI_TYPE` | ✅ | Harness type: `6` = ZeroClaw |
| `FREQUENCY` | ✅ | Blocks between executions (e.g. `5000` ≈ 29 min) |
| `WINDOW_NUM_CALLS` | ✅ | Calls per window before rollover |
| `FUND_AMOUNT` | ✅ | RITUAL to deposit (e.g. `0.1`) |
| `LOCK_DURATION` | ✅ | Blocks to lock funds (e.g. `1728000` = 7 days) |

---

## 🔗 Contracts (Ritual Testnet)

| Contract | Address |
|----------|---------|
| SovereignAgentFactory | `0x9dC4C054e53bCc4Ce0A0Ff09E890A7a8e817f304` |
| Registry | `0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F` |
| Tracker | `0xC069FFCa0389f44eCA2C626e55491b0ab045AEF5` |
| RitualWallet | `0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948` |

---

## ⏱️ Block Time Reference

Ritual Chain has **350ms block time**.

| Duration | Blocks |
|----------|--------|
| 2 hours | 20,571 |
| 4 hours | 41,143 |
| 6 hours | 61,714 |
| 12 hours | 123,429 |
| 1 day | 246,857 |
| 3 days | 741,000 |
| 7 days | 1,728,000 |
| 15 days | 3,703,000 |
| 30 days | 7,406,000 |

---

## 📄 License

MIT
