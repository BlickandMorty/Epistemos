//! DAG edges — typed, Merkle-signed.
//!
//! Per `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §1.2.
//!
//! Every edge is Merkle-signed under the capability that issued it.
//! `EdgeSignature` binds `(from, to, kind)` so an edge can't be silently
//! re-attributed. This is the foundation of provenance verifiability:
//! the Sovereign Gate session that issued a capability is recoverable
//! by walking from the edge through the `AuthorizedBy` edge type.
//!
//! Phase 8.A scope: typed schema + content-hashed signature with a
//! caller-supplied capability hash. Phase 8.C will add the Macaroon
//! capability layer that produces real cryptographic signatures; until
//! then `EdgeSignature::compute` is a deterministic content-hash that
//! lets tests pin the signing contract without requiring the real key
//! material.

use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use super::node::{Hash, NodeId, Timestamp};

// ── EdgeKind enum (doctrine §1.2, 10 variants) ──────────────────────────────

/// The 10 canonical edge kinds from doctrine §1.2. Each variant
/// constrains the `from`/`to` node-kind pair in production usage; the
/// schema doesn't enforce that today (would require introspecting the
/// node store at insert time) — the linter that lands in Phase 8.G
/// will catch type-mismatches at PR time.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "edge_kind", rename_all = "snake_case")]
pub enum EdgeKind {
    /// Claim → Evidence
    DerivesFrom { strength: f32 },
    /// Claim → Claim
    Contradicts { tension: f32 },
    /// Skill → Tool / Skill
    Invokes { order: u32, args_template: String },
    /// Event → Capability
    WitnessedBy {},
    /// Capability → SovereignSession
    AuthorizedBy {},
    /// Procedure → Event
    RecordedBy { step: u32 },
    /// Companion → Procedure / Skill
    OwnedBy {},
    /// Companion → Model
    Deforms {
        lora_path: PathBuf,
        weight_alpha: f32,
    },
    /// MemoryTier → Node
    Caches { tier: MemoryTier, score: f32 },
    /// any → Note
    AnnotatedBy { kind: AnnotationKind },
}

impl EdgeKind {
    pub fn discriminator(&self) -> &'static str {
        match self {
            EdgeKind::DerivesFrom { .. } => "derives_from",
            EdgeKind::Contradicts { .. } => "contradicts",
            EdgeKind::Invokes { .. } => "invokes",
            EdgeKind::WitnessedBy {} => "witnessed_by",
            EdgeKind::AuthorizedBy {} => "authorized_by",
            EdgeKind::RecordedBy { .. } => "recorded_by",
            EdgeKind::OwnedBy {} => "owned_by",
            EdgeKind::Deforms { .. } => "deforms",
            EdgeKind::Caches { .. } => "caches",
            EdgeKind::AnnotatedBy { .. } => "annotated_by",
        }
    }
}

/// Selector for `DagStore::edges_from` / `edges_to` filtering. Lighter
/// than `EdgeKind` because it doesn't need the variant payload.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EdgeKindSelector {
    DerivesFrom,
    Contradicts,
    Invokes,
    WitnessedBy,
    AuthorizedBy,
    RecordedBy,
    OwnedBy,
    Deforms,
    Caches,
    AnnotatedBy,
}

impl EdgeKindSelector {
    pub fn matches(&self, kind: &EdgeKind) -> bool {
        matches!(
            (self, kind),
            (EdgeKindSelector::DerivesFrom, EdgeKind::DerivesFrom { .. })
                | (EdgeKindSelector::Contradicts, EdgeKind::Contradicts { .. })
                | (EdgeKindSelector::Invokes, EdgeKind::Invokes { .. })
                | (EdgeKindSelector::WitnessedBy, EdgeKind::WitnessedBy {})
                | (EdgeKindSelector::AuthorizedBy, EdgeKind::AuthorizedBy {})
                | (EdgeKindSelector::RecordedBy, EdgeKind::RecordedBy { .. })
                | (EdgeKindSelector::OwnedBy, EdgeKind::OwnedBy {})
                | (EdgeKindSelector::Deforms, EdgeKind::Deforms { .. })
                | (EdgeKindSelector::Caches, EdgeKind::Caches { .. })
                | (EdgeKindSelector::AnnotatedBy, EdgeKind::AnnotatedBy { .. })
        )
    }
}

