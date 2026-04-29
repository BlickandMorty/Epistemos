//! Append-only event log with BLAKE3 content-hash chain (S2;
//! DOCTRINE I-3 / I-4 / I-13 / IMPLEMENTATION §3-S2).
//!
//! Persists `AgentEvent` values to a JSONL file with `fsync` after
//! every line. Each entry carries a sequence number, a timestamp,
//! the BLAKE3 hash of the previous entry's full bytes, and the
//! event payload. External truncation or modification breaks the
//! hash chain; `verify_integrity()` detects it. The reducer only
//! ever reads `LogEntry { ts, event, .. }` — system clocks never
//! enter the reducer per I-13.
//!
//! Log line format (one JSON object per line, no trailing comma):
//!
//!   {"seq":N,"ts":"<rfc3339>","prev_hash":"<hex64>","event":<AgentEvent>}
//!
//! `prev_hash` for the first line is the all-zero hash. The hash
//! chain is computed over the canonical JSON bytes of each line up
//! to and including the trailing newline.

use std::fs::{File, OpenOptions};
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::events::{AgentEvent, Blake3Hash};

/// Errors emitted by the event log.
#[derive(Debug, thiserror::Error)]
pub enum EventLogError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("serde: {0}")]
    Serde(#[from] serde_json::Error),
    #[error("integrity: {message} at line {line}")]
    Integrity { line: u64, message: String },
}

/// One persisted log entry. The `event` is the canonical
/// `AgentEvent`; `prev_hash` chains to the previous entry; `seq` is
/// 1-indexed. `ts` is RFC3339 — timestamps are attached by the
/// log writer at append time and are the only legitimate source of
/// time for the reducer per I-13.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LogEntry {
    pub seq: u64,
    pub ts: String,
    pub prev_hash: Blake3Hash,
    pub event: AgentEvent,
}

/// Append-only handle over a single log file. Single-writer; if
/// concurrent writers are needed, wrap in a `Mutex` at the
/// owner layer (the simulation's writer thread holds it
/// exclusively).
#[derive(Debug)]
pub struct EventLog {
    path: PathBuf,
    file: File,
    /// Hash of the most recently appended entry's bytes (including
    /// its trailing newline). For an empty log this is `Blake3Hash::ZERO`.
    last_hash: Blake3Hash,
    seq: u64,
}

impl EventLog {
    /// Open or create the log at `path`. Existing entries are
    /// scanned to recover `seq` and `last_hash`. The chain is
    /// validated as part of recovery — any mismatch returns
    /// `EventLogError::Integrity`.
    pub fn open(path: &Path) -> Result<Self, EventLogError> {
        if let Some(parent) = path.parent() {
            if !parent.as_os_str().is_empty() {
                std::fs::create_dir_all(parent)?;
            }
        }

        // First pass: validate + recover state from any existing log.
        let (seq, last_hash) = if path.exists() {
            recover_state(path)?
        } else {
            (0, Blake3Hash::ZERO)
        };

        let file = OpenOptions::new()
            .create(true)
            .append(true)
            .read(true)
            .open(path)?;

        Ok(Self {
            path: path.to_owned(),
            file,
            last_hash,
            seq,
        })
    }

    /// Path to the underlying file.
    pub fn path(&self) -> &Path {
        &self.path
    }

    /// Highest seq written so far.
    pub fn current_seq(&self) -> u64 {
        self.seq
    }

    /// Most recent chain hash; the hash to use as `prev_hash` for
    /// the next append.
    pub fn current_hash(&self) -> Blake3Hash {
        self.last_hash
    }

    /// Append `event` with a caller-supplied timestamp. Returns the
    /// new sequence number. `fsync` runs before this returns so
    /// crash recovery sees a durable entry.
    pub fn append(
        &mut self,
        event: &AgentEvent,
        ts: chrono::DateTime<chrono::Utc>,
    ) -> Result<u64, EventLogError> {
        let entry = LogEntry {
            seq: self.seq + 1,
            ts: ts.to_rfc3339_opts(chrono::SecondsFormat::Millis, true),
            prev_hash: self.last_hash,
            event: event.clone(),
        };
        let line = serialise_line(&entry)?;
        let new_hash = Blake3Hash::of(line.as_bytes());

        self.file.write_all(line.as_bytes())?;
        self.file.sync_data()?;

        self.seq = entry.seq;
        self.last_hash = new_hash;
        Ok(entry.seq)
    }

    /// Convenience: append with the current wall-clock UTC. Used at
    /// the writer boundary; the reducer never calls this — it
    /// reads back the persisted `ts` from `LogEntry`.
    pub fn append_now(&mut self, event: &AgentEvent) -> Result<u64, EventLogError> {
        self.append(event, chrono::Utc::now())
    }

