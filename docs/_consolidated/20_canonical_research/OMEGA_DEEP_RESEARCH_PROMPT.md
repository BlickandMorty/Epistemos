# OMEGA DEEP RESEARCH PROMPT

> **Index status**: CANONICAL-RESEARCH — Omega agent orchestration deep-research prompt — 5-layer split + current architecture inventory + research targets.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.


## For Google Deep Research / Perplexity Pro / Claude Research Mode

---

## MISSION

I am building **Epistemos Omega** — a native macOS agent orchestration system embedded in a knowledge management app. It uses **Rust + Swift + Metal** with direct access to:
- macOS Accessibility APIs (AXUIElement, AX tree walking)
- CGEvent input simulation (clicks, keystrokes, mouse moves)
- ScreenCaptureKit (screen capture)
- Apple Events / osascript (inter-app scripting)
- Shortcuts.app integration
- Local LLM inference via MLX (Qwen 3.5 4B on-device)
- Terminal/CLI command execution
- SwiftData + FTS5 SQLite knowledge base (710+ notes)
- Metal GPU compute for graph rendering

I want to research the absolute best approaches from open-source agent frameworks and create a **Rust + Swift native implementation** that surpasses all of them. The goal is Apple Design Award quality with zero cloud dependency for core agent features.

---

## CURRENT ARCHITECTURE (what exists)

### 5-Layer Split
```
Layer 5 (Swift/SwiftUI): Views, UX, OmegaPanel
Layer 4 (Swift): MLX inference, OmegaInferenceBridge → TriageService (Qwen 3.5 4B)
Layer 3 (Rust omega-mcp): Orchestrator, TaskGraph, agents, confirmation gate, SQLite logging
Layer 2 (Rust omega-mcp): MCP dispatcher, tool registry, recipes
Layer 1 (Rust omega-ax): AX tree, CGEvent, osascript, shortcuts, permissions
```

### Current Agents
| Agent | Tools | Status |
|-------|-------|--------|
| SafariAgent | open_url, search_web, get_page_url, get_page_title | Working |
| FileAgent | read_file, write_file, list_files, move_file, delete_file | Working |
| NotesAgent | create_note, edit_note, search_notes, list_notes | Working (wired to VaultSyncService) |
| TerminalAgent | run_command | Working |
| AutomationAgent | get_ui_tree, click_element (semantic), type_text, run_shortcut | Working (semantic click via AX tree) |

### Current Planning
- LLM-based planning via local Qwen 3.5 4B with structured JSON output
- Heuristic fallback when model unavailable
- Risk-based confirmation gates (low/medium/high/critical)
- Inter-step data passing (_context key carries dependency outputs)
- Execution logging to SQLite

### Current Issues
1. **Planning quality**: Local 4B model sometimes generates invalid plans or wrong agent/tool combinations
2. **Error recovery**: Retries exist but no intelligent re-planning after failure
3. **No memory**: Agent doesn't learn from past executions
4. **No visual grounding**: When AX tree is sparse, agent is blind
5. **No multi-app workflows**: Can't chain actions across Safari → Notes → Terminal fluently
6. **No parallel execution**: Steps execute sequentially even when independent
7. **Sandbox constraints**: App Store sandbox limits CGEvent and AX access

---

## RESEARCH QUESTIONS

### 1. Agent Orchestration Architecture
- How do OpenClaw, NemoClaw, CoPaw, and other open-source agent frameworks structure their orchestration?
- What is the optimal task decomposition strategy for a local-first agent with a small (4B) model?
- How do production agent systems handle **re-planning** after step failures?
- What DAG execution strategies support parallel independent steps?
- How does Perplexity Computer implement its agent loop? What can we learn from their approach to UI automation?

### 2. Tool Use & Function Calling
- What are the best structured output formats for small local models (Qwen, Llama)?
- How do frameworks like LangChain, CrewAI, AutoGen, and Semantic Kernel handle tool schemas?
- What's the optimal few-shot prompt engineering strategy for a 4B model doing planning?
- How can we use **constrained decoding** (grammar-based sampling) in MLX to guarantee valid JSON tool calls?
- What ReAct / Plan-and-Execute / Tree-of-Thought patterns work best at the 4B parameter scale?

