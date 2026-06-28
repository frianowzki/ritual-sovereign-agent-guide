// ═══════════════════════════════════════════════════════════
//  CONSTANTS
// ═══════════════════════════════════════════════════════════
const RITUAL_CHAIN_ID = 1979;
const RITUAL_RPC = 'https://rpc.ritualfoundation.org';
const SOVEREIGN_FACTORY = '0x9dC4C054e53bCc4Ce0A0Ff09E890A7a8e817f304';
const REGISTRY = '0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F';
const TRACKER = '0xC069FFCa0389f44eCA2C626e55491b0ab045AEF5';
const RITUAL_WALLET = '0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948';

const FACTORY_ABI = [
  "function predictHarness(address owner, bytes32 userSalt) view returns (address harness, bytes32 childSalt)",
  "function deployHarness(bytes32 userSalt) returns (address harness)",
  "event DeployHarness(address indexed owner, address indexed harness, bytes32 childSalt)"
];

const REGISTRY_ABI = [
  "function getServicesByCapability(uint8 capability, bool checkValidity) view returns (tuple(tuple(address paymentAddress, address teeAddress, uint8 teeType, bytes publicKey, string endpoint, bytes32 certPubKeyHash, uint8 capability) node, bool isValid, bytes32 workloadId)[])"
];

const WALLET_ABI = [
  "function balanceOf(address user) view returns (uint256)",
  "function lockUntil(address user) view returns (uint256)",
  "function depositFor(address user, uint256 lockDuration) payable"
];

const MODELS = {
  native: ['zai-org/GLM-4.7-FP8', 'meta-llama/Llama-3.3-70B-Instruct', 'Qwen/Qwen3-32B', 'deepseek-ai/DeepSeek-R1'],
  openrouter: ['google/gemini-2.5-flash', 'anthropic/claude-sonnet-4-5-20250929', 'openai/gpt-4o-mini', 'deepseek/deepseek-chat', 'meta-llama/llama-4-maverick'],
  openai: ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini', 'gpt-4.1-nano'],
  anthropic: ['claude-sonnet-4-5-20250929', 'claude-haiku-4-5-20250929', 'claude-opus-4-20250514'],
  gemini: ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash'],
};

const TEMPLATES = {
  default: `You are a DeFi analytics sovereign agent on Ritual Chain. Every time you wake up:

1. Fetch the top 10 cryptocurrency prices from CoinGecko API
2. Calculate 24h change percentages
3. Identify the biggest movers (gainers and losers)
4. Summarize overall market sentiment (Fear/Greed)
5. Store results in your HuggingFace dataset

Return a concise market summary with actionable insights.`,
  market: `You are a market monitoring sovereign agent. On each execution:

1. Check ETH, BTC, SOL, and top 5 altcoin prices
2. Alert if any coin moves >5% in the last hour
3. Track volume spikes (>2x average)
4. Monitor gas prices on Ethereum mainnet
5. Write a brief alert report to your dataset

Focus on actionable alerts, not general commentary.`,
  research: `You are a research sovereign agent. Each cycle:

1. Search for the latest crypto/Web3 news from the past 24 hours
2. Identify 3 most important developments
3. Analyze potential market impact of each
4. Cross-reference with on-chain data if available
5. Publish a research brief to your dataset

Be analytical and evidence-based. No speculation without data.`,
};

// Block time: ~3.5s per block on Ritual
const BLOCKS_PER_HOUR = 1029; // 3600 / 3.5

// ═══════════════════════════════════════════════════════════
//  STATE
// ═══════════════════════════════════════════════════════════
let provider = null;
let signer = null;
let userAddress = null;
let balanceInterval = null;

// ═══════════════════════════════════════════════════════════
//  WALLET
// ═══════════════════════════════════════════════════════════
async function connectWallet() {
  if (!window.ethereum) {
    alert('No wallet detected. Install MetaMask, Rabby, or another EVM wallet.');
    return;
  }
  try {
    const web3Provider = new ethers.BrowserProvider(window.ethereum);
    await web3Provider.send('eth_requestAccounts', []);
    signer = await web3Provider.getSigner();
    userAddress = await signer.getAddress();

    // Verify ownership via personal sign (no private key stored)
    try {
      const msg = `Ritual Sovereign Deployer\nAddress: ${userAddress}\nTimestamp: ${Date.now()}`;
      await signer.signMessage(msg);
    } catch(signErr) {
      if (signErr.code === 'ACTION_REJECTED') {
        alert('Signature rejected. Please sign to verify wallet ownership.');
        return;
      }
    }

    // Check chain
    const network = await web3Provider.getNetwork();
    if (Number(network.chainId) !== RITUAL_CHAIN_ID) {
      try {
        await window.ethereum.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId: '0x' + RITUAL_CHAIN_ID.toString(16) }],
        });
      } catch (switchError) {
        if (switchError.code === 4902) {
          await window.ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [{
              chainId: '0x' + RITUAL_CHAIN_ID.toString(16),
              chainName: 'Ritual Chain',
              nativeCurrency: { name: 'RITUAL', symbol: 'RITUAL', decimals: 18 },
              rpcUrls: [RITUAL_RPC],
              blockExplorerUrls: ['https://explorer.ritualfoundation.org'],
            }],
          });
        } else { throw switchError; }
      }
      const newNetwork = await web3Provider.getNetwork();
      if (Number(newNetwork.chainId) !== RITUAL_CHAIN_ID) {
        throw new Error('Please switch to Ritual Chain (ID 1979)');
      }
    }

    provider = web3Provider;
    localStorage.setItem('sr_connected', '1');
    startBalancePolling();
    updateWalletUI(true);

  } catch (err) {
    console.error(err);
    alert('Failed to connect: ' + err.message);
  }
}

function disconnectWallet() {
  stopBalancePolling();
  localStorage.removeItem('sr_connected');
  provider = null;
  signer = null;
  userAddress = null;
  setTimeout(() => location.reload(), 200);
}

function updateWalletUI(connected) {
  const dot = document.getElementById('wallet-dot');
  const status = document.getElementById('wallet-status');
  const connectBtn = document.getElementById('connect-btn');
  const disconnectBtn = document.getElementById('disconnect-btn');

  if (connected) {
    dot.classList.remove('bg-slate-600');
    dot.classList.add('bg-green-500', 'pulse-dot');
    status.textContent = `${userAddress.slice(0,6)}...${userAddress.slice(-4)}`;
    status.classList.remove('text-slate-500');
    status.classList.add('text-green-400');
    connectBtn.classList.add('hidden');
    disconnectBtn.classList.remove('hidden');
    // Fetch balance
    provider.getBalance(userAddress).then(bal => {
      const badge = document.getElementById('wallet-balance-badge');
      badge.textContent = `${parseFloat(ethers.formatEther(bal)).toFixed(2)} RITUAL`;
      badge.classList.remove('hidden');
    }).catch(()=>{});
  } else {
    dot.classList.remove('bg-green-500', 'pulse-dot');
    dot.classList.add('bg-slate-600');
    status.textContent = 'Not connected';
    status.classList.remove('text-green-400');
    status.classList.add('text-slate-500');
    connectBtn.classList.remove('hidden');
    disconnectBtn.classList.add('hidden');
    document.getElementById('wallet-balance-badge').classList.add('hidden');
  }
}

// ═══════════════════════════════════════════════════════════
//  BALANCE POLLING (real-time, every 5s)
// ═══════════════════════════════════════════════════════════
function startBalancePolling() {
  stopBalancePolling();
  balanceInterval = setInterval(async () => {
    if (!provider || !userAddress) return;
    try {
      const bal = await provider.getBalance(userAddress);
      const balFmt = parseFloat(ethers.formatEther(bal)).toFixed(2);
      const badge = document.getElementById('wallet-balance-badge');
      if (badge) {
        const prev = badge.dataset.prev || '';
        if (prev && prev !== balFmt) {
          badge.style.background = 'rgba(180,158,255,0.3)';
          setTimeout(() => { badge.style.background = 'rgba(180,158,255,0.1)'; }, 400);
        }
        badge.textContent = `${balFmt} RITUAL`;
        badge.dataset.prev = balFmt;
      }
    } catch(e) {}
  }, 5000);
}

function stopBalancePolling() {
  if (balanceInterval) { clearInterval(balanceInterval); balanceInterval = null; }
}

// ═══════════════════════════════════════════════════════════
//  AUTO-RECONNECT
// ═══════════════════════════════════════════════════════════
async function autoReconnect() {
  if (!localStorage.getItem('sr_connected')) return;
  if (!window.ethereum) return;
  try {
    const accounts = await window.ethereum.request({ method: 'eth_accounts' });
    if (!accounts || accounts.length === 0) { localStorage.removeItem('sr_connected'); return; }
    const web3Provider = new ethers.BrowserProvider(window.ethereum);
    signer = await web3Provider.getSigner();
    userAddress = await signer.getAddress();
    provider = web3Provider;
    startBalancePolling();
    updateWalletUI(true);
  } catch(e) { localStorage.removeItem('sr_connected'); }
}

// ═══════════════════════════════════════════════════════════
//  TABS
// ═══════════════════════════════════════════════════════════
function switchTab(tab) {
  ['deploy','agents','manage','status','env'].forEach(t => {
    const panel = document.getElementById(`panel-${t}`);
    if (panel) panel.classList.toggle('hidden', t !== tab);
    const btn = document.getElementById(`tab-${t}`);
    if (btn) btn.className = t === tab ? 'tab-active pb-2 text-xs font-medium transition' : 'tab-inactive pb-2 text-xs font-medium transition';
  });
}

function updateModelOptions() {
  const p = document.getElementById('d-provider').value;
  const sel = document.getElementById('d-model');
  sel.innerHTML = MODELS[p].map(m => `<option value="${m}">${m}</option>`).join('');
  document.getElementById('apikey-group').style.display = p === 'native' ? 'none' : '';
  // Refresh custom select UI
  const wrap = sel.closest('.rs-select');
  if (wrap && wrap._refreshSelect) wrap._refreshSelect();
}

