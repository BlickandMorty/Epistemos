# ACS Anchor Harness Full Closeout - 2026-05-27

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Status: `RESUME ACS ANCHOR HARNESS` completed.

Branch: `codex/resume-acs-anchor-harness-2026-05-27`.

## What Changed

- `agent_core/src/uas/acs_anchor.rs`
  - Adds `AcsAnchorPlaneProjection<'_>`, a borrowed five-plane projection view
    over an `AcsAnchor`.
  - Adds `AcsAnchor::project_to_plane()` without allocating a parallel anchor
    type.
- `agent_core/src/uas/anchor_registry.rs`
  - Adds `lookup_via_projection(...)`.
  - Rejects projection lookup when a silent field change would otherwise hide
    loss.
- `agent_core/src/bin/falsify_acs_anchor_addressing.rs`
  - Promotes the old N=100 scoped harness to an N=1000 full harness.
  - Measures four primary stages:
    1. agent runtime emission
    2. registry lookup
    3. audit canonicalization through `Claim` JSON
    4. five-plane projection inversion
  - Keeps SCOPE-Rex admission proof tamper rejection as an adjacent security axis.
- `artifacts/falsifiers/acs_anchor_addressing/result.json`
  - Re-emitted as `f_acs_anchor_addressing_full_n1000_v1`.

## Measurement

The harness produced a primary witness on the local M2 Pro artifact rig:

- `full_n`: 1000 anchors
- `stage_agent_runtime_emission`: 1000 / 1000
- `stage_lookup_matches`: 1000 / 1000
- `stage_audit_canonicalization`: 1000 / 1000
- `stage_projection_inversion`: 1000 / 1000
- `stage_admission_proof_round_trip`: 1000 / 1000
- `stage_admission_proof_tamper_rejected`: 1000 / 1000

Latency p99 measurements in the artifact are under the documented budgets:

- emission p99: 1 us <= 80 us
- lookup p99: 0 us <= 40 us
- audit p99: 3 us <= 800 us
- projection p99: 0 us <= 20 us

## No-Orphan Check

- Motion: Project / Recall and projection inversion for typed ACS anchors.
- UAS: uses the product `agent_core::uas::AcsAnchor`, not a duplicate research
  type.
- Plane: `RuntimePlane` is projected and inverted.
- Residency: `ResidencyTier` survives emission, audit, and projection.
- WBO/error: no approximate green claim; the artifact records measured axes and
  thresholds.
- Witness: result artifact plus Rust tests.
- Falsifier: `F-ACS-Anchor-Addressing`.
- Tier: Verified Floor witness.
- Rollback: revert the projection/registry methods and restore the scoped
  artifact if a downstream regression appears.

## Verification

- `cargo test --manifest-path agent_core/Cargo.toml --lib --quiet acs_anchor`
- `cargo run --manifest-path agent_core/Cargo.toml --release --bin falsify_acs_anchor_addressing`
