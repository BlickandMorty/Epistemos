---
falsifier: F-SmallCompressedModel-LocalRuntimeCommandCard
created_on: 2026-06-06
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/small_compressed_model_local_runtime_command_card/result.json
---

# F-SmallCompressedModel-LocalRuntimeCommandCard

## Purpose

This is the executable metadata-only witness that turns
`F-SmallCompressedModel-OwnerApprovalRuntimeGate` into visible local GGUF
command inventory before any owner-approved compressed-model runtime probe can
be armed.

Epistemos is a local cognitive substrate where every meaningful object has an
address, plane, budget, status, and witness; MAS ships the safe floor, Pro
contains the gated/research/vault/omega ladder, and no claim promotes without
visible proof.

## Command

```bash
Tools/falsifiers/f_small_compressed_model_local_runtime_command_card.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/small_compressed_model_local_runtime_command_card/result.json`
- scope: metadata-only; `model_bytes_loaded=0`, `runtime_bytes_loaded=0`,
  and `provider_calls_made=0`

The artifact passes with 2 command cards and 52 red-fixture rejections. It
records `/opt/homebrew/bin/llama-cli` as the only direct local GGUF command
card for the selected `google/gemma-4-E2B-it-qat-q4_0-gguf` future probe, and
records `/opt/homebrew/bin/llama-server` only as a denied-by-default sidecar
card. It preserves the observed local version ref
`local_version:llama.cpp:9370:aa50b2c2a:darwin_arm64:no_model_load:2026_06_06`
as command inventory, not as runtime proof.

## Hard Rejections

The witness rejects missing or wrong command paths, selecting the server
sidecar as the live command, enabling the server sidecar by default, owner
approval marked granted, command armed, command executed, inference executed,
model file opened, first-token claims, retained-token digest claims, opened or
resident model/runtime bytes, model/runtime byte loads, provider calls, missing
AnswerPacket, missing RunEventLog, missing rollback, missing cancellation,
missing memory ledger, missing command/model-path/command-ledger/denied-sidecar
visibility, MAS product build, Pro Live status, T2+ promotion, quality claims,
L2/L3 green claims, MAS readiness, hidden cloud fallback, hidden route
authority, provider fallback, route mutation, live dense 70B claims,
SSD-as-RAM claims, bad proof refs, missing L1/L2/L3 separation, undeferred
set runtime, unblocked product promotion, and metadata-budget overflow.

## Non-Promotion Rule

This falsifier does not run MLX, GGUF inference, LiteRT, Transformers,
llama.cpp inference, or custom Metal; does not open a Gemma QAT model path;
does not prove first token, quality, tool use, memory fit, runtime parity,
Swift MLX support, LiteRT package support, MAS readiness, L2 capability, L3
user-facing behavior, live dense 70B, or live sparse 70B. It advances
research-to-build T1/L1 metadata architecture only. L2 capability and L3
product runtime remain unchanged.

## Queue Effect

`F-SmallCompressedModel-LocalRuntimeCommandCard` proves the next
`small_compressed_model_owner_approved_runtime_probe` must be explicit,
owner-approved, one-token, cancellable, rollback-bound, memory-ledgered,
RunEventLog-bound, AnswerPacket-visible, and unable to fall back to a provider
or default server sidecar. The guard-owned product cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
