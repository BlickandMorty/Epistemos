//! `falsify_graph_filter_visibility_test_products_command_spec`.
//!
//! Metadata-only witness for the Epistemos-specific Xcode test-products
//! command spec. It does not run Xcode, open test products, or claim release
//! readiness; it proves the future proof run is source-bound and fail-closed.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_graph_filter_test_products_command_templates,
    required_graph_filter_test_products_seed_selectors,
    required_graph_filter_test_products_source_refs, GraphFilterVisibilityTestProductsCommandSpec,
    GraphFilterVisibilityTestProductsCommandSpecWitness,
    GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_NEXT_CURSOR,
    GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_NEXT_CURSOR,
    GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-GraphFilterVisibilityTestProductsCommandSpec";
const FIXTURE_ID: &str = "graph_filter_visibility_test_products_command_spec_v1";
const COMMAND: &str = "Tools/falsifiers/f_graph_filter_visibility_test_products_command_spec.sh";
const RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_test_products_command_spec/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_release_blocker_card/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} seed_selectors={} command_templates={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["seed_selector_count"].value,
        artifact.measurements["command_template_count"].value,
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream = read_upstream()?;
    let witness = GraphFilterVisibilityTestProductsCommandSpecWitness::new(
        GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_REF,
        upstream.overall_pass,
        &upstream.next_cursor,
    )?;
    witness.validate()?;
    let red_results = red_fixture_results(&witness);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_graph_filter_card_pass", upstream.overall_pass),
        (
            "upstream_next_cursor_research_tool_catalog",
            upstream.next_cursor
                == GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_NEXT_CURSOR,
        ),
        (
            "scheme_path_bound",
            witness.spec.scheme_path
                == "Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme",
        ),
        (
            "scheme_testable_bound",
            witness.spec.scheme_name == "Epistemos"
                && witness.spec.testable_name == "EpistemosTests.xctest",
        ),
        (
            "build_for_testing_template_bound",
            witness
                .spec
                .command_templates
                .iter()
                .any(|command| command.contains("build-for-testing")),
        ),
        (
            "test_without_building_templates_bound",
            witness
                .spec
                .command_templates
                .iter()
                .filter(|command| command.contains("test-without-building"))
                .count()
                == 2,
        ),
        (
            "proof_root_is_artifact_scoped",
            witness
                .spec
                .proof_root_template
                .starts_with("artifacts/xcode/graph-filter-visibility-test-products/"),
        ),
        (
            "derived_data_is_proof_root_scoped",
            witness.spec.derived_data_path_template == "$PROOF_ROOT/DerivedData",
        ),
        (
            "scheme_pre_action_recorded",
            witness.spec.scheme_pre_action_title == "Patch MLX Metal Warning"
                && witness.spec.scheme_pre_action_script == "scripts/patch_mlx_metal_warnings.sh",
        ),
        (
            "seed_selectors_bound",
            witness.metrics.seed_selector_count
                == required_graph_filter_test_products_seed_selectors().len(),
        ),
        (
            "source_refs_bound",
            witness.metrics.source_ref_count
                == required_graph_filter_test_products_source_refs().len(),
        ),
        (
            "no_xcode_command_executed",
            !witness.spec.xcode_command_executed,
        ),
        (
            "no_product_code_changed",
            !witness.spec.product_code_changed,
        ),
        (
            "no_test_product_bytes_opened",
            witness.metrics.selected_test_product_bytes_opened == 0,
        ),
        (
            "no_model_or_app_runtime_bytes",
            witness.metrics.model_runtime_bytes_loaded == 0
                && witness.metrics.app_runtime_bytes_loaded == 0,
        ),
        (
            "rejects_stale_and_global_artifacts",
            witness.spec.rejects_global_derived_data
                && witness.spec.rejects_different_commit_products
                && witness.spec.rejects_stale_result_bundle,
        ),
        (
            "rejects_selector_mismatch_and_filename_selectors",
            witness.spec.rejects_selector_mismatch && witness.spec.rejects_filename_selector,
        ),
        (
            "rejects_enumeration_only_and_zero_tests",
            witness.spec.rejects_enumeration_only_pass && witness.spec.rejects_zero_executed_tests,
        ),
        (
            "rejects_pre_action_mutation",
            witness.spec.rejects_pre_action_mutation,
        ),
        (
            "full_automated_check_row_still_required",
            witness.spec.full_automated_check_row_still_required,
        ),
        (
            "no_raw_note_prompt_model_log_bytes",
            !witness.spec.raw_note_prompt_model_bytes_logged,
        ),
        (
            "no_l2_l3_product_release_green",
            !witness.spec.l2_green_claimed
                && !witness.spec.l3_green_claimed
                && !witness.spec.product_green_claimed
                && !witness.spec.release_ready_claimed,
        ),
        (
            "no_live_dense_70b_claim",
            !witness.spec.live_dense_70b_claimed,
        ),
        (
            "rollback_run_event_answer_packet_refs_present",
            !witness.spec.rollback_ref.is_empty()
                && !witness.spec.run_event_log_ref.is_empty()
                && !witness.spec.answer_packet_ref.is_empty(),
        ),
        (
            "next_cursor_bound",
            witness.next_cursor == GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_NEXT_CURSOR,
        ),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }

    for (id, passed) in &red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            id,
            *passed,
        );
    }

    for (name, actual, expected, unit) in [
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_graph_filter_test_products_source_refs().len() as u64,
            "refs",
        ),
        (
            "seed_selector_count",
            witness.metrics.seed_selector_count as u64,
            required_graph_filter_test_products_seed_selectors().len() as u64,
            "selectors",
        ),
        (
            "command_template_count",
            witness.metrics.command_template_count as u64,
            required_graph_filter_test_products_command_templates().len() as u64,
            "commands",
        ),
        (
            "selected_test_product_bytes_opened_total",
            witness.metrics.selected_test_product_bytes_opened,
            0,
            "bytes",
        ),
        (
            "model_runtime_bytes_loaded_total",
            witness.metrics.model_runtime_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "app_runtime_bytes_loaded_total",
            witness.metrics.app_runtime_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "red_fixture_count",
            red_fixture_count,
            red_fixture_count,
            "fixtures",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            red_fixture_count,
            "fixtures",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            actual,
            "==",
            expected,
            unit,
        );
    }

    measurements.insert(
        "graph_filter_test_products_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "graph_filter_test_products_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "graph_filter_test_products_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "graph_filter_test_products_command_spec".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.spec)?,
            unit: "command_spec".to_string(),
        },
    );
    thresholds.insert(
        "graph_filter_test_products_command_spec".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "command_spec".to_string(),
        },
    );
    pass_per_axis.insert("graph_filter_test_products_command_spec".to_string(), true);

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(witness.next_cursor),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "eq".to_string(),
            value: serde_json::json!(
                GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_NEXT_CURSOR,
    );

    for axis in GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_AXES {
        measurements
            .entry((*axis).to_string())
            .or_insert(Measurement {
                value: serde_json::json!(false),
                unit: "axis_missing".to_string(),
            });
        thresholds
            .entry((*axis).to_string())
            .or_insert(AcceptanceThreshold {
                operator: "present".to_string(),
                value: serde_json::json!(true),
                unit: "axis_missing".to_string(),
            });
        pass_per_axis.entry((*axis).to_string()).or_insert(false);
    }

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
        anomalies: Vec::new(),
        notes: "metadata-only F-GraphFilterVisibilityTestProductsCommandSpec: consumes the graph-filter visibility release-blocker card, binds the Epistemos scheme/testable/pre-action, proof-root-scoped build-for-testing and test-without-building command templates, seed Swift Testing selectors, stale-artifact and zero-test rejection policy, rollback, RunEventLog, AnswerPacket, zero Xcode execution, zero test-product/model/runtime bytes, and no L2/L3/product/release/large-model promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:graph-filter-visibility-test-products-command-spec:upstream-card
