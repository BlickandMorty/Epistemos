//! Tri-Fusion content fabric, Phase C JSON floor.
//!
//! These first slices intentionally prove the authoritative ProseMirror JSON
//! path and deterministic structured mutations. Markdown is a declared
//! canonical subset with its own byte-equal fixtures; HTML starts as a strict
//! semantic-tree subset with tree-equal fixtures.

use std::collections::BTreeSet;

use crate::artifacts::ArtifactRef;
use crate::cognitive_dag::Hash as DagHash;
use crate::cognitive_dag::{
    ClaimScope, DagError, DagStore, Edge, EdgeId, EdgeKind, EdgeKindSelector, EvidenceBlob,
    EvidenceKind, Node, NodeId, NodeKind, SourceRef, Timestamp,
};
use crate::mutations::{
    BlockRef, MutationActor, MutationEnvelope, Reversibility, Sensitivity, SourceOp,
};
use crate::provenance::ledger::{
    Claim, ClaimId, ClaimKind, ClaimLedger, Evidence, EvidenceId, LedgerError,
};

use serde::de::Error as SerdeDeError;
use serde::{Deserialize, Deserializer, Serialize, Serializer};
use serde_json::{json, Map, Value};
use thiserror::Error;

mod html;
mod markdown;

pub const TRI_FUSION_JSON_CANONICAL_VERSION: &str = "tri_fusion_json_v0";

const HASH_DOMAIN: &[u8] = b"epistemos.tri_fusion.document.v0\0";
const MUTATION_DOMAIN: &[u8] = b"epistemos.tri_fusion.mutation.v0\0";
const PROVENANCE_CAPABILITY_DOMAIN: &[u8] = b"epistemos.tri_fusion.provenance.capability.v0\0";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TriFusionDocument {
    root: Value,
    canonical_json: String,
    hash: TriFusionDocumentHash,
}

