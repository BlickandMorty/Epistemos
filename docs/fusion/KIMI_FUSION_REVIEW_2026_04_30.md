# Kimi Fusion Review - 2026-04-30

## Verdict
Use / revise / block.

**Use** the April 30 fusion packet as the active execution authority.
**Revise** the queue to prioritize build-floor verification and Halo wiring before any worktree extraction.
**Block** raw merges of any worktree, Pro-only leakage into Core, and any edit to protected surfaces without Codex approval.

## Canonical Direction
One substrate spine ships Core-first: `TypedArtifact -> MutationEnvelope -> RunEventLog -> AgentEvent -> GraphEvent -> Halo / Graph / Theater / Audit`. The V1 wedge is Halo + Contextual Shadows as a locally-running, debounced, provenance-rich recall surface. Pro tunnels (Hermes, CLI, MCP, Theater) stay behind explicit gates. Quick Capture remains sibling-canonical and must be extracted as small, substrate-aligned slices—not flattened into trunk by branch merge.

## Sources Reviewed

### Repo authority (read in full)
1. `/Users/jojo/Downloads/Epistemos/AGENTS.md`
2. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`
3. `/Users/jojo/Downloads/Epistemos/docs/architecture/BOLTFFI_AUDIT_2026_04_15.md`
4. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/CODEX_VERIFIED_STATE_2026_04_25.md`
5. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/MASTER_FUSION.md`
6. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/MASTER_BUILD_PLAN.md`
7. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/RESEARCH_INDEX_BY_FEATURE.md`
8. `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md`

### Fusion packet (read in full)
9. `/Users/jojo/Downloads/Epistemos/docs/fusion/README_START_HERE_2026_04_30.md`
10. `/Users/jojo/Downloads/Epistemos/docs/fusion/CANONICAL_SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md`
11. `/Users/jojo/Downloads/Epistemos/docs/fusion/BUILDER_EXECUTION_PROMPT_2026_04_30.md`
12. `/Users/jojo/Downloads/Epistemos/docs/fusion/KIMI_RESEARCH_AND_FUSION_PROMPT_2026_04_30.md`
13. `/Users/jojo/Downloads/Epistemos/docs/fusion/KIMI_SESSION_CONTEXT_2026_04_30.md`
14. `/Users/jojo/Downloads/Epistemos/docs/fusion/CODEX_ACTIVE_OVERSEER_KIMI_PROMPT_2026_04_30.md`

### April 30 source docs (read in full)
15. `/Users/jojo/Downloads/EPST_UNIFIED_SUBSTRATE_MASTER_PLAN_2026_04_30.md`
16. `/Users/jojo/Downloads/SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md`
17. `/Users/jojo/Downloads/CODEX_UNIFIED_EXECUTION_PROMPT_2026_04_30.md`

### External research (scanned via targeted rg)
18. `/Users/jojo/Downloads/Pasted markdown.md` — scanned full; claims Contextual Shadows not wired end-to-end
19. `/Users/jojo/Downloads/ambient/EPISTEMOS_V1_DECISION.md` — scanned full; Halo V1 scoping
20. `/Users/jojo/Downloads/Advice/perplexity 2.md` — scanned; CLI/MCP tunnel design (Pro-only)
21. `/Users/jojo/Downloads/final/`, `/Users/jojo/Downloads/final v2/`, `/Users/jojo/Downloads/final v3/` — keyword-searched

### Worktrees (status + log + diff inspected)
22. Main: `/Users/jojo/Downloads/Epistemos` — HEAD `ac8c6d28`, branch `feature/landing-liquid-wave`, 40+ dirty files
23. Lane A: `/Users/jojo/Downloads/Epistemos-laneA` — HEAD `12183f29`, branch `lane-A`, 1 dirty file (`ApprovalModalView.swift`)
24. Quick Capture: `/Users/jojo/Downloads/Epistemos/.claude/worktrees/vigorous-goldberg-3a2d35` — HEAD `0e0234d9`, 50+ commits (Phases 0–12.5)
25. Simulation: `/Users/jojo/Downloads/Epistemos/.claude/worktrees/simulation` — HEAD `3163b170`, 17 commits (Sim Mode S0–S11)
26. Honest Handle / FFI: `/Users/jojo/Downloads/Epistemos/.claude/worktrees/agent-a0550f9c` — HEAD `6cd47481`, 3 dirty files (RustShadowFFIClient, honest_handle.rs, Cargo.lock)
27. Hermes parity: `/Users/jojo/Downloads/Epistemos/.claude/worktrees/hermes-parity` — HEAD `465a3c30`, 17 commits
28. Inspiring-heisenberg: `/Users/jojo/Downloads/Epistemos/.claude/worktrees/inspiring-heisenberg-ea9dc3` — HEAD `31214a4d`, 19 commits (BoltFFI proto, benchmark harness, syntax-core, Swift 6 hardening)

### Main repo code evidence (rg + file reads)
29. `Epistemos/Engine/HaloController.swift` — exists, `@MainActor @Observable`, 6-state FSM
30. `Epistemos/Engine/HaloEditorBridge.swift` — exists, NSTextView delegate bridge
31. `Epistemos/Engine/ShadowSearchService.swift` — exists, ShadowFFI search wrapper
32. `Epistemos/Models/MutationEnvelope.swift` — exists, mirrors Rust `agent_core::mutations::MutationEnvelope`
33. `agent_core/src/mutations/envelope.rs` — exists, parity-tested
34. `Epistemos/Views/Capture/QuickCaptureView.swift` — exists, basic sheet UI
35. `Epistemos/Intents/Custom/NoteActionIntents.swift` — `QuickCaptureIntent` exists
36. `Epistemos/Engine/EpdocDocument.swift` — `.epdoc` NSDocument subclass exists
37. `Epistemos/Engine/SwiftTreeSitterLiveHighlighter.swift` — exists, 15 language bindings
38. `EpistemosTests/HaloControllerTests.swift`, `HaloUITests.swift`, `ContextualShadowsStateTests.swift`, `MutationEnvelopeParityTests.swift` — exist

## Superseded Sources

- **`MASTER_FUSION_OVERLAY_2026_04_30.md` / `MASTER_BUILD_PLAN_OVERLAY_2026_04_30.md` / `WORKTREE_FUSION_PROTOCOL.md` / `QUICK_CAPTURE_TO_MAIN_MERGE_PLAN.md` / `QC/FINAL_SYNTHESIS.md`** — referenced by older prompts but not found at expected paths. Do not treat as authority. Use the repo-local fusion packet and April 30 Downloads docs instead.
- **Advice docs suggesting "no subprocesses ever"** — superseded by the corrected policy: **no hot-path subprocesses**. Core/MAS can use App Intents, Spotlight, and menu-bar capture. Pro can use explicit capability tunnels.
- **Research claiming BoltFFI 1000× speedup** — marked `[UNVERIFIED]` in canonical docs. Do not treat as shipping doctrine.
- **Private ANE / activation steering / infinite-context claims** — research-only gates. Not Core/MAS.
- **Any doc claiming Contextual Shadows is "fully wired" without pointing to a live debounce→encode→search→panel code path** — must be rechecked against current code.

## Nuance To Preserve

### Halo / Contextual Shadows
The V1 differentiator is NOT just a search box. It is a **6-state FSM** (`dormant → watching → encoding → searching → available → open`) with a **trailing-edge debounce**, **Model2Vec + usearch + Tantivy + RRF** stack, and **non-activating NSPanel** presentation. The `HaloController`, `HaloEditorBridge`, and `ShadowSearchService` exist in main, but the live typing loop may not be fully wired end-to-end (per `Pasted markdown.md` C1). The nuance: preserve the FSM semantics, performance budgets, and provenance attachment even if the UI path needs completion.

### Quick Capture
The `vigorous-goldberg` worktree contains **50+ commits** of substantial capture infrastructure: Tool trait + variant dispatch, Intent→Effect bridge, universal undo log, NightBrain idle scheduler, semantic cache, route capture with GBNF classifier, heal loop, ExecutionReceipt, and BrowserEngine trait. The nuance: these are **donor concepts**, not a merge target. The safe extraction is: capture routing grammar, typed undo envelope, and App Intent wiring. Reject: any flattening of QC's independent tool registry into main's agent loop without substrate alignment.

### Raw Thoughts / Provenance
`MutationEnvelope` and `RunEventLog` are real in both Swift and Rust with parity tests. The four-layer event hierarchy (RunEventLog → MutationEnvelope → AgentEvent → GraphEvent) is canonical. Preserve: append-only integrity, BLAKE3 Merkle chain (commit `fe97e512`), and the rule that UI success cannot emit before durable commit succeeds.

### Code Editor
`SwiftTreeSitterLiveHighlighter` exists with 15 language bindings. The verdict is locked: **TextKit 2 surface + SwiftTreeSitter live + Rust background brain + SourceKit-LSP**. Do not replace with CodeEditSourceEditor or Flutter/AppFlowy. Preserve the UTF-8→UTF-16 range mapping discipline.

### .epdoc / Documents
`EpdocDocument` (NSDocument subclass) exists with Tiptap-in-WKWebView bridge. The editor verdict says leave Tiptap alone for V1.5. Preserve: the `.epdoc` package bundle shape, block-level FTS5 projection, and UTType registration.

## Worktree Salvage Map

### Lane A (`Epistemos-laneA`, `12183f29`)
- **keep:** Nothing obviously valuable unmerged. Lane A is **behind** main on canonical commits and its diff vs main shows **deletions** (`LocalModelInfrastructure.swift`, `InferenceState.swift`, `oplog.rs` content) rather than additions.
- **reject:** Raw merge. The lane appears to have been a control-plane experiment that was either superseded or partially reverted.
- **risk:** High. Merging would delete verified work.
- **recommended extraction:** None. Archive the branch for reference only.

### Quick Capture (`vigorous-goldberg-3a2d35`, `0e0234d9`)
- **keep:** Tool trait pattern (`Tool` + `ToolRegistry::execute_v2`), Intent→Effect→Inverse loop, universal undo log, semantic cache (SQLite-backed), route capture classifier (GBNF + centroid + concept), ExecutionReceipt, BrowserEngine trait, NightBrain idle scheduler wiring.
- **reject:** Raw merge of the entire branch. The worktree has its own tool registry, dispatch surface, and vault assumptions that drift from main's current substrate. Do not overwrite `agent_core` tools.
- **risk:** Very high if merged broadly. The QC tool registry is parallel architecture, not substrate-aligned.
- **recommended extraction:**
  1. `QuickCaptureIntent` App Intent wiring (already partially in main).
  2. Typed capture artifact envelope (source/provenance attached).
  3. Universal undo log schema (if it can map to `MutationEnvelope`).
  4. Semantic cache pattern for capture routing.

### Simulation / Theater (`simulation`, `3163b170`)
- **keep:** AgentEvent normalization + replay infrastructure, event-driven reducer pattern, activity hysteresis, honesty audit ledger.
- **reject:** Full Theater UI, companion creation flow, Bevy ECS, opulent landing ritual, gift-box adapter system. These are Pro/product-theater work.
- **risk:** Moderate. The event normalization is useful for Core; the visual systems are Pro-only.
- **recommended extraction:** AgentEvent replay infrastructure as a **Pro-only** module gated behind `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.

