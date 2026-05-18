//! `AnswerPacket` — the terminal artifact of a v2 mission run.
//!
//! Closes the canonical flow:
//!
//! ```text
//! AgentBlueprint → MissionPacket → AgentEvent stream → approval →
//! MutationEnvelope → RunEventLog → AnswerPacket
//! ```
//!
//! The packet binds the user-visible answer to its witness trail (the
//! `RunEventLog` root) and the stop reason so downstream callers can
//! tell `EndTurn` from `BudgetExhausted` etc. without re-walking the
//! event stream.

use serde::{Deserialize, Serialize};

use crate::cognitive_dag::node::Hash;

use super::blueprint::AgentBlueprintId;
use super::budget::BudgetLedger;
use super::para::StopReason;
use super::run_event_log::RunEventLog;

/// One citation row. Kept opaque on purpose so different executors can
/// supply different evidence shapes without expanding this struct.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Citation {
    pub source: String,
    pub locator: String,
}

impl Citation {
    /// Recommended maximum citations per `AnswerPacket`. The UI
    /// surfaces become unusable past this, and the JSON payload
    /// inflates the `RunEventLog` without proportional value. The
    /// runtime DOES NOT enforce this — it surfaces a soft warning
    /// via [`AnswerPacket::exceeds_recommended_citation_cap`]. Phase 1
    /// hardening boundary doc; iter-21.
    pub const MAX_RECOMMENDED_PER_PACKET: usize = 256;

    /// True iff the citation has both a non-empty source and a
    /// non-empty locator. The runtime never rejects a citation
    /// directly; callers use this to filter or warn on empty rows
    /// before persisting. Phase 1 hardening — citation shape
    /// validation surface.
    #[must_use]
    pub fn is_valid(&self) -> bool {
        !self.source.is_empty() && !self.locator.is_empty()
    }

    /// Ergonomic constructor from a `(source, locator)` tuple. Useful
    /// in tests and short call sites where the full struct literal
    /// reads noisier than `Citation::from(("vault/notes/a.md",
    /// "L42-L57"))`.
    #[must_use]
    pub fn from_tuple<S: Into<String>, L: Into<String>>(source: S, locator: L) -> Self {
        Self {
            source: source.into(),
            locator: locator.into(),
        }
    }

    /// Build a single display string of the form `source<sep>locator`
    /// for terminal / audit-log output. Examples:
    ///
    /// ```text
    /// cite.as_display_string(":")  → "vault/notes/2026/may/a.md:L42-L57"
    /// cite.as_display_string(" @ ") → "vault/notes/2026/may/a.md @ L42-L57"
    /// ```
    #[must_use]
    pub fn as_display_string(&self, separator: &str) -> String {
        format!("{}{}{}", self.source, separator, self.locator)
    }
}

/// Terminal artifact of a mission run.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AnswerPacket {
    pub blueprint_id: AgentBlueprintId,
    /// Concatenation of every `AgentEvent::FinalText` delta from the
    /// stream. Producer-owned — we do not validate the text content,
    /// only that the stop reason and witness root accompany it.
    pub final_text: String,
    pub citations: Vec<Citation>,
    pub stop_reason: StopReason,
    /// Final budget ledger after every debit. Lets the caller display
    /// `tokens_used / max_tokens` without rebuilding from the log.
    pub final_ledger: BudgetLedger,
    /// BLAKE3 root over the `RunEventLog` at packet-emit time. Replay
    /// must reproduce this hash bit-for-bit.
    pub run_event_log_root: Hash,
    /// BLAKE3 digest over the **thinking-block bytes** the executor
    /// emitted (from `ParaOutput::thinking_digest`). Honors the
    /// `CLAUDE.md` non-negotiable *"PRESERVE THINKING BLOCKS. When
    /// stop_reason is tool_use, pass the ENTIRE content array back
    /// including thinking blocks + signatures."* End-to-end audit:
    /// `ParaOutput::thinking_digest` → `AnswerPacket::thinking_digest`
    /// must equal a BLAKE3 of the producer's thinking bytes.
    /// Zero-hash (`Hash::zero()`) means no thinking content for this
    /// run — never tamper this field; emit `Hash::zero()` honestly.
    #[serde(default = "Hash::zero")]
    pub thinking_digest: Hash,
}

impl std::fmt::Display for AnswerPacket {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "AnswerPacket{{blueprint={}, stop={:?}, tokens={}, citations={}}}",
            self.blueprint_id,
            self.stop_reason,
            self.final_ledger.tokens_used,
            self.citations.len()
        )
    }
}

impl AnswerPacket {
    /// Build an `AnswerPacket` from the final state of a run.
    /// `run_event_log_root` is captured here (callers pass the log so
    /// the hash is computed against the final state — never half-way).
    /// `thinking_digest` defaults to `Hash::zero()`; callers with
    /// thinking blocks should use `emit_with_thinking` instead.
    #[must_use]
    pub fn emit(
        blueprint_id: AgentBlueprintId,
        final_text: String,
        citations: Vec<Citation>,
        stop_reason: StopReason,
        final_ledger: BudgetLedger,
        run_event_log: &RunEventLog,
    ) -> Self {
        Self {
            blueprint_id,
            final_text,
            citations,
            stop_reason,
            final_ledger,
            run_event_log_root: run_event_log.root_hash(),
            thinking_digest: Hash::zero(),
        }
    }

    /// True if the citation list exceeds the recommended cap
    /// ([`Citation::MAX_RECOMMENDED_PER_PACKET`]). Callers may use
    /// this to surface a soft UI warning. The packet is NOT rejected
    /// by the runtime — payload size is the only consequence.
    #[must_use]
    pub fn exceeds_recommended_citation_cap(&self) -> bool {
        self.citations.len() > Citation::MAX_RECOMMENDED_PER_PACKET
    }

    /// True iff the run terminated unhappily (`Error`, `Refusal`,
    /// `CapabilityDenied`, or `BudgetExhausted`). UI surfaces use
    /// this to render the answer with a distinctive style; audit
    /// dashboards use it to filter for problematic runs.
    #[must_use]
    pub const fn was_terminated_by_error(&self) -> bool {
        matches!(
            self.stop_reason,
            StopReason::Error
                | StopReason::Refusal
                | StopReason::CapabilityDenied
                | StopReason::BudgetExhausted
        )
    }

