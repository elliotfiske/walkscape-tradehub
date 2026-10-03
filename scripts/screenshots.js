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

  // Load a route and capture the viewport (not fullPage; see the note below).
  // A screenshot taken before the Elm app has rendered is a blank white page,
  // so wait until the app's text is on screen and the stylesheet has applied,
  // and retry once on a fresh page if that never happens.
  async function capture(context, route, file) {
    let lastError;
    for (let i = 0; i < 2; i++) {
      const page = await context.newPage();
      const t0 = Date.now();
      const problems = [];
      page.on('console', (m) => { if (m.type() === 'error') problems.push(`console.error: ${m.text().slice(0, 200)}`); });
      page.on('framenavigated', (f) => { if (f === page.mainFrame()) problems.push(`navigated: ${f.url().slice(0, 100)}`); });
      page.on('pageerror', (e) => problems.push(`pageerror: ${String(e.message).slice(0, 200)}`));
      page.on('requestfailed', (r) => problems.push(`requestfailed: ${r.url().slice(0, 120)} ${r.failure()?.errorText}`));
      try {
        await page.goto(base + route.path, { waitUntil: 'load', timeout: 30000 });
        await page.waitForFunction(
          (text) =>
            document.body.innerText.includes(text) &&
            getComputedStyle(document.body).backgroundColor !== 'rgba(0, 0, 0, 0)',
          config.readyText || 'Trailpost',
          { timeout: Number(route.readyTimeoutMs ?? 45000) },
        );
        // Lamdera opens a websocket and renders the first ToFrontend after
        // load; give it a beat so we don't capture the pre-connect frame.
        await page.waitForTimeout(Number(route.settleMs ?? 1000));
        await page.screenshot({ path: file, timeout: 15000 });
        console.error(`[screenshots] ${path.basename(file)} ok in ${Date.now() - t0}ms (attempt ${i + 1})`);
        return;
      } catch (e) {
        lastError = e;
        console.error(`[screenshots] ${path.basename(file)} attempt ${i + 1} failed after ${Date.now() - t0}ms: ${e.message.split('\n')[0]}`);
        for (const p of problems.slice(0, 10)) console.error(`[screenshots]   ${p}`);
        const body = await page.evaluate(() => document.body.innerText.slice(0, 120)).catch(() => '(page gone)');
        console.error(`[screenshots]   body text: ${JSON.stringify(body)}`);
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
      // The `lamdera live` dev backend runs inside a browser tab, so closing or
      // reloading the only tab drops it mid-capture (aborted requests, blank
      // frames). Keep one leader tab open on the app for this whole context.
      const leader = await context.newPage();
      await leader.goto(base + '/', { waitUntil: 'load', timeout: 30000 }).catch(() => {});
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
      await leader.close().catch(() => {});
      await context.close();
    }
  } finally {
    await browser.close();
  }
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
