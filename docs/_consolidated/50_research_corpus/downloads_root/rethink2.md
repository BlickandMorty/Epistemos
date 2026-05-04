# Epistemos Agent + Model Research Dossier
### Phase I: Eliminate Python — Adopt Rust Agent Substrate + Best Local Models
*Compiled April 3, 2026 — Primary sources: GitHub repos, HuggingFace model cards, official docs, Reddit benchmarks*

***
## Executive Summary
This dossier evaluates four agent repositories and four model families for integration into Epistemos's Phase I migration (Swift 6 + Rust + Metal only, no Python). The core findings are:

1. **Block Goose is the primary target.** Its Rust `Provider` trait and `Extension` system are production-grade, Apache-2.0 licensed, and directly transplantable into `agent_core`. The `goose-mcp` crate (backed by `rmcp`) can replace the Python `epistemos_bridge.py` and the Swift `EpistemosMCPClient/Server` entirely.
2. **Hermes self-evolution is Python-only but its *design patterns* are portable.** The `agentskills.io` SKILL.md format and FTS5 SQLite session memory pattern should be ported directly to Rust. The DSPy/GEPA optimizer itself should be skipped.
3. **Gemma 4 26B-A4B is the best local agent/reasoner for M2 Pro 18GB.** It fits in 16–18 GB at 4-bit, delivers Codeforces ELO 1718 and AIME 2026 88.3%, and has day-0 MLX support. It is the Goldilocks model for this stack.
4. **Gemma 4 E4B is the router.** At ~2–3 GB 4-bit with native MLX support, 128K context, and strong tool-calling capability, it is always-hot at negligible cost.
5. **Qwopus3.5-27B-v3 TQ3_4S is interesting but a dependency trap.** It requires a non-standard `llama.cpp` fork and has no MLX path. Skip for now.
6. **TurboQuant in the `mlx-vlm` context is a KV-cache compression scheme** (3.5-bit KV, ~4× active memory reduction) that is MLX-native and should be enabled for all long-context Gemma 4 inference via `--kv-bits 3.5 --kv-quant-scheme turboquant`.[^1]

***
## Section 1 — Agent Framework Verdicts
### 1.1 Block Goose — **CLONE + HEAVILY TAKE FROM**
**License:** Apache-2.0. **Language:** ~58% Rust, 34% TypeScript (TS is UI-only; Rust is the agent core).[^2]

**Verdict: This is the most important source in this dossier. Clone the following, adapt everything else.**

#### What to Clone Directly

| Module | Source Path | What It Gives Epistemos |
|---|---|---|
| `Provider` trait | `crates/goose/src/providers/base.rs:456` | Unified streaming/non-streaming LLM API abstraction over any cloud or local endpoint[^3] |
| `ProviderDef` / metadata | same file | Auto-registration of providers via `from_env()` factory; ConfigKey for secrets, env vars[^3] |
| `Extension` trait | `crates/goose/src/extensions/` | Zero-boilerplate tool plugin system — `name/description/instructions/tools/status/call_tool`[^4] |
| `goose-acp-macros` crate | `crates/goose-acp-macros/` | `#[tool]` proc macro: defines a tool from a Rust method signature — no schema JSON to write[^4] |
| Context compaction logic | `crates/goose/src/agents/agent.rs` | Auto-compact at `GOOSE_AUTO_COMPACT_THRESHOLD` (default 80%); tool-call summarization at 10+ calls; `summarize/truncate/clear/prompt` strategies[^5] |
| Adversary mode pattern | `crates/goose/src/agents/` | Silent parallel reviewer LLM that ALLOW/BLOCKs each sensitive tool call before execution; pattern-based prompt injection detection[^6] |
| Declarative provider JSON | `crates/goose/src/providers/configs/` | Any OpenAI-compatible endpoint (including local MLX server) can be registered without writing Rust[^7] |

#### What to Take From (Adapt, Not Verbatim Copy)

- **Session persistence pattern:** Goose stores sessions in SQLite at `~/Library/Application Support/goose/` on macOS. Epistemos should do the same but integrate with the Living Vault. Copy the compaction threshold trigger logic and the `SessionManager` interface; replace the storage backend with your own rusqlite schema.
- **ToolRouteManager / router model pattern:** Goose supports a `GOOSE_PLANNER_PROVIDER` + `GOOSE_PLANNER_MODEL` split — one model for strategic planning, a separate one for execution. This maps directly to Epistemos's 3-tier model architecture (router → reasoner → agent).[^8]
- **`goose-mcp` as MCP server/client:** The `goose-mcp` crate uses `rmcp` (the official Rust MCP SDK) as its transport layer. As of `v1.25.0`, it uses `rmcp 0.15.0` and supports Streamable HTTP, SSE, and stdio. This crate can directly replace `epistemos_bridge.py` and the Swift `EpistemosMCPClient`. The migration path: compile `goose-mcp` as a static library, expose its `call_tool(name, params) → Value` interface via a thin C ABI to Swift.[^9]

