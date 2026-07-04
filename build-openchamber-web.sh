#!/bin/bash
set -e

# PLAN 1-PRO packaging (§1 "bundle a Node runtime + pruned production
# node_modules"; matched-triple §6). Stages the Pro agent surface's runtime
# artifacts into Resources — the SAME proven pattern as
# build-opencode-runtime.sh (pinned fetch at build time, version-stamp gated,
# the end user installs NOTHING).
#
# Layout produced:
#   Resources/openchamber-runtime/bin/node          — pinned Node runtime
#   Resources/openchamber-runtime/bin/opencode-triple — matched-triple opencode
#                                                     (NAMED to avoid the
#                                                     flattened-resource
#                                                     collision with the Work
#                                                     lane's bin/opencode)
#                                                     (SDK pin 1.17.12 — the
#                                                     Work lane's 1.17.9 stays
#                                                     THEIRS, untouched)
#   Resources/openchamber-runtime/openchamber-web.tar.gz
#       server/ + dist/ + package.json + pruned production node_modules,
#       shipped as ONE artifact because the synchronized resource copy
#       FLATTENS directory trees (iter31 lesson) — the supervisor unpacks it
#       to Application Support, version-stamped.
#
# The tarball's native modules (node-pty, better-sqlite3, sherpa-onnx-node)
# are installed with the PINNED node's own npm so the ABI always matches the
# bundled runtime, not whatever node the dev machine has.
#
# Fork source: ~/dev/openchamber-epistemos (override: OPENCHAMBER_FORK_ROOT).
# The embed dist must be built (VITE_EPISTEMOS_EMBED=1 bun run build:web) —
# this script REFUSES a dist that still contains a service worker.

NODE_VERSION="25.8.2"           # match the verified dev runtime (native-ABI anchor)
OPENCODE_VERSION="1.17.12"      # MATCHED TRIPLE: @opencode-ai/sdk pin at the vendored fork

ROOT="$(cd "$(dirname "$0")" && pwd)"
FORK="${OPENCHAMBER_FORK_ROOT:-$HOME/dev/openchamber-epistemos}"
WEB="$FORK/packages/web"
DEST="$ROOT/Epistemos/Resources/openchamber-runtime"
BIN_DIR="$DEST/bin"

case "$(uname -m)" in
    arm64|aarch64) NODE_ASSET="node-v${NODE_VERSION}-darwin-arm64"; OC_ASSET="opencode-darwin-arm64" ;;
    x86_64)        NODE_ASSET="node-v${NODE_VERSION}-darwin-x64";   OC_ASSET="opencode-darwin-x64" ;;
    *) echo "build-openchamber-web.sh: unsupported arch $(uname -m)"; exit 1 ;;
esac

NODE_STAMP="$DEST/.node-${NODE_VERSION}-$(uname -m)"
OC_STAMP="$DEST/.opencode-${OPENCODE_VERSION}-$(uname -m)"

mkdir -p "$BIN_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# -------------------------------------------------------------------
# 1. Pinned Node runtime (stamp gated)
# -------------------------------------------------------------------
if [ -f "$NODE_STAMP" ] && [ -x "$BIN_DIR/node" ]; then
    echo "build-openchamber-web.sh: pinned Node ${NODE_VERSION} already vendored — skipping."
else
    echo "build-openchamber-web.sh: vendoring Node ${NODE_VERSION} (${NODE_ASSET})…"
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ASSET}.tar.gz" -o "$TMP/node.tar.gz"
    tar -xzf "$TMP/node.tar.gz" -C "$TMP"
    cp "$TMP/${NODE_ASSET}/bin/node" "$BIN_DIR/node"
    chmod +x "$BIN_DIR/node"
    rm -f "$DEST"/.node-*
    touch "$NODE_STAMP"
fi
# Keep the full extracted dist around for its npm (staging installs below).
if [ ! -d "$TMP/${NODE_ASSET}" ]; then
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ASSET}.tar.gz" -o "$TMP/node.tar.gz"
    tar -xzf "$TMP/node.tar.gz" -C "$TMP"
fi
PINNED_NODE_DIR="$TMP/${NODE_ASSET}"

