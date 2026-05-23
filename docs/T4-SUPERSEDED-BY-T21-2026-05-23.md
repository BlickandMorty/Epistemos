---
state: t4-superseded-by-t21
created_on: 2026-05-23
worktree: /Users/jojo/Downloads/Epistemos-wrv-salvage
main_head: 24b5052cf2
t4_branch: codex/t4-vault-2026-05-16
t4_head: 8cff8701fc
decision: do-not-salvage-code
---

# T4 Vault Recall Contract - Superseded by T21

## Decision

Do **not** mine `codex/t4-vault-2026-05-16:agent_core/src/retrieval/mod.rs`
into current main.

T4 contains real, tested Rust contract work, but it defines a second
retrieval authority under `agent_core::retrieval`. Current main already
has the T21 Vault Recall Contract wired through the production storage
path:

- `agent_core/src/storage/retrieval_trace.rs`
- `agent_core/src/storage/vault.rs`
- `agent_core/src/storage/f_vault_recall_runner.rs`
- `agent_core/src/storage/f_vault_recall_50_fixture.rs`
- `agent_core/src/tools/vault_search_ladder.rs`
- `agent_core/tests/f_vault_recall_50.rs`
- `agent_core/tests/vault_recall_bridge.rs`

Importing T4 would not be a small caller-chain improvement. It would add
a parallel trace / answerability model beside T21, then require a later
reconciliation pass to decide which contract owns vault recall.

## Donor-Mining Test

| Question | Result |
|---|---|
| Unique vs main? | **Partly, but not safely mineable.** T4 has unique shadow-first answerability, exact-escalation, residual-decode, MMR-selection, and `VaultContextTrace` helpers. The retrieval-contract slot itself is not unique: T21 is already the current canonical contract. |
| Pure-additive? | **File-additive only.** The module path is absent on main, but using it would require adding `pub mod retrieval` and then choosing callers. That creates a second retrieval API instead of extending the existing T21 path. |
| Compiles without dragging old architecture back in? | **Not accepted as a salvage target.** The isolated file is mostly data/logic, but its value depends on shadow-first / exact-escalation architecture that is not current production wiring. |
| Preserves current product doctrine? | **No.** Current doctrine is T21: `VaultBackend::hybrid_search_with_trace`, `RetrievalTrace`, F-VaultRecall runner, and lexical-only gap chips until semantic / graph / recency / MMR backends are real. |
| Spine-critical / adjacent / tangential? | **Spine-adjacent, superseded.** The problem is spine-critical; the T4 implementation is a superseded parallel design. |

## Audit

### What Exists on T4

T4 adds `agent_core/src/retrieval/mod.rs` and exports it from T4's
`agent_core/src/lib.rs` as `pub mod retrieval;`.

The file is substantial and includes:

- `VaultInventorySnapshot`
- `VaultRetrievalMode`
- `VaultSignalKind`
- `VaultCandidateTrace`
- `VaultContextTrace`
- `ShadowFirstTrace`
- `ShadowFirstDecision`
- exact-escalation request / hit / outcome types
- residual-decode request / hit / outcome types
- `required_candidate_pool`
- `recency_half_life_decay`
- `shadow_first_decision`
- `shadow_first_top_score_margin`
- `mmr_select_indices`
- inline unit tests for empty input, non-finite scores, provenance
  visibility, exact-verification matching, residual summaries, MMR edge
  cases, and synthesis/adversarial validation.

T4 also carries `agent_core/tests/vault_recall_baseline.rs`, but that
test is ignored and requires a local user vault path. It is a baseline
report generator, not current CI proof.

### What Exists on Current Main

Current main already wires the T21 path through production Rust callers:

- `VaultBackend::hybrid_search_with_trace` exists as the trace-emitting
  trait method.
- `VaultStore::hybrid_search` delegates to its traced implementation,
  preserving the old result-list API while making trace emission the
  single implementation body.
