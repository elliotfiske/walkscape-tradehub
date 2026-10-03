#!/usr/bin/env bash
# Commit a directory of PNGs to the orphan `ci/screenshots` branch under
# <prefix>/ and print the commit sha. Uses git plumbing with a throwaway index
# so the working tree and current branch are untouched. Retries on
# non-fast-forward (parallel PR runs).
#
# Usage: scripts/ci-publish-screenshots.sh <dir> <prefix>   e.g. shots pr-12/abc1234
set -euo pipefail

src=$1
prefix=$2
branch=ci/screenshots

for attempt in 1 2 3 4; do
  parent=""
  if git fetch --quiet --depth 1 origin "$branch" 2>/dev/null; then
    parent=$(git rev-parse FETCH_HEAD)
  fi

  export GIT_INDEX_FILE
  GIT_INDEX_FILE=$(mktemp)
  rm -f "$GIT_INDEX_FILE"
  if [ -n "$parent" ]; then git read-tree "$parent"; else git read-tree --empty; fi
  for f in "$src"/*.png; do
    blob=$(git hash-object -w "$f")
    git update-index --add --cacheinfo "100644,$blob,$prefix/$(basename "$f")"
  done
  tree=$(git write-tree)
  rm -f "$GIT_INDEX_FILE"
  unset GIT_INDEX_FILE

  msg="screenshots: $prefix"
  if [ -n "$parent" ]; then
    commit=$(git -c user.name=github-actions -c user.email=github-actions@users.noreply.github.com commit-tree "$tree" -p "$parent" -m "$msg")
  else
    commit=$(git -c user.name=github-actions -c user.email=github-actions@users.noreply.github.com commit-tree "$tree" -m "$msg")
  fi

  if git push --quiet --no-verify origin "$commit:refs/heads/$branch"; then
    echo "$commit"
    exit 0
  fi
  echo "ci-publish-screenshots: push rejected (attempt $attempt), retrying" >&2
  sleep $((attempt * 2))
done
echo "ci-publish-screenshots: giving up" >&2
exit 1
