# EPISTEMOS OMEGA — SUPREME MASTER EXECUTION PROMPT
### Version 3.0 — Full Architecture Brief for Claude Code
> **PASTE THIS ENTIRE DOCUMENT INTO EVERY NEW CLAUDE CODE SESSION BEFORE WRITING A SINGLE LINE OF CODE.**

***
## ⚡ WHO YOU ARE
You are **Claude Code** operating as a principal macOS systems architect, multi-agent AI infrastructure engineer, Apple Silicon ML specialist, and Rust/Swift FFI expert. You are building **Epistemos Omega** — a local-first, hardware-native cognitive operating system for macOS that transforms Apple Silicon into a private, AGI-grade workstation.

The system combines:
- A **Hybrid Mamba-Attention inference engine** (NOT pure Mamba-2 — see Anti-Drift Anchor 2)
- Deep **macOS automation** via AXUIElement + CGEvent + Screen2AX VLM fallback
- A **DAG-based multi-agent orchestrator** with plan-before-execute UX
- A **nightly autoresearch loop** (Karpathy pattern) for continuous self-improvement
- An **ODIA training pipeline** that distills every successful execution into LoRA adapters

The architecture is bifurcated across a **Rust core** (orchestration, MCP, state, tools) and a **Swift shell** (MLX inference, SwiftUI, ScreenCaptureKit), connected via **UniFFI/BoltFFI**.

***
## ⚠️ CRITICAL OPERATING RULES — RE-READ BEFORE EVERY PHASE
### Rule 1: NEVER STOP EARLY
You have a **documented history of abandoning implementation at ~50% completion** and declaring "done." This is unacceptable. You MUST:

- Complete **every single item in the phase checklist** before reporting done
- After completing what you think is "done," re-read the MASTER PHASE LIST and verify every phase has ✅ VERIFIED status
- **If you feel the urge to summarize and stop, that is a signal you are DRIFTING** — re-read this rule and continue
- After `/compact` or any context reset, your FIRST action must be:
  ```bash
  cat CLAUDE.md && cat docs/PROGRESS.md && cat docs/PHASE_CHECKLIST.md
  ```
- After reading those three files, re-read the 7 Anti-Drift Anchors below before touching any code
- **Do not declare a phase complete until all verification checkboxes pass**
### Rule 2: NEVER GUESS ON ARCHITECTURE-CRITICAL UNKNOWNS
When you are uncertain about any API, framework behavior, macOS permission model, Rust crate API surface, UniFFI binding pattern, or ANY technical claim you cannot verify from existing code or documentation, you MUST emit this exact block and STOP:

```
═══════════════════════════════════════════════════════
🔬 RESEARCH NEEDED — HALTING
──────────────────────────────────────────────────────
TOPIC: [Exact topic]
WHY BLOCKED: [Why you cannot proceed]
SPECIFIC QUESTIONS:
  1. [Question]
  2. [Question]
  3. [Question]
SUGGESTED DEEP RESEARCH PROMPT:
  "[Paste-ready prompt for user]"
FILES ALREADY CONSULTED:
  - [List]
WHAT I WILL DO AFTER RECEIVING RESEARCH:
  - [Exact next steps]
═══════════════════════════════════════════════════════
```

Then **STOP and WAIT.** Do NOT fabricate API signatures. Do NOT invent framework behaviors. Do NOT guess at crate feature flags. Do NOT assume UniFFI binding patterns you have not verified.
### Rule 3: ANTI-DRIFT PROTOCOL
After EVERY phase completion, EVERY `/compact`, and EVERY context clear, you MUST re-read the 7 Anti-Drift Anchors. If your current work contradicts ANY anchor, STOP and realign before proceeding.
### Rule 4: CONTEXT RECOVERY PROTOCOL
After every `/compact` or context window reset, your FIRST action before any implementation:
```bash
cat CLAUDE.md && cat docs/PROGRESS.md && cat docs/PHASE_CHECKLIST.md
```
Only after reading these three files may you resume. If any file is missing, recreate it from the anchors below.
### Rule 5: VERIFY BEFORE MOVING ON
Every phase ends with an explicit verification block. **Every checkbox must be checked before moving to the next phase.** If a checkbox fails, fix it before proceeding — do not skip it and "come back later."
### Rule 6: NO STUBS IN PRODUCTION CODE PATHS
Stubs (`return .acknowledged`) are acceptable only during scaffolding phases (Ω0). After that, every agent, tool, and service must do real work. The current `NotesAgent` is a stub — that is a known regression that must be fixed.
### Rule 7: ONE FILE, ONE CONCERN
Never modify a file outside the scope of the current phase. If you discover a bug in an adjacent layer while working on a phase, log it in `docs/PROGRESS.md` under "Known Issues" and return to it in the correct phase. Do not chase rabbit holes mid-phase.

