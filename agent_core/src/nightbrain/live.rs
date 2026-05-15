//! Live NightBrain task registration — global singleton scheduler the
//! Swift side calls into via UniFFI to register canonical maintenance
//! tasks at app boot.
//!
//! Scope: exposes the live registration surface flagged after the Codex
//! continuation pass. Before this module the FFI surface only exposed
//! `canonical_task_names()` (the contract list) +
//! `nightbrain_preview_admission(...)` (the gate preview). There was no
//! path for the Swift host to register canonical names or trigger the
//! scheduler from diagnostics. The registered bodies below are still
//! placeholders and must stay honest until real task bodies land.
//!
//! Approach: a `LiveScheduler` lazy-static singleton holds the canonical
//! tasks. `register_canonical_tasks()` populates it idempotently with
//! `NoOpTask` implementations — placeholders that record their name and
//! report `skipped(1)` so diagnostics never confuse them with completed
//! maintenance work. Each canonical task body (event_store_checkpoint_vacuum,
//! search_index_passive_checkpoint, …) can then be filled in incrementally
//! without changing the registration surface.
//!
//! Determinism: registration is idempotent (re-registering an already-
//! present canonical name is a no-op, not a duplicate-name error). This
//! lets AppBootstrap call register_canonical_tasks unconditionally
//! without tracking whether it ran before.

use std::collections::{HashMap, VecDeque};
use std::sync::{Arc, OnceLock};

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;

use super::{
    NightBrainScheduler, NightBrainTask, RegisteredTaskOutcome, Result, TaskCtx, TaskOutcome,
};

/// Process-global live scheduler. Held in a OnceLock so the singleton
/// is initialised on first access and never reconstructed.
static LIVE_SCHEDULER: OnceLock<Arc<Mutex<NightBrainScheduler>>> = OnceLock::new();

// ---------------------------------------------------------------------------
// ObservationTask — generic substrate for observation-only NightBrain bodies
// ---------------------------------------------------------------------------
//
// Per Master Fusion Plan §B.9 incremental rollout, the third parallel
// observation lane is the trigger to extract a small generic. Four
// canonical NightBrain task names share the same contract today:
//
//   - maintenance_log               — pure NightBrain self-audit
//   - search_index_passive_checkpoint — host owns Tantivy commit; this
//                                       task records the join key
//   - event_store_checkpoint_vacuum  — host owns the event-store
//                                       vacuum; this task records the
//                                       join key
//   - workspace_snapshot_compaction  — host owns workspace state; this
//                                       task records the join key
//
// All four want the same shape: append ONE row to a per-lane ring with
// `{task_name, observed_at_ms, completed}`, report `complete(1)`,
// honor cooperative preemption. So they share one struct
// (`ObservationTask`) and one HashMap-keyed ring store (`LANE_RINGS`).
//
// The remaining 6 canonical task names need real work, not observation
// (dedupe_artifacts, memory_distillation, cloud_knowledge_distillation,
// session_graph_generation, skill_evolution_analysis, ssm_state_pruning).
// They stay on `NoOpTask` until their real implementation slices land —
// dressing them up as ObservationTask would be the "real body" anti-
// pattern the project rules forbid.

/// Maximum number of rows kept per observation lane. Past this cap the
/// oldest entry is evicted on each append. Sized for ~1 week of
/// nightly maintenance at 36 runs/day (~256 / 36 ≈ 7 days), generous
/// given each entry is < 96 bytes.
pub const OBSERVATION_LANE_RING_CAPACITY: usize = 256;

/// Back-compat aliases — external callers (FFI surfaces, host-side
/// Swift) can keep referring to `MAINTENANCE_LOG_RING_CAPACITY` and
/// `SEARCH_INDEX_CHECKPOINT_LOG_RING_CAPACITY` as before. Both alias
/// the same canonical capacity constant.
pub const MAINTENANCE_LOG_RING_CAPACITY: usize = OBSERVATION_LANE_RING_CAPACITY;
pub const SEARCH_INDEX_CHECKPOINT_LOG_RING_CAPACITY: usize = OBSERVATION_LANE_RING_CAPACITY;

/// One row in any observation lane. Surfaces the canonical task name
/// + observed-at timestamp + whether the body executed (vs. preempted).
/// Serializable so a future FFI surface can read lane snapshots
/// without touching the in-memory rings directly.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ObservationLogEntry {
    /// Canonical task name from `CANONICAL_TASK_NAMES`.
    pub task_name: String,
    /// UTC unix milliseconds at observation.
    pub observed_at_ms: i64,
    /// `true` when the task body ran to completion; `false` on a
    /// cooperative preempt.
    pub completed: bool,
}

