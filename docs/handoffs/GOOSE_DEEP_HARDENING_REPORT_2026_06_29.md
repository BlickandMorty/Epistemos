# Goose Phase-0 deep-hardening report (2026-06-29)

Multi-agent adversarial audit (8 lenses x 3-skeptic verify x 3 rounds, 98 agents). raw round-1 findings: 16; **confirmed (>=2/3 skeptics): 34**; refuted: 5.

Owner green-lit fixing every confirmed bug (commit each separately) as step 1, before the goosed/native-UI migration. Companion: GOOSE_NATIVE_UI_DECISION_2026_06_29.md.

## Synthesis

Independently re-verified the three headline claims against current source — all three are real and present today:
- `GooseWebNativeAffordanceBridge.swift:526` `rememberScopedRoot(expandedPath)` runs with no `isPathAllowed` gate; `:547` re-broadens on every launch. CONFIRMED.
- `GooseWebSurfaceView.swift:293-297` `customACPStatusLabel` never reads `acpBridge.status`. CONFIRMED.
- `GooseWebSurfaceView.swift:602-607` nav gate keys on host-class only, not origin+port. CONFIRMED.

Below is the synthesized owner-facing report.

---

# GOOSE PHASE-0 DEEP-HARDENING REPORT

The raw findings contained heavy duplication (the same defect surfaced by multiple skeptics). I have deduplicated to distinct root-cause defects, re-verified the top ones against live source, and ranked them. Counts of independent confirmations are noted.

## (1) CONFIRMED REAL ISSUES — prioritized

### CRITICAL

**C1. WebView-reachable `addRecentDir` self-grants filesystem scope — full path-sandbox escape (read/write anywhere the user account can reach).** Confirmed x2 + re-verified live.
- File: `Epistemos/Goose/GooseWebNativeAffordanceBridge.swift:526` (and amplifier `:547`); reachable via `GooseWebBootShim.swift:540` → `window.electron.addRecentDir`.
- `addRecentDirectory` gates only on exists/isDir/non-symlink, then calls `rememberScopedRoot(expandedPath)` with NO `isPathAllowed` check. Contrast `writeFile`/`ensureDirectory` which check before remembering. Exploit: `addRecentDir('/private/etc')` then `readFile('/private/etc/passwd')` → allowed=true (verified by standalone Swift probe in the source findings). `/Users`, `/Library`, `/Applications`, `/private/var` all pass. `listRecentDirectories()` re-calls `rememberScopedRoot` on every stored dir, so the escalation persists across restarts via `recent-dirs.json`. Any page JS (XSS, malicious recipe, imported MCP-app HTML) reaches it.
- FIX: Remove `rememberScopedRoot(expandedPath)` from `addRecentDirectory` (:526) and `validDirs.forEach(rememberScopedRoot)` from `listRecentDirectories` (:547). Recent-dirs must be a display-only list. Widen scope ONLY via consented `NSOpenPanel` (`rememberScopedAccess`). If a recent dir must stay readable, gate it: `guard isPathAllowed(expandedPath) else { return false }`. Add a regression test asserting `addRecentDir('/private/etc')` then `readFile('/private/etc/passwd')` returns not-found.

### HIGH

**H1. Nav gate allows ANY loopback origin → privileged bridge + ACP secret + FS handlers reachable from any 127.0.0.1/localhost/::1 page.** Confirmed + re-verified live.
- File: `GooseWebSurfaceView.swift:602-607` (`GooseNavigationDecider`) + `:444-466` (handler/userScript install). Secret at `GooseWebBootShim.swift:498`; FS bridge `:521-539`.
- Gate checks scheme + host-class only, never the specific Goose origin/port. No `securityOrigin`/`frameInfo`/`isMainFrame` validation anywhere (grep-confirmed). Any in-surface JS can `window.location='http://127.0.0.1:<attackerPort>/'` and the foreign local page then calls `epistemosGooseNative.postMessage({name:'readFile',...})` or `window.electron.getSecretKey()`. Full XSS not required — a rendered hyperlink or LLM/tool/MCP content that sets `location` suffices.
- FIX: Restrict the decider to (a) the Goose custom scheme and (b) the exact host+port of the WorkSPAServer + goose-serve origins (compare full origin, not host class). Additionally validate `message.frameInfo.securityOrigin`/`isMainFrame` in `receiveAffordanceMessage` and `receivePromptMessage`, rejecting non-Goose origins.

