// UniFFI-exported free functions for Swift interop.

use crate::types::PermissionStatus;
use crate::ax_tree;
use crate::permissions;
use crate::input;

/// Check all macOS permissions needed for automation.
pub fn check_permissions() -> PermissionStatus {
    permissions::check_permissions()
}

/// Walk the accessibility tree for the app with given PID.
/// Returns a JSON-encoded AXTreeSnapshot.
pub fn walk_ax_tree_json(pid: i64) -> String {
    let snapshot = ax_tree::walk_ax_tree(pid);
    serde_json::to_string(&snapshot).unwrap_or_default()
}

/// Simulate a click at (x, y).
pub fn simulate_click(x: f64, y: f64) -> String {
    let result = input::execute_input(&crate::types::InputEvent::Click { x, y });
    serde_json::to_string(&result).unwrap_or_default()
}

/// Simulate typing text.
pub fn simulate_type_text(text: String) -> String {
    let result = input::execute_input(&crate::types::InputEvent::TypeText { text });
    serde_json::to_string(&result).unwrap_or_default()
}
