#!/usr/bin/env node
// Dump the post-Elm-init HTML of a Lamdera tab via Chrome DevTools Protocol.
//
// Prereqs: same as cdp-console.js (debuggable Chrome on :9222, `npm install`).
//
// Usage:
//   node scripts/cdp-html.js                            # → stdout
//   node scripts/cdp-html.js --out page.html            # write to file (prints path)
//   node scripts/cdp-html.js --selector '[data-testid="message"]'  # outerHTML of a node
//   node scripts/cdp-html.js --port 8002                # only localhost:8002 tabs
//
// Picks the first matching localhost tab. Pass --port when several worktrees
// run `lamdera live` in the shared debug Chrome to pin to your worktree's port.
//
// Unlike `curl localhost:8000`, this returns the DOM *after* the Elm runtime
// has rendered, so client-side view output is included.

const http = require('http');
const path = require('path');
const fs = require('fs');
const WebSocket = require('ws');
const { detectWorktreePort } = require('./cdp-port');

const args = process.argv.slice(2);
const portEq = args.find((a) => a.startsWith('--port='));
const portIdx = args.indexOf('--port');
let port = portEq ? portEq.slice('--port='.length) : portIdx >= 0 ? args[portIdx + 1] : null;
if (port !== null && !/^\d+$/.test(port || '')) { console.error(`invalid --port: ${port}`); process.exit(1); }
// No explicit --port: try to default to this worktree's lamdera-live port.
if (port === null) port = detectWorktreePort();
const outIdx = args.indexOf('--out');
const outPath = outIdx >= 0 ? path.resolve(args[outIdx + 1]) : null;
const selIdx = args.indexOf('--selector');
const selector = selIdx >= 0 ? args[selIdx + 1] : null;

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

async function main() {
  const wsUrl = await pickTab();
  const ws = new WebSocket(wsUrl);

  // Build the expression. JSON-stringify the selector to escape it safely.
  const expression = selector
    ? `(() => { const el = document.querySelector(${JSON.stringify(selector)}); if (!el) throw new Error('selector not found: ' + ${JSON.stringify(selector)}); return el.outerHTML; })()`
    : `document.documentElement.outerHTML`;

  ws.on('open', () => {
    ws.send(JSON.stringify({
      id: 1,
      method: 'Runtime.evaluate',
      params: { expression, returnByValue: true },
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
    const html = m.result?.result?.value ?? '';
    if (outPath) {
      fs.writeFileSync(outPath, html);
      console.log(outPath);
    } else {
      process.stdout.write(html);
      if (!html.endsWith('\n')) process.stdout.write('\n');
    }
    ws.close();
    process.exit(0);
  });

  ws.on('error', (e) => { console.error('ws error:', e.message); process.exit(1); });
}

main().catch((e) => { console.error(e.message); process.exit(1); });