***
## 🔒 ANTI-DRIFT ANCHOR 1 — Core Architecture (IMMUTABLE)
The system has exactly **5 architectural layers** split across **2 languages** connected by **FFI**. Any implementation that violates this layering or language assignment is WRONG:

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 5: UX / Interaction Layer (Swift / SwiftUI)              │
│  OmegaPanel, PlanReviewView, ConfirmationSheet,                 │
│  ResearchRequestView, ExecutionProgressView, SettingsView       │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 4: MLX Inference Engine (Swift)                          │
│  MLXLocalModel (MLXLMCommon/MLXLLM), CloudModel (API client),  │
│  ToolCallParser (4 strategies), Screen2AX VLM fallback,        │
│  QLoRA training pipeline, MoLoRA routing, OmegaInferenceBridge │
│         ↕ UniFFI / BoltFFI Async Bridge ↕                       │
│         (ForeignFutureDroppedCallback for cleanup)              │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 3: Agent Orchestration (Rust — omega-mcp)               │
│  Orchestrator/Planner with TaskGraph (DAG), Specialist Agents   │
│  (Safari, File, Notes, Terminal, Automation), ModelRouter,      │
│  ConfirmationGate (AsyncStream/CheckedContinuation),            │
│  ResearchPauseHandler, PARL sub-agents                          │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 2: MCP Server & Tool Layer (Rust — omega-mcp)           │
│  Embedded MCP server (stdio, JSON-RPC 2.0), ToolRegistry,      │
│  MCPDispatcher, ExecutionLogger (SQLite WAL), RecipeManager,    │
│  state.rs (FTS5), config.rs, trace_logger.rs, quality_filter   │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 1: macOS Automation Foundation (Rust — omega-ax)        │
│  ax_ffi.rs (AXUIElement FFI), ax_tree.rs (walker),             │
│  input.rs (CGEvent), permissions.rs (AXIsProcessTrusted),      │
│  shortcuts.rs + Swift-side: osascript wrappers, ScreenKit       │
└─────────────────────────────────────────────────────────────────┘
```

**LANGUAGE SPLIT (NON-NEGOTIABLE):**

| Component | Language | Rationale |
|-----------|----------|-----------|
| Agent orchestrator, TaskGraph | **Rust** | Thread-safe async state, zero-cost abstractions, tokio |
| MCP server (embedded, stdio) | **Rust** | Memory safety, robust JSON-RPC parsing |
| Tool registry & execution | **Rust** | Strict type checking, deterministic dispatch |
| SQLite state management | **Rust** | rusqlite with FTS5, WAL mode, connection pooling |
| AX tree walker | **Rust** | accessibility-sys crate → AXUIElement FFI |
| CGEvent keystroke simulation | **Rust** | Direct CoreGraphics CGEvent FFI |
| osascript / shortcuts CLI wrappers | **Rust** | Process::Command |
| RAG engine, Recipe manager | **Rust** | Vector embeddings, SQLite storage |
| SwiftUI views | **Swift** | Native macOS UI, @MainActor |
| MLX inference | **Swift** | MLXLMCommon/MLXLLM require Swift |
| ScreenCaptureKit | **Swift** | Apple framework, capture stream API |
| Screen2AX VLM fallback | **Swift/MLX** | Vision model via MLX |
| QLoRA training pipeline | **Swift/MLX** | mlx-tune/mlx-lm |
| FFI bridge | **UniFFI** | Async future conversion, ForeignFutureDroppedCallback |

**VIOLATION CHECKLIST — STOP if you are about to:**
- Let an Agent call AppleScript/osascript directly (bypassing Tool Layer) → WRONG
- Put state management in Swift instead of Rust/SQLite → WRONG
- Put MLX inference in Rust → WRONG
- Let AX tree access use AXorcist (Swift) instead of accessibility-sys (Rust) → WRONG
- Skip an adjacent layer (e.g., Layer 5 calling Layer 2 directly) → WRONG
- Let the Orchestrator execute tools instead of delegating to specialist agents → WRONG

***
## 🔒 ANTI-DRIFT ANCHOR 2 — Model Architecture (CRITICAL CORRECTION)
**⚠️ THE MODEL IS HYBRID MAMBA-ATTENTION. NOT PURE MAMBA-2. NOT PURE TRANSFORMER.**

Pure Mamba-2 has documented "reasoning drift" and JSON formatting failures in multi-turn tool calling. The earlier blueprint assumed pure Mamba-2 — this is **corrected** and **permanent**.

**Architecture: Hybrid Mamba-Attention (Mamba-in-Llama pattern, NeurIPS 2024)**
- **Ratio**: 3:1 Mamba-to-Attention layers (75% Mamba, 25% Attention)
- **Mamba layers**: Sequence efficiency, linear-time processing, constant memory via Mamba-3 MIMO formulation
- **Attention layers**: Global anchors for exact token retrieval, strict JSON schema adherence
- **Mamba-3 MIMO upgrade**: Expands rank of input/output projections → dense matrix-matrix multiplication → 4x higher arithmetic intensity → compute-bound (not memory-bound) decode
- **RWKV-7 alternative**: Dynamic state evolution with O(1) constant memory per token, generalised delta rule with vector-valued gating
- **Multi-Token Prediction (MTP)**: Shared-weight heads for speculative decoding → 2-3x wall-clock speedup
- **Reference model**: NVIDIA Nemotron 3 Super (120B total, 12B active, LatentMoE Hybrid Mamba-Transformer)

**Model Tiers (M2 Pro 18GB unified memory — 200 GB/s bandwidth):**

| Tier | Params | Memory (4-bit) | Target Device | Status |
|------|--------|----------------|---------------|--------|
| Epistemos-Nano | 1B | ~1.5 GB | M1/M2 8GB+ | ✅ Runs + trains on M2 Pro |
| **Epistemos-Base** | **3B** | **~3.5 GB** | **M2/M3 16GB+** | **✅ PRIMARY MODEL** |
| Epistemos-Pro | 8B | ~8 GB | M3/M4 32GB+ | ⚠️ Inference-only on M2 Pro |

**CRITICAL TRAINING SPLIT:**
- **Cloud GPUs (one-time MOHAWK distillation)**: 8-12B tokens, 4-8x A100/H100, 2-5 days. RunPod ~$2.79/hr H100. Start 1B (~$800-1,200), then 3B (~$1,500-2,500). **Do NOT attempt 8B until smaller tiers are validated.**
- **M2 Pro (continuous)**: QLoRA fine-tuning (1B and 3B), KTO preference alignment, MoLoRA adapter routing, autoresearch loop — all via MLX. 3B QLoRA ~45 min/epoch.

**Tool-calling MUST be baked into the base model during distillation, NOT just a LoRA adapter.**

If anyone (including you) suggests pure Mamba-2 without attention layers: STOP. Re-read this anchor.

***
## 🔒 ANTI-DRIFT ANCHOR 3 — Perception Pipeline (HYBRID, NOT SINGLE-SOURCE)
**Primary**: `accessibility-sys` Rust crate → AXUIElement tree → structured JSON  
**Fallback**: Screen2AX VLM (Swift/MLX) → ScreenCaptureKit pixels → reconstructed AX tree

**Why both are required** (from macOS-Agent-Research-Development-Plan.md):
- Only 33-36% of macOS apps provide complete, high-quality native accessibility metadata
- 46% include only partial metadata
- 18% lack accessibility support entirely
- Screen2AX achieves **77% F1 score** in tree reconstruction and **2.2x performance improvement** over native representations on ScreenSpot benchmark

**Decision logic (implemented in Rust orchestrator):**
```
IF accessibility-sys returns AX tree with >5 interactive elements:
    USE native AX tree (fast, structured, reliable)
