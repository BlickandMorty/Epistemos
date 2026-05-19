//! `intelligence.nightbrain_trigger` — fire a NightBrain background job
//! (Specialty D1). Plan §3.5 intelligence family. Modification (mutates
//! background state); delegate-bound (the NightBrain scheduler lives in
//! Swift behind the AgentEventDelegate).
//!
//! Per FINAL_SYNTHESIS §2 layer 7 (metabolism / NightBrain) and §6 wave
//! sequencing: NightBrain is the substrate's overnight self-tuning loop.
//! Wave 8 deliberation reuses this Tool surface for auto-research.

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
            "required": ["job"],
            "properties": {
                "job": {
                    "type": "string",
                    "enum": [
                        "event_checkpoint",
                        "search_index_checkpoint",
                        "artifact_dedup",
                        "workspace_compaction",
                        "memory_distillation",
                        "cloud_knowledge_distillation",
                        "session_graph_generation",
                        "skill_evolution_analysis",
                        "ssm_state_pruning",
                        "vault_integrity_check",
                        "maintenance_log"
                    ]
                },
                "priority": {
                    "type": "string",
                    "enum": ["normal", "immediate"],
                    "default": "normal"
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "intelligence.nightbrain_trigger",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
