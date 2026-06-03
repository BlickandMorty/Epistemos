//! Cold-miss ledger for constructive residency route learning.
//!
//! This metadata-only primitive records route-level cold misses and the
//! rollback-bound policy patch they justify. It does not move bytes, mutate
//! live routing policy, mmap files, run MLX/Metal, or load model weights.

use serde::{Deserialize, Serialize};
use std::collections::HashSet;

use crate::uas::{UasAddress, UasKind};

const ENTRY_UAS_KIND: &str = "cold_miss_ledger_entry";
const LEDGER_UAS_KIND: &str = "cold_miss_ledger";
const POLICY_PATCH_UAS_KIND: &str = "cold_route_policy_patch";
const MAX_STORAGE_WEAR_BYTES: u64 = 128 * 1024;
const ROUTE_PREFIXES: [&str; 2] = ["route:", "runtime_router:"];
const FALLBACK_PREFIXES: [&str; 2] = ["fallback:", "runtime_router:fallback_"];
const PREFETCH_POLICY_PREFIX: &str = "prefetch_policy:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";

// UAS: uas/research-construction/cold-miss-ledger-entry
// Plane: RuntimePlane::Episodic
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ColdMissLedgerEntry {
    pub entry_address: UasAddress,
    pub route_id: String,
    pub missed_unit: UasAddress,
    pub miss_time_ms: u64,
    pub stall_ms: u64,
    pub cold_io_bytes: u64,
    pub fallback_used: String,
    pub verifier_delta_bps: i32,
    pub next_prefetch_policy: String,
}

impl ColdMissLedgerEntry {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        route_id: impl Into<String>,
        missed_unit: UasAddress,
        miss_time_ms: u64,
        stall_ms: u64,
        cold_io_bytes: u64,
        fallback_used: impl Into<String>,
        verifier_delta_bps: i32,
        next_prefetch_policy: impl Into<String>,
        created_at_ms: u64,
    ) -> Result<Self, ColdMissLedgerError> {
        let route_id = route_id.into();
        let fallback_used = fallback_used.into();
        let next_prefetch_policy = next_prefetch_policy.into();
        validate_nonempty("route_id", &route_id)?;
        validate_route("route_id", &route_id)?;
        if miss_time_ms == 0 {
            return Err(ColdMissLedgerError::ZeroMissTime);
        }
        if stall_ms == 0 {
            return Err(ColdMissLedgerError::ZeroStall);
        }
        if cold_io_bytes == 0 {
            return Err(ColdMissLedgerError::ZeroColdIoBytes);
        }
        validate_nonempty("fallback_used", &fallback_used)?;
        validate_fallback("fallback_used", &fallback_used)?;
        if verifier_delta_bps == 0 {
            return Err(ColdMissLedgerError::MissingVerifierDelta);
        }
        validate_nonempty("next_prefetch_policy", &next_prefetch_policy)?;
        validate_prefetch_policy("next_prefetch_policy", &next_prefetch_policy)?;

        let entry_address = entry_address(
            &route_id,
            &missed_unit,
            miss_time_ms,
            stall_ms,
            cold_io_bytes,
            &fallback_used,
            verifier_delta_bps,
            &next_prefetch_policy,
            created_at_ms,
        );

        Ok(Self {
            entry_address,
            route_id,
            missed_unit,
            miss_time_ms,
            stall_ms,
            cold_io_bytes,
            fallback_used,
            verifier_delta_bps,
            next_prefetch_policy,
        })
    }
}

// UAS: uas/research-construction/cold-miss-ledger
// Plane: RuntimePlane::Episodic
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ColdMissLedger {
    pub ledger_address: UasAddress,
    pub route_id: String,
    pub source_card_ids: Vec<String>,
    pub task_signature: String,
    pub entries: Vec<ColdMissLedgerEntry>,
    pub next_prefetch_policy: String,
    pub policy_patch_ref: UasAddress,
    pub fallback_route: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub baseline_held_out_misses: u64,
    pub patched_held_out_misses: u64,
    pub baseline_repeated_stall_ms: u64,
    pub patched_repeated_stall_ms: u64,
    pub storage_wear_bytes: u64,
    pub production_mutation: bool,
}

