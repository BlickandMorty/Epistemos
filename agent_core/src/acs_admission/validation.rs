#![allow(unused_imports)]

use serde::{Deserialize, Serialize};

use crate::{
    artifacts::ArtifactRef,
    effect::receipt::{Capability, SigningKey},
    mutations::{
        BlockRef, MutationActor, MutationEnvelope, MutationStatus, RelationChange, Reversibility,
        Sensitivity, SourceOp,
    },
    oplog::{OpLog, OpPayload},
    provenance::ledger::{Claim, ClaimKind, ClaimStatus},
    scope_rex::{
        answer_packet::{AnswerPacket, VrmLabel},
        residency::{route as route_residency, Residency},
    },
};

use super::*;
use super::admit::*;
use super::audit_sink::*;
use super::common::*;
use super::decision::*;
use super::input::*;
use super::policy::*;
use super::proof::*;
use super::requests::*;
use super::risk::*;
use super::verdict::*;
use super::wire::*;

pub(crate) fn validate_answer_packet(packet: &AnswerPacket) -> Result<(), ACSAdmissionInputError> {
    require_non_empty(&packet.id.0, "answer_packet.id")?;
    for (idx, claim) in packet.claims.iter().enumerate() {
        require_non_empty(&claim.id.0, "answer_packet.claims.id")?;
        require_non_empty(&claim.text, "answer_packet.claims.text")?;
        require_non_negative_ms(claim.created_at_ms, "answer_packet.claims.created_at_ms")?;
        if packet.claims[..idx]
            .iter()
            .any(|existing| existing.id == claim.id)
        {
            return Err(ACSAdmissionInputError::Forged {
                field: "answer_packet.claims.id",
            });
        }
    }
    for signal in &packet.residency_signals {
        require_normalized_signal(
            signal.safety_risk,
            "answer_packet.residency_signals.safety_risk",
        )?;
        require_normalized_signal(signal.privacy, "answer_packet.residency_signals.privacy")?;
        require_normalized_signal(
            signal.verification_score,
            "answer_packet.residency_signals.verification_score",
        )?;
        require_finite_signal(signal.gain, "answer_packet.residency_signals.gain")?;
        require_normalized_signal(
            signal.forgetting,
            "answer_packet.residency_signals.forgetting",
        )?;
    }
    require_answer_packet_label_consistency(packet)?;
    require_non_empty(
        &packet.witnessed_state_ref.0,
        "answer_packet.witnessed_state_ref",
    )?;
    require_optional_non_empty(
        packet.semantic_delta_ref.as_ref().map(|id| id.0.as_str()),
        "answer_packet.semantic_delta_ref",
    )?;
    if !packet.attention_mode_claims_are_consistent() {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.attention_mode",
        });
    }
    require_non_empty(
        &packet.mutation_envelope_ref.0,
        "answer_packet.mutation_envelope_ref",
    )
}

