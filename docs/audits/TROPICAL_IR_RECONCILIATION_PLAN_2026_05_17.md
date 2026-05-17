# Tropical-IR Reconciliation Plan — 2026-05-17 (Terminal T5, Phase A iter-6)

**Issue:** §4.I SCOPE LOCK + driver-prompt-T5 require a NEW
`agent_core/src/research/tropical_ir/` directory module. An existing
flat `agent_core/src/research/tropical.rs` (594 LOC, 28 tests) — landed
under Wave J Phase B.6.15 as the "Tropical-Affine completeness
substrate" — predates that scope. Flagged in iter-1 audit §9.1 as the
only motion-risk item before Phase B2 begins.

**Decision (user-confirmed via meta-message + iter-1 audit Option B):**
Move + re-export. The flat file becomes a thin shim that re-exports
the new module's public surface so existing call sites stay valid
across the migration.

**Authority chain:**
- §4.I:864 — names `agent_core/src/research/tropical_ir/` as the
  NEW module location for Tropical-IR.
- iter-1 audit (`docs/audits/EML_IR_AUDIT_2026_05_17.md`) §9.1 —
  Option B (Move + re-export) was the recommended path.
- User meta-message (this session) — confirmed Option B
  ("move tropical.rs into tropical_ir/ then re-export from the
  original path so nothing breaks").

This document is a **plan**, not an execution. The move itself happens
at Phase B2 entry slice (iter 9+). Iter-6 lands the plan + the
risk/rollback bookkeeping so the eventual move is mechanical.

---

## 1. Current state inventory

`agent_core/src/research/tropical.rs` (594 LOC). Public surface:

| Item | Kind | Line |
|---|---|---:|
| `TropicalMonomial { coeffs, bias }` | struct | 43-47 |
| `TropicalPolynomial { … }` | struct | 52-? |
| `TropicalError` | enum | 58 |
| `tropical_add(a, b)` | fn | 124 |
| `tropical_mul(a, b)` | const fn | 131 |
| `relu_as_tropical_polynomial()` | fn | 191 |
| `relu_layer_as_tropical(…)` | fn | 218 |

**Tests:** 28 `#[test]` attributes.

**External call sites:** **none.** Only `agent_core/src/research/mod.rs:45`
declares `pub mod tropical;`. A repo-wide grep
`grep -rn "research::tropical\|crate::tropical" agent_core/src/ --include="*.rs"`
returns **zero** non-self matches. This makes the move risk-free at
the API level.

**Cited primary sources** (header `//!` block):
- Zhang, Naitzat, Lim — *Tropical Geometry of Deep Neural Networks*,
  ICML 2018, arXiv:1805.07091. ✅ matches `research_custody/tropical/claims.yaml`
  entry `zhang-naitzat-lim-tropical-nn`.
- Maclagan & Sturmfels — *Introduction to Tropical Geometry*, AMS
  GSM 161, 2015. ⚠️ **NOT IN** `research_custody/tropical/claims.yaml`
  as of iter-5. Add at next claims-population pass (see §6 follow-up).
- HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md §"Terminal B"
  Phase B.6.15 — Wave J substrate context.

**Note:** the `research_custody/tropical/claims.yaml` (iter-5) cites
Charisopoulos/Maragos arXiv:1805.08749 as the second primary source
for Tropical-IR; the existing file's header cites Maclagan-Sturmfels
instead. Both are correct — they're different parts of the picture.
Iter-9+ claims.yaml should carry **all three** (Zhang/Naitzat/Lim,
Charisopoulos/Maragos, Maclagan/Sturmfels).

## 2. Target state

```
agent_core/src/research/
├── mod.rs                      (unchanged — keeps `pub mod tropical;`
│                                and adds `pub mod tropical_ir;`)
├── tropical.rs                 (594 LOC → ~6 LOC shim, see §3)
└── tropical_ir/
    ├── mod.rs                  (carries the source-citation header
    │                            + re-exports of TropicalMonomial etc.)
    ├── grammar.rs              (TropicalMonomial · TropicalPolynomial
    │                            · TropicalError type definitions)
    ├── operator.rs             (tropical_add · tropical_mul +
    │                            future TropicalRational composition)
    └── compile.rs              (relu_as_tropical_polynomial ·
                                  relu_layer_as_tropical)
```

The shape matches doctrine §4 (Per-IR Rust crate-module shape: mod ·
grammar · normalize · evaluator · lowering · certificate). Iter-6
target landing is the **3-file split** above — `normalize.rs`,
`lowering.rs`, and `certificate.rs` arrive during Phase B2 proper
(iter 9+).

Re-export shim `tropical.rs`:

```rust
//! Compatibility shim — Tropical-IR moved to research::tropical_ir/
//! at iter-6 of T5 Phase A. New code should import from
//! `crate::research::tropical_ir`. This file re-exports the prior
//! public surface so external call sites don't break across the
//! migration.

#![doc(hidden)]

pub use super::tropical_ir::{
    relu_as_tropical_polynomial, relu_layer_as_tropical, tropical_add, tropical_mul,
    TropicalError, TropicalMonomial, TropicalPolynomial,
};
```

(Final shim form lands at the actual move commit; the above is
illustrative.)

## 3. Migration steps (single commit, single iteration)

1. `git mv agent_core/src/research/tropical.rs agent_core/src/research/tropical_ir.rs.tmp`
   — preserve content under a temp name.
2. `mkdir -p agent_core/src/research/tropical_ir/`.
3. Split the temp file into 4 files (grammar / operator / compile +
   re-exporting `mod.rs`). Tests stay with the items they test.
4. Create the thin re-export shim at
   `agent_core/src/research/tropical.rs` per §2.
5. Edit `agent_core/src/research/mod.rs` line 45 region to add
   `pub mod tropical_ir;` alongside the existing `pub mod tropical;`
   declaration.
6. `cargo test --manifest-path agent_core/Cargo.toml --lib` —
   **expected: 1671 passed (unchanged).** Test count is identical;
   only the module path changes.
7. Commit per the per-iter discipline (HEREDOC, Co-Authored-By
   Codex (T5)).

**Out-of-scope-lock concern.** Step 5 touches
`agent_core/src/research/mod.rs`, which is technically outside the
SCOPE LOCK (mod.rs is the parent's, not one of the listed
`<ir>_ir/` modules). However: the only edit is the additive
`pub mod tropical_ir;` declaration, which is the canonical way to
register a NEW child module in Rust. Without this single line, the
new module does not compile. Treat as **minimal-scope-lock breach
explicitly enabled by the driver SCOPE LOCK entry for tropical_ir/**
(creating a new module necessarily means declaring it in the parent).
The diff for this edit is **1 line, additive only**.

## 4. Risk assessment

| Risk | Severity | Mitigation |
|---|---|---|
| Existing call site breaks | **Zero** — grep shows no external uses; `mod.rs:45` is the only mention | Re-export shim covers any future cross-tree users that might land before B2 |
| Test count regresses | Low — all 28 tests move with their items; cargo test count stays at 1671 | Iter-6 plan-doc lands before the move; iter-9 commit message includes pre/post cargo counts |
| Source-citation header drift | Low — header migrates verbatim from flat file to new `tropical_ir/mod.rs` | Verify post-move via `grep -c "arXiv\|Zhang\|Maclagan" agent_core/src/research/tropical_ir/mod.rs` |
| Concurrent merge conflict with sibling T1-T8 terminals | None — no other T-terminal owns research/tropical* (T5 owns all six IRs per driver SCOPE LOCK) | Verified by inspecting MEMORY.md (T1 trifusion, T2 agent, T3 uasacs, T4 vault, T5 emlir, T6 uiux, T7 eml runtime, T8 biometric — only T5 + T7 touch eml-related, and T7 is runtime-layer not IR-layer per `project_terminal_t7_override_2026_05_17` memory) |
| `research_custody/tropical/claims.yaml` gets out-of-sync with the file-level citations | Low — claims.yaml cites Zhang/Naitzat/Lim + Charisopoulos/Maragos but tropical.rs header cites Zhang/Naitzat/Lim + Maclagan/Sturmfels | §6 below: at iter-9+, add Maclagan/Sturmfels as a third claims.yaml entry for tropical IR |

## 5. Rollback path

If `cargo test --lib` after the move shows any regression (`< 1671`
or any failures):

1. `git reset --hard <pre-move-sha>` — recover the iter-5 state
   (commit `f99cdc02d` is the last clean iter-5 baseline).
2. Re-investigate the regression. The move is purely structural;
   any test failure indicates either (a) Cargo.toml feature gating
   the wrong way, or (b) a hidden cross-module import that grep
   missed (e.g. a macro expansion).
3. If the root cause is structural (e.g. a build-script reference),
   document under §4 risk table and re-attempt at the next iter.

## 6. Follow-up bookkeeping (not iter-6 work)

These are notes for the iter-9+ Phase B2 entry slice:

1. **Add Maclagan-Sturmfels to `research_custody/tropical/claims.yaml`.**
   Currently 2 claims (Zhang/Naitzat/Lim + Charisopoulos/Maragos);
   the existing file header lists Zhang/Naitzat/Lim + Maclagan/Sturmfels.
   Both books should be claimed.
2. **Update `paper_registry/seed.rs`** if Phase C wires the new
   Tropical-IR claims into the runtime claim ledger (out of scope
   for Phase A).
3. **Verify `research_custody/tropical/verification_status.md`**
   reflects the post-move file paths (e.g. `lowering.rs` instead of
   the flat `tropical.rs`) at the iter-9 commit.

## 7. Acceptance bar for the iter-9 move commit

- Pre-move cargo lib test count: **1671** (baseline from iter-2 commit
  `078bbce83` message).
- Post-move cargo lib test count: **1671 unchanged** (zero regression).
- `grep -rn "research::tropical\|crate::tropical" agent_core/src/`
  returns the same external call-site count as today (zero).
- `tropical.rs` shim file present, ≤ 15 LOC, re-exports the seven
  public items.
- `tropical_ir/mod.rs` carries the verbatim source-citation header
  from the pre-move flat file.
- `git mv` chain visible in `git log --follow` (preserves history
  attribution for the 594 LOC + 28 tests landed under Wave J B.6.15).

---

**Status:** Plan-only commit. Move executes at Phase B2 entry
(iter 9+), under the conditions in §7. Phase A close-out (iter-8)
will reconfirm this plan against any sibling-terminal merge motion
that lands between now and B2.

**Co-Authored-By:** Codex (T5) <noreply@anthropic.com>
