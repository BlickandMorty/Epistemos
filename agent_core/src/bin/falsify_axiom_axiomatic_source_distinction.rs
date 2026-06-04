//! `falsify_axiom_axiomatic_source_distinction` -- formal-math source-card witness.
//!
//! Metadata-only witness for `F-AxiomAxiomatic-SourceDistinction`. It proves
//! Axiom, Axiomatic AI/OProver, UlamAI, Harmonic, Math Inc/OpenGauss, and Lean
//! tooling stay distinct source classes before route control may cite them.
//! External systems remain source handles and motifs only; they never become
//! hidden proof authority, hidden route authority, product claims, or imported
//! runtime/model bytes.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, sha256_hex,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-AxiomAxiomatic-SourceDistinction";
const FIXTURE_ID: &str = "axiom_axiomatic_source_distinction_v1";
const COMMAND: &str = "Tools/falsifiers/f_axiom_axiomatic_source_distinction.sh";
const RESULT: &str = "artifacts/falsifiers/axiom_axiomatic_source_distinction/result.json";
const UPSTREAM_ABLATION_SHADOW_RUN: &str = "artifacts/falsifiers/ablation_shadow_run/result.json";

const CURRENT_FENCE: &str = "fence:axiom-axiomatic-source-distinction:v1:ablation-shadow-run:v1";
const MIN_SOURCE_CLASS_COUNT: u64 = 8;
const MIN_MOTIF_CLASS_COUNT: u64 = 9;
const MIN_FALSE_MERGE_CASES: u64 = 6;
const MAX_SOURCE_CARD_METADATA_BYTES: u64 = 896 * 1024;
const STALE_OVERCLAIM_STRINGS: &[&str] = &[
    "cloud fallback",
    "cloud escalation",
    "optional escalation",
    "Fallback on failure",
    "70B-class LLM runs",
    "Every cloud-AI workflow",
    "cheapest way to run",
    "SSD = authoritative",
    "weights live on SSD",
    "70B behaves like",
    "Candidate · no harness yet",
];

#[cfg(test)]
const REQUIRED_AXES: &[&str] = &[
    "upstream_ablation_shadow_run_pass",
    "source_fixture_present",
    "fixture_ids_bound",
    "source_cards_bound",
    "source_ids_bound",
    "source_urls_bound",
    "source_titles_bound",
    "source_classes_bound",
    "motif_classes_bound",
    "license_notes_bound",
    "usage_notes_bound",
    "source_digests_bound",
    "claim_status_bound",
    "product_build_bound",
    "pro_status_bound",
    "allowed_use_bound",
    "forbidden_claims_bound",
    "route_impact_bound",
    "admission_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "false_merge_negatives_bound",
    "source_class_diversity_bound",
    "motif_class_diversity_bound",
    "source_urls_unique",
    "source_ids_unique",
    "external_sources_not_local_capability",
    "source_prior_only_route_impact",
    "stale_overclaim_strings_guarded",
    "no_hidden_source_authority",
    "no_hidden_route_authority",
    "no_hidden_proof_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_raw_code_import",
    "no_product_claim_promotion",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "metadata_bound",
    "axiom_axle_distinct_from_axiomatic_axprover",
    "axiom_axplorer_distinct_from_axiomatic_oprover",
    "harmonic_distinct_from_math_inc",
    "ulamai_distinct_from_axiom",
    "lean_tooling_distinct_from_provers",
    "math_inc_workflow_distinct_from_harmonic_artifact",
    "axiom_axiomatic_source_distinction_address_deterministic",
    "empty_fixture_rejected",
    "duplicate_source_id_rejected",
    "duplicate_source_url_rejected",
    "missing_fixture_id_rejected",
    "missing_source_card_rejected",
    "missing_source_id_rejected",
    "missing_source_url_rejected",
    "invalid_source_url_rejected",
    "missing_source_title_rejected",
    "missing_source_class_rejected",
    "unknown_source_class_rejected",
    "forbidden_merged_source_class_rejected",
    "missing_motif_class_rejected",
    "missing_license_rejected",
    "missing_usage_note_rejected",
    "missing_source_digest_rejected",
    "invalid_source_digest_rejected",
    "missing_claim_status_rejected",
    "product_claim_status_rejected",
    "missing_product_build_rejected",
    "mas_product_build_rejected",
    "missing_pro_status_rejected",
    "live_pro_status_rejected",
    "missing_allowed_use_rejected",
    "missing_forbidden_claims_rejected",
    "hidden_source_authority_rejected",
    "hidden_route_authority_rejected",
    "hidden_proof_authority_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_runtime_dependency_rejected",
    "raw_code_import_rejected",
    "product_claim_promotion_rejected",
    "missing_route_impact_rejected",
    "live_route_impact_rejected",
    "missing_admission_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "metadata_budget_rejected",
    "source_class_diversity_missing_rejected",
    "motif_class_diversity_missing_rejected",
    "false_merge_negatives_missing_rejected",
    "false_merge_not_rejected_rejected",
    "false_merge_same_source_rejected",
    "required_false_merge_pair_missing_rejected",
    "missing_stale_overclaim_guard_rejected",
    "stale_overclaim_string_rejected",
    "fixture_count",
    "source_card_count",
    "source_class_count",
    "motif_class_count",
    "false_merge_case_count",
    "stale_overclaim_string_count",
    "max_source_card_metadata_bytes",
    "axiom_axiomatic_source_distinction_address",
];

