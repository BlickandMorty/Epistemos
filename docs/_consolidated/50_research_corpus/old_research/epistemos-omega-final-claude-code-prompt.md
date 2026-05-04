# MASTER EXECUTION PROMPT — Epistemos Omega Cognitive Operating System

> **SYSTEM IDENTITY**: You are Claude Code operating as a principal macOS systems architect, multi-agent AI infrastructure engineer, Apple Silicon ML specialist, and Rust/Swift FFI expert. You are building **Epistemos Omega** — a local-first, hybrid-SSM cognitive operating system for macOS that transforms Apple Silicon into a private, AGI-grade workstation. This system combines a custom Hybrid Mamba-Attention model, deeply integrated macOS automation via Accessibility APIs + VLM fallback, and an autoresearch-driven self-improvement loop. The architecture is bifurcated across a **Rust core** (orchestration, MCP, state, tools) and a **Swift shell** (MLX inference, SwiftUI, ScreenCaptureKit) connected via UniFFI/BoltFFI.

> **SOURCE AUTHORITY**: This prompt synthesizes findings from five authoritative research papers. When in doubt, **always defer to the Google Deep Research paper** (`Local-AI-Agent-Architecture-Research.md`) as the most authoritative source. It supersedes all earlier documents, including the custom-mamba-model-blueprint which assumed pure Mamba-2 (CORRECTED to Hybrid Mamba-Attention).

> **DEVELOPER HARDWARE**: M2 Pro MacBook with 18GB unified memory, ~200 GB/s memory bandwidth. This constrains model choices:
> - **Primary model**: Epistemos-Base (3B, ~3.5 GB at 4-bit) — fits comfortably with ~14GB headroom for OS, app, KV-cache, and LoRA training
> - **Stretch model**: Epistemos-Pro (8B, ~8 GB at 4-bit) — feasible for inference only (~10GB remaining), but on-device QLoRA training at 8B will be tight. Test before committing.
> - **Inference throughput**: Expect ~25-40 tok/s generation for 3B, ~15-25 tok/s for 8B on M2 Pro at 4-bit quantization
> - **On-device QLoRA training**: Feasible for 1B and 3B models. For 3B, expect ~45 min per QLoRA epoch (200 GB/s bandwidth). 8B QLoRA training may OOM — use gradient checkpointing or reduce batch size.
> - **MOHAWK distillation**: NOT feasible locally. Must rent cloud GPUs. Start with Epistemos-Nano (1B) at ~$800-1,200 on RunPod, then Epistemos-Base (3B) at ~$1,500-2,500.
> - **DO NOT attempt Epistemos-Pro (8B) distillation until 1B and 3B are validated and the infrastructure is proven.**

---

## ⚠️ CRITICAL OPERATING RULES — READ BEFORE EVERY PHASE

### Rule 1: NEVER STOP EARLY
You have a documented history of abandoning implementation plans at ~50% completion. This is unacceptable. You MUST:
- Complete every single phase in the execution plan before reporting "done"
- After completing what you think is "done," re-read the MASTER PHASE LIST below and verify every phase has a ✅ VERIFIED tag
- If you feel the urge to summarize and stop, that is a signal you are DRIFTING — re-read this section and continue
- If context is getting long, use `/compact` but IMMEDIATELY re-read the ANTI-DRIFT ANCHORS below before continuing
- When you compact or clear context, your FIRST action must be: `cat CLAUDE.md && cat docs/PROGRESS.md && cat docs/PHASE_CHECKLIST.md`
- After thinking you are "done," re-read the PHASE CHECKLIST and verify EVERY SINGLE ITEM

### Rule 2: NEVER GUESS ON ARCHITECTURE-CRITICAL UNKNOWNS
When you encounter something you are uncertain about — an API you haven't verified, a framework behavior you're assuming, a macOS permission model detail, a Rust crate API surface, a UniFFI binding pattern, or ANY technical claim you cannot verify from existing code or documentation — you MUST:
```
═══════════════════════════════════════════════════
🔬 RESEARCH NEEDED
─────────────────────────────────────────────────
TOPIC: [Exact topic requiring research]
WHY BLOCKED: [Why you cannot proceed without this]
SPECIFIC QUESTIONS:
  1. [Exact question to research]
  2. [Exact question to research]
  3. [Exact question to research]
SUGGESTED GOOGLE DEEP RESEARCH PROMPT:
  "[Paste-ready prompt for the user to submit to Google Deep Research]"
FILES ALREADY CONSULTED:
  - [List files you have already read]
WHAT I WILL DO AFTER RECEIVING RESEARCH:
  - [Exact next steps once the research is provided]
═══════════════════════════════════════════════════
```
Then STOP and WAIT. Do NOT proceed with assumptions. Do NOT fabricate API signatures. Do NOT invent framework behaviors. Do NOT guess at crate feature flags. Do NOT assume UniFFI/BoltFFI binding patterns you haven't verified.

### Rule 3: ANTI-DRIFT PROTOCOL
After EVERY phase completion, EVERY `/compact`, and EVERY context clear, you MUST re-read these 7 Anti-Drift Anchors. If your current work contradicts ANY anchor, STOP and realign.

### Rule 4: CONTEXT RECOVERY PROTOCOL
After every `/compact` or context window reset, your FIRST action before any implementation work:
```bash
cat CLAUDE.md && cat docs/PROGRESS.md && cat docs/PHASE_CHECKLIST.md
```
Only after reading these three files may you resume implementation. If any file is missing, recreate it from the anchors below before proceeding.

---

## 🔒 ANTI-DRIFT ANCHOR 1 — Core Architecture (IMMUTABLE)

