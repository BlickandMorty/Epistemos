# F-KVCacheIdentitySaltAndOffloadProofPacket - 2026-06-07

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 architecture witness.

- Command:
  `Tools/falsifiers/f_kv_cache_identity_salt_offload_proof_packet.sh`
- Artifact:
  `artifacts/falsifiers/kv_cache_identity_salt_offload_proof_packet/result.json`
- Rust primitive:
  `agent_core/src/uas/kv_cache_identity_salt_offload_proof_packet.rs`
- Falsifier binary:
  `agent_core/src/bin/falsify_kv_cache_identity_salt_offload_proof_packet.rs`
- Artifact commit SHA at generation time:
  `d360fbc29ce4e9ed9e7fbbab213336e3805b572a`
- Deterministic packet address:
  `kv_cache_identity_salt_offload_proof_packet:190f70b5238f764552e25ef5e3d086afff42d30ee4c9824c098fe4098b7027eb@1779072000000`

## What It Proves

This witness converts Deep Research Pass 128 from T0 canon into a metadata-only
KV cache identity, privacy salt, and offload proof packet. It accepts five
source-card motifs:

- vLLM prefix caching;
- LMCache local storage;
- llama.cpp slot prompt-cache save/restore;
- KTransformers heterogeneous expert/cache scheduling;
- KIVI asymmetric KV quantization.

It binds source/search freshness, prompt assembly, tokenizer, chat-template,
tool-schema, model/runtime identity, KV block hash, parent block hash, token
range digest, cache salt, trust group, adapter/modality extras, K/V dtype,
quant profile, layer/head/position policy, offload tiers, path scope, cleanup,
rollback, RunEventLog, AnswerPacket, abstention, and cache caveats.

## Hard Boundaries

This witness opens zero cache/model/KV/runtime/provider/product bytes and
starts no server or command. It does not prove cache reuse, local model runtime,
large-model fit, product readiness, or user-facing capability.

The witness rejects:

- missing source cards;
- duplicate source cards;
- missing source/prompt/tokenizer/tool-schema digests;
- missing parent block hash;
- missing cache salt;
- missing adapter/modality extras;
- K/V dtype identity gaps;
- local disk path escape;
- remote cache bytes;
- cache reuse authority;
- hidden cache authority;
- raw prompt or raw token logging;
- server start or command arming;
- L2/L3 green claims;
- live dense 70B claims;
- SSD-as-RAM claims;
- model/KV/cache byte loads.

## Promotion Truth

- T0 research/canon: superseded for this packet by the landed T1 witness.
- T1/L1 architecture proof: advanced for metadata-only cache identity/offload
  proof.
- T2/L2 capability route: unchanged and red.
- T3/L3 WRV/product surface: unchanged and red.
- T4/T5 green: no.

Correct phrasing: "KV cache identity architecture proof advanced; product
capability / user surface did not."

## Next Link

The next side-ladder cursor is `llama_cpp_slot_prompt_cache_command_card`.
The guard-owned product cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
