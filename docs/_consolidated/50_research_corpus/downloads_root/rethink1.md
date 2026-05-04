# Epistemos Agent + Model Research — Phase I Deep Technical Analysis

## Executive Summary

This report analyzes four agent repositories and four model families for Epistemos's Phase I migration: eliminating the Python Hermes Agent subprocess and replacing it with a pure Rust agent runtime embedded in the Swift + Rust + Metal application. The verdict is clear — **Goose is the dominant clone target**; Hermes Self-Evolution provides the offline optimization algorithm; SciAgent-Skills provides 196 ready-made skill files for ⌘R research; and OpenHarness, while clever, is TypeScript-only and too far from the Rust/FFI stack to be directly integrated. On the model side, **Gemma 4 26B-A4B** with Unsloth Dynamic 2.0 quantization emerges as the ideal local inference target for Epistemos's M2 Pro 18GB constraint.

***

## Section 1: Agent Framework Verdicts

### 1.1 Block Goose — **CLONE**

| Attribute | Detail |
|-----------|--------|
| Language | 58% Rust, 34% TypeScript (CLI/UI only) |
| License | Apache-2.0 |
| Stars | 29,400+ (as of April 2026)[^1] |
| Release | v1.25.0 (Feb 2026) with macOS sandbox[^2] |
| Integration Difficulty | **2–3 weeks** (provider trait + agent loop + MCP crate) |

**Clone / Take From:**
The core Rust crates are a near-perfect foundation for Epistemos's `agent_core`. The architecture separates concerns cleanly — providers, tools, session, inspection, and MCP are all independent crates. The `crates/goose/` library can be added as a Cargo dependency with features disabled, and the relevant modules extracted verbatim under Apache-2.0 (compatible with Epistemos's commercial use).[^3]

**Specific files to clone directly:**
- `crates/goose/src/providers/base.rs` — `Provider` trait (38KB, most important file)
- `crates/goose/src/providers/anthropic.rs` — complete Anthropic implementation
- `crates/goose/src/providers/openai.rs` — complete OpenAI implementation
- `crates/goose/src/providers/gcpvertexai.rs` + `gcpauth.rs` + `oauth.rs` — Google OAuth chain
- `crates/goose/src/providers/retry.rs` — retry logic with exponential backoff
- `crates/goose/src/providers/errors.rs` — `ProviderError` enum
- `crates/goose/src/providers/utils.rs` + `formats/` — message format normalization
- `crates/goose/src/agents/agent.rs` — full agent loop (`reply_internal()`)
- `crates/goose/src/agents/extension_manager.rs` — builtin vs stdio dispatch
- `crates/goose/src/tool_inspection/` — security, egress, adversary, repetition inspectors
- `crates/goose/src/context_mgmt/` — compaction threshold, `compact_messages()`
- `crates/goose/src/session_manager/` — SQLite session persistence
- `crates/goose-mcp/src/` — entire crate; rename to `epistemos-mcp`

**Skip from Goose:**
- `crates/goose/src/providers/local_inference.rs` + `local_inference/` — Epistemos uses MLX-Swift, not llama-cpp-2 or candle
- `crates/goose/src/providers/bedrock.rs`, `sagemaker_tgi.rs` — AWS-specific
- `crates/goose-cli/` — Epistemos is a macOS GUI app, not a CLI
- `crates/goose-server/` — Epistemos uses zero-copy IPC, not HTTP
- `feature = "aws-providers"`, `feature = "otel"`, `feature = "telemetry"`

**License implications:** Apache-2.0 is compatible with commercial distribution. Attribution is required — add `NOTICE` file. No copyleft obligations. The Darwinian Evolver used by Hermes self-evolution is AGPL; do NOT link to it, only invoke as an external CLI subprocess if needed.

**Cloud compatibility:** YES. The `Provider` trait is explicitly designed for cloud. Goose has full production implementations of Anthropic, OpenAI, Google (GCP Vertex AI + OAuth), GitHub Copilot, Databricks, Azure, Azure AD, Snowflake, OpenRouter, and LiteLLM — covering every cloud backend Epistemos already supports. The `gcpauth.rs` module handles the full Google OAuth2 PKCE flow that Epistemos currently runs in Swift; this can move to Rust via UniFFI.[^4]

***

### 1.2 OpenHarness — **STUDY** (patterns only, do not clone)

| Attribute | Detail |
|-----------|--------|
| Language | TypeScript, Node 18+, React + Ink UI |
| License | MIT |
| Status | Alpha |
| Integration Difficulty | **N/A — TypeScript, not FFI-compatible** |

OpenHarness is a terminal-based coding agent built with React + Ink, functionally similar to Claude Code but provider-agnostic. It is a well-structured ~1K-line codebase, not a library — it cannot be embedded into Rust via UniFFI. However, three patterns are worth adapting directly into Epistemos's Rust tool layer:

