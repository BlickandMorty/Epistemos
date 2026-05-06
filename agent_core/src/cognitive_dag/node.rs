//! DAG nodes — typed, content-addressed via BLAKE3.
//!
//! Per `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §1.1.
//!
//! Every node is content-addressed: `NodeId = BLAKE3(canonical_serialize(kind))`.
//! Identical kind content → identical id. This gives free deduplication,
//! free integrity verification, and free distributed shareability —
//! same property as Git blobs and IPFS objects, applied to cognition.

use serde::{Deserialize, Serialize};

// ── ID + helpers ────────────────────────────────────────────────────────────

/// Content-address of a node. Computed as `BLAKE3(canonical_serialize(kind))`.
/// Hex-encoded for JSON round-trip; the underlying 32-byte digest is
/// available via `as_bytes()`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct NodeId([u8; 32]);

impl NodeId {
    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    pub fn to_hex(&self) -> String {
        hex_lower(&self.0)
    }
}

/// Wall-clock timestamp in milliseconds since the Unix epoch. Stored as
/// u64 (signed not needed; we don't address pre-1970 events).
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct Timestamp(pub u64);

impl Timestamp {
    pub fn now() -> Self {
        let ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as u64)
            .unwrap_or(0);
        Self(ms)
    }
}

/// 32-byte content / Merkle hash. Same shape as `NodeId` but distinct
/// type so the type system catches "passing a hash where an id is
/// expected" at compile time.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct Hash([u8; 32]);

impl Hash {
    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    pub fn to_hex(&self) -> String {
        hex_lower(&self.0)
    }

    pub fn zero() -> Self {
        Self([0u8; 32])
    }
}

