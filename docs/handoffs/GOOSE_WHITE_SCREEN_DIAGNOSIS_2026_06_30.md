# Goose white-screen — diagnosis handoff (2026-06-30)

> **For the agent working Plan 1 (Goose).** This is a live-evidence diagnosis of the Goose white-screen / "waiting for
> ACP" bug, gathered by running the app and probing the live servers. Everything below is either **CONFIRMED** (observed
> at runtime) or **HYPOTHESIS** (ranked). Goal: you fix it correctly without re-deriving the investigation.

---

## Symptom (what the owner sees)
The "Epistemos Goose" window opens **blank white**, OR renders the placeholder **"Goose Web UI waiting for ACP"** and
never advances to the real UI. It *used to work* — this is a **regression** that tracks with repeated rebuilds.

## TL;DR — most likely cause
**A non-atomic / stale web-UI staging interacting with constant rebuilds.** The Goose UI is a React SPA. The served
`index.html` references content-hashed assets (e.g. `assets/index-CA98ulTS.js`) that **404** because the served
directory's `index.html` and its `assets/` folder are out of sync. HTML with no JS → empty `<div id="root">` → white.
A second, downstream failure (**ACP WebSocket never reaches `.connected`**) leaves it stuck on the placeholder even when
the page does render. Repeated rebuild+relaunch cycles keep re-desyncing the staging, so it can never stabilize.

---

## CONFIRMED at runtime (with evidence)

1. **Build is NOT the problem.** Running app is non-sandboxed Debug: `com.apple.security.app-sandbox = <false/>`, and
   `EPISTEMOS_APP_STORE` is **not** in the Debug `SWIFT_ACTIVE_COMPILATION_CONDITIONS`. So the `#if EPISTEMOS_APP_STORE`
   gate at `GooseRuntimeSupervisor.swift:176` is NOT compiled in, and the sandbox is not blocking the subprocess.

2. **The goose backend works.** The bundled `goose` (1.39.0, arm64) cold-starts in **~1s** and answers
   `GET /health → 200 "ok"` and `GET /status → 200 "ok"`. It is an "ACP server over HTTP and WebSocket"; it does **not**
   serve the web UI (`GET / → 404`, expected).

3. **The backend IS spawned and healthy when the surface opens.** Saw `…/GooseRuntime/goose serve --host 127.0.0.1
   --port 3284 --with-builtin developer` running and `127.0.0.1:3284 (LISTEN)`. The app's own diagnostics panel shows
   `runtime live`, `native ACP ready (1.39.0)`, `ACP http://127.0.0.1:3284`, `UI origin live: http://127.0.0.1:57755/`.
   **The readiness timeout (`listenTimeout = 20s`) is not the issue** — goose is healthy in ~1s.

4. **The web UI is served by an in-app `WorkSPAServer`** (`Epistemos/Work/WorkSPAServer.swift`, `NWListener`, ephemeral
   loopback port — observed on 57755, owned by the Epistemos process, not goose).

5. **★ THE WHITE-SCREEN CAUSE — asset hash mismatch.** Live, the WorkSPAServer served:
   - `GET / → 200 text/html` ✅ (HTML loads — that's why it's *white*, not an error page)
   - the served `index.html` references `assets/index-CA98ulTS.js` + `assets/index-2MZlLW4Q.css`
   - `GET /assets/index-CA98ulTS.js → 404` ❌ and the CSS `→ 404` ❌
   - → the SPA's JS never loads → React never mounts → **white screen.**

6. **Multiple goose-desktop copies with different hashes exist across builds**, each internally consistent on its own,
   but the *served* root combined a new `index.html` with assets that didn't contain the referenced hash:
   - `.app` bundle (isoloop build): `index → CA98ulTS`, `assets/ has CA98ulTS` ✅ (consistent)
   - App Support staging `~/Library/Application Support/Epistemos/GooseWebUI`: was `CE4sY_IY ↔ CE4sY_IY` ✅ (consistent but **older**, staged Jun-29 16:29)
   - **Served result: `index CA98ulTS` + `assets/CA98ulTS.js → 404`** ❌ ← the two got crossed.

7. **The resolver does NOT verify referenced assets resolve.** `GooseWebUIResolver` validates: index.html exists +
   manifest `acpMode:true` + bridge markers + an `assets/` dir exists (`missing-local-assets`). It does **not** check that
   the specific `<script src>` / `<link href>` hashed files in index.html actually exist. So a crossed/stale bundle
   **passes validation and gets served** instead of being rejected so a consistent copy can win.

8. **★ THE "WAITING FOR ACP" CAUSE.** `GooseWebSurfaceView.loadGooseUIWhenReady` loops, showing the placeholder until
   **both** `gooseUIReady(WorkSPAServer baseURL)` (HEAD → 200 + `text/html`) **and** `runtimeACPReady(connection)`
   (runtime health + `acpBridge.status == .connected`) are true (`GooseWebSurfaceView.swift:795-823`). Observed stuck on
   `"Goose Web UI waiting for ACP"` with `ws://127.0.0.1:3284/acp?token=…` → the **ACP WebSocket bridge isn't reaching
   `.connected`**, and/or `gooseUIReady` HEAD isn't passing.

9. **★ REBUILD CHURN is masking/compounding everything.** The running app's pid changed **three times in ~5 minutes**
   (55411 → 66776 → 67492) — build agents + the recon loop keep rebuilding and relaunching it. Each rebuild changes the
   UI asset hashes and re-desyncs the staging mid-write, so the surface never stabilizes. This is almost certainly *why*
   "it worked at first, now it's white": the first build staged consistently; later rebuilds crossed it.