1. **Tool risk classification**: OpenHarness assigns every tool a `low/medium/high` risk level that maps directly to auto-approve/ask/deny behavior. Epistemos's 50+ tools would benefit from this granular permission model.
2. **Zod-style schema approach**: Each tool declares a Zod input schema for runtime validation. The Rust equivalent — using `serde_json::Value` validated against a JSON Schema — should be added to every builtin extension in `epistemos-mcp`.
3. **Headless JSON mode (`oh run --json`)**: The pattern of a machine-readable output path that pipes structured results is valuable for Epistemos's cron/automation triggers.

The comparison table OpenHarness publishes shows it has 18 tools vs Claude Code's 40+, which is useful calibration for Epistemos's 50+ tool target.

***

### 1.3 Hermes Agent Self-Evolution — **STUDY + PORT ALGORITHM**

| Attribute | Detail |
|-----------|--------|
| Language | Python (pyproject.toml) |
| License | MIT |
| Algorithm | DSPy + GEPA (Genetic-Pareto Prompt Evolution) |
| GPU required | No — API-call based, ~$2–10/run |
| Relationship to hermes-agent | Offline optimizer that generates PRs against the main repo |

This is a **research/tooling repo**, not a runtime library. It cannot be embedded. What matters is the algorithm, which is straightforwardly portable to Rust.

**How the learning loop works:**
1. Read current skill/prompt/tool description from the repo
2. Generate an eval dataset (synthetic or from real session history via `--eval-source sessiondb`)
3. GEPA reads execution traces to understand *why* specific steps failed — not just binary pass/fail
4. Propose N targeted mutations (text-level changes to prompts, skill descriptions, tool descriptions)
5. Evaluate each mutation, build a Pareto front (quality vs. size tradeoff)
6. Constraint gates: full test suite, size limits (skills ≤15KB, tool descriptions ≤500 chars), semantic preservation
7. Open a PR with the winning variant for human review

**Phases implemented:**
- Phase 1 ✅ SKILL.md files (live)
- Phase 2–5 (tool descriptions, system prompt, tool code, continuous loop) — planned

**Mapping to Epistemos's Living Vault:** The Living Vault's nightly loop (diff engine + memory classifier + QLoRA fine-tuning) is the **runtime** self-improvement mechanism. Self-evolution is the **offline** optimizer. They are complementary, not competing:

| Epistemos System | Hermes System | Analogy |
|-----------------|---------------|---------|
| Living Vault nightly QLoRA | (no equivalent) | Weight updates |
| Optimization loop | GEPA + DSPy | Prompt/skill evolution |
| Memory classifier ADD/UPDATE/DELETE | (no equivalent) | Knowledge management |
| Ebbinghaus decay | (no equivalent) | Forgetting curve |

**Port to Rust:** The mutation-evaluation-selection loop is pure algorithm logic. A Rust port is straightforward:
```rust
// Pseudo-Rust sketch
async fn evolve_skill(skill: &SkillFile, traces: &[ExecutionTrace]) -> SkillFile {
    let candidates = gepa_mutate(skill, traces, N_MUTATIONS).await;
    let evaluated = futures::join_all(candidates.iter().map(|c| evaluate(c))).await;
    pareto_select(evaluated)
}
```
The expensive part (LLM calls for mutation) is provider-agnostic and maps directly to Epistemos's `Provider` trait. This becomes a nightly job in the Epistemos cron system.

***

### 1.4 SciAgent-Skills — **TAKE FROM (selectively)**

| Attribute | Detail |
|-----------|--------|
| Language | Markdown (no runtime deps) |
| License | CC-BY-4.0 |
| Skills | 196 across 11 categories |
| Format | SKILL.md files with registry.yaml index |

This is the cleanest grab: zero runtime dependencies, pure markdown, Claude Code plugin format. The skills load into any agent that reads markdown, including Hermes-compatible agents.

**Take for Epistemos ⌘R (one-click research):**
- `genomics-bioinformatics/pubmed-search` — PubMed/NCBI API queries
- `genomics-bioinformatics/gget` — gene/protein lookup tool
- `scientific-computing/` — Polars, NetworkX, SymPy, UMAP (14+ skills)
- `scientific-writing/` — manuscript drafting, peer review templates, LaTeX guides (21 skills)
- `biostatistics/` — PyMC Bayesian modeling, SHAP, survival analysis (12 skills)

**Skip:**
- `lab-automation/` (Opentrons, Benchling) — not relevant to PKM
- `structural-biology-drug-discovery/` (AutoDock Vina, ChEMBL) — too domain-specific for a general PKM user

