//! Run the owner-approved Gemma first-runtime execution probe.
//!
//! Requires a prior digest-only local artifact receipt and the same owner
//! approval phrase plus local path. Writes only a redacted execution receipt.

use std::path::PathBuf;

use agent_core::uas::{
    execute_first_runtime_probe, first_runtime_execution_receipt_json_pretty,
    GemmaFirstRuntimeExecutionProbeRequest, GemmaOwnerApprovedLocalArtifactReceipt,
};

const DEFAULT_OUTPUT: &str =
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_execution_probe/receipt.redacted.json";
const DEFAULT_PROMPT: &str = "Return exactly OK.";

fn main() -> std::process::ExitCode {
    let request = match request_from_env() {
        Ok(request) => request,
        Err(error) => {
            eprintln!("{error}");
            print_usage();
            return std::process::ExitCode::from(2);
        }
    };

    let receipt = match execute_first_runtime_probe(&request) {
        Ok(receipt) => receipt,
        Err(error) => {
            eprintln!("first-runtime execution probe failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };

    let output_path = PathBuf::from(
        std::env::var("EPI_GEMMA_RUNTIME_PROBE_OUTPUT")
            .unwrap_or_else(|_| DEFAULT_OUTPUT.to_string()),
    );
    if let Some(parent) = output_path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create receipt directory: {error}");
            return std::process::ExitCode::from(1);
        }
    }

    let bytes = match first_runtime_execution_receipt_json_pretty(&receipt) {
        Ok(bytes) => bytes,
        Err(error) => {
            eprintln!("receipt serialization failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };
    if let Err(error) = std::fs::write(&output_path, bytes) {
        eprintln!("failed to write receipt: {error}");
        return std::process::ExitCode::from(1);
    }

    println!(
        "Gemma first-runtime execution receipt materialized: model={} exit={:?} first_token={} next={} output={}",
        receipt.selected_model_id,
        receipt.exit_code,
        receipt.first_token_digest,
        receipt.next_cursor,
        output_path.display(),
    );
    std::process::ExitCode::SUCCESS
}

fn request_from_env() -> Result<GemmaFirstRuntimeExecutionProbeRequest, String> {
    let receipt_path = PathBuf::from(required_env("EPI_GEMMA_LOCAL_ARTIFACT_RECEIPT")?);
    let receipt_bytes = std::fs::read(&receipt_path)
        .map_err(|error| format!("failed to read EPI_GEMMA_LOCAL_ARTIFACT_RECEIPT: {error}"))?;
    let upstream_receipt: GemmaOwnerApprovedLocalArtifactReceipt =
        serde_json::from_slice(&receipt_bytes)
            .map_err(|error| format!("failed to parse upstream receipt JSON: {error}"))?;
    Ok(GemmaFirstRuntimeExecutionProbeRequest {
        owner_approval_phrase: required_env("EPI_GEMMA_OWNER_APPROVAL_PHRASE")?,
        upstream_receipt,
        local_file_path: PathBuf::from(required_env("EPI_GEMMA_LOCAL_MODEL_PATH")?),
        llama_cli_path: PathBuf::from(
            std::env::var("EPI_GEMMA_LLAMA_CLI").unwrap_or_else(|_| "llama-cli".to_string()),
        ),
        prompt: std::env::var("EPI_GEMMA_RUNTIME_PROBE_PROMPT")
            .unwrap_or_else(|_| DEFAULT_PROMPT.to_string()),
        ctx_size: env_u32("EPI_GEMMA_RUNTIME_CTX_SIZE", 512)?,
        predict: env_u32("EPI_GEMMA_RUNTIME_PREDICT", 1)?,
        seed: env_u64("EPI_GEMMA_RUNTIME_SEED", 42)?,
        timeout_ms: env_u64("EPI_GEMMA_RUNTIME_TIMEOUT_MS", 30_000)?,
    })
}

fn required_env(name: &'static str) -> Result<String, String> {
    let value = std::env::var(name).map_err(|_| format!("{name} is required"))?;
    if value.trim().is_empty() {
        return Err(format!("{name} is empty"));
    }
    Ok(value)
}

fn env_u32(name: &'static str, default: u32) -> Result<u32, String> {
    match std::env::var(name) {
        Ok(value) => value
            .parse::<u32>()
            .map_err(|_| format!("{name} must be an unsigned integer")),
        Err(_) => Ok(default),
    }
}

fn env_u64(name: &'static str, default: u64) -> Result<u64, String> {
    match std::env::var(name) {
        Ok(value) => value
            .parse::<u64>()
            .map_err(|_| format!("{name} must be an unsigned integer")),
        Err(_) => Ok(default),
    }
}

fn print_usage() {
    eprintln!(
        "required env: EPI_GEMMA_OWNER_APPROVAL_PHRASE EPI_GEMMA_LOCAL_MODEL_PATH EPI_GEMMA_LOCAL_ARTIFACT_RECEIPT"
    );
    eprintln!(
        "optional env: EPI_GEMMA_LLAMA_CLI EPI_GEMMA_RUNTIME_PROBE_PROMPT EPI_GEMMA_RUNTIME_CTX_SIZE EPI_GEMMA_RUNTIME_PREDICT EPI_GEMMA_RUNTIME_SEED EPI_GEMMA_RUNTIME_TIMEOUT_MS EPI_GEMMA_RUNTIME_PROBE_OUTPUT"
    );
}
