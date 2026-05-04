//! Phase 3D-2 — alias table per plan §3.7.
//!
//! Plan §3.7: "Alias table: persisted per concept node. Grows from
//! explicit user merges and from B-variant aliases:[...] outputs.
//! Stored as .alias.json next to concept node."
//!
//! Embedding tie-breaker thresholds (§3.7):
//! - cosine ≥ 0.88: propose merge (NEVER auto). User approves → alias added.
//! - cosine 0.72-0.88: defer band — always to user.
//! - cosine < 0.72: confidently new concept; auto-create.
//!
//! "No silent renames" invariant: renaming a canonical concept requires
//! explicit user action. The system never decides on its own that
//! `rematerialization` should become `gradient-checkpointing`; it only
//! proposes via the merge_into_existing_note action gated at variant
//! confidence ≥ 0.90.

use std::path::{Path, PathBuf};

use chrono::{DateTime, Utc};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use crate::format::{validate_against, FormatError};

pub const ALIAS_V1_ID: &str = "epistemos://schemas/alias.v1.json";

const ALIAS_SCHEMA: &str = include_str!("../../schemas/alias.v1.json");

/// Plan §3.7 embedding tie-breaker thresholds. Pinned to plan literal
/// so silent drift would break a test.
pub const ALIAS_PROPOSE_MERGE_THRESHOLD: f64 = 0.88;
pub const ALIAS_DEFER_BAND_LOWER: f64 = 0.72;
// Above 0.88 is propose-merge; 0.72-0.88 is defer-to-user; below 0.72
// is confidently-new — auto-create concept node.

/// Plan §3.7 — provenance of an alias addition.
#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum AliasProvenance {
    /// User explicitly merged surface form → canonical. Highest trust.
    UserMerge,
    /// Variant B's classifier `aliases:[...]` output (§3.7 path 2).
    VariantBOutput,
    /// `knowledge.concept_extract` tool surfaced an alias.
    ConceptExtract,
    /// Developer-shipped fixture seed (e.g. domain-specific aliases
    /// included with the app). Audit-trail only.
    ManualSeed,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct AliasEntry {
    pub name: String,
    pub added_at: DateTime<Utc>,
    pub via: AliasProvenance,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub confidence: Option<f64>,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct AliasTable {
    #[serde(rename = "$schema")]
    pub schema: String,
    pub canonical_name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub definition: Option<String>,
    #[serde(default)]
    pub aliases: Vec<AliasEntry>,
    pub schema_version: u32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub last_modified: Option<DateTime<Utc>>,
}

impl AliasTable {
    pub fn fresh(canonical_name: impl Into<String>) -> Self {
        Self {
            schema: ALIAS_V1_ID.to_string(),
            canonical_name: canonical_name.into(),
            definition: None,
            aliases: Vec::new(),
            schema_version: 1,
            last_modified: None,
        }
    }

    /// Append an alias if not already present (case-sensitive, surface-
    /// form match). The canonicalizer normalizes surface forms when
    /// READING — at write time we preserve what the user/source typed.
    pub fn append_alias(&mut self, alias: AliasEntry) {
        if self
            .aliases
            .iter()
            .any(|a| a.name == alias.name && a.via == alias.via)
        {
            return;
        }
        self.aliases.push(alias);
        self.last_modified = Some(Utc::now());
    }

    pub fn validate(&self) -> Result<(), FormatError> {
        let v = serde_json::to_value(self)?;
        validate_against(ALIAS_SCHEMA, &v)
    }

    /// Plan §6.9 atomic write — uses `crate::util::atomic_write_json`
    /// so half-written tables are never visible to readers.
    pub fn save(&self, path: &Path) -> Result<(), FormatError> {
        // Validate before write — plan §3.7 "no silent renames"
        // invariant means we never persist an inconsistent table.
        self.validate()?;
        crate::util::atomic_write_json(path, self)?;
        Ok(())
    }

    pub fn load(path: &Path) -> Result<Self, FormatError> {
        let bytes = std::fs::read(path)?;
        let table: AliasTable = serde_json::from_slice(&bytes)?;
        if table.schema != ALIAS_V1_ID {
            return Err(FormatError::SchemaValidation(format!(
                "$schema mismatch: expected {} got {}",
                ALIAS_V1_ID, table.schema
            )));
        }
        Ok(table)
    }

    /// Convention: `.alias.json` lives at `<concept_dir>/<canonical>.alias.json`.
    /// Construct the canonical path for a given dir + canonical name.
    pub fn path_for(concept_dir: &Path, canonical_name: &str) -> PathBuf {
        concept_dir.join(format!("{}.alias.json", canonical_name))
    }

    /// Lookup: does any of the surface forms in `aliases[]` (after
    /// canonicalization) match the canonicalized `query`? Returns the
    /// canonical_name if so. Used by Variant C concept-anchored to
    /// resolve "rematerialization" → "checkpoint-gradient" without an
    /// LLM call.
    pub fn matches_canonicalized(&self, query: &str) -> bool {
        let q_canon = super::canonicalize(query);
        // Direct match against this table's canonical_name.
        if q_canon == self.canonical_name {
            return true;
        }
        // Match against any alias's canonicalized form.
        self.aliases
            .iter()
            .any(|a| super::canonicalize(&a.name) == self.canonical_name
                && super::canonicalize(&a.name) == q_canon)
    }
}

/// Plan §3.7 — classify a candidate-existing-concept cosine distance
/// into the three bands. Used by route_capture Variant C to decide
/// merge / defer / new.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AliasDecision {
    /// cosine ≥ 0.88 — propose merge (NEVER auto per §3.7 "no silent
    /// renames"). User approves → caller adds AliasEntry with
    /// `via: UserMerge`.
    ProposeMerge,
    /// cosine 0.72-0.88 — defer band; always surface to user.
    DeferToUser,
    /// cosine < 0.72 — confidently new concept; auto-create node.
    ConfidentlyNew,
}

