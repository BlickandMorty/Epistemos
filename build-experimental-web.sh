#!/bin/bash
set -e

# EXPERIMENTAL surface packaging (§16 of the build prompt) — stages the headless
# 1Code fork's runtime artifacts into Resources. Mirrors the PROVEN
# build-openchamber-web.sh patterns:
#   · stamps OUTSIDE Resources (xcodegen snapshots the synced Resources tree; a
#     changing stamp filename inside it leaves the project referencing a deleted
#     file -> BUILD FAILED — hit live on openchamber)
#   · ONE tarball (the synchronized resource copy FLATTENS directory trees)
#   · native modules installed with the PINNED node's own npm (ABI match), never
#     electron-rebuild (upstream postinstall targets Electron's ABI)
#   · REFUSES a dist containing a service worker (stale-bundle guard)
#
# Experimental-specific additions:
#   · Node 25.8.2 is SHARED with the OpenChamber surface — same vendor path +
#     stamp name, so whichever script runs first vendors it and the other skips.
#   · node_modules is the COMPUTED backend subset: the headless bundle externalizes
#     its deps, so we scan it for require("pkg") and install only those (the
#     renderer is pre-built static — its React/mermaid/etc. never run in Node).
#   · chmod +x on node-pty's spawn-helper (bun/npm can drop the exec bit ->
#     posix_spawnp failure at the first PTY touch — hit live 2026-07-05).
#   · BOOT SELF-TEST: the staged tree is booted with the pinned node and must
#     serve /healthz before the tarball is accepted.
#
# Layout produced:
#   Epistemos/Resources/openchamber-runtime/bin/node       — shared pinned Node
#   Epistemos/Resources/experimental-runtime/experimental-web.tar.gz
#       server/ (headless bundle + electron-shim + onecode-shim + migrations)
#       dist/   (built renderer SPA)
#       node_modules/ (backend subset, pinned-node ABI)
#
# Fork source: .research-clones/1code (override: EXPERIMENTAL_FORK_ROOT).
# The fork must be pre-built:  bun run build  &&  node headless/build.mjs

NODE_VERSION="25.8.2"   # native-ABI anchor, shared with OpenChamber

ROOT="$(cd "$(dirname "$0")" && pwd)"
FORK="${EXPERIMENTAL_FORK_ROOT:-$ROOT/.research-clones/1code}"
DEST="$ROOT/Epistemos/Resources/experimental-runtime"
SHARED_BIN="$ROOT/Epistemos/Resources/openchamber-runtime/bin"
STAMPS="$ROOT/.build-stamps"
mkdir -p "$STAMPS" "$DEST" "$SHARED_BIN"

case "$(uname -m)" in
    arm64|aarch64) NODE_ASSET="node-v${NODE_VERSION}-darwin-arm64" ;;
    x86_64)        NODE_ASSET="node-v${NODE_VERSION}-darwin-x64" ;;
    *) echo "build-experimental-web.sh: unsupported arch $(uname -m)"; exit 1 ;;
esac

# SAME stamp name as build-openchamber-web.sh — the sharing contract.
NODE_STAMP="$STAMPS/openchamber-node-${NODE_VERSION}-$(uname -m)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# -------------------------------------------------------------------
# 1. Shared pinned Node runtime (stamp gated, same path as OpenChamber)
# -------------------------------------------------------------------
if [ -f "$NODE_STAMP" ] && [ -x "$SHARED_BIN/node" ]; then
    echo "build-experimental-web.sh: shared pinned Node ${NODE_VERSION} already vendored — skipping."
else
    echo "build-experimental-web.sh: vendoring shared Node ${NODE_VERSION} (${NODE_ASSET})…"
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ASSET}.tar.gz" -o "$TMP/node.tar.gz"
    tar -xzf "$TMP/node.tar.gz" -C "$TMP"
    cp "$TMP/${NODE_ASSET}/bin/node" "$SHARED_BIN/node"
    chmod +x "$SHARED_BIN/node"
    rm -f "$STAMPS"/openchamber-node-*
    touch "$NODE_STAMP"