### Honest Handle / FFI (`agent-a0550f9c`, `6cd47481`)
- **keep:** Handle safety patterns (`Arc::into_raw` discipline), nil-engine guards, typed buffer layout ideas.
- **reject:** Broad FFI replacement. The diff is 770+ lines in `honest_handle.rs` and 249 lines in `RustShadowFFIClient.swift`. This is high-risk without benchmark harness first.
- **risk:** Very high. FFI layout mismatches = instant crashes.
- **recommended extraction:** None until `EpistemosTests/GraphFFIBenchmarkTests.swift` baseline is recorded and a deliberation brief is approved.

### Hermes Parity (`hermes-parity`, `465a3c30`)
- **keep:** 5-phase parity plan (H.1–H.5), tool registry gap analysis, provider chain patterns, session persistence design.
- **reject:** Raw merge of the branch into Core. Hermes is explicitly **Pro-only** per every canonical doc.
- **risk:** High if leaked into MAS. The branch contains subprocess-aware tool logic.
- **recommended extraction:** Register orphaned tools in `agent_core/src/tools/registry.rs` **only** behind Pro gates. Wire provider chain UI in Settings as Pro-only.

### Inspiring-heisenberg (`inspiring-heisenberg-ea9dc3`, `31214a4d`)
- **keep:** Benchmark harness scaffolds (os_signpost + criterion), BoltFFI typed buffer prototype **behind `bolt-graph` feature flag**, Swift 6 concurrency hardening fixes, syntax-core crate scaffolding.
- **reject:** Enabling the BoltFFI prototype in production without parity + benchmark delta proof.
- **risk:** Moderate. The benchmark harness is safe to land. The BoltFFI switch is not.
- **recommended extraction:** Benchmark harness first. Then a narrow deliberation brief for graph data-plane migration.

