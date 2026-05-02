use serde::Serialize;
use std::{
    ffi::{CStr, CString},
    os::raw::c_char,
    path::{Path, PathBuf},
    ptr,
};

#[cfg(test)]
use super::EtlInputKind;
use super::{
    crawl_vault, run_bounded_validation_worker, EtlIngestJob, EtlQueue, EtlQueueStats,
    EtlWorkerRunSummary,
};

#[derive(Debug, Clone, Serialize)]
struct EtlQueueStatsJson {
    available: bool,
    total: u64,
    pending: u64,
    running: u64,
    done: u64,
    failed: u64,
    killed: u64,
    active: u64,
    completed: u64,
    error: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
struct EtlEnqueueWalkJson {
    available: bool,
    total: u64,
    queued: u64,
    skipped: u64,
    error: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
struct EtlWorkerRunJson {
    available: bool,
    requested: u64,
    attempted: u64,
    succeeded: u64,
    failed: u64,
    pending_before: u64,
    pending_after: u64,
    done_after: u64,
    failed_after: u64,
    error: Option<String>,
}

impl EtlEnqueueWalkJson {
    fn available(total: u64, queued: u64, skipped: u64) -> Self {
        Self {
            available: true,
            total,
            queued,
            skipped,
            error: None,
        }
    }

    fn unavailable(error: impl Into<String>) -> Self {
        Self {
            available: false,
            total: 0,
            queued: 0,
            skipped: 0,
            error: Some(error.into()),
        }
    }
}

impl EtlQueueStatsJson {
    fn available(stats: EtlQueueStats) -> Self {
        Self {
            available: true,
            total: stats.total,
            pending: stats.pending,
            running: stats.running,
            done: stats.done,
            failed: stats.failed,
            killed: stats.killed,
            active: stats.active,
            completed: stats.completed,
            error: None,
        }
    }

    fn unavailable(error: impl Into<String>) -> Self {
        Self {
            available: false,
            total: 0,
            pending: 0,
            running: 0,
            done: 0,
            failed: 0,
            killed: 0,
            active: 0,
            completed: 0,
            error: Some(error.into()),
        }
    }
}

impl EtlWorkerRunJson {
    fn available(summary: EtlWorkerRunSummary) -> Self {
        Self {
            available: true,
            requested: summary.requested,
            attempted: summary.attempted,
            succeeded: summary.succeeded,
            failed: summary.failed,
            pending_before: summary.pending_before,
            pending_after: summary.pending_after,
            done_after: summary.done_after,
            failed_after: summary.failed_after,
            error: summary.error,
        }
    }

    fn unavailable(error: impl Into<String>) -> Self {
        Self {
            available: false,
            requested: 0,
            attempted: 0,
            succeeded: 0,
            failed: 0,
            pending_before: 0,
            pending_after: 0,
            done_after: 0,
            failed_after: 0,
            error: Some(error.into()),
        }
    }
}

#[no_mangle]
pub extern "C" fn etl_queue_stats_json(path: *const c_char) -> *mut c_char {
    let snapshot = match std::panic::catch_unwind(|| stats_snapshot_from_path(path)) {
        Ok(snapshot) => snapshot,
        Err(_) => EtlQueueStatsJson::unavailable("Rust panic while reading ETL queue stats"),
    };
    json_to_c_string(snapshot)
}

#[no_mangle]
pub extern "C" fn etl_enqueue_vault_walk_json(
    vault_path: *const c_char,
    queue_path: *const c_char,
) -> *mut c_char {
    let snapshot =
        match std::panic::catch_unwind(|| enqueue_walk_snapshot_from_paths(vault_path, queue_path))
        {
            Ok(snapshot) => snapshot,
            Err(_) => EtlEnqueueWalkJson::unavailable("Rust panic while enqueueing ETL vault walk"),
        };
    enqueue_json_to_c_string(snapshot)
}

#[no_mangle]
pub extern "C" fn etl_run_worker_json(queue_path: *const c_char, max_jobs: u64) -> *mut c_char {
    let snapshot =
        match std::panic::catch_unwind(|| worker_snapshot_from_path(queue_path, max_jobs)) {
            Ok(snapshot) => snapshot,
            Err(_) => EtlWorkerRunJson::unavailable("Rust panic while running ETL worker"),
        };
    worker_json_to_c_string(snapshot)
}

#[no_mangle]
pub extern "C" fn etl_queue_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    // SAFETY: `ptr` must be a pointer returned by `CString::into_raw` in this
    // module. Reconstructing it exactly once lets Rust free the allocation.
    unsafe {
        drop(CString::from_raw(ptr));
    }
}

fn worker_snapshot_from_path(queue_path: *const c_char, max_jobs: u64) -> EtlWorkerRunJson {
    let queue_path = match string_from_c_path(queue_path, "ETL queue path") {
        Ok(path) => path,
        Err(error) => return EtlWorkerRunJson::unavailable(error),
    };
    if !Path::new(&queue_path).exists() {
        return EtlWorkerRunJson::unavailable("ETL queue database does not exist");
    }

    let runtime = match tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(error) => {
            return EtlWorkerRunJson::unavailable(format!(
                "failed to create ETL worker runtime: {error}"
            ));
        }
    };
    match runtime.block_on(async {
        let queue = EtlQueue::open_at(queue_path).await?;
        run_bounded_validation_worker(&queue, max_jobs as usize).await
    }) {
        Ok(summary) => EtlWorkerRunJson::available(summary),
        Err(error) => EtlWorkerRunJson::unavailable(format!("{error:#}")),
    }
}

