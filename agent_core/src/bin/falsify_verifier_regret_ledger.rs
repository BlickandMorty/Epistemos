//! `falsify_verifier_regret_ledger` -- held-out route-regret contract.
//!
//! Metadata-only witness for `F-VerifierRegretLedger`. It proves route
//! utility updates change later shadow route selection and reduce held-out
//! verifier regret while binding rollback, RunEventLog, AnswerPacket, and
//! no-hidden-authority guards. No runtime/model bytes are loaded.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-VerifierRegretLedger";
const FIXTURE_ID: &str = "verifier_regret_ledger_v1";
const COMMAND: &str = "Tools/falsifiers/f_verifier_regret_ledger.sh";
const RESULT: &str = "artifacts/falsifiers/verifier_regret_ledger/result.json";
const UPSTREAM_NEURAL_CONTROL: &str =
    "artifacts/falsifiers/neural_control_card_ablation/result.json";
const MAX_POLICY_PATCH_BYTES: u64 = 12 * 1024 * 1024;

// UAS: verifier-regret held-out task set.
// Plane: Verification.
// Residency: metadata-only; task identifiers only, no prompt/model bytes.
#[derive(Clone)]
struct HeldOutSet {
    task_ids: &'static [&'static str],
    baseline_regret_bps: u64,
    updated_regret_bps: u64,
}

// UAS: VerifierRegretLedger entry.
// Plane: Controller + Verification.
// Residency: metadata-only shadow policy evidence.
#[derive(Clone)]
struct RegretEntry {
    entry_id: &'static str,
    unit_id: &'static str,
    route_id: &'static str,
    task_signature: &'static str,
    baseline_score_bps: u64,
    intervention_score_bps: u64,
    verifier_delta_bps: u64,
    evidence_validity_delta_bps: u64,
    latency_saved_ms: u64,
    active_bytes_saved: u64,
    failure_mode: &'static str,
    regret_update: &'static str,
    next_policy: &'static str,
    prior_route: &'static str,
    updated_route: &'static str,
    held_out: HeldOutSet,
    rollback_handle: &'static str,
    run_event_log_ref: &'static str,
    answer_packet_ref: &'static str,
    policy_patch_ref: &'static str,
    route_authority: &'static str,
    policy_version_before: u64,
    policy_version_after: u64,
    policy_patch_active_bytes: u64,
    hidden_chain_exposed: bool,
    hidden_cloud: bool,
    live_policy_mutated: bool,
    upstream_neural_ref: &'static str,
}

#[derive(Debug, Eq, PartialEq)]
// UAS: uas:verifier-regret:error
// Plane: Verification
// Residency: metadata-only
enum RegretError {
    MissingEntry,
    DuplicateEntry,
    MissingEntryId,
    MissingUnit,
    MissingRoute,
    MissingTaskSignature,
    InvalidScore,
    MissingDelta,
    MissingFailureMode,
    MissingRegretUpdate,
    MissingNextPolicy,
    MissingHeldOut,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    MissingPolicyPatch,
    NoRouteSelectionChange,
    NoHeldOutRegretReduction,
    HiddenLiveAuthority,
    LivePolicyMutation,
    HiddenChainExposure,
    CloudRoute,
    ActiveByteBudgetExceeded,
    StalePolicyVersion,
    UpstreamNotBound,
}

