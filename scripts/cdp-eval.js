#!/usr/bin/env node
// Evaluate a JS expression in a Lamdera tab via Chrome DevTools Protocol.
//
// Prereqs: same as cdp-console.js (debuggable Chrome on :9222, `npm install`).
//
// Usage:
//   node scripts/cdp-eval.js "document.title"
//   node scripts/cdp-eval.js "location.reload(); 'reloading'"
//   echo "1+2" | node scripts/cdp-eval.js -            # read expression from stdin
//   node scripts/cdp-eval.js --port 8002 "1+1"         # only localhost:8002 tabs
//
// Picks the first matching localhost tab. With several worktrees each running
// `lamdera live` on its own port in the shared debug Chrome, pass --port to pin
// selection to your worktree's port. Wraps the expression in an IIFE so
// multi-statement scripts work and `const`/`let` are scoped. Awaits promises
// automatically. This drives the *frontend*; for backend state use
// `lamdera backend` from the terminal (see CLAUDE.md).

const http = require('http');
const WebSocket = require('ws');
const { detectWorktreePort } = require('./cdp-port');

const args = process.argv.slice(2);
let port = null;
const positional = [];
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--port') { port = args[++i]; continue; }
  if (a.startsWith('--port=')) { port = a.slice('--port='.length); continue; }
  positional.push(a);
}
if (port !== null && !/^\d+$/.test(port || '')) { console.error(`invalid --port: ${port}`); process.exit(1); }
// No explicit --port: try to default to this worktree's lamdera-live port.
if (port === null) port = detectWorktreePort();
const exprArg = positional[0];
if (!exprArg) { console.error('usage: cdp-eval.js [--port <n>] <expression|->'); process.exit(1); }

async function readExpr() {
  if (exprArg !== '-') return exprArg;
  return new Promise((resolve) => {
    let buf = '';
    process.stdin.on('data', (c) => buf += c);
    process.stdin.on('end', () => resolve(buf));
  });
}

const fetchTabs = () => new Promise((resolve, reject) => {
  http.get('http://localhost:9222/json', (res) => {
    let body = '';
    res.on('data', (c) => body += c);
    res.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { reject(e); } });
  }).on('error', reject);
});

async function pickTab() {
  const urlRe = port
    ? new RegExp(`^https?://localhost:${port}(/|$)`)
    : /^https?:\/\/localhost:\d+/;
  const tabs = (await fetchTabs()).filter((t) => t.type === 'page' && urlRe.test(t.url));
  if (!tabs.length) {
    throw new Error(
      port
        ? `no localhost:${port} tab found on :9222`
        : 'no localhost tab found on :9222 (the URL must include an explicit port, e.g. http://localhost:8000)'
    );
  }
  const t = tabs[0];
  console.error(`[cdp] tab: ${t.title} — ${t.url}`);
  return t.webSocketDebuggerUrl;
}

function formatResult(r) {
  if (!r) return 'null';
  if (r.type === 'string') return r.value;
  if (r.value !== undefined) return JSON.stringify(r.value, null, 2);
  if (r.unserializableValue) return r.unserializableValue;
  return r.description ?? r.type;
}

async function main() {
  // CDP's Runtime.evaluate handles multi-statement scripts natively and
  // returns the completion value of the last expression-statement.
  // For async code, the user should wrap in `(async () => { ... })()`.
  const expression = (await readExpr()).trim();
  const wsUrl = await pickTab();
  const ws = new WebSocket(wsUrl);

  ws.on('open', () => {
    ws.send(JSON.stringify({
      id: 1,
      method: 'Runtime.evaluate',
      params: { expression, returnByValue: true, awaitPromise: true },
    }));
  });

  ws.on('message', (d) => {
    const m = JSON.parse(d);
    if (m.id !== 1) return;
    if (m.result?.exceptionDetails) {
      const e = m.result.exceptionDetails;
      console.error(`[exception] ${e.text} ${e.exception?.description || ''}`);
      ws.close();
      process.exit(1);
    }
    console.log(formatResult(m.result?.result));
    ws.close();
    process.exit(0);
  });

  ws.on('error', (e) => { console.error('ws error:', e.message); process.exit(1); });
}

main().catch((e) => { console.error(e.message); process.exit(1); });