// ═══════════════════════════════════════════════════════════
//  LLM SIMULATION — test provider + model before deploy
// ═══════════════════════════════════════════════════════════
async function simulateLLM() {
  const provider = document.getElementById('d-provider').value;
  const model = document.getElementById('d-model').value;
  const apiKey = document.getElementById('d-apikey')?.value.trim();
  const btn = document.getElementById('llm-test-btn');
  const resultDiv = document.getElementById('llm-test-result');

  btn.disabled = true;
  btn.innerHTML = '<svg class="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" opacity=".25"/><path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" opacity=".75"/></svg> Testing...';
  resultDiv.classList.remove('hidden');
  resultDiv.style.background = 'rgba(180,158,255,0.08)';
  resultDiv.style.border = '1px solid rgba(180,158,255,0.2)';
  resultDiv.innerHTML = `<span class="text-slate-400">Testing ${provider}/${model}...</span>`;

  const start = Date.now();

  try {
    if (provider === 'native') {
      // Test Ritual RPC reachability
      const rpc = new ethers.JsonRpcProvider(RITUAL_RPC);
      const blockNum = await rpc.getBlockNumber();
      const elapsed = Date.now() - start;
      resultDiv.innerHTML = `<span style="color:#b49eff">✓ Ritual RPC live — block #${blockNum.toLocaleString()} — ${elapsed}ms</span>`;
      resultDiv.style.background = 'rgba(180,158,255,0.1)';
      resultDiv.style.border = '1px solid rgba(180,158,255,0.3)';
    } else if (provider === 'openrouter') {
      if (!apiKey) throw new Error('Enter API key first');
      // Minimal chat call — 1 token to verify key + model
      const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model, messages: [{ role: 'user', content: 'hi' }], max_tokens: 1 })
      });
      const elapsed = Date.now() - start;
      if (resp.ok) {
        const data = await resp.json();
        const tokens = data.usage?.total_tokens || '?';
        resultDiv.innerHTML = `<span style="color:#b49eff">✓ Model responding — ${tokens} tokens — ${elapsed}ms</span>`;
      } else {
        const err = await resp.json().catch(() => ({}));
        const msg = err.error?.message || `HTTP ${resp.status}`;
        resultDiv.innerHTML = `<span class="text-red-400">✗ ${msg}</span>`;
        resultDiv.style.background = 'rgba(239,68,68,0.08)';
        resultDiv.style.border = '1px solid rgba(239,68,68,0.2)';
      }
    } else if (provider === 'openai') {
      if (!apiKey) throw new Error('Enter API key first');
      const resp = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model, messages: [{ role: 'user', content: 'hi' }], max_tokens: 1 })
      });
      const elapsed = Date.now() - start;
      if (resp.ok) {
        const data = await resp.json();
        const tokens = data.usage?.total_tokens || '?';
        resultDiv.innerHTML = `<span style="color:#b49eff">✓ Model responding — ${tokens} tokens — ${elapsed}ms</span>`;
      } else {
        const err = await resp.json().catch(() => ({}));
        const msg = err.error?.message || `HTTP ${resp.status}`;
        resultDiv.innerHTML = `<span class="text-red-400">✗ ${msg}</span>`;
        resultDiv.style.background = 'rgba(239,68,68,0.08)';
        resultDiv.style.border = '1px solid rgba(239,68,68,0.2)';
      }
    } else if (provider === 'anthropic') {
      if (!apiKey) throw new Error('Enter API key first');
      const resp = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'Content-Type': 'application/json' },
        body: JSON.stringify({ model, messages: [{ role: 'user', content: 'hi' }], max_tokens: 1 })
      });
      const elapsed = Date.now() - start;
      if (resp.ok) {
        const data = await resp.json();
        const tokens = (data.usage?.input_tokens || 0) + (data.usage?.output_tokens || 0);
        resultDiv.innerHTML = `<span style="color:#b49eff">✓ Model responding — ${tokens} tokens — ${elapsed}ms</span>`;
      } else {
        const err = await resp.json().catch(() => ({}));
        const msg = err.error?.message || `HTTP ${resp.status}`;
        resultDiv.innerHTML = `<span class="text-red-400">✗ ${msg}</span>`;
        resultDiv.style.background = 'rgba(239,68,68,0.08)';
        resultDiv.style.border = '1px solid rgba(239,68,68,0.2)';
      }
    } else if (provider === 'gemini') {
      if (!apiKey) throw new Error('Enter API key first');
      const geminiModel = model.includes('/') ? model.split('/').pop() : model;
      const resp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents: [{ parts: [{ text: 'hi' }] }], generationConfig: { maxOutputTokens: 1 } })
      });
      const elapsed = Date.now() - start;
      if (resp.ok) {
        const data = await resp.json();
        const tokens = data.usageMetadata?.totalTokenCount || '?';
        resultDiv.innerHTML = `<span style="color:#b49eff">✓ Model responding — ${tokens} tokens — ${elapsed}ms</span>`;
      } else {
        const err = await resp.json().catch(() => ({}));
        const msg = err.error?.message || `HTTP ${resp.status}`;
        resultDiv.innerHTML = `<span class="text-red-400">✗ ${msg}</span>`;
        resultDiv.style.background = 'rgba(239,68,68,0.08)';
        resultDiv.style.border = '1px solid rgba(239,68,68,0.2)';
      }
    }
  } catch (err) {
    const elapsed = Date.now() - start;
    resultDiv.innerHTML = `<span class="text-red-400">✗ ${err.message} — ${elapsed}ms</span>`;
    resultDiv.style.background = 'rgba(239,68,68,0.08)';
    resultDiv.style.border = '1px solid rgba(239,68,68,0.2)';
  } finally {
    btn.disabled = false;
    btn.innerHTML = 'Test';
  }
}

function loadTemplate(name) {
  document.getElementById('d-prompt').value = TEMPLATES[name] || '';
}

function updateEstimate() {
  const fund = parseFloat(document.getElementById('d-fund').value) || 0;
  document.getElementById('est-fund').textContent = fund.toFixed(2);
  document.getElementById('est-total').textContent = (fund + 0.02).toFixed(2);
}

// ═══════════════════════════════════════════════════════════
//  SCHEDULE VALIDATION
// ═══════════════════════════════════════════════════════════
function validateSchedule() {
  const freq = parseInt(document.getElementById('d-freq').value) || 0;
  const calls = parseInt(document.getElementById('d-window').value) || 0;
  const total = freq * calls;
  const totalEl = document.getElementById('sched-total');
  const statusEl = document.getElementById('sched-status');

  totalEl.textContent = `${freq.toLocaleString()} × ${calls} = ${total.toLocaleString()} blocks`;

  if (total > 100000) {
    statusEl.textContent = 'Very high — verify gas costs';
    statusEl.className = 'font-semibold';
    statusEl.style.color = '#ef4444';
    totalEl.style.color = '#ef4444';
  } else if (total > 10000) {
    statusEl.textContent = 'High — double check fees';
    statusEl.className = 'font-semibold';
    statusEl.style.color = '#eab308';
    totalEl.style.color = '#eab308';
  } else {
    statusEl.textContent = 'Recommended range';
    statusEl.className = 'font-semibold';
    statusEl.style.color = '#b49eff';
    totalEl.style.color = '#b49eff';
  }
}

