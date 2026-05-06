// omega-ax: macOS accessibility tree walker, input simulation, and permission management.
// Provides the automation foundation for Epistemos Omega agent system.
// Separate from graph-engine (rendering) and epistemos-core (training).

mod ax_ffi;
pub mod ax_tree;
pub mod input;
pub mod permissions;
pub mod shortcuts;
pub mod types;

// Re-export types for UniFFI
pub use types::{AXTreeSnapshot, AutomationResult, PermissionState, PermissionStatus};

// Re-export free functions
pub use uniffi_exports::*;

mod uniffi_exports;

uniffi::include_scaffolding!("omega_ax");