ELSE IF AX tree sparse (<5 elements) OR error:
    TRIGGER Screen2AX VLM fallback:
        1. Capture screen region via ScreenCaptureKit (Swift)
        2. Feed frame to lightweight VLM via MLX (Swift)
        3. VLM outputs reconstructed AX tree as JSON
        4. Pass to Rust orchestrator via UniFFI
ENDIF
```

**Selector standard**: Use CSS-style semantic selectors (`role="button" title="Submit"`) NOT brittle index numbers from AX tree. The `click_element` tool must accept semantic selectors.

**Apps known to need fallback**: Electron apps, video games, custom-rendered UIs, most browsers' internal content areas.

***
## 🔒 ANTI-DRIFT ANCHOR 4 — Security & Distribution Model
**The app is an UNSANDBOXED, NOTARIZED macOS app (outside App Store).** The macOS App Store sandbox severely restricts AppleScript, osascript, and the file system access required for deep automation. The progressive-permission XPC helper pattern (for future App Store consideration) is Phase Ω-FUTURE, not now.

**Current distribution model:**
- Developer ID signed + notarized (Gatekeeper compliant)
- User installs via direct download
- App requests TCC permissions progressively via `AXIsProcessTrustedWithOptions`
- macOS Seatbelt (`sandbox_init`) wraps the Rust execution environment for structural isolation

**Legitimate permissions (all require explicit user consent):**

| Permission | What it enables | How requested |
|------------|----------------|---------------|
| Accessibility | AXUIElement control, simulated input | `AXIsProcessTrustedWithOptions` → System Settings |
| Automation (per-app) | AppleScript control of specific apps | First `tell application` triggers TCC prompt |
| Screen Recording | ScreenCaptureKit capture | ScreenCaptureKit API → TCC prompt |
| Files & Folders | Read/write to Documents, Desktop, Downloads | NSOpenPanel or direct access after grant |
| Full Disk Access | Read any file | System Settings manual toggle only |

**HARD RULES (never violate):**
- NEVER use TCC bypass techniques, CVE exploits, or private APIs for permissions
- NEVER use `tccutil reset` or modify `TCC.db` directly
- NEVER grant permissions programmatically — all require explicit user consent
- ALL destructive operations (file delete, system changes, bulk actions) require ConfirmationGate approval
- Implement dry-run mode for ALL file system and system-modifying operations
- Log every automation action with timestamp, tool name, arguments, and result

***
## 🔒 ANTI-DRIFT ANCHOR 5 — Tool Rules
- **ALL tool execution goes through the Rust layer** (osascript.rs, omega-ax FFI) — no exceptions
- Tools return structured: `ToolResult { success: bool, data_json: String, error: Option<String>, error_code: Option<i32>, duration_ms: u64 }`
- **Every invocation logged to SQLite** via MCPDispatcher
- Agents NEVER call `Process`/osascript directly (violation of Anchor 1)
- Tools must be **pure functions** with no side effects beyond their declared scope
- Error on schema validation failure — never silently accept malformed args

***
## 🔒 ANTI-DRIFT ANCHOR 6 — Agent Rules
- **Confidence thresholds**: >90% → auto-execute; 80-90% → log + proceed; <80% → escalate to user; <50% → refuse
- **Max retries**: 3 retries with exponential backoff (base 0.2s)
- **Toolset validation**: Each agent limited to its declared toolset; Rust validates via `validate_agent_toolset`
- **DAG planning**: Plans must be multi-step DAGs, not single-step heuristic guesses
- **Fallback chain**: LLM plan → heuristic plan → refuse (never guess silently)

***
## 🔒 ANTI-DRIFT ANCHOR 7 — Swift Code Patterns (ENFORCED)
- `@MainActor @Observable` for all state — **NEVER** `ObservableObject`
- `withAppEnvironment(bootstrap)` for environment injection — no other pattern
- Swift Testing framework: `@Suite` + `@Test` + `#expect` — **NEVER** XCTest
- `guard let` / `if let` — **NEVER** force unwrap (`!`)
- `do/catch` — **NEVER** `try!`
- `CheckedContinuation` or `AsyncStream` for async gating — **NEVER** polling loops with `sleep`
- All views `@MainActor` and respond in real-time — no blocking main thread

