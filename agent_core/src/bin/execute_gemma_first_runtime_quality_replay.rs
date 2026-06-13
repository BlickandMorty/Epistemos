//! Execute the Gemma first-runtime same-fixture quality replay gate.
//!
//! Inputs may contain raw candidate outputs for in-memory scoring. The emitted
//! artifact is digest-only and keeps route/default/System G mutation at zero.

use std::path::PathBuf;

use agent_core::uas::{
    execute_first_runtime_quality_replay, first_runtime_quality_replay_artifact_json_pretty,
    GemmaFirstRuntimeQualityPacket, GemmaFirstRuntimeQualityReplayObservationEnvelope,
    GemmaFirstRuntimeQualityReplayRequest, GemmaFirstRuntimeQualityTaskObservation,
};

const DEFAULT_OUTPUT: &str =
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_quality_replay/result.redacted.json";

fn main() -> std::process::ExitCode {
    let request = match request_from_env() {
        Ok(request) => request,
        Err(error) => {
            eprintln!("{error}");
            print_usage();
            return std::process::ExitCode::from(2);
        }
    };

    let artifact = match execute_first_runtime_quality_replay(&request) {
        Ok(artifact) => artifact,
        Err(error) => {
            eprintln!("first-runtime quality replay execution failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };

    let output_path = PathBuf::from(
        std::env::var("EPI_GEMMA_QUALITY_REPLAY_OUTPUT")
            .unwrap_or_else(|_| DEFAULT_OUTPUT.to_string()),
    );
    if let Some(parent) = output_path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create quality replay directory: {error}");
            return std::process::ExitCode::from(1);
        }
    }

    let bytes = match first_runtime_quality_replay_artifact_json_pretty(&artifact) {
        Ok(bytes) => bytes,
        Err(error) => {
            eprintln!("quality replay artifact serialization failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };
    if let Err(error) = std::fs::write(&output_path, bytes) {
        eprintln!("failed to write quality replay artifact: {error}");
        return std::process::ExitCode::from(1);
    }

    println!(
        "Gemma first-runtime quality replay executed: model={} passed={}/{} next={} output={}",
        artifact.selected_model_id,
        artifact.passed_task_count,
        artifact.task_results.len(),
        artifact.next_cursor,
        output_path.display(),
    );
    std::process::ExitCode::SUCCESS
}

fn request_from_env() -> Result<GemmaFirstRuntimeQualityReplayRequest, String> {
    let packet_path = PathBuf::from(required_env("EPI_GEMMA_QUALITY_PACKET")?);
    let observations_path = PathBuf::from(required_env("EPI_GEMMA_QUALITY_REPLAY_OBSERVATIONS")?);

    let packet_bytes = std::fs::read(&packet_path)
        .map_err(|error| format!("failed to read EPI_GEMMA_QUALITY_PACKET: {error}"))?;
    let quality_packet: GemmaFirstRuntimeQualityPacket = serde_json::from_slice(&packet_bytes)
        .map_err(|error| format!("failed to parse quality packet JSON: {error}"))?;

    let observation_bytes = std::fs::read(&observations_path).map_err(|error| {
        format!("failed to read EPI_GEMMA_QUALITY_REPLAY_OBSERVATIONS: {error}")
    })?;
    let observations = parse_observations(&observation_bytes)?;

    Ok(GemmaFirstRuntimeQualityReplayRequest {
        quality_packet,
        observations,
    })
}

fn parse_observations(
    bytes: &[u8],
) -> Result<Vec<GemmaFirstRuntimeQualityTaskObservation>, String> {
    if let Ok(envelope) =
        serde_json::from_slice::<GemmaFirstRuntimeQualityReplayObservationEnvelope>(bytes)
    {
        return Ok(envelope.observations);
    }
    serde_json::from_slice::<Vec<GemmaFirstRuntimeQualityTaskObservation>>(bytes)
        .map_err(|error| format!("failed to parse quality replay observations JSON: {error}"))
}

fn required_env(name: &'static str) -> Result<String, String> {
    let value = std::env::var(name).map_err(|_| format!("{name} is required"))?;
    if value.trim().is_empty() {
        return Err(format!("{name} is empty"));
    }
    Ok(value)
}

fn print_usage() {
    eprintln!("required env: EPI_GEMMA_QUALITY_PACKET");
    eprintln!("required env: EPI_GEMMA_QUALITY_REPLAY_OBSERVATIONS");
    eprintln!("optional env: EPI_GEMMA_QUALITY_REPLAY_OUTPUT");
}
