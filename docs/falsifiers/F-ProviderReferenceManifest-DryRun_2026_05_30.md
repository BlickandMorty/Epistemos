---
state: primary_witness
created_on: 2026-05-30
falsifier_id: F-ProviderReferenceManifest-DryRun
artifact: artifacts/falsifiers/provider_reference_manifest_dry_run/result.json
command: Tools/falsifiers/f_provider_reference_manifest_dry_run.sh
scope_guard: shape-only reference manifest; no provider call, prompts, fp16 logits, MLX, Metal, KV, or 70B inference executed
---

# F-ProviderReferenceManifest-DryRun - 2026-05-30

## Verdict

`F-ProviderReferenceManifest-DryRun` proves the next safe reference ABI for
`F-70B-Local-Cocktail-Lite` without creating fake fp16/provider evidence.

It writes a tiny retained local fixture under the 70B row root:

```text
artifacts/falsifiers/70b_local_cocktail_lite/provider_reference_manifest_dry_run/shape_only_reference.jsonl
artifacts/falsifiers/70b_local_cocktail_lite/provider_reference_manifest_dry_run/shape_only_prompt_suite.json
artifacts/falsifiers/70b_local_cocktail_lite/provider_reference_manifest_dry_run/shape_only_manifest.json
```

The manifest validates as a `ProviderReferenceManifest`, but its
`evidence_scope` is `shape_only_fixture`, so the 70B preflight must not count it
as a prompt-level fp16/provider reference.

The gate also re-opens the retained sidecar and prompt-suite files and checks
their bytes against the declared `sha256:<64hex>` digests. A manifest whose JSON
shape is valid but whose replay files are missing or tampered remains unusable
as reference evidence.

## Artifact Summary

Artifact:

```text
artifacts/falsifiers/provider_reference_manifest_dry_run/result.json
```

Minimum axes:

| Axis | Result |
|---|---:|
| Shape fixture written | `true` |
| Manifest valid | `true` |
| Prompt-level reference | `false` |
| Does not advance 70B reference gate | `true` |
| Row-root path | `true` |
| Digest matches sidecar | `true` |
| Replay files valid | `true` |
| Prompt suite bound | `true` |
| No provider call | `true` |

## What This Does Not Prove

- It does not prove fp16 reference logits.
- It does not call a hosted provider.
- It does not send prompts.
- It does not retain raw prompt text.
- It does not prove live 70B generation.
- It does not advance `provider_reference_available` in the 70B preflight.

The point is the opposite: agents may keep a retained shape fixture for the
reference ABI, while `F-70B-Local-Cocktail-Lite` remains red until a real
prompt-level reference manifest exists.

## Canon Link

This gate supports:

- [F-70B-Local-Cocktail-Lite](F_70B_LOCAL_COCKTAIL_LITE_2026_05_18.md)
- [F-ResidencyPlan-DryRun](F-ResidencyPlan-DryRun_2026_05_30.md)
- [Addressable Neural Substrate Canon](../fusion/ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md)

The invariant is:

```text
reference manifest shape can be tested early
  -> shape-only fixtures are preserved
  -> prompt-suite identity and retained replay bytes are digest-bound
  -> only prompt-level replay manifests advance the 70B comparison gate
```
