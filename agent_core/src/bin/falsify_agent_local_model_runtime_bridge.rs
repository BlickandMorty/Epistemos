//! `falsify_agent_local_model_runtime_bridge` - witness for the local-model
//! agent runtime seam.
//!
//! The product already has a real local model catalog, MLX/GGUF runtime
//! clients, and a System G event seam. This harness keeps the deeper claim
//! honest: a Rust `ProviderPolicy::LocalMlx` request may hand off to the Swift
//! host, but the architecture is not promoted until a live local-model prompt
//! suite proves the end-to-end path on this machine.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-Agent-Local-Model-Runtime-Bridge";
const FIXTURE_ID: &str = "agent_local_model_runtime_bridge_source_audit_v1";
const COMMAND: &str = "Tools/falsifiers/f_agent_local_model_runtime_bridge.sh";

const LOCAL_MODEL_INFRASTRUCTURE: &str = "Epistemos/Engine/LocalModelInfrastructure.swift";
const MLX_INFERENCE_SERVICE: &str = "Epistemos/Engine/MLXInferenceService.swift";
const LOCAL_GGUF_CLIENT: &str = "Epistemos/Engine/LocalGGUFClient.swift";
const BLUEPRINT: &str = "agent_core/src/agent_runtime_v2/blueprint.rs";
const SYSTEM_G_RUNTIME: &str = "agent_core/src/agent_runtime_v2/system_g_runtime.rs";
const LOCAL_AGENT_ADAPTER: &str = "agent_core/src/agent_runtime_v2/adapters/local_agent.rs";
const SWIFT_SYSTEM_G_SEAM: &str = "Epistemos/SystemG/SystemGRunSeam.swift";
const REAL_SYSTEM_G_SEAM: &str = "Epistemos/SystemG/RealSystemGRunSeam.swift";
const APP_BOOTSTRAP: &str = "Epistemos/App/AppBootstrap.swift";
const SYSTEM_G_RUN_SEAM_TESTS: &str = "EpistemosTests/SystemGRunSeamTests.swift";
const LIVE_PROMPT_SUITE_RESULT: &str =
    "artifacts/falsifiers/agent_local_model_runtime_bridge/live_prompt_suite.json";

fn main() {
    let report = build_report();
    let path = PathBuf::from("artifacts/falsifiers/agent_local_model_runtime_bridge/result.json");
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create agent local runtime bridge artifact dir");
    }
    let mut file = std::fs::File::create(&path).expect("open agent local runtime bridge artifact");
    write_artifact(&mut file, &report.artifact).expect("write agent local runtime bridge artifact");

    println!(
        "F-Agent-Local-Model-Runtime-Bridge: overall_pass={} next_bottleneck={} artifact={}",
        report.artifact.overall_pass,
        report.next_bottleneck,
        path.display()
    );

    if !report.artifact.overall_pass {
        std::process::exit(1);
    }
}

struct BridgeReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    next_bottleneck: String,
}

