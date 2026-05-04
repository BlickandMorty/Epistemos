# NEXT_SESSION_BOOTSTRAP.md — The single prompt for a fresh session

> **Authored**: 2026-04-27
> **Purpose**: Paste-as-message into a fresh Claude Code / Codex / Cowork session. This single message provides all the nuance + routing + execution discipline needed to continue work on the **current implementation cluster** without re-explaining anything.
> **Current cluster**: CLI integration + Hermes integration + Halo Contextual Shadows + workspace dual-editor + landing wave style. **All composed with the four pillars (N1 PromptTree + N2 Concept Door + N3 Exploration Spectrum + N4 Local Analysis Mode).**
> **Status**: This file IS the prompt. Copy from after the next `---` to the end of file. Paste into a fresh agent's first message.

---

# EPISTEMOS — Implementation Cluster Continuation

You are continuing work on **Epistemos** at `/Users/jojo/Downloads/Epistemos/`. Native macOS cognitive workspace. Swift 6.2 + Rust (UniFFI) + Metal + GRDB + MLX-Swift + Apple Foundation Models on macOS 26.

## Quick reference card (read this first — 30 seconds)

```
THE FOUR PILLARS (the cognitive exoskeleton):
  N1 PromptTree              prompt is data, not strings           [SHIPPED]
  N2 Concept Door            every concept opens a world           [V1.5 — see CONCEPT_DOOR_N2.md]
  N3 Exploration Spectrum    meter reshapes deliberation           [V1.5 — see EXPLORATION_SPECTRUM_N3.md]
  N4 Local Analysis Mode     deterministic math/ML verification    [V1.5 — see LOCAL_ANALYSIS_MODE_N4.md]

CURRENT WORK CLUSTER (do NOT expand beyond this):
  1. Halo + Contextual Shadows  V1 ship-critical, App Store differentiator
  2. CLI integration            Claude Code / Codex / Gemini / Hermes — Pro primarily
  3. Hermes integration         UX-privileged, NOT substrate-sovereign
  4. Workspace dual-editor      Prose native + Document Tiptap-in-WKWebView (DO NOT REWRITE — see EDITOR_VERDICT)
  5. Landing wave search        GPU Metal ASCII, NO per-frame Rust

THE FOUR BINDING RULES:
  1. Code is verification evidence, NOT architectural authority. Contradictions = DRIFT, surface them.
  2. Benchmark harness is the absolute first step for any FFI/perf work — instrument before changing.
  3. The editor is settled. Don't rewrite Tiptap-in-WKWebView. Don't port AppFlowy. See EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md.
  4. ac8c6d28 is THE canonical verified HEAD (audit floor). Any commit since is SUSPECT until re-audited via the §4.2 checklist in CODEX_VERIFIED_STATE_2026_04_25.md. Do not trust continuity. Re-prove it.

THE TWO PROFILES:
  MAS = sandboxed App Store, V1 = Halo only, no shell/Docker/CLI subprocess
  Pro = direct distribution, post-V1, all the autonomy + CLI + Hermes + computer use

THE OUTPUT CONTRACT:
  First response = Loaded constraints summary + Implementation plan + STOP for approval.
  No code until approved. After approval: 15 anti-patterns + four-layer event hierarchy + perf budget + WRV proof.
```

---

## Full context

**The current work cluster** (do NOT expand beyond this):
1. **Halo + Contextual Shadows** (V1 ship-critical, the only differentiator for App Store)
2. **CLI integration** (Claude Code / Codex / Gemini / Hermes — Pro mode primarily)
3. **Hermes integration** (UX-privileged, integration-privileged, NOT substrate-sovereign)
4. **Workspace dual-editor** (Prose native + Document Tiptap-in-WKWebView; **the editor is settled — do NOT rewrite**)
5. **Landing wave search style** (GPU Metal ASCII, NO per-frame Rust, NO touching other search bars)

These compose with the **four cognitive pillars**:
```
N1 PromptTree              — prompt is data, not strings           (SHIPPED)
N2 Concept Door            — every concept opens a world (vertical depth)
N3 Exploration Spectrum    — meter reshapes deliberation per query (lateral exploration)
N4 Local Analysis Mode     — deterministic math/ML verification of output (rigor)
```

---

## §1 — Authority hierarchy (BINDING — do not invert)