fn stats_snapshot_from_path(path: *const c_char) -> EtlQueueStatsJson {
    let path = match string_from_c_path(path, "ETL queue path") {
        Ok(path) => path,
        Err(error) => return EtlQueueStatsJson::unavailable(error),
    };
    if !Path::new(&path).exists() {
        return EtlQueueStatsJson::unavailable("ETL queue database does not exist");
    }

    let runtime = match tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(error) => {
            return EtlQueueStatsJson::unavailable(format!(
                "failed to create ETL stats runtime: {error}"
            ));
        }
    };
    match runtime.block_on(async {
        let queue = EtlQueue::open_at(path).await?;
        queue.stats().await
    }) {
        Ok(stats) => EtlQueueStatsJson::available(stats),
        Err(error) => EtlQueueStatsJson::unavailable(format!("{error:#}")),
    }
}

fn enqueue_walk_snapshot_from_paths(
    vault_path: *const c_char,
    queue_path: *const c_char,
) -> EtlEnqueueWalkJson {
    let vault_path = match string_from_c_path(vault_path, "ETL vault path") {
        Ok(path) => PathBuf::from(path),
        Err(error) => return EtlEnqueueWalkJson::unavailable(error),
    };
    let queue_path = match string_from_c_path(queue_path, "ETL queue path") {
        Ok(path) => PathBuf::from(path),
        Err(error) => return EtlEnqueueWalkJson::unavailable(error),
    };
    if !vault_path.is_dir() {
        return EtlEnqueueWalkJson::unavailable("ETL vault path is not a directory");
    }

    let entries = crawl_vault(&vault_path);
    let total = entries.len() as u64;
    let mut jobs = Vec::with_capacity(entries.len());
    let mut skipped = 0_u64;
    for entry in entries {
        let content = match std::fs::read(&entry.path) {
            Ok(content) => content,
            Err(_) => {
                skipped += 1;
                continue;
            }
        };
        match EtlIngestJob::from_entry(&entry, &content) {
            Some(job) => jobs.push(job),
            None => skipped += 1,
        }
    }

    let runtime = match tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(error) => {
            return EtlEnqueueWalkJson::unavailable(format!(
                "failed to create ETL enqueue runtime: {error}"
            ));
        }
    };
    match runtime.block_on(async {
        let queue = EtlQueue::open_at(&queue_path).await?;
        queue.enqueue_jobs(jobs).await
    }) {
        Ok(queued) => EtlEnqueueWalkJson::available(total, queued as u64, skipped),
        Err(error) => EtlEnqueueWalkJson::unavailable(format!("{error:#}")),
    }
}

fn string_from_c_path(path: *const c_char, label: &str) -> Result<String, String> {
    if path.is_null() {
        return Err(format!("missing {label}"));
    }
    // SAFETY: The caller provided a non-null C string pointer. Invalid UTF-8 is
    // reported as an unavailable diagnostic instead of crossing the FFI boundary.
    let c_path = unsafe { CStr::from_ptr(path) };
    let path = c_path
        .to_str()
        .map_err(|_| format!("{label} was not valid UTF-8"))?;
    if path.trim().is_empty() {
        return Err(format!("missing {label}"));
    }
    Ok(path.to_string())
}

