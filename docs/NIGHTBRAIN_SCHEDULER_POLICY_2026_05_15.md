# NightBrain Scheduler Policy (B2-L2)

**Status:** Doctrine row (forward-staging Rust scheduler · partial main substrate). Swift `NightBrainRun` + `NightBrainCheckpoint` types are in main (`Epistemos/State/CognitiveSubstrateTypes.swift:34, 43`); PowerGate already references "NightBrain LaunchAgent (3 AM cron — defer if battery < 50%)" (`Epistemos/State/PowerGate.swift:12`). The Rust scheduler at `agent_core/src/nightbrain/` is **NOT-STARTED** in main; this doc freezes the policy + trait + eligibility matrix so when it ships it doesn't redrift.

**Source:** `docs/fusion/salvage/from-vigorous-goldberg/agent_core_src/nightbrain/mod.rs` (334 LOC; Plan §7.1 verbatim shape) + PASS 2 audit row B2-L2 + `MASTER_FUSION §3.35 Golden-ratio scheduling` (landed iter 19, KAM-stable cadence) + B.9 NightBrain task bodies row in `MAS_COMPLETE_FUSION §B` (6 task bodies pending).

**Sibling doctrine docs:** `agent_core/docs/HEAL_LOOP_SCHEMA_AND_TTL.md` (B2-L1; eviction-lazy-on-append uses NightBrain instead of a dedicated cron) · `MASTER_FUSION §3.35` golden-ratio scheduling.

---

## 1. Architectural premise

NightBrain is the idle-time maintenance scheduler. Per FINAL_SYNTHESIS §2 layer 7 (Metabolism): "Auto-research observes the log, runs variants overnight, keeps wins, tombstones losses, surfaces morning report. Outputs improved baselines for Layers 2-4 next day."

The scheduler is the **gate** that decides when maintenance work can run without intruding on the user's interactive session. The tasks themselves are the WORK; the scheduler is the WHEN.

---

## 2. Eligibility matrix (the audit-row literals)

Per PASS 2 B2-L2 row's verbatim eligibility list:

| Condition | Required state |
|---|---|
| **Flagged notes available** | At least one note in the vault is in a state that maintenance can act on (low-confidence capture pending re-route · dedupe candidate · stale embedding · unsynced shadow row). |
| **Power source** | Plugged in (AC) OR battery > 50%. |
| **Active agent** | NO agent currently running (per `agent_core::session::GlobalSessions::active_count() == 0`). |
| **Local time window** | 1:00 AM ≤ now ≤ 5:00 AM (host local timezone). |
| **Cooldown** | ≥ 12h since last successful NightBrain admit cycle (per `<vault>/.epcache/nightbrain/last_admit.json`). |
| **Thermal** | `ProcessInfo.thermalState == .nominal` — never admit under thermal pressure. |
| **Idle threshold** | System idle ≥ 60s per `IdleMonitor.is_idle_for(Duration::from_secs(60))`. |

**Composition rule:** ALL conditions must hold. The Plan §7.1 admit gate is:

```
admit ⇔ flagged_work ∧ (on_ac ∨ battery > 50%)
       ∧ no_agent ∧ in_window ∧ cooldown_ok
       ∧ thermal_nominal ∧ idle ≥ 60s
       ∧ ¬cancellation_token.is_cancelled()
```

Per salvage `nightbrain/mod.rs:181-186`, the host caller passes `thermal_nominal` + `on_ac_or_battery_above_50` directly; the module owns the idle-time + cancellation pieces. The 1-5 AM window + 12h cooldown + flagged-work check are HOST-side gates (Swift wires them via `NightBrainService`).

---

## 3. Per-30-min eval cadence

Per PASS 2 B2-L2 row: "Per-30-min eval." The scheduler does NOT run continuously — it wakes every 30 minutes during the 1-5 AM window, runs the eligibility gate, and either admits one task or sleeps until the next half-hour mark.

