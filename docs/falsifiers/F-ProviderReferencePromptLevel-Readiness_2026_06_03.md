---
state: failure_report
created_on: 2026-06-03
falsifier_id: F-ProviderReferencePromptLevel-Readiness
artifact: artifacts/falsifiers/provider_reference_prompt_level_readiness/result.json
command: Tools/falsifiers/f_provider_reference_prompt_level_readiness.sh
scope_guard: prompt-level provider/local reference readiness only; no provider call, no model run, no fp16 logits generation
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a planning and witness artifact. For active architecture, route Helios/UAS/ACS (Anchored Cognitive Substrate)/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

# F-ProviderReferencePromptLevel-Readiness - 2026-06-03

## Verdict

`F-ProviderReferencePromptLevel-Readiness` audits the real prompt-level
reference path for `F-70B-Local-Cocktail-Lite`.

It does not call a provider, run MLX, generate fp16 logits, or use the
shape-only retained fixture as evidence. It only reads
`EPISTEMOS_70B_PROVIDER_REFERENCE` and checks whether that path points to a
digest-valid `ProviderReferenceManifest` whose retained replay files are
prompt-level comparison evidence.

Current artifact:

```text
artifacts/falsifiers/provider_reference_prompt_level_readiness/result.json
```

Current status:

```text
overall_pass=false
primary_blocker=missing_provider_reference_env
prompt_level_reference_available=false
```

That is the correct red state when the heavy/provider-reference lane is active.
It is deferred by default while the app is routed through practical MLX local
inference.

## Minimum Axes

| Axis | Required Meaning |
|---|---|
| `provider_reference_env_set` | `EPISTEMOS_70B_PROVIDER_REFERENCE` is set. |
| `manifest_file_exists` | The named manifest exists on disk. |
| `manifest_valid` | `ProviderReferenceManifest::validate()` accepts the manifest. |
| `prompt_level_scope` | `evidence_scope=prompt_level_comparison`; shape fixtures fail. |
| `prompt_count_floor` | Prompt-level manifests include at least 50 prompts. |
| `replay_files_valid` | The retained reference artifact and prompt suite exist and match SHA256 digests. |
| `prompt_level_reference_available` | All above conditions are true. |

## What This Does Not Prove

- It does not prove the local 70B runtime.
- It does not prove D_KL, TTFT, tok/s, RSS, cache state, or rollback.
- It does not send prompts to a provider.
- It does not promote the shape-only `F-ProviderReferenceManifest-DryRun`
  fixture.

The invariant is:

```text
shape-only manifest ABI can be green
  -> prompt-level readiness remains red without a real manifest
  -> F-70B-Local-Cocktail-Lite stays on missing_fp16_or_provider_reference only when that lane is re-enabled
  -> only digest-valid prompt-level replay evidence advances the comparison gate
```
