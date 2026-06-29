use std::env;
use std::fs;
use std::io::Read;
#[cfg(unix)]
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::time::Duration;

use serde_json::{json, Value};
use tempfile::Builder;

use super::browser_executable::{extended_path, find_agent_browser};
use super::browser_private::create_private_browser_dir;
use super::browser_redaction::redact_browser_error_detail;
use super::browser_screenshot::{
    extract_screenshot_path, screenshot_directory, AGENT_BROWSER_SCREENSHOT_DIR_ENV,
};
use super::registry::ToolError;

const MAX_BROWSER_OUTPUT_BYTES: usize = 512 * 1024;

pub(crate) fn socket_dir_for_session(session_name: &str) -> PathBuf {
    let base = if cfg!(target_os = "macos") {
        PathBuf::from("/tmp")
    } else {
        env::temp_dir()
    };
    base.join(format!("agent-browser-{session_name}"))
}

pub(crate) async fn run_agent_browser_command(
    command_name: &str,
    args: &[String],
    session_name: &str,
    cdp_url: Option<&str>,
    socket_dir: &Path,
    timeout: Duration,
) -> Result<Value, ToolError> {
    let executable = find_agent_browser()?;
    create_private_browser_dir(socket_dir)?;
    let stdout_file = Builder::new()
        .prefix("stdout-")
        .tempfile_in(socket_dir)
        .map_err(|e| ToolError::ExecutionFailed(format!("create browser stdout temp file: {e}")))?;
    let stderr_file = Builder::new()
        .prefix("stderr-")
        .tempfile_in(socket_dir)
        .map_err(|e| ToolError::ExecutionFailed(format!("create browser stderr temp file: {e}")))?;

    let stdout_handle = stdout_file
        .reopen()
        .map_err(|e| ToolError::ExecutionFailed(format!("reopen browser stdout temp file: {e}")))?;
    let stderr_handle = stderr_file
        .reopen()
        .map_err(|e| ToolError::ExecutionFailed(format!("reopen browser stderr temp file: {e}")))?;

    let mut command = executable.into_command();
    command.arg("--session").arg(session_name);
    if let Some(cdp_url) = cdp_url {
        command.arg("--cdp").arg(cdp_url);
    }
    command.arg("--json").arg(command_name);
    for arg in args {
        command.arg(arg);
    }
    command.env("AGENT_BROWSER_SOCKET_DIR", socket_dir);
    if command_name == "screenshot" {
        command.env(AGENT_BROWSER_SCREENSHOT_DIR_ENV, screenshot_directory()?);
    }
    command.env("PATH", extended_path());
    command.env("PYTHON_DOTENV_DISABLED", "true");
    command.stdin(Stdio::null());
    command.stdout(Stdio::from(stdout_handle));
    command.stderr(Stdio::from(stderr_handle));

    let mut child = command
        .spawn()
        .map_err(|e| ToolError::ExecutionFailed(format!("spawn agent-browser: {e}")))?;

    let status = match tokio::time::timeout(timeout, child.wait()).await {
        Ok(wait_result) => wait_result
            .map_err(|e| ToolError::ExecutionFailed(format!("wait for agent-browser: {e}")))?,
        Err(_) => {
            let _ = child.kill().await;
            let _ = child.wait().await;
            return Err(ToolError::ExecutionFailed(format!(
                "browser command '{command_name}' timed out after {}s",
                timeout.as_secs()
            )));
        }
    };

    let stdout = read_limited_browser_output(stdout_file.path(), "stdout")?;
    let stderr = read_limited_browser_output(stderr_file.path(), "stderr")?;
    let stdout = stdout.trim().to_string();
    let stderr = stderr.trim().to_string();

    if !stdout.is_empty() {
        if let Ok(parsed) = serde_json::from_str::<Value>(&stdout) {
            if parsed
                .get("success")
                .and_then(Value::as_bool)
                .is_some_and(|success| !success)
            {
                let message = parsed
                    .get("error")
                    .and_then(Value::as_str)
                    .unwrap_or("agent-browser reported failure");
                return Err(ToolError::ExecutionFailed(format!(
                    "agent-browser '{command_name}' failed: {}",
                    redact_browser_error_detail(message)
                )));
            }
            return Ok(parsed);
        }

        if command_name == "screenshot" {
            if let Some(path) = extract_screenshot_path(&stdout) {
                return Ok(json!({
                    "success": true,
                    "data": {
                        "path": path,
                    }
                }));
            }
        }

        if !status.success() {
            let code = status.code().unwrap_or(-1);
            let stream = if stderr.is_empty() {
                "stdout"
            } else {
                "stderr"
            };
            return Err(ToolError::ExecutionFailed(format!(
                "agent-browser '{command_name}' failed with exit code {code}; {stream} redacted"
            )));
        }

        return Err(ToolError::ExecutionFailed(format!(
            "agent-browser returned non-JSON output for '{command_name}' (stdout redacted)"
        )));
    }

    if !status.success() {
        let code = status.code().unwrap_or(-1);
        let detail = if stderr.is_empty() {
            format!("exit code {code}")
        } else {
            format!("exit code {code}; stderr redacted")
        };
        return Err(ToolError::ExecutionFailed(format!(
            "agent-browser '{command_name}' failed: {detail}"
        )));
    }

    Ok(json!({
        "success": true,
        "data": {},
    }))
}

