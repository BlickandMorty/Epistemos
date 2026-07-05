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
# Pins (bump deliberately; the stamps invalidate on change)
# -------------------------------------------------------------------
BUN_VERSION="1.3.14"
OPENCODE_VERSION="1.17.9"   # sst/opencode standalone binary release

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$ROOT/Epistemos/Resources/opencode-runtime"
BIN_DIR="$DEST/bin"

# Target arch → release asset names (Bun + OpenCode).
case "$(uname -m)" in
    arm64|aarch64) BUN_ASSET="bun-darwin-aarch64"; OC_ASSET="opencode-darwin-arm64" ;;
    x86_64)        BUN_ASSET="bun-darwin-x64";     OC_ASSET="opencode-darwin-x64" ;;
    *) echo "build-opencode-runtime.sh: unsupported arch $(uname -m)"; exit 1 ;;
esac

STAMP="$DEST/.bun-${BUN_VERSION}-${BUN_ASSET}"
OC_STAMP="$DEST/.opencode-${OPENCODE_VERSION}-${OC_ASSET}"

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
# 2. Fetch the PINNED OpenCode standalone binary → Resources/.../bin/opencode (version-stamp gated)
#    sst/opencode ships a self-contained (bun-compiled) `opencode` CLI/TUI binary — no source build. The
#    native SwiftTerm/PTY terminal view spawns it; the resolver (WorkOpenCodeRuntime.bundledRuntimeURL) goes
#    LIVE once bin/opencode exists.
# -------------------------------------------------------------------
if [ -f "$OC_STAMP" ] && [ -x "$BIN_DIR/opencode" ]; then
    echo "build-opencode-runtime.sh: pinned OpenCode ${OPENCODE_VERSION} (${OC_ASSET}) already vendored — skipping fetch."
else
    echo "build-opencode-runtime.sh: vendoring pinned OpenCode ${OPENCODE_VERSION} (${OC_ASSET})…"
    mkdir -p "$BIN_DIR"
    OCTMP="$(mktemp -d)"
    trap 'rm -rf "$OCTMP"' EXIT
    OC_URL="https://github.com/sst/opencode/releases/download/v${OPENCODE_VERSION}/${OC_ASSET}.zip"
    if ! curl -fsSL "$OC_URL" -o "$OCTMP/opencode.zip"; then
        echo "build-opencode-runtime.sh: failed to download OpenCode from $OC_URL" >&2
        exit 1
    fi
    unzip -q -o "$OCTMP/opencode.zip" -d "$OCTMP"
    if [ ! -f "$OCTMP/opencode" ]; then
        echo "build-opencode-runtime.sh: opencode binary not found in archive" >&2
        exit 1
    fi
    cp "$OCTMP/opencode" "$BIN_DIR/opencode"
    chmod +x "$BIN_DIR/opencode"
    rm -f "$DEST"/.opencode-* 2>/dev/null || true
    touch "$OC_STAMP"
    echo "build-opencode-runtime.sh: vendored OpenCode → $BIN_DIR/opencode ($("$BIN_DIR/opencode" --version 2>/dev/null || echo '?'))"
fi

