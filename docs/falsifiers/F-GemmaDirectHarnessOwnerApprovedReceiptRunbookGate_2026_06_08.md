# F-GemmaDirectHarnessOwnerApprovedReceiptRunbookGate - 2026-06-08

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 primary witness.

## What It Proves

`F-GemmaDirectHarnessOwnerApprovedReceiptRunbookGate` consumes the landed `F-GemmaDirectHarnessReceiptEmitterDryRunArtifactGate` witness and freezes the owner-approved runbook contract before a future bounded Gemma `llama-cli` receipt attempt can be armed.

The witness binds 34 runbook fields, 46 abort conditions, owner approval, owner identity, owner path manifest, model file digest, llama.cpp binary/version digest, command template, argv/environment/workdir policy, prompt/grammar policy, context/predict caps, seed/timeout/cancel/teardown, stdout/stderr redaction, memory/timing samplers, temp/atomic/cleanup policy, RunEventLog, AnswerPacket, rollback, abstention, human-visible confirmation, and non-promotion.

## What It Does Not Prove

This witness does not write or read a runbook, open an owner path, open a model file, inspect or execute llama.cpp, arm or run a command, capture a first token, load model/runtime/provider bytes, prove Gemma quality, prove memory fit, admit a RuntimeRouter/System G route, wire settings, or make Gemma live/default/MAS/L2/L3/T4/user-facing.

Correct phrasing: "Gemma now has a landed owner-approved receipt runbook contract; Gemma is still not live, default, L2/L3, or user-facing."

## Artifact

- Command: `Tools/falsifiers/f_gemma_direct_harness_owner_approved_receipt_runbook_gate.sh`
- Artifact root: `artifacts/falsifiers/gemma_direct_harness_owner_approved_receipt_runbook_gate/`
- Result: `artifacts/falsifiers/gemma_direct_harness_owner_approved_receipt_runbook_gate/result.json`
- Source: `agent_core/src/uas/gemma_direct_harness_owner_approved_receipt_runbook_gate.rs`
- Falsifier: `agent_core/src/bin/falsify_gemma_direct_harness_owner_approved_receipt_runbook_gate.rs`

## Metrics

- Required runbook fields: 34.
- Required abort conditions: 46.
- Red-fixture rejections: 52.
- Future runbook bytes written/read: 0 / 0.
- Owner path opens: 0.
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

Next side-ladder unit: `gemma_direct_harness_owner_approved_receipt_preflight_packet_gate`.
