//! `falsify_local_tool_use` - fallback witness for RuntimeRouter tool lanes.
//!
//! The primary falsifier lives in Swift (`EpistemosTests/FLocalToolUseTests`),
//! where the real model catalog and router types are compiled. This Rust
//! harness keeps the old Terminal T1 follow-up honest by emitting a durable
//! artifact that proves the Swift falsifier, local-first tool-caller chain, and
//! grammar/capability guards are still present on main.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-LocalToolUse";
const FIXTURE_ID: &str = "local_tool_use_source_witness_v1";
const COMMAND: &str = "Tools/falsifiers/f_local_tool_use.sh";
const RESULT: &str = "artifacts/falsifiers/local_tool_use/result.json";

const INFERENCE_STATE: &str = "Epistemos/State/InferenceState.swift";
const LOCAL_TOOL_GRAMMAR: &str = "Epistemos/LocalAgent/LocalToolGrammar.swift";
const RUNTIME_ROUTER: &str = "Epistemos/LocalAgent/RuntimeRouter.swift";
const RUNTIME_TESTS: &str = "EpistemosTests/RuntimeRouterTests.swift";
const F_LOCAL_TOOL_USE_TESTS: &str = "EpistemosTests/FLocalToolUseTests.swift";
const POLICY_ORDER_GUARD: &str = "agent_core/tests/runtime_router_policy_order_source_guard.rs";