pub(crate) fn require_answer_packet_label_consistency(
    packet: &AnswerPacket,
) -> Result<(), ACSAdmissionInputError> {
    let has_quarantine_signal = packet
        .residency_signals
        .iter()
        .any(|signal| route_residency(signal) == Residency::Quarantine);

    if packet.ui_label == VrmLabel::Blocked && !has_quarantine_signal {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.ui_label == VrmLabel::Blocked
        && packet.claims.iter().any(is_active_positive_answer_claim)
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.ui_label != VrmLabel::Blocked && has_quarantine_signal {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.ui_label == VrmLabel::Speculative
        && !packet.claims.iter().any(is_active_speculative_answer_claim)
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.ui_label == VrmLabel::Speculative
        && packet
            .claims
            .iter()
            .any(is_active_non_speculative_answer_claim)
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.ui_label == VrmLabel::Speculative
        && packet.claims.iter().any(is_non_active_gap_answer_claim)
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.ui_label == VrmLabel::PlausibleButUnverified {
        if !packet.claims.iter().any(is_active_plausible_answer_claim) {
            return Err(ACSAdmissionInputError::Forged {
                field: "answer_packet.ui_label",
            });
        }
        if packet
            .claims
            .iter()
            .any(is_active_non_plausible_answer_claim)
        {
            return Err(ACSAdmissionInputError::Forged {
                field: "answer_packet.ui_label",
            });
        }
        if packet.claims.iter().any(is_non_active_gap_answer_claim) {
            return Err(ACSAdmissionInputError::Forged {
                field: "answer_packet.ui_label",
            });
        }
    }

    if packet.ui_label != VrmLabel::Verified {
        return Ok(());
    }

    if packet
        .residency_signals
        .iter()
        .any(|signal| signal.verification_score < 0.5)
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.claims.iter().any(is_active_unverified_answer_claim) {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.claims.iter().any(is_non_active_gap_answer_claim) {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet
        .claims
        .iter()
        .any(is_non_active_verifying_answer_claim)
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        });
    }

    if packet.claims.iter().any(is_active_verifying_answer_claim) {
        Ok(())
    } else {
        Err(ACSAdmissionInputError::Forged {
            field: "answer_packet.ui_label",
        })
    }
}

pub(crate) fn is_active_verifying_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim)
        && matches!(
            claim.kind,
            ClaimKind::Empirical | ClaimKind::Mathematical | ClaimKind::CodeInvariant
        )
}

pub(crate) fn is_non_active_verifying_answer_claim(claim: &Claim) -> bool {
    !is_active_answer_claim(claim)
        && matches!(
            claim.kind,
            ClaimKind::Empirical | ClaimKind::Mathematical | ClaimKind::CodeInvariant
        )
}

pub(crate) fn is_active_positive_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim)
        && matches!(
            claim.kind,
            ClaimKind::Empirical
                | ClaimKind::Mathematical
                | ClaimKind::CodeInvariant
                | ClaimKind::Causal
                | ClaimKind::Speculative
        )
}

pub(crate) fn is_active_speculative_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim) && claim.kind == ClaimKind::Speculative
}

pub(crate) fn is_active_plausible_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim) && matches!(claim.kind, ClaimKind::Empirical | ClaimKind::Causal)
}

pub(crate) fn is_active_non_speculative_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim)
        && matches!(
            claim.kind,
            ClaimKind::Empirical
                | ClaimKind::Mathematical
                | ClaimKind::CodeInvariant
                | ClaimKind::Causal
        )
}

pub(crate) fn is_active_non_plausible_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim)
        && matches!(
            claim.kind,
            ClaimKind::Mathematical | ClaimKind::CodeInvariant | ClaimKind::Speculative
        )
}

pub(crate) fn is_non_active_gap_answer_claim(claim: &Claim) -> bool {
    !is_active_answer_claim(claim)
        && matches!(
            claim.kind,
            ClaimKind::Empirical
                | ClaimKind::Mathematical
                | ClaimKind::CodeInvariant
                | ClaimKind::Causal
                | ClaimKind::Speculative
        )
}

pub(crate) fn is_active_unverified_answer_claim(claim: &Claim) -> bool {
    is_active_answer_claim(claim)
        && matches!(claim.kind, ClaimKind::Causal | ClaimKind::Speculative)
}

pub(crate) fn is_active_answer_claim(claim: &Claim) -> bool {
    claim.status == ClaimStatus::Active
}

pub(crate) fn require_finite_signal(value: f32, field: &'static str) -> Result<(), ACSAdmissionInputError> {
    if value.is_finite() {
        Ok(())
    } else {
        Err(ACSAdmissionInputError::Forged { field })
    }
}

pub(crate) fn require_normalized_signal(
    value: f32,
    field: &'static str,
) -> Result<(), ACSAdmissionInputError> {
    require_finite_signal(value, field)?;
    if (0.0..=1.0).contains(&value) {
        Ok(())
    } else {
        Err(ACSAdmissionInputError::Forged { field })
    }
}