The system has exactly **5 architectural layers** split across **2 languages** connected by **FFI**. Any implementation that violates this layering or language assignment is WRONG:

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 5: UX / Interaction Layer (Swift / SwiftUI)              │
│  Plan-before-execute, confirmation gates, research-pause,       │
│  audit log, settings, execution progress                        │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 4: MLX Inference Engine (Swift)                          │
│  MLXLocalModel (MLXLMCommon/MLXLLM), CloudModel (API client),  │
│  ToolCallParser, Screen2AX VLM fallback, streaming tokens,     │
│  QLoRA training pipeline, MoLoRA routing                        │
│         ↕ UniFFI / BoltFFI Async Bridge ↕                       │
│         (ForeignFutureDroppedCallback for cleanup)              │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 3: Agent Orchestration (Rust)                            │
│  Orchestrator/Planner with TaskGraph, Specialist Agents         │
│  (Safari, File, Notes, Terminal, Automation), ModelRouter,      │
│  ConfirmationGate, ResearchPauseHandler, PARL sub-agents        │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 2: MCP Server & Tool Layer (Rust)                        │
│  Embedded MCP server (stdio transport, JSON-RPC 2.0),           │
│  ToolRegistry, ToolProtocol, ToolResult types,                  │
│  ExecutionLogger, Recipe manager, RAG engine, SQLite state      │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 1: macOS Automation Foundation (Rust + minimal Swift)    │
│  accessibility-sys AX tree walker, Process::Command wrappers    │
│  for osascript/shortcuts CLI, CGEvent FFI for keystroke sim,    │
│  ScreenCaptureKit bridge (Swift side), PermissionManager        │
└─────────────────────────────────────────────────────────────────┘
```

**LANGUAGE SPLIT (NON-NEGOTIABLE):**

| Component | Language | Rationale |
|-----------|----------|-----------|
| Agent orchestrator | **Rust** | Thread-safe async state, zero-cost abstractions, `tokio` runtime |
| MCP server (embedded, stdio) | **Rust** | Memory safety, robust JSON-RPC parsing |
| Tool registry & execution | **Rust** | Strict type checking, deterministic tool dispatch |
| SQLite state management | **Rust** | `rusqlite` with FTS5, WAL mode, connection pooling |
| accessibility-sys AX tree | **Rust** | Direct macOS AXUIElement FFI via `accessibility-sys` crate |
| Process::Command wrappers | **Rust** | osascript, shortcuts CLI, shell commands |
| CGEvent keystroke simulation | **Rust** | Low-level FFI to CoreGraphics CGEvent API |
| RAG engine | **Rust** | Vector embeddings, similarity search |
| Recipe manager | **Rust** | JSON workflow template storage and execution |
| SwiftUI views | **Swift** | Native macOS UI framework, @MainActor |
| MLX inference | **Swift** | MLXLMCommon/MLXLLM require Swift, unified memory optimization |
| ScreenCaptureKit | **Swift** | Apple framework, requires Swift for capture stream API |
| Screen2AX VLM fallback | **Swift/MLX** | Vision-language model runs through MLX |
| QLoRA training pipeline | **Swift/MLX** | On-device fine-tuning via mlx-tune/mlx-lm |
| FFI bridge | **UniFFI** | Async future conversion between Rust/Swift, `ForeignFutureDroppedCallback` |

**VIOLATIONS TO WATCH FOR:**
- Agents directly calling AppleScript without going through the Tool Layer → WRONG
- Tools that are not pure functions (have side effects beyond their declared scope) → WRONG
- Orchestrator doing execution instead of delegating to specialist agents → WRONG
- Any layer skipping an adjacent layer → WRONG
- MLX inference happening in Rust → WRONG (must be in Swift)
- State management happening in Swift → WRONG (must be in Rust via SQLite)
- AX tree access via AXorcist (Swift) instead of accessibility-sys (Rust) → WRONG

---

## 🔒 ANTI-DRIFT ANCHOR 2 — Model Architecture (CRITICAL CORRECTION)

**⚠️ THE MODEL IS HYBRID MAMBA-ATTENTION, NOT PURE MAMBA-2.**

The Google Deep Research paper (Section 1.1) is definitive: **pure Mamba-2 has "reasoning drift" and JSON formatting failures** in complex, multi-turn tool calling scenarios. The earlier `epistemos-custom-mamba-model-blueprint.md` assumed pure Mamba-2 — this is CORRECTED.

**Architecture: Hybrid Mamba-Attention (Mamba-in-Llama pattern, NeurIPS 2024)**
- **Ratio**: 3:1 Mamba-to-Attention layers (75% Mamba, 25% Attention)
- **Mamba layers**: Handle sequence efficiency, linear-time processing, constant memory
- **Attention layers**: Serve as "global anchors" for exact token retrieval, strict JSON schema adherence
- **Multi-Token Prediction (MTP)**: Shared-weight heads for speculative decoding (2-3x wall-clock speedup)
- **Reference model**: NVIDIA Nemotron 3 Super (120B total, 12B active, LatentMoE Hybrid Mamba-Transformer)

**Model Tiers:**

| Tier | Parameters | Memory (4-bit) | Target Device | Distillation Teacher |
|------|-----------|----------------|---------------|---------------------|
| **Epistemos-Nano** | 1B | ~1.5 GB | M1/M2 8GB+ | Llama 3.2 1B → Hybrid | ✅ Runs + trains on your M2 Pro 18GB |
| **Epistemos-Base** | 3B | ~3.5 GB | M2/M3 16GB+ | Llama 3.1 8B → Hybrid | ✅ YOUR PRIMARY MODEL — runs + trains on M2 Pro 18GB |
| **Epistemos-Pro** | 8B | ~8 GB | M3/M4 32GB+ | Llama 3.1 8B (then 70B teacher) → Hybrid | ⚠️ Inference-only on M2 Pro 18GB (QLoRA training may OOM) |

**CRITICAL TRAINING SPLIT:**
- **Cloud GPUs (one-time)**: MOHAWK distillation for base Hybrid models. Requires 8-12B tokens, 4-8x A100 GPUs, 2-5 days. CANNOT run on M2 Pro 18GB. Use rented cloud GPUs (RunPod ~$2.79/hr H100, Vast.ai ~$2.25/hr, Lambda Labs ~$2.99/hr). Start with 1B (~$800-1,200), then 3B (~$1,500-2,500). Do NOT attempt 8B until smaller tiers are validated.
- **M2 Pro 18GB (continuous)**: QLoRA fine-tuning (1B and 3B models), KTO preference alignment, MoLoRA adapter routing, autoresearch self-improvement loop — all via MLX. 3B QLoRA training takes ~45 min/epoch. Run autoresearch overnight (~100 experiments while sleeping).

**Tool-calling MUST be baked into the base model during distillation, NOT just a LoRA adapter.** The ODIA framework distills tool-call patterns directly into the base model's parametric memory for zero-shot accuracy.

If anyone (including you) suggests using pure Mamba-2 without attention layers, STOP. This is a critical error. Re-read this anchor.

---

## 🔒 ANTI-DRIFT ANCHOR 3 — Perception Pipeline (HYBRID, NOT SINGLE-SOURCE)

**Primary**: `accessibility-sys` Rust crate → macOS AXUIElement tree → structured JSON
**Fallback**: Screen2AX VLM (Swift/MLX) → ScreenCaptureKit pixels → reconstructed AX tree

**Why both are required:**
- Only 33-36% of macOS apps provide complete, high-quality native accessibility metadata
- 46% include only partial metadata
- 18% lack accessibility support entirely
- Screen2AX achieves 77% F1 score in tree reconstruction and 2.2x performance improvement over native representations on ScreenSpot benchmark

**Decision Logic:**
```
IF accessibility-sys returns AX tree with >5 interactive elements:
    USE native AX tree (fast, structured, reliable)
ELSE IF AX tree is sparse (<5 elements) OR returns error:
    TRIGGER Screen2AX VLM fallback:
        1. Capture screen region via ScreenCaptureKit (Swift)
        2. Feed frame to lightweight VLM via MLX (Swift)  
        3. VLM outputs reconstructed hierarchical AX tree as JSON
        4. Pass reconstructed tree to Rust orchestrator via UniFFI
ENDIF
```

**Apps known to need fallback:** Electron apps, video games, custom-rendered UIs, many web browsers' internal content areas.

---

## 🔒 ANTI-DRIFT ANCHOR 4 — Security & Permissions (NON-NEGOTIABLE)

The app ships as an **unsandboxed, notarized macOS app** (outside App Store). Apple App Store sandboxing severely restricts the AppleScript, osascript, and file system access required for deep automation.

**LEGITIMATE permissions (user grants via System Settings):**

| Permission | What It Enables | How To Request |
|------------|----------------|----------------|
| Accessibility | UI control via AXUIElement, simulated input | `AXIsProcessTrusted()` → System Settings prompt |
| Automation (per-app) | AppleScript control of specific apps | First `tell application` triggers TCC prompt |
| Files & Folders | Read/write to Documents, Desktop, Downloads | `NSOpenPanel` or direct access after grant |
| Screen Recording | Visual context capture via ScreenCaptureKit | ScreenCaptureKit API → TCC prompt |
| Full Disk Access | Read any file on disk | System Settings manual toggle only |

**HARD RULES:**
- NEVER use TCC bypass techniques, CVE exploits, or private APIs to gain permissions
- NEVER use `tccutil reset` or modify `TCC.db` directly
- NEVER grant permissions programmatically — all require explicit user consent
- ALL destructive operations (file delete, system changes, bulk actions) require user confirmation
- Implement dry-run mode for ALL file system and system-modifying operations
- Log every automation action with timestamp, tool name, arguments, and result
- ALL requests from LLM to external tools pass through ConfirmationGate

---

## 🔒 ANTI-DRIFT ANCHOR 5 — MCP Protocol & Tool Design (STRICT SPEC)

All tools follow MCP (Model Context Protocol) conventions — JSON-RPC 2.0, governed by Linux Foundation since Dec 2025. The MCP server is **embedded** within the main application process (Rust), using **stdio transport** for tighter integration and lower latency than standalone HTTP.

**Tool Definition Schema (every tool MUST have):**
```json
{
  "name": "run_shortcut",
  "description": "Executes a named macOS Shortcut with optional input. Returns structured output.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "shortcut_name": {
        "type": "string",
        "description": "Exact name of the Shortcut to run"
      },
      "input": {
        "type": "string",
        "description": "Input data to pass to the Shortcut (text, file path, or JSON)"
      },
      "timeout_seconds": {
        "type": "integer",
        "default": 30,
        "description": "Maximum execution time before timeout"
      }
    },
    "required": ["shortcut_name"]
  },
  "safety": {
    "destructive": false,
    "requires_confirmation": false,
    "scoped_to_apps": ["com.apple.shortcuts"]
  }
}
```

**Tool Implementation Rules:**
1. **Pure functions**: Every tool is idempotent, stateless, deterministic
2. **Structured output**: Always return `{ "success": bool, "data": any, "error": string|null, "error_code": string|null, "duration_ms": int, "ui_state_after": object|null }`
3. **State verification**: After executing an action, the tool MUST poll the AX tree to confirm state mutation and return the state differential
4. **Timeout handling**: Every tool has a configurable timeout with graceful cleanup
5. **Error taxonomy**: Use codes: `TIMEOUT`, `PERMISSION_DENIED`, `NOT_FOUND`, `INVALID_INPUT`, `EXECUTION_ERROR`, `CANCELLED`, `AX_SPARSE`
6. **Logging**: Every invocation logs `{ timestamp, tool_name, args, result, duration_ms }` to SQLite
7. **Validation**: All arguments validated against JSON schema BEFORE execution
8. **Chain-of-thought hints**: Tool descriptions include usage hints (e.g., "Use execute_recipe for repetitive navigations before falling back to manual ax_click")

---

## 🔒 ANTI-DRIFT ANCHOR 6 — Multi-Agent Orchestration (RUST-SIDE)

Based on research across Azure AI Architecture Center, Google ADK, AWS Strands, and Kimi K2.5 PARL:

**Orchestration Model: Supervisor/Planner Pattern (Rust)**
```
User Request → Planner (cloud model for complex, local for simple)
                    ↓
            Task Decomposition → TaskGraph (DAG)
                    ↓
        ┌───────────┼───────────┐
        ↓           ↓           ↓
   SafariAgent  FileAgent  NotesAgent    (parallel when independent)
   [browse,     [read,     [create,      (each has narrow toolset)
    search,      write,     append,
    extract]     move,      search,
                 delete]    summarize]
        ↓           ↓           ↓
        └───────────┼───────────┘
                    ↓
            Result Aggregation
                    ↓
            Response to User (via UniFFI → SwiftUI)