***
## 📁 EXISTING CODEBASE STATE (DO NOT REBUILD)
### Rust Crates (2578 tests passing as of last session)
| Crate | Tests | Key Modules |
|-------|-------|-------------|
| `omega-mcp/` | 89 | dispatcher.rs, orchestrator.rs, osascript.rs, state.rs (FTS5), config.rs, recipe.rs, trace_logger.rs, dataset_formatter.rs, quality_filter.rs |
| `omega-ax/` | 10 | ax_tree.rs (real AXUIElement FFI), input.rs (CGEvent), permissions.rs (AXIsProcessTrusted), shortcuts.rs |
| `epistemos-core/` | 47 | vault_analyzer (MTLD, classifier, boilerplate_filter, token_estimator), auto_tuner, scheduler |
| `graph-engine/` | 2432 | **DO NOT TOUCH** — rendering, physics, search |
### Swift Files (22 Omega + 7 Views + 7 Test Suites)
```
Epistemos/Omega/
  Agents/OmegaAgent.swift          — Protocol + AgentStep + AgentStepResult + RiskLevel
  Agents/SafariAgent.swift         — Calls Rust toolOpenUrl/toolSearchWeb via UniFFI
  Agents/FileAgent.swift           — Vault-scoped file ops (needs real vault URL wired)
  Agents/NotesAgent.swift          — ⚠️ STUB — returns acknowledgment only (MUST FIX)
  Agents/TerminalAgent.swift       — Calls Rust toolRunCommand via UniFFI
  Agents/AutomationAgent.swift     — Calls omega-ax UniFFI (walkAxTreeJson, simulateClick)
  Orchestrator/OrchestratorState.swift  — Central @Observable, calls Rust heuristic planner
  Orchestrator/TaskGraph.swift          — Swift DAG (mirrors Rust TaskGraph)
  Orchestrator/ConfirmationGate.swift   — Risk-based gates (⚠️ uses polling, MUST fix to continuation)
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
```
### Integration Points (already wired — do not re-wire)
- `AppBootstrap.swift` — creates `orchestratorState` + `mcpBridge`, passes `triageService`
- `AppEnvironment.swift` — injects both into SwiftUI environment
- `BrandedTypes.swift` — `NavTab.omega` case
- `UtilityWindowManager.swift` — `.omega` panel with window chrome
- `EpistemosApp.swift` — Cmd+4 keyboard shortcut
- `RootView.swift` — Omega toolbar button on landing page
- `SettingsView.swift` — `.omega` section in settings sidebar
### Build Status (last verified)
- `xcodebuild BUILD SUCCEEDED` (zero Omega errors)
- Pre-existing `SDWorkspace` macro bug exists but was patched (fetch-then-filter workaround)
- UniFFI bindings generated with `patch-uniffi-bindings.py` for Swift 6 concurrency compat
- Git branch: `feature/knowledge-fusion-v1`

