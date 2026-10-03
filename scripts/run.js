#!/usr/bin/env node
// Start `lamdera live` and a debuggable Chrome on free ports, and babysit
// lamdera: auto-restart on crash, or when its output matches a bad-state
// pattern (see BAD_STATE_PATTERNS below — append as you spot new ones).
//
// Usage:
//   node scripts/run.js              # auto-pick ports
//   LAMDERA_PORT=8005 node scripts/run.js   # force lamdera port
//   CHROME_PORT=9230 node scripts/run.js    # force chrome debug port
//   node scripts/run.js --no-chrome  # skip launching Chrome
//
// On Linux (e.g. Claude Code cloud sessions) it launches the Playwright-bundled
// Chromium headless instead of macOS Chrome; override with CHROME_BIN.

const net = require('net');
const http = require('http');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const noChrome = process.argv.includes('--no-chrome');

// Patterns in lamdera live output that indicate it's stuck and needs a
// restart. Each entry pairs a regex with an optional `prewarm` flag — when
// set, we run `lamdera make` before respawning `lamdera live`, because a bare
// restart isn't enough to clear the underlying state.
const BAD_STATE_PATTERNS = [
  { re: /🚨/ }, // 🚨 — lamdera live shows this when it's in a bad state
  { re: /Ran into some weird problem loading elm\.json/, prewarm: true }, // fresh-worktree elm-stuff race; only `lamdera make` clears it
];

const MAX_RESTARTS_PER_MINUTE = 5;

async function findFreePort(start, end = start + 50, opts = {}) {
  const step = opts.step || 1;
  for (let p = start; p <= end; p += step) {
    if (await isPortFree(p)) return p;
  }
  throw new Error(`no free port in ${start}-${end} (step ${step})`);
}

function isPortFree(port) {
  return new Promise((resolve) => {
    const srv = net.createServer();
    srv.once('error', () => resolve(false));
    srv.once('listening', () => srv.close(() => resolve(true)));
    srv.listen(port, '0.0.0.0');
  });
}

function waitForHttp(port, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  return new Promise((resolve, reject) => {
    const tick = () => {
      const req = http.get({ host: '127.0.0.1', port, path: '/', timeout: 1000 }, (res) => {
        res.resume();
        resolve();
      });
      req.on('error', () => {
        if (Date.now() > deadline) reject(new Error(`lamdera not responding on :${port}`));
        else setTimeout(tick, 300);
      });
      req.on('timeout', () => req.destroy());
    };
    tick();
  });
}

let lamderaProc = null;
let chromeProc = null;
let tailwindProc = null;
let cachebustProc = null;
let shuttingDown = false;
const restartTimes = [];

function runBuildCssOnce() {
  return new Promise((resolve, reject) => {
    console.log('[run] running `npm run build:css` once (fresh-worktree safety)');
    const proc = spawn('npm', ['run', 'build:css'], {
      stdio: ['ignore', 'pipe', 'pipe'],
      env: process.env,
      cwd: path.join(__dirname, '..'),
    });
    proc.stdout.on('data', (chunk) => process.stdout.write(`[tailwind-init] ${chunk}`));
    proc.stderr.on('data', (chunk) => process.stderr.write(`[tailwind-init] ${chunk}`));
    proc.on('exit', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`build:css exited code=${code}`));
    });
    proc.on('error', reject);
  });
}

function startTailwind() {
  console.log('[run] starting tailwind watcher (npm run watch:css)');
  const proc = spawn('npm', ['run', 'watch:css'], {
    stdio: ['ignore', 'pipe', 'pipe'],
    env: process.env,
    cwd: path.join(__dirname, '..'),
  });
  proc.stdout.on('data', (chunk) => process.stdout.write(`[tailwind] ${chunk}`));
  proc.stderr.on('data', (chunk) => process.stderr.write(`[tailwind] ${chunk}`));
  proc.on('exit', (code) => {
    if (shuttingDown) return;
    console.error(`[run] tailwind exited (code=${code}); leaving lamdera running`);
  });
  tailwindProc = proc;
}

