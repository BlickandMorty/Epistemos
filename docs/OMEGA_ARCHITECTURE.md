# Epistemos Omega — Architecture

> **Index status**: SUPERSEDED-HISTORICAL — Omega retired per IMPLEMENTATION_PLAN_FROM_ADVICE.
> **Superseded by / Phase**: IMPLEMENTATION_PLAN_FROM_ADVICE.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## Overview

Omega is the agent/automation subsystem of Epistemos. It adds macOS-wide task execution capabilities through specialist agents, an MCP tool registry, and a plan-before-execute UX.

## 5-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 5: UX / Interaction Layer (Swift / SwiftUI)              │
│  OmegaPanel, PlanReviewView, ConfirmationSheet,                 │
│  ResearchRequestView, ExecutionProgressView                     │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 4: MLX Inference + Planning (Swift)                      │
│  OmegaInferenceBridge → TriageService, ToolCallParser,          │
│  OmegaPlanningService (LLM + heuristic fallback)                │
│         ↕ UniFFI Bridge ↕                                       │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 3: Agent Orchestration (Swift)                           │
│  OrchestratorState, TaskGraph (DAG), ConfirmationGate,          │
│  ResearchPauseHandler, 5 specialist agents                      │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 2: MCP Server & Tool Layer (Rust — omega-mcp)            │
│  MCPDispatcher, ToolRegistry, ExecutionLogger (SQLite WAL),     │
│  JSON-RPC 2.0 protocol types                                    │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 1: macOS Automation Foundation (Rust — omega-ax)         │
│  AX tree walker (ApplicationServices FFI), CGEvent input sim,   │
│  Permission checker (AXIsProcessTrusted)                        │
│  + Swift-side: osascript wrappers, ScreenCaptureKit             │
└─────────────────────────────────────────────────────────────────┘
```

## Rust Crates

| Crate | Purpose | Tests |
|-------|---------|-------|
| `omega-mcp` | MCP tool registry, execution logger, JSON-RPC 2.0 | 34 |
| `omega-ax` | AX tree walker, CGEvent input, permission checks | 8 |

## Specialist Agents

| Agent | Domain | Tools |
|-------|--------|-------|
| SafariAgent | Web browsing | open_url, get_page_url, get_page_title, search_web |
| FileAgent | File system (vault-scoped) | read_file, write_file, list_files, move_file, delete_file |
| NotesAgent | Epistemos notes | create_note, edit_note, search_notes, list_notes |
| TerminalAgent | Shell commands (allow-listed) | run_command |
| AutomationAgent | Generic macOS automation | get_ui_tree, click_element, type_text, press_key, run_shortcut |

## Data Flow

```
User task → OrchestratorState.submitTask()
         → OmegaPlanningService.generatePlan()
         → TaskGraph (DAG of AgentSteps)
         → ConfirmationGate (risk evaluation)
         → Agent.execute(step)
         → Tool execution (via omega-mcp registry)
         → ExecutionLogger (SQLite WAL)
         → AgentStepResult → UI update
```

## Training Integration

ODIA traces from the execution log feed into the Knowledge Fusion pipeline:
- ODIATraceGenerator reads execution results → ODIA-format JSONL
- TraceDataMixer implements 40/20/20/20 composition ratio
- MoLoRARouter provides per-token adapter routing
- CSISafeguard monitors for reward hacking during autoresearch
