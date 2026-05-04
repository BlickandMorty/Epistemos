# HELIOS KV-Direct Gate Runbook - Canonical Epistemos Re-Derivation

> Created 2026-05-03 during fusion verification floor STEP 2.
> Source reference: `/Users/jojo/Downloads/GPT research/bench/G1_KV_DIRECT_GATE.md`.
> Authority note: this is an experiment gate, not a shipped feature.

## Purpose

KV-Direct asks whether Epistemos can replace or compress full KV cache storage
without changing greedy decode outputs. It is valuable only if it preserves the
canonical substrate promises: deterministic, local-first, zero-copy where
possible, no silent cloud fallback, and no UI-as-proof.

## Week 0 Decision Rule

Run KV-Direct versus KV-full on a local MLX Qwen-family 4-bit model at 32k
context first. 128k is a later stretch gate.

Pass condition:

```text
D_KL = 0
token_match = 100%
peak_RAM >= 8x lower than KV-full
no uncontrolled cloud escalation
```

The GPT reference allowed `KL < 0.05` and compression `> 10x`. Canonical
Epistemos uses the stricter handoff rule above until a future deliberation
explicitly loosens it.

## Canonical Inputs

| Input | Canonical path/status |
|---|---|
| Local model route | `Epistemos/Engine/MLXInferenceService.swift` and `Epistemos/State/InferenceState.swift` |
| KIVI arithmetic tolerance | `Epistemos/Engine/KIVIQuantization.swift` and `EpistemosTests/KIVIKVCacheRuntimeTests.swift` |
| SSM/prompt-cache persistence | `Epistemos/Vault/SSMStateService.swift` |
| Live token-throughput blocker | `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` R15 notes |
| Verification floor | `scripts/verify_hotpath.py` |

## Preflight

Before attempting a live KV-Direct run:

1. Confirm `scripts/verify_hotpath.py` passes.
2. Confirm sufficient free memory and thermal headroom.
3. Ensure no cloud provider is selected as fallback.
4. Record model id, quantization, context length, prompt hash, decode settings,
   peak RSS, token/sec, per-token KL, and token match.
5. Save the run artifact under `docs/fusion/fleet/kv-direct-gate/`.

## Run Shape

This runbook intentionally does not provide a shell command yet because the
canonical KV-Direct harness has not been implemented. The first code slice for
this experiment must create a deterministic local harness that can run:

```text
KV-full baseline -> KV-Direct candidate -> compare logits/tokens/memory
```

No benchmark may auto-download a cloud model or call a cloud provider.

## Failure Rules

- If token match is below 100%, stop and inspect before any optimization claim.
- If `D_KL` is non-zero, stop and store the logits for audit.
- If peak RAM is not at least 8x lower, the method may remain a research note
  but cannot be promoted to a product path.
- If the run requires closing user apps to avoid memory pressure, mark the
  result as hardware-conditioned and do not generalize it to Core/App Store.

## Current Status

`KIVIKVCacheRuntimeTests` already proves grouped quantized state formation,
prompt-cache serialization, causal masking, and deterministic arithmetic
tolerance after grouped flush. That is not the KV-Direct gate. It is the floor
that lets a future gate be meaningful.
