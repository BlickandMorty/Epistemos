use agent_core::a2ui::schemas::{catalog_schema_json, closed_catalog_component_names};

#[test]
fn d3_closed_catalog_exports_note_card_schema() {
    let names = closed_catalog_component_names();
    assert_eq!(names, vec!["NoteCard"]);

    let schema = catalog_schema_json();
    assert!(schema.contains("NoteCard"), "{schema}");
    assert!(schema.contains("claimId"), "{schema}");
    assert!(schema.contains("retractionStatus"), "{schema}");
    assert!(!schema.contains("RawInspector"), "{schema}");
}