pub(crate) fn validate_mutation_envelope(envelope: &MutationEnvelope) -> Result<(), ACSAdmissionInputError> {
    require_non_empty(&envelope.mutation_id, "mutation_envelope.mutation_id")?;
    require_optional_non_empty(envelope.run_id.as_deref(), "mutation_envelope.run_id")?;
    require_optional_non_empty(
        envelope.caused_by_event_id.as_deref(),
        "mutation_envelope.caused_by_event_id",
    )?;
    require_optional_non_empty(
        envelope.approval_id.as_deref(),
        "mutation_envelope.approval_id",
    )?;
    require_non_negative_ms(envelope.created_at_ms, "mutation_envelope.created_at_ms")?;
    if let Some(committed_at_ms) = envelope.committed_at_ms {
        require_non_negative_ms(committed_at_ms, "mutation_envelope.committed_at_ms")?;
        if committed_at_ms < envelope.created_at_ms {
            return Err(ACSAdmissionInputError::Forged {
                field: "mutation_envelope.committed_at_ms",
            });
        }
    }
    if matches!(
        envelope.status,
        MutationStatus::Pending | MutationStatus::Failed
    ) && envelope.committed_at_ms.is_some()
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "mutation_envelope.committed_at_ms",
        });
    }
    if matches!(
        envelope.status,
        MutationStatus::Committed | MutationStatus::Reverted
    ) && envelope.committed_at_ms.is_none()
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "mutation_envelope.committed_at_ms",
        });
    }
    if envelope.status == MutationStatus::Reverted
        && envelope.reversibility == Reversibility::Irreversible
    {
        return Err(ACSAdmissionInputError::Forged {
            field: "mutation_envelope.reversibility",
        });
    }
    if envelope.status != MutationStatus::Pending && envelope.integrity_hash.is_empty() {
        return Err(ACSAdmissionInputError::Forged {
            field: "mutation_envelope.integrity_hash",
        });
    }
    if !envelope.integrity_hash.is_empty() {
        require_lowercase_hex_digest(
            &envelope.integrity_hash,
            MUTATION_INTEGRITY_HASH_BYTES,
            "mutation_envelope.integrity_hash",
        )?;
    }
    if envelope.schema_version == 0 {
        return Err(ACSAdmissionInputError::Forged {
            field: "mutation_envelope.schema_version",
        });
    }
    validate_mutation_actor(&envelope.actor)?;
    if let MutationActor::Agent {
        run_id: actor_run_id,
    } = &envelope.actor
    {
        match envelope.run_id.as_deref() {
            Some(envelope_run_id) if envelope_run_id == actor_run_id => {}
            _ => {
                return Err(ACSAdmissionInputError::Forged {
                    field: "mutation_envelope.run_id",
                });
            }
        }
    }
    validate_mutation_source_op(&envelope.op)?;
    validate_mutation_touched_artifacts(&envelope.touched_artifacts)?;
    validate_mutation_touched_blocks(&envelope.touched_blocks)?;
    validate_mutation_relation_changes(&envelope.relation_changes)?;
    Ok(())
}

pub(crate) fn validate_mutation_touched_artifacts(
    artifacts: &[ArtifactRef],
) -> Result<(), ACSAdmissionInputError> {
    for (idx, artifact) in artifacts.iter().enumerate() {
        require_non_empty(
            &artifact.id,
            "mutation_envelope.touched_artifacts.artifact_id",
        )?;
        require_optional_non_empty(
            artifact.title.as_deref(),
            "mutation_envelope.touched_artifacts.title",
        )?;
        if artifacts[..idx]
            .iter()
            .any(|existing| existing.id == artifact.id)
        {
            return Err(ACSAdmissionInputError::Forged {
                field: "mutation_envelope.touched_artifacts.artifact_id",
            });
        }
    }
    Ok(())
}

