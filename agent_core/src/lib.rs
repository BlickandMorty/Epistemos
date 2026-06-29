pub mod a2ui;
pub mod acs_admission;
pub mod agent_loop;
pub mod agent_runtime;
pub mod agent_runtime_v2;
pub mod approval;
pub mod arena;
pub mod arenas;
pub mod artifacts;
pub mod auto_research;
pub mod bootstrap;
pub mod brain_export;
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
pub mod confidence_floor;
pub mod context_compiler;
pub mod context_loader;
pub mod deep_research;
pub mod dispatcher;
pub mod effect;
pub mod eidos;
pub mod error;
pub mod error_classifier;
pub mod etl;
pub mod evolution;
pub mod example_bank;
pub mod falsifier_artifacts;
pub mod format;
pub mod grammar;
pub mod heal;
pub mod helios;
pub mod hyperdynamic_loop;
pub mod lattice;
pub mod lattice_wbo;
pub mod lifecycle;
pub mod live_files;
#[cfg(feature = "lsp-runtime")]
pub mod lsp_runtime;
pub mod model_profile;
pub mod mutations;
pub mod neocortex;
pub mod nightbrain;
pub mod oplog;
pub mod oplog_lattice_wbo;
pub mod projection_cache;
pub mod prompt_caching;
pub mod prompts;
pub mod provenance;
pub mod provider;
pub mod reasoning_metrics;
/// P5.H A2/A3 — the EML re-rank POLICY core, promoted out of the research tree
/// (which is `#[cfg(feature="research")]`, default-OFF, never in the app) into
/// the always-compiled core. Only the scalar EML potential the re-rank needs is
/// here — NOT the full research `eml` IR machinery (which stays research-gated),
/// so the MAS binary stays lean.
pub mod eml_rerank;
#[cfg(feature = "research")]
pub mod research;
pub mod resonance;
pub mod resources;
pub mod retrieval;
pub mod tamagotchi;
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
pub mod tri_fusion;
pub mod types;
pub mod uas;
pub mod util;
pub mod variant_ladder;
pub mod vault_registry;
pub mod wbo6;

#[cfg(feature = "pro-build")]
pub mod pty;

pub mod providers {
    pub mod claude;
    pub mod gemini;
    // Pro-only: the on-device GGUF provider shells out to a hardened `llama-cli`
    // subprocess, which the MAS sandbox forbids. Invisible to MAS compilation.
    #[cfg(feature = "pro-build")]
    pub mod gguf_cli;
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
    pub mod f_vault_recall_50_fixture;
    pub mod f_vault_recall_runner;
    pub mod f_vault_recall_synthetic_seed;
    pub mod hyperbolic_topology;
    pub mod memory_classifier;
    pub mod memory_decay;
    pub mod neural_cache;
    pub mod raw_thoughts;
    pub mod recipe_cache;
    pub mod retrieval_trace;
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

// Goose=WORK seam (R-GOOSE, Seam B) — isolated + inert; nothing in agent_loop /
// agent_runtime references it (GOOSE GUARDRAIL: Chat/Act unchanged).
pub mod work;

// WORK code-intelligence tools — ⚠️ REDUNDANT under Architecture C (OpenCode has a built-in
// LSP; re-eval owner 2026-06-21). Kept (not blind-deleted) pending the OpenCode runtime vendor,
// then removed; `lsp_runtime` stays for the native editors. Gated behind `lsp-runtime`; isolated.
#[cfg(feature = "lsp-runtime")]
pub mod work_lsp_tools;

// RAG preflight tool selection (Deterministic Schema Engine, P8.2 spec §B): pick the
// ~3-5 tools relevant to a turn so local models keep a tight, focused tool footprint.
pub mod tool_preflight;

// Reasoning-token isolation (Deterministic Schema Engine, P8.2 spec §B): split a local
// model's preserved thinking trace from the clean answer (Rust-core / GGUF path).
pub mod reasoning_tokens;

// Schema validation gate for REPAIR (Deterministic Schema Engine, P8.2 spec §C.1):
// collect ALL violations of an emitted value vs its schema, for a model repair loop.
pub mod schema_validation;

// R-LITEPARSE seam (owner 2026-06-19): dedicated PDF→Markdown import via the
// run-llama/liteparse Rust core (Apache-2.0, in-process PDFium + Tesseract OCR, MAS-safe;
// Office/image subprocess formats OUT OF SCOPE). Always-compiled + INERT until vendored.
pub mod liteparse;

// AST quality gate (Deterministic Schema Engine, P8.2 spec §A): reject syntactically
// broken generated code (tree-sitter ERROR/MISSING) BEFORE any disk write. Gated behind
// `lsp-runtime` (reuses the LSP runtime's tree-sitter grammars — no new deps).
#[cfg(feature = "lsp-runtime")]
pub mod ast_quality_gate;

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
    pub mod browser_executable;
    #[cfg(feature = "pro-build")]
    pub mod browser_private;
    #[cfg(feature = "pro-build")]
    pub mod browser_redaction;
    #[cfg(feature = "pro-build")]
    pub mod browser_schema;
    #[cfg(feature = "pro-build")]
    pub mod browser_screenshot;
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