```
1. /Users/jojo/Downloads/Epistemos/CLAUDE.md
2. /Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md          ← architectural truth (1631 lines)
3. /Users/jojo/Downloads/Epistemos/docs/MASTER_BUILD_PLAN.md             ← operational queue + WRV gate
4. /Users/jojo/Downloads/Epistemos/docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md
5. /Users/jojo/Downloads/Epistemos/docs/plan/01_DOCTRINE.md
6. /Users/jojo/Downloads/Epistemos/docs/plan/02_BUILD_MATRIX.md          ← MAS / Pro gating
7. /Users/jojo/Downloads/Epistemos/docs/plan/03_EXECUTION_MAP.md         ← per-item depth
8. /Users/jojo/Downloads/Epistemos/docs/plan/04_PHASES.md
9. /Users/jojo/Downloads/Epistemos/docs/plan/05_RESEARCH_INDEX.md
10. /Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/MASTER_FUSION.md  ← synthesis layer (NOT the queue)
```

**Code reality is verification evidence, not architectural authority.** If code contradicts these, mark as **DRIFT** and surface. Do NOT silently declare "code wins."

---

## §2 — Pre-flight reads (do these BEFORE any change)

Read in this exact order:

```
1. docs/READ_FIRST.md                                                       ← clean entry point
2. docs/_consolidated/00_canonical_authority/CODEX_VERIFIED_STATE_2026_04_25.md ← THE audit floor (ac8c6d28 = last verified HEAD)
3. docs/_consolidated/00_canonical_authority/MASTER_FUSION.md               ← especially §0.0 (audit floor) + §0.1 (ref fallback) + §6 + §16 + §17 + §18 + §19
4. docs/_consolidated/00_canonical_authority/ambient_V1_DECISION.md         ← V1 verdict — Halo is the ONLY differentiator
5. CLAUDE.md                                                                 ← code standards + provider matrix + DO NOT list
6. docs/architecture/PLAN_V2.md                                              ← architectural authority
7. docs/MASTER_BUILD_PLAN.md                                                 ← operational queue
8. docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md                                  ← contract
9. docs/plan/01_DOCTRINE.md                                                  ← doctrine
10. docs/plan/02_BUILD_MATRIX.md                                             ← MAS/Pro split
```

**STEP 0 BEFORE ANY CHANGE**: run the audit-floor verification per `CODEX_VERIFIED_STATE_2026_04_25.md §4.2`:

```bash
git log ac8c6d28..HEAD --oneline                                            # any commits since? all suspect.
git diff ac8c6d28..HEAD -- Epistemos/Views/Notes/ProseEditor*.swift         # MUST be empty (protected)
git diff ac8c6d28..HEAD -- graph-engine/ Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Graph/HologramController.swift  # motion-only edits if any
git stash list                                                              # check for stash@{0} (W9.21 PR4 + W9.8 partial)
```

If any of these reveal post-`ac8c6d28` work, that work goes through full re-audit (Codex diff review + build verification + doc accuracy + invariant re-check) BEFORE being treated as accepted. **Continuity is not inherited; it is re-proven.**

Then for the **current cluster specifically**, load the relevant research dossiers:

### For Halo + Contextual Shadows (V1 ship)
```
docs/_consolidated/00_canonical_authority/ambient_V1_DECISION.md             ← 6-state FSM + perf budget + Apple Design Award angle
docs/_consolidated/70_design_implementation/ambient_swift_rust_metal_blueprint.md
docs/_consolidated/70_design_implementation/ambient_contextual_shadows_blueprint.txt
docs/_consolidated/50_research_corpus/ambient_dir/                            ← all 4 ambient research files
docs/_consolidated/20_canonical_research/perf_DETERMINISTIC_PERFORMANCE_PLAN.md ← 6-sprint perf program
```

### For CLI integration (Pro mode)
```
docs/_consolidated/30_cli_integration/CLI_CONFIG_COMPILATION_RESEARCH.md     ← 1161 lines, authoritative compiler reference
docs/_consolidated/30_cli_integration/claude-code-codex-parity-options.md    ← runtime path comparison
docs/_consolidated/30_cli_integration/capability-tunnels.md                  ← 4-tunnel strategy (A shell / B.1 URL MCP / B.2 stdio MCP / C CLI passthrough)
docs/_consolidated/30_cli_integration/mcp-url-servers.md                     ← Tunnel B.1 deep-dive
docs/_consolidated/50_research_corpus/advice/claudy research.md              ← CLI discovery probe order (NSWorkspace → known paths → version pinning → GRDB 24h TTL)
```