fn build_report() -> BridgeReport {
    let local_model = SourceFile::read(LOCAL_MODEL_INFRASTRUCTURE);
    let mlx = SourceFile::read(MLX_INFERENCE_SERVICE);
    let gguf = SourceFile::read(LOCAL_GGUF_CLIENT);
    let blueprint = SourceFile::read(BLUEPRINT);
    let system_g = SourceFile::read(SYSTEM_G_RUNTIME);
    let local_agent = SourceFile::read(LOCAL_AGENT_ADAPTER);
    let swift_system_g = SourceFile::read(SWIFT_SYSTEM_G_SEAM);
    let real_system_g = SourceFile::read(REAL_SYSTEM_G_SEAM);
    let app_bootstrap = SourceFile::read(APP_BOOTSTRAP);
    let swift_tests = SourceFile::read(SYSTEM_G_RUN_SEAM_TESTS);

    let local_model_catalog_available = local_model.exists
        && local_model.contains("enum LocalModelCatalog")
        && local_model.contains("qwen3_8B4Bit");
    let qwen3_floor_fallback_preserved =
        local_model.contains("fallbackPrimaryAgentModel: LocalTextModelID = .qwen3_8B4Bit");
    let dense_36b_gate_preserved = local_model.contains("primaryAgentModelMinHostRAMGB: Int = 32")
        && local_model.contains("primaryAgentModelMinHostRAMGB_powerUser: Int = 32");
    let mlx_runtime_client_available =
        mlx.exists && mlx.contains("MLXInferenceService") && mlx.contains("runtimeKind == .mlx");
    let gguf_runtime_client_available = gguf.exists
        && gguf.contains("LocalGGUFClient")
        && gguf.contains("RoutedLocalRuntimeClient");
    let provider_policy_local_mlx_available =
        blueprint.exists && blueprint.contains("ProviderPolicy") && blueprint.contains("LocalMlx");
    let system_g_event_seam_available = system_g.exists
        && system_g.contains("MissionPacket")
        && system_g.contains("SystemGAgentEvent stream")
        && system_g.contains("RunEventLog")
        && system_g.contains("AnswerPacket")
        && system_g.contains("pub fn start_run");
    let system_g_dispatch_is_synthetic = system_g.contains("Real provider hooks")
        && system_g.contains("text: packet.user_prompt.clone()")
        && system_g.contains("fn execute_v1_dispatch");
    let rust_local_mlx_handoff_wired = system_g_event_seam_available
        && provider_policy_local_mlx_available
        && system_g.contains("start_run_with_provider_policy")
        && system_g.contains("ProviderPolicy::LocalMlx")
        && system_g.contains("LocalModelHandoff")
        && system_g.contains("provider_policy_json")
        && system_g.contains("execute_provider_policy_route");
    let swift_local_model_handoff_event_wired = swift_system_g.exists
        && swift_system_g.contains("localModelHandoff")
        && swift_system_g.contains("local_model_handoff")
        && swift_system_g.contains("providerPolicyJSON");
    let swift_local_model_handoff_consumed = real_system_g.exists
        && real_system_g.contains("systemGStartRunWithProviderJson")
        && real_system_g.contains(".localModelHandoff")
        && real_system_g.contains("completeLocalModelHandoff")
        && real_system_g.contains("localProvider.client.stream");
    let app_bootstrap_local_client_registered = app_bootstrap.exists
        && app_bootstrap.contains("RealSystemGRunSeam(localModelClient: localLLMClient)");
    let focused_swift_handoff_test_present = swift_tests.exists
        && swift_tests.contains("streams local model missions")
        && swift_tests.contains("localModelHandoff")
        && swift_tests.contains("providerPolicyJSON");
    let local_agent_adapter_is_scaffold = local_agent
        .contains("actual `LocalAgentAdapter::dispatch` body lands")
        || !local_agent.contains("pub fn dispatch");
    let system_g_local_model_provider_dispatch_wired = rust_local_mlx_handoff_wired
        && swift_local_model_handoff_event_wired
        && swift_local_model_handoff_consumed
        && app_bootstrap_local_client_registered;
    let local_agent_adapter_dispatch_wired =
        local_agent.exists && !local_agent_adapter_is_scaffold && local_agent.contains("dispatch");
    let live_local_model_answerpacket_provenance_wired =
        system_g_local_model_provider_dispatch_wired
            && real_system_g.contains("system_g_local_model")
            && real_system_g.contains("model_id:")
            && real_system_g.contains("AnswerPacketEmitter.shared.emit");
    let live_prompt_suite = LivePromptSuiteArtifact::read(LIVE_PROMPT_SUITE_RESULT);
    let live_agent_local_model_prompt_suite_passed = live_prompt_suite.passed;

    let next_bottleneck = choose_next_bottleneck(
        local_model_catalog_available,
        mlx_runtime_client_available || gguf_runtime_client_available,
        provider_policy_local_mlx_available,
        system_g_event_seam_available,
        local_agent_adapter_dispatch_wired,
        rust_local_mlx_handoff_wired,
        swift_local_model_handoff_event_wired,
        swift_local_model_handoff_consumed,
        app_bootstrap_local_client_registered,
        focused_swift_handoff_test_present,
        system_g_local_model_provider_dispatch_wired,
        live_local_model_answerpacket_provenance_wired,
        live_agent_local_model_prompt_suite_passed,
    );

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_files_present",
        [
            &local_model,
            &mlx,
            &gguf,
            &blueprint,
            &system_g,
            &local_agent,
            &swift_system_g,
            &real_system_g,
            &app_bootstrap,
            &swift_tests,
        ]
        .iter()
        .all(|source| source.exists),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_model_catalog_available",
        local_model_catalog_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "qwen3_floor_fallback_preserved",
        qwen3_floor_fallback_preserved,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "dense_36b_gate_preserved",
        dense_36b_gate_preserved,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mlx_runtime_client_available",
        mlx_runtime_client_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "gguf_runtime_client_available",
        gguf_runtime_client_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_policy_local_mlx_available",
        provider_policy_local_mlx_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "system_g_event_seam_available",
        system_g_event_seam_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_agent_adapter_dispatch_wired",
        local_agent_adapter_dispatch_wired,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rust_local_mlx_handoff_wired",
        rust_local_mlx_handoff_wired,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "swift_local_model_handoff_event_wired",
        swift_local_model_handoff_event_wired,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "swift_local_model_handoff_consumed",
        swift_local_model_handoff_consumed,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "app_bootstrap_local_client_registered",
        app_bootstrap_local_client_registered,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "focused_swift_handoff_test_present",
        focused_swift_handoff_test_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "system_g_local_model_provider_dispatch_wired",
        system_g_local_model_provider_dispatch_wired,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "live_local_model_answerpacket_provenance_wired",
        live_local_model_answerpacket_provenance_wired,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "live_agent_local_model_prompt_suite_passed",
        live_agent_local_model_prompt_suite_passed,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rust_v1_dispatch_still_synthetic_but_provider_route_not_synthetic",
        system_g_dispatch_is_synthetic && rust_local_mlx_handoff_wired,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_agent_adapter_not_scaffold",
        !local_agent_adapter_is_scaffold,
    );

    add_label(&mut measurements, "next_bottleneck", &next_bottleneck);
    add_source_summary(
        &mut measurements,
        "local_model_infrastructure",
        &local_model,
    );
    add_source_summary(&mut measurements, "mlx_inference_service", &mlx);
    add_source_summary(&mut measurements, "local_gguf_client", &gguf);
    add_source_summary(&mut measurements, "agent_blueprint", &blueprint);
    add_source_summary(&mut measurements, "system_g_runtime", &system_g);
    add_source_summary(&mut measurements, "local_agent_adapter", &local_agent);
    add_source_summary(&mut measurements, "swift_system_g_seam", &swift_system_g);
    add_source_summary(&mut measurements, "real_system_g_seam", &real_system_g);
    add_source_summary(&mut measurements, "app_bootstrap", &app_bootstrap);
    add_source_summary(&mut measurements, "system_g_run_seam_tests", &swift_tests);
    add_label(
        &mut measurements,
        "live_prompt_suite_result_path",
        LIVE_PROMPT_SUITE_RESULT,
    );
    measurements.insert(
        "live_prompt_suite_summary".to_string(),
        Measurement {
            value: live_prompt_suite.summary,
            unit: "object".to_string(),
        },
    );

    let overall = pass_per_axis.values().copied().all(|v| v);
    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: if overall {
            ArtifactKind::PrimaryWitness
        } else {
            ArtifactKind::FailureReport
        },
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: if overall {
            FallbackTier::Primary
        } else {
            FallbackTier::Fail
        },
        anomalies: build_anomalies(
            system_g_dispatch_is_synthetic,
            rust_local_mlx_handoff_wired,
            swift_local_model_handoff_consumed,
            live_agent_local_model_prompt_suite_passed,
            local_agent_adapter_is_scaffold,
            &next_bottleneck,
        ),
        notes: format!(
            "local_model_agent_bridge_witness; next_bottleneck={next_bottleneck}; \
             local catalog and runtime clients are present, Rust ProviderPolicy::LocalMlx now \
             emits a local_model_handoff, and Swift consumes that handoff through the registered \
             local client. Do not promote the architecture until the live prompt suite artifact \
             proves real local-model generation on this machine."
        ),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    BridgeReport {
        artifact,
        next_bottleneck,
    }
}

