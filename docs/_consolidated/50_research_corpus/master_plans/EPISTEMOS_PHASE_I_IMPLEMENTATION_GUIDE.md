# Epistemos Phase I: Pure Rust Agent Runtime — Implementation Guide

> **Purpose**: This document is a working sprint file. Hand it to Claude Code. Every section contains real code patterns, not analysis. The research is done. This is the build plan.
>
> **Constraint envelope**: Swift 6 + Rust (UniFFI) + Metal. No Python. No venv. 18GB M2 Pro. Target: 8–12MB agent binary, <10ms cold start, zero-copy IPC via Apple Silicon UMA.

---

## 0. The Critical Path (Read This First)

Everything depends on one question: **can Rust stream tokens to Swift efficiently across UniFFI?**

If yes → the entire Goose Provider architecture works.  
If no → you need a different IPC strategy (XPC, shared memory, local HTTP).

**Day one task**: Build the UniFFI streaming bridge. Nothing else matters until this works.

The dependency graph:

```
UniFFI Streaming Bridge (Week 1, Days 1-3)
    ↓
Provider Trait Extraction (Week 1, Days 3-5)
    ↓
AnthropicProvider + OpenAIProvider (Week 2)
    ↓
MetalProvider wrapping MLX-Swift (Week 2-3)
    ↓
rmcp + Builtin Extensions (Week 3-4)
    ↓
Agent Loop with parallel dispatch (Week 4-5)
    ↓
Living Vault integration (Week 5-6)
    ↓
Kill Python subprocess (Week 6)
```

---

## 1. UniFFI Streaming Bridge

### The Problem

Goose's `Provider::stream()` returns `Pin<Box<dyn Stream<Item = Result<(Option<Message>, Option<ProviderUsage>), ProviderError>> + Send>>>`. This type cannot cross FFI. UniFFI doesn't support Rust async streams natively. You need a callback-based bridge where Rust pushes token chunks to Swift via a trait object, and Swift wraps that into an `AsyncStream`.

### Rust Side: `agent_core/src/bridge/stream.rs`

```rust
use uniffi;
use std::sync::Arc;

/// The callback Swift will implement to receive streaming chunks.
/// UniFFI generates the Swift protocol from this trait.
#[uniffi::export(callback_interface)]
pub trait TokenStreamCallback: Send + Sync {
    /// Called for each token chunk. `delta` is the text fragment.
    /// `tool_call_json` is non-None when the model emits a tool_use block.
    fn on_token(&self, delta: String, tool_call_json: Option<String>);

    /// Called once when the stream completes successfully.
    /// `usage` contains token counts for cost tracking.
    fn on_complete(&self, usage: ProviderUsageFFI);

    /// Called if the stream encounters an error.
    fn on_error(&self, error: String);
}

/// FFI-safe usage struct (UniFFI can't bridge complex enums directly)
#[derive(uniffi::Record)]
pub struct ProviderUsageFFI {
    pub input_tokens: u32,
    pub output_tokens: u32,
    pub model: String,
    pub cost_microdollars: Option<u64>,  // cost in µ$ for sub-cent precision
}

/// FFI-safe message representation
#[derive(uniffi::Record)]
pub struct MessageFFI {
    pub role: String,           // "user" | "assistant" | "system"
    pub content: String,        // text content
    pub tool_calls_json: Option<String>,  // serialized Vec<ToolCall>
    pub tool_result_json: Option<String>, // serialized ToolResult
}

/// FFI-safe tool definition
#[derive(uniffi::Record)]
pub struct ToolFFI {
    pub name: String,
    pub description: String,
    pub parameters_json: String,  // JSON Schema as string
}

/// The main agent handle exposed to Swift.
/// Wraps the internal Rust agent and manages the tokio runtime.
#[derive(uniffi::Object)]
pub struct AgentHandle {
    runtime: tokio::runtime::Runtime,
    // Internal agent state — Provider, ExtensionManager, SessionManager
    inner: Arc<AgentInner>,
}

#[uniffi::export]
impl AgentHandle {
    /// Create a new agent with the specified provider configuration.
    /// `provider_config_json` is a serialized ProviderConfig.
    #[uniffi::constructor]
    pub fn new(provider_config_json: String) -> Result<Self, AgentError> {
        // Build a multi-threaded tokio runtime.
        // On M2 Pro, 4 worker threads is optimal — leaves cores for Metal/MLX.
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(4)
            .enable_all()
            .build()
            .map_err(|e| AgentError::RuntimeInit(e.to_string()))?;

        let config: ProviderConfig = serde_json::from_str(&provider_config_json)
            .map_err(|e| AgentError::InvalidConfig(e.to_string()))?;

        let inner = runtime.block_on(async {
            AgentInner::new(config).await
        })?;

        Ok(Self {
            runtime,
            inner: Arc::new(inner),
        })
    }

    /// Send a message and stream the response via callback.
    /// This is the primary interface Swift calls for every user interaction.
    ///
    /// Non-blocking: spawns on the tokio runtime and returns immediately.
    /// All responses arrive via the callback on a background thread.
    pub fn send_message(
        &self,
        messages: Vec<MessageFFI>,
        tools: Vec<ToolFFI>,
        callback: Box<dyn TokenStreamCallback>,
    ) {
        let inner = self.inner.clone();
        let callback = Arc::new(callback);

        self.runtime.spawn(async move {
            // Convert FFI types to internal types
            let messages = messages.into_iter()
                .map(Message::from_ffi)
                .collect::<Vec<_>>();
            let tools = tools.into_iter()
                .map(Tool::from_ffi)
                .collect::<Vec<_>>();

            // Call the provider's stream method
            match inner.provider.stream(
                &inner.model_config,
                &inner.session_id,
                &inner.system_prompt,
                &messages,
                &tools,
            ).await {
                Ok(mut stream) => {
                    use futures::StreamExt;
                    while let Some(chunk) = stream.next().await {
                        match chunk {
                            Ok((maybe_msg, maybe_usage)) => {
                                if let Some(msg) = maybe_msg {
                                    // Extract text deltas and tool calls from the message
                                    let (delta, tool_json) = msg.extract_delta();
                                    callback.on_token(delta, tool_json);
                                }
                                if let Some(usage) = maybe_usage {
                                    callback.on_complete(usage.into_ffi());
                                }
                            }
                            Err(e) => {
                                callback.on_error(e.to_string());
                                return;
                            }
                        }
                    }
                }
                Err(e) => {
                    callback.on_error(e.to_string());
                }
            }
        });
    }

    /// Cancel any in-flight streaming request.
    /// Swift calls this when the user taps stop or navigates away.
    pub fn cancel(&self) {
        self.inner.cancel_token.cancel();
    }
}

/// Error types exposed to Swift
#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum AgentError {
    #[error("Runtime initialization failed: {0}")]
    RuntimeInit(String),
    #[error("Invalid configuration: {0}")]
    InvalidConfig(String),
    #[error("Provider error: {0}")]
    Provider(String),
    #[error("Tool execution error: {0}")]
    ToolExecution(String),
}
```

### Swift Side: `EpistemosApp/Agent/AgentBridge.swift`

```swift
import EpistemosAgentCore  // The generated UniFFI Swift module

/// Wraps the Rust AgentHandle into Swift's structured concurrency world.
/// This is the single point of contact between SwiftUI and the Rust agent.
actor AgentBridge {
    private let handle: AgentHandle
    
    init(providerConfig: ProviderConfig) throws {
        let json = try JSONEncoder().encode(providerConfig)
        self.handle = try AgentHandle(
            providerConfigJson: String(data: json, encoding: .utf8)!
        )
    }
    
    /// Stream a response as an AsyncSequence of token chunks.
    /// SwiftUI views consume this directly via `for await chunk in stream`.
    func stream(
        messages: [Message],
        tools: [Tool]
    ) -> AsyncThrowingStream<TokenChunk, Error> {
        // Convert Swift types to FFI types
        let ffiMessages = messages.map { $0.toFFI() }
        let ffiTools = tools.map { $0.toFFI() }
        
        return AsyncThrowingStream { continuation in
            // Create the callback that bridges Rust → Swift async
            let callback = StreamCallbackImpl(continuation: continuation)
            
            // Fire-and-forget: Rust streams back via callback
            self.handle.sendMessage(
                messages: ffiMessages,
                tools: ffiTools,
                callback: callback
            )
            
            // Wire up cancellation: when Swift cancels the stream,
            // tell Rust to stop generating
            continuation.onTermination = { @Sendable _ in
                self.handle.cancel()
            }
        }
    }
}

/// The concrete callback implementation that UniFFI calls from Rust.
/// Each method pushes into the AsyncThrowingStream's continuation.
final class StreamCallbackImpl: TokenStreamCallback {
    private let continuation: AsyncThrowingStream<TokenChunk, Error>.Continuation
    
    init(continuation: AsyncThrowingStream<TokenChunk, Error>.Continuation) {
        self.continuation = continuation
    }
    
    func onToken(delta: String, toolCallJson: String?) {
        let chunk = TokenChunk(
            text: delta,
            toolCall: toolCallJson.flatMap { try? JSONDecoder().decode(ToolCall.self, from: $0.data(using: .utf8)!) }
        )
        continuation.yield(chunk)
    }
    
    func onComplete(usage: ProviderUsageFFI) {
        // Emit final usage as a special chunk, then finish
        let chunk = TokenChunk(text: "", usage: Usage(from: usage))
        continuation.yield(chunk)
        continuation.finish()
    }
    
    func onError(error: String) {
        continuation.finish(throwing: AgentError.provider(error))
    }
}

/// The token chunk that SwiftUI views consume
struct TokenChunk: Sendable {
    let text: String
    let toolCall: ToolCall?
    let usage: Usage?
    
    init(text: String, toolCall: ToolCall? = nil, usage: Usage? = nil) {
        self.text = text
        self.toolCall = toolCall
        self.usage = usage
    }
}
```

