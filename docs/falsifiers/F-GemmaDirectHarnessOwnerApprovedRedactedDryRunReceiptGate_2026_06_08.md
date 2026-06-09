# F-GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate - 2026-06-08

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 primary witness.

This gate consumes `F-GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate` and freezes the digest-only redacted dry-run receipt contract required before a future Gemma first-token review can exist. It does not write a receipt, open owner paths, hash model files, inspect or execute `llama.cpp`, spawn a process, retain raw prompt/stdout/stderr/token bytes, load model bytes, call providers, mutate RuntimeRouter/System G/settings/defaults, emit a user-facing AnswerPacket, or make Gemma live/default/L2/L3/T4.

## Artifact

- Command: `Tools/falsifiers/f_gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate.sh`
- Source: `agent_core/src/uas/gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate.rs`
- Falsifier: `agent_core/src/bin/falsify_gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate.rs`
- Artifact: `artifacts/falsifiers/gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate/result.json`
- Upstream: `artifacts/falsifiers/gemma_direct_harness_owner_approved_command_envelope_gate/result.json`
- Next cursor: `gemma_direct_harness_owner_approved_first_token_digest_review_gate`

## What It Proves

- The upstream command envelope gate must already pass.
- The redacted receipt contract requires 28 fields and 51 abort conditions.
- Owner/model/llama.cpp identity, exit/timeout/teardown policy, stdout/stderr/first-token/prompt digest policy, redaction maps, output/token byte caps, memory/timing samples, temp/atomic/cleanup policy, rollback, RunEventLog, AnswerPacket, abstention, human-visible confirmation, no-route-mutation proof, quality denial, and non-promotion are bound.
- The witness rejects 48 red fixtures covering missing/duplicate fields, missing proof boundaries, receipt write/read, temp/owner/model/llama path opens, command arming/execution, process spawn, model/runtime/provider byte loads, raw prompt/output/stdout/stderr/token retention, route/settings mutation, hidden authority, cloud fallback, quality/product claims, live dense 70B claims, and SSD-as-RAM claims.
- The UAS address is deterministic under set reordering.

## What It Does Not Prove

- No local Gemma file exists because of this witness.
- No redacted receipt was actually written.
- No owner path, model file, or `llama.cpp` binary was opened or hashed.
- No process was spawned and no first token was produced.
- No quality, memory fit, latency, route admission, WRV, MAS, or release-readiness claim was advanced.
- No live dense 70B or live large-model claim is promoted.

## Layer Truth

- L1 architecture/canon: advanced as metadata-only T1/L1 side-ladder evidence.
- L1 guard-owned product cursor: unchanged unless the regenerated architecture guard says otherwise.
- L2 capability route: unchanged and red.
- L3 user-facing / north star: unchanged and red.

Correct phrasing: "Gemma now has a landed redacted dry-run receipt contract; Gemma is still not live, default, L2/L3, T4, or user-facing."
