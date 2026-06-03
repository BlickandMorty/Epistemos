//! `falsify_source_to_residency_no_poison` — source promotion guard.
//!
//! This fixture-only witness proves source-derived layout/cache/route/prompt
//! patches cannot promote from poisoned, stale, private, corrupted,
//! license-blocked, or low-credibility sources. It does not fetch sources,
//! import code, rewrite layout, mutate route policy, or run MLX/Metal.

use std::collections::{BTreeMap, HashSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    PrivacyClass, SemanticWorkingSetError, SourceCard, SourceNoPoisonStatus, SourceSignalEdge,
    SourceSignalGraph, SourceSignalType, SourceToResidencyPatch, SourceToResidencyPatchKind,
    SourceToResidencyPromotionStatus,
};

const FALSIFIER_ID: &str = "F-SourceToResidency-NoPoison";
const FIXTURE_ID: &str = "source_to_residency_no_poison_v1";
const COMMAND: &str = "Tools/falsifiers/f_source_to_residency_no_poison.sh";
const RESULT: &str = "artifacts/falsifiers/source_to_residency_no_poison/result.json";
const CREATED_AT_MS: u64 = 1_779_000_000_000;
const IMPORT_GATE: &str = "source:no-poison+license+digest+privacy+credibility";
const REQUIRED_FALSIFIER: &str = "F-SourceToResidency-NoPoison";
const ROLLBACK_REF: &str = "rollback:source-to-residency-no-poison";

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
        "{FALSIFIER_ID}: overall_pass={} patch_count={} rejected_fixture_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["patch_count"].value,
        artifact.measurements["rejected_fixture_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let graph = fixture_graph()?;
    let reversed = SourceSignalGraph::intake(
        fixture_source_cards()?.into_iter().rev().collect(),
        fixture_edges()?.into_iter().rev().collect(),
        CREATED_AT_MS,
    )?;
    let layout_patch = patch_for(
        &graph,
        "source:paper:working-set",
        SourceToResidencyPatchKind::Layout,
    )?;
    let cache_patch = patch_for(
        &graph,
        "source:repo:agent-loop",
        SourceToResidencyPatchKind::Cache,
    )?;
    let route_patch = patch_for(
        &graph,
        "source:paper:working-set",
        SourceToResidencyPatchKind::Route,
    )?;
    let prompt_patch = patch_for(
        &graph,
        "source:repo:agent-loop",
        SourceToResidencyPatchKind::Prompt,
    )?;
    let reversed_patch = patch_for(
        &reversed,
        "source:paper:working-set",
        SourceToResidencyPatchKind::Layout,
    )?;

    let accepted_patches = vec![layout_patch.clone(), cache_patch, route_patch, prompt_patch];
    let patch_address_deterministic = layout_patch.patch_address == reversed_patch.patch_address;
    let source_graph_address_bound = accepted_patches
        .iter()
        .all(|patch| patch.source_graph_address == graph.graph_address);
    let source_digest_bound = accepted_patches
        .iter()
        .all(|patch| patch.source_digest.starts_with("blake3:"));
    let affected_organs_bound = accepted_patches
        .iter()
        .all(|patch| !patch.affected_organs.is_empty());
    let import_gate_bound = accepted_patches
        .iter()
        .all(|patch| patch.import_gate == IMPORT_GATE);
    let falsifier_required_bound = accepted_patches
        .iter()
        .all(|patch| patch.falsifier_required == REQUIRED_FALSIFIER);
    let rollback_bound = accepted_patches
        .iter()
        .all(|patch| patch.rollback_ref == ROLLBACK_REF);
    let promotion_status_shadow_candidate = accepted_patches
        .iter()
        .all(|patch| patch.promotion_status == SourceToResidencyPromotionStatus::ShadowCandidate);
    let patch_kinds_coverage = {
        let kinds = accepted_patches
            .iter()
            .map(|patch| patch.patch_kind)
            .collect::<HashSet<_>>();
        kinds.contains(&SourceToResidencyPatchKind::Layout)
            && kinds.contains(&SourceToResidencyPatchKind::Cache)
            && kinds.contains(&SourceToResidencyPatchKind::Route)
            && kinds.contains(&SourceToResidencyPatchKind::Prompt)
    };

    let blocked_poison_source_rejected = promotion_blocked(
        &graph,
        "source:poison:prompt-injection",
        digest("prompt-injection-fixture"),
    )?;
    let stale_digest_rejected = promotion_blocked(
        &graph,
        "source:paper:working-set",
        digest("changed-working-set-paper"),
    )?;
    let private_source_rejected = promotion_blocked(
        &graph,
        "source:doc:semantic-working-set",
        digest("semantic-working-set-doc"),
    )?;
    let license_blocked_source_rejected = promotion_blocked(
        &graph,
        "source:repo:license-blocked",
        digest("license-blocked-repo"),
    )?;
    let low_credibility_source_rejected = promotion_blocked(
        &graph,
        "source:paper:low-credibility",
        digest("low-credibility-paper"),
    )?;
    let unknown_source_rejected =
        promotion_blocked(&graph, "source:missing", digest("missing-source"))?;
    let missing_falsifier_gate_rejected = missing_falsifier_gate_rejected(&graph)?;
    let missing_rollback_rejected = missing_rollback_rejected(&graph)?;
    let empty_affected_organs_rejected = empty_affected_organs_rejected(&graph)?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "valid_patch_created",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "patch_address_deterministic",
        patch_address_deterministic,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_graph_address_bound",
        source_graph_address_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_digest_bound",
        source_digest_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "affected_organs_bound",
        affected_organs_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "import_gate_bound",
        import_gate_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "falsifier_required_bound",
        falsifier_required_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rollback_bound",
        rollback_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "promotion_status_shadow_candidate",
        promotion_status_shadow_candidate,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "patch_kinds_coverage",
        patch_kinds_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "blocked_poison_source_rejected",
        blocked_poison_source_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "stale_digest_rejected",
        stale_digest_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "private_source_rejected",
        private_source_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "license_blocked_source_rejected",
        license_blocked_source_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "low_credibility_source_rejected",
        low_credibility_source_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unknown_source_rejected",
        unknown_source_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_falsifier_gate_rejected",
        missing_falsifier_gate_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_rollback_rejected",
        missing_rollback_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "empty_affected_organs_rejected",
        empty_affected_organs_rejected,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "patch_count",
        accepted_patches.len() as u64,
        4,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rejected_fixture_count",
        9,
        9,
        ">=",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "patch_address",
        &layout_patch.patch_address.to_string(),
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
            "kind": "scope_guard",
            "detail": "fixture-only source-to-residency promotion guard; no source fetch, code import, layout rewrite, cache mutation, route mutation, model decode, MLX/Metal, or live policy change executed"
        })],
        notes: "Proves source-derived layout/cache/route/prompt patches stay shadow candidates and fail closed for poisoned, stale/corrupted, private, license-blocked, low-credibility, unknown, missing-falsifier, missing-rollback, or empty-organ fixtures.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn patch_for(
    graph: &SourceSignalGraph,
    source_id: &str,
    patch_kind: SourceToResidencyPatchKind,
) -> Result<SourceToResidencyPatch, Box<dyn std::error::Error>> {
    let digest = graph
        .source_cards
        .iter()
        .find(|card| card.source_id == source_id)
        .map(|card| card.digest.clone())
        .ok_or("source fixture missing")?;
    let proposed_unit_or_policy = match patch_kind {
        SourceToResidencyPatchKind::Layout => "layout:working-set-tile",
        SourceToResidencyPatchKind::Cache => "cache:prefix-reuse-shadow",
        SourceToResidencyPatchKind::Route => "route:source-derived-prior",
        SourceToResidencyPatchKind::Prompt => "prompt:source-grounded-caveat",
    };
    Ok(SourceToResidencyPatch::from_source_signal(
        graph,
        source_id,
        digest,
        patch_kind,
        proposed_unit_or_policy,
        vec!["app_cold_store".to_string(), "runtime_router".to_string()],
        IMPORT_GATE,
        REQUIRED_FALSIFIER,
        ROLLBACK_REF,
        CREATED_AT_MS,
    )?)
}

