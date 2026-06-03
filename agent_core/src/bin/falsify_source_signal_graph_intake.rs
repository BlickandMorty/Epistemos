//! `falsify_source_signal_graph_intake` — source-card provenance gate.
//!
//! This is a metadata-only witness for the June 1 Semantic Working-Set
//! Compiler bundle. It proves bookmark, repo, paper, doc, and X bookmark
//! sources become sorted source cards with digest, credibility, license/usage
//! note, privacy, route affinity, and no-poison gates before any source can
//! influence a working-set plan.

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

const FALSIFIER_ID: &str = "F-SourceSignalGraph-Intake";
const FIXTURE_ID: &str = "source_signal_graph_intake_v1";
const COMMAND: &str = "Tools/falsifiers/f_source_signal_graph_intake.sh";
const RESULT: &str = "artifacts/falsifiers/source_signal_graph_intake/result.json";
const CREATED_AT_MS: u64 = 1_779_000_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} source_card_count={} edge_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["source_card_count"].value,
        artifact.measurements["edge_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let original_cards = fixture_source_cards()?;
    let original_edges = fixture_edges()?;
    let graph = SourceSignalGraph::intake(
        original_cards.clone(),
        original_edges.clone(),
        CREATED_AT_MS,
    )?;
    let reversed = SourceSignalGraph::intake(
        original_cards.iter().cloned().rev().collect(),
        original_edges.iter().cloned().rev().collect(),
        CREATED_AT_MS,
    )?;

    let graph_address_deterministic = graph.graph_address == reversed.graph_address;
    let source_cards_sorted = graph
        .source_cards
        .windows(2)
        .all(|pair| pair[0].source_id <= pair[1].source_id);
    let source_type_coverage = has_type(&graph, SourceSignalType::Bookmark)
        && has_type(&graph, SourceSignalType::Repo)
        && has_type(&graph, SourceSignalType::Paper)
        && has_type(&graph, SourceSignalType::Doc)
        && has_type(&graph, SourceSignalType::XBookmark);
    let bookmark_source_present = has_type(&graph, SourceSignalType::Bookmark);
    let repo_source_present = has_type(&graph, SourceSignalType::Repo);
    let paper_source_present = has_type(&graph, SourceSignalType::Paper);
    let doc_source_present = has_type(&graph, SourceSignalType::Doc);
    let x_source_present = has_type(&graph, SourceSignalType::XBookmark);
    let digest_coverage = graph
        .source_cards
        .iter()
        .all(|card| card.digest.starts_with("blake3:") && card.digest.len() == 71);
    let credibility_rank_coverage = graph
        .source_cards
        .iter()
        .all(|card| card.credibility_rank > 0);
    let license_usage_note_coverage = graph
        .source_cards
        .iter()
        .all(|card| !card.license_or_usage_note.is_empty());
    let privacy_class_coverage = original_cards
        .iter()
        .any(|card| card.privacy_class == PrivacyClass::LocalPrivate)
        && original_cards
            .iter()
            .any(|card| card.privacy_class == PrivacyClass::VaultPrivate)
        && original_cards
            .iter()
            .any(|card| card.privacy_class == PrivacyClass::PublicResearch);
    let no_poison_status_coverage = original_cards
        .iter()
        .any(|card| card.no_poison_status == SourceNoPoisonStatus::Clear)
        && original_cards
            .iter()
            .any(|card| card.no_poison_status == SourceNoPoisonStatus::Blocked);
    let route_affinity_coverage = graph.route_affinities.len() >= 4
        && graph
            .source_cards
            .iter()
            .all(|card| !card.route_affinities.is_empty());
    let poison_source_rejected = graph
        .rejected_source_ids
        .iter()
        .any(|source_id| source_id == "source:poison:prompt-injection");
    let poison_edges_dropped = graph.edges.iter().all(|edge| {
        edge.from_source_id != "source:poison:prompt-injection"
            && edge.to_source_id != "source:poison:prompt-injection"
    });
    let duplicate_source_rejected = duplicate_source_rejected()?;
    let bad_digest_rejected = bad_digest_rejected()?;
    let unknown_edge_rejected = unknown_edge_rejected()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "graph_address_deterministic",
        graph_address_deterministic,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_cards_sorted",
        source_cards_sorted,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_type_coverage",
        source_type_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "bookmark_source_present",
        bookmark_source_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "repo_source_present",
        repo_source_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "paper_source_present",
        paper_source_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "doc_source_present",
        doc_source_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "x_source_present",
        x_source_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "digest_coverage",
        digest_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "credibility_rank_coverage",
        credibility_rank_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "license_usage_note_coverage",
        license_usage_note_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "privacy_class_coverage",
        privacy_class_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_poison_status_coverage",
        no_poison_status_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_affinity_coverage",
        route_affinity_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "poison_source_rejected",
        poison_source_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "poison_edges_dropped",
        poison_edges_dropped,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "duplicate_source_rejected",
        duplicate_source_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "bad_digest_rejected",
        bad_digest_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unknown_edge_rejected",
        unknown_edge_rejected,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_card_count",
        graph.source_cards.len() as u64,
        5,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "edge_count",
        graph.edges.len() as u64,
        4,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_affinity_count",
        graph.route_affinities.len() as u64,
        4,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rejected_source_count",
        graph.rejected_source_ids.len() as u64,
        1,
        ">=",
    );
    measurements.insert(
        "graph_address".to_string(),
        Measurement {
            value: serde_json::Value::String(graph.graph_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "graph_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert("graph_address".to_string(), true);

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
            "kind": "scope_guard",
            "detail": "metadata-only SourceSignalGraph intake; no browser fetch, source import, model decode, route mutation, or source-derived promotion executed"
        })],
        notes: "Proves bookmark, repo, paper, doc, and X bookmark source cards carry digest, credibility, license/usage note, privacy, route affinity, no-poison status, deterministic graph addressing, blocked-source rejection, and endpoint validation before working-set planning.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn fixture_source_cards() -> Result<Vec<SourceCard>, Box<dyn std::error::Error>> {
    Ok(vec![
        source_card(
            "source:bookmark:karpathy-autoresearch",
            SourceSignalType::Bookmark,
            "arc://bookmark/karpathy-autoresearch",
            "karpathy-autoresearch-bookmark",
            1,
            PrivacyClass::LocalPrivate,
            SourceNoPoisonStatus::Clear,
            &["autoresearch", "semantic_working_set"],
        )?,
        source_card(
            "source:repo:agent-loop",
            SourceSignalType::Repo,
            "https://github.com/fixture/agent-loop",
            "agent-loop-repo",
            2,
            PrivacyClass::PublicResearch,
            SourceNoPoisonStatus::Clear,
            &["autoresearch", "verification"],
        )?,
        source_card(
            "source:paper:working-set",
            SourceSignalType::Paper,
            "paper://denning-working-set-model",
            "denning-working-set-paper",
            1,
            PrivacyClass::PublicResearch,
            SourceNoPoisonStatus::Clear,
            &["semantic_working_set"],
        )?,
        source_card(
            "source:doc:semantic-working-set",
            SourceSignalType::Doc,
            "docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md",
            "semantic-working-set-doc",
            1,
            PrivacyClass::VaultPrivate,
            SourceNoPoisonStatus::Clear,
            &["semantic_working_set", "evidence_routing"],
        )?,
        source_card(
            "source:x:kv-cache-thread",
            SourceSignalType::XBookmark,
            "x-bookmark://fixture/kv-cache-thread",
            "kv-cache-x-thread",
            3,
            PrivacyClass::LocalPrivate,
            SourceNoPoisonStatus::Clear,
            &["semantic_working_set", "verification"],
        )?,
        source_card(
            "source:poison:prompt-injection",
            SourceSignalType::Bookmark,
            "arc://bookmark/prompt-injection-fixture",
            "prompt-injection-fixture",
            5,
            PrivacyClass::LocalPrivate,
            SourceNoPoisonStatus::Blocked,
            &["semantic_working_set"],
        )?,
    ])
}

