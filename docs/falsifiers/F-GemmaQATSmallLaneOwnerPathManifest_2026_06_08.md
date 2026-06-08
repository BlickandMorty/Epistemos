---
falsifier: F-GemmaQATSmallLaneOwnerPathManifest
date: 2026-06-08
artifact: artifacts/falsifiers/gemma_qat_small_lane_owner_path_manifest/result.json
scope: metadata-only T1/L1 Gemma E2B/E4B owner path-manifest contract
---

# F-GemmaQATSmallLaneOwnerPathManifest

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Result

PASS as metadata-only T1/L1 architecture proof.

Command:

```bash
Tools/falsifiers/f_gemma_qat_small_lane_owner_path_manifest.sh
```

Artifact:

- path: `artifacts/falsifiers/gemma_qat_small_lane_owner_path_manifest/result.json`
- manifest cards: `2`
- owner manifest bytes read: `0`
- raw owner path bytes stored: `0`
- canonical path bytes stored: `0`
- path canonicalization attempts: `0`
- model bytes loaded: `0`
- runtime bytes loaded: `0`
- command executions: `0`
- red fixtures rejected: `29`
- next cursor: `gemma_qat_byte_kv_app_envelope_preflight`

## What It Proves

`F-GemmaQATSmallLaneOwnerPathManifest` turns the landed Gemma preferred-family
policy into a concrete owner-path manifest contract for the small Gemma QAT
warmup lanes:

- `google/gemma-4-E2B-it-qat-q4_0-gguf`
- `google/gemma-4-E4B-it-qat-q4_0-gguf`

The witness binds the exact Hugging Face model IDs, source revisions already
captured by the Gemma QAT candidate card, the current GGUF filenames
`gemma-4-E2B_q4_0-it.gguf` and `gemma-4-E4B_q4_0-it.gguf`, declared source-card
bytes, GGUF/LiteRT lane intent, owner manifest schema requirements, path
policy, byte-plan refs, command envelope refs, rollback, RunEventLog,
AnswerPacket, abstention, and compatibility fences.

The owner manifest is deliberately absent in this rung. The gate proves the
contract for a future owner-provided path without reading that path, storing raw
paths, canonicalizing paths, opening files, hashing files, resolving symlinks,
arming commands, loading models, or mutating routes.

## What It Does Not Prove

This witness does not prove:

- either Gemma model is installed locally;
- the owner has approved any local path;
- a path is safe or canonical;
- bytes fit Jojo's current app memory envelope;
- GGUF, LiteRT-LM, or MLX is the winning runtime lane;
- first token, quality replay, coding/research/writing performance, or tool
  JSON correctness;
- Swift MLX Gemma 4 loader parity;
- Gemma is the live main app model;
- MAS, L2, L3, release readiness, live dense 70B, SSD-as-RAM, hidden cloud
  fallback, or hidden Eidos/PatternBoost/lattice route authority.

Correct phrasing: "Gemma E2B/E4B owner-path manifest contract is L1
metadata-proofed; no Gemma path or runtime has been approved or opened."

## Red Fixtures

The falsifier rejects:

- inserting 12B into the small-lane manifest pack;
- duplicate model IDs;
- bad source revisions, filenames, or source locators;
- missing required manifest fields;
- present owner manifests or owner signatures;
- owner approval laundering;
- owner manifest bytes, raw path bytes, or canonical path bytes;
- path canonicalization attempts;
- file open, stat, hash, or symlink attempts;
- armed commands or runtime probes;
- model/runtime/provider bytes;
- bad proof refs;
- route mutation or hidden authority;
- MAS/L2/L3/product capability claims;
- live dense 70B and SSD-as-RAM claims;
- unsafe ledger state;
- metadata budget overflow;
- wrong manifest state or action.

## Next

The next Gemma side-ladder unit is
`F-GemmaQATByteKVAppEnvelopePreflight`, consuming this owner-path manifest
contract and separately binding selected model bytes, KV cache bytes, runtime
workspace, app headroom, cancellation, rollback, RunEventLog, AnswerPacket, and
abstention before any first-token or runtime proof can begin.

The guard-owned product cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