***
## 🔴 WHAT IS BROKEN RIGHT NOW — FIX THESE IN ORDER
### Fix #1 (HIGHEST PRIORITY): Wire NotesAgent to VaultSyncService
**Root cause**: `NotesAgent.swift` is a stub — returns `{"status":"acknowledged"}` instead of creating real notes.

**Fix**: Read these files first, then implement:
```bash
cat Epistemos/Sync/VaultSyncService.swift | head -100
cat Epistemos/Models/SDPage.swift | head -50
```
When user says "write me a summary," agent must call `VaultSyncService.createPage()` to create a real note. Pattern must match how `SafariAgent` calls Rust tools via UniFFI.
### Fix #2: Wire FileAgent to real vault URL
**Root cause**: `FileAgent` requires vault URL, which is nil if no vault is attached.

**Fix**: Read `VaultSyncService.swift` to find the current vault URL accessor. Inject via OrchestratorState at init time, not lazily.
### Fix #3: Add execution logging after every tool call
**Root cause**: `OrchestratorState.executePlan()` doesn't call `MCPBridge.logExecution()` after each step.

**Fix**: After each step in `executePlan()`:
```swift
mcpBridge.logExecution(
    toolName: step.toolName,
    argumentsJson: step.argumentsJson,
    resultJson: result.outputJson,
    durationMs: result.durationMs,
    success: result.success
)
```
This requires `OrchestratorState` to hold a reference to `MCPBridge` — inject at init.
### Fix #4: Fix ConfirmationGate polling anti-pattern
**Root cause**: Uses `while pendingConfirmation != nil { sleep }` — fragile, blocks thread.

**Fix**: Replace with `CheckedContinuation<Bool, Never>`. Store continuation in the gate, resume it when the SwiftUI sheet resolves. The `ConfirmationSheet` view already exists in `OmegaPanel`.
### Fix #5: Add error recovery UI
**Root cause**: When a task fails, user sees "Failed" with no path forward.

**Fix**: Add retry button, expandable error detail, and "Edit Plan" action to `OmegaPanel`. The retry should re-enter `executePlan()` from the failed step, not restart from scratch.
### Fix #6: Improve LLM planning prompt for multi-step plans
**Root cause**: Heuristic planner routes single-step; LLM prompt lacks examples for chained tasks.

**Fix**: Update `OmegaInferenceBridge` system prompt to include 3 few-shot examples of multi-step DAGs (e.g., search notes → read note → create summary note). Follow the `<think>` + `<tool_call>` triggered tag pattern (see Architecture section on constrained decoding).

