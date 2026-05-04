# Session Synthesis: Feature Audit → Implementation Plan

**Date:** 2026-04-09  
**Session type:** Research audit + implementation planning (no code written to production files)  
**Output:** `IMPLEMENTATION_PLAN_FEATURES.md` (new file, 34KB)  
**Auditor:** Kimi Code CLI → Handoff to Codex for structured release audit

---

## Executive Summary

This session performed a **brutally honest ground-truth audit** of four major architectural features claimed in a research document against the actual Epistemos codebase. The audit found that three of four features exist primarily in `agent_core` (debug-only, not shipping), one is partially staged, and one (TurboQuant) has zero implementation.

Following the audit, a **detailed 5-phase implementation plan** was written to actually build these features into the shipping product.

**⚠️ CRITICAL WARNINGS FOR AUDIT:**
1. **agent_core is NOT linked in release builds** — `project.yml` does not include `-lagent_core` in `OTHER_LDFLAGS`. Any feature in `agent_core/` is invisible to the live app.
2. **Multiple Swift files contain reimplementations** of what agent_core provides via FFI — these are "shadow implementations" that drift from the Rust source of truth.
3. **Metal kernels are compiled but NOT invoked** — 14 Mamba2 kernels exist, compile, pass tests, but are never called during live inference.
4. **TurboQuant is referenced in 5+ planning docs but has ZERO implementation code** — this is the most severe documentation/reality gap.

---

## Part 1: Competitor Deep Dives (Completed)

Four competitor repositories were audited for adoptable patterns:

### 1. Logseq (ClojureScript/Electron/DataScript)
**Repo:** `logseq/logseq`  
**Key findings:**
- Reactive DataScript/Datalog query engine — every block is a datom, queries auto-recompute
- File-based graph storage with bidirectional sync to DataScript
- Block-level references (`((block-id))`) with live transclusion
- **Adoptable for Epistemos:** The query reactivity model could inform the SwiftData → GraphStore sync layer

### 2. Obsidian (Closed source/Electron)
**Audit method:** Plugin API analysis, community plugin source  
**Key findings:**
- Vault-as-folder with `.obsidian/` config directory
- Plugin sandbox with restricted file system access
- Canvas view for spatial note arrangement
- **Adoptable for Epistemos:** The canvas spatial model could inform the hyperbolic topology visualization

### 3. OpenClaw (TypeScript/Node/Gateway)
**Repo:** `cline/cline` (formerly OpenClaw)  
**Key findings:**
- Gateway pattern for model routing with fallback chains
- Skill/compaction system with automatic context management
- Tool use with structured JSON output validation
- **Adoptable for Epistemos:** The gateway fallback chain pattern is already implemented in TriageService; the compaction system could inform the Mamba distillation design

### 4. Hermes (Python/Nous Research)
**Repo:** `NousResearch/Hermes`  
**Key findings:**
- Learning loop with Honcho integration for user memory
- Progressive training with synthetic data generation
- Tool calling with structured output schemas
- **Adoptable for Epistemos:** The learning loop pattern maps to GEPA skill evolution

---

## Part 2: File-by-File Ground Truth Audit

Each claim in the research document was checked against actual source code. Files were read in full, not summarized.

### Feature 1: Hyperbolic Topo-Spatial Memory

**File audited:** `agent_core/src/storage/hyperbolic_topology.rs` (613 LOC)  

**What exists (REAL):**
- `HyperbolicPoint` — Poincaré coordinates (r, theta) with correct hyperbolic distance formula
- `VaultNodeMetrics` — Complexity Weight (Cw), Gravity (Gv), Volatility (Vs)
- `build_topology()` — walks directory tree, assigns `r = tanh(depth × 0.3)`
- `topology_to_agent_context()` — generates compact LLM-readable vault map
- 9 unit tests covering coordinates, distances, complexity ranges

**What does NOT exist (ASPIRATIONAL):**
- ❌ `should_pierce_blanket()` with FEP math — the blanket summary is just a string, no runtime decision
- ❌ Variational Free Energy calculation: `F = Complexity - Accuracy`
- ❌ Integration with SwiftData note graph — only walks filesystem