impl ColdMissLedger {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        route_id: impl Into<String>,
        source_card_ids: Vec<String>,
        task_signature: impl Into<String>,
        entries: Vec<ColdMissLedgerEntry>,
        next_prefetch_policy: impl Into<String>,
        policy_patch_ref: UasAddress,
        fallback_route: impl Into<String>,
        rollback_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        baseline_held_out_misses: u64,
        patched_held_out_misses: u64,
        baseline_repeated_stall_ms: u64,
        patched_repeated_stall_ms: u64,
        storage_wear_bytes: u64,
        production_mutation: bool,
        created_at_ms: u64,
    ) -> Result<Self, ColdMissLedgerError> {
        let route_id = route_id.into();
        let task_signature = task_signature.into();
        let next_prefetch_policy = next_prefetch_policy.into();
        let fallback_route = fallback_route.into();
        let rollback_ref = rollback_ref.into();
        let run_event_log_ref = run_event_log_ref.into();
        let answer_packet_ref = answer_packet_ref.into();

        validate_nonempty("route_id", &route_id)?;
        validate_route("route_id", &route_id)?;
        let source_card_ids = canonicalize_source_cards(source_card_ids)?;
        validate_nonempty("task_signature", &task_signature)?;
        let entries = canonicalize_entries(entries)?;
        if entries.len() < 2 {
            return Err(ColdMissLedgerError::MissingRepeatedMisses);
        }
        if entries.iter().any(|entry| entry.route_id != route_id) {
            return Err(ColdMissLedgerError::EntryRouteMismatch);
        }
        validate_nonempty("next_prefetch_policy", &next_prefetch_policy)?;
        validate_prefetch_policy("next_prefetch_policy", &next_prefetch_policy)?;
        if entries
            .iter()
            .any(|entry| entry.next_prefetch_policy != next_prefetch_policy)
        {
            return Err(ColdMissLedgerError::EntryPolicyMismatch);
        }
        validate_policy_patch_ref(&policy_patch_ref)?;
        validate_nonempty("fallback_route", &fallback_route)?;
        validate_fallback("fallback_route", &fallback_route)?;
        validate_prefixed("rollback_ref", &rollback_ref, ROLLBACK_PREFIX)?;
        validate_prefixed(
            "run_event_log_ref",
            &run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        )?;
        validate_prefixed(
            "answer_packet_ref",
            &answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        )?;
        if patched_held_out_misses >= baseline_held_out_misses {
            return Err(ColdMissLedgerError::MissingHeldOutImprovement);
        }
        if patched_repeated_stall_ms >= baseline_repeated_stall_ms {
            return Err(ColdMissLedgerError::MissingStallImprovement);
        }
        if storage_wear_bytes > MAX_STORAGE_WEAR_BYTES {
            return Err(ColdMissLedgerError::StorageWearTooHigh { storage_wear_bytes });
        }
        if production_mutation {
            return Err(ColdMissLedgerError::ProductionMutation);
        }

        let ledger_address = ledger_address(
            &route_id,
            &source_card_ids,
            &task_signature,
            &entries,
            &next_prefetch_policy,
            &policy_patch_ref,
            &fallback_route,
            &rollback_ref,
            &run_event_log_ref,
            &answer_packet_ref,
            baseline_held_out_misses,
            patched_held_out_misses,
            baseline_repeated_stall_ms,
            patched_repeated_stall_ms,
            storage_wear_bytes,
            created_at_ms,
        );

        Ok(Self {
            ledger_address,
            route_id,
            source_card_ids,
            task_signature,
            entries,
            next_prefetch_policy,
            policy_patch_ref,
            fallback_route,
            rollback_ref,
            run_event_log_ref,
            answer_packet_ref,
            baseline_held_out_misses,
            patched_held_out_misses,
            baseline_repeated_stall_ms,
            patched_repeated_stall_ms,
            storage_wear_bytes,
            production_mutation,
        })
    }

    pub fn total_cold_io_bytes(&self) -> u64 {
        self.entries.iter().map(|entry| entry.cold_io_bytes).sum()
    }

    pub fn total_verifier_delta_bps(&self) -> i32 {
        self.entries
            .iter()
            .map(|entry| entry.verifier_delta_bps)
            .sum()
    }
}