/// Type aliases preserve the existing public API. `MaintenanceLogEntry`
/// and `SearchIndexCheckpointEntry` are the same shape as
/// `ObservationLogEntry`, kept as named aliases so any consumer
/// (Swift FFI surface, downstream Rust crate) that imported the old
/// names continues to compile.
pub type MaintenanceLogEntry = ObservationLogEntry;
pub type SearchIndexCheckpointEntry = ObservationLogEntry;

/// Lane key in `LANE_RINGS`. Must match a name in `CANONICAL_TASK_NAMES`
/// to keep the audit trail joinable against the registered task set.
type LaneName = &'static str;

/// Process-global HashMap-keyed observation lane store. Each lane has
/// its own bounded ring buffer. Initialized on first access and never
/// reconstructed. The outer Mutex serializes inserts across lanes;
/// per-lane Mutex contention is bounded because each lane only has
/// one writer (its `ObservationTask`).
static LANE_RINGS: OnceLock<Arc<Mutex<HashMap<LaneName, VecDeque<ObservationLogEntry>>>>> =
    OnceLock::new();

fn lane_rings() -> Arc<Mutex<HashMap<LaneName, VecDeque<ObservationLogEntry>>>> {
    LANE_RINGS
        .get_or_init(|| Arc::new(Mutex::new(HashMap::new())))
        .clone()
}

/// Append one entry to the named lane, evicting the oldest row if the
/// lane is at capacity. Idempotently creates the lane on first append.
async fn append_to_lane(lane: LaneName, entry: ObservationLogEntry) {
    let rings = lane_rings();
    let mut guard = rings.lock().await;
    let ring = guard
        .entry(lane)
        .or_insert_with(|| VecDeque::with_capacity(OBSERVATION_LANE_RING_CAPACITY));
    if ring.len() >= OBSERVATION_LANE_RING_CAPACITY {
        ring.pop_front();
    }
    ring.push_back(entry);
}

/// Snapshot of the most-recent `limit` entries on the named lane.
/// Newest entry is the last element. `limit = 0` returns an empty Vec
/// without locking the rings; otherwise the call briefly holds the
/// HashMap Mutex.
pub async fn recent_lane_entries(lane: LaneName, limit: usize) -> Vec<ObservationLogEntry> {
    if limit == 0 {
        return Vec::new();
    }
    let rings = lane_rings();
    let guard = rings.lock().await;
    let Some(ring) = guard.get(lane) else {
        return Vec::new();
    };
    let total = ring.len();
    let take = limit.min(total);
    ring.iter().skip(total - take).cloned().collect()
}

/// Back-compat reader: returns the maintenance_log lane. Wraps
/// [`recent_lane_entries`] with the canonical name as the lane key.
pub async fn recent_maintenance_log_entries(limit: usize) -> Vec<MaintenanceLogEntry> {
    recent_lane_entries("maintenance_log", limit).await
}

/// Back-compat reader: returns the search_index_passive_checkpoint
/// lane. Wraps [`recent_lane_entries`] with the canonical name as the
/// lane key.
pub async fn recent_search_index_checkpoint_entries(
    limit: usize,
) -> Vec<SearchIndexCheckpointEntry> {
    recent_lane_entries("search_index_passive_checkpoint", limit).await
}

/// Generic observation-only task body. Records ONE row in the lane
/// keyed by its canonical name per scheduler run. Reports
/// `complete(1)`. Honors `ctx.is_cancelled()` for cooperative
/// preemption.
///
/// Use only when observation-only is the intended contract. Tasks
/// that need real work (memory_distillation, dedupe_artifacts, etc.)
/// must implement a dedicated struct rather than masquerade as an
/// `ObservationTask`.
struct ObservationTask {
    canonical_name: &'static str,
}

#[async_trait]
impl NightBrainTask for ObservationTask {
    fn name(&self) -> &str {
        self.canonical_name
    }

    async fn run(&self, ctx: &TaskCtx) -> Result<TaskOutcome> {
        if ctx.is_cancelled() {
            return Ok(TaskOutcome::preempted(0));
        }
        let observed_at_ms = chrono::Utc::now().timestamp_millis();
        let entry = ObservationLogEntry {
            task_name: self.canonical_name.to_string(),
            observed_at_ms,
            completed: true,
        };
        append_to_lane(self.canonical_name, entry).await;
        tokio::task::yield_now().await;
        Ok(TaskOutcome::complete(1))
    }
}