**Status:** Mathematical foundation is real and tested. FEP decision layer is described in comments, not implemented.

---

### Feature 2: Holographic KV-Cache Resonance

**Files audited:**
- `agent_core/src/storage/neural_cache.rs` (373 LOC)
- `LOCAL_MODEL_STACK_ADVICE.md` (planning doc)
- `EPISTEMOS-NORTH-STAR.md` (roadmap)

**What exists (REAL):**
- 3-tier cache: Hot (`<1ms`), Warm (`<5ms`), Cold (`<50ms`)
- `temporal_retrieve(minutes_ago, window_minutes)` — filters cached facts by timestamp
- Comment mentions "TurboQuant temporal encoding" but this is naming only

**What does NOT exist (ASPIRATIONAL):**
- ❌ **Zero code for TurboQuant** — grepped entire repo for `turboquant`, `TQ3`, `fwht`, `lloyd-max`, `codebook` — no implementation
- ❌ No `kv_cache_resonance_sweep` function anywhere
- ❌ No FWHT (Fast Walsh-Hadamard Transform) kernel
- ❌ No asymmetric quantization path (q8_0-K / turbo4-V)
- ❌ No KV-cache quantization — Neural Cache is for **semantic fact caching**, not KV compression

**Status:** Neural Cache is a real tiered retrieval system. TurboQuant and resonance sweep are pure research aspirations with no code.

---

### Feature 3: Continuous SSM Distillation

**Files audited:**
- `epistemos-core/src/ssm_state.rs` (502 LOC)
- `agent_core/src/storage/ssm_state.rs` (similar, debug-only)
- `Epistemos/Vault/SSMStateService.swift` (290 LOC)
- `Epistemos/Shaders/Mamba2/*.metal` (4 files, 14 kernels)
- `Epistemos/Engine/MetalRuntimeManager.swift`
- `MAMBA2_PHASE1_COMPLETION.md`

**What exists (REAL):**
- SSM binary format v2: magic `0x4D414D42` ("MAMB"), 60-byte header, f16 layer data
- `save_ssm_state()` / `load_ssm_state()` / `list_ssm_states()` / `prune_ssm_states()`
- `SSMStateService.saveMLXCache()` / `loadMLXCache()` — uses MLX-Swift's native prompt cache API
- `NightBrainService` has `ssmStatePruning` job
- 14 Metal kernels compiled and passing tests:
  - `segsum_stable.metal` — 2 kernels
  - `inter_chunk_scan.metal` — 4 kernels  
  - `elementwise_ssm_helpers.metal` — 5 kernels
  - `direct_conv.metal` — 3 kernels
- `MetalRuntimeManager.runBenchmark()` — synthetic benchmarks

**What does NOT exist (ASPIRATIONAL):**
- ❌ **No `DistillationEngine` actor** — no Swift file with this name
- ❌ **No continuous overflow distillation** — SSM state is saved as atomic snapshots, not incrementally fed
- ❌ **Custom Metal is NOT live backend** — `MAMBA2_PHASE1_COMPLETION.md` explicitly states: "token generation still runs through MLX"
- ❌ **No `Mamba2ForwardPass.swift`** — core remaining engineering work per implementation guide
- ❌ No MLX cache extension for token-level eviction

**Status:** SSM persistence is production-ready. Custom kernels exist but are not invoked. Distillation loop does not exist.

---

### Feature 4: Genetic-Pareto Prompt Evolution (GEPA)

**Files audited:**
- `agent_core/src/evolution/mutation_proposer.rs` (316 LOC)
- `Epistemos/Vault/SkillEvolutionService.swift` (873 LOC)
- `Epistemos/State/NightBrainService.swift` (377 LOC)
- `Epistemos/Vault/VaultLifecycleService.swift` (793 LOC)

**What exists (REAL — most complete feature):**

**Rust side:**
- `propose_mutation()` — takes skill content + trace pattern, returns `SkillMutation`
- Four improvement signals: `FrequentRetries`, `SlowExecution`, `ConsistentFailure`, `UnusedCapability`
- Constraint gates: size ≤15KB, semantic similarity >0.80 (via `memory_classifier::embed_text_public`)
- Version incrementing (v1 → v2 → v3)
- 7 unit tests