### SwiftUI Integration: Consuming the Stream

```swift
/// In a SwiftUI view model
@Observable
final class ChatViewModel {
    private let agent: AgentBridge
    var responseText = ""
    var isStreaming = false
    var currentTask: Task<Void, Never>?
    
    func send(_ userMessage: String) {
        isStreaming = true
        responseText = ""
        
        currentTask = Task {
            do {
                let messages = buildMessageHistory(appending: userMessage)
                let tools = extensionManager.allTools()
                
                for try await chunk in await agent.stream(
                    messages: messages,
                    tools: tools
                ) {
                    // Append text deltas to the response
                    // This drives the SwiftUI view update at ~60fps
                    responseText += chunk.text
                    
                    // Handle tool calls inline
                    if let toolCall = chunk.toolCall {
                        let result = await extensionManager.execute(toolCall)
                        // Feed tool result back — this continues the agent loop
                        // (see Section 6 for the full agent loop)
                    }
                }
            } catch {
                responseText += "\n\n[Error: \(error.localizedDescription)]"
            }
            isStreaming = false
        }
    }
    
    func stop() {
        currentTask?.cancel()
    }
}
```

### Proving It Works (Day 1 Validation)

Before touching Goose code, prove the bridge works with a mock:

```rust
// agent_core/src/bridge/mock_provider.rs
pub struct MockProvider;

#[async_trait]
impl Provider for MockProvider {
    async fn stream(
        &self, _config: &ModelConfig, _sid: &str,
        _system: &str, _messages: &[Message], _tools: &[Tool],
    ) -> Result<MessageStream, ProviderError> {
        // Simulate token-by-token streaming with realistic timing
        let tokens = "Hello from Rust! The bridge is working.".split_whitespace()
            .map(|s| s.to_string())
            .collect::<Vec<_>>();

        Ok(Box::pin(async_stream::stream! {
            for token in tokens {
                tokio::time::sleep(std::time::Duration::from_millis(50)).await;
                let msg = Message::assistant_text(format!("{token} "));
                yield Ok((Some(msg), None));
            }
            yield Ok((None, Some(ProviderUsage {
                input_tokens: 10, output_tokens: 8, model: "mock".into(),
            })));
        }))
    }
    // ... other trait methods with minimal stubs
}
```

If tokens arrive in SwiftUI word-by-word at ~50ms intervals with no crashes, the bridge is proven. Move to Provider extraction.

---

## 2. Goose Provider Trait Extraction

### What to Vendor (Exact Files)

Clone the Goose repo at a pinned commit. Copy these files into `agent_core/src/providers/`:

```
goose/crates/goose/src/providers/
├── base.rs           → The Provider + ProviderDef traits
├── errors.rs         → ProviderError enum
├── configs/          → Declarative JSON provider definitions
├── anthropic.rs      → Anthropic streaming + tool parsing
├── openai.rs         → OpenAI-compatible streaming
├── google.rs         → Google/Gemini provider
├── ollama.rs         → Local Ollama (useful for llama.cpp sidecar)
├── formats/          → Message format converters per provider
│   ├── anthropic.rs
│   ├── openai.rs
│   └── google.rs
└── utils.rs          → stream_openai_compat(), retry logic
```

### Stripping Unnecessary Dependencies

Goose's Provider module pulls in dependencies you don't need. Here's what to cut:

```toml
# agent_core/Cargo.toml — The LEAN dependency set
[dependencies]
# Core async
tokio = { version = "1", features = ["rt-multi-thread", "macros", "sync", "time"] }
futures = "0.3"
async-trait = "0.1"
async-stream = "0.3"

# HTTP + TLS (use Apple's native TLS to save ~1MB)
reqwest = { version = "0.12", default-features = false, features = [
    "json", "stream", "native-tls"  # NOT rustls — saves ~1MB binary
] }

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# MCP protocol
rmcp = { version = "0.9", features = ["client", "server", "transport-child-process"] }

# Error handling
thiserror = "2"
anyhow = "1"

# Logging (bridges to os_log via tracing-oslog)
tracing = "0.1"

# Template engine for system prompts (Goose uses Tera — it's lightweight)
tera = "1"

# UniFFI bindings
uniffi = "0.28"

# Keychain access (macOS native, replaces Goose's `keyring` crate)
security-framework = "3"

# Token counting (tiktoken-rs for accurate context window tracking)
tiktoken-rs = "0.6"

# SQLite for session persistence (you already have this via GRDB)
rusqlite = { version = "0.32", features = ["bundled"] }

# DO NOT INCLUDE:
# lancedb        — replace with sqlite-vec + tantivy (you already have these)
# v8             — sandboxed JS execution, unnecessary
# indicatif      — CLI progress bars
# clap           — CLI argument parsing
# open           — opens URLs in browser
# xcap           — screenshot capture (use ScreenCaptureKit directly from Swift)
```

### Adapting the Provider Trait

The Goose trait is almost perfect as-is. The one adaptation: add `CancellationToken` support for SwiftUI lifecycle integration.

```rust
// agent_core/src/providers/base.rs
// Adapted from Goose — added cancellation and simplified to Epistemos needs

use async_trait::async_trait;
use futures::Stream;
use std::pin::Pin;
use tokio_util::sync::CancellationToken;

/// A stream of partial message chunks from an LLM provider.
/// Each item is either a text/tool delta, a usage report, or an error.
pub type MessageStream = Pin<
    Box<dyn Stream<Item = Result<StreamChunk, ProviderError>> + Send>
>;

/// A single chunk in the stream. Simpler than Goose's tuple.
pub enum StreamChunk {
    /// A text delta or tool-use block
    Delta(MessageDelta),
    /// Final usage statistics (emitted once at end of stream)
    Usage(ProviderUsage),
}

/// The core provider abstraction.
/// Every LLM backend (cloud or local) implements this.
#[async_trait]
pub trait Provider: Send + Sync {
    /// Human-readable provider name: "anthropic", "openai", "metal-mlx", etc.
    fn name(&self) -> &str;

    /// Stream a completion. This is the hot path — every user message flows through here.
    ///
    /// `cancel` allows SwiftUI to abort mid-stream when the user taps stop
    /// or navigates away. Implementations should check `cancel.is_cancelled()`
    /// between chunk yields and bail early.
    async fn stream(
        &self,
        config: &ModelConfig,
        system: &str,
        messages: &[Message],
        tools: &[Tool],
        cancel: CancellationToken,
    ) -> Result<MessageStream, ProviderError>;

    /// Non-streaming one-shot completion.
    /// Default implementation collects the stream — override for efficiency.
    async fn complete(
        &self,
        config: &ModelConfig,
        system: &str,
        messages: &[Message],
        tools: &[Tool],
    ) -> Result<(Message, ProviderUsage), ProviderError> {
        let cancel = CancellationToken::new(); // no external cancel for one-shot
        let stream = self.stream(config, system, messages, tools, cancel).await?;
        collect_stream(stream).await
    }

    /// Model configuration (context window, temperature, known models).
    fn model_config(&self) -> &ModelConfig;

    /// Optional: cheap model for session naming, intent classification, etc.
    /// Defaults to the primary model.
    fn fast_model_config(&self) -> &ModelConfig {
        self.model_config()
    }
}

/// Provider metadata + factory. Used for auto-discovery and configuration.
pub trait ProviderDef {
    /// Configuration keys needed (API keys, OAuth tokens, endpoints).
    fn config_keys(&self) -> Vec<ConfigKey>;

    /// Construct a provider from environment/keychain values.
    fn from_config(config: &ProviderConfig) -> Result<Box<dyn Provider>, ProviderError>;

    /// Known models for this provider (used in UI model picker).
    fn known_models(&self) -> Vec<KnownModel>;
}
```

### The Anthropic Provider (Adapted from Goose)

