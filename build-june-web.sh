#!/bin/bash
# Stages the vendored June web bundle for the MAS agent surface (Plan 1-MAS §1).
#
# Builds the pinned June fork (production Vite, relative base) and stages it
# into Epistemos/Resources/JuneWeb/ — which Xcode copies into the app bundle
# with directory structure preserved (Contents/Resources/JuneWeb/...), where
# JuneWebAssets.resolve() finds it. Run manually after fork web changes; the
# staged tree is self-gitignored (never committed into the Epistemos repo).
#
# Gates:
# - refuses a dist containing a service worker (perf doctrine §2.7)
# - excludes June's commercial fonts (Plan 1-MAS R6) — Berkeley Mono,
#   ABC Diatype, Martina Plantijn are licensed to June upstream, not Epistemos.
#   The scheme handler additionally 404s them (belt + braces).
set -euo pipefail

FORK="${EPISTEMOS_JUNE_FORK:-$HOME/dev/june-epistemos}"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
STAGE="$REPO_ROOT/Epistemos/Resources/JuneWeb"

UNLICENSED_FONTS=(
  "BerkeleyMono-Regular.woff2" "BerkeleyMono-Oblique.woff2"
  "ABCDiatype-Regular.woff2" "ABCDiatype-Medium.woff2"
  "martina-plantijn-light.woff2"
)

[ -f "$FORK/package.json" ] || { echo "ERROR: June fork not found at $FORK (set EPISTEMOS_JUNE_FORK)"; exit 1; }
[ -f "$FORK/epistemos/tauri-internals-shim.js" ] || { echo "ERROR: overlay shim missing in fork"; exit 1; }
command -v bun >/dev/null || { echo "ERROR: bun is required"; exit 1; }

echo "== June fork: $FORK @ $(git -C "$FORK" rev-parse --short HEAD) ($(git -C "$FORK" log -1 --format=%cs))"
if ! git -C "$FORK" diff --quiet; then
  echo "WARNING: fork working tree is dirty — staging uncommitted state"
fi

echo "== Building (bun install + tsc + vite build --base=./)"
(cd "$FORK" && bun install --silent && bunx tsc && bunx vite build --base=./ >/dev/null)

if find "$FORK/dist" -name "sw.js" -o -name "service-worker*" | grep -q .; then
  echo "ERROR: dist contains a service worker — refusing to stage"
  exit 1
fi

echo "== Staging -> $STAGE"
rm -rf "$STAGE"
mkdir -p "$STAGE"
EXCLUDES=()
for font in "${UNLICENSED_FONTS[@]}"; do EXCLUDES+=(--exclude "$font"); done
rsync -a "${EXCLUDES[@]}" "$FORK/dist/" "$STAGE/dist/"
cp "$FORK/epistemos/tauri-internals-shim.js" "$STAGE/tauri-internals-shim.js"
# Self-ignoring: the staged tree never enters the Epistemos git history.
printf '*\n' > "$STAGE/.gitignore"

for font in "${UNLICENSED_FONTS[@]}"; do
  if [ -e "$STAGE/dist/$font" ]; then
    echo "ERROR: unlicensed font leaked into stage: $font"
    exit 1
  fi
done

FILES=$(find "$STAGE/dist" -type f | wc -l | tr -d ' ')
MAIN_GZ=$(gzip -c "$STAGE"/dist/assets/main-*.js 2>/dev/null | wc -c | tr -d ' ')
echo "== Staged $FILES files; main chunk $((MAIN_GZ / 1024)) KB gz"
echo "== Done. Rebuild the AppStore scheme to bundle."
