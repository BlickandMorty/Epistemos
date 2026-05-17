//! Tri-Fusion content fabric, Phase C JSON floor.
//!
//! This first slice intentionally proves only the authoritative
//! ProseMirror JSON path. Markdown, HTML, Swift FFI, editor receiver,
//! and provenance claims must land in later slices with their own tests.

use serde_json::Value;
use thiserror::Error;

pub const TRI_FUSION_JSON_CANONICAL_VERSION: &str = "tri_fusion_json_v0";

const HASH_DOMAIN: &[u8] = b"epistemos.tri_fusion.document.v0\0";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TriFusionDocument {
    root: Value,
    canonical_json: String,
    hash: TriFusionDocumentHash,
}

#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct TriFusionDocumentHash([u8; 32]);

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum TriFusionError {
    #[error("invalid JSON: {message}")]
    InvalidJson { message: String },
    #[error("document root must be a JSON object")]
    RootNotObject,
    #[error("document root must have string type \"doc\"")]
    RootTypeNotDoc,
    #[error("document root must have array content")]
    RootContentNotArray,
    #[error("node at {path} must be a JSON object")]
    NodeNotObject { path: String },
    #[error("node at {path} must have a non-empty string type")]
    NodeTypeInvalid { path: String },
    #[error("node at {path} has non-object attrs")]
    NodeAttrsInvalid { path: String },
    #[error("node at {path} has non-array content")]
    NodeContentInvalid { path: String },
    #[error("node at {path} has non-array marks")]
    NodeMarksInvalid { path: String },
    #[error("mark at {path} must be a JSON object with a non-empty string type")]
    MarkInvalid { path: String },
    #[error("text node at {path} must have string text")]
    TextNodeMissingText { path: String },
}

impl TriFusionDocument {
    pub fn parse_json(input: &str) -> Result<Self, TriFusionError> {
        let root: Value =
            serde_json::from_str(input).map_err(|error| TriFusionError::InvalidJson {
                message: error.to_string(),
            })?;
        Self::from_json_value(root)
    }

    pub fn from_json_value(root: Value) -> Result<Self, TriFusionError> {
        validate_document(&root)?;
        let canonical_json = canonical_json_value(&root);
        let hash = TriFusionDocumentHash::for_canonical_json(&canonical_json);
        Ok(Self {
            root,
            canonical_json,
            hash,
        })
    }

    pub fn canonical_json(&self) -> &str {
        &self.canonical_json
    }

    pub fn root(&self) -> &Value {
        &self.root
    }

    pub fn hash(&self) -> TriFusionDocumentHash {
        self.hash
    }

    pub fn canonical_version(&self) -> &'static str {
        TRI_FUSION_JSON_CANONICAL_VERSION
    }
}

impl TriFusionDocumentHash {
    pub fn for_canonical_json(canonical_json: &str) -> Self {
        let mut hasher = blake3::Hasher::new();
        hasher.update(HASH_DOMAIN);
        hasher.update(TRI_FUSION_JSON_CANONICAL_VERSION.as_bytes());
        hasher.update(b"\0");
        hasher.update(canonical_json.as_bytes());
        let digest = hasher.finalize();
        Self(*digest.as_bytes())
    }

    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    pub fn to_hex(self) -> String {
        hex_lower(&self.0)
    }
}

impl std::fmt::Debug for TriFusionDocumentHash {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_tuple("TriFusionDocumentHash")
            .field(&self.to_hex())
            .finish()
    }
}

impl std::fmt::Display for TriFusionDocumentHash {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.to_hex())
    }
}

fn validate_document(root: &Value) -> Result<(), TriFusionError> {
    let object = root.as_object().ok_or(TriFusionError::RootNotObject)?;

    match object.get("type").and_then(Value::as_str) {
        Some("doc") => {}
        _ => return Err(TriFusionError::RootTypeNotDoc),
    }

    let content = object
        .get("content")
        .and_then(Value::as_array)
        .ok_or(TriFusionError::RootContentNotArray)?;

    for (index, node) in content.iter().enumerate() {
        validate_node(node, &format!("$.content[{index}]"))?;
    }

    Ok(())
}

fn validate_node(node: &Value, path: &str) -> Result<(), TriFusionError> {
    let object = node
        .as_object()
        .ok_or_else(|| TriFusionError::NodeNotObject {
            path: path.to_string(),
        })?;

    let node_type = object
        .get("type")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| TriFusionError::NodeTypeInvalid {
            path: path.to_string(),
        })?;

    if let Some(attrs) = object.get("attrs") {
        if !attrs.is_object() {
            return Err(TriFusionError::NodeAttrsInvalid {
                path: format!("{path}.attrs"),
            });
        }
    }

    if let Some(marks) = object.get("marks") {
        let marks = marks
            .as_array()
            .ok_or_else(|| TriFusionError::NodeMarksInvalid {
                path: format!("{path}.marks"),
            })?;
        for (index, mark) in marks.iter().enumerate() {
            validate_mark(mark, &format!("{path}.marks[{index}]"))?;
        }
    }

    if node_type == "text" && !object.get("text").is_some_and(Value::is_string) {
        return Err(TriFusionError::TextNodeMissingText {
            path: path.to_string(),
        });
    }

    if let Some(content) = object.get("content") {
        let content = content
            .as_array()
            .ok_or_else(|| TriFusionError::NodeContentInvalid {
                path: format!("{path}.content"),
            })?;
        for (index, child) in content.iter().enumerate() {
            validate_node(child, &format!("{path}.content[{index}]"))?;
        }
    }

    Ok(())
}

