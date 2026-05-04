# Worktree Inventory — Epistemos — 2026-04-30

> **Scope:** Read-only inventory. No code changes. No merges. No stash pops.
> **Verified floor:** `ac8c6d28` on `feature/landing-liquid-wave`.
> **Authority:** `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md` + this file.

---

## 1. Main Repository

| Property | Value |
|---|---|
| Path | `/Users/jojo/Downloads/Epistemos` |
| Branch | `feature/landing-liquid-wave` |
| HEAD | `ac8c6d28` |
| Total status entries | **1292** |
| Modified (` M`) | **503** |
| Untracked (`??`) | **789** |
| Stashes | 4 |

### 1.1 Dirty-file summary (top lanes)

The 503 modified files span these lanes:

| Lane | Approx. file count | Notes |
|---|---|---|
| graph-engine (Rust) | 12 | **HIGH RISK — see §1.2** |
| agent_core (Rust) | ~35 | bridge, providers, oplog, artifacts, MCP, ETL |
| Swift App / Engine | ~60 | AppBootstrap, EpistemosApp, ChatCoordinator, MLXInferenceService, LSPClient, QuarantineArchive, MeaningAnchorService, MetalRuntimeManager, ModelDownloadManager, KnowledgeCoreBridge, ShadowFFIClient, RustShadowFFIClient, SSMMemorySidecar, SpotlightIndexer, Log, QueryRuntime, EpistemosSpeechAnalyzer, EpistemosSidecar, EpdocDocument, EpdocEditorBridge, EpdocProperty |
| Swift Graph | 1 | SemanticClusterService.swift |
| Swift Views | ~25 | HologramOverlay, ShadowPanel, ContextualShadowsPanel, ApprovalModalView, ChatInputBar, CodeEditorView, CodeLineGutter, NoteDetailWorkspaceView, NoteTableOfContents, SegmentedIndentationGuideView, RawThoughtsInspectorView, SettingsView, VoiceInputButton, EpdocEditorChromeView, EpdocKaTeXPreview |
| Swift State / Sync / Vault | ~15 | ContextualShadowsState, NightBrainScheduler, SearchIndexService, VaultIndexActor, VaultSyncService, SSMStateService, VaultLifecycleService, InstantRecallService |
| Swift LocalAgent / Omega | ~8 | LocalAgentLoop, IncrementalToolCallDetector, OmegaPermissions, TCCPermissionState, IMessageDriverService, CSISafeguard |
| Swift Models | 1 | SDPage+Queries.swift |
| Tests | ~25 | ContextualShadowsStateTests, HaloUITests, EpdocEditorBridgeTests, EpdocInfoPlistTests, EpistemosSidecarTests, InstantRecallTests, IncrementalToolCallDetectorTests, KnowledgeCoreBridgeTests, LocalAgentLoopTests, Mamba2MetalRuntimeTests, NoteEditorLayoutTests, PerformanceInstrPkgTests, ProductionHardeningTests, RawThoughtsStateTests, ReleaseScriptAuditTests, RuntimeCapabilityAndPerformancePolicyTests, RuntimeValidationTests, SSMMemorySidecarTests |
| Xcode project / plists / schemes | 4 | project.pbxproj, Epistemos-AppStore.xcscheme, Epistemos-AppStore-Info.plist, .vscode/settings.json |
| Docs (CLAUDE.md) | 1 | |

### 1.2 Graph-engine dirty diff — HIGH RISK, NOT APPROVED FOR MODIFICATION

**Status:** 12 files modified, **+1,008 / −118 lines**.

