const express = require('express');
const path = require('path');
const fs = require('fs').promises;
const fsSync = require('fs');
const { spawn } = require('child_process');

const PORT = Number(process.env.PORT || 3333);
const PROJECT_ROOT = process.env.PROJECT_ROOT
  ? path.resolve(process.env.PROJECT_ROOT)
  : path.resolve(__dirname, '..');
const DATA_DIR = path.join(PROJECT_ROOT, 'data');
const DEFAULT_OUTPUT = 'data/transactions.json';
const DEFAULT_API_URL = process.env.API_URL || 'http://localhost:8080';
/** URL que o browser no host usa (Swagger, curl). */
const PUBLIC_API_URL = process.env.PUBLIC_API_URL || 'http://localhost:8080';

/** Dentro do Docker, localhost:8080 aponta para o próprio container — usar serviço `api`. */
function resolveApiUrl(requested) {
  const fallback = DEFAULT_API_URL.replace(/\/$/, '');
  const raw = (requested || DEFAULT_API_URL).replace(/\/$/, '');
  try {
    const host = new URL(raw).hostname;
    if (host === 'localhost' || host === '127.0.0.1') {
      return fallback;
    }
  } catch {
    return fallback;
  }
  return raw;
}

const app = express();
app.use(express.json({ limit: '2mb' }));
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});
app.use(express.static(path.join(__dirname, 'public')));

const DEFAULT_MONGO_URI =
  process.env.MONGODB_URI ||
  'mongodb://admin:admin123@mongodb:27017/fraud_detection?authSource=admin';

let batchPrepState = {
  running: false,
  startedAt: null,
  finishedAt: null,
  ok: null,
  error: null,
  logs: [],
  stats: null,
};

let loopProcess = null;
const loopLogs = [];

function pushLog(line) {
  const entry = { at: new Date().toISOString(), line };
  loopLogs.push(entry);
  if (loopLogs.length > 500) loopLogs.shift();
}

function resolveDataPath(relativePath) {
  const normalized = path.normalize(relativePath || DEFAULT_OUTPUT);
  const absolute = path.isAbsolute(normalized)
    ? normalized
    : path.join(PROJECT_ROOT, normalized);
  if (!absolute.startsWith(DATA_DIR)) {
    throw new Error('Arquivo deve ficar dentro da pasta data/');
  }
  return absolute;
}

function runCommand(cmd, args, env = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, {
      cwd: PROJECT_ROOT,
      env: { ...process.env, ...env },
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (d) => {
      stdout += d.toString();
    });
    child.stderr.on('data', (d) => {
      stderr += d.toString();
    });
    child.on('close', (code) => {
      if (code === 0) resolve({ stdout, stderr });
      else reject(new Error(stderr || stdout || `exit ${code}`));
    });
    child.on('error', reject);
  });
}

async function readFileStats(absolutePath) {
  const raw = await fs.readFile(absolutePath, 'utf8');
  const data = JSON.parse(raw);
  if (!Array.isArray(data)) throw new Error('JSON deve ser um array de transações');
  const frauds = data.filter((t) => t.is_fraud).length;
  const amounts = data.map((t) => Number(t.amount) || 0);
  const mean = amounts.length
    ? amounts.reduce((a, b) => a + b, 0) / amounts.length
    : 0;
  return {
    path: path.relative(PROJECT_ROOT, absolutePath),
    total: data.length,
    frauds,
    fraudRate: data.length ? frauds / data.length : 0,
    amountMean: Math.round(mean * 100) / 100,
    preview: data.slice(0, 5),
  };
}

function mapToAnalyzePayload(t) {
  const ts = t.timestamp || '';
  let hour = 12;
  let isWeekend = 0;
  try {
    const dt = new Date(ts);
    if (!Number.isNaN(dt.getTime())) {
      hour = dt.getHours();
      isWeekend = dt.getDay() >= 5 ? 1 : 0;
    }
  } catch {
    /* ignore */
  }
  return {
    amount: t.amount,
    merchant_category: t.merchant_category,
    payment_method: t.payment_method,
    user_country: t.user_country,
    merchant_country: t.merchant_country,
    hour,
    is_weekend: isWeekend,
    is_international:
      t.user_country !== t.merchant_country ? 1 : 0,
    transaction_id: t.transaction_id,
    user_id: t.user_id,
  };
}

