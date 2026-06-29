# Goose Phase 0 — Owner §7 Sign-Off Checklist (2026-06-28)

> 🛑 **SUPERSEDED 2026-06-29: §7 is GREEN-LIT — this checklist is HISTORICAL.** Plan 1 is ON Phase 1; there is NO
> pending sign-off. Do NOT treat the items below as a blocking gate. (Keep the 5 proofs green as ongoing
> verification.) Canon: `docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md`.

Branch: `feat/goose-surface`. Prepared by the Claude deep-hardening loop.
**Phase 0 is NOT signed off.** This checklist is the §7 gate: the items only
*you* (owner) can verify, plus the one OAuth login the automated proofs cannot
perform. Nothing here starts Phase 1 / `Epistemos/Agent/*` / Paseo §15.

---

## ★ 2026-06-29 ADDENDUM — post-green-light progress (Steps 1-3)

You green-lit **NATIVE EPISTEMOS UI + goosed backend** and the ordered plan
(finish hardening → goosed swap → per-route parity-gated native migration). The
"OWNER DECISION NEEDED" above (start Path-B) is therefore RESOLVED and executed.
Status of your three ordered steps:

- **STEP 1 (finish hardening) — DONE.** Every adversarially-confirmed,
  backend-independent bug from the deep-hardening pass is fixed and committed
  separately, WebView surface kept green: C1 (addRecentDir self-scope),
  H1 (nav-gate pins OUR ports not any loopback), false-green ready language,
  #3 (superseded ACP client closed), #4 (null-id error contained), #11 (Stop/steer
  bypass the ACP FIFO), #13/#24/#23/#14 (openExternal allowlist + git env-harden +
  launchApp guest nav-gate), #7/#20 (graft hard-fail on upstream drift),
  #9/#17/#28 (golden-rule roster guard now catches hardcoded MODEL ids). Residual
  bugs are documented as deferred-with-rationale (`GOOSE_DEEP_HARDENING_REPORT...`,
  commit `360d06e75`).

- **STEP 2 (goosed backend, Option B) — DONE + PROVEN.** Swap implemented behind
  `EPISTEMOS_GOOSE_BACKEND` (default `.serve`, single-point rollback), bundler
  stages both binaries, `** BUILD SUCCEEDED **`. End-to-end live re-prove on goosed
  (`scripts/goosed-live-reprove.sh`, re-runnable): the FULL ACP surface is
  byte-identical (106 providers live-enumerated, Auth 65, Extensions 11, full
  session lifecycle, prompt→stream→end_turn) AND the **3 previously-unbackable
  features are now live REST** (`/config/prompts` 200, `/config/permissions` 405,
  `/mcp-app-proxy` 400). Source-verified parity SUPERSET (same `check_acp_token`
  auth + `developer` builtin; goosed ADDS `GooseDesktop` identity + real scheduler).
  → This is what closes your "feature-completeness 100%" gate: **0 unbackable on
  goosed** (was 2 on lean serve). Details: `GOOSE_STEP2_GOOSED_PROOF_2026_06_29.md`.
  - Honest remainders: (a) flipping the runtime DEFAULT to goosed needs an in-app
    smoke test (the iso-DD test host is degraded; protocol-level proof is complete).
    (b) TLS stays opt-in — http loopback is the proven, zero-regression posture; the
    cert-pin delegate is scoped-deferred until an MCP guest is shown to need https.