// ═══════════════════════════════════════════════════════════
//  DEPLOY
// ═══════════════════════════════════════════════════════════
async function deployAgent() {
  if (!signer || !userAddress) { alert('Connect wallet first'); return; }

  const apiKey = document.getElementById('d-apikey').value.trim();
  const provider_name = document.getElementById('d-provider').value;
  const model = document.getElementById('d-model').value;
  const hfToken = document.getElementById('d-hftoken').value.trim();
  const hfRepo = document.getElementById('d-hfrepo').value.trim();
  const salt = document.getElementById('d-salt').value.trim();
  const prompt = document.getElementById('d-prompt').value.trim();
  const freq = parseInt(document.getElementById('d-freq').value);
  const windowCalls = parseInt(document.getElementById('d-window').value);
  const schedulerTtl = parseInt(document.getElementById('d-schedttl').value) || 500;
  const fundAmount = parseFloat(document.getElementById('d-fund').value);

  // Pre-flight: check for pending async job
  const TRACKER_ABI_LOCAL = ["function hasPendingJobForSender(address sender) view returns (bool)"];
  try {
    const tracker = new ethers.Contract(TRACKER, TRACKER_ABI_LOCAL, provider);
    const hasPending = await tracker.hasPendingJobForSender(userAddress);
    if (hasPending) {
      alert('You have a pending async job. Wait for it to expire (up to ~1 hour) or use a different wallet.');
      btn.disabled = false;
      btn.innerHTML = 'Deploy Sovereign Agent';
      return;
    }
  } catch(e) { console.warn('Pending check failed:', e.message); }

  const scheduleTotal = freq * windowCalls;
  if (scheduleTotal > 100000) {
    alert(`Schedule extremely high: ${freq} × ${windowCalls} = ${scheduleTotal} blocks. Consider reducing to avoid excessive gas costs.`);
    return;
  }
  if (fundAmount < 0.25) {
    alert(`Minimum fund is 0.25 RITUAL.`);
    return;
  }

  const maxBudget = parseFloat(document.getElementById('d-maxbudget').value);
  const lockDuration = parseInt(document.getElementById('d-lockduration').value);
  const gasLimit = parseInt(document.getElementById('d-gaslimit').value) || 5_000_000;
  const deployGasLimit = parseInt(document.getElementById('d-deploygas').value) || 3_500_000;
  const schedulerGas = parseInt(document.getElementById('d-schedgas').value) || 800_000;
  const rolloverBps = parseInt(document.getElementById('d-rolloverbps').value) || 5000;
  const rolloverRetry = parseInt(document.getElementById('d-rolloverretry').value) || 1;
  const maxFeeGwei = parseInt(document.getElementById('d-maxfee').value) || 20;
  const priorityFeeGwei = parseInt(document.getElementById('d-priorityfee').value) || 1;

  if ((provider_name !== 'native' && !apiKey) || !hfToken || !hfRepo) {
    alert('Fill in all required fields');
    return;
  }

  const progressDiv = document.getElementById('deploy-progress');
  progressDiv.classList.remove('hidden');
  const termDiv = document.getElementById('deploy-terminal');
  termDiv.innerHTML = '';
  const btn = document.getElementById('deploy-btn');
  btn.disabled = true;
  btn.innerHTML = 'Deploying...';

  try {
    updateProgress(33, 'Step 1/3 — Deploy Harness');
    log(termDiv, 'comment', '── Step 1: deployHarness ──');

    const factory = new ethers.Contract(SOVEREIGN_FACTORY, FACTORY_ABI, signer);
    const userSalt = ethers.keccak256(ethers.toUtf8Bytes(salt));

    log(termDiv, 'cmd', `Salt: ${salt} → ${userSalt.slice(0,18)}...`);

    const [predicted, childSalt] = await factory.predictHarness(userAddress, userSalt);
    log(termDiv, 'info', `Predicted: ${predicted}`);

    const code = await provider.getCode(predicted);
    let harnessAddr = predicted;

    if (code && code !== '0x' && code !== '0x0') {
      log(termDiv, 'warn', `Harness already exists at ${predicted}`);
    } else {
      log(termDiv, 'cmd', 'Sending deployHarness tx...');
      const tx = await factory.deployHarness(userSalt, { gasLimit: deployGasLimit });
      log(termDiv, 'info', `TX: <a href='https://explorer.ritualfoundation.org/tx/${tx.hash}' target='_blank' class='tx-hash'>${tx.hash}</a>`);
      log(termDiv, 'cmd', 'Waiting for confirmation...');

      let receipt = null;
      for (let i = 0; i < 30; i++) {
        await new Promise(r => setTimeout(r, 5000));
        try {
          const rawReceipt = await provider.send('eth_getTransactionReceipt', [tx.hash]);
          if (rawReceipt) { receipt = rawReceipt; break; }
        } catch(e) {}
      }
      if (!receipt) throw new Error('deployHarness timed out after 150s — check explorer for tx status');
      const status = receipt.status === '0x1' || receipt.status === '0x01' || receipt.status === 1;
      if (!status) throw new Error('deployHarness reverted');
      log(termDiv, 'info', `Confirmed block ${parseInt(receipt.blockNumber, 16)}`);
      log(termDiv, 'success', `Harness deployed: ${harnessAddr}`);
    }

    updateProgress(66, 'Step 2/3 — Prepare');
    log(termDiv, 'comment', '── Step 2: Prepare ──');

    updateProgress(90, 'Step 3/3 — Configure & Fund');
    log(termDiv, 'comment', '── Step 3: configureFundAndStart ──');
    log(termDiv, 'cmd', `Fund: ${fundAmount} RITUAL | Lock: ${lockDuration} blocks | Freq: ${freq} blocks`);

    const secretsObj = { LLM_PROVIDER: provider_name, HF_TOKEN: hfToken };
    if (provider_name === 'openrouter') secretsObj.OPENROUTER_API_KEY = apiKey;
    else if (provider_name === 'openai') secretsObj.OPENAI_API_KEY = apiKey;
    else if (provider_name === 'anthropic') secretsObj.ANTHROPIC_API_KEY = apiKey;
    else if (provider_name === 'gemini') secretsObj.GEMINI_API_KEY = apiKey;

    let fullCalldata;
    try {
      // Get selected executor (if any)
      const selectedExec = getSelectedExecutor();
      if (selectedExec) {
        log(termDiv, 'info', `Selected executor: ${selectedExec.address.slice(0,10)}...${selectedExec.address.slice(-8)}`);
      }
      
      const encodeResp = await fetch('/api/encode', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          harness: harnessAddr,
          prompt: prompt || 'You are a sovereign AI agent on Ritual Chain.',
          model: model,
          hfRepo: hfRepo,
          hfToken: hfToken,
          secrets: JSON.stringify(secretsObj),
          fundAmount: fundAmount.toString(),
          frequency: freq,
          windowCalls: windowCalls,
          lockDuration: lockDuration,
          schedulerGas: schedulerGas,
          schedulerTtl: schedulerTtl,
          rolloverBps: rolloverBps,
          rolloverRetry: rolloverRetry,
          maxFeeGwei: maxFeeGwei,
          priorityFeeGwei: priorityFeeGwei,
          cliType: parseInt(document.querySelector('input[name="cli-type"]:checked')?.value || '6'),
          sender: userAddress,
          executorAddress: selectedExec ? selectedExec.address : null
        })
      });

      if (!encodeResp.ok) {
        const err = await encodeResp.json();
        throw new Error(err.error || 'Encoding failed');
      }

      const encodeResult = await encodeResp.json();
      fullCalldata = encodeResult.calldata;
      log(termDiv, 'info', `Executor: <a href='https://explorer.ritualfoundation.org/address/${encodeResult.executor}' target='_blank' class='tx-hash'>${encodeResult.executor}</a>`);
      const cliTypeLabel = document.querySelector('input[name="cli-type"]:checked')?.value === '5' ? 'Crush' : 'ZeroClaw';
      log(termDiv, 'info', `CLI Runtime: ${cliTypeLabel} (type ${document.querySelector('input[name="cli-type"]:checked')?.value || '6'})`);
      log(termDiv, 'info', `Secrets: ${encodeResult.encryptedSize} bytes | Calldata: ${encodeResult.calldataSize} bytes`);
    } catch (encodeErr) {
      throw new Error(`Calldata encoding failed: ${encodeErr.message}`);
    }

    const txValue = ethers.parseEther(fundAmount.toString());

    // Simulate
    log(termDiv, 'cmd', 'Simulating...');
    try {
      await provider.send('eth_call', [{
        from: userAddress,
        to: harnessAddr,
        value: '0x' + txValue.toString(16),
        data: fullCalldata,
        gasLimit: '0x' + gasLimit.toString(16),
      }, 'latest']);
      log(termDiv, 'success', 'Simulation passed');
    } catch (simErr) {
      const simMsg = simErr.data?.message || simErr.message || 'unknown revert';
      log(termDiv, 'error', `Simulation REVERTED: ${simMsg}`);
      throw new Error(`Simulation reverted: ${simMsg}. Check: funds in RitualWallet, no pending jobs, correct params.`);
    }

    log(termDiv, 'cmd', 'Sending configureFundAndStart tx...');
    const tx2 = await signer.sendTransaction({
      to: harnessAddr,
      value: txValue,
      data: fullCalldata,
      gasLimit: gasLimit,
    });
    log(termDiv, 'info', `TX: <a href='https://explorer.ritualfoundation.org/tx/${tx2.hash}' target='_blank' class='tx-hash'>${tx2.hash}</a>`);
    log(termDiv, 'cmd', 'Waiting for confirmation...');

    // Receipt: 30 attempts × 5s = 150s. On Ritual blocks are ~350ms, should confirm in 1-2 blocks.
    let receipt2 = null;
    for (let i = 0; i < 30; i++) {
      await new Promise(r => setTimeout(r, 5000));
      try {
        const rawReceipt = await provider.send('eth_getTransactionReceipt', [tx2.hash]);
        if (rawReceipt) { receipt2 = rawReceipt; break; }
      } catch(e) {}
    }

    if (!receipt2) throw new Error('Transaction timed out after 150s — check explorer manually');
    const status2 = receipt2.status === '0x1' || receipt2.status === '0x01' || receipt2.status === 1;
    if (!status2) throw new Error('configureFundAndStart reverted on-chain');
    log(termDiv, 'info', `Confirmed block ${parseInt(receipt2.blockNumber, 16)}`);

    // ── Phase 2: Wait for async callback to complete ──
    // configureFundAndStart has TWO phases:
    //   Phase 1 (sync): TX mined, funds deposited — we just confirmed this
    //   Phase 2 (async): TEE executor picks up job, encrypts secrets, configures agent
    // Phase 2 can take 1-5 minutes. We poll configured() to detect it.
    log(termDiv, 'cmd', 'TX confirmed. Waiting for TEE callback (async phase)...');
    log(termDiv, 'info', 'This takes 1-5 min — the TEE executor must pick up and arm the scheduler.');

    updateProgress(95, 'Step 3/3 — Waiting for TEE callback');

    let agentConfigured = false;
    const rpcProvider = new ethers.JsonRpcProvider(RITUAL_RPC);

    for (let i = 0; i < 60; i++) {  // 60 × 5s = 300s = 5 min max
      await new Promise(r => setTimeout(r, 5000));
      try {
        // Check wakeMode: 0=uninit, 1=stopped, 2=configured, 3+=armed
        const wmResult = await rpcProvider.call({ to: harnessAddr, data: '0xc9777451' });
        const wakeMode = parseInt(wmResult.hex(), 16);
        if (wakeMode >= 3) {
          agentConfigured = true;
          break;
        }
        // Also check state selector as fallback
        const stateResult = await rpcProvider.call({ to: harnessAddr, data: '0x24974129' });
        const state = parseInt(stateResult.hex(), 16);
        if (state >= 2 && i >= 12) {  // state=2 after 60s = good enough
          agentConfigured = true;
          break;
        }
      } catch(e) {}
      // Progress feedback every 30s
      if ((i + 1) % 6 === 0) {
        log(termDiv, 'info', `Still waiting... (${Math.round((i + 1) * 5 / 60)} min elapsed)`);
      }
    }

    if (!agentConfigured) {
      // Callback didn't complete in 5 min — funds are deposited but agent unconfigured
      updateProgress(100, 'Partial — needs manual restart');
      log(termDiv, 'warn', '═══════════════════════════════════════');
      log(termDiv, 'warn', 'TX confirmed but agent not armed in 5 min.');
      log(termDiv, 'warn', 'Funds deposited. Agent deployed but scheduler not armed.');
      log(termDiv, 'warn', 'Go to Deploy tab with SAME salt to re-trigger configureFundAndStart.');
      log(termDiv, 'warn', '═══════════════════════════════════════');
      log(termDiv, 'info', `Harness: <a href='https://explorer.ritualfoundation.org/agents/${harnessAddr}' target='_blank' class='tx-hash'>${harnessAddr}</a>`);

      btn.innerHTML = 'Needs Restart';
      btn.classList.remove('btn-primary');
      btn.classList.add('btn-outline');
    } else {
      // Full success
      updateProgress(100, 'Complete');
      log(termDiv, 'success', '═══════════════════════════════════════');
      log(termDiv, 'success', `SOVEREIGN AGENT DEPLOYED & ARMED`);
      log(termDiv, 'success', `Harness: <a href='https://explorer.ritualfoundation.org/agents/${harnessAddr}' target='_blank' class='tx-hash'>${harnessAddr}</a>`);
      log(termDiv, 'success', `Model: ${model} | Fund: ${fundAmount} RITUAL`);
      log(termDiv, 'success', '═══════════════════════════════════════');

      btn.innerHTML = 'Deployed!';
      btn.classList.remove('btn-primary');
      btn.classList.add('btn-outline');
    }

    // Save to localStorage for My Agents
    const agents = JSON.parse(localStorage.getItem('sr_agents') || '[]');
    if (!agents.find(a => a.address.toLowerCase() === harnessAddr.toLowerCase())) {
      agents.push({ address: harnessAddr, salt, timestamp: Date.now() });
      localStorage.setItem('sr_agents', JSON.stringify(agents));
    }

  } catch (err) {
    console.error(err);
    log(termDiv, 'error', `Error: ${err.message}`);
    btn.disabled = false;
    btn.innerHTML = 'Retry Deploy';
  }
}

