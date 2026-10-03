#!/usr/bin/env bash
#
# One-line production deploy: `npm run deploy`
#
# Deploys exactly what's on origin/main and nothing else. Every failure mode we
# hit manually (main diverging, migrations committed straight to main, running
# from a worktree) is turned into a hard stop *before* anything is pushed, so a
# failed deploy never leaves main in an inconsistent state.
#
# The invariant: local main is only ever a mirror of origin/main. Migrations
# reach main through the normal PR flow (see .claude/skills/lamdera-deploy.md),
# so by deploy time the Evergreen files are already committed and `lamdera
# check` is a no-op.
set -euo pipefail

die() { echo "✗ $*" >&2; exit 1; }
step() { echo "→ $*"; }

# 1. Must be the primary checkout — lamdera can't run in a linked git worktree
#    (.git is a pointer file there, and the compiler bails with "missing a git
#    repository").
toplevel=$(git rev-parse --show-toplevel)
[ -f "$toplevel/.git" ] && die "This is a linked git worktree; lamdera can't run here. Deploy from the primary checkout (the main clone, not a Conductor workspace)."

# 2. Must be on main — any other branch deploys a throwaway preview app.
branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" = "main" ] || die "Deploy must run from 'main' (currently on '$branch'). Other branches create preview apps, not production."

# 3. Working tree must be clean — we only ever deploy committed state.
git diff-index --quiet HEAD -- 2>/dev/null && [ -z "$(git status --porcelain)" ] \
  || die "Working tree is not clean. Commit, stash, or discard changes first.$(printf '\n')$(git status --short)"

# 4. main must mirror origin/main exactly.
step "Fetching origin…"
git fetch --quiet origin
ahead=$(git rev-list --count origin/main..HEAD)
behind=$(git rev-list --count HEAD..origin/main)
if [ "$ahead" -gt 0 ]; then
  die "Local main has $ahead commit(s) not on origin/main — something was committed directly to main.
  Never commit to main. Move those commits to a branch and open a PR (see .claude/skills/lamdera-deploy.md), then deploy.
$(git log --oneline origin/main..HEAD)"
fi
if [ "$behind" -gt 0 ]; then
  step "Fast-forwarding main to origin/main ($behind commit(s))…"
  git merge --ff-only origin/main
fi

# 5. The migration must already be committed. If `lamdera check` generates any
#    Evergreen/snapshot files now, the PR flow was bypassed — abort rather than
#    deploy (and commit) uncommitted, unreviewed migration code onto main.
step "Running lamdera check (expecting no changes)…"
before=$(git status --porcelain)
lamdera check
after=$(git status --porcelain)
if [ "$before" != "$after" ]; then
  echo "$(git status --short)" >&2
  die "lamdera check generated uncommitted files: types changed vs production but no migration is committed on main.
  Take it through a PR: on a branch run 'lamdera check --force', finish src/Evergreen/Migrate/V<N>.elm, commit src/Evergreen, PR → merge, then deploy.
  See .claude/skills/lamdera-deploy.md"
fi

# 6. Ship it. (lamdera deploy === lamdera check && git push lamdera main)
step "Deploying to production…"
lamdera deploy
step "Done. main, origin/main, and lamdera/main are all at $(git rev-parse --short HEAD)."