### For Hermes integration (Pro mode primarily; some MAS-safe seams)
```
docs/_consolidated/20_canonical_research/HERMES_INTEGRATION_RESEARCH.md      ← Fast Pack 10 + Deep Pack 30 + 40-file Hermes list
docs/_consolidated/20_canonical_research/hermes_research/                    ← 10 hermes-* files (bundling + expert-mode + risks + strategic-fork + tool-catalog + update-strategy + wire-protocol + local-models-16gb)
docs/EPISTEMOS-HERMES-PARITY-PLAN.md                                         ← 5-phase closure plan (H.1-H.5 in MASTER_FUSION §6.7)
docs/EPISTEMOS-CODEX-PLAN.md                                                 ← Hermes parity through Claude Code
```

**Hermes positioning** (binding, from MASTER_FUSION §11.2): *"Hermes is UX-privileged and integration-privileged, but not substrate-sovereign."* May receive dedicated UX + Hermes mode + branded landing + foreman-for-demos + epistemos-hermes-mcp seam + skill projection. May NOT bypass provider routing / approval / WRV / provenance / A2UI validation. **Removing Hermes must not break core Epistemos.**

### For Workspace dual-editor (V1.5)
```
docs/_consolidated/00_canonical_authority/EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md       ← BINDING: Leave Tiptap alone. Don't port AppFlowy. Benchmark first.
docs/_consolidated/70_design_implementation/workspace_epistemos_code_verdict.md      ← Code Editor architectural lock
docs/_consolidated/70_design_implementation/workspace_gpt_workspace_architecture.md
docs/_consolidated/70_design_implementation/workspace_gpt_workspace_synthesis.md     ← .epdoc package + universal artifact envelope
docs/_consolidated/30_canonical_operational/CODE_EDITOR_POLISH_SCOPE.md              ← Phase S 4 items (~2 days)
docs/_consolidated/70_design_implementation/perf_editor_120fps_v1.md                 ← 120fps optimization (3 perspectives)
docs/_consolidated/70_design_implementation/perf_editor_120fps_v2.md
docs/_consolidated/70_design_implementation/perf_editor_120fps_v3.md
```

### For Landing wave search style
```
docs/_consolidated/30_canonical_operational/LANDING_WAVE_SEARCH_PLAN.md      ← 160×80 ASCII grid @ <1ms GPU per frame, M-series target
```

### For the four pillars (compose with everything)
```
docs/_consolidated/00_canonical_authority/CONCEPT_DOOR_N2.md                 ← N2 minimal surface, infinite depth
docs/_consolidated/00_canonical_authority/EXPLORATION_SPECTRUM_N3.md         ← N3 meter + scientist-of-words mode + diffusion-distillation
docs/_consolidated/00_canonical_authority/LOCAL_ANALYSIS_MODE_N4.md          ← N4 deterministic verification (toggle: λ icon, ⌘⇧L)
docs/PROMPT_AS_DATA_SPEC.md                                                  ← N1 (SHIPPED)
```

### For execution context
```
docs/V1_5_IMPLEMENTATION_TRACKER.md                                          ← live status board
docs/AGENT_PROGRESS.md                                                       ← session log
docs/CANONICAL_AUDIT_LOG.md (tail)                                           ← what's drifting
docs/CRITIQUE_LOG.md (tail)                                                  ← per-commit findings
docs/KNOWN_ISSUES_REGISTER.md                                                ← 19-bug register
docs/_consolidated/10_living_audits/FUSED_AUDIT_VIEW.md §2                   ← top-of-queue Blockers
```

### Architecture specs (PLAN_V2 sources — load when item touched)

These are the load-bearing PLAN_V2-referenced specs. They live in `docs/architecture/` (originals — DO NOT MOVE) and have copies in `docs/_consolidated/20_canonical_research/architecture_specs/`. Either path resolves. **Read the one that matches your task topic:**