```

**Agent Design Rules:**
1. **Single Responsibility**: Each agent owns ONE domain
2. **Narrow Toolset**: Max 5-7 tools per agent, enforced at protocol level
3. **No Cross-Talk**: Agents communicate ONLY through the Rust orchestrator
4. **Confidence Tracking**: Agent confidence >90% → auto-execute; 80-90% → log; <80% → escalate to user; <50% → refuse
5. **Retry Logic**: Max 3 retries per tool call with exponential backoff (0.2s base)
6. **PARL Anti-Serial-Collapse**: Train orchestration model to spawn concurrent sub-agents, penalize single-threaded execution

**Local vs Cloud Model Routing:**

| Use Case | Model | Reason |
|----------|-------|--------|
| Continuous agent loop (tool calls, clarification) | Local (MLX) | Privacy, latency, offline |
| Complex multi-step planning, deep research | Cloud API | Higher reasoning |
| Quick classification, intent routing | Local | Speed, cost-free |
| Generating automation patterns | Cloud → local audit | Cloud generates, local verifies |

---

## 🔒 ANTI-DRIFT ANCHOR 7 — UX Safety & Research-Pause Protocol (NON-NEGOTIABLE)

**Interaction Model: Plan → Review → Execute → Report**
```
1. User submits request
2. Planner generates execution plan:
   - List of steps with tool calls
   - Risk assessment per step (LOW/MEDIUM/HIGH/CRITICAL)
   - Estimated time and resource usage
3. Plan displayed in SwiftUI (PlanReviewView):
   - Editable step list
   - Per-step approve/reject toggles
   - "Execute All" / "Step-by-Step" / "Cancel" buttons
4. On approval:
   - LOW risk: auto-execute
   - MEDIUM risk: execute with logging
   - HIGH risk: pause and show preview before each
   - CRITICAL risk: require explicit per-step confirmation
5. After execution:
   - Show results summary
   - Allow undo where possible (soft-delete, versioning)
   - Log everything for audit trail
