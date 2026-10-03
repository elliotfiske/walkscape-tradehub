#!/usr/bin/env node
// Tail console messages from a Chrome tab via the DevTools Protocol.
//
// Prereqs:
//   1. Launch a debuggable Chrome (separate profile so your normal browser is undisturbed):
//        /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
//          --remote-debugging-port=9222 \
//          --user-data-dir=/tmp/chrome-debug \
//          http://localhost:8000
//   2. `npm install` at the repo root (provides `ws`).
//
// Usage:
//   node scripts/cdp-console.js [--port <n>] [duration-seconds] [ws-url-override]
//
// Picks the first matching localhost tab. Pass --port when several worktrees
// run `lamdera live` in the shared debug Chrome to pin to your worktree's port.
// This tails the *frontend* console; for backend state use `lamdera backend`
// from the terminal (see CLAUDE.md).

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

const duration = parseFloat(positional[0] || '10') * 1000;
const wsOverride = positional[1];

// No explicit --port (and not pinned to a ws URL): default to this worktree's
// lamdera-live port.
if (port === null && !wsOverride) port = detectWorktreePort();

const fetchTabs = () => new Promise((resolve, reject) => {
  http.get('http://localhost:9222/json', (res) => {
    let body = '';
    res.on('data', (c) => body += c);
    res.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { reject(e); } });
  }).on('error', reject);
});

async function pickTab() {
  if (wsOverride) return wsOverride;
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
  console.error(`[cdp] attaching to: ${t.title} — ${t.url}`);
  return t.webSocketDebuggerUrl;
}

function fmtArg(a) {
  if (a.value !== undefined) return typeof a.value === 'string' ? a.value : JSON.stringify(a.value);
  if (a.unserializableValue) return a.unserializableValue;
  return a.description ?? a.type;
}

async function main() {
  const wsUrl = await pickTab();
  const ws = new WebSocket(wsUrl);
  let id = 0;
  const send = (method, params = {}) => ws.send(JSON.stringify({ id: ++id, method, params }));

  ws.on('open', () => {
    send('Runtime.enable');
    send('Log.enable');
  });

  ws.on('message', (data) => {
    const msg = JSON.parse(data);
    if (msg.method === 'Runtime.consoleAPICalled') {
      const { type, args, stackTrace } = msg.params;
      const loc = stackTrace?.callFrames?.[0];
      const where = loc ? `${(loc.url || '').split('/').pop()}:${loc.lineNumber + 1}` : '';
      console.log(`[${type}] ${args.map(fmtArg).join(' ')}${where ? '  (' + where + ')' : ''}`);
    } else if (msg.method === 'Runtime.exceptionThrown') {
      const e = msg.params.exceptionDetails;
      console.log(`[exception] ${e.text} ${e.exception?.description || ''}`);
    } else if (msg.method === 'Log.entryAdded') {
      const e = msg.params.entry;
      console.log(`[log/${e.level}] ${e.text}`);
    }
  });

  ws.on('error', (e) => { console.error('ws error:', e.message); process.exit(1); });
  setTimeout(() => { ws.close(); process.exit(0); }, duration);
}

main().catch((e) => { console.error(e.message); process.exit(1); });
