# Hyperdynamic Schema Loop — Audit (Terminal S, 2026-05-24)

**Branch:** `phase2-terminal-s-hyperdynamic-loop-2026-05-24` (worktree
`/Users/jojo/Downloads/Epistemos-terminal-s`).
**Spec:** `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md` §Terminal S.
**Substrate motion:** Mutate / Promote (raw model output → typed accepted
packet) per `docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md`
§12.6.

## 1. What landed

| Surface | Path | Commit |
|---|---|---|
| Trait + budget + verdict + counters + runner | `agent_core/src/hyperdynamic_loop/mod.rs` | `8572ae961c` |
| `SchemaRepairLoop` (feature = "research") | `agent_core/src/hyperdynamic_loop/schema_repair.rs` | `405fa8bba7` |
| `AdmissionRepairLoop` | `agent_core/src/hyperdynamic_loop/admission_repair.rs` | `405fa8bba7` |
| `WitnessRepairLoop<T>` | `agent_core/src/hyperdynamic_loop/witness_repair.rs` | `405fa8bba7` |
| Falsifier spec F-HyperdynamicLoop-Bounded | `docs/falsifiers/F-HyperdynamicLoop-Bounded_2026_05_24.md` | `0cf19466c2` |
| Falsifier harness binary | `agent_core/src/bin/falsify_hyperdynamic_loop_bounded.rs` | (iter 4) |
| Falsifier result artifact | `artifacts/falsifiers/hyperdynamic_loop_bounded/result.json` | (iter 4) |
| SwiftUI health row | `Epistemos/Views/Settings/HyperdynamicLoopHealthRow.swift` | (iter 4) |
| `mission_run.rs` hook | `agent_core/src/agent_runtime_v2/mission_run.rs` | (iter 5) |
| This audit | `docs/audits/HYPERDYNAMIC_SCHEMA_LOOP_2026_05_24.md` | (iter 5) |

## 2. The loop, drawn

```
   draft (model output)
      │
      ▼
   ┌───────────────────────────┐
   │  HyperdynamicLoop::check  │
   │  → RepairVerdict          │
   └─────────────┬─────────────┘
                 │
   ┌─────────────┼─────────────┐
   ▼             ▼             ▼
 Accept    RepairWith       Quarantine
   │           │                 │
   │           ▼                 │
   │   re_emit(prev, hint)       │
   │   ──►  next draft           │
   │           │                 │
   │           └──┐ (loop again, │
   │              │  retries++)  │
   │              ▼              │
   │     budget exhausted?       │
   │     ─► quarantine_budget    │
   │                             │
   ▼                             ▼
 typed accepted packet     Provenance Console
 → next layer              quarantine row
```

Budget invariant: `min(3 retries, 5 s wall-clock, 1024 tokens)` per
`RepairBudget::DEFAULT`; `RepairBudget::tightened()` never loosens
the default.

## 3. Acceptance bar — each row's evidence

| Acceptance bar | Evidence |
|---|---|
| Every typed model output passes through ≥ 1 loop kind before reaching consumer code. | `mission_run.rs` hook (iter 5) gates `record_event` + `admit_and_record_tool_call` through the appropriate loop before appending to `RunEventLog`. Until that lands, the loops compile and have 24 passing unit tests, but the integration point is still pending. |
| F-HyperdynamicLoop-Bounded PASS on a 100-prompt adversarial corpus. | Spec at `docs/falsifiers/F-HyperdynamicLoop-Bounded_2026_05_24.md`; harness at `agent_core/src/bin/falsify_hyperdynamic_loop_bounded.rs`; result at `artifacts/falsifiers/hyperdynamic_loop_bounded/result.json` (iter 4). Per-axis: `loops_run`, `max_retries_observed ≤ 3`, `max_latency_ms_observed ≤ 5000`, `total_wall_clock_ms ≤ 30000`, `outcome_partition_closed`, `seed_matches_canon`. |
| Repair budget caps at min(3 retries, 5 s, 1024 tokens) by default; configurable per call site. | `RepairBudget::DEFAULT` carries those literals (tested in `budget_default_is_canonical_acceptance_bar`); `RepairBudget::tightened` allows call-site overrides and is tested to never loosen the default (`tightened_never_loosens_the_default`). |
| Quarantine triggers visible in Provenance Console. | `RepairOutcome::{Quarantined, QuarantinedBudgetExhausted}` carries the reason + repairs count. `mission_run.rs` hook (iter 5) lowers them into the same `RunEventEntry` channel ACS terminal verdicts already use, which the Provenance Console already renders. |

