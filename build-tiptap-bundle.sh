#!/bin/bash
set -e

# Wave 7.17 — build the Tiptap WKWebView JS bundle and stage it under
# Epistemos/Resources/Editor/ where EpdocEditorURLSchemeHandler reads
# it (Epistemos/Engine/EpdocEditorBridge.swift).
#
# Canonical 2026 macOS pattern (per the W7.17 setup-research agent):
# bundle at BUILD time, ship the static dist/ inside the .app. The
# user NEVER runs npm. Runtime install is structurally impossible
# under MAS sandbox + hostile to UX even on Pro / Developer ID.
#
# This script ships in the project.yml preBuildScripts chain. It:
#   1. Verifies npm is available; loud-fails with install hints if not
#   2. Installs deps via `npm ci` ONLY when package-lock.json hash
#      changes (lock-hash stamp under node_modules/.installed-<hash>)
#   3. Runs webpack in --mode production by default so Xcode sees a stable
#      resource graph across Pro/AppStore schemes. Set
#      EPISTEMOS_TIPTAP_DEVELOPMENT=1 only when intentionally debugging
#      the WKWebView bundle from an Xcode build.
#   4. rsyncs dist/ → ../Epistemos/Resources/Editor/
#   5. Sanity-checks editor.html landed at the destination so we never
#      ship a broken .app
#
# CI: set CI=1 + the script will exit non-zero if the bundle output is
# missing.

# -------------------------------------------------------------------
# 0. npm availability
# -------------------------------------------------------------------

# Xcode launched from Finder keeps a minimal PATH; include common Node
# install locations before checking for npm.
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

if ! command -v npm &> /dev/null; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  build-tiptap-bundle.sh: npm not found on PATH."
    echo ""
    echo "  Install Node ≥ 20.10:"
    echo "    brew install node@20"
    echo "    brew link node@20"
    echo "  OR with nvm:"
    echo "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
    echo "    nvm install 20 && nvm use 20"
    echo ""
    echo "  After install, re-run this script (or rebuild Epistemos in Xcode)."
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    exit 1
fi

cd "$(dirname "$0")/js-editor"

# -------------------------------------------------------------------
# 1. npm install — gated on package-lock.json HASH change
#
# Replaces the W7.17 mtime-based stamp with a content-hash stamp so
# the install only fires when the resolved dep tree actually changes.
# Saves ~20s on every Xcode build that doesn't update deps.
# -------------------------------------------------------------------

if [ ! -f package-lock.json ]; then
    echo "build-tiptap-bundle.sh: package-lock.json missing — running first-time install"
    npm install --no-audit --no-fund
fi

LOCK_HASH=$(shasum -a 256 package-lock.json | cut -d' ' -f1)
STAMP_FILE="node_modules/.installed-${LOCK_HASH}"

if [ ! -f "$STAMP_FILE" ]; then
    # Lock changed (or first install) — clear old stamps + run npm ci
    rm -f node_modules/.installed-* 2>/dev/null || true
    if [ -d node_modules ]; then
        npm ci --no-audit --no-fund --prefer-offline
    else
        npm ci --no-audit --no-fund
    fi
    mkdir -p node_modules
    touch "$STAMP_FILE"
fi

# -------------------------------------------------------------------
# 2. webpack - production by default for stable Xcode resources
# -------------------------------------------------------------------

if [ "${EPISTEMOS_TIPTAP_DEVELOPMENT:-}" = "1" ]; then
    npm run build -- --mode development
else
    npm run build -- --mode production
fi

# -------------------------------------------------------------------
# 3. Stage to Epistemos/Resources/Editor/
# -------------------------------------------------------------------

DEST="../Epistemos/Resources/Editor"
mkdir -p "$DEST"
rsync -a --delete dist/ "$DEST/"

prune_production_editor_bundle() {
    if [ "${EPISTEMOS_TIPTAP_DEVELOPMENT:-}" = "1" ]; then
        return 0
    fi

    # The custom WKURLSchemeHandler serves *.br files for JS/CSS with
    # Content-Encoding: br, so the uncompressed transfer source is only a
    # development fallback. Keep production app bundles small by removing
    # the plain counterpart whenever a Brotli asset exists.
    find "$DEST" -type f -name '*.br' -print0 | while IFS= read -r -d '' compressed; do
        plain="${compressed%.br}"
        if [ -f "$plain" ]; then
            rm -f "$plain"
        fi
    done

    # WKWebView on the supported macOS target loads KaTeX WOFF2 fonts.
    # Shipping TTF and WOFF alongside WOFF2 triples the font footprint with
    # no V1 benefit.
    if [ -d "$DEST/vendor/katex/fonts" ]; then
        find "$DEST/vendor/katex/fonts" -type f \( -name '*.ttf' -o -name '*.woff' \) -delete
    fi
}

prune_production_editor_bundle

# -------------------------------------------------------------------
# 4. Sanity check — never ship a broken .app
# -------------------------------------------------------------------

if [ ! -f "$DEST/editor.html" ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  build-tiptap-bundle.sh: webpack output missing!"
    echo "  Expected $DEST/editor.html"
    echo ""
    echo "  Check js-editor/dist/ for build artifacts; re-run with"
    echo "    cd js-editor && npm run build"
    echo "  to inspect the webpack output directly."
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    exit 2
fi

if [ "${CI:-}" = "1" ]; then
    echo "build-tiptap-bundle.sh: CI mode — bundle staged successfully ($(du -sh "$DEST" | cut -f1))"
fi
