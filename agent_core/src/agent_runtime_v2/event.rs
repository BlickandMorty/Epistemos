//! `AgentEvent` — the typed event stream a v2 executor yields.
//!
//! Mirrors the prior-design shape (`docs/HERMES_AGENT_CORE_2_0_DESIGN
//! _2026_05_15.md` §4) but in the neutral `agent_runtime_v2`
//! namespace. Every provider serialises its native protocol into these
//! variants before crossing back into Epistemos.

use serde::{Deserialize, Serialize};

use super::mission::{ToolCall, ToolCallError};
use super::para::StopReason;

/// Single event in the executor stream.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "event_type", rename_all = "snake_case")]
pub enum AgentEvent {
    /// Streaming reasoning / "thinking" delta. May arrive in any
    /// quantity; concatenation reproduces the full thinking text.
    ReasoningDelta { text: String },
    /// Streaming final-text delta. Concatenation reproduces the
    /// final answer body.
    FinalText { text: String },
    /// Agent emitted a tool call. The dispatcher validates it via
    /// `ToolCall::validate` before threading through capability /
    /// budget / envelope gates.
    ToolCall { call: ToolCall },
    /// Result of a previously-emitted tool call (executor-side
    /// echo so RunEventLog can pair calls with receipts).
    ToolResult {
        name: String,
        result: serde_json::Value,
    },
    /// Terminal event with a typed stop reason.
    Stop { reason: StopReason },
    /// Error event. Always terminal for the run; carries the kind so
    /// RunEventLog records the exact failure surface.
    Error {
        kind: AgentEventErrorKind,
        message: String,
    },
}

/// Closed taxonomy of executor-stream error kinds. Mirrors the
/// rejection surfaces of the gates: malformed tool call, budget,
/// capability, provider transport.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentEventErrorKind {
    MalformedToolCall,
    BudgetExhausted,
    CapabilityDenied,
    Provider,
}

impl AgentEvent {
    /// Number of variants in the closed AgentEvent taxonomy. Pinned
    /// at 6: ReasoningDelta, FinalText, ToolCall, ToolResult, Stop,
    /// Error. Adding a variant silently changes RunEventLog persistence
    /// shape + every match block; a test pins this so the addition
    /// surfaces at PR review.
    pub const VARIANT_COUNT: usize = 6;

    /// Build a `MalformedToolCall` event from a `ToolCallError`. Keeps
    /// the executor / dispatcher from open-coding the conversion at
    /// every rejection site.
    #[must_use]
    pub fn from_tool_call_error(err: &ToolCallError) -> Self {
        Self::Error {
            kind: AgentEventErrorKind::MalformedToolCall,
            message: format!("{err:?}"),
        }
    }

    /// Build a terminal `Stop` event with the given reason. Convenience
    /// for executors so the rejection / completion sites don't have to
    /// open-code the struct shape — and the literal `AgentEvent::Stop
    /// { reason }` doesn't sprinkle across the codebase.
    #[must_use]
    pub const fn stop(reason: StopReason) -> Self {
        Self::Stop { reason }
    }

    /// True iff this event terminates the executor stream: a `Stop`
    /// (typed completion) or `Error` (typed failure). Stream consumers
    /// call this to break iteration without pattern-matching the full
    /// taxonomy. Phase 1 hardening — extension of the "every state
    /// transition is a typed event" invariant.
    #[must_use]
    pub const fn is_terminal(&self) -> bool {
        matches!(self, Self::Stop { .. } | Self::Error { .. })
    }

    /// Build a terminal `Error` event with a typed error kind and a
    /// human-readable message. Symmetric to [`Self::stop`] — keeps
    /// rejection sites from open-coding the struct shape.
    #[must_use]
    pub fn error(kind: AgentEventErrorKind, message: impl Into<String>) -> Self {
        Self::Error {
            kind,
            message: message.into(),
        }
    }

    /// Concatenate every `ReasoningDelta` text field from a slice of
    /// events into a single `String`. Replay / display callers use
    /// this to reconstruct the complete reasoning trace without
    /// walking the slice themselves. Non-reasoning events are
    /// skipped. O(n) in slice length.
    #[must_use]
    pub fn concat_reasoning_text(events: &[Self]) -> String {
        let mut out = String::new();
        for event in events {
            if let Self::ReasoningDelta { text } = event {
                out.push_str(text);
            }
        }
        out
    }