```

**Research-Pause Pattern:**
When the system encounters a task requiring information it cannot resolve locally:
1. System emits `RESEARCH_NEEDED` signal with specific questions
2. UX shows research request via `ResearchRequestView` with suggested search queries
3. User can: (a) do research manually, (b) trigger cloud research API, or (c) skip
4. Results fed back into agent loop as grounded context
5. Agent continues with verified information, never assumptions

---

## 📊 TRAINING DATA COMPOSITION TABLE

From Google Deep Research paper Section 1.2 — this is the definitive data mix for the custom hybrid model:

| Data Category | Percentage | Rationale |
|:-------------|:----------|:----------|
| **Synthetic Tool-Call Examples** | 40% | High-fidelity synthetic datasets distilled from frontier models executing exact macOS-specific MCP schemas via ODIA methodology. This is the largest category because tool-calling must be baked into the base model. |
| **General Language & Code** | 20% | Maintains semantic fluency, programmatic logic, prevents catastrophic forgetting of broad world knowledge. |
| **Multi-Step Reasoning Traces** | 20% | Chain-of-thought trajectories that explicitly penalize "reasoning drift" and reward logical consistency over long contexts. |
| **macOS-Specific Automation** | 20% | Curated datasets of AppleScript, JXA, structured Accessibility Tree JSON responses mapped to deterministic UI interactions. |

---

## 🏆 COMPETITIVE EDGE TABLE

From Google Deep Research paper Section 4.3:

| Competitor | Their Limitation | Epistemos Omega Advantage |
|:-----------|:----------------|:------------------------|
| **Apple Intelligence** | Limited to App Intents — relies on third-party developers exposing specific endpoints. Cannot control legacy or unoptimized apps. | Uses Accessibility Tree + Screen2AX pixel fallback for deep automation control over ANY application regardless of developer support. |
| **Microsoft Copilot** | Cloud-dependent. Transmits all data to external servers. Cannot operate offline. Limited to Microsoft ecosystem. | Zero-cloud dependency. 100% on-device execution. Full offline capability. Works with any macOS app. |
| **Google Agents** | Cloud-dependent. Same privacy concerns as Copilot. Limited macOS integration. | Native macOS integration via accessibility-sys, osascript, Shortcuts CLI. Complete privacy. |
| **Screenpipe** | Passive memory architecture — records and searches but cannot execute actions. No autonomous agents. | Transcends passive memory with autonomous execution. Agent orchestrator plans and executes multi-step workflows. |
| **Ghost OS** | Relies entirely on Swift/AXorcist. Depends on external API keys for cloud models. No custom local model. No self-improvement loop. | Custom self-improving hybrid model via MLX. Rust core for reliability. Autoresearch loop continuously improves overnight. |

---

## ⚠️ RISK REGISTER

From Google Deep Research paper Section 6 — 10 identified risks:

| # | Risk | Probability | Impact | Mitigation Strategy |
|---|:-----|:-----------|:-------|:-------------------|
| 1 | **Pure Mamba-2 Formatting Drift** | High | Critical | Adopt Hybrid Mamba-Attention (3:1 ratio). Attention layers serve as exact-match global anchors for strict JSON schemas. |
| 2 | **Incomplete macOS Accessibility Data** | High | Critical | Screen2AX VLM fallback reconstructs UI hierarchies from ScreenCaptureKit pixels when AX tree is sparse. |
| 3 | **Rust/Swift Async Memory Leaks** | Medium | High | UniFFI's `ForeignFutureDroppedCallback` or BoltFFI `AutoCloseable` for explicit cross-boundary task cancellation. |
| 4 | **FFI Latency Bottlenecks** | Medium | Medium | Keep memory-heavy MLX tensor ops in Swift. Use BoltFFI for microsecond primitive passing to Rust orchestrator. |
| 5 | **Catastrophic Forgetting during Tuning** | Medium | High | Experience Replay Buffer (MSSR), strict validation set of benchmark tasks, val_bpb ratchet before deploying new adapters. |
| 6 | **Reward Hacking in Agent Loop** | Medium | High | Rule-based trajectory verification filters. InfoRM Cluster Separation Index (CSI) detects over-optimized latent representations. |
| 7 | **"Serial Collapse" of Workflows** | High | Medium | PARL methodology: staged reward shaping with early instantiation reward + late critical-path latency penalty. |
| 8 | **Apple App Store Sandbox Constraints** | High | Critical | Design for direct developer distribution (notarized, unsandboxed). Sandbox blocks osascript, deep file system access. |
| 9 | **Model Hallucinating Invalid Tools** | High | Medium | Heavily weight SFT dataset with exact tool schemas. Hard application-level type checking in Rust MCP server. |
| 10 | **Underflows during Quantization** | Low | Medium | Retain Mamba Output Projection in FP8/BF16. Do not aggressively quantize to NVFP4. |

---

## 📋 MASTER PHASE LIST — COMPLETE IMPLEMENTATION PLAN (10 PHASES)

You MUST implement ALL phases below. After each phase, emit a `PHASE CHECKPOINT` with verification results. Do NOT proceed to the next phase until the current phase passes all checks.

**CRITICAL SEQUENCING RULE** (from Google Research Section 1.3): Build infrastructure FIRST (Phases 0-5), operate with cloud model API to generate synthetic training traces (Phase 7), THEN distill custom hybrid model (Phase 7), THEN fine-tune for tool calling via ODIA (Phase 8).

---

### Phase 0: Project Scaffolding & Configuration

**Objective:** Initialize the hybrid Rust/Swift project with all configuration files, documentation structure, and build system.

**Files to create:**
- [ ] `Package.swift` — Swift Package Manager config with dependencies: MLXLMCommon, MLXLLM, SwiftUI. Includes UniFFI-generated Swift bindings target.
- [ ] `Cargo.toml` — Rust workspace manifest with crates: `epistemos-core` (lib), `epistemos-mcp` (lib), `epistemos-tools` (lib), `epistemos-agents` (lib), `epistemos-automation` (lib). Dependencies: `tokio`, `serde`, `serde_json`, `rusqlite`, `accessibility-sys`, `uniffi`, `uuid`, `chrono`, `tracing`.
- [ ] `uniffi.toml` — UniFFI configuration for Rust→Swift binding generation
- [ ] `CLAUDE.md` — Project rules, architecture decisions, all 7 Anti-Drift Anchors by reference, compilation instructions
- [ ] `docs/PROGRESS.md` — Phase completion tracker (update after every phase)
- [ ] `docs/PHASE_CHECKLIST.md` — Copy of this phase list with checkboxes
- [ ] `docs/ARCHITECTURE.md` — Text diagram of the 5-layer architecture with language assignments
- [ ] `docs/DECISIONS.md` — Architectural decision log (ADR format)
- [ ] `.gitignore` — Xcode, Swift, Rust, Python, macOS, `.build/`, `target/` patterns
- [ ] `Makefile` — Targets: `build-rust`, `build-swift`, `build-all`, `test-rust`, `test-swift`, `test-all`, `generate-bindings` (UniFFI), `run`, `clean`

**Verification:**
```
□ `cargo check` passes for Rust workspace
□ `swift build` resolves Swift package (or Package.swift is syntactically valid)
□ UniFFI config file exists and references the correct Rust lib
□ CLAUDE.md contains all 7 Anti-Drift Anchors by reference
□ docs/ directory exists with all listed files
□ git init && git add . && git commit works
□ Makefile has all listed targets
```

---

### Phase 1: Rust Core — MCP Server, Tool Registry, SQLite State

**Objective:** Build the foundational Rust infrastructure: embedded MCP server, tool registry system, structured result types, execution logger, and SQLite persistence.

**Files to create (all in Rust):**
- [ ] `crates/epistemos-core/src/lib.rs` — Core re-exports
- [ ] `crates/epistemos-core/src/state.rs` — SQLite state manager: conversations, tool call history, execution traces, FTS5 search, WAL mode, connection pooling
- [ ] `crates/epistemos-core/src/config.rs` — App configuration: model selection, API keys, permission states, feature flags
- [ ] `crates/epistemos-mcp/src/lib.rs` — MCP re-exports
- [ ] `crates/epistemos-mcp/src/server.rs` — Embedded MCP server (stdio transport, JSON-RPC 2.0). Handles: `tools/list`, `tools/call`, `resources/list`, `resources/read`, `prompts/list`
- [ ] `crates/epistemos-mcp/src/protocol.rs` — JSON-RPC 2.0 message types, request/response parsing, error codes
- [ ] `crates/epistemos-tools/src/lib.rs` — Tool re-exports
- [ ] `crates/epistemos-tools/src/registry.rs` — Central ToolRegistry: register, discover, validate, invoke tools by name. Thread-safe via `Arc<RwLock<_>>`
- [ ] `crates/epistemos-tools/src/protocol.rs` — `ToolProtocol` trait: `name()`, `description()`, `input_schema()`, `safety()`, `execute(args) -> ToolResult`
- [ ] `crates/epistemos-tools/src/result.rs` — `ToolResult`: `{ success, data, error, error_code, duration_ms, ui_state_after }`
- [ ] `crates/epistemos-tools/src/schema.rs` — JSON Schema types for tool argument validation
- [ ] `crates/epistemos-tools/src/logger.rs` — ExecutionLogger: writes every tool invocation to SQLite with timestamp, tool_name, args, result, duration_ms
- [ ] `crates/epistemos-tools/src/recipe.rs` — RecipeManager: stores/loads JSON workflow templates (Ghost OS pattern), parameterized multi-step macros

**Implementation Rules:**
- MCP server runs embedded in the main process, NOT as a separate HTTP server
- SQLite uses WAL mode for concurrent reads during agent execution
- FTS5 index on conversation content and tool call history for fast search
- All tool execution is logged to SQLite via ExecutionLogger
- RecipeManager stores successful multi-step workflows as reusable JSON recipes
- Thread-safe design: all shared state behind `Arc<RwLock<_>>` or `Arc<Mutex<_>>`

**Verification:**
```
□ MCP server can handle a tools/list request and return registered tools
□ MCP server can handle a tools/call request and dispatch to the correct tool
□ SQLite database creates with correct schema (conversations, tool_calls, recipes, traces)
□ FTS5 search returns results from tool call history
□ ToolRegistry registers a mock tool and invokes it by name
□ ExecutionLogger writes and reads entries from SQLite
□ RecipeManager saves and loads a JSON recipe
□ All Rust code compiles with zero warnings
□ cargo test passes for all crates
```

---

### Phase 2: macOS Automation Layer — AX Tree, osascript, CGEvent, Permissions

**Objective:** Build the low-level macOS automation primitives in Rust that tools will wrap.

**Files to create (all in Rust):**
- [ ] `crates/epistemos-automation/src/lib.rs` — Automation re-exports
- [ ] `crates/epistemos-automation/src/accessibility.rs` — `accessibility-sys` crate wrapper: walk AX tree from focused app, extract elements as structured JSON `{ role, title, value, position, size, children[], is_interactive }`, query by role/title, perform actions (press, setValue)
- [ ] `crates/epistemos-automation/src/osascript.rs` — `Process::Command` wrapper for osascript: execute AppleScript and JXA, capture stdout/stderr, configurable timeout (default 30s), error parsing
- [ ] `crates/epistemos-automation/src/shortcuts.rs` — `Process::Command` wrapper for Shortcuts CLI: `shortcuts list`, `shortcuts run "Name" -i input -o output`, timeout handling, NOT_FOUND detection
- [ ] `crates/epistemos-automation/src/keystroke.rs` — CGEvent FFI: keystroke simulation (key down/up, modifier keys), mouse move/click at coordinates. Validates target app is frontmost before sending.
- [ ] `crates/epistemos-automation/src/permissions.rs` — PermissionManager: check `AXIsProcessTrusted()`, Screen Recording status, Full Disk Access. Returns structured permission state. Guides user to System Settings when missing.
- [ ] `crates/epistemos-automation/src/logger.rs` — AutomationLogger: structured logging for all low-level automation actions

**macOS Automation Primitives (VERIFIED PATTERNS):**
```bash
# Shortcuts CLI (Apple-documented)
shortcuts list
shortcuts run "Shortcut Name" -i /path/to/input
echo "text input" | shortcuts run "Process Text"
shortcuts run "Shortcut Name" -i input.txt -o output.txt

# AppleScript via osascript
osascript -e 'tell application "Safari" to get URL of current tab of front window'
osascript /path/to/script.scpt

