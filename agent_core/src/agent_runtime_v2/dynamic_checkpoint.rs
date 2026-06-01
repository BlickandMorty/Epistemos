//! Dynamic-compute checkpoint manifests for System G routes.
//!
//! These are metadata-only witnesses. They do not pause kernels, mutate model
//! state, wake model bytes, or execute inference. A checkpoint exists only when
//! a route-affecting dynamic-compute decision is already visible through a
//! RunEventLog event id and bound to the `F-DynamicCompute-Checkpoint`
//! falsifier.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;

use super::run_event_log::{RunEventEntry, RunEventLog};
use crate::uas::construction_card::{pro_status_preimage, product_build_preimage};
use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const DYNAMIC_COMPUTE_CHECKPOINT_FALSIFIER_ID: &str = "F-DynamicCompute-Checkpoint";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DynamicComputeCheckpointKind {
    EarlyExit,
    SelfSpeculative,
    DepthBudget,
    KvRestore,
    AdapterSwap,
    EidosInterrupt,
    VerifierRepair,
    ControllerSsm,
}

impl DynamicComputeCheckpointKind {
    pub const fn wire_tag(self) -> &'static str {
        match self {
            Self::EarlyExit => "early_exit",
            Self::SelfSpeculative => "self_speculative",
            Self::DepthBudget => "depth_budget",
            Self::KvRestore => "kv_restore",
            Self::AdapterSwap => "adapter_swap",
            Self::EidosInterrupt => "eidos_interrupt",
            Self::VerifierRepair => "verifier_repair",
            Self::ControllerSsm => "controller_ssm",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct DynamicComputeCheckpoint {
    pub checkpoint_address: UasAddress,
    pub checkpoint_kind: DynamicComputeCheckpointKind,
    pub trigger: String,
    pub active_units_before: Vec<UasAddress>,
    pub active_units_after: Vec<UasAddress>,
    pub verifier_reason: String,
    pub latency_budget_remaining_ms: u64,
    pub run_event_id: String,
    pub verifier_stack: Vec<String>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
}

impl DynamicComputeCheckpoint {
    #[allow(clippy::too_many_arguments)]
    pub fn from_visible_run_event(
        checkpoint_kind: DynamicComputeCheckpointKind,
        trigger: impl Into<String>,
        active_units_before: Vec<UasAddress>,
        active_units_after: Vec<UasAddress>,
        verifier_reason: impl Into<String>,
        latency_budget_remaining_ms: u64,
        run_event_log: &RunEventLog,
        run_event_ordinal: u64,
        verifier_stack: Vec<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        created_at_ms: u64,
    ) -> Result<Self, DynamicComputeCheckpointError> {
        validate_visible_run_event(run_event_log, run_event_ordinal)?;
        Self::new(
            checkpoint_kind,
            trigger,
            active_units_before,
            active_units_after,
            verifier_reason,
            latency_budget_remaining_ms,
            format!("run_event_log:{run_event_ordinal}"),
            verifier_stack,
            product_build,
            pro_status,
            created_at_ms,
        )
    }

    #[allow(clippy::too_many_arguments)]
    fn new(
        checkpoint_kind: DynamicComputeCheckpointKind,
        trigger: impl Into<String>,
        active_units_before: Vec<UasAddress>,
        active_units_after: Vec<UasAddress>,
        verifier_reason: impl Into<String>,
        latency_budget_remaining_ms: u64,
        run_event_id: impl Into<String>,
        verifier_stack: Vec<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        created_at_ms: u64,
    ) -> Result<Self, DynamicComputeCheckpointError> {
        let trigger = trigger.into();
        let verifier_reason = verifier_reason.into();
        let run_event_id = run_event_id.into();

        validate_text("trigger", &trigger)?;
        validate_text("verifier_reason", &verifier_reason)?;
        validate_text("run_event_id", &run_event_id)?;
        validate_run_event_id(&run_event_id)?;
        validate_units("active_units_before", &active_units_before)?;
        validate_units("active_units_after", &active_units_after)?;
        validate_verifier_stack(&verifier_stack)?;
        validate_build_status(&product_build, &pro_status)?;

        let mut active_units_before = active_units_before;
        let mut active_units_after = active_units_after;
        active_units_before.sort_by_key(ToString::to_string);
        active_units_after.sort_by_key(ToString::to_string);

        let checkpoint_address = Self::address(
            checkpoint_kind,
            &trigger,
            &active_units_before,
            &active_units_after,
            &verifier_reason,
            latency_budget_remaining_ms,
            &run_event_id,
            &verifier_stack,
            &product_build,
            &pro_status,
            created_at_ms,
        );

        Ok(Self {
            checkpoint_address,
            checkpoint_kind,
            trigger,
            active_units_before,
            active_units_after,
            verifier_reason,
            latency_budget_remaining_ms,
            run_event_id,
            verifier_stack,
            product_build,
            pro_status,
        })
    }

    #[allow(clippy::too_many_arguments)]
    fn address(
        checkpoint_kind: DynamicComputeCheckpointKind,
        trigger: &str,
        active_units_before: &[UasAddress],
        active_units_after: &[UasAddress],
        verifier_reason: &str,
        latency_budget_remaining_ms: u64,
        run_event_id: &str,
        verifier_stack: &[String],
        product_build: &ProductBuild,
        pro_status: &ProStatus,
        created_at_ms: u64,
    ) -> UasAddress {
        let mut preimage = String::new();
        preimage.push_str("dynamic_compute_checkpoint_v1\n");
        preimage.push_str(checkpoint_kind.wire_tag());
        preimage.push('\n');
        push_len_prefixed(&mut preimage, "trigger", trigger);
        push_units(&mut preimage, "before", active_units_before);
        push_units(&mut preimage, "after", active_units_after);
        push_len_prefixed(&mut preimage, "verifier_reason", verifier_reason);
        preimage.push_str(&format!(
            "latency_budget_remaining_ms:{latency_budget_remaining_ms}\n"
        ));
        push_len_prefixed(&mut preimage, "run_event_id", run_event_id);
        push_list(&mut preimage, "verifier", verifier_stack);
        preimage.push_str(product_build_preimage(product_build));
        preimage.push('\n');
        preimage.push_str(pro_status_preimage(pro_status));
        preimage.push('\n');

        UasAddress::new(UasKind::AgentTrace, preimage.as_bytes(), created_at_ms)
    }
}

fn push_units(preimage: &mut String, label: &str, units: &[UasAddress]) {
    preimage.push_str(label);
    preimage.push(':');
    preimage.push_str(&units.len().to_string());
    preimage.push('\n');
    for unit in units {
        preimage.push_str(&unit.to_string());
        preimage.push('\n');
    }
}

fn push_list(preimage: &mut String, label: &str, values: &[String]) {
    preimage.push_str(label);
    preimage.push(':');
    preimage.push_str(&values.len().to_string());
    preimage.push('\n');
    for value in values {
        push_len_prefixed(preimage, label, value);
    }
}

fn push_len_prefixed(preimage: &mut String, label: &str, value: &str) {
    preimage.push_str(label);
    preimage.push(':');
    preimage.push_str(&value.len().to_string());
    preimage.push(':');
    preimage.push_str(value);
    preimage.push('\n');
}

fn validate_text(field: &'static str, value: &str) -> Result<(), DynamicComputeCheckpointError> {
    if value.trim().is_empty() {
        return Err(DynamicComputeCheckpointError::MissingField { field });
    }
    if value.trim() != value {
        return Err(DynamicComputeCheckpointError::FieldHasSurroundingWhitespace { field });
    }
    if value.chars().any(char::is_control) {
        return Err(DynamicComputeCheckpointError::FieldContainsControlCharacter { field });
    }
    Ok(())
}

fn validate_run_event_id(run_event_id: &str) -> Result<(), DynamicComputeCheckpointError> {
    let Some(ordinal) = run_event_id.strip_prefix("run_event_log:") else {
        return Err(DynamicComputeCheckpointError::InvalidRunEventId {
            run_event_id: run_event_id.to_string(),
        });
    };
    let Ok(parsed) = ordinal.parse::<u64>() else {
        return Err(DynamicComputeCheckpointError::InvalidRunEventId {
            run_event_id: run_event_id.to_string(),
        });
    };
    if parsed.to_string() != ordinal {
        return Err(DynamicComputeCheckpointError::InvalidRunEventId {
            run_event_id: run_event_id.to_string(),
        });
    }
    Ok(())
}

fn validate_visible_run_event(
    run_event_log: &RunEventLog,
    ordinal: u64,
) -> Result<(), DynamicComputeCheckpointError> {
    let Ok(index) = usize::try_from(ordinal) else {
        return Err(DynamicComputeCheckpointError::MissingRunEventLogOrdinal { ordinal });
    };
    let Some(entry) = run_event_log.entries().get(index) else {
        return Err(DynamicComputeCheckpointError::MissingRunEventLogOrdinal { ordinal });
    };
    let actual = entry.ordinal();
    if actual != ordinal {
        return Err(DynamicComputeCheckpointError::RunEventLogOrdinalMismatch {
            requested: ordinal,
            actual,
        });
    }
    match entry {
        RunEventEntry::Event { .. } => Ok(()),
        RunEventEntry::SealedMutation { .. } | RunEventEntry::LedgerSnapshot { .. } => {
            Err(DynamicComputeCheckpointError::RunEventLogOrdinalIsNotEvent { ordinal })
        }
    }
}

fn validate_units(
    field: &'static str,
    units: &[UasAddress],
) -> Result<(), DynamicComputeCheckpointError> {
    if units.is_empty() {
        return Err(DynamicComputeCheckpointError::MissingActiveUnits { field });
    }
    let mut seen = HashSet::with_capacity(units.len());
    for unit in units {
        if !seen.insert(unit.to_string()) {
            return Err(DynamicComputeCheckpointError::DuplicateActiveUnit {
                field,
                address: unit.to_string(),
            });
        }
    }
    Ok(())
}

fn validate_verifier_stack(verifier_stack: &[String]) -> Result<(), DynamicComputeCheckpointError> {
    if verifier_stack.is_empty() {
        return Err(DynamicComputeCheckpointError::MissingVerifier);
    }
    let mut seen = HashSet::with_capacity(verifier_stack.len());
    let mut has_dynamic_checkpoint_falsifier = false;
    for verifier in verifier_stack {
        validate_text("verifier_stack", verifier)?;
        if !seen.insert(verifier.as_str()) {
            return Err(DynamicComputeCheckpointError::DuplicateVerifier {
                verifier: verifier.clone(),
            });
        }
        if verifier == DYNAMIC_COMPUTE_CHECKPOINT_FALSIFIER_ID {
            has_dynamic_checkpoint_falsifier = true;
        }
    }
    if !has_dynamic_checkpoint_falsifier {
        return Err(DynamicComputeCheckpointError::MissingDynamicCheckpointFalsifier);
    }
    Ok(())
}

fn validate_build_status(
    product_build: &ProductBuild,
    pro_status: &ProStatus,
) -> Result<(), DynamicComputeCheckpointError> {
    if product_build == &ProductBuild::Mas {
        return Err(DynamicComputeCheckpointError::ProductBuildStatusMismatch);
    }
    if product_build == &ProductBuild::Pro && pro_status == &ProStatus::Live {
        return Err(DynamicComputeCheckpointError::ProductBuildStatusMismatch);
    }
    Ok(())
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DynamicComputeCheckpointError {
    MissingField {
        field: &'static str,
    },
    FieldHasSurroundingWhitespace {
        field: &'static str,
    },
    FieldContainsControlCharacter {
        field: &'static str,
    },
    MissingActiveUnits {
        field: &'static str,
    },
    DuplicateActiveUnit {
        field: &'static str,
        address: String,
    },
    MissingVerifier,
    DuplicateVerifier {
        verifier: String,
    },
    MissingDynamicCheckpointFalsifier,
    InvalidRunEventId {
        run_event_id: String,
    },
    MissingRunEventLogOrdinal {
        ordinal: u64,
    },
    RunEventLogOrdinalIsNotEvent {
        ordinal: u64,
    },
    RunEventLogOrdinalMismatch {
        requested: u64,
        actual: u64,
    },
    ProductBuildStatusMismatch,
}

impl std::fmt::Display for DynamicComputeCheckpointError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingField { field } => write!(f, "{field} is required"),
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "{field} must not contain leading or trailing whitespace")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "{field} must not contain control characters")
            }
            Self::MissingActiveUnits { field } => {
                write!(f, "{field} must contain at least one UAS address")
            }
            Self::DuplicateActiveUnit { field, address } => {
                write!(f, "{field} contains duplicate active unit {address}")
            }
            Self::MissingVerifier => write!(f, "at least one verifier is required"),
            Self::DuplicateVerifier { verifier } => {
                write!(f, "dynamic checkpoint verifier was duplicated: {verifier}")
            }
            Self::MissingDynamicCheckpointFalsifier => write!(
                f,
                "dynamic checkpoints must bind F-DynamicCompute-Checkpoint in verifier_stack"
            ),
            Self::InvalidRunEventId { run_event_id } => write!(
                f,
                "dynamic checkpoints must bind a concrete RunEventLog ordinal as run_event_log:<ordinal>, got {run_event_id}"
            ),
            Self::MissingRunEventLogOrdinal { ordinal } => write!(
                f,
                "dynamic checkpoint run_event_log:{ordinal} does not exist in the bound RunEventLog"
            ),
            Self::RunEventLogOrdinalIsNotEvent { ordinal } => write!(
                f,
                "dynamic checkpoint run_event_log:{ordinal} must refer to an AgentEvent row"
            ),
            Self::RunEventLogOrdinalMismatch { requested, actual } => write!(
                f,
                "dynamic checkpoint requested run_event_log:{requested}, but the entry carried ordinal {actual}"
            ),
            Self::ProductBuildStatusMismatch => write!(
                f,
                "dynamic checkpoint ProductBuild and ProStatus are inconsistent"
            ),
        }
    }
}

