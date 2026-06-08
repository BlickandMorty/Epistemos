//! `falsify_automated_checks_fresh_test_products_evidence_envelope`.
//!
//! Metadata-only witness for the future fresh Xcode test-products proof root.
//! It consumes the landed command spec plus the retained red automated-checks
//! artifact. It does not run Xcode, open test products, or promote L2/L3.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_automated_checks_fresh_test_products_digest_fields,
    required_automated_checks_fresh_test_products_proof_surfaces,
    required_automated_checks_fresh_test_products_rejection_policies,
    AutomatedChecksFreshTestProductsEvidenceEnvelope,
    AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness,
    AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-AutomatedChecksFreshTestProductsEvidenceEnvelope";
const FIXTURE_ID: &str = "automated_checks_fresh_test_products_evidence_envelope_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_automated_checks_fresh_test_products_evidence_envelope.sh";
const RESULT: &str =
    "artifacts/falsifiers/automated_checks_fresh_test_products_evidence_envelope/result.json";
const COMMAND_SPEC_RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_test_products_command_spec/result.json";
const AUTOMATED_CHECKS_RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json";
const CAPABILITY_RESULT: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} digest_fields={} rejection_policies={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_digest_field_count"].value,
        artifact.measurements["required_rejection_policy_count"].value,
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let command_spec = read_command_spec()?;
    let automated_checks = read_automated_checks()?;
    let capability = read_capability()?;
    let witness = AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
        command_spec.overall_pass,
        &command_spec.address,
        command_spec.seed_selector_count,
        command_spec.command_template_count,
        automated_checks.overall_pass,
        &capability.next_bottleneck,
        &automated_checks.top_failure_family,
        automated_checks.xcodebuild_test_passed,
    )?;
    witness.validate()?;

    let red_results = red_fixture_results(&witness);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        (
            "upstream_command_spec_pass",
            witness.command_spec_overall_pass,
        ),
        (
            "upstream_command_spec_address_bound",
            witness.command_spec_address.starts_with("sha256:")
                && witness.command_spec_address.len() == 71,
        ),
        (
            "upstream_command_spec_seed_selectors_8",
            witness.command_spec_seed_selector_count == 8,
        ),
        (
            "upstream_command_spec_command_templates_3",
            witness.command_spec_command_template_count == 3,
        ),
        (
            "upstream_automated_checks_red_bound",
            !witness.automated_checks_overall_pass,
        ),
        (
            "upstream_automated_next_bottleneck_bound",
            witness.automated_checks_next_bottleneck
                == AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR,
        ),
        (
            "upstream_top_failure_family_bound",
            witness.automated_checks_top_failure_family == "graph_filter_visibility",
        ),
        (
            "upstream_xcodebuild_test_red_bound",
            !witness.automated_checks_xcodebuild_test_passed,
        ),
        (
            "proof_root_prefix_bound",
            witness
                .spec
                .proof_root_prefix
                .starts_with("artifacts/xcode/graph-filter-visibility-test-products/"),
        ),
        (
            "selected_test_product_kinds_bound",
            witness.metrics.selected_test_product_kind_count == 2,
        ),
        (
            "required_digest_fields_bound",
            witness.metrics.required_digest_field_count
                == required_automated_checks_fresh_test_products_digest_fields().len(),
        ),
        (
            "required_rejection_policies_bound",
            witness.metrics.required_rejection_policy_count
                == required_automated_checks_fresh_test_products_rejection_policies().len(),
        ),
        (
            "required_proof_surfaces_bound",
            witness.metrics.required_proof_surface_count
                == required_automated_checks_fresh_test_products_proof_surfaces().len(),
        ),
        (
            "scheme_pre_action_recorded",
            witness.spec.scheme_pre_action_title == "Patch MLX Metal Warning"
                && witness.spec.scheme_pre_action_script == "scripts/patch_mlx_metal_warnings.sh",
        ),
        (
            "minimum_nonzero_executed_tests_required",
            witness.metrics.minimum_executed_test_count > 0,
        ),
        (
            "full_automated_check_row_still_required",
            witness.spec.full_automated_check_row_still_required,
        ),
        (
            "focused_proof_cannot_replace_full_row",
            !witness.spec.focused_proof_replaces_full_automated_checks,
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
            "no_selected_test_product_bytes_opened",
            witness.metrics.selected_test_product_bytes_opened == 0,
        ),
        (
            "no_model_or_app_runtime_bytes",
            witness.metrics.model_runtime_bytes_loaded == 0
                && witness.metrics.app_runtime_bytes_loaded == 0,
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
            "no_live_dense_70b_or_ssd_ram_claim",
            !witness.spec.live_dense_70b_claimed && !witness.spec.ssd_as_ram_claimed,
        ),
        (
            "rollback_run_event_answer_packet_refs_present",
            !witness.spec.rollback_ref.is_empty()
                && !witness.spec.run_event_log_ref.is_empty()
                && !witness.spec.answer_packet_ref.is_empty(),
        ),
        (
            "next_cursor_bound",
            witness.next_cursor
                == AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR,
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

    for (name, passed) in red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }

    for (name, actual, expected, unit) in [
        (
            "command_spec_seed_selector_count",
            witness.command_spec_seed_selector_count,
            8,
            "selectors",
        ),
        (
            "command_spec_command_template_count",
            witness.command_spec_command_template_count,
            3,
            "commands",
        ),
        (
            "selected_test_product_kind_count",
            witness.metrics.selected_test_product_kind_count as u64,
            witness.metrics.selected_test_product_kind_count as u64,
            "kinds",
        ),
        (
            "required_digest_field_count",
            witness.metrics.required_digest_field_count as u64,
            required_automated_checks_fresh_test_products_digest_fields().len() as u64,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            witness.metrics.required_rejection_policy_count as u64,
            required_automated_checks_fresh_test_products_rejection_policies().len() as u64,
            "policies",
        ),
        (
            "required_proof_surface_count",
            witness.metrics.required_proof_surface_count as u64,
            required_automated_checks_fresh_test_products_proof_surfaces().len() as u64,
            "surfaces",
        ),
        (
            "minimum_executed_test_count",
            witness.metrics.minimum_executed_test_count,
            1,
            "tests",
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
        "command_spec_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.command_spec_address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "command_spec_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "command_spec_address".to_string(),
        witness.command_spec_address.starts_with("sha256:"),
    );

    measurements.insert(
        "automated_checks_fresh_test_products_envelope_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "automated_checks_fresh_test_products_envelope_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "automated_checks_fresh_test_products_envelope_address".to_string(),
        !witness.address.is_empty(),
    );
    measurements.insert(
        "automated_checks_fresh_test_products_evidence_envelope".to_string(),
        Measurement {
            value: serde_json::to_value(&witness)?,
            unit: "json".to_string(),
        },
    );
    thresholds.insert(
        "automated_checks_fresh_test_products_evidence_envelope".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "envelope".to_string(),
        },
    );
    pass_per_axis.insert(
        "automated_checks_fresh_test_products_evidence_envelope".to_string(),
        true,
    );
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
                AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR,
    );

    for axis in AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_AXES {
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
        notes: "metadata-only F-AutomatedChecksFreshTestProductsEvidenceEnvelope: consumes the graph-filter test-products command spec and retained red automated-checks artifact, binds future proof-root digest requirements, nonzero executed-test proof, pre-action handling, rollback, RunEventLog, AnswerPacket, full automated-check-row preservation, zero Xcode execution, zero test-product/model/runtime bytes, and no L2/L3/product/release/large-model promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn red_fixture_results(
    witness: &AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness,
) -> Vec<(&'static str, bool)> {
    let mut results = Vec::new();
    for fixture in red_fixture_cases() {
        let rejected = match fixture {
            RedFixture::CommandSpecFail => AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
                false,
                &witness.command_spec_address,
                witness.command_spec_seed_selector_count,
                witness.command_spec_command_template_count,
                witness.automated_checks_overall_pass,
                &witness.automated_checks_next_bottleneck,
                &witness.automated_checks_top_failure_family,
                witness.automated_checks_xcodebuild_test_passed,
            )
            .is_err(),
            RedFixture::MissingCommandSpecAddress => AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
                witness.command_spec_overall_pass,
                "",
                witness.command_spec_seed_selector_count,
                witness.command_spec_command_template_count,
                witness.automated_checks_overall_pass,
                &witness.automated_checks_next_bottleneck,
                &witness.automated_checks_top_failure_family,
                witness.automated_checks_xcodebuild_test_passed,
            )
            .is_err(),
            RedFixture::WrongCommandSpecSelectorCount => AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
                witness.command_spec_overall_pass,
                &witness.command_spec_address,
                7,
                witness.command_spec_command_template_count,
                witness.automated_checks_overall_pass,
                &witness.automated_checks_next_bottleneck,
                &witness.automated_checks_top_failure_family,
                witness.automated_checks_xcodebuild_test_passed,
            )
            .is_err(),
            RedFixture::AutomatedChecksGreen => AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
                witness.command_spec_overall_pass,
                &witness.command_spec_address,
                witness.command_spec_seed_selector_count,
                witness.command_spec_command_template_count,
                true,
                &witness.automated_checks_next_bottleneck,
                &witness.automated_checks_top_failure_family,
                witness.automated_checks_xcodebuild_test_passed,
            )
            .is_err(),
            RedFixture::WrongNextBottleneck => AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
                witness.command_spec_overall_pass,
                &witness.command_spec_address,
                witness.command_spec_seed_selector_count,
                witness.command_spec_command_template_count,
                witness.automated_checks_overall_pass,
                "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe",
                &witness.automated_checks_top_failure_family,
                witness.automated_checks_xcodebuild_test_passed,
            )
            .is_err(),
            RedFixture::WrongFailureFamily => AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
                witness.command_spec_overall_pass,
                &witness.command_spec_address,
                witness.command_spec_seed_selector_count,
                witness.command_spec_command_template_count,
                witness.automated_checks_overall_pass,
                &witness.automated_checks_next_bottleneck,
                "agent_route_policy",
                witness.automated_checks_xcodebuild_test_passed,
            )
            .is_err(),
            RedFixture::XcodebuildTestGreen => AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
                witness.command_spec_overall_pass,
                &witness.command_spec_address,
                witness.command_spec_seed_selector_count,
                witness.command_spec_command_template_count,
                witness.automated_checks_overall_pass,
                &witness.automated_checks_next_bottleneck,
                &witness.automated_checks_top_failure_family,
                true,
            )
            .is_err(),
            RedFixture::MutateSpec { name: _, mutate } => {
                let mut spec = AutomatedChecksFreshTestProductsEvidenceEnvelope::canonical();
                mutate(&mut spec);
                spec.validate().is_err()
            }
        };
        results.push((fixture.name(), rejected));
    }
    results
}