// ── Memory tier (used by Caches edge) ──────────────────────────────────────

/// L0 (exact-hot) through L_SE (self-evolving) per doctrine §2.8.
/// Compact ordering: lower numeric → hotter / closer to the model's
/// active context.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MemoryTier {
    /// L0: exact-hot, in-context this turn
    Hot,
    /// L1: warm cache, recently-touched
    Warm,
    /// L2: cool, available via fast retrieval
    Cool,
    /// L3: cold, full vault scan
    Cold,
    /// L_SE: self-evolving — promoted/demoted by NightBrain analysis
    SelfEvolving,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AnnotationKind {
    Comment,
    Citation,
    Correction,
    Tag,
    Highlight,
}

// ── EdgeSignature ──────────────────────────────────────────────────────────

/// Phase 8.A signature: deterministic BLAKE3 over `(from, to, kind,
/// capability_hash)`. Phase 8.C swaps in the real Macaroon-style
/// capability signing; the trait surface here doesn't change so call
/// sites stay stable.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct EdgeSignature([u8; 32]);

impl EdgeSignature {
    /// Compute the canonical Phase 8.A signature. Pure function of
    /// inputs; same `(from, to, kind, capability_hash)` always produces
    /// the same signature. `capability_hash` is the BLAKE3 of the
    /// capability node that issued the edge — Phase 8.C tightens this
    /// to a real signed token.
    pub fn compute(from: &NodeId, to: &NodeId, kind: &EdgeKind, capability_hash: &Hash) -> Self {
        let mut hasher = blake3::Hasher::new();
        hasher.update(from.as_bytes());
        hasher.update(to.as_bytes());
        let kind_canonical = serde_json::to_string(kind).expect("serializable kind");
        hasher.update(kind_canonical.as_bytes());
        hasher.update(capability_hash.as_bytes());
        Self(*hasher.finalize().as_bytes())
    }

    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    /// Verify a signature against the same inputs. Phase 8.A: this is
    /// just recomputing + comparing. Phase 8.C: this validates the
    /// real Macaroon proof.
    pub fn verify(
        &self,
        from: &NodeId,
        to: &NodeId,
        kind: &EdgeKind,
        capability_hash: &Hash,
    ) -> bool {
        let recomputed = Self::compute(from, to, kind, capability_hash);
        // constant-time compare to avoid timing side-channels even on
        // the deterministic Phase 8.A path; future-proofs the contract.
        constant_time_eq(self.as_bytes(), recomputed.as_bytes())
    }
}

// ── Edge struct ─────────────────────────────────────────────────────────────

/// `EdgeId` is the BLAKE3 over `(from, to, kind)` — content-addressed
/// like nodes. This makes edges deduplicate naturally: inserting the
/// same edge twice is a no-op at the storage layer.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct EdgeId([u8; 32]);