**Integration path:** Convert selected SKILL.md files to the Hermes skill format, compile them as resources in `epistemos-mcp` as a builtin `ResearchExtension`. The `registry.yaml` index becomes Epistemos's skill discovery manifest.

***

## Section 2: Goose Deep Dive

### 2.1 Complete Crate Architecture

```
block/goose/
├── crates/
│   ├── goose/                  ← CORE LIBRARY (clone this)
│   │   └── src/
│   │       ├── providers/      ← Provider trait + 30+ implementations
│   │       │   ├── base.rs     ← Provider + ProviderDef traits (38KB)
│   │       │   ├── anthropic.rs, openai.rs, gcpvertexai.rs, ...
│   │       │   ├── oauth.rs    ← Full OAuth2 PKCE flow
│   │       │   ├── toolshim.rs ← Tool-calling shim for non-tool models
│   │       │   ├── retry.rs    ← Exponential backoff, jitter
│   │       │   └── formats/    ← OpenAI/Anthropic/Google message formats
│   │       ├── agents/
│   │       │   ├── agent.rs    ← Agent struct + reply_internal() loop
│   │       │   └── extension_manager.rs
│   │       ├── tool_inspection/
│   │       │   ├── security_inspector.rs
│   │       │   ├── egress_inspector.rs
│   │       │   ├── adversary_inspector.rs  ← LLM-based inspection
│   │       │   ├── permission_inspector.rs
│   │       │   └── repetition_inspector.rs
│   │       ├── context_mgmt/   ← Compaction + summarization
│   │       └── session_manager/ ← SQLite-backed session storage
│   ├── goose-mcp/              ← BUILTIN EXTENSIONS (clone this)
│   │   └── src/
│   │       ├── lib.rs          ← Extension registry
│   │       ├── subprocess.rs   ← stdio MCP subprocess management
│   │       ├── computercontroller/ ← Screen/input control
│   │       ├── memory/         ← In-session memory
│   │       ├── peekaboo/       ← File inspection tools
│   │       ├── autovisualiser/ ← Chart generation
│   │       └── tutorial/       ← Onboarding flows
│   ├── goose-sdk/              ← External SDK (skip)
│   ├── goose-cli/              ← CLI binary (skip)
│   ├── goose-server/           ← HTTP server (skip)
│   └── goose-acp/              ← Agent Communication Protocol (study)
```

### 2.2 Provider Trait — Deep Analysis

The `Provider` trait defined in `base.rs` at line 456 is the most important single file for Epistemos:[^4]

```rust
#[async_trait]
pub trait Provider: Send + Sync {
    fn get_name(&self) -> &str;
    async fn stream(
        &self,
        model_config: &ModelConfig,
        session_id: &str,
        system: &str,
        messages: &[Message],
        tools: &[Tool],
    ) -> Result<MessageStream, ProviderError>;
    fn get_model_config(&self) -> ModelConfig;
    async fn complete(...) -> Result<(Message, ProviderUsage), ProviderError>;
    // + retry_config(), supports_embeddings(), configure_oauth(),
    //   refresh_credentials(), permission_routing(), etc.
}
```

The `ProviderDef` trait is a static factory that adds `metadata()` (name, description, models, config keys) and `from_env()` (async constructor from env vars). This two-trait pattern cleanly separates the runtime object (`Provider`) from the registration/discovery mechanism (`ProviderDef`).[^4]

**Mapping to Epistemos's existing cloud backends:**

| Epistemos Current | Goose Provider File | OAuth handled in |
|------------------|--------------------|--------------------|
| OpenAI (OAuth) | `openai.rs` | `oauth.rs` PKCE flow |
| Google (OAuth) | `gcpvertexai.rs` | `gcpauth.rs` + `gcpvertexai.rs` |
| Anthropic (API key) | `anthropic.rs` | env var, no OAuth |
| MLX-Swift (local) | **NEW: `mlx_swift.rs`** | UniFFI call into Swift |

The Google OAuth implementation in `gcpauth.rs` is a complete, production-grade OAuth2 refresh-token manager (39KB) — directly applicable to Epistemos's existing Google OAuth.

**Thinking block handling:** Goose filters `MessageContent::Thinking` and echoes it back verbatim for Gemini, Kimi, and DeepSeek extended thinking. The pattern should be extended for Anthropic's `extended_thinking` parameter when it's passed through the context compiler.

### 2.3 Agent Loop — `reply_internal()` Flow

The agent loop in `agent.rs` runs for up to 1,000 turns with:
1. **Cancellation token** — `CancellationToken` from Tokio, checked at each turn
2. **Tool dispatch** — Tools split into `frontend_tools` (routed to Swift UI layer) and `backend_tools` (handled in Rust)
3. **ContextLengthExceeded** handling — compaction is triggered automatically, messages are summarized, conversation is replaced with a `HistoryReplaced` event
4. **Retry** — `RetryConfig { max_retries: 3, initial_delay_ms: 1000, max_delay_ms: 10000, retry_on_statuses: [429, 500, 502, 503, 504] }`[^4]