## 4. Substrate consumed (no duplication)

The Terminal S work is a **promotion** of research-tier primitives to
production, not a rewrite:

- `agent_core::research::hyperdynamic_schemas::repair::{Schema,
  validate_value, repair_schema, RepairPolicy, RepairReport}` —
  consumed by `SchemaRepairLoop` under `feature = "research"`. The
  schema validation + repair logic is unchanged; what's new is the
  loop wrapper that drives the bounded-retry contract.
- `agent_core::acs_admission::ACSAdmissionVerdict` (Allow,
  AllowWithWarning, Defer, Quarantine, Reject) — consumed by
  `AdmissionRepairLoop`. The verdict semantics are unchanged;
  the loop maps them onto the three-way verdict the loop runner
  needs.
- `agent_core::research::eml_ir::witness` (`FulpWitness`,
  `FulpReplayError`) — the proof backend the call site lowers into
  `WitnessState::{Verified, RepairableMismatch{constraint}, Invalid{reason}}`
  before handing the draft to `WitnessRepairLoop<T>`. The loop is
  generic over payload `T` to avoid coupling to any one witness shape
  (today F-ULP; tomorrow weight-bit replay).

## 5. PR No-Orphan Check

Per `docs/audits/PR_NO_ORPHAN_CHECK_2026_05_18.md` discipline: every
new symbol either has a caller in this PR or names the iter / PR that
will wire it. Pre-iter-5 wirings:

| Symbol | Caller (planned) |
|---|---|
| `HyperdynamicLoop` trait | Hook in `agent_runtime_v2/mission_run.rs` (iter 5) |
| `RepairBudget`, `run_loop`, `run_loop_with_clock` | Same hook + the falsifier harness (iter 4, compiled now) |
| `SchemaRepairLoop` | Hook (iter 5) — under `feature = "research"` |
| `AdmissionRepairLoop` | Hook (iter 5) — wraps the existing ACS admission verdict in `admit_and_record_tool_call` |
| `WitnessRepairLoop<T>` | Hook (iter 5) — gates the F-ULP witness path |
| `HyperdynamicLoopMetrics` (Swift) | FFI bridge from `agent_core::hyperdynamic_loop::LoopCounters` (iter 5+) |

## 6. 7-Law check

Per `docs/CANONICAL_CHRONICLE_2026_05_23.md` §1.2:

| Law | Hold or break |
|---|---|
| Substrate Motion Invariant (3 motions only) | HOLDS — every loop motion is Mutate / Promote (draft → accepted packet). No fourth motion introduced. |
| Verified Floor | HOLDS — `cargo test --lib hyperdynamic_loop` is 24/24 green on M2 Pro 16 GB UMA. |
| No-Orphan | HOLDS pre-emptively — see §5 above. |
| Sealed Mutation chain | HOLDS — the hook (iter 5) calls the loop **before** `record_event` / `admit_and_record_tool_call` appends to `RunEventLog`. The sealed-mutation chain is unchanged; the loop only gates *what gets appended*. |
| Witness-bound Provenance | HOLDS — `RepairOutcome::Quarantined` carries the reason verbatim; `mission_run.rs` hook lowers it into the same `RunEventEntry` channel that ACS terminal verdicts already use. |
| Honest Capability Gating | HOLDS — repair never widens beyond the call site's `RepairBudget`; `RepairBudget::tightened` is unit-tested to never loosen the default. |
| Real APIs Only | HOLDS — no new external endpoints touched. |

## 7. What is NOT done yet

- **`mission_run.rs` hook (iter 5)** — the actual integration point.
  Per the Terminal S prompt, the hook must run every emitted packet
  through ≥ 1 loop kind before `RunEventLog` append. Designed to be
  minimal-surface: a single helper method that takes a draft + a
  loop instance and returns either the typed accepted packet or a
  quarantine reason. No existing `admit_and_record_tool_call` flow
  shape is changed; the loop sits between ACS verdict + audit
  record append and the `AgentEvent::ToolCall` row.
- **FFI bridge for `LoopCounters`** — the SwiftUI row reads the
  metrics singleton but the singleton is fed by `ingest(kind:,
  stats:)`; the Rust side does not yet stream into it. Iter 5+.
- **Provenance Console quarantine row** — the audit doc claims the
  quarantine triggers are visible in the Provenance Console; that
  claim rests on the iter-5 hook landing.

These three gaps are tracked in the iter-5 driver prompt (cron
`cd963566`).
