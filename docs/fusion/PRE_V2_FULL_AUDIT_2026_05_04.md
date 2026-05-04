# Pre-V2 full audit — 2026-05-04

User-requested comprehensive audit before signaling `RESUME SUBSTRATE V2`.
4 parallel Explore agents covered: doctrine docs, salvage tree, memory
entries, code/build state. This doc is the synthesis after personally
verifying each agent's most consequential claims.

**Bottom line**: 5 real gaps that should close before V2.1 starts. None
are catastrophic. Two are about hygiene (uncommitted work, stale CLAUDE.md
numbers); three are about substrate continuity (Lane A's
session_insights.rs orphan, untriaged salvage, stale memory entries). The
recovery doctrine itself is coherent — Stages A-F closed cleanly.

---

## Verified ground truth

| Claim source | Claim | Verified | Verdict |
|---|---|---|---|
| CLAUDE.md | Swift 137K LOC | **251,595** | CLAUDE.md is 84% under-reported |
| CLAUDE.md | Rust 94K LOC | **71,417** | CLAUDE.md is 24% over-reported |
| CLAUDE.md | 2,679-test Swift suite | **346 test files** (test count not measured) | needs re-verification |
| CLAUDE.md | 770 agent_core tests | 695 lib tests + integration suites | partially correct |
| Recovery summary | Hermes-in-Rust 15 tests pass | **15 pass, 0 fail** | ✓ correct |
| Recovery summary | TEMP-FREE-TIER exactly 4 hits | **4 hits in entitlements file only** | ✓ correct |
| Recovery summary | Hermes-in-Rust 6 modules / 737 LOC | **737 LOC, 6 modules confirmed** | ✓ correct |
| Recovery summary | AFM in 6 in-process call sites | **6 sites confirmed** | ✓ correct |
| Recovery summary | GenUIDispatcher.swift exists with typed switch | **exists at Engine/GenUIDispatcher.swift** | ✓ correct |
| Recovery summary | GENUI-DEFER markers in code | **0 hits in `Epistemos/`** | doctrine references markers but they're not in source |

**Build state (just verified)**:
- xcodebuild Epistemos macOS: BUILD SUCCEEDED
- agent_core lib tests: 695 pass, 0 fail
- Hermes-in-Rust integration tests: 15 pass, 0 fail

---

## Gap 1 — 9,947 lines of uncommitted work in 366 source files (HIGH)

**Finding**: `git status` shows 380 modified files in the working tree
(385 total including 5 LocalPackages + 3 untracked). Excluding build
artifacts, that's 366 source files with **+9,947 / -836 lines** uncommitted.

**Distribution**:
- `docs/` 139 files
- `docs/plans/` 33 files
- `docs/architecture/` 26 files
- `docs/handoffs/` 20 files
- `agent_core/src/tools/` 17 files
- `agent_core/src/` 13 files (top-level)
- `epistemos-shadow/src/backend/` 4 files
- `graph-engine/src/` 9 files (incl. `knowledge_core/store.rs` +808 lines)

These pre-date this recovery loop — the original `git status` at session
start showed similar counts. Most appear to be Codex / Kimi / fleet-agent
work-in-progress that hasn't been triaged into clean commits.

**Risk for V2.1**: V2.1 will modify many of the same files (especially
`agent_core/src/`). If the uncommitted work isn't committed or stashed
first, V2.1 commits will entangle with it and the diff history becomes
unreadable.

**Recommended action before V2.1**:
1. `git diff --stat -- agent_core/ graph-engine/ epistemos-shadow/` and
   triage what's intentional vs editor-leftover
2. Either `git commit -am "WIP: pre-V2 in-flight"` to a separate branch
   for review, or `git stash push -m "pre-V2 in-flight"`
3. Confirm a clean `git status` before signaling RESUME SUBSTRATE V2

---

## Gap 2 — Lane A's `session_insights.rs` is orphan code (HIGH)

**Finding**: `docs/fusion/salvage/from-lane-a/session_insights.rs` (625
LOC) is the only Rust module salvaged from Lane A's 601 unmerged commits.
Per CANONICAL_AUDIT_LOG.md, it was supposed to ship as a `pub mod
session_insights;` declaration in `agent_core/src/lib.rs` to unblock N1
(Prompt Tree cache telemetry) + W9.6 (cost dashboard).