// Plane: Verification.
// Residency: metadata-only upstream artifact summary; no product/runtime bytes.
#[derive(Debug)]
struct UpstreamGraphFilterCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamGraphFilterCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamGraphFilterCard {
        overall_pass: json
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false),
        next_cursor: json
            .pointer("/measurements/next_cursor/value")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
    })
}

fn red_fixture_results(
    witness: &GraphFilterVisibilityTestProductsCommandSpecWitness,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor) in [
        (
            "upstream_fail_rejected",
            false,
            GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_NEXT_CURSOR,
        ),
        ("wrong_upstream_cursor_rejected", true, "wrong_next_cursor"),
    ] {
        let rejected = GraphFilterVisibilityTestProductsCommandSpecWitness::new(
            GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_REF,
            upstream_pass,
            cursor,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_spec = |id: &str,
                    mutate: fn(&mut GraphFilterVisibilityTestProductsCommandSpec),
                    results: &mut Vec<(String, bool)>| {
        let mut spec = witness.spec.clone();
        mutate(&mut spec);
        results.push((id.to_string(), spec.validate().is_err()));
    };

    add_spec(
        "missing_scheme_path_rejected",
        |spec| spec.scheme_path.clear(),
        &mut results,
    );
    add_spec(
        "wrong_testable_rejected",
        |spec| spec.testable_name = "EpistemosUITests.xctest".to_string(),
        &mut results,
    );
    add_spec(
        "global_derived_data_rejected",
        |spec| spec.proof_root_template = "~/Library/Developer/Xcode/DerivedData".to_string(),
        &mut results,
    );
    add_spec(
        "missing_pre_action_rejected",
        |spec| spec.scheme_pre_action_script.clear(),
        &mut results,
    );
    add_spec(
        "missing_seed_selector_rejected",
        |spec| {
            spec.seed_selectors
                .retain(|value| !value.contains("isNodeVisibleForAllTypes"))
        },
        &mut results,
    );
    add_spec(
        "duplicate_seed_selector_rejected",
        |spec| spec.seed_selectors.push(spec.seed_selectors[0].clone()),
        &mut results,
    );
    add_spec(
        "filename_selector_rejected",
        |spec| {
            spec.seed_selectors[0] =
                "EpistemosTests/FilterEngineComprehensiveTests.swift".to_string()
        },
        &mut results,
    );
    add_spec(
        "missing_build_template_rejected",
        |spec| {
            spec.command_templates
                .retain(|value| !value.contains("build-for-testing"))
        },
        &mut results,
    );
    add_spec(
        "missing_test_without_building_template_rejected",
        |spec| {
            spec.command_templates
                .retain(|value| !value.contains("test-without-building"))
        },
        &mut results,
    );
    add_spec(
        "xcode_execution_claim_rejected",
        |spec| spec.xcode_command_executed = true,
        &mut results,
    );
    add_spec(
        "product_code_change_claim_rejected",
        |spec| spec.product_code_changed = true,
        &mut results,
    );
    add_spec(
        "test_product_byte_open_rejected",
        |spec| spec.selected_test_product_bytes_opened = 1,
        &mut results,
    );
    add_spec(
        "runtime_byte_leak_rejected",
        |spec| spec.model_runtime_bytes_loaded = 1,
        &mut results,
    );
    add_spec(
        "stale_artifact_policy_missing_rejected",
        |spec| spec.rejects_stale_result_bundle = false,
        &mut results,
    );
    add_spec(
        "selector_mismatch_policy_missing_rejected",
        |spec| spec.rejects_selector_mismatch = false,
        &mut results,
    );
    add_spec(
        "zero_test_policy_missing_rejected",
        |spec| spec.rejects_zero_executed_tests = false,
        &mut results,
    );
    add_spec(
        "pre_action_mutation_policy_missing_rejected",
        |spec| spec.rejects_pre_action_mutation = false,
        &mut results,
    );
    add_spec(
        "automated_row_replacement_rejected",
        |spec| spec.full_automated_check_row_still_required = false,
        &mut results,
    );
    add_spec(
        "l2_l3_product_green_claim_rejected",
        |spec| spec.l2_green_claimed = true,
        &mut results,
    );
    add_spec(
        "release_ready_claim_rejected",
        |spec| spec.release_ready_claimed = true,
        &mut results,
    );
    add_spec(
        "live_dense_70b_claim_rejected",
        |spec| spec.live_dense_70b_claimed = true,
        &mut results,
    );
    add_spec(
        "raw_note_prompt_model_log_rejected",
        |spec| spec.raw_note_prompt_model_bytes_logged = true,
        &mut results,
    );

    results
}