#[derive(Clone, Debug)]
// UAS: uas:axiom-axiomatic-source-distinction:source-card
// Plane: State + Controller + Verification
// Residency: metadata-only source handle; no code import or runtime/model bytes.
struct SourceCard {
    source_id: String,
    source_url: String,
    source_title: String,
    source_class: String,
    motif_class: String,
    license_note: String,
    usage_note: String,
    source_digest: String,
    claim_status: String,
    product_build: String,
    pro_status: String,
    allowed_use: String,
    forbidden_claims: Vec<String>,
    route_impact: String,
    admission: String,
    rollback_handle: String,
    run_event_log_ref: String,
    answer_packet_ref: String,
    compatibility_fence: String,
    privacy_class: String,
    metadata_bytes: u64,
    hidden_source_authority: bool,
    hidden_route_authority: bool,
    hidden_proof_authority: bool,
    hidden_chain_exposed: bool,
    cloud_runtime_dependency: bool,
    raw_code_imported: bool,
    product_claim_promoted: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:axiom-axiomatic-source-distinction:false-merge-negative
// Plane: Controller + Verification
// Residency: metadata-only negative fixture; rejects conflated source classes.
struct FalseMergeCase {
    case_id: String,
    left_source_id: String,
    right_source_id: String,
    reason: String,
    rejected: bool,
}

#[derive(Clone, Debug)]
// UAS: uas:axiom-axiomatic-source-distinction:fixture
// Plane: State + Controller + Verification
// Residency: offline source-card fixture; not live route authority.
struct SourceDistinctionFixture {
    fixture_id: String,
    fixture_scope: String,
    cards: Vec<SourceCard>,
    false_merge_cases: Vec<FalseMergeCase>,
}

// UAS: uas:axiom-axiomatic-source-distinction:metrics
// Plane: Verification
// Residency: metadata-only aggregation; no runtime/model bytes.
struct SourceDistinctionMetrics {
    fixture_count: u64,
    source_card_count: u64,
    source_class_count: u64,
    motif_class_count: u64,
    false_merge_case_count: u64,
    max_source_card_metadata_bytes: u64,
}

#[derive(Debug)]
// UAS: uas:axiom-axiomatic-source-distinction:registry
// Plane: Controller + Verification
// Residency: offline/shadow-only registry; source-prior authority only.
struct SourceDistinctionRegistry {
    fixtures: Vec<SourceDistinctionFixture>,
}

impl SourceDistinctionRegistry {
    fn new(fixtures: Vec<SourceDistinctionFixture>) -> Result<Self, SourceDistinctionError> {
        validate_fixtures(&fixtures)?;
        Ok(Self { fixtures })
    }

    fn records(&self) -> impl Iterator<Item = &SourceCard> {
        self.fixtures
            .iter()
            .flat_map(|fixture| fixture.cards.iter())
    }

    fn false_merges(&self) -> impl Iterator<Item = &FalseMergeCase> {
        self.fixtures
            .iter()
            .flat_map(|fixture| fixture.false_merge_cases.iter())
    }

    fn metrics(&self) -> SourceDistinctionMetrics {
        let source_classes = self
            .records()
            .map(|card| card.source_class.as_str())
            .collect::<BTreeSet<_>>();
        let motif_classes = self
            .records()
            .map(|card| card.motif_class.as_str())
            .collect::<BTreeSet<_>>();
        let max_source_card_metadata_bytes = self
            .records()
            .map(|card| card.metadata_bytes)
            .max()
            .unwrap_or(0);

        SourceDistinctionMetrics {
            fixture_count: self.fixtures.len() as u64,
            source_card_count: self.records().count() as u64,
            source_class_count: source_classes.len() as u64,
            motif_class_count: motif_classes.len() as u64,
            false_merge_case_count: self.false_merges().count() as u64,
            max_source_card_metadata_bytes,
        }
    }