## Builder Prompt Risks

1. **Worktree inventory pressure** — The builder prompt requires `WORKTREE_INVENTORY_2026_04_30.md`, `RESEARCH_FUSION_NOTES_2026_04_30.md`, and `FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` before coding. Risk: the builder may rush these docs and skip evidence. **Mitigation:** Codex must audit each doc for exact file citations and Core/Pro classification before approving the next step.
2. **Quick Capture flattening risk** — The builder may see 50+ QC commits and assume QC should be merged as a unit. **Mitigation:** Explicitly treat QC as sibling-canonical; extract slices only.
3. **Pro-leakage risk** — Hermes/CLI/MCP/Theater research is abundant and exciting. Risk of wiring it into Core because "the code exists." **Mitigation:** Every queue item must declare `Core`, `Pro`, or `Both`. MAS build must compile without Pro symbols.
4. **Halo overbuild risk** — The builder may try to implement the full 6-state FSM + Model2Vec + usearch + Tantivy + RRF in one slice. **Mitigation:** V1 proof can start with a simpler debounced embed→search→panel path using existing `ShadowSearchService`. Stack lock comes later.
5. **Protected path drift** — The builder prompt lists protected files but doesn't explicitly re-check them after every edit. **Mitigation:** Codex must run `git diff ac8c6d28..HEAD -- Epistemos/Views/Notes/ProseEditor*.swift` independently after every slice.