**Why 30 minutes:**
- Longer than 15 min: avoids ping-pong with very brief user interactions (typing a single note before going back to sleep).
- Shorter than 60 min: lets the scheduler catch the user's actual idle state inside the 4-hour overnight window (1-5 AM = 8 half-hour slots).
- Aligns with `DispatchSourceTimer` resolution + macOS Energy Impact accounting cycle.

**Composition with §3.35 golden-ratio scheduling:** the φ-spaced scheduling in MASTER_FUSION §3.35 is about TASK ORDERING within a NightBrain admit cycle (`t_n = base_interval · φ^n`); the per-30-min eval is the ADMIT cadence (when the scheduler wakes to consider admitting). They are orthogonal:

- **30-min eval** = how often the gate checks eligibility.
- **φ-spaced ordering** = if the gate admits, which task runs first / second / third within the admit window.

---

## 4. The `NightBrainTask` trait (canonical contract)

Verbatim from salvage `nightbrain/mod.rs:98-116`:

```rust
#[async_trait]
pub trait NightBrainTask: Send + Sync {
    /// Stable name for telemetry / checkpoint files (`<name>.checkpoint.json`).
    fn name(&self) -> &str;

    /// One admit cycle. Tasks should:
    /// 1. Resume from checkpoint if present.
    /// 2. Process work in batches of `ctx.batch_size`.
    /// 3. Check `ctx.is_cancelled()` between batches.
    /// 4. Persist a checkpoint after each batch unit.
    /// 5. Return Ok when the unit's slice is complete (or Cancelled
    ///    if preempted). Persistent state lives in the checkpoint;
    ///    the next admit cycle picks up where this one left off.
    async fn run(&self, ctx: &TaskCtx) -> Result<TaskOutcome, NightBrainError>;
}
```

**Five-step task discipline** (Plan §7.1):

1. **Resume from checkpoint if present.** Tasks are stateful across admit cycles via `<vault>/.epcache/nightbrain/<name>.checkpoint.json`.
2. **Batch size = 32 items typically** per `TaskCtx::new` default (`ctx.batch_size = 32`).
3. **Cancellation check between batches.** `ctx.is_cancelled()` returns true the moment user input fires the preempt; the task MUST stop within the next batch boundary.
4. **Persist a checkpoint after each batch.** No silent loss — even a sudden cancellation keeps the most recent batch's work durable.
5. **Return `TaskOutcome::complete(items)` OR `TaskOutcome::preempted(items_so_far)`** so the morning report can compose `completed: bool` correctly.

---

## 5. Worker pool sizing + preemption

**Pool size formula** (per salvage `nightbrain/mod.rs:33-38`):

```rust
pub const DEFAULT_IDLE_THRESHOLD: Duration = Duration::from_secs(60);

pub fn default_worker_pool_size() -> usize {
    let cores = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4);
    (cores.saturating_sub(2)).clamp(1, 4)
}
```

**Capped at `min(4, available_cores − 2)`.** On the V1 ship rig (M2 Pro 16 GB = 10 cores = 6P + 4E), pool size = `min(4, 8) = 4`. The `-2` reserves 2 cores for the OS + foreground UI even if the user wakes mid-cycle. The `min(4, ...)` cap prevents thrash on higher-core machines.

**Preemption is synchronous + total.** Per salvage `nightbrain/mod.rs:188-192`:

```rust
/// Plan §7.1: "any user input triggers cancel_all on NightBrain."
/// Call this from idle_monitor::mark_user_input() callbacks.
pub fn preempt(&self) {
    self.token.cancel();
}
```

Any user keystroke / mouse move / touchpad event must call `preempt()` BEFORE the input is forwarded to the foreground app. The cancellation token fans the cancel out to every in-flight task; each task's next `ctx.is_cancelled()` check stops it within its batch boundary.

---

## 6. Per-task gates (canonical 10 + UndoEviction)

Existing in main (Swift-side per `Epistemos/State/CognitiveSubstrateTypes.swift` + earlier loop iters):