```rust
// agent_core/src/providers/anthropic.rs
// Core streaming logic adapted from Goose's Anthropic provider

use crate::providers::base::*;
use reqwest::Client;
use futures::StreamExt;

pub struct AnthropicProvider {
    client: Client,
    api_key: String,
    config: ModelConfig,
}

impl AnthropicProvider {
    pub fn new(api_key: String, model: &str) -> Self {
        Self {
            client: Client::new(),
            api_key,
            config: ModelConfig {
                model: model.to_string(),
                context_window: 200_000,  // Claude models
                max_output: 8_192,
                temperature: 0.7,
            },
        }
    }
}

#[async_trait]
impl Provider for AnthropicProvider {
    fn name(&self) -> &str { "anthropic" }
    fn model_config(&self) -> &ModelConfig { &self.config }

    async fn stream(
        &self,
        config: &ModelConfig,
        system: &str,
        messages: &[Message],
        tools: &[Tool],
        cancel: CancellationToken,
    ) -> Result<MessageStream, ProviderError> {
        // Build the Anthropic API request body
        let body = serde_json::json!({
            "model": config.model,
            "max_tokens": config.max_output,
            "temperature": config.temperature,
            "system": system,
            "messages": messages.iter().map(|m| m.to_anthropic()).collect::<Vec<_>>(),
            "tools": tools.iter().map(|t| t.to_anthropic()).collect::<Vec<_>>(),
            "stream": true,
        });

        // Open the SSE stream
        let response = self.client
            .post("https://api.anthropic.com/v1/messages")
            .header("x-api-key", &self.api_key)
            .header("anthropic-version", "2023-06-01")
            .header("content-type", "application/json")
            .json(&body)
            .send()
            .await
            .map_err(|e| ProviderError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(ProviderError::Api { status: status.as_u16(), body });
        }

        // Parse SSE events into StreamChunks
        let byte_stream = response.bytes_stream();
        let stream = async_stream::stream! {
            let mut buffer = String::new();
            let mut current_text = String::new();
            let mut tool_use_blocks: Vec<ToolUseBlock> = Vec::new();
            let mut usage = ProviderUsage::default();

            // Streaming SSE parser — each `data: {...}` line is a JSON event
            futures::pin_mut!(byte_stream);
            while let Some(chunk_result) = byte_stream.next().await {
                // Check cancellation between chunks
                if cancel.is_cancelled() {
                    break;
                }

                let bytes = chunk_result.map_err(|e| ProviderError::Network(e.to_string()))?;
                buffer.push_str(&String::from_utf8_lossy(&bytes));

                // Process complete SSE lines
                while let Some(line_end) = buffer.find('\n') {
                    let line = buffer[..line_end].trim().to_string();
                    buffer = buffer[line_end + 1..].to_string();

                    if !line.starts_with("data: ") { continue; }
                    let json_str = &line[6..];
                    if json_str == "[DONE]" { continue; }

                    let event: serde_json::Value = match serde_json::from_str(json_str) {
                        Ok(v) => v,
                        Err(_) => continue,
                    };

                    match event["type"].as_str() {
                        Some("content_block_delta") => {
                            if let Some(text) = event["delta"]["text"].as_str() {
                                yield Ok(StreamChunk::Delta(MessageDelta::Text(text.to_string())));
                            }
                            // Handle tool_use input_json_delta
                            if let Some(partial) = event["delta"]["partial_json"].as_str() {
                                // Accumulate partial JSON for tool calls
                                if let Some(block) = tool_use_blocks.last_mut() {
                                    block.partial_json.push_str(partial);
                                }
                            }
                        }
                        Some("content_block_start") => {
                            if event["content_block"]["type"].as_str() == Some("tool_use") {
                                tool_use_blocks.push(ToolUseBlock {
                                    id: event["content_block"]["id"].as_str().unwrap_or("").to_string(),
                                    name: event["content_block"]["name"].as_str().unwrap_or("").to_string(),
                                    partial_json: String::new(),
                                });
                            }
                        }
                        Some("content_block_stop") => {
                            // Emit completed tool call
                            if let Some(block) = tool_use_blocks.last() {
                                if !block.name.is_empty() {
                                    yield Ok(StreamChunk::Delta(MessageDelta::ToolUse {
                                        id: block.id.clone(),
                                        name: block.name.clone(),
                                        arguments_json: block.partial_json.clone(),
                                    }));
                                }
                            }
                        }
                        Some("message_delta") => {
                            // Extract final usage from message_delta
                            if let Some(u) = event["usage"].as_object() {
                                usage.output_tokens = u.get("output_tokens")
                                    .and_then(|v| v.as_u64())
                                    .unwrap_or(0) as u32;
                            }
                        }
                        Some("message_start") => {
                            if let Some(u) = event["message"]["usage"].as_object() {
                                usage.input_tokens = u.get("input_tokens")
                                    .and_then(|v| v.as_u64())
                                    .unwrap_or(0) as u32;
                            }
                            usage.model = event["message"]["model"]
                                .as_str().unwrap_or("").to_string();
                        }
                        _ => {}
                    }
                }
            }
            // Emit final usage
            yield Ok(StreamChunk::Usage(usage));
        };

        Ok(Box::pin(stream))
    }
}
```

---

## 3. MetalProvider: Wrapping MLX-Swift for Local Inference

This is the most novel piece — making a local MLX model look identical to a cloud provider through the same `Provider` trait. The key insight: MLX-Swift runs on the Swift side, so the MetalProvider actually calls *back into Swift* from Rust, inverting the usual call direction.

### Architecture

```
SwiftUI → AgentBridge (Swift) → UniFFI → AgentHandle (Rust)
                                              ↓
                                    MetalProvider::stream()
                                              ↓
                                    UniFFI callback → Swift
                                              ↓
                                    MLXInferenceEngine (Swift/Metal)
                                              ↓
                                    tokens stream back to Rust
                                              ↓
                                    Rust yields StreamChunks
                                              ↓
                                    UniFFI callback → Swift
                                              ↓
                                    SwiftUI renders
```

### Rust Side: The MetalProvider

```rust
// agent_core/src/providers/metal.rs
// Local inference via MLX-Swift, called back through UniFFI

use crate::providers::base::*;
use std::sync::Arc;
use tokio::sync::mpsc;

/// Callback interface that Swift's MLX engine implements.
/// Rust calls this to request inference; Swift runs Metal compute
/// and pushes tokens back via the channel.
#[uniffi::export(callback_interface)]
pub trait MLXInferenceCallback: Send + Sync {
    /// Request a streaming completion from the local MLX model.
    /// `request_json` contains the full prompt + params as JSON.
    /// `token_sender_id` is an opaque handle that Swift uses to
    /// push tokens back to the correct Rust channel.
    fn generate(
        &self,
        request_json: String,
        token_sender_id: u64,
    );

    /// Cancel an in-flight generation.
    fn cancel_generation(&self, token_sender_id: u64);
}

/// Callback for Swift to push individual tokens back to Rust.
/// Registered once at startup; Swift calls it from the Metal inference thread.
#[uniffi::export(callback_interface)]
pub trait MLXTokenReceiver: Send + Sync {
    fn receive_token(&self, sender_id: u64, token: String);
    fn receive_complete(&self, sender_id: u64, usage_json: String);
    fn receive_error(&self, sender_id: u64, error: String);
}

pub struct MetalProvider {
    mlx_callback: Arc<dyn MLXInferenceCallback>,
    config: ModelConfig,
    /// Channel registry: maps sender_id → mpsc::Sender
    /// so tokens from Swift can be routed to the correct stream
    channels: Arc<dashmap::DashMap<u64, mpsc::UnboundedSender<TokenEvent>>>,
    next_id: Arc<std::sync::atomic::AtomicU64>,
}

enum TokenEvent {
    Token(String),
    Complete(ProviderUsage),
    Error(String),
}

impl MetalProvider {
    pub fn new(
        mlx_callback: Arc<dyn MLXInferenceCallback>,
        model_name: &str,
        context_window: u32,
    ) -> Self {
        Self {
            mlx_callback,
            config: ModelConfig {
                model: model_name.to_string(),
                context_window,
                max_output: 4096,
                temperature: 0.7,
            },
            channels: Arc::new(dashmap::DashMap::new()),
            next_id: Arc::new(std::sync::atomic::AtomicU64::new(1)),
        }
    }

    /// Returns a token receiver that Swift holds and calls into.
    /// This bridges Metal inference → Rust async streams.
    pub fn create_token_receiver(self: &Arc<Self>) -> Arc<MetalTokenReceiverImpl> {
        Arc::new(MetalTokenReceiverImpl {
            channels: self.channels.clone(),
        })
    }
}

/// The concrete receiver Swift calls from the Metal thread.
pub struct MetalTokenReceiverImpl {
    channels: Arc<dashmap::DashMap<u64, mpsc::UnboundedSender<TokenEvent>>>,
}

impl MLXTokenReceiver for MetalTokenReceiverImpl {
    fn receive_token(&self, sender_id: u64, token: String) {
        if let Some(tx) = self.channels.get(&sender_id) {
            let _ = tx.send(TokenEvent::Token(token));
        }
    }
    fn receive_complete(&self, sender_id: u64, usage_json: String) {
        if let Some(tx) = self.channels.get(&sender_id) {
            let usage: ProviderUsage = serde_json::from_str(&usage_json)
                .unwrap_or_default();
            let _ = tx.send(TokenEvent::Complete(usage));
        }
        self.channels.remove(&sender_id);
    }
    fn receive_error(&self, sender_id: u64, error: String) {
        if let Some(tx) = self.channels.get(&sender_id) {
            let _ = tx.send(TokenEvent::Error(error));
        }
        self.channels.remove(&sender_id);
    }
}

#[async_trait]
impl Provider for MetalProvider {
    fn name(&self) -> &str { "metal-mlx" }
    fn model_config(&self) -> &ModelConfig { &self.config }

    async fn stream(
        &self,
        config: &ModelConfig,
        system: &str,
        messages: &[Message],
        tools: &[Tool],
        cancel: CancellationToken,
    ) -> Result<MessageStream, ProviderError> {
        // Allocate a unique sender ID for this request
        let sender_id = self.next_id.fetch_add(1, std::sync::atomic::Ordering::Relaxed);

        // Create channel for tokens from Swift → Rust
        let (tx, mut rx) = mpsc::unbounded_channel();
        self.channels.insert(sender_id, tx);

        // Build the inference request
        // Format messages into the model's chat template
        let request = serde_json::json!({
            "model": config.model,
            "system": system,
            "messages": messages.iter().map(|m| m.to_chat_ml()).collect::<Vec<_>>(),
            "tools": tools.iter().map(|t| t.to_json_schema()).collect::<Vec<_>>(),
            "max_tokens": config.max_output,
            "temperature": config.temperature,
        });

        // Tell Swift/MLX to start generating
        let request_json = serde_json::to_string(&request)
            .map_err(|e| ProviderError::Internal(e.to_string()))?;
        self.mlx_callback.generate(request_json, sender_id);

        // Set up cancellation
        let mlx_cb = self.mlx_callback.clone();
        let cancel_clone = cancel.clone();
        tokio::spawn(async move {
            cancel_clone.cancelled().await;
            mlx_cb.cancel_generation(sender_id);
        });

        // Convert the channel into a MessageStream
        let stream = async_stream::stream! {
            // Accumulate tool call JSON from the model's output
            let mut tool_parser = ToolCallParser::new();

            while let Some(event) = rx.recv().await {
                if cancel.is_cancelled() { break; }

                match event {
                    TokenEvent::Token(text) => {
                        // Try to parse tool calls from the token stream.
                        // Local models emit tool calls as structured text
                        // (e.g., Qwen's <tool_call>...</tool_call> format).
                        match tool_parser.feed(&text) {
                            ParseResult::Text(t) => {
                                yield Ok(StreamChunk::Delta(MessageDelta::Text(t)));
                            }
                            ParseResult::ToolCall(tc) => {
                                yield Ok(StreamChunk::Delta(MessageDelta::ToolUse {
                                    id: tc.id,
                                    name: tc.name,
                                    arguments_json: tc.arguments,
                                }));
                            }
                            ParseResult::Buffering => {
                                // Accumulating potential tool call, don't yield yet
                            }
                        }
                    }
                    TokenEvent::Complete(usage) => {
                        // Flush any remaining buffered text
                        if let Some(remaining) = tool_parser.flush() {
                            yield Ok(StreamChunk::Delta(MessageDelta::Text(remaining)));
                        }
                        yield Ok(StreamChunk::Usage(usage));
                        break;
                    }
                    TokenEvent::Error(e) => {
                        yield Err(ProviderError::Inference(e));
                        break;
                    }
                }
            }
        };

        Ok(Box::pin(stream))
    }
}
```

