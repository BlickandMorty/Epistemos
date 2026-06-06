---
falsifier: F-SmallCompressedModel-ModelPathReadinessCard
created_on: 2026-06-06
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/small_compressed_model_model_path_readiness_card/result.json
---

# F-SmallCompressedModel-ModelPathReadinessCard

## Purpose

This is the executable metadata-only witness that turns
`F-SmallCompressedModel-LocalRuntimeCommandCard` into an explicit model-path
readiness contract before any owner-approved compressed-model runtime probe can
be armed.

Epistemos is a local cognitive substrate where every meaningful object has an
address, plane, budget, status, and witness; MAS ships the safe floor, Pro
contains the gated/research/vault/omega ladder, and no claim promotes without
visible proof.

## Command

```bash
Tools/falsifiers/f_small_compressed_model_model_path_readiness_card.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path:
  `artifacts/falsifiers/small_compressed_model_model_path_readiness_card/result.json`
- scope: metadata-only; `downloaded_model_bytes=0`,
  `opened_model_bytes=0`, `hashed_model_bytes=0`,
  `model_bytes_loaded=0`, `runtime_bytes_loaded=0`, and
  `provider_calls_made=0`

The artifact passes with 1 model-path readiness card and 59 red-fixture
rejections. It records the selected
`google/gemma-4-E2B-it-qat-q4_0-gguf` source, required file
`gemma-4-E2B_q4_0-it.gguf`, source revision
`1894d1fc0a19d86697abd40483f5983c867df03f`, Xet hash
`f9eedc0d3f769aa9c59341e9b230f2d6b4726cc355b1f0101b60a524a6584a30`,
and expected file bytes `3349514112`. The checked local path state is
`missing_or_unverified`; no model path is approved as a runtime input.

## Hard Rejections

The witness rejects wrong model IDs, wrong filenames, missing source revision
or hash, undersized expected bytes, present model paths, present-but-unapproved
status, missing Downloads or Hugging Face cache search scopes, owner approval
marked granted, download approval marked granted, download executed, command
armed, command executed, inference executed, first-token claims, downloaded,
opened, hashed, resident, loaded, or provider bytes, missing AnswerPacket,
missing RunEventLog, missing rollback, missing cancellation, missing memory
ledger, missing source/path/command-card visibility, MAS product build, Pro
Live status, T2+ promotion, quality claims, L2/L3 green claims, MAS readiness,
hidden cloud fallback, hidden route authority, provider fallback, default
server sidecar, route mutation, live dense 70B claims, SSD-as-RAM claims, bad
proof refs, missing L1/L2/L3 separation, undeferred set runtime, unblocked
product promotion, and metadata-budget overflow.

## Non-Promotion Rule

This falsifier does not download, open, hash, load, or run Gemma 4 E2B; does
not prove GGUF loadability, Swift MLX Gemma support, LiteRT support, first
token, quality, tool use, memory fit, runtime parity, MAS readiness, L2
capability, L3 user-facing behavior, live dense 70B, or live sparse 70B. It
advances research-to-build T1/L1 metadata architecture only. L2 capability and
L3 product runtime remain unchanged.

## Larger-Model Ladder Effect

The larger-local-model bias remains intact: E2B is the safety proving lane,
Gemma 4 12B QAT remains the flagship Pro Gated target, and 31B/70B-class
routes remain Pro Research/Vault until residency, routing, transport, memory,
cancellation, rollback, RunEventLog, and AnswerPacket proof exists. This card
prevents that ambition from skipping the model-path proof step.

## Queue Effect

`F-SmallCompressedModel-ModelPathReadinessCard` proves the next
`small_compressed_model_owner_approved_runtime_probe` must be explicit,
owner-approved, one-token, bound to a visible local model path, cancellable,
rollback-bound, memory-ledgered, RunEventLog-bound, AnswerPacket-visible, and
unable to fall back to a provider or default server sidecar. The guard-owned
product cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.

## Sources

- Google Gemma 4 QAT:
  <https://blog.google/innovation-and-ai/technology/developers-tools/quantization-aware-training-gemma-4/>
- Gemma 4 E2B QAT GGUF:
  <https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf>
- llama.cpp:
  <https://github.com/ggml-org/llama.cpp>
