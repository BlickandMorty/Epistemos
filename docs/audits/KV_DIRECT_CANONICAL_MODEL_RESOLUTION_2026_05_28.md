# KV-Direct Canonical Model Resolution

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
| [unsloth/Qwen3-8B-128K-GGUF](https://hf.co/unsloth/Qwen3-8B-128K-GGUF) | GGUF | base model `Qwen/Qwen3-8B` derivative | 128K-labeled, not MLX | candidate for llama.cpp/GGUF route, not current MLX falsifier |
| [mlx-community/Qwen3-Coder-Next-4bit](https://hf.co/mlx-community/Qwen3-Coder-Next-4bit) | MLX 4-bit | noncanonical `Qwen3-Coder-Next` | local config declares 262,144 | runtime research candidate only |

No exact public hit was found for a canonical `Qwen/Qwen3-8B-MLX-4bit` asset
that is both MLX-format and locally verified at `>=128000` context.

### Refresh From Hugging Face Hub - 2026-05-28

The current Hub check keeps the same conclusion:

- Query `Qwen3 8B 128K MLX 4bit`: no repositories found.
- Query `Qwen3-8B 128K MLX`: one MLX result, but it is a 21B merged coder
  artifact, not canonical Qwen3-8B.
- Query `Qwen3-8B-128K GGUF`: `unsloth/Qwen3-8B-128K-GGUF` remains the
  clearest base-model-related 128K-labeled Qwen3-8B lane.
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
[unsloth/Qwen3-8B-128K-GGUF](https://hf.co/unsloth/Qwen3-8B-128K-GGUF), and
[mlx-community/Qwen3-Coder-Next-4bit](https://hf.co/mlx-community/Qwen3-Coder-Next-4bit).

## Non-Drift Decision

Do not run the canonical 100-prompt / 128K shard plan again until one of these
is true:

1. A canonical `Qwen/Qwen3-8B-MLX-4bit`-compatible local asset/config is
   resolved with `model_context_window_tokens >= 128000`.
2. Canon explicitly retargets `F-KV-Direct-Gate` from
   `Qwen/Qwen3-8B-MLX-4bit` to a named derivative or noncanonical model, and the
   docs/artifact id are updated to reflect the new target.
3. A separate route is created for `Qwen3-8B-128K-GGUF` / llama.cpp-style
   evaluation, with its own falsifier id and no MLX route claim.
4. A local rope/context extension path is implemented and falsified as a
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

The GGUF split is now executable as a separate falsifier:

```text
falsifier_id = F-Qwen3-8B-128K-GGUF-Route
artifact = artifacts/falsifiers/qwen3_8b_128k_gguf_route/result.json
command = Tools/falsifiers/f_qwen3_8b_128k_gguf_route.sh
current_next_bottleneck = repair_qwen3_8b_128k_gguf_metal_stall
```

This route targets `unsloth/Qwen3-8B-128K-GGUF`, validates under the shared
artifact schema, and stays a `failure_report` until the measured fixture reaches
the full 100-prompt / 128K-context / 256-decode shape. A passing result would be
a `fallback_witness`, not a primary MLX witness.

Current local GGUF evidence:

```text
model_file = /Users/jojo/Library/Application Support/Epistemos/Models/text/hub/models--unsloth--Qwen3-8B-128K-GGUF/snapshots/4a4ca8eeed6a9f3cdf58de9a1e86f7376d0059f9/Qwen3-8B-128K-Q4_K_M.gguf
model_file_bytes = 5027784736
metadata_file = /Users/jojo/Library/Application Support/Epistemos/Models/text/hub/models--unsloth--Qwen3-8B-128K-GGUF/snapshots/4a4ca8eeed6a9f3cdf58de9a1e86f7376d0059f9/config.json
metadata_context_window_tokens = 131072
runner = /opt/homebrew/bin/llama-cli
bench_runner = /opt/homebrew/bin/llama-bench
kl_runner = /opt/homebrew/bin/llama-perplexity
```

Smoke-only measurements now exist:

```text
bench_metrics = artifacts/falsifiers/qwen3_8b_128k_gguf_route/live_bench/metrics.json
bench_shape = 1 prompt, 32768 context tokens, 256 decode tokens
bench_cache = f16 K / f16 V
bench_peak_ram_gb = 9.26873779296875
bench_decode_tok_s = 32.445546
bench_prefill_tok_s = 133.530438

kl_metrics = artifacts/falsifiers/qwen3_8b_128k_gguf_route/live_kl/kl_metrics.json
kl_shape = 1 prompt, 128 context tokens
kl_reference_route = llama_perplexity_f16_kv
kl_test_route = llama_perplexity_q4_0_kv
average_d_kl_nats = 0.000402
p99_d_kl_nats = 0.006094
same_top_p_percent = 100.0
```

These smoke witnesses prove that the candidate asset loads locally and that the
llama.cpp route can emit throughput/RSS and KL evidence. They do not prove the
Capability Ceiling.

The preserved probe ladder now narrows the repair surface:
`32768` / `256` with f16 KV is the best successful point; quantized KV
without flash-attention fails context creation; flash-attention times out even
at 8K; disabling KV offload is not a repair. The route also retains a
non-executing 128K dry-run preview with `not_executed=true` and
`falsifier_green_capable=false`. Treat the current blocker as a
backend/cache-policy stall, not a reason to recreate model download, prompt
suite, shard planner, or runner scaffolding.

## Next Build Cursor

The duplicate-work guard cursor is now:

```text
repair_qwen3_8b_128k_gguf_metal_stall
```

Interpret this narrowly: the canonical MLX model/context contradiction remains
red, but the already-mapped GGUF split has advanced past asset/runner/smoke-KL
setup and now has a 128K stall witness plus a dry-run preview. Do not duplicate
prompt-suite, shard planner, merge, model download, or runner scaffolding.