fn json_to_c_string(snapshot: EtlQueueStatsJson) -> *mut c_char {
    let json = serde_json::to_string(&snapshot).unwrap_or_else(|_| {
        "{\"available\":false,\"total\":0,\"pending\":0,\"running\":0,\"done\":0,\"failed\":0,\"killed\":0,\"active\":0,\"completed\":0,\"error\":\"failed to encode ETL stats\"}".to_string()
    });
    c_string_or_null(json)
}

fn enqueue_json_to_c_string(snapshot: EtlEnqueueWalkJson) -> *mut c_char {
    let json = serde_json::to_string(&snapshot).unwrap_or_else(|_| {
        "{\"available\":false,\"total\":0,\"queued\":0,\"skipped\":0,\"error\":\"failed to encode ETL enqueue result\"}".to_string()
    });
    c_string_or_null(json)
}

fn worker_json_to_c_string(snapshot: EtlWorkerRunJson) -> *mut c_char {
    let json = serde_json::to_string(&snapshot).unwrap_or_else(|_| {
        "{\"available\":false,\"requested\":0,\"attempted\":0,\"succeeded\":0,\"failed\":0,\"pending_before\":0,\"pending_after\":0,\"done_after\":0,\"failed_after\":0,\"error\":\"failed to encode ETL worker result\"}".to_string()
    });
    c_string_or_null(json)
}