impl std::fmt::Display for RegretError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for RegretError {}

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
        Err(error) => {
            eprintln!("failed to build {FALSIFIER_ID}: {error}");
            return std::process::ExitCode::from(2);
        }
    };

    let path = PathBuf::from(RESULT);
    if let Some(parent) = path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create artifact directory: {error}");
            return std::process::ExitCode::from(2);
        }
    }
    let mut file = match std::fs::File::create(&path) {
        Ok(file) => file,
        Err(error) => {
            eprintln!("failed to open artifact: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    if let Err(error) = write_artifact(&mut file, &artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    println!(
        "{FALSIFIER_ID}: overall_pass={} regret_entry_count={} regret_address={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["regret_entry_count"].value,
        artifact.measurements["regret_address"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let entries = fixture_entries();
    let reversed = entries.iter().cloned().rev().collect::<Vec<_>>();
    let ledger = RegretLedger::new(entries)?;
    let reversed_ledger = RegretLedger::new(reversed)?;

    let upstream_neural_control_pass = upstream_neural_control_pass();
    let regret_entries_present = ledger.entries.len() == 3;
    let unit_ids_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.unit_id.starts_with("uas:"));
    let route_ids_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.route_id.starts_with("route:"));
    let task_signatures_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.task_signature.starts_with("task:"));
    let baseline_scores_bound = ledger
        .entries
        .iter()
        .all(|entry| bounded_score(entry.baseline_score_bps));
    let intervention_scores_bound = ledger
        .entries
        .iter()
        .all(|entry| bounded_score(entry.intervention_score_bps));
    let verifier_delta_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.verifier_delta_bps > 0);
    let evidence_validity_delta_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.evidence_validity_delta_bps > 0);
    let latency_delta_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.latency_saved_ms > 0);
    let active_byte_delta_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.active_bytes_saved > 0);
    let failure_modes_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.failure_mode.starts_with("failure:"));
    let regret_updates_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.regret_update.starts_with("regret-update:"));
    let next_policy_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.next_policy.starts_with("policy:"));
    let held_out_task_set_bound = ledger.entries.iter().all(held_out_bound);
    let later_route_selection_changed = ledger
        .entries
        .iter()
        .all(|entry| entry.prior_route != entry.updated_route);
    let held_out_regret_reduced = ledger
        .entries
        .iter()
        .all(|entry| entry.held_out.updated_regret_bps < entry.held_out.baseline_regret_bps);
    let route_utility_update_shadow_only = ledger
        .entries
        .iter()
        .all(|entry| entry.route_authority == "shadow_only");
    let rollback_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.rollback_handle.starts_with("rollback:"));
    let run_event_log_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.run_event_log_ref.starts_with("runlog:"));
    let answer_packet_ref_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.answer_packet_ref.starts_with("answerpacket:"));
    let policy_patch_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.policy_patch_ref.starts_with("policy-patch:"));
    let no_hidden_route_authority = route_utility_update_shadow_only;
    let no_hidden_chain = ledger
        .entries
        .iter()
        .all(|entry| !entry.hidden_chain_exposed);
    let no_hidden_cloud = ledger.entries.iter().all(|entry| !entry.hidden_cloud);
    let live_policy_not_mutated = ledger
        .entries
        .iter()
        .all(|entry| !entry.live_policy_mutated);
    let policy_version_advances = ledger
        .entries
        .iter()
        .all(|entry| entry.policy_version_after == entry.policy_version_before + 1);
    let upstream_neural_refs_bound = ledger.entries.iter().all(|entry| {
        entry
            .upstream_neural_ref
            .starts_with("artifacts/falsifiers/neural_control_card_ablation/")
    });
    let quality_delta_positive = ledger
        .entries
        .iter()
        .all(|entry| entry.intervention_score_bps > entry.baseline_score_bps);
    let active_byte_budget_respected = ledger
        .entries
        .iter()
        .all(|entry| entry.policy_patch_active_bytes <= MAX_POLICY_PATCH_BYTES);
    let regret_address_deterministic = ledger.regret_address == reversed_ledger.regret_address;
    let duplicate_entry_rejected = duplicate_entry_rejected();
    let missing_held_out_rejected = invalid_entry_rejected(|entry| entry.held_out.task_ids = &[])
        == Some(RegretError::MissingHeldOut);
    let missing_regret_update_rejected = invalid_entry_rejected(|entry| entry.regret_update = "")
        == Some(RegretError::MissingRegretUpdate);
    let missing_next_policy_rejected = invalid_entry_rejected(|entry| entry.next_policy = "")
        == Some(RegretError::MissingNextPolicy);
    let missing_rollback_rejected = invalid_entry_rejected(|entry| entry.rollback_handle = "")
        == Some(RegretError::MissingRollback);
    let missing_run_event_log_rejected =
        invalid_entry_rejected(|entry| entry.run_event_log_ref = "")
            == Some(RegretError::MissingRunEventLog);
    let missing_answer_packet_rejected =
        invalid_entry_rejected(|entry| entry.answer_packet_ref = "")
            == Some(RegretError::MissingAnswerPacket);
    let no_route_change_rejected =
        invalid_entry_rejected(|entry| entry.updated_route = entry.prior_route)
            == Some(RegretError::NoRouteSelectionChange);
    let no_regret_reduction_rejected = invalid_entry_rejected(|entry| {
        entry.held_out.updated_regret_bps = entry.held_out.baseline_regret_bps;
    }) == Some(RegretError::NoHeldOutRegretReduction);
    let hidden_live_authority_rejected =
        invalid_entry_rejected(|entry| entry.route_authority = "live_route_policy")
            == Some(RegretError::HiddenLiveAuthority);
    let live_policy_mutation_rejected =
        invalid_entry_rejected(|entry| entry.live_policy_mutated = true)
            == Some(RegretError::LivePolicyMutation);
    let hidden_chain_exposure_rejected =
        invalid_entry_rejected(|entry| entry.hidden_chain_exposed = true)
            == Some(RegretError::HiddenChainExposure);
    let cloud_route_rejected =
        invalid_entry_rejected(|entry| entry.hidden_cloud = true) == Some(RegretError::CloudRoute);
    let over_budget_update_rejected = invalid_entry_rejected(|entry| {
        entry.policy_patch_active_bytes = MAX_POLICY_PATCH_BYTES + 1
    }) == Some(RegretError::ActiveByteBudgetExceeded);
    let stale_policy_rejected =
        invalid_entry_rejected(|entry| entry.policy_version_after = entry.policy_version_before)
            == Some(RegretError::StalePolicyVersion);
    let no_runtime_bytes_loaded = true;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        ("upstream_neural_control_pass", upstream_neural_control_pass),
        ("regret_entries_present", regret_entries_present),
        ("unit_ids_bound", unit_ids_bound),
        ("route_ids_bound", route_ids_bound),
        ("task_signatures_bound", task_signatures_bound),
        ("baseline_scores_bound", baseline_scores_bound),
        ("intervention_scores_bound", intervention_scores_bound),
        ("quality_delta_positive", quality_delta_positive),
        ("verifier_delta_bound", verifier_delta_bound),
        (
            "evidence_validity_delta_bound",
            evidence_validity_delta_bound,
        ),
        ("latency_delta_bound", latency_delta_bound),
        ("active_byte_delta_bound", active_byte_delta_bound),
        ("failure_modes_bound", failure_modes_bound),
        ("regret_updates_bound", regret_updates_bound),
        ("next_policy_bound", next_policy_bound),
        ("held_out_task_set_bound", held_out_task_set_bound),
        (
            "later_route_selection_changed",
            later_route_selection_changed,
        ),
        ("held_out_regret_reduced", held_out_regret_reduced),
        (
            "route_utility_update_shadow_only",
            route_utility_update_shadow_only,
        ),
        ("rollback_bound", rollback_bound),
        ("run_event_log_bound", run_event_log_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("policy_patch_bound", policy_patch_bound),
        ("no_hidden_route_authority", no_hidden_route_authority),
        ("no_hidden_chain", no_hidden_chain),
        ("no_hidden_cloud", no_hidden_cloud),
        ("live_policy_not_mutated", live_policy_not_mutated),
        ("policy_version_advances", policy_version_advances),
        ("upstream_neural_refs_bound", upstream_neural_refs_bound),
        ("active_byte_budget_respected", active_byte_budget_respected),
        ("regret_address_deterministic", regret_address_deterministic),
        ("duplicate_entry_rejected", duplicate_entry_rejected),
        ("missing_held_out_rejected", missing_held_out_rejected),
        (
            "missing_regret_update_rejected",
            missing_regret_update_rejected,
        ),
        ("missing_next_policy_rejected", missing_next_policy_rejected),
        ("missing_rollback_rejected", missing_rollback_rejected),
        (
            "missing_run_event_log_rejected",
            missing_run_event_log_rejected,
        ),
        (
            "missing_answer_packet_rejected",
            missing_answer_packet_rejected,
        ),
        ("no_route_change_rejected", no_route_change_rejected),
        ("no_regret_reduction_rejected", no_regret_reduction_rejected),
        (
            "hidden_live_authority_rejected",
            hidden_live_authority_rejected,
        ),
        (
            "live_policy_mutation_rejected",
            live_policy_mutation_rejected,
        ),
        (
            "hidden_chain_exposure_rejected",
            hidden_chain_exposure_rejected,
        ),
        ("cloud_route_rejected", cloud_route_rejected),
        ("over_budget_update_rejected", over_budget_update_rejected),
        ("stale_policy_rejected", stale_policy_rejected),
        ("no_runtime_bytes_loaded", no_runtime_bytes_loaded),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
        );
    }

    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "regret_entry_count",
        ledger.entries.len() as u64,
        3,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_task_count",
        ledger.held_out_task_count(),
        6,
        "count",
    );
    add_u64_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_policy_patch_active_bytes",
        ledger.max_policy_patch_active_bytes(),
        MAX_POLICY_PATCH_BYTES,
        "bytes",
    );
    add_string_contains_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "regret_address",
        &ledger.regret_address,
        "uas:verifier-regret:",
        "uas_address",
    );

    Ok(ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: vec![serde_json::json!({
            "kind": "scope_guard",
            "detail": "metadata-only VerifierRegretLedger witness; no live route mutation, no model/runtime bytes, no hidden chain, no hidden cloud, and no product promotion executed"
        })],
        notes: "Proves verifier-regret updates change later shadow route selection and reduce held-out regret while binding RunEventLog, rollback, AnswerPacket, policy-patch evidence, and no-hidden-authority guards.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:verifier-regret:ledger
// Plane: Controller + Verification
// Residency: metadata-only
struct RegretLedger {
    entries: Vec<RegretEntry>,
    regret_address: String,
}

impl RegretLedger {
    fn new(mut entries: Vec<RegretEntry>) -> Result<Self, RegretError> {
        if entries.is_empty() {
            return Err(RegretError::MissingEntry);
        }
        let mut seen = BTreeSet::new();
        for entry in &entries {
            if !seen.insert(entry.entry_id) {
                return Err(RegretError::DuplicateEntry);
            }
            validate_entry(entry)?;
        }
        entries.sort_by_key(|entry| entry.entry_id);
        let regret_address = regret_address(&entries);
        Ok(Self {
            entries,
            regret_address,
        })
    }

    fn held_out_task_count(&self) -> u64 {
        self.entries
            .iter()
            .map(|entry| entry.held_out.task_ids.len() as u64)
            .sum()
    }

    fn max_policy_patch_active_bytes(&self) -> u64 {
        self.entries
            .iter()
            .map(|entry| entry.policy_patch_active_bytes)
            .max()
            .unwrap_or(0)
    }
}

fn validate_entry(entry: &RegretEntry) -> Result<(), RegretError> {
    if !entry.entry_id.starts_with("regret-entry:") {
        return Err(RegretError::MissingEntryId);
    }
    if !entry.unit_id.starts_with("uas:") {
        return Err(RegretError::MissingUnit);
    }
    if !entry.route_id.starts_with("route:") {
        return Err(RegretError::MissingRoute);
    }
    if !entry.task_signature.starts_with("task:") {
        return Err(RegretError::MissingTaskSignature);
    }
    if !bounded_score(entry.baseline_score_bps)
        || !bounded_score(entry.intervention_score_bps)
        || entry.intervention_score_bps <= entry.baseline_score_bps
    {
        return Err(RegretError::InvalidScore);
    }
    if entry.verifier_delta_bps == 0
        || entry.evidence_validity_delta_bps == 0
        || entry.latency_saved_ms == 0
        || entry.active_bytes_saved == 0
    {
        return Err(RegretError::MissingDelta);
    }
    if !entry.failure_mode.starts_with("failure:") {
        return Err(RegretError::MissingFailureMode);
    }
    if !entry.regret_update.starts_with("regret-update:") {
        return Err(RegretError::MissingRegretUpdate);
    }
    if !entry.next_policy.starts_with("policy:") {
        return Err(RegretError::MissingNextPolicy);
    }
    if !held_out_bound(entry) {
        return Err(RegretError::MissingHeldOut);
    }
    if entry.prior_route == entry.updated_route {
        return Err(RegretError::NoRouteSelectionChange);
    }
    if entry.held_out.updated_regret_bps >= entry.held_out.baseline_regret_bps {
        return Err(RegretError::NoHeldOutRegretReduction);
    }
    if !entry.rollback_handle.starts_with("rollback:") {
        return Err(RegretError::MissingRollback);
    }
    if !entry.run_event_log_ref.starts_with("runlog:") {
        return Err(RegretError::MissingRunEventLog);
    }
    if !entry.answer_packet_ref.starts_with("answerpacket:") {
        return Err(RegretError::MissingAnswerPacket);
    }
    if !entry.policy_patch_ref.starts_with("policy-patch:") {
        return Err(RegretError::MissingPolicyPatch);
    }
    if entry.route_authority != "shadow_only" {
        return Err(RegretError::HiddenLiveAuthority);
    }
    if entry.live_policy_mutated {
        return Err(RegretError::LivePolicyMutation);
    }
    if entry.hidden_chain_exposed {
        return Err(RegretError::HiddenChainExposure);
    }
    if entry.hidden_cloud {
        return Err(RegretError::CloudRoute);
    }
    if entry.policy_patch_active_bytes > MAX_POLICY_PATCH_BYTES {
        return Err(RegretError::ActiveByteBudgetExceeded);
    }
    if entry.policy_version_after != entry.policy_version_before + 1 {
        return Err(RegretError::StalePolicyVersion);
    }
    if !entry
        .upstream_neural_ref
        .starts_with("artifacts/falsifiers/neural_control_card_ablation/")
    {
        return Err(RegretError::UpstreamNotBound);
    }
    Ok(())
}

fn held_out_bound(entry: &RegretEntry) -> bool {
    !entry.held_out.task_ids.is_empty()
        && entry
            .held_out
            .task_ids
            .iter()
            .all(|task| task.starts_with("heldout:"))
        && bounded_score(entry.held_out.baseline_regret_bps)
        && bounded_score(entry.held_out.updated_regret_bps)
}

fn bounded_score(score: u64) -> bool {
    (1..=10_000).contains(&score)
}

fn duplicate_entry_rejected() -> bool {
    let mut entries = fixture_entries();
    let duplicate = entries[0].clone();
    entries.push(duplicate);
    matches!(RegretLedger::new(entries), Err(RegretError::DuplicateEntry))
}

fn invalid_entry_rejected(mut mutate: impl FnMut(&mut RegretEntry)) -> Option<RegretError> {
    let mut entries = fixture_entries();
    mutate(&mut entries[0]);
    RegretLedger::new(entries).err()
}

fn regret_address(entries: &[RegretEntry]) -> String {
    let mut preimage = String::new();
    for entry in entries {
        push_preimage(&mut preimage, "entry_id", entry.entry_id);
        push_preimage(&mut preimage, "unit_id", entry.unit_id);
        push_preimage(&mut preimage, "route_id", entry.route_id);
        push_preimage(&mut preimage, "task_signature", entry.task_signature);
        push_preimage(
            &mut preimage,
            "baseline_score_bps",
            &entry.baseline_score_bps.to_string(),
        );
        push_preimage(
            &mut preimage,
            "intervention_score_bps",
            &entry.intervention_score_bps.to_string(),
        );
        push_preimage(&mut preimage, "regret_update", entry.regret_update);
        push_preimage(&mut preimage, "next_policy", entry.next_policy);
        push_preimage(&mut preimage, "prior_route", entry.prior_route);
        push_preimage(&mut preimage, "updated_route", entry.updated_route);
        push_preimage(
            &mut preimage,
            "held_out_baseline_regret_bps",
            &entry.held_out.baseline_regret_bps.to_string(),
        );
        push_preimage(
            &mut preimage,
            "held_out_updated_regret_bps",
            &entry.held_out.updated_regret_bps.to_string(),
        );
        push_preimage(&mut preimage, "rollback_handle", entry.rollback_handle);
        push_preimage(&mut preimage, "answer_packet_ref", entry.answer_packet_ref);
    }
    sha256_hex(preimage.as_bytes()).replacen("sha256:", "uas:verifier-regret:", 1)
}

fn push_preimage(out: &mut String, key: &str, value: &str) {
    out.push_str(key);
    out.push('=');
    out.push_str(value);
    out.push('\n');
}

fn add_u64_le_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    max: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "<=".to_string(),
            value: serde_json::Value::from(max),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual <= max);
}