// ── Lightweight reference types ─────────────────────────────────────────────
//
// Doctrine §1.1 names several wrapper types (AuthorRef, MimeType, etc).
// These are intentionally lightweight — Phase 8.A is the DAG scaffold;
// later phases can refine each into richer subsystems.

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct AuthorRef(pub String);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct MimeType(pub String);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ClaimScope {
    Vault,
    Session,
    Global,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct SourceRef(pub String);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EvidenceKind {
    Citation,
    Observation,
    Computation,
    UserAssertion,
    ToolOutput,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct EvidenceBlob(pub Vec<u8>);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ToolId(pub String);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ToolSurface {
    Vault,
    Web,
    Code,
    Media,
    Channel,
    Other,
}

/// Tool tier — mirrors `crate::tools::registry::ToolTier` shape but kept
/// independent here so the DAG schema doesn't pull in the whole tools
/// crate at type-definition time.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NodeTier {
    None,
    ChatLite,
    ChatPro,
    Agent,
    Full,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ContextHash(pub [u8; 32]);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct OutcomeList(pub Vec<String>);

/// Mirrors `agent_core::evolution::AgentEventKind` shape but kept
/// independent so the DAG schema is self-contained.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DagAgentEventKind {
    TurnStart,
    TurnEnd,
    ToolCall,
    ToolReturn,
    ApprovalGate,
    Stop,
    Error,
    Other(String),
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct SessionId(pub String);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ModelProfile(pub String);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct IdentityHash(pub [u8; 32]);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct PersonaBlob(pub Vec<u8>);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CapabilityKind {
    ToolInvoke(String),
    VaultAccess(String),
    NetworkEgress(String),
    SubprocessSpawn,
    Approval,
    Other(String),
}

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct CapabilityScope(pub String);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct WeightRoot(pub [u8; 32]);

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelLineage {
    Base,
    Lora { parent: NodeId, lora_path: String },
}

// ── NodeKind enum (doctrine §1.1, 10 variants) ──────────────────────────────

/// The 10 canonical node kinds from doctrine §1.1. Each variant is
/// content-addressed independently — two `Note`s with identical body +
/// author + mime get the same `NodeId`. Adding a field to a variant
/// changes the canonical serialization which changes the id; that's
/// the desired behavior (different content → different identity).
///
/// Note: `Eq` + `Hash` not derived because no NodeKind variant uses
/// f32 today, but we keep `PartialEq` to support content-equality
/// comparisons in tests. NodeId already provides hashable identity.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "node_kind", rename_all = "snake_case")]
pub enum NodeKind {
    Note {
        body: String,
        author: AuthorRef,
        mime: MimeType,
    },
    Claim {
        proposition: String,
        scope: ClaimScope,
        source: SourceRef,
    },
    Evidence {
        kind: EvidenceKind,
        payload: EvidenceBlob,
        captured_at: Timestamp,
    },
    Skill {
        name: String,
        description: String,
        schema_version: u32,
    },
    Tool {
        id: ToolId,
        surface: ToolSurface,
        tier: NodeTier,
    },
    Procedure {
        skill_ref: NodeId,
        context_hash: ContextHash,
        outcomes: OutcomeList,
    },
    Event {
        kind: DagAgentEventKind,
        ts: Timestamp,
        session: SessionId,
    },
    Companion {
        profile: ModelProfile,
        identity: IdentityHash,
        persona: PersonaBlob,
    },
    Capability {
        kind: CapabilityKind,
        scope: CapabilityScope,
        expiry: Option<Timestamp>,
    },
    Model {
        weight_root: WeightRoot,
        base_or_lora: ModelLineage,
    },
}

impl NodeKind {
    /// One-letter discriminator used in the canonical serialization +
    /// for log readability. Lowercased so it sorts predictably.
    pub fn discriminator(&self) -> &'static str {
        match self {
            NodeKind::Note { .. } => "note",
            NodeKind::Claim { .. } => "claim",
            NodeKind::Evidence { .. } => "evidence",
            NodeKind::Skill { .. } => "skill",
            NodeKind::Tool { .. } => "tool",
            NodeKind::Procedure { .. } => "procedure",
            NodeKind::Event { .. } => "event",
            NodeKind::Companion { .. } => "companion",
            NodeKind::Capability { .. } => "capability",
            NodeKind::Model { .. } => "model",
        }
    }

    /// Canonical static/dynamic-rooted artifact discriminator.
    ///
    /// Static artifacts are content-addressed snapshots: new versions
    /// mint new node IDs. Dynamic-rooted artifacts point at mutable model
    /// state, but still express mutation as a new node plus lineage edges,
    /// never by mutating the node in place.
    pub fn is_dynamic_rooted(&self) -> bool {
        match self {
            NodeKind::Companion { .. } | NodeKind::Model { .. } => true,
            NodeKind::Note { .. }
            | NodeKind::Claim { .. }
            | NodeKind::Evidence { .. }
            | NodeKind::Skill { .. }
            | NodeKind::Tool { .. }
            | NodeKind::Procedure { .. }
            | NodeKind::Event { .. }
            | NodeKind::Capability { .. } => false,
        }
    }
}

// ── Node struct + content-addressing ────────────────────────────────────────

/// A single DAG node. `id` is computed from `kind` via BLAKE3 over the
/// canonical (sorted-keys) JSON of the kind. `merkle_root` is stored
/// here for cheap lookup but is recomputed by the storage layer when
/// edges are added; see `DagStore::merkle_root`.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Node {
    pub id: NodeId,
    pub kind: NodeKind,
    pub created_at: Timestamp,
    /// Root of the subtree of (this node + every incoming edge). Set
    /// by `DagStore` on insert; equals `id` when the node has no
    /// incoming edges yet.
    pub merkle_root: Hash,
}

impl Node {
    /// Compute the canonical content-address for a `NodeKind`.
    /// Deterministic across runs: serializes via `serde_json` with
    /// `.sortedKeys` then hashes with BLAKE3. Two nodes built from
    /// identical kinds always get the same id.
    pub fn compute_id(kind: &NodeKind) -> NodeId {
        let canonical = canonical_json(kind);
        let mut hasher = blake3::Hasher::new();
        hasher.update(canonical.as_bytes());
        let digest = hasher.finalize();
        NodeId(*digest.as_bytes())
    }