### Swift Side: MLX Inference Engine

```swift
// EpistemosApp/Agent/MLXInferenceEngine.swift
import MLX
import MLXLLM
import MLXRandom

/// Implements the Rust MLXInferenceCallback protocol.
/// Runs local model inference on Metal and streams tokens back to Rust.
final class MLXInferenceEngine: MLXInferenceCallback, @unchecked Sendable {
    private let model: LLMModel
    private let tokenizer: Tokenizer
    private var activeTasks: [UInt64: Task<Void, Never>] = [:]
    private let lock = NSLock()
    
    /// The token receiver Rust provides — we call this to push tokens back
    var tokenReceiver: MLXTokenReceiver?
    
    init(modelPath: URL) async throws {
        // Load the MLX model from the local safetensors cache.
        // This is where the 3.4GB Qwen3.5-4B-4bit gets loaded.
        let configuration = ModelConfiguration(id: modelPath.path)
        (self.model, self.tokenizer) = try await LLM.load(configuration: configuration)
    }
    
    func generate(requestJson: String, tokenSenderId: UInt64) {
        guard let receiver = tokenReceiver else { return }
        guard let data = requestJson.data(using: .utf8),
              let request = try? JSONDecoder().decode(InferenceRequest.self, from: data)
        else {
            receiver.receiveError(senderId: tokenSenderId, error: "Invalid request JSON")
            return
        }
        
        let task = Task.detached(priority: .userInitiated) { [model, tokenizer, receiver] in
            do {
                // Build the prompt using the model's chat template
                let prompt = ChatTemplate.apply(
                    messages: request.messages,
                    tools: request.tools,
                    system: request.system,
                    tokenizer: tokenizer
                )
                
                let tokens = tokenizer.encode(text: prompt)
                let inputArray = MLXArray(tokens)
                
                var outputTokens = 0
                let startTime = CFAbsoluteTimeGetCurrent()
                
                // The core inference loop — Metal compute happens here.
                // Each iteration produces one token via the model's forward pass.
                for await token in model.generate(
                    input: inputArray,
                    parameters: .init(
                        temperature: Float(request.temperature),
                        topP: 0.9,
                        repetitionPenalty: 1.05
                    )
                ) {
                    // Check for cancellation
                    if Task.isCancelled { break }
                    
                    // Stop conditions
                    if tokenizer.isSpecialToken(token) { break }
                    if outputTokens >= request.maxTokens { break }
                    
                    // Decode token to text and push to Rust
                    let text = tokenizer.decode([token])
                    receiver.receiveToken(senderId: tokenSenderId, token: text)
                    outputTokens += 1
                }
                
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                let tokPerSec = Double(outputTokens) / elapsed
                
                // Send completion with usage stats
                let usage = ProviderUsageFFI(
                    inputTokens: UInt32(tokens.count),
                    outputTokens: UInt32(outputTokens),
                    model: request.model,
                    costMicrodollars: 0  // local inference is free
                )
                let usageJson = try JSONEncoder().encode(usage)
                receiver.receiveComplete(
                    senderId: tokenSenderId,
                    usageJson: String(data: usageJson, encoding: .utf8) ?? "{}"
                )
                
            } catch {
                receiver.receiveError(
                    senderId: tokenSenderId,
                    error: error.localizedDescription
                )
            }
        }
        
        // Track active task for cancellation
        lock.lock()
        activeTasks[tokenSenderId] = task
        lock.unlock()
    }
    
    func cancelGeneration(tokenSenderId: UInt64) {
        lock.lock()
        activeTasks[tokenSenderId]?.cancel()
        activeTasks.removeValue(forKey: tokenSenderId)
        lock.unlock()
    }
}
```

---

## 4. Tool Call Parsing for Local Models

Cloud providers (Anthropic, OpenAI) return tool calls as structured JSON in the SSE stream. Local models emit them as text. You need a streaming parser that detects tool call patterns mid-generation.

### Qwen 3.5 Tool Call Format

Qwen uses this format when tools are provided:

```
<tool_call>
{"name": "read_file", "arguments": {"path": "/Users/jordan/vault/note.md"}}
</tool_call>
```

### The Streaming Parser

```rust
// agent_core/src/providers/tool_parser.rs
// Streaming parser that detects tool calls in local model output

/// State machine for parsing tool calls from a token stream.
/// Handles partial tokens (e.g., "<tool" arriving in one chunk,
/// "_call>" in the next).
pub struct ToolCallParser {
    buffer: String,
    state: ParserState,
    tool_call_count: u32,
}

enum ParserState {
    /// Normal text output — pass through
    Text,
    /// Detected potential start tag — accumulating to confirm
    MaybeTag,
    /// Inside a tool_call block — accumulating JSON
    InToolCall,
}

pub enum ParseResult {
    /// Regular text to display
    Text(String),
    /// A complete tool call was parsed
    ToolCall(ParsedToolCall),
    /// Accumulating — don't yield anything yet
    Buffering,
}

pub struct ParsedToolCall {
    pub id: String,
    pub name: String,
    pub arguments: String,  // raw JSON string
}

impl ToolCallParser {
    pub fn new() -> Self {
        Self {
            buffer: String::new(),
            state: ParserState::Text,
            tool_call_count: 0,
        }
    }

    /// Feed a token into the parser. Returns what to yield to the stream.
    pub fn feed(&mut self, token: &str) -> ParseResult {
        self.buffer.push_str(token);

        match self.state {
            ParserState::Text => {
                // Check if buffer might contain start of a tool call tag
                if self.buffer.contains("<tool_call>") {
                    // Split: everything before the tag is text, the rest is tool call
                    let idx = self.buffer.find("<tool_call>").unwrap();
                    let text_before = self.buffer[..idx].to_string();
                    self.buffer = self.buffer[idx + "<tool_call>".len()..].to_string();
                    self.state = ParserState::InToolCall;

                    if text_before.is_empty() {
                        ParseResult::Buffering
                    } else {
                        ParseResult::Text(text_before)
                    }
                } else if self.buffer.ends_with('<')
                    || self.buffer.ends_with("<t")
                    || self.buffer.ends_with("<to")
                    || self.buffer.ends_with("<too")
                    || self.buffer.ends_with("<tool")
                    || self.buffer.ends_with("<tool_")
                    || self.buffer.ends_with("<tool_c")
                    || self.buffer.ends_with("<tool_ca")
                    || self.buffer.ends_with("<tool_cal")
                    || self.buffer.ends_with("<tool_call")
                {
                    // Might be the start of a tag — hold the buffer
                    self.state = ParserState::MaybeTag;
                    // Yield everything except the potential tag prefix
                    let safe_end = self.buffer.rfind('<').unwrap_or(self.buffer.len());
                    if safe_end > 0 {
                        let text = self.buffer[..safe_end].to_string();
                        self.buffer = self.buffer[safe_end..].to_string();
                        ParseResult::Text(text)
                    } else {
                        ParseResult::Buffering
                    }
                } else {
                    // Normal text — flush the whole buffer
                    let text = std::mem::take(&mut self.buffer);
                    ParseResult::Text(text)
                }
            }
            ParserState::MaybeTag => {
                if self.buffer.contains("<tool_call>") {
                    let idx = self.buffer.find("<tool_call>").unwrap();
                    let text_before = self.buffer[..idx].to_string();
                    self.buffer = self.buffer[idx + "<tool_call>".len()..].to_string();
                    self.state = ParserState::InToolCall;
                    if text_before.is_empty() {
                        ParseResult::Buffering
                    } else {
                        ParseResult::Text(text_before)
                    }
                } else if !("<tool_call>".starts_with(&self.buffer)
                    || self.buffer.starts_with("<tool_call>"))
                {
                    // False alarm — not a tag after all
                    self.state = ParserState::Text;
                    let text = std::mem::take(&mut self.buffer);
                    ParseResult::Text(text)
                } else {
                    ParseResult::Buffering
                }
            }
            ParserState::InToolCall => {
                // Accumulate until we see the closing tag
                if self.buffer.contains("</tool_call>") {
                    let idx = self.buffer.find("</tool_call>").unwrap();
                    let json_str = self.buffer[..idx].trim().to_string();
                    self.buffer = self.buffer[idx + "</tool_call>".len()..].to_string();
                    self.state = ParserState::Text;

                    // Parse the JSON and emit a ToolCall
                    match serde_json::from_str::<serde_json::Value>(&json_str) {
                        Ok(v) => {
                            self.tool_call_count += 1;
                            ParseResult::ToolCall(ParsedToolCall {
                                id: format!("local_tc_{}", self.tool_call_count),
                                name: v["name"].as_str().unwrap_or("unknown").to_string(),
                                arguments: v["arguments"].to_string(),
                            })
                        }
                        Err(_) => {
                            // Malformed JSON — emit as text so user sees it
                            ParseResult::Text(format!("<tool_call>{json_str}</tool_call>"))
                        }
                    }
                } else {
                    ParseResult::Buffering
                }
            }
        }
    }

    /// Flush remaining buffer (call at end of stream)
    pub fn flush(&mut self) -> Option<String> {
        if self.buffer.is_empty() {
            None
        } else {
            Some(std::mem::take(&mut self.buffer))
        }
    }
}
```