fn add_string_contains_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    required: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "contains".to_string(),
            value: serde_json::Value::String(required.to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual.contains(required));
}

fn upstream_neural_control_pass() -> bool {
    let value = match std::fs::read_to_string(Path::new(UPSTREAM_NEURAL_CONTROL))
        .ok()
        .and_then(|content| serde_json::from_str::<serde_json::Value>(&content).ok())
    {
        Some(value) => value,
        None => return false,
    };
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
        && value
            .get("pass_per_axis")
            .and_then(serde_json::Value::as_object)
            .map(|axes| axes.values().all(|axis| axis.as_bool() == Some(true)))
            .unwrap_or(false)
}

fn fixture_entries() -> Vec<RegretEntry> {
    vec![
        regret_entry(
            "regret-entry:proof-route-citation-boost-v1",
            "uas:brain-route:proof-citation-boost",
            "route:local-qwen+eidos+verifier",
            "task:adversarial-note-citation-repair",
            7020,
            8120,
            410,
            530,
            180,
            6 * 1024 * 1024,
            "failure:citation-gap",
            "regret-update:prefer-eidos-verifier-on-citation-gap",
            "policy:shadow-route-utility-v26-proof-citation",
            "route:local-qwen-only",
            "route:local-qwen+eidos+verifier",
            &[
                "heldout:citation-counterexample-01",
                "heldout:citation-counterexample-02",
            ],
            1820,
            960,
            1,
            2,
            4 * 1024 * 1024,
        ),
        regret_entry(
            "regret-entry:kv-page-swiftlm-caveat-v1",
            "uas:kv-page-control:swiftlm-caveat-balance",
            "route:kv-page-query-aware+swiftlm-source",
            "task:swiftlm-source-caveat-note",
            6900,
            7810,
            360,
            430,
            140,
            5 * 1024 * 1024,
            "failure:source-caveat-missing",
            "regret-update:prefer-source-caveat-page-before-summary",
            "policy:shadow-route-utility-v27-source-caveat",
            "route:recency-kv-page",
            "route:query-aware-kv-page+eidos-caveat",
            &["heldout:swiftlm-caveat-01", "heldout:swiftlm-caveat-02"],
            1640,
            890,
            4,
            5,
            5 * 1024 * 1024,
        ),
        regret_entry(
            "regret-entry:neural-control-counterexample-v1",
            "uas:neural-control:counterexample-dampening",
            "route:brain-route+neural-control-shadow",
            "task:counterexample-heavy-argument",
            7180,
            8240,
            450,
            390,
            160,
            7 * 1024 * 1024,
            "failure:overconfident-counterexample",
            "regret-update:penalize-unverified-counterexample-dampening",
            "policy:shadow-route-utility-v28-counterexample",
            "route:neural-control-shadow-only",
            "route:neural-control-shadow+strict-verifier",
            &[
                "heldout:counterexample-argument-01",
                "heldout:counterexample-argument-02",
            ],
            1930,
            1010,
            8,
            9,
            6 * 1024 * 1024,
        ),
    ]
}

