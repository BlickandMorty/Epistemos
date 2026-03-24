// omega-ax: macOS accessibility tree walker, input simulation, and permission management.
// Provides the automation foundation for Epistemos Omega agent system.
// Separate from graph-engine (rendering) and epistemos-core (training).

pub mod types;
mod ax_ffi;
pub mod ax_tree;
pub mod permissions;
pub mod input;
pub mod shortcuts;

// Re-export types for UniFFI
pub use types::{PermissionState, PermissionStatus, AXTreeSnapshot, AutomationResult};

// Re-export free functions
pub use uniffi_exports::*;

mod uniffi_exports;

uniffi::include_scaffolding!("omega_ax");