// ═══════════════════════════════════════════════════════════
//  CHECK STATUS (ON-CHAIN) — clean, no pills/badges
// ═══════════════════════════════════════════════════════════
async function checkStatusOnChain() {
  const harness = document.getElementById('s-agent').value.trim();
  if (!harness) { alert('Enter a harness address'); return; }

  const btn = document.getElementById('status-btn');
  btn.disabled = true;
  btn.innerHTML = 'Checking...';

  const resultDiv = document.getElementById('status-result');
  resultDiv.classList.remove('hidden');
  const content = document.getElementById('status-content');
  content.innerHTML = '<p class="text-sm text-slate-500">Loading...</p>';

  try {
    const rpcProvider = new ethers.JsonRpcProvider(RITUAL_RPC);
    const code = await rpcProvider.getCode(harness);
    const hasCode = code && code !== '0x' && code !== '0x0';

    let owner = 'N/A', balance = 0n, lockUntil = 0n, currentBlock = 0;
    let blocksRemaining = 0, daysRemaining = 0, heartbeats = 0;

    if (hasCode) {
      try {
        const result = await rpcProvider.call({ to: harness, data: '0x8da5cb5b' });
        owner = '0x' + result.slice(26);
      } catch(e) {}

      const wallet = new ethers.Contract(RITUAL_WALLET, WALLET_ABI, rpcProvider);
      balance = await wallet.balanceOf(harness);
      lockUntil = await wallet.lockUntil(harness);
      currentBlock = await rpcProvider.getBlockNumber();
      blocksRemaining = Number(lockUntil) - currentBlock;
      daysRemaining = blocksRemaining * BLOCKS_PER_HOUR / 1029 / 24;
      heartbeats = Number(balance) / Number(ethers.parseEther('0.003'));
    }

    if (!hasCode) {
      content.innerHTML = `
        <div class="space-y-3">
          <p class="text-red-400 text-sm">No contract at this address</p>
          <p class="text-xs text-slate-500">This address has no deployed bytecode on Ritual Chain.</p>
          <div class="flex justify-center gap-3 pt-2">
            <a href="https://explorer.ritualfoundation.org/address/${harness}" target="_blank" class="btn-outline rounded-lg px-3 py-1.5 text-xs">View on Explorer</a>
          </div>
        </div>
      `;
      return;
    }

    content.innerHTML = `
      <div class="space-y-3">
        <div class="space-y-1.5">
          <div class="flex justify-between text-sm">
            <span class="text-slate-500">Bytecode</span>
            <span class="text-slate-300">${(code.length - 2) / 2} bytes</span>
          </div>
          <div class="flex justify-between text-sm">
            <span class="text-slate-500">Owner</span>
            <span class="text-slate-300 mono text-xs">${owner.length > 10 ? owner.slice(0,10) + '...' + owner.slice(-8) : owner}</span>
          </div>
          <div class="flex justify-between text-sm">
            <span class="text-slate-500">Balance</span>
            <span style="color:#b49eff" class="font-semibold">${ethers.formatEther(balance)} RITUAL</span>
          </div>
          <div class="flex justify-between text-sm">
            <span class="text-slate-500">Lock Until</span>
            <span class="text-slate-300">Block ${Number(lockUntil).toLocaleString()} ${blocksRemaining > 0 ? '(~' + Math.round(blocksRemaining / BLOCKS_PER_HOUR) + 'h left)' : blocksRemaining < 0 ? '(expired)' : ''}</span>
          </div>
          <div class="flex justify-between text-sm">
            <span class="text-slate-500">Est. Heartbeats</span>
            <span class="text-slate-300">~${Math.round(heartbeats)}</span>
          </div>
        </div>
        <div class="flex justify-center gap-3 pt-2 border-t border-white/5">
          <a href="https://explorer.ritualfoundation.org/agents/${harness}" target="_blank" class="btn-outline rounded-lg px-3 py-1.5 text-xs">View Agent</a>
          <a href="https://explorer.ritualfoundation.org/agents" target="_blank" class="btn-outline rounded-lg px-3 py-1.5 text-xs">All Agents</a>
        </div>
      </div>
    `;
  } catch (err) {
    content.innerHTML = `<p class="text-red-400 text-sm">Error: ${err.message}</p>`;
  } finally {
    btn.disabled = false;
    btn.innerHTML = 'Check Status';
  }
}

// ═══════════════════════════════════════════════════════════
//  SMOKE TEST — validate HF + LLM before on-chain
// ═══════════════════════════════════════════════════════════
let smokeTestPassed = false;

function checkSmokeTestReady() {
  const hfRepo = document.getElementById('d-hfrepo')?.value.trim();
  const hfToken = document.getElementById('d-hftoken')?.value.trim();
  const provider = document.getElementById('d-provider')?.value;
  const apiKey = document.getElementById('d-apikey')?.value.trim();
  
  const btn = document.getElementById('smoke-test-btn');
  if (!btn) return;
  
  const hfReady = hfRepo && hfRepo.includes('/') && hfToken && hfToken.startsWith('hf_');
  const llmReady = provider === 'native' || (apiKey && apiKey.length > 10);
  
  btn.disabled = !(hfReady && llmReady);
  
  // Reset smoke test result if inputs change
  if (smokeTestPassed && !(hfReady && llmReady)) {
    smokeTestPassed = false;
    const result = document.getElementById('smoke-test-result');
    if (result) result.classList.add('hidden');
  }
}

async function runSmokeTest() {
  const btn = document.getElementById('smoke-test-btn');
  const resultDiv = document.getElementById('smoke-test-result');
  btn.disabled = true;
  btn.innerHTML = '<svg class="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" opacity="0.25"/><path fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" opacity="0.75"/></svg> Testing...';
  resultDiv.classList.remove('hidden');
  resultDiv.style.background = 'rgba(255,255,255,0.05)';
  resultDiv.style.border = '1px solid rgba(255,255,255,0.1)';
  resultDiv.innerHTML = '<span class="text-slate-400">Running smoke tests...</span>';
  
  const results = [];
  
  try {
    // Test 1: HF token + repo
    const hfRepo = document.getElementById('d-hfrepo').value.trim();
    const hfToken = document.getElementById('d-hftoken').value.trim();
    
    resultDiv.innerHTML = '<span class="text-slate-400">Testing HuggingFace credentials...</span>';
    
    const hfResp = await fetch(`https://huggingface.co/api/datasets/${hfRepo}`, {
      headers: { 'Authorization': `Bearer ${hfToken}` }
    });
    
    if (hfResp.ok) {
      results.push('<span style="color:#b49eff">✓ HF dataset accessible</span>');
    } else if (hfResp.status === 401) {
      results.push('<span class="text-red-400">✗ HF token invalid or expired</span>');
    } else if (hfResp.status === 404) {
      results.push('<span class="text-red-400">✗ HF dataset not found — create it first</span>');
    } else {
      results.push(`<span class="text-yellow-400">⚠ HF check returned ${hfResp.status}</span>`);
    }
    
    // Test 2: LLM key (skip for native)
    const provider = document.getElementById('d-provider').value;
    if (provider === 'native') {
      results.push('<span style="color:#b49eff">✓ Ritual Native (no key needed)</span>');
    } else {
      const apiKey = document.getElementById('d-apikey').value.trim();
      resultDiv.innerHTML = '<span class="text-slate-400">Testing LLM API key...</span>';
      
      if (provider === 'openrouter') {
        const orResp = await fetch('https://openrouter.ai/api/v1/models', {
          headers: { 'Authorization': `Bearer ${apiKey}` }
        });
        if (orResp.ok) {
          results.push('<span style="color:#b49eff">✓ OpenRouter key valid</span>');
        } else if (orResp.status === 401) {
          results.push('<span class="text-red-400">✗ OpenRouter key invalid</span>');
        } else {
          results.push(`<span class="text-yellow-400">⚠ OpenRouter check returned ${orResp.status}</span>`);
        }
      } else {
        // For OpenAI/Anthropic/Gemini, just check key format
        const validPrefixes = {
          openai: ['sk-'],
          anthropic: ['sk-ant-'],
          gemini: ['AIza']
        };
        const prefixes = validPrefixes[provider] || [];
        if (prefixes.some(p => apiKey.startsWith(p))) {
          results.push(`<span style="color:#b49eff">✓ ${provider} key format valid</span>`);
        } else {
          results.push(`<span class="text-yellow-400">⚠ ${provider} key format unexpected — will be tested on-chain</span>`);
        }
      }
    }
    
    // Show results
    const allPassed = results.every(r => r.includes('color:#b49eff') || r.includes('✓'));
    smokeTestPassed = allPassed;
    
    resultDiv.style.background = allPassed ? 'rgba(180,158,255,0.1)' : 'rgba(239,68,68,0.1)';
    resultDiv.style.border = allPassed ? '1px solid rgba(180,158,255,0.3)' : '1px solid rgba(239,68,68,0.3)';
    resultDiv.innerHTML = results.join('<br>');
    
    smokeTestPassed = allPassed;
    
  } catch (err) {
    resultDiv.style.background = 'rgba(239,68,68,0.1)';
    resultDiv.style.border = '1px solid rgba(239,68,68,0.3)';
    resultDiv.innerHTML = `<span class="text-red-400">✗ Network error: ${err.message}</span>`;
    smokeTestPassed = false;
  } finally {
    btn.disabled = false;
    btn.innerHTML = '<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg> ' + (smokeTestPassed ? 'TEST PASSED ✓' : 'RETRY TEST');
  }
}

// ═══════════════════════════════════════════════════════════
//  EXECUTOR HEALTH — delivery rate + deploy window
// ═══════════════════════════════════════════════════════════
async function updateExecutorHealth() {
  const dot = document.getElementById('health-dot');
  const text = document.getElementById('health-text');
  if (!dot || !text) return;
  
  try {
    let executors = [];
    try {
      const resp = await fetch('/api/executors');
      if (resp.ok) {
        const data = await resp.json();
        executors = data.executors || [];
      }
    } catch(e) {}
    
    const count = executors.length;
    let color, label;
    
    if (count > 5) {
      color = '#b49eff';
      label = `${count} active executors`;
    } else if (count >= 3) {
      color = '#eab308';
      label = `${count} active executors — Deploy possible but limited`;
    } else if (count > 0) {
      color = '#ef4444';
      label = `${count} active executors — Deploy risky, wait for more`;
    } else {
      color = '#ef4444';
      label = 'No active executors — Cannot deploy right now';
    }
    
    dot.style.background = color;
    text.textContent = label;
    text.style.color = color;
  } catch(e) {
    dot.style.background = '#64748b';
    text.textContent = 'Executor health unavailable';
    text.style.color = '#64748b';
  }
}

// ═══════════════════════════════════════════════════════════
//  EXECUTOR MANAGEMENT — fetch from registry, dropdown, details
// ═══════════════════════════════════════════════════════════
let cachedExecutors = [];

async function refreshExecutors() {
  const sel = document.getElementById('d-executor');
  const btn = document.getElementById('executor-refresh-btn');
  const countEl = document.getElementById('executor-count');
  const detailsDiv = document.getElementById('executor-details');
  
  sel.innerHTML = '<option value="">Loading...</option>';
  btn.disabled = true;
  btn.textContent = '...';
  
  try {
    // Try API first
    let executors = [];
    try {
      const resp = await fetch('/api/executors');
      if (resp.ok) {
        const data = await resp.json();
        executors = data.executors || [];
      }
    } catch(e) {}
    
    // Fallback: fetch directly from chain
    if (executors.length === 0) {
      try {
        const rpcProvider = new ethers.JsonRpcProvider(RITUAL_RPC);
        const registry = new ethers.Contract(REGISTRY, REGISTRY_ABI, rpcProvider);
        const services = await registry.getServicesByCapability(0, true);
        for (const svc of services) {
          if (svc.isValid) {
            executors.push({
              address: svc.node.teeAddress,
              paymentAddress: svc.node.paymentAddress,
              teeType: Number(svc.node.teeType),
              endpoint: svc.node.endpoint,
              capability: Number(svc.node.capability),
            });
          }
        }
      } catch(e) { console.warn('Chain fetch failed:', e.message); }
    }
    
    cachedExecutors = executors;
    sel.innerHTML = '';
    
    if (executors.length === 0) {
      sel.innerHTML = '<option value="">No executors found</option>';
      countEl.textContent = 'Registry returned 0 active executors.';
      return;
    }
    
    // Populate dropdown
    executors.forEach((exec, i) => {
      const opt = document.createElement('option');
      opt.value = i;
      const shortAddr = exec.address.slice(0, 8) + '...' + exec.address.slice(-6);
      const endpoint = exec.endpoint ? ` (${exec.endpoint.slice(0, 30)})` : '';
      opt.textContent = `${shortAddr}${endpoint}`;
      sel.appendChild(opt);
    });
    
    countEl.textContent = `${executors.length} active executor${executors.length > 1 ? 's' : ''} found`;
    
    // Show details for first executor
    showExecutorDetails(0);
    sel.addEventListener('change', () => showExecutorDetails(parseInt(sel.value)));
    // Refresh custom select UI
    const wrap = sel.closest('.rs-select');
    if (wrap && wrap._refreshSelect) wrap._refreshSelect();
    
  } catch (err) {
    sel.innerHTML = `<option value="">Error: ${err.message}</option>`;
    countEl.textContent = 'Failed to load executors.';
  } finally {
    btn.disabled = false;
    btn.textContent = 'Refresh';
    updateExecutorHealth();
  }
}

