# Factory-Backed Harness Deployment

## Overview

The factory-backed pattern is the recommended way to deploy sovereign agents in production. Instead of calling `0x080C` directly from a consumer contract, you:

1. Deploy a deterministic child harness contract via the factory
2. Build calldata with ECIES-encrypted secrets
3. Configure, fund, and arm the scheduler in one transaction

The harness handles rolling window lifecycle, scheduler integration, and Phase 2 callback delivery.

## Addresses

```
SOVEREIGN_FACTORY = 0x9dC4C054e53bCc4Ce0A0Ff09E890A7a8e817f304
REGISTRY          = 0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F
TRACKER           = 0xC069FFCa0389f44eCA2C626e55491b0ab045AEF5
RITUAL_WALLET     = 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948
SCHEDULER         = 0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B
ASYNC_DELIVERY    = 0x5A16214fF555848411544b005f7Ac063742f39F6
```

## Step 1: predictHarness + deployHarness

```python
from web3 import Web3

w3 = Web3(Web3.HTTPProvider("https://rpc.ritualfoundation.org"))
factory = w3.eth.contract(address=SOVEREIGN_FACTORY, abi=FACTORY_ABI)

user_salt_bytes = Web3.keccak(text="my-agent-salt")
predicted, child_salt = factory.functions.predictHarness(SENDER, user_salt_bytes).call()

# Deploy (use 3M gas limit — CREATE3 internal deployment needs it)
deploy_data = factory.encode_abi("deployHarness", [user_salt_bytes])
# send tx with gas_limit=3_000_000
```

## Step 2: Build Calldata (ECIES + ABI Encode)

```python
from ecies import encrypt as ecies_encrypt
from ecies.config import ECIES_CONFIG
from eth_abi.abi import encode

ECIES_CONFIG.symmetric_nonce_length = 12  # CRITICAL: must be 12

# Get executor public key from registry
registry = w3.eth.contract(address=REGISTRY, abi=REGISTRY_ABI)
services = registry.functions.getServicesByCapability(0, True).call()
node = services[0][0]
executor = Web3.to_checksum_address(node[1])
pub_key_bytes = bytes(node[3])

# Encrypt secrets
secrets_json = json.dumps({
    "LLM_PROVIDER": "openrouter",
    "OPENROUTER_API_KEY": "...",
    "HF_TOKEN": "hf_...",
})
encrypted = ecies_encrypt(pub_key_bytes.hex(), secrets_json.encode())

# 23-field SovereignAgentParams
SOVEREIGN_REQUEST_TYPES = [
    "address", "uint256", "bytes", "uint64", "uint64", "string",
    "address", "bytes4", "uint256", "uint256", "uint256", "uint16",
    "string", "bytes",
    "(string,string,string)", "(string,string,string)",
    "(string,string,string)[]", "(string,string,string)",
    "string", "string[]", "uint16", "uint32", "string",
]

params = [
    executor,                    # 1. executor address
    500,                         # 2. ttl
    b"",                         # 3. userPublicKey
    5,                           # 4. pollIntervalBlocks
    6000,                        # 5. maxPollBlock
    "SOVEREIGN_AGENT_TASK",      # 6. taskIdMarker
    harness_address,             # 7. deliveryTarget (MUST be predicted harness)
    delivery_selector,           # 8. bytes4(onSovereignAgentResult)
    3_000_000,                   # 9. deliveryGasLimit
    1_000_000_000,               # 10. deliveryMaxFeePerGas
    100_000_000,                 # 11. deliveryMaxPriorityFeePerGas
    5,                           # 12. cliType (5=crush, 6=zeroclaw)
    "Your prompt here",          # 13. prompt
    encrypted,                   # 14. encryptedSecrets
    ("hf", "user/repo/sessions/session-001.jsonl", "HF_TOKEN"),  # 15. convoHistory
    ("hf", "user/repo/artifacts/", "HF_TOKEN"),                   # 16. output
    [],                          # 17. skills
    ("hf", "user/repo/prompts/default-system.md", ""),            # 18. systemPrompt
    "google/gemini-2.5-flash",   # 19. model
    [],                          # 20. tools
    50,                          # 21. maxTurns
    8192,                        # 22. maxTokens
    "",                          # 23. rpcUrls
]
```