**Swift side:**
- `SkillEvolutionService.analyzeTraces()` — loads vault + harness JSONL traces
- `ImprovementSignal.detectSignals()` — heuristic detection with thresholds
- `proposeMutation()` — calls Rust FFI `proposeSkillMutation`
- `autoProposeMutations()` — batch analysis across all skills
- `approveMutation()` / `rejectMutation()` — versioned skill writes with diff tracking
- `NightBrainService` calls `skillEvolutionAnalysis` in daily pipeline

**Simplification (noted):**
- Constraint check uses **two boolean gates** (size + semantic similarity), not multi-objective Pareto frontier
- No genetic algorithm with crossover/mutation operators
- No DSPy integration — mutations are template-based heuristics

**Status:** GEPA infrastructure is the most complete of the four features. Trace analysis, signal detection, mutation proposal, and versioned writing are all real.

---

## Part 3: FFI Boundary Audit

**Critical finding: agent_core is NOT built or linked.**

### Build Configuration (`project.yml`)

**Linked libraries (`OTHER_LDFLAGS`):**
```
-lgraph_engine -lomega_mcp -lomega_ax -lepistemos_core
```

**NOT linked:** `-lagent_core`

**Build scripts (`preBuildScripts`):**
```bash
build-rust.sh        # → libgraph_engine.a
build-omega-mcp.sh   # → libomega_mcp.dylib
build-omega-ax.sh    # → libomega_ax.dylib
build-epistemos-core.sh # → libepistemos_core.dylib
```

**No build script for agent_core.**

### FFI Call Patterns

**epistemos-core** (UDL-based UniFFI):
- Swift: `import epistemos_coreFFI`
- Pattern: Free functions in `src/uniffi_exports.rs`, declared in `.udl`
- Used by: `NoteFileStorage.swift` (integrity checks)

**agent_core** (proc-macro UniFFI):
- Swift: `import agent_core` (guarded by `#if canImport`)
- Only used by: `StreamingDelegate.swift`
- **Always falls back to stub** because agent_core is not linked

### Shadow Implementations (Swift reimplements what Rust provides)

| Rust Function (agent_core) | Swift "Shadow" | Location |
|---------------------------|----------------|----------|
| `detect_vault_contradictions` | `detectVaultContradictions()` | `VaultLifecycleService.swift:~380` |
| `generate_session_graph` | `generateSessionGraph()` | `VaultLifecycleService.swift:~290` |
| `analyze_skill_traces` | `analyzeSkillTraces()` | `VaultLifecycleService.swift:~430` |
| `propose_skill_mutation` | `proposeSkillMutation()` | `VaultLifecycleService.swift:~470` |
| `list_registered_skills` | `listRegisteredSkills()` | `VaultLifecycleService.swift:~500` |

**Problem:** These Swift functions reimplement the Rust logic locally. They have the same names but different implementations. The Rust versions are more sophisticated (e.g., Rust `propose_skill_mutation` has constraint gates; Swift version has a simple heuristic).

**Root cause:** agent_core is not linked, so Swift had to reimplement.

---

## Part 4: Overwritten / Scaffolded / Drifted Code

### Category 1: Overwritten by Previous Agents

**`VaultLifecycleService.swift`** — Contains Swift reimplementations that are **simpler** than what existed in agent_core:

- `proposeSkillMutation()` in Swift (lines ~470-490): Simple heuristic that checks `failureCount > successCount`, appends a static "Reliability Notes" section
- `propose_mutation()` in Rust: Full constraint gates (size ≤15KB, semantic similarity >0.80), four improvement signal types, version incrementing

**The Rust version is better.** The Swift version was written because the agent didn't read the Rust source first, or because agent_core wasn't available at build time.

**`SSMStateService.swift`** — Uses MLX-Swift's `savePromptCache` / `loadPromptCache` instead of the Rust `ssm_state.rs` FFI. The Rust binary format is described as "fallback for custom runtime" but the FFI functions are never called from Swift.

### Category 2: Scaffolded but Not Wired

**MetalRuntimeManager.swift:**
- `compileKernels()` — real, compiles all 14 kernels
- `runBenchmark()` — real, runs synthetic tests
- **Missing:** `executeForwardPass()` — no method exists that actually runs Mamba2 generation using these kernels
- **Missing:** Integration with `TriageService` or any inference path