function showExecutorDetails(index) {
  const detailsDiv = document.getElementById('executor-details');
  const exec = cachedExecutors[index];
  if (!exec) {
    detailsDiv.classList.add('hidden');
    return;
  }
  
  detailsDiv.classList.remove('hidden');
  document.getElementById('exec-addr').textContent = exec.address.slice(0, 10) + '...' + exec.address.slice(-8);
  document.getElementById('exec-payment').textContent = exec.paymentAddress ? exec.paymentAddress.slice(0, 10) + '...' + exec.paymentAddress.slice(-8) : '—';
  document.getElementById('exec-endpoint').textContent = exec.endpoint || '—';
  document.getElementById('exec-teetype').textContent = exec.teeType === 0 ? 'SGX' : exec.teeType === 1 ? 'TDX' : `Type ${exec.teeType}`;
}

function getSelectedExecutor() {
  const sel = document.getElementById('d-executor');
  const index = parseInt(sel.value);
  if (isNaN(index) || !cachedExecutors[index]) return null;
  return cachedExecutors[index];
}

// Load executors on page load
document.addEventListener('DOMContentLoaded', () => {
  setTimeout(refreshExecutors, 1000);
  setTimeout(updateExecutorHealth, 1500);
  
  // Wire smoke test readiness check to inputs
  ['d-hfrepo', 'd-hftoken', 'd-provider', 'd-apikey'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.addEventListener('input', checkSmokeTestReady);
  });
  checkSmokeTestReady();
  
  // Gooey input — Enter key triggers check
  const sAgentInput = document.getElementById('s-agent');
  if (sAgentInput) {
    sAgentInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') checkStatusOnChain();
    });
  }

  // ═══ ENCRYPTED TEXT HERO ═══
  initEncryptedText();

  // ═══ SHADCN CUSTOM SELECTS ═══
  initCustomSelects();

});

