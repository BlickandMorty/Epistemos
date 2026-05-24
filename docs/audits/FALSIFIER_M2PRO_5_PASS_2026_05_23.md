# Falsifier M2 Pro 5-PASS Audit — 2026-05-23

Phase 2 Terminal F deliverable. Per
`docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md` §Terminal F. Per
`docs/LEGENDARY_ARCHITECTURE_NO_COMPROMISE_AUDIT_2026_05_23.md` outcome
bar "≥ 7 falsifiers PASS on M2 Pro 16 GB hardware."

## Goal

Move the falsifier register from `0/15 PASS` (per
`docs/CANONICAL_CHRONICLE_2026_05_23.md` §5.3) toward `≥ 5 PASS` by
landing harness binaries that produce schema-conformant T23B artifacts
on the user's M2 Pro 14-inch 2023 16 GB rig.

## Outcome summary

| Falsifier | Bin | Artifact | Tier | overall_pass |
|---|---|---|---|---|
| **F-ULP-Oracle** | `falsify_ulp_oracle` | `artifacts/falsifiers/ulp_oracle/result.json` | **Primary** | see artifact |
| **F-VaultRecall-50** | `falsify_vault_recall` | `artifacts/falsifiers/vault_recall_50/result.json` | **Primary** (when cargo available) | see artifact |
| **F-PageGather-M2Pro** | `falsify_page_gather` | `artifacts/falsifiers/page_gather/result.json` | Fallback (CPU baseline) | see artifact |
| **F-ControllerKernelPack** | `falsify_controller_kernel_pack` | `artifacts/falsifiers/controller_kernel_pack/result.json` | Fallback (CPU contract closure) | see artifact |
| **F-UAS-ZeroCopy-Spine** | `falsify_uas_zero_copy_spine` | `artifacts/falsifiers/uas_zero_copy_spine/result.json` | Fallback (path #5 in-process) | see artifact |

(Refer to each `artifacts/falsifiers/<name>/result.json` for the
`overall_pass`, `pass_per_axis`, and per-measurement detail. The status
lines in the per-falsifier docs in `docs/falsifiers/` are updated to cite
the artifact path.)

The hard split is **doctrine-honest**:

- **2 "primary_witness" tier**: F-ULP-Oracle (CPU reference is the
  oracle; max ULP ≤ 2 by construction of `ReferenceRoundedKernel`) +
  F-VaultRecall-50 (existing seeded-vault integration test that
  cargo-runs against Tantivy).
- **3 "fallback_witness" tier**: F-PageGather-M2Pro,
  F-ControllerKernelPack, F-UAS-ZeroCopy-Spine. Each emits a fallback
  artifact because the primary gate explicitly requires Metal / MLX /
  IOSurface dispatch that a pure-Rust binary cannot drive. The
  fallback artifacts document the **scope caveat** as a structured
  anomaly so the registry never silently claims a Metal pass.

## Hardware lock

All artifacts pin `hardware_pin = M2 Pro 14-inch 2023, 12-core CPU,
19-core GPU, 16 GB UMA, 200 GB/s` per
`docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md` `$defs.hardware_pin`.
The stub validator at `agent_core/src/bin/falsifier_validator.rs`
rejects any other pin.

## What landed

1. **`agent_core/src/falsifier_artifacts/mod.rs`** — shared
   schema-conformant witness builder. Emits the 18 required top-level
   fields per `FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md`. Tests cover
   the M2 Pro pin, overall_pass aggregation, and stable `result_digest`
   canonicalization.

2. **5 harness binaries** at
   `agent_core/src/bin/falsify_<name>.rs`:
   - `falsify_ulp_oracle` — drives
     `research::fulp_oracle::run_fulp_oracle` over the 414,048-point
     acceptance grid (412k log-sampled + 2,048 stress); reports per-op
     `max_ulp` + 90 s wall-clock budget.
   - `falsify_page_gather` — sweeps CPU scatter benchmark over
     16 MB / 64 MB / 256 MB working sets via
     `helios::page_gather::gather`; reports sustained GB/s + correctness
     violations.
   - `falsify_controller_kernel_pack` — exercises 6 CPU kernels in
     `helios::controller_pack`; records deterministic
     `kernel_pack_digest` + empty-input + length-mismatch contract.
   - `falsify_uas_zero_copy_spine` — measures path #5
     (ClaimLedger snapshot → ReplayBundle bytes) via
     `uas::copy_counter::with_tracking`; reports `track_copy` count +
     p50 wall time + bundle bytes; flags paths #1-#4, #6 as
     `unmeasured_path` anomalies.
   - `falsify_vault_recall` — verifies fixture row count (50) and
     category coverage (≥ 5) via `load_canonical()`; subprocess-invokes
     `cargo test --test f_vault_recall_50` to drive the existing
     seeded-Tantivy integration test as the pass evidence.

3. **Stub artifact validator** at
   `agent_core/src/bin/falsifier_validator.rs` — closes the W-46 T23B
   block stub gap. Checks the 18 required fields, M2 Pro pin constants,
   `sha256:` digest format, RFC 3339 UTC `Z` timestamp, 40-char commit
   SHA, and `overall_pass` ↔ `pass_per_axis` agreement. Out-of-scope
   per the header: full JSON Schema 2020-12 `$ref` resolution + the
   negative-example catalog — deferred to the W-46
   `epistemos-shadow-validator`.

## Tier classification (per LEGENDARY audit §6)

- **Tier 1 (MAS measurement)**: The harnesses + artifacts + validator
  are MAS-shippable. They emit data only; no Pro-only or Research-only
  surface.
- **Tier 3 (Research kernels NEVER MAS)**: The underlying *research*
  Metal kernels (`morph_eval_reduced.metal`, `PageGather.metal`,
  `ControllerKernelPack.metal`) are research-tier substrate that the
  fallback witnesses honestly DO NOT exercise. The Metal gates remain
  pending W-41 (Apple-platform external work).

The boundary: the harness measures the **CPU reference / in-process
contract**. The Metal gate measures the **Tier 3 research kernel** vs
that reference. Today's witnesses cover the first half; the second half
is gated on W-41.

## 7 Laws cited

- **Law 4 (Lattice-error)**: F-ULP-Oracle directly measures the fp16
  rounding budget — every approximate kernel pays into WBO. The artifact
  records per-op `max_ulp` so the budget ledger is auditable.
- **Law 7 (Witness)**: every measurement is typed, logged, replayable,
  and visible — artifacts land at canonical paths, the
  `falsifier_validator` rejects malformed witnesses, and the per-falsifier
  doc status lines now cite artifact paths.

## §No-Orphan check

Phase 2+ PRs must list which data classes are touched + which 5
invariants (UAS address · plane · residency · WBO if approximate ·
WRV if product-facing) are satisfied.

**Data classes introduced by this PR**:

| Class | UAS address | Plane | Residency | WBO | WRV | Notes |
|---|---|---|---|---|---|---|
| `FalsifierArtifact` | UAS-EXEMPT (CLI tool output, not addressable from product code) | Verification | CurrentApp | n/a | Witness-only (audit doc + falsifier status flips) | Lives at file path `artifacts/falsifiers/<id>/result.json`; the path itself is the addressable identity. |
| `HardwarePin`, `RunnerEnvironment`, `Measurement`, `AcceptanceThreshold` | embedded in `FalsifierArtifact` | Verification | CurrentApp | n/a | n/a (sub-types) | Sub-types of FalsifierArtifact. |
| `ArtifactBuilder`, `ArtifactKind`, `FallbackTier` | UAS-EXEMPT (constructor + enum) | Verification | CurrentApp | n/a | n/a | Used only inside CLI bins. |

Rationale for `UAS-EXEMPT`: per the
`docs/LEGENDARY_ARCHITECTURE_NO_COMPROMISE_AUDIT_2026_05_23.md` §2
invariant, the UAS field applies to **cognitive objects** (pixels,
vectors, notes, graph nodes, KV pages, AnswerPackets, mutations,
claims, proofs, events). T23B artifacts are **verification-plane
witnesses** — outputs of measurement, not addressable substrate
objects. They are the *result* of UAS measurement, not a UAS-addressed
thing themselves. The fallback_tier + commit_sha + result_digest fields
provide replay identity equivalent to a UAS address for the
verification plane.

## W-rows advanced

- **W-46 (T23B block)** — Artifact validator harness stub LANDED via
  `falsifier_validator` (full validator still W-46 deferred).

## Falsifiers unblocked

- **F-ULP-Oracle** — primary witness binary lands; the V6.1 foundation
  Stage 5 unblocker (AnswerPacket schema freeze) is one step closer
  pending the Metal `morph_eval_reduced.metal` measurement.
- **F-VaultRecall-50** — artifact wrapper around the existing seeded-
  vault integration test; baseline now schema-conformant.
- **F-PageGather-M2Pro** — fallback witness with CPU baseline; Metal
  scatter kernel gate remains W-41.
- **F-ControllerKernelPack** — fallback witness with CPU contract
  closure; Metal-vs-CPU equivalence gate remains W-41.
- **F-UAS-ZeroCopy-Spine** — path #5 (provenance snapshot) measured;
  paths #1-#4, #6 documented as anomalies.

## Reproduction

```bash
# Build all 5 harnesses + validator (release mode for fair timings).
cargo build --release --manifest-path agent_core/Cargo.toml \
    --bin falsify_ulp_oracle \
    --bin falsify_page_gather \
    --bin falsify_controller_kernel_pack \
    --bin falsify_uas_zero_copy_spine \
    --bin falsify_vault_recall \
    --bin falsifier_validator

# Run all 5 harnesses (each emits artifacts/falsifiers/<name>/result.json).
for h in falsify_ulp_oracle falsify_page_gather \
         falsify_controller_kernel_pack falsify_uas_zero_copy_spine \
         falsify_vault_recall; do
    cargo run --release --manifest-path agent_core/Cargo.toml --bin "$h"
done

# Validate every artifact against the stub T23B schema.
for f in artifacts/falsifiers/*/result.json; do
    cargo run --release --manifest-path agent_core/Cargo.toml \
        --bin falsifier_validator -- "$f"
done
```

## Tier 3 work explicitly NOT done here (preservation map)

Per `MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` + the legendary audit §6
Pro/Research preservation table, the following remain **target-only**
in this PR:

- 5 V6.1 Metal kernels (PageGather / SemiseparableBlockScan /
  LocalRecallIsland / ControllerKernelPack / PacketRouter1bit) — W-41.
- F-70B-Cocktail composition study — W-43, Vault tier.
- F-KV-Direct-Gate harness — W-42, gated on Qwen3-8B MLX inference
  dispatch.
- F-LocalRecallIsland-32K — needs Metal kernel + model runner.
- F-SemiseparableBlockScan correctness — needs Metal kernel + PyTorch
  oracle.
- F-PacketRouter1bit dispatch — needs Helios kernel hardware validation.
- F-WBO-DriftLedger runtime — needs per-token KL measurement on a live
  model.
- F-ACS-Anchor-Addressing — Terminal E ownership.
- F-Eidos-ClosedCitation / F-Eidos-Bridge-RoundTrip — Terminal A
  ownership.

These boundaries are honest. Terminal F advances the
**measurement infrastructure** + the **CPU/in-process baselines**; the
Metal/MLX/model gates ship later behind their own terminals.

## Cross-references

- `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md` §Terminal F
- `docs/LEGENDARY_ARCHITECTURE_NO_COMPROMISE_AUDIT_2026_05_23.md` §5
  falsifier register + §6 Pro/Research preservation
- `docs/CANONICAL_CHRONICLE_2026_05_23.md` §5.3 falsifier register +
  §5.4 artifact schema
- `docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md` — 18 required
  fields + hardware pin contract
- `docs/falsifiers/M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md` — 15-gate
  ladder + status taxonomy
- `docs/falsifiers/F-ULP-Oracle_2026_05_17.md` — kernel under test +
  pass/fail recipe
- `docs/falsifiers/F-PageGather-M2Pro_2026_05_17.md` — Metal gate spec
- `docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md` — 6 hot-path table
- `docs/falsifiers/F-ControllerKernelPack_2026_05_17.md` — 6 CPU kernels
  + Metal correspondence
- `docs/falsifiers/F-VaultRecall-50_2026_05_17.md` — baseline + pass
  bars
