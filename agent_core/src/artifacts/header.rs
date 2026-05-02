//! Canonical header for cognitive artifacts.
//!
//! Per `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §3
//! (T+4.2 of `docs/audits/deliberation/T+4_cognitive_artifact_spine_deliberation_20260427.md`).
//!
//! [`ArtifactHeader`] is the on-disk + on-wire shape for every typed
//! artifact's identity and provenance metadata. For `.epdoc` packages it
//! is persisted as `manifest.json`; for SwiftData-backed artifacts it
//! lives as a row in the SwiftData store.
//!
//! Wire format mirrors Swift's `EpdocManifest` at
//! `Epistemos/Models/EpdocManifest.swift:92`. JSON keys are byte-equal in
//! both directions; the parity test in
//! `EpistemosTests/ArtifactProvenanceParityTests.swift` enforces drift.

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

use super::{ArtifactKind, ProvenanceBlock};

/// `manifest.json` — the canonical artifact header.
///
/// Mirrors Swift's `EpdocManifest`. Field order matches Swift's
/// `CodingKeys` so a JSONEncoder-with-sorted-keys round-trip is
/// byte-equal across languages. The `vault_path` from the implementation
/// plan §3 is intentionally NOT included on the wire — it's a runtime
/// resolution and lives on a higher-level wrapper type.
///
/// `metadata` is a `BTreeMap` (sorted) so JSON emission is deterministic
/// regardless of insertion order. Swift's `[String: String]` is unordered
/// at the language level but `JSONEncoder.outputFormatting = .sortedKeys`
/// makes the wire format match.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ArtifactHeader {
    /// Stable artifact id. Persists across renames. Treated opaquely at
    /// this layer — generation strategy (UUID v4 / v7 / ULID) is decided
    /// by the caller in T+4.5 (`.epdoc` package writer) and downstream.
    pub id: String,

    /// Wave 3.2 unified [`ArtifactKind`]. For `.epdoc` packages this is
    /// almost always [`ArtifactKind::Document`], but the field is written
    /// so a future kind reuses the same on-disk shape.
    pub kind: ArtifactKind,

    /// Bumped on every backwards-incompatible manifest schema change.
    /// Readers MUST tolerate higher `schema_version` (forward compat) by
    /// ignoring unknown fields — never by failing to load.
    pub schema_version: u32,

    /// Unix milliseconds. `chrono::Utc::now().timestamp_millis()` gives
    /// the canonical generator value.
    pub created_at: i64,

    /// Unix milliseconds. Update on every save; readers compare against
    /// the file mtime to detect out-of-band edits.
    pub updated_at: i64,

    /// Display title. Stored at the header level so list views can
    /// render without parsing the full content.
    pub title: String,

    /// Hex digest of the canonical content body (`content.pm.json` for
    /// `.epdoc` packages, body markdown for ProseNotes). The hash
    /// algorithm choice (BLAKE3 vs SHA-256) is encoded in the prefix
    /// when needed (e.g. `"blake3:abc..."` or `"sha256:def..."`); a
    /// bare hex string defaults to BLAKE3 per
    /// `docs/audits/deliberation/T+4_cognitive_artifact_spine_deliberation_20260427.md` §E.
    pub content_hash: String,

    /// Provenance — see [`ProvenanceBlock`].
    pub provenance: ProvenanceBlock,

    /// Optional free-form metadata bag — theme name, icon, accent color,
    /// display mode, etc. Older readers tolerate absence; newer readers
    /// can extend the convention without bumping `schema_version`.
    /// Borrowed from Smaug6739/Alexandrie's `nodes.metadata JSON`
    /// pattern (Wave 7.6 follow-up). Sorted via `BTreeMap` so wire-format
    /// is deterministic across writers.
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub metadata: Option<BTreeMap<String, String>>,
}

impl ArtifactHeader {
    /// Current schema version. Bump on every backwards-incompatible
    /// header field change AND simultaneously update the Swift mirror.
    pub const CURRENT_SCHEMA_VERSION: u32 = 1;

