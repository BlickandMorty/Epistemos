# F-MoEActiveParamsMemoryTruth - 2026-06-07

Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 primary witness on 2026-06-07.

- Command: `Tools/falsifiers/f_moe_active_params_memory_truth.sh`
- Artifact: `artifacts/falsifiers/moe_active_params_memory_truth/result.json`
- Primitive: `agent_core/src/uas/moe_active_params_memory_truth.rs`
- Falsifier binary: `agent_core/src/bin/falsify_moe_active_params_memory_truth.rs`
- Scope: Pro ResearchCandidate / L1 only. Product capability, user-facing runtime, Apple Silicon memory fit, local model availability, runtime load, first token, quality, speed, live dense 70B, SSD-as-RAM, hidden cloud fallback, and MAS promotion remain unproved.

## What It Proves

`F-MoEActiveParamsMemoryTruth` consumes `F-HardwareTieredModelCatalog-SourceCard` and proves that MoE active-parameter counts are compute evidence, not resident-memory proof.

The accepted metadata ledger has 2 MoE rows:

- `samuelcardillo/Qwopus-MoE-35B-A3B-GGUF`: GGUF / llama.cpp lane, Pro ResearchCandidate, not product-routed.
- `mudler/Qwopus-MoE-35B-A3B-APEX-GGUF`: APEX GGUF lane, Pro ResearchCandidate, provenance-gated and not product-routed.

The witness records total declared params `70000000000`, active declared params as compute-only evidence, declared full-weight artifact bytes `38000000000`, KV cache budget bytes `4000000000`, app headroom bytes `8589934592`, 35 rejected red fixtures, deterministic UAS addressing, rollback, RunEventLog, AnswerPacket, compatibility, privacy, provenance, hardware-tier, and abstention refs. It keeps model, runtime, provider, source-tree, product-copy, command-execution, and benchmark bytes at zero.

## Hard Rejections

The artifact rejects empty ledgers, duplicate card IDs, duplicate model IDs, non-MoE rows, bad source SHA values, active params as memory-fit claims, missing active-compute flags, active params greater than or equal to total params, missing full-weight bytes, missing KV budget, missing expert-residency lease, missing router/runtime workspace, missing app headroom, 16-18 GB MoE default claims, APEX without provenance, server benchmarks as local fit proof, product routes, product defaults, product winners, hidden route authority, hidden cloud fallback, L2/L3 promotion, live dense 70B, SSD-as-RAM, nonzero model/runtime/provider/source-tree/product/command/benchmark bytes, bad AnswerPacket refs, bad abstention refs, and bad upstream refs.

## Non-Claims

This is not a runtime proof. It does not download, hash, open, mmap, or load any model file. It does not run GGUF, APEX, llama.cpp, LiteRT-LM, MLX, MLX Swift, MLX-LM, vLLM, KTransformers, PowerInfer, Qwopus, Qwen, Gemma, or any local runtime. It does not prove Apple Silicon fit, latency, quality, coding ability, long-context support, first-token success, MAS support, or a "best" model.

Correct phrasing: architecture MoE memory-truth coverage advanced; product capability and user-facing runtime did not.

## Downstream Units

`F-ExoticQuantQuarantineRouteCard`, `F-ExoticQuantSourcePinAndByteBudgetPreflight`, `F-ExoticQuantRuntimeLaneOwnerApprovalGate`, `F-ExoticQuantLoaderCompatibilityModelPathGate`, `F-ExoticQuantLocalArtifactAvailabilityOwnerGate`, `F-ExoticQuantOwnerPathManifestIntakeGate`, and `F-ExoticQuantOwnerPathCanonicalizationPreflightGate` are now landed as metadata-only downstream witnesses. The current research-to-build next unit is `exotic_quant_owner_path_byte_envelope_preflight_gate`, which should prove selected byte envelopes without path opens, symlink following, command arming, or product promotion.
