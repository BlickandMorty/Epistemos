# ACS Admission Production Gate Audit — 2026-05-24

## Summary

Terminal E wires ACS (Anchored Cognitive Substrate / Autopoietic Cognitive Stack) admission into the v2 tool-call path and stops treating `CSISafeguard` as an isolated class. The Rust path now exposes `agent_runtime_v2::acs_run_event_log_sink::ACSRunEventLogSink`, uses `ACSRunEventLogSink::admit_and_record` before a `MissionRun` can append a tool call, and carries `scope_rex::admission_proof::SCOPERexAdmissionProof { verdict, record_id, capability_signature }` on the cross-lane handoff.

The Swift path calls `CSISafeguard.recordMeasurement(...)` before `CloudKnowledgeDistillationService` persists a compiled model vault. A low CSI value throws before `store.save(vault)`.

## Rev-2 PR Carry Fields

- Motion: Mutate / Promote. ACS admission decides whether a tool action or distillation write may become durable state; blocked verdicts remain witnessed without committing the action.
- UAS: ACS audit `record_id` is the address for each admission record. Provenance Console rows currently carry an explicit UAS waiver until row-level ACS record ids are available.
- Plane: Controller plane for admission decisions; Verification plane for `RunEventLog`, signed proof, Swift source guard, and audit docs; UI projection is a Verification-plane witness.
- Residency: Tier 1 MAS for the production gate path. No Pro-only or Research-only runtime path is promoted by this PR.
- WBO: not an approximate transform, so no lattice budget is spent. Verdict accounting is the error policy: allow, warning, and blocked verdicts stay separate and auditable.
- Witness: `RunEventLog` ACS audit record, `SCOPERexAdmissionProof`, forged-signature test, source-order test for `CSISafeguard`, and this audit doc.
- Falsifier: W-46/W-47 proof boundary is tested locally. Canonical `F-ACS-Anchor-Addressing` is not claimed; it is blocked by missing `AcsAnchor` / `AnchorRegistry` / harness substrate on this branch.
- Tier: Tier 1 (MAS), high risk because it gates execution and persistence.
- Rollback: disable `EPISTEMOS_ACS_ADMISSION_V0` for UI flag posture, revert callers to `MissionRun::record_event` / direct distillation persistence, or inject a `csiGateProvider` that returns `shouldContinue: true` while preserving the source-order seam for a follow-up fix.
- LLM-address granularity row: `Output schema` for typed tool-call / proof admission, plus `Whole-model call` metadata for per-model distillation vault gating. No KV-page, adapter, attention-head, parameter-anchor, or circuit addressing is claimed.

## 7 Laws

- Law 7 Witness: every admitted v2 tool call emits an ACS audit record into the OpLog and returns a signed proof tied to that record.
- Law 4 Lattice-error: blocked ACS verdicts remain audited while the typed tool-call row is not appended.
- Law 1 Density: the controller policy stays compact; `MissionRun::admit_and_record_tool_call` is the single production handoff for v2 tool calls.
- Law 2 Address is also advanced through canonical ACS `record_id` proofs and OpLog lookup.

## No-Orphan Check

Data classes touched:

- ACS audit records and v2 tool handoffs: UAS address is the ACS `record_id` stored as the OpLog node id; plane is controller/witness; residency is Tier 1 MAS; WBO is not approximate; WRV is wired, reachable, and verified by Rust integration tests.
- SCOPE-Rex admission proofs: UAS address is `record_id`; plane is proof/witness; residency is Tier 1 MAS; WBO is not approximate; WRV is wired and verified through forged-signature rejection.
- Cloud distillation CSI measurements: UAS address waiver because the CSI value is an ephemeral pre-persistence gate, not durable knowledge data; plane is alignment safety; residency is Tier 1 MAS; WBO is not approximate; WRV is product-facing through the thrown persistence error and test coverage.
- Provenance Console ACS verdict field: UAS address is explicitly not linked until provenance rows carry ACS record ids; plane is UI witness; residency is Tier 1 MAS; WBO is not approximate; WRV is visible but partial because full clickable AcsAnchor detail remains pending.

## W-Rows And Falsifiers

- W-46 advances to Rust-wired: `ACSRunEventLogSink::admit_and_record` fans verdicts into the OpLog, with v2 module exposure and focused tests.
- W-47 advances to partial-wired: `SCOPERexAdmissionProof { verdict, record_id, capability_signature }` exists under `scope_rex`, tool handoffs carry it, and forged signature mutation is rejected.
- W-25 advances to partial: Provenance Console rows render an inline `ACS verdict` field, but full AcsAnchor sorting/clickable detail remains blocked by missing row-level ACS anchor IDs.
- W-52 advances to wired-source-guarded-Xcode-cancelled: `CSISafeguard` has a production caller before distillation persistence and a low-CSI short-circuit test, but the targeted Xcode test run was cancelled during a Rust build step before Swift tests completed.
- F-ACS-Anchor-Addressing: unblocked at the ACS admission proof/address boundary; full M2 Pro PASS is not claimed because this branch does not contain the canonical `AcsAnchor` type, `AnchorRegistry`, or `agent_core/tests/acs_anchor_addressing.rs` harness required by `docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md`.

## Tier Classification

Tier 1 (MAS). This PR gates v2 tool execution and distillation persistence in MAS-reachable code paths. No Pro-only code was added. Research surfaces are untouched. Vault/speculation trail is preserved in this audit doc and the backlog row updates.

## Verification

- PASS: `rustup run stable cargo test --manifest-path agent_core/Cargo.toml --test r5_acs_tool_handoff`
- PASS: `rustup run stable cargo test --manifest-path agent_core/Cargo.toml --test r4_acs_audit_snapshot_helper --test acs_admission_bridge`
- PASS: `rustup run stable cargo build --manifest-path agent_core/Cargo.toml --no-default-features --features pro-build,lsp-runtime --target x86_64-apple-darwin`
- CANCELLED/FAIL exit 65: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTerminalEACS -only-testing:EpistemosTests/CloudKnowledgeDistillationTests -only-testing:EpistemosTests/ProvenanceConsoleSourceGuardTests -only-testing:EpistemosTests/SearchFusionHealthRowTests test CODE_SIGNING_ALLOWED=NO -quiet`. The run reached the Rust bridge build and then reported `could not compile agent_core (lib)` with `rustc` exiting by signal 15 (`SIGTERM`), not a Rust diagnostic. The same direct Rust feature/target build above passed, so Swift test completion is not claimed.
- BLOCKED: canonical `F-ACS-Anchor-Addressing` M2 Pro PASS is not claimed. Required files from the falsifier spec are absent on this branch: `agent_core/src/research/acs/anchor.rs`, `agent_core/src/research/acs/anchor_registry.rs`, and `agent_core/tests/acs_anchor_addressing.rs`. See `docs/audits/DECISION_NEEDED_ACS_ANCHOR_ADDRESSING_2026_05_24.md`.