| Spec | What it provides | When to load |
|---|---|---|
| `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` | **THE N2 typed-artifact-spine implementation plan.** ArtifactKind enum (7 kinds: ProseNote, Document, RawThought, Source, Code, Run, Output), ArtifactHeader + ProvenanceBlock schemas, current status (80% Raw Thoughts done, 30% typed graph types done, .epdoc NOT yet built, Document editor host NOT yet built). Single-line invariant: **"Filesystem is durable. Graph is rebuildable. Artifact identity is stable."** | When working on N2 Concept Door, typed artifacts, Raw Thoughts persistence, .epdoc package, or workspace dual-editor |
| `docs/architecture/EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN.md` | **Benchmark harness is the absolute first step** — no migration, no editor work, no BoltFFI prototype until instrumentation exists. 5 BoltFFI priority surfaces, divan vs criterion, signpost subsystem `com.epistemos.ffi`. First migration target: graph Data Loading + Queries + Search (single typed buffer layout covers all three). Required deliverables: `EpistemosTests/FFIBenchmarkBaselines.swift` + `graph-engine/benches/graph_ffi_baselines.rs` + `docs/architecture/BENCHMARK_BASELINES.csv`. | When working on performance, BoltFFI carve-out, or any FFI-related slice |
| `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md` | BoltFFI carve-out strategy (PLAN_V2 §22 source). NO mass-migration; narrow `substrate-rt` carve-out via `repr(C)` ring buffer. | When touching FFI hot-path |
| `docs/architecture/COMPUTE_STEERING_SPEC_v1.md` | PLAN_V2 §8 source. DIET/DIP experiments behind flags + expert budget classes + KV policy abstraction + mask compiler. | Phase 2 work, also relevant to **N3 Exploration Spectrum** (the meter that modulates compute) |
| `docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md` | PLAN_V2 §9 source. LoRA micro-updates + guardrail overseer + SSM memory sidecar. Anchor/canary/rollback discipline + allowlisted inputs + helper-model-first. | Phase 3 work, also relevant to **N4 Local Analysis Mode** (deterministic adaptation rollback) |
| `docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md` | PLAN_V2 §10-11 source. Overseer role + agent hierarchy + reasoning profiles + execution policy refs + plan trace protocol + local guardrail skeleton. | When working on agent system, capability handshake, or Hermes integration |
| `docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md` | **V1 ship-critical**. 5 canonical findings: (1) silent-answer = post-processing bug in `Engine/Extensions.swift` (UserFacingModelOutput must fail-open); (2) local freezing = actor/lifecycle problem in MLXInferenceBridge + LocalAgentLoop (need dedicated inference actor); (3) local model safety = runtime-policy gap (need admission control before load + one-active-model + eviction); (4) FFI multi-turn continuity = biggest engine-level win still missing (Rust still starts fresh each session call); (5) thinking UI is serviceable but not end-state. | When closing V1 release blockers — pick one of the 5 findings to address per slice |
| `docs/architecture/PERF_REPAIR_REPORT_2026_04_21.md` | Concrete bugs + fixes (2026-04-21): semantic note lookups not propagated, fenced ` ```tool_call ` blocks not parsed, MLX Metal working set never released on unload, direct-stream cloud path advertised app tools it can't execute, Mini Chat showing `Thinking` while in `Tools` mode (UI lying about execution path). File:line evidence per bug. | When debugging streaming/runtime symptoms — grep this for the symptom you see |
| `docs/architecture/CHAT_TRANSPARENCY_PLAN_2026-04-19.md` | Chat transparency UX shipping log: EffectiveModelBadge SHIPPED (Batch I/J), context side panel SHIPPED, routing rationale popover SHIPPED, error bubble recovery buttons SHIPPED. P1+P2+P3 backlog with research citations (Perplexity / NotebookLM / Continue.dev / Cursor / Aider patterns). | When working on chat UI — check what's already shipped vs what's still pending |
| `docs/architecture/MASTER_PLAN_2026-04-19.md` | Sprint commit log (chat routing + picker UX + chat transparency + theme polish + perf + model stack). Cross-references RELEASE_HARDENING_CANONICAL_PLAN as tighter canonical successor. | Historical context only |

**`PLAN_V2_UPDATED.md`** in `docs/architecture/` is a SUPERSEDED variant — canonical `PLAN_V2.md` stays. **`NEW_SESSION_PROMPT.md` + `NEW_SESSION_PROMPT_AUDITED.md` + `CODEX_CONTEXT_PACK.md` + `PLAN_V2_CANONICALIZATION_*.md` + all `PHASE_*_HANDOFF.md`** are SUPERSEDED-HISTORICAL handoffs (this `NEXT_SESSION_BOOTSTRAP.md` supersedes them).

**Performance baselines** (CSV data, not narrative): `docs/architecture/BENCHMARK_BASELINES.csv` + `docs/architecture/AGENT_STREAM_BASELINES.csv` — committed baseline numbers from Instruments runs. Source-of-truth for "did we regress?" checks.

---

## §3 — Reference-fallback algorithm (BINDING — when path is null)

If you read a reference path and it doesn't exist (file moved, renamed, or archived):

```
1. Try the path as written. If exists, use it.

