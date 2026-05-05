use std::path::{Path, PathBuf};

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::format::{validate_unit_interval, FormatError};

use super::{canonicalize, is_canonical_name};

pub const ALIAS_V1_ID: &str = "epistemos://schemas/alias.v1.json";

pub const ALIAS_PROPOSE_MERGE_THRESHOLD: f64 = 0.88;
pub const ALIAS_DEFER_BAND_LOWER: f64 = 0.72;

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum AliasProvenance {
    UserMerge,
    VariantBOutput,
    ConceptExtract,
    ManualSeed,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct AliasEntry {
    pub name: String,
    pub added_at: DateTime<Utc>,
    pub via: AliasProvenance,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub confidence: Option<f64>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct AliasTable {
    #[serde(rename = "$schema")]
    pub schema: String,
    pub canonical_name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub definition: Option<String>,
    #[serde(default)]
    pub aliases: Vec<AliasEntry>,
    pub schema_version: u32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub last_modified: Option<DateTime<Utc>>,
}

impl AliasTable {
    pub fn fresh(canonical_name: impl Into<String>) -> Self {
        Self {
            schema: ALIAS_V1_ID.to_string(),
            canonical_name: canonical_name.into(),
            definition: None,
            aliases: Vec::new(),
            schema_version: 1,
            last_modified: None,
        }
    }

    pub fn append_alias(&mut self, alias: AliasEntry) {
        if self
            .aliases
            .iter()
            .any(|entry| entry.name == alias.name && entry.via == alias.via)
        {
            return;
        }
        self.aliases.push(alias);
        self.last_modified = Some(Utc::now());
    }

    pub fn validate(&self) -> Result<(), FormatError> {
        if self.schema != ALIAS_V1_ID {
            return Err(FormatError::Validation(format!(
                "alias.$schema must be {}, got {}",
                ALIAS_V1_ID, self.schema
            )));
        }
        if !is_canonical_name(&self.canonical_name) {
            return Err(FormatError::Validation(format!(
                "alias.canonical_name must be lowercase canonical kebab-case, got {}",
                self.canonical_name
            )));
        }
        if self.schema_version == 0 {
            return Err(FormatError::Validation(
                "alias.schema_version must be at least 1".to_string(),
            ));
        }
        if let Some(definition) = &self.definition {
            if definition.trim().is_empty() {
                return Err(FormatError::Validation(
                    "alias.definition must not be empty when present".to_string(),
                ));
            }
        }

        for alias in &self.aliases {
            validate_alias_entry(alias)?;
        }
        Ok(())
    }

    pub fn save(&self, path: &Path) -> Result<(), FormatError> {
        self.validate()?;
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let bytes = serde_json::to_vec_pretty(self)?;
        let tmp_path = temp_path_for(path);
        std::fs::write(&tmp_path, bytes)?;
        std::fs::rename(&tmp_path, path)?;
        Ok(())
    }

    pub fn load(path: &Path) -> Result<Self, FormatError> {
        let bytes = std::fs::read(path)?;
        let table: Self = serde_json::from_slice(&bytes)?;
        table.validate()?;
        Ok(table)
    }

    pub fn path_for(concept_dir: &Path, canonical_name: &str) -> PathBuf {
        concept_dir.join(format!("{canonical_name}.alias.json"))
    }

    pub fn matches_canonicalized(&self, query: &str) -> bool {
        let query_canonical = canonicalize(query);
        query_canonical == self.canonical_name
            || self
                .aliases
                .iter()
                .any(|alias| canonicalize(&alias.name) == query_canonical)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AliasDecision {
    ProposeMerge,
    DeferToUser,
    ConfidentlyNew,
}

pub fn classify_alias_cosine(cosine: f64) -> AliasDecision {
    if !cosine.is_finite() {
        AliasDecision::DeferToUser
    } else if cosine >= ALIAS_PROPOSE_MERGE_THRESHOLD {
        AliasDecision::ProposeMerge
    } else if cosine >= ALIAS_DEFER_BAND_LOWER {
        AliasDecision::DeferToUser
    } else {
        AliasDecision::ConfidentlyNew
    }
}

fn validate_alias_entry(alias: &AliasEntry) -> Result<(), FormatError> {
    if alias.name.trim().is_empty() {
        return Err(FormatError::Validation(
            "alias.name must not be empty".to_string(),
        ));
    }
    if alias.name.chars().count() > 200 {
        return Err(FormatError::Validation(
            "alias.name must be at most 200 characters".to_string(),
        ));
    }
    if let Some(confidence) = alias.confidence {
        validate_unit_interval(confidence, "alias.confidence")?;
    }
    Ok(())
}

fn temp_path_for(path: &Path) -> PathBuf {
    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("alias.json");
    path.with_file_name(format!(".{file_name}.tmp"))
}