#[derive(Debug)]
struct SourceFile {
    path: &'static str,
    exists: bool,
    text: String,
}

impl SourceFile {
    fn read(path: &'static str) -> Self {
        let text = std::fs::read_to_string(path).unwrap_or_default();
        Self {
            path,
            exists: Path::new(path).exists(),
            text,
        }
    }

    fn contains(&self, needle: &str) -> bool {
        self.text.contains(needle)
    }
}

fn choose_next_bottleneck(
    local_model_catalog_available: bool,
    local_runtime_client_available: bool,
    provider_policy_local_mlx_available: bool,
    system_g_event_seam_available: bool,
    local_agent_adapter_dispatch_wired: bool,
    rust_local_mlx_handoff_wired: bool,
    swift_local_model_handoff_event_wired: bool,
    swift_local_model_handoff_consumed: bool,
    app_bootstrap_local_client_registered: bool,
    focused_swift_handoff_test_present: bool,
    system_g_local_model_provider_dispatch_wired: bool,
    live_local_model_answerpacket_provenance_wired: bool,
    live_agent_local_model_prompt_suite_passed: bool,
) -> String {
    if !local_model_catalog_available {
        "restore_local_model_catalog".to_string()
    } else if !local_runtime_client_available {
        "restore_mlx_or_gguf_runtime_client".to_string()
    } else if !provider_policy_local_mlx_available {
        "add_agent_provider_policy_local_mlx".to_string()
    } else if !system_g_event_seam_available {
        "restore_system_g_event_answerpacket_seam".to_string()
    } else if !local_agent_adapter_dispatch_wired {
        "wire_local_agent_adapter_dispatch".to_string()
    } else if !rust_local_mlx_handoff_wired {
        "wire_rust_local_mlx_provider_handoff".to_string()
    } else if !swift_local_model_handoff_event_wired {
        "mirror_local_model_handoff_in_swift_events".to_string()
    } else if !swift_local_model_handoff_consumed {
        "consume_system_g_local_model_handoff_in_swift".to_string()
    } else if !app_bootstrap_local_client_registered {
        "register_real_system_g_run_seam_with_local_client".to_string()
    } else if !focused_swift_handoff_test_present {
        "add_system_g_local_model_handoff_swift_test".to_string()
    } else if !system_g_local_model_provider_dispatch_wired {
        "wire_system_g_provider_policy_local_mlx_to_swift_generation".to_string()
    } else if !live_local_model_answerpacket_provenance_wired {
        "record_local_model_provenance_in_answerpacket".to_string()
    } else if !live_agent_local_model_prompt_suite_passed {
        "run_live_agent_local_model_prompt_suite".to_string()
    } else {
        "ready_for_capability_ceiling_recheck".to_string()
    }
}

