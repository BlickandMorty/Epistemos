#![cfg(feature = "research")]

use agent_core::research::hyperdynamic_schemas::{
    validate_document_shape, DocumentPath, DocumentShape, DocumentValidationError, FieldSchema,
    FieldType, Schema,
};
use agent_core::tri_fusion::TriFusionDocument;

fn paragraph_shape() -> DocumentShape {
    DocumentShape::new()
        .with_node_attrs(
            "paragraph",
            Schema::new().with("id", FieldSchema::strict(FieldType::String)),
        )
        .require_block_identity_for("paragraph")
}

#[test]
fn tri_fusion_document_passes_nested_shape_validation() {
    let document = TriFusionDocument::parse_json(
        r#"{"content":[{"attrs":{"id":"b1"},"content":[{"text":"Hello","type":"text"}],"type":"paragraph"}],"type":"doc"}"#,
    )
    .unwrap();

    assert!(validate_document_shape(&paragraph_shape(), document.root()).is_empty());
}

#[test]
fn nested_shape_validation_reports_stable_attr_path() {
    let document = TriFusionDocument::parse_json(
        r#"{"content":[{"attrs":{},"content":[{"text":"Hello","type":"text"}],"type":"paragraph"}],"type":"doc"}"#,
    )
    .unwrap();

    let errors = validate_document_shape(&paragraph_shape(), document.root());
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
}

#[test]
fn nested_shape_validation_does_not_change_canonical_json() {
    let document = TriFusionDocument::parse_json(
        r#"{"content":[{"attrs":{"id":"b1"},"content":[{"text":"Hello","type":"text"}],"type":"paragraph"}],"type":"doc"}"#,
    )
    .unwrap();
    let before = document.canonical_json().to_string();

    let errors = validate_document_shape(&paragraph_shape(), document.root());

    assert!(errors.is_empty());
    assert_eq!(document.canonical_json(), before);
}
