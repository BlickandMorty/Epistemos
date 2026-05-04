# RESEARCH_INDEX_BY_FEATURE.md — Required-reads per build phase

> **Authored**: 2026-04-27.
> **Role**: Maps every implementation phase (T+ slot) and every major feature to the **specific research files on disk** that must be read before that work begins. Agents (Claude builder + Codex auditor) MUST read the listed files before starting a new phase or session, and may pull from this index when they hit something they don't already have context for.
> **Scope**: ~440 research files on user's disk, organized by topic. Both original locations (`~/Downloads/...`, `~/jojo/...`) and consolidated copies (`docs/_consolidated/50_research_corpus/...`) are listed; either resolves.
> **Binding rule**: before any new T+ phase begins OR any new session opens, the agent reads the corresponding "Required reads" section in full, in priority order. Skipping = drift.
> **Reference-fallback**: if a path is null, apply `MASTER_FUSION.md §0.1` algorithm.

---

## §0 — How to use this index

1. **Before starting a new T+ phase from `NEXT_SESSION_BOOTSTRAP.md`**: open the matching §1.X section below. Read the "Required reads (Tier 1 — must read in full)" list. Optionally read Tier 2 if depth needed.
2. **Before opening a new session**: read §2 (cross-cutting required reads — the spine that every session needs regardless of phase).
3. **When you hit something mid-implementation that isn't in your context**: open the matching topic in §3 and pull only the file most relevant to the unknown.
4. **When research conflicts**: doctrine docs (in `docs/_consolidated/00_canonical_authority/`) win over research; use research for nuance and concrete patterns, not architectural authority.

Path syntax in this doc:
- `~/Downloads/foo.md` → original file at user's disk
- `_consolidated/...` → copy in `docs/_consolidated/...` (same content, organized by source)

---

## §1 — Per-phase required reads

### T+1 — Reconcile new doctrine docs with code

No external research required. Reconciliation happens entirely against:
- `docs/_consolidated/00_canonical_authority/CODEX_VERIFIED_STATE_2026_04_25.md` (the audit floor)
- `docs/_consolidated/00_canonical_authority/MASTER_FUSION.md` (the canonical synthesis)
- `docs/architecture/PLAN_V2.md` (architectural authority)
- `CLAUDE.md` (code standards)
- The four pillars docs (CONCEPT_DOOR_N2 / EXPLORATION_SPECTRUM_N3 / LOCAL_ANALYSIS_MODE_N4)

### T+2 — Stash@{0} resolution (W9.21 PR4 + W9.8 partial)

No external research required. Decision rule from `MASTER_FUSION.md §6.10` and the user's stated preference (restart fresh).

### T+3 — Close Phase S blockers (S.1 / S.7-9 / Instruments / distribution archive)

