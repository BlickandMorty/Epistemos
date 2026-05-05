use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::Duration;

use agent_core::bridge::{nightbrain_canonical_task_names, nightbrain_preview_admission};
use agent_core::nightbrain::{
    default_worker_pool_size, CancellationToken, HostActivitySnapshot, NightBrainScheduler,
    NightBrainTask, TaskCtx, TaskOutcome, DEFAULT_IDLE_THRESHOLD,
};
use async_trait::async_trait;

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

    async fn run(&self, ctx: &TaskCtx) -> agent_core::nightbrain::Result<TaskOutcome> {
        let mut processed = 0;
        for chunk in (0..self.items).step_by(ctx.batch_size) {
            if ctx.is_cancelled() {
                self.processed.store(processed, Ordering::Relaxed);
                return Ok(TaskOutcome::preempted(processed));
            }
            processed += std::cmp::min(ctx.batch_size, self.items - chunk);
        }
        self.processed.store(processed, Ordering::Relaxed);
        Ok(TaskOutcome::complete(processed))
    }
}

struct CancellingTask {
    name: &'static str,
}

#[async_trait]
impl NightBrainTask for CancellingTask {
    fn name(&self) -> &str {
        self.name
    }

    async fn run(&self, ctx: &TaskCtx) -> agent_core::nightbrain::Result<TaskOutcome> {
        ctx.cancellation_token().cancel();
        Ok(TaskOutcome::preempted(0))
    }
}

#[test]
fn default_idle_gate_is_sixty_seconds() {
    assert_eq!(DEFAULT_IDLE_THRESHOLD, Duration::from_secs(60));
}

#[test]
fn host_activity_snapshot_admits_only_when_idle_thermal_and_power_are_clear() {
    let scheduler = NightBrainScheduler::new();

    assert!(scheduler.should_admit(HostActivitySnapshot {
        idle_for: Duration::from_secs(61),
        thermal_nominal: true,
        on_ac_or_battery_above_50: true,
    }));

    assert!(!scheduler.should_admit(HostActivitySnapshot {
        idle_for: Duration::from_secs(59),
        thermal_nominal: true,
        on_ac_or_battery_above_50: true,
    }));
    assert!(!scheduler.should_admit(HostActivitySnapshot {
        idle_for: Duration::from_secs(61),
        thermal_nominal: false,
        on_ac_or_battery_above_50: true,
    }));
    assert!(!scheduler.should_admit(HostActivitySnapshot {
        idle_for: Duration::from_secs(61),
        thermal_nominal: true,
        on_ac_or_battery_above_50: false,
    }));
}

#[tokio::test]
async fn preempt_cancels_running_task_and_reset_opens_next_cycle() {
    let scheduler = NightBrainScheduler::new();
    let task = CountingTask {
        name: "counter",
        items: 10_000,
        processed: AtomicUsize::new(0),
    };

    scheduler.preempt();
    let outcome = scheduler.run_task(&task).await.expect("preempted task");
    assert_eq!(outcome, TaskOutcome::preempted(0));
    assert!(!scheduler.should_admit(HostActivitySnapshot {
        idle_for: Duration::from_secs(61),
        thermal_nominal: true,
        on_ac_or_battery_above_50: true,
    }));

    scheduler.reset();
    assert!(scheduler.should_admit(HostActivitySnapshot {
        idle_for: Duration::from_secs(61),
        thermal_nominal: true,
        on_ac_or_battery_above_50: true,
    }));
}

#[tokio::test]
async fn task_completes_when_not_cancelled() {
    let scheduler = NightBrainScheduler::new();
    let task = CountingTask {
        name: "counter",
        items: 100,
        processed: AtomicUsize::new(0),
    };

    let outcome = scheduler.run_task(&task).await.expect("completed task");
    assert_eq!(outcome, TaskOutcome::complete(100));
    assert_eq!(task.processed.load(Ordering::Relaxed), 100);
}

