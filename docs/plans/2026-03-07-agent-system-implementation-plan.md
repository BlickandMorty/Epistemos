# Epistemos Agent System — Implementation Plan

**Date:** 2026-03-07
**Design Doc:** `docs/plans/2026-03-07-agent-system-design.md`
**Research Paper:** `~/agent document.md`
**Status:** Ready for execution

---

## How to Use This Plan

Each phase has numbered tasks. Each task specifies:
- **Files** to create or modify (exact paths)
- **Pattern** — what to build, referencing design doc sections and reference repos
- **Depends on** — which prior tasks must be complete
- **Verification** — how to confirm the task is done
- **Reference** — source repo files to study before implementing

Execute tasks in order within each phase. Phases are sequential (Phase N depends on Phase N-1). Within a phase, tasks without mutual dependencies can be parallelized.

**Critical rules:**
- Follow existing Epistemos patterns: `@MainActor @Observable`, Swift Testing, `withAppEnvironment(bootstrap)`, no XCTest, no ObservableObject
- Rust FFI: `#[repr(C)]`, `// SAFETY:` on every unsafe block, `with_capacity()` in hot paths
- All new state objects register in `AppBootstrap` and `AppEnvironment`
- All new SwiftData models register in `ModelContainer` schema
- Run `xcodebuild test` + `cargo test` after every task

---

## Phase Dependency Graph

```
Phase 1: MLX Foundation
    ↓
Phase 2: Agent Engine Core
    ↓
Phase 3: Memory System ←──────────────────┐
    ↓                                      │
Phase 4: Librarian Agent                   │
    ↓                                      │
Phase 5: Writer Agent                      │
    ↓                                      │
Phase 6: Builder Agent ────────────────────┘
    ↓
Phase 7: Learning Pool
    ↓
Phase 8: Graph NPCs
    ↓
Phase 9: Voice System
    ↓
Phase 10: Polish & Distribution
```

---

## Phase 1: MLX Foundation

**Goal:** Add MLX inference to Epistemos. Load Qwen 3.5 models locally on Apple Silicon and generate text through the existing `LLMClientProtocol`.

**Design doc reference:** Section 4 (Model Provider Layer)
**Research paper reference:** "Optimization for Inference and Low-Latency Execution", "Local vs. Cloud Hybrid Architectures"

### Task 1.1: Add MLX SPM Dependencies

**Files to modify:**
- `Epistemos.xcodeproj` (or `Package.swift` if SPM-based)

**What:**
Add two packages:
```
mlx-swift-lm    https://github.com/ml-explore/mlx-swift-lm    branch: main
swift-transformers    https://github.com/huggingface/swift-transformers    from: 1.1.9
```

Link products to Epistemos target:
- `MLXLMCommon`
- `MLXLLM`
- `MLXVLM` (optional, for future vision)
- `Tokenizers`

**Verification:** `xcodebuild build` succeeds with new dependencies resolved.

**Reference:** `mlxchat-main/project.yml` (lines 30-45)

---

### Task 1.2: Create MLXEngine Actor

**Files to create:**
- `Epistemos/Engine/MLXEngine.swift`

**What:**
Port the `MLXEngine` actor from MLXChat. This is the core GPU-isolated inference engine.

**Public API (must match these signatures):**

```swift
actor MLXEngine {
    init(memoryLimitGB: Int = 5)

    func loadModel(
        id: String,
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> Double

    func generateChat(
        messages: [Chat.Message],
        maxTokens: Int = 500,
        temperature: Float = 0.6,
        topP: Float = 0.95,
        repetitionPenalty: Float? = nil,
        enableThinking: Bool? = nil,
        tools: [ToolSpec]? = nil,
        toolDispatch: (@Sendable (String, [String: String]) async -> (name: String, result: String))? = nil,
        onChunk: (@MainActor @Sendable (String) -> Void)? = nil
    ) async throws -> GenerationResult

    func clearCache()
    func unloadModel()
}
```

**Key internals to port:**
1. Model loading via `MLXLMCommon.ModelContext` — download from HuggingFace Hub, configure tokenizer
2. GPU memory management — `GPU.set(memoryLimit:)`, baseline/peak tracking
3. Streaming generation — `MLXLMCommon.generateTask()` async iteration, token-by-token `onChunk`
4. Tool call parsing — Qwen 3.5 XML format (`<tool_call><function=name><parameter=key>value</parameter></function></tool_call>`)
5. Multi-turn tool loop — max 5 iterations: generate → parse tool → dispatch → append result → regenerate
6. Repetition detection — `hasRepetition()`, `trimRepetition()`, `hasRepeatedLine()`, `trimRepeatedLines()`
7. Think tag stripping — `stripThinkingTags()` removes `<think>...</think>` pairs
8. Chat template patching — `correctedChatTemplateIfNeeded()` for Qwen 3.5 4B Jinja bug

**Adaptation from MLXChat:**
- Remove iOS-specific UIImage handling (Epistemos is macOS)
- Remove VLM fallback logic (not needed in Phase 1)
- Keep `onToolCall` and `onToolResult` callbacks but make optional (agents will use them later)

**Reference:** `mlxchat-main/MLXChat/Engine/MLXEngine.swift` (603 lines — port entire file with adaptations)

**Verification:** Unit test that loads Qwen 3.5 0.8B Q4 and generates a response to "What is 2+2?".

---

### Task 1.3: Create MLXModelRegistry

**Files to create:**
- `Epistemos/Engine/MLXModelRegistry.swift`

**What:**
Port `ModelSpec` and `ModelRegistry` from MLXChat. Registry of all supported Qwen 3.5 MLX model variants.

```swift
struct MLXModelSpec: Identifiable, Sendable, Codable {
    let id: String           // e.g. "qwen3.5-0.8b-q4"
    let hfId: String         // HuggingFace repo: "mlx-community/Qwen3.5-0.8B-MLX-4bit"
    let displayName: String
    let family: String       // "0.8B", "2B", "4B", "9B"
    let quantization: String // "Q3", "Q4", "Q8", "BF16"
    let sizeGB: Double
}

enum MLXModelRegistry {
    static let models: [MLXModelSpec]
    static func modelsForMemory(availableGB: Double) -> [MLXModelSpec]
    static func find(id: String) -> MLXModelSpec?
}
```

**Models to include:**

| ID | HF Repo | Family | Quant | Size |
|---|---|---|---|---|
| qwen3.5-0.8b-q4 | mlx-community/Qwen3.5-0.8B-MLX-4bit | 0.8B | Q4 | 0.7 |
| qwen3.5-0.8b-q8 | mlx-community/Qwen3.5-0.8B-MLX-8bit | 0.8B | Q8 | 1.1 |
| qwen3.5-2b-q4 | mlx-community/Qwen3.5-2B-MLX-4bit | 2B | Q4 | 1.8 |
| qwen3.5-2b-q8 | mlx-community/Qwen3.5-2B-MLX-8bit | 2B | Q8 | 2.8 |
| qwen3.5-4b-q4 | mlx-community/Qwen3.5-4B-MLX-4bit | 4B | Q4 | 2.8 |
| qwen3.5-4b-q8 | mlx-community/Qwen3.5-4B-MLX-8bit | 4B | Q8 | 5.6 |
| qwen3.5-9b-q4 | mlx-community/Qwen3.5-9B-MLX-4bit | 9B | Q4 | 5.6 |

**Reference:** `mlxchat-main/MLXChat/Models/ModelRegistry.swift` (116 lines)

**Verification:** Unit test that `MLXModelRegistry.modelsForMemory(4.0)` returns models ≤ 4GB.

---

### Task 1.4: Create MLXClient (LLMClientProtocol conformance)

**Files to create:**
- `Epistemos/Engine/MLXClient.swift`

**What:**
Bridge between Epistemos's existing `LLMClientProtocol` and the new `MLXEngine`.

```swift
@MainActor
final class MLXClient: LLMClientProtocol {
    private let engine: MLXEngine
    private var loadedModelId: String?

    init(memoryLimitGB: Int = 5)

    // Load a specific model (swaps if different model already loaded)
    func loadModel(_ spec: MLXModelSpec, progress: (@Sendable (Progress) -> Void)? = nil) async throws
    func unloadModel()

    // LLMClientProtocol conformance
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String
    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error>
    func testConnection() async -> ConnectionTestResult
    func configSnapshot() -> LLMSnapshot
    func enrichmentSnapshot() -> LLMSnapshot
}
```

**Key behavior:**
- `generate()` builds `[Chat.Message]` from prompt + systemPrompt, calls `engine.generateChat()`, returns `cleanedOutput`
- `stream()` wraps `engine.generateChat(onChunk:)` in an `AsyncThrowingStream`
- `testConnection()` returns `.success` if a model is loaded, `.failure` otherwise
- Model swapping: if `loadModel` called with different ID, calls `engine.unloadModel()` then `engine.loadModel()`
- Nonisolated snapshot methods return pre-built `LLMSnapshot` with provider="MLX"

**Integration with existing LLMService:**
- Add `MLXClient` as new case in `LLMService` provider enum
- Do NOT replace existing providers — MLX is additive

**Files to modify:**
- `Epistemos/Engine/LLMService.swift` — add `.mlx` case to provider enum, initialize `MLXClient` in `init`

**Reference:** Existing provider pattern in `LLMService.swift` (Anthropic, OpenAI, etc.)

**Verification:**
1. Unit test: `MLXClient` conforms to `LLMClientProtocol`, `generate()` returns non-empty string
2. Integration test: `LLMService` with `.mlx` provider streams a response

---

### Task 1.5: Create MLXModelManager (download + cache management)

**Files to create:**
- `Epistemos/Engine/MLXModelManager.swift`

**What:**
Manages model downloads, disk cache, and memory budget.

