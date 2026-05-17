use std::path::Path;
use std::sync::Mutex;

use chrono::{DateTime, Duration, Utc};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};

use crate::effect::ApplyError;
use crate::format::Intent;

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "lowercase")]
pub enum HealOutcome {
    Recovered,
    Abandoned,
    Escalated,
}

impl HealOutcome {
    pub const ALL: [HealOutcome; 3] =
        [HealOutcome::Recovered, HealOutcome::Abandoned, HealOutcome::Escalated];

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Recovered => "recovered",
            Self::Abandoned => "abandoned",
            Self::Escalated => "escalated",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "recovered" => Some(Self::Recovered),
            "abandoned" => Some(Self::Abandoned),
            "escalated" => Some(Self::Escalated),
            _ => None,
        }
    }

    pub const fn is_recovered(self) -> bool {
        matches!(self, HealOutcome::Recovered)
    }

    pub const fn is_abandoned(self) -> bool {
        matches!(self, HealOutcome::Abandoned)
    }

    pub const fn is_escalated(self) -> bool {
        matches!(self, HealOutcome::Escalated)
    }

    /// Predicate: this outcome ended the heal loop on its own
    /// (Recovered or Abandoned). Escalated kicks the case upward
    /// and is NOT terminal from the loop's perspective. Useful for
    /// telemetry counters that want a 2-bucket split.
    pub const fn is_terminal_for_loop(self) -> bool {
        matches!(self, HealOutcome::Recovered | HealOutcome::Abandoned)
    }
}

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

#[derive(Clone, Debug, PartialEq)]
pub struct RecurringPattern {
    pub tool: String,
    pub error_kind: String,
    pub event_count: u32,
}

impl RecurringPattern {
    /// Predicate: this pattern's event_count meets or exceeds
    /// `min_events`. Companion to `HealEventLog::recurring_patterns`
    /// for callers that materialize patterns first then filter.
    pub const fn is_above_threshold(&self, min_events: u32) -> bool {
        self.event_count >= min_events
    }

    /// Predicate: this pattern crosses the default
    /// `DEFAULT_RECURRING_MIN_EVENTS` threshold.
    pub const fn is_above_default_threshold(&self) -> bool {
        self.event_count >= DEFAULT_RECURRING_MIN_EVENTS
    }
}

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
CREATE INDEX IF NOT EXISTS heal_events_session ON heal_events (session_id, step_idx);
"#;

pub struct HealEventLog {
    conn: Mutex<Connection>,
}

impl HealEventLog {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, HealLogError> {
        if let Some(parent) = path.as_ref().parent() {
            std::fs::create_dir_all(parent).map_err(HealLogError::Io)?;
        }
        let conn = Connection::open(path)?;
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;
        conn.execute_batch(SCHEMA_SQL)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    pub fn open_in_memory() -> Result<Self, HealLogError> {
        let conn = Connection::open_in_memory()?;
        conn.execute_batch(SCHEMA_SQL)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    #[allow(clippy::too_many_arguments)]
    pub fn append_failure(
        &self,
        tool: &str,
        variant: &str,
        original_intent: &Intent,
        error: &ApplyError,
        corrected_intent: Option<Intent>,
        outcome: HealOutcome,
        step_idx: u32,
        session_id: &str,
    ) -> Result<i64, HealLogError> {
        self.append(&HealEvent {
            id: None,
            ts: Utc::now(),
            tool: tool.to_string(),
            variant: variant.to_string(),
            original_intent: original_intent.clone(),
            error: error.clone(),
            corrected_intent,
            outcome,
            step_idx,
            session_id: session_id.to_string(),
        })
    }

    pub fn append(&self, event: &HealEvent) -> Result<i64, HealLogError> {
        let guard = self.conn.lock().expect("heal_events mutex");
        insert_event(&guard, event)?;
        Ok(guard.last_insert_rowid())
    }

    pub fn append_batch(&self, events: &[HealEvent]) -> Result<usize, HealLogError> {
        if events.is_empty() {
            return Ok(0);
        }
        let mut guard = self.conn.lock().expect("heal_events mutex");
        let tx = guard.transaction()?;
        for event in events {
            insert_event(&tx, event)?;
        }
        tx.commit()?;
        Ok(events.len())
    }

    pub fn events_for_session(&self, session_id: &str) -> Result<Vec<HealEvent>, HealLogError> {
        let guard = self.conn.lock().expect("heal_events mutex");
        let mut statement = guard.prepare(
            "SELECT id, ts, tool, variant, original_intent, error,
                    corrected_intent, outcome, step_idx, session_id
             FROM heal_events
             WHERE session_id = ?1
             ORDER BY step_idx ASC, id ASC",
        )?;
        let rows = statement.query_map(params![session_id], row_to_event)?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row?);
        }
        Ok(out)
    }