# -------------------------------------------------------------------
# 2. Matched-triple opencode (stamp gated; separate from the Work lane's pin)
# -------------------------------------------------------------------
if [ -f "$OC_STAMP" ] && [ -x "$BIN_DIR/opencode-triple" ]; then
    echo "build-openchamber-web.sh: pinned opencode ${OPENCODE_VERSION} already vendored — skipping."
else
    echo "build-openchamber-web.sh: vendoring opencode ${OPENCODE_VERSION} (${OC_ASSET})…"
    curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/${OC_ASSET}.zip" -o "$TMP/opencode.zip" \
      || curl -fsSL "https://github.com/sst/opencode/releases/download/v${OPENCODE_VERSION}/${OC_ASSET}.zip" -o "$TMP/opencode.zip"
    unzip -q -o "$TMP/opencode.zip" -d "$TMP/oc"
    OC_BIN="$(find "$TMP/oc" -name opencode -type f | head -1)"
    if [ -z "$OC_BIN" ]; then
        echo "build-openchamber-web.sh: opencode binary not found in release archive" >&2
        exit 1
    fi
    cp "$OC_BIN" "$BIN_DIR/opencode-triple"
    chmod +x "$BIN_DIR/opencode-triple"
    rm -f "$DEST"/.opencode-*
    touch "$OC_STAMP"
fi

# -------------------------------------------------------------------
# 3. Web bundle tarball (content-hash gated on the fork's HEAD + dist)
# -------------------------------------------------------------------
if [ ! -f "$WEB/dist/index.html" ] || [ ! -f "$WEB/server/index.js" ]; then
    echo "build-openchamber-web.sh: fork embed dist missing at $WEB — build it first:" >&2
    echo "  cd $FORK && VITE_EPISTEMOS_EMBED=1 bun run build:web" >&2
    exit 1
fi
if [ -f "$WEB/dist/sw.js" ]; then
    echo "build-openchamber-web.sh: REFUSING a dist with a service worker (stock flavor?) — rebuild with VITE_EPISTEMOS_EMBED=1" >&2
    exit 1
fi

FORK_SHA="$(git -C "$FORK" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
DIST_HASH="$( (git -C "$FORK" rev-parse HEAD; find "$WEB/dist" -type f -newer "$WEB/package.json" 2>/dev/null | wc -l) | shasum -a 256 | cut -c1-16)"
WEB_STAMP="$DEST/.web-${FORK_SHA}-${DIST_HASH}"

if [ -f "$WEB_STAMP" ] && [ -f "$DEST/openchamber-web.tar.gz" ]; then
    echo "build-openchamber-web.sh: web bundle for ${FORK_SHA} already staged — skipping."
else
    echo "build-openchamber-web.sh: staging web bundle (fork ${FORK_SHA})…"
    STAGE="$TMP/openchamber-web"
    mkdir -p "$STAGE"
    cp -R "$WEB/server" "$STAGE/server"
    cp -R "$WEB/dist" "$STAGE/dist"
    cp -R "$WEB/public" "$STAGE/public" 2>/dev/null || true
    # package.json minus devDependencies/scripts (production install only).
    python3 - "$WEB/package.json" "$STAGE/package.json" <<'PYEOF'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
pkg = json.load(open(src))
for key in ("devDependencies", "scripts"):
    pkg.pop(key, None)
json.dump(pkg, open(dst, "w"), indent=2)
PYEOF
    echo "build-openchamber-web.sh: production npm install with the PINNED node (native-module ABI match)…"
    (cd "$STAGE" && PATH="$PINNED_NODE_DIR/bin:$PATH" "$PINNED_NODE_DIR/bin/npm" install --omit=dev --no-audit --no-fund --loglevel=error)
    # Version marker the supervisor uses for its unpack stamp.
    echo "{\"forkSha\":\"$FORK_SHA\",\"stagedAt\":\"$(date -u +%FT%TZ)\"}" > "$STAGE/.epistemos-web-version.json"
    tar -czf "$DEST/openchamber-web.tar.gz" -C "$TMP" openchamber-web
    rm -f "$DEST"/.web-*
    touch "$WEB_STAMP"
    echo "build-openchamber-web.sh: staged $(du -h "$DEST/openchamber-web.tar.gz" | cut -f1) tarball."
fi

echo "build-openchamber-web.sh: done."
