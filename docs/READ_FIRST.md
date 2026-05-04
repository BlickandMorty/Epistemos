# READ_FIRST.md — Clean entry point for plan execution

> **Purpose**: When you sit down to work on plans, this is the **only** file you need to open first. Everything else is either canonical (referenced from here) or archived (`_archive/`).
> **Last updated**: 2026-04-27
> **Anti-bombardment rule**: if a doc isn't in this list or referenced from one of these, it's either superseded (in `_archive/`) or research (in `_consolidated/50_research_corpus/`).

---

## §1 — The 7-doc canonical core (open these in order)

```
1. /CLAUDE.md                                    Code standards + provider matrix + DO NOT list
2. /docs/architecture/PLAN_V2.md                 Architectural truth (1631 lines)
3. /docs/MASTER_BUILD_PLAN.md                    Operational queue + WRV gate
4. /docs/_consolidated/00_canonical_authority/MASTER_FUSION.md
                                                 The fused master-plan checklist (§6 = your todo list)
5. /docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md     Execution contract
6. /docs/plan/01_DOCTRINE.md                     14 non-negotiables + provenance model
7. /docs/V1_5_IMPLEMENTATION_TRACKER.md          Live status board
```

That's it. Seven files. Nothing more is required to start work.

---

## §2 — The four pillars (the cognitive exoskeleton)

```
N1 PromptTree              prompt is data, not strings           docs/PROMPT_AS_DATA_SPEC.md
N2 Concept Door            every concept opens a world           _consolidated/00_canonical_authority/CONCEPT_DOOR_N2.md
N3 Exploration Spectrum    meter reshapes deliberation           _consolidated/00_canonical_authority/EXPLORATION_SPECTRUM_N3.md
N4 Local Analysis Mode     deterministic math+ML verification    _consolidated/00_canonical_authority/LOCAL_ANALYSIS_MODE_N4.md
```

These four compose. They are not separate features. Each is canonical in `_consolidated/00_canonical_authority/`.

---

## §3 — Where things live now (after 2026-04-27 cleanup)

| Need | Path |
|---|---|
| Read canonical authority | `docs/_consolidated/00_canonical_authority/` (24 files) |
| Read fusion docs (MASTER_FUSION, AI_STACK, etc.) | `docs/_consolidated/` |
| Read research corpus | `docs/_consolidated/50_research_corpus/` (~349 files, organized by source) |
| Read execution map / phase / build matrix | `docs/plan/` |
| Read live audits | `docs/audits/` (append-only, 54 timestamped) |
| Read live tracker | `docs/V1_5_IMPLEMENTATION_TRACKER.md` |
| Read AGENT_PROGRESS | `docs/AGENT_PROGRESS.md` |
| Read deferred / Pro-only research | `docs/_consolidated/60_deferred_research/` |
| Read superseded / older plans | `docs/_archive/` (organized by cluster — see _archive/MANIFEST.md) |

---

## §4 — What to do depending on the task

**"I want to work on the next item in the queue"**
→ Read `_consolidated/00_canonical_authority/MASTER_FUSION.md §6` (the one checkable list).

**"I want to ship V1"**
→ Read `_consolidated/00_canonical_authority/ambient_V1_DECISION.md` + `MASTER_FUSION.md §6.1` (V1 ship-critical).

**"I want to add Concept Door / Halo / Exploration Spectrum / Local Analysis Mode"**
→ Read the corresponding N2/N3/N4 standalone doc (in `_consolidated/00_canonical_authority/`).

**"I want to find some old research"**
→ `_consolidated/50_research_corpus/` (organized by source: master_plans/, downloads_root/, old_research/, advice/, final/, etc.)

**"I want to find what was superseded"**
→ `docs/_archive/` (organized by cluster: omega_retired/, theme_shipped/, plans_old/, etc.). See `_archive/MANIFEST.md`.

**"I'm a fresh agent and need to bootstrap"**
→ Open this file. Read §1's seven docs in order. Then jump to MASTER_FUSION §6.

---

## §5 — What was cleaned up 2026-04-27

- **113 SUPERSEDED-HISTORICAL + TRANSIENT-CANDIDATE files** organized into `docs/_archive/<cluster>/` by concept (omega_retired, theme_shipped, plans_old, etc.).
- **All 113 files exist in BOTH places** — original location preserved (so old references still resolve) AND archive copy (for concept-organized browsing). Bit-identical (verified via `cmp -s`).
- **Cluster organization** in `_archive/`: 32 plans_old + 17 google_research_packs + 16 architecture_handoffs + 13 sessions_handoffs + 8 audits_old + 7 sprint_sessions_old + 6 theme_shipped + 5 omega_retired + 5 kimi_goose_research + 4 knowledge_fusion_old.
- **Reference-fallback algorithm** added to `_consolidated/00_canonical_authority/MASTER_FUSION.md §0.1` — binding instruction for any agent: if a path is null at its stated location, search `_archive/` recursively, then `_consolidated/50_research_corpus/`, then surface `[BROKEN-REFERENCE]`.
- **See `_archive/MANIFEST.md`** for the exhaustive per-cluster file list.

---

## §6 — The doctrine in 5 lines

```
Halo gives ambient recall.
Concept Door gives deliberate depth.
Exploration Spectrum gives deliberation shape.
Local Analysis Mode gives deterministic verification.
Provenance gives the audit trail underneath all four.
```

That is the cognitive exoskeleton. Everything else in this repo is either supporting evidence or implementation detail.

---

**END OF READ_FIRST.md**