fn promotion_blocked(
    graph: &SourceSignalGraph,
    source_id: &str,
    expected_digest: String,
) -> Result<bool, Box<dyn std::error::Error>> {
    let error = SourceToResidencyPatch::from_source_signal(
        graph,
        source_id,
        expected_digest,
        SourceToResidencyPatchKind::Route,
        "route:source-derived-prior",
        vec!["runtime_router".to_string()],
        IMPORT_GATE,
        REQUIRED_FALSIFIER,
        ROLLBACK_REF,
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::SourcePromotionBlocked { .. }
    ))
}

fn missing_falsifier_gate_rejected(
    graph: &SourceSignalGraph,
) -> Result<bool, Box<dyn std::error::Error>> {
    let source = source(graph, "source:paper:working-set")?;
    let error = SourceToResidencyPatch::from_source_signal(
        graph,
        &source.source_id,
        &source.digest,
        SourceToResidencyPatchKind::Route,
        "route:source-derived-prior",
        vec!["runtime_router".to_string()],
        IMPORT_GATE,
        "source-to-residency-no-poison",
        ROLLBACK_REF,
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::SourcePromotionBlocked { .. }
    ))
}

fn missing_rollback_rejected(
    graph: &SourceSignalGraph,
) -> Result<bool, Box<dyn std::error::Error>> {
    let source = source(graph, "source:paper:working-set")?;
    let error = SourceToResidencyPatch::from_source_signal(
        graph,
        &source.source_id,
        &source.digest,
        SourceToResidencyPatchKind::Route,
        "route:source-derived-prior",
        vec!["runtime_router".to_string()],
        IMPORT_GATE,
        REQUIRED_FALSIFIER,
        "source-to-residency-no-poison",
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::SourcePromotionBlocked { .. }
    ))
}