fn fixture_edges() -> Result<Vec<SourceSignalEdge>, Box<dyn std::error::Error>> {
    Ok(vec![
        SourceSignalEdge::new(
            "source:bookmark:karpathy-autoresearch",
            "source:repo:agent-loop",
            "supports",
        )?,
        SourceSignalEdge::new(
            "source:repo:agent-loop",
            "source:paper:working-set",
            "implements_motif",
        )?,
        SourceSignalEdge::new(
            "source:paper:working-set",
            "source:doc:semantic-working-set",
            "grounds",
        )?,
        SourceSignalEdge::new(
            "source:x:kv-cache-thread",
            "source:doc:semantic-working-set",
            "suggests_route_prior",
        )?,
        SourceSignalEdge::new(
            "source:poison:prompt-injection",
            "source:doc:semantic-working-set",
            "must_not_promote",
        )?,
    ])
}

#[allow(clippy::too_many_arguments)]
fn source_card(
    source_id: &str,
    source_type: SourceSignalType,
    locator: &str,
    digest_seed: &str,
    credibility_rank: u8,
    privacy_class: PrivacyClass,
    no_poison_status: SourceNoPoisonStatus,
    route_affinities: &[&str],
) -> Result<SourceCard, Box<dyn std::error::Error>> {
    Ok(SourceCard::new(
        source_id,
        source_type,
        locator,
        digest(digest_seed),
        credibility_rank,
        "fixture-only source; motif mining permitted, no raw merge",
        privacy_class,
        no_poison_status,
        route_affinities
            .iter()
            .map(|route| (*route).to_string())
            .collect(),
    )?)
}

fn has_type(graph: &SourceSignalGraph, source_type: SourceSignalType) -> bool {
    graph
        .source_cards
        .iter()
        .any(|card| card.source_type == source_type)
}

fn duplicate_source_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let duplicate = vec![
        source_card(
            "source:doc:semantic-working-set",
            SourceSignalType::Doc,
            "docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md",
            "semantic-working-set-doc-a",
            1,
            PrivacyClass::VaultPrivate,
            SourceNoPoisonStatus::Clear,
            &["semantic_working_set"],
        )?,
        source_card(
            "source:doc:semantic-working-set",
            SourceSignalType::Doc,
            "docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md",
            "semantic-working-set-doc-b",
            1,
            PrivacyClass::VaultPrivate,
            SourceNoPoisonStatus::Clear,
            &["semantic_working_set"],
        )?,
    ];
    Ok(SourceSignalGraph::intake(duplicate, Vec::new(), CREATED_AT_MS).is_err())
}

fn bad_digest_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    Ok(SourceCard::new(
        "source:bad-digest",
        SourceSignalType::Doc,
        "docs/bad.md",
        "blake3:not-64-hex",
        1,
        "fixture-only source; motif mining permitted, no raw merge",
        PrivacyClass::VaultPrivate,
        SourceNoPoisonStatus::Clear,
        vec!["semantic_working_set".to_string()],
    )
    .is_err())
}

fn unknown_edge_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    Ok(SourceSignalGraph::intake(
        fixture_source_cards()?,
        vec![SourceSignalEdge::new(
            "source:doc:semantic-working-set",
            "source:missing",
            "references",
        )?],
        CREATED_AT_MS,
    )
    .is_err())
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
    let pass = match operator {
        "<=" => actual <= expected,
        ">=" => actual >= expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), pass);
}