pub(crate) fn validate_mutation_touched_blocks(blocks: &[BlockRef]) -> Result<(), ACSAdmissionInputError> {
    for (idx, block) in blocks.iter().enumerate() {
        require_non_empty(
            &block.artifact_id,
            "mutation_envelope.touched_blocks.artifact_id",
        )?;
        require_non_empty(&block.block_id, "mutation_envelope.touched_blocks.block_id")?;
        if blocks[..idx].iter().any(|existing| {
            existing.artifact_id == block.artifact_id && existing.block_id == block.block_id
        }) {
            return Err(ACSAdmissionInputError::Forged {
                field: "mutation_envelope.touched_blocks.block_id",
            });
        }
    }
    Ok(())
}

pub(crate) fn validate_mutation_relation_changes(
    changes: &[RelationChange],
) -> Result<(), ACSAdmissionInputError> {
    for (idx, change) in changes.iter().enumerate() {
        match change {
            RelationChange::Added {
                from_id,
                to_id,
                label,
            }
            | RelationChange::Removed {
                from_id,
                to_id,
                label,
            } => {
                validate_mutation_relation_endpoints(from_id, to_id)?;
                require_non_empty(label, "mutation_envelope.relation_changes.label")?;
            }
            RelationChange::Updated {
                from_id,
                to_id,
                old_label,
                new_label,
            } => {
                validate_mutation_relation_endpoints(from_id, to_id)?;
                require_non_empty(old_label, "mutation_envelope.relation_changes.old_label")?;
                require_non_empty(new_label, "mutation_envelope.relation_changes.new_label")?;
                if old_label == new_label {
                    return Err(ACSAdmissionInputError::Forged {
                        field: "mutation_envelope.relation_changes.new_label",
                    });
                }
            }
        }
        if changes[..idx].iter().any(|existing| {
            relation_change_matches(existing, change) || relation_change_conflicts(existing, change)
        }) {
            return Err(ACSAdmissionInputError::Forged {
                field: "mutation_envelope.relation_changes",
            });
        }
    }
    Ok(())
}

pub(crate) fn relation_change_matches(left: &RelationChange, right: &RelationChange) -> bool {
    match (left, right) {
        (
            RelationChange::Added {
                from_id: left_from_id,
                to_id: left_to_id,
                label: left_label,
            },
            RelationChange::Added {
                from_id: right_from_id,
                to_id: right_to_id,
                label: right_label,
            },
        )
        | (
            RelationChange::Removed {
                from_id: left_from_id,
                to_id: left_to_id,
                label: left_label,
            },
            RelationChange::Removed {
                from_id: right_from_id,
                to_id: right_to_id,
                label: right_label,
            },
        ) => {
            left_from_id == right_from_id && left_to_id == right_to_id && left_label == right_label
        }
        (
            RelationChange::Updated {
                from_id: left_from_id,
                to_id: left_to_id,
                old_label: left_old_label,
                new_label: left_new_label,
            },
            RelationChange::Updated {
                from_id: right_from_id,
                to_id: right_to_id,
                old_label: right_old_label,
                new_label: right_new_label,
            },
        ) => {
            left_from_id == right_from_id
                && left_to_id == right_to_id
                && left_old_label == right_old_label
                && left_new_label == right_new_label
        }
        _ => false,
    }
}