// UAS: uas/research-construction/cold-miss-ledger-error
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ColdMissLedgerError {
    MissingRouteId,
    MissingSourceCards,
    DuplicateSourceCard { source_card_id: String },
    MissingTaskSignature,
    MissingEntry,
    MissingRepeatedMisses,
    EntryRouteMismatch,
    EntryPolicyMismatch,
    ZeroMissTime,
    ZeroStall,
    ZeroColdIoBytes,
    MissingVerifierDelta,
    MissingNextPrefetchPolicy,
    InvalidRoute { field: &'static str, value: String },
    InvalidFallback { field: &'static str, value: String },
    InvalidPrefetchPolicy { field: &'static str, value: String },
    InvalidPolicyPatchRef { actual_kind: String },
    MissingFallback,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    MissingHeldOutImprovement,
    MissingStallImprovement,
    StorageWearTooHigh { storage_wear_bytes: u64 },
    ProductionMutation,
    FieldHasSurroundingWhitespace { field: &'static str },
    FieldContainsControlCharacter { field: &'static str },
}

impl std::fmt::Display for ColdMissLedgerError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingRouteId => write!(f, "route_id is required"),
            Self::MissingSourceCards => write!(f, "source_card_ids are required"),
            Self::DuplicateSourceCard { source_card_id } => {
                write!(f, "duplicate source card id: {source_card_id}")
            }
            Self::MissingTaskSignature => write!(f, "task_signature is required"),
            Self::MissingEntry => write!(f, "cold miss ledger entries are required"),
            Self::MissingRepeatedMisses => write!(f, "at least two cold miss entries are required"),
            Self::EntryRouteMismatch => {
                write!(f, "ledger entry route_id must match ledger route_id")
            }
            Self::EntryPolicyMismatch => {
                write!(f, "ledger entry policy must match next_prefetch_policy")
            }
            Self::ZeroMissTime => write!(f, "miss_time_ms must be nonzero"),
            Self::ZeroStall => write!(f, "stall_ms must be nonzero"),
            Self::ZeroColdIoBytes => write!(f, "cold_io_bytes must be nonzero"),
            Self::MissingVerifierDelta => write!(f, "verifier_delta_bps must be nonzero"),
            Self::MissingNextPrefetchPolicy => write!(f, "next_prefetch_policy is required"),
            Self::InvalidRoute { field, value } => {
                write!(f, "{field} has unsupported route id `{value}`")
            }
            Self::InvalidFallback { field, value } => {
                write!(f, "{field} has unsupported fallback `{value}`")
            }
            Self::InvalidPrefetchPolicy { field, value } => {
                write!(f, "{field} has unsupported prefetch policy `{value}`")
            }
            Self::InvalidPolicyPatchRef { actual_kind } => {
                write!(
                    f,
                    "policy_patch_ref must be {POLICY_PATCH_UAS_KIND}, got {actual_kind}"
                )
            }
            Self::MissingFallback => write!(f, "fallback route is required"),
            Self::MissingRollback => write!(f, "rollback_ref is required"),
            Self::MissingRunEventLog => write!(f, "run_event_log_ref is required"),
            Self::MissingAnswerPacket => write!(f, "answer_packet_ref is required"),
            Self::MissingHeldOutImprovement => {
                write!(f, "patched held-out misses must be lower than baseline")
            }
            Self::MissingStallImprovement => {
                write!(f, "patched repeated stall must be lower than baseline")
            }
            Self::StorageWearTooHigh { storage_wear_bytes } => {
                write!(f, "storage wear too high: {storage_wear_bytes}")
            }
            Self::ProductionMutation => write!(f, "cold miss ledger must not mutate production"),
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "{field} must not contain leading or trailing whitespace")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "{field} must not contain control characters")
            }
        }
    }
}