| Task name | Purpose | Status |
|---|---|---|
| `observation_compaction` | Compact `ObservationTask` ring buffer | LANDED |
| `heal_event_retention` | Lazy TTL eviction on heal_events.sqlite per B2-L1 | LANDED (post-B2-L1) |
| `shadow_index_refresh` | Re-index Halo Shadow Tantivy/usearch | LANDED |
| `nano_continual_step` | LoRA delta application from auto-research wins | NOT-STARTED |
| **`dedupe_artifacts`** | Per B.9 — collapse duplicate artifact rows | NOT-STARTED |
| **`memory_distillation`** | Per B.9 — compact session-trace KV | NOT-STARTED |
| **`cloud_knowledge_distillation`** | Per B.9 — pull morning cloud-research wins | NOT-STARTED |
| **`session_graph_generation`** | Per B.9 — emit DAG-snapshot per session | NOT-STARTED |
| **`skill_evolution_analysis`** | Per B.9 — score newly-emitted skills | NOT-STARTED |
| **`ssm_state_pruning`** | Per B.9 — prune Mamba hidden-state cache | NOT-STARTED |

**UndoEvictionTask (B2-L2 specific):** the audit row's "UndoEvictionTask wiring" sibling — when a vault Undo expiry hits its TTL, the Undo row + paired Effect Inverse (per Hermes 2.0 §5.4 `Inverse::*`) are evicted from `<vault>/.epcache/undo/`. Runs per-night with `DEFAULT_BATCH_SIZE = 32` Undos per batch.

**Per-task admit cadence** (post-eligibility-gate; this is the φ-spaced ordering per §3.35):

```
t_0 = 0           // first task (observation_compaction — quickest)
t_1 = 1 * φ^1     // ≈ 1.618 min
t_2 = 1 * φ^2     // ≈ 2.618 min
...
```

Slower tasks land later in the admit window so they don't crowd out the quick maintenance work if the user wakes early.

---

## 7. Checkpoint format

Each task writes `<vault>/.epcache/nightbrain/<task_name>.checkpoint.json`:

```json
{
  "task_name": "dedupe_artifacts",
  "started_at": "2026-05-16T01:30:00Z",
  "last_checkpoint_at": "2026-05-16T01:32:14Z",
  "items_processed": 96,
  "items_skipped": 4,
  "next_offset": "ulid-01HXY...",
  "completed": false,
  "schema_version": 1
}
```

The Swift `NightBrainCheckpoint` type at `Epistemos/State/CognitiveSubstrateTypes.swift:43` mirrors this exactly for cross-language parity. **schema_version = 1** is frozen; bumping requires a doctrine-row update + migration plan.

---

## 8. Morning report composition (NightBrain → user)

The morning report is the user-visible artifact. After the admit window closes (≥ 5 AM OR preempt), the scheduler composes a summary:

```
NightBrain summary — 2026-05-16 01:30 → 05:00

✓ observation_compaction       128 items     0.4 s
✓ heal_event_retention          12 evictions 0.1 s
✓ shadow_index_refresh        4316 docs      72 s
~ dedupe_artifacts              96 items    PREEMPTED at 01:32 (user wake)
- nano_continual_step           skipped — no auto-research wins available
- cloud_knowledge_distillation skipped — Pro entitlement absent

Wins applied: 0
Wins not applied: 0
Discoveries to investigate: 0
```

**Privacy gate (B2-M14 cross-link):** aggregate counts in the morning report MUST go through `dp_aggregate(_, ε ≤ 0.5)` per MASTER_FUSION §3.42 differential-privacy gate before the prose summary line is emitted to any LLM context surface.

---

## 9. Forward-staged module layout

When the Rust substrate lands in main:

```
agent_core/src/nightbrain/
├── mod.rs                 — NightBrainScheduler + NightBrainTask trait + TaskCtx + TaskOutcome
├── eligibility.rs         — should_admit logic + flagged-work / time-window / cooldown gates
├── checkpoint.rs          — JSON read/write for <task>.checkpoint.json
├── morning_report.rs      — TaskOutcome aggregation → user-facing summary
└── tasks/                 — individual NightBrainTask impls (one file per task name)

Swift side (already in main):
Epistemos/State/CognitiveSubstrateTypes.swift  — NightBrainRun + NightBrainCheckpoint Codable mirrors
Epistemos/State/NightBrainService.swift        — host wiring (idle monitor + thermal/battery probes)
Epistemos/State/PowerGate.swift                — LaunchAgent 3-AM cron + battery-50% defer
```