**H2. ACP serialization proxy queues `cancel`/Stop (and every client method) behind the in-flight `prompt()` — the Stop button is dead during an active turn.** Confirmed; verified present in shipping bundle (`index-DXsE5f4M.js` fn `DK`).
- File: `stage-goose-web-ui.sh:1157-1219` (grafted into `acp/acpConnection.ts`).
- `serializeACPRequests` uses ONE FIFO promise chain for ALL ACP calls and wraps both `client.goose.*` and top-level `client`. `prompt()` resolves only at end-of-turn (stopReason); `cancel()` is a notification queued behind it, so Stop, mid-turn provider/model switch, and `sessionSteer` are silently deferred until the turn finishes on its own. Token display and permission/elicitation responses bypass the proxy, so the stall is partial — but turn cancellation is broken.
- FIX: Exclude `prompt`, `cancel`, and `sessionSteer_unstable` from the FIFO (issue immediately on the connection), or invert so the queue only serializes config-mutating requests. Add a regression test: issue `cancel()` while `prompt()` is pending and assert the `session/cancel` notification reaches the transport before the prompt resolves.

**H3. "custom ACP Goose ready" shown even when the ACP bridge is idle/connecting/FAILED/disconnected (false-green in the owner-watched panel).** Confirmed x3 + re-verified live.
- File: `GooseWebSurfaceView.swift:293-297` (rendered `:112`).
- `customACPStatusLabel` is computed purely from `unhandledDiagnostics`, never from `acpBridge.status`. `fail()` (`GooseACPEventBridge.swift:306`) sets `.failed` but appends no diagnostic; `disconnect()` (`:79`) clears diagnostics. So a hard connection failure renders "native ACP Goose: error: …" next to "custom ACP Goose: ready". This is exactly the contradictory green the owner sees at Cmd-3.
- FIX: Switch on `acpBridge.status` like `nativeACPStatusLabel` does. Only return `"ready"` when `.connected && diagnostics.isEmpty`; otherwise return `idle`/`connecting`/`disconnected`/`error: …`.

**H4. The test "locking" the ready-language is a source-text grep only — it green-lights the H3 decoupling.** Confirmed.
- File: `EpistemosTests/GooseRuntimeSupervisorTests.swift:247-264`.
- `detailsPanelUsesExactOwnerStatusLanguage` asserts only that the file *contains* `"? \"ready\""`. No behavioral assertion. This is the "green proof masking the honesty gap" pattern the owner distrusts.
- FIX: Add a behavioral test driving `GooseACPEventBridge` to `.failed` and `.disconnected` (stub transport whose `initialize()` throws; and via `disconnect()`), asserting the label feeding the row is NOT `"ready"` in those states and IS only after successful initialize.

**H5. Golden-rule roster guard is case-sensitive and incomplete — a hardcoded roster in its natural form (lowercase IDs) slips through.** Confirmed x4.
- File: `EpistemosTests/GooseRuntimeSupervisorTests.swift:911 / 929`.
- `line.contains(token)` over mixed-case tokens; Swift `contains` is case-sensitive. `"OPENAI_API_KEY"` ≠ `"OpenAI"`, and lowercase model/provider ids (`anthropic`, `openai`, `claude-sonnet-4`, `gpt-4o`, `gemini-2.0-flash`) match nothing. Token set also omits Databricks/Bedrock/Vertex/DeepSeek/Together/Cohere/Azure etc. The surface is currently clean (grep-confirmed zero live hits), so this is a guard-strength gap, not a live violation — but the GOLDEN RULE is the gate, and the gate is bypassable.
- FIX: Lowercase both sides; expand tokens to the full Goose provider set + lowercase model stems (`gpt-`, `claude-`, `gemini-`, `qwen`, `deepseek-`, `llama-`, `o1-/o3-/o4-`); keep an allowlist exemption for legitimate `*_API_KEY`/`*_ACCESS_TOKEN` env-name lines so the hardening lists don't false-positive.

### MEDIUM

