# CLUSTER_FUSIONS_INDEX.md — Recursive Loop Targets

> **Authored**: 2026-04-27.
> **Role**: Identifies clusters of related docs in `_consolidated/` that should be fused into single canonical references. **Maintains the recursive loop the user requested**: keep finding docs to fuse, prune duplicates, preserve nuance. Originals never deleted.
> **First worked example**: `30_canonical_operational/AI_STACK_FUSION.md` (4 source docs → 1 layered reference, every claim preserved with attribution).

---

## §1 — How fusion works (the pattern)

For each cluster:

1. **Identify** related docs that say overlapping/sequential things about one subject
2. **Read each in full** — preserve nuance from every source
3. **Author a fused reference** with attribution per claim (`source: <file> §<section>`)
4. **Order layers** logically — current truth → decisions → status → forward-compat → risks → cross-refs
5. **Keep originals intact** with their existing banners — fusion is a navigation layer, not a replacement
6. **Ship to the appropriate `_consolidated/<tier>/` subdir**

When fusion and source disagree: **source wins**. Treat fusion as a synthesis layer for fast onboarding; depth lives in the originals.

---

## §2 — Cluster inventory (to fuse next session)

### Cluster A: **Code Editor** (12 docs → 1 fusion) — HIGHEST VALUE

The largest cluster. Touches multiple architectural concerns: rendering pipeline, tree-sitter, IME, viewport scoping, GPU rendering, debugging.

**Sources** (all in `_consolidated/`):
1. `30_canonical_operational/CODE_EDITOR_DEBUG.md` (debug guide for syntax color invisibility, TextKit1 + NSTextView layout)
2. `30_canonical_operational/CODE_EDITOR_ROOT_CAUSE.md` (root-cause analysis companion)
3. `30_canonical_operational/CODE_EDITOR_POLISH_SCOPE.md` (Phase S 4-item polish: line gutter, debouncing, outline cache, viewport-scoped highlighting)
4. `30_canonical_operational/FEATURE_SPEC_TOC_AND_FOLDING.md` (TOC strip + code folding + CodeSymbol struct 20-byte repr(C))
5. `20_canonical_research/CODE_EDITOR_STACK_RESEARCH.md` (best-path Xcode-grade editor; CodeEditorView recommended)
6. `20_canonical_research/CUSTOM_TEXT_ENGINE_RESEARCH.md` (Zed/Nova/Sublime/VSCode 120fps research)
7. `20_canonical_research/KIMI_AUDIT_REPORT.md` (Kimi editor audit: build passed + 2 perf opportunities)
8. `60_deferred_research/GPU_RENDERER_SEAM.md` (Pro-tier Zed-style GPU pipeline)
9. `70_design_implementation/perf_editor_120fps_v1.md` (TextKit2 + background TreeSitter + Metal MSDF)
10. `70_design_implementation/perf_editor_120fps_v2.md` (ProMotion 8.33ms; SumTree/Rope analysis)
11. `70_design_implementation/perf_editor_120fps_v3.md` (5-phase roadmap; CodeEditSourceEditor 0.13.1+ patches)
12. `70_design_implementation/workspace_epistemos_code_verdict.md` (architectural lock — Swift+TextKit2 surface + SwiftTreeSitter live + Rust background brain + SourceKit-LSP + Metal viz only)

**Fusion target**: `00_canonical_authority/CODE_EDITOR_FUSION.md` (rationale: this is a load-bearing surface; should be canonical).

**Suggested layered structure**:
- §1 — Architectural lock (from `workspace_epistemos_code_verdict`)
- §2 — Three-tier rendering (TextKit2 surface / SwiftTreeSitter live / Metal viz)
- §3 — 120fps techniques (NSTextStorage delegate, MSDF glyph atlas, CADisplayLink keep-alive)
- §4 — Tree-sitter actor isolation
- §5 — Viewport-scoped highlighting + outline cache
- §6 — Phase S polish items (the 4 must-ship)
- §7 — Pro-tier GPU pipeline (deferred; from `GPU_RENDERER_SEAM`)
- §8 — Known issues + debugging (from `CODE_EDITOR_DEBUG` + `CODE_EDITOR_ROOT_CAUSE`)
- §9 — Audit findings (from `KIMI_AUDIT_REPORT`)
- §10 — Risk register
- §11 — Cross-refs to PLAN_V2 §22-23, MASTER_FUSION §6.4

### Cluster B: **AI Stack** (4 docs → 1 fusion) — ✅ DONE 2026-04-27

Sources: `ai_stack_decision_report` + `ai_stack_implementation_plan` + `ai_stack_phase_audit_log` + `ai_stack_risks`.

**Fusion**: `30_canonical_operational/AI_STACK_FUSION.md` — authored. Worked example showing the pattern.

### Cluster C: **Agent System** (~7 docs → 1 fusion)

**Sources** (all in `_consolidated/`):
1. `20_canonical_research/agent_system/AGENT_ARCHITECTURE.md` (CLAUDE.md cited)
2. `20_canonical_research/agent_system/AGENT_CORE_ROLE.md`
3. `20_canonical_research/agent_system/GAP_ANALYSIS.md`
4. `20_canonical_research/agent_system/STARTING_PROMPT.md`
5. `20_canonical_research/agent_system/OPERATOR_MANUAL.md`
6. `20_canonical_research/AGENT_FUSION_RESEARCH_PROMPT.md` (8-project comparative)
7. `20_canonical_research/FUSED_AGENT_ENGINEERING_REPORT.md` (claw-code + OpenClaw + Hermes diagnosis)

**Fusion target**: `00_canonical_authority/AGENT_SYSTEM_FUSION.md`.

