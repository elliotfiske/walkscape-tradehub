#!/usr/bin/env bash
# `lamdera check` for scripts and agents: works in a linked worktree, adds
# --force off main, and never blocks on a prompt.
#
# Prompts: when the Evergreen files it checked aren't committed, lamdera asks
# "Shall I run `git add` for you? [Y/n]". Without a TTY that hangs; with stdin
# closed it dies with exit 1 even though the check passed. We close stdin (so
# the offline-mode "continue anyway?" prompt fails rather than passes) and read
# the output to tell the two apart.
#
# Worktrees: lamdera bails ("missing a git repository") when .git is a pointer
# file, as in Conductor workspaces. We briefly symlink .git to this worktree's
# gitdir (git still resolves the lamdera remote via commondir), run the check,
# and restore. Delete the shim if Lamdera ever supports worktrees natively.
#
# Exit: 0 passed, 3 passed but src/Evergreen has uncommitted files (commit
# them), 1 failed (lamdera's report is above).
set -uo pipefail

toplevel=$(git rev-parse --show-toplevel)
gitptr="$toplevel/.git"
cd "$toplevel"

# Self-heal: a hard-killed prior run (SIGKILL, no trap) can leave .git as the
# symlink below. git still works through it, but restore the pointer file.
if [ -L "$gitptr" ]; then
    healed_target=$(readlink "$gitptr")
    rm -f "$gitptr"
    printf 'gitdir: %s\n' "$healed_target" >"$gitptr"
fi

shimmed=0
log=$(mktemp)
cleanup() {
    rm -f "$log"
    if [ "$shimmed" = 1 ] && [ -L "$gitptr" ]; then
        rm -f "$gitptr"
        printf '%s\n' "$gitptr_orig" >"$gitptr"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM
if [ -f "$gitptr" ]; then
    gitptr_orig=$(cat "$gitptr")
    gitdir=$(git rev-parse --absolute-git-dir)
    rm -f "$gitptr"
    ln -s "$gitdir" "$gitptr"
    shimmed=1
fi

# Off main, --force makes check compare against production Evergreen (plain
# check treats a non-main branch as a preview and skips the migration check).
# Plain string, not an array: macOS bash 3.2 + `set -u` errors on empty arrays.
branch=$(git rev-parse --abbrev-ref HEAD)
force_flag=""
if [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
    force_flag="--force"
fi

[ "$shimmed" = 1 ] && note=" (worktree .git shim active)" || note=""
echo "lamdera-check: running 'lamdera check ${force_flag} $*'${note} …" >&2
# shellcheck disable=SC2086  # intentional split: force_flag is our own literal
lamdera check $force_flag "$@" </dev/null 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

if [ "$status" -eq 0 ]; then
    exit 0
fi
if grep -q 'Shall I run .git add' "$log"; then
    {
        echo ""
        echo "lamdera-check: the check PASSED, but these Evergreen files aren't committed:"
        git status --short -- src/Evergreen | sed 's/^/    /'
        echo "  Commit them:  git add src/Evergreen && git commit"
    } >&2
    exit 3
fi
exit 1
