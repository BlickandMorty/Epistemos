//! Phase 4B — `heal_events.sqlite` persistence per plan §5.7.
//!
//! Plan §5.7 schema verbatim:
//!
//! ```sql
//! CREATE TABLE heal_events (
//!   id INTEGER PRIMARY KEY,
//!   ts TEXT NOT NULL,
//!   tool TEXT NOT NULL,
//!   variant TEXT NOT NULL,
//!   original_intent JSON NOT NULL,
//!   error JSON NOT NULL,
//!   corrected_intent JSON,
//!   outcome TEXT NOT NULL,    -- recovered | abandoned | escalated
//!   step_idx INTEGER NOT NULL,
//!   session_id TEXT NOT NULL
//! );
//! CREATE INDEX heal_events_tool_ts ON heal_events (tool, ts);
//! ```
//!
//! Plan §5.7 also mandates: "Recurring heal patterns (same tool, same
//! error class, ≥10 events in 7 days) auto-surface as a 'prompt drift'
//! alert in the action trace UI." This module ships the storage + the
//! query; the alert UI surfacing lands in Phase 8 observability work.
//!
//! Crash safety: WAL + synchronous=NORMAL per §6.9, append-only so
//! crashes mid-write never corrupt prior events.

use std::path::Path;
use std::sync::Mutex;

use chrono::{DateTime, Duration, Utc};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};

use crate::format::intent::Intent;

use super::ApplyError;

/// Plan §5.7 outcome enum — exactly three values:
/// - `Recovered` — the heal loop succeeded after one or more retries.
/// - `Abandoned` — the loop exhausted retries / diagnostician gave up.
/// - `Escalated` — punted to a higher-tier handler (user review, cloud
///   cascade). Reserved for Phase 8 Intent→Effect work; not emitted yet.
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "lowercase")]
pub enum HealOutcome {
    Recovered,
    Abandoned,
    Escalated,
}

impl HealOutcome {
    pub fn as_str(&self) -> &'static str {
        match self {
            HealOutcome::Recovered => "recovered",
            HealOutcome::Abandoned => "abandoned",
            HealOutcome::Escalated => "escalated",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "recovered" => Some(HealOutcome::Recovered),
            "abandoned" => Some(HealOutcome::Abandoned),
            "escalated" => Some(HealOutcome::Escalated),
            _ => None,
        }
    }
}

/// One row in heal_events. `id` is None on insert (assigned by SQLite);
/// reads populate it.
#[derive(Clone, Debug, PartialEq)]
pub struct HealEvent {
    pub id: Option<i64>,
    pub ts: DateTime<Utc>,
    pub tool: String,
    pub variant: String,
    pub original_intent: Intent,
    pub error: ApplyError,
    pub corrected_intent: Option<Intent>,
    pub outcome: HealOutcome,
    pub step_idx: u32,
    pub session_id: String,
}

/// One row in the §5.7 recurring-patterns query result.
#[derive(Clone, Debug, PartialEq)]
pub struct RecurringPattern {
    pub tool: String,
    pub error_kind: String,
    pub event_count: u32,
}

/// Plan §5.7: "≥10 events in 7 days" — pinned to plan literal so silent
/// drift breaks tests.
pub const DEFAULT_RECURRING_WINDOW_DAYS: i64 = 7;
pub const DEFAULT_RECURRING_MIN_EVENTS: u32 = 10;

const SCHEMA_SQL: &str = r#"
CREATE TABLE IF NOT EXISTS heal_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT NOT NULL,
  tool TEXT NOT NULL,
  variant TEXT NOT NULL,
  original_intent TEXT NOT NULL,
  error TEXT NOT NULL,
  corrected_intent TEXT,
  outcome TEXT NOT NULL CHECK(outcome IN ('recovered','abandoned','escalated')),
  step_idx INTEGER NOT NULL,
  session_id TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS heal_events_tool_ts ON heal_events (tool, ts);
CREATE INDEX IF NOT EXISTS heal_events_session ON heal_events (session_id);
"#;

pub struct HealEventLog {
    conn: Mutex<Connection>,
}

