#!/usr/bin/env bash
# Install the pinned Lamdera compiler to ~/.local/bin (or $LAMDERA_BIN_DIR).
# Single source of truth for the version + checksum — used by CI
# (.github/actions/lamdera-setup) and the cloud SessionStart hook
# (.claude/hooks/cloud-setup.sh).
#
# Pinned to the exact Lamdera version that locked this repo's elm.json. The
# rolling /bin/linux/lamdera ("latest") can drift to a version with different
# vendored package versions, which fails compiles with "INCOMPATIBLE
# DEPENDENCIES". Bump this in lockstep with local upgrades.
#
# Lamdera ships no published checksum/signature, so this is a
# trust-on-first-use pin: LAMDERA_SHA256 was captured from the binary over
# HTTPS and verified across independent fetches. We abort before chmod/exec if
# the download doesn't match, defeating a poisoned DNS, MITM, or
# compromised-CDN swap. Update BOTH version and hash in lockstep on upgrade:
# curl the new URL and run `sha256sum` to get the new value.
#
# Idempotent: skips the download when the installed binary already matches.
set -euo pipefail

LAMDERA_VERSION="1.4.0"
LAMDERA_SHA256="6287d0853237a806be73d43212a2ed839bd697f2b1b9466a8d135eae438575c4"

bin_dir="${LAMDERA_BIN_DIR:-$HOME/.local/bin}"
target="$bin_dir/lamdera"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) platform="linux-x86_64" ;;
  *) echo "install-lamdera: unsupported platform $(uname -s)-$(uname -m); install lamdera manually" >&2; exit 1 ;;
esac

if [ -x "$target" ] && echo "${LAMDERA_SHA256}  $target" | sha256sum -c --status - 2>/dev/null; then
  echo "install-lamdera: lamdera ${LAMDERA_VERSION} already installed at $target" >&2
  exit 0
fi

mkdir -p "$bin_dir"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsSL --retry 3 "https://static.lamdera.com/bin/lamdera-${LAMDERA_VERSION}-${platform}" -o "$tmp"
echo "${LAMDERA_SHA256}  $tmp" | sha256sum -c -
chmod a+x "$tmp"
mv "$tmp" "$target"
trap - EXIT
echo "install-lamdera: installed lamdera ${LAMDERA_VERSION} to $target" >&2
