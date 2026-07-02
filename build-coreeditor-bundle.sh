#!/bin/bash
set -euo pipefail

# Plan 2 Stage 5 - build MarkEdit's CoreEditor bundle and stage it as an
# Epistemos static resource. Runtime npm/yarn is forbidden; this script runs at
# build time from the pinned vendored MarkEdit lockfile.

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_EDITOR_DIR="${ROOT_DIR}/LocalPackages/MarkEdit/CoreEditor"
DEST="${ROOT_DIR}/Epistemos/Resources/CoreEditor"

NODE_PATH_PREFIXES=(
    "$HOME/.volta/bin"
    "/opt/homebrew/opt/node@20/bin"
    "/opt/homebrew/bin"
    "/usr/local/opt/node@20/bin"
    "/usr/local/bin"
)

for NODE_PATH_PREFIX in "${NODE_PATH_PREFIXES[@]}"; do
    if [ -d "$NODE_PATH_PREFIX" ]; then
        PATH="$NODE_PATH_PREFIX:$PATH"
    fi
done
export PATH

if [ -s "$HOME/.nvm/nvm.sh" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.nvm/nvm.sh"
    nvm use --silent 20 >/dev/null 2>&1 || nvm use --silent --lts >/dev/null 2>&1 || true
fi

if ! command -v node >/dev/null 2>&1; then
    echo ""
    echo "build-coreeditor-bundle.sh: node not found on PATH."
    echo "Install Node >= 20, then rerun the build."
    echo ""
    exit 1
fi

if [ ! -d "$CORE_EDITOR_DIR" ]; then
    echo "build-coreeditor-bundle.sh: missing vendored CoreEditor at $CORE_EDITOR_DIR"
    echo "Run scripts/vendor_markedit.sh first."
    exit 2
fi

cd "$CORE_EDITOR_DIR"

if [ ! -f yarn.lock ]; then
    echo "build-coreeditor-bundle.sh: yarn.lock missing in $CORE_EDITOR_DIR"
    exit 3
fi

YARN_CLI=".yarn/releases/yarn-4.15.0.cjs"
if [ ! -f "$YARN_CLI" ]; then
    echo "build-coreeditor-bundle.sh: missing pinned Yarn CLI at $CORE_EDITOR_DIR/$YARN_CLI"
    exit 4
fi

LOCK_HASH="$(
    {
        shasum -a 256 package.json
        shasum -a 256 yarn.lock
        shasum -a 256 .yarnrc.yml
        shasum -a 256 "$YARN_CLI"
    } | shasum -a 256 | cut -d' ' -f1
)"
STAMP_FILE="node_modules/.epistemos-installed-${LOCK_HASH}"

if [ ! -f "$STAMP_FILE" ]; then
    rm -f node_modules/.epistemos-installed-* 2>/dev/null || true
    node "$YARN_CLI" install --immutable
    mkdir -p node_modules
    touch "$STAMP_FILE"
fi

node "$YARN_CLI" build

if [ ! -f dist/index.html ]; then
    echo "build-coreeditor-bundle.sh: CoreEditor build output missing dist/index.html"
    exit 5
fi

if [ ! -d dist/chunks ]; then
    echo "build-coreeditor-bundle.sh: CoreEditor build output missing dist/chunks"
    exit 6
fi

mkdir -p "$DEST"
rsync -a --delete dist/ "$DEST/"

if [ ! -f "$DEST/index.html" ]; then
    echo "build-coreeditor-bundle.sh: staged bundle missing $DEST/index.html"
    exit 7
fi

if [ ! -d "$DEST/chunks" ]; then
    echo "build-coreeditor-bundle.sh: staged bundle missing $DEST/chunks"
    exit 8
fi

if [ "${CI:-}" = "1" ]; then
    echo "build-coreeditor-bundle.sh: CI mode - bundle staged successfully ($(du -sh "$DEST" | cut -f1))"
fi
