#!/usr/bin/env bash
# Tests for evergreen-version-check.sh and regen-migration.sh, in a throwaway
# git repo with a fake production version (PROD_VERSION). No Lamdera needed.
#
#   bash scripts/test-evergreen.sh
set -euo pipefail

src=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/repo"
cd "$tmp/repo"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; }

# expect <exit code> <description> <command...>
expect() {
    local want=$1 what=$2
    shift 2
    local got=0
    "$@" >"$tmp/out" 2>&1 || got=$?
    if [ "$got" = "$want" ]; then ok "$what"; else bad "$what (exit $got, wanted $want)"; sed 's/^/       /' "$tmp/out"; fi
}

check() { EVERGREEN_TRUNK=main PROD_VERSION=$1 scripts/evergreen-version-check.sh "${2:-main}"; }
regen() { EVERGREEN_TRUNK=main EVERGREEN_BASE=${2:-main} PROD_VERSION=$1 scripts/regen-migration.sh --no-check; }

# snapshot <version>: a fake src/Evergreen/V<n> snapshot.
snapshot() {
    mkdir -p "src/Evergreen/V$1"
    printf 'module Evergreen.V%s.Types exposing (..)\n\ntype Msg = %s\n' "$1" "${2:-A}" >"src/Evergreen/V$1/Types.elm"
}
# migration <to> <from>: a fake Migrate/V<to>.elm with a hand edit.
migration() {
    mkdir -p src/Evergreen/Migrate
    cat >"src/Evergreen/Migrate/V$1.elm" <<EOF
module Evergreen.Migrate.V$1 exposing (..)

import Evergreen.V$2.Types
import Evergreen.V$1.Types

frontendMsg old =
    case old of
        Evergreen.V$2.Types.Removed -> MsgOldValueIgnored -- HAND EDIT
EOF
}

git init --quiet -b main
git config user.email t@example.com
git config user.name test
mkdir scripts
cp "$src/evergreen-version-check.sh" "$src/regen-migration.sh" scripts/
snapshot 1
git add -A && git commit --quiet -m "v1 deployed"
git branch deployed # stands in for lamdera/main

echo "version check"
git checkout --quiet -b feature
snapshot 2 B && migration 2 1
git add -A && git commit --quiet -m "feature: migration V2"
expect 0 "fresh migration (prod v1, branch V2) passes" check 1
expect 1 "type-neutral deploy (prod v2) makes V2 stale" check 2
grep -q "STALE MIGRATION" "$tmp/out" && ok "  ...and says STALE MIGRATION" || bad "  ...missing STALE message"
expect 2 "can't tell without a base" check 2 nonexistent-ref

git checkout --quiet -b lying
snapshot 3 B && migration 3 2
git add -A && git commit --quiet -m "finish the V3 lamdera generated on top of stale V2"
expect 1 "stale V2 + V3 built on it still fails" check 2

git checkout --quiet main
git checkout --quiet -b neutral
echo x >README && git add -A && git commit --quiet -m "no Evergreen change"
expect 0 "branch without Evergreen changes passes at any version" check 7

git checkout --quiet main
git checkout --quiet -b rename-deployed
git mv src/Evergreen/V1 src/Evergreen/V2 && git commit --quiet -m "rename deployed V1 away"
expect 1 "renaming a deployed version away fails" check 1

git checkout --quiet main
git checkout --quiet -b trunk-ahead
snapshot 2 B && migration 2 1
git add -A && git commit --quiet -m "merged, not yet deployed"
git checkout --quiet -b on-top
expect 1 "trunk has an undeployed migration" check 1 trunk-ahead
grep -q "hasn't been deployed" "$tmp/out" && ok "  ...and says so" || bad "  ...missing undeployed message"

echo "deploy gate (BASE = deployed commit)"
git checkout --quiet main
git merge --quiet --no-ff feature -m "merge stale feature"
expect 1 "main with stale V2 vs deployed v2 fails" check 2 deployed
expect 0 "same main before the neutral deploy (prod v1) passes" check 1 deployed