function startCachebust() {
  console.log('[run] starting cachebust watcher');
  const proc = spawn('node', ['scripts/cachebust.js'], {
    stdio: ['ignore', 'pipe', 'pipe'],
    env: process.env,
    cwd: path.join(__dirname, '..'),
  });
  proc.stdout.on('data', (chunk) => process.stdout.write(`${chunk}`));
  proc.stderr.on('data', (chunk) => process.stderr.write(`${chunk}`));
  proc.on('exit', (code) => {
    if (shuttingDown) return;
    console.error(`[run] cachebust exited (code=${code}); leaving lamdera running`);
  });
  cachebustProc = proc;
}

function startLamdera(port) {
  console.log(`[run] starting lamdera live on :${port}`);
  const proc = spawn('lamdera', ['live', '--port', String(port)], {
    stdio: ['ignore', 'pipe', 'pipe'],
    env: process.env,
  });

  const handleLine = (stream) => (chunk) => {
    const text = chunk.toString();
    process[stream].write(text);
    if (shuttingDown) return;
    for (const pat of BAD_STATE_PATTERNS) {
      if (pat.re.test(text)) {
        console.error(`[run] bad-state pattern matched (${pat.re}); ${pat.prewarm ? 'running `lamdera make` then ' : ''}restarting lamdera`);
        scheduleRestart(port, { prewarm: !!pat.prewarm });
        return;
      }
    }
  };

  proc.stdout.on('data', handleLine('stdout'));
  proc.stderr.on('data', handleLine('stderr'));

  proc.on('exit', (code, sig) => {
    if (shuttingDown) return;
    console.error(`[run] lamdera exited (code=${code} sig=${sig}); restarting`);
    scheduleRestart(port);
  });

  lamderaProc = proc;
}

function scheduleRestart(port, opts = {}) {
  if (shuttingDown) return;
  const now = Date.now();
  restartTimes.push(now);
  while (restartTimes.length && now - restartTimes[0] > 60_000) restartTimes.shift();
  if (restartTimes.length > MAX_RESTARTS_PER_MINUTE) {
    console.error(`[run] >${MAX_RESTARTS_PER_MINUTE} restarts in 60s — giving up`);
    shutdown(1);
    return;
  }
  if (lamderaProc && !lamderaProc.killed) {
    // Capture the ref locally — startLamdera reassigns lamderaProc after
    // ~500ms, so a bare lamderaProc inside the timeout could SIGKILL the
    // fresh process instead of the old one.
    const oldProc = lamderaProc;
    oldProc.removeAllListeners('exit');
    oldProc.kill('SIGTERM');
    setTimeout(() => { if (!oldProc.killed) oldProc.kill('SIGKILL'); }, 2000);
  }
  setTimeout(async () => {
    if (shuttingDown) return;
    if (opts.prewarm) {
      try {
        await runLamderaMake();
      } catch (e) {
        console.error(`[run] lamdera make failed: ${e.message}`);
      }
    }
    if (shuttingDown) return;
    startLamdera(port);
  }, 500);
}

function runLamderaMake() {
  return new Promise((resolve, reject) => {
    console.log('[run] running `lamdera make src/Frontend.elm` to warm elm-stuff');
    const proc = spawn('lamdera', ['make', 'src/Frontend.elm', '--output=/dev/null'], {
      stdio: ['ignore', 'pipe', 'pipe'],
      env: process.env,
      cwd: path.join(__dirname, '..'),
    });
    proc.stdout.on('data', (chunk) => process.stdout.write(`[lamdera-make] ${chunk}`));
    proc.stderr.on('data', (chunk) => process.stderr.write(`[lamdera-make] ${chunk}`));
    proc.on('exit', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`lamdera make exited code=${code}`));
    });
    proc.on('error', reject);
  });
}