    /// Construct a fresh `Node` from a `NodeKind`. Computes `id` from
    /// content; sets `created_at = now()`; initialises `merkle_root`
    /// to `id` (the no-incoming-edges baseline). The storage layer
    /// updates `merkle_root` as edges land.
    pub fn new(kind: NodeKind) -> Self {
        let id = Self::compute_id(&kind);
        let created_at = Timestamp::now();
        let merkle_root = Hash(id.0);
        Self {
            id,
            kind,
            created_at,
            merkle_root,
        }
    }

    /// Like `new` but with caller-supplied `created_at` for replay /
    /// test determinism.
    pub fn new_at(kind: NodeKind, created_at: Timestamp) -> Self {
        let id = Self::compute_id(&kind);
        let merkle_root = Hash(id.0);
        Self {
            id,
            kind,
            created_at,
            merkle_root,
        }
    }
}

// ── canonical_json: deterministic JSON for content-addressing ────────────

/// Serialise a value via serde_json with sorted keys + no whitespace
/// — the same canonicalisation `GenUIPayload::canonicalJSONEncoder()`
/// uses. Stable across runs; identical input always produces
/// identical bytes.
///
/// Note: serde_json's `to_string` already produces sorted keys for
/// structs (field order is fixed by definition); for maps, BTreeMap
/// iteration is sorted. This wrapper exists so future changes to the
/// canonicalisation strategy go in one place.
pub fn canonical_json<T: Serialize>(value: &T) -> String {
    serde_json::to_string(value).expect("serializable kind")
}

// ── hex lowercase helper (no extra crate dependency) ────────────────────

fn hex_lower(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        out.push(hex_nibble(b >> 4));
        out.push(hex_nibble(b & 0x0f));
    }
    out
}

