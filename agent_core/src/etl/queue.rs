use anyhow::{Context, Result};
use apalis::prelude::{BoxDynError, Metrics, TaskSink, WorkerBuilder, WorkerContext};
use apalis_sqlite::{SqliteConnectOptions, SqlitePool, SqliteStorage};
use futures::stream;
use serde::{Deserialize, Serialize};
use std::{future::Future, path::Path};

use super::jobs::EtlIngestJob;

pub const ETL_QUEUE_NAME: &str = "epistemos-etl-ingest";

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct EtlQueueStats {
    pub total: u64,
    pub pending: u64,
    pub running: u64,
    pub done: u64,
    pub failed: u64,
    pub killed: u64,
    pub active: u64,
    pub completed: u64,
}

#[derive(Debug, Clone)]
pub struct EtlQueue {
    pool: SqlitePool,
}

impl EtlQueue {
    pub async fn open_at(path: impl AsRef<Path>) -> Result<Self> {
        let path = path.as_ref();
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("create ETL queue directory {}", parent.display()))?;
        }
        let options = SqliteConnectOptions::new()
            .filename(path)
            .create_if_missing(true);
        let pool = SqlitePool::connect_with(options)
            .await
            .with_context(|| format!("open ETL queue database {}", path.display()))?;
        Self::from_pool(pool).await
    }

    pub async fn open_database_url(database_url: &str) -> Result<Self> {
        let pool = SqlitePool::connect(database_url)
            .await
            .with_context(|| format!("open ETL queue database URL {database_url}"))?;
        Self::from_pool(pool).await
    }

    pub async fn open_in_memory() -> Result<Self> {
        Self::open_database_url(":memory:").await
    }

    async fn from_pool(pool: SqlitePool) -> Result<Self> {
        SqliteStorage::setup(&pool)
            .await
            .context("run ETL queue migrations")?;
        Ok(Self { pool })
    }

    pub async fn enqueue_job(&self, job: EtlIngestJob) -> Result<()> {
        let mut backend = SqliteStorage::new_in_queue(&self.pool, ETL_QUEUE_NAME);
        backend.push(job).await.context("enqueue ETL ingest job")
    }

    pub async fn enqueue_jobs<I>(&self, jobs: I) -> Result<usize>
    where
        I: IntoIterator<Item = EtlIngestJob>,
    {
        let jobs: Vec<_> = jobs.into_iter().collect();
        let count = jobs.len();
        let mut backend = SqliteStorage::new_in_queue(&self.pool, ETL_QUEUE_NAME);
        let mut jobs = stream::iter(jobs);
        backend
            .push_stream(&mut jobs)
            .await
            .context("enqueue ETL ingest jobs")?;
        Ok(count)
    }

    pub async fn run_worker<F, Fut>(&self, worker_name: &str, handler: F) -> Result<()>
    where
        F: Fn(EtlIngestJob, WorkerContext) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = Result<(), BoxDynError>> + Send + 'static,
    {
        let backend = SqliteStorage::new_in_queue(&self.pool, ETL_QUEUE_NAME);
        let worker = WorkerBuilder::new(worker_name)
            .backend(backend)
            .build(move |job, worker| {
                let handler = handler.clone();
                async move { handler(job, worker).await }
            });
        worker
            .run()
            .await
            .with_context(|| format!("run ETL worker {worker_name}"))?;
        Ok(())
    }

    pub async fn stats(&self) -> Result<EtlQueueStats> {
        let backend =
            SqliteStorage::<EtlIngestJob, (), ()>::new_in_queue(&self.pool, ETL_QUEUE_NAME);
        let rows = backend
            .fetch_by_queue(ETL_QUEUE_NAME)
            .await
            .context("read ETL queue metrics")?;
        let mut stats = EtlQueueStats::default();
        for row in rows {
            let value = parse_statistic_count(&row.value);
            match row.title.as_str() {
                "TOTAL_JOBS" => stats.total = value,
                "PENDING_JOBS" => stats.pending = value,
                "RUNNING_JOBS" => stats.running = value,
                "DONE_JOBS" => stats.done = value,
                "FAILED_JOBS" => stats.failed = value,
                "KILLED_JOBS" => stats.killed = value,
                "ACTIVE_JOBS" => stats.active = value,
                "COMPLETED_JOBS" => stats.completed = value,
                _ => {}
            }
        }
        Ok(stats)
    }
}