| File | Lines changed | Assessment |
|---|---|---|
| `graph-engine/src/knowledge_core/store.rs` | **+808 / −0** | Massive addition — new store impl; unverified against current Swift callers |
| `graph-engine/src/complexity_weight.rs` | +67 / −− | Physics parameter changes |
| `graph-engine/src/forces.rs` | +63 / −− | Force-model changes |
| `graph-engine/src/edge_trim.rs` | +43 / −− | Edge-trim logic changes |
| `graph-engine/src/motion/curl.rs` | +20 / −− | Motion/curl changes |
| `graph-engine/src/motion/waves.rs` | +40 / −− | Wave motion changes |
| `graph-engine/src/engine.rs` | +29 / −− | Core engine changes |
| `graph-engine/src/bolt_bridge.rs` | +17 / −− | BoltFFI bridge changes |
| `graph-engine/src/simulation.rs` | +12 / −− | Simulation changes |
| `graph-engine/src/types.rs` | +16 / −− | Type changes |
| `graph-engine/src/renderer.rs` | +7 / −− | Renderer changes |
| `graph-engine/src/lib.rs` | +4 / −− | Module registration changes |

**Decision:** These changes are **unaudited** and **not approved** for any Round 1–2 work. They must be treated as suspect until a dedicated deliberation brief is written, benchmarked, and approved by Codex. Any builder touching graph-engine must first prove build + test parity with `ac8c6d28` before and after.

### 1.3 Protected paths check

| Path | Dirty? | Verdict |
|---|---|---|
| `Epistemos/Views/Notes/ProseEditor*.swift` | **NO** | ✅ Protected surface clean |
| `Epistemos/Views/Graph/MetalGraphView.swift` | **NO** | ✅ Protected surface clean |
| `Epistemos/Views/Graph/HologramController.swift` | **NO** | ✅ Protected surface clean |
| `Epistemos/Views/Graph/HologramOverlay.swift` | **YES** | ⚠️ Overlay is NOT the protected controller; still avoid unless slice explicitly requires it |
| `Epistemos/Graph/SemanticClusterService.swift` | **YES** | ⚠️ Graph-adjacent service diff; note but not protected |

### 1.4 Stash inventory

| Stash | Branch | Description | Size | Handling |
|---|---|---|---|---|
| `stash@{0}` | `master` | W9.21 PR4 (honest-FFI Swift consumer cutover) + W9.8 (ApprovalModalView production wire) partial | 10 files, **+1,511 / −191** | **NOT VERIFIED.** Per `CODEX_VERIFIED_STATE_2026_04_25.md §1.0a`, recoverable but had NOT passed audit at cutoff. Do **not** pop without fresh deliberation brief + Codex approval. |
| `stash@{1}` | `master` | Codex WIP parallel during landing-wave session | 16 files, **+664 / −145** | Includes LandingWave Metal view changes, NodeInspectorState, PinnedInspector, NoteInsightService, LiveNoteScanner. **NOT VERIFIED.** Do not pop without audit. |
| `stash@{2}` | `main` | WIP on main at `31214a4d` | Unknown | Appears to be heuristic worktree residue. Do not pop without inspection. |
| `stash@{3}` | `main` | WIP on main at `29c0ca83` — "Fix: Invisible text in code editor — isRichText must be true" | Unknown | Appears to be editor fix residue. Do not pop without inspection. |

**Stash policy:** All four stashes are **suspect** per `CODEX_VERIFIED_STATE_2026_04_25.md §4`. Do not pop any stash without explicit Codex authorization and a re-audit checklist.

---

## 2. Worktree Inventory

### 2.1 Lane A

| Property | Value |
|---|---|
| Path | `/Users/jojo/Downloads/Epistemos-laneA` |
| Branch | `lane-A` |
| HEAD | `12183f29` |
| Dirty files | **1** (`Epistemos/Views/Approval/ApprovalModalView.swift`) |
| File count | 28,207 |

**Recent commits (top 5):**
1. `12183f29` — plan(tracker): mark N1 as 🟢 SHIPPED after b8d779ca + af0a0f21
2. `af0a0f21` — n1(phase-1): persist + render Anthropic prompt-cache hit rate
3. `b8d779ca` — n1(phase-1): extend AgentResultFFI with prompt-cache token fields
4. `b9a5312d` — n1(phase-1): wire cached_tokens_share into W9.6 CostDashboardView
5. `1ab15596` — n1(prompt-tree): Settings toggle