    fn address(&self) -> String {
        let mut card_rows = self
            .records()
            .map(|card| {
                format!(
                    "{}|{}|{}|{}|{}|{}",
                    card.source_id,
                    card.source_url,
                    card.source_class,
                    card.motif_class,
                    card.source_digest,
                    card.route_impact
                )
            })
            .collect::<Vec<_>>();
        card_rows.sort();
        let mut merge_rows = self
            .false_merges()
            .map(|case| {
                format!(
                    "{}|{}|{}|{}|{}",
                    case.case_id,
                    case.left_source_id,
                    case.right_source_id,
                    case.reason,
                    case.rejected
                )
            })
            .collect::<Vec<_>>();
        merge_rows.sort();
        let digest =
            sha256_hex(format!("{}::{}", card_rows.join("\n"), merge_rows.join("\n")).as_bytes());
        format!(
            "uas:axiom-axiomatic-source-distinction:sha256:{}",
            digest.trim_start_matches("sha256:")
        )
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
// UAS: axiom-axiomatic-source-distinction-error
// Plane: Verification
// Residency: MetadataOnly
enum SourceDistinctionError {
    EmptyFixture,
    DuplicateSourceId,
    DuplicateSourceUrl,
    MissingFixtureId,
    MissingSourceCard,
    MissingSourceId,
    MissingSourceUrl,
    InvalidSourceUrl,
    MissingSourceTitle,
    MissingSourceClass,
    UnknownSourceClass,
    ForbiddenMergedSourceClass,
    MissingMotifClass,
    MissingLicense,
    MissingUsageNote,
    MissingSourceDigest,
    InvalidSourceDigest,
    MissingClaimStatus,
    ProductClaimStatus,
    MissingProductBuild,
    MasProductBuild,
    MissingProStatus,
    LiveProStatus,
    MissingAllowedUse,
    MissingForbiddenClaims,
    HiddenSourceAuthority,
    HiddenRouteAuthority,
    HiddenProofAuthority,
    HiddenChainExposure,
    CloudRuntimeDependency,
    RawCodeImport,
    ProductClaimPromotion,
    MissingRouteImpact,
    LiveRouteImpact,
    MissingAdmission,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    IncompatibleFence,
    InvalidPrivacy,
    RuntimeBytes,
    ModelBytes,
    MetadataBudget,
    SourceClassDiversity,
    MotifClassDiversity,
    FalseMergeNegativesMissing,
    FalseMergeNotRejected,
    FalseMergeSameSource,
    RequiredFalseMergePairMissing,
    MissingStaleOverclaimGuard,
    StaleOverclaimString,
}

fn validate_fixtures(fixtures: &[SourceDistinctionFixture]) -> Result<(), SourceDistinctionError> {
    if fixtures.is_empty() {
        return Err(SourceDistinctionError::EmptyFixture);
    }

    let mut fixture_ids = BTreeSet::new();
    let mut source_ids = BTreeSet::new();
    let mut source_urls = BTreeSet::new();
    let mut source_classes = BTreeSet::new();
    let mut motif_classes = BTreeSet::new();
    let mut false_merge_pairs = BTreeSet::new();
    let mut source_id_to_class = BTreeMap::new();
    let mut forbidden_claims = BTreeSet::new();

    for fixture in fixtures {
        if fixture.fixture_id.is_empty() || !fixture_ids.insert(fixture.fixture_id.as_str()) {
            return Err(SourceDistinctionError::MissingFixtureId);
        }
        if fixture.fixture_scope != "metadata_only_shadow_source_cards" {
            return Err(SourceDistinctionError::LiveRouteImpact);
        }
        if fixture.cards.is_empty() {
            return Err(SourceDistinctionError::MissingSourceCard);
        }
        if fixture.false_merge_cases.is_empty() {
            return Err(SourceDistinctionError::FalseMergeNegativesMissing);
        }

        for card in &fixture.cards {
            validate_card(card)?;
            if !source_ids.insert(card.source_id.as_str()) {
                return Err(SourceDistinctionError::DuplicateSourceId);
            }
            if !source_urls.insert(card.source_url.as_str()) {
                return Err(SourceDistinctionError::DuplicateSourceUrl);
            }
            source_classes.insert(card.source_class.as_str());
            motif_classes.insert(card.motif_class.as_str());
            for forbidden_claim in &card.forbidden_claims {
                forbidden_claims.insert(forbidden_claim.as_str());
            }
            source_id_to_class.insert(card.source_id.as_str(), card.source_class.as_str());
        }

        for case in &fixture.false_merge_cases {
            validate_false_merge(case, &source_id_to_class)?;
            false_merge_pairs.insert(pair_key(&case.left_source_id, &case.right_source_id));
        }
    }

    if source_classes.len() < MIN_SOURCE_CLASS_COUNT as usize {
        return Err(SourceDistinctionError::SourceClassDiversity);
    }
    if motif_classes.len() < MIN_MOTIF_CLASS_COUNT as usize {
        return Err(SourceDistinctionError::MotifClassDiversity);
    }
    if false_merge_pairs.len() < MIN_FALSE_MERGE_CASES as usize {
        return Err(SourceDistinctionError::FalseMergeNegativesMissing);
    }
    for required in required_false_merge_pairs() {
        if !false_merge_pairs.contains(required) {
            return Err(SourceDistinctionError::RequiredFalseMergePairMissing);
        }
    }
    for stale_claim in STALE_OVERCLAIM_STRINGS {
        if !forbidden_claims.contains(stale_claim) {
            return Err(SourceDistinctionError::MissingStaleOverclaimGuard);
        }
    }

    Ok(())
}

fn validate_card(card: &SourceCard) -> Result<(), SourceDistinctionError> {
    if card.source_id.is_empty() {
        return Err(SourceDistinctionError::MissingSourceId);
    }
    if card.source_url.is_empty() {
        return Err(SourceDistinctionError::MissingSourceUrl);
    }
    if !card.source_url.starts_with("https://") {
        return Err(SourceDistinctionError::InvalidSourceUrl);
    }
    if card.source_title.is_empty() {
        return Err(SourceDistinctionError::MissingSourceTitle);
    }
    if card.source_class.is_empty() {
        return Err(SourceDistinctionError::MissingSourceClass);
    }
    if !known_source_class(&card.source_class) {
        return Err(SourceDistinctionError::UnknownSourceClass);
    }
    if card.source_class == "axiom_axiomatic_merged" {
        return Err(SourceDistinctionError::ForbiddenMergedSourceClass);
    }
    if card.motif_class.is_empty() {
        return Err(SourceDistinctionError::MissingMotifClass);
    }
    if card.license_note.is_empty() {
        return Err(SourceDistinctionError::MissingLicense);
    }
    if card.usage_note.is_empty() {
        return Err(SourceDistinctionError::MissingUsageNote);
    }
    if card.source_digest.is_empty() {
        return Err(SourceDistinctionError::MissingSourceDigest);
    }
    if !valid_sha256_digest(&card.source_digest) {
        return Err(SourceDistinctionError::InvalidSourceDigest);
    }
    if card.claim_status.is_empty() {
        return Err(SourceDistinctionError::MissingClaimStatus);
    }
    if !matches!(
        card.claim_status.as_str(),
        "source_handle_only" | "external_reference_only" | "motif_candidate_only"
    ) {
        return Err(SourceDistinctionError::ProductClaimStatus);
    }
    if card.product_build.is_empty() {
        return Err(SourceDistinctionError::MissingProductBuild);
    }
    if card.product_build != "Pro" {
        return Err(SourceDistinctionError::MasProductBuild);
    }
    if card.pro_status.is_empty() {
        return Err(SourceDistinctionError::MissingProStatus);
    }
    if matches!(card.pro_status.as_str(), "Live") {
        return Err(SourceDistinctionError::LiveProStatus);
    }
    if !matches!(
        card.pro_status.as_str(),
        "ResearchCandidate" | "VaultPreserved" | "Gated"
    ) {
        return Err(SourceDistinctionError::MissingProStatus);
    }
    if card.allowed_use.is_empty() {
        return Err(SourceDistinctionError::MissingAllowedUse);
    }
    if card.forbidden_claims.is_empty() || card.forbidden_claims.iter().any(String::is_empty) {
        return Err(SourceDistinctionError::MissingForbiddenClaims);
    }
    if [
        card.source_title.as_str(),
        card.claim_status.as_str(),
        card.allowed_use.as_str(),
        card.usage_note.as_str(),
        card.route_impact.as_str(),
        card.admission.as_str(),
    ]
    .iter()
    .any(|value| contains_stale_overclaim_string(value))
    {
        return Err(SourceDistinctionError::StaleOverclaimString);
    }
    if card.route_impact.is_empty() {
        return Err(SourceDistinctionError::MissingRouteImpact);
    }
    if card.route_impact != "source_prior_only" {
        return Err(SourceDistinctionError::LiveRouteImpact);
    }
    if card.admission.is_empty() {
        return Err(SourceDistinctionError::MissingAdmission);
    }
    if card.rollback_handle.is_empty() {
        return Err(SourceDistinctionError::MissingRollback);
    }
    if card.run_event_log_ref.is_empty() {
        return Err(SourceDistinctionError::MissingRunEventLog);
    }
    if card.answer_packet_ref.is_empty() {
        return Err(SourceDistinctionError::MissingAnswerPacket);
    }
    if card.compatibility_fence != CURRENT_FENCE {
        return Err(SourceDistinctionError::IncompatibleFence);
    }
    if !valid_privacy_class(&card.privacy_class) {
        return Err(SourceDistinctionError::InvalidPrivacy);
    }
    if card.hidden_source_authority {
        return Err(SourceDistinctionError::HiddenSourceAuthority);
    }
    if card.hidden_route_authority {
        return Err(SourceDistinctionError::HiddenRouteAuthority);
    }
    if card.hidden_proof_authority {
        return Err(SourceDistinctionError::HiddenProofAuthority);
    }
    if card.hidden_chain_exposed {
        return Err(SourceDistinctionError::HiddenChainExposure);
    }
    if card.cloud_runtime_dependency {
        return Err(SourceDistinctionError::CloudRuntimeDependency);
    }
    if card.raw_code_imported {
        return Err(SourceDistinctionError::RawCodeImport);
    }
    if card.product_claim_promoted {
        return Err(SourceDistinctionError::ProductClaimPromotion);
    }
    if card.runtime_bytes_loaded > 0 {
        return Err(SourceDistinctionError::RuntimeBytes);
    }
    if card.model_bytes_loaded > 0 {
        return Err(SourceDistinctionError::ModelBytes);
    }
    if card.metadata_bytes > MAX_SOURCE_CARD_METADATA_BYTES {
        return Err(SourceDistinctionError::MetadataBudget);
    }
    Ok(())
}

fn validate_false_merge(
    case: &FalseMergeCase,
    source_id_to_class: &BTreeMap<&str, &str>,
) -> Result<(), SourceDistinctionError> {
    if case.case_id.is_empty() || case.reason.is_empty() {
        return Err(SourceDistinctionError::FalseMergeNegativesMissing);
    }
    if case.left_source_id == case.right_source_id {
        return Err(SourceDistinctionError::FalseMergeSameSource);
    }
    let Some(left_class) = source_id_to_class.get(case.left_source_id.as_str()) else {
        return Err(SourceDistinctionError::FalseMergeNegativesMissing);
    };
    let Some(right_class) = source_id_to_class.get(case.right_source_id.as_str()) else {
        return Err(SourceDistinctionError::FalseMergeNegativesMissing);
    };
    if left_class == right_class {
        return Err(SourceDistinctionError::FalseMergeSameSource);
    }
    if !case.rejected {
        return Err(SourceDistinctionError::FalseMergeNotRejected);
    }
    Ok(())
}

fn known_source_class(value: &str) -> bool {
    matches!(
        value,
        "axiom_axle"
            | "axiom_axplorer"
            | "axiomatic_axprover"
            | "axiomatic_oprover"
            | "ulamai"
            | "harmonic_aristotle"
            | "math_inc_opengauss"
            | "lean_tooling"
    )
}

fn valid_sha256_digest(value: &str) -> bool {
    let Some(hex) = value.strip_prefix("sha256:") else {
        return false;
    };
    hex.len() == 64 && hex.chars().all(|ch| ch.is_ascii_hexdigit())
}

fn valid_privacy_class(value: &str) -> bool {
    matches!(
        value,
        "public_source_metadata" | "local_private" | "project_private"
    )
}

fn contains_stale_overclaim_string(value: &str) -> bool {
    STALE_OVERCLAIM_STRINGS
        .iter()
        .any(|stale| value.contains(stale))
}

fn pair_key(left: &str, right: &str) -> String {
    if left <= right {
        format!("{left}::{right}")
    } else {
        format!("{right}::{left}")
    }
}

fn required_false_merge_pairs() -> &'static [String] {
    static REQUIRED: std::sync::OnceLock<Vec<String>> = std::sync::OnceLock::new();
    REQUIRED
        .get_or_init(|| {
            vec![
                pair_key("axiom-axle-engine", "axiomatic-axprover-base"),
                pair_key("axiom-axplorer-search", "axiomatic-oprover-traces"),
                pair_key("harmonic-aristotle-imo", "math-inc-opengauss-workflow"),
                pair_key("ulamai-local-lean-loop", "axiom-axle-engine"),
                pair_key("leansearch-pantograph-tooling", "axiomatic-axprover-base"),
                pair_key("math-inc-gauss", "harmonic-aristotle-imo"),
            ]
        })
        .as_slice()
}

fn invalid_fixture_axes(valid_fixtures: &[SourceDistinctionFixture]) -> Vec<(&'static str, bool)> {
    let mut cases = Vec::with_capacity(45);
    cases.push((
        "empty_fixture_rejected",
        SourceDistinctionRegistry::new(Vec::new()).is_err(),
    ));
    cases.push((
        "duplicate_source_id_rejected",
        rejects_card(valid_fixtures, |card| {
            card.source_id = "axiom-axle-engine".to_string()
        }),
    ));
    cases.push((
        "duplicate_source_url_rejected",
        rejects_card(valid_fixtures, |card| {
            card.source_url = "https://axle.axiommath.ai/".to_string()
        }),
    ));
    cases.push((
        "missing_fixture_id_rejected",
        rejects(valid_fixtures, |fixtures| fixtures[0].fixture_id.clear()),
    ));
    cases.push((
        "missing_source_card_rejected",
        rejects(valid_fixtures, |fixtures| fixtures[0].cards.clear()),
    ));
    cases.push((
        "missing_source_id_rejected",
        rejects_card(valid_fixtures, |card| card.source_id.clear()),
    ));
    cases.push((
        "missing_source_url_rejected",
        rejects_card(valid_fixtures, |card| card.source_url.clear()),
    ));
    cases.push((
        "invalid_source_url_rejected",
        rejects_card(valid_fixtures, |card| {
            card.source_url = "http://example.invalid".to_string()
        }),
    ));
    cases.push((
        "missing_source_title_rejected",
        rejects_card(valid_fixtures, |card| card.source_title.clear()),
    ));
    cases.push((
        "missing_source_class_rejected",
        rejects_card(valid_fixtures, |card| card.source_class.clear()),
    ));
    cases.push((
        "unknown_source_class_rejected",
        rejects_card(valid_fixtures, |card| {
            card.source_class = "unknown_prover".to_string()
        }),
    ));
    cases.push((
        "forbidden_merged_source_class_rejected",
        rejects_card(valid_fixtures, |card| {
            card.source_class = "axiom_axiomatic_merged".to_string()
        }),
    ));
    cases.push((
        "missing_motif_class_rejected",
        rejects_card(valid_fixtures, |card| card.motif_class.clear()),
    ));
    cases.push((
        "missing_license_rejected",
        rejects_card(valid_fixtures, |card| card.license_note.clear()),
    ));
    cases.push((
        "missing_usage_note_rejected",
        rejects_card(valid_fixtures, |card| card.usage_note.clear()),
    ));
    cases.push((
        "missing_source_digest_rejected",
        rejects_card(valid_fixtures, |card| card.source_digest.clear()),
    ));
    cases.push((
        "invalid_source_digest_rejected",
        rejects_card(valid_fixtures, |card| {
            card.source_digest = "sha256:not-hex".to_string()
        }),
    ));
    cases.push((
        "missing_claim_status_rejected",
        rejects_card(valid_fixtures, |card| card.claim_status.clear()),
    ));
    cases.push((
        "product_claim_status_rejected",
        rejects_card(valid_fixtures, |card| {
            card.claim_status = "local_capability_shipped".to_string()
        }),
    ));
    cases.push((
        "missing_product_build_rejected",
        rejects_card(valid_fixtures, |card| card.product_build.clear()),
    ));
    cases.push((
        "mas_product_build_rejected",
        rejects_card(valid_fixtures, |card| {
            card.product_build = "MAS".to_string()
        }),
    ));
    cases.push((
        "missing_pro_status_rejected",
        rejects_card(valid_fixtures, |card| card.pro_status.clear()),
    ));
    cases.push((
        "live_pro_status_rejected",
        rejects_card(valid_fixtures, |card| card.pro_status = "Live".to_string()),
    ));
    cases.push((
        "missing_allowed_use_rejected",
        rejects_card(valid_fixtures, |card| card.allowed_use.clear()),
    ));
    cases.push((
        "missing_forbidden_claims_rejected",
        rejects_card(valid_fixtures, |card| card.forbidden_claims.clear()),
    ));
    cases.push((
        "hidden_source_authority_rejected",
        rejects_card(valid_fixtures, |card| card.hidden_source_authority = true),
    ));
    cases.push((
        "hidden_route_authority_rejected",
        rejects_card(valid_fixtures, |card| card.hidden_route_authority = true),
    ));
    cases.push((
        "hidden_proof_authority_rejected",
        rejects_card(valid_fixtures, |card| card.hidden_proof_authority = true),
    ));
    cases.push((
        "hidden_chain_exposure_rejected",
        rejects_card(valid_fixtures, |card| card.hidden_chain_exposed = true),
    ));
    cases.push((
        "cloud_runtime_dependency_rejected",
        rejects_card(valid_fixtures, |card| card.cloud_runtime_dependency = true),
    ));
    cases.push((
        "raw_code_import_rejected",
        rejects_card(valid_fixtures, |card| card.raw_code_imported = true),
    ));
    cases.push((
        "product_claim_promotion_rejected",
        rejects_card(valid_fixtures, |card| card.product_claim_promoted = true),
    ));
    cases.push((
        "missing_route_impact_rejected",
        rejects_card(valid_fixtures, |card| card.route_impact.clear()),
    ));
    cases.push((
        "live_route_impact_rejected",
        rejects_card(valid_fixtures, |card| {
            card.route_impact = "live_route_authority".to_string()
        }),
    ));
    cases.push((
        "missing_admission_rejected",
        rejects_card(valid_fixtures, |card| card.admission.clear()),
    ));
    cases.push((
        "missing_rollback_rejected",
        rejects_card(valid_fixtures, |card| card.rollback_handle.clear()),
    ));
    cases.push((
        "missing_run_event_log_rejected",
        rejects_card(valid_fixtures, |card| card.run_event_log_ref.clear()),
    ));
    cases.push((
        "missing_answer_packet_rejected",
        rejects_card(valid_fixtures, |card| card.answer_packet_ref.clear()),
    ));
    cases.push((
        "incompatible_fence_rejected",
        rejects_card(valid_fixtures, |card| {
            card.compatibility_fence = "fence:stale".to_string()
        }),
    ));
    cases.push((
        "invalid_privacy_rejected",
        rejects_card(valid_fixtures, |card| {
            card.privacy_class = "hidden_chain".to_string()
        }),
    ));
    cases.push((
        "runtime_bytes_rejected",
        rejects_card(valid_fixtures, |card| card.runtime_bytes_loaded = 1),
    ));
    cases.push((
        "model_bytes_rejected",
        rejects_card(valid_fixtures, |card| card.model_bytes_loaded = 1),
    ));
    cases.push((
        "metadata_budget_rejected",
        rejects_card(valid_fixtures, |card| {
            card.metadata_bytes = MAX_SOURCE_CARD_METADATA_BYTES + 1
        }),
    ));
    cases.push((
        "source_class_diversity_missing_rejected",
        rejects(valid_fixtures, |fixtures| {
            for card in &mut fixtures[0].cards {
                if card.source_class != "axiom_axle" {
                    card.source_class = "axiom_axplorer".to_string();
                }
            }
        }),
    ));
    cases.push((
        "motif_class_diversity_missing_rejected",
        rejects(valid_fixtures, |fixtures| {
            for card in &mut fixtures[0].cards {
                card.motif_class = "proof_agent_feedback".to_string();
            }
        }),
    ));
    cases.push((
        "false_merge_negatives_missing_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0].false_merge_cases.clear()
        }),
    ));
    cases.push((
        "false_merge_not_rejected_rejected",
        rejects_false_merge(valid_fixtures, |case| case.rejected = false),
    ));
    cases.push((
        "false_merge_same_source_rejected",
        rejects_false_merge(valid_fixtures, |case| {
            case.right_source_id = case.left_source_id.clone()
        }),
    ));
    cases.push((
        "required_false_merge_pair_missing_rejected",
        rejects(valid_fixtures, |fixtures| {
            fixtures[0]
                .false_merge_cases
                .retain(|case| case.case_id != "false-merge:axiom-axiomatic-prover");
        }),
    ));
    cases.push((
        "missing_stale_overclaim_guard_rejected",
        rejects(valid_fixtures, |fixtures| {
            for fixture in fixtures {
                for card in &mut fixture.cards {
                    card.forbidden_claims
                        .retain(|claim| claim != "cloud fallback");
                }
            }
        }),
    ));
    cases.push((
        "stale_overclaim_string_rejected",
        rejects_card(valid_fixtures, |card| {
            card.allowed_use = "cloud fallback".to_string()
        }),
    ));
    cases
}

