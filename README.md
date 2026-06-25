# Ritual Sovereign Agent — Factory Harness Deployment Guide

Deploy a production-grade Sovereign Agent on Ritual Chain using the factory-backed harness pattern. This guide covers everything from environment setup to automated scheduling.

> **Chain:** Ritual (ID `1979`) | **RPC:** `https://rpc.ritualfoundation.org` | **Block time:** ~350ms

---

## What You'll Build

A **Sovereign Agent** — an on-chain AI agent that:
- Runs autonomously on a schedule (every ~11.7 minutes)
- Calls the `0x080C` precompile via a factory-deployed harness
- Uses TEE-verified executors for off-chain AI inference
- Delivers results via async Phase 2 callbacks
- Stores conversation history on HuggingFace

```
┌──────────────┐    deployHarness     ┌──────────────┐
│  Your EOA    │ ──────────────────▶  │   Factory    │ ─── CREATE3 ──▶ Harness
└──────────────┘                      └──────────────┘
       │
       │  configureFundAndStart
       ▼
┌──────────────┐    schedule()        ┌──────────────┐
│   Harness    │ ──────────────────▶  │  Scheduler   │
└──────────────┘                      └──────────────┘
       │                                     │
       │  wakeUp() every 2000 blocks         │
       ▼                                     │
┌──────────────┐    0x080C call        ┌──────────────┐
│  Precompile  │ ──────────────────▶  │  Executor    │ ─── TEE ──▶ AI Model
│   0x080C     │                      │   (TEE)      │
└──────────────┘                      └──────────────┘
       │                                     │
       │  Phase 2 callback                   │
       ▼                                     │
┌──────────────┐    onSovereignAgentResult   │
│   Harness    │ ◀──────────────────────────┘
└──────────────┘
```

---

## Prerequisites

- Python 3.10+
- Ritual Chain wallet with **≥ 0.2 RITUAL** (testnet)
- HuggingFace account + token
- One LLM API key (OpenRouter, OpenAI, Anthropic, or Gemini)

---

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/frianowzki/ritual-factory-harness-guide.git
cd ritual-factory-harness-guide

# 2. Install dependencies
pip install web3 eciespy eth-abi

# 3. Copy and fill .env
cp .env.example .env
nano .env  # fill in your keys

# 4. Deploy
python3 scripts/deploy.py
```

---

## Environment Setup

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PRIVATE_KEY` | Your EOA private key (0x-prefixed) | `0xabc123...` |
| `HF_TOKEN` | HuggingFace access token | `hf_abc123...` |
| `HF_REPO_ID` | HuggingFace dataset (user/repo format) | `myuser/agent-data` |
| `LLM_PROVIDER` | One of: `openrouter`, `openai`, `anthropic`, `gemini` | `openrouter` |
| `OPENROUTER_API_KEY` | OpenRouter API key (if using OpenRouter) | `sk-or-v1-abc...` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MODEL` | LLM model identifier | `google/gemini-2.5-flash` |
| `AGENT_PROMPT` | Custom prompt for your agent | See `templates/default-prompt.txt` |
| `SALT` | Unique salt for deterministic deployment | `my-sovereign-agent` |
| `CLI_TYPE` | Agent runtime type (5=crush, 6=zeroclaw) | `5` |
| `FREQUENCY` | Blocks between executions | `2000` (~11.7 min) |
| `WINDOW_NUM_CALLS` | Calls per rolling window | `5` |
| `FUND_AMOUNT` | RITUAL to fund harness | `0.1` |

### LLM Provider Setup

**OpenRouter (recommended — cheapest):**
```bash
LLM_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-v1-your-key-here
MODEL=google/gemini-2.5-flash
```

**OpenAI:**
```bash
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-your-key-here
MODEL=gpt-4o-mini
```

**Anthropic:**
```bash
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-your-key-here
MODEL=claude-sonnet-4-5-20250929
```

**Gemini:**
```bash
LLM_PROVIDER=gemini
GEMINI_API_KEY=your-key-here
MODEL=gemini-2.5-flash
```

### HuggingFace Setup

1. Go to [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
2. Create a token with **write** access
3. Create a dataset repo (e.g., `yourname/agent-data`)
4. Set in `.env`:
   ```bash
   HF_TOKEN=hf_your_token_here
   HF_REPO_ID=yourname/agent-data
   ```

---

## Custom Prompts

Edit `templates/default-prompt.txt` or set `AGENT_PROMPT` in `.env`.

The prompt is what the AI agent sees every time it wakes up. Make it specific:

```
# Good — specific task
"You are a DeFi analytics agent. Fetch the top 10 altcoin prices from 
CoinGecko API, calculate 24h change percentages, and identify the 
biggest movers. Return a concise market summary."

