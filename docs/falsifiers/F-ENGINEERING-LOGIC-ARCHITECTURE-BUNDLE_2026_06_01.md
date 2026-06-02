---
state: backlog-falsifier-bundle
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source: docs/fusion/ENGINEERING_LOGIC_ARCHITECTURE_INTAKE_2026_06_01.md
status: candidate tests; not implemented unless a later PR wires artifacts
---

# F-Engineering Logic Architecture Bundle - 2026-06-01

This bundle turns the engineering-logic doctrine into testable promotion
gates. It does not authorize a new architecture organ, planning framework, or
runtime layer. It defines the minimum proof artifacts required before a
mechanism can govern product behavior.

## Shared artifact contract

Every falsifier emits:

```text
falsifier_id
source_doc
change_id
affected_organs
product_build
pro_status
decision_record_ref
invariant_ids
state_machine_id_or_boundary_contract_id
budget_vector_ref
failure_envelope_ref
observability_probe_ref
migration_or_import_gate_ref
rollback_ref
run_event_log_visibility
answer_packet_visibility
pass
failure_reason
```

## Falsifier Matrix

| Falsifier | Pass condition | Rejects |
|---|---|---|
| `F-DecisionRecord-Completeness` | A proposed mechanism names the problem, chosen option, rejected options, constraints, affected organs, source refs, falsifier refs, and rollback. | Architecture by assertion, winner-only thinking, and no rollback. |
| `F-InvariantLedger-Completeness` | Every live or candidate mechanism declares owner organ, source of truth, preconditions, postconditions, forbidden states, witness, and falsifier. | Mechanisms with no testable invariant or hidden owner. |
| `F-StateMachineCard-TransitionSafety` | State fixtures exercise allowed, forbidden, terminal, and rollback transitions with named guards and side effects. | Open-ended state mutation, impossible rollback, and undocumented side effects. |
| `F-BoundaryContract-SendableOwnership` | Actor, FFI, model, storage, or tool boundaries declare ownership, data shape, sendability/thread rule, cancellation, backpressure, error type, and privacy. | Implicit cross-actor mutation, unsafe FFI ownership, and unbounded retries. |
| `F-BudgetVector-HotPath` | Hot-path fixtures report latency, active bytes, hot resident bytes, cold bytes, copy count, allocations, actor hops, disk I/O, and verifier cost where relevant. | Performance claims without measured budget or hidden copy/allocation cost. |
| `F-HotPathProofCard-NoAllocationSpike` | Rapid-event fixtures stay within p95/p99 budget and do not introduce per-event allocation spikes beyond the declared budget. | UI/render/editor/model hot paths that work only in calm demos. |
| `F-FailureEnvelope-Rollback` | Known failures have detection signal, user visibility rule, retry/fallback policy, data-loss classification, and rollback ref before mutation. | Mutation-first designs and failure modes that only become visible after data loss. |
| `F-ObservabilityProbe-Threshold` | Each important claim has a metric, log, signpost, artifact, or AnswerPacket field with pass/fail threshold and redaction policy. | "It should work" claims with no witness. |
| `F-MigrationRail-KillSwitch` | Migration fixtures prove compatibility shim, validation step, kill switch, and rollback state before replacing old behavior. | One-way migrations and prompt/doc-only migration plans. |
| `F-ImportGateCard-LicenseSetup` | External repos are classified as source-mine-only, vendor candidate, or rejected with license, dependency, setup, security, maintenance, and benchmark notes. | Copy-paste imports, AGPL drift, and unreviewed dependency adoption. |
| `F-SimplicityBudget-NoIndirection` | The mechanism proves complexity buys reduced duplication, user-visible value, performance value, or testability without increasing hidden authority. | Wrapper stacks, abstract factories, and "architecture" that only adds distance. |
| `F-EngineeringLogic-NoHiddenAuthority` | A proposed component routes through existing organs and visible proof surfaces; any new authority is explicitly rejected or escalated to architecture review. | Parallel Eidos, parallel memory, parallel router, hidden model self-router, or secret cache authority. |

## Required fixture families

1. **Architecture doc claim.** A doctrine paragraph proposes a new mechanism
   and must produce a DecisionRecord plus InvariantLedger row.
2. **Swift actor boundary.** A UI state change crosses from main actor to
   worker actor and back.
3. **Rust/FFI boundary.** A Swift caller passes data to Rust and receives
   owned or borrowed memory.
4. **Editor hot path.** Rapid typing or AI streaming exercises debounce,
   projection, and undo protection.
5. **Cold residency route.** A candidate route wakes cold pages, KV, adapters,
   or evidence and must declare active/cold budgets.
6. **Neural route prior.** Eidos or NeuralImportanceAtlas proposes a model
   support set and must expose baseline, ablation, and interference risk.
7. **Data migration.** A sidecar or cache schema changes with old fixtures
   still present.
8. **Imported repo motif.** A public source appears in a proposed plan and
   must pass license/setup/import classification.
9. **Failure injection.** Disk, privacy, model mismatch, parse failure,
   cancellation, and timeout fixtures trigger fallbacks.
10. **No-hidden-authority scan.** A PR introduces a new service, manager,
    router, cache, or memory object and must prove it calls existing organs.

## Build order

1. Define schema-only artifacts for DecisionRecord, InvariantLedger,
   BoundaryContract, BudgetVector, FailureEnvelope, and ObservabilityProbe.
2. Add `F-DecisionRecord-Completeness` and
   `F-InvariantLedger-Completeness` over doc/backlog fixtures.
3. Add `F-BoundaryContract-SendableOwnership` for a small Swift actor or
   Rust/FFI boundary.
4. Add `F-BudgetVector-HotPath` and
   `F-HotPathProofCard-NoAllocationSpike` over one existing editor/UI hot path.
5. Add `F-FailureEnvelope-Rollback` before any mutation-heavy route.
6. Add migration and import gates before schema or dependency changes.
7. Add `F-EngineeringLogic-NoHiddenAuthority` as a static/docs review gate
   before new services or managers promote.

## Product locks

- Engineering logic is a promotion grammar, not a new runtime organ.
- Live behavior still routes through UAS/OAS, Eidos, ActiveAssembly,
  SCOPE-Rex/SovereignGate, RuntimeRouter/System G, RunEventLog, and
  AnswerPacket.
- A mechanism can remain ambitious as Pro Research or TargetOnly while its
  proof artifacts mature.
- No source import happens before ImportGateCard.
- No hidden authority, hidden cache, hidden model self-router, or hidden
  mutation path can pass this bundle.

## Companion gates

- Semantic working-set compiler:
  `docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md`
- Meta-breakthrough control surfaces:
  `docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md`
- Constructive residency:
  `docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`
- Residency PatternBoost:
  `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`
- Cache-lineage autoresearch:
  `docs/falsifiers/F-CACHE-LINEAGE-AUTORESEARCH-BUNDLE_2026_06_01.md`
- Math and portable note systems:
  `docs/falsifiers/F-MATH-NOTE-SYSTEMS-PORTABILITY-BUNDLE_2026_06_01.md`
