// W9.27 — Append-only OpLog (event-sourced graph foundation)
//
// Per docs/RESEARCH_DOSSIER_TIER_3_4.md §W9.27: hand-roll the OpLog
// (NOT automerge/yrs/diamond-types — single-writer scope keeps the
// CRDT merge complexity unnecessary for V1).
//
// Schema: every mutation is an Op with (Lamport, actor_id, payload).
// Persisted to GRDB as `epistemos_oplog(seq INTEGER PRIMARY KEY,
// payload BLOB)`. Current state materializes via `Replay::fold(ops)`
// into the existing SDPage / SDGraphEdge projections.
//
// FOUNDATION: this module ships:
//   - the Op enum + serde wire format
//   - the OpLog handle with append + iterate APIs
//   - in-memory Vec<Op> backing for the v0 wiring
// The GRDB-backed persistent store and the Swift-side subscription
// stream land in subsequent commits per the dossier's PR plan.
//
// Wiring contract (additive — gated by EPISTEMOS_GRAPH_OPLOG flag):
//   - VaultIndexActor consumes OpLog::iter_after(last_seq) on startup
//     to materialize new ops into SwiftData.
//   - The flag mirrors the existing EPISTEMOS_GRAPH_INDEX_CHATS
//     rollback pattern so the OpLog can be killed without surgery.

use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::ffi::{c_char, CStr, CString};
use std::fs::{File, OpenOptions};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, MutexGuard};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "op_type", rename_all = "snake_case")]
pub enum OpPayload {
    NodeAdd { id: String, kind: String, title: String },
    NodeUpdate { id: String, title: Option<String> },
    NodeRemove { id: String },
    EdgeAdd { from: String, to: String, label: Option<String> },
    EdgeRemove { from: String, to: String },
    PropSet { node_id: String, key: String, value: serde_json::Value },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Op {
    pub seq: u64,
    pub lamport: u64,
    pub actor_id: String,
    pub ts_unix_ms: i64,
    pub payload: OpPayload,
}

#[derive(Debug, thiserror::Error)]
pub enum OpLogError {
    #[error("sqlite: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("serde: {0}")]
    Serde(#[from] serde_json::Error),
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Default)]
pub struct OpLog {
    inner: Mutex<OpLogInner>,
    actor_id: String,
    /// Optional persistent backing. When `Some`, every append also
    /// writes to SQLite; on startup, existing rows are replayed into
    /// `inner.ops` so the in-memory cache stays the canonical reader.
    /// When `None`, the OpLog is in-memory only (used by tests + the
    /// pre-PR2 callers).
    persistence: Option<Mutex<Connection>>,
    /// D5 — substrate durability discipline.
    ///
    /// Persistent file handle to the SQLite database file, opened
    /// once at `open_persistent` time and reused on every append.
    /// We use this to issue `F_FULLFSYNC` (Darwin) / `sync_all` (other
    /// platforms) after every INSERT so that bytes actually hit the
    /// disk platter before `append()` returns. Without this, macOS
    /// reports `fsync()` complete before the platter is updated, so a
    /// power loss can lose the last N writes — fatal for the OpLog
    /// because retraction propagation (doctrine §3) needs every commit
    /// durable across power loss.
    ///
    /// Held as an `Option<Mutex<File>>` to mirror `persistence` and
    /// keep the in-memory branch zero-cost.
    durability: Option<Mutex<File>>,
}

#[derive(Debug, Default)]
struct OpLogInner {
    next_seq: u64,
    next_lamport: u64,
    ops: Vec<Op>,
}

impl OpLog {
    pub fn new(actor_id: impl Into<String>) -> Self {
        Self {
            inner: Mutex::new(OpLogInner::default()),
            actor_id: actor_id.into(),
            persistence: None,
            durability: None,
        }
    }

