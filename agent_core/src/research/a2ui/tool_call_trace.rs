//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `ToolCallTrace`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::ToolCallTrace`].
//!
//! # Wave I — ToolCallTrace component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ToolCallTraceEntry {
    pub tool_name: String,
    pub args_json: String,
    pub result_summary: String,
    pub duration_ms: u32,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ToolCallTraceProps {
    pub entries: Vec<ToolCallTraceEntry>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ToolCallTraceError {
    EmptyTraceVec,
    EmptyToolName { index: usize },
}

impl ToolCallTraceError {
    pub const fn cause(&self) -> &'static str {
        match self {
            ToolCallTraceError::EmptyTraceVec => "empty_trace_vec",
            ToolCallTraceError::EmptyToolName { .. } => "empty_tool_name",
        }
    }
}

impl ToolCallTraceProps {
    pub fn validate(&self) -> Result<(), ToolCallTraceError> {
        if self.entries.is_empty() {
            return Err(ToolCallTraceError::EmptyTraceVec);
        }
        for (i, e) in self.entries.iter().enumerate() {
            if e.tool_name.is_empty() {
                return Err(ToolCallTraceError::EmptyToolName { index: i });
            }
        }
        Ok(())
    }

    pub fn total_duration_ms(&self) -> u64 {
        self.entries.iter().map(|e| e.duration_ms as u64).sum()
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Number of tool-call entries.
    pub fn entry_count(&self) -> usize {
        self.entries.len()
    }

    /// Mean per-call duration in ms. `None` for an empty trace.
    /// Cross-surface invariant: when `Some`, `mean_duration_ms ==
    /// total_duration_ms / entry_count`.
    pub fn mean_duration_ms(&self) -> Option<f64> {
        if self.entries.is_empty() {
            return None;
        }
        Some(self.total_duration_ms() as f64 / self.entries.len() as f64)
    }

    /// Slowest entry's duration_ms. `None` for an empty trace.
    pub fn max_duration_ms(&self) -> Option<u32> {
        self.entries.iter().map(|e| e.duration_ms).max()
    }

    /// Number of distinct tool names invoked across the trace.
    pub fn distinct_tool_count(&self) -> usize {
        self.entries
            .iter()
            .map(|e| e.tool_name.as_str())
            .collect::<std::collections::HashSet<_>>()
            .len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(name: &str, duration: u32) -> ToolCallTraceEntry {
        ToolCallTraceEntry {
            tool_name: name.into(),
            args_json: "{}".into(),
            result_summary: "ok".into(),
            duration_ms: duration,
        }
    }

    #[test]
    fn empty_trace_rejected() {
        let t = ToolCallTraceProps { entries: vec![] };
        assert_eq!(t.validate().unwrap_err(), ToolCallTraceError::EmptyTraceVec);
    }

    #[test]
    fn valid_trace_passes() {
        let t = ToolCallTraceProps {
            entries: vec![entry("workspace_search", 50)],
        };
        assert!(t.validate().is_ok());
    }

    #[test]
    fn empty_tool_name_rejected() {
        let t = ToolCallTraceProps {
            entries: vec![entry("", 0)],
        };
        assert!(matches!(t.validate().unwrap_err(), ToolCallTraceError::EmptyToolName { .. }));
    }

    #[test]
    fn total_duration_sums() {
        let t = ToolCallTraceProps {
            entries: vec![entry("a", 100), entry("b", 200)],
        };
        assert_eq!(t.total_duration_ms(), 300);
    }

    #[test]
    fn serde_json_roundtrip() {
        let t = ToolCallTraceProps {
            entries: vec![entry("x", 1)],
        };
        let json = serde_json::to_string(&t).unwrap();
        let back: ToolCallTraceProps = serde_json::from_str(&json).unwrap();
        assert_eq!(t, back);
    }

    // ── diagnostic surface (iter 205) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct() {
        assert_ne!(
            ToolCallTraceError::EmptyTraceVec.cause(),
            ToolCallTraceError::EmptyToolName { index: 0 }.cause(),
        );
    }

    #[test]
    fn entry_count_matches_entries_len() {
        let t = ToolCallTraceProps {
            entries: vec![entry("a", 1), entry("b", 2)],
        };
        assert_eq!(t.entry_count(), 2);
    }

    #[test]
    fn mean_duration_none_on_empty() {
        let t = ToolCallTraceProps { entries: vec![] };
        assert_eq!(t.mean_duration_ms(), None);
    }

    #[test]
    fn mean_duration_matches_total_div_count() {
        // Cross-surface invariant.
        let t = ToolCallTraceProps {
            entries: vec![entry("a", 100), entry("b", 200), entry("c", 300)],
        };
        let mean = t.mean_duration_ms().unwrap();
        let total_div = t.total_duration_ms() as f64 / t.entry_count() as f64;
        assert!((mean - total_div).abs() < 1e-9);
        assert!((mean - 200.0).abs() < 1e-9);
    }

    #[test]
    fn max_duration_picks_slowest() {
        let t = ToolCallTraceProps {
            entries: vec![entry("a", 50), entry("b", 500), entry("c", 100)],
        };
        assert_eq!(t.max_duration_ms(), Some(500));
    }

    #[test]
    fn max_duration_none_on_empty() {
        let t = ToolCallTraceProps { entries: vec![] };
        assert_eq!(t.max_duration_ms(), None);
    }

    #[test]
    fn distinct_tool_count_dedupes() {
        let t = ToolCallTraceProps {
            entries: vec![
                entry("read", 10),
                entry("write", 20),
                entry("read", 30),
                entry("search", 40),
            ],
        };
        assert_eq!(t.distinct_tool_count(), 3); // read, write, search
        // Cross-surface invariant: distinct ≤ total.
        assert!(t.distinct_tool_count() <= t.entry_count());
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = ToolCallTraceProps { entries: vec![entry("x", 1)] };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
