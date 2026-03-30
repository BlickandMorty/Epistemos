# Epistemos — Project Rules

## Architecture
- Swift 6.0 + Rust (UniFFI FFI) + Metal compute shaders
- GRDB for persistence, MLX-Swift for local inference
- Omega agent system being replaced by Epistemos Omega: Rust living loop + Hermes subprocess + MCP peer bridge
- 137K lines Swift, 94K lines Rust, 370 Swift files, 99 Rust files, 115 test files
- Rust agent_core crate owns: agentic loop, HTTP streaming, tool execution, session persistence, memory search, security, prompt caching, context compaction
- Swift owns: UI rendering, MLX inference, macOS APIs (AXUIElement via AXorcist, ScreenCaptureKit, CGEvent), permission gate UI, MCP server hosting
- Python hermes-agent subprocess owns: cloud API orchestration, skills system, procedural memory, multi-step planning

## NON-NEGOTIABLE CONSTRAINTS
- NO SIDECAR for INFERENCE. All inference in-process via Rust FFI or MLX-Swift. ONLY exception: oMLX bridge for oversized models. Hermes subprocess is for ORCHESTRATION, not inference.
- REAL APIs ONLY. Every cloud endpoint verified against provider docs. No fake features.
- HONEST CAPABILITY GATING. Local models get fast/thinking/research. Cloud models get agent/liveAgent. Never fake agent capability for local models.
- Zero test regressions against the 2,679-test suite.
- PRESERVE THINKING BLOCKS. When stop_reason is "tool_use", pass the ENTIRE content array back including thinking blocks + signatures. Dropping them kills the agent.
- STREAM EVERYTHING. Forward every token to the delegate immediately. No buffering.
- AGENT DECIDES TERMINATION. max_turns is a safety rail, not a schedule. Trust stop_reason == "end_turn".
- API keys in macOS Keychain (SecItemAdd/SecItemCopyMatching), NEVER UserDefaults.

## Code Standards
- Use @Observable, not ObservableObject
- Use Swift Testing (@Test, #expect) for new tests
- All inference on background actors — never block @MainActor
- Every unsafe block gets // SAFETY: comment
- No try!, no force-unwraps, no print() in production paths
- DispatchQueue.main.async in UniFFI callbacks, NEVER .sync (deadlock)

## Build & Test
- Build: xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
- Rust: cargo test --manifest-path agent_core/Cargo.toml
- Test: swift test
- Lint: swiftlint

## DO NOT
- Edit .xcodeproj directly — use xcodegen
- Commit model files (.gguf, .safetensors, .mlx)
- Import SDKs that don't exist (Anthropic has NO Swift SDK, OpenAI has NO Swift SDK)
- Use Ollama, llama-server, or any subprocess for INFERENCE (Hermes subprocess for orchestration is OK)
- Mark items done in PROGRESS.md until verification greps pass
- Buffer streaming responses — forward every token immediately
- Strip thinking blocks from message history
- Use Debug format ({:?}) for JSON serialization
- Use AsyncStream with .unbounded buffering — use .bufferingNewest(256)

## Swift SDK Reality (DO NOT HALLUCINATE)
- Anthropic: NO Swift SDK → raw URLSession
- OpenAI: NO Swift SDK → raw URLSession or community MacPaw/OpenAI
- Apple MLX: YES → mlx-swift, mlx-swift-lm
- MCP: YES → modelcontextprotocol/swift-sdk (v0.10.2, Swift 6.0+, macOS 14+)
- AXorcist: YES → steipete/AXorcist (fuzzy AX queries, MIT)
- Swift Subprocess: YES → swiftlang/swift-subprocess (Swift 6.1+)

## Provider Matrix (verified March 2026)
- Claude Opus 4.6/Sonnet 4.6: api.anthropic.com/v1/messages, thinking: adaptive, tools ✅, MCP ✅
- Claude Haiku 4.5: same endpoint, thinking: disabled, tools ✅, computer use ❌
- Perplexity Sonar Pro: api.perplexity.ai/chat/completions, no tools
- Local Qwen3.5/Hermes-3: in-process MLX, grammar-constrained tools

## Detailed Docs (READ these, don't guess)
- Current sprint: docs/sprint-sessions/sprint-omega-1-foundation.md
- Agent progress: docs/AGENT_PROGRESS.md
- Agent architecture: docs/agent-system/AGENT_ARCHITECTURE.md
- Hermes research: docs/HERMES_INTEGRATION_RESEARCH.md
- Full build spec: docs/EPISTEMOS_FUSED_v3.md
- Deep analysis: docs/epistemos-deep-analysis.md

## FILE MAP — Agent System
### Rust agent_core crate
- Loop: agent_core/src/agent_loop.rs
- Bridge: agent_core/src/bridge.rs
- Claude SSE: agent_core/src/providers/claude.rs
- Perplexity: agent_core/src/providers/perplexity.rs
- Tools: agent_core/src/tools/registry.rs
- Think tool: agent_core/src/tools/think.rs
- Security: agent_core/src/security.rs
- Prompt caching: agent_core/src/prompt_caching.rs
- Compaction: agent_core/src/compaction.rs
- Vault: agent_core/src/storage/vault.rs
- Routing: agent_core/src/routing.rs
- Session: agent_core/src/session.rs

### Rust omega-mcp crate
- Dispatcher: omega-mcp/src/dispatcher.rs
- Catalog: omega-mcp/src/catalog.rs
- Vault ops: omega-mcp/src/vault.rs

### Swift Agent Bridge
- Streaming delegate: Epistemos/Bridge/StreamingDelegate.swift
- Agent ViewModel: Epistemos/ViewModels/AgentViewModel.swift
- MCP Bridge: Epistemos/Omega/MCPBridge.swift

### Swift Local Agent
- Hermes prompt: Epistemos/LocalAgent/HermesPromptBuilder.swift
- Grammar DSL: Epistemos/LocalAgent/LocalToolGrammar.swift
- Local loop: Epistemos/LocalAgent/LocalAgentLoop.swift
- Router: Epistemos/LocalAgent/ConfidenceRouter.swift

### Swift Computer Use
- Device agent: Epistemos/Omega/Inference/DeviceAgentService.swift
- Visual verify: Epistemos/Omega/Vision/VisualVerifyLoop.swift
- Screen capture: Epistemos/Omega/Vision/ScreenCaptureService.swift
- AX fusion: Epistemos/Omega/Vision/Screen2AXFusion.swift

### App Bootstrap
- Bootstrap: Epistemos/App/AppBootstrap.swift

## Session Startup Protocol
1. Read docs/AGENT_PROGRESS.md to see what's done and what's next
2. Read the current sprint file from docs/sprint-sessions/
3. After completing each task, run its verification command before moving to the next
4. After completing all sprint tasks, update docs/AGENT_PROGRESS.md with ✅ and today's date
