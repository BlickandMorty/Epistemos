# F-KVOffloadTierBudgetEnvelope

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 primary witness on 2026-06-08.

This witness turns LMCache/vLLM/KVSwap/KIVI offload research into an explicit
KV/cache byte envelope before any offload tier can influence RuntimeRouter /
System G. It does not run a model, open a cache file, start a server, arm a
command, or prove Apple Silicon runtime fit.

## Artifact

- Falsifier id: `F-KVOffloadTierBudgetEnvelope`
- Command: `Tools/falsifiers/f_kv_offload_tier_budget_envelope.sh`
- Artifact root:
  `artifacts/falsifiers/kv_offload_tier_budget_envelope/`
- Artifact:
  `artifacts/falsifiers/kv_offload_tier_budget_envelope/result.json`
- Rust primitive:
  `agent_core/src/uas/kv_offload_tier_budget_envelope.rs`
- Falsifier binary:
  `agent_core/src/bin/falsify_kv_offload_tier_budget_envelope.rs`
- Axis contract:
  `agent_core/src/falsifier_artifacts/axes.rs::KV_OFFLOAD_TIER_BUDGET_ENVELOPE_AXES`

## Accepted Evidence

- Upstream dependency:
  `artifacts/falsifiers/kivi_asymmetric_kv_stability_source_card/result.json`
- Source ref count: 6
- Tier count: 4
- Declared hot resident bytes: `2147483648`
- Declared CPU cache bytes: `4294967296`
- Declared local disk cache bytes: `8589934592`
- Declared app headroom bytes: `4294967296`
- Declared remote cache bytes: `0`
- Red fixtures rejected: 47
- Deterministic offload envelope address:
  `kv_offload_tier_budget_envelope:b3c55fdab037ecb741744753053428a2def9d1c370547b230160da73248dea7e@1779244800000`
- Next side-ladder cursor:
  `kv_cache_lineage_deletion_fence`

## What This Proves

- KV/cache offload research now has an addressable Pro ResearchCandidate byte
  envelope before route use.
- Hot resident UMA, CPU cache, local disk cache, and remote-denied tiers are
  separated.
- Local disk remains a cache tier with explicit budget, cleanup, teardown, and
  cache-miss behavior. It is not RAM.
- Remote KV/cache tiers are denied for the local product route.
- Rollback, RunEventLog, AnswerPacket, abstention, caveat, privacy, and
  compatibility refs are required before promotion.

## What This Does Not Prove

- It does not prove KV offload works locally.
- It does not prove low-bit KV, LMCache, vLLM, llama.cpp, or custom Metal
  runtime quality.
- It does not prove large-model fit, latency, throughput, first token, or
  user-facing capability.
- It does not load model, KV, cache, runtime, source-tree, benchmark, product,
  or provider bytes.
- It does not promote MAS, L2, L3, T4/T5, live dense 70B, SSD-as-RAM, or
  user-facing runtime capability.

Correct phrasing: "L1 KV offload tier-budget architecture proof advanced;
product capability / user surface did not."

## Promotion Truth

- T0 research/canon: superseded for this envelope by landed T1 witness.
- T1/L1 architecture proof: advanced for metadata-only budget proof.
- T2/L2 capability route: unchanged and red.
- T3/L3 WRV/user-facing runtime: unchanged and red.
- T4/T5 green: no.

## Sources

- LMCache local storage: `https://docs.lmcache.ai/kv_cache/local_storage.html`
- LMCache architecture:
  `https://docs.lmcache.ai/developer_guide/architecture.html`
- vLLM KV offloading connector:
  `https://vllm.ai/blog/kv-offloading-connector`
- vLLM multi-tier offloading RFC:
  `https://github.com/vllm-project/vllm/issues/38260`
- KIVI: `https://arxiv.org/abs/2402.02750`
- KVSwap: `https://arxiv.org/abs/2511.11907`
