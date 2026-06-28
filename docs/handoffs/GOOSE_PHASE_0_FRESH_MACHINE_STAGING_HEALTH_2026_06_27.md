# Goose Phase 0 - Fresh-Machine Staging and Health Note

Date: 2026-06-27
Scope: Goose Phase 0 only. This note does not authorize `Epistemos/Agent/*`,
hybrid AppKit Phase 1, Paseo Section 15, or owner sign-off.

## Purpose

GooseWebUI availability must be reproducible on a fresh machine. Do not treat
an existing `~/Library/Application Support/Epistemos/GooseWebUI` directory or a
same-day `/tmp` log as proof. Re-stage the artifact, verify resolver markers,
then separately prove `goose serve` health and ACP reachability.

## Required Local Material

- Repo root: `/Users/jojo/Downloads/Epistemos`
- Goose clone: `.research-clones/work/goose`
- Goose desktop UI source: `.research-clones/work/goose/ui/desktop`
- Goose UI dependencies:
  - `.research-clones/work/goose/ui/node_modules`
  - `.research-clones/work/goose/ui/desktop/node_modules`
- Goose Vite binary: `.research-clones/work/goose/ui/node_modules/.bin/vite`
- Local Goose binary, preferred:
  `.research-clones/work/goose/target/aarch64-apple-darwin/debug/goose`

If any required dependency is missing, Phase 0 WebView proof is blocked rather
than silently degraded to a mock or stale artifact.

## Stage Goose Web UI

From the repo root:

```bash
OUT_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/epistemos-goose-webui-health.XXXXXX")"
./stage-goose-web-ui.sh "$OUT_ROOT/goose-desktop"
test -f "$OUT_ROOT/goose-desktop/index.html"
test -f "$OUT_ROOT/goose-desktop/.epistemos-goose-webui.json"
```

The staging script is the authority. It patches Goose desktop into ACP mode,
sets `USE_ACP_CHAT = true`, builds with relative assets, verifies required ACP
provider/catalog bridge markers, writes `.epistemos-goose-webui.json`, and
atomically moves the finished artifact into place.

For a faster overlay-only check:

```bash
EPISTEMOS_GOOSE_UI_VALIDATE_ONLY=1 ./stage-goose-web-ui.sh "$OUT_ROOT/unused"
```

That validation checks the ACP provider overlay without building the Vite
artifact. It is useful for quick diagnosis, but it is not a full staged Web UI
artifact proof.

## Resolver Acceptance

The resolver only accepts ACP-mode artifacts. A valid artifact has:

- `index.html`
- `.epistemos-goose-webui.json` with `acpMode: true`
- local relative asset references
- bridge markers including `shared-getAcpClient-provider-inventory`,
  `local-acp-config-GOOSE_TELEMETRY_ENABLED`,
  `providersList_unstable`, `providersCatalogList_unstable`,
  `providersSetupCatalogList_unstable`,
  `providersCatalogTemplate_unstable`,
  `__epistemosGooseACPRequestSerialization`,
  `__epistemosGooseProviderInventoryEvents`,
  `__epistemosGooseProviderCatalogEvents`, and
  `provider-catalog-template-choice`

To force a specific staged artifact for app/test runs, set:

```bash
export EPISTEMOS_GOOSE_UI_INDEX="$OUT_ROOT/goose-desktop/index.html"
```

`GooseWebUIResolver` should reject missing manifests, missing local assets,
absolute `/assets` paths, and missing bridge markers.

## Goose Serve Health

Use a local loopback port and an explicit token:

```bash
GOOSE_BIN="$PWD/.research-clones/work/goose/target/aarch64-apple-darwin/debug/goose"
PORT=3284
TOKEN="$(uuidgen | tr '[:upper:]' '[:lower:]')"
GOOSE_SERVER__SECRET_KEY="$TOKEN" "$GOOSE_BIN" serve \
  --host 127.0.0.1 \
  --port "$PORT" \
  --with-builtin developer
```

In another shell:

```bash
curl -fsS "http://127.0.0.1:$PORT/health"
```

Expected health response is `ok`. ACP initialization must connect to:

```text
ws://127.0.0.1:<port>/acp?token=<redacted-token>
```

Use live ACP proof scripts or `scripts/generate-goose-acp-fixtures.mjs` for
structured ACP verification. Do not count a mock transport as live Goose proof.
If `3284` is already occupied by an unrelated process, record that fact and use
another loopback port for the independent probe.

## Hosted Xcode Test Note

When building with `CODE_SIGNING_ALLOWED=NO`, the generated app can fail strict
verification and stall app-hosted XCTest. Before `test-without-building`, run:

```bash
codesign --force --deep --sign - \
  build/goose-phase0-verification-2026-06-27/DerivedData/Build/Products/Debug/Epistemos.app

codesign --verify --deep --strict --verbose=2 \
  build/goose-phase0-verification-2026-06-27/DerivedData/Build/Products/Debug/Epistemos.app
```

The expected `.xctestrun` file after build-for-testing is:

```text
build/goose-phase0-verification-2026-06-27/DerivedData/Build/Products/Epistemos_macosx26.4-arm64.xctestrun
```

Do not count a hosted test run as proof until XCTest reports real test counts.

## Window-Affordance Caveat

On 2026-06-27, opening real AppKit modal/MCP app windows from the hosted
WebView native-affordance test crashed in `_NSWindowTransformAnimation dealloc`
(`Epistemos-2026-06-27-195020.ips`). The current green WebView affordance proof
therefore handler-routes `showMessageBox`, `launchApp`, `refreshApp`, and
`closeApp`, and records:

```text
confirm_handler_override=true
mcp_app_handler_override=true
```

That proof is valid for WebView bridge dispatch plus non-window native
affordances. It is not real confirm-dialog or MCP-app window proof.

## Cleanup

After live proofs:

```bash
lsof -nP -iTCP:3284 -sTCP:LISTEN
pgrep -fl 'goose serve|Electron|vite|xcodebuild|xctest|swift-frontend|swiftc'
```

No Phase 0 proof should leave a `goose serve`, Electron fallback, Vite, XCTest,
or build process behind. Existing unrelated user apps are not proof failures,
but they should be named instead of hidden.

## Current Status

On 2026-06-27, staging, app-hosted XCTest after re-signing, `GooseLiveIntegrationTests`
7/7, and the broad provider/settings/source/route live verification 13/13 all
passed. Phase 0 remains not signed off because Gate 3 thought-stream proof,
Gate 5 OAuth/parity, true AppKit window-affordance proof, MAS/manual/
distribution WRV, and owner sign-off remain open.

On 2026-06-28, a stale app-support Goose Web UI artifact and fragile provider
inventory-first behavior reproduced owner-visible route failures. Re-stage with
the current script before manual testing. The accepted artifact must contain the
new shared-client marker `shared-getAcpClient-provider-inventory` and the
app-local config marker `local-acp-config-GOOSE_TELEMETRY_ENABLED`; artifacts
that only contain `createEpistemosGooseACPClient` are stale and must be rejected.
The fresh live route smoke passed against script `./assets/index-DDJFnyeu.js`
for `/configure-providers`, `/settings?section=models`, `/extensions`, `/apps`,
`/schedules`, `/recipes`, `/sessions`, and `/skills`.