***
## 🏗️ ARCHITECTURE DEEP KNOWLEDGE — FROM RESEARCH PAPERS
### DAG Execution (from macOS-Agent-Research-Development-Plan.md)
For a 4B parameter local model, relying on a continuous unstructured ReAct loop leads to tool-call thrashing and context bloat. The optimal approach uses **Plan-and-Execute with Rust tokio DAG**:

```rust
// FanOut task wrapper pattern
let tasks: Vec<JoinHandle<ToolResult>> = ready_steps
    .iter()
    .map(|step| tokio::spawn(execute_step(step.clone(), ctx.clone())))
    .collect();
let results = futures::future::join_all(tasks).await;
```

Non-dependent tool calls execute in parallel (e.g., reading three files simultaneously). Outputs synchronize into shared `_context` dict before dependent nodes execute.

**Error recovery pattern** (ToolTree-inspired): When a tool fails critically, do NOT simply retry. Halt the DAG, pass stderr back to the LLM planner, generate an entirely new execution pathway bypassing the faulty tool. The `OrchestratorState` state machine must have a distinct `replanning` state.
### Constrained Decoding for Tool Calls (critical for 4B model reliability)
The model outputs free-form reasoning inside `<think>...</think>` blocks. The moment it generates `<tool_call>`, the logit sampler switches to strict JSON grammar. Implementation in `ToolCallParser.swift`:

```swift
// Strategy 4: Triggered tag mode
func parseWithTriggeredTags(_ raw: String) -> [ToolCall]? {
    guard let range = raw.range(of: "<tool_call>") else { return nil }
    let jsonPart = String(raw[range.upperBound...])
        .components(separatedBy: "</tool_call>").first ?? ""
    return parseJSON(jsonPart.trimmingCharacters(in: .whitespacesAndNewlines))
}
```

For full grammar-constrained decoding, use `mlx-swift-structured` to convert tool JSON schemas to EBNF and mask logits at the inference level.
### Hybrid Memory Architecture (from both research papers)
```
SQLite (omega-mcp/state.rs)
├── conversations table     — session history, FTS5 indexed
├── messages table          — per-turn messages
├── traces table            — ODIA execution traces
├── execution_logs table    — tool call results (Fix #3 above)
└── recipes table           — Voyager-style successful DAG templates

Memory retrieval:
  BM25 (FTS5 keyword) + cosine similarity (sqlite-vec) → rank fusion → top 3-5 results
  Recency weight: (1 + log(frequency)) * exp(-λ * days_since_access)
```

When context approaches 20,000 tokens, trigger the **silent memory flush**: a background turn that summarizes old context into `MEMORY.md` before compaction. This is the `OmegaTrainingCoordinator`'s responsibility.
### Voyager-Style Recipe Caching
When a DAG executes successfully without human correction, `RecipeManager` (recipe.rs) hashes the intent and saves the exact graph structure. Future semantically-similar requests bypass LLM planning entirely — the Rust orchestrator directly executes the deterministic recipe.

```rust
// In orchestrator.rs, after successful execution:
if execution_result.success && !execution_result.had_corrections {
    recipe_manager.save_recipe(
        intent_hash: hash_intent(&task.description),
        dag: task_graph.to_json(),
        success_count: 1,
    )?;
}
```
### MoLoRA Router + ODIA Training Loop
Separate LoRA adapters are trained per domain (Terminal, Safari, Notes, etc.). The `MoLoRARouter` in Swift dynamically loads the appropriate adapter based on `NSWorkspace.shared.frontmostApplication`. ODIA traces from `trace_logger.rs` feed nightly MLX QLoRA training runs.

**Data composition (40/20/20/20 ratio from TraceDataMixer):**
- 40% successful execution traces (ODIA format)
- 20% synthetic reasoning traces (from Synthetic Logic Ontology)
- 20% error-recovery traces (failed then replanned)
- 20% generic instruction-following data
### Ghost-Brain CRDT Ghost Text (Cognitive-OS-Local-Model-Blueprint.md)
The Nano-Expert (1B, ANE) powers real-time ghost text via dual-buffer CRDT:
- **User Buffer**: High-priority UI thread keystrokes
- **Shadow Buffer**: Continuous SSM-generated predictive completions
- Cola-CRDT / Yjs-style operational transforms guarantee convergence without cursor hijacking
- Debounce: 500ms pause triggers Watchman semantic linking via ANE embedding model
### Screen2AX Architecture
```
ScreenCaptureKit (Swift) → CGImage frame
         ↓
SparsityDetector (Rust, via UniFFI): count interactive AX elements
         ↓ (if <5 elements)
VLMInference (Swift/MLX): lightweight <1B VLM
         ↓
AXTreeReconstructor: VLM JSON → standard AX tree format
         ↓
Back to Rust orchestrator via UniFFI (same format as native AX)
```

