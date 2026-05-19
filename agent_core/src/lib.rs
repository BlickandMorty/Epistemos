pub mod a2ui;
pub mod agent_loop;
pub mod agent_runtime;
pub mod approval;
pub mod arena;
pub mod auto_research;
pub mod arenas;
pub mod artifacts;
pub mod bootstrap;
pub mod bridge;
pub mod browser_engine;
pub mod cache;
pub mod canon;
#[cfg(feature = "pro-build")]
pub mod channel_relay;
#[cfg(feature = "pro-build")]
pub mod channels;
pub mod circuit_breaker;
pub mod cognitive_dag;
pub mod cognitive_weight;
pub mod command_center;
pub mod compaction;
pub mod context_compiler;
pub mod context_loader;
pub mod dispatcher;
pub mod effect;
pub mod error;
pub mod error_classifier;
pub mod etl;
pub mod evolution;
pub mod example_bank;
pub mod format;
pub mod brain_export;
pub mod grammar;
pub mod heal;
pub mod helios;
pub mod lattice;
pub mod lifecycle;
pub mod tamagotchi;
pub mod live_files;
#[cfg(feature = "lsp-runtime")]
pub mod lsp_runtime;
pub mod mutations;
pub mod neocortex;
pub mod nightbrain;
pub mod oplog;
pub mod projection_cache;
pub mod prompt_caching;
pub mod prompts;
pub mod provenance;
pub mod provider;
pub mod reasoning_metrics;
pub mod resonance;
pub mod resources;
#[cfg(feature = "research")]
pub mod research;
// HELIOS V5 W1 — SCOPE-Rex full surface module entry. Hosts AnswerPacket
// (W1), Residency Governor (W4), Semantic BTM V1.5 (W5), Active-Support
// Atlas (W6) sub-modules. The Core ring (τ + π + λ) lives in `resonance`.
pub mod rope;
pub mod rope_handle;
pub mod route;
pub mod routing;
pub mod runtime;
pub mod schemas;
pub mod scope_rex;
pub mod security;
pub mod session;
pub mod session_insights;
pub mod sketch;
pub mod skill_discovery;
pub mod skill_router;
pub mod sovereign;
pub mod tools_v2;
pub mod types;
pub mod util;
pub mod variant_ladder;
pub mod vault_registry;
pub mod wbo6;

#[cfg(feature = "pro-build")]
pub mod pty;

pub mod providers {
    pub mod claude;
    pub mod gemini;
    pub mod openai;
    pub mod openai_compatible;
    pub mod perplexity;
    pub mod pricing;
    pub mod schema;
    pub mod tool_names;
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
#[cfg(feature = "pro-build")]
pub mod tirith;
pub mod undo;

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
    pub mod note_tools;
    pub mod registry;
    pub mod think;
    pub mod todo;
    pub mod vault_search_ladder;
    pub mod web;
    pub mod web_fetch;
    pub mod workspace_search;

    #[cfg(feature = "pro-build")]
    pub mod apple;
    #[cfg(feature = "pro-build")]
    pub mod browser;
    #[cfg(feature = "pro-build")]
    pub mod cli_passthrough;
    #[cfg(feature = "pro-build")]
    pub mod computer_use;
    #[cfg(feature = "pro-build")]
    pub mod custom_tools;
    #[cfg(feature = "pro-build")]
    pub mod delegate_task;
    #[cfg(feature = "pro-build")]
    pub mod discovery;
    #[cfg(feature = "pro-build")]
    pub mod imessage;
    #[cfg(feature = "pro-build")]
    pub mod imessage_contacts;
    #[cfg(feature = "pro-build")]
    pub mod intelligence;
    #[cfg(feature = "pro-build")]
    pub mod macos;
    #[cfg(feature = "pro-build")]
    pub mod media;
    #[cfg(feature = "pro-build")]
    pub mod scheduling;
    pub mod skills;
    #[cfg(feature = "pro-build")]
    pub mod stdio_mcp;
    #[cfg(feature = "pro-build")]
    pub mod terminal;
    #[cfg(feature = "pro-build")]
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

    /// Serializes tests that mutate the process-local permission store.
    /// The store is OnceLock-backed and shared across modules, so module-local
    /// locks are not enough under Rust's parallel test runner.
    pub(crate) fn permission_store_lock() -> MutexGuard<'static, ()> {
        static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        LOCK.get_or_init(|| Mutex::new(()))
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
    }
}

uniffi::setup_scaffolding!();