impl std::error::Error for DynamicComputeCheckpointError {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::agent_runtime_v2::{AgentEvent, RunEventLog};
    use crate::cognitive_dag::node::Hash;

    fn unit(label: &[u8]) -> UasAddress {
        UasAddress::new(UasKind::ModelComponent, label, 7)
    }

    fn verifier_stack() -> Vec<String> {
        vec![DYNAMIC_COMPUTE_CHECKPOINT_FALSIFIER_ID.to_string()]
    }

    fn checkpoint() -> Result<DynamicComputeCheckpoint, DynamicComputeCheckpointError> {
        DynamicComputeCheckpoint::new(
            DynamicComputeCheckpointKind::EidosInterrupt,
            "missing closed citation evidence",
            vec![unit(b"controller"), unit(b"kv-page-before")],
            vec![unit(b"controller"), unit(b"kv-page-after")],
            "Eidos requested evidence repair before answer emission",
            2_500,
            "run_event_log:42",
            verifier_stack(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            99,
        )
    }

    #[test]
    fn checkpoint_roundtrips_and_binds_visible_run_event() {
        let checkpoint = checkpoint().expect("valid checkpoint should build");

        assert_eq!(
            checkpoint.checkpoint_kind,
            DynamicComputeCheckpointKind::EidosInterrupt
        );
        assert_eq!(checkpoint.product_build, ProductBuild::Pro);
        assert_eq!(checkpoint.pro_status, ProStatus::ResearchCandidate);
        assert_eq!(checkpoint.run_event_id, "run_event_log:42");
        assert_eq!(checkpoint.checkpoint_address.kind, UasKind::AgentTrace);
        assert!(checkpoint
            .verifier_stack
            .contains(&DYNAMIC_COMPUTE_CHECKPOINT_FALSIFIER_ID.to_string()));

        let json = serde_json::to_string(&checkpoint).expect("serialize checkpoint");
        let back: DynamicComputeCheckpoint =
            serde_json::from_str(&json).expect("deserialize checkpoint");
        assert_eq!(back, checkpoint);
    }

    #[test]
    fn checkpoint_requires_run_event_visibility() {
        let err = DynamicComputeCheckpoint::new(
            DynamicComputeCheckpointKind::VerifierRepair,
            "citation verifier failed",
            vec![unit(b"before")],
            vec![unit(b"after")],
            "bounded verifier repair must be visible",
            1_000,
            "",
            verifier_stack(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            DynamicComputeCheckpointError::MissingField {
                field: "run_event_id"
            }
        );
    }

    #[test]
    fn checkpoint_rejects_unbound_run_event_ids() {
        for run_event_id in [
            "status-row:42",
            "run_event_log:",
            "run_event_log:latest",
            "run_event_log:42/extra",
        ] {
            let err = DynamicComputeCheckpoint::new(
                DynamicComputeCheckpointKind::VerifierRepair,
                "citation verifier failed",
                vec![unit(b"before")],
                vec![unit(b"after")],
                "bounded verifier repair must be visible",
                1_000,
                run_event_id,
                verifier_stack(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                99,
            )
            .unwrap_err();

            assert_eq!(
                err,
                DynamicComputeCheckpointError::InvalidRunEventId {
                    run_event_id: run_event_id.to_string()
                }
            );
        }
    }

    #[test]
    fn checkpoint_rejects_noncanonical_run_event_ordinals() {
        let err = DynamicComputeCheckpoint::new(
            DynamicComputeCheckpointKind::VerifierRepair,
            "citation verifier failed",
            vec![unit(b"before")],
            vec![unit(b"after")],
            "bounded verifier repair must bind one canonical event ordinal",
            1_000,
            "run_event_log:00042",
            verifier_stack(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            DynamicComputeCheckpointError::InvalidRunEventId {
                run_event_id: "run_event_log:00042".to_string()
            }
        );
    }

    #[test]
    fn checkpoint_requires_dynamic_compute_falsifier() {
        let err = DynamicComputeCheckpoint::new(
            DynamicComputeCheckpointKind::DepthBudget,
            "depth budget reached",
            vec![unit(b"before")],
            vec![unit(b"after")],
            "budget gate must be admitted before output changes",
            1_000,
            "run_event_log:7",
            vec!["F-AppColdStore-Layout".to_string()],
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            DynamicComputeCheckpointError::MissingDynamicCheckpointFalsifier
        );
    }

    #[test]
    fn checkpoint_rejects_duplicate_active_units() {
        let duplicate = unit(b"same-unit");
        let err = DynamicComputeCheckpoint::new(
            DynamicComputeCheckpointKind::AdapterSwap,
            "adapter family switch",
            vec![duplicate.clone(), duplicate.clone()],
            vec![unit(b"after")],
            "adapter swap must declare the support set it changed",
            1_000,
            "run_event_log:8",
            verifier_stack(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            DynamicComputeCheckpointError::DuplicateActiveUnit {
                field: "active_units_before",
                address: duplicate.to_string()
            }
        );
    }

    #[test]
    fn checkpoint_keeps_research_status_out_of_mas() {
        let err = DynamicComputeCheckpoint::new(
            DynamicComputeCheckpointKind::SelfSpeculative,
            "shallow draft proposed deeper verify",
            vec![unit(b"before")],
            vec![unit(b"after")],
            "self-speculative routing remains Pro Research until falsified",
            1_000,
            "run_event_log:9",
            verifier_stack(),
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            DynamicComputeCheckpointError::ProductBuildStatusMismatch
        );
    }

    #[test]
    fn checkpoint_keeps_gated_dynamic_compute_out_of_mas() {
        let err = DynamicComputeCheckpoint::new(
            DynamicComputeCheckpointKind::KvRestore,
            "restore candidate KV pages before generation",
            vec![unit(b"controller")],
            vec![unit(b"controller"), unit(b"kv-page")],
            "KV restore checkpoints remain Pro-gated until runtime falsifiers pass",
            1_000,
            "run_event_log:9",
            verifier_stack(),
            ProductBuild::Mas,
            ProStatus::Gated,
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            DynamicComputeCheckpointError::ProductBuildStatusMismatch
        );
    }

    #[test]
    fn checkpoint_keeps_manifest_only_dynamic_compute_out_of_pro_live() {
        let err = DynamicComputeCheckpoint::new(
            DynamicComputeCheckpointKind::DepthBudget,
            "depth budget changed the route plan",
            vec![unit(b"before")],
            vec![unit(b"after")],
            "dynamic compute checkpoints stay Pro Research or Pro Gated until the route has live product proof",
            1_000,
            "run_event_log:9",
            verifier_stack(),
            ProductBuild::Pro,
            ProStatus::Live,
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            DynamicComputeCheckpointError::ProductBuildStatusMismatch
        );
    }

    #[test]
    fn checkpoint_can_bind_a_concrete_run_event_log_ordinal() {
        let mut log = RunEventLog::new();
        let ordinal = log.append_event(AgentEvent::ReasoningDelta {
            text: "Eidos interrupt visible before answer emission".to_string(),
        });

        let checkpoint = DynamicComputeCheckpoint::from_visible_run_event(
            DynamicComputeCheckpointKind::EidosInterrupt,
            "missing closed citation evidence",
            vec![unit(b"controller")],
            vec![unit(b"controller"), unit(b"citation-kv-page")],
            "Eidos requested evidence repair before answer emission",
            2_500,
            &log,
            ordinal,
            verifier_stack(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            99,
        )
        .expect("concrete log event ordinal should bind");

        assert_eq!(checkpoint.run_event_id, "run_event_log:0");
        assert_eq!(
            checkpoint.checkpoint_kind,
            DynamicComputeCheckpointKind::EidosInterrupt
        );
    }

    #[test]
    fn checkpoint_rejects_missing_visible_run_event_log_ordinal() {
        let log = RunEventLog::new();

        let err = DynamicComputeCheckpoint::from_visible_run_event(
            DynamicComputeCheckpointKind::VerifierRepair,
            "citation verifier failed",
            vec![unit(b"before")],
            vec![unit(b"after")],
            "bounded verifier repair must be visible",
            1_000,
            &log,
            0,
            verifier_stack(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            DynamicComputeCheckpointError::MissingRunEventLogOrdinal { ordinal: 0 }
        );
    }

    #[test]
    fn checkpoint_rejects_non_event_run_event_log_ordinals() {
        let mut log = RunEventLog::new();
        let ordinal = log.append_sealed_mutation(Hash::from_bytes([7; 32]), Default::default());

        let err = DynamicComputeCheckpoint::from_visible_run_event(
            DynamicComputeCheckpointKind::AdapterSwap,
            "adapter family switch",
            vec![unit(b"before")],
            vec![unit(b"after")],
            "adapter swap must bind an AgentEvent row, not only a mutation row",
            1_000,
            &log,
            ordinal,
            verifier_stack(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            99,
        )
        .unwrap_err();

        assert_eq!(
            err,
            DynamicComputeCheckpointError::RunEventLogOrdinalIsNotEvent { ordinal }
        );
    }
}