impl std::error::Error for ColdMissLedgerError {}

fn entry_address(
    route_id: &str,
    missed_unit: &UasAddress,
    miss_time_ms: u64,
    stall_ms: u64,
    cold_io_bytes: u64,
    fallback_used: &str,
    verifier_delta_bps: i32,
    next_prefetch_policy: &str,
    created_at_ms: u64,
) -> UasAddress {
    let preimage = format!(
        "{ENTRY_UAS_KIND}\n{route_id}\n{missed_unit}\n{miss_time_ms}\n{stall_ms}\n{cold_io_bytes}\n{fallback_used}\n{verifier_delta_bps}\n{next_prefetch_policy}"
    );
    UasAddress::new(
        UasKind::Other(ENTRY_UAS_KIND.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

#[allow(clippy::too_many_arguments)]
fn ledger_address(
    route_id: &str,
    source_card_ids: &[String],
    task_signature: &str,
    entries: &[ColdMissLedgerEntry],
    next_prefetch_policy: &str,
    policy_patch_ref: &UasAddress,
    fallback_route: &str,
    rollback_ref: &str,
    run_event_log_ref: &str,
    answer_packet_ref: &str,
    baseline_held_out_misses: u64,
    patched_held_out_misses: u64,
    baseline_repeated_stall_ms: u64,
    patched_repeated_stall_ms: u64,
    storage_wear_bytes: u64,
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str(LEDGER_UAS_KIND);
    preimage.push('\n');
    push_field(&mut preimage, "route_id", route_id);
    push_field(&mut preimage, "task_signature", task_signature);
    for source_card_id in source_card_ids {
        push_field(&mut preimage, "source_card_id", source_card_id);
    }
    for entry in entries {
        push_field(&mut preimage, "entry", &entry.entry_address.to_string());
    }
    push_field(&mut preimage, "next_prefetch_policy", next_prefetch_policy);
    push_field(
        &mut preimage,
        "policy_patch_ref",
        &policy_patch_ref.to_string(),
    );
    push_field(&mut preimage, "fallback_route", fallback_route);
    push_field(&mut preimage, "rollback_ref", rollback_ref);
    push_field(&mut preimage, "run_event_log_ref", run_event_log_ref);
    push_field(&mut preimage, "answer_packet_ref", answer_packet_ref);
    push_field(
        &mut preimage,
        "held_out_misses",
        &format!("{baseline_held_out_misses}:{patched_held_out_misses}"),
    );
    push_field(
        &mut preimage,
        "repeated_stall_ms",
        &format!("{baseline_repeated_stall_ms}:{patched_repeated_stall_ms}"),
    );
    push_field(
        &mut preimage,
        "storage_wear_bytes",
        &storage_wear_bytes.to_string(),
    );
    UasAddress::new(
        UasKind::Other(LEDGER_UAS_KIND.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn push_field(preimage: &mut String, name: &str, value: &str) {
    preimage.push_str(name);
    preimage.push('=');
    preimage.push_str(value);
    preimage.push('\n');
}

fn canonicalize_source_cards(
    mut source_card_ids: Vec<String>,
) -> Result<Vec<String>, ColdMissLedgerError> {
    if source_card_ids.is_empty() {
        return Err(ColdMissLedgerError::MissingSourceCards);
    }
    for source_card_id in &source_card_ids {
        validate_nonempty("source_card_id", source_card_id)?;
    }
    source_card_ids.sort();
    let mut seen = HashSet::with_capacity(source_card_ids.len());
    for source_card_id in &source_card_ids {
        if !seen.insert(source_card_id.clone()) {
            return Err(ColdMissLedgerError::DuplicateSourceCard {
                source_card_id: source_card_id.clone(),
            });
        }
    }
    Ok(source_card_ids)
}

fn canonicalize_entries(
    mut entries: Vec<ColdMissLedgerEntry>,
) -> Result<Vec<ColdMissLedgerEntry>, ColdMissLedgerError> {
    if entries.is_empty() {
        return Err(ColdMissLedgerError::MissingEntry);
    }
    entries.sort_by(|a, b| {
        a.missed_unit
            .to_string()
            .cmp(&b.missed_unit.to_string())
            .then_with(|| a.miss_time_ms.cmp(&b.miss_time_ms))
            .then_with(|| {
                a.entry_address
                    .to_string()
                    .cmp(&b.entry_address.to_string())
            })
    });
    Ok(entries)
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), ColdMissLedgerError> {
    if value.trim().is_empty() {
        return Err(match field {
            "route_id" => ColdMissLedgerError::MissingRouteId,
            "source_card_id" => ColdMissLedgerError::MissingSourceCards,
            "task_signature" => ColdMissLedgerError::MissingTaskSignature,
            "next_prefetch_policy" => ColdMissLedgerError::MissingNextPrefetchPolicy,
            "fallback_used" | "fallback_route" => ColdMissLedgerError::MissingFallback,
            "rollback_ref" => ColdMissLedgerError::MissingRollback,
            "run_event_log_ref" => ColdMissLedgerError::MissingRunEventLog,
            "answer_packet_ref" => ColdMissLedgerError::MissingAnswerPacket,
            _ => ColdMissLedgerError::FieldContainsControlCharacter { field },
        });
    }
    if value.trim() != value {
        return Err(ColdMissLedgerError::FieldHasSurroundingWhitespace { field });
    }
    if value.chars().any(char::is_control) {
        return Err(ColdMissLedgerError::FieldContainsControlCharacter { field });
    }
    Ok(())
}

fn validate_route(field: &'static str, value: &str) -> Result<(), ColdMissLedgerError> {
    if ROUTE_PREFIXES
        .iter()
        .any(|prefix| value.strip_prefix(prefix).is_some_and(is_reference_payload))
    {
        return Ok(());
    }
    Err(ColdMissLedgerError::InvalidRoute {
        field,
        value: value.to_string(),
    })
}

fn validate_fallback(field: &'static str, value: &str) -> Result<(), ColdMissLedgerError> {
    if FALLBACK_PREFIXES
        .iter()
        .any(|prefix| value.strip_prefix(prefix).is_some_and(is_reference_payload))
    {
        return Ok(());
    }
    Err(ColdMissLedgerError::InvalidFallback {
        field,
        value: value.to_string(),
    })
}

fn validate_prefetch_policy(field: &'static str, value: &str) -> Result<(), ColdMissLedgerError> {
    if value
        .strip_prefix(PREFETCH_POLICY_PREFIX)
        .is_some_and(is_reference_payload)
    {
        return Ok(());
    }
    Err(ColdMissLedgerError::InvalidPrefetchPolicy {
        field,
        value: value.to_string(),
    })
}

fn validate_policy_patch_ref(policy_patch_ref: &UasAddress) -> Result<(), ColdMissLedgerError> {
    if matches!(
        &policy_patch_ref.kind,
        UasKind::Other(tag) if tag == POLICY_PATCH_UAS_KIND
    ) {
        return Ok(());
    }
    Err(ColdMissLedgerError::InvalidPolicyPatchRef {
        actual_kind: policy_patch_ref.kind.wire_tag().to_string(),
    })
}

fn validate_prefixed(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), ColdMissLedgerError> {
    validate_nonempty(field, value)?;
    if value.strip_prefix(prefix).is_some_and(is_reference_payload) {
        return Ok(());
    }
    Err(match field {
        "rollback_ref" => ColdMissLedgerError::MissingRollback,
        "run_event_log_ref" => ColdMissLedgerError::MissingRunEventLog,
        "answer_packet_ref" => ColdMissLedgerError::MissingAnswerPacket,
        _ => ColdMissLedgerError::FieldContainsControlCharacter { field },
    })
}

fn is_reference_payload(payload: &str) -> bool {
    !payload.is_empty() && payload.trim() == payload && !payload.chars().any(char::is_control)
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_000_000_000;

    fn address(kind: UasKind, label: &str) -> UasAddress {
        UasAddress::new(kind, label.as_bytes(), CREATED_AT_MS)
    }

    fn policy_patch_ref() -> UasAddress {
        address(
            UasKind::Other(POLICY_PATCH_UAS_KIND.to_string()),
            "policy-patch",
        )
    }

    fn entry(label: &str, stall_ms: u64) -> ColdMissLedgerEntry {
        ColdMissLedgerEntry::new(
            "route:module-5-cold-assembly",
            address(UasKind::ModelComponent, label),
            1_000 + stall_ms,
            stall_ms,
            64 * 1024,
            "runtime_router:fallback_static_route",
            -120,
            "prefetch_policy:module-5-coactivation-priority",
            CREATED_AT_MS,
        )
        .unwrap()
    }

    fn accepted_ledger() -> ColdMissLedger {
        ColdMissLedger::new(
            "route:module-5-cold-assembly",
            vec![
                "source:constructive-residency".to_string(),
                "source:coldstream-transport".to_string(),
            ],
            "task:module-5-adversarial-research",
            vec![entry("missing-weight-b", 22), entry("missing-weight-a", 18)],
            "prefetch_policy:module-5-coactivation-priority",
            policy_patch_ref(),
            "fallback:static-route",
            "rollback:cold-miss-ledger",
            "run_event_log:cold-miss-ledger",
            "answer_packet:cold-miss-ledger",
            4,
            1,
            96,
            24,
            32 * 1024,
            false,
            CREATED_AT_MS,
        )
        .unwrap()
    }

    #[test]
    fn cold_miss_ledger_accepts_held_out_improvement() {
        let ledger = accepted_ledger();
        assert_eq!(ledger.entries.len(), 2);
        assert_eq!(ledger.total_cold_io_bytes(), 128 * 1024);
        assert!(ledger.total_verifier_delta_bps() < 0);
    }

    #[test]
    fn cold_miss_ledger_address_is_deterministic() {
        let first = accepted_ledger();
        let second = ColdMissLedger::new(
            "route:module-5-cold-assembly",
            vec![
                "source:coldstream-transport".to_string(),
                "source:constructive-residency".to_string(),
            ],
            "task:module-5-adversarial-research",
            vec![entry("missing-weight-a", 18), entry("missing-weight-b", 22)],
            "prefetch_policy:module-5-coactivation-priority",
            policy_patch_ref(),
            "fallback:static-route",
            "rollback:cold-miss-ledger",
            "run_event_log:cold-miss-ledger",
            "answer_packet:cold-miss-ledger",
            4,
            1,
            96,
            24,
            32 * 1024,
            false,
            CREATED_AT_MS,
        )
        .unwrap();
        assert_eq!(first.ledger_address, second.ledger_address);
    }

    #[test]
    fn cold_miss_ledger_rejects_single_miss() {
        let result = ColdMissLedger::new(
            "route:module-5-cold-assembly",
            vec!["source:constructive-residency".to_string()],
            "task:module-5-adversarial-research",
            vec![entry("missing-weight-a", 18)],
            "prefetch_policy:module-5-coactivation-priority",
            policy_patch_ref(),
            "fallback:static-route",
            "rollback:cold-miss-ledger",
            "run_event_log:cold-miss-ledger",
            "answer_packet:cold-miss-ledger",
            4,
            1,
            96,
            24,
            32 * 1024,
            false,
            CREATED_AT_MS,
        );
        assert!(matches!(
            result,
            Err(ColdMissLedgerError::MissingRepeatedMisses)
        ));
    }

    #[test]
    fn cold_miss_ledger_rejects_missing_policy_patch() {
        let result = ColdMissLedger::new(
            "route:module-5-cold-assembly",
            vec!["source:constructive-residency".to_string()],
            "task:module-5-adversarial-research",
            vec![entry("missing-weight-a", 18), entry("missing-weight-b", 22)],
            "prefetch_policy:module-5-coactivation-priority",
            address(UasKind::Other("layout_patch".to_string()), "bad-ref"),
            "fallback:static-route",
            "rollback:cold-miss-ledger",
            "run_event_log:cold-miss-ledger",
            "answer_packet:cold-miss-ledger",
            4,
            1,
            96,
            24,
            32 * 1024,
            false,
            CREATED_AT_MS,
        );
        assert!(matches!(
            result,
            Err(ColdMissLedgerError::InvalidPolicyPatchRef { .. })
        ));
    }

    #[test]
    fn cold_miss_ledger_rejects_missing_improvement() {
        let result = ColdMissLedger::new(
            "route:module-5-cold-assembly",
            vec!["source:constructive-residency".to_string()],
            "task:module-5-adversarial-research",
            vec![entry("missing-weight-a", 18), entry("missing-weight-b", 22)],
            "prefetch_policy:module-5-coactivation-priority",
            policy_patch_ref(),
            "fallback:static-route",
            "rollback:cold-miss-ledger",
            "run_event_log:cold-miss-ledger",
            "answer_packet:cold-miss-ledger",
            4,
            4,
            96,
            24,
            32 * 1024,
            false,
            CREATED_AT_MS,
        );
        assert!(matches!(
            result,
            Err(ColdMissLedgerError::MissingHeldOutImprovement)
        ));
    }

    #[test]
    fn cold_miss_ledger_rejects_live_mutation() {
        let result = ColdMissLedger::new(
            "route:module-5-cold-assembly",
            vec!["source:constructive-residency".to_string()],
            "task:module-5-adversarial-research",
            vec![entry("missing-weight-a", 18), entry("missing-weight-b", 22)],
            "prefetch_policy:module-5-coactivation-priority",
            policy_patch_ref(),
            "fallback:static-route",
            "rollback:cold-miss-ledger",
            "run_event_log:cold-miss-ledger",
            "answer_packet:cold-miss-ledger",
            4,
            1,
            96,
            24,
            32 * 1024,
            true,
            CREATED_AT_MS,
        );
        assert!(matches!(
            result,
            Err(ColdMissLedgerError::ProductionMutation)
        ));
    }

    #[test]
    fn cold_miss_entry_rejects_zero_stall() {
        let result = ColdMissLedgerEntry::new(
            "route:module-5-cold-assembly",
            address(UasKind::ModelComponent, "missing-weight-a"),
            1_000,
            0,
            64 * 1024,
            "runtime_router:fallback_static_route",
            -120,
            "prefetch_policy:module-5-coactivation-priority",
            CREATED_AT_MS,
        );
        assert!(matches!(result, Err(ColdMissLedgerError::ZeroStall)));
    }

    #[test]
    fn cold_miss_ledger_rejects_high_storage_wear() {
        let result = ColdMissLedger::new(
            "route:module-5-cold-assembly",
            vec!["source:constructive-residency".to_string()],
            "task:module-5-adversarial-research",
            vec![entry("missing-weight-a", 18), entry("missing-weight-b", 22)],
            "prefetch_policy:module-5-coactivation-priority",
            policy_patch_ref(),
            "fallback:static-route",
            "rollback:cold-miss-ledger",
            "run_event_log:cold-miss-ledger",
            "answer_packet:cold-miss-ledger",
            4,
            1,
            96,
            24,
            256 * 1024,
            false,
            CREATED_AT_MS,
        );
        assert!(matches!(
            result,
            Err(ColdMissLedgerError::StorageWearTooHigh { .. })
        ));
    }
}
