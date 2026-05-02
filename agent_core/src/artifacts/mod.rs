//! # `artifacts`
//!
//! Cognitive artifact taxonomy for the Epistemos workspace substrate.
//!
//! Per `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §2-3 and
//! `docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 3.2.
//!
//! This module defines the canonical typed identity for every cognitive
//! artifact in Epistemos:
//!
//!   - [`ArtifactKind`] (`kind.rs`) — the 7-variant kind discriminator.
//!     Mirrored byte-equal to `Epistemos/Models/ArtifactKind.swift`.
//!   - [`ArtifactHeader`] (`header.rs`) — the canonical on-wire header
//!     (id, kind, schema_version, timestamps, title, content hash,
//!     provenance, metadata). Mirrors Swift's `EpdocManifest` at
//!     `Epistemos/Models/EpdocManifest.swift:92`.
//!   - [`Producer`] / [`ArtifactRef`] / [`ProvenanceBlock`]
//!     (`provenance.rs`) — the supporting types embedded in every
//!     header. Mirror Swift's `EpdocProducer` / `EpdocArtifactRef` /
//!     `EpdocProvenance`.
//!
//! Cross-language parity is enforced by:
//!   - `EpistemosTests/ArtifactKindParityTests.swift`
//!     (Wave 3.2 — kind enum)
//!   - `EpistemosTests/ArtifactProvenanceParityTests.swift`
//!     (Wave 3.3 — header + provenance, T+4.2)
//!
//! Kept distinct from:
//!   - `EntityKind` (substrate-core) — slotmap entity discriminator
//!   - `ChatArtifactKind` (Swift `Epistemos/Models/Artifact.swift`) — chat
//!     content block discriminator (json/yaml/csv/code/etc.)
//!   - `GraphNodeType` (Swift `Epistemos/Models/GraphTypes.swift`) — graph
//!     render category (legacy compatibility; `mapsToArtifactKind()`
//!     bridge at `Epistemos/Models/GraphTypes.swift:209`)

pub mod header;
pub mod kind;
pub mod provenance;

pub use header::ArtifactHeader;
pub use kind::ArtifactKind;
pub use provenance::{ArtifactRef, Producer, ProvenanceBlock};
