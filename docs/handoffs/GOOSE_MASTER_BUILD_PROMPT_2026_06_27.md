# Goose Master Build Prompt — Full Program (Phase 0 → Hybrid AppKit)

> 🛑 **SUPERSEDED 2026-06-29 (Option 1 + Unification).** §7 is GREEN-LIT (Plan 1 is ON Phase 1). There is **NO
> native chat** and **NO Gate-7 chat-primary flip** — chat + every Goose feature stays in the **reskinned WebView,
> PERMANENTLY** (NATIVE = the frame + the Models picker only). Any "native chat / chat-primary / Gate 7 / Phase 0
> not signed / wait for §7 sign-off" text below is HISTORICAL — do not act on it. Canon:
> `docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md` + `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.

**Paste this entire block to the building agent.** One goal, one sequential program. Do not mark the goal complete until **every phase exit criterion** below passes.

---

```
Do not stop until the owner says stop.

You are building the SINGLE Epistemos agent surface = Goose (reskinned), end-to-end:
Phase 0 (Goose fully connected + proof gate) → Phase 1 native FRAME only (window / nav /
launcher + the permission pop-ups) wrapped around Goose's reskinned WebView. NO Goose
feature is EVER reimplemented in Swift — every feature stays in Goose's WebView,
permanently. This is ONE program — NOT a scaffold milestone you can close early.

═══════════════════════════════════════════════════════════════════════════════
CURRENT STATE (2026-06-27 — read before coding)
═══════════════════════════════════════════════════════════════════════════════

Codex previously marked "goal complete" too early. The 2026-06-27 hardening
slice proved live ACP/WebView transport, the real Goose Electron fallback
launcher, the top native file/dialog/external-URL affordances, the read-only
custom ACP minimum, typed/unit-proven provider-settings read ACP, live read-only
WebView route smoke for providers/settings/extensions/skills, live provider
config save/read/delete ACP, live settings mutation ACP, structured
provider authenticate fail-closed rejection ACP, live Skills source-list/export
ACP for project and built-in skills, live isolated project Skill source
create/update/delete/import ACP, structured unhandled-ACP diagnostics, and golden
F1-F5 ACP fixtures, but Phase 0 is still
NOT signed off (~90% architecture, ~96% proof
gate). See:
docs/handoffs/GOOSE_PHASE_0_STATUS_AUDIT_2026_06_27.md

Known gaps you MUST close:
- In-app Electron comparison fallback is wired/proven via the Swift menu launcher
  and Hermit pnpm/CDP; the launcher must keep Electron Forge stdin open; keep it
  green while closing the rest of Phase 0
- GooseWebUI staging is proven on this machine; add fresh-machine health/staging
  guidance so it is durable
- Live Swift ACP proves initialize/new/prompt/answer/permission/tool-result;
  `agent_thought_chunk` is codec/client-covered but was not emitted by the live
  provider in the current proof run
- Live Swift custom ACP proves read-only providers, config extensions,
  preferences, defaults, session info, and diagnostics; provider supported-models,
  config-read, and config-status are typed/unit-proven; provider config
  save/read/delete is live-proven in an isolated home with file-backed secrets;
  settings preference save/read/remove plus defaults-save are live-proven in an
  isolated home with a disposable configured provider; provider authenticate
  non-OAuth rejection is live-proven with preserved JSON-RPC error data and no
  config mutation; Skills source-list/export for project and built-in skills is
  typed, unit-proven, and live-proven against real `goose serve`; project Skill
  source create/update/delete/import is typed, unit-proven, and live-proven
  against real `goose serve` in an isolated temp project;
  read-only WebView route smoke proves providers/settings/extensions/skills
  render against live `goose serve`; owner/browser-mediated OAuth authenticate
  success and deeper provider/settings parity remain open
- Golden F1-F5 ACP fixtures are captured from live `goose serve`, sanitized,
  revision-pinned, and covered by Swift decoder/shape tests
- Top native affordances are implemented/proven:
  directoryChooser, showOpenDialog, showSaveDialog, selectFileOrDirectory,
  selectImportSessionFile, openExternal, openInChrome, openDirectoryInExplorer