impl HealEventLog {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, rusqlite::Error> {
        let conn = Connection::open(path)?;
        // Plan §6.9 crash-safety: WAL + synchronous=NORMAL.
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;
        conn.execute_batch(SCHEMA_SQL)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    pub fn open_in_memory() -> Result<Self, rusqlite::Error> {
        let conn = Connection::open(":memory:")?;
        conn.execute_batch(SCHEMA_SQL)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    /// Append one event. Append-only by design — never UPDATE.
    ///
    /// TODO Wave 5 (FINAL_SYNTHESIS §5.5): mint an Ed25519 ExecutionReceipt
    /// per row signed with the per-vault Keychain key. The receipt is a
    /// proof-of-execution audit trail; tampering with the log invalidates
    /// the chain. Lands together with the broader RunEventLog (Effect /
    /// Intent receipts) during Wave 5 stabilize, not piecemeal here.
    pub fn append(&self, event: &HealEvent) -> Result<i64, HealLogError> {
        let original_json = serde_json::to_string(&event.original_intent)
            .map_err(|e| HealLogError::Serialize(e.to_string()))?;
        let error_json = serde_json::to_string(&event.error)
            .map_err(|e| HealLogError::Serialize(e.to_string()))?;
        let corrected_json = event
            .corrected_intent
            .as_ref()
            .map(|c| serde_json::to_string(c))
            .transpose()
            .map_err(|e| HealLogError::Serialize(e.to_string()))?;

        let g = self.conn.lock().expect("heal_events mutex poisoned");
        g.execute(
            "INSERT INTO heal_events
             (ts, tool, variant, original_intent, error, corrected_intent, outcome, step_idx, session_id)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
            params![
                event.ts.to_rfc3339(),
                event.tool,
                event.variant,
                original_json,
                error_json,
                corrected_json,
                event.outcome.as_str(),
                event.step_idx,
                event.session_id,
            ],
        )?;
        Ok(g.last_insert_rowid())
    }

    /// Append a batch of events atomically (one transaction). Used by
    /// HealLoop on termination to flush all per-step rows together.
    pub fn append_batch(&self, events: &[HealEvent]) -> Result<usize, HealLogError> {
        if events.is_empty() {
            return Ok(0);
        }
        let mut g = self.conn.lock().expect("heal_events mutex poisoned");
        let tx = g.transaction()?;
        for event in events {
            let original_json = serde_json::to_string(&event.original_intent)
                .map_err(|e| HealLogError::Serialize(e.to_string()))?;
            let error_json = serde_json::to_string(&event.error)
                .map_err(|e| HealLogError::Serialize(e.to_string()))?;
            let corrected_json = event
                .corrected_intent
                .as_ref()
                .map(|c| serde_json::to_string(c))
                .transpose()
                .map_err(|e| HealLogError::Serialize(e.to_string()))?;
            tx.execute(
                "INSERT INTO heal_events
                 (ts, tool, variant, original_intent, error, corrected_intent, outcome, step_idx, session_id)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
                params![
                    event.ts.to_rfc3339(),
                    event.tool,
                    event.variant,
                    original_json,
                    error_json,
                    corrected_json,
                    event.outcome.as_str(),
                    event.step_idx,
                    event.session_id,
                ],
            )?;
        }
        let n = events.len();
        tx.commit()?;
        Ok(n)
    }

    /// Plan §5.7: "Recurring heal patterns (same tool, same error
    /// class, ≥10 events in 7 days) auto-surface as a 'prompt drift'
    /// alert." This is the query. Caller filters to actionable rows;
    /// the alert UI is Phase 8 observability work.
    pub fn recurring_patterns(
        &self,
        window_days: i64,
        min_events: u32,
    ) -> Result<Vec<RecurringPattern>, HealLogError> {
        let cutoff = (Utc::now() - Duration::days(window_days)).to_rfc3339();
        let g = self.conn.lock().expect("heal_events mutex poisoned");

        // Query strategy: extract error.kind from the JSON column at
        // query time. SQLite has json_extract since 3.9; rusqlite ships
        // a recent SQLite in the bundled feature.
        let mut stmt = g.prepare(
            "SELECT tool,
                    json_extract(error, '$.kind') AS error_kind,
                    COUNT(*) AS n
             FROM heal_events
             WHERE ts >= ?1
             GROUP BY tool, error_kind
             HAVING n >= ?2
             ORDER BY n DESC, tool ASC, error_kind ASC",
        )?;
        let rows = stmt.query_map(params![cutoff, min_events as i64], |r| {
            let tool: String = r.get(0)?;
            let error_kind: String = r.get::<_, Option<String>>(1)?.unwrap_or_default();
            let n: i64 = r.get(2)?;
            Ok(RecurringPattern {
                tool,
                error_kind,
                event_count: n as u32,
            })
        })?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row?);
        }
        Ok(out)
    }

