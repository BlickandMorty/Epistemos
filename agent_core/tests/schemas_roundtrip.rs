//! Round-trip parity test for the four hybrid-memory schemas under
//! `agent_core/schemas/epistemos.*.v1.schema.json`.
//!
//! Per `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §B.5
//! acceptance bar:
//!   "Each schema: Loads + parses without error, Validates a known-good
//!    fixture, Rejects a known-bad fixture, Round-trips through Rust
//!    types via schemars (when those types land)."
//!
//! This test covers the first three checks today. Schemars-derive-from-
//! Rust-types parity is a W2.6 follow-up: the Rust types in
//! `agent_core::schemas` are hand-written mirrors of the canonical JSON
//! schemas so the JSON files remain the source of truth (per the
//! README convention). When the Rust types gain `schemars::JsonSchema`
//! derives, an additional assertion will compare the generated schema
//! to the on-disk schema and fail on drift. That work is tracked in
//! the Master Fusion Plan §8 Implementation Log.

use agent_core::schemas::{
    validate_epistemos_payload, ClaimKind, EpistemosPayload, EpistemosSchemaRev,
    SchemaValidationError,
};
use serde_json::Value;

fn schema_path(rev: EpistemosSchemaRev) -> std::path::PathBuf {
    let crate_root = env!("CARGO_MANIFEST_DIR");
    std::path::PathBuf::from(crate_root)
        .join("schemas")
        .join(format!("{}.schema.json", rev.as_str()))
}

fn load_schema(rev: EpistemosSchemaRev) -> Value {
    let path = schema_path(rev);
    let bytes = std::fs::read(&path).unwrap_or_else(|e| {
        panic!("schema file `{}` must exist: {e}", path.display());
    });
    serde_json::from_slice(&bytes).unwrap_or_else(|e| {
        panic!("schema file `{}` must parse as JSON: {e}", path.display());
    })
}

#[test]
fn every_schema_file_loads_and_declares_canonical_schema_rev_const() {
    for rev in [
        EpistemosSchemaRev::SoulV1,
        EpistemosSchemaRev::SkillV1,
        EpistemosSchemaRev::EpisodeV1,
        EpistemosSchemaRev::SemanticV1,
    ] {
        let schema = load_schema(rev);

        // The schema MUST declare a `schema_rev` property whose `const`
        // matches the rev. This is the disk↔code parity anchor.
        let const_value = schema
            .get("properties")
            .and_then(|p| p.get("schema_rev"))
            .and_then(|s| s.get("const"))
            .and_then(|c| c.as_str())
            .unwrap_or_else(|| {
                panic!(
                    "schema {} must declare properties.schema_rev.const",
                    rev.as_str()
                )
            });
        assert_eq!(
            const_value,
            rev.as_str(),
            "schema_rev const drift in {}",
            rev.as_str()
        );

        // additionalProperties must be false (matches the Rust types'
        // `#[serde(deny_unknown_fields)]`).
        assert_eq!(
            schema.get("additionalProperties"),
            Some(&Value::Bool(false)),
            "schema {} must declare additionalProperties:false to stay in sync with Rust deny_unknown_fields",
            rev.as_str()
        );

        // The schema's `required` list must include `schema_rev` so the
        // validator can short-circuit on missing rev.
        let required = schema
            .get("required")
            .and_then(|r| r.as_array())
            .unwrap_or_else(|| panic!("schema {} must declare a `required` array", rev.as_str()));
        assert!(
            required
                .iter()
                .any(|v| v.as_str() == Some("schema_rev")),
            "schema {} must list `schema_rev` as required",
            rev.as_str()
        );
    }
}

#[test]
fn soul_known_good_fixture_validates_and_round_trips() {
    let good = serde_json::json!({
        "schema_rev": "epistemos.soul.v1",
        "soul_id": "abcdef012345",
        "model_id": "qwen3-4b-4bit",
        "identity": {
            "name": "Jordan",
            "voice": "concise / no hedging / cites sources",
            "stance": "prefer local-first / privacy-respecting"
        },
        "preferences": {
            "timezone": "America/Chicago",
            "language": "en-US",
            "tone": "concise",
            "citation_required": true
        },
        "instructions": "## How to behave\n- Cite sources.\n- No hedging.",
        "updated_at": "2026-05-15T20:00:00Z",
        "updated_by": "user"
    });
    let payload = validate_epistemos_payload(&good).expect("valid soul payload");
    assert!(matches!(payload, EpistemosPayload::Soul(_)));
    let back = serde_json::to_value(&payload).expect("re-serialize");
    assert_eq!(back, good, "soul payload must round-trip without loss");
}

#[test]
fn soul_known_bad_fixture_is_rejected() {
    // Missing required `identity` field.
    let bad = serde_json::json!({
        "schema_rev": "epistemos.soul.v1",
        "soul_id": "abcdef012345",
        "model_id": "qwen3-4b-4bit",
        "preferences": {},
        "updated_at": "2026-05-15T20:00:00Z"
    });
    let err = validate_epistemos_payload(&bad).expect_err("must reject missing identity");
    assert!(matches!(err, SchemaValidationError::Deserialize(_)));
}

