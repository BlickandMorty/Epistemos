# HELIOS Metal Kernel Index - Canonical Epistemos Re-Derivation

> Created 2026-05-03 during fusion verification floor STEP 2.
> Source reference: `/Users/jojo/Downloads/GPT research/docs/METAL_KERNELS.md`.
> Authority note: GPT's `kernels/*.metal` pack is a research mockup. Current
> Epistemos shader authority is the in-tree `Epistemos/Shaders/` directory.

## Drift Resolved

The fusion handoff asked for every kernel under `agent_core/metal/`. Current
Epistemos has no `agent_core/metal/` directory. The canonical path is:

```text
Epistemos/Shaders/
Epistemos/Shaders/Mamba2/
```

This is not a blocker. It means the STEP 2 verifier must inspect the real
Xcode/Metal shader bundle and not the GPT mockup path.

## Canonical Kernel Inventory

| Kernel file | Entry points | Budget term | Current role | Claim ceiling |
|---|---|---|---|---|
| `Epistemos/Shaders/CodeEditorEmbedding.metal` | `cosineSimilarityBatch`, `batchNormalize` | `T_Q`, `T_S` | GPU batch cosine + normalization for semantic-search embeddings | Performance helper only; not proof of semantic correctness |
| `Epistemos/Shaders/LandingWave.metal` | `landing_wave_step`, `landing_wave_clear`, vertex/fragment wave stages | UI-only | Landing-page liquid ASCII wave | Visual surface, never proof |
| `Epistemos/Shaders/ThinkingGlow.metal` | `thinking_glow_vertex`, `thinking_glow_fragment` | UI-only | Thinking-state glow | Visual surface, never proof |
| `Epistemos/Shaders/Mamba2/direct_conv.metal` | `depthwise_conv1d_k4`, `depthwise_conv1d_k4_silu`, `conv1d_step` | `T_W`, `T_K` | Mamba-2 depthwise conv and decode state update | Requires CPU/MLX golden tests before runtime authority |
| `Epistemos/Shaders/Mamba2/elementwise_ssm_helpers.metal` | `chunk_state_decay`, `ssd_output_merge`, `silu_gate`, `rms_norm` | `T_W`, `T_K` | Mamba-2 SSD helpers and normalization | Numerics must be checked against deterministic references |
| `Epistemos/Shaders/Mamba2/inter_chunk_scan.metal` | `inter_chunk_reduce`, `inter_chunk_scan_tiles` | `T_K` | Apple-safe multi-dispatch inter-chunk state passing | Correctly avoids Apple GPU forward-progress assumptions |
| `Epistemos/Shaders/Mamba2/segsum_stable.metal` | `segsum_stable`, `segsum_stable_tiled` | `T_W`, `T_K` | Stable segment-sum lower-triangular matrix construction | Stability claim limited to clamped/log-space implementation |

## Canonical Kernel Rules

- Hot inference buffers should prefer shared UMA-compatible memory. Any
  `.storageModeManaged` or `.storageModePrivate` in an inference path must be
  treated as drift until a deliberation proves it is outside the hot path.
- Apple GPU kernels must not rely on cross-threadgroup forward progress. The
  Mamba-2 inter-chunk scan explicitly uses reduce-then-scan multi-dispatch.
- UI shaders are not substrate proofs. `LandingWave` and `ThinkingGlow` may be
  beautiful, but tests and AgentEvents remain the evidence layer.
- GPT's EML/FWHT/Sherry/CountSketch kernels remain research references until
  re-derived into this tree with CPU golden references.

## Verification Hooks

`scripts/verify_hotpath.py` checks:

- All canonical shader files above exist.
- Each shader has at least one Metal entry point.
- The Mamba-2 shader set has at least four files.
- The inter-chunk shader contains the Apple forward-progress warning and the
  reduce-then-scan pattern.
- Current hot-path Swift Metal allocation checks do not introduce
  `.storageModeManaged` or `.storageModePrivate`.

## Open Follow-Ups

- Add CPU golden-reference tests for each Mamba-2 kernel before claiming
  runtime correctness.
- STEP 4e / PR61 seeded Rust-side Metal source ownership under
  `agent_core/metal/` for six HELIOS kernels:
  `eml_softmax_lse.metal`, `count_sketch_update.metal`, `kv_fingerprint.metal`,
  `dora_apply.metal`, `ternary_gemv.metal`, and
  `ternary_proj_residual.metal`. These compile with `xcrun metal`, but are not
  runtime authority until a future bridge adds CPU golden references and an
  explicit dispatch gate.
- Swift/Xcode-owned UI and Mamba-2 runtime shaders remain under
  `Epistemos/Shaders/`. The new `agent_core/metal/` files are substrate seeds,
  not a bundle migration.
