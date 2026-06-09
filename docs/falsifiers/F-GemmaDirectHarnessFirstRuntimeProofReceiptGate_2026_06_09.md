# F-GemmaDirectHarnessFirstRuntimeProofReceiptGate - 2026-06-09

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Verdict

PASS as a metadata-only T1/L1 primary witness.

This gate consumes `F-GemmaDirectHarnessFirstRuntimeProofCommandCard` and `F-GemmaDirectHarnessTrapPolicyGate`, then freezes the digest-only receipt contract required before a future owner-approved local Gemma GGUF execution probe can count as evidence.

It does not write or read a receipt, read the command card, open owner/model/llama.cpp paths, arm or execute a command, spawn a process, start a server, allow network/hub/endpoint routes, load model/runtime/provider bytes, capture raw path/prompt/output/stdout/stderr/token bytes, mutate RuntimeRouter/System G/settings/defaults, emit a user-facing AnswerPacket, or make Gemma live/default/L2/L3/T4.

## Artifact

- Command: `Tools/falsifiers/f_gemma_direct_harness_first_runtime_proof_receipt_gate.sh`
- Result: `artifacts/falsifiers/gemma_direct_harness_first_runtime_proof_receipt_gate/result.json`
- Falsifier id: `F-GemmaDirectHarnessFirstRuntimeProofReceiptGate`
- Next cursor: `gemma_direct_harness_owner_approved_first_runtime_execution_probe`
- Scope: metadata-only; no runtime bytes loaded.

## Bound Axes

- 36 required receipt fields, including `trap_policy_digest`.
- 6 required termination classes: success, nonzero exit, timeout, owner cancellation, signal termination, and teardown failure.
- 67 required abort conditions, including `missing_trap_policy`.
- `stdio_capture_cap_bytes=65536`.
- 73 red fixtures rejected.
- Zero receipt write/read bytes and zero command-card read bytes.
- Zero owner path opens, command arming/execution, process spawn, server start, network/hub/endpoint allowance, file opens, model/runtime/provider bytes, raw private bytes, route/default mutation, hidden authority, and promotion claims.

## Layer Truth

- L1 architecture/canon: advanced with a metadata-only receipt contract for the first practical Gemma local GGUF runtime proof.
- L2 capability route: unchanged. No runtime was executed and no route was admitted.
- L3 user-facing / north star: unchanged. No settings row, diagnostics row, default model toggle, or visible AnswerPacket exists yet.

Correct phrasing: "Gemma now has a landed first-runtime proof receipt contract; Gemma is still not live, default, quality-proven, route-admitted, L2/L3, T4, or user-facing."

## Risk Closed

This gate prevents a future local Gemma execution from laundering a token into capability. The receipt must bind the trap-policy digest, classify exit/termination, timeout/cancel/teardown, timing and memory, stdout/stderr, first token, prompt/output digests, redaction proof, raw-byte-zero proof, rollback, RunEventLog, AnswerPacket, abstention, reviewer-visible summary, no-quality, no-route-admission, and non-promotion before it can feed any later proof.

## Remaining Risk

The exact local `llama-cli` binary/version and owner-approved E2B/E4B GGUF path are still not bound by this gate. The next owner-approved execution probe must bind exact local materials and still remain Pro Gated, non-default, and non-promotional.
