use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use thiserror::Error;

pub mod live;

pub const DEFAULT_IDLE_THRESHOLD: Duration = Duration::from_secs(60);
pub const CANONICAL_TASK_NAMES: &[&str] = &[
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
];

pub type Result<T> = std::result::Result<T, NightBrainError>;

pub fn canonical_task_names() -> Vec<String> {
    CANONICAL_TASK_NAMES
        .iter()
        .map(|name| (*name).to_string())
        .collect()
}

pub fn default_worker_pool_size() -> usize {
    let cores = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4);
    std::cmp::min(4, cores.saturating_sub(2)).max(1)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct HostActivitySnapshot {
    pub idle_for: Duration,
    pub thermal_nominal: bool,
    pub on_ac_or_battery_above_50: bool,
}

#[derive(Debug, Error)]
pub enum NightBrainError {
    #[error("task failed: {0}")]
    TaskFailed(String),
    #[error("task cancelled")]
    Cancelled,
    #[error("invalid task name")]
    InvalidTaskName,
    #[error("duplicate task name: {0}")]
    DuplicateTaskName(String),
}

#[derive(Clone, Default)]
pub struct CancellationToken(Arc<AtomicBool>);

impl CancellationToken {
    pub fn new() -> Self {
        Self(Arc::new(AtomicBool::new(false)))
    }

    pub fn cancel(&self) {
        self.0.store(true, Ordering::Release);
    }

    pub fn is_cancelled(&self) -> bool {
        self.0.load(Ordering::Acquire)
    }

    pub fn reset(&self) {
        self.0.store(false, Ordering::Release);
    }
}

#[derive(Clone)]
pub struct TaskCtx {
    token: CancellationToken,
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

    pub fn cancellation_token(&self) -> CancellationToken {
        self.token.clone()
    }
}

#[async_trait]
pub trait NightBrainTask: Send + Sync {
    fn name(&self) -> &str;
    async fn run(&self, ctx: &TaskCtx) -> Result<TaskOutcome>;
}

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

    pub fn skipped(items: usize) -> Self {
        Self {
            items_processed: 0,
            items_skipped: items,
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RegisteredTaskOutcome {
    pub name: String,
    pub outcome: TaskOutcome,
}

pub struct NightBrainScheduler {
    token: CancellationToken,
    idle_threshold: Duration,
    pool_size: usize,
    tasks: Vec<Arc<dyn NightBrainTask>>,
}

impl Default for NightBrainScheduler {
    fn default() -> Self {
        Self::new()
    }
}

impl NightBrainScheduler {
    pub fn new() -> Self {
        Self {
            token: CancellationToken::new(),
            idle_threshold: DEFAULT_IDLE_THRESHOLD,
            pool_size: default_worker_pool_size(),
            tasks: Vec::new(),
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

    pub fn should_admit(&self, snapshot: HostActivitySnapshot) -> bool {
        snapshot.thermal_nominal
            && snapshot.on_ac_or_battery_above_50
            && snapshot.idle_for >= self.idle_threshold
            && !self.token.is_cancelled()
    }

    pub fn preempt(&self) {
        self.token.cancel();
    }

    pub fn reset(&self) {
        self.token.reset();
    }

    pub async fn run_task(&self, task: &dyn NightBrainTask) -> Result<TaskOutcome> {
        let ctx = TaskCtx::new(self.token.clone());
        task.run(&ctx).await
    }

    pub fn register_task(&mut self, task: Arc<dyn NightBrainTask>) -> Result<()> {
        let name = task.name().trim();
        if name.is_empty() {
            return Err(NightBrainError::InvalidTaskName);
        }
        if self
            .tasks
            .iter()
            .any(|registered| registered.name() == name)
        {
            return Err(NightBrainError::DuplicateTaskName(name.to_string()));
        }
        self.tasks.push(task);
        Ok(())
    }

    pub fn registered_task_names(&self) -> Vec<String> {
        self.tasks
            .iter()
            .map(|task| task.name().to_string())
            .collect()
    }

    pub async fn run_registered_tasks(&self) -> Result<Vec<RegisteredTaskOutcome>> {
        let mut outcomes = Vec::with_capacity(self.tasks.len());
        for task in &self.tasks {
            let outcome = self.run_task(task.as_ref()).await?;
            let completed = outcome.completed;
            outcomes.push(RegisteredTaskOutcome {
                name: task.name().to_string(),
                outcome,
            });
            if !completed || self.token.is_cancelled() {
                break;
            }
        }
        Ok(outcomes)
    }

    pub fn pool_size(&self) -> usize {
        self.pool_size
    }
}