## Step 3: configureFundAndStart

```python
# Schedule config
schedule = (
    500000,                # schedulerGas
    2000,                  # frequency (blocks, ~11.7 min)
    500,                   # schedulerTtl
    w3.to_wei(20, "gwei"), # maxFeePerGas
    w3.to_wei(1, "gwei"),  # maxPriorityFeePerGas
    0,                     # value
)

# Rolling config
rolling = (
    5,     # windowNumCalls
    5000,  # rolloverThresholdBps (50%)
    1,     # rolloverRetryEveryCalls
)

lock_duration = 100_000_000  # blocks

# Encode configureFundAndStart(selector=0xb1906702)
selector = bytes.fromhex("b1906702")
encoded_args = encode(
    [params_type, schedule_type, rolling_type, "uint256"],
    [params, schedule, rolling, lock_duration]
)
calldata = selector + encoded_args

# Send with 0.1 RITUAL value and 5M gas limit
```

## Pitfalls

1. **Gas limits**: `deployHarness` needs 3M, `configureFundAndStart` needs 5M. Default estimation fails.
2. **ECIES nonce length**: Must set `ECIES_CONFIG.symmetric_nonce_length = 12`. Wrong nonce = silent failure.
3. **deliveryTarget**: MUST equal the predicted harness address. Mismatch reverts with `InvalidDeliveryTarget()`.
4. **Address checksumming**: web3 v7 requires checksummed addresses in tx `to` field. Use `Web3.to_checksum_address()`.
5. **web3 v7 API**: Use `encode_abi("fnName", [args])` (positional), not `encodeABI(fn_name=..., args=...)`.
6. **Frequency**: 2000 blocks is safe default. `frequency=1` fires every block and causes precompile reverts.
7. **Lifespan**: `frequency × numCalls <= 10,000` (Scheduler MAX_LIFESPAN). Exceeding reverts.
8. **HF_REPO_ID**: Must be `user/repo` format, not a URL. Placeholder values cause silent failures in executor.
9. **Pending jobs**: Check `hasPendingJobForSender()` before deploying. Sender lock blocks concurrent async jobs.
10. **Balance**: ~0.11 RITUAL minimum (0.01 deploy + 0.05 configure + 0.05 fund). More is safer.
11. **DeploymentFailed() error**: When `deployHarness` gas limit is too low (< 3M), you get `DeploymentFailed()` (selector `0x30116425`) — NOT an out-of-gas error. The CREATE3 factory internally deploys a minimal proxy + actual contract, and the inner deployment reverts if gas is insufficient. Always set 3M+ gas.
12. **configureFundAndStart gas**: If gas limit is too low (~3M), the tx consumes all gas and reverts with status 0 but no revert reason. Set 5M+ to be safe. Actual usage: ~3.2M gas.
13. **tx_data type**: `encode_abi()` returns a hex string in web3 v7, not bytes. The `send_tx` helper must convert: `if isinstance(tx_data, str): tx_data = bytes.fromhex(tx_data[2:])`.

## Cost Breakdown

| Step | Gas Used | Cost (250 gwei) |
|------|----------|-----------------|
| deployHarness | ~943k | ~0.005 RITUAL |
| configureFundAndStart | ~3.2M | ~0.016 RITUAL |
| Fund harness | - | 0.1 RITUAL |
| **Total** | - | **~0.12 RITUAL** |

Each heartbeat call: ~0.002-0.005 RITUAL on-chain gas (executor pays TEE cost).
0.1 RITUAL funds ~20-50 heartbeats (~1-2 months at 1x/day).

**Actual gas used (verified 2026-06-25):**
- `deployHarness("hive-sovereign-v6")`: 943,627 gas (set 3M limit)
- `configureFundAndStart(...)`: 3,178,666 gas (set 5M limit, failed at 3M with 2,994,769 gas consumed)

## Reference

Official example: `ritual-foundation/ritual-dapp-skills/examples/sovereign-agent/` on GitHub.
Guide: https://github.com/samarth67/ritual-sovereign-agent-guide/blob/main/README.md
