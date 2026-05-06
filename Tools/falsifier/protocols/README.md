---
state: canon
canon_promoted_on: 2026-05-06
covers: HELIOS V5 W25 M2 Max falsifier protocols
---

# HELIOS V5 W25 — M2 Max Falsifier Protocols

Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W25 + DOC 0 §0.4:

> *"tools/falsifier/ — Swift + Rust harness; reads YAML protocols, runs on
> attached M2 Max, posts results to ClaimLedger as TypedArtifacts. Nightly
> on dev rig."*

This directory contains one YAML protocol per E/H/PCF/W id that has a real
substrate. Each protocol declares:

- `id` — canonical theorem id (e.g. E4, H17, W12)
- `title` — human-readable name
- `class` — `foundational` | `operational` | `architectural` | `cross_tradition` | `candidate` | `work_slice`
- `lane` — L1 / L2 / L3 / L5 (L4 reserved)
- `severity` — HALT / QUARANTINE / DEGRADE / WARN
- `state` — per `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` §1 WRV ladder
- `statement` — the claim being falsified
- `acceptance` — metric / threshold / units
- `stage_0_proxy` — the cargo test filter that exercises the substrate today
- `m2_max_protocol` — what the real M2 Max-specific run does (target)
- `adversarial` — known attack vectors
- `defenses` — corresponding defenses
- `literature` — citations
- `insertion_site` — where the substrate lives in the repo

## Currently authored protocols

| Id | Class | Lane | Substrate | Stage-0 proxy |
|---|---|---|---|---|
| `E3.yaml` | foundational | L1 | `epistemos-research/src/theorems/e3_morph_field.rs` | `storage::vault` |
| `E4.yaml` | foundational | L1 sampled | `epistemos-research/src/theorems/e4_wbo7.rs` | `scope_rex::metal::softmax` |
| `H2.yaml` | operational | L1 | `agent_core/src/scope_rex/metal/softmax.rs` | `scope_rex::metal::softmax` |
| `H3.yaml` | operational | L1 | `agent_core/src/scope_rex/metal/asa_index.rs` | `scope_rex::metal::asa_index` |
| `H7.yaml` | operational | L1 mix | `agent_core/src/scope_rex/residency.rs` | `scope_rex::residency` |
| `H17.yaml` | cross_tradition | L2 | `agent_core/src/scope_rex/retrieval/hopfield.rs` | `scope_rex::retrieval::hopfield` |
| `W6.yaml` | work_slice | L1 | (cross-refs H3) | `scope_rex::metal::asa_index` |
| `W8.yaml` | work_slice | L1 | `agent_core/src/scope_rex/kv/direct_gate.rs` | `scope_rex::kv::direct_gate` |

## Adding a new protocol

1. Create `protocols/<id>.yaml` matching the schema in `E4.yaml` (the
   richest example).
2. Update this README's currently-authored table.
3. Wire the id into `Tools/falsifier/falsifier.sh` registry (the
   PROTOCOL_TEST_FILTER list).
4. Source-text guard test in `EpistemosTests/HELIOSInvariantSourceGuardTests.swift`.

## Real M2 Max runs (deferred)

Stage-0 runs the cargo test as substrate-presence proxy. Real
M2 Max-specific runs land per a follow-up slice that grows
`falsifier.sh` to:

1. Parse `protocols/*.yaml` (e.g. via `yq` or a Rust binary).
2. Dispatch to the appropriate runner:
   - `cargo test` (substrate path, current)
   - Metal kernel benchmark (when `.metal` files exist)
   - Hardware-bench rig (when M2 Max attached)
3. Compare measured metric to `acceptance.threshold`.
4. Post pass/fail TypedArtifact to ClaimLedger.

Until then this directory is the **declarative manifest** that the
follow-up runner will read.