    /// W9.27 PR2 — open or create a SQLite-backed persistent OpLog at
    /// `db_path`. Existing rows are loaded into the in-memory cache at
    /// startup so subsequent reads are O(1) (Vec walk) and writes are
    /// O(log n) (BTreeMap inside SQLite).
    ///
    /// Schema (created if missing):
    ///   CREATE TABLE epistemos_oplog (
    ///     seq INTEGER PRIMARY KEY,
    ///     lamport INTEGER NOT NULL,
    ///     actor_id TEXT NOT NULL,
    ///     ts_unix_ms INTEGER NOT NULL,
    ///     payload BLOB NOT NULL  -- serde_json bytes
    ///   )
    ///
    /// The schema name is deliberately stable (`epistemos_oplog`)
    /// matching the dossier's contract — same name as the OpLog
    /// reader on the Swift side will eventually look for.
    ///
    /// Per CLAUDE.md DO NOT list: this uses serde_json (not Debug
    /// format) for payload serialization. The `payload` BLOB column
    /// stores `serde_json::to_vec(&op.payload)` bytes.
    pub fn open_persistent(
        actor_id: impl Into<String>,
        db_path: impl AsRef<Path>,
    ) -> Result<Self, OpLogError> {
        let path: PathBuf = db_path.as_ref().to_path_buf();
        let conn = Connection::open(&path)?;
        // D5 — substrate durability discipline. WAL keeps writers and
        // readers from blocking each other (rollback-journal mode is
        // the rusqlite default and is the wrong choice for an event
        // log). `synchronous=FULL` makes SQLite call fsync after every
        // commit. `foreign_keys=ON` matches the rest of the substrate
        // (we don't currently have FK constraints in the schema, but
        // future migrations should be able to assume it).
        //
        // Order matters: journal_mode must be set before any write to
        // upgrade the file format; SQLite ignores subsequent attempts
        // if the journal is already initialized in the legacy mode.
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "FULL")?;
        conn.pragma_update(None, "foreign_keys", "ON")?;
        Self::init_schema(&conn)?;

        let mut inner = OpLogInner::default();
        Self::load_existing(&conn, &mut inner)?;

        // D5 — open the database file once for F_FULLFSYNC use. We
        // keep this handle alive for the lifetime of the OpLog instead
        // of reopening on every append (the alternative path), because
        // every append is on the hot retraction-propagation loop and
        // open()/close() are non-trivial syscalls.
        let durability_file = OpenOptions::new().write(true).open(&path)?;

        Ok(Self {
            inner: Mutex::new(inner),
            actor_id: actor_id.into(),
            persistence: Some(Mutex::new(conn)),
            durability: Some(Mutex::new(durability_file)),
        })
    }

    /// D5 — issue F_FULLFSYNC on Darwin (forces bytes to platter, not
    /// just to the drive's write cache) or `sync_all` elsewhere.
    /// Called after every INSERT in `append()`.
    fn full_fsync(&self) -> std::io::Result<()> {
        let Some(file_mutex) = self.durability.as_ref() else {
            return Ok(());
        };
        let file = file_mutex.lock().unwrap_or_else(|e| e.into_inner());
        Self::full_fsync_file(&file)
    }

    fn full_fsync_file(file: &File) -> std::io::Result<()> {
        #[cfg(target_vendor = "apple")]
        {
            use std::os::unix::io::AsRawFd;
            // SAFETY: file is borrowed for the duration of the call;
            // F_FULLFSYNC is documented to take a single i32 (cmd) and
            // a single argument (here `0`, ignored). Returns 0 on
            // success or -1 with errno set.
            let rc = unsafe { libc::fcntl(file.as_raw_fd(), libc::F_FULLFSYNC, 0) };
            if rc == -1 {
                // Fall back to sync_all on F_FULLFSYNC failure (some
                // filesystems — exFAT, network mounts — don't support
                // it and return ENOTSUP / EINVAL). sync_all is at
                // least as strong as fsync().
                return file.sync_all();
            }
            Ok(())
        }
        #[cfg(not(target_vendor = "apple"))]
        {
            file.sync_all()
        }
    }