pub(crate) fn relation_change_conflicts(left: &RelationChange, right: &RelationChange) -> bool {
    match (left, right) {
        (
            RelationChange::Added {
                from_id: left_from_id,
                to_id: left_to_id,
                label: left_label,
            },
            RelationChange::Removed {
                from_id: right_from_id,
                to_id: right_to_id,
                label: right_label,
            },
        )
        | (
            RelationChange::Removed {
                from_id: left_from_id,
                to_id: left_to_id,
                label: left_label,
            },
            RelationChange::Added {
                from_id: right_from_id,
                to_id: right_to_id,
                label: right_label,
            },
        ) => {
            left_from_id == right_from_id && left_to_id == right_to_id && left_label == right_label
        }
        (
            RelationChange::Updated {
                from_id: left_from_id,
                to_id: left_to_id,
                old_label: left_old_label,
                new_label: left_new_label,
            },
            RelationChange::Added {
                from_id: right_from_id,
                to_id: right_to_id,
                label: right_label,
            },
        ) => {
            left_from_id == right_from_id
                && left_to_id == right_to_id
                && (left_new_label == right_label || left_old_label == right_label)
        }
        (
            RelationChange::Added {
                from_id: left_from_id,
                to_id: left_to_id,
                label: left_label,
            },
            RelationChange::Updated {
                from_id: right_from_id,
                to_id: right_to_id,
                old_label: right_old_label,
                new_label: right_new_label,
            },
        ) => {
            left_from_id == right_from_id
                && left_to_id == right_to_id
                && (left_label == right_new_label || left_label == right_old_label)
        }
        (
            RelationChange::Updated {
                from_id: left_from_id,
                to_id: left_to_id,
                old_label: left_old_label,
                new_label: left_new_label,
            },
            RelationChange::Removed {
                from_id: right_from_id,
                to_id: right_to_id,
                label: right_label,
            },
        ) => {
            left_from_id == right_from_id
                && left_to_id == right_to_id
                && (left_old_label == right_label || left_new_label == right_label)
        }
        (
            RelationChange::Removed {
                from_id: left_from_id,
                to_id: left_to_id,
                label: left_label,
            },
            RelationChange::Updated {
                from_id: right_from_id,
                to_id: right_to_id,
                old_label: right_old_label,
                new_label: right_new_label,
            },
        ) => {
            left_from_id == right_from_id
                && left_to_id == right_to_id
                && (left_label == right_old_label || left_label == right_new_label)
        }
        (
            RelationChange::Updated {
                from_id: left_from_id,
                to_id: left_to_id,
                old_label: left_old_label,
                new_label: left_new_label,
            },
            RelationChange::Updated {
                from_id: right_from_id,
                to_id: right_to_id,
                old_label: right_old_label,
                new_label: right_new_label,
            },
        ) => {
            left_from_id == right_from_id
                && left_to_id == right_to_id
                && (left_old_label == right_old_label
                    || left_new_label == right_old_label
                    || left_old_label == right_new_label
                    || left_new_label == right_new_label)
        }
        _ => false,
    }
}

pub(crate) fn validate_mutation_relation_endpoints(
    from_id: &str,
    to_id: &str,
) -> Result<(), ACSAdmissionInputError> {
    require_non_empty(from_id, "mutation_envelope.relation_changes.from_id")?;
    require_non_empty(to_id, "mutation_envelope.relation_changes.to_id")
}

pub(crate) fn validate_mutation_actor(actor: &MutationActor) -> Result<(), ACSAdmissionInputError> {
    match actor {
        MutationActor::Agent { run_id } => {
            require_non_empty(run_id, "mutation_envelope.actor.run_id")?;
        }
        MutationActor::User | MutationActor::System => {}
    }
    Ok(())
}

pub(crate) fn validate_mutation_source_op(op: &SourceOp) -> Result<(), ACSAdmissionInputError> {
    match op {
        SourceOp::ArtifactCreate {
            artifact_id,
            artifact_kind,
        } => {
            require_non_empty(artifact_id, "mutation_envelope.op.artifact_id")?;
            require_non_empty(artifact_kind, "mutation_envelope.op.artifact_kind")?;
        }
        SourceOp::ArtifactUpdate { artifact_id } | SourceOp::ArtifactDelete { artifact_id } => {
            require_non_empty(artifact_id, "mutation_envelope.op.artifact_id")?;
        }
        SourceOp::Other { label } => {
            require_non_empty(label, "mutation_envelope.op.label")?;
        }
        SourceOp::GraphMutation => {}
    }
    Ok(())
}