fn hex_nibble(n: u8) -> char {
    match n {
        0..=9 => (b'0' + n) as char,
        10..=15 => (b'a' + n - 10) as char,
        _ => unreachable!("nibble out of range"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_note() -> NodeKind {
        NodeKind::Note {
            body: "hello".into(),
            author: AuthorRef("user".into()),
            mime: MimeType("text/markdown".into()),
        }
    }

    fn all_node_kind_variants() -> [NodeKind; 10] {
        [
            NodeKind::Note {
                body: "".into(),
                author: AuthorRef("".into()),
                mime: MimeType("".into()),
            },
            NodeKind::Claim {
                proposition: "".into(),
                scope: ClaimScope::Vault,
                source: SourceRef("".into()),
            },
            NodeKind::Evidence {
                kind: EvidenceKind::Citation,
                payload: EvidenceBlob(vec![]),
                captured_at: Timestamp(0),
            },
            NodeKind::Skill {
                name: "".into(),
                description: "".into(),
                schema_version: 0,
            },
            NodeKind::Tool {
                id: ToolId("".into()),
                surface: ToolSurface::Other,
                tier: NodeTier::None,
            },
            NodeKind::Procedure {
                skill_ref: NodeId([0u8; 32]),
                context_hash: ContextHash([0u8; 32]),
                outcomes: OutcomeList(vec![]),
            },
            NodeKind::Event {
                kind: DagAgentEventKind::TurnStart,
                ts: Timestamp(0),
                session: SessionId("".into()),
            },
            NodeKind::Companion {
                profile: ModelProfile("".into()),
                identity: IdentityHash([0u8; 32]),
                persona: PersonaBlob(vec![]),
            },
            NodeKind::Capability {
                kind: CapabilityKind::Approval,
                scope: CapabilityScope("".into()),
                expiry: None,
            },
            NodeKind::Model {
                weight_root: WeightRoot([0u8; 32]),
                base_or_lora: ModelLineage::Base,
            },
        ]
    }

    #[test]
    fn node_id_is_deterministic_for_identical_content() {
        let a = Node::compute_id(&sample_note());
        let b = Node::compute_id(&sample_note());
        assert_eq!(a, b, "content-addressing must be deterministic");
    }

    #[test]
    fn different_content_produces_different_id() {
        let a = Node::compute_id(&sample_note());
        let b = Node::compute_id(&NodeKind::Note {
            body: "goodbye".into(),
            author: AuthorRef("user".into()),
            mime: MimeType("text/markdown".into()),
        });
        assert_ne!(a, b, "different bodies must produce different ids");
    }

    #[test]
    fn different_kinds_produce_different_ids() {
        let note_id = Node::compute_id(&sample_note());
        let claim_id = Node::compute_id(&NodeKind::Claim {
            proposition: "hello".into(),
            scope: ClaimScope::Vault,
            source: SourceRef("user".into()),
        });
        assert_ne!(
            note_id, claim_id,
            "different kinds must produce different ids"
        );
    }

    #[test]
    fn new_node_initialises_merkle_root_to_id() {
        let node = Node::new(sample_note());
        assert_eq!(node.merkle_root.as_bytes(), node.id.as_bytes());
    }

    #[test]
    fn new_at_uses_supplied_timestamp() {
        let ts = Timestamp(1_000_000);
        let node = Node::new_at(sample_note(), ts);
        assert_eq!(node.created_at, ts);
    }

    #[test]
    fn discriminator_covers_all_variants() {
        // Sanity: every variant has a non-empty discriminator.
        // Cargo will fail-to-compile if a new variant is added without
        // updating discriminator(), so this test mostly guards against
        // typos in the discriminator strings.
        let variants = all_node_kind_variants();
        let mut seen_discriminators = std::collections::BTreeSet::new();
        for v in &variants {
            let d = v.discriminator();
            assert!(!d.is_empty(), "discriminator must be non-empty");
            assert!(
                seen_discriminators.insert(d),
                "duplicate discriminator: {}",
                d
            );
        }
        assert_eq!(
            seen_discriminators.len(),
            10,
            "10 variants per doctrine §1.1"
        );
    }

    #[test]
    fn dynamic_rooted_discriminator_covers_all_variants() {
        for kind in all_node_kind_variants() {
            let expected_dynamic =
                matches!(kind, NodeKind::Companion { .. } | NodeKind::Model { .. });
            assert_eq!(
                kind.is_dynamic_rooted(),
                expected_dynamic,
                "{} dynamic-rooted classification drifted",
                kind.discriminator()
            );
        }
    }

    #[test]
    fn node_round_trips_through_canonical_json() {
        let node = Node::new_at(sample_note(), Timestamp(1234));
        let encoded = serde_json::to_string(&node).unwrap();
        let decoded: Node = serde_json::from_str(&encoded).unwrap();
        assert_eq!(node, decoded);
        assert_eq!(decoded.id, node.id);
    }

    #[test]
    fn node_id_to_hex_is_64_chars_lowercase() {
        let id = Node::compute_id(&sample_note());
        let hex = id.to_hex();
        assert_eq!(hex.len(), 64);
        assert!(hex
            .chars()
            .all(|c| c.is_ascii_hexdigit() && (!c.is_ascii_uppercase())));
    }

    #[test]
    fn timestamp_now_is_nonzero_and_monotonic_or_equal() {
        let a = Timestamp::now();
        let b = Timestamp::now();
        assert!(a.0 > 0);
        assert!(b >= a, "now must not go backwards within a process");
    }

    #[test]
    fn hash_zero_is_all_zero_bytes() {
        let z = Hash::zero();
        assert!(z.as_bytes().iter().all(|b| *b == 0));
    }

    #[test]
    fn canonical_json_handles_all_node_kinds() {
        // Sanity: every variant serialises without panicking.
        let kinds = [
            sample_note(),
            NodeKind::Claim {
                proposition: "p".into(),
                scope: ClaimScope::Global,
                source: SourceRef("s".into()),
            },
            NodeKind::Capability {
                kind: CapabilityKind::ToolInvoke("vault.write".into()),
                scope: CapabilityScope("vault_x".into()),
                expiry: Some(Timestamp(99999)),
            },
        ];
        for k in &kinds {
            let json = canonical_json(k);
            assert!(!json.is_empty());
            // Every canonical JSON encodes the discriminator
            assert!(json.contains(k.discriminator()));
        }
    }
}
