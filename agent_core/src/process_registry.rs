//! Process Registry — Background process tracking
//!
//! Reference: Hermes `tools/process_registry.py`
//! Tracks background processes spawned by bash/code_execution tools.
//! - Max 64 concurrent tracked processes (LRU eviction of finished)
//! - Rolling 200KB output buffer per process
//! - 30-minute TTL for finished processes (kept for polling)

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

/// Maximum tracked processes before LRU eviction.
const MAX_PROCESSES: usize = 64;

/// Maximum output buffer per process (200KB).
const MAX_OUTPUT_BYTES: usize = 200_000;

/// How long finished processes are kept for polling.
const FINISHED_TTL: Duration = Duration::from_secs(1800); // 30 minutes

/// Unique process identifier.
pub type ProcessId = String;

/// Status of a tracked process.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProcessStatus {
    Running,
    Finished { exit_code: Option<i32> },
}

/// A tracked process entry.
#[derive(Debug, Clone)]
pub struct ProcessEntry {
    pub id: ProcessId,
    pub command: String,
    pub cwd: String,
    pub pid: Option<u32>,
    pub status: ProcessStatus,
    pub started_at: Instant,
    pub finished_at: Option<Instant>,
    output_buffer: String,
}

impl ProcessEntry {
    fn new(id: ProcessId, command: String, cwd: String, pid: Option<u32>) -> Self {
        Self {
            id,
            command,
            cwd,
            pid,
            status: ProcessStatus::Running,
            started_at: Instant::now(),
            finished_at: None,
            output_buffer: String::new(),
        }
    }

    /// Append output to the rolling buffer. Truncates oldest content if over limit.
    fn append_output(&mut self, text: &str) {
        self.output_buffer.push_str(text);
        if self.output_buffer.len() > MAX_OUTPUT_BYTES {
            let excess = self.output_buffer.len() - MAX_OUTPUT_BYTES;
            // Find a safe char boundary to truncate at.
            let boundary = self.output_buffer[excess..]
                .char_indices()
                .next()
                .map(|(i, _)| excess + i)
                .unwrap_or(excess);
            self.output_buffer = format!(
                "[... {} bytes truncated ...]\n{}",
                boundary,
                &self.output_buffer[boundary..]
            );
        }
    }

    /// Get the current output buffer.
    fn output(&self) -> &str {
        &self.output_buffer
    }

    fn elapsed(&self) -> Duration {
        self.started_at.elapsed()
    }
}

/// Thread-safe process registry.
pub struct ProcessRegistry {
    inner: Mutex<RegistryInner>,
}

struct RegistryInner {
    running: HashMap<ProcessId, ProcessEntry>,
    finished: HashMap<ProcessId, ProcessEntry>,
    next_counter: u64,
}