It never landed. `grep -rn 'session_insights' Epistemos/ agent_core/`
returns one stale comment. The file sits in salvage but isn't compiled.

**Risk for V2.1**: V2.1 (DAG Phase 8) needs claim provenance — what tools
ran, in what order, with what cost. The current `agent_core` has
`provenance/ledger.rs` (Phase 1) but no cost-per-step telemetry.
Re-implementing without consulting `session_insights.rs` would be
duplicate work.

**Recommended action before V2.1**:
- Read `from-lane-a/session_insights.rs` (625 lines) to decide: integrate
  as `pub mod session_insights;` in `agent_core/src/lib.rs`, OR fold its
  ideas into the DAG Phase 8 schema
- Document the decision in `QUICK_CAPTURE_SALVAGE_TRIAGE` (currently only
  covers `from-vigorous-goldberg/`)

---

## Gap 3 — 6 of 7 salvage subdirs untriaged (MEDIUM)

**Finding**: I shipped `QUICK_CAPTURE_SALVAGE_TRIAGE_2026_05_04.md` for
`from-vigorous-goldberg/` (5,656 LOC). The other 6 salvage directories
have no triage doc:

| Dir | Volume | Untriaged content |
|---|---|---|
| `from-lane-a/` | 94 files | PROMPT_AS_DATA_SPEC.md (272 lines, N1 spec), session_insights.rs (Gap 2 above), 92 architecture docs from 601 unmerged commits |
| `from-hermes-parity/` | 3 files | HERMES_PARITY_AUDIT_REPORT.md (23K, 76% parity vs Hermes 0.6.0), PHASE9_AUDIT.md (15.8K), SKILL_PORTING_GUIDE.md (76.5K — 21 Hermes tools porting spec) |
| `from-codex-runtime-input-audit/` | 2 files | 324-commit list + 1,369-line diff-stat, dated 2026-04-24 |
| `from-simulation/Hermes-UI/` | 5 files | AsciiPortraitView, HermesGoldHaloView, HermesLandingPhases, HermesLandingRitualView, HermesSession (likely dead code) |
| `from-simulation/reference-code/` | 4 files | compaction.rs, prompt_caching.rs, security.rs, think.rs (reference implementations) |
| `from-stashes/` | 2 files | stash-1 (1,276 lines), stash-2 (17,964 lines) — patch headers not analyzed |
| `from-agent-a0550f9c/` | 1 file | CANONICAL_AUDIT_LOG.md |

Total untriaged: ~21,000+ lines of patches + 100K+ of audit reports.

**Risk for V2.1**: `SKILL_PORTING_GUIDE.md` likely names tools V2.1 would
either port or supersede. `HERMES_PARITY_AUDIT_REPORT.md` claims 76%
parity at 22 vs 37 tools — V2.1's tool surface decisions should reference
this audit, not re-derive it.

**Recommended action before V2.1**:
- Spend ~30 minutes triaging each remaining salvage subdir into the
  same Tier A/B/C/D buckets as `from-vigorous-goldberg/`
- Single follow-on doc: `SALVAGE_TRIAGE_REMAINDER_2026_05_05.md`
- Patch headers from stashes can be summarized without reading full
  diffs (header alone reveals scope)

---

## Gap 4 — Memory entries stale or missing for 5 new doctrines (MEDIUM)

**Finding** (Agent 3): Major doctrine docs from May 3-4 recovery have NO
memory entry:
- `HERMES_BRAND_DOCTRINE_2026_05_04.md` (canonical brand identity gate)
- `CODEX_RECOVERY_HANDOFF_2026_05_04.md` (Codex's read-first list)
- `HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md` (forward-compat discipline)
- `PROVENANCE_CONSOLE_DOCTRINE_2026_05_04.md` (MAS feature trio third piece)
- `QUICK_CAPTURE_SALVAGE_TRIAGE_2026_05_04.md` (4-tier triage doc)

Plus stale memory:
- `project_hackathon_focus_2026_05_03.md` (21:15 same day) was overtaken by
  `project_canonical_recovery_plan_2026_05_03.md` (23:56) when the user
  abandoned the hackathon. Stale memory still says "prioritize hackathon."
- `project_canonical_recovery_plan_2026_05_03.md` claims `agent_core::hermes`
  doesn't exist — it shipped same day at 10:01 (Codex's recovery push
  ad6280cf). Memory written before the module existed.

