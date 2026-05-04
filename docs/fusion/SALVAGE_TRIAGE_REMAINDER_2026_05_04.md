# Salvage triage — remaining 6 subdirs (2026-05-04)

Companion to `QUICK_CAPTURE_SALVAGE_TRIAGE_2026_05_04.md` (which covered
`from-vigorous-goldberg/`). Closes Gap 3 of `PRE_V2_FULL_AUDIT_2026_05_04.md`.

The 6 remaining salvage subdirs categorized into the same A/B/C/D
integration tiers + recommended landing order. Some findings are
**newly-elevated to V2.1 blockers** by this triage (especially the
agent-a0550f9c CANONICAL_AUDIT_LOG findings that surface Doctrine §3
Retraction Propagation as missing).

---

## Tier A — V2.1 informs / blockers

### `from-agent-a0550f9c/CANONICAL_AUDIT_LOG.md` (76,848 bytes, dated 2026-04-26)

**This is the single most important untriaged document.** A 47-item
audit (3 Bucket A, 7 Bucket B, 5 Bucket C, 7 Bucket D, 1 Bucket N, 12
D-series, 9 gap-fixes, 3 pre-TestFlight) with **17 BLOCKERS, 19
WARNINGS, 6 NOTES**. Most findings still open.

**V2.1 keystone finding — Doctrine §3 Retraction Propagation does
not exist in code.** Zero hits for `MutationEnvelope`,
`ProposedEnvelope`, `ClaimLedger`, `RetractionPropagated`,
`provenance/ledger` in earlier searches. **V2.1 (Cognitive DAG Phase
8) cannot land without this primitive** — it is the doctrine's named
contribution. The recovery loop's commit `2ca663a1` landed
graph-engine `MutationRelationKind` enum + supporting infrastructure
which is the precursor; the full Mutation Envelope + ClaimLedger
needs to land in V2.1 Phase 8.A.

**Other open V2.1-relevant findings:**
- W9.27 OpLog: schema missing `prev_hash` column for D1 BLAKE3 chain
- D2 7-verb MCP graph boundary: actual `omega-mcp/src/vault.rs`
  exports the wrong tool surface (read_file / write_file / list_files
  / search_notes / execute_vault_tool — none of the 7 specified verbs
  exist)
- D3 closed A2UI catalog: doesn't exist anywhere
- D5 substrate durability: no `PRAGMA journal_mode = WAL`, no
  `fcntl(F_FULLFSYNC)` in oplog or vault
- Faculty roster D4: ships 36B model on 16GB hardware ceiling
  (memory-budget violation hidden under different model ID)

**Findings already addressed since 2026-04-26:**
- Build-matrix nomenclature: `EPISTEMOS_PRO` → mostly canonicalized;
  recovery commit `2ca663a1` flipped security.rs to use `pro-build`
  feature gate per MAS_FIRST_FOCUS_DOCTRINE
- W9.21 Honest FFI: doctrine doc `HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md`
  shipped (commit `ad6280cf` and earlier); Swift consumer migrations
  still pending per W9.21 PR3+

**Recommended action for V2.1**: Lift the CANONICAL_AUDIT_LOG into
the V2.1 Phase 8 sub-plan as the canonical "open blockers" list.
Each blocker maps to a Phase 8 deliverable.

### `from-lane-a/PROMPT_AS_DATA_SPEC.md` (272 lines)

N1 spec — JSPF + PTF (JSON-Schema Prompt Format + Prompt Tree Format).
Foundation shipped under `EPISTEMOS_PROMPT_TREE=1` feature flag;
default-on cutover gated on ≥30% measured cache-hit rate over a
two-week bake window. Authority: subordinate to PLAN_V2.md, CLAUDE.md,
MASTER_BUILD_PLAN.md.

