#!/bin/bash
set -e

# Wave 7.17 — build the Tiptap WKWebView JS bundle and stage it under
# Epistemos/Resources/Editor/ where EpdocEditorURLSchemeHandler reads
# it (Epistemos/Engine/EpdocEditorBridge.swift).
#
# Mirrors the cadence of the other 8 build-*.sh scripts so it slots
# cleanly into project.yml's preBuildScripts chain.
#
# First run requires Node ≥ 20.10 + npm. CI environments without
# Node will fail HARD here — that's intentional; the JS bundle is
# the editor.

if ! command -v npm &> /dev/null; then
    echo "build-tiptap-bundle.sh: npm not found on PATH."
    echo "  Install Node 20.10+ via:"
    echo "    brew install node@20"
    echo "    OR"
    echo "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
    exit 1
fi

cd "$(dirname "$0")/js-editor"

# Skip the npm install on incremental builds when node_modules is fresh
# enough — saves ~20s per Xcode build.
if [ ! -d node_modules ] || [ package.json -nt node_modules/.installed-stamp ]; then
    npm ci --no-audit --no-fund
    touch node_modules/.installed-stamp
fi

if [ "$CONFIGURATION" = "Debug" ]; then
    npm run build -- --mode development
else
    npm run build -- --mode production
fi

DEST="../Epistemos/Resources/Editor"
mkdir -p "$DEST"
rsync -a --delete dist/ "$DEST/"
