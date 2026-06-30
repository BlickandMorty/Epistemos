# REMOVED FEATURES — KILL LIST / DO-NOT-RESURRECT (owner canon, 2026-06-30)

> **THE one doc every agent checks before "salvaging"/building anything.** These features were DELIBERATELY REMOVED by the
> owner. Do NOT resurrect, re-route, re-spec, or re-add them — anywhere, ever. Salvage/recon may ONLY route features that
> *accidentally* fell out, NEVER these. Source: read-only audit workflow `wf_22a0bafe` (5 agents; git-history + code +
> 7-plan + recon). KEEP arXiv + all current features (see KEEP). When a keep/cut is genuinely unclear it's parked under
> OWNER-CONFIRM — do NOT guess.

## ⚠️ NAME-COLLISIONS — these LOOK removed but are LEGIT-CURRENT (do NOT delete)
The owner may SEE these and think a removed thing came back. They did NOT — different feature, similar name:
- **`TriageService`** (complexity-routing: NotesOperation/GeneralOperation → local-vs-cloud model pick) — LIVE. NOT the removed triage/Review-Queue HUD.
- **`ChatTranscriptPresentation`** (current fused main chat transcript) + meeting/voice/Work transcripts — LIVE. NOT the removed native chat (`AgentChatState`, deleted).
- **`FSRSReviewSidebar`** (FSRS-6 forgotten-notes review) — LIVE. NOT the removed Review-Queue HUD.
- **Current Chat-vs-Act operating mode** (`CoworkChatMode`; Act == the agent loop) — LIVE. NOT the cut Act(Osaurus) engine.
- **Current Work/OpenGUI 6-engine harness** (`WorkEnginesPanelView`/`WorkEngineTranscript`/`WorkOpenGUISupervisor`) — LIVE. NOT the cut tri-surface federation stack.
- **`AgentRuntimeRiskLevel`** enum (StreamingDelegate:474, used by PipelineService) — LIVE. NOT the archived `AgentRuntime`.

