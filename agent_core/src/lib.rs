pub mod agent_loop;
pub mod bridge;
pub mod compaction;
pub mod context_compiler;
pub mod error;
pub mod example_bank;
pub mod prompt_caching;
pub mod prompts;
pub mod provider;
pub mod pty;
pub mod routing;
pub mod security;
pub mod session;
pub mod skill_router;
pub mod types;
pub mod vault_registry;

pub mod providers {
    pub mod claude;
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

pub mod tools {
    pub mod registry;
    pub mod think;
}

uniffi::setup_scaffolding!();
