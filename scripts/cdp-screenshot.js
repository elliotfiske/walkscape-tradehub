#!/usr/bin/env node
// Capture a PNG screenshot of a Lamdera tab via Chrome DevTools Protocol.
//
// Prereqs: same as cdp-console.js (debuggable Chrome on :9222, `npm install`).
//
// Usage:
//   node scripts/cdp-screenshot.js                       # → /tmp/lamdera-screenshot.png
//   node scripts/cdp-screenshot.js --out shot.png        # custom output path
//   node scripts/cdp-screenshot.js --full-page           # capture beyond viewport
//   node scripts/cdp-screenshot.js --port 8002           # only localhost:8002 tabs
//
// Picks the first matching localhost tab. Pass --port when several worktrees
// run `lamdera live` in the shared debug Chrome to pin to your worktree's port.
//
// Prints the absolute output path on stdout; the Read tool can open the PNG.

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
const fullPage = args.includes('--full-page');
const mobile = args.includes('--mobile');
const widthIdx = args.indexOf('--width');
const heightIdx = args.indexOf('--height');
const customWidth = widthIdx >= 0 ? parseInt(args[widthIdx + 1], 10) : null;
const customHeight = heightIdx >= 0 ? parseInt(args[heightIdx + 1], 10) : null;
const outIdx = args.indexOf('--out');
const outPath = path.resolve(outIdx >= 0 ? args[outIdx + 1] : '/tmp/lamdera-screenshot.png');

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
  let id = 0;
  const pending = new Map();
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const myId = ++id;
    pending.set(myId, { resolve, reject });
    ws.send(JSON.stringify({ id: myId, method, params }));
  });

  ws.on('message', (data) => {
    const m = JSON.parse(data);
    if (m.id && pending.has(m.id)) {
      const { resolve, reject } = pending.get(m.id);
      pending.delete(m.id);
      if (m.error) reject(new Error(m.error.message));
      else resolve(m.result);
    }
  });

  ws.on('error', (e) => { console.error('ws error:', e.message); process.exit(1); });

  await new Promise((r) => ws.on('open', r));

  if (mobile || customWidth || customHeight) {
    const width = customWidth || (mobile ? 390 : 1024);
    const height = customHeight || (mobile ? 844 : 768);
    await send('Emulation.setDeviceMetricsOverride', {
      width,
      height,
      deviceScaleFactor: mobile ? 2 : 1,
      mobile: !!mobile,
    });
  }

  const params = { format: 'png' };
  if (fullPage) {
    const { contentSize } = await send('Page.getLayoutMetrics');
    params.captureBeyondViewport = true;
    params.clip = { x: 0, y: 0, width: contentSize.width, height: contentSize.height, scale: 1 };
  }

  const { data: b64 } = await send('Page.captureScreenshot', params);
  fs.writeFileSync(outPath, Buffer.from(b64, 'base64'));
  console.log(outPath);
  ws.close();
  process.exit(0);
}

main().catch((e) => { console.error(e.message); process.exit(1); });