---

## 5. Builtin Extensions (Zero-IPC Native Tools)

These compile directly into the agent binary. No subprocess, no stdio, no MCP transport overhead. Each tool is a Rust function that the agent loop calls directly.

### The Extension Trait (Adapted from Goose)

```rust
// agent_core/src/extensions/mod.rs

use serde_json::Value;

/// A tool exposed to the LLM. Contains everything the model needs
/// to decide when and how to call it.
#[derive(Clone, Debug, serde::Serialize)]
pub struct ToolDefinition {
    pub name: String,
    pub description: String,
    pub parameters: Value,  // JSON Schema
}

/// Result of executing a tool
pub struct ToolResult {
    pub content: String,          // text content for the model
    pub is_error: bool,
    pub metadata: Option<Value>,  // optional structured data
}

/// An extension provides a group of related tools.
/// Builtin extensions are compiled into the binary.
#[async_trait]
pub trait Extension: Send + Sync {
    /// Extension name (used for tool namespacing: "developer__read_file")
    fn name(&self) -> &str;

    /// Human-readable description injected into the system prompt
    fn description(&self) -> &str;

    /// Instructions appended to the system prompt when this extension is active
    fn instructions(&self) -> &str { "" }

    /// All tools this extension provides
    fn tools(&self) -> Vec<ToolDefinition>;

    /// Execute a tool call. `name` is the tool name WITHOUT the extension prefix.
    async fn call_tool(&self, name: &str, arguments: Value) -> Result<ToolResult, ToolError>;
}
```

### The Developer Extension (Core Coding Tools)

```rust
// agent_core/src/extensions/developer.rs
// File operations, shell execution, search — the 17 core tools

use super::*;
use std::path::PathBuf;
use tokio::process::Command;

pub struct DeveloperExtension {
    /// Root directory for file operations (vault path)
    root: PathBuf,
    /// Allowed shell commands (security boundary)
    allowed_commands: Vec<String>,
}

impl DeveloperExtension {
    pub fn new(root: PathBuf) -> Self {
        Self {
            root,
            allowed_commands: vec![
                "ls", "cat", "head", "tail", "wc", "find", "grep",
                "rg", "fd", "git", "diff", "patch", "mkdir", "cp", "mv",
            ].into_iter().map(String::from).collect(),
        }
    }

    /// Resolve and validate a path against the root (prevent directory traversal)
    fn resolve_path(&self, path: &str) -> Result<PathBuf, ToolError> {
        let resolved = if path.starts_with('/') {
            PathBuf::from(path)
        } else {
            self.root.join(path)
        };
        let canonical = resolved.canonicalize()
            .map_err(|e| ToolError::InvalidPath(e.to_string()))?;

        // Security: ensure the path is within the root
        if !canonical.starts_with(&self.root) {
            return Err(ToolError::AccessDenied(format!(
                "Path {} is outside the allowed root {}",
                canonical.display(), self.root.display()
            )));
        }
        Ok(canonical)
    }

    // ──────────────── Individual tool implementations ────────────────

    async fn read_file(&self, args: Value) -> Result<ToolResult, ToolError> {
        let path = args["path"].as_str()
            .ok_or(ToolError::MissingParam("path"))?;
        let resolved = self.resolve_path(path)?;

        let content = tokio::fs::read_to_string(&resolved).await
            .map_err(|e| ToolError::IO(e.to_string()))?;

        // Add line numbers for the model's reference
        let numbered = content.lines().enumerate()
            .map(|(i, line)| format!("{:>4} | {}", i + 1, line))
            .collect::<Vec<_>>()
            .join("\n");

        Ok(ToolResult {
            content: numbered,
            is_error: false,
            metadata: Some(serde_json::json!({
                "path": resolved.display().to_string(),
                "lines": content.lines().count(),
                "bytes": content.len(),
            })),
        })
    }

    async fn write_file(&self, args: Value) -> Result<ToolResult, ToolError> {
        let path = args["path"].as_str()
            .ok_or(ToolError::MissingParam("path"))?;
        let content = args["content"].as_str()
            .ok_or(ToolError::MissingParam("content"))?;

        // For new files, resolve against root without requiring existence
        let resolved = self.root.join(path);

        // Create parent directories if needed
        if let Some(parent) = resolved.parent() {
            tokio::fs::create_dir_all(parent).await
                .map_err(|e| ToolError::IO(e.to_string()))?;
        }

        tokio::fs::write(&resolved, content).await
            .map_err(|e| ToolError::IO(e.to_string()))?;

        Ok(ToolResult {
            content: format!("Wrote {} bytes to {}", content.len(), resolved.display()),
            is_error: false,
            metadata: None,
        })
    }

    async fn edit_file(&self, args: Value) -> Result<ToolResult, ToolError> {
        let path = args["path"].as_str()
            .ok_or(ToolError::MissingParam("path"))?;
        let old_str = args["old_str"].as_str()
            .ok_or(ToolError::MissingParam("old_str"))?;
        let new_str = args["new_str"].as_str()
            .ok_or(ToolError::MissingParam("new_str"))?;

        let resolved = self.resolve_path(path)?;
        let content = tokio::fs::read_to_string(&resolved).await
            .map_err(|e| ToolError::IO(e.to_string()))?;

        // Ensure the old string appears exactly once (deterministic edit)
        let count = content.matches(old_str).count();
        if count == 0 {
            return Err(ToolError::EditFailed(
                "old_str not found in file".to_string()
            ));
        }
        if count > 1 {
            return Err(ToolError::EditFailed(format!(
                "old_str appears {} times — must be unique for safe editing", count
            )));
        }

        let new_content = content.replacen(old_str, new_str, 1);
        tokio::fs::write(&resolved, &new_content).await
            .map_err(|e| ToolError::IO(e.to_string()))?;

        Ok(ToolResult {
            content: format!("Edited {}: replaced {} chars with {} chars",
                resolved.display(), old_str.len(), new_str.len()),
            is_error: false,
            metadata: None,
        })
    }

    async fn shell(&self, args: Value) -> Result<ToolResult, ToolError> {
        let command = args["command"].as_str()
            .ok_or(ToolError::MissingParam("command"))?;

        // Security: validate the command starts with an allowed binary
        let first_word = command.split_whitespace().next().unwrap_or("");
        if !self.allowed_commands.iter().any(|c| first_word == c.as_str()) {
            return Err(ToolError::AccessDenied(format!(
                "Command '{}' is not in the allowed list. Allowed: {:?}",
                first_word, self.allowed_commands
            )));
        }

        let output = Command::new("sh")
            .arg("-c")
            .arg(command)
            .current_dir(&self.root)
            .output()
            .await
            .map_err(|e| ToolError::IO(e.to_string()))?;

        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();

        // Truncate to avoid blowing up the context window
        let max_chars = 20_000;
        let truncated_stdout = if stdout.len() > max_chars {
            format!("{}...\n[truncated, {} total chars]",
                &stdout[..max_chars], stdout.len())
        } else {
            stdout
        };

        Ok(ToolResult {
            content: if stderr.is_empty() {
                truncated_stdout
            } else {
                format!("STDOUT:\n{}\nSTDERR:\n{}", truncated_stdout, stderr)
            },
            is_error: !output.status.success(),
            metadata: Some(serde_json::json!({
                "exit_code": output.status.code(),
            })),
        })
    }

    async fn grep(&self, args: Value) -> Result<ToolResult, ToolError> {
        let pattern = args["pattern"].as_str()
            .ok_or(ToolError::MissingParam("pattern"))?;
        let path = args["path"].as_str().unwrap_or(".");
        let resolved = self.resolve_path(path)?;

        // Use ripgrep (rg) for speed — it respects .gitignore automatically
        let output = Command::new("rg")
            .args(["--line-number", "--no-heading", "--color=never", "-e", pattern])
            .arg(&resolved)
            .output()
            .await
            .map_err(|e| ToolError::IO(e.to_string()))?;

        let results = String::from_utf8_lossy(&output.stdout).to_string();
        let line_count = results.lines().count();

        Ok(ToolResult {
            content: if results.is_empty() {
                format!("No matches for pattern '{pattern}'")
            } else if line_count > 200 {
                format!("{}\n... ({line_count} total matches, showing first 200)",
                    results.lines().take(200).collect::<Vec<_>>().join("\n"))
            } else {
                results
            },
            is_error: false,
            metadata: Some(serde_json::json!({ "match_count": line_count })),
        })
    }
}

#[async_trait]
impl Extension for DeveloperExtension {
    fn name(&self) -> &str { "developer" }

    fn description(&self) -> &str {
        "File system operations, shell commands, and code search"
    }

    fn instructions(&self) -> &str {
        "Use developer tools to read, write, and edit files. \
         Use edit_file for targeted changes (requires unique old_str). \
         Use shell for git, find, and other commands. \
         Use grep (ripgrep) for fast code search across the vault."
    }

    fn tools(&self) -> Vec<ToolDefinition> {
        vec![
            ToolDefinition {
                name: "read_file".into(),
                description: "Read the contents of a file with line numbers".into(),
                parameters: serde_json::json!({
                    "type": "object",
                    "required": ["path"],
                    "properties": {
                        "path": { "type": "string", "description": "File path relative to vault root" }
                    }
                }),
            },
            ToolDefinition {
                name: "write_file".into(),
                description: "Write content to a file (creates or overwrites)".into(),
                parameters: serde_json::json!({
                    "type": "object",
                    "required": ["path", "content"],
                    "properties": {
                        "path": { "type": "string" },
                        "content": { "type": "string" }
                    }
                }),
            },
            ToolDefinition {
                name: "edit_file".into(),
                description: "Replace a unique string in a file. old_str must appear exactly once.".into(),
                parameters: serde_json::json!({
                    "type": "object",
                    "required": ["path", "old_str", "new_str"],
                    "properties": {
                        "path": { "type": "string" },
                        "old_str": { "type": "string", "description": "Exact text to find (must be unique)" },
                        "new_str": { "type": "string", "description": "Replacement text" }
                    }
                }),
            },
            ToolDefinition {
                name: "shell".into(),
                description: "Execute a shell command. Only allowed commands: ls, cat, head, tail, wc, find, grep, rg, fd, git, diff, patch, mkdir, cp, mv".into(),
                parameters: serde_json::json!({
                    "type": "object",
                    "required": ["command"],
                    "properties": {
                        "command": { "type": "string" }
                    }
                }),
            },
            ToolDefinition {
                name: "grep".into(),
                description: "Search files using ripgrep (respects .gitignore)".into(),
                parameters: serde_json::json!({
                    "type": "object",
                    "required": ["pattern"],
                    "properties": {
                        "pattern": { "type": "string", "description": "Regex pattern" },
                        "path": { "type": "string", "description": "Directory or file to search (default: vault root)" }
                    }
                }),
            },
        ]
    }

    async fn call_tool(&self, name: &str, arguments: Value) -> Result<ToolResult, ToolError> {
        match name {
            "read_file" => self.read_file(arguments).await,
            "write_file" => self.write_file(arguments).await,
            "edit_file" => self.edit_file(arguments).await,
            "shell" => self.shell(arguments).await,
            "grep" => self.grep(arguments).await,
            _ => Err(ToolError::UnknownTool(name.to_string())),
        }
    }
}
```