fn validate_mark(mark: &Value, path: &str) -> Result<(), TriFusionError> {
    let object = mark
        .as_object()
        .ok_or_else(|| TriFusionError::MarkInvalid {
            path: path.to_string(),
        })?;
    let valid_type = object
        .get("type")
        .and_then(Value::as_str)
        .is_some_and(|value| !value.is_empty());
    if valid_type {
        Ok(())
    } else {
        Err(TriFusionError::MarkInvalid {
            path: path.to_string(),
        })
    }
}

fn canonical_json_value(value: &Value) -> String {
    let mut out = String::new();
    write_canonical_json(value, &mut out);
    out
}

fn write_canonical_json(value: &Value, out: &mut String) {
    match value {
        Value::Null => out.push_str("null"),
        Value::Bool(value) => out.push_str(if *value { "true" } else { "false" }),
        Value::Number(value) => out.push_str(&value.to_string()),
        Value::String(value) => {
            out.push_str(&serde_json::to_string(value).expect("string serializes"))
        }
        Value::Array(values) => {
            out.push('[');
            for (index, value) in values.iter().enumerate() {
                if index > 0 {
                    out.push(',');
                }
                write_canonical_json(value, out);
            }
            out.push(']');
        }
        Value::Object(object) => {
            out.push('{');
            let mut keys: Vec<&str> = object.keys().map(String::as_str).collect();
            keys.sort_unstable();
            for (index, key) in keys.iter().enumerate() {
                if index > 0 {
                    out.push(',');
                }
                out.push_str(&serde_json::to_string(key).expect("object key serializes"));
                out.push(':');
                write_canonical_json(&object[*key], out);
            }
            out.push('}');
        }
    }
}

fn hex_lower(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push(HEX[(byte >> 4) as usize] as char);
        out.push(HEX[(byte & 0x0f) as usize] as char);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    const CANONICAL_MINIMAL: &str = r#"{"content":[{"content":[{"text":"Hello","type":"text"}],"type":"paragraph"}],"type":"doc"}"#;

    #[test]
    fn minimal_doc_round_trips_byte_equal() {
        let document = TriFusionDocument::parse_json(CANONICAL_MINIMAL).unwrap();
        assert_eq!(document.canonical_json(), CANONICAL_MINIMAL);
        assert_eq!(
            document.canonical_version(),
            TRI_FUSION_JSON_CANONICAL_VERSION
        );
    }

    #[test]
    fn canonical_json_sorts_object_keys() {
        let input = r#"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Hello"}]}]}"#;
        let document = TriFusionDocument::parse_json(input).unwrap();
        assert_eq!(document.canonical_json(), CANONICAL_MINIMAL);
    }

    #[test]
    fn hash_is_stable_for_equivalent_json() {
        let left = TriFusionDocument::parse_json(CANONICAL_MINIMAL).unwrap();
        let right = TriFusionDocument::parse_json(
            r#"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Hello"}]}]}"#,
        )
        .unwrap();
        assert_eq!(left.hash(), right.hash());
        assert_eq!(left.hash().as_bytes().len(), 32);
        assert_eq!(left.hash().to_hex().len(), 64);
    }

    #[test]
    fn hash_changes_when_text_changes() {
        let left = TriFusionDocument::parse_json(CANONICAL_MINIMAL).unwrap();
        let right = TriFusionDocument::parse_json(
            r#"{"content":[{"content":[{"text":"Goodbye","type":"text"}],"type":"paragraph"}],"type":"doc"}"#,
        )
        .unwrap();
        assert_ne!(left.hash(), right.hash());
    }

    #[test]
    fn rejects_invalid_json() {
        let error = TriFusionDocument::parse_json("{").unwrap_err();
        assert!(matches!(error, TriFusionError::InvalidJson { .. }));
    }

    #[test]
    fn rejects_non_object_root() {
        let error = TriFusionDocument::parse_json("[]").unwrap_err();
        assert_eq!(error, TriFusionError::RootNotObject);
    }

    #[test]
    fn rejects_non_doc_root() {
        let error =
            TriFusionDocument::parse_json(r#"{"content":[],"type":"paragraph"}"#).unwrap_err();
        assert_eq!(error, TriFusionError::RootTypeNotDoc);
    }

    #[test]
    fn rejects_root_without_content_array() {
        let error = TriFusionDocument::parse_json(r#"{"type":"doc"}"#).unwrap_err();
        assert_eq!(error, TriFusionError::RootContentNotArray);
    }

    #[test]
    fn rejects_non_object_child_node() {
        let error = TriFusionDocument::parse_json(r#"{"content":[1],"type":"doc"}"#).unwrap_err();
        assert_eq!(
            error,
            TriFusionError::NodeNotObject {
                path: "$.content[0]".to_string()
            }
        );
    }

    #[test]
    fn rejects_text_node_without_text() {
        let error = TriFusionDocument::parse_json(r#"{"content":[{"type":"text"}],"type":"doc"}"#)
            .unwrap_err();
        assert_eq!(
            error,
            TriFusionError::TextNodeMissingText {
                path: "$.content[0]".to_string()
            }
        );
    }

    #[test]
    fn validates_nested_marks_and_attrs() {
        let document = TriFusionDocument::parse_json(
            r#"{"content":[{"attrs":{"id":"b1"},"content":[{"marks":[{"type":"bold"}],"text":"Hello","type":"text"}],"type":"paragraph"}],"type":"doc"}"#,
        )
        .unwrap();
        assert_eq!(document.root()["type"], "doc");
    }
}