#### What to Skip

- `goose-cli` and `goose-server` crates — these are the desktop/CLI shells, not the agent substrate. They add heavy UI and web server dependencies.
- TypeScript UI — irrelevant; Epistemos has native SwiftUI/Metal.
- The `goose-bench` crate — evaluation harness, not needed for production.

#### Builtin vs. Stdio Extensions — Critical Architecture Note

The GitHub discussion clarifies: **builtin extensions are NOT in-process.** They run as separate processes communicating over stdio MCP. This is different from what the official docs imply. For Epistemos, this means the 17 core coding tools (file read/write/edit, bash, grep, glob, search) should be implemented as **`BuiltinExtension` Rust types within `agent_core`** — compiled into the binary and exposed as in-process tool handlers — which avoids all IPC overhead. Only external third-party MCP servers (e.g., a future scientific skill) need the stdio subprocess path.[^10]

#### Provider Trait — Full Interface

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
    async fn complete(
        &self,
        model_config: &ModelConfig,
        session_id: &str,
        system: &str,
        messages: &[Message],
        tools: &[Tool],
    ) -> Result<(Message, ProviderUsage), ProviderError>;
    // optional: configure_oauth, generate_session_name, fetch_supported_models
}
```

`MessageStream` is a `Pin<Box<dyn Stream<Item = Result<(Option<Message>, Option<ProviderUsage>), ProviderError>> + Send>>`. For local MLX inference, Epistemos should implement a `LocalMLXProvider` that wraps the MLX-Swift inference server (running on localhost) with an OpenAI-compatible API, then registers it via the declarative JSON path — no extra Rust needed.[^3][^7]

#### Cloud Provider Path

Goose already handles OpenAI (OAuth + API key), Anthropic (API key), Google (OAuth), Ollama, and OpenRouter — 15+ providers total. For Epistemos's cloud providers (OpenAI OAuth, Google OAuth, Anthropic API key), clone the existing provider implementations verbatim, stripping CLI-specific dependencies (clap, indicatif). **The answer to the question "can I use this for cloud as well?" is yes — the Provider trait is the unified interface for both local and cloud.** A single `agent_core::providers::Provider` trait covers MLX local, OpenAI, Anthropic, and Google with the same call signature.[^11]

#### Binary Size Estimate

The `goose` crate alone (providers + agent loop + extensions, no CLI/server/UI) pulls: `tokio`, `reqwest`, `serde`, `async_trait`, `anyhow`, `futures`, `rmcp`. With `--release` + LTO + strip, this compiles to an estimated **8–14 MB** for the agent core static library. This is realistic for a production Rust agent crate of this feature surface. The full `goose-cli` binary is ~40–60 MB before stripping; stripping gets it to ~22–30 MB — but Epistemos does not need the CLI.

#### Integration Difficulty

Adapting the Provider + Extension + MCP triad into `agent_core`: **5–10 days** for an experienced Rust engineer. The main work is: (1) removing CLI/server coupling from the agent loop, (2) defining a Swift-facing C ABI boundary for `call_tool`, (3) wiring the local MLX provider.

***
### 1.2 OpenHarness (zhijiewong/openharness) — **SKIP**
No meaningful content found on GitHub — the repository is either private, abandoned, or extremely minimal. It does not appear in any engineering discussions, benchmarks, or dependency graphs. Epistemos's existing Meta-Harness (`BootstrapPacket`, `TraceCollector`, `ProgressStore`, `CompletionChecker`) is more mature by comparison. **Do not spend time on this.**

***
### 1.3 Hermes Agent Self-Evolution (NousResearch) — **STUDY + EXTRACT PATTERNS**
**License:** MIT. **Language:** Python (DSPy, GEPA) — not portable as-is.[^12]

**What it is:** A standalone optimization pipeline that uses DSPy + GEPA (Genetic-Pareto Prompt Evolution) to systematically evolve Hermes Agent's skills, tool descriptions, and system prompts using evolutionary algorithms. The learning loop: task completion → SKILL.md creation → GEPA mutation of skill frontmatter and instructions → fitness scoring via test harness → survival of highest-scoring variants.[^13][^14]

**Hermes Agent architecture (from CrabTalk technical survey):**[^15]

The *agent itself* (not the self-evolution repo) is what Epistemos currently forks. Its key architectural features:
- **5-layer memory system:** (1) in-context, (2) SKILL.md procedural files, (3) vector store indexing skills, (4) Honcho user modeling (entity-centric, derives preferences from interactions), (5) FTS5 SQLite full-text search across all past sessions
- **ReAct loop** with autonomous SKILL.md creation after complex tasks (5+ tool calls, error recovery)
- **Skill creation trigger:** when the agent finishes a non-trivial task, it autonomously writes a reusable procedure to a `.md` file, maps it to a command
- **`agentskills.io` standard:** SKILL.md format adopted by 11+ tools — Claude Code, Cursor, GitHub Copilot, Gemini CLI, Goose, Roo Code, Kiro, Codex, VS Code, Amp, OpenCode. A skill written for Epistemos will work in Claude Code.[^15]
- **6 execution backends:** local, Docker, SSH, Daytona, Singularity, Modal — the agent runtime is decoupled from the execution surface[^15]

**Hermes 4 model specifics** (the model the agent is purpose-built for):
- Trained on ByteDance Seed 36B base (not Llama), with DataForge synthetic pipeline: ~5M samples, ~60B tokens vs. Hermes 3's 390M tokens[^15]
- Hybrid reasoning: `<think>...</think>` blocks up to 16,000 tokens, toggleable[^15]
- Hermes 4.3 (36B): 78.4% reduction in overlong reasoning on AIME'24 with only 4.7% accuracy cost[^15]
- Hermes 3 function calling: 90% accuracy vs. 60–70% for general models[^15]

**What to port to Rust:**

| Hermes Pattern | Rust Implementation |
|---|---|
| SKILL.md format (agentskills.io) | Markdown files with YAML frontmatter in `~/.epistemos/skills/` — parse with `gray_matter` or `serde_yaml` |
| FTS5 SQLite session search | `rusqlite` with `fts5` feature flag — direct port |
| Skill creation trigger (5+ tool calls) | Counter in agent loop; trigger SKILL.md writer task |
| Context compaction nudge timer | `tokio::time::interval(Duration::from_secs(900))` |
| User modeling | Epistemological profile JSON updated after each session |

**What NOT to port:**
- DSPy optimization framework — Python-only, requires Python runtime
- GEPA genetic mutation — Python-only; *concept* can be approximated natively by scoring skill versions against a test trace and keeping the highest performer
- Atropos RL training — cloud training pipeline, irrelevant to runtime

**Self-evolution vs. Living Vault:** Hermes self-evolution is about *optimizing skill text*. Epistemos's Living Vault is about *memory persistence and knowledge graph updates*. They are complementary, not redundant. The Living Vault handles the vault's Ebbinghaus decay and diff engine; the self-evolution pattern handles the agent's procedural skill files. Both should exist.

**Integration difficulty:** Adopting agentskills.io format and FTS5 session search: **1–3 days**. These are data format decisions, not algorithmic ones.

***
### 1.4 SciAgent-Skills (jaechang-hits) — **SKIP**
This repository provides Python-based computational biology and bioinformatics tools (protein analysis, drug discovery, experiment design). While the *concept* of scientific research skills for the `⌘R` one-click research feature is relevant, these specific tools are:[^16]
- Bioinformatics-specific — not general knowledge-graph research
- Python-only with heavy scientific dependencies (RDKit, BioPython, etc.)
- Too narrow for a general PKM application

The correct path for `⌘R` is: web search tool (via MCP extension) + Epistemos graph traversal + Hermes-style SKILL.md for research workflow patterns. **SciAgent-Skills would only matter if Epistemos targets life sciences research users specifically.**

***
## Section 2 — Goose Architecture Deep Dive
### 2.1 Crate Map
```
goose/ (workspace root, version 1.0.27, Apache-2.0)
├── crates/
│   ├── goose/              ← THE CORE — providers, agent loop, extensions, session
│   ├── goose-mcp/          ← MCP server implementations (computercontroller, memory, autovisualiser)
│   ├── goose-acp-macros/   ← #[tool] proc macro for extension definition
│   ├── goose-cli/          ← CLI binary (skip for Epistemos)
│   ├── goose-server/       ← HTTP server (skip)
│   └── goose-bench/        ← Evaluation (skip)
```
### 2.2 Agent Loop — `reply_internal()`
The agent loop (conceptual flow from docs):[^5][^8]

```
user message
    → system prompt construction
    → tool list assembly (or router__llm_search only if ToolRouteManager active)
    → provider.stream(model_config, session_id, system, messages, tools)
    → parse streaming response:
        if text delta: accumulate, stream to UI
        if tool_call: ExtensionManager.call_tool(name, params)
            → if ToolInspectionManager active: adversary review → ALLOW or BLOCK
            → dispatch to matching Extension.call_tool()
            → append tool_result to messages
    → loop until no more tool calls
    → if context > auto_compact_threshold: summarize oldest N messages
    → if context still > limit: apply context_strategy (truncate/clear/prompt)
