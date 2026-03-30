# Sprint Omega-6: Context Compiler + Graph Visualizer
## Duration: 3-4 sessions | Priority: HIGH — the sprint that turns living memory into visible intelligence

Prerequisite: Sprint Omega-5 must be complete and verified.

---

## Pre-Read

```bash
cat CLAUDE.md
cat docs/AGENT_PROGRESS.md
cat docs/agent-system/LIVING_VAULT_ARCHITECTURE.md
cat docs/sprint-sessions/sprint-omega-5-living-vault.md
```

Confirm: "Architecture read. Sprint Omega-6: Context Compiler + Graph Visualizer. First task: context compiler."

---

## What This Sprint Does

Builds the prompt assembler and graph interfaces that let Epistemos read from its vault system like a model-specific cognitive substrate. After this sprint, the app can compile cache-optimized prompt stacks from registered vaults and render those vaults as an explorable graph with semantic zoom and inline node inspection.

## Prerequisite Check

Before starting, verify Sprint Omega-5 is complete:

```bash
cargo check --manifest-path agent_core/Cargo.toml 2>&1 | tail -5
cargo test --manifest-path agent_core/Cargo.toml -- vault_registry 2>&1 | tail -5
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5
./scripts/verify/omega_verify.sh --task omega5-9
```

If any of these fail, fix them before proceeding.

## Dependency Setup

Add the remaining Omega-6 dependency before touching graph tasks:

- `project.yml`
  - `Grape`
  - URL: `https://github.com/SwiftGraphs/Grape`
  - Product: `Grape`
  - Recommended version floor: `1.1.0`

Verify dependency resolution:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5
```

---

## Tasks

### Task 1: Context Compiler Core (Rust)

**Create:** `agent_core/src/context_compiler.rs`

**Requirements:**
- `ContextCompiler` struct that assembles prompts from a `VaultIdentity`
- `compile(query: &str, model: &str, vault_path: &Path) -> Result<CompiledContext, ContextCompilerError>`
- `CompiledContext` record:
  - `system_prompt`
  - `tools`
  - `skills`
  - `memory`
  - `few_shot_examples`
  - `rag_context`
  - `conversation_history`
  - `cache_breakpoints: Vec<usize>`
- Cache-optimal ordering:
  1. Tool definitions
  2. Base system prompt
  3. Active skills
  4. Core memory
  5. Few-shot examples
  6. RAG context
  7. Conversation history
  8. Current user message
- Stable prefix should maximize prompt-cache reuse
- Over-budget compression phases:
  - whitespace trim
  - summarize old turns
  - drop low-strength memory
  - reduce examples

**Wire into:** `agent_core/src/lib.rs`

**Verify:**
```bash
grep -c "ContextCompiler\|compile\|CompiledContext\|cache_breakpoints" agent_core/src/context_compiler.rs
cargo test --manifest-path agent_core/Cargo.toml -- context_compiler 2>&1 | tail -5
```

### Task 2: Skill Router (Rust)

**Create:** `agent_core/src/context_compiler/skill_router.rs`

**Requirements:**
- `SkillRouter`
- `SkillMetadata`
- `route(query_embedding, model) -> Vec<SkillMetadata>`
- Embedding-based top-3 selection
- Filter by `compatible_models`
- Progressive disclosure: metadata first, full skill body on demand

**Verify:**
```bash
grep -c "SkillRouter\|SkillMetadata\|route" agent_core/src/context_compiler/skill_router.rs
cargo test --manifest-path agent_core/Cargo.toml -- skill_router 2>&1 | tail -5
```

### Task 3: Few-Shot Example Bank (Rust)

**Create:** `agent_core/src/context_compiler/example_bank.rs`

**Requirements:**
- `ExampleBank`
- `Example`
- `retrieve(query, k) -> Vec<Example>`
- `record_outcome(example_id, score)`
- Default `k=3`, cap `k=5`
- Order examples weakest → strongest so best example lands last

**Verify:**
```bash
grep -c "ExampleBank\|Example\|retrieve\|record_outcome" agent_core/src/context_compiler/example_bank.rs
cargo test --manifest-path agent_core/Cargo.toml -- example_bank 2>&1 | tail -5
```

### Task 4: Graph Data Model (Swift)

**Create:** `Epistemos/Views/Graph/GraphDataModel.swift`

**Requirements:**
- `GraphNode`
- `GraphEdge`
- `NodeType`
- `VaultGraphBuilder`
- Reads vault files and converts them into graph nodes
- Supports incremental diff-based updates

**Verify:**
```bash
grep -c "GraphNode\|GraphEdge\|VaultGraphBuilder\|NodeType" Epistemos/Views/Graph/GraphDataModel.swift
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -3
```

### Task 5: Agent Graph View (Swift)

**Create:** `Epistemos/Views/Graph/AgentGraphView.swift`

**Requirements:**
- Uses Grape force-directed graph primitives
- Colors and sizes nodes by semantic type
- Supports selection, pan, zoom, and vault filter state
- Targets 60fps for ~2K nodes

**Verify:**
```bash
grep -c "AgentGraphView\|Grape\|GraphNode" Epistemos/Views/Graph/AgentGraphView.swift
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -3
```

### Task 6: Semantic Zoom Controller (Swift)

**Create:** `Epistemos/Views/Graph/SemanticZoomController.swift`

**Requirements:**
- `ZoomLevel`
- `SemanticZoomController`
- Levels:
  - `cosmic`
  - `constellation`
  - `solarSystem`
  - `planet`
  - `surface`
- Gesture-driven transitions
- Spring-based animation state

**Verify:**
```bash
grep -c "ZoomLevel\|SemanticZoomController\|cosmic\|constellation" Epistemos/Views/Graph/SemanticZoomController.swift
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -3
```

### Task 7: Node Detail Panel + Full Verification (Swift)

**Create:** `Epistemos/Views/Graph/NodeDetailPanel.swift`

**Requirements:**
- Shows content, strength, importance, and change history for the selected node
- Supports inline edit → diff preview → commit
- Includes pin / boost / delete actions
- Finish with a full Omega-6 verification sweep

**Verify:**
```bash
grep -c "NodeDetailPanel\|history\|strength" Epistemos/Views/Graph/NodeDetailPanel.swift
cargo test --manifest-path agent_core/Cargo.toml 2>&1 | tail -5
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5
./scripts/verify/omega_verify.sh --quick
```
