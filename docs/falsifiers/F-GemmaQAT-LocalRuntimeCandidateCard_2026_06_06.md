---
falsifier: F-GemmaQAT-LocalRuntimeCandidateCard
created_on: 2026-06-06
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/gemma_qat_local_runtime_candidate_card/result.json
---

# F-GemmaQAT-LocalRuntimeCandidateCard

## Purpose

This is the executable metadata-only witness that turns source-carded Gemma 4
QAT research into local runtime candidate cards after
`F-CompressedModelSourceCard-Intake`.

Epistemos is a local cognitive substrate where every meaningful object has an
address, plane, budget, status, and witness; MAS ships the safe floor, Pro
contains the gated/research/vault/omega ladder, and no claim promotes without
visible proof.

## Command

```bash
Tools/falsifiers/f_gemma_qat_local_runtime_candidate_card.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/gemma_qat_local_runtime_candidate_card/result.json`
- scope: metadata-only; `model_bytes_loaded=0`, `runtime_bytes_loaded=0`,
  and `provider_calls_made=0`

The artifact passes with 4 accepted cards and 33 red-fixture rejections. The
accepted pack is source-backed from current Hugging Face model metadata for
Gemma 4 QAT GGUF E2B, E4B, 12B, and 31B. It records Apache-2.0 license refs,
source revision refs, declared GGUF byte totals, context windows, Pro status,
candidate bands, route caveats, rollback, RunEventLog, AnswerPacket, and
compatibility-fence refs. It records total declared file bytes
`54696279481`, estimated resident-floor bytes `62277025792`, and zero loaded
model/runtime/provider bytes.

## Hard Rejections

The witness rejects duplicate card/model IDs, bad upstream source-card refs,
missing license or revision refs, non-HTTPS locators, zero declared file bytes,
zero context windows, file-size-as-resident-memory claims, zero KV/scratch
floors, model/runtime byte loads, provider calls, MAS product build, Pro Live
status, T2+ promotion, missing MLX loader caveats, Swift MLX loader-proof
claims, MTP speedup claims, MAS readiness claims, product capability claims,
hidden cloud fallback, hidden route authority, live dense 70B claims,
SSD-as-RAM claims, 31B non-vault promotion, 12B small-harness promotion, bad
proof refs, missing L1/L2/L3 separation, undeferred runtime, unblocked product
promotion, and metadata overflow.

## Non-Promotion Rule

This falsifier does not run MLX, GGUF, LiteRT, Transformers, or custom Metal;
does not load Gemma QAT weights; does not prove Swift MLX support; does not
prove quality, first token, tool use, MTP speedup, memory fit, MAS readiness,
or product capability; and does not advance live dense 70B or live sparse 70B.
It advances T1/L1 metadata architecture only. L2 capability and L3
user-facing/product runtime remain unchanged.

## Queue Effect

`F-GemmaQAT-LocalRuntimeCandidateCard` gives the model ladder a source-backed
candidate pack for later `F-QAT-ModelRouteCard-MemoryPreflight`, runtime-lane
parity dry runs, and small approved model harness work. The guard-owned
product cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