#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct TriFusionDocumentHash([u8; 32]);

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case", tag = "kind")]
pub enum TriFusionMutation {
    InsertBlock {
        artifact_id: String,
        after_block_id: Option<String>,
        block: Value,
    },
    MutateBlock {
        artifact_id: String,
        block_id: String,
        replacement: Value,
    },
    LinkBlock {
        artifact_id: String,
        from_block_id: String,
        to_block_id: String,
        relation: String,
    },
    TranscludeBlock {
        artifact_id: String,
        after_block_id: Option<String>,
        source_block_id: String,
        transclusion_block_id: String,
    },
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TriFusionMutationEnvelope {
    pub mutation_id: String,
    pub document_id: String,
    pub base_document_hash: TriFusionDocumentHash,
    pub actor: TriFusionMutationActor,
    pub source_format: TriFusionSourceFormat,
    pub rationale: String,
    #[serde(flatten)]
    pub mutation: TriFusionMutation,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case", tag = "kind")]
pub enum TriFusionMutationActor {
    User,
    Agent { run_id: String },
    System,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct TriFusionMutationActorWire {
    kind: String,
    run_id: Option<String>,
}

impl<'de> Deserialize<'de> for TriFusionMutationActor {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let wire = TriFusionMutationActorWire::deserialize(deserializer)?;
        match wire.kind.as_str() {
            "user" => reject_unit_actor_run_id(wire.run_id, "user").map(|()| Self::User),
            "agent" => {
                let run_id = wire
                    .run_id
                    .ok_or_else(|| D::Error::missing_field("run_id"))?;
                if run_id.trim().is_empty() {
                    return Err(D::Error::custom("agent actor run_id must be non-empty"));
                }
                Ok(Self::Agent { run_id })
            }
            "system" => reject_unit_actor_run_id(wire.run_id, "system").map(|()| Self::System),
            _ => Err(D::Error::unknown_variant(
                &wire.kind,
                &["user", "agent", "system"],
            )),
        }
    }
}

fn reject_unit_actor_run_id<E>(run_id: Option<String>, actor_kind: &'static str) -> Result<(), E>
where
    E: SerdeDeError,
{
    if run_id.is_some() {
        Err(E::custom(format!(
            "{actor_kind} actor must not include run_id"
        )))
    } else {
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TriFusionSourceFormat {
    Json,
    Markdown,
    Html,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TriFusionProvenanceStatus {
    #[default]
    Deferred,
    Committed,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TriFusionWitness {
    pub mutation_id: String,
    pub mutation_kind: String,
    pub before_hash: TriFusionDocumentHash,
    pub after_hash: TriFusionDocumentHash,
    pub touched_blocks: Vec<BlockRef>,
    pub canonical_version: String,
    #[serde(default)]
    pub provenance_status: TriFusionProvenanceStatus,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub envelope_mutation_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub document_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub actor: Option<TriFusionMutationActor>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_format: Option<TriFusionSourceFormat>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rationale: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub mutation_envelope_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub claim_graph_node_id: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cognitive_dag_edge_id: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TriFusionMutationResult {
    pub document: TriFusionDocument,
    pub witness: TriFusionWitness,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TriFusionCognitiveDagProvenanceIds {
    pub claim_node_id: String,
    pub evidence_node_id: String,
    pub derives_from_evidence_edge_id: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct TriFusionCognitiveDagProvenanceVerification {
    pub ids: TriFusionCognitiveDagProvenanceIds,
    pub claim_node_present: bool,
    pub evidence_node_present: bool,
    pub derives_from_evidence_edge_present: bool,
    pub status: TriFusionCognitiveDagProvenanceVerificationStatus,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TriFusionCognitiveDagProvenanceVerificationStatus {
    Complete,
    MissingNode,
    MissingDerivesFromEdge,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct TriFusionCognitiveDagProvenanceIdentity {
    claim_node_id: NodeId,
    evidence_node_id: NodeId,
    derives_from_evidence_edge_id: EdgeId,
}

impl TriFusionMutationResult {
    pub fn pending_mutation_envelope(
        &self,
        sequence: u64,
        created_at_ms: i64,
    ) -> Result<MutationEnvelope, TriFusionError> {
        self.witness
            .pending_mutation_envelope(sequence, created_at_ms)
    }

    pub fn commit_claim_ledger_provenance(
        &self,
        ledger: &mut ClaimLedger,
        created_at_ms: i64,
    ) -> Result<TriFusionWitness, LedgerError> {
        self.witness
            .commit_claim_ledger_provenance(ledger, created_at_ms)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct TriFusionWitnessContext {
    envelope_mutation_id: String,
    document_id: String,
    actor: TriFusionMutationActor,
    source_format: TriFusionSourceFormat,
    rationale: String,
}

#[derive(Clone, Debug, Error, PartialEq, Eq)]
pub enum TriFusionError {
    #[error("invalid JSON: {message}")]
    InvalidJson { message: String },
    #[error("document root must be a JSON object")]
    RootNotObject,
    #[error("document root must have string type \"doc\"")]
    RootTypeNotDoc,
    #[error("document root must have array content")]
    RootContentNotArray,
    #[error("node at {path} must be a JSON object")]
    NodeNotObject { path: String },
    #[error("node at {path} must have a non-empty string type")]
    NodeTypeInvalid { path: String },
    #[error("node at {path} has non-object attrs")]
    NodeAttrsInvalid { path: String },
    #[error("node at {path} has non-array content")]
    NodeContentInvalid { path: String },
    #[error("node at {path} has non-array marks")]
    NodeMarksInvalid { path: String },
    #[error("mark at {path} must be a JSON object with a non-empty string type")]
    MarkInvalid { path: String },
    #[error("text node at {path} must have string text")]
    TextNodeMissingText { path: String },
    #[error("mutation block at {path} must carry attrs.id or attrs.block_id")]
    MutationBlockIdentityMissing { path: String },
    #[error("mutation block id {block_id:?} already exists")]
    DuplicateBlockIdentity { block_id: String },
    #[error(
        "replacement block id {replacement_block_id:?} does not match target {target_block_id:?}"
    )]
    ReplacementBlockIdentityMismatch {
        target_block_id: String,
        replacement_block_id: String,
    },
    #[error("block {block_id:?} not found")]
    BlockNotFound { block_id: String },
    #[error("base document hash mismatch: expected {expected}, got {actual}")]
    BaseDocumentHashMismatch {
        expected: TriFusionDocumentHash,
        actual: TriFusionDocumentHash,
    },
    #[error("invalid Markdown at line {line}: {message}")]
    InvalidMarkdown { line: usize, message: String },
    #[error("unsupported Markdown projection at {path}: {message}")]
    UnsupportedMarkdownProjection { path: String, message: String },
    #[error("invalid HTML: {message}")]
    InvalidHtml { message: String },
    #[error("unsupported HTML projection at {path}: {message}")]
    UnsupportedHtmlProjection { path: String, message: String },
    #[error("invalid mutation: {message}")]
    InvalidMutation { message: String },
}

impl TriFusionDocument {
    pub fn parse_json(input: &str) -> Result<Self, TriFusionError> {
        let root: Value =
            serde_json::from_str(input).map_err(|error| TriFusionError::InvalidJson {
                message: error.to_string(),
            })?;
        Self::from_json_value(root)
    }

    pub fn from_json_value(root: Value) -> Result<Self, TriFusionError> {
        validate_document(&root)?;
        let canonical_json = canonical_json_value(&root);
        let hash = TriFusionDocumentHash::for_canonical_json(&canonical_json);
        Ok(Self {
            root,
            canonical_json,
            hash,
        })
    }

    pub fn canonical_json(&self) -> &str {
        &self.canonical_json
    }

    pub fn root(&self) -> &Value {
        &self.root
    }

    pub fn hash(&self) -> TriFusionDocumentHash {
        self.hash
    }

    pub fn canonical_version(&self) -> &'static str {
        TRI_FUSION_JSON_CANONICAL_VERSION
    }

    pub fn apply_mutation(
        &self,
        mutation: TriFusionMutation,
    ) -> Result<TriFusionMutationResult, TriFusionError> {
        self.apply_mutation_with_context(mutation, None)
    }

    fn apply_mutation_with_context(
        &self,
        mutation: TriFusionMutation,
        witness_context: Option<TriFusionWitnessContext>,
    ) -> Result<TriFusionMutationResult, TriFusionError> {
        let mut next_root = self.root.clone();
        let touched_blocks = mutation.apply_to_root(&mut next_root)?;
        let document = Self::from_json_value(next_root)?;
        let witness =
            TriFusionWitness::new(self, &document, &mutation, touched_blocks, witness_context);
        Ok(TriFusionMutationResult { document, witness })
    }

    pub fn apply_mutation_envelope(
        &self,
        envelope: TriFusionMutationEnvelope,
    ) -> Result<TriFusionMutationResult, TriFusionError> {
        if envelope.base_document_hash != self.hash {
            return Err(TriFusionError::BaseDocumentHashMismatch {
                expected: self.hash,
                actual: envelope.base_document_hash,
            });
        }
        let witness_context = TriFusionWitnessContext {
            envelope_mutation_id: envelope.mutation_id,
            document_id: envelope.document_id,
            actor: envelope.actor,
            source_format: envelope.source_format,
            rationale: envelope.rationale,
        };
        self.apply_mutation_with_context(envelope.mutation, Some(witness_context))
    }
}

impl TriFusionDocumentHash {
    pub fn for_canonical_json(canonical_json: &str) -> Self {
        let mut hasher = blake3::Hasher::new();
        hasher.update(HASH_DOMAIN);
        hasher.update(TRI_FUSION_JSON_CANONICAL_VERSION.as_bytes());
        hasher.update(b"\0");
        hasher.update(canonical_json.as_bytes());
        let digest = hasher.finalize();
        Self(*digest.as_bytes())
    }

    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    pub fn to_hex(self) -> String {
        hex_lower(&self.0)
    }
}

impl Serialize for TriFusionDocumentHash {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&self.to_hex())
    }
}

impl<'de> Deserialize<'de> for TriFusionDocumentHash {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = String::deserialize(deserializer)?;
        parse_hash_hex(&value).map_err(D::Error::custom)
    }
}

impl std::fmt::Debug for TriFusionDocumentHash {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_tuple("TriFusionDocumentHash")
            .field(&self.to_hex())
            .finish()
    }
}

impl std::fmt::Display for TriFusionDocumentHash {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.to_hex())
    }
}

impl TriFusionMutation {
    pub fn kind(&self) -> &'static str {
        match self {
            Self::InsertBlock { .. } => "insert_block",
            Self::MutateBlock { .. } => "mutate_block",
            Self::LinkBlock { .. } => "link_block",
            Self::TranscludeBlock { .. } => "transclude_block",
        }
    }

    fn apply_to_root(&self, root: &mut Value) -> Result<Vec<BlockRef>, TriFusionError> {
        match self {
            Self::InsertBlock {
                artifact_id,
                after_block_id,
                block,
            } => apply_insert_block(root, artifact_id, after_block_id.as_deref(), block),
            Self::MutateBlock {
                artifact_id,
                block_id,
                replacement,
            } => apply_mutate_block(root, artifact_id, block_id, replacement),
            Self::LinkBlock {
                artifact_id,
                from_block_id,
                to_block_id,
                relation,
            } => apply_link_block(root, artifact_id, from_block_id, to_block_id, relation),
            Self::TranscludeBlock {
                artifact_id,
                after_block_id,
                source_block_id,
                transclusion_block_id,
            } => apply_transclude_block(
                root,
                artifact_id,
                after_block_id.as_deref(),
                source_block_id,
                transclusion_block_id,
            ),
        }
    }
}

impl TriFusionWitness {
    pub fn provenance_claim_id(&self) -> ClaimId {
        ClaimId::new(format!("tri_fusion:claim:{}", self.mutation_id))
    }

    pub fn provenance_evidence_id(&self) -> EvidenceId {
        EvidenceId::new(format!("tri_fusion:evidence:{}", self.mutation_id))
    }

    pub fn provenance_claim_text(&self) -> String {
        let document_id = self
            .document_id
            .as_deref()
            .unwrap_or("unknown-tri-fusion-document");
        format!(
            "Tri-Fusion mutation {} transformed document {} from {} to {}.",
            self.mutation_id, document_id, self.before_hash, self.after_hash
        )
    }

    pub fn provenance_evidence_source(&self) -> String {
        format!(
            "tri_fusion_witness:{}:{}:{}:{}",
            self.mutation_id, self.mutation_kind, self.before_hash, self.after_hash
        )
    }

    pub fn cognitive_dag_provenance_ids(
        &self,
        created_at_ms: i64,
    ) -> TriFusionCognitiveDagProvenanceIds {
        self.cognitive_dag_provenance_identity(created_at_ms)
            .public_ids()
    }

    pub fn verify_cognitive_dag_provenance(
        &self,
        store: &dyn DagStore,
        created_at_ms: i64,
    ) -> Result<TriFusionCognitiveDagProvenanceVerification, DagError> {
        let identity = self.cognitive_dag_provenance_identity(created_at_ms);
        let claim_node_present = store.get_node(identity.claim_node_id)?.is_some();
        let evidence_node_present = store.get_node(identity.evidence_node_id)?.is_some();
        let derives_from_evidence_edge_present = if claim_node_present {
            store
                .edges_from(identity.claim_node_id, Some(EdgeKindSelector::DerivesFrom))?
                .iter()
                .any(|edge| edge.id() == identity.derives_from_evidence_edge_id)
        } else {
            false
        };
        let status = if !claim_node_present || !evidence_node_present {
            TriFusionCognitiveDagProvenanceVerificationStatus::MissingNode
        } else if !derives_from_evidence_edge_present {
            TriFusionCognitiveDagProvenanceVerificationStatus::MissingDerivesFromEdge
        } else {
            TriFusionCognitiveDagProvenanceVerificationStatus::Complete
        };

        Ok(TriFusionCognitiveDagProvenanceVerification {
            ids: identity.public_ids(),
            claim_node_present,
            evidence_node_present,
            derives_from_evidence_edge_present,
            status,
        })
    }

    fn cognitive_dag_provenance_identity(
        &self,
        created_at_ms: i64,
    ) -> TriFusionCognitiveDagProvenanceIdentity {
        let claim_id = self.provenance_claim_id();
        let evidence_id = self.provenance_evidence_id();
        let evidence_source = self.provenance_evidence_source();
        let claim_node_id = Node::compute_id(&NodeKind::Claim {
            proposition: self.provenance_claim_text(),
            scope: ClaimScope::Vault,
            source: SourceRef(format!("ledger_claim:{}", claim_id.0)),
        });
        let evidence_node_id = Node::compute_id(&NodeKind::Evidence {
            kind: EvidenceKind::Citation,
            payload: EvidenceBlob(cognitive_dag_evidence_payload_bytes(
                &evidence_id,
                &evidence_source,
            )),
            captured_at: Timestamp(created_at_ms.unsigned_abs()),
        });
        let edge_id = EdgeId::compute(
            &claim_node_id,
            &evidence_node_id,
            &EdgeKind::DerivesFrom { strength: 1.0 },
        );

        TriFusionCognitiveDagProvenanceIdentity {
            claim_node_id,
            evidence_node_id,
            derives_from_evidence_edge_id: edge_id,
        }
    }

    pub fn commit_claim_ledger_provenance(
        &self,
        ledger: &mut ClaimLedger,
        created_at_ms: i64,
    ) -> Result<Self, LedgerError> {
        let claim_id = self.provenance_claim_id();
        let evidence_id = self.provenance_evidence_id();
        let dag_ids = self.cognitive_dag_provenance_ids(created_at_ms);
        if ledger.claim(&claim_id).is_some() {
            return Err(LedgerError::DuplicateId(claim_id.0.clone()));
        }
        if ledger.evidence(&evidence_id).is_some() {
            return Err(LedgerError::DuplicateId(evidence_id.0.clone()));
        }

        let evidence = Evidence::new(
            evidence_id.clone(),
            self.provenance_evidence_source(),
            created_at_ms,
        );
        let claim = Claim::new(
            claim_id.clone(),
            self.provenance_claim_text(),
            created_at_ms,
        )
        .with_kind(ClaimKind::CodeInvariant);

        ledger.commit_evidence(evidence)?;
        ledger.commit_claim(claim, Vec::new(), vec![evidence_id])?;

        let mut committed = self.clone();
        if let Err(error) = committed.ensure_cognitive_dag_provenance_edge(created_at_ms) {
            tracing::warn!(
                target: "tri_fusion",
                mutation_id = %committed.mutation_id,
                error = %error,
                "Tri-Fusion provenance edge insertion failed"
            );
        }
        committed.provenance_status = TriFusionProvenanceStatus::Committed;
        committed.mutation_envelope_id = Some(
            committed
                .envelope_mutation_id
                .clone()
                .unwrap_or_else(|| committed.mutation_id.clone()),
        );
        committed.claim_graph_node_id = Some(dag_ids.claim_node_id);
        committed.cognitive_dag_edge_id = Some(dag_ids.derives_from_evidence_edge_id);
        Ok(committed)
    }

    fn ensure_cognitive_dag_provenance_edge(&self, created_at_ms: i64) -> Result<(), DagError> {
        let identity = self.cognitive_dag_provenance_identity(created_at_ms);
        let store = crate::cognitive_dag::dispatch::cognitive_dag_store();
        let claim_node_present = store.get_node(identity.claim_node_id)?.is_some();
        let evidence_node_present = store.get_node(identity.evidence_node_id)?.is_some();
        if !claim_node_present || !evidence_node_present {
            return Ok(());
        }

        let capability_hash = tri_fusion_provenance_capability_hash(&self.mutation_id);
        store.register_capability(capability_hash)?;
        let edge = Edge::new_at(
            identity.claim_node_id,
            identity.evidence_node_id,
            EdgeKind::DerivesFrom { strength: 1.0 },
            capability_hash,
            Timestamp(created_at_ms.unsigned_abs()),
        );
        store.put_edge(edge)?;
        Ok(())
    }

    pub fn pending_mutation_envelope(
        &self,
        sequence: u64,
        created_at_ms: i64,
    ) -> Result<MutationEnvelope, TriFusionError> {
        let mutation_id = self
            .envelope_mutation_id
            .clone()
            .unwrap_or_else(|| self.mutation_id.clone());
        let artifact_id = self
            .touched_blocks
            .first()
            .map(|block| block.artifact_id.clone())
            .or_else(|| self.document_id.clone())
            .ok_or_else(|| TriFusionError::InvalidMutation {
                message: "cannot build MutationEnvelope without touched block or document id"
                    .to_string(),
            })?;
        let actor = self
            .actor
            .as_ref()
            .map(mutation_actor_from_tri_fusion)
            .unwrap_or(MutationActor::System);
        let mut envelope = MutationEnvelope::pending(
            mutation_id,
            sequence,
            actor.clone(),
            SourceOp::ArtifactUpdate {
                artifact_id: artifact_id.clone(),
            },
            Sensitivity::Internal,
            Reversibility::Reversible,
            created_at_ms,
        );
        envelope.run_id = match actor {
            MutationActor::Agent { run_id } => Some(run_id),
            MutationActor::User | MutationActor::System => None,
        };
        envelope.touched_artifacts = self
            .touched_blocks
            .iter()
            .map(|block| block.artifact_id.clone())
            .chain(std::iter::once(artifact_id))
            .collect::<BTreeSet<_>>()
            .into_iter()
            .map(ArtifactRef::new)
            .collect();
        envelope.touched_blocks = self.touched_blocks.clone();
        envelope.affects_summary = true;
        envelope.affects_body = matches!(
            self.mutation_kind.as_str(),
            "insert_block" | "mutate_block" | "transclude_block"
        );
        envelope.affects_outline = envelope.affects_body;
        envelope.affects_search_projection = envelope.affects_body;
        envelope.affects_backlinks = matches!(
            self.mutation_kind.as_str(),
            "link_block" | "transclude_block"
        );
        envelope.affects_graph = envelope.affects_backlinks;
        Ok(envelope)
    }

    fn new(
        before: &TriFusionDocument,
        after: &TriFusionDocument,
        mutation: &TriFusionMutation,
        touched_blocks: Vec<BlockRef>,
        witness_context: Option<TriFusionWitnessContext>,
    ) -> Self {
        let mutation_json = serde_json::to_value(mutation).expect("mutation serializes");
        let canonical_mutation = canonical_json_value(&mutation_json);
        let mut hasher = blake3::Hasher::new();
        hasher.update(MUTATION_DOMAIN);
        hasher.update(TRI_FUSION_JSON_CANONICAL_VERSION.as_bytes());
        hasher.update(b"\0");
        hasher.update(before.hash.as_bytes());
        hasher.update(after.hash.as_bytes());
        hasher.update(canonical_mutation.as_bytes());
        let mutation_id = hex_lower(hasher.finalize().as_bytes());
        let (envelope_mutation_id, document_id, actor, source_format, rationale) =
            match witness_context {
                Some(context) => (
                    Some(context.envelope_mutation_id),
                    Some(context.document_id),
                    Some(context.actor),
                    Some(context.source_format),
                    Some(context.rationale),
                ),
                None => (None, None, None, None, None),
            };

        Self {
            mutation_id,
            mutation_kind: mutation.kind().to_string(),
            before_hash: before.hash,
            after_hash: after.hash,
            touched_blocks,
            canonical_version: TRI_FUSION_JSON_CANONICAL_VERSION.to_string(),
            provenance_status: TriFusionProvenanceStatus::Deferred,
            envelope_mutation_id,
            document_id,
            actor,
            source_format,
            rationale,
            mutation_envelope_id: None,
            claim_graph_node_id: None,
            cognitive_dag_edge_id: None,
        }
    }
}

impl TriFusionCognitiveDagProvenanceIdentity {
    fn public_ids(self) -> TriFusionCognitiveDagProvenanceIds {
        TriFusionCognitiveDagProvenanceIds {
            claim_node_id: self.claim_node_id.to_hex(),
            evidence_node_id: self.evidence_node_id.to_hex(),
            derives_from_evidence_edge_id: hex_lower(self.derives_from_evidence_edge_id.as_bytes()),
        }
    }
}

fn mutation_actor_from_tri_fusion(actor: &TriFusionMutationActor) -> MutationActor {
    match actor {
        TriFusionMutationActor::User => MutationActor::User,
        TriFusionMutationActor::Agent { run_id } => MutationActor::Agent {
            run_id: run_id.clone(),
        },
        TriFusionMutationActor::System => MutationActor::System,
    }
}

fn cognitive_dag_evidence_payload_bytes(evidence_id: &EvidenceId, source: &str) -> Vec<u8> {
    let mut hasher = blake3::Hasher::new();
    hasher.update(b"epistemos-ledger-evidence-v1");
    hasher.update(evidence_id.0.as_bytes());
    hasher.update(b"\n");
    hasher.update(source.as_bytes());
    hasher.finalize().as_bytes().to_vec()
}

fn tri_fusion_provenance_capability_hash(mutation_id: &str) -> DagHash {
    let mut hasher = blake3::Hasher::new();
    hasher.update(PROVENANCE_CAPABILITY_DOMAIN);
    hasher.update(mutation_id.as_bytes());
    DagHash::from_bytes(*hasher.finalize().as_bytes())
}

fn apply_insert_block(
    root: &mut Value,
    artifact_id: &str,
    after_block_id: Option<&str>,
    block: &Value,
) -> Result<Vec<BlockRef>, TriFusionError> {
    validate_node(block, "$.mutation.block")?;
    let inserted_block_id = required_block_identity(block, "$.mutation.block")?.to_string();
    reject_duplicate_block_id(root, &inserted_block_id)?;

    if let Some(after_block_id) = after_block_id {
        if !insert_after_block(root, after_block_id, block)? {
            return Err(TriFusionError::BlockNotFound {
                block_id: after_block_id.to_string(),
            });
        }
    } else {
        root_content_mut(root)?.push(block.clone());
    }

    Ok(vec![BlockRef::new(artifact_id, inserted_block_id)])
}

fn apply_mutate_block(
    root: &mut Value,
    artifact_id: &str,
    block_id: &str,
    replacement: &Value,
) -> Result<Vec<BlockRef>, TriFusionError> {
    reject_empty_id("block_id", block_id)?;
    validate_node(replacement, "$.mutation.replacement")?;
    let replacement_block_id = required_block_identity(replacement, "$.mutation.replacement")?;
    if replacement_block_id != block_id {
        return Err(TriFusionError::ReplacementBlockIdentityMismatch {
            target_block_id: block_id.to_string(),
            replacement_block_id: replacement_block_id.to_string(),
        });
    }

    if !replace_block_by_id(root, block_id, replacement)? {
        return Err(TriFusionError::BlockNotFound {
            block_id: block_id.to_string(),
        });
    }

    Ok(vec![BlockRef::new(artifact_id, block_id)])
}

fn apply_link_block(
    root: &mut Value,
    artifact_id: &str,
    from_block_id: &str,
    to_block_id: &str,
    relation: &str,
) -> Result<Vec<BlockRef>, TriFusionError> {
    reject_empty_id("from_block_id", from_block_id)?;
    reject_empty_id("to_block_id", to_block_id)?;
    if relation.trim().is_empty() {
        return Err(TriFusionError::InvalidMutation {
            message: "relation must be non-empty".to_string(),
        });
    }
    if find_block_by_id(root, to_block_id)?.is_none() {
        return Err(TriFusionError::BlockNotFound {
            block_id: to_block_id.to_string(),
        });
    }

    let source = find_block_by_id_mut(root, from_block_id)?.ok_or_else(|| {
        TriFusionError::BlockNotFound {
            block_id: from_block_id.to_string(),
        }
    })?;
    let attrs = attrs_object_mut(source)?;
    let links = attrs
        .entry("links".to_string())
        .or_insert_with(|| Value::Array(Vec::new()))
        .as_array_mut()
        .ok_or_else(|| TriFusionError::InvalidMutation {
            message: "attrs.links must be an array".to_string(),
        })?;
    let link = json!({
        "relation": relation,
        "target_block_id": to_block_id,
    });
    if !links.iter().any(|existing| existing == &link) {
        links.push(link);
        links.sort_by_key(canonical_json_value);
    }

    Ok(vec![
        BlockRef::new(artifact_id, from_block_id),
        BlockRef::new(artifact_id, to_block_id),
    ])
}

fn apply_transclude_block(
    root: &mut Value,
    artifact_id: &str,
    after_block_id: Option<&str>,
    source_block_id: &str,
    transclusion_block_id: &str,
) -> Result<Vec<BlockRef>, TriFusionError> {
    reject_empty_id("source_block_id", source_block_id)?;
    reject_empty_id("transclusion_block_id", transclusion_block_id)?;
    if find_block_by_id(root, source_block_id)?.is_none() {
        return Err(TriFusionError::BlockNotFound {
            block_id: source_block_id.to_string(),
        });
    }
    reject_duplicate_block_id(root, transclusion_block_id)?;

    let block = json!({
        "type": "transclusion",
        "attrs": {
            "id": transclusion_block_id,
            "source_block_id": source_block_id,
        },
    });

    if let Some(after_block_id) = after_block_id {
        if !insert_after_block(root, after_block_id, &block)? {
            return Err(TriFusionError::BlockNotFound {
                block_id: after_block_id.to_string(),
            });
        }
    } else {
        root_content_mut(root)?.push(block);
    }

    Ok(vec![
        BlockRef::new(artifact_id, source_block_id),
        BlockRef::new(artifact_id, transclusion_block_id),
    ])
}

fn root_content_mut(root: &mut Value) -> Result<&mut Vec<Value>, TriFusionError> {
    root.as_object_mut()
        .and_then(|object| object.get_mut("content"))
        .and_then(Value::as_array_mut)
        .ok_or(TriFusionError::RootContentNotArray)
}

fn root_content(root: &Value) -> Result<&Vec<Value>, TriFusionError> {
    root.as_object()
        .and_then(|object| object.get("content"))
        .and_then(Value::as_array)
        .ok_or(TriFusionError::RootContentNotArray)
}

fn insert_after_block(
    root: &mut Value,
    after_block_id: &str,
    block: &Value,
) -> Result<bool, TriFusionError> {
    reject_empty_id("after_block_id", after_block_id)?;
    Ok(insert_after_block_in_content(
        root_content_mut(root)?,
        after_block_id,
        block,
    ))
}

fn insert_after_block_in_content(
    content: &mut Vec<Value>,
    after_block_id: &str,
    block: &Value,
) -> bool {
    for index in 0..content.len() {
        if block_identity(&content[index]).is_some_and(|identity| identity == after_block_id) {
            content.insert(index + 1, block.clone());
            return true;
        }
        if let Some(child_content) = content[index]
            .as_object_mut()
            .and_then(|object| object.get_mut("content"))
            .and_then(Value::as_array_mut)
        {
            if insert_after_block_in_content(child_content, after_block_id, block) {
                return true;
            }
        }
    }
    false
}

fn replace_block_by_id(
    root: &mut Value,
    block_id: &str,
    replacement: &Value,
) -> Result<bool, TriFusionError> {
    Ok(replace_block_by_id_in_content(
        root_content_mut(root)?,
        block_id,
        replacement,
    ))
}

fn replace_block_by_id_in_content(
    content: &mut Vec<Value>,
    block_id: &str,
    replacement: &Value,
) -> bool {
    for node in content.iter_mut() {
        if block_identity(node).is_some_and(|identity| identity == block_id) {
            *node = replacement.clone();
            return true;
        }
        if let Some(child_content) = node
            .as_object_mut()
            .and_then(|object| object.get_mut("content"))
            .and_then(Value::as_array_mut)
        {
            if replace_block_by_id_in_content(child_content, block_id, replacement) {
                return true;
            }
        }
    }
    false
}

fn find_block_by_id<'a>(
    root: &'a Value,
    block_id: &str,
) -> Result<Option<&'a Value>, TriFusionError> {
    reject_empty_id("block_id", block_id)?;
    Ok(find_block_by_id_in_content(root_content(root)?, block_id))
}

fn find_block_by_id_in_content<'a>(content: &'a [Value], block_id: &str) -> Option<&'a Value> {
    for node in content {
        if block_identity(node).is_some_and(|identity| identity == block_id) {
            return Some(node);
        }
        if let Some(child_content) = node
            .as_object()
            .and_then(|object| object.get("content"))
            .and_then(Value::as_array)
        {
            if let Some(found) = find_block_by_id_in_content(child_content, block_id) {
                return Some(found);
            }
        }
    }
    None
}