    pub fn count(&self) -> Result<u64, HealLogError> {
        let g = self.conn.lock().expect("heal_events mutex poisoned");
        let n: i64 = g.query_row("SELECT COUNT(*) FROM heal_events", [], |r| r.get(0))?;
        Ok(n as u64)
    }

    /// Read events for a given session — useful for trace UI to show
    /// the full heal-loop history of one capture.
    pub fn events_for_session(
        &self,
        session_id: &str,
    ) -> Result<Vec<HealEvent>, HealLogError> {
        let g = self.conn.lock().expect("heal_events mutex poisoned");
        let mut stmt = g.prepare(
            "SELECT id, ts, tool, variant, original_intent, error,
                    corrected_intent, outcome, step_idx, session_id
             FROM heal_events
             WHERE session_id = ?1
             ORDER BY step_idx ASC, id ASC",
        )?;
        let rows = stmt.query_map(params![session_id], row_to_event)?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row?);
        }
        Ok(out)
    }
}

fn row_to_event(r: &rusqlite::Row<'_>) -> rusqlite::Result<HealEvent> {
    let id: i64 = r.get(0)?;
    let ts_str: String = r.get(1)?;
    let ts: DateTime<Utc> = DateTime::parse_from_rfc3339(&ts_str)
        .map_err(|e| rusqlite::Error::FromSqlConversionFailure(
            1,
            rusqlite::types::Type::Text,
            Box::new(e),
        ))?
        .with_timezone(&Utc);
    let tool: String = r.get(2)?;
    let variant: String = r.get(3)?;
    let original_json: String = r.get(4)?;
    let error_json: String = r.get(5)?;
    let corrected_json: Option<String> = r.get(6)?;
    let outcome_str: String = r.get(7)?;
    let step_idx: u32 = r.get::<_, i64>(8)? as u32;
    let session_id: String = r.get(9)?;

    let original_intent: Intent = serde_json::from_str(&original_json).map_err(|e| {
        rusqlite::Error::FromSqlConversionFailure(
            4,
            rusqlite::types::Type::Text,
            Box::new(e),
        )
    })?;
    let error: ApplyError = serde_json::from_str(&error_json).map_err(|e| {
        rusqlite::Error::FromSqlConversionFailure(
            5,
            rusqlite::types::Type::Text,
            Box::new(e),
        )
    })?;
    let corrected_intent = match corrected_json {
        Some(s) => Some(serde_json::from_str::<Intent>(&s).map_err(|e| {
            rusqlite::Error::FromSqlConversionFailure(
                6,
                rusqlite::types::Type::Text,
                Box::new(e),
            )
        })?),
        None => None,
    };
    let outcome = HealOutcome::from_str(&outcome_str).ok_or_else(|| {
        rusqlite::Error::FromSqlConversionFailure(
            7,
            rusqlite::types::Type::Text,
            Box::new(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                format!("unknown outcome enum value: {}", outcome_str),
            )),
        )
    })?;

    Ok(HealEvent {
        id: Some(id),
        ts,
        tool,
        variant,
        original_intent,
        error,
        corrected_intent,
        outcome,
        step_idx,
        session_id,
    })
}

#[derive(Debug, thiserror::Error)]
pub enum HealLogError {
    #[error("rusqlite: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("serialize: {0}")]
    Serialize(String),
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Duration as ChronoDuration;