**Suggested layered structure**:
- §1 — Honest capability gating (CLAUDE.md + MOAT discipline)
- §2 — Pure Rust agent_core architecture (registry + tools + dispatch)
- §3 — Tool tier classification (built-in 12 + standard 68 + Specialties 19; from EPISTEMOS_SPECIALTIES)
- §4 — Provider matrix (local/cloud capability matrix)
- §5 — Hermes parity status (5-phase closure plan H.1-H.5 from MASTER_FUSION §6.7)
- §6 — DAG executor + Screen2AX (MEGAPROMPT WS2 future work)
- §7 — Gaps + dead code (from GAP_ANALYSIS + FUSED_AGENT_ENGINEERING_REPORT)
- §8 — Operator runbook (from OPERATOR_MANUAL)

### Cluster D: **Codex Handoffs** (~14 docs → 1 fusion or just chronologically ordered index)

**Sources**: All `30_canonical_operational/CODEX_*` files.

**Decision**: **Don't fuse, just chronologically index.** These are operational handoffs that have intrinsic temporal value (what happened on what date). Fusion would lose the timeline. Instead, author a `30_canonical_operational/CODEX_HANDOFFS_TIMELINE.md` that just orders them with summary lines.

### Cluster E: **Hermes Research** (10 docs in `20_canonical_research/hermes_research/`)

**Sources**: `hermes-bundling-build-phase` + `hermes-expert-mode-implementation-spec` + `hermes-expert-mode-research-prompt` + `hermes-expert-view-ui-spec` + `hermes-risks-and-failure-modes` + `hermes-strategic-fork-analysis` + `hermes-tool-catalog` + `hermes-update-strategy` + `hermes-wire-protocol` + `local-models-16gb-mac-april-2026`.

**Fusion target**: `60_deferred_research/HERMES_INTEGRATION_FUSION.md` (deferred since Hermes integration is Phase D / K).

### Cluster F: **Architecture Specs (CANONICAL-RESEARCH)** (6 docs in `20_canonical_research/architecture_specs/`)

**Sources**: `ADAPTATION_SUBSYSTEM_SPEC_v1` + `BOLTFFI_AUDIT_2026_04_15` + `COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN` + `COMPUTE_STEERING_SPEC_v1` + `EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN` + `OVERSEER_AND_AGENT_HIERARCHY`.

**Decision**: **Don't fuse**. These are PLAN_V2 §6-§11 source specs — each is a canonical contract for one subsystem. Fusing would erode contract clarity. Keep as-is.

### Cluster G: **Theme Refactor** (5 docs)

All `SUPERSEDED-HISTORICAL` (theme refactor shipped per memory). **No fusion needed**; banner-only is appropriate.

### Cluster H: **Omega System** (5+ docs)

All `SUPERSEDED-HISTORICAL` (Omega retired per IMPLEMENTATION_PLAN_FROM_ADVICE). **No fusion needed**.

### Cluster I: **Plans tree** (33 docs in `docs/plans/`)

All `SUPERSEDED-HISTORICAL` (older plan tree predecessor). **No fusion needed**.

### Cluster J: **Audits** (54 timestamped audit logs)

All `CANONICAL-OPERATIONAL` (append-only logs). **No fusion needed** — they have intrinsic timeline value.

### Cluster K: **Handoffs** (20 dated session handoffs)

All `CANONICAL-HISTORICAL` (state recovery). **No fusion needed**.

---

## §3 — Decision matrix (when to fuse vs leave alone)

| Pattern | Action | Reason |
|---|---|---|
| Multiple docs on same topic, current+aspirational | **Fuse** | Reduce read-load while preserving nuance |
| Append-only timeline (audits/handoffs) | **Don't fuse** | Timeline IS the value |
| Specs that define separate contracts | **Don't fuse** | Contract clarity |
| Pure SUPERSEDED with banners | **Don't fuse** | They're already navigated past |
| Phased work (Phase 0/1/2 docs) | **Fuse** | Phase fusion = single status board |

---

## §4 — Recursive loop continuation

**Per user**: "continue with it recursively keep on running a loop to find docs to fuse prune etc."

Next pass priorities:
1. **Cluster A (Code Editor) — fuse next** (12 docs → 1; highest leverage; already in 70_design_implementation are the perf v1/v2/v3 dossiers + workspace_verdict)
2. **Cluster C (Agent System) — fuse after A** (7 docs → 1; load-bearing for Phase D / K)
3. **Cluster D (Codex Handoffs) — chronological index** (14 docs → 1 timeline)
4. **Cluster E (Hermes Research) — fuse when Phase D/K starts** (10 docs → 1; deferred)

Per-cluster fusion authoring time: ~30-45 min each (read all sources, draft layered structure, write fusion, cross-link).

---

## §5 — Provenance log

| Date | Cluster | Action | Authored by |
|---|---|---|---|
| 2026-04-27 | B (AI Stack) | Fused 4 docs → `30_canonical_operational/AI_STACK_FUSION.md` | consolidation pass |
| (pending) | A (Code Editor) | 12 docs → `00_canonical_authority/CODE_EDITOR_FUSION.md` | next session |
| (pending) | C (Agent System) | 7 docs → `00_canonical_authority/AGENT_SYSTEM_FUSION.md` | next session |
| (pending) | D (Codex Timeline) | 14 docs → `30_canonical_operational/CODEX_HANDOFFS_TIMELINE.md` | next session |
| (deferred) | E (Hermes Research) | 10 docs → `60_deferred_research/HERMES_INTEGRATION_FUSION.md` | when Phase D/K starts |

---

**END OF CLUSTER_FUSIONS_INDEX.md**