**Comparison to Epistemos's `agent_loop.rs`:**
- Goose's loop is more mature — it handles the `Frontend` tool category cleanly, which maps directly to Epistemos's Swift-side UI tools (vault navigation, graph manipulation)
- Goose's compaction is threshold-based; Epistemos can set this to match its cache-optimal context window sizes
- The `SessionManager` with SQLite persistence can replace Epistemos's current in-memory session state

### 2.4 MCP Crate Analysis

The `goose-mcp` crate uses `rmcp` (Rust MCP client/server, MIT license) as its underlying protocol implementation. The crate provides:

- `subprocess.rs` — manages `stdio` MCP processes (spawns external processes, manages their stdin/stdout pipes, reconnects on failure)
- `mcp_server_runner.rs` — runs goose-mcp tools as an MCP server
- Built-in tools: computer controller, memory, file inspection, auto-visualizer, tutorial

**Can it replace `epistemos_bridge.py` AND `EpistemosMCPClient/Server`?** Yes — completely. The replacement path:
1. `epistemos_bridge.py` → delete (Phase I goal)
2. `EpistemosMCPClient` (Swift) → replace with a UniFFI-bridged call into `epistemos-mcp` crate
3. `EpistemosMCPServer` (Swift) → keep for exposing Swift-side vault/graph tools as MCP endpoints to the Rust agent

### 2.5 Extension System

Goose v1.25.0 unified its subagent and Skills systems into a single "Summon" extension. The `ExtensionConfig` enum has three variants:[^2]

```rust
enum ExtensionConfig {
    Builtin { name: String },          // compiled into binary, zero IPC
    Stdio { command: String, args, env }, // external process via MCP stdio
    Frontend { name: String },          // Swift-side UI tool
}
```

**Mapping to Epistemos's 50+ tools:**

| Category | Count | Extension Type |
|----------|-------|---------------|
| File I/O (read, write, edit, glob, grep) | 7 | `Builtin` |
| Vault operations (wikilink, transclusion, graph) | 12 | `Frontend` → Swift |
| Memory classifier, diff engine | 4 | `Builtin` (Rust) |
| Web fetch, search | 3 | `Builtin` |
| Shell (bash, git) | 4 | `Builtin` |
| Cloud MCP bridges | 20+ | `Stdio` (external) |
| Research skills (⌘R) | 15+ | `Builtin` (skill runner) |

The `Builtin` type is **zero IPC** — the extension runs inside the agent binary with direct function calls. All 17 core coding/file tools should be `Builtin` extensions for maximum performance.

### 2.6 ToolInspectionManager

Five inspectors run in sequence before any tool is executed:
- `SecurityInspector` — blocks shell injection patterns, path traversal
- `EgressInspector` — checks outgoing network calls against an allowlist
- `AdversaryInspector` — **LLM-based** inspection that detects prompt injection in tool results
- `PermissionInspector` — maps to Epistemos's 3-tier power management (Full/Eco/LowPower)
- `RepetitionInspector` — detects tool loops (same tool called >N times with similar args)

The `AdversaryInspector` is the most novel — it uses a secondary, smaller model call to check if a tool's output contains instructions attempting to hijack the agent. This is directly applicable to Epistemos when processing external web content or untrusted vault files.

### 2.7 Binary Size Estimate

Using Cargo release profile with `opt-level = "z"`, `lto = true`, `strip = true`, `codegen-units = 1`:[^5]

| Component | Size (stripped, macOS ARM64) |
|-----------|------------------------------|
| `goose` core (no local-inference, no AWS, no otel) | ~12–18 MB |
| `goose-mcp` (builtin extensions) | ~3–5 MB |
| `epistemos` tools (50+ tools compiled in) | ~2–4 MB |
| SQLite (via sqlx static) | ~2–3 MB |
| **Total estimate** | **~19–30 MB** |

This is above Epistemos's stated 5–15 MB target. Reaching sub-15 MB requires:
1. Replacing `sqlx` with a lighter SQLite binding (e.g., `rusqlite` with `bundled-sqlcipher`)
2. Disabling all providers not needed at compile time via Cargo features
3. Using `cargo bloat --release --crates` to identify the top binary contributors[^6]
4. Potentially splitting into a dylib loaded at runtime (which also enables updates without full app re-release)

***

## Section 3: Model Recommendations

### 3.1 Gemma 4 Family — Architecture Overview

Released April 1, 2026, Gemma 4 ships four variants:[^7][^8]

