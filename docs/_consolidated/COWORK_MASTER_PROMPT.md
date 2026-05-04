# Cowork Master Continuation Prompt — Epistemos Consolidation + Resume

> **How to use**: paste this entire file as the first message of a fresh Claude Cowork session.
> **Date authored**: 2026-04-27 by previous Claude session (Phase 1 + Phase 2 of consolidation).
> **Working dir**: `/Users/jojo/Downloads/Epistemos/`.
> **Today's date** at runtime: verify with `date` if session is resumed later.
> **Goal**: complete the consolidation safely (copy-not-move), fill gaps in the fused views, then resume V1.5 coding work with the canonical operational queue.

---

## §0 — Project context (read this first; one paragraph)

Epistemos is a macOS-native Personal Knowledge Management cognitive substrate. Stack: Swift 6.2 + Rust (UniFFI) + Metal + GRDB + MLX-Swift + Apple Foundation Models on macOS 26. Hardware target: 16 GB unified memory Mac (~10–11 GB realistic budget). Distribution: dual build — App Store (sandboxed, "Bounded Intelligence OS") and Pro (Hardened Runtime, "Full Autonomy OS"). The work has accumulated **hundreds of planning + research docs** across the repo and `~/Downloads/`. The previous Claude session built a parallel consolidated view at `docs/_consolidated/` (~93 files copied, 3 fusion docs + 1 master prompt, originals untouched, 3.5 MB total), classified the most prominent docs in `docs/_INDEX.md`, and added canonical-status banners to ~10 important originals. **Major V1 scoping update synced 2026-04-27**: a 12-file research drop from `~/Downloads/{workspace, opt, ambient}/` was incorporated; `ambient_V1_DECISION.md` is now in `00_canonical_authority/` and provides the architectural verdict that V1 = sandboxed App Store ship with Halo + Contextual Shadows as the *only* differentiator (broader items deferred to V1.5). Your job is to continue this work to completion without breaking anything.

---

## §1 — HARD RULES (non-negotiable; read carefully)