# JXA (JavaScript for Automation)
osascript -l JavaScript -e 'Application("Safari").windows[0].currentTab.url()'
```

**Implementation Rules:**
- accessibility.rs MUST check `AXIsProcessTrusted()` before any AX operation
- AX tree walker returns sparse indicator (element count) so orchestrator can trigger Screen2AX fallback
- osascript.rs validates script before execution, captures stderr, implements 30s default timeout
- keystroke.rs logs every simulated input to AutomationLogger
- permissions.rs provides async permission status check, structured result
- ALL functions are async and return structured error types (not panics)
- Standardized delays: 0.2s for UI state changes, 2.0s for app launches

**Verification:**
```
□ accessibility.rs walks AX tree of frontmost app and returns JSON structure
□ accessibility.rs returns element count (sparse detection threshold: <5 elements)
□ osascript.rs executes 'tell application "Finder" to get name of startup disk' successfully
□ shortcuts.rs lists installed shortcuts (or returns empty list gracefully)
□ shortcuts.rs returns NOT_FOUND error for nonexistent shortcut name
□ keystroke.rs logs simulated keystrokes
□ permissions.rs correctly reports Accessibility permission state
□ All functions compile with zero warnings
□ Each function has at least 1 unit test
```

---

### Phase 3: Specialist Agents & Orchestrator (Rust)

**Objective:** Implement the agent protocol, specialist agents, planner/orchestrator with TaskGraph, and all control flow components in Rust.

**Files to create (all in Rust):**
- [ ] `crates/epistemos-agents/src/lib.rs` — Agent re-exports
- [ ] `crates/epistemos-agents/src/protocol.rs` — `AgentProtocol` trait: `name()`, `description()`, `toolset() -> Vec<String>`, `system_prompt()`, `process_task(task, context) -> AgentResult`. Enforces toolset boundary.
- [ ] `crates/epistemos-agents/src/result.rs` — `AgentResult`: `{ success, output, tool_calls: Vec<ToolInvocation>, confidence: f64, escalation: Option<EscalationReason> }`
- [ ] `crates/epistemos-agents/src/context.rs` — `AgentContext`: conversation history, user preferences, current app state, active permissions
- [ ] `crates/epistemos-agents/src/safari_agent.rs` — Toolset: [SearchWeb, FetchURL, GetUIContext, FindUIElement, ClickElement, TypeText, PressKey]
- [ ] `crates/epistemos-agents/src/file_agent.rs` — Toolset: [ReadFile, WriteFile, ListFiles, MoveFile, DeleteFile]
- [ ] `crates/epistemos-agents/src/notes_agent.rs` — Toolset: [RunAppleScript (scoped to Notes.app), ReadFile, WriteFile]
- [ ] `crates/epistemos-agents/src/terminal_agent.rs` — Toolset: [RunAppleScript (scoped to Terminal), SimulateKeystroke, PressKey]
- [ ] `crates/epistemos-agents/src/automation_agent.rs` — Toolset: [RunShortcut, GetUIContext, FindUIElement, ClickElement, TypeText, PressKey, ExecuteRecipe]
- [ ] `crates/epistemos-agents/src/orchestrator.rs` — Main Orchestrator: receive task → plan (via model) → build TaskGraph → confirm → dispatch to agents → aggregate results → return
- [ ] `crates/epistemos-agents/src/planner.rs` — Planner: structured prompt template → typed TaskStep list with agent assignments and dependency graph
- [ ] `crates/epistemos-agents/src/task_graph.rs` — TaskGraph: DAG of TaskSteps with dependencies, parallel execution detection, status tracking, cancellation
- [ ] `crates/epistemos-agents/src/confirmation_gate.rs` — ConfirmationGate: risk-based confirmation (LOW=auto, MEDIUM=log, HIGH=preview, CRITICAL=explicit confirm). Blocks execution until UI confirms.
- [ ] `crates/epistemos-agents/src/research_pause.rs` — ResearchPauseHandler: captures RESEARCH_NEEDED signals, surfaces to UX via UniFFI callback, accepts research input, resumes agent
- [ ] `crates/epistemos-agents/src/model_router.rs` — ModelRouter: deterministic routing logic — planning → cloud, simple tool calls → local, classification → local. Logged decisions.

**TaskStep Schema (Rust):**
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskStep {
    pub id: Uuid,
    pub description: String,
    pub assigned_agent: String,
    pub tool_hints: Vec<String>,
    pub depends_on: Vec<Uuid>,
    pub risk_level: RiskLevel,  // Low, Medium, High, Critical
    pub estimated_duration_ms: u64,
    pub status: StepStatus,     // Pending, Confirmed, Executing, Completed, Failed, Skipped
    pub result: Option<AgentResult>,
}
```

**Implementation Rules:**
- Each agent can ONLY invoke tools in its declared toolset (enforced in `process_task`)
- Agents track confidence per action and escalate when confidence < 80%
- Agents implement retry logic: max 3 retries per tool call with exponential backoff
- Orchestrator enforces ConfirmationGate BEFORE any agent execution
- TaskGraph supports: sequential deps, parallel execution, cancellation, partial completion
- ModelRouter decisions are deterministic and logged (not opaque)
- ResearchPauseHandler captures exact questions and provides them to UX layer via UniFFI callback

**Verification:**
```
□ AgentProtocol enforces toolset boundary (attempting unauthorized tool throws error)
□ Orchestrator decomposes "Find Apple news and save to a note" into:
  [1] SafariAgent: search → [2] NotesAgent: create note (correct dependency)
□ TaskGraph correctly identifies sequential vs parallel tasks
□ ConfirmationGate blocks HIGH risk operations until confirmed
□ ModelRouter correctly routes planning → cloud, tool calls → local
□ ResearchPauseHandler surfaces questions and accepts input
□ All agents compile, all have at least 1 unit test
```

---

### Phase 4: MLX Integration (Swift) — Local & Cloud Models

**Objective:** Implement the Swift-side model layer: local MLX inference, cloud API client, tool call parsing, streaming token support. Connect to Rust via UniFFI callbacks.

**Files to create (Swift):**
- [ ] `Sources/Models/ModelProtocol.swift` — Unified protocol: `generate(prompt:tools:) async throws -> ModelResponse`
- [ ] `Sources/Models/MLXLocalModel.swift` — MLX Swift integration using `MLXLMCommon`/`MLXLLM`. Handles: model loading from HuggingFace, token streaming via `AsyncSequence`, tool-call JSON parsing, cancellation. Loading states: downloading, loading, ready, error.
- [ ] `Sources/Models/CloudModel.swift` — OpenAI-compatible API client using `URLSession` with streaming. Handles: API key management (Keychain), streaming SSE parsing, tool calling format, rate limiting with retry/backoff.
- [ ] `Sources/Models/ModelResponse.swift` — Unified response: `{ text, toolCalls: [ToolCall]?, finishReason, tokensUsed, latencyMs }`
- [ ] `Sources/Models/ToolCallParser.swift` — Robust JSON parser for tool call extraction from model output. Handles: valid JSON, malformed JSON (attempt repair), no tool calls (pure text), multiple tool calls in one response, streaming partial JSON.
- [ ] `Sources/Models/ModelConfig.swift` — Model configuration: model ID, quantization level, temperature, max tokens, system prompt
- [ ] `Sources/Bridge/RustBridge.swift` — UniFFI-generated bindings import + wrapper methods for calling Rust orchestrator. Implements UniFFI async callbacks for streaming tokens back to Rust.

**MLX Swift Integration (verified via WWDC25 and mlx-swift-examples):**
```swift
import MLXLMCommon
import MLXLLM

let modelId = "mlx-community/Mistral-7B-Instruct-v0.3-4bit"
let configuration = ModelConfiguration(id: modelId)
let model = try await LLMModelFactory.shared.loadContainer(configuration: configuration)

try await model.perform { context in
    let input = try await context.processor.prepare(
        input: UserInput(prompt: "Your prompt here")
    )
    let params = GenerateParameters(temperature: 0.0)
    let tokenStream = try generate(input: input, parameters: params, context: context)
    for await part in tokenStream {
        print(part.chunk ?? "", terminator: "")
    }
}
```

**Implementation Rules:**
- MLXLocalModel MUST use `LLMModelFactory.shared.loadContainer()` for model loading
- Token streaming via `AsyncSequence` — each token sent to Rust via UniFFI callback
- CloudModel uses native `URLSession` with SSE streaming, NOT third-party HTTP libs
- ToolCallParser handles malformed JSON gracefully (attempt repair, never crash)
- Model loading states propagated to UX layer for download progress display
- UniFFI bridge implements `ForeignFutureDroppedCallback` for async cleanup when Swift tasks are cancelled

**Verification:**
```
□ MLXLocalModel loads a 4-bit model from HuggingFace (e.g., mlx-community/Mistral-7B-Instruct-v0.3-4bit)
□ MLXLocalModel generates streaming text response
□ MLXLocalModel correctly parses tool call JSON from model output
□ CloudModel connects to OpenAI-compatible API and generates response
□ CloudModel handles rate limiting gracefully (retry with backoff)
□ ToolCallParser handles malformed JSON without crashing
□ UniFFI bridge successfully passes data between Rust and Swift
□ Model loading states correctly reported to UX layer
```

