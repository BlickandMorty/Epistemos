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
}
