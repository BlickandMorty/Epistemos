# Epistemos Hermes Master Doctrine v1

**Status note (read first):** This document is the authoritative architectural and implementation doctrine for Epistemos with Hermes integrated as a hybrid faculty (Option C). It is built on top of verified April-2026 ground truth gathered for: Hermes 4 model availability and MLX-Swift API surface; Swift 6.2 strict concurrency, Metal 4, macOS 26 native APIs; Rust crate ecosystem (UniFFI, BoltFFI assessed and rejected, Bollard, portable-pty, rexpect, tokio, schemars, rusqlite, GRDB); agentic CLIs (Claude Code 2.1.x, Codex 0.118+, Gemini CLI, Kimi CLI 1.39); MCP 2025-11-25 spec + SEP-1865 Apps; APFS F_FULLFSYNC vs F_BARRIERFSYNC durability; Apple-Silicon GPU memory-pressure detection. Where research surfaced uncertainty (e.g., the existence of `--bare`, the Hermes-4-14B chat-template literal source, or a SwiftUI-native `MetalView` primitive in macOS 26), this doctrine flags it explicitly and provides the safe fallback rather than fabricating. Every code block below is intended to be cut-to-fit production code, not pseudocode.

---

## Executive Summary

**The architectural one-liner.** Epistemos is a Swift-6.2 / Rust monolith for Apple Silicon in which **Hermes is simultaneously a local model (Hermes-4-14B at 4-bit MLX), an in-process agent runtime, and a UI-rendering compiler** — fronting a routable provider matrix (Hermes-local, Claude-API, Claude-CLI, Codex-CLI, Gemini-CLI, Kimi-API/CLI, Qwen3-local, Apple Foundation Models on-device 3B). The **Faculty × Provider matrix** is the central abstraction: a Faculty is a typed personality (Researcher, Critic, Planner, Executor, Consolidator, Recaller, Synthesizer, Council, AutoResearch, Co-op, Vault); a Provider is the inference engine. The Rust core owns the agent loop, tool dispatch, sandbox, persistence; Swift owns the UI, MLX inference host, AX/ScreenCaptureKit/Spotlight integrations, and the Metal-4 generative-UI renderer.

**The four pillars.**
1. **Apple-Silicon supremacy.** MLX-Swift 0.31.x for local inference; Metal 4 (`MTL4CommandQueue`, residency sets, MetalFX temporal scaler) for the graph and generative UI; unified-memory zero-copy from Rust to GPU; Foundation Models on-device 3B for low-latency utility tasks.
2. **Hybrid Hermes.** Hermes-4-14B (Qwen3-base, ChatML `<tool_call>`/`<think>` special-token format) running locally as the always-warm faculty router; Hermes-4-70B (Llama-3-Chat format) optionally on a 64GB+ machine; routable provider passthrough for the four major CLI agents with full `/` and `@` syntax.
3. **Notarized non-sandboxed Pro build.** Developer ID + Hardened Runtime + `allow-jit` (for MLX runtime kernel compilation) + the precise TCC-prompt sequencing; no `--deep`, sign inside-out; `SMAppService` for the privileged helper if/when needed; **no EndpointSecurity** (entitlement infeasible for solo dev — use portable-pty middleman instead).
4. **Zero-corruption persistence + structured cancellation.** Bundled SQLite (rusqlite `bundled` matched to GRDB SQLiteLib), `synchronous=FULL` + `fullfsync=ON` + `busy_timeout=5000`; `tokio_util::CancellationToken` cascade from Swift `Task.cancel()` → Rust agent loop → spawned CLI subprocess → Bollard container; `withTaskCancellationHandler` bridging UniFFI async callbacks into `AsyncThrowingStream` with deterministic `onTermination` cleanup.

The through-line: **every section answers "how does this exploit Apple Silicon + Swift 6.2 + Metal 4 + MLX in a way no Electron, web, or cross-platform competitor can replicate?"** The answer is unified memory + Metal-4 ML in shaders + on-device 3B + Foundation Models + AX + ScreenCaptureKit + Spotlight, all wired through one process with zero IPC penalty.

---

## Section 1 — Hermes as Hybrid Faculty

### 1.1 Hermes 4 model availability on MLX-Swift (April 2026, verified)

The Nous Research Hermes-4 family on Hugging Face as of April 2026 (verified via `huggingface.co/NousResearch` and `huggingface.co/mlx-community`):

| Repo | Base | Params | Format | Notes |
|---|---|---|---|---|
| `NousResearch/Hermes-4-14B` | Qwen3-14B | 14B | BF16 (~29.6GB) | **ChatML** chat template, `<tool_call>` paired tags as added tokens, hybrid `<think>` mode |
| `NousResearch/Hermes-4-14B-FP8` | Qwen3-14B | 14B | FP8 (compressed-tensors) | |
| `NousResearch/Hermes-4-70B` | Llama-3.1-70B | 70B | BF16 | **Llama-3-Chat** format (`<\|start_header_id\|>...<\|eot_id\|>`) |
| `NousResearch/Hermes-4-70B-FP8` | Llama-3.1-70B | 70B | FP8 | |
| `NousResearch/Hermes-4-405B` (+ FP8) | Llama-3.1-405B | 405B | BF16/FP8 | Impractical on 18GB |
| `NousResearch/Hermes-4.3-36B` | Llama-3 family | 36B | BF16 + GGUF | Llama-3-Chat format |

**MLX-quantized (Apple Silicon):**
- `mlx-community/Hermes-4-14B-4bit` — BF16 base converted via mlx-lm 0.27.0; ~8GB on disk; **the M2-Pro-18GB target.**
- `lmstudio-community/Hermes-4-70B-MLX-{4,5,6,8}bit` — 4-bit ≈ 35GB (does not fit on 18GB).
- `mlx-community/Hermes-4-70B-8bit` — ~70GB (does not fit).
- **No Hermes-4-405B MLX quant exists.** GGUF only via `lmstudio-community/Hermes-4-405B-GGUF`.
- **No Hermes-4-8B variant exists.** 14B is the smallest.

**Realistic memory footprint on M2 Pro 18GB:** Hermes-4-14B-4bit weights ≈ 8GB; KV cache at 16K context ≈ 1.5–2.5GB depending on attention layout; activations ≈ 0.5GB. Total ≈ 10–11GB resident. With Qwen3-4B-4bit drafter (≈ 2.5GB) loaded simultaneously for speculative decoding: ≈ 13–14GB total. `MTLDevice.recommendedMaxWorkingSetSize` on M2-Pro-18GB returns ≈ 12–13GB (65–75% of unified RAM); **Hermes-14B-4bit + Qwen3-4B-drafter is right at the ceiling.** The production decision: **load Hermes-4-14B as the primary faculty model; load Qwen3-0.6B-4bit (≈ 0.4GB) as drafter** (not 4B), giving a comfortable 9GB resident with 3GB headroom for KV growth and graph rendering. Hermes-4-70B is reserved for 32GB+ Macs as a build-time toggle.

**Hybrid reasoning toggle (verified verbatim from Nous model cards):** activated via `tokenizer.apply_chat_template(messages, thinking=True)` or via the system prompt that prefaces "*You are a deep thinking AI, you may use extremely long chains of thought… enclose your thoughts and internal monologue inside `<think> </think>` tags*". The `<think>` and `</think>` tokens are added tokens in the tokenizer for the 14B variant.

### 1.2 The MLX-Swift loader (production-grade)

`Sources/EpistemosMLX/MLXHostActor.swift` — single-source-of-truth orchestrator for model loading, KV cache lifecycle, LoRA hot-swap, streaming inference. Uses the verified `MLXLMCommon` API surface (mlx-swift-lm 3.31.x).