```swift
@MainActor @Observable
final class MLXModelManager {
    var downloadProgress: Double = 0
    var isDownloading = false
    var cachedModels: [MLXModelSpec] = []
    var loadedModel: MLXModelSpec?
    var availableMemoryGB: Double { /* ProcessInfo.processInfo.physicalMemory based */ }

    func download(_ spec: MLXModelSpec) async throws
    func deleteCache(for spec: MLXModelSpec) throws
    func scanCachedModels()
    var totalCacheSizeGB: Double { get }
}
```

**Behavior:**
- Models download to `~/Library/Caches/Epistemos/MLXModels/` (or HuggingFace Hub default cache)
- `scanCachedModels()` checks which HF repos are already on disk
- Download progress reported via `downloadProgress` (0.0–1.0)
- `availableMemoryGB` uses `ProcessInfo.processInfo.physicalMemory` and `os_proc_available_memory()`

**Reference:** `mlxchat-main/MLXChat/ViewModels/SettingsManager.swift` (lines 100-180, cache scanning)

**Verification:** Unit test: download mock model spec, verify cache directory created.

---

### Task 1.6: Register MLX in AppBootstrap

**Files to modify:**
- `Epistemos/App/AppBootstrap.swift` — add `mlxClient: MLXClient` and `mlxModelManager: MLXModelManager`
- `Epistemos/App/AppEnvironment.swift` — add environment keys for both

**What:**
Wire MLX into the dependency graph. Initialize `MLXClient` in `AppBootstrap.init()`. Auto-load triage model (0.8B Q4) on app launch if cached.

```swift
// In AppBootstrap.init():
let mlxClient = MLXClient(memoryLimitGB: 5)
let mlxModelManager = MLXModelManager()

// In AppBootstrap.setup() (called after init):
Task {
    mlxModelManager.scanCachedModels()
    if let triageModel = MLXModelRegistry.find(id: "qwen3.5-0.8b-q4"),
       mlxModelManager.cachedModels.contains(where: { $0.id == triageModel.id }) {
        try? await mlxClient.loadModel(triageModel)
    }
}
```

**Verification:** App launches, triage model loads in background (check Console.app logs).

---

### Task 1.7: MLX Settings UI

**Files to create:**
- `Epistemos/Views/Settings/MLXSettingsView.swift`

**Files to modify:**
- Existing settings view (add MLX section)

**What:**
Settings panel for MLX model management:
- List of available models with download/delete buttons
- Download progress bar
- GPU memory limit slider
- Currently loaded model indicator
- Cache size display

Keep it minimal — just functional controls, no elaborate design.

**Verification:** Can download Qwen 3.5 0.8B Q4 from settings, see it appear as cached, load it.

---

### Task 1.8: Phase 1 Tests

**Files to create:**
- `EpistemosTests/MLXEngineTests.swift`
- `EpistemosTests/MLXClientTests.swift`
- `EpistemosTests/MLXModelRegistryTests.swift`

**What:**
```swift
@Suite("MLX Engine")
struct MLXEngineTests {
    @Test func modelRegistryReturnsModelsForMemory()
    @Test func modelRegistryFindsById()
    @Test func clientConformsToProtocol()
    @Test func clientReturnsFailureWhenNoModel()
    // Integration tests (require model download, mark as .disabled or conditional):
    @Test(.disabled("Requires model download"))
    func engineLoadsAndGenerates()
}
```

**Verification:** `xcodebuild test` passes with new test suite.

---

## Phase 2: Agent Engine Core

**Goal:** Build the agent orchestration infrastructure — the message bus, agent protocol, agent engine lifecycle manager, triage classifier, and agent panel UI.

**Design doc reference:** Sections 5 (The Four Agents — Triage), 6 (Agent Communication)
**Research paper reference:** "Theoretical Framework of Agentic Orchestration", "The ReAct Paradigm"

### Task 2.1: Define Agent Protocol and Types

**Files to create:**
- `Epistemos/Agents/AgentTypes.swift`

**What:**
Core types for the agent system.

```swift
// Agent identity
enum AgentID: String, Sendable, Codable, CaseIterable {
    case triage
    case librarian
    case writer
    case builder
}

// Agent lifecycle
enum AgentStatus: Sendable {
    case idle
    case thinking
    case working(task: String)
    case waitingForApproval(action: String)
    case error(String)
}

// Trust levels (mirrors Rust tool-sandbox)
enum TrustLevel: String, Sendable, Codable {
    case sandbox
    case standard
    case elevated
}

// Task representation
struct AgentTask: Identifiable, Sendable {
    let id: String
    let from: AgentID
    let to: AgentID
    let instruction: String
    let context: String
    let createdAt: Date
}

// Result
struct AgentResult: Sendable {
    let taskId: String
    let from: AgentID
    let output: String
    let artifacts: [AgentArtifact]
}

struct AgentArtifact: Sendable {
    let type: ArtifactType  // .file, .note, .draft, .searchResult
    let path: String?
    let content: String?
}

// Agent protocol — all agents conform
@MainActor
protocol AgentProtocol: AnyObject {
    var id: AgentID { get }
    var status: AgentStatus { get }
    var trustLevel: TrustLevel { get set }

    func handleTask(_ task: AgentTask) async
    func handleMention(from: AgentID, context: String, request: String) async -> String
    func handleInsight(_ insight: String, from: AgentID)
    func cancel()
}
```

**Reference:**
- Design doc Section 5 (agent specs)
- `openclaw-main/src/agents/tool-catalog.ts` (tool profiles pattern)
- `CoPaw-main/src/copaw/agents/react_agent.py` (agent loop)

**Verification:** Compiles, all types are `Sendable`.

---

### Task 2.2: Create MessageBus Actor

**Files to create:**
- `Epistemos/Agents/MessageBus.swift`

**What:**
Central typed message router. All agents and UI surfaces connect.

```swift
actor MessageBus {
    // Message type (from design doc Section 6)
    enum Message: Sendable {
        // Routing
        case taskAssignment(from: AgentID, to: AgentID, task: AgentTask)
        case taskComplete(from: AgentID, result: AgentResult)

        // Agent-to-agent
        case mention(from: AgentID, to: AgentID, context: String, request: String)
        case mentionResponse(from: AgentID, to: AgentID, response: String)

        // Proactive
        case insight(from: AgentID, relevantTo: AgentID?, content: String)
        case indexRequest(from: AgentID, content: IndexableContent)

        // UI
        case statusUpdate(from: AgentID, status: AgentStatus)
        case notification(from: AgentID, message: String, speak: Bool)
        case activityLog(from: AgentID, action: String, detail: String)

        // Learning Pool
        case searchRequest(from: AgentID, query: SearchQuery)
        case searchResult(to: AgentID, results: [SearchChunk])
    }

    // Subscribe to messages (filtered)
    func subscribe(for agent: AgentID) -> AsyncStream<Message>
    func subscribeAll() -> AsyncStream<Message>  // UI uses this

    // Publish
    func publish(_ message: Message)

    // Recent activity log (last 100 messages, for persistence)
    func recentActivity() -> [Message]
}
```

**Implementation details:**
- Use `AsyncStream.Continuation` per subscriber, stored in `[AgentID: AsyncStream<Message>.Continuation]`
- UI subscriber uses special key (e.g. `.triage` repurposed, or add `.ui` case)
- `publish()` fans out to all matching continuations
- Activity log: circular buffer of last 100 messages (for agent panel display)

**Reference:**
- Design doc Section 6 (Message Bus Architecture)
- `openclaw-main/src/acp/` (bidirectional RPC pattern — adapted to Swift actors)
- Claude Code TeammateTool (JSON inbox pattern — adapted to in-memory)

**Verification:** Unit test: publish taskAssignment, subscriber for that agent receives it. Subscriber for different agent does not.

---

### Task 2.3: Create AgentEngine (Lifecycle Manager)

**Files to create:**
- `Epistemos/Agents/AgentEngine.swift`

**What:**
Owns all agent instances. Manages lifecycle, model allocation, and routing.

```swift
@MainActor @Observable
final class AgentEngine {
    private(set) var agents: [AgentID: any AgentProtocol] = [:]
    private(set) var agentStatuses: [AgentID: AgentStatus] = [:]
    let messageBus: MessageBus

    // Dependencies
    private let mlxClient: MLXClient
    private let mlxModelManager: MLXModelManager
    private let llmService: LLMService
    private let triageService: TriageService

    init(
        messageBus: MessageBus,
        mlxClient: MLXClient,
        mlxModelManager: MLXModelManager,
        llmService: LLMService,
        triageService: TriageService
    )

    // Lifecycle
    func start() async  // Initialize all agents, load triage model
    func stop()          // Cancel all agent tasks, unload models

    // Routing (called by Triage)
    func routeTask(_ task: AgentTask) async

    // Model management
    func loadModelForAgent(_ agentId: AgentID) async throws
    func unloadModelForAgent(_ agentId: AgentID)

    // Trust management
    func setTrustLevel(_ level: TrustLevel, for agentId: AgentID)
}
```

**Model allocation strategy (from design doc Section 4):**
- Triage (0.8B Q4, ~700MB) — always loaded at startup
- Librarian (2B Q4, ~1.8GB) — loaded on demand
- Writer (4B Q4, ~2.8GB) — loaded on demand, swaps out 2B
- Builder (4B-9B, ~2.8-5.6GB) — loaded on demand, uses cloud fallback

Only one large model loaded at a time (0.8B stays resident). Swap takes ~2-5s.

**Reference:**
- Design doc Section 4 (Model Provider Layer)
- Research paper: "Local vs. Cloud Hybrid Architectures" (System 1 on-device, System 2 cloud)

**Verification:** Unit test: `AgentEngine.start()` initializes all 4 agents, triage model loads.

