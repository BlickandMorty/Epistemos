---
falsifier: F-SmallCompressedModel-RuntimeProbeProofEnvelope
created_on: 2026-06-06
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/small_compressed_model_runtime_probe_proof_envelope/result.json
---

# F-SmallCompressedModel-RuntimeProbeProofEnvelope

## Purpose

This is the executable metadata-only witness that turns
`F-SmallCompressedModel-ModelPathReadinessCard` into the exact proof envelope
required before any owner-approved one-token E2B compressed-model runtime
probe can be armed.

Epistemos is a local cognitive substrate where every meaningful object has an
address, plane, budget, status, and witness; MAS ships the safe floor, Pro
contains the gated/research/vault/omega ladder, and no claim promotes without
visible proof.

## Command

```bash
Tools/falsifiers/f_small_compressed_model_runtime_probe_proof_envelope.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path:
  `artifacts/falsifiers/small_compressed_model_runtime_probe_proof_envelope/result.json`
- scope: metadata-only; `downloaded_model_bytes=0`,
  `opened_model_bytes=0`, `hashed_model_bytes=0`,
  `resident_model_bytes=0`, `model_bytes_loaded=0`,
  `runtime_bytes_loaded=0`, and `provider_calls_made=0`

The artifact passes with 1 runtime-probe proof envelope, 16 required proof
phases, 23 command-template tokens, and 70 red-fixture rejections. It records
the selected `google/gemma-4-E2B-it-qat-q4_0-gguf` source, required file
`gemma-4-E2B_q4_0-it.gguf`, direct command path `/opt/homebrew/bin/llama-cli`,
and a visible offline command template:

```bash
/opt/homebrew/bin/llama-cli --offline --model <OWNER_APPROVED_MODEL_PATH> --prompt <SYNTHETIC_NON_USER_PROMPT> --predict 1 --ctx-size 512 --batch-size 32 --ubatch-size 32 --temp 0 --seed 0 --no-conversation --single-turn --simple-io --no-display-prompt --no-mmap --log-disable
```

No model path is approved as a runtime input, no owner approval is granted, and
the command remains unarmed and unexecuted.

## Required Proof Phases

The envelope requires owner-approval token binding, model-path binding, command
card binding, offline mode, synthetic non-user prompt hash, one-token budget,
context and batch caps, memory-before sample, runtime-start sample, first-token
redaction, cancellation deadline, rollback, RunEventLog, AnswerPacket,
non-promotion, and larger-model escalation blockers.

## Hard Rejections

The witness rejects missing offline mode, missing model or prompt placeholders,
unbounded prediction, oversized context or batch windows, nonzero temperature,
conversation mode, mmap use, hidden HF or URL download flags, Docker/HF-token
flags, server sidecars, owner approval marked granted, download execution,
command arming or execution, inference execution, first-token claims, retained
token digests before runtime, downloaded/opened/hashed/resident/loaded or
provider bytes, missing AnswerPacket, missing RunEventLog, missing rollback,
missing cancellation, missing memory ledger, missing visibility surfaces,
quality claims, L2/L3/MAS promotion, hidden cloud fallback, hidden route
authority, provider fallback, route mutation, live dense 70B claims,
SSD-as-RAM claims, E4B escalation without a new envelope, 12B escalation
without memory repreflight, 31B non-vault routing, 70B non-cold-assembly
claims, bad proof refs, and metadata-budget overflow.

## Non-Promotion Rule

This falsifier does not download, open, hash, load, or run Gemma 4 E2B; does
not prove GGUF loadability, Swift MLX Gemma support, LiteRT support, first
token, quality, tool use, memory fit, runtime parity, MAS readiness, L2
capability, L3 user-facing behavior, live dense 70B, or live sparse 70B. It
advances research-to-build T1/L1 metadata architecture only.

## Larger-Model Ladder Effect

The larger-local-model bias remains intact: E2B is the harness proving lane,
Gemma 4 12B QAT remains the flagship Pro Gated Mac target, and 31B/70B-class
routes remain Pro Research/Vault until residency, routing, transport, memory,
cancellation, rollback, RunEventLog, and AnswerPacket proof exists. This
envelope prevents the large-model ambition from skipping command, path,
memory, cancellation, and packet proof.

## Queue Effect

`F-SmallCompressedModel-RuntimeProbeProofEnvelope` proves the next
`small_compressed_model_owner_approved_runtime_probe` must be explicit,
owner-approved, one-token, bound to a visible local model path, offline,
cancellable, rollback-bound, memory-ledgered, RunEventLog-bound,
AnswerPacket-visible, and unable to fall back to a provider, hidden download,
default server sidecar, 12B/31B, dense 70B, or mmap/SSD stress. The guard-owned
product cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.

## Sources

- Google Gemma 4 QAT:
  <https://blog.google/innovation-and-ai/technology/developers-tools/quantization-aware-training-gemma-4/>
- Gemma 4 E2B QAT GGUF:
  <https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf>
- llama.cpp:
  <https://github.com/ggml-org/llama.cpp>
