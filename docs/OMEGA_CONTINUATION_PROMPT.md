# OMEGA CONTINUATION PROMPT — Paste into new Claude Code session

> **Index status**: CANONICAL-OPERATIONAL — Continuation prompt for Omega agent/automation — context recovery + 22 Omega files + 2578 Rust tests.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



## CONTEXT RECOVERY

You are continuing work on **Epistemos Omega** — an agent/automation subsystem integrated into the Epistemos macOS knowledge management app. Multiple sessions have built the foundation. Your job is to **make it actually work end-to-end**.

**First action in every session:**
```bash
cat CLAUDE.md && cat docs/PROGRESS.md && cat docs/DECISIONS.md && cat docs/OMEGA_ARCHITECTURE.md
```

## WHAT EXISTS (DO NOT REBUILD)

### Rust Crates (2578 tests passing)
| Crate | Tests | Key Modules |
|-------|-------|-------------|
| `omega-mcp/` | 89 | dispatcher.rs, orchestrator.rs, osascript.rs, state.rs (FTS5), config.rs, recipe.rs, trace_logger.rs, dataset_formatter.rs, quality_filter.rs |
| `omega-ax/` | 10 | ax_tree.rs (real AXUIElement FFI), input.rs (CGEvent), permissions.rs (AXIsProcessTrusted), shortcuts.rs |
| `epistemos-core/` | 47 | vault_analyzer (MTLD, classifier, boilerplate filter, token estimator), auto_tuner, scheduler |
| `graph-engine/` | 2432 | DO NOT TOUCH — rendering, physics, search |

### Swift Files (22 Omega + 7 Views + 7 Test Suites)
```
Epistemos/Omega/
  Agents/OmegaAgent.swift          — Protocol + AgentStep + AgentStepResult + RiskLevel
  Agents/SafariAgent.swift         — Calls Rust toolOpenUrl/toolSearchWeb via UniFFI
  Agents/FileAgent.swift           — Vault-scoped file ops
  Agents/NotesAgent.swift          — STUB — returns acknowledgment, not real note ops
  Agents/TerminalAgent.swift       — Calls Rust toolRunCommand via UniFFI
  Agents/AutomationAgent.swift     — Calls omega-ax UniFFI (walkAxTreeJson, simulateClick)
  Orchestrator/OrchestratorState.swift  — Central @Observable, calls Rust heuristic planner
  Orchestrator/TaskGraph.swift          — Swift DAG (mirrors Rust TaskGraph)
  Orchestrator/ConfirmationGate.swift   — Risk-based gates
  Orchestrator/ResearchPause.swift      — Pause for user research
  Orchestrator/OmegaInferenceBridge.swift — Wraps TriageService for LLM planning
  Orchestrator/OmegaTrainingCoordinator.swift — Bridges to KF training
  Inference/ToolCallParser.swift        — 4 parse strategies (JSON, Qwen, array, code block)
  Inference/OmegaPlanningService.swift  — LLM plan generation + heuristic fallback
  Vision/ScreenCaptureService.swift     — Real ScreenCaptureKit (SCShareableContent)
  Vision/Screen2AXService.swift         — VLM fallback placeholder
  MCPBridge.swift                       — Creates MCPDispatcher, registers 19 tools at startup

Epistemos/Views/Omega/
  OmegaPanel.swift, TaskInputBar.swift, PlanReviewView.swift,
  ConfirmationSheet.swift, ResearchRequestView.swift,
  ExecutionProgressView.swift, ExecutionLogView.swift

Epistemos/Views/Settings/OmegaSettingsDetailView.swift
```

### Integration Points (already wired)
- `AppBootstrap.swift` — creates `orchestratorState` + `mcpBridge`, passes `triageService`
- `AppEnvironment.swift` — injects both into SwiftUI environment
- `BrandedTypes.swift` — `NavTab.omega` case
- `UtilityWindowManager.swift` — `.omega` panel with window chrome
- `EpistemosApp.swift` — Cmd+4 keyboard shortcut
- `RootView.swift` — Omega toolbar button on landing page
- `SettingsView.swift` — `.omega` section in settings sidebar

### Build Status
- `xcodebuild BUILD SUCCEEDED` (zero Omega errors)
- Pre-existing `SDWorkspace` bug was fixed (fetch-then-filter workaround)
- UniFFI bindings generated with `patch-uniffi-bindings.py` for Swift 6 concurrency compat

## WHAT IS BROKEN (FIX THESE)

### 1. Omega Fails on Most Tasks
**Root cause**: Without a local model loaded, LLM planning returns nothing. The heuristic fallback covers basic patterns but can't actually DO things because:
- `NotesAgent` is a stub — returns `{"status":"acknowledged"}` instead of creating real notes
- `FileAgent` requires vault URL which may be nil if no vault is attached
- `SafariAgent` calls Rust `toolOpenUrl()` which runs osascript — but may fail without Automation permission

**Fix**: Wire NotesAgent to real `VaultSyncService` and `ModelContainer`. When the user says "write me a summary", the agent should use `VaultSyncService.createPage()` to actually create a note. Read `Epistemos/Sync/VaultSyncService.swift` and `Epistemos/Models/SDPage.swift` first.