fn empty_affected_organs_rejected(
    graph: &SourceSignalGraph,
) -> Result<bool, Box<dyn std::error::Error>> {
    let source = source(graph, "source:paper:working-set")?;
    Ok(SourceToResidencyPatch::from_source_signal(
        graph,
        &source.source_id,
        &source.digest,
        SourceToResidencyPatchKind::Route,
        "route:source-derived-prior",
        Vec::new(),
        IMPORT_GATE,
        REQUIRED_FALSIFIER,
        ROLLBACK_REF,
        CREATED_AT_MS,
    )
    .is_err())
}

fn source<'a>(
    graph: &'a SourceSignalGraph,
    source_id: &str,
) -> Result<&'a SourceCard, Box<dyn std::error::Error>> {
    graph
        .source_cards
        .iter()
        .find(|card| card.source_id == source_id)
        .ok_or_else(|| format!("{source_id} missing").into())
}

fn fixture_graph() -> Result<SourceSignalGraph, Box<dyn std::error::Error>> {
    Ok(SourceSignalGraph::intake(
        fixture_source_cards()?,
        fixture_edges()?,
        CREATED_AT_MS,
    )?)
}

fn fixture_source_cards() -> Result<Vec<SourceCard>, Box<dyn std::error::Error>> {
    Ok(vec![
        source_card(
            "source:paper:working-set",
            SourceSignalType::Paper,
            "paper://denning-working-set-model",
            "denning-working-set-paper",
            1,
            "fixture-only public paper; motif mining permitted",
            PrivacyClass::PublicResearch,
            SourceNoPoisonStatus::Clear,
            &["semantic_working_set"],
        )?,
        source_card(
            "source:repo:agent-loop",
            SourceSignalType::Repo,
            "https://github.com/fixture/agent-loop",
            "agent-loop-repo",
            2,
            "fixture-only public repo; motif mining permitted",
            PrivacyClass::PublicResearch,
            SourceNoPoisonStatus::Clear,
            &["autoresearch", "verification"],
        )?,
        source_card(
            "source:doc:semantic-working-set",
            SourceSignalType::Doc,
            "docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md",
            "semantic-working-set-doc",
            1,
            "vault-private source; evidence okay, residency promotion blocked",
            PrivacyClass::VaultPrivate,
            SourceNoPoisonStatus::Clear,
            &["semantic_working_set"],
        )?,
        source_card(
            "source:repo:license-blocked",
            SourceSignalType::Repo,
            "https://github.com/fixture/license-blocked",
            "license-blocked-repo",
            1,
            "license-blocked: no residency promotion",
            PrivacyClass::PublicResearch,
            SourceNoPoisonStatus::Clear,
            &["semantic_working_set"],
        )?,
        source_card(
            "source:paper:low-credibility",
            SourceSignalType::Paper,
            "paper://low-credibility",
            "low-credibility-paper",
            9,
            "fixture-only public source; credibility too low",
            PrivacyClass::PublicResearch,
            SourceNoPoisonStatus::Clear,
            &["semantic_working_set"],
        )?,
        source_card(
            "source:poison:prompt-injection",
            SourceSignalType::Bookmark,
            "arc://bookmark/prompt-injection-fixture",
            "prompt-injection-fixture",
            1,
            "fixture-only poisoned source",
            PrivacyClass::PublicResearch,
            SourceNoPoisonStatus::Blocked,
            &["semantic_working_set"],
        )?,
    ])
}

fn fixture_edges() -> Result<Vec<SourceSignalEdge>, Box<dyn std::error::Error>> {
    Ok(vec![
        SourceSignalEdge::new(
            "source:paper:working-set",
            "source:repo:agent-loop",
            "supports",
        )?,
        SourceSignalEdge::new(
            "source:poison:prompt-injection",
            "source:paper:working-set",
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
    license_or_usage_note: &str,
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
        license_or_usage_note,
        privacy_class,
        no_poison_status,
        route_affinities
            .iter()
            .map(|route| (*route).to_string())
            .collect(),
    )?)
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
        "==" => actual == expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
) {
    let pass = !value.is_empty();
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "string".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "string".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}
