# Goose Master Build Prompt — Full Program (Phase 0 → Hybrid AppKit)

**Paste this entire block to the building agent.** One goal, one sequential program. Do not mark the goal complete until **every phase exit criterion** below passes.

---

```
Do not stop until the owner says stop.

You are building the SINGLE Epistemos agent surface = Goose (reskinned), end-to-end:
Phase 0 (Goose fully connected + proof gate) → Phase 1–4 hybrid AppKit (native chat +
long-tail WebView until per-route gates). This is ONE program with ordered gates — NOT
a scaffold milestone you can close early.

═══════════════════════════════════════════════════════════════════════════════
CURRENT STATE (2026-06-27 — read before coding)
═══════════════════════════════════════════════════════════════════════════════

Codex previously marked "goal complete" too early. The 2026-06-27 hardening
slice proved live ACP/WebView transport, the real Goose Electron fallback
launcher, the top native file/dialog/external-URL affordances, the read-only
custom ACP minimum, typed/unit-proven provider-settings read ACP, live read-only
WebView route smoke for providers/settings/extensions/skills, live provider
config save/read/delete ACP, structured
unhandled-ACP diagnostics, and golden F1-F5 ACP fixtures, but Phase 0 is still
NOT signed off (~85% architecture, ~92% proof
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
  read-only WebView route smoke proves providers/settings/extensions/skills
  render against live `goose serve`; provider authenticate/settings mutation
  parity remains open
- Golden F1-F5 ACP fixtures are captured from live `goose serve`, sanitized,
  revision-pinned, and covered by Swift decoder/shape tests
- Top native affordances are implemented/proven:
  directoryChooser, showOpenDialog, showSaveDialog, selectFileOrDirectory,
  selectImportSessionFile, openExternal, openInChrome, openDirectoryInExplorer
- 9 long-tail boot-shim keys still deferred-with-visible-error:
  showMessageBox, getBinaryPath, readFile, writeFile, ensureDirectory,
  launchApp, refreshApp, closeApp, openNotificationsSettings
- Remaining _goose/unstable/* ACP extension methods beyond the read-only
  minimum, provider-settings reads, and provider config save/delete are unwired
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

NON-NEGOTIABLES:
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
  - DONE 2026-06-27: staged Web UI ACP provider overlay renders
    configure-providers, models settings, extensions, and skills routes against
    live `goose serve`; evidence:
    `/tmp/epistemos-goose-phase0-webview-route-smoke.log`
  - Continue wiring Skills/provider authenticate/settings mutation parity OR codegen from
    acp-meta.json for the remaining custom methods
  - DONE 2026-06-27: GooseACPEventBridge stops silently dropping unsupported
    custom requests; it logs/surfaces diagnostics and returns JSON-RPC
    method-not-found replies
  - Provider authenticate/settings mutation and deeper Skills/provider/settings parity
    remain blockers unless routed to honest blocked UI

P0.5 Live proof gate (§7 — ALL required)
  [x] Real Goose Electron launches (in-app comparison fallback menu item)
  [x] goose serve :3284 /health ok + ACP WS connects reliably
  [ ] new session → prompt → stream (thinking + answer + tools) → permission → result → end_turn
      Current live proof covers answer/tool/permission/result/end_turn; live provider did not emit thought chunk
  [x] Staged WebView boots on exercised path with ACP config + native affordance bridge
  [ ] MAS build shows honest Pro gate only
  [ ] Capture: log excerpt + WRV script + proof artifacts (not PNG-only)
  [ ] Document honest gaps vs Electron for routes not exercised

P0.6 Golden fixtures (Phase 0 completion)
  - DONE 2026-06-27: captured F1–F5 from live goose serve →
    EpistemosTests/Fixtures/GooseACP/
  - DONE 2026-06-27: scripts/generate-goose-acp-fixtures.mjs launches local
    `goose serve`, records ACP WebSocket frames, normalizes volatile ids/paths,
    stores Goose revision metadata, and exits cleanly
  - DONE 2026-06-27: GooseACPGoldenFixtureTests decode every captured frame
    through Swift ACP models and pin initialize, session/new, prompt answer,
    permission/tool-result, and read-only custom ACP shapes
  - NEXT 2026-06-27: first unsolved Phase 0 blocker is provider authenticate/
    settings mutation parity plus deeper Skills/provider/settings parity or an
    honest blocked UI where not wired

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

Step 2 — AgentTranscript reducer
  - Epistemos/Agent/AgentTranscript.swift + tests vs F1–F5 fixtures
  Exit: thinking ≠ answer; tool ≠ prose; 5 fixture tests pass

Step 3 — Native shell MVP + hybrid content router
  - AgentSurfaceWindowController, AgentRouteContentView
  - Native: AgentHubView, AgentSessionCanvasView, composer, permission/elicitation
  - Embedded WebView panel for long-tail routes (Skills, Recipes, Extensions, etc.)
  - AgentSessionController actor; useNativeChatPath=false until Step 9
  Exit: full chat loop on NATIVE path; long-tail opens WebView in same window

┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 2 — Entry + navigation + settings (Steps 4–6)                         │
└─────────────────────────────────────────────────────────────────────────────┘

Step 4 — Landing tile + ⌘⇧A + cwd picker + diagnostics row
Step 5 — AgentNavigationRailView (8 destinations + recent sessions + hybrid router)
Step 6 — AgentSettingsView (Models, Chat, Auth, App tabs native; unproven tabs WebView)
  - OAuth via ACP authenticate (Goose owns provider tokens — not UserDefaults)

┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 3 — Feature parity + Epistemos bridge (Steps 7–8)                     │
└─────────────────────────────────────────────────────────────────────────────┘

Step 7 — Per-route native gates; flip useWebViewFor* only when fixtures+WRV pass
Step 8 — epistemos.context.snapshot (vault note attach to composer)

┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 4 — Chat-primary default (Step 9 / Gate 7)                            │
└─────────────────────────────────────────────────────────────────────────────┘

Step 9 — useNativeChatPath=true default; long-tail WebView intentional;
  full-window WebView = regression compare only ("Open Goose Web fallback")

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

Native v1 (must be capability-neutral vs WebView chat):
  Landing entry, hub, session canvas, transcript, composer, permission/elicitation,
  session header, sessions list, configure-providers, permission settings,
  proven settings tabs (Models, Chat, Auth, App, Keyboard)

WebView long-tail until per-route gate:
  Skills, Recipes, Extensions, Scheduler, Apps, shared-session, standalone-app,
  unproven settings tabs (Sharing, Prompts, Local Inference)

One Agent window. AgentRouteContentView switches native vs embedded WebView.
100% Goose capability overall — no thin native stubs.

═══════════════════════════════════════════════════════════════════════════════
DEFINITION OF DONE (entire goal — NOT before all pass)
═══════════════════════════════════════════════════════════════════════════════

The goal is complete ONLY when ALL of:

□ Phase 0 §7 proof gate + signoff doc with live evidence
□ Steps 1–9 exit criteria (follow-on plan §5)
□ Hybrid charter satisfied (native chat default; long-tail WebView where unflipped)
□ Pro build: Landing → Agent → native chat loop → stream → permission works
□ Long-tail routes reachable (native or full-capability WebView panel)
□ Focused Goose tests + build-for-testing green; no new regressions
□ MAS honest gating verified
□ Real Goose Electron fallback works from Epistemos menu
□ GOOSE_PHASE_0_SIGNOFF.md + GOOSE_PHASE_4_COMPLETE.md (or equivalent) written

FORBIDDEN "done" claims:
× Build-green or unit tests on mock transport alone
× PNG proof without reproducible WRV script
× Phase 0 closed with ACP WebSocket still failing
× Epistemos/Agent/* started before Phase 0 hardening
× Reviving Chat/Act/Work/AgentClone surfaces
× Wiring REST goosed agent or Electron IPC for agent path
× Bulk deleting WebView before per-route native gates pass
× Paseo §15 before Step 9

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

*Master prompt v1 — 2026-06-27. Supersedes partial Codex goal scope.*