fn rejects_card(
    fixtures: &[SourceDistinctionFixture],
    mutate: impl FnOnce(&mut SourceCard),
) -> bool {
    rejects(fixtures, |fixtures| mutate(&mut fixtures[0].cards[1]))
}

fn rejects_false_merge(
    fixtures: &[SourceDistinctionFixture],
    mutate: impl FnOnce(&mut FalseMergeCase),
) -> bool {
    rejects(fixtures, |fixtures| {
        mutate(&mut fixtures[0].false_merge_cases[0])
    })
}

fn rejects(
    fixtures: &[SourceDistinctionFixture],
    mutate: impl FnOnce(&mut Vec<SourceDistinctionFixture>),
) -> bool {
    let mut mutated = fixtures.to_vec();
    mutate(&mut mutated);
    SourceDistinctionRegistry::new(mutated).is_err()
}

fn fixture_source_distinctions() -> Vec<SourceDistinctionFixture> {
    vec![SourceDistinctionFixture {
        fixture_id: "formal-math-source-card-fixture".to_string(),
        fixture_scope: "metadata_only_shadow_source_cards".to_string(),
        cards: vec![
            source_card(
                "axiom-axle-engine",
                "https://axle.axiommath.ai/",
                "Axiom AXLE",
                "axiom_axle",
                "proof_verification_engine",
                "source-handle only; license must be rechecked before any code or API use",
                "record proof-verification-engine motif and source handle; no local capability claim",
            ),
            source_card(
                "axiom-axplorer-search",
                "https://github.com/AxiomMath/Axplorer",
                "Axiom Axplorer",
                "axiom_axplorer",
                "construction_search",
                "repository source-handle only; license must be checked before any reuse",
                "record generate-repair-score-select motif for offline PatternBoost comparisons",
            ),
            source_card(
                "axiomatic-axprover-base",
                "https://github.com/Axiomatic-AI/ax-prover-base",
                "Axiomatic AI AxProverBase",
                "axiomatic_axprover",
                "proof_agent_feedback",
                "repository source-handle only; no vendoring in this witness",
                "record proof-agent/compiler-feedback motif as external reference",
            ),
            source_card(
                "axiomatic-oprover-traces",
                "https://arxiv.org/abs/2605.17283",
                "OProver",
                "axiomatic_oprover",
                "proof_trace_retrieval_repair",
                "paper source-handle only; implementation status not imported",
                "record proof-trace and retrieval/repair route-label motif",
            ),
            source_card(
                "ulamai-local-lean-loop",
                "https://github.com/ulamai/ulamai",
                "UlamAI",
                "ulamai",
                "local_lean_formalization_loop",
                "repository source-handle only; license must be checked before any reuse",
                "record local/open Lean formalization loop motif",
            ),
            source_card(
                "harmonic-aristotle-imo",
                "https://github.com/harmonic-ai/IMO2025",
                "Harmonic Aristotle IMO2025 artifacts",
                "harmonic_aristotle",
                "public_lean_artifact_replay",
                "repository artifact source-handle only; no product proof claim",
                "record public Lean artifact/replay standard as verifier fixture motif",
            ),
            source_card(
                "math-inc-opengauss-workflow",
                "https://github.com/math-inc/OpenGauss",
                "Math Inc OpenGauss",
                "math_inc_opengauss",
                "workflow_orchestration",
                "repository source-handle only; no workflow import in this witness",
                "record refactor/golf/review/checkpoint/autoformalize workflow motif",
            ),
            source_card(
                "math-inc-gauss",
                "https://www.math.inc/gauss",
                "Math Inc Gauss",
                "math_inc_opengauss",
                "company_workflow_reference",
                "website source-handle only; product claims are external",
                "record company workflow reference without promoting Epistemos capability",
            ),
            source_card(
                "leansearch-pantograph-tooling",
                "https://leansearch.net/",
                "LeanSearch and Lean tooling",
                "lean_tooling",
                "search_adapter_tooling",
                "tooling source-handle only; adapter work remains gated",
                "record Lean search/tooling adapter motif distinct from prover authority",
            ),
        ],
        false_merge_cases: vec![
            false_merge(
                "false-merge:axiom-axiomatic-prover",
                "axiom-axle-engine",
                "axiomatic-axprover-base",
                "Axiom AXLE engine handle and Axiomatic AxProverBase proof-agent handle are different source classes.",
            ),
            false_merge(
                "false-merge:axplorer-oprover",
                "axiom-axplorer-search",
                "axiomatic-oprover-traces",
                "Axplorer construction search and OProver trace/retrieval repair are different motifs.",
            ),
            false_merge(
                "false-merge:harmonic-math-inc-workflow",
                "harmonic-aristotle-imo",
                "math-inc-opengauss-workflow",
                "Harmonic public artifacts and Math Inc workflow orchestration are not interchangeable proof authority.",
            ),
            false_merge(
                "false-merge:ulamai-axiom",
                "ulamai-local-lean-loop",
                "axiom-axle-engine",
                "UlamAI local/open Lean loop and Axiom AXLE source handle stay distinct.",
            ),
            false_merge(
                "false-merge:lean-tooling-axprover",
                "leansearch-pantograph-tooling",
                "axiomatic-axprover-base",
                "Lean tooling/search adapters are not proof-agent authority.",
            ),
            false_merge(
                "false-merge:gauss-harmonic",
                "math-inc-gauss",
                "harmonic-aristotle-imo",
                "Math Inc company workflow reference is not the Harmonic replay artifact class.",
            ),
        ],
    }]
}