impl EdgeId {
    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    /// Content-address an edge from its `(from, to, kind)` triple.
    /// `created_at` and `signature` are NOT part of identity — same
    /// triple means same edge id; the signature attests provenance,
    /// not identity.
    pub fn compute(from: &NodeId, to: &NodeId, kind: &EdgeKind) -> Self {
        let mut hasher = blake3::Hasher::new();
        hasher.update(from.as_bytes());
        hasher.update(to.as_bytes());
        let kind_canonical = serde_json::to_string(kind).expect("serializable kind");
        hasher.update(kind_canonical.as_bytes());
        Self(*hasher.finalize().as_bytes())
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Edge {
    pub from: NodeId,
    pub to: NodeId,
    pub kind: EdgeKind,
    pub created_at: Timestamp,
    pub signature: EdgeSignature,
}

impl Edge {
    /// Construct + sign an edge. `capability_hash` identifies the
    /// capability that issued it; in Phase 8.A this is a content
    /// hash, in Phase 8.C this becomes a real Macaroon root.
    pub fn new(from: NodeId, to: NodeId, kind: EdgeKind, capability_hash: Hash) -> Self {
        let signature = EdgeSignature::compute(&from, &to, &kind, &capability_hash);
        Self {
            from,
            to,
            kind,
            created_at: Timestamp::now(),
            signature,
        }
    }

    pub fn new_at(
        from: NodeId,
        to: NodeId,
        kind: EdgeKind,
        capability_hash: Hash,
        created_at: Timestamp,
    ) -> Self {
        let signature = EdgeSignature::compute(&from, &to, &kind, &capability_hash);
        Self {
            from,
            to,
            kind,
            created_at,
            signature,
        }
    }

    pub fn id(&self) -> EdgeId {
        EdgeId::compute(&self.from, &self.to, &self.kind)
    }

    /// Verify the signature against a capability hash. Returns true
    /// iff the edge was signed under the same capability.
    pub fn verify_signature(&self, capability_hash: &Hash) -> bool {
        self.signature
            .verify(&self.from, &self.to, &self.kind, capability_hash)
    }
}

// ── constant-time equality (avoid pulling in a crypto crate just for this) ─

fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut acc = 0u8;
    for (x, y) in a.iter().zip(b.iter()) {
        acc |= x ^ y;
    }
    acc == 0
}

#[cfg(test)]
mod tests {
    use super::super::node::{ClaimScope, Node, NodeKind, SourceRef};
    use super::*;

    fn dummy_node_id(seed: u8) -> NodeId {
        NodeId::from_bytes([seed; 32])
    }

    fn dummy_capability_hash(seed: u8) -> Hash {
        Hash::from_bytes([seed; 32])
    }

    #[test]
    fn edge_signature_is_deterministic() {
        let from = dummy_node_id(1);
        let to = dummy_node_id(2);
        let kind = EdgeKind::DerivesFrom { strength: 0.8 };
        let cap = dummy_capability_hash(99);
        let s1 = EdgeSignature::compute(&from, &to, &kind, &cap);
        let s2 = EdgeSignature::compute(&from, &to, &kind, &cap);
        assert_eq!(s1, s2);
    }

    #[test]
    fn edge_signature_changes_when_any_input_changes() {
        let from = dummy_node_id(1);
        let to = dummy_node_id(2);
        let kind = EdgeKind::DerivesFrom { strength: 0.8 };
        let cap = dummy_capability_hash(99);
        let baseline = EdgeSignature::compute(&from, &to, &kind, &cap);

        let from2 = dummy_node_id(3);
        assert_ne!(EdgeSignature::compute(&from2, &to, &kind, &cap), baseline);

        let to2 = dummy_node_id(4);
        assert_ne!(EdgeSignature::compute(&from, &to2, &kind, &cap), baseline);

        let kind2 = EdgeKind::DerivesFrom { strength: 0.5 };
        assert_ne!(EdgeSignature::compute(&from, &to, &kind2, &cap), baseline);

        let cap2 = dummy_capability_hash(100);
        assert_ne!(EdgeSignature::compute(&from, &to, &kind, &cap2), baseline);
    }

    #[test]
    fn edge_id_is_independent_of_signature_and_timestamp() {
        let from = dummy_node_id(1);
        let to = dummy_node_id(2);
        let kind = EdgeKind::Invokes {
            order: 0,
            args_template: "{}".into(),
        };
        let cap_a = dummy_capability_hash(10);
        let cap_b = dummy_capability_hash(20);
        let edge_a = Edge::new_at(from, to, kind.clone(), cap_a, Timestamp(100));
        let edge_b = Edge::new_at(from, to, kind, cap_b, Timestamp(200));
        // Same (from, to, kind) → same EdgeId regardless of cap or time
        assert_eq!(edge_a.id(), edge_b.id());
        // But signatures differ because capability differs
        assert_ne!(edge_a.signature, edge_b.signature);
    }

    #[test]
    fn verify_signature_round_trips() {
        let from = dummy_node_id(1);
        let to = dummy_node_id(2);
        let kind = EdgeKind::WitnessedBy {};
        let cap = dummy_capability_hash(42);
        let edge = Edge::new(from, to, kind, cap);
        assert!(edge.verify_signature(&cap));
    }