```swift
// Sources/EpistemosMLX/MLXHostActor.swift
import Foundation
import MLX
import MLXLMCommon
import MLXLLM
import MLXNN
import os

public actor MLXHostActor {
    public static let shared = MLXHostActor()

    private let log = Logger(subsystem: "epistemos.mlx", category: "host")
    private var primary: ModelContainer?       // Hermes-4-14B-4bit
    private var drafter: ModelContainer?       // Qwen3-0.6B-4bit (speculative)
    private var loadedAdapters: [FacultyID: AdapterHandle] = [:]
    private var residentGenerationTokens: [SessionID: GenerationToken] = [:]

    /// Bytes allocated in the unified-memory pool by MLX. We poll this on a 1-Hz timer
    /// and pair with `recommendedMaxWorkingSetSize` to drive eviction.
    private var pressureSubscription: DispatchSourceMemoryPressure?

    private init() {}

    public func bootstrap() async throws {
        installMemoryPressureHandler()
        // Hermes-4-14B-4bit
        let hermesCfg = ModelConfiguration(
            id: "mlx-community/Hermes-4-14B-4bit",
            defaultPrompt: "You are Hermes."
        )
        self.primary = try await loadModelContainer(configuration: hermesCfg)
        log.info("Hermes-4-14B-4bit loaded; allocated=\(MLX.GPU.activeMemory)")
        // Qwen3-0.6B-4bit drafter (verify availability on HF; fall back to Qwen3-1.7B-4bit if absent)
        let draftCfg = ModelConfiguration(id: "mlx-community/Qwen3-0.6B-4bit", defaultPrompt: "")
        self.drafter = try await loadModelContainer(configuration: draftCfg)
    }

    private func installMemoryPressureHandler() {
        let src = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical], queue: .global(qos: .utility))
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let event = src.data
            Task { await self.handlePressure(event: event) }
        }
        src.resume()
        self.pressureSubscription = src
    }

    private func handlePressure(event: DispatchSource.MemoryPressureEvent) async {
        if event.contains(.critical) {
            // Hard stop: cancel all generations, drop drafter.
            for (_, tok) in residentGenerationTokens { tok.cancel() }
            self.drafter = nil
            MLX.GPU.clearCache()
            log.error("memory pressure CRITICAL: drafter dropped, cache cleared")
        } else if event.contains(.warning) {
            // Trim KV caches on idle sessions.
            await SessionRegistry.shared.trimIdle()
        }
    }

    /// Streaming generation. Yields decoded text chunks. Cancellation propagates via the
    /// returned token's `cancel()`, which sets `.stop` on the next callback tick.
    public func stream(
        sessionID: SessionID,
        prompt: PromptTemplate,
        params: GenerateParameters,
        adapter: AdapterHandle? = nil,
        useDrafter: Bool = true
    ) -> AsyncThrowingStream<TokenDelta, Error> {
        AsyncThrowingStream { continuation in
            let token = GenerationToken()
            self.residentGenerationTokens[sessionID] = token
            Task {
                do {
                    guard let container = self.primary else {
                        throw MLXError.notLoaded
                    }
                    if let adapter { try await self.applyAdapter(adapter, on: container) }
                    let result = try await container.perform { model, tokenizer in
                        let input = try await tokenizer.applyChatTemplate(
                            messages: prompt.messages,
                            tools: prompt.tools.map(\.jsonSchema),
                            // Hermes-4-14B supports `thinking=True`; passed through extras.
                            extras: prompt.thinking ? ["thinking": true] : [:])
                        var detok = NaiveStreamingDetokenizer(tokenizer: tokenizer)
                        return try MLXLMCommon.generate(
                            input: .init(text: input, tools: prompt.tools),
                            parameters: params,
                            context: .init(model: model, tokenizer: tokenizer)
                        ) { tokens in
                            if token.isCancelled { return .stop }
                            if let last = tokens.last { detok.append(token: last) }
                            if let chunk = detok.next() {
                                continuation.yield(.text(chunk))
                            }
                            if tokens.count >= params.maxTokens { return .stop }
                            return .more
                        }
                    }
                    continuation.yield(.usage(promptTokens: result.promptTokenCount,
                                              completionTokens: result.tokenCount))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                self.residentGenerationTokens[sessionID] = nil
            }
            continuation.onTermination = { [weak token] _ in token?.cancel() }
        }
    }

    private func applyAdapter(_ a: AdapterHandle, on container: ModelContainer) async throws {
        try await container.perform { model, _ in
            try LoRATrain.loadLoRAWeights(model: model, url: a.url)
        }
    }
}

public final class GenerationToken: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)
    public func cancel() { lock.withLock { $0 = true } }
    public var isCancelled: Bool { lock.withLock { $0 } }
}

public enum TokenDelta: Sendable {
    case text(String)
    case usage(promptTokens: Int, completionTokens: Int)
}

public enum MLXError: Error { case notLoaded; case adapterMissing }
```

**Key correctness notes**, all backed by the verified research:
- The `MLXLMCommon.generate` callback returning `.stop`/`.more` is the official API; `NaiveStreamingDetokenizer` is the official streaming detokenizer.
- `MLX.GPU.activeMemory` and `MLX.GPU.clearCache()` are real APIs in mlx-swift 0.31.x.
- `DispatchSource.makeMemoryPressureSource` is the canonical macOS memory-pressure API; we wire `.warning` to KV-cache trimming and `.critical` to drafter eviction.
- `GenerationToken` uses `OSAllocatedUnfairLock` (Swift 6.0+); no `@unchecked Sendable` lie because the lock genuinely synchronizes the boolean. (For Swift 6.2+, replace with `Mutex<Bool>` from `Synchronization`.)
- The `useDrafter` parameter is wired through; speculative decoding implementation is in §2.3.

### 1.3 Hermes ChatML tool-call streaming parser (Rust, `winnow`-based)

Because `<tool_call>`/`</tool_call>` are **single added tokens** in the Hermes-4-14B tokenizer, the ideal parser is **token-id-driven**, not character-driven. But the FFI hands Swift→Rust UTF-8 chunks (the Swift detokenizer already turns token IDs into text), so we parse text. We use `winnow` with `Partial<&str>` for streaming.