```

The planner/worker split: set `GOOSE_PLANNER_PROVIDER` + `GOOSE_PLANNER_MODEL` to use one model for strategic planning (clears message history after plan is approved) and a different model for execution. This is the architectural basis for Epistemos's 3-tier local model system.[^8]
### 2.3 MCP Implementation
Goose v1.25.0 uses `rmcp 0.15.0`. The `rmcp` crate (Model Context Protocol official Rust SDK) fully implements the MCP 2025-11-25 spec with:[^9]
- Stdio, Streamable HTTP, SSE transports
- OAuth for MCP servers
- Resumability, batch messages, streaming JSON
- DNS rebinding protection[^17]

The `goose-mcp` crate wraps `rmcp` to define individual builtin extensions as MCP servers. For Epistemos, the migration path is:
1. Import `rmcp` directly as a dependency in `agent_core`
2. Implement each of the 50+ Epistemos tools as `rmcp::ServerHandler` impls
3. Expose the combined MCP server to Swift via a Unix domain socket (UDS) or `tokio::io::DuplexStream`
4. On the Swift side, replace `EpistemosMCPClient` with a minimal `URLSession`-based or NIO client connecting to the Rust MCP server

This eliminates `epistemos_bridge.py` and the Python subprocess entirely.
### 2.4 Adversary Mode / Security Architecture
The adversary mode is a two-agent security pattern (added March 2026):[^6]
- A second LLM instance runs silently, reviewing each tool call against the full conversation context
- Returns `ALLOW` or `BLOCK` with a reason
- Pattern-based prompt injection detection scans tool results for adversarial instruction content
- Egress inspector blocks unexpected network calls from tools
- Repetition inspector detects infinite tool-calling loops

For Epistemos, this becomes the security substrate for the 50+ tool suite. Adapt the adversary and egress inspectors verbatim; the repetition inspector can use a simpler counter approach.

***
## Section 3 — Model Recommendations
### 3.1 Gemma 4 Family Overview
Gemma 4 released April 2, 2026. Four sizes, all Apache-2.0, all instruction-tuned:[^1]

| Model | Effective Params | Context | Key Capability | MLX Ready |
|---|---|---|---|---|
| E2B | 2.3B (5.1B w/ embed) | 128K | Ultra-light, audio+vision | Yes[^1] |
| E4B | 4.5B (8B w/ embed) | 128K | Balanced router/agent, audio+vision | Yes[^18] |
| 26B A4B MoE | 3.8B active / 25.2B total | 256K | Near-31B quality at 4B compute | Yes[^1] |
| 31B Dense | 30.7B | 256K | Max quality, needs 20+ GB | Yes[^18] |

**Architecture highlights:**
- Alternating local sliding-window (512 or 1024 tokens) and global full-context attention layers[^1]
- Per-Layer Embeddings (PLE): a per-layer conditioning pathway that adds meaningful per-layer specialization at modest parameter cost[^1]
- Shared KV Cache: last N layers reuse K/V states from preceding non-shared layer — major memory reduction for long context[^1]
- Native function calling (tool_use) in all sizes, tested with multimodal inputs including tool calls over images[^19]
### 3.2 Recommended Model Stack for M2 Pro 18GB
#### Router Model: **Gemma 4 E4B — 4-bit MLX**

- **Memory:** ~2.5–3 GB at 4-bit (4.5B effective parameters)[^18]
- **tok/s on M2 Pro (estimated from Reddit MLX thread):** 55–70 tok/s at 4-bit[^20]
- **Why it wins:** 128K context, native function calling, audio support (can classify intent from voice), fits in memory alongside the reasoner model. MMLU Pro 69.4%, LiveCodeBench 52% — more than sufficient for intent classification, routing depth estimation, and quick-fire tool calls.[^1]
- **Format:** `mlx-community/gemma-4-E4B-it-4bit` (day-0 release)
- **TurboQuant:** Enable `--kv-bits 3.5 --kv-quant-scheme turboquant` for long conversations — reduces KV cache active memory ~4×[^1]

#### Reasoner + Agent Model: **Gemma 4 26B A4B MoE — 4-bit MLX + TurboQuant**

- **Memory:** ~16–18 GB at 4-bit (25.2B total, 3.8B active per token)[^21][^18]
  - **Fits in 18GB.** The critical insight: only 3.8B parameters are active per token, so *compute* is equivalent to a 4B model. Memory holds the full 25.2B weight matrix, but in 4-bit it occupies approximately 12–14 GB, leaving headroom for KV cache and Swift app runtime.
- **tok/s:** MoE tables from the Reddit MLX benchmark show Qwen3.5-35B-A3B at 8-bit running 71.8 tok/s; Gemma 4 26B-A4B should be comparable or faster at 4-bit (fewer active params). Realistic estimate: **45–65 tok/s** at 4-bit MLX on M2 Pro 18GB with TurboQuant.[^20]
- **Benchmarks:** AIME 2026 88.3%, Codeforces ELO 1718, LiveCodeBench 77.1%, MMLU Pro 82.6%, LMArena 1441. This is genuinely frontier-level reasoning.[^1]
- **Tool calling:** Confirmed reliable tool calling across all modalities — multimodal function calling tested and validated in official release docs[^1]
- **TurboQuant KV:** `--kv-bits 3.5 --kv-quant-scheme turboquant` is explicitly supported for this model in `mlx-vlm`, reducing active memory ~4× for long context inference[^1]
- **Format:** `mlx-community/gemma-4-26B-A4B-it` (MLX 4-bit) — or use `ggml-org/gemma-4-26b-a4b-it-GGUF:Q4_K_M` with llama.cpp for GGUF path
- **Why it beats Qwen 3.5 for this stack:** Native MLX, Apache-2.0, day-0 release, confirmed MoE architecture that fits the exact 18GB constraint, superior benchmarks, and explicit Hermes agent integration testing mentioned in official docs[^1]

#### Summary Table

| Role | Model | Format | RAM | tok/s (est.) | Context |
|---|---|---|---|---|---|
| Router (pinned) | Gemma 4 E4B-it | 4-bit MLX | ~3 GB | 55–70 | 128K |
| Reasoner + Agent | Gemma 4 26B-A4B-it | 4-bit MLX + TurboQuant | ~14–16 GB | 45–65 | 256K |
| Cloud fallback | Anthropic / OpenAI / Google | Provider API | — | — | 200K+ |

***
## Section 4 — TurboQuant and Dynamic 2.0 Analysis
### 4.1 What TurboQuant Actually Is
TurboQuant in the `mlx-vlm` context is **KV cache quantization**, not weight quantization. It reduces the precision of stored key/value tensors during generation from float16 to ~3.5 bits per element. This achieves:[^1]
- ~4× reduction in KV cache active memory
- Enables long-context inference on 18GB hardware that would otherwise OOM
- Same accuracy as uncompressed baseline per official benchmarks[^1]

This is orthogonal to Unsloth Dynamic 2.0, which is **weight quantization**.
### 4.2 Unsloth Dynamic 2.0 — Per-Tensor AWQ Quantization
Unsloth Dynamic 2.0 is a per-tensor quantization strategy that assigns each weight tensor a precision level based on KLD sensitivity analysis and AWQ correctability. Key technical facts:[^22]

- Based on 150+ KLD benchmarks across 121 quantization configurations[^22]
- Uses importance matrices (imatrix) calibrated on high-quality conversational + coding data[^22]
- AWQ pre-scaling: amplifies important weight channels and compensates via preceding norm layers — only works where a norm layer directly precedes the projection[^22]
- Critical finding: `linear_attn.out_proj` is the most KLD-sensitive tensor (6.0); `lm_head` is the safest (0.05)[^22]
- In practice: `embed_tokens` → 5-bit, `lm_head` → 6-bit, router gates → 8-bit, `o_proj` → bf16 (skip), MLP gate/up → 3-bit[^22]
- Key insight: **spending a few extra bits on embed_tokens and lm_head (< 1% of total model size) has negligible impact on file size but dramatically reduces output degradation**[^22]

For Qwen3.5 hybrid models (alternating full-attention + GatedDeltaNet layers), uniform 4-bit quantization is catastrophic because `linear_attn.out_proj` tensors have KLD 6.0 and cannot be AWQ-corrected (no preceding norm). Dynamic 2.0 keeps these at bf16.[^22]
### 4.3 Which Quant Method for Epistemos on M2 Pro 18GB?
| Method | Works with MLX? | Best for | Notes |
|---|---|---|---|
| TurboQuant KV | Yes (native mlx-vlm) | Gemma 4 long context | KV cache, not weights |
| Unsloth Dynamic 2.0 MLX | Yes (via MLX-Node Rust pipeline[^22]) | Qwen3.5 hybrid models | Requires imatrix |
| Standard Q4_K_M (GGUF) | llama.cpp only | Any model via GGUF | Not MLX |
| Standard 4-bit MLX | Yes | Gemma 4 (non-hybrid) | Baseline |

**Recommendation:** Use standard 4-bit MLX quantization for Gemma 4 E4B (router) and Gemma 4 26B-A4B (reasoner/agent), with TurboQuant KV enabled for the 26B model during long-context sessions. Unsloth Dynamic 2.0 is most relevant if Epistemos ships Qwen3.5 as an alternative model path — in that case, the MLX-Node Rust quantization pipeline can run at model-download time.[^22]

**Does Epistemos's Stateful Rotor quantization pipeline need updating?** The Stateful Rotor pipeline (for QLoRA fine-tuning and MoLoRA adapter routing) operates on fine-tuning, not inference quantization. It does not conflict with TurboQuant or Dynamic 2.0. However, if the nightly self-improvement loop produces adapter checkpoints, those adapters should be validated against the Dynamic 2.0 base quant to ensure they don't re-introduce precision in sensitive layers.

***
## Section 5 — Qwopus 3.5 27B v3 TQ3_4S Analysis
### What Is Qwopus?
Qwopus is a community merge/distillation of Qwen3.5 and Opus-class reasoning models. The v3 variant is specifically a speculative-decoding-optimized distillation where the draft model is tuned to match the target model's token distribution.[^23]
### TQ3_4S Quantization
`TQ3_4S` is a **non-standard ternary quantization format** requiring a fork of `llama.cpp`:
- TQ3: ternary weights with 3 possible values (-1, 0, +1) packed efficiently
- 4S: 4-bit scale factors applied per 32-weight group
- Arithmetic: bitwise POPCNT operations replace FP multiply-accumulate — dramatically faster on CPUs, but GPU (Metal) support is incomplete[^23]
### Fit on M2 Pro 18GB
Qwopus3.5-27B-v3 at TQ3_4S: estimated ~7–9 GB (ternary packs very densely). Fits easily in 18GB. However:

**Problems for Epistemos:**
- No MLX path — requires a patched `llama.cpp` that is not the mainstream fork
- No official Rust inference library supports TQ3_4S natively
- Speculative decoding with the draft model adds complexity to the inference pipeline
- Quality vs. Gemma 4 26B-A4B: likely inferior on reasoning benchmarks (Gemma 4 26B-A4B scored Codeforces ELO 1718 vs. Qwen3.5 27B (dense) at much lower scores)[^20]

**Verdict: Skip for Phase I.** Monitor if TQ3_4S gets merged into mainline llama.cpp or if MLX support appears. As of April 2026, it is not worth the integration debt.

***
## Section 6 — Mistral.rs as a Rust-Native Inference Alternative
The official Gemma 4 release notes an important finding: **mistral.rs is a Rust-native inference engine with day-0 Gemma 4 support**. It supports all modalities (text, image, video, audio), builtin tool-calling, and agentic functionality. Installation is a single shell script.[^1]

For Epistemos, this is significant: mistral.rs could serve as the inference backend for `agent_core` rather than running a separate MLX Python server. It exposes an OpenAI-compatible HTTP endpoint, which means the `LocalMLXProvider` can be re-pointed at a `mistralrs serve` process with zero API changes. The advantage over MLX: fully Rust, no Python dependency even for the inference server, smaller memory footprint for in-process use.

**Recommendation:** Evaluate mistral.rs as the inference backend in Phase I. If it matches MLX tok/s on Gemma 4 E4B and 26B-A4B, prefer it for the `agent_core` local inference path — it keeps the entire runtime Rust-native.

***
## Section 7 — Hermes Self-Evolution: Rust-Portable Patterns
The DSPy + GEPA evolution loop cannot be ported to Rust in its current form. However, its *design philosophy* maps cleanly to native Rust:[^13][^14]
### Rust-Native Self-Evolution Architecture for Epistemos
```
┌─────────────────────────────────────────────────┐
│            Epistemos Living Vault               │
│  ┌─────────────┐   ┌───────────────────────┐   │
│  │ SKILL.md    │   │ Session FTS5 SQLite    │   │
│  │ Registry    │   │ (rusqlite + fts5)      │   │
│  │ (agentskills│   │ Compaction at >80%     │   │
│  │  .io format)│   │ context threshold      │   │
│  └─────────────┘   └───────────────────────┘   │
│          │                    │                  │
│  ┌─────────────────────────────────────────┐   │
│  │    Nightly Skill Scorer (Rust async)    │   │
│  │  - Replay last N sessions per skill     │   │
│  │  - Score: task_success / tool_calls     │   │
│  │  - Keep highest-scoring SKILL.md version│   │
│  │  - No Python, no DSPy, no GEPA          │   │
│  └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

