# EPISTEMOS — MASTER RESEARCH SYNTHESIS + DEPENDENCY-ORDERED BUILD ROADMAP (2026-06-19)

**READ-FIRST CAPSTONE.** Unifies all 15 deep-research docs into one plan. The build loop should
read THIS first, then the per-slice docs for detail. Cited per claim by source slice.

> OWNER HARDENING MANDATE (2026-06-19): every new thing must be **deeply hardened BEFORE and
> AFTER** it is added; the app is **repaired before and after**; each port gets an **AFTER-PORT
> INSPECTION** that leaves **no gaps**; target **enterprise-level** robustness. Harden→add→re-harden
> →post-inspect is the per-item lifecycle for every roadmap entry below. See §3 constraint 7.

---

## 1. THE KEYSTONE — *built-then-not-wired*

One root cause explains the entire "the app feels broken" complaint. The failures are NOT missing
capability and NOT "we hand-rolled what a clone does better." Epistemos already adopted the proven
cores (HF `HubClient`, `llguidance` grammar, Hermes-3 tool format, Goose recipe types) and already
built the proper abstractions — **then left them disconnected at the last mile while a cruder older
heuristic does the live work, or compiled them out of the shipping build, or pointed two halves at
different directories.** [S1 keystone; converges with S4]

The owner's four reported breakages share this one cause: *the surfaces the owner sees are wired
correctly to events that never fire, because the producers of those events are dead/gated/stubbed/
mis-pathed one layer down.* Almost everything is WIRE / DELETE / FLIP, not import-a-clone.

| # | Instance | Mechanism | Source |
|---|---|---|---|
| 1 | **RuntimeRouter is DEAD** (`RuntimeRouter.swift:580`, zero callers) | "everything→Qwen-3-4B" exists because the proper router never got wired; live path uses a hardcoded Qwen list (`AgentCommandCenterState.swift:580-600`) | S1, S7·G-1 |
| 2 | **Chats never ENTER the tool loop** | local Gemma `canActAsAgent=false` no backup Qwen (`PipelineService:316/342`); non-OpenAI/Anthropic cloud gets no tools (`supportsAgentTier:1347`). UI boxes intact, empty only because no calls fire | S4, S6 |
| 3 | **Auto-route machinery OFF** | `AUTO_TOOL_ROUTE_V0`/`SCHEMA_PREFLIGHT_V0`/`GGUF_TOOL_GRAMMAR_V0` never "1" → every fix flag-OFF=not live | S4, S7·R-3 |
| 4 | **Skills compiled-OUT of MAS + 4-way path mismatch** | progressive skills `#[cfg(pro-build)]` (`registry.rs:963`); 4 disjoint dirs; 7 `SKILL.md` in `.agents/skills/` no loader reads | S1, S4 |
| 5 | **Constrained decoder is a FAKE stub** | `MLXConstrainedGenerator` no masking; `isAvailable` false. Win: bridge Rust `llguidance` into MLX | S1·T1 |
| 6 | **Staging-purge defeats download-resume** | 30-min unconditional purge kills resume on big models (=corrupt root); STEP 3 added a parallel dir but did NOT condition the purge = partial-fix masquerading | S1·D2, S7·G-4 |
| 7 | **Goose Work engine inert** | `runWorkSession` throws `engineNotWired`; vendored types unconsumed | S1·W1, S6 |
| 8 | **Self-evolution/procedural-memory dead** | no caller; `procedural_memory` records never written | S1·S2, S4 |
| 9 | **Hermes session-search mis-directed** | scans `<vault>/sessions/` while index crawls `<vault>/chats/` → may return ZERO hits (OQ-1) | R2, S6, S17 |
| 10 | **ArtifactHostView is a stub** | every route "Deferred in v1", 0 refs — while HTMLWorkspace+data.json+PatchRouter already exist | S6, S16, S14 |

---

## 2. BUILD-ONCE-REUSE PRIMITIVES (build each ONCE so slices compose, not collide)