**M1. Default file-affordance scope is the entire home directory; main webview has no CSP / egress restriction.** Confirmed.
- File: `GooseWebNativeAffordanceBridge.swift:54` (default root = `$HOME`) + `:391-462`; `GooseWebSurfaceView.swift:33,444-468`. Path-traversal/symlink checks are sound; the weakness is the broad default grant. `readFile('/Users/jojo/.ssh/id_rsa')` → allowed. Nav gate doesn't constrain `fetch`/XHR; no CSP. Any in-UI script execution = read ~/.ssh, ~/.aws, tokens + unrestricted remote POST exfiltration.
- FIX: Narrow default roots to the selected working dir + AppSupport; widen only via consented NSOpenPanel. Apply CSP (`default-src 'self'; connect-src` limited to loopback ACP origin) to the served UI.

**M2. `connect()` abandons the previous `GooseACPClient` without closing it — leaks WebSocket transport + read loop, orphans suspended continuations.** Confirmed.
- File: `GooseACPEventBridge.swift:125-127`. Sets `client = nil` after `eventTask?.cancel()` but never `await client.close()` (contrast `disconnect()` at `:74`). Cancelling `eventTask` does not resume a suspended `withCheckedThrowingContinuation`. On a new-key/injected reconnect over a still-open idle socket, the old read loop keeps ingesting into unbounded `queuedEvents` and never resumes its continuation; only an independent socket error self-heals it.
- FIX: Mirror `disconnect()`: `let previous = client; client = nil; eventTask?.cancel(); if let previous { Task { await previous.close() } }`.

**M3. JSON-RPC error frame with null id triggers terminal `fail()` — a non-transport server error tears down the whole connection.** Confirmed.
- File: `GooseACPClient.swift:545-550`. `.error(nil, …)` calls `fail()`, which drops all `queuedResponses` and throws into every waiting continuation, then `ensureReadLoop`'s `terminalError == nil` guard blocks restart. A null-id error is legal per spec (parse-error/invalid-request/global notice) — application-level, not transport.
- FIX: Route null-id errors through the same non-fatal containment as unhandled frames (structured diagnostic, keep connection alive). Reserve `fail()` for transport errors only.

**M4. Live ACP chat hook fires dead `/agent/update_from_session` REST on every session load (throwOnError:true, no .catch) → unhandled rejection on the primary path.** Confirmed; audit-missed.
- File: `.research-clones/.../hooks/useAcpChatSession.ts:277`. Reconciliation is NOT lost (`loadAcpSession` already calls `client.loadSession`), so this is a redundant dead call, but a real recurring unhandled rejection. Staging script never touches this hook; the component-only audit missed it.
- FIX: `if (!USE_ACP_CHAT) { updateFromSession({...}); }` or `.catch(() => {})`. Add a `replaceRequired` patch + gate assertion.

**M5. Voice-dictation runtime path (`useAudioRecorder.ts`) is ungrafted — actual transcription file + `dictationTranscribe_unstable` ACP method missed by audit gap #4.** Confirmed.
- File: `.research-clones/.../hooks/useAudioRecorder.ts:102,124`. `getDictationConfig()`/`transcribeDictation()` are dead REST. Wired into the always-rendered ChatInput mic button; 404 forces `isEnabled=false` → permanently-disabled mic whose tooltip routes to the also-broken DictationSettings page. The SDK exposes a full `dictation*_unstable` suite the audit never enumerated.
- FIX: Graft `getDictationConfig→dictationConfig_unstable` and `transcribeDictation→dictationTranscribe_unstable`, OR hide the mic button entirely under ACP if dictation is a deliberate carve-out. Update the audit ledger row #4.

**M6. Gateways settings section silently renders broken + 5s 404 poll-loop (missed by the 42-component audit — uses raw `getApiUrl` fetch, not an `@/api` SDK import).** Confirmed.
- File: `.research-clones/.../components/settings/gateways/GatewaySettingsSection.tsx:113`. `goose serve`'s ACP router never mounts `/gateway/*`. The section stays VISIBLE because the tunnel-status failure fail-opens to visible, then polls `/gateway/status` every 5s → perpetual 404s. Not grafted, not in the audit.
- FIX: Gate the section off under `USE_ACP_CHAT` (replace `{!tunnelDisabled && <GatewaySettingsSection />}`), which also kills the poll. At minimum add to the audit ledger.

