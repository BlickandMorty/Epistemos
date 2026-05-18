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

impl MissionPacket {
    /// Maximum prompt length we will accept. Beyond this, the executor
    /// rejects before touching the provider. Bound chosen to keep
    /// substrate latency budgets honest; tune as needed.
    pub const MAX_PROMPT_BYTES: usize = 128 * 1024;

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
    fn malformed_tool_call_rejected_leading_dot() {
        let bad = ToolCall {
            name: ".secret".to_string(),
            arguments: serde_json::json!({}),
        };
        assert!(matches!(bad.validate(), Err(ToolCallError::BadName { .. })));
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
    fn good_tool_call_passes() {
        good_call().validate().expect("good call must validate");
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
}