fn build_anomalies(
    system_g_dispatch_is_synthetic: bool,
    rust_local_mlx_handoff_wired: bool,
    swift_local_model_handoff_consumed: bool,
    live_agent_local_model_prompt_suite_passed: bool,
    local_agent_adapter_is_scaffold: bool,
    next_bottleneck: &str,
) -> Vec<serde_json::Value> {
    let mut anomalies = Vec::new();
    if system_g_dispatch_is_synthetic {
        anomalies.push(serde_json::json!({
            "kind": "system_g_dispatch_synthetic",
            "detail": "System G currently echoes the mission prompt through a deterministic V1 seam. That is a valid witness seam, not live local-model generation."
        }));
    }
    if rust_local_mlx_handoff_wired {
        anomalies.push(serde_json::json!({
            "kind": "rust_local_mlx_handoff_wired",
            "detail": "Rust System G accepts ProviderPolicy::LocalMlx and terminates the Rust leg with local_model_handoff instead of falsely pretending Rust owns Swift/MLX generation."
        }));
    }
    if swift_local_model_handoff_consumed {
        anomalies.push(serde_json::json!({
            "kind": "swift_local_model_handoff_consumed",
            "detail": "Swift consumes local_model_handoff and streams through the registered local client, then emits local-model AnswerPacket provenance."
        }));
    }
    if !live_agent_local_model_prompt_suite_passed {
        anomalies.push(serde_json::json!({
            "kind": "live_prompt_suite_missing",
            "detail": format!("No passing live local-model prompt-suite artifact found at {LIVE_PROMPT_SUITE_RESULT}; keep this falsifier red until real local generation is measured.")
        }));
    }
    if local_agent_adapter_is_scaffold {
        anomalies.push(serde_json::json!({
            "kind": "local_agent_adapter_dispatch_missing",
            "detail": "The Rust LocalAgentAdapter mirrors capability metadata and tier gates, but its dispatch body is not wired yet."
        }));
    }
    anomalies.push(serde_json::json!({
        "kind": "next_bottleneck",
        "detail": next_bottleneck,
    }));
    anomalies
}