    /// True iff this packet represents a "clean" run: stop_reason is
    /// `EndTurn` (typed graceful completion) and `was_terminated_by_error`
    /// is false. Inverse of `was_terminated_by_error` for the EndTurn
    /// case, but ALSO false for `ToolUse` / `MaxTokens` (which are
    /// non-error but also non-terminal-graceful — the executor cut the
    /// run short). Use this when a downstream consumer (e.g. a chat
    /// log) only wants to surface fully-completed answers.
    ///
    /// Phase 1 hardening — UI / audit-surface convenience.
    #[must_use]
    pub const fn is_clean_termination(&self) -> bool {
        matches!(self.stop_reason, StopReason::EndTurn)
    }

    /// True iff the answer has neither final text nor citations.
    /// Convenience for UI surfaces that want to render "the run
    /// produced nothing useful" (e.g. immediate-reject, capability
    /// denial before any tokens emit). Independent of stop_reason —
    /// an EndTurn run with empty body is still empty.
    #[must_use]
    pub fn is_empty_run(&self) -> bool {
        self.final_text.is_empty() && self.citations.is_empty()
    }

    /// Compute `tokens_used / max_tokens` as a ratio in `[0.0, 1.0+]`
    /// for progress-bar rendering. Returns `None` if `max_tokens`
    /// is zero (unbounded — no meaningful ratio). Saturates above
    /// 1.0 if the ledger over-shot the cap (defensive — the gate
    /// prevents this, but the helper doesn't trust it).
    #[must_use]
    pub fn token_usage_ratio(&self, spec: &super::budget::BudgetSpec) -> Option<f64> {
        if spec.max_tokens == 0 {
            return None;
        }
        let used = self.final_ledger.tokens_used as f64;
        let cap = spec.max_tokens as f64;
        Some(used / cap)
    }

    /// Emit with an explicit `thinking_digest` lifted from the
    /// terminal `ParaOutput::thinking_digest`. Callers MUST use this
    /// path when the run produced thinking content; otherwise replay
    /// cannot prove the executor preserved the thinking bytes
    /// verbatim through the run.
    #[must_use]
    pub fn emit_with_thinking(
        blueprint_id: AgentBlueprintId,
        final_text: String,
        citations: Vec<Citation>,
        stop_reason: StopReason,
        final_ledger: BudgetLedger,
        run_event_log: &RunEventLog,
        thinking_digest: Hash,
    ) -> Self {
        Self {
            blueprint_id,
            final_text,
            citations,
            stop_reason,
            final_ledger,
            run_event_log_root: run_event_log.root_hash(),
            thinking_digest,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::agent_runtime_v2::budget::{BudgetDebit, BudgetLedger};
    use crate::agent_runtime_v2::event::AgentEvent;

    #[test]
    fn answer_packet_emitted_with_typed_stop_reason() {
        // §4 T11 acceptance: "AnswerPacket emitted". Run a mock flow,
        // append events to the log, emit the packet, and assert the
        // stop reason + witness root are present and consistent.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "think".into() });
        log.append_event(AgentEvent::FinalText { text: "the answer".into() });
        log.append_sealed_mutation(
            Hash::from_bytes([3u8; 32]),
            BudgetDebit { tokens: 25, ..Default::default() },
        );
        log.append_ledger_snapshot(BudgetLedger {
            tokens_used: 25,
            ..Default::default()
        });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        let packet = AnswerPacket::emit(
            AgentBlueprintId("research-assistant".to_string()),
            "the answer".to_string(),
            vec![Citation {
                source: "vault/notes/2026/may/a.md".into(),
                locator: "L42-L57".into(),
            }],
            StopReason::EndTurn,
            BudgetLedger {
                tokens_used: 25,
                ..Default::default()
            },
            &log,
        );

        assert_eq!(packet.stop_reason, StopReason::EndTurn);
        assert_eq!(packet.final_text, "the answer");
        assert_eq!(packet.citations.len(), 1);
        assert_eq!(packet.final_ledger.tokens_used, 25);
        assert_eq!(packet.run_event_log_root, log.root_hash());
    }

    #[test]
    fn emit_and_emit_with_thinking_default_are_byte_equal_for_zero_digest() {
        // Phase 1 hardening — replay-parity invariant. The doc
        // contract on `emit` says: "thinking_digest defaults to
        // Hash::zero(); callers with thinking blocks should use
        // emit_with_thinking instead." Prove that contract:
        // emit(...) == emit_with_thinking(..., Hash::zero())
        // byte-for-byte. Any future drift (e.g. emit silently
        // computes a different default) would silently break
        // replay parity for runs without thinking content.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::FinalText { text: "x".into() });
        log.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });

        let blueprint = AgentBlueprintId("emit-equiv".to_string());
        let citations = vec![Citation {
            source: "v/p.md".into(),
            locator: "L1".into(),
        }];
        let ledger = BudgetLedger {
            tokens_used: 7,
            ..Default::default()
        };

        let via_emit = AnswerPacket::emit(
            blueprint.clone(),
            "x".to_string(),
            citations.clone(),
            StopReason::EndTurn,
            ledger.clone(),
            &log,
        );
        let via_explicit = AnswerPacket::emit_with_thinking(
            blueprint,
            "x".to_string(),
            citations,
            StopReason::EndTurn,
            ledger,
            &log,
            Hash::zero(),
        );
        assert_eq!(via_emit, via_explicit);
        // And serde round-trip parity: their JSON projections must
        // also match (catches any new field that one path forgot to
        // populate identically).
        assert_eq!(
            serde_json::to_string(&via_emit).expect("emit json"),
            serde_json::to_string(&via_explicit).expect("explicit json"),
        );
        // And the implicit default really is Hash::zero (defends
        // against a future refactor that swaps the default).
        assert_eq!(via_emit.thinking_digest, Hash::zero());
    }