---

## 6. The Agent Loop (with Parallel Tool Dispatch)

This is the heart of the system. Adapted from Goose's `reply_internal()` but with two critical improvements: parallel tool execution and proactive context compaction.

```rust
// agent_core/src/agent/loop.rs

use crate::providers::base::*;
use crate::extensions::*;
use futures::future::try_join_all;
use tiktoken_rs::CoreBPE;
use tokio_util::sync::CancellationToken;

pub struct AgentLoop {
    provider: Box<dyn Provider>,
    extensions: Vec<Box<dyn Extension>>,
    system_prompt: String,
    session: Session,
    tokenizer: CoreBPE,
    /// Compaction fires at this fraction of the context window
    compaction_threshold: f32,  // default 0.75
    cancel: CancellationToken,
}

impl AgentLoop {
    /// Run one turn of the agent loop.
    /// Takes a user message, returns the assistant's final response
    /// after all tool calls are resolved.
    pub async fn reply(
        &mut self,
        user_message: Message,
        stream_callback: &dyn TokenStreamCallback,
    ) -> Result<Message, AgentError> {
        self.session.messages.push(user_message);

        // Gather all available tools from all extensions
        let tools: Vec<Tool> = self.extensions.iter()
            .flat_map(|ext| {
                let prefix = ext.name();
                ext.tools().into_iter().map(move |t| Tool {
                    name: format!("{prefix}__{}", t.name),
                    description: t.description,
                    parameters: t.parameters,
                })
            })
            .collect();

        // Build system prompt with extension instructions
        let system = self.build_system_prompt();

        // ──── Main loop: generate → dispatch tools → repeat ────
        let mut iterations = 0;
        let max_iterations = 25;  // safety limit

        loop {
            iterations += 1;
            if iterations > max_iterations {
                return Err(AgentError::MaxIterations);
            }

            // ── Proactive context compaction ──
            // Check BEFORE calling the provider, not after a ContextLengthExceeded error.
            // This avoids wasting a failed API call.
            let estimated_tokens = self.estimate_tokens(&system, &self.session.messages, &tools);
            let window = self.provider.model_config().context_window;
            if estimated_tokens as f32 > window as f32 * self.compaction_threshold {
                self.compact_context(&system).await?;
            }

            // ── Stream from the provider ──
            let mut stream = self.provider.stream(
                self.provider.model_config(),
                &system,
                &self.session.messages,
                &tools,
                self.cancel.clone(),
            ).await?;

            // Collect the full response (streaming chunks to the callback as they arrive)
            let mut response_text = String::new();
            let mut tool_calls: Vec<ToolCall> = Vec::new();
            let mut usage = ProviderUsage::default();

            use futures::StreamExt;
            while let Some(chunk) = stream.next().await {
                if self.cancel.is_cancelled() {
                    return Err(AgentError::Cancelled);
                }

                match chunk? {
                    StreamChunk::Delta(delta) => match delta {
                        MessageDelta::Text(text) => {
                            response_text.push_str(&text);
                            stream_callback.on_token(text, None);
                        }
                        MessageDelta::ToolUse { id, name, arguments_json } => {
                            tool_calls.push(ToolCall { id, name, arguments_json: arguments_json.clone() });
                            stream_callback.on_token(
                                String::new(),
                                Some(serde_json::to_string(&serde_json::json!({
                                    "id": id, "name": name, "arguments": arguments_json
                                })).unwrap_or_default()),
                            );
                        }
                    },
                    StreamChunk::Usage(u) => usage = u,
                }
            }

            // Add the assistant's response to the session
            let assistant_msg = Message::assistant(response_text.clone(), tool_calls.clone());
            self.session.messages.push(assistant_msg.clone());

            // ── If no tool calls, we're done ──
            if tool_calls.is_empty() {
                stream_callback.on_complete(usage.into_ffi());
                self.session.persist().await?;
                return Ok(assistant_msg);
            }

            // ── Dispatch tool calls IN PARALLEL ──
            // This is the critical improvement over Goose's sequential dispatch.
            // Independent tool calls (e.g., reading 3 files) run concurrently.
            let tool_futures: Vec<_> = tool_calls.iter().map(|tc| {
                let extensions = &self.extensions;
                async move {
                    // Parse the namespaced tool name: "developer__read_file"
                    let (ext_name, tool_name) = tc.name.split_once("__")
                        .ok_or(AgentError::InvalidToolName(tc.name.clone()))?;

                    // Find the extension
                    let ext = extensions.iter()
                        .find(|e| e.name() == ext_name)
                        .ok_or(AgentError::ExtensionNotFound(ext_name.to_string()))?;

                    // Parse arguments
                    let args: serde_json::Value = serde_json::from_str(&tc.arguments_json)
                        .unwrap_or(serde_json::Value::Null);

                    // Execute the tool
                    let result = ext.call_tool(tool_name, args).await
                        .unwrap_or_else(|e| ToolResult {
                            content: format!("Error: {e}"),
                            is_error: true,
                            metadata: None,
                        });

                    Ok::<(String, ToolResult), AgentError>((tc.id.clone(), result))
                }
            }).collect();

            // Run all tool calls concurrently
            let results = try_join_all(tool_futures).await?;

            // Add tool results as a user message (the LLM convention)
            let tool_results: Vec<ToolResultMessage> = results.into_iter()
                .map(|(id, result)| ToolResultMessage {
                    tool_call_id: id,
                    content: result.content,
                    is_error: result.is_error,
                })
                .collect();

            self.session.messages.push(Message::tool_results(tool_results));

            // Loop continues — the model will see tool results and either
            // respond with text (done) or request more tool calls
        }
    }

    /// Proactive context compaction.
    /// Summarizes older messages while preserving recent context and tool results.
    async fn compact_context(&mut self, system: &str) -> Result<(), AgentError> {
        // Keep the last N messages intact (recent context is most valuable)
        let keep_recent = 6;  // 3 turns of user/assistant pairs
        let total = self.session.messages.len();

        if total <= keep_recent {
            return Ok(());  // nothing to compact
        }

        // Split messages into old (to summarize) and recent (to keep)
        let (old_messages, recent_messages) = self.session.messages.split_at(total - keep_recent);

        // Use the provider's fast model to summarize old messages
        let summary_prompt = format!(
            "Summarize the following conversation history concisely. \
             Preserve all key facts, decisions, file paths, code changes, \
             and tool results. Omit pleasantries and repetition.\n\n{}",
            old_messages.iter()
                .map(|m| format!("[{}]: {}", m.role, m.content_preview(200)))
                .collect::<Vec<_>>()
                .join("\n")
        );

        let (summary_msg, _) = self.provider.complete(
            self.provider.fast_model_config(),
            "You are a conversation summarizer. Be concise and factual.",
            &[Message::user(summary_prompt)],
            &[],  // no tools for summarization
        ).await?;

        // Replace old messages with a single summary message
        let mut new_messages = vec![
            Message::system(format!(
                "[Context summary of {} earlier messages]\n{}",
                old_messages.len(),
                summary_msg.text_content()
            ))
        ];
        new_messages.extend(recent_messages.to_vec());
        self.session.messages = new_messages;

        Ok(())
    }

    fn estimate_tokens(&self, system: &str, messages: &[Message], tools: &[Tool]) -> usize {
        // Rough estimate: 4 chars ≈ 1 token (conservative for English)
        // A precise count uses tiktoken but is slower
        let char_count = system.len()
            + messages.iter().map(|m| m.estimated_chars()).sum::<usize>()
            + tools.iter().map(|t| t.estimated_chars()).sum::<usize>();
        char_count / 4
    }

    fn build_system_prompt(&self) -> String {
        let mut prompt = self.system_prompt.clone();
        for ext in &self.extensions {
            let instructions = ext.instructions();
            if !instructions.is_empty() {
                prompt.push_str(&format!("\n\n## {} Tools\n{}", ext.name(), instructions));
            }
        }
        prompt
    }
}
```