#[derive(Debug, Clone)]
struct LivePromptSuiteArtifact {
    passed: bool,
    summary: serde_json::Value,
}

impl LivePromptSuiteArtifact {
    fn read(path: &str) -> Self {
        let Ok(text) = std::fs::read_to_string(path) else {
            return Self {
                passed: false,
                summary: serde_json::json!({
                    "path": path,
                    "exists": false,
                }),
            };
        };
        let Ok(value) = serde_json::from_str::<serde_json::Value>(&text) else {
            return Self {
                passed: false,
                summary: serde_json::json!({
                    "path": path,
                    "exists": true,
                    "parse_error": true,
                }),
            };
        };
        let overall_pass = value
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false);
        let prompt_count = value
            .get("prompt_count")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0);
        let token_chunk_count = value
            .get("token_chunk_count")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0);
        let total_output_chars = value
            .get("total_output_chars")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0);
        let handoff_seen = value
            .get("system_g_local_model_handoff_seen")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false);
        let answerpacket_provenance_seen = value
            .get("answerpacket_local_model_provenance_seen")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false);
        let model_id_present = value
            .get("model_id")
            .and_then(serde_json::Value::as_str)
            .map(|model_id| !model_id.trim().is_empty())
            .unwrap_or(false);
        let passed = overall_pass
            && prompt_count >= 1
            && token_chunk_count >= 1
            && total_output_chars >= 1
            && handoff_seen
            && answerpacket_provenance_seen
            && model_id_present;
        Self {
            passed,
            summary: serde_json::json!({
                "path": path,
                "exists": true,
                "overall_pass": overall_pass,
                "prompt_count": prompt_count,
                "token_chunk_count": token_chunk_count,
                "total_output_chars": total_output_chars,
                "system_g_local_model_handoff_seen": handoff_seen,
                "answerpacket_local_model_provenance_seen": answerpacket_provenance_seen,
                "model_id_present": model_id_present,
            }),
        }
    }
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: bool,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Bool(value),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value);
}

fn add_label(measurements: &mut BTreeMap<String, Measurement>, key: &str, value: &str) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "label".to_string(),
        },
    );
}

fn add_source_summary(
    measurements: &mut BTreeMap<String, Measurement>,
    key: &str,
    source: &SourceFile,
) {
    measurements.insert(
        format!("{key}_source"),
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bottleneck_names_local_agent_handoff_sequence_before_live_prompt_suite() {
        assert_eq!(
            choose_next_bottleneck(
                true, true, true, true, false, false, false, false, false, false, false, false,
                false,
            ),
            "wire_local_agent_adapter_dispatch"
        );
        assert_eq!(
            choose_next_bottleneck(
                true, true, true, true, true, false, false, false, false, false, false, false,
                false,
            ),
            "wire_rust_local_mlx_provider_handoff"
        );
        assert_eq!(
            choose_next_bottleneck(
                true, true, true, true, true, true, false, false, false, false, false, false,
                false,
            ),
            "mirror_local_model_handoff_in_swift_events"
        );
        assert_eq!(
            choose_next_bottleneck(
                true, true, true, true, true, true, true, true, true, true, true, false, false,
            ),
            "record_local_model_provenance_in_answerpacket"
        );
        assert_eq!(
            choose_next_bottleneck(
                true, true, true, true, true, true, true, true, true, true, true, true, false,
            ),
            "run_live_agent_local_model_prompt_suite"
        );
    }

    #[test]
    fn current_source_audit_is_expected_to_be_red_until_live_provider_wiring() {
        let report = build_report();
        assert_eq!(report.artifact.falsifier_id, FALSIFIER_ID);
        assert_eq!(report.artifact.artifact_kind, "failure_report");
        assert_eq!(report.artifact.fallback_tier, "Fail");
        assert!(!report.artifact.overall_pass);
        assert!(report
            .artifact
            .pass_per_axis
            .contains_key("rust_local_mlx_handoff_wired"));
        assert!(report
            .artifact
            .pass_per_axis
            .contains_key("swift_local_model_handoff_consumed"));
        assert!(report
            .artifact
            .pass_per_axis
            .contains_key("live_local_model_answerpacket_provenance_wired"));
        assert!(report
            .artifact
            .pass_per_axis
            .contains_key("live_agent_local_model_prompt_suite_passed"));
    }
}