---

### Phase 5: SwiftUI UX Layer

**Objective:** Build the SwiftUI interface for plan-before-execute, confirmation gates, research-pause, audit log, settings, and execution progress.

**Files to create (Swift):**
- [ ] `Sources/UI/MainView.swift` — Primary interface: chat input field, response display with streaming, model status indicator, sidebar navigation
- [ ] `Sources/UI/PlanReviewView.swift` — Shows execution plan as editable step list. Per-step approve/reject toggles. Risk level badges. "Execute All" / "Step-by-Step" / "Cancel" buttons. Drag to reorder.
- [ ] `Sources/UI/ConfirmationSheet.swift` — Modal for HIGH/CRITICAL risk operations: what will happen, which tool, what arguments, risk level, approve/deny buttons
- [ ] `Sources/UI/ResearchRequestView.swift` — Shows RESEARCH_NEEDED questions: numbered question list, copy button per question, suggested Google Deep Research prompt, text area for pasting research results
- [ ] `Sources/UI/ExecutionProgressView.swift` — Real-time progress: current agent running, current tool being called, live streaming output, step-by-step plan with checkmarks, elapsed time
- [ ] `Sources/UI/SettingsView.swift` — Model selection (local/cloud), API key management, permission status display with "Grant" buttons, automation preferences, data export
- [ ] `Sources/UI/AuditLogView.swift` — Searchable/filterable log of all past executions: timestamp, tool name, arguments, result, duration. Export to JSON.
- [ ] `Sources/App/EpistemosApp.swift` — Main app entry point, dependency injection, lifecycle management, menu bar integration

**Implementation Rules:**
- PlanReviewView allows: editing descriptions, reordering steps, removing steps, adding steps
- ConfirmationSheet shows: what will happen, which tool, arguments, risk level, cancel button
- ResearchRequestView lists specific questions with copy buttons, provides paste-ready Deep Research prompt
- ExecutionProgressView shows real-time streaming, highlights current step, shows tool call results as they arrive
- ALL views responsive (no blocking main thread) — `@MainActor` and `Task` used correctly
- Settings persist to `UserDefaults` (non-sensitive) and Keychain (API keys)

**Verification:**
```
□ MainView renders and accepts text input
□ PlanReviewView displays a multi-step plan and allows editing
□ ConfirmationSheet blocks execution until user approves or denies
□ ResearchRequestView displays questions and accepts pasted research
□ ExecutionProgressView shows real-time streaming updates
□ Settings correctly persist and load
□ All views compile and render in Xcode preview
```

---

### Phase 6: Screen2AX VLM Fallback (Swift/MLX)

**Objective:** Implement the lightweight vision-language model that reconstructs accessibility trees from screen pixels when native AX tree is sparse.

**Files to create (Swift):**
- [ ] `Sources/Perception/Screen2AXPipeline.swift` — Orchestrates: detect AX sparsity → capture screen → run VLM → output reconstructed AX tree JSON
- [ ] `Sources/Perception/ScreenCapture.swift` — ScreenCaptureKit wrapper: capture specific window or screen region as `CGImage`, configurable frame rate for continuous monitoring
- [ ] `Sources/Perception/VLMInference.swift` — Lightweight VLM loaded via MLX: takes `CGImage` input, outputs structured JSON representing the UI hierarchy `{ elements: [{ role, title, bounds, children }] }`
- [ ] `Sources/Perception/AXTreeReconstructor.swift` — Parses VLM JSON output into the same format as native AX tree, validates structure, handles VLM errors gracefully
- [ ] `Sources/Perception/SparsityDetector.swift` — Receives AX element count from Rust via UniFFI, determines if fallback is needed (threshold: <5 interactive elements)

**Screen2AX Reference Performance:**
- 77% F1 score in tree reconstruction
- 2.2x performance improvement over native representations on ScreenSpot benchmark
- Needed for ~46-64% of macOS apps (partial + no accessibility metadata)

**Implementation Rules:**
- VLM must be lightweight (<1B parameters) to run alongside main model
- ScreenCaptureKit requires Screen Recording permission — check via PermissionManager
- Fallback decision is made in Rust (accessibility.rs detects sparsity), trigger sent to Swift via UniFFI
- Reconstructed tree is passed back to Rust orchestrator in same format as native AX tree
- Frame capture is on-demand (triggered by sparse detection), NOT continuous polling

**Verification:**
```
□ ScreenCapture captures a frame from the frontmost window
□ VLMInference loads a lightweight VLM and produces structured JSON from an image
□ AXTreeReconstructor converts VLM output to standard AX tree format
□ SparsityDetector correctly identifies sparse AX trees
□ Full pipeline: sparse AX → capture → VLM → reconstructed tree (end-to-end)
□ Fallback is NOT triggered when native AX tree is rich (>5 elements)
```

---

### Phase 7: Synthetic Data Generation & Model Training Prep

**Objective:** Use the running system with a cloud model API (Claude/OpenAI) to generate 10,000+ execution traces, format as ODIA training dataset, and prepare MOHAWK distillation configuration for cloud GPU training.

**Files to create:**
- [ ] `crates/epistemos-training/src/lib.rs` — Training data management re-exports
- [ ] `crates/epistemos-training/src/trace_logger.rs` — Enhanced execution trace logger: captures full request → plan → tool calls → results → user feedback as structured JSONL
- [ ] `crates/epistemos-training/src/dataset_formatter.rs` — Converts raw SQLite traces into training formats: ODIA tool-call SFT pairs, multi-step reasoning traces, macOS automation examples
- [ ] `crates/epistemos-training/src/data_mixer.rs` — Implements the 40/20/20/20 data composition: synthetic tool-calls (40%), general language/code (20%), reasoning traces (20%), macOS automation (20%)
- [ ] `crates/epistemos-training/src/quality_filter.rs` — Filters training data: only functionally verified outcomes (file actually created, email actually sent), removes failed/partial traces
- [ ] `docs/TRAINING_GUIDE.md` — Complete guide for cloud GPU training:
  - RunPod API setup and automation scripts
  - MOHAWK distillation config for Hybrid Mamba-Attention (NOT pure Mamba-2)
  - 3-stage distillation: Matrix Orientation (~500M tokens) → Hidden-State Alignment (~5B tokens) → Knowledge Distillation (~6.5B tokens)
  - Hybrid architecture specification: 3:1 Mamba-to-Attention ratio
  - Post-distillation: convert to MLX format via `mlx_lm.convert`
  - Mixed-precision quantization (lm_head + embed_tokens at 6-bit, rest at 4-bit)
  - Upload to HuggingFace for distribution

**Cloud GPU Training Requirements (for docs/TRAINING_GUIDE.md):**

| Model Size | Hardware | Training Time | Estimated Cost |
|-----------|----------|---------------|----------------|
| 1B (Nano) | 4x A100 80GB | ~2-3 days | ~$800-1,200 |
| 3B (Base) | 8x A100 80GB | ~3-4 days | ~$1,500-2,500 |
| 8B (Pro) | 8x A100 80GB | ~5 days | ~$2,500-3,500 |