    /// Concatenate every `FinalText` delta from a slice of events
    /// into a single `String`. Symmetric to
    /// [`Self::concat_reasoning_text`]; reconstructs the complete
    /// final answer body without walking the slice manually.
    #[must_use]
    pub fn concat_final_text(events: &[Self]) -> String {
        let mut out = String::new();
        for event in events {
            if let Self::FinalText { text } = event {
                out.push_str(text);
            }
        }
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn malformed_tool_call_becomes_error_event() {
        let bad = ToolCall {
            name: String::new(),
            arguments: serde_json::json!({}),
        };
        let err = bad.validate().expect_err("empty name rejected");
        let event = AgentEvent::from_tool_call_error(&err);
        match event {
            AgentEvent::Error { kind, message } => {
                assert_eq!(kind, AgentEventErrorKind::MalformedToolCall);
                assert!(message.contains("EmptyName"), "message: {message}");
            }
            other => panic!("expected Error event, got {other:?}"),
        }
    }

    #[test]
    fn event_variants_round_trip_through_json() {
        let cases = vec![
            AgentEvent::ReasoningDelta { text: "think".into() },
            AgentEvent::FinalText { text: "answer".into() },
            AgentEvent::ToolCall {
                call: ToolCall {
                    name: "vault.read".into(),
                    arguments: serde_json::json!({"path": "a"}),
                },
            },
            AgentEvent::ToolResult {
                name: "vault.read".into(),
                result: serde_json::json!({"ok": true}),
            },
            AgentEvent::Stop { reason: StopReason::EndTurn },
            AgentEvent::Error {
                kind: AgentEventErrorKind::Provider,
                message: "transport".into(),
            },
        ];
        for event in cases {
            let s = serde_json::to_string(&event).expect("serialize");
            let back: AgentEvent = serde_json::from_str(&s).expect("deserialize");
            assert_eq!(back, event);
        }
    }

    #[test]
    fn is_terminal_returns_true_for_stop_and_error_only() {
        // Stop + Error terminate; all other variants continue the stream.
        assert!(AgentEvent::Stop { reason: StopReason::EndTurn }.is_terminal());
        assert!(AgentEvent::Stop { reason: StopReason::BudgetExhausted }.is_terminal());
        assert!(AgentEvent::Error {
            kind: AgentEventErrorKind::Provider,
            message: "x".into(),
        }
        .is_terminal());
        assert!(!AgentEvent::ReasoningDelta { text: "t".into() }.is_terminal());
        assert!(!AgentEvent::FinalText { text: "f".into() }.is_terminal());
        assert!(!AgentEvent::ToolCall {
            call: ToolCall {
                name: "vault.read".into(),
                arguments: serde_json::json!({}),
            },
        }
        .is_terminal());
        assert!(!AgentEvent::ToolResult {
            name: "vault.read".into(),
            result: serde_json::json!({}),
        }
        .is_terminal());
    }

    #[test]
    fn error_helper_produces_correct_variant_with_typed_kind_and_message() {
        let e = AgentEvent::error(AgentEventErrorKind::Provider, "transport failed");
        match e {
            AgentEvent::Error { kind, message } => {
                assert_eq!(kind, AgentEventErrorKind::Provider);
                assert_eq!(message, "transport failed");
            }
            other => panic!("expected Error variant, got {other:?}"),
        }
        // is_terminal continues to hold.
        let e2 = AgentEvent::error(AgentEventErrorKind::BudgetExhausted, "cap hit");
        assert!(e2.is_terminal());
    }

    #[test]
    fn agent_event_variant_count_is_six() {
        // Phase 1 hardening — closed enum size pin. Six variants
        // total: ReasoningDelta, FinalText, ToolCall, ToolResult,
        // Stop, Error. A future addition silently changes every
        // match block; this test surfaces it at PR review.
        assert_eq!(AgentEvent::VARIANT_COUNT, 6);
        // Cross-check: an exhaustive match over a representative
        // sample of each variant must compile without warning.
        let samples = [
            AgentEvent::ReasoningDelta { text: "x".into() },
            AgentEvent::FinalText { text: "x".into() },
            AgentEvent::ToolCall {
                call: ToolCall {
                    name: "n".into(),
                    arguments: serde_json::json!({}),
                },
            },
            AgentEvent::ToolResult {
                name: "n".into(),
                result: serde_json::json!({}),
            },
            AgentEvent::Stop { reason: StopReason::EndTurn },
            AgentEvent::Error {
                kind: AgentEventErrorKind::Provider,
                message: "x".into(),
            },
        ];
        assert_eq!(samples.len(), AgentEvent::VARIANT_COUNT);
    }

    #[test]
    fn agent_event_serde_tag_values_are_stable() {
        // Phase 1 hardening — replay parity guardrail. The serde
        // tag value for every AgentEvent variant must match a
        // canonical string. A rename would silently break
        // RunEventLog persistence + cross-version replay.
        let canon: &[(AgentEvent, &str)] = &[
            (AgentEvent::ReasoningDelta { text: "t".into() }, "reasoning_delta"),
            (AgentEvent::FinalText { text: "t".into() }, "final_text"),
            (
                AgentEvent::ToolCall {
                    call: ToolCall {
                        name: "vault.read".into(),
                        arguments: serde_json::json!({}),
                    },
                },
                "tool_call",
            ),
            (
                AgentEvent::ToolResult { name: "vault.read".into(), result: serde_json::json!({}) },
                "tool_result",
            ),
            (AgentEvent::Stop { reason: StopReason::EndTurn }, "stop"),
            (
                AgentEvent::Error {
                    kind: AgentEventErrorKind::Provider,
                    message: "x".into(),
                },
                "error",
            ),
        ];
        for (event, expected_tag) in canon {
            let s = serde_json::to_string(event).expect("serialise");
            let parsed: serde_json::Value = serde_json::from_str(&s).expect("reparse");
            let tag = parsed
                .get("event_type")
                .and_then(|v| v.as_str())
                .expect("event_type field missing");
            assert_eq!(tag, *expected_tag, "tag drift for {event:?}");
        }
    }

    #[test]
    fn agent_event_error_kind_serde_values_are_stable() {
        // Same guardrail for AgentEventErrorKind — closed taxonomy
        // persisted in RunEventLog rows.
        for (kind, expected) in &[
            (AgentEventErrorKind::MalformedToolCall, "malformed_tool_call"),
            (AgentEventErrorKind::BudgetExhausted, "budget_exhausted"),
            (AgentEventErrorKind::CapabilityDenied, "capability_denied"),
            (AgentEventErrorKind::Provider, "provider"),
        ] {
            let s = serde_json::to_string(kind).expect("serialise");
            // s comes back as a quoted JSON string; assert it equals
            // "expected" (with quotes).
            assert_eq!(s, format!("\"{expected}\""));
        }
    }

    #[test]
    fn concat_final_text_joins_only_final_deltas() {
        let events = [
            AgentEvent::ReasoningDelta { text: "skip-me".into() },
            AgentEvent::FinalText { text: "the ".into() },
            AgentEvent::ToolCall {
                call: ToolCall {
                    name: "x.y".into(),
                    arguments: serde_json::json!({}),
                },
            },
            AgentEvent::FinalText { text: "answer".into() },
            AgentEvent::Stop { reason: StopReason::EndTurn },
        ];
        assert_eq!(AgentEvent::concat_final_text(&events), "the answer");
    }

    #[test]
    fn concat_final_text_empty_slice_returns_empty_string() {
        assert_eq!(AgentEvent::concat_final_text(&[]), "");
    }

    #[test]
    fn concat_reasoning_text_joins_only_reasoning_deltas() {
        let events = [
            AgentEvent::ReasoningDelta { text: "Hello".into() },
            AgentEvent::FinalText { text: "skip me".into() },
            AgentEvent::ReasoningDelta { text: " world".into() },
            AgentEvent::ToolCall {
                call: ToolCall {
                    name: "x.y".into(),
                    arguments: serde_json::json!({}),
                },
            },
            AgentEvent::ReasoningDelta { text: "!".into() },
            AgentEvent::Stop { reason: StopReason::EndTurn },
        ];
        let combined = AgentEvent::concat_reasoning_text(&events);
        assert_eq!(combined, "Hello world!");
    }

    #[test]
    fn concat_reasoning_text_empty_slice_returns_empty_string() {
        assert_eq!(AgentEvent::concat_reasoning_text(&[]), "");
    }

    #[test]
    fn concat_reasoning_text_no_reasoning_returns_empty() {
        let events = [
            AgentEvent::FinalText { text: "answer".into() },
            AgentEvent::Stop { reason: StopReason::EndTurn },
        ];
        assert_eq!(AgentEvent::concat_reasoning_text(&events), "");
    }

    #[test]
    fn stop_helper_produces_correct_variant() {
        let s = AgentEvent::stop(StopReason::BudgetExhausted);
        match s {
            AgentEvent::Stop { reason } => {
                assert_eq!(reason, StopReason::BudgetExhausted);
            }
            other => panic!("expected Stop variant, got {other:?}"),
        }
    }

    #[test]
    fn stop_event_carries_typed_reason() {
        let s = AgentEvent::Stop { reason: StopReason::BudgetExhausted };
        match s {
            AgentEvent::Stop { reason } => assert_eq!(reason, StopReason::BudgetExhausted),
            _ => panic!(),
        }
    }
}
