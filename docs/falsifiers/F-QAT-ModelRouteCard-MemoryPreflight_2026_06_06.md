---
falsifier: F-QAT-ModelRouteCard-MemoryPreflight
created_on: 2026-06-06
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/qat_model_route_card_memory_preflight/result.json
---

# F-QAT-ModelRouteCard-MemoryPreflight

## Purpose

This is the executable metadata-only witness that turns
`F-GemmaQAT-LocalRuntimeCandidateCard` candidates into route-card memory
preflights before any compressed-model dry-run can cite them.

Epistemos is a local cognitive substrate where every meaningful object has an
address, plane, budget, status, and witness; MAS ships the safe floor, Pro
contains the gated/research/vault/omega ladder, and no claim promotes without
visible proof.

## Command

```bash
Tools/falsifiers/f_qat_model_route_card_memory_preflight.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/qat_model_route_card_memory_preflight/result.json`
- scope: metadata-only; `model_bytes_loaded=0`, `runtime_bytes_loaded=0`,
  and `provider_calls_made=0`

The artifact passes with 4 accepted route cards and 44 red-fixture rejections.
On the declared M2 Pro 16 GB UMA profile, E2B and E4B Gemma 4 QAT GGUF cards
are admitted only for later dry-run packetization; 12B abstains for
insufficient headroom; 31B remains vault-only. The witness records declared
file bytes, predicted resident bytes, KV bytes, scratch bytes, UMA budget,
reserved system bytes, available route bytes, headroom, timeout,
cancellation deadline, rollback, RunEventLog, AnswerPacket, and compatibility
refs.

## Hard Rejections

The witness rejects duplicate route-card IDs, duplicate model/runtime lanes,
bad upstream candidate refs, missing hardware profile refs, bad route-caveat
refs, zero declared bytes, file-size-as-memory claims, zero KV/scratch floors,
incorrect total route bytes, incorrect available-route bytes, incorrect
headroom, zero timeout/cancellation, cancellation after timeout,
model/runtime byte loads, provider calls, dry-run admission with negative
headroom, insufficient-headroom abstention with positive headroom, 12B dry-run
bypass on this profile, 31B non-vault admission, missing abstention reason,
missing rollback, missing RunEventLog, missing AnswerPacket, bad proof refs,
undeferred runtime, false Swift MLX loader proof, first-token claims, quality
claims, MAS readiness, MAS product build, Pro Live status, T2+ promotion,
hidden cloud fallback, hidden route authority, live dense 70B claims,
SSD-as-RAM claims, missing L1/L2/L3 separation, unblocked product promotion,
and metadata overflow.

## Non-Promotion Rule

This falsifier does not run MLX, GGUF, LiteRT, Transformers, llama.cpp, or
custom Metal; does not load Gemma QAT weights; does not prove first token,
quality, tool use, runtime parity, Swift MLX support, MAS readiness, L2
capability, L3 user-facing behavior, live dense 70B, or live sparse 70B. It
advances T1/L1 metadata architecture only. L2 capability and L3 product
runtime remain unchanged.

## Queue Effect

`F-QAT-ModelRouteCard-MemoryPreflight` gives the model ladder a byte-accounted
route-card preflight for later `F-CompressedRoute-AnswerPacket-DryRun` and
owner-approved small compressed model runtime harness work. The guard-owned
product cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