// ═══════════════════════════════════════════════════════════
//  ENCRYPTED TEXT — Aceternity-style character scramble
// ═══════════════════════════════════════════════════════════
function initEncryptedText() {
  const el = document.getElementById('hero-title');
  if (!el) return;
  const finalText = el.getAttribute('data-text') || el.textContent;
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,./<>?~`';
  const totalDuration = 1800;
  const frameInterval = 40;
  const totalFrames = Math.ceil(totalDuration / frameInterval);

  // Wrap each character in a span
  el.innerHTML = '';
  const spans = [];
  for (let i = 0; i < finalText.length; i++) {
    const span = document.createElement('span');
    span.className = 'encrypted-char';
    if (finalText[i] === ' ') {
      span.innerHTML = '&nbsp;';
      span.style.minWidth = '0.3em';
    } else {
      span.textContent = chars[Math.floor(Math.random() * chars.length)];
      span.classList.add('scrambling');
    }
    el.appendChild(span);
    spans.push({ span, final: finalText[i], isSpace: finalText[i] === ' ' });
  }

  // Calculate per-char delay based on position (left to right reveal)
  let frame = 0;
  const timer = setInterval(() => {
    frame++;
    const progress = frame / totalFrames;
    for (let i = 0; i < spans.length; i++) {
      const { span, final, isSpace } = spans[i];
      if (isSpace) continue;
      // Each char starts scrambling at a staggered time
      const charStart = (i / spans.length) * 0.6;
      const charEnd = charStart + 0.4;
      if (progress >= charEnd) {
        span.textContent = final;
        span.classList.remove('scrambling');
      } else if (progress >= charStart) {
        span.textContent = chars[Math.floor(Math.random() * chars.length)];
      }
    }
    if (frame >= totalFrames) {
      clearInterval(timer);
      // Ensure all chars are final
      for (const { span, final } of spans) {
        span.textContent = final;
        span.classList.remove('scrambling');
      }
    }
  }, frameInterval);
}

function randomizeSalt() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let salt = 'agent-';
  for (let i = 0; i < 8; i++) salt += chars[Math.floor(Math.random() * chars.length)];
  document.getElementById('d-salt').value = salt;
}

// ═══════════════════════════════════════════════════════════
//  MANAGE — Deposit / Restart / Stop
// ═══════════════════════════════════════════════════════════
async function depositToWallet() {
  if (!signer || !userAddress) { alert('Connect wallet first'); return; }
  const agent = document.getElementById('m-deposit-agent').value.trim();
  const amount = parseFloat(document.getElementById('m-deposit-amount').value);
  const lockBlocks = parseInt(document.getElementById('m-deposit-lock').value);
  if (!agent) { alert('Enter an agent address'); return; }
  if (!amount || amount <= 0) { alert('Enter a valid amount'); return; }

  const btn = document.getElementById('deposit-btn');
  const termDiv = document.getElementById('deposit-terminal');
  termDiv.classList.remove('hidden');
  termDiv.innerHTML = '';
  btn.disabled = true;
  btn.innerHTML = 'Depositing...';

  try {
    log(termDiv, 'comment', `Deposit ${amount} RITUAL to ${agent}`);
    const wallet = new ethers.Contract(RITUAL_WALLET, WALLET_ABI, signer);
    const value = ethers.parseEther(amount.toString());
    const tx = await wallet.depositFor(agent, lockBlocks, { value, gasLimit: 3_000_000 });
    log(termDiv, 'info', `TX: <a href='https://explorer.ritualfoundation.org/tx/${tx.hash}' target='_blank' class='tx-hash'>${tx.hash}</a>`);
    let receipt = null;
    for (let i = 0; i < 30; i++) {
      await new Promise(r => setTimeout(r, 5000));
      try { const raw = await provider.send('eth_getTransactionReceipt', [tx.hash]); if (raw) { receipt = raw; break; } } catch(e) {}
    }
    if (!receipt) throw new Error('Transaction timed out after 150s');
    const status = receipt.status === '0x1' || receipt.status === '0x01' || receipt.status === 1;
    if (!status) throw new Error('Deposit reverted');
    log(termDiv, 'success', `Deposited ${amount} RITUAL to ${agent}`);
    log(termDiv, 'info', `TX: <a href='https://explorer.ritualfoundation.org/tx/${tx.hash}' target='_blank' class='tx-hash'>View TX</a>`);
  } catch (err) {
    log(termDiv, 'error', `Error: ${err.message}`);
  } finally {
    btn.disabled = false;
    btn.innerHTML = 'Deposit';
  }
}

async function restartAgent() {
  if (!signer || !userAddress) { alert('Connect wallet first'); return; }
  const agent = document.getElementById('m-restart-agent').value.trim();
  if (!agent) { alert('Enter an agent address'); return; }

  const btn = document.getElementById('restart-btn');
  const termDiv = document.getElementById('restart-terminal');
  termDiv.classList.remove('hidden');
  termDiv.innerHTML = '';
  btn.disabled = true;
  btn.innerHTML = 'Checking...';

  try {
    log(termDiv, 'comment', `Diagnose agent ${agent.slice(0,10)}...`);

    const rpcProvider = new ethers.JsonRpcProvider(RITUAL_RPC);
    const wallet = new ethers.Contract(RITUAL_WALLET, WALLET_ABI, rpcProvider);

    // Check on-chain state
    let isRunning = false;
    try {
      const r = await rpcProvider.call({ to: agent, data: '0x2014e5d1' }); // isRunning()
      isRunning = r.length >= 32 ? r[31] === 1 : false;
    } catch(e) {}

    let wakeCount = 0n;
    try {
      const r = await rpcProvider.call({ to: agent, data: '0x46cebb38' }); // wakeCount()
      wakeCount = BigInt(r);
    } catch(e) {}

    const balance = await wallet.balanceOf(agent);
    const lockUntil = await wallet.lockUntil(agent);
    const currentBlock = await rpcProvider.getBlockNumber();
    const balFmt = parseFloat(ethers.formatEther(balance)).toFixed(4);
    const blocksLeft = Number(lockUntil) - currentBlock;
    const hoursLeft = Math.max(0, Math.round(blocksLeft * 3.5 / 3600));

    log(termDiv, 'info', `Balance: ${balFmt} RITUAL | Lock: ${hoursLeft > 0 ? hoursLeft + 'h left' : 'expired'}`);
    log(termDiv, 'info', `Running: ${isRunning} | Wakes: ${wakeCount}`);

    if (!isRunning) {
      log(termDiv, 'warn', 'Agent is NOT running.');
      log(termDiv, 'cmd', 'To restart: Deploy tab > enter same salt > Deploy again.');
      log(termDiv, 'info', 'This re-calls configureFundAndStart() to re-arm the scheduler.');
      btn.innerHTML = 'Check & Restart';
      return;
    }

    // Agent IS running — confirm stop + restart
    if (!confirm(`Agent is running (${wakeCount} wakes). Stop and restart?\n\nThis sends 2 transactions:\n1. stop() — cancel scheduler\n2. Reconfigure via Deploy tab`)) {
      btn.innerHTML = 'Check & Restart';
      return;
    }

    // Step 1: Stop
    log(termDiv, 'cmd', 'Step 1: Sending stop()...');
    btn.innerHTML = 'Stopping...';
    const harness = new ethers.Contract(agent, ['function stop() external', 'function isRunning() view returns (bool)'], signer);
    try {
      const tx = await harness.stop();
      log(termDiv, 'info', `TX: <a href='https://explorer.ritualfoundation.org/tx/${tx.hash}' target='_blank' class='tx-hash'>${tx.hash.slice(0,18)}...</a>`);
      const receipt = await tx.wait();
      log(termDiv, 'success', `Stopped! Gas: ${receipt.gasUsed.toString()}`);
    } catch (stopErr) {
      if (stopErr.message?.includes('NotRunning')) {
        log(termDiv, 'warn', 'Agent was already stopped.');
      } else {
        throw stopErr;
      }
    }

    // Step 2: Guide to reconfigure
    log(termDiv, 'info', '');
    log(termDiv, 'cmd', 'Step 2: Go to Deploy tab > enter same salt > Deploy');
    log(termDiv, 'info', 'This re-calls configureFundAndStart() with fresh params.');
    log(termDiv, 'info', 'The CREATE2 deterministic address stays the same.');

  } catch (err) {
    log(termDiv, 'error', `Error: ${err.message}`);
  } finally {
    btn.disabled = false;
    btn.innerHTML = 'Check & Restart';
  }
}

async function stopAgent() {
  if (!signer || !userAddress) { alert('Connect wallet first'); return; }
  const agent = document.getElementById('m-stop-agent').value.trim();
  if (!agent) { alert('Enter an agent address'); return; }

  const btn = document.getElementById('stop-btn');
  const termDiv = document.getElementById('stop-terminal');
  termDiv.classList.remove('hidden');
  termDiv.innerHTML = '';
  btn.disabled = true;
  btn.innerHTML = 'Checking...';

  try {
    log(termDiv, 'comment', `Stop agent ${agent}`);

    const rpcProvider = new ethers.JsonRpcProvider(RITUAL_RPC);
    const wallet = new ethers.Contract(RITUAL_WALLET, WALLET_ABI, rpcProvider);

    // Check current state
    let isRunning = false;
    try {
      const r = await rpcProvider.call({ to: agent, data: '0x2014e5d1' }); // isRunning()
      isRunning = r.length >= 32 ? r[31] === 1 : false;
    } catch(e) {}

    let wakeCount = 0n;
    try {
      const r = await rpcProvider.call({ to: agent, data: '0x46cebb38' }); // wakeCount()
      wakeCount = BigInt(r);
    } catch(e) {}

    const balance = await wallet.balanceOf(agent);
    const lockUntil = await wallet.lockUntil(agent);
    const currentBlock = await rpcProvider.getBlockNumber();
    const balFmt = parseFloat(ethers.formatEther(balance)).toFixed(4);
    const blocksLeft = Number(lockUntil) - currentBlock;
    const hoursLeft = Math.max(0, Math.round(blocksLeft * 3.5 / 3600));

    log(termDiv, 'info', `Balance: ${balFmt} RITUAL | Lock: ${hoursLeft > 0 ? hoursLeft + 'h left' : 'expired'}`);
    log(termDiv, 'info', `Running: ${isRunning} | Wakes: ${wakeCount}`);

    if (!isRunning) {
      log(termDiv, 'warn', 'Agent is already stopped.');
      if (blocksLeft <= 0 && balance > 0n) {
        log(termDiv, 'success', 'Lock expired. Funds can be withdrawn from RitualWallet.');
      } else if (balance > 0n) {
        log(termDiv, 'info', `Funds locked for ${hoursLeft}h more.`);
      }
      btn.innerHTML = 'Check Status';
      return;
    }

    // Agent is running — confirm stop
    if (!confirm(`Agent is running (${wakeCount} wakes, ${balFmt} RITUAL).\n\nSend stop() to cancel scheduler?\n\nNote: Funds remain locked until lock expires.`)) {
      btn.innerHTML = 'Check Status';
      return;
    }

    // Send stop() transaction
    log(termDiv, 'cmd', 'Sending stop()...');
    btn.innerHTML = 'Stopping...';
    const harness = new ethers.Contract(agent, [
      'function stop() external',
      'function owner() view returns (address)'
    ], signer);

    // Verify ownership
    const owner = await rpcProvider.call({ to: agent, data: '0x8da5cb5b' }); // owner()
    const ownerAddr = '0x' + owner.slice(-40);
    if (ownerAddr.toLowerCase() !== userAddress.toLowerCase()) {
      throw new Error(`Not owner. Owner: ${ownerAddr.slice(0,10)}... You: ${userAddress.slice(0,10)}...`);
    }

    const tx = await harness.stop();
    log(termDiv, 'info', `TX: <a href='https://explorer.ritualfoundation.org/tx/${tx.hash}' target='_blank' class='tx-hash'>${tx.hash.slice(0,18)}...</a>`);
    const receipt = await tx.wait();
    log(termDiv, 'success', `Agent stopped! Gas: ${receipt.gasUsed.toString()}`);
    log(termDiv, 'info', '');
    log(termDiv, 'info', 'Funds remain locked in RitualWallet until lock expires.');
    log(termDiv, 'info', 'To restart: Deploy tab > enter same salt > Deploy');

  } catch (err) {
    log(termDiv, 'error', `Error: ${err.message}`);
  } finally {
    btn.disabled = false;
    btn.innerHTML = 'Stop Agent';
  }
}

// ═══════════════════════════════════════════════════════════
//  MY AGENTS — Explorer primary + on-chain verification + cache
// ═══════════════════════════════════════════════════════════
let allAgentsData = [];
let selectedAgents = new Set();
let currentDetailAddr = null;

// ── Network Detection ──
async function checkRitualNetwork() {
  try {
    const chainId = await window.ethereum.request({ method: 'eth_chainId' });
    const id = parseInt(chainId, 16);
    const warn = document.getElementById('network-warning');
    if (id !== RITUAL_CHAIN_ID) {
      warn.classList.remove('hidden');
      return false;
    }
    warn.classList.add('hidden');
    return true;
  } catch(e) { return true; }
}

async function switchToRitual() {
  try {
    await window.ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: '0x' + RITUAL_CHAIN_ID.toString(16) }]
    });
    document.getElementById('network-warning').classList.add('hidden');
  } catch(e) {
    alert('Switch to Ritual Chain (ID: ' + RITUAL_CHAIN_ID + ') in your wallet');
  }
}

// ── Health Score ──
function getHealthScore(agent) {
  const bal = agent.balance || 0n;
  const lock = agent.lockUntil || 0n;
  const running = agent.isRunning;
  const wakes = agent.wakeCount || 0;
  const currentBlock = agent.currentBlock || 0;
  const blocksLeft = Number(lock) - currentBlock;

  if (bal === 0n && !running) return { label: 'Stopped', color: '#6b7280', icon: '⚪' };
  if (!running && wakes === 0) return { label: 'Idle', color: '#f97316', icon: '🟠' };
  if (bal === 0n) return { label: 'Critical', color: '#ef4444', icon: '🔴' };
  if (blocksLeft < 172800) return { label: 'Warning', color: '#eab308', icon: '🟡' };
  if (running && bal > 0n && blocksLeft > 0) return { label: 'Healthy', color: '#22c55e', icon: '🟢' };
  if (running) return { label: 'Active', color: '#22c55e', icon: '🟢' };
  return { label: 'Unknown', color: '#8b5cf6', icon: '⚪' };
}

// ── Cost Estimate ──
function getCostEstimate(agent) {
  const bal = agent.balance || 0n;
  const balFloat = parseFloat(ethers.formatEther(bal));
  const wakes = agent.wakeCount || 0;
  const avgCostPerWake = wakes > 0 ? balFloat / (wakes + balFloat / 0.003) : 0.003;
  const estimatedDaily = avgCostPerWake * (86400 / (2000 * 0.35));
  const daysLeft = estimatedDaily > 0 ? balFloat / estimatedDaily : 0;
  return { deposited: balFloat + 0.02, remaining: balFloat, daily: estimatedDaily, daysLeft };
}

// ── Explorer API (Primary Source) ──
async function fetchFromExplorer() {
  const agents = new Map();
  try {
    const resp = await fetch('https://explorer.ritualfoundation.org/api/agents/cache');
    if (!resp.ok) throw new Error('Explorer API ' + resp.status);
    const cache = await resp.json();
    const allAgents = [...(cache.sovereign || []), ...(cache.persistent || [])];
    for (const agent of allAgents) {
      if (agent.info?.owner?.toLowerCase() === userAddress.toLowerCase()) {
        const addr = agent.address.toLowerCase();
        agents.set(addr, {
          address: agent.address,
          source: 'explorer',
          agentType: agent.info?.type || 'sovereign',
          agentState: agent.info?.state,
          isAlive: agent.info?.isAlive,
          lastBlock: agent.lastActivityBlock || agent.info?.lastHeartbeatBlock,
          timestamp: 0
        });
      }
    }
  } catch(e) { console.warn('Explorer API failed:', e.message); }
  return agents;
}

// ── Factory Events (Supplementary) ──
async function fetchFromFactoryEvents() {
  const agents = new Map();
  try {
    const rpcProvider = new ethers.JsonRpcProvider(RITUAL_RPC);
    const currentBlock = await rpcProvider.getBlockNumber();
    const factory = new ethers.Contract(SOVEREIGN_FACTORY, FACTORY_ABI, rpcProvider);
    const fromBlock = Math.max(0, currentBlock - 7_776_000);
    const filter = factory.filters.DeployHarness(userAddress);
    const events = await factory.queryFilter(filter, fromBlock, currentBlock);
    for (const ev of events) {
      const addr = ev.args.harness.toLowerCase();
      if (!agents.has(addr)) {
        agents.set(addr, {
          address: ev.args.harness,
          source: 'factory',
          salt: ev.args.salt ? ethers.hexlify(ev.args.salt) : null,
          timestamp: ev.blockNumber * 350
        });
      }
    }
  } catch(e) { console.warn('Factory events failed:', e.message); }
  return agents;
}

// ── localStorage Cache ──
function fetchFromCache() {
  const agents = new Map();
  const saved = JSON.parse(localStorage.getItem('sr_agents') || '[]');
  for (const a of saved) {
    agents.set(a.address.toLowerCase(), { ...a, source: 'cache' });
  }
  return agents;
}

function saveToCache(agents) {
  const arr = Array.from(agents.values()).map(a => ({
    address: a.address,
    salt: a.salt || null,
    label: a.label || null,
    timestamp: a.timestamp || 0,
    addedManually: a.addedManually || false
  }));
  localStorage.setItem('sr_agents', JSON.stringify(arr));
}

// ── On-chain Verification ──
async function verifyOnChain(addr, rpcProvider) {
  const result = { address: addr, hasCode: false };
  try {
    const code = await rpcProvider.getCode(addr);
    result.hasCode = code && code !== '0x' && code !== '0x0';
    if (!result.hasCode) return result;

    // Owner
    try {
      const r = await rpcProvider.call({ to: addr, data: '0x8da5cb5b' });
      result.owner = '0x' + r.slice(26);
      result.isOwnerMatch = result.owner.toLowerCase() === userAddress.toLowerCase();
    } catch(e) {}

    // isRunning
    try {
      const r = await rpcProvider.call({ to: addr, data: '0x2014e5d1' });
      result.isRunning = r.length >= 32 && r[31] === 1;
    } catch(e) {}

    // wakeCount
    try {
      const r = await rpcProvider.call({ to: addr, data: '0x46cebb38' });
      result.wakeCount = Number(BigInt(r));
    } catch(e) {}

    // Balance + Lock
    const wallet = new ethers.Contract(RITUAL_WALLET, WALLET_ABI, rpcProvider);
    result.balance = await wallet.balanceOf(addr);
    result.lockUntil = await wallet.lockUntil(addr);
    result.currentBlock = await rpcProvider.getBlockNumber();
  } catch(e) {}
  return result;
}

// ── Main Load ──
async function loadMyAgents() {
  if (!signer || !userAddress) { alert('Connect wallet first'); return; }
  await checkRitualNetwork();

  const listDiv = document.getElementById('agents-list');
  listDiv.innerHTML = '<div class="glass rounded-xl p-4 text-center"><p class="text-slate-500 text-xs">Scanning on-chain...</p></div>';

  const agents = new Map();
  const rpcProvider = new ethers.JsonRpcProvider(RITUAL_RPC);

  // Layer 1: Cache (instant display)
  const cached = fetchFromCache();
  for (const [k, v] of cached) agents.set(k, v);

  // Layer 2: Explorer API (primary)
  const explorer = await fetchFromExplorer();
  for (const [k, v] of explorer) {
    if (!agents.has(k)) agents.set(k, v);
    else Object.assign(agents.get(k), v, { source: 'explorer+cache' });
  }

  // Layer 3: Factory events
  const factory = await fetchFromFactoryEvents();
  for (const [k, v] of factory) {
    if (!agents.has(k)) agents.set(k, v);
    else if (!agents.get(k).salt && v.salt) agents.get(k).salt = v.salt;
  }

  // Step 2: Enrich each agent with on-chain data
  allAgentsData = [];
  for (const [addr, agent] of agents) {
    const enriched = await verifyOnChain(addr, rpcProvider);
    Object.assign(agent, enriched);
    agent.label = agent.label || agent.salt || ('Agent @ ' + addr.slice(0, 8) + '...');
    allAgentsData.push(agent);
  }

  // Save to cache
  saveToCache(agents);

  // Update timestamp
  document.getElementById('agents-updated').textContent = 'Updated just now';
  document.getElementById('agents-count').textContent = `(${allAgentsData.length})`;

  // Render
  renderAgentCards();
}

function refreshAgents() { loadMyAgents(); }

// ── Render Cards ──
function renderAgentCards() {
  const listDiv = document.getElementById('agents-list');
  if (allAgentsData.length === 0) {
    listDiv.innerHTML = '<div class="glass rounded-xl p-4 text-center"><p class="text-slate-500 text-xs">No agents found. Deploy one or add by address above.</p></div>';
    return;
  }

  // Show batch bar if > 1 agent
  document.getElementById('batch-bar').classList.toggle('hidden', allAgentsData.length <= 1);

  listDiv.innerHTML = allAgentsData.map((agent, i) => {
    const health = getHealthScore(agent);
    const bal = agent.balance > 0n ? parseFloat(ethers.formatEther(agent.balance)).toFixed(4) : '0';
    const blocksLeft = agent.lockUntil ? Number(agent.lockUntil) - (agent.currentBlock || 0) : 0;
    const hoursLeft = Math.max(0, Math.round(blocksLeft * 0.35 / 3600));
    const isOwner = agent.isOwnerMatch !== false;
    const addr = agent.address;
    const selected = selectedAgents.has(addr.toLowerCase());

    return `
    <div class="glass rounded-xl p-2 md:p-3 cursor-pointer transition-all hover:border-purple-500/30" style="border:1px solid ${selected ? 'rgba(180,158,255,0.5)' : 'transparent'}" onclick="showAgentDetail('${addr}')">
      <div class="flex items-center justify-between mb-1">
        <div class="flex items-center gap-2">
          ${allAgentsData.length > 1 ? `<input type="checkbox" ${selected ? 'checked' : ''} onclick="event.stopPropagation(); toggleAgentSelect('${addr}')" class="accent-purple-500" />` : ''}
          <span class="w-2 h-2 rounded-full" style="background:${health.color}"></span>
          <span class="text-xs font-semibold text-slate-200">${agent.label}</span>
        </div>
        <span class="text-xs font-semibold px-2 py-0.5 rounded-full" style="background:${health.color}20;color:${health.color}">${health.icon} ${health.label}</span>
      </div>
      ${!isOwner ? '<div class="text-xs text-red-400 mb-1">⚠️ Owner mismatch</div>' : ''}
      <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs mt-1">
        <span class="text-slate-500">Address <span class="mono text-slate-300">${addr.slice(0,8)}...${addr.slice(-6)}</span></span>
        <span class="text-slate-500">Balance <span class="text-slate-300">${bal} RITUAL</span></span>
        <span class="text-slate-500">Wakes <span class="text-slate-300">${agent.wakeCount || 0}</span></span>
        ${hoursLeft > 0 ? `<span class="text-slate-500">Lock <span class="text-slate-300">${hoursLeft}h left</span></span>` : ''}
        <span class="text-slate-600">${agent.source || 'unknown'}</span>
      </div>
    </div>`;
  }).join('');
}

// ── Agent Detail View ──
function showAgentDetail(addr) {
  const agent = allAgentsData.find(a => a.address.toLowerCase() === addr.toLowerCase());
  if (!agent) return;
  currentDetailAddr = addr;

  document.getElementById('agents-list').classList.add('hidden');
  document.getElementById('batch-bar').classList.add('hidden');
  const detail = document.getElementById('agent-detail');
  detail.classList.remove('hidden');

  const health = getHealthScore(agent);
  const cost = getCostEstimate(agent);
  const bal = agent.balance > 0n ? parseFloat(ethers.formatEther(agent.balance)).toFixed(6) : '0';
  const blocksLeft = agent.lockUntil ? Number(agent.lockUntil) - (agent.currentBlock || 0) : 0;
  const hoursLeft = Math.max(0, Math.round(blocksLeft * 0.35 / 3600));
  const daysLeft = (hoursLeft / 24).toFixed(1);

  document.getElementById('detail-health').textContent = health.icon + ' ' + health.label;
  document.getElementById('detail-health').style.background = health.color + '20';
  document.getElementById('detail-health').style.color = health.color;
  document.getElementById('detail-explorer-link').href = 'https://explorer.ritualfoundation.org/address/' + addr;

  document.getElementById('detail-content').innerHTML = `
    <div class="space-y-2 text-xs">
      <div class="flex justify-between"><span class="text-slate-500">Address</span><span class="mono text-slate-300">${addr}</span></div>
      <div class="flex justify-between"><span class="text-slate-500">Owner</span><span class="mono text-slate-300">${agent.owner || 'N/A'}${agent.isOwnerMatch ? ' ✓' : ''}</span></div>
      <div class="flex justify-between"><span class="text-slate-500">Balance</span><span class="text-slate-300">${bal} RITUAL</span></div>
      <div class="flex justify-between"><span class="text-slate-500">Locked</span><span class="text-slate-300">${hoursLeft > 0 ? daysLeft + ' days (' + hoursLeft + 'h)' : 'Expired'}</span></div>
      <div class="flex justify-between"><span class="text-slate-500">Running</span><span class="text-slate-300">${agent.isRunning ? '✓ Yes' : '✗ No'}</span></div>
      <div class="flex justify-between"><span class="text-slate-500">Wakes</span><span class="text-slate-300">${agent.wakeCount || 0}</span></div>
      <div class="flex justify-between"><span class="text-slate-500">Source</span><span class="text-slate-300">${agent.source || 'unknown'}</span></div>
      ${agent.salt ? `<div class="flex justify-between"><span class="text-slate-500">Salt</span><span class="mono text-slate-300">${agent.salt}</span></div>` : ''}
      <hr style="border-color:rgba(255,255,255,0.05)">
      <div class="flex justify-between"><span class="text-slate-500">Est. Daily Cost</span><span class="text-slate-300">${cost.daily.toFixed(4)} RITUAL</span></div>
      <div class="flex justify-between"><span class="text-slate-500">Est. Days Left</span><span class="text-slate-300">${cost.daysLeft.toFixed(1)} days</span></div>
    </div>`;
}

function closeAgentDetail() {
  document.getElementById('agent-detail').classList.add('hidden');
  document.getElementById('agents-list').classList.remove('hidden');
  document.getElementById('batch-bar').classList.toggle('hidden', allAgentsData.length <= 1);
  currentDetailAddr = null;
}

async function detailAction(action) {
  if (!currentDetailAddr) return;
  if (action === 'stop') {
    document.getElementById('m-stop-agent').value = currentDetailAddr;
    switchTab('manage');
    setTimeout(() => stopAgent(), 100);
  } else if (action === 'deposit') {
    document.getElementById('m-deposit-agent').value = currentDetailAddr;
    switchTab('manage');
  }
}

// ── Add Manual Agent ──
async function addManualAgent() {
  if (!signer || !userAddress) { alert('Connect wallet first'); return; }
  const input = document.getElementById('m-add-agent');
  const addr = input.value.trim();
  if (!addr || !addr.startsWith('0x') || addr.length !== 42) { alert('Enter a valid address'); return; }

  const resultDiv = document.getElementById('add-agent-result');
  resultDiv.classList.remove('hidden');
  resultDiv.innerHTML = '<span class="text-slate-400">Verifying...</span>';
  resultDiv.style.background = 'rgba(180,158,255,0.08)';
  resultDiv.style.border = '1px solid rgba(180,158,255,0.2)';

  const rpcProvider = new ethers.JsonRpcProvider(RITUAL_RPC);
  const verified = await verifyOnChain(addr, rpcProvider);

  if (!verified.hasCode) {
    resultDiv.innerHTML = '<span class="text-red-400">✗ No contract at this address</span>';
    resultDiv.style.background = 'rgba(239,68,68,0.08)';
    return;
  }
  if (!verified.isOwnerMatch) {
    resultDiv.innerHTML = `<span class="text-red-400">✗ Owner mismatch. Owner: ${verified.owner?.slice(0,10)}...</span>`;
    resultDiv.style.background = 'rgba(239,68,68,0.08)';
    return;
  }

  // Add to data
  verified.label = 'Agent @ ' + addr.slice(0, 8) + '...';
  verified.source = 'manual';
  verified.addedManually = true;
  allAgentsData.push(verified);

  // Save to cache
  const agents = new Map();
  for (const a of allAgentsData) agents.set(a.address.toLowerCase(), a);
  saveToCache(agents);

  resultDiv.innerHTML = `<span style="color:#22c55e">✓ Added! Balance: ${verified.balance > 0n ? parseFloat(ethers.formatEther(verified.balance)).toFixed(4) : '0'} RITUAL | Running: ${verified.isRunning ? 'Yes' : 'No'}</span>`;
  resultDiv.style.background = 'rgba(34,197,94,0.08)';
  input.value = '';

  renderAgentCards();
  document.getElementById('agents-count').textContent = `(${allAgentsData.length})`;
}

// ── Batch Selection ──
function toggleAgentSelect(addr) {
  const key = addr.toLowerCase();
  if (selectedAgents.has(key)) selectedAgents.delete(key);
  else selectedAgents.add(key);
  document.getElementById('selected-count').textContent = selectedAgents.size;
  renderAgentCards();
}

function toggleSelectAll() {
  const checked = document.getElementById('select-all-agents').checked;
  if (checked) allAgentsData.forEach(a => selectedAgents.add(a.address.toLowerCase()));
  else selectedAgents.clear();
  document.getElementById('selected-count').textContent = selectedAgents.size;
  renderAgentCards();
}

async function batchStop() {
  if (selectedAgents.size === 0) return;
  if (!confirm(`Stop ${selectedAgents.size} agent(s)?`)) return;
  switchTab('manage');
  for (const addr of selectedAgents) {
    document.getElementById('m-stop-agent').value = addr;
    await stopAgent();
  }
}

async function batchDeposit() {
  if (selectedAgents.size === 0) return;
  const amount = prompt('Deposit amount (RITUAL) per agent:', '0.1');
  if (!amount) return;
  switchTab('manage');
  for (const addr of selectedAgents) {
    document.getElementById('m-deposit-agent').value = addr;
    document.getElementById('m-deposit-amount').value = amount;
    await depositToWallet();
  }
}

// ── Wallet Change Listener ──
if (typeof window !== 'undefined' && window.ethereum) {
  window.ethereum.on('accountsChanged', () => {
    if (document.getElementById('panel-agents') && !document.getElementById('panel-agents').classList.contains('hidden')) {
      loadMyAgents();
    }
  });
  window.ethereum.on('chainChanged', () => {
    checkRitualNetwork();
    if (document.getElementById('panel-agents') && !document.getElementById('panel-agents').classList.contains('hidden')) {
      loadMyAgents();
    }
  });
}
function copyEnv() {
  const text = document.getElementById('env-output').textContent;
  navigator.clipboard.writeText(text);
  const btn = document.getElementById('env-copy-btn');
  btn.textContent = 'Copied!';
  setTimeout(() => { btn.textContent = 'Copy'; }, 2000);
}

// ═══════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════
function log(container, cls, text) {
  if (typeof container === 'string') container = document.getElementById(container);
  if (!container) return;
  const line = document.createElement('div');
  line.className = `line ${cls}`;
  line.innerHTML = text;
  container.appendChild(line);
  container.scrollTop = container.scrollHeight;
}

function updateProgress(percent, label) {
  document.getElementById('progress-fill').style.width = percent + '%';
  document.getElementById('deploy-step-label').textContent = label;
}

// ═══════════════════════════════════════════════════════════
//  INIT
// ═══════════════════════════════════════════════════════════
updateModelOptions();
document.getElementById('d-fund').addEventListener('input', updateEstimate);
document.getElementById('d-lockduration').addEventListener('change', updateEstimate);
updateEstimate();
validateSchedule();
autoReconnect();

// ═══════════════════════════════════════════════════════════
//  SHADCN CUSTOM SELECT (rs-select)
// ═══════════════════════════════════════════════════════════
function initCustomSelects() {
  document.querySelectorAll('.rs-select').forEach(wrap => {
    const sel = wrap.querySelector('select');
    if (!sel) return;
    const trigger = wrap.querySelector('.rs-select-trigger');
    const valEl = wrap.querySelector('.rs-select-value');

    // Build dropdown content
    const content = document.createElement('div');
    content.className = 'rs-select-content';
    wrap.appendChild(content);
    const checkSvg = '<svg class="check" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>';

    function buildItems() {
      content.innerHTML = '';
      Array.from(sel.options).forEach((opt, i) => {
        if (opt.disabled && !opt.value) return; // skip placeholder
        const item = document.createElement('div');
        item.className = 'rs-select-item';
        item.setAttribute('data-value', opt.value);
        item.setAttribute('data-index', i);
        if (opt.value === sel.value) item.classList.add('selected');
        item.innerHTML = `<span>${opt.text}</span>${checkSvg}`;
        item.addEventListener('click', () => {
          sel.value = opt.value;
          valEl.textContent = opt.text;
          valEl.classList.remove('placeholder');
          content.querySelectorAll('.rs-select-item').forEach(it => it.classList.remove('selected'));
          item.classList.add('selected');
          closeDropdown();
          // Fire change event
          sel.dispatchEvent(new Event('change', { bubbles: true }));
        });
        content.appendChild(item);
      });
    }

    function openDropdown() {
      buildItems();
      // Set current
      valEl.textContent = sel.options[sel.selectedIndex]?.text || '';
      if (!sel.value) valEl.classList.add('placeholder');
      content.classList.add('open');
      trigger.classList.add('open');
      // Prevent clipping from overflow-y:auto on panel-deploy
      const panel = document.getElementById('panel-deploy');
      if (panel) panel.style.overflow = 'visible';
      // Position above if near bottom
      requestAnimationFrame(() => {
        const rect = content.getBoundingClientRect();
        if (rect.bottom > window.innerHeight - 20) {
          content.style.bottom = '100%';
          content.style.top = 'auto';
          content.style.marginTop = '0';
          content.style.marginBottom = '4px';
        } else {
          content.style.bottom = 'auto';
          content.style.top = '100%';
          content.style.marginTop = '4px';
          content.style.marginBottom = '0';
        }
      });
    }

    function closeDropdown() {
      content.classList.remove('open');
      trigger.classList.remove('open');
      // Restore scroll after dropdown closes
      const panel = document.getElementById('panel-deploy');
      if (panel) { panel.style.overflow = ''; panel.classList.add('overflow-y-auto'); }
    }

    trigger.addEventListener('click', (e) => {
      e.stopPropagation();
      const isOpen = content.classList.contains('open');
      // Close all others first
      document.querySelectorAll('.rs-select-content.open').forEach(c => c.classList.remove('open'));
      document.querySelectorAll('.rs-select-trigger.open').forEach(t => t.classList.remove('open'));
      if (!isOpen) openDropdown();
    });

    document.addEventListener('click', (e) => {
      if (!wrap.contains(e.target)) closeDropdown();
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') closeDropdown();
    });

    // Set initial display
    if (sel.value) {
      valEl.textContent = sel.options[sel.selectedIndex]?.text || '';
      valEl.classList.remove('placeholder');
    } else if (sel.options[0]) {
      valEl.textContent = sel.options[0].text;
      valEl.classList.add('placeholder');
    }

    // Expose refresh method for dynamic selects (like d-executor, d-model)
    wrap._refreshSelect = function() {
      buildItems();
      if (sel.value) {
        valEl.textContent = sel.options[sel.selectedIndex]?.text || '';
        valEl.classList.remove('placeholder');
      }
    };
  });
}
</script>

</body>
// ═══════════════════════════════════════════════════════════
//  IMPROVEMENTS v2 — Error Boundary + Health Polling + PWA
// ═══════════════════════════════════════════════════════════

// ─── PWA Registration ───
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  });
}

// ─── Error Boundary ───
function safeAsync(fn) {
  return async (...args) => {
    try {
      return await fn(...args);
    } catch (err) {
      const msg = err?.reason?.message || err?.message || String(err);
      // Friendly error mapping
      const friendly = {
        'user rejected action': 'Signature rejected by user.',
        'insufficient funds': 'Not enough RITUAL balance.',
        'nonce too low': 'Transaction nonce conflict. Try again.',
        'replacement underpriced': 'Gas too low for replacement TX.',
        'CALL_EXCEPTION': 'Contract call failed — check parameters.',
        'NETWORK_ERROR': 'Network error — check RPC connection.',
        'TIMEOUT': 'Request timed out — try again.',
        'missing revert data': 'Transaction reverted — check contract state.',
      };
      let display = msg;
      for (const [key, val] of Object.entries(friendly)) {
        if (msg.toLowerCase().includes(key.toLowerCase())) { display = val; break; }
      }
      console.error('[Sovereign]', err);
      showToast(display, 'error');
      throw err;
    }
  };
}

// Toast notification system
function showToast(message, type = 'info') {
  const existing = document.getElementById('sovereign-toast');
  if (existing) existing.remove();
  
  const toast = document.createElement('div');
  toast.id = 'sovereign-toast';
  const colors = {
    error: { bg: 'rgba(239,68,68,0.15)', border: 'rgba(239,68,68,0.3)', text: '#fca5a5' },
    success: { bg: 'rgba(34,197,94,0.15)', border: 'rgba(34,197,94,0.3)', text: '#86efac' },
    info: { bg: 'rgba(180,158,255,0.15)', border: 'rgba(180,158,255,0.3)', text: '#b49eff' },
    warning: { bg: 'rgba(234,179,8,0.15)', border: 'rgba(234,179,8,0.3)', text: '#fde047' }
  };
  const c = colors[type] || colors.info;
  Object.assign(toast.style, {
    position: 'fixed', top: '20px', right: '20px', zIndex: '9999',
    background: c.bg, border: `1px solid ${c.border}`, color: c.text,
    padding: '12px 20px', borderRadius: '10px', fontSize: '13px',
    fontFamily: "'Instrument Sans', sans-serif", maxWidth: '400px',
    backdropFilter: 'blur(16px)', boxShadow: '0 8px 32px rgba(0,0,0,0.4)',
    animation: 'toastIn 0.3s ease', cursor: 'pointer'
  });
  toast.textContent = message;
  toast.onclick = () => toast.remove();
  document.body.appendChild(toast);
  setTimeout(() => { toast.style.opacity = '0'; setTimeout(() => toast.remove(), 300); }, 5000);
}

// Add toast animation
if (!document.getElementById('toast-style')) {
  const s = document.createElement('style');
  s.id = 'toast-style';
  s.textContent = '@keyframes toastIn{from{opacity:0;transform:translateY(-10px)}to{opacity:1;transform:translateY(0)}}';
  document.head.appendChild(s);
}

// ─── Health Check Polling (My Agents) ───
let healthPollInterval = null;

function startHealthPolling() {
  if (healthPollInterval) return;
  healthPollInterval = setInterval(async () => {
    const agentsList = document.getElementById('agents-list');
    if (!agentsList || agentsList.classList.contains('hidden')) {
      stopHealthPolling();
      return;
    }
    // Refresh agents data
    try { await refreshMyAgents(); } catch(e) {}
  }, 30000); // Every 30 seconds
}

function stopHealthPolling() {
  if (healthPollInterval) { clearInterval(healthPollInterval); healthPollInterval = null; }
}

// Auto-start when My Agents tab is shown
const origShowTab = window.showTab;
if (typeof origShowTab === 'function') {
  window.showTab = function(...args) {
    origShowTab.apply(this, args);
    const tab = args[0];
    if (tab === 'agents') startHealthPolling();
    else stopHealthPolling();
  };
}

// ─── Explorer Verification Link ───
function getExplorerUrl(address) {
  return `https://explorer.ritualfoundation.org/address/${address}`;
}