fn find_block_by_id_mut<'a>(
    root: &'a mut Value,
    block_id: &str,
) -> Result<Option<&'a mut Value>, TriFusionError> {
    reject_empty_id("block_id", block_id)?;
    Ok(find_block_by_id_mut_in_content(
        root_content_mut(root)?,
        block_id,
    ))
}

fn find_block_by_id_mut_in_content<'a>(
    content: &'a mut [Value],
    block_id: &str,
) -> Option<&'a mut Value> {
    for node in content {
        if block_identity(node).is_some_and(|identity| identity == block_id) {
            return Some(node);
        }
        if let Some(child_content) = node
            .as_object_mut()
            .and_then(|object| object.get_mut("content"))
            .and_then(Value::as_array_mut)
        {
            if let Some(found) = find_block_by_id_mut_in_content(child_content, block_id) {
                return Some(found);
            }
        }
    }
    None
}

fn block_identity(node: &Value) -> Option<&str> {
    node.as_object()
        .and_then(|object| object.get("attrs"))
        .and_then(Value::as_object)
        .and_then(|attrs| {
            attrs
                .get("id")
                .or_else(|| attrs.get("block_id"))
                .and_then(Value::as_str)
                .filter(|value| !value.is_empty())
        })
}

fn required_block_identity<'a>(node: &'a Value, path: &str) -> Result<&'a str, TriFusionError> {
    block_identity(node).ok_or_else(|| TriFusionError::MutationBlockIdentityMissing {
        path: path.to_string(),
    })
}

