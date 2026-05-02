//! Provenance metadata for cognitive artifacts.
//!
//! Per `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §3
//! (T+4.2 of `docs/audits/deliberation/T+4_cognitive_artifact_spine_deliberation_20260427.md`).
//!
//! Three types live here:
//!   - [`Producer`] — `Human` | `Agent` | `System`. Who/what authored the artifact.
//!   - [`ArtifactRef`] — opaque pointer to another artifact (id + optional kind + title).
//!   - [`ProvenanceBlock`] — combines them into the "where did this come from" record
//!     embedded in every [`super::ArtifactHeader`].
//!
//! Wire-format mirrors Swift's `EpdocProducer` / `EpdocArtifactRef` /
//! `EpdocProvenance` at `Epistemos/Models/EpdocManifest.swift:18,27,52`. The
//! Swift side carries the `Epdoc` prefix because `.epdoc` was the first
//! consumer; this Rust side uses the canonical taxonomy names. JSON keys
//! are byte-equal in both directions — the parity test in
//! `EpistemosTests/ArtifactProvenanceParityTests.swift` enforces drift.

use serde::{Deserialize, Serialize};

use super::ArtifactKind;

/// Producer of an artifact — who/what created it.
///
/// Mirrors Swift's `EpdocProducer` (`Epistemos/Models/EpdocManifest.swift:18`).
/// Wire format is the lower-snake-case raw value (`"human"`, `"agent"`,
/// `"system"`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Producer {
    /// A human user authored this artifact directly.
    Human,
    /// An agent run produced this artifact (cloud LLM, local LLM, or tool
    /// invocation orchestrated by the agent loop).
    Agent,
    /// The app or runtime created this artifact automatically (e.g. an
    /// imported source, a generated index, a system snapshot).
    System,
}

/// Lightweight reference to another artifact in the workspace. Carries
/// just enough to resolve the target without embedding it.
///
/// Mirrors Swift's `EpdocArtifactRef` (`Epistemos/Models/EpdocManifest.swift:27`).
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ArtifactRef {
    /// Stable artifact id. Treated opaquely at this layer — the resolver
    /// decides whether it's a ULID, UUID v4/v7, or SwiftData URI. Persists
    /// across renames; never reused. Matches Swift's `id: String`.
    pub id: String,

    /// Kind of the referenced artifact. Optional because legacy links may
    /// not have recorded it; readers should tolerate `None` and fall back
    /// to a kind lookup via [`Self::id`].
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub kind: Option<ArtifactKind>,

    /// Human-readable title captured at link time. May be stale relative
    /// to the live artifact title; UI should refresh on render.
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub title: Option<String>,
}

impl ArtifactRef {
    /// Construct a reference with id only — typical for forward-looking
    /// links where kind / title aren't known yet.
    pub fn new<S: Into<String>>(id: S) -> Self {
        Self {
            id: id.into(),
            kind: None,
            title: None,
        }
    }

    /// Construct a fully-populated reference. Use this when a write site
    /// has all three values cached, so readers don't need a second lookup.
    pub fn full<S: Into<String>, T: Into<String>>(id: S, kind: ArtifactKind, title: T) -> Self {
        Self {
            id: id.into(),
            kind: Some(kind),
            title: Some(title.into()),
        }
    }
}

/// Provenance metadata — answers "where did this artifact come from".
///
/// Embedded in every [`super::ArtifactHeader`] so a reader can trace the
/// full lineage without a second lookup. Mirrors Swift's `EpdocProvenance`
/// (`Epistemos/Models/EpdocManifest.swift:52`). All `Vec` fields default to
/// empty so older manifests round-trip cleanly through newer readers.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ProvenanceBlock {
    /// Who or what authored this artifact.
    pub producer: Producer,

    /// Direct ancestors — artifacts the body of this one is derived from
    /// (e.g. a Document derived from a ProseNote, or an Output derived
    /// from a Run).
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub derived_from: Vec<ArtifactRef>,

    /// Run that produced this artifact, when applicable. Matches the
    /// `run_id` in Raw Thoughts `manifest.json`. Optional because not
    /// every artifact comes from an agent run.
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub generated_by_run: Option<String>,

    /// Tool name if the artifact came directly from a tool invocation
    /// (`vault_search`, `web_fetch`, `code_execution`, etc.). Optional.
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub tool_id: Option<String>,

    /// Sources cited / consumed by the producer (a Run's input artifacts,
    /// or a Document's referenced Sources).
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub source_artifacts: Vec<ArtifactRef>,

    /// Outputs this artifact emitted (a Run pointing to the Output it
    /// generated, or a Document pointing to its Code/Source children).
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub output_artifacts: Vec<ArtifactRef>,
}