2. If NOT found:
   a. Extract basename
   b. Run: find docs/_archive -name "<basename>" -type f
   c. If exactly one match: use it. Note "archive-resolved" in your audit.
   d. If multiple: prefer cluster matching the original parent dir
      (e.g., docs/plans/X.md → _archive/plans_old/X.md)
   e. If no archive match: search docs/_consolidated/50_research_corpus/
   f. If still nothing: report [BROKEN-REFERENCE: <path>]. DO NOT GUESS.

3. Read banner (first 10 lines):
   - SUPERSEDED-HISTORICAL → follow "Superseded by:" pointer; original is for state recovery only
   - TRANSIENT-CANDIDATE → context only
   - CANONICAL-* / DEFERRED-RESEARCH → still active
```

**Cluster naming in `docs/_archive/`** (113 files):
- `plans_old/` (32) — older plan tree predecessor
- `google_research_packs/` (17) — pre-canonical Google research
- `architecture_handoffs/` (16) — phase handoffs from architecture/
- `sessions_handoffs/` (13) — one-off session reports + dated handoffs
- `audits_old/` (8) — superseded by canonical living logs
- `sprint_sessions_old/` (7) — older sprints (sprint-omega-1-foundation kept in place)
- `theme_shipped/` (6), `omega_retired/` (5), `kimi_goose_research/` (5), `knowledge_fusion_old/` (4)

See `docs/_archive/MANIFEST.md` for exhaustive per-cluster list. **Files canonical-class never appear in `_archive/`** — finding one there is drift.

---

## §4 — The 15 anti-patterns (BINDING — see MASTER_FUSION §11)

1. No silent backend rerouting (always log routing decisions)
2. No dropped errors during agent streaming
3. No exposing unsupported capabilities as supported
4. No `try!` in production paths
5. No force-unwraps (`!`) on optionals
6. No `print()` in production paths (use OSLog with categories)
7. No `AnyView` — use `@ViewBuilder` and concrete types
8. No `unsafe` blocks without `// SAFETY:` comment
9. No mutating state from observed Combine/AsyncSequence in `body`
10. No I/O overlap in serial-streamed paths (serial invariant)
11. No fake success on capability denial
12. No direct chat-to-weight path (poisoned adaptation defense)
13. No unstructured masks (mask must compile or block; never default-allow)
14. No allocation in hot paths (use arenas, mmap, preallocated buffers)
15. No JSON strings on hot FFI paths (use stable ABI structs, numeric IDs, shared memory)

Plus (from §11.1–§11.3):
- **Production**: no fallback inspector. Unknown A2UI schemas → `VALIDATION_FAILED`. **DEBUG-only**: quarantine renderer, must NOT compile into ReleasePro/MAS.
- **No local model inference sidecar.** Pro-only: installed CLI provider adapters under explicit policy.
- **MAS rule**: MAS target must NOT spawn arbitrary user-installed coding CLIs.

---

## §5 — Four-layer event hierarchy (BINDING — see MASTER_FUSION §3.5)

```
RunEventLog       — durable record of observable runtime activity
MutationEnvelope  — durable record of graph/state mutation
AgentEvent        — hot UI projection
GraphEvent        — Metal/render projection
```

Commit ordering: receive RunEvent → validate MutationEnvelope (if mutation) → classify sensitivity + redact → commit → enqueue projection → commit → emit AgentEvent + GraphEvent **after** commit. **Never emit UI success before durable state succeeds.**