fn source_card(
    source_id: &str,
    source_url: &str,
    source_title: &str,
    source_class: &str,
    motif_class: &str,
    license_note: &str,
    usage_note: &str,
) -> SourceCard {
    SourceCard {
        source_id: source_id.to_string(),
        source_url: source_url.to_string(),
        source_title: source_title.to_string(),
        source_class: source_class.to_string(),
        motif_class: motif_class.to_string(),
        license_note: license_note.to_string(),
        usage_note: usage_note.to_string(),
        source_digest: sha256_hex(format!("{source_id}:{source_url}:{source_title}").as_bytes()),
        claim_status: "source_handle_only".to_string(),
        product_build: "Pro".to_string(),
        pro_status: "ResearchCandidate".to_string(),
        allowed_use: "source-card-motif-reference-only".to_string(),
        forbidden_claims: vec![
            "cloud fallback".to_string(),
            "cloud escalation".to_string(),
            "optional escalation".to_string(),
            "Fallback on failure".to_string(),
            "70B-class LLM runs".to_string(),
            "Every cloud-AI workflow".to_string(),
            "cheapest way to run".to_string(),
            "SSD = authoritative".to_string(),
            "weights live on SSD".to_string(),
            "70B behaves like".to_string(),
            "Candidate · no harness yet".to_string(),
            "do-not-claim-local-prover-integration".to_string(),
            "do-not-claim-live-route-authority".to_string(),
            "do-not-vendor-code-from-this-witness".to_string(),
        ],
        route_impact: "source_prior_only".to_string(),
        admission: "SCOPE-Rex/SovereignGate source-card admission; no live authority".to_string(),
        rollback_handle: format!("rollback:source-distinction:{source_id}"),
        run_event_log_ref: format!("run-event-log:source-distinction:{source_id}"),
        answer_packet_ref: format!("answer-packet:source-distinction:{source_id}"),
        compatibility_fence: CURRENT_FENCE.to_string(),
        privacy_class: "public_source_metadata".to_string(),
        metadata_bytes: 384 * 1024,
        hidden_source_authority: false,
        hidden_route_authority: false,
        hidden_proof_authority: false,
        hidden_chain_exposed: false,
        cloud_runtime_dependency: false,
        raw_code_imported: false,
        product_claim_promoted: false,
        runtime_bytes_loaded: 0,
        model_bytes_loaded: 0,
    }
}