**Status check (verified 2026-05-04):** `Epistemos/Engine/PromptTree.swift`
exists (per the spec's claimed location). N1 cache-hit telemetry was
flagged as "blocked on substrate fix" in `CANONICAL_AUDIT_LOG` —
needs follow-up to see if substrate fix landed.

**Recommended action**: Read in full when V2.1 work touches prompt
construction. The spec is canon, just under a feature flag pending
the bake-window data.

### `from-lane-a/session_insights.rs` (625 LOC) — VERIFIED ALREADY INTEGRATED

Agent 2's earlier finding (claimed orphan code blocking N1) was wrong.
Verified 2026-05-04: `agent_core/src/session_insights.rs` exists in
main with 672 LOC (evolved beyond the salvage version's 625) and is
declared `pub mod session_insights;` at `agent_core/src/lib.rs:37`.
The recovery commit `2ca663a1` landed an additional 83-line evolution.

**No action required.** The salvage copy can be deleted as redundant.

---

## Tier B — Reference material for V2.1 tool decisions

### `from-hermes-parity/HERMES_PARITY_AUDIT_REPORT.md` (23K, dated 2026-04-09)

Comprehensive Rust agent_core vs Hermes Python (v0.6.0) comparison.
**Overall parity: 76%**. Per-area scores:
- Core agent loop: 85%
- Error handling: 90%
- Provider infrastructure: 75%
- Security: 65%
- Session persistence: 80%
- Tool ecosystem: 70% (22 Rust tools vs 37 Hermes tools)
- Context management: 70%

Key V2.1-relevant gaps:
- Smart approval LLM guard (security 65%)
- Context compression depth + iterative summary updates (context 70%)
- 15 missing tools (browser automation, MCP servers, voice/TTS, image
  generation, delegate subagent, RL training)
- Nous Portal OAuth, Codex OAuth adapter, custom endpoint auto-detection

**Recommended action for V2.1**: Reference this audit when prioritizing
which Hermes tools to port (vs supersede). Stage B.1 (Hermes-in-Rust)
shipped scaffolding for prompt format / function call / skills /
procedural memory / self-evolution; full tool surface expansion is
post-V2.1.

### `from-hermes-parity/PHASE9_AUDIT.md` (15.8K)
Phase 9 specific audit. Less critical than the parity report; reference
material when Phase 9 work is on the table.

### `from-hermes-parity/SKILL_PORTING_GUIDE.md` (76.5K)
Comprehensive guide for porting Hermes skills (21 modules). Read when
implementing Stage B.1 follow-on work or post-V2.1 tool expansion.

---

## Tier C — Mostly superseded reference material

### `from-lane-a/` 92 architecture docs (dated 2026-04-07 to 2026-04-23)

Most architecture docs are superseded by the current `docs/fusion/`
canon docs. Spot-check before deleting:
- `STATE_OF_SYSTEM.md` — likely superseded by recent recovery findings
- `RELEASE_READINESS_AUDIT.md` — risk register; may have unique items
- `AGENT_RUNTIME_ARCHITECTURE.md` — superseded by kernel doctrine
- `RESEARCH_PROMPT.md` — historical; reference only
- `CLAUDE_IMPLEMENTATION_AUDIT.md` + `_V2.md` — historical
- `BENCHMARK_*` files — historical baselines; benchmarks/results/
  in main is current

**Recommended action**: Spot-check 5 docs for unique findings; delete
the rest as historical. Defer to a future archival pass.

### `from-codex-runtime-input-audit/` (commit-list.txt + diff-stat.txt)

324 commits dated 2026-04-24. Diff stats show MASSIVE per-file changes
(ChatCoordinator +7168, AppBootstrap +1010, RootView +1277) — these
look like accumulated ChatCoordinator + RootView refactoring that has
since been merged into main piecemeal.

**Recommended action**: `git log --oneline | grep -f commit-list.txt`
to identify which commits actually made it into main (vs were rolled
back vs are duplicated under different SHAs in main). Defer to a
focused 1-hr triage session; not V2.1 blocking.

### `from-stashes/stash-2-wip-on-main-31214a4d.patch` (17,964 lines)

Massive WIP stash. Header shows it includes:
- Xcode AppStore scheme renames (Epistemos.app → Epistemos-AppStore.app)
- syntax-core/target gitignore addition
- Likely much more

**Recommended action**: This stash is so large (17K lines) that
inspecting it in full is its own project. Most of its scheme work
likely landed via subsequent commits. Defer to a focused triage; if
the user has lost work concerns, audit by file path against current
state.

---

## Tier D — Dead code / Pro-only

### `from-simulation/Hermes-UI/` (5 Swift files)

Landing/ritual UI scaffolding (AsciiPortraitView, HermesGoldHaloView,
HermesLandingPhases, HermesLandingRitualView, HermesSession). No
consumer in main. Likely superseded by current
`Epistemos/Views/Landing/Hermes/` (HermesShimmeringSigil + HermesBrand
+ HermesExpertModeView).

**Recommended action**: Read each file's preamble; if any contain
Canvas drawing techniques the current Hermes UI doesn't, port the
technique. Otherwise mark as historical reference.

### `from-simulation/reference-code/` (4 Rust files + INTEGRATION_GUIDE.md)

Reference implementations of compaction / prompt_caching / security /
think. The current `agent_core/src/{compaction,prompt_caching,security,
tools/think}.rs` may already incorporate these — just-shipped commit
`2ca663a1` added 242 lines to security.rs which may have come from
this reference.

**Recommended action**: Spot-diff `from-simulation/reference-code/security.rs`
against `agent_core/src/security.rs` to check coverage. If reference
has unique safety patterns, port them.

### `from-stashes/stash-1-codex-wip-parallel.patch` (1,276 lines)

Smaller stash; XcodeProj scheme work. Most likely already in main as
the AppStore scheme is currently working.

**Recommended action**: Cross-reference the file paths against current
state; delete if all addressed.

---

## Acceptance bar

- [x] All 6 untriaged subdirs categorized into A/B/C/D tiers
- [ ] CANONICAL_AUDIT_LOG findings lifted into V2.1 Phase 8 sub-plan
      (this is the critical follow-up before V2.1 starts)
- [ ] Lane A historical doc archival pass (defer 1 day)
- [ ] from-codex-runtime-input cross-reference against main (defer 1 day)
- [ ] from-stashes file-path-vs-current-state audit (defer 2 days)

The salvage tree under `docs/fusion/salvage/` stays read-only. Don't
import from the salvage path at compile time — copy into the canonical
source tree only when integrating a Tier A or Tier B slice.

---

## Cross-reference for V2.1 prep

When the user signals `RESUME SUBSTRATE V2`:

1. Open `from-agent-a0550f9c/CANONICAL_AUDIT_LOG.md` and lift the
   17 BLOCKER findings into the V2.1 Phase 8.A sub-plan
2. Verify Doctrine §3 Retraction Propagation primitive is the first
   Phase 8.A deliverable (per the audit it's the keystone)
3. Reference `from-hermes-parity/HERMES_PARITY_AUDIT_REPORT.md` when
   Phase 8 touches the agent loop / context compression
4. The `from-vigorous-goldberg/` Tier A modules (format / canon /
   grammar / undo) remain integration-ready throughout V2.1