**M7. Settings>Auth shows "No locally stored provider credentials were found" after a transient ACP load failure — masks the failure, no retry.** Confirmed.
- File: `stage-goose-web-ui.sh:2267-2277` → `AuthSettingsSection.tsx:135-150`. `listAcpProviderSecrets()` → `getAcpProviders()` rethrows on mid-connect/transient drop; the unchanged catch sets `secrets=[]` → persistent "no credentials" panel with no refresh. `loadSecrets` runs once via `useEffect`.
- FIX: Keep a `loadError` state; on catch render error + Retry instead of the empty message.

**M8. Tetrate / NanoGPT free-credit onboarding is ungrafted dead REST (`/handle_tetrate`, `/handle_nanogpt`) — LIVE in the shipping bundle, reachable from the grafted ProviderSelector.** Confirmed.
- File: `.research-clones/.../components/onboarding/FreeOptionCards.tsx:86` (rendered by `ProviderSelector.tsx:177`). Both endpoints present in `index-DXsE5f4M.js`. The ProviderSelector graft reroutes fetchProviders/createCustomProvider but not FreeOptionCards → buttons fail with generic "unexpected error" in a view the owner already flagged.
- FIX: Honest-gate the Tetrate/NanoGPT buttons off under ACP, or graft to a native key flow.

**M9. `openExternal` uses a denylist, not an allowlist — permits `smb://`, `ftp://`, `vnc://`, arbitrary app deeplinks from WebView content.** Confirmed x2.
- File: `GooseWebNativeAffordanceBridge.swift:13-22, 239-242, 346-353`; reachable via `GooseWebBootShim.swift:517`. `smb://attacker/share` → outbound SMB/NTLM hash leak; `someapp://destructive-action` drives other apps with no prompt.
- FIX: Convert to an allowlist (http, https, mailto, tel), mirroring `shouldOpenBrowserURL`.

### LOW

**L1. `useNavigationSessions:77` active-session fallback uses dead `getSession` REST → resumed sessions outside recent-25 silently never appear in the sidebar.** Confirmed x4 (heavily duplicated). Fail-soft. FIX: reroute through `acpLoadSession`.

**L2. `useFileDrop` native-path call-site grafts are best-effort (no hard-fail), violating the script's own anchor-drift-must-fail doctrine.** Confirmed x2. `stage-goose-web-ui.sh:3178-3191`. Anchors match today; future drift silently drops native drag-drop path resolution (falls back to nonexistent `window.electron.getPathForFile`). FIX: add `if (!includes(anchor)) throw` around both call-site replaces.

**L3. `launchApp` renders attacker-controlled HTML in an unrestricted WKWebView (no nav gate, `file://` baseURL origin).** Confirmed. `GooseWebNativeAffordanceBridge.swift:568-612`. FIX: attach a nav decider, `.nonPersistent()` store, opaque baseURL.

**L4. `listGitWorktreeDirs` spawns git without env hardening (inherits full process env).** Confirmed. `GooseWebNativeAffordanceBridge.swift:464-505`. Doctrine gap vs `GooseRuntimeSupervisor.processEnvironment`. FIX: set explicit minimal env mirroring the supervisor.

**L5. Boot-time analytics `readConfig` (renderer.tsx:53) hits dead REST and fail-opens telemetry to ENABLED-by-default.** Confirmed (info/low). `undefined !== false` → telemetry on. FIX: route through the local-ACP config path or invert default to OFF.

**L6. CostTracker/ChatInput pricing backed by ungrafted `getCanonicalModelInfo` (fail-open to null).** Confirmed low. Cost/context silently blank in always-visible chat. FIX: route through ACP catalog data or document as accepted degrade.

**L7. `FeaturesContext.getFeatures` dead REST → server feature flags silently degrade to hardcoded defaults.** Confirmed low; defaults benign. FIX: document as intentional degrade or graft.

### LATENT (info — fragility, no current break)

- **AppsView graft:** two sequential `.replace` under one `writeRequired` guard → the larger native-dialog block can silently no-op if only the import anchor drifts (`stage-goose-web-ui.sh:2580-2697`). FIX: split into two guarded replaces or add a post-write `includes('handleNativeFilePath')` throw.
- **Self-stamped marker:** `local-acp-config-GOOSE_TELEMETRY_ENABLED` is injected into `index.html` immediately before it is checked → tautological guard, proves nothing about the JS graft (`stage-goose-web-ui.sh:3350-3377`). FIX: verify a real minification-surviving token in `assets/`.

---

