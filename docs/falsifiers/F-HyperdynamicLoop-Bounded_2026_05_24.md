---
falsifier: F-HyperdynamicLoop-Bounded
created_on: 2026-05-24
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: IMPLEMENTED
---

# F-HyperdynamicLoop-Bounded

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).

| Field | Value |
|---|---|
| Purpose | Prove the Hyperdynamic Schema Loop primitive (Terminal S) **always terminates** under its declared `RepairBudget` — no infinite repair loop is reachable from any adversarial draft on the 100-prompt corpus. |
| Current status | IMPLEMENTED. Spec + harness + artifact land in Terminal S branch `phase2-terminal-s-hyperdynamic-loop-2026-05-24`. Source: `agent_core/src/hyperdynamic_loop/`, harness: `agent_core/src/bin/falsify_hyperdynamic_loop_bounded.rs`, artifact: `artifacts/falsifiers/hyperdynamic_loop_bounded/result.json`. |
| Input fixture | 100-prompt adversarial corpus generated deterministically (xorshift32 seeded with `HYPERDYNAMIC_LOOP_BOUNDED_SEED = 0x5_2025_05_24`). Each prompt produces one draft for each of the three concrete loops (AdmissionRepairLoop, WitnessRepairLoop, and — when `feature = "research"` is enabled — SchemaRepairLoop). |
| Pass threshold | On Jojo's M2 Pro 14-inch 2023, 16 GB UMA, approximately 200 GB/s memory bandwidth: **(a)** every prompt finalizes in ≤ `RepairBudget::DEFAULT.max_retries = 3` retries; **(b)** every prompt finalizes in ≤ `RepairBudget::DEFAULT.max_latency = 5_000 ms` wall-clock; **(c)** zero prompts return an outcome outside `{Accepted, Quarantined, QuarantinedBudgetExhausted}`; **(d)** the harness's own wall-clock budget caps at 30 s for all 100×3 = 300 loop runs combined. |
| Failure meaning | A non-terminating repair path exists. Either the runner's retry cap is off-by-one, the wall-clock check uses the wrong clock, or a concrete loop returns `RepairWith` without monotonic progress, causing the executor to wedge on adversarial drift. |
| Fallback route | Keep the three concrete loops out of `mission_run.rs` until the bound is proved. Without the witnessed bound, consumer code reverts to ad-hoc retry — the failure surface fragments per the Terminal S motivation. |
| Product lane | MAS (default features) for AdmissionRepairLoop + WitnessRepairLoop. SchemaRepairLoop runs under `--features research` only, mirroring `agent_core::research::hyperdynamic_schemas` shipping discipline. |
| Exact command | `cargo run --manifest-path agent_core/Cargo.toml --release --bin falsify_hyperdynamic_loop_bounded -- --output artifacts/falsifiers/hyperdynamic_loop_bounded/result.json` |
| Expected artifact | `artifacts/falsifiers/hyperdynamic_loop_bounded/result.json` with the per-loop pass/fail breakdown, max observed retries, max observed wall-clock, and the deterministic corpus seed. |

## Canon Anchors

- Terminal S spec: [docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md §Terminal S](../PHASE_2_TERMINAL_PROMPTS_2026_05_23.md#terminal-s--hyperdynamic-schema-loop-primitive-new).
- Substrate motion: [docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md §12.6](../fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md#126-the-3-ontology-motion-grammar-holds-at-every-granularity) (Mutate / Promote at the schema-typed-output granularity).
- Trait surface: `agent_core::hyperdynamic_loop::{HyperdynamicLoop, RepairBudget, RepairVerdict, RepairOutcome}`.

## Failure Criterion

The falsifier fails if **any** of the following hold:

1. A single corpus prompt drives the runner past `RepairBudget::DEFAULT.max_retries = 3` retries.
2. A single corpus prompt drives the runner past `RepairBudget::DEFAULT.max_latency = 5_000 ms` wall-clock.
3. The total harness wall-clock exceeds 30 s on the floor hardware.
4. Any prompt returns an outcome outside the three documented `RepairOutcome` variants (this is a type-system invariant the harness asserts at runtime).
5. The `result.json` artifact is absent or its `seed` field does not match `HYPERDYNAMIC_LOOP_BOUNDED_SEED` (the corpus is otherwise replayable from `seed` alone).

## Artifact Schema Axes

The expected `result.json` must conform to [Falsifier Artifact Schema](FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md) and include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`:

- `loops_run` — total draft × loop iterations executed.
- `max_retries_observed` — max repair attempts observed in any single draft.
- `max_latency_ms_observed` — max wall-clock observed in any single draft.
- `total_wall_clock_ms` — harness end-to-end wall-clock.
- `outcome_partition` — count per `{accepted, quarantined_explicit, quarantined_budget_exhausted}` (zero-sum partition assertion).

## Corpus Construction

The 100-prompt corpus is **deterministic**: a single `u32` seed (`HYPERDYNAMIC_LOOP_BOUNDED_SEED`) feeds xorshift32 to produce one draft per loop kind per index. Per-loop adversarial shapes:

- **AdmissionRepairLoop** — verdict cycles across `{Allow, AllowWithWarning, Defer, Quarantine, Reject}` weighted toward `Defer` (50 %) to exercise the repair path.
- **WitnessRepairLoop** — state cycles across `{Verified, RepairableMismatch, Invalid}` weighted toward `RepairableMismatch` (50 %).
- **SchemaRepairLoop** (research feature) — `{empty draft against required schema, type-mismatched value, unknown-field value, fully-valid value}` cycles.

For repair paths, the harness's `re_emit` closure is intentionally **non-progressive**: it returns the draft unchanged. This forces the runner's bounded-retry contract to fire on every `RepairWith` and is the strongest adversarial shape the corpus contains — if the loop terminates under non-progress, it terminates under any progress.