### 3. macOS Native Automation
- What are ALL the macOS automation APIs available? (Accessibility, Apple Events, Automator, Shortcuts, XPC, System Events, JXA, AppleScript, CGEvent, IOKit HID)
- How does **Hammerspoon** implement its Lua-to-macOS bridge? Can we port key patterns to Rust?
- How does **Karabiner-Elements** handle low-level input interception?
- What's the best way to build an **app-aware agent** that understands which app is frontmost and adapts its toolset?
- How can we use **Accessibility Inspector** patterns to build robust element selectors (role + title + hierarchy)?
- What XPC services can we leverage for automation within the sandbox?

### 4. Visual Grounding (Screen2AX)
- How does **OmniParser** (Microsoft) extract UI elements from screenshots?
- How does **SeeClick** / **CogAgent** / **Ferret-UI** map visual elements to actions?
- What VLM architectures can run locally on Apple Silicon for UI understanding?
- How can we combine AX tree + screenshot analysis for robust element targeting?
- What does Anthropic's Computer Use implementation look like under the hood?

### 5. Memory & Learning
- How do agent frameworks implement **episodic memory** (remembering past task executions)?
- What's the best way to use execution traces for **fine-tuning** the planning model?
- How can we implement **ODIA** (Offline Data-Informed Agent) training using our SQLite execution logs?
- What LoRA/QLoRA strategies work for fine-tuning Qwen 4B on agent-specific data?
- How does **Voyager** (Minecraft agent) implement its skill library? Can we adapt this for macOS automation?

### 6. Safety & Sandboxing
- How can an App Store sandboxed app still provide useful automation?
- What's the Accessibility API's behavior inside the sandbox?
- How do apps like **Raycast**, **Alfred**, and **Keyboard Maestro** handle automation permissions?
- What's the best UX for progressive permission escalation (start safe, unlock more as user trusts)?

### 7. MCP (Model Context Protocol) Integration
- How mature is the MCP ecosystem? What servers are most useful for a knowledge agent?
- How does **Claude Desktop** implement MCP tool routing?
- Can we run MCP servers as XPC services within the app bundle?
- What's the overhead of MCP JSON-RPC vs direct FFI for tool dispatch?

---

## OPEN SOURCE PROJECTS TO DEEPLY ANALYZE

### Agent Frameworks (analyze their code, not just docs)
1. **OpenClaw** (GitHub) — Open-source computer use agent. Analyze: orchestration loop, error recovery, screen parsing
2. **NemoClaw** (NVIDIA) — Agent framework with tool use. Analyze: planning strategies, multi-step execution
3. **CoPaw** — Collaborative agent framework. Analyze: multi-agent coordination, task decomposition
4. **AutoGen** (Microsoft) — Multi-agent conversation framework. Analyze: agent-to-agent communication patterns
5. **CrewAI** — Role-based agent orchestration. Analyze: agent role definitions, delegation patterns
6. **LangGraph** (LangChain) — Graph-based agent workflows. Analyze: DAG execution, state management
7. **Semantic Kernel** (Microsoft) — AI orchestration SDK. Analyze: plugin architecture, planner strategies

### macOS Automation
8. **Hammerspoon** — Lua-based macOS automation. Analyze: hs.application, hs.window, hs.eventtap modules
9. **Raycast Extensions** — How they handle tool dispatch and permission in a sandboxed context
10. **Accessibility-Toolkit** / **AXSwift** — Swift wrappers for AX APIs

### Vision & UI Understanding
11. **OmniParser** (Microsoft) — UI element extraction from screenshots
12. **SeeClick** — Visual grounding for UI agents
13. **Ferret-UI** (Apple) — Multimodal UI understanding model