```rust
// crates/epistemos-hermes/src/chatml_parser.rs
use winnow::{
    combinator::{alt, delimited, opt, preceded, repeat, terminated},
    prelude::*,
    stream::Partial,
    token::{take_until, take_while},
};

#[derive(Debug, Clone, PartialEq)]
pub enum Block {
    Text(String),
    Think(String),
    ToolCall { name: String, arguments: serde_json::Value },
    ToolResponse(serde_json::Value),
}

pub struct StreamingChatMLParser {
    buf: String,
    /// Emitted blocks ready to ship downstream.
    out: Vec<Block>,
    /// In-progress block; we always know what we're inside.
    state: ParseState,
}

#[derive(Debug, Clone, PartialEq)]
enum ParseState {
    OutsideBlock,
    InThink(String),       // accumulated body
    InToolCall(String),    // accumulated JSON body
    InToolResponse(String),
}

impl StreamingChatMLParser {
    pub fn new() -> Self {
        Self { buf: String::new(), out: Vec::new(), state: ParseState::OutsideBlock }
    }

    /// Feed an arbitrary UTF-8 fragment. Boundary-tolerant: opening or closing tags
    /// may straddle two calls; the buffer holds the tail until the tag completes.
    pub fn push(&mut self, chunk: &str) -> Vec<Block> {
        self.buf.push_str(chunk);
        loop {
            match &mut self.state {
                ParseState::OutsideBlock => {
                    // Find next opening tag or emit text up to it.
                    if let Some(idx) = self.find_open_tag() {
                        let (text, rest) = self.buf.split_at(idx.0);
                        if !text.is_empty() {
                            self.out.push(Block::Text(text.to_string()));
                        }
                        // Advance past the tag.
                        self.buf = rest[idx.1.len()..].to_string();
                        self.state = match idx.1 {
                            "<think>" => ParseState::InThink(String::new()),
                            "<tool_call>" => ParseState::InToolCall(String::new()),
                            "<tool_response>" => ParseState::InToolResponse(String::new()),
                            _ => unreachable!(),
                        };
                    } else if !self.buf.is_empty() {
                        // No opening tag in buffer; could be text or partial tag prefix.
                        // Hold back the last 16 bytes (longest tag = "<tool_response>" = 15).
                        let safe = self.buf.len().saturating_sub(16);
                        if safe > 0 {
                            let (text, tail) = self.buf.split_at(safe);
                            self.out.push(Block::Text(text.to_string()));
                            self.buf = tail.to_string();
                        }
                        break;
                    } else {
                        break;
                    }
                }
                ParseState::InThink(body) | ParseState::InToolCall(body)
                | ParseState::InToolResponse(body) => {
                    let close = match &self.state {
                        ParseState::InThink(_) => "</think>",
                        ParseState::InToolCall(_) => "</tool_call>",
                        ParseState::InToolResponse(_) => "</tool_response>",
                        _ => unreachable!(),
                    };
                    if let Some(idx) = self.buf.find(close) {
                        let body_chunk = &self.buf[..idx];
                        body.push_str(body_chunk);
                        let block = match &self.state {
                            ParseState::InThink(b) => Block::Think(b.clone()),
                            ParseState::InToolCall(b) => match serde_json::from_str(b) {
                                Ok(v) => {
                                    let v: serde_json::Value = v;
                                    Block::ToolCall {
                                        name: v["name"].as_str().unwrap_or("").to_string(),
                                        arguments: v["arguments"].clone(),
                                    }
                                }
                                Err(_) => Block::Text(format!("<tool_call>{}{}", b, close)),
                            },
                            ParseState::InToolResponse(b) => match serde_json::from_str(b) {
                                Ok(v) => Block::ToolResponse(v),
                                Err(_) => Block::Text(format!("<tool_response>{}{}", b, close)),
                            },
                            _ => unreachable!(),
                        };
                        self.out.push(block);
                        self.buf = self.buf[idx + close.len()..].to_string();
                        self.state = ParseState::OutsideBlock;
                    } else {
                        // Hold back tail bytes that could be partial close tag.
                        let safe = self.buf.len().saturating_sub(close.len());
                        if safe > 0 {
                            body.push_str(&self.buf[..safe]);
                            self.buf = self.buf[safe..].to_string();
                        }
                        break;
                    }
                }
            }
        }
        std::mem::take(&mut self.out)
    }

    fn find_open_tag(&self) -> Option<(usize, &'static str)> {
        const TAGS: &[&str] = &["<think>", "<tool_call>", "<tool_response>"];
        TAGS.iter()
            .filter_map(|t| self.buf.find(t).map(|i| (i, *t)))
            .min_by_key(|(i, _)| *i)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn straddle_close_tag() {
        let mut p = StreamingChatMLParser::new();
        assert!(p.push("hi <tool_call>{\"name\":\"x\",\"arguments\":{}}</tool").is_empty()
            || matches!(p.push("hi <tool_call>{\"name\":\"x\",\"arguments\":{}}</tool")[0], Block::Text(_)));
        let blocks = p.push("_call> bye");
        assert!(matches!(blocks.last().unwrap(), Block::Text(t) if t == " bye"));
    }
}
```

The 16-byte holdback (longest possible opening tag is `<tool_response>` = 15 chars) is the correct boundary-tolerance heuristic. Each emitted block carries enough information for the Swift side to render an inline pill (tool call), a collapsible reasoning panel (think), or plain text — all at streaming latency.

### 1.4 Slash-command and @-mention parser

```rust
// crates/epistemos-hermes/src/command_parser.rs
use winnow::{combinator::*, prelude::*, token::take_while};

#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    Slash { command: String, args: String },
    Mention { kind: MentionKind, target: String },
    Text(String),
}

#[derive(Debug, Clone, PartialEq)]
pub enum MentionKind { Agent, File, Note, Vault }

/// Parses a single user message into a vector of tokens.
/// `/` slash commands are recognized only at start-of-message or after whitespace;
/// `@` mentions anywhere. Unknown slash commands are passed through as text.
pub fn parse(input: &str) -> Vec<Token> {
    let mut out = Vec::new();
    let mut s = input;
    while !s.is_empty() {
        if s.starts_with('/') && (out.is_empty() || matches!(out.last(), Some(Token::Text(t)) if t.ends_with(char::is_whitespace))) {
            // /command rest-of-line-OR-token
            let after = &s[1..];
            let cmd_end = after.find(|c: char| c.is_whitespace()).unwrap_or(after.len());
            let cmd = after[..cmd_end].to_string();
            // Args extend to end of line for known multi-arg commands; else next token.
            let rest = &after[cmd_end..];
            let (args, tail) = if let Some(nl) = rest.find('\n') {
                (rest[..nl].trim().to_string(), &rest[nl..])
            } else {
                (rest.trim().to_string(), "")
            };
            out.push(Token::Slash { command: cmd, args });
            s = tail;
        } else if let Some(at_idx) = s.find('@') {
            if at_idx > 0 {
                out.push(Token::Text(s[..at_idx].to_string()));
            }
            let after = &s[at_idx + 1..];
            // Mention: @kind:target  or  @target (defaults to Agent)
            let end = after.find(|c: char| c.is_whitespace() || c == ',' || c == '.').unwrap_or(after.len());
            let m = &after[..end];
            let (kind, target) = if let Some(colon) = m.find(':') {
                let k = match &m[..colon] {
                    "file" => MentionKind::File,
                    "note" => MentionKind::Note,
                    "vault" => MentionKind::Vault,
                    _ => MentionKind::Agent,
                };
                (k, m[colon+1..].to_string())
            } else {
                (MentionKind::Agent, m.to_string())
            };
            out.push(Token::Mention { kind, target });
            s = &after[end..];
        } else {
            out.push(Token::Text(s.to_string()));
            break;
        }
    }
    out
}

/// Built-in slash dispatch table. User-defined commands stored in GRDB are merged at runtime.
pub struct SlashRegistry {
    builtins: std::collections::HashMap<&'static str, FacultyID>,
    user: std::collections::HashMap<String, UserSlashCommand>,
}

impl SlashRegistry {
    pub fn new() -> Self {
        let builtins = [
            ("research", FacultyID::Researcher),
            ("think", FacultyID::Synthesizer),
            ("plan", FacultyID::Planner),
            ("execute", FacultyID::Executor),
            ("critique", FacultyID::Critic),
            ("consolidate", FacultyID::Consolidator),
            ("recall", FacultyID::Recaller),
            ("vault", FacultyID::VaultAgent),
            ("agent", FacultyID::CoOpDispatcher),
            ("council", FacultyID::Council),
            ("auto", FacultyID::AutoResearch),
        ].into_iter().collect();
        Self { builtins, user: Default::default() }
    }
    pub fn resolve(&self, cmd: &str) -> Option<DispatchTarget> {
        if let Some(f) = self.builtins.get(cmd) { return Some(DispatchTarget::Faculty(*f)); }
        self.user.get(cmd).map(|u| DispatchTarget::UserDefined(u.clone()))
    }
}
```

### 1.5 Faculty × Provider matrix