---

## HYPOTHESES — ranked (what I think it is)

- **H1 (most likely): non-atomic, non-hash-gated web-UI staging.** The UI is copied/served without an atomic, content-
  hash-keyed swap, so `index.html` and `assets/` can land from different builds → 404 → white. Rebuild churn triggers it
  repeatedly. **This is the primary white-screen cause.**
- **H2: index resolved from one dir, assets served from another.** The resolver picks `index.html` from the fresh bundle
  (CA98ulTS) but the WorkSPAServer `root` / `staticRoutes` resolve assets against a stale staged dir (CE4sY_IY). Verify
  `root == resolvedIndex.deletingLastPathComponent()` and that `gooseStaticCompatibilityRoutes()` doesn't cross-wire.
- **H3: ACP WebSocket handshake never completes.** `acpBridge.status` never hits `.connected` → stuck on placeholder.
  Check the **token**: the `token=` in `ws://127.0.0.1:3284/acp?token=…` must match goose's `GOOSE_SERVER__SECRET_KEY`.
  Also check the `/acp` route is up before the bridge dials, and the WS upgrade isn't blocked.
- **H4: readiness gate deadlock / ordering.** `loadGooseUIWhenReady` requires BOTH `gooseUIReady` AND `runtimeACPReady`
  before loading the SPA. If ACP only connects *after* the SPA loads (the SPA opens the socket), this is chicken-and-egg
  and holds forever on the placeholder. Consider loading the SPA when the **UI server** is ready and letting the SPA
  establish ACP itself.

---

## FIX DIRECTIONS (do these, not a rewrite)

1. **Stage the web UI atomically + hash-gated.** Copy `index.html` + `assets/` as one unit into a content-hash-named
   dir; only flip the served-root pointer after the full copy verifies. Never serve a root whose `index.html` references
   an asset that isn't present.
2. **Tighten `GooseWebUIResolver`.** Parse `<script src>` / `<link href>` from `index.html` and verify each referenced
   file exists in the served root; **reject the candidate (fall through)** if any is missing — so it lands on a consistent
   copy instead of serving a broken one. (Add a `missing-referenced-asset:<file>` reason alongside `missing-local-assets`.)
3. **Re-derive staging from the CURRENT bundle on launch** (version/hash check), and clear stale staged dirs — so repeated
   rebuilds don't leave a crossed staging behind.
4. **Fix the ACP gate (H3/H4).** Verify token↔`GOOSE_SERVER__SECRET_KEY` parity; confirm `/acp` is accepting WS upgrades
   before the bridge connects; consider decoupling SPA-load from `acpBridge == .connected` so a slow handshake doesn't
   pin the whole surface on the placeholder.
5. **Note for testing: the rebuild churn must be paused** to get a stable repro — otherwise the staging is a moving target.

## RULED OUT (don't chase these)
- ❌ Sandbox / MAS / `EPISTEMOS_APP_STORE` gate — build is non-sandboxed, gate off.
- ❌ The goose binary — works, `/health → ok` in ~1s.
- ❌ Missing bundle — index.html + manifest (`acpMode:true`) + assets all present.
- ❌ "Old build" — fresh build, still broken.
- ❌ webview-vs-native architecture — the webview path is fine and *was* working; this is staging + ACP, not architecture.
- ❌ The existing `retry web ui render until ready` / `wait for acp before web ui render` commits — retrying re-serves the
  same 404'd JS; "wait for ACP" is exactly where it now hangs. Necessary but not sufficient.

## Reproduce / verify (commands used)
```bash
# 1. confirm the served UI's asset mismatch (PORT = the WorkSPAServer's ephemeral port, from lsof on the Epistemos pid)
APPPID=$(pgrep -x Epistemos | head -1)
PORT=$(lsof -nP -iTCP -sTCP:LISTEN -a -p $APPPID | grep -oE ':[0-9]+ ' | tr -d ': ' | head -1)
JS=$(curl -s "http://127.0.0.1:$PORT/" | grep -oE 'assets/index-[A-Za-z0-9_]+\.js' | head -1)
curl -s -o /dev/null -w "%{http_code}\n" "http://127.0.0.1:$PORT/$JS"   # 404 == the bug

# 2. confirm the backend is fine (not the problem)
curl -s http://127.0.0.1:3284/health    # -> ok

# 3. confirm index.html ↔ assets/ consistency for any goose-desktop dir
d=<goose-desktop dir>; echo "wants $(grep -oE 'index-[A-Za-z0-9_]+\.js' "$d/index.html" | head -1) ; has $(ls "$d/assets" | grep -oE 'index-[A-Za-z0-9_]+\.js' | head -1)"
```

## Key files
- `Epistemos/Goose/GooseWebSurfaceView.swift` — `loadGooseUI` (575), `loadGooseUIWhenReady` (795), `gooseUIReady` (842), `runtimeACPReady` (825)
- `Epistemos/Goose/GooseWebUIResolver.swift` — candidate resolution (88-127) + validation reasons (280-302, `missingRequiredBridgeMarkers` 385)
- `Epistemos/Work/WorkSPAServer.swift` — the `NWListener` SPA server (start 97)
- `Epistemos/Goose/GooseRuntimeSupervisor.swift` — `start` (157), `#if EPISTEMOS_APP_STORE` gate (176), `serveArguments` (441), `healthCheck` (758)