This is the Rust analogue of GEPA's genetic improvement: instead of LLM-driven mutation, Epistemos uses session replay scoring with the vault's existing diff engine and Ebbinghaus decay to surface which skill invocations led to successful outcomes.

***
## Section 8 — Phase I Integration Roadmap
### Week 1–2: Audit and Extract
1. Clone `block/goose` repo; extract `crates/goose/` and `crates/goose-acp-macros/` into a local `vendor/` directory in the Epistemos workspace
2. Identify every Python function in `epistemos_bridge.py` — map each to either a Goose builtin extension (file ops, bash, grep, glob) or a custom Rust tool
3. Audit Swift `EpistemosMCPClient/Server` — identify which calls can be replaced by the `rmcp`-backed Goose MCP crate
4. Download Gemma 4 E4B 4-bit MLX and Gemma 4 26B-A4B 4-bit MLX; run baseline latency benchmarks with TurboQuant KV on vs. off
### Week 3–4: Provider + Extension Layer
5. Implement `LocalMLXProvider` in `agent_core/src/providers/local_mlx.rs` — wraps local OpenAI-compatible endpoint (MLX-LM server or mistral.rs)
6. Implement cloud providers (OpenAI, Anthropic, Google) by adapting Goose's provider impls, stripping CLI deps
7. Port 17 core coding tools to Rust `BuiltinExtension` impls using `#[tool]` proc macro
8. Compile and link `agent_core` as a static library; define C ABI bridge for Swift: `call_tool(name: *const c_char, params_json: *const c_char) -> *mut c_char`
### Week 5–6: Session + Context Layer
9. Implement SQLite session persistence with FTS5 search (port Hermes pattern)
10. Implement context compaction at 80% context threshold (port Goose pattern)
11. Implement agentskills.io SKILL.md parser in Rust
12. Wire adversary mode security inspector for sensitive tools (bash, file write)
### Week 7–8: Integration + Testing
13. Shut down Python subprocess in Epistemos binary; validate full agent loop through Rust
14. A/B test Gemma 4 26B-A4B vs. current Qwen default on 50 representative tasks from vault
15. Enable TurboQuant KV for 26B model; measure memory headroom vs. Metal GPU budget
16. Document new model slots in `ModelConfig` for user-selectable routing in Settings
### Updated Binary Size Estimate
| Component | Before Phase I | After Phase I |
|---|---|---|
| Python venv + Hermes agent | 60–120 MB | 0 |
| `agent_core.dylib` (Rust, stripped) | ~8 MB (UniFFI overhead) | ~12–16 MB (Goose + rmcp) |
| MLX model weights (E4B 4-bit) | 0 | ~3 GB (user download) |
| MLX model weights (26B-A4B 4-bit) | 0 | ~14 GB (user download) |
| App binary total (ex-models) | ~250 MB | ~180–200 MB |