fn read_limited_browser_output(path: &Path, stream: &str) -> Result<String, ToolError> {
    let file = fs::File::open(path)
        .map_err(|e| ToolError::ExecutionFailed(format!("read browser {stream}: {e}")))?;
    let mut reader = file.take((MAX_BROWSER_OUTPUT_BYTES + 1) as u64);
    let mut bytes = Vec::with_capacity(MAX_BROWSER_OUTPUT_BYTES.min(8 * 1024));
    reader
        .read_to_end(&mut bytes)
        .map_err(|e| ToolError::ExecutionFailed(format!("read browser {stream}: {e}")))?;

    let truncated = bytes.len() > MAX_BROWSER_OUTPUT_BYTES;
    if truncated {
        bytes.truncate(MAX_BROWSER_OUTPUT_BYTES);
    }
    let mut text = decode_limited_browser_output(&bytes, truncated, stream)?;
    if truncated {
        text.push_str(&format!(
            "\n... [{stream} truncated at {MAX_BROWSER_OUTPUT_BYTES} bytes]"
        ));
    }
    Ok(text)
}

fn decode_limited_browser_output(
    bytes: &[u8],
    truncated: bool,
    stream: &str,
) -> Result<String, ToolError> {
    match std::str::from_utf8(bytes) {
        Ok(text) => Ok(text.to_string()),
        Err(error) if truncated && error.error_len().is_none() => {
            Ok(std::str::from_utf8(&bytes[..error.valid_up_to()])
                .map_err(|_| {
                    ToolError::ExecutionFailed(format!(
                        "agent-browser {stream} was not valid UTF-8"
                    ))
                })?
                .to_string())
        }
        Err(_) => Err(ToolError::ExecutionFailed(format!(
            "agent-browser {stream} was not valid UTF-8"
        ))),
    }
}

pub(crate) fn cleanup_local_daemon(session_name: &str, socket_dir: &Path) {
    if !cleanup_socket_dir_is_private(socket_dir) {
        return;
    }

    #[cfg(unix)]
    {
        let pid_file = socket_dir.join(format!("{session_name}.pid"));
        if let Ok(pid_text) = fs::read_to_string(&pid_file) {
            if let Ok(pid) = pid_text.trim().parse::<i32>() {
                // SAFETY: Sending SIGTERM to a pid read from agent-browser's own
                // pidfile is the intended cleanup path for that child daemon.
                unsafe { libc::kill(pid, libc::SIGTERM) };
            }
        }
    }
    let _ = fs::remove_dir_all(socket_dir);
}

fn cleanup_socket_dir_is_private(socket_dir: &Path) -> bool {
    #[cfg(unix)]
    {
        let Ok(metadata) = fs::symlink_metadata(socket_dir) else {
            return false;
        };
        if metadata.file_type().is_symlink() || !metadata.is_dir() {
            return false;
        }
        metadata.uid() == unsafe { libc::geteuid() }
    }

    #[cfg(not(unix))]
    {
        socket_dir.is_dir()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn browser_output_rejects_non_utf8_without_echoing_bytes() {
        let err = decode_limited_browser_output(&[0xff, 0xfe], false, "stdout").unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("stdout was not valid UTF-8"));
        assert!(!message.contains("255"));
        assert!(!message.contains("0xff"));
    }

    #[test]
    fn browser_output_truncation_trims_incomplete_utf8_boundary() {
        let mut bytes = vec![b'a'; MAX_BROWSER_OUTPUT_BYTES - 1];
        bytes.push(0xe2);

        let decoded = decode_limited_browser_output(&bytes, true, "stdout").unwrap();
        assert_eq!(decoded.len(), MAX_BROWSER_OUTPUT_BYTES - 1);
        assert!(decoded.bytes().all(|byte| byte == b'a'));
    }

    #[cfg(unix)]
    #[test]
    fn browser_cleanup_ignores_symlinked_socket_directory() {
        let temp = tempfile::tempdir().unwrap();
        let target = temp.path().join("target");
        let link = temp.path().join("socket-link");
        fs::create_dir_all(&target).unwrap();
        fs::write(target.join("session.pid"), b"not-a-pid").unwrap();
        std::os::unix::fs::symlink(&target, &link).unwrap();

        cleanup_local_daemon("session", &link);

        assert!(link.exists());
        assert!(target.join("session.pid").exists());
    }

    #[cfg(unix)]
    #[test]
    fn browser_cleanup_removes_private_socket_directory() {
        let temp = tempfile::tempdir().unwrap();
        let socket_dir = temp.path().join("socket");
        fs::create_dir_all(&socket_dir).unwrap();
        fs::write(socket_dir.join("session.pid"), b"not-a-pid").unwrap();

        cleanup_local_daemon("session", &socket_dir);

        assert!(!socket_dir.exists());
    }
}
