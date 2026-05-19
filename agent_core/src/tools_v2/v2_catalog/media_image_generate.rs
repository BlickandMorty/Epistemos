//! `media.image_generate` — generate an image. Plan §3.5 media family.
//! Modification (writes a file when output_path is set). Per PLAN §5.1 +
//! §16 + §3.4: `provider` is REQUIRED — no default. `mlx` routes through
//! the AgentEventDelegate (Swift MLX sidecar lane); `fal` is the explicit
//! cloud opt-in. Per CLAUDE.md "NO SIDECAR for INFERENCE" the MLX lane is
//! in-process via UniFFI, not a subprocess.

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
            "required": ["prompt", "provider"],
            "properties": {
                "prompt": { "type": "string", "minLength": 1 },
                "aspect_ratio": {
                    "type": "string",
                    "enum": ["landscape", "portrait", "square"],
                    "default": "square"
                },
                "provider": {
                    "type": "string",
                    "enum": ["mlx", "fal"],
                    "description": "mlx = Apple-native sidecar (PLAN §5.1/§16); fal = explicit cloud opt-in. Required."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "media.image_generate",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