## 🛑 KILL LIST — REMOVED, do NOT resurrect (17; evidence = deletion commits)
1. **Triage / Review-Queue HUD (⌘.)** — removed; AI = "just Goose". (still-routing → see RESURRECTION SOURCES)
2. **Raw-thoughts vault-visibility UI** (`RawThoughtsState`) — deleted `53227361b`; zero hits. (substrate = OWNER-CONFIRM). (still-routing)
3. **Old native chat surface** (`AgentChatState` + composer chrome: SlashCommandPopover, ToolActivityNarrator, ComposerMicButton…) — deleted `19418ea41`/`37db4d9a4`/`d51eddae3`. (recon row #36 "chat" preset is adjacent — flag)
4. **Old local + cloud AI agent surface** (Agent Command Center cluster + archived `AgentRuntime`/`ClaudeManagedRuntime`) — cluster-deleted; AI = "just Goose". **Dead residual on disk → DELETE (see build task).**
5. **Osaurus engine + Act-as-Osaurus** — deleted `3ebf98f7a`/`b7c449b55` (only comment ghosts remain).
6. **Three-engine modes** (Chat/Act/Work triad + mode toggles) — cut `b7c449b55`.
7. **Hermes namespace / legacy agent subprocess (Omega)** — purged 2026-05-05.
8. **Obscura** (custom browser/scraper engine) — cut `0cfb689b5` (browser = vendored browser-use, KEPT).
9. **ColBERT** local retrieval model — cut `0cfb689b5` (search = RRF+EML, KEPT).
10. **Local model management stack** (installer/downloader/model-server/runtime-picker/GGUF+MLX clients) — deleted. (MLX *runtime* itself = OWNER-CONFIRM)
11. **MLX image generation + on-device LoRA / MoLoRA adapters** — deleted `37db4d9a4`; LoRA-Studio declined (Plan 9).
12. **Federation / tri-surface OpenGUI-Work architecture + its 13 handoff docs** — deleted `cf7730010` (current single Work harness KEPT).
13. **Old code-editor implementations** (WebKit textarea editor, native SourceEditor fallback, live-highlighter scaffold) — deleted; replaced by MarkEdit. (v1-legacy fallback is a SEPARATE kept item — don't over-delete)
14. **CodeEdit SPM packages** — removed `f28c14a2a` (Epistemos's own `CodeEditor*` classes are NOT this).
15. **LSPServerProcess subprocess transport** — deleted `813c15dd` (in-process RustLSPTransport is the only LSP transport).
16. **Plan 8 — dedicated Theming/Appearance plan** — DECLINED (Plan 4 mono-icons survives separately).
17. **Plan 9 — Local-model knowledge & adapters** (items 39/42/43) — DECLINED; "do not resurface".

## RESURRECTION SOURCES still routing removed features (to mark OWNER-REMOVED)
- `PROMPT_PLAN_6_QUICKCAPTURE.md:47` done-gate still demands "review HUD triages a real deferred capture" (+ :25/:26 list item 4 in-scope).
- `LOST_ITEMS_RECON_2026_06_29.md` lines 61/65/102 still cluster item 4 (triage) / item 33 (raw-thoughts) into Plan 6.
- `LOST_ITEMS_RECON_2026_06_29.md:92` row #36 proposes a "chat" quick-capture preset (adjacent to removed chat).

## RESIDUAL DEAD CODE to DELETE (build-agent task — auditor is docs-only, cannot delete code)
Paste to a build agent (branch off main; deletions stay; build green):
1. **DELETE whole files** (dead: never instantiated / `@available(*,unavailable)` / zero consumers):
   `Epistemos/State/AgentCommandCenterState.swift`, `Epistemos/Engine/CommandInputParser.swift`,
   `Epistemos/Models/CommandTokenizer.swift`, `Epistemos/State/CommandCenterDiagnostics.swift`,
   `Epistemos/Engine/CommandCenterRequestCompiler.swift`, `Epistemos/Engine/AgentRuntime.swift`,
   `Epistemos/Engine/ClaudeManagedRuntime.swift`.
2. **DE-REFERENCE (edit, keep file):** `EpistemosConfig.swift` remove dead `cma.enabled`/`cma.defaultBudgetUSD` @AppStorage (~32-33); `AppBootstrap.swift` remove dead `commandCenter*HotkeyMonitor` props + teardown (~881-882, ~1920-1921, ~3588-3596).
3. **COMMENT SCRUB only:** `StreamingDelegate.swift:55`, `SkillDiscoveryCatalog.swift:45/318`, `WorkOpenCodeShell.swift:8/71/87`, `WorkBackendGateStatus.swift:6`, `WorkOpenCodeShellGateStatus.swift:9/25`.
4. **DO NOT TOUCH** (live / name-collision): `AgentRuntimeRiskLevel` (StreamingDelegate:474), `TriageService.swift`, `FSRSReviewSidebar.swift`, the Work seams, the raw-thought substrate (OWNER-CONFIRM pending), CodeEditorPolishTests, arXiv, all current features. Build green, keep deletions.

## ✅ KEEP (confirmed current — arXiv explicitly kept)
arXiv pull · Goose single agent surface (frame/Models picker/goosed+MAS-in-process backend/GOLDEN-RULE inventory) ·
editor lens model (Prose/Source/Note) + MarkEdit clone + Cmd+K + note AI-diff + width toggle + HTML Workspace (regenerate) +
wikilinks + web clipper + PDF viewer + graph inline-edit + provenance spine · Plan-3 caps (EdgeParse/liteparse PDF→md,
provenance moat, extensibility/skill-MCP/vault-as-MCP, QuickLook/Live-Text, landing buttons, native browser tab +
browser-use Pro robot, meeting/STT, voice TTS+STT, brand logos, RRF+EML search) · Plan 4 mono-icons (parked) · Plan 5
Companions (parked) · Plan 6 Quick-Capture+Undo+Action-Trace (parked, MINUS the triage HUD) · Plan 7 sync + quality gate (parked).

## ❓ OWNER-CONFIRM (genuinely unclear keep-or-cut — do NOT guess; owner decides)
- **MLX local text-inference lane** — CANON CONTRADICTION: CLAUDE.md calls MLX-Swift "the current live local inference lane"; the 5-plan canon says "AI = just Goose". Keep MLX or cut?
- **Provider-specific cloud agent** (#19) — marked OWNER-REMOVED in recon, but confirm it's fully dead vs a gated Goose-provider thing.
- **Per-model capability profile** (#15) · **llama.cpp/GGUF lane** (#16) · **Hyperdynamic determinism loop** (#25; primitives in `agent_core/src/hyperdynamic_loop/`) — local-inference items: keep or cut?
- **Agent cockpit right-side panel** (#11) — run rail (context/plan-DAG/tools); old "Act" home was cut, never re-homed. Keep (re-home to Goose) or cut?
- **Raw-thought SUBSTRATE** (taxonomy + `OpenRawThoughtSandboxIntent` + `QuarantineArchive`) — the *UI* is killed; is the substrate also cut, or kept?
- **Stealth/undetected browsing** (Camoufox/nodriver, Pro) — `PLAN_3_CAPABILITIES:419` says "re-confirm." Keep or cut?