**FFI surface** (when the Rust side lands):

```rust
// Bridge entry points exposed via UniFFI:
pub fn nightbrain_should_admit(thermal_nominal: bool, on_ac_or_battery_above_50: bool) -> bool;
pub fn nightbrain_preempt();
pub fn nightbrain_run_task(name: &str) -> NightBrainRunOutcome;  // synchronous wrapper around Tokio
```

---

## 10. V1 / Pro / Post-V1 boundary

- **V1 MAS:** Swift `NightBrainRun` + `NightBrainCheckpoint` types ship + the existing PowerGate 3-AM LaunchAgent reference. Rust scheduler substrate (`agent_core/src/nightbrain/`) lands V1.x or later.
- **V1.x:** Rust `NightBrainScheduler` + `NightBrainTask` trait lands; first task body wired (`observation_compaction` — already partially canonical) so the cross-language surface flows end-to-end.
- **B.9 task bodies** (6 pending: dedupe_artifacts · memory_distillation · cloud_knowledge_distillation · session_graph_generation · skill_evolution_analysis · ssm_state_pruning) land one-per-slice as separate doctrine-then-code passes; each consumes this scheduler.
- **Pro V1.x:** `cloud_knowledge_distillation` activates (requires Pro entitlement); `nano_continual_step` activates (Pro tier nano LoRA training).
- **Wave 9+:** auto-research per-fetch consumption of B2-H20 ephemeral tokens (Hermes 2.0 §5.2) + B2-M14 differential-privacy gate on morning report aggregates.

---

## 11. Cross-references

- B2-L2 PASS 2 audit row.
- `docs/fusion/salvage/from-vigorous-goldberg/agent_core_src/nightbrain/mod.rs` (334 LOC) — canonical Rust source.
- `~/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md §2 layer 7 (Metabolism)` — auto-research overnight cadence.
- B2-L1 `agent_core/docs/HEAL_LOOP_SCHEMA_AND_TTL.md` — sibling Phase I LOW-tier row; B2-L1's lazy TTL eviction uses this scheduler's admit cadence.
- `MASTER_FUSION §3.35 Golden-ratio scheduling` (landed iter 19) — φ-spaced task ordering WITHIN a NightBrain admit window; orthogonal to this 30-min eval cadence.
- `MAS_COMPLETE_FUSION §B.9` — 6 task bodies pending (`dedupe_artifacts` · `memory_distillation` · `cloud_knowledge_distillation` · `session_graph_generation` · `skill_evolution_analysis` · `ssm_state_pruning`); each consumes this scheduler.
- `MASTER_FUSION §3.42 Differential Privacy (B2-M14)` — morning report aggregate gate.
- `HERMES_AGENT_CORE_2_0_DESIGN §5.2 Ephemeral capability tokens (B2-H20)` — per-fetch authorization for auto-research consumer tasks.
- `HERMES_AGENT_CORE_2_0_DESIGN §5.4 Intent → Effect Applier subsystem (B2-M10)` — `Inverse::*` Undo backbone consumed by UndoEvictionTask.
- `Epistemos/State/CognitiveSubstrateTypes.swift:34, 43` — Swift `NightBrainRun` + `NightBrainCheckpoint` types (already in main).
- `Epistemos/State/PowerGate.swift:12` — 3-AM LaunchAgent cron + battery-50% defer reference.
- Plan §7.1 (the canonical NightBrain scheduler spec).
- Plan §6.9 (WAL crash-safety — checkpoint files inherit).

---

*— B2-L2 doctrine row. Eligibility matrix + 30-min admit cadence + `NightBrainTask` trait + worker pool sizing + checkpoint format frozen. Rust substrate `agent_core/src/nightbrain/` lands when prioritized. The 6 B.9 task bodies are separate slices that consume this scheduler.*