| Model | Params | Active Params | Architecture | Context | RAM (4bit) |
|-------|--------|--------------|-------------|---------|------------|
| Gemma 4 E2B | 2B | 2B | Dense, multimodal | 128K | ~1.2 GB |
| Gemma 4 E4B | 4B | 4B | Dense, multimodal | 128K | ~2.5 GB |
| Gemma 4 26B-A4B | 26B | 4B active | MoE, multimodal | 256K | ~5–6 GB |
| Gemma 4 31B | 31B | 31B | Dense, multimodal | 256K | ~15–16 GB |

Benchmark results from Artificial Analysis:[^9]

| Model | GPQA Diamond | MMLU-Pro | LCB (coding) |
|-------|-------------|----------|--------------|
| Gemma 4 31B | 85.7% | 85.2% | 80.0% |
| Gemma 4 26B-A4B | 79.2% | 82.6% | 77.1% |
| Qwen3.5 9B (Reasoning) | 80.6% | — | — |

The 26B-A4B uses only ~4B parameters per forward pass, giving it near-4B inference cost but approaching 31B reasoning quality.[^10][^11]

### 3.2 Inference Speed on Apple Silicon

On M5 MAX (48GB), Gemma 4 26B-A4B Q4 achieves **40–43 tok/s**. On M2 Pro 18GB, expect approximately 20–30 tok/s given the lower memory bandwidth. For comparison, M5 MAX achieved 81 tok/s average for the same model.[^12][^13]

The MLX community collection (`mlx-community/gemma-4-26b-a4b-4bit`) provides the native MLX format for direct use with MLX-Swift — no conversion needed.

### 3.3 Router Model (always pinned, <3 GB)

**Winner: Gemma 4 E4B (4B dense) — mlx-community 4bit**

- Memory: ~2.5 GB (pinned resident, never evicted)
- Speed: ~80–100 tok/s on M2 Pro 18GB (dense 4B benefits from Metal compute throughput)
- Use: intent classification, routing depth estimation, fast inline completions
- Advantage over Qwen: native multimodal input means vault images feed directly into routing decisions without a separate vision model

### 3.4 Reasoner/Coder Model (cold-loaded, 5–8 GB)

**Winner: Gemma 4 26B-A4B — Unsloth UD-Q4_K_M GGUF (or mlx-community 4bit)**

- Memory: ~5.5 GB at UD-Q4_K_M[^14]
- Speed: estimated 25–35 tok/s on M2 Pro 18GB
- Quality: 82.6% MMLU-Pro, 79.2% GPQA — competitive with models 3x larger[^9]
- Context: 256K — matches Epistemos's long vault document needs
- Advantage: **26B knowledge base at 4B compute cost** is the ideal tradeoff for a PKM reasoner
- MLX path: `mlx-community/gemma-4-26b-a4b-4bit` for fastest Apple Silicon inference
- GGUF path: `unsloth/gemma-4-26B-A4B-it-GGUF` → `UD-Q4_K_M` (~5.5 GB) for llama.cpp integration[^14]

### 3.5 Agent/Tool-Calling Model

**Winner: Qwopus 3.5 27B v3 TQ3_4S (for heavy tool sessions) / Gemma 4 26B-A4B (default)**

**What is Qwopus?** A distillation of Qwen 3.5 27B's weights on Claude 4.6 Opus reasoning traces — it combines Qwen's strong tool-calling infrastructure with Opus-style chain-of-thought. Think of it as Qwen 3.5 27B's architecture with Claude Opus's reasoning patterns baked in via synthetic distillation.[^15][^16]

**TQ3_4S quantization:** A custom 3-bit format with 4-block sub-grouping, similar to IQ3_XS but with per-block calibration scaling. Effective bit-width is ~3.4 bits. Memory footprint: ~8–10 GB on M2 Pro 18GB (fits with the E4B router resident).

- MLX compatibility: **GGUF only** — requires llama.cpp inference or conversion to safetensors first
- Quality vs Qwen 3.5 9B: community consensus is that it matches 9B quality at 27B depth with Claude-style structured outputs
- Best use case: multi-step tool-calling sessions where JSON reliability matters more than raw speed

For the **default** agent model, use Gemma 4 26B-A4B via MLX-Swift (native integration). For sessions that specifically need Opus-style chain-of-thought, hot-swap to Qwopus TQ3_4S via llama.cpp.

***

## Section 4: TurboQuant and Quantization Analysis

### 4.1 What Is TurboQuant?

"TurboQuant" is Unsloth's marketing name for their Dynamic 2.0 GGUF pipeline. It is not a new quantization *format* but a new *calibration and assignment strategy*:[^17][^18]

