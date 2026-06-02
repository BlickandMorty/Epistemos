# SCOPE-Rex Admission Field + AcsAnchor Link - 2026-05-18

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

> **Current namespace supersession (2026-05-31):** this file name and the
> Rust module path `agent_core/src/acs_admission/` predate the namespace lock.
> Current canon reads this surface as **SCOPE-Rex Admission / SovereignGate**.
> **AcsAnchor** supplies anchored coordinate, provenance, and residency
> projection. SCOPE-Rex owns allow / warn / defer / quarantine / reject
> governance. New docs/UI must use SCOPE-Rex admission, not the old ACS wording.

## Placement

SCOPE-Rex Admission / SovereignGate is the admission field. AcsAnchor
(anchored cognitive substrate) supplies the anchored coordinate/provenance
projection that admission may reference. Neither layer is a hot-path kernel,
model-inference path, cloud fallback, or direct state mutator.

The admission order is:

1. Caller forms a typed request.
2. SCOPE-Rex Admission evaluates policy, capabilities, risk, and bypass constraints.
3. SCOPE-Rex Admission emits a pure-data verdict plus an audit record.
4. Only allow / allow-with-warning verdicts may proceed toward witnessed durable mutation.

## Verdict Layer

The legacy Rust surface is `agent_core/src/acs_admission/`. The type names
remain until a code migration lands; current product prose should call the
surface SCOPE-Rex Admission / SovereignGate and reserve AcsAnchor for the
anchoring/projection layer.

Load-bearing types:

- `ACSAdmissionInput` is a closed-schema validated decode envelope carrying a typed payload, risk vector, request time, closed-schema canonical granted capability payloads including trim-stable `VaultPath` paths, `VaultPath` verbs, and `NetworkHost` hosts, and a canonical request ID.
- `ACSAdmissionVerdict` is the pure-data verdict enum: allow, allow-with-warning, defer, quarantine, reject.
- `ACSRiskVector` is a closed-schema validated decode surface and keeps all risk axes finite and bounded.
- `ACSPolicy` is a closed-schema validated decode object identified by a canonical policy ID; risk thresholds and capability rules are validated decode surfaces, operation-specific threshold overrides and set-like required capability rules are validated before a decoded policy can be used, required `VaultPath` paths must be trim-stable, while named required capabilities, `VaultPath` verbs, and `NetworkHost` hosts use the same canonical ASCII token alphabet.
- `ACSAuditRecord` is emitted for every verdict as a closed-schema validated decode surface with canonical ASCII token IDs, a `record_id` bound to its request ID and emitted time, and a canonical reason token; allowing reason tokens are reserved for allowing verdicts.

Every legacy `ACSAdmissionVerdict` emits exactly one closed-schema validated decode `ACSAdmissionDecision` with one `ACSAuditRecord` at the admission seam, and decoded decisions must keep their top-level verdict aligned with the embedded audit record. Allow and allow-with-warning can proceed to downstream durable guards. Defer is the only retryable verdict and has a budget of three prior attempts; quarantine and reject are terminal.

Required capability rules and their capability payloads are closed-schema, operation-scoped, and set-like: duplicate `(operation, capability)` pairs make the policy malformed.

Granted capability claims are set-like as well: duplicate capabilities in one admission input are rejected as forged admission input before policy matching.

Closed typed payloads accepted by the field:

- `MutationEnvelope`
- `ActiveAssemblyPacket`
- `AnswerPacket`
- memory write request
- tool/action request
- kernel-promotion request
- model-adaptation request

## Strict default policy matrix

The strict default policy matrix gates the shipped high-risk operations as follows: `MemoryWrite` requires `VaultWrite` with `quarantine_at=0.75`; `ToolAction` requires `ToolExec` with `quarantine_at=0.65`; `ActiveAssemblyPacket` requires `Assembly` with `defer_at=0.55`; `KernelPromotion` requires `KernelPromote` with `reject_at=0.60`; `ModelAdaptation` requires `ModelAdapt` with `reject_at=0.50`.

No SCOPE-Rex admission path calls cloud services, runs model inference, or applies durable state directly.

Required string fields inside typed payloads must be nonblank and trim-stable; boundary-spaced payload IDs, active support IDs, hashes, tool names, targets, and addresses are rejected as forged admission input. `ACSAdmissionPayload` variants validate typed payload invariants during decode; `MutationEnvelope` is closed at the ACS payload boundary; `AnswerPacket` rejects unknown fields at the SCOPE-Rex decode boundary; `MemoryWrite`, `ToolAction`, `ActiveAssemblyPacket`, `KernelPromotion`, and `ModelAdaptation` bodies are validated decode objects.

## Bypass Rules

