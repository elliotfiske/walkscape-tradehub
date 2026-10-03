#!/usr/bin/env node
// Stamp src/Frontend.elm's `/output.css?dev=<hash>` cache-busters with a short
// content hash of public/output.css, so the query string changes if and only
// if the CSS content changes. Lamdera live then picks up the Frontend.elm edit
// and reloads the browser with the new query string, defeating Chrome's CSS
// cache; in production the same stamp makes returning browsers refetch
// /output.css only when it actually changed.
//
// Modes:
//   node scripts/cachebust.js          # watch output.css, restamp on change (dev)
//   node scripts/cachebust.js --once   # restamp once and exit (used by pre-commit)
//
// A content hash (not an incrementing counter) keeps the value deterministic:
// rebuilding identical CSS yields the same stamp, so commits don't churn
// Frontend.elm and the dev watcher never fights the pre-commit hook.
//
// The stamp lives on the `<link rel="stylesheet" href="/output.css?dev=...">`
// node in the view. If you move the view out of Frontend.elm (e.g. into a
// View.elm module), point `viewPath` below at that file instead.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = path.join(__dirname, '..');
const cssPath = path.join(root, 'public', 'output.css');
const viewPath = path.join(root, 'src', 'Frontend.elm');
// Matches both the legacy numeric counter (?dev=8) and the hash form (?dev=a1b2c3d4).
// markerRe (non-global) is for the presence check — a /g regex would mutate
// lastIndex across .test() calls and can return false negatives in watch mode.
// stampRe (global) rewrites every occurrence.
const markerRe = /\/output\.css\?dev=[0-9a-f]+/;
const stampRe = /\/output\.css\?dev=[0-9a-f]+/g;

function stamp() {
  let css;
  try {
    css = fs.readFileSync(cssPath);
  } catch (e) {
    console.error(`[cachebust] cannot read ${cssPath}: ${e.message}`);
    return false;
  }
  const hash = crypto.createHash('sha256').update(css).digest('hex').slice(0, 8);

  let src;
  try {
    src = fs.readFileSync(viewPath, 'utf8');
  } catch (e) {
    console.error(`[cachebust] cannot read ${viewPath}: ${e.message}`);
    return false;
  }
  if (!markerRe.test(src)) {
    console.error(`[cachebust] no /output.css?dev=… marker in ${path.basename(viewPath)}`);
    return false;
  }
  const next = src.replace(stampRe, `/output.css?dev=${hash}`);
  if (next === src) return true; // already current — no write needed, success
  try {
    fs.writeFileSync(viewPath, next);
    console.log(`[cachebust] stamped /output.css?dev=${hash}`);
    return true;
  } catch (e) {
    console.error(`[cachebust] write ${viewPath} failed: ${e.message}`);
    return false;
  }
}

// stamp() returns true on success (including the no-op "already current" case)
// and false only on a genuine error, so --once can fail the commit on error
// without tripping on every commit where the CSS didn't change.
if (process.argv.includes('--once')) {
  process.exit(stamp() ? 0 : 1);
}

if (!fs.existsSync(cssPath)) {
  console.log(`[cachebust] waiting for ${cssPath} to exist`);
}

let timer = null;
fs.watch(path.dirname(cssPath), { persistent: true }, (_event, name) => {
  if (name !== 'output.css') return;
  // debounce: tailwind may write in bursts
  clearTimeout(timer);
  timer = setTimeout(stamp, 150);
});

console.log(`[cachebust] watching ${cssPath}`);