1. **Calibration dataset** — Unsloth uses a 1.5M+ token curated dataset for imatrix computation (standard imatrix uses ~256K tokens)[^17]
2. **Per-tensor dynamic bit assignment** — analyzes each layer's weight distribution and assigns optimal bit-width (Q4_NL, Q5.1, Q5.0, Q4.1, Q4.0, or Q2_K_XL) rather than a fixed width[^18]
3. **Model-specific schemes** — the layers quantized in Gemma 4 differ significantly from those in Llama 4; no single recipe is applied universally[^17]
4. **QAT compatibility** — Dynamic 2.0 can now work on QAT (Quantization-Aware Training) checkpoints, not just post-training[^17]

### 4.2 Quantization Method Comparison

| Method | How It Works | Quality/Size Ratio | Apple Silicon |
|--------|-------------|-------------------|---------------|
| Standard GGUF Q4_K_M | Fixed 4-bit groups | Baseline | Via llama.cpp |
| Unsloth Dynamic 2.0 UD-Q4_K_M | Per-tensor calibrated, varied bits | **+2–5% quality vs Q4_K_M at same size** | Via llama.cpp or converted to MLX |
| MLX native 4bit | Group quantization, Metal-optimized | Comparable to Q4_K_M | **Native, fastest** |
| ButterflyQuant | Learned rotation + quantization | Better for extreme compression | Not mainstream yet |
| Epistemos Stateful Rotor | Per-tensor via rotation matrices | Similar to Dynamic 2.0 | Via MLX pipeline |

The Unsloth MLX port (via `lyn.one`) demonstrates that Dynamic 2.0's methodology can be applied using `mlx convert --q-recipe unsloth --imatrix-path imatrix.gguf`. This means Epistemos's existing Stateful Rotor pipeline can be upgraded to match Dynamic 2.0 quality by adding AWQ (Activation-Aware Weight Quantization) pre-scaling before the rotation step.[^19]

### 4.3 Best Quant for Epistemos's 18 GB M2 Pro

Priority order:
1. **MLX native 4bit from mlx-community** — zero-copy, Metal-optimized, best throughput for always-loaded models
2. **Unsloth UD-Q4_K_M GGUF** — for models without MLX community builds, best quality at minimum size
3. **Unsloth UD-IQ3_XS GGUF** — when fitting a second large model alongside the router is needed
4. **Standard Q4_K_M** — fallback only; always prefer Dynamic 2.0 when available

For Gemma 4 26B-A4B specifically: use `mlx-community/gemma-4-26b-a4b-4bit` as the primary path and `unsloth/gemma-4-26B-A4B-it-GGUF` → `UD-Q4_K_M` as the GGUF fallback.[^14]

***

## Section 5: Integration Roadmap — Updated Phase I Plan

### 5.1 Phase I Sprint Map

**Sprint 1: Provider Foundation (1 week)**
- Clone `crates/goose/src/providers/` → `agent_core/src/providers/`
- Disable: `local_inference`, `bedrock`, `sagemaker`, `codex`, `cursor_agent`
- Keep: `anthropic`, `openai`, `gcpvertexai`/`gcpauth`, `openai_compatible`, `retry`, `errors`, `utils`, `formats/`, `oauth`
- Add new provider: `mlx_swift.rs` — calls MLX-Swift via UniFFI for local inference
- Wire UniFFI bindings: `provider_call_stream()` → MLX-Swift's `generate()` async sequence

**Sprint 2: Agent Loop (1 week)**
- Clone `crates/goose/src/agents/agent.rs` → `agent_core/src/agent_loop.rs`
- Map `Frontend` tool category → Swift `ToolDispatch` protocol (vault/graph operations)
- Connect `SessionManager` to Epistemos's existing SQLite vault journal
- Implement `CancellationToken` integration with Swift's structured concurrency (`Task.cancel()`)
- Target: cold start <10 ms via lazy `Arc<Mutex<Option<Arc<dyn Provider>>>>` initialization

**Sprint 3: MCP Replacement (1 week)**
- Clone `crates/goose-mcp/` → `epistemos-mcp/`
- Delete `epistemos_bridge.py` — the Python subprocess
- Implement `EpistemosVaultExtension` as a `Builtin` extension: `vault_read`, `vault_write`, `vault_link`, `graph_query`, `memory_classify`
- Expose Swift-side graph/vault as MCP server endpoints via `mcp_server_runner.rs` pattern
- Wire existing 50+ tools through `ExtensionConfig::Builtin` (file I/O, search, memory, cron)

**Sprint 4: Tool Inspection + Security (3 days)**
- Clone `tool_inspection/` pipeline
- Configure `EgressInspector` with Epistemos's allowlist (vault domain, configured cloud endpoints)
- Tune `RepetitionInspector` threshold for long vault sessions (higher than Goose default)
- Add `AdversaryInspector` only when processing external web content (CPU cost: ~1 extra LLM call per web fetch)

