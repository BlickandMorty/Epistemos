//! Nested document-shape validation for the Tri-Fusion JSON floor.
//!
//! This module does not replace the flat repair substrate. It layers
//! path-aware ProseMirror-like validation over the existing scalar
//! `Schema` / `FieldSchema` vocabulary so Tri-Fusion can report stable
//! nested locations without weakening flat schema repair semantics.

use super::repair::{FieldType, Schema};
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use std::collections::{BTreeMap, BTreeSet};
use std::fmt;

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub enum DocumentPathSegment {
    Field(String),
    Index(usize),
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct DocumentPath {
    segments: Vec<DocumentPathSegment>,
}

impl DocumentPath {
    pub fn root() -> Self {
        Self {
            segments: Vec::new(),
        }
    }

    pub fn field(&self, name: impl Into<String>) -> Self {
        let mut segments = self.segments.clone();
        segments.push(DocumentPathSegment::Field(name.into()));
        Self { segments }
    }

    pub fn index(&self, index: usize) -> Self {
        let mut segments = self.segments.clone();
        segments.push(DocumentPathSegment::Index(index));
        Self { segments }
    }

    pub fn segments(&self) -> &[DocumentPathSegment] {
        &self.segments
    }
}

impl fmt::Display for DocumentPath {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("$")?;
        for segment in &self.segments {
            match segment {
                DocumentPathSegment::Field(name) if is_simple_field(name) => {
                    f.write_str(".")?;
                    f.write_str(name)?;
                }
                DocumentPathSegment::Field(name) => {
                    f.write_str("[")?;
                    f.write_str(&serde_json::to_string(name).map_err(|_| fmt::Error)?)?;
                    f.write_str("]")?;
                }
                DocumentPathSegment::Index(index) => {
                    write!(f, "[{index}]")?;
                }
            }
        }
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct NodeShape {
    pub attrs: Schema,
    pub require_block_identity: bool,
}

impl NodeShape {
    pub fn new() -> Self {
        Self {
            attrs: Schema::new(),
            require_block_identity: false,
        }
    }

    pub fn with_attrs(mut self, attrs: Schema) -> Self {
        self.attrs = attrs;
        self
    }

    pub fn require_block_identity(mut self) -> Self {
        self.require_block_identity = true;
        self
    }
}

impl Default for NodeShape {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DocumentShape {
    pub node_shapes: BTreeMap<String, NodeShape>,
    pub identity_attr_names: BTreeSet<String>,
}

impl DocumentShape {
    pub fn new() -> Self {
        let mut identity_attr_names = BTreeSet::new();
        identity_attr_names.insert("block_id".to_string());
        identity_attr_names.insert("id".to_string());
        Self {
            node_shapes: BTreeMap::new(),
            identity_attr_names,
        }
    }

    pub fn with_node_shape(mut self, node_type: impl Into<String>, shape: NodeShape) -> Self {
        self.node_shapes.insert(node_type.into(), shape);
        self
    }

    pub fn with_node_attrs(mut self, node_type: impl Into<String>, attrs: Schema) -> Self {
        self.node_shapes.entry(node_type.into()).or_default().attrs = attrs;
        self
    }

    pub fn require_block_identity_for(mut self, node_type: impl Into<String>) -> Self {
        self.node_shapes
            .entry(node_type.into())
            .or_default()
            .require_block_identity = true;
        self
    }
}

impl Default for DocumentShape {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum DocumentValidationError {
    RootNotObject {
        path: DocumentPath,
    },
    RootTypeInvalid {
        path: DocumentPath,
    },
    RootContentInvalid {
        path: DocumentPath,
    },
    NodeNotObject {
        path: DocumentPath,
    },
    NodeTypeInvalid {
        path: DocumentPath,
    },
    NodeAttrsInvalid {
        path: DocumentPath,
    },
    NodeContentInvalid {
        path: DocumentPath,
    },
    MissingRequiredAttribute {
        path: DocumentPath,
        expected: Vec<FieldType>,
    },
    AttributeTypeMismatch {
        path: DocumentPath,
        expected: Vec<FieldType>,
        actual: FieldType,
    },
    UnknownAttribute {
        path: DocumentPath,
        actual: FieldType,
    },
    UnsupportedAttributeValue {
        path: DocumentPath,
    },
    MissingBlockIdentity {
        path: DocumentPath,
        accepted_attrs: Vec<String>,
    },
}

impl DocumentValidationError {
    pub const fn kind(&self) -> &'static str {
        match self {
            DocumentValidationError::RootNotObject { .. } => "root_not_object",
            DocumentValidationError::RootTypeInvalid { .. } => "root_type_invalid",
            DocumentValidationError::RootContentInvalid { .. } => "root_content_invalid",
            DocumentValidationError::NodeNotObject { .. } => "node_not_object",
            DocumentValidationError::NodeTypeInvalid { .. } => "node_type_invalid",
            DocumentValidationError::NodeAttrsInvalid { .. } => "node_attrs_invalid",
            DocumentValidationError::NodeContentInvalid { .. } => "node_content_invalid",
            DocumentValidationError::MissingRequiredAttribute { .. } => "missing_required_attr",
            DocumentValidationError::AttributeTypeMismatch { .. } => "attribute_type_mismatch",
            DocumentValidationError::UnknownAttribute { .. } => "unknown_attribute",
            DocumentValidationError::UnsupportedAttributeValue { .. } => "unsupported_attr_value",
            DocumentValidationError::MissingBlockIdentity { .. } => "missing_block_identity",
        }
    }

    pub fn path(&self) -> &DocumentPath {
        match self {
            DocumentValidationError::RootNotObject { path }
            | DocumentValidationError::RootTypeInvalid { path }
            | DocumentValidationError::RootContentInvalid { path }
            | DocumentValidationError::NodeNotObject { path }
            | DocumentValidationError::NodeTypeInvalid { path }
            | DocumentValidationError::NodeAttrsInvalid { path }
            | DocumentValidationError::NodeContentInvalid { path }
            | DocumentValidationError::MissingRequiredAttribute { path, .. }
            | DocumentValidationError::AttributeTypeMismatch { path, .. }
            | DocumentValidationError::UnknownAttribute { path, .. }
            | DocumentValidationError::UnsupportedAttributeValue { path }
            | DocumentValidationError::MissingBlockIdentity { path, .. } => path,
        }
    }
}

pub fn validate_document_shape(
    shape: &DocumentShape,
    document: &JsonValue,
) -> Vec<DocumentValidationError> {
    let root_path = DocumentPath::root();
    let Some(root) = document.as_object() else {
        return vec![DocumentValidationError::RootNotObject { path: root_path }];
    };

    let mut errors = Vec::new();
    if root.get("type").and_then(JsonValue::as_str) != Some("doc") {
        errors.push(DocumentValidationError::RootTypeInvalid {
            path: root_path.field("type"),
        });
    }

    match root.get("content").and_then(JsonValue::as_array) {
        Some(content) => {
            for (index, node) in content.iter().enumerate() {
                validate_node_shape(
                    shape,
                    node,
                    &root_path.field("content").index(index),
                    &mut errors,
                );
            }
        }
        None => errors.push(DocumentValidationError::RootContentInvalid {
            path: root_path.field("content"),
        }),
    }

    errors
}

fn validate_node_shape(
    shape: &DocumentShape,
    node: &JsonValue,
    path: &DocumentPath,
    errors: &mut Vec<DocumentValidationError>,
) {
    let Some(node_object) = node.as_object() else {
        errors.push(DocumentValidationError::NodeNotObject { path: path.clone() });
        return;
    };

    let node_type = match node_object
        .get("type")
        .and_then(JsonValue::as_str)
        .filter(|value| !value.is_empty())
    {
        Some(node_type) => node_type,
        None => {
            errors.push(DocumentValidationError::NodeTypeInvalid {
                path: path.field("type"),
            });
            return;
        }
    };

    let attrs_path = path.field("attrs");
    let attrs = match node_object.get("attrs") {
        Some(attrs) => match attrs.as_object() {
            Some(attrs) => Some(attrs),
            None => {
                errors.push(DocumentValidationError::NodeAttrsInvalid { path: attrs_path });
                None
            }
        },
        None => None,
    };

    if let Some(node_shape) = shape.node_shapes.get(node_type) {
        validate_attrs(node_shape, attrs, &path.field("attrs"), errors);
        if node_shape.require_block_identity && !has_block_identity(shape, attrs) {
            errors.push(DocumentValidationError::MissingBlockIdentity {
                path: path.field("attrs"),
                accepted_attrs: shape.identity_attr_names.iter().cloned().collect(),
            });
        }
    }

    if let Some(content) = node_object.get("content") {
        match content.as_array() {
            Some(content) => {
                for (index, child) in content.iter().enumerate() {
                    validate_node_shape(shape, child, &path.field("content").index(index), errors);
                }
            }
            None => errors.push(DocumentValidationError::NodeContentInvalid {
                path: path.field("content"),
            }),
        }
    }
}

fn validate_attrs(
    node_shape: &NodeShape,
    attrs: Option<&serde_json::Map<String, JsonValue>>,
    attrs_path: &DocumentPath,
    errors: &mut Vec<DocumentValidationError>,
) {
    for (name, field_schema) in &node_shape.attrs.fields {
        match attrs.and_then(|attrs| attrs.get(name)) {
            Some(value) => match json_field_type(value) {
                Some(actual)
                    if field_schema
                        .allowed_types
                        .iter()
                        .any(|expected| *expected == actual) => {}
                Some(actual) => errors.push(DocumentValidationError::AttributeTypeMismatch {
                    path: attrs_path.field(name),
                    expected: field_schema.allowed_types.clone(),
                    actual,
                }),
                None => errors.push(DocumentValidationError::UnsupportedAttributeValue {
                    path: attrs_path.field(name),
                }),
            },
            None if field_schema.required => {
                errors.push(DocumentValidationError::MissingRequiredAttribute {
                    path: attrs_path.field(name),
                    expected: field_schema.allowed_types.clone(),
                });
            }
            None => {}
        }
    }

    if let Some(attrs) = attrs {
        for (name, value) in attrs {
            if node_shape.attrs.fields.contains_key(name) {
                continue;
            }
            match json_field_type(value) {
                Some(actual) => errors.push(DocumentValidationError::UnknownAttribute {
                    path: attrs_path.field(name),
                    actual,
                }),
                None => errors.push(DocumentValidationError::UnsupportedAttributeValue {
                    path: attrs_path.field(name),
                }),
            }
        }
    }
}

fn has_block_identity(
    shape: &DocumentShape,
    attrs: Option<&serde_json::Map<String, JsonValue>>,
) -> bool {
    let Some(attrs) = attrs else {
        return false;
    };
    shape.identity_attr_names.iter().any(|name| {
        attrs
            .get(name)
            .and_then(JsonValue::as_str)
            .is_some_and(|value| !value.is_empty())
    })
}

fn json_field_type(value: &JsonValue) -> Option<FieldType> {
    match value {
        JsonValue::Null => Some(FieldType::Null),
        JsonValue::Bool(_) => Some(FieldType::Bool),
        JsonValue::String(_) => Some(FieldType::String),
        JsonValue::Number(number) if number.is_i64() || number.is_u64() => Some(FieldType::Integer),
        JsonValue::Number(_) => Some(FieldType::Float),
        JsonValue::Array(_) | JsonValue::Object(_) => None,
    }
}

fn is_simple_field(name: &str) -> bool {
    let mut chars = name.chars();
    matches!(chars.next(), Some(first) if first == '_' || first.is_ascii_alphabetic())
        && chars.all(|ch| ch == '_' || ch.is_ascii_alphanumeric())
}

#[cfg(test)]
mod tests {
    use super::super::repair::FieldSchema;
    use super::*;
    use serde_json::json;

    fn paragraph_shape() -> DocumentShape {
        DocumentShape::new()
            .with_node_attrs(
                "paragraph",
                Schema::new()
                    .with("id", FieldSchema::strict(FieldType::String))
                    .with("confidence", FieldSchema::optional(FieldType::Float)),
            )
            .require_block_identity_for("paragraph")
    }

    #[test]
    fn document_path_renders_nested_locations() {
        let path = DocumentPath::root()
            .field("content")
            .index(2)
            .field("attrs")
            .field("block-id");
        assert_eq!(path.to_string(), r#"$.content[2].attrs["block-id"]"#);
    }

    #[test]
    fn valid_document_shape_returns_no_errors() {
        let document = json!({
            "type": "doc",
            "content": [
                { "type": "paragraph", "attrs": { "id": "b1", "confidence": 0.75 } }
            ]
        });
        assert!(validate_document_shape(&paragraph_shape(), &document).is_empty());
    }

    #[test]
    fn missing_required_attr_reports_stable_path() {
        let document = json!({
            "type": "doc",
            "content": [
                { "type": "paragraph", "attrs": {} }
            ]
        });
        let errors = validate_document_shape(&paragraph_shape(), &document);
        assert_eq!(
            errors[0],
            DocumentValidationError::MissingRequiredAttribute {
                path: DocumentPath::root()
                    .field("content")
                    .index(0)
                    .field("attrs")
                    .field("id"),
                expected: vec![FieldType::String],
            }
        );
        assert_eq!(errors[0].kind(), "missing_required_attr");
    }

    #[test]
    fn attr_type_mismatch_reports_actual_type() {
        let document = json!({
            "type": "doc",
            "content": [
                { "type": "paragraph", "attrs": { "id": 5 } }
            ]
        });
        let errors = validate_document_shape(&paragraph_shape(), &document);
        assert_eq!(
            errors[0],
            DocumentValidationError::AttributeTypeMismatch {
                path: DocumentPath::root()
                    .field("content")
                    .index(0)
                    .field("attrs")
                    .field("id"),
                expected: vec![FieldType::String],
                actual: FieldType::Integer,
            }
        );
    }

    #[test]
    fn non_scalar_attr_is_rejected_with_path() {
        let document = json!({
            "type": "doc",
            "content": [
                { "type": "paragraph", "attrs": { "id": "b1", "meta": { "x": 1 } } }
            ]
        });
        let errors = validate_document_shape(&paragraph_shape(), &document);
        assert_eq!(
            errors[0],
            DocumentValidationError::UnsupportedAttributeValue {
                path: DocumentPath::root()
                    .field("content")
                    .index(0)
                    .field("attrs")
                    .field("meta"),
            }
        );
    }

    #[test]
    fn required_block_identity_accepts_block_id_alias() {
        let document = json!({
            "type": "doc",
            "content": [
                { "type": "paragraph", "attrs": { "id": "b1", "block_id": "b1" } }
            ]
        });
        let shape = DocumentShape::new()
            .with_node_attrs(
                "paragraph",
                Schema::new()
                    .with("id", FieldSchema::strict(FieldType::String))
                    .with("block_id", FieldSchema::optional(FieldType::String)),
            )
            .require_block_identity_for("paragraph");
        assert!(validate_document_shape(&shape, &document).is_empty());
    }

    #[test]
    fn missing_block_identity_reports_accepted_attrs() {
        let document = json!({
            "type": "doc",
            "content": [
                { "type": "paragraph", "attrs": { "id": "" } }
            ]
        });
        let errors = validate_document_shape(&paragraph_shape(), &document);
        assert!(errors.iter().any(|error| matches!(
            error,
            DocumentValidationError::MissingBlockIdentity { accepted_attrs, .. }
                if accepted_attrs == &vec!["block_id".to_string(), "id".to_string()]
        )));
    }

    #[test]
    fn nested_content_errors_keep_traversal_order() {
        let document = json!({
            "type": "doc",
            "content": [
                { "type": "paragraph", "content": [1], "attrs": { "id": "b1" } }
            ]
        });
        let errors = validate_document_shape(&paragraph_shape(), &document);
        assert_eq!(
            errors[0],
            DocumentValidationError::NodeNotObject {
                path: DocumentPath::root()
                    .field("content")
                    .index(0)
                    .field("content")
                    .index(0),
            }
        );
    }

    #[test]
    fn document_shape_round_trips_through_json() {
        let shape = paragraph_shape();
        let encoded = serde_json::to_string(&shape).unwrap();
        let decoded: DocumentShape = serde_json::from_str(&encoded).unwrap();
        assert_eq!(decoded, shape);
    }
}