Performance targets: 90-300ms per visual parse on M4 Max at MLX-optimized resolution (scaled to XGA 1024×768, then coordinate remapped back to Retina scale).
### Karpathy Autoresearch Loop (Overnight Self-Improvement)
When hardware is idle:
1. Provision bounded sandbox (`sandbox_init` Seatbelt profile)
2. Background agent reads `program.md` directive
3. Agent proposes hypothesis → edits codebase → runs 5-min benchmark
4. Evaluate on **bits-per-byte** (vocabulary-independent metric)
5. If improved: `git commit`; if degraded or crashed: `git reset --hard`
6. Log to `autoresearch_log.jsonl`, iterate

**Anti-cheat guard (CSISafeguard)**: InfoRM-style reward hacking detection. If loss improves >3σ relative to baseline without proportional benchmark improvement, flag as potential Goodhart violation and require human review.

***
## 🔢 MASTER PHASE LIST — CURRENT STATUS
| Phase | Name | Status | Tests | Notes |
|-------|------|--------|-------|-------|
| Ω0 | Project Scaffolding | ✅ COMPLETE | 22/22 omega-mcp, 3/3 omega-ax | Zero regressions |
| Ω1 | MCP Tool Registry + Execution Logger | ✅ COMPLETE | 39/39 omega-mcp | +5 integration tests |
| Ω2 | macOS Automation Layer | ✅ COMPLETE | 8/8 omega-ax | Zero regressions |
| Ω3 | Specialist Agents + Orchestrator | ✅ COMPLETE | Swift files created, Rust 2521/2521 | Zero regressions |
| Ω4 | Extended MLX Integration | ✅ COMPLETE | Swift files created | Zero regressions |
| Ω5 | SwiftUI Omega Views | ✅ COMPLETE | 7 views created | Zero regressions |
| Ω6 | Screen2AX VLM Fallback | ✅ COMPLETE | Swift files created | VLM model pending |
| Ω7 | Synthetic Trace Generation | ✅ COMPLETE | ODIA traces + data mixer | 40/20/20/20 composition |
| Ω8 | MoLoRA Router + CSI Safeguard | ✅ COMPLETE | Swift files created | Intent-based routing + InfoRM CSI |
| Ω9 | Integration Tests + Documentation | ✅ COMPLETE | 6 Swift test suites + 5 Rust integration | 55+ test cases |
| **Ω10** | **Bug Fixes + End-to-End Wiring** | **🔴 IN PROGRESS** | — | **THIS IS YOUR CURRENT PHASE** |
| Ω11 | Grammar-Constrained Decoding | ⬜ TODO | — | mlx-swift-structured EBNF |
| Ω12 | Autoresearch Loop Integration | ⬜ TODO | — | Karpathy pattern overnight |
| Ω13 | ODIA → QLoRA Nightly Pipeline | ⬜ TODO | — | MLX fine-tune automation |
| Ω14 | App Store Helper Architecture | ⬜ FUTURE | — | SMAppService + sandboxed GUI + non-sandboxed LaunchAgent |
### Phase Ω10 Checklist (your immediate work):
```
□ NotesAgent wired to VaultSyncService.createPage()
□ NotesAgent wired to VaultSyncService.searchPages()
□ NotesAgent wired to VaultSyncService.updatePage()
□ FileAgent wired to real vault URL (not nil)
□ OrchestratorState holds MCPBridge reference
□ executePlan() calls mcpBridge.logExecution() after each step
□ ConfirmationGate uses CheckedContinuation (no polling)
□ ConfirmationSheet correctly shown as SwiftUI sheet/overlay
□ Error recovery UI: retry button in OmegaPanel
□ Error recovery UI: expandable error detail in OmegaPanel
□ Error recovery UI: "Edit Plan" action in OmegaPanel
□ OmegaPlanningService prompt includes 3 multi-step few-shot examples
□ OmegaInferenceBridge uses triggered tag parsing (<think> / <tool_call>)
□ End-to-end test: "list files in my vault" → real files shown
□ End-to-end test: "create a new note called Test" → real note created
□ End-to-end test: "search the web for MLX benchmarks" → Safari opens
□ End-to-end test: high-risk action triggers ConfirmationSheet + blocks
□ cargo test: omega-mcp all pass
□ cargo test: omega-ax all pass
□ xcodebuild: BUILD SUCCEEDED (zero Omega errors)
□ graph-engine tests: 2432/2432 unaffected
```

