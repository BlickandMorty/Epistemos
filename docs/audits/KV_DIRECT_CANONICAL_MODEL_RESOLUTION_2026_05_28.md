# KV-Direct Canonical Model Resolution

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Date: 2026-05-28

## Purpose

Resolve the current Capability Ceiling cursor:

```text
resolve_qwen3_8b_128k_context_model_assets_for_kv_direct
```

This is a model-contract audit, not a runtime benchmark. It prevents agents from
rerunning expensive 128K shards against a model asset that cannot honestly pass
the context floor.

## Current Verdict

`F-KV-Direct-Gate` is still pinned to:

```text
canonical_model_repo_id = Qwen/Qwen3-8B-MLX-4bit
required_context_window_tokens = 128000
```

The resolved local canonical asset is:

```text
path = /Users/jojo/Library/Application Support/Epistemos/Models/text/hub/models--Qwen--Qwen3-8B-MLX-4bit/snapshots/383413e909f3bc5303ce195ebbdf0339c5a1a2a3
model_type = qwen3
model_context_window_tokens = 40960
resolved_model_context_source = declared_config_context
resolved_model_rope_scaling = none
model_identity_matches_canonical = true
model_context_supports_required_context = false
```

So the current failure is not model identity. It is the canonical model/context
contract: the exact target model is present, but it does not prove 128K context.

## Public Model Check

Hugging Face search on 2026-05-28 found:

| Repo | Format | Identity relation | Context meaning | Use |
|---|---|---|---|---|
| [Qwen/Qwen3-8B-MLX-4bit](https://hf.co/Qwen/Qwen3-8B-MLX-4bit) | MLX 4-bit | canonical current target | local config declares 40,960 | canonical but context-red |
| [mlx-community/Qwen3-8B-4bit](https://hf.co/mlx-community/Qwen3-8B-4bit) | MLX 4-bit | base model `Qwen/Qwen3-8B` | no verified local 128K proof in this audit | candidate only unless downloaded and config-verified |
| [lmstudio-community/Qwen3-8B-MLX-4bit](https://hf.co/lmstudio-community/Qwen3-8B-MLX-4bit) | MLX 4-bit | base model `Qwen/Qwen3-8B` | no verified local 128K proof in this audit | candidate only unless downloaded and config-verified |
| [mlx-community/Qwen3-Coder-Next-4bit](https://hf.co/mlx-community/Qwen3-Coder-Next-4bit) | MLX 4-bit | noncanonical `Qwen3-Coder-Next` | local config declares 262,144 | runtime research candidate only |

No exact public hit was found for a canonical `Qwen/Qwen3-8B-MLX-4bit` asset
that is both MLX-format and locally verified at `>=128000` context.

### Refresh From Hugging Face Hub - 2026-05-28

The current Hub check keeps the same conclusion:

- Query `Qwen3 8B 128K MLX 4bit`: no repositories found.
- Query `Qwen3-8B 128K MLX`: one MLX result, but it is a 21B merged coder
  artifact, not canonical Qwen3-8B.
- Repo details still show `Qwen/Qwen3-8B-MLX-4bit`,
  `mlx-community/Qwen3-8B-4bit`, and
  `lmstudio-community/Qwen3-8B-MLX-4bit` as MLX 4-bit Qwen3-8B-family
  artifacts, but the current local verified context for the canonical asset is
  still `40960`, not `>=128000`.
- `mlx-community/Qwen3-Coder-Next-4bit` remains a useful MLX long-context
  mechanics probe, but its architecture/base model is `qwen3_next` /
  `Qwen3-Coder-Next`, so it is not the canonical Qwen3-8B falsifier target.

Sources checked: [Qwen/Qwen3-8B-MLX-4bit](https://hf.co/Qwen/Qwen3-8B-MLX-4bit),
[mlx-community/Qwen3-8B-4bit](https://hf.co/mlx-community/Qwen3-8B-4bit),
[lmstudio-community/Qwen3-8B-MLX-4bit](https://hf.co/lmstudio-community/Qwen3-8B-MLX-4bit),
[mlx-community/Qwen3-Coder-Next-4bit](https://hf.co/mlx-community/Qwen3-Coder-Next-4bit).

## Non-Drift Decision

Do not run the canonical 100-prompt / 128K shard plan again until one of these
is true:

1. A canonical `Qwen/Qwen3-8B-MLX-4bit`-compatible local asset/config is
   resolved with `model_context_window_tokens >= 128000`.
2. Canon explicitly retargets `F-KV-Direct-Gate` from
   `Qwen/Qwen3-8B-MLX-4bit` to a named derivative or noncanonical model, and the
   docs/artifact id are updated to reflect the new target.
3. A local rope/context extension path is implemented and falsified as a
   candidate transformation before it is allowed to satisfy the canonical gate.

## Candidate Runtime Plan

The current candidate-tier long-context MLX plan is:

```text
artifacts/falsifiers/kv_direct_gate/live_mlx_candidate_qwen3_coder_next_plan/full_suite_run_plan.json
model_repo_id = mlx-community/Qwen3-Coder-Next-4bit
model_identity_matches_canonical = false
model_context_window_tokens = 262144 in local inventory
falsifier_green_capable = false
```

It can be used to test MLX long-context mechanics, prompt-cache behavior, and
Metal/runtime failure modes. It cannot satisfy `F-KV-Direct-Gate`.

The optional non-MLX long-context candidate lane was removed from the active
architecture queue at user request on 2026-06-03. Do not recreate it for
KV-Direct. The active blocker remains the canonical MLX model/context contract
above unless canon explicitly retargets `F-KV-Direct-Gate`.

## Next Build Cursor

The duplicate-work guard cursor is now:

```text
resolve_qwen3_8b_128k_context_model_assets_for_kv_direct
```

Interpret this narrowly: the canonical MLX model/context contradiction remains
red. Do not duplicate prompt-suite, shard planner, merge, model download, or
runner scaffolding.
