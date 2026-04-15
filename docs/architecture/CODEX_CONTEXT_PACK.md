# Codex Context Pack for New Sessions

## Identity
Epistemos is a local-first cognitive operating system, not a normal chatbot, not just a coding wrapper, and not just a PKM with AI attached.

## Non-negotiable truths
- Rust is the sole control-plane authority.
- `gguf`, `mlx`, and later `remote` are sibling runtimes.
- `gguf` owns primary local text generation.
- `mlx` is permanent and owns embeddings, helper models, adaptation, image generation, and Apple-native auxiliary workloads.
- No silent backend rerouting.
- No runtime self-escalates to cloud.
- No mid-generation backend switching.
- Public runtime contract stays pull-based.
- Serial GPU->SSD->GPU invariant must hold in streamed/fallback paths.
- Trust the OS page cache.
- No speculative expert prefetch during active decode.
- Base weights stay immutable.
- Adaptation is bounded, reversible, MLX-first, and helper-model-first.

## Architecture planes
- Interface layer
- Knowledge layer
- Control plane
- Execution plane
- Adaptation plane
- Oversight plane

## Agent Command Center
- Phase 5 includes a dedicated Agent Command Center / agent home, not just an inline chat box.
- It should be reachable from the landing/home toolbar and a global shortcut.
- The UX target is Apple-native, but the interaction model may borrow from Cursor, Antigravity, and OpenCode:
  - slash commands
  - skill selection
  - model / brain switching
  - MCP server / tool toggles
  - at-mention context attachment
  - a low-latency floating suggestion box
  - a right-side inspector panel for plan/review/summary and live execution state
- Advanced agentic controls that already exist in main chat should migrate into this dedicated Agent home instead of being duplicated across two full-featured surfaces.
- Main chat stays as the lighter conversational surface; the Agent home owns the full control stack such as plan mode, model picker, skills, slash commands, tool restrictions, and execution inspection.
- The command center is an explicit delegation layer, not a second control plane.
- SwiftUI owns the interactive shell and parsing surface; Rust still owns request compilation, routing, permissions, and runtime truth.

## Overseer
- The overseer is a supervisory role, not a fixed model family.
- Split conceptually into:
  - planner overseer
  - guardrail overseer
  - SSM memory sidecar
- SSM/Mamba belongs primarily to memory compression, not default planner identity.

## Agent hierarchy
- overseer -> main agent -> sub-agents
- sub-agents report upward
- no unrestricted swarm communication
- all inter-agent communication must be structured, budgeted, and logged

## Research placement
- KAN = graph/routing/reranking helper, not chat backbone
- TTT/LoRA = bounded MLX adaptation lane, not default main runtime behavior
- MoE = selective specialization and expert budgeting
- SSM/Mamba = memory compression helper lane
- image generation = MLX sidecar mode

## Required specs beyond Backend Interface Spec v1
1. Capability Handshake Spec
2. Compute Steering Spec
3. Adaptation Subsystem Spec

## Implementation rule
- audit first
- preserve MLX
- keep GGUF primary for main reasoning
- use explicit telemetry and fail closed
- do not widen scope casually
