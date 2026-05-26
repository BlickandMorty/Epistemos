# Decision Needed — ACS Anchor Addressing Scope

Superseded by `docs/audits/DECISION_RESOLVED_ACS_ANCHOR_ADDRESSING_2026_05_24.md`. This file is preserved as the original ambiguity record; the resolved scope is Option 2, with canonical typed-anchor falsifier work deferred outside Terminal E.

## Summary

Terminal E wires ACS admission as a production gate, but cannot honestly claim `F-ACS-Anchor-Addressing` PASS on this branch.

The canonical falsifier at `docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md` requires:

- `agent_core/src/research/acs/anchor.rs` with typed `AcsAnchor { theorem_tag, plane, tier, source_hash, active_packet_id }`
- `AnchorRegistry` lookup by `UasAddress`
- `agent_core/tests/acs_anchor_addressing.rs` running the 1000-anchor four-stage round trip through agent runtime, lookup, audit, and projection

Those files are not present in this branch. `agent_core/src/research/acs/mod.rs` currently contains the autopoiesis / governance / Kuramoto / Notch-Delta / VSM research modules only, with a reserved anchor comment.

## Evidence

- `find agent_core/src/research/acs -maxdepth 2 -type f` returns only `vsm.rs`, `kuramoto.rs`, `autopoiesis.rs`, `notch_delta.rs`, `mod.rs`, and `governance.rs`.
- `ls agent_core/tests | rg 'acs|anchor'` returns only `acs_admission_bridge.rs`, `r4_acs_audit_snapshot_helper.rs`, and `r5_acs_tool_handoff.rs`.
- `rg "pub struct AcsAnchor|AnchorRegistry|active_packet_id" agent_core/src agent_core/tests` returns no implementation hits.

## Decision

Pick one before claiming the falsifier:

1. Import or re-land the T3 `AcsAnchor` / `AnchorRegistry` / `acs_anchor_addressing` harness into this branch, run the M2 Pro falsifier, and then update the Terminal E audit to PASS.
2. Re-scope Terminal E acceptance so `F-ACS-Anchor-Addressing` is explicitly limited to the ACS admission proof/address boundary, while the canonical typed-anchor falsifier remains T3/Terminal G-owned.

## Current Safe Claim

Terminal E can claim:

- W-46 Rust-wired: ACS verdicts fan into `RunEventLog`.
- W-47 partial-wired: `SCOPERexAdmissionProof { verdict, record_id, capability_signature }` exists, is carried on v2 tool handoffs, and forged signatures are rejected.
- W-52 wired-source-guarded: `CSISafeguard` is called before distillation persistence, with source-order and low-CSI short-circuit tests added.
- Rev-2 LLM-address granularity: Output schema for tool-call/proof admission and whole-model-call metadata for model-vault gating. No finer neural-substrate row is touched or claimed.

Terminal E cannot claim canonical `F-ACS-Anchor-Addressing` PASS until the typed anchor substrate and harness exist and pass locally.