- **STEP 3 (router + native Models slice) — DONE + PARITY-PROVEN (stays opt-in).**
  `GooseSurfaceRouter` defaults EVERY route to the WebView (the oracle); a route goes
  native only when it is BOTH native-capable AND explicitly enabled
  (`EPISTEMOS_GOOSE_NATIVE_ROUTES` env / `epistemos.goose.nativeRoutes` UserDefaults).
  Native `GooseNativeModelsView` is the safe first slice — STRICTLY live-enumerated
  from the same ACP connection the WebView uses (no second spawn; GOLDEN RULE roster
  guard clean). `** BUILD SUCCEEDED **`.
  - A live parity probe CAUGHT a real design error before it shipped: the picker first
    sourced the custom-provider TEMPLATE catalog (built-ins like openai absent → the
    real default couldn't be shown) + a per-provider live model call that HANGS without
    creds. Fixed to source `providers/list` (65 providers, models INLINE, built-ins
    included, default resolvable, never hangs).
  - Witness (re-runnable: `scripts/goose-native-models-probe.sh`): providers/list → 65
    providers, 53 carry inline models, defaults/read → openai/gpt-4o-mini present →
    `NATIVE_MODELS_PARITY_PASS`. Plus always-run router invariant tests.
  - HARD GATE honored: the Models route has EARNED promotion but stays on the WebView by
    default — flip the flag to try native. WebView remains the oracle for every route.
  - Next routes (auth, apps, sessions, …) promote one at a time as each gains a native
    view + green parity, same pattern.

- **OWNER-SYMPTOM ROOT CAUSES FOUND + FIXED (2026-06-29).** An adversarial review of the
  owner-facing WebView host (`GooseWebSurfaceView` + `GooseACPEventBridge` lifecycle) traced your
  reported intermittent symptoms to REAL bugs (not stale-build artifacts). Shared root cause: the
  runtime reaching `.running` and the ACP bridge reaching `.connected` are ASYNC, but the surface
  only reacted to the FIRST poll and never re-drove a late/failed transition. Fixed (commits
  `5081b27f2`/`58ef3aaab`/`09042cc96`; build green; `GOOSE_WEBVIEW_HOST_REVIEW_2026_06_29.md`):
  - **H1** "loading failures that never self-heal": `.running` arriving after the 26s load poll (the
    `goosed` backend needs 45s) left the surface stuck on the placeholder forever — now an idempotent
    supervisor-status observer drives the load whenever readiness arrives.
  - **H2 + H3 "Failed to load provider credentials" / providers not auto-loading**: the SPA read
    Goose's credential state BEFORE the native key-sync mirrored your Keychain keys (H3), and a brief
    goose blip could strand the bridge failed with the sync never re-running (H2). Now the surface
    reloads the SPA once the keys are synced, re-drives the bridge under a healthy runtime, and the
    sync retries through Goose's cold-start warmup (M3).
  - **M2** lingering "loading failures": the health check now times out in 5s instead of up to 60s.
  - **L1**: the details row now reads exactly "custom ACP Goose ready" when connected.
  → These ship in the Swift build, so they need a **rebuilt** app (not just the re-staged Web UI) +
  a quick smoke test: open Goose, kill+restart `goose serve`, confirm the surface RECOVERS instead of
  sticking; and that Auth/Models populate on first open without "Failed to load provider credentials".

The manual app pass + OAuth login below remain the owner-only §7 gate.

---

## What the automated proofs already established (re-runnable)

Built on an isolated DerivedData (CoW-cloned SourcePackages) to avoid the
concurrent-agent build race. Combined live sweep, real `goose serve` 1.39.0:

```
✔ Test run with 5 tests in 5 suites passed
  provider catalog:  65 providers / 413 models  (catalog_source=goose_serve_acp_only)
  session lifecycle: prompt end_turn; persisted session listed; fork differs
  custom capability: recipe-id reconciled (by_path), session launched
  web prompt:        renderer submits, streams to end_turn
  web route smoke:   all owner routes render with their ACP methods seen
```

- GOLDEN RULE: 0 hardcoded provider/model rosters in `Epistemos/Goose/*.swift`.
- No silent ACP drops: unknown methods → structured diagnostic + JSON-RPC `-32601`.
- Secrets: Keychain via `GooseProviderKeyBridge` (never UserDefaults).
- Thermonuclear hardening: per-frame ACP decode containment; reconnect recovery
  (budget reset + `connectionKey` clear); stale-prompt cancellation; nav `file:`
  scheme removed. 5/5 sweep stays green after these edits.
- Repaired Web UI re-staged to `~/Library/Application Support/Epistemos/GooseWebUI`.

Evidence: `docs/handoffs/GOOSE_PHASE_0_VERIFICATION_2026_06_27.md` (2026-06-28
addendum), `docs/handoffs/GOOSE_PHASE_0_THERMONUCLEAR_FINDINGS_2026_06_28.md`,
proof logs under `/tmp/epistemos-goose-phase0-*.log`.

---

## Feature-parity closures since this checklist was first written (2026-06-28 PM)

Directly addressing your "feature completeness 100% is the main gate" — the
silently-missing controls (dead `@/api` REST not grafted to ACP) found and fixed,
each gated by a strict test and re-proven by the 5/5 live sweep:

- **Thinking Effort** now end-to-end: appears (live inventory `reasoning`),
  applies to the agent (`setSessionConfigOption thinking_effort`), and PERSISTS
  across restart (`preferencesSave/Read_unstable`). (`c4995667b`)
- **First-run welcome provider grid** populates from the live ACP catalog
  (OnboardingGuard → ProviderSelector); was an empty dead-REST dropdown — your
  "my app is not doing that at all." (`af1521aa3`)
- **Custom-provider CRUD** (add/edit/delete) bridged onto
  `providersCustom*_unstable`; adding/editing a custom provider previously threw
  silently. (`05a9f4e65`)
- Model switcher / config-status / auth credentials (earlier this loop).
- Gate test `stagingGraftsWireLiveParityFeatures` now carries **39 assertions**
  locking every graft (passes 0.049s); the parity-gate IS the regression guard
  you asked for ("deep hardened strict tests moving forward").

Still tracked (verify-then-fix, not yet grafted): tools/permissions list
(`toolsList_unstable` — needs live extension-prefix filtering check), dictation,
agent-mode cross-restart persistence (no `GOOSE_MODE` preference home in 1.39.0).

### Feature-completeness DEFINITIVELY assessed (your primary gate)

A 10-agent audit swept ALL 42 ungrafted Goose UI components that touch the dead
`@/api` REST surface (`docs/handoffs/GOOSE_MISSING_FEATURE_AUDIT_2026_06_28.md`).
Result: **35 are NOT missing features** (types-only / already-ACP-wired /
dead-branch / non-ACP native carve-outs), and **7 are genuine gaps** — of which
**1 was a clean fix (AlertBox threshold save, grafted `80de32ab7`)** and the other
**6 are NOT silent bugs but product decisions or features with no ACP method**:
PermissionModal-save + Prompts have **no ACP persistence method** (implement native
or hide); Dictation needs a **graft-vs-native** decision (Epistemos has native
voice); MCP-App rendering needs a goosed-only host; toolsCache/PermissionModal-load
need a live extension-filter check. So the residual is **bounded and named, not an
unknown "things are silently missing"** — the surface is feature-complete for
everything ACP can express.

### 2026-06-28 evening — Path-A grafting exhausted + Path-B gating risk cleared

Closing out the "Both: graft ACP gaps now, plan Path B" decision:

- **toolsCache (#1) shipped + gate-locked** (`listAcpSessionTools` via
  `toolsList_unstable` with a full-list fallback so a tool-name casing mismatch can
  never be worse than the silent-null REST it replaces; +7 parity-gate assertions).
- **PermissionModal (#3) — deliberately NOT half-grafted (verify-then-fix).** Its
  tool-LOAD is ACP-graftable, but per-tool SAVE (`upsertPermissions`) has no ACP
  method. A LOAD-only graft would make the modal LOOK functional while silently
  discarding saves — a NEW silent failure, strictly worse than today's honest
  load-error. It is both-halves-or-nothing → Path B.
- **Path-A graft work is now EXHAUSTED of safe, non-throwaway items.** Every residual
  gap is Path-B (#3 Permission-save, #5 MCP-app, #6 Prompts), a no-op (#2 Extension
  env_keys are references not secrets), or a "don't rush" native-vs-graft call
  (#4 Dictation — Epistemos has native voice).
- **Path-B gating risk RESOLVED, verdict FAVORABLE.** Source-level check: `goosed
  agent`'s tunnel/gateway tasks are network-only (zero subprocess spawning → same
  launched-server shape as the already-accepted `goose serve`, no new sidecar vs
  CLAUDE.md's no-subprocess rule); the two entitlements it needs (`network.client`
  + `network.server`) already ship. Caveats named (wider network surface for MAS
  review; the shared "is a launched goose binary MAS-distributable at all" question
  is unchanged, not regressed). See `GOOSE_PATH_B_FULL_GOOSED_MIGRATION_PLAN...md`.

**→ OWNER DECISION NEEDED to make further automated progress:** start Path-B
*implementation* (bundle `goosed`, swap the supervisor to `goosed agent` behind a
build flag, Path A stays default until proven) — which makes Prompts / Permission-
save / MCP-app work natively — **or** stay Path-A and have me honest-gate (hide) the
no-ACP-method controls so nothing looks functional-but-silently-broken. Until you
pick, and until the shared Swift test bundle unblocks (another agent's
`CodeEditorPolishTests`), no further safe Goose code work remains this loop.

---

## OWNER — manual app pass (please click through and confirm)

> Note: every route below is ALSO covered by the automated live WebRoute suite
> (`GooseWebRouteLiveIntegrationTests`, green this pass), which asserts each route
> renders its real heading AND fires its real ACP method (not dead REST) —
> `/apps`, `/schedules`→`schedules/list`, `/recipes`→`recipes/list`,
> `/sessions`→`session/list`, `/skills`→`sources/list`, `/extensions`→
> `config/extensions/list`, `/settings?section=models|auth`, `/configure-providers`
> — with empty-state text (e.g. "No apps available") accepted and error-boundary
> text forbidden. Your manual pass is final confirmation, not first discovery.

Launch the current Debug build:

> ⚠️ **IMPORTANT — relaunch to pick up the fixes.** The Goose surface loads its Web
> UI from `~/Library/Application Support/Epistemos/GooseWebUI` at launch. All the
> parity fixes from this loop (welcome provider grid, model switcher / config-status,
> Thinking-Effort persistence, custom-provider add/edit/delete) live in that
> re-staged bundle. If an Epistemos instance is still running from BEFORE the
> re-stage, it shows the OLD surface — which would look like "still broken." **Quit
> any running Epistemos (Cmd-Q) first, then open the build below.** (The bundle is
> already current; you do NOT need to rebuild for these Web-UI fixes. A rebuild is
> only needed if you also want the Swift-side hardening from this loop.)

```
# quit any running instance first, then:
/usr/bin/open "/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app"
```

- [ ] **Cmd-3 opens Goose.** Open the details/slider panel. It reads exactly
      `native ACP Goose ready (1.39.0)` and `custom ACP Goose ready`
      (NOT a vague "Goose ACP ready").
- [ ] **Settings → Auth**: no `Failed to load provider credentials`. Configured
      providers list their credential fields; empty providers show an empty
      state, not a toast error.
- [ ] **Settings → Models → Switch models**: the provider picker auto-populates
      from the Goose ACP catalog. (A provider-specific model error for a local
      provider whose server is off — e.g. LM Studio/Ollama — is acceptable and is
      NOT the same as a generic "ACP WebSocket connection failed".)
- [ ] **Settings → Models → Thinking Effort**: for a reasoning-capable model the
      effort selector is visible, changing it applies, and it survives an app
      restart (newly persisted this pass).
- [ ] **First run / welcome**: with no provider configured, the welcome screen's
      provider list is populated (not empty) and configured providers read as
      ready.
- [ ] **Settings → Models → Add custom provider** (and edit/delete an existing
      one): the form saves without a silent failure; the new provider appears and
      is selectable.
- [ ] **New Chat**: the prompt input appears after loading; the default
      provider/model shows; a tiny prompt streams and returns.
- [ ] **Apps**: route loads. `No apps available` is fine; a generic
      `Error loading apps` is not.
- [ ] **Recipes**: route loads; save-and-run does not throw `recipe not found`.
- [ ] **Session History**: route loads; a recently-prompted session appears; no
      generic `Error Loading Sessions`.
- [ ] **Skills / Scheduler / Extensions**: routes load without generic error
      boundaries.
- [ ] **(Edge) Reconnect**: with Goose open, kill `goose serve` and let it
      restart (or toggle the runtime); the surface recovers or shows an honest
      blocked state — no stale provider errors. *(Newly hardened this pass.)*

## OWNER — the OAuth login the proofs cannot perform

- [ ] **Browser-mediated provider OAuth success.** Pick an OAuth provider
      (e.g. the one you normally use), run its sign-in from Settings → Auth, and
      confirm a configured/authenticated status comes back and a prompt then
      streams. This is the Gate-5 item that requires your interactive browser
      session; the automated suite can only prove the non-OAuth rejection path.

---

## Gate status (honest)

| Gate | Status | Note |
| --- | --- | --- |
| 1 Real Goose Electron fallback launches | PASS | **re-proven 2026-06-29** — `GooseElectronFallbackLauncherTests` green in the 53/53 unit run (real build) |
| 2 `goose serve` ACP WS reachable | PASS | **proven 2026-06-29 by direct probe** — iso-DD goose binary is byte-identical to the working one + its `goose serve` returns `/health` 200 in 1s; live product instance serves ACP on 3284 (3h+). The iso-DD live-SUITE timeouts are a test-harness spawn artifact (isolated TestRuntime), NOT a runtime failure — see verification doc "CONCLUSIVE" addendum |
| 3 new→prompt→stream→end_turn | PLUMBING PASS; real-token completion needs your creds | **2026-06-29 direct ACP probe**: `initialize` + `session/new` + `session/prompt` all live against real `goose serve`; prompt STREAMED 6 `session/update` events (usage/commands/session_info) and reached `stopReason=end_turn` — full new→prompt→stream→terminate loop proven. Used a DUMMY key (used=0 tokens), so a real LLM `agentMessageChunk` completion + live `agent_thought_chunk` still need YOUR provider credential (this Gate-3 success path + Gate-5 OAuth genuinely can't be automated) |
| 4 Staged Web UI boots via shim | PASS | **re-proven 2026-06-29** — `GooseWebViewBootShimTests` + resolver suite green (53/53) |
| 5 Nothing lost vs real Goose | PARTIAL | owner OAuth success, true confirm-dialog/MCP-app window affordances, MAS/manual/distribution WRV still open |

### 2026-06-29 re-prove summary (folded in for sign-off)

- Corrected a multi-loop FALSE premise: the shared test bundle was **never** blocked
  by `CodeEditorPolishTests` (its "CodeEdit refs" are Epistemos's own `CodeEditor*`
  classes, not the removed package). Proven by a **real green full build** (exit 0)
  on an isolated DerivedData. DerivedData/artifact health (yyjson, llama.xcframework)
  confirmed clean.
- **Focused Goose unit layer re-proven 53/53 green** (build + `test-without-building`,
  re-runnable): parity gate (now carrying this loop's toolsCache→`toolsList_unstable`
  + AlertBox-threshold grafts), GOLDEN RULE (no roster), no-silent-ACP-drops (decode
  containment), security/honesty (nav-gate deny-by-default, DEBUG-only-cwd,
  env-hardening), exact ready language, resolver, boot-shim, affordance bridge,
  electron fallback. Web UI re-staged fresh to App Support.
- **Combined LIVE sweep: load-blocked, NOT failing.** Re-runs at machine load
  12.8–35 on 12 cores starved the fixed test timeouts; failure mode varied with load
  (catalog loaded 40 providers at load 12.8 → socket `.closed` at load 19) — the
  signature of CPU starvation, not a Goose regression. PM #11's clean 5/5 (78.8s, no
  competing build) is the control. To be re-run in a quiet window. No timeout
  weakening (would mask signal).
- **STEP-2 quality review** of this loop's grafts — no defects (graceful ACP-failure
  degradation, `USE_ACP_CHAT`-gated, tsc-enforced types, anchor-guarded).
- **Path B (goosed host) gating risk RESOLVED favorable** — `goosed agent` adds no
  new subprocess/sidecar surface; required network entitlements already ship. Awaits
  your go/no-go.

## 2026-06-29 PM — continuous-loop security hardening (re-prove + thermonuclear)

A fresh independent loop re-proved the live surface from scratch and ran a 3-reviewer
adversarial pass over all of `Epistemos/Goose/*`. Re-runnable re-proofs this loop:
`LIVE_ACP_SURFACE_PASS` (106 providers via `providers/catalog/list`), `NATIVE_MODELS_PARITY_PASS`
(65 providers, 53 with inline models), `NO_SILENT_DROPS_PASS` (3 unknown methods → structured
`-32601`), affordance-ledger completeness (54/54 `window.electron.*` calls covered), Keychain-only
secrets, app-target build green. The review CONFIRMED the load-bearing properties (no-silent-drops,
subprocess hardening, router-defaults-to-WebView, nav-gate deny-by-default, GOLDEN RULE clean, no
hidden sidecar, false-green honesty) and FOUND + FIXED real bugs (committed `e09513737` + a follow-up):

- **HIGH** web-affordance denylist was case-sensitive (`~/.SSH` bypass on case-insensitive APFS) and
  symlink-bypassable — now case-insensitive + symlink-resolved, denylist extended.
- **HIGH** Electron fallback launcher could exec a CWD `bin/pnpm` in shipped Pro builds — gated
  `#if DEBUG`.
- **HIGH** one malformed ACP frame tore down the whole connection — now per-frame contained.
- **MED** supervisor restart race could mark the live process failed — process-identity guard added.
- **MED** `openExternal` faked success on a denied scheme — now an honest error.
- **MED(sec)** a known request method with drifted params answered `-32601` (could disable the
  permission gate) — now `-32602` invalid-params; unknown methods still `-32601`.

Full ranked table + evidence: `GOOSE_PHASE_0_VERIFICATION_2026_06_27.md` (2026-06-29 continuous-loop
sections). These are SWIFT-side fixes → they need a **rebuilt** app to take effect (the Web-UI
bundle is unchanged). NOTE: the shared `build-for-testing` is currently blocked by an unrelated
Plan-3 test (`EpistemosTests/ArxivPlan3Tests.swift`) at HEAD — the Goose app target itself builds
green; the focused Goose unit suites re-run once the Plan-3 lane restores the test target.

## Remaining non-owner work before/after sign-off (tracked)

- Gate 3 live thinking chunk, or your explicit §7 amendment that Goose no longer
  emits it on the supported path.
- Gate 5: true confirm-dialog / MCP-app window affordances proven or honestly
  demoted; MAS honest-gate + manual WRV + distribution preflight.
- Deferred thermonuclear MED/LOW backlog (event-sink stream shape, queue bounds,
  CSP for MCP-app guest, staged-binary signature check, frame-scoped handlers,
  deinit drains, git-config neutralization) — future hardening loops.

**Sign-off:** reply with your decision once the manual pass + OAuth login above
are confirmed (or amend Gate 3). Until then Phase 0 stays open and no Phase 1 /
hybrid AppKit / Paseo work begins.