`RunEventLog` is append-only, ordered by `(run_id, sequence)`, BLAKE3-Merkle-chained for integrity. High-volume token/bash deltas roll into compressed `transcript.jsonl.zst` — NOT into the durable event log.

---

## §6 — Performance budget (BINDING — see MASTER_FUSION §17.3)

```
MainActor work per recall update:        target < 1 ms,  hard ceiling 2 ms p99
Debounce window:                         target 200 ms,  hard ceiling 250 ms
FFI hop:                                 target < 0.5 ms, hard ceiling 1 ms
Model2Vec encode:                        target < 2 ms,  hard ceiling 4 ms
usearch HNSW top-k:                      target < 5 ms,  hard ceiling 10 ms
Tantivy BM25:                            target < 8 ms,  hard ceiling 12 ms
RRF fusion + metadata fetch:             target < 3 ms,  hard ceiling 5 ms
End-to-end recall pass after debounce:   target < 25 ms, hard ceiling 40 ms
Perceived recall after debounce:         target < 100 ms
Graph frame budget:                      never exceed display target
```

Every hot path needs `os_signpost`. **If a feature cannot be measured, it cannot be claimed.**

---

## §7 — Execution loop (the actual work)

For each turn:

```
Step 1. Read pre-flight (§2 above) IF not already loaded.
Step 2. Check /Users/jojo/Downloads/Epistemos/docs/_consolidated/10_living_audits/FUSED_AUDIT_VIEW.md §2
        for the top-of-queue Blocker. Pick ONE item.
Step 3. Cross-reference MASTER_FUSION.md §6 for status (✅🟡🟠🔴❓⚪🆕) and effort estimate.
Step 4. Cross-reference 03_EXECUTION_MAP.md for per-item depth + WRV expectations.
Step 5. If item touches CLI: read 30_cli_integration/* dossiers first.
        If item touches Hermes: read hermes_research/* + EPISTEMOS-HERMES-PARITY-PLAN first.
        If item touches Halo: read ambient_V1_DECISION + ambient_swift_rust_metal_blueprint first.
        If item touches workspace/editor: read EDITOR_VERDICT_TIPTAP_VS_APPFLOWY + workspace_epistemos_code_verdict + workspace_gpt_workspace_synthesis. **DO NOT rewrite the editor.**
        If item touches typed artifacts / N2 Concept Door: read COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md FIRST (the canonical implementation plan; extend, don't redefine).
        If item touches FFI / performance: read EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN.md §1.1 FIRST. **Benchmark harness is the absolute first step — instrument before changing.**
        If item touches landing wave: read LANDING_WAVE_SEARCH_PLAN.
        If item touches V1 release blockers: read RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md (5 canonical findings RH.1-RH.5).
        If item touches chat UI: read CHAT_TRANSPARENCY_PLAN_2026-04-19.md to check what's ALREADY shipped (don't redo SHIPPED batches).
Step 6. Produce a **loaded constraints summary** (per §0 of master prompt):
        - authority hierarchy referenced
        - current item ID + status
        - file paths to inspect/touch
        - performance budgets
        - MAS/Pro implication
        - composition with N1/N2/N3/N4 (if any)
        - WRV proof path
Step 7. STOP. Wait for human approval or proceed if WRV gate explicit.
Step 8. Implement under the 15 anti-patterns + four-layer event hierarchy.
Step 9. Run verification:
        ./scripts/audit/release_preflight.sh
        ./scripts/audit/verify.sh --fix-format
        xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
        xcodebuild ... test
        cargo test --manifest-path graph-engine/Cargo.toml
        cargo test --manifest-path agent_core/Cargo.toml
        (and other relevant Cargo manifests)
Step 10. Three-pass deep verification (per AGENT_DEEP_VERIFICATION_MANUAL):
         code + logs + runtime + persistence MUST agree.
         Three uninterrupted zero-fail passes for READY verdict.
Step 11. Update MASTER_FUSION §6 status (⚪ → 🟡 or ✅), V1_5_IMPLEMENTATION_TRACKER, AGENT_PROGRESS.
Step 12. Commit per MASTER_BUILD_PLAN §10 commit format with WRV proof block.
```

---

## §8 — Cluster-specific micro-checklists

### Halo + Contextual Shadows (V1 ship-critical — DO NOT EXPAND)

