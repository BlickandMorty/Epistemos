# T17B Decomposition Map — `lattice_wbo` (2026-05-22)

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

`agent_core/src/lattice_wbo/mod.rs` was a 13,291-line monolith. T17B splits it
into reviewable submodules without changing public behavior or any test's
intent. The crate API surface and test count are byte-for-byte preserved
modulo file paths, including the same 305 `#[test]` functions and the same
re-exported public types.

The acceptance contract: crate still compiles, every existing test still
passes (verified: `cargo test --manifest-path agent_core/Cargo.toml --lib`
reports `1976 passed; 0 failed; 0 ignored`), no submodule file exceeds
1,500 lines, and `agent_core/src/lib.rs` is untouched because the module
path `pub mod lattice_wbo;` did not change.

## New layout

```
agent_core/src/lattice_wbo/
├── mod.rs                                   façade — re-exports only (24 lines)
├── wire.rs                                  shared serde infra (40 lines)
├── error.rs                                 LatticeWboError (138 lines)
├── verifier.rs                              falsifier-hook owners + private hook helpers (141 lines)
├── register.rs                              ResidencyTier, LatticeCoderKind, SideInformationKind, WboLedgerEntry (843 lines)
├── accounting.rs                            WboTermCode, LatticeErrorContribution, LatticeBudget, ActiveSupportBudget (558 lines)
├── tests.rs                                 shared test helpers + submodule declarations (162 lines)
└── tests/
    ├── serde_roundtrip.rs                   (1,196)
    ├── public_accounting_envelope.rs        (562)
    ├── public_key_registries.rs             (541)
    ├── ledger_basic_validation.rs           (265)
    ├── residency_catalog.rs                 (1,079)
    ├── register_doc_cross_links.rs          (1,272)
    ├── register_doc_rows.rs                 (350)
    ├── codec_falsifier_catalog.rs           (900)
    ├── axis_assignment.rs                   (913)
    ├── budget_validation.rs                 (1,052)
    ├── term_catalog_and_slices.rs           (534)
    ├── active_support_side_info.rs          (862)
    ├── ledger_residency_rejections.rs       (610)
    └── ledger_measured_and_falsifier.rs     (1,376)
```

The original suggested `witness.rs` bucket has no content — the live module
did not contain a witness-production unit; that surface lives elsewhere in
the crate. The suggested `serde.rs` split was rejected because every
`Deserialize` impl tightly couples to private fields/validators of its
companion type; keeping serde impls colocated with their types avoids
visibility leaks. The shared serde plumbing (`ExplicitPublicOption` plus
its deserialize hook) lives in `wire.rs`.

## Production-code line mapping (prior monolith → new file)

| Prior `mod.rs` range | Item                                               | New file        | New range |
|----------------------|----------------------------------------------------|-----------------|-----------|
| 1–6                  | Module doc                                         | `mod.rs`        | 1–11      |
| 7                    | `use serde::{...}`                                 | (split per file)| —         |
| 9–40                 | `ExplicitPublicOption` + `deserialize_explicit_public_option` | `wire.rs`       | 7–41      |
| 42–215               | `ResidencyTier` enum + impl + Serialize/Deserialize | `register.rs`   | 13–185    |
| 217–501              | `LatticeCoderKind` enum + impl + Serialize/Deserialize | `register.rs`   | 187–471   |
| 503–612              | `SideInformationKind` enum + impl + Serialize/Deserialize | `register.rs`   | 473–582   |
| 614–732              | `WboTermCode` enum + impl + Serialize/Deserialize  | `accounting.rs` | 12–130    |
| 734–784              | `FalsifierHookOwner` + `FALSIFIER_HOOK_OWNERS` + `falsifier_hook_owners` + Deserialize | `verifier.rs`   | 14–65     |
| 786–865              | `LatticeErrorContribution` + impl + Deserialize    | `accounting.rs` | 133–214   |
| 867–1144             | `LatticeBudget` + impl + Deserialize               | `accounting.rs` | 216–470   |
| 1146–1212            | `ActiveSupportBudget` + impl + Deserialize         | `accounting.rs` | 493–558   |
| 1214–1472            | `WboLedgerEntry` + impl + Deserialize              | `register.rs`   | 585–842   |
| 1474–1607            | `LatticeWboError` enum + impl + Serialize/Deserialize | `error.rs`      | 5–138     |
| 1609–1685            | Private hook helpers (`validate_nonnegative_finite`, `contains_falsifier_hook`, `is_falsifier_hook_boundary`, `contains_any_falsifier_hook`, `f_hooks_in`, `falsifier_hooks_are_owned`) | `verifier.rs`   | 68–141    |

