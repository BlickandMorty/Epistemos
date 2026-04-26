//! # `artifacts`
//!
//! Cognitive artifact taxonomy for the Epistemos workspace substrate.
//!
//! Per `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §2 and
//! `docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 3.2.
//!
//! `ArtifactKind` is the canonical "what is this thing" enum shared across
//! Rust + Swift via byte-equal raw values. The Swift mirror lives at
//! `Epistemos/Models/ArtifactKind.swift` and a source-guard test
//! (`EpistemosTests/ArtifactKindParityTests.swift`) asserts both sides
//! ship the same variants in the same order with the same numeric ids.
//!
//! Kept distinct from:
//!   - `EntityKind` (substrate-core) — slotmap entity discriminator
//!   - `ChatArtifactKind` (Swift `Epistemos/Models/Artifact.swift`) — chat
//!     content block discriminator (json/yaml/csv/code/etc.)
//!   - `GraphNodeType` (Swift `Epistemos/Models/GraphTypes.swift`) — graph
//!     render category (legacy compatibility)

pub mod kind;

pub use kind::ArtifactKind;