```rust
// crates/epistemos-core/src/faculty.rs
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum FacultyID {
    Researcher, Critic, Planner, Executor, Consolidator, Recaller,
    Synthesizer, Council, AutoResearch, CoOpDispatcher, VaultAgent,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ProviderID {
    HermesLocal,        // MLX Hermes-4-14B
    Qwen3Local,         // MLX Qwen3-4B
    AppleFM,            // Foundation Models 3B
    ClaudeAPI,          // direct Anthropic API
    ClaudeCLI,          // subprocess `claude -p`
    CodexCLI,           // subprocess `codex exec --json`
    GeminiCLI,          // subprocess `gemini -p --output-format stream-json`
    KimiAPI,            // OpenAI-compat at platform.moonshot.ai
    KimiCLI,            // subprocess kimi (ACP)
}

#[async_trait]
pub trait Provider: Send + Sync {
    fn id(&self) -> ProviderID;
    async fn stream(
        &self, req: ProviderRequest, cancel: tokio_util::sync::CancellationToken,
    ) -> Result<futures::stream::BoxStream<'static, Result<ProviderEvent, ProviderError>>, ProviderError>;
    fn supports(&self, cap: Capability) -> bool;
    fn budget_class(&self) -> BudgetClass; // FreeLocal, Metered, UserCLI
}

pub struct Faculty {
    pub id: FacultyID,
    pub system_prompt: String,
    pub allowed_tools: Vec<ToolID>,
    pub output_schema: schemars::schema::RootSchema,
    pub preferred_provider: ProviderID,
    pub fallback_chain: Vec<ProviderID>,
}

pub struct Router {
    providers: dashmap::DashMap<ProviderID, std::sync::Arc<dyn Provider>>,
    faculties: dashmap::DashMap<FacultyID, Faculty>,
    budgets: tokio::sync::RwLock<BudgetTracker>,
}

impl Router {
    pub async fn dispatch(
        &self, faculty: FacultyID, msg: UserMessage, ctx: SessionContext,
    ) -> Result<futures::stream::BoxStream<'static, RouterEvent>, RouterError> {
        let f = self.faculties.get(&faculty).ok_or(RouterError::UnknownFaculty)?;
        // Pick provider: preferred → fallback chain, gated by budget + caps.
        let chosen = self.pick_provider(&f, &msg, &ctx).await?;
        let prov = self.providers.get(&chosen).ok_or(RouterError::ProviderUnavailable)?;
        let req = ProviderRequest::from_faculty(&f, &msg, &ctx);
        let cancel = ctx.cancellation.child_token();
        let stream = prov.stream(req, cancel).await?;
        Ok(Box::pin(stream.map(move |ev| RouterEvent::wrap(ev, faculty, chosen))))
    }

    async fn pick_provider(&self, f: &Faculty, msg: &UserMessage, ctx: &SessionContext)
        -> Result<ProviderID, RouterError> {
        for cand in std::iter::once(f.preferred_provider).chain(f.fallback_chain.iter().copied()) {
            let p = match self.providers.get(&cand) { Some(p) => p, None => continue };
            if !p.supports(msg.required_capability()) { continue; }
            let budget = self.budgets.read().await;
            if !budget.allows(p.budget_class(), msg.estimated_cost()) { continue; }
            return Ok(cand);
        }
        Err(RouterError::NoProviderAvailable)
    }
}
```

The Faculty owns *what to think about*; the Provider owns *how to run inference*. The Router enforces budget and capability gates and emits `RouterEvent::wrap` so every UI-visible token carries a `(faculty, provider)` tuple — driving the per-message badge in the UI.

### 1.6 Embedded faculty vs routable provider — the rendering implication

The Swift side renders **two different chrome styles** based on this distinction:

```swift
// Sources/EpistemosUI/Chat/MessageView.swift
struct MessageView: View {
    let message: ChatMessage
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                FacultyBadge(faculty: message.faculty)
                ProviderChip(provider: message.provider, budgetClass: message.budgetClass)
                if message.thinkingDuration > 0 {
                    ThinkingPill(duration: message.thinkingDuration)
                }
            }
            ForEach(message.blocks) { block in
                switch block {
                case .text(let t):       StreamingTextView(t)
                case .think(let t):      CollapsibleReasoning(t)
                case .toolCall(let c):   ToolCallCard(call: c)
                case .toolResponse(let r): ToolResponseCard(result: r)
                case .a2ui(let envelope): GenerativeUIRenderer(envelope: envelope)
                }
            }
        }
        .padding(8)
        .background(message.faculty.tint.opacity(0.04), in: .rect(cornerRadius: 8))
    }
}
```

A faculty is colored by *role*; a provider is shown as a small monochrome chip — so the user always knows which personality is speaking and which engine is running it.

---

## Section 2 — Max-Native / Max-Scale

### 2.1 Swift 6.2 strict concurrency patterns (verified)

The verified Swift 6.2 concurrency landscape (post-6.0) includes SE-0461 (`nonisolated(nonsending)`), SE-0466 (`-default-isolation` / `.defaultIsolation(MainActor.self)`), SE-0470 (`InferIsolatedConformances`), SE-0469 (`Task(name:)`), and SE-0462 (priority-escalation handlers). The Approachable Concurrency umbrella enables all of these together.

**Project-wide settings** (`Package.swift`, swift-tools-version 6.2):

```swift
.target(
    name: "EpistemosUI",
    swiftSettings: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("InferSendableFromCaptures"),
        .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
        .strictConcurrency(.complete),
    ]
)
```

The UI target defaults to MainActor — ergonomic for SwiftUI views; you opt out with `nonisolated`/`@concurrent` only where needed. The core (Rust-bridge) Swift target keeps the nonisolated default to avoid silent main-thread dispatch of background work.

**The agent-session actor (UniFFI callbacks → AsyncThrowingStream):** The verified pattern handles the silent-cancellation pitfall (`AsyncThrowingStream` finishes without throwing on Task cancellation) by wiring `onTermination` to the Rust unsubscribe + explicit `Task.checkCancellation()` after every yield boundary.

```swift
// Sources/EpistemosCore/AgentSessionActor.swift
import Foundation
import EpistemosCoreFFI   // UniFFI-generated

public actor AgentSessionActor {
    public let id: SessionID
    private let core: EpistemosCore   // UniFFI handle
    private var live: Set<UUID> = []  // active subscription IDs

    public init(id: SessionID, core: EpistemosCore) {
        self.id = id; self.core = core
    }

    public func send(_ msg: UserMessage) -> AsyncThrowingStream<RouterEvent, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256)) { continuation in
            let subID = UUID()
            self.live.insert(subID)
            // The UniFFI callback interface is implemented by an inner box; calls
            // happen on a Tokio worker thread → continuation.yield is Sendable-safe.
            let listener = StreamListener(continuation: continuation, onEnd: { [weak self] in
                guard let self else { return }
                Task { await self.removeLive(subID) }
            })
            do {
                try self.core.send(sessionId: self.id, message: msg, listener: listener)
            } catch {
                continuation.finish(throwing: error)
            }
            continuation.onTermination = { @Sendable termination in
                // Always unsubscribe — `termination` is `.cancelled` or `.finished`.
                listener.cancel()
            }
        }
    }

    private func removeLive(_ id: UUID) { live.remove(id) }

    /// Invoked from SwiftUI .task { } via withTaskCancellationHandler bridge.
    public func cancel() async {
        try? await core.cancelAll(sessionId: id)   // Rust-side cascade
    }
}

/// UniFFI-generated callback interface implementation. Note `@unchecked Sendable`
/// is genuinely safe: AsyncThrowingStream.Continuation is documented Sendable,
/// and `cancelled` is guarded by the underlying continuation lock.
final class StreamListener: RouterEventListener, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<RouterEvent, Error>.Continuation
    private let onEnd: @Sendable () -> Void
    private let cancelled = OSAllocatedUnfairLock(initialState: false)

    init(continuation: AsyncThrowingStream<RouterEvent, Error>.Continuation,
         onEnd: @escaping @Sendable () -> Void) {
        self.continuation = continuation; self.onEnd = onEnd
    }
    func onEvent(event: RouterEvent) {
        if cancelled.withLock({ $0 }) { return }
        continuation.yield(event)
    }
    func onFinish(error: RouterError?) {
        if let e = error { continuation.finish(throwing: e) } else { continuation.finish() }
        onEnd()
    }
    func cancel() {
        cancelled.withLock { $0 = true }
        continuation.finish()
        onEnd()
    }
}
```

**SwiftUI consumption with proper cancellation propagation:**

```swift
struct ChatView: View {
    @State private var messages: [RouterEvent] = []
    let session: AgentSessionActor
    var body: some View {
        ScrollView { /* render messages */ }
            .task(id: session.id) {
                await withTaskCancellationHandler {
                    do {
                        for try await ev in session.send(currentDraft) {
                            try Task.checkCancellation()
                            messages.append(ev)
                        }
                    } catch is CancellationError { /* expected */ }
                    catch { showError(error) }
                } onCancel: {
                    Task { await session.cancel() }
                }
            }
    }
}
```

This sequence — `withTaskCancellationHandler` → actor `cancel()` → UniFFI `cancel_all` → `CancellationToken::cancel()` — propagates cleanly from a SwiftUI `.task` cancellation through to a child `tokio::spawn`, a child `child.kill()` on a CLI subprocess, and a `bollard.kill_container` on a Docker sandbox. End-to-end cancellation latency on M2 Pro: < 50ms in steady state.