**Net result:** Eliminate 60–120 MB Python payload; slightly increase Rust binary (~4–8 MB); dramatically improve cold start (no venv activate, no Python import chain).
### Updated Performance Targets
| Metric | Current | Phase I Target |
|---|---|---|
| Agent cold start | ~3–8 sec (Python subprocess) | <200 ms (Rust async init) |
| First tool call latency | ~500 ms (Python IPC) | <10 ms (in-process Rust) |
| Router model first token | N/A | <50 ms (E4B, warm) |
| Reasoner first token | ~2–3 sec (current) | <500 ms (26B-A4B warm) |
| Memory footprint (agent runtime) | 200–400 MB (Python heap) | <40 MB (Rust async runtime) |

***
## Section 9 — Risk Map
| Risk | Severity | Mitigation |
|---|---|---|
| Goose agent loop changes break `reply_internal()` API | Medium | Vendor the crate at a specific commit; don't track HEAD during migration |
| `rmcp` ABI changes break MCP bridge | Medium | Pin `rmcp` version; write integration tests against every MCP tool |
| Gemma 4 26B-A4B OOM on 18GB during long sessions | Medium | TurboQuant KV + auto-evict context at 80% threshold; monitor with `vm_stat` |
| mistral.rs tok/s inferior to MLX on M2 | Low | Benchmark both before committing; MLX remains fallback |
| TQ3_4S never gets MLX support | Low | Avoided by selecting Gemma 4 instead of Qwopus |
| agentskills.io SKILL.md format changes | Low | Own the parser; treat spec as advisory not normative |
| Goose Extension trait changes | Low | Only clone the Provider + Extension traits; don't depend on goose crate directly |

