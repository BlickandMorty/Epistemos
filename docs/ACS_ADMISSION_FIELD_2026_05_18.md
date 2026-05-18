# ACS Admission Field - 2026-05-18

## Placement

ACS (Anchored Cognitive Substrate (structure-view) / Autopoietic Cognitive Stack (process-view)) is the admission field above SCOPE-Rex. It is not a hot-path kernel, model-inference path, cloud fallback, or direct state mutator.

The admission order is:

1. Caller forms a typed request.
2. ACS evaluates policy, capabilities, risk, and bypass constraints.
3. ACS emits a pure-data verdict plus an audit record.
4. Only allow / allow-with-warning verdicts may proceed toward SCOPE-Rex witnessed durable mutation.

## Verdict Layer

The Rust surface is `agent_core/src/acs_admission/`.

Load-bearing types:

- `ACSAdmissionInput` is a closed-schema validated decode envelope carrying a typed payload, risk vector, request time, closed-schema canonical granted capability payloads including trim-stable `VaultPath` paths, `VaultPath` verbs, and `NetworkHost` hosts, and a canonical request ID.
- `ACSAdmissionVerdict` is the pure-data verdict enum: allow, allow-with-warning, defer, quarantine, reject.
- `ACSRiskVector` is a closed-schema validated decode surface and keeps all risk axes finite and bounded.
- `ACSPolicy` is a closed-schema validated decode object identified by a canonical policy ID; risk thresholds and capability rules are validated decode surfaces, operation-specific threshold overrides and set-like required capability rules are validated before a decoded policy can be used, required `VaultPath` paths must be trim-stable, while named required capabilities, `VaultPath` verbs, and `NetworkHost` hosts use the same canonical ASCII token alphabet.
- `ACSAuditRecord` is emitted for every verdict as a closed-schema validated decode surface with canonical ASCII token IDs, a `record_id` bound to its request ID and emitted time, and a canonical reason token; allowing reason tokens are reserved for allowing verdicts.

Every ACSAdmissionVerdict emits exactly one closed-schema validated decode `ACSAdmissionDecision` with one `ACSAuditRecord` at the admission seam, and decoded decisions must keep their top-level verdict aligned with the embedded audit record. Allow and allow-with-warning can proceed to downstream durable guards. Defer is the only retryable verdict and has a budget of three prior attempts; quarantine and reject are terminal.

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

No ACS admission path calls cloud services, runs model inference, or applies durable state directly.

Required string fields inside typed payloads must be nonblank and trim-stable; boundary-spaced payload IDs, active support IDs, hashes, tool names, targets, and addresses are rejected as forged admission input. `MemoryWrite`, `ToolAction`, and `KernelPromotion` bodies are validated decode objects, and `ActiveAssemblyPacket` and `ModelAdaptation` bodies remain closed-schema objects.

## Bypass Rules

Durable memory writes must carry a MutationEnvelope integration point. Kernel promotion requests must also carry a MutationEnvelope integration point plus a signed plan hash. Model adaptation requests must carry a MutationEnvelope integration point plus a checkpoint hash. Missing, blank, or boundary-spaced integration points are rejected and audited as bypass attempts. Downstream durable commit seams should call `guard_durable_commit` with the emitted `ACSAuditRecord`; missing records and defer/quarantine/reject verdicts fail closed.

## W-Row: T11 RunEventLog Wiring

Owner: T11 `agent_runtime_v2/` phase 2 fusion.

Contract: `ACSAuditSink::record(ACSAuditRecord)` is wired to the existing append-only RunEventLog substrate through `ACSRunEventLogSink`. The sink stores each validated audit record as a closed-schema `acs.audit.record` row keyed by `ACSAuditRecord.record_id` and rejects invalid RunEventLog chains plus duplicate record IDs; `resolve_acs_audit_record` is the read-side resolver for proof consumers and rejects invalid RunEventLog chains, duplicate record references, and rows with extra unaudited fields. `InMemoryACSAuditSink` remains the test-only sink for pure policy tests and mirrors duplicate record ID rejection.

## W-Row: SCOPE-Rex Admission Proof

Owner: T11 / SCOPE-Rex fusion consumer.

Contract: SCOPE-Rex receives `SCOPERexAdmissionProof`, not the full audit body. The proof carries `ACSAdmissionVerdict`, `ACSOperationKind`, canonical `AuditRecordId` shaped as `acs:<request>:<decimal-suffix>` where `<request>` uses the canonical ACS audit-token alphabet and `<decimal-suffix>` has no leading-zero aliases, and `CapabilitySignature`; `AuditRecordId` decoding rejects non-canonical references, `CapabilitySignature` decoding rejects non-canonical lowercase-hex signatures, and proof decoding rejects non-allowing verdicts plus unknown fields so a full `ACSAuditRecord` cannot be smuggled into the proof envelope. Proof construction and validation reject non-allowing verdicts before signing and reject non-canonical lowercase-hex signatures. `signed_from_record` signs a domain-separated payload containing the verdict, operation, and record reference so tampering with any of them invalidates `verify_signature`. `verify_against_run_event_log` resolves the referenced RunEventLog record and verifies it in one call; `verify_against_record` remains the lower-level primitive. Mismatched record IDs, mismatched operations, mismatched verdicts, missing records, and invalid signatures fail closed. The `ACSAuditRecord` remains in RunEventLog; SCOPE-Rex consumes the signed record reference.

## Layer Cross-Link

ACS-L0 is current event/governance admission for MAS-shippable durable flow: `MutationEnvelope`, `MemoryWrite`, and `AnswerPacket`.

ACS-L1 is agent/tool-loop admission for MAS-shippable agent streams before durable effects: `ToolAction` and `ActiveAssemblyPacket`.

ACS-L2 is self-healing/research admission for Pro-only or Research-lane evolution: `KernelPromotion` and `ModelAdaptation`. These remain above SCOPE-Rex and require rare capability checks, stricter reject thresholds, and audit evidence before any durable runtime lane can consume them.

Rust exposes these product lanes through `ACSLane.product_lane_code()`: `event_governance`, `agent_tool_loops`, and `self_healing_research`. Persisted audit records and SCOPE-Rex proofs expose the same classification through `lane()` and `product_lane_code()`.

Canon cross-links:

- `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T18B
- `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` MASTER_FUSION §3.8
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` ACS five-layer recursion and SCOPE-Rex / Rex naming rows