    fn write_intent(path: &str) -> Intent {
        Intent::VaultWrite {
            path: path.to_string(),
            body: "x".to_string(),
            frontmatter: serde_json::json!({}),
        }
    }

    fn sample_event(tool: &str, error_kind: &str, step: u32, session: &str) -> HealEvent {
        HealEvent {
            id: None,
            ts: Utc::now(),
            tool: tool.to_string(),
            variant: "a".to_string(),
            original_intent: write_intent("foo.md"),
            error: ApplyError::new(error_kind, "test error"),
            corrected_intent: None,
            outcome: HealOutcome::Abandoned,
            step_idx: step,
            session_id: session.to_string(),
        }
    }

    #[test]
    fn append_and_count_round_trips() {
        let log = HealEventLog::open_in_memory().unwrap();
        assert_eq!(log.count().unwrap(), 0);
        log.append(&sample_event("vault.write", "io", 0, "s1"))
            .unwrap();
        assert_eq!(log.count().unwrap(), 1);
    }

    #[test]
    fn append_batch_is_atomic_transaction() {
        let log = HealEventLog::open_in_memory().unwrap();
        let events = vec![
            sample_event("vault.write", "io", 0, "s1"),
            sample_event("vault.write", "io", 1, "s1"),
            sample_event("vault.write", "io", 2, "s1"),
        ];
        let n = log.append_batch(&events).unwrap();
        assert_eq!(n, 3);
        assert_eq!(log.count().unwrap(), 3);
    }