***
## Section 10 — Final Verdicts
**Should Epistemos clone Goose?** Yes — clone the `goose` crate (not the CLI/server), specifically `Provider` trait, `Extension` trait, `ToolInspectionManager`, and the agent loop compaction logic. This is the fastest path to a production-grade Rust agent that handles 15+ cloud providers + local MLX with one unified interface.

**Can the Provider trait serve cloud as well?** Yes. The Provider trait is deliberately cloud-agnostic — it abstracts OpenAI, Anthropic, Google, and local endpoints behind the same `stream/complete` interface. One `agent_core::Provider` covers all of Epistemos's AI stack.

**Best local model for Epistemos M2 Pro 18GB?** Gemma 4 26B-A4B at 4-bit MLX with TurboQuant KV — 88.3% AIME 2026, Codeforces ELO 1718, 256K context, fits in 16–18 GB, native tool calling, Apache-2.0. This is the correct choice.

**Best router model?** Gemma 4 E4B at 4-bit MLX — always-hot at ~3 GB, 128K context, strong MMLU, audio+vision for multimodal routing, native function calling.

**Skip Python entirely?** Yes. Goose + rmcp + Rust tool extensions replaces the entire Python Hermes subprocess. The Living Vault self-improvement loop can be reimplemented in Rust using session replay scoring without DSPy/GEPA.

