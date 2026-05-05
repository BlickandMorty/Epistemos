use schemars::{schema_for, JsonSchema};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
pub enum A2UIComponentKind {
    NoteCard,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum A2UIRetractionStatus {
    Active,
    AtRisk,
    Retracted,
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct A2UIEvidenceItem {
    pub id: String,
    pub title: String,
    pub excerpt: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct A2UINoteCardProps {
    pub claim_id: String,
    pub title: String,
    pub body: String,
    pub evidence: Vec<A2UIEvidenceItem>,
    pub retraction_status: A2UIRetractionStatus,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct A2UINoteCardEnvelope {
    pub id: String,
    pub component: A2UIComponentKind,
    #[serde(flatten)]
    pub props: A2UINoteCardProps,
}

pub fn closed_catalog_component_names() -> Vec<&'static str> {
    vec!["NoteCard"]
}

pub fn catalog_schema_json() -> String {
    serde_json::to_string_pretty(&schema_for!(A2UINoteCardEnvelope))
        .unwrap_or_else(|_| "{}".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn note_card_schema_serializes() {
        let schema = catalog_schema_json();
        assert!(schema.contains("NoteCard"));
        assert!(schema.contains("claimId"));
        assert!(schema.contains("retractionStatus"));
    }
}