// UAS: F-AutomatedChecksFreshTestProductsEvidenceEnvelope red-fixture set.
// Plane: Verification.
// Residency: metadata-only fixture contract; no product/test bytes are loaded.
enum RedFixture {
    CommandSpecFail,
    MissingCommandSpecAddress,
    WrongCommandSpecSelectorCount,
    AutomatedChecksGreen,
    WrongNextBottleneck,
    WrongFailureFamily,
    XcodebuildTestGreen,
    MutateSpec {
        name: &'static str,
        mutate: fn(&mut AutomatedChecksFreshTestProductsEvidenceEnvelope),
    },
}

impl RedFixture {
    fn name(&self) -> &'static str {
        match self {
            Self::CommandSpecFail => "command_spec_fail_rejected",
            Self::MissingCommandSpecAddress => "missing_command_spec_address_rejected",
            Self::WrongCommandSpecSelectorCount => "wrong_command_spec_selector_count_rejected",
            Self::AutomatedChecksGreen => "automated_checks_green_rejected",
            Self::WrongNextBottleneck => "wrong_next_bottleneck_rejected",
            Self::WrongFailureFamily => "wrong_failure_family_rejected",
            Self::XcodebuildTestGreen => "xcodebuild_test_green_rejected",
            Self::MutateSpec { name, .. } => name,
        }
    }
}

