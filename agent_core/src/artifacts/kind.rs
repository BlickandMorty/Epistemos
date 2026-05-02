//! Unified `ArtifactKind` taxonomy.
//!
//! Per `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §2 and
//! `docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 3.2.
//!
//! Every cognitive artifact in the Epistemos workspace carries one
//! `ArtifactKind` value. The numeric ids are CONTRACTS — they are
//! mirrored byte-equal to the Swift enum at `Epistemos/Models/ArtifactKind.swift`
//! (`EpistemosTests/ArtifactKindParityTests.swift` enforces parity).
//!
//! Adding a new variant is a 4-step ritual:
//!   1. Add the variant + numeric id here, in declaration order.
//!   2. Append the matching variant to the Swift enum with the same id.
//!   3. Update `ArtifactKindParityTests` (canonicalVariants list).
//!   4. Document the variant's intent here (one-line `///` per variant).
//!
//! Skipping any of those steps fails the parity test on the next CI run.

use serde::{Deserialize, Serialize};

/// The canonical kind discriminator for cognitive artifacts.
///
/// `repr(u8)` so the wire format is stable and compact. `serde` uses
/// `snake_case` rename so JSON shows `"prose_note"` instead of `"ProseNote"`
/// — matches the Swift mirror's `String, RawValue == "prose_note"`.
#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ArtifactKind {
    /// Canonical user note — ProseMirror JSON document persisted as
    /// `SDPage` + vault `.md` file. The default kind for hand-authored
    /// rich text in the Notes surface.
    ProseNote = 1,

    /// Rich `.epdoc` package — ProseMirror canonical + projections + assets.
    /// Used for long-form documents, research reports, importable Word/PDF.
    Document = 2,

    /// One thinking-block sequence inside an agent run. Captures
    /// thinking_delta + signature_delta pairs (see Raw Thoughts V0).
    RawThought = 3,

    /// External reference — web page, PDF, book, paper. Source material
    /// the user is drawing from but did not author.
    Source = 4,

    /// Source code file. May carry syntax-core highlighting metadata when
    /// the inspector displays it.
    Code = 5,

    /// One agent execution span — parent of its RawThought + tool trace
    /// children (see Raw Thoughts V0 `manifest.json` + `final.json`).
    Run = 6,

    /// Captured terminal / REPL / build output. The text the user wants
    /// to remember from a tool execution, separable from the tool's
    /// invocation record.
    Output = 7,
}

impl ArtifactKind {
    /// Stable lower_snake_case identifier — matches the serde rename and
    /// the Swift `rawValue`. Use this when persisting to disk or wire
    /// formats outside of the canonical serde path.
    pub const fn as_str(self) -> &'static str {
        match self {
            ArtifactKind::ProseNote => "prose_note",
            ArtifactKind::Document => "document",
            ArtifactKind::RawThought => "raw_thought",
            ArtifactKind::Source => "source",
            ArtifactKind::Code => "code",
            ArtifactKind::Run => "run",
            ArtifactKind::Output => "output",
        }
    }

    /// Numeric id — matches the `repr(u8)` discriminant and the Swift
    /// `RawValue == UInt8` mirror. Stable across versions; never reused.
    pub const fn id(self) -> u8 {
        self as u8
    }

    /// All variants in declaration order. The parity test reads this
    /// slice to confirm the Swift mirror covers every Rust variant.
    pub const ALL: &'static [ArtifactKind] = &[
        ArtifactKind::ProseNote,
        ArtifactKind::Document,
        ArtifactKind::RawThought,
        ArtifactKind::Source,
        ArtifactKind::Code,
        ArtifactKind::Run,
        ArtifactKind::Output,
    ];

    /// Round-trip a numeric id back into a typed kind. Returns `None`
    /// for unknown ids — callers MUST handle the option (do not panic
    /// on an old vault that contains a kind id this binary doesn't yet
    /// understand).
    pub const fn from_id(id: u8) -> Option<ArtifactKind> {
        match id {
            1 => Some(ArtifactKind::ProseNote),
            2 => Some(ArtifactKind::Document),
            3 => Some(ArtifactKind::RawThought),
            4 => Some(ArtifactKind::Source),
            5 => Some(ArtifactKind::Code),
            6 => Some(ArtifactKind::Run),
            7 => Some(ArtifactKind::Output),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn id_round_trips() {
        for variant in ArtifactKind::ALL {
            let id = variant.id();
            let recovered = ArtifactKind::from_id(id)
                .unwrap_or_else(|| panic!("from_id({id}) returned None for variant {variant:?}"));
            assert_eq!(*variant, recovered, "id round-trip must be identity");
        }
    }

    #[test]
    fn ids_are_dense_and_one_indexed() {
        // Sprint 1 contract: ids are 1..=N with no gaps, so a Swift
        // `RawValue: UInt8, CaseIterable` mirror can rely on linear
        // iteration. Keeps the parity test's range check trivial.
        for (offset, variant) in ArtifactKind::ALL.iter().enumerate() {
            assert_eq!(
                variant.id() as usize,
                offset + 1,
                "ids must be dense starting at 1 — variant {variant:?} should have id {}",
                offset + 1
            );
        }
    }

    #[test]
    fn as_str_matches_serde_rename() {
        // Wire format guard: `snake_case` rename + `as_str()` constants
        // MUST agree, otherwise on-disk JSON drifts from in-memory
        // string-id usage in helper code.
        for variant in ArtifactKind::ALL {
            let json = serde_json::to_string(variant).unwrap();
            // JSON wraps the string in quotes — strip them.
            let trimmed = json.trim_matches('"');
            assert_eq!(
                trimmed,
                variant.as_str(),
                "serde rename and as_str() must agree for {variant:?}"
            );
        }
    }

    #[test]
    fn from_id_rejects_unknown() {
        assert!(ArtifactKind::from_id(0).is_none());
        assert!(ArtifactKind::from_id(255).is_none());
        assert!(
            ArtifactKind::from_id(8).is_none(),
            "8 is currently unused — when adding a new variant, update this assertion AND the Swift mirror"
        );
    }
}