# Good — recurring analysis
"You are Hive, a sovereign AI agent on Ritual Chain. Monitor RITUAL 
token price, check recent transactions on the explorer, and provide 
a brief market sentiment analysis. Focus on unusual activity."

# Bad — too vague
"Do something useful."
```

### Prompt Templates

See `templates/` for ready-made prompts:
- `default-prompt.txt` — General DeFi analytics
- `market-monitor.txt` — Price tracking + alerts
- `research-agent.txt` — Web research + summarization

---

## Deployment Script

### `scripts/deploy.py`

Full deployment: predict → deploy harness → build calldata → configure + fund + start.

```bash
python3 scripts/deploy.py
```

**What it does:**
1. Checks pending jobs (sender lock)
2. Predicts harness address via `predictHarness`
3. Deploys harness via `deployHarness` (3M gas)
4. Discovers executor from TEEServiceRegistry
5. Encrypts secrets with ECIES (12-byte nonce)
6. Builds 23-field SovereignAgentParams
7. Calls `configureFundAndStart` (5M gas, 0.1 RITUAL)

**Output:**
```
✅ Harness deployed: 0x...
✅ Configured + funded!
Explorer: https://explorer.ritualfoundation.org/address/0x...
```

### `scripts/reconfigure.py`

Reconfigure an existing harness (new prompt, model, or funding).

```bash
python3 scripts/reconfigure.py --harness 0xYourHarnessAddress
```

**What it does:**
1. Calls `stop()` on existing harness
2. Builds new calldata with updated config
3. Calls `configureFundAndStart` with new params

### `scripts/check-status.py`

Check harness status, balance, and schedule.

```bash
python3 scripts/check-status.py --harness 0xYourHarnessAddress
```

**Output:**
```
Harness: 0x...
Owner: 0x...
Configured: true
Wake Mode: ROLLING_FIXED_WINDOW (1)
RitualWallet Balance: 0.119 RITUAL
Schedule: frequency=2000, windowNumCalls=5
```

---

## Architecture

### System Contracts

| Contract | Address | Purpose |
|----------|---------|---------|
| SovereignAgentFactory | `0x9dC4C054e53bCc4Ce0A0Ff09E890A7a8e817f304` | Deploys harnesses |
| TEEServiceRegistry | `0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F` | Executor discovery |
| AsyncJobTracker | `0xC069FFCa0389f44eCA2C626e55491b0ab045AEF5` | Job lifecycle |
| AsyncDelivery | `0x5A16214fF555848411544b005f7Ac063742f39F6` | Phase 2 callbacks |
| RitualWallet | `0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948` | Fee escrow |
| Scheduler | `0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B` | Recurring execution |

### Rolling Window

The harness uses a rolling window to ensure continuous operation:

```
Window 1: [call1, call2, call3, call4, call5]
                                    ↑ threshold (50%)
                                    Window 2 scheduled here
Window 2: [call1, call2, call3, call4, call5]
                                    ↑
                                    Window 3 scheduled
