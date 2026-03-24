// omega-mcp: MCP tool registry, execution logger, and protocol types.
// Provides the tool infrastructure for Epistemos Omega agent system.
// Separate from graph-engine (rendering) and epistemos-core (training).

pub mod types;
pub mod registry;
pub mod logger;
pub mod server;
pub mod dispatcher;
pub mod state;
pub mod config;
pub mod recipe;
pub mod trace_logger;
pub mod dataset_formatter;
pub mod quality_filter;

// Re-export types for UniFFI
pub use types::{ToolDefinition, ToolResult, ToolCall, ExecutionRecord, SafetyInfo};
pub use registry::ToolRegistryError;
pub use dispatcher::MCPDispatcher;

// Re-export free functions
pub use uniffi_exports::*;

mod uniffi_exports;

uniffi::include_scaffolding!("omega_mcp");
