//! Source guards for the AppColdStore / NeuralImportance / PatternBoost lock.
//!
//! These guards keep non-executing route-card and assembly-genome surfaces from
//! drifting into hidden live route authority. They intentionally inspect source
//! text so the unattended architecture loop can verify the contract without
//! launching model, mmap, Metal, or SSD stress probes.

const APP_COLD_STORE_SOURCE: &str = include_str!("../src/uas/app_cold_store.rs");
const PATTERN_BOOST_SOURCE: &str = include_str!("../src/uas/pattern_boost.rs");
const APP_COLD_STORE_FALSIFIER_SOURCE: &str =
    include_str!("../src/bin/falsify_app_cold_store_layout.rs");

#[test]
fn app_cold_store_route_card_remains_manifest_only() {
    for required in [
        "does not mmap bytes, warm caches",
        "runtime_model_bytes_loaded: 0",
        "dry_run_copy_count: 0",
        "runtime_model_peak_uma_bytes: 0",
        "dry_run_ssd_read_bytes: 0",
        "validate_residency_plan_snapshot(plan)?",
        "validate_build_status(&product_build, &pro_status, residency_status)?",
        "ProductBuild::Pro",
        "ProStatus::ResearchCandidate",
    ] {
        assert!(
            APP_COLD_STORE_SOURCE.contains(required),
            "AppColdStore route cards must preserve manifest-only guard: {required}"
        );
    }
}

#[test]
fn eidos_route_prior_stays_a_bound_planning_hint() {
    for required in [
        "const EIDOS_NEURAL_ROUTE_PRIOR_FALSIFIER_ID",
        "MissingEidosNeuralRoutePriorVerifier",
        "validate_eidos_route_prior(",
        "validate_eidos_route_prior_support_binding(",
        "route_prior_support_matches_unit(",
        "validate_shape()",
        "prior.task_signature != task_signature",
        "prior.evidence_ids.is_empty()",
        "prior.likely_verifiers.is_empty()",
        "prior.likely_weight_page_families.is_empty()",
        "strip_prefix(\"weight_page:\")",
        "strip_prefix(\"uas:\")",
        "strip_prefix(\"source:\")",
        "strip_prefix(\"range:\")",
        "strip_prefix(\"hash:\")",
    ] {
        assert!(
            APP_COLD_STORE_SOURCE.contains(required),
            "EidosRoutePrior must remain a verifier-bound route prior: {required}"
        );
    }
}

#[test]
fn patternboost_genomes_stay_shadow_dry_run_and_witness_bound() {
    for required in [
        "do not wake model bytes",
        "mutate live routing policy",
        "validate_patternboost_status(&product_build, &pro_status, residency_status)?",
        "product_build != &ProductBuild::Pro",
        "pro_status != &ProStatus::ResearchCandidate",
        "residency_status != ResidencyTier::CapabilityCeiling",
        "REQUIRED_PATTERNBOOST_VERIFIER_LANES",
        "F-ComputeResumeLease-Compatibility",
        "F-LatticeAbstentionGate-Soundness",
        "F-NoOfflineOracleLeak",
        "F-ParamRouteCard-Admission",
        "F-ResidencyPatternBoost-NoHiddenAuthority",
        "validate_rollback_reference(&rollback_ref)?",
        "validate_run_event_log_span_ref(&run_event_log_span_ref)?",
        "validate_answer_packet_caveat_ref(&answer_packet_caveat_ref)?",
        "is_shadow_or_dry_run_route_id(route_id)",
        "is_baseline_fallback_route_id(route_id)",
        "FALLBACK_ROUTE_ID_PREFIXES",
        "\"baseline_\"",
        "\"fallback_\"",
        "\"shadow_\"",
        "\"dry_run_\"",
    ] {
        assert!(
            PATTERN_BOOST_SOURCE.contains(required),
            "PatternBoost assembly genomes must remain shadow/dry-run witness metadata: {required}"
        );
    }
}

#[test]
fn app_cold_store_falsifier_reports_visible_non_runtime_axes() {
    for required in [
        "manifest-only AppColdStore route card",
        "no mmap, no cache warm, no model byte load, no inference",
        "runtime_model_bytes_loaded",
        "dry_run_copy_count",
        "runtime_model_peak_uma_bytes",
        "dry_run_ssd_read_bytes",
        "eidos_route_prior_neural_falsifier_bound",
        "param_route_card_admission_verifier_bound",
        "product_build_pro_research_status_bound",
        "rollback_reference_bound",
        "witness_completeness_percent",
    ] {
        assert!(
            APP_COLD_STORE_FALSIFIER_SOURCE.contains(required),
            "F-AppColdStore-Layout must keep non-runtime visible-proof axis: {required}"
        );
    }
}
