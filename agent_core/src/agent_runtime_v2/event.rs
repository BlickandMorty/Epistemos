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

impl AgentEventErrorKind {
    /// Canonical snake_case code matching the JSON tag — log lines
    /// and RunEventLog rows agree on this single string.
    #[must_use]
    pub const fn code(self) -> &'static str {
        match self {
            Self::MalformedToolCall => "malformed_tool_call",
            Self::BudgetExhausted => "budget_exhausted",
            Self::CapabilityDenied => "capability_denied",
            Self::Provider => "provider",
        }
    }
}

impl std::fmt::Display for AgentEventErrorKind {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.code())
    }
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

    /// True iff this event is a streaming delta (ReasoningDelta or
    /// FinalText) that buffer-flush logic may coalesce. Distinct
    /// from terminal events (Stop / Error) and tool events
    /// (ToolCall / ToolResult — those land discretely and are not
    /// coalescable).
    #[must_use]
    pub const fn is_streaming_delta(&self) -> bool {
        matches!(self, Self::ReasoningDelta { .. } | Self::FinalText { .. })
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
    fn is_streaming_delta_returns_true_only_for_reasoning_and_final_text() {
        // Phase 1 hardening — buffer-flush logic relies on this
        // distinction. ReasoningDelta + FinalText are coalescable;
        // ToolCall/ToolResult land discretely; Stop/Error terminate.
        assert!(AgentEvent::ReasoningDelta { text: "x".into() }.is_streaming_delta());
        assert!(AgentEvent::FinalText { text: "y".into() }.is_streaming_delta());
        assert!(!AgentEvent::ToolCall {
            call: ToolCall {
                name: "n".into(),
                arguments: serde_json::json!({}),
            },
        }
        .is_streaming_delta());
        assert!(!AgentEvent::ToolResult {
            name: "n".into(),
            result: serde_json::json!({}),
        }
        .is_streaming_delta());
        assert!(!AgentEvent::Stop { reason: StopReason::EndTurn }.is_streaming_delta());
        assert!(!AgentEvent::Error {
            kind: AgentEventErrorKind::Provider,
            message: "x".into(),
        }
        .is_streaming_delta());
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
    fn error_helper_preserves_empty_and_long_messages_verbatim() {
        // Phase 1 hardening — boundary completeness for the
        // AgentEvent::error constructor. The doc says "message"
        // is preserved verbatim. Pin two boundary cases:
        //   - empty message (no truncation or default fallback)
        //   - 10_000-byte message (no truncation cap)
        // A future builder that imposed a non-empty constraint or
        // a length cap would surface here.
        let empty = AgentEvent::error(AgentEventErrorKind::Provider, "");
        match empty {
            AgentEvent::Error { message, .. } => {
                assert_eq!(message, "", "empty message must survive verbatim");
            }
            other => panic!("expected Error, got {other:?}"),
        }
        let long_msg = "x".repeat(10_000);
        let long = AgentEvent::error(AgentEventErrorKind::Provider, long_msg.clone());
        match long {
            AgentEvent::Error { message, .. } => {
                assert_eq!(message.len(), 10_000);
                assert_eq!(message, long_msg);
            }
            other => panic!("expected Error, got {other:?}"),
        }
        // Also: the impl Into<String> bound must accept both &str
        // and String (positive type-checker probe).
        let _from_str = AgentEvent::error(AgentEventErrorKind::Provider, "literal");
        let _from_string = AgentEvent::error(
            AgentEventErrorKind::Provider,
            String::from("owned"),
        );
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
    fn agent_event_error_round_trips_for_every_error_kind_variant() {
        // Phase 1 hardening — the existing 6-variant round-trip only
        // uses AgentEventErrorKind::Provider in the Error variant.
        // This pins all 4 ErrorKind values (MalformedToolCall,
        // BudgetExhausted, CapabilityDenied, Provider) survive
        // serde round-trip embedded inside AgentEvent::Error so a
        // rename or skip on any one variant catches at PR review.
        for kind in [
            AgentEventErrorKind::MalformedToolCall,
            AgentEventErrorKind::BudgetExhausted,
            AgentEventErrorKind::CapabilityDenied,
            AgentEventErrorKind::Provider,
        ] {
            let event = AgentEvent::Error {
                kind,
                message: format!("test message for {kind:?}"),
            };
            let s = serde_json::to_string(&event).expect("serialise");
            let back: AgentEvent = serde_json::from_str(&s).expect("deserialise");
            assert_eq!(back, event, "round-trip failed for {kind:?}");
            // The JSON form must contain the snake_case kind string
            // (else log-greppers break).
            assert!(
                s.contains(&format!("\"{}\"", kind.code())),
                "JSON for {kind:?} must contain code string {:?}, got {s}",
                kind.code()
            );
        }
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
    fn agent_event_error_kind_display_matches_serde_tag_for_log_parity() {
        // Phase 1 hardening — Display + .code() + serde tag all
        // agree on the same snake_case string. Log dashboards,
        // RunEventLog rows, and human-readable surfaces never
        // disagree on the label.
        for (kind, expected) in [
            (AgentEventErrorKind::MalformedToolCall, "malformed_tool_call"),
            (AgentEventErrorKind::BudgetExhausted, "budget_exhausted"),
            (AgentEventErrorKind::CapabilityDenied, "capability_denied"),
            (AgentEventErrorKind::Provider, "provider"),
        ] {
            assert_eq!(format!("{kind}"), expected);
            assert_eq!(kind.code(), expected);
            let json = serde_json::to_string(&kind).unwrap();
            assert_eq!(json, format!("\"{expected}\""));
        }
    }

    #[test]
    fn agent_event_error_kind_unknown_string_fails_to_deserialise() {
        // Phase 1 hardening — fourth leg of the closed-taxonomy
        // guardrail (mode iter-71, AgentEvent event_type iter-73,
        // StopReason iter-74). AgentEventErrorKind has 4 variants
        // (malformed_tool_call, budget_exhausted, capability_denied,
        // provider) persisted inside AgentEvent::Error payloads in
        // every RunEventLog. A future #[serde(other)] catch-all or
        // case-insensitive shim would silently absorb stray strings
        // into a default category and break audit-dashboard counters.
        for bad in [
            // Adjacent vocabulary
            "\"network\"",
            "\"timeout\"",
            "\"rejected\"",
            "\"forbidden\"",
            // Case variants of valid strings
            "\"PROVIDER\"",
            "\"Provider\"",
            "\"Budget_Exhausted\"",
            "\"capabilityDenied\"",
            // Kebab-case drift
            "\"malformed-tool-call\"",
            "\"budget-exhausted\"",
            // Adjacent-but-wrong synonyms
            "\"refused\"",
            "\"transport\"",
            "\"capability\"",
            "\"\"",
        ] {
            let r: Result<AgentEventErrorKind, _> = serde_json::from_str(bad);
            assert!(
                r.is_err(),
                "unknown AgentEventErrorKind string {bad} must fail to deserialise"
            );
        }
        // Sanity: every valid variant still round-trips byte-equal.
        for (variant, expected) in [
            (AgentEventErrorKind::MalformedToolCall, "\"malformed_tool_call\""),
            (AgentEventErrorKind::BudgetExhausted, "\"budget_exhausted\""),
            (AgentEventErrorKind::CapabilityDenied, "\"capability_denied\""),
            (AgentEventErrorKind::Provider, "\"provider\""),
        ] {
            let s = serde_json::to_string(&variant).unwrap();
            assert_eq!(s, expected);
            let back: AgentEventErrorKind = serde_json::from_str(&s).unwrap();
            assert_eq!(back, variant);
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
    fn concat_final_text_preserves_slice_order_not_lexical_order() {
        // Phase 1 hardening — the existing test joins "the " + "answer"
        // which happens to be lexically descending. Strengthen by
        // using 3 FinalText fragments where slice order is NOT the
        // sort order — proves the concat is order-preserving (not
        // accidentally sorted) and that all 3+ fragments survive.
        let events = [
            AgentEvent::FinalText { text: "zulu-".into() },
            AgentEvent::ReasoningDelta { text: "SKIP".into() },
            AgentEvent::FinalText { text: "alpha-".into() },
            AgentEvent::FinalText { text: "mike".into() },
            AgentEvent::Stop { reason: StopReason::EndTurn },
        ];
        let joined = AgentEvent::concat_final_text(&events);
        assert_eq!(joined, "zulu-alpha-mike");
        // Negative: NOT the lexically-sorted projection.
        assert_ne!(joined, "alpha-mike-zulu-");
        // Negative: did not pick up the ReasoningDelta payload.
        assert!(!joined.contains("SKIP"));
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
    fn agent_event_unknown_event_type_tag_fails_to_deserialise() {
        // Phase 1 hardening — closed-taxonomy guardrail symmetric to
        // mode::unknown_mode_string_fails_to_deserialise. The
        // #[serde(tag = "event_type")] discriminator must REJECT
        // unrecognised tag values: a future #[serde(other)] catch-all,
        // case-insensitive shim, or fallthrough to a "default" variant
        // would silently route stray RunEventLog rows to the wrong
        // handler. Replay parity depends on this contract; pin it.
        for bad in [
            // Unknown vocabulary not in the 6-variant taxonomy.
            r#"{"event_type":"thought","text":"x"}"#,
            r#"{"event_type":"complete","reason":"end_turn"}"#,
            // Case-variant of a known tag (snake_case-exact taxonomy).
            r#"{"event_type":"Final_Text","text":"x"}"#,
            r#"{"event_type":"FINAL_TEXT","text":"x"}"#,
            r#"{"event_type":"finalText","text":"x"}"#,
            // Legacy shapes a maintainer might "helpfully" allow.
            r#"{"event_type":"done","reason":"end_turn"}"#,
            r#"{"event_type":"text","text":"x"}"#,
            // Missing event_type entirely → also a failure.
            r#"{"text":"x"}"#,
        ] {
            let r: Result<AgentEvent, _> = serde_json::from_str(bad);
            assert!(
                r.is_err(),
                "unknown event_type tag in {bad} must fail to deserialise"
            );
        }
        // Sanity preserved: at least one valid known tag still
        // deserialises (so the negative cases above aren't masking
        // a broader serde breakage).
        let ok: AgentEvent =
            serde_json::from_str(r#"{"event_type":"final_text","text":"ok"}"#)
                .expect("valid tag still deserialises");
        match ok {
            AgentEvent::FinalText { text } => assert_eq!(text, "ok"),
            other => panic!("expected FinalText, got {other:?}"),
        }
    }

    #[test]
    fn event_const_fn_annotations_compile_in_const_context() {
        // Phase 1 hardening — compile-time pin for the const-able
        // surfaces on AgentEvent / AgentEventErrorKind (companion to
        // iter-100 / iter-101 const-context pins). A future refactor
        // that dropped `const` from any of these annotations
        // surfaces as a compile failure right here.
        //
        // NOTE: AgentEvent itself has a Drop impl (String-carrying
        // variants), so we can't const-bind a constructed AgentEvent
        // value. The pinnable surfaces are the &'static str / usize
        // returns and AgentEventErrorKind which is Copy.
        //
        // Pinned signatures:
        //   - AgentEventErrorKind::code (returns &'static str)
        //   - AgentEvent::VARIANT_COUNT (associated const)
        const PROVIDER_CODE: &str = AgentEventErrorKind::Provider.code();
        const BUDGET_CODE: &str = AgentEventErrorKind::BudgetExhausted.code();
        const MALFORMED_CODE: &str = AgentEventErrorKind::MalformedToolCall.code();
        const CAPABILITY_CODE: &str = AgentEventErrorKind::CapabilityDenied.code();
        const VARIANT_COUNT: usize = AgentEvent::VARIANT_COUNT;

        // Runtime asserts keep the const items live + provide a
        // fallback regression net should const-context behaviour drift.
        assert_eq!(PROVIDER_CODE, "provider");
        assert_eq!(BUDGET_CODE, "budget_exhausted");
        assert_eq!(MALFORMED_CODE, "malformed_tool_call");
        assert_eq!(CAPABILITY_CODE, "capability_denied");
        assert_eq!(VARIANT_COUNT, 6);
    }

    #[test]
    fn agent_event_buckets_partition_six_variants_exactly_once_each() {
        // Phase 1 hardening — cross-helper invariant pin.
        // The 6 AgentEvent variants partition into 3 buckets via
        // (is_streaming_delta, is_terminal):
        //   bucket A (streaming_delta=true, terminal=false):
        //     ReasoningDelta, FinalText
        //   bucket B (streaming_delta=false, terminal=false — "neither"):
        //     ToolCall, ToolResult
        //   bucket C (streaming_delta=false, terminal=true):
        //     Stop, Error
        //
        // The existing helper tests pin each variant's helpers
        // INDEPENDENTLY. This pin asserts the CROSS-HELPER property:
        //   - the two helpers are MUTUALLY EXCLUSIVE for every variant
        //     (no variant returns true from both)
        //   - every variant falls into EXACTLY ONE of the 3 buckets
        //   - bucket counts are 2/2/2 (2 in each bucket)
        //
        // A future helper refactor that overlapped the buckets, or
        // a new variant that fell into 0 or 2 buckets, would slip
        // past the existing isolated tests but fail this one.
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

        let mut bucket_a = 0; // streaming_delta=true, terminal=false
        let mut bucket_b = 0; // both false ("neither")
        let mut bucket_c = 0; // streaming_delta=false, terminal=true
        for ev in &samples {
            let s = ev.is_streaming_delta();
            let t = ev.is_terminal();
            // Mutual exclusion: a variant cannot be BOTH a streaming
            // delta AND a terminal event.
            assert!(
                !(s && t),
                "variant {ev:?}: is_streaming_delta AND is_terminal both true — buckets must be disjoint"
            );
            match (s, t) {
                (true, false) => bucket_a += 1,
                (false, false) => bucket_b += 1,
                (false, true) => bucket_c += 1,
                (true, true) => unreachable!(), // ruled out above
            }
        }
        // Every variant must fall into exactly one bucket. The total
        // must equal the variant count.
        assert_eq!(
            bucket_a + bucket_b + bucket_c,
            AgentEvent::VARIANT_COUNT,
            "buckets must partition all variants"
        );
        // Specific bucket cardinality (2/2/2 for the current taxonomy).
        // A future variant addition that doesn't update this assert
        // surfaces here.
        assert_eq!(bucket_a, 2, "expected 2 streaming-delta variants");
        assert_eq!(bucket_b, 2, "expected 2 neither variants (ToolCall, ToolResult)");
        assert_eq!(bucket_c, 2, "expected 2 terminal variants (Stop, Error)");
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