---

### Task 2.4: Create TriageAgent (Classifier)

**Files to create:**
- `Epistemos/Agents/TriageAgent.swift`

**What:**
The always-on classifier. Routes user messages to the right agent or answers directly.

```swift
@MainActor
final class TriageAgent: AgentProtocol {
    let id = AgentID.triage
    var status: AgentStatus = .idle
    var trustLevel: TrustLevel = .standard  // N/A but protocol requires it

    private let mlxClient: MLXClient
    private let messageBus: MessageBus
    private let triageService: TriageService  // Existing — for Apple Intelligence fallback

    // Classification result
    enum Classification: String, Sendable {
        case direct      // Answer immediately
        case librarian   // Route to Librarian
        case writer      // Route to Writer
        case builder     // Route to Builder
        case learningPool // Route to Learning Pool
    }

    // Classify user intent using Qwen 0.8B few-shot
    func classify(_ userMessage: String) async -> Classification

    // Few-shot examples (persisted, grows with corrections)
    private var examples: [(input: String, classification: Classification)]
    func addCorrectionExample(input: String, correct: Classification)

    // AgentProtocol
    func handleTask(_ task: AgentTask) async  // Classify and route
    func handleMention(from: AgentID, context: String, request: String) async -> String
    func handleInsight(_ insight: String, from: AgentID)
    func cancel()
}
```

**Classification prompt (from design doc Section 5):**
```
You are a task router. Classify the user's message into one of:
- DIRECT: Answer immediately (greetings, time, simple facts)
- LIBRARIAN: Note organization, search, connections, tagging
- WRITER: Prose improvement, research writing, article drafting
- BUILDER: Code generation, file creation, terminal commands, IDE work
- LEARNING_POOL: Web search, academic research, current events

Examples:
"organize my notes from last week" -> LIBRARIAN
"write me a swift function that..." -> BUILDER
...

User message: {input}
Classification:
```

**Performance target:** <100ms classification latency with 0.8B model.

**Apple Intelligence fallback:** For "DIRECT" classifications, use existing `TriageService` to route between Apple Intelligence and cloud for the actual response.

**Correction learning:** When user says "no, that's for the Writer", store `(input, .writer)` in the few-shot examples array. Persist to UserDefaults. Cap at 200 examples (FIFO oldest).

**Reference:**
- Design doc Section 5 (Agent 0: Triage)
- `CoPaw-main/src/copaw/agents/command_handler.py` (command routing)
- `openclaw-main/src/routing/` (session-based routing)
- Existing `Epistemos/Engine/TriageService.swift` (complexity-based routing — extended, not replaced)

**Verification:** Unit test: classify("hi") returns .direct, classify("organize my notes") returns .librarian.

---

### Task 2.5: Create Agent Panel UI (Dashboard)

**Files to create:**
- `Epistemos/Views/Agents/AgentPanelView.swift`
- `Epistemos/Views/Agents/AgentCardView.swift`
- `Epistemos/Views/Agents/AgentThreadView.swift`

**What:**
Dashboard sidebar showing agent status cards. Tap card to open agent's conversation thread.

**AgentPanelView** — vertical stack of `AgentCardView` instances:
```
+-------------------------+
|  AGENT PANEL            |
|                         |
|  +-------------------+  |
|  | [bot] Triage      |  |
|  | Status: Idle      |  |
|  | Last: 2m ago      |  |
|  +-------------------+  |
|                         |
|  +-------------------+  |
|  | [bot] Librarian   |  |
|  | Status: Working   |  |
|  | "Indexing 3 notes" |  |
|  +-------------------+  |
|  ...                    |
+-------------------------+
```

**AgentCardView** — shows agent name, icon color, status, last activity. Tappable.

**AgentThreadView** — chat-style view of agent's conversation history (messages, tool calls, results). Reuse existing `MessageBubble` pattern from `Views/Chat/`.

**Integration:**
- Agent Panel is a new sidebar section, toggled from the main window
- Position: right sidebar or dedicated tab (user preference from design doc: "sidebar that sits in the main home window")

**Files to modify:**
- Main window layout (add Agent Panel toggle)
- `AppEnvironment.swift` (add `AgentEngine` to environment)

**Reference:**
- Design doc Section 5 (Agent Panel spec)
- Existing `Views/Chat/ChatSidebarView.swift` (sidebar pattern)
- Existing `Views/Chat/MessageBubble.swift` (message rendering)

**Verification:** Agent Panel shows 4 cards with correct status. Tapping Triage card shows empty thread.

---

### Task 2.6: Wire Triage to Main Chat

**Files to modify:**
- `Epistemos/State/ChatState.swift` (or wherever main chat submission happens)
- `Epistemos/Views/Chat/ChatInputBar.swift`

**What:**
When user sends a message in main chat, route through TriageAgent:

1. User types message, hits send
2. `ChatState` passes message to `AgentEngine.routeTask()`
3. `TriageAgent.classify()` determines target
4. For `.direct`: answer in main chat using existing pipeline
5. For `.librarian`/`.writer`/`.builder`: show routing pill ("→ Routing to Builder"), create task in Agent Panel
6. For `.learningPool`: show routing pill, create search task (will be wired in Phase 7)

**Routing pill:** Small inline element in chat: "→ Routing to Builder" with link to Agent Panel card.

**Add toggle:** "Agent Mode" toggle in chat input bar. When off, messages go through existing pipeline (no classification). When on, all messages route through Triage.

**Reference:**
- Design doc Section 5 (Triage flow), Decision #14 (main chat + agent panel)
- Existing chat submission flow

**Verification:** Type "organize my notes" with Agent Mode on → routing pill appears → Librarian card in Agent Panel shows task.

---

### Task 2.7: Register AgentEngine in AppBootstrap

**Files to modify:**
- `Epistemos/App/AppBootstrap.swift` — add `messageBus: MessageBus`, `agentEngine: AgentEngine`
- `Epistemos/App/AppEnvironment.swift` — add environment keys

**What:**
```swift
// In AppBootstrap.init():
let messageBus = MessageBus()
let agentEngine = AgentEngine(
    messageBus: messageBus,
    mlxClient: mlxClient,
    mlxModelManager: mlxModelManager,
    llmService: llmService,
    triageService: triageService
)

// Start after app is ready:
Task { await agentEngine.start() }
```

**Verification:** App launches with AgentEngine running, Triage model loaded.

---

### Task 2.8: Phase 2 Tests

**Files to create:**
- `EpistemosTests/MessageBusTests.swift`
- `EpistemosTests/TriageAgentTests.swift`
- `EpistemosTests/AgentEngineTests.swift`

**Tests:**
- MessageBus: publish/subscribe routing, fan-out, activity log retention
- TriageAgent: classification accuracy for all 5 categories, correction learning
- AgentEngine: lifecycle (start/stop), model allocation, routing

**Verification:** All tests pass.

---

## Phase 3: Memory System

**Goal:** Build the three-tier memory system so agents have persistent, searchable memory.

**Design doc reference:** Section 7 (Memory System)
**Research paper reference:** "Strategic Advantage of Rust-Native Frameworks" (memory efficiency)

### Task 3.1: Create Rust memory-engine Crate

**Files to create:**
- `memory-engine/Cargo.toml`
- `memory-engine/src/lib.rs`
- `memory-engine/src/embeddings.rs`
- `memory-engine/src/vector_index.rs`
- `memory-engine/src/compaction.rs`

**What:**
Rust crate for Tier 3 (Semantic Memory). Embedding storage, vector search, text compaction.

```rust
// lib.rs — FFI interface

#[no_mangle]
pub extern "C" fn memory_engine_create() -> *mut MemoryEngine;

#[no_mangle]
pub extern "C" fn memory_engine_destroy(engine: *mut MemoryEngine);

// Embed text and store with ID
#[no_mangle]
pub extern "C" fn memory_engine_embed_and_store(
    engine: *mut MemoryEngine,
    id: *const c_char,
    text: *const c_char,
    embedding: *const f32,
    dim: u32,
) -> u8;

// Search by embedding vector (cosine + BM25 hybrid)
#[no_mangle]
pub extern "C" fn memory_engine_search(
    engine: *mut MemoryEngine,
    query_embedding: *const f32,
    dim: u32,
    query_text: *const c_char,
    limit: u32,
    out_count: *mut u32,
) -> *mut SearchResult;

#[no_mangle]
pub extern "C" fn memory_engine_free_results(results: *mut SearchResult, count: u32);

// Compact old text (summarize)
#[no_mangle]
pub extern "C" fn memory_engine_get_compaction_candidates(
    engine: *mut MemoryEngine,
    threshold_ratio: f32,  // 0.7 = 70%
    out_count: *mut u32,
) -> *mut *const c_char;
```

**Internals:**
- `embeddings.rs`: Store `(id, Vec<f32>)` pairs in memory-mapped file (`memmap2`)
- `vector_index.rs`: Brute-force cosine similarity search (fine for <100K vectors). BM25 keyword scoring. Hybrid reranking.
- `compaction.rs`: Return IDs of entries that should be compacted (based on context ratio)

**Cargo.toml deps:** `ndarray`, `serde`, `serde_json`, `memmap2`

**Reference:**
- Design doc Section 7 (Tier 3: Semantic Memory)
- `CoPaw-main/src/copaw/agents/memory/` (compaction logic, 70% threshold)
- Existing `graph-engine/src/embedding.rs` (cosine similarity — reuse pattern)

**Verification:** `cargo test` — embed 100 texts, search by query, verify top result is semantically closest.

---

### Task 3.2: FFI Bridge for memory-engine

**Files to create:**
- `memory-engine-bridge/memory_engine.h` (C header)

**Files to modify:**
- `Epistemos.xcodeproj` — add memory-engine static library target, link header

