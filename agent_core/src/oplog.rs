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

use serde::{Deserialize, Serialize};
use std::sync::{Mutex, MutexGuard};

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

#[derive(Debug, Default)]
pub struct OpLog {
    inner: Mutex<OpLogInner>,
    actor_id: String,
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
        }
    }

    /// Appends a single payload and returns the assigned sequence number.
    pub fn append(&self, payload: OpPayload) -> u64 {
        let now = chrono::Utc::now().timestamp_millis();
        let mut inner = self.lock();
        let seq = inner.next_seq;
        let lamport = inner.next_lamport;
        inner.next_seq = inner.next_seq.saturating_add(1);
        inner.next_lamport = inner.next_lamport.saturating_add(1);
        inner.ops.push(Op {
            seq,
            lamport,
            actor_id: self.actor_id.clone(),
            ts_unix_ms: now,
            payload,
        });
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
}
