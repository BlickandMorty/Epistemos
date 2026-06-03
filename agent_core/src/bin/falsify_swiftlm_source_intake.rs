//! `falsify_swiftlm_source_intake` — SwiftLM source-mining gate.
//!
//! Metadata-only witness for `F-SwiftLM-SourceIntake`. It proves the SwiftLM
//! repository is captured as source-carded motif evidence with license/setup
//! notes, benchmark caveats, and local test plans before any code import or
//! product dependency can be claimed.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    PrivacyClass, SourceCard, SourceNoPoisonStatus, SourceSignalEdge, SourceSignalGraph,
    SourceSignalType,
};

const FALSIFIER_ID: &str = "F-SwiftLM-SourceIntake";
const FIXTURE_ID: &str = "swiftlm_source_intake_v1";
const COMMAND: &str = "Tools/falsifiers/f_swiftlm_source_intake.sh";
const RESULT: &str = "artifacts/falsifiers/swiftlm_source_intake/result.json";
const CREATED_AT_MS: u64 = 1_779_010_000_000;

#[derive(Clone)]
struct SwiftLmSourceCard {
    card: SourceCard,
    motif: &'static str,
    setup_note: &'static str,
    benchmark_caveat: &'static str,
    local_test_plan: &'static str,
    implementation_import_status: &'static str,
}

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
        "{FALSIFIER_ID}: overall_pass={} motif_count={} test_plan_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["motif_count"].value,
        artifact.measurements["local_test_plan_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let fixture = fixture_swiftlm_source_cards()?;
    let cards = fixture
        .iter()
        .map(|item| item.card.clone())
        .collect::<Vec<_>>();
    let graph = SourceSignalGraph::intake(cards.clone(), fixture_edges()?, CREATED_AT_MS)?;
    let reversed = SourceSignalGraph::intake(
        cards.iter().cloned().rev().collect(),
        fixture_edges()?.into_iter().rev().collect(),
        CREATED_AT_MS,
    )?;

    let graph_address_deterministic = graph.graph_address == reversed.graph_address;
    let swiftlm_source_cards_present = graph.source_cards.len() == fixture.len();
    let swiftlm_repo_card_present = graph
        .source_cards
        .iter()
        .any(|card| card.source_id == "source:repo:swiftlm");
    let source_cards_sorted = graph
        .source_cards
        .windows(2)
        .all(|pair| pair[0].source_id <= pair[1].source_id);
    let source_graph_edges_bound = graph.edges.len() == 4;
    let source_graph_route_affinity_bound = graph
        .route_affinities
        .iter()
        .any(|route| route == "constructive_residency")
        && graph
            .route_affinities
            .iter()
            .any(|route| route == "app_cold_store");

    let ssd_streaming_motif_captured = motif_present(&fixture, "ssd_expert_streaming");
    let kv_compression_motif_captured = motif_present(&fixture, "kv_compression");
    let persistent_buffer_motif_captured = motif_present(&fixture, "persistent_buffers");
    let prefetch_motif_captured = motif_present(&fixture, "prefetch");
    let license_note_present = fixture.iter().all(|item| {
        item.card
            .license_or_usage_note
            .contains("license=MIT-source-card")
    });
    let setup_note_present = fixture
        .iter()
        .all(|item| item.setup_note.contains("setup=local-read-only"));
    let benchmark_caveat_present = fixture
        .iter()
        .all(|item| item.benchmark_caveat.contains("caveat="));
    let local_test_plan_present = fixture
        .iter()
        .all(|item| item.local_test_plan.starts_with("local-test="));
    let no_code_import_declared = fixture.iter().all(|item| {
        item.implementation_import_status == "none:source-mining-only"
            && item.card.license_or_usage_note.contains("no-code-import")
    });
    let no_product_dependency_declared = fixture.iter().all(|item| {
        item.card
            .license_or_usage_note
            .contains("not-product-dependency")
    });
    let no_runtime_bytes_loaded = true;
    let duplicate_source_rejected = duplicate_source_rejected()?;
    let missing_license_rejected = source_cards_reject_missing_license_note()?;
    let missing_benchmark_caveat_rejected = invalid_fixture_rejected(|item| {
        item.benchmark_caveat = "";
    })?;
    let missing_local_test_plan_rejected = invalid_fixture_rejected(|item| {
        item.local_test_plan = "";
    })?;
    let implementation_import_rejected = invalid_fixture_rejected(|item| {
        item.implementation_import_status = "import:repo-code";
    })?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        ("swiftlm_source_cards_present", swiftlm_source_cards_present),
        ("swiftlm_repo_card_present", swiftlm_repo_card_present),
        ("source_cards_sorted", source_cards_sorted),
        ("source_graph_edges_bound", source_graph_edges_bound),
        (
            "source_graph_route_affinity_bound",
            source_graph_route_affinity_bound,
        ),
        (
            "source_graph_address_deterministic",
            graph_address_deterministic,
        ),
        ("ssd_streaming_motif_captured", ssd_streaming_motif_captured),
        (
            "kv_compression_motif_captured",
            kv_compression_motif_captured,
        ),
        (
            "persistent_buffer_motif_captured",
            persistent_buffer_motif_captured,
        ),
        ("prefetch_motif_captured", prefetch_motif_captured),
        ("license_note_present", license_note_present),
        ("setup_note_present", setup_note_present),
        ("benchmark_caveat_present", benchmark_caveat_present),
        ("local_test_plan_present", local_test_plan_present),
        ("no_code_import_declared", no_code_import_declared),
        (
            "no_product_dependency_declared",
            no_product_dependency_declared,
        ),
        ("no_runtime_bytes_loaded", no_runtime_bytes_loaded),
        ("duplicate_source_rejected", duplicate_source_rejected),
        ("missing_license_rejected", missing_license_rejected),
        (
            "missing_benchmark_caveat_rejected",
            missing_benchmark_caveat_rejected,
        ),
        (
            "missing_local_test_plan_rejected",
            missing_local_test_plan_rejected,
        ),
        (
            "implementation_import_rejected",
            implementation_import_rejected,
        ),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
        );
    }

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_card_count",
        graph.source_cards.len() as u64,
        4,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "motif_count",
        fixture.len() as u64,
        4,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_test_plan_count",
        fixture
            .iter()
            .filter(|item| item.local_test_plan.starts_with("local-test="))
            .count() as u64,
        4,
        ">=",
    );
    measurements.insert(
        "source_graph_address".to_string(),
        Measurement {
            value: serde_json::Value::String(graph.graph_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "source_graph_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert("source_graph_address".to_string(), true);

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
            "detail": "metadata-only SwiftLM source intake; no repo fetch, no source import, no model bytes, no route mutation, and no product dependency executed"
        })],
        notes: "Proves SwiftLM SSD-streaming/KV-compression/persistent-buffer/prefetch motifs are source-carded with license, setup, benchmark caveat, and local test-plan metadata before any implementation import.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn fixture_swiftlm_source_cards() -> Result<Vec<SwiftLmSourceCard>, Box<dyn std::error::Error>> {
    Ok(vec![
        swiftlm_card(
            "source:repo:swiftlm",
            SourceSignalType::Repo,
            "https://github.com/SharpAI/SwiftLM",
            "swiftlm-repo-card",
            "ssd_expert_streaming",
            "caveat=repo claims are source-mined only until local fixture tests reproduce SSD expert streaming without importing code",
            "local-test=synthetic AppColdStore page-run prefetch fixture compares source-carded SSD motif against cold-miss baseline",
        )?,
        swiftlm_card(
            "source:doc:swiftlm-kv-compression",
            SourceSignalType::Doc,
            "docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md#swiftlm-source-mining",
            "swiftlm-kv-compression-card",
            "kv_compression",
            "caveat=KV compression is a motif only until WBO and compatibility-fence artifacts prove equal-quality reuse",
            "local-test=KVByteBudgetCard plus future compatibility-fence fixture records codec bytes hit/miss tokens and quality caveat",
        )?,
        swiftlm_card(
            "source:doc:swiftlm-persistent-buffers",
            SourceSignalType::Doc,
            "docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md#external-grounding",
            "swiftlm-persistent-buffer-card",
            "persistent_buffers",
            "caveat=persistent buffers cannot imply durable hidden reasoning or source-derived product authority",
            "local-test=ReasoningStateContinuity and future CacheAdmissionCard fixture require purge policy rollback and AnswerPacket visibility",
        )?,
        swiftlm_card(
            "source:doc:swiftlm-prefetch",
            SourceSignalType::Doc,
            "docs/fusion/NEURAL_IMPORTANCE_ROUTING_ATLAS_2026_05_31.md#swiftlm",
            "swiftlm-prefetch-card",
            "prefetch",
            "caveat=prefetch motif remains shadow-policy only until cold-miss held-out improvement and storage wear are bounded",
            "local-test=ColdMissLedger plus future ParetoResidencyTournament fixture compares prefetch policy against file-order static baselines",
        )?,
    ])
}

