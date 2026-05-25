const $ = (id) => document.getElementById(id);

function toast(msg, ok = true) {
  const el = $('toast');
  el.textContent = msg;
  el.className = `toast ${ok ? 'ok' : 'err'}`;
  setTimeout(() => el.classList.add('hidden'), 4000);
}

function apiUrl() {
  return $('apiUrl').value.replace(/\/$/, '');
}

function outputPath() {
  return $('output').value.trim() || 'data/transactions.json';
}

async function jsonFetch(url, options = {}) {
  const r = await fetch(url, options);
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(data.error || data.message || r.statusText);
  return data;
}

function renderStats(stats) {
  if (!stats) {
    $('fileStats').textContent = 'Arquivo não encontrado ou inválido.';
    return;
  }
  $('fileStats').innerHTML = `
    <dl>
      <dt>Arquivo</dt><dd>${stats.path}</dd>
      <dt>Total</dt><dd>${stats.total}</dd>
      <dt>Fraudes (rótulo)</dt><dd>${stats.frauds} (${(stats.fraudRate * 100).toFixed(1)}%)</dd>
      <dt>Valor médio</dt><dd>R$ ${stats.amountMean.toLocaleString('pt-BR')}</dd>
    </dl>
  `;
}

async function checkApiHealth() {
  const pill = $('apiStatus');
  try {
    const q = new URLSearchParams({ apiUrl: apiUrl() });
    const data = await jsonFetch(`/api/health?${q}`);
    pill.textContent = data.ok
      ? `API: ${data.body?.status || 'ok'}`
      : 'API: erro';
    pill.className = `api-pill ${data.ok ? 'ok' : 'err'}`;
  } catch {
    pill.textContent = 'API: offline';
    pill.className = 'api-pill err';
  }
}

async function refreshStats() {
  try {
    const q = new URLSearchParams({ path: outputPath() });
    const data = await jsonFetch(`/api/file/stats?${q}`);
    renderStats(data.stats);
  } catch (e) {
    renderStats(null);
    toast(e.message, false);
  }
}

$('formGenerate').addEventListener('submit', async (e) => {
  e.preventDefault();
  try {
    const data = await jsonFetch('/api/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        num: Number($('num').value),
        fraudRate: Number($('fraudRate').value),
        output: outputPath(),
      }),
    });
    renderStats(data.stats);
    toast(data.message || 'Arquivo gerado');
  } catch (err) {
    toast(err.message, false);
  }
});

$('btnRefreshStats').addEventListener('click', refreshStats);

$('formBatch').addEventListener('submit', async (e) => {
  e.preventDefault();
  try {
    const data = await jsonFetch('/api/send-batch', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        apiUrl: apiUrl(),
        slice: Number($('batchSlice').value),
        path: outputPath(),
      }),
    });
    toast(
      `Lote enviado: ${data.sent} tx — fraudes detectadas: ${data.result.total_frauds_detected}`
    );
    await checkApiHealth();
  } catch (err) {
    toast(err.message, false);
  }
});

async function pollLoop() {
  try {
    const data = await jsonFetch('/api/loop/status');
    const lines = data.logs.map((l) => `[${l.at.slice(11, 19)}] ${l.line}`).join('\n');
    $('loopLogs').textContent = lines || (data.running ? 'Aguardando logs…' : 'Loop parado.');
    $('btnLoopStart').disabled = data.running;
    $('btnLoopStop').disabled = !data.running;
  } catch {
    /* ignore */
  }
}

$('btnLoopStart').addEventListener('click', async () => {
  try {
    await jsonFetch('/api/loop/start', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        apiUrl: apiUrl(),
        intervalSec: Number($('intervalSec').value),
        maxCycles: Number($('maxCycles').value),
        generateN: Number($('generateN').value),
        batchSlice: Number($('batchSliceLoop').value),
      }),
    });
    toast('Loop iniciado');
    pollLoop();
  } catch (err) {
    toast(err.message, false);
  }
});

$('btnLoopStop').addEventListener('click', async () => {
  try {
    await jsonFetch('/api/loop/stop', { method: 'POST' });
    toast('Loop parado');
    pollLoop();
  } catch (err) {
    toast(err.message, false);
  }
});

$('apiUrl').addEventListener('change', checkApiHealth);

(async function init() {
  const cfg = await jsonFetch('/api/config');
  $('apiUrl').value = cfg.defaultApiUrl;
  await checkApiHealth();
  await refreshStats();
  setInterval(pollLoop, 2000);
  setInterval(checkApiHealth, 15000);
})();