fn reject_duplicate_block_id(root: &Value, block_id: &str) -> Result<(), TriFusionError> {
    reject_empty_id("block_id", block_id)?;
    if find_block_by_id(root, block_id)?.is_some() {
        Err(TriFusionError::DuplicateBlockIdentity {
            block_id: block_id.to_string(),
        })
    } else {
        Ok(())
    }
}

fn reject_empty_id(field: &str, value: &str) -> Result<(), TriFusionError> {
    if value.is_empty() {
        Err(TriFusionError::InvalidMutation {
            message: format!("{field} must be non-empty"),
        })
    } else {
        Ok(())
    }
}

fn attrs_object_mut(node: &mut Value) -> Result<&mut Map<String, Value>, TriFusionError> {
    let object = node
        .as_object_mut()
        .ok_or_else(|| TriFusionError::NodeNotObject {
            path: "$.mutation.link_source".to_string(),
        })?;
    let attrs = object
        .entry("attrs".to_string())
        .or_insert_with(|| Value::Object(Map::new()));
    attrs
        .as_object_mut()
        .ok_or_else(|| TriFusionError::NodeAttrsInvalid {
            path: "$.mutation.link_source.attrs".to_string(),
        })
}

fn validate_document(root: &Value) -> Result<(), TriFusionError> {
    let object = root.as_object().ok_or(TriFusionError::RootNotObject)?;

    match object.get("type").and_then(Value::as_str) {
        Some("doc") => {}
        _ => return Err(TriFusionError::RootTypeNotDoc),
    }

    let content = object
        .get("content")
        .and_then(Value::as_array)
        .ok_or(TriFusionError::RootContentNotArray)?;

    for (index, node) in content.iter().enumerate() {
        validate_node(node, &format!("$.content[{index}]"))?;
    }

    Ok(())
}