fi
# Full extracted dist for its npm (ABI-matched installs below).
if [ ! -d "$TMP/${NODE_ASSET}" ]; then
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ASSET}.tar.gz" -o "$TMP/node.tar.gz"
    tar -xzf "$TMP/node.tar.gz" -C "$TMP"
fi
PINNED_NODE_DIR="$TMP/${NODE_ASSET}"

# -------------------------------------------------------------------
# 2. Preflight the fork build artifacts
# -------------------------------------------------------------------
# GRACEFUL SKIP (exit 0): this script is wired into the shared Epistemos preBuild
# chain, so on a machine without the gitignored .research-clones/1code fork (CI,
# a fresh checkout, any non-Experimental build) it must NOT fail the whole app
# build. The Experimental surface honestly reports "runtime not staged" at launch.
if [ ! -d "$FORK" ]; then
    echo "build-experimental-web.sh: fork clone absent at $FORK — skipping (Experimental runtime not staged)."
    exit 0
fi
if [ ! -f "$FORK/out/renderer/index.html" ] || [ ! -f "$FORK/headless/dist/index.cjs" ]; then
    echo "build-experimental-web.sh: fork present but not built at $FORK — skipping. To stage, run:" >&2
    echo "  cd $FORK && bun run build && node headless/build.mjs" >&2
    exit 0
fi

# License deny-list gate (§4/§16 "the SBOM gate is the real enforcement"): FAIL the build
# if any dependency carries a copyleft/non-commercial license incompatible with the paid,
# closed-source Developer-ID distribution. Runs against the staged fork's node_modules.
if [ -f "$FORK/scripts/epistemos-license-gate.mjs" ] && [ -d "$FORK/node_modules" ]; then
    echo "build-experimental-web.sh: running license deny-list gate…"
    if ! "$SHARED_BIN/node" "$FORK/scripts/epistemos-license-gate.mjs" "$FORK/node_modules"; then
        echo "build-experimental-web.sh: LICENSE GATE FAILED — a denied dependency is present. Aborting." >&2
        exit 1
    fi
fi
# Service-worker refusal (stale/stock dist guard).
if [ -f "$FORK/out/renderer/sw.js" ] || grep -rlq "serviceWorker\.register" "$FORK/out/renderer/assets" 2>/dev/null; then
    echo "build-experimental-web.sh: REFUSING a dist containing a service worker" >&2
    exit 1
fi

# De-brand gate (Task 4 / DoD-4): the shipped artifacts must carry ZERO donor
# branding — no "21st", "1code", "twentyfirst" in the served renderer or the
# headless backend bundle. LICENSE/NOTICE attribution files are the only
# exemption (Apache-2.0 requires keeping them; they are not user-facing UI).
DEBRAND_HITS="$(grep -rEli '21st|1code|twentyfirst' "$FORK/headless/dist" "$FORK/out/renderer" 2>/dev/null | grep -Ev '(^|/)(LICENSE|NOTICE)' || true)"
if [ -n "$DEBRAND_HITS" ]; then
    echo "build-experimental-web.sh: DE-BRAND GATE FAILED — donor branding found in:" >&2
    echo "$DEBRAND_HITS" >&2
    exit 1
fi

FORK_SHA="$(git -C "$FORK" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
DIRTY="$(git -C "$FORK" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
CONTENT_HASH="$( (git -C "$FORK" rev-parse HEAD 2>/dev/null; shasum -a 256 "$FORK/bun.lock" "$FORK/headless/dist/index.cjs" "$FORK/headless/dist/onecode-shim.js" "$FORK/out/renderer/index.html" 2>/dev/null) | shasum -a 256 | cut -c1-16)"
WEB_STAMP="$STAMPS/experimental-web-${FORK_SHA}-${CONTENT_HASH}"

if [ -f "$WEB_STAMP" ] && [ -f "$DEST/experimental-web.tar.gz" ] && [ "$DIRTY" = "0" ]; then
    echo "build-experimental-web.sh: web bundle for ${FORK_SHA} already staged — skipping."
    echo "build-experimental-web.sh: done."
    exit 0
fi