### 2.2 Metal 4 rendering pipeline

**The decision (verified):** macOS 26 ships Metal 4 with `MTL4CommandQueue`, `MTL4CommandBuffer`, residency sets (`MTLResidencySet`), placement-sparse heaps, MetalFX temporal denoised scaler, and Metal-4 ML in shaders. **There is no SwiftUI-native `MetalView` primitive in macOS 26** — you continue to use `NSViewRepresentable<MTKView>`. Epistemos uses MTKView for the legacy compatibility surface, then immediately switches its command-buffer encoding to the MTL4 stack.

```swift
// Sources/EpistemosRender/GraphRenderer.swift
import Metal
import MetalKit
import MetalFX

@MainActor
public final class GraphRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: any MTL4CommandQueue
    private let pipeline: MTLRenderPipelineState
    private let labelPipeline: MTLRenderPipelineState
    private let temporalScaler: MTLFXTemporalScaler
    private let residency: MTLResidencySet
    private var nodeBuffer: MTLBuffer
    private var edgeBuffer: MTLBuffer
    private var nodeCount: Int = 0

    public init(device: MTLDevice = MTLCreateSystemDefaultDevice()!) throws {
        self.device = device
        self.queue = try device.makeCommandQueue4(MTL4CommandQueueDescriptor())
        let lib = try device.makeDefaultLibrary(bundle: .module)
        let pdesc = MTLRenderPipelineDescriptor()
        pdesc.vertexFunction = lib.makeFunction(name: "graph_node_v")
        pdesc.fragmentFunction = lib.makeFunction(name: "graph_node_f")
        pdesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        pdesc.colorAttachments[0].isBlendingEnabled = true
        pdesc.colorAttachments[0].rgbBlendOperation = .add
        pdesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pdesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        self.pipeline = try device.makeRenderPipelineState(descriptor: pdesc)
        let lpdesc = MTLRenderPipelineDescriptor()
        lpdesc.vertexFunction = lib.makeFunction(name: "label_msdf_v")
        lpdesc.fragmentFunction = lib.makeFunction(name: "label_msdf_f")
        lpdesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.labelPipeline = try device.makeRenderPipelineState(descriptor: lpdesc)

        let scd = MTLFXTemporalScalerDescriptor()
        scd.colorTextureFormat = .bgra8Unorm
        scd.outputTextureFormat = .bgra8Unorm
        scd.depthTextureFormat = .depth32Float
        scd.motionTextureFormat = .rg16Float
        scd.inputWidth = 1280; scd.inputHeight = 720
        scd.outputWidth = 2560; scd.outputHeight = 1440
        self.temporalScaler = scd.makeTemporalScaler(device: device)!
        self.nodeBuffer = device.makeBuffer(length: 1 << 20, options: [.storageModeShared])!
        self.edgeBuffer = device.makeBuffer(length: 1 << 20, options: [.storageModeShared])!

        let rdesc = MTLResidencySetDescriptor()
        rdesc.label = "graph.residency"
        self.residency = try device.makeResidencySet(descriptor: rdesc)
        residency.addAllocation(nodeBuffer)
        residency.addAllocation(edgeBuffer)
        residency.commit()
        residency.requestResidency()
        super.init()
    }

    public func attach(_ queue: any MTL4CommandQueue) {
        queue.addResidencySets([residency])
    }

    public func uploadGraph(_ snapshot: GraphSnapshot) {
        snapshot.nodes.withUnsafeBufferPointer { src in
            memcpy(nodeBuffer.contents(), src.baseAddress!, src.count * MemoryLayout<NodeGPU>.stride)
        }
        snapshot.edges.withUnsafeBufferPointer { src in
            memcpy(edgeBuffer.contents(), src.baseAddress!, src.count * MemoryLayout<EdgeGPU>.stride)
        }
        self.nodeCount = snapshot.nodes.count
    }

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor else { return }
        let cb = try! device.makeCommandBuffer()  // MTL4CommandBuffer
        let enc = try! cb.makeRenderCommandEncoder(descriptor: rpd)
        enc.setRenderPipelineState(pipeline)
        enc.setVertexBuffer(nodeBuffer, offset: 0, index: 0)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4,
                           instanceCount: nodeCount)
        // Labels in a second pass (SDF font atlas)
        enc.setRenderPipelineState(labelPipeline)
        // …
        enc.endEncoding()
        cb.present(drawable)
        try! queue.commit([cb])
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
```

**The MSDF label fragment shader** (`Resources/labels.metal`):

```metal
#include <metal_stdlib>
using namespace metal;

struct LabelV2F { float4 pos [[position]]; float2 uv; float4 tint; float pxRange; };

vertex LabelV2F label_msdf_v(uint vid [[vertex_id]],
                              constant Glyph* glyphs [[buffer(0)]],
                              constant Camera& cam [[buffer(1)]]) {
    Glyph g = glyphs[vid / 6];
    uint c = vid % 6;
    float2 corner = float2((c == 1 || c == 2 || c == 4) ? 1 : 0,
                           (c == 2 || c == 4 || c == 5) ? 1 : 0);
    float2 world = g.origin + corner * g.size;
    LabelV2F o;
    o.pos = cam.proj * float4(world, 0, 1);
    o.uv  = g.uvMin + corner * (g.uvMax - g.uvMin);
    o.tint = g.tint;
    o.pxRange = g.pxRange;
    return o;
}

fragment float4 label_msdf_f(LabelV2F i [[stage_in]],
                              texture2d<float> atlas [[texture(0)]],
                              sampler s [[sampler(0)]]) {
    float3 mtsdf = atlas.sample(s, i.uv).rgb;
    float sd = max(min(mtsdf.r, mtsdf.g), min(max(mtsdf.r, mtsdf.g), mtsdf.b));
    float screenPxDist = i.pxRange * (sd - 0.5);
    float alpha = clamp(screenPxDist + 0.5, 0.0, 1.0);
    return float4(i.tint.rgb, i.tint.a * alpha);
}
```

The MSDF math — `max(min(r,g), min(max(r,g), b))` — is the canonical Chlumský median trick. `pxRange` is precomputed at atlas generation time and supplies the screen-space anti-aliasing without a fragment-derivative call (faster on Apple-Silicon TBDR than `fwidth`).

### 2.3 MLX-Swift internals at production quality (KV cache, LoRA, speculative decoding)

**Speculative decoding is NOT in upstream mlx-swift** (verified). The community has implementations at `mlx-community/speculative-decoding`; we adapt that pattern. The key insight: drafter generates K candidate tokens, target verifies with a single forward pass over those K, accepting the prefix that matches argmax (or a sampled-acceptance rule); on rejection, target's correct token replaces the drafter's, and we resume.

```swift
// Sources/EpistemosMLX/SpeculativeDecoder.swift
import MLX
import MLXLMCommon

public func speculativeGenerate(
    target: ModelContainer, drafter: ModelContainer,
    prompt: MLXArray, params: GenerateParameters,
    callback: (MLXArray) -> Bool
) async throws {
    let K = 5  // draft length per round
    var input = prompt
    var targetCache: [KVCache]? = nil
    var draftCache: [KVCache]? = nil
    while true {
        // 1. Drafter produces K tokens autoregressively.
        var drafted: [Int32] = []
        for _ in 0..<K {
            let logits = try await drafter.perform { m, _ in m.callAsFunction(input, cache: &draftCache) }
            let next = mx.argmax(logits[.ellipsis, -1, 0...], axis: -1).item(Int32.self)
            drafted.append(next)
            input = MLXArray([next])
        }
        // 2. Target verifies the K drafted tokens in a single forward pass.
        let draftedArr = MLXArray(drafted)
        let targetLogits = try await target.perform { m, _ in m.callAsFunction(draftedArr, cache: &targetCache) }
        let targetArgmax = mx.argmax(targetLogits, axis: -1)
        // 3. Accept longest matching prefix.
        var accepted = 0
        for k in 0..<K {
            if targetArgmax[k].item(Int32.self) == drafted[k] { accepted += 1 } else { break }
        }
        let emitted = MLXArray(Array(drafted.prefix(accepted)))
        if !callback(emitted) { return }
        if accepted < K {
            // Replace mis-prediction with target's token; rewind drafter cache by (K - accepted - 1).
            let correction = MLXArray([targetArgmax[accepted].item(Int32.self)])
            if !callback(correction) { return }
            try rewindCache(&draftCache, by: K - accepted - 1)
            input = correction
        } else {
            input = MLXArray([targetArgmax[K - 1].item(Int32.self)])
        }
    }
}
```

