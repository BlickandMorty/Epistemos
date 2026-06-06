---
falsifier: F-SmallCompressedModel-LiveHarnessPreflight
created_on: 2026-06-06
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/small_compressed_model_live_harness_preflight/result.json
---

# F-SmallCompressedModel-LiveHarnessPreflight

## Purpose

This is the executable metadata-only witness that turns
`F-CompressedRoute-AnswerPacket-DryRun` packets into a constrained owner-approval
lease for the first small compressed-model runtime probe.

Epistemos is a local cognitive substrate where every meaningful object has an
address, plane, budget, status, and witness; MAS ships the safe floor, Pro
contains the gated/research/vault/omega ladder, and no claim promotes without
visible proof.

## Command

```bash
Tools/falsifiers/f_small_compressed_model_live_harness_preflight.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/small_compressed_model_live_harness_preflight/result.json`
- scope: metadata-only; `model_bytes_loaded=0`, `runtime_bytes_loaded=0`,
  and `provider_calls_made=0`

The artifact passes with 2 accepted preflight candidates and 56 red-fixture
rejections. The selected future probe candidate is
`gemma4_e2b_qat_gguf_harness_preflight` on the GGUF/llama.cpp lane. E4B is
visible as a deferred alternate. LiteRT-LM requires later package proof. MLX
Swift remains blocked by the loader-caveat witness until local loader support
is proven. Owner approval is required and not granted by this witness.

## Hard Rejections

The witness rejects duplicate candidate IDs, duplicate model/runtime lanes,
bad upstream packet refs, bad runtime-doc refs, bad owner-approval refs, bad
memory-ledger refs, missing blocked-lane refs, E4B selected as primary, MLX
selected as primary, 12B or 31B insertion, owner approval being marked granted,
missing owner-approval requirement, undeferred runtime, live execution,
first-token claims, retained token digest claims, zero declared bytes,
file-size-as-memory route planning, zero context tokens, retained-token budget
other than one, invalid planned route bytes, cancellation after timeout, opened
model/runtime bytes, resident model/runtime bytes, model/runtime byte loads,
provider calls, missing AnswerPacket, missing RunEventLog, missing rollback,
missing cancellation, missing selected-model/runtime-lane/byte-plan visibility,
MAS product build, Pro Live status, T2+ promotion, quality claims, L2/L3 green
claims, MAS readiness, hidden cloud fallback, hidden route authority, route
mutation, live dense 70B claims, SSD-as-RAM claims, metadata overflow, missing
L1/L2/L3 separation, undeferred set runtime, unblocked product promotion,
missing MLX Swift caveat, and missing LiteRT package-proof requirement.

## Non-Promotion Rule

This falsifier does not run MLX, GGUF, LiteRT, Transformers, llama.cpp, or
custom Metal; does not load Gemma QAT weights; does not prove first token,
quality, tool use, runtime parity, Swift MLX support, MAS readiness, L2
capability, L3 user-facing behavior, live dense 70B, or live sparse 70B. It
advances T1/L1 metadata architecture only. L2 capability and L3 product
runtime remain unchanged.

## Queue Effect

`F-SmallCompressedModel-LiveHarnessPreflight` gives the model ladder a safe
owner-approval lease for a future `small_compressed_model_owner_approved_runtime_probe`.
The guard-owned product cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