fn red_fixture_cases() -> Vec<RedFixture> {
    vec![
        RedFixture::CommandSpecFail,
        RedFixture::MissingCommandSpecAddress,
        RedFixture::WrongCommandSpecSelectorCount,
        RedFixture::AutomatedChecksGreen,
        RedFixture::WrongNextBottleneck,
        RedFixture::WrongFailureFamily,
        RedFixture::XcodebuildTestGreen,
        RedFixture::MutateSpec {
            name: "global_derived_data_rejected",
            mutate: |spec| {
                spec.proof_root_prefix =
                    "~/Library/Developer/Xcode/DerivedData/Epistemos".to_string()
            },
        },
        RedFixture::MutateSpec {
            name: "missing_digest_field_rejected",
            mutate: |spec| {
                spec.required_digest_fields.pop();
            },
        },
        RedFixture::MutateSpec {
            name: "missing_rejection_policy_rejected",
            mutate: |spec| {
                spec.required_rejection_policies.pop();
            },
        },
        RedFixture::MutateSpec {
            name: "missing_proof_surface_rejected",
            mutate: |spec| {
                spec.required_proof_surfaces.pop();
            },
        },
        RedFixture::MutateSpec {
            name: "zero_executed_tests_policy_rejected",
            mutate: |spec| spec.minimum_executed_test_count = 0,
        },
        RedFixture::MutateSpec {
            name: "full_row_replacement_rejected",
            mutate: |spec| spec.focused_proof_replaces_full_automated_checks = true,
        },
        RedFixture::MutateSpec {
            name: "xcode_execution_claim_rejected",
            mutate: |spec| spec.xcode_command_executed = true,
        },
        RedFixture::MutateSpec {
            name: "product_code_change_claim_rejected",
            mutate: |spec| spec.product_code_changed = true,
        },
        RedFixture::MutateSpec {
            name: "test_product_byte_open_rejected",
            mutate: |spec| spec.selected_test_product_bytes_opened = 1,
        },
        RedFixture::MutateSpec {
            name: "runtime_byte_leak_rejected",
            mutate: |spec| spec.model_runtime_bytes_loaded = 1,
        },
        RedFixture::MutateSpec {
            name: "raw_note_prompt_model_log_rejected",
            mutate: |spec| spec.raw_note_prompt_model_bytes_logged = true,
        },
        RedFixture::MutateSpec {
            name: "l2_l3_product_green_claim_rejected",
            mutate: |spec| spec.l3_green_claimed = true,
        },
        RedFixture::MutateSpec {
            name: "release_ready_claim_rejected",
            mutate: |spec| spec.release_ready_claimed = true,
        },
        RedFixture::MutateSpec {
            name: "live_dense_70b_claim_rejected",
            mutate: |spec| spec.live_dense_70b_claimed = true,
        },
        RedFixture::MutateSpec {
            name: "ssd_as_ram_claim_rejected",
            mutate: |spec| spec.ssd_as_ram_claimed = true,
        },
    ]
}