    fn init_schema(conn: &Connection) -> Result<(), rusqlite::Error> {
        conn.execute(
            "CREATE TABLE IF NOT EXISTS epistemos_oplog (
                seq INTEGER PRIMARY KEY,
                lamport INTEGER NOT NULL,
                actor_id TEXT NOT NULL,
                ts_unix_ms INTEGER NOT NULL,
                payload BLOB NOT NULL
            )",
            [],
        )?;
        Ok(())
    }

    fn load_existing(
        conn: &Connection,
        inner: &mut OpLogInner,
    ) -> Result<(), OpLogError> {
        let mut stmt = conn.prepare(
            "SELECT seq, lamport, actor_id, ts_unix_ms, payload
             FROM epistemos_oplog
             ORDER BY seq ASC",
        )?;
        let rows = stmt.query_map([], |row| {
            let seq: i64 = row.get(0)?;
            let lamport: i64 = row.get(1)?;
            let actor_id: String = row.get(2)?;
            let ts_unix_ms: i64 = row.get(3)?;
            let payload_bytes: Vec<u8> = row.get(4)?;
            Ok((seq as u64, lamport as u64, actor_id, ts_unix_ms, payload_bytes))
        })?;

        let mut max_seq: i128 = -1;
        let mut max_lamport: i128 = -1;
        for r in rows {
            let (seq, lamport, actor_id, ts_unix_ms, payload_bytes) = r?;
            let payload: OpPayload = serde_json::from_slice(&payload_bytes)?;
            if seq as i128 > max_seq {
                max_seq = seq as i128;
            }
            if lamport as i128 > max_lamport {
                max_lamport = lamport as i128;
            }
            inner.ops.push(Op {
                seq,
                lamport,
                actor_id,
                ts_unix_ms,
                payload,
            });
        }
        inner.next_seq = if max_seq < 0 { 0 } else { (max_seq as u64) + 1 };
        inner.next_lamport = if max_lamport < 0 {
            0
        } else {
            (max_lamport as u64) + 1
        };
        Ok(())
    }

    /// Appends a single payload and returns the assigned sequence number.
    /// Persists to SQLite if `open_persistent` was used.
    pub fn append(&self, payload: OpPayload) -> u64 {
        let now = chrono::Utc::now().timestamp_millis();
        let mut inner = self.lock();
        let seq = inner.next_seq;
        let lamport = inner.next_lamport;
        inner.next_seq = inner.next_seq.saturating_add(1);
        inner.next_lamport = inner.next_lamport.saturating_add(1);

        let op = Op {
            seq,
            lamport,
            actor_id: self.actor_id.clone(),
            ts_unix_ms: now,
            payload,
        };

        // Persist BEFORE pushing to in-memory cache so a SQLite failure
        // doesn't leave a phantom op in memory. Best-effort logging on
        // persistence failure — the caller has no graceful recovery
        // path mid-append, and the in-memory cache is still usable.
        if let Some(conn_mutex) = &self.persistence {
            if let Ok(payload_bytes) = serde_json::to_vec(&op.payload) {
                if let Ok(conn) = conn_mutex.lock() {
                    let insert_rc = conn.execute(
                        "INSERT INTO epistemos_oplog
                         (seq, lamport, actor_id, ts_unix_ms, payload)
                         VALUES (?, ?, ?, ?, ?)",
                        params![
                            op.seq as i64,
                            op.lamport as i64,
                            &op.actor_id,
                            op.ts_unix_ms,
                            payload_bytes,
                        ],
                    );
                    // D5 — only F_FULLFSYNC when the INSERT actually
                    // landed. If SQLite errored mid-INSERT there's
                    // nothing on the platter to flush; skipping the
                    // sync avoids touching unrelated WAL frames from
                    // an earlier transaction we don't own.
                    if insert_rc.is_ok() {
                        let _ = self.full_fsync();
                    }
                }
            }
        }

        inner.ops.push(op);
        seq
    }

    /// Returns the ops with seq > `after_seq` in append order.
    /// Used by the Swift mirror (VaultIndexActor) to catch up from
    /// last-seen seq.
    pub fn iter_after(&self, after_seq: u64) -> Vec<Op> {
        let inner = self.lock();
        inner
            .ops
            .iter()
            .filter(|op| op.seq > after_seq)
            .cloned()
            .collect()
    }

    /// Total op count — useful for snapshot-cadence policies.
    pub fn len(&self) -> usize {
        self.lock().ops.len()
    }

    pub fn is_empty(&self) -> bool {
        self.lock().ops.is_empty()
    }

    /// Replay the entire log via the provided fold function. Caller
    /// supplies the materializer (typically an SDPage / SDGraphEdge
    /// projection accumulator) so this module stays decoupled from
    /// the storage layer.
    pub fn replay<S, F>(&self, init: S, mut fold: F) -> S
    where
        F: FnMut(S, &Op) -> S,
    {
        let inner = self.lock();
        inner.ops.iter().fold(init, |acc, op| fold(acc, op))
    }

    fn lock(&self) -> MutexGuard<'_, OpLogInner> {
        self.inner.lock().unwrap_or_else(|e| e.into_inner())
    }
}