**Sprint 5: Model + Skill Bundle (3 days)**
- Bundle `mlx-community/gemma-4-E4B-it-4bit` (~2.5 GB) as the default shipped router
- Offer `mlx-community/gemma-4-26b-a4b-4bit` as the downloadable reasoner
- Import SciAgent-Skills research subset (~15 selected SKILL.md files) as builtin `ResearchExtension`
- Register skills in `registry.yaml` → Epistemos skill discovery manifest

### 5.2 What to Port from Hermes Self-Evolution

Implement a `SkillEvolutionJob` in Epistemos's cron system that runs weekly (not nightly — expensive):

```rust
// Weekly cron: optimize Epistemos skill descriptions
SkillEvolutionJob {
    target: EvolutionTarget::SkillFiles,
    eval_source: EvalSource::SessionHistory { days: 7 },
    engine: Engine::GEPA { 
        mutations: 8,
        iterations: 5,
        pareto_objectives: [Quality, Size]
    },
    guardrails: Guardrails {
        max_skill_size_kb: 15,
        max_tool_desc_chars: 500,
        require_tests_pass: true,
        human_review_required: true,  // PR-style, not auto-apply
    }
}
```

This replaces the current "static skill files" model with one that continuously improves as Epistemos processes real user session traces. It does not require GPU — all evolution happens via cloud LLM API calls ($2–10/run).

### 5.3 Updated Binary Size Estimate

| Component | Size (stripped `opt-level = "z"`, ARM64) |
|-----------|------------------------------------------|
| `agent_core` (goose providers + loop + session) | ~12–18 MB |
| `epistemos-mcp` (50+ builtin tools) | ~4–6 MB |
| SQLite via `rusqlite` | ~2 MB |
| UniFFI bridge stubs | ~0.5 MB |
| **Total** | **~18–26 MB** |

This slightly exceeds the original 5–15 MB target. Options to meet the target:
1. Compile as a `cdylib` dylib (loaded at app launch) rather than a static library
2. Feature-flag each cloud provider (`--features anthropic,openai,google` only)
3. Move heavy deps (serde, tokio) to already-present Swift app bundle (tokio is ~2–3 MB of the estimate)

The 5–15 MB target is achievable for the **agent-only** binary (no providers compiled in, providers loaded as plugins at runtime). The full Phase I binary will realistically land at 20–25 MB.

### 5.4 Updated Performance Targets

| Metric | Original Target | Updated Estimate |
|--------|----------------|-----------------|
| Cold start | <10 ms | **<8 ms** (Rust init only; provider lazy-loaded) |
| First token (local, E4B router) | — | **<100 ms** (MLX-Swift, model already warm) |
| Tool dispatch overhead | — | **<1 ms** (Builtin zero-IPC path) |
| MCP subprocess spawn | — | **<50 ms** (Stdio extension cold start) |
| Agent loop turn overhead | — | **<5 ms** (excluding LLM call) |
| Context compaction | — | **<200 ms** (triggered at threshold) |

Zero-copy IPC via Apple Silicon UMA remains the primary advantage over any Python subprocess architecture — no serialization, no pipe overhead, no Python GIL contention.

### 5.5 Claude Code Pitch Summary

When presenting Phase I to Claude Code for implementation, frame it as follows:

> **Goal:** Replace `epistemos_bridge.py` subprocess + Python venv with a pure Rust `agent_core` crate. The implementation strategy is to adapt Goose's Apache-2.0 codebase: clone `providers/base.rs` (Provider trait), `agents/agent.rs` (loop), and the entire `goose-mcp` crate. Add one new provider `mlx_swift.rs` via UniFFI. Compile to a `cdylib` loaded by Swift at runtime. Target: 20–25 MB binary, <10 ms cold start, zero Python dependencies in the shipped app.
>
> **Files to generate:**
> - `agent_core/Cargo.toml` (features: anthropic, openai, google, mlx-local)
> - `agent_core/src/providers/mlx_swift.rs` (UniFFI bridge to Swift MLX)
> - `agent_core/src/providers/base.rs` (adapted from goose, drop local-inference)
> - `epistemos-mcp/src/extensions/vault.rs` (VaultExtension replacing bridge.py)
> - `UniFFI/agent_core.udl` (interface definition for Swift ↔ Rust calls)

---

## References

