# SCOPE-Rex Admission Production Gate Audit - 2026-05-24

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

> Legacy code and file paths still use `acs_*` names. Current architecture
> language is SCOPE-Rex/SovereignGate for admission/governance and AcsAnchor
> for anchored coordinate/provenance.

## Summary

Terminal E wires SCOPE-Rex admission into the v2 tool-call path and stops treating `CSISafeguard` as an isolated class. The legacy Rust path now exposes `agent_runtime_v2::acs_run_event_log_sink::ACSRunEventLogSink`, uses `ACSRunEventLogSink::admit_and_record` before a `MissionRun` can append a tool call, and carries `scope_rex::admission_proof::SCOPERexAdmissionProof { verdict, record_id, capability_signature }` on the cross-lane handoff.

The Swift path calls `CSISafeguard.recordMeasurement(...)` before `CloudKnowledgeDistillationService` persists a compiled model vault. A low CSI value throws before `store.save(vault)`.

Latest-main build hardening also marks the production `EidosBridge` static bridge methods `nonisolated` so Swift 6 default actor isolation does not break the existing W-47 citation gate. This is a build-correctness fix only; it does not change Eidos behavior.

## Rev-2 PR Carry Fields

- Motion: Mutate / Promote. SCOPE-Rex admission decides whether a tool action or distillation write may become durable state; blocked verdicts remain witnessed without committing the action.
- UAS: legacy ACS audit `record_id` is the address for each admission record. Provenance Console rows currently carry an explicit UAS waiver until row-level admission record ids are available.
- Plane: Controller plane for admission decisions; Verification plane for `RunEventLog`, signed proof, Swift source guard, and audit docs; UI projection is a Verification-plane witness.
- Residency: MAS-safe for the production gate path. No Pro-only or Pro Research runtime path is promoted by this PR.
- WBO: not an approximate transform, so no lattice budget is spent. Verdict accounting is the error policy: allow, warning, and blocked verdicts stay separate and auditable.
- Witness: `RunEventLog` admission audit record, `SCOPERexAdmissionProof`, forged-signature test, source-order test for `CSISafeguard`, and this audit doc.
- Falsifier: W-46/W-47 proof boundary is tested locally. Canonical `F-ACS-Anchor-Addressing` PASS is not claimed because the typed-anchor harness is explicitly deferred out of Terminal E scope.
- Tier: MAS-safe, high risk because it gates execution and persistence.
- Rollback: disable `EPISTEMOS_ACS_ADMISSION_V0` for UI flag posture, revert callers to `MissionRun::record_event` / direct distillation persistence, or inject a `csiGateProvider` that returns `shouldContinue: true` while preserving the source-order seam for a follow-up fix.
- LLM-address granularity row: `Output schema` for typed tool-call / proof admission, plus `Whole-model call` metadata for per-model distillation vault gating. No KV-page, adapter, attention-head, parameter-anchor, or circuit addressing is claimed.
- Incidental build fix: `EidosBridge` isolation has no new motion; it preserves the existing W-47 citation-gate witness path at `Output schema` granularity.

## 7 Laws

- Law 7 Witness: every admitted v2 tool call emits an admission audit record into the OpLog and returns a signed proof tied to that record.
- Law 4 Lattice-error: blocked SCOPE-Rex verdicts remain audited while the typed tool-call row is not appended.
- Law 1 Density: the controller policy stays compact; `MissionRun::admit_and_record_tool_call` is the single production handoff for v2 tool calls.
- Law 2 Address is also advanced through canonical admission `record_id` proofs and OpLog lookup.

## No-Orphan Check

Data classes touched:

- Legacy ACS audit records and v2 tool handoffs: UAS address is the admission `record_id` stored as the OpLog node id; plane is controller/witness; residency is MAS-safe; WBO is not approximate; WRV is wired, reachable, and verified by Rust integration tests.
- SCOPE-Rex admission proofs: UAS address is `record_id`; plane is proof/witness; residency is MAS-safe; WBO is not approximate; WRV is wired and verified through forged-signature rejection.
- Cloud distillation CSI measurements: UAS address waiver because the CSI value is an ephemeral pre-persistence gate, not durable knowledge data; plane is alignment safety; residency is MAS-safe; WBO is not approximate; WRV is product-facing through the thrown persistence error and test coverage.
- Provenance Console SCOPE-Rex verdict field: UAS address is explicitly not linked until provenance rows carry admission record ids; plane is UI witness; residency is MAS-safe; WBO is not approximate; WRV is visible but partial because full clickable AcsAnchor detail remains pending.

## W-Rows And Falsifiers

- W-46 advances to Rust-wired: `ACSRunEventLogSink::admit_and_record` fans SCOPE-Rex verdicts into the OpLog, with v2 module exposure and focused tests.
- W-47 advances to partial-wired: `SCOPERexAdmissionProof { verdict, record_id, capability_signature }` exists under `scope_rex`, tool handoffs carry it, and forged signature mutation is rejected.
- W-25 advances to partial: Provenance Console rows render an inline SCOPE-Rex verdict field, but full AcsAnchor sorting/clickable detail remains blocked by missing row-level AcsAnchor IDs.
- W-52 advances to wired-source-guarded-Xcode-blocked: `CSISafeguard` has a production caller before distillation persistence and a low-CSI short-circuit test, but targeted Xcode verification is blocked by Swift 6 actor isolation in the test helper after three attempts.
- F-ACS-Anchor-Addressing: unblocked only at the SCOPE-Rex admission proof/address boundary. Full M2 Pro PASS is not claimed because the canonical typed-anchor harness is deferred per `docs/audits/DECISION_RESOLVED_ACS_ANCHOR_ADDRESSING_2026_05_24.md`.

## Build Classification

MAS-safe. This PR gates v2 tool execution and distillation persistence in MAS-reachable code paths. No Pro-only code was added. Pro Research surfaces are untouched. Pro Vault-Preserved/speculation trail is preserved in this audit doc and the backlog row updates.

## Verification

- PASS: `rustup run stable cargo test --manifest-path agent_core/Cargo.toml --test r5_acs_tool_handoff`
- PASS: `rustup run stable cargo test --manifest-path agent_core/Cargo.toml --test r4_acs_audit_snapshot_helper --test acs_admission_bridge`
- PASS: `rustup run stable cargo build --manifest-path agent_core/Cargo.toml --no-default-features --features pro-build,lsp-runtime --target x86_64-apple-darwin`
- FAIL after three Xcode attempts: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CloudKnowledgeDistillationTests -only-testing:EpistemosTests/ProvenanceConsoleSourceGuardTests -only-testing:EpistemosTests/SearchFusionHealthRowTests test CODE_SIGNING_ALLOWED=NO -quiet`. The final blocker is `EpistemosTests/CloudKnowledgeDistillationTests.swift:565`, where `makeNote(...)` is main-actor isolated but called from a synchronous nonisolated provider closure. See `docs/audits/BLOCKER_ACS_ADMISSION_XCODE_VERIFICATION_2026_05_24.md`.
- DEFERRED: canonical `F-ACS-Anchor-Addressing` M2 Pro PASS is not claimed. The typed-anchor four-stage harness is outside Terminal E's product-lane scope and remains deferred under D-27. See `docs/audits/DECISION_RESOLVED_ACS_ANCHOR_ADDRESSING_2026_05_24.md`.