## Missing Research Or Evidence

1. **Current main build status** — No `xcodebuild test` or `cargo test` log was captured in this review. The builder must verify green before any edits.
2. **Contextual Shadows live loop evidence** — `Pasted markdown.md` claims the debounce→encode→search→panel loop is missing, but this is from prior research. A fresh `rg` of `HaloEditorBridge` + `HaloController` + `ShadowSearchService` call sites is needed to verify current wiring.
3. **Quick Capture capture→artifact path** — `QuickCaptureView.swift` exists, but does the captured text become a `TypedArtifact` with `MutationEnvelope`? Unknown without reading the view code in depth.
4. **Lane A true delta** — Lane A's diff vs main shows deletions. Need to confirm whether any Lane A file contains valuable additions that were never cherry-picked.
5. **Stash@{0} contents** — `stash@{0}` holds W9.21 PR4 + W9.8 partial. These are flagged as "recoverable but NOT YET verified" in `CODEX_VERIFIED_STATE`. Must be inspected before popping.

## Recommended First Three Slices

### Slice 1: Verify Floor + Produce Required Phase 0 Docs
- **Scope:** Run `xcodebuild build` + `cargo test` on current dirty main. Produce `WORKTREE_INVENTORY_2026_04_30.md`, `RESEARCH_FUSION_NOTES_2026_04_30.md`, `FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md`.
- **Files touched:** `docs/fusion/*.md` only.
- **Core/Pro:** Both (docs only).
- **Risk:** Near-zero.
- **Tests:** `xcodebuild -scheme Epistemos -destination 'platform=macOS' build`, `cargo test` in `graph-engine/` and `agent_core/`.
- **Rollback:** `git checkout -- docs/fusion/`.

