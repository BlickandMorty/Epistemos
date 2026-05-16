//! Git MCP executor — read-only repository inspection.
//!
//! D.3 scope is deliberately narrow: status, diff, and log. No mutating Git
//! verbs are exposed from this module.

use crate::subprocess::hardened_command;
use crate::types::ToolResult;
use serde_json::Value;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::thread;
use std::time::{Duration, Instant};

const DEFAULT_TIMEOUT_MS: u64 = 30_000;
const MAX_TIMEOUT_MS: u64 = 120_000;
const DEFAULT_OUTPUT_BYTES: usize = 256 * 1024;
const MAX_OUTPUT_BYTES: usize = 1024 * 1024;

#[derive(Debug)]
struct CappedOutput {
    text: String,
    truncated: bool,
}

#[derive(Debug)]
struct GitCommandOutput {
    stdout: String,
    stderr: String,
    stdout_truncated: bool,
    stderr_truncated: bool,
    exit_code: Option<i32>,
    duration_ms: u64,
}

pub struct GitExecutor {
    root: PathBuf,
}

impl GitExecutor {
    pub fn new(repo_root: &str) -> Option<Self> {
        let path = PathBuf::from(repo_root);
        if !path.is_dir() {
            return None;
        }

        let output = hardened_command("/usr/bin/git")
            .arg("-C")
            .arg(&path)
            .args(["rev-parse", "--show-toplevel"])
            .output()
            .ok()?;

        if !output.status.success() {
            return None;
        }

        let top = String::from_utf8_lossy(&output.stdout).trim().to_string();
        let root = PathBuf::from(top).canonicalize().ok()?;
        Some(Self { root })
    }

    pub fn status(&self, include_branch: bool, max_bytes: usize) -> ToolResult {
        let mut args = vec!["status".to_string(), "--porcelain=v1".to_string()];
        if include_branch {
            args.push("-b".to_string());
        }

        match self.run_git(args, max_bytes, DEFAULT_TIMEOUT_MS) {
            Ok(output) => {
                let lines: Vec<&str> = output.stdout.lines().collect();
                ToolResult::ok(
                    serde_json::json!({
                        "repo_root": self.root,
                        "entries": lines,
                        "raw": output.stdout,
                        "stderr": output.stderr,
                        "stdout_truncated": output.stdout_truncated,
                        "stderr_truncated": output.stderr_truncated,
                        "exit_code": output.exit_code,
                    })
                    .to_string(),
                    output.duration_ms,
                )
            }
            Err(result) => result,
        }
    }

    pub fn diff(
        &self,
        staged: bool,
        stat: bool,
        pathspecs: Vec<String>,
        max_bytes: usize,
        timeout_ms: u64,
    ) -> ToolResult {
        let pathspecs = match validate_pathspecs(pathspecs) {
            Ok(pathspecs) => pathspecs,
            Err(error) => {
                return ToolResult::err(error, crate::types::error_codes::INVALID_INPUT, 0)
            }
        };

        let mut args = vec!["diff".to_string()];
        if staged {
            args.push("--cached".to_string());
        }
        if stat {
            args.push("--stat".to_string());
        }
        args.push("--".to_string());
        args.extend(pathspecs);

        match self.run_git(args, max_bytes, timeout_ms) {
            Ok(output) => ToolResult::ok(
                serde_json::json!({
                    "repo_root": self.root,
                    "diff": output.stdout,
                    "stderr": output.stderr,
                    "stdout_truncated": output.stdout_truncated,
                    "stderr_truncated": output.stderr_truncated,
                    "exit_code": output.exit_code,
                })
                .to_string(),
                output.duration_ms,
            ),
            Err(result) => result,
        }
    }

    pub fn log(&self, max_count: usize, oneline: bool, max_bytes: usize) -> ToolResult {
        let max_count = max_count.clamp(1, 100);
        let mut args = vec![
            "log".to_string(),
            "--date=iso-strict".to_string(),
            format!("-n{max_count}"),
        ];
        if oneline {
            args.push("--oneline".to_string());
        } else {
            args.push("--pretty=format:%H%x09%an%x09%aI%x09%s".to_string());
        }

        match self.run_git(args, max_bytes, DEFAULT_TIMEOUT_MS) {
            Ok(output) => {
                let entries: Vec<&str> = output.stdout.lines().collect();
                ToolResult::ok(
                    serde_json::json!({
                        "repo_root": self.root,
                        "entries": entries,
                        "raw": output.stdout,
                        "stderr": output.stderr,
                        "stdout_truncated": output.stdout_truncated,
                        "stderr_truncated": output.stderr_truncated,
                        "exit_code": output.exit_code,
                    })
                    .to_string(),
                    output.duration_ms,
                )
            }
            Err(result) => result,
        }
    }