#[test]
fn skill_known_good_fixture_validates_for_both_oneof_arms() {
    let code = serde_json::json!({
        "schema_rev": "epistemos.skill.v1",
        "skill_id": "abcdef012345",
        "name": "echo",
        "description": "Returns its input.",
        "body": {"kind": "code", "language": "javascript", "source": "return input;"},
        "created_at": "2026-05-15T00:00:00Z"
    });
    validate_epistemos_payload(&code).expect("code-body skill must validate");

    let plan = serde_json::json!({
        "schema_rev": "epistemos.skill.v1",
        "skill_id": "abcdef012345",
        "name": "search+summarize",
        "description": "Search vault then summarize.",
        "body": {
            "kind": "plan",
            "steps": [
                {"tool": "vault.search", "arguments": {"q": "x"}},
                {"tool": "memory.curated", "arguments": {}, "depends_on": [0]}
            ]
        },
        "created_at": "2026-05-15T00:00:00Z"
    });
    validate_epistemos_payload(&plan).expect("plan-body skill must validate");
}

#[test]
fn skill_known_bad_fixture_is_rejected_for_unknown_capability() {
    let bad = serde_json::json!({
        "schema_rev": "epistemos.skill.v1",
        "skill_id": "abcdef012345",
        "name": "x",
        "description": "y",
        "body": {"kind": "code", "language": "javascript", "source": "//"},
        "requires_capabilities": ["evil.escalation"],
        "created_at": "2026-05-15T00:00:00Z"
    });
    let err = validate_epistemos_payload(&bad).expect_err("must reject unknown capability");
    assert!(matches!(err, SchemaValidationError::Deserialize(_)));
}

#[test]
fn episode_known_good_fixture_validates() {
    let good = serde_json::json!({
        "schema_rev": "epistemos.episode.v1",
        "episode_id": "555566667777",
        "occurred_at": "2026-05-15T20:00:00Z",
        "recorded_at": "2026-05-15T20:01:00Z",
        "kind": "user_capture",
        "actor": "user",
        "content": "user noted contradiction in claim X",
        "context": {"vault_path": "notes/claim-x.md"},
        "salience": 0.7,
        "tags": ["contradiction", "claim-x"],
        "linked_episodes": ["aaaabbbbcccc"]
    });
    let payload = validate_epistemos_payload(&good).expect("valid episode payload");
    assert!(matches!(payload, EpistemosPayload::Episode(_)));
}

#[test]
fn episode_known_bad_fixture_is_rejected_for_invalid_linked_id() {
    let bad = serde_json::json!({
        "schema_rev": "epistemos.episode.v1",
        "episode_id": "555566667777",
        "occurred_at": "2026-05-15T20:00:00Z",
        "kind": "user_capture",
        "content": "x",
        "linked_episodes": ["NOT_LOWERCASE"]
    });
    let err = validate_epistemos_payload(&bad).expect_err("must reject bad linked id");
    assert!(matches!(err, SchemaValidationError::InvalidIdPattern { .. }));
}

#[test]
fn semantic_known_good_fixture_validates_all_nine_claim_kinds() {
    let kinds = [
        ("verified_empirical", ClaimKind::VerifiedEmpirical),
        ("verified_mathematical", ClaimKind::VerifiedMathematical),
        ("verified_code_invariant", ClaimKind::VerifiedCodeInvariant),
        ("plausible_empirical", ClaimKind::PlausibleEmpirical),
        ("plausible_causal", ClaimKind::PlausibleCausal),
        ("speculative", ClaimKind::Speculative),
        ("refuted_empirical", ClaimKind::RefutedEmpirical),
        ("refuted_mathematical", ClaimKind::RefutedMathematical),
        ("blocked_safety", ClaimKind::BlockedSafety),
    ];
    for (json_key, expected) in kinds {
        let v = serde_json::json!({
            "schema_rev": "epistemos.semantic.v1",
            "fact_id": "111122223333",
            "predicate": "prefers",
            "subject": "user",
            "object": "pacific_time",
            "confidence": 1.0,
            "claim_kind": json_key
        });
        let payload = validate_epistemos_payload(&v).unwrap_or_else(|e| {
            panic!("claim_kind={json_key} must validate, got error: {e}")
        });
        if let EpistemosPayload::Semantic(s) = payload {
            assert_eq!(s.claim_kind, expected, "claim_kind {json_key} mismatch");
        } else {
            panic!("expected Semantic variant for claim_kind={json_key}");
        }
    }
}

#[test]
fn semantic_known_bad_fixture_is_rejected_for_unknown_claim_kind() {
    let bad = serde_json::json!({
        "schema_rev": "epistemos.semantic.v1",
        "fact_id": "111122223333",
        "predicate": "prefers",
        "subject": "user",
        "object": "pacific_time",
        "confidence": 1.0,
        "claim_kind": "made_up_claim_kind"
    });
    let err = validate_epistemos_payload(&bad).expect_err("must reject unknown claim_kind");
    assert!(matches!(err, SchemaValidationError::Deserialize(_)));
}

