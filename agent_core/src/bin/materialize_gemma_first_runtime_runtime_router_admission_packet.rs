//! Materialize a Gemma first-runtime RuntimeRouter admission packet.
//!
//! This consumes the digest-only same-fixture replay artifact and writes a
//! digest-only admission packet. It does not mutate RuntimeRouter/System G,
//! change defaults, run commands, or load model/runtime bytes.

use std::path::PathBuf;

use agent_core::uas::{
    first_runtime_runtime_router_admission_packet_json_pretty,
    materialize_first_runtime_runtime_router_admission_packet,
    GemmaFirstRuntimeQualityReplayArtifact, GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest,
};

const DEFAULT_OUTPUT: &str = "artifacts/falsifiers/gemma_direct_harness_first_runtime_runtime_router_admission/admission.redacted.json";

fn main() -> std::process::ExitCode {
    let request = match request_from_env() {
        Ok(request) => request,
        Err(error) => {
            eprintln!("{error}");
            print_usage();
            return std::process::ExitCode::from(2);
        }
    };

    let packet = match materialize_first_runtime_runtime_router_admission_packet(&request) {
        Ok(packet) => packet,
        Err(error) => {
            eprintln!("first-runtime RuntimeRouter admission packet failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };

    let output_path = PathBuf::from(
        std::env::var("EPI_GEMMA_RUNTIME_ROUTER_ADMISSION_OUTPUT")
            .unwrap_or_else(|_| DEFAULT_OUTPUT.to_string()),
    );
    if let Some(parent) = output_path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create admission packet directory: {error}");
            return std::process::ExitCode::from(1);
        }
    }

    let bytes = match first_runtime_runtime_router_admission_packet_json_pretty(&packet) {
        Ok(bytes) => bytes,
        Err(error) => {
            eprintln!("admission packet serialization failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };
    if let Err(error) = std::fs::write(&output_path, bytes) {
        eprintln!("failed to write admission packet: {error}");
        return std::process::ExitCode::from(1);
    }

    println!(
        "Gemma first-runtime RuntimeRouter admission packet materialized: model={} replay_passed={} system_g_ready={} next={} output={}",
        packet.selected_model_id,
        packet.quality_replay_passed,
        packet.system_g_dry_run_packet_ready,
        packet.next_cursor,
        output_path.display(),
    );
    std::process::ExitCode::SUCCESS
}

fn request_from_env() -> Result<GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest, String> {
    let replay_path = PathBuf::from(required_env("EPI_GEMMA_QUALITY_REPLAY_ARTIFACT")?);
    let replay_bytes = std::fs::read(&replay_path)
        .map_err(|error| format!("failed to read EPI_GEMMA_QUALITY_REPLAY_ARTIFACT: {error}"))?;
    let quality_replay_artifact: GemmaFirstRuntimeQualityReplayArtifact =
        serde_json::from_slice(&replay_bytes)
            .map_err(|error| format!("failed to parse replay artifact JSON: {error}"))?;
    Ok(GemmaFirstRuntimeRuntimeRouterAdmissionPacketRequest {
        quality_replay_artifact,
    })
}

fn required_env(name: &'static str) -> Result<String, String> {
    let value = std::env::var(name).map_err(|_| format!("{name} is required"))?;
    if value.trim().is_empty() {
        return Err(format!("{name} is empty"));
    }
    Ok(value)
}

fn print_usage() {
    eprintln!("required env: EPI_GEMMA_QUALITY_REPLAY_ARTIFACT");
    eprintln!("optional env: EPI_GEMMA_RUNTIME_ROUTER_ADMISSION_OUTPUT");
}