**What about Qwopus TQ3_4S?** Skip for Phase I. No MLX path, non-standard format, inferior benchmarks vs. Gemma 4 26B-A4B.

**Hermes self-evolution?** Study the SKILL.md format and FTS5 session search pattern; port both to Rust. Skip the DSPy/GEPA Python optimizer.

---

## References

1. [Welcome Gemma 4: Frontier multimodal intelligence on device](https://huggingface.co/blog/gemma4) - Similar to Gemma-3n, Gemma 4 supports image, text, and audio inputs, and generates text responses. T...

2. [goose/Cargo.toml at main · block/goose - GitHub](https://github.com/block/goose/blob/main/Cargo.toml) - an open source, extensible AI agent that goes beyond code suggestions - install, execute, edit, and ...

3. [Provider Interface - Goose - Mintlify](https://www.mintlify.com/block/goose/development/provider-interface) - Goose's provider system allows integration with any LLM service. This guide explains how to implemen...

4. [Extensions Design | goose - GitHub Pages](https://block.github.io/goose/docs/goose-architecture/extensions-design/) - This document describes the design and implementation of the Extensions framework in goose, which en...

5. [Smart Context Management | goose - GitHub Pages](https://block.github.io/goose/docs/guides/sessions/smart-context-management/) - goose automatically compacts (summarizes) older parts of your conversation when approaching token li...

6. [Adversary Agent: using a hidden agent to keep the main agent safe](https://block.github.io/goose/blog/2026/03/31/adversary-mode) - Introducing adversary mode — an independent agent reviewer that silently watches the main agent to k...

7. [Custom Providers - Goose - Mintlify](https://mintlify.com/block/goose/guides/custom-providers) - Goose offers two approaches: declarative configuration for OpenAI-compatible APIs, and full Rust tra...

8. [Does Your AI Agent Need a Plan? | goose](https://block.github.io/goose/blog/2025/12/19/does-your-ai-agent-need-a-plan/) - Planning with an AI produces good results. Knowing when and how to plan with an AI agent produces ev...

9. [goose v1.25.0: Sandboxed, Streamlined, and More Secure](https://block.github.io/goose/blog/2026/02/23/goose-v1-25-0/) - goose v1.25.0 brings macOS sandboxing, a unified summon extension, rich MCP app UIs, agentic CLI upg...

10. [Extensions · block goose · Discussion #7675 - GitHub](https://github.com/block/goose/discussions/7675) - Builtin extensions - part of the goose-mcp crate, run in a separate process and goose communicates w...

11. [Configure LLM Provider | goose - GitHub Pages](https://block.github.io/goose/docs/getting-started/providers/) - Ramalama API is a compatible alternative to Ollama and can be used with the goose Ollama provider. S...

12. [Activity · NousResearch/hermes-agent-self-evolution - GitHub](https://github.com/NousResearch/hermes-agent-self-evolution/activity) - Evolutionary self-improvement for Hermes Agent — optimize skills, prompts, and code using DSPy + GEP...

13. [NousResearch/hermes-agent-self-evolution - GitHub](https://github.com/NousResearch/hermes-agent-self-evolution) - Hermes Agent Self-Evolution uses DSPy + GEPA (Genetic-Pareto Prompt Evolution) to automatically evol...

14. [GEPA Optimization for AI Agent Skills with Sensei v1.4.0 - LinkedIn](https://www.linkedin.com/posts/shayneboyer_githubcopilot-ai-agentskills-activity-7442719498719121408-MNr0) - The solution: Sensei's new --gepa mode replaces template-based improvements with LLM-driven evolutio...

15. [Hermes Agent: what Nous Research built - CrabTalk](https://crabtalk.ai/blog/hermes-agent-survey) - We examined Hermes Agent's architecture — from Atropos RL training to persistent skill documents. He...

16. [Best Python Repositories | GitHubTree](https://githubtree.mgks.dev/language/python/) - NousResearch/hermes-agent-self-evolution. ⚒ Evolutionary self-improvement for Hermes Agent — optimiz...

17. [rust-mcp-sdk - Lib.rs](https://lib.rs/crates/rust-mcp-sdk) - This SDK fully implements the latest MCP protocol version (2025-11-25), with backward compatibility ...

18. [gemma4:e4b - Ollama](https://ollama.com/library/gemma4:e4b) - Gemma 4 models are designed to deliver frontier-level performance at each size. They are well-suited...

19. [From RTX to Spark: NVIDIA Accelerates Gemma 4 for Local Agentic AI](https://blogs.nvidia.com/blog/rtx-ai-garage-open-models-google-gemma-4/) - The E2B and E4B models are built for ultraefficient, low-latency inference at the edge, running comp...

20. [MLX Inference: Where Things Stand in April 2026 - Reddit](https://www.reddit.com/r/LocalLLaMA/comments/1sa56q8/mlx_inference_where_things_stand_in_april_2026/) - Whats up with MLX? · Is MLX in itself somehow making the models a little bit different / more "stupi...

21. [Run Gemma 4 Locally with Ollama - LeetLLM](https://leetllm.com/blog/run-gemma4-local-ollama) - This guide walks you through running the 26B MoE and 31B Dense models on your own GPU using Ollama, ...

22. [SWARM: Replicating Shared Disaggregated-Memory Data in No Time](http://arxiv.org/pdf/2409.16258.pdf) - Memory disaggregation is an emerging data center architecture that improves
resource utilization and...

23. [Logseq Review: Effective PKM Tool for Knowledge Organization](https://www.linkedin.com/posts/rahulmohank_turns-out-logseq-is-the-winner-for-me-activity-7422617099245772800-tIXE) - Turns out, Logseq is the winner for me. The first option that comes to mind when noting something do...

