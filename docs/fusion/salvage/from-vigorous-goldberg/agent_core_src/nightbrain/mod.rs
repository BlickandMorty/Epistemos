//! Plan §7.1 — NightBrain idle scheduler.
//!
//! Single-process, multi-task scheduler that runs maintenance work
//! when the system is idle:
//!
//! - **Trigger**: thermal nominal AND idle ≥ 60s AND (on AC OR battery
//!   > 50%). The host wires the thermal/battery probes; this module
//!   owns the rest.
//! - **Worker pool**: Tokio multi-threaded runtime, capped at
//!   `min(4, available_cores - 2)` per plan.
//! - **Preemption**: any user input cancels in-flight tasks. Tasks
//!   check `ctx.is_cancelled()` between batch units (every 32 items
//!   typically).
//! - **Persistence**: each task writes a `<task>.checkpoint.json`
//!   after each batch unit; resumable on next idle window.
//!
//! Per FINAL_SYNTHESIS §2 layer 7 (Metabolism): "Auto-research
//! observes the log, runs variants overnight, keeps wins, tombstones
//! losses, surfaces morning report. Outputs improved baselines for
//! Layers 2-4 next day."

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use thiserror::Error;

use crate::lifecycle::idle_monitor::IdleMonitor;

/// Default idle threshold per §7.1: 60 seconds of user-input quiet
/// before NightBrain admits work.
pub const DEFAULT_IDLE_THRESHOLD: Duration = Duration::from_secs(60);

/// Plan §7.1 worker-pool cap formula.
pub fn default_worker_pool_size() -> usize {
    let cores = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4);
    std::cmp::min(4, cores.saturating_sub(2)).max(1)
}

#[derive(Debug, Error)]
pub enum NightBrainError {
    #[error("task failed: {0}")]
    TaskFailed(String),
    #[error("task cancelled")]
    Cancelled,
}

/// Cancellation handle shared across all in-flight NightBrain tasks.
/// Cheap atomic; cloning is just an Arc bump.
#[derive(Clone, Default)]
pub struct CancellationToken(Arc<AtomicBool>);

impl CancellationToken {
    pub fn new() -> Self {
        Self(Arc::new(AtomicBool::new(false)))
    }

    /// Plan §7.1: "any user input triggers cancel_all on NightBrain."
    pub fn cancel(&self) {
        self.0.store(true, Ordering::Release);
    }

    pub fn is_cancelled(&self) -> bool {
        self.0.load(Ordering::Acquire)
    }

    /// Used by the scheduler to reset the token between admit cycles.
    pub fn reset(&self) {
        self.0.store(false, Ordering::Release);
    }
}

/// Per-task context. Tasks call `is_cancelled()` between batch units
/// to honor §7.1 preemption.
pub struct TaskCtx {
    pub token: CancellationToken,
    /// Plan §7.1: "Tasks check ctx.cancellation_token between batch
    /// units (every 32 items typically)."
    pub batch_size: usize,
}

impl TaskCtx {
    pub fn new(token: CancellationToken) -> Self {
        Self {
            token,
            batch_size: 32,
        }
    }

    pub fn is_cancelled(&self) -> bool {
        self.token.is_cancelled()
    }
}

/// NightBrain task surface. Concrete impls land alongside the
/// subsystems they maintain (re-route low-confidence captures lives
/// in route/, undo eviction in undo/, vacuum in storage/, etc.).
#[async_trait]
pub trait NightBrainTask: Send + Sync {
    /// Stable name for telemetry / checkpoint files
    /// (`<name>.checkpoint.json`).
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

/// Outcome reported back to the scheduler so it can compose the
/// morning report.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TaskOutcome {
    pub items_processed: usize,
    pub items_skipped: usize,
    pub completed: bool,
}

impl TaskOutcome {
    pub fn complete(items: usize) -> Self {
        Self {
            items_processed: items,
            items_skipped: 0,
            completed: true,
        }
    }

    pub fn preempted(items_so_far: usize) -> Self {
        Self {
            items_processed: items_so_far,
            items_skipped: 0,
            completed: false,
        }
    }
}

/// Single-process scheduler. Owns the cancellation token; preempt()
/// fans the cancel out to every in-flight task.
pub struct NightBrainScheduler {
    token: CancellationToken,
    idle_threshold: Duration,
    monitor: Arc<IdleMonitor>,
    pool_size: usize,
}

impl NightBrainScheduler {
    pub fn new(monitor: Arc<IdleMonitor>) -> Self {
        Self {
            token: CancellationToken::new(),
            idle_threshold: DEFAULT_IDLE_THRESHOLD,
            monitor,
            pool_size: default_worker_pool_size(),
        }
    }

    pub fn with_idle_threshold(mut self, threshold: Duration) -> Self {
        self.idle_threshold = threshold;
        self
    }

    pub fn with_pool_size(mut self, pool_size: usize) -> Self {
        self.pool_size = pool_size.max(1);
        self
    }

    pub fn cancellation_token(&self) -> CancellationToken {
        self.token.clone()
    }

