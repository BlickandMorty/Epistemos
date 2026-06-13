//! Owner-approved Gemma first-runtime execution probe.
//!
//! This is the first gated execution layer after the local artifact receipt.
//! It consumes a digest-only owner-approved GGUF receipt, rechecks the explicit
//! owner path against that receipt, runs a bounded offline `llama-cli` command,
//! and emits a digest-only receipt. It does not mutate RuntimeRouter, System G,
//! settings defaults, provider state, or model picker state.

use serde::{Deserialize, Serialize};
use std::fmt;
use std::io::{self, Read};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::thread;
use std::time::{Duration, Instant};

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    llama_cli_identity_for_path, redacted_path_digest_for_path, sha256_file, validate_receipt,
    GemmaOwnerApprovedLocalArtifactReceipt,
    GemmaOwnerApprovedLocalArtifactReceiptMaterializerError,
    GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_MATERIALIZER_NEXT_CURSOR,
};

pub const GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_CURSOR: &str =
    "gemma_direct_harness_owner_approved_first_runtime_execution_probe";
pub const GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_same_fixture_quality_packet_gate";
pub const GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_SCHEMA_VERSION: &str =
    "gemma-first-runtime-execution-probe-receipt-v1";
pub const GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_COMMAND_CARD_ID: &str =
    "F-GemmaDirectHarnessFirstRuntimeProofCommandCard";

