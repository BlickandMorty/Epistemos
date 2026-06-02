# Decision Resolved - SCOPE-Rex Admission + AcsAnchor Addressing Scope

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

**Decision:** **Option 2 — Re-scope Terminal E** (chosen 2026-05-24)
**Resolver:** user via Claude session
**Reason:** Terminal G already produced the typed anchor substrate at `agent_core/src/uas/{acs_anchor.rs, anchor_registry.rs}` and measured `F-ACS-AnchorLookup` on M2 Pro. Forcing Terminal E to also build the `agent_core/src/research/acs/anchor.rs` + harness would either (a) duplicate substrate or (b) break the canonical lane separation (research/acs/ = Pro Research, never MAS · legacy acs_admission/ = product-lane SCOPE-Rex admission).

## What Terminal E claims (locked)

- W-46: **Rust-wired** — `ACSRunEventLogSink::admit_and_record` fans SCOPE-Rex verdicts into OpLog
- W-47: **partial-wired** — `SCOPERexAdmissionProof { verdict, record_id, capability_signature }` carried on v2 tool handoffs; forged-signature rejection covered
- W-25: **partial** — Provenance Console renders inline SCOPE-Rex verdict field; full clickable AcsAnchor sorting blocked on row-level AcsAnchor IDs (future work)
- W-52: **wired-source-guarded** — `CSISafeguard` is called before distillation persistence; low-CSI short-circuit test added

## What Terminal E does NOT claim (locked)

- **F-ACS-Anchor-Addressing canonical PASS** — that falsifier requires `agent_core/src/research/acs/{anchor,anchor_registry}.rs` + `agent_core/tests/acs_anchor_addressing.rs` (1,000-anchor four-stage round-trip), all of which belong to T3/Pro Research and remain out of scope for Terminal E's product-lane work.

## What gets deferred (future Pro Research follow-up)

A new deferred item is created:

- **D-27 · F-ACS-Anchor-Addressing canonical harness** — the typed-anchor four-stage round-trip in `agent_core/src/research/acs/` + tests. Re-promotion codeword: **`RESUME ACS ANCHOR HARNESS`**. Builds on Terminal G's `agent_core/src/uas/anchor_registry.rs` foundation. Currently Pro Research; promotes to MAS-safe product-lane after the typed-anchor round-trip PASSes on M2 Pro.

## Adjacent victory already in main

- Terminal G's PR (pending open) lands `F-ACS-AnchorLookup` measured PASS (anchor lookup `< 1 μs avg over 10k claims`). This is the product-relevant anchor-performance measurement and lives in the product lane (`agent_core/src/uas/`). The canonical F-ACS-Anchor-Addressing four-stage harness remains deferred per D-27 above.
