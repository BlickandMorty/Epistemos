pub mod agent_loop;
pub mod approval;
pub mod arenas;
pub mod artifacts;
pub mod bridge;
pub mod channel_relay;
pub mod circuit_breaker;
pub mod command_center;
pub mod compaction;
pub mod context_compiler;
pub mod context_loader;
pub mod dispatcher;
pub mod error;
pub mod error_classifier;
pub mod etl;
pub mod evolution;
pub mod example_bank;
pub mod lattice;
pub mod mutations;
pub mod neocortex;
pub mod oplog;
pub mod prompt_caching;
pub mod prompts;
pub mod provenance;
pub mod provider;
pub mod reasoning_metrics;
pub mod resonance;
pub mod resources;
pub mod rope;
pub mod rope_handle;
pub mod routing;
pub mod runtime;
pub mod security;
pub mod session;
pub mod session_insights;
pub mod sketch;
pub mod skill_router;
pub mod sovereign;
pub mod types;
pub mod vault_registry;
pub mod wbo6;

#[cfg(not(feature = "mas-sandbox"))]
pub mod pty;

pub mod providers {
    pub mod claude;
    pub mod gemini;
    pub mod openai;
    pub mod openai_compatible;
    pub mod perplexity;
    pub mod schema;
}

pub mod storage {
    pub mod contradiction_detector;
    pub mod cross_propagation;
    pub mod diff_engine;
    pub mod hyperbolic_topology;
    pub mod memory_classifier;
    pub mod memory_decay;
    pub mod neural_cache;
    pub mod raw_thoughts;
    pub mod recipe_cache;
    pub mod session_graph;
    pub mod session_store;
    pub mod skills_registry;
    pub mod ssm_state;
    pub mod vault;
    pub mod vault_git;
}

pub mod shared_memory;
pub mod tirith;

pub mod mcp;

pub mod tools {
    pub mod channel_contacts;
    pub mod chunk_reduce;
    pub mod clarify;
    pub mod communication;
    pub mod file_ops;
    pub mod filesystem;
    pub mod graph;
    pub mod inference;
    pub mod knowledge;
    pub mod memory;
    pub mod registry;
    pub mod think;
    pub mod todo;
    pub mod web;
    pub mod web_fetch;
    pub mod workspace_search;

    #[cfg(not(feature = "mas-sandbox"))]
    pub mod apple;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod browser;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod cli_passthrough;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod computer_use;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod custom_tools;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod delegate_task;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod discovery;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod imessage;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod imessage_contacts;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod intelligence;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod macos;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod media;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod scheduling;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod skills;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod stdio_mcp;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod terminal;
    #[cfg(not(feature = "mas-sandbox"))]
    pub mod trajectory;
}

#[cfg(test)]
pub(crate) mod test_support {
    use std::sync::{Mutex, MutexGuard, OnceLock};

    /// Serializes tests that mutate process-wide environment variables.
    /// Rust's default parallel test runner otherwise lets one test remove
    /// an API key while another is constructing an env-dependent registry.
    pub(crate) fn env_lock() -> MutexGuard<'static, ()> {
        static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        LOCK.get_or_init(|| Mutex::new(()))
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
    }
}

uniffi::setup_scaffolding!();