# -------------------------------------------------------------------
# 3. Stage: server + dist + migrations + computed backend node_modules
# -------------------------------------------------------------------
echo "build-experimental-web.sh: staging web bundle (fork ${FORK_SHA}, dirty=${DIRTY})…"
STAGE="$TMP/experimental-web"
mkdir -p "$STAGE/server"
cp "$FORK/headless/dist/index.cjs" "$FORK/headless/dist/electron-shim.cjs" "$FORK/headless/dist/onecode-shim.js" "$STAGE/server/"
cp -R "$FORK/drizzle" "$STAGE/server/migrations"   # packaged path: resourcesPath(=server/)/migrations
cp -R "$FORK/out/renderer" "$STAGE/dist"

# Computed backend dependency subset: externals actually required by the bundle.
python3 - "$FORK/headless/dist/index.cjs" "$FORK/package.json" "$STAGE/package.json" <<'PYEOF'
import json, re, sys
bundle, fork_pkg, out = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(bundle, encoding="utf8", errors="replace").read()
names = set()
# Catch require("x"), import("x"), AND require.resolve("x") / require.resolve("x/package.json").
# The engine SDKs are loaded via dynamic import()/require.resolve, NOT static require — a
# require-only scan silently dropped @anthropic-ai/claude-agent-sdk + @zed-industries/codex-acp
# from the bundle, so chat died at runtime with "Cannot find package". (owner 2026-07-05)
for m in re.finditer(r'(?:require(?:\.resolve)?|import)\(\s*"((?:@[\w.-]+/)?[\w.-]+)(?:/[^"]*)?"', src):
    root = m.group(1)
    if not root.startswith("node:"):
        names.add(root)
# FORCE-INCLUDE the engine SDKs regardless of scan — they are load-bearing and dynamically
# resolved. If a future refactor stops referencing them literally, chat must still work.
FORCE = {"@anthropic-ai/claude-agent-sdk", "@zed-industries/codex-acp", "@mcpc-tech/acp-ai-provider", "@agentclientprotocol/codex-acp"}
names |= FORCE
deps = json.load(open(fork_pkg))["dependencies"]
subset = {k: v for k, v in sorted(deps.items()) if k in names}
missing = sorted(n for n in names if n not in deps and not n.startswith(("electron",)))
pkg = {"name": "epistemos-experimental-backend", "private": True, "dependencies": subset}
json.dump(pkg, open(out, "w"), indent=2)
print(f"[deps] backend subset: {len(subset)} of {len(deps)} fork deps")
if missing:
    print(f"[deps] required-but-not-in-dependencies (builtins/dev?): {missing}")
PYEOF

echo "build-experimental-web.sh: production npm install with the PINNED node (ABI match)…"
# --legacy-peer-deps: the fork resolves with bun (lenient); the engine SDKs (claude-agent-sdk,
# codex-acp) carry peer-dep constraints npm's strict resolver rejects. Match bun's behavior.
(cd "$STAGE" && PATH="$PINNED_NODE_DIR/bin:$PATH" "$PINNED_NODE_DIR/bin/npm" install --omit=dev --legacy-peer-deps --no-audit --no-fund --loglevel=error)

# §4/§16: re-run the license deny-list gate on the STAGED production subset — this is what
# actually SHIPS. The earlier gate scans the fork's dev node_modules; --legacy-peer-deps can
# resolve different transitive versions here, so the shipped tree must be scanned on its own.
if [ -f "$FORK/scripts/epistemos-license-gate.mjs" ]; then
    echo "build-experimental-web.sh: license gate on the STAGED (shipped) node_modules…"
    if ! "$SHARED_BIN/node" "$FORK/scripts/epistemos-license-gate.mjs" "$STAGE/node_modules"; then
        echo "build-experimental-web.sh: STAGED license gate FAILED — a shipped dependency carries a denied license." >&2
        exit 1
    fi
fi

