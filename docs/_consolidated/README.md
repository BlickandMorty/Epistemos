# Epistemos — Consolidated Doctrine, Research, and Implementation View

> **Created**: 2026-04-27
> **Purpose**: Single read-only consolidated tree containing **copies** of every canonical and load-bearing doc, organized into tiers, with fused cross-views. **Originals in `docs/` and `~/Downloads/{Advice,final,final v2,final v3}/` are untouched** — this is a parallel consolidated view for fast onboarding.
> **Authoritative source**: when in doubt, the original wins. This tree is for navigation/onboarding only.
> **Editing rule**: do not edit anything in this tree. If you fix a doc, fix the original; re-run the copy script (`docs/_consolidated/_regenerate.sh`, future) to refresh the copies.

---

## Tier structure (~586 files, ~20 MB) — last updated 2026-04-27 (post Epistemos repo recursive pass)

```
_consolidated/
├── 00_canonical_authority/      (13 files)  ← Tier 1 — read first; the spine of execution
│   ├── MASTER_FUSION.md         ← ★ NEW (2026-04-27 PM): single canonical fusion of 8 master plans + the user's checkable execution list
│   └── ambient_V1_DECISION.md   ← (2026-04-27 AM): the V1 architectural verdict
├── 10_living_audits/            (6 files)   ← Tier 2 — what's drifting, what just shipped
│   └── FUSED_AUDIT_VIEW.md      ← Blocker-centric merged view (incl. V1 perf budget Note E + perf constraints Note F)
├── 20_canonical_research/       (8 files)   ← Tier 2 — synthesis docs cited from plan tree
│   └── perf_DETERMINISTIC_PERFORMANCE_PLAN.md  ← 6-sprint × 12-week perf program
├── 30_cli_integration/          (4 files)   ← Tier 3 — Claude Code / Codex / Gemini integration
├── 40_canonical_prompts/        (9 files)   ← Tier 3 — task prompts (incl. 3 perf-plan prompts)
├── 50_research_corpus/          (~349 files, ~10 MB)  ← Tier 4 — research corpus
│   ├── 00_FUSED_RESEARCH_DIGEST.md  ← cross-corpus synthesis (now incl. §5.5 workspace/opt/ambient + §5.6 master plans + downloads_root)
│   ├── advice/                  (7 files)   ← /Downloads/Advice/
│   ├── final/                   (8 files)   ← /Downloads/final/ executive sumaries + last round of thinking
│   ├── final_v2/                (6 files)   ← /Downloads/final v2/
│   ├── final_v3/                (1 file)    ← /Downloads/final v3/
│   ├── master_plans/            (8 files)   ← ★ NEW: the 8 master-plan-class docs synthesized into MASTER_FUSION.md
│   ├── downloads_root/          (184 files) ← NEW: ~/Downloads/*.{md,txt} root level (after content-hash dedup)
│   ├── jojo_root/               (3 files)   ← NEW: ~/jojo/*.{md,txt} root level
│   ├── old_research/            (41 files)  ← NEW: Omega/Nano/Time Machine/Instant Recall/Mac AI Assistant
│   ├── mass_research/           (65 files)  ← NEW: dedup of mass research folder + next batch + unsort3ed
│   ├── meta_analytical_pfc/     (11 files)  ← NEW: meta-analytical PFC research
│   ├── audit_dir/               (11 files)  ← NEW: ~/Downloads/audit/
│   ├── workspace_dir/           (5 files)   ← workspace cluster
│   ├── opt_dir/                 (7 files)   ← opt cluster
│   ├── ambient_dir/             (4 files)   ← ambient cluster
│   ├── last_feature/            (4 files)   ← ~/Downloads/last feature after new agents/
│   ├── livingbrain/             (1 file)    ← LivingBrain
│   └── fluid_dir/               (1 file)    ← fluid
├── 60_deferred_research/        (9 files)   ← Tier 5 — research for unimplemented features
└── 70_design_implementation/    (13 files)  ← Tier 5 — best comprehensive design+impl docs
```