    fn run_git(
        &self,
        args: Vec<String>,
        max_bytes: usize,
        timeout_ms: u64,
    ) -> Result<GitCommandOutput, ToolResult> {
        let start = Instant::now();
        let max_bytes = max_bytes.clamp(1024, MAX_OUTPUT_BYTES);
        let timeout = Duration::from_millis(timeout_ms.clamp(1_000, MAX_TIMEOUT_MS));

        let mut command = hardened_command("/usr/bin/git");
        command
            .arg("-C")
            .arg(&self.root)
            .arg("--no-pager")
            .args(&args)
            .env("GIT_TERMINAL_PROMPT", "0")
            .env("GIT_PAGER", "cat")
            .env("PAGER", "cat")
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        let mut child = match command.spawn() {
            Ok(child) => child,
            Err(error) => {
                return Err(ToolResult::err(
                    format!("Failed to launch git: {error}"),
                    crate::types::error_codes::EXECUTION_ERROR,
                    start.elapsed().as_millis() as u64,
                ))
            }
        };

        let stdout = child.stdout.take().expect("git stdout pipe");
        let stderr = child.stderr.take().expect("git stderr pipe");
        let stdout_reader = thread::spawn(move || read_capped(stdout, max_bytes));
        let stderr_reader = thread::spawn(move || read_capped(stderr, max_bytes));

        let status = loop {
            match child.try_wait() {
                Ok(Some(status)) => break status,
                Ok(None) => {
                    if start.elapsed() > timeout {
                        let _ = child.kill();
                        let _ = child.wait();
                        let duration_ms = start.elapsed().as_millis() as u64;
                        let _ = stdout_reader.join();
                        let _ = stderr_reader.join();
                        return Err(ToolResult::err(
                            "git execution timed out".to_string(),
                            crate::types::error_codes::TIMEOUT,
                            duration_ms,
                        ));
                    }
                    thread::sleep(Duration::from_millis(10));
                }
                Err(error) => {
                    let duration_ms = start.elapsed().as_millis() as u64;
                    let _ = stdout_reader.join();
                    let _ = stderr_reader.join();
                    return Err(ToolResult::err(
                        format!("Failed to poll git: {error}"),
                        crate::types::error_codes::EXECUTION_ERROR,
                        duration_ms,
                    ));
                }
            }
        };

        let duration_ms = start.elapsed().as_millis() as u64;
        let stdout = stdout_reader.join().unwrap_or(CappedOutput {
            text: String::new(),
            truncated: true,
        });
        let stderr = stderr_reader.join().unwrap_or(CappedOutput {
            text: String::new(),
            truncated: true,
        });
        let exit_code = status.code();

        if status.success() {
            Ok(GitCommandOutput {
                stdout: stdout.text,
                stderr: stderr.text,
                stdout_truncated: stdout.truncated,
                stderr_truncated: stderr.truncated,
                exit_code,
                duration_ms,
            })
        } else {
            let message = if stderr.text.trim().is_empty() {
                format!("git failed with exit code {exit_code:?}")
            } else {
                format!(
                    "git failed with exit code {exit_code:?}: {}",
                    stderr.text.trim()
                )
            };
            Err(ToolResult::err(
                message,
                crate::types::error_codes::EXECUTION_ERROR,
                duration_ms,
            ))
        }
    }
}

pub fn execute_git_tool(repo_root: String, tool_name: String, args_json: String) -> String {
    let Some(executor) = GitExecutor::new(&repo_root) else {
        let result = ToolResult::err(
            format!("Git repository root does not exist or is not a worktree: {repo_root}"),
            crate::types::error_codes::NOT_FOUND,
            0,
        );
        return serde_json::to_string(&result).unwrap_or_default();
    };

    let args: Value =
        serde_json::from_str(&args_json).unwrap_or(Value::Object(serde_json::Map::new()));
    let max_bytes = args["maxBytes"]
        .as_u64()
        .map(|value| value as usize)
        .unwrap_or(DEFAULT_OUTPUT_BYTES);

    let result = match tool_name.as_str() {
        "git.status" | "git_status" => {
            let include_branch = args["includeBranch"].as_bool().unwrap_or(false);
            executor.status(include_branch, max_bytes)
        }
        "git.diff" | "git_diff" => {
            let staged = args["staged"].as_bool().unwrap_or(false);
            let stat = args["stat"].as_bool().unwrap_or(false);
            let timeout_ms = args["timeoutMs"]
                .as_u64()
                .unwrap_or(DEFAULT_TIMEOUT_MS)
                .clamp(1_000, MAX_TIMEOUT_MS);
            let pathspecs = args["pathspecs"]
                .as_array()
                .map(|values| {
                    values
                        .iter()
                        .filter_map(|value| value.as_str().map(ToString::to_string))
                        .collect()
                })
                .unwrap_or_default();
            executor.diff(staged, stat, pathspecs, max_bytes, timeout_ms)
        }
        "git.log" | "git_log" => {
            let max_count = args["maxCount"].as_u64().unwrap_or(20) as usize;
            let oneline = args["oneline"].as_bool().unwrap_or(false);
            executor.log(max_count, oneline, max_bytes)
        }
        _ => ToolResult::err(
            format!("Unknown git tool: {tool_name}"),
            crate::types::error_codes::NOT_FOUND,
            0,
        ),
    };

    serde_json::to_string(&result).unwrap_or_default()
}