- 9 long-tail boot-shim keys still deferred-with-visible-error:
  showMessageBox, getBinaryPath, readFile, writeFile, ensureDirectory,
  launchApp, refreshApp, closeApp, openNotificationsSettings
- Remaining _goose/unstable/* ACP extension methods beyond the read-only
  minimum, provider-settings reads, provider config save/delete, settings
  mutation, and Skills source-list/export/mutation are unwired
- No Epistemos/Agent/* yet (correct — starts after Phase 0 sign-off)
- GooseACPEventBridge now surfaces unsupported custom requests in diagnostics
  and returns JSON-RPC method-not-found errors; use those diagnostics to close
  the remaining methods

Keep what works: Epistemos/Goose/* supervisor, standard ACP client, boot shim ledger,
native permission/elicitation panels, MAS gate, menu ⌘3.

═══════════════════════════════════════════════════════════════════════════════
READ FIRST (canon order)
═══════════════════════════════════════════════════════════════════════════════

1. docs/handoffs/GOOSE_PHASE_0_STATUS_AUDIT_2026_06_27.md — honest starting point
2. docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md
   — §0, §2–§7, §9-C (live), §14, §15–§17. IGNORE ⛔ DEAD/SUPERSEDED sections.
3. docs/handoffs/GOOSE_AGENT_APPKIT_FOLLOWON_PLAN_2026_06_26.md — hybrid-by-route +
   Steps 0–9 (build authority after Phase 0)
4. docs/handoffs/GOOSE_APPKIT_SURFACE_MAPPING_2026_06_26.md — screen map
5. docs/handoffs/GOOSE_NATIVE_NEW_SURFACE_RESEARCH_ROUND1_2026_06_26.md
6. docs/handoffs/GOOSE_NATIVE_NEW_SURFACE_RESEARCH_ROUND2_2026_06_26.md
7. Optional: docs/handoffs/GOOSE_SURFACE_CLAUDE_HANDOFF_2026_06_24.md (reskin log)

═══════════════════════════════════════════════════════════════════════════════
ARCHITECTURE (unchanged)
═══════════════════════════════════════════════════════════════════════════════

- ONE surface: Goose. NO Chat/Act/Work federation. NO AgentClone revival.
- Engine: supervised `goose serve` on loopback :3284, ACP WebSocket /acp?token=…
- Phase 0: Goose web UI in WebView/WebPage + narrow boot shim + native permission/elicitation
- Phase 1+: Epistemos/Agent/* hybrid — native chat path + embedded WebView for long-tail routes
- NOT full window.electron IPC emulation for agent path — agent traffic is ACP (USE_ACP_CHAT)
- NOT REST goosed agent path — use goose serve + ACP only
- NOT UniFFI embed of Goose into app binary — subprocess + ACP forever on Pro/Developer-ID
- MAS: honest Pro gate, no hidden spawn

★★★ GOLDEN RULE — CATALOG FIDELITY (the bar that was missed; non-negotiable) ★★★
Epistemos MUST enumerate Goose's provider/model/skill/extension inventory through the SAME
ACP/catalog paths Goose itself uses — dynamically, at runtime, from `goose serve`. NEVER a
Swift-hardcoded, manually-maintained, or app-duplicated list. Everything the user sees IS
Goose, enumerated by Goose. If the agent is "adding" or "remembering" any catalog item
itself, it is WRONG — that defeats the entire point of running the real clone.
  • Today the Swift product code already obeys this (no hardcoded catalogs; the staged Web UI
    overlays Goose's ACP `_goose/unstable/providers/*`). The failure is PROOF + SURFACING, not
    hardcoding — so it must be live-PROVEN (P0.7) and the catalog must be reachable + usable
    (browse + pick + add providers/models via the ACP-fed UI, keys bridged from the Keychain).

NON-NEGOTIABLES:
• GOLDEN RULE (above): inventory is ALWAYS enumerated live from Goose via ACP — never a
  Swift-hardcoded/app-maintained list. Live-prove it (P0.7); the user must never have to
  manually add what Goose already provides.
• Goose stays independently GREEN (§17). Two gates in order: (1) Goose green standalone,
  (2) Epistemos integration. Always verifiable via real Goose Electron + goosed.
• ADD, DON'T EDIT on Goose Rust core (§14.3). Epistemos wiring lives in Epistemos/Goose/*
  and Epistemos/Agent/* across ACP seam + reskin overlay.
• Build Paseo features from SPEC (§15/§15.7) ONLY AFTER Phase 0 sign-off + hybrid Steps 1–9
  chat-primary flip — NEVER vendor Paseo AGPL code (§15.6).
• Commit at clean points. Clone has its own git.
• Zero test regressions against full Epistemos test suite when feasible; at minimum run
  focused Goose tests + build-for-testing after each gate.

═══════════════════════════════════════════════════════════════════════════════
PROGRAM STRUCTURE — execute in order; do not skip gates
═══════════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 0 — GOOSE FULLY CONNECTED (WebView + ACP proof)                       │
│ Exit: owner-ready proof gate §7 — BEFORE any Epistemos/Agent/* work         │
└─────────────────────────────────────────────────────────────────────────────┘

P0.1 Runtime + ACP transport hardening
  - Fix live ACP WebSocket: secretKey sync (bootstrap ↔ supervisor ↔ shim getSecretKey),
    token percent-encoding, WS upgrade proof BEFORE marking runtime .running
  - Surface full ACP error in diagnostics (no truncation)
  - Supervisor: optional ACP initialize probe before .running (not health-only)
  - Integration test spawning REAL goose serve (not GooseACPMemoryTransport only)
  - Kill stale :3284 orphans; document spawn lifecycle

P0.2 Web UI staging (durable)
  - bash stage-goose-web-ui.sh → ~/Library/Application Support/Epistemos/GooseWebUI/
  - Verify .epistemos-goose-webui.json acpMode: true
  - Add doc/CI note or Settings health row so fresh machines know to stage
  - WebView must load reskinned UI, not placeholder HTML

P0.3 Boot shim — finish blocking affordances
  - DONE 2026-06-27: implemented/proved native bridge for directoryChooser,
    showOpenDialog, showSaveDialog, selectFileOrDirectory, selectImportSessionFile,
    openExternal, openInChrome, openDirectoryInExplorer
  - Continue with honest long-tail shims or visible blocked UI:
    showMessageBox, getBinaryPath, readFile, writeFile, ensureDirectory,
    launchApp, refreshApp, closeApp, openNotificationsSettings
  - Future hybrid AgentNativeAffordances may reuse this Goose bridge; do not start
    Epistemos/Agent/* before Phase 0 sign-off
  - Exercised chat path must NOT hit deferred-with-visible-error

P0.4 Extended ACP minimum (Skills + providers usable)
  - DONE 2026-06-27: read-only minimum proves providers, config extensions,
    preferences, defaults, session info, and diagnostics live against goose serve
  - DONE 2026-06-27: provider supported-models, config-read, and config-status
    methods are typed and unit-proven in GooseACPClientTests
  - DONE 2026-06-27: provider config save/read/delete is typed/unit-proven and
    live-proven against real `goose serve` using isolated HOME/file-backed
    secrets; evidence:
    `/tmp/epistemos-goose-phase0-provider-config-mutation.log`
  - DONE 2026-06-27: settings preference save/read/remove and defaults-save are
    typed/unit-proven and live-proven against real `goose serve` using isolated
    HOME/file-backed secrets plus a disposable configured provider; evidence:
    `/tmp/epistemos-goose-phase0-settings-mutation.log`
  - DONE 2026-06-27: staged Web UI ACP provider overlay renders
    configure-providers, models settings, extensions, and skills routes against
    live `goose serve`; evidence:
    `/tmp/epistemos-goose-phase0-webview-route-smoke.log`
  - DONE 2026-06-27: provider authenticate non-OAuth rejection is typed/unit-
    proven and live-proven against real `goose serve` with isolated HOME/file-
    backed secrets; evidence:
    `/tmp/epistemos-goose-phase0-provider-authenticate-rejection.log`
  - DONE 2026-06-27: Skills source-list discovery for project and built-in
    skills is typed/unit-proven and live-proven against real `goose serve`;
    evidence: `/tmp/epistemos-goose-phase0-acp-custom-readonly.log`
  - DONE 2026-06-27: project Skill source export is typed/unit-proven and
    live-proven against real `goose serve` with valid portable JSON evidence in
    `/tmp/epistemos-goose-phase0-acp-custom-readonly.log`
  - DONE 2026-06-27: project Skill source create/update/delete/import is
    typed/unit-proven and live-proven against real `goose serve` in an isolated
    temp project with cleanup; evidence:
    `/tmp/epistemos-goose-phase0-source-mutation.log`
  - Continue wiring owner/browser-mediated OAuth authenticate success OR codegen
    from acp-meta.json for the remaining custom methods
  - DONE 2026-06-27: GooseACPEventBridge stops silently dropping unsupported
    custom requests; it logs/surfaces diagnostics and returns JSON-RPC
    method-not-found replies
  - OAuth authenticate success and deeper provider/settings parity remain
    blockers unless routed to honest blocked UI

P0.5 Live proof gate (§7 — ALL required)
  [x] Real Goose Electron launches (in-app comparison fallback menu item)
  [x] goose serve :3284 /health ok + ACP WS connects reliably
  [ ] new session → prompt → stream (thinking + answer + tools) → permission → result → end_turn
      Current live proof covers answer/tool/permission/result/end_turn; live provider did not emit thought chunk
  [x] Staged WebView boots on exercised path with ACP config + native affordance bridge
  [ ] MAS build shows honest Pro gate only
  [ ] Capture: log excerpt + WRV script + proof artifacts (not PNG-only)
  [ ] Document honest gaps vs Electron for routes not exercised
  [ ] Live-prove the PRODUCTION chat path — the embedded WEB UI's ACP client → end_turn,
      NOT only the Swift test client. Live tests must FAIL LOUD when the goose binary is
      absent (never silently skip/pass)
  [ ] Portable: surface works on a CLEAN build (bundled/staged binary + Web UI) OR honestly
      gates when absent — not "works on this machine only"

P0.6 Golden fixtures (Phase 0 completion)
  - DONE 2026-06-27: captured F1–F5 from live goose serve →
    EpistemosTests/Fixtures/GooseACP/
  - DONE 2026-06-27: scripts/generate-goose-acp-fixtures.mjs launches local
    `goose serve`, records ACP WebSocket frames, normalizes volatile ids/paths,
    stores Goose revision metadata, and exits cleanly
  - DONE 2026-06-27: GooseACPGoldenFixtureTests decode every captured frame
    through Swift ACP models and pin initialize, session/new, prompt answer,
    permission/tool-result, and read-only custom ACP shapes
  - NEXT 2026-06-27: first unsolved Phase 0 blocker is OAuth authenticate
    success plus deeper provider/settings parity, or an honest blocked UI where
    not wired

P0.7 GOLDEN RULE — catalog fidelity (live parity, ALL required)
  [ ] Live catalog-parity test: fetch provider/model inventory ONLY via ACP ext methods
      (providers/list, setup/catalog/list, supported-models/list), compute a sorted
      providerId digest + count, assert parity vs the real Goose Electron app on the SAME
      config dir. Any drift = FAIL
  [ ] Live-prove catalog/list, setup/catalog/list, supported-models/list against real
      `goose serve` (not typed/unit only)
  [ ] Replace WebView route-smoke greps for hardcoded brand names with ACP-DERIVED
      expectations (assert against what ACP actually returned)
  [ ] CI/grep gate: NO provider/model roster literals in Epistemos/Goose/**/*.swift
  [ ] SURFACED + USABLE: the ACP catalog + model picker is a reachable entry (don't bypass
      onboarding when zero providers configured); adding a provider works, with the API key
      bridged from the Epistemos Keychain → goose (GooseACPClient.saveGooseProviderConfig).
      Fix the env denylist that strips all provider keys (GooseRuntimeSupervisor) — allowlist
      them OR make the Keychain bridge the sole, deliberate path. Model-switch persists across
      restart (defaultsSave)
  [ ] Phase 1 native models/provider UI (AgentSettingsModelsSection / AgentProviderSetupView)
      BLOCKED until each route proves ACP-fed inventory, never a Swift-duplicated picker

