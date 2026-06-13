//! Materialize a Gemma first-runtime route AnswerPacket visibility packet.
//!
//! This consumes the digest-only System G dry-run route packet and writes a
//! digest-only visibility packet for later settings/diagnostics/WRV work. It
//! does not emit a user-visible AnswerPacket, execute System G, run commands,
//! load model bytes, or mutate route/default state.

use std::path::PathBuf;

use agent_core::uas::{
    first_runtime_route_answer_packet_visibility_json_pretty,
    materialize_first_runtime_route_answer_packet_visibility,
    GemmaFirstRuntimeRouteAnswerPacketVisibilityRequest, GemmaFirstRuntimeSystemGDryRunRoutePacket,
};

const DEFAULT_OUTPUT: &str = "artifacts/falsifiers/gemma_direct_harness_first_runtime_route_answer_packet_visibility/visibility.redacted.json";

fn main() -> std::process::ExitCode {
    let request = match request_from_env() {
        Ok(request) => request,
        Err(error) => {
            eprintln!("{error}");
            print_usage();
            return std::process::ExitCode::from(2);
        }
    };

    let packet = match materialize_first_runtime_route_answer_packet_visibility(&request) {
        Ok(packet) => packet,
        Err(error) => {
            eprintln!("first-runtime route AnswerPacket visibility failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };

    let output_path = PathBuf::from(
        std::env::var("EPI_GEMMA_ROUTE_ANSWER_PACKET_VISIBILITY_OUTPUT")
            .unwrap_or_else(|_| DEFAULT_OUTPUT.to_string()),
    );
    if let Some(parent) = output_path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create route visibility packet directory: {error}");
            return std::process::ExitCode::from(1);
        }
    }

    let bytes = match first_runtime_route_answer_packet_visibility_json_pretty(&packet) {
        Ok(bytes) => bytes,
        Err(error) => {
            eprintln!("route visibility packet serialization failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };
    if let Err(error) = std::fs::write(&output_path, bytes) {
        eprintln!("failed to write route visibility packet: {error}");
        return std::process::ExitCode::from(1);
    }

    println!(
        "Gemma first-runtime route AnswerPacket visibility materialized: model={} settings_wrv_ready={} mutation_count={} next={} output={}",
        packet.selected_model_id,
        packet.settings_diagnostics_wrv_ready,
        packet.runtime_router_mutation_count
            + packet.system_g_mutation_count
            + packet.default_model_mutation_count,
        packet.next_cursor,
        output_path.display(),
    );
    std::process::ExitCode::SUCCESS
}

fn request_from_env() -> Result<GemmaFirstRuntimeRouteAnswerPacketVisibilityRequest, String> {
    let dry_run_path = PathBuf::from(required_env("EPI_GEMMA_SYSTEM_G_DRY_RUN_ROUTE_PACKET")?);
    let dry_run_bytes = std::fs::read(&dry_run_path).map_err(|error| {
        format!("failed to read EPI_GEMMA_SYSTEM_G_DRY_RUN_ROUTE_PACKET: {error}")
    })?;
    let system_g_dry_run_packet: GemmaFirstRuntimeSystemGDryRunRoutePacket =
        serde_json::from_slice(&dry_run_bytes)
            .map_err(|error| format!("failed to parse System G dry-run packet JSON: {error}"))?;
    Ok(GemmaFirstRuntimeRouteAnswerPacketVisibilityRequest {
        system_g_dry_run_packet,
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
    eprintln!("required env: EPI_GEMMA_SYSTEM_G_DRY_RUN_ROUTE_PACKET");
    eprintln!("optional env: EPI_GEMMA_ROUTE_ANSWER_PACKET_VISIBILITY_OUTPUT");
}
