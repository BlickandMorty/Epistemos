---
falsifier: F-70B-Local-Cocktail-Lite
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PREFLIGHT FAILURE REPORT IMPLEMENTED
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

# F-70B-Local-Cocktail-Lite

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove the 70B-class local cocktail composes enough to identify whether the capability ceiling is real on the M2 Pro floor, without presenting it as a product feature. |
| Current status | PREFLIGHT FAILURE REPORT IMPLEMENTED. `Tools/falsifiers/f_70b_local_cocktail_lite.sh` now emits a schema-valid failure artifact and validates it. No local 70B product claim exists yet: the harness records missing model/reference/runtime gates until prompt-level measurements replace the sentinel values. Active Assembly, Sparse Runtime Split, and UAS/AcsAnchor mmap residency now contribute component artifacts, but none replace the missing local 70B weights and live sparse 70B runtime. |
| Input fixture | 70B-class candidate set such as Llama-3.3-70B, Qwen2.5-72B, or Hermes-4-70B; 50-prompt suite covering MMLU-Pro subset, HumanEval, long-context reasoning, and multi-turn coherence; cloud/fp16 reference path; sparse local path using ternary/BitNet, hybrid SSM, KV-Direct, PageGather, active assembly, speculative decoding, and optional cascade. |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: D_KL < 0.1 nats versus fp16/cloud reference, decode >= 5 tok/s, TTFT <= 30 s on a 4k prompt, resident memory < 14 GB, first run <= 2 h, and warm-cache run <= 30 min; any miss must identify the bottleneck. |
| Failure meaning | The 70B local-cocktail composition does not hold on the real floor, or the bottleneck is unknown; no local 70B product, marketing, or architecture-ceiling claim may ship. |
| Fallback route | Publish the fail report and pivot to the next strongest cocktail, likely Granite-4.0-H-Micro plus Network Cascade for large-model outliers; keep 70B paths Pro Vault-Preserved / Pro Research only. |
| Product lane | Capability Ceiling / Pro Vault-Preserved / Pro Research only; never MAS/user-facing until the composition artifact passes and product policy is revisited. |
| Exact command | `Tools/falsifiers/f_70b_local_cocktail_lite.sh` |
| Expected artifact | `artifacts/falsifiers/70b_local_cocktail_lite/result.json` with prompt-level D_KL, TTFT, tok/s, RSS, cache state, component bottleneck, and next-best-cocktail recommendation. |

## Canon Anchors