**Hyperbolic topology:**
- Rust code is complete (613 LOC)
- No Swift service exists to call it
- No FFI exports in epistemos-core
- `HyperbolicTopologyService` does not exist

**Neural Cache:**
- Rust code is complete (373 LOC)
- No Swift service exists
- No chat command (`/recent`) exists
- No FFI exports in epistemos-core

### Category 3: Configuration Drift

**`project.yml` vs actual build:**
- `project.yml` references `build-rust/swift-bindings/epistemos_core.swift` and `epistemos_coreFFI` module
- But `agent_core` is not in the sources list, not in linker flags, not in build scripts
- The `#if canImport(agent_core)` in `StreamingDelegate.swift` is dead code in release builds

**`EpistemosConfig.swift`:**
- Has `nightBrainEnabled`, `nightBrainRequiresAC`, `nightBrainMinIdleSeconds`
- **Missing:** `gepaAutoPropose`, `gepaMinTraces`, `gepaSizeLimitKB` (referenced in plan but not in code)

---

## Part 5: Implementation Plan Written

**File created:** `IMPLEMENTATION_PLAN_FEATURES.md` (34KB)

**5 phases:**

| Phase | Feature | Key Files to Create/Modify |
|-------|---------|---------------------------|
| 1 | GEPA | `epistemos-core/src/evolution/mutation_proposer.rs`, `VaultLifecycleService.swift`, Settings UI |
| 2 | Hyperbolic Topology | `epistemos-core/src/topology/hyperbolic.rs`, `HyperbolicTopologyService.swift` |
| 3 | Neural Cache | `epistemos-core/src/cache/neural.rs`, `NeuralCacheService.swift`, chat command |
| 4 | Mamba Distillation | Design doc only — blocked on MLX extensions |
| 5 | TurboQuant | Deferred — 10+ week research project |

**Pattern for all phases:**
1. Port Rust module from agent_core → epistemos-core
2. Add `#[derive(uniffi::Record)]` to structs
3. Export free functions in `uniffi_exports.rs`
4. Declare in `epistemos_core.udl`
5. Regenerate bindings: `bash build-epistemos-core.sh`
6. Create Swift service actor
7. Wire to NightBrain or TriageService
8. Test: `cargo test` + `xcodebuild test`

---

## Part 6: Structured Release Audit for Codex

### Audit Task 1: FFI Completeness

**Verify every FFI function is callable from Swift:**

```bash
# 1. Build epistemos-core
cd epistemos-core && cargo build

# 2. Generate bindings
bash build-epistemos-core.sh

# 3. Check Swift bindings file exists
ls build-rust/swift-bindings/epistemos_core.swift
ls build-rust/swift-bindings/epistemos_coreFFI/

# 4. Verify no agent_core references in release build
grep -r "canImport(agent_core)" Epistemos/ --include="*.swift"
# Should only find: StreamingDelegate.swift (expected, has fallback)

# 5. Verify agent_core is NOT in linker flags
grep "OTHER_LDFLAGS" project.yml
# Should NOT contain: agent_core
```

**Expected result:** All new FFI functions appear in generated Swift bindings.

### Audit Task 2: Shadow Implementation Replacement

**For each Swift "shadow" function, verify it calls Rust FFI:**

| Swift Function | Should Call | Current Status |
|----------------|-------------|----------------|
| `VaultLifecycleService.proposeSkillMutation()` | `proposeSkillMutation()` (Rust) | Pure Swift heuristic |
| `VaultLifecycleService.detectContradictions()` | `detect_vault_contradictions()` (Rust) | Pure Swift heuristic |
| `VaultLifecycleService.generateGraphForSession()` | `generate_session_graph()` (Rust) | Pure Swift implementation |

**Audit method:**
1. Read the Swift function
2. Verify it has `#if canImport(epistemos_coreFFI)` path
3. Verify FFI call is primary, Swift fallback is secondary
4. Verify FFI function exists in Rust

### Audit Task 3: Feature Completeness Matrix