    pub fn recurring_patterns(
        &self,
        window_days: i64,
        min_events: u32,
    ) -> Result<Vec<RecurringPattern>, HealLogError> {
        let cutoff = (Utc::now() - Duration::days(window_days)).to_rfc3339();
        let guard = self.conn.lock().expect("heal_events mutex");
        let mut statement = guard.prepare(
            "SELECT tool,
                    json_extract(error, '$.kind') AS error_kind,
                    COUNT(*) AS n
             FROM heal_events
             WHERE ts >= ?1
             GROUP BY tool, error_kind
             HAVING n >= ?2
             ORDER BY n DESC, tool ASC, error_kind ASC",
        )?;
        let rows = statement.query_map(params![cutoff, min_events as i64], |row| {
            let event_count: i64 = row.get(2)?;
            Ok(RecurringPattern {
                tool: row.get(0)?,
                error_kind: row.get::<_, Option<String>>(1)?.unwrap_or_default(),
                event_count: event_count as u32,
            })
        })?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row?);
        }
        Ok(out)
    }

    pub fn count(&self) -> Result<u64, HealLogError> {
        let guard = self.conn.lock().expect("heal_events mutex");
        let count: i64 =
            guard.query_row("SELECT COUNT(*) FROM heal_events", [], |row| row.get(0))?;
        Ok(count as u64)
    }
}

fn insert_event(conn: &Connection, event: &HealEvent) -> Result<(), HealLogError> {
    let original_intent = serde_json::to_string(&event.original_intent)
        .map_err(|error| HealLogError::Serialize(error.to_string()))?;
    let error_json = serde_json::to_string(&event.error)
        .map_err(|error| HealLogError::Serialize(error.to_string()))?;
    let corrected_intent = event
        .corrected_intent
        .as_ref()
        .map(serde_json::to_string)
        .transpose()
        .map_err(|error| HealLogError::Serialize(error.to_string()))?;
    conn.execute(
        "INSERT INTO heal_events
         (ts, tool, variant, original_intent, error, corrected_intent, outcome, step_idx, session_id)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
        params![
            event.ts.to_rfc3339(),
            event.tool,
            event.variant,
            original_intent,
            error_json,
            corrected_intent,
            event.outcome.as_str(),
            event.step_idx,
            event.session_id,
        ],
    )?;
    Ok(())
}

fn row_to_event(row: &rusqlite::Row<'_>) -> rusqlite::Result<HealEvent> {
    let ts_string: String = row.get(1)?;
    let corrected_intent: Option<String> = row.get(6)?;
    let outcome_string: String = row.get(7)?;
    Ok(HealEvent {
        id: Some(row.get(0)?),
        ts: DateTime::parse_from_rfc3339(&ts_string)
            .map_err(|error| {
                rusqlite::Error::FromSqlConversionFailure(
                    1,
                    rusqlite::types::Type::Text,
                    Box::new(error),
                )
            })?
            .with_timezone(&Utc),
        tool: row.get(2)?,
        variant: row.get(3)?,
        original_intent: serde_json::from_str(&row.get::<_, String>(4)?).map_err(|error| {
            rusqlite::Error::FromSqlConversionFailure(
                4,
                rusqlite::types::Type::Text,
                Box::new(error),
            )
        })?,
        error: serde_json::from_str(&row.get::<_, String>(5)?).map_err(|error| {
            rusqlite::Error::FromSqlConversionFailure(
                5,
                rusqlite::types::Type::Text,
                Box::new(error),
            )
        })?,
        corrected_intent: corrected_intent
            .map(|json| serde_json::from_str(&json))
            .transpose()
            .map_err(|error| {
                rusqlite::Error::FromSqlConversionFailure(
                    6,
                    rusqlite::types::Type::Text,
                    Box::new(error),
                )
            })?,
        outcome: HealOutcome::parse(&outcome_string).ok_or_else(|| {
            rusqlite::Error::FromSqlConversionFailure(
                7,
                rusqlite::types::Type::Text,
                Box::new(std::io::Error::new(
                    std::io::ErrorKind::InvalidData,
                    format!("unknown heal outcome {outcome_string}"),
                )),
            )
        })?,
        step_idx: row.get::<_, i64>(8)? as u32,
        session_id: row.get(9)?,
    })
}

