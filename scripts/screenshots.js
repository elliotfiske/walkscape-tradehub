#!/usr/bin/env node
// Screenshot every route × viewport in scripts/screenshot-routes.json with a
// fresh headless Chromium (Playwright). Unlike cdp-screenshot.js this needs no
// running debug Chrome — just a base URL — so it works in CI and cloud
// sessions, against `lamdera live` or a deployed preview.
//
// Usage:
//   node scripts/screenshots.js                               # localhost:8000 → screenshots/
//   node scripts/screenshots.js --base http://localhost:8002 --out /tmp/shots
//   node scripts/screenshots.js --base https://<app>-pr-12.lamdera.app
//
// Prints one PNG path per line on stdout. Browser: Playwright's own lookup
// (PLAYWRIGHT_BROWSERS_PATH — preinstalled in cloud sessions; in CI run
// `npx playwright-core install chromium` first), or CHROME_BIN to override.

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright-core');

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

(async () => {
  const base = arg('base', 'http://localhost:8000').replace(/\/$/, '');
  const outDir = path.resolve(arg('out', 'screenshots'));
  const config = JSON.parse(fs.readFileSync(path.join(__dirname, 'screenshot-routes.json'), 'utf8'));
  fs.mkdirSync(outDir, { recursive: true });

  // CI runners have no GPU and a small /dev/shm; without these flags Chromium
  // can stall producing a frame, so page.screenshot() hangs until it times out.
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_BIN || undefined,
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
  });
  let failed = 0;

  // Load a route and capture the viewport. Viewport-only on purpose
  // (investigated 2026-10-03, PR #3): on GitHub runners
  // page.screenshot({ fullPage: true }) stalled ~50% of the time (10-30s
  // timeout, even on pages as tall as the viewport); viewport captures never
  // did. Not the network (only Google Fonts) and not reproducible locally, even
  // with 20x CPU throttling. --disable-gpu/--disable-dev-shm-usage didn't fix
  // it. Retrying helps but costs ~16s per stall. Don't re-add fullPage without
  // testing in CI. If a frame still never arrives, retry once on a fresh page.
  async function capture(context, route, file) {
    let lastError;
    for (let i = 0; i < 2; i++) {
      const page = await context.newPage();
      const t0 = Date.now();
      try {
        await page.goto(base + route.path, { waitUntil: 'load', timeout: 30000 });
        // `lamdera live` keeps long-lived connections (websocket, dev-tool
        // polling) open, so networkidle may never fire — treat it as a
        // best-effort wait rather than a requirement.
        await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});
        // Lamdera opens a websocket and renders the first ToFrontend after
        // load; give it a beat so we don't capture the pre-connect frame.
        await page.waitForTimeout(Number(route.settleMs ?? 1000));
        await page.screenshot({ path: file, timeout: 10000 });
        console.error(`[screenshots] ${path.basename(file)} ok in ${Date.now() - t0}ms (attempt ${i + 1})`);
        return;
      } catch (e) {
        lastError = e;
        console.error(`[screenshots] ${path.basename(file)} attempt ${i + 1} failed after ${Date.now() - t0}ms: ${e.message.split('\n')[0]}`);
      } finally {
        await page.close().catch(() => {});
      }
    }
    throw lastError;
  }

  try {
    for (const vp of config.viewports) {
      const context = await browser.newContext({
        viewport: { width: vp.width, height: vp.height },
        deviceScaleFactor: 1,
        isMobile: vp.width < 600,
      });
      for (const route of config.routes) {
        const file = path.join(outDir, `${route.name}-${vp.name}.png`);
        try {
          await capture(context, route, file);
          console.log(file);
        } catch (e) {
          failed++;
          console.error(`[screenshots] ${route.name}@${vp.name}: ${e.message}`);
        }
      }
      await context.close();
    }
  } finally {
    await browser.close();
  }
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
