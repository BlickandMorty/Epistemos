use std::time::Duration;

use agent_core::format::Intent;
use agent_core::undo::{UndoEntry, UndoLog, UndoLogError, AUTO_RESEARCH_TTL, DEFAULT_TTL};
use chrono::{TimeZone, Utc};
use serde_json::json;

fn sample_intent() -> Intent {
    Intent::VaultWrite {
        path: "notes/x.md".to_string(),
        body: "hello".to_string(),
        frontmatter: json!({}),
    }
}

fn sample_entry(session_id: &str) -> UndoEntry {
    UndoEntry::new(
        session_id.to_string(),
        sample_intent(),
        json!({"effect": "vault.write", "path": "notes/x.md"}),
        json!({"inverse": "vault.delete", "path": "notes/x.md"}),
    )
}

#[test]
fn append_get_round_trips_json_effect_and_inverse() {
    let log = UndoLog::open_in_memory().unwrap();
    let entry = sample_entry("session-1");
    let id = log.append(&entry).unwrap();
    let fetched = log.get(id).unwrap();

    assert_eq!(fetched.id, Some(id));
    assert_eq!(fetched.session_id, "session-1");
    assert_eq!(fetched.intent, entry.intent);
    assert_eq!(fetched.effect, entry.effect);
    assert_eq!(fetched.inverse, entry.inverse);
    assert!(!fetched.undone);
}

#[test]
fn recent_filters_by_session_and_orders_newest_first() {
    let log = UndoLog::open_in_memory().unwrap();
    let base = Utc.with_ymd_and_hms(2026, 4, 29, 1, 0, 0).unwrap();
    for (offset, session_id) in [(0, "s1"), (1, "s1"), (2, "s2"), (3, "s1")] {
        let mut entry = sample_entry(session_id);
        entry.ts = base + chrono::Duration::seconds(offset);
        entry.ttl_until = entry.ts + chrono::Duration::hours(24);
        log.append(&entry).unwrap();
    }

    let recent = log.recent("s1", 10).unwrap();
    assert_eq!(recent.len(), 3);
    assert!(recent.windows(2).all(|window| window[0].ts >= window[1].ts));
    assert!(recent.iter().all(|entry| entry.session_id == "s1"));
}

#[test]
fn mark_undone_returns_inverse_flips_flag_and_records_acceptance_signal() {
    let log = UndoLog::open_in_memory().unwrap();
    let entry = sample_entry("s");
    let id = log.append(&entry).unwrap();
    let inverse = log.mark_undone(id).unwrap();

    assert_eq!(inverse, entry.inverse);
    assert!(log.get(id).unwrap().undone);
    assert!(log
        .has_undo_since("s", Utc::now() - chrono::Duration::minutes(5))
        .unwrap());
    assert!(matches!(
        log.mark_undone(id),
        Err(UndoLogError::AlreadyUndone(_))
    ));
}

#[test]
fn mark_undone_rejects_expired_entries_and_evicts_only_past_ttl() {
    let log = UndoLog::open_in_memory().unwrap();
    log.append(&sample_entry("s")).unwrap();

    let mut expired = sample_entry("s");
    expired.ttl_until = Utc::now() - chrono::Duration::seconds(1);
    let expired_id = log.append(&expired).unwrap();
    assert!(matches!(
        log.mark_undone(expired_id),
        Err(UndoLogError::Expired { .. })
    ));

    assert_eq!(log.evict_expired().unwrap(), 1);
    assert_eq!(log.len().unwrap(), 1);
}

#[test]
fn ttl_classes_match_canon() {
    assert_eq!(DEFAULT_TTL, Duration::from_secs(24 * 60 * 60));
    assert_eq!(AUTO_RESEARCH_TTL, Duration::from_secs(7 * 24 * 60 * 60));

    let routine = sample_entry("s");
    assert!(
        ((routine.ttl_until - routine.ts) - chrono::Duration::hours(24))
            .num_seconds()
            .abs()
            < 5
    );

    let research = UndoEntry::with_ttl(
        "s".to_string(),
        sample_intent(),
        json!({"effect": "auto_research.win"}),
        json!({"inverse": "auto_research.retract"}),
        AUTO_RESEARCH_TTL,
    );
    assert!(
        ((research.ttl_until - research.ts) - chrono::Duration::days(7))
            .num_seconds()
            .abs()
            < 5
    );
}

#[test]
fn file_backed_log_creates_canonical_schema() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join(".epistemos").join("undo_events.sqlite");
    let log = UndoLog::open(&path).unwrap();
    let id = log.append(&sample_entry("s")).unwrap();
    assert_eq!(log.get(id).unwrap().id, Some(id));
    assert!(path.exists());
}
