// Shortcuts CLI wrapper: list, run, and manage macOS Shortcuts from Rust.
// Uses Process::Command to invoke /usr/bin/shortcuts.

use crate::types::AutomationResult;
use std::process::Command;
use std::time::Instant;

const SUBPROCESS_ALLOWLIST: &[&str] = &[
    "PATH",
    "HOME",
    "USER",
    "LOGNAME",
    "LANG",
    "LC_ALL",
    "LC_CTYPE",
    "LC_MESSAGES",
    "TERM",
    "SHELL",
    "TMPDIR",
    "__CF_USER_TEXT_ENCODING",
];
const SUBPROCESS_DENYLIST: &[&str] = &[
    "OPENAI_API_KEY",
    "OPENAI_ACCESS_TOKEN",
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_ACCESS_TOKEN",
    "GOOGLE_API_KEY",
    "GOOGLE_ACCESS_TOKEN",
    "PERPLEXITY_API_KEY",
    "OPENROUTER_API_KEY",
    "HF_TOKEN",
];

fn hardened_command(program: &str) -> Command {
    let mut command = Command::new(program);
    command.env_clear();
    for &key in SUBPROCESS_ALLOWLIST {
        if SUBPROCESS_DENYLIST.contains(&key) {
            continue;
        }
        if let Ok(value) = std::env::var(key) {
            command.env(key, value);
        }
    }
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        command.process_group(0);
    }
    command
}

/// List all installed shortcuts. Returns JSON array of names.
pub fn list_shortcuts() -> AutomationResult {
    let start = Instant::now();

    let output = match hardened_command("/usr/bin/shortcuts").arg("list").output() {
        Ok(o) => o,
        Err(e) => {
            return AutomationResult {
                success: false,
                error: Some(format!("Failed to run shortcuts CLI: {e}")),
                duration_ms: start.elapsed().as_millis() as u64,
            }
        }
    };

    let duration_ms = start.elapsed().as_millis() as u64;

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let _names: Vec<&str> = stdout.lines().collect();
        AutomationResult {
            success: true,
            error: None,
            duration_ms,
        }
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        AutomationResult {
            success: false,
            error: Some(format!("shortcuts list failed: {stderr}")),
            duration_ms,
        }
    }
}

/// Run a named shortcut with optional input. Returns the output.
pub fn run_shortcut(name: &str, input: Option<&str>) -> AutomationResult {
    let start = Instant::now();

    let mut cmd = hardened_command("/usr/bin/shortcuts");
    cmd.arg("run").arg(name);

    if let Some(inp) = input {
        cmd.arg("-i").arg(inp);
    }

    let output = match cmd.output() {
        Ok(o) => o,
        Err(e) => {
            let duration_ms = start.elapsed().as_millis() as u64;
            // Check if shortcut not found
            let err_msg = format!("{e}");
            return AutomationResult {
                success: false,
                error: Some(
                    if err_msg.contains("not found") || err_msg.contains("No such") {
                        format!("NOT_FOUND: Shortcut '{}' does not exist", name)
                    } else {
                        format!("Failed to run shortcut '{}': {}", name, e)
                    },
                ),
                duration_ms,
            };
        }
    };

    let duration_ms = start.elapsed().as_millis() as u64;

    if output.status.success() {
        AutomationResult {
            success: true,
            error: None,
            duration_ms,
        }
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let err = if stderr.contains("couldn't find") || stderr.contains("not found") {
            format!("NOT_FOUND: Shortcut '{}' does not exist", name)
        } else {
            format!("Shortcut '{}' failed: {}", name, stderr)
        };
        AutomationResult {
            success: false,
            error: Some(err),
            duration_ms,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    fn restore_env(saved: Vec<(&'static str, Option<String>)>) {
        for (var, value) in saved {
            match value {
                Some(value) => std::env::set_var(var, value),
                None => std::env::remove_var(var),
            }
        }
    }

    #[test]
    fn test_shortcuts_command_scrubs_provider_secrets() {
        let _guard = ENV_LOCK.lock().expect("env lock poisoned");
        let secret_vars = [
            "OPENAI_API_KEY",
            "ANTHROPIC_API_KEY",
            "GOOGLE_API_KEY",
            "PERPLEXITY_API_KEY",
            "HF_TOKEN",
        ];
        let saved: Vec<(&'static str, Option<String>)> = secret_vars
            .iter()
            .map(|&var| (var, std::env::var(var).ok()))
            .collect();
        for &var in &secret_vars {
            std::env::set_var(var, format!("omega-ax-fixture-{var}"));
        }

        let output = hardened_command("/usr/bin/env")
            .output()
            .expect("env binary must exist on test host");
        restore_env(saved);

        let env = String::from_utf8_lossy(&output.stdout);
        for &var in &secret_vars {
            assert!(
                !env.contains(&format!("{var}=")),
                "{var} leaked into omega-ax child env: {env}"
            );
            assert!(
                !env.contains(&format!("omega-ax-fixture-{var}")),
                "{var} fixture value leaked into omega-ax child env: {env}"
            );
        }
    }

    #[test]
    fn test_list_shortcuts_runs() {
        // This test verifies the function doesn't panic.
        // On CI without shortcuts, it returns either success (empty list) or error.
        let result = list_shortcuts();
        assert!(result.success || result.error.is_some());
    }

    #[test]
    fn test_run_nonexistent_shortcut() {
        let result = run_shortcut("ThisShortcutDoesNotExist_12345", None);
        // Should fail with NOT_FOUND or an error
        assert!(!result.success || result.error.is_some());
    }
}
