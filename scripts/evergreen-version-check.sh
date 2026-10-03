#!/usr/bin/env bash
# Fail when undeployed Evergreen files aren't numbered for the next deploy.
#
# Lamdera bumps the app version on *every* production deploy, type changes or
# not, and `lamdera check` numbers a new migration (production + 1) at the
# moment you run it. So a PR's src/Evergreen/V<n> + Migrate/V<n>.elm go stale
# as soon as anything else deploys. `lamdera check` can't tell: it takes the
# branch's V<n> for deployed history and generates V<n+1> on top of it, and if
# you finish that one it typechecks and deploys, migrating production data
# that never had V<n>'s types.
#
# The rule: every src/Evergreen file that differs between the deployed commit
# and HEAD must belong to version production+1. Deployed versions are history.
# Needs no Lamdera login: https://<app>.lamdera.app/_i reports the deployed
# version, and the Deploy workflow records the deployed commit as the
# `deployed` branch on GitHub.
#
# Usage:
#   scripts/evergreen-version-check.sh [BASE]
#       BASE = the deployed commit. Defaults to origin/deployed, or origin/main
#       if that branch doesn't exist yet. deploy.sh passes lamdera/main.
#   scripts/evergreen-version-check.sh --prod-version | --default-base
# PROD_VERSION=<n> skips the lookup and EVERGREEN_TRUNK=<ref> replaces
# origin/main (tests).
#
# Exit: 0 fine, 1 stale or inconsistent, 2 couldn't tell (offline, no BASE).
set -euo pipefail

trunk=${EVERGREEN_TRUNK:-origin/main}

prod_version() {
    if [ -n "${PROD_VERSION:-}" ]; then
        echo "$PROD_VERSION"
        return
    fi
    local app info
    app=$(node -p 'require("./package.json").config.lamderaApp')
    info=$(curl -fsS --max-time 20 "https://${app}.lamdera.app/_i") || return 1
    sed -nE 's/.*"v":([0-9]+).*/\1/p' <<<"$info" | grep .
}

default_base() {
    if git rev-parse --verify --quiet origin/deployed >/dev/null; then
        echo origin/deployed
    else
        echo "$trunk"
    fi
}

# Version numbers in a list of src/Evergreen paths (V<n>/... or Migrate/V<n>.elm).
versions_in() {
    sed -nE 's#^src/Evergreen/(Migrate/)?V([0-9]+)[/.].*#\2#p' | sort -n | uniq
}

cd "$(git rev-parse --show-toplevel)"

case "${1:-}" in
    --prod-version)
        prod_version || { echo "evergreen: couldn't read the production version" >&2; exit 2; }
        exit 0
        ;;
    --default-base)
        default_base
        exit 0
        ;;
esac

base_ref=${1:-$(default_base)}
if [ "$base_ref" = "$trunk" ] && [ -z "${1:-}" ]; then
    echo "evergreen: no origin/deployed branch yet; comparing against $trunk instead." >&2
fi

prod=$(prod_version) || {
    echo "evergreen: couldn't read the production version from /_i (offline?)" >&2
    exit 2
}
next=$((prod + 1))

base=$(git merge-base "$base_ref" HEAD 2>/dev/null) || {
    echo "evergreen: no merge-base with $base_ref (fetch it first)" >&2
    exit 2
}

changed=$(git diff --no-renames --name-only "$base" HEAD -- src/Evergreen)
ours=$(versions_in <<<"$changed")
stale=$(grep -vx "$next" <<<"$ours" || true)

# The base can be ahead of production: a migration merged but its deploy
# failed or hasn't finished (only possible when BASE isn't the deployed commit).
base_top=$(git ls-tree -r --name-only "$base" -- src/Evergreen | versions_in | tail -1)
if [ -n "$base_top" ] && [ "$base_top" -gt "$prod" ]; then
    {
        echo ""
        echo "evergreen: $base_ref has Evergreen V$base_top, but production is v$prod."
        echo ""
        echo "  A migration on trunk hasn't been deployed (the Deploy workflow failed or"
        echo "  is still running). Get trunk deployed first, then rerun this check."
    } >&2
    exit 1
fi

if [ -z "$stale" ]; then
    if [ -n "$ours" ]; then
        echo "evergreen: undeployed Evergreen files are V$next and production is v$prod. OK."
    fi
    exit 0
fi

# Stale files that are already on trunk came from a merged PR, not this branch.
on_trunk=""
if [ "$base_ref" != "$trunk" ] && git rev-parse --verify --quiet "$trunk" >/dev/null; then
    on_trunk=$(git diff --no-renames --name-only "$base" "$trunk" -- src/Evergreen)
fi

{
    echo ""
    echo "evergreen: STALE MIGRATION. Production is v$prod, so every undeployed"
    echo "Evergreen file must be V$next, but these aren't:"
    echo ""
    for v in $stale; do
        grep -E "^src/Evergreen/(Migrate/)?V$v[/.]" <<<"$changed" | while IFS= read -r f; do
            if grep -qxF "$f" <<<"$on_trunk"; then
                echo "    $f   (already on $trunk)"
            else
                echo "    $f"
            fi
        done
    done
    echo ""
    echo "  Something else deployed after this migration was generated (every deploy"
    echo "  bumps the version, even without type changes). Don't finish a migration"
    echo "  that 'lamdera check' generates on top of these files: it would treat them"
    echo "  as deployed history. Renumber instead, on a branch that has $trunk merged in:"
    echo ""
    echo "    scripts/regen-migration.sh"
    echo ""
    if [ -n "$on_trunk" ] && grep -qE "^src/Evergreen/(Migrate/)?V($(echo $stale | tr ' ' '|'))[/.]" <<<"$on_trunk"; then
        echo "  The stale files are on $trunk itself, so its deploys fail until a PR"
        echo "  renumbers them. Do that on a fresh branch off $trunk and merge it first."
        echo ""
    fi
    echo "  See .claude/skills/lamdera-deploy/SKILL.md (\"Stale migration\")."
} >&2
exit 1