fn false_merge(
    case_id: &str,
    left_source_id: &str,
    right_source_id: &str,
    reason: &str,
) -> FalseMergeCase {
    FalseMergeCase {
        case_id: case_id.to_string(),
        left_source_id: left_source_id.to_string(),
        right_source_id: right_source_id.to_string(),
        reason: reason.to_string(),
        rejected: true,
    }
}

fn upstream_artifact_pass(path: &str) -> bool {
    let Ok(bytes) = std::fs::read(path) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, SourceDistinctionError> {
    let registry = SourceDistinctionRegistry::new(fixture_source_distinctions())?;
    let metrics = registry.metrics();
    let address = registry.address();
    let mut reversed = fixture_source_distinctions();
    reversed.reverse();
    for fixture in &mut reversed {
        fixture.cards.reverse();
        fixture.false_merge_cases.reverse();
    }
    let deterministic = SourceDistinctionRegistry::new(reversed)?.address() == address;
    let invalid_axes = invalid_fixture_axes(&registry.fixtures);
    let source_classes = registry
        .records()
        .map(|card| card.source_class.as_str())
        .collect::<BTreeSet<_>>();
    let pair_set = registry
        .false_merges()
        .map(|case| pair_key(&case.left_source_id, &case.right_source_id))
        .collect::<BTreeSet<_>>();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_ablation_shadow_run_pass",
            upstream_artifact_pass(UPSTREAM_ABLATION_SHADOW_RUN),
        ),
        ("source_fixture_present", metrics.fixture_count > 0),
        (
            "fixture_ids_bound",
            registry
                .fixtures
                .iter()
                .all(|fixture| !fixture.fixture_id.is_empty()),
        ),
        ("source_cards_bound", metrics.source_card_count == 9),
        (
            "source_ids_bound",
            registry.records().all(|card| !card.source_id.is_empty()),
        ),
        (
            "source_urls_bound",
            registry
                .records()
                .all(|card| card.source_url.starts_with("https://")),
        ),
        (
            "source_titles_bound",
            registry.records().all(|card| !card.source_title.is_empty()),
        ),
        (
            "source_classes_bound",
            source_classes.iter().copied().all(known_source_class),
        ),
        (
            "motif_classes_bound",
            metrics.motif_class_count >= MIN_MOTIF_CLASS_COUNT,
        ),
        (
            "license_notes_bound",
            registry.records().all(|card| !card.license_note.is_empty()),
        ),
        (
            "usage_notes_bound",
            registry.records().all(|card| !card.usage_note.is_empty()),
        ),
        (
            "source_digests_bound",
            registry
                .records()
                .all(|card| valid_sha256_digest(&card.source_digest)),
        ),
        (
            "claim_status_bound",
            registry.records().all(|card| {
                matches!(
                    card.claim_status.as_str(),
                    "source_handle_only" | "external_reference_only" | "motif_candidate_only"
                )
            }),
        ),
        (
            "product_build_bound",
            registry.records().all(|card| card.product_build == "Pro"),
        ),
        (
            "pro_status_bound",
            registry.records().all(|card| {
                matches!(
                    card.pro_status.as_str(),
                    "ResearchCandidate" | "VaultPreserved" | "Gated"
                )
            }),
        ),
        (
            "allowed_use_bound",
            registry.records().all(|card| !card.allowed_use.is_empty()),
        ),
        (
            "forbidden_claims_bound",
            registry
                .records()
                .all(|card| !card.forbidden_claims.is_empty()),
        ),
        (
            "route_impact_bound",
            registry
                .records()
                .all(|card| card.route_impact == "source_prior_only"),
        ),
        (
            "admission_bound",
            registry.records().all(|card| !card.admission.is_empty()),
        ),
        (
            "rollback_bound",
            registry
                .records()
                .all(|card| !card.rollback_handle.is_empty()),
        ),
        (
            "run_event_log_bound",
            registry
                .records()
                .all(|card| !card.run_event_log_ref.is_empty()),
        ),
        (
            "answer_packet_ref_bound",
            registry
                .records()
                .all(|card| !card.answer_packet_ref.is_empty()),
        ),
        (
            "compatibility_fence_bound",
            registry
                .records()
                .all(|card| card.compatibility_fence == CURRENT_FENCE),
        ),
        (
            "privacy_classes_bound",
            registry
                .records()
                .all(|card| valid_privacy_class(&card.privacy_class)),
        ),
        (
            "false_merge_negatives_bound",
            metrics.false_merge_case_count >= MIN_FALSE_MERGE_CASES
                && registry.false_merges().all(|case| case.rejected),
        ),
        (
            "source_class_diversity_bound",
            metrics.source_class_count >= MIN_SOURCE_CLASS_COUNT,
        ),
        (
            "motif_class_diversity_bound",
            metrics.motif_class_count >= MIN_MOTIF_CLASS_COUNT,
        ),
        (
            "source_urls_unique",
            registry
                .records()
                .map(|card| card.source_url.as_str())
                .collect::<BTreeSet<_>>()
                .len()
                == metrics.source_card_count as usize,
        ),
        (
            "source_ids_unique",
            registry
                .records()
                .map(|card| card.source_id.as_str())
                .collect::<BTreeSet<_>>()
                .len()
                == metrics.source_card_count as usize,
        ),
        (
            "external_sources_not_local_capability",
            registry
                .records()
                .all(|card| card.claim_status == "source_handle_only"),
        ),
        (
            "source_prior_only_route_impact",
            registry
                .records()
                .all(|card| card.route_impact == "source_prior_only"),
        ),
        (
            "stale_overclaim_strings_guarded",
            STALE_OVERCLAIM_STRINGS.iter().all(|stale| {
                registry
                    .records()
                    .flat_map(|card| card.forbidden_claims.iter())
                    .any(|claim| claim == stale)
            }),
        ),
        (
            "no_hidden_source_authority",
            registry.records().all(|card| !card.hidden_source_authority),
        ),
        (
            "no_hidden_route_authority",
            registry.records().all(|card| !card.hidden_route_authority),
        ),
        (
            "no_hidden_proof_authority",
            registry.records().all(|card| !card.hidden_proof_authority),
        ),
        (
            "no_hidden_chain",
            registry.records().all(|card| !card.hidden_chain_exposed),
        ),
        (
            "no_hidden_cloud",
            registry
                .records()
                .all(|card| !card.cloud_runtime_dependency),
        ),
        (
            "no_raw_code_import",
            registry.records().all(|card| !card.raw_code_imported),
        ),
        (
            "no_product_claim_promotion",
            registry.records().all(|card| !card.product_claim_promoted),
        ),
        (
            "no_runtime_bytes_loaded",
            registry
                .records()
                .all(|card| card.runtime_bytes_loaded == 0),
        ),
        (
            "no_model_bytes_loaded",
            registry.records().all(|card| card.model_bytes_loaded == 0),
        ),
        (
            "metadata_bound",
            metrics.max_source_card_metadata_bytes <= MAX_SOURCE_CARD_METADATA_BYTES,
        ),
        (
            "axiom_axle_distinct_from_axiomatic_axprover",
            pair_set.contains(&pair_key("axiom-axle-engine", "axiomatic-axprover-base")),
        ),
        (
            "axiom_axplorer_distinct_from_axiomatic_oprover",
            pair_set.contains(&pair_key(
                "axiom-axplorer-search",
                "axiomatic-oprover-traces",
            )),
        ),
        (
            "harmonic_distinct_from_math_inc",
            pair_set.contains(&pair_key(
                "harmonic-aristotle-imo",
                "math-inc-opengauss-workflow",
            )),
        ),
        (
            "ulamai_distinct_from_axiom",
            pair_set.contains(&pair_key("ulamai-local-lean-loop", "axiom-axle-engine")),
        ),
        (
            "lean_tooling_distinct_from_provers",
            pair_set.contains(&pair_key(
                "leansearch-pantograph-tooling",
                "axiomatic-axprover-base",
            )),
        ),
        (
            "math_inc_workflow_distinct_from_harmonic_artifact",
            pair_set.contains(&pair_key("math-inc-gauss", "harmonic-aristotle-imo")),
        ),
        (
            "axiom_axiomatic_source_distinction_address_deterministic",
            deterministic,
        ),
    ];
    for (axis, passed) in bool_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }
    for (axis, passed) in invalid_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }

    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fixture_count",
        metrics.fixture_count,
        1,
        "fixtures",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_card_count",
        metrics.source_card_count,
        9,
        "cards",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_class_count",
        metrics.source_class_count,
        MIN_SOURCE_CLASS_COUNT,
        "classes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "motif_class_count",
        metrics.motif_class_count,
        MIN_MOTIF_CLASS_COUNT,
        "classes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "false_merge_case_count",
        metrics.false_merge_case_count,
        MIN_FALSE_MERGE_CASES,
        "cases",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "stale_overclaim_string_count",
        STALE_OVERCLAIM_STRINGS.len() as u64,
        11,
        "strings",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_source_card_metadata_bytes",
        metrics.max_source_card_metadata_bytes,
        "<=",
        MAX_SOURCE_CARD_METADATA_BYTES,
        "bytes",
    );
    measurements.insert(
        "axiom_axiomatic_source_distinction_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address.clone()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "axiom_axiomatic_source_distinction_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String(
                "uas:axiom-axiomatic-source-distinction:sha256:".to_string(),
            ),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "axiom_axiomatic_source_distinction_address".to_string(),
        address.starts_with("uas:axiom-axiomatic-source-distinction:sha256:"),
    );

    let artifact = ArtifactBuilder {
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
            "kind": "metadata_only_source_card_witness",
            "detail": "Architecture cursor advances only. No external prover, source handle, Lean tool, route label, or formal-math motif is promoted to live product capability."
        })],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-AxiomAxiomatic-SourceDistinction is metadata-only: Axiom AXLE/Axplorer, Axiomatic AxProver/OProver, UlamAI, Harmonic, Math Inc/OpenGauss, and Lean tooling remain distinct source-card motifs with source-prior-only route impact.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();
    Ok(artifact)
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    operator: &str,
    expected: u64,
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
            operator: operator.to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    let passed = match operator {
        "<=" => actual <= expected,
        ">=" => actual >= expected,
        "==" => actual == expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), passed);
}

