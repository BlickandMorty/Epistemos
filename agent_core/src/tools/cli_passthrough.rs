//! CLI-passthrough tools — Tunnel C.
//!
//! Lets the in-process agent delegate a task to another full-featured
//! coding-agent CLI running as a subprocess. No per-capability code on
//! our side — whatever the target CLI can do (install packages, run
//! sandboxed commands, edit files, use its own tool set, run its own
//! MCP servers, use `git`, `ssh`, `curl`, anything a shell can do), we
//! get that for free.
//!
//! Two tools:
//!
//! * `claude_code` — spawns Anthropic's Claude Code CLI (`claude -p`)
//!   in non-interactive mode with `--permission-mode bypassPermissions`
//!   by default (tunnel mode; the caller has already approved the tool
//!   invocation up front). Requires the binary to be in PATH (e.g.
//!   `~/.local/bin/claude` added via the official installer).
//!
//! * `codex` — spawns OpenAI's Codex CLI
//!   (`/Applications/Codex.app/Contents/Resources/codex exec <prompt>`).
//!   Ships with the Codex desktop app on macOS, so users who already
//!   have that app get the CLI for free.
//!
//! Both tools stream their child stdout+stderr into the tool result with
//! a generous default timeout (5 minutes) and a hard cap (30 minutes).
//! Working directory and extra env can be set per-invocation. If the
//! target CLI isn't installed, the tool returns a structured
//! install-hint message so the caller can recover by installing it.

use std::path::PathBuf;

use async_trait::async_trait;
use serde_json::Value;

use super::registry::{ToolError, ToolHandler};

const DEFAULT_TIMEOUT_SECONDS: u64 = 300; // 5 minutes
const MAX_TIMEOUT_SECONDS: u64 = 1_800; // 30 minutes

/// Candidate absolute paths for `claude` CLI, in preference order. PATH
/// lookup via `which` is still tried first.
fn claude_code_candidate_paths() -> Vec<PathBuf> {
    let mut candidates: Vec<PathBuf> = Vec::new();
    if let Some(home) = std::env::var_os("HOME") {
        let home = PathBuf::from(home);
        candidates.push(home.join(".local").join("bin").join("claude"));
        candidates.push(home.join(".claude").join("local").join("claude"));
        candidates.push(home.join(".npm-global").join("bin").join("claude"));
    }
    candidates.push(PathBuf::from("/opt/homebrew/bin/claude"));
    candidates.push(PathBuf::from("/usr/local/bin/claude"));
    candidates
}

/// Candidate absolute paths for `codex` CLI, in preference order.
fn codex_candidate_paths() -> Vec<PathBuf> {
    let mut candidates: Vec<PathBuf> = Vec::new();
    if let Some(home) = std::env::var_os("HOME") {
        let home = PathBuf::from(home);
        candidates.push(home.join(".local").join("bin").join("codex"));
    }
    candidates.push(PathBuf::from(
        "/Applications/Codex.app/Contents/Resources/codex",
    ));
    candidates.push(PathBuf::from("/opt/homebrew/bin/codex"));
    candidates.push(PathBuf::from("/usr/local/bin/codex"));
    candidates
}

fn resolve_binary(name: &str, extra_candidates: &[PathBuf]) -> Option<PathBuf> {
    // PATH first.
    if let Ok(path) = std::env::var("PATH") {
        for dir in std::env::split_paths(&path) {
            let candidate = dir.join(name);
            if candidate.is_file() {
                return Some(candidate);
            }
        }
    }
    // Known install locations.
    for candidate in extra_candidates {
        if candidate.is_file() {
            return Some(candidate.clone());
        }
    }
    None
}

fn parse_timeout(input: &Value) -> u64 {
    input
        .get("timeout_seconds")
        .and_then(Value::as_u64)
        .unwrap_or(DEFAULT_TIMEOUT_SECONDS)
        .min(MAX_TIMEOUT_SECONDS)
}

fn parse_working_dir(input: &Value) -> Option<String> {
    input
        .get("working_dir")
        .and_then(Value::as_str)
        .map(|s| s.to_string())
}

fn missing_binary_payload(name: &str, install_hint: &str) -> String {
    serde_json::to_string(&serde_json::json!({
        "error": format!("{name} CLI is not installed on this machine"),
        "install_hint": install_hint,
    }))
    .unwrap_or_else(|_| format!("{name} CLI not installed: {install_hint}"))
}