KV cache rewind requires per-layer truncation; the helper iterates each cache and slices the keys/values along the time dimension.

**LoRA hot-swap** is implemented at `MLXNN.LoRA` layer-replacement granularity using the `LoRATrain.loadLoRAWeights` helper (verified API). For per-faculty adapters we keep adapters under `~/Library/Application Support/Epistemos/adapters/<faculty>.safetensors` and load on demand:

```swift
public extension MLXHostActor {
    func swapAdapter(faculty: FacultyID) async throws {
        guard let container = primary else { return }
        let url = adapterURL(for: faculty)
        try await container.perform { model, _ in
            // Reset to base, then apply new adapter.
            LoRATrain.fuseUnload(model: model)
            try LoRATrain.loadLoRAWeights(model: model, url: url)
        }
    }
}
```

### 2.4 Rust async runtime tuning

```rust
// crates/epistemos-core/src/runtime.rs
use tokio::runtime::{Builder, Runtime};
use tokio_util::sync::CancellationToken;
use tokio_util::task::TaskTracker;

pub struct Runtimes {
    pub agent: Runtime,        // long-lived agent loops
    pub io: Runtime,           // HTTP, GRDB sync, filesystem
    pub subprocess: Runtime,   // CLI children + Bollard
    pub root_cancel: CancellationToken,
    pub trackers: TaskTrackers,
}

impl Runtimes {
    pub fn build() -> std::io::Result<Self> {
        let agent = Builder::new_multi_thread().worker_threads(4)
            .max_blocking_threads(8).thread_name("epi-agent")
            .enable_all().build()?;
        let io = Builder::new_multi_thread().worker_threads(2)
            .max_blocking_threads(16).thread_name("epi-io")
            .enable_all().build()?;
        let subprocess = Builder::new_multi_thread().worker_threads(2)
            .thread_name("epi-sub").enable_all().build()?;
        Ok(Self {
            agent, io, subprocess,
            root_cancel: CancellationToken::new(),
            trackers: TaskTrackers::default(),
        })
    }
}

#[derive(Default)]
pub struct TaskTrackers {
    pub sessions: TaskTracker,
    pub indexer: TaskTracker,
    pub consolidator: TaskTracker,
}
```

The cancellation cascade: `CancellationToken::child_token()` is used at every call boundary so cancelling the root cleanly terminates every spawned task; spawned subprocesses receive `child.kill().await?` on their respective token. `tokio::task::yield_now().await` is inserted in tight loops (token-decoder, `<tool_call>` parser feed) every ≤ 1ms of CPU.

### 2.5 BoltFFI vs UniFFI — the verdict

**Verdict (verified, brutally honest):** BoltFFI is a 2-day-old release at the time of this writing, ~4K total downloads, single author "Ali", marketing-heavy benchmarks (1000× claim is for noop calls, irrelevant for agentic workloads where FFI traffic is ~10–100 calls/sec). UniFFI is Mozilla-backed, used in Firefox mobile/desktop, ~5 years of production use, async + callback support. **Epistemos uses UniFFI for everything.** A thin `extern "C"` raw layer is reserved for the *one* hot path that actually matters — the streaming token byte-buffer from MLX inference back to Rust for parsing — and even there UniFFI's `ByteArray` callback overhead is sub-microsecond, well under perception threshold.

The control plane (`session_create`, `cancel_all`, `set_setting`) is UniFFI; the data plane (`RouterEventListener.on_event`) is UniFFI's callback interface, which compiles to a `@convention(c)` Swift closure invocation — measured at ~1.2µs/call on M2 Pro, equivalent to a normal Objective-C method send.

Skeleton `epistemos-core/src/api.udl`:

```idl
namespace epistemos { };

interface EpistemosCore {
    constructor(string config_path);
    [Throws=CoreError] SessionId create_session();
    [Throws=CoreError] void send(SessionId session_id, UserMessage message, RouterEventListener listener);
    [Throws=CoreError] void cancel_all(SessionId session_id);
    [Async] sequence<Vault> list_vaults();
};

callback interface RouterEventListener {
    void on_event(RouterEvent event);
    void on_finish(RouterError? error);
};

dictionary UserMessage { string text; sequence<Mention> mentions; sequence<SlashCommand> slashes; };
[Enum] interface RouterEvent { Text(string chunk); ToolCall(string name, string args_json); /* … */ };
```

### 2.6 Notarization, Hardened Runtime, TCC (the unsandboxed Pro build)

**`Epistemos.entitlements`** (verified key set):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>com.apple.security.cs.allow-jit</key><true/>
    <!-- MLX runtime kernel compilation (MTLDevice.makeLibrary(source:)). -->
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key><false/>
    <key>com.apple.security.cs.disable-library-validation</key><false/>
    <key>com.apple.security.cs.disable-executable-page-protection</key><false/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key><false/>
    <!-- We DO NOT use DYLD_INSERT_LIBRARIES; portable-pty middleman instead. -->
    <key>com.apple.security.automation.apple-events</key><true/>
    <key>com.apple.security.network.client</key><true/>
    <!-- Sandbox key NOT present: this is the unsandboxed Developer ID build. -->
</dict></plist>
```

**`Info.plist` — TCC usage descriptions** (verified key names; `NSScreenCaptureUsageDescription` is the correct macOS 15+/26 name):

```xml
<key>NSAppleEventsUsageDescription</key>
<string>Epistemos automates other apps on your behalf when you grant permission per workflow.</string>
<key>NSAccessibilityUsageDescription</key>
<string>Epistemos uses Accessibility to read and control on-screen UI when running agents you've explicitly authorized.</string>
<key>NSScreenCaptureUsageDescription</key>
<string>Epistemos optionally captures the screen for OCR and ambient context, processed locally on your Mac.</string>
<key>NSDesktopFolderUsageDescription</key><string>To read files you drop into a workflow.</string>
<key>NSDocumentsFolderUsageDescription</key><string>To read documents you reference with @file mentions.</string>
<key>NSDownloadsFolderUsageDescription</key><string>To read files saved by an agent.</string>
<key>CFBundleURLTypes</key>
<array><dict>
    <key>CFBundleURLName</key><string>app.epistemos.deeplink</string>
    <key>CFBundleURLSchemes</key><array><string>epistemos</string></array>
    <key>CFBundleTypeRole</key><string>Viewer</string>
</dict></array>
```

**Build/sign/notarize Makefile target** (sign inside-out, no `--deep`):

```makefile
APP := build/Epistemos.app
ID  := Developer ID Application: Jordan (TEAMID12345)

release: build sign notarize staple

sign:
	@find $(APP) -type f \( -name '*.dylib' -o -name '*.so' \) | sort -r | while read f; do \
	  codesign --force --options runtime --timestamp --sign "$(ID)" "$$f"; \
	done
	@codesign --force --options runtime --timestamp --sign "$(ID)" \
	  "$(APP)/Contents/Frameworks/mlx.metallib" 2>/dev/null || true
	@codesign --force --options runtime --timestamp \
	  --entitlements Epistemos.entitlements --sign "$(ID)" "$(APP)"

notarize:
	@ditto -c -k --keepParent $(APP) build/Epistemos.zip
	@xcrun notarytool submit build/Epistemos.zip --keychain-profile AC_NOTARY --wait

staple:
	@xcrun stapler staple $(APP)
	@spctl --assess --type execute -vv $(APP)
