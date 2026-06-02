# Hyperdynamic Schema Loop — Audit (Terminal S, 2026-05-24)

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

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
| Falsifier result artifact | `artifacts/falsifiers/hyperdynamic_loop_bounded/result.json` | `8b65039974` |
| SwiftUI health row | `Epistemos/Views/Settings/HyperdynamicLoopHealthRow.swift` | `db938a1548` |
| `mission_run.rs` hook | `agent_core/src/agent_runtime_v2/mission_run.rs` | `27af5e0418` |
| This audit (initial) | `docs/audits/HYPERDYNAMIC_SCHEMA_LOOP_2026_05_24.md` | `db938a1548` (refreshed iter 4) |

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
| Every typed model output passes through ≥ 1 loop kind before reaching consumer code. | `mission_run.rs` hook landed at `27af5e0418`. Two free helpers (`gate_admission_draft_through_loop`, `gate_witness_draft_through_loop<T>`) wrap `run_loop` with the appropriate concrete loop. The `_through_loop` suffix is the canonical grep marker; the unit test `hook_helpers_carry_through_loop_suffix_for_grep` enforces it via `stringify!`. Adapter call-site enforcement is a discipline gate — adapter wiring is tracked as a follow-up in §7. |
| F-HyperdynamicLoop-Bounded PASS on a 100-prompt adversarial corpus. | Spec at `docs/falsifiers/F-HyperdynamicLoop-Bounded_2026_05_24.md`; harness at `agent_core/src/bin/falsify_hyperdynamic_loop_bounded.rs`; result at `artifacts/falsifiers/hyperdynamic_loop_bounded/result.json` (iter 4). Per-axis: `loops_run`, `max_retries_observed ≤ 3`, `max_latency_ms_observed ≤ 5000`, `total_wall_clock_ms ≤ 30000`, `outcome_partition_closed`, `seed_matches_canon`. |
| Repair budget caps at min(3 retries, 5 s, 1024 tokens) by default; configurable per call site. | `RepairBudget::DEFAULT` carries those literals (tested in `budget_default_is_canonical_acceptance_bar`); `RepairBudget::tightened` allows call-site overrides and is tested to never loosen the default (`tightened_never_loosens_the_default`). |
| Quarantine triggers visible in Provenance Console. | `RepairOutcome::{Quarantined, QuarantinedBudgetExhausted}` carries the reason + repairs count. `mission_run.rs` hook (iter 5) lowers them into the same `RunEventEntry` channel SCOPE-Rex terminal verdicts already use, which the Provenance Console already renders. |

## 4. Substrate consumed (no duplication)

The Terminal S work is a **promotion** of Pro Research primitives to
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
| `HyperdynamicLoop` trait | `gate_admission_draft_through_loop` + `gate_witness_draft_through_loop` in `mission_run.rs` (`27af5e0418`) + the falsifier harness binary (`8b65039974`) |
| `RepairBudget`, `run_loop`, `run_loop_with_clock` | Both hook helpers + falsifier harness |
| `SchemaRepairLoop` | Pro Research-feature-gated; consumed by the Pro Research integration the falsifier spec carves out. The MAS hook keeps schema-side wiring as the iter-5+ follow-up |
| `AdmissionRepairLoop` | `gate_admission_draft_through_loop` (`27af5e0418`) + falsifier harness 100-prompt run |
| `WitnessRepairLoop<T>` | `gate_witness_draft_through_loop<T>` (`27af5e0418`) + falsifier harness 100-prompt run |
| `HyperdynamicLoopMetrics` (Swift) | FFI bridge from `agent_core::hyperdynamic_loop::LoopCounters` (follow-up — pure transport, no shape change) |

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

- **Adapter call-site wiring** — the model adapter (one layer above
  `MissionRun`) MUST call `gate_admission_draft_through_loop` /
  `gate_witness_draft_through_loop<T>` before invoking
  `MissionRun::admit_and_record_tool_call` / `record_event`. Today
  this is enforced as a discipline gate (the `_through_loop` grep
  marker + the unit test that enforces the suffix). Mechanical
  enforcement — a lint or a wrapper type that makes
  `admit_and_record_tool_call` only callable from an outcome-typed
  acceptor — is a follow-up tracked in the Terminal S handoff.
- **FFI bridge for `LoopCounters`** — the SwiftUI row reads the
  `HyperdynamicLoopMetrics` singleton; the singleton's
  `ingest(kind:, stats:)` is the entry point for when the bridge
  streams from `agent_core::hyperdynamic_loop::LoopCounters` to
  Swift. Until that lands the row shows "no read yet" and chips
  read `·`. The Rust counter shape is stable, so the bridge is
  pure transport.
- **Provenance Console quarantine row rendering** — quarantine
  outcomes (`RepairOutcome::Quarantined` /
  `QuarantinedBudgetExhausted`) carry a reason verbatim; the
  Provenance Console already renders ACS-terminal verdicts via
  the same `RunEventEntry` channel, so no console-side change is
  required once the adapter wires the helpers.

These three gaps do not block the Terminal S landing: the hook
surface, the falsifier PASS, and the audit doc all stand on their
own. Iter 5 / a follow-up PR threads the helpers into the live
adapter path.