function findChrome() {
  if (process.env.CHROME_BIN) return process.env.CHROME_BIN;
  const candidates = ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'];
  // Playwright's bundled Chromium (preinstalled in Claude Code cloud sessions).
  const pwDir = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';
  try {
    for (const d of fs.readdirSync(pwDir).filter((n) => /^chromium-\d+$/.test(n)).sort().reverse()) {
      candidates.push(path.join(pwDir, d, 'chrome-linux', 'chrome'));
    }
  } catch (_) {}
  candidates.push('/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome');
  return candidates.find((c) => fs.existsSync(c)) || null;
}

function startChrome(lamderaPort, chromePort) {
  const userDataDir = `/tmp/chrome-debug-${chromePort}`;
  try { fs.mkdirSync(userDataDir, { recursive: true }); } catch (_) {}
  const chromeBin = findChrome();
  if (!chromeBin) {
    console.error('[run] Chrome not found (set CHROME_BIN); skipping');
    return;
  }
  // No display on Linux servers (cloud sessions, CI): run headless. The CDP
  // scripts (cdp-screenshot.js etc.) work the same either way.
  const headless = process.platform === 'linux' && !process.env.DISPLAY;
  console.log(`[run] starting Chrome${headless ? ' (headless)' : ''} (debug :${chromePort}, profile ${userDataDir})`);
  const proc = spawn(chromeBin, [
    ...(headless ? ['--headless=new', '--no-sandbox', '--window-size=1280,800'] : []),
    `--remote-debugging-port=${chromePort}`,
    `--user-data-dir=${userDataDir}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-features=ChromeWhatsNewUI,SigninInterceptBubbleV2',
    '--disable-sync',
    `http://localhost:${lamderaPort}`,
  ], { stdio: 'ignore', detached: false });
  proc.on('exit', (code) => {
    if (shuttingDown) return;
    console.log(`[run] Chrome exited (code=${code}); leaving lamdera running`);
  });
  chromeProc = proc;
}

function shutdown(exitCode = 0) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log('[run] shutting down');
  for (const p of [lamderaProc, chromeProc, tailwindProc, cachebustProc]) {
    if (p && !p.killed) p.kill('SIGTERM');
  }
  setTimeout(() => process.exit(exitCode), 500);
}

process.on('SIGINT', () => shutdown(0));
process.on('SIGTERM', () => shutdown(0));

(async () => {
  // One-shot CSS build before anything else: tailwind --watch does its first
  // build asynchronously, so on a fresh worktree the browser can race ahead
  // and 404 on /output.css. Block here until the file definitely exists.
  try {
    await runBuildCssOnce();
  } catch (e) {
    console.error(`[run] initial build:css failed: ${e.message} (continuing)`);
  }

  startTailwind();
  startCachebust();

  // lamdera live binds <port> AND reserves <port>+1 as its proxy slot, so
  // step by 2 to avoid colliding with another worktree's proxy reservation.
  const lamderaPort = parseInt(process.env.LAMDERA_PORT, 10) || await findFreePort(8000, 8050, { step: 2 });

  // Pre-warm elm-stuff so a fresh worktree doesn't hit the "weird problem
  // loading elm.json" race on `lamdera live`'s first read.
  try {
    await runLamderaMake();
  } catch (e) {
    console.error(`[run] pre-warm lamdera make failed: ${e.message} (continuing)`);
  }

  startLamdera(lamderaPort);

  if (!noChrome) {
    try {
      await waitForHttp(lamderaPort);
    } catch (e) {
      console.error(`[run] ${e.message}; launching Chrome anyway`);
    }
    const chromePort = parseInt(process.env.CHROME_PORT, 10) || await findFreePort(9222);
    startChrome(lamderaPort, chromePort);
  }

  console.log(`[run] lamdera: http://localhost:${lamderaPort}`);
})().catch((e) => { console.error(e); shutdown(1); });
