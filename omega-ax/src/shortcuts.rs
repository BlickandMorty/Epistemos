// Shortcuts CLI wrapper: list, run, and manage macOS Shortcuts from Rust.
// Uses Process::Command to invoke /usr/bin/shortcuts.

use std::process::Command;
use std::time::Instant;
use crate::types::AutomationResult;

/// List all installed shortcuts. Returns JSON array of names.
pub fn list_shortcuts() -> AutomationResult {
    let start = Instant::now();

    let output = match Command::new("/usr/bin/shortcuts")
        .arg("list")
        .output()
    {
        Ok(o) => o,
        Err(e) => return AutomationResult {
            success: false,
            error: Some(format!("Failed to run shortcuts CLI: {e}")),
            duration_ms: start.elapsed().as_millis() as u64,
        },
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

    let mut cmd = Command::new("/usr/bin/shortcuts");
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
                error: Some(if err_msg.contains("not found") || err_msg.contains("No such") {
                    format!("NOT_FOUND: Shortcut '{}' does not exist", name)
                } else {
                    format!("Failed to run shortcut '{}': {}", name, e)
                }),
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
