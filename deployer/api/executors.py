"""
/api/executors — Vercel Python serverless function
Returns list of active TEE executors from Ritual Executor Registry.

GET response:
  { executors: [{ address, teeAddress, teeType, endpoint, capability, isValid }] }
"""

import json
import time
from collections import defaultdict
from http.server import BaseHTTPRequestHandler
from web3 import Web3

_rate_limits = defaultdict(list)
RATE_LIMIT_WINDOW = 60
RATE_LIMIT_MAX = 30

def _check_rate_limit(ip):
    now = time.time()
    _rate_limits[ip] = [t for t in _rate_limits[ip] if now - t < RATE_LIMIT_WINDOW]
    if len(_rate_limits[ip]) >= RATE_LIMIT_MAX:
        return False
    _rate_limits[ip].append(now)
    return True

RPC_URL = "https://rpc.ritualfoundation.org"
REGISTRY = "0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F"

REGISTRY_ABI = [{
    "name": "getServicesByCapability",
    "type": "function",
    "stateMutability": "view",
    "inputs": [
        {"name": "capability", "type": "uint8"},
        {"name": "checkValidity", "type": "bool"},
    ],
    "outputs": [{"name": "", "type": "tuple[]", "components": [
        {"name": "node", "type": "tuple", "components": [
            {"name": "paymentAddress", "type": "address"},
            {"name": "teeAddress", "type": "address"},
            {"name": "teeType", "type": "uint8"},
            {"name": "publicKey", "type": "bytes"},
            {"name": "endpoint", "type": "string"},
            {"name": "certPubKeyHash", "type": "bytes32"},
            {"name": "capability", "type": "uint8"},
        ]},
        {"name": "isValid", "type": "bool"},
        {"name": "workloadId", "type": "bytes32"},
    ]}],
}]


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            ip = self.headers.get("X-Forwarded-For", self.client_address[0]).split(",")[0].strip()
            if not _check_rate_limit(ip):
                self.send_response(429)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Rate limit exceeded"}).encode())
                return
            w3 = Web3(Web3.HTTPProvider(RPC_URL))
            registry = w3.eth.contract(address=REGISTRY, abi=REGISTRY_ABI)
            services = registry.functions.getServicesByCapability(0, True).call()

            executors = []
            for svc in services:
                node = svc[0]
                is_valid = svc[1]
                if is_valid:
                    executors.append({
                        "address": Web3.to_checksum_address(node[1]),  # teeAddress
                        "paymentAddress": Web3.to_checksum_address(node[0]),
                        "teeType": node[2],
                        "endpoint": node[4],
                        "capability": node[6],
                        "isValid": is_valid,
                    })

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "https://sovereign-deployer.vercel.app")
            self.end_headers()
            self.wfile.write(json.dumps({"executors": executors}).encode())
        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "https://sovereign-deployer.vercel.app")
            self.end_headers()
            msg = str(e).split("\n")[0][:200]
            self.wfile.write(json.dumps({"error": msg}).encode())

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "https://sovereign-deployer.vercel.app")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
