# NightBrain Scheduler Policy (B2-L2)

**Status:** Doctrine row · **§5.0 partial substrate in main**. Rust skeleton at `agent_core/src/nightbrain/` IS in main: `mod.rs` (247 LOC — `NightBrainScheduler` + `NightBrainTask` trait + `CancellationToken` + `HostActivitySnapshot` + `should_admit()` thermal+power+idle composition + `register_task()` + `run_registered_tasks()` + `default_worker_pool_size()` + `canonical_task_names()` 10 names) and `live.rs` (702 LOC — `LIVE_SCHEDULER` OnceLock + `register_canonical_tasks()` + `ObservationTask` generic with 4 wired lanes + `NoOpTask` placeholders for 6 bodies still pending). Swift `NightBrainRun` + `NightBrainCheckpoint` Codable mirrors are in main (`Epistemos/State/CognitiveSubstrateTypes.swift:34, 43`); PowerGate references the 3-AM LaunchAgent cron (`Epistemos/State/PowerGate.swift:12`). **What this doctrine freezes:** the 4 missing eligibility-matrix conditions (flagged-notes, 1-5 AM window, 12h cooldown, no-active-agent) + per-30-min admit cadence + checkpoint format + 6 pending task bodies + morning-report composition — all currently NOT in `should_admit()`, all required before the scheduler ships end-to-end.

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

**Current Rust state** (verified against `agent_core/src/nightbrain/mod.rs:185-190` in main, 2026-05-16):

```rust
pub fn should_admit(&self, snapshot: HostActivitySnapshot) -> bool {
    snapshot.thermal_nominal
        && snapshot.on_ac_or_battery_above_50
        && snapshot.idle_for >= self.idle_threshold
        && !self.token.is_cancelled()
}
```

The 3-of-7 conditions wired in `should_admit()` today are: thermal + power + idle threshold (+ cancel-token sanity check). The 4 missing conditions per Plan §7.1 — **flagged-notes** + **time-window** + **12h cooldown** + **no-active-agent** — are not yet in the Rust composition. They land per this doctrine when the eligibility surface widens (proposed `agent_core/src/nightbrain/eligibility.rs` module split per §9 below).

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

Existing in main per `agent_core/src/nightbrain/mod.rs:11-22` (`CANONICAL_TASK_NAMES`) + `agent_core/src/nightbrain/live.rs` (registration surface):

| Task name | Purpose | Status |
|---|---|---|
| `maintenance_log` | Pure NightBrain self-audit; one row per admit | **LIVE** (`ObservationTask` lane, live.rs:80) |
| `search_index_passive_checkpoint` | Host owns Tantivy commit; this records the join key | **LIVE** (`ObservationTask` lane, live.rs:81) |
| `event_store_checkpoint_vacuum` | Host owns event-store vacuum; this records the join key | **LIVE** (`ObservationTask` lane) |
| `workspace_snapshot_compaction` | Host owns workspace state; this records the join key | **LIVE** (`ObservationTask` lane) |
| `dedupe_artifacts` | Per B.9 — collapse duplicate artifact rows | **NoOpTask placeholder** in main (real body NOT-STARTED) |
| `memory_distillation` | Per B.9 — compact session-trace KV | **NoOpTask placeholder** (NOT-STARTED) |
| `cloud_knowledge_distillation` | Per B.9 — pull morning cloud-research wins | **NoOpTask placeholder** (NOT-STARTED · Pro tier) |
| `session_graph_generation` | Per B.9 — emit DAG-snapshot per session | **NoOpTask placeholder** (NOT-STARTED) |
| `skill_evolution_analysis` | Per B.9 — score newly-emitted skills | **NoOpTask placeholder** (NOT-STARTED) |
| `ssm_state_pruning` | Per B.9 — prune Mamba hidden-state cache | **NoOpTask placeholder** (NOT-STARTED) |
| `nano_continual_step` | LoRA delta application from auto-research wins | NOT-IN-CANONICAL-LIST yet (post-V1.x) |
| `heal_event_retention` | Lazy TTL eviction on heal_events.sqlite per B2-L1 | DOCTRINE-FROZEN (B2-L1 row, body NOT-STARTED — will be wired as 11th canonical name) |
| `shadow_index_refresh` | Re-index Halo Shadow Tantivy/usearch | LANDED via host-side scheduler — NOT in NightBrain canonical list |

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

