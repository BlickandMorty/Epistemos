//! Tier A hybrid JSON/Markdown formats recovered from the Quick Capture
//! salvage track.

pub mod intent;
pub mod mem;
pub mod skill;

pub use intent::{Intent, INTENT_V1_ID};
pub use mem::{Actor, MemFile, MemHeader, MemType, Provenance, Signals, MEM_V1_ID};
pub use skill::{SkillManifest, SkillStep, SKILL_V1_ID};

#[derive(Debug, thiserror::Error)]
pub enum FormatError {
    #[error("malformed mem header (line 1 must match `---{{json}}---`): {0}")]
    MalformedMemHeader(String),

    #[error("malformed JSON in mem header: {0}")]
    MemHeaderJson(String),

    #[error("format validation failed: {0}")]
    Validation(String),

    #[error("io: {0}")]
    Io(#[from] std::io::Error),

    #[error("serde: {0}")]
    Serde(#[from] serde_json::Error),
}

pub(crate) fn validate_schema(
    actual: &str,
    expected: &str,
    label: &str,
) -> Result<(), FormatError> {
    if actual == expected {
        Ok(())
    } else {
        Err(FormatError::Validation(format!(
            "{label} must be {expected}, got {actual}"
        )))
    }
}

pub(crate) fn validate_unit_interval(value: f64, label: &str) -> Result<(), FormatError> {
    if value.is_finite() && (0.0..=1.0).contains(&value) {
        Ok(())
    } else {
        Err(FormatError::Validation(format!(
            "{label} must be finite and in 0.0..=1.0"
        )))
    }
}

pub(crate) fn validate_nonempty(value: &str, label: &str) -> Result<(), FormatError> {
    if value.trim().is_empty() {
        Err(FormatError::Validation(format!(
            "{label} must not be empty"
        )))
    } else {
        Ok(())
    }
}

pub(crate) fn is_ulid_like(value: &str) -> bool {
    value.len() == 26
        && value
            .bytes()
            .all(|b| matches!(b, b'0'..=b'9' | b'A'..=b'H' | b'J'..=b'K' | b'M'..=b'N' | b'P'..=b'T' | b'V'..=b'Z'))
}

pub(crate) fn is_kebab_name(value: &str) -> bool {
    !value.is_empty()
        && value.split('-').all(|part| {
            !part.is_empty()
                && part
                    .bytes()
                    .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit())
        })
}

pub(crate) fn is_dotted_tool_name(value: &str) -> bool {
    !value.is_empty()
        && value.split('.').all(|part| {
            !part.is_empty()
                && part
                    .bytes()
                    .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_' || b == b'-')
        })
}

pub(crate) fn is_step_id(value: &str) -> bool {
    value
        .strip_prefix('s')
        .is_some_and(|rest| !rest.is_empty() && rest.bytes().all(|b| b.is_ascii_digit()))
}

pub(crate) fn parse_result_ref(value: &str) -> Option<&str> {
    value
        .strip_suffix(".result")
        .filter(|step_id| is_step_id(step_id))
}