    #[test]
    fn verify_signature_fails_with_wrong_capability() {
        let from = dummy_node_id(1);
        let to = dummy_node_id(2);
        let kind = EdgeKind::WitnessedBy {};
        let cap = dummy_capability_hash(42);
        let edge = Edge::new(from, to, kind, cap);
        let wrong_cap = dummy_capability_hash(43);
        assert!(!edge.verify_signature(&wrong_cap));
    }

    #[test]
    fn edge_kind_discriminator_covers_all_10_variants() {
        let variants = [
            EdgeKind::DerivesFrom { strength: 0.0 },
            EdgeKind::Contradicts { tension: 0.0 },
            EdgeKind::Invokes {
                order: 0,
                args_template: "".into(),
            },
            EdgeKind::WitnessedBy {},
            EdgeKind::AuthorizedBy {},
            EdgeKind::RecordedBy { step: 0 },
            EdgeKind::OwnedBy {},
            EdgeKind::Deforms {
                lora_path: PathBuf::new(),
                weight_alpha: 0.0,
            },
            EdgeKind::Caches {
                tier: MemoryTier::Hot,
                score: 0.0,
            },
            EdgeKind::AnnotatedBy {
                kind: AnnotationKind::Comment,
            },
        ];
        let mut seen = std::collections::BTreeSet::new();
        for v in &variants {
            assert!(
                seen.insert(v.discriminator()),
                "duplicate: {}",
                v.discriminator()
            );
        }
        assert_eq!(seen.len(), 10, "doctrine §1.2 names exactly 10 edge kinds");
    }

    #[test]
    fn edge_kind_selector_matches_correct_kind() {
        assert!(EdgeKindSelector::DerivesFrom.matches(&EdgeKind::DerivesFrom { strength: 0.5 }));
        assert!(!EdgeKindSelector::DerivesFrom.matches(&EdgeKind::Contradicts { tension: 0.5 }));
        assert!(EdgeKindSelector::Invokes.matches(&EdgeKind::Invokes {
            order: 0,
            args_template: "".into()
        }));
    }

    #[test]
    fn edge_round_trips_through_canonical_json() {
        let claim_a = Node::new(NodeKind::Claim {
            proposition: "A".into(),
            scope: ClaimScope::Vault,
            source: SourceRef("u".into()),
        });
        let claim_b = Node::new(NodeKind::Claim {
            proposition: "B".into(),
            scope: ClaimScope::Vault,
            source: SourceRef("u".into()),
        });
        let cap = dummy_capability_hash(7);
        let edge = Edge::new(
            claim_a.id,
            claim_b.id,
            EdgeKind::Contradicts { tension: 0.9 },
            cap,
        );
        let encoded = serde_json::to_string(&edge).unwrap();
        let decoded: Edge = serde_json::from_str(&encoded).unwrap();
        assert_eq!(edge, decoded);
        assert!(decoded.verify_signature(&cap));
    }

    #[test]
    fn memory_tier_ordering_reflects_doctrine() {
        // Doctrine §2.8: lower numeric = hotter
        assert!(MemoryTier::Hot < MemoryTier::Warm);
        assert!(MemoryTier::Warm < MemoryTier::Cool);
        assert!(MemoryTier::Cool < MemoryTier::Cold);
        assert!(MemoryTier::Cold < MemoryTier::SelfEvolving);
    }

    #[test]
    fn constant_time_eq_handles_length_mismatch() {
        assert!(!constant_time_eq(b"abc", b"abcd"));
        assert!(constant_time_eq(b"abc", b"abc"));
        assert!(!constant_time_eq(b"abc", b"abd"));
    }

    #[test]
    fn edge_id_is_deterministic_across_constructions() {
        let from = dummy_node_id(1);
        let to = dummy_node_id(2);
        let kind = EdgeKind::Invokes {
            order: 5,
            args_template: "{x}".into(),
        };
        let id_a = EdgeId::compute(&from, &to, &kind);
        let id_b = EdgeId::compute(&from, &to, &kind);
        assert_eq!(id_a, id_b);
    }
}
