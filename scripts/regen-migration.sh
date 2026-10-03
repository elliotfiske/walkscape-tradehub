#!/usr/bin/env bash
# Renumber this branch's Evergreen migration after production moved past it.
#
# Run it when scripts/evergreen-version-check.sh reports a STALE MIGRATION:
# the branch added src/Evergreen/V<old> + Migrate/V<old>.elm, then something
# else deployed and V<old> now names a production version with other types.
#
#   1. Finds the one stale version among the undeployed Evergreen files (vs.
#      the deployed commit, see evergreen-version-check.sh).
#   2. If trunk has no new migration since then, the migration is still valid
#      and only its number is wrong: git mv V<old> -> V<next>, and rewrite
#      Evergreen.V<old> -> Evergreen.V<next> inside the moved files. Hand edits
#      carry over untouched.
#      If trunk did gain a migration, the old one migrates from the wrong
#      version. It's removed so lamdera regenerates from trunk's latest, and a
#      copy is kept so you can re-apply your hand edits.
#   3. Runs lamdera check to confirm.
#
# Nothing is committed. Review `git status src/Evergreen`, then commit.
#
# Usage: scripts/regen-migration.sh [--no-check]
#   --no-check  skip step 3 (tests; or when you'll run lamdera check yourself)
# EVERGREEN_BASE=<ref> (deployed commit), EVERGREEN_TRUNK=<ref> (origin/main)
# and PROD_VERSION=<n> override the defaults (tests).
set -euo pipefail

die() { echo "regen-migration: $*" >&2; exit 1; }
say() { echo "regen-migration: $*"; }

run_check=1
[ "${1:-}" = "--no-check" ] && run_check=0

cd "$(git rev-parse --show-toplevel)"
here=$(pwd)
trunk=${EVERGREEN_TRUNK:-origin/main}

if [ "$trunk" = "origin/main" ]; then
    git fetch --quiet origin main
    git fetch --quiet origin deployed 2>/dev/null || true
fi
git merge-base --is-ancestor "$trunk" HEAD \
    || die "branch is behind $trunk. Merge it first (git merge $trunk), then rerun."
base_ref=${EVERGREEN_BASE:-$(EVERGREEN_TRUNK=$trunk "$here/scripts/evergreen-version-check.sh" --default-base)}

prod=$("$here/scripts/evergreen-version-check.sh" --prod-version)
next=$((prod + 1))
base=$(git merge-base "$base_ref" HEAD)
stamp=$(date +%Y%m%d-%H%M%S)
backup="$(git rev-parse --git-path evergreen-regen)/$stamp"

versions_in() {
    sed -nE 's#^src/Evergreen/(Migrate/)?V([0-9]+)[/.].*#\2#p' | sort -n | uniq
}

# Untracked files under src/Evergreen are usually what `lamdera check` just
# generated on top of the stale version. Move them aside; refuse to touch
# uncommitted edits to tracked files.
if [ -n "$(git status --porcelain -- src/Evergreen | grep -v '^??' || true)" ]; then
    git status --short -- src/Evergreen >&2
    die "commit or discard your changes under src/Evergreen first."
fi
untracked=$(git ls-files --others --exclude-standard -- src/Evergreen)
if [ -n "$untracked" ]; then
    mkdir -p "$backup/untracked"
    while IFS= read -r f; do
        mkdir -p "$backup/untracked/$(dirname "$f")"
        mv "$f" "$backup/untracked/$f"
    done <<<"$untracked"
    say "moved untracked src/Evergreen files (generated against the stale version) to $backup/untracked"
fi

ours=$(git diff --no-renames --name-only "$base" HEAD -- src/Evergreen | versions_in)
stale=$(grep -vx "$next" <<<"$ours" || true)
if [ -z "$stale" ]; then
    say "nothing stale: production is v$prod and the undeployed Evergreen files are ${ours:+V}${ours:-none}."
    exit 0
fi
[ "$(wc -l <<<"$stale")" -eq 1 ] \
    || die "several stale versions are undeployed ($(echo $stale)). Sort that out by hand."
old=$stale

# A V<next> committed alongside V<old> was generated on top of the stale
# snapshot (the trap evergreen-version-check.sh warns about). Drop it.
if grep -qx "$next" <<<"$ours"; then
    mkdir -p "$backup"
    git show "HEAD:src/Evergreen/Migrate/V$next.elm" >"$backup/V$next.elm" 2>/dev/null || true
    git rm -r --quiet --ignore-unmatch "src/Evergreen/V$next" "src/Evergreen/Migrate/V$next.elm"
    say "removed V$next, which was generated on top of stale V$old (copy of its migration in $backup)"
fi

old_mig="src/Evergreen/Migrate/V$old.elm"
[ -f "$old_mig" ] || die "$old_mig doesn't exist; can't tell what it migrated from."

# Which version the old migration migrates from, and which one lamdera would
# migrate from now (the newest migration left once ours is gone, or 1).
old_from=$(sed -nE "s/^import Evergreen\.V([0-9]+)\..*/\1/p" "$old_mig" | grep -vx "$old" | sort -n | uniq | tail -1)
new_from=$(git ls-tree --name-only HEAD src/Evergreen/Migrate/ | versions_in | grep -vx -e "$old" -e "$next" | tail -1 || true)
new_from=${new_from:-1}

if [ "$old_from" = "$new_from" ]; then
    git mv "src/Evergreen/V$old" "src/Evergreen/V$next"
    git mv "$old_mig" "src/Evergreen/Migrate/V$next.elm"
    find "src/Evergreen/V$next" "src/Evergreen/Migrate/V$next.elm" -name '*.elm' -print0 \
        | xargs -0 perl -pi -e "s/\bEvergreen\.(Migrate\.)?V$old\b/Evergreen.\${1}V$next/g"
    git add "src/Evergreen/V$next" "src/Evergreen/Migrate/V$next.elm"
    say "renumbered V$old -> V$next (still migrates from V$new_from; hand edits kept)."
    handedits=""
else
    mkdir -p "$backup"
    cp "$old_mig" "$backup/V$old.elm"
    git rm -r --quiet "src/Evergreen/V$old" "$old_mig"
    say "trunk gained a migration (V$new_from) since V$old was generated from V$old_from."
    say "removed V$old; lamdera will generate V$new_from -> V$next."
    handedits="$backup/V$old.elm"
fi

if [ "$run_check" = 0 ]; then
    say "skipped lamdera check (--no-check)."
else
    status=0
    "$here/scripts/lamdera-check.sh" || status=$?
    # 3 = passed, files not committed yet: expected here.
    if [ "$status" != 0 ] && [ "$status" != 3 ]; then
        echo "" >&2
        if [ -f "src/Evergreen/Migrate/V$next.elm" ] && grep -q Unimplemented "src/Evergreen/Migrate/V$next.elm"; then
            echo "regen-migration: finish src/Evergreen/Migrate/V$next.elm (replace Unimplemented)." >&2
        fi
        if [ -n "$handedits" ]; then
            echo "regen-migration: your old hand edits are in $handedits." >&2
            echo "  Port them across, renaming Evergreen.V$old -> Evergreen.V$next and" >&2
            echo "  checking them against the V$new_from types they now migrate from." >&2
        fi
        echo "  Then run scripts/lamdera-check.sh until it passes, and commit src/Evergreen." >&2
        exit 1
    fi
fi

echo ""
git status --short -- src/Evergreen
echo ""
say "done. Production is v$prod; this branch now migrates V$new_from -> V$next."
say "review, then:  git add -A src/Evergreen && git commit -m 'Renumber Evergreen migration to V$next'"
