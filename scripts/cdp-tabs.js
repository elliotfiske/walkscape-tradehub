#!/usr/bin/env node
// List Chrome tabs via the DevTools Protocol — a compact, reliable replacement
// for `curl -s http://localhost:9222/json | jq ...`.
//
// Prereqs: same as cdp-console.js (debuggable Chrome on :9222, `npm install`).
//
// Usage:
//   node scripts/cdp-tabs.js                 # compact list
//   node scripts/cdp-tabs.js --ws            # also print each tab's webSocket URL
//   node scripts/cdp-tabs.js --json          # machine-readable array (trimmed fields)
//   node scripts/cdp-tabs.js --port 8002     # only list localhost:8002 tabs
//
// Lists every `type: "page"` tab (or only one port's tabs with --port — handy
// when several worktrees run `lamdera live` in the shared debug Chrome).
// Diagnostics go to stderr; the listing goes to stdout. For backend state, use
// `lamdera backend` from the terminal (see CLAUDE.md) rather than a tab.

const http = require('http');

const args = process.argv.slice(2);
const asJson = args.includes('--json');
const showWs = args.includes('--ws');
const portEq = args.find((a) => a.startsWith('--port='));
const portIdx = args.indexOf('--port');
const port = portEq ? portEq.slice('--port='.length) : portIdx >= 0 ? args[portIdx + 1] : null;
if (port !== null && !/^\d+$/.test(port || '')) { console.error(`invalid --port: ${port}`); process.exit(1); }

const fetchTabs = () => new Promise((resolve, reject) => {
  http.get('http://localhost:9222/json', (res) => {
    let body = '';
    res.on('data', (c) => body += c);
    res.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { reject(e); } });
  }).on('error', reject);
});

// Strip query string and fragment before logging to the terminal — tab URLs can
// carry params, while ws:// debugger URLs have none (so --ws output is
// unaffected). The --json output keeps full URLs since it's for machine use.
const redactUrl = (raw) => {
  try {
    const u = new URL(raw);
    u.search = '';
    u.hash = '';
    return u.toString();
  } catch {
    return '(invalid-url)';
  }
};

async function main() {
  const portRe = port ? new RegExp(`^https?://localhost:${port}(/|$)`) : null;
  const pages = (await fetchTabs()).filter(
    (t) => t.type === 'page' && (!portRe || portRe.test(t.url || ''))
  );
  if (!pages.length) {
    console.error(port ? `[cdp] no localhost:${port} tabs open on :9222` : '[cdp] no page tabs open on :9222');
    process.exit(0);
  }

  const rows = pages.map((t, i) => ({
    index: i,
    title: t.title || '(untitled)',
    url: t.url,
    ws: t.webSocketDebuggerUrl,
  }));

  if (asJson) {
    console.log(JSON.stringify(rows, null, 2));
    return;
  }

  for (const r of rows) {
    const line = `${String(r.index).padEnd(2)} ${r.title.slice(0, 40).padEnd(40)} ${redactUrl(r.url)}`;
    console.log(line);
    if (showWs) console.log(`   ${redactUrl(r.ws)}`);
  }
}

main().catch((e) => {
  if (e.code === 'ECONNREFUSED') {
    console.error('[cdp] connection refused on :9222 — is debuggable Chrome running? See CLAUDE.md.');
  } else {
    // Log a bounded error category rather than the raw message, which could
    // echo back URL/query content from an upstream failure.
    console.error(`[cdp] failed to list tabs (${e.code || e.name || 'unknown error'})`);
  }
  process.exit(1);
});