impl ProcessRegistry {
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(RegistryInner {
                running: HashMap::new(),
                finished: HashMap::new(),
                next_counter: 1,
            }),
        }
    }

    /// Register a new background process. Returns its unique ID.
    pub fn register(&self, command: &str, cwd: &str, pid: Option<u32>) -> ProcessId {
        let mut inner = self.inner.lock().expect("process registry poisoned");

        // LRU eviction: remove oldest finished processes if at capacity.
        while inner.running.len() + inner.finished.len() >= MAX_PROCESSES {
            if let Some(oldest_id) = find_oldest_finished(&inner.finished) {
                inner.finished.remove(&oldest_id);
            } else {
                break;
            }
        }

        let id = format!("proc_{:012x}", inner.next_counter);
        inner.next_counter += 1;

        let entry = ProcessEntry::new(id.clone(), command.to_string(), cwd.to_string(), pid);
        inner.running.insert(id.clone(), entry);
        id
    }

    /// Append output to a process's rolling buffer.
    pub fn append_output(&self, id: &str, text: &str) {
        let mut inner = self.inner.lock().expect("process registry poisoned");
        if let Some(entry) = inner.running.get_mut(id) {
            entry.append_output(text);
        }
    }

    /// Mark a process as finished with an optional exit code.
    pub fn mark_finished(&self, id: &str, exit_code: Option<i32>) {
        let mut inner = self.inner.lock().expect("process registry poisoned");
        if let Some(mut entry) = inner.running.remove(id) {
            entry.status = ProcessStatus::Finished { exit_code };
            entry.finished_at = Some(Instant::now());
            inner.finished.insert(id.to_string(), entry);
        }
    }

    /// Get the current output buffer for a process.
    pub fn get_output(&self, id: &str) -> Option<String> {
        let inner = self.inner.lock().expect("process registry poisoned");
        inner
            .running
            .get(id)
            .or_else(|| inner.finished.get(id))
            .map(|e| e.output().to_string())
    }

    /// Get the status of a process.
    pub fn get_status(&self, id: &str) -> Option<ProcessStatus> {
        let inner = self.inner.lock().expect("process registry poisoned");
        inner
            .running
            .get(id)
            .or_else(|| inner.finished.get(id))
            .map(|e| e.status.clone())
    }

    /// List all tracked processes (running + recently finished).
    pub fn list(&self) -> Vec<ProcessSummary> {
        let inner = self.inner.lock().expect("process registry poisoned");
        let mut summaries = Vec::new();

        for entry in inner.running.values() {
            summaries.push(ProcessSummary {
                id: entry.id.clone(),
                command: entry.command.clone(),
                status: "running".to_string(),
                elapsed_secs: entry.elapsed().as_secs(),
                output_bytes: entry.output_buffer.len(),
            });
        }
        for entry in inner.finished.values() {
            let exit_str = match &entry.status {
                ProcessStatus::Finished { exit_code: Some(c) } => format!("exited({})", c),
                ProcessStatus::Finished { exit_code: None } => "exited(?)".to_string(),
                ProcessStatus::Running => "running".to_string(),
            };
            summaries.push(ProcessSummary {
                id: entry.id.clone(),
                command: entry.command.clone(),
                status: exit_str,
                elapsed_secs: entry.elapsed().as_secs(),
                output_bytes: entry.output_buffer.len(),
            });
        }

        summaries
    }

    /// Evict finished processes older than FINISHED_TTL.
    pub fn gc(&self) -> usize {
        let mut inner = self.inner.lock().expect("process registry poisoned");
        let before = inner.finished.len();
        inner.finished.retain(|_, entry| {
            entry.finished_at.map_or(true, |t| t.elapsed() < FINISHED_TTL)
        });
        before - inner.finished.len()
    }

    /// Kill a running process by sending SIGTERM (or SIGKILL if force=true).
    /// Returns true if the process was found and a signal was sent.
    #[cfg(unix)]
    pub fn kill(&self, id: &str, force: bool) -> bool {
        let inner = self.inner.lock().expect("process registry poisoned");
        if let Some(entry) = inner.running.get(id) {
            if let Some(pid) = entry.pid {
                let signal = if force {
                    libc::SIGKILL
                } else {
                    libc::SIGTERM
                };
                // SAFETY: Sending a signal to a known PID. The PID was obtained
                // from a process we spawned. Worst case: the process already exited
                // and the signal goes nowhere (kill returns -1 with ESRCH).
                let result = unsafe { libc::kill(pid as i32, signal) };
                return result == 0;
            }
        }
        false
    }

    /// Kill a running process (non-unix stub).
    #[cfg(not(unix))]
    pub fn kill(&self, _id: &str, _force: bool) -> bool {
        false
    }

    /// Check if a process is still alive by probing its PID.
    #[cfg(unix)]
    pub fn is_alive(&self, id: &str) -> bool {
        let inner = self.inner.lock().expect("process registry poisoned");
        if let Some(entry) = inner.running.get(id) {
            if let Some(pid) = entry.pid {
                // SAFETY: kill(pid, 0) checks if process exists without sending a signal.
                let result = unsafe { libc::kill(pid as i32, 0) };
                return result == 0;
            }
        }
        false
    }

    #[cfg(not(unix))]
    pub fn is_alive(&self, _id: &str) -> bool {
        false
    }

    /// Number of currently running processes.
    pub fn running_count(&self) -> usize {
        let inner = self.inner.lock().expect("process registry poisoned");
        inner.running.len()
    }

    /// Total tracked processes (running + finished).
    pub fn total_count(&self) -> usize {
        let inner = self.inner.lock().expect("process registry poisoned");
        inner.running.len() + inner.finished.len()
    }
}