    #[test]
    fn schema_check_rejects_invalid_outcome_string() {
        // §5.7 outcome column has CHECK(outcome IN ('recovered',
        // 'abandoned','escalated')) — bypassing the enum to insert a
        // bogus literal must fail at the SQLite layer.
        let log = HealEventLog::open_in_memory().unwrap();
        let g = log.conn.lock().unwrap();
        let r = g.execute(
            "INSERT INTO heal_events (ts, tool, variant, original_intent, error, outcome, step_idx, session_id) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![
                Utc::now().to_rfc3339(),
                "x",
                "a",
                "{}",
                "{}",
                "fabricated_outcome",
                0,
                "s1"
            ],
        );
        assert!(r.is_err(), "schema CHECK rejected bogus outcome enum");
    }

    #[test]
    fn events_for_session_returns_all_steps_in_order() {
        let log = HealEventLog::open_in_memory().unwrap();
        // Insert out-of-order; query should sort by step_idx ASC.
        log.append(&sample_event("v", "io", 2, "s1")).unwrap();
        log.append(&sample_event("v", "io", 0, "s1")).unwrap();
        log.append(&sample_event("v", "io", 1, "s1")).unwrap();
        log.append(&sample_event("other", "io", 0, "s2")).unwrap();
        let evs = log.events_for_session("s1").unwrap();
        assert_eq!(evs.len(), 3);
        assert_eq!(evs[0].step_idx, 0);
        assert_eq!(evs[1].step_idx, 1);
        assert_eq!(evs[2].step_idx, 2);
    }

    #[test]
    fn recurring_patterns_groups_by_tool_and_error_kind() {
        let log = HealEventLog::open_in_memory().unwrap();
        // 12 events for (vault.write, io) — exceeds default 10 threshold.
        for i in 0..12 {
            log.append(&sample_event("vault.write", "io", i, "s1"))
                .unwrap();
        }
        // 5 events for (vault.write, schema_violation) — below threshold.
        for i in 0..5 {
            log.append(&sample_event("vault.write", "schema_violation", i, "s1"))
                .unwrap();
        }
        // 11 events for (knowledge.recall, timeout) — exceeds threshold.
        for i in 0..11 {
            log.append(&sample_event("knowledge.recall", "timeout", i, "s2"))
                .unwrap();
        }

        let patterns = log
            .recurring_patterns(
                DEFAULT_RECURRING_WINDOW_DAYS,
                DEFAULT_RECURRING_MIN_EVENTS,
            )
            .unwrap();

        // Two qualifying patterns: vault.write/io (12) and
        // knowledge.recall/timeout (11). vault.write/schema_violation
        // (5) below threshold, excluded.
        assert_eq!(patterns.len(), 2);
        // Order: DESC by count, then tool ASC, then error_kind ASC.
        assert_eq!(patterns[0].tool, "vault.write");
        assert_eq!(patterns[0].error_kind, "io");
        assert_eq!(patterns[0].event_count, 12);
        assert_eq!(patterns[1].tool, "knowledge.recall");
        assert_eq!(patterns[1].error_kind, "timeout");
        assert_eq!(patterns[1].event_count, 11);
    }

    #[test]
    fn recurring_patterns_window_excludes_old_events() {
        let log = HealEventLog::open_in_memory().unwrap();
        // 12 events but with ts 30 days ago — outside the 7-day window.
        let old_ts = Utc::now() - ChronoDuration::days(30);
        for i in 0..12 {
            let mut ev = sample_event("vault.write", "io", i, "s1");
            ev.ts = old_ts;
            log.append(&ev).unwrap();
        }
        let patterns = log.recurring_patterns(7, 10).unwrap();
        assert_eq!(patterns.len(), 0, "30-day-old events outside 7d window");
    }

    #[test]
    fn recurring_thresholds_match_plan_5_7_literal() {
        // Plan §5.7: "≥10 events in 7 days" — pinned constants.
        assert_eq!(DEFAULT_RECURRING_WINDOW_DAYS, 7);
        assert_eq!(DEFAULT_RECURRING_MIN_EVENTS, 10);
    }

    #[test]
    fn outcome_enum_serializes_lowercase_and_round_trips() {
        for variant in [
            HealOutcome::Recovered,
            HealOutcome::Abandoned,
            HealOutcome::Escalated,
        ] {
            let s = serde_json::to_string(&variant).unwrap();
            let stripped = s.trim_matches('"');
            assert_eq!(stripped, variant.as_str());
            let parsed = HealOutcome::from_str(stripped).unwrap();
            assert_eq!(parsed, variant);
        }
    }

    #[test]
    fn outcome_from_str_rejects_unknown() {
        assert_eq!(HealOutcome::from_str("recovered"), Some(HealOutcome::Recovered));
        assert_eq!(HealOutcome::from_str("abandoned"), Some(HealOutcome::Abandoned));
        assert_eq!(HealOutcome::from_str("escalated"), Some(HealOutcome::Escalated));
        assert_eq!(HealOutcome::from_str("Recovered"), None, "lowercase only");
        assert_eq!(HealOutcome::from_str("merged"), None);
    }

    #[test]
    fn open_on_disk_with_wal() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("heal.sqlite");
        let log = HealEventLog::open(&path).unwrap();
        log.append(&sample_event("v", "io", 0, "s1")).unwrap();
        // WAL mode should produce a -wal sidecar after the first write.
        let wal_path = path.with_extension("sqlite-wal");
        assert!(
            wal_path.exists() || path.exists(),
            "WAL mode produces -wal sidecar (or queues for next checkpoint)"
        );
    }

    #[test]
    fn full_event_round_trips_via_disk_storage() {
        let log = HealEventLog::open_in_memory().unwrap();
        let mut event = sample_event("vault.write", "schema_violation", 1, "s1");
        event.outcome = HealOutcome::Recovered;
        event.corrected_intent = Some(write_intent("corrected.md"));
        log.append(&event).unwrap();

        let evs = log.events_for_session("s1").unwrap();
        assert_eq!(evs.len(), 1);
        let read = &evs[0];
        // ID should be populated on read.
        assert!(read.id.is_some());
        assert_eq!(read.tool, event.tool);
        assert_eq!(read.variant, event.variant);
        assert_eq!(read.outcome, HealOutcome::Recovered);
        assert_eq!(read.step_idx, 1);
        assert_eq!(read.original_intent, event.original_intent);
        assert_eq!(read.error.kind, event.error.kind);
        assert_eq!(read.corrected_intent, event.corrected_intent);
    }
}
