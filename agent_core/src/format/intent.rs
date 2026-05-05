use serde::{Deserialize, Serialize};

use super::{is_kebab_name, validate_nonempty, FormatError};

pub const INTENT_V1_ID: &str = "epistemos://schemas/intent.v1.json";

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(tag = "action", rename_all = "snake_case", deny_unknown_fields)]
pub enum Intent {
    #[serde(rename = "vault.write")]
    VaultWrite {
        path: String,
        body: String,
        frontmatter: serde_json::Value,
    },
    #[serde(rename = "vault.move")]
    VaultMove {
        from: String,
        to: String,
    },
    #[serde(rename = "vault.delete")]
    VaultDelete {
        path: String,
    },
    #[serde(rename = "concept.create")]
    ConceptCreate {
        canonical_name: String,
        definition: String,
    },
    #[serde(rename = "concept.alias")]
    ConceptAlias {
        canonical_name: String,
        alias: String,
    },
    #[serde(rename = "memory.write")]
    MemoryWrite {
        entry: serde_json::Value,
    },
    Noop {
        reason: String,
    },
    Abort {
        reason: String,
    },
}

impl Intent {
    pub fn validate(&self) -> Result<(), FormatError> {
        match self {
            Self::VaultWrite {
                path,
                body: _,
                frontmatter,
            } => {
                validate_path(path, "vault.write.path")?;
                if frontmatter.is_object() {
                    Ok(())
                } else {
                    Err(FormatError::Validation(
                        "vault.write.frontmatter must be a JSON object".to_string(),
                    ))
                }
            }
            Self::VaultMove { from, to } => {
                validate_path(from, "vault.move.from")?;
                validate_path(to, "vault.move.to")
            }
            Self::VaultDelete { path } => validate_path(path, "vault.delete.path"),
            Self::ConceptCreate {
                canonical_name,
                definition,
            } => {
                validate_canonical_name(canonical_name)?;
                validate_nonempty(definition, "concept.create.definition")
            }
            Self::ConceptAlias {
                canonical_name,
                alias,
            } => {
                validate_canonical_name(canonical_name)?;
                validate_nonempty(alias, "concept.alias.alias")
            }
            Self::MemoryWrite { entry } => {
                if entry.is_object() {
                    Ok(())
                } else {
                    Err(FormatError::Validation(
                        "memory.write.entry must be a JSON object".to_string(),
                    ))
                }
            }
            Self::Noop { reason } => validate_reason(reason, "noop.reason"),
            Self::Abort { reason } => validate_reason(reason, "abort.reason"),
        }
    }
}

fn validate_path(path: &str, label: &str) -> Result<(), FormatError> {
    validate_nonempty(path, label)?;
    if path.contains('\0') {
        Err(FormatError::Validation(format!(
            "{label} must not contain NUL"
        )))
    } else {
        Ok(())
    }
}

fn validate_canonical_name(value: &str) -> Result<(), FormatError> {
    if is_kebab_name(value) {
        Ok(())
    } else {
        Err(FormatError::Validation(format!(
            "canonical_name must be lowercase kebab-case, got {value}"
        )))
    }
}

fn validate_reason(reason: &str, label: &str) -> Result<(), FormatError> {
    validate_nonempty(reason, label)?;
    if reason.chars().count() > 280 {
        Err(FormatError::Validation(format!(
            "{label} must be at most 280 characters"
        )))
    } else {
        Ok(())
    }
}
