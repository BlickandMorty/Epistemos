# T18B — `acs_admission` decompose layout (2026-05-22)

Pure-refactor decompose of the monolithic `agent_core/src/acs_admission/mod.rs`
(13,612 LOC, 379 unit tests) into reviewable submodules. No behaviour change,
no new tests. Mirrors the T17B convention.

Branch: `codex/t18b-acs-admission-field-2026-05-18`.

## Final layout

```
agent_core/src/acs_admission/
├── mod.rs                              37 LOC  — façade: mod decls + pub re-exports
├── common.rs                           11      — shared consts (audit run-event key, proof
│                                                 domain, capability signature byte count,
│                                                 audit-token prefixes)
├── risk.rs                            312      — ACSRiskVector + ACSRiskVectorError +
│                                                 ACSOperationKind + ACSLane
├── wire.rs                            559      — ACSAdmissionPayload + mutation envelope
│                                                 wire types (actor / source-op / relation /
│                                                 artifact-ref / block-ref wires)
├── validation.rs                      680      — validate_answer_packet + validate_mutation_
│                                                 envelope + supporting claim/relation/
│                                                 finite-signal predicates
├── requests.rs                        436      — ActiveAssemblyPacket + ACSMemoryWriteRequest
│                                                 + ACSToolActionRequest +
│                                                 ACSKernelPromotionRequest +
│                                                 ACSModelAdaptationRequest
├── input.rs                           367      — ACSAdmissionInput + ACSAdmissionInputError
│                                                 + input-side decode + capability-shape
│                                                 checks
├── verdict.rs                         516      — ACSAdmissionVerdict + ACSAuditRecord +
│                                                 AuditRecordId + audit-token canonicalisation
├── proof.rs                           539      — CapabilitySignature + SCOPERexAdmissionProof
│                                                 + proof error variants + payload-bytes
│                                                 helpers + hex codec
├── decision.rs                         83      — ACSAdmissionDecision
├── audit_sink.rs                      575      — ACSAuditSink trait + ACSAuditError +
│                                                 ACSRunEventLogSink + InMemoryACSAuditSink
│                                                 + resolve_acs_audit_record lookup
├── admit.rs                           347      — admit / admit_and_log / admit_and_record
│                                                 entry points + guard_durable_commit +
│                                                 ACSDurableCommitError + capability-creep
│                                                 helpers + audit-token formatters
├── policy.rs                         1003      — ACSRiskThresholds + ACSCapabilityRule +
│                                                 ACSOperationThresholdRule + ACSPolicy +
│                                                 ACSPolicyError + CapabilityFieldNames /
│                                                 CapabilityShadowFieldNames lookup tables
├── tests.rs                           157      — test parent: shared fixture helpers
│                                                 (`tool_action_payload`,
│                                                  `high_risk_operation_payload`,
│                                                  `mutation_envelope_fixture`,
│                                                  `assert_mutation_envelope_payload_decode_rejects`,
│                                                  `audit_record_fixture`,
│                                                  `CountingSigningKey`) + sub-module decls
└── tests/
    ├── admission_basics.rs           1184  (51 tests) — risk-vector + lane + operation-kind
    │                                                    contracts; default-policy matrix;
    │                                                    malformed-policy; capability shape
    │                                                    basics
    ├── capability_and_threshold.rs   1251  (72 tests) — granted/required capability acceptance
    │                                                    & rejection; per-operation thresholds;
    │                                                    threshold-namespace tests; risk
    │                                                    threshold edges
    ├── payload_field_validation.rs   1171  (46 tests) — payload decode rejections; shadow
    │                                                    field rejections on each sub-request
    │                                                    type (memory_write / tool_action /
    │                                                    kernel_promotion / model_adaptation)
    ├── proof_and_audit_sink.rs       1267  (42 tests) — SCOPE-Rex admission-proof decode +
    │                                                    verification + chain + sink contracts;
    │                                                    run-event-log sink invariants
    ├── capability_rule_decode.rs     1253  (59 tests) — ACSCapabilityRule decode + shape rules
    │                                                    + policy-field rejections; missing
    │                                                    capability-rule decode paths
    ├── policy_field_decode.rs        1252  (51 tests) — ACSPolicy / ACSRiskThresholds /
    │                                                    ACSOperationThresholdRule field
    │                                                    decode + shape errors; answer-packet
    │                                                    duplicate-claim detection
    └── audit_record_and_shadows.rs   1258  (57 tests) — ACSAuditRecord decode + corrupt-row
                                                         detection; answer-packet residency
                                                         + retracted-basis cases; shadow
                                                         field-name corruption guards
```