Per `ambient_V1_DECISION.md`, V1 = Halo+Shadows ONLY. NOT Docker, NOT shell, NOT computer-use, NOT full agent platform.

- [ ] Rust `epistemos-shadow` crate exists or wired (embed/ann/lexical/fusion/store/state/ffi/error)
- [ ] Stack locked: Model2Vec `potion-retrieval-32M` + usearch HNSW + Tantivy BM25 + weighted RRF (k=60)
- [ ] Narrow UniFFI surface (5 functions: insert / remove / search / flush / stats)
- [ ] Swift `HaloController` (@MainActor @Observable) + `ShadowSearchService` (actor, off-main FFI) + `ShadowIndexingService` (actor, dirty queue) + `ShadowPanelController` (NSPanel non-activating)
- [ ] 6-state FSM: Dormant → Sensing → Available → Open → EditingNote / SummarizingChat / errorRecoverable
- [ ] Debounce 200ms, cancel stale, ignore out-of-order generations
- [ ] Panel does NOT steal editor focus
- [ ] VoiceOver labels per state, reduceMotion respected, keyboard nav works
- [ ] os_signpost on every hot-path stage
- [ ] Privacy: local-only by default
- [ ] No external subprocess required
- [ ] WRV: Wired (UI exists) + Reachable (typing triggers it) + Visible (Halo renders)

### CLI integration (Pro mode primary)

Per `capability-tunnels.md`: 4-tunnel strategy.
- **Tunnel A** (shell): Pro only, gated by approval, scrubbed env, kill-on-drop
- **Tunnel B.1** (URL MCP): `~/.config/mcp/url_servers.json` — see `mcp-url-servers.md`
- **Tunnel B.2** (stdio MCP): standard MCP server pattern
- **Tunnel C** (CLI passthrough): subprocess CLI, Pro only

Per `CLI_CONFIG_COMPILATION_RESEARCH.md`:
- Project-scoped MCP belongs in `.mcp.json` — NOT `.claude/settings.json`
- `mcpServers` in `.claude/settings.json` is ignored by Claude Code
- Keep root `CLAUDE.md` lean; per-path rules in `.claude/rules/*.md`

ProviderDiscovery must be **passive**:
- Allowed: `which <binary>`, `<binary> --version`, `<binary> --help`, repo-local manifest reads
- Forbidden without user approval: paid model prompts, auth file reads, env var dumps, config writes, daemon starts

CLI discovery probe order (per `claudy research.md`): NSWorkspace → known paths → version pinning → GRDB 24h TTL cache.

### Hermes integration

Per `EPISTEMOS-HERMES-PARITY-PLAN.md` 5-phase closure:
- **Phase 1** (30 min): Register 5 orphaned tools (delegate_task / file_ops / memory / skills / web_fetch) in `agent_core/src/tools/registry.rs`
- **Phase 2** (2-3 days): Build 7 new tools (rate-limit tracker / code exec sandbox / todo mgmt / clarify / title generator / process registry / structured compaction templates)
- **Phase 3** (1-2 days): 15 pre-built skills at `[vault]/skills/`
- **Phase 4** (1 day): Wire orphaned Swift (CredentialPool / HookRegistry / KnowledgeIndexBuilder / LiveNoteScheduler / DataviewService / EpistemicStatus)
- **Phase 5** (30 min): Connect dead-code (`should_pierce_blanket()`, `compute_trajectory_metrics()`)

**Verify before assuming**: `grep -rn "delegate_task|file_ops|memory.rs|skills.rs|web_fetch" agent_core/src/tools/registry.rs`

Hermes runtime path (Pro only): managed Python subprocess. Lazy startup + crash loop protection + local HTTP/SSE on 127.0.0.1 random high port + CSPRNG token + approval shim + signed bundle/notarization. **MAS path**: native Rust planner adopting Hermes XML tool-call conventions + agentskills.io skill format.

### Workspace dual-editor

Per `workspace_epistemos_code_verdict.md`:
- Swift+TextKit2 owns surface
- **SwiftTreeSitter on the SwiftUI thread** for live syntax (UTF-16↔UTF-8 mapping cost across Rust FFI is the silent killer — DO NOT route per-keystroke syntax through Rust)
- Rust background brain for project-wide symbols + RAG chunking
- SourceKit-LSP for completion + diagnostics
- Metal viz only for minimap / heatmap / diff overlays

