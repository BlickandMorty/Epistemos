use agent_core::canon::{
    canonicalize, classify_alias_cosine, AliasDecision, AliasEntry, AliasProvenance, AliasTable,
    ALIAS_DEFER_BAND_LOWER, ALIAS_PROPOSE_MERGE_THRESHOLD, ALIAS_V1_ID,
};
use chrono::{TimeZone, Utc};

#[test]
fn canonicalizer_is_deterministic_order_insensitive_and_stemmed() {
    let baseline = canonicalize("Gradient Checkpointing!");
    assert_eq!(baseline, "checkpoint-gradient");
    assert_eq!(canonicalize("gradient checkpointing"), baseline);
    assert_eq!(canonicalize("checkpointing gradient"), baseline);
    assert_eq!(canonicalize("the gradient of checkpointing"), baseline);
}

#[test]
fn canonicalizer_dedups_stopwords_and_unicode_folds() {
    assert_eq!(canonicalize("the and or but"), "");
    assert_eq!(canonicalize("running running running"), "run");
    assert_eq!(canonicalize("Épistémos v3 final"), "epistemo-final-v3");
}

#[test]
fn alias_thresholds_preserve_no_silent_rename_bands() {
    assert_eq!(ALIAS_PROPOSE_MERGE_THRESHOLD, 0.88);
    assert_eq!(ALIAS_DEFER_BAND_LOWER, 0.72);
    assert_eq!(classify_alias_cosine(0.71), AliasDecision::ConfidentlyNew);
    assert_eq!(classify_alias_cosine(0.72), AliasDecision::DeferToUser);
    assert_eq!(classify_alias_cosine(0.879), AliasDecision::DeferToUser);
    assert_eq!(classify_alias_cosine(0.88), AliasDecision::ProposeMerge);
    assert_eq!(classify_alias_cosine(f64::NAN), AliasDecision::DeferToUser);
}

#[test]
fn alias_table_validates_and_matches_canonicalized_aliases() {
    let mut table = AliasTable::fresh("checkpoint-gradient");
    table.definition = Some("recompute activations to save memory".to_string());
    table.append_alias(AliasEntry {
        name: "rematerialization".to_string(),
        added_at: Utc.with_ymd_and_hms(2026, 4, 29, 1, 0, 0).unwrap(),
        via: AliasProvenance::UserMerge,
        confidence: None,
    });

    table.validate().unwrap();
    assert!(table.matches_canonicalized("Gradient Checkpointing"));
    assert!(table.matches_canonicalized("rematerialization"));
    assert!(!table.matches_canonicalized("attention is all you need"));

    let encoded = serde_json::to_string(&table).unwrap();
    let decoded: AliasTable = serde_json::from_str(&encoded).unwrap();
    assert_eq!(decoded, table);
}

#[test]
fn alias_table_rejects_bad_shapes_and_dedups_by_name_and_provenance() {
    let now = Utc.with_ymd_and_hms(2026, 4, 29, 1, 0, 0).unwrap();
    let mut table = AliasTable::fresh("checkpoint-gradient");
    table.append_alias(AliasEntry {
        name: "rematerialization".to_string(),
        added_at: now,
        via: AliasProvenance::UserMerge,
        confidence: Some(0.91),
    });
    table.append_alias(AliasEntry {
        name: "rematerialization".to_string(),
        added_at: now,
        via: AliasProvenance::UserMerge,
        confidence: Some(0.91),
    });
    table.append_alias(AliasEntry {
        name: "rematerialization".to_string(),
        added_at: now,
        via: AliasProvenance::VariantBOutput,
        confidence: Some(0.91),
    });
    assert_eq!(table.aliases.len(), 2);
    table.validate().unwrap();

    table.canonical_name = "BadCamelCase".to_string();
    assert!(table.validate().is_err());

    let mut long_alias = AliasTable::fresh("checkpoint-gradient");
    long_alias.append_alias(AliasEntry {
        name: "x".repeat(201),
        added_at: now,
        via: AliasProvenance::ManualSeed,
        confidence: None,
    });
    assert!(long_alias.validate().is_err());
}

#[test]
fn alias_table_atomic_save_load_and_path_convention() {
    let dir = tempfile::tempdir().unwrap();
    let path = AliasTable::path_for(dir.path(), "checkpoint-gradient");
    assert_eq!(
        path.file_name().and_then(|name| name.to_str()),
        Some("checkpoint-gradient.alias.json")
    );

    let mut table = AliasTable::fresh("checkpoint-gradient");
    table.append_alias(AliasEntry {
        name: "rematerialization".to_string(),
        added_at: Utc.with_ymd_and_hms(2026, 4, 29, 1, 0, 0).unwrap(),
        via: AliasProvenance::UserMerge,
        confidence: None,
    });
    table.save(&path).unwrap();

    let loaded = AliasTable::load(&path).unwrap();
    assert_eq!(loaded, table);
    let entries = std::fs::read_dir(dir.path()).unwrap().count();
    assert_eq!(entries, 1);
}

#[test]
fn alias_constants_and_provenance_wire_names_are_stable() {
    assert_eq!(ALIAS_V1_ID, "epistemos://schemas/alias.v1.json");
    let cases = [
        (AliasProvenance::UserMerge, "user_merge"),
        (AliasProvenance::VariantBOutput, "variant_b_output"),
        (AliasProvenance::ConceptExtract, "concept_extract"),
        (AliasProvenance::ManualSeed, "manual_seed"),
    ];
    for (provenance, expected) in cases {
        let encoded = serde_json::to_string(&provenance).unwrap();
        assert_eq!(encoded.trim_matches('"'), expected);
    }
}