**What:**
Generate C header from Rust FFI functions using `cbindgen` or manual header. Add to Xcode build.

Same pattern as existing `graph-engine-bridge/graph_engine.h`.

**Reference:** Existing `graph-engine-bridge/graph_engine.h` (448 lines — follow exact same pattern)

**Verification:** Xcode builds with memory-engine linked.

---

### Task 3.3: Swift MemoryService Wrapper

**Files to create:**
- `Epistemos/Agents/MemoryService.swift`

**What:**
Swift wrapper around the Rust memory-engine FFI.

```swift
@MainActor @Observable
final class MemoryService {
    private var engineHandle: OpaquePointer?

    // Tier 3: Semantic
    func embedAndStore(id: String, text: String, embedding: [Float])
    func semanticSearch(queryEmbedding: [Float], queryText: String, limit: Int) -> [MemorySearchResult]

    // Tier 2: Episodic (SwiftData)
    func saveEpisodicMemory(agentId: AgentID, sessionId: String, summary: String, decisions: [String])
    func loadRecentEpisodes(agentId: AgentID, limit: Int) -> [EpisodicMemory]

    // Tier 1: Working (in-memory per agent)
    func shouldCompact(agentId: AgentID, currentTokenCount: Int, maxTokens: Int) -> Bool
    func requestCompaction(agentId: AgentID) -> [String]  // Returns IDs of messages to compact
}
```

**Reference:**
- Design doc Section 7 (all three tiers)
- Existing `GraphState.swift` pattern for FFI wrapper (opaque pointer, nil guards)

**Verification:** Unit test: store 10 memories, search returns relevant results.

---

### Task 3.4: Episodic Memory SwiftData Model

**Files to create:**
- `Epistemos/Models/SDAgentThread.swift`

**What:**
SwiftData model for Tier 2 episodic memory.

```swift
@Model
final class SDAgentThread {
    @Attribute(.unique) var id: String
    var agentId: String           // AgentID.rawValue
    var projectId: String?        // Optional project scope
    var documentId: String?       // Optional note scope
    var summary: String           // Compacted session summary
    var keyDecisions: [String]    // Important decisions made
    var toolResults: [String]     // Notable tool outputs
    var createdAt: Date
    var archivedAt: Date?         // Non-nil = archived (>90 days)

    init(id: String = UUID().uuidString, agentId: String, ...)
}
```

**Files to modify:**
- `AppBootstrap.swift` — add `SDAgentThread` to `ModelContainer` schema

**Reference:**
- Design doc Section 7 (Tier 2: Episodic)
- Existing `Models/SDPage.swift` (SwiftData model pattern)

**Verification:** Unit test: create, save, query `SDAgentThread` via `ModelContext`.

---

### Task 3.5: Working Memory with Compaction

**Files to create:**
- `Epistemos/Agents/WorkingMemory.swift`

**What:**
Per-agent in-memory context buffer with automatic compaction.

```swift
final class WorkingMemory: Sendable {
    let agentId: AgentID
    private let maxTokens: Int  // Model context window

    // Current context
    var messages: [Chat.Message]
    var currentTokenCount: Int

    // Compaction (design doc: 70% threshold)
    var needsCompaction: Bool { Double(currentTokenCount) / Double(maxTokens) > 0.7 }

    // Compact: summarize older messages using small model, replace with summary
    func compact(using mlxClient: MLXClient) async -> [Chat.Message]

    // Todo rewriting (Manus pattern): inject current goals into recent context
    func rewriteTodos(currentGoals: [String]) -> [Chat.Message]

    func append(_ message: Chat.Message)
    func clear()
}
```

**Manus pattern (from design doc):**
Before each agent turn, rewrite the current task goals into a system message at the end of context. This prevents goal drift as context compacts.

**Reference:**
- Design doc Section 7 (Tier 1: Working Memory)
- `CoPaw-main/src/copaw/agents/memory/` (compaction at 70%)
- Manus pattern (todo rewriting into context)

**Verification:** Unit test: fill working memory to 75%, verify `needsCompaction` is true. After `compact()`, verify token count dropped below 50%.

---

### Task 3.6: Register MemoryService in AppBootstrap

**Files to modify:**
- `AppBootstrap.swift` — add `memoryService: MemoryService`
- `AppEnvironment.swift` — add environment key

**Verification:** App launches, MemoryService initializes Rust engine.

---

## Phase 4: Librarian Agent

**Goal:** Build the first full agent — reads, organizes, tags, and connects notes. Has both passive (background scanning) and active (@mention) modes.

**Design doc reference:** Section 5 (Agent 1: Librarian)

### Task 4.1: Create LibrarianAgent

**Files to create:**
- `Epistemos/Agents/LibrarianAgent.swift`

**What:**
Full agent implementation conforming to `AgentProtocol`.

```swift
@MainActor
final class LibrarianAgent: AgentProtocol {
    let id = AgentID.librarian
    var status: AgentStatus = .idle
    var trustLevel: TrustLevel = .standard

    private let mlxClient: MLXClient
    private let llmService: LLMService
    private let messageBus: MessageBus
    private let memoryService: MemoryService
    private let workingMemory: WorkingMemory

    // Tools available to Librarian
    private let tools: [LibrarianTool]

    // Passive monitoring
    private var monitoringTask: Task<Void, Never>?
    func startPassiveMonitoring()
    func stopPassiveMonitoring()

    // Active tasks
    func handleTask(_ task: AgentTask) async  // ReACT loop for complex requests
    func handleMention(from: AgentID, context: String, request: String) async -> String

    // Search
    func searchNotes(query: String) async -> [NoteSearchResult]
    func semanticSearch(query: String) async -> [MemorySearchResult]
}
```

**Librarian tools (from design doc):**
- `note_search` — keyword search across all notes (uses existing VaultSyncService / NoteInsightService)
- `note_read` — read a specific note's content
- `note_tag` — add/modify tags on a note
- `note_move` — move note to different folder
- `graph_query` — traverse knowledge graph (existing `graph_engine_search` FFI)
- `embedding_search` — semantic search via MemoryService

**Passive mode behavior:**
- Observe `NotesUIState` for note saves
- When note saved, re-embed via MemoryService
- Periodically scan for: untagged notes, contradictions, missing connections
- Emit `.insight()` messages on message bus when findings are significant
- UI: subtle badge on agent's sidebar section

**Active mode (ReACT loop):**
```
while !done && iterations < maxIterations:
    1. Build prompt: system + tools + working memory + user request
    2. Generate with MLX (2B) or cloud
    3. Parse for tool calls
    4. Execute tools
    5. Append results to working memory
    6. Check if task complete
```

**Reference:**
- Design doc Section 5 (Agent 1 spec)
- `CoPaw-main/src/copaw/agents/react_agent.py` (ReACT loop with max_iters)
- `openclaw-main/src/agents/tool-catalog.ts` (tool profile pattern)
- Research paper: "The ReAct Paradigm and Reasoning Loops", "Implementation of Multi-Turn Logic"

**Verification:** Test: "@librarian find notes about CRISPR" returns relevant notes. Passive mode detects untagged note.

---

### Task 4.2: Librarian Tools Implementation

**Files to create:**
- `Epistemos/Agents/Tools/NoteTools.swift`

**What:**
Tool implementations that Librarian (and later Writer) uses.

```swift
enum NoteTools {
    static func searchNotes(query: String, modelContext: ModelContext) -> [NoteSearchResult]
    static func readNote(id: String, modelContext: ModelContext) -> String?
    static func tagNote(id: String, tags: [String], modelContext: ModelContext)
    static func moveNote(id: String, toFolder: String, modelContext: ModelContext)
}
```

These wrap existing SwiftData queries on `SDPage`.

**Reference:** Existing `Sync/VaultSyncService.swift`, `Engine/NoteInsightService.swift`

**Verification:** Unit test: create 5 test notes, search returns correct ones.

---

### Task 4.3: Proactive Signal UI (Badges)

**Files to modify:**
- `Epistemos/Views/Notes/NotesSidebar.swift` — add badge indicators for agent insights

**What:**
When Librarian detects an insight (untagged note, contradiction, missing connection), show a subtle dot indicator next to the note in the sidebar. Dot color matches Librarian (blue).

Keep it minimal — a small colored circle next to affected notes.

**Reference:**
- Design doc Section 5 (Librarian passive mode, proactive signals)
- Existing sidebar patterns

**Verification:** Librarian flags an untagged note → blue dot appears next to it in sidebar.

---

## Phase 5: Writer Agent

**Goal:** Configurable writing assistant with presets, integrated into existing per-note chat.

**Design doc reference:** Section 5 (Agent 2: Writer)

### Task 5.1: Create WriterAgent

**Files to create:**
- `Epistemos/Agents/WriterAgent.swift`

**What:**
```swift
@MainActor
final class WriterAgent: AgentProtocol {
    let id = AgentID.writer
    var status: AgentStatus = .idle
    var trustLevel: TrustLevel = .standard

    private let llmService: LLMService  // Cloud-first for quality
    private let mlxClient: MLXClient     // Qwen 4B for quick edits
    private let messageBus: MessageBus
    private let memoryService: MemoryService
    private let workingMemory: WorkingMemory

    // Preset system
    var activePreset: WriterPreset?
    var customSettings: WriterSettings

    // Generate with configurable style
    func write(
        instruction: String,
        sourceText: String?,
        preset: WriterPreset?,
        settings: WriterSettings
    ) async -> AsyncThrowingStream<String, Error>

    // Parse chain-of-thought instructions
    func parseInstruction(_ instruction: String) -> WriterPlan
}
```

**Reference:**
- Design doc Section 5 (Agent 2 spec)
- Existing `NoteChatState` (per-note AI chat — Writer extends this)