fn c_string_or_null(value: String) -> *mut c_char {
    match CString::new(value) {
        Ok(c_string) => c_string.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;
    use std::path::PathBuf;
    use tempfile::TempDir;

    fn job(path: &str, fingerprint: u64) -> EtlIngestJob {
        EtlIngestJob {
            path: PathBuf::from(path),
            size_bytes: 42,
            fingerprint,
            kind: EtlInputKind::Markdown,
        }
    }

    fn decode_and_free(ptr: *mut c_char) -> Value {
        assert!(!ptr.is_null(), "stats FFI should always return JSON");
        // SAFETY: The pointer was returned by `etl_queue_stats_json`, which
        // allocates a NUL-terminated Rust-owned C string.
        let json = unsafe { CStr::from_ptr(ptr) }
            .to_str()
            .expect("stats JSON should be UTF-8")
            .to_string();
        etl_queue_free_string(ptr);
        serde_json::from_str(&json).expect("stats JSON should decode")
    }

    #[test]
    fn ffi_null_path_returns_unavailable_json() {
        let decoded = decode_and_free(etl_queue_stats_json(ptr::null()));

        assert_eq!(decoded["available"], false);
        assert_eq!(decoded["pending"], 0);
        assert!(decoded["error"].as_str().unwrap_or("").contains("missing"));
    }

    #[test]
    fn ffi_missing_database_is_unavailable_and_does_not_create_file() {
        let dir = TempDir::new().expect("temp dir");
        let db_path = dir.path().join("missing.sqlite");
        let c_path = CString::new(db_path.to_string_lossy().as_bytes()).expect("valid path");

        let decoded = decode_and_free(etl_queue_stats_json(c_path.as_ptr()));

        assert_eq!(decoded["available"], false);
        assert_eq!(decoded["total"], 0);
        assert!(
            !db_path.exists(),
            "diagnostic stats must not create the queue"
        );
    }

    #[test]
    fn ffi_existing_database_returns_pending_counts() {
        let dir = TempDir::new().expect("temp dir");
        let db_path = dir.path().join("etl.sqlite");
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");
        runtime
            .block_on(async {
                let queue = EtlQueue::open_at(&db_path).await?;
                queue
                    .enqueue_jobs([job("notes/a.md", 1), job("notes/b.md", 2)])
                    .await?;
                anyhow::Ok(())
            })
            .expect("queue seeded");
        drop(runtime);

        let c_path = CString::new(db_path.to_string_lossy().as_bytes()).expect("valid path");
        let decoded = decode_and_free(etl_queue_stats_json(c_path.as_ptr()));

        assert_eq!(decoded["available"], true);
        assert_eq!(decoded["total"], 2);
        assert_eq!(decoded["pending"], 2);
        assert_eq!(decoded["active"], 2);
        assert_eq!(decoded["completed"], 0);
    }

    #[test]
    fn ffi_enqueue_vault_walk_creates_queue_with_supported_files_only() {
        let dir = TempDir::new().expect("temp dir");
        std::fs::create_dir_all(dir.path().join("notes")).expect("notes dir");
        std::fs::write(dir.path().join("notes/a.md"), "alpha").expect("markdown");
        std::fs::write(dir.path().join("notes/b.txt"), "bravo").expect("text");
        std::fs::write(dir.path().join("notes/plugin.swift"), "struct Plugin {}").expect("source");
        let queue_path = dir.path().join(".epcache/etl/queue.sqlite");
        let c_vault = CString::new(dir.path().to_string_lossy().as_bytes()).expect("vault path");
        let c_queue = CString::new(queue_path.to_string_lossy().as_bytes()).expect("queue path");

        let decoded = decode_and_free(etl_enqueue_vault_walk_json(
            c_vault.as_ptr(),
            c_queue.as_ptr(),
        ));

        assert_eq!(decoded["available"], true);
        assert_eq!(decoded["total"], 2);
        assert_eq!(decoded["queued"], 2);
        assert_eq!(decoded["skipped"], 0);

        let c_queue = CString::new(queue_path.to_string_lossy().as_bytes()).expect("queue path");
        let stats = decode_and_free(etl_queue_stats_json(c_queue.as_ptr()));
        assert_eq!(stats["available"], true);
        assert_eq!(stats["pending"], 2);
        assert_eq!(stats["active"], 2);
    }

    #[test]
    fn ffi_run_worker_validates_and_completes_supported_jobs() {
        let dir = TempDir::new().expect("temp dir");
        std::fs::create_dir_all(dir.path().join("notes")).expect("notes dir");
        std::fs::write(dir.path().join("notes/a.md"), "alpha").expect("markdown");
        let queue_path = dir.path().join(".epcache/etl/queue.sqlite");
        let c_vault = CString::new(dir.path().to_string_lossy().as_bytes()).expect("vault path");
        let c_queue = CString::new(queue_path.to_string_lossy().as_bytes()).expect("queue path");

        let enqueued = decode_and_free(etl_enqueue_vault_walk_json(
            c_vault.as_ptr(),
            c_queue.as_ptr(),
        ));
        assert_eq!(enqueued["queued"], 1);

        let c_queue = CString::new(queue_path.to_string_lossy().as_bytes()).expect("queue path");
        let worker = decode_and_free(etl_run_worker_json(c_queue.as_ptr(), 4));

        assert_eq!(worker["available"], true);
        assert_eq!(worker["requested"], 1);
        assert_eq!(worker["attempted"], 1);
        assert_eq!(worker["succeeded"], 1);
        assert_eq!(worker["failed"], 0);
        assert_eq!(worker["pending_after"], 0);
        assert_eq!(worker["done_after"], 1);

        let c_queue = CString::new(queue_path.to_string_lossy().as_bytes()).expect("queue path");
        let stats = decode_and_free(etl_queue_stats_json(c_queue.as_ptr()));
        assert_eq!(stats["pending"], 0);
        assert_eq!(stats["done"], 1);
    }

    #[test]
    fn ffi_run_worker_fails_missing_or_mismatched_files_without_done() {
        let dir = TempDir::new().expect("temp dir");
        let db_path = dir.path().join("etl.sqlite");
        let stale_path = dir.path().join("notes/missing.md");
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");
        runtime
            .block_on(async {
                let queue = EtlQueue::open_at(&db_path).await?;
                queue
                    .enqueue_job(EtlIngestJob {
                        path: stale_path,
                        size_bytes: 12,
                        fingerprint: 42,
                        kind: EtlInputKind::Markdown,
                    })
                    .await?;
                anyhow::Ok(())
            })
            .expect("queue seeded");
        drop(runtime);

        let c_queue = CString::new(db_path.to_string_lossy().as_bytes()).expect("queue path");
        let worker = decode_and_free(etl_run_worker_json(c_queue.as_ptr(), 4));

        assert_eq!(worker["available"], true);
        assert_eq!(worker["attempted"], 1);
        assert_eq!(worker["succeeded"], 0);
        assert_eq!(worker["failed"], 1);
        assert_eq!(worker["done_after"], 0);
    }
}