    #[test]
    fn answer_packet_distinguishes_budget_exhausted_from_end_turn() {
        // Two runs with the same final_text but different stop_reasons
        // must produce distinguishable packets. This is what makes
        // StopReason load-bearing.
        let log = RunEventLog::new();
        let p_end = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "partial".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        let p_budget = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "partial".into(),
            vec![],
            StopReason::BudgetExhausted,
            BudgetLedger::default(),
            &log,
        );
        assert_ne!(p_end, p_budget);
        assert_eq!(p_end.run_event_log_root, p_budget.run_event_log_root);
        assert_ne!(p_end.stop_reason, p_budget.stop_reason);
    }

    #[test]
    fn answer_packet_witness_root_changes_when_log_changes() {
        let mut log_a = RunEventLog::new();
        log_a.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        let p_a = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log_a,
        );

        let mut log_b = RunEventLog::new();
        log_b.append_event(AgentEvent::ReasoningDelta { text: "extra".into() });
        log_b.append_event(AgentEvent::Stop { reason: StopReason::EndTurn });
        let p_b = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log_b,
        );

        assert_ne!(p_a.run_event_log_root, p_b.run_event_log_root);
    }

    #[test]
    fn thinking_blocks_preserved_para_output_to_answer_packet_end_to_end() {
        // End-to-end CLAUDE.md non-negotiable: thinking bytes must
        // flow ParaOutput → (via the run) → AnswerPacket unchanged.
        // We construct a ParaOutput with thinking bytes, lift its
        // thinking_digest into the AnswerPacket via emit_with_thinking,
        // then assert the digest equals an independent BLAKE3 over the
        // original bytes.
        use crate::agent_runtime_v2::para::{ParaOutput, StopReason};
        let thinking = b"<thinking>sig:0x42 derivation chain ...</thinking>".to_vec();
        let independent = *blake3::hash(&thinking).as_bytes();

        let para_out = ParaOutput::new(
            "the answer".to_string(),
            StopReason::EndTurn,
            Some(thinking.clone()),
        );
        assert_eq!(
            para_out.thinking_digest, independent,
            "ParaOutput::new must hash thinking bytes via BLAKE3"
        );

        let log = RunEventLog::new();
        let packet = AnswerPacket::emit_with_thinking(
            AgentBlueprintId("research-assistant".into()),
            para_out.value.clone(),
            vec![],
            para_out.stop_reason,
            BudgetLedger::default(),
            &log,
            Hash::from_bytes(para_out.thinking_digest),
        );

        assert_eq!(
            packet.thinking_digest.as_bytes(),
            &para_out.thinking_digest,
            "AnswerPacket.thinking_digest must equal ParaOutput.thinking_digest"
        );
        assert_eq!(
            packet.thinking_digest.as_bytes(),
            &independent,
            "AnswerPacket.thinking_digest must equal an independent BLAKE3 recompute"
        );

        // Round-trip via JSON to prove RunEventLog/persistence path
        // does not lose the field.
        let s = serde_json::to_string(&packet).expect("serialize");
        let back: AnswerPacket = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(back.thinking_digest, packet.thinking_digest);
    }

    #[test]
    fn hash_zero_default_for_thinking_digest_is_literal_all_zero_bytes() {
        // Phase 1 hardening — pin the Hash::zero binding so a
        // future Hash::zero rename / re-impl doesn't silently
        // change the AnswerPacket.thinking_digest default value.
        // The JSON serialised representation of a zero hash must
        // be 32 hex zeros (the cognitive_dag::node::Hash impl uses
        // #[serde(transparent)] so it serialises as its inner
        // [u8;32]).
        let log = RunEventLog::new();
        let packet = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        assert_eq!(packet.thinking_digest, Hash::zero());
        assert_eq!(packet.thinking_digest.as_bytes(), &[0u8; 32]);
    }

    #[test]
    fn emit_defaults_thinking_digest_to_zero() {
        let log = RunEventLog::new();
        let packet = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        assert_eq!(packet.thinking_digest, Hash::zero());
    }

    #[test]
    fn answer_packet_display_preserves_unicode_in_blueprint_id() {
        // Phase 1 hardening — Unicode safety pin for the Display
        // impl (companion to iter-205 Citation::as_display_string
        // Unicode pin). AnswerPacket::Display uses format! with
        // self.blueprint_id slotted in via its Display impl
        // (AgentBlueprintId::Display writes inner String verbatim).
        // Unicode blueprint ids must survive byte-equal in the log
        // line output.
        let log = RunEventLog::new();
        let packet = AnswerPacket::emit(
            AgentBlueprintId("研究助手-α🚀".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        let display = format!("{packet}");
        assert!(
            display.contains("blueprint=研究助手-α🚀"),
            "Unicode blueprint_id must survive in Display output: {display}"
        );
        // Full shape still matches the documented format.
        assert_eq!(
            display,
            "AnswerPacket{blueprint=研究助手-α🚀, stop=EndTurn, tokens=0, citations=0}"
        );
    }

    #[test]
    fn answer_packet_display_surfaces_only_tokens_axis_from_5_axis_ledger() {
        // Phase 1 hardening — doctrine pin. AnswerPacket::Display
        // intentionally surfaces ONLY the tokens_used axis from the
        // 5-axis BudgetLedger (the other 4 axes — wall, tool_calls,
        // subprocess, memory — are omitted from the one-line log
        // summary to keep it short).
        //
        // This doctrine choice was unpinned. Existing
        // answer_packet_display_renders_summary_for_log_lines uses
        // a ledger with only tokens_used populated; it doesn't probe
        // whether non-zero other axes would silently appear.
        //
        // A future maintainer who "helpfully" added wall_ms or
        // tool_calls to Display would silently inflate every audit
        // log line. Pin the tokens-only doctrine.
        let log = RunEventLog::new();
        let packet = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "answer".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger {
                tokens_used: 42,
                wall_used_ms: 9_999,
                tool_calls_used: 7,
                subprocess_used_ms: 12_345,
                memory_bytes_used: 1_000_000,
            },
            &log,
        );
        let display = format!("{packet}");
        // tokens is present and equals 42.
        assert!(display.contains("tokens=42"));
        // The other 4 axes' values are NOT in the Display output.
        assert!(!display.contains("9999"), "wall_used_ms must not appear in {display}");
        assert!(!display.contains("12345"), "subprocess_used_ms must not appear in {display}");
        assert!(!display.contains("1000000"), "memory_bytes_used must not appear in {display}");
        // tool_calls_used=7 is also omitted; but "tokens=42" might
        // contain the digit "7" only if it appears in 42 — it doesn't.
        // The 4 omitted axes use distinct large values so any
        // accidental inclusion would surface as a different digit
        // sequence. Pin the exact output shape.
        assert_eq!(
            display,
            "AnswerPacket{blueprint=a, stop=EndTurn, tokens=42, citations=0}"
        );
    }

    #[test]
    fn answer_packet_display_renders_summary_for_log_lines() {
        // Phase 1 hardening — one-line log surface. Pin the field
        // ordering + omission of body text (final_text could be
        // 100KB+; Display intentionally truncates by NOT printing it
        // at all).
        let log = RunEventLog::new();
        let packet = AnswerPacket::emit(
            AgentBlueprintId("research-assistant".into()),
            "x".repeat(50_000),
            vec![
                Citation::from_tuple("s1", "l1"),
                Citation::from_tuple("s2", "l2"),
            ],
            StopReason::EndTurn,
            BudgetLedger {
                tokens_used: 1_337,
                ..Default::default()
            },
            &log,
        );
        let display = format!("{packet}");
        assert_eq!(
            display,
            "AnswerPacket{blueprint=research-assistant, stop=EndTurn, tokens=1337, citations=2}"
        );
        assert!(!display.contains("x"), "body must NOT appear in log line");
    }

    #[test]
    fn citation_serde_json_preserves_struct_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin extending iter-162
        // (presence + count) with field-order. Citation declares:
        // source, locator. A future reorder breaks the Swift
        // Citation mirror's byte-equal decoding.
        let c = Citation {
            source: "vault/a.md".into(),
            locator: "L42".into(),
        };
        let s = serde_json::to_string(&c).expect("serialise");
        let source_pos = s.find("\"source\":").expect("source key");
        let locator_pos = s.find("\"locator\":").expect("locator key");
        assert!(
            source_pos < locator_pos,
            "source field must appear before locator in {s}"
        );
    }

    #[test]
    fn citation_serde_json_contains_all_two_canonical_top_level_keys() {
        // Phase 1 hardening — wire-shape pin matching the established
        // pattern. Citation has 2 top-level fields (source, locator);
        // a silent rename would round-trip but break vault audit
        // consumers and the Swift Citation mirror.
        let c = Citation {
            source: "vault/a.md".into(),
            locator: "L42".into(),
        };
        let json = serde_json::to_value(&c).expect("serialise");
        let obj = json.as_object().expect("Citation serialises as JSON object");
        for key in ["source", "locator"] {
            assert!(
                obj.contains_key(key),
                "missing top-level key {key:?} in {json:?}"
            );
        }
        assert_eq!(
            obj.len(),
            2,
            "expected exactly 2 top-level keys, got {} ({:?})",
            obj.len(),
            obj.keys().collect::<Vec<_>>()
        );
    }

    #[test]
    fn citation_as_display_string_concatenates_with_separator() {
        let c = Citation {
            source: "vault/notes/2026/may/a.md".into(),
            locator: "L42-L57".into(),
        };
        assert_eq!(
            c.as_display_string(":"),
            "vault/notes/2026/may/a.md:L42-L57"
        );
        assert_eq!(
            c.as_display_string(" @ "),
            "vault/notes/2026/may/a.md @ L42-L57"
        );
        // Empty separator just concatenates.
        assert_eq!(
            c.as_display_string(""),
            "vault/notes/2026/may/a.mdL42-L57"
        );
    }

    #[test]
    fn citation_as_display_string_preserves_unicode_in_source_locator_and_separator() {
        // Phase 1 hardening — Unicode safety pin for the display
        // helper. The function uses format! with raw String slots
        // for source / locator / separator — Unicode in any of the
        // three components must survive byte-equal.
        //
        // Companion to iter-99 (MissionPacket Unicode round-trip)
        // and iter-203 (vault_persistence_path Unicode preservation).
        //
        // The existing tests use ASCII strings only.
        let c = Citation {
            source: "vault/notes/2026年5月/note.md".into(),
            locator: "行42-行57".into(),
        };
        assert_eq!(
            c.as_display_string(" → "),
            "vault/notes/2026年5月/note.md → 行42-行57"
        );
        // Emoji separator.
        assert_eq!(
            c.as_display_string("🔗"),
            "vault/notes/2026年5月/note.md🔗行42-行57"
        );
        // RTL script in locator.
        let arabic = Citation {
            source: "كتاب".into(),
            locator: "ص٤٢".into(),
        };
        assert_eq!(arabic.as_display_string(":"), "كتاب:ص٤٢");
        // Mixed: Latin source + CJK separator + Cyrillic locator.
        let mixed = Citation {
            source: "Book".into(),
            locator: "Глава 5".into(),
        };
        assert_eq!(mixed.as_display_string("←"), "Book←Глава 5");
    }

    #[test]
    fn citation_as_display_string_handles_empty_source_and_empty_locator_without_panic() {
        // Phase 1 hardening — defensive boundary. as_display_string
        // concatenates source + separator + locator; if either is
        // empty, the result must be a sensible string with no panic.
        // Mirrors what the UI would render for a malformed (but
        // technically constructible) citation. Calling is_valid()
        // is the caller's responsibility — display is for diagnostic
        // log lines that may show invalid citations.
        let empty_source = Citation {
            source: "".into(),
            locator: "L1-L9".into(),
        };
        assert_eq!(empty_source.as_display_string(":"), ":L1-L9");
        assert_eq!(empty_source.as_display_string(""), "L1-L9");

        let empty_locator = Citation {
            source: "vault/notes/x.md".into(),
            locator: "".into(),
        };
        assert_eq!(empty_locator.as_display_string(":"), "vault/notes/x.md:");
        assert_eq!(empty_locator.as_display_string(""), "vault/notes/x.md");

        // Both empty — separator stands alone.
        let both_empty = Citation { source: "".into(), locator: "".into() };
        assert_eq!(both_empty.as_display_string(":"), ":");
        assert_eq!(both_empty.as_display_string(""), "");
    }

    #[test]
    fn citation_is_valid_rejects_empty_fields() {
        let good = Citation {
            source: "vault/notes/2026/may/a.md".into(),
            locator: "L42-L57".into(),
        };
        assert!(good.is_valid());
        let no_source = Citation {
            source: "".into(),
            locator: "L42".into(),
        };
        assert!(!no_source.is_valid());
        let no_locator = Citation {
            source: "src".into(),
            locator: "".into(),
        };
        assert!(!no_locator.is_valid());
        let both_empty = Citation {
            source: "".into(),
            locator: "".into(),
        };
        assert!(!both_empty.is_valid());
    }

    #[test]
    fn every_citation_field_is_identity_load_bearing() {
        // Phase 1 hardening — twelfth leg of the identity-pin
        // pattern. Citation has 2 fields (source, locator); each
        // must participate in PartialEq derivation. Citations land
        // inside AnswerPacket::citations vectors AND inside the
        // sealed_mutations() audit trail — duplicate detection at
        // both sites depends on byte-equal equality of both fields.
        let base = Citation {
            source: "vault/notes/2026/may/a.md".into(),
            locator: "L42-L57".into(),
        };

        let mut diff_source = base.clone();
        diff_source.source = "vault/notes/2026/may/b.md".into();
        assert_ne!(diff_source, base, "source must participate in PartialEq");

        let mut diff_locator = base.clone();
        diff_locator.locator = "L99-L100".into();
        assert_ne!(diff_locator, base, "locator must participate in PartialEq");

        // Sanity preserved.
        assert_eq!(base.clone(), base);
    }

    #[test]
    fn citation_is_valid_treats_whitespace_only_strings_as_valid_per_doctrine() {
        // Phase 1 hardening — boundary pin: is_valid() checks
        // !is_empty() exactly. The doctrine ("non-empty source and
        // non-empty locator") deliberately does NOT trim — a future
        // refactor that silently added `.trim().is_empty()` would
        // tighten the contract without callers noticing.
        //
        // Surface that the contract is "byte-level non-empty",
        // not "non-blank". Locators are commonly things like
        // `L42-L57`, but a producer could emit unusual whitespace
        // for a chat-window citation (`"  "` as a placeholder)
        // and the runtime must NOT reject it via this helper.
        let whitespace_source = Citation {
            source: "   ".into(),
            locator: "L42".into(),
        };
        assert!(
            whitespace_source.is_valid(),
            "whitespace-only source must count as valid per non-empty doctrine"
        );
        let whitespace_locator = Citation {
            source: "vault/notes/a.md".into(),
            locator: "\t".into(),
        };
        assert!(whitespace_locator.is_valid());
        let whitespace_both = Citation {
            source: "\n\n".into(),
            locator: " ".into(),
        };
        assert!(whitespace_both.is_valid());
        // Sanity preserved: a single non-whitespace character per
        // side is still valid.
        let minimal = Citation {
            source: "a".into(),
            locator: "b".into(),
        };
        assert!(minimal.is_valid());
    }

    #[test]
    fn is_empty_run_returns_true_only_when_text_and_citations_both_empty() {
        let log = RunEventLog::new();
        let empty = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "".into(),
            vec![],
            StopReason::CapabilityDenied,
            BudgetLedger::default(),
            &log,
        );
        assert!(empty.is_empty_run());

        let with_text = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "an answer".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        assert!(!with_text.is_empty_run());

        let with_citations = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "".into(),
            vec![Citation::from_tuple("src", "loc")],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        assert!(!with_citations.is_empty_run());
    }

    #[test]
    fn is_empty_run_treats_whitespace_only_final_text_as_non_empty_per_doctrine() {
        // Phase 1 hardening — DOCTRINE PIN, symmetric companion to
        // citation_is_valid_treats_whitespace_only_strings_as_valid_per_doctrine
        // (iter-72). is_empty_run's contract is
        // "final_text.is_empty() && citations.is_empty()" — byte-level
        // is_empty(), NOT is_blank(). A future "let me trim before
        // checking" refactor would silently start treating
        // whitespace-only / newline-only answer bodies as empty
        // runs, hiding answers from the UI surface.
        //
        // Pin the byte-level doctrine: whitespace IS content.
        let log = RunEventLog::new();
        for whitespace_text in [" ", "\n", "\t", "   \n\t  ", " \r\n "] {
            let packet = AnswerPacket::emit(
                AgentBlueprintId("ws-run".into()),
                whitespace_text.to_string(),
                vec![],
                StopReason::EndTurn,
                BudgetLedger::default(),
                &log,
            );
            assert!(
                !packet.is_empty_run(),
                "whitespace-only final_text {whitespace_text:?} must count as non-empty per byte-level doctrine"
            );
        }
        // Sanity: a truly empty body with no citations IS empty.
        let truly_empty = AnswerPacket::emit(
            AgentBlueprintId("ws-run".into()),
            "".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        assert!(truly_empty.is_empty_run());
    }

    #[test]
    fn token_usage_ratio_returns_used_over_cap() {
        use crate::agent_runtime_v2::budget::BudgetSpec;
        let log = RunEventLog::new();
        let packet = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger {
                tokens_used: 250,
                ..Default::default()
            },
            &log,
        );
        let spec = BudgetSpec::new(1_000, 0, 0, 0);
        let ratio = packet.token_usage_ratio(&spec).expect("bounded cap");
        assert!((ratio - 0.25).abs() < 1e-9, "ratio = {ratio}");
        // Unbounded cap → None.
        let unbounded = BudgetSpec::default();
        assert_eq!(packet.token_usage_ratio(&unbounded), None);
    }

    #[test]
    fn token_usage_ratio_at_zero_used_and_at_exactly_cap_boundary() {
        // Phase 1 hardening — boundary completeness for the progress-
        // bar helper. Two cases the existing tests don't pin:
        //   (1) tokens_used = 0 with a bounded cap → Some(0.0)
        //   (2) tokens_used == cap exactly → Some(1.0) (the gate
        //       admits the final debit that lands on the cap; the
        //       helper must reflect the bar with no float drift)
        use crate::agent_runtime_v2::budget::BudgetSpec;
        let log = RunEventLog::new();

        let zero_used = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger { tokens_used: 0, ..Default::default() },
            &log,
        );
        let spec_bounded = BudgetSpec::new(500, 0, 0, 0);
        let r0 = zero_used.token_usage_ratio(&spec_bounded).expect("bounded");
        assert!(r0.abs() < 1e-12, "zero/N must be exactly 0.0, got {r0}");

        let exact_cap = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger { tokens_used: 500, ..Default::default() },
            &log,
        );
        let r1 = exact_cap.token_usage_ratio(&spec_bounded).expect("bounded");
        assert!((r1 - 1.0).abs() < 1e-12, "exact cap must be 1.0, got {r1}");
    }

    #[test]
    fn token_usage_ratio_saturates_above_one_when_overshot() {
        use crate::agent_runtime_v2::budget::BudgetSpec;
        let log = RunEventLog::new();
        let packet = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::BudgetExhausted,
            BudgetLedger {
                tokens_used: 1_200,
                ..Default::default()
            },
            &log,
        );
        // Defensive — gate prevents this, but helper doesn't trust
        // it. 1200/1000 = 1.2 (NOT capped to 1.0 — the caller can
        // clamp if they want to).
        let spec = BudgetSpec::new(1_000, 0, 0, 0);
        let ratio = packet.token_usage_ratio(&spec).expect("bounded cap");
        assert!((ratio - 1.2).abs() < 1e-9);
    }

    #[test]
    fn citation_from_tuple_constructs_equivalent_struct() {
        let direct = Citation {
            source: "src".into(),
            locator: "loc".into(),
        };
        let from_tuple = Citation::from_tuple("src", "loc");
        assert_eq!(direct, from_tuple);
        // String args also work.
        let from_strings = Citation::from_tuple(String::from("src"), String::from("loc"));
        assert_eq!(direct, from_strings);
    }

    #[test]
    fn is_clean_termination_only_true_for_end_turn_and_disjoint_from_error_path() {
        // Phase 1 hardening — UI surface filter must distinguish
        // "fully-completed graceful run" (EndTurn) from BOTH the
        // unhappy errors AND the non-error-but-cut-short cases
        // (ToolUse, MaxTokens). The 7 stop_reason variants must
        // partition cleanly: only EndTurn returns true.
        let make = |reason: StopReason| AnswerPacket {
            blueprint_id: AgentBlueprintId("clean-term-fixture".into()),
            final_text: String::new(),
            citations: vec![],
            stop_reason: reason,
            final_ledger: BudgetLedger::default(),
            run_event_log_root: Hash::zero(),
            thinking_digest: Hash::zero(),
        };
        assert!(make(StopReason::EndTurn).is_clean_termination());
        for reason in [
            StopReason::ToolUse,
            StopReason::MaxTokens,
            StopReason::Refusal,
            StopReason::BudgetExhausted,
            StopReason::CapabilityDenied,
            StopReason::Error,
        ] {
            let p = make(reason);
            assert!(
                !p.is_clean_termination(),
                "stop_reason {reason:?} must NOT be a clean termination"
            );
            // Disjoint-with-error invariant: a clean run cannot also
            // be an error termination, and vice versa.
            assert!(
                !(p.is_clean_termination() && p.was_terminated_by_error()),
                "clean and error must be disjoint"
            );
        }
    }

    #[test]
    fn answer_packet_stop_reason_buckets_partition_seven_variants_exactly_once_each() {
        // Phase 1 hardening — cross-helper exhaustiveness pin
        // symmetric to the AgentEvent partition (iter-88). AnswerPacket
        // has 2 helpers (is_clean_termination, was_terminated_by_error)
        // that implicitly bucket every StopReason into one of three
        // categories:
        //   bucket A (clean=true, error=false):  EndTurn
        //   bucket B (clean=false, error=false): ToolUse, MaxTokens
        //   bucket C (clean=false, error=true):  Refusal,
        //                                        BudgetExhausted,
        //                                        CapabilityDenied,
        //                                        Error
        //
        // The existing is_clean_termination_only_* test pins disjoint
        // clean+error per individual variant inside a loop; the
        // was_terminated_by_error_matches test pins the error bucket
        // membership. Neither pins:
        //   - the FULL 7-variant partition with explicit bucket
        //     cardinality (1/2/4),
        //   - exhaustive iteration over EVERY variant of the closed
        //     StopReason taxonomy.
        //
        // A future StopReason addition that fell into 0 or 2 buckets
        // would slip past every existing test. This pin surfaces it.
        let make = |reason: StopReason| AnswerPacket {
            blueprint_id: AgentBlueprintId("partition-fixture".into()),
            final_text: String::new(),
            citations: vec![],
            stop_reason: reason,
            final_ledger: BudgetLedger::default(),
            run_event_log_root: Hash::zero(),
            thinking_digest: Hash::zero(),
        };
        let all_variants = [
            StopReason::EndTurn,
            StopReason::ToolUse,
            StopReason::MaxTokens,
            StopReason::Refusal,
            StopReason::BudgetExhausted,
            StopReason::CapabilityDenied,
            StopReason::Error,
        ];
        assert_eq!(all_variants.len(), 7, "StopReason has 7 variants");

        let mut bucket_clean = 0;
        let mut bucket_neither = 0;
        let mut bucket_error = 0;
        for &reason in &all_variants {
            let p = make(reason);
            let c = p.is_clean_termination();
            let e = p.was_terminated_by_error();
            // Mutual exclusion: a packet cannot be BOTH clean AND
            // error-terminated.
            assert!(
                !(c && e),
                "stop_reason {reason:?}: clean AND error both true — buckets must be disjoint"
            );
            match (c, e) {
                (true, false) => bucket_clean += 1,
                (false, false) => bucket_neither += 1,
                (false, true) => bucket_error += 1,
                (true, true) => unreachable!(),
            }
        }
        // Total membership equals variant count.
        assert_eq!(
            bucket_clean + bucket_neither + bucket_error,
            all_variants.len(),
            "buckets must partition the closed StopReason taxonomy"
        );
        // Pin the specific 1/2/4 cardinality (today's doctrine). A
        // future re-categorisation that shifts variants between
        // buckets surfaces at PR review.
        assert_eq!(bucket_clean, 1, "expected 1 clean variant (EndTurn)");
        assert_eq!(bucket_neither, 2, "expected 2 neither variants (ToolUse, MaxTokens)");
        assert_eq!(bucket_error, 4, "expected 4 error variants");
    }

    #[test]
    fn was_terminated_by_error_matches_unhappy_stop_reasons() {
        let log = RunEventLog::new();
        let happy = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        assert!(!happy.was_terminated_by_error());
        for unhappy in [
            StopReason::Error,
            StopReason::Refusal,
            StopReason::CapabilityDenied,
            StopReason::BudgetExhausted,
        ] {
            let p = AnswerPacket::emit(
                AgentBlueprintId("a".into()),
                "x".into(),
                vec![],
                unhappy,
                BudgetLedger::default(),
                &log,
            );
            assert!(
                p.was_terminated_by_error(),
                "stop_reason {unhappy:?} must be terminal-by-error"
            );
        }
        // ToolUse / MaxTokens are neither happy nor error — they're
        // pending/interrupted; current helper treats them as not
        // error.
        for neutral in [StopReason::ToolUse, StopReason::MaxTokens] {
            let p = AnswerPacket::emit(
                AgentBlueprintId("a".into()),
                "x".into(),
                vec![],
                neutral,
                BudgetLedger::default(),
                &log,
            );
            assert!(
                !p.was_terminated_by_error(),
                "stop_reason {neutral:?} is neutral, not error"
            );
        }
    }

    #[test]
    fn citation_cap_constant_is_256() {
        assert_eq!(Citation::MAX_RECOMMENDED_PER_PACKET, 256);
    }

    #[test]
    fn exceeds_recommended_citation_cap_flags_oversize_packet() {
        // Phase 1 hardening boundary — soft cap on citation list.
        let log = RunEventLog::new();
        let mut over = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        for i in 0..(Citation::MAX_RECOMMENDED_PER_PACKET + 1) {
            over.citations.push(Citation {
                source: format!("s{i}"),
                locator: format!("l{i}"),
            });
        }
        assert!(over.exceeds_recommended_citation_cap());

        // At-cap is not flagged (the cap is strict >).
        let mut at_cap = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        for i in 0..Citation::MAX_RECOMMENDED_PER_PACKET {
            at_cap.citations.push(Citation {
                source: format!("s{i}"),
                locator: format!("l{i}"),
            });
        }
        assert!(!at_cap.exceeds_recommended_citation_cap());
    }

    #[test]
    fn oversize_citation_packet_still_serialises() {
        // Cap is soft — the runtime does NOT reject an over-cap
        // packet; serialise/deserialise must still round-trip.
        let log = RunEventLog::new();
        let mut packet = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        for i in 0..1_000 {
            packet.citations.push(Citation {
                source: format!("s{i}"),
                locator: format!("l{i}"),
            });
        }
        let s = serde_json::to_string(&packet).expect("serialise oversize");
        let back: AnswerPacket = serde_json::from_str(&s).expect("deserialise oversize");
        assert_eq!(back.citations.len(), 1_000);
        assert!(back.exceeds_recommended_citation_cap());
    }

    #[test]
    fn answer_packet_emit_against_empty_log_captures_empty_log_root_hash() {
        // Phase 1 hardening — replay parity. An AnswerPacket emitted
        // before any events are appended must carry the empty-log
        // root_hash verbatim. A receiver that recomputes the empty
        // root and compares MUST agree (proves emit() reads the
        // CURRENT log state, not a stale snapshot).
        let log = RunEventLog::new();
        let expected_root = log.root_hash();
        let packet = AnswerPacket::emit(
            AgentBlueprintId("empty-run".into()),
            String::new(),
            vec![],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        assert_eq!(
            packet.run_event_log_root, expected_root,
            "emit must capture the live log root, not a stale value"
        );
        // The empty-log root is also stable across calls.
        let log2 = RunEventLog::new();
        assert_eq!(packet.run_event_log_root, log2.root_hash());
    }

    #[test]
    fn every_answer_packet_field_is_identity_load_bearing() {
        // Phase 1 hardening — symmetric companion to
        // every_blueprint_field_is_identity_load_bearing (blueprint.rs).
        // AnswerPacket has 7 fields:
        //   blueprint_id, final_text, citations, stop_reason,
        //   final_ledger, run_event_log_root, thinking_digest
        // Each must participate in PartialEq / Hash derivation so a
        // silent #[serde(skip)] or PartialEq override that dropped
        // ANY field would let two distinct packets compare equal.
        // The full-field round-trip test only proves SAME=SAME after
        // serde; it doesn't catch a derived-equality regression
        // where DIFFERENT packets are reported equal.
        let log = RunEventLog::new();
        let base = AnswerPacket::emit_with_thinking(
            AgentBlueprintId("identity-fixture".into()),
            "base text".into(),
            vec![Citation::from_tuple("s", "l")],
            StopReason::EndTurn,
            BudgetLedger {
                tokens_used: 100,
                wall_used_ms: 200,
                tool_calls_used: 1,
                subprocess_used_ms: 0,
                memory_bytes_used: 4096,
            },
            &log,
            Hash::from_bytes([7u8; 32]),
        );

        // Helper: clone base then mutate one field.
        let mut diff_blueprint = base.clone();
        diff_blueprint.blueprint_id = AgentBlueprintId("OTHER".into());
        assert_ne!(diff_blueprint, base, "blueprint_id must participate in PartialEq");

        let mut diff_text = base.clone();
        diff_text.final_text.push_str("X");
        assert_ne!(diff_text, base, "final_text must participate in PartialEq");

        let mut diff_citations = base.clone();
        diff_citations.citations.push(Citation::from_tuple("x", "y"));
        assert_ne!(diff_citations, base, "citations must participate in PartialEq");

        let mut diff_stop = base.clone();
        diff_stop.stop_reason = StopReason::Refusal;
        assert_ne!(diff_stop, base, "stop_reason must participate in PartialEq");

        let mut diff_ledger = base.clone();
        diff_ledger.final_ledger.tokens_used += 1;
        assert_ne!(diff_ledger, base, "final_ledger must participate in PartialEq");

        let mut diff_root = base.clone();
        diff_root.run_event_log_root = Hash::from_bytes([99u8; 32]);
        assert_ne!(diff_root, base, "run_event_log_root must participate in PartialEq");

        let mut diff_thinking = base.clone();
        diff_thinking.thinking_digest = Hash::zero();
        assert_ne!(diff_thinking, base, "thinking_digest must participate in PartialEq");

        // Sanity preserved: an unmodified clone still equals base.
        let same = base.clone();
        assert_eq!(same, base);
    }

    #[test]
    fn answer_packet_round_trips_through_json_with_full_field_coverage() {
        // Phase 1 hardening — replay-parity. The existing round-trip
        // uses minimal fixtures (one citation, default ledger,
        // EndTurn, zero thinking). This adversarial round-trip
        // exercises EVERY field with a non-default value:
        //   - 3 citations
        //   - non-default 5-axis ledger
        //   - BudgetExhausted stop_reason
        //   - non-zero thinking_digest (proves emit_with_thinking
        //     path serialises bit-exact)
        //   - non-empty final_text
        //   - non-zero run_event_log_root (log has appended events)
        // Any serde rename / skip / default that breaks ANY field
        // surfaces here as a back!=packet inequality.
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::ReasoningDelta { text: "r".into() });
        log.append_event(AgentEvent::FinalText { text: "answer".into() });
        log.append_event(AgentEvent::Stop { reason: StopReason::BudgetExhausted });

        let thinking = Hash::from_bytes([7u8; 32]);
        let packet = AnswerPacket::emit_with_thinking(
            AgentBlueprintId("adversarial".into()),
            "answer body".into(),
            vec![
                Citation { source: "s1".into(), locator: "l1".into() },
                Citation { source: "s2".into(), locator: "l2".into() },
                Citation { source: "s3".into(), locator: "l3".into() },
            ],
            StopReason::BudgetExhausted,
            BudgetLedger {
                tokens_used: 1234,
                wall_used_ms: 567,
                tool_calls_used: 8,
                subprocess_used_ms: 90,
                memory_bytes_used: 1_024_000,
            },
            &log,
            thinking,
        );
        let s = serde_json::to_string(&packet).expect("serialise");
        let back: AnswerPacket = serde_json::from_str(&s).expect("deserialise");
        assert_eq!(back, packet);
        // Spot-check that the field actually survived round-trip and
        // wasn't reset to default — defends against #[serde(skip)]
        // silently dropping a field while serde_json::from_str still
        // produces a "valid" packet with default values.
        assert_eq!(back.final_ledger.memory_bytes_used, 1_024_000);
        assert_eq!(back.thinking_digest, thinking);
        assert_ne!(back.run_event_log_root, Hash::zero());
        assert_eq!(back.citations.len(), 3);
        assert_eq!(back.stop_reason, StopReason::BudgetExhausted);
    }

    #[test]
    fn answer_packet_serde_tolerates_unknown_extra_fields_per_current_doctrine() {
        // Phase 1 hardening — symmetric companion to
        // blueprint::blueprint_serde_tolerates_unknown_extra_fields
        // (iter-121). AnswerPacket lands in vault audit / chat
        // history persistence; cross-version replay depends on
        // forward-compat (a v3 packet with an extra field must
        // still deserialise under v2 readers, dropping the extras).
        //
        // AnswerPacket does NOT carry #[serde(deny_unknown_fields)],
        // so serde_json's default IGNORE-unknown behaviour applies.
        // Pin it.
        let log = RunEventLog::new();
        let base = AnswerPacket::emit(
            AgentBlueprintId("forward-compat".into()),
            "answer".into(),
            vec![Citation::from_tuple("s", "l")],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        let s = serde_json::to_string(&base).expect("serialise");
        let augmented = s
            .trim_end_matches('}')
            .to_string()
            + r#","future_replay_field":"some-experimental-value"}"#;
        let parsed: AnswerPacket =
            serde_json::from_str(&augmented).expect("unknown field tolerated");
        // Unknown field silently dropped — round-trip equality holds.
        assert_eq!(parsed, base);
    }

    #[test]
    fn answer_packet_serde_json_preserves_struct_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin extending iter-155
        // (presence + count) with field-order. AnswerPacket
        // declares its 7 fields as:
        //   blueprint_id, final_text, citations, stop_reason,
        //   final_ledger, run_event_log_root, thinking_digest
        //
        // A future field reorder would change the byte-shape on
        // the wire — semantically equivalent but breaks byte-equal
        // diff tools and any cache-key consumer.
        let log = RunEventLog::new();
        let packet = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![Citation::from_tuple("s", "l")],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        let s = serde_json::to_string(&packet).expect("serialise");
        let expected_keys_in_order = [
            "\"blueprint_id\":",
            "\"final_text\":",
            "\"citations\":",
            "\"stop_reason\":",
            "\"final_ledger\":",
            "\"run_event_log_root\":",
            "\"thinking_digest\":",
        ];
        let mut last_idx: Option<usize> = None;
        for key in expected_keys_in_order {
            let pos = s.find(key).unwrap_or_else(|| panic!("key {key} not found in {s}"));
            if let Some(prev) = last_idx {
                assert!(
                    pos > prev,
                    "field {key} at byte {pos} must appear after previous field at {prev}"
                );
            }
            last_idx = Some(pos);
        }
    }

    #[test]
    fn answer_packet_serde_json_contains_all_seven_canonical_top_level_keys() {
        // Phase 1 hardening — wire-shape pin matching the pattern
        // (AgentBlueprint 5 keys, MissionPacket 3 keys iter-154).
        // AnswerPacket has 7 fields (blueprint_id, final_text,
        // citations, stop_reason, final_ledger, run_event_log_root,
        // thinking_digest); a silent rename would round-trip but
        // break vault audit readers + .epbundle consumers.
        let log = RunEventLog::new();
        let packet = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "x".into(),
            vec![Citation::from_tuple("s", "l")],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        let json = serde_json::to_value(&packet).expect("serialise");
        let obj = json.as_object().expect("AnswerPacket serialises as JSON object");
        for key in [
            "blueprint_id",
            "final_text",
            "citations",
            "stop_reason",
            "final_ledger",
            "run_event_log_root",
            "thinking_digest",
        ] {
            assert!(
                obj.contains_key(key),
                "missing top-level key {key:?} in {json:?}"
            );
        }
        assert_eq!(
            obj.len(),
            7,
            "expected exactly 7 top-level keys, got {} ({:?})",
            obj.len(),
            obj.keys().collect::<Vec<_>>()
        );
    }

    #[test]
    fn answer_packet_round_trips_through_json() {
        let log = RunEventLog::new();
        let packet = AnswerPacket::emit(
            AgentBlueprintId("a".into()),
            "hello".into(),
            vec![Citation {
                source: "src".into(),
                locator: "loc".into(),
            }],
            StopReason::EndTurn,
            BudgetLedger::default(),
            &log,
        );
        let s = serde_json::to_string(&packet).expect("serialize");
        let back: AnswerPacket = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(back, packet);
    }
}