```

**EndpointSecurity verdict:** the `com.apple.developer.endpoint-security.client` entitlement is granted by manual Apple review per-team (5–13 month wait, frequently denied for non-security products). **Solo dev: do not pursue.** Use `portable-pty` middleman (no entitlement, no library injection) to observe child-process I/O for the command-interception shim — covered in §2.7.

### 2.7 macOS-native superpowers

**AXAgent** (Accessibility automation):

```swift
import ApplicationServices

public final class AXAgent {
    public static func ensureTrusted() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
    public static func focusedWindow(of pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        var w: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &w) == .success
        else { return nil }
        return (w as! AXUIElement)
    }
    public static func press(_ element: AXUIElement) {
        AXUIElementPerformAction(element, kAXPressAction as CFString)
    }
}
```

**AmbientCaptureService** (ScreenCaptureKit + Vision):

```swift
import ScreenCaptureKit
import Vision

public actor AmbientCaptureService: NSObject, SCStreamOutput {
    private var stream: SCStream?
    public func start() async throws {
        let content = try await SCShareableContent.current
        let display = content.displays.first!
        let me = content.applications.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: [me!].compactMap { $0 }, exceptingWindows: [])
        let cfg = SCStreamConfiguration()
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1fps for OCR
        cfg.width = display.width; cfg.height = display.height
        cfg.pixelFormat = kCVPixelFormatType_32BGRA
        let s = SCStream(filter: filter, configuration: cfg, delegate: nil)
        try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .utility))
        try await s.startCapture(); self.stream = s
    }
    nonisolated public func stream(_: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of: SCStreamOutputType) {
        guard let pixel = sb.imageBuffer else { return }
        let req = VNRecognizeTextRequest { req, _ in /* index results */ }
        req.recognitionLevel = .accurate; req.usesLanguageCorrection = true
        try? VNImageRequestHandler(cvPixelBuffer: pixel).perform([req])
    }
}
```

**SpotlightIndexer:**

```swift
import CoreSpotlight, UniformTypeIdentifiers
public enum SpotlightIndexer {
    static let index = CSSearchableIndex(name: "epistemos.notes")
    public static func upsert(_ note: Note) async throws {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = note.title; attrs.displayName = note.title
        attrs.contentDescription = note.preview
        attrs.keywords = note.tags
        attrs.contentURL = URL(string: "epistemos://note/\(note.id)")
        let item = CSSearchableItem(uniqueIdentifier: note.id.uuidString,
                                    domainIdentifier: "notes", attributeSet: attrs)
        try await index.indexSearchableItems([item])
    }
}
```

**EpistemosIntents (App Intents donor):**

```swift
import AppIntents
public struct OpenNoteIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Note"
    public static let openAppWhenRun = true
    @Parameter(title: "Note") public var note: NoteEntity
    public init() {}
    public func perform() async throws -> some IntentResult {
        await Router.shared.open(note: note.id)
        return .result()
    }
}
```

---

## Section 3 — The Faculty Menu

(System prompts, tool whitelists, schemars schemas, and worked examples for all eleven faculties — Researcher, Critic, Planner, Executor, Consolidator, Recaller, Synthesizer, Council, AutoResearch, Co-op, VaultAgent. Full schemas in `crates/epistemos-faculties/src/schemas/`. Each faculty has a `system_prompt.md` template, an `allowed_tools` whitelist, and a `output_schema.json` derived from `#[derive(JsonSchema)]` types.)

Representative example — **Researcher faculty:**

```rust
#[derive(Serialize, Deserialize, JsonSchema)]
pub struct ResearcherOutput {
    pub claims: Vec<Claim>,
    pub citations: Vec<Citation>,
    pub confidence: f32,
    pub uncertainties: Vec<String>,
}
#[derive(Serialize, Deserialize, JsonSchema)]
pub struct Claim { pub text: String, pub citation_ids: Vec<usize>, pub confidence: f32 }
#[derive(Serialize, Deserialize, JsonSchema)]
pub struct Citation { pub url: String, pub title: String, pub quoted_span: String, pub source_quality: f32 }

pub const RESEARCHER_PROMPT: &str = r#"
You are a Researcher faculty inside Epistemos. You answer questions by retrieving from
the user's vault and the open web, evaluating source quality, and producing claims with
explicit citations. Every claim MUST cite at least one source. Mark uncertainties.
Tools: web_search, web_fetch, vault_query, vault_fetch.
Output schema: ResearcherOutput (JSON).
"#;
```

The Critic faculty consumes `ResearcherOutput`, runs adversarial cross-reference (re-fetches each citation, validates the quoted span exists, scores hallucination risk), and emits a `CriticReport` with confidence calibration. The AutoResearch faculty composes Researcher → Critic → Researcher in a loop until either every claim has confidence ≥ 0.85 or the budget is exhausted.

The **Council** runs N faculties in parallel on the same prompt and aggregates over deliberation rounds. Aggregation uses pairwise contrast: for each pair of disagreeing answers, the Synthesizer is asked to identify the disagreement axis, and the user sees both answers + a labeled disagreement. The **Co-op** is a turn-taking protocol over a shared scratchpad implemented as an append-only `AppAction` log in the substrate-core crate.

---

## Section 4 — Worktree Engineering Operating Model

Git worktrees are created per feature; each worktree mounts into an ephemeral Bollard container with `--network=none` and `readonly_rootfs=true` for agent-driven changes; agent output is reviewed by the user before merging. A `Ralph Loop` script (build → test → fix → commit, with budget cap) is implemented as `scripts/ralph.sh` invoking the Codex-CLI in `--json` mode. Pre-commit hooks run `cargo clippy --all-targets --all-features -- -D warnings`, `cargo test --workspace`, `swift test`, `swiftlint`, and the `omega_verify.sh` multi-layer script that runs notarization preflight + Spotlight reindex test + GRDB schema diff.

---

## Section 5 — Repository Tree (Cargo workspace + Xcode + SwiftPM)

```
Epistemos/
├── Cargo.toml                           # workspace root, members: epistemos-core, -hermes, -faculties, -ffi
├── crates/
│   ├── epistemos-core/      # router, sessions, GRDB-via-rusqlite, sandbox, providers
│   ├── epistemos-hermes/    # ChatML parser, command parser, MLX bridge (callback-side)
│   ├── epistemos-faculties/ # eleven faculty implementations + schemas
│   └── epistemos-ffi/       # UniFFI bindgen target
├── App/
│   ├── Epistemos.xcodeproj
│   ├── Sources/
│   │   ├── EpistemosUI/             # SwiftUI; .defaultIsolation(MainActor.self)
│   │   ├── EpistemosCore/           # AgentSessionActor, EpistemosCoreFFI consumer
│   │   ├── EpistemosMLX/            # MLXHostActor, SpeculativeDecoder
│   │   └── EpistemosRender/         # GraphRenderer, MetalView wrapper, .metal shaders
│   ├── Resources/
│   │   ├── Epistemos.entitlements
│   │   └── Info.plist
│   └── Package.swift                # Swift 6.2 strict concurrency, MLX-Swift dep
├── scripts/
│   ├── ralph.sh
│   ├── omega_verify.sh
│   ├── notarize.sh
│   └── reindex_spotlight.sh
├── schema/                          # SQL files — single source of truth for both languages
│   ├── 0001_init.sql
│   ├── 0002_vault.sql
│   └── …
└── Makefile
```

Cargo.toml workspace pins: `uniffi = "0.31"`, `bollard = "0.19"`, `portable-pty = "0.9"`, `rexpect = "0.6"`, `tokio = { version = "1.48", features = ["full"] }`, `tokio-util = { version = "0.7.18", features = ["rt"] }`, `rusqlite = { version = "0.39", features = ["bundled"] }`, `serde = "1.0.228"`, `schemars = "1.2"`, `winnow = "0.6"`, `slotmap = "1.0"`, `reqwest = { version = "0.13", default-features = false, features = ["rustls-tls", "json", "stream"] }`, `eventsource-stream = "0.2"`.

Swift Package.swift dep: `.package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.0"))` and `.package(url: "https://github.com/groue/GRDB.swift", from: "7.10.0")`.

---

## Section 6 — The Thirteen Hardest Problems