#[derive(Debug, thiserror::Error)]
pub enum HealLogError {
    #[error("sqlite: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("serialize: {0}")]
    Serialize(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── HealOutcome diagnostic surface (iter 148) ────────────────────────────

    #[test]
    fn heal_outcome_all_includes_three_distinct() {
        let s: std::collections::HashSet<_> = HealOutcome::ALL.iter().copied().collect();
        assert_eq!(s.len(), 3);
    }

    #[test]
    fn heal_outcome_as_str_roundtrips_through_parse() {
        // Cross-surface invariant: parse(as_str(o)) == Some(o) for all outcomes.
        for o in HealOutcome::ALL.iter().copied() {
            assert_eq!(HealOutcome::parse(o.as_str()), Some(o));
        }
    }

    #[test]
    fn heal_outcome_parse_unknown_returns_none() {
        assert_eq!(HealOutcome::parse("Recovered"), None); // case-sensitive
        assert_eq!(HealOutcome::parse(""), None);
        assert_eq!(HealOutcome::parse("not-an-outcome"), None);
    }

    #[test]
    fn heal_outcome_classifier_predicates_partition() {
        // Cross-surface invariant: is_recovered XOR is_abandoned XOR is_escalated
        // (exactly one true per variant — 3-way partition).
        for o in HealOutcome::ALL.iter().copied() {
            let trio = [o.is_recovered(), o.is_abandoned(), o.is_escalated()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", o);
        }
    }

    #[test]
    fn heal_outcome_is_terminal_for_loop_covers_recovered_and_abandoned() {
        assert!(HealOutcome::Recovered.is_terminal_for_loop());
        assert!(HealOutcome::Abandoned.is_terminal_for_loop());
        assert!(!HealOutcome::Escalated.is_terminal_for_loop());
    }

    #[test]
    fn heal_outcome_as_str_matches_serde_wire_form() {
        // Cross-surface: as_str() agrees with serde rename_all = "lowercase"
        // serialization for each variant.
        for o in HealOutcome::ALL.iter().copied() {
            let json = serde_json::to_string(&o).unwrap();
            assert_eq!(json, format!("\"{}\"", o.as_str()), "{:?}", o);
        }
    }

    // ── RecurringPattern diagnostic surface (iter 148) ───────────────────────

    fn pattern(count: u32) -> RecurringPattern {
        RecurringPattern {
            tool: "edit".into(),
            error_kind: "timeout".into(),
            event_count: count,
        }
    }

    #[test]
    fn recurring_pattern_above_threshold_at_boundary() {
        let p = pattern(10);
        assert!(p.is_above_threshold(10));
        assert!(p.is_above_threshold(9));
        assert!(!p.is_above_threshold(11));
    }

    #[test]
    fn recurring_pattern_above_default_threshold_matches_constant() {
        // Cross-surface invariant: is_above_default_threshold() iff
        // is_above_threshold(DEFAULT_RECURRING_MIN_EVENTS).
        for count in [0u32, 5, DEFAULT_RECURRING_MIN_EVENTS - 1, DEFAULT_RECURRING_MIN_EVENTS, DEFAULT_RECURRING_MIN_EVENTS + 5] {
            let p = pattern(count);
            assert_eq!(
                p.is_above_default_threshold(),
                p.is_above_threshold(DEFAULT_RECURRING_MIN_EVENTS),
                "count={}", count,
            );
        }
    }

    #[test]
    fn default_recurring_constants_stable() {
        assert_eq!(DEFAULT_RECURRING_WINDOW_DAYS, 7);
        assert_eq!(DEFAULT_RECURRING_MIN_EVENTS, 10);
    }
}
