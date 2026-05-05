use std::collections::HashSet;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use super::{
    is_dotted_tool_name, is_kebab_name, is_step_id, parse_result_ref, validate_schema,
    validate_unit_interval, FormatError,
};

pub const SKILL_V1_ID: &str = "epistemos://schemas/skill.v1.json";

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct SkillStep {
    pub id: String,
    pub tool: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub input: Option<serde_json::Value>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub input_from: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub params: Option<serde_json::Value>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct SkillManifest {
    #[serde(rename = "$schema")]
    pub schema: String,
    pub id: String,
    pub name: String,
    pub narrative_path: String,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub preconditions: Vec<String>,
    pub steps: Vec<SkillStep>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub success_metric: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_used: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub success_rate: Option<f64>,
    pub schema_version: u32,
}

impl SkillManifest {
    pub fn validate(&self) -> Result<(), FormatError> {
        validate_schema(&self.schema, SKILL_V1_ID, "skill.$schema")?;
        validate_skill_id(&self.id)?;
        if !is_kebab_name(&self.name) {
            return Err(FormatError::Validation(format!(
                "skill.name must be lowercase kebab-case, got {}",
                self.name
            )));
        }
        if !self.narrative_path.ends_with(".skill.md") || self.narrative_path.trim().is_empty() {
            return Err(FormatError::Validation(
                "skill.narrative_path must point at a .skill.md narrative".to_string(),
            ));
        }
        if self.steps.is_empty() {
            return Err(FormatError::Validation(
                "skill.steps must contain at least one step".to_string(),
            ));
        }
        if self.schema_version == 0 {
            return Err(FormatError::Validation(
                "skill.schema_version must be at least 1".to_string(),
            ));
        }
        if let Some(value) = self.success_rate {
            validate_unit_interval(value, "skill.success_rate")?;
        }

        let mut seen = HashSet::with_capacity(self.steps.len());
        for step in &self.steps {
            validate_step(step, &seen)?;
            if !seen.insert(step.id.as_str()) {
                return Err(FormatError::Validation(format!(
                    "duplicate skill step id {}",
                    step.id
                )));
            }
        }
        Ok(())
    }
}

fn validate_step(step: &SkillStep, seen: &HashSet<&str>) -> Result<(), FormatError> {
    if !is_step_id(&step.id) {
        return Err(FormatError::Validation(format!(
            "skill step id must match s[0-9]+, got {}",
            step.id
        )));
    }
    if !is_dotted_tool_name(&step.tool) {
        return Err(FormatError::Validation(format!(
            "skill step tool must be dotted lowercase tool name, got {}",
            step.tool
        )));
    }
    if let Some(input_from) = &step.input_from {
        let Some(source_step) = parse_result_ref(input_from) else {
            return Err(FormatError::Validation(format!(
                "skill step input_from must reference sN.result, got {input_from}"
            )));
        };
        if !seen.contains(source_step) {
            return Err(FormatError::Validation(format!(
                "skill step input_from references unknown or future step {source_step}"
            )));
        }
    }
    Ok(())
}

fn validate_skill_id(value: &str) -> Result<(), FormatError> {
    let Some(rest) = value.strip_prefix("skill.") else {
        return Err(FormatError::Validation(format!(
            "skill.id must start with skill., got {value}"
        )));
    };
    let Some((name, version)) = rest.rsplit_once(".v") else {
        return Err(FormatError::Validation(format!(
            "skill.id must end with .vN, got {value}"
        )));
    };
    if is_kebab_name(name)
        && !version.is_empty()
        && version.bytes().all(|byte| byte.is_ascii_digit())
        && version != "0"
    {
        Ok(())
    } else {
        Err(FormatError::Validation(format!(
            "skill.id must match skill.<kebab-name>.vN, got {value}"
        )))
    }
}
