pub mod agent_loop;
pub mod bridge;
pub mod compaction;
pub mod context_compiler;
pub mod error;
pub mod error_classifier;
pub mod example_bank;
pub mod process_registry;
pub mod prompt_caching;
pub mod prompts;
pub mod provider;
pub mod pty;
pub mod rate_limit_tracker;
pub mod routing;
pub mod security;
pub mod session;
pub mod skill_router;
pub mod title_generator;
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
    pub mod cross_propagation;
    pub mod diff_engine;
    pub mod memory_classifier;
    pub mod memory_decay;
    pub mod recipe_cache;
    pub mod vault;
    pub mod vault_git;
}

pub mod shared_memory;

pub mod mcp;

pub mod tools {
    pub mod chunk_reduce;
    pub mod computer_use;
    pub mod delegate_task;
    pub mod file_ops;
    pub mod memory;
    pub mod registry;
    pub mod skills;
    pub mod think;
    pub mod web_fetch;
    pub mod workspace_search;
    pub mod todo;
    pub mod clarify;
    pub mod code_execution;
    pub mod graph_query;
    pub mod note_tools;
}

uniffi::setup_scaffolding!();