- **(a) WebKit-host kit** — custom-URL-scheme handler + `build-*-bundle.sh` + shared `processPool`/`dismantleNSView`. Needs: OpenClaw, terminal, HTML-canvas, KaTeX, Mermaid, StreamHtml. Template = the Epdoc trio (copy verbatim). [S14, OpenClaw, S2]
- **(b) Pixel-skin CSS injector** — `EpistemosWebTheme.applyScript(for:namespace:)` from `EpdocEditorThemeStyle` (Epdoc byte-identical). Pair native: `PixelSkinTokens` on `ResolvedTheme` + collapse the 3-way `PixelPanelModifier` branch. Needs: Epdoc/OpenClaw/code-editor/terminal/canvas. [S2, S3]
- **(c) Tree-sitter syntax highlighter** — *the single highest-leverage shared fix.* One wire fixes chat code blocks (R-ELEMENTS), HTMLWorkspace code panes (P7.2 "can't see code"), Streamdown highlight. Highlighter already exists for the editor. [S14]
- **(d) Shared progressive-render primitive** — one unterminated-block-tolerant renderer + one DOMPurify/rehype-harden sanitizer. Needs: Streamdown, GenUI SpecStream, R-LIVE-ARTIFACTS data.json, StreamHtml. [S14, S16]
- **(e) Sandbox seam** — `host / Lume-VM / Apple-container`, bound per engine. Lume (Swift MIT) = full desktop-guest VM (Pro); Apple Containerization (apache-2.0) = headless Linux micro-VM (Work). Two tiers, ONE seam. Needs: browser/computer-use, Work code-exec, Osaurus VM. [S10]
- **(f) Shared tool/capability registry + memory substrate** — ONE `register_default_tools` (`registry.rs:923`); each engine binds its OWN `with_tier` (capability shared by DEFINITION, invocation per-engine); Act⊇Chat by the ordered tier ladder, not by calling Chat. Registry correct; memory seam designed-but-unwired (sessions untagged, `sessions/` unindexed). [S17]

---

## 3. GOVERNING CONSTRAINTS (gate everything)

1. **No cross-engine import (isolation).** Already TRUE (`ChatCoordinator` 0 Act/Work refs). Don't add Work/lane logic to InferenceState/ChatCoordinator; selection is presentation state. Promote `WorkBackendSeamTests` into a general CI `epistemos_doctrine_lint` gate. [S17]
2. **Flag-OFF ≠ done.** DONE = owner can SEE+USE. A FLIP-FLAGS+in-app-verify slice gates any tick. [S7·R-3]
3. **MAS-honesty firewall.** `#if !EPISTEMOS_APP_STORE` + Inert `isLive=false` + seam THROWS not silent-cloud. Always-compile GateStatus+HealthRow; show a value only when armed; orange witness chip until passing. MAS = `network.client` only (no server, no subprocess). [S3, OSAURUS map]
4. **Never-delete / Pro-gate.** Don't blind-delete the PRUNE list (ConfidenceRouter in-flight → KEEP+flag). Port/subprocess/VM/Node/vendored = Pro. [S7·R-4, S3]
5. **App-native-by-embedding + ProvenanceGate.** Host clone web UIs in WKWebView + re-point transport to the in-process engine (don't SwiftUI-rewrite — that's what forced OpenClaw off MAS). Record `VendorProvenance`. License flags: browser-use/Osaurus/Hermes/OpenClaw/cua-Lume = MIT; AI-Elements/Streamdown = Apache-2.0; **LFM2-ColBERT = "LFM Open License v1.0" (not MIT/Apache); stealth nodriver = AGPL-3.0; Holo Apache-2.0 base=Qwen3.5.** [OpenClaw, S10, S12]
6. **WebKit-maximization (native carve-out).** WKWebView for genuinely-web surfaces (terminal/canvas/OpenClaw/Mermaid); native where it wins (AI-Elements/json-render/chat primitives). [S14]
7. **OWNER HARDENING LIFECYCLE (2026-06-19, enterprise-level).** Every roadmap item follows: **(i) harden BEFORE** — repair/secure the surrounding code + add the guard/witness/test before adding the new thing; **(ii) add**; **(iii) re-harden AFTER** — security/perf/honesty pass on the added code; **(iv) AFTER-PORT INSPECTION** — a gap-hunt that asserts no seam, fallback, leak, or honesty hole was introduced (WKWebView teardown, no-silent-fallback, isLive honesty, provenance, flag state, rollback). No item is "done" until its after-port inspection passes with zero gaps. This composes with constraint 2 (flag-OFF≠done) and the witness/T4-promotion rule.

---

## 4. DEPENDENCY-ORDERED MASTER ROADMAP (each item: `[source · MAS/Pro]`; each follows the §3.7 harden→add→re-harden→inspect lifecycle)

