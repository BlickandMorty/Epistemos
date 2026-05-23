use agent_core::tri_fusion::{TriFusionDocument, TriFusionError};

const MINIMAL_DOC: &str =
    r#"{"content":[{"content":[{"text":"Hello","type":"text"}],"type":"paragraph"}],"type":"doc"}"#;

#[test]
fn seed_fixture_round_trips_byte_equal() {
    let document = TriFusionDocument::parse_json(MINIMAL_DOC).unwrap();
    assert_eq!(document.canonical_json(), MINIMAL_DOC);
}

#[test]
fn semantically_equal_seed_fixture_has_stable_hash() {
    let canonical = TriFusionDocument::parse_json(MINIMAL_DOC).unwrap();
    let reordered = TriFusionDocument::parse_json(
        r#"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Hello"}]}]}"#,
    )
    .unwrap();

    assert_eq!(canonical.canonical_json(), reordered.canonical_json());
    assert_eq!(canonical.hash(), reordered.hash());
}

#[test]
fn changed_seed_fixture_changes_hash() {
    let original = TriFusionDocument::parse_json(MINIMAL_DOC).unwrap();
    let changed = TriFusionDocument::parse_json(
        r#"{"content":[{"content":[{"text":"Changed","type":"text"}],"type":"paragraph"}],"type":"doc"}"#,
    )
    .unwrap();

    assert_ne!(original.hash(), changed.hash());
}

#[test]
fn malformed_root_fails_before_hashing() {
    let error = TriFusionDocument::parse_json(r#"{"content":[],"type":"paragraph"}"#).unwrap_err();
    assert_eq!(error, TriFusionError::RootTypeNotDoc);
}