- MASTER_FUSION: [§1 local-computer thesis](../_consolidated/00_canonical_authority/MASTER_FUSION.md#1--what-epistemos-is-the-one-paragraph-thesis-distilled-from-5-docs) and [§3 claim 2 honest capability gating](../_consolidated/00_canonical_authority/MASTER_FUSION.md#3--convergent-claims-where-3-docs-agree--these-are-bedrock), because the 70B cocktail is ceiling research until the local floor proves it.
- Unified Active Substrate Canon: [§4 Terminal B prompt cross-link](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#4-uas-acs-cross-link-map) and [§5 MAS-first sort](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md#5-v1--v1x--v2--never-ships-sort), read through the current UAS/AcsAnchor naming split, which keeps this gate Pro Vault-Preserved / Pro Research only.

## Failure Criterion

This falsifier fails if D_KL is at least 0.1 nats, decode is below 5 tok/s, TTFT exceeds 30 s on a 4k prompt, resident memory reaches 14 GB, first or warm-cache runtime exceeds the threshold, the miss lacks a bottleneck, or no Jojo M2 Pro 16 GB UMA artifact exists.

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`: `d_kl_nats`, `decode_tok_s`, `ttft_seconds`, `resident_memory_gb`, and `bottleneck_identified`.

## 2026-05-27 Preflight Implementation

The harness now exists and is intentionally red:

```bash
Tools/falsifiers/f_70b_local_cocktail_lite.sh
```

It writes `artifacts/falsifiers/70b_local_cocktail_lite/result.json` and then
runs `agent_core::falsifier_validator` against the artifact. The harness exits
non-zero while the falsifier is still a failure report, but the artifact itself
is schema-valid and names the current bottleneck. This is the guardrail the
70B/UAS/AcsAnchor ceiling needs: every future improvement must move a named axis from
sentinel/failure to measured/pass instead of lowering the dense MLX memory gate.
It also carries `active_assembly_artifact_available` and
`eml_geometry_scan_chart_coverage_available` so the
"EML/Geometry/Scan chart for weights, layers, KV pages, and kernels" ambition
cannot disappear while the runtime is still opaque.

Environment inputs reserved for the real prompt-level run:

- `EPISTEMOS_70B_MODEL_PATH` — local 70B-class candidate weights.
- `EPISTEMOS_70B_PROVIDER_REFERENCE` — replayable
  `ProviderReferenceManifest` JSON for fp16/cloud/local reference material
  retained under the artifact root when used. A path existing on disk is not
  enough; it must validate row-root paths, digests, replay permission, and
  local-vs-hosted retention/data-class rules.

Until those are present and the sparse 70B runtime is wired, this gate remains
Pro Vault-Preserved / Pro Research only.

## 2026-05-28 Route Kernel

`F-70B-Local-Cocktail-Lite` is now consumed by the route-level
`F-Capability-Ceiling-Evaluation-Kernel`.

```bash
Tools/falsifiers/f_capability_ceiling_evaluation_kernel.sh
```

The route artifact lives at
`artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json`. Its
current result is red and names the next bottleneck before any future 70B work
continues. This prevents the 70B row-root from drifting into a product claim
while PageGather dense evidence, live KV-Direct, live sparse 70B runtime, and
live 70B chart coverage remain incomplete. As of 2026-05-28,
`F-ActiveAssembly-Minimal` and `F-Sparse-Runtime-Split` are no longer missing
synthetic component artifacts, and `F-UAS-ACS-MmapResidency` is no longer
missing as a file-backed residency component artifact. The 70B cocktail reads
them as component inputs while keeping `sparse_70b_runtime_available=false` and
`eml_geometry_scan_chart_coverage_available=false` until model-backed runtime
rows exist.

`F-Sparse-Runtime-Split` contributes these 70B preflight axes:

- `sparse_runtime_split_artifact_available=true`
- `synthetic_ir_chart_coverage_available=true`
- `eml_geometry_scan_chart_coverage_available=false` until live model-backed
  weights/layers/KV/kernel rows exist

`F-UAS-ACS-MmapResidency` contributes this preflight axis:

- `uas_acs_mmap_residency_artifact_available=true`

That axis only proves file-backed UAS/AcsAnchor residency. It does not prove live
70B token generation, residual-patched KV spill, or model-quality parity.

Additional live env input reserved for promotion:

- `EPISTEMOS_70B_SPARSE_RUNTIME_PATH` — model-backed sparse runtime trace or
  artifact root. This must exist before `sparse_70b_runtime_available` can pass.

## 2026-05-30 WeightBlock Range-Hash Gate

The 70B preflight now reads the bounded byte-range fingerprint artifact before
it trusts a `WeightBlockManifest` active set:

```text
artifacts/falsifiers/weight_block_range_hash_dry_run/result.json
```

New axis:

- `weight_block_range_hash_dry_run_available=true`

Required upstream axes:

- `bounded_range_hashed`
- `range_len_bytes`
- `over_limit_rejected_before_read`
- `short_reader_rejected`
- `known_hash_manifest_valid`
- `no_model_file_touched`

This proves the manifest layer can fingerprint explicit byte ranges without
hashing or loading a real model file. It is deliberately ordered before
`F-ResidencyPlan-DryRun`: a 70B active set may not cite SSD-backed byte ranges
until the range-hash ABI has proved bounded reads, over-limit rejection, short
reader rejection, known-hash parity, and no model-file access.

If a future local 70B model exists but this gate is missing, the preflight now
halts at:

```text
missing_weight_block_range_hash_dry_run
```

## 2026-05-30 ResidencyPlan Dry-Run Gate

The 70B preflight now reads the non-executing planner artifact:

```text
artifacts/falsifiers/residency_plan_dry_run/result.json
```

New axis:

- `residency_plan_dry_run_available=true`

This means the 70B route now knows that a model-shaped active set can be
represented and budgeted before runtime:

```text
72 GiB cold addressed bytes
872,415,232 active runtime bytes
0 runtime model bytes loaded
Sherry / Leech / NF4 route labels present
missing rollback rejected
```

The current 70B preflight remains red, as intended. After this update the
primary bottleneck moved forward to:

```text
missing_fp16_or_provider_reference
```

That is progress: the architecture now has a planner witness, while the live
quality/reference/runtime gates remain honest. No product or live 70B inference
claim may ship until the prompt-level run replaces the sentinel D_KL, tok/s,
TTFT, and RSS values.

## 2026-05-30 Provider Reference Manifest Gate

The next bottleneck is now stricter than "file exists." The preflight reads
`EPISTEMOS_70B_PROVIDER_REFERENCE` as a replay manifest and only passes
`provider_reference_available` when the manifest validates, its retained
artifact files exist, the prompt-suite sidecar exists, and both retained files
match their declared SHA256 digests.

Source ABI:

- `ProviderReferenceManifest::from_path`
- `ProviderReferenceKind::{LocalFp16Replay, HostedZeroRetentionReceipt}`
- `ReferenceDataSentClass::{LocalOnly, PublicBenchmarkIds, HashedPromptIds, RedactedFeatureDigest, PromptEmbeddings}`
- `ReferenceRetentionClaim::{LocalFileOnly, ZeroRetention}`
- prompt-suite binding fields: `prompt_suite_id`,
  `prompt_suite_artifact_ref`, and `prompt_suite_artifact_sha256`

New preflight axis:

- `provider_reference_manifest_valid`
- `provider_reference_replay_files_valid`
- A shape-only retained fixture can make `provider_reference_manifest_valid=true`
  while keeping `provider_reference_available=false`.
- A prompt-level manifest with missing or tampered replay files keeps
  `provider_reference_replay_files_valid=false` and cannot advance the gate.

Required safety:

- artifact paths stay under `artifacts/falsifiers/70b_local_cocktail_lite/`
- no `.` or `..` path segments
- digests are `sha256:<64 lowercase hex>`
- `replay_allowed=true`
- prompt-level references require at least 50 prompts and a digest-bound prompt
  suite under the 70B row root or the canonical KV-Direct prompt-suite root
- retained reference and prompt-suite files must exist on disk and hash-match
  the manifest; JSON alone is never enough
- local fp16 references use `LocalOnly` data and `LocalFileOnly` retention
- hosted references use non-local data class, `ZeroRetention`, request digest,
  and redaction digest

This still does not call a provider, send prompts, or run inference. It is only
the replay contract needed before a future prompt-level 70B comparison can be
trusted.

The shape-only dry-run is now retained at:

```text
artifacts/falsifiers/70b_local_cocktail_lite/provider_reference_manifest_dry_run/shape_only_manifest.json
```

When the 70B preflight is pointed at that fixture, it reports:

```text
provider_reference_manifest_valid=true
provider_reference_replay_files_valid=true
provider_reference_available=false
provider_reference_status=shape_only_manifest
primary_bottleneck=missing_fp16_or_provider_reference
```

That is the desired behavior: ABI shape can be tested without falsely advancing
the actual fp16/provider comparison gate.