fn read_capped(mut reader: impl Read, max_bytes: usize) -> CappedOutput {
    let mut stored = Vec::with_capacity(max_bytes.min(8192));
    let mut buf = [0u8; 8192];
    let mut truncated = false;

    loop {
        let n = match reader.read(&mut buf) {
            Ok(0) => break,
            Ok(n) => n,
            Err(_) => {
                truncated = true;
                break;
            }
        };
        let remaining = max_bytes.saturating_sub(stored.len());
        if remaining > 0 {
            let keep = remaining.min(n);
            stored.extend_from_slice(&buf[..keep]);
            if keep < n {
                truncated = true;
            }
        } else {
            truncated = true;
        }
    }

    CappedOutput {
        text: String::from_utf8_lossy(&stored).to_string(),
        truncated,
    }
}

fn validate_pathspecs(pathspecs: Vec<String>) -> Result<Vec<String>, String> {
    let mut checked = Vec::with_capacity(pathspecs.len());
    for pathspec in pathspecs {
        if pathspec.is_empty() {
            return Err("Git pathspec cannot be empty".to_string());
        }
        if pathspec.starts_with('-') {
            return Err("Git pathspec cannot start with '-'".to_string());
        }
        if pathspec.contains('\0') {
            return Err("Git pathspec cannot contain NUL bytes".to_string());
        }
        let path = Path::new(&pathspec);
        if path.is_absolute() {
            return Err("Git pathspec must be repository-relative".to_string());
        }
        if path
            .components()
            .any(|component| matches!(component, std::path::Component::ParentDir))
        {
            return Err("Git pathspec traversal is not allowed".to_string());
        }
        checked.push(pathspec);
    }
    Ok(checked)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::process::Command;

    fn git(dir: &Path, args: &[&str]) {
        let output = Command::new("/usr/bin/git")
            .arg("-C")
            .arg(dir)
            .args(args)
            .output()
            .expect("launch git");
        assert!(
            output.status.success(),
            "git {:?} failed: {}",
            args,
            String::from_utf8_lossy(&output.stderr)
        );
    }

    fn make_repo() -> tempfile::TempDir {
        let dir = tempfile::tempdir().expect("tempdir");
        git(dir.path(), &["init"]);
        git(dir.path(), &["config", "user.email", "test@example.com"]);
        git(dir.path(), &["config", "user.name", "Epistemos Test"]);
        git(dir.path(), &["config", "commit.gpgsign", "false"]);
        dir
    }

    fn parsed(result: &str) -> Value {
        serde_json::from_str(result).expect("tool result json")
    }

    #[test]
    fn git_status_reports_porcelain_entries() {
        let dir = make_repo();
        fs::write(dir.path().join("note.md"), "# Note\n").expect("write");

        let result = execute_git_tool(
            dir.path().display().to_string(),
            "git.status".to_string(),
            r#"{"includeBranch":true}"#.to_string(),
        );
        let json = parsed(&result);

        assert_eq!(json["success"], true);
        let data: Value = serde_json::from_str(json["data_json"].as_str().unwrap()).unwrap();
        assert!(data["raw"].as_str().unwrap().contains("?? note.md"));
    }

    #[test]
    fn git_diff_rejects_path_traversal() {
        let dir = make_repo();
        let result = execute_git_tool(
            dir.path().display().to_string(),
            "git.diff".to_string(),
            r#"{"pathspecs":["../secret.md"]}"#.to_string(),
        );
        let json = parsed(&result);

        assert_eq!(json["success"], false);
        assert_eq!(json["error_code"], crate::types::error_codes::INVALID_INPUT);
    }

    #[test]
    fn git_log_limits_count() {
        let dir = make_repo();
        fs::write(dir.path().join("note.md"), "# Note\n").expect("write");
        git(dir.path(), &["add", "note.md"]);
        git(dir.path(), &["commit", "-m", "initial note"]);

        fs::write(dir.path().join("note.md"), "# Note\nMore\n").expect("write");
        git(dir.path(), &["add", "note.md"]);
        git(dir.path(), &["commit", "-m", "second note"]);

        let result = execute_git_tool(
            dir.path().display().to_string(),
            "git.log".to_string(),
            r#"{"maxCount":1,"oneline":true}"#.to_string(),
        );
        let json = parsed(&result);

        assert_eq!(json["success"], true);
        let data: Value = serde_json::from_str(json["data_json"].as_str().unwrap()).unwrap();
        let entries = data["entries"].as_array().unwrap();
        assert_eq!(entries.len(), 1);
        assert!(entries[0].as_str().unwrap().contains("second note"));
    }
}
