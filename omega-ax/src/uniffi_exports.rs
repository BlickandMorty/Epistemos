// UniFFI-exported free functions for Swift interop.

use crate::types::PermissionStatus;
use crate::ax_tree;
use crate::permissions;
use crate::input;
use crate::shortcuts;

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

/// Run a macOS Shortcuts.app shortcut by name.
/// Returns JSON-encoded AutomationResult.
pub fn run_shortcut_by_name(name: String) -> String {
    let result = shortcuts::run_shortcut(&name, None);
    serde_json::to_string(&result).unwrap_or_default()
}

/// Find an element by label/title in a running app's AX tree and click it.
/// Walks the AX tree for the given PID, finds the first element whose
/// title/value/description matches `element_name`, and clicks its center.
/// Returns JSON with success/error status.
pub fn click_element_by_name(pid: i64, element_name: String) -> String {
    let snapshot = ax_tree::walk_ax_tree(pid);

    // Search for matching element
    let target = snapshot.elements.iter().find(|el| {
        el.title.as_deref().map_or(false, |t| {
            t.eq_ignore_ascii_case(&element_name) || t.to_lowercase().contains(&element_name.to_lowercase())
        }) || el.value.as_deref().map_or(false, |v| {
            v.eq_ignore_ascii_case(&element_name) || v.to_lowercase().contains(&element_name.to_lowercase())
        }) || el.description.as_deref().map_or(false, |d| {
            d.eq_ignore_ascii_case(&element_name) || d.to_lowercase().contains(&element_name.to_lowercase())
        })
    });

    match target {
        Some(el) => {
            // Click center of element's frame
            let cx = el.position_x + el.size_width / 2.0;
            let cy = el.position_y + el.size_height / 2.0;
            if el.size_width == 0.0 && el.size_height == 0.0 {
                return format!(
                    "{{\"success\":false,\"error\":\"Found element '{}' but it has zero size (x:{}, y:{})\",\"element_role\":\"{}\"}}",
                    element_name, el.position_x, el.position_y, el.role
                );
            }
            let click_result = input::execute_input(&crate::types::InputEvent::Click { x: cx, y: cy });
            let success = click_result.success;
            format!(
                "{{\"success\":{},\"element\":\"{}\",\"role\":\"{}\",\"clicked_at\":[{:.0},{:.0}]{}}}",
                success,
                element_name.replace('"', "\\\""),
                el.role,
                cx, cy,
                if !success { format!(",\"error\":\"Click failed\"") } else { String::new() }
            )
        }
        None => {
            // List available elements for debugging
            let available: Vec<String> = snapshot.elements.iter()
                .filter_map(|el| {
                    el.title.as_ref()
                        .or(el.description.as_ref())
                        .map(|s| format!("{}({})", el.role, s))
                })
                .take(20)
                .collect();
            format!(
                "{{\"success\":false,\"error\":\"Element '{}' not found in AX tree ({} elements scanned)\",\"available\":[{}]}}",
                element_name.replace('"', "\\\""),
                snapshot.elements.len(),
                available.iter().map(|s| format!("\"{}\"", s.replace('"', "\\\""))).collect::<Vec<_>>().join(",")
            )
        }
    }
}
