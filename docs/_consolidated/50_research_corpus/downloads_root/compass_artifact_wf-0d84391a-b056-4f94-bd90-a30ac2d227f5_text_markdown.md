# Epistemos Master Execution Plan: Implementation Contract

**Status as of April 26, 2026.** This report is grounded against verified APIs, crate versions, and shipping releases. Speculative claims are flagged inline. Apple Foundation Models (FMF), MLX-Swift 0.31.x, mlx-swift-lm 3.31.x, UniFFI 0.29.5, Swift 6.2 (Xcode 26), macOS 26.4 ("Tahoe" RC) are the platform baselines.

---

## Executive summary: the five "go-first" moats

Before the per-phase breakdown, the strategic conclusion: **ship phases 1, 2, 8, 12, and one of {3 or 5} first.** They produce the highest demo-to-effort ratio, feed every other phase's data substrate, and align directly with Apple Design Award judging patterns (native API depth, distinctive viewpoint, on-device privacy).

| Priority | Phase | Type | ADA category fit | Reason |
|---|---|---|---|---|
| **1** | 8 — Live dynamic knowledge graph (Metal-rendered) | Demo + Infra | **Innovation** / Visuals & Graphics | Visible 60–120 fps Metal; sqlite-vec KNN + petgraph; the App Store hero shot |
| **2** | 2 — Organic decay engine (FSRS-6 + tiered quantization) | Demo + Infra | Innovation | Vectors physically shrink on disk; visually striking; novel data structure |
| **3** | 1 — Intelligent semantic ontology via AFM `@Generable` | Infra (powers everything) | Innovation | One Swift type drives LLM + UI + persistence |
| **4** | 12 — Cognitive sidecar files | Infra (trust moat) | Inclusivity / Innovation | Plain JSON, `vim`-able; converts power users away from Obsidian |
| **5** | 5 — Hybrid brain (AFM 3B + MLX subconscious + cloud executive) | Infra | Innovation | Demonstrates AFM mastery — Apple PR'd seven AFM-using apps in Sept 2025 |

**Defer to v1.5:** Phase 10 NightBrain LoRA (highest infra moat, almost impossible to demo live), Phase 11 voice (commodity), Phase 16 stenographer (overlaps with Granola). **Treat Phase 6 as a feasibility fence:** the "pause-mid-stream-and-inject" pattern does not exist on any cloud API and must be replaced with tool-use retrieval.

---

## Phase 1 — Intelligent semantic ontology

### Recommended implementation
**Apple Foundation Models `@Generable` recursive structs as primary path**, with **HDBSCAN clustering on MLX-embedded sentence vectors** as the unsupervised discovery pass, and **llama.cpp GBNF grammars via Rust FFI** as the only-on-pre-26 fallback.

```swift
@Generable struct OntologyNode {
    @Guide(description: "Canonical concept, lowercase kebab-case") let concept: String
    @Guide(description: "Knowledge depth marker") let depth: DepthMarker
    @Guide(.count(0...8)) let children: [OntologyNode]   // recursive nesting works
}
@Generable enum DepthMarker { case surface, synthesized, coreBelief }
```

`@Generable` performs token-level masking against a compile-time-derived schema in a privileged OS daemon. Verified `@Guide` constraints: `.count(_:)`, `.range(_:)`, `.minimum/.maximum`, `.anyOf([...])`, `.pattern(/regex/)`, `.description("...")`. Recursive nesting is supported but **property declaration order is semantically significant** — the model fills fields sequentially, so dependents must follow their referents.

### Alternatives

| Approach | Pros | Cons | RAM | Verdict |
|---|---|---|---|---|
| AFM `@Generable` (rec.) | Free, type-safe, streaming `PartiallyGenerated`, OS-managed | macOS 26+, ~3B fixed, mandatory guardrails | OS daemon, **0 app cost** | Primary |
| MLX-Swift + GBNF via FFI | Any safetensors arch | Build complexity; `additionalProperties:false` quirks; `oneOf+properties` mixing buggy | 0.5–4 GB | Pre-26 fallback |
| GLiNER-multitask (ONNX) | <500 MB, 0.62 F1 zero-shot, parallel | Flat entities only; needs two passes for hierarchy | 200–400 MB | Niche |
| HDBSCAN (`hdbscan = "0.12"`) on MiniLM | Unsupervised, label-free, noise-tolerant | No semantic labels; needs ≥50 points | 100–300 MB | **Use it for parent-domain discovery, then label clusters with AFM** |

### Specific crates / APIs
`FoundationModels` (macOS 26+), `hdbscan = "0.12"`, `petal-clustering = "0.10"` (alt), `schemars = "0.8"` for schema export, `llama-cpp-2` Rust bindings (fallback).

### Failure modes
Schema drift across macOS minor versions (snapshot-test exported JSON), recursive `@Generable` infinite descent (always bound `children` with `.count`), GBNF sampler stalls on greedy `x?` repetitions (use `x{0,N}`), AFM guardrails false-positives on aviation/medical terms.

### Award angle
The same Swift type drives (a) Apple on-device LLM, (b) SwiftUI list rendering with `PartiallyGenerated` streaming, (c) GRDB persistence — **single source of truth, zero glue code**. Live HDBSCAN-driven self-organizing ontology is genuinely impressive.

---

## Phase 2 — Organic decay engine