# §16 arm64-first artifact: strip native prebuilds for other platforms (Windows / Linux /
# Intel-mac) — pure dead weight in a macOS arm64 build, and adhoc-signed cross-platform .node
# files would only add notarization surface. Keep darwin-arm64 only. (Reversible: a future
# universal build removes this prune.)
PRUNED_BEFORE=$(du -sk "$STAGE/node_modules" 2>/dev/null | cut -f1)
find "$STAGE/node_modules" -type d -path "*/prebuilds/*" \
    \( -name "win32-*" -o -name "linux-*" -o -name "linuxmusl-*" -o -name "darwin-x64" -o -name "android-*" \) \
    -prune -exec rm -rf {} + 2>/dev/null || true
# sharp ships per-platform packages under @img — keep only the darwin-arm64 pair.
if [ -d "$STAGE/node_modules/@img" ]; then
    find "$STAGE/node_modules/@img" -maxdepth 1 -mindepth 1 -type d \
        ! -name "sharp-darwin-arm64" ! -name "sharp-libvips-darwin-arm64" \
        -exec rm -rf {} + 2>/dev/null || true
fi
# claude-agent-sdk vendors ripgrep per-platform (vendor/ripgrep/<arch-os>/) for the Grep tool —
# keep ONLY arm64-darwin (removing it would break Grep). Strip linux/win32/x64-darwin.
RG_DIR="$STAGE/node_modules/@anthropic-ai/claude-agent-sdk/vendor/ripgrep"
if [ -d "$RG_DIR" ]; then
    find "$RG_DIR" -maxdepth 1 -mindepth 1 -type d ! -name "arm64-darwin" \
        -exec rm -rf {} + 2>/dev/null || true
fi
PRUNED_AFTER=$(du -sk "$STAGE/node_modules" 2>/dev/null | cut -f1)
echo "build-experimental-web.sh: arm64-first prune — node_modules ${PRUNED_BEFORE}K → ${PRUNED_AFTER}K"

# spawn-helper exec bit (posix_spawnp gotcha) — enforce unconditionally.
chmod +x "$STAGE"/node_modules/node-pty/prebuilds/darwin-*/spawn-helper 2>/dev/null || true

echo "{\"forkSha\":\"$FORK_SHA\",\"dirty\":$DIRTY,\"stagedAt\":\"$(date -u +%FT%TZ)\"}" > "$STAGE/.epistemos-web-version.json"

# -------------------------------------------------------------------
# 4. BOOT SELF-TEST: staged tree must serve /healthz with the pinned node
# -------------------------------------------------------------------
SELFTEST_PORT=49733
echo "build-experimental-web.sh: boot self-test on :${SELFTEST_PORT}…"
EPISTEMOS_ONECODE_PORT=$SELFTEST_PORT \
EPISTEMOS_ONECODE_PACKAGED=1 \
EPISTEMOS_ONECODE_USER_DATA="$TMP/selftest-userdata" \
EPISTEMOS_ONECODE_RENDERER="$STAGE/dist" \
NODE_PATH="$STAGE/node_modules" \
"$SHARED_BIN/node" --max-old-space-size=3072 "$STAGE/server/index.cjs" >"$TMP/selftest.log" 2>&1 &
SELFTEST_PID=$!
HEALTH=""
for _ in $(seq 1 20); do
    sleep 0.5
    HEALTH="$(curl -s --max-time 2 "http://127.0.0.1:${SELFTEST_PORT}/healthz" || true)"
    [ -n "$HEALTH" ] && break
done
kill "$SELFTEST_PID" 2>/dev/null || true
wait "$SELFTEST_PID" 2>/dev/null || true
if ! echo "$HEALTH" | grep -q '"ok":true'; then
    echo "build-experimental-web.sh: BOOT SELF-TEST FAILED — staged tree did not serve /healthz:" >&2
    tail -20 "$TMP/selftest.log" >&2
    exit 1
fi
echo "build-experimental-web.sh: boot self-test passed (${HEALTH})."

# -------------------------------------------------------------------
# 5. Tarball
# -------------------------------------------------------------------
tar -czf "$DEST/experimental-web.tar.gz" -C "$TMP" experimental-web
rm -f "$STAMPS"/experimental-web-*
[ "$DIRTY" = "0" ] && touch "$WEB_STAMP"
echo "build-experimental-web.sh: staged $(du -h "$DEST/experimental-web.tar.gz" | cut -f1) tarball."
echo "build-experimental-web.sh: done."
