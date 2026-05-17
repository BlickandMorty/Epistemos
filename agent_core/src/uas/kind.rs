//! UasKind — substrate-typed identity tag.
//!
//! Source:
//! - Canonical doctrine `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md`
//!   §5 register row #3 (UasKind).
//! - Phase B blueprint `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md`
//!   §2.1 iter 22.
//! - T-terminal coord `docs/audits/UAS_ACS_T_TERMINAL_COORDINATION_2026_05_17.md`
//!   §2 (initial variant set proposed by T3; T1 review pending before iter 30).
//!
//! # Phase B.G.B1.b — iter 22
//!
//! Expands the iter-21 `Placeholder` stub into the full T3-proposed variant
//! set. T1 review of these variants is pending per coord doc §2.
//!
//! The `Other(String)` escape hatch is the forward-compat anchor so iter-22's
//! variant set can be extended in any later iter without breaking already-
//! serialized `UasAddress` instances; an unknown wire tag deserializes to
//! `Other(unknown_tag)` rather than failing the round trip.

use serde::{Deserialize, Serialize};
use std::borrow::Cow;

/// Substrate-typed identity tag.
///
/// Variant order LOCKed by canonical doctrine §5 register row #3. New variants
/// MUST be added at the end of the enum (before `Other`) to preserve
/// deterministic ordering and discriminant assignment.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UasKind {
    /// Markdown vault note (Halo/Shadow consumer).
    VaultNote,
    /// Cognitive DAG node (`agent_core::cognitive_dag::node`).
    GraphNode,
    /// KV cache page (hot / warm / cold tier per F-KV-Direct-Gate).
    KvPage,
    /// VPD-extracted model component (T7 lane — read-only from T3).
    ModelComponent,
    /// agent_runtime trace event (T2 lane — read-only from T3).
    AgentTrace,
    /// Tool execution result.
    ToolResult,
    /// SCOPE-Rex AnswerPacket emission.
    AnswerPacket,
    /// T1 tri-fusion content-fabric block (T1 to refine).
    TriFusionBlock,
    /// Forward-compat escape hatch. An unknown wire tag deserializes here.
    Other(String),
}

impl UasKind {
    /// Stable wire-format tag for inclusion in `UasAddress::Display`.
    ///
    /// Returns `Cow<'static, str>` so known variants return a static string
    /// without allocation; `Other(s)` returns the contained string borrowed.
    pub fn wire_tag(&self) -> Cow<'_, str> {
        match self {
            UasKind::VaultNote => Cow::Borrowed("vault_note"),
            UasKind::GraphNode => Cow::Borrowed("graph_node"),
            UasKind::KvPage => Cow::Borrowed("kv_page"),
            UasKind::ModelComponent => Cow::Borrowed("model_component"),
            UasKind::AgentTrace => Cow::Borrowed("agent_trace"),
            UasKind::ToolResult => Cow::Borrowed("tool_result"),
            UasKind::AnswerPacket => Cow::Borrowed("answer_packet"),
            UasKind::TriFusionBlock => Cow::Borrowed("tri_fusion_block"),
            UasKind::Other(s) => Cow::Borrowed(s.as_str()),
        }
    }

    /// Inverse of `wire_tag`. Returns the matching known variant if the tag
    /// is recognized; falls back to `Other(tag.to_string())` for unknown tags.
    ///
    /// This makes `from_wire_tag` total — every input produces a UasKind. The
    /// caller can detect "unknown" cases by inspecting `matches!(_, Other(_))`.
    pub fn from_wire_tag(tag: &str) -> Self {
        match tag {
            "vault_note" => UasKind::VaultNote,
            "graph_node" => UasKind::GraphNode,
            "kv_page" => UasKind::KvPage,
            "model_component" => UasKind::ModelComponent,
            "agent_trace" => UasKind::AgentTrace,
            "tool_result" => UasKind::ToolResult,
            "answer_packet" => UasKind::AnswerPacket,
            "tri_fusion_block" => UasKind::TriFusionBlock,
            unknown => UasKind::Other(unknown.to_string()),
        }
    }

    /// Returns `true` if this variant is one of the known (non-`Other`) tags.
    pub fn is_known(&self) -> bool {
        !matches!(self, UasKind::Other(_))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// All eight known wire tags must round-trip without landing in `Other`.
    #[test]
    fn known_variants_round_trip_through_wire_tag() {
        let known = [
            UasKind::VaultNote,
            UasKind::GraphNode,
            UasKind::KvPage,
            UasKind::ModelComponent,
            UasKind::AgentTrace,
            UasKind::ToolResult,
            UasKind::AnswerPacket,
            UasKind::TriFusionBlock,
        ];
        for variant in &known {
            let tag = variant.wire_tag();
            let parsed = UasKind::from_wire_tag(&tag);
            assert_eq!(*variant, parsed, "wire-tag round-trip failed for {:?}", variant);
            assert!(variant.is_known());
        }
    }

    #[test]
    fn unknown_wire_tag_falls_back_to_other() {
        let parsed = UasKind::from_wire_tag("future_variant_not_yet_landed");
        assert_eq!(parsed, UasKind::Other("future_variant_not_yet_landed".to_string()));
        assert!(!parsed.is_known());
    }

    #[test]
    fn other_variant_round_trips() {
        let other = UasKind::Other("custom_x".to_string());
        let tag = other.wire_tag();
        assert_eq!(tag.as_ref(), "custom_x");
        let parsed = UasKind::from_wire_tag(&tag);
        assert_eq!(other, parsed);
    }

    #[test]
    fn other_tag_collides_with_known_resolves_to_known() {
        // Forward-compat behavior: if Other is stored with a tag that matches a
        // known variant, round-trip migrates to the known variant. This is
        // intentional — the canonical form for "vault_note" is VaultNote.
        let other_with_known_tag = UasKind::Other("vault_note".to_string());
        let tag = other_with_known_tag.wire_tag();
        let parsed = UasKind::from_wire_tag(&tag);
        assert_eq!(parsed, UasKind::VaultNote);
        // Note: this means `other_with_known_tag != parsed` — intentional.
    }

    #[test]
    fn serde_round_trip_known_variant() {
        let variant = UasKind::VaultNote;
        let json = serde_json::to_string(&variant).expect("serialize must succeed");
        let parsed: UasKind = serde_json::from_str(&json).expect("deserialize must succeed");
        assert_eq!(variant, parsed);
    }

    #[test]
    fn serde_round_trip_other_variant() {
        let variant = UasKind::Other("future_x".to_string());
        let json = serde_json::to_string(&variant).expect("serialize must succeed");
        let parsed: UasKind = serde_json::from_str(&json).expect("deserialize must succeed");
        assert_eq!(variant, parsed);
    }
}
