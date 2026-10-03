// Shared helper: figure out which `lamdera live` port belongs to *this*
// worktree, so the cdp-*.js scripts can default `--port` automatically.
//
// In a multi-worktree setup each worktree runs its own `lamdera live` on its
// own port, all sharing the one debug Chrome on :9222. Without a port hint the
// scripts would attach to whichever localhost tab comes first — possibly
// another worktree's. This matches `lamdera live` processes to the current
// worktree by working directory and returns that process's port.
//
// Detection is best-effort: on any ambiguity or error it returns null and the
// caller falls back to its previous behavior (first matching localhost tab).
// An explicit `--port` always wins — callers only consult this when none given.

const { execSync } = require('child_process');
const path = require('path');

// The worktree root is the parent of the scripts/ dir this module lives in.
const WORKTREE_ROOT = path.resolve(__dirname, '..');

const DEFAULT_LAMDERA_PORT = '8000'; // `lamdera live` with no --port

// Return the cwd of a pid via lsof, or null. macOS has no `ps`-based cwd.
function pidCwd(pid) {
  try {
    const out = execSync(`lsof -a -p ${pid} -d cwd -Fn`, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    const line = out.split('\n').find((l) => l.startsWith('n'));
    return line ? path.resolve(line.slice(1)) : null;
  } catch {
    return null;
  }
}

// Find the lamdera-live port serving this worktree. Returns a string port or
// null. Logs a short hint to stderr on ambiguity unless { quiet: true }.
function detectWorktreePort({ quiet = false } = {}) {
  const log = (m) => { if (!quiet) console.error(m); };
  let procs;
  try {
    const out = execSync('pgrep -fl "lamdera live"', { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    procs = out.split('\n')
      .map((line) => {
        const pidMatch = line.match(/^(\d+)\s/);
        if (!pidMatch) return null;
        const portMatch = line.match(/--port[=\s]+(\d+)/);
        return { pid: pidMatch[1], port: portMatch ? portMatch[1] : DEFAULT_LAMDERA_PORT };
      })
      .filter(Boolean);
  } catch {
    return null; // pgrep found nothing (exit 1) or isn't available
  }
  if (!procs.length) return null;

  const matches = [...new Set(
    procs.filter((p) => pidCwd(p.pid) === WORKTREE_ROOT).map((p) => p.port)
  )];

  if (matches.length === 1) {
    log(`[cdp] auto-detected this worktree's lamdera port: ${matches[0]}`);
    return matches[0];
  }
  if (matches.length > 1) {
    log(`[cdp] multiple lamdera ports for this worktree (${matches.join(', ')}); pass --port to choose`);
  } else if (procs.length > 1) {
    log(`[cdp] couldn't match a lamdera live process to this worktree; pass --port (running: ${procs.map((p) => p.port).join(', ')})`);
  }
  return null;
}

module.exports = { detectWorktreePort, WORKTREE_ROOT };