### Slice 2: Halo Live Loop Wiring Audit + Minimal V1 Proof
- **Scope:** Trace the current wiring from `HaloEditorBridge` → `HaloController` → `ShadowSearchService` → panel UI. If the loop is genuinely broken, wire the smallest possible path: editor text change → debounce → ShadowFFI search → results panel. Do NOT build the full Model2Vec + usearch + Tantivy stack in this slice.
- **Files likely touched:** `Epistemos/Engine/HaloController.swift`, `Epistemos/Engine/ShadowSearchService.swift`, possibly a new lightweight panel view.
- **Protected files:** `Epistemos/Views/Notes/ProseEditor*.swift` (read-only for bridge wiring; do not alter editor internals).
- **Core/Pro:** Core.
- **Risk:** Medium. ShadowFFI is a live FFI surface; nil-engine guards required.
- **Tests:** `HaloControllerTests.swift`, `HaloUITests.swift`, manual runtime verification of panel appearance.
- **Rollback:** Revert HaloController + ShadowSearchService changes; panel view can be deleted.

### Slice 3: Quick Capture Capture→Artifact→Graph Slice
- **Scope:** Wire `QuickCaptureView` → `TypedArtifact` creation → `MutationEnvelope` emission → graph node creation. One minimal flow, not the full QC branch.
- **Files likely touched:** `Epistemos/Views/Capture/QuickCaptureView.swift`, `Epistemos/Models/MutationEnvelope.swift`, `Epistemos/Graph/GraphStore.swift` or `GraphState.swift`.
- **Protected files:** ProseEditor, graph physics/render internals.
- **Core/Pro:** Core.
- **Risk:** Medium. Requires SwiftData save + graph update atomicity.
- **Tests:** New test verifying capture creates artifact + graph node + envelope.
- **Rollback:** Revert QuickCaptureView changes; artifact creation can be feature-flagged.

## Red Lines

1. **No raw worktree merges.** Ever. Every worktree contribution must be inventoried, deliberated, and extracted as a narrow patch.
2. **No Pro-only features in Core/MAS.** Hermes, CLI passthrough, MCP URL/stdio tunnels, Docker, Simulation Theater, and computer-use are Pro-only. MAS must compile without them.
3. **No edits to protected paths without Codex explicit approval.** Protected: `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Views/Graph/HologramController.swift`, graph physics/render internals, generated `.rlib`, DerivedData.
4. **No private Apple APIs in Core.** No ANE direct access. No hidden cloud escalation.
5. **No neural-kernel / infinite-context / activation-steering implementation in Core.** Research-only gates.
6. **No making Markdown shadows canonical.** Prose stays native TextKit 2. Documents stay Tiptap-in-WKWebView with transaction-summary bridge.
7. **No feature claimed as shipped without WRV proof.** Wired + Reachable + Visible, or explicit exemption from the closed exempt list.
8. **No commit or stage without Codex explicit authorization.**
9. **No build/test regression without immediate stop and surface.**
10. **No older research overrides current repo authority.** Conflict resolution: current code → AGENTS.md → April 30 fusion docs → older research.