pub fn classify_alias_cosine(cosine: f64) -> AliasDecision {
    if cosine >= ALIAS_PROPOSE_MERGE_THRESHOLD {
        AliasDecision::ProposeMerge
    } else if cosine >= ALIAS_DEFER_BAND_LOWER {
        AliasDecision::DeferToUser
    } else {
        AliasDecision::ConfidentlyNew
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn thresholds_match_plan_3_7_literal() {
        // Plan §3.7: ≥0.88 propose, 0.72-0.88 defer, <0.72 new.
        assert_eq!(ALIAS_PROPOSE_MERGE_THRESHOLD, 0.88);
        assert_eq!(ALIAS_DEFER_BAND_LOWER, 0.72);
    }

    #[test]
    fn classify_alias_cosine_buckets_per_plan_3_7() {
        // Below 0.72 → ConfidentlyNew.
        assert_eq!(classify_alias_cosine(0.0), AliasDecision::ConfidentlyNew);
        assert_eq!(classify_alias_cosine(0.50), AliasDecision::ConfidentlyNew);
        assert_eq!(classify_alias_cosine(0.71), AliasDecision::ConfidentlyNew);
        // 0.72 to 0.88 → DeferToUser.
        assert_eq!(classify_alias_cosine(0.72), AliasDecision::DeferToUser);
        assert_eq!(classify_alias_cosine(0.80), AliasDecision::DeferToUser);
        assert_eq!(classify_alias_cosine(0.879), AliasDecision::DeferToUser);
        // ≥ 0.88 → ProposeMerge.
        assert_eq!(classify_alias_cosine(0.88), AliasDecision::ProposeMerge);
        assert_eq!(classify_alias_cosine(0.95), AliasDecision::ProposeMerge);
        assert_eq!(classify_alias_cosine(1.0), AliasDecision::ProposeMerge);
    }

    #[test]
    fn fresh_table_validates() {
        let t = AliasTable::fresh("checkpoint-gradient");
        t.validate().expect("fresh table must validate");
    }

    #[test]
    fn append_alias_grows_table_and_updates_timestamp() {
        let mut t = AliasTable::fresh("checkpoint-gradient");
        assert!(t.last_modified.is_none());
        t.append_alias(AliasEntry {
            name: "rematerialization".to_string(),
            added_at: Utc::now(),
            via: AliasProvenance::UserMerge,
            confidence: None,
        });
        assert_eq!(t.aliases.len(), 1);
        assert!(t.last_modified.is_some());
    }

    #[test]
    fn append_alias_dedupes_by_name_and_via() {
        let mut t = AliasTable::fresh("checkpoint-gradient");
        let now = Utc::now();
        t.append_alias(AliasEntry {
            name: "rematerialization".to_string(),
            added_at: now,
            via: AliasProvenance::UserMerge,
            confidence: None,
        });
        // Same name + via → dedup.
        t.append_alias(AliasEntry {
            name: "rematerialization".to_string(),
            added_at: now,
            via: AliasProvenance::UserMerge,
            confidence: None,
        });
        assert_eq!(t.aliases.len(), 1);
        // Same name, DIFFERENT via — admitted (different provenance).
        t.append_alias(AliasEntry {
            name: "rematerialization".to_string(),
            added_at: now,
            via: AliasProvenance::VariantBOutput,
            confidence: Some(0.92),
        });
        assert_eq!(t.aliases.len(), 2);
    }

    #[test]
    fn save_and_load_round_trip_atomic() {
        let dir = tempdir().unwrap();
        let path = AliasTable::path_for(dir.path(), "checkpoint-gradient");
        let mut t = AliasTable::fresh("checkpoint-gradient");
        t.definition = Some("recompute forward to save memory".to_string());
        t.append_alias(AliasEntry {
            name: "rematerialization".to_string(),
            added_at: Utc::now(),
            via: AliasProvenance::UserMerge,
            confidence: None,
        });
        t.save(&path).unwrap();
        // Atomic-write invariant: only the final file should exist; no
        // .tmp.* sibling.
        let entries: Vec<_> = std::fs::read_dir(dir.path())
            .unwrap()
            .filter_map(|e| e.ok())
            .map(|e| e.file_name())
            .collect();
        assert_eq!(entries.len(), 1);

        let loaded = AliasTable::load(&path).unwrap();
        assert_eq!(loaded.canonical_name, "checkpoint-gradient");
        assert_eq!(loaded.definition.as_deref(), Some("recompute forward to save memory"));
        assert_eq!(loaded.aliases.len(), 1);
    }

    #[test]
    fn schema_rejects_invalid_canonical_name_pattern() {
        let bad = serde_json::json!({
            "$schema": ALIAS_V1_ID,
            "canonical_name": "BadCamelCase",
            "aliases": [],
            "schema_version": 1
        });
        assert!(validate_against(ALIAS_SCHEMA, &bad).is_err());
    }

    #[test]
    fn schema_rejects_unknown_via_value() {
        let bad = serde_json::json!({
            "$schema": ALIAS_V1_ID,
            "canonical_name": "x",
            "aliases": [{
                "name": "y",
                "added_at": "2026-04-29T01:00:00Z",
                "via": "fabricated_provenance"
            }],
            "schema_version": 1
        });
        assert!(
            validate_against(ALIAS_SCHEMA, &bad).is_err(),
            "via must be one of the four plan-§3.7 enum values"
        );
    }

    #[test]
    fn schema_rejects_alias_name_over_200_chars() {
        let huge = "x".repeat(201);
        let bad = serde_json::json!({
            "$schema": ALIAS_V1_ID,
            "canonical_name": "x",
            "aliases": [{
                "name": huge,
                "added_at": "2026-04-29T01:00:00Z",
                "via": "user_merge"
            }],
            "schema_version": 1
        });
        assert!(validate_against(ALIAS_SCHEMA, &bad).is_err());
    }

    #[test]
    fn load_rejects_wrong_schema_id() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("bad.alias.json");
        let bad = serde_json::json!({
            "$schema": "epistemos://schemas/wrong.v1.json",
            "canonical_name": "x",
            "aliases": [],
            "schema_version": 1
        });
        std::fs::write(&path, serde_json::to_vec(&bad).unwrap()).unwrap();
        let r = AliasTable::load(&path);
        assert!(r.is_err());
    }

    #[test]
    fn matches_canonicalized_finds_query_via_canonical_name() {
        let t = AliasTable::fresh("checkpoint-gradient");
        // Surface forms of the canonical name itself match.
        assert!(t.matches_canonicalized("Gradient Checkpointing"));
        assert!(t.matches_canonicalized("gradient checkpointing"));
        // Different concept doesn't.
        assert!(!t.matches_canonicalized("attention is all you need"));
    }

    #[test]
    fn path_for_uses_alias_json_suffix() {
        let p = AliasTable::path_for(Path::new("/concepts"), "checkpoint-gradient");
        assert_eq!(p.to_string_lossy(), "/concepts/checkpoint-gradient.alias.json");
    }

    #[test]
    fn provenance_serializes_snake_case() {
        let cases = [
            (AliasProvenance::UserMerge, "user_merge"),
            (AliasProvenance::VariantBOutput, "variant_b_output"),
            (AliasProvenance::ConceptExtract, "concept_extract"),
            (AliasProvenance::ManualSeed, "manual_seed"),
        ];
        for (p, expected) in cases {
            let s = serde_json::to_string(&p).unwrap();
            assert_eq!(s.trim_matches('"'), expected);
        }
    }
}