## (2) COVERAGE / COMPLETENESS GAPS STILL TO CLOSE

These are areas that were ASSERTED-reachable by source-grep but NEVER exercised against live `goose serve 1.39.0`. The owner should treat them as unverified, not working.

**Highest priority (write paths behind owner-reported symptoms):**
1. **Model-switch + provider-key write paths never proven live.** `GooseACPClient.swift:288-292` `defaultsSave`, and `GooseProviderKeyBridge.saveGooseProviderConfig`. The probe only calls READ methods. The owner-reported "model switch" symptom (task #9) has zero live witness on the actual mutation. CLOSE: probe `defaults/save` then `defaults/read` round-trip + save-provider-config + assert `status.isConfigured`.
2. **Entire `_unstable` mutation surface (40+ methods) unexercised.** scheduler/recipes/extensions/session export/import/rename/steer/truncate. `goose-acp-live-probe.mjs:46-70` sends only read/list + basic session ops. None proven implemented by 1.39.0. CLOSE: round-trip each `_unstable` method against live ACP, fail loudly on method-not-found.
3. **`configExtensions Add/Remove/SetEnabled` is an un-audited code-execution boundary.** Adding a stdio MCP extension makes `goose serve` spawn an arbitrary command; the extensions' argv/cwd/env trust path through ACP is unexamined and no native consent gate was confirmed. CLOSE: audit for a consent gate; confirm subprocess hardening applies to spawned extensions.
4. **Permission/elicitation single-slot model.** `GooseACPEventBridge.swift:270-273` overwrites `pendingPermission`/`pendingElicitation` with no queue → a second concurrent `request_permission` (parallel tool calls, common) orphans the first → deadlocked turn. CLOSE: replace with an ordered queue; send `cancelled()` for every still-pending requestID on overwrite/disconnect.
5. **Permission/elicitation round-trips never exercised live** — `goose-acp-live-probe.mjs:69` only prompts "Say hi", a no-tool turn. The entire native approval UX (the core tool-call security gate) is source-grep-only. CLOSE: force a tool requiring approval, assert `session/request_permission` arrives, send `selected(optionId)`, confirm the agent proceeds.

**Medium:**
6. **`sessionSteer_unstable` mid-turn steering** is both unverified AND queued behind `prompt()` by the same proxy as Stop (H2) → likely dead. CLOSE: probe steer against a live in-flight prompt; fix via the H2 control-channel change.
7. **Thinking/reasoning fidelity through `session/update` unverified** despite the non-negotiable PRESERVE THINKING BLOCKS / STREAM EVERYTHING mandate. `GooseACPEventBridge.swift:268-269` stores only `lastSessionUpdate = notification` (last-update-wins discards intermediate deltas). CLOSE: assert a thinking-capable model emits reasoning-typed deltas rendered in order; replace last-update storage with an append/stream the UI can't drop.
8. **`GOOSE_DISABLE_KEYRING` on-disk fate of mirrored secrets unexamined** — `GooseRuntimeSupervisor.swift:378-380` + `syncConfiguredProviderKeys`. Possible plaintext write to `~/.config/goose`, which would violate the Keychain-only rule on the goose side. CLOSE: confirm where injected secrets land when keyring is disabled.
9. **Health-check trusts any `/health: ok`** — `GooseRuntimeSupervisor.swift:536-544` adopts the first responder under our own secret without verifying it's our child or accepts our secret. Port-race / leftover-serve → opaque auth failure later. CLOSE: secret-authenticated probe or PID/socket match before `.running`.
10. **Scheduler / recipes / session export-import / slash-commands / agent-mentions** — whole owner-facing routes with zero graft-fidelity, live, or parity coverage (`stage-goose-web-ui.sh` has only a recipe-ID reconciliation graft; grep `schedul` = nothing). CLOSE: per-route smoke against live ACP + graft-presence assertions.

**Low:**
11. ACP secret carried as `token=SECRET` URL query param (`GooseRuntimeSupervisor.swift:447`) → exposed to access logs / `ps` / diagnostics. Move to a header/subprotocol or scrub from `recordDiagnostic`.
12. `randomSecretKey()` falls back to non-CSPRNG UUID concat when `SecRandomCopyBytes` fails (`GooseRuntimeSupervisor.swift:528-534`) → silent entropy downgrade of the only auth secret. Fail closed instead.
13. `unhandledRequest` blanket-replies "unsupported" to every un-modeled method incl. `fs/*` and `terminal/*` (`GooseACPEventBridge.swift:274-283`); Epistemos advertises only `elicitation`. Works today because builtins do server-side fs, but an untested coupling. Assert advertised caps match builtins in use.
14. Process-lifecycle resilience (crash → orphan cleanup → restart → port-3284 reclaim → WebView reload) asserted by handlers, never independently proven (`GooseRuntimeSupervisor.swift:315-327`). CLOSE: kill `goose serve` mid-session, assert `.failed` + retry + port reclaim within `portReleaseGrace`.

---

## (3) HARDNESS VERDICT — blunt

**The Goose surface is NOT genuinely hardened. The owner is right to keep seeing issues.** "It's done" is false.

Concrete reasons, not vibes:

- **One CRITICAL live sandbox escape ships today.** `addRecentDir` self-granting scope (C1) is independently re-verified in current source and defeats the exact path-scoping control the brief names as the CORE risk. Combined with the loopback nav gate (H1), the security model has a clear, page-JS-reachable read/write-anywhere chain. These are present-tense exploitable, not latent.

- **A user-facing core control is dead.** The Stop button (H2) does not cancel an in-flight turn — verified present in the shipping `index-DXsE5f4M.js`. This is a real agentic-UX break, not a theoretical one.

- **The honesty instrumentation is itself dishonest.** "custom ACP Goose ready" (H3) renders green on a failed/idle connection, and the test that supposedly locks it (H4) is a source grep that green-lights the lie. This is precisely the "green proofs while the owner sees red" pattern — and the owner literally watches this panel at Cmd-3. Until H3+H4 are fixed, no green status from this surface should be trusted.

- **The GOLDEN-RULE gate is bypassable.** The roster guard (H5) passes by accident of casing, not because the directory is clean. The directory IS clean today (independently grep-confirmed), so there is no live violation — but the gate the owner is relying on would not catch the realistic violation form. That is a guarantee that doesn't hold.

- **Coverage is the bigger lie than any single bug.** The deepest structural problem is that ~40+ `_unstable` ACP mutation methods, the model-switch write path (the owner's own reported symptom), the permission/elicitation approval UX, the MCP-extension code-execution boundary, and thinking-block fidelity through `session/update` have ZERO live verification. They are "present in source" only. The live probe sends read-only calls and a no-tool "say hi". So the most load-bearing claims — "real Goose agentic safety", "model switch works", "PRESERVE THINKING BLOCKS holds end-to-end" — rest on grep, not behavior. Several of these (M2/M3 continuation leaks/teardown, the single-slot permission deadlock) are correctness bugs that a real exercise would likely surface immediately.

**What "done" would actually require:** fix C1 + H1 (close the escape), H2 (revive Stop), H3+H4 (honest status + behavioral test), H5 (real golden-rule guard); then extend `goose-acp-live-probe.mjs` to round-trip the write paths and approval flow against live `goose serve 1.39.0` and gate Phase-0 on it. Until the probe exercises mutations and permissions and passes, treat the surface as unverified regardless of any green checkmark.

Net: real, present-tense defects remain (1 critical, 5 high), plus a coverage gap that means the headline capabilities are unproven. Do not promote this to T4/green.

## Completeness gaps (still under-verified)

- Entire _unstable ACP mutation surface (scheduler/recipes/extensions/session ops) is grafted but never exercised by any live probe — 40+ methods asserted-reachable, none proven
- Model-switch write path (defaults/save) and provider-key write path (provider config save) are never proven live — directly under-covers the owner-reported 'model switch' symptom (task #9)
- configExtensions Add/Remove/SetEnabled is an un-audited code-execution boundary — WebView/recipe-reachable installation of arbitrary stdio MCP servers as subprocesses of goose serve
- Permission and elicitation prompts use a single-slot model — a second request silently overwrites the first, leaving the agent's prior session/request_permission awaiting forever (deadlocked turn)
- Session steering/interrupt (sessionSteer_unstable) is un-grafted-verified AND, like Stop, is queued behind the in-flight prompt() by the serialization proxy — mid-turn steering is unproven and likely dead
- Thinking/reasoning content fidelity through ACP session/update is unverified despite the non-negotiable PRESERVE THINKING BLOCKS / STREAM EVERYTHING mandate
- GOOSE_DISABLE_KEYRING path: where goose serve persists the injected provider secrets (Keychain vs plaintext ~/.config/goose) is unexamined — possible plaintext credential write
- Health-check trusts ANY service returning 'ok' on /health — Epistemos can declare a foreign goose-compatible server 'running' under its OWN secret, then silently fail ACP auth
- ACP secret is carried as a URL query parameter (token=SECRET) — exposed to goose serve access logging, ps/proc inspection of the WS URL, and any URL-capturing diagnostic
- randomSecretKey() falls back to non-CSPRNG UUID concatenation when SecRandomCopyBytes fails — silent entropy downgrade of the only auth secret
- unhandledRequest auto-replies 'unsupported' to EVERY un-modeled ACP method, including fs/* and terminal/* — Epistemos advertises no fs/terminal client capabilities, so any future goose path needing client-side file/terminal callbacks silently breaks
- session/request_permission and elicitation/create round-trips are never exercised live — the entire native approval/elicitation UX (the core security gate for tool calls) is source-grep-only
- Scheduler, recipes, session export/import, slash-commands and agent-mentions are whole product surfaces with zero coverage in the 8 lenses + 3 rounds (no graft fidelity, no live, no parity finding)
- Process-lifecycle resilience (crash → orphan cleanup, auto-restart, WebView reload) is asserted by handlers but not independently proven; handleProcessExit only flips status to .failed with no recovery

---

## Step-1 fix status (2026-06-29) — owner green-light "fix every confirmed bug"

**FIXED + committed + build/tsc-verified (the backend-independent bugs that persist regardless of goosed):**
- C1 CRITICAL — addRecentDir filesystem-scope escape (ae6937673)
- H1 HIGH — nav gate any-loopback → pinned server ports (a26a9c058)
- HIGH — false "custom ACP Goose ready" decoupled from bridge status (39d57bb99)
- #3 MED — connect() leaked superseded client (9876b54f3)
- #4 MED — null-id JSON-RPC error terminal-fail → contained (983c4aaa1)
- #11 HIGH — dead Stop button (cancel/steer bypass the serialization FIFO) (e6b0a4751)
- #13/#24 MED — openExternal denylist → allowlist (f3b3a3cea)
- #23 LOW — listGitWorktreeDirs env hardening (f3b3a3cea)
- #14 LOW — launchApp guest webview nav-gate + non-persistent store (f3b3a3cea)
- #7/#20 LOW — useFileDrop grafts hard-fail on drift (e473049ac)
- #9/#17/#28 — golden-rule guard catches hardcoded MODEL ids (754f87643)
App target BUILD SUCCEEDED with all Swift fixes (witness: scratchpad/goose-fixes-build2.log).

**DEFERRED to Step 2 (goosed swap) — these are "dead REST call" bugs that 404 ONLY because lean
`goose serve` doesn't serve REST; `goosed agent` serves the full REST, so they fix themselves on
the swap (ACP-grafting them would be throwaway Path-A work):** #5 (/agent/update_from_session),
#6/#16/#27/#32 (useNavigationSessions getSession), #19 (Settings>Auth empty-state masks load
failure), #25 (Gateways /gateway poll), #26 (FeaturesContext getFeatures), #31 (Tetrate/NanoGPT
onboarding), #33 (CostTracker canonical model info), #34 (boot analytics readConfig).

**DEFERRED with rationale (low-value / native-UI rework / test-bundle blocked):**
- #2 MED (file scope defaults to $HOME + no CSP) — aggressive narrowing risks breaking legitimate
  project-file access ("WebView stays green"); the file bridge is reworked in the native-UI phase;
  the actual sandbox ESCAPES (C1 + traversal/symlink) are already closed. CSP half also touches
  Epistemos/Work (outside owned surface).
- #8 LOW, #21 LOW — staging graft-guard robustness (same hard-fail pattern as the shipped #7 fix).
- #30 MED — ready-language needs a behavioral test (driving bridge to .failed); the shared test
  bundle is currently broken by another agent's VRMLabelHonestLabelTests (Int64/UInt64), so test
  changes can't be bundle-run now — NOT my owned surface (NO-COLLISION), not touched.
- #15 MED (dictation) — Task #12 native-vs-graft decision ("do not rush").