**What changed 2026-04-27 (PM, second pass)**:
- **`MASTER_FUSION.md`** authored — single canonical fusion of 8 master-plan-class docs into one checkable execution list (per user directive: "5 master plans were supposed to fuse to one I just check off the list over time").
- **8 master plans** copied to `master_plans/`: EPISTEMOS_MASTER_THESIS, EPISTEMOS_MEGAPROMPT, EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER (2026-04-27 latest audit), 2026-03-27-master-gap-closure-plan, PLAN_V2_UPDATED, EPISTEMOS_PHASE_I_IMPLEMENTATION_GUIDE, master_plan_doc, harness-engineering-thesis.
- **184 unique research docs** copied from `~/Downloads/*.md` root (content-hash dedup against existing 95 files).
- **41 docs** from `~/Downloads/old research/` covering Omega Dual-Brain protocol, Nano Master Training Guide, Time Machine UI, Instant Recall (Mamba+Quantized Vector Memory), Local AI Agent Architecture, Mac AI Assistant Design Blueprint, On-Device AI Training System Research, MLX Constrained Decoding, Cognitive OS & Local Model Blueprint.
- **65 unique docs** from `mass research folder` + `next batch of unsorted research` + `unsort3ed research` (dedup absorbed most into downloads_root first).
- **11 from meta-analytical-pfc**, **11 from audit/**, **3 from jojo root**, plus smaller clusters.
- **Corpus expanded from 95 → 440 files.** Originals untouched.

**Read-first**: `MASTER_FUSION.md` (then `MASTER_BUILD_PLAN.md` for the operational queue).

---

## Tier 1 — `00_canonical_authority/` — the spine

Read in this order to get full canonical context for any agent session:

1. `CLAUDE.md` — code standards, provider matrix, file map, "DO NOT" list. Top of authority.
2. `PLAN_V2.md` — architectural authority (1631 lines). If anything contradicts this, this wins.
3. `MASTER_BUILD_PLAN.md` — operational doctrine + §7 queue + §10 quick-start. **The execution entry point.**
4. `00_AUTHORITY_AND_ANTI_DRIFT.md` — the contract every agent obeys (WRV §4.7).
5. `01_DOCTRINE.md` — 14 non-negotiables + 5 fifth-position rulings + Open Provenance Standard §5. Doctrine #14 = "no orphan scaffolding" is the load-bearing rule.
6. `02_BUILD_MATRIX.md` — Pro / MAS feature gating.
7. `03_EXECUTION_MAP.md` — per-item depth (36 items: R/W9/D/N) with verified `file:line` + WRV expectations.
8. `04_PHASES.md` — Phase 0–4 entry/exit gates + parallel open-standard track.
9. `05_RESEARCH_INDEX.md` — reverse-index from items → research files in `~/Downloads/{Advice,final,final v2,final v3}/`.
10. `_INDEX.md` — full classification of every doc with rationales.
11. `PLAN_TREE_README.md` — pointer doc for the plan tree.

---

## Tier 2 — `10_living_audits/` — what's actually shipping

- `CANONICAL_AUDIT_LOG.md` — deep architectural drift audit (3 passes; 14 Blockers + 1 Major drift + 1 partial-resolved open as of 2026-04-27 Pass #3).
- `CRITIQUE_LOG.md` — rolling per-commit auditor findings (14 passes since 2026-04-27).
- `V1_5_IMPLEMENTATION_TRACKER.md` — live status board (🟢/🟡/🔵/⚪/⏸ per item).
- `AGENT_PROGRESS.md` — session-log (cited in CLAUDE.md startup).
- `APP_ISSUES_AUTO_FIX.md` — runtime-issue register.
- **`FUSED_AUDIT_VIEW.md`** (NEW) — Blocker-centric pane that merges the architectural-drift lens (CANONICAL) and the per-commit lens (CRITIQUE) into one table, indexed by Blocker ID.

## Tier 2 — `20_canonical_research/` — load when item is touched

- `RESEARCH_DOSSIER_TIER_3_4.md` — paste-ready research prompts + Bucket A/B/C/D sequencing + Common Epistemos Context block.
- `STRUCTURING_AUDIT.md` — input → structure pipeline (S1–S16 surfaces; G1–G9 gap-fixes).
- `RESOURCE_INVENTORY.md` — Phase R live-resource accounting (issue-register backing).
- `RESOURCE_RUNTIME_RESEARCH.md` — Phase R substrate research (canonical IDs, ResourceService).
- `IMPLEMENTATION_PLAN_FROM_ADVICE.md` — 4-model council synthesis (Developer ID, schema-first GenUI, UniFFI primary).
- `PROMPT_AS_DATA_SPEC.md` — N1 spec (now SHIPPED).
- `KNOWN_ISSUES_REGISTER.md` — 19-bug register tied to Phase R.

## Tier 3 — `30_cli_integration/` — when implementing CLI work

- `CLI_CONFIG_COMPILATION_RESEARCH.md` — authoritative compiler reference for Claude Code / Codex / Gemini configs (Apr 2026); includes drop-in templates + Rust manifest struct.
- `claude-code-codex-parity-options.md` — runtime-path comparison (Tunnel C subprocess vs Option 2 URL handoff vs Option 3 codex-mcp-server vs Option 4 static bundle).
- `capability-tunnels.md` — 4-tunnel capability strategy (A shell / B.1 URL MCP / B.2 stdio MCP / C CLI passthrough).
- `mcp-url-servers.md` — Tunnel B.1 deep-dive.

## Tier 3 — `40_canonical_prompts/` — task starters

- `_TEMPLATE.md`, `full_session_orchestrator.md`, `N1_prompt_tree.md`, `W9.25_grammar_masking.md`, `phase0_ship_blockers.md`. Plus `auditor_loop.md` (SUPERSEDED, kept for reference).

## Tier 4 — `50_research_corpus/` — original research drops

- `advice/` (8 files) — earliest architectural advice (claude advice, Claude paper PDF, claudy research, Gemini paper PDF, Gpt paper, perplexity 2, Perplexity paper).
- `final/` (16 files) — post-research convergence + hackathon material + Hermes manifesto + executive summaries + last-round-of-thinking docs.
- `final_v2/` (6 files) — most recent runtime/inference research drop (Master Doctrine, deep-research-report, App Moats, Hackathon Plan).
- `final_v3/` (1 file) — prompt-engineering research (JSON schema, caching, Tool Search).
- **`00_FUSED_RESEARCH_DIGEST.md`** (NEW) — cross-corpus synthesis: what each corpus uniquely contributes, where they converge, where they diverge, what's NOT yet in canonical doctrine.

## Tier 5 — `60_deferred_research/` — research for unimplemented features

Research/spec docs the canonical plan references but the feature isn't built yet. Banner-marked DEFERRED-RESEARCH in originals.

- `AMBIENT_RECALL_HALO_MASTER_PLAN.md` — Phase H (ambient recall), gated on Phase R.
- `INSTANT_RECALL_ARCHITECTURE.md` — Phase R+ instant recall.
- `OPENCLAW_FEATURE_SPEC.md` — Phase K (iMessage), Pro-only.
- `CONTROL_PLANE_RESEARCH.md` — Phase D research.
- `UNIFIED_SUBSTRATE_RESEARCH.md` — substrate Phase D (the "Five Laws" need cross-check with CLAUDE.md).
- `HERMES_INTEGRATION_RESEARCH.md` — Phase D / K Hermes provider (cited in CLAUDE.md "Detailed Docs" — operational reference).
- `TOOL_TIER_AND_IMESSAGE_INTEGRATION.md` — Phase K design.
- `COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` — post-V1.5 cognitive layer.
- `EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN.md` — cross-cutting synthesis.

## Tier 5 — `70_design_implementation/` — best comprehensive design+impl docs

- `EPISTEMOS_HERMES_MANIFESTO.md` — the strategic/aesthetic vision (Part I) + executable research brief (Part II) + compressed nine-day vector (Part III).
- `Episdemo Master Architecture Brief + Claude Brainstorm Prompt.md` — master architecture prompt (Swift 6 + Rust + UniFFI + MLX-Swift + GRDB; M2 Pro 16 GB; "ambient agency").
- `epistemos-deep-analysis.md` — codebase analysis (cited in CLAUDE.md "Detailed Docs").

---

## Read order (for new agent sessions)

```
1. 00_canonical_authority/CLAUDE.md
2. 00_canonical_authority/PLAN_V2.md (skim 1–8; deep-read sections referenced by your task)
3. 00_canonical_authority/MASTER_BUILD_PLAN.md (this is the operational entry point)
4. 00_canonical_authority/00_AUTHORITY_AND_ANTI_DRIFT.md
5. 00_canonical_authority/01_DOCTRINE.md
6. 10_living_audits/FUSED_AUDIT_VIEW.md (single-pane state of Blockers + recent ships)
7. 10_living_audits/V1_5_IMPLEMENTATION_TRACKER.md
8. (when picking up an item) 00_canonical_authority/03_EXECUTION_MAP.md → that item's section
9. (when picking up an item) 20_canonical_research/RESEARCH_DOSSIER_TIER_3_4.md → that item's research prompt
10. (only if research deep-dive needed) 50_research_corpus/00_FUSED_RESEARCH_DIGEST.md → relevant corpus section
```

For CLI integration work add Tier 3 reads. For deferred features add Tier 5 (`60_deferred_research/`).

---

## What is NOT in this tree

- Operational logs (`docs/audits/`, `docs/handoffs/`) — kept in their original location for historical state recovery; not duplicated here.
- Confirmed-superseded docs that don't add design/impl value — they stay in `docs/` with SUPERSEDED-HISTORICAL banners (see `docs/_INDEX.md §9`).
- Truly-transient files (old session prompts, dated handoffs, duplicate logs) — see `docs/_INDEX.md §10`.

---

## Fusion artifacts in this tree

Three derived docs synthesize sources without losing source nuance. Sources remain authoritative.

1. **`COWORK_MASTER_PROMPT.md`** (this directory) — single self-contained prompt for a fresh Claude Cowork session to (a) continue consolidation of unprocessed docs, (b) verify `_consolidated/` vs originals + fill gaps in fusion docs, or (c) resume V1.5 coding work with the canonical operational queue. Includes §6 Path Catalog listing every dense/nuanced/best doc with absolute path across `~/Downloads/{Advice,final,final v2,final v3}/` + the Epistemos repo. **Paste this file as the first message in a fresh Cowork session to continue.**
2. **`10_living_audits/FUSED_AUDIT_VIEW.md`** — every Blocker indexed once with both architectural-drift (CANONICAL_AUDIT_LOG) and per-commit (CRITIQUE_LOG) perspectives merged.
3. **`50_research_corpus/00_FUSED_RESEARCH_DIGEST.md`** — cross-corpus synthesis of `/Advice + /final + /final v2 + /final v3` contributions: unique contributions, convergent claims, divergent rulings, NOT-yet-canonical residuals, `[UNVERIFIED]` markers.

---

## Regeneration

This tree was built 2026-04-27 by manual `cp` commands captured in the session log. Future automation (TODO):
- `_regenerate.sh` — re-runs the copy script idempotently. Checksum compare; only update changed files.
- Integration into `docs/_INDEX.md §12` outstanding actions.

---

## Last verified

2026-04-27. Tier counts confirmed via `find _consolidated/<tier> -type f | wc -l`. Total 76 files, 3.1 MB.