**Verification:** Writer generates text matching preset style.

---

### Task 5.2: Writer Preset System

**Files to create:**
- `Epistemos/Agents/WriterPresets.swift`
- `Epistemos/Models/SDWriterPreset.swift`

**What:**
```swift
struct WriterSettings: Codable, Sendable {
    var style: WritingStyle       // formal, casual, technical, creative
    var length: Int               // target word count
    var depth: DepthLevel         // shallow, moderate, deep
    var method: ResearchMethod    // analytical, descriptive, argumentative
    var tone: ToneLevel           // objective, persuasive, conversational
    var citation: CitationStyle?  // APA 7th, MLA, Chicago, none
}

enum WriterPreset: String, CaseIterable, Codable {
    case academicPaper
    case blogPost
    case technicalDoc
    case grantProposal
    case literatureReview
    case custom

    var defaultSettings: WriterSettings { ... }
}
```

**SwiftData model for custom presets:**
```swift
@Model
final class SDWriterPreset {
    @Attribute(.unique) var id: String
    var name: String
    var settingsJSON: String  // Encoded WriterSettings
    var createdAt: Date
}
```

**Reference:**
- Design doc Section 5 (Writer preset system, UI mockup)

**Verification:** Select "Academic Paper" preset → WriterSettings populated correctly.

---

### Task 5.3: Writer Integration with Note Editor

**Files to modify:**
- `Epistemos/State/NoteChatState.swift` — add Writer agent awareness
- Existing note chat UI — add preset selector dropdown

**What:**
When Writer is active on a note, its output streams through the existing `NoteChatState` token-buffering pipeline (60ms buffer, `---` divider, accept/discard flow). The Writer extends `NotesOperation` with agent-powered alternatives.

**Key:** Don't break existing non-agent note chat. Agent mode is additive.

**Reference:**
- Design doc Section 5 (Writer integration)
- Existing `NoteChatState` architecture (callbacks: `onStreamStart`, `onTokenFlush`, `onAccept`, `onDiscard`)

**Verification:** Writer streams text into note editor below `---` divider. Accept/discard works.

---

### Task 5.4: Writer Preset UI

**Files to create:**
- `Epistemos/Views/Agents/WriterPresetPanel.swift`

**What:**
Panel with preset radio buttons and manual setting dials (from design doc Section 5 mockup). Opens when Writer is active.

**Verification:** Select preset, dials update. Custom settings persist.

---

## Phase 6: Builder Agent

**Goal:** Code generation agent with built-in IDE workspace, trust-enforced tool execution, and Claude Code agent loop.

**Design doc reference:** Section 5 (Agent 3: Builder), Section 11 (Trust Levels)
**Research paper reference:** "The Core Agentic Architecture in Rust", "Ownership and Memory Safety Checklist"

### Task 6.1: Create Rust tool-sandbox Crate

**Files to create:**
- `tool-sandbox/Cargo.toml`
- `tool-sandbox/src/lib.rs`
- `tool-sandbox/src/file_ops.rs`
- `tool-sandbox/src/shell_exec.rs`
- `tool-sandbox/src/permissions.rs`

**What:**
Rust crate that validates and executes tool calls with trust-level enforcement.

```rust
// permissions.rs
#[repr(C)]
pub enum TrustLevel {
    Sandbox = 0,
    Standard = 1,
    Elevated = 2,
}

#[repr(C)]
pub struct ToolPermission {
    pub trust_level: TrustLevel,
    pub workspace_path: *const c_char,
    pub whitelisted_commands: *const *const c_char,
    pub whitelisted_count: u32,
}

// Validate before execution
#[no_mangle]
pub extern "C" fn tool_sandbox_validate_file_read(
    path: *const c_char,
    permission: *const ToolPermission,
) -> u8; // 0 = denied, 1 = allowed

#[no_mangle]
pub extern "C" fn tool_sandbox_validate_file_write(
    path: *const c_char,
    permission: *const ToolPermission,
) -> u8;

#[no_mangle]
pub extern "C" fn tool_sandbox_validate_shell(
    command: *const c_char,
    permission: *const ToolPermission,
) -> u8;

// Execute
#[no_mangle]
pub extern "C" fn tool_sandbox_exec_shell(
    command: *const c_char,
    working_dir: *const c_char,
    permission: *const ToolPermission,
    out_stdout: *mut *mut c_char,
    out_stderr: *mut *mut c_char,
) -> i32; // exit code, -1 if denied

#[no_mangle]
pub extern "C" fn tool_sandbox_free_string(s: *mut c_char);
```

**Trust enforcement rules (from design doc Section 11):**

| Level | File Read | File Write | File Delete | Shell | System |
|---|---|---|---|---|---|
| Sandbox | Own folder only | Denied | Denied | Denied | Denied |
| Standard | Own folder + notes | Own folder | Own folder | Whitelisted (`swift`, `cargo`, `npm`, `git`) | Denied |
| Elevated | Full filesystem | Full filesystem | Full filesystem | Any | AppleScript |

**Whitelisted commands for Standard:**
`["swift", "cargo", "npm", "node", "git", "python3", "pip3", "make", "xcodebuild"]`

**Path validation:** Resolve symlinks, check prefix matches workspace path. Prevent `../` traversal.

**Reference:**
- Design doc Section 11 (Trust Levels, Rust enforcement)
- `openclaw-main/src/agents/tool-catalog.ts` (tool profiles with safety tiers)
- Research paper: "Ownership and Memory Safety Checklist", "Unsafe Code Contracts"

**Verification:** `cargo test` — validate file read inside workspace (allowed), outside (denied). Validate shell with whitelisted command (allowed), arbitrary command (denied for Standard).

---

### Task 6.2: FFI Bridge for tool-sandbox

**Files to create:**
- `tool-sandbox-bridge/tool_sandbox.h`

**Files to modify:**
- `Epistemos.xcodeproj` — link tool-sandbox static library

**Verification:** Xcode builds with tool-sandbox linked.

---

### Task 6.3: Swift ToolExecutor Wrapper

**Files to create:**
- `Epistemos/Agents/Tools/ToolExecutor.swift`

**What:**
Swift wrapper around Rust tool-sandbox FFI.

```swift
@MainActor
final class ToolExecutor {
    func validateAndExecute(
        call: ToolCall,
        agentId: AgentID,
        trustLevel: TrustLevel,
        workspacePath: String
    ) async -> ToolExecutionResult

    enum ToolExecutionResult {
        case success(output: String)
        case denied(reason: String)
        case needsApproval(action: String, onApprove: () async -> String)
        case error(String)
    }
}
```

**Approval flow:** When action needs approval (e.g., shell exec at Standard trust), return `.needsApproval` with a closure. UI shows approval dialog. If approved, closure executes.

"Allow All This Session" stores approved patterns for current session. Resets on app restart.

**Reference:**
- Design doc Section 11 (Semi-autonomous approval dialog mockup)
- Research paper: "prompt hooks allow the developer to intercept the reasoning process"

**Verification:** Test: execute whitelisted command → success. Execute arbitrary command at Standard → needsApproval.

---

### Task 6.4: Create BuilderAgent

**Files to create:**
- `Epistemos/Agents/BuilderAgent.swift`

**What:**
The Claude Code-style agent loop.

```swift
@MainActor
final class BuilderAgent: AgentProtocol {
    let id = AgentID.builder
    var status: AgentStatus = .idle
    var trustLevel: TrustLevel = .standard

    private let llmService: LLMService
    private let mlxClient: MLXClient
    private let messageBus: MessageBus
    private let memoryService: MemoryService
    private let toolExecutor: ToolExecutor
    private let workingMemory: WorkingMemory

    // Workspace
    var workspacePath: String  // Default: ~/Epistemos-Projects/{project}/
    var activityLog: [ActivityEntry] = []

    // The agent loop (from design doc)
    func executeTask(_ task: AgentTask) async {
        var iterations = 0
        let maxIterations = 25

        while !task.isComplete && iterations < maxIterations {
            // 1. Build context
            // 2. Call model (MLX Qwen-Coder or Cloud Claude)
            // 3. Parse response for tool calls
            // 4. If tool call: validate, execute, log, feed back
            // 5. If text: stream to thread, check completion
            // 6. Rewrite todo list (Manus pattern)
            iterations += 1
        }
    }
}
```

**Builder tools:**
- `file_read(path)` — read file content
- `file_write(path, content)` — write/create file
- `file_delete(path)` — delete file
- `shell_exec(command, workingDir)` — execute shell command
- `note_search(query)` — search user's notes for context
- `graph_query(query)` — search knowledge graph

All gated through `ToolExecutor` (Rust validation).

**Reference:**
- Design doc Section 5 (Builder agent loop pseudocode)
- `CoPaw-main/src/copaw/agents/react_agent.py` (ReACT with max_iters=50)
- Claude Code agent loop pattern (generate → tool → validate → execute → repeat)
- Manus pattern (todo rewriting)
- Research paper: "Implementation of Multi-Turn Logic", ".multi_turn(n)"

**Verification:** Builder creates a file, writes content, runs `cat` to verify, reports success.

---

### Task 6.5: Builder Workspace UI

**Files to create:**
- `Epistemos/Views/Agents/BuilderWorkspaceView.swift`
- `Epistemos/Views/Agents/BuilderFileTreeView.swift`
- `Epistemos/Views/Agents/BuilderEditorView.swift`
- `Epistemos/Views/Agents/BuilderTerminalView.swift`
- `Epistemos/Views/Agents/BuilderActivityLogView.swift`

**What:**
Three-pane workspace (from design doc Section 5 mockup):
- Left: File tree (scoped to workspace folder)
- Center: Syntax-highlighted code editor (NSTextView with basic syntax highlighting)
- Bottom: Terminal output pane (read-only, shows command output)
- Left bottom: Activity log (chronological list of actions)

