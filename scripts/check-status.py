#!/usr/bin/env python3
"""
Ritual Sovereign Agent — Check Harness Status

Displays harness configuration, balance, and schedule status.

Usage:
    python3 scripts/check-status.py --harness 0xYourHarnessAddress
"""

import argparse
import os
import sys
from pathlib import Path

from web3 import Web3

# ── Load .env ──
def load_env():
    env_path = Path(__file__).parent.parent / ".env"
    if env_path.exists():
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, _, value = line.partition("=")
                    os.environ.setdefault(key.strip(), value.strip())

load_env()

RPC_URL = os.environ.get("RPC_URL", "https://rpc.ritualfoundation.org")
RITUAL_WALLET = "0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948"


def call_fn(w3, addr, sig, from_addr=None):
    """Call a view function, return raw result or None on revert."""
    try:
        params = {"to": Web3.to_checksum_address(addr), "data": sig}
        if from_addr:
            params["from"] = from_addr
        result = w3.eth.call(params)
        return result
    except:
        return None


def main():
    parser = argparse.ArgumentParser(description="Check Sovereign Agent harness status")
    parser.add_argument("--harness", required=True, help="Harness contract address")
    parser.add_argument("--owner", help="Owner address (for owner-gated reads)")
    args = parser.parse_args()

    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    harness = Web3.to_checksum_address(args.harness)
    owner = args.owner

    print(f"{'='*60}")
    print(f"SOVEREIGN AGENT HARNESS STATUS")
    print(f"{'='*60}")
    print(f"Harness: {harness}")
    print(f"Explorer: https://explorer.ritualfoundation.org/address/{harness}")
    print()

    # ── Code exists? ──
    code = w3.eth.get_code(harness)
    if not code or code == b"" or code == b"\x00":
        print("❌ No contract at this address!")
        sys.exit(1)
    print(f"✅ Contract deployed ({len(code)} bytes)")

    # ── Owner ──
    result = call_fn(w3, harness, "0x8da5cb5b")  # owner()
    if result and len(result) >= 20:
        owner = "0x" + result[-20:].hex()
        print(f"Owner: {owner}")

    # ── Configured ──
    result = call_fn(w3, harness, "0x0679825b")  # configured()
    if result:
        # configured() returns a big blob — check if non-empty
        configured = len(result) > 32
        print(f"Configured: {'true' if configured else 'false'}")

    # ── Wake mode (needs owner) ──
    if owner:
        result = call_fn(w3, harness, "0x55826926", from_addr=owner)  # wakeMode()
        if result:
            mode = int(result.hex(), 16)
            mode_names = {0: "NONE", 1: "ROLLING_FIXED_WINDOW"}
            print(f"Wake Mode: {mode_names.get(mode, f'UNKNOWN ({mode})')} ({mode})")

    # ── Schedule config (needs owner) ──
    if owner:
        result = call_fn(w3, harness, "0x3e5676d6", from_addr=owner)  # scheduleConfig()
        if result and len(result) >= 192:
            try:
                vals = w3.codec.decode(["uint32", "uint32", "uint32", "uint256", "uint256", "uint256"], result)
                print(f"\nSchedule Config:")
                print(f"  schedulerGas: {vals[0]:,}")
                print(f"  frequency: {vals[1]:,} blocks (~{vals[1] * 0.35 / 60:.1f} min)")
                print(f"  schedulerTtl: {vals[2]:,}")
                print(f"  maxFeePerGas: {w3.from_wei(vals[3], 'gwei')} gwei")
                print(f"  maxPriorityFeePerGas: {w3.from_wei(vals[4], 'gwei')} gwei")
                print(f"  value: {w3.from_wei(vals[5], 'ether')} RITUAL")
            except:
                pass

    # ── Rolling config (needs owner) ──
    if owner:
        result = call_fn(w3, harness, "0x618abb34", from_addr=owner)  # rollingConfig()
        if result and len(result) >= 96:
            try:
                vals = w3.codec.decode(["uint32", "uint16", "uint16"], result)
                print(f"\nRolling Config:")
                print(f"  windowNumCalls: {vals[0]}")
                print(f"  rolloverThresholdBps: {vals[1]} ({vals[1]/100}%)")
                print(f"  rolloverRetryEveryCalls: {vals[2]}")
            except:
                pass

    # ── RitualWallet balance ──
    wallet_abi = [{"name": "balanceOf", "type": "function", "stateMutability": "view",
                   "inputs": [{"name": "user", "type": "address"}], "outputs": [{"type": "uint256"}]}]
    wallet = w3.eth.contract(address=RITUAL_WALLET, abi=wallet_abi)
    balance = wallet.functions.balanceOf(harness).call()
    print(f"\nRitualWallet Balance: {w3.from_wei(balance, 'ether'):.4f} RITUAL")

    # ── Lock expiry ──
    lock_abi = [{"name": "lockUntil", "type": "function", "stateMutability": "view",
                 "inputs": [{"name": "user", "type": "address"}], "outputs": [{"type": "uint256"}]}]
    lock_contract = w3.eth.contract(address=RITUAL_WALLET, abi=lock_abi)
    lock_until = lock_contract.functions.lockUntil(harness).call()
    current_block = w3.eth.block_number
    blocks_remaining = lock_until - current_block
    days_remaining = blocks_remaining * 0.35 / 86400
    print(f"Lock Until: block {lock_until:,} ({blocks_remaining:,} blocks, ~{days_remaining:.0f} days)")

    # ── Cost estimate ──
    heartbeats = balance / w3.to_wei(0.003, "ether")  # conservative 0.003 per heartbeat
    print(f"\nEstimated heartbeats remaining: ~{int(heartbeats)}")
    print(f"Estimated days at 1x/day: ~{int(heartbeats)}")

    print(f"\n{'='*60}")


if __name__ == "__main__":
    main()