// UAS: uas:automated-checks-fresh-test-products-evidence-envelope:command-spec-artifact
// Plane: Verification.
// Residency: metadata-only upstream command-spec artifact summary.
struct CommandSpecArtifact {
    overall_pass: bool,
    address: String,
    seed_selector_count: u64,
    command_template_count: u64,
}

// UAS: uas:automated-checks-fresh-test-products-evidence-envelope:automated-checks-artifact
// Plane: Verification.
// Residency: metadata-only retained red automated-checks artifact summary.
struct AutomatedChecksArtifact {
    overall_pass: bool,
    top_failure_family: String,
    xcodebuild_test_passed: bool,
}

// UAS: uas:automated-checks-fresh-test-products-evidence-envelope:capability-artifact
// Plane: Verification.
// Residency: metadata-only capability bottleneck summary.
struct CapabilityArtifact {
    next_bottleneck: String,
}

fn read_command_spec() -> Result<CommandSpecArtifact, Box<dyn std::error::Error>> {
    let json = read_json(Path::new(COMMAND_SPEC_RESULT))?;
    Ok(CommandSpecArtifact {
        overall_pass: json_bool(&json, "overall_pass").unwrap_or(false),
        address: measurement_string(&json, "graph_filter_test_products_address")
            .unwrap_or_default(),
        seed_selector_count: measurement_u64(&json, "seed_selector_count").unwrap_or(0),
        command_template_count: measurement_u64(&json, "command_template_count").unwrap_or(0),
    })
}

fn read_automated_checks() -> Result<AutomatedChecksArtifact, Box<dyn std::error::Error>> {
    let json = read_json(Path::new(AUTOMATED_CHECKS_RESULT))?;
    Ok(AutomatedChecksArtifact {
        overall_pass: json_bool(&json, "overall_pass").unwrap_or(false),
        top_failure_family: measurement_string(&json, "top_xcodebuild_test_failure_family")
            .unwrap_or_default(),
        xcodebuild_test_passed: measurement_bool(&json, "xcodebuild_test_passed").unwrap_or(false),
    })
}

fn read_capability() -> Result<CapabilityArtifact, Box<dyn std::error::Error>> {
    let json = read_json(Path::new(CAPABILITY_RESULT))?;
    Ok(CapabilityArtifact {
        next_bottleneck: measurement_string(&json, "next_bottleneck").unwrap_or_default(),
    })
}

fn read_json(path: &Path) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(path)?;
    Ok(serde_json::from_slice(&bytes)?)
}

fn json_bool(json: &serde_json::Value, key: &str) -> Option<bool> {
    json.get(key).and_then(serde_json::Value::as_bool)
}

fn measurement_bool(json: &serde_json::Value, key: &str) -> Option<bool> {
    json.pointer(&format!("/measurements/{key}/value"))
        .and_then(serde_json::Value::as_bool)
}

fn measurement_u64(json: &serde_json::Value, key: &str) -> Option<u64> {
    json.pointer(&format!("/measurements/{key}/value"))
        .and_then(serde_json::Value::as_u64)
}

fn measurement_string(json: &serde_json::Value, key: &str) -> Option<String> {
    json.pointer(&format!("/measurements/{key}/value"))
        .and_then(serde_json::Value::as_str)
        .map(ToOwned::to_owned)
}