Totals: 13 production files + 1 test parent + 7 test sub-modules.
All production files ≤ 1,003 LOC; all test files ≤ 1,267 LOC.
mod.rs façade is 37 LOC.

## Public-API surface

Unchanged. `crate::acs_admission::*` re-exports every previously-`pub` item
from its new home submodule via `pub use foo::*;` globs in `mod.rs`. Callers
(e.g. `agent_core::agent_runtime`, `bridge.rs`, etc.) need no edits.

## Visibility lifts

The split crosses several previously-internal call sites. Each lift is from
file-private to `pub(crate)` — no item becomes externally `pub` that wasn't
already.

- **policy.rs**
  - `CapabilityFieldNames` struct + 5 fields (used from input.rs against
    the `GRANTED_CAPABILITY_FIELDS` lookup)
  - `CapabilityShadowFieldNames` struct + 6 fields (used from input.rs and
    policy's own shadow-field rejection paths)
- **requests.rs**: `validate()` on each of the 5 sub-request types (called
  from `wire.rs` `ACSAdmissionPayload::validate` dispatcher)
- **wire.rs**: `ACSAdmissionPayload::validate` (called from `input.rs`)
- **verdict.rs**: `AuditRecordId::validate` (called from `audit_sink.rs` +
  `proof.rs`)
- top-level private fns + consts in each extracted submodule are now
  `pub(crate)` (cross-module helpers like `is_canonical_*`,
  `audit_request_id`, `require_*`, `MALFORMED_*_AUDIT_PREFIX`, etc.)

## Module dependency map

```
common ── (no internal deps)
risk   ── (no internal deps)
wire   ── risk, requests
requests ── (no internal deps within acs_admission)
validation ── wire
input  ── wire, policy (capability field names + validate helpers),
          risk, requests
verdict ── risk, proof (for AuditRecordId::validate ProofError variant)
proof   ── common, verdict
decision ── input, risk, verdict
audit_sink ── common, verdict, proof, risk, decision
admit  ── common, risk, input, verdict, decision, audit_sink, policy
policy  ── common, risk, requests
```

Cycles avoided. The façade `pub use` order in `mod.rs` is alphabetical;
Rust resolves these regardless of declaration order.

## Iteration history

This decompose landed across three commits on
`codex/t18b-acs-admission-field-2026-05-18`:

| Iter | Commit       | Scope                                            |
|------|--------------|--------------------------------------------------|
| 1    | `68e60ef435` | Verbatim extract of `mod tests { … }` body into  |
|      |              | `tests.rs`. mod.rs: 13,612 → 5,108 LOC.          |
| 2    | `e0ad3c62ae` | Split production body (5,106 LOC) into 12        |
|      |              | submodules listed above. mod.rs becomes a 38-LOC |
|      |              | façade.                                          |
| 3    | (this commit)| Split `tests.rs` (8,528 LOC) into 7 topic        |
|      |              | sub-modules + slim 157-LOC parent holding shared |
|      |              | fixture helpers.                                 |

## Verification

`cargo test --manifest-path agent_core/Cargo.toml --lib`:

```
test result: ok. 2050 passed; 0 failed; 0 ignored; 0 measured;
0 filtered out
```

379 `acs_admission::tests::*` tests included — matches the pre-split count
exactly. Zero behaviour change, zero regression.

## Next step (out of scope for this decompose)

Namespace collision with T17B's `research/acs/` submodules (now-decomposed
on `codex/t17b-lattice-wbo-register-2026-05-18`) is documented separately
in `docs/T18B-NAMESPACE-PROPOSAL-2026-05-22.md`. That doc proposes only —
no code changes pending arbitration.
