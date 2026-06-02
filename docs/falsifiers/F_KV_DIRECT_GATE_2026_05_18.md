---
falsifier: F-KV-Direct-Gate
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PREFLIGHT FAILURE REPORT IMPLEMENTED
---

# F-KV-Direct-Gate

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove the L3 SSD Oracle / KV-Direct memory floor: residual-patched cold-spill KV reproduces full-cache output at 128K without blowing the 16 GB rig. |
| Current status | LIVE HARNESS CONTRACT + CANONICAL PROMPT SUITE IMPLEMENTED, ARTIFACT STILL RED. `Tools/falsifiers/f_kv_direct_gate.sh` emits and validates a schema-valid red artifact. The Tier-1 Rust layout/equality contract is measured over 1,000 traces; the harness auto-detects the local Qwen3-8B MLX snapshot when present; `kv_direct_prompt_suite` emits the canonical 100-prompt / 128K / 256-decode manifest. As of 2026-05-28, the resolved local snapshot identity is canonical (`Qwen/Qwen3-8B-MLX-4bit`) but declares only `40960` context tokens and no rope scaling, so the next bottleneck is model/context asset resolution before rerunning the failed 128K shard. |
| Input fixture | Qwen3-8B-MLX-4bit at 128K context; `artifacts/falsifiers/kv_direct_gate/prompt_suite.json` with 100 prompts split into 25 long-prefix recall, 25 multi-turn, 25 code-completion, and 25 reasoning cases; full-RAM KV reference path; residual-patched mmap/NF4 KV test path; synthetic SSD spill is allowed if labeled. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: at least 100 paired prompts, at least 128K context tokens, at least 256 decode tokens per prompt, average D_KL between reference and residual-patched logits < 0.05 nats, peak RAM < 13 GB, decode speed >= 10 tok/s, suite wall-clock <= 30 min, and explicit SSD-spill trace. |
| Failure meaning | KV-Direct does not generalize to the target Qwen3/MLX/128K floor; the app cannot claim 128K local context via SSD oracle on 16 GB hardware. |
| Fallback route | Pivot to softer eviction: selective cold-region purge, prefix caching, attention-sink preservation, or sliding-window attention; keep full-cache/reference path authoritative. |
| Product lane | Verified Floor / MAS-compatible only after gate; Research until Qwen3 128K artifact exists. |
| Exact command | `Tools/falsifiers/f_kv_direct_gate.sh` |
| Expected artifact | `artifacts/falsifiers/kv_direct_gate/result.json` with per-prompt D_KL, token-match/decode metrics, peak RSS, SSD-spill trace, and fallback decision. |

## Canon Anchors