    /// Stream every entry from the start of the log in order. The
    /// caller is responsible for re-applying them via the reducer.
    pub fn iter(&self) -> Result<EventLogIter, EventLogError> {
        let f = File::open(&self.path)?;
        Ok(EventLogIter {
            reader: BufReader::new(f),
            line_no: 0,
        })
    }

    /// Read every entry into a Vec. Convenience for tests and
    /// integrity checks; large logs should prefer `iter()`.
    pub fn read_all(&self) -> Result<Vec<LogEntry>, EventLogError> {
        let mut out = Vec::new();
        for entry in self.iter()? {
            out.push(entry?);
        }
        Ok(out)
    }

    /// Verify the on-disk hash chain end-to-end. Returns
    /// `EventLogError::Integrity` on any break: missing prev_hash,
    /// truncation, or mid-stream tampering.
    pub fn verify_integrity(&self) -> Result<(), EventLogError> {
        verify_chain(&self.path).map(|_| ())
    }
}

/// Iterator over `LogEntry` values in the log. Yields a
/// `Result<LogEntry, EventLogError>` so the caller can stop on the
/// first decode error.
pub struct EventLogIter {
    reader: BufReader<File>,
    line_no: u64,
}

impl Iterator for EventLogIter {
    type Item = Result<LogEntry, EventLogError>;
    fn next(&mut self) -> Option<Self::Item> {
        let mut line = String::new();
        match self.reader.read_line(&mut line) {
            Ok(0) => None,
            Ok(_) => {
                self.line_no += 1;
                let trimmed = line.trim_end_matches('\n').trim_end_matches('\r');
                Some(serde_json::from_str::<LogEntry>(trimmed).map_err(EventLogError::from))
            }
            Err(e) => Some(Err(EventLogError::Io(e))),
        }
    }
}

// =============================================================================
// Helpers.
// =============================================================================

fn serialise_line(entry: &LogEntry) -> Result<String, EventLogError> {
    let mut s = serde_json::to_string(entry)?;
    s.push('\n');
    Ok(s)
}

/// Recover (seq, last_hash) by scanning the existing log file and
/// validating the full chain. Returns `(0, ZERO)` for a 0-byte file.
fn recover_state(path: &Path) -> Result<(u64, Blake3Hash), EventLogError> {
    let f = File::open(path)?;
    let len = f.metadata()?.len();
    if len == 0 {
        return Ok((0, Blake3Hash::ZERO));
    }
    let (seq, last_hash) = verify_chain(path)?;
    Ok((seq, last_hash))
}

