# Goose Phase 0 — Thermonuclear Findings (2026-06-28)

Source: multi-agent thermo-nuclear + correctness/honesty/edge-case review of the Goose
surface (`Epistemos/Goose/*`, the 6 Phase-0 diff files, `stage-goose-web-ui.sh`),
adversarially verified. 41 agents.

- Raw findings: 36  | Confirmed: 30  | Rejected (misreads): 5
- Fixed in the 2026-06-28 Claude hardening batch: 7 + finding [2] (restart race) + finding [11] executed path (cwd binary #if DEBUG guard), both closed in the PM parity pass
- Deferred (documented backlog): 22 (incl. finding [11]'s non-executed remainder — GooseWebUIResolver/Electron cwd paths)

All boundaries respected: GOLDEN RULE intact, working WebView/ACP path preserved,
no editor/Plan-3/vendor files touched, deletions (if any) committed separately.


---
## FIXED in 2026-06-28 Claude batch


### [1] P2 · edge-case · `GooseACPClient.swift`:460-468, 532-554, 595-616

**Issue:** A single decode failure on ANY incoming notification/request tears down the entire ACP connection. In the read loop, `try await self.ingest(message)` calls `event(from:)`, which does `try params.decoded(GooseACPSessionNotification.self)` / `GooseACPRequestPermissionRequest` / `GooseACPCreateElicitationRequest`. These are typed shapes that throw on a missing/mismatched field (e.g. a `user_message_chunk` without `content`, a `session/update` without `sessionId`, or a `session/request_permission` with an unexpected option shape). Any such throw propagates out of `ingest`, is caught by the read loop's `catch`, calls `fail(error)`, and returns -- permanently killing the read loop and failing ever

**Action:** Fix it with the scoped containment. Wrap the typed payload decode inside event(from:)/ingest so a decode failure on a known notification or server request yields a contained .unhandledNotification/.unhandledRequest-style diagnostic and, for requests, an immediate structured JSON-RPC error response (prefer -32602 invalid params over -32601 since the method WAS recognized), then `continue` the read loop. Keep terminal fail() reserved for transport.receive() errors, closed connection, and the outer GooseACPIncomingMessage frame parse at line 460. Files: Epistemos/Goose/GooseACPClient.swift (ingest 532-554, event 595-616, read loop 454-468) and the typed shapes in Epistemos/Goose/GooseACPProtoco

*(fix_is_safe=True)*

### [2] P2 · edge-case · `GooseACPEventBridge.swift`:117-189, 252-254

**Issue:** Reconnect is broken in two compounding ways. (1) The `for attempt in 1...attempts` budget in `runConnection` is shared between the initial handshake retries AND every post-connection reconnect: a successful `markConnected` does NOT reset the counter, and a mid-session websocket drop falls into the same `catch`, consuming attempts. So a long-lived connection that survives 6 transient drops over its lifetime (URL path passes initialHandshakeAttempts: 6) exhausts the budget and then `fail()`s permanently, even though each drop was individually recoverable. (2) On terminal failure `fail()` only sets `status = .failed`; it never clears `connectionKey`. Because `connect(key:)` early-returns on `gu

**Action:** Fix as a targeted edit to GooseACPEventBridge.swift. (a) Separate the initial-handshake budget from the lifetime reconnect budget: after markConnected, treat subsequent socket drops with their own bounded retry-with-backoff burst rather than continuing to consume the original attempt counter (e.g. convert the `for attempt in 1...attempts` to a `var attempt` loop that resets to 0 once markConnected succeeds, or wrap the post-connect run in an inner bounded reconnect loop with the existing retryDelayNanoseconds backoff to avoid a tight spin). (b) Allow same-url re-establishment after terminal failure by clearing connectionKey (set connectionKey=nil) — preferably scoped to the terminal connecti

*(fix_is_safe=True)*

### [3] P3 · security · `GooseWebSurfaceView.swift`:584-603 (specifically 591)

**Issue:** GooseNavigationDecider allows the `file:` scheme for main-frame navigations in the trusted Goose surface. The surface only ever loads its UI via the custom scheme (`surfaceURL`) and the loopback http server (`loopbackURL`), plus `about:` for `page.load(html:)`; there is no legitimate `file://` load. Because the WebPage config injects the boot shim + the affordance/prompt bridges into every main-frame document at documentStart, an in-page link or agent-rendered link to `file:///...` would both render arbitrary local file contents inside the surface and run the privileged native bridges against a file origin. `file` is the odd one out among the allowed schemes and is an unnecessary local-file-

**Action:** Apply the suggested fix: remove `file` from the allow-list case at line 591 so it reads `case "about", GooseWebSurfaceView.gooseUISchemeName: return .allow`, leaving the loopback http/https/ws/wss-to-127.0.0.1/localhost/::1 case and the default .cancel unchanged. This is a safe defense-in-depth narrowing with no impact on any working load path. Optionally add a brief comment noting that no legitimate flow loads file:// so the scheme is intentionally not permitted.

*(fix_is_safe=True)*

### [4] P3 · edge-case · `GooseWebSurfaceView.swift`:328-352, 426-428 (and onDisappear 66-72 for contrast)

**Issue:** Stale native prompt overlay survives runtime failure / restart / placeholder. handleRuntimeStatusChange(.failed/.unavailable), restartSurface(), and loadGooseUI's failure branches all disconnect acpBridge (which clears its pending permission/elicitation) and call loadPlaceholder(), but none call nativePromptBridge.cancelPendingPrompts(). Only onDisappear clears the native prompt bridge. So if the web UI raised a permission/elicitation via window.epistemos.goose.requestPermission and goose then dies or is restarted, the page is reloaded/replaced but the SwiftUI overlay (driven by nativePromptBridge.pendingPermission/pendingElicitation, checked first in nativeACPOverlay) keeps showing an orpha

**Action:** Apply the fix at the two accurately-cited sites and the matching loadWhenReady failed branch: add nativePromptBridge.cancelPendingPrompts() alongside the existing acpBridge.disconnect()/loadPlaceholder() in restartSurface() (328-338), in handleRuntimeStatusChange's .failed/.unavailable case (340-352), and in loadWhenReady's .unavailable/.failed branch (361-364). It is a no-op when no native prompt is held, so it is safe to add unconditionally. Optionally mirror it in loadGooseUI's placeholder fallbacks for full symmetry, but those are lower priority.

*(fix_is_safe=True)*

### [5] P3 · edge-case · `GooseACPEventBridge.swift`:148-189

**Issue:** ACP reconnect budget conflates initial-handshake retries with lifetime reconnects. runConnection uses `for attempt in 1...attempts` (attempts=6 for the url-based connect). A successful initialize does not reset the counter; when the receive loop's receiveEvent() throws because the socket dropped (goose flapped while still passing the HTTP health check), the catch falls back into the SAME loop and consumes an attempt. After 6 cumulative drop/reconnect cycles over the connection's lifetime — even though each reconnect succeeded — the bridge permanently fail()s and stops listening, killing native overlays/diagnostics without surfacing a recoverable state. (In the normal goose-restart flow the s

**Action:** Restructure runConnection so the bounded initial-handshake retry is separate from post-connect reconnects. Concretely: wrap an outer reconnect loop around (bounded-handshake-with `initialHandshakeAttempts` budget) + (receive loop); when receiveEvent() throws after a successful initialize, break back to the outer loop and re-run the bounded handshake afresh (resetting the budget) instead of drawing down the same counter, keeping the retryDelayNanoseconds backoff and the .connecting status between reconnects. This preserves the existing initial-handshake retry test behavior, keeps transient WS flaps recoverable, and still lets the supervisor's HTTP health monitor bound the truly-dead case. Kee

*(fix_is_safe=True)*

### [6] P3 · edge-case · `GooseWebSurfaceView.swift`:354-370, 520-534

**Issue:** loadWhenReady and loadGooseUIWhenReady ignore Task cancellation. Both poll supervisor/server status in a fixed-count loop using `try? await Task.sleep(...)`, which swallows CancellationError. When the owning `.task` is cancelled (view disappears) and supervisor.stop() sets status to .stopped (the `default` branch), the sleeps return immediately, so the loop busy-spins through all iterations (260 / 80) with no real delay and can still call connectNativeACP / loadGooseUI / loadPlaceholder against a torn-down surface. The fixed iteration counts (260 ≈ 26s, 80 ≈ 6.4s) are also undocumented magic.

**Action:** Add `guard !Task.isCancelled else { return }` at the top of both loop bodies (loadWhenReady ~line 355 and loadGooseUIWhenReady ~line 521) so cancellation exits promptly instead of busy-spinning and doing post-teardown work; this also prevents reaching the `.running` branch (and starting an orphaned WorkSPAServer) after onDisappear. Optionally hoist 260 and 80 (and the 100ms/80ms sleeps) into named constants documenting the ~26s / ~6.4s timeouts. Leave the happy path untouched.

*(fix_is_safe=True)*

---
## DEFERRED backlog (with rationale)

Not fixed this pass to keep the regression surface small and respect the
'preserve the working path / deletion last-resort / no risky refactor of untouched
1000-line files' constraints. Each is a candidate for a later hardening loop.


### [1] P2 · maintainability · `GooseWebNativeAffordanceBridge.swift`:648-671

**Issue:** Embedded surface mutates host-app-global chrome. setMenuBarIcon calls the app-wide StatusBar.shared.setup()/remove() (Epistemos/App/StatusBar.swift) and setDockIcon calls NSApp.setActivationPolicy(.regular/.accessory) — the same global activation policy EpistemosApp itself manages (EpistemosApp.swift:361,468). These affordances make sense for standalone Goose Electron, but here a single embedded Goose WebView toggling 'show dock icon' off removes the entire Epistemos app's dock presence (and can flip it to .accessory), and setMenuBarIcon drives the host status bar. This is logic in the wrong layer / boundary muddiness: a sub-surface controlling host-app-wide window/dock/menubar state.

**Action:** Confirm as a real P2 boundary/maintainability finding. Preferred fix: scope these two affordances behind a host-provided policy object injected into GooseWebNativeAffordanceBridge that decides whether the embedded Goose surface may mutate global app chrome; default to persist-the-preference-only (no host chrome mutation), mirroring the existing nullAffordance/falseAffordance neutering already applied to setWindowTitle and getIsFullScreen in GooseWebBootShim.swift. This also removes the dual-owner conflict on NSApp.setActivationPolicy with EpistemosApp/AppStoreFirstWindowPresenter (EpistemosApp.swift:361,468). Do not alter the WebView/ACP path. Relevant files: /Users/jojo/Downloads/Epistemos/

*(fix_is_safe=True)*

### [2] P2 · edge-case · `GooseRuntimeSupervisor.swift`:183-187 — ✅ FIXED (2026-06-28 PM)

**RESOLVED this session** exactly per the recommended approach. `run()` (now
`GooseRuntimeSupervisor.swift:208-228`) no longer fails immediately when the
pre-launch `healthCheck` finds the port up: it polls a bounded grace window
(`portReleaseGrace = 2s`, 100 ms cadence reused from `waitForReady`) for the port
to go DOWN, and only declares `occupiedPortMessage` if it stays up the whole
window. A real foreign Goose-compatible occupant never releases, so genuine
foreign-occupant detection is preserved; a user-initiated restart's own
just-terminated `goose serve` releases within the window and the new process
launches. Behavior-preserving, confined to `GooseRuntimeSupervisor.swift`.
Covered by two tests: `supervisorRefusesStaleHealthEndpoint` (foreign occupant
stays up → still fails) and `supervisorToleratesPortReleaseWithinGraceWindow`
(port releases in-window → launches). This directly removes a spurious
"Port 3284 already has a running Goose-compatible service" failure on normal
restart — a likely contributor to the owner-reported intermittent restart/ACP
flakiness.

**Issue (original):** Restart race against port release. `run()` does a pre-launch `if await healthCheck(defaultBaseURL) { status = .failed(occupiedPortMessage) }`. But `stop()`/`terminateTrackedProcess` only sends SIGTERM (force SIGKILL is deferred 500ms in OrphanSubprocessCleanup) and returns synchronously. `GooseWebSurfaceView.restartSurface()` calls `supervisor.stop()` immediately followed by `supervisor.start(...)`. The just-killed previous `goose serve` is frequently still bound to 3284 when the new `run()` probes it, so a normal user-initiated restart spuriously fails with "Port 3284 already has a running Goose-compatible service." The same fixed-port design (always `defaultPort`, no fallback) also makes a

**Action:** Fix the self-restart race in GooseRuntimeSupervisor.run() before the occupied-port declaration, using a behavior-preserving, low-risk approach confined to GooseRuntimeSupervisor.swift. Preferred: record the PID being terminated in stop()/terminateTrackedProcess, and in run() — when the pre-launch healthCheck reports the port up — poll for a bounded window (e.g. up to ~1-2s, reusing the 100ms cadence already in waitForReady) for the port to go DOWN and/or for that prior PID to be confirmed exited (kill(pid,0) != 0); only declare occupiedPortMessage if it is still up after the window. This keeps foreign-occupant detection intact (a real foreign goose stays up the whole window and still fails) 

*(fix_is_safe=True)*

### [3] P2 · edge-case · `GooseCustomCapabilityLiveIntegrationTests.swift`:91-96, 266-301

**Issue:** Recipe-id reconciliation is the entire point of this diff, yet the test that proves it can pass vacuously. `canonicalRecipeID` tries a file_path match, then a fileName+title match, and on miss silently `return savedId` (line 301). Nothing downstream asserts that the list-match path actually fired: there is no guard that `recipeList` was non-empty, that it contained the saved file_path, or that `recipe_resolved_id` was found in the list rather than echoed from the save response. If Goose changes the list entry shape (file_path/recipe.title), or the `/private/var` normalization drifts, the matcher silently falls back to savedId and the test still goes green — proving nothing about reconciliati

**Action:** Adopt the fix in the test only. Make canonicalRecipeID signal which path resolved the id (e.g. return a (resolvedId, MatchKind) where MatchKind is .byPath/.byName/.fallback), then `guard` in the test that MatchKind != .fallback and throw GooseLiveIntegrationError.runtimeFailed on fallback. Additionally guard that recipeList.recipes is non-empty and contains an entry whose normalized file_path equals the saved one before relying on the resolved id. Keep it scoped to EpistemosTests/GooseCustomCapabilityLiveIntegrationTests.swift; no production or boundary-protected files are involved.

*(fix_is_safe=True)*

### [4] P2 · drift · `stage-goose-web-ui.sh`:1528-1556, 1590-1592, 1425-1443 — ✅ FIXED (2026-06-28 PM)

**RESOLVED.** All five silent `if (source.includes(anchor)) { replace }` branches
converted to the file's idempotency-guarded hard-fail discipline (marker
`epistemos-acp-graft-hardfail`): DefaultSubmitHandler readConfig + getProviderModels,
ProviderConfigurationModal OAuth + delete-cleanup, ProviderConfigForm onboarding
OAuth. Upstream anchor drift now throws at stage time instead of silently reverting
the control to its dead-in-ACP REST endpoint. Behavior-preserving on GREEN
(`EPISTEMOS_GOOSE_UI_VALIDATE_*` exit 0 — all five anchors still match real
upstream — re-staged to App Support end-to-end). Locked by the parity gate (+6
assertions). Commit `9f9372dda`.



**Issue:** Several ACP grafts use the silent pattern `if (source.includes(anchor)) { source = source.replace(...) }` with NO throw and NO post-build marker check, unlike the rest of the file which hard-fails on a missing anchor. Affected: ProviderConfigurationModal OAuth branch (1528) and provider-delete cleanup branch (1554), onboarding ProviderConfigForm OAuth branch (1590), and DefaultSubmitHandler readConfig/getProviderModels branches (1425/1441). If upstream Goose reformats any of those anchors, the build still succeeds and validation still passes, but the ACP branch is silently dropped and the code reverts to REST endpoints (configureProviderOauth / cleanupProviderCache / readConfig / getProvider

**Action:** Convert the five silent branches (1425, 1441, 1528, 1554, 1590) to the file's hard-fail discipline by mirroring the idempotency-guarded throw pattern already used two lines away (1398-1403 / replaceRequired): wrap each with `if (!source.includes('<replacement-marker>')) { if (!source.includes(anchor)) throw new Error('...anchor not found'); source = source.replace(...); }` so upstream anchor drift fails the build loudly instead of silently reverting to ACP-unavailable REST endpoints. This is the primary, complete fix and is behavior-preserving on the current GREEN path. Secondarily, optionally add authenticateAcpProviderConfig and deleteAcpProviderConfig to the post-build required_marker gre

*(fix_is_safe=True)*

### [5] P2 · edge-case · `stage-goose-web-ui.sh`:442-498, 471, 500-533 — ⚠️ VERIFIED, fix DEFERRED (recommended fix is redundant; owner-critical surface)

**Re-analyzed 2026-06-28 PM — the recommended fix does NOT apply.** Verified the
actual model path: `listAcpProviderModels(p.name)` already reads Goose's REGISTRY
inventory (`providersList_unstable({providerIds:[p.name]})`) with a
`providersSupportedModelsList_unstable` fallback — it does NOT contact the
provider's endpoint, so it throws only on an ACP-CONNECTION failure, never on an
"unreachable provider endpoint" as the finding assumed. Therefore the finding's
"lowest-risk" fix (lazily re-fetch `providersList_unstable` in the modelInterface
catch when `epistemosKnownModelFallback(p)` is empty) is REDUNDANT: that exact call
already ran in `listAcpProviderModels` and a re-fetch fails identically. The empty
catalog `known_models` (entries past the 8-template cap) only matter as a
LAST-RESORT fallback when ACP is globally broken (both inventory + supported-models
calls fail) — a degraded state where a cached catalog roster could in principle
help, but only via the heavier alternative (merge the one-shot `providersList`
inventory into the catalog surface, with the timing/cache nuance the finding
itself flags). DEFERRED: the model picker is the owner's #1 surface and currently
GREEN (live catalog/inventory/model suites pass); the broken-ACP fallback path is
not unit-testable without a controlled ACP-failure mock. Do NOT apply the
redundant fix. A real fix needs a designed ACP-failure harness first.



**Issue:** loadProviderCatalogSurface enriches only the first 8 catalog entries with template details (`catalogEntries.slice(0, 8)`); setup-catalog entries get `known_models: []` (line 251) and template enrichment beyond the 8th provider never happens. getAcpProviders returns this merged catalog surface as the PRIMARY (lines 500-513) and only falls back to providersList_unstable inventory (the source of full per-provider known_models, populated via startProviderInventoryLoad at line 516) when the catalog surface THROWS. So in the normal happy path roughly 57 of 65 providers carry empty known_models. This directly defeats two owner fixes for the exact edge case they targeted: when a provider's live endp

**Action:** Fix, but choose the safe variant. Do NOT drop the 8-entry cap (65 sequential ACP template fetches risk happy-path latency and shared-client starvation). Instead, populate known_models/default_model for all providers from the ACP inventory. Lowest-risk: in the modelInterface fallback catch (1774-1786), when epistemosKnownModelFallback(p) is empty, lazily fetch that one provider's inventory via providersList_unstable({ providerIds: [p.name] }) and use its known_models so the 'showing Goose catalog models' warning path fires instead of throw e. Alternatively, merge the providersList_unstable inventory's known_models/default_model into the catalog surface in getAcpProviders/loadProviderCatalogSu

*(fix_is_safe=True)*

### [6] P2 · honesty · `stage-goose-web-ui.sh`:587-621, 671-677

**Issue:** The local ACP config keys (GOOSE_MAX_TURNS, GOOSE_MODE, GOOSE_THINKING_EFFORT, GOOSE_TELEMETRY_ENABLED, voice_dictation_*, SECURITY_*_CLASSIFIER_*) are intercepted by upsertAcpProviderConfig and written only to the module-level in-memory `localAcpConfigValues` Map (line 672); they are never sent to goose serve over ACP and are read back only from that same Map. Consequence for the ACP reconnect/reload edge case: a WebView reload re-evaluates the module, clearing the Map, so every one of these settings reverts to defaults (only GOOSE_TELEMETRY_ENABLED has a default). The settings UI appears to accept and persist telemetry/voice/security/max-turns changes, but they are session-scoped memory wi

**Action:** Keep the finding at P2. Apply a tiered fix in stage-goose-web-ui.sh: (a) immediately, rehydrate the intercepted keys on connect (and/or surface their session-scoped nature) so the settings UI stops implying persistence it doesn't have; (b) for keys with real ACP PreferenceDefs (GOOSE_THINKING_EFFORT, voice_dictation_provider->VOICE_DICTATION_PROVIDER, voice_dictation_preferred_mic->VOICE_DICTATION_PREFERRED_MIC), route upsert/read through the Goose ACP preferences method instead of the in-memory Map, after verifying the client wrapper exposes it; (c) route SECURITY_*_CLASSIFIER_TOKEN secrets to Keychain via a native Epistemos bridge, never to config.yaml or the Map. Do not delete the existin

*(fix_is_safe=True)*

### [7] P3 · edge-case · `GooseACPClient.swift`:518-530, 489-500 — ⚠️ DEFERRED (subtle race; needs a concurrency harness)

**Re-analyzed 2026-06-28 PM — fix is subtler than the finding states.** The naive
`withTaskCancellationHandler { withCheckedThrowingContinuation { ... } } onCancel:`
has a cancellation-before-registration race: `onCancel` runs off-actor and must
Task-hop to the actor to `removeValue(forKey: id)`; if that hop runs BEFORE the
`withCheckedThrowingContinuation` body parks the continuation, the removeValue
returns nil and the later-parked continuation is never resumed -> a permanent hang
(worse than today). Also, today's impact is "delayed until connection teardown,"
not an infinite hang (teardown's `fail()` resumes all waiters). Doing this safely
needs a guarded park (e.g. store a sentinel / check `Task.isCancelled` after
registration, or an explicit registered/cancelled state machine) PLUS a controllable
mock-transport concurrency test to prove single-resume across the
deliver/fail/cancel/timeout race. Not worth rushing into core ACP plumbing (every
request flows through `waitForResponse`) without that harness; the surface is
currently GREEN. Keep deferred; design the harness first.



**Issue:** No per-request timeout or cooperative cancellation. `waitForResponse` parks a `withCheckedThrowingContinuation` in `waitingResponses[id]` with no timeout and no Swift Task-cancellation hook. If the connection stays alive but the server never answers one request (e.g. Goose enumerating models from an unreachable/hanging provider endpoint, or a custom method that errors out server-side without a JSON-RPC reply), the caller hangs forever -- it only unblocks on full connection teardown. Worse, `withCheckedThrowingContinuation` ignores cancellation, so if the caller's Task is cancelled (rapid route switching cancelling an in-flight provider catalog fetch), the awaiting call does NOT throw Cancell

**Action:** Fix, with care. Add a single private wait helper that wraps the existing continuation in `withTaskCancellationHandler`: on cancel, hop onto the actor and, only if `waitingResponses.removeValue(forKey: id)` returns the continuation, resume it with `CancellationError()`. Additionally arm an optional per-request watchdog (generous deadline) that, on expiry, likewise removes the id and resumes with a timeout error ONLY when removeValue returns non-nil. This keeps the single-resume invariant shared with deliverResponse/fail and prevents a double-resume crash. Leave the success path and `fail()` semantics unchanged. Do not silently swallow the timeout — propagate it as a thrown error so callers ca

*(fix_is_safe=True)*

### [8] P3 · edge-case · `GooseWebNativeAffordanceBridge.swift`:63-67, 568-626 — ✅ FIXED (2026-06-28 PM)

**RESOLVED.** Added `@MainActor closeAllApps()` to the bridge (snapshots
`appWindows.values`, clears all three registries, THEN closes each window so the
`windowWillClose`-driven `removeValue` cannot mutate during iteration) and invoke it
from `GooseWebSurfaceView.onDisappear` alongside the existing teardown. Launched
MCP-app windows no longer orphan as top-level NSWindows after the surface
disappears. Locked by `mcpAppWindowsClosedOnSurfaceTeardown` (method + ordering +
onDisappear call); 16/16 supervisor tests green. Commit `a753916eb`.



**Issue:** Launched MCP-app windows/WebViews leak on surface teardown. launchApp creates NSWindow + WKWebView instances tracked in appWindows/appWebViews/appWindowDelegates. They are only removed when the user closes that specific window (windowWillClose) or calls closeApp. GooseWebSurfaceView.onDisappear stops the supervisor/server/acp and cancels prompts but never closes these app windows, and the bridge deinit only releases the wakelock assertion. So any MCP app windows opened via launchApp outlive the Goose surface as orphaned top-level windows holding WKWebViews, with no remaining UI to close them.

**Action:** Add a MainActor teardown method to GooseWebNativeAffordanceBridge (e.g. closeAllApps()) that snapshots appWindows.values, calls close() on each, then clears appWindows/appWebViews/appWindowDelegates, and invoke it from GooseWebSurfaceView.onDisappear alongside the existing cleanup. Snapshot before iterating to avoid mutation-during-iteration via the windowWillClose delegate callback. Leave the deinit closing as optional/skip it (nonisolated deinit cannot safely do MainActor window closes). Downgrade severity to P3.

*(fix_is_safe=True)*

### [9] P3 · maintainability · `GooseWebNativeAffordanceBridge.swift`:99-237

**Issue:** The affordance bridge is a single 1008-line @MainActor class whose handleAffordance is a ~130-line switch spanning ~15 unrelated responsibility clusters (file dialogs, file IO + path-scoping, MCP app window lifecycle, notifications, dock/menubar/wakelock/spellcheck prefs, recent-dirs persistence, recipe-hash store, git-worktree subprocess). It is a new Phase-0 file that this PR itself created over the 1000-line line. The dispatch switch and the scoping/IO helpers, the window-lifecycle helpers, and the system-pref helpers are independently cohesive.

**Action:** Keep as a low-priority P3 cleanup; not a Phase-0 sign-off blocker. Lowest-risk first step (zero access-control changes): move the two already-private sibling declarations — GooseWebNativeAppWindowDelegate and the PreferenceKey enum — into their own files. Optional follow-up: extract the cohesive helper clusters (path-scope/IO; window-lifecycle; system-preference) into same-type @MainActor extensions in separate files, widening the stored properties and shared helpers they touch from private to internal/package (behavior-preserving). Keep the dispatch switch and the bridge entry points (userContentController / receiveAffordanceMessage / handleAffordance) intact. Do not convert to injected 'se

*(fix_is_safe=True)*

### [10] P3 · honesty · `GooseElectronFallbackLauncher.swift`:251-273 — ✅ bypass removed (2026-06-28 PM)

**Part 1 RESOLVED (honesty).** The misleading `GOOSE_ALLOWLIST_BYPASS=true` line is
removed. Verified-then-fixed: the bypass WAS forwarded to the child, BUT the
allowlist URL it would bypass (`GOOSE_ALLOWLIST`) is NOT in `environmentAllowlist`
(only PATH/HOME/USER/.../SHELL), so it is never forwarded, so the child enforces no
allowlist (`main.ts:2901 if (!GOOSE_ALLOWLIST) return`) and the bypass disabled
nothing — a line that reads "security guard off" while doing nothing. Removing it
is behaviorally identical now and the secure default if `GOOSE_ALLOWLIST`
forwarding is ever added (the child would then enforce it). Locked by
`launcherEnvironmentIsSanitized` (now asserts `GOOSE_ALLOWLIST_BYPASS == nil` and
`GOOSE_ALLOWLIST == nil`); 5/5 launcher tests green. **Part 2 still open:** moving
the whole launcher + its menu button (`EpistemosApp.swift:1488`) from
`#if !EPISTEMOS_APP_STORE` to `#if DEBUG` so Developer-ID *release* builds also get
the no-op stub — deferred because it only affects the Release configuration, which
must be built/verified in that config before merging (not testable from the DEBUG
suites).



**Issue:** The Electron fallback ships in the Developer-ID build (only `#if EPISTEMOS_APP_STORE` is a no-op stub) and is a second, parallel agent surface that bypasses the canonical WebView+ACP path: it `pnpm --filter goose-app run start-gui` to launch the full upstream Goose desktop from a hardcoded dev checkout (`.research-clones/work/goose` or a hardcoded `~/Downloads/Epistemos/...`). It deliberately sets `GOOSE_ALLOWLIST_BYPASS=true` (disables a Goose-side guard), `NODE_ENV=development`, and `ELECTRON_IS_DEV=1`. Disabling a security allowlist inside a code path that is compiled into a shipped (non-MAS) build, and running a whole alternative agent surface, is at odds with the "single Epistemos agent

**Action:** Lower to P3 and treat as cleanup, not a release blocker. Two safe steps: (1) Drop the `GOOSE_ALLOWLIST_BYPASS=true` line at GooseElectronFallbackLauncher.swift:261 (or add a `// dev-only, no-op: GOOSE_ALLOWLIST is stripped by the env allowlist above` comment) since GOOSE_ALLOWLIST is never forwarded to the child. (2) Keep the launcher out of release/non-MAS menus: move both the launcher implementation and the menu button at EpistemosApp.swift:1493-1496 behind `#if DEBUG` with a coordinated no-op stub so non-DEBUG non-MAS builds still compile, and document it as a developer-only escape hatch. Do NOT delete the launcher - it is a useful labeled dev tool already inert on end-user machines (requ

*(fix_is_safe=True)*

### [11] P3 · security · `GooseRuntimeSupervisor.swift`:449-456 — ✅ FIXED (binary one; 2026-06-28 PM)

**RESOLVED for the EXECUTED path (the security-relevant one).** The cwd-relative
`.research-clones/work/goose/target/*` candidates in `gooseBinaryCandidates`
(now `GooseRuntimeSupervisor.swift`) are wrapped in `#if DEBUG`, so a shipped
(Release) build resolves only the trusted AppSupport (`Epistemos/GooseRuntime/goose`)
and bundle candidates — no code-execution-from-cwd. DEBUG keeps the checkout
candidates for local dev + the live test suites (which run DEBUG). App-target
build SUCCEEDED with the change; locked by the new test
`checkoutBinaryCandidatesAreDebugGuarded` (asserts the `#if DEBUG`/`#endif` wraps
the checkout block and AppSupport/bundle stay unconditional).

**WebUIResolver remainder ALSO FIXED (2026-06-28 PM):** the cwd
`.research-clones/.../dist/index.html` candidate in
`GooseWebUIResolver.candidateIndexURLs` (loaded into the ACP-bridged, privileged
WebView) is now `#if DEBUG`-guarded too, so a Release build sources web content
only from explicit-env / bundled / AppSupport. Locked by
`checkoutWebIndexCandidateIsDebugGuarded`; supervisor + resolver suites green
(21/21), including `resolver supports Application Support staging and checkout
dist fallback` (DEBUG resolution unchanged). Only remaining piece of this finding
is the Electron launcher cwd/Downloads paths — a separate already-dev-inert tool
tracked under finding [10].

**Issue:** Binary-resolution candidate safety: `gooseBinaryCandidates` appends executables resolved relative to the process current working directory (`<cwd>/.research-clones/work/goose/target/.../goose`) and `resolvedGooseBinary` will `proc.run()` the first one whose exec bit is set (no signature/ownership/trusted-location check). Process cwd is influenceable in some launch contexts, so this is a code-execution-from-cwd pattern. The same cwd-relative pattern exists for the Web UI index (GooseWebUIResolver) and the Electron workspace (GooseElectronFallbackLauncher, incl. a hardcoded `~/Downloads/Epistemos` path). In a real install the App-Support/bundle candidates win first, so this only bites in dev, 

**Action:** Apply the #if DEBUG guard to the cwd-relative candidates in the three Goose-surface resolvers, prioritizing the binary one (most security-relevant since it is executed). In GooseRuntimeSupervisor.gooseBinaryCandidates (lines 449-456), wrap the four checkoutTarget appends in #if DEBUG so release builds resolve only AppSupport/bundle. Mirror the same guard for GooseWebUIResolver.swift:107 (cwd .research-clones index.html loaded into the WebView) and GooseElectronFallbackLauncher.swift:237/239 (incl. the hardcoded Downloads/Epistemos path). Keep the AppSupport/bundle candidates unconditional so real-install behavior is unchanged. This is a small, surgical hardening; do not refactor the resoluti

*(fix_is_safe=True)*

### [12] P3 · security · `GooseRuntimeSupervisor.swift`:337-339

**Issue:** `disableKeyring` sets `GOOSE_DISABLE_KEYRING=true`, which makes goose persist its config secrets to a plaintext on-disk config instead of the OS keyring. Because GooseProviderKeyBridge pushes provider API keys into goose via the ACP config-save path, enabling this flag would land those provider secrets in a plaintext file, contradicting the Keychain-only constraint. Today only tests pass `true` and the production call site (`GooseWebSurfaceView.start(secretKey:)`) leaves it `false`, but nothing prevents a future caller from enabling it.

**Action:** Accept as a low-priority hardening fix. (1) Add a doc comment on the disableKeyring parameter (GooseRuntimeSupervisor.swift ~322) stating that GOOSE_DISABLE_KEYRING makes goose persist provider secrets to a plaintext on-disk config and must remain test-only. (2) In processEnvironment, gate the env-var write so that in non-test builds the flag is ignored (or the start refuses) when set — detecting test context with the existing ProcessInfo XCTestConfigurationFilePath pattern (mirroring GooseProviderKeyBridge.swift:205) and emitting a structured diagnostic rather than crashing. Avoid precondition/fatalError. This preserves current test behavior (tests run under XCTest) and current production b

*(fix_is_safe=True)*

### [13] P3 · maintainability · `GooseWebUIResolver.swift`:332-337

**Issue:** `artifactContainsRequiredBridgeMarkers(indexURL:fileManager:)` is dead code — it is a private static helper with no callers (the live path goes `isACPModeArtifact` -> `artifactRejectionReasons` -> `missingRequiredBridgeMarkers` directly). It duplicates the `missingRequiredBridgeMarkers(...).isEmpty` logic.

**Action:** Accept the finding as a valid P3 dead-code cleanup. The unused private helper `artifactContainsRequiredBridgeMarkers` (GooseWebUIResolver.swift:332-337) can be safely removed since it has zero callers and merely duplicates `missingRequiredBridgeMarkers(...).isEmpty` already used inline by artifactRejectionReasons. Because this is new code on an in-progress branch, surface it to the owner: either delete it, or wire it in if it was intended scaffolding. Either choice is behavior-preserving; deletion is the lower-effort path and does not endanger the WebView/ACP path or any protected surface.

*(fix_is_safe=True)*

### [14] P3 · honesty · `GooseSessionLifecycleLiveIntegrationTests.swift`:66, 117

**Issue:** The proof line `session_info_cwd_matches_repo=\(loadCWD == repoPath)` can read `true` vacuously. `loadCWD = stringValue(for: "cwd", in: sessionInfo.session) ?? repoPath` falls back to repoPath whenever session/info omits or mistypes `cwd`, so the recorded proof claims the session cwd matched the repo even when the field was entirely absent. Nothing asserts session/info actually returned a usable cwd, so the new session/info probe contributes a potentially misleading breadcrumb without verifying anything.

**Action:** Split the breadcrumb computation from the call argument. Keep `loadCWD = stringValue(...) ?? repoPath` for the legitimate `loadSession(cwd:)`/`forkSession(cwd:)` arguments (they need a non-nil cwd), but extract the raw value separately, e.g. `let sessionInfoCWD = stringValue(for: "cwd", in: sessionInfo.session)`, then record `session_info_cwd_present=\(sessionInfoCWD != nil)` and `session_info_cwd_matches_repo=\(sessionInfoCWD == repoPath)` (which is false when absent). This is an additive, behavior-preserving change confined to the test file EpistemosTests/GooseSessionLifecycleLiveIntegrationTests.swift; it touches no editor/Plan-3/vendor files, no WebView/ACP path, no provider inventory, a

*(fix_is_safe=True)*

### [15] P3 · maintainability · `GooseSessionLifecycleLiveIntegrationTests.swift`:139-204

**Issue:** Hand-rolled poll loops and helper clones proliferate. `listSessionsIncluding` (30 x 500ms) and `waitForGooseWebPromptInput` (GooseWebPromptLiveIntegrationTests.swift:145-167, 120 x 100ms) each re-implement the same loop/sleep/`attempt % N`-logging/last-value/timeout-error shape already present in `waitForGooseWebBootProbe` and `waitForGooseWebPromptEndTurn`, each with its own ad-hoc attempt count and interval. Separately, `initializeLiveDesktopSession` (139-171) is a near-verbatim clone of the shared `initializeLiveSession` (GooseLiveIntegrationTests.swift:867) differing only by the metadata passed to newSession.

**Action:** Keep as a fix-ready P3. Highest-value, lowest-risk step: collapse initializeLiveDesktopSession into the shared initializeLiveSession by adding optional cwd: (default liveRepoRootURL().path) and metadata: (default nil) parameters, then update the single lifecycle caller to pass the desktop cwd/metadata; this is mechanical and behavior-preserving for the 3 existing callers. Treat the generic pollUntil(attempts:interval:describe:predicate:) consolidation as optional/secondary: only adopt it if the helper cleanly accommodates sleep-ordering, throw-vs-return-on-timeout, and the end-turn mid-loop error short-circuit without hurting readability; otherwise leave those loops as-is. No product code or

*(fix_is_safe=True)*

### [16] P3 · maintainability · `stage-goose-web-ui.sh`:925-927

**Issue:** In the acpConnection.ts graft, `getClientAnchor` is declared (the `export async function getAcpClient` signature string) immediately before fs.writeFileSync but is never referenced — no includes check, no replace. It is dead leftover, suggesting the request-serialization graft once intended to also wrap getAcpClient and was left half-applied; it adds noise and a false impression that getAcpClient is anchored/guarded.

**Action:** Delete the unused `const getClientAnchor` declaration at lines 925-926 (the line `fs.writeFileSync(path, source);` then follows directly). Do NOT take the alternative of wiring it into an anchor guard — that would add a throw and change staging behavior. Low priority; bundle with other staging-script cleanup.

*(fix_is_safe=True)*

### [17] P3 · maintainability · `GooseACPProtocol.swift`:1-1146

**Issue:** The 1146-line protocol file is a flat dump of ~60 DTOs plus 4 hand-rolled coding enums in one namespace, with duplication and two parallel method enums. `GooseACPMethod` (hand-rolled rawValue both directions, including an `.unknown(String)` case) and `GooseACPCustomMethod: String` are two separate method registries serving the same `sendRequest(method:String)` sink. `GooseACPProviderTemplateCatalogEntry` and `GooseACPProviderTemplate` duplicate ~6 fields (providerId/name/format/apiUrl/envVar/docUrl). Several `init(from:)` exist only to apply `decodeIfPresent(...) ?? default`. Also, `GooseACPSessionUpdate.encode` (942-947) round-trips through a fresh `JSONEncoder()` -> `JSONDecoder()` -> merg

**Action:** Keep as a low-priority deferred owner note; do not action unilaterally. If any cleanup is taken: (a) limit to a behavior-preserving multi-file split mirroring the GooseACPSourceProtocol split, performed via xcodegen regeneration so the new files stay in the Epistemos target; (b) do NOT introduce a nested shared sub-struct for the two provider templates — the ACP wire format is flat and a nested decode would break the proven-green 65-provider/413-model catalog path; if deduplication is wanted, keep the flat stored fields and share only via a protocol/extension with default flat CodingKeys; (c) leave GooseACPSessionUpdate.encode as-is, or remove it only after narrowing the conformance to Decod

*(fix_is_safe=False)*

### [18] P3 · security · `GooseRuntimeSupervisor.swift`:216, 288-303

**Issue:** Subprocess-group hardening gap vs the documented standard. The Rust spawn sites use `process_group(0)` + `kill_on_drop`; the Swift `goose serve` (and the Electron launcher) use Foundation `Process`, which is not placed in its own process group. Teardown relies on `OrphanSubprocessCleanup.cleanupProcessTree` walking `proc_listchildpids` from the root PID. Any grandchild that goose spawns (MCP/extension/provider helpers) and that gets reparented to launchd after its intermediate parent exits is no longer reachable from the root PID, so it escapes the tree-walk and leaks. Additionally, both `track(proc)` and `terminateTrackedProcess` go through `AppBootstrap.shared?.orphanCleanup` with optional

**Action:** Accept as a low-priority (P3) robustness/consistency item; do NOT do the posix_spawn/process-group rewrite in Phase 0. Safe subset worth doing: (a) Mirror the Electron launcher exactly in GooseRuntimeSupervisor: add a single private lazy var cleanup = AppBootstrap.shared?.orphanCleanup ?? OrphanSubprocessCleanup() and route the three call sites (track at line 216, cleanupProcessTree at 291, untrack at 302) through that one instance. Must be ONE shared instance, not three independent ?? expressions, or track() and cleanupProcessTree() would land on different objects and defeat tracking. (b) Add a brief code comment at the spawn site documenting that proc_listchildpids tree-walk is the deliber

*(fix_is_safe=False)*

### [19] P3 · security · `GooseRuntimeSupervisor.swift`:234-268, 477-485

**Issue:** Readiness is confirmed solely by an unauthenticated GET `/health` returning body "ok". It does not prove the listener is the process we spawned. In the narrow window where our `goose serve` loses the bind race to a foreign Goose-compatible service that grabbed 3284 after the pre-launch check, `waitForReady` returns the foreign base URL and `status` becomes `.running`, after which `connectNativeACP` hands OUR secret token to that foreign listener via the `?token=` query before the process-exit handler flips state to `.failed`. So the secret can briefly be disclosed to a local impostor.

**Action:** Accept the finding (real, P3). Implement the identity-bound readiness fix already modeled by the sibling supervisors rather than the suggested options. Concretely: in `waitForReady`, have the pipe-reading task feed each line to the existing `parseListeningURL(from:expectedPort:)` (line 346) and resume readiness with that parsed URL only when OUR spawned process emits its "ACP server starting/listening on 127.0.0.1:<port>" line — mirroring WorkRuntimeSupervisor.swift:134 and WorkOpenWorkSupervisor.swift:109. Because the pipe is connected exclusively to our spawned process, a foreign listener cannot forge that line, so this binds readiness to process identity BEFORE any secret leaves the app. 

*(fix_is_safe=False)*

### [20] P3 · maintainability · `GooseElectronFallbackLauncher.swift`:28-63, 251-273

**Issue:** Env-sanitization is duplicated across two launchers with drifting policy. `GooseRuntimeSupervisor.processEnvironment` and `GooseElectronFallbackLauncher.processEnvironment` both implement the same allowlist + denylist + PATH-prepend pattern, but the denylists have diverged: the Electron copy omits the DYLD_PRINT_LIBRARIES / Malloc* / PYTHONSTARTUP / RUBYOPT / PERL5* vectors and several provider keys (PERPLEXITY/OPENROUTER/GOOGLE_ACCESS_TOKEN/etc.) that the supervisor lists. It is allowlist-first so nothing actually leaks today, but the two lists will keep drifting and one is presented as a security control while being incomplete.

**Action:** Keep as P3 maintainability (not a security defect — allowlist-first already blocks every denylisted name). If addressed: extract a single shared denylist constant (the hardening policy) used by all the subprocess launchers (Goose supervisor + Electron + the two Work launchers), but do NOT unify the allowlists as the suggested fix literally says — keep each launcher's allowlist and extra-env local, because they legitimately differ (Electron needs SHELL; Work launchers have distinct PATH/extra-env). As a cheap, low-risk interim, simply add the missing vectors (DYLD_PRINT_LIBRARIES, Malloc* family, DEBUG, PYTHONSTARTUP, RUBYOPT/RUBYLIB, PERL5*, and the extra provider keys) to the Electron denyl

*(fix_is_safe=False)*

### [21] P3 · drift · `stage-goose-web-ui.sh`:2553-2607 (TS graft) vs GooseCustomCapabilityLiveIntegrationTests.swift:266-307

**Issue:** The recipe-id reconciliation algorithm is implemented twice in two languages with no shared source of truth: the TS web graft (`reconcileSavedRecipeResponse` + `normalizeRecipePath` + `fileNameFromPath`) and the Swift proof (`canonicalRecipeID` + `normalizeRecipePath`). The `/private/var/` -> strip-`/private` normalization is duplicated verbatim, and the two even diverge on filename extraction (TS hand-rolls `path.split(/[\/]/)`, Swift uses `URL.lastPathComponent`). Because the Swift test re-implements the logic rather than exercising the renderer's actual output, a fix or bug in one side is invisible to the other — the proof can stay green while the shipped TS path is broken (or vice-versa)

**Action:** Keep as a low-severity (P3) documented drift note, not a blocking fix. Do NOT adopt the primary suggested fix of restructuring the working ACP-direct Swift integration test to drive a WebView and read window.__epistemosGooseRecipeIDReconciliation (unsafe: touches the protected WebView/ACP path; array is only populated on an actual drift event so the assertion is empty/flaky in the happy path). Safe options: (1) add cross-reference comments pinning the two normalizeRecipePath implementations together and explicitly noting the fileNameFromPath (split) vs lastPathComponent divergence so a change to one flags the other; (2) if behavioral coverage of the shipped reconciliation is desired, add a d

*(fix_is_safe=False)*

### [22] P3 · maintainability · `stage-goose-web-ui.sh`:2548-2572, 2668

**Issue:** The `void EPISTEMOS_ACP_RECIPE_ID_RECONCILIATION_MARKER;` breadcrumb hack injects dead code into the real Goose web bundle: a synthetic const that exists only to be greppable by the validate-only check (line 2668), kept alive solely by a no-op `void` statement to dodge unused-var lint. The companion `window.__epistemosGooseRecipeIDReconciliation` ring buffer is written but never read anywhere in the repo (confirmed by grep) — pure write-only instrumentation shipped to production. The validate grep keys off the synthetic string rather than the meaningful symbol `reconcileSavedRecipeResponse`. This repeats the same idiom already at line 854 (EPISTEMOS_ACP_SERIALIZATION_MARKER), compounding the

**Action:** Keep the finding but downgrade to P3 and correct the fix. Preferred remedy (consistency, no deletion): add `__epistemosGooseRecipeIDReconciliation` to GooseWebUIResolver.requiredBridgeMarkers and assert it in GooseWebRouteLiveIntegrationTests.swift alongside its two siblings, making the buffer load-bearing instead of orphaned. If instead simplifying the marker idiom, update BOTH stage-goose-web-ui.sh:2544 (idempotency guard) AND :2668 (validate grep) to key off `reconcileSavedRecipeResponse`, applying the same treatment to the sibling markers at 612/854 to avoid a one-off inconsistency. Do NOT apply the fix as literally written (it omits line 2544 and would break idempotent re-runs of the st

*(fix_is_safe=False)*

### [23] P3 · honesty · `stage-goose-web-ui.sh`:1713-1721

**Issue:** epistemosProviderModelErrorMessage hardcodes the provider-specific unreachable-endpoint hint to a single provider id ('lmstudio') with a literal `http://localhost:1234` and `LMSTUDIO_HOST`. Other local/self-hosted providers (ollama, custom OpenAI-compatible endpoints) that are unreachable get the generic 'Failed to fetch models' message, only partially meeting the owner's 'provider-specific warning not generic ACP failure' intent. The literal localhost URL is also potentially misleading: if the user configured LMSTUDIO_HOST to a remote address, the message asserts a host that is not the one actually being contacted.

**Action:** Keep as a P3 honesty polish, but do NOT implement the suggested 'derive host from api_url / configured *_HOST value' mechanism — that data is not present in ProviderDetails.metadata and would require new ACP plumbing that risks the working path. Instead apply a wording-only fix: stop asserting localhost:1234 as the host being contacted (present it as the LM Studio default, e.g. 'LM Studio is not reachable. Start its local server, or update the LMSTUDIO_HOST setting (default http://localhost:1234)'), and optionally extend the same lightweight hardcoded special-case to other known local providers like ollama. This is behavior-preserving and boundary-safe. Low priority; fine to defer.

*(fix_is_safe=False)*

### [24] P3 · maintainability · `stage-goose-web-ui.sh`:2670-2675

**Issue:** The staged TypeScript overlay is only type-checked when EPISTEMOS_GOOSE_UI_VALIDATE_TYPECHECK=1 (opt-in, default 0). The real build path uses vite/esbuild, which strips types without type-checking, and the post-build verification only greps for marker substrings. A graft that introduces a type error (e.g. a renamed ACP method or a shape mismatch in providers.ts) but still bundles would ship undetected by the default pipeline.

**Action:** Do NOT make tsc --noEmit a hard gate on the release/staging build path — given the whole-tree strict tsconfig over the re-synced upstream clone, that risks breaking a currently-green working path on the next re-sync. Instead, enforce the EXISTING opt-in validate path in CI: run `EPISTEMOS_GOOSE_UI_VALIDATE_ONLY=1 EPISTEMOS_GOOSE_UI_VALIDATE_TYPECHECK=1 bash stage-goose-web-ui.sh` as a CI step (it passes today, EXIT=0). This fails graft-introduced type/shape errors in CI without coupling the artifact build to upstream type cleanliness. If upstream-tree brittleness becomes a problem, optionally scope tsc to just the grafted files. Note for context: renamed-ACP-method drift is already largely c

*(fix_is_safe=False)*
