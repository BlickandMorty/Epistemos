use anyhow::{bail, Context, Result};
use apalis::prelude::BoxDynError;
use serde::Serialize;
use std::{
    fs,
    sync::{
        atomic::{AtomicUsize, Ordering},
        Arc,
    },
    time::Duration,
};

use super::{hash::fingerprint, EtlIngestJob, EtlInputKind, EtlQueue};

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct EtlWorkerRunSummary {
    pub requested: u64,
    pub attempted: u64,
    pub succeeded: u64,
    pub failed: u64,
    pub pending_before: u64,
    pub pending_after: u64,
    pub done_after: u64,
    pub failed_after: u64,
    pub error: Option<String>,
}

pub fn validate_ingest_job(job: &EtlIngestJob) -> Result<()> {
    let metadata = fs::metadata(&job.path)
        .with_context(|| format!("read ETL job metadata {}", job.path.display()))?;
    if !metadata.is_file() {
        bail!("ETL job path is not a regular file: {}", job.path.display());
    }
    if metadata.len() != job.size_bytes {
        bail!(
            "ETL job size changed for {}: expected {}, got {}",
            job.path.display(),
            job.size_bytes,
            metadata.len()
        );
    }
    let current_kind =
        EtlInputKind::from_extension(job.path.extension().and_then(|ext| ext.to_str()))
            .ok_or_else(|| {
                anyhow::anyhow!(
                    "ETL job kind is no longer supported: {}",
                    job.path.display()
                )
            })?;
    if current_kind != job.kind {
        bail!(
            "ETL job kind changed for {}: expected {:?}, got {:?}",
            job.path.display(),
            job.kind,
            current_kind
        );
    }
    let content = fs::read(&job.path)
        .with_context(|| format!("read ETL job content {}", job.path.display()))?;
    let path_string = job.path.to_string_lossy();
    let actual = fingerprint(path_string.as_bytes(), &content);
    if actual != job.fingerprint {
        bail!(
            "ETL job fingerprint mismatch for {}: expected {}, got {}",
            job.path.display(),
            job.fingerprint,
            actual
        );
    }
    Ok(())
}

pub async fn run_bounded_validation_worker(
    queue: &EtlQueue,
    max_jobs: usize,
) -> Result<EtlWorkerRunSummary> {
    let before = queue
        .stats()
        .await
        .context("read ETL stats before worker")?;
    let requested = before.pending.min(max_jobs as u64);
    if requested == 0 {
        return Ok(EtlWorkerRunSummary {
            requested: 0,
            attempted: 0,
            succeeded: 0,
            failed: 0,
            pending_before: before.pending,
            pending_after: before.pending,
            done_after: before.done,
            failed_after: before.failed + before.killed,
            error: None,
        });
    }

    let attempted = Arc::new(AtomicUsize::new(0));
    let succeeded = Arc::new(AtomicUsize::new(0));
    let failed = Arc::new(AtomicUsize::new(0));
    let target = requested as usize;
    let attempted_for_worker = attempted.clone();
    let succeeded_for_worker = succeeded.clone();
    let failed_for_worker = failed.clone();

    let run_result = tokio::time::timeout(Duration::from_secs(30), async {
        queue
            .run_worker("etl-validation-worker", move |job, worker| {
                let attempted = attempted_for_worker.clone();
                let succeeded = succeeded_for_worker.clone();
                let failed = failed_for_worker.clone();
                async move {
                    let validation = validate_ingest_job(&job);
                    match &validation {
                        Ok(()) => {
                            succeeded.fetch_add(1, Ordering::SeqCst);
                        }
                        Err(_) => {
                            failed.fetch_add(1, Ordering::SeqCst);
                        }
                    }
                    let current = attempted.fetch_add(1, Ordering::SeqCst) + 1;
                    if current >= target {
                        let _ = worker.stop();
                    }
                    validation.map_err(|error| -> BoxDynError {
                        Box::new(std::io::Error::other(format!("{error:#}")))
                    })
                }
            })
            .await
    })
    .await;

    let error = match run_result {
        Ok(Ok(())) => None,
        Ok(Err(error)) => Some(format!("{error:#}")),
        Err(_) => Some("timed out running ETL validation worker".to_string()),
    };
    let after = queue.stats().await.context("read ETL stats after worker")?;
    Ok(EtlWorkerRunSummary {
        requested,
        attempted: attempted.load(Ordering::SeqCst) as u64,
        succeeded: succeeded.load(Ordering::SeqCst) as u64,
        failed: failed.load(Ordering::SeqCst) as u64,
        pending_before: before.pending,
        pending_after: after.pending,
        done_after: after.done,
        failed_after: after.failed + after.killed,
        error,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn validation_accepts_current_supported_file() -> Result<()> {
        let dir = TempDir::new()?;
        let source = dir.path().join("note.md");
        fs::write(&source, "body")?;
        let path_string = source.to_string_lossy().into_owned();
        let job = EtlIngestJob {
            path: source,
            size_bytes: 4,
            fingerprint: fingerprint(path_string.as_bytes(), b"body"),
            kind: EtlInputKind::Markdown,
        };

        validate_ingest_job(&job)?;
        Ok(())
    }

    #[test]
    fn validation_rejects_missing_file() {
        let job = EtlIngestJob {
            path: "missing.md".into(),
            size_bytes: 4,
            fingerprint: 42,
            kind: EtlInputKind::Markdown,
        };

        assert!(validate_ingest_job(&job).is_err());
    }

    #[test]
    fn validation_rejects_fingerprint_mismatch() -> Result<()> {
        let dir = TempDir::new()?;
        let source = dir.path().join("note.md");
        fs::write(&source, "changed")?;
        let job = EtlIngestJob {
            path: source,
            size_bytes: 7,
            fingerprint: 42,
            kind: EtlInputKind::Markdown,
        };

        assert!(validate_ingest_job(&job).is_err());
        Ok(())
    }
}