**File tree:** Use `FileManager` to enumerate workspace directory. Real-time observation via `DispatchSource.makeFileSystemObjectSource`.

**Code editor:** Reuse `NSTextView` with basic keyword highlighting (Swift/Rust keywords). Not a full IDE — just syntax-aware editing.

**Terminal:** Read-only `NSTextView` showing streamed shell output from `Process` execution.

**Reference:**
- Design doc Section 5 (Builder workspace mockup)
- Existing `ProseEditorRepresentable` (NSTextView wrapping pattern)

**Verification:** File tree shows workspace contents. Editing a file saves to disk. Terminal shows output.

---

### Task 6.6: Agent Section in Notes Sidebar

**Files to modify:**
- `Epistemos/Views/Notes/NotesSidebar.swift`

**What:**
Add collapsible "AGENTS" section below user's note folders (from design doc Section 9).

```
v AGENTS
  v [bot] Librarian
    > Tag Reports
    > Connection Maps
  v [bot] Writer
    > Drafts
  v [bot] Builder
    > parser-project
      main.swift
      ast.swift
```

Each agent section lists its workspace folder contents. Files are browsable and editable.

**Reference:**
- Design doc Section 9 (Agent Section in Notes Sidebar mockup)
- Existing `NotesSidebar.swift` structure

**Verification:** AGENTS section appears in sidebar with correct agent sub-sections.

---

### Task 6.7: Approval Dialog

**Files to create:**
- `Epistemos/Views/Agents/ToolApprovalView.swift`

**What:**
Alert dialog for semi-autonomous approval (from design doc Section 11).

```
+----------------------------------------+
|  [bot] Builder wants to:              |
|  Run command: swift build              |
|  In: ~/Epistemos-Projects/parser/     |
|                                        |
|  [Allow]  [Allow All This Session]     |
|  [Deny]   [Configure Trust ->]         |
+----------------------------------------+
```

**Verification:** Builder requests shell exec → dialog appears → Allow executes → Deny blocks.

---

## Phase 7: Learning Pool

**Goal:** Port Perplexica's search pipeline to Swift+Rust. Any agent can query.

**Design doc reference:** Section 8 (Learning Pool)

### Task 7.1: Create Rust learning-pool Crate

**Files to create:**
- `learning-pool/Cargo.toml`
- `learning-pool/src/lib.rs`
- `learning-pool/src/web_search.rs`
- `learning-pool/src/scraper.rs`
- `learning-pool/src/chunker.rs`
- `learning-pool/src/rag.rs`

**What:**
Rust crate for web fetching, HTML scraping, text chunking, and RAG pipeline.

```rust
// web_search.rs — Brave Search API
pub async fn brave_search(query: &str, api_key: &str, count: u32) -> Vec<SearchResult>;

// scraper.rs — URL fetching + HTML stripping
pub async fn scrape_url(url: &str, max_length: usize) -> String;

// chunker.rs — Split text into chunks for embedding
pub fn chunk_text(text: &str, chunk_size: usize, overlap: usize) -> Vec<TextChunk>;

// rag.rs — RAG pipeline: chunk, embed, store, search
pub fn rag_index_document(doc_id: &str, text: &str, engine: &mut MemoryEngine);
pub fn rag_search(query_embedding: &[f32], query_text: &str, engine: &MemoryEngine, limit: u32) -> Vec<RagResult>;
```

**Deps:** `reqwest`, `serde`, `serde_json`, `tokio` (async runtime for HTTP)