fn validate_node(node: &Value, path: &str) -> Result<(), TriFusionError> {
    let object = node
        .as_object()
        .ok_or_else(|| TriFusionError::NodeNotObject {
            path: path.to_string(),
        })?;

    let node_type = object
        .get("type")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| TriFusionError::NodeTypeInvalid {
            path: path.to_string(),
        })?;

    if let Some(attrs) = object.get("attrs") {
        if !attrs.is_object() {
            return Err(TriFusionError::NodeAttrsInvalid {
                path: format!("{path}.attrs"),
            });
        }
    }

    if let Some(marks) = object.get("marks") {
        let marks = marks
            .as_array()
            .ok_or_else(|| TriFusionError::NodeMarksInvalid {
                path: format!("{path}.marks"),
            })?;
        for (index, mark) in marks.iter().enumerate() {
            validate_mark(mark, &format!("{path}.marks[{index}]"))?;
        }
    }

    if node_type == "text" && !object.get("text").is_some_and(Value::is_string) {
        return Err(TriFusionError::TextNodeMissingText {
            path: path.to_string(),
        });
    }

    if let Some(content) = object.get("content") {
        let content = content
            .as_array()
            .ok_or_else(|| TriFusionError::NodeContentInvalid {
                path: format!("{path}.content"),
            })?;
        for (index, child) in content.iter().enumerate() {
            validate_node(child, &format!("{path}.content[{index}]"))?;
        }
    }

    Ok(())
}

