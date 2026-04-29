pub mod agent_loop;
pub mod approval;
pub mod bootstrap;
pub mod bridge;
pub mod format;
pub mod grammar;
pub mod channel_relay;
pub mod command_center;
pub mod compaction;
pub mod context_compiler;
pub mod context_loader;
pub mod dispatcher;
pub mod error;
pub mod error_classifier;
pub mod evolution;
pub mod example_bank;
pub mod neocortex;
pub mod prompt_caching;
pub mod prompts;
pub mod provider;
pub mod pty;
pub mod reasoning_metrics;
pub mod routing;
pub mod security;
pub mod session;
pub mod skill_router;
pub mod types;
pub mod vault_registry;

pub mod providers {
    pub mod claude;
    pub mod gemini;
    pub mod openai;
    pub mod openai_compatible;
    pub mod perplexity;
}

pub mod storage {
    pub mod contradiction_detector;
    pub mod cross_propagation;
    pub mod diff_engine;
    pub mod hyperbolic_topology;
    pub mod memory_classifier;
    pub mod memory_decay;
    pub mod neural_cache;
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

pub mod tools;

uniffi::setup_scaffolding!();
