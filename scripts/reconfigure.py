#!/usr/bin/env python3
"""
Ritual Sovereign Agent — Reconfigure Existing Harness

Reconfigures an existing harness with new prompt, model, or funding.
Calls stop() then configureFundAndStart() with updated params.

Usage:
    python3 scripts/reconfigure.py --harness 0xYourHarnessAddress
    python3 scripts/reconfigure.py --harness 0xYourHarnessAddress --fund 0.05

Requires: .env file with PRIVATE_KEY, HF_TOKEN, HF_REPO_ID, LLM provider key
"""

import argparse
import json
import os
import sys
from pathlib import Path

from ecies import encrypt as ecies_encrypt
from ecies.config import ECIES_CONFIG
from eth_abi.abi import encode
from web3 import Web3

ECIES_CONFIG.symmetric_nonce_length = 12

# ── Load .env ──
def load_env():
    env_path = Path(__file__).parent.parent / ".env"
    if not env_path.exists():
        print("ERROR: .env file not found.")
        sys.exit(1)
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, value = line.partition("=")
                os.environ.setdefault(key.strip(), value.strip())

load_env()

# ── Config ──
RPC_URL = os.environ.get("RPC_URL", "https://rpc.ritualfoundation.org")
PRIVATE_KEY = os.environ["PRIVATE_KEY"]
HF_TOKEN = os.environ["HF_TOKEN"]
HF_REPO_ID = os.environ["HF_REPO_ID"]
CLI_TYPE = int(os.environ.get("CLI_TYPE", "5"))
FREQUENCY = int(os.environ.get("FREQUENCY", "2000"))
WINDOW_NUM_CALLS = int(os.environ.get("WINDOW_NUM_CALLS", "5"))
ROLLOVER_THRESHOLD_BPS = int(os.environ.get("ROLLOVER_THRESHOLD_BPS", "5000"))

REGISTRY = "0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F"

REGISTRY_ABI = [
    {
        "name": "getServicesByCapability",
        "type": "function",
        "stateMutability": "view",
        "inputs": [
            {"name": "capability", "type": "uint8"},
            {"name": "checkValidity", "type": "bool"},
        ],
        "outputs": [
            {
                "name": "",
                "type": "tuple[]",
                "components": [
                    {
                        "name": "node",
                        "type": "tuple",
                        "components": [
                            {"name": "paymentAddress", "type": "address"},
                            {"name": "teeAddress", "type": "address"},
                            {"name": "teeType", "type": "uint8"},
                            {"name": "publicKey", "type": "bytes"},
                            {"name": "endpoint", "type": "string"},
                            {"name": "certPubKeyHash", "type": "bytes32"},
                            {"name": "capability", "type": "uint8"},
                        ],
                    },
                    {"name": "isValid", "type": "bool"},
                    {"name": "workloadId", "type": "bytes32"},
                ],
            }
        ],
    }
]

SOVEREIGN_REQUEST_TYPES = [
    "address", "uint256", "bytes", "uint64", "uint64", "string",
    "address", "bytes4", "uint256", "uint256", "uint256", "uint16",
    "string", "bytes",
    "(string,string,string)", "(string,string,string)",
    "(string,string,string)[]", "(string,string,string)",
    "string", "string[]", "uint16", "uint32", "string",
]


def send_tx(w3, tx_data, to, value=0, gas_limit=5_000_000, private_key=""):
    if isinstance(tx_data, str):
        tx_data = bytes.fromhex(tx_data[2:]) if tx_data.startswith("0x") else bytes.fromhex(tx_data)
    
    account = w3.eth.account.from_key(private_key)
    tx = {
        "from": account.address,
        "to": Web3.to_checksum_address(to),
        "value": value,
        "data": tx_data,
        "nonce": w3.eth.get_transaction_count(account.address),
        "maxFeePerGas": w3.to_wei(20, "gwei"),
        "maxPriorityFeePerGas": w3.to_wei(1, "gwei"),
        "chainId": 1979,
        "type": 2,
        "gas": gas_limit,
    }
    signed = w3.eth.account.sign_transaction(tx, private_key)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    print(f"  tx: {tx_hash.hex()}")
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)
    status = "✅ OK" if receipt.status == 1 else "❌ FAIL"
    print(f"  status: {status} (gas {receipt.gasUsed})")
    return receipt