#[tokio::test]
async fn registered_tasks_run_in_registration_order() {
    let mut scheduler = NightBrainScheduler::new();
    scheduler
        .register_task(Arc::new(CountingTask {
            name: "first",
            items: 10,
            processed: AtomicUsize::new(0),
        }))
        .expect("first task registers");
    scheduler
        .register_task(Arc::new(CountingTask {
            name: "second",
            items: 20,
            processed: AtomicUsize::new(0),
        }))
        .expect("second task registers");

    assert_eq!(scheduler.registered_task_names(), ["first", "second"]);
    let outcomes = scheduler
        .run_registered_tasks()
        .await
        .expect("registered tasks run");
    assert_eq!(outcomes.len(), 2);
    assert_eq!(outcomes[0].name, "first");
    assert_eq!(outcomes[0].outcome, TaskOutcome::complete(10));
    assert_eq!(outcomes[1].name, "second");
    assert_eq!(outcomes[1].outcome, TaskOutcome::complete(20));
}

#[test]
fn duplicate_registered_task_names_are_rejected() {
    let mut scheduler = NightBrainScheduler::new();
    scheduler
        .register_task(Arc::new(CountingTask {
            name: "vacuum",
            items: 1,
            processed: AtomicUsize::new(0),
        }))
        .expect("first task registers");

    let error = scheduler
        .register_task(Arc::new(CountingTask {
            name: "vacuum",
            items: 1,
            processed: AtomicUsize::new(0),
        }))
        .expect_err("duplicate task names are rejected");
    assert!(error.to_string().contains("duplicate task name"));
}

#[tokio::test]
async fn registered_task_run_stops_after_preemption() {
    let mut scheduler = NightBrainScheduler::new();
    scheduler
        .register_task(Arc::new(CancellingTask { name: "cancel" }))
        .expect("cancelling task registers");
    scheduler
        .register_task(Arc::new(CountingTask {
            name: "after",
            items: 20,
            processed: AtomicUsize::new(0),
        }))
        .expect("second task registers");

    let outcomes = scheduler
        .run_registered_tasks()
        .await
        .expect("registered task run reports preemption outcome");
    assert_eq!(outcomes.len(), 1);
    assert_eq!(outcomes[0].name, "cancel");
    assert_eq!(outcomes[0].outcome, TaskOutcome::preempted(0));
}

#[test]
fn worker_pool_follows_canonical_cap_formula() {
    let pool = default_worker_pool_size();
    assert!((1..=4).contains(&pool));
    assert_eq!(NightBrainScheduler::new().pool_size(), pool);
}

#[test]
fn cancellation_token_is_shared_across_clones() {
    let token = CancellationToken::new();
    let cloned = token.clone();
    assert!(!token.is_cancelled());
    cloned.cancel();
    assert!(token.is_cancelled());
}

#[test]
fn ffi_exposes_canonical_swift_host_task_names() {
    assert_eq!(
        nightbrain_canonical_task_names(),
        [
            "event_store_checkpoint_vacuum",
            "search_index_passive_checkpoint",
            "dedupe_artifacts",
            "workspace_snapshot_compaction",
            "memory_distillation",
            "cloud_knowledge_distillation",
            "session_graph_generation",
            "skill_evolution_analysis",
            "ssm_state_pruning",
            "maintenance_log",
        ]
    );
}

#[test]
fn ffi_admission_preview_matches_scheduler_gate() {
    let admitted = nightbrain_preview_admission(61, true, true, false);
    assert!(admitted.admitted);
    assert_eq!(admitted.reason, "admitted");
    assert_eq!(admitted.idle_threshold_seconds, 60);

    let not_idle = nightbrain_preview_admission(59, true, true, false);
    assert!(!not_idle.admitted);
    assert_eq!(not_idle.reason, "not_idle");

    let preempted = nightbrain_preview_admission(61, true, true, true);
    assert!(!preempted.admitted);
    assert_eq!(preempted.reason, "preempted");
}