const MAX_PROMPT_BYTES: usize = 512;
const MAX_STDIO_BYTES: usize = 64 * 1024;
const MAX_CTX_SIZE: u32 = 4_096;
const MAX_PREDICT: u32 = 16;
const MIN_TIMEOUT_MS: u64 = 100;
const MAX_TIMEOUT_MS: u64 = 120_000;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GemmaFirstRuntimeExecutionProbeRequest {
    pub owner_approval_phrase: String,
    pub upstream_receipt: GemmaOwnerApprovedLocalArtifactReceipt,
    pub local_file_path: PathBuf,
    pub llama_cli_path: PathBuf,
    pub prompt: String,
    pub ctx_size: u32,
    pub predict: u32,
    pub seed: u64,
    pub timeout_ms: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaFirstRuntimeExecutionProbeReceipt {
    pub schema_version: String,
    pub upstream_receipt_digest: String,
    pub owner_approval_phrase_digest: String,
    pub selected_model_id: String,
    pub expected_byte_count: u64,
    pub observed_byte_count: u64,
    pub local_file_sha256: String,
    pub redacted_path_digest: String,
    pub llama_cli_version_digest: String,
    pub llama_cli_help_digest: String,
    pub prompt_digest: String,
    pub command_argv_digest: String,
    pub command_card_id: String,
    pub offline_flag_present: bool,
    pub single_turn_flag_present: bool,
    pub no_display_prompt_flag_present: bool,
    pub show_timings_flag_present: bool,
    pub ctx_size: u32,
    pub predict: u32,
    pub seed: u64,
    pub timeout_ms: u64,
    pub duration_ms: u64,
    pub termination_class: String,
    pub exit_code: Option<i32>,
    pub process_status_success: bool,
    pub timed_out: bool,
    pub stdout_digest: String,
    pub stderr_digest: String,
    pub stdout_byte_count_capped: u64,
    pub stderr_byte_count_capped: u64,
    pub stdout_truncated: bool,
    pub stderr_truncated: bool,
    pub first_token_digest: String,
    pub first_token_present: bool,
    pub raw_path_absent: bool,
    pub raw_prompt_absent: bool,
    pub raw_stdout_absent: bool,
    pub raw_stderr_absent: bool,
    pub raw_token_absent: bool,
    pub runtime_command_executed_count: u64,
    pub runtime_router_mutation_count: u64,
    pub system_g_mutation_count: u64,
    pub settings_default_mutation_count: u64,
    pub server_started_count: u64,
    pub network_probe_count: u64,
    pub provider_endpoint_count: u64,
    pub quality_claim: bool,
    pub live_gemma_claim: bool,
    pub l2_l3_t4_claim: bool,
    pub live_dense_70b_claim: bool,
    pub reviewer_visible_summary: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub non_promotion_ref: String,
    pub next_cursor: String,
    pub receipt_digest: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GemmaFirstRuntimeExecutionObservation {
    pub exit_code: Option<i32>,
    pub process_status_success: bool,
    pub timed_out: bool,
    pub duration_ms: u64,
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
    pub stdout_truncated: bool,
    pub stderr_truncated: bool,
}

#[derive(Debug)]
pub enum GemmaFirstRuntimeExecutionProbeError {
    MissingField(&'static str),
    InvalidParameter(&'static str),
    UpstreamReceipt(GemmaOwnerApprovedLocalArtifactReceiptMaterializerError),
    OwnerApprovalDigestMismatch,
    LocalArtifactMismatch(&'static str),
    LlamaCliIdentityMismatch(&'static str),
    Io(io::Error),
    Spawn(io::Error),
    Join(&'static str),
    ProcessTimedOut,
    ProcessFailed,
    OutputTruncated(&'static str),
    ReceiptInvalid(&'static str),
    Serialize(serde_json::Error),
}

impl fmt::Display for GemmaFirstRuntimeExecutionProbeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "{field} is missing"),
            Self::InvalidParameter(field) => write!(f, "{field} is invalid"),
            Self::UpstreamReceipt(error) => write!(f, "upstream receipt invalid: {error}"),
            Self::OwnerApprovalDigestMismatch => {
                write!(
                    f,
                    "owner approval phrase digest does not match upstream receipt"
                )
            }
            Self::LocalArtifactMismatch(field) => {
                write!(f, "local artifact does not match upstream receipt: {field}")
            }
            Self::LlamaCliIdentityMismatch(field) => {
                write!(
                    f,
                    "llama-cli identity does not match upstream receipt: {field}"
                )
            }
            Self::Io(error) => write!(f, "io error: {error}"),
            Self::Spawn(error) => write!(f, "failed to spawn llama-cli: {error}"),
            Self::Join(stream) => write!(f, "failed to join {stream} reader"),
            Self::ProcessTimedOut => write!(f, "llama-cli timed out"),
            Self::ProcessFailed => write!(f, "llama-cli exited unsuccessfully"),
            Self::OutputTruncated(stream) => write!(f, "{stream} exceeded capped byte budget"),
            Self::ReceiptInvalid(reason) => write!(f, "execution receipt invalid: {reason}"),
            Self::Serialize(error) => write!(f, "receipt serialization error: {error}"),
        }
    }
}

impl std::error::Error for GemmaFirstRuntimeExecutionProbeError {}

impl From<io::Error> for GemmaFirstRuntimeExecutionProbeError {
    fn from(value: io::Error) -> Self {
        Self::Io(value)
    }
}

impl From<serde_json::Error> for GemmaFirstRuntimeExecutionProbeError {
    fn from(value: serde_json::Error) -> Self {
        Self::Serialize(value)
    }
}

impl From<GemmaOwnerApprovedLocalArtifactReceiptMaterializerError>
    for GemmaFirstRuntimeExecutionProbeError
{
    fn from(value: GemmaOwnerApprovedLocalArtifactReceiptMaterializerError) -> Self {
        Self::UpstreamReceipt(value)
    }
}

impl GemmaFirstRuntimeExecutionProbeRequest {
    pub fn validate(&self) -> Result<(), GemmaFirstRuntimeExecutionProbeError> {
        validate_receipt(&self.upstream_receipt)?;
        validate_nonempty("owner_approval_phrase", &self.owner_approval_phrase)?;
        validate_nonempty("prompt", &self.prompt)?;
        if self.prompt.as_bytes().len() > MAX_PROMPT_BYTES {
            return Err(GemmaFirstRuntimeExecutionProbeError::InvalidParameter(
                "prompt",
            ));
        }
        if self.upstream_receipt.next_cursor
            != GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_MATERIALIZER_NEXT_CURSOR
        {
            return Err(GemmaFirstRuntimeExecutionProbeError::InvalidParameter(
                "upstream_receipt.next_cursor",
            ));
        }
        if self.ctx_size == 0 || self.ctx_size > MAX_CTX_SIZE {
            return Err(GemmaFirstRuntimeExecutionProbeError::InvalidParameter(
                "ctx_size",
            ));
        }
        if self.predict == 0 || self.predict > MAX_PREDICT {
            return Err(GemmaFirstRuntimeExecutionProbeError::InvalidParameter(
                "predict",
            ));
        }
        if self.timeout_ms < MIN_TIMEOUT_MS || self.timeout_ms > MAX_TIMEOUT_MS {
            return Err(GemmaFirstRuntimeExecutionProbeError::InvalidParameter(
                "timeout_ms",
            ));
        }
        Ok(())
    }
}

pub fn execute_first_runtime_probe(
    request: &GemmaFirstRuntimeExecutionProbeRequest,
) -> Result<GemmaFirstRuntimeExecutionProbeReceipt, GemmaFirstRuntimeExecutionProbeError> {
    request.validate()?;
    verify_owner_and_material(request)?;
    let observation = run_llama_cli_probe(request)?;
    if observation.timed_out {
        return Err(GemmaFirstRuntimeExecutionProbeError::ProcessTimedOut);
    }
    if !observation.process_status_success {
        return Err(GemmaFirstRuntimeExecutionProbeError::ProcessFailed);
    }
    if observation.stdout_truncated {
        return Err(GemmaFirstRuntimeExecutionProbeError::OutputTruncated(
            "stdout",
        ));
    }
    if observation.stderr_truncated {
        return Err(GemmaFirstRuntimeExecutionProbeError::OutputTruncated(
            "stderr",
        ));
    }
    build_first_runtime_execution_receipt(request, observation)
}

pub fn build_first_runtime_execution_receipt(
    request: &GemmaFirstRuntimeExecutionProbeRequest,
    observation: GemmaFirstRuntimeExecutionObservation,
) -> Result<GemmaFirstRuntimeExecutionProbeReceipt, GemmaFirstRuntimeExecutionProbeError> {
    request.validate()?;
    let first_token_digest = first_token_digest(&observation.stdout);
    let mut receipt = GemmaFirstRuntimeExecutionProbeReceipt {
        schema_version: GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_SCHEMA_VERSION.to_string(),
        upstream_receipt_digest: request.upstream_receipt.receipt_digest.clone(),
        owner_approval_phrase_digest: sha256_hex(request.owner_approval_phrase.as_bytes()),
        selected_model_id: request.upstream_receipt.selected_model_id.clone(),
        expected_byte_count: request.upstream_receipt.expected_byte_count,
        observed_byte_count: request.upstream_receipt.observed_byte_count,
        local_file_sha256: request.upstream_receipt.local_file_sha256.clone(),
        redacted_path_digest: request.upstream_receipt.redacted_path_digest.clone(),
        llama_cli_version_digest: request.upstream_receipt.llama_cli_version_digest.clone(),
        llama_cli_help_digest: request.upstream_receipt.llama_cli_help_digest.clone(),
        prompt_digest: sha256_hex(request.prompt.as_bytes()),
        command_argv_digest: command_argv_digest(request),
        command_card_id: GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_COMMAND_CARD_ID.to_string(),
        offline_flag_present: true,
        single_turn_flag_present: true,
        no_display_prompt_flag_present: true,
        show_timings_flag_present: true,
        ctx_size: request.ctx_size,
        predict: request.predict,
        seed: request.seed,
        timeout_ms: request.timeout_ms,
        duration_ms: observation.duration_ms,
        termination_class: if observation.timed_out {
            "timed_out".to_string()
        } else if observation.process_status_success {
            "exited_success".to_string()
        } else {
            "exited_failure".to_string()
        },
        exit_code: observation.exit_code,
        process_status_success: observation.process_status_success,
        timed_out: observation.timed_out,
        stdout_digest: sha256_hex(&observation.stdout),
        stderr_digest: sha256_hex(&observation.stderr),
        stdout_byte_count_capped: observation.stdout.len() as u64,
        stderr_byte_count_capped: observation.stderr.len() as u64,
        stdout_truncated: observation.stdout_truncated,
        stderr_truncated: observation.stderr_truncated,
        first_token_present: first_token_digest.is_some(),
        first_token_digest: first_token_digest.unwrap_or_default(),
        raw_path_absent: true,
        raw_prompt_absent: true,
        raw_stdout_absent: true,
        raw_stderr_absent: true,
        raw_token_absent: true,
        runtime_command_executed_count: 1,
        runtime_router_mutation_count: 0,
        system_g_mutation_count: 0,
        settings_default_mutation_count: 0,
        server_started_count: 0,
        network_probe_count: 0,
        provider_endpoint_count: 0,
        quality_claim: false,
        live_gemma_claim: false,
        l2_l3_t4_claim: false,
        live_dense_70b_claim: false,
        reviewer_visible_summary:
            "Owner-approved Gemma first-runtime probe ran one bounded offline direct-file llama-cli command; receipt stores only digests/counts and makes no quality, route, default, or live-product claim."
                .to_string(),
        rollback_ref: "rollback:gemma-first-runtime-execution-probe-v1".to_string(),
        run_event_log_ref: "run_event_log:gemma-first-runtime-execution-probe-v1".to_string(),
        answer_packet_ref: "answer_packet:gemma-first-runtime-execution-probe-v1".to_string(),
        abstention_ref: "abstention:gemma-first-runtime-execution-probe-v1".to_string(),
        non_promotion_ref: "non_promotion:gemma-first-runtime-execution-probe-v1".to_string(),
        next_cursor: GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_NEXT_CURSOR.to_string(),
        receipt_digest: String::new(),
    };
    receipt.receipt_digest = first_runtime_receipt_digest(&receipt)?;
    validate_first_runtime_execution_receipt(&receipt)?;
    Ok(receipt)
}

pub fn validate_first_runtime_execution_receipt(
    receipt: &GemmaFirstRuntimeExecutionProbeReceipt,
) -> Result<(), GemmaFirstRuntimeExecutionProbeError> {
    if receipt.schema_version != GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_SCHEMA_VERSION {
        return Err(GemmaFirstRuntimeExecutionProbeError::ReceiptInvalid(
            "bad schema_version",
        ));
    }
    for (field, value) in [
        ("upstream_receipt_digest", &receipt.upstream_receipt_digest),
        (
            "owner_approval_phrase_digest",
            &receipt.owner_approval_phrase_digest,
        ),
        ("local_file_sha256", &receipt.local_file_sha256),
        ("redacted_path_digest", &receipt.redacted_path_digest),
        (
            "llama_cli_version_digest",
            &receipt.llama_cli_version_digest,
        ),
        ("llama_cli_help_digest", &receipt.llama_cli_help_digest),
        ("prompt_digest", &receipt.prompt_digest),
        ("command_argv_digest", &receipt.command_argv_digest),
        ("stdout_digest", &receipt.stdout_digest),
        ("stderr_digest", &receipt.stderr_digest),
        ("first_token_digest", &receipt.first_token_digest),
        ("receipt_digest", &receipt.receipt_digest),
    ] {
        if !value.starts_with("sha256:") {
            return Err(GemmaFirstRuntimeExecutionProbeError::ReceiptInvalid(field));
        }
    }
    if receipt.command_card_id != GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_COMMAND_CARD_ID
        || !receipt.offline_flag_present
        || !receipt.single_turn_flag_present
        || !receipt.no_display_prompt_flag_present
        || !receipt.show_timings_flag_present
        || receipt.ctx_size == 0
        || receipt.ctx_size > MAX_CTX_SIZE
        || receipt.predict == 0
        || receipt.predict > MAX_PREDICT
        || receipt.timeout_ms < MIN_TIMEOUT_MS
        || receipt.timeout_ms > MAX_TIMEOUT_MS
        || receipt.termination_class != "exited_success"
        || !receipt.process_status_success
        || receipt.timed_out
        || receipt.stdout_truncated
        || receipt.stderr_truncated
        || !receipt.first_token_present
        || !receipt.raw_path_absent
        || !receipt.raw_prompt_absent
        || !receipt.raw_stdout_absent
        || !receipt.raw_stderr_absent
        || !receipt.raw_token_absent
        || receipt.runtime_command_executed_count != 1
        || receipt.runtime_router_mutation_count != 0
        || receipt.system_g_mutation_count != 0
        || receipt.settings_default_mutation_count != 0
        || receipt.server_started_count != 0
        || receipt.network_probe_count != 0
        || receipt.provider_endpoint_count != 0
        || receipt.quality_claim
        || receipt.live_gemma_claim
        || receipt.l2_l3_t4_claim
        || receipt.live_dense_70b_claim
        || receipt.next_cursor != GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_NEXT_CURSOR
    {
        return Err(GemmaFirstRuntimeExecutionProbeError::ReceiptInvalid(
            "policy violation",
        ));
    }
    if receipt.receipt_digest != first_runtime_receipt_digest(receipt)? {
        return Err(GemmaFirstRuntimeExecutionProbeError::ReceiptInvalid(
            "receipt_digest mismatch",
        ));
    }
    Ok(())
}

pub fn first_runtime_execution_receipt_json_pretty(
    receipt: &GemmaFirstRuntimeExecutionProbeReceipt,
) -> Result<Vec<u8>, GemmaFirstRuntimeExecutionProbeError> {
    validate_first_runtime_execution_receipt(receipt)?;
    let mut bytes = serde_json::to_vec_pretty(receipt)?;
    bytes.push(b'\n');
    Ok(bytes)
}

fn verify_owner_and_material(
    request: &GemmaFirstRuntimeExecutionProbeRequest,
) -> Result<(), GemmaFirstRuntimeExecutionProbeError> {
    if sha256_hex(request.owner_approval_phrase.as_bytes())
        != request.upstream_receipt.owner_approval_phrase_digest
    {
        return Err(GemmaFirstRuntimeExecutionProbeError::OwnerApprovalDigestMismatch);
    }
    if std::fs::metadata(&request.local_file_path)?.len()
        != request.upstream_receipt.observed_byte_count
    {
        return Err(GemmaFirstRuntimeExecutionProbeError::LocalArtifactMismatch(
            "observed_byte_count",
        ));
    }
    if sha256_file(&request.local_file_path)? != request.upstream_receipt.local_file_sha256 {
        return Err(GemmaFirstRuntimeExecutionProbeError::LocalArtifactMismatch(
            "local_file_sha256",
        ));
    }
    if redacted_path_digest_for_path(&request.local_file_path)
        != request.upstream_receipt.redacted_path_digest
    {
        return Err(GemmaFirstRuntimeExecutionProbeError::LocalArtifactMismatch(
            "redacted_path_digest",
        ));
    }
    let identity = llama_cli_identity_for_path(&request.llama_cli_path)?;
    if identity.version_digest != request.upstream_receipt.llama_cli_version_digest {
        return Err(
            GemmaFirstRuntimeExecutionProbeError::LlamaCliIdentityMismatch("version_digest"),
        );
    }
    if identity.help_digest != request.upstream_receipt.llama_cli_help_digest {
        return Err(GemmaFirstRuntimeExecutionProbeError::LlamaCliIdentityMismatch("help_digest"));
    }
    if !identity.offline_flag_present {
        return Err(GemmaFirstRuntimeExecutionProbeError::LlamaCliIdentityMismatch("offline_flag"));
    }
    Ok(())
}

fn run_llama_cli_probe(
    request: &GemmaFirstRuntimeExecutionProbeRequest,
) -> Result<GemmaFirstRuntimeExecutionObservation, GemmaFirstRuntimeExecutionProbeError> {
    let started = Instant::now();
    let mut child = Command::new(&request.llama_cli_path)
        .args(command_args(request))
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .env_remove("MODEL_ENDPOINT")
        .env_remove("OPENAI_API_KEY")
        .env_remove("HF_HOME")
        .env_remove("HUGGINGFACE_HUB_CACHE")
        .spawn()
        .map_err(GemmaFirstRuntimeExecutionProbeError::Spawn)?;

    let stdout = child
        .stdout
        .take()
        .ok_or(GemmaFirstRuntimeExecutionProbeError::MissingField("stdout"))?;
    let stderr = child
        .stderr
        .take()
        .ok_or(GemmaFirstRuntimeExecutionProbeError::MissingField("stderr"))?;
    let stdout_reader = read_stream_capped(stdout, MAX_STDIO_BYTES);
    let stderr_reader = read_stream_capped(stderr, MAX_STDIO_BYTES);

    let timeout = Duration::from_millis(request.timeout_ms);
    let mut timed_out = false;
    let status = loop {
        if let Some(status) = child.try_wait()? {
            break status;
        }
        if started.elapsed() >= timeout {
            timed_out = true;
            let _ = child.kill();
            break child.wait()?;
        }
        thread::sleep(Duration::from_millis(10));
    };

    let stdout = stdout_reader
        .join()
        .map_err(|_| GemmaFirstRuntimeExecutionProbeError::Join("stdout"))??;
    let stderr = stderr_reader
        .join()
        .map_err(|_| GemmaFirstRuntimeExecutionProbeError::Join("stderr"))??;

    Ok(GemmaFirstRuntimeExecutionObservation {
        exit_code: status.code(),
        process_status_success: status.success(),
        timed_out,
        duration_ms: started.elapsed().as_millis().min(u128::from(u64::MAX)) as u64,
        stdout: stdout.bytes,
        stderr: stderr.bytes,
        stdout_truncated: stdout.truncated,
        stderr_truncated: stderr.truncated,
    })
}

struct CappedOutput {
    bytes: Vec<u8>,
    truncated: bool,
}

fn read_stream_capped<R: Read + Send + 'static>(
    mut reader: R,
    cap: usize,
) -> thread::JoinHandle<io::Result<CappedOutput>> {
    thread::spawn(move || {
        let mut bytes = Vec::new();
        let mut truncated = false;
        let mut buffer = [0_u8; 4096];
        loop {
            let n = reader.read(&mut buffer)?;
            if n == 0 {
                break;
            }
            let remaining = cap.saturating_sub(bytes.len());
            if remaining > 0 {
                let keep = remaining.min(n);
                bytes.extend_from_slice(&buffer[..keep]);
            }
            if n > remaining {
                truncated = true;
            }
        }
        Ok(CappedOutput { bytes, truncated })
    })
}

fn command_args(request: &GemmaFirstRuntimeExecutionProbeRequest) -> Vec<String> {
    vec![
        "--offline".to_string(),
        "-m".to_string(),
        request.local_file_path.to_string_lossy().to_string(),
        "--single-turn".to_string(),
        "--no-display-prompt".to_string(),
        "--show-timings".to_string(),
        "--ctx-size".to_string(),
        request.ctx_size.to_string(),
        "--predict".to_string(),
        request.predict.to_string(),
        "--seed".to_string(),
        request.seed.to_string(),
        "-p".to_string(),
        request.prompt.clone(),
    ]
}

fn command_argv_digest(request: &GemmaFirstRuntimeExecutionProbeRequest) -> String {
    let redacted = format!(
        "--offline -m <redacted:{}> --single-turn --no-display-prompt --show-timings --ctx-size {} --predict {} --seed {} -p <prompt:{}>",
        request.upstream_receipt.redacted_path_digest,
        request.ctx_size,
        request.predict,
        request.seed,
        sha256_hex(request.prompt.as_bytes())
    );
    sha256_hex(redacted.as_bytes())
}

fn first_token_digest(stdout: &[u8]) -> Option<String> {
    String::from_utf8_lossy(stdout)
        .split_whitespace()
        .next()
        .map(|token| sha256_hex(token.as_bytes()))
}

fn first_runtime_receipt_digest(
    receipt: &GemmaFirstRuntimeExecutionProbeReceipt,
) -> Result<String, GemmaFirstRuntimeExecutionProbeError> {
    let mut clone = receipt.clone();
    clone.receipt_digest.clear();
    Ok(sha256_hex(&serde_json::to_vec(&clone)?))
}

fn validate_nonempty(
    field: &'static str,
    value: &str,
) -> Result<(), GemmaFirstRuntimeExecutionProbeError> {
    if value.trim().is_empty() {
        return Err(GemmaFirstRuntimeExecutionProbeError::MissingField(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{
        build_receipt_from_observed_material, materialize_owner_approved_local_artifact_receipt,
        GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest,
    };
    use std::fs;
    #[cfg(unix)]
    use std::os::unix::fs::PermissionsExt;
    use std::path::Path;

    fn write_executable(path: &Path, body: &str) {
        fs::write(path, body).expect("write fake cli");
        #[cfg(unix)]
        {
            let mut permissions = fs::metadata(path).expect("metadata").permissions();
            permissions.set_mode(0o755);
            fs::set_permissions(path, permissions).expect("chmod");
        }
    }

    fn owner_phrase() -> String {
        "owner explicitly approves this local Gemma receipt".to_string()
    }

    fn receipt_request(
        model_path: PathBuf,
        llama_cli_path: PathBuf,
    ) -> GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest {
        GemmaOwnerApprovedLocalArtifactReceiptMaterializationRequest {
            owner_approval_phrase: owner_phrase(),
            local_file_path: model_path,
            selected_model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf".to_string(),
            source_repo: "google/gemma-4-E2B-it-qat-q4_0-gguf".to_string(),
            source_revision: "source-card-digest:fixture".to_string(),
            expected_filename: "gemma-fixture.gguf".to_string(),
            expected_byte_count: 12,
            expected_file_sha256: sha256_hex(b"hello gemma!"),
            source_license_ref: "license:gemma-terms".to_string(),
            provenance_mode: "owner_approved_direct_local_file".to_string(),
            hardware_profile_ref: "hardware:m2-pro-18gb-test".to_string(),
            llama_cli_path,
        }
    }

    fn fake_cli(path: &Path, runtime_body: &str) {
        write_executable(
            path,
            &format!(
                r#"#!/bin/sh
if [ "$1" = "--version" ]; then
  echo "llama-cli fake 1"
  exit 0
fi
if [ "$1" = "--help" ]; then
  echo "usage: llama-cli --offline --single-turn --no-display-prompt --show-timings"
  exit 0
fi
{runtime_body}
"#
            ),
        );
    }

    fn execution_request(dir: &Path, runtime_body: &str) -> GemmaFirstRuntimeExecutionProbeRequest {
        let model_path = dir.join("gemma-fixture.gguf");
        fs::write(&model_path, b"hello gemma!").expect("write model fixture");
        let llama_cli_path = dir.join("llama-cli");
        fake_cli(&llama_cli_path, runtime_body);
        let upstream_receipt = materialize_owner_approved_local_artifact_receipt(&receipt_request(
            model_path.clone(),
            llama_cli_path.clone(),
        ))
        .expect("upstream receipt");
        GemmaFirstRuntimeExecutionProbeRequest {
            owner_approval_phrase: owner_phrase(),
            upstream_receipt,
            local_file_path: model_path,
            llama_cli_path,
            prompt: "Return exactly OK".to_string(),
            ctx_size: 512,
            predict: 1,
            seed: 42,
            timeout_ms: 1_000,
        }
    }

    #[test]
    fn builds_digest_only_execution_receipt_without_raw_prompt_or_output() {
        let dir = tempfile::tempdir().expect("tempdir");
        let request = execution_request(
            dir.path(),
            r#"printf 'OK\n'
printf 'llama_print_timings: total time = 1 ms\n' >&2
exit 0"#,
        );
        let receipt = execute_first_runtime_probe(&request).expect("runtime receipt");
        validate_first_runtime_execution_receipt(&receipt).expect("valid receipt");
        let json =
            String::from_utf8(first_runtime_execution_receipt_json_pretty(&receipt).unwrap())
                .unwrap();

        assert!(!json.contains(dir.path().to_string_lossy().as_ref()));
        assert!(!json.contains("Return exactly OK"));
        assert!(!json.contains("OK\n"));
        assert!(json.contains("first_token_digest"));
        assert_eq!(receipt.runtime_command_executed_count, 1);
        assert_eq!(receipt.runtime_router_mutation_count, 0);
        assert_eq!(receipt.system_g_mutation_count, 0);
        assert!(!receipt.live_gemma_claim);
        assert_eq!(
            receipt.next_cursor,
            GEMMA_FIRST_RUNTIME_EXECUTION_PROBE_NEXT_CURSOR
        );
    }

    #[test]
    fn rejects_owner_phrase_that_does_not_match_upstream_receipt() {
        let dir = tempfile::tempdir().expect("tempdir");
        let mut request = execution_request(dir.path(), "printf 'OK\\n'\nexit 0");
        request.owner_approval_phrase = "different approval".to_string();
        assert!(matches!(
            execute_first_runtime_probe(&request).unwrap_err(),
            GemmaFirstRuntimeExecutionProbeError::OwnerApprovalDigestMismatch
        ));
    }

    #[test]
    fn rejects_local_path_that_does_not_match_upstream_receipt() {
        let dir = tempfile::tempdir().expect("tempdir");
        let mut request = execution_request(dir.path(), "printf 'OK\\n'\nexit 0");
        let alternate = dir.path().join("other.gguf");
        fs::write(&alternate, b"hello gemma!").expect("write alternate");
        request.local_file_path = alternate;
        assert!(matches!(
            execute_first_runtime_probe(&request).unwrap_err(),
            GemmaFirstRuntimeExecutionProbeError::LocalArtifactMismatch(_)
        ));
    }

    #[test]
    fn rejects_runtime_timeout_without_emitting_success_receipt() {
        let dir = tempfile::tempdir().expect("tempdir");
        let mut request = execution_request(dir.path(), "sleep 2\nprintf 'OK\\n'\nexit 0");
        request.timeout_ms = 100;
        assert!(matches!(
            execute_first_runtime_probe(&request).unwrap_err(),
            GemmaFirstRuntimeExecutionProbeError::ProcessTimedOut
        ));
    }

    #[test]
    fn validates_builder_policy_for_success_observation() {
        let dir = tempfile::tempdir().expect("tempdir");
        let request = execution_request(dir.path(), "printf 'OK\\n'\nexit 0");
        let receipt = build_first_runtime_execution_receipt(
            &request,
            GemmaFirstRuntimeExecutionObservation {
                exit_code: Some(0),
                process_status_success: true,
                timed_out: false,
                duration_ms: 7,
                stdout: b"OK\n".to_vec(),
                stderr: b"timings\n".to_vec(),
                stdout_truncated: false,
                stderr_truncated: false,
            },
        )
        .expect("receipt");
        validate_first_runtime_execution_receipt(&receipt).expect("valid");
    }

    #[test]
    fn rejects_builder_policy_without_first_token() {
        let dir = tempfile::tempdir().expect("tempdir");
        let request = execution_request(dir.path(), "printf 'OK\\n'\nexit 0");
        assert!(matches!(
            build_first_runtime_execution_receipt(
                &request,
                GemmaFirstRuntimeExecutionObservation {
                    exit_code: Some(0),
                    process_status_success: true,
                    timed_out: false,
                    duration_ms: 7,
                    stdout: b"   \n".to_vec(),
                    stderr: b"timings\n".to_vec(),
                    stdout_truncated: false,
                    stderr_truncated: false,
                },
            )
            .unwrap_err(),
            GemmaFirstRuntimeExecutionProbeError::ReceiptInvalid(_)
        ));
    }

    #[test]
    fn rejects_upstream_receipt_with_bad_next_cursor() {
        let dir = tempfile::tempdir().expect("tempdir");
        let model_path = dir.path().join("gemma-fixture.gguf");
        let llama_cli_path = dir.path().join("llama-cli");
        let req = receipt_request(model_path.clone(), llama_cli_path.clone());
        let mut upstream = build_receipt_from_observed_material(
            &req,
            12,
            sha256_hex(b"hello gemma!"),
            sha256_hex(b"version"),
            sha256_hex(b"help --offline"),
            true,
            true,
            true,
        )
        .expect("upstream");
        upstream.next_cursor = "wrong".to_string();
        let request = GemmaFirstRuntimeExecutionProbeRequest {
            owner_approval_phrase: owner_phrase(),
            upstream_receipt: upstream,
            local_file_path: model_path,
            llama_cli_path,
            prompt: "Return exactly OK".to_string(),
            ctx_size: 512,
            predict: 1,
            seed: 42,
            timeout_ms: 1_000,
        };
        assert!(matches!(
            request.validate().unwrap_err(),
            GemmaFirstRuntimeExecutionProbeError::UpstreamReceipt(_)
                | GemmaFirstRuntimeExecutionProbeError::InvalidParameter(
                    "upstream_receipt.next_cursor"
                )
        ));
    }
}
