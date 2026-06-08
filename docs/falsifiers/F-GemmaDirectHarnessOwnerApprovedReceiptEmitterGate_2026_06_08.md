# F-GemmaDirectHarnessOwnerApprovedReceiptEmitterGate - 2026-06-08

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 primary witness.

## What It Proves

`F-GemmaDirectHarnessOwnerApprovedReceiptEmitterGate` consumes the landed `F-GemmaDirectHarnessArtifactReceiptMap` witness and defines the fail-closed emitter contract for a future owner-approved bounded Gemma `llama-cli` receipt.

The witness binds 33 required emitter fields, 42 abort conditions, owner approval, owner path-manifest digest, upstream receipt-map digest, model file digest, llama.cpp binary/version digest, command-template digest, argv/environment/workdir digest, prompt/grammar digest, process/timeout/cancel/teardown/stdout/stderr policy, token redaction, timing and memory samplers, atomic write, cleanup, RunEventLog, AnswerPacket, rollback, abstention, and non-promotion.

## What It Does Not Prove

This witness does not write or read a receipt, open a local model path, inspect or execute llama.cpp, arm or run a command, capture a first token, load model/runtime/provider bytes, prove Gemma quality, prove memory fit, admit a RuntimeRouter/System G route, wire settings, or make Gemma live/default/MAS/L2/L3/T4/user-facing.

Correct phrasing: "Gemma now has a landed owner-approved receipt-emitter contract for future direct harness artifacts; Gemma is still not live, default, L2/L3, or user-facing."

## Artifact

- Command: `Tools/falsifiers/f_gemma_direct_harness_owner_approved_receipt_emitter_gate.sh`
- Artifact root: `artifacts/falsifiers/gemma_direct_harness_owner_approved_receipt_emitter_gate/`
- Result: `artifacts/falsifiers/gemma_direct_harness_owner_approved_receipt_emitter_gate/result.json`
- Source: `agent_core/src/uas/gemma_direct_harness_owner_approved_receipt_emitter_gate.rs`
- Falsifier: `agent_core/src/bin/falsify_gemma_direct_harness_owner_approved_receipt_emitter_gate.rs`

## Key Axes

- Upstream receipt-map pass and reference binding.
- Required emitter field and abort-condition set integrity.
- Owner/source/model/runtime/command digest requirements.
- Process, timeout, cancellation, teardown, stdio, token redaction, timing, memory, atomic write, and cleanup policies.
- RunEventLog, AnswerPacket, rollback, and abstention binding.
- Deferred receipt write/read with zero future receipt bytes.
- Zero command, file, model, runtime, and provider action.
- Raw owner path, prompt, output, stdout, stderr, token, and non-digest receipt field denial.
- RuntimeRouter/System G/settings/default/parallel-authority mutation denial.
- Hidden route/Eidos/lattice/PatternBoost/cloud authority denial.
- Quality, MAS, L2, L3, T4, default-Gemma, live dense 70B, and SSD-as-RAM claim denial.
- Deterministic UAS address and next cursor binding.

## Metrics

- Required emitter fields: 33.
- Required abort conditions: 42.
- Red-fixture rejections: 54.
- Future receipt bytes written/read: 0 / 0.
- Command armed/executed: 0 / 0.
- File opens: 0.
- Model/runtime/provider bytes or calls: 0 / 0 / 0.
- Raw owner path/prompt/output/stdout/stderr/token bytes: 0.
- Mutation, hidden-authority, and promotion claim counts: 0.

## Layer Truth

- L1 architecture/canon: advanced as metadata-only side-ladder evidence.
- L1 guard-owned product cursor: still `small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
- L2 capability route: unchanged and still `vault_research_route_with_packetized_mitigation`.
- L3 user-facing / release readiness: unchanged and still red.

## Next

Next side-ladder unit: `gemma_direct_harness_receipt_emitter_dry_run_artifact_gate`.