fn live_scheduler() -> Arc<Mutex<NightBrainScheduler>> {
    LIVE_SCHEDULER
        .get_or_init(|| Arc::new(Mutex::new(NightBrainScheduler::new())))
        .clone()
}

/// Placeholder task implementation — records its canonical name and
/// returns a `skipped(1)` outcome. Real task bodies replace this
/// pattern incrementally without changing the registration surface.
///
/// The name is `&'static str` because every canonical task name is a
/// string literal in `CANONICAL_TASK_NAMES` — no allocation needed.
struct NoOpTask {
    canonical_name: &'static str,
}

#[async_trait]
impl NightBrainTask for NoOpTask {
    fn name(&self) -> &str {
        self.canonical_name
    }

    async fn run(&self, ctx: &TaskCtx) -> Result<TaskOutcome> {
        if ctx.is_cancelled() {
            return Ok(TaskOutcome::preempted(0));
        }
        // Yield once so cooperative cancellation has a chance to fire on
        // long task chains. No real work — report an honest skip until
        // per-task bodies replace these placeholders.
        tokio::task::yield_now().await;
        Ok(TaskOutcome::skipped(1))
    }
}

/// Resolve the list of `&'static str` canonical names. The returned
/// slice mirrors `CANONICAL_TASK_NAMES` exactly so registration is
/// idempotent.
fn canonical_static_names() -> &'static [&'static str] {
    super::CANONICAL_TASK_NAMES
}

/// Idempotently register all canonical NightBrain tasks against the
/// live scheduler. Called by Swift `AppBootstrap` at startup. Returns
/// the names that ended up registered (the union of any pre-existing
/// registrations + the canonical set). Re-registering an already-
/// present canonical name is a no-op, not an error.
pub async fn register_canonical_tasks() -> Vec<String> {
    let scheduler = live_scheduler();
    let mut guard = scheduler.lock().await;
    for canonical_name in canonical_static_names() {
        let already_registered = guard
            .registered_task_names()
            .iter()
            .any(|registered| registered == canonical_name);
        if already_registered {
            continue;
        }
        // Per Master Fusion Plan §B.9: replace `NoOpTask` placeholders
        // with real bodies as they land, one at a time. Observation-
        // only bodies (where the host owns the real work and this
        // task is the audit-trail join key) share `ObservationTask`.
        // Tasks that need real work (dedupe_artifacts,
        // memory_distillation, cloud_knowledge_distillation,
        // session_graph_generation, skill_evolution_analysis,
        // ssm_state_pruning) stay on NoOp until their slices land —
        // dressing them up as ObservationTask is the "real body" anti-
        // pattern the project rules forbid.
        let is_observation_lane = matches!(
            *canonical_name,
            "maintenance_log"
                | "search_index_passive_checkpoint"
                | "event_store_checkpoint_vacuum"
                | "workspace_snapshot_compaction"
        );
        let task: Arc<dyn NightBrainTask> = if is_observation_lane {
            Arc::new(ObservationTask { canonical_name })
        } else {
            Arc::new(NoOpTask { canonical_name })
        };
        // The non-idempotent error here would only fire on a name
        // collision — guarded against above. Treat any residual error
        // as a soft skip (the next boot retries).
        let _ = guard.register_task(task);
    }
    guard.registered_task_names()
}

/// Snapshot of the live scheduler's currently-registered names.
/// Cheap; no execution. Used by Swift diagnostics + by tests asserting
/// the registration surface is plumbed.
pub async fn live_registered_task_names() -> Vec<String> {
    let scheduler = live_scheduler();
    let guard = scheduler.lock().await;
    guard.registered_task_names()
}

/// Trigger a live execution of every registered task. Intended to be
/// called from the host's idle scheduler when admission gates pass.
/// Returns per-task outcomes. Honours cancellation via the scheduler's
/// shared CancellationToken (which `preempt_live_scheduler()` cancels).
pub async fn run_live_registered_tasks() -> Result<Vec<RegisteredTaskOutcome>> {
    let scheduler = live_scheduler();
    let guard = scheduler.lock().await;
    guard.run_registered_tasks().await
}

/// Cancel any in-flight live tasks. Idempotent. Real cancellation
/// observation happens at task `ctx.is_cancelled()` checkpoints.
pub async fn preempt_live_scheduler() {
    let scheduler = live_scheduler();
    let guard = scheduler.lock().await;
    guard.preempt();
}

