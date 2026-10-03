#!/usr/bin/env bash
# SessionStart hook for Claude Code cloud sessions (claude.ai/code). No-op
# locally. Gets the container to "lamdera make / npm test / npm run review /
# lamdera check all work":
#
#   1. pinned lamdera binary  → ~/.local/bin (scripts/install-lamdera.sh)
#   2. npm deps               (elm-test-rs, elm-review, real `elm` for review)
#   3. Elm packages           → ~/.elm via git clone (scripts/elm-prefetch.js);
#      the cloud proxy blocks the compiler's github zipball downloads
#   4. Lamdera CLI auth       from the LAMDERA_CLI_AUTH env var (cloud
#      environment secret) → ~/.elm/.lamdera-cli, so `lamdera check` works
#   5. `lamdera` git remote   so lamdera knows the app name (pushing to it
#      still won't work here — SSH is blocked; GitHub Actions deploys)
#   6. repo git hooks         (core.hooksPath)
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
log() { echo "[cloud-setup] $*" >&2; }

bash scripts/install-lamdera.sh
export PATH="$HOME/.local/bin:$PATH"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
fi

log "npm install"
npm install --no-audit --no-fund --loglevel=error

log "prefetching Elm packages"
node scripts/elm-prefetch.js

log "priming lamdera package cache"
lamdera make src/Frontend.elm src/Backend.elm --output=/dev/null >/dev/null

elm_home="${ELM_HOME:-$HOME/.elm}"
if [ -n "${LAMDERA_CLI_AUTH:-}" ]; then
  mkdir -p "$elm_home"
  printf '%s' "$LAMDERA_CLI_AUTH" > "$elm_home/.lamdera-cli"
  chmod 600 "$elm_home/.lamdera-cli"
  log "wrote Lamdera CLI auth to $elm_home/.lamdera-cli"
else
  log "LAMDERA_CLI_AUTH not set — 'lamdera check' will fail with 'No CLI auth' (CI still enforces it)"
fi

app=$(node -p 'require("./package.json").config.lamderaApp')
if ! git remote get-url lamdera >/dev/null 2>&1; then
  git remote add lamdera "git@apps.lamdera.com:${app}.git"
fi

git config core.hooksPath .githooks
log "done"