1. **NEVER move or delete files.** Copy only. The originals at `/Users/jojo/Downloads/Epistemos/docs/`, `/Users/jojo/Downloads/Advice/`, `/Users/jojo/Downloads/final/`, `/Users/jojo/Downloads/final v2/`, `/Users/jojo/Downloads/final v3/` must stay bit-identical to current state.
2. **NEVER edit a file you have not read in full** (per user's explicit "preserve nuance" rule). For files >25 K tokens, use `Bash split` to chunk and read every chunk. The previous session demonstrated this technique with `/tmp/eps_chunks/`.
3. **Originals win on conflict.** `_consolidated/` is a derived navigation view, not source of truth.
4. **Banner-then-classify**: when you find a doc not yet labeled, READ it, then add a status banner at the top of the **original** (one of: `CANONICAL`, `CANONICAL-RESEARCH`, `CANONICAL-OPERATIONAL`, `DEFERRED-RESEARCH`, `SUPERSEDED-HISTORICAL`, `TRANSIENT-CANDIDATE`). Then if it's any of the first four, COPY it to the appropriate tier in `_consolidated/`. If it's `SUPERSEDED-HISTORICAL`, leave the original in place with the banner; do NOT copy. If it's `TRANSIENT-CANDIDATE`, surface it to user before any action.
5. **Update `docs/_INDEX.md`** AND `docs/_consolidated/00_canonical_authority/_INDEX.md` (re-copy after edit) when you classify new files.
6. **Surface to user before any deletion or mass move.** Even if a file looks transient, ASK FIRST.
7. **Preserve `[UNVERIFIED]` markers** when citing research. Do not strip them.
8. **No git operations** without explicit user consent — no `git rm`, no `git mv`, no commits, no force-push, no rebase.
9. **Work in this directory ONLY**: `/Users/jojo/Downloads/Epistemos/`. Do not touch other dirs.
10. **Use `cp`, not `mv`.** Use `2>/dev/null || true` after `cp` to skip missing files quietly. Verify each batch with `find <dir> -type f | wc -l` after.

---

## §2 — Three modes — the user will pick one (or rotate through them)

### Mode A — Continue consolidation (process unprocessed docs)

There are ~150–200 unprocessed docs across `docs/` root + subdirs. Read each, classify it, banner the original, and copy to the appropriate tier in `_consolidated/`. **Detailed workflow in §7 below.**

### Mode B — Verify `_consolidated/` vs originals + fill gaps

The previous session created 3 fusion docs:
- `docs/_consolidated/README.md`
- `docs/_consolidated/10_living_audits/FUSED_AUDIT_VIEW.md`
- `docs/_consolidated/50_research_corpus/00_FUSED_RESEARCH_DIGEST.md`

Compare each fusion doc against the source originals it claims to synthesize. Find gaps. Add missing items. Verify checksum-style that no copies were corrupted. **Detailed workflow in §8 below.**

### Mode C — Resume V1.5 coding work

Consolidation is "good enough"; pick up the operational queue and ship the highest-priority V1.5 Blocker. Use `docs/_consolidated/00_canonical_authority/MASTER_BUILD_PLAN.md` §0 loop pattern. Top-of-queue items are listed in `docs/_consolidated/10_living_audits/FUSED_AUDIT_VIEW.md §2` priority order. **Detailed workflow in §9 below.**

---

## §3 — What's already done (don't redo)

### Edits to originals (banners + index entries; non-destructive additions)

1. `docs/plan/README.md` — canonical-pointer banner added (points at `MASTER_BUILD_PLAN.md` as operational entry).
2. `docs/plan/prompts/auditor_loop.md` — SUPERSEDED banner (file kept; superseded by `full_session_orchestrator.md`).
3. `docs/plan/05_RESEARCH_INDEX.md` — §C-bis added cataloging `/Downloads/final v3/` as orthogonal-not-superseding to v2.
4. `docs/CANONICAL_AUDIT_LOG.md` — top banner: status, role, read-with companions, latest-pass score.
5. `docs/CRITIQUE_LOG.md` — top banner with cross-ref overlap notes.
6. `docs/RESEARCH_DOSSIER_TIER_3_4.md` — top banner.
7. `docs/CLI_CONFIG_COMPILATION_RESEARCH.md` — top banner.
8. `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md` — DEFERRED-RESEARCH banner (Phase H, gated on Phase R).
9. `docs/OPENCLAW_FEATURE_SPEC.md` — DEFERRED-RESEARCH banner (Phase K, Pro-only).
10. `docs/MASTER_SESSION_PROMPT.md` — SUPERSEDED-HISTORICAL banner (note that user memory still refs it).
11. `docs/EPISTEMOS_FUSED_v3.md` — SUPERSEDED-HISTORICAL banner.
12. `docs/IMPLEMENTATION_BLUEPRINT.md` — SUPERSEDED-HISTORICAL banner.

### New files created

1. `docs/_INDEX.md` — comprehensive classification of every docs/ file with rationales (CANONICAL / DEFERRED-RESEARCH / SUPERSEDED-HISTORICAL / DELETE-CANDIDATE / pending audit). 13 sections.
2. `docs/_consolidated/` — entire tier tree built; **~93 files** copied from canonical/research/deferred/design tiers; **3.5 MB total**. Originals untouched.
3. `docs/_consolidated/README.md` — entry point + tier index + read order.
4. `docs/_consolidated/10_living_audits/FUSED_AUDIT_VIEW.md` — Blocker-centric merged view: §1 RESOLVED + §2 STILL OPEN priority queue + §3 operational notes (incl. **Note E** V1_DECISION perf budget + **Note F** perf-plan hard constraints) + §4 next-3-commits.
5. `docs/_consolidated/50_research_corpus/00_FUSED_RESEARCH_DIGEST.md` — 5-corpus synthesis: §1 chronology + §2 unique contributions + §3 convergent claims + §4 divergent rulings + §5 NOT-yet-canonical residuals + **§5.5 supplementary corpus drops (workspace/opt/ambient)** + §7 [UNVERIFIED] markers.
6. `docs/_consolidated/COWORK_MASTER_PROMPT.md` — **this file**.

### Workspace / opt / ambient sync (added 2026-04-27)

12 additional files copied from `~/Downloads/{workspace, opt, ambient}/` after deeper research review:

- **`00_canonical_authority/ambient_V1_DECISION.md`** — **the V1 architectural verdict** (single most decisive scoping doc in the entire corpus). Defines V1 = sandboxed App Store with Contextual Shadows + Halo as the *only* differentiator; Pro/direct ships later. 6-week roadmap. Performance budget table. Stack locked (Model2Vec + usearch + tantivy + RRF). 6-state Halo FSM. Apple Design Award angle.
- **`20_canonical_research/perf_DETERMINISTIC_PERFORMANCE_PLAN.md`** — 6-sprint × 12-week perf program (Sprint 0 signposts+GRDB+LTO → 5 PGO+arenas+mmap). 5 hard constraints. Stabilization paths.
- **`40_canonical_prompts/perf_CLAUDE_MD_ADDENDUM.md`** + **`perf_CONTEXT_ESSENTIALS_APPEND.txt`** + **`perf_SPRINT0_KICKOFF.md`** — operational appends + sprint-kickoff prompt template.
- **`70_design_implementation/`** (8 new docs):
  - `workspace_epistemos_code_verdict.md` — Code Editor architectural lock (Swift+TextKit2 + SwiftTreeSitter + Rust background brain + SourceKit-LSP + Metal viz only)
  - `workspace_gpt_workspace_architecture.md` + `workspace_gpt_workspace_synthesis.md` — dual-editor workspace + universal artifact envelope
  - `perf_invalidation_strategy.md` — "invalidation > transport" critique; reaffirms BoltFFI 1000× as `[UNVERIFIED]`
  - `perf_editor_120fps_v1/v2/v3.md` — three converging dossiers on 120fps editor (NSTextStorage delegate + background TreeSitter actor + Metal MSDF + minimap CALayer + CADisplayLink keep-alive)
  - `perf_ffi_flatbuffers_research.md` — theoretical zero-copy FFI + static SwiftUI routing + Markov prefetching
  - `ambient_swift_rust_metal_blueprint.md` — hybrid architecture (Swift UI+Metal / Rust core / UniFFI control / C-shim data plane / optional XPC) + 7 milestones + 15-line code review checklist
  - `ambient_contextual_shadows_blueprint.txt` — Halo + popover blueprint (NSTextView caret tracking + nested editor in popover + Mirror Speculative Decoding NPU+GPU)

Both fusion docs reflect these additions: `FUSED_AUDIT_VIEW.md §3` Notes E + F; `FUSED_RESEARCH_DIGEST.md §5.5`. **Originals at `~/Downloads/{workspace, opt, ambient}/` untouched.**

### Reads done by previous session (in full)

- All of `docs/plan/` (00–05 + README + 6 prompts)
- `CLAUDE.md`
- `docs/architecture/PLAN_V2.md` (1631 lines)
- `docs/MASTER_BUILD_PLAN.md`
- `docs/V1_5_IMPLEMENTATION_TRACKER.md`
- `docs/MULTI_SESSION_PROTOCOL.md`
- `docs/STRUCTURING_AUDIT.md`
- `docs/PROMPT_AS_DATA_SPEC.md`
- `docs/RESOURCE_INVENTORY.md`
- `docs/RESOURCE_RUNTIME_RESEARCH.md`
- `docs/CLI_CONFIG_COMPILATION_RESEARCH.md` (1161 lines, paginated)
- `docs/claude-code-codex-parity-options.md`
- `docs/capability-tunnels.md`
- `docs/mcp-url-servers.md`
- `docs/CANONICAL_AUDIT_LOG.md` (836 lines, paginated)
- `docs/CRITIQUE_LOG.md` (1715 lines, paginated)
- `docs/plan/03_EXECUTION_MAP.md` (1524 lines, paginated)
- `docs/RESEARCH_DOSSIER_TIER_3_4.md` (2098 lines, paginated)
- `/Downloads/final/EPISTEMOS_HERMES_MANIFESTO.md`
- 4 Explore-agent digests of all 4 research corpora

### Reads NOT done (anything not listed above is unread by previous session)

The previous session relied on Explore-agent digests (not full reads) for everything else. Your job in Mode A includes reading the un-read originals before classifying them.

---

## §4 — What's pending — the unprocessed surface

### docs/ root files NOT yet classified or bannered (~115 files)

Examples (verify each is unread before reading):

- `BACKEND_INTERFACE_SPEC_v1.md` — sounds canonical (PLAN_V2 §6 references "Backend Interface Spec v1"); read first to verify status.
- `DECISIONS.md` — likely a decision log; high-value if active.
- `WAVE_9_POLISH_AND_NATIVE.md`, `WAVE_13_MASTER_IMPLEMENTATION_PLAN.md` — wave-based plans referenced from `V1_5_TRACKER` and dossier; verify whether superseded or still active.
- `PHASE_I_IMPLEMENTATION_GUIDE.md` — Phase 1 implementation guide; could be canonical or superseded.
- `RESEARCH_TO_APP_TRACEABILITY.md` — traceability matrix; might be load-bearing.
- `CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md` — design spec.
- `CUSTOM_TEXT_ENGINE_RESEARCH.md` — research.
- `AUDIT_REPORT.md`, `audit-progress.md` — audit artifacts; maybe operational.
- `DEAD_CODE_CLEANUP_ANALYSIS.md` — operational audit.
- `APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` — recent release status; likely operational/canonical.
- `MASTER_HARDENING_AND_HARNESS_PLAN.md`, `MASTER_MODEL_STACK_PLAN.md` — older plan docs; banner SUPERSEDED if confirmed.
- `MASTER_SESSION_PROMPT_v2.md` — versioned predecessor of current MASTER_BUILD_PLAN; likely SUPERSEDED.
- `OMEGA_*.md` (5 files) — Omega system retired per `IMPLEMENTATION_PLAN_FROM_ADVICE.md`; likely SUPERSEDED.
- `CODEX_*.md` (8 files) — old session bootstrap prompts; likely SUPERSEDED.
- `KIMI_*.md` (3 files) — historical Kimi audit work; SUPERSEDED.
- `GOOSE_*.md` (3 files) — Goose comparative research; SUPERSEDED-HISTORICAL.
- `GRAPH_WAVES_*.md` (3 files) — landing-wave feature shipped per memory `project_landing_wave_redesign`; SUPERSEDED.
- `THEME_*.md` (5 files) — completed theme refactor; SUPERSEDED.
- `CODE_EDITOR_*.md` (4 files) — Phase S editor docs; verify whether resolved into PLAN_V2 §23.
- `ai_stack_*.md` (4 files) — provider matrix research; verify if absorbed into BUILD_MATRIX.
- `INSTANT_RECALL_ARCHITECTURE.md` — DEFERRED-RESEARCH (Phase R+).
- `CONTROL_PLANE_RESEARCH.md` — DEFERRED-RESEARCH (Phase D research).
- `UNIFIED_SUBSTRATE_RESEARCH.md` — **special case**: the "Five Laws (Add to CLAUDE.md — binding)" language suggests possibly-canonical content not yet absorbed; cross-check CLAUDE.md before banner.
- `HERMES_INTEGRATION_RESEARCH.md` — cited in CLAUDE.md operationally; banner DEFERRED-RESEARCH or CANONICAL-OPERATIONAL.
- `TOOL_TIER_AND_IMESSAGE_INTEGRATION.md` — Phase K design.
- `PROGRESS.md` — older predecessor of `AGENT_PROGRESS.md`; likely SUPERSEDED.
- `ROADMAP_NEXT_3.md` — superseded by `04_PHASES.md`.
- `REMAINING_WORK_INVENTORY.md` — superseded by `03_EXECUTION_MAP.md` + `V1_5_IMPLEMENTATION_TRACKER.md`.
- `PHASE_CHECKLIST.md`, `PHASE_S_AUDIT.md` — phase-specific docs; verify.
- `VERIFICATION_PROTOCOL.md` — pre-Phase-S ops; verify status.
- `HARDENING_VERIFICATION.md` — pre-Phase-S; verify.
- `RESEARCH_PROMPTS.md`, `RESEARCH_PROMPT_CLOUD_NATIVE_AGENT_BRIDGE.md`, `RESEARCH_PROMPT_CODE_EDITOR_AND_AI_FILE_OPS.md` — research prompts; classify.
- `audit-progress.md` — likely operational; banner CANONICAL-OPERATIONAL or SUPERSEDED.
- `codex-memory.md`, `codex-v2-release-audit.md`, `codex-verification-handoff.md` — Codex-related operational docs; verify status.
- `non_agent_full_app_pruning_audit_research_pack_2026-03-26.md` — historical research.
- `session-handoff-2026-03-07.md`, `SESSION_HANDOFF_2026-04-07.md`, `SESSION_REPORT_2026-04-06.md`, `SESSION_STATE_2026_03_25.md`, `SESSION_BOOTSTRAP_PROMPT.md` — session artifacts; SUPERSEDED-HISTORICAL or TRANSIENT-CANDIDATE.
- `NEXT_SESSION_PROMPT.md`, `KF_CONTINUATION_PROMPT.md`, `PARALLEL_SESSION_PROMPT.md`, `IMPLEMENTATION_PROMPTS.md`, `handoff-prompt.md`, `PERPLEXITY_DEEP_AUDIT_PROMPT.md`, `KIMI_AUDIT_PROMPT.md`, `OMEGA_DEEP_RESEARCH_PROMPT.md`, `OMEGA_CONTINUATION_PROMPT.md`, `AGENT_FUSION_RESEARCH_PROMPT.md`, `AGENT_INTEGRATION_SESSION_PLAN.md`, `CLAUDE_CODE_SESSION_PROMPT.md`, `CLAUDE_OMEGA_AUDIT_FIX_MANIFESTO_2026_03_25.md` — transient session prompts; TRANSIENT-CANDIDATE for deletion review.
- `FINAL_VERIFICATION_CHECKLIST.md` — one-off checklist; likely TRANSIENT.
- `BUILD_TEST_GREEN_BASELINE.md`, `PERF_BASELINE.md` — historical baselines; SUPERSEDED.
- `AUDIT_LOG.md` — possibly duplicate of `CANONICAL_AUDIT_LOG.md`; verify content.
- `AUDIT_REFLECTION_2026_04_23.md` — historical audit; SUPERSEDED.
- `ANTI_DRIFT_SYSTEM.md` — overlap with `docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md`; banner SUPERSEDED.
- `AGENT_DEEP_VERIFICATION_MANUAL.md` — replaced by WRV gate in `00_AUTHORITY_AND_ANTI_DRIFT.md §4.7`; SUPERSEDED.
- `BEST_OF_CLAW_AND_OPENCLAW.md` — research synthesis ingested into `OPENCLAW_FEATURE_SPEC.md`; SUPERSEDED.
- `CLAUDE_CANONICAL_STATE_HANDOFF_2026-04-23.md` — recent handoff; classify.
- `CLAUDE_UPGRADE_PLAN_SYNOPSIS.md` — older planning; SUPERSEDED.
- `LANDING_WAVE_SEARCH_PLAN.md` — feature shipped per memory; SUPERSEDED.
- `NANO-MASTER-TRAINING-GUIDE.md` — training research; DEFERRED.
- `POST_V1_OPPORTUNITY_MAP.md` — aspirational roadmap; SUPERSEDED by `04_PHASES.md`.
- `SKILL_IMPLEMENTATION_PLAN.md`, `SKILL_PORT_MASTER_REFERENCE.md` — feature design refs; classify.
- `TRAINING_GUIDE.md`, `TRAINING_TRACKS.md` — training material; classify.
- `EPISTEMOS_SPECIALTIES.md` — capabilities matrix; SUPERSEDED by `02_BUILD_MATRIX.md`.
- `FEATURE_SPEC_TOC_AND_FOLDING.md` — Phase S editor feature; classify.
- `FUSED_AGENT_ENGINEERING_REPORT.md` — research synthesis; SUPERSEDED.
- `GRAPH_SDF_LABEL_RESEARCH_PROMPT.md` — research prompt; classify.
- `GPU_RENDERER_SEAM.md` — perf research; SUPERSEDED (covered by W9.24 in EXECUTION_MAP).
- `V1_RELEASE_AUDIT.md`, `V1_SCOPE_BOUNDARY.md` — V1 shipped; SUPERSEDED.
- `VISION_BACKLOG.md` — aspirational; SUPERSEDED by `04_PHASES.md`.
- `epistemos-deep-analysis.md` — already in `_consolidated/70_design_implementation/`; verify copy fidelity.
- `future-work-audit.md` — aspirational; SUPERSEDED.

### Subdirectories not yet processed

| Subdir | Files | Action |
|---|---|---|
| `docs/architecture/` | 30 files (only `PLAN_V2.md` + `README.md` consolidated) | Read each to classify; many are PHASE_*_HANDOFF historical; most likely SUPERSEDED-HISTORICAL but some (`OVERSEER_AND_AGENT_HIERARCHY.md`, `COMPUTE_STEERING_SPEC_v1.md`, `ADAPTATION_SUBSYSTEM_SPEC_v1.md`, `BACKEND_INTERFACE_SPEC_v1.md` if at root) may be CANONICAL-RESEARCH. |
| `docs/plans/` | 33 files | Likely all SUPERSEDED-HISTORICAL (older plan tree predecessor of `docs/plan/`). Spot-check 3–5; if confirmed pattern, banner all 33 SUPERSEDED-HISTORICAL without reading each. |
| `docs/audits/` | 54 files (mostly timestamped `verify-*.md` snapshots) | CANONICAL-OPERATIONAL — keep all; do NOT copy to `_consolidated/` (operational logs, not navigation material). Optionally banner the 3–5 most recent ones to flag still-relevant. |
| `docs/handoffs/` | 20 files (session handoffs) | CANONICAL-HISTORICAL — keep for state recovery. Do NOT copy. |
| `docs/research/` | 11 Hermes-specific research files | CANONICAL-RESEARCH (Phase D + K reference). Copy all to `_consolidated/20_canonical_research/hermes_research/` (new subdir). |
| `docs/sprint-sessions/` | 8 files | Mostly SUPERSEDED-HISTORICAL (old sprint plans pre-MASTER_BUILD_PLAN); verify dates; banner accordingly. |
| `docs/legal/` | 2 files | CANONICAL-OPERATIONAL (license + privacy). Don't touch; don't copy. |
| `docs/release/` | 1 file | CANONICAL-OPERATIONAL (MAS app review). Don't touch; don't copy. |
| `docs/agent-system/` | unknown — check `ls`. CLAUDE.md cites `docs/agent-system/AGENT_ARCHITECTURE.md` as canonical. | Read each; classify. AGENT_ARCHITECTURE.md is CANONICAL-RESEARCH per CLAUDE.md citation. |
| `docs/sprint-sessions/sprint-omega-1-foundation.md` | cited in CLAUDE.md startup protocol | Verify currency; if active, banner CANONICAL-OPERATIONAL. |
| `docs/google_research/` (if exists) | unknown | Read; banner; archive. |
| `docs/windows_research/` (if exists) | unknown | Same. |
| `docs/bug-fixes/` | unknown | CANONICAL-HISTORICAL or SUPERSEDED. |
| `docs/channels/` | unknown | Likely Phase K research; DEFERRED-RESEARCH. |
| `docs/superpowers/` | 2 files (per previous orphan inventory) | DEFERRED-RESEARCH (W9.24 + graph embedding spec). |
| `docs/knowledge-fusion/` | 3 files | SUPERSEDED (KF system retired per `IMPLEMENTATION_PLAN_FROM_ADVICE.md`). |

### `/Downloads/{workspace, opt, ambient}/` files not yet read in full (8 files; need chunked-read workflow)

The 2026-04-27 sync incorporated 15 dense research files from this cluster. 7 had full reads done; the following 8 are oversized for one Read call and need `Bash split` chunked-read in Mode A:

| Path | Size | Likely content |
|---|---|---|
| `/Users/jojo/Downloads/workspace/claude work.md` | 29K tokens | Claude's architecture deep-dive (companion to gpt work.md) |
| `/Users/jojo/Downloads/workspace/raw thoughts.md` | 67K tokens | **User's own brainstorm — possibly the most personal-value file in the entire corpus** |
| `/Users/jojo/Downloads/opt/Epistemos Performance Optimization Roadmap.txt` | 26K tokens | Likely deep-dive perf research; companion to PERF_PLAN |
| `/Users/jojo/Downloads/opt/compass_artifact_wf-97f869bf-...md` | 26K tokens | Compass artifact (research aggregator format) |
| `/Users/jojo/Downloads/opt.txt` | 38K tokens | Root-level perf research dump |
| `/Users/jojo/Downloads/opt2.txt` | 33K tokens | Root-level perf research dump |
| `/Users/jojo/Downloads/opt3.txt` | 21K tokens | Root-level perf research dump |
| `/Users/jojo/Downloads/ambient/claude ambient.md` | 27K tokens | Claude's analysis of the ambient/Halo feature |

For each: use the `Bash split` workflow demonstrated in §7 Step 1 (split into 500-1000-line chunks via `/tmp/eps_chunks/`, then Read each chunk, then synthesize). Once read, copy with `<source>_<descriptive>` prefix into the appropriate tier in `_consolidated/`. Update `FUSED_RESEARCH_DIGEST.md §5.5` with new findings if anything changes the convergent/divergent analysis.

### `_consolidated/` gaps to fill (Mode B priority)

The 3 fusion docs were authored from in-context reads. Verify against originals:

1. `_consolidated/10_living_audits/FUSED_AUDIT_VIEW.md` — every Blocker listed should match `CANONICAL_AUDIT_LOG.md` Pass #1/#2/#3 + `CRITIQUE_LOG.md` Pass #1–#14. Spot-check 3 random Blockers; verify file:line citations are accurate.
2. `_consolidated/50_research_corpus/00_FUSED_RESEARCH_DIGEST.md` — §2 "Unique contributions" + §3 "Convergent claims" + §4 "Divergent rulings" + §5 "NOT-yet-canonical residuals". Each cited corpus passage should be findable. Spot-check 5 citations.
3. `_consolidated/README.md` — tier counts (76 files, 3.1 MB) should match current state; re-run `find _consolidated/<tier> -type f | wc -l` per tier.

---

## §5 — Read order (the dense, nuanced, load-bearing docs)

If a fresh session, read in this exact order before doing anything else. Each is in `_consolidated/` so paths are short:

```
1. docs/_consolidated/00_canonical_authority/CLAUDE.md            ← code standards (top of authority)
2. docs/_consolidated/00_canonical_authority/PLAN_V2.md            ← architectural authority (1631 lines)
3. docs/_consolidated/00_canonical_authority/MASTER_BUILD_PLAN.md  ← operational entry point + queue
4. docs/_consolidated/00_canonical_authority/00_AUTHORITY_AND_ANTI_DRIFT.md ← contract
5. docs/_consolidated/00_canonical_authority/01_DOCTRINE.md        ← 14 non-negotiables
6. docs/_consolidated/00_canonical_authority/02_BUILD_MATRIX.md    ← Pro/MAS gating
7. docs/_consolidated/00_canonical_authority/03_EXECUTION_MAP.md   ← per-item depth (36 items)
8. docs/_consolidated/00_canonical_authority/04_PHASES.md          ← phase ordering
9. docs/_consolidated/00_canonical_authority/05_RESEARCH_INDEX.md  ← reverse-index from items to corpus
10. docs/_consolidated/00_canonical_authority/_INDEX.md            ← every doc classified
11. docs/_consolidated/10_living_audits/FUSED_AUDIT_VIEW.md        ← single-pane Blocker view
12. docs/_consolidated/50_research_corpus/00_FUSED_RESEARCH_DIGEST.md ← cross-corpus synthesis
13. docs/_consolidated/README.md                                   ← tier index + read order
```

---

## §6 — PATH CATALOG — every dense/nuanced/best doc with absolute path

### Tier 0 — Canonical authority chain (read-first; the spine)

```
/Users/jojo/Downloads/Epistemos/CLAUDE.md
/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md
/Users/jojo/Downloads/Epistemos/docs/MASTER_BUILD_PLAN.md
/Users/jojo/Downloads/Epistemos/docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md
/Users/jojo/Downloads/Epistemos/docs/plan/01_DOCTRINE.md
/Users/jojo/Downloads/Epistemos/docs/plan/02_BUILD_MATRIX.md
/Users/jojo/Downloads/Epistemos/docs/plan/03_EXECUTION_MAP.md
/Users/jojo/Downloads/Epistemos/docs/plan/04_PHASES.md
/Users/jojo/Downloads/Epistemos/docs/plan/05_RESEARCH_INDEX.md
/Users/jojo/Downloads/Epistemos/docs/plan/README.md
/Users/jojo/Downloads/Epistemos/docs/_INDEX.md
```

### Tier 1 — Living audits + tracker

```
/Users/jojo/Downloads/Epistemos/docs/CANONICAL_AUDIT_LOG.md          (3 deep passes, 836 lines)
/Users/jojo/Downloads/Epistemos/docs/CRITIQUE_LOG.md                  (14 passes, 1715 lines)
/Users/jojo/Downloads/Epistemos/docs/V1_5_IMPLEMENTATION_TRACKER.md   (live status board)
/Users/jojo/Downloads/Epistemos/docs/AGENT_PROGRESS.md                 (session log)
/Users/jojo/Downloads/Epistemos/docs/APP_ISSUES_AUTO_FIX.md            (runtime issues)
/Users/jojo/Downloads/Epistemos/docs/KNOWN_ISSUES_REGISTER.md          (19-bug register)
```

### Tier 2 — Canonical research synthesis

```
/Users/jojo/Downloads/Epistemos/docs/RESEARCH_DOSSIER_TIER_3_4.md     (2098 lines; per-item paste-ready prompts + Bucket A/B/C/D)
/Users/jojo/Downloads/Epistemos/docs/STRUCTURING_AUDIT.md              (S1-S16 surfaces, G1-G9 gap-fixes)
/Users/jojo/Downloads/Epistemos/docs/RESOURCE_INVENTORY.md             (Phase R live-resource accounting)
/Users/jojo/Downloads/Epistemos/docs/RESOURCE_RUNTIME_RESEARCH.md      (Phase R substrate research)
/Users/jojo/Downloads/Epistemos/docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md (4-model council synthesis)
/Users/jojo/Downloads/Epistemos/docs/PROMPT_AS_DATA_SPEC.md            (N1 spec — SHIPPED)
/Users/jojo/Downloads/Epistemos/docs/MULTI_SESSION_PROTOCOL.md         (cross-session coordination)
```

### Tier 3 — CLI integration (load when implementing CLI work)

```
/Users/jojo/Downloads/Epistemos/docs/CLI_CONFIG_COMPILATION_RESEARCH.md  (1161 lines; authoritative CLI compiler ref)
/Users/jojo/Downloads/Epistemos/docs/claude-code-codex-parity-options.md (runtime path comparison)
/Users/jojo/Downloads/Epistemos/docs/capability-tunnels.md               (4-tunnel strategy)
/Users/jojo/Downloads/Epistemos/docs/mcp-url-servers.md                  (Tunnel B.1 deep-dive)
```

### Tier 4 — Original research corpus (the four /Downloads/ folders)

#### `/Users/jojo/Downloads/Advice/` (7 files — earliest 4-model architectural advice)

```
/Users/jojo/Downloads/Advice/Claude paper.pdf        (273 KB; runtime-path doctrine + licensing constraints)
/Users/jojo/Downloads/Advice/Gemini paper.pdf        (253 KB; Gemini API + ADK + MCP universal tool surface)
/Users/jojo/Downloads/Advice/Gpt paper.md            (23 KB; provider runtimes as plug-ins; Codex app-server)
/Users/jojo/Downloads/Advice/Perplexity paper.md     (32 KB; DevContainer + Claude Agent SDK + Qwen3-4B + json-render)
/Users/jojo/Downloads/Advice/claude advice.md        (62 KB; mirror of PLAN_V2 doctrine)
/Users/jojo/Downloads/Advice/claudy research.md      (63 KB; CLI config templates + DevContainer lifecycle)
/Users/jojo/Downloads/Advice/perplexity 2.md         (32 KB; Qwen3-4B agentic tool-calling)
```

#### `/Users/jojo/Downloads/final/` (14 files including 2 nested folders)

```
/Users/jojo/Downloads/final/Building Epistemos x Hermes Hackathon.txt              (45 KB; hackathon technical dossier)
/Users/jojo/Downloads/final/EPISTEMOS_HERMES_MANIFESTO.md                          (37 KB; THE STRATEGIC VISION — read this)
/Users/jojo/Downloads/final/Episdemo Master Architecture Brief + Claude Brainstorm Prompt.md (32 KB; master architecture prompt)
/Users/jojo/Downloads/final/compass_artifact_wf-2d55c11c-...md                     (63 KB; CLI config templates Apr 2026)
/Users/jojo/Downloads/final/compass_artifact_wf-2de4a4f7-...md                     (57 KB; Hackathon Hermes architectural dossier)
/Users/jojo/Downloads/final/deep-research-report (2).md                            (33 KB; Archon consensus ruling)

/Users/jojo/Downloads/final/last round of thinking/AI App Architecture Consensus Building.txt           (43 KB; 4-architect consensus)
/Users/jojo/Downloads/final/last round of thinking/Epistemos App_ Privacy, Speed, SDK Integration.txt    (47 KB; Pro/MAS tradeoffs)
/Users/jojo/Downloads/final/last round of thinking/Epistemos Architecture Consensus & Disruption.txt    (25 KB; consensus + disruption)
/Users/jojo/Downloads/final/last round of thinking/compass_artifact_wf-1d5bf47c-...md                   (67 KB; final round-of-thinking)

/Users/jojo/Downloads/final/executive sumaries/compass_artifact_wf-929d1097-...md   (69 KB; LARGEST executive summary; fused doctrine)
/Users/jojo/Downloads/final/executive sumaries/deeper research from gpt.md          (33 KB; GPT-authored deeper synthesis)
/Users/jojo/Downloads/final/executive sumaries/epistemos-rival-doctrine.md          (22 KB; THE DEFEATED OPINION; historical record)
/Users/jojo/Downloads/final/executive sumaries/gpt deep.md                          (35 KB; GPT-authored deep synthesis)
```

#### `/Users/jojo/Downloads/final v2/` (6 files — most recent runtime/inference research; doctrine crystallized here)

```
/Users/jojo/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt           (40 KB; provenance plane + 7-verb MCP + BoltFFI [UNVERIFIED])
/Users/jojo/Downloads/final v2/Epistemos Hackathon_ Deep Research Plan.txt              (42 KB; workspace OS paradigm + A2UI v0.9 + SleepGate)
/Users/jojo/Downloads/final v2/compass_artifact_wf-c2d78e2f-...md                       (63 KB; MASTER DOCTRINE & IMPLEMENTATION COOKBOOK — read this)
/Users/jojo/Downloads/final v2/deep-research-report (4) copy 2.md                       (22 KB; deep audit + critique of "parity over-indexing")
/Users/jojo/Downloads/final v2/deep-research-report (4) copy.md                         (14 KB; SSM/hybrid models)
/Users/jojo/Downloads/final v2/deep-research-report (4).md                              (13 KB; KIVI vs TurboQuant + UniFFI bump specifics)
```

#### `/Users/jojo/Downloads/final v3/` (1 file — orthogonal LLM prompt-engineering research)

```
/Users/jojo/Downloads/final v3/deep-research-report (4).md   (13 KB; JSON-schema prompting + Anthropic cache mechanics + Tool Search)
```

### Tier 4-bis — `/Downloads/{workspace, opt, ambient}/` cluster (synced 2026-04-27 — Phase H Halo + 120fps editor + perf program + V1 verdict)

These are 15 dense research files in a cluster discovered after the initial v1/v2/v3 corpus pass. All have been **copied** to `_consolidated/` with disambiguating prefixes (`workspace_*`, `perf_*`, `ambient_*`); **originals untouched**. 7 of the 15 also have full reads done; 8 are oversized and pending chunked-read in Mode A.

#### `/Users/jojo/Downloads/workspace/` (5 files — code editor architectural lock + dual-editor workspace)

```
/Users/jojo/Downloads/workspace/epistemos_code_verdict.md           (10 KB; ★ Code Editor architectural lock — Swift+TextKit2 surface + SwiftTreeSitter live + Rust background brain + SourceKit-LSP + Metal viz only; Cognitive Execution Surface with Provenance, not Xcode clone) → 70/workspace_epistemos_code_verdict.md
/Users/jojo/Downloads/workspace/gpt work.md                          (35 KB; dual-editor workspace — TextKit 2 for Prose + Tiptap-in-WKWebView for Document + Raw Thoughts as run artifacts; ProseMirror JSON canonical, Markdown shadow lossy) → 70/workspace_gpt_workspace_architecture.md
/Users/jojo/Downloads/workspace/gpt work 2.md                        (37 KB; universal artifact envelope synthesis + FTS5 over normalized search_text + provider-visible reasoning persistence) → 70/workspace_gpt_workspace_synthesis.md
/Users/jojo/Downloads/workspace/claude work.md                       (29K tokens — UNREAD; needs chunked-read in Mode A)
/Users/jojo/Downloads/workspace/raw thoughts.md                      (67K tokens — UNREAD; user's own brainstorm; possibly most personal-value file)
```

#### `/Users/jojo/Downloads/opt/` (8 files + 6 root files — deterministic perf program + 120fps editor)

```
/Users/jojo/Downloads/opt/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md       (★ 6-sprint × 12-week perf program — Sprint 0 signposts+GRDB+LTO → 5 PGO+arenas+mmap; 5 hard constraints; stabilization paths) → 20/perf_DETERMINISTIC_PERFORMANCE_PLAN.md
/Users/jojo/Downloads/opt/CLAUDE_MD_ADDENDUM.md                       (5-line block to append to CLAUDE.md naming the perf plan + 5 constraints + 6-sprint sequence) → 40/perf_CLAUDE_MD_ADDENDUM.md
/Users/jojo/Downloads/opt/CONTEXT_ESSENTIALS_APPEND.txt                (post-compaction hook block: 5 perf constraints + scope boundaries) → 40/perf_CONTEXT_ESSENTIALS_APPEND.txt
/Users/jojo/Downloads/opt/CLAUDE_CODE_SPRINT0_KICKOFF.md               (paste-prompt for Sprint 0; same template works for all 6 sprints with header swap) → 40/perf_SPRINT0_KICKOFF.md
/Users/jojo/Downloads/opt/claude opt 2.md                              ("invalidation > transport" — 78×–167× incremental outline-refresh gain; mutation envelopes + query fingerprints; reaffirms BoltFFI 1000× as [UNVERIFIED]) → 70/perf_invalidation_strategy.md
/Users/jojo/Downloads/opt/deep-research-report (2).md                  (FlatBuffers + Markov-prefetch + Tree-sitter atomic-pointer cache + mmap SPSC ring; theoretical zero-copy FFI model — distinct from /final/ same-named doc) → 70/perf_ffi_flatbuffers_research.md
/Users/jojo/Downloads/opt4.md                                          (120fps editor optimization perspective 1 — TextKit 2 + background TreeSitter actor + Metal MSDF glyph atlas + minimap CALayer + CADisplayLink keep-alive) → 70/perf_editor_120fps_v1.md
/Users/jojo/Downloads/opt5.md                                          (120fps editor perspective 2 — same architecture, different framing; ProMotion 8.33ms budget; SumTree/Rope data structure analysis) → 70/perf_editor_120fps_v2.md
/Users/jojo/Downloads/opt6.md                                          (120fps editor perspective 3 — 5-phase implementation roadmap; CodeEditSourceEditor 0.13.1+ upgrade with patches; tree-sitter actor isolation) → 70/perf_editor_120fps_v3.md
/Users/jojo/Downloads/opt/Epistemos Performance Optimization Roadmap.txt (26K tokens — UNREAD; chunked-read pending)
/Users/jojo/Downloads/opt/compass_artifact_wf-97f869bf-f267-4d6b-aafc-174916c29d0d_text_markdown.md  (26K tokens — UNREAD; chunked-read pending)
/Users/jojo/Downloads/opt.txt                                          (38K tokens — UNREAD; chunked-read pending)
/Users/jojo/Downloads/opt2.txt                                         (33K tokens — UNREAD; chunked-read pending)
/Users/jojo/Downloads/opt3.txt                                         (21K tokens — UNREAD; chunked-read pending)
```

#### `/Users/jojo/Downloads/ambient/` (4 files — V1 scope decision + Halo blueprint)

```
/Users/jojo/Downloads/ambient/EPISTEMOS_V1_DECISION.md                 (★★★ THE V1 ARCHITECTURAL VERDICT — single most decisive scoping doc in the entire research corpus; V1 = MAS sandboxed Halo+Shadows ONLY differentiator, Pro later; 6-week roadmap; perf budget table; stack lock; 6-state Halo FSM; Apple Design Award angle) → 00_canonical_authority/ambient_V1_DECISION.md
/Users/jojo/Downloads/ambient/deep-research-report (2).md              (★ Swift+Rust+Metal hybrid blueprint — Swift owns UI+Metal, Rust owns retrieval+parsing in-process cdylib, UniFFI = control plane, C-shim for zero-copy slabs + MTLBuffer wrapping, optional XPC for risky helpers; 7 milestones + 15-line code review checklist) → 70/ambient_swift_rust_metal_blueprint.md
/Users/jojo/Downloads/ambient/gemini ambient.txt                       (Halo + Contextual Shadows implementation blueprint — NSTextView caret tracking + popover with note/chat toggle + nested editor for in-place edits + Mirror Speculative Decoding NPU+GPU + ARM NEON usearch) → 70/ambient_contextual_shadows_blueprint.txt
/Users/jojo/Downloads/ambient/claude ambient.md                        (27K tokens — UNREAD; chunked-read pending; Claude's analysis of ambient feature)
```

### Tier 5 — Deferred research (research for unimplemented features; KEEP)

```
/Users/jojo/Downloads/Epistemos/docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md   (Phase H, downstream of Phase R)
/Users/jojo/Downloads/Epistemos/docs/INSTANT_RECALL_ARCHITECTURE.md       (Phase R+ instant recall)
/Users/jojo/Downloads/Epistemos/docs/OPENCLAW_FEATURE_SPEC.md             (Phase K, Pro-only)
/Users/jojo/Downloads/Epistemos/docs/CONTROL_PLANE_RESEARCH.md            (Phase D research)
/Users/jojo/Downloads/Epistemos/docs/UNIFIED_SUBSTRATE_RESEARCH.md        (substrate Phase D; "Five Laws — binding" needs cross-check)
/Users/jojo/Downloads/Epistemos/docs/HERMES_INTEGRATION_RESEARCH.md       (Phase D / K Hermes provider; cited in CLAUDE.md)
/Users/jojo/Downloads/Epistemos/docs/TOOL_TIER_AND_IMESSAGE_INTEGRATION.md (Phase K design)
/Users/jojo/Downloads/Epistemos/docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md (post-V1.5 cognitive layer)
/Users/jojo/Downloads/Epistemos/docs/architecture/EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN.md (cross-cutting research synthesis)
```

### Tier 6 — Best comprehensive design + implementation docs

```
/Users/jojo/Downloads/final/EPISTEMOS_HERMES_MANIFESTO.md                          (vision + research brief + 9-day vector)
/Users/jojo/Downloads/final/Episdemo Master Architecture Brief + Claude Brainstorm Prompt.md  (master architecture)
/Users/jojo/Downloads/Epistemos/docs/epistemos-deep-analysis.md                    (codebase analysis; cited in CLAUDE.md "Detailed Docs")
/Users/jojo/Downloads/Epistemos/docs/architecture/COMPUTE_STEERING_SPEC_v1.md      (Compute Steering Spec v1; PLAN_V2 §8 source)
/Users/jojo/Downloads/Epistemos/docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md  (Adaptation Subsystem Spec v1; PLAN_V2 §9 source)
/Users/jojo/Downloads/Epistemos/docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md  (Overseer + Agent Hierarchy; PLAN_V2 §10-11 source)
```

### Tier 7 — Operational logs (don't copy; reference only)

```
/Users/jojo/Downloads/Epistemos/docs/audits/                  (54 files; verify-*.md timestamps; needed for state recovery)
/Users/jojo/Downloads/Epistemos/docs/handoffs/                (20 files; session handoffs; historical reference)
/Users/jojo/Downloads/Epistemos/docs/sprint-sessions/         (8 files; old sprint plans; classify per-file)
/Users/jojo/Downloads/Epistemos/docs/research/                (11 Hermes-specific research files; CANONICAL-RESEARCH)
/Users/jojo/Downloads/Epistemos/docs/legal/                   (license + privacy)
/Users/jojo/Downloads/Epistemos/docs/release/                 (MAS app review notes)
```

### Tier 8 — Already-banner candidates (need reading before banner-then-copy)

```
/Users/jojo/Downloads/Epistemos/docs/BACKEND_INTERFACE_SPEC_v1.md          (PLAN_V2 §6 references; likely CANONICAL-RESEARCH)
/Users/jojo/Downloads/Epistemos/docs/DECISIONS.md                          (decision log; verify currency)
/Users/jojo/Downloads/Epistemos/docs/WAVE_9_POLISH_AND_NATIVE.md           (wave plan; likely SUPERSEDED by 03_EXECUTION_MAP)
/Users/jojo/Downloads/Epistemos/docs/WAVE_13_MASTER_IMPLEMENTATION_PLAN.md (wave plan; likely SUPERSEDED)
/Users/jojo/Downloads/Epistemos/docs/PHASE_I_IMPLEMENTATION_GUIDE.md       (Phase 1 guide; verify status)
/Users/jojo/Downloads/Epistemos/docs/RESEARCH_TO_APP_TRACEABILITY.md       (traceability matrix)
/Users/jojo/Downloads/Epistemos/docs/CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md  (design spec)
/Users/jojo/Downloads/Epistemos/docs/CUSTOM_TEXT_ENGINE_RESEARCH.md        (research)
/Users/jojo/Downloads/Epistemos/docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md (recent release status)
/Users/jojo/Downloads/Epistemos/docs/SKILL_IMPLEMENTATION_PLAN.md          (Skill design; classify)
/Users/jojo/Downloads/Epistemos/docs/SKILL_PORT_MASTER_REFERENCE.md        (Skill porting; classify)
/Users/jojo/Downloads/Epistemos/docs/agent-system/AGENT_ARCHITECTURE.md    (CLAUDE.md cites; CANONICAL-RESEARCH)
```

---

## §7 — Mode A workflow (continue consolidation)

For each unprocessed file in `docs/` root or unprocessed subdir:

### Step 1: Read in full

If file < 500 lines: `Read` directly.
If file >= 500 lines: paginate via `Bash split` to chunks. Example for `docs/SOME_BIG_DOC.md`:

```bash
mkdir -p /tmp/eps_chunks
split -l 500 -d -a 2 /Users/jojo/Downloads/Epistemos/docs/SOME_BIG_DOC.md /tmp/eps_chunks/somebig_
ls /tmp/eps_chunks/somebig_*
# Then Read each chunk
```

### Step 2: Classify

Pick one status from this closed set:
- **`CANONICAL`**: actively cited from canonical authority chain (Tier 0); current execution depends on it.
- **`CANONICAL-RESEARCH`**: synthesis doc cited from plan tree; load when item touched.
- **`CANONICAL-OPERATIONAL`**: live operational log (audit, handoff, status).
- **`DEFERRED-RESEARCH`**: research for unimplemented feature; reactivate when phase X starts.
- **`SUPERSEDED-HISTORICAL`**: explicitly superseded by named newer doc; kept for reference.
- **`TRANSIENT-CANDIDATE`**: looks transient (old prompt, dated handoff); SURFACE TO USER before any action.

### Step 3: Banner the original

Add a banner at the top of the original (insert AFTER first heading line, BEFORE the existing first paragraph). Format:

```markdown
> **Index status**: <STATUS> — <one-sentence reason>.
> **Superseded by** (if SUPERSEDED): [path with link].
> **Phase / unlock condition** (if DEFERRED): <e.g., Phase H gated on Phase R closure>.
> **Linked from**: <canonical doc that cites it; if any>.
> Classified in [`docs/_INDEX.md §<N>`](_INDEX.md).
```

Use `Read` first (just first 30 lines is enough to register the file path with Edit), then `Edit` to insert the banner.

### Step 4: Copy to `_consolidated/` (only if CANONICAL / CANONICAL-RESEARCH / CANONICAL-OPERATIONAL / DEFERRED-RESEARCH)

```bash
# Examples:
cp /Users/jojo/Downloads/Epistemos/docs/<FILE>.md /Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/  # Tier 0
cp /Users/jojo/Downloads/Epistemos/docs/<FILE>.md /Users/jojo/Downloads/Epistemos/docs/_consolidated/20_canonical_research/   # Tier 2
cp /Users/jojo/Downloads/Epistemos/docs/<FILE>.md /Users/jojo/Downloads/Epistemos/docs/_consolidated/60_deferred_research/    # Tier 5
# etc.
```

For SUPERSEDED-HISTORICAL: leave original in place; do NOT copy. Banner is enough.
For TRANSIENT-CANDIDATE: surface to user; do nothing else until they confirm.

### Step 5: Update `_INDEX.md` AND its copy in `_consolidated/`

Add a row in the appropriate section of `docs/_INDEX.md` for this file. Then re-run:

```bash
cp /Users/jojo/Downloads/Epistemos/docs/_INDEX.md /Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/_INDEX.md
```

### Step 6: Repeat

Process docs in the priority order specified in §4 above (recent + dense + load-bearing first). Cap each session at ~20 files to avoid context exhaustion.

---

## §8 — Mode B workflow (verify + fill gaps in fusion docs)

The previous session created 3 fusion docs from in-context reads. Verify and fill gaps.

### Step 1: Verify file copies (no corruption)

```bash
for f in $(find /Users/jojo/Downloads/Epistemos/docs/_consolidated -type f -name "*.md"); do
  rel=${f#/Users/jojo/Downloads/Epistemos/docs/_consolidated/}
  base=$(basename "$f")
  # Find corresponding original
  orig=$(find /Users/jojo/Downloads/Epistemos/docs /Users/jojo/Downloads /Users/jojo/Downloads/Epistemos -maxdepth 4 -name "$base" -not -path "*/_consolidated/*" -type f 2>/dev/null | head -1)
  if [ -n "$orig" ] && [ -f "$orig" ]; then
    if ! cmp -s "$f" "$orig"; then
      echo "DIFF: $rel vs $orig"
    fi
  fi
done
```

Expected output: only the 3 NEW fusion docs and `_INDEX.md` (since copy might be older than source) should diff. If any other file diffs, investigate — possible corruption in copy.

### Step 2: Verify FUSED_AUDIT_VIEW.md

For each Blocker listed in `_consolidated/10_living_audits/FUSED_AUDIT_VIEW.md §2`, find the corresponding entry in `CANONICAL_AUDIT_LOG.md`:

```bash
# Example: verify W9.21 Blocker citation
grep -n "W9.21" /Users/jojo/Downloads/Epistemos/docs/CANONICAL_AUDIT_LOG.md
grep -n "W9.21" /Users/jojo/Downloads/Epistemos/docs/CRITIQUE_LOG.md
```

If any Blocker in FUSED is missing from CANONICAL or CRITIQUE: investigate (could be the fusion fabricated). If any Blocker in CANONICAL is missing from FUSED: add it.

Spot-check 3 random Blockers. If 3/3 verify, confidence high.

### Step 3: Verify FUSED_RESEARCH_DIGEST.md

For each citation in `_consolidated/50_research_corpus/00_FUSED_RESEARCH_DIGEST.md`, find the source:

```bash
# Example: "BoltFFI 1000× speedup [UNVERIFIED]" cited from final v2/App Moats
grep -n "BoltFFI" "/Users/jojo/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt"
```

Spot-check 5 citations. If 5/5 verify, confidence high.

### Step 4: Fill gaps

Common gap patterns:
- **Missing Blocker** in FUSED_AUDIT_VIEW that exists in CANONICAL — add a row.
- **Citation drift** in FUSED_RESEARCH_DIGEST — update citation file path or quoted passage.
- **Stale "last sync" date** — update header with current date.
- **`README.md` tier counts wrong** — re-run `find _consolidated/<tier> -type f | wc -l` and update.

For each gap fix: edit the fusion doc, NOT the source. Sources are authoritative.

### Step 5: Append "verification log" section

At the bottom of each fusion doc, add:

```markdown
## §N+1 — Verification log

- 2026-04-27: Initial fusion (previous session).
- <DATE>: Mode B verification by <agent name>. Spot-check N/N Blockers verified, M citation matches confirmed. Gaps filled: [list].
```

---

## §9 — Mode C workflow (resume V1.5 coding work)

Consolidation is "good enough"; pick up the operational queue.

### Step 1: Read

`docs/_consolidated/00_canonical_authority/MASTER_BUILD_PLAN.md` §0 loop pattern. This IS the loop:

```
loop:
  read this file (only on first turn)
  pick next item with status ⚪ PENDING from §7 priority queue
  follow §1–§6 contract for that item
  ship it (commit + WRV proof in PR description)
  update §7 status to 🟢 SHIPPED with commit SHA
  goto loop
```

### Step 2: Look at FUSED_AUDIT_VIEW.md §2

Top 3 still-open Blockers (priority order):

1. **W9.21 PR4** — Swift consumer cutover for honest-FFI handles. ~1.5 hr Lane C.
2. **W9.8** — NSAlert → ApprovalModalView production wire. ~2 hr Lane C.
3. **AnyView 16-violation cleanup** — Doctrine §6 #6 enforcement. ~2 hr Lane A.

These touch disjoint files; safe for parallel `isolation: "worktree"` agents per orchestrator §3.

### Step 3: Pick one, follow MASTER_BUILD_PLAN.md §1–§6 contract

Includes 7 verification gates (§3) and the WRV gate (§4.7) — every item must verify Wired + Reachable + Visible before it can be marked SHIPPED.

### Step 4: Commit + update tracker

Per MASTER_BUILD_PLAN.md §10 commit format. Includes WRV proof block.

---

## §10 — Output protocol

When done with whatever mode you're in:

1. **Brief summary** to user: count of files processed / Blockers shipped / gaps filled.
2. **Pending list** for next session.
3. **Updated todos** via `TodoWrite`.
4. **NO destructive operations** without user OK (no `rm`, `mv`, force-push, branch delete, etc.).
5. **NO commits** unless user explicitly asks.

---

## §11 — End-of-session signals (when to stop)

Stop and surface to user immediately if:

1. You hit a `[UNVERIFIED]` claim that can't be resolved via Read/Grep/WebFetch.
2. A file's content contradicts its inferred classification (e.g., a doc named "MASTER" turns out to be 3 lines of pseudocode).
3. You're about to do a destructive op.
4. The bash chunking returns >25 K tokens despite small line count (file has very long lines; needs a different strategy).
5. You discover scope creep is necessary (e.g., you find a doc that needs new tier classification not covered above).
6. You exceed ~30 file reads in one session — surface, get OK to continue.
7. A canonical doc has changed since the previous session's read (verify by re-running first 30 lines and comparing the §3 done-list).

---

## §12 — Quick-start for this session

If you're a fresh Claude Cowork session reading this:

1. Read §0–§4 of this prompt (you've done that).
2. Read §5 listed canonical docs (in `_consolidated/00_canonical_authority/`).
3. Ask the user: "Mode A, Mode B, or Mode C?"
4. Execute that mode per §7 / §8 / §9.
5. Cap at ~3 hours of work; then surface progress + pending list.

If user says "just go" or doesn't specify: default to **Mode B** first (verify + fill gaps in fusion docs is fastest leverage), then Mode A if time, then surface.

---

## §13 — Things explicitly NOT in scope for this prompt

- Do NOT regenerate `_consolidated/` from scratch. It's built; just maintain it.
- Do NOT write Swift / Rust code unless user picked Mode C.
- Do NOT create new fusion docs without user OK (the 3 existing ones are already comprehensive).
- Do NOT touch user auto-memory at `/Users/jojo/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/` unless explicitly asked. (If user says "update my memory about X" — then you may.)
- Do NOT interact with `/Users/jojo/Downloads/Epistemos/.git/` directly.

---

## §14 — Reference: previous session's todo list

Final state from session that authored this prompt:

```
- [completed] Read PLAN_V2.md fully
- [completed] Digest all 4 research corpora via Explore
- [completed] Add canonical-pointer banner to docs/plan/README.md
- [completed] Mark auditor_loop.md SUPERSEDED but keep file
- [completed] Add §C-bis to 05_RESEARCH_INDEX.md for /final v3/
- [completed] Read 5 large in-repo docs fully (CANONICAL_AUDIT, CRITIQUE, EXECUTION_MAP, DOSSIER, CLI_CONFIG)
- [completed] Add canonical-status banners to 4 large docs
- [completed] Build docs/_INDEX.md
- [completed] Add DEFERRED banners to 2 + SUPERSEDED banners to 3
- [completed] Build _consolidated/ tier tree + 76 file copies
- [completed] Write _consolidated/README.md, FUSED_AUDIT_VIEW, FUSED_RESEARCH_DIGEST
- [completed] Write COWORK_MASTER_PROMPT.md (this file)
- [pending — your work] Mode A: process unprocessed docs (~150 files in §4)
- [pending — your work] Mode B: verify + fill gaps in fusion docs
- [pending — user OK] mass move clearly-superseded files into docs/superseded/ folder (currently they stay in place with banners)
- [pending — user OK] per-file deletion review for ~17 truly-transient files
```

---

**START NOW**: ask the user which mode (A/B/C). Default Mode B if no answer in their first turn.