PHASE 0 EXIT: Write docs/handoffs/GOOSE_PHASE_0_SIGNOFF.md with checklist + evidence.
STOP and ask owner to approve Phase 1 start (Step 0 sign-off). If owner pre-approved
this master prompt, treat Phase 0 exit as internal gate then continue automatically.

┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 1 — HYBRID APPKIT (native chat + WebView long-tail)                   │
│ Authority: GOOSE_AGENT_APPKIT_FOLLOWON_PLAN Steps 1–3                       │
└─────────────────────────────────────────────────────────────────────────────┘

Step 1 — ACP infrastructure (complete ext client + shims)
  - GooseACPExtClient + generated ext methods
  - Recipe param requests, session/update side-effects in bridge
  - Remaining long-tail deferred shims implemented or visibly blocked (reuse/extend Goose native affordance bridge)
  Exit: ext decode tests green; cwd/import/dialogs work in WebView + native shim

Step 2 — [DELETED 2026-06-27] No native transcript reducer. The chat transcript is a
  Goose FEATURE and stays in Goose's WebView, unchanged.

Step 3 — Native FRAME only (NO native chat, NO native feature)
  - AgentSurfaceWindowController + native nav rail + landing entry = the app FRAME.
  - Permission/elicitation render natively (already built + proven); the WebView
    forwards them to the native panels.
  - The content area hosts GOOSE'S RESKINNED WEBVIEW for ALL features — chat included.
  - There is NO AgentSessionCanvasView, NO native composer, NO useNativeChatPath.
  Exit: native frame hosts Goose's WebView; Goose's own chat runs in the WebView, unchanged.

┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 2 — Entry + navigation + settings (Steps 4–6)                         │
└─────────────────────────────────────────────────────────────────────────────┘

Step 4 — Landing tile + ⌘⇧A + cwd picker + diagnostics row (frame only)
Step 5 — AgentNavigationRailView (native nav rail; content slot = Goose WebView)
Step 6 — [DELETED 2026-06-27] No native settings/providers/auth MANAGEMENT. Settings,
  providers, and OAuth are Goose features and stay in Goose's WebView — Goose owns provider
  tokens, enumerated via its own ACP (GOLDEN RULE). ⚠️ CARVE-OUT (2026-06-29, Option 1): the
  Models PICKER is the ONE native route, already built (`GooseNativeModelsView`, Steps 1–3) —
  KEEP it native; do NOT revert it to web. Only the Models picker is native; settings/providers/
  auth management stay WebView.

┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 3 — Feature parity + Epistemos bridge (Steps 7–8)                     │
└─────────────────────────────────────────────────────────────────────────────┘

Step 7 — [DELETED 2026-06-27] No per-route native flips, no useWebViewFor* gates. Every
  Goose feature stays in the WebView PERMANENTLY. There is no "eventually native."
Step 8 — epistemos.context.snapshot (vault note attach — passed into the WebView composer)

┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 4 — Chat-primary default (Step 9 / Gate 7)                            │
└─────────────────────────────────────────────────────────────────────────────┘

Step 9 — [DELETED 2026-06-27] There is NO "native chat default." Chat IS Goose's WebView,
  permanently. Native never becomes the chat path.

┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 5 — Paseo strategic fusion (ONLY AFTER Step 9)                        │
└─────────────────────────────────────────────────────────────────────────────┘

Per SURFACE §15/§15.7 — build from spec, never vendor AGPL:
  (1) engine picker surfacing ACP family
  (2) multi-tab/split workspace
  (3) inline diff + gh PR/merge
  (4) worktree-isolated parallel runs
Notes/vault: markdown source-of-truth data layer (§16)

═══════════════════════════════════════════════════════════════════════════════
HYBRID-BY-ROUTE (owner canon — do not regress to "100% AppKit day one")
═══════════════════════════════════════════════════════════════════════════════

NATIVE — the COMPLETE, FIXED native set (reimplements NO Goose feature):
  app window/chrome, native nav rail, landing entry, and the permission/elicitation
  pop-ups (already proven native; the WebView forwards them). That is ALL.

GOOSE'S RESKINNED WEBVIEW — PERMANENT (every Goose feature; no "until a gate"):
  chat / transcript / streaming / composer, providers, models, settings, sessions,
  skills, recipes, extensions, scheduler, MCP apps, shared-session, standalone-app.
  These are NEVER rebuilt in Swift and are NEVER "flipped" native by this plan.