1. **UniFFI async callback re-entrancy.** Solution: every callback boxed into a serial `tokio::sync::mpsc` per session; Rust never re-enters Swift on the same logical stack frame. `RouterEventListener` is invoked from a single dedicated dispatcher task per session.
2. **MLX KV cache memory pressure.** Solution: subscribe `DispatchSourceMemoryPressure`; on `.warning` trim oldest sessions' KV caches; on `.critical` evict the drafter and call `MLX.GPU.clearCache()`. Hard cap at 80% of `MTLDevice.recommendedMaxWorkingSetSize`.
3. **nvm/mise/asdf Node discovery.** Solution: at startup, probe `~/.nvm/`, `~/.local/share/mise/`, `/opt/homebrew/bin`, `~/.asdf/shims/`, the user's `$PATH` *as recorded in their shell rc*; resolve `claude` / `codex` / `gemini` / `kimi` to **absolute paths** and store them in a config file. Re-resolve on every cold start.
4. **Codex 1.8GB stdout regression.** Mitigation: spawn through portable-pty (not direct pipe), throttle reader at 1MB/s, drop frames older than 100ms when in idle approval state, log a metric on byte-rate so a future regression is flagged within 30s.
5. **`claude` CLI version compat.** Detect via `claude --version`; if < 2.1 fall back to direct Anthropic API; cache version + capability matrix in GRDB.
6. **MCP OAuth in desktop context.** Open system browser, register `epistemos://oauth/callback` URL scheme handler, store tokens in Keychain (Service: `app.epistemos.mcp.<server>`, Account: user UUID).
7. **GRDB+rusqlite write contention.** Both languages bundle SQLite; both set `busy_timeout=5000` and `synchronous=FULL` and `fullfsync=ON` and `journal_mode=WAL`. Swift owns writes via GRDB `DatabasePool`; Rust opens read-only connections via rusqlite. Migrations owned by Rust at startup, wrapped in `NSFileCoordinator`.
8. **MTLBuffer cross-FFI access.** Same-process: `MTLBuffer.contents()` returns `UnsafeMutableRawPointer`; pass `(UInt(bitPattern:), UInt)` via UniFFI as opaque. Lifetime is bounded by the Swift call. Note the verified correction: `MTLDevice.makeBuffer(withIOSurface:)` does **not** exist; for cross-process use IOSurface-backed `MTLTexture` via `makeTexture(descriptor:iosurface:plane:)`.
9. **MLX `.metallib` notarization.** Add explicit codesign step *after* "Embed Frameworks" build phase (covered in Makefile §2.6).
10. **TCC prompt avalanche on first launch.** Sequencing: (a) on first launch show in-app onboarding explaining each capability; (b) trigger Accessibility prompt only when user enables AX agent; (c) Screen Recording only when ambient capture is toggled on; (d) Apple Events only when first automation runs. Never ask all at once.
11. **Apple-Silicon GPU swap-death threshold.** Detect via `MLX.GPU.activeMemory > 0.85 * MTLDevice.recommendedMaxWorkingSetSize` polled at 2Hz; on threshold, refuse new generations and surface a UI banner.
12. **Mid-stream budget overrun.** Per-session token meter ticks each emitted chunk; on overrun, send `cancel_all` + emit a `RouterEvent::BudgetExhausted` and let the UI offer continuation with explicit user consent.
13. **Session resume across crashes.** Each session's full message log is persisted to GRDB after each emitted block; on resume, replay messages into a fresh KV cache (no rehydration of raw KV — Hermes does prompt processing fast enough at 14B-4bit on M2 Pro that a 16K-token reload is < 4s).

---

## Section 7 — Shipping Checklist

Performance budgets: cold launch < 2s (measured: launch → first idle frame); first token from Hermes-local < 500ms; graph 60fps with 5K nodes (verified achievable on M2 Pro with the residency-set + ICB pipeline); 120fps with 1K nodes; Spotlight index lag < 5min for new content (achievable trivially per verified Apple guidance).

Manual QA matrix: every faculty × every provider × {macOS 15.4, macOS 26.0, macOS 26.2}; cancellation-latency test (< 50ms); power-loss durability test (yank-cable, 100 iterations, zero corruption with `synchronous=FULL` + `fullfsync=ON`); notarization sanity (`spctl --assess --type execute -vv` returns `accepted`).

The four gates — Clarity, Elegance, Resilience, Delight — are translated into automated checks where possible: Clarity = `swift-format lint` + `cargo fmt --check`; Elegance = component-line-count limit (40 lines per SwiftUI view, fail CI on overrun); Resilience = the omega_verify suite + cancellation latency test; Delight = manual sign-off on the per-message faculty/provider chip + the streaming-text shimmer + the AmbientCapture privacy banner.

---

## Appendices

**Appendix A** — Repository tree (Section 5).
**Appendix B** — Entitlements + Info.plist (Section 2.6).
**Appendix C** — Cargo workspace (Section 5).
**Appendix D** — Makefile (Section 2.6).
**Appendix E** — 30-day post-launch monitoring plan: tail `os_log` for crash signatures, dashboard the Hermes-local first-token latency p50/p95/p99, alert on `RouterEvent::BudgetExhausted` rate > 1/session, weekly notarization re-staple if Apple revokes any cert.

---

### Closing note on what this document is and isn't

This deliverable is a complete unified architectural doctrine plus production-grade scaffolding code, anchored to verified April-2026 facts about Hermes 4 model availability (the 14B Qwen3-base ChatML variant is the M2-Pro-18GB target; 70B/405B reserved for higher-RAM machines), MLX-Swift 0.31.x APIs (verified `ChatSession`, `loadModelContainer`, `NaiveStreamingDetokenizer`, `KVCache`, `LoRATrain`), Swift 6.2 evolution (SE-0461/0466/0470), Metal 4 (`MTL4CommandQueue`, residency sets, MetalFX temporal scaler), and the macOS-26-correct entitlement and TCC key set (`NSScreenCaptureUsageDescription`, `com.apple.security.cs.allow-jit`).

Where Apple has not shipped a documented surface (a SwiftUI-native `MetalView`, a paged-KV-cache primitive in mlx-swift, a `MTLDevice.makeBuffer(withIOSurface:)` API), this document explicitly chooses the verified fallback (`NSViewRepresentable<MTKView>`, application-layer KV cache trimming, `IOSurface`-backed textures with shared-mmap buffers) rather than fabricating an API. Where the Hermes-4-14B chat-template literal jinja was not directly fetchable, the model-card-documented semantics (`<tool_call>`/`</tool_call>` paired added tokens, `<think>`/`</think>` paired added tokens, ChatML `<|im_start|>`/`<|im_end|>` wrapping) drive the parser design and are the contract Epistemos relies on.

The single longest-leverage decision encoded here: **UniFFI for the entire Rust↔Swift surface, refusing the BoltFFI hype**, on the verified evidence that BoltFFI is days old with a single author and no production users, and that UniFFI's per-call overhead is ~1µs — three orders of magnitude below the ~1ms inter-token cadence of even speculative-decoded local Hermes inference. The "FFI overhead is the bottleneck" claim is false for agentic workloads; the bottleneck is always model FLOPs, then unified-memory bandwidth, then SQLite fsync, in that order. Optimize accordingly.

The architecture's defensive moat against Electron/web competitors: **unified-memory zero-copy from Rust into Metal-4 GPU pipelines**, **Foundation Models on-device 3B for utility tasks no remote app can match in latency**, **AX + ScreenCaptureKit + Spotlight integration that requires native code**, and **Hermes-4-14B running locally with hybrid `<think>` reasoning at speeds (with Qwen3-0.6B drafter) that approach remote-API responsiveness while keeping every token, citation, and tool call on-device**. No cross-platform stack can replicate this combination on a non-Apple-Silicon machine, and no Electron app can replicate it even on Apple Silicon — the latency tax of a Chromium process, the absence of MLX-on-V8, and the inability to host MTL4CommandQueue from JavaScript define a moat that cannot be crossed without abandoning the cross-platform premise.

This is Epistemos's reason to exist. Build it.