def main():
    parser = argparse.ArgumentParser(description="Reconfigure existing Sovereign Agent harness")
    parser.add_argument("--harness", required=True, help="Harness contract address")
    parser.add_argument("--prompt", help="New prompt (overrides AGENT_PROMPT env)")
    parser.add_argument("--model", help="New model (overrides MODEL env)")
    parser.add_argument("--fund", type=float, default=0.05, help="RITUAL to fund (default: 0.05)")
    args = parser.parse_args()

    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = w3.eth.account.from_key(PRIVATE_KEY)
    SENDER = account.address
    harness_addr = Web3.to_checksum_address(args.harness)

    print(f"Sender: {SENDER}")
    print(f"Harness: {harness_addr}")
    print(f"Balance: {w3.from_wei(w3.eth.get_balance(SENDER), 'ether'):.4f} RITUAL")

    # ── 1. Stop existing schedule ──
    print(f"\n── Step 1: stop() ──")
    stop_selector = bytes.fromhex("36f5e290")  # stop()
    receipt = send_tx(w3, stop_selector, harness_addr, gas_limit=500_000, private_key=PRIVATE_KEY)
    if receipt.status != 1:
        print("⚠️  stop() failed (might already be stopped)")

    # ── 2. Build new calldata ──
    print(f"\n── Step 2: Build new calldata ──")
    registry = w3.eth.contract(address=REGISTRY, abi=REGISTRY_ABI)
    services = registry.functions.getServicesByCapability(0, True).call()
    node = services[0][0]
    executor = Web3.to_checksum_address(node[1])
    pub_key_bytes = bytes(node[3])

    # Get LLM creds
    provider = os.environ.get("LLM_PROVIDER", "openrouter").lower()
    if provider == "openrouter":
        creds = {"LLM_PROVIDER": "openrouter", "OPENROUTER_API_KEY": os.environ["OPENROUTER_API_KEY"], "HF_TOKEN": HF_TOKEN}
        model = args.model or os.environ.get("MODEL", "google/gemini-2.5-flash")
    elif provider == "openai":
        creds = {"LLM_PROVIDER": "openai", "OPENAI_API_KEY": os.environ["OPENAI_API_KEY"], "HF_TOKEN": HF_TOKEN}
        model = args.model or os.environ.get("MODEL", "gpt-4o-mini")
    elif provider == "anthropic":
        creds = {"LLM_PROVIDER": "anthropic", "ANTHROPIC_API_KEY": os.environ["ANTHROPIC_API_KEY"], "HF_TOKEN": HF_TOKEN}
        model = args.model or os.environ.get("MODEL", "claude-sonnet-4-5-20250929")
    elif provider == "gemini":
        creds = {"LLM_PROVIDER": "gemini", "GEMINI_API_KEY": os.environ["GEMINI_API_KEY"], "HF_TOKEN": HF_TOKEN}
        model = args.model or os.environ.get("MODEL", "gemini-2.5-flash")
    else:
        print(f"ERROR: Unknown LLM_PROVIDER '{provider}'")
        sys.exit(1)

    encrypted = ecies_encrypt(pub_key_bytes.hex(), json.dumps(creds).encode())
    delivery_selector = Web3.keccak(text="onSovereignAgentResult(bytes32,bytes)")[:4]

    # Get prompt
    prompt = args.prompt or os.environ.get("AGENT_PROMPT", "").strip()
    if not prompt:
        prompt_path = Path(__file__).parent.parent / "templates" / "default-prompt.txt"
        prompt = prompt_path.read_text().strip() if prompt_path.exists() else "You are a sovereign AI agent on Ritual Chain."

    print(f"Model: {model}")
    print(f"Prompt: {prompt[:80]}...")

    params = [
        executor, 500, b"", 5, 6000, "SOVEREIGN_AGENT_TASK",
        Web3.to_checksum_address(harness_addr), delivery_selector,
        3_000_000, 1_000_000_000, 100_000_000,
        CLI_TYPE, prompt, encrypted,
        ("hf", f"{HF_REPO_ID}/sessions/session-001.jsonl", "HF_TOKEN"),
        ("hf", f"{HF_REPO_ID}/artifacts/", "HF_TOKEN"),
        [],
        ("hf", f"{HF_REPO_ID}/prompts/default-system.md", ""),
        model, [], 50, 8192, "",
    ]

    schedule = (500000, FREQUENCY, 500, w3.to_wei(20, "gwei"), w3.to_wei(1, "gwei"), 0)
    rolling = (WINDOW_NUM_CALLS, ROLLOVER_THRESHOLD_BPS, 1)
    lock_duration = 100_000_000

    selector = bytes.fromhex("b1906702")
    schedule_tuple = "(uint32,uint32,uint32,uint256,uint256,uint256)"
    rolling_tuple = "(uint32,uint16,uint16)"
    encoded_args = encode(
        [f"({','.join(SOVEREIGN_REQUEST_TYPES)})", schedule_tuple, rolling_tuple, "uint256"],
        [params, schedule, rolling, lock_duration]
    )
    calldata = selector + encoded_args

    # ── 3. configureFundAndStart ──
    print(f"\n── Step 3: configureFundAndStart ──")
    fund_amount = w3.to_wei(args.fund, "ether")
    print(f"Funding: {args.fund} RITUAL")

    receipt = send_tx(w3, calldata, harness_addr, value=fund_amount, gas_limit=5_000_000, private_key=PRIVATE_KEY)

    if receipt.status == 1:
        print(f"\n{'='*60}")
        print(f"✅ HARNESS RECONFIGURED!")
        print(f"Harness: {harness_addr}")
        print(f"Explorer: https://explorer.ritualfoundation.org/address/{harness_addr}")
        print(f"New funding: {args.fund} RITUAL")
        print(f"Model: {model}")
        print(f"{'='*60}")
    else:
        print(f"\n❌ configureFundAndStart FAILED!")
        sys.exit(1)


if __name__ == "__main__":
    main()