**Already in main:**

```
agent_core/src/nightbrain/
├── mod.rs    (247 LOC) — NightBrainScheduler + NightBrainTask trait + TaskCtx + TaskOutcome
│                       + CancellationToken + HostActivitySnapshot + should_admit (3-of-7 conds)
│                       + register_task + run_registered_tasks + default_worker_pool_size
│                       + CANONICAL_TASK_NAMES (10 names)
└── live.rs   (702 LOC) — LIVE_SCHEDULER OnceLock singleton + register_canonical_tasks
                        + ObservationTask generic (4 wired lanes) + NoOpTask (6 pending bodies)
                        + ObservationLogEntry + per-lane ring buffers (cap=256)

Swift side (already in main):
Epistemos/State/CognitiveSubstrateTypes.swift  — NightBrainRun + NightBrainCheckpoint Codable mirrors
Epistemos/State/PowerGate.swift                — LaunchAgent 3-AM cron + battery-50% defer
```

**Pending module split (V1.x):**

```
agent_core/src/nightbrain/
├── mod.rs                — (existing — re-exports below)
├── live.rs               — (existing — observation lanes; NoOpTask placeholders replaced)
├── eligibility.rs        — NEW: widen should_admit to all 7 conditions
│                          (add flagged-work + 1-5 AM window + 12h cooldown + no-active-agent)
├── checkpoint.rs         — NEW: JSON read/write for <task>.checkpoint.json
├── morning_report.rs     — NEW: TaskOutcome aggregation → user-facing summary + DP gate
└── tasks/                — NEW: real body impls replacing NoOpTask placeholders
    ├── dedupe_artifacts.rs
    ├── memory_distillation.rs
    ├── cloud_knowledge_distillation.rs        (Pro tier)
    ├── session_graph_generation.rs
    ├── skill_evolution_analysis.rs
    └── ssm_state_pruning.rs

Swift side (pending):
Epistemos/State/NightBrainService.swift        — host wiring (idle monitor + flagged-notes probe
                                                + time-window + 12h cooldown + no-active-agent)
```

**FFI surface delta (when the eligibility widening lands):**

```rust
// Bridge entry points exposed via UniFFI:
pub fn nightbrain_should_admit(snapshot: HostActivitySnapshotFFI) -> bool;
// HostActivitySnapshotFFI WIDENS: idle_for + thermal + power + flagged_work + in_window
//                                  + cooldown_ok + active_agent_count
pub fn nightbrain_preempt();
pub fn nightbrain_run_task(name: &str) -> NightBrainRunOutcome;  // synchronous wrapper around Tokio
pub fn nightbrain_morning_report() -> MorningReportFFI;          // post-window aggregated outcome
```

The current FFI surface (per `agent_core/src/bridge.rs`) already exposes `canonical_task_names()` + `nightbrain_preview_admission(...)`. The widening above is additive — existing call sites keep working until they migrate to the wider snapshot.

---

## 10. V1 / Pro / Post-V1 boundary

- **V1 MAS (today):** Rust skeleton + 4 observation lanes + 6 NoOp placeholders + 3-of-7 eligibility conditions + Swift `NightBrainRun` + `NightBrainCheckpoint` Codable mirrors + PowerGate 3-AM LaunchAgent reference are all in main. **Diagnostic-only**: registered tasks emit ObservationLogEntry rows but no real maintenance executes.
- **V1.x:** Eligibility widening lands (`eligibility.rs` module split adds the missing 4 conditions); first real task body replaces a NoOpTask (proposed: `dedupe_artifacts` since it touches the most foundational invariant); cross-language morning report flows end-to-end.
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