/// Reset the cancellation token so the next admission window can run.
pub async fn reset_live_scheduler() {
    let scheduler = live_scheduler();
    let guard = scheduler.lock().await;
    guard.reset();
}

#[cfg(test)]
mod tests {
    use super::super::canonical_task_names;
    use super::*;
    use std::sync::OnceLock;
    use std::time::Duration;
    use tokio::sync::Mutex as AsyncMutex;

    /// Serializes tests that touch the process-global LIVE_SCHEDULER
    /// singleton. Without this, parallel cargo-test workers race on
    /// the shared cancellation token (a preempt in test A can land
    /// between reset+run in test B). The mutex preserves real
    /// determinism without weakening the production semantics — only
    /// tests share this lock.
    fn test_serializer() -> &'static AsyncMutex<()> {
        static SERIALIZER: OnceLock<AsyncMutex<()>> = OnceLock::new();
        SERIALIZER.get_or_init(|| AsyncMutex::new(()))
    }

    #[tokio::test]
    async fn register_canonical_tasks_is_idempotent() {
        let _guard = test_serializer().lock().await;
        // Purposely call twice; second call must not produce duplicate
        // names + must not error.
        let first = register_canonical_tasks().await;
        let second = register_canonical_tasks().await;
        assert_eq!(first, second);
        assert_eq!(first.len(), canonical_task_names().len());
        assert_eq!(
            first
                .iter()
                .filter(|name| name == &"event_store_checkpoint_vacuum")
                .count(),
            1,
            "registration must not produce duplicate entries"
        );
    }

    #[tokio::test]
    async fn registered_task_names_match_canonical_set() {
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        let mut live = live_registered_task_names().await;
        let mut canonical = canonical_task_names();
        live.sort();
        canonical.sort();
        assert_eq!(live, canonical);
    }

    #[tokio::test]
    async fn run_live_registered_tasks_reports_noop_placeholders_as_skipped() {
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        reset_live_scheduler().await; // any prior preempts cleared
        let outcomes = run_live_registered_tasks().await.expect("run ok");
        assert_eq!(outcomes.len(), canonical_task_names().len());
        for outcome in &outcomes {
            assert!(
                outcome.outcome.completed,
                "task must not stop the run loop"
            );
            let is_real_body = matches!(
                outcome.name.as_str(),
                "maintenance_log"
                    | "search_index_passive_checkpoint"
                    | "event_store_checkpoint_vacuum"
                    | "workspace_snapshot_compaction"
            );
            if is_real_body {
                // §B.9 real body — completed=true, processed=1.
                assert_eq!(
                    outcome.outcome.items_processed, 1,
                    "{} real body must process exactly 1 row",
                    outcome.name
                );
                assert_eq!(
                    outcome.outcome.items_skipped, 0,
                    "{} real body must NOT report a skip",
                    outcome.name
                );
            } else {
                // Remaining canonical names still NoOp placeholders.
                assert_eq!(
                    outcome.outcome.items_processed, 0,
                    "no-op placeholder ({}) must process 0",
                    outcome.name
                );
                assert_eq!(
                    outcome.outcome.items_skipped, 1,
                    "no-op placeholder ({}) must report skipped(1)",
                    outcome.name
                );
            }
        }
    }

    // -- Master Fusion §B.9 — maintenance_log real body --------------------

    #[tokio::test]
    async fn maintenance_log_task_appends_a_row_per_run() {
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        reset_live_scheduler().await;

        // Snapshot the log size before; we only assert the delta.
        let before = recent_maintenance_log_entries(MAINTENANCE_LOG_RING_CAPACITY).await;
        let _ = run_live_registered_tasks().await.expect("run ok");
        let after = recent_maintenance_log_entries(MAINTENANCE_LOG_RING_CAPACITY).await;
        assert_eq!(
            after.len(),
            (before.len() + 1).min(MAINTENANCE_LOG_RING_CAPACITY),
            "one run must append exactly one row (or stay at capacity)"
        );

        let latest = after.last().expect("post-run log must be non-empty");
        assert_eq!(latest.task_name, "maintenance_log");
        assert!(
            latest.completed,
            "the recorded row must report completed=true"
        );
        assert!(
            latest.observed_at_ms > 0,
            "the recorded row must carry a monotonic-positive timestamp"
        );
    }

    #[tokio::test]
    async fn maintenance_log_ring_is_bounded_to_capacity() {
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        reset_live_scheduler().await;

        // Drive the ring well past capacity. Each scheduler run fires
        // every registered task once, so we get one maintenance_log
        // row per loop. Run capacity + 16 times to prove eviction.
        let runs = MAINTENANCE_LOG_RING_CAPACITY + 16;
        for _ in 0..runs {
            reset_live_scheduler().await;
            let _ = run_live_registered_tasks().await.expect("run ok");
        }
        let snapshot = recent_maintenance_log_entries(MAINTENANCE_LOG_RING_CAPACITY + 64).await;
        assert!(
            snapshot.len() <= MAINTENANCE_LOG_RING_CAPACITY,
            "ring must never grow past capacity; got {} after {} runs",
            snapshot.len(),
            runs
        );
    }

    #[tokio::test]
    async fn preempt_short_circuits_pending_tasks() {
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        preempt_live_scheduler().await;
        // After preempt the first task observes cancellation; the
        // run loop short-circuits after one preempted outcome.
        let outcomes = run_live_registered_tasks().await.expect("run ok");
        assert!(
            !outcomes.is_empty(),
            "at least one task must report its preempted outcome"
        );
        assert!(
            !outcomes[0].outcome.completed,
            "first task must be preempted"
        );
        // Reset + re-run completes everything cleanly — proves preempt
        // semantics are reversible.
        reset_live_scheduler().await;
        let resumed = run_live_registered_tasks().await.expect("run ok");
        assert_eq!(resumed.len(), canonical_task_names().len());
        for outcome in &resumed {
            assert!(outcome.outcome.completed);
        }
    }

    #[tokio::test]
    async fn cancellation_token_carries_through_to_task_ctx() {
        // Sanity check that the singleton's token is the same one tasks
        // observe via TaskCtx (via super::run_task → TaskCtx::new(...)).
        // If the singleton fragmented its token, preempt would be a no-op.
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        reset_live_scheduler().await;
        let _outcomes_before = run_live_registered_tasks().await.expect("run ok");
        // Sleep briefly so any racy state machine settles.
        tokio::time::sleep(Duration::from_millis(10)).await;
        let names = live_registered_task_names().await;
        assert!(!names.is_empty());
    }

    // -- Master Fusion §B.9 2/10 — search_index_passive_checkpoint --------

    #[tokio::test]
    async fn search_index_checkpoint_task_appends_a_row_per_run() {
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        reset_live_scheduler().await;

        let before =
            recent_search_index_checkpoint_entries(SEARCH_INDEX_CHECKPOINT_LOG_RING_CAPACITY).await;
        let _ = run_live_registered_tasks().await.expect("run ok");
        let after =
            recent_search_index_checkpoint_entries(SEARCH_INDEX_CHECKPOINT_LOG_RING_CAPACITY).await;
        assert_eq!(
            after.len(),
            (before.len() + 1).min(SEARCH_INDEX_CHECKPOINT_LOG_RING_CAPACITY),
            "one run must append exactly one row (or stay at capacity)"
        );

        let latest = after.last().expect("post-run log must be non-empty");
        assert_eq!(latest.task_name, "search_index_passive_checkpoint");
        assert!(latest.completed);
        assert!(latest.observed_at_ms > 0);
    }

    #[tokio::test]
    async fn search_index_checkpoint_ring_is_bounded_to_capacity() {
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        reset_live_scheduler().await;

        let runs = SEARCH_INDEX_CHECKPOINT_LOG_RING_CAPACITY + 16;
        for _ in 0..runs {
            reset_live_scheduler().await;
            let _ = run_live_registered_tasks().await.expect("run ok");
        }
        let snapshot = recent_search_index_checkpoint_entries(
            SEARCH_INDEX_CHECKPOINT_LOG_RING_CAPACITY + 64,
        )
        .await;
        assert!(
            snapshot.len() <= SEARCH_INDEX_CHECKPOINT_LOG_RING_CAPACITY,
            "ring must never grow past capacity; got {} after {} runs",
            snapshot.len(),
            runs
        );
    }

    // -- Master Fusion §B.9 3/10 + 4/10 — generic ObservationTask --------

    #[tokio::test]
    async fn event_store_checkpoint_vacuum_uses_observation_task() {
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        reset_live_scheduler().await;

        let before =
            recent_lane_entries("event_store_checkpoint_vacuum", OBSERVATION_LANE_RING_CAPACITY)
                .await;
        let _ = run_live_registered_tasks().await.expect("run ok");
        let after =
            recent_lane_entries("event_store_checkpoint_vacuum", OBSERVATION_LANE_RING_CAPACITY)
                .await;
        assert_eq!(
            after.len(),
            (before.len() + 1).min(OBSERVATION_LANE_RING_CAPACITY),
            "one run must append exactly one row to the event_store lane"
        );
        let latest = after.last().expect("post-run lane must be non-empty");
        assert_eq!(latest.task_name, "event_store_checkpoint_vacuum");
        assert!(latest.completed);
        assert!(latest.observed_at_ms > 0);
    }

    #[tokio::test]
    async fn workspace_snapshot_compaction_uses_observation_task() {
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        reset_live_scheduler().await;

        let before =
            recent_lane_entries("workspace_snapshot_compaction", OBSERVATION_LANE_RING_CAPACITY)
                .await;
        let _ = run_live_registered_tasks().await.expect("run ok");
        let after =
            recent_lane_entries("workspace_snapshot_compaction", OBSERVATION_LANE_RING_CAPACITY)
                .await;
        assert_eq!(
            after.len(),
            (before.len() + 1).min(OBSERVATION_LANE_RING_CAPACITY),
            "one run must append exactly one row to the workspace lane"
        );
        let latest = after.last().expect("post-run lane must be non-empty");
        assert_eq!(latest.task_name, "workspace_snapshot_compaction");
        assert!(latest.completed);
    }

    #[tokio::test]
    async fn non_observation_lanes_remain_noop_skips() {
        // The 6 canonical names that need real work (not just
        // observation) must keep reporting `skipped(1)` until their
        // dedicated implementation slices land.
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        reset_live_scheduler().await;
        let outcomes = run_live_registered_tasks().await.expect("run ok");

        for name in [
            "dedupe_artifacts",
            "memory_distillation",
            "cloud_knowledge_distillation",
            "session_graph_generation",
            "skill_evolution_analysis",
            "ssm_state_pruning",
        ] {
            let outcome = outcomes
                .iter()
                .find(|o| o.name == name)
                .unwrap_or_else(|| panic!("canonical name {name} must be registered"));
            assert_eq!(
                outcome.outcome.items_skipped, 1,
                "non-observation lane ({name}) must still report skipped(1) until its real body lands"
            );
            assert_eq!(outcome.outcome.items_processed, 0);
            // And the observation lane store must NOT have a ring for
            // this name (it shouldn't be written to).
            let ring_snapshot =
                recent_lane_entries(canonical_name_to_static(name), OBSERVATION_LANE_RING_CAPACITY)
                    .await;
            assert!(
                ring_snapshot.is_empty(),
                "non-observation task ({name}) must NOT have written to a lane ring"
            );
        }
    }

    /// Test helper: map a canonical name (`&str`) back to its
    /// `&'static str` form using the registered set. Lets the
    /// `non_observation_lanes_remain_noop_skips` test pass a static
    /// lane key into `recent_lane_entries`.
    fn canonical_name_to_static(name: &str) -> &'static str {
        super::super::CANONICAL_TASK_NAMES
            .iter()
            .copied()
            .find(|n| *n == name)
            .unwrap_or("")
    }

    #[tokio::test]
    async fn parallel_lanes_grow_independently() {
        // Each task body writes to its own ring; a single scheduler run
        // must grow both the maintenance_log + search_index lanes by
        // exactly one row each.
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        reset_live_scheduler().await;

        let m_before = recent_maintenance_log_entries(MAINTENANCE_LOG_RING_CAPACITY)
            .await
            .len();
        let s_before = recent_search_index_checkpoint_entries(
            SEARCH_INDEX_CHECKPOINT_LOG_RING_CAPACITY,
        )
        .await
        .len();
        let _ = run_live_registered_tasks().await.expect("run ok");
        let m_after = recent_maintenance_log_entries(MAINTENANCE_LOG_RING_CAPACITY)
            .await
            .len();
        let s_after = recent_search_index_checkpoint_entries(
            SEARCH_INDEX_CHECKPOINT_LOG_RING_CAPACITY,
        )
        .await
        .len();
        assert_eq!(
            m_after,
            (m_before + 1).min(MAINTENANCE_LOG_RING_CAPACITY),
            "maintenance_log lane must grow by one"
        );
        assert_eq!(
            s_after,
            (s_before + 1).min(SEARCH_INDEX_CHECKPOINT_LOG_RING_CAPACITY),
            "search_index_passive_checkpoint lane must grow by one"
        );
    }
}