1. [Goose AI Agent by Block: Free Open-Source Local Coding Agent](https://www.paperclipped.de/en/blog/goose-block-open-source-ai-agent/) - Goose is Block's free, open-source AI agent with 29K+ GitHub stars. It runs locally, supports any LL...

2. [goose v1.25.0: Sandboxed, Streamlined, and More Secure](https://block.github.io/goose/blog/2026/02/23/goose-v1-25-0/) - goose v1.25.0 brings macOS sandboxing, a unified summon extension, rich MCP app UIs, agentic CLI upg...

3. [GitHub - block/goose: an open source, extensible AI agent that goes ...](https://github.com/block/goose) - goose is your on-machine AI agent, capable of automating complex development tasks from start to fin...

4. [Provider Interface - Goose - Mintlify](https://www.mintlify.com/block/goose/development/provider-interface) - Goose's provider system allows integration with any LLM service. This guide explains how to implemen...

5. [Making Rust binaries smaller by default | Hacker News](https://news.ycombinator.com/item?id=39112486) - Reducing the binary size is usually more important than performance (and often more important than m...

6. [What you found so far to reduce rust binary size? : r/learnrust - Reddit](https://www.reddit.com/r/learnrust/comments/1makqnr/what_you_found_so_far_to_reduce_rust_binary_size/) - I wanted to have prebuilt binaries for my GCP based cli tool, but I can't get it to have less than 7...

7. [[AINews] Gemma 4: The best small Multimodal Open Models ...](https://www.latent.space/p/ainews-gemma-4-the-best-small-multimodal) - Model lineup + key specs: Four sizes were announced—31B dense, 26B MoE (“A4B”, ~4B active), and two ...

8. [Gemma 4 models explained: E2B, E4B, 26B A4B, and 31B](https://ainewssilo.com/articles/gemma-4-models-explained-hardware-benchmarks) - That shows up in the benchmark table. On MMLU Pro, 26B A4B scores 82.6% versus 85.2% for 31B. On AIM...

9. [1.6M). Gemma 4 26B A4B (Reasoning) scores 79.2%, ahead of gpt ...](https://x.com/ArtificialAnlys/status/2039752013249212600) - Gemma 4 26B A4B (Reasoning) scores 79.2%, ahead of gpt-oss-120B (high, 76.2%) but behind Qwen3.5 9B ...

10. [Gemma 4 26B A4B - Modular](https://www.modular.com/models/gemma-4-26b-a4b-it) - Gemma 4 26B A4B is a Mixture-of-Experts (MoE) model with 26B total parameters but only 4B activated ...

11. [Gemma 4 31B and 26B A4B running on NVIDIA and AMD, SOTA on ...](https://www.reddit.com/r/LocalLLaMA/comments/1samjtz/gemma_4_31b_and_26b_a4b_running_on_nvidia_and_amd/) - Both models handle text, image, and video input natively with 256K context. Modular's inference engi...

12. [Gemma 4 26b a4b - MacBook Pro M5 MAX. Averaging around 81tok ...](https://www.reddit.com/r/LocalLLaMA/comments/1sb1rb9/gemma_4_26b_a4b_macbook_pro_m5_max_averaging/) - Assuming this is a GGUF because MLX support for Gemma 4 isn't in LM Studio yet, right?

13. [Gemma 4 Local Test | New Open LLM King? - YouTube](https://www.youtube.com/watch?v=_lXgq-U49Aw) - Performance gemma4 26b a4b quant 4, hardware 32gb ram and rx6700 12gb only getting 12.5 tok/sec. Com...

14. [gemma-4-26B-A4B-it-UD-Q4_K_M.gguf - Hugging Face](https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF/blob/main/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf) - This file is stored with Xet . It is too big to display, but you can still download it. Large File P...

15. [Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled - Reeboot](https://reeboot.fr/en/blog/qwen35-claude-opus-reasoning-distilled) - In tool-calling benchmarks across quantized Qwen3.5 models, only the 27B variant with Claude Opus di...

16. [Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-GGUF](https://huggingface.co/Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-GGUF) - Hardware usage remains unchanged: About 16.5 GB VRAM with Q4_K_M quantization; 29–35 tok/s generatio...

17. [Unsloth Dynamic 2.0 GGUFs](https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs) - Revamped Layer Selection for GGUFs + safetensors: Unsloth Dynamic 2.0 now selectively quantizes laye...

18. [Unsloth Dynamic v2.0 GGUF Quantization - UBOS.tech](https://ubos.tech/news/unsloth-dynamic-v2-0-gguf-quantization-breakthrough-accuracy%E2%80%91size-trade%E2%80%91off/) - Answer: Unsloth Dynamic v2.0 GGUFs provide a breakthrough quantization technique that keeps large‑la...

19. [Unsloth MLX: Bring Dynamic 2.0 Per-Tensor Quantization to Apple ...](https://lyn.one/unsloth-quantize-recipe) - Unsloth MLX: Bring Dynamic 2.0 Per-Tensor Quantization to Apple Silicon ... Notably, 7 snaps up to 8...

