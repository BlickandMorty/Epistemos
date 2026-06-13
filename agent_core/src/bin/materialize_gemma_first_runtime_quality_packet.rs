//! Materialize a Gemma first-runtime same-fixture quality packet.
//!
//! This consumes the redacted first-runtime execution receipt and writes a
//! replay-ready packet. It does not run fixtures, scorers, judges, routes, or
//! System G.

use std::path::PathBuf;

use agent_core::uas::{
    first_runtime_quality_packet_json_pretty, materialize_first_runtime_quality_packet,
    GemmaFirstRuntimeExecutionProbeReceipt, GemmaFirstRuntimeQualityPacketRequest,
};

const DEFAULT_OUTPUT: &str =
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_quality_packet/packet.redacted.json";

fn main() -> std::process::ExitCode {
    let request = match request_from_env() {
        Ok(request) => request,
        Err(error) => {
            eprintln!("{error}");
            print_usage();
            return std::process::ExitCode::from(2);
        }
    };

    let packet = match materialize_first_runtime_quality_packet(&request) {
        Ok(packet) => packet,
        Err(error) => {
            eprintln!("first-runtime quality packet materialization failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };

    let output_path = PathBuf::from(
        std::env::var("EPI_GEMMA_QUALITY_PACKET_OUTPUT")
            .unwrap_or_else(|_| DEFAULT_OUTPUT.to_string()),
    );
    if let Some(parent) = output_path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create quality packet directory: {error}");
            return std::process::ExitCode::from(1);
        }
    }

    let bytes = match first_runtime_quality_packet_json_pretty(&packet) {
        Ok(bytes) => bytes,
        Err(error) => {
            eprintln!("quality packet serialization failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };
    if let Err(error) = std::fs::write(&output_path, bytes) {
        eprintln!("failed to write quality packet: {error}");
        return std::process::ExitCode::from(1);
    }

    println!(
        "Gemma first-runtime quality packet materialized: model={} tasks={} next={} output={}",
        packet.selected_model_id,
        packet.task_packets.len(),
        packet.next_cursor,
        output_path.display(),
    );
    std::process::ExitCode::SUCCESS
}

fn request_from_env() -> Result<GemmaFirstRuntimeQualityPacketRequest, String> {
    let receipt_path = PathBuf::from(required_env("EPI_GEMMA_RUNTIME_PROBE_RECEIPT")?);
    let receipt_bytes = std::fs::read(&receipt_path)
        .map_err(|error| format!("failed to read EPI_GEMMA_RUNTIME_PROBE_RECEIPT: {error}"))?;
    let runtime_receipt: GemmaFirstRuntimeExecutionProbeReceipt =
        serde_json::from_slice(&receipt_bytes)
            .map_err(|error| format!("failed to parse runtime receipt JSON: {error}"))?;
    Ok(GemmaFirstRuntimeQualityPacketRequest { runtime_receipt })
}

fn required_env(name: &'static str) -> Result<String, String> {
    let value = std::env::var(name).map_err(|_| format!("{name} is required"))?;
    if value.trim().is_empty() {
        return Err(format!("{name} is empty"));
    }
    Ok(value)
}

fn print_usage() {
    eprintln!("required env: EPI_GEMMA_RUNTIME_PROBE_RECEIPT");
    eprintln!("optional env: EPI_GEMMA_QUALITY_PACKET_OUTPUT");
}