fn main() -> std::process::ExitCode {
    let report = build_report();
    let path = repo_path(RESULT);
    if let Some(parent) = path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create {FALSIFIER_ID} artifact directory: {error}");
            return std::process::ExitCode::from(2);
        }
    }
    let mut file = match std::fs::File::create(&path) {
        Ok(file) => file,
        Err(error) => {
            eprintln!("failed to open {FALSIFIER_ID} artifact: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    if let Err(error) = write_artifact(&mut file, &report) {
        eprintln!("failed to write {FALSIFIER_ID} artifact: {error}");
        return std::process::ExitCode::from(2);
    }
    println!(
        "{FALSIFIER_ID}: overall_pass={} agent_capable_models={} artifact={}",
        report.overall_pass,
        report
            .measurements
            .get("agent_capable_model_count")
            .and_then(|m| m.value.as_u64())
            .unwrap_or(0),
        path.display()
    );
    if report.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_report() -> agent_core::falsifier_artifacts::FalsifierArtifact {
    let inference = SourceFile::read(INFERENCE_STATE);
    let grammar = SourceFile::read(LOCAL_TOOL_GRAMMAR);
    let router = SourceFile::read(RUNTIME_ROUTER);
    let runtime_tests = SourceFile::read(RUNTIME_TESTS);
    let swift_falsifier = SourceFile::read(F_LOCAL_TOOL_USE_TESTS);
    let policy_guard = SourceFile::read(POLICY_ORDER_GUARD);

    let agent_models = agent_capable_models(&inference.text);
    let model_count = agent_models.len() as u64;
    let tool_caller_chain = default_tool_caller_chain_is_local_first(&router.text);

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_files_present",
        [
            &inference,
            &grammar,
            &router,
            &runtime_tests,
            &swift_falsifier,
            &policy_guard,
        ]
        .iter()
        .all(|source| source.exists),
    );
    add_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "agent_capable_model_count",
        model_count,
        20,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "agent_capable_catalog_not_empty",
        model_count > 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "swift_flocaltooluse_suite_present",
        swift_falsifier.contains("@Suite(\"F-LocalToolUse")
            && swift_falsifier.contains("everyAgentCapableModelHasAViableLocalLane")
            && swift_falsifier.contains("smallestAgentCapableModelRoundTripsThroughLocalLane"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "swift_flocaltooluse_blocks_silent_cloud_escalation",
        swift_falsifier.contains("!lane.isLocal")
            && swift_falsifier.contains("silent cloud escalation hazard"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "swift_flocaltooluse_checks_native_grammar",
        swift_falsifier.contains("LocalToolGrammar.nativeGrammar(forModelID: model.rawValue)")
            && swift_falsifier
                .contains("capability.grammarSupport.contains(nativeGrammar.rawValue)")
            && swift_falsifier.contains("capability.toolCallMode == .softGuidance"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "tool_caller_chain_keeps_gguf_before_cloud",
        tool_caller_chain,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_guard_pins_tool_caller_local_first",
        policy_guard.contains("tool_caller_chain_keeps_gguf_local_before_cloud_fallback"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_swift_test_pins_tool_caller_local_first",
        runtime_tests.contains("toolCallerKeepsGGUFBeforeCloudFallback")
            && runtime_tests.contains("lane == .gguf")
            && runtime_tests.contains(".cloud(provider: \"claude\")).accepts == 0"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mlx_lane_supports_agent_tool_grammars",
        router.contains("case .mlx")
            && router
                .contains("grammarSupport: [\"qwen_xml\", \"hermes_json\", \"canonical_xml\"]")
            && router.contains("toolCallMode: .native"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "gguf_lane_keeps_soft_guidance_tool_path",
        router.contains("case .gguf")
            && router.contains("grammarSupport: [\"canonical_xml\", \"hermes_json\"]")
            && router.contains("toolCallMode: .softGuidance"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "badge_data_uses_catalog_and_lane_capability",
        router.contains("model?.canActAsAgent == true")
            && router.contains("laneHonorsGrammar")
            && router.contains("RuntimeAgentCapabilityState"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "native_grammar_resolver_covers_current_agent_families",
        grammar.contains("normalized.contains(\"hermes\")")
            && grammar.contains("normalized.contains(\"qwen\")")
            && grammar.contains("normalized.contains(\"qwopus\")")
            && grammar.contains("return .canonicalXML"),
    );

    measurements.insert(
        "agent_capable_models".to_string(),
        Measurement {
            value: serde_json::Value::Array(
                agent_models
                    .iter()
                    .map(|model| serde_json::Value::String(model.clone()))
                    .collect(),
            ),
            unit: "list".to_string(),
        },
    );
    add_source_summary(&mut measurements, "inference_state", &inference);
    add_source_summary(&mut measurements, "local_tool_grammar", &grammar);
    add_source_summary(&mut measurements, "runtime_router", &router);
    add_source_summary(&mut measurements, "runtime_router_tests", &runtime_tests);
    add_source_summary(
        &mut measurements,
        "f_local_tool_use_tests",
        &swift_falsifier,
    );
    add_source_summary(&mut measurements, "policy_order_guard", &policy_guard);

    let overall = pass_per_axis.values().copied().all(|passed| passed);
    ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: if overall {
            ArtifactKind::FallbackWitness
        } else {
            ArtifactKind::FailureReport
        },
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: if overall {
            FallbackTier::Fallback
        } else {
            FallbackTier::Fail
        },
        anomalies: vec![serde_json::json!({
            "kind": "fallback_witness",
            "detail": "Rust proves source, router order, Swift falsifier, and grammar guards; the primary route behavior remains the Swift FLocalToolUse test suite."
        })],
        notes: format!(
            "local_tool_use_source_witness; agent_capable_models={model_count}; \
             proves the missing Terminal T1 Rust-side artifact without claiming live inference."
        ),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build()
}

#[derive(Debug)]
struct SourceFile {
    path: &'static str,
    exists: bool,
    text: String,
}

impl SourceFile {
    fn read(path: &'static str) -> Self {
        let resolved = repo_path(path);
        Self {
            path,
            exists: resolved.exists(),
            text: std::fs::read_to_string(resolved).unwrap_or_default(),
        }
    }

    fn contains(&self, needle: &str) -> bool {
        self.text.contains(needle)
    }
}

fn agent_capable_models(source: &str) -> BTreeSet<String> {
    let Some(section) = section_between(
        source,
        "var canActAsAgent: Bool",
        "var canRunLocalAgentLoop",
    ) else {
        return BTreeSet::new();
    };
    let Some(switch_start) = section.find("switch self") else {
        return BTreeSet::new();
    };
    let mut true_branch = String::new();
    for line in section[switch_start..].lines() {
        let source_line = line
            .split_once("//")
            .map_or(line, |(before_comment, _)| before_comment);
        if source_line.trim_start().starts_with("true") {
            break;
        }
        let branch_line = source_line
            .split_once(':')
            .map_or(source_line, |(before_colon, _)| before_colon);
        if source_line.contains("case ") || source_line.trim_start().starts_with('.') {
            true_branch.push_str(branch_line);
            true_branch.push('\n');
        }
        if source_line.contains(": true") {
            break;
        }
    }
    model_cases(&true_branch)
}

fn model_cases(source: &str) -> BTreeSet<String> {
    let mut models = BTreeSet::new();
    for token in source.split(',') {
        let trimmed = token.trim().trim_start_matches("case ").trim();
        let Some(fragment) = trimmed.strip_prefix('.') else {
            continue;
        };
        let name: String = fragment
            .chars()
            .take_while(|c| c.is_ascii_alphanumeric() || *c == '_')
            .collect();
        if !name.is_empty() {
            models.insert(name);
        }
    }
    models
}

fn default_tool_caller_chain_is_local_first(source: &str) -> bool {
    let Some(section) = section_between(
        source,
        "nonisolated public static func defaultPreferredLanes(for role: RuntimeRole) -> [RuntimeLane]",
        "nonisolated private static func defaultLocalPolicy(for role: RuntimeRole)",
    ) else {
        return false;
    };
    let Some(start) = section.find("case .toolCaller:") else {
        return false;
    };
    let tail = &section[start..];
    let Some(end) = tail.find("case .trivial:") else {
        return false;
    };
    let block = &tail[..end];
    let Some(mlx) = block.find(".mlx") else {
        return false;
    };
    let Some(gguf) = block.find(".gguf") else {
        return false;
    };
    let Some(claude) = block.find(".cloud(provider: \"claude\")") else {
        return false;
    };
    let Some(openai) = block.find(".cloud(provider: \"openai\")") else {
        return false;
    };
    mlx < gguf && gguf < claude && gguf < openai
}

fn section_between<'a>(source: &'a str, start: &str, end: &str) -> Option<&'a str> {
    let start_index = source.find(start)?;
    let tail = &source[start_index..];
    let end_index = tail.find(end)?;
    Some(&tail[..end_index])
}

fn add_count_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    actual: u64,
    minimum: u64,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::from(minimum),
            unit: "count".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), actual >= minimum);
}

fn add_source_summary(
    measurements: &mut BTreeMap<String, Measurement>,
    label: &str,
    source: &SourceFile,
) {
    measurements.insert(
        format!("{label}_source"),
        Measurement {
            value: serde_json::json!({
                "path": source.path,
                "exists": source.exists,
                "bytes": source.text.len(),
            }),
            unit: "object".to_string(),
        },
    );
}

fn repo_path(path: &str) -> PathBuf {
    let path = Path::new(path);
    if path.is_absolute() {
        return path.to_path_buf();
    }
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let repo_root = manifest_dir.parent().unwrap_or(&manifest_dir);
    repo_root.join(path)
}

#[cfg(test)]
mod tests {
    #[test]
    fn agent_model_parser_only_reads_true_branch_cases() {
        let source = r#"
            var canActAsAgent: Bool {
                // prose mentions .swift and .write but neither is a model
                switch self {
                case .qwen35_4B4Bit, .qwen3_8B4Bit,
                     .localAgent43_36B4Bit:
                    true
                case .gemma4_4B4Bit:
                    false
                default:
                    false
                }
            }

            var canRunLocalAgentLoop: Bool { canActAsAgent }
        "#;
        let models = super::agent_capable_models(source);
        assert_eq!(models.len(), 3);
        assert!(models.contains("qwen35_4B4Bit"));
        assert!(models.contains("qwen3_8B4Bit"));
        assert!(models.contains("localAgent43_36B4Bit"));
        assert!(!models.contains("gemma4_4B4Bit"));
        assert!(!models.contains("swift"));
        assert!(!models.contains("write"));
    }

    #[test]
    fn report_is_green_fallback_witness() {
        let report = super::build_report();
        assert!(report.overall_pass);
        assert_eq!(report.falsifier_id, super::FALSIFIER_ID);
        assert_eq!(report.artifact_kind, "fallback_witness");
    }
}