**Donor classification:** Control-plane / driver channel work. Substantially merged into main already (N1 PromptTree, W9.6 CostDashboard, W9.27 OpLog PR2).

**Raw-merge decision:** **REJECT.** Lane A is behind main on canonical commits. Its diff vs main shows deletions (`LocalModelInfrastructure.swift`, `InferenceState.swift`, `oplog.rs` content) rather than valuable additions.

**Salvage notes:** Nothing clearly unmerged. The single dirty file (`ApprovalModalView.swift`) may be a W9.8 partial that also exists in `stash@{0}`. If W9.8 is resurrected, use `stash@{0}` or re-implement clean, not Lane A.

### 2.2 Quick Capture / Agent-Core (`vigorous-goldberg-3a2d35`)

| Property | Value |
|---|---|
| Path | `/Users/jojo/Downloads/Epistemos/.claude/worktrees/vigorous-goldberg-3a2d35` |
| Branch | `claude/vigorous-goldberg-3a2d35` |
| HEAD | `0e0234d9` |
| Dirty files | **0** |
| File count | 27,930 |

**Recent commits (top 10):**
1. `0e0234d9` — Quick Capture Phase 12.5 — skill discovery
2. `3a5ea8f9` — Wave 6 prep — BrowserEngine trait
3. `4d2b9877` — Quick Capture D1 hardening — ExecutionReceipt
4. `f56e3bac` — Quick Capture Phase 11 — 30-case heal-recovery eval
5. `5d2139dd` — Quick Capture Phase 8 — ConceptGraphApplier + MemoryApplier
6. `ae06d054` — IntentDispatcher routes Intents to sub-appliers
7. `92156e23` — VaultIntentApplier closes Intent→Effect→Inverse loop
8. `0b39938c` — UndoEvictionTask wires undo log into NightBrain
9. `a6683f8e` — Model Workspace Protocol orchestrator
10. `eaa74d15` — NightBrain idle scheduler + idle monitor

**Donor classification:** Quick Capture, agent core, provenance, typed capture, tool registry, heal loop, semantic cache.

**Raw-merge decision:** **REJECT.** This branch contains a parallel tool registry (`ToolRegistry::execute_v2`), independent vault assumptions, and 50+ commits of substrate that drifted from main. Raw merge would create duplicate architecture.

**Salvage notes (conceptual only — extraction requires future deliberation briefs):**
- Tool trait + variant dispatch pattern (phases 2A–2G)
- Intent→Effect→Inverse loop + universal undo log
- Capture routing classifier (GBNF + centroid embedding + concept canonicalizer)
- ExecutionReceipt provenance pattern
- NightBrain idle scheduler wiring
- BrowserEngine trait (Wave 6)
- Semantic cache (SQLite-backed)

### 2.3 Simulation / Theater (`simulation`)

| Property | Value |
|---|---|
| Path | `/Users/jojo/Downloads/Epistemos/.claude/worktrees/simulation` |
| Branch | `worktree-simulation` |
| HEAD | `3163b170` |
| Dirty files | **0** |
| File count | 26,039 |

**Recent commits (top 10):**
1. `3163b170` — Sim Mode S11: Adapter gift-box system (.epbox + Mailroom)
2. `beb3baf5` — Sim Mode S10: Animated raster atlas pipeline
3. `f70b80d1` — Sim Mode S9: Hermes graph faculty + opulent landing ritual
4. `ec82d958` — Sim Mode S8: Companion creation flow
5. `6937be84` — Sim Mode S7: Graph Live Theater
6. `172cff1d` — Sim Mode S6: Notes Sidebar (knowledge-brick)
7. `d06d94d4` — Sim Mode v1.6 patch: overview vs drill-in graph modes
8. `c7de3e9e` — Sim Mode S5: Landing Farm placement
9. `9309b2c1` — Sim Mode S5 prep: activity-state persistence
10. `544fadc9` — Sim Mode S4: Theater Metal renderer

