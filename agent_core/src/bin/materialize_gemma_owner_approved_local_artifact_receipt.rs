//! Materialize one owner-approved local Gemma GGUF receipt.
//!
//! This command intentionally does not execute a model. It hashes one explicit
//! owner-approved local GGUF, redacts the path, binds `llama-cli` identity, and
//! writes a digest-only receipt that can feed the future first-runtime probe.

use std::path::PathBuf;

use agent_core::uas::{
    materialize_owner_approved_local_artifact_receipt, receipt_json_pretty,
    GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest,
};

const DEFAULT_OUTPUT: &str = "artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_materializer/receipt.redacted.json";

fn main() -> std::process::ExitCode {
    let request = match request_from_env() {
        Ok(request) => request,
        Err(error) => {
            eprintln!("{error}");
            print_usage();
            return std::process::ExitCode::from(2);
        }
    };

    let receipt = match materialize_owner_approved_local_artifact_receipt(&request) {
        Ok(receipt) => receipt,
        Err(error) => {
            eprintln!("receipt materialization failed: {error}");
            return std::process::ExitCode::from(1);
        }
    };

    let output_path = PathBuf::from(
        std::env::var("EPI_GEMMA_RECEIPT_OUTPUT").unwrap_or_else(|_| DEFAULT_OUTPUT.to_string()),
    );
    if let Some(parent) = output_path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create receipt directory: {error}");
            return std::process::ExitCode::from(1);
        }
    }

    let bytes = match receipt_json_pretty(&receipt) {
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
        "Gemma owner-approved local artifact receipt materialized: model={} bytes={} sha256={} path_digest={} next={} output={}",
        receipt.selected_model_id,
        receipt.observed_byte_count,
        receipt.local_file_sha256,
        receipt.redacted_path_digest,
        receipt.next_cursor,
        output_path.display(),
    );
    std::process::ExitCode::SUCCESS
}

fn request_from_env() -> Result<GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest, String>
{
    let approval = required_env("EPI_GEMMA_OWNER_APPROVAL_PHRASE")?;
    let local_file_path = PathBuf::from(required_env("EPI_GEMMA_LOCAL_MODEL_PATH")?);
    let selected_model_id = required_env("EPI_GEMMA_SELECTED_MODEL_ID")?;
    let expected_filename = required_env("EPI_GEMMA_EXPECTED_FILENAME")?;
    let expected_byte_count = required_env("EPI_GEMMA_EXPECTED_BYTE_COUNT")?
        .parse::<u64>()
        .map_err(|_| "EPI_GEMMA_EXPECTED_BYTE_COUNT must be an unsigned integer".to_string())?;
    let expected_file_sha256 = required_env("EPI_GEMMA_EXPECTED_LFS_SHA256")?;
    Ok(
        GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest {
            owner_approval_phrase: approval,
            local_file_path,
            selected_model_id: selected_model_id.clone(),
            source_repo: std::env::var("EPI_GEMMA_SOURCE_REPO").unwrap_or(selected_model_id),
            source_revision: required_env("EPI_GEMMA_SOURCE_REVISION")?,
            expected_filename,
            expected_byte_count,
            expected_file_sha256,
            source_license_ref: required_env("EPI_GEMMA_SOURCE_LICENSE_REF")?,
            provenance_mode: std::env::var("EPI_GEMMA_PROVENANCE_MODE")
                .unwrap_or_else(|_| "owner_approved_direct_local_file".to_string()),
            hardware_profile_ref: std::env::var("EPI_GEMMA_HARDWARE_PROFILE_REF")
                .unwrap_or_else(|_| "hardware:local-owner-approved".to_string()),
            llama_cli_path: PathBuf::from(
                std::env::var("EPI_GEMMA_LLAMA_CLI").unwrap_or_else(|_| "llama-cli".to_string()),
            ),
        },
    )
}

fn required_env(name: &'static str) -> Result<String, String> {
    let value = std::env::var(name).map_err(|_| format!("{name} is required"))?;
    if value.trim().is_empty() {
        return Err(format!("{name} is empty"));
    }
    Ok(value)
}

fn print_usage() {
    eprintln!(
        "required env: EPI_GEMMA_OWNER_APPROVAL_PHRASE EPI_GEMMA_LOCAL_MODEL_PATH EPI_GEMMA_SELECTED_MODEL_ID EPI_GEMMA_EXPECTED_FILENAME EPI_GEMMA_EXPECTED_BYTE_COUNT EPI_GEMMA_EXPECTED_LFS_SHA256 EPI_GEMMA_SOURCE_REVISION EPI_GEMMA_SOURCE_LICENSE_REF"
    );
    eprintln!(
        "optional env: EPI_GEMMA_SOURCE_REPO EPI_GEMMA_PROVENANCE_MODE EPI_GEMMA_HARDWARE_PROFILE_REF EPI_GEMMA_LLAMA_CLI EPI_GEMMA_RECEIPT_OUTPUT"
    );
}