### 2. Execution Results Not Logged to SQLite
**Root cause**: Agents execute tools and return results, but `OrchestratorState.executePlan()` doesn't call `MCPBridge.logExecution()` after each step.

**Fix**: After each successful/failed step in `executePlan()`, call:
```swift
mcpBridge.logExecution(
    toolName: step.toolName,
    argumentsJson: step.argumentsJson,
    resultJson: result.outputJson,
    durationMs: result.durationMs,
    success: result.success
)
```
This requires `OrchestratorState` to have a reference to `MCPBridge`.

### 3. ConfirmationGate UI Doesn't Actually Block
**Root cause**: `ConfirmationGate.requestConfirmation()` uses a polling loop (`while pendingConfirmation != nil { sleep }`) which works but is fragile. The ConfirmationSheet view needs to be properly shown as a sheet/overlay.

**Fix**: The ConfirmationSheet already exists in OmegaPanel but the gate needs to use `AsyncStream` or `CheckedContinuation` instead of polling.

### 4. Planning Produces Wrong Agent/Tool Combinations
**Root cause**: The heuristic planner routes "write me a summary of my essay" to `notes.create_note` which is correct but the agent can't actually write content. With a loaded model, the LLM should generate a multi-step plan: (1) search notes for "all things must go", (2) read the matching note, (3) create a summary note.

**Fix**: Improve `OmegaPlanningService` to generate multi-step plans. The `OmegaInferenceBridge` prompt already includes agent/tool descriptions but needs better examples for the local model.

### 5. No Error Recovery UI
When a task fails, the user sees "Failed" but no way to retry, edit the plan, or understand what went wrong.

**Fix**: Add retry button, error detail expansion, and "Edit Plan" capability to OmegaPanel.

## ARCHITECTURE RULES (FROM MASTER PROMPT)

### Anti-Drift Anchor 1: 5-Layer Split
```
Layer 5 (Swift/SwiftUI): Views, UX
Layer 4 (Swift): MLX inference, OmegaInferenceBridge → TriageService
Layer 3 (Rust omega-mcp): Orchestrator, TaskGraph, agents, confirmation gate
Layer 2 (Rust omega-mcp): MCP dispatcher, tool registry, SQLite logging, recipes
Layer 1 (Rust omega-ax): AX tree, CGEvent, osascript, shortcuts, permissions
```

### Anti-Drift Anchor 5: Tool Rules
- ALL tool execution goes through Rust layer (osascript.rs, omega-ax FFI)
- Tools return structured `ToolResult { success, data_json, error, error_code, duration_ms }`
- Every invocation logged to SQLite via MCPDispatcher
- Agents NEVER call Process/osascript directly (violation of Anchor 1)

### Anti-Drift Anchor 6: Agent Rules
- Confidence >90% → auto-execute; 80-90% → log; <80% → escalate; <50% → refuse
- Max 3 retries with exponential backoff (0.2s base)
- Each agent limited to its declared toolset (Rust validates via `validate_agent_toolset`)

### Existing Patterns (from CLAUDE.md)
- `@MainActor @Observable` for all state — NEVER ObservableObject
- `withAppEnvironment(bootstrap)` for environment injection
- Swift Testing framework (`@Suite` + `@Test` + `#expect`) — NEVER XCTest
- `guard let` / `if let` — NEVER force unwrap
- `do/catch` — NEVER `try!`

## PRIORITY ORDER

1. **Wire NotesAgent to VaultSyncService** — make "create note" actually create a note
2. **Wire FileAgent to real vault URL** — make "list files" actually list files
3. **Add execution logging** — every tool call logged to omega-mcp SQLite
4. **Fix ConfirmationGate** — use continuation instead of polling
5. **Add error recovery UI** — retry button, error details, edit plan
6. **Improve LLM planning prompt** — better examples for multi-step plans
7. **Test recursively** — run the app, try tasks, fix failures, repeat

## KEY FILES TO READ FIRST

Before writing any code:
```bash
cat Epistemos/Sync/VaultSyncService.swift | head -100
cat Epistemos/Models/SDPage.swift | head -50
cat Epistemos/Omega/Orchestrator/OrchestratorState.swift
cat Epistemos/Omega/Agents/NotesAgent.swift
cat Epistemos/Omega/MCPBridge.swift
cat Epistemos/Views/Omega/OmegaPanel.swift
```

## VERIFICATION

After each fix:
```bash
# Rust tests
cd omega-mcp && cargo test && cd ../omega-ax && cargo test && cd ..

# Swift build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep "BUILD"

# Then manually test in the app:
# 1. Cmd+4 to open Omega
# 2. Type "list files in my vault" → should show actual files
# 3. Type "create a new note called Test" → should create a real note
# 4. Type "search the web for MLX benchmarks" → should open Safari
```

## GIT STATE

Branch: `feature/knowledge-fusion-v1`
Recent commits:
```
242a5bd CRITICAL: Agents now route through Rust Tool Layer (Anchors 1+5)
cee375a Move orchestrator to Rust per Anchor 1
2b880b9 Fix Omega routing: smarter heuristic, better error messaging
011d150 Omega end-to-end: LLM planning, MCPBridge tool registration
b115af4 Epistemos Omega: Agent system integration + all gap closures
```

All work is committed. No uncommitted changes.
