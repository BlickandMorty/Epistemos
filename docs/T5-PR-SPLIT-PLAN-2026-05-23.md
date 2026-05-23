# T5 EML-IR — PR Split Plan (2026-05-23)

`codex/t5-emlir-2026-05-16` is **961 commits ahead of main** and carries
a 6-IR Lean+Rust stack. It cannot land as a single PR. Per
`/tmp/audit/02_may16_cycle.md` line 88-104 and the canon's "T5 stays
scope-locked" guidance (HANDOFF:92-93), the merge sequence below splits
the work into independently-verifiable, monotonically-mergeable PRs.

**Pre-condition for any T5 cherry-pick.** `agent_core/src/research/eml/`
is **already on main** (landed via T12 F-ULP Oracle). Cherry-picking
T5's `eml/` would conflict; this plan skips that path and addresses the
**five IRs absent on main**: `tropical_ir`, `scan_ir`, `operator_ir`,
`info_ir`, `geometry_ir`. Plus the Lean schemas live in
`research_custody/<ir>/`.

---

## PR sequence

Each PR is independently cargo+xcodebuild verified, lands behind no
feature flag (research feature already gates the surface), and is
merged with the CI bypass per the user override.

| Order | PR title | Branch | Files (truly-new + absent on main) | Verify |
|---|---|---|---|---|
| 1 | `feat(t5/operator-ir): land Operator-IR primitive` | `salvage/T5-operator-ir-2026-05-23` | `agent_core/src/research/operator_ir/{mod,grammar,evaluator,certificate,fourier_kernel}.rs` + custody (`research_custody/operator_ir/`) | `cargo test --features research --lib operator_ir` |
| 2 | `feat(t5/scan-ir): land Scan-IR primitive` | `salvage/T5-scan-ir-2026-05-23` | `agent_core/src/research/scan_ir/{mod,grammar,evaluator,certificate,semiseparable_block_scan}.rs` + custody | `cargo test --features research --lib scan_ir` |
| 3 | `feat(t5/tropical-ir): land Tropical-IR primitive` | `salvage/T5-tropical-ir-2026-05-23` | `agent_core/src/research/tropical_ir/{mod,grammar,evaluator,certificate,…}.rs` + custody | `cargo test --features research --lib tropical_ir` |
| 4 | `feat(t5/info-ir): land Info-IR primitive` | `salvage/T5-info-ir-2026-05-23` | `agent_core/src/research/info_ir/{mod,grammar,evaluator,certificate,mirror_descent}.rs` + custody | `cargo test --features research --lib info_ir` |
| 5 | `feat(t5/geometry-ir): land Geometry-IR primitive` | `salvage/T5-geometry-ir-2026-05-23` | `agent_core/src/research/geometry_ir/{mod,grammar,evaluator,certificate,rotor}.rs` + custody | `cargo test --features research --lib geometry_ir` |
| 6 | `feat(t5/cross-ir): cross-IR coercion + corpus round-trip` | `salvage/T5-cross-ir-2026-05-23` | `agent_core/tests/cross_ir_*` + `agent_core/tests/eml_ir_corpus_round_trip.rs` | `cargo test --features research --lib cross_ir` |
| 7 | `docs(t5): Phase A closeout (8/8 already-closed)` | `salvage/T5-docs-phase-a-2026-05-23` | `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE*.md`, `docs/fusion/PHASE_A_CLOSEOUT*.md`, `docs/fusion/PHASE_B1_CLOSEOUT*.md`, `docs/fusion/EML_IR_AUDIT*.md` | docs only |
| 8 | `docs(t5): Lean schemas under research_custody` | `salvage/T5-lean-custody-2026-05-23` | 12 `.lean` files + `research_custody/<ir>/{claims.yaml,hashes/SHA256SUMS,verification_status.md}` | `lake build` (deferred — needs Lean toolchain) |

**Total**: 8 sequential PRs. Each is gate-able on its own cargo test target.

---

## Why this ordering

- **PRs 1-5 are independent IRs**: any order is correct, but the
  `02_may16_cycle.md` audit names `operator_ir` and `scan_ir` as the
  most-tested primitives at iter-950 — pick them first to discover any
  shared-helper coupling early.
- **PR 6 (cross-IR)** lands AFTER all 5 individual IRs because the
  corpus round-trip test exercises every primitive.
- **PRs 7-8 (docs + Lean custody)** trail the code so the docs ↔ code
  cross-links are valid against landed paths.

---

## Pre-cherry-pick blockers (per audit doc)

1. `EML-LEAN-VENDOR` open blocker (`tomdif/eml-lean` not vendored) — affects PR #8 (Lean custody). Until vendored, PRs 1-7 ship without Lean parity.
2. Carney inexpressibility citation gap in Phase A §5.0 — affects PR #7 (docs) accuracy, not buildability. Document the gap in the PR body; do not block on it.
3. T7 `eml_integration/` is on a separate salvage track (Phase C item) — it depends on `research/eml/` on main, NOT on these T5 IRs, so PR ordering between T5 and T7 is independent.

---

## How a salvage PR is constructed (template)

For each IR (PRs 1-5):

```
git checkout -b salvage/T5-<ir>-ir-2026-05-23 origin/main
git checkout origin/codex/t5-emlir-2026-05-16 -- \
  agent_core/src/research/<ir>_ir/ \
  research_custody/<ir>_ir/   # if directory exists
cargo check --manifest-path agent_core/Cargo.toml --lib --features research
cargo test --manifest-path agent_core/Cargo.toml --features research --lib <ir>_ir
# verify xcodebuild green (no Swift changes expected)
git commit -m "feat(t5/<ir>-ir): land <Name>-IR primitive from codex/t5-emlir-2026-05-16"
git push -u origin salvage/T5-<ir>-ir-2026-05-23
gh pr create --title "..." --body "..."   # CI-bypass note in body
gh pr merge --merge --admin
```

---

## What this plan does NOT cover

- The `research/eml/` substrate is already on main via T12; no T5 PR
  re-introduces it.
- T5's 28 `sorry`s in Lean are budget-gated per the substrate contract;
  they ship as-is and are not "blockers" for the merge.
- T7 (Deep EML) is a separate Phase C salvage track that depends on
  `research/eml/` on main; the T5 split does NOT block T7.