/// Walk the log file, validating the hash chain entry-by-entry.
/// Returns `(last_seq, last_hash)` on success.
fn verify_chain(path: &Path) -> Result<(u64, Blake3Hash), EventLogError> {
    let f = File::open(path)?;
    let mut reader = BufReader::new(f);
    let mut line = String::new();
    let mut line_no: u64 = 0;
    let mut prev_hash = Blake3Hash::ZERO;
    let mut last_seq: u64 = 0;

    loop {
        line.clear();
        let read = reader.read_line(&mut line)?;
        if read == 0 {
            break;
        }
        line_no += 1;

        // Empty / whitespace lines are not allowed.
        if line.trim().is_empty() {
            return Err(EventLogError::Integrity {
                line: line_no,
                message: "blank line".to_string(),
            });
        }

        // Decode and validate sequence + prev_hash.
        let trimmed = line.trim_end_matches('\n').trim_end_matches('\r');
        let entry: LogEntry =
            serde_json::from_str(trimmed).map_err(EventLogError::from)?;

        if entry.seq != last_seq + 1 {
            return Err(EventLogError::Integrity {
                line: line_no,
                message: format!(
                    "out-of-order seq: expected {}, got {}",
                    last_seq + 1,
                    entry.seq
                ),
            });
        }
        if entry.prev_hash != prev_hash {
            return Err(EventLogError::Integrity {
                line: line_no,
                message: format!(
                    "prev_hash mismatch: expected {}, got {}",
                    prev_hash.to_hex(),
                    entry.prev_hash.to_hex()
                ),
            });
        }

        prev_hash = Blake3Hash::of(line.as_bytes());
        last_seq = entry.seq;
    }

    Ok((last_seq, prev_hash))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::companions::CompanionId;
    use crate::events::{MessageId, SessionId, SessionMode};
    use std::io::{Read, Seek, SeekFrom};

    fn fixture_event(label: &str) -> AgentEvent {
        AgentEvent::MessageDelta {
            message_id: MessageId::new(label),
            delta: format!("delta for {label}"),
        }
    }

    fn cid() -> CompanionId {
        CompanionId::new_ulid()
    }

    #[test]
    fn fresh_log_has_zero_seq() {
        let tmp = tempfile::tempdir().unwrap();
        let log = EventLog::open(&tmp.path().join("events.jsonl")).unwrap();
        assert_eq!(log.current_seq(), 0);
        assert_eq!(log.current_hash(), Blake3Hash::ZERO);
    }

    #[test]
    fn append_increments_seq_and_advances_chain() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("events.jsonl");
        let mut log = EventLog::open(&path).unwrap();
        let _seq1 = log.append_now(&fixture_event("a")).unwrap();
        let h1 = log.current_hash();
        let _seq2 = log.append_now(&fixture_event("b")).unwrap();
        let h2 = log.current_hash();

        assert_eq!(log.current_seq(), 2);
        assert_ne!(h1, Blake3Hash::ZERO);
        assert_ne!(h1, h2);

        // Read back: two entries, chain consistent.
        let entries = log.read_all().unwrap();
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].seq, 1);
        assert_eq!(entries[0].prev_hash, Blake3Hash::ZERO);
        assert_eq!(entries[1].seq, 2);
        assert_eq!(entries[1].prev_hash, h1);
        assert_eq!(entries[1].prev_hash.to_hex().len(), 64);
    }

    #[test]
    fn reopening_recovers_state() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("events.jsonl");
        let h_after_two = {
            let mut log = EventLog::open(&path).unwrap();
            log.append_now(&fixture_event("one")).unwrap();
            log.append_now(&fixture_event("two")).unwrap();
            log.current_hash()
        };
        // Re-open: state recovered from disk.
        let log2 = EventLog::open(&path).unwrap();
        assert_eq!(log2.current_seq(), 2);
        assert_eq!(log2.current_hash(), h_after_two);
        // And subsequent append continues the chain cleanly.
        let mut log2 = log2;
        let h_before_three = log2.current_hash();
        log2.append_now(&fixture_event("three")).unwrap();
        let entries = log2.read_all().unwrap();
        assert_eq!(entries.len(), 3);
        assert_eq!(entries[2].prev_hash, h_before_three);
    }

    #[test]
    fn verify_integrity_passes_on_clean_log() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("events.jsonl");
        let mut log = EventLog::open(&path).unwrap();
        for i in 0..5 {
            log.append_now(&fixture_event(&format!("e{i}"))).unwrap();
        }
        log.verify_integrity().unwrap();
    }

    #[test]
    fn verify_integrity_detects_truncation() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("events.jsonl");
        let mut log = EventLog::open(&path).unwrap();
        for i in 0..5 {
            log.append_now(&fixture_event(&format!("e{i}"))).unwrap();
        }
        drop(log);

        // Truncate the file to a partial line in the middle.
        let mut f = OpenOptions::new()
            .read(true)
            .write(true)
            .open(&path)
            .unwrap();
        let mut all = String::new();
        f.read_to_string(&mut all).unwrap();
        let halfway = all.len() / 2;
        // Cut at the halfway point — likely mid-line, breaking JSON.
        f.set_len(halfway as u64).unwrap();
        f.seek(SeekFrom::Start(0)).unwrap();

        // Recovery / verify must surface integrity error.
        match EventLog::open(&path) {
            Err(EventLogError::Integrity { .. }) | Err(EventLogError::Serde(_)) => {}
            other => panic!("expected integrity / serde error, got {other:?}"),
        }
    }

    #[test]
    fn verify_integrity_detects_mid_chain_modification() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("events.jsonl");
        let mut log = EventLog::open(&path).unwrap();
        for i in 0..3 {
            log.append_now(&fixture_event(&format!("e{i}"))).unwrap();
        }
        drop(log);

        // Modify a byte in the middle of the file (changes content
        // but preserves byte length, breaking the hash of that line
        // which the next line's prev_hash references).
        let mut buf = std::fs::read(&path).unwrap();
        // Find the second line's "delta" payload and mutate one
        // character.
        let pos = buf
            .windows(7)
            .position(|w| w == b"delta f")
            .expect("payload marker present");
        buf[pos + 6] = b'X';
        std::fs::write(&path, &buf).unwrap();

        // Reopen → integrity break.
        match EventLog::open(&path) {
            Err(EventLogError::Integrity { .. }) => {}
            other => panic!("expected integrity error, got {other:?}"),
        }
    }

    #[test]
    fn read_all_yields_entries_in_seq_order() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("events.jsonl");
        let mut log = EventLog::open(&path).unwrap();
        let alice = cid();
        log.append_now(&AgentEvent::SessionStarted {
            session_id: SessionId::new("s1"),
            mode: SessionMode::Chat,
        })
        .unwrap();
        log.append_now(&AgentEvent::ParticipantJoined {
            agent_id: alice,
            role: crate::companions::ProviderRole::CodeWorker,
        })
        .unwrap();
        let all = log.read_all().unwrap();
        assert_eq!(all[0].seq, 1);
        assert_eq!(all[1].seq, 2);
        assert!(matches!(all[0].event, AgentEvent::SessionStarted { .. }));
        assert!(matches!(all[1].event, AgentEvent::ParticipantJoined { .. }));
    }
}
