# Archive Manifest — Cleanup Pass 2026-04-27

> **Status**: All 113 SUPERSEDED-HISTORICAL + TRANSIENT-CANDIDATE files exist in **both** their original `docs/` location AND in `docs/_archive/<cluster>/`. **Nothing was deleted.** The archive is for **concept-organized navigation**, not replacement.
> **Why both places**: legacy references in old docs still resolve at the original paths; the archive provides clean concept-grouped browsing.
> **Reference-fallback algorithm**: see `_consolidated/00_canonical_authority/MASTER_FUSION.md §0.1` — if a path is null at its stated location, search `_archive/` first, then `_consolidated/50_research_corpus/`, then surface as `[BROKEN-REFERENCE]`.

---

## Cluster summary

| Cluster | Files | What's inside |
|---|---|---|
| `plans_old/` | 32 | Older plan tree (predecessor of `docs/plan/`) — 2026-03-03 through 2026-03-28 design/implementation/audit plans |
| `google_research_packs/` | 17 | Pre-canonical Google research (2026-03-18); both agent + general packs combined |
| `architecture_handoffs/` | 16 | Phase handoffs (1-7) + canonicalization redos + transparency plans + master plan 04-19 + new session prompts; **PLAN_V2_UPDATED.md is here** (older variant; canonical PLAN_V2.md stays in architecture/) |
| `sessions_handoffs/` | 13 | One-off session reports + dated handoffs + transient session prompts (NEXT_SESSION, KF_CONTINUATION, handoff-prompt, etc.) |
| `audits_old/` | 8 | One-off audits superseded by canonical living logs (AUDIT_REPORT, V1_SCOPE_BOUNDARY, EPISTEMOS_FUSED_v3, IMPLEMENTATION_BLUEPRINT, etc.) |
| `sprint_sessions_old/` | 7 | Older sprint plans (sprint-agent-1/2/3/4, sprint-omega-2/5/6); `sprint-omega-1-foundation` kept in place (CANONICAL-OPERATIONAL per CLAUDE.md citation) |
| `theme_shipped/` | 6 | Theme refactor shipped per memory; all theme docs archived |
| `omega_retired/` | 5 | Omega system retired per IMPLEMENTATION_PLAN_FROM_ADVICE; OMEGA_*, CLAUDE_OMEGA, MASTER_SESSION_PROMPT |
| `kimi_goose_research/` | 5 | Kimi audit + Goose framework comparison; selection complete |
| `knowledge_fusion_old/` | 4 | KF system retired per IMPLEMENTATION_PLAN_FROM_ADVICE |

**Total**: 113 files (90 mass-archive + 23 referenced-but-still-archived-for-concept-browsing).

---

## Important: files exist in BOTH places

**Audit policy**: every file in `_archive/<cluster>/<filename>` is a **byte-identical copy** of the file at its original `docs/<original-path>/<filename>` location. To verify:

```bash
cmp -s "docs/<original-path>/<filename>" "docs/_archive/<cluster>/<filename>"
echo $?    # 0 = identical
```

**Why both places**:
- **Original locations preserved** so any reference in old docs (banners, plan-tree citations, prompt files, audit logs) still resolves
- **Archive copies** for concept-organized browsing — open `_archive/omega_retired/` to see all retired Omega docs in one place, instead of grepping the whole repo
- **No git history loss** — files retain their full git log at original paths; archive copies are fresh adds

---

## How to read an archived file

Every file (in both locations) carries a banner in its first 10 lines indicating:

- `SUPERSEDED-HISTORICAL` + name of the superseding doc
- OR `TRANSIENT-CANDIDATE` + reason it's transient

When you read an archived file, treat it as **historical context only**. If the banner names a superseder, follow that pointer instead.

---

## Files NOT in archive (canonical / canonical-research / canonical-operational / deferred-research)

These stay in their canonical locations only. Do NOT move them to `_archive/`:

- `docs/_consolidated/00_canonical_authority/*` (the spine)
- `docs/_consolidated/10_living_audits/*` (CANONICAL_AUDIT_LOG, CRITIQUE_LOG, etc.)
- `docs/_consolidated/20_canonical_research/*`
- `docs/_consolidated/30_canonical_operational/*`
- `docs/_consolidated/30_cli_integration/*`
- `docs/_consolidated/40_canonical_prompts/*`
- `docs/_consolidated/50_research_corpus/*` (research originals, organized by source)
- `docs/_consolidated/60_deferred_research/*`
- `docs/_consolidated/70_design_implementation/*`
- `docs/plan/*` (canonical plan tree)
- `docs/architecture/PLAN_V2.md` + `docs/architecture/README.md`
- `CLAUDE.md` (at repo root)
- All other files that DO NOT have a SUPERSEDED-HISTORICAL or TRANSIENT-CANDIDATE banner

---

## Reference-fallback algorithm (binding for all agents)

When you follow a reference path and the file is missing/null:

```
1. Read the path as written. If it exists, use it. Done.

2. If NOT found:
   a. Extract basename
   b. find docs/_archive -name "<basename>" -type f
   c. If exactly one match: use it. Note "archive-resolved" in audit.
   d. If multiple matches: prefer cluster matching original parent dir.
   e. If no archive match: search docs/_consolidated/50_research_corpus/
   f. If still no match: report [BROKEN-REFERENCE]. Do not guess.

3. Read banner (first 10 lines):
   - SUPERSEDED-HISTORICAL → follow "Superseded by:" pointer
   - TRANSIENT-CANDIDATE → context only
   - CANONICAL-* / DEFERRED-RESEARCH → still active
```

**Files canonical-class never appear in `_archive/`** — finding one there is drift.

---

## Provenance

| Date | Action |
|---|---|
| 2026-04-27 (cleanup) | Identified 113 SUPERSEDED+TRANSIENT files: 90 mass-safe-to-move + 23 referenced-from-canonical-text. Initial pass moved 90 to archive only. User clarified intent: archive copies for concept-browsing, but originals stay so old references resolve. Reversed the 90-move (sandbox blocked some `rm` operations, which incidentally enforced the desired both-places state). Copied the 23 referenced files to archive. **Final state: all 113 files exist in BOTH places.** Reference-fallback algorithm authored in `MASTER_FUSION.md §0.1`. |

---

**END OF MANIFEST.md**