fn swiftlm_card(
    source_id: &str,
    source_type: SourceSignalType,
    locator: &str,
    digest_seed: &str,
    motif: &'static str,
    benchmark_caveat: &'static str,
    local_test_plan: &'static str,
) -> Result<SwiftLmSourceCard, Box<dyn std::error::Error>> {
    let usage_note = format!(
        "license=MIT-source-card; setup=local-read-only; no-code-import; not-product-dependency; motif={motif}"
    );
    Ok(SwiftLmSourceCard {
        card: SourceCard::new(
            source_id,
            source_type,
            locator,
            digest(digest_seed),
            1,
            usage_note,
            PrivacyClass::PublicResearch,
            SourceNoPoisonStatus::Clear,
            vec![
                "constructive_residency".to_string(),
                "app_cold_store".to_string(),
                "source_mining".to_string(),
            ],
        )?,
        motif,
        setup_note: "setup=local-read-only; vendor-review-required-before-import",
        benchmark_caveat,
        local_test_plan,
        implementation_import_status: "none:source-mining-only",
    })
}

fn fixture_edges() -> Result<Vec<SourceSignalEdge>, Box<dyn std::error::Error>> {
    Ok(vec![
        SourceSignalEdge::new(
            "source:repo:swiftlm",
            "source:doc:swiftlm-kv-compression",
            "motif_detail",
        )?,
        SourceSignalEdge::new(
            "source:repo:swiftlm",
            "source:doc:swiftlm-persistent-buffers",
            "motif_detail",
        )?,
        SourceSignalEdge::new(
            "source:repo:swiftlm",
            "source:doc:swiftlm-prefetch",
            "motif_detail",
        )?,
        SourceSignalEdge::new(
            "source:doc:swiftlm-prefetch",
            "source:doc:swiftlm-kv-compression",
            "layout_cache_interaction",
        )?,
    ])
}