fn parse_statistic_count(value: &str) -> u64 {
    value
        .parse::<f64>()
        .ok()
        .filter(|parsed| parsed.is_finite() && *parsed > 0.0)
        .map(|parsed| parsed.round() as u64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{
        path::PathBuf,
        sync::{
            atomic::{AtomicUsize, Ordering},
            Arc,
        },
        time::Duration,
    };
    use tempfile::TempDir;
    use tokio::sync::Mutex;

    fn job(path: &str, fingerprint: u64) -> EtlIngestJob {
        EtlIngestJob {
            path: PathBuf::from(path),
            size_bytes: 42,
            fingerprint,
            kind: super::super::jobs::EtlInputKind::Markdown,
        }
    }

    fn sort_jobs(jobs: &mut [EtlIngestJob]) {
        jobs.sort_by(|lhs, rhs| {
            lhs.fingerprint
                .cmp(&rhs.fingerprint)
                .then_with(|| lhs.path.cmp(&rhs.path))
        });
    }

    async fn drain_jobs(queue: &EtlQueue, count: usize) -> Result<Vec<EtlIngestJob>> {
        let seen = Arc::new(Mutex::new(Vec::with_capacity(count)));
        let remaining = Arc::new(AtomicUsize::new(count));
        let seen_for_worker = seen.clone();
        let remaining_for_worker = remaining.clone();

        tokio::time::timeout(Duration::from_secs(5), async move {
            queue
                .run_worker("etl-test-worker", move |job, worker| {
                    let seen = seen_for_worker.clone();
                    let remaining = remaining_for_worker.clone();
                    async move {
                        seen.lock().await.push(job);
                        if remaining.fetch_sub(1, Ordering::SeqCst) == 1 {
                            let _ = worker.stop();
                        }
                        Ok(())
                    }
                })
                .await
        })
        .await
        .context("timed out draining ETL worker")??;

        let drained = seen.lock().await.clone();
        Ok(drained)
    }

    #[tokio::test]
    async fn drains_enqueued_jobs_with_worker() -> Result<()> {
        let queue = EtlQueue::open_in_memory().await?;
        let jobs = vec![job("notes/a.md", 1), job("notes/b.md", 2)];

        assert_eq!(queue.enqueue_jobs(jobs.clone()).await?, jobs.len());
        let mut expected = jobs;
        let mut drained = drain_jobs(&queue, expected.len()).await?;
        sort_jobs(&mut expected);
        sort_jobs(&mut drained);

        assert_eq!(drained, expected);
        Ok(())
    }

    #[tokio::test]
    async fn persists_jobs_until_reopened_worker_drains_them() -> Result<()> {
        let dir = TempDir::new()?;
        let db_path = dir.path().join("etl.sqlite");
        let jobs = vec![job("notes/persisted.md", 99)];
        {
            let queue = EtlQueue::open_at(&db_path).await?;
            queue.enqueue_jobs(jobs.clone()).await?;
        }

        let reopened = EtlQueue::open_at(&db_path).await?;
        let drained = drain_jobs(&reopened, jobs.len()).await?;

        assert_eq!(drained, jobs);
        Ok(())
    }

    #[tokio::test]
    async fn enqueue_job_accepts_single_typed_job() -> Result<()> {
        let queue = EtlQueue::open_in_memory().await?;
        let expected = vec![job("notes/single.md", 7)];

        queue.enqueue_job(expected[0].clone()).await?;
        let drained = drain_jobs(&queue, expected.len()).await?;

        assert_eq!(drained, expected);
        Ok(())
    }

    #[tokio::test]
    async fn stats_are_zero_for_new_queue() -> Result<()> {
        let queue = EtlQueue::open_in_memory().await?;

        assert_eq!(queue.stats().await?, EtlQueueStats::default());
        Ok(())
    }

    #[tokio::test]
    async fn stats_count_pending_jobs_after_enqueue() -> Result<()> {
        let queue = EtlQueue::open_in_memory().await?;
        let jobs = vec![job("notes/a.md", 1), job("notes/b.md", 2)];

        queue.enqueue_jobs(jobs).await?;
        let stats = queue.stats().await?;

        assert_eq!(stats.total, 2);
        assert_eq!(stats.pending, 2);
        assert_eq!(stats.running, 0);
        assert_eq!(stats.done, 0);
        assert_eq!(stats.active, 2);
        assert_eq!(stats.completed, 0);
        Ok(())
    }

    #[tokio::test]
    async fn stats_count_done_jobs_after_worker_drains() -> Result<()> {
        let queue = EtlQueue::open_in_memory().await?;
        let jobs = vec![job("notes/a.md", 1), job("notes/b.md", 2)];

        queue.enqueue_jobs(jobs.clone()).await?;
        let mut expected = jobs;
        let mut drained = drain_jobs(&queue, expected.len()).await?;
        sort_jobs(&mut expected);
        sort_jobs(&mut drained);
        assert_eq!(drained, expected);

        let stats = queue.stats().await?;
        assert_eq!(stats.total, 2);
        assert_eq!(stats.pending, 0);
        assert_eq!(stats.running, 0);
        assert_eq!(stats.done, 2);
        assert_eq!(stats.active, 0);
        assert_eq!(stats.completed, 2);
        Ok(())
    }
}