Private helpers that were once free fns in `mod.rs` are now `pub(super)` in
`verifier.rs` and `wire.rs` so that `register.rs`, `accounting.rs`, and the
test submodules can still call them by their original names.

## Test mapping (prior `mod tests { … }` lines 1687–13291)

The shared `use super::*;` + 6 helper utilities + the `RegisterCanonAnchor`
struct moved into `lattice_wbo/tests.rs`. The 305 `#[test]` functions were
grouped by tested surface into 14 submodules of `lattice_wbo/tests/`:

| Prior `mod.rs` range | New submodule                                  |
|----------------------|------------------------------------------------|
| 1687–1822            | helpers → `tests.rs`                           |
| 1824–3015            | `tests/serde_roundtrip.rs`                     |
| 3017–3574            | `tests/public_accounting_envelope.rs`          |
| 3576–4112            | `tests/public_key_registries.rs`               |
| 4114–4374            | `tests/ledger_basic_validation.rs`             |
| 4376–5450            | `tests/residency_catalog.rs`                   |
| 5452–6717            | `tests/register_doc_cross_links.rs`            |
| 6719–7064            | `tests/register_doc_rows.rs`                   |
| 7066–7961            | `tests/codec_falsifier_catalog.rs`             |
| 7963–8871            | `tests/axis_assignment.rs`                     |
| 8873–9920            | `tests/budget_validation.rs`                   |
| 9922–10451           | `tests/term_catalog_and_slices.rs`             |
| 10453–11310          | `tests/active_support_side_info.rs`            |
| 11312–11917          | `tests/ledger_residency_rejections.rs`         |
| 11919–13290          | `tests/ledger_measured_and_falsifier.rs`       |

Each test submodule starts with `use super::*;`, which through
`tests.rs`'s `pub(super) use super::*;`, `pub(super) use super::verifier::*;`,
and `pub(super) use super::wire::*;` re-exports gives every test access to
the same names (`LatticeBudget`, `contains_falsifier_hook`,
`ExplicitPublicOption`, etc.) it had under the monolith.

## Two coordinated edits outside the pure-refactor envelope

1. **`docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md` rows 45–49**:
   the "Source anchor" cells previously named
   `agent_core/src/lattice_wbo/mod.rs:LINE` for the five serialized public
   structs. After decomposition the canonical declarations live in three
   different files (`verifier.rs`, `accounting.rs`, `register.rs`); the
   rows were updated to point at the new files and lines. Without this,
   `tests::register_doc_cross_links::register_doc_json_surface_source_line_anchors_match_current_code`
   would fail.
2. **`tests/register_doc_cross_links.rs` —
   `register_doc_json_surface_source_line_anchors_match_current_code`**:
   the test was rewritten to load each struct's actual file (`accounting.rs`,
   `register.rs`, `verifier.rs`) instead of a single `mod.rs`, and to format
   anchors against the per-struct file name. Logic and assertions are
   otherwise unchanged.

## Verification

```
$ cargo check --manifest-path agent_core/Cargo.toml --lib --tests
   Finished `dev` profile [unoptimized + debuginfo] target(s)

$ cargo test --manifest-path agent_core/Cargo.toml --lib
   test result: ok. 1976 passed; 0 failed; 0 ignored; 0 measured

$ cargo test --manifest-path agent_core/Cargo.toml --lib lattice_wbo
   test result: ok. 305 passed; 0 failed; 0 ignored; 0 measured; 1671 filtered out
```

## Follow-up (not in this branch)

The user's prompt flags a name-resolution pass coordinating with T18B's
`research/acs` namespace. That work is intentionally deferred; this commit
limits itself to the structural decomposition.
