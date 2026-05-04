# Epistemos `docs/` — Canonical Index

> **Index status**: CANONICAL — Already canonical (this file).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/00_canonical_authority/`.



> **Last updated**: 2026-04-27
> **Purpose**: ONE entry point that tells you which doc is canonical, which is deferred research (kept until built), and which is superseded historical (kept for reference, not active).
> **Anti-drift rule**: every file in `docs/` is classified here. If a file isn't in this index, it's drift — flag it and add it.

---

## §1 — Read order for any new agent session

```
1. CLAUDE.md                                ← code standards (top of hierarchy)
2. docs/architecture/PLAN_V2.md             ← architectural authority
3. docs/MASTER_BUILD_PLAN.md                ← OPERATIONAL ENTRY POINT (queue + loop)
4. docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md ← contract
5. docs/plan/01_DOCTRINE.md                 ← 14 non-negotiables
6. docs/plan/02_BUILD_MATRIX.md             ← Pro/MAS gating
7. docs/plan/03_EXECUTION_MAP.md            ← per-item depth
8. docs/CANONICAL_AUDIT_LOG.md (tail)       ← what's drifting
9. docs/CRITIQUE_LOG.md (tail)              ← per-commit findings
10. docs/V1_5_IMPLEMENTATION_TRACKER.md     ← live status board
```

Items further down only when their item is picked up.

---

## §2 — Canonical authority chain (Tier 1; never archive)

| File | Role | Status notes |
|---|---|---|
| `CLAUDE.md` | Code standards + provider matrix + DO NOT list | Repo root. Top of authority. |
| `docs/architecture/PLAN_V2.md` | Architectural authority (1631 lines) | If this contradicts anything below, PLAN_V2 wins. |
| `docs/MASTER_BUILD_PLAN.md` | Operational doctrine + §7 queue + §10 quick-start | Explicit canonical entry point. |
| `docs/plan/README.md` | Plan-tree index (depth-refs map) | Pointer to MASTER_BUILD_PLAN. |
| `docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md` | The contract every agent obeys (WRV §4.7) | Mandatory pre-flight read. |
| `docs/plan/01_DOCTRINE.md` | 14 non-negotiables + 5 fifth-position rulings + Open Provenance Standard §5 | Doctrine #14 = no orphan scaffolding (the whole rule). |
| `docs/plan/02_BUILD_MATRIX.md` | Pro/MAS feature gating | Every PR declares profile impact. |
| `docs/plan/03_EXECUTION_MAP.md` | Per-item depth (36 items: R/W9/D/N) with verified file:line + WRV expectations | The "boarding pass" for any item. |
| `docs/plan/04_PHASES.md` | Phase 0–4 entry/exit gates + parallel open-standard track | |
| `docs/plan/05_RESEARCH_INDEX.md` | Reverse-index from items → research files in `~/Downloads/Advice` `/final` `/final v2` `/final v3` | Updated 2026-04-27 with §C-bis for `/final v3`. |

**Never archive any of these.** They are the spine.

---

## §3 — Living audit + tracker logs (Tier 2; append-only, regenerated continuously)

| File | Role | Cadence | Status |
|---|---|---|---|
| `docs/CANONICAL_AUDIT_LOG.md` | Deep architectural drift audit (3 passes, 14 Blockers + 1 Major + 1 partial-resolved open) | Snapshot, ~weekly or post-major-refactor | CANONICAL |
| `docs/CRITIQUE_LOG.md` | Rolling per-commit auditor findings (14 passes since 2026-04-27) | Hourly during active dev | CANONICAL |
| `docs/V1_5_IMPLEMENTATION_TRACKER.md` | Live status board (🟢/🟡/🔵/⚪/⏸ per item) | Every commit | CANONICAL |
| `docs/AGENT_PROGRESS.md` | Session-log of progress markers (cited in CLAUDE.md startup) | Session-end | CANONICAL |
| `docs/APP_ISSUES_AUTO_FIX.md` | Runtime-issue register (cited in CLAUDE.md auto-fix opportunities) | Append on discovery | CANONICAL |
| `docs/KNOWN_ISSUES_REGISTER.md` | 19-bug register tied to Phase R (resource-runtime hardening) | Append on discovery | CANONICAL |

**Cross-ref recommendation (NOT YET DONE; needs user approval)**: CANONICAL + CRITIQUE overlap ~30 % on Blockers. Rather than merge (lose nuance), add a cross-ref matrix at the top of each linking the same Blocker across both views. Until merged, both stay canonical and authoritative.

---

## §4 — Canonical research dossiers (Tier 2; load when item touched)

Synthesis of the four-corpus research (`/Advice`, `/final`, `/final v2`, `/final v3`).

| File | Role | Linked from |
|---|---|---|
| `docs/RESEARCH_DOSSIER_TIER_3_4.md` | Per-item paste-ready research prompts + Bucket A/B/C/D sequencing + Common Epistemos Context block | `03_EXECUTION_MAP.md` per-item Research mandates |
| `docs/STRUCTURING_AUDIT.md` | Input → structure pipeline (S1–S16 surfaces, G1–G9 gap-fixes) | `MASTER_BUILD_PLAN.md §9` pre-flight reads |
| `docs/RESOURCE_INVENTORY.md` | Resource-runtime accounting for Phase R (live IDs / file paths backing Known Issues) | `KNOWN_ISSUES_REGISTER.md` |
| `docs/RESOURCE_RUNTIME_RESEARCH.md` | Resource-runtime architectural advice for Phase R (canonical IDs, ResourceService, snapshot-vs-live attachments) | `IMPLEMENTATION_PLAN_FROM_ADVICE.md` |
| `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` | 4-model council synthesis (Developer ID over MAS, schema-first GenUI, UniFFI primary) | User memory `project_advice_council_2026_04_22` |
| `docs/PROMPT_AS_DATA_SPEC.md` | N1 specification (JSPF + PTF format spec; N1 now SHIPPED) | `MASTER_BUILD_PLAN.md §7 N1` |

**KEEP all six.** Each is unique research the canonical plan tree cites by reference.

---

## §5 — Canonical implementation references — CLI integration (Tier 3; load when implementing CLI work)

| File | Role |
|---|---|
| `docs/CLI_CONFIG_COMPILATION_RESEARCH.md` | Authoritative compiler reference for Claude Code / Codex / Gemini configs (Apr 2026). Drop-in templates + Rust struct + regeneration policy. |
| `docs/claude-code-codex-parity-options.md` | Runtime-path comparison (Tunnel C subprocess vs Option 2 URL handoff vs Option 3 codex-mcp-server vs Option 4 static bundle) with recommendation. |
| `docs/capability-tunnels.md` | 4-tunnel capability strategy (A shell / B.1 URL MCP / B.2 stdio MCP / C CLI passthrough). |
| `docs/mcp-url-servers.md` | Tunnel B.1 deep-dive (`~/.config/mcp/url_servers.json` format). |

**KEEP all four.** Each covers a distinct CLI integration concern; no overlap.

---

## §6 — Canonical prompts (Tier 3; ready-to-paste session starters)

| File | Role |
|---|---|
| `docs/plan/prompts/_TEMPLATE.md` | Template for new task prompts (slots: ITEM_ID, ITEM_TITLE, etc.). |
| `docs/plan/prompts/full_session_orchestrator.md` | Single-session orchestrator (current; absorbs audit + ship + verify into one loop). |
| `docs/plan/prompts/N1_prompt_tree.md` | N1 (Prompt Tree) task prompt — N1 now SHIPPED; keep as reference. |
| `docs/plan/prompts/W9.25_grammar_masking.md` | W9.25 task prompt — partial; future PRs cite it. |
| `docs/plan/prompts/phase0_ship_blockers.md` | Phase 0 ship-blockers task prompt. |
| `docs/plan/prompts/auditor_loop.md` | **SUPERSEDED** by `full_session_orchestrator.md` (banner added 2026-04-27); kept for the cron-scheduled separate-auditor pattern in case multi-builder mode returns. |

**KEEP all six.** The auditor_loop is preserved with explicit SUPERSEDED banner — not deleted.

---

## §7 — Operational subdirectories (KEEP; classify items inside as needed)

| Dir | Status | Notes |
|---|---|---|
| `docs/plan/` | CANONICAL | Plan tree (00–05 + README + prompts/). All canonical. |
| `docs/architecture/` | MIXED | PLAN_V2.md + README canonical; rest = phase-specific handoffs (PHASE_*_HANDOFF, PLAN_V2_CANONICALIZATION_*) — historical references for state recovery. Audit individually before archiving. |
| `docs/audits/` | CANONICAL-OPERATIONAL | 39 timestamped audit files; needed for state reconstruction. Append-only. |
| `docs/handoffs/` | CANONICAL-HISTORICAL | 14 session handoff files; historical state recovery. Keep for 30 days minimum. |
| `docs/research/` | CANONICAL-DEFERRED | Hermes deep-dive research (9 files); needed for Phase D + K. |
| `docs/legal/` | CANONICAL-OPERATIONAL | License + privacy policy. Don't touch. |
| `docs/release/` | CANONICAL-OPERATIONAL | MAS app review notes. Operational reference. |

---

## §8 — Deferred research (KEEP; defer = "research exists, feature not yet built")

These are research/spec docs for **unimplemented features** the plan tree references. Move to `docs/deferred/` if you want them visually separated from canonical, but **do not delete** — they're load-bearing references for future phases.

| File | Phase it informs | Status notes |
|---|---|---|
| `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md` | Phase R+ (ambient recall) | Research; deferred until Phase R closes. |
| `docs/INSTANT_RECALL_ARCHITECTURE.md` | Phase R+ (instant recall) | Research direction. |
| `docs/OPENCLAW_FEATURE_SPEC.md` | Phase K (iMessage / OpenClaw) | Pro-only; Phase K deferred until App Store ships per `project_app_store_first_sequencing` memory. |
| `docs/CONTROL_PLANE_RESEARCH.md` | Phase D (control plane) | Research. |
| `docs/UNIFIED_SUBSTRATE_RESEARCH.md` | Substrate (GRDB/provenance foundation) | Phase D research. |
| `docs/HERMES_INTEGRATION_RESEARCH.md` | Phase D / K (Hermes provider) | Cited in CLAUDE.md "Detailed Docs". |
| `docs/TOOL_TIER_AND_IMESSAGE_INTEGRATION.md` | Phase K | Research. |
| `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` | Cognitive layer (post-V1.5) | Research. |
| `docs/architecture/EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN.md` | Cross-cutting research | Synthesis doc. |
| `docs/superpowers/` (subdir) | W9.24 Metal zero-copy + graph embedding | Spec for deferred Bucket D items. |

**Recommended move** (with user OK): `mkdir -p docs/deferred/` and `git mv` these into it so canonical/non-canonical separation is visible at a glance. Index entries above stay; just paths update.

---

## §9 — Superseded historical (KEEP for reference, mark with banner; not active)

These docs were canonical at one point but have been **superseded by a newer canonical doc**. Rather than delete (per user policy), label them and keep. Add a `> **Status**: SUPERSEDED-HISTORICAL — see <successor>` banner at the top of each.

| File | Superseded by | Reason |
|---|---|---|
| `docs/MASTER_SESSION_PROMPT.md` | `MASTER_BUILD_PLAN.md §9` | Older session-bootstrap; new master plan absorbs it. |
| `docs/EPISTEMOS_FUSED_v3.md` | `MASTER_BUILD_PLAN.md` + `IMPLEMENTATION_PLAN_FROM_ADVICE.md` | Older comprehensive build spec; ingested. |
| `docs/IMPLEMENTATION_BLUEPRINT.md` | `IMPLEMENTATION_PLAN_FROM_ADVICE.md` | Older blueprint; superseded. |
| `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` | Phases 1+2 in `04_PHASES.md` + W9.21/22/23/29 in execution map | Pre-MASTER_BUILD_PLAN. |
| `docs/PROGRESS.md` | `AGENT_PROGRESS.md` | Older predecessor; same role. |
| `docs/ROADMAP_NEXT_3.md` | `04_PHASES.md` | Older phase planning. |
| `docs/REMAINING_WORK_INVENTORY.md` | `03_EXECUTION_MAP.md` + `V1_5_IMPLEMENTATION_TRACKER.md` | Older inventory. |
| `docs/HARDENING_VERIFICATION.md` | Phase S (per `project_app_store_first_sequencing`) | Pre-Phase-S ops. |
| `docs/PHASE_CHECKLIST.md` | `04_PHASES.md` | Older phase checklist. |
| `docs/MULTI_SESSION_PROTOCOL.md` | `full_session_orchestrator.md` (consolidated single-session model) | Now historical; kept because the protocol is referenced in CRITIQUE_LOG header. |
| `docs/ARCHITECTURE_AUDIT.md` | `CANONICAL_AUDIT_LOG.md` | Older one-off audit. |
| `docs/AUDIT_REFLECTION_2026_04_23.md` | `CANONICAL_AUDIT_LOG.md` Pass #1+ | Mid-session reflection. |
| `docs/V1_AUDIT.md`, `docs/V1_SCOPE_BOUNDARY_INVENTORY.md` | `V1_5_IMPLEMENTATION_TRACKER.md` | V1 shipped; trackers cover post-V1. |
| `docs/VERIFICATION_PROTOCOL.md` | Phase S | Pre-Phase-S ops. |
| `docs/ANTI_DRIFT_SYSTEM.md` | `docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md` | Overlap ~80 % with canonical version. |
| `docs/EPISTEMOS_SPECIALTIES.md` | Implicit in `02_BUILD_MATRIX.md` | Older capabilities matrix. |
| `docs/MASTER_MODEL_STACK_PLAN.md` | `D4` in `03_EXECUTION_MAP.md` (faculty roster) | Older provider matrix research. |
| `docs/OMEGA_*.md` (5 files) | Omega system retired per `IMPLEMENTATION_PLAN_FROM_ADVICE.md` | Keep `OMEGA_ARCHITECTURE.md` for Phase R reference; archive the others. |
| `docs/CODEX_*.md` (5 files) | `MASTER_BUILD_PLAN.md` | Old session-bootstrap prompts. |
| `docs/CODE_EDITOR_*.md` (4 files) | PLAN_V2 §23 | Phase S editor docs; resolved into PLAN_V2. |
| `docs/THEME_*.md` (6 files) | Completed feature work; ship history | Keep `THEME_REVAMP_FINAL_CHANGELOG.md` only. |
| `docs/GRAPH_WAVES_*.md` (3 files) | Landing wave done per `project_landing_wave_redesign` memory | Historical feature shipped. |
| `docs/GOOSE_*.md` (3 files) | Goose migration tracked in `project_goose_migration` memory | Historical comparative research. |
| `docs/HERMES_PARITY_REPORT.md` | Subsumed by Hermes-as-provider ruling in `01_DOCTRINE.md §2.2` | Comparative analysis; ruling already absorbed. |
| `docs/KIMI_*.md` (3 files) | Historical session audit | Kept for state recovery. |
| `docs/CLAUDE_CANONICAL_STATE_HANDOFF_2026-04-23.md` | Session handoff; consumed | Keep 30 days. |
| `docs/CLAUDE_OMEGA_AUDIT_FIX_MANIFESTO_2026_03_25.md` | Older session directive | Historical. |
| `docs/CLAUDE_UPGRADE_PLAN_SYNOPSIS.md` | Model-version policy now in `CLAUDE.md` | One-off. |
| `docs/AGENT_DEEP_VERIFICATION_MANUAL.md` | WRV gate in `00_AUTHORITY_AND_ANTI_DRIFT.md §4.7` | Replaced. |
| `docs/AGENT_FUSION_RESEARCH_PROMPT.md` | `MASTER_BUILD_PLAN.md` | One-off prompt. |
| `docs/AGENT_INTEGRATION_SESSION_PLAN.md` | `MASTER_BUILD_PLAN.md` | Transient. |
| `docs/AUDIT-HANDOFF-Ω10-Ω14.md` | Omega retired | Historical. |
| `docs/BEST_OF_CLAW_AND_OPENCLAW.md` | Phase K design (`OPENCLAW_FEATURE_SPEC.md`) | Research synthesis ingested. |
| `docs/BUILD_TEST_GREEN_BASELINE.md` | Periodic; new baselines supersede | Historical baseline. |
| `docs/FEATURE_SPEC_TOC_AND_FOLDING.md` | Phase S editor surface | Phase S deferred per memory. |
| `docs/FUSED_AGENT_ENGINEERING_REPORT.md` | `IMPLEMENTATION_PLAN_FROM_ADVICE.md` | Older research synthesis. |
| `docs/GPU_RENDERER_SEAM.md` | W9.24 Metal zero-copy in `03_EXECUTION_MAP.md` | Research ingested. |
| `docs/LANDING_WAVE_SEARCH_PLAN.md` | Landing wave shipped | Historical feature plan. |
| `docs/NANO-MASTER-TRAINING-GUIDE.md` | Training is research-grade; D11+ deferred | Historical. |
| `docs/PERF_BASELINE.md` | Per-PR benchmarks supersede | Historical. |
| `docs/POST_V1_OPPORTUNITY_MAP.md` | Phase 4 + post-V1.5 in `04_PHASES.md` | Aspirational roadmap. |
| `docs/RESEARCH_*.md` (3 older research dump files) | `RESEARCH_DOSSIER_TIER_3_4.md` | Older research dumps. |
| `docs/SKILL_*.md` (2 files) | `D9` in execution map | Historical feature design. |
| `docs/VISION_BACKLOG.md` | Phase 4+ in `04_PHASES.md` | Aspirational. |
| `docs/WAVE_*.md` (2 files) | Wave-based planning superseded by phase-based | Historical. |
| `docs/ai_stack_*.md` (4 files) | Provider matrix research; ingested into `02_BUILD_MATRIX.md` | Historical research. |
| `docs/epistemos-deep-analysis.md` | Codebase analysis; cited in CLAUDE.md "Detailed Docs" | Keep as canonical reference (move to canonical research?) |
| `docs/future-work-audit.md` | `04_PHASES.md` | Aspirational. |
| `docs/non_agent_full_app_pruning_audit_research_pack_2026-03-26.md` | One-off pruning research | Historical. |
| `docs/handoffs/*` (14 files) | Session handoffs | Historical-operational. |
| `docs/sprint-sessions/*` (7 files) | `04_PHASES.md` | Old sprint plans; keep recent only. |

**Recommended move** (with user OK): `mkdir -p docs/superseded/` and `git mv` these. Banners on each pointing to the canonical successor. **Nothing deleted.**

---

## §10 — Delete-candidate (with user explicit approval per file)

These are confirmed-transient or duplicate files. **Do NOT delete without per-file confirmation from user**, per user's stated policy.

| File | Reason | Confidence |
|---|---|---|
| `docs/AUDIT_LOG.md` | Duplicate name of `CANONICAL_AUDIT_LOG.md`; if content overlaps, delete safely (verify first). | Medium — must verify content first |
| `docs/CHANGELOG_THEME_REFACTOR.md` | Per-PR changelog; superseded by git log. | High |
| `docs/NEXT_SESSION_PROMPT.md` | Single-session bootstrap prompt; superseded. | High |
| `docs/CLAUDE_CODE_SESSION_PROMPT.md` | Older session prompt; superseded by `MASTER_BUILD_PLAN.md §9`. | High |
| `docs/SESSION_BOOTSTRAP_PROMPT.md` | Same. | High |
| `docs/handoff-prompt.md` | Generic handoff template; not used. | High |
| `docs/IMPLEMENTATION_PROMPTS.md` | Ephemeral prompt collection. | High |
| `docs/PARALLEL_SESSION_PROMPT.md` | Superseded by orchestrator. | High |
| `docs/PERPLEXITY_DEEP_AUDIT_PROMPT.md` | One-off audit tool prompt. | High |
| `docs/SESSION_REPORT_2026-04-06.md` | Dated session report. | High |
| `docs/SESSION_STATE_2026_03_25.md` | Dated state snapshot. | High |
| `docs/session-handoff-2026-03-07.md` | Dated handoff. | High |
| `docs/KF_CONTINUATION_PROMPT.md` | Knowledge Fusion continuation; KF is retired. | High |
| `docs/FINAL_VERIFICATION_CHECKLIST.md` | One-off checklist. | High |
| `docs/audits/verify-2026-03-21-*.md` | Old verify snapshots; keep latest 3 only. | High |
| `docs/audits/verify-2026-03-28-*.md` | Same. | High |
| `docs/audits/verify-2026-04-09-*.md` | Same. | High |
| `docs/plans/*.md` (37 files) | Old plan tree; superseded by `docs/plan/`. Verify each before deleting. | Medium — bulk verify |
| `docs/knowledge-fusion/*.md` (3 files) | KF system retired; obsolete per `IMPLEMENTATION_PLAN_FROM_ADVICE.md`. | Medium |

**Recommended action**: review this list with user, get per-file approval, then `git rm` in batches with explanatory commit messages.

---

## §11 — Workspace conventions

- **Plan-tree depth refs** (`docs/plan/00–05`) are loaded by every Builder agent on session start. Keep them tight (under ~1500 lines each); push detail into `prompts/` task files or item-specific spec files (e.g. `PROMPT_AS_DATA_SPEC.md`).
- **Audit logs** (CANONICAL + CRITIQUE) are append-only. Resolved findings stay logged with resolution commit; nothing is deleted from history.
- **Tracker** (`V1_5_IMPLEMENTATION_TRACKER.md`) is the live status board. The execution-map (`03_EXECUTION_MAP.md`) is the per-item spec. They co-exist by design (different audiences).
- **Research dossier** (`RESEARCH_DOSSIER_TIER_3_4.md`) is paste-ready research prompts + Bucket sequencing. The execution map is the implementation gating layer. They overlap on item names but serve different roles.
- **CLI integration docs** (CLI_CONFIG_COMPILATION_RESEARCH + claude-code-codex-parity-options + capability-tunnels + mcp-url-servers) are four distinct concerns; keep all four.

---

## §12 — Outstanding consolidation actions (pending user OK)

1. **Add cross-ref matrix** at top of CANONICAL_AUDIT_LOG and CRITIQUE_LOG so the same Blocker is findable in both views. (Lower-risk than merging.)
2. **Move deferred research** to `docs/deferred/` (mass `git mv`, paths only, no content change).
3. **Move superseded historical** to `docs/superseded/` (mass `git mv` + banner additions).
4. **Per-file deletion review** for the §10 delete-candidate list.
5. **Audit `docs/architecture/`** — keep PLAN_V2 + README; classify rest as Deferred / Superseded.
6. **Bulk-classify `docs/plans/`** — high probability all 37 files are superseded by `docs/plan/`; verify and archive.

Each action above is independent. Recommend executing in order 1 → 2 → 3 → 4 → 5 → 6 to maintain reviewability.

---

## §13 — Last verified

- **2026-04-27 (initial)**: Index built after full reads of `CANONICAL_AUDIT_LOG.md`, `CRITIQUE_LOG.md`, `03_EXECUTION_MAP.md`, `RESEARCH_DOSSIER_TIER_3_4.md`, `CLI_CONFIG_COMPILATION_RESEARCH.md`, `PLAN_V2.md`, all `docs/plan/` files. Research-corpus digest from 4 parallel Explore agents (Advice / final / final v2 / final v3). Inventory of orphan docs from a 6th Explore agent.
- **2026-04-27 (second pass)**: Massive scope expansion per user directive. 8 master-plan-class docs + 218 topical research files + 195 Downloads root + 25 jojo root scanned. **`MASTER_FUSION.md`** authored at `_consolidated/00_canonical_authority/` — single canonical fusion of the master plans into one checkable execution list. Corpus expanded from 95 → 441 files (17 MB). Originals at `~/Downloads/` and `~/jojo/` untouched (verified bit-identical via `cmp -s`).

---

## §14 — Master plans corpus (added 2026-04-27, second pass)

Eight master-plan-class documents identified and synthesized into `_consolidated/00_canonical_authority/MASTER_FUSION.md`. Each contributes a distinct layer of the architecture-thinking stack:

| # | Doc | Layer | Status |
|---|---|---|---|
| 1 | `EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER.md` (2026-04-27, 52KB) | Latest audit (file:line verification of 20 shipped moats + 13-item drift inventory) | **CANONICAL-RESEARCH** — copied to `_consolidated/50_research_corpus/master_plans/` |
| 2 | `2026-03-27-master-gap-closure-plan.md` (Opus 4.6, 124KB) | Gap-closure single source of truth (5 hard blockers identified) | **CANONICAL-RESEARCH** — copied |
| 3 | `EPISTEMOS_MEGAPROMPT.md` (2026-03-28, 40KB) | Sprint operationalization (7 workstreams × 17 days) | **CANONICAL-RESEARCH** — copied |
| 4 | `EPISTEMOS_PHASE_I_IMPLEMENTATION_GUIDE.md` (86KB) | Phase I Pure Rust Agent Runtime deep dive | **CANONICAL-RESEARCH** — copied |
| 5 | `PLAN_V2_UPDATED.md` (60KB) | Architectural authority (27 sections; possibly superset of canonical `PLAN_V2.md`) | **CANONICAL-RESEARCH** — copied (verify against canonical PLAN_V2.md before promotion) |
| 6 | `master_plan_doc.md` (26KB) | 16-phase cognitive blueprint | **CANONICAL-RESEARCH** — copied |
| 7 | `EPISTEMOS_MASTER_THESIS.md` (38KB) | "Harness Engineering and the Death of the Cloud" — market positioning + Stateful Rotor + 5 hardware-symbiotic engines | **CANONICAL-RESEARCH** — copied |
| 8 | `harness-engineering-thesis.md` (48KB) | Engineering thesis variant | **CANONICAL-RESEARCH** — copied |

**Originals untouched**: 6 at `~/Downloads/`, 2 at `~/jojo/`. Bit-identical verification passed.

---

## §15 — Downloads + jojo root expansion (added 2026-04-27, second pass)

Per user directive ("find all research in the entire downloads root level their nested folders, prioritize MAS / Pro mode / CLIs / Hermes / agent integrations"), recursively scanned `~/Downloads/` (excluding 3rd-party code repos: openclaw-main, logseq-source, Sunshine-master, claw-code, rowboat, epistemos-public, Epistemos-laneA, Epistemos-*-backup-*) + `~/jojo/` root. Bulk-copied with content-hash dedup:

| Source | Files copied (after dedup) | Tier subdir |
|---|---|---|
| `~/Downloads/*.{md,txt}` (root) | 184 | `50_research_corpus/downloads_root/` |
| `~/jojo/*.{md,txt}` (root) | 3 | `50_research_corpus/jojo_root/` |
| `~/Downloads/old research/` | 41 | `50_research_corpus/old_research/` |
| `~/Downloads/mass research folder/` + `next batch of unsorted research/` + `unsort3ed research/` | 65 (dedup absorbed dupes into downloads_root) | `50_research_corpus/mass_research/` |
| `~/Downloads/meta-analytical-pfc/` | 11 | `50_research_corpus/meta_analytical_pfc/` |
| `~/Downloads/audit/` | 11 | `50_research_corpus/audit_dir/` |
| Smaller clusters (last_feature, livingbrain, fluid_dir, ambient_dir, opt_dir, workspace_dir) | 22 | individual subdirs |

**Total in second pass**: ~327 new files. Total `_consolidated/` now: **441 files (17 MB)**. Originals untouched.

Topical findings synthesized into `_consolidated/50_research_corpus/00_FUSED_RESEARCH_DIGEST.md §5.6` covering: MAS / App Store / Pro mode (V1 = sandboxed App Store with Halo+Shadows; Pro later), CLI integration (Claude Code, Codex, capability tunnels, MCP), Hermes parity (5-phase closure plan; 5 orphaned tools to register), agent system (Omega Dual-Brain protocol: Reasoning Brain on GPU + Device Action Agent on ANE; Mirror Speculative Decoding; UI-TARS; VLM2VLA; MoLoRA per-app routing; ODIA nightly LoRA), memory architecture (Mamba-3 + binary HNSW + Model2Vec + state injection), training pipelines (Nano/Base/Pro multi-scale family), UI/UX (Time Machine 4-layer Metal shader pipeline), audit/hardening (4 failure modes, AppSupervisor/EpistemosHealthMode/AgentCircuitBreaker assessments).
