#!/usr/bin/env zsh
# update-osaurus.sh — re-vendor the LATEST osaurus-ai/osaurus (owner sourcing policy
# 2026-06-18: always clone latest upstream, take control, keep updates one command).
#
# Usage:  zsh scripts/update-osaurus.sh
# After running: update LocalPackages/osaurus/VENDOR.md PINNED commit, re-run xcodegen
# if the file set changed, then build-verify both MAS + Pro profiles.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$REPO_ROOT/LocalPackages/osaurus"
UPSTREAM="https://github.com/osaurus-ai/osaurus"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Cloning latest $UPSTREAM ..."
git clone --depth 1 "$UPSTREAM" "$TMP/osaurus"
SHA="$(git -C "$TMP/osaurus" rev-parse HEAD)"
rm -rf "$TMP/osaurus/.git"   # take control — vendor as our own source

rm -rf "$DEST"
mv "$TMP/osaurus" "$DEST"

echo "Vendored osaurus @ $SHA  ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
echo "NEXT: bump VENDOR.md PINNED commit to $SHA, re-run xcodegen, build-verify."