fn validate_mark(mark: &Value, path: &str) -> Result<(), TriFusionError> {
    let object = mark
        .as_object()
        .ok_or_else(|| TriFusionError::MarkInvalid {
            path: path.to_string(),
        })?;
    let valid_type = object
        .get("type")
        .and_then(Value::as_str)
        .is_some_and(|value| !value.is_empty());
    if valid_type {
        Ok(())
    } else {
        Err(TriFusionError::MarkInvalid {
            path: path.to_string(),
        })
    }
}

fn canonical_json_value(value: &Value) -> String {
    let mut out = String::new();
    write_canonical_json(value, &mut out);
    out
}

fn write_canonical_json(value: &Value, out: &mut String) {
    match value {
        Value::Null => out.push_str("null"),
        Value::Bool(value) => out.push_str(if *value { "true" } else { "false" }),
        Value::Number(value) => out.push_str(&value.to_string()),
        Value::String(value) => {
            out.push_str(&serde_json::to_string(value).expect("string serializes"))
        }
        Value::Array(values) => {
            out.push('[');
            for (index, value) in values.iter().enumerate() {
                if index > 0 {
                    out.push(',');
                }
                write_canonical_json(value, out);
            }
            out.push(']');
        }
        Value::Object(object) => {
            out.push('{');
            let mut keys: Vec<&str> = object.keys().map(String::as_str).collect();
            keys.sort_unstable();
            for (index, key) in keys.iter().enumerate() {
                if index > 0 {
                    out.push(',');
                }
                out.push_str(&serde_json::to_string(key).expect("object key serializes"));
                out.push(':');
                write_canonical_json(&object[*key], out);
            }
            out.push('}');
        }
    }
}

fn hex_lower(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push(HEX[(byte >> 4) as usize] as char);
        out.push(HEX[(byte & 0x0f) as usize] as char);
    }
    out
}

fn parse_hash_hex(value: &str) -> Result<TriFusionDocumentHash, String> {
    if value.len() != 64 {
        return Err("hash must be 64 hexadecimal characters".to_string());
    }

    let mut bytes = [0_u8; 32];
    let chars = value.as_bytes();
    for index in 0..32 {
        let high = hex_nibble(chars[index * 2])?;
        let low = hex_nibble(chars[index * 2 + 1])?;
        bytes[index] = (high << 4) | low;
    }
    Ok(TriFusionDocumentHash(bytes))
}