Durable memory writes must carry a MutationEnvelope integration point. Kernel promotion requests must also carry a MutationEnvelope integration point plus a signed plan hash. Model adaptation requests must carry a MutationEnvelope integration point plus a checkpoint hash. Missing, blank, or boundary-spaced integration points are rejected and audited as bypass attempts. Downstream durable commit seams should call `guard_durable_commit` with the emitted legacy `ACSAuditRecord`; missing records and defer/quarantine/reject verdicts fail closed.

## W-Row: T11 RunEventLog Wiring

Owner: T11 `agent_runtime_v2/` phase 2 fusion.

Contract: legacy `ACSAuditSink::record(ACSAuditRecord)` is wired to the existing append-only RunEventLog substrate through `ACSRunEventLogSink`. The sink stores each validated audit record as a closed-schema `scope_rex.admission.record` / legacy `acs.audit.record` row keyed by `ACSAuditRecord.record_id` and rejects invalid RunEventLog chains plus duplicate record IDs; `resolve_acs_audit_record` is the read-side resolver for proof consumers and rejects invalid RunEventLog chains, duplicate record references, and rows with extra unaudited fields. `InMemoryACSAuditSink` remains the test-only sink for pure policy tests and mirrors duplicate record ID rejection.

## W-Row: SCOPE-Rex Admission Proof

Owner: T11 / SCOPE-Rex fusion consumer.

Contract: SCOPE-Rex receives `SCOPERexAdmissionProof`, not the full audit body. The proof carries legacy `ACSAdmissionVerdict`, legacy `ACSOperationKind`, canonical `AuditRecordId` shaped as `acs:<request>:<decimal-suffix>` where `<request>` uses the canonical admission audit-token alphabet and `<decimal-suffix>` has no leading-zero aliases, and `CapabilitySignature`; `AuditRecordId` decoding rejects non-canonical references, `CapabilitySignature` decoding rejects non-canonical lowercase-hex signatures, and proof decoding rejects non-allowing verdicts plus unknown fields so a full `ACSAuditRecord` cannot be smuggled into the proof envelope. Proof construction and validation reject non-allowing verdicts before signing and reject non-canonical lowercase-hex signatures. `signed_from_record` signs a domain-separated payload containing the verdict, operation, and record reference so tampering with any of them invalidates `verify_signature`. `verify_against_run_event_log` resolves the referenced RunEventLog record and verifies it in one call; `verify_against_record` remains the lower-level primitive. Mismatched record IDs, mismatched operations, mismatched verdicts, missing records, and invalid signatures fail closed. The legacy `ACSAuditRecord` remains in RunEventLog; SCOPE-Rex consumes the signed record reference.

## Phase 2 doc-only contracts

T18B defines shapes only here; T11 owns RunEventLog wire in `agent_runtime_v2/`.

L. `ACSAuditSink trait shape`: `record(&self, record: ACSAuditRecord) -> Result<(), ACSAuditError>`. Implementations must validate the record before accepting it, reject duplicate `record_id` values, preserve per-request verdict monotonicity, and never mutate durable app state directly from SCOPE-Rex admission. `InMemoryACSAuditSink for testing` mirrors those invariants without touching RunEventLog.

M. `SCOPERexAdmissionProof shape`: `{ verdict: ACSAdmissionVerdict, operation: ACSOperationKind, record_id: AuditRecordId, signature: CapabilitySignature }`. The signature binds the domain, verdict, operation, and record reference; SCOPE-Rex receives the proof, then resolves the full `ACSAuditRecord` from RunEventLog through the T11-owned seam.

N. W-row refresh remains doc-only until T11 fusion: W-46 consumes L, W-47 consumes M, and T11 owns RunEventLog wire plus UI propagation. T18B must not implement additional `agent_runtime_v2/` wiring in Phase 1.

## Layer Cross-Link

Legacy `ACS-L0/L1/L2` labels map to current SCOPE-Rex admission planes/statuses.
They are not product builds and do not mean Active Cold Storage.

L0 is current event/governance admission for MAS-shippable durable flow: `MutationEnvelope`, `MemoryWrite`, and `AnswerPacket`.

L1 is agent/tool-loop admission for MAS-shippable agent streams before durable effects: `ToolAction` and `ActiveAssemblyPacket`.

L2 is self-healing / Pro Research admission for Pro-only evolution: `KernelPromotion` and `ModelAdaptation`. These require rare capability checks, stricter reject thresholds, and audit evidence before any durable runtime lane can consume them.

Rust exposes these product lanes through `ACSLane.product_lane_code()`: `event_governance`, `agent_tool_loops`, and `self_healing_research`. Persisted audit records and SCOPE-Rex proofs expose the same classification through `lane()` and `product_lane_code()`.

Canon cross-links:

- `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T18B
- `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` MASTER_FUSION §3.8
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` legacy ACS five-layer recursion, AcsAnchor anchoring, and SCOPE-Rex / Rex naming rows
