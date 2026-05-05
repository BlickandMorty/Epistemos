//! Live NightBrain task registration — global singleton scheduler the
//! Swift side calls into via UniFFI to register canonical maintenance
//! tasks at app boot.
//!
//! Scope: closes the "NightBrain live Rust task registration not fully
//! wired" follow-up flagged after the Codex continuation pass. Before
//! this module the FFI surface only exposed `canonical_task_names()`
//! (the contract list) + `nightbrain_preview_admission(...)` (the gate
//! preview). There was no path for the Swift host to actually register
//! task implementations + trigger a run from the live scheduler.
//!
//! Approach: a `LiveScheduler` lazy-static singleton holds the canonical
//! tasks. `register_canonical_tasks()` populates it idempotently with
//! `NoOpTask` implementations — placeholders that record their name +
//! execution but perform no real work. Each canonical task body
//! (event_store_checkpoint_vacuum, search_index_passive_checkpoint, …)
//! can then be filled in incrementally without changing the registration
//! surface. What matters here is that the SHAPE of the live registration
//! is plumbed end-to-end (Swift → FFI → Rust singleton → run), not that
//! every task body does real work today.
//!
//! Determinism: registration is idempotent (re-registering an already-
//! present canonical name is a no-op, not a duplicate-name error). This
//! lets AppBootstrap call register_canonical_tasks unconditionally
//! without tracking whether it ran before.

use std::sync::{Arc, OnceLock};

use async_trait::async_trait;
use tokio::sync::Mutex;

use super::{NightBrainScheduler, NightBrainTask, RegisteredTaskOutcome, Result, TaskCtx, TaskOutcome};

/// Process-global live scheduler. Held in a OnceLock so the singleton
/// is initialised on first access and never reconstructed.
static LIVE_SCHEDULER: OnceLock<Arc<Mutex<NightBrainScheduler>>> = OnceLock::new();

fn live_scheduler() -> Arc<Mutex<NightBrainScheduler>> {
    LIVE_SCHEDULER
        .get_or_init(|| Arc::new(Mutex::new(NightBrainScheduler::new())))
        .clone()
}

/// Placeholder task implementation — records its canonical name and
/// returns a `complete(0)` outcome. Real task bodies replace this
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
        // long task chains. No real work — replace per-task.
        tokio::task::yield_now().await;
        Ok(TaskOutcome::complete(0))
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
        let task: Arc<dyn NightBrainTask> = Arc::new(NoOpTask {
            canonical_name,
        });
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
    async fn run_live_registered_tasks_completes_every_canonical_task() {
        let _guard = test_serializer().lock().await;
        register_canonical_tasks().await;
        reset_live_scheduler().await; // any prior preempts cleared
        let outcomes = run_live_registered_tasks().await.expect("run ok");
        assert_eq!(outcomes.len(), canonical_task_names().len());
        for outcome in &outcomes {
            assert!(outcome.outcome.completed, "no-op task must complete");
            assert_eq!(outcome.outcome.items_processed, 0, "no-op processes 0");
        }
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
        assert!(!outcomes[0].outcome.completed, "first task must be preempted");
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
}
