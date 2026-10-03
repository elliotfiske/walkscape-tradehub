#!/usr/bin/env node
// Pre-populate ELM_HOME's package cache with `git clone` instead of the
// compiler's own `github.com/<pkg>/zipball/<v>/` downloads.
//
// Why: Claude Code cloud sessions sit behind an egress proxy that scopes
// github.com HTTPS to the session's own repo, so Elm's zipball fetches 400/403
// ("PROBLEM DOWNLOADING PACKAGE") — but git smart-HTTP clones of public repos
// still work. Once a package dir exists under ELM_HOME, lamdera / elm-test-rs /
// elm-review treat it as cached and never hit the zipball URL.
//
// lamdera/* packages are skipped: lamdera fetches those from static.lamdera.com
// itself, which the proxy allows.
//
// Usage:
//   node scripts/elm-prefetch.js                      # elm.json + review/elm.json
//   node scripts/elm-prefetch.js path/to/elm.json …   # explicit files
//   node scripts/elm-prefetch.js --pkg owner/name@1.2.3 …
//
// Idempotent: already-cached versions are skipped. Exit code 1 if any clone
// failed.

const { execFile } = require('child_process');
const { promisify } = require('util');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const ELM_HOME = process.env.ELM_HOME || path.join(os.homedir(), '.elm');
const PKG_DIR = path.join(ELM_HOME, '0.19.1', 'packages');

// Packages some tools resolve on their own, beyond what's listed in the
// project's elm.json files (e.g. elm-test-rs's generated runner project).
const EXTRA = [
  'mpizenberg/elm-test-runner@6.0.1',
  'elm-explorations/test@2.2.0',
  'elm-explorations/test@2.2.1',
];

function depsOf(elmJsonPath) {
  const j = JSON.parse(fs.readFileSync(elmJsonPath, 'utf8'));
  const out = [];
  for (const section of ['dependencies', 'test-dependencies']) {
    const s = j[section] || {};
    for (const kind of ['direct', 'indirect']) {
      for (const [name, v] of Object.entries(s[kind] || {})) out.push(`${name}@${v}`);
    }
  }
  return out;
}

async function main() {
  const args = process.argv.slice(2);
  const specs = [];
  const files = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--pkg') specs.push(args[++i]);
    else files.push(args[i]);
  }
  if (!files.length && !specs.length) {
    files.push(path.join(ROOT, 'elm.json'));
    const review = path.join(ROOT, 'review', 'elm.json');
    if (fs.existsSync(review)) files.push(review);
    specs.push(...EXTRA);
  }
  for (const f of files) specs.push(...depsOf(f));

  const todo = [...new Set(specs)]
    .map((spec) => spec.split('@'))
    .filter(([name, version]) => !name.startsWith('lamdera/')
      && !fs.existsSync(path.join(PKG_DIR, name, version, 'elm.json')));

  let fetched = 0;
  let failed = 0;
  const run = promisify(execFile);
  async function fetchOne([name, version]) {
    const dest = path.join(PKG_DIR, name, version);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.rmSync(dest, { recursive: true, force: true });
    try {
      await run('git', [
        '-c', 'advice.detachedHead=false',
        'clone', '--quiet', '--depth', '1', '--branch', version,
        `https://github.com/${name}.git`, dest,
      ]);
      fs.rmSync(path.join(dest, '.git'), { recursive: true, force: true });
      fetched++;
      console.error(`[elm-prefetch] ${name} ${version}`);
    } catch (e) {
      failed++;
      fs.rmSync(dest, { recursive: true, force: true });
      console.error(`[elm-prefetch] FAILED ${name} ${version}: ${String(e.stderr || e.message).trim()}`);
    }
  }
  // A small worker pool: clones are latency-bound, not CPU-bound.
  await Promise.all(Array.from({ length: 8 }, async () => {
    while (todo.length) await fetchOne(todo.shift());
  }));

  console.error(`[elm-prefetch] done: ${fetched} fetched, ${failed} failed (cache: ${PKG_DIR})`);
  process.exit(failed ? 1 : 0);
}

main();
