//! `capture.voice` — Phase 5 native skill. Record voice input and
//! transcribe via SpeechAnalyzer (or whisper.cpp fallback). Plan §3.5
//! capture family. Read-only (audio buffer is NOT persisted; only the
//! transcript text is returned); delegate-bound.

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
                "max_duration_secs": {
                    "type": "integer",
                    "default": 60,
                    "minimum": 1,
                    "maximum": 600,
                    "description": "Cap on recording length; ASR runs after capture stops."
                },
                "language_hint": {
                    "type": "string",
                    "description": "Optional BCP-47 language hint (e.g. 'en-US')."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "capture.voice",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
