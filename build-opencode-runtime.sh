#!/bin/bash
set -e

# WORK ENGINE = OpenCode (Architecture C, owner 2026-06-21). This script vendors the OpenCode work-engine
# runtime into Epistemos.app/Contents/Resources/opencode-runtime/ at BUILD time — the SAME proven pattern as
# build-tiptap-bundle.sh (fetch/build at build time, ship static inside the .app; the END USER installs
# NOTHING). Per the addendum "🆕 BUN RUNTIME = VENDORED/BUNDLED": bundle the PINNED Bun binary, never depend
# on a dev `brew install bun`.
#
# Layout produced (what WorkOpenCodeRuntime.bundledRuntimeURL() resolves):
#   Resources/opencode-runtime/bin/bun        — the pinned Bun runtime (this script, checkpoint 1)
#   Resources/opencode-runtime/bin/opencode   — the OpenCode CLI/TUI launcher (checkpoint 2, next)
#
# Gating: a version stamp (Resources/opencode-runtime/.bun-<version>-<arch>) so the ~90MB Bun fetch only fires
# when the pinned version/arch changes — unchanged checkouts skip it (stable Xcode resource graph).
#
# CI: set CI=1 to fail loudly if the runtime output is missing.

# -------------------------------------------------------------------
# Pins (bump deliberately; the stamp invalidates on change)
# -------------------------------------------------------------------
BUN_VERSION="1.3.14"

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$ROOT/Epistemos/Resources/opencode-runtime"
BIN_DIR="$DEST/bin"

# Target arch → Bun release asset name.
case "$(uname -m)" in
    arm64|aarch64) BUN_ASSET="bun-darwin-aarch64" ;;
    x86_64)        BUN_ASSET="bun-darwin-x64" ;;
    *) echo "build-opencode-runtime.sh: unsupported arch $(uname -m)"; exit 1 ;;
esac

STAMP="$DEST/.bun-${BUN_VERSION}-${BUN_ASSET}"

# -------------------------------------------------------------------
# 1. Fetch the PINNED Bun binary into Resources (version-stamp gated)
# -------------------------------------------------------------------
if [ -f "$STAMP" ] && [ -x "$BIN_DIR/bun" ]; then
    echo "build-opencode-runtime.sh: pinned Bun ${BUN_VERSION} (${BUN_ASSET}) already vendored — skipping fetch."
else
    echo "build-opencode-runtime.sh: vendoring pinned Bun ${BUN_VERSION} (${BUN_ASSET})…"
    mkdir -p "$BIN_DIR"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    URL="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/${BUN_ASSET}.zip"
    if ! curl -fsSL "$URL" -o "$TMP/bun.zip"; then
        echo "build-opencode-runtime.sh: failed to download Bun from $URL" >&2
        exit 1
    fi
    unzip -q -o "$TMP/bun.zip" -d "$TMP"
    # The zip extracts to <asset>/bun.
    if [ ! -f "$TMP/${BUN_ASSET}/bun" ]; then
        echo "build-opencode-runtime.sh: Bun binary not found in archive (expected ${BUN_ASSET}/bun)" >&2
        exit 1
    fi
    cp "$TMP/${BUN_ASSET}/bun" "$BIN_DIR/bun"
    chmod +x "$BIN_DIR/bun"
    # Clear old stamps + stamp the new pin.
    rm -f "$DEST"/.bun-* 2>/dev/null || true
    touch "$STAMP"
    echo "build-opencode-runtime.sh: vendored Bun → $BIN_DIR/bun ($("$BIN_DIR/bun" --version 2>/dev/null || echo '?'))"
fi

# -------------------------------------------------------------------
# 2. OpenCode CLI/TUI build → Resources/opencode-runtime/bin/opencode  [NEXT CHECKPOINT]
#    Vendor the pinned OpenCode source, `bun install`, and stage the launcher so the native SwiftTerm/PTY
#    terminal view can spawn `opencode` (the resolver goes LIVE once bin/opencode exists). Implemented in the
#    follow-on checkpoint; until then the work shell stays honestly INERT (resolver returns nil without
#    bin/opencode). Not faked.
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# 3. Sanity check
# -------------------------------------------------------------------
if [ ! -x "$BIN_DIR/bun" ]; then
    echo "build-opencode-runtime.sh: Bun runtime missing at $BIN_DIR/bun" >&2
    exit 2
fi

if [ "${CI:-}" = "1" ]; then
    echo "build-opencode-runtime.sh: CI mode — Bun runtime vendored ($(du -sh "$BIN_DIR/bun" | cut -f1))"
fi