---

## 7. Model Loading Strategy

### The 3-Tier Architecture

```
┌─────────────────────────────────────────────────────┐
│                    18GB M2 Pro                        │
│                                                       │
│  macOS + Epistemos App:  ~5GB                        │
│  ┌──────────────────────────────────────────────┐    │
│  │  Router (always pinned):  Qwen3.5 4B  3.4GB  │    │
│  └──────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────┐    │
│  │  Reasoner (cold-loaded): Qwen3.5 9B   5.5GB  │    │
│  └──────────────────────────────────────────────┘    │
│  KV Cache + headroom:  ~4GB                          │
│                                                       │
│  Cloud fallback: Anthropic / OpenAI / Google          │
│  (when local quality insufficient or user requests)   │
└─────────────────────────────────────────────────────┘
```

### Model Manager (Rust)

```rust
// agent_core/src/models/manager.rs

use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::RwLock;

/// Manages local model lifecycle: loading, eviction, tier selection.
pub struct ModelManager {
    /// Path to the model cache directory
    cache_dir: PathBuf,
    /// Currently loaded models
    loaded: Arc<RwLock<LoadedModels>>,
    /// MLX inference callback (bridges to Swift)
    mlx: Arc<dyn MLXInferenceCallback>,
    /// System memory info for intelligent loading decisions
    memory_budget_bytes: u64,
}

struct LoadedModels {
    router: Option<LoadedModel>,
    reasoner: Option<LoadedModel>,
}

struct LoadedModel {
    name: String,
    size_bytes: u64,
    provider: Arc<MetalProvider>,
}

/// The model registry — what's available and how to get it
pub struct ModelRegistry {
    pub models: Vec<ModelSpec>,
}

pub struct ModelSpec {
    pub name: String,
    pub tier: ModelTier,
    pub hf_repo: String,          // e.g., "mlx-community/Qwen3.5-4B-Instruct-4bit"
    pub size_bytes: u64,           // approximate disk/memory size
    pub context_window: u32,
    pub tool_calling: bool,
    pub thinking_mode: bool,
}

#[derive(Clone, Copy, PartialEq)]
pub enum ModelTier {
    Router,     // Always-hot, <3.5GB, fast intent classification + simple tool calls
    Reasoner,   // Cold-loaded on demand, 5-8GB, complex reasoning + coding
    Agent,      // Dual-duty: router for simple tasks, reasoner for complex agentic flows
    Cloud,      // Anthropic/OpenAI/Google via API
}

impl ModelManager {
    pub fn default_registry() -> ModelRegistry {
        ModelRegistry {
            models: vec![
                // ── Phase I defaults ──
                ModelSpec {
                    name: "qwen3.5-4b-router".into(),
                    tier: ModelTier::Router,
                    hf_repo: "mlx-community/Qwen3.5-4B-Instruct-4bit".into(),
                    size_bytes: 3_400_000_000,   // 3.4 GB
                    context_window: 32_768,
                    tool_calling: true,           // 97.5% accuracy
                    thinking_mode: false,
                },
                ModelSpec {
                    name: "qwen3.5-9b-reasoner".into(),
                    tier: ModelTier::Reasoner,
                    hf_repo: "mlx-community/Qwen3.5-9B-Instruct-4bit".into(),
                    size_bytes: 5_500_000_000,   // 5.5 GB
                    context_window: 32_768,
                    tool_calling: true,
                    thinking_mode: true,
                },
                // ── Gemma 4 upgrade path (when MLX tool-call parser is merged) ──
                ModelSpec {
                    name: "gemma4-e4b-multimodal".into(),
                    tier: ModelTier::Reasoner,
                    hf_repo: "mlx-community/gemma-4-e4b-it-4bit".into(),
                    size_bytes: 3_000_000_000,   // 3 GB
                    context_window: 128_000,      // 128K context!
                    tool_calling: false,           // NOT YET — waiting on parser
                    thinking_mode: true,
                },
            ],
        }
    }

    /// Intelligent routing: decide which model handles a given request.
    /// This is where the 3-tier architecture comes alive.
    pub async fn select_provider(
        &self,
        intent: &RequestIntent,
    ) -> Arc<dyn Provider> {
        match intent.complexity {
            // Simple queries: router handles directly (always loaded, fast)
            Complexity::Simple => {
                self.ensure_router_loaded().await;
                self.loaded.read().await.router.as_ref().unwrap().provider.clone()
            }
            // Complex reasoning, coding, multi-step: load reasoner
            Complexity::Complex => {
                self.ensure_reasoner_loaded().await;
                self.loaded.read().await.reasoner.as_ref().unwrap().provider.clone()
            }
            // Beyond local capability: fall back to cloud
            Complexity::CloudRequired => {
                // Return the configured cloud provider (Anthropic/OpenAI)
                // This is wired up during AgentHandle initialization
                todo!("Return cloud provider")
            }
        }
    }

    async fn ensure_router_loaded(&self) {
        let loaded = self.loaded.read().await;
        if loaded.router.is_some() { return; }
        drop(loaded);
        // Load router model — this takes ~1s from SSD
        // Implementation calls into MLX via the mlx callback
    }

    async fn ensure_reasoner_loaded(&self) {
        let loaded = self.loaded.read().await;
        if loaded.reasoner.is_some() { return; }
        drop(loaded);

        // Check memory pressure before loading
        let available = self.available_memory_bytes();
        let spec = &Self::default_registry().models[1]; // qwen3.5-9b
        if available < spec.size_bytes + 1_000_000_000 {
            // Not enough memory — this is the 18GB constraint biting.
            // Option 1: Evict router temporarily (exclusive mode)
            // Option 2: Fall back to cloud
            // For now, fall back to cloud
            tracing::warn!(
                "Insufficient memory for reasoner ({} available, {} needed). Using cloud.",
                available, spec.size_bytes
            );
            return;
        }
        // Load reasoner model
    }

    fn available_memory_bytes(&self) -> u64 {
        // On macOS, use host_statistics64 to get free + inactive pages
        // This gives real available memory, not just what Activity Monitor shows
        #[cfg(target_os = "macos")]
        {
            use mach2::mach_host::*;
            // ... platform-specific memory query
            // Simplified: return budget minus loaded models
            let loaded = self.loaded.blocking_read();
            let used: u64 = loaded.router.as_ref().map(|m| m.size_bytes).unwrap_or(0)
                + loaded.reasoner.as_ref().map(|m| m.size_bytes).unwrap_or(0);
            self.memory_budget_bytes.saturating_sub(used)
        }
    }
}
```

---

## 8. GEPA-Inspired Self-Evolution for the Living Vault

Port the core algorithm, not the Python. The pattern is language-agnostic: trace → diagnose → mutate → evaluate → gate → commit.

