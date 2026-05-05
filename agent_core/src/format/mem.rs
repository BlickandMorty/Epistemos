use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use super::{is_ulid_like, validate_schema, validate_unit_interval, FormatError};

pub const MEM_V1_ID: &str = "epistemos://schemas/mem.v1.json";

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "lowercase")]
pub enum MemType {
    Identity,
    Preference,
    Goal,
    Project,
    Habit,
    Decision,
    Constraint,
    Relationship,
    Episode,
    Reflection,
    Capture,
    Semantic,
    Procedural,
}

impl MemType {
    pub const fn all() -> [Self; 13] {
        [
            Self::Identity,
            Self::Preference,
            Self::Goal,
            Self::Project,
            Self::Habit,
            Self::Decision,
            Self::Constraint,
            Self::Relationship,
            Self::Episode,
            Self::Reflection,
            Self::Capture,
            Self::Semantic,
            Self::Procedural,
        ]
    }
}

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "lowercase")]
pub enum Actor {
    User,
    Agent,
    System,
}

#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct Signals {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub access_count: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_accessed: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub explicit_importance: Option<f64>,
}

impl Signals {
    fn is_empty(&self) -> bool {
        self.access_count.is_none()
            && self.last_accessed.is_none()
            && self.explicit_importance.is_none()
    }

    fn validate(&self) -> Result<(), FormatError> {
        if let Some(value) = self.explicit_importance {
            validate_unit_interval(value, "signals.explicit_importance")?;
        }
        Ok(())
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct Provenance {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub source: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub device: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tool_chain: Vec<String>,
}

impl Provenance {
    fn is_empty(&self) -> bool {
        self.source.is_none() && self.device.is_none() && self.tool_chain.is_empty()
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct MemHeader {
    #[serde(rename = "$schema")]
    pub schema: String,
    pub id: String,
    #[serde(rename = "type")]
    pub mem_type: MemType,
    pub ts: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub actor: Option<Actor>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub links: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub salience: Option<f64>,
    #[serde(default, skip_serializing_if = "Signals::is_empty")]
    pub signals: Signals,
    #[serde(default, skip_serializing_if = "Provenance::is_empty")]
    pub provenance: Provenance,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub schema_version: Option<u32>,
}

impl MemHeader {
    pub fn validate(&self) -> Result<(), FormatError> {
        validate_schema(&self.schema, MEM_V1_ID, "mem.$schema")?;
        if !is_ulid_like(&self.id) {
            return Err(FormatError::Validation(format!(
                "mem.id must match canonical ULID alphabet, got {}",
                self.id
            )));
        }
        if self.tags.len() > 16 {
            return Err(FormatError::Validation(
                "mem.tags must contain at most 16 entries".to_string(),
            ));
        }
        if self.links.len() > 64 {
            return Err(FormatError::Validation(
                "mem.links must contain at most 64 entries".to_string(),
            ));
        }
        if let Some(value) = self.salience {
            validate_unit_interval(value, "mem.salience")?;
        }
        if let Some(version) = self.schema_version {
            if version == 0 {
                return Err(FormatError::Validation(
                    "mem.schema_version must be at least 1".to_string(),
                ));
            }
        }
        self.signals.validate()
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct MemFile {
    pub header: MemHeader,
    pub body: String,
}

impl MemFile {
    pub fn parse(input: &str) -> Result<Self, FormatError> {
        let (header_line, body) = match input.find('\n') {
            Some(index) => (&input[..index], &input[index + 1..]),
            None => (input, ""),
        };
        let inner = parse_header_fence(header_line.trim_end_matches('\r'))?;
        let header = serde_json::from_str(inner)
            .map_err(|error| FormatError::MemHeaderJson(error.to_string()))?;
        Ok(Self {
            header,
            body: body.to_string(),
        })
    }

    pub fn serialize(&self) -> Result<String, FormatError> {
        self.validate()?;
        let header_json = serde_json::to_string(&self.header)?;
        Ok(format!("---{}---\n{}", header_json, self.body))
    }

    pub fn validate(&self) -> Result<(), FormatError> {
        self.header.validate()
    }
}

fn parse_header_fence(line: &str) -> Result<&str, FormatError> {
    let Some(inner) = line
        .strip_prefix("---")
        .and_then(|rest| rest.strip_suffix("---"))
    else {
        return Err(FormatError::MalformedMemHeader(format!(
            "expected ---{{json}}---, got {line:?}"
        )));
    };
    if inner.starts_with('{') && inner.ends_with('}') {
        Ok(inner)
    } else {
        Err(FormatError::MalformedMemHeader(format!(
            "header inner must be a JSON object, got {inner:?}"
        )))
    }
}
