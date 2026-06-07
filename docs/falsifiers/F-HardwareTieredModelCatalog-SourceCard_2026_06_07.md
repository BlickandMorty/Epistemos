# F-HardwareTieredModelCatalog-SourceCard - 2026-06-07

Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 primary witness on 2026-06-07.

- Command: `Tools/falsifiers/f_hardware_tiered_model_catalog_source_card.sh`
- Artifact: `artifacts/falsifiers/hardware_tiered_model_catalog_source_card/result.json`
- Primitive: `agent_core/src/uas/hardware_tiered_model_catalog_source_card.rs`
- Falsifier binary: `agent_core/src/bin/falsify_hardware_tiered_model_catalog_source_card.rs`
- Scope: Pro ResearchCandidate / L1 only. Product capability, user-facing runtime, local model availability, runtime load, first token, quality, speed, live dense 70B, SSD-as-RAM, hidden cloud fallback, and MAS promotion remain unproved.

## What It Proves

`F-HardwareTieredModelCatalog-SourceCard` consumes the already-passed `F-KVSourceCard-ForkAndDaemonBoundary` artifact and turns local Downloads model research plus current model-card metadata into typed, UAS-addressed hardware-tier cards before any model can influence RuntimeRouter/System G.

The accepted catalog has 9 model cards:

- `google/gemma-4-E2B-it-qat-q4_0-gguf`: small harness candidate only.
- `google/gemma-4-12B-it-qat-q4_0-gguf`: Pro Gated flagship candidate only.
- `Jackrong/Qwopus3.5-27B-v3-GGUF`: coding/reasoning candidate with 16-18 GB headroom caveat.
- `YTan2000/Qwopus3.5-27B-v3-TQ3_4S`: exotic quant candidate; provenance-gated and runtime-deferred.
- `caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5`: exotic quant candidate; provenance-gated and runtime-deferred.
- `samuelcardillo/Qwopus-MoE-35B-A3B-GGUF`: MoE candidate requiring active-params/full-weight memory truth.
- `mudler/Qwopus-MoE-35B-A3B-APEX-GGUF`: MoE exotic-quant candidate requiring active-params/full-weight memory truth and provenance gating.
- `nvidia/Gemma-4-31B-IT-NVFP4`: CUDA/Blackwell-only GPU candidate; denied as a Mac default.
- `Intel/gemma-4-31B-it-int4-AutoRound`: server/GPU research candidate; denied as a Mac default.

The witness records 9 catalog cards, at least 4 hardware tiers, at least 4 runtime lanes, at least 6 formats, at least 5 roles, 37 rejected red fixtures, deterministic UAS addressing, rollback, RunEventLog, AnswerPacket, compatibility, privacy, provenance, and hardware-tier refs. It keeps model, runtime, provider, source-tree, product-copy, command-execution, and benchmark bytes at zero.

## Hard Rejections

The artifact rejects empty catalogs, duplicate card IDs, duplicate model IDs, unknown model IDs, bad upstream refs, non-Hugging Face source URLs, bad source revisions, missing local research quarantine, missing source-card requirements, non-deferred runtimes, MAS product claims, Pro Live status, T2+ promotion, product routes, product-default claims, product-winner claims, hidden route authority, hidden cloud fallback, L2/L3 promotion, live dense 70B, SSD-as-RAM, model/runtime/provider/source-tree/product/command/benchmark bytes, Gemma 12B as small harness, Qwopus 27B without headroom caveat, MoE without active-params truth, exotic quant without provenance gate, NVFP4 as a Mac default, AutoRound as a Mac GGUF/MLX route, declared bytes without local-research quarantine, and bad proof refs.

## Non-Claims

This is not a runtime proof. It does not download, hash, open, mmap, or load any model file. It does not run GGUF, llama.cpp, LiteRT-LM, MLX, MLX Swift, MLX-LM, vLLM, Transformers, AutoRound, NVFP4, TurboQuant, TQ3_4S, HLWQ, APEX, Qwopus, Gemma, or any local runtime. It does not prove Apple Silicon fit, latency, quality, coding ability, long-context support, first-token success, MAS support, or a "best" model.

Correct phrasing: architecture catalog coverage advanced; product capability and user-facing runtime did not.

## Downstream Units

`F-MoEActiveParamsMemoryTruth`, `F-ExoticQuantQuarantineRouteCard`, `F-ExoticQuantSourcePinAndByteBudgetPreflight`, `F-ExoticQuantRuntimeLaneOwnerApprovalGate`, `F-ExoticQuantLoaderCompatibilityModelPathGate`, and `F-ExoticQuantLocalArtifactAvailabilityOwnerGate` are now landed as metadata-only downstream witnesses. The current research-to-build next unit is `exotic_quant_owner_path_manifest_intake_gate`, which should define owner-approved path manifest intake before any exotic quant command envelope can be armed.