app.get('/api/config', (_req, res) => {
  res.json({
    projectRoot: PROJECT_ROOT,
    defaultOutput: DEFAULT_OUTPUT,
    defaultApiUrl: PUBLIC_API_URL.replace(/\/$/, ''),
    serverApiUrl: DEFAULT_API_URL.replace(/\/$/, ''),
    python: process.env.PYTHON || 'python3',
  });
});

app.get('/api/health', async (req, res) => {
  const apiUrl = resolveApiUrl(req.query.apiUrl);
  try {
    const r = await fetch(`${apiUrl}/health`);
    const body = await r.json();
    res.json({ ok: r.ok, status: r.status, body });
  } catch (e) {
    res.status(502).json({ ok: false, error: e.message });
  }
});

app.post('/api/generate', async (req, res) => {
  try {
    const num = Math.min(100_000, Math.max(1, Number(req.body.num) || 100));
    const fraudRate = Math.min(1, Math.max(0, Number(req.body.fraudRate) ?? 0.05));
    const rel = req.body.output || DEFAULT_OUTPUT;
    const absolute = resolveDataPath(rel);
    const python = process.env.PYTHON || 'python3';
    const { stdout } = await runCommand(python, [
      'scripts/generate_data.py',
      '-n',
      String(num),
      '-o',
      rel,
      '--fraud-rate',
      String(fraudRate),
    ]);
    const stats = await readFileStats(absolute);
    res.json({ ok: true, message: stdout.trim(), stats });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
});

app.get('/api/file/stats', async (req, res) => {
  try {
    const absolute = resolveDataPath(req.query.path || DEFAULT_OUTPUT);
    const stats = await readFileStats(absolute);
    res.json({ ok: true, stats });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
});

app.post('/api/send-batch', async (req, res) => {
  try {
    const slice = Math.min(500, Math.max(1, Number(req.body.slice) || 20));
    const apiUrl = resolveApiUrl(req.body.apiUrl);
    const absolute = resolveDataPath(req.body.path || DEFAULT_OUTPUT);
    const raw = await fs.readFile(absolute, 'utf8');
    const data = JSON.parse(raw);
    const batch = data.slice(0, slice).map(mapToAnalyzePayload);
    const r = await fetch(`${apiUrl}/api/v1/transactions/batch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(batch),
    });
    const body = await r.json();
    if (!r.ok) {
      return res.status(r.status).json({ ok: false, error: body });
    }
    res.json({ ok: true, sent: batch.length, result: body });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
});

app.get('/api/loop/status', (_req, res) => {
  res.json({
    running: loopProcess !== null,
    pid: loopProcess?.pid ?? null,
    logs: loopLogs.slice(-80),
  });
});

app.post('/api/loop/start', (req, res) => {
  if (loopProcess) {
    return res.status(409).json({ ok: false, error: 'Loop já está em execução' });
  }
  const intervalSec = Math.max(5, Number(req.body.intervalSec) || 60);
  const maxCycles = Math.max(0, Number(req.body.maxCycles) || 0);
  const generateN = Math.min(10_000, Math.max(1, Number(req.body.generateN) || 80));
  const batchSlice = Math.min(500, Math.max(1, Number(req.body.batchSlice) || 20));
  const apiUrl = resolveApiUrl(req.body.apiUrl);

  loopLogs.length = 0;
  pushLog(`Iniciando demo_loop: intervalo=${intervalSec}s max=${maxCycles || '∞'}`);

  loopProcess = spawn('bash', ['scripts/demo_loop.sh', String(intervalSec), String(maxCycles)], {
    cwd: PROJECT_ROOT,
    env: {
      ...process.env,
      API_URL: apiUrl,
      GENERATE_N: String(generateN),
      BATCH_SLICE: String(batchSlice),
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  loopProcess.stdout.on('data', (d) => {
    d.toString()
      .split('\n')
      .filter(Boolean)
      .forEach((line) => pushLog(line));
  });
  loopProcess.stderr.on('data', (d) => {
    d.toString()
      .split('\n')
      .filter(Boolean)
      .forEach((line) => pushLog(`[stderr] ${line}`));
  });
  loopProcess.on('close', (code) => {
    pushLog(`Loop encerrado (code=${code})`);
    loopProcess = null;
  });

  res.json({ ok: true, pid: loopProcess.pid });
});

app.post('/api/loop/stop', (_req, res) => {
  if (!loopProcess) {
    return res.json({ ok: true, message: 'Nenhum loop ativo' });
  }
  loopProcess.kill('SIGTERM');
  loopProcess = null;
  pushLog('Loop parado pelo usuário');
  res.json({ ok: true });
});

function pushBatchLog(line) {
  batchPrepState.logs.push({ at: new Date().toISOString(), line });
  if (batchPrepState.logs.length > 120) batchPrepState.logs.shift();
}

async function fetchMongoProfileStats(apiUrl) {
  try {
    const base = resolveApiUrl(apiUrl);
    const r = await fetch(`${base}/api/v1/batch/profile-stats`);
    if (!r.ok) return null;
    return await r.json();
  } catch {
    return null;
  }
}

function lakeLayersReady() {
  const layers = ['bronze', 'silver', 'gold'];
  let ready = 0;
  for (const layer of layers) {
    const dir = path.join(PROJECT_ROOT, 'data', 'lake', layer);
    try {
      if (fsSync.existsSync(dir) && fsSync.readdirSync(dir).length > 0) ready += 1;
    } catch {
      /* ignore */
    }
  }
  return ready;
}

function dockerNetworkName() {
  const project = process.env.COMPOSE_PROJECT_NAME || 'datamaster';
  return `${project}_fraud-network`;
}

/** Caminho do projeto no host (Docker Desktop precisa disso no `docker run -v`). */
function hostWorkspaceForDocker() {
  if (process.env.DOCKER_HOST_WORKSPACE) {
    return process.env.DOCKER_HOST_WORKSPACE;
  }
  try {
    const line = fsSync
      .readFileSync('/proc/self/mountinfo', 'utf8')
      .split('\n')
      .find((l) => l.includes(' /workspace '));
    if (!line) return PROJECT_ROOT;
    const beforeSep = line.split(' - ')[0].trim().split(/\s+/);
    const workspaceIdx = beforeSep.indexOf('/workspace');
    const root =
      workspaceIdx > 0 ? beforeSep[workspaceIdx - 1] : beforeSep[3];
    if (!root || root === '/workspace') return PROJECT_ROOT;
    if (root.startsWith('/Users/')) return root;
    if (root.startsWith('/')) return `/Users${root}`;
    return PROJECT_ROOT;
  } catch {
    return PROJECT_ROOT;
  }
}

async function runSparkMedallion(pushLogLine) {
  if (!fsSync.existsSync('/var/run/docker.sock')) {
    pushLogLine(
      'Spark: monte docker.sock no data-console ou rode bash scripts/run_demo.sh no host'
    );
    return false;
  }
  pushLogLine('Pipeline Spark (Bronze → Silver → Gold)…');
  const hostWorkspace = hostWorkspaceForDocker();
  pushLogLine(`Spark via docker run (host: ${hostWorkspace})`);
  const spark = await runCommand('docker', [
    'run',
    '--rm',
    '--network',
    dockerNetworkName(),
    '-v',
    `${hostWorkspace}:/workspace`,
    '-w',
    '/workspace',
    '-e',
    'SPARK_DEMO_LOCAL=1',
    '-e',
    'HOME=/tmp',
    '-e',
    'USER=root',
    '-e',
    'HADOOP_USER_NAME=root',
    '-e',
    'SPARK_INPUT=data/transactions.json',
    '--user',
    '0:0',
    'bitnamilegacy/spark:3.5.5',
    '/bin/bash',
    '/workspace/docker/spark-job-entrypoint.sh',
  ]);
  if (spark.stdout.trim()) {
    spark.stdout
      .trim()
      .split('\n')
      .slice(-8)
      .forEach((line) => pushLogLine(line));
  }
  const layers = lakeLayersReady();
  pushLogLine(`Lake Medallion: ${layers}/3 camadas com dados`);
  return layers >= 3;
}

app.get('/api/batch-prep/status', async (req, res) => {
  const mongoStats = await fetchMongoProfileStats(req.query.apiUrl);
  res.json({
    ...batchPrepState,
    mongoStats,
    logs: batchPrepState.logs.slice(-40),
  });
});

app.post('/api/batch-prep/run', async (req, res) => {
  if (batchPrepState.running) {
    return res.status(409).json({ ok: false, error: 'Batch dataprep já em execução' });
  }
  const num = Math.min(5000, Math.max(100, Number(req.body.num) || 800));
  const fraudRate = Math.min(1, Math.max(0, Number(req.body.fraudRate) ?? 0.08));
  const rel = req.body.output || DEFAULT_OUTPUT;
  const apiUrl = resolveApiUrl(req.body.apiUrl);
  const python = process.env.PYTHON || 'python3';
  const mongoUri = req.body.mongoUri || DEFAULT_MONGO_URI;

  batchPrepState = {
    running: true,
    startedAt: new Date().toISOString(),
    finishedAt: null,
    ok: null,
    error: null,
    logs: [],
    stats: null,
  };
  pushBatchLog(`Iniciando dataprep → MongoDB (${num} transações)`);
  res.json({ ok: true, message: 'Batch dataprep iniciado' });

  (async () => {
    try {
      const absolute = resolveDataPath(rel);
      pushBatchLog('Gerando data/transactions.json…');
      const gen = await runCommand(python, [
        'scripts/generate_data.py',
        '-n',
        String(num),
        '-o',
        rel,
        '--fraud-rate',
        String(fraudRate),
      ]);
      if (gen.stdout.trim()) pushBatchLog(gen.stdout.trim().split('\n').pop());

      pushBatchLog('Executando batch_dataprep_mongo.py…');
      try {
        await runCommand(python, ['-m', 'pip', 'install', '-q', 'pymongo']);
      } catch {
        /* pymongo pode já estar instalado */
      }
      const prep = await runCommand(
        python,
        ['scripts/batch_dataprep_mongo.py', '-i', rel],
        { MONGODB_URI: mongoUri }
      );
      if (prep.stdout.trim()) {
        prep.stdout
          .trim()
          .split('\n')
          .forEach((line) => pushBatchLog(line));
      }

      const fileStats = await readFileStats(absolute);
      const mongoStats = await fetchMongoProfileStats(apiUrl);
      let sparkOk = false;
      try {
        sparkOk = await runSparkMedallion(pushBatchLog);
      } catch (sparkErr) {
        batchPrepState.ok = false;
        batchPrepState.error = sparkErr.message;
        pushBatchLog(`Erro Spark: ${sparkErr.message}`);
        throw sparkErr;
      }
      if (!sparkOk) {
        throw new Error(
          'Pipeline Spark incompleto — use bash scripts/run_demo.sh no host ou monte docker.sock no data-console'
        );
      }

      const mongoStatsAfter = await fetchMongoProfileStats(apiUrl);
      batchPrepState.stats = {
        file: fileStats,
        mongo: mongoStatsAfter || mongoStats,
        lake_layers: lakeLayersReady(),
        spark_ok: sparkOk,
      };
      batchPrepState.ok = true;
      pushBatchLog(
        `Fluxo completo — ${mongoStatsAfter?.mongodb_profiles_loaded ?? mongoStats?.mongodb_profiles_loaded ?? '?'} perfis MongoDB, lake ${lakeLayersReady()}/3`
      );
    } catch (e) {
      batchPrepState.ok = false;
      batchPrepState.error = e.message;
      pushBatchLog(`Erro: ${e.message}`);
    } finally {
      batchPrepState.running = false;
      batchPrepState.finishedAt = new Date().toISOString();
    }
  })();
});

app.listen(PORT, () => {
  console.log(`Console do gerador: http://localhost:${PORT}`);
  console.log(`Projeto: ${PROJECT_ROOT}`);
});