...and so on
```

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `windowNumCalls` | 5 | 5 calls per window |
| `frequency` | 2000 | ~11.7 min between calls |
| `rolloverThresholdBps` | 5000 | Start next window at 50% |
| `rolloverRetryEveryCalls` | 1 | Retry scheduling every call |

### Cost Breakdown

| Step | Gas | Cost (~250 gwei) |
|------|-----|------------------|
| `deployHarness` | ~943k | ~0.005 RITUAL |
| `configureFundAndStart` | ~3.2M | ~0.016 RITUAL |
| Fund harness (deposit) | — | 0.1 RITUAL |
| **Total setup** | — | **~0.12 RITUAL** |
| Per heartbeat (on-chain gas) | ~200k | ~0.002 RITUAL |

0.1 RITUAL funds ~50 heartbeats (~1 month at 1x/day, or ~2 months at every-other-day).

---

## Pitfalls & Solutions

### 1. `DeploymentFailed()` (0x30116425)

**Cause:** `deployHarness` gas limit too low (< 3M).
**Fix:** Set gas limit to 3,000,000+.

### 2. `configureFundAndStart` reverts with no reason

**Cause:** Gas limit too low (~3M). Actual usage is ~3.2M.
**Fix:** Set gas limit to 5,000,000.

### 3. ECIES silent failure

**Cause:** Wrong nonce length (16 instead of 12).
**Fix:** Always set `ECIES_CONFIG.symmetric_nonce_length = 12`.

### 4. `InvalidDeliveryTarget()`

**Cause:** `deliveryTarget` doesn't match predicted harness address.
**Fix:** Use `predictHarness()` result, not factory address.

### 5. Sender locked

**Cause:** Another async job pending for your EOA.
**Fix:** Wait for current job to settle, or use different key.
**Check:** `cast call 0xC069...aef5 "hasPendingJobForSender(address)(bool)" YOUR_ADDRESS`

### 6. `ModeNotSupported()` on `wakeMode()`

**Cause:** Function requires `msg.sender == owner`.
**Fix:** Use `--from OWNER_ADDRESS` when calling via cast.

### 7. HF_REPO_ID format

**Must be:** `username/repo-name` (slash-separated)
**Not:** A URL, or `hf_` prefixed token

---

## Monitoring

### Check Harness Status

```bash
# Configured?
cast call 0xYOUR_HARNESS "configured()(bool)" --rpc-url https://rpc.ritualfoundation.org

# Wake mode (needs --from owner)
cast call 0xYOUR_HARNESS "wakeMode()(uint8)" --from YOUR_EOA --rpc-url https://rpc.ritualfoundation.org

# Schedule config
cast call 0xYOUR_HARNESS "scheduleConfig()(uint32,uint32,uint32,uint256,uint256,uint256)" --from YOUR_EOA --rpc-url https://rpc.ritualfoundation.org

# Rolling config
cast call 0xYOUR_HARNESS "rollingConfig()(uint32,uint16,uint16)" --from YOUR_EOA --rpc-url https://rpc.ritualfoundation.org
```

### Check Wallet Balance

```bash
# Harness RitualWallet balance
cast call 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948 "balanceOf(address)(uint256)" 0xYOUR_HARNESS --rpc-url https://rpc.ritualfoundation.org

# Lock expiry
cast call 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948 "lockUntil(address)(uint256)" 0xYOUR_HARNESS --rpc-url https://rpc.ritualfoundation.org
```

### Explorer

- **Agents page:** `https://explorer.ritualfoundation.org/agents?kind=sovereign`
- **Your harness:** `https://explorer.ritualfoundation.org/address/0xYOUR_HARNESS`

---

## Top-Up Funding

When balance runs low, add more RITUAL:

```bash
# From EOA to harness RitualWallet
cast send 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948 \
  "deposit(uint256)" 100000000 \
  --value 0.1ether \
  --private-key $PRIVATE_KEY \
  --rpc-url https://rpc.ritualfoundation.org
```

Or use the reconfigure script to stop → reconfigure with new funding.

---

## Files

```
ritual-factory-harness-guide/
├── README.md                    # This guide
├── .env.example                 # Environment template
├── scripts/
│   ├── deploy.py                # Full deployment script
│   ├── reconfigure.py           # Reconfigure existing harness
│   └── check-status.py          # Check harness status
├── templates/
│   ├── default-prompt.txt       # Default agent prompt
│   ├── market-monitor.txt       # Price monitoring prompt
│   └── research-agent.txt       # Web research prompt
└── references/
    └── factory-harness-deployment.md  # Technical reference
```

---

## References

- [Ritual dApp Skills](https://github.com/ritual-foundation/ritual-dapp-skills) — Official skills + examples
- [Ritual Docs](https://docs.ritualfoundation.org) — Chain documentation
- [Ritual Explorer](https://explorer.ritualfoundation.org) — Block explorer
- [Sovereign Agent Guide](https://github.com/samarth67/ritual-sovereign-agent-guide) — Windows setup guide

---

## License

MIT
