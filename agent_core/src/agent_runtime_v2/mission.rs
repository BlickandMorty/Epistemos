//! `MissionPacket` + `ToolCall` — the typed input to a v2 executor.
//!
//! `MissionPacket` is what crosses the v2 boundary: it names the
//! blueprint, the user prompt, and the vault scope. `ToolCall` is the
//! typed wrapper around any tool invocation an agent emits; its
//! `validate()` is the gate that produces the §4 T11
//! "malformed tool call rejected" rejection.

use serde::{Deserialize, Serialize};

use super::blueprint::AgentBlueprintId;

/// Typed mission input.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MissionPacket {
    pub blueprint_id: AgentBlueprintId,
    pub user_prompt: String,
    pub vault_scope: String,
}

impl std::fmt::Display for MissionPacket {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "MissionPacket{{blueprint={}, scope={}}}",
            self.blueprint_id, self.vault_scope
        )
    }
}

impl MissionPacket {
    /// Maximum prompt length we will accept. Beyond this, the executor
    /// rejects before touching the provider. Bound chosen to keep
    /// substrate latency budgets honest; tune as needed.
    pub const MAX_PROMPT_BYTES: usize = 128 * 1024;

    /// Ergonomic constructor: build a MissionPacket and validate the
    /// prompt in one call. Returns the packet on success; surfaces
    /// `MissionPromptError::OversizePrompt` if the prompt exceeds
    /// `MAX_PROMPT_BYTES`. Phase 1 hardening — callers no longer need
    /// to remember to call validate_prompt separately.
    pub fn new(
        blueprint_id: AgentBlueprintId,
        user_prompt: impl Into<String>,
        vault_scope: impl Into<String>,
    ) -> Result<Self, MissionPromptError> {
        let packet = Self {
            blueprint_id,
            user_prompt: user_prompt.into(),
            vault_scope: vault_scope.into(),
        };
        packet.validate_prompt()?;
        Ok(packet)
    }

    /// Validate the prompt against the byte cap. Phase 1 hardening:
    /// the runtime now enforces what was previously a doc-only
    /// constant. Callers should run this before threading the packet
    /// through the dispatcher.
    pub fn validate_prompt(&self) -> Result<(), MissionPromptError> {
        let len = self.user_prompt.len();
        if len > Self::MAX_PROMPT_BYTES {
            return Err(MissionPromptError::OversizePrompt {
                size: len,
                cap: Self::MAX_PROMPT_BYTES,
            });
        }
        Ok(())
    }
}

/// Errors surfaced by `MissionPacket::validate_prompt`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MissionPromptError {
    OversizePrompt { size: usize, cap: usize },
}

/// A single tool invocation produced by an executor stream. The runtime
/// `validate()`s before threading the call through the capability /
/// budget / envelope gates.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolCall {
    /// Canonical tool name — `<namespace>.<verb>` (e.g. `vault.read`).
    /// MUST be non-empty and contain only `[a-z0-9._-]`.
    pub name: String,
    /// JSON arguments. Whatever schema the named tool advertises;
    /// validated separately by the tool registry at dispatch time.
    pub arguments: serde_json::Value,
}

impl ToolCall {
    /// Maximum tool-name length in bytes. Bound chosen to cover the
    /// longest legitimate `<namespace>.<verb>` pattern (e.g. nested
    /// subsystem names) while still rejecting pathological inputs
    /// that would bloat the RunEventLog row.
    pub const MAX_NAME_BYTES: usize = 256;

    /// Maximum serialised argument size. Prevents a runaway tool call
    /// from blowing past the WBO substrate term.
    pub const MAX_ARGS_BYTES: usize = 64 * 1024;