    /// Construct a header with the most common defaults. Generates no
    /// id (caller decides) and no metadata; uses
    /// [`Self::CURRENT_SCHEMA_VERSION`].
    pub fn new(
        id: String,
        kind: ArtifactKind,
        title: String,
        content_hash: String,
        provenance: ProvenanceBlock,
        created_at: i64,
        updated_at: i64,
    ) -> Self {
        Self {
            id,
            kind,
            schema_version: Self::CURRENT_SCHEMA_VERSION,
            created_at,
            updated_at,
            title,
            content_hash,
            provenance,
            metadata: None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture() -> ArtifactHeader {
        ArtifactHeader::new(
            "01H8XGJWBWBAQ4N0K9HZ8XGJWB".to_string(),
            ArtifactKind::Document,
            "My Research Report".to_string(),
            "blake3:abcdef0123456789".to_string(),
            ProvenanceBlock::human(),
            1_745_788_800_000,
            1_745_788_800_000,
        )
    }

    #[test]
    fn round_trips_through_json() {
        let h = fixture();
        let json = serde_json::to_string(&h).expect("serialize");
        let recovered: ArtifactHeader = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(h, recovered, "JSON round-trip must be identity");
    }

    #[test]
    fn wire_format_keys_match_swift_coding_keys() {
        // Parity guard: the JSON keys MUST match Swift's CodingKeys at
        // Epistemos/Models/EpdocManifest.swift:152-162. If this test fails,
        // either rename a field on this side or update Swift CodingKeys
        // — never let the wire format drift.
        let h = fixture();
        let value: serde_json::Value = serde_json::to_value(&h).expect("serialize to value");
        let obj = value.as_object().expect("manifest is a JSON object");
        let mut keys: Vec<&str> = obj.keys().map(|s| s.as_str()).collect();
        keys.sort();
        assert_eq!(
            keys,
            vec![
                "content_hash",
                "created_at",
                "id",
                "kind",
                "provenance",
                "schema_version",
                "title",
                "updated_at",
            ],
            "ArtifactHeader JSON keys must match EpdocManifest CodingKeys exactly. \
             Drift means the Swift Codable round-trip will fail."
        );
    }

    #[test]
    fn metadata_is_skipped_when_none() {
        // Older Swift writers don't emit `metadata`; readers MUST
        // tolerate its absence. Skipping when None keeps the wire
        // format compatible.
        let h = fixture();
        let json = serde_json::to_string(&h).expect("serialize");
        assert!(
            !json.contains("\"metadata\""),
            "metadata: None must be omitted from wire format, got: {json}"
        );
    }

    #[test]
    fn metadata_round_trips_when_present() {
        let mut h = fixture();
        let mut m = BTreeMap::new();
        m.insert("theme".to_string(), "midnight".to_string());
        m.insert("accent".to_string(), "#7c3aed".to_string());
        h.metadata = Some(m);

        let json = serde_json::to_string(&h).expect("serialize");
        let recovered: ArtifactHeader = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(h, recovered);
        // BTreeMap guarantees alphabetical key ordering.
        assert!(json.contains(r#""accent":"#));
        assert!(json.contains(r#""theme":"#));
    }

    #[test]
    fn schema_version_constant_matches_swift_mirror() {
        // Pre-cutoff Swift's EpdocManifest.currentSchemaVersion = 1.
        // This constant MUST stay in lock-step. Bump together when adding
        // a backwards-incompatible field.
        assert_eq!(ArtifactHeader::CURRENT_SCHEMA_VERSION, 1);
    }

    #[test]
    fn default_kind_is_not_assumed() {
        // Per the implementation plan, `kind` is mandatory in every
        // header — there's no implicit default. Verify the struct
        // requires it (this is a compile-time guard via `Self::new`'s
        // signature; this test just documents the contract).
        let h = fixture();
        assert_eq!(h.kind, ArtifactKind::Document);
    }
}
