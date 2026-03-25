# Audit Handoff: Omega Phases Ω10-Ω14

**Commit**: `75e1d1db` on `feature/knowledge-fusion-v1`
**Date**: 2026-03-24
**Scope**: 22 files changed, 2892 insertions, 14 new Swift files

## What to Verify

### 1. Build & Tests (Start Here)
```bash
# Swift build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep -E "BUILD|error:"

# Rust tests
cd omega-mcp && cargo test 2>&1 | tail -3
cd ../omega-ax && cargo test 2>&1 | tail -3
cd ../graph-engine && cargo test 2>&1 | grep "test result"
```
Expected: BUILD SUCCEEDED, 89/89, 10/10, 2432/2432.

---

### 2. Phase Ω10 — Bug Fixes (Modified Files)

**ResearchPause.swift** — Was polling with `while sleep(100ms)`, now uses `CheckedContinuation`.
- Check: `requestResearch()` suspends via `withCheckedContinuation`
- Check: `provideResponse()` and `skip()` call `continuation.resume()`
- Check: no `Task.sleep` or polling loop remains

**ExecutionProgressView.swift** — Added "Edit Plan" button.
- Check: button appears only when `hasFailed` is true
- Check: calls `orchestrator.editPlan()`

**OrchestratorState.swift** — Added `editPlan()` method.
- Check: clears execution state but preserves `currentTaskDescription`
- Check: calls `taskGraph.reset()` which sets status to `.idle`

**OmegaPanel.swift** — Auto-populates input bar on edit plan.
- Check: `onChange(of: orchestrator.taskGraph.status)` pre-fills `taskInput`

---

### 3. Phase Ω11 — Constrained Decoding (New Files)

**ToolSchemaGrammar.swift** (`Omega/Inference/`)
- Check: `compilePlanningGrammar()` produces valid EBNF with tool/agent/risk enums
- Check: `compileSingleToolCallGrammar()` for device action JSON
- Check: `resolveAgent()` mapping matches OmegaPlanningService's tool→agent map

**ConstrainedDecodingService.swift** (`Omega/Inference/`)
- Check: `GrammarConstrainedGenerator` protocol is `Sendable`
- Check: `isAvailable` is false until `setGenerator()` is called
- Check: grammar caching uses hash comparison

**MLXConstrainedGenerator.swift** (`Omega/Inference/`)
- Check: `#if canImport(MLXLMCommon)` guards everywhere
- Check: `JSONSchemaLogitProcessor` conforms to `LogitProcessor` (prompt/process/didSample)
- Check: `process(logits:)` penalizes EOS tokens when depth > 0
- **Known limitation**: This is a Tier 2 (soft biasing) implementation. Full token-level masking requires tokenizer vocabulary access. The architecture is correct but constrained decoding is partial — it prevents premature stopping but doesn't guarantee perfect JSON structure.

**OmegaInferenceBridge.swift** (Modified)
- Check: tries constrained path first, falls back to unconstrained
- Check: `constrainedDecoding` is optional, nil-safe

---

### 4. Phase Ω12 — Dual-Brain Foundation (New Files)

**HardwareTierManager.swift** (`Omega/Inference/`)
- Check: `detectTier()` reads `machdep.cpu.brand_string` via sysctl
- Check: `detectANE()` checks for "Apple" in chip name
- Check: `detectMetalGPU()` uses `MTLCreateSystemDefaultDevice()`
- Check: `DualBrainConfig.recommended()` returns sensible model pairs per tier
- Check: `supportsDualModel` requires ≥16GB + ANE + Metal

**DeviceAgentService.swift** (`Omega/Inference/`)
- Check: `DeviceInferenceBackend` protocol is `Sendable`
- Check: `SharedGPUBackend` wraps TriageService via `withCheckedThrowingContinuation`
- Check: `resolveUIAction()` builds prompt with AX tree + intent, returns `DeviceActionResult`
- Check: `verifyAction()` returns confidence 0.0-1.0, guards `.isFinite`

**DualBrainRouter.swift** (`Omega/Inference/`)
- Check: `classify()` routing table matches Anchor 3 from master prompt
- Check: falls back to Brain 1 when `deviceAgent.isReady` is false
- Check: routing stats tracked (brain1Count, brain2Count, fallbackCount)

---

### 5. Phase Ω13 — Computer Use Stack (New Files)

**AXSemanticSelector.swift** (`Omega/Vision/`)
- Check: `parse()` handles `//Role[@Attr='Value']` and `contains()` syntax
- Check: `resolve()` filters AX tree JSON elements by role + predicates
- Check: `resolveBest()` prefers interactive matches

**VisualVerifyLoop.swift** (`Omega/Vision/`)
- Check: `walkAxTreeJson(pid: Int64(pid))` — Int64 cast is correct for FFI
- Check: `captureBeforeState()` returns `VerifyToken` with AX snapshot
- Check: `verify()` tries Brain 2 LLM first, falls back to diff-based
- Check: rolling success rate capped at 20 entries

**Screen2AXFusion.swift** (`Omega/Vision/`)
- Check: `sparseThreshold = 10` (updated from 5 based on R5 research)
- Check: `perceive()` pipeline: AX → check count → Vision OCR fallback
- Check: Apple Vision `VNRecognizeTextRequest` with `.fast` recognition level
- Check: OCR regions merged as synthetic `AXStaticText` with `is_synthetic: true`

**Screen2AXService.swift** (Modified)
- Check: threshold changed from `< 5` to `< 10`