### PHASE 0 — FIX-THE-BROKEN (the keystone; mostly WIRE/FLIP/DELETE; precondition for all value)
1. **WIRE RuntimeRouter; collapse 4→R1+R2; fold the `AgentCommandCenterState:580` Qwen list into R1; DELETE dead R4** (after rehosting `routeProfiles()`); honest "no local→nil" survives. `[S1·G-1 · MAS]`
2. **Attach tools for plain chat on ALL cloud providers** (not just OpenAI/Anthropic). `[S4·G-2 · MAS]` — biggest visible win.
3. **Local Gemma tool path**: live-wire `schemaGgufToolDispatchJson` + allow `canActAsAgent` for the GGUF lane; honest "toolless" until then. `[S4 · MAS/Pro]`
4. **Condition the staging-purge on active-download + bounded retry** (still unconditional at `LocalModelInfrastructure:2593/2629`). `[S1·D2/S7·G-4 · MAS]`
5. **Skills repair**: un-gate progressive skills honestly (MAS or "Pro only"); UNIFY the 4 dirs; point the loader at `.agents/skills/`; fix `skill_manage` v2 schema; close the 4 schema↔impl drifts. `[S1/S4·G-3 · MAS]`
6. **FLIP + VERIFY gating slice**: set the 4 flags, verify visible tool/Eidos boxes in-app; **block the TOOLS/SKILLS tick until this passes.** `[S7·R-3 · MAS]`
7. **Plan-honesty sweep**: un-tick false `[x]`'s (1024/1026/1027; R-LITEPARSE→`[~]`); stamp picker 402/458 superseded (C3). `[S7]`
8. **HTML-WORKSPACE-CAN'T-EDIT** (owner-confirmed, still unresolved): code panes are plain `NSTextView` (no highlight, "can't see code"); `safeAPI` message handler is an empty stub (no two-way edit drive); preview uses `loadHTMLString(baseURL:nil)`; no live patch→WKWebView push. Fix all four. `[S14·P7.2 · MAS]`