echo "stale migration already merged (trunk can't deploy)"
git checkout --quiet -b unrelated-pr
echo y >OTHER && git add -A && git commit --quiet -m "type-neutral PR on broken trunk"
expect 1 "unrelated PR on a broken trunk fails" check 2 deployed
grep -q "(already on main)" "$tmp/out" && grep -q "renumbers them" "$tmp/out" \
    && ok "  ...and blames trunk, not the PR" || bad "  ...doesn't say it's trunk's"
git checkout --quiet -b fix-trunk main
expect 0 "regen on a branch off trunk renumbers V2 to V3" regen 2 deployed
git commit --quiet -m "renumber"
expect 0 "the fix PR passes against the deployed commit" check 2 deployed
git checkout --quiet main && git reset --quiet --hard deployed

echo "regen-migration"
git checkout --quiet main && git reset --quiet --hard deployed

git checkout --quiet -B r1 feature
expect 0 "renumbers stale V2 to V3" regen 2
[ ! -e src/Evergreen/V2 ] && [ ! -e src/Evergreen/Migrate/V2.elm ] && ok "  V2 gone" || bad "  V2 still there"
grep -q "^module Evergreen.V3.Types" src/Evergreen/V3/Types.elm && ok "  snapshot module renamed" || bad "  snapshot module not renamed"
grep -q "^module Evergreen.Migrate.V3" src/Evergreen/Migrate/V3.elm \
    && grep -q "^import Evergreen.V1.Types" src/Evergreen/Migrate/V3.elm \
    && grep -q "^import Evergreen.V3.Types" src/Evergreen/Migrate/V3.elm \
    && ok "  migration renumbered, still from V1" || bad "  migration not renumbered"
grep -q "HAND EDIT" src/Evergreen/Migrate/V3.elm && ok "  hand edit kept" || bad "  hand edit lost"
git commit --quiet -m renumber
expect 0 "version check passes afterwards" check 2

git checkout --quiet -B r2 lying
expect 0 "drops the V3 built on stale V2, then renumbers V2" regen 2
grep -q "HAND EDIT" src/Evergreen/Migrate/V3.elm && grep -q "^import Evergreen.V1.Types" src/Evergreen/Migrate/V3.elm \
    && ok "  V3 is the real migration (from V1)" || bad "  V3 is the wrong one"
git reset --quiet --hard

git checkout --quiet -B r3 feature
snapshot 3 B && migration 3 2 # untracked: what `lamdera check` generates after the merge
expect 0 "moves untracked V3 aside first" regen 2
grep -q "HAND EDIT" src/Evergreen/Migrate/V3.elm && grep -q "^import Evergreen.V1.Types" src/Evergreen/Migrate/V3.elm \
    && ok "  V3 is the renumbered V2" || bad "  V3 is wrong"
git reset --quiet --hard

git checkout --quiet main
git checkout --quiet -b trunk-migrated
snapshot 3 C && migration 3 1
git add -A && git commit --quiet -m "another PR's migration, deployed as v3"
git checkout --quiet -B r4 feature
git merge --quiet --no-edit trunk-migrated
expect 0 "trunk gained a migration: removes V2 and keeps a copy" env EVERGREEN_TRUNK=trunk-migrated EVERGREEN_BASE=trunk-migrated PROD_VERSION=3 scripts/regen-migration.sh --no-check
[ ! -e src/Evergreen/V2 ] && ok "  V2 removed" || bad "  V2 still there"
ls "$(git rev-parse --git-path evergreen-regen)"/*/V2.elm >/dev/null 2>&1 && ok "  old migration backed up" || bad "  no backup"

git checkout --quiet -f -B r5 feature
echo "-- edit" >>src/Evergreen/Migrate/V2.elm
expect 1 "refuses with uncommitted Evergreen edits" regen 2
git checkout --quiet -- .

git checkout --quiet -B r6 deployed
expect 0 "nothing stale is a no-op" regen 2

echo ""
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
