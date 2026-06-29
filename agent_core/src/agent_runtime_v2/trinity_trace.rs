//! TRINITY orchestrator — slice 3: JSONL trace PERSISTENCE (owner 2026-06-22). The reference emits a
//! newline-delimited JSON trace (schema_version 1) for honest, replayable provenance of every coordination run.
//! This slice serializes the loop's `TrinityEvent` stream to JSONL and persists it ATOMICALLY (temp + rename, per
//! the build's durability posture — a crash mid-write can't leave a truncated trace), plus a reader for replay.
//! Slice 3b forwards the same events into the Swift `TraceCollector` (the app-facing provenance surface).

use std::fs;
use std::path::Path;

use super::trinity_loop::TrinityEvent;

/// Serialize a trace to JSONL — one JSON object per line (the reference's on-disk shape). Errors if any event
/// fails to serialize (never silently drops an event from the provenance trail).
pub fn trace_to_jsonl(events: &[TrinityEvent]) -> Result<String, String> {
    let mut out = String::new();
    for event in events {
        let line = serde_json::to_string(event).map_err(|e| e.to_string())?;
        out.push_str(&line);
        out.push('\n');
    }
    Ok(out)
}

/// Parse a JSONL trace back into events (replay). Blank lines are skipped; a malformed line is an error (the
/// trail must be whole to be trusted).
pub fn trace_from_jsonl(text: &str) -> Result<Vec<TrinityEvent>, String> {
    let mut events = Vec::new();
    for line in text.lines() {
        if line.trim().is_empty() {
            continue;
        }
        events.push(serde_json::from_str(line).map_err(|e| e.to_string())?);
    }
    Ok(events)
}

/// Write the trace to `path` ATOMICALLY (temp sibling + rename — atomic on the same filesystem) so a crash
/// mid-write can never leave a truncated/invalid trace file. The parent directory is created if needed.
pub fn write_trace_jsonl(events: &[TrinityEvent], path: &Path) -> Result<(), String> {
    let body = trace_to_jsonl(events)?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let tmp = path.with_extension("jsonl.tmp");
    fs::write(&tmp, body).map_err(|e| e.to_string())?;
    fs::rename(&tmp, path).map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::super::trinity_loop::{run_trinity_loop, TrinityRoleExecutor, VerifierVerdict};
    use super::*;

    struct AcceptingExec;
    impl TrinityRoleExecutor for AcceptingExec {
        fn think(&mut self, _o: &str, _f: &str) -> String {
            "plan".into()
        }
        fn work(&mut self, _p: &str) -> String {
            "work".into()
        }
        fn verify(&mut self, _w: &str, _o: &str) -> (VerifierVerdict, String) {
            (VerifierVerdict::Accept, String::new())
        }
    }

    #[test]
    fn jsonl_round_trips_a_real_loop_trace() {
        let out = run_trinity_loop("solve x", 5, &mut AcceptingExec);
        let jsonl = trace_to_jsonl(&out.trace).unwrap();
        // one line per event, every line is an object with an "event" tag.
        assert_eq!(jsonl.lines().count(), out.trace.len());
        assert!(jsonl.lines().all(|l| l.contains("\"event\"")));
        // round-trip is identity (honest, lossless provenance).
        assert_eq!(trace_from_jsonl(&jsonl).unwrap(), out.trace);
    }

    #[test]
    fn read_skips_blank_lines_and_rejects_garbage() {
        let out = run_trinity_loop("x", 5, &mut AcceptingExec);
        let jsonl = format!("\n{}\n\n", trace_to_jsonl(&out.trace).unwrap().trim_end());
        assert_eq!(trace_from_jsonl(&jsonl).unwrap(), out.trace); // blanks skipped
        assert!(trace_from_jsonl("not json").is_err()); // garbage rejected
    }

    #[test]
    fn write_is_atomic_and_leaves_no_temp() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("traces").join("run.jsonl");
        let out = run_trinity_loop("x", 5, &mut AcceptingExec);
        write_trace_jsonl(&out.trace, &path).unwrap();

        let body = std::fs::read_to_string(&path).unwrap();
        assert_eq!(trace_from_jsonl(&body).unwrap(), out.trace); // complete, valid
        assert!(
            !path.with_extension("jsonl.tmp").exists(),
            "no temp sidecar may linger"
        );
    }
}