// MARK: - W9.27 PR3 — extern "C" FFI exports for the Swift OpLogFFIClient
//
// Mirrors the W9.21 honest-FFI pattern + W9.26 rope_handle.rs lifecycle:
//   - `Arc::into_raw` / `Arc::decrement_strong_count` for refcount
//   - JSON wire format (serde_json::to_string of `Vec<Op>`) — keeps the
//     Swift side decoder-agnostic and reuses the existing Codable mirror
//   - Out-param error code: 0 = success, 1 = null handle,
//     2 = serialization failure
//
// Per CLAUDE.md "DO NOT" list: serde_json (not Debug `{:?}`) is the
// only acceptable JSON wire format here — every Op payload variant is
// already `#[derive(Serialize, Deserialize)]`.
//
// Why we don't return a Vec<Op> across FFI: there's no stable Rust
// ABI for slices of complex types. JSON is the path of least
// resistance, mirrors the existing OpPayload tagged-union encoding,
// and keeps the Swift side a `JSONDecoder().decode([Op].self, …)`
// one-liner.

/// Open or create a SQLite-backed `OpLog` at `path` and return an
/// `Arc::into_raw` handle. Returns null on any failure (path invalid,
/// SQLite open failure, schema migration failure).
///
/// # Safety
/// `path` must be a valid null-terminated UTF-8 C string pointing at a
/// writable filesystem location. `actor_id` must be a valid
/// null-terminated UTF-8 C string. Caller must release exactly once
/// via `oplog_release`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn oplog_open_at(
    path: *const c_char,
    actor_id: *const c_char,
) -> *const OpLog {
    let result = std::panic::catch_unwind(|| {
        if path.is_null() || actor_id.is_null() {
            return std::ptr::null();
        }
        // SAFETY: caller contract — both pointers are null-terminated UTF-8.
        let path_cstr = unsafe { CStr::from_ptr(path) };
        let actor_cstr = unsafe { CStr::from_ptr(actor_id) };
        let Ok(path_str) = path_cstr.to_str() else {
            return std::ptr::null();
        };
        let Ok(actor_str) = actor_cstr.to_str() else {
            return std::ptr::null();
        };
        match OpLog::open_persistent(actor_str, path_str) {
            Ok(log) => Arc::into_raw(Arc::new(log)),
            Err(_) => std::ptr::null(),
        }
    });
    result.unwrap_or(std::ptr::null())
}