One Agent window. AgentRouteContentView switches native vs embedded WebView.
100% Goose capability overall — no thin native stubs.

═══════════════════════════════════════════════════════════════════════════════
DEFINITION OF DONE (entire goal — NOT before all pass)
═══════════════════════════════════════════════════════════════════════════════

The goal is complete ONLY when ALL of:

□ Phase 0 §7 proof gate + signoff doc with live evidence
□ GOLDEN RULE proven (P0.7): provider/model/skill inventory live-enumerated via ACP with
  parity vs real Goose; ZERO hardcoded rosters; keys bridged from Keychain; picker surfaced + usable
□ LOSE NOTHING: every Goose capability proven live through the PRODUCTION (web UI) path; zero
  deferred-with-visible-error among affordances the UI actually calls; recipe-trust persists (no re-prompt loop)
□ Portable: works on a clean build (bundled/staged) or honestly gates when absent
□ Native FRAME (window/nav/launcher) hosts Goose's reskinned WebView; permission/elicitation native; NO Goose feature reimplemented in Swift
□ Pro build: Landing → Agent window → Goose's WebView chat loop → stream → permission works
□ Every Goose feature reachable + full-capability in the WebView
□ Focused Goose tests + build-for-testing green; no new regressions
□ MAS honest gating verified
□ Real Goose Electron fallback works from Epistemos menu
□ GOOSE_PHASE_0_SIGNOFF.md written

FORBIDDEN "done" claims:
× Build-green or unit tests on mock transport alone
× PNG proof without reproducible WRV script
× Phase 0 closed with ACP WebSocket still failing
× Epistemos/Agent/* started before Phase 0 hardening
× Reviving Chat/Act/Work/AgentClone surfaces
× Wiring REST goosed agent or Electron IPC for agent path
× Reimplementing ANY Goose feature in native Swift (chat, providers, models, settings, sessions, skills, recipes, extensions, scheduler, apps)
× "Eventually" / "before ship" nativizing a Goose feature — native is the FIXED frame ONLY; any future feature-nativization is a SEPARATE owner decision with its own 100%-parity proof, NOT this plan
× Paseo §15 before Phase 0 sign-off
× ANY Swift-hardcoded / app-duplicated provider/model/skill roster (GOLDEN RULE violation)
× Catalog not live-proven via ACP parity vs real Goose
× "Works on my machine" — surface depends on un-bundled local artifacts
× Production (web UI) chat path untested while only the Swift client is proven

═══════════════════════════════════════════════════════════════════════════════
WORK DISCIPLINE
═══════════════════════════════════════════════════════════════════════════════

- After EACH gate (P0.1…P0.6, Steps 1–9): run verification, update
  docs/handoffs/GOOSE_BUILD_PROGRESS.md with ✅/❌ and evidence path
- Deep hardening before features: fix transport before UI polish
- If blocked >30min on ACP WS: capture stderr, token, lsof :3284, diagnostics panel
- Prefer minimal diffs; read before write; match Epistemos patterns (@Observable, Swift Testing)
- When unsure: real Goose Electron baseline wins — Epistemos must not be worse

Branch: feat/goose-surface (or owner-directed)
Stop only when owner says stop OR entire DEFINITION OF DONE is ✅ with evidence.
```

---

*Master prompt v1.1 — 2026-06-27. v1.1 adds the GOLDEN RULE (catalog fidelity, P0.7) + lose-nothing / production-path / portability gates. Supersedes partial Codex goal scope.*
