//! Materialize a Gemma first-runtime System G dry-run route packet.
//!
//! This consumes the digest-only RuntimeRouter admission packet and writes a
//! digest-only System G dry-run packet. It does not perform admission, execute
//! System G, run commands, load model bytes, or mutate route/default state.

use std::path::PathBuf;

use agent_core::uas::{
    first_runtime_system_g_dry_run_route_packet_json_pretty,
    materialize_first_runtime_system_g_dry_run_route_packet,
    GemmaFirstRuntimeRuntimeRouterAdmissionPacket,
    GemmaFirstRuntimeSystemGDryRunRoutePacketRequest,
};

const DEFAULT_OUTPUT: &str = "artifacts/falsifiers/gemma_direct_harness_first_runtime_system_g_dry_run_route/system_g_dry_run.redacted.json";

fn main() -> std::process::ExitCode {
    let request = match request_from_env() {
        Ok(request) => request,
        Err(error) => {
            eprintln!("{error}");
            print_usage();
            return std::process::ExitCode::from(2);
        }
    };

    let packet = match materialize_first_runtime_system_g_dry_run_route_packet(&request) {
        Ok(packet) => packet,
        Err(error) => {
            eprintln!("first-runtime System G dry-run route packet failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };

    let output_path = PathBuf::from(
        std::env::var("EPI_GEMMA_SYSTEM_G_DRY_RUN_ROUTE_OUTPUT")
            .unwrap_or_else(|_| DEFAULT_OUTPUT.to_string()),
    );
    if let Some(parent) = output_path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create System G dry-run packet directory: {error}");
            return std::process::ExitCode::from(1);
        }
    }

    let bytes = match first_runtime_system_g_dry_run_route_packet_json_pretty(&packet) {
        Ok(bytes) => bytes,
        Err(error) => {
            eprintln!("System G dry-run packet serialization failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };
    if let Err(error) = std::fs::write(&output_path, bytes) {
        eprintln!("failed to write System G dry-run packet: {error}");
        return std::process::ExitCode::from(1);
    }

    println!(
        "Gemma first-runtime System G dry-run route packet materialized: model={} route_visibility_ready={} mutation_count={} next={} output={}",
        packet.selected_model_id,
        packet.route_answer_packet_visibility_ready,
        packet.runtime_router_mutation_count
            + packet.system_g_mutation_count
            + packet.default_model_mutation_count,
        packet.next_cursor,
        output_path.display(),
    );
    std::process::ExitCode::SUCCESS
}

fn request_from_env() -> Result<GemmaFirstRuntimeSystemGDryRunRoutePacketRequest, String> {
    let admission_path = PathBuf::from(required_env("EPI_GEMMA_RUNTIME_ROUTER_ADMISSION_PACKET")?);
    let admission_bytes = std::fs::read(&admission_path).map_err(|error| {
        format!("failed to read EPI_GEMMA_RUNTIME_ROUTER_ADMISSION_PACKET: {error}")
    })?;
    let admission_packet: GemmaFirstRuntimeRuntimeRouterAdmissionPacket =
        serde_json::from_slice(&admission_bytes)
            .map_err(|error| format!("failed to parse admission packet JSON: {error}"))?;
    Ok(GemmaFirstRuntimeSystemGDryRunRoutePacketRequest { admission_packet })
}

fn required_env(name: &'static str) -> Result<String, String> {
    let value = std::env::var(name).map_err(|_| format!("{name} is required"))?;
    if value.trim().is_empty() {
        return Err(format!("{name} is empty"));
    }
    Ok(value)
}

fn print_usage() {
    eprintln!("required env: EPI_GEMMA_RUNTIME_ROUTER_ADMISSION_PACKET");
    eprintln!("optional env: EPI_GEMMA_SYSTEM_G_DRY_RUN_ROUTE_OUTPUT");
}