/// Iterate ops with seq > `after_seq`, serialize as a JSON array of
/// `Op`, and return a heap-allocated null-terminated UTF-8 C string.
/// Caller must free via `oplog_free_string`.
///
/// On any failure the return is null and `*out_error` is set
/// (1 = null handle, 2 = serialization failure). On success
/// `*out_error` is 0 and the return is non-null. An empty result set
/// returns a non-null `"[]"` string with `*out_error = 0`.
///
/// # Safety
/// `handle` must be a live `OpLog` pointer or null. `out_error` must
/// be a valid `*mut i32` (typically the address of a Swift `Int32`).
#[unsafe(no_mangle)]
pub unsafe extern "C" fn oplog_iter_after_json(
    handle: *const OpLog,
    after_seq: u64,
    out_error: *mut i32,
) -> *mut c_char {
    let set_err = |code: i32| {
        if !out_error.is_null() {
            // SAFETY: caller contract — out_error is writable.
            unsafe { *out_error = code };
        }
    };
    let result = std::panic::catch_unwind(|| {
        if handle.is_null() {
            set_err(1);
            return std::ptr::null_mut();
        }
        // SAFETY: caller contract — handle is a live OpLog pointer.
        let log = unsafe { &*handle };
        let ops = log.iter_after(after_seq);
        let json = match serde_json::to_string(&ops) {
            Ok(s) => s,
            Err(_) => {
                set_err(2);
                return std::ptr::null_mut();
            }
        };
        match CString::new(json) {
            Ok(c) => {
                set_err(0);
                c.into_raw()
            }
            Err(_) => {
                set_err(2);
                std::ptr::null_mut()
            }
        }
    });
    result.unwrap_or_else(|_| {
        set_err(2);
        std::ptr::null_mut()
    })
}

/// Decrement the OpLog handle's refcount. Drops the OpLog (and closes
/// the SQLite connection) at zero. Idempotent on null.
///
/// # Safety
/// `handle` must be a live `OpLog` pointer previously returned by
/// `oplog_open_at`, or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn oplog_release(handle: *const OpLog) {
    if !handle.is_null() {
        // SAFETY: caller contract — exactly-balanced retain/release.
        unsafe {
            Arc::decrement_strong_count(handle);
        }
    }
}