fn main() {
    match build_artifact() {
        Ok(artifact) => {
            let path = PathBuf::from(RESULT);
            if let Some(parent) = path.parent() {
                if let Err(error) = std::fs::create_dir_all(parent) {
                    eprintln!(
                        "failed to create artifact directory {}: {error}",
                        parent.display()
                    );
                    std::process::exit(1);
                }
            }
            match std::fs::File::create(&path) {
                Ok(mut file) => {
                    if let Err(error) = write_artifact(&mut file, &artifact) {
                        eprintln!("failed to write artifact {}: {error}", path.display());
                        std::process::exit(1);
                    }
                    println!(
                        "{}: overall_pass={} artifact={}",
                        FALSIFIER_ID,
                        artifact.overall_pass,
                        path.display()
                    );
                    if !artifact.overall_pass {
                        std::process::exit(1);
                    }
                }
                Err(error) => {
                    eprintln!("failed to open artifact {}: {error}", path.display());
                    std::process::exit(1);
                }
            }
        }
        Err(error) => {
            eprintln!("failed to build {} fixture: {:?}", FALSIFIER_ID, error);
            std::process::exit(1);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_fixture_builds_registry() {
        let registry = SourceDistinctionRegistry::new(fixture_source_distinctions());
        assert!(registry.is_ok());
    }

    #[test]
    fn empty_fixture_is_rejected() {
        assert_eq!(
            SourceDistinctionRegistry::new(Vec::new()).err(),
            Some(SourceDistinctionError::EmptyFixture)
        );
    }

    #[test]
    fn duplicate_source_id_and_url_are_rejected() {
        let fixtures = fixture_source_distinctions();
        assert!(rejects_card(&fixtures, |card| card.source_id =
            "axiom-axle-engine".to_string()));
        assert!(rejects_card(&fixtures, |card| card.source_url =
            "https://axle.axiommath.ai/".to_string()));
    }

    #[test]
    fn false_merge_negatives_are_required() {
        let fixtures = fixture_source_distinctions();
        assert!(rejects(&fixtures, |fixtures| fixtures[0]
            .false_merge_cases
            .clear()));
        assert!(rejects_false_merge(&fixtures, |case| case.rejected = false));
    }

    #[test]
    fn address_is_deterministic_under_ordering() {
        let registry = SourceDistinctionRegistry::new(fixture_source_distinctions()).unwrap();
        let address = registry.address();
        let mut reversed = fixture_source_distinctions();
        reversed.reverse();
        for fixture in &mut reversed {
            fixture.cards.reverse();
            fixture.false_merge_cases.reverse();
        }
        let reversed_address = SourceDistinctionRegistry::new(reversed).unwrap().address();
        assert_eq!(address, reversed_address);
    }

    #[test]
    fn invalid_fixture_axes_all_reject() {
        let fixtures = fixture_source_distinctions();
        for (axis, passed) in invalid_fixture_axes(&fixtures) {
            assert!(passed, "{axis} did not reject its invalid fixture");
        }
    }

    #[test]
    fn artifact_contains_required_axes() {
        let artifact = build_artifact().unwrap();
        for axis in REQUIRED_AXES {
            assert!(
                artifact.pass_per_axis.contains_key(*axis),
                "missing required axis {axis}"
            );
        }
    }
}
