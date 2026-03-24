// Core types for the macOS accessibility and automation layer.

use serde::{Deserialize, Serialize};

/// A single element in the accessibility tree.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AXElement {
    pub role: String,
    pub title: Option<String>,
    pub value: Option<String>,
    pub description: Option<String>,
    pub position_x: f64,
    pub position_y: f64,
    pub size_width: f64,
    pub size_height: f64,
    pub is_interactive: bool,
    pub children_count: u32,
    /// Index into the flat element array for parent. -1 if root.
    pub parent_index: i32,
}

/// Flattened accessibility tree snapshot.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AXTreeSnapshot {
    pub elements: Vec<AXElement>,
    pub app_name: String,
    pub app_pid: i64,
    pub is_sparse: bool,
}

impl AXTreeSnapshot {
    /// Threshold for sparse detection (fewer than this many interactive elements = sparse).
    pub const SPARSE_THRESHOLD: usize = 5;

    pub fn interactive_count(&self) -> usize {
        self.elements.iter().filter(|e| e.is_interactive).count()
    }
}

/// Permission state for a macOS capability.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum PermissionState {
    Granted,
    Denied,
    Unknown,
}

/// Aggregated permission status for all capabilities the system needs.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PermissionStatus {
    pub accessibility: PermissionState,
    pub screen_recording: PermissionState,
    pub automation: PermissionState,
}

/// A simulated input event (keyboard or mouse).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum InputEvent {
    Click { x: f64, y: f64 },
    DoubleClick { x: f64, y: f64 },
    TypeText { text: String },
    KeyPress { key_code: u16, modifiers: u64 },
    MouseMove { x: f64, y: f64 },
}

/// Result of an automation action.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AutomationResult {
    pub success: bool,
    pub error: Option<String>,
    pub duration_ms: u64,
}