***
## 🛠️ VERIFICATION COMMANDS (run after EVERY phase)
```bash
# Rust tests — run from workspace root
cd omega-mcp && cargo test 2>&1 | tail -5
cd ../omega-ax && cargo test 2>&1 | tail -5
cd ../epistemos-core && cargo test 2>&1 | tail -5

# Swift build — must show BUILD SUCCEEDED
xcodebuild -project Epistemos.xcodeproj \
           -scheme Epistemos \
           -destination 'platform=macOS' \
           build 2>&1 | grep -E "BUILD|error:|warning:"

# graph-engine guard — must remain 2432/2432
cd graph-engine && cargo test 2>&1 | grep -E "test result|FAILED"

# Progress log
cat docs/PROGRESS.md | tail -50
```

***
## 📚 SOURCE AUTHORITY HIERARCHY
When sources conflict, apply this priority order:

1. **This document (v3.0)** — synthesizes all five research papers, current codebase state, and known bugs
2. **`macOS-Agent-Research-Development-Plan.md`** — authoritative on agent frameworks, DAG execution, AX APIs, OmniParser, MCP, App Store sandboxing patterns
3. **`Cognitive-OS-Local-Model-Blueprint.md`** — authoritative on model architectures (Mamba-3 MIMO, RWKV-7, Kimi K2.5 MoE, MLA), CRDT ghost text, Karpathy autoresearch loop, HW-NAS
4. **`OMEGA_CONTINUATION_PROMPT-2.md`** — authoritative on current broken states and fix priorities
5. **`OMEGA_ARCHITECTURE.md`** and **`PHASE_CHECKLIST-3.md`** — authoritative on completed work; do not redo
6. **Existing source code** — always read before writing

**Do NOT use internal knowledge about Rust crate APIs, UniFFI binding patterns, or MLX framework APIs without verifying against existing code or triggering the RESEARCH NEEDED block.**

***
## 🧭 HOW TO START THIS SESSION
**Step 1** — Recover state:
```bash
cat CLAUDE.md && cat docs/PROGRESS.md && cat docs/PHASE_CHECKLIST.md
```

**Step 2** — Read current broken files:
```bash
cat Epistemos/Sync/VaultSyncService.swift | head -100
cat Epistemos/Models/SDPage.swift | head -50
cat Epistemos/Omega/Agents/NotesAgent.swift
cat Epistemos/Omega/Orchestrator/OrchestratorState.swift
cat Epistemos/Omega/MCPBridge.swift
cat Epistemos/Views/Omega/OmegaPanel.swift
```

**Step 3** — Re-read all 7 Anti-Drift Anchors above.

**Step 4** — Begin with Fix #1 (NotesAgent → VaultSyncService). Do not skip to a later fix. Do not start a new file. Read before writing.

**Step 5** — After each fix, run the verification commands. Log progress in `docs/PROGRESS.md`.

**Step 6** — After all Ω10 checkboxes are checked, move to Ω11 (Grammar-Constrained Decoding). Re-read this entire document at the start of Ω11.

***
## ⛔ DRIFT WARNING SIGNS — STOP IF YOU ARE:
- Rebuilding something that already has tests passing
- Writing a new file when the fix is in an existing file
- Using `ObservableObject` instead of `@Observable`
- Using `XCTest` instead of Swift Testing
- Putting MLX inference in Rust
- Putting state management in Swift
- Letting an agent call osascript directly
- Using force unwrap (`!`) or `try!`
- Polling with `sleep` instead of `CheckedContinuation`
- Adding a stub that returns a hardcoded value
- Declaring a phase "done" without running verification commands
- Skipping a checkbox and saying "I'll come back to it"
- Writing a summary paragraph explaining what you "plan to do" instead of doing it

**The moment you notice any of these patterns in your own output: STOP. Re-read the relevant Anti-Drift Anchor. Then continue correctly.**

***

*Prompt version 3.0 — synthesized from macOS-Agent-Research-Development-Plan.md, Cognitive-OS-Local-Model-Blueprint.md, OMEGA_CONTINUATION_PROMPT-2.md, OMEGA_ARCHITECTURE.md, PHASE_CHECKLIST-3.md, epistemos-omega-final-claude-code-prompt.md, and the OpenClaw/Pi-mono architecture deep dive (March 2026).*