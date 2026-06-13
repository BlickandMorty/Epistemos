//! Materialize a Gemma first-runtime settings/diagnostics WRV packet.
//!
//! This consumes the digest-only route AnswerPacket visibility packet and
//! writes a digest-only WRV packet that lets Settings/diagnostics describe the
//! blocked Gemma proof lane. It does not unlock a picker toggle, emit a
//! user-visible AnswerPacket, execute commands, load model bytes, or mutate
//! RuntimeRouter/System G/default route state.

use std::path::PathBuf;

use agent_core::uas::{
    first_runtime_settings_diagnostics_wrv_json_pretty,
    materialize_first_runtime_settings_diagnostics_wrv,
    GemmaFirstRuntimeRouteAnswerPacketVisibilityPacket,
    GemmaFirstRuntimeSettingsDiagnosticsWrvRequest,
};

const DEFAULT_OUTPUT: &str = "artifacts/falsifiers/gemma_direct_harness_first_runtime_settings_diagnostics_wrv/wrv.redacted.json";

fn main() -> std::process::ExitCode {
    let request = match request_from_env() {
        Ok(request) => request,
        Err(error) => {
            eprintln!("{error}");
            print_usage();
            return std::process::ExitCode::from(2);
        }
    };

    let packet = match materialize_first_runtime_settings_diagnostics_wrv(&request) {
        Ok(packet) => packet,
        Err(error) => {
            eprintln!("first-runtime settings/diagnostics WRV failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };

    let output_path = PathBuf::from(
        std::env::var("EPI_GEMMA_SETTINGS_DIAGNOSTICS_WRV_OUTPUT")
            .unwrap_or_else(|_| DEFAULT_OUTPUT.to_string()),
    );
    if let Some(parent) = output_path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create settings/diagnostics WRV directory: {error}");
            return std::process::ExitCode::from(1);
        }
    }

    let bytes = match first_runtime_settings_diagnostics_wrv_json_pretty(&packet) {
        Ok(bytes) => bytes,
        Err(error) => {
            eprintln!("settings/diagnostics WRV serialization failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };
    if let Err(error) = std::fs::write(&output_path, bytes) {
        eprintln!("failed to write settings/diagnostics WRV packet: {error}");
        return std::process::ExitCode::from(1);
    }

    println!(
        "Gemma first-runtime settings/diagnostics WRV materialized: model={} settings_wrv_passed={} release_audit_ready={} mutation_count={} next={} output={}",
        packet.selected_model_id,
        packet.settings_diagnostics_wrv_passed,
        packet.release_audit_automated_checks_ready,
        packet.runtime_router_mutation_count
            + packet.system_g_mutation_count
            + packet.default_model_mutation_count,
        packet.next_cursor,
        output_path.display(),
    );
    std::process::ExitCode::SUCCESS
}

fn request_from_env() -> Result<GemmaFirstRuntimeSettingsDiagnosticsWrvRequest, String> {
    let visibility_path = PathBuf::from(required_env(
        "EPI_GEMMA_ROUTE_ANSWER_PACKET_VISIBILITY_PACKET",
    )?);
    let visibility_bytes = std::fs::read(&visibility_path).map_err(|error| {
        format!("failed to read EPI_GEMMA_ROUTE_ANSWER_PACKET_VISIBILITY_PACKET: {error}")
    })?;
    let route_visibility_packet: GemmaFirstRuntimeRouteAnswerPacketVisibilityPacket =
        serde_json::from_slice(&visibility_bytes)
            .map_err(|error| format!("failed to parse route visibility packet JSON: {error}"))?;
    Ok(GemmaFirstRuntimeSettingsDiagnosticsWrvRequest {
        route_visibility_packet,
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
    eprintln!("required env: EPI_GEMMA_ROUTE_ANSWER_PACKET_VISIBILITY_PACKET");
    eprintln!("optional env: EPI_GEMMA_SETTINGS_DIAGNOSTICS_WRV_OUTPUT");
}