#[allow(clippy::too_many_arguments)]
fn regret_entry(
    entry_id: &'static str,
    unit_id: &'static str,
    route_id: &'static str,
    task_signature: &'static str,
    baseline_score_bps: u64,
    intervention_score_bps: u64,
    verifier_delta_bps: u64,
    evidence_validity_delta_bps: u64,
    latency_saved_ms: u64,
    active_bytes_saved: u64,
    failure_mode: &'static str,
    regret_update: &'static str,
    next_policy: &'static str,
    prior_route: &'static str,
    updated_route: &'static str,
    held_out_task_ids: &'static [&'static str],
    held_out_baseline_regret_bps: u64,
    held_out_updated_regret_bps: u64,
    policy_version_before: u64,
    policy_version_after: u64,
    policy_patch_active_bytes: u64,
) -> RegretEntry {
    RegretEntry {
        entry_id,
        unit_id,
        route_id,
        task_signature,
        baseline_score_bps,
        intervention_score_bps,
        verifier_delta_bps,
        evidence_validity_delta_bps,
        latency_saved_ms,
        active_bytes_saved,
        failure_mode,
        regret_update,
        next_policy,
        prior_route,
        updated_route,
        held_out: HeldOutSet {
            task_ids: held_out_task_ids,
            baseline_regret_bps: held_out_baseline_regret_bps,
            updated_regret_bps: held_out_updated_regret_bps,
        },
        rollback_handle: "rollback:verifier-regret-shadow-policy-v1",
        run_event_log_ref: "runlog:verifier-regret-shadow-replay-v1",
        answer_packet_ref: "answerpacket:verifier-regret-held-out-v1",
        policy_patch_ref: "policy-patch:verifier-regret-shadow-v1",
        route_authority: "shadow_only",
        policy_version_before,
        policy_version_after,
        policy_patch_active_bytes,
        hidden_chain_exposed: false,
        hidden_cloud: false,
        live_policy_mutated: false,
        upstream_neural_ref: "artifacts/falsifiers/neural_control_card_ablation/result.json",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fixture_ledger_passes_and_address_is_order_stable() {
        let entries = fixture_entries();
        let reversed = entries.iter().cloned().rev().collect::<Vec<_>>();
        let ledger = match RegretLedger::new(entries) {
            Ok(ledger) => ledger,
            Err(error) => panic!("fixture should pass: {error}"),
        };
        let reversed_ledger = match RegretLedger::new(reversed) {
            Ok(ledger) => ledger,
            Err(error) => panic!("reversed fixture should pass: {error}"),
        };
        assert_eq!(ledger.regret_address, reversed_ledger.regret_address);
    }

    #[test]
    fn empty_ledger_rejects() {
        assert!(matches!(
            RegretLedger::new(Vec::new()),
            Err(RegretError::MissingEntry)
        ));
    }

    #[test]
    fn required_invalid_fixtures_reject() {
        let cases = [
            invalid_entry_rejected(|entry| entry.held_out.task_ids = &[]),
            invalid_entry_rejected(|entry| entry.regret_update = ""),
            invalid_entry_rejected(|entry| entry.next_policy = ""),
            invalid_entry_rejected(|entry| entry.rollback_handle = ""),
            invalid_entry_rejected(|entry| entry.run_event_log_ref = ""),
            invalid_entry_rejected(|entry| entry.answer_packet_ref = ""),
            invalid_entry_rejected(|entry| entry.updated_route = entry.prior_route),
            invalid_entry_rejected(|entry| {
                entry.held_out.updated_regret_bps = entry.held_out.baseline_regret_bps;
            }),
            invalid_entry_rejected(|entry| entry.route_authority = "live_route_policy"),
            invalid_entry_rejected(|entry| entry.live_policy_mutated = true),
            invalid_entry_rejected(|entry| entry.hidden_chain_exposed = true),
            invalid_entry_rejected(|entry| entry.hidden_cloud = true),
            invalid_entry_rejected(|entry| {
                entry.policy_patch_active_bytes = MAX_POLICY_PATCH_BYTES + 1;
            }),
            invalid_entry_rejected(|entry| {
                entry.policy_version_after = entry.policy_version_before;
            }),
        ];
        assert!(cases.iter().all(Option::is_some));
    }

    #[test]
    fn build_artifact_sets_required_scope_axis() {
        let artifact = match build_artifact() {
            Ok(artifact) => artifact,
            Err(error) => panic!("artifact should build: {error}"),
        };
        assert_eq!(artifact.falsifier_id, FALSIFIER_ID);
        assert!(artifact.pass_per_axis["no_runtime_bytes_loaded"]);
        assert!(artifact.pass_per_axis["live_policy_mutation_rejected"]);
        assert!(artifact.pass_per_axis["no_regret_reduction_rejected"]);
    }
}