impl ProvenanceBlock {
    /// Construct a minimal provenance for an artifact whose only known
    /// fact is its producer. Useful for human-authored notes.
    pub fn human() -> Self {
        Self {
            producer: Producer::Human,
            derived_from: Vec::new(),
            generated_by_run: None,
            tool_id: None,
            source_artifacts: Vec::new(),
            output_artifacts: Vec::new(),
        }
    }

    /// Construct a provenance for an agent-produced artifact, with
    /// optional run id and tool id.
    pub fn agent(run_id: Option<String>, tool_id: Option<String>) -> Self {
        Self {
            producer: Producer::Agent,
            derived_from: Vec::new(),
            generated_by_run: run_id,
            tool_id,
            source_artifacts: Vec::new(),
            output_artifacts: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn producer_serde_round_trips_snake_case() {
        for variant in [Producer::Human, Producer::Agent, Producer::System] {
            let json = serde_json::to_string(&variant).expect("serialize Producer");
            let recovered: Producer = serde_json::from_str(&json).expect("deserialize Producer");
            assert_eq!(recovered, variant, "Producer round-trip must be identity");
        }
        // Wire format guard: keys are lower-snake-case so the Swift mirror
        // (`EpdocProducer`'s String raw value) matches byte-for-byte.
        assert_eq!(
            serde_json::to_string(&Producer::Human).unwrap(),
            "\"human\""
        );
        assert_eq!(
            serde_json::to_string(&Producer::Agent).unwrap(),
            "\"agent\""
        );
        assert_eq!(
            serde_json::to_string(&Producer::System).unwrap(),
            "\"system\""
        );
    }

    #[test]
    fn artifact_ref_round_trips() {
        let r = ArtifactRef::full("abc-123", ArtifactKind::Document, "My Doc");
        let json = serde_json::to_string(&r).expect("serialize ArtifactRef");
        let recovered: ArtifactRef = serde_json::from_str(&json).expect("deserialize ArtifactRef");
        assert_eq!(r, recovered);
    }

    #[test]
    fn artifact_ref_skips_none_fields() {
        // Wire-format guard: optional fields are absent when None so older
        // manifests don't carry `null` placeholders.
        let r = ArtifactRef::new("only-id");
        let json = serde_json::to_string(&r).expect("serialize");
        assert_eq!(json, r#"{"id":"only-id"}"#);
    }

    #[test]
    fn provenance_block_human_serializes_compact() {
        // Empty Vec fields skip serialization so a minimal human-authored
        // note's manifest stays small.
        let p = ProvenanceBlock::human();
        let json = serde_json::to_string(&p).expect("serialize");
        assert_eq!(json, r#"{"producer":"human"}"#);
    }

    #[test]
    fn provenance_block_agent_with_run_id() {
        let p = ProvenanceBlock::agent(Some("run-2026-04-27-x".to_string()), None);
        let json = serde_json::to_string(&p).expect("serialize");
        assert_eq!(
            json,
            r#"{"producer":"agent","generated_by_run":"run-2026-04-27-x"}"#
        );
        let recovered: ProvenanceBlock = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(recovered, p);
    }

    #[test]
    fn provenance_block_round_trips_full() {
        let p = ProvenanceBlock {
            producer: Producer::Agent,
            derived_from: vec![ArtifactRef::full("src-1", ArtifactKind::Source, "Paper")],
            generated_by_run: Some("run-99".to_string()),
            tool_id: Some("vault_search".to_string()),
            source_artifacts: vec![ArtifactRef::new("src-2")],
            output_artifacts: vec![ArtifactRef::new("out-1")],
        };
        let json = serde_json::to_string(&p).expect("serialize");
        let recovered: ProvenanceBlock = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(p, recovered);
    }

    #[test]
    fn artifact_ref_kind_optional_default_none() {
        // Backward-compat guard: a ref with only `id` field deserializes
        // with `kind = None` and `title = None` instead of failing.
        let json = r#"{"id":"old-style-id"}"#;
        let r: ArtifactRef = serde_json::from_str(json).expect("deserialize");
        assert_eq!(r.id, "old-style-id");
        assert_eq!(r.kind, None);
        assert_eq!(r.title, None);
    }
}