/// Summary of a tracked process for listing.
#[derive(Debug, Clone)]
pub struct ProcessSummary {
    pub id: ProcessId,
    pub command: String,
    pub status: String,
    pub elapsed_secs: u64,
    pub output_bytes: usize,
}

fn find_oldest_finished(finished: &HashMap<ProcessId, ProcessEntry>) -> Option<ProcessId> {
    finished
        .values()
        .filter(|e| e.finished_at.is_some())
        .min_by_key(|e| e.finished_at.unwrap())
        .map(|e| e.id.clone())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn register_and_list() {
        let reg = ProcessRegistry::new();
        let id = reg.register("cargo test", "/tmp", Some(1234));
        assert!(id.starts_with("proc_"));

        let list = reg.list();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].status, "running");
        assert_eq!(reg.running_count(), 1);
    }

    #[test]
    fn append_and_get_output() {
        let reg = ProcessRegistry::new();
        let id = reg.register("echo hello", "/tmp", None);

        reg.append_output(&id, "hello world\n");
        reg.append_output(&id, "line 2\n");

        let output = reg.get_output(&id).unwrap();
        assert!(output.contains("hello world"));
        assert!(output.contains("line 2"));
    }

    #[test]
    fn output_buffer_rolling_truncation() {
        let reg = ProcessRegistry::new();
        let id = reg.register("long output", "/tmp", None);

        // Write more than MAX_OUTPUT_BYTES.
        let chunk = "x".repeat(10_000);
        for _ in 0..25 {
            reg.append_output(&id, &chunk);
        }

        let output = reg.get_output(&id).unwrap();
        assert!(output.len() <= MAX_OUTPUT_BYTES + 100); // +overhead for truncation message
        assert!(output.contains("truncated"));
    }

    #[test]
    fn mark_finished_moves_to_finished_list() {
        let reg = ProcessRegistry::new();
        let id = reg.register("quick job", "/tmp", Some(99));
        assert_eq!(reg.running_count(), 1);

        reg.mark_finished(&id, Some(0));
        assert_eq!(reg.running_count(), 0);
        assert_eq!(reg.total_count(), 1);

        let status = reg.get_status(&id).unwrap();
        assert_eq!(status, ProcessStatus::Finished { exit_code: Some(0) });
    }

    #[test]
    fn lru_eviction_at_capacity() {
        let reg = ProcessRegistry::new();

        // Fill to capacity with finished processes.
        for i in 0..MAX_PROCESSES {
            let id = reg.register(&format!("cmd {i}"), "/tmp", None);
            reg.mark_finished(&id, Some(0));
        }
        assert_eq!(reg.total_count(), MAX_PROCESSES);

        // Adding one more should evict the oldest finished.
        let _new_id = reg.register("overflow", "/tmp", None);
        assert!(reg.total_count() <= MAX_PROCESSES);
    }

    #[test]
    fn gc_removes_old_finished() {
        let reg = ProcessRegistry::new();
        let id = reg.register("old job", "/tmp", None);
        reg.mark_finished(&id, Some(0));

        // GC shouldn't remove it yet (just finished).
        let evicted = reg.gc();
        assert_eq!(evicted, 0);
        assert_eq!(reg.total_count(), 1);
    }

    #[test]
    fn nonexistent_process_returns_none() {
        let reg = ProcessRegistry::new();
        assert!(reg.get_output("proc_999").is_none());
        assert!(reg.get_status("proc_999").is_none());
    }
}