**Donor classification:** Pro-only Simulation Theater, companion/Hermes visuals, event-driven reducer, replay infrastructure.

**Raw-merge decision:** **REJECT.** Theater is explicitly Pro/direct-distribution. No Core/MAS leakage.

**Salvage notes:**
- AgentEvent normalization + replay infrastructure (S2)
- Event-driven reducer pattern (Rust → Swift actor bridge)
- Activity hysteresis + honesty audit ledger

### 2.4 Honest Handle / Single Binary / FFI Refactor (`agent-a0550f9c`)

| Property | Value |
|---|---|
| Path | `/Users/jojo/Downloads/Epistemos/.claude/worktrees/agent-a0550f9c` |
| Branch | `worktree-agent-a0550f9c` |
| HEAD | `6cd47481` |
| Dirty files | **3** (`Epistemos/Engine/RustShadowFFIClient.swift`, `agent_core/Cargo.lock`, `epistemos-shadow/src/honest_handle.rs`) |
| File count | 28,208 |

**Recent commits (top 5):**
1. `6cd47481` — audit(canonical): pass #3 — fuse docs/architecture/ findings
2. `766b38fe` — plan(tracker): mark W9.27 PR3 + D1 BLAKE3 Merkle chain 🟢 SHIPPED
3. `fe97e512` — w9.27+d1(oplog): add prev_hash BLAKE3 Merkle chain
4. `9750ad11` — plan(tracker): mark D4 🟢 SHIPPED
5. `4c0c7e17` — d4(faculty-roster): demote Hermes 4.3 36B → Qwen 3 8B fallback

**Donor classification:** High-risk FFI handle refactor (W9.21 PR1–PR2). Honest handles for substrate-rt, substrate-core, syntax-core.

**Raw-merge decision:** **REJECT.** The diff is 770+ lines in `honest_handle.rs` and 249 lines in `RustShadowFFIClient.swift`. FFI layout changes are crash-prone without benchmark + safety proof.

**Salvage notes:**
- `Arc::into_raw` handle discipline (safe pattern, not safe to merge blindly)
- Nil-engine guard patterns

### 2.5 Hermes Parity (`hermes-parity`)

| Property | Value |
|---|---|
| Path | `/Users/jojo/Downloads/Epistemos/.claude/worktrees/hermes-parity` |
| Branch | `worktree-hermes-parity` |
| HEAD | `465a3c30` |
| Dirty files | **0** |
| File count | 25,572 |

**Recent commits (top 10):**
1. `465a3c30` — Complete Hermes parity provider-chain and session persistence work
2. `5755f421` — P0 fixes: session UUIDs, TriageService fallback, Apple Intelligence
3. `7a1124cf` — Phase 9: Close 3 HIGH gaps — credential rotation, provider chain, session persistence
4. `1105bf10` — Phase 8: Critical hardening — retry logic, safety gates
5. `5463759d` — Phase 7: Add 6 PKM-specific tools beyond Hermes parity
6. `20c83b2d` — Phase 3-6: Error classifier, title generator, process registry, loop wiring
7. `58020e66` — Add rate_limit_tracker.rs
8. `b110c3a0` — Phase 2: Add 3 new tools + register all (22 total)
9. `1aded627` — Phase 1: Register 4 previously-unregistered tools
10. `005b40f5` — Unify agent system: remove Hermes subprocess, add model capability UI

**Donor classification:** Pro-only Hermes integration, tool registry gaps, provider chain, session persistence.

**Raw-merge decision:** **REJECT.** Hermes is Pro-only. MAS must not contain Hermes subprocess symbols.

**Salvage notes:**
- 5 orphaned tools to register (H.1 in `MASTER_FUSION.md §6.7`) — **Pro-only**
- Provider chain UI patterns — **Pro-only**
- Rate-limit tracker pattern — could be Core-safe if it doesn't spawn processes

### 2.6 Inspiring-Heisenberg (`inspiring-heisenberg-ea9dc3`)