/// Free a string previously returned by `oplog_iter_after_json`.
/// Idempotent on null.
///
/// # Safety
/// `s` must be a pointer returned by `oplog_iter_after_json` and not
/// yet freed.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn oplog_free_string(s: *mut c_char) {
    if !s.is_null() {
        // SAFETY: caller contract — s came from CString::into_raw.
        unsafe {
            drop(CString::from_raw(s));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn append_assigns_monotonic_seq() {
        let log = OpLog::new("test");
        let s1 = log.append(OpPayload::NodeAdd {
            id: "n1".into(),
            kind: "page".into(),
            title: "First".into(),
        });
        let s2 = log.append(OpPayload::NodeAdd {
            id: "n2".into(),
            kind: "page".into(),
            title: "Second".into(),
        });
        assert_eq!(s1, 0);
        assert_eq!(s2, 1);
        assert_eq!(log.len(), 2);
    }

    #[test]
    fn iter_after_filters_correctly() {
        let log = OpLog::new("test");
        for i in 0..5 {
            log.append(OpPayload::NodeAdd {
                id: format!("n{i}"),
                kind: "page".into(),
                title: format!("Page {i}"),
            });
        }
        let tail = log.iter_after(2);
        assert_eq!(tail.len(), 2);
        assert_eq!(tail[0].seq, 3);
        assert_eq!(tail[1].seq, 4);
    }

    #[test]
    fn replay_folds_state() {
        let log = OpLog::new("test");
        log.append(OpPayload::NodeAdd {
            id: "n1".into(),
            kind: "page".into(),
            title: "A".into(),
        });
        log.append(OpPayload::NodeRemove { id: "n1".into() });
        let count = log.replay(0, |acc, op| match op.payload {
            OpPayload::NodeAdd { .. } => acc + 1,
            OpPayload::NodeRemove { .. } => acc - 1,
            _ => acc,
        });
        assert_eq!(count, 0);
    }

    #[test]
    fn payload_serializes_compactly() {
        let payload = OpPayload::PropSet {
            node_id: "n1".into(),
            key: "tags".into(),
            value: serde_json::json!(["alpha", "beta"]),
        };
        let json = serde_json::to_string(&payload).unwrap();
        assert!(json.contains("\"op_type\":\"prop_set\""));
        assert!(json.contains("\"node_id\":\"n1\""));
    }

    // MARK: - W9.27 PR2 — GRDB persistence tests

    fn temp_db_path(name: &str) -> std::path::PathBuf {
        let mut p = std::env::temp_dir();
        p.push(format!("epistemos-oplog-{name}-{}.sqlite", uuid::Uuid::new_v4()));
        p
    }

    #[test]
    fn persistent_open_creates_schema() {
        let path = temp_db_path("schema");
        let log = OpLog::open_persistent("test", &path).unwrap();
        assert!(log.is_empty());
        // File exists post-open even though no ops were appended.
        assert!(path.exists());
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn persistent_append_round_trips_via_reopen() {
        let path = temp_db_path("roundtrip");
        {
            let log = OpLog::open_persistent("actor-A", &path).unwrap();
            let s1 = log.append(OpPayload::NodeAdd {
                id: "n1".into(),
                kind: "page".into(),
                title: "First".into(),
            });
            let s2 = log.append(OpPayload::EdgeAdd {
                from: "n1".into(),
                to: "n2".into(),
                label: Some("links_to".into()),
            });
            assert_eq!(s1, 0);
            assert_eq!(s2, 1);
        } // log + connection drop here

        // Reopen — should restore the same ops.
        let reopened = OpLog::open_persistent("actor-A", &path).unwrap();
        assert_eq!(reopened.len(), 2);
        let tail = reopened.iter_after(0);
        assert_eq!(tail.len(), 1);
        assert_eq!(tail[0].seq, 1);
        match &tail[0].payload {
            OpPayload::EdgeAdd { from, to, label } => {
                assert_eq!(from, "n1");
                assert_eq!(to, "n2");
                assert_eq!(label.as_deref(), Some("links_to"));
            }
            _ => panic!("expected EdgeAdd payload"),
        }

        // Next append continues from the reloaded counter.
        let s3 = reopened.append(OpPayload::NodeRemove { id: "n1".into() });
        assert_eq!(s3, 2);

        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn persistent_lamport_counter_resumes() {
        let path = temp_db_path("lamport");
        {
            let log = OpLog::open_persistent("actor-A", &path).unwrap();
            for i in 0..3 {
                log.append(OpPayload::NodeAdd {
                    id: format!("n{i}"),
                    kind: "page".into(),
                    title: format!("Title {i}"),
                });
            }
        }
        let reopened = OpLog::open_persistent("actor-A", &path).unwrap();
        // After 3 appends with lamports 0,1,2 — next append must be 3.
        let s = reopened.append(OpPayload::NodeRemove { id: "n0".into() });
        assert_eq!(s, 3);
        let tail = reopened.iter_after(2);
        assert_eq!(tail.len(), 1);
        assert_eq!(tail[0].lamport, 3);
        let _ = std::fs::remove_file(&path);
    }

    // MARK: - D5 substrate durability discipline tests

    #[test]
    fn open_persistent_uses_wal_journal_mode() {
        let path = temp_db_path("wal-mode");
        let oplog = OpLog::open_persistent("test", &path).unwrap();
        let conn = oplog.persistence.as_ref().unwrap().lock().unwrap();
        let mode: String = conn
            .pragma_query_value(None, "journal_mode", |r| r.get(0))
            .unwrap();
        assert_eq!(mode.to_lowercase(), "wal");
        drop(conn);
        drop(oplog);
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn open_persistent_uses_synchronous_full() {
        let path = temp_db_path("sync-full");
        let oplog = OpLog::open_persistent("test", &path).unwrap();
        let conn = oplog.persistence.as_ref().unwrap().lock().unwrap();
        let sync: i32 = conn
            .pragma_query_value(None, "synchronous", |r| r.get(0))
            .unwrap();
        assert_eq!(sync, 2); // FULL = 2
        drop(conn);
        drop(oplog);
        let _ = std::fs::remove_file(&path);
    }
}