function getVerifyUrl(address) {
  return `https://sourcify.dev/#/verify/${address}?chainIds=1979`;
}

function appendVerificationUI(container, contractAddr) {
  if (!container || !contractAddr) return;
  const div = document.createElement('div');
  div.className = 'mt-3 rounded-lg px-3 py-2 border';
  div.style.cssText = 'background:rgba(34,197,94,0.08);border-color:rgba(34,197,94,0.2)';
  div.innerHTML = `
    <div class="flex flex-wrap items-center gap-2 text-xs">
      <span style="color:#86efac;font-weight:600">✓ Deployed</span>
      <span class="text-slate-500">·</span>
      <a href="${getExplorerUrl(contractAddr)}" target="_blank" rel="noopener" 
         class="underline hover:no-underline" style="color:#b49eff">
        View on Explorer ↗
      </a>
      <span class="text-slate-500">·</span>
      <a href="${getVerifyUrl(contractAddr)}" target="_blank" rel="noopener"
         class="underline hover:no-underline" style="color:#b49eff">
        Verify Source ↗
      </a>
    </div>
    <div class="text-[10px] mt-1 text-slate-500 mono">${contractAddr}</div>
  `;
  container.appendChild(div);
}

// ─── Mobile Layout Fix ───
function applyMobileLayout() {
  const isMobile = window.innerWidth < 768;
  const grid = document.querySelector('#panel-deploy .grid');
  if (!grid) return;
  
  if (isMobile) {
    // Mobile: single column, deploy button full width
    grid.style.gridTemplateColumns = '1fr';
    const deployBtnWrap = document.getElementById('deploy-btn')?.parentElement;
    if (deployBtnWrap) deployBtnWrap.style.gridColumn = '1';
  } else {
    grid.style.gridTemplateColumns = '';
    const deployBtnWrap = document.getElementById('deploy-btn')?.parentElement;
    if (deployBtnWrap) deployBtnWrap.style.gridColumn = '';
  }
}

window.addEventListener('resize', applyMobileLayout);
window.addEventListener('DOMContentLoaded', applyMobileLayout);
