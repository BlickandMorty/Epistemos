//! `communication.imessage` — read and send via macOS Messages.app.
//! Plan §3.5 communication family. Reads query ~/Library/Messages/chat.db
//! (Full Disk Access required); send action shells out to AppleScript
//! (Automation permission required + harden_cli_subprocess). Action arg
//! `send` makes this Destructive in legacy registry.
//!
//! `small_model_safe: false` because the action enum mixes read + send
//! and the 1.5B router shouldn't auto-pick `send`.

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
            "required": ["action"],
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["send", "list_chats", "read_chat", "recent", "unread", "search"]
                },
                "to": { "type": "string" },
                "message": {
                    "type": "string",
                    "maxLength": 8192
                },
                "service": {
                    "type": "string",
                    "enum": ["iMessage", "SMS"],
                    "default": "iMessage"
                },
                "chat_id": { "type": "integer", "minimum": 0 },
                "query": { "type": "string" },
                "limit": {
                    "type": "integer",
                    "default": 25,
                    "minimum": 1,
                    "maximum": 500
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "communication.imessage",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: false,
};