**Risk for V2.1**: Future sessions starting fresh will not know about the
new doctrines unless they read all of `docs/fusion/` from scratch — slow
and lossy. Stale memories will actively mislead.

**Recommended action before V2.1**:
- Delete or rewrite `project_hackathon_focus_2026_05_03.md`
- Update `project_canonical_recovery_plan_2026_05_03.md` to say the hermes
  modules shipped (and reference commit ad6280cf)
- Add 5 new memory entries (one per missing doctrine), each ≤150 chars
  summary + pointer to the doc

---

## Gap 5 — CLAUDE.md statistics drift + GENUI-DEFER markers absent (LOW-MEDIUM)

**Finding**:
- CLAUDE.md says "137K Swift LOC, 94K Rust LOC, 370 Swift files, 99 Rust
  files, 115 test files, 2,679-test suite". Actual: **251,595 Swift LOC,
  71,417 Rust LOC, 346 Swift test files** (test count itself not
  measured against 2,679).
- `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` defines `GENUI-DEFER:` markers
  for explicit deferral tracking. `grep -rn 'GENUI-DEFER' Epistemos/`
  returns **0 hits**. The doctrine's deferral tracking has no in-code
  enforcement.

**Risk for V2.1**: CLAUDE.md is loaded into every session as ground
truth. Stale numbers → wrong context → wrong-sized estimates. Missing
GENUI-DEFER markers → deferral list integrity drifts silently.

**Recommended action before V2.1**:
- Run `find Epistemos -name '*.swift' | wc -l` + `find Epistemos -name
  '*.swift' -exec wc -l {} + | tail -1` and update CLAUDE.md
- Either add GENUI-DEFER markers in source per the doctrine's deferral
  list rows, OR amend the doctrine to acknowledge the markers are
  doc-only

---

## What is NOT a gap (verified)

- **Recovery sequence Stages A-F**: closed cleanly per
  `RECOVERY_LOOP_FINDINGS_2026_05_04.md`
- **Wait-for-signal contract**: coherent. Recovery plan + V2 plan agree
  on `RESUME SUBSTRATE V2` trigger
- **Five-question PR discipline**: canonical at
  `CANONICAL_RECOVERY_PLAN_2026_05_03.md` §2 (Agent 1 reported it
  missing — actually present, just not in a doctrine doc by that name)
- **TEMP-FREE-TIER restoration trail**: exemplary, contract-honored
- **MAS-vs-Pro gating**: defense-in-depth (3 layers around iMessage,
  customToolsCard fixed this loop)
- **Hermes-in-Rust scaffold**: 15 tests green
- **Capability lattice cross-runtime parity**: pinned by 2 contract
  tests (Stage B.3)

---

## Suggested ordering before signaling RESUME SUBSTRATE V2

1. **Today** (low effort, high value):
   - Update CLAUDE.md statistics (Gap 5)
   - Decide on `project_hackathon_focus_2026_05_03.md` (delete vs annotate) (Gap 4)
   - Decide on uncommitted work (commit / stash / leave) (Gap 1)

2. **Within 1 day**:
   - Read `from-lane-a/session_insights.rs` + decide its V2 fate (Gap 2)
   - Triage remaining 6 salvage subdirs (Gap 3)
   - Add 5 new memory entries for the missing doctrines (Gap 4)

3. **Optional polish**:
   - Add GENUI-DEFER markers per the doctrine's deferral list (Gap 5)

After (1) + (2) clear, the substrate is ready for V2.1. Helios v3 +
SCOPE-Rex remains the V3 ultimate goal — these gap closures protect the
V3 path from silently inheriting substrate debt.

---

## Trust-but-verify reminders

The 4 parallel Explore agents had 3 false-positive findings worth
noting (fixed in this synthesis):
- Agent 1 claimed GenUIDispatcher.swift doesn't exist — it does
- Agent 1 claimed five-question PR discipline isn't in canon — it is
- Agent 4 claimed 0 Swift test files — there are 346 (wrong grep pattern)

The agents' true-positive findings (uncommitted work, GENUI-DEFER absent
from code, missing memories, untriaged salvage) all verified.