**Required reads (Tier 1)**:
- `docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md` — 5 canonical findings RH.1-RH.5; hot-spot file:line evidence
- `docs/architecture/PERF_REPAIR_REPORT_2026_04_21.md` — concrete bugs (semantic note lookups not propagated, fenced ` ```tool_call ` parser, MLX Metal unload, direct-stream tool advertisement mismatch, Mini Chat thinking-during-tools UI lie)
- `docs/architecture/CHAT_TRANSPARENCY_PLAN_2026-04-19.md` — what's already shipped (don't redo SHIPPED batches I/J/X/Y/S/BB/W)
- `docs/PHASE_S_AUDIT.md` — current state of S.1-S.9
- `docs/release/MAS_APP_REVIEW_NOTES.md` — App Store review notes
- `docs/architecture/BENCHMARK_BASELINES.csv` + `AGENT_STREAM_BASELINES.csv` — committed baseline numbers

**Tier 2 (if hitting specifics)**:
- Apple's App Store Connect submission docs (when at S.7)
- Apple TestFlight invitation flow docs (when at S.8)
- `docs/_consolidated/30_canonical_operational/V1_RELEASE_AUDIT.md`

### T+4 — Cognitive workspace typed artifact spine (ArtifactKind / .epdoc / Document editor)

**Required reads (Tier 1)**:
- `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` — **THE implementation plan**. ArtifactKind enum (7 kinds), ArtifactHeader, ProvenanceBlock, current state (Raw Thoughts 80% via Patches 4+5; typed graph 30% via Patch 5; .epdoc 0%; Document editor host 0%; readable_blocks 0%; Epistemos Code surface blocked on Patch 6a; agent patch/provenance not linked; MutationEnvelope still broad NotificationCenter; ArtifactRoute partial).
- `_consolidated/70_design_implementation/workspace_gpt_workspace_synthesis.md` — universal artifact envelope, .epdoc package shape, FTS5 over normalized search_text
- `_consolidated/70_design_implementation/workspace_gpt_workspace_architecture.md` — dual-editor architecture
- `_consolidated/00_canonical_authority/EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md` — BINDING (don't rewrite Tiptap; don't port AppFlowy; rendering pipeline comparison)
- `~/Downloads/final v2/compass_artifact_wf-c2d78e2f-...md` — Master Doctrine & Implementation Cookbook (12 moats; faculty roster; A2UI v0.9; FSRS-6; AFM @Generable as canonical structurer)
- `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt` — provenance plane primitives; ULID-keyed graph; DenseSlotMap arena; GRDB WAL + F_FULLFSYNC; 7-verb MCP; AnyView ban

**Tier 2 (when hitting specifics)**:
- ProseMirror docs (when on Tiptap canonical body)
- BlockNote benchmark (UX quality reference only — NOT foundation)
- `~/Downloads/old research/On-Device-AI-Training-System-Prompt.md` (when typed artifact links to Run training data)
- `~/Downloads/EPISTEMOS-FEATURE-SPEC.md` — feature surface inventory

### T+5 — Halo + Contextual Shadows V1 ship (ambient memory primitive)

**Required reads (Tier 1)**:
- `_consolidated/00_canonical_authority/ambient_V1_DECISION.md` — **the V1 architectural verdict**. 6-state FSM, performance budget table, stack lock (Model2Vec + usearch + tantivy + RRF), Apple Design Award angle. THE most decisive scoping doc.
- `~/Downloads/ambient/EPISTEMOS_V1_DECISION.md` — original of the above
- `~/Downloads/ambient/deep-research-report (2).md` — Swift+Rust+Metal hybrid blueprint, 7-milestone roadmap, 15-line FFI hardening checklist, C-shim + MTLBuffer wrapping
- `~/Downloads/ambient/gemini ambient.txt` — Halo + Contextual Shadows implementation blueprint (NSTextView caret tracking + popover with note/chat toggle + Mirror Speculative Decoding NPU+GPU + ARM NEON usearch)
- `~/Downloads/ambient/claude ambient.md` — Claude's deep analysis of the ambient feature (27K tokens; chunked-read needed)
- `_consolidated/70_design_implementation/ambient_swift_rust_metal_blueprint.md` — consolidated copy of the Swift+Rust+Metal blueprint
- `_consolidated/70_design_implementation/ambient_contextual_shadows_blueprint.txt` — consolidated copy of gemini ambient
- `_consolidated/20_canonical_research/perf_DETERMINISTIC_PERFORMANCE_PLAN.md` — 6-sprint × 12-week perf program; 5 hard constraints; signpost subsystem `com.epistemos.ffi`
- `~/Downloads/cap1_contextual_shadows.md` — capability pack #1 (early Halo design)

**Tier 2 (depth)**:
- Apple Developer docs on `WKWebView` (only if ambient panel uses it; preferred is NSPanel non-activating)
- Apple Developer docs on `NSPanel` non-activating + `NSWindowStyleMaskNonactivatingPanel` (when ShadowPanelController is wired)
- Apple Developer `accessibilityReduceMotion` + VoiceOver guidance
- Model2Vec official model page (when wiring potion-retrieval-32M)
- `usearch` Rust docs (HNSW + BF16 + M=16 + ef=64 config)
- `tantivy` Rust docs (BM25 + title boost 2.0)
- RRF fusion paper (k=60, weighted lex 1.2 / dense 1.0)

**Anti-pattern reading (what NOT to do)**:
- `~/Downloads/cap2_cross_app_capture.md`, `cap3_cognitive_friction.md`, `cap4_temporal_graph.md`, `cap5_night_brain.md`, `cap6_spatial_graph.md` — DEFERRED (post-V1 caps; do NOT pull into V1)

### T+6 — CLI integration (Pro mode primarily)

**Required reads (Tier 1)**:
- `_consolidated/30_cli_integration/CLI_CONFIG_COMPILATION_RESEARCH.md` — **the authoritative CLI compiler reference** (1161 lines). Drop-in templates for Claude Code / Codex / Gemini configs; Rust struct definitions; regeneration policy. April 2026 doc state.
- `_consolidated/30_cli_integration/claude-code-codex-parity-options.md` — runtime path comparison (Tunnel C subprocess vs Option 2 URL handoff vs Option 3 codex-mcp-server vs Option 4 static bundle) with recommendation
- `_consolidated/30_cli_integration/capability-tunnels.md` — 4-tunnel strategy (A shell / B.1 URL MCP / B.2 stdio MCP / C CLI passthrough)
- `_consolidated/30_cli_integration/mcp-url-servers.md` — Tunnel B.1 deep-dive (`~/.config/mcp/url_servers.json` format)
- `_consolidated/50_research_corpus/advice/claudy research.md` — CLI discovery probe order (NSWorkspace → known paths → version pinning → GRDB 24h TTL cache); DevContainer lifecycle
- `~/Downloads/Advice/Claude paper.pdf` — runtime-path doctrine + licensing constraints (subprocess CLI as Power Mode requires Developer ID non-sandbox)
- `~/Downloads/Advice/Gpt paper.md` — provider runtimes as plug-ins; Codex app-server pattern
- `~/Downloads/Advice/Gemini paper.pdf` — Gemini API + ADK + MCP universal tool surface
- `~/Downloads/Advice/Perplexity paper.md` — DevContainer + Claude Agent SDK + Qwen3-4B + json-render
- `~/Downloads/EPISTEMOS-CODEX-PLAN.md` — Hermes parity through Claude Code (5 phases; orphaned tools)

**Tier 2 (when hitting specifics)**:
- Anthropic Claude Code docs on `.mcp.json` (project-scoped MCP) and `.claude/settings.json` (account-level)
- OpenAI Codex CLI repo (for Codex CLI runtime semantics)
- Google `gemini` CLI repo (when Gemini integration starts)
- MCP spec (for tool registration + capability handshake)

**CRITICAL gotcha (BINDING)**:
- Project-scoped MCP belongs in `.mcp.json` — **NOT** `.claude/settings.json` (`mcpServers` there is IGNORED by Claude Code)
- Keep root `CLAUDE.md` lean; per-path rules in `.claude/rules/*.md`

### T+7 — Hermes integration (Pro primary; some MAS-safe seams)

**Required reads (Tier 1)**:
- `docs/HERMES_INTEGRATION_RESEARCH.md` — Fast Pack 10 + Deep Pack 30 + 40-file Hermes list (curated read-first guidance)
- `docs/EPISTEMOS-HERMES-PARITY-PLAN.md` — 5-phase closure plan (H.1-H.5 in MASTER_FUSION §6.7)
- `_consolidated/20_canonical_research/hermes_research/hermes-bundling-build-phase.md`
- `_consolidated/20_canonical_research/hermes_research/hermes-expert-mode-implementation-spec.md`
- `_consolidated/20_canonical_research/hermes_research/hermes-expert-mode-research-prompt.md`
- `_consolidated/20_canonical_research/hermes_research/hermes-expert-view-ui-spec.md`
- `_consolidated/20_canonical_research/hermes_research/hermes-risks-and-failure-modes.md`
- `_consolidated/20_canonical_research/hermes_research/hermes-strategic-fork-analysis.md` — bundle vs adopt format vs full fork analysis
- `_consolidated/20_canonical_research/hermes_research/hermes-tool-catalog.md` — full tool inventory
- `_consolidated/20_canonical_research/hermes_research/hermes-update-strategy.md`
- `_consolidated/20_canonical_research/hermes_research/hermes-wire-protocol.md`
- `_consolidated/20_canonical_research/hermes_research/local-models-16gb-mac-april-2026.md`
- `~/Downloads/final/Building Epistemos x Hermes Hackathon.txt` — hackathon technical dossier
- `~/Downloads/final/EPISTEMOS_HERMES_MANIFESTO.md` — strategic vision, aesthetic discipline, six-verb MCP boundary
- `~/Downloads/final/compass_artifact_wf-2de4a4f7-...md` — Hackathon Hermes architectural dossier (57KB)

**Tier 2 (when hitting specifics)**:
- agentskills.io skill format spec
- Anthropic XML tool-call conventions (when implementing native Rust planner for MAS)

**BINDING positioning** (per MASTER_FUSION §11.2):
- "Hermes is UX-privileged and integration-privileged, but not substrate-sovereign"
- Removing Hermes must NOT break core Epistemos
- MAS path: native Rust planner adopting Hermes XML tool-call + agentskills.io skill format. NO Python subprocess in MAS.

### T+8 — Workspace dual-editor / Document editor / .epdoc completion

**Required reads (Tier 1)**:
- `_consolidated/00_canonical_authority/EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md` — BINDING (re-read from T+4 if needed)
- `_consolidated/70_design_implementation/workspace_epistemos_code_verdict.md` — **Code Editor architectural lock**. Swift+TextKit2 surface + SwiftTreeSitter live (NOT Rust FFI per-keystroke) + Rust background brain + SourceKit-LSP + Metal viz only. "Stop researching. The architecture is bulletproof."
- `_consolidated/70_design_implementation/workspace_gpt_workspace_synthesis.md` (re-read)
- `~/Downloads/workspace/gpt work.md` (35KB) — dual-editor workspace architecture
- `~/Downloads/workspace/gpt work 2.md` (37KB) — universal artifact envelope synthesis
- `~/Downloads/workspace/claude work.md` (29K tokens — chunked-read needed) — Claude's architecture deep-dive
- `~/Downloads/workspace/raw thoughts.md` (67K tokens — chunked-read needed) — **the user's own brainstorm; possibly highest personal-value file in entire corpus**
- `_consolidated/30_canonical_operational/CODE_EDITOR_POLISH_SCOPE.md` — Phase S 4 items (~2 days): line gutter, Binding<String> debounce, outline cache/diff, viewport-scoped highlighting
- `_consolidated/30_canonical_operational/FEATURE_SPEC_TOC_AND_FOLDING.md` — TOC strip + code folding + CodeSymbol struct (20-byte repr(C))
- `_consolidated/70_design_implementation/perf_editor_120fps_v1.md` — 120fps optimization perspective 1 (NSTextStorage delegate + Metal MSDF + minimap CALayer + CADisplayLink)
- `_consolidated/70_design_implementation/perf_editor_120fps_v2.md` — perspective 2 (ProMotion 8.33ms; SumTree/Rope analysis)
- `_consolidated/70_design_implementation/perf_editor_120fps_v3.md` — perspective 3 (5-phase implementation roadmap)
- `_consolidated/70_design_implementation/perf_invalidation_strategy.md` — "invalidation > transport"; 78×–167× incremental outline-refresh gain; reaffirms BoltFFI 1000× as `[UNVERIFIED]`

**Tier 2**:
- TextKit 2 Apple Developer docs (when on Prose editor changes — but ProseEditor is protected so this is lookup-only)
- SwiftTreeSitter package docs (when on live syntax)
- SourceKit-LSP docs (Swift semantic intelligence)
- ProseMirror schema/transaction docs (when on .epdoc canonical body)

### T+9 — Landing wave search style (GPU Metal ASCII)

**Required reads (Tier 1)**:
- `_consolidated/30_canonical_operational/LANDING_WAVE_SEARCH_PLAN.md` — 160×80 ASCII grid @ <1ms GPU per frame on M-series; anti-collision notice; off-limits surfaces enumerated
- `_consolidated/30_canonical_operational/GRAPH_WAVES_HANDOFF.md` — graph waves ship handoff (10-commit canonical sequence; experimental forces gating)

**Tier 2**:
- Apple Metal Best Practices (when wiring shader pipeline)
- `_consolidated/30_canonical_operational/GPU_RENDERER_SEAM.md` — DEFERRED Pro-only (do NOT pull into V1 landing wave)

### T+10 — N2 Concept Door / Depth Kernel

**Required reads (Tier 1)**:
- `_consolidated/00_canonical_authority/CONCEPT_DOOR_N2.md` — the canonical N2 doctrine (re-read)
- `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` — **REQUIRED IMPLEMENTATION COMPANION** (per CONCEPT_DOOR_N2 §13.1)
- `docs/PROMPT_AS_DATA_SPEC.md` — N1 spec (Concept Door composes N1 PromptTree; do NOT bypass)
- `_consolidated/00_canonical_authority/MASTER_FUSION.md §16-§17` — Concept Door + Minimal Surface design contract
- `_consolidated/00_canonical_authority/EXPLORATION_SPECTRUM_N3.md` (sister N3 doctrine; helps see how they compose)
- `~/Downloads/final v3/deep-research-report (4).md` — JSON-schema prompting + Anthropic prompt caching mechanics + Tool Search (informs N1+N2 prompt composition)

**Tier 2**:
- `~/Downloads/old research/Designing Epistemos Time Machine UI.md` — spatial-temporal UI patterns (relevant when ConceptWorld renders related artifacts spatially)
- ProseMirror block-with-stable-ID patterns (when ConceptDoor links to specific blocks)

### T+11 — N3 Exploration Spectrum / Concept Diffusion Mode

**Required reads (Tier 1)**:
- `_consolidated/00_canonical_authority/EXPLORATION_SPECTRUM_N3.md` — the canonical N3 doctrine (re-read)
- `docs/PROMPT_AS_DATA_SPEC.md` — N1 (the prompt-tree generator that N3 compiles into)
- `_consolidated/00_canonical_authority/CONCEPT_DOOR_N2.md` — sister doc (each ConceptNode IS a Concept Door target)
- `~/Downloads/final v3/deep-research-report (4).md` — JSON-schema prompting; Ambiguity Tax framing; modular prompt trees
- `~/Downloads/final v2/compass_artifact_wf-c2d78e2f-...md` — Master Doctrine; AFM @Generable as canonical structurer; A2UI v0.9 with VALIDATION_FAILED rejection

**Tier 2 (the "scientist of words" persona inspiration)**:
- Diffusion model intuition (any standard reference; the metaphor borrows from iterative noise→signal refinement)
- `~/Downloads/old research/Epistemos Instant Recall Mamba + Quantized Vector Memory on Swift Rust.md` — Mamba state injection (related to deliberation-shape mechanics)

### T+12 — N4 Local Analysis Mode / Deterministic Verification

**Required reads (Tier 1)**:
- `_consolidated/00_canonical_authority/LOCAL_ANALYSIS_MODE_N4.md` — the canonical N4 doctrine (re-read; 8-rule determinism contract is BINDING)
- `_consolidated/00_canonical_authority/MASTER_FUSION.md §3.5` — four-layer event hierarchy (LAM RunEventLog integration)
- `_consolidated/00_canonical_authority/MASTER_FUSION.md §11.1` — DEBUG quarantine for closed A2UI catalog

**Tier 2 (when hitting specifics)**:
- `tree-sitter` Rust crate docs (Stage 2 code verification — pinned grammar SHAs)
- `symbolica` or `nalgebra` Rust crate docs (Stage 3 symbolic math; pinned)
- `rug` (GNU MP) Rust docs (arbitrary-precision numeric)
- `inari` (IEEE 1788 interval arithmetic) Rust crate docs
- `clippy` rule documentation (Stage 2 lint)
- `rustc` `--no-execute` mode (Stage 2 type-check without running)
- `pyright` strict mode docs (when LAM verifies Python code)
- `swiftc` static analysis (when LAM verifies Swift code)

**ANTI-pattern reading (BINDING — what NOT to do)**:
- Anything proposing LLM-based double-checking or chain-of-verification with LLMs in the verification loop. **N4's whole point is no LLM in verification.**

### T+13 — Master Hardening + Wiring + Product Expression Audit (10 specialist agents)

**Required reads (Tier 1)**:
- `docs/architecture/EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN.md` — research synthesis (the source of "benchmark harness is the absolute first step")
- `_consolidated/00_canonical_authority/IMPLEMENTATION_PLAN_FROM_ADVICE.md` — 4-model council synthesis (241KB; the canonical synthesized master plan)
- `_consolidated/00_canonical_authority/MASTER_HARDENING_AND_HARNESS_PLAN.md` — 5-layer hardening roadmap; phases 1-13
- `_consolidated/00_canonical_authority/RESEARCH_TO_APP_TRACEABILITY.md` — F01-F29 feature traceability matrix with file:line evidence
- `_consolidated/00_canonical_authority/EPISTEMOS_SPECIALTIES.md` — 19 architecturally-impossible-for-others specialties
- `docs/audits/` (the audit subdirectory) — existing audit artifacts to extend, not replace
- `_consolidated/50_research_corpus/master_plans/EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER.md` — 2026-04-27 audit; 20 verified moats; 13-item drift inventory
- `_consolidated/50_research_corpus/master_plans/2026-03-27-master-gap-closure-plan.md` — 124KB; Opus 4.6 audit; 5 hard blockers (G.1-G.5)
- `_consolidated/50_research_corpus/master_plans/EPISTEMOS_MEGAPROMPT.md` — 7 workstreams × 17 days

**Tier 2 (when each specialist agent runs)**:
- Agent 1 Cartographer: read all of `Epistemos/` directory tree first
- Agent 3 Ambient Recall: re-read T+5 list
- Agent 4 UI Surface: read existing settings/sidebar/menus + this index
- Agent 5 Performance: read T+14 perf research list
- Agent 8 Privacy/App Store: re-read T+3 + RELEASE_HARDENING_CANONICAL_PLAN

### T+14 — Deterministic Knowledge Runtime v1 (Phase 0-7)

**Required reads (Tier 1)**:
- `_consolidated/00_canonical_authority/IMPLEMENTATION_PLAN_FROM_ADVICE.md` (re-read for performance context)
- `_consolidated/20_canonical_research/perf_DETERMINISTIC_PERFORMANCE_PLAN.md` — 6-sprint × 12-week perf program; 5 hard constraints
- `_consolidated/40_canonical_prompts/perf_CLAUDE_MD_ADDENDUM.md` — 5-line block to append to CLAUDE.md
- `_consolidated/40_canonical_prompts/perf_CONTEXT_ESSENTIALS_APPEND.txt` — post-compaction hook
- `_consolidated/40_canonical_prompts/perf_SPRINT0_KICKOFF.md` — paste-prompt for Sprint 0
- `_consolidated/70_design_implementation/perf_invalidation_strategy.md` — **"invalidation > transport"**; 78×–167× incremental outline-refresh; reaffirms BoltFFI 1000× as `[UNVERIFIED]`
- `_consolidated/70_design_implementation/perf_ffi_flatbuffers_research.md` — theoretical zero-copy FFI model (FlatBuffers + Markov prefetching + atomic-pointer Tree-sitter cache)
- `~/Downloads/opt/claude opt 2.md` — "invalidation > transport" critique
- `~/Downloads/opt/CLAUDE_CODE_SPRINT0_KICKOFF.md` — sprint kickoff template
- `~/Downloads/opt/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` — original of the consolidated perf plan
- `~/Downloads/opt/Epistemos Performance Optimization Roadmap.txt` (26K tokens — chunked-read)
- `~/Downloads/opt/compass_artifact_wf-97f869bf-...md` (26K tokens — chunked-read)
- `~/Downloads/opt.txt` (38K tokens — chunked-read)
- `~/Downloads/opt2.txt` (33K tokens — chunked-read)
- `~/Downloads/opt3.txt` (21K tokens — chunked-read)
- `_consolidated/20_canonical_research/architecture_specs/BOLTFFI_AUDIT_2026_04_15.md` — BoltFFI carve-out strategy (PLAN_V2 §22)

**Tier 2 (when implementing specific phases)**:
- Phase 1 (typed mutation envelopes): Apple Concurrency Manifesto; Swift 6 Sendable + actor isolation
- Phase 4 (borrowed row projections): Swift `UnsafeBufferPointer` + `withUnsafeBytes`; `Data(bytesNoCopy:count:deallocator:)` Apple docs
- Phase 5 (raw thoughts bulk lane): mmap append-only file patterns; SPSC ring buffer
- Phase 6 (static registries): Rust `phf` crate docs
- Phase 7 (preview cache): SQLite mmap docs

**ANTI-pattern reading (what NOT to start with — per GPT advisor verdict)**:
- Tree-sitter migration research → DEFER until Phase 4 proves invalidation isn't the bottleneck
- Metal binary archive research → DEFER unless launch hitches dominate
- Slotmap entity-store migration → DEFER
- FlatBuffers migration → DEFER (rkyv stays unless direct Swift traversal proven necessary)
- Full Swift macro infrastructure → DEFER

### T+15 — Final ambitious "I never did" pile

#### T+15.1 Pro mode launch
- Re-read T+6 (CLI integration)
- Re-read T+7 (Hermes integration)
- `_consolidated/60_deferred_research/OPENCLAW_FEATURE_SPEC.md` — Phase K Pro-only

#### T+15.4 Mirror Speculative Decoding (NPU+GPU dual accelerator)
- Apple ML Research arXiv 2510.13161 (the source paper; cited from `gemini ambient.txt`)
- `~/Downloads/old research/Epistemos Omega — Dual-Brain Hardware-Action Protocol Deep Research Analysis & Master Execution Prompt.md` — Reasoning Brain GPU + Device Action Agent ANE; ANEMLL benchmarks; Mirror Speculative Decoding application
- `_consolidated/50_research_corpus/old_research/` — same file via consolidation
- ANE benchmarks (UI-TARS arXiv 2501.12326; UI-TARS-2 arXiv 2509.02544; VLM2VLA arXiv 2509.22195; MambaPEFT arXiv 2411.03855; Memba arXiv 2506.18184)

#### T+15.5 ODIA — Overnight Distillation + In-Memory Adaptation
- `~/Downloads/old research/Epistemos Omega — Supreme Master Execution Prompt for Claude Code.md`
- `~/Downloads/old research/EPISTEMOS-NANO-MASTER-TRAINING-GUIDE.md` — training data curation
- `~/Downloads/old research/App-Specific Training + Multi-Scale Model Family.md` — Nano/Base/Pro tiers
- `~/Downloads/old research/Legendary Nano Model — Niche Scripts & Automated Pipelines.md`
- 5 hard blockers from gap-closure (G.1-G.5 in MASTER_FUSION §6.9)

#### T+15.6 Time Machine immersive temporal navigation
- `~/Downloads/old research/Designing Epistemos Time Machine UI.md` — full blueprint (4-layer Metal shader pipeline; SDF Metaballs + Reaction-Diffusion Gray-Scott + Curl Noise + Volumetric Nebula; Material Point Method + strain energy minimization; CAMetalLayer not MTKView; <5% GPU compute, <50MB VRAM)

#### T+15.8 17-model LocalTextModelID expansion
- `_consolidated/50_research_corpus/master_plans/EPISTEMOS_MEGAPROMPT.md §1.1` — full enum spec
- `_consolidated/20_canonical_research/HERMES_INTEGRATION_RESEARCH.md` — local-models-16gb-mac-april-2026
- `~/Downloads/Epistemos Complete Model Support & Feature Expansion Plan.md` — model lineup expansion plan (68KB)

#### T+15.10 Apple Design Award submission
- `_consolidated/00_canonical_authority/ambient_V1_DECISION.md §"Apple Design Award angle"` — explicit framing

---

## §2 — Cross-cutting required reads (every session, regardless of phase)

These are the spine — read at the start of every fresh session, before opening any phase-specific list:

```
1. docs/READ_FIRST.md
2. docs/_consolidated/00_canonical_authority/CODEX_VERIFIED_STATE_2026_04_25.md
3. docs/_consolidated/00_canonical_authority/MASTER_FUSION.md
4. docs/_consolidated/00_canonical_authority/NEXT_SESSION_BOOTSTRAP.md
5. docs/_consolidated/00_canonical_authority/RESEARCH_INDEX_BY_FEATURE.md (this file — pulls T+ phase reads)
6. CLAUDE.md
7. docs/architecture/PLAN_V2.md
8. docs/MASTER_BUILD_PLAN.md
9. docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md
10. docs/plan/01_DOCTRINE.md
```

These are 10 docs. Read them in full. Then layer the phase-specific list from §1.

---

## §3 — Topic-indexed lookup (when you hit something mid-implementation)

If during implementation you encounter a concept/system you don't have full context on, look it up here and pull the most relevant file.

### Memory architecture / retrieval
- **Stateful Rotor / sub-5ms retrieval**: `~/Downloads/EPISTEMOS_MASTER_THESIS.md` + `harness-engineering-thesis.md` + `~/Downloads/old research/Epistemos Instant Recall Mamba + Quantized Vector Memory on Swift Rust.md`
- **TurboQuant / PolarQuant / QJL**: `~/Downloads/old research/TurboQuant (PolarQuant + QJL) — Technical Deep Dive.md` (corrects brief; PolarQuant uses recursive multi-level; QJL is 1-bit per coordinate; both are model-level KV optimizations NOT index primitives)
- **Mamba-3 + state injection**: `~/Downloads/old research/Epistemos Instant Recall Mamba.md` (2025/2026 Mamba-3 features; constant memory footprint; MemMamba threshold-triggered state summarization)
- **Binary HNSW for index**: same Instant Recall doc; usearch crate

### FFI / Rust↔Swift boundary
- **BoltFFI carve-out**: `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md` (PLAN_V2 §22 source); narrow `substrate-rt` carve-out via `repr(C)` ring buffer; NO mass migration
- **UniFFI patterns**: Mozilla UniFFI user guide
- **rkyv zero-copy deserialization**: rkyv official docs
- **C-shim + MTLBuffer wrapping**: `_consolidated/70_design_implementation/ambient_swift_rust_metal_blueprint.md`

### Provenance / event hierarchy
- **Four-layer model**: `MASTER_FUSION.md §3.5` (canonical) + `~/Downloads/final v2/App Moats.txt` (provenance plane primitives)
- **BLAKE3 Merkle chain**: commit `fe97e512` (W9.27 PR3 + D1) made it real; spec in `MASTER_FUSION.md §3.5` integrity section
- **MutationEnvelope schema**: `MASTER_FUSION.md §3.5` Layer 2

### Code editor performance
- **120fps techniques**: `_consolidated/70_design_implementation/perf_editor_120fps_v1/v2/v3.md` (3 perspectives converge on NSTextStorage delegate + background TreeSitter actor + Metal MSDF + minimap CALayer + CADisplayLink keep-alive)
- **TextKit 2 vs TextKit 1**: Apple Developer docs + `~/Downloads/old research/Epistemos Editor Stack — Hardening Pass Audit Report.md`
- **SwiftTreeSitter live + Rust background**: `workspace_epistemos_code_verdict.md`

### Sandbox / App Store
- **Entitlements drift**: `EpistemosTests/AppStoreHardeningTests.swift` (verified suite; 20+ tests)
- **PrivacyInfo.xcprivacy**: `Epistemos/Resources/PrivacyInfo.xcprivacy`
- **App Sandbox + security-scoped bookmarks**: Apple Developer docs
- **codesign embedded entitlements**: see verified codesign output in CODEX_VERIFIED_STATE §1

### Reliability gates / sanitizers
- **TSAN with `-Wl,-no_compact_unwind`**: commit `d46594c8` (reliability script DERIVED_DATA_ROOT hardening)
- **Sanitizer evidence**: `/tmp/epistemos-reliability/` directory tree
- **DerivedData + TCC prompts**: see CODEX_VERIFIED_STATE §1; routes through TCC if under `~/Downloads/`

### Hermes / agent system
- **Tool registry**: `agent_core/src/tools/registry.rs` + the 5 orphaned tools to register
- **MCP wire protocol**: `_consolidated/20_canonical_research/hermes_research/hermes-wire-protocol.md`
- **Skill format**: agentskills.io spec
- **XML tool calls**: `_consolidated/20_canonical_research/hermes_research/hermes-tool-catalog.md`

### A2UI / closed catalog
- **A2UI v0.9 envelope**: `~/Downloads/final v2/Epistemos Hackathon_ Deep Research Plan.txt`
- **VALIDATION_FAILED + DEBUG quarantine**: `MASTER_FUSION.md §11.1`
- **Closed catalog discipline**: `MASTER_FUSION.md §16.5` (N2 catalog additions) + §17 minimal surface

### Halo / Contextual Shadows specifics
- **6-state FSM**: `ambient_V1_DECISION.md`
- **NSPanel non-activating**: Apple AppKit docs + `gemini ambient.txt`
- **Trailing-edge anchor (NOT caret tracking)**: `AMBIENT_RECALL_HALO_MASTER_PLAN.md` §3.6.1
- **Three Halo surfaces**: `AMBIENT_RECALL_HALO_MASTER_PLAN.md` §3.6.2

### Research lineage / what's deferred
- **Capability pack 2-6 (cross-app capture, cognitive friction, temporal graph, night brain, spatial graph)**: `~/Downloads/cap2..cap6.md` — DEFERRED post-V1 caps
- **Knowledge Fusion**: SUPERSEDED-HISTORICAL per IMPLEMENTATION_PLAN_FROM_ADVICE; in `_archive/knowledge_fusion_old/`
- **Omega system**: SUPERSEDED-HISTORICAL per IMPLEMENTATION_PLAN_FROM_ADVICE; in `_archive/omega_retired/`

---

## §4 — Reading discipline (BINDING)

When a phase says "Required reads (Tier 1 — must read in full)", these rules apply:

1. **Read in priority order**. Files are listed in dependency order; later files assume earlier files.
2. **Read in full** for Tier 1. Skimming = drift. If the file is oversized (e.g., raw thoughts.md at 67K tokens or claude work.md at 29K tokens), use chunked-read with `Bash split` or equivalent — but read every chunk, not just the first.
3. **Note `[UNVERIFIED]` markers**. Several research files (esp. `final v2/App Moats`, `Hackathon Plan`) carry explicit `[UNVERIFIED]` tags on claims like "BoltFFI 1000× speedup". Preserve these markers when citing.
4. **Doctrine wins over research**. If a research paper claims X but `MASTER_FUSION.md` or `PLAN_V2.md` says Y, doctrine wins. Surface the conflict; don't silently follow research.
5. **Anti-pattern reading is also required**. If a phase lists files under "Anti-pattern reading", read them so you know what NOT to copy from them.

---

## §5 — Disk research locations (canonical paths)

If you need to find research not listed in §1-§3:

```
~/Downloads/Advice/                              4-model architectural advice (7 files; runtime path doctrine)
~/Downloads/final/                               Executive summaries + last round of thinking (14 files; Hermes manifesto)
~/Downloads/final/last round of thinking/        4 files (consensus building, privacy/speed/SDK, architecture consensus & disruption, compass artifact)
~/Downloads/final/executive sumaries/            4 files (Master Doctrine compass, deeper research from gpt, rival doctrine, gpt deep)
~/Downloads/final v2/                            6 files (Master Doctrine cookbook, App Moats, Hackathon Plan, KIVI vs TurboQuant, SSM/hybrid, deep critique)
~/Downloads/final v3/                            1 file (LLM prompt-engineering — JSON schema, Anthropic cache, Tool Search)
~/Downloads/ambient/                             4 files (V1 decision, Swift+Rust+Metal blueprint, gemini ambient, claude ambient)
~/Downloads/workspace/                           5 files (epistemos code verdict, gpt work / work 2, claude work, raw thoughts)
~/Downloads/opt/                                 8 files (deterministic perf plan, CLAUDE_MD addendum, sprint 0 kickoff, claude opt 2, deep research, optimization roadmap, compass artifact)
~/Downloads/old research/                        41 files (Omega, Nano Master Training, Time Machine UI, Instant Recall, Mac AI Assistant, On-Device AI Training, MLX Constrained Decoding)
~/Downloads/audit/                               4 files (audit-class research)
~/Downloads/meta-analytical-pfc/                 11 files (meta-analytical PFC research)
~/Downloads/*.md (root)                          ~195 files (mixed; large unsorted research; many master-plan candidates)
~/jojo/*.md (root)                               ~25 files (master plan, harness engineering thesis, vector quant, etc.)
~/Downloads/mass research folder/                65 unique files (after dedup with downloads_root)
~/Downloads/next batch of unsorted research/     mostly duplicated above
~/Downloads/unsort3ed research/                  mostly duplicated above
~/Downloads/soaar and research mode/             12 files (Omega + SOAR research)
~/Downloads/last feature after new agents/       4 files
~/Downloads/new features/, new make sures/       small clusters

Consolidated mirror (organized by source):
docs/_consolidated/50_research_corpus/
   advice/  final/  final_v2/  final_v3/  ambient_dir/  workspace_dir/  opt_dir/
   old_research/  mass_research/  meta_analytical_pfc/  audit_dir/
   master_plans/      ← the 8 canonical master plans
   downloads_root/    ← 184 unique files from ~/Downloads/*.md after dedup
   jojo_root/         ← 3 unique files from ~/jojo/*.md

3rd-party code repos (NOT research; skip):
~/Downloads/openclaw-main/, logseq-source/, Sunshine-master/, claw-code/, rowboat/, epistemos-public/
```

**Search command** (when nothing in §1-§3 matches what you need):

```bash
# Topic-keyword search across all research (excludes 3rd-party + repo)
find ~/Downloads ~/jojo -maxdepth 3 -type f \( -name "*.md" -o -name "*.txt" \) \
  -not -path "*/openclaw-main/*" \
  -not -path "*/logseq-source/*" \
  -not -path "*/Sunshine-master/*" \
  -not -path "*/Epistemos*/*" \
  -not -path "*/.git/*" \
  | xargs grep -l -i -E "<your-topic-keyword>" 2>/dev/null | head -20
```

---

## §7 — Real-time deliberation protocol (BINDING — every phase, every session)

The user's directive: *"once it gets to BoltFFI, I want it to literally research my own disk AND do a web search and conjugate and synthesize data related to BoltFFI to figure out the best way to implement it, the drawbacks, the advantages, etc., and deliberate in real time on every single pass, every single phase."*

This is not optional. Before any T+ phase begins, the agent must perform the **Deliberation Pass** below. The output is a per-phase deliberation brief saved to `docs/audits/deliberation/T+<N>_<topic>_deliberation_<YYYYMMDD>.md` and surfaced to the human / Codex auditor before any code is written.

### §7.1 — The Deliberation Pass (5 steps)

```
Step A — Disk research synthesis
  1. Open §1.<phase> Required reads (Tier 1) above. Read every file in full.
  2. For each file, extract: claims made, [UNVERIFIED] markers, file:line
     evidence patterns, anti-patterns to avoid, named tradeoffs.
  3. If a file is oversized (>20K tokens), use chunked-read; do not skip.
  4. Note where research files agree (convergent) vs disagree (divergent).
     Convergent claims are bedrock; divergent claims need adjudication.

Step B — Web research (live; complements disk)
  Allowed sources, in priority order:
    1. Official Apple Developer documentation
    2. Official Rust crate docs on docs.rs (pinned to current versions)
    3. Vendor official docs (Anthropic, OpenAI, Google, Hugging Face)
    4. arXiv papers cited in disk research (read the abstract + conclusion
       at minimum; pull tables/figures if implementation-relevant)
    5. GitHub issues/PRs/discussions on the actual crate or library
    6. Standards documents (IEEE 754, IEEE 1788 for intervals,
       BLAKE3 spec, MCP protocol spec, etc.)
    7. Engineering blog posts from the actual project maintainers
       (Apple, Mozilla, ChimeHQ for SwiftTreeSitter, etc.)
  Forbidden / low-trust:
    - Random Medium / Substack / Reddit posts unless they cite primary
      sources you then verify
    - LLM-generated explainers without primary-source backing
    - Year-old docs when the topic moves fast (always check the date)

  Search keyword recipes per phase: see §7.3 below.

  Output: short "web findings" notes per topic, with URL + access date +
  one-line gist. Save to the deliberation brief.

Step C — Conjugate disk + web
  For each implementation question in this phase:
    - What does disk research say?
    - What does web research say?
    - Where do they agree? (high confidence)
    - Where do they disagree? (needs explicit adjudication)
    - What is the canonical doctrine answer? (look in MASTER_FUSION /
      PLAN_V2 / CLAUDE.md)
    - If the doctrine has not ruled on this question, propose an answer
      backed by the strongest evidence and surface it for human approval.

Step D — Trade-off matrix
  For every non-trivial choice (data structure, library, algorithm,
  architectural seam), produce a trade-off matrix:

    Option | Pros | Cons | Risk | Reversibility | Recommendation
    -------|------|------|------|---------------|---------------
    A      | ...  | ...  | ...  | ...           | ...
    B      | ...  | ...  | ...  | ...           | ...

  At least one option in each matrix MUST be "do nothing / defer / reuse
  existing", and the recommendation must justify why that option is or
  isn't chosen.

Step E — Decision + provenance
  Conclude the brief with:
    - Decision (the chosen path)
    - Rationale (1 paragraph; cite disk + web sources)
    - Risks accepted
    - Risks deferred
    - What measurement will prove the decision was right
    - What measurement would force a reversal
    - Citations: every disk file read + every web URL with access date

  THE DELIBERATION BRIEF IS THE GATE. No code is written until the brief
  is saved. Codex audits the brief before approving forward motion.
```

### §7.2 — Output format (paste-ready template)

```markdown
# T+<N> Deliberation Brief: <Topic>

**Date**: <YYYY-MM-DD>
**Phase**: T+<N>
**Author**: Claude builder
**Auditor**: Codex (pending)

## §A — Disk research synthesis
- File: <path>
  - Claim: ...
  - Evidence: <file:line / quote>
  - [UNVERIFIED] markers: ...
  - Anti-patterns: ...
- File: <path>
  - ...

Convergent claims:
- ...

Divergent claims:
- A says X, B says Y. Adjudication required.

## §B — Web research findings
- <URL> (accessed YYYY-MM-DD)
  - Gist: ...
  - Relevant section/quote: ...
- ...

## §C — Conjugation (disk × web)
For each implementation question:
- Q: ...
  - Disk: ...
  - Web: ...
  - Doctrine: ... (cite MASTER_FUSION / PLAN_V2 section)
  - Synthesis: ...

## §D — Trade-off matrix
| Option | Pros | Cons | Risk | Reversibility | Recommendation |
|---|---|---|---|---|---|
| A | ... | ... | ... | ... | ... |
| B | ... | ... | ... | ... | ... |
| C (do nothing / defer / reuse) | ... | ... | ... | ... | ... |

## §E — Decision
- Chosen: <option>
- Rationale: ...
- Risks accepted: ...
- Risks deferred: ...
- Success metric: ...
- Reversal trigger: ...
- Citations:
  - Disk: <list>
  - Web: <list with URLs + dates>
```

### §7.3 — Per-phase web-search keyword recipes

When you do Step B web research, use these starting keyword recipes. Adapt them as you read; they're a launchpad, not a script.

#### T+3 — Phase S blockers (App Store / TestFlight / signposts / archive)
```
- "App Store Connect submission macOS 2026"
- "TestFlight macOS internal testers distribution profile"
- "macOS distribution-signed archive vs ad-hoc xcodebuild"
- "PrivacyInfo.xcprivacy NSPrivacyAccessedAPITypes Apple required reasons"
- "os_signpost OSLog Instruments macOS Swift 6"
- "Apple App Store review guidelines 2.5.1 sandboxing 2026"
- "Apple sandbox security-scoped bookmarks NSDocumentScopeBookmark"
```

#### T+4 — Cognitive workspace typed artifact spine
```
- "ProseMirror schema custom block stable IDs"
- "Tiptap WKWebView macOS performance 2026"
- "BlockNote vs Tiptap macOS native"
- "ULID Rust crate vs UUID v7 deterministic"
- "BLAKE3 content hash file integrity"
- "GFM markdown vs Djot 2025 ecosystem maturity"
- "macOS package directory bundle .epdoc custom UTI"
- ".xcdatamodeld vs SwiftData migration Swift 6 strict concurrency"
```

#### T+5 — Halo + Contextual Shadows V1
```
- "NSPanel non-activating macOS Swift 6 caret tracking alternatives"
- "Model2Vec potion-retrieval-32M HuggingFace embedding"
- "usearch HNSW Rust crate BF16 M=16 ef=64"
- "tantivy BM25 title boost 2.0 weighted Rust"
- "reciprocal rank fusion k=60 weighted lex dense"
- "Apple Vision Reduce Motion accessibility 2026"
- "WKProcessPool prewarming WKWebView macOS shared"
- "macOS 26 NSWindowStyleMaskNonactivatingPanel SwiftUI integration"
```

#### T+6 — CLI integration (Pro)
```
- "Anthropic Claude Code .mcp.json project scoped MCP servers"
- "OpenAI Codex CLI runtime architecture 2026"
- "Google gemini CLI MCP support macOS"
- "MCP protocol spec 2026 stdio HTTP capability handshake"
- "Apple sandbox spawn subprocess CLI exception entitlement"
- "Developer ID notarization vs Mac App Store distribution constraints"
- "macOS NSWorkspace urlForApplicationWithBundleIdentifier 2026"
```

#### T+7 — Hermes integration (Pro)
```
- "agentskills.io skill format spec 2026"
- "Hermes XML tool call convention"
- "managed Python subprocess macOS Apple Silicon notarization"
- "127.0.0.1 random high port CSPRNG token local HTTP service Swift"
- "OAuth 2.1 sampling MCP tool"
```

#### T+8 — Workspace dual-editor / Document editor / .epdoc completion
```
- "TextKit 2 NSTextStorage delegate incremental delta 2026"
- "SwiftTreeSitter ChimeHQ live syntax highlighting performance"
- "tree-sitter Rust crate UTF-8 byte offset NSRange UTF-16 mapping trap"
- "SourceKit-LSP Swift semantic completion 2026 macOS 26"
- "Metal MSDF font atlas glyph rendering minimap CALayer"
- "CADisplayLink 120fps ProMotion macOS Metal triple-buffer wait_until_scheduled"
- "CodeEditSourceEditor 0.15.2 production readiness GitHub issues"
```

#### T+10 — N2 Concept Door / Depth Kernel
```
- "ProseMirror block-level metadata plugin custom node attrs"
- "Anthropic prompt caching cache_control 5-minute TTL 4-breakpoint"
- "JSON schema strict mode validation Swift Codable"
- "structured output schema-first prompting 2026"
```

#### T+11 — N3 Exploration Spectrum / Concept Diffusion Mode
```
- "diffusion model iterative noise-to-signal refinement intuition"
- "tree-of-thoughts vs graph-of-thoughts prompting 2025"
- "JSON tool call grammar-constrained EBNF mask local model"
- "MLX-Swift token sampling logit mask custom"
```

#### T+12 — N4 Local Analysis Mode (deterministic verification)
```
- "symbolica Rust symbolic computation crate"
- "nalgebra Rust linear algebra deterministic IEEE 754"
- "rug GNU MP arbitrary-precision Rust"
- "inari IEEE 1788 interval arithmetic Rust"
- "tree-sitter grammar SHA pinning reproducibility"
- "rustc --no-execute static analysis pipeline"
- "byte-reproducible build Rust pinned toolchain"
- "dimensional analysis compile-time Swift Quantity type"
```

#### T+13 — Master Hardening + Wiring + Product Expression Audit
```
- "static analysis Swift dead code unused symbol Apple"
- "@MainActor Swift 6 strict concurrency violation grep pattern"
- "SwiftUI @Query invalidation storm SwiftData performance 2026"
- "SwiftLint rule unused private symbol unreachable code"
```

#### T+14 — Deterministic Knowledge Runtime v1
```
- "phf Rust compile-time perfect hash 100K entries benchmark"
- "rkyv vs FlatBuffers vs Cap'n Proto schema evolution Rust"
- "BoltFFI 1000x speedup Swift Rust shared memory benchmark"  ← will return little; the term is from user's research
- "shared memory SPSC ring buffer Swift Rust mmap"
- "@ViewBuilder exhaustive switch SwiftUI Swift macro"
- "SwiftUI AnyView performance cost vs concrete view 2026"
- "Apple WAL F_FULLFSYNC F_BARRIERFSYNC SQLite durability"
- "GRDB swift WAL mmap performance pragma"
- "criterion vs divan Rust benchmark allocation tracking"
```

#### T+15 — Final ambitious work
```
- "Apple Mirror Speculative Decoding ANE GPU draft target arXiv 2510.13161"
- "Apple Neural Engine ANEMLL 1B model benchmark INT8"
- "MoLoRA per-app adapter routing macOS hot swap"
- "VLM2VLA catastrophic forgetting natural language action representation arXiv 2509.22195"
- "UI-TARS computer use ScreenSpotPro arXiv 2501.12326"
- "ODIA overnight distillation in-memory adaptation LoRA"
- "Apple Design Award submission macOS app criteria 2026"
- "FSRS-6 spaced repetition note review formula"
```

### §7.4 — Real-time deliberation cadence

The user said *"deliberate in real time on every single pass, every single phase"*. Operationalize this:

```
Per slice (within a phase):
  1. Open the deliberation brief for this phase (or create if first slice)
  2. Note any new question that surfaced from prior slice
  3. If question is novel: do micro-deliberation — read 1-3 specific
     disk files + 2-3 web sources + add finding to the brief's §C
  4. Implement the slice
  5. After slice: append "what I learned" to brief's §E for the next slice

Per phase transition:
  Before exiting phase T+N to enter T+(N+1):
    - Confirm phase brief is complete and Codex-approved
    - Open fresh brief for next phase per §7.2 template
    - Read the next phase's §1 list in full + run its §7.3 web keywords
    - Surface the new brief before any code in the new phase

Per session boot:
  Read §2 cross-cutting list FIRST.
  Then check: is there an open phase deliberation brief? If yes, read
  it before resuming work. If no, you're between phases — open the next
  brief per §7.4 phase transition.
```

### §7.5 — Codex audit of deliberation briefs

When Codex audits a brief, it checks:

1. **Completeness**: §A through §E all populated with specific evidence
2. **Source diversity**: at least 2 disk files + 2 web sources
3. **Citation discipline**: every claim has a path or URL + date
4. **Trade-off honesty**: at least one "do nothing / defer / reuse" option in §D matrix
5. **Doctrine alignment**: §C synthesis cites MASTER_FUSION / PLAN_V2 / CLAUDE.md sections
6. **Reversal triggers**: §E specifies what would force the decision to be undone
7. **No `[UNVERIFIED]` claims smuggled in as verified**: if a research file marked something `[UNVERIFIED]`, the brief preserves that marker

If any check fails, Codex returns the brief with corrections required. The phase does not proceed until the brief passes.

### §7.6 — Why this matters

Without real-time deliberation, agents:
- Reach for whatever pattern they remember last
- Adopt research claims as fact (esp. `[UNVERIFIED]` ones like "BoltFFI 1000×")
- Build first and learn the trade-offs only when something breaks
- Re-learn the same lesson per session

With deliberation:
- Every choice has cited evidence
- Every trade-off has an explicit alternative considered
- Every decision has a measurable reversal trigger
- The deliberation briefs become a long-term record that future sessions and future audits can re-check

The cost is ~30-60 minutes of structured reading + web research per phase. The savings is weeks of "wait, why did we do it this way?" debugging downstream.

---

## §6 — Provenance

| Date | Event |
|---|---|
| 2026-04-27 | Index authored. Mapped ~440 research files to 15 implementation phases (T+1 through T+15) + 9 cross-cutting topics + canonical disk paths. Binding rule established: agents read corresponding §1 list before each phase, §2 list every session, §3 lookup mid-implementation. |

---

**END OF RESEARCH_INDEX_BY_FEATURE.md**

> *"Performance is a product feature, not an optimization pass. Research is a context feature, not a search burden. Read before you build."*
