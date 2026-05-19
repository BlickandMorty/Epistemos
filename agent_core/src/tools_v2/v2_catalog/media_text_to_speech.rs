//! `media.text_to_speech` — render text to audio via macOS `say`.
//! Plan §3.5 media family. Pro-only because it spawns a subprocess
//! (`say` binary) and is therefore not reachable from the AppStoreSafe
//! variant ladder; the existing `harden_cli_subprocess` chain in
//! security.rs gates the spawn at runtime.

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
            "required": ["text"],
            "properties": {
                "text": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 8000
                },
                "voice": {
                    "type": "string",
                    "description": "macOS voice name (e.g., Samantha, Alex, Ava)."
                },
                "rate": {
                    "type": "integer",
                    "description": "Words per minute (default ~175).",
                    "minimum": 1,
                    "maximum": 1000
                },
                "output_path": {
                    "type": "string",
                    "description": "Optional audio file path. Omit to play live."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "media.text_to_speech",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::ProOnly,
    small_model_safe: false,
};