- `RetrievalTrace` carries the five canonical T21 signal names:
  lexical, semantic, graph, recency, and MMR.
- `RetrievalTrace::evidence_strength()` classifies weak / moderate /
  strong evidence and forces all-chatter fallback to weak.
- `RetrievalTrace::has_only_lexical_signals()` marks the current Q2 gap
  honestly: current backends emit lexical only until real semantic /
  graph / recency / MMR pipelines are wired.
- `FVaultRecallRowOutcome`, `run_row`, `run_all`, and `summarize`
  bridge fixture rows to any `VaultBackend`.
- `vault_search_ladder.rs` owns the current `vault.search` ladder and
  documents the Q1 BM25-floor recalibration gap.

### Fixture / Stub / Status-Only

- T4 `vault_recall_baseline.rs`: ignored local-vault report generator.
- T4 `agent_core::retrieval`: real library code, but no current main
  production caller.
- Main T21: real Rust caller chain in storage, tests, fixture runner,
  and ladder; Swift / UI visibility remains downstream per
  `docs/F_VAULT_RECALL_50_2026_05_18.md`.

### Production Caller Chain

Current Rust caller chain:

`VaultSearchHandler / storage callers -> VaultBackend::hybrid_search`
`-> VaultStore::hybrid_search_with_trace -> RetrievalTrace`

Diagnostics/falsifier chain:

`F_VAULT_RECALL_50_FIXTURE -> run_row ->`
`VaultBackend::hybrid_search_with_trace -> FVaultRecallRowOutcome ->`
`summarize`

No current main caller chain reaches T4's `agent_core::retrieval` module.

## WRV Classification

T21 retrieval contract: **current-wired** in Rust, with visible Swift/UI
surfaces still downstream.

T4 salvage candidate: **implemented-not-wired / superseded**.

T4 is not WRV-ready:

- **Wired:** no, absent from current main.
- **Reachable:** no, unless a new `pub mod retrieval` and callers are
  added.
- **Visible:** no, no current UI or diagnostics consumer.
- **Verified:** T4 has unit tests, but the current product verifier is
  T21's F-VaultRecall suite.

## Hardening Notes

T4's inline tests cover many important edge cases: empty query, zero
limit, non-finite scores, missing visible evidence, ambiguous top
margin, exact-verification mismatch, residual summary normalization,
bounded snippets, and MMR non-finite inputs.

Those hardening ideas should be treated as reference material for future
T21 work only. If a future T21 loop needs exact-escalation or MMR
selection, port the specific behavior into the existing
`storage::retrieval_trace` / `storage::vault` / `f_vault_recall_runner`
spine with a failing T21 test first. Do not introduce
`agent_core::retrieval` as a parallel namespace.

## Verification Performed

Read/audit commands:

```bash
git rev-parse --short HEAD
git rev-parse --short origin/main
git rev-parse --short codex/t4-vault-2026-05-16
git ls-tree -r --name-only codex/t4-vault-2026-05-16 agent_core/src agent_core/tests
rg --files agent_core/src agent_core/tests
rg 'retrieval_trace|RetrievalTrace|FVaultRecall|hybrid_search_with_trace|vault_search_ladder' agent_core/src agent_core/tests Epistemos EpistemosTests
git show codex/t4-vault-2026-05-16:agent_core/src/retrieval/mod.rs
git show codex/t4-vault-2026-05-16:agent_core/tests/vault_recall_baseline.rs
```

Narrow verification for the decision doc:

```bash
test -f docs/T4-SUPERSEDED-BY-T21-2026-05-23.md
rg 'agent_core::retrieval|do not mine|superseded|current-wired|implemented-not-wired' docs/T4-SUPERSEDED-BY-T21-2026-05-23.md
```

## Final Status

M1 is closed as a **decision / archive** unit. No T4 code should be
mined. The preserved T4 branch remains useful as reference material, but
T21 is the current vault recall spine.