| Property | Value |
|---|---|
| Path | `/Users/jojo/Downloads/Epistemos/.claude/worktrees/inspiring-heisenberg-ea9dc3` |
| Branch | `claude/inspiring-heisenberg-ea9dc3` |
| HEAD | `31214a4d` |
| Dirty files | **0** |
| File count | 27,774 |

**Recent commits (top 10):**
1. `31214a4d` — Update progress and mark three runtime issues as patched
2. `4f76a89c` — Session 6: Agent streaming instrumentation
3. `68a93eb1` — Session 3: Graph BoltFFI typed buffer prototype behind `bolt-graph` feature flag
4. `759f9101` — Session 5: syntax-core crate scaffolding
5. `678b75ce` — Session 1: Benchmark harness — os_signpost + criterion baselines
6. `76ae58a6` — Session 2: Swift 6 concurrency hardening
7. `ce1087bb` — Session 0: Editor doc-truth audit
8. `d20f416b` — Fix three runtime issues: beach ball, pinned inspector freeze, Vec drop crash
9. `428bb6f8` — Integrate §23-§27 from research synthesis into PLAN_V2
10. `47ee3c84` — Phase 7 Step 9: Wire Graph Chat receiver through ACC and Rust compile path

**Donor classification:** Benchmark harness, BoltFFI prototype, Swift 6 hardening, syntax-core scaffolding, runtime fixes.

**Raw-merge decision:** **REJECT.** BoltFFI prototype must not be enabled without benchmark baseline + parity proof.

**Salvage notes:**
- **Benchmark harness** (Session 1) — safe to extract as test-only scaffold
- **Swift 6 concurrency fixes** (Session 2) — evaluate individually for Core safety
- **Runtime fixes** (beach ball, pinned inspector freeze, Vec drop crash) — high value, evaluate individually

---

## 3. Summary Table

| Worktree | Branch | HEAD | Dirty | Files | Decision | Risk |
|---|---|---|---|---|---|---|
| Main | `feature/landing-liquid-wave` | `ac8c6d28` | 503 M / 789 ?? | ~28k | **Floor** — preserve | graph-engine diff is HIGH |
| Lane A | `lane-A` | `12183f29` | 1 | 28,207 | **Archive only** | High (deletions vs main) |
| Quick Capture | `claude/vigorous-goldberg-3a2d35` | `0e0234d9` | 0 | 27,930 | **Extract slices** | Very high if merged raw |
| Simulation | `worktree-simulation` | `3163b170` | 0 | 26,039 | **Pro donor only** | Moderate |
| Honest Handle | `worktree-agent-a0550f9c` | `6cd47481` | 3 | 28,208 | **Defer until benchmark** | Very high (FFI layout) |
| Hermes Parity | `worktree-hermes-parity` | `465a3c30` | 0 | 25,572 | **Pro donor only** | High (Pro leak risk) |
| Inspiring-Heisenberg | `claude/inspiring-heisenberg-ea9dc3` | `31214a4d` | 0 | 27,774 | **Extract benchmark harness** | Moderate |

---

## 4. Next Recommended Phase

Per `CODEX_UNIFIED_EXECUTION_PROMPT_2026_04_30.md §3` and `BUILDER_EXECUTION_PROMPT_2026_04_30.md`:

1. **Phase 0 completion** (this doc + `RESEARCH_FUSION_NOTES` + `FUSED_IMPLEMENTATION_QUEUE`)
2. **Build/test floor verification** — `xcodebuild build` + `cargo test` on dirty main; protected-path re-audit
3. **Liquid Wave active slice preservation** — assess whether stash@{1} LandingWave changes need rescue
4. **Quick Capture fusion sprint** — only after floor is green and deliberation brief approved
5. **Phase S/App Store release closure** — S.1 dogfood, S.7–S.9 metadata/TestFlight/submission
6. **Halo V1 proof** — wire live recall loop if genuinely broken

**Implementation is blocked until Codex approves a deliberation brief for the next slice.**