    /// Validate the tool call shape. The runtime calls this BEFORE
    /// running the variant-ladder dispatch — a malformed call never
    /// reaches the registry.
    pub fn validate(&self) -> Result<(), ToolCallError> {
        if self.name.is_empty() {
            return Err(ToolCallError::EmptyName);
        }
        if self.name.len() > Self::MAX_NAME_BYTES {
            return Err(ToolCallError::OversizeName {
                size: self.name.len(),
                cap: Self::MAX_NAME_BYTES,
            });
        }
        for (idx, ch) in self.name.chars().enumerate() {
            let allowed = ch.is_ascii_alphanumeric() || ch == '.' || ch == '_' || ch == '-';
            if !allowed {
                return Err(ToolCallError::BadName {
                    name: self.name.clone(),
                    bad_char: ch,
                    index: idx,
                });
            }
        }
        // Reject leading/trailing dots and double-dots — defensive
        // against path-traversal-style names a provider might produce.
        if self.name.starts_with('.') || self.name.ends_with('.') {
            return Err(ToolCallError::BadName {
                name: self.name.clone(),
                bad_char: '.',
                index: 0,
            });
        }
        if self.name.contains("..") {
            return Err(ToolCallError::BadName {
                name: self.name.clone(),
                bad_char: '.',
                index: self.name.find("..").unwrap_or(0),
            });
        }
        let arg_bytes = serde_json::to_vec(&self.arguments)
            .map_err(|e| ToolCallError::BadArguments(e.to_string()))?;
        if arg_bytes.len() > Self::MAX_ARGS_BYTES {
            return Err(ToolCallError::OversizeArguments {
                size: arg_bytes.len(),
                cap: Self::MAX_ARGS_BYTES,
            });
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ToolCallError {
    EmptyName,
    BadName {
        name: String,
        bad_char: char,
        index: usize,
    },
    OversizeName {
        size: usize,
        cap: usize,
    },
    BadArguments(String),
    OversizeArguments {
        size: usize,
        cap: usize,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    fn good_call() -> ToolCall {
        ToolCall {
            name: "vault.read".to_string(),
            arguments: serde_json::json!({"path": "notes/2026/may"}),
        }
    }

    #[test]
    fn malformed_tool_call_rejected_empty_name() {
        // §4 T11 acceptance: "malformed tool call rejected".
        let bad = ToolCall {
            name: String::new(),
            arguments: serde_json::json!({}),
        };
        assert_eq!(bad.validate(), Err(ToolCallError::EmptyName));
    }

    #[test]
    fn malformed_tool_call_rejected_bad_chars() {
        let bad = ToolCall {
            name: "vault read".to_string(),
            arguments: serde_json::json!({}),
        };
        match bad.validate() {
            Err(ToolCallError::BadName { name, bad_char, index }) => {
                assert_eq!(name, "vault read");
                assert_eq!(bad_char, ' ');
                assert_eq!(index, 5);
            }
            other => panic!("expected BadName, got {other:?}"),
        }
    }

    #[test]
    fn malformed_tool_call_rejected_for_path_and_shell_injection_chars_in_name() {
        // Phase 1 hardening — adversarial-fixture pin (parallel to
        // thinking-bytes adversarial pin in para.rs). validate()'s
        // allow-list is alnum + `.` + `_` + `-`. Many common
        // path-traversal and shell-injection chars MUST be rejected:
        //
        //   path separators:    `/` `\`
        //   shell metas:        `;` `&` `|` `$` `!` `*` `?` `<` `>`
        //   quoting:            `"` `'` `` ` ``
        //   grouping:           `(` `)` `{` `}` `[` `]`
        //   misc unsafe:        `:` `,` `=`
        //
        // Pin all of these. A future "let me loosen validate() to
        // accept namespace separators like `/` for HTTP tool URIs"
        // refactor would silently open path-traversal vectors at
        // dispatch time.
        //
        // Defends against a regression where ToolCall names slip past
        // validate() and reach the variant_ladder dispatcher with
        // attacker-controlled separators.
        let adversarial_chars = [
            '/', '\\',
            ';', '&', '|', '$', '!', '*', '?', '<', '>',
            '"', '\'', '`',
            '(', ')', '{', '}', '[', ']',
            ':', ',', '=',
        ];
        for ch in adversarial_chars {
            let name = format!("vault{ch}read");
            let bad = ToolCall {
                name: name.clone(),
                arguments: serde_json::json!({}),
            };
            match bad.validate() {
                Err(ToolCallError::BadName { name: n, bad_char, index }) => {
                    assert_eq!(n, name, "BadName.name must echo input for {ch}");
                    assert_eq!(
                        bad_char, ch,
                        "BadName.bad_char must surface offending char {ch:?}"
                    );
                    assert_eq!(
                        index, 5,
                        "BadName.index must locate the offending char position for {ch:?}"
                    );
                }
                other => panic!(
                    "expected BadName for adversarial char {ch:?}, got {other:?}"
                ),
            }
        }
    }

    #[test]
    fn malformed_tool_call_rejected_leading_dot() {
        let bad = ToolCall {
            name: ".secret".to_string(),
            arguments: serde_json::json!({}),
        };
        assert!(matches!(bad.validate(), Err(ToolCallError::BadName { .. })));
    }

    #[test]
    fn malformed_tool_call_rejected_trailing_dot() {
        // Phase 1 hardening — symmetric companion to
        // malformed_tool_call_rejected_leading_dot. validate() checks
        // both `starts_with('.')` AND `ends_with('.')` for path-
        // traversal-style names. The leading-dot test is present;
        // the trailing-dot test was missing. A future refactor that
        // dropped `|| self.name.ends_with('.')` from the guard would
        // silently start accepting "vault." / "vault.read." names
        // that may resolve to unintended targets at dispatch time.
        let bad = ToolCall {
            name: "vault.".to_string(),
            arguments: serde_json::json!({}),
        };
        assert!(
            matches!(bad.validate(), Err(ToolCallError::BadName { .. })),
            "trailing-dot tool name must reject"
        );
        // Even with valid middle structure, the trailing dot trips:
        let bad2 = ToolCall {
            name: "vault.read.".to_string(),
            arguments: serde_json::json!({}),
        };
        assert!(matches!(bad2.validate(), Err(ToolCallError::BadName { .. })));
        // Single-char "." is both leading and trailing — must reject
        // (already implicitly covered by starts_with, but pin
        // explicitly for the boundary).
        let single_dot = ToolCall {
            name: ".".to_string(),
            arguments: serde_json::json!({}),
        };
        assert!(matches!(single_dot.validate(), Err(ToolCallError::BadName { .. })));
    }

    #[test]
    fn malformed_tool_call_rejected_for_non_ascii_unicode_chars_in_name() {
        // Phase 1 hardening — boundary completeness for the bad-
        // chars rejection path. The allowed-charset is ASCII-only:
        // is_ascii_alphanumeric + dot / underscore / hyphen. Non-
        // ASCII characters (CJK, emoji, accented Latin, Cyrillic)
        // must all reject as BadName.
        //
        // Companion to iter-248 (control chars rejection). A future
        // refactor that widened to is_alphanumeric() (Unicode-aware)
        // would silently start accepting non-ASCII names and break
        // Swift mirror parity (the Swift side uses byte-equal ASCII
        // tool registry keys).
        for ch in ['é', '中', '🚀', 'Ω', 'ß', 'Й'] {
            let name = format!("vault{ch}read");
            let bad = ToolCall {
                name,
                arguments: serde_json::json!({}),
            };
            let err = bad
                .validate()
                .expect_err(&format!("non-ASCII char {ch:?} must reject"));
            assert!(
                matches!(err, ToolCallError::BadName { .. }),
                "expected BadName for {ch:?}, got {err:?}"
            );
        }
    }

    #[test]
    fn malformed_tool_call_rejected_for_newline_tab_and_control_chars_in_name() {
        // Phase 1 hardening — boundary completeness for the bad-
        // chars rejection path. The existing
        // malformed_tool_call_rejected_bad_chars covers a single
        // space; pin the broader category of whitespace + control
        // characters that must reject because none of them are in
        // the [a-z0-9._-] allowed-charset.
        //
        // A future "let me allow whitespace inside quoted names"
        // refactor would silently widen the validator surface
        // beyond its documented bounds.
        for ch in ['\n', '\t', '\r', '\0', '/', ':', '@', '#', '$', '%'] {
            let name = format!("vault{ch}read");
            let bad = ToolCall {
                name,
                arguments: serde_json::json!({}),
            };
            let err = bad.validate().expect_err(&format!("char {ch:?} must reject"));
            assert!(
                matches!(err, ToolCallError::BadName { .. }),
                "expected BadName for char {ch:?}, got {err:?}"
            );
        }
    }

    #[test]
    fn malformed_tool_call_rejected_double_dot() {
        let bad = ToolCall {
            name: "vault..read".to_string(),
            arguments: serde_json::json!({}),
        };
        assert!(matches!(bad.validate(), Err(ToolCallError::BadName { .. })));
    }

    #[test]
    fn tool_call_serde_json_preserves_struct_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin extending iter-157
        // (presence + count) with field-order. ToolCall declares:
        // name, arguments. A future reorder breaks byte-equal
        // cache keys (tool-registry dedup) + replay byte-shape.
        let call = ToolCall {
            name: "vault.read".into(),
            arguments: serde_json::json!({"path": "a"}),
        };
        let s = serde_json::to_string(&call).expect("serialise");
        let name_pos = s.find("\"name\":").expect("name key");
        let args_pos = s.find("\"arguments\":").expect("arguments key");
        assert!(
            name_pos < args_pos,
            "name field must appear before arguments in {s}"
        );
    }

    #[test]
    fn tool_call_serde_json_contains_all_two_canonical_top_level_keys() {
        // Phase 1 hardening — wire-shape pin matching the
        // established pattern (AgentBlueprint 5, MissionPacket 3
        // iter-154, AnswerPacket 7 iter-155, MutationEnvelope 3
        // iter-156). ToolCall has 2 top-level fields (name,
        // arguments); a silent rename would round-trip but break
        // tool-registry consumers, dispatcher dedup logic, and
        // Swift bridge readers.
        let call = ToolCall {
            name: "vault.read".into(),
            arguments: serde_json::json!({"path": "a"}),
        };
        let json = serde_json::to_value(&call).expect("serialise");
        let obj = json.as_object().expect("ToolCall serialises as JSON object");
        for key in ["name", "arguments"] {
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
    fn tool_call_preserves_json_special_chars_in_arguments_through_serde() {
        // Phase 1 hardening — adversarial JSON pin for ToolCall.arguments
        // (companion to mission_packet iter-413, answer_packet iter-414,
        // citation iter-415, mutation_envelope iter-416).
        //
        // ToolCall.arguments is serde_json::Value which can hold
        // arbitrary JSON shapes — including string-valued fields with
        // JSON-special characters (quotes, backslashes, newlines, etc).
        // The Value type's own serde impl handles these correctly;
        // pin the round-trip transparency.
        //
        // A future "let me cache the arguments as a String pre-parsed
        // for speed" refactor would silently break the Value→Value
        // round-trip semantics that the dispatcher relies on.
        let adversarial = [
            serde_json::json!({"json_string": r#"{"nested": "object"}"#}),
            serde_json::json!({"multi_line": "a\nb\nc"}),
            serde_json::json!({"escapes": r#"quote " backslash \ tab \t"#}),
            serde_json::json!({"control": "x\x01y\x02z"}),
            serde_json::json!({"unicode": "🚀年5月"}),
            serde_json::json!([1, 2, "nested\narray", {"deep": {"k": "v"}}]),
        ];
        for args in adversarial {
            let call = ToolCall {
                name: "vault.read".into(),
                arguments: args.clone(),
            };
            // Validation must still pass (arguments shape is opaque to
            // the validator, only size matters and these are tiny).
            call.validate().expect("validation passes");
            let s = serde_json::to_string(&call).expect("serialise");
            let back: ToolCall =
                serde_json::from_str(&s).expect("deserialise");
            assert_eq!(back, call, "tool call arguments must round-trip byte-equal");
            // Spot-check the round-tripped arguments deep-equal.
            assert_eq!(back.arguments, args);
        }
    }

    #[test]
    fn tool_call_round_trips_through_json_with_nested_arguments() {
        // Phase 1 hardening — serde JSON round-trip with non-trivial
        // arguments (nested object + array). RunEventLog persists
        // ToolCall rows; any silent shape change would break replay.
        let call = ToolCall {
            name: "vault.search".into(),
            arguments: serde_json::json!({
                "query": "Aegis is rejected",
                "filters": {
                    "tags": ["agent", "v2"],
                    "since": "2026-05-01T00:00:00Z"
                },
                "limit": 25,
                "fuzzy": true,
                "nested": {
                    "deeper": {
                        "array": [1, 2, 3, 4, 5]
                    }
                }
            }),
        };
        call.validate().expect("valid call validates");
        let s = serde_json::to_string(&call).expect("serialise");
        let back: ToolCall = serde_json::from_str(&s).expect("deserialise");
        assert_eq!(back, call);
        // Independent walk through the deserialised arguments to
        // confirm shape preservation.
        assert_eq!(back.name, "vault.search");
        assert_eq!(back.arguments["query"], "Aegis is rejected");
        assert_eq!(back.arguments["filters"]["tags"][0], "agent");
        assert_eq!(back.arguments["nested"]["deeper"]["array"][4], 5);
        back.validate().expect("round-tripped call still validates");
    }

    #[test]
    fn tool_call_serde_tolerates_unknown_extra_fields_per_current_doctrine() {
        // Phase 1 hardening — DOCTRINE PIN with forward-compat teeth.
        // serde_json's DEFAULT behaviour is to IGNORE unknown fields
        // during deserialise. ToolCall does NOT carry
        // #[serde(deny_unknown_fields)], so an older log row containing
        // extra fields a future maintainer added and then reverted
        // (or that a different consumer wrote) still deserialises
        // successfully — the extras are silently dropped.
        //
        // This forward-compat property is load-bearing for RunEventLog
        // migrations: a Pro-Research field that gets added in v3 to
        // ToolCall must still let MAS V1 read the same row without
        // erroring.
        //
        // Pin the lenient behaviour so a future
        // #[serde(deny_unknown_fields)] addition surfaces at PR
        // review as a deliberate doctrine change.
        let call = ToolCall {
            name: "vault.read".into(),
            arguments: serde_json::json!({"path": "a"}),
        };
        let s = serde_json::to_string(&call).expect("serialise");
        // Inject a stray field into the JSON. Use rfind('}') so the
        // injection doesn't strip nested-object closing braces.
        let last_brace = s.rfind('}').expect("trailing brace");
        let mut augmented = String::with_capacity(s.len() + 50);
        augmented.push_str(&s[..last_brace]);
        augmented.push_str(r#","future_field":"some-experimental-value"}"#);
        let parsed: ToolCall =
            serde_json::from_str(&augmented).expect("unknown field tolerated");
        assert_eq!(parsed, call);
    }

    #[test]
    fn tool_call_error_struct_variants_field_shapes_pinned_via_destructure() {
        // Phase 1 hardening — field-shape pin for ToolCallError's
        // 4 struct-variants (BadName, OversizeName, BadArguments,
        // OversizeArguments). Companion to mission_prompt_error
        // iter-454, budget_error::exhausted iter-455,
        // log_validation_error iter-456.
        //
        // Each struct variant carries an EXACT field count + type
        // signature; pin via destructure compile-fail + type
        // assertions per field.
        //
        // - BadName { name: String, bad_char: char, index: usize } → 3
        // - OversizeName { size: usize, cap: usize } → 2
        // - BadArguments(String) → 1 tuple field
        // - OversizeArguments { size: usize, cap: usize } → 2
        // - EmptyName (no fields)
        //
        // A future variant-payload extension would silently shuffle
        // audit log shape; surface here.
        let bad_name = ToolCallError::BadName {
            name: "n".into(),
            bad_char: ' ',
            index: 5,
        };
        match bad_name {
            ToolCallError::BadName { name, bad_char, index } => {
                let _: String = name;
                let _: char = bad_char;
                let _: usize = index;
            }
            _ => unreachable!(),
        }

        let oversize_name = ToolCallError::OversizeName { size: 999, cap: 256 };
        match oversize_name {
            ToolCallError::OversizeName { size, cap } => {
                let _: usize = size;
                let _: usize = cap;
            }
            _ => unreachable!(),
        }

        let bad_args = ToolCallError::BadArguments("bad json".into());
        match bad_args {
            ToolCallError::BadArguments(msg) => {
                let _: String = msg;
            }
            _ => unreachable!(),
        }

        let oversize_args = ToolCallError::OversizeArguments {
            size: 99_999,
            cap: 65_536,
        };
        match oversize_args {
            ToolCallError::OversizeArguments { size, cap } => {
                let _: usize = size;
                let _: usize = cap;
            }
            _ => unreachable!(),
        }

        // EmptyName is a unit variant.
        let empty = ToolCallError::EmptyName;
        match empty {
            ToolCallError::EmptyName => {}
            _ => unreachable!(),
        }
    }

    #[test]
    fn tool_call_error_bad_name_inner_fields_are_identity_load_bearing() {
        // Phase 1 hardening — inner-field distinctness pin
        // (companion to iter-194/195/196 inner pins).
        // ToolCallError::BadName carries 3 fields: name, bad_char,
        // index. Each must participate in PartialEq derivation so
        // two BadName errors with different invalid characters /
        // positions / parent names compare unequal — audit
        // attribution depends on the distinct triples.
        let base = ToolCallError::BadName {
            name: "vault read".into(),
            bad_char: ' ',
            index: 5,
        };
        // Different name → unequal.
        assert_ne!(
            base,
            ToolCallError::BadName {
                name: "vault.read.bad".into(),
                bad_char: ' ',
                index: 5,
            }
        );
        // Different bad_char → unequal.
        assert_ne!(
            base,
            ToolCallError::BadName {
                name: "vault read".into(),
                bad_char: '/',
                index: 5,
            }
        );
        // Different index → unequal.
        assert_ne!(
            base,
            ToolCallError::BadName {
                name: "vault read".into(),
                bad_char: ' ',
                index: 6,
            }
        );
        // Identical → equal.
        assert_eq!(
            base,
            ToolCallError::BadName {
                name: "vault read".into(),
                bad_char: ' ',
                index: 5,
            }
        );
    }

    #[test]
    fn tool_call_error_variant_count_is_five() {
        // Phase 1 hardening — cardinality pin. ToolCallError has 5
        // variants (EmptyName, BadName, OversizeName, BadArguments,
        // OversizeArguments). Each surfaces from ToolCall::validate
        // for a different malformed-input class. A future addition
        // (e.g., ReservedName for namespaces v2 forbids) requires:
        //   - validate() rejection branch
        //   - AgentEvent::from_tool_call_error mapping
        //   - Debug-repr pin update
        let variants = [
            ToolCallError::EmptyName,
            ToolCallError::BadName {
                name: "x".into(),
                bad_char: ' ',
                index: 0,
            },
            ToolCallError::OversizeName { size: 999, cap: 256 },
            ToolCallError::BadArguments("parse fail".into()),
            ToolCallError::OversizeArguments { size: 99_999, cap: 65_536 },
        ];
        assert_eq!(variants.len(), 5);
        for i in 0..variants.len() {
            for j in (i + 1)..variants.len() {
                assert_ne!(
                    variants[i], variants[j],
                    "errors[{i}] and errors[{j}] must be distinct"
                );
            }
        }
    }

    #[test]
    fn tool_call_error_debug_repr_is_stable_for_log_persistence() {
        // Phase 1 hardening — audit dashboards print Debug repr of
        // ToolCallError when surfacing malformed-tool-call events.
        // A maintainer rename would silently change the leading
        // discriminant string and break log greps. Pin each variant.
        let err = ToolCallError::EmptyName;
        assert_eq!(format!("{err:?}"), "EmptyName");

        let err = ToolCallError::BadName {
            name: "x y".into(),
            bad_char: ' ',
            index: 1,
        };
        let dbg = format!("{err:?}");
        assert!(dbg.starts_with("BadName"), "got {dbg}");

        let err = ToolCallError::OversizeName { size: 1000, cap: 256 };
        let dbg = format!("{err:?}");
        assert!(dbg.starts_with("OversizeName"), "got {dbg}");

        let err = ToolCallError::BadArguments("parse failure".into());
        let dbg = format!("{err:?}");
        assert!(dbg.starts_with("BadArguments"), "got {dbg}");

        let err = ToolCallError::OversizeArguments { size: 1_000_000, cap: 65_536 };
        let dbg = format!("{err:?}");
        assert!(dbg.starts_with("OversizeArguments"), "got {dbg}");
    }

    #[test]
    fn malformed_tool_call_rejected_oversize_name() {
        // Phase 1 hardening — tool-name length cap. 257-byte name
        // (cap is 256) must reject before the runtime hits the
        // registry.
        let mut huge_name = String::from("vault.");
        huge_name.push_str(&"x".repeat(ToolCall::MAX_NAME_BYTES));
        let len = huge_name.len();
        let bad = ToolCall {
            name: huge_name,
            arguments: serde_json::json!({}),
        };
        let err = bad.validate().expect_err("over-cap name must reject");
        assert_eq!(
            err,
            ToolCallError::OversizeName {
                size: len,
                cap: ToolCall::MAX_NAME_BYTES,
            }
        );
    }

    #[test]
    fn tool_call_accepts_leading_hyphen_and_leading_underscore_in_name() {
        // Phase 1 hardening — doctrine pin. validate rejects only
        // leading/trailing DOT (iter-95) and double-dot. Leading
        // hyphen or underscore are intentionally permitted today
        // because they have no path-traversal semantics.
        //
        // A future "let me require leading [a-z0-9]" refactor for
        // strict CLI-style naming would silently break callers
        // using "_internal" or "-experimental" prefixes. Pin
        // current behaviour.
        for name in [
            "_internal",
            "-experimental",
            "__init__",
            "--reset",
            "-",          // pure hyphen — single char
            "_",          // pure underscore — single char
            "-1",         // leading hyphen + digit
            "_v2.read",   // leading underscore + dot + word
        ] {
            let call = ToolCall {
                name: name.to_string(),
                arguments: serde_json::json!({}),
            };
            call.validate()
                .unwrap_or_else(|e| panic!("name {name:?} must accept, got {e:?}"));
        }
    }

    #[test]
    fn tool_call_accepts_names_starting_with_digit_or_pure_digits() {
        // Phase 1 hardening — positive boundary pin. validate's
        // allowed-charset is [a-z0-9._-]; there is NO rule
        // requiring the first character to be a letter or
        // forbidding pure-digit names. Today the validator accepts
        // both leading-digit and pure-digit names.
        //
        // A future "let me require a letter prefix" refactor would
        // silently break callers that use numeric versioning in
        // tool names (e.g., "v2.search" → "2.search" if someone
        // strips the 'v'). Pin current behaviour so the doctrine
        // call is visible at PR review.
        for name in [
            "9",           // pure single digit
            "9.read",      // digit + dot + word
            "123",         // pure digits
            "v2.search",   // starts with letter, contains digit
            "2.search",    // starts with digit
            "0.0.1",       // version-like
            "abc-1",       // alphanumeric + hyphen
        ] {
            let call = ToolCall {
                name: name.to_string(),
                arguments: serde_json::json!({}),
            };
            call.validate()
                .unwrap_or_else(|e| panic!("name {name:?} must accept, got {e:?}"));
        }
    }

    #[test]
    fn tool_call_accepts_full_allowed_charset_lowercase_digits_dot_underscore_hyphen() {
        // Phase 1 hardening — positive-charset coverage for
        // ToolCall::validate. The doc on `name` says
        // "[a-z0-9._-]"; exercising one valid name that uses
        // EVERY allowed character class proves the validator
        // doesn't accidentally exclude one (rejection tests
        // exercise the negative side; this nails the positive).
        let name = "abcdefghijklmnopqrstuvwxyz0123456789._-".to_string();
        let call = ToolCall {
            name,
            arguments: serde_json::json!({"ok": true}),
        };
        call.validate().expect("full allowed charset must accept");
    }

    #[test]
    fn tool_name_uppercase_currently_accepted_despite_doc_lowercase_only() {
        // Phase 1 hardening — DOCTRINE PIN with documentation-mismatch
        // teeth. The `ToolCall::name` doc says "[a-z0-9._-]" (lowercase
        // only) but `validate()` uses `is_ascii_alphanumeric()` which
        // ALSO accepts uppercase A-Z. Currently uppercase tool names
        // pass validation. Either:
        //   (a) the docstring needs updating to "[A-Za-z0-9._-]", or
        //   (b) the validator needs tightening to reject uppercase.
        //
        // This test pins the CURRENT behaviour (uppercase accepted)
        // so the choice is visible at PR review. Whichever direction
        // the eventual doctrine call goes, the next iter must update
        // this test and the docstring in the SAME commit — neither
        // can silently drift past the other.
        //
        // Test fixtures pick canonical-looking uppercase / mixed-case
        // names a Claude / OpenAI provider might emit:
        for name in [
            "Vault.Read",           // PascalCase namespace + verb
            "VAULT.READ",           // SCREAMING_CASE
            "vault.READ",           // mixed case in verb
            "Vault_search",         // PascalCase namespace + snake verb
            "VaultSearch",          // no separator, pascal
            "ABC123.xyz",           // alphanumeric mixed
        ] {
            let call = ToolCall {
                name: name.to_string(),
                arguments: serde_json::json!({}),
            };
            call.validate()
                .unwrap_or_else(|e| panic!("uppercase name {name:?} currently accepted but got {e:?}"));
        }
        // Sanity preserved — the lowercase-only doctrine still
        // accepts every name in the documented charset.
        let lowercase = ToolCall {
            name: "vault.read".into(),
            arguments: serde_json::json!({}),
        };
        lowercase.validate().expect("lowercase canonical name accepted");
    }

    #[test]
    fn tool_name_single_char_accepts_per_minimum_boundary() {
        // Phase 1 hardening — minimum-boundary pin for ToolCall.name
        // validation. The existing tool_name_at_cap_accepts_when_valid_chars
        // pins the MAX (256-byte) boundary. The MIN (1-byte) boundary
        // — a tool with a 1-character name — was unpinned.
        //
        // The validator rejects empty names (EmptyName error) but
        // accepts any non-empty valid-char name. A 1-char name is the
        // legal minimum. Pin it across the full allowed charset:
        //   - alphanumeric: "a", "Z", "0", "9"
        //   - underscore: "_"
        //   - hyphen: "-"
        //
        // Note: leading-dot ".X" is rejected (path-traversal); a 1-char
        // "." is BOTH leading and trailing → rejected (already pinned).
        for name in ["a", "Z", "0", "9", "_", "-"] {
            let call = ToolCall {
                name: name.to_string(),
                arguments: serde_json::json!({}),
            };
            call.validate().unwrap_or_else(|e| {
                panic!("single-char name {name:?} must validate, got {e:?}")
            });
        }
    }

    #[test]
    fn tool_name_at_cap_accepts_when_valid_chars() {
        // Exactly MAX_NAME_BYTES with valid charset: accepts (strict
        // > boundary).
        let at_cap = "a".repeat(ToolCall::MAX_NAME_BYTES);
        let call = ToolCall {
            name: at_cap,
            arguments: serde_json::json!({}),
        };
        call.validate().expect("at-cap valid name must accept");
    }

    #[test]
    fn malformed_tool_call_rejected_oversize_arguments() {
        let huge = "x".repeat(ToolCall::MAX_ARGS_BYTES);
        let bad = ToolCall {
            name: "vault.read".to_string(),
            arguments: serde_json::json!({"blob": huge}),
        };
        assert!(matches!(
            bad.validate(),
            Err(ToolCallError::OversizeArguments { .. })
        ));
    }

    #[test]
    fn tool_call_oversize_arguments_surfaces_exact_size_and_cap_in_error() {
        // Phase 1 hardening — error attribution completeness companion
        // to malformed_tool_call_rejected_oversize_arguments (which
        // only checks the variant shape via matches!) and
        // malformed_tool_call_rejected_oversize_name (which DOES pin
        // exact (size, cap) for the name path).
        //
        // The arguments-path error attribution must also surface
        // exact byte count + cap so audit dashboards can report
        // "tool call rejected at 65537 bytes vs 65536 cap" rather
        // than the variant-only message.
        //
        // Defends against a future refactor that obscured the size
        // payload behind an opaque message + dropped the cap field.
        // Build a JSON value whose serialised form is > MAX_ARGS_BYTES.
        // A string of length MAX (in JSON: 2 quotes + MAX chars) lands
        // at MAX+2 bytes — comfortably over the cap.
        let huge = "x".repeat(ToolCall::MAX_ARGS_BYTES);
        let bad = ToolCall {
            name: "vault.read".to_string(),
            arguments: serde_json::json!(huge),
        };
        match bad.validate() {
            Err(ToolCallError::OversizeArguments { size, cap }) => {
                assert_eq!(cap, ToolCall::MAX_ARGS_BYTES);
                // Serialised length of `json!(huge)` is the
                // raw string length + 2 (the two JSON quote chars).
                assert_eq!(
                    size,
                    ToolCall::MAX_ARGS_BYTES + 2,
                    "size must surface the exact serialised byte count"
                );
            }
            other => panic!("expected OversizeArguments, got {other:?}"),
        }
    }

    #[test]
    fn tool_call_arguments_minimum_size_boundary_pins() {
        // Phase 1 hardening — minimum-boundary pin for ToolCall.arguments.
        // Companion to tool_call_arguments_at_cap_accepts_per_strict_greater_boundary
        // (which pins the MAX 64-KiB boundary).
        //
        // The minimum non-trivial arguments is `serde_json::json!({})`
        // which serialises to "{}" (2 bytes — well under cap). Other
        // minimum shapes (null, false, 0, "") all serialise to 4 bytes
        // or fewer.
        //
        // Pin that the smallest valid JSON values all accept through
        // validate() — a future "let me require non-empty top-level
        // object" tightening would silently break callers that pass
        // null/bool/number-only arguments.
        for args in [
            serde_json::json!({}),       // empty object: "{}" (2 bytes)
            serde_json::json!(null),     // JSON null: "null" (4 bytes)
            serde_json::json!(false),    // JSON false: "false" (5 bytes)
            serde_json::json!(0),        // integer zero: "0" (1 byte)
            serde_json::json!(""),       // empty string: "\"\"" (2 bytes)
            serde_json::json!([]),       // empty array: "[]" (2 bytes)
        ] {
            let call = ToolCall {
                name: "vault.read".into(),
                arguments: args.clone(),
            };
            call.validate().unwrap_or_else(|e| {
                panic!("minimum arguments {args:?} must validate, got {e:?}")
            });
        }
    }

    #[test]
    fn tool_call_arguments_at_cap_accepts_per_strict_greater_boundary() {
        // Phase 1 hardening — boundary completeness companion to
        // tool_name_at_cap_accepts_when_valid_chars. The arguments path
        // uses `arg_bytes.len() > MAX_ARGS_BYTES` (strict greater);
        // exactly at-cap must accept. The existing at-cap pin only
        // covers the name path.
        //
        // To produce arguments serialising to exactly MAX_ARGS_BYTES,
        // we need a JSON value whose serialisation length is the cap.
        // A raw string of length MAX-2 serialises to "<string>" of
        // length MAX (two quotes around MAX-2 chars).
        let at_cap_string = "x".repeat(ToolCall::MAX_ARGS_BYTES - 2);
        let call = ToolCall {
            name: "vault.read".to_string(),
            arguments: serde_json::json!(at_cap_string),
        };
        call.validate()
            .expect("at-cap arguments must accept per strict-greater boundary");
    }

    #[test]
    fn tool_call_accepts_multi_segment_dotted_names_with_non_adjacent_dots() {
        // Phase 1 hardening — positive doctrine pin. The existing
        // tests reject ".secret" (leading), "vault." (trailing,
        // iter-95), and "vault..read" (adjacent double-dot). They
        // pin the rejection surface. NOTHING currently asserts that
        // multi-segment names with non-adjacent dots ARE accepted.
        // A future refactor that tightened the validator to "at
        // most one dot" (e.g., to enforce a strict `namespace.verb`
        // shape) would silently start rejecting names like
        // "analytics.metrics.export" — and the existing positive
        // test (tool_call_accepts_full_allowed_charset_*) uses
        // EXACTLY one dot in its fixture, so the regression slips
        // past.
        for name in [
            "a.b.c",                    // minimal 3-segment
            "vault.search.full",        // realistic 3-segment
            "analytics.metrics.export", // 3-segment with longer parts
            "a.b.c.d.e",                // 5-segment chain
            "ns_v2.tool_v1.verb_v3",    // segments with underscores
            "ns-1.tool-2.verb-3",       // segments with hyphens
        ] {
            let call = ToolCall {
                name: name.to_string(),
                arguments: serde_json::json!({}),
            };
            call.validate()
                .unwrap_or_else(|e| panic!("multi-dot name {name:?} must accept, got {e:?}"));
        }
    }

    #[test]
    fn tool_call_validate_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220-230).
        // ToolCall::validate takes &self and walks the name + args;
        // pure function over immutable data.
        //
        // A future refactor that introduced thread-local state or
        // a "skip-cache" for repeat validations would silently break
        // determinism.
        let call = good_call();
        let r1 = call.validate();
        let r2 = call.validate();
        let r3 = call.validate();
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
        assert!(r1.is_ok());

        // Same property on the rejection path.
        let bad = ToolCall {
            name: String::new(),
            arguments: serde_json::json!({}),
        };
        let e1 = bad.validate();
        let e2 = bad.validate();
        assert_eq!(e1, e2);
        assert_eq!(e1, Err(ToolCallError::EmptyName));
    }

    #[test]
    fn good_tool_call_passes() {
        good_call().validate().expect("good call must validate");
    }

    #[test]
    fn mission_packet_display_blueprint_id_and_scope_reflect_field_values() {
        // Phase 1 hardening — Display semantic pin (companion to
        // answer_packet_display_citations_count_field_reflects_vec_len
        // iter-488 + tokens iter-489 + stop iter-490). MissionPacket
        // Display surfaces 2 fields:
        //   "MissionPacket{blueprint={}, scope={}}"
        //
        // Pin that both values track the underlying field with
        // distinctive payloads. A future "let me truncate
        // blueprint_id to 8 chars for visual brevity" refactor
        // would silently lose the distinctive identifier in log lines.
        for (blueprint, scope) in [
            ("research-assistant", "vault/notes"),
            ("a", "b"),
            ("agent_with_underscore", "vault/with/slashes"),
            ("a-very-long-distinctive-blueprint-identifier-12345",
             "another-very-long-scope-string-abcdef"),
        ] {
            let mp = MissionPacket {
                blueprint_id: AgentBlueprintId(blueprint.to_string()),
                user_prompt: "hidden".to_string(),
                vault_scope: scope.to_string(),
            };
            let display = format!("{mp}");
            assert!(
                display.contains(&format!("blueprint={blueprint}")),
                "Display must contain blueprint={blueprint}, got: {display}"
            );
            assert!(
                display.contains(&format!("scope={scope}")),
                "Display must contain scope={scope}, got: {display}"
            );
        }
    }

    #[test]
    fn mission_packet_display_with_empty_fields_produces_terse_layout() {
        // Phase 1 hardening — boundary pin for MissionPacket Display
        // with empty blueprint_id + vault_scope (companion to
        // answer_packet_display_with_empty_blueprint_id_produces_terse_output
        // iter-428).
        //
        // Both fields are user-supplied free-form Strings; empty
        // values must not panic and must produce
        //   "MissionPacket{blueprint=, scope=}"
        // with the layout intact.
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId(String::new()),
            user_prompt: "hidden".to_string(),
            vault_scope: String::new(),
        };
        let display = format!("{mp}");
        assert_eq!(display, "MissionPacket{blueprint=, scope=}");
        // Prompt absent.
        assert!(!display.contains("hidden"));
    }

    #[test]
    fn mission_packet_display_field_order_is_blueprint_then_scope() {
        // Phase 1 hardening — Display field-ORDER pin (companion to
        // answer_packet_display_field_order_is_blueprint_stop_tokens_citations
        // iter-494). MissionPacket Display format (mission.rs §22):
        //   "MissionPacket{{blueprint={}, scope={}}}"
        //
        // The 2 fields appear in EXACTLY this order:
        //   1. blueprint
        //   2. scope
        //
        // A future reorder would silently shuffle the log-line layout.
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("a".into()),
            user_prompt: "hidden".into(),
            vault_scope: "s".into(),
        };
        let display = format!("{mp}");
        let blueprint_pos = display.find("blueprint=").expect("blueprint field");
        let scope_pos = display.find("scope=").expect("scope field");
        assert!(blueprint_pos < scope_pos, "blueprint must precede scope");
    }

    #[test]
    fn mission_packet_display_starts_with_literal_struct_name_prefix() {
        // Phase 1 hardening — wire-shape pin (companion to
        // answer_packet_display_starts_with_literal_struct_name_prefix
        // iter-451). MissionPacket::Display format string is
        //   "MissionPacket{{blueprint={}, scope={}}}"
        // (mission.rs §22). The literal "MissionPacket{" prefix is
        // load-bearing for grep-based audit pipelines.
        //
        // A future "let me shorten to 'MP{...}' for log brevity"
        // refactor would silently break grep contracts.
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("a".into()),
            user_prompt: "hidden".into(),
            vault_scope: "s".into(),
        };
        let display = format!("{mp}");
        assert!(display.starts_with("MissionPacket{"),
            "Display must start with literal 'MissionPacket{{', got: {display}");
        assert!(display.ends_with('}'),
            "Display must end with literal '}}', got: {display}");
    }

    #[test]
    fn mission_packet_display_writes_special_chars_verbatim_no_escaping() {
        // Phase 1 hardening — Display vs serde behaviour pin.
        // mission.rs §21 Display impl writes:
        //   "MissionPacket{blueprint={}, scope={}}"
        // using {} (Display) — NOT {:?} (Debug). Display writes
        // strings VERBATIM without JSON-escaping; if the
        // blueprint_id or vault_scope carries a quote, backslash,
        // or newline, it appears RAW in the log line.
        //
        // This is the correct semantic — Display is for human-readable
        // log lines, not JSON-parseable persistence. The user_prompt
        // is intentionally OMITTED from Display (already pinned in
        // mission_packet_display_omits_prompt_for_log_concision); the
        // remaining 2 fields appear verbatim.
        //
        // Pin this behaviour so a future "let me JSON-escape the
        // Display fields for log safety" refactor surfaces at PR
        // review (since it would silently change the appearance for
        // tail-following log readers).
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId(r#"agent "with quotes""#.to_string()),
            user_prompt: "hidden body".to_string(),
            vault_scope: "vault\\windows\\style".to_string(),
        };
        let display = format!("{mp}");
        // Quotes and backslashes appear RAW (no JSON-escape).
        assert!(display.contains(r#"agent "with quotes""#),
            "blueprint_id quotes must appear raw, got {display}");
        assert!(display.contains(r#"vault\windows\style"#),
            "vault_scope backslashes must appear raw, got {display}");
        // Prompt absent.
        assert!(!display.contains("hidden body"));
    }

    #[test]
    fn mission_packet_display_preserves_unicode_in_blueprint_id_and_vault_scope() {
        // Phase 1 hardening — Unicode safety pin for Display
        // (companion to iter-206 AnswerPacket Display Unicode pin).
        // MissionPacket::Display writes blueprint_id and vault_scope
        // verbatim via their respective Display impls; the
        // user_prompt is intentionally omitted (log concision).
        // Unicode in either of the two surfaced fields must survive
        // byte-equal.
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("研究助手-α".into()),
            user_prompt: "any prompt".into(),
            vault_scope: "vault/笔记/2026年5月".into(),
        };
        let display = format!("{mp}");
        assert_eq!(
            display,
            "MissionPacket{blueprint=研究助手-α, scope=vault/笔记/2026年5月}"
        );
        assert!(display.contains("研究助手-α"));
        assert!(display.contains("vault/笔记/2026年5月"));
        // user_prompt is intentionally OMITTED from Display.
        assert!(!display.contains("any prompt"));
    }

    #[test]
    fn mission_packet_display_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series + iter-278 AnswerPacket
        // Display determinism). MissionPacket Display reads
        // blueprint_id + vault_scope through write!; pure.
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("a".into()),
            user_prompt: "p".into(),
            vault_scope: "v".into(),
        };
        let s1 = format!("{mp}");
        let s2 = format!("{mp}");
        let s3 = format!("{mp}");
        assert_eq!(s1, s2);
        assert_eq!(s2, s3);
    }

    #[test]
    fn mission_packet_display_omits_prompt_for_log_concision() {
        // Phase 1 hardening — Display is for log lines. Prompts can
        // be hundreds of KB; we deliberately omit them so a single
        // log line doesn't blow stdout. blueprint_id + vault_scope
        // are the audit-relevant fields. The user_prompt remains
        // available via Debug for verbose inspection.
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("research-assistant".into()),
            user_prompt: "x".repeat(100_000),
            vault_scope: "vault/notes/2026".into(),
        };
        let display = format!("{mp}");
        assert_eq!(
            display,
            "MissionPacket{blueprint=research-assistant, scope=vault/notes/2026}"
        );
        assert!(!display.contains("x"), "prompt body must NOT appear");
        assert!(display.len() < 200, "log line must stay terse");
    }

    #[test]
    fn mission_packet_new_constructor_validates_and_constructs() {
        let ok = MissionPacket::new(
            AgentBlueprintId("a".into()),
            "small prompt",
            "vault/notes",
        )
        .expect("under-cap prompt accepted");
        assert_eq!(ok.user_prompt, "small prompt");
        assert_eq!(ok.vault_scope, "vault/notes");

        let too_big_prompt = "x".repeat(MissionPacket::MAX_PROMPT_BYTES + 1);
        let err = MissionPacket::new(
            AgentBlueprintId("a".into()),
            too_big_prompt,
            "vault",
        )
        .expect_err("over-cap prompt rejected");
        assert!(matches!(err, MissionPromptError::OversizePrompt { .. }));
    }

    #[test]
    fn mission_packet_new_constructor_positional_arg_order_is_pinned() {
        // Phase 1 hardening — positional-order pin for MissionPacket::new.
        // The signature is:
        //   new(blueprint_id, user_prompt, vault_scope)
        // (mission.rs §42). Each arg maps to the same-named field.
        //
        // A future "let me reorder for ergonomic intuition" refactor
        // (e.g., putting user_prompt first because it's the user-
        // visible content) would silently shuffle every call site's
        // behaviour. The 3 args all accept `impl Into<String>`,
        // making the swap type-compatible.
        //
        // Pin via 3 DISTINCT identifiable values per field.
        let mp = MissionPacket::new(
            AgentBlueprintId("DISTINCT-BLUEPRINT-ID".into()),
            "DISTINCT-USER-PROMPT-CONTENT",
            "DISTINCT-VAULT-SCOPE-PATH",
        )
        .expect("under-cap construction");
        assert_eq!(mp.blueprint_id.0, "DISTINCT-BLUEPRINT-ID");
        assert_eq!(mp.user_prompt, "DISTINCT-USER-PROMPT-CONTENT");
        assert_eq!(mp.vault_scope, "DISTINCT-VAULT-SCOPE-PATH");
    }

    #[test]
    fn mission_packet_new_constructor_at_cap_accepts_and_over_cap_surfaces_exact_size_in_error() {
        // Phase 1 hardening — boundary completeness companion to
        // mission_packet_new_constructor_validates_and_constructs.
        // The existing test pins under-cap-accepts and over-cap-rejects-
        // via-shape (matches!). The boundary BEHAVIOUR through `new()`
        // for AT-CAP (must accept) and the EXACT error payload from
        // `new()` for OVER-BY-ONE (must report size + cap precisely)
        // were unpinned.
        //
        // Parallel to validate_prompt's mission_prompt_at_cap_accepts +
        // mission_prompt_over_cap_rejected pins, lifted to the
        // ergonomic constructor.
        //
        // Defends against a future "let me change new()'s reject
        // boundary to >= instead of >" or "let me obscure the error
        // payload behind an opaque message" refactor.
        // At exactly MAX_PROMPT_BYTES: must accept.
        let at_cap_prompt = "x".repeat(MissionPacket::MAX_PROMPT_BYTES);
        let ok = MissionPacket::new(
            AgentBlueprintId("a".into()),
            at_cap_prompt.clone(),
            "vault",
        )
        .expect("at-cap prompt must accept through new()");
        assert_eq!(ok.user_prompt.len(), MissionPacket::MAX_PROMPT_BYTES);

        // Over-by-one: must reject with EXACT (size, cap) attribution.
        let over_by_one = "x".repeat(MissionPacket::MAX_PROMPT_BYTES + 1);
        let err = MissionPacket::new(
            AgentBlueprintId("a".into()),
            over_by_one.clone(),
            "vault",
        )
        .expect_err("over-by-one prompt must reject through new()");
        assert_eq!(
            err,
            MissionPromptError::OversizePrompt {
                size: MissionPacket::MAX_PROMPT_BYTES + 1,
                cap: MissionPacket::MAX_PROMPT_BYTES,
            },
            "new() must surface the exact (size, cap) attribution, not just the variant shape"
        );
    }

    #[test]
    fn tool_call_error_is_clone_send_sync_but_not_copy() {
        // Phase 1 hardening — trait-bound pin for ToolCallError.
        // Companion to the Clone + Send + Sync (not Copy) sweep
        // (CapabilityError iter-384 et al).
        //
        // ToolCallError: 5-variant enum with String + char + usize
        // payloads on 4 variants (BadName, OversizeName, BadArguments,
        // OversizeArguments) + 1 unit variant (EmptyName). Clone +
        // PartialEq by derive (mission.rs §153), NOT Copy because
        // BadName carries `name: String` and BadArguments carries
        // `String`.
        //
        // Send + Sync are load-bearing — ToolCall validation rejections
        // surface in AgentEvent::Error and ride the executor stream
        // across thread boundaries.
        //
        // A future "let me hold a Cow<'static, str>" inside BadName
        // refactor that introduced a non-Send lifetime would silently
        // break cross-thread propagation — surface here.
        fn assert_clone_send_sync<T: Clone + Send + Sync>() {}
        assert_clone_send_sync::<ToolCallError>();

        let e = ToolCallError::BadName {
            name: "vault read".into(),
            bad_char: ' ',
            index: 5,
        };
        assert_eq!(e.clone(), e);
    }

    #[test]
    fn mission_packet_and_tool_call_are_clone_send_sync_but_not_copy() {
        // Phase 1 hardening — trait-bound pin for the String/Value-
        // bearing structs in mission.rs. Companion to the
        // AgentBlueprintId Clone + Send + Sync pin iter-375.
        //
        // MissionPacket: 3 fields (AgentBlueprintId + 2 Strings), Clone
        // by derive but NOT Copy (Strings allocate).
        // ToolCall: 2 fields (String + serde_json::Value), Clone by
        // derive but NOT Copy (Value allocates).
        //
        // Send + Sync are load-bearing — these cross dispatcher
        // background-actor boundaries.
        //
        // A future "let me hold a non-Send AsyncMutex<Value> inside
        // ToolCall.arguments" refactor would silently break the
        // cross-thread propagation that the dispatcher relies on.
        fn assert_clone_send_sync<T: Clone + Send + Sync>() {}
        assert_clone_send_sync::<MissionPacket>();
        assert_clone_send_sync::<ToolCall>();

        // Sanity: Clone yields equal value, distinct allocation.
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("a".into()),
            user_prompt: "p".into(),
            vault_scope: "v".into(),
        };
        assert_eq!(mp.clone(), mp);
        let tc = ToolCall {
            name: "vault.read".into(),
            arguments: serde_json::json!({"path": "a"}),
        };
        assert_eq!(tc.clone(), tc);
    }

    #[test]
    fn mission_prompt_error_is_copy_clone_send_sync_for_propagation_safety() {
        // Phase 1 hardening — trait-bound pin (part of the Copy +
        // Clone + Send + Sync sweep series from budget_gate through
        // VariantLadderError iter-373).
        //
        // MissionPromptError: 1-variant enum with Copy payload
        // (2×usize) marked Copy via derive (mission.rs §73). Returned
        // by validate_prompt / MissionPacket::new; Copy lets callers
        // surface the error to UI + audit without owning.
        //
        // A future addition like BadEncoding(String) would break Copy
        // — surface here.
        fn assert_copy_clone_send_sync<T: Copy + Clone + Send + Sync>() {}
        assert_copy_clone_send_sync::<MissionPromptError>();

        let e = MissionPromptError::OversizePrompt {
            size: 200_000,
            cap: 131_072,
        };
        let _a = e; let _b = e; assert_eq!(e, e);
    }

    #[test]
    fn mission_prompt_error_variant_count_is_one() {
        // Phase 1 hardening — cardinality pin completing the
        // count-pin series across the agent_runtime_v2 error taxonomies
        // (mode iter-?, ToolCallError 5v, AgentEventErrorKind 4v,
        // BlueprintModeError 2v, VariantLadderError 2v). MissionPromptError
        // has exactly 1 variant (OversizePrompt) today.
        //
        // A future addition (e.g., EmptyPrompt if non-empty becomes a
        // requirement, or BadEncoding for non-UTF-8 input) requires:
        //   - validate_prompt() match-arm extension
        //   - new variant's debug repr pin + inner-field identity pin
        //
        // Pin the count so the addition surfaces at PR review with a
        // deliberate test update.
        let variants = [MissionPromptError::OversizePrompt { size: 0, cap: 0 }];
        assert_eq!(variants.len(), 1);
    }

    #[test]
    fn mission_prompt_error_oversize_field_shape_pinned_to_exactly_size_and_cap() {
        // Phase 1 hardening — field-shape pin for
        // MissionPromptError::OversizePrompt. The variant carries
        // EXACTLY 2 named fields (size + cap), both usize. Pin the
        // field count + types via the Debug repr (already pinned by
        // mission_prompt_error_oversize_debug_repr_is_stable_for_audit_persistence
        // but that test only fixes the format STRING, not the SHAPE).
        //
        // A future "let me add a 3rd field like {size, cap, kind}"
        // refactor would silently change the error payload size and
        // break any audit log that keys on the (size, cap) tuple.
        //
        // Pin via struct-literal destructuring: if the field count
        // changes, this match arm fails to compile.
        let err = MissionPromptError::OversizePrompt {
            size: 200_000,
            cap: 131_072,
        };
        match err {
            MissionPromptError::OversizePrompt { size, cap } => {
                // Exactly 2 fields, both usize. The destructure
                // compile-fails if more/fewer fields exist.
                assert_eq!(size, 200_000);
                assert_eq!(cap, 131_072);
                // Type assertion: size and cap are both usize.
                let _: usize = size;
                let _: usize = cap;
            }
        }
    }

    #[test]
    fn mission_prompt_error_oversize_inner_fields_are_identity_load_bearing() {
        // Phase 1 hardening — closes the error inner-field distinctness
        // series across the codebase (iter-197 BadName, iter-198
        // BudgetError::Exhausted, iter-199 OrdinalMismatch).
        // MissionPromptError::OversizePrompt carries 2 fields: size,
        // cap. Each must participate in PartialEq derivation so an
        // audit pipeline keyed on (size, cap) tuples can distinguish
        // distinct prompt-size violations.
        let base = MissionPromptError::OversizePrompt {
            size: 200_000,
            cap: 131_072,
        };
        // Different size → unequal.
        assert_ne!(
            base,
            MissionPromptError::OversizePrompt {
                size: 300_000,
                cap: 131_072,
            }
        );
        // Different cap → unequal.
        assert_ne!(
            base,
            MissionPromptError::OversizePrompt {
                size: 200_000,
                cap: 65_536,
            }
        );
        // Identical → equal.
        assert_eq!(
            base,
            MissionPromptError::OversizePrompt {
                size: 200_000,
                cap: 131_072,
            }
        );
    }

    #[test]
    fn mission_prompt_error_oversize_debug_repr_is_stable_for_audit_persistence() {
        // Phase 1 hardening — audit-log surface. MissionPromptError
        // surfaces in CI / incident output when prompt validation
        // fails. Pin the Debug repr so refactors don't silently
        // break grep-based audit pipelines.
        let err = MissionPromptError::OversizePrompt {
            size: 200_000,
            cap: 131_072,
        };
        let dbg = format!("{err:?}");
        assert_eq!(dbg, "OversizePrompt { size: 200000, cap: 131072 }");
        // Field-order sensitivity: size before cap.
        let s_idx = dbg.find("size").expect("size field");
        let c_idx = dbg.find("cap").expect("cap field");
        assert!(s_idx < c_idx, "size must appear before cap in Debug");
    }

    #[test]
    fn mission_packet_new_accepts_both_empty_prompt_and_empty_vault_scope() {
        // Phase 1 hardening — symmetric companion to
        // mission_packet_new_accepts_empty_prompt_documents_no_lower_bound.
        // Both user_prompt AND vault_scope are optional in the sense
        // that the runtime doesn't enforce a non-empty lower bound
        // on either; vault_scope is intentionally allowed to be ""
        // (a fully unbounded vault read). Pin the current doctrine.
        let ok = MissionPacket::new(
            AgentBlueprintId("probe".into()),
            "",
            "",
        )
        .expect("both empty fields accepted today");
        assert_eq!(ok.user_prompt, "");
        assert_eq!(ok.vault_scope, "");
        // validate_prompt agrees.
        ok.validate_prompt().expect("validate_prompt agrees");
    }

    #[test]
    fn mission_packet_new_accepts_empty_prompt_documents_no_lower_bound() {
        // Phase 1 hardening — documentation invariant. validate_prompt
        // currently has only an UPPER bound (MAX_PROMPT_BYTES); there
        // is no lower bound. An empty prompt is allowed (the executor
        // may use it as a synthetic probe). If a future iter adds a
        // MissionPromptError::Empty variant, this test surfaces the
        // behaviour change at PR review rather than letting it slip
        // silently into release.
        let ok = MissionPacket::new(
            AgentBlueprintId("probe".into()),
            "",
            "vault/probe",
        )
        .expect("empty prompt is currently allowed");
        ok.validate_prompt()
            .expect("validate_prompt agrees: no lower bound");
        assert_eq!(ok.user_prompt, "");
    }

    #[test]
    fn mission_packet_validate_prompt_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220-234).
        // validate_prompt takes &self and only inspects
        // user_prompt.len(); pure check.
        let ok = MissionPacket {
            blueprint_id: AgentBlueprintId("a".into()),
            user_prompt: "small".into(),
            vault_scope: "vault".into(),
        };
        let r1 = ok.validate_prompt();
        let r2 = ok.validate_prompt();
        let r3 = ok.validate_prompt();
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
        assert!(r1.is_ok());

        // Rejection path.
        let too_big = MissionPacket {
            blueprint_id: AgentBlueprintId("a".into()),
            user_prompt: "x".repeat(MissionPacket::MAX_PROMPT_BYTES + 1),
            vault_scope: "vault".into(),
        };
        let e1 = too_big.validate_prompt();
        let e2 = too_big.validate_prompt();
        assert_eq!(e1, e2);
        assert!(matches!(e1, Err(MissionPromptError::OversizePrompt { .. })));
    }