async fn run_passthrough(
    binary: PathBuf,
    args: Vec<String>,
    working_dir: Option<String>,
    timeout_seconds: u64,
    tool_name: &str,
) -> Result<String, ToolError> {
    let mut command = tokio::process::Command::new(&binary);
    command.args(&args);
    if let Some(dir) = working_dir.as_deref() {
        command.current_dir(dir);
    }
    // Doctrine-mandated subprocess hardening: env_clear + tight allowlist
    // (PATH/HOME/USER/locale/TERM only), kill_on_drop, process_group(0).
    // Defends against LD_PRELOAD / DYLD_INSERT_LIBRARIES / NODE_OPTIONS /
    // PYTHONPATH and the rest of the dynamic-loader + interpreter-option
    // hijack vectors. CLI auth is the user's responsibility — the CLI
    // reads its own config from the user's home dir, not from inherited
    // env vars (so we do NOT proxy ANTHROPIC_API_KEY / OPENAI_API_KEY).
    crate::security::harden_cli_subprocess(&mut command);
    command.stdin(std::process::Stdio::null());
    command.stdout(std::process::Stdio::piped());
    command.stderr(std::process::Stdio::piped());

    let output = tokio::time::timeout(
        std::time::Duration::from_secs(timeout_seconds),
        command.output(),
    )
    .await
    .map_err(|_| {
        ToolError::ExecutionFailed(format!("{tool_name} timed out after {timeout_seconds}s"))
    })?
    .map_err(|error| ToolError::ExecutionFailed(format!("{tool_name} spawn failed: {error}")))?;

    // Post-read output cap. The doctrine names "Codex 1.8GB stdout
    // regression" as one of the 13 hardest engineering problems —
    // a runaway CLI that floods stdout will OOM if we keep an
    // unbounded String. Cap at 10 MiB per stream so even the worst
    // case fits in agent context. NOTE: `cmd.output()` itself
    // already collected everything into memory before returning;
    // the true streaming-with-backpressure fix is a Phase-2 refactor
    // that uses `cmd.spawn()` + bounded async reads. This cap is
    // graduated hardening: bounds the post-collection allocation.
    const MAX_OUTPUT_BYTES: usize = 10 * 1024 * 1024;
    let stdout_bytes = &output.stdout[..output.stdout.len().min(MAX_OUTPUT_BYTES)];
    let stderr_bytes = &output.stderr[..output.stderr.len().min(MAX_OUTPUT_BYTES)];
    let stdout = String::from_utf8_lossy(stdout_bytes).trim().to_string();
    let stderr = String::from_utf8_lossy(stderr_bytes).trim().to_string();
    let exit_code = output.status.code().unwrap_or(-1);

    let mut parts: Vec<String> = Vec::new();
    parts.push(format!("{tool_name} binary: {}", binary.display()));
    if !stdout.is_empty() {
        parts.push(format!("STDOUT:\n{stdout}"));
    }
    if !stderr.is_empty() {
        parts.push(format!("STDERR:\n{stderr}"));
    }
    if !output.status.success() {
        parts.push(format!("Exit code: {exit_code}"));
    }
    Ok(parts.join("\n\n"))
}

pub struct ClaudeCodeHandler;

#[async_trait]
impl ToolHandler for ClaudeCodeHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let task = input
            .get("task")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("task required".to_string()))?
            .to_string();
        let working_dir = parse_working_dir(input);
        let timeout_seconds = parse_timeout(input);
        let bypass_permissions = input
            .get("bypass_permissions")
            .and_then(Value::as_bool)
            .unwrap_or(true);
        let model = input.get("model").and_then(Value::as_str);

        let binary = match resolve_binary("claude", &claude_code_candidate_paths()) {
            Some(path) => path,
            None => {
                return Ok(missing_binary_payload(
                    "claude_code",
                    "Install Claude Code CLI: `npm install -g @anthropic-ai/claude-code` (or see https://docs.claude.com/claude-code for alternative installers).",
                ));
            }
        };

        let mut args: Vec<String> = Vec::new();
        args.push("-p".to_string()); // --print / non-interactive
        if bypass_permissions {
            args.push("--permission-mode".to_string());
            args.push("bypassPermissions".to_string());
        }
        if let Some(model) = model {
            args.push("--model".to_string());
            args.push(model.to_string());
        }
        args.push(task);

        run_passthrough(binary, args, working_dir, timeout_seconds, "claude_code").await
    }
}

pub struct CodexHandler;

#[async_trait]
impl ToolHandler for CodexHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let task = input
            .get("task")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("task required".to_string()))?
            .to_string();
        let working_dir = parse_working_dir(input);
        let timeout_seconds = parse_timeout(input);
        let use_sandbox = input
            .get("sandbox")
            .and_then(Value::as_bool)
            .unwrap_or(false);

        let binary = match resolve_binary("codex", &codex_candidate_paths()) {
            Some(path) => path,
            None => {
                return Ok(missing_binary_payload(
                    "codex",
                    "Install Codex by downloading the Codex desktop app from https://openai.com/codex (macOS bundles the CLI at /Applications/Codex.app/Contents/Resources/codex), or via the CLI distribution of your choice.",
                ));
            }
        };

        let mut args: Vec<String> = Vec::new();
        if use_sandbox {
            args.push("sandbox".to_string());
            args.push(task);
        } else {
            args.push("exec".to_string());
            args.push(task);
        }

        run_passthrough(binary, args, working_dir, timeout_seconds, "codex").await
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn claude_code_candidate_paths_are_non_empty() {
        assert!(!claude_code_candidate_paths().is_empty());
    }

    #[test]
    fn codex_candidate_paths_include_desktop_app() {
        let paths = codex_candidate_paths();
        assert!(paths
            .iter()
            .any(|p| p.ends_with("Codex.app/Contents/Resources/codex")));
    }

    #[test]
    fn resolve_binary_finds_nothing_for_garbage_name() {
        assert!(resolve_binary("this_cli_does_not_exist_xyz_qwertyuiop_", &[]).is_none());
    }

    #[test]
    fn parse_timeout_applies_default_and_cap() {
        use serde_json::json;
        assert_eq!(parse_timeout(&json!({})), DEFAULT_TIMEOUT_SECONDS);
        assert_eq!(parse_timeout(&json!({"timeout_seconds": 60})), 60);
        assert_eq!(
            parse_timeout(&json!({"timeout_seconds": 99_999})),
            MAX_TIMEOUT_SECONDS
        );
    }

    #[test]
    fn missing_binary_payload_is_valid_json() {
        let s = missing_binary_payload("foo", "install foo");
        let parsed: serde_json::Value =
            serde_json::from_str(&s).expect("missing_binary_payload should be JSON");
        assert_eq!(parsed["install_hint"], "install foo");
    }
}