fn hex_nibble(byte: u8) -> Result<u8, String> {
    match byte {
        b'0'..=b'9' => Ok(byte - b'0'),
        b'a'..=b'f' => Ok(byte - b'a' + 10),
        b'A'..=b'F' => Ok(byte - b'A' + 10),
        _ => Err("hash contains a non-hexadecimal character".to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CANONICAL_MINIMAL: &str = r#"{"content":[{"content":[{"text":"Hello","type":"text"}],"type":"paragraph"}],"type":"doc"}"#;
    const BLOCK_DOC: &str = r#"{"content":[{"attrs":{"id":"b1"},"content":[{"text":"One","type":"text"}],"type":"paragraph"}],"type":"doc"}"#;

    fn paragraph(block_id: &str, text: &str) -> Value {
        json!({
            "type": "paragraph",
            "attrs": {
                "id": block_id,
            },
            "content": [
                {
                    "type": "text",
                    "text": text,
                },
            ],
        })
    }

    #[test]
    fn minimal_doc_round_trips_byte_equal() {
        let document = TriFusionDocument::parse_json(CANONICAL_MINIMAL).unwrap();
        assert_eq!(document.canonical_json(), CANONICAL_MINIMAL);
        assert_eq!(
            document.canonical_version(),
            TRI_FUSION_JSON_CANONICAL_VERSION
        );
    }

    #[test]
    fn canonical_json_sorts_object_keys() {
        let input = r#"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Hello"}]}]}"#;
        let document = TriFusionDocument::parse_json(input).unwrap();
        assert_eq!(document.canonical_json(), CANONICAL_MINIMAL);
    }

    #[test]
    fn hash_is_stable_for_equivalent_json() {
        let left = TriFusionDocument::parse_json(CANONICAL_MINIMAL).unwrap();
        let right = TriFusionDocument::parse_json(
            r#"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Hello"}]}]}"#,
        )
        .unwrap();
        assert_eq!(left.hash(), right.hash());
        assert_eq!(left.hash().as_bytes().len(), 32);
        assert_eq!(left.hash().to_hex().len(), 64);
    }

    #[test]
    fn hash_changes_when_text_changes() {
        let left = TriFusionDocument::parse_json(CANONICAL_MINIMAL).unwrap();
        let right = TriFusionDocument::parse_json(
            r#"{"content":[{"content":[{"text":"Goodbye","type":"text"}],"type":"paragraph"}],"type":"doc"}"#,
        )
        .unwrap();
        assert_ne!(left.hash(), right.hash());
    }

    #[test]
    fn rejects_invalid_json() {
        let error = TriFusionDocument::parse_json("{").unwrap_err();
        assert!(matches!(error, TriFusionError::InvalidJson { .. }));
    }

    #[test]
    fn rejects_non_object_root() {
        let error = TriFusionDocument::parse_json("[]").unwrap_err();
        assert_eq!(error, TriFusionError::RootNotObject);
    }

    #[test]
    fn rejects_non_doc_root() {
        let error =
            TriFusionDocument::parse_json(r#"{"content":[],"type":"paragraph"}"#).unwrap_err();
        assert_eq!(error, TriFusionError::RootTypeNotDoc);
    }

    #[test]
    fn rejects_root_without_content_array() {
        let error = TriFusionDocument::parse_json(r#"{"type":"doc"}"#).unwrap_err();
        assert_eq!(error, TriFusionError::RootContentNotArray);
    }

    #[test]
    fn rejects_non_object_child_node() {
        let error = TriFusionDocument::parse_json(r#"{"content":[1],"type":"doc"}"#).unwrap_err();
        assert_eq!(
            error,
            TriFusionError::NodeNotObject {
                path: "$.content[0]".to_string()
            }
        );
    }

    #[test]
    fn rejects_text_node_without_text() {
        let error = TriFusionDocument::parse_json(r#"{"content":[{"type":"text"}],"type":"doc"}"#)
            .unwrap_err();
        assert_eq!(
            error,
            TriFusionError::TextNodeMissingText {
                path: "$.content[0]".to_string()
            }
        );
    }

    #[test]
    fn validates_nested_marks_and_attrs() {
        let document = TriFusionDocument::parse_json(
            r#"{"content":[{"attrs":{"id":"b1"},"content":[{"marks":[{"type":"bold"}],"text":"Hello","type":"text"}],"type":"paragraph"}],"type":"doc"}"#,
        )
        .unwrap();
        assert_eq!(document.root()["type"], "doc");
    }

    #[test]
    fn hash_serializes_as_canonical_hex_string() {
        let document = TriFusionDocument::parse_json(CANONICAL_MINIMAL).unwrap();
        let encoded = serde_json::to_string(&document.hash()).unwrap();
        assert_eq!(encoded.len(), 66);
        let decoded: TriFusionDocumentHash = serde_json::from_str(&encoded).unwrap();
        assert_eq!(decoded, document.hash());
    }

    #[test]
    fn mutation_envelope_parses_grammar_shape_and_applies() {
        let document = TriFusionDocument::parse_json(BLOCK_DOC).unwrap();
        let input = format!(
            r#"{{"mutation_id":"tfm-1","document_id":"doc-1","base_document_hash":"{}","actor":{{"kind":"agent","run_id":"run-1"}},"source_format":"json","kind":"insert_block","artifact_id":"doc-1","rationale":"Add a second block.","after_block_id":"b1","block":{{"attrs":{{"id":"b2"}},"content":[{{"text":"Two","type":"text"}}],"type":"paragraph"}}}}"#,
            document.hash()
        );
        let envelope: TriFusionMutationEnvelope = serde_json::from_str(&input).unwrap();

        assert_eq!(envelope.base_document_hash, document.hash());
        assert_eq!(
            envelope.actor,
            TriFusionMutationActor::Agent {
                run_id: "run-1".to_string()
            }
        );
        assert_eq!(envelope.source_format, TriFusionSourceFormat::Json);

        let result = document.apply_mutation_envelope(envelope).unwrap();

        assert_eq!(result.witness.mutation_kind, "insert_block");
        assert_eq!(
            result.witness.provenance_status,
            TriFusionProvenanceStatus::Deferred
        );
        assert_eq!(
            result.witness.envelope_mutation_id.as_deref(),
            Some("tfm-1")
        );
        assert_eq!(result.witness.document_id.as_deref(), Some("doc-1"));
        assert_eq!(
            result.witness.actor,
            Some(TriFusionMutationActor::Agent {
                run_id: "run-1".to_string()
            })
        );
        assert_eq!(
            result.witness.source_format,
            Some(TriFusionSourceFormat::Json)
        );
        assert_eq!(
            result.witness.rationale.as_deref(),
            Some("Add a second block.")
        );
        assert_eq!(
            result.witness.touched_blocks,
            vec![BlockRef::new("doc-1", "b2")]
        );
        assert_eq!(result.witness.mutation_envelope_id, None);
        assert_eq!(result.witness.claim_graph_node_id, None);
        assert_eq!(result.witness.cognitive_dag_edge_id, None);
    }

    #[test]
    fn claim_ledger_provenance_commit_marks_witness_and_mirrors_dag() {
        let document = TriFusionDocument::parse_json(BLOCK_DOC).unwrap();
        let created_at_ms = 1_779_019_261_000;
        let input = format!(
            r#"{{"mutation_id":"tfm-provenance-commit","document_id":"doc-provenance","base_document_hash":"{}","actor":{{"kind":"agent","run_id":"run-provenance"}},"source_format":"json","kind":"insert_block","artifact_id":"doc-provenance","rationale":"Commit provenance for a model-authored block.","after_block_id":"b1","block":{{"attrs":{{"id":"b-provenance"}},"content":[{{"text":"Provenance committed","type":"text"}}],"type":"paragraph"}}}}"#,
            document.hash()
        );
        let envelope: TriFusionMutationEnvelope = serde_json::from_str(&input).unwrap();
        let result = document.apply_mutation_envelope(envelope).unwrap();
        let mut ledger = ClaimLedger::new();

        let committed = result
            .commit_claim_ledger_provenance(&mut ledger, created_at_ms)
            .unwrap();
        let verification = committed
            .verify_cognitive_dag_provenance(
                crate::cognitive_dag::dispatch::cognitive_dag_store(),
                created_at_ms,
            )
            .unwrap();

        assert_eq!(
            committed.provenance_status,
            TriFusionProvenanceStatus::Committed
        );
        assert_eq!(
            committed.mutation_envelope_id.as_deref(),
            Some("tfm-provenance-commit")
        );
        assert!(ledger.claim(&committed.provenance_claim_id()).is_some());
        assert!(ledger
            .evidence(&committed.provenance_evidence_id())
            .is_some());
        assert_eq!(
            verification.status,
            TriFusionCognitiveDagProvenanceVerificationStatus::Complete
        );
        assert!(verification.claim_node_present);
        assert!(verification.evidence_node_present);
        assert!(verification.derives_from_evidence_edge_present);
        assert_eq!(
            committed.claim_graph_node_id.as_deref(),
            Some(verification.ids.claim_node_id.as_str())
        );
        assert_eq!(
            committed.cognitive_dag_edge_id.as_deref(),
            Some(verification.ids.derives_from_evidence_edge_id.as_str())
        );

        let envelope = committed
            .pending_mutation_envelope(7, created_at_ms)
            .unwrap();
        assert_eq!(envelope.mutation_id, "tfm-provenance-commit");
        assert_eq!(envelope.run_id.as_deref(), Some("run-provenance"));
        assert_eq!(
            envelope.touched_blocks,
            vec![BlockRef::new("doc-provenance", "b-provenance")]
        );
        assert!(envelope.affects_body);
        assert!(envelope.affects_search_projection);
    }

    #[test]
    fn mutation_envelope_rejects_stale_base_hash_before_mutation() {
        let document = TriFusionDocument::parse_json(BLOCK_DOC).unwrap();
        let stale_hash = TriFusionDocumentHash::for_canonical_json("stale");
        let error = document
            .apply_mutation_envelope(TriFusionMutationEnvelope {
                mutation_id: "tfm-1".to_string(),
                document_id: "doc-1".to_string(),
                base_document_hash: stale_hash,
                actor: TriFusionMutationActor::System,
                source_format: TriFusionSourceFormat::Json,
                rationale: "Attempt stale edit.".to_string(),
                mutation: TriFusionMutation::InsertBlock {
                    artifact_id: "doc-1".to_string(),
                    after_block_id: Some("b1".to_string()),
                    block: paragraph("b2", "Two"),
                },
            })
            .unwrap_err();

        assert_eq!(
            error,
            TriFusionError::BaseDocumentHashMismatch {
                expected: document.hash(),
                actual: stale_hash,
            }
        );
        assert!(!document.canonical_json().contains(r#""id":"b2""#));
    }

    #[test]
    fn insert_block_appends_and_witnesses_touched_block() {
        let document = TriFusionDocument::parse_json(BLOCK_DOC).unwrap();
        let result = document
            .apply_mutation(TriFusionMutation::InsertBlock {
                artifact_id: "artifact-1".to_string(),
                after_block_id: None,
                block: paragraph("b2", "Two"),
            })
            .unwrap();

        assert_ne!(result.witness.before_hash, result.witness.after_hash);
        assert_eq!(result.witness.mutation_kind, "insert_block");
        assert_eq!(
            result.witness.touched_blocks,
            vec![BlockRef::new("artifact-1", "b2")]
        );
        assert_eq!(
            result.document.root()["content"].as_array().unwrap().len(),
            2
        );
    }

    #[test]
    fn mutate_block_replaces_existing_block() {
        let document = TriFusionDocument::parse_json(BLOCK_DOC).unwrap();
        let result = document
            .apply_mutation(TriFusionMutation::MutateBlock {
                artifact_id: "artifact-1".to_string(),
                block_id: "b1".to_string(),
                replacement: paragraph("b1", "Rewritten"),
            })
            .unwrap();

        assert!(result.document.canonical_json().contains("Rewritten"));
        assert!(!result.document.canonical_json().contains("One"));
        assert_eq!(
            result.witness.touched_blocks,
            vec![BlockRef::new("artifact-1", "b1")]
        );
    }

    #[test]
    fn link_block_adds_deduplicated_sorted_relation() {
        let document = TriFusionDocument::from_json_value(json!({
            "type": "doc",
            "content": [
                paragraph("b1", "One"),
                paragraph("b2", "Two"),
            ],
        }))
        .unwrap();
        let mutation = TriFusionMutation::LinkBlock {
            artifact_id: "artifact-1".to_string(),
            from_block_id: "b1".to_string(),
            to_block_id: "b2".to_string(),
            relation: "supports".to_string(),
        };

        let first = document.apply_mutation(mutation.clone()).unwrap();
        let second = first.document.apply_mutation(mutation).unwrap();
        let links = second.document.root()["content"][0]["attrs"]["links"]
            .as_array()
            .unwrap();

        assert_eq!(links.len(), 1);
        assert_eq!(links[0]["target_block_id"], "b2");
        assert_eq!(
            second.witness.touched_blocks,
            vec![
                BlockRef::new("artifact-1", "b1"),
                BlockRef::new("artifact-1", "b2"),
            ]
        );
    }

    #[test]
    fn transclude_block_inserts_reference_node() {
        let document = TriFusionDocument::parse_json(BLOCK_DOC).unwrap();
        let result = document
            .apply_mutation(TriFusionMutation::TranscludeBlock {
                artifact_id: "artifact-1".to_string(),
                after_block_id: Some("b1".to_string()),
                source_block_id: "b1".to_string(),
                transclusion_block_id: "t1".to_string(),
            })
            .unwrap();

        let content = result.document.root()["content"].as_array().unwrap();
        assert_eq!(content[1]["type"], "transclusion");
        assert_eq!(content[1]["attrs"]["source_block_id"], "b1");
        assert_eq!(
            result.witness.touched_blocks,
            vec![
                BlockRef::new("artifact-1", "b1"),
                BlockRef::new("artifact-1", "t1"),
            ]
        );
    }

    #[test]
    fn missing_mutation_target_is_rejected_without_changing_original() {
        let document = TriFusionDocument::parse_json(BLOCK_DOC).unwrap();
        let original_hash = document.hash();
        let error = document
            .apply_mutation(TriFusionMutation::MutateBlock {
                artifact_id: "artifact-1".to_string(),
                block_id: "missing".to_string(),
                replacement: paragraph("missing", "Missing"),
            })
            .unwrap_err();

        assert_eq!(
            error,
            TriFusionError::BlockNotFound {
                block_id: "missing".to_string()
            }
        );
        assert_eq!(document.hash(), original_hash);
    }

    #[test]
    fn replacement_identity_must_match_target_block() {
        let document = TriFusionDocument::parse_json(BLOCK_DOC).unwrap();
        let error = document
            .apply_mutation(TriFusionMutation::MutateBlock {
                artifact_id: "artifact-1".to_string(),
                block_id: "b1".to_string(),
                replacement: paragraph("b2", "Wrong"),
            })
            .unwrap_err();

        assert_eq!(
            error,
            TriFusionError::ReplacementBlockIdentityMismatch {
                target_block_id: "b1".to_string(),
                replacement_block_id: "b2".to_string(),
            }
        );
    }
}