```rust
// agent_core/src/evolution/mod.rs
// Trace-based reflective self-improvement for the Living Vault

use crate::providers::base::Provider;

/// A single execution trace from an agent session.
/// This is the raw material for self-improvement.
pub struct ExecutionTrace {
    pub session_id: String,
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub messages: Vec<Message>,
    pub tool_calls: Vec<TracedToolCall>,
    pub outcome: SessionOutcome,
}

pub struct TracedToolCall {
    pub tool_name: String,
    pub arguments: serde_json::Value,
    pub result: String,
    pub latency_ms: u64,
    pub success: bool,
}

pub enum SessionOutcome {
    /// User explicitly accepted/liked the result
    Success { user_feedback: Option<String> },
    /// User retried, rephrased, or expressed frustration
    Failure { retry_count: u32, error_messages: Vec<String> },
    /// Session ended without clear signal
    Ambiguous,
}

/// The self-evolution engine. Runs during the nightly self-improvement loop.
pub struct EvolutionEngine {
    /// Cloud provider for LLM-based diagnosis and mutation
    provider: Box<dyn Provider>,
    /// The vault's memory classification rules (ADD/UPDATE/DELETE/NOOP)
    memory_rules: Vec<MemoryRule>,
    /// The constraint gates every mutation must pass
    gates: Vec<Box<dyn ConstraintGate>>,
}

impl EvolutionEngine {
    /// Run one evolution cycle. This is the GEPA core loop,
    /// adapted for Epistemos's Living Vault.
    ///
    /// Cost: ~$2-10 per run via cloud API calls. No GPU training.
    pub async fn evolve(&mut self, traces: Vec<ExecutionTrace>) -> Result<Vec<Mutation>, EvolutionError> {
        // ── Step 1: Diagnose failures ──
        // Feed failed traces to the LLM and ask it to identify root causes.
        let failed_traces: Vec<_> = traces.iter()
            .filter(|t| matches!(t.outcome, SessionOutcome::Failure { .. }))
            .collect();

        if failed_traces.is_empty() {
            return Ok(vec![]);  // nothing to improve
        }

        let diagnosis_prompt = format!(
            "Analyze these failed agent sessions and identify the root cause of each failure. \
             Focus on: incorrect tool selection, poor argument formatting, missing context, \
             wrong reasoning strategy, or inadequate system prompt instructions.\n\n{}",
            failed_traces.iter().enumerate()
                .map(|(i, t)| format!("### Failure {}\n{}", i + 1, t.summarize()))
                .collect::<Vec<_>>()
                .join("\n\n")
        );

        let (diagnosis, _) = self.provider.complete(
            self.provider.model_config(),
            "You are an agent debugging expert. Be specific and actionable.",
            &[Message::user(diagnosis_prompt)],
            &[],
        ).await?;

        // ── Step 2: Generate targeted mutations ──
        // For each diagnosed failure, propose a specific change to:
        // - System prompt instructions
        // - Tool descriptions
        // - Memory classification rules
        // - Retrieval prompt templates
        let mutation_prompt = format!(
            "Based on this diagnosis, propose specific, minimal changes that would \
             prevent these failures. Each change should be a single, testable modification.\n\n\
             Diagnosis:\n{}\n\n\
             Current memory rules:\n{}\n\n\
             Output as JSON array of mutations.",
            diagnosis.text_content(),
            serde_json::to_string_pretty(&self.memory_rules).unwrap_or_default()
        );

        let (mutations_msg, _) = self.provider.complete(
            self.provider.model_config(),
            "You are a system prompt optimizer. Output valid JSON only.",
            &[Message::user(mutation_prompt)],
            &[],
        ).await?;

        let candidate_mutations: Vec<Mutation> = serde_json::from_str(
            &mutations_msg.text_content()
        ).map_err(|e| EvolutionError::ParseFailed(e.to_string()))?;

        // ── Step 3: Constraint gates ──
        // Every mutation must pass ALL gates before it's committed.
        // This is the safety mechanism that prevents the agent from
        // breaking itself during autonomous evolution.
        let mut approved_mutations = Vec::new();

        for mutation in candidate_mutations {
            let mut passed = true;

            for gate in &self.gates {
                if !gate.check(&mutation).await? {
                    tracing::info!(
                        "Mutation rejected by gate '{}': {:?}",
                        gate.name(), mutation
                    );
                    passed = false;
                    break;
                }
            }

            if passed {
                approved_mutations.push(mutation);
            }
        }

        Ok(approved_mutations)
    }
}

/// A constraint gate that mutations must pass.
/// Modeled after Hermes Self-Evolution's five-gate system.
#[async_trait]
pub trait ConstraintGate: Send + Sync {
    fn name(&self) -> &str;
    async fn check(&self, mutation: &Mutation) -> Result<bool, EvolutionError>;
}

/// Gate 1: Size limit — mutations can't bloat prompts beyond a threshold
pub struct SizeGate { max_bytes: usize }
#[async_trait]
impl ConstraintGate for SizeGate {
    fn name(&self) -> &str { "size_limit" }
    async fn check(&self, mutation: &Mutation) -> Result<bool, EvolutionError> {
        Ok(mutation.content.len() <= self.max_bytes)
    }
}

/// Gate 2: Semantic preservation — the mutation must not change the core intent
pub struct SemanticGate { provider: Arc<dyn Provider> }
#[async_trait]
impl ConstraintGate for SemanticGate {
    fn name(&self) -> &str { "semantic_preservation" }
    async fn check(&self, mutation: &Mutation) -> Result<bool, EvolutionError> {
        // Ask the LLM if the mutation preserves the original semantic intent
        let (response, _) = self.provider.complete(
            self.provider.model_config(),
            "You are a semantic similarity judge. Answer YES or NO only.",
            &[Message::user(format!(
                "Does this change preserve the original intent?\n\nOriginal:\n{}\n\nModified:\n{}",
                mutation.original, mutation.content
            ))],
            &[],
        ).await?;
        Ok(response.text_content().trim().to_uppercase().starts_with("YES"))
    }
}

/// Gate 3: Regression test — replay successful traces with the mutation applied
pub struct RegressionGate { test_traces: Vec<ExecutionTrace> }

/// Gate 4: Diff size limit — mutations should be surgical, not rewrites
pub struct DiffSizeGate { max_changed_lines: usize }

/// Gate 5: Human review flag — mutations above a severity threshold
/// get flagged for morning review instead of auto-committed
pub struct HumanReviewGate { severity_threshold: f32 }

#[derive(Debug, serde::Serialize, serde::Deserialize)]
pub struct Mutation {
    pub target: MutationTarget,
    pub original: String,
    pub content: String,
    pub rationale: String,
    pub severity: f32,  // 0.0 (cosmetic) to 1.0 (architectural)
}

#[derive(Debug, serde::Serialize, serde::Deserialize)]
pub enum MutationTarget {
    SystemPrompt,
    ToolDescription { tool_name: String },
    MemoryRule { rule_id: String },
    RetrievalPrompt,
}
```

---

## 9. Cargo Workspace Layout

```
epistemos/
├── Cargo.toml                    # Workspace root
├── crates/
│   ├── agent_core/               # The main crate — 8-12MB target
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── bridge/           # UniFFI boundary
│   │       │   ├── mod.rs
│   │       │   └── stream.rs     # Section 1 code
│   │       ├── providers/        # Goose-derived
│   │       │   ├── mod.rs
│   │       │   ├── base.rs       # Provider trait (Section 2)
│   │       │   ├── anthropic.rs  # Cloud provider
│   │       │   ├── openai.rs     # Cloud provider
│   │       │   ├── google.rs     # Cloud provider
│   │       │   ├── metal.rs      # Local MLX (Section 3)
│   │       │   ├── tool_parser.rs # Section 4
│   │       │   └── errors.rs
│   │       ├── extensions/       # Builtin tools (Section 5)
│   │       │   ├── mod.rs
│   │       │   ├── developer.rs  # File ops, shell, grep
│   │       │   ├── memory.rs     # Vault search (sqlite-vec + tantivy)
│   │       │   └── macos.rs      # AXUIElement, ScreenCaptureKit
│   │       ├── agent/            # The loop (Section 6)
│   │       │   ├── mod.rs
│   │       │   ├── loop.rs
│   │       │   └── session.rs    # Session persistence (SQLite)
│   │       ├── models/           # Model management (Section 7)
│   │       │   ├── mod.rs
│   │       │   └── manager.rs
│   │       └── evolution/        # GEPA self-improvement (Section 8)
│   │           ├── mod.rs
│   │           └── gates.rs
│   └── agent_core_ffi/          # Thin UniFFI wrapper crate
│       ├── Cargo.toml
│       └── src/
│           └── lib.rs            # #[uniffi::export] re-exports
```

---

## 10. Sprint Plan

| Week | Deliverable | Validation |
|------|-------------|------------|
| **1** | UniFFI streaming bridge (mock provider → Swift `AsyncStream` → SwiftUI) | Tokens appear word-by-word in a test SwiftUI view |
| **2** | Anthropic + OpenAI providers (Goose-derived) streaming through the bridge | Cloud models work end-to-end in the app |
| **3** | MetalProvider + Qwen3.5 4B router loaded via MLX-Swift | Local model streams tokens through the same bridge |
| **4** | Builtin Developer extension (file ops, shell, grep) + agent loop with parallel dispatch | Agent can read/write/edit files and run shell commands |
| **5** | Session persistence (SQLite) + context compaction + model manager (router/reasoner switching) | Long conversations compact gracefully; 9B loads on demand |
| **6** | Kill Python subprocess. Wire all existing Epistemos tools as builtin extensions. Benchmark. | `ps aux | grep python` returns nothing while agent works |

### Post-Phase I Backlog (Don't Touch Until Week 6 Is Done)

- GEPA self-evolution integration (nightly loop)
- Gemma 4 E4B as router when MLX tool-call parser ships
- SciAgent-style scientific skills as MCP extensions
- Adversary mode (parallel reviewer LLM for security)
- TurboQuant KV cache compression for long context
- Qwopus 27B exclusive mode (evict router, load 27B)

---

## Appendix A: Key Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Provider trait source | Goose (vendored, not dependency) | Avoid pulling lancedb, v8, tera; own the code |
| MCP SDK | `rmcp` 0.9.1 (Cargo dependency) | Official Rust MCP SDK, lightweight, actively maintained |
| TLS | `reqwest` with `native-tls` (Apple SecureTransport) | Saves ~1MB vs rustls; uses hardware TLS on Apple Silicon |
| Token counting | `tiktoken-rs` | Accurate BPE counting for context window tracking |
| Router model | Qwen3.5 4B 4-bit MLX | 97.5% tool-calling accuracy, 55-65 tok/s, 3.4GB |
| Reasoner model | Qwen3.5 9B 4-bit MLX | Best quality at 5.5GB; cold-loads in ~1.5s from SSD |
| Quantization format | MLX native safetensors ONLY | GGUF K-quants cast to FP16 on MLX — no acceleration |
| Parallel tool dispatch | `futures::try_join_all` | Critical latency improvement for multi-tool calls |
| Context compaction | Proactive (estimate before call) | Avoids wasted API calls from ContextLengthExceeded |
| Session storage | SQLite (shared with GRDB) | Single DB for app + agent; no JSONL files |
| Cancellation | `tokio::CancellationToken` | Clean integration with Swift structured concurrency |

## Appendix B: Binary Size Budget

| Component | Estimated Size |
|-----------|---------------|
| `tokio` (runtime) | 2.0 MB |
| `reqwest` + native-tls | 1.5 MB |
| `rmcp` (MCP SDK) | 0.8 MB |
| `serde` + `serde_json` | 0.5 MB |
| Provider implementations (3 cloud + 1 local) | 1.0 MB |
| Extension implementations (developer, memory, macos) | 0.5 MB |
| Agent loop + session + evolution | 0.5 MB |
| UniFFI generated bindings | 0.3 MB |
| `tiktoken-rs` | 0.4 MB |
| Misc (tracing, thiserror, etc.) | 0.5 MB |
| **Total (stripped release + LTO)** | **~8 MB** |

Target met: 8MB < 12MB budget.

---

*This document is the build plan. The research phase is complete. Ship it.*