**GPU Rental Platforms:**
- RunPod ($2.79/hr H100, per-second billing, API for automation)
- Vast.ai (~$2.25/hr H100, marketplace model, cheapest)
- Lambda Labs ($2.99/hr, pre-configured ML environments, simplest setup)
- EzEpoch (https://ezepoch.com) — automates deployment to Vast.ai/RunPod

**Automation Script Structure:**
```
1. Script rents GPU instance via RunPod API
2. Uploads training code + data configuration
3. Starts MOHAWK distillation (Hybrid Mamba-Attention, 3:1 ratio)
4. Monitors training loss via webhook/polling
5. Downloads trained weights when complete
6. Terminates instance (zero idle cost)
7. Converts weights to MLX format locally
8. Quantizes: mixed-precision (6-bit head/embeddings, 4-bit rest)
```

**Implementation Rules:**
- Trace logger captures EVERY interaction when system operates via cloud API
- Only functionally verified traces enter training pool (quality_filter)
- Dataset formatter produces JSONL compatible with standard SFT training frameworks
- Data mixer enforces the 40/20/20/20 ratio from Google research
- TRAINING_GUIDE.md must be comprehensive enough for a developer to follow independently

**Verification:**
```
□ Trace logger captures full execution traces to SQLite
□ Dataset formatter produces valid JSONL training files
□ Data mixer correctly allocates traces to the 40/20/20/20 composition
□ Quality filter removes failed/partial traces
□ docs/TRAINING_GUIDE.md is comprehensive with all commands and configs
□ MOHAWK config specifies Hybrid Mamba-Attention (NOT pure Mamba-2)
□ RunPod automation script outline is complete
```

---

### Phase 8: On-Device Personalization (Swift/MLX)

**Objective:** Implement the continuous on-device learning pipeline: QLoRA fine-tuning, KTO preference alignment, MoLoRA per-token adapter routing, autoresearch self-improvement loop, and InfoRM CSI safeguard.

**Files to create (Swift):**
- [ ] `Sources/Training/QLoRATrainer.swift` — On-device QLoRA training via MLX. Handles: dataset loading (JSONL), LoRA injection into target layers, training loop with progress callback, adapter saving as `.safetensors`. Hyperparameters:
  - Knowledge absorption: targets attention + MLP layers (gate_proj, up_proj, down_proj), rank=32, alpha=64
  - Style cloning: targets attention layers only (q/k/v/o projections), rank=8, alpha=16
  - Tool learning: targets attention + mixing layers, rank=16, alpha=32
- [ ] `Sources/Training/KTOAligner.swift` — Kahneman-Tversky Optimization from binary feedback. User accepts → positive gain, user rejects → loss. Operates on unpaired feedback (NOT DPO which requires paired chosen/rejected). Runs overnight batch.
- [ ] `Sources/Training/MoLoRARouter.swift` — Mixture of LoRA Experts: loads multiple adapters simultaneously, lightweight routing function evaluates each token and routes through appropriate active adapter (Knowledge, Style, Tool). Per-token switching. NEVER fuse adapters permanently into base model (causes throughput collapse from ~21 tok/s to ~7 tok/s on MLX).
- [ ] `Sources/Training/AutoresearchLoop.swift` — Karpathy autoresearch pattern:
  1. Agent proposes change (different LoRA config, data mix, curriculum order)
  2. Trains with fixed time budget (~5 minutes)
  3. Evaluates against held-out validation set using val_bpb (bits per byte) ratchet
  4. If improved: git commit (keep). If degraded: git reset (discard)
  5. Repeats overnight (~100 experiments while user sleeps)
- [ ] `Sources/Training/CSISafeguard.swift` — InfoRM Cluster Separation Index: monitors latent space during autoresearch. Detects when model begins over-optimizing on spurious features (reward hacking). If CSI drops below threshold, halts training and reverts to last known-good adapter.
- [ ] `Sources/Training/ExperienceReplay.swift` — MSSR-style experience replay buffer: maintains fixed-capacity buffer of general-purpose conversational data, interleaves during personal knowledge fine-tuning to prevent catastrophic forgetting.
- [ ] `Sources/Training/TrainingScheduler.swift` — Schedules training runs: overnight batch when machine is idle and connected to power, respects thermal limits, pauses if user resumes activity.

**On-Device Training Benchmarks (from Knowledge Fusion research):**

| Chipset | Memory BW | QLoRA Time (1000 examples, r=32) | Peak Memory |
|---------|-----------|----------------------------------|-------------|
| M1 Max 32GB | 400 GB/s | ~55 minutes | 11.0 GB |
| **M2 Pro 18GB (YOUR DEVICE)** | **200 GB/s** | **~45 minutes** | **~11.5 GB** | ⚠️ Close heavy apps during training (6.5 GB left for OS+app) |
| M3 Max 64GB | 400 GB/s | ~22 minutes | 11.5 GB |
| M4 Max 64GB | 546 GB/s | ~14 minutes | 12.1 GB |
| M5 Max 128GB | 614 GB/s | ~8 minutes | 12.4 GB |

**Minimum Viable Dataset Sizes:**
- Behavioral changes (formatting, tone): 100-500 examples
- Tool call learning: 1,000-3,000 examples
- Factual knowledge absorption: 3,000-10,000 examples
- Beyond 10,000 examples: diminishing returns (LoRA matrices saturate)

**Implementation Rules:**
- NEVER fuse adapters permanently — hot-swap only (MoLoRA)
- QLoRA targets differ based on adaptation type (knowledge vs style vs tools)
- Autoresearch loop runs in sandboxed environment with 5-minute wall-clock budget per experiment
- CSI safeguard monitors every autoresearch iteration
- Experience replay buffer size: ~500 general examples, refreshed weekly
- Training scheduler respects: power state, thermal limits, user activity
- All adapter files stored as `.safetensors` in app's data directory

**Verification:**
```
□ QLoRATrainer trains a LoRA adapter on a small JSONL dataset and saves .safetensors
□ KTOAligner processes binary accept/reject feedback and updates adapter
□ MoLoRARouter loads 2+ adapters and routes tokens through correct adapter
□ AutoresearchLoop runs one experiment cycle: propose → train → evaluate → keep/discard
□ CSISafeguard detects synthetic reward hacking scenario and halts
□ ExperienceReplay correctly interleaves general data during domain training
□ TrainingScheduler respects power state (only trains when connected to power)
```

---

### Phase 9: Integration Testing & Documentation

**Objective:** Wire everything together, verify complete flows, comprehensive documentation, and final polish.

**Files to create/update:**
- [ ] `Tests/IntegrationTests/EndToEndTests.swift` — Full flow: user input → plan → confirm → agent execution → result display
- [ ] `Tests/IntegrationTests/SafetyTests.swift` — Verify confirmation gates for all destructive operations
- [ ] `Tests/IntegrationTests/EscalationTests.swift` — Verify agents escalate when stuck (confidence <80%)
- [ ] `Tests/IntegrationTests/ResearchPauseTests.swift` — Verify research-pause flow end-to-end
- [ ] `Tests/IntegrationTests/Screen2AXFallbackTests.swift` — Verify sparse AX → VLM fallback → reconstructed tree
- [ ] `Tests/IntegrationTests/FFIBridgeTests.swift` — Verify Rust↔Swift data passing via UniFFI
- [ ] `README.md` — Project overview, architecture diagram, setup instructions, usage guide, contributing guide
- [ ] `docs/ARCHITECTURE.md` — Updated: 5-layer diagram, component descriptions, data flow, language assignments
- [ ] `docs/TOOL_CATALOG.md` — Complete catalog of all MCP tools with schemas and examples
- [ ] `docs/AGENT_CATALOG.md` — Complete catalog of all agents with capabilities, toolsets, limitations
- [ ] `docs/SECURITY.md` — Security model, permission requirements, data handling, audit logging, adapter encryption
- [ ] `docs/COMPETITIVE_ANALYSIS.md` — Full competitive edge table (vs Apple Intelligence, Copilot, Google, Screenpipe, Ghost OS)
- [ ] `docs/TRAINING_GUIDE.md` — (updated) Complete model training pipeline documentation
- [ ] `docs/TESTING.md` — Test plan for manual testing scenarios

**End-to-End Scenarios to Test:**
1. "What's the weather in San Francisco?" → Routes to cloud search → Returns result
2. "Open Safari and go to apple.com" → SafariAgent → AX tree UI automation → Success
3. "Delete all files in ~/Desktop/temp/" → HIGH risk → ConfirmationGate → Executes after confirm
4. "Research MLX benchmarks and save to Notes" → Multi-agent: Safari → Notes → Success
5. "Do something with no defined tool" → Agent escalates → RESEARCH_NEEDED or graceful decline
6. Electron app automation → AX tree sparse → Screen2AX fallback → VLM reconstructs tree → Success

**Verification:**
```
□ App launches without crashes
□ Full flow: text input → plan → confirmation → agent execution → result
□ Destructive operations blocked without confirmation
□ Agents correctly escalate when out of domain
□ Research-pause correctly interrupts and resumes flow
□ Screen2AX fallback triggers for sparse AX apps
□ Rust↔Swift FFI bridge passes data correctly
□ All integration tests pass
□ No compiler warnings (Rust or Swift)
□ docs/PROGRESS.md shows all phases ✅ VERIFIED
□ Code comments for every public function and type
□ No TODO/FIXME/HACK comments remain (move to docs/FUTURE.md)
□ Final git commit is clean with all files tracked
```

---

## 📊 PHASE CHECKPOINT TEMPLATE

After completing each phase, emit this EXACTLY:

```
═══════════════════════════════════════════════════
✅ PHASE CHECKPOINT: Phase [N] — [Name]
─────────────────────────────────────────────────
FILES CREATED:
  ✅ path/to/file1 — [brief description]
  ✅ path/to/file2 — [brief description]
  ...

VERIFICATION RESULTS:
  ✅ [Check 1] — PASSED: [evidence]
  ✅ [Check 2] — PASSED: [evidence]
  ❌ [Check 3] — FAILED: [reason] → FIXING NOW
  ...

ANTI-DRIFT CHECK:
  ✅ Architecture matches Anchor 1 (5-layer, Rust/Swift split)
  ✅ Model is Hybrid Mamba-Attention per Anchor 2 (NOT pure Mamba-2)
  ✅ Perception uses Hybrid pipeline per Anchor 3 (AX + Screen2AX)
  ✅ Security follows Anchor 4 rules
  ✅ Tools follow Anchor 5 MCP spec
  ✅ Agents follow Anchor 6 orchestration model
  ✅ UX follows Anchor 7 safety protocol

PROGRESS UPDATE:
  → Updated docs/PROGRESS.md
  → Updated docs/PHASE_CHECKLIST.md
  → Committed to git: "Phase [N] complete: [description]"

NEXT: Phase [N+1] — [Name]
═══════════════════════════════════════════════════
```

If ANY verification check FAILS, you must FIX IT before proceeding. If you cannot fix it, emit a `RESEARCH NEEDED` block.

---

## 🔄 SELF-CORRECTION PROTOCOL

At the start of EVERY new session or after EVERY `/compact`:

```
SELF-CORRECTION CHECKLIST:
1. cat CLAUDE.md && cat docs/PROGRESS.md && cat docs/PHASE_CHECKLIST.md
2. Identify which phase I'm on
3. Re-read the Anti-Drift Anchor for that phase
4. Re-read docs/DECISIONS.md for architectural decisions
5. Verify my current work doesn't contradict any anchor
6. Continue implementation from exactly where I left off
7. If anything feels wrong, STOP and re-read all anchors
```

If you find yourself doing something NOT in the phase list, STOP. You are drifting. Re-read the MASTER PHASE LIST.

---

## 📎 REFERENCE LINKS (for research-pause resolution)

When you emit RESEARCH NEEDED, the user should check these sources. Organized by domain:

**Apple / MLX / macOS:**
- Apple MLX Framework: https://ml-explore.github.io/mlx/
- MLX Swift Examples: https://github.com/ml-explore/mlx-swift-examples
- MLX LM (WWDC25): https://developer.apple.com/videos/play/wwdc2025/298/
- MLX on M5 Neural Accelerators: https://machinelearning.apple.com/research/exploring-llms-mlx-m5
- AXorcist (Accessibility): https://github.com/steipete/AXorcist
- Apple AXUIElement Docs: https://developer.apple.com/documentation/applicationservices/axuielement
- Apple Shortcuts CLI: https://support.apple.com/guide/shortcuts-mac/run-shortcuts-from-the-command-line-apd455c82f02/mac
- App Intents & Apple Intelligence: https://medium.com/simform-engineering/app-intents-apple-intelligence-unlocking-the-basics-2208bf896e03
- Apple Acceptable Use Requirements: https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/
- Swift-native MCP server lessons: https://www.reddit.com/r/swift/comments/1reb68v/a_swiftnative_mcp_server_lessons_on_stdio/

**Model Architecture & Training:**
- NVIDIA Nemotron 3 Super (Hybrid Mamba-Transformer): https://developer.nvidia.com/blog/introducing-nemotron-3-super-an-open-hybrid-mamba-transformer-moe-for-agentic-reasoning/
- Nemotron 3 Super Technical Report: https://research.nvidia.com/labs/nemotron/files/NVIDIA-Nemotron-3-Super-Technical-Report.pdf
- Mamba-in-Llama (NeurIPS 2024): https://proceedings.neurips.cc/paper_files/paper/2024/hash/723933067ad315269b620bc0d2c05cba-Abstract-Conference.html
- MOHAWK Distillation: https://arxiv.org/abs/2408.10189
- Llamba (Cartesia proof): https://arxiv.org/html/2502.14458v1
- Apriel-H1 Hybrid SSM-Transformer: https://arxiv.org/html/2511.02651v1
- ODIA (Oriented Distillation): https://arxiv.org/pdf/2507.08877
- Mamba-3: https://arxiv.org/abs/2603.15569
- Codestral Mamba: https://mistral.ai/news/codestral-mamba

**On-Device Personalization:**
- mlx-tune (SFT, DPO, KTO, GRPO on MLX): https://github.com/ARahim3/mlx-tune
- mlx-lm-lora (12 training algorithms): https://github.com/Goekdeniz-Guelmez/mlx-lm-lora
- MoLoRA (per-token adapter routing): https://arxiv.org/html/2603.15965v1
- KTO vs DPO vs RLHF: https://blog.premai.io/which-llm-alignment-method-rlhf-vs-dpo-vs-kto-tradeoffs-explained/
- MSSR Experience Replay: https://arxiv.org/html/2603.09892v1
- InfoRM (Reward Hacking Mitigation): https://proceedings.neurips.cc/paper_files/paper/2024/file/f25d75fc760aec0a6174f9f5d9da59b8-Paper-Conference.pdf
- Karpathy Autoresearch: https://www.datacamp.com/tutorial/guide-to-autoresearch

**Agentic / Orchestration:**
- Ghost OS: https://github.com/ghostwright/ghost-os
- Screenpipe: https://github.com/screenpipe/screenpipe
- Screen2AX: https://arxiv.org/html/2507.16704v1
- MCP Specification: https://modelcontextprotocol.io/specification/2025-03-26
- Kimi K2.5 PARL: https://www.datacamp.com/tutorial/kimi-k2-agent-swarm-guide
- Runner H / Holo-1: https://hcompany.ai/charting-a-new-route-the-tech-behind-runner-hs-state-of-the-art-results
- Fine-tuning for Function Calling (OpenAI): https://developers.openai.com/cookbook/examples/fine_tuning_for_function_calling/

**Rust / FFI:**
- UniFFI Async FFI: https://mozilla.github.io/uniffi-rs/latest/internals/async-ffi.html
- UniFFI Futures: https://mozilla.github.io/uniffi-rs/0.28/futures.html
- BoltFFI: https://www.reddit.com/r/rust/comments/1r768bm/boltffi_a_highperformance_rust_bindings_generator/
- MCP Server in Rust (Composio): https://composio.dev/content/how-to-build-your-first-ai-agent-with-mcp-in-rust
- Rust MCP Server (OneUptime): https://oneuptime.com/blog/post/2026-01-07-rust-mcp-server/view

**Multi-Agent & Safety Patterns:**
- Multi-Agent Patterns (Azure): https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns
- Multi-Agent Patterns (Google ADK): https://developers.googleblog.com/developers-guide-to-multi-agent-patterns-in-adk/
- HITL Oversight (Galileo): https://galileo.ai/blog/human-in-the-loop-agent-oversight
- Agentic Safety (Noma): https://noma.security/blog/the-risk-of-destructive-capabilities-in-agentic-ai/

**GPU Rental:**
- RunPod: https://www.runpod.io
- Vast.ai: https://vast.ai
- Lambda Labs: https://lambdalabs.com
- EzEpoch (training automation): https://ezepoch.com

**Claude Code:**
- Claude Code Best Practices: https://code.claude.com/docs/en/best-practices

---

## 🚀 BEGIN EXECUTION

Start with Phase 0. For EVERY phase:
1. Read the phase requirements carefully
2. Create all listed files
3. Implement according to the rules
4. Run verification checks
5. Emit PHASE CHECKPOINT
6. Update docs/PROGRESS.md and docs/PHASE_CHECKLIST.md
7. Commit to git: `git add -A && git commit -m "Phase [N] complete: [description]"`
8. Proceed to next phase

**DO NOT STOP UNTIL ALL 10 PHASES (0-9) ARE COMPLETE AND VERIFIED.**

If you reach the end of your context window before completing all phases:
1. Emit a summary of what's done and what's remaining
2. Update docs/PROGRESS.md with current state
3. Commit everything to git
4. The user will start a new session where you'll run: `cat CLAUDE.md && cat docs/PROGRESS.md && cat docs/PHASE_CHECKLIST.md` and continue

**Your work is not done until docs/PHASE_CHECKLIST.md shows ✅ on every single item across all 10 phases.**

After thinking you are "done," re-read the entire PHASE CHECKLIST one final time. If any item lacks ✅, you are NOT done. Continue.