---

### 6. Phase Ω14 — Knowledge Graph Integration (New Files)

**AgentGraphMemory.swift** (`Omega/Knowledge/`)
- Check: `recordExecution()` creates `.idea` node + `.source` nodes + `.tag` nodes
- Check: deduplicates sources via `graphStore.node(bySourceId:type:)`
- Check: `recall()` uses `graphStore.fuzzySearch()`
- Check: `contextFor()` does BFS expansion via `graphStore.connected(to:maxDepth:)`
- Check: `extractTags()` has reasonable stop words, limits to 3 tags

**RecipeGraphSkills.swift** (`Omega/Knowledge/`)
- Check: `syncRecipesToGraph()` calls MCP dispatch for recipe listing
- Check: creates `tool:*` tag nodes for each tool in recipe steps
- Check: `suggestRecipes()` filters for `sourceId?.hasPrefix("recipe:")`

**GhostBrainCoauthor.swift** (`Omega/Knowledge/`)
- Check: `buildContext()` respects `maxTokenBudget` (chars * 4 estimate)
- Check: `buildContinuationContext()` follows `.expands` and `.supports` edges
- Check: `suggestWikilinks()` returns note neighbors from graph
- Check: `isEnabled` flag allows disabling ghost brain

**OrchestratorState.swift** (Modified)
- Check: `agentGraphMemory` is `weak var` (not `private(set)`)
- Check: `executePlan()` calls `agentGraphMemory?.recordExecution()` after completion

---

### 7. Wiring (AppBootstrap + AppEnvironment)

**AppBootstrap.swift** — Check initialization order:
1. `constrainedDecoding = ConstrainedDecodingService()` (property)
2. `hardwareTierManager = HardwareTierManager()` (property)
3. `deviceAgent = DeviceAgentService(hardwareTier:)` (in init)
4. `dualBrainRouter = DualBrainRouter(hardwareTier:deviceAgent:)` (in init)
5. `screen2AXFusion = Screen2AXFusion(screenCapture:)` (in init)
6. `visualVerifyLoop = VisualVerifyLoop(screenCapture:deviceAgent:)` (in init)
7. `orchestratorState.registerAgents(...)` — passes constrainedDecoding
8. `constrainedDecoding.setGenerator(MLXConstrainedGenerator(...))` — after register
9. `agentGraphMemory = AgentGraphMemory(graphStore:)` (in init)
10. `recipeGraphSkills = RecipeGraphSkills(graphStore:mcpBridge:)` (in init)
11. `ghostBrainCoauthor = GhostBrainCoauthor(graphStore:agentMemory:)` (in init)
12. `orchestratorState.agentGraphMemory = agentGraphMemory` — after graph memory init

**AppEnvironment.swift** — Check all new `.environment()` calls present:
- `constrainedDecoding`, `hardwareTierManager`, `dualBrainRouter`
- `screen2AXFusion`, `visualVerifyLoop`, `ghostBrainCoauthor`

---

### 8. Known Issues / Intentional Gaps

1. **MLXConstrainedGenerator** is Tier 2 (soft logit biasing), not full token masking. Upgrade path: mlx-swift-structured library by @petrukha-ivan when verified.
2. **RecipeGraphSkills** dispatches via JSON-RPC `recipes/list` which may not be a registered MCP method yet — will return `[]` gracefully.
3. **DeviceAgentService** uses `SharedGPUBackend` (shares Brain 1 model). Dedicated ANE backend comes in Ω15+ when custom Mamba models are distilled.
4. **Screen2AXFusion** Vision OCR path is async but called from `@MainActor` context — VNImageRequestHandler.perform is synchronous on the calling thread inside the continuation.
5. **Xcode project IDs**: One collision was manually fixed (AXSemanticSelector reused HardwareTierManager's ID). Verify no duplicate IDs in pbxproj if Xcode acts weird.

---

### 9. Research Results (Empirical, Run on This Machine)

**R5 — AX Sparsity**: 10/11 (91%) apps have FULL AX metadata. Screen2AX fallback rarely needed.
**R4 — OmniParser**: YOLO 260ms (OK), EasyOCR 20s (rejected), Apple Vision OCR used instead.

---

### 10. Files Summary

| New File | Phase | Lines |
|----------|-------|-------|
| `Omega/Inference/ToolSchemaGrammar.swift` | Ω11 | ~190 |
| `Omega/Inference/ConstrainedDecodingService.swift` | Ω11 | ~100 |
| `Omega/Inference/MLXConstrainedGenerator.swift` | Ω11 | ~220 |
| `Omega/Inference/HardwareTierManager.swift` | Ω12 | ~220 |
| `Omega/Inference/DeviceAgentService.swift` | Ω12 | ~230 |
| `Omega/Inference/DualBrainRouter.swift` | Ω12 | ~130 |
| `Omega/Vision/AXSemanticSelector.swift` | Ω13 | ~190 |
| `Omega/Vision/VisualVerifyLoop.swift` | Ω13 | ~160 |
| `Omega/Vision/Screen2AXFusion.swift` | Ω13 | ~230 |
| `Omega/Knowledge/AgentGraphMemory.swift` | Ω14 | ~200 |
| `Omega/Knowledge/RecipeGraphSkills.swift` | Ω14 | ~200 |
| `Omega/Knowledge/GhostBrainCoauthor.swift` | Ω14 | ~200 |

Total: ~2,270 lines of new Swift code across 12 files.