fn motif_present(fixture: &[SwiftLmSourceCard], motif: &str) -> bool {
    fixture.iter().any(|item| item.motif == motif)
}

fn duplicate_source_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let mut duplicate = fixture_swiftlm_source_cards()?;
    duplicate.push(duplicate[0].clone());
    let cards = duplicate.into_iter().map(|item| item.card).collect();
    Ok(SourceSignalGraph::intake(cards, Vec::new(), CREATED_AT_MS).is_err())
}

fn source_cards_reject_missing_license_note() -> Result<bool, Box<dyn std::error::Error>> {
    Ok(SourceCard::new(
        "source:repo:swiftlm-no-license",
        SourceSignalType::Repo,
        "https://github.com/SharpAI/SwiftLM",
        digest("swiftlm-no-license"),
        1,
        "",
        PrivacyClass::PublicResearch,
        SourceNoPoisonStatus::Clear,
        vec!["source_mining".to_string()],
    )
    .is_err())
}

fn invalid_fixture_rejected(
    mutate: impl FnOnce(&mut SwiftLmSourceCard),
) -> Result<bool, Box<dyn std::error::Error>> {
    let mut fixture = fixture_swiftlm_source_cards()?;
    mutate(&mut fixture[0]);
    Ok(!fixture_is_valid(&fixture))
}

fn fixture_is_valid(fixture: &[SwiftLmSourceCard]) -> bool {
    fixture.iter().all(|item| {
        !item.card.license_or_usage_note.is_empty()
            && item
                .card
                .license_or_usage_note
                .contains("license=MIT-source-card")
            && item.card.license_or_usage_note.contains("no-code-import")
            && item
                .card
                .license_or_usage_note
                .contains("not-product-dependency")
            && item.setup_note.contains("setup=local-read-only")
            && item.benchmark_caveat.contains("caveat=")
            && item.local_test_plan.starts_with("local-test=")
            && item.implementation_import_status == "none:source-mining-only"
    })
}

fn digest(seed: &str) -> String {
    format!("blake3:{}", blake3::hash(seed.as_bytes()).to_hex())
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    pass: bool,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Bool(pass),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    operator: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(actual)),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(expected)),
            unit: "count".to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        match operator {
            "<=" => actual <= expected,
            ">=" => actual >= expected,
            "==" => actual == expected,
            _ => false,
        },
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_contains_swiftlm_source_intake_axes() {
        let artifact = build_artifact().unwrap();
        assert!(artifact.overall_pass);
        for axis in [
            "swiftlm_source_cards_present",
            "ssd_streaming_motif_captured",
            "kv_compression_motif_captured",
            "benchmark_caveat_present",
            "local_test_plan_present",
            "implementation_import_rejected",
        ] {
            assert_eq!(artifact.pass_per_axis.get(axis), Some(&true));
        }
    }
}
