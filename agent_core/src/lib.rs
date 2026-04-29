pub mod agent_loop;
pub mod audit;
pub mod bridge;
pub mod compaction;
pub mod companions;
pub mod context_compiler;
pub mod digest;
pub mod event_log;
pub mod events;
pub mod ffi;
pub mod normalize;
pub mod context_loader;
pub mod dispatcher;
pub mod error;
pub mod error_classifier;
pub mod evolution;
pub mod example_bank;
pub mod neocortex;
pub mod perf;
pub mod prompt_caching;
pub mod prompts;
pub mod provider;
pub mod replay;
pub mod pty;
pub mod reasoning_metrics;
pub mod routing;
pub mod security;
pub mod session;
pub mod simulation;
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

pub mod mcp;

pub mod tools {
    pub mod apple;
    pub mod browser;
    pub mod chunk_reduce;
    pub mod clarify;
    pub mod communication;
    pub mod computer_use;
    pub mod delegate_task;
    pub mod discovery;
    pub mod file_ops;
    pub mod filesystem;
    pub mod graph;
    pub mod imessage;
    pub mod imessage_contacts;
    pub mod inference;
    pub mod intelligence;
    pub mod knowledge;
    pub mod macos;
    pub mod media;
    pub mod memory;
    pub mod registry;
    pub mod scheduling;
    pub mod skills;
    pub mod terminal;
    pub mod think;
    pub mod todo;
    pub mod trajectory;
    pub mod web;
    pub mod web_fetch;
    pub mod workspace_search;
}

uniffi::setup_scaffolding!();
