//! `communication.channel_contacts` — per-sender routing for non-iMessage
//! channels (telegram, slack, discord, whatsapp, signal, email).
//! Plan §3.5 communication family. Modification (mutates the contact
//! routing table); local config only.

use std::sync::OnceLock;

use serde_json::{json, Value};

use crate::tools_v2::legacy_adapter::{generic_text_or_object_output_schema, AdapterSpec};
use crate::tools_v2::{Profile, VariantId};

pub fn input_schema() -> &'static Value {
    static S: OnceLock<Value> = OnceLock::new();
    S.get_or_init(|| {
        json!({
            "type": "object",
            "additionalProperties": false,
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["list", "get", "set", "upsert", "remove", "delete", "resolve", "record_message"],
                    "default": "list"
                },
                "channel_id": {
                    "type": "string",
                    "enum": ["telegram", "slack", "discord", "whatsapp", "signal", "email"]
                },
                "handle": { "type": "string" },
                "display_name": { "type": "string" },
                "model": { "type": "string" },
                "tool_tier": {
                    "type": "string",
                    "enum": ["none", "chat_lite", "chat_pro", "agent", "full"],
                    "default": "chat_pro"
                },
                "prompt_mode": {
                    "type": "string",
                    "enum": ["general", "code", "research"],
                    "default": "general"
                },
                "allowed": { "type": "boolean" },
                "auto_reply": { "type": "boolean" },
                "allowed_only": { "type": "boolean", "default": false }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "communication.channel_contacts",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