### PHASE 1 — FOUNDATIONS (shared primitives + the missing axis)
9. **Model the Chat/Act/Work axis primitive** (#1 structural prep): `CoworkChatMode.work` + `ActLane{openClaw,osaurusLocal}` as RootView presentation state — NOT in InferenceState/ChatCoordinator. `[S6/S17 · MAS]` — blocks all engine work.
10. **Generalize the isolation guardrail → `EngineIsolationDoctrineTests` + a gate in `epistemos_doctrine_lint` (CI)** — do 2nd so every later step is fenced. `[S17 · MAS]`
11. **`PixelSkinTokens` on `ResolvedTheme` + collapse the 3-way `PixelPanelModifier` branch** (pixel unconditional, 8 sites). `[S2 · MAS]`
12. **`EpistemosWebTheme.applyScript(for:namespace:)`** generalized injector (Epdoc repoint = no-op). `[S2 · MAS]`
13. **WebKit-host kit hardening** (shared processPool + dismantleNSView base for every web surface). `[S14 · MAS]`
14. **Tree-sitter highlighter into chat + HTMLWorkspace panes** (one wire, three surfaces — also fixes #8's "can't see code"). `[S14 · MAS]`
15. **Memory-seam wiring**: engine/kind tag on `SessionHandle` + enroll `<vault>/sessions/` in the shadow crawl (resolves OQ-1; unblocks Hermes session-search). `[S17/R2 · MAS]`

### PHASE 2 — ENGINES (gated; only after Phase 1 fences)
16. **Hermes 4 lifts into the in-process LocalAgent brain (NOT onto Osaurus)**: session.search→summarize over the fused index; **deterministic** Swift compactor (a model call mid-turn deadlocks the MainActor client); named prompt tiers (folded-skills=CONTEXT not stable); richer auto-skill triggers (needs procedural records written). `[Hermes/R2 · MAS, exec Pro]`
17. **Act 2-lane picker**: `ActEngine` + one ChatCoordinator branch (mirror WorkBackendFactory); generator-closure swap in `LocalAgentLoop` for `.osaurusLocal` (token serving only; IP stays in brain). RuntimeRouter ≠ Act picker. `[Osaurus/R2 · Pro]`
18. **Surface the existing browser-use family** as a first-class Pro-gated approval-required skill via the shared registry (Chat-aware + Act-home + reachability test) — code exists, just starved. `[S10 · Pro]`
19. **Define + bind the Sandbox seam** per engine. `[S10 · Pro]`
20. **Terminal UI port**: xterm.js bundle → WKWebView fed by the real Rust `terminal.rs`; **home in Work** (wire inert `work.rs`/`WorkBackend`); keep the triple MAS barrier. `[S14/S10 · Pro]`
21. **Work=Goose**: wrap the core behind the seam when armed (`EPISTEMOS_WORK_GOOSE_V0`); Shell exec Pro+hardened. `[S1·W1/S5 · Pro]`
22. **OpenClaw WebKit-host**: bundle + scheme handler + transport→in-process `agent_core` via `AgentStreamEventDelegate` (no new FFI); HIDE its config-form; pixel-skin chat only; Node gateway Pro/dev. `[OpenClaw/R2/S3 · Pro]`
23. **Computer-use deepening**: cua action-schema + composed grounding; Holo vision lane (`GgufVisionCliProvider`+mmproj, base=Qwen3.5); Lume native lift; stealth via stealth-browser-mcp (AGPL-nodriver vs Patchright-Apache decision). `[S10 · Pro]`

### PHASE 3 — SUPERSESSION FEATURES (some lowest-risk wins parallelizable with Phase 2)
24. **R-LIVE-ARTIFACTS**: `ArtifactRoute.htmlWorkspace` → `HTMLWorkspacePreviewView`; data.json subscribes to a saved RRF/DAG feed → PatchRouter live-patch (no reload). Same surface as #8. `[S16/S14 · MAS core, Pro feeds]` — lowest-risk supersession win.
25. **R-VAULT-MCP-SERVER**: `epistemos_mcp_server.rs` ([[bin]]) wrapping the existing StdioServer+MCPDispatcher+VaultExecutor over **stdio** (dodges no-network.server); auto-gen AGENTS.md+.mcp.json. `[S16 · Pro]` — other lowest-risk win (anti-Tolaria).
26. **R-WEBCLIP**: Share Extension → app-group → file-watcher drains to SDPage+`.md`; pure-Rust readability+html2md FFI beside liteparse. `[S16/S5 · MAS core, Pro full-page]`
27. **Consolidate MCP-install** into ONE native panel (OpenClaw/Osaurus/Goose register through it) + connectors UI (P2.7). `[S3/S5 · MAS]`
28. **ColBERT tool-selector**: `ToolScorer{lexical|colbert}` trait swap; in-process GGUF embedding FFI + Rust MaxSim; same retriever upgrades vault RAG. **Strictly downstream of loop-entry.** `[S12 · Pro]`
29. **Streamdown/StreamHtml polish**: unterminated-block tolerance + KaTeX-in-chat + tiny WebKit Mermaid. `[S14 · MAS]`
30. **R-SYNC (LAST)**: iCloud-Drive + invert SoT (`.md`→SoT, `.epcache` never syncs); Pro git lane via `vault_git.rs`. Highest blast radius (`VaultSyncService` 176KB). `[S16/S5 · MAS, HIGH risk]`
31. **R-VOICE** (additive over the real Apple TTS/STT seam) + **prune orphan views IN PAIRS** with their dead Rust twins. `[S6/S5 · MAS]`

---

## 5. CONTRADICTIONS / RISKS THE ROADMAP MUST RESPECT [S7]
- **C3:** picker placement (1170 vs 402/458) — stamp superseded (P0·7).
- **C4/R-4:** RuntimeRouter both badge-source AND dead-to-wire; ConfidenceRouter on PRUNE list but in-flight → KEEP+flag.
- **R-1 (high):** P3.0 "import Osaurus frontend+entitlements verbatim" would BREAK the MAS sandbox — point to OSAURUS_ACT_CONNECTION_MAP.
- **R-2:** advertised-filter × auto-route × Qwen-substitution — ship G-1 + honest-nil BEFORE the filter; add a test.
- **R-3:** flag-OFF ≠ done (P0·6 gate).
- **R-5:** isolation vs shared-Goose-core — shared core only behind the capability-registry (enforced by P1·10 lint).
- **Convergence (S6/S17):** ChatCoordinator + InferenceState = meeting point of tools-repair + model-stack + 3-engine — sequence, don't collide; keep engine/lane selection OUT of them.
- **OQ-1:** verify `sessions/` vs `chats/` layout BEFORE the session-search lift.
- **MAS firewall fragility:** every armed conformer keeps `isLive=false` until live + no silent cloud.
- **WKWebView teardown leak:** every 2nd+ web surface replicates dismantleNSView + shared pool.

---

## 6. THE 10 HIGHEST-LEVERAGE ACTIONS (ranked)
1. Attach tools for plain chat on ALL cloud providers — biggest visible win. `[S4]`
2. WIRE RuntimeRouter (+collapse to R1+R2, fold the Qwen list) — durable Qwen-pin fix. `[S1·G-1]`
3. FLIP the 4 flags + verify in-app — converts on-paper into live. `[S7·R-3]`
4. Tree-sitter highlighter into chat + canvas + Streamdown — one wire, three "can't see code" surfaces (incl. the HTML-workspace edit complaint). `[S14]`
5. Skills: un-gate + unify dirs + fix `.agents/skills` path. `[S1/S4·G-3]`
6. Condition the staging-purge on active-download. `[S1·D2]`
7. Model the Chat/Act/Work axis primitive (presentation-only). `[S6/S17]`
8. Generalize the isolation guardrail into a CI doctrine-lint gate. `[S17]`
9. R-VAULT-MCP-SERVER + R-LIVE-ARTIFACTS — two lowest-risk highest-supersession wins. `[S16]`
10. Surface the existing browser-use family via the shared registry. `[S10]`

**Net:** the app feels broken for ONE reason (built-then-not-wired). Phase 0 is almost entirely
WIRE/FLIP/DELETE and unlocks the rest. Build the six reusable primitives once; fence everything
behind the isolation lint + MAS-honesty firewall + the owner hardening lifecycle (harden→add→
re-harden→after-port-inspect, no gaps); sequence the convergence files and R-SYNC last.
