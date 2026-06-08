# F-KIVIAsymmetricKVStabilitySourceCard

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 primary witness on 2026-06-08.

This witness source-cards KIVI-style asymmetric KV quantization before any
low-bit KV, cache, or large-local-model route can influence RuntimeRouter /
System G. It consumes the landed `F-LlamaCppSlotPromptCacheCommandCard`
artifact, binds primary KIVI sources, records backend caveats, separates key
and value quantization axes, requires residual full-precision policy, and
rejects product/runtime promotion.

## Artifact

- Falsifier id: `F-KIVIAsymmetricKVStabilitySourceCard`
- Command: `Tools/falsifiers/f_kivi_asymmetric_kv_stability_source_card.sh`
- Artifact root:
  `artifacts/falsifiers/kivi_asymmetric_kv_stability_source_card/`
- Artifact:
  `artifacts/falsifiers/kivi_asymmetric_kv_stability_source_card/result.json`
- Rust primitive:
  `agent_core/src/uas/kivi_asymmetric_kv_stability_source_card.rs`
- Falsifier binary:
  `agent_core/src/bin/falsify_kivi_asymmetric_kv_stability_source_card.rs`
- Validator registry:
  `agent_core/src/bin/falsifier_validator.rs`
- Axis contract:
  `agent_core/src/falsifier_artifacts/axes.rs::KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_AXES`

## Accepted Evidence

- Upstream dependency:
  `artifacts/falsifiers/llama_cpp_slot_prompt_cache_command_card/result.json`
- Primary sources:
  `https://arxiv.org/abs/2402.02750` and
  `https://github.com/jy-yuan/KIVI`
- Backend lanes:
  `CudaResearch`, `TransformersInspired`, `AppleSiliconUnproven`,
  `RuntimeRouterDenied`
- KV axis policy:
  key cache per-channel, value cache per-token
- Quant policy:
  2-bit K, 2-bit V, group size required, residual length required,
  residual fp16 policy required
- Stability proof slots:
  softmax drift, attention outlier, long-context recall, reasoning quality,
  coding quality, latency and memory, backend compatibility, rollback replay
- Red fixtures rejected: 37
- Deterministic KIVI stability address:
  `kivi_asymmetric_kv_stability_source_card:716e314fc2ccbc2a81bd9d77d54ca926e9f2835eab704d604f9a924b6c677674@1779158400000`
- Next side-ladder cursor:
  `kv_offload_tier_budget_envelope`

## What This Proves

- KIVI asymmetric KV research is now addressable as a source-carded,
  rollback-visible, AnswerPacket-visible Pro ResearchCandidate input.
- Low-bit KV cannot be promoted from a paper/repo claim without separate K/V
  axis policy, residual policy, backend caveats, stability proof slots, and
  clean-room provenance.
- Apple Silicon support is explicitly unproven.
- Direct source import is denied by this gate; clean-room rewrite or later
  provenance-approved integration is required.
- No hidden route/cache authority is created.

## What This Does Not Prove

- It does not prove KIVI runs on Jojo's Mac.
- It does not prove low-bit KV is stable for Epistemos tasks.
- It does not prove local model fit, token quality, latency, or memory savings.
- It does not load model, KV, runtime, source-tree, benchmark, or product bytes.
- It does not promote MAS, L2, L3, T4/T5, live dense 70B, SSD-as-RAM, or
  user-facing runtime capability.

Correct phrasing: "L1 KIVI stability source-card architecture proof advanced;
product capability / user surface did not."

## Promotion Truth

- T0 research/canon: superseded for this card by landed T1 witness.
- T1/L1 architecture proof: advanced for metadata-only source-card proof.
- T2/L2 capability route: unchanged and red.
- T3/L3 WRV/user-facing runtime: unchanged and red.
- T4/T5 green: no.

## Sources

- KIVI arXiv: `https://arxiv.org/abs/2402.02750`
- KIVI GitHub: `https://github.com/jy-yuan/KIVI`