Per `workspace_gpt_workspace_synthesis.md`:
- Prose stays native (TextKit 2)
- Document = `.epdoc` package (manifest.json + content.pm.json canonical + shadow.md lossy + plain.txt + search_blocks.jsonl + assets/ + previews/)
- Raw Thoughts as run-scoped artifacts
- Universal artifact envelope: typed canonical body + projections; FTS5 over normalized search_text; provider-visible reasoning persistence

### Landing wave search style

Per `LANDING_WAVE_SEARCH_PLAN.md`:
- GPU Metal ASCII liquid-wave (160×80 grid @ <1ms GPU per frame on M-series)
- NO Rust per-frame path (Metal/SwiftUI only)
- Zero idle cost; pause when occluded
- Reduced-motion fallback
- DO NOT touch other search bars

---

## §9 — Anti-overbuild stops (BINDING)

If you find yourself doing any of these without explicit user request, **STOP and surface**:

- Adding features the picked Blocker doesn't require
- **Rewriting the Document editor** (Tiptap-in-WKWebView is settled per `EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md` — DON'T port AppFlowy, DON'T add Flutter, DON'T rewrite in native Swift unless benchmarks prove it)
- **Optimizing without measuring** — benchmark harness must come BEFORE any perf change (per `EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN.md §1.1`)
- Real Claude/Codex/Gemini CLI provider adapters in MAS
- Browser automation, Docker/Bollard, Wasmtime/JSC sandboxing
- Full A2UI catalog rebuild
- Co-op Mode, Deep Research Runner, NightBrain
- Manifest compiler, full skill projection
- New graph renderer architecture
- Broad persistence rewrite
- Dependency upgrades unrelated to current item
- Pandoc/Tectonic bundle in V1
- CRDT, code cells, Excalidraw
- Semantic auto-linking everywhere
- Diffusion / unbounded recursion
- LLM-based "double-checker" in N4 verification path
- Re-defining `ArtifactKind` taxonomy (already locked in `COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` — extend, don't redefine)

**The first job is the magical spine. The cathedral comes later.** Per `MASTER_FUSION.md §6.1`, V1 = Halo + Contextual Shadows ONLY. V1.5 = N2 + N3 + N4 + Raw Thoughts + typed artifact spine. Pro = the rest.

---

## §10 — Output format expected

For your first response in this session:

1. **Loaded constraints summary** (200-400 words):
   - Authority hierarchy items I just read
   - Current cluster: Halo / CLI / Hermes / workspace / landing wave (which one specifically am I working on?)
   - Pre-flight reads completed
   - Top-of-queue item from FUSED_AUDIT_VIEW §2
   - Item status from MASTER_FUSION §6
   - MAS/Pro implication
   - Performance budget for this work
   - WRV proof path
   - Anti-overbuild flags to watch

2. **Implementation plan** (numbered steps with file paths)

3. **STOP**. Wait for human approval before writing code.

After approval, implement under §4 anti-patterns + §5 four-layer events + §6 perf budget. Verify per §7 step 9-11. Commit per §7 step 12.

---

## §11 — Final principle

The app must feel **alien-smooth**: typing never blocks, recall appears like a sixth sense, every artifact has identity, every agent/run has provenance, every advanced feature is gated behind a measured inspectable spine.

**The four pillars**:
- **Halo**: ambient recall (V1 ship-critical)
- **Concept Door (N2)**: deliberate depth on a chosen concept
- **Exploration Spectrum (N3)**: meter reshapes deliberation per query
- **Local Analysis Mode (N4)**: deterministic verification of output

Underneath: provenance plane (RunEventLog + MutationEnvelope + AgentEvent + GraphEvent), retraction propagation, BLAKE3 Merkle integrity, closed A2UI catalog, MAS/Pro policy split.

A normal app shows files. **Epistemos reveals thought-objects.**
A normal AI app gives plausible answers. **Epistemos preserves provenance and verifies math/code claims deterministically.**

---

**END OF NEXT_SESSION_BOOTSTRAP.md**

> Paste from "EPISTEMOS — Implementation Cluster Continuation" header (after first `---`) through this END line as your first message in any fresh session. Together with the references it points to, you have full nuance + routing + execution discipline for the current implementation cluster without re-explaining anything.
