//! `communication.send_message` — send to slack/telegram/discord/webhook/
//! matrix/whatsapp/signal/email. Plan §3.5 communication family.
//!
//! **Destructive**: sending is irreversible and visible to others. Per
//! FINAL_SYNTHESIS §5.6 cloud egress and irreversible-action gates: the
//! existing legacy permission gate (RiskLevel::Destructive) fires unless
//! the caller already pre-approved. `small_model_safe: false` so the 1.5B
//! router never auto-sends.

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
            "required": ["platform", "message"],
            "properties": {
                "platform": {
                    "type": "string",
                    "enum": ["slack","telegram","discord","webhook","matrix","whatsapp","signal","email"]
                },
                "message": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 32768,
                    "description": "Body (≤4096 chars for chat platforms; ≤32768 for email)."
                },
                "target": { "type": "string" },
                "webhook_url": { "type": "string" },
                "room_id": { "type": "string" },
                "to": {
                    "description": "Explicit recipient (string or array) for whatsapp/signal/email."
                },
                "subject": { "type": "string" },
                "reply_to": { "type": "string" }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "communication.send_message",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: false,
};