**Note:** Web search and URL scraping already exist in Swift (from MLXChat's `BraveSearchService.swift` and `WebFetchService.swift`). The Rust version handles heavy lifting (chunking, RAG), while Swift handles the HTTP calls natively to avoid Tokio in-process.

**Alternative approach (simpler):** Keep web search in Swift (port MLXChat code), only put chunking + RAG in Rust.

**Reference:**
- Design doc Section 8 (Learning Pool pipeline)
- `Perplexica-master/src/lib/agents/search/` (full pipeline)
- `mlxchat-main/MLXChat/Tools/BraveSearchService.swift` (Brave Search)
- `mlxchat-main/MLXChat/Tools/WebFetchService.swift` (URL fetch + HTML strip)

**Verification:** `cargo test` — chunk a 5000-word text into 500-word chunks with 100-word overlap. Verify correct count and overlap.

---

### Task 7.2: Port Search Pipeline to Swift

**Files to create:**
- `Epistemos/Agents/LearningPool/LearningPoolService.swift`
- `Epistemos/Agents/LearningPool/QueryClassifier.swift`
- `Epistemos/Agents/LearningPool/Researcher.swift`
- `Epistemos/Agents/LearningPool/AnswerWriter.swift`
- `Epistemos/Agents/LearningPool/BraveSearchService.swift`
- `Epistemos/Agents/LearningPool/WebFetchService.swift`

**What:**
Port Perplexica's 3-stage pipeline:

**Stage 1 — Classify:**
```swift
struct QueryClassifier {
    func classify(_ query: String, using mlxClient: MLXClient) async -> ClassificationResult
}

struct ClassificationResult {
    var shouldSearch: Bool
    var searchSources: [SearchSource]  // web, academic, notes, uploads
    var rewrittenQuery: String
    var widgets: [WidgetType]  // weather, stocks, calc
}
```

**Stage 2 — Research (ReACT loop):**
```swift
struct Researcher {
    func research(
        query: String,
        sources: [SearchSource],
        iterationLimit: Int,  // Speed=2, Balanced=6, Quality=25
        using mlxClient: MLXClient
    ) -> AsyncThrowingStream<ResearchEvent, Error>
}
```

**Stage 3 — Write answer:**
```swift
struct AnswerWriter {
    func writeAnswer(
        query: String,
        researchResults: [ResearchChunk],
        using llmService: LLMService
    ) -> AsyncThrowingStream<String, Error>
}
```

**BraveSearchService and WebFetchService:** Port directly from MLXChat (nearly identical code, adapt to Epistemos patterns).

**Reference:**
- Design doc Section 8 (steps, what changes from Perplexica)
- `Perplexica-master/src/lib/agents/search/classifier.ts`
- `Perplexica-master/src/lib/agents/search/researcher/index.ts`
- `mlxchat-main/MLXChat/Tools/BraveSearchService.swift` (56 lines — port directly)
- `mlxchat-main/MLXChat/Tools/WebFetchService.swift` (87 lines — port directly)

**Verification:** Query "what is CRISPR" → classifier selects web search → researcher fetches results → answer writer produces cited response.

---

### Task 7.3: Learning Pool UI

**Files to create:**
- `Epistemos/Views/LearningPool/LearningPoolView.swift`
- `Epistemos/Views/LearningPool/SearchResultView.swift`

**What:**
Home window section (from design doc Section 8 mockup):
- Search bar
- Mode selector: Speed / Balanced / Quality
- Source checkboxes: Web, Academic, Notes
- Recent searches list
- Upload document button (for RAG)

**Reference:**
- Design doc Section 8 (UI mockup)

**Verification:** Search executes, results display with citations and source URLs.

---

### Task 7.4: Wire Learning Pool to Message Bus

**Files to modify:**
- `Epistemos/Agents/LearningPool/LearningPoolService.swift`

**What:**
Learning Pool subscribes to message bus for `.searchRequest` messages. Agents can query it by publishing a search request. Results returned via `.searchResult`.

**Verification:** Librarian publishes search request → Learning Pool executes → results delivered back to Librarian via bus.

---

## Phase 8: Graph NPCs

**Goal:** Agents become visible animated NPC entities in the Metal-rendered knowledge graph.

**Design doc reference:** Section 9 (Graph NPCs & Agent Visualization)

### Task 8.1: Add Agent Node/Edge Types to Rust graph-engine

**Files to modify:**
- `graph-engine/src/types.rs` — add new NodeType variants (Agent=8, CodeFile=9, CodeFolder=10, Draft=11, SearchResult=12)
- `graph-engine/src/types.rs` — add new EdgeType variants (agentWorkedOn, agentAttachedTo, bridgedTo, derivedFrom)

**What:**
Extend existing enums:

```rust
#[repr(u8)]
pub enum NodeType {
    Note = 0, Chat = 1, Idea = 2, Source = 3, Folder = 4,
    Quote = 5, Tag = 6, Block = 7,
    // New for agents:
    Agent = 8, CodeFile = 9, CodeFolder = 10, Draft = 11, SearchResult = 12,
}
```

**Files to also modify:**
- `Epistemos/Models/GraphTypes.swift` — mirror new types in Swift enum
- FFI header — add new node type constants

**Reference:**
- Design doc Section 9 (NPC Node Types table)
- Existing `graph-engine/src/types.rs`

**Verification:** `cargo test` — create Agent node, CodeFile node, connect with agentWorkedOn edge.

---

### Task 8.2: AgentNPCState in Rust

**Files to create:**
- `graph-engine/src/npc.rs`

**What:**
```rust
pub struct AgentNPCState {
    pub agent_id: u8,
    pub position: [f32; 3],
    pub target_node: Option<u64>,
    pub state: NPCAnimState,
    pub glow_color: [f32; 4],
    pub glow_intensity: f32,
    pub trail_points: Vec<[f32; 3]>,
}

pub enum NPCAnimState {
    Idle,
    Moving(f32),     // progress 0-1
    Attached(f32),   // angle in radians
    Working(f32),    // pulse phase
}
```

**Add to Engine struct:** `npcs: Vec<AgentNPCState>` (4 slots, one per agent).

**FFI functions:**
```c
void graph_engine_npc_set_state(Engine* engine, uint8_t agent_id, uint8_t state, float param);
void graph_engine_npc_set_target(Engine* engine, uint8_t agent_id, const char* node_uuid);
void graph_engine_npc_get_screen_pos(Engine* engine, uint8_t agent_id, float* out_x, float* out_y);
```

**Reference:**
- Design doc Section 9 (AgentNPCState struct, NPCAnimState enum)

**Verification:** `cargo test` — create NPC, set target node, verify position interpolates toward target.

---

### Task 8.3: NPC Rendering (Metal Shader)

**Files to modify:**
- `graph-engine/src/renderer.rs` — add NPC rendering pass

**What:**
Render NPCs as colored circles (~20px) with glow effect. Color per agent (blue=Librarian, green=Writer, orange=Builder, white=Triage). Glow intensity oscillates when working.

**Animation in render loop:**
- Idle: sinusoidal Y offset (bobbing)
- Working: glow pulse (sin wave on intensity)
- Moving: lerp position toward target
- Attached: circular orbit around target node

Particle trail: store last 10 positions in `trail_points`, render as fading dots behind NPC.

**Reference:**
- Design doc Section 9 (NPC visual design, animation states)
- Existing `graph-engine/src/renderer.rs` (glow shader pattern — reuse for NPC glow)

**Verification:** NPC renders in graph, bobs when idle, pulses when working.

---

### Task 8.4: Agent Territory (Separate Physics)

**Files to modify:**
- `graph-engine/src/simulation.rs` — add second force simulation instance

**What:**
Agent territory is a separate graph region with its own physics:
- Tighter gravity (compact workspace)
- Weaker repulsion (nodes cluster closer)
- Connected to main graph via "bridge" edge with very weak spring

**Portal node:** Special node at the bridge point. Clicking it triggers camera transition.

**FFI:**
```c
void graph_engine_set_territory_mode(Engine* engine, uint8_t active); // 0=main, 1=territory
void graph_engine_territory_add_node(Engine* engine, const char* uuid, uint8_t zone, ...);
```

**Zones:** 0=Librarian, 1=Writer, 2=Builder (color-tinted backgrounds)

**Reference:**
- Design doc Section 9 (Territory layout, physics separation, portal interaction)

**Verification:** Territory renders with correct zone tinting. Camera transitions between main graph and territory.

---

### Task 8.5: Wire NPC Actions to Agent Events

**Files to create:**
- `Epistemos/Agents/NPCController.swift`

**What:**
Listens to message bus and updates NPC states:

| Agent Event | NPC Action |
|---|---|
| Agent receives task | NPC moves to target node |
| Agent reads note | NPC attaches, glow dims |
| Agent writes/modifies | NPC attaches, glow brightens + pulses |
| Agent creates file | New node in territory, NPC moves there |
| Agent @mentions another | NPC moves toward other agent's zone |
| Agent completes | NPC returns to home zone |
| Agent idle | NPC bobs in home zone |

**Reference:**
- Design doc Section 9 (NPC behavior rules table)

**Verification:** Builder creates a file → new CodeFile node appears in territory → Builder NPC moves to it → glow pulses.

---

## Phase 9: Voice System

**Goal:** Chatterbox TTS integration. Each agent gets a distinct voice. Read Mode for notes, chat, and graph.

**Design doc reference:** Section 10 (Voice System)

### Task 9.1: Create Python TTS Daemon

**Files to create:**
- `Epistemos/Resources/tts_daemon.py`

**What:**
Persistent Python subprocess that loads Chatterbox Turbo and responds to JSON requests via stdin/stdout.

```python
# Protocol:
# stdin:  {"text": "...", "agent": "librarian", "ref_audio": "path/to/ref.wav", "output": "/tmp/out.wav"}
# stdout: {"status": "ok", "duration_ms": 450, "output": "/tmp/out.wav"}

import sys, json
from chatterbox.tts_turbo import ChatterboxTurboTTS

model = ChatterboxTurboTTS.from_pretrained(device="mps")

for line in sys.stdin:
    request = json.loads(line)
    wav = model.generate(
        text=request["text"],
        audio_prompt_path=request.get("ref_audio"),
    )
    # Save to output path
    torchaudio.save(request["output"], wav, 24000)
    print(json.dumps({"status": "ok", "duration_ms": int(elapsed * 1000)}))
    sys.stdout.flush()
```

**Bundle Python:** Ship with embedded Python 3.11 + dependencies, or require user to have Python installed. Decision: require Python initially (simplifies distribution). Add "Install Voice" setup wizard later.

**Reference:**
- `chatterbox-master/src/chatterbox/tts_turbo.py` (API)
- `chatterbox-master/example_for_mac.py` (MPS device usage)
- Design doc Section 10 (daemon architecture)

**Verification:** Daemon starts, receives JSON request, produces WAV file.

---

### Task 9.2: Swift TTS Wrapper

**Files to create:**
- `Epistemos/Engine/ChatterboxTTSEngine.swift`

**What:**
```swift
@MainActor @Observable
final class ChatterboxTTSEngine {
    var isRunning = false
    var isGenerating = false

    // Daemon lifecycle
    func start() async throws    // Spawn Python subprocess
    func stop()                   // Kill subprocess

    // Generate speech
    func speak(
        text: String,
        agentId: AgentID,
        referenceAudio: URL?  // For voice cloning
    ) async throws -> URL  // Path to generated WAV

    // Playback
    func play(_ audioURL: URL)
    func pause()
    func resume()
    func stop()

    // Per-agent voice config
    var agentVoices: [AgentID: VoiceConfig]
}

struct VoiceConfig: Codable {
    var referenceAudioPath: String?  // nil = default voice
    var speed: Float = 1.0
    var volume: Float = 0.8
}
```

**Playback:** Use `AVAudioEngine` for low-latency playback with volume control.

**Reference:**
- Design doc Section 10 (architecture diagram, per-agent voices)
- `chatterbox-master/example_for_mac.py`

**Verification:** `speak(text: "Hello", agentId: .librarian)` produces audio, plays through speakers.

---

### Task 9.3: Read Mode Toggles

**Files to modify:**
- `Epistemos/Views/Notes/NoteTabView.swift` — add "Read" toggle button
- `Epistemos/Views/Chat/ChatView.swift` — add "Read" toggle
- `Epistemos/Views/Graph/HologramNodeInspector.swift` — add "Read Summary" toggle

**What:**
Per-surface toggle that reads content aloud using ChatterboxTTSEngine:
- **Notes:** Reads full note text. Shows progress bar. Pause/resume.
- **Chat:** Reads assistant messages as they complete.
- **Graph:** Reads node summary when selected.

**Reference:**
- Design doc Section 10 (Voice Integration Points table, Read Mode)

**Verification:** Toggle Read Mode on a note → text is spoken aloud → pause works.

---

### Task 9.4: Voice Settings UI

**Files to create:**
- `Epistemos/Views/Settings/VoiceSettingsView.swift`

**What:**
From design doc Section 10 mockup:
- Master toggle (on/off)
- Per-agent voice selector (Default / Custom)
- Record button for voice cloning (5-15s sample)
- Read Mode checkboxes (Notes, Chat, Graph Summaries)
- Speed slider, Volume slider

**Verification:** Record voice sample → agent uses cloned voice.

---

### Task 9.5: Register TTS in AppBootstrap

**Files to modify:**
- `AppBootstrap.swift` — add `ttsEngine: ChatterboxTTSEngine`
- `AppEnvironment.swift` — add environment key

**Verification:** TTS engine starts with app (if voice enabled in settings).

---

## Phase 10: Polish & Distribution

**Goal:** Production hardening, App Store Lite build, Direct Download Pro build, notification system, performance tuning.

**Design doc reference:** Sections 12 (Notifications), 13 (Distribution)

### Task 10.1: Compile-Time Feature Gating

**Files to modify:**
- Xcode project — add `EPISTEMOS_PRO` build configuration
- Create two schemes: "Epistemos Lite" and "Epistemos Pro"

**What:**
```swift
#if EPISTEMOS_PRO
// Full filesystem access, shell execution, Elevated trust, Ollama, AppleScript
#else
// Sandboxed file access, no shell, max Standard trust, no Ollama
#endif
```

Gate these features behind `#if EPISTEMOS_PRO`:
- `TrustLevel.elevated` (disable in Lite)
- Shell/terminal execution in Builder
- Full filesystem access outside workspace
- Ollama integration
- System actions (AppleScript)

**Lite is still a real product** — all 4 agents, Agent Panel, Learning Pool, Graph NPCs, TTS, three-tier memory all work in Lite.

**Reference:**
- Design doc Section 13 (feature comparison table)

**Verification:** Build both schemes. Lite scheme builds without elevated features. Pro scheme has all features.

---

### Task 10.2: Notification System

**Files to create:**
- `Epistemos/Agents/NotificationService.swift`

**What:**
Three channels (from design doc Section 12):

```swift
@MainActor @Observable
final class NotificationService {
    func notify(
        from agentId: AgentID,
        message: String,
        channel: NotificationChannel
    )

    enum NotificationChannel {
        case macOS      // UNUserNotificationCenter
        case inApp      // Badge on agent's sidebar section
        case voice      // ChatterboxTTSEngine.speak()
    }
}
```

Subscribe to message bus `.notification` events. Route to configured channels per agent.

**Reference:**
- Design doc Section 12 (three channels, per-agent settings)

**Verification:** Agent completes task → macOS notification appears → voice speaks summary (if enabled).

---

### Task 10.3: Trust Settings UI

**Files to create:**
- `Epistemos/Views/Settings/TrustSettingsView.swift`

**What:**
Per-agent trust level configuration:
- Three-tier picker (Sandbox / Standard / Elevated) per agent
- Whitelisted commands editor (for Standard tier)
- Workspace path selector per agent
- "Elevated requires Pro" label in Lite build

**Verification:** Change Builder trust to Elevated → Builder can execute arbitrary shell commands.

---

### Task 10.4: Performance Tuning

**What:**
- Model swap latency profiling — target <3s swap between 2B and 4B
- Memory pressure monitoring — graceful unload when system memory low
- GPU memory ceiling — respect `GPU.set(memoryLimit:)` across all GPU consumers (MLX + Metal graph)
- Token generation throughput — target >30 tok/s for 0.8B on M1, >50 tok/s on M3
- Test across M1/M2/M3/M4

**Files to modify:**
- `MLXEngine.swift` — add memory pressure observer
- `AgentEngine.swift` — unload non-essential models when memory pressure high

**Verification:** Profile on M1 Mac Mini. No OOM crashes with 8GB RAM when running triage + one agent.

---

### Task 10.5: End-to-End Integration Tests

**Files to create:**
- `EpistemosTests/AgentIntegrationTests.swift`

**Tests:**
1. User message → Triage classifies → routes to correct agent → agent produces output
2. Agent-to-agent: Builder creates file → Librarian indexes it → searchable
3. Learning Pool: search query → web results → cited answer
4. Memory: agent conversation compacts → episodic memory saved → retrieved next session
5. Trust: Standard Builder tries to delete system file → denied

**Verification:** All integration tests pass.

---

### Task 10.6: App Store Submission Prep (Lite)

**What:**
- App Sandbox entitlements (network access, read-only user folder for notes)
- Privacy descriptions (microphone for voice cloning, location for weather widget)
- App Store Connect metadata, screenshots, description
- In Settings: "Some Builder features require Epistemos Pro" (no external links per Apple 3.1.1)

---

## Appendix A: File Creation Summary

### New Swift Files (32 files)

```
Epistemos/Engine/
  MLXEngine.swift
  MLXModelRegistry.swift
  MLXClient.swift
  MLXModelManager.swift
  ChatterboxTTSEngine.swift

Epistemos/Agents/
  AgentTypes.swift
  MessageBus.swift
  AgentEngine.swift
  TriageAgent.swift
  LibrarianAgent.swift
  WriterAgent.swift
  BuilderAgent.swift
  WorkingMemory.swift
  MemoryService.swift
  NPCController.swift
  NotificationService.swift
  WriterPresets.swift
  Tools/
    NoteTools.swift
    ToolExecutor.swift
  LearningPool/
    LearningPoolService.swift
    QueryClassifier.swift
    Researcher.swift
    AnswerWriter.swift
    BraveSearchService.swift
    WebFetchService.swift

Epistemos/Models/
  SDAgentThread.swift
  SDWriterPreset.swift

Epistemos/Views/Agents/
  AgentPanelView.swift
  AgentCardView.swift
  AgentThreadView.swift
  BuilderWorkspaceView.swift
  BuilderFileTreeView.swift
  BuilderEditorView.swift
  BuilderTerminalView.swift
  BuilderActivityLogView.swift
  WriterPresetPanel.swift
  ToolApprovalView.swift

Epistemos/Views/Settings/
  MLXSettingsView.swift
  VoiceSettingsView.swift
  TrustSettingsView.swift

Epistemos/Views/LearningPool/
  LearningPoolView.swift
  SearchResultView.swift

Epistemos/Resources/
  tts_daemon.py
```

### New Rust Crates (3 crates)

```
memory-engine/
  Cargo.toml
  src/lib.rs
  src/embeddings.rs
  src/vector_index.rs
  src/compaction.rs

tool-sandbox/
  Cargo.toml
  src/lib.rs
  src/file_ops.rs
  src/shell_exec.rs
  src/permissions.rs

learning-pool/
  Cargo.toml
  src/lib.rs
  src/web_search.rs
  src/scraper.rs
  src/chunker.rs
  src/rag.rs
```

### Modified Files (key modifications)

```
Epistemos/Engine/LLMService.swift — add MLX provider
Epistemos/App/AppBootstrap.swift — add all new services
Epistemos/App/AppEnvironment.swift — add all new environment keys
Epistemos/State/NoteChatState.swift — Writer agent awareness
Epistemos/Views/Notes/NotesSidebar.swift — Agent section + badges
Epistemos/Models/GraphTypes.swift — new node/edge types
graph-engine/src/types.rs — new NodeType/EdgeType variants
graph-engine/src/renderer.rs — NPC rendering
graph-engine/src/simulation.rs — territory physics
graph-engine-bridge/graph_engine.h — new FFI functions
```

### New Test Files (7 files)

```
EpistemosTests/MLXEngineTests.swift
EpistemosTests/MLXClientTests.swift
EpistemosTests/MLXModelRegistryTests.swift
EpistemosTests/MessageBusTests.swift
EpistemosTests/TriageAgentTests.swift
EpistemosTests/AgentEngineTests.swift
EpistemosTests/AgentIntegrationTests.swift
```

---

## Appendix B: External Dependencies

### Swift Package Manager (add to Xcode project)

| Package | URL | Version | Products Used |
|---|---|---|---|
| mlx-swift-lm | `https://github.com/ml-explore/mlx-swift-lm` | branch: main | MLXLMCommon, MLXLLM, MLXVLM |
| swift-transformers | `https://github.com/huggingface/swift-transformers` | from: 1.1.9 | Tokenizers |

### Rust Cargo (new workspace members)

| Crate | Key Deps |
|---|---|
| memory-engine | ndarray, serde, memmap2 |
| tool-sandbox | nix (shell exec), serde |
| learning-pool | reqwest, serde, serde_json |

### Python (bundled or user-installed)

| Package | Version | Purpose |
|---|---|---|
| chatterbox-tts | latest | TTS engine |
| torch | ≥2.6 | ML runtime |
| torchaudio | ≥2.6 | Audio I/O |
| transformers | ≥4.40 | Model loading |

### Models (downloaded on first use)

| Model | Size | Purpose |
|---|---|---|
| mlx-community/Qwen3.5-0.8B-MLX-4bit | ~700MB | Triage (always loaded) |
| mlx-community/Qwen3.5-2B-MLX-4bit | ~1.8GB | Librarian |
| mlx-community/Qwen3.5-4B-MLX-4bit | ~2.8GB | Writer/Builder |
| mlx-community/Qwen3.5-9B-MLX-4bit | ~5.6GB | Complex tasks (high-memory Macs) |
| ResembleAI/chatterbox-turbo | ~1.5GB | TTS |

---

## Appendix C: Key Research Paper Recommendations Applied

From `~/agent document.md` (Architectural Optimization for Swift-to-Rust Agentic Transitions):

| Paper Recommendation | How Applied |
|---|---|
| BoltFFI for high-performance FFI | Evaluate for memory-engine and tool-sandbox crates. Current graph-engine uses manual C ABI which works. BoltFFI would eliminate serialization overhead for high-frequency agent tool calls. |
| ReACT paradigm for agent loops | All agents use Reasoning → Action → Observation loop (Tasks 4.1, 5.1, 6.4) |
| `.multi_turn(n)` iteration limits | All agent loops have `maxIterations` cap (25 for Builder, 10 for Librarian, 6 for Writer) |
| Rust-native 5x memory reduction | Memory-engine, tool-sandbox, learning-pool all in Rust for efficiency |
| System 1 (fast) vs System 2 (complex) | Triage (0.8B, <100ms) = System 1. Cloud APIs = System 2. Routing by TriageAgent. |
| Quantization for edge inference | All MLX models use Q4 quantization (4-bit weights) |
| `impl Into<String>` for flexible APIs | Apply in Rust crate public APIs |
| `Cow<str>` over `.clone()` | Use in memory-engine hot paths |
| `#[must_use]` on Result returns | Apply to all Rust FFI functions returning Result |
| `// SAFETY:` contracts on unsafe | Already in CLAUDE.md rules — enforce in all new crates |
| Phased migration (PoC → core → alignment) | 10 phases, each builds on previous, each independently verifiable |
| Swift 6 strict concurrency | All agents are `@MainActor`, messages are `Sendable`, actors isolate state |
| Memory ownership: Rust allocates, Rust frees | `free_string`, `free_results` functions in every crate (same pattern as graph-engine) |
| Prompt hooks for human-in-the-loop | ToolApprovalView intercepts dangerous actions before Rust executes (Task 6.7) |

---

## Appendix D: Cross-Reference to Design Doc

| Design Doc Section | Implementation Phase | Key Tasks |
|---|---|---|
| §1 Vision | All phases | — |
| §2 Decision Record | — | Preserved for reference |
| §3 System Architecture | Phase 2 | Tasks 2.1-2.7 |
| §4 Model Provider Layer | Phase 1 | Tasks 1.1-1.8 |
| §5 The Four Agents | Phases 2, 4, 5, 6 | Tasks 2.4, 4.1, 5.1, 6.4 |
| §6 Agent Communication | Phase 2 | Task 2.2 |
| §7 Memory System | Phase 3 | Tasks 3.1-3.6 |
| §8 Learning Pool | Phase 7 | Tasks 7.1-7.4 |
| §9 Graph NPCs | Phase 8 | Tasks 8.1-8.5 |
| §10 Voice System | Phase 9 | Tasks 9.1-9.5 |
| §11 Trust Levels | Phase 6 | Tasks 6.1-6.3, 6.7 |
| §12 Notifications | Phase 10 | Task 10.2 |
| §13 Distribution | Phase 10 | Tasks 10.1, 10.6 |
| §14 Swift/Rust Split | All phases | Enforced throughout |
| §15 Source Repo Reference Map | All phases | Referenced in each task |
| §16 Competitive Analysis | — | Informs design choices |
| §17 Implementation Phases | This document | Expanded into detailed tasks |
