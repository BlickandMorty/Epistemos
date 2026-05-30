# F-Qwen3-8B-128K-GGUF-Route

Date: 2026-05-28

## Purpose

Create a separate candidate/fallback lane for a 128K GGUF Qwen3-8B route
without retargeting `F-KV-Direct-Gate`.

The canonical KV gate remains pinned to:

```text
Qwen/Qwen3-8B-MLX-4bit
```

This falsifier is only for:

```text
unsloth/Qwen3-8B-128K-GGUF
```

or a future explicitly documented GGUF retarget. It cannot make the MLX gate
green.

## Artifact

```text
artifacts/falsifiers/qwen3_8b_128k_gguf_route/result.json
```

Current status: schema-valid failure report. The local GGUF asset and
llama.cpp runners are present, but the full 128K route is not proven.

Current bottleneck:

```text
repair_qwen3_8b_128k_gguf_metal_stall
```

## Command

```bash
Tools/falsifiers/f_qwen3_8b_128k_gguf_route.sh
```

Expected exit is non-zero until all candidate route axes pass. The script still
validates the artifact shape with `falsifier_validator`.

## Heavy-Run Safety Gate

The bench helper refuses any GGUF run above `32768` context tokens unless both
conditions are true:

```bash
--allow-full-suite
EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1
```

This is deliberate. The latest 128K probe reproduced a Metal command-buffer
stall on this laptop, and the route must not destabilize the current app while
it is still a Vault/Research candidate. Agents may inspect existing artifacts
and run light source/artifact validators by default; they must not launch
65K/128K/70B-class probes without the explicit heavy-run environment opt-in.

## Required Inputs

| Variable | Meaning |
|---|---|
| `EPISTEMOS_QWEN3_8B_128K_GGUF_PATH` | Local `.gguf` file or directory containing the target GGUF file. If unset, the harness scans Epistemos model storage and Hugging Face cache for `models--unsloth--Qwen3-8B-128K-GGUF`. |
| `EPISTEMOS_QWEN3_8B_128K_GGUF_METADATA_PATH` | JSON metadata proving `context_window_tokens` or `n_ctx_train >= 128000`. |
| `EPISTEMOS_QWEN3_8B_128K_GGUF_RUNNER` | Research measurement runner or in-process GGUF harness path. |
| `EPISTEMOS_QWEN3_8B_128K_GGUF_PROMPT_SUITE` | Optional prompt suite path; defaults to the shared KV prompt suite. |
| `EPISTEMOS_QWEN3_8B_128K_GGUF_LOGITS_PATH` | Paired reference/test logits object. |
| `EPISTEMOS_QWEN3_8B_128K_GGUF_REFERENCE_LOGITS` | Reference logits rows, if not using paired object. |
| `EPISTEMOS_QWEN3_8B_128K_GGUF_TEST_LOGITS` | Test logits rows matching reference rows. |
| `EPISTEMOS_QWEN3_8B_128K_GGUF_METRICS_PATH` | Live metrics JSON: prompt count, context tokens, decode tokens per prompt, RSS, tok/s, wall clock. |

## Live Probe Ledger

### 2026-05-28 context probe

The local candidate asset resolves to:

```text
/Users/jojo/Library/Application Support/Epistemos/Models/text/hub/models--unsloth--Qwen3-8B-128K-GGUF/snapshots/4a4ca8eeed6a9f3cdf58de9a1e86f7376d0059f9/Qwen3-8B-128K-Q4_K_M.gguf
```

The latest green-ish smoke metrics still come from the smaller default live
bench under:

```text
artifacts/falsifiers/qwen3_8b_128k_gguf_route/live_bench/metrics.json
```

That smoke artifact proves runner/asset viability only; it does not prove the
128K contract because it reports `32768` context and `1` prompt.

The first full-context Metal probe was:

```bash
Tools/falsifiers/run_qwen3_8b_128k_gguf_bench.sh \
  --allow-full-suite \
  --context-tokens 128000 \
  --decode-tokens 1 \
  --cache-type-k q4_0 \
  --cache-type-v q4_0 \
  --flash-attn 1 \
  --batch-size 512 \
  --ubatch-size 256 \
  --output-dir artifacts/falsifiers/qwen3_8b_128k_gguf_route/live_bench_128k_q4_0_fa_probe
```

Result:

- artifact: `artifacts/falsifiers/qwen3_8b_128k_gguf_route/live_bench_128k_q4_0_fa_probe/manifest.json`
- status: failure report, no metrics written
- exit: terminated after `1549.18` seconds with no JSON output
- peak RSS: `10352017408` bytes (`~9.64 GiB`)
- Metal backend facts: unified memory true, shared buffers true, residency sets
  true, recommended max working set `12713.12 MB`

Sampling showed the process inside `llama_decode` waiting on a Metal command
buffer (`ggml_metal_synchronize` / `waitUntilCompleted`), so this is evidence
of a full-context runtime/residency stall rather than evidence that 128K is
green. The bench runner now supports `--timeout-seconds` and removes stale
metrics on failure/timeout.

### 2026-05-29 probe-ladder update

The falsifier now ingests the local shape probes under:

```text
artifacts/falsifiers/qwen3_8b_128k_gguf_route/shape_probes
```

Current ladder summary in `result.json`:

- manifests read: `10`
- successful probes: `4`
- best successful shape: `32768` context / `256` decode
- best successful cache policy: `ctk=f16 ctv=f16 flash_attn=false`
- quantized KV without flash-attention: failure observed, no success observed
- flash-attention: timeout observed, no success observed
- no-KV-offload probe: failure/timeout observed, no success observed

This narrows the stall: the current local runner/hardware can run the GGUF
candidate at 32K with f16 KV, but q4/q8 KV fails context creation without
flash-attention even at 8K, flash-attention times out even at 8K, and disabling
KV offload is not a repair. The next work is therefore not another prompt-suite
expansion. It is a backend/cache policy repair: find or build a 128K-capable KV
policy that does not hit the Metal flash-attention stall and does not exceed the
16 GB floor.

## Pass Shape

The candidate route must prove:

- target identity: `unsloth/Qwen3-8B-128K-GGUF`;
- context support: `model_context_window_tokens >= 128000`;
- prompt suite: `>=100` prompts, `>=128000` context, `>=256` decode tokens,
  balanced families;
- paired logits: average `D_KL < 0.05`;
- runtime budget on the 16 GB M2 Pro floor: peak RAM `<13 GB`, decode
  `>=10 tok/s`, suite wall clock `<=30 min`.

If all axes pass, the artifact is a `fallback_witness`, not a primary MLX
witness.

## Non-Drift Rule

This route is allowed to advance GGUF/llama.cpp research and Pro/fallback
runtime work. It must not:

- satisfy `F-KV-Direct-Gate`;
- lower the dense 36B / 70B MAS gates;
- imply the App Store target links GGUF/llama runtime;
- replace the canonical Qwen3-8B MLX model unless the falsifier is explicitly
  retargeted in docs and artifacts.
