---
falsifier: F-ModelInventory-ZeroByteCandidateCards
created_on: 2026-06-06
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/model_inventory_zero_byte_candidate_cards/result.json
---

# F-ModelInventory-ZeroByteCandidateCards

## Purpose

This is the executable metadata-only model inventory witness for the June 6
TurboVec/QAT and large-local-model research-to-build loop. It proves that
local model, package, cache, sidecar, and runtime-preference evidence can be
bound to accepted `SourceCard` rows before any model byte, index byte, runtime
byte, provider call, route choice, or product-capability claim is allowed.

Epistemos is a local cognitive substrate where every meaningful object has an
address, plane, budget, status, and witness; MAS ships the safe floor, Pro
contains the gated/research/vault/omega ladder, and no claim promotes without
visible proof.

## Command

```bash
Tools/falsifiers/f_model_inventory_zero_byte_candidate_cards.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/model_inventory_zero_byte_candidate_cards/result.json`
- scope: metadata-only; `model_bytes_loaded=0`, `index_bytes_loaded=0`,
  `runtime_bytes_loaded=0`, and `provider_calls_made=0`

The artifact passes only when 12 accepted fixtures cover catalog descriptors,
install manifests, present and missing hub snapshots, Gemma 4 loader-blocked
sidecars, deferred GGUF/128K byte witnesses, LFS pointer metadata, capped
sidecar JSON, package manifests, and runtime-preference hints. It also rejects
32 red fixtures for duplicate or orphan identities, blocked sources, stale
source timestamps, snapshot-as-file-hash laundering, LFS/local-hash confusion,
weight-blob opens, weight-blob hashing, nonzero model/index/runtime bytes,
provider calls, active-directory runtime proof, unverified manifest checksum
promotion, package-lock loader proof, missing Gemma 4 loader caveats, hidden
route authority, filesystem-path UAS identity, missing sidecar caps, malformed
sidecar trust, MAS/Pro and L2/L3 false promotion, live dense 70B claims,
SSD-as-RAM claims, hidden cloud fallback, digest mismatch, and missing
rollback/RunEventLog/AnswerPacket references.

## Non-Promotion Rule

This falsifier does not select a model, rank a route, run MLX/GGUF/LiteRT,
hash large blobs, open `.safetensors`, `.gguf`, `.npz`, or `.mlx` files,
prove Gemma 4 Swift loader readiness, prove 128K context, or promote any
local-large-model product claim. It advances L1 metadata architecture only.
L2 capability and L3 user-facing surfaces remain unchanged until a later
runtime and WRV witness passes.

## Queue Effect

`F-ModelInventory-ZeroByteCandidateCards` gives the research loop a buildable
feeder for `F-ProprietaryCompression-ProvenanceGate`: local model and runtime
evidence now has a source-card-bound candidate shape with explicit byte,
provenance, rollback, RunEventLog, AnswerPacket, MAS/Pro, and promotion
boundaries. The guard-owned next cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`;
this witness is a research-derived architecture checkpoint, not a replacement
for the product runtime/release-audit queue.
