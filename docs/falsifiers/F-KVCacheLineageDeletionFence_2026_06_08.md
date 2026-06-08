# F-KVCacheLineageDeletionFence

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 primary witness on 2026-06-08.

This witness turns persistent KV/prompt-cache reuse into a lineage and deletion
contract before any cache state can influence RuntimeRouter / System G. It does
not run a model, open a cache file, start a server, arm a command, prove cache
reuse, or prove Apple Silicon runtime fit.

## Artifact

- Falsifier id: `F-KVCacheLineageDeletionFence`
- Command: `Tools/falsifiers/f_kv_cache_lineage_deletion_fence.sh`
- Artifact root:
  `artifacts/falsifiers/kv_cache_lineage_deletion_fence/`
- Artifact:
  `artifacts/falsifiers/kv_cache_lineage_deletion_fence/result.json`
- Rust primitive:
  `agent_core/src/uas/kv_cache_lineage_deletion_fence.rs`
- Falsifier binary:
  `agent_core/src/bin/falsify_kv_cache_lineage_deletion_fence.rs`
- Axis contract:
  `agent_core/src/falsifier_artifacts/axes.rs::KV_CACHE_LINEAGE_DELETION_FENCE_AXES`

## Accepted Evidence

- Upstream dependency:
  `artifacts/falsifiers/kv_offload_tier_budget_envelope/result.json`
- Source ref count: 6
- Boundary count: 10
- Lifecycle state count: 3
- Red fixtures rejected: 63
- KV bytes loaded: 0
- Cache bytes opened: 0
- Runtime bytes loaded: 0
- Deterministic lineage fence address:
  `kv_cache_lineage_deletion_fence:f60cf661689a2ad5b70d837987dc23f6b165d7118f9aae9cc7de77040ab849f1@1779331200000`
- Next side-ladder cursor:
  `same_fixture_runtime_replay_envelope`

## What This Proves

- Cache/KV reuse now has an addressable Pro ResearchCandidate lineage fence
  before route use.
- Source body, search result, prompt, tokenizer, chat template, tool schema,
  model revision, adapter, cache salt, and privacy scope are separate required
  boundaries.
- Active, tombstoned, and purged lifecycle states are explicit.
- Stale source reuse, identity drift reuse, and cross-scope reuse fail closed.
- Tombstone, purge, rollback, RunEventLog, AnswerPacket, abstention, and caveat
  refs are required before promotion.
- Cache hits cannot be used as quality proof, model-fit proof, route authority,
  or hidden cache authority.

## What This Does Not Prove

- It does not prove cache reuse works locally.
- It does not prove LMCache, vLLM, llama.cpp, prompt-cache, or custom Metal
  runtime quality.
- It does not prove large-model fit, latency, throughput, first token, or
  user-facing capability.
- It does not load model, KV, cache, runtime, source-tree, benchmark, product,
  or provider bytes.
- It does not promote MAS, L2, L3, T4/T5, live dense 70B, SSD-as-RAM, or
  user-facing runtime capability.

Correct phrasing: "L1 KV cache lineage/deletion architecture proof advanced;
product capability / user surface did not."

## Promotion Truth

- T0 research/canon: superseded for this fence by landed T1 witness.
- T1/L1 architecture proof: advanced for metadata-only lineage/deletion proof.
- T2/L2 capability route: unchanged and red.
- T3/L3 WRV/user-facing runtime: unchanged and red.
- T4/T5 green: no.

## Sources

- vLLM automatic prefix caching:
  `https://docs.vllm.ai/en/v0.18.0/design/prefix_caching/`
- LMCache local storage:
  `https://docs.lmcache.ai/kv_cache/local_storage.html`
- llama.cpp server slot prompt-cache save/restore/erase:
  `https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md`
- LMCache paper:
  `https://arxiv.org/abs/2510.09665`