    #[test]
    fn mission_prompt_at_cap_accepts() {
        // Phase 1 hardening — enforce the previously doc-only cap.
        // Boundary: exactly MAX_PROMPT_BYTES accepts (strict > check).
        let at_cap = "x".repeat(MissionPacket::MAX_PROMPT_BYTES);
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("a".into()),
            user_prompt: at_cap,
            vault_scope: "vault".into(),
        };
        mp.validate_prompt().expect("at-cap prompt must accept");
    }

    #[test]
    fn mission_prompt_over_cap_rejected() {
        let too_big = "x".repeat(MissionPacket::MAX_PROMPT_BYTES + 1);
        let size = too_big.len();
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("a".into()),
            user_prompt: too_big,
            vault_scope: "vault".into(),
        };
        let err = mp.validate_prompt().expect_err("over-cap prompt must reject");
        assert_eq!(
            err,
            MissionPromptError::OversizePrompt {
                size,
                cap: MissionPacket::MAX_PROMPT_BYTES,
            }
        );
    }

    #[test]
    fn mission_packet_preserves_json_special_chars_in_user_prompt_through_serde() {
        // Phase 1 hardening — adversarial JSON pin. The user_prompt
        // field is a String that frequently carries JSON-flavoured
        // content (the user is asking the model to write JSON, or
        // pasting a JSON sample). Serde MUST escape these correctly
        // through round-trip: quotes, backslashes, embedded newlines,
        // control characters in the C0 range, tabs.
        //
        // Companion to:
        //   - mission_packet_preserves_unicode_in_user_prompt_and_vault_scope_through_serde
        //   - thinking_bytes_with_embedded_nuls_and_non_utf8_preserved_through_digest
        //
        // A future #[serde(serialize_with = ...)] that applied lossy
        // sanitisation would silently change the persisted prompt.
        // Pin the JSON-escape transparency invariant.
        let adversarial_prompts = [
            r#"Write JSON: {"key": "value", "nested": {"a": [1, 2, 3]}}"#,
            "literal\nnewline\nin\nprompt",
            "literal\ttab\tin\tprompt",
            r#"backslash \ and quote " characters"#,
            "control\x01char\x02prompt",
            r#"Unicode + JSON: {"年": "2026年", "🚀": "emoji"}"#,
        ];
        for prompt in adversarial_prompts {
            let mp = MissionPacket {
                blueprint_id: AgentBlueprintId("json-edge".into()),
                user_prompt: prompt.to_string(),
                vault_scope: "vault".into(),
            };
            let s = serde_json::to_string(&mp).expect("serialise");
            let back: MissionPacket =
                serde_json::from_str(&s).expect("deserialise");
            assert_eq!(back.user_prompt, prompt, "prompt must round-trip byte-equal");
            assert_eq!(back, mp);
        }
    }

    #[test]
    fn mission_packet_preserves_unicode_in_user_prompt_and_vault_scope_through_serde() {
        // Phase 1 hardening — Unicode-safety pin. MissionPacket carries
        // a free-form user_prompt (the user's text — emoji, CJK,
        // RTL scripts, combining characters all plausible) AND a
        // vault_scope path that may include CJK directory names
        // (e.g. "vault/notes/2026年5月"). The existing
        // mission_packet_round_trips uses pure ASCII; this pins
        // that serde JSON preserves multi-byte sequences byte-for-byte
        // through both fields, with no \u-escaping that would
        // change the on-disk encoding.
        //
        // Companion to blueprint_display_name_preserves_unicode_through_serde
        // (iter-49ish in blueprint.rs). RunEventLog rows that
        // capture MissionPacket-derived payloads depend on this
        // contract.
        let cases = [
            ("简化 May 2026 笔记。", "vault/notes/2026年5月"),
            ("🚀 Summarise these notes 📝", "vault/🗂️/incoming"),
            ("café — résumé", "vault/notes/café"),
            ("日本語 + العربية + 한국어 mixed", "vault/multilingual"),
            ("combining ä + à + â", "vault/combining"),
        ];
        for (prompt, scope) in cases {
            let mp = MissionPacket {
                blueprint_id: AgentBlueprintId("unicode-fixture".into()),
                user_prompt: prompt.into(),
                vault_scope: scope.into(),
            };
            let s = serde_json::to_string(&mp).expect("serialise unicode");
            let back: MissionPacket =
                serde_json::from_str(&s).expect("deserialise unicode");
            assert_eq!(back, mp, "round-trip drift on {prompt:?} / {scope:?}");
            assert_eq!(back.user_prompt, prompt);
            assert_eq!(back.vault_scope, scope);
            // serde_json default: no \u escaping for printable
            // non-ASCII — the literal multi-byte chars appear in
            // the JSON form. Pin that contract too.
            assert!(
                s.contains(prompt),
                "user_prompt {prompt:?} must appear verbatim in JSON, got {s}"
            );
            assert!(
                s.contains(scope),
                "vault_scope {scope:?} must appear verbatim in JSON, got {s}"
            );
        }
    }

    #[test]
    fn mission_and_tool_call_size_constants_pin_exact_values() {
        // Phase 1 hardening — exact-value pin for the size caps,
        // companion to envelope::payload_size_constant_is_4_mib
        // (MutationEnvelope::MAX_RECOMMENDED_PAYLOAD_BYTES) and
        // answer::citation_cap_constant_is_256 (Citation::MAX_RECOMMENDED_PER_PACKET).
        // The over-cap tests confirm the caps reject by REJECTING
        // (size + 1)-byte fixtures, but they don't pin the exact
        // numeric value. A future "bump the cap to 256 KiB" change
        // would silently flow without any test failing — the
        // doctrine choice should be explicit at PR review.
        //
        // Three caps, three values:
        assert_eq!(MissionPacket::MAX_PROMPT_BYTES, 128 * 1024);
        assert_eq!(ToolCall::MAX_NAME_BYTES, 256);
        assert_eq!(ToolCall::MAX_ARGS_BYTES, 64 * 1024);
        // Document the rationale links via the assertions themselves
        // — these match the docstring intent (substrate latency
        // budget for prompts, RunEventLog row-bloat ceiling for
        // tool calls).
    }

    #[test]
    fn every_tool_call_field_is_identity_load_bearing() {
        // Phase 1 hardening — companion to the MissionPacket /
        // AnswerPacket / AgentBlueprint identity pins. ToolCall has
        // 2 fields (name, arguments); each must participate in
        // PartialEq derivation. ToolCall lands in RunEventEntry::Event
        // payloads + AgentEvent::ToolCall variants, and the
        // dispatcher de-dups outstanding tool calls by equality — a
        // silent #[serde(skip)] or PartialEq override that dropped
        // either field would silently collapse distinct calls.
        let base = ToolCall {
            name: "vault.read".into(),
            arguments: serde_json::json!({"path": "notes/a"}),
        };

        let mut diff_name = base.clone();
        diff_name.name = "vault.write".into();
        assert_ne!(diff_name, base, "name must participate in PartialEq");

        let mut diff_args = base.clone();
        diff_args.arguments = serde_json::json!({"path": "notes/b"});
        assert_ne!(diff_args, base, "arguments must participate in PartialEq");

        // Argument-shape changes also count: same key, different value type.
        let mut diff_args_shape = base.clone();
        diff_args_shape.arguments = serde_json::json!({"path": 42});
        assert_ne!(diff_args_shape, base, "argument-type changes must change identity");

        // Sanity preserved.
        assert_eq!(base.clone(), base);
    }

    #[test]
    fn mission_packet_and_tool_call_fields_are_pub_per_field_visibility_doctrine() {
        // Phase 1 hardening — field-visibility pin pair for
        // MissionPacket + ToolCall (companion to the field-visibility
        // pin family iter-505..iter-508).
        //
        // MissionPacket: 3 pub fields
        //   - blueprint_id, user_prompt, vault_scope
        // ToolCall: 2 pub fields
        //   - name, arguments
        //
        // Future "let me hide user_prompt behind a getter for size
        // safety" or "let me hide arguments behind a typed accessor"
        // refactors would silently break direct-field call sites.
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("p".into()),
            user_prompt: "u".into(),
            vault_scope: "v".into(),
        };
        assert_eq!(mp.blueprint_id.0, "p");
        assert_eq!(mp.user_prompt, "u");
        assert_eq!(mp.vault_scope, "v");

        let tc = ToolCall {
            name: "vault.read".into(),
            arguments: serde_json::json!({"k": "v"}),
        };
        assert_eq!(tc.name, "vault.read");
        assert_eq!(tc.arguments["k"], "v");
    }

    #[test]
    fn mission_packet_and_tool_call_struct_field_shapes_pinned_via_destructure() {
        // Phase 1 hardening — struct-field-shape pin pair for
        // MissionPacket + ToolCall (companion to AnswerPacket
        // iter-464, AgentBlueprint iter-465).
        //
        // MissionPacket: EXACTLY 3 fields
        //   - blueprint_id: AgentBlueprintId
        //   - user_prompt: String
        //   - vault_scope: String
        //
        // ToolCall: EXACTLY 2 fields
        //   - name: String
        //   - arguments: serde_json::Value
        //
        // A future "let me add a `priority` field to MissionPacket"
        // or "session_id to ToolCall" would silently change the wire
        // shape — surface here via destructure compile-fail.
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("p".into()),
            user_prompt: "u".into(),
            vault_scope: "v".into(),
        };
        let MissionPacket { blueprint_id, user_prompt, vault_scope } = mp;
        let _: AgentBlueprintId = blueprint_id;
        let _: String = user_prompt;
        let _: String = vault_scope;

        let tc = ToolCall {
            name: "vault.read".into(),
            arguments: serde_json::json!({}),
        };
        let ToolCall { name, arguments } = tc;
        let _: String = name;
        let _: serde_json::Value = arguments;
    }

    #[test]
    fn every_mission_packet_field_is_identity_load_bearing() {
        // Phase 1 hardening — symmetric companion to
        // blueprint::every_blueprint_field_is_identity_load_bearing
        // (5 fields) and answer::every_answer_packet_field_is_identity_load_bearing
        // (7 fields). MissionPacket has 3 fields (blueprint_id,
        // user_prompt, vault_scope); each must participate in
        // PartialEq so a silent #[serde(skip)] or PartialEq override
        // that dropped any field would let two distinct missions
        // compare equal — making dedup / cache keying unreliable.
        let base = MissionPacket {
            blueprint_id: AgentBlueprintId("identity-fixture".into()),
            user_prompt: "base prompt".into(),
            vault_scope: "vault/notes".into(),
        };

        let mut diff_id = base.clone();
        diff_id.blueprint_id = AgentBlueprintId("OTHER".into());
        assert_ne!(diff_id, base, "blueprint_id must participate in PartialEq");

        let mut diff_prompt = base.clone();
        diff_prompt.user_prompt.push_str("X");
        assert_ne!(diff_prompt, base, "user_prompt must participate in PartialEq");

        let mut diff_scope = base.clone();
        diff_scope.vault_scope = "vault/other".into();
        assert_ne!(diff_scope, base, "vault_scope must participate in PartialEq");

        // Sanity preserved: unmodified clone still equals base.
        assert_eq!(base.clone(), base);
    }

    #[test]
    fn mission_packet_serde_tolerates_unknown_extra_fields_per_current_doctrine() {
        // Phase 1 hardening — symmetric companion to iter-121
        // (AgentBlueprint) and iter-122 (AnswerPacket) unknown-fields
        // tolerance pins. MissionPacket is queued / persisted in
        // session state across versions; forward-compat (v3 packet
        // with extra field still deserialisable under v2 reader)
        // depends on the lenient #[serde(deny_unknown_fields)]-NOT-
        // present default.
        //
        // A future tightening would silently start rejecting
        // cross-version mission packets that older agents wrote.
        let base = MissionPacket {
            blueprint_id: AgentBlueprintId("forward-compat-fixture".into()),
            user_prompt: "summarise notes".into(),
            vault_scope: "vault/notes".into(),
        };
        let s = serde_json::to_string(&base).expect("serialise");
        let augmented = s
            .trim_end_matches('}')
            .to_string()
            + r#","future_routing_hint":"experimental-tier-3-prep"}"#;
        let parsed: MissionPacket =
            serde_json::from_str(&augmented).expect("unknown field tolerated");
        // Unknown field silently dropped — round-trip equality holds.
        assert_eq!(parsed, base);
    }

    #[test]
    fn mission_packet_serde_json_preserves_struct_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin extending iter-154
        // (presence + count) with field-order. MissionPacket
        // declares its 3 fields as: blueprint_id, user_prompt,
        // vault_scope. A future reorder would change the byte
        // shape on the wire — semantically equivalent but breaks
        // byte-equal diff tools and any cache-key consumer.
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("a".into()),
            user_prompt: "p".into(),
            vault_scope: "v".into(),
        };
        let s = serde_json::to_string(&mp).expect("serialise");
        let expected_keys_in_order = [
            "\"blueprint_id\":",
            "\"user_prompt\":",
            "\"vault_scope\":",
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
    fn mission_packet_serde_json_contains_all_three_canonical_top_level_keys() {
        // Phase 1 hardening — wire-shape pin matching the pattern
        // established by blueprint_serde_json_contains_all_five_canonical_top_level_keys.
        // MissionPacket has 3 fields (blueprint_id, user_prompt,
        // vault_scope); a silent rename would round-trip cleanly
        // but break consumers parsing by field name (Swift bridge,
        // CLI debug tools, replay JSON readers).
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("a".into()),
            user_prompt: "p".into(),
            vault_scope: "v".into(),
        };
        let json = serde_json::to_value(&mp).expect("serialise");
        let obj = json.as_object().expect("MissionPacket serialises as JSON object");
        for key in ["blueprint_id", "user_prompt", "vault_scope"] {
            assert!(
                obj.contains_key(key),
                "missing top-level key {key:?} in {json:?}"
            );
        }
        // Exactly 3 keys — pins that no field was silently added
        // without doctrine update.
        assert_eq!(
            obj.len(),
            3,
            "expected exactly 3 top-level keys, got {} ({:?})",
            obj.len(),
            obj.keys().collect::<Vec<_>>()
        );
    }

    #[test]
    fn mission_packet_round_trips() {
        let mp = MissionPacket {
            blueprint_id: AgentBlueprintId("research-assistant".to_string()),
            user_prompt: "Summarise the May 2026 notes.".to_string(),
            vault_scope: "vault/notes/2026/may".to_string(),
        };
        let s = serde_json::to_string(&mp).expect("serialize");
        let back: MissionPacket = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(back, mp);
    }

    #[test]
    fn mission_packet_new_under_cap_equals_struct_literal_byte_for_byte() {
        // Phase 1 hardening — thin-wrapper equivalence pin (companion
        // to citation_from_tuple_equals_struct_literal_byte_for_byte at
        // answer.rs). MissionPacket::new is the canonical ergonomic
        // constructor; on a valid under-cap prompt it MUST produce a
        // packet byte-equal to the direct struct-literal form. A
        // future "let me trim trailing whitespace" or "let me normalise
        // the vault_scope path separator" tweak in the helper would
        // silently introduce two distinct packet byte forms depending
        // on call site, breaking RunEventLog row equality.
        //
        // Sweep over representative fixtures: typical, empty fields,
        // Unicode, special chars, leading/trailing whitespace,
        // multi-byte tabs.
        let fixtures: &[(&str, &str, &str)] = &[
            ("research-assistant", "Summarise the May notes", "vault/notes"),
            ("a", "", ""),
            ("b", "  leading whitespace", "vault/notes  "),
            ("c", "tab\there", "\tindented\t"),
            ("blueprint-📝", "勉強します", "vault/ノート/2026年"),
            ("d", "\"quoted\"\nlines", "vault\\\\path"),
        ];
        for (bid, prompt, scope) in fixtures {
            let via_new = MissionPacket::new(
                AgentBlueprintId((*bid).to_string()),
                *prompt,
                *scope,
            )
            .expect("under-cap fixture must accept");
            let via_struct = MissionPacket {
                blueprint_id: AgentBlueprintId((*bid).to_string()),
                user_prompt: (*prompt).to_string(),
                vault_scope: (*scope).to_string(),
            };
            assert_eq!(
                via_new, via_struct,
                "new({bid:?}, {prompt:?}, {scope:?}) must equal struct-literal form"
            );
            // Byte-equal JSON serialisation too — MissionPacket is
            // serialised through the RunEventLog provenance path.
            let j_new = serde_json::to_string(&via_new).expect("serialize new");
            let j_struct = serde_json::to_string(&via_struct).expect("serialize struct");
            assert_eq!(j_new, j_struct);
        }
    }

    #[test]
    fn tool_call_validate_error_precedence_pins_first_check_wins() {
        // Phase 1 hardening — validation-precedence pin. ToolCall::validate
        // runs its checks in a documented order (mission.rs §105-149):
        //   1. EmptyName
        //   2. OversizeName
        //   3. BadName (illegal char)
        //   4. BadName (leading/trailing '.')
        //   5. BadName (containing "..")
        //   6. OversizeArguments
        // The FIRST matching check fires; later ones are unreachable
        // for that input. A future refactor that reordered the checks
        // (e.g., "let me check arguments size first to short-circuit
        // huge inputs") would silently change which error every
        // multi-violation tool call surfaces — breaking AgentEvent::
        // from_tool_call_error mapping + audit dashboards that filter
        // by error kind. Pin the precedence with multi-violation
        // fixtures.
        let oversize_name = "x".repeat(ToolCall::MAX_NAME_BYTES + 1);
        let huge_args = serde_json::json!({
            "blob": "y".repeat(ToolCall::MAX_ARGS_BYTES + 1),
        });

        // Empty-name + would-also-fail-on-args: EmptyName wins over
        // OversizeArguments.
        let c1 = ToolCall {
            name: String::new(),
            arguments: huge_args.clone(),
        };
        assert!(matches!(c1.validate(), Err(ToolCallError::EmptyName)));

        // Oversize-name + bad-char in name: OversizeName wins over BadName.
        let c2 = ToolCall {
            name: format!("bad char {oversize_name}"), // contains space
            arguments: serde_json::json!({}),
        };
        match c2.validate() {
            Err(ToolCallError::OversizeName { .. }) => {}
            other => panic!("expected OversizeName to win, got {other:?}"),
        }

        // Bad-char in name + oversize args: BadName wins over OversizeArguments.
        let c3 = ToolCall {
            name: "bad char".to_string(), // contains space
            arguments: huge_args.clone(),
        };
        match c3.validate() {
            Err(ToolCallError::BadName { bad_char: ' ', .. }) => {}
            other => panic!("expected BadName(' ') to win, got {other:?}"),
        }

        // Leading-dot name + oversize args: BadName('.') wins over OversizeArguments.
        let c4 = ToolCall {
            name: ".leading".to_string(),
            arguments: huge_args.clone(),
        };
        match c4.validate() {
            Err(ToolCallError::BadName { bad_char: '.', .. }) => {}
            other => panic!("expected BadName('.') leading-dot to win, got {other:?}"),
        }

        // Double-dot name + oversize args: BadName('.') wins over OversizeArguments.
        let c5 = ToolCall {
            name: "valid..name".to_string(),
            arguments: huge_args,
        };
        match c5.validate() {
            Err(ToolCallError::BadName { bad_char: '.', .. }) => {}
            other => panic!("expected BadName('.') double-dot to win, got {other:?}"),
        }
    }
}
