//! Phase 1 — hybrid JSON+Markdown file formats.
//!
//! Plan: docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md §1.x (formats),
//! §2.x (per-format specs), §24.2-§24.4 (verbatim invariant + Mercury
//! 13-type enum + 4-file soul split).
//!
//! Modules:
//! - `mem` — `.mem` (single-file fusion: line-1 ---{json}--- header
//!   + Markdown body; 13-type MemType enum; verbatim invariant)
//! - `intent` — Intent enum (vault.write, .move, .delete, concept.create,
//!   .alias, memory.write, noop, abort) per §8
//! - `tool_meta` — ToolMeta envelope (status, variant_used, latency_ms,
//!   confidence, schema_version, power_state) per §3.1
//! - `soul` — paired-file 4-file soul directory per §24.4
//!   (SOUL.md, STYLE.md, SKILL.md, MEMORY.jsonl)
//! - `skill` — Voyager-shaped procedural skill per §2.4

pub mod intent;
pub mod mem;
pub mod skill;
pub mod soul;
pub mod tool_meta;

/// Embedded JSON Schemas, content-addressed at compile time. Schema lookup
/// at runtime is `include_str!`-fast, no disk I/O.
///
/// §24.4 user-soul 4-file split (SOUL/STYLE/SKILL/MEMORY) needs separate
/// per-file schemas that the plan does not yet define. Those land in a
/// follow-up commit alongside the vault_registry::VaultId::Soul integration
/// (§25.5) — until then `soul.v1.json` covers the agent-soul shape (§2.3).
pub mod schemas {
    pub const MEM_V1: &str = include_str!("../../schemas/mem.v1.json");
    pub const TOOL_META_V1: &str = include_str!("../../schemas/tool_meta.v1.json");
    pub const INTENT_V1: &str = include_str!("../../schemas/intent.v1.json");
    pub const SOUL_V1: &str = include_str!("../../schemas/soul.v1.json");
    pub const SKILL_V1: &str = include_str!("../../schemas/skill.v1.json");
}

/// Validate a JSON value against an embedded schema. Returns the first
/// validation error path + message, or `Ok(())` on success.
pub fn validate_against(schema_src: &str, value: &serde_json::Value) -> Result<(), FormatError> {
    let schema_json: serde_json::Value = serde_json::from_str(schema_src)
        .map_err(|e| FormatError::SchemaParse(e.to_string()))?;
    let validator = jsonschema::validator_for(&schema_json)
        .map_err(|e| FormatError::SchemaCompile(e.to_string()))?;
    if let Err(err) = validator.validate(value) {
        return Err(FormatError::SchemaValidation(format!(
            "at {}: {}",
            err.instance_path, err
        )));
    }
    Ok(())
}

#[derive(Debug, thiserror::Error)]
pub enum FormatError {
    #[error("malformed mem header (line 1 must match `---{{json}}---`): {0}")]
    MalformedMemHeader(String),

    #[error("malformed JSON in mem header: {0}")]
    MemHeaderJson(String),

    #[error("schema parse failed: {0}")]
    SchemaParse(String),

    #[error("schema compile failed: {0}")]
    SchemaCompile(String),

    #[error("schema validation failed: {0}")]
    SchemaValidation(String),

    #[error("soul directory missing required file: {0}")]
    SoulMissingFile(String),

    #[error("soul integrity check failed: {0}")]
    SoulIntegrity(String),

    #[error("invalid ulid: {0}")]
    InvalidUlid(String),

    #[error("io: {0}")]
    Io(#[from] std::io::Error),

    #[error("serde: {0}")]
    Serde(#[from] serde_json::Error),
}