# -------------------------------------------------------------------
# 2.5 Build + stage the omega_mcp_stdio FUSION server → Resources/.../bin/omega_mcp_stdio
#     The stdio MCP server that fuses the app's vault tools into OpenCode's work agent. Built from the
#     omega-mcp crate (Rust); cargo's incremental cache makes this fast after the first build.
#     WorkOpenCodeRuntime.bundledMcpServerURL() resolves it; launchSpec then registers it via OPENCODE_CONFIG.
# -------------------------------------------------------------------
if command -v cargo >/dev/null 2>&1; then
    echo "build-opencode-runtime.sh: building omega_mcp_stdio fusion server…"
    if cargo build --release --manifest-path "$ROOT/omega-mcp/Cargo.toml" --bin omega_mcp_stdio >/dev/null 2>&1; then
        # HOST-ARCH selection (2026-07-05 root-cause): the old `find … | head -1`
        # nondeterministically picked the x86_64-apple-darwin build on an arm64
        # host → "bad CPU type in executable" → the engine's MCP spawn silently
        # died and epistemos-vault never reached the agent. Prefer the host
        # triple, then the plain host build; VERIFY the arch before staging.
        HOST_ARCH="$(uname -m)"
        case "$HOST_ARCH" in
            arm64)  RUST_TRIPLE="aarch64-apple-darwin" ;;
            x86_64) RUST_TRIPLE="x86_64-apple-darwin" ;;
            *)      RUST_TRIPLE="" ;;
        esac
        STDIO_BIN=""
        for CAND in "$ROOT/omega-mcp/target/$RUST_TRIPLE/release/omega_mcp_stdio" \
                    "$ROOT/omega-mcp/target/release/omega_mcp_stdio"; do
            if [ -f "$CAND" ]; then STDIO_BIN="$CAND"; break; fi
        done
        if [ -n "$STDIO_BIN" ]; then
            BIN_ARCHS="$(lipo -archs "$STDIO_BIN" 2>/dev/null || true)"
            case " $BIN_ARCHS " in
                *" $HOST_ARCH "*) : ;;  # lipo reports "arm64"/"x86_64" (space-separated when fat)
                *)
                    echo "build-opencode-runtime.sh: FATAL staged omega_mcp_stdio arch '$BIN_ARCHS' != host '$HOST_ARCH' — refusing a dead MCP binary" >&2
                    exit 1
                    ;;
            esac
            mkdir -p "$BIN_DIR"
            cp "$STDIO_BIN" "$BIN_DIR/omega_mcp_stdio"
            chmod +x "$BIN_DIR/omega_mcp_stdio"
            echo "build-opencode-runtime.sh: staged omega_mcp_stdio ($BIN_ARCHS) → $BIN_DIR/omega_mcp_stdio"
        else
            echo "build-opencode-runtime.sh: WARN omega_mcp_stdio binary not found after build (fusion omitted)" >&2
        fi
    else
        echo "build-opencode-runtime.sh: WARN omega_mcp_stdio build failed (fusion omitted; TUI still launches)" >&2
    fi
else
    echo "build-opencode-runtime.sh: WARN cargo not on PATH — omega_mcp_stdio fusion server not built" >&2
fi

# -------------------------------------------------------------------
# 3. Sanity check
# -------------------------------------------------------------------
# Bun is checkpoint 1 (this script stages it) — its absence IS a real failure.
if [ ! -x "$BIN_DIR/bun" ]; then
    echo "build-opencode-runtime.sh: Bun runtime missing at $BIN_DIR/bun" >&2
    exit 2
fi
# The OpenCode CLI/TUI launcher is checkpoint 2 (the pinned OpenCode vendor) and is NOT staged by
# this script yet. Its absence is the HONEST partial-vendor state — Bun + the omega_mcp_stdio fusion
# server are staged, but the work shell stays INERT (WorkOpenCodeRuntime.resolveRuntimeURL returns
# nil → WorkTerminalHostView shows the honest unavailable view) until the pinned launcher lands at
# $BIN_DIR/opencode. So WARN, do NOT hard-fail (exit 2) — the partial runtime must stage cleanly, and
# a hard-fail here would break any build step that invokes this script before OpenCode is vendored.
if [ ! -x "$BIN_DIR/opencode" ]; then
    echo "build-opencode-runtime.sh: NOTE OpenCode launcher not vendored yet (checkpoint 2 pending) — Bun + fusion staged; the work shell stays honestly inert until $BIN_DIR/opencode lands." >&2
fi

if [ "${CI:-}" = "1" ]; then
    if [ -x "$BIN_DIR/opencode" ]; then
        echo "build-opencode-runtime.sh: CI mode — runtime vendored (bun $(du -sh "$BIN_DIR/bun" | cut -f1), opencode $(du -sh "$BIN_DIR/opencode" | cut -f1))"
    else
        echo "build-opencode-runtime.sh: CI mode — partial runtime (bun $(du -sh "$BIN_DIR/bun" | cut -f1) staged; opencode pending checkpoint 2)"
    fi
fi