### Recommended implementation
**FSRS-6 algorithm via `fsrs = "5.2.0"` crate** (BSD-3, maintained by Anki's lead dev + Jarrett Ye, 21 trainable params, uses Burn — no libtorch). Schedule via **`tokio-cron-scheduler = "0.15.1"`** for in-process work + **launchd LaunchAgent registered through `SMAppService.agent(plistName:)`** for the 3 AM nightly wake.

**Quantization tier cascade** (real, shipping crates only):
- Tier 0 (≤ 7 days): `f16` via `half = "2.6"` + `safetensors = "0.5"`
- Tier 1 (8–30 d): `Q8_0` via `candle-core` quantized types
- Tier 2 (30–90 d): `Q4_K` via `candle-core`
- Tier 3 (>90 d): `Q2_K` via `candle-core` — **below this, summarize-and-delete; raw int2 without GPU rotation kernels is below the noise floor**

### Critical platform reality
- **`BGTaskScheduler` does NOT exist on macOS** (`API_UNAVAILABLE(macos)` in SDK headers — verified). Do not plan around it.
- **`NSBackgroundActivityScheduler` only runs while app is alive** — useless for 3 AM wake if user quits the app.
- **`launchd StartCalendarInterval` wakes from sleep, coalesces missed runs** (per `launchd.plist` man page) — the only correct mechanism.
- Power Nap is Intel-only; Apple Silicon's "always-on processor" handles dark-wake differently. Plan for "first wake-window after 3 AM" semantics.

### Alternatives

| Algorithm | Verdict |
|---|---|
| Pure Ebbinghaus `R = e^(-t/S)` | Too simple; FSRS power function fits real data better |
| SM-2 (Anki classic) | FSRS dominates on SRS-Benchmark; SM-2's "reset to step 1" on lapse is statistically wrong |
| **FSRS-6 (recommended)** | DSR model, 21 params, plug-in ready |

| Quantization research approach | Status | Verdict |
|---|---|---|
| ButterflyQuant (arXiv 2509.09679) | Paper only, **no library** | Don't port for hackathon |
| TurboQuant (arXiv 2504.19874) | Google paper, **no Google impl**; community port `0xSero/turboquant` is CUDA-only | Skip on Apple Silicon |
| Kitty (arXiv 2511.18643) | Triton/CUDA only; KV-cache only | Wrong target |
| KVTuner (arXiv 2502.04420) | Code exists at `cmd2001/KVTuner`; CUDA | Concept worth borrowing |
| **candle GGUF Q-types** | Production-ready in Rust **today** | Use this |

### Failure modes
FSRS parameter training overfits below ~50 reviews (use defaults + Bayesian prior to defaults for first two weeks); quantization is irreversible (keep f16 baseline for at least 90 days); `launchd` plists must be Team-ID-signed or `SMAppService.register()` fails silently; M-series laptop on battery + lid closed may defer 3 AM jobs by hours — fallback fire on next launch if `last_consolidation > 36h`.

### Award angle
*"Notes that forget like brains do."* Live demo: scrub a 30-day timeline → vector store shrinks visibly from 850 MB to 220 MB while semantic recall on the active subset stays >0.95 of f16 baseline. Pure local, no subscription, no model rot.

---

## Phase 3 — Omni-CLI native bridge

### Recommended implementation
**`pty-process = "0.5.3"` with `features = ["async"]`** for PTY spawning (Tokio-native AsyncRead/Write). **`anstream = "0.6"`** for ANSI stripping. Per-CLI adapters that emit a unified `AgentEvent` enum.

### Per-CLI verified flag matrix

| CLI | Headless | JSON stream | Auth | MCP support | Reality |
|---|---|---|---|---|---|
| **Claude Code** | `claude -p "..." --output-format stream-json --verbose --include-partial-messages [--bare]` | ✅ NDJSON: `system`, `stream_event`, `result`. `--json-schema` for constrained output. `--continue` / `--resume <session_id>` | `ANTHROPIC_API_KEY` | `claude mcp add`; can act as MCP server via `claude mcp serve` | Best supported |
| **OpenAI Codex** | `codex exec --json "..."` (Rust binary, source-available `openai/codex`) | ✅ JSONL: `thread.started`, `turn.{started,completed,failed}`, `item.{started,updated,completed}`. Item types: `agent_message`, `reasoning`, `command_execution`, `file_change`, `mcp_tool_call`. `--output-schema` for constrained output. `-o <path>` for final | ChatGPT OAuth or `OPENAI_API_KEY` | `codex mcp add`, `codex mcp serve` | Stable; can vendor `codex-rs` directly |
| **Kimi CLI** (`MoonshotAI/kimi-cli` v1.39) | `kimi --print -p "..."` | ✅ `--output-format=stream-json` (OpenAI Message format) | OAuth or API key | `kimi mcp add` | macOS+Linux only |
| **Hermes Agent** (Nous Research) | `hermes chat -q "..."` | ⚠️ **No first-class JSONL flag**. Recommended path: spawn `hermes api-server` once and stream via SSE on `/v1/chat/completions`. Or `hermes acp` (Agent Client Protocol) over stdio | OAuth via `hermes auth` | `hermes mcp serve` | **Treat as a service, not a one-shot CLI** |

### Strongly-typed event translation

```rust
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Enum)]
pub enum AgentEvent {
    SessionStarted   { session_id: String, model: String },
    Token            { text: String },
    Reasoning        { text: String },
    ToolCallStarted  { id: String, name: String },
    ToolCallArgsDelta{ id: String, partial_json: String },
    ToolCallCompleted{ id: String, result: String },
    FileChange       { path: String, status: String },
    CommandExec      { command: String, exit_code: Option<i32> },
    GeneratingDiff   { path: String },
    Retry            { attempt: u32, delay_ms: u64, reason: String },
    UsageUpdate      { input_tokens: u64, output_tokens: u64, cost_usd: Option<f64> },
    Done             { final_text: Option<String>, structured: Option<String> },
    Error            { message: String, recoverable: bool },
}
```

A `CliAdapter` trait + per-CLI `translate(&self, line: &str) -> Vec<AgentEvent>` keeps CLI-specific quirks isolated.

### Alternatives
**(A) Direct API calls** lose the agent harnesses (Claude Code's tool framework, Codex's sandboxing, Kimi's subagent tool, Hermes' learning loop). Wrap CLIs for v1; add direct API adapters only on hot paths. **(B) Inversion: expose Epistemos as MCP server** via stdio — best for power users already in `claude` or `codex`; pair with CLI wrapping. **(C) Sidecar XPC services per CLI** — required for Mac App Store distribution due to subprocess sandbox restrictions. v2 architecture.

### Failure modes
CLI version drift (pin per-CLI capabilities table; auto-detect via `--version`); zombie sub-shells (`setpgid` then SIGINT→SIGKILL); auth expiry (delegate re-login to each CLI's own `login` command); JSONL garbage outside the stream (parse line-independently, never concatenate).

### Hackathon flex
*"Side-by-side Plan/Execute panes running Claude Code, Codex, Kimi, Hermes against the same PKM context — four fundamentally different agent harnesses sharing state via your local MCP server."* This is the moat — most "multi-agent" demos use a single inference API.

---

## Phase 4 — Bootstrap packet wiring

### ⚠️ Critical reality-check
**Your 800-token bootstrap is BELOW the cache minimum on every major provider.** Anthropic minimums: Claude Sonnet 4.5/3.7 = **1,024 tokens**, Sonnet 4.6 = **2,048**, Opus 4.5/4.6/4.7 + Haiku 4.5 = **4,096**. OpenAI minimum is 1,024 tokens, increments of 128. **You must pad the bootstrap or you get no cache benefit.**

### Recommended implementation

```swift
let req = AnthropicRequest(
    model: "claude-sonnet-4-5",
    system: [
        .text(packet),                                                    // unmarked
        .text(stableSkillsPlusPersona, cacheControl: .ephemeral(.oneHour)) // pad to ≥ threshold
    ],
    tools: ToolRegistry.stable,   // alphabetic order — order drift = cache miss
    messages: [.user(userText)]
)
```

Cache pricing on Anthropic: cache write = 1.25× (5 min) or 2.0× (1 h); cache read = **0.1× (90% savings)**. Break-even on 1 h TTL ≈ 2 hits/hour. **Anthropic silently changed default ephemeral TTL from 1 h to 5 min in March 2026 — always pass `ttl` explicitly.** Up to 4 explicit `cache_control` markers. Suggested allocation: end-of-tools, end-of-bootstrap, end-of-stable-conversation-chunk, free slot.

### UniFFI BootstrapPacketBuilder
Make the Rust builder **deterministic** — sort tool arrays, canonical JSON, lock newlines, no timestamps. Single-character drift = cache miss.

### Swift 6 / Xcode 26 gotcha
With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26 default), uniffi-bindgen-generated Swift fails to compile because `deinit` cannot be MainActor-isolated. **Mozilla issue #2818, open since Feb 11, 2026, no fix shipped.** Workaround: place generated bindings in a separate SwiftPM target with `nonisolated` default isolation, OR run `sed` post-processing to prepend `nonisolated` on file-level decls.

### Failure modes
Silent cache miss when below threshold (no error — check `cache_creation_input_tokens` / `cache_read_input_tokens`); concurrent cold requests both pay write cost; tool registry drift; **assistant prefilling is REMOVED on Claude Opus 4.6/4.7, Sonnet 4.6, Mythos Preview** (returns 400) — switch to `output_config.format` for JSON shaping.

---

## Phase 5 — Hybrid brain architecture

### Memory budget on M2 Pro 18 GB

| Component | Owner | Resident |
|---|---|---|
| macOS + WindowServer + daemons | OS | ~3.5–4 GB |
| **AFM 3B (`generativeexperiences`d)** | OS daemon | **~2 GB, OS process — does NOT count against app** |
| Swift heap + UI + SQLite + sqlite-vec hot pages | App | ~1.5–2 GB |
| Rust core (UniFFI) + tokenizers | App | ~300–500 MB |
| **MLX subconscious (Qwen3 0.6B 4-bit)** | App | **~600–800 MB** |
| MLX KV cache headroom (8K ctx) | App | ~300 MB |
| GPU/Metal heaps | App | ~200–400 MB |
| **App total** | | **~3.5–5 GB** |

### Recommendation: Qwen3 0.6B 4-bit, NOT SmolLM2 1.7B

| Model (4-bit, group_size 64) | Disk | RAM ≤1k ctx | RAM @ 4k ctx | Notes |
|---|---|---|---|---|
| **Qwen3 0.6B** (`mlx-community/Qwen3-0.6B-4bit`) | ~360 MB | ~450 MB | ~600 MB | **Top pick for subconscious** |
| Llama 3.2 1B 4-bit | ~720 MB | ~830 MB | ~1.1 GB | Solid baseline |
| SmolLM2 1.7B 4-bit | ~1.0 GB | ~1.1 GB | ~1.4 GB | English only |
| Gemma 3 2B 4-bit | ~1.3 GB | ~1.5 GB | ~1.9 GB | 8k context |
| Phi-3.5-mini 3.8B 4-bit | ~2.2 GB | ~2.4 GB | ~2.9 GB | Exceeds 2 GB budget |

### Concurrency policy (the heart of Phase 5)

```swift
private func canRunMLX() -> Bool {
    let pi = ProcessInfo.processInfo
    if pi.isLowPowerModeEnabled { return false }
    if pi.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue { return false }
    if PowerSource.isOnBattery && PowerSource.currentCharge < 0.50 { return false }
    if Date.now.timeIntervalSince(idleSince) < 2.0 { return false }
    if afmSession.isResponding { return false }   // yield GPU to AFM
    return true
}
```

Cap MLX RSS via `MLX.GPU.set(memoryLimit: 6 * 1024 * 1024 * 1024)`. Use `LanguageModelSession.prewarm(promptPrefix:)` on app launch to hide AFM cold-start. Monitor `ProcessInfo.thermalStateDidChangeNotification` and `.NSProcessInfoPowerStateDidChange`. Note: `ProcessInfo.thermalState`'s `.fair` covers both `powermetrics` "moderate" and "heavy" — for tighter control, shell out to `pmset -g therm` in a privileged helper.

### When to use which brain

| Trigger | Brain |
|---|---|
| Inline grammar / autocomplete while typing | AFM `streamResponse` |
| Per-note auto-tag (foreground) | AFM `SystemLanguageModel(useCase: .contentTagging)` |
| Background bulk re-classification (idle queue) | MLX Qwen3 0.6B |
| Multi-doc reasoning, cross-session synthesis | Cloud (Hermes 4 70B / Claude / Kimi) |
| Code in user's repos | Claude Code via Phase 3 bridge |

**MLX does not use ANE** (MLX is GPU-only on M2). AFM's daemon does. Both share Metal command queues — under contention, the foreground caller wins. Yield-to-AFM via `isResponding` semaphore.

---

## Phase 6 — Just-in-time context injection

### ⚠️ Feasibility verdict (HONEST)

| Pattern | Feasible? | Why |
|---|---|---|
| Pause cloud agent's `<thinking>` mid-stream and inject | **NO** | No provider exposes a pause primitive. Cancel is destructive. |
| Read Claude's `thinking_delta` events | YES (summarized; full trace requires Anthropic sales contact) | **Observe only, cannot steer** |
| Read OpenAI o1/o3/GPT-5 reasoning tokens | NO raw, summary only via `response.reasoning_summary_text.delta` | — |
| **Inject context mid-thought via tool use** | **YES — the only real mechanism** | Agent calls `epistemos_retrieve(...)`, you return `tool_result`, agent continues with interleaved thinking |
| Cancel + re-call with appended context | Mechanically yes, semantically broken | Loses output; thinking blocks must be passed back **verbatim with cryptographic signatures** or Claude rejects |
| Hot-swap system prompt without breaking cache | **NO** | Any change past cache breakpoint = invalidation |

### Recommended pattern: tool-use-based retrieval

Define `epistemos_retrieve` as a cached part of the system+tools prefix. The agent calls it when it realizes it needs information. With **interleaved thinking** (auto on Sonnet/Opus 4.6+; older models need `interleaved-thinking-2025-05-14` beta header), the model emits additional thinking blocks between tool calls — these must be preserved verbatim+signed when continuing.

### 50-token compression
**LLMLingua-2** (`microsoft/llmlingua-2-xlm-roberta-large-meetingbank`). BERT-class encoder, 3–6× faster than v1, runs on CPU/MPS. `target_token=50` parameter, up to 20× compression with minimal quality loss. Run as sidecar Python process or port BERT inference to swift-transformers / Core ML.

**Reject:** ICAE, AutoCompressor, GIST, NUGGET, xRAG — all model-locked (the decoder must be the same LLM as encoder). **No major commercial provider accepts raw embeddings as conversational input. Period.** "Vector-based context substitution" is a research curiosity; the only realistic vector path is tool-use-driven RAG.

---

## Phase 7 — Hermes as Chief of Staff

### Verified facts (April 2026)
**Hermes 4 70B and 405B** were released **August 26, 2025** (Llama-3.1 base, 131K context, hybrid `<think>` reasoning, function calling). **Hermes 4.3 36B** (ByteDance Seed-36B base, trained on Psyche decentralized network) released August 25, 2025. **No "Hermes 5" exists.** Note that "Hermes Agent" (the framework, v0.11) is a distinct product from the Hermes 4 *models* — don't conflate.

### Pricing (April 2026)

| Model | Provider | Input / 1M | Output / 1M |
|---|---|---|---|
| **Hermes 4 70B** | Nous Portal / OpenRouter | **$0.13** | **$0.40** |
| Hermes 4 405B | Nous Portal | $1.00 | $3.00 |
| Hermes 4 405B | Nebius FP8 (via OpenRouter) | $0.60 | $1.90 |
| Hermes 3 405B | OpenRouter free tier | $0 | $0 |
| Claude Sonnet 4.6 | Anthropic | $3.00 | $15.00 |
| Kimi K2 | Moonshot | $0.15 | ~$2.50 |

**Hermes 70B as orchestrator vs Claude Sonnet 4.6 as orchestrator: ~3.2× cheaper end-to-end** for a typical 5-step orchestration ($0.038 vs $0.12 per session).

### MCP server: target spec `2025-06-18`

The newest spec is `2025-11-25` but tooling lags; `2025-06-18` has broadest client support, uses **Streamable HTTP** (replaces old HTTP+SSE) and **OAuth 2.1 + PKCE + Dynamic Client Registration** for remote auth. Pin spec version in `ServerInfo`.

**Rust SDK: `rmcp = "0.16"` (official, `github.com/modelcontextprotocol/rust-sdk`)** — features `["server", "transport-io", "macros"]`. Expose tools via `#[tool(tool_box)] impl EpistemosServer { #[tool(description = "...")] async fn search_notes(...) }`. **Critical: route all logs to stderr; stdout is reserved for JSON-RPC frames.**

### Steerability as moat — concrete examples
1. **Persona persistence across long contexts.** Claude drifts back to assistant persona after ~30 turns; Hermes maintains arbitrary personas for full 131K window.
2. **No reflexive content refusals on user's own data.** A journal containing self-harm reflection or sensitive personal history is summarized by Hermes without disclaimers; Claude/GPT-5 hedge.
3. **Direct steering of reasoning depth** via `reasoning.enabled=false/true` toggle.
4. **Custom format adherence** with less prompt engineering.
5. **Lower sycophancy.**

Caveat: steerability cuts both ways. Single-user local PKM is fine; multi-tenant SaaS needs your own guardrails.

### Orchestration decision matrix

| Pattern | When |
|---|---|
| Parallel fan-out | Subtasks independent + aggregator exists |
| Sequential pipeline | Output of A feeds B |
| Orchestrator-workers | Subtask shape unknown until lead inspects input |
| Evaluator-optimizer | Quality criterion exists; iterate to threshold |
| Single-shot | <2K token task — skip orchestration |

Anthropic's published guidance: **start single-shot, escalate to orchestrator-workers only when you cannot enumerate subtasks at design time.** Each subagent prompt needs four fields: objective, output format, tool/source guidance, task boundaries.

---

## Phase 8 — Cognitive depth & meta-analysis

### Recommended implementation
**`sqlite-vec = "0.1.9"` (vector KNN inside the GRDB SQLite file) + `petgraph = "0.8.2"` (StableDiGraph for in-memory property graph projection) + GRDB tables for L1/L2/L3 nodes and edges.**

```sql
CREATE TABLE node (
  id TEXT PRIMARY KEY, kind TEXT NOT NULL,
  depth INTEGER NOT NULL,                   -- 1=surface, 2=synthesized, 3=core-belief
  title TEXT NOT NULL, body TEXT,
  created_at INTEGER, updated_at INTEGER, sidecar_path TEXT
);
CREATE TABLE edge (
  src TEXT, dst TEXT, rel TEXT,             -- parent_of, derived_from, contradicts, supports, session_of
  weight REAL DEFAULT 1.0, meta JSON,
  PRIMARY KEY (src, dst, rel)
);
CREATE VIRTUAL TABLE vec_node USING vec0(
  node_id TEXT PRIMARY KEY, embedding float[384]
);
```

### Depth markers — TBox/ABox aligned
- **L1 Surface/Scratchpad** → ABox-only, ephemeral, never participates in TBox inference
- **L2 Synthesized/Actionable** → ABox + lightweight type assertions (HDBSCAN cluster summaries)
- **L3 Core Belief/Architecture** → TBox; SKOS-style `broader/narrower/related` edges, plus `contradicts`; changes trigger revalidation cascade

### Dynamic edge inference
On new node N: sqlite-vec KNN k=10 → score with Jaccard-of-tags + cosine → threshold τ=0.78 → emit candidate edges. **Hysteresis: τ_add=0.80 / τ_remove=0.65** (prevents oscillation as user iterates). Existing edges decay `weight *= 0.97^days` via Phase 2 cron.

**`StableDiGraph` is mandatory** if you persist NodeIndex externally (regular `Graph::remove_node` reuses indices; external state silently desyncs).

### Alternatives

| Stack | Verdict |
|---|---|
| **sqlite-vec + petgraph + GRDB** (rec.) | Single ACID DB, 165 KB extension, SIMD KNN, sub-50 ms KNN @ 100k vecs |
| LanceDB embedded (`lancedb = "0.26.2"`) | Multimodal columnar + IVF-PQ; pulls aws-smithy transitive deps requiring Rust ≥1.91 |
| SurrealDB embedded | Native graph + vector + SQL, but RocksDB heavy to compile |
| oxigraph (RDF + SPARQL) | True OWL/SKOS reasoning but RDF model heavy for personal app |

### Award angle
Live, animated graph view that visibly grows new edges as user types (sqlite-vec sub-50 ms latency). L1→L2→L3 depth-marker visualization as color-graded altitude in force-directed graph. **The same SQLite file openable in `sqlite3` CLI** — Obsidian-style "your data is yours" promise.

---

## Phase 9 — High-performance session distillation

### Recommended implementation
**AFM `@Generable` as primary, MLX-Swift + exported `@Generable` JSON Schema as fallback for sessions exceeding 4096 tokens.**

```swift
@Generable struct SessionTelemetry: Equatable {
    @Guide(description: "ISO-8601 UTC start") let sessionStart: String
    @Guide(description: "ISO-8601 UTC end") let sessionEnd: String
    @Guide(.count(0...8)) let decisionsMade: [Decision]
    @Guide(.count(0...10)) let unresolvedFriction: [FrictionPoint]
    @Guide(.count(1...12)) let activeThemes: [String]
    @Guide(.count(3...7)) let emotionalTrajectory: [EmotionalBeat]
    @Guide(description: "≤160 chars") let headline: String
    @Guide(description: "0–100") let confidence: Int

    @Generable struct Decision: Equatable {
        let statement: String
        let supersedes: String?
        @Guide(.anyOf(["hard","soft","exploratory"])) let commitmentLevel: String
    }
    @Generable struct FrictionPoint: Equatable {
        let topic: String; let reason: String
        @Guide(.anyOf(["needs_data","values_conflict","energy_depletion","external_blocker"]))
        let category: String
    }
    @Generable struct EmotionalBeat: Equatable {
        let position: Double  // 0.0=start, 1.0=end
        @Guide(.anyOf(["clarity","frustration","curiosity","resignation","excitement","doubt","resolve"]))
        let valenceLabel: String
        let trigger: String
    }
}
```

**4096-token AFM context is the binding constraint.** For long sessions: rolling map-reduce — slice transcript into ≤2400-token chunks, generate partial telemetries, then reduce with `instructions: "merge contradictions, dedupe themes, rebuild trajectory."` Use `SystemLanguageModel.tokenCount(for:)` (macOS 26.4+) to budget. Recover from `LanguageModelGenerationError.exceededContextWindowSize` by spawning a fresh session seeded with previous summary.

### Triggering
End-of-session detection (90 s input idle), Combine `.debounce(for: 30, ...)` auto-save, manual ⌘⇧D.

### Award angle
**Live "session digest" view paints fields in as `streamResponse` progresses** — themes appear first, emotional trajectory animates onto a timeline, user *watches their session being understood*.

---

## Phase 10 — NightBrain LoRA metabolism

### Recommended implementation
**`mlx-swift-lm 3.31.x`** (LoRATrainingExample app + `llm-tool lora train|fuse|test|eval` subcommands, real APIs in `MLXLLM/Lora.swift`). Training driven from a launchd-triggered Swift helper (separate executable from main app). Dataset assembled in Rust, written to `~/Library/Application Support/<app>/nightbrain/dataset.jsonl`.

**Hyperparameters that work on M2 Pro 18 GB** (4-bit base, e.g., `mlx-community/Mistral-7B-Instruct-v0.3-4bit`): `--num-layers 4–8`, `--rank 4–8`, `--alpha 16`, `--learning-rate 1e-5`, `--batch-size 1`, `--iters 200–600`. **Training time: ~280–350 tok/s on M2 Pro = 15–60 min for 100–1000 examples.**

### Dataset format (verified against `mlx-examples/lora`)
JSONL: `{"text": "..."}`, `{"prompt": "...", "completion": "..."}`, or `{"messages": [...]}`.

### Salience weights schema (concrete)

```json
{
  "schema_version": "1.0",
  "date": "2026-04-25",
  "edits": {
    "ai_suggestions_total": 38, "ai_suggestions_accepted": 22,
    "ai_suggestions_rejected": 12, "ai_suggestions_edited": 4,
    "rejection_clusters": [
      {"theme": "overly_formal_tone", "count": 6, "exemplars": ["chunk_a1b2"], "weight": 0.82}
    ]
  },
  "prompts": {
    "recurring_phrasings": [{"ngram": "summarize but keep the", "count": 9, "tf_idf": 0.34}],
    "vocabulary_drift": {"new_terms_today": ["mycelium","lattice","epistemic"]}
  },
  "sentiment": {"valence_mean": -0.12, "valence_std": 0.41, "arousal_mean": 0.38},
  "friction": {"abandoned_drafts": 3, "rewrite_loops": [...]},
  "training_signal": {
    "lora_eligible_pairs": 31, "preferred_pairs_count": 22,
    "estimated_training_iters": 400, "estimated_minutes_m2_pro": 18
  },
  "decay_signals": {
    "notes_demoted_to_q4": 41, "notes_demoted_to_q2": 8
  }
}
```

### Snapshot management
```
adapters/
  2026-04-23_iter400.safetensors  # daily, keep N=14
  current -> 2026-04-25_iter400.safetensors
fused/
  2026-04-week17.safetensors      # weekly fuse
```
**Fusion threshold: `weekly_loss_delta < -0.03 AND user_regen_rate < 0.10` → fuse.** Rollback if validation loss spikes >20% over 3-day moving average.

### Failure rate reality check on M2 Pro 18 GB

| Failure mode | Rate | Mitigation |
|---|---|---|
| OOM mid-training | 5–15% | `--num-layers 4`, fail-fast, fallback to in-context steering |
| NaN/divergence | 3–8% | Check loss after 50 iters, abort+rollback |
| Insufficient signal (<20 examples) | 30% | 3-day rolling dataset window |
| Adapter degrades inference | 10%/week | 20-prompt validation set, reject merge if worse |
| macOS killed helper (memory/thermal) | 5% | launchd auto-relaunch + checkpoint every 100 iters |

**Aggregate clean run rate ~70–80%.** Always ship in-context-steering fallback (Architecture B from research). Don't surface "your nightly brain is offline" — degrade quietly.

### Alternatives
**(A) RAG-only personalization** — facts only, won't change style. **(B) In-context steering with persona file + few-shot** — no training infra, but token-window bound. **(C) NightBrain LoRA (recommended)** with B as silent fallback.

### ADA angle
*"The first journal that learns you while you sleep. Every night at 3 AM, your Mac trains a LoRA adapter on the day's edits and rejections — fully on device, in ~18 minutes. Wake up to a model that writes more like you and forgets the suggestions you rejected."*

---

## Phase 11 — Omni-contextual brain dumps

### Recommendation: SpeechAnalyzer + SpeechTranscriber as primary, WhisperKit as fallback

**SpeechAnalyzer is real on macOS 26** (`developer.apple.com/documentation/speech/speechanalyzer`, WWDC25 session 277). Modules: `SpeechTranscriber`, `SpeechDetector`, `DictationTranscriber`. **Models live outside app sandbox** in OS asset catalog — zero binary cost, shared across apps, auto-updated. **DictationTranscriber** does NOT require user to enable Siri/keyboard dictation in Settings (UX win over old SFSpeechRecognizer).

**MacStories Yap benchmark: SpeechAnalyzer 2.2× faster than WhisperKit large-v3-turbo** on a 7 GB / 34-min video, comparable accuracy.

### When to use WhisperKit
**WhisperKit 0.15.0** (Nov 2025), distributed via `argmax-oss-swift` umbrella package (bundles WhisperKit + SpeakerKit + TTSKit). Min macOS 14. Use when: (a) supporting macOS 14/15 (pre-26), (b) custom vocabulary needed (SpeechAnalyzer lacks this), (c) multi-channel audio sum.

### Code skeleton (SpeechAnalyzer)
```swift
let transcriber = SpeechTranscriber(locale: .current, preset: .conversational)
try await ensureModel(transcriber: transcriber, locale: .current)
let analyzer = SpeechAnalyzer(modules: [transcriber])
// AVAudioEngine installTap → AsyncStream<AVAudioPCMBuffer> → analyzer.analyze(audio:)
// Iterate `transcriber.results` with isFinal vs volatile distinction
```

### Metal waveform overlay (reuses your `MetalGraphView.swift`)
Ring buffer of FFT bins from `installTap` (lock-free SPSC) → compute shader for per-bar heights → fragment shader for bloom/glow. Drive `CAMetalLayer` at `displaySyncEnabled = true` (60/120 Hz ProMotion). M2 Pro unified memory: pass amplitudes via `MTLBuffer` `storageModeShared` (no copies). **Temporal smoothing `y_t = 0.7·y_{t-1} + 0.3·y_new`** kills jitter.

### Failure modes
Asset not yet downloaded (use `AssetInventory.assetInstallationRequest(supporting:)` with progress UI); AirPods Bluetooth route changes (`AVAudioEngine.configurationChangeNotification`); mic permission denial — graceful keyboard fallback.

---

## Phase 12 — Cognitive sidecar files

### Recommended implementation
**JSON sidecars validated by `jsonschema` crate, schemas derived from Rust structs via `schemars = "0.8"`, watched by `notify = "8.2.0"` + `notify-debouncer-full = "0.7.0"`, codebase exclusion via `ignore = "0.4.25"` (BurntSushi/ripgrep) with explicit allow-list overrides for source files.**

```rust
#[derive(Serialize, Deserialize, JsonSchema)]
#[serde(deny_unknown_fields, rename_all = "camelCase")]
struct EpistemosSidecar {
    schema_version: u16,
    entity_id: Ulid,
    depth: DepthMarker,
    parent_domain: Option<String>,
    derived_from: Vec<Ulid>,
    embeddings: Option<EmbeddingRef>,
    cognitive_meta: CognitiveMeta,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    annotations: Vec<Annotation>,
}
```

### Format choice rationale
**Stay with JSON** (not protobuf/capnp/msgpack) because: (a) human-readable, diff-friendly — *the* differentiator vs. opaque blobs; (b) AFM `@Generable` already exports JSON Schema; (c) 2020-12 `$dynamicRef` supports schema evolution. Use MessagePack (`rmp-serde`) for hot-path internal cache only.

### File watching
`notify` 8.2.0 uses **FSEvents** on macOS by default. `notify-debouncer-full` 0.7.0 coalesces rename pairs and tracks file inode IDs across renames. 400 ms debounce window, expose to user.

### Codebase exclusion (NEVER apply structuring to source)
```rust
let mut ovr = OverrideBuilder::new(&root);
for ext in &["*.swift","*.rs","*.py","*.json","*.ts","*.tsx","*.js","*.yaml","*.toml"] {
    ovr.add(ext)?;  // overrides evaluate before .gitignore
}
let walker = WalkBuilder::new(&root)
    .overrides(ovr.build()?).standard_filters(true)
    .add_custom_ignore_filename(".pkmignore").build();
```

### Failure modes
FSEvents denied on files outside app sandbox (offer `PollWatcher` fallback); high-volume saves (debounce mandatory); schema evolution breakage (`schema_version` per node + per-version migration); sidecar drift on renames (subscribe to `EventKind::Modify(ModifyKind::Name)` and follow); JSON Schema validator memory (compile schemas once, reuse — recompiling on every read is 10–100× regression).

### Award angle
*"Open the file in Finder, edit in any text editor, see your PKM update live."* Killer demo for ADA judges who reward platform integration. Sidecars are inspectable, scriptable, AI-friendly.

---

## Phase 13 — Unstructured data audit (ETL)

### Recommended implementation
**`ignore::WalkParallel` + `rayon` + `xxh3` (or `blake3`) + `apalis-sqlite` + `apalis-cron`.** `apalis 1.0.0-rc.7` (Sept 2025+) — production-ready job queue with Tower middleware and SQLite backend, no Redis dependency.

```rust
const HARDCODED_EXCLUDES: &[&str] = &[
    ".git",".build",".swiftpm","node_modules","target","DerivedData",
    ".venv","__pycache__",".idea",".vscode",
];
const PROGRAMMING_EXTS: &[&str] = &[
    "swift","rs","ts","tsx","js","jsx","py","go","java","kt","c","cpp","h","hpp",
    "m","mm","cs","rb","php","scala","lua","sh","bash","zsh","yaml","yml","toml","lock",
];

fn build_walker(root: &PathBuf) -> ignore::WalkParallel {
    let mut b = WalkBuilder::new(root);
    b.standard_filters(true).hidden(false).require_git(false)
     .threads(num_cpus::get_physical());
    let mut overrides = OverrideBuilder::new(root);
    for ex in HARDCODED_EXCLUDES { overrides.add(&format!("!{ex}/**")).ok(); }
    for ext in PROGRAMMING_EXTS  { overrides.add(&format!("!**/*.{ext}")).ok(); }
    if let Ok(o) = overrides.build() { b.overrides(o); }
    b.build_parallel()
}
```

### Hash choice
**xxh3-128 (`twox-hash 2.x`) for change detection** — 31 GB/s, 128-bit space avoids collisions for vault-sized corpora. Reserve **BLAKE3** (8.4 GB/s, multi-threaded inside a single hash) for cryptographic integrity (signed exports). APFS clone semantics make `mtime` alone unreliable — always combine `(size, mtime, hash)`.

For files >64 KB use `Hasher::update_mmap()` not `read_to_end()` to avoid memory blow-up.

### Failure modes
Symlink loops (`follow_links(false)`); sandbox prompts (request bookmark URL with `URLBookmarkResolutionWithSecurityScope`); iCloud-evicted `.icloud` placeholders (detect and skip); APFS sparse files (`metadata().len()` is logical size, fine for hashing).

### ADA angle
*"Quiet vault-watcher."* Audit runs invisibly, Rosetta Stone moment: *"I noticed 3 new themes in files you forgot you wrote."*

---

## Phase 14 — Intake valve (real-time structural routing)

### Latency budget breakdown (target <500 ms)

| Stage | Budget | Notes |
|---|---|---|
| Pasteboard poll detection | ≤50 ms | macOS does NOT post `NSPasteboard` notifications — only `changeCount` polling at 100 ms |
| Read pasteboard string | <5 ms | Synchronous |
| Pre-filter (length, URL, size) | <2 ms | Local |
| Tier A: deterministic exact-match (FTS5 + Levenshtein) | <10 ms | If hit, route immediately |
| Tier B: NLEmbedding cosine over local embeddings | <30 ms | Only if Tier A misses |
| **Tier C: AFM classification (warm session, cached prefix)** | **300–400 ms** | `@Generable enum IntakeRoute { .matchExisting, .newConcept, .ambient, .noise }` |
| Route + UI flash | <15 ms | SwiftUI |
| **Total** | **~410 ms** | within budget |

**Critical optimization:** keep a single `LanguageModelSession` warm with a prewarmed cached prefix containing the entire ontology summary. `.prewarm()` + reuse avoids ~1 s cold-start.

### Cancellation gotcha (Phase 14 must mitigate)
**Swift `Task.cancel()` does NOT automatically cancel Rust futures via UniFFI** (open issue mozilla/uniffi-rs#2771). Without explicit handling, Rust's tokio runtime keeps running AFM to completion, wasting CPU/battery.

```rust
#[derive(uniffi::Object)]
pub struct ClassifyHandle { cancel: tokio_util::sync::CancellationToken }

#[uniffi::export(async_runtime = "tokio")]
impl KnowledgeCore {
    pub async fn classify_paste(self: Arc<Self>, handle: Arc<ClassifyHandle>, ...) -> Result<()> {
        tokio::select! {
            r = run_pipeline(...) => r,
            _ = handle.cancel.cancelled() => Err(KnowledgeError::Cancelled),
        }
    }
}
```
Swift must call `handle.cancel()` explicitly in `continuation.onTermination`.

### SwiftUI paste interception
`PasteButton + Transferable` only fires on user-initiated paste action. For real intake valve: custom `NSTextView` subclass wrapped in `NSViewRepresentable`, override `paste(_:)`. Polling pasteboard `changeCount` only while app is foreground active.

### Award angle
The "intake valve" feels like fluid intelligence. As you paste, a tiny corner dot pulses cyan ("new"), gold ("matches existing concept — see [link]"), or grey ("ambient — sent to archive"). No modal, no friction — the system has an opinion *before you finish reading*.

---

## Phase 15 — Quarantine architecture

### Recommended implementation
**Two SQLite files, separate GRDB `DatabaseQueue` instances, NEVER joined at the SQL layer.**

```
~/Library/Containers/<app>/Data/
├── Curated.sqlite       ← deterministic, schema-versioned
│   tables: concepts, themes, decisions, sessions, links
└── Quarantine.sqlite    ← raw thoughts, append-only, separate vector index
    tables: raw_entries, voice_transcripts, ambient_pastes
```

Filesystem mirror: `~/PKM/Vault/` (curated, synced) and `~/PKM/RawThoughtsArchive/` (excluded from iCloud via `URLResourceKey.isExcludedFromBackupKey = true`).

### Toggle mechanisms
Per-session: `SessionConfig.includeRaw: Bool` (defaults `false`). Per-conversation: `ConversationState.quarantineMode: .strict | .blended | .raw`. Global: `UserDefaults` with default `.strict`.

### Prompt segmentation (LLM exposure)
Tag every retrieved chunk with `curated:` or `raw:` prefix in the **tool result name itself**, not just metadata. The model's attention is grounded by the role/name of the source, not embedded notes. Wrap raw content in `<raw_user_thought>...</raw_user_thought>` tags + system prompt explicit handling rule.

### Failure modes
**Prompt injection from raw**: pasted email containing "Ignore prior instructions." Mitigation: explicit XML tagging + system rule. **Vector search ranking a raw thought top-1**: separate vector indexes, never co-mingle. **Backup leakage**: explicit `isExcludedFromBackupKey`.

### ADA angle
*"Two minds, one app."* A glass-pane toggle pushes stream-of-consciousness into a parallel shadow vault that the AI **only sees when explicitly invited**. Makes the app safe enough for actual messy thinking.

---

## Phase 16 — Structured conversation state

### Verified Anthropic compaction APIs
- **`clear_thinking_20251015`** — context-editing strategy. Default `keep: {type: "thinking_turns", value: 1}`. Set `keep: "all"` for max cache hits. Beta header: `context-management-2025-06-27`. Must be **first** in `edits` array. **Requires `thinking` enabled — else 400.**
- **`clear_tool_uses_20250919`** — clears old tool results.
- **`compact_20260112`** — server-side full conversation compaction. Beta header `compact-2026-01-12`. Triggers at configurable `input_tokens` threshold; replaces history with model-generated summary. Works on `claude-opus-4-7`. Supports `pause_after_compaction`.

**Anthropic explicitly recommends server-side compaction over client-side SDK control** unless you need fine-grained client behavior. Anthropic's own April 2026 retro shipped `keep:1` *every turn* not once → cache misses every request. **If you implement client-side compaction, ensure it's idempotent and triggered once per threshold cross.**

### Recommended pattern: real-time stenographer
Dedicated AFM 3B "stenographer" task continuously updates `conversation_state.json` after every user turn. Reasoning model receives **only structured state + last 2 turns**, never full raw transcript.

```swift
@Generable struct ConversationState: Equatable {
    @Guide(description: "Single sentence the user is currently arguing for.")
    let activeThesis: String
    @Guide(.count(0...20)) let resolvedNodes: [ResolvedNode]
    @Guide(.count(0...8))  let openLoops: [OpenLoop]
    @Guide(.count(0...5))  let emotionalTrajectory: [Beat]
    @Guide(.count(0...30)) let referencedConcepts: [String]
    @Guide(description: "Compressed semantic vector summary, ≤120 chars.")
    let semanticGist: String
    let turnsCovered: Int
    @Guide(description: "0–100") fidelity: Int

    @Generable struct ResolvedNode: Equatable {
        let claim: String
        @Guide(.anyOf(["accepted","rejected","reframed","tabled"])) let resolution: String
        @Guide(description: "Verbatim user phrase ≤80 chars.") let evidence: String
    }
    @Generable struct OpenLoop: Equatable {
        let question: String
        @Guide(.anyOf(["awaiting_user","awaiting_data","contested","blocked"])) let status: String
        let raisedAtTurn: Int
    }
}
```

### Token economics
50-turn conversation: raw transcript ~15–25k tokens; structured state ~600–1200 tokens. **~95% token reduction.** Always retain raw transcript on disk — this is a *projection*, not a replacement.

### Failure modes
Stenographer drift (every 10 turns, re-derive from raw and diff; surface drift to user). State staleness (turn-versioned state; either await before reasoner call or accept N-1 staleness for streaming). Lossy emotional trajectory (capture verbatim quotes in `evidence` fields).

### ADA angle
*"Conversations that remember themselves."* User scrolls a structured timeline — active thesis pinned to top, resolved nodes collapsing into checkmarks, open loops glowing. User edits `activeThesis` directly to *steer* the AI's frame mid-conversation.

---

## Cross-cutting A — Apple Foundation Models deep dive

**Available macOS 26+ only** (Tahoe). macOS 15 Sequoia does NOT ship the model assets. Underlying model: ~3B params, 2-bit quantized (per Apple ML Research July 2025 tech report), updated July 17, 2025 with PT-MoE server companion (PCC only; not exposed to FMF API).

### Verified PCC fact
**Apple DTS engineer (developer.apple.com/forums/thread/809497):** "Currently the Foundation Models framework only has access to the on-device model. **PCC is never used. Ever.**" For an M2 Pro PKM app: zero risk of cloud egress through FMF, but no fallback if on-device is too small.

### Hard limits
- **4096 tokens combined input + output.** `LanguageModelGenerationError.exceededContextWindowSize`. Use `model.tokenCount(for:)` to budget (macOS 26.4+).
- **No multimodal input** as of 26.4 (text-only).
- **Guardrails are mandatory and cannot be disabled.**
- Streaming is via `T.PartiallyGenerated` snapshots — **no token-level callbacks exposed.**

### Adapter framework
`.fmadapter` packages (~160 MB typical), LoRA rank 32, `Foundation Models Adapter Training Toolkit` (Python, requires Mac w/ ≥32 GB RAM or Linux GPU). Distribution via Background Assets. **Production deployment requires the Foundation Models Framework Adapter Entitlement** (request via Apple Developer Account Holder).

⚠️ **Adapter ID regex: `/fmadapter-\w+-\w+/`** — undocumented; hyphens in adapter names break loading.

### Cold start
Model assets NOT loaded into daemon until first request after boot — count on **1–3 second cold start**. Use `session.prewarm(promptPrefix:)` on app launch.

---

## Cross-cutting B — MLX-Swift state of the art

### Versions (April 2026)
- `mlx-swift = "0.31.3"` (released ~23 Mar 2026). Tracks Python MLX.
- `mlx-swift-lm = "3.31.3"` (released 15 Apr 2026). LLM/VLM/Embedder code lives here now (split out late 2025).
- Requires Xcode 16+, Swift 6.1 tools-version, macOS 14+ runtime.

### Architecture support (verified in mlx-swift-lm)
Llama 3/3.2, Mistral 1/2/3, Mixtral, Phi 1–3.5, Gemma 2/3/3-Embedding/4, Qwen 1.5/2/2.5/3/3-Next/3.5/3.5 MoE, GLM 4.6/4.7/Flash/OCR, DeepSeek V3, GPT-OSS (MXFP4), MiniCPM, MiniMax, NemotronH, OLMo 3, LFM2/2.5, Apertus, AfMoE (Arcee), Jamba, SmolLM. VLMs: Qwen2/3-VL, Pixtral, GLM-OCR, Gemma 4 vision, LFM2 VL.

**Native: HuggingFace `safetensors`. GGUF NOT supported as input** (Python `mlx_lm` can convert from gguf as one-time import; Swift runtime expects safetensors).

### Quantization
`affine` (default), `nvfp4`, `mxfp8`. Bits typically 2/3/4/6/8, group sizes 32/64/128. Default `mlx-community/*-4bit` repos: affine, 4-bit, group_size=64. **`QuantizedKVCache` exists** with configurable `kv_bits` group size.

### Speculative decoding
**Added in mlx-swift-lm 3.31.3** (PR #173). KV caches support `copy()` (PR #158) and serialization round-trip (PR #121, #155) — enables "fork session" patterns.

### LoRA training
`LoRATrainingExample` macOS app + `llm-tool lora train|test|fuse|eval` subcommands. ~250 tok/s on M1 Max for 7B, ~475 on M2 Ultra → realistic ~280–350 on M2 Pro 18 GB at batch=1, num-layers=4–8 with 4-bit base. **DoRA** and full fine-tuning also available.

### ANE
**MLX does NOT use the Apple Neural Engine.** GPU-only (Metal). For battery-sensitive background work, Core ML on ANE wins (Community projects ANEMLL, john-rocky/CoreML-LLM achieve 47–62 tok/s for 1B at ~2 W vs ~20 W GPU). For active foreground throughput, MLX-on-GPU wins.

---

## Cross-cutting D — Multi-agent CLI integration

See Phase 3 above. Key per-CLI capability summary:

| Capability | Claude Code | Codex | Kimi | Hermes |
|---|---|---|---|---|
| Native NDJSON event stream | ✅ | ✅ | ✅ | ⚠️ via api-server |
| Constrained output schema | ✅ `--json-schema` | ✅ `--output-schema` | ❌ | ❌ |
| Session resumption | ✅ `--continue/--resume` | ✅ `exec resume` | ✅ `--continue` | ✅ `--continue` |
| MCP client + server | ✅ | ✅ | ✅ | ✅ |
| Open source | ❌ | ✅ Rust (`openai/codex`) | ✅ Python | ✅ Rust |
| OAuth subscription auth | Anthropic Pro | ChatGPT | Moonshot | Codex/Copilot/Nous Portal/OpenRouter |

**Codex's source-available status is a strategic asset** — vendor `codex-rs` as a Cargo dependency to skip the binary entirely if needed.

---

## Cross-cutting E — UniFFI streaming patterns

### Pin `uniffi = "0.29.5"`
Versions 0.30.0 (2025-10-08) and 0.31.0 (2026-01-14) introduce method-checksum changes and value-type methods on records/enums you may not need. Set `experimental_sendable_value_types = true` in `uniffi.toml`.

### Pattern matrix

| Pattern | Latency (estimated) | Use case |
|---|---|---|
| Sync `#[uniffi::export] fn` | ~0.5–10 µs | Cheap pure-Rust calls |
| Async `async fn` round-trip | ~30–100 µs | Single request/response (LLM, FS, DB) |
| **Foreign callback interface + Swift `AsyncThrowingStream` adapter** | ~3–8 µs/event, ~50–200k events/s | **Recommended for streaming** |
| Object handle + polling | High | Anti-pattern, avoid |

**All numbers ESTIMATED, not measured on this stack.** Build a benchmark harness early. UniFFI maintainers acknowledge historical "favored features over performance" stance with FFI 1.0 / FFI v2 redesign in progress (issues #2155, #2752).

### Required cancellation pattern
**Swift `Task.cancel()` does NOT automatically cancel Rust futures** (issue #2771, open). Ship explicit `CancellationToken` handle objects.

### Issue #2818 (Swift 6.2 / Xcode 26 isolation conflict)
**Open since Feb 11, 2026, no fix shipped.** With `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`, generated bindings fail to compile. **Best workaround: place UniFFI bindings in a separate SwiftPM target with `defaultIsolation(nil)` (nonisolated), let your app target run with `defaultIsolation(MainActor.self)`.** Alternative: `sed` post-process build phase prepending `nonisolated`.

### Concurrency layout for Epistemos
- `AgentViewModel` — `@Observable` + implicit `@MainActor` (Xcode 26 default)
- `KnowledgeStore` — custom `actor` with `nonisolated` accessors delegating to UniFFI types
- `BootstrapBuilder` — `nonisolated struct`

---

## Cross-cutting F — Token usage optimization playbook

### Decision tree
- **Static across requests** (system, tools, persona, large doc) → **Prompt caching**
- **Large but only sometimes needed** (knowledge base) → **Tool-use retrieval** (beats eager RAG for agentic flows)
- **Stable persona/style** (and self-host) → **LoRA**
- **Long bloated text** → **LLMLingua-2 compression**
- **Otherwise** → just send it

### Quantitative savings

| Lever | Savings |
|---|---|
| Anthropic 5-min cache hit | **~90%** on cached tokens (1.25× write cost) |
| Anthropic 1-h cache hit | ~90% on cached tokens (2× write cost; break-even ≈ 2 hits) |
| OpenAI cache hit | **50%** baseline (cookbook claims up to 90% on newest models) |
| Kimi (Moonshot) cache hit | **75–83%** on input cost |
| LLMLingua-2 compression | 2–20× token reduction; ~50–80% input cost reduction |
| Tool-use retrieval vs full-context | ~99% input reduction on retrieved part |
| LoRA persona vs system prompt | Eliminates 500–2,000 tokens *every* call |

### What does NOT work
- **No major commercial provider accepts raw embeddings as conversational input.** Vector context substitution is research-only.
- **Hot-swap system prompts without breaking cache** — impossible. Single character drift = full miss.
- **Pause and inject mid-stream** — no provider exposes the primitive.

---

## Cross-cutting G — Apple Design Award strategy

### 2026 status
**ADA winners not yet announced as of April 26, 2026.** WWDC 2026 = June 8–12. ADA reveal expected late May / first week June 2026. Any "2026 ADA winner" claim is fabricated.

### 2025 winners — pattern analysis
Innovation app: **Play** (SwiftUI prototyping). Visuals & Graphics app: **Feather: Draw in 3D**. Notable AFM-using finalists: **CellWalk** (uses Foundation Models for dynamic scientific text). **Apple has skipped pure-genAI apps two years running** — they prefer apps that *use* AFM to enhance a non-AI core experience.

### Apple PR'd 7 AFM-using apps in Sept 2025
SmartGym, Stoic, VLLO, Grammo, Stuff, CellWalk, Lil Artist. **Going hard on AFM is aligned with Apple's 2026 marketing priorities.**

### Recommended ADA category for Epistemos
**Innovation (primary), Visuals & Graphics (backup).** Innovation rewards "novel use of Apple technologies that set them apart in their genre" — Foundation Models + Metal graph + on-device LoRA fits exactly.

### Submission mechanics
**There is no public ADA submission form.** Apps must be on the App Store; selection is by Apple's editorial team. Visibility levers: (a) **App Store Connect Featuring Nominations** ~3 months before WWDC (i.e., March 2026 for June 2026 reveal), (b) Today/Discover tab, (c) dev relations contact.

### Required engineering polish for editor's eye
macOS Tahoe Liquid Glass adoption, App Intents, Spotlight integration, Quick Look for sidecar files, Shortcuts actions, Live Activities (mobile companion), VoiceOver + Dynamic Type + Reduce Motion *actually working*.

### Demo video structure (60–90 sec)
1. **0:00–0:05** Cold open: live Metal graph animation, ~1000 nodes pulsing
2. **0:05–0:35** Native moment: type a thought → AFM streams → graph node materializes → connects. 60fps.
3. **0:35–0:55** Decay moment: time-lapse of unused notes physically dimming and shrinking.
4. **0:55–1:15** Privacy moment: airplane mode ON, everything still works. Activity Monitor shows AFM on Neural Engine.
5. **1:15–1:25** Open `.epistemos.json` in TextEdit. *"Your data, your files. Forever."*
6. **1:25–1:30** Logo.

**Hide:** Rust ("performance core"), cloud LLMs (de-emphasize, lead on-device), multi-agent CLI orchestration (powerful but reads as chaotic — save for hackathons).

---

## Cross-cutting H — Hackathon strategy

### 2024–2026 winning patterns (cross-referenced from Microsoft AI Agents Hackathon, Kong Agentic, Global Agent Hackathon, ODSC-Google Cloud)
1. Solve a real problem with named user
2. Working demo in first 30 seconds
3. Visible reasoning trace ("transparent agent decisions")
4. Multi-agent orchestration is now table stakes — but *named, role-differentiated* agents win
5. Local-first / privacy is increasingly a moat
6. Document architecture during, not after

### 5-minute demo arc for Epistemos

| Time | Beat |
|---|---|
| 0:00–0:30 | Type one sentence → AFM streams entities → graph nodes snap-connect in Metal → multi-agent status bar shows `[Claude: summarizing] [Codex: tagging] [MLX: linking] [Local: storing]` → `Sarah.epistemos.json` appears in Finder |
| 0:30–1:30 | Toggle Wi-Fi off, keep typing — everything still works. *"Four AI agents in parallel via PTY. The 3B Foundation Model on Neural Engine — zero cloud."* |
| 1:30–2:30 | **Money shot — decay**: fast-forward 30 days on 2000-node graph. Old nodes dim and shrink. *"Ebbinghaus curve, applied to vector magnitudes, rendered in Metal."* |
| 2:30–3:30 | JIT retrieval: ask "What did Sarah and I conclude about Metal renderers?" → agent visibly traverses graph mid-thought → annotated tool calls |
| 3:30–4:15 | Open `~/Epistemos/Sarah.epistemos.json` in `vim`. Edit. Save. Graph updates live. *"Plain JSON. `git diff`-able. No lock-in."* |
| 4:15–5:00 | NightBrain tease: *"Tonight while you sleep, your Mac fine-tunes a personal LoRA on what you wrote today."* |

### Sprinkle technical sophistication
Activity Monitor: Neural Engine pegged at 80%. `top`: 150 MB resident, 0.3% CPU at idle (Obsidian is 600 MB). Casually mention Swift 6 strict concurrency, UniFFI, sqlite-vec + petgraph, MetalKit, WhisperKit, MLX-Swift, Foundation Models `@Generable` + tool-calling, Liquid Glass.

---

## Phase integration matrix

| Phase | Feeds | Fed by | Critical path |
|---|---|---|---|
| 1 (Ontology) | 8, 9, 13, 14, 16 | — | **Yes** |
| 2 (Decay) | 8, 10 | 1 | **Yes** |
| 3 (CLI Bridge) | 7 | 4 (bootstrap) | Optional v1 |
| 4 (Bootstrap) | 5, 6, 7 | — | **Yes (cheap)** |
| 5 (Hybrid Brain) | 1, 6, 9, 14, 16 | 4 | **Yes** |
| 6 (JIT Injection) | 7 | 1, 5, 8 | Reduce-scope to tool-use |
| 7 (Hermes Orchestrator) | All workers | 3, 4, 6 | v1.5 |
| 8 (Depth/Graph) | 12, 14, 15 | 1, 2 | **Yes** |
| 9 (Distillation) | 16, 10 | 1, 5 | v1.5 |
| 10 (NightBrain LoRA) | — | 9, 12 | **Defer to v1.5** |
| 11 (Voice Dumps) | 12, 14 | — | v1.5 |
| 12 (Sidecars) | 13, 14, 15 | 1, 8 | **Yes** |
| 13 (ETL Audit) | 12 | 12 | v1.5 |
| 14 (Intake Valve) | 8, 12, 15 | 1, 5, 8 | **Yes** |
| 15 (Quarantine) | All cloud calls | 11, 12, 14 | **Yes (architectural)** |
| 16 (Conversation State) | All cloud calls | 1, 5, 9 | v1.5 |

---

## Risk register & deprecated/superseded callouts

| Original assumption | Reality (April 2026) | Action |
|---|---|---|
| BGTaskScheduler for 3 AM wake | **Does not exist on macOS** (`API_UNAVAILABLE(macos)`) | Use `SMAppService.agent` + launchd `StartCalendarInterval` |
| Mamba/SSM for summarization | User reports failure; respect that | Standard transformers (Mistral 7B 4-bit, Qwen3, Llama 3.2) |
| MLX uses ANE | **MLX is GPU-only** | Use Core ML for battery-sensitive background; MLX for foreground throughput |
| GGUF in MLX-Swift | **Not supported as input** | Convert to safetensors via Python `mlx_lm`; ship safetensors only |
| ButterflyQuant / TurboQuant / Kitty libraries | **No Apple Silicon implementations exist**; papers only or CUDA/Triton | Use candle's GGUF Q-types (Q8_0, Q4_K, Q2_K) |
| Pause-mid-stream-and-inject for JIT | **No provider exposes the primitive** | Tool-use-based retrieval with interleaved thinking |
| Hot-swap system prompts | **Cache invalidation; cannot be done losslessly** | Cache-first design; treat system as immutable per-conversation |
| Embedding inputs as LLM context | **No commercial provider supports this** | Tool-use + local vector index → text retrieval |
| Anthropic prefill on Claude 4.6+ | **REMOVED — returns 400** | Use `output_config.format` for JSON shaping |
| Default Anthropic cache TTL = 1 h | **Silently changed to 5 min in March 2026** | Always pass `ttl: "1h"` explicitly |
| Anthropic FMF uses Private Cloud Compute | **DTS confirmed: PCC never used** | No cloud egress concern; no PCC fallback either |
| Swift 6 strict concurrency works cleanly with UniFFI | **Issue #2818 open since Feb 2026** | Separate SwiftPM target with `nonisolated` defaults |
| Swift `Task.cancel()` cancels Rust futures | **Does not — issue #2771** | Explicit `CancellationToken` handle pattern |
| AFM context window ≥ 8k | **4096 hard limit** | Map-reduce chunking; use `tokenCount(for:)` to budget |
| AFM models bundled in macOS Sequoia | **Sequoia ships NO model assets** | Require macOS 26 Tahoe minimum, gate via `SystemLanguageModel.default.availability` |
| `mlx_lm.lora` Swift bindings | **No literal Swift API of that name** — equivalent functionality is in `mlx-swift-lm` `MLXLLM/Lora.swift` | Use mlx-swift-lm package targets |
| `claude-cookbooks` GBNF easy mixing of `oneOf+properties` | **Not supported** | Stick to flat schemas or use `@Generable`-derived schemas |

---

## Final implementation contract

**Build order (12-month plan, optimized for ADA submission March 2026 → June 2026 reveal):**

**Months 1–3 (foundation):** Phase 1 (AFM `@Generable` ontology) → Phase 8 (sqlite-vec + petgraph + Metal graph) → Phase 12 (sidecars + notify + ignore) → Phase 4 (bootstrap with cache padding to 1100+ tokens) → Phase 5 (hybrid brain orchestrator with thermal/battery/GPU-contention policy).

**Months 4–6 (sensory + structure):** Phase 14 (intake valve with <500 ms target, explicit cancellation token) → Phase 15 (two-DB quarantine) → Phase 11 (SpeechAnalyzer + Metal waveform) → Phase 2 (FSRS-6 + candle Q-types tier cascade + launchd LaunchAgent).

**Months 7–9 (orchestration + intelligence):** Phase 3 (CLI bridge with pty-process) → Phase 6 (tool-use retrieval, NOT pause-and-inject) → Phase 9 (`@Generable SessionTelemetry`) → Phase 16 (real-time stenographer).

**Months 10–12 (defensibility + polish):** Phase 7 (Hermes Chief of Staff via rmcp 0.16) → Phase 13 (apalis-sqlite ETL with xxh3) → Phase 10 (NightBrain LoRA — quietly, with in-context fallback always engaged) → ADA polish (Liquid Glass, App Intents, Quick Look, accessibility audit).

**Three things to do first this week:**
1. Pin `uniffi = "0.29.5"` and stand up Issue #2818 mitigation (separate SwiftPM target with nonisolated defaults). Without this, every other Swift 6 build is broken on Xcode 26.
2. Build a benchmark harness measuring AFM `@Generable` round-trip latency, MLX Qwen3 0.6B 4-bit tok/s under thermal pressure, sqlite-vec KNN at 100k vectors, and UniFFI callback throughput. Numbers in this report are estimates; measure your stack.
3. Pad the existing 800-token BootstrapPacket to ≥1,100 tokens of stable content and verify cache hits via `cache_creation_input_tokens` / `cache_read_input_tokens` telemetry. Without padding, you have no caching at all.

The architecture is sound, the platform is ready, and the moat (native Apple Silicon + on-device AI + filesystem-transparent + graph-native) is genuinely defensible. The hardest work is not the build — it's the discipline to refuse phases (6's pause-and-inject; 10's premature LoRA demo) that the platform won't let you ship as designed.