### Perplexity & Commercial References
14. **Perplexity Computer** — How their desktop agent handles: screen reading, action execution, multi-app workflows, error recovery. What makes their UX feel seamless?
15. **Anthropic Computer Use** — Their implementation of computer control via screenshots + coordinate clicking

### Training & Memory
16. **Voyager** (NVIDIA) — Skill library pattern for agent learning
17. **AgentTuning** — Fine-tuning LLMs for agent capabilities
18. **FireAct** — Training language agents with execution feedback

---

## WHAT I WANT TO BUILD (future architecture)

### Phase 1: Fix & Harden (DONE — this session)
- ✅ Semantic click_element (AX tree → find element → click center)
- ✅ Real run_shortcut via Rust FFI
- ✅ Inter-step data passing
- ✅ Execution logging to SQLite
- ✅ jsonEscape crash fix
- ✅ Error recovery UI (retry/dismiss/expand)
- ✅ Permission auto-setup flow

### Phase 2: Intelligent Planning
- Constrained decoding for guaranteed valid JSON plans
- ReAct-style observe-think-act loop with AX tree as observation
- Re-planning after step failures (not just retry — generate new plan)
- Parallel step execution for independent tasks
- Plan caching (same task type → skip planning)

### Phase 3: Visual Grounding
- Screen2AX: when AX tree is sparse (<5 elements), capture screenshot → VLM → synthetic AX tree
- Multi-modal planning: model sees both AX tree and screenshot
- Element targeting: combine AX role/title with visual bounding box for robust clicks

### Phase 4: Memory & Learning
- Episodic memory: SQLite stores (task, plan, result, duration) tuples
- Skill library: successful plans saved as "recipes" for instant replay
- ODIA training: nightly fine-tune Qwen adapter on execution traces
- MoLoRA routing: multiple LoRA adapters for different task domains

### Phase 5: Multi-App Workflows
- App-aware context switching (detect frontmost app, load relevant tools)
- Cross-app data pipelines (Safari → extract → Notes → summarize)
- Workflow templates (repeatable multi-app sequences)
- Natural language macro recording ("watch what I do, then repeat")

---

## DELIVERABLES REQUESTED

1. **Architectural comparison** of all listed agent frameworks — what each does best
2. **Code-level analysis** of OpenClaw, NemoClaw, CoPaw orchestration loops
3. **macOS automation API deep dive** — every available API, sandbox behavior, best practices
4. **Visual grounding survey** — what models run locally on Apple Silicon, accuracy benchmarks
5. **Planning strategy comparison** — ReAct vs Plan-and-Execute vs Tree-of-Thought at 4B scale
6. **Memory/learning patterns** — how to go from execution logs to fine-tuned model
7. **Concrete Rust + Swift implementation plan** — what to port, what to write from scratch
8. **Safety architecture** — progressive permission model for App Store compliance
9. **Perplexity Computer analysis** — their UX patterns, what makes it feel magic
10. **Top 20 actionable improvements** ranked by impact/effort for Epistemos Omega

---

## REFERENCE FILES

The following files provide essential context about the current implementation:

1. `CLAUDE.md` — Engineering bible, architecture overview, all patterns
2. `docs/OMEGA_CONTINUATION_PROMPT.md` — What was built, what was broken, what was fixed
3. `docs/OMEGA_ARCHITECTURE.md` — 5-layer split, anti-drift anchors
4. `docs/future-work-audit.md` — 21 waves, 134 planned items
5. `Epistemos/Omega/Orchestrator/OrchestratorState.swift` — Current orchestration loop
6. `Epistemos/Omega/Agents/AutomationAgent.swift` — macOS UI automation agent
7. `Epistemos/Omega/Orchestrator/OmegaInferenceBridge.swift` — LLM planning prompt
8. `Epistemos/Omega/Inference/OmegaPlanningService.swift` — Planning + heuristic fallback
9. `omega-ax/src/uniffi_exports.rs` — Rust FFI: AX tree, clicks, shortcuts
10. `omega-ax/src/ax_tree.rs` — Accessibility tree walker implementation