    /// Plan §7.1 trigger gate. The host caller passes thermal + power
    /// state; this module owns the idle-time + cancellation pieces.
    /// Returns true when work should be admitted.
    pub fn should_admit(&self, thermal_nominal: bool, on_ac_or_battery_above_50: bool) -> bool {
        thermal_nominal
            && on_ac_or_battery_above_50
            && self.monitor.is_idle_for(self.idle_threshold)
            && !self.token.is_cancelled()
    }

    /// Plan §7.1: "any user input triggers cancel_all on NightBrain."
    /// Call this from idle_monitor::mark_user_input() callbacks.
    pub fn preempt(&self) {
        self.token.cancel();
    }

    /// Reset the cancellation token between admit cycles.
    pub fn reset(&self) {
        self.token.reset();
    }

    /// Run a single task in the foreground (for tests + simple
    /// driver loops). Production deployment runs tasks on the Tokio
    /// pool via a separate driver; the trait is the contract.
    pub async fn run_task(
        &self,
        task: &dyn NightBrainTask,
    ) -> Result<TaskOutcome, NightBrainError> {
        let ctx = TaskCtx::new(self.token.clone());
        task.run(&ctx).await
    }

    pub fn pool_size(&self) -> usize {
        self.pool_size
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::AtomicUsize;

    struct CountingTask {
        name: &'static str,
        items: usize,
        processed: AtomicUsize,
    }

    #[async_trait]
    impl NightBrainTask for CountingTask {
        fn name(&self) -> &str {
            self.name
        }

        async fn run(&self, ctx: &TaskCtx) -> Result<TaskOutcome, NightBrainError> {
            let batch = ctx.batch_size;
            let mut processed = 0;
            for chunk in (0..self.items).step_by(batch) {
                if ctx.is_cancelled() {
                    self.processed.store(processed, Ordering::Relaxed);
                    return Ok(TaskOutcome::preempted(processed));
                }
                let unit = std::cmp::min(batch, self.items - chunk);
                processed += unit;
            }
            self.processed.store(processed, Ordering::Relaxed);
            Ok(TaskOutcome::complete(processed))
        }
    }

    #[tokio::test]
    async fn admits_when_idle_thermal_and_battery_ok() {
        let monitor = IdleMonitor::new();
        // Use a 0-second idle threshold so the test runs deterministically
        // without sleeping; production deployments use the 60s default.
        let scheduler = NightBrainScheduler::new(monitor)
            .with_idle_threshold(Duration::from_secs(0));
        assert!(scheduler.should_admit(true, true));
    }

    #[tokio::test]
    async fn does_not_admit_when_user_active() {
        let monitor = IdleMonitor::new();
        let scheduler = NightBrainScheduler::new(monitor)
            .with_idle_threshold(Duration::from_secs(60));
        // Fresh monitor → not idle.
        assert!(!scheduler.should_admit(true, true));
    }

    #[tokio::test]
    async fn does_not_admit_under_thermal_pressure_or_low_battery() {
        let monitor = IdleMonitor::new();
        let scheduler = NightBrainScheduler::new(monitor)
            .with_idle_threshold(Duration::from_secs(0));
        assert!(!scheduler.should_admit(false, true), "thermal pressure blocks admit");
        assert!(!scheduler.should_admit(true, false), "low battery on DC blocks admit");
    }

    #[tokio::test]
    async fn preempt_cancels_running_task() {
        let monitor = IdleMonitor::new();
        let scheduler = NightBrainScheduler::new(monitor);
        let task = CountingTask {
            name: "counter",
            items: 10_000,
            processed: AtomicUsize::new(0),
        };
        // Cancel before run.
        scheduler.preempt();
        let outcome = scheduler.run_task(&task).await.expect("task should not error");
        assert!(!outcome.completed, "preempted task should not complete");
    }

    #[tokio::test]
    async fn task_completes_when_not_cancelled() {
        let monitor = IdleMonitor::new();
        let scheduler = NightBrainScheduler::new(monitor);
        let task = CountingTask {
            name: "counter",
            items: 100,
            processed: AtomicUsize::new(0),
        };
        let outcome = scheduler.run_task(&task).await.expect("ok");
        assert!(outcome.completed);
        assert_eq!(outcome.items_processed, 100);
    }

    #[test]
    fn pool_size_caps_at_4_per_plan_7_1() {
        let monitor = IdleMonitor::new();
        // No matter the host machine, the pool never exceeds 4 per §7.1.
        let scheduler = NightBrainScheduler::new(monitor);
        assert!(scheduler.pool_size() <= 4);
        assert!(scheduler.pool_size() >= 1);
    }

    #[test]
    fn cancellation_token_is_shared_via_arc_clone() {
        let monitor = IdleMonitor::new();
        let scheduler = NightBrainScheduler::new(monitor);
        let t1 = scheduler.cancellation_token();
        let t2 = scheduler.cancellation_token();
        assert!(!t1.is_cancelled() && !t2.is_cancelled());
        t1.cancel();
        assert!(t2.is_cancelled(), "cancellation token must be shared, not cloned");
    }

    #[test]
    fn reset_clears_cancellation_for_next_admit_cycle() {
        let monitor = IdleMonitor::new();
        let scheduler = NightBrainScheduler::new(monitor);
        scheduler.preempt();
        assert!(scheduler.cancellation_token().is_cancelled());
        scheduler.reset();
        assert!(!scheduler.cancellation_token().is_cancelled());
    }
}