| Feature | Rust Code | FFI Export | Swift Service | Wired to UI | NightBrain Job | Tests |
|---------|-----------|------------|---------------|-------------|----------------|-------|
| GEPA mutation | ✅ agent_core | ❌ not in epistemos-core | ❌ not wired | ❌ no settings | ✅ calls Swift version | ✅ Rust tests |
| Hyperbolic topology | ✅ agent_core | ❌ not in epistemos-core | ❌ no service | ❌ no UI | ❌ no job | ✅ Rust tests |
| Neural Cache | ✅ agent_core | ❌ not in epistemos-core | ❌ no service | ❌ no command | ❌ no job | ✅ Rust tests |
| SSM persistence | ✅ epistemos-core | ⚠️ exists but unused | ✅ SSMStateService | ✅ Settings | ✅ ssmStatePruning | ✅ Rust + Swift |
| Metal kernels | ✅ 14 compiled | N/A | ✅ MetalRuntimeManager | ❌ no UI | ❌ no job | ✅ benchmark |
| TurboQuant | ❌ no code | ❌ no export | ❌ no service | ❌ no UI | ❌ no job | ❌ no tests |

### Audit Task 4: Integration Flow Verification

**For each feature, trace the complete user journey:**

**GEPA:**
1. User uses a skill multiple times → traces written to vault
2. NightBrain runs (24h interval, idle check) → `skillEvolutionAnalysis` job
3. `VaultLifecycleService.runEvolutionSweep()` called
4. Should: Call Rust `proposeSkillMutation()` via FFI
5. Should: Return mutation proposal if gates pass
6. Should: Show in `SkillEvolutionView` for user approval
7. Should: Write versioned SKILL.md on approval

**Current state:** Steps 1-3 work. Step 4 uses Swift heuristic, not Rust. Steps 5-7 work.

**Hyperbolic Topology:**
1. User searches vault → `VaultSearchService.rankedSearch()`
2. Should: Call `HyperbolicTopologyService.topology(for:)`
3. Should: Boost results using gravity metrics
4. Should: Show topology in graph view

**Current state:** No service exists. Search is pure BM25.

**Neural Cache:**
1. User types `/recent <query>` in chat
2. Should: Call `NeuralCacheService.retrieveLastDays()`
3. Should: Return temporally-filtered facts
4. Should: Inject into prompt context

**Current state:** No command exists. No service exists.

### Audit Task 5: Build Verification

**Full build must pass:**
```bash
# Rust tests
cd epistemos-core && cargo test
cd graph-engine && cargo test

# Swift build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build

# Swift tests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test

# Verify no warnings about missing agent_core
grep -i "agent_core" build_output.txt || echo "No agent_core references — good"
```

### Audit Task 6: Documentation Accuracy

**Verify these documents match reality:**

