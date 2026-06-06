---
falsifier: F-SmallCompressedModel-OwnerApprovalRuntimeGate
created_on: 2026-06-06
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/small_compressed_model_owner_approval_runtime_gate/result.json
---

# F-SmallCompressedModel-OwnerApprovalRuntimeGate

## Purpose

This is the executable metadata-only witness that turns
`F-SmallCompressedModel-LiveHarnessPreflight` into a fail-closed command gate
for the first tiny compressed-model runtime probe.

Epistemos is a local cognitive substrate where every meaningful object has an
address, plane, budget, status, and witness; MAS ships the safe floor, Pro
contains the gated/research/vault/omega ladder, and no claim promotes without
visible proof.

## Command

```bash
Tools/falsifiers/f_small_compressed_model_owner_approval_runtime_gate.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/small_compressed_model_owner_approval_runtime_gate/result.json`
- scope: metadata-only; `model_bytes_loaded=0`, `runtime_bytes_loaded=0`,
  and `provider_calls_made=0`

The artifact passes with 1 owner-approval gate and 64 red-fixture rejections.
The selected future probe is still `gemma4_e2b_qat_gguf_harness_preflight` on
the GGUF/llama.cpp lane, but this witness records owner approval as pending,
the runtime command as not armed, and the command as not executed.

## Hard Rejections

The witness rejects duplicate gates, duplicate selected candidates, bad
upstream preflight refs, bad selected-candidate refs, bad owner-approval refs,
bad command-ledger refs, bad model-path refs, bad memory-ledger refs, missing
denied-route refs, bad denied-route prefixes, E4B/12B/31B selection, MLX Swift
selection, owner approval marked granted, approved status, missing owner
approval requirement, armed commands, executed commands, live execution,
first-token claims, retained token digest claims, invalid route-byte totals,
file-size-as-memory planning, retained-token budgets other than one,
cancellation after timeout, opened model/runtime bytes, resident model/runtime
bytes, model/runtime byte loads, provider calls, missing AnswerPacket,
missing RunEventLog, missing rollback, missing cancellation, missing memory
ledger, missing command/model/denied-route/byte-plan visibility, MAS product
build, Pro Live status, T2+ promotion, quality claims, L2/L3 green claims,
MAS readiness, hidden cloud fallback, hidden route authority, route mutation,
live dense 70B claims, SSD-as-RAM claims, 12B/31B permission, MLX Swift loader
permission, LiteRT without package proof, KV-Direct 128K shard permission,
mmap/SSD stress permission, gate metadata overflow, missing L1/L2/L3
separation, undeferred set runtime, and unblocked product promotion.

## Non-Promotion Rule

This falsifier does not run MLX, GGUF, LiteRT, Transformers, llama.cpp, or
custom Metal; does not load Gemma QAT weights; does not prove first token,
quality, tool use, runtime parity, Swift MLX support, LiteRT package support,
MAS readiness, L2 capability, L3 user-facing behavior, live dense 70B, or live
sparse 70B. It advances T1/L1 metadata architecture only. L2 capability and
L3 product runtime remain unchanged.

## Queue Effect

`F-SmallCompressedModel-OwnerApprovalRuntimeGate` gives the model ladder a
visible fail-closed command envelope for a future
`small_compressed_model_owner_approved_runtime_probe`. The guard-owned product
cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
