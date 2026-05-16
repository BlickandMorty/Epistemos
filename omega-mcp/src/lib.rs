// omega-mcp: MCP tool registry, execution logger, and protocol types.
// Provides the tool infrastructure for Epistemos Omega agent system.
// Separate from graph-engine (rendering) and epistemos-core (training).

pub mod arena;
pub mod catalog;
pub mod config;
pub mod dataset_formatter;
pub mod dispatcher;
#[cfg(not(feature = "mas-sandbox"))]
pub mod git;
pub mod github;
pub mod graph_search_backend;
pub mod graph_tools;
pub mod logger;
pub mod memory;
pub mod moa;
pub mod orchestrator;
#[cfg(not(feature = "mas-sandbox"))]
pub mod osascript;
#[cfg(not(feature = "mas-sandbox"))]
pub mod pty;
pub mod quality_filter;
pub mod recipe;
pub mod registry;
pub mod server;
pub mod state;
#[cfg(not(feature = "mas-sandbox"))]
pub(crate) mod subprocess;
pub mod trace_logger;
pub mod transport;
pub mod types;
pub mod vault;
pub mod web_search;

// Re-export types for UniFFI
pub use dispatcher::MCPDispatcher;
pub use registry::ToolRegistryError;
pub use types::{ExecutionRecord, SafetyInfo, ToolCall, ToolDefinition, ToolResult};

// Re-export free functions
pub use uniffi_exports::*;

mod uniffi_exports;

uniffi::include_scaffolding!("omega_mcp");