- MASTER_FUSION: [§3 claim 11 multi-objective KV cache precision allocation](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock) and [§3 claim 4 Apple Silicon unified memory](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock).
- Unified Active Substrate Canon: [§2 row 3 KV-Direct gate](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#2-the-6-canonical-surfaces), which is the UAS memory-architecture floor.

## Failure Criterion

This falsifier fails if average D_KL is at least 0.05 nats, peak RAM reaches 13 GB, decode speed drops below 10 tok/s, the 100-prompt suite exceeds 30 min, SSD spill is unlabeled, or no Jojo M2 Pro 16 GB UMA artifact exists.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `average_d_kl_nats`, `peak_ram_gb`, `decode_tok_s`, `suite_wall_clock_min`, and `spill_labeling`.

## 2026-05-27 Preflight Implementation

The harness now exists and is intentionally red:

```bash
Tools/falsifiers/f_kv_direct_gate.sh
```

It writes `artifacts/falsifiers/kv_direct_gate/result.json`, validates the
artifact, and exits non-zero while the live prompt-level gate is still missing.
The artifact separates two facts:

- the Tier-1 Rust direct/reference QK equality contract passes over 1,000
  deterministic traces;
- the actual L3 SSD Oracle metrics (`average_d_kl_nats`, `peak_ram_gb`,
  `decode_tok_s`, `suite_wall_clock_min`, `spill_labeling`) remain sentinel
  failures until Qwen3-8B / 128K / MLX measurement lands.

## 2026-05-28 Live Harness Contract

The harness now has the executable contract needed for the real MLX/Qwen pass.
It still does not load or run Qwen by itself; the model runner must emit the
inputs below, and this falsifier performs the route-level truth check. On
2026-05-28 it began auto-detecting the local Epistemos app-support Qwen3-8B
MLX snapshot. The harness now also reads the resolved model `config.json`; the
currently resolved snapshot is present but declares `max_position_embeddings =
40960` and `rope_scaling = none`, so it fails the 128K model-context axis.

Environment inputs:

| Variable | Required for green | Shape |
|---|---:|---|
| `EPISTEMOS_KV_DIRECT_MODEL_PATH` | yes, unless auto-detected | Existing local `Qwen/Qwen3-8B-MLX-4bit` model directory or file whose `config.json` honestly supports `>=128000` context tokens. If unset, the harness scans Epistemos app-support model storage for `models--Qwen--Qwen3-8B-MLX-4bit`. Noncanonical long-context models are candidate-tier only. |
| `EPISTEMOS_KV_DIRECT_PROMPT_SUITE` | optional if default exists | Prompt-suite manifest path. Default: `artifacts/falsifiers/kv_direct_gate/prompt_suite.json`, generated by `Tools/falsifiers/kv_direct_prompt_suite.sh`. |
| `EPISTEMOS_KV_DIRECT_LOGITS_PATH` | yes, unless using paired files | JSON object `{ "prompts": [{ "reference_logits": [...], "test_logits": [...] }] }` or a raw prompt array. |
| `EPISTEMOS_KV_DIRECT_REFERENCE_LOGITS` | yes, if no paired fixture | JSON logits rows `[[...], ...]` or one row `[...]`. |
| `EPISTEMOS_KV_DIRECT_TEST_LOGITS` | yes, if no paired fixture | Same row count and shape as reference logits. |
| `EPISTEMOS_KV_DIRECT_METRICS_PATH` | yes | JSON object with `peak_ram_gb`, `decode_tok_s`, `suite_wall_clock_min`, `spill_labeling`, `context_window_tokens`, and `decode_tokens_per_prompt`. Aliases `peak_rss_gb`, `decode_tokens_per_second`, `wall_clock_min`, `ssd_spill_labeled`, `context_tokens`, `max_context_tokens`, `prompt_context_tokens`, `generated_tokens_per_prompt`, `tokens_emitted_per_prompt`, and `decode_tokens` are accepted. |
| `EPISTEMOS_KV_DIRECT_SPILL_TRACE` | yes | Existing trace file proving the SSD-spill path and labels used by the metrics run. |

New artifact axes:

- `live_harness_contract_present`
- `model_assets_available`
- `model_identity_matches_canonical`
- `model_context_window_tokens`
- `model_context_supports_required_context`
- `prompt_suite_manifest_available`
- `prompt_suite_prompt_count`
- `prompt_suite_min_context_tokens`
- `prompt_suite_min_decode_tokens_per_prompt`
- `prompt_suite_balanced_family_coverage`
- `reference_logits_available`
- `test_logits_available`
- `live_metrics_available`
- `spill_trace_available`
- `metrics_spill_labeling`
- `spill_trace_ssd_spill_labeled`
- `spill_trace_route_is_canonical`
- `spill_trace_residual_patch_applied`
- `spill_trace_mmap_backed`
- `spill_trace_quantized_storage`
- `spill_trace_cold_kv_bytes`
- `live_prompt_count`
- `context_window_tokens`
- `decode_tokens_per_prompt`
- `live_harness_mode`

Model-config labels are also recorded:

- `canonical_model_repo_id`
- `resolved_model_repo_id`
- `resolved_model_asset_path`
- `resolved_model_type`
- `resolved_model_context_source`
- `resolved_model_rope_scaling`

The D_KL axis is now computed from supplied prompt logits:

```text
average_d_kl_nats = mean_prompt sum softmax(reference_logits) * (ln p_ref - ln p_test)
```

If any live input is missing or malformed, the artifact remains a validated
failure report and records a `live_input_parse_error` or missing-input anomaly.
This is the no-compromise behavior: Tier-1 Rust equality stays useful, but it
cannot promote the 128K SSD Oracle without prompt-level logits, fixture shape,
RSS, throughput, wall-clock, and spill-trace witnesses. A small prompt smoke
fixture may help debug the runner, but cannot flip the gate green.

### Spill Trace Semantic Contract

`spill_labeling=true` in metrics is not enough. The spill trace itself must
prove the canonical route:

```text
route = residual_patched_mmap_nf4_ssd_spill
ssd_spill_labeled = true
residual_patch_applied = true
mmap_backed = true
kv_storage_format = nf4 or equivalent quantized storage
cold_kv_bytes > 0
```

`F-UAS-ACS-MmapResidency` now proves the file-backed mmap UAS/ACS residency
slice that this spill trace must build on. That upstream witness is necessary
but not sufficient: the KV gate still needs live reference/test logits,
resident-memory metrics, throughput metrics, and a spill trace from the model
runner.

Merged shard traces are accepted only when every shard route is canonical. A
`prompt_cache_reload`, `kv_quantized`, or `full_kv` route remains a useful
development witness but cannot satisfy `F-KV-Direct-Gate`, even if paired
logits and metrics are present.

## 2026-05-28 Prompt Suite Contract

The canonical prompt-suite manifest is generated by:

```bash
Tools/falsifiers/kv_direct_prompt_suite.sh
```

It writes `artifacts/falsifiers/kv_direct_gate/prompt_suite.json` and defines
the exact 100 prompt families the live runner must materialize with the
resolved Qwen3-8B tokenizer. The manifest is intentionally compact: it stores
seeded prompt specs and target token counts, not a huge pre-tokenized corpus.

The falsifier now requires the manifest shape before the live gate can pass:

- at least `100` prompts;
- minimum declared context target `>=128000`;
- minimum decode target `>=256`;
- at least `25` prompts each for `long_prefix_recall`, `multi_turn`,
  `code_completion`, and `reasoning`.

This moves the next bottleneck from "what should the run measure?" to the real
work: emit paired reference/test logits, live metrics, and SSD-spill trace for
that canonical suite.

## 2026-05-28 Model Context Contract

The gate now refuses to treat "model file exists" as enough for the 128K route.
It first pins model identity, then reads the resolved model's `config.json`.
The canonical target remains:

```text
canonical_model_repo_id = Qwen/Qwen3-8B-MLX-4bit
model_identity_matches_canonical = true
```

Current local resolution:

```text
resolved_model_repo_id = Qwen/Qwen3-8B-MLX-4bit
model_identity_matches_canonical = true
```

This is separate from long-context candidate exploration. The local inventory
found alternates such as `mlx-community/Qwen3-Coder-Next-4bit` with a 262K
declared context window, and the planner can now build explicit candidate
plans for them. Those plans cannot satisfy this falsifier unless canon changes
the model target.

After identity, the gate requires:

```text
model_context_window_tokens >= 128000
model_context_supports_required_context = true
```

Current local resolution:

```text
model_path = /Users/jojo/Library/Application Support/Epistemos/Models/text/hub/models--Qwen--Qwen3-8B-MLX-4bit/snapshots/383413e909f3bc5303ce195ebbdf0339c5a1a2a3
model_type = qwen3
model_context_window_tokens = 40960
resolved_model_context_source = declared_config_context
resolved_model_rope_scaling = none
```

This is a real red gate, not a nuisance. Future agents must resolve a
128K-capable model asset or a locally justified rope/context configuration
before retrying the 100-prompt / 128K shard plan. The earlier `shard_000_000`
runtime failure remains preserved evidence, but it is no longer the first
cursor while the model context contract is red.

## 2026-05-28 MLX Runner Scaffold

`Tools/falsifiers/run_kv_direct_mlx_live.sh` now provides the local MLX runner
side of the contract. It auto-detects the same Qwen3-8B MLX snapshot, reads the
canonical prompt suite, materializes prompts with the model tokenizer, and
writes:

- `artifacts/falsifiers/kv_direct_gate/live_mlx/reference_logits.json`;
- `artifacts/falsifiers/kv_direct_gate/live_mlx/test_logits.json`;
- `artifacts/falsifiers/kv_direct_gate/live_mlx/metrics.json`;
- `artifacts/falsifiers/kv_direct_gate/live_mlx/spill_trace.json`;
- `artifacts/falsifiers/kv_direct_gate/live_mlx/manifest.json`.

Default execution is intentionally smoke-sized and cannot satisfy this
falsifier. The full 100-prompt / 128K / 256-decode run requires
`--allow-full-suite`. A 2026-05-28 smoke run proved that the runner can load the
local Qwen3-8B model and emit full-vocabulary paired logit rows, but it remains
red by design: 1 prompt, 512 context tokens, 1 decode token, no SSD-spill
labeling, and an undersized fixture. This is runner plumbing, not a KV-Direct
green witness.

The runner now supports three explicitly labeled routes:

| Route | Meaning | Promotion status |
|---|---|---|
| `full_kv` | Reference MLX route with the normal prompt cache kept in memory. | Reference only. |
| `kv_quantized` | MLX KV-quantized development route. | Development evidence; does not exercise SSD spill. |
| `prompt_cache_reload` | Saves an MLX prompt cache to disk, clears the in-memory cache, reloads it, and emits test logits from the reloaded cache. | Intermediate file-backed cache witness; still not the residual-patched mmap/NF4 SSD-spill oracle. |

The first `prompt_cache_reload` smoke run wrote a `75,356,889` byte prompt-cache
file under `artifacts/falsifiers/kv_direct_gate/live_mlx/prompt_cache_reload/`
and fed paired logits into `F-KV-Direct-Gate`. The artifact stayed red for the
right reasons: only 1 prompt, 512 context tokens, 1 decode token, and
`spill_labeling=false`. The low smoke D_KL is useful plumbing evidence, but it
does not pay the 128K / RSS / tok/s / SSD-spill budget.

## 2026-05-28 Sharded Full-Suite Runner

The MLX runner now supports `--prompt-offset`, so the full 100-prompt suite can
be executed in restartable shards instead of one fragile terminal session. Each
shard writes the same five contract files as the smoke run.

Example one-prompt shard:

```bash
Tools/falsifiers/run_kv_direct_mlx_live.sh \
  --allow-full-suite \
  --prompt-offset 0 \
  --max-prompts 1 \
  --context-tokens 128000 \
  --decode-tokens 256 \
  --prefill-step-size 512 \
  --test-route prompt_cache_reload \
  --output-dir artifacts/falsifiers/kv_direct_gate/live_mlx_shards/shard_000_000
```

Shards are merged with:

```bash
Tools/falsifiers/merge_kv_direct_mlx_shards.sh \
  --output-dir artifacts/falsifiers/kv_direct_gate/live_mlx_merged \
  artifacts/falsifiers/kv_direct_gate/live_mlx_shards/shard_000_000 \
  artifacts/falsifiers/kv_direct_gate/live_mlx_shards/shard_001_001 \
  ... \
  artifacts/falsifiers/kv_direct_gate/live_mlx_shards/shard_099_099
```

The merger writes `reference_logits.json`, `test_logits.json`, `metrics.json`,
`spill_trace.json`, and `manifest.json` in the exact shape consumed by
`F-KV-Direct-Gate`. It also preserves route labels. Merging prompt-cache reload
or KV-quantized shards still leaves `spill_labeling=false`; only a residual-
patched mmap/NF4 SSD-spill route can flip the final spill axis.

## 2026-05-28 Full-Suite Run Plan

The full 100-prompt job is now mapped into an executable run plan:

```bash
Tools/falsifiers/plan_kv_direct_mlx_shards.sh --write-shell
```

It writes:

- `artifacts/falsifiers/kv_direct_gate/live_mlx_full_suite_plan/full_suite_run_plan.json`;
- `artifacts/falsifiers/kv_direct_gate/live_mlx_full_suite_plan/run_all_shards.sh`.

The current plan creates 100 one-prompt shards at 128K context, 256 decode
tokens per prompt, and `prefill_step_size=512`, then merges them into
`artifacts/falsifiers/kv_direct_gate/live_mlx_merged/`. The Capability Ceiling
kernel now reads this plan as `kv_direct_full_suite_run_plan_available`.

Current planned route is still `prompt_cache_reload`, so the plan is
`falsifier_green_capable=false`. It proves the full run is mapped and
restartable; it does not prove the final SSD-spill oracle. The final route must
still emit paired logits, metrics, and a spill trace for
`residual_patched_mmap_nf4_ssd_spill`.

The planner now also accepts `--model-path` and records model identity in the
plan and shard commands. This is explicitly for candidate-tier development
runs. The current long-context candidate plan is:

```text
artifacts/falsifiers/kv_direct_gate/live_mlx_candidate_qwen3_coder_next_plan/full_suite_run_plan.json
model_repo_id = mlx-community/Qwen3-Coder-Next-4bit
model_identity_matches_canonical = false
falsifier_green_capable = false
```

That plan is useful for testing MLX long-context mechanics on a local 262K
model, but it is not a green path for `F-KV-Direct-Gate`.

## 2026-05-28 First-Shard Runtime Bottleneck

The first mapped shard is now:

```text
artifacts/falsifiers/kv_direct_gate/live_mlx_shards/shard_000_000
```

Two attempts failed before a single prompt row was emitted:

- `prefill_step_size=2048`: Metal command buffer aborted with
  `kIOGPUCommandBufferCallbackErrorImpactingInteractivity`;
- `prefill_step_size=512`: stopped after about 14 minutes with `0` completed
  prompt rows.

The pending-work guard now reports:

```text
resolve_qwen3_8b_128k_context_model_assets_for_kv_direct
```

This changes the next work from "run more shards" or "repair the 128K
first-prompt MLX prefill/runtime path" to "resolve the model/context asset
contract." It is still not a KV-Direct pass.