| Document | Claim | Reality | Status |
|----------|-------|---------|--------|
| `EPISTEMOS-NORTH-STAR.md` Phase 21 | "TurboQuant (PolarQuant + QJL)" | Zero implementation | ❌ OVERSTATED |
| `MAMBA2_PHASE1_COMPLETION.md` | "Custom Metal is NOT live backend" | Accurate | ✅ CORRECT |
| `AI_VAULT_RUNTIME_AUDIT.md` | "agent_core: DEBUG ONLY" | Accurate | ✅ CORRECT |
| `AGENTS.md` | "Hyperbolic Topology in AgentGraphMemory" | No such integration | ❌ OVERSTATED |
| Research doc (user's) | "FEP blanket piercing at runtime" | `should_pierce_blanket` doesn't exist | ❌ OVERSTATED |

---

## Part 7: Specific File States

### Files That Are Complete and Correct

| File | Lines | Status | Notes |
|------|-------|--------|-------|
| `agent_core/src/evolution/mutation_proposer.rs` | 316 | ✅ Complete | Real constraint gates, 7 tests |
| `agent_core/src/storage/hyperbolic_topology.rs` | 613 | ✅ Complete | Poincaré math correct, FEP missing |
| `agent_core/src/storage/neural_cache.rs` | 373 | ✅ Complete | 3-tier cache, temporal retrieval |
| `epistemos-core/src/ssm_state.rs` | 502 | ✅ Complete | Binary format v2, all operations |
| `Epistemos/State/NightBrainService.swift` | 377 | ✅ Complete | 10 jobs, checkpoint resume |
| `Epistemos/Vault/SkillEvolutionService.swift` | 873 | ✅ Complete | Full GEPA pipeline |
| `Epistemos/Shaders/Mamba2/*.metal` | ~800 | ✅ Complete | 14 kernels, compiled |
| `Epistemos/Engine/MetalRuntimeManager.swift` | ~400 | ✅ Complete | Compilation + benchmark |

### Files That Need Replacement / Wiring

| File | Lines | Status | Action Needed |
|------|-------|--------|---------------|
| `VaultLifecycleService.swift` | 793 | ⚠️ Shadow impls | Replace Swift reimplementations with FFI calls |
| `SSMStateService.swift` | 290 | ⚠️ MLX only | Add Rust FFI fallback path |
| `TriageService.swift` | 1772 | ✅ Complete | No changes needed — pure Swift routing |
| `AgentGraphMemory.swift` | 340 | ✅ Complete | No changes needed — already wired to GraphStore |

### Files That Don't Exist But Should (per plan)

| File | Purpose | Phase |
|------|---------|-------|
| `epistemos-core/src/evolution/mutation_proposer.rs` | GEPA in shipping crate | 1 |
| `epistemos-core/src/topology/hyperbolic.rs` | Hyperbolic topology in shipping crate | 2 |
| `epistemos-core/src/cache/neural.rs` | Neural cache in shipping crate | 3 |
| `Epistemos/Vault/HyperbolicTopologyService.swift` | Swift service for topology | 2 |
| `Epistemos/Vault/NeuralCacheService.swift` | Swift service for temporal retrieval | 3 |

---

## Part 8: Decision Log

### Decisions Made in This Session

1. **Port strategy:** Move features from `agent_core` to `epistemos-core` rather than linking agent_core. Rationale: agent_core has debug-only dependencies (tokio full, git2, tantivy) that bloat the binary.

2. **Semantic similarity proxy:** Use Jaccard similarity instead of sentence-transformers for constraint gates. Rationale: embedding model adds ~50MB; Jaccard is sufficient for skill text comparison.

3. **FEP implementation:** Actually implement `should_pierce_blanket()` with entropy-based complexity and cosine similarity accuracy. Rationale: the research document describes it as operational, so it must be built.

4. **Distillation approach:** Spec summary-based checkpointing instead of token-level eviction. Rationale: MLX cache doesn't expose token-level APIs; summary approach achieves same goal with existing infrastructure.

5. **TurboQuant deferral:** Flag as post-V1 research project. Rationale: 10+ weeks, requires MLX fork, user benefit is incremental (memory reduction) not capability addition.

---

## Part 9: Handoff Checklist for Codex

Before starting implementation, Codex should:

- [ ] Read this document in full
- [ ] Read `IMPLEMENTATION_PLAN_FEATURES.md`
- [ ] Read `AGENTS.md` (Swift/Rust patterns)
- [ ] Read `AI_VAULT_RUNTIME_AUDIT.md` (debug-only boundaries)
- [ ] Read `MAMBA2_PHASE1_COMPLETION.md` (Metal kernel status)
- [ ] Verify `cargo test` passes in `epistemos-core/`
- [ ] Verify `xcodebuild build` passes
- [ ] Run the 6 audit tasks in Part 6
- [ ] Confirm understanding of UDL-based UniFFI pattern

**Then proceed with Phase 1.1.1** of the implementation plan.

---

## Part 10: Known Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| UDL binding generation fails | Medium | Blocks all FFI | Check uniffi version compatibility, run `cargo update` |
| Swift service actor isolation issues | Medium | Runtime crashes | Follow `@MainActor` pattern from `AgentGraphMemory` |
| BM25 + Neural Cache integration conflict | Low | Search results degraded | Keep BM25 as primary, use Neural Cache as reranker |
| Metal kernel dispatch errors | Low | Distillation fails | Use summary fallback, debug kernels separately |
| User config migration | Low | Settings lost | New config keys use `@AppStorage` with defaults |

---

*End of session synthesis. Ready for Codex handoff.*