#[test]
fn semantic_payload_with_retracts_and_derives_from_round_trips() {
    let v = serde_json::json!({
        "schema_rev": "epistemos.semantic.v1",
        "fact_id": "111122223333",
        "predicate": "prefers",
        "subject": "user",
        "object": "pacific_time",
        "confidence": 0.95,
        "claim_kind": "plausible_empirical",
        "retracts": ["aaaabbbbcccc"],
        "derives_from": ["ddddeeeeffff"]
    });
    let payload = validate_epistemos_payload(&v).expect("valid semantic payload");
    let back = serde_json::to_value(&payload).expect("re-serialize");
    assert_eq!(back, v);
}

/// Drift gate: for every field the disk JSON schema lists as `required`,
/// the corresponding Rust struct field MUST also be required (non-`Option`,
/// non-`#[serde(default)]`). If a future schema edit promotes a field to
/// `required` but the Rust mirror still treats it as optional, runtime
/// `validate_epistemos_payload` would accept payloads the JSON schema
/// rejects — a real drift visible only at the boundary.
///
/// Strategy: take a known-good fixture, programmatically delete each
/// field named in the disk `required` array (skipping `schema_rev`,
/// already covered by the dispatcher), and assert Rust rejects with
/// `Deserialize` (the serde "missing field" path).
#[test]
fn disk_required_fields_match_rust_required_fields() {
    fn assert_each_required_field_makes_rust_reject_when_removed(
        rev: EpistemosSchemaRev,
        good: Value,
    ) {
        let schema = load_schema(rev);
        let required: Vec<String> = schema
            .get("required")
            .and_then(|r| r.as_array())
            .unwrap_or_else(|| panic!("{} schema must declare `required` array", rev.as_str()))
            .iter()
            .filter_map(|v| v.as_str().map(str::to_string))
            .collect();
        assert!(
            !required.is_empty(),
            "{} schema must have at least one required field",
            rev.as_str()
        );

        for field in &required {
            // `schema_rev` is dispatcher-required and surfaces a
            // distinct `MissingSchemaRev` error — covered by the
            // existing top-level test; skip here.
            if field == "schema_rev" {
                continue;
            }
            let mut probe = good.clone();
            let removed = probe
                .as_object_mut()
                .unwrap_or_else(|| panic!("{} fixture must be a JSON object", rev.as_str()))
                .remove(field);
            assert!(
                removed.is_some(),
                "{} fixture must contain `{field}` so removal is meaningful — \
                 fixture drift suspected",
                rev.as_str()
            );
            let err = match validate_epistemos_payload(&probe) {
                Ok(_) => panic!(
                    "{} schema lists `{field}` as required, but Rust accepted \
                     the payload after removing it — disk↔code drift. Rust \
                     struct must remove the `Option<...>`/`#[serde(default)]` \
                     so missing `{field}` is rejected at parse time.",
                    rev.as_str()
                ),
                Err(e) => e,
            };
            assert!(
                matches!(err, SchemaValidationError::Deserialize(_)),
                "{} removing required field `{field}` must surface as \
                 Deserialize error (serde missing-field), got: {err:?}",
                rev.as_str()
            );
        }
    }

    // Reuse the schema's own known-good fixtures so the test stays
    // honest if the JSON schemas evolve.
    let soul_good = serde_json::json!({
        "schema_rev": "epistemos.soul.v1",
        "soul_id": "abcdef012345",
        "model_id": "qwen3-4b-4bit",
        "identity": {
            "name": "Jordan",
            "voice": "concise / no hedging / cites sources"
        },
        "preferences": {"tone": "concise"},
        "updated_at": "2026-05-15T20:00:00Z"
    });
    let skill_good = serde_json::json!({
        "schema_rev": "epistemos.skill.v1",
        "skill_id": "abcdef012345",
        "name": "echo",
        "description": "Returns its input.",
        "body": {"kind": "code", "language": "javascript", "source": "return input;"},
        "created_at": "2026-05-15T00:00:00Z"
    });
    let episode_good = serde_json::json!({
        "schema_rev": "epistemos.episode.v1",
        "episode_id": "555566667777",
        "occurred_at": "2026-05-15T20:00:00Z",
        "kind": "user_capture",
        "content": "x"
    });
    let semantic_good = serde_json::json!({
        "schema_rev": "epistemos.semantic.v1",
        "fact_id": "111122223333",
        "predicate": "prefers",
        "subject": "user",
        "object": "pacific_time",
        "confidence": 1.0,
        "claim_kind": "verified_empirical"
    });

    assert_each_required_field_makes_rust_reject_when_removed(
        EpistemosSchemaRev::SoulV1,
        soul_good,
    );
    assert_each_required_field_makes_rust_reject_when_removed(
        EpistemosSchemaRev::SkillV1,
        skill_good,
    );
    assert_each_required_field_makes_rust_reject_when_removed(
        EpistemosSchemaRev::EpisodeV1,
        episode_good,
    );
    assert_each_required_field_makes_rust_reject_when_removed(
        EpistemosSchemaRev::SemanticV1,
        semantic_good,
    );
}
