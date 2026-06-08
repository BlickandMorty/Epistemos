---
falsifier: F-GemmaQATByteKVAppEnvelopePreflight
date: 2026-06-08
artifact: artifacts/falsifiers/gemma_qat_byte_kv_app_envelope_preflight/result.json
scope: metadata-only T1/L1 Gemma E2B/E4B byte/KV/app envelope preflight
---

# F-GemmaQATByteKVAppEnvelopePreflight

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Result

PASS as metadata-only T1/L1 architecture proof.

Command:

```bash
Tools/falsifiers/f_gemma_qat_byte_kv_app_envelope_preflight.sh
```

Artifact:

- path: `artifacts/falsifiers/gemma_qat_byte_kv_app_envelope_preflight/result.json`
- envelope cards: `2`
- selected artifact bytes total: `12091583309`
- KV cache floor bytes total: `1342177280`
- runtime workspace bytes total: `1879048192`
- app headroom bytes total: `8589934592`
- planned total envelope bytes: `24104069965`
- model bytes loaded: `0`
- runtime bytes loaded: `0`
- provider calls: `0`
- first-token attempts: `0`
- red fixtures rejected: `33`
- next cursor: `gemma_qat_redacted_first_token_probe`

## What It Proves

`F-GemmaQATByteKVAppEnvelopePreflight` consumes the landed
`F-GemmaQATSmallLaneOwnerPathManifest` and turns the Gemma E2B/E4B QAT warmup
lanes into byte-accounted preflight cards.

The witness binds selected artifact bytes, KV cache floor bytes, runtime
workspace bytes, app headroom bytes, metadata side-table bytes, Jojo's current
16 GB M2 Pro UMA floor, owner-approval requirement, fresh-memory-sample
requirement, redacted first-token requirement, cancellation, rollback,
RunEventLog, AnswerPacket, abstention, SovereignGate, and compatibility-fence
refs.

E2B is marked as a probe candidate after owner approval. E4B is marked as a
tight probe candidate that still requires a fresh memory sample. These are
candidate states only; neither is a product-fit or runtime-success claim.

## What It Does Not Prove

This witness does not prove:

- either Gemma model is installed locally;
- any owner path is approved, canonicalized, opened, statted, or hashed;
- selected GGUF file bytes become resident memory;
- KV cache or runtime workspace bytes have been allocated;
- GGUF, LiteRT-LM, or MLX has emitted a first token;
- first-token latency, memory pressure, cancellation, teardown, quality,
  coding/research/writing utility, or tool JSON reliability;
- Swift MLX Gemma 4 loader parity;
- Gemma is the live main app model;
- MAS, L2, L3, release readiness, live dense 70B, SSD-as-RAM, hidden cloud
  fallback, or hidden Eidos/PatternBoost/lattice route authority.

Correct phrasing: "Gemma E2B/E4B byte/KV/app envelopes are L1
metadata-proofed; no Gemma file or runtime has been opened, loaded, or promoted."

## Red Fixtures

The falsifier rejects:

- inserting 12B into the E2B/E4B warmup envelope pack;
- duplicate model IDs;
- incorrect selected artifact bytes;
- selected file bytes treated as resident memory;
- missing KV cache floor, runtime workspace, or app headroom;
- envelope-total mismatches;
- E4B without a fresh-memory-sample caveat;
- M2 Pro candidate wording that becomes a fit claim;
- owner approval laundering;
- first-token claims or first-token attempts;
- bad proof refs;
- owner manifest, local artifact, path canonicalization, file access, or hash
  claims;
- armed commands or runtime probes;
- model/runtime/provider bytes;
- benchmark runs;
- route mutation or hidden authority;
- MAS/L2/L3/product capability claims;
- live dense 70B and SSD-as-RAM claims;
- metadata budget overflow;
- bad upstream refs;
- missing LiteRT lane;
- quality claims.

## Next

The next Gemma side-ladder unit is `F-GemmaQATRedactedFirstTokenProbe`, which
must remain owner-approved, redacted, one-token, cancellable, rollback-bound,
RunEventLog-backed, AnswerPacket-visible, and non-promoting.

The guard-owned product cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
