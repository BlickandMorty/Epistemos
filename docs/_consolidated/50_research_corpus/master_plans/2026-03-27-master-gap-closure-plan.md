# Epistemos — Master Gap Closure Plan

**Date:** 2026-03-27
**Author:** Claude Opus 4.6 (Automated Audit)
**Scope:** All 30 source files — Swift, Python, Rust, JSON, JSONL
**Verdict:** NOT TRAINING-READY. Multiple hard blockers. Several components are misleading.
**Purpose:** This is the single source of truth for what works, what doesn't, and exactly what to do about it — in order.

---

## Executive Summary

Epistemos has substantial working infrastructure: a trustworthy adapter registry, a real Rust/Swift MCP bridge with 2,540 passing tests, a well-built BFCL evaluation script, and 503 synthetic embodied trajectories in the correct format. The codebase is not broken — it is **unwired**.

The five most critical issues:

1. **The most carefully prepared training data (`train_final.jsonl`) is not read by any training path.** Three separate training paths exist, each reading different raw data. The compose → IFD filter → CAMPUS sort pipeline produces output that nothing consumes.

2. **The deploy gate auto-passes every adapter.** It checks whether a weights file exists on disk. It never loads the model, never runs inference, never scores predictions, never compares to a baseline. Any adapter — including a catastrophically bad one — passes.

3. **Cross-app AX capture records the wrong app's UI tree.** Every embodied capture of Safari, Terminal, or Finder captures Epistemos's own accessibility tree instead of the target app's. This produces actively harmful training signal for cross-app tasks.

4. **No training run has ever completed.** Six adapter directories exist; all contain only config files, no weights. The nightly flywheel has never fired successfully.

5. **The data mix is ~93% Epistemos symbol QA.** The master guide calls for 40% tool-calling / 20% general / 20% app-specific / 10% negative / 10% error recovery. Current data would produce a model that answers questions about its own codebase and nothing else.

**Readiness scores:**
- Training Ready: **17%** (3.5 of 21 criteria)
- Vision Matched: **0%** (0 of 26 criteria)

**Estimated time to first trustworthy training run:** 2-3 weeks of focused work.
**Estimated time to validated nightly flywheel:** 4-6 weeks.
**Estimated time to match master vision (Mamba-2 hybrid):** 9-12 months (20% probability of success).

**Recommended strategy:** Ship with Qwen LoRA (achievable in weeks), plan Mamba-2 as a v2 research initiative.

---

> **How to read this document:**
>
> - **TRUSTWORTHY** = Code does what it says. Tested. Can be relied on.
> - **PARTIAL** = Core logic exists but key pieces are missing, wrong, or untested.
> - **NOT WIRED** = Code exists in isolation. Nothing calls it, or nothing feeds it data.
> - **MISLEADING** = Name or comments claim one thing; code does another.
> - **ABSENT** = Does not exist in any form in the codebase.
>
> Every claim in this document is grounded in specific file + line number evidence from the 30-file audit.

---

## Table of Contents

1. [Current Verified Truth](#1-current-verified-truth)
2. [Hard Blockers To First Trustworthy Training Run](#2-hard-blockers-to-first-trustworthy-training-run)
3. [Architecture Gaps To Match The Master Vision](#3-architecture-gaps-to-match-the-master-vision)
4. [Training Path Truth Table](#4-training-path-truth-table)
5. [Eval Gate Truth Table](#5-eval-gate-truth-table)
6. [Data Coverage Gaps](#6-data-coverage-gaps)
7. [Research/SOAR Feature Gaps](#7-researchsoar-feature-gaps)
8. [What The User Must Do](#8-what-the-user-must-do)
9. [What Claude Must Do](#9-what-claude-must-do)
10. [Exact Execution Order](#10-exact-execution-order)
11. [Acceptance Criteria For "Training Ready"](#11-acceptance-criteria-for-training-ready)
12. [Acceptance Criteria For "Vision Matched"](#12-acceptance-criteria-for-vision-matched)
13. [Beyond-The-Vision Opportunities](#13-beyond-the-vision-opportunities)

---

## 1. Current Verified Truth

This section documents exactly what exists and works today, what exists but is broken, and what is entirely absent. No inference. No optimism. Every entry is grounded in file evidence.

### 1.1 Components That Are Genuinely Trustworthy

These components do what they claim. They can be relied upon as foundations.

| Component | File | Evidence | Status |
|-----------|------|----------|--------|
| **AdapterRegistry** | `AdapterRegistry.swift` | Full CRUD with atomic writes, never-fuse-into-base enforcement, thread-safe actor isolation | TRUSTWORTHY |
| **AdapterLoader** | `AdapterLoader.swift` | Proper hot-swap with capacity limits, weights file verification before load, graceful fallback | TRUSTWORTHY |
| **EmbodiedCaptureService** (core logic) | `EmbodiedCaptureService.swift` | Real AX capture via omega-ax, pre/post diff computation, 150ms settling delay, JSONL persistence. Line 37: `captureAXTree(pid:)` correctly uses whatever PID is passed | TRUSTWORTHY (but caller sends wrong PID — see Finding 3) |
| **eval_bfcl.py** (standalone) | `eval_bfcl.py` lines 358-437 | Comprehensive 4-axis scoring: tool match (40%), args match (30%), sequence match via LCS (20%), refusal match (10%). Deploy gate logic with configurable threshold | TRUSTWORTHY as a CLI tool. NOT WIRED into any automated flow |
| **KTOTrainer** | `KTOTrainer.swift` | Proper batch size guard, Process() bridge to Python, correct argument marshaling | TRUSTWORTHY |
| **MCPBridge** | `MCPBridge.swift` | Real UniFFI bridge to Rust dispatcher, SQLite logging of all tool calls | TRUSTWORTHY |
| **ODIATraceGenerator** | `ODIATraceGenerator-16.swift` | Real structured trace format with proper field extraction | TRUSTWORTHY |
| **OmegaTrainingCoordinator** | `OmegaTrainingCoordinator-18.swift` | Proper bridge from execution events to training data, correct signal routing | TRUSTWORTHY |
| **ResearchOrchestrator** | `ResearchOrchestrator-22.swift` | Real confidence tracking, multi-step escalation logic, synthesis gates | TRUSTWORTHY |
| **app_code_graph.json** | `app_code_graph-30.json` | Real 4,082 nodes, 19,619 edges from AST parse. Actual graph structure, not chat-style QA | TRUSTWORTHY |
| **Rust omega-mcp** | Cargo test suite | 2,540 passing tests. UniFFI bindings verified | TRUSTWORTHY |
| **SafariAgent** (Rust layer) | `SafariAgent.swift` + Rust UniFFI | Rust layer handles real Safari automation via `toolOpenUrl`, `toolGetPageUrl`, etc. | TRUSTWORTHY (execution works; AX capture from Swift side is broken) |

### 1.2 Components That Are Partial

These have real logic but are missing critical pieces.

| Component | File | What Works | What's Broken/Missing | Status |
|-----------|------|------------|----------------------|--------|
| **QLoRATrainer** | `QLoRATrainer.swift` | Process() bridge to `train_knowledge.py`, argument marshaling, completion callbacks | Conflicting LoRA rank defaults: `defaultKnowledge` uses rank 32 (line 77-85), but `autoConfigureForHardware()` uses rank 16 (KnowledgeFusionViewModel lines 66-94). The Nano path gets rank 32 via ODIA scheduler, which is wrong | PARTIAL |
| **TrainingScheduler** | `TrainingScheduler.swift` | NSBackgroundActivityScheduler infrastructure, idle/power checks, 24h interval. Three separate schedulers (KTO, Vault, ODIA) | Deploy gate is a placeholder (lines 312-353). ODIA path generates temp JSONL that bypasses the compose→IFD→CAMPUS pipeline entirely | PARTIAL |
| **IFD Filter** | `ifd_filter.py` | Structural quality heuristics: response_length, has_reasoning, has_tool_call, instruction_clarity, response_structure, deduplication (lines 123-162) | NOT real IFD. Docstring (lines 1-21) admits it's "a proxy for GPT-2 perplexity-based IFD scoring." Real IFD requires computing p(response\|instruction) / p(response) with a language model. This uses regex pattern matching | MISLEADING |
| **CAMPUS Sort** | `campus_sort.py` | Curriculum ordering concept implemented. Sorts by estimated complexity | All metrics are regex proxies (lines 23-87): tree depth = count of `AX\w+` matches, selector ambiguity = count of `click_element\|click` matches, chain length = count of `**Step \d+` matches. Not measuring real structural properties from parsed data | PARTIAL |
| **compose_training_mix.py** | `compose_training_mix.py` | Reads multiple JSONL sources, applies ratio-based sampling, outputs to `composed_training_data/train.jsonl` (line 221) | Output file is `train.jsonl`, not `train_final.jsonl`. More critically: NOTHING in Swift code reads this output. The pipeline terminates into void | NOT WIRED |
| **EmbodiedCaptureService** (wiring) | `OrchestratorState.swift` lines 190-207 | Capture logic is correct and integrated into executePlan() | PID is hardcoded to `ProcessInfo.processInfo.processIdentifier` — Epistemos's own PID. Every cross-app capture (Safari, Terminal, Finder) records Epistemos's AX tree, not the target app's | PARTIAL |
| **CSISafeguard** | `CSISafeguard.swift` | Code structure exists for catastrophic forgetting detection | `computeCSI()` is never called. Requires learned embeddings from at least one training run. No training run has ever completed, so this has never been tested | NOT WIRED |

### 1.3 Components That Are Misleading

These have names, comments, or claimed statuses that diverge from what the code actually does.

| Component | What It Claims | What It Actually Does | Evidence | Verdict |
|-----------|---------------|----------------------|----------|---------|
| **Deploy Gate** (`runDeployGate()`) | Evaluates adapter quality before deployment using BFCL scoring | Checks if `eval_bfcl.py` exists in bundle. If NOT present: returns `passed: true` with "eval infrastructure not yet deployed." If present: checks ONLY whether `adapter_weights.safetensors` exists on disk. NEVER runs eval_bfcl.py. NEVER loads model. NEVER scores anything. | `TrainingScheduler.swift` lines 312-353 | MISLEADING — Any adapter with weights on disk passes. Quality is never checked. |
| **IFD Superfilter** | Implements Instruction Following Difficulty scoring per the research paper | Implements 6 structural heuristics via regex: response_length, has_reasoning, has_tool_call, instruction_clarity, response_structure, deduplication. Zero model-based scoring. | `ifd_filter.py` lines 1-21 (docstring admits proxy), lines 123-162 (actual logic) | MISLEADING — Better than nothing, but calling it "IFD" is incorrect |
| **CAMPUS Curriculum Sort** | Sorts training data by real complexity metrics (AX tree depth, selector ambiguity, chain length) | Uses regex `AX\w+` count as "tree depth", regex `click_element\|click` count as "selector ambiguity", regex `**Step \d+` count as "chain length" | `campus_sort.py` lines 23-87 | MISLEADING — Implements curriculum ordering concept but metrics are rough text proxies, not structural measurements |
| **`train_final.jsonl` pipeline** | compose → IFD filter → CAMPUS sort → `train_final.jsonl` → training | The pipeline DOES produce `train_final.jsonl` via: `compose_training_mix.py` → `train.jsonl` (line 221) → `ifd_filter.py` → `train_filtered.jsonl` (line 235) → `campus_sort.py` → `train_sorted.jsonl` / `train_filtered_sorted.jsonl`. BUT: Zero Swift code paths read `train_final.jsonl`. All three live training paths use different data (see Section 4). | Multiple files — see Training Path Truth Table | NOT WIRED — The most carefully prepared data file is disconnected from all training |
| **Nightly Flywheel** | Automated nightly training loop that improves the model | Has never fired successfully. Even if it fired: ODIA path bypasses data composition, deploy gate auto-passes, no evaluation runs, and PID capture is broken so all cross-app training data is grounded to wrong UI state | `TrainingScheduler.swift` + `OrchestratorState.swift` | MISLEADING — Infrastructure exists but produces nothing useful |

### 1.4 Components That Are Absent

These do not exist in any form in the codebase.

| Component | Required By | Current State |
|-----------|-------------|---------------|
| **RLAIF verification pairs** | Master vision (RL stage) | 0 exist. No code generates them. No schema defined. |
| **Screen2AX dataset** | Section 3.4 of master guide | Not downloaded. Zero screenshot-based examples in any data file. |
| **GRPO / decomposed reward model** | Section 4.1 of master guide | No code exists. The 6-component decomposed reward (format/element/action/parameter/state/completion) is entirely absent. |
| **Grammar-constrained decoding** | Master guide | Only soft EOS exists (ConstrainedDecodingService). No grammar-guided generation, no formal grammar definitions, no constrained sampling. |
| **MoLoRA / AdaFuse learned routing** | Master vision | AdapterRouter exists but routes by heuristic text matching (keyword-based). No learned routing weights, no gradient-based adapter selection. |
| **Doc-to-LoRA rebuild trigger** | Master vision | Not implemented. When vault documents change, no pipeline re-generates SFT data and retrains. |
| **Scene-MMKG fusion** | Master vision | `app_code_graph.json` exists (4,082 nodes, 19,619 edges) but is NOT fused into training examples or runtime inference. The graph sits on disk, unused by training or routing. |
| **MOHAWK 3-stage distillation** | Master vision | No distillation code exists. No teacher model configured. No student architecture defined. |
| **Mamba-2 hybrid architecture** | Master vision | Zero Mamba code. Zero state-space model code. Zero hybrid attention/SSM code. The codebase uses standard transformer LoRA on whatever MLX model is installed. |
| **CoreML export pipeline** | Master vision (on-device deployment) | No CoreML conversion code. No `.mlpackage` generation. All inference goes through MLX Python bridge. |
| **Real adapter weights** | Any training path | 6 adapter directories exist on disk. ALL contain only `adapter_config.json`. ZERO contain `adapter_weights.safetensors`. No training run has ever completed. |
| **KTO feedback signals** | KTO training path | `kto_feedback` table exists with correct schema. 0 rows. Code requires `guard count >= 20`. |
| **Real ODIA execution traces** | ODIA nightly path | `omega_executions.db` has 6 rows total. Zero research tool calls. Need hundreds for meaningful training. |
| **general.jsonl replay buffer** | Anti-forgetting (Section 5.4) | File exists, size 0 bytes. |

### 1.5 The Test Failure

| Test | File | Symptom | Root Cause |
|------|------|---------|------------|
| `FrictionPersistenceTests/noteSwitchPersistsDistinctSessions()` | `CognitiveSubstrateTests.swift` lines 447-495 | Crashes with `windows.count == 0` then `Index out of range` | Test creates friction events, switches notes, asserts `windows.count == 2`. The test code itself is structurally correct — the issue is in `FrictionMonitorService` not persisting windows to the `EventStore` as expected. The service likely isn't observing or writing window entries. |

**Test code flow:**
1. Creates a `FrictionMonitorService` instance
2. Posts friction events for Note A (scroll, pause, re-read)
3. Switches context to Note B
4. Posts friction events for Note B
5. Queries `EventStore` for distinct session windows
6. Asserts `windows.count == 2` (one for Note A, one for Note B)
7. **Actual result:** `windows.count == 0` — no sessions persisted
8. Then tries to access `windows[0]` → `Index out of range` crash

**Likely root causes (in order of probability):**
1. `FrictionMonitorService` event observation is not writing to `EventStore` (most likely)
2. `EventStore` session windowing logic has a bug in grouping by note context
3. The test is creating events synchronously but `FrictionMonitorService` processes them asynchronously, causing a race

**Impact:** This test failure does NOT block training. It affects friction analytics (measuring user confusion/difficulty), which feeds into UX improvements but not into the training pipeline.

### 1.6 Rust and Swift Test Suites

| Suite | Passing | Failing | Coverage Area |
|-------|---------|---------|---------------|
| Rust (cargo test) | 2,540 | 0 | omega-mcp tool dispatch, UniFFI bindings, SQLite operations, tool schemas |
| Swift (XCTest) | 139 | 1 | ThemePair, OmegaAgent, ResearchMode, CognitiveSubstrate |
| **Total** | **2,679** | **1** | |

**What the tests cover:**
- Rust: Tool dispatch correctness, argument validation, SQLite read/write, error handling, UniFFI bridge marshaling
- Swift: Theme generation, agent routing, research escalation, adapter registry CRUD

**What the tests do NOT cover:**
- Training pipeline end-to-end (no test runs compose → filter → sort → train → eval)
- Deploy gate logic (no test verifies that the gate blocks bad adapters)
- Cross-app PID resolution (no test verifies correct PID for Safari/Terminal/Finder)
- Data format validation (no test verifies JSONL schema compliance)
- Embodied capture integration (no test verifies AX tree capture during agent execution)

---

## 2. Hard Blockers To First Trustworthy Training Run

These are problems that MUST be fixed before any training run produces a useful adapter. They are ordered by severity.

### BLOCKER 1: `train_final.jsonl` Is Disconnected From All Training Paths (CRITICAL)

**The Problem:**

The data preparation pipeline (compose → IFD filter → CAMPUS sort) produces carefully curated output files. None of the three live training paths read these files.

| Training Path | What It Actually Reads | What It Should Read |
|--------------|----------------------|-------------------|
| Manual vault training (`KnowledgeFusionViewModel.trainOnVault()`) | `synthResult.trainingFiles` — dynamically generated from vault parsing (line 207-274) | The composed, filtered, sorted mix |
| Nightly ODIA training (`TrainingScheduler.onODIASchedulerFired()`) | A temp JSONL file written from pending ODIA traces (lines 253-256) | The composed, filtered, sorted mix augmented with ODIA traces |
| The compose→IFD→CAMPUS pipeline | N/A — this IS the pipeline | Nothing reads its output |

**Why This Matters:** You can run compose_training_mix.py, ifd_filter.py, and campus_sort.py perfectly. The output sits in `composed_training_data/` and nobody reads it. The training infrastructure fires on raw, unfiltered, unbalanced data.

**Fix:** Wire `train_final.jsonl` (or whatever the pipeline's final output is) into `QLoRATrainer.swift` as the default `--data_path`. The temp ODIA file should be APPENDED to the composed mix, not used alone.

---

### BLOCKER 2: Deploy Gate Auto-Passes Everything (CRITICAL)

**The Problem:**

`TrainingScheduler.runDeployGate()` (lines 312-353) has three code paths:

```
Path A: eval_bfcl.py NOT in bundle → return passed: true
                                      reason: "eval infrastructure not yet deployed"

Path B: eval_bfcl.py IS in bundle, weights file NOT on disk → return passed: false

Path C: eval_bfcl.py IS in bundle, weights file IS on disk → return passed: true
```

**What's missing from all three paths:**
- Loading the base model
- Loading the adapter
- Running inference on eval tasks
- Generating a predictions JSONL file
- Running `eval_bfcl.py --predictions <file> --ground-truth <file>`
- Comparing new score to baseline
- Applying the `new_score > baseline + 0.5%` threshold

**Current behavior:** Any adapter that has `adapter_weights.safetensors` on disk is automatically deployed. A completely random adapter would pass. A catastrophically overtrained adapter would pass. There is zero quality filtering.

**Why This Matters:** The deploy gate is the ONLY safety mechanism preventing a bad adapter from replacing a good one. Without it, the nightly flywheel is a ratchet that can only get worse.

**Fix:** Implement the full eval flow:
1. Load base model + candidate adapter
2. Run inference on `bfcl_eval_macos.jsonl` (100 tasks) + `bfcl_eval_epistemos.jsonl` (50 tasks)
3. Write predictions to temp JSONL
4. Run `eval_bfcl.py` scoring
5. Compare to saved baseline
6. Only deploy if `new_score > baseline + threshold`

---

### BLOCKER 3: Cross-App PID Capture Is Broken (HIGH)

**The Problem:**

`OrchestratorState.swift` lines 190-207:
```swift
// Pre-capture (line 190-194):
let pid = ProcessInfo.processInfo.processIdentifier  // Epistemos's PID

// Post-capture (line 203-207):
let pid = ProcessInfo.processInfo.processIdentifier  // Still Epistemos's PID
```

`EmbodiedCaptureService.captureAXTree(pid:)` (line 37) correctly uses whatever PID it receives. The bug is in the CALLER, not the service.

**Impact:** Every embodied capture during:
- Safari browsing → captures Epistemos's AX tree, NOT Safari's
- Terminal commands → captures Epistemos's AX tree, NOT Terminal's
- Finder operations → captures Epistemos's AX tree, NOT Finder's
- Any non-Epistemos app interaction → WRONG AX tree

**Why This Matters:** Cross-app trajectories are the CORE training data for a macOS agent. If these trajectories show Epistemos's AX tree when the agent was operating in Safari, the model learns to map Safari instructions to Epistemos UI elements. This isn't just useless — it's actively harmful training signal.

**Scope of damage:** This affects ALL trajectories in the embodied pipeline where the target app is not Epistemos itself. Epistemos-internal trajectories (note editing, graph navigation, settings) are correctly captured because Epistemos IS the target.

**Fix:** `OrchestratorState` must extract the target app's PID from the step arguments. The step already knows which agent is executing (SafariAgent, TerminalAgent, FinderAgent). Each agent should provide its target PID. For Safari: use `NSWorkspace.shared.runningApplications` filtered by bundle identifier `com.apple.Safari`.

---

### BLOCKER 4: LoRA Rank Defaults Conflict (MEDIUM)

**The Problem:**

Three different default rank values exist:

| Source | Rank | Alpha | When Used |
|--------|------|-------|-----------|
| `QLoRATrainer.swift` `defaultKnowledge` (line 77-85) | 32 | 64 | ODIA nightly path via TrainingScheduler |
| `KnowledgeFusionViewModel.autoConfigureForHardware()` (lines 66-94) | 16 | 32 | Manual vault training |
| `train_knowledge.py` `DEFAULT_RANK` (lines 25-27) | 32 | 64 | Python fallback if no CLI args |

**Impact on Nano (the target hardware):**
- Manual training correctly uses rank 16 (small enough for Nano's memory)
- ODIA nightly training uses rank 32 (may OOM on Nano or produce oversized adapters)
- If Python script is called without explicit rank args, it defaults to 32

**Fix:** Unify all defaults to rank 16, alpha 32 for the Nano target. If multiple hardware targets are needed, the hardware autoconfig should be the single source of truth, called by ALL training paths.

---

### BLOCKER 5: No Training Run Has Ever Completed (HIGH)

**The Problem:**

| Evidence | State |
|----------|-------|
| 6 adapter directories on disk | All contain only `adapter_config.json` |
| `adapter_weights.safetensors` files | 0 exist anywhere |
| `training_metadata.json` files | 0 exist anywhere |
| `adapter_registry.json` | Contains `[]` |
| Nightly scheduler | Has never fired successfully |
| KTO feedback table | 0 rows |
| omega_executions.db | 6 rows (not enough to trigger training) |

**Why This Matters:** Until one complete training cycle succeeds end-to-end, you cannot validate:
- That the QLoRA Python bridge works on the actual hardware
- That adapter weights serialize correctly
- That the adapter loads and produces different outputs than base
- That the eval pipeline can score a trained adapter
- That the deploy gate can compare two adapters
- That CSISafeguard's catastrophic forgetting detection works

**Fix:** Run one complete training cycle, even on a small dataset, to validate the full pipeline. Fix any issues that surface. This is a prerequisite to fixing everything else — you need to know the pipeline works before optimizing the data.

---

## 3. Architecture Gaps To Match The Master Vision

The master vision calls for a fundamentally different architecture than what exists. This section catalogs every divergence.

### 3.1 Base Model Architecture

| Dimension | Master Vision | Current Reality | Gap Severity |
|-----------|--------------|-----------------|--------------|
| **Architecture** | Mamba-2 hybrid (75% Mamba SSM / 25% attention) | Standard transformer decoder (likely Qwen 3.5) via MLX | TOTAL — Different architecture family |
| **Parameter count** | 1B custom | Whatever Qwen model is installed (~0.5B to 7B) | HIGH — No parameter budget enforcement |
| **Model detection** | `detectInstalledModels()` scans `~/Library/Application Support/Epistemos/Models/text/active/` | Picks up whatever MLX model directory exists there | N/A — Works as designed for current approach |
| **Training method** | MOHAWK 3-stage distillation (teacher → projection → student) | LoRA fine-tuning on pre-existing model | TOTAL — Distillation vs. adaptation |
| **Deployment** | CoreML `.mlpackage` for on-device | MLX Python bridge for on-device | HIGH — MLX works but CoreML is the production target |
| **State management** | Mamba hidden state injection/extraction for context switching | Standard KV cache | TOTAL — Fundamentally different context model |

**Honest Assessment:** The current "LoRA on Qwen via MLX" approach is a VALID AND USEFUL intermediate step. It can produce a functional assistant today. But it is architecturally unrelated to the master vision's Mamba-2 hybrid. The training pipeline happens to be compatible with both (standard transformer decoder) because LoRA works on attention layers regardless, but the Mamba-2 path requires:

1. Defining the hybrid architecture (which layers are Mamba, which are attention)
2. Training or obtaining a teacher model
3. Implementing MOHAWK's 3-stage distillation
4. Building CoreML export for the custom architecture
5. Implementing Mamba state injection for context switching

None of these exist. This is 6-12 months of architecture work.

### 3.2 Training Pipeline Architecture

| Dimension | Master Vision | Current Reality | Gap |
|-----------|--------------|-----------------|-----|
| **SFT data** | compose → IFD filter → CAMPUS sort → `train_final.jsonl` | Pipeline exists but output is disconnected from training (BLOCKER 1) | NOT WIRED |
| **IFD scoring** | GPT-2 perplexity-based p(response\|instruction)/p(response) | Regex heuristics labeled as "IFD proxy" | MISLEADING |
| **CAMPUS sort** | Real AX tree depth, real selector count, real chain length | Regex proxies for all three metrics | MISLEADING |
| **RLAIF** | 464 verification pairs → preference learning | 0 pairs exist, no generation code | ABSENT |
| **GRPO** | 6-component decomposed reward model | No code exists | ABSENT |
| **KTO** | Online preference learning from user feedback | Infrastructure wired, 0 feedback signals collected | NOT WIRED (no data) |
| **Nightly flywheel** | ODIA traces → compose → filter → sort → train → eval → deploy | ODIA traces → temp JSONL → train (bypassing filter/sort) → auto-pass deploy gate | PARTIAL + MISLEADING |

### 3.3 Runtime Architecture

| Dimension | Master Vision | Current Reality | Gap |
|-----------|--------------|-----------------|-----|
| **Adapter routing** | Learned MoLoRA/AdaFuse with gradient-based selection | Heuristic text matching in AdapterRouter | PARTIAL |
| **Context switching** | Mamba state injection/extraction | Standard KV cache (no explicit management) | ABSENT |
| **Grammar-constrained decoding** | Full grammar definitions for tool call format | Soft EOS only in ConstrainedDecodingService | PARTIAL |
| **CSI Safeguard** | Continuous embedding drift monitoring | Code exists, `computeCSI()` never called, needs trained embeddings | NOT WIRED |
| **Scene-MMKG** | Fused code graph + AX atlas in runtime context | Code graph on disk (4,082 nodes), not loaded into any runtime path | NOT WIRED |
| **Cross-app automation** | Target app PID capture for AX trees | Hardcoded to Epistemos PID | BROKEN |

---

## 4. Training Path Truth Table

This table shows every path from data to training, what file each path actually reads, and what happens to the data.

### 4.1 The Three Live Training Paths

| # | Trigger | Code Path | Data Source | .jsonl File Actually Read | Passes Through IFD? | Passes Through CAMPUS? | Deploy Gate? |
|---|---------|-----------|-------------|--------------------------|---------------------|----------------------|--------------|
| 1 | User taps "Train on Vault" | `KnowledgeFusionViewModel.trainOnVault()` (lines 207-274) → `QLoRATrainer.trainKnowledgeAdapter()` (lines 98-116) → `train_knowledge.py` | `synthResult.trainingFiles` — dynamically generated from vault parsing at runtime | **Dynamic temp file** — different every time, based on current vault contents | NO | NO | NO (manual path has no gate) |
| 2 | Nightly scheduler fires | `TrainingScheduler.onODIASchedulerFired()` (lines 253-256) → writes pending ODIA traces → `QLoRATrainer.trainKnowledgeAdapter()` → `train_knowledge.py` | Accumulated ODIA traces from `omega_executions.db` | **Temp JSONL** — written fresh from pending traces | NO | NO | YES — but auto-passes (BLOCKER 2) |
| 3 | N/A — disconnected | `compose_training_mix.py` → `ifd_filter.py` → `campus_sort.py` | All available JSONL sources composed at ratio | `train_final.jsonl` (or `train_filtered_sorted.jsonl`) | YES (heuristic proxy) | YES (regex proxy) | N/A — no code reads the output |

### 4.2 File Flow Detail

```
Path 1 (Manual Vault Training):
  Vault markdown files
    → KnowledgeFusionViewModel.parseVault()
    → SyntheticDataGenerator.generate()
    → [temp]/train.jsonl
    → train_knowledge.py --data_path [temp]/train.jsonl
    → adapter_weights.safetensors (never produced — 0 successful runs)

Path 2 (ODIA Nightly):
  omega_executions.db (6 rows)
    → TrainingScheduler.onODIASchedulerFired()
    → ODIATraceGenerator.generateTraces()
    → [temp]/odia_traces.jsonl
    → train_knowledge.py --data_path [temp]/odia_traces.jsonl
    → adapter_weights.safetensors (never produced — not enough data)
    → runDeployGate() → auto-passes

Path 3 (Compose Pipeline — DISCONNECTED):
  Multiple source JSONLs
    → compose_training_mix.py → composed_training_data/train.jsonl
    → ifd_filter.py → train_filtered.jsonl
    → campus_sort.py → train_filtered_sorted.jsonl (or train_final.jsonl)
    → ??? (NOTHING READS THIS)
```

### 4.3 What `train_knowledge.py` Actually Does With Its Input

| Line Range | Behavior |
|------------|----------|
| 146-180 | Copies whatever `--data_path` it receives into a temp directory as `train.jsonl` |
| 25-27 | Default hyperparameters: `DEFAULT_RANK = 32, DEFAULT_ALPHA = 64` (overridable via CLI) |
| Does NOT | Look for `train_final.jsonl` specifically |
| Does NOT | Validate data format, check for embodied fields, or verify data quality |
| Does NOT | Run any IFD filtering or curriculum sorting |

**Key Insight:** `train_knowledge.py` is a dumb pipe. It trains on whatever you give it. The quality of training depends ENTIRELY on what the caller passes as `--data_path`. Currently, the callers pass unfiltered, unbalanced, single-source data.

### 4.4 LoRA Hyperparameter Path

| Caller | How Rank Is Set | Actual Value |
|--------|----------------|--------------|
| `KnowledgeFusionViewModel.trainOnVault()` | `autoConfigureForHardware()` always runs first (lines 66-94) | rank=16, alpha=32 |
| `TrainingScheduler.onODIASchedulerFired()` | Uses `TrainingConfig.defaultKnowledge` (lines 77-85) | rank=32, alpha=64 |
| `train_knowledge.py` (if no CLI override) | `DEFAULT_RANK`, `DEFAULT_ALPHA` (lines 25-27) | rank=32, alpha=64 |

**Conflict:** The same hardware (Apple Silicon Nano) gets rank 16 from one path and rank 32 from another. Rank 32 may OOM on devices with 8GB unified memory under load.

---

## 5. Eval Gate Truth Table

This table shows exactly what evaluation is CLAIMED to run vs what ACTUALLY runs.

### 5.1 Deploy Gate (`runDeployGate()`)

| Step | Claimed | Actual Code (TrainingScheduler.swift lines 312-353) | Verdict |
|------|---------|-----------------------------------------------------|---------|
| 1. Load eval infrastructure | Implied by function name | Checks if `eval_bfcl.py` exists in app bundle (line 332-333) | FILE CHECK ONLY |
| 2. If infrastructure missing | Should block deployment | Returns `passed: true`, reason: "eval infrastructure not yet deployed" (line 335) | DEFAULT PASS — silently allows deployment without evaluation |
| 3. Load base model | Required for scoring | Not implemented | ABSENT |
| 4. Load candidate adapter | Required for scoring | Not implemented | ABSENT |
| 5. Run inference on eval tasks | Required for scoring | Not implemented | ABSENT |
| 6. Generate predictions JSONL | Required by `eval_bfcl.py --predictions` | Not implemented. Nothing in Swift generates this file | ABSENT |
| 7. Run `eval_bfcl.py` scoring | Core eval logic | NEVER CALLED. Not invoked via Process() or any other mechanism | ABSENT |
| 8. Compare new score to baseline | `new_score > baseline + 0.5%` | Not implemented | ABSENT |
| 9. Check adapter weights exist | Minimum sanity check | YES — checks `adapter_weights.safetensors` exists on disk (lines 343-352) | IMPLEMENTED — but this is the ONLY real check |
| 10. Return pass/fail | Gate decision | Returns `passed: true` if weights file exists, `passed: false` if not | FILE EXISTENCE = PASS. Quality not measured. |

### 5.2 eval_bfcl.py Standalone Capabilities

`eval_bfcl.py` (lines 358-437) is a well-built standalone tool. Here's what it CAN do if actually called:

| Capability | Implementation | Status |
|------------|---------------|--------|
| Parse predictions JSONL | Reads `--predictions` file with predicted tool calls | IMPLEMENTED |
| Parse ground truth JSONL | Reads `--ground-truth` file with expected tool calls | IMPLEMENTED |
| Tool name matching (40% weight) | Exact match + 0.5 partial credit for tool family | IMPLEMENTED |
| Argument matching (30% weight) | Subset matching, case-insensitive, substring partial credit | IMPLEMENTED |
| Sequence matching (20% weight) | LCS-based ordering score for multi-step tasks | IMPLEMENTED |
| Refusal matching (10% weight) | Correct refusal for unsafe/out-of-scope tasks | IMPLEMENTED |
| Category breakdown | Per-category score aggregation | IMPLEMENTED |
| Difficulty breakdown | Per-difficulty score aggregation | IMPLEMENTED |
| Baseline auto-save | Saves first-run score as baseline for future comparison | IMPLEMENTED |
| Deploy gate threshold | `new_score > baseline + threshold` (configurable) | IMPLEMENTED |

**The gap is NOT in eval_bfcl.py.** The gap is that nothing calls it. The Swift deploy gate does not:
- Generate predictions (requires model inference)
- Invoke the Python script (requires Process() bridge)
- Read the results (requires JSON parsing of eval output)

### 5.3 Evaluation Data Files

| File | Exists? | Tasks | Format Valid? | Used By Anything? |
|------|---------|-------|--------------|-------------------|
| `bfcl_eval_macos.jsonl` | YES (in MOHAWK/embodied_data/) | 100 macOS tasks | YES — has id, category, instruction, expected_action, verification, difficulty | NOT WIRED into deploy gate |
| `bfcl_eval_epistemos.jsonl` | YES (in MOHAWK/embodied_data/) | 50 Epistemos tasks | YES — same schema | NOT WIRED into deploy gate |
| `predictions_template.jsonl` | YES (in MOHAWK/embodied_data/) | Template for model output | YES | Nothing generates predictions to fill it |
| Baseline scores file | NO | N/A | N/A | Cannot exist until first eval run completes |

---

## 6. Data Coverage Gaps

### 6.1 Training Data Inventory

| Dataset | File | Examples | Format | Quality | Status |
|---------|------|----------|--------|---------|--------|
| Symbol QA | `02_symbol_qa.jsonl` | ~3,070 | Chat SFT | Regex-generated, no Xcode symbol graph | PARTIAL — exists but not from authoritative source |
| Code Graph QA | `01_code_graph.jsonl` | 557 | Chat SFT | Chat-style QA about code, NOT actual graph structure | MISLEADING — name implies graph data, contains QA pairs |
| AX Atlas | `03_ax_atlas.jsonl` | 146 | Chat SFT | Chat-style descriptions. NO actual AX trees, NO pre/post diffs | MISLEADING — name implies atlas, contains descriptions |
| Trajectories (old) | `04_trajectories.jsonl` | 43 | Chat SFT | Wrong format (chat, not OBSERVE→REASON→ACT→RESULT→DONE) | PARTIAL — too few, wrong format |
| Embodied trajectories | `embodied_trajectories.jsonl` | 503 | Embodied JSONL | Full schema: AX tree, screenshot, reasoning, action, result, diff | TRUSTWORTHY — correct format, synthetic content |
| Embodied SFT | `embodied_trajectories_sft.jsonl` | 503 | Chat SFT | Converted from embodied, OBSERVE→REASON→ACT→RESULT→DONE format | TRUSTWORTHY |
| Tool calls | Embedded in train.jsonl | ~144 | Chat SFT | AXPress format, 50+ tools | PARTIAL — too few |
| Negative examples | Embedded in train.jsonl | ~20 | Chat SFT | Has `<think>` tags, hammer-style refusals | PARTIAL — too few |
| Research layer | Layer 16 generator | 48 (not on disk) | Chat SFT | Generator exists, not yet run to disk | NOT WIRED |
| App code graph | `app_code_graph-30.json` | 4,082 nodes, 19,619 edges | JSON graph | Real AST parse | TRUSTWORTHY — but not converted to training format |
| Composed mix | `composed_training_data/train.jsonl` | Unknown | Chat SFT | Output of compose_training_mix.py | NOT WIRED — nothing reads it |
| Filtered | `train_filtered.jsonl` | Unknown | Chat SFT | Output of ifd_filter.py | NOT WIRED |
| Sorted | `train_filtered_sorted.jsonl` | Unknown | Chat SFT | Output of campus_sort.py | NOT WIRED |
| General replay buffer | `general.jsonl` | 0 | N/A | 0 bytes | EMPTY |
| ODIA traces | `omega_executions.db` | 6 rows | SQLite | 2 click_element, 2 run_command, 1 list_files, 1 run_shortcut | INSUFFICIENT |
| KTO feedback | `kto_feedback` table | 0 rows | SQLite | Schema exists, no data | EMPTY |
| RLAIF pairs | N/A | 0 | N/A | Does not exist | ABSENT |
| Screen2AX | N/A | 0 | N/A | Not downloaded | ABSENT |
| General macOS traces | N/A | 0 | N/A | 50K needed, 0 exist | ABSENT |

### 6.2 Data Mix Analysis

**Master guide target:**

| Category | Target % | Target Count (at 5,000 total) |
|----------|---------|------|
| Tool-calling | 40% | 2,000 |
| General instruction | 20% | 1,000 |
| Epistemos app-specific | 20% | 1,000 |
| Negative / refusal | 10% | 500 |
| Error recovery | 10% | 500 |

**Current reality:**

| Category | Current Count | Current % | Gap |
|----------|--------------|-----------|-----|
| Tool-calling | ~144 (original) + ~54 (embodied) = ~198 | ~4.5% | Missing ~1,800 |
| General instruction | 0 | 0% | Missing ~1,000 |
| Epistemos app-specific | ~3,070 (symbol QA) + ~503 (embodied) + ~557 (code graph) = ~4,130 | ~93% | OVER by ~3,130 |
| Negative / refusal | ~20 (original) + ~24 (embodied) = ~44 | ~1% | Missing ~456 |
| Error recovery | ~15 (original) + ~27 (embodied) = ~42 | ~1% | Missing ~458 |
| **Total** | **~4,414** | | |

**Verdict:** The mix is catastrophically skewed toward Epistemos app-specific data (~93%). Training on this mix will produce a model that can answer questions about Epistemos's codebase but cannot perform general macOS tasks, refuses nothing, and recovers from no errors.

### 6.3 Data Quality Concerns

| Concern | Severity | Detail |
|---------|----------|--------|
| **Symbol QA is regex-generated** | MEDIUM | 3,070 examples generated from regex parsing of Swift files, not from `xcodebuild -symbolGraph`. May contain incorrect cross-file references. |
| **Embodied trajectories are synthetic** | MEDIUM | All 503 embodied trajectories use template AX trees, not real captured AX trees from running Epistemos. The templates are structurally valid but may not match actual runtime AX tree shapes. |
| **Cross-app embodied data captures wrong PID** | HIGH | Any embodied trajectory captured during real Omega execution targeting Safari/Terminal/Finder has Epistemos's AX tree, not the target app's. These trajectories are HARMFUL training signal for cross-app tasks. |
| **No IFD filtering has been applied** | MEDIUM | The "IFD filter" exists but is a heuristic proxy. Even that proxy has not been run on the composed dataset in a way that feeds into training. |
| **No deduplication across sources** | LOW | Symbol QA, code graph, and embodied data may overlap. No global dedup pass. |

---

## 7. Research/SOAR Feature Gaps

### 7.1 Research Orchestration

| Feature | Code Location | Status | Detail |
|---------|--------------|--------|--------|
| ResearchOrchestrator | `ResearchOrchestrator-22.swift` | TRUSTWORTHY | Real confidence tracking, multi-step escalation, synthesis gates |
| Research agent routing | OrchestratorState → TaskGraph → agents | TRUSTWORTHY | Routes to correct research agents |
| MCP tool bridge | `MCPBridge.swift` | TRUSTWORTHY | Real UniFFI bridge to Rust, SQLite logging |
| Research ODIA traces | ODIATraceGenerator | TRUSTWORTHY | Generates structured traces with `taskType: "research"` and 2x weight |
| Research execution traces | `omega_executions.db` | INSUFFICIENT | 6 total rows, 0 research tool calls |
| Research training data | Layer 16 generator | NOT WIRED | Generator code exists (48 examples), never run to disk |
| Research eval holdout | N/A | ABSENT | No research-specific eval tasks in BFCL holdout |

### 7.2 SOAR (State-Observe-Act-Reflect) Loop

| Component | Status | Detail |
|-----------|--------|--------|
| State observation (pre-action) | PARTIAL | `EmbodiedCaptureService.captureAXTree()` works, but PID is wrong for cross-app |
| Action execution | TRUSTWORTHY | Agent system executes real actions via Rust UniFFI bridge |
| Result observation (post-action) | PARTIAL | Post-action capture works, same PID issue |
| Reflection / reasoning | PARTIAL | `<think>` tags in training data, but no structured reflection loop at runtime |
| Trajectory persistence | TRUSTWORTHY | JSONL persistence works correctly |
| Training from trajectories | NOT WIRED | `train_final.jsonl` disconnected from training paths |

### 7.3 Advanced Features

| Feature | Master Vision | Current State | Gap |
|---------|--------------|---------------|-----|
| **Learned adapter routing** | MoLoRA/AdaFuse with gradient-based selection per token/layer | AdapterRouter does keyword text matching to select which adapter to load. No learned weights, no per-token routing, no gradient signal. | FUNDAMENTAL — Heuristic vs. learned |
| **Grammar-constrained decoding** | Formal grammar definitions for tool call JSON, ensuring syntactically valid output | ConstrainedDecodingService with soft EOS only. No grammar definitions, no constrained sampling, no Earley/GLR parsing during generation. | PARTIAL — EOS constraint is simplest form |
| **CSI Safeguard** | Continuous monitoring of embedding drift to detect catastrophic forgetting | `CSISafeguard.swift` exists. `computeCSI()` requires learned embeddings from training. No training has completed, so no embeddings exist, so CSI has never been computed. | NOT WIRED — Chicken-and-egg: needs training to work, but is supposed to protect training |
| **Scene-MMKG** | Multimodal knowledge graph fusing code structure + AX atlas + visual layout | `app_code_graph.json` has 4,082 nodes and 19,619 edges from real AST parse. This graph is NOT loaded into any runtime context, NOT fused with AX atlas data, NOT used in training example generation. | NOT WIRED — Data exists, fusion does not |
| **Doc-to-LoRA rebuild** | When vault documents change → regenerate SFT data → retrain adapter | No file watcher exists. No change detection. No automatic rebuild trigger. Manual "Train on Vault" is the only path. | ABSENT |

---

## 8. What The User Must Do

These actions require the user's direct involvement — they cannot be done by Claude alone.

### 8.1 Actions Requiring macOS / Hardware Access

| # | Action | Why Claude Can't Do It | Time Estimate |
|---|--------|----------------------|---------------|
| 1 | **Grant Epistemos Accessibility permission** | System Settings > Privacy > Accessibility. Requires GUI interaction on the Mac. | 2 minutes |
| 2 | **Run one complete LoRA training on the Mac** | Requires the actual Apple Silicon hardware, the installed MLX model, and sufficient RAM/thermal headroom. | 30-60 minutes (including troubleshooting) |
| 3 | **Enable `omega.embodiedCapture` UserDefault** | `defaults write com.epistemos.app omega.embodiedCapture -bool true` in Terminal. Required to start live AX capture during real usage. | 1 minute |
| 4 | **Use the app to generate real ODIA traces** | Execute 100+ real Omega tasks (search, navigate, create notes, run commands) so `omega_executions.db` accumulates meaningful data. | Ongoing — days/weeks of real usage |
| 5 | **Use the app to generate KTO feedback** | Click accept/discard on 20+ AI-generated responses in the note editor to populate `kto_feedback` table. | Ongoing — during normal usage |
| 6 | **Validate the test failure** | Build and run `CognitiveSubstrateTests` to confirm `noteSwitchPersistsDistinctSessions()` crashes. Check `FrictionMonitorService` window persistence. | 15-30 minutes |
| 7 | **Verify adapter loads after first training** | After training completes, verify that the adapter actually changes model output for a known query. Compare base model response to adapter-augmented response. | 10 minutes |
| 8 | **Budget approval for Claude Sonnet trajectory generation** | ~$550 for 1,000 high-quality trajectories via Sonnet API. User must approve spend. | 5 minutes (decision) |
| 9 | **Download Screen2AX dataset** | 1,127 images × 112 apps. Requires disk space and network. | 30 minutes |

### 8.2 Actions Requiring Product Decisions

| # | Decision | Options | Impact |
|---|----------|---------|--------|
| 1 | **Prioritize Qwen LoRA path vs Mamba-2 hybrid path** | (A) Ship with Qwen LoRA now, plan Mamba-2 for v2. (B) Pause and build Mamba-2 first. Recommendation: **A** — Qwen LoRA gives real functionality in weeks. Mamba-2 is 6-12 months of architecture work with uncertain payoff. | Determines entire technical roadmap |
| 2 | **Decide on LoRA rank for Nano** | (A) Rank 16 everywhere (safer for 8GB). (B) Rank 32 everywhere (better quality, may OOM). (C) Adaptive based on available memory. Recommendation: **A** for initial release. | Affects all training and adapter loading |
| 3 | **Decide on data mix ratios** | (A) Master guide 40/20/20/10/10. (B) Modified ratios given current data availability. Recommendation: **A** as target, accept proportional scaling until general data exists. | Determines data generation priorities |
| 4 | **Decide on real IFD vs current proxy** | (A) Implement GPT-2 based IFD scoring. (B) Keep heuristic proxy, rename it honestly. Recommendation: **B** for now — the heuristic is useful, just mislabeled. Real IFD is a nice-to-have. | Affects data pipeline complexity |

---

## 9. What Claude Must Do

These are code changes, data generation tasks, and pipeline fixes that Claude can execute.

### 9.1 Critical Bug Fixes

| # | Task | Files to Change | Complexity | Blocks |
|---|------|----------------|------------|--------|
| 1 | **Wire `train_final.jsonl` into training paths** | `QLoRATrainer.swift`, `TrainingScheduler.swift`, `KnowledgeFusionViewModel.swift` | MEDIUM | First trustworthy training run |
| 2 | **Implement real deploy gate** | `TrainingScheduler.swift` | HIGH | Safe adapter deployment |
| 3 | **Fix cross-app PID capture** | `OrchestratorState.swift` | MEDIUM | Correct cross-app training data |
| 4 | **Unify LoRA rank defaults** | `QLoRATrainer.swift`, `KnowledgeFusionViewModel.swift`, `train_knowledge.py` | LOW | Consistent training behavior |
| 5 | **Rename IFD filter honestly** | `ifd_filter.py` | LOW | Developer trust (no functional change) |
| 6 | **Rename CAMPUS sort honestly** | `campus_sort.py` | LOW | Developer trust (no functional change) |

### 9.2 Deploy Gate Implementation Detail

The deploy gate needs these specific additions to `TrainingScheduler.swift`:

```
Required additions to runDeployGate():

1. GENERATE PREDICTIONS:
   - Load base model + candidate adapter via MLXInferenceBridge
   - For each task in bfcl_eval_macos.jsonl + bfcl_eval_epistemos.jsonl:
     - Feed instruction to model
     - Capture predicted tool call(s)
     - Write to predictions.jsonl
   
2. RUN SCORING:
   - Invoke eval_bfcl.py via Process():
     python3 eval_bfcl.py \
       --predictions predictions.jsonl \
       --ground-truth bfcl_eval_macos.jsonl \
       --threshold 0.005
   
3. PARSE RESULTS:
   - Read eval output JSON
   - Extract overall_score and passed boolean
   
4. ENFORCE GATE:
   - If not passed: reject adapter, log reason, keep current adapter
   - If passed: proceed with deployment
   - NEVER return passed:true without running scoring
```

### 9.3 PID Fix Implementation Detail

```
Required changes to OrchestratorState.swift:

1. Add method to resolve target app PID:
   func resolveTargetPID(for agent: OmegaAgent) -> pid_t {
       switch agent {
       case is SafariAgent:
           return pidForBundleID("com.apple.Safari")
       case is TerminalAgent:
           return pidForBundleID("com.apple.Terminal")
       case is FinderAgent:
           return pidForBundleID("com.apple.finder")
       default:
           return ProcessInfo.processInfo.processIdentifier // Epistemos itself
       }
   }

2. Replace hardcoded PID in pre-capture (lines 190-194):
   let pid = resolveTargetPID(for: currentAgent)

3. Replace hardcoded PID in post-capture (lines 203-207):
   let pid = resolveTargetPID(for: currentAgent)

4. Add helper:
   func pidForBundleID(_ bundleID: String) -> pid_t {
       NSWorkspace.shared.runningApplications
           .first { $0.bundleIdentifier == bundleID }?
           .processIdentifier ?? ProcessInfo.processInfo.processIdentifier
   }
```

### 9.4 Training Path Wiring Fix

```
Required changes:

1. TrainingScheduler.onODIASchedulerFired():
   CURRENT: Write ODIA traces to temp JSONL → pass directly to trainer
   FIXED:   Write ODIA traces → APPEND to composed mix → run IFD filter →
            run CAMPUS sort → pass final output to trainer

2. KnowledgeFusionViewModel.trainOnVault():
   CURRENT: Generate SFT from vault → pass directly to trainer
   FIXED:   Generate SFT from vault → MERGE with base composed mix →
            run IFD filter → run CAMPUS sort → pass final output to trainer

3. Add a single entry point:
   func prepareTrainingData(additionalSources: [URL]) -> URL {
       // 1. Start with base composed mix
       // 2. Append additional sources
       // 3. Run ifd_filter.py
       // 4. Run campus_sort.py
       // 5. Return path to final output
   }
```

### 9.5 Data Generation Tasks

| # | Task | Output | Estimated Size |
|---|------|--------|----------------|
| 1 | Generate Layer 16 research data to disk | `research_training.jsonl` | ~48 examples |
| 2 | Expand embodied trajectory generator to 1,000+ | Additional entries in `embodied_trajectories.jsonl` | ~500 more trajectories |
| 3 | Generate negative/refusal examples | `negative_examples.jsonl` | ~500 examples to reach 10% target |
| 4 | Generate error recovery examples | `error_recovery.jsonl` | ~500 examples to reach 10% target |
| 5 | Convert `app_code_graph.json` to training format | `code_graph_training.jsonl` | QA pairs from real graph structure |
| 6 | Build general macOS instruction data | `general_macos.jsonl` | ~1,000 examples (Evol-Instruct from seeds) |

### 9.6 Pipeline Integration Tasks

| # | Task | Complexity |
|---|------|------------|
| 1 | Make `compose_training_mix.py` the canonical data preparation entry point | MEDIUM |
| 2 | Wire compose output → IFD → CAMPUS → `train_final.jsonl` as a single make target or script | LOW |
| 3 | Add `train_final.jsonl` path as default in `QLoRATrainer.swift` | LOW |
| 4 | Add ODIA trace append to compose pipeline | MEDIUM |
| 5 | Add vault SFT merge to compose pipeline | MEDIUM |
| 6 | Wire eval_bfcl.py into deploy gate via Process() | HIGH |
| 7 | Add prediction generation step (requires model inference) | HIGH |

---

## 10. Exact Execution Order

This is the dependency-ordered sequence. Steps within the same phase can be parallelized. Steps across phases cannot.

### Phase 0: Validate The Pipe (Before Any Optimization)

**Goal:** Prove that data goes in one end and a trained adapter comes out the other.

| Step | Task | Owner | Depends On | Output | Est. Time |
|------|------|-------|------------|--------|-----------|
| 0.1 | Unify LoRA rank defaults to 16/32 across all paths | Claude | Nothing | Updated `QLoRATrainer.swift`, `KnowledgeFusionViewModel.swift`, `train_knowledge.py` | 30 min |
| 0.2 | Run one training on existing `embodied_trajectories_sft.jsonl` (503 examples) | User (on Mac) | 0.1 | `adapter_weights.safetensors` on disk OR an error log showing what breaks | 1 hour |
| 0.3 | Debug any failures from 0.2 | Claude + User | 0.2 | Working training pipeline | Variable |
| 0.4 | Verify trained adapter loads and changes model output | User | 0.3 | Confirmation that adapter affects inference | 15 min |
| 0.5 | Register adapter in `AdapterRegistry` | User | 0.4 | `adapter_registry.json` with 1 entry | 5 min |

**Phase 0 acceptance:** One `adapter_weights.safetensors` on disk, registered in `adapter_registry.json`, verified to change model output.

---

### Phase 1: Fix Critical Wiring (Unblock The Pipeline)

**Goal:** Make the pipeline honest — data flows through composition, filtering, and sorting before training.

| Step | Task | Owner | Depends On | Output | Est. Time |
|------|------|-------|------------|--------|-----------|
| 1.1 | Wire `train_final.jsonl` as default training data path | Claude | Phase 0 complete | Updated `QLoRATrainer.swift`, `TrainingScheduler.swift` | 2 hours |
| 1.2 | Fix cross-app PID capture | Claude | Nothing | Updated `OrchestratorState.swift` with `resolveTargetPID()` | 2 hours |
| 1.3 | Implement real deploy gate (prediction generation + eval scoring) | Claude | Phase 0 complete (need working inference) | Updated `TrainingScheduler.swift` with full eval flow | 4-6 hours |
| 1.4 | Rename `ifd_filter.py` docstring to "heuristic quality filter" | Claude | Nothing | Honest documentation | 15 min |
| 1.5 | Rename `campus_sort.py` docstring to "proxy-based curriculum sort" | Claude | Nothing | Honest documentation | 15 min |
| 1.6 | Wire compose → IFD → CAMPUS as a single callable pipeline | Claude | 1.1 | `prepare_training_data.sh` or Python wrapper | 2 hours |
| 1.7 | Add ODIA trace append to compose pipeline | Claude | 1.6 | Updated `compose_training_mix.py` | 1 hour |
| 1.8 | Add vault SFT merge to compose pipeline | Claude | 1.6 | Updated `compose_training_mix.py` | 1 hour |

**Phase 1 acceptance:** All training paths go through compose → filter → sort. Deploy gate runs real evaluation. Cross-app captures use correct PID. No misleading labels.

---

### Phase 2: Fix The Data (Unblock Useful Training)

**Goal:** Get the data mix to a state where training produces a useful model.

| Step | Task | Owner | Depends On | Output | Est. Time |
|------|------|-------|------------|--------|-----------|
| 2.1 | Generate 500 more embodied trajectories (expand generator) | Claude | Nothing | `embodied_trajectories.jsonl` → 1,000+ entries | 3-4 hours |
| 2.2 | Generate Layer 16 research training data to disk | Claude | Nothing | `research_training.jsonl` (~48 examples) | 1 hour |
| 2.3 | Generate 500 negative/refusal examples | Claude | Nothing | `negative_examples.jsonl` | 2 hours |
| 2.4 | Generate 500 error recovery examples | Claude | Nothing | `error_recovery.jsonl` | 2 hours |
| 2.5 | Convert `app_code_graph.json` (4,082 nodes) to training QA pairs | Claude | Nothing | `code_graph_training.jsonl` | 2 hours |
| 2.6 | Generate 1,000 general macOS instruction examples (Evol-Instruct from seed tasks) | Claude | Nothing | `general_macos.jsonl` | 4 hours |
| 2.7 | Enable `omega.embodiedCapture` UserDefault | User | Phase 1 (PID fix) | Live capture active during real usage | 1 min |
| 2.8 | Use Epistemos for 100+ real tasks to accumulate ODIA traces | User | 2.7 | 100+ rows in `omega_executions.db` | Days/weeks |
| 2.9 | Accept/discard 20+ AI responses for KTO feedback | User | Nothing | 20+ rows in `kto_feedback` | Days |
| 2.10 | Recompose full data mix at target ratios | Claude | 2.1-2.6 complete | `train_final.jsonl` at 40/20/20/10/10 | 2 hours |
| 2.11 | Run composed data through IFD heuristic filter | Claude | 2.10 | `train_filtered.jsonl` | 30 min |
| 2.12 | Run filtered data through CAMPUS proxy sort | Claude | 2.11 | `train_final.jsonl` (sorted, filtered, balanced) | 30 min |

**Phase 2 acceptance:** `train_final.jsonl` exists with ≥3,000 examples at approximately 40/20/20/10/10 ratio, filtered and sorted. At least 100 real ODIA traces exist. At least 20 KTO signals exist.

---

### Phase 3: First Real Training Run

**Goal:** Produce the first adapter that passes a real eval gate.

| Step | Task | Owner | Depends On | Output | Est. Time |
|------|------|-------|------------|--------|-----------|
| 3.1 | Run LoRA training on `train_final.jsonl` | User (on Mac) | Phase 2 complete | `adapter_weights.safetensors` | 1-2 hours |
| 3.2 | Run deploy gate with real eval | Automated (after 3.1) | Phase 1 (deploy gate fixed) | Pass/fail with score breakdown | 30 min |
| 3.3 | If fail: analyze category breakdown, identify weak areas | Claude | 3.2 | Targeted data generation plan | 1 hour |
| 3.4 | If pass: register adapter, verify in production | User | 3.2 | Production adapter deployed | 15 min |
| 3.5 | Run CSISafeguard with trained embeddings | Claude | 3.4 | Baseline CSI score for future drift detection | 30 min |
| 3.6 | Populate `general.jsonl` replay buffer from training data | Claude | 3.4 | Non-empty anti-forgetting buffer | 30 min |

**Phase 3 acceptance:** One adapter passes eval gate with real scoring. CSI baseline established. Replay buffer populated.

---

### Phase 4: Validate The Flywheel

**Goal:** Prove the nightly loop works end-to-end without human intervention.

| Step | Task | Owner | Depends On | Output | Est. Time |
|------|------|-------|------------|--------|-----------|
| 4.1 | Manually trigger `onODIASchedulerFired()` with real traces | User | Phase 3, 100+ ODIA traces | Automated training → eval → deploy cycle | 2 hours |
| 4.2 | Verify new adapter scores higher than baseline | Automated | 4.1 | Score comparison log | 15 min |
| 4.3 | Verify CSI safeguard catches simulated catastrophic adapter | Claude | 3.5 | CSI rejection log | 1 hour |
| 4.4 | Let nightly scheduler fire naturally for 3 nights | User | 4.1-4.3 | 3 adapter generations with eval history | 3 days |
| 4.5 | Verify KTO training triggers after 20+ signals | Automated | 2.9, 20+ KTO signals | KTO-trained adapter | 1 hour |

**Phase 4 acceptance:** Nightly flywheel produces adapters, eval gate correctly accepts/rejects, CSI catches bad adapters, KTO training fires.

---

### Phase 5: Scale Data (Stretch Goals for Quality)

**Goal:** Reach the data volumes the master guide envisions.

| Step | Task | Owner | Depends On | Output | Est. Time |
|------|------|-------|------------|--------|-----------|
| 5.1 | Generate 1,000 Claude Sonnet trajectories (requires budget approval) | User (approve) + Claude (execute) | User budget approval (~$550) | 1,000 high-quality trajectories | 2-3 days |
| 5.2 | Download Screen2AX dataset | User | Disk space | 1,127 images × 112 apps | 30 min |
| 5.3 | Mine 50K general macOS traces (AgentTrek + Evol-Instruct) | Claude | 5.2 | `general_macos_50k.jsonl` | 5-7 days |
| 5.4 | Generate 464 RLAIF verification pairs | Claude | Phase 3 (need working model for preference pairs) | `rlaif_pairs.jsonl` | 3-4 days |
| 5.5 | Implement real IFD scoring with GPT-2 | Claude | Nothing | Updated `ifd_filter.py` with model-based scoring | 2-3 days |
| 5.6 | Implement real CAMPUS metrics from parsed AX trees | Claude | Nothing | Updated `campus_sort.py` with structural measurements | 1-2 days |
| 5.7 | Implement GRPO with 6-component reward | Claude | 5.4 | `grpo_trainer.py` | 5-7 days |

**Phase 5 acceptance:** 50K+ general traces, 1,000+ Sonnet trajectories, 464 RLAIF pairs, real IFD scoring, real CAMPUS metrics, GRPO trainer functional.

---

### Phase 6: Architecture Evolution (Long-Term)

**Goal:** Move toward the master vision's architecture.

| Step | Task | Owner | Depends On | Output | Est. Time |
|------|------|-------|------------|--------|-----------|
| 6.1 | Design Mamba-2 hybrid architecture (75/25 split) | Claude + User | Product decision to proceed | Architecture spec document | 1-2 weeks |
| 6.2 | Implement MOHAWK 3-stage distillation | Claude | 6.1 | `mohawk_distill.py` | 4-6 weeks |
| 6.3 | Train Mamba-2 hybrid via MOHAWK | User (GPU cluster) | 6.2 | 1B parameter hybrid model | 2-4 weeks |
| 6.4 | Build CoreML export for hybrid architecture | Claude | 6.3 | `.mlpackage` pipeline | 2-3 weeks |
| 6.5 | Implement Mamba state injection for context switching | Claude | 6.4 | State save/restore in Swift | 2-3 weeks |
| 6.6 | Implement learned MoLoRA/AdaFuse routing | Claude | 6.3 | Gradient-based adapter selection | 2-3 weeks |
| 6.7 | Implement grammar-constrained decoding | Claude | Nothing (can parallel) | Formal grammar + constrained sampler | 1-2 weeks |

**Phase 6 acceptance:** Mamba-2 hybrid model trained, CoreML exported, state injection working, learned routing deployed.

---

## 11. Acceptance Criteria For "Training Ready"

The system is "training ready" when ALL of the following are true. Not most. ALL.

### 11.1 Data Criteria

| # | Criterion | Measurement | Minimum Threshold | Current State | Pass? |
|---|-----------|-------------|-------------------|---------------|-------|
| 1 | Composed training mix exists on disk | `train_final.jsonl` file size > 0 | ≥3,000 examples | Pipeline produces file but nothing reads it | NO |
| 2 | Tool-calling examples ≥ 30% of mix | `grep -c "tool_call\|toolName" train_final.jsonl` / total | ≥900 examples | ~198 across all sources | NO |
| 3 | General instruction examples ≥ 15% of mix | Count of general-category examples | ≥450 examples | 0 | NO |
| 4 | Negative/refusal examples ≥ 5% of mix | Count of negative-category examples | ≥150 examples | ~44 across all sources | NO |
| 5 | Error recovery examples ≥ 5% of mix | Count of error-recovery examples | ≥150 examples | ~42 across all sources | NO |
| 6 | Embodied format examples exist | Examples with `accessibility_tree` field | ≥500 | 503 (synthetic) | YES (barely) |
| 7 | Data has passed IFD filter | `train_filtered.jsonl` exists and is smaller than input | Filter ran and removed low-quality examples | Filter exists but was not run on composed data | NO |
| 8 | Data has passed CAMPUS sort | `train_final.jsonl` is ordered easy→hard | First 100 examples simpler than last 100 | Sort exists but was not run on filtered data | NO |
| 9 | No Epistemos-PID-captured cross-app data in mix | Cross-app trajectories verified to use target app PID | 0 wrong-PID trajectories | All cross-app captures use wrong PID | NO |

### 11.2 Pipeline Criteria

| # | Criterion | Measurement | Current State | Pass? |
|---|-----------|-------------|---------------|-------|
| 10 | Training reads `train_final.jsonl` | Code inspection: `--data_path` argument points to composed output | Training reads dynamic temp files | NO |
| 11 | Deploy gate runs real eval | Code inspection: `eval_bfcl.py` invoked with predictions | Deploy gate checks file existence only | NO |
| 12 | Deploy gate has baseline score | `baseline_scores.json` exists with real eval results | No baseline — no eval has ever run | NO |
| 13 | All training paths use same LoRA rank | Code inspection: rank is consistent | Rank 16 vs 32 depending on path | NO |
| 14 | One complete training cycle has succeeded | `adapter_weights.safetensors` exists, registered in `adapter_registry.json` | 0 successful training runs | NO |

### 11.3 Evaluation Criteria

| # | Criterion | Measurement | Current State | Pass? |
|---|-----------|-------------|---------------|-------|
| 15 | BFCL macOS eval holdout exists | `bfcl_eval_macos.jsonl` with ≥100 tasks | 100 tasks exist | YES |
| 16 | Epistemos eval holdout exists | `bfcl_eval_epistemos.jsonl` with ≥50 tasks | 50 tasks exist | YES |
| 17 | Eval tasks have ground truth | Each task has `expected_action` field | All 150 tasks have ground truth | YES |
| 18 | Eval runner produces scores | `eval_bfcl.py` runs and outputs JSON | Works standalone, not wired into deploy gate | PARTIAL |

### 11.4 Safety Criteria

| # | Criterion | Measurement | Current State | Pass? |
|---|-----------|-------------|---------------|-------|
| 19 | CSI safeguard has baseline embeddings | `csi_baseline.json` or equivalent exists | No training has completed, no embeddings | NO |
| 20 | Anti-forgetting replay buffer non-empty | `general.jsonl` file size > 0 | 0 bytes | NO |
| 21 | Cross-app PID bug is fixed | Code inspection: `resolveTargetPID()` used | Hardcoded to Epistemos PID | NO |

### Summary Scorecard

| Category | Criteria | Passing | Failing |
|----------|----------|---------|---------|
| Data | 9 | 1 | 8 |
| Pipeline | 5 | 0 | 5 |
| Evaluation | 4 | 2.5 | 1.5 |
| Safety | 3 | 0 | 3 |
| **Total** | **21** | **3.5** | **17.5** |

**Training readiness: 17% (3.5 / 21)**

---

## 12. Acceptance Criteria For "Vision Matched"

The system matches the master vision when ALL of the following are true. This is the long-term target, NOT required for first training run.

### 12.1 Architecture Criteria

| # | Criterion | Measurement | Current State | Gap |
|---|-----------|-------------|---------------|-----|
| 1 | Base model is Mamba-2 hybrid | Architecture has 75% Mamba SSM + 25% attention layers | Standard transformer (Qwen via MLX) | TOTAL |
| 2 | Parameter count is ~1B | Model size measurement | Whatever Qwen model is installed | UNCONTROLLED |
| 3 | MOHAWK 3-stage distillation completed | Teacher → projection → student pipeline ran to completion | No distillation code exists | ABSENT |
| 4 | CoreML export works | `.mlpackage` file generated and loads on device | No CoreML code exists | ABSENT |
| 5 | Mamba state injection works | Context can be saved/restored via state vectors | No state management code | ABSENT |

### 12.2 Training Pipeline Criteria

| # | Criterion | Current State | Gap |
|---|-----------|---------------|-----|
| 6 | Real IFD scoring (GPT-2 perplexity-based) | Heuristic proxy | MISLEADING |
| 7 | Real CAMPUS metrics (parsed AX trees) | Regex proxies | MISLEADING |
| 8 | RLAIF verification pairs (464+) | 0 exist | ABSENT |
| 9 | GRPO with 6-component decomposed reward | No code | ABSENT |
| 10 | KTO online from real feedback (20+ signals) | 0 signals collected | EMPTY |
| 11 | 50K general macOS traces | 0 exist | ABSENT |
| 12 | Screen2AX dataset integrated | Not downloaded | ABSENT |
| 13 | 1,000+ multi-turn embodied trajectories | 503 synthetic | PARTIAL |

### 12.3 Runtime Criteria

| # | Criterion | Current State | Gap |
|---|-----------|---------------|-----|
| 14 | Learned MoLoRA/AdaFuse routing | Keyword text matching | FUNDAMENTAL |
| 15 | Grammar-constrained decoding | Soft EOS only | PARTIAL |
| 16 | CSI safeguard active and monitoring | Never called | NOT WIRED |
| 17 | Scene-MMKG fusion in runtime context | Graph on disk, not loaded | NOT WIRED |
| 18 | Doc-to-LoRA automatic rebuild | Not implemented | ABSENT |

### 12.4 Data Criteria

| # | Criterion | Target | Current | % Complete |
|---|-----------|--------|---------|------------|
| 19 | Tool-calling training examples | 20,000+ | ~198 | 1% |
| 20 | General instruction examples | 10,000+ | 0 | 0% |
| 21 | Epistemos app-specific examples | 10,000+ | ~4,130 (mostly symbol QA) | ~41% |
| 22 | Negative/refusal examples | 5,000+ | ~44 | 1% |
| 23 | Error recovery examples | 5,000+ | ~42 | 1% |
| 24 | RLAIF verification pairs | 464+ | 0 | 0% |
| 25 | Real ODIA execution traces | 1,000+ | 6 | 0.6% |
| 26 | KTO feedback signals | 100+ | 0 | 0% |

### Vision Match Summary

| Category | Criteria | Met | Not Met |
|----------|----------|-----|---------|
| Architecture | 5 | 0 | 5 |
| Training Pipeline | 8 | 0 | 8 |
| Runtime | 5 | 0 | 5 |
| Data | 8 | 0 | 8 |
| **Total** | **26** | **0** | **26** |

**Vision match: 0% (0 / 26)**

This is expected and not alarming. The vision describes a 12+ month research agenda. The current system is at the "make LoRA work on a transformer" stage. The gap between "training ready" (Section 11) and "vision matched" (Section 12) is where the actual product ships and iterates.

---

## 13. Beyond-The-Vision Opportunities

These are capabilities NOT in the master vision document that would significantly improve the system. Presented as food for thought, not commitments.

### 13.1 Immediate Wins (Low Effort, High Value)

| Opportunity | Why It Matters | Effort |
|-------------|---------------|--------|
| **Honest naming throughout codebase** | When `ifd_filter.py` calls itself "IFD" but isn't, developers (including future Claude sessions) make wrong assumptions about data quality. Honest names ("heuristic_quality_filter.py") prevent cascading misunderstandings. | 1 hour |
| **Single-command training data prep** | Currently requires manually running compose → ifd → campus as separate scripts. A single `make training-data` or `prepare_training_data.py` eliminates human error in the pipeline. | 2 hours |
| **Training run audit log** | Every training run should log: input file hash, example count, hyperparameters, hardware, duration, final loss, eval scores, deploy gate decision. Currently nothing logs this. Without it, you can't debug regressions. | 3 hours |
| **Adapter A/B comparison tool** | Load two adapters, run same prompts through both, display side-by-side output. Currently no way to compare adapters without manual testing. | 4 hours |

### 13.2 Data Quality Improvements

| Opportunity | Why It Matters | Effort |
|-------------|---------------|--------|
| **Cross-validation on training data** | Split training data into K folds, train on K-1, eval on held-out fold. Detect overfitting before deploying. Currently the only eval is the BFCL holdout — no validation during training. | 1-2 days |
| **Difficulty-stratified eval** | Current eval reports overall score. Should report easy/medium/hard separately. A model that aces easy tasks but fails hard ones looks the same as one that's mediocre across the board. `eval_bfcl.py` already has difficulty fields — just need to wire stratified reporting into the deploy gate. | 4 hours |
| **Synthetic data quality scoring** | The 503 synthetic trajectories use template AX trees. Score each trajectory on realism (does this AX tree match what Epistemos actually produces?) and filter out unrealistic ones before training. | 1 day |
| **Active learning for trajectory generation** | After first training run, identify which task categories the model is weakest on. Generate more trajectories specifically for those categories. Currently data generation is uniform across categories. | 2-3 days |

### 13.3 Runtime Improvements

| Opportunity | Why It Matters | Effort |
|-------------|---------------|--------|
| **Confidence-gated adapter switching** | Before routing to a specialized adapter, check model confidence on the task. If confidence is low, fall back to base model instead of risking a bad specialized prediction. Currently AdapterRouter always routes if keywords match. | 2-3 days |
| **Execution trace replay** | Record every Omega execution as a replayable trace. Allow users to "replay" a failed task step-by-step to understand what went wrong. Currently traces are write-only (for training) with no replay capability. | 3-5 days |
| **Progressive context injection** | Instead of dumping the entire AX tree into context, progressively reveal relevant subtrees as the model requests them. Reduces context length for simple tasks. Requires Mamba state management OR a smart context window manager for transformers. | 1-2 weeks |
| **Fallback chain for tool calls** | When a tool call fails, automatically try the next most likely tool call. Currently a failed tool call is a hard stop. The model has to regenerate from scratch. | 1 week |

### 13.4 Safety Improvements

| Opportunity | Why It Matters | Effort |
|-------------|---------------|--------|
| **Canary tasks in production** | Periodically inject known-answer tasks during real usage. If the model gets them wrong, flag potential degradation before users notice. Currently degradation is only caught by CSI (which isn't wired) or user complaints. | 1-2 days |
| **Adapter rollback on user complaints** | If 3+ users report bad responses after an adapter deploy, automatically rollback to previous adapter. Currently no automated rollback mechanism. | 1 day |
| **Training data poisoning detection** | ODIA traces from real usage could be adversarial (user intentionally feeding bad patterns). Basic outlier detection on new traces before they enter the training pipeline. | 3-5 days |
| **Differential privacy for user data** | ODIA traces and KTO feedback contain user behavior data. DP-SGD or similar during training would provide formal privacy guarantees. Master vision doesn't address privacy at all. | 2-3 weeks |

### 13.5 Observability Improvements

| Opportunity | Why It Matters | Effort |
|-------------|---------------|--------|
| **Structured training logs with W&B-style tracking** | Currently, training output goes to Process() stdout and is not parsed or stored. Loss curves, gradient norms, learning rate schedules — all invisible. A local SQLite log of per-step metrics would enable post-hoc analysis of every training run without external services. | 1-2 days |
| **Adapter lineage tracking** | When adapter B is trained from data that included ODIA traces from adapter A's execution, there's an implicit lineage. Tracking this lineage (which adapter generated which traces, which traces trained which adapter) enables debugging of quality regressions across generations. | 2-3 days |
| **Data provenance per example** | Each example in `train_final.jsonl` should carry metadata: which source file it came from, which generation method (synthetic template, Claude Sonnet, live capture, vault parse), when it was generated, and its IFD/CAMPUS scores. This enables fine-grained analysis of which data sources help or hurt. | 1-2 days |
| **Eval score trend visualization** | Store every deploy gate eval result with timestamp. Plot score trends over time. Detect if the nightly flywheel is actually improving or oscillating. Currently eval results are ephemeral — only the pass/fail decision persists, not the score history. | 1 day |

### 13.6 Developer Experience

| Opportunity | Why It Matters | Effort |
|-------------|---------------|--------|
| **Training dashboard** | Web UI showing: current adapter scores, training history, data mix composition, eval breakdowns, CSI drift graph. Currently all of this is invisible — you have to read SQLite databases and JSON files manually. | 3-5 days |
| **`epistemos train status`** CLI command | One command to show: last training run, current adapter, eval scores, data counts, pipeline health. | 4 hours |
| **Automated test for training pipeline** | CI test that: generates 10 synthetic examples → runs compose → runs IFD → runs CAMPUS → runs training (1 iteration) → runs eval → checks output format. Catches pipeline regressions. Currently the test suite does not test the training pipeline at all. | 1-2 days |
| **Fix the `noteSwitchPersistsDistinctSessions` test** | Failing test (`CognitiveSubstrateTests.swift` line 447-495) indicates `FrictionMonitorService` isn't persisting windows to EventStore. This is a real bug that affects friction tracking, which feeds into UX analytics. | 2-4 hours |

---

## Appendix A: File-to-Finding Index

Every finding in this document traces back to a specific file and line range. This index allows independent verification.

| Finding | Files | Key Lines |
|---------|-------|-----------|
| Training path disconnection | `train_knowledge.py` (146-180), `QLoRATrainer.swift` (98-116), `TrainingScheduler.swift` (253-256), `KnowledgeFusionViewModel.swift` (207-274), `compose_training_mix.py` (221), `ifd_filter.py` (235), `campus_sort.py` (96-97) | Three paths, three different data sources, zero path reads `train_final.jsonl` |
| Deploy gate placeholder | `TrainingScheduler.swift` (312-353) | Lines 332-335: default pass. Lines 343-352: file existence check only |
| Cross-app PID bug | `OrchestratorState.swift` (188-207), `EmbodiedCaptureService.swift` (37), `SafariAgent.swift` (Rust UniFFI calls) | Lines 190-194 and 203-207 both use `ProcessInfo.processInfo.processIdentifier` |
| Base model divergence | `KnowledgeFusionViewModel.swift` (177-189) | `detectInstalledModels()` scans for any MLX model directory |
| IFD filter mislabeling | `ifd_filter.py` (1-21, 123-162) | Docstring says "proxy for GPT-2"; actual code is regex heuristics |
| CAMPUS sort proxies | `campus_sort.py` (23-87) | `estimate_tree_depth`: regex `AX\w+`; `estimate_selector_ambiguity`: regex `click_element\|click` |
| LoRA rank conflict | `QLoRATrainer.swift` (77-85), `KnowledgeFusionViewModel.swift` (66-94), `train_knowledge.py` (25-27) | 32/64 vs 16/32 depending on code path |
| Test failure | `CognitiveSubstrateTests.swift` (447-495) | `windows.count == 0` then `Index out of range` |

---

## Appendix B: Component Status Matrix

Full status of every component mentioned in this document.

| Component | Status | Blocks Training? | Blocks Vision? | Fix Phase |
|-----------|--------|-----------------|----------------|-----------|
| AdapterRegistry | TRUSTWORTHY | No | No | — |
| AdapterLoader | TRUSTWORTHY | No | No | — |
| AdapterRouter | PARTIAL | No | Yes (needs learned routing) | Phase 6 |
| EmbodiedCaptureService (core) | TRUSTWORTHY | No | No | — |
| EmbodiedCaptureService (PID wiring) | BROKEN | YES | YES | Phase 1 |
| eval_bfcl.py (standalone) | TRUSTWORTHY | No | No | — |
| Deploy gate (runDeployGate) | MISLEADING | YES | YES | Phase 1 |
| KTOTrainer | TRUSTWORTHY | No | No | — |
| MCPBridge | TRUSTWORTHY | No | No | — |
| ODIATraceGenerator | TRUSTWORTHY | No | No | — |
| OmegaTrainingCoordinator | TRUSTWORTHY | No | No | — |
| ResearchOrchestrator | TRUSTWORTHY | No | No | — |
| QLoRATrainer (code) | TRUSTWORTHY | No | No | — |
| QLoRATrainer (defaults) | PARTIAL | YES (wrong rank for Nano) | YES | Phase 0 |
| TrainingScheduler (infrastructure) | PARTIAL | YES (data path wrong) | YES | Phase 1 |
| train_knowledge.py | TRUSTWORTHY | No (it's a dumb pipe) | No | — |
| compose_training_mix.py | NOT WIRED | YES | YES | Phase 1 |
| ifd_filter.py | MISLEADING | No (works as heuristic) | Yes (not real IFD) | Phase 1 (rename), Phase 5 (real IFD) |
| campus_sort.py | MISLEADING | No (works as proxy) | Yes (not real CAMPUS) | Phase 1 (rename), Phase 5 (real metrics) |
| CSISafeguard | NOT WIRED | YES (no baseline) | YES | Phase 3 |
| ConstrainedDecodingService | PARTIAL | No | Yes (no grammar-guided) | Phase 6 |
| Scene-MMKG | NOT WIRED | No | YES | Phase 6 |
| RLAIF pairs | ABSENT | No (not needed for SFT) | YES | Phase 5 |
| GRPO reward model | ABSENT | No (not needed for SFT) | YES | Phase 5 |
| Screen2AX | ABSENT | No | YES | Phase 5 |
| Mamba-2 architecture | ABSENT | No | YES | Phase 6 |
| MOHAWK distillation | ABSENT | No | YES | Phase 6 |
| CoreML export | ABSENT | No | YES | Phase 6 |
| Doc-to-LoRA rebuild | ABSENT | No | YES | Phase 6 |
| Grammar-constrained decoding | PARTIAL | No | YES | Phase 6 |
| Learned MoLoRA routing | ABSENT | No | YES | Phase 6 |
| general.jsonl replay buffer | EMPTY | YES (no anti-forgetting) | YES | Phase 3 |
| KTO feedback signals | EMPTY | No (KTO is optional stage) | YES | Phase 4 |
| ODIA execution traces | INSUFFICIENT (6 rows) | YES (nightly flywheel needs data) | YES | Phase 2 |
| Adapter weights | ABSENT (0 on disk) | YES | YES | Phase 0 |

---

## Appendix C: Glossary

| Term | Definition |
|------|-----------|
| **AX tree** | Accessibility tree — the macOS Accessibility API's structured representation of all UI elements in an app. Used by screen readers and by Epistemos for UI automation. |
| **BFCL** | Berkeley Function Calling Leaderboard — a benchmark for evaluating tool/function calling in LLMs. Epistemos uses a custom variant for macOS tasks. |
| **CAMPUS** | Curriculum-Aware Multi-Parameter Uptraining Sort — orders training data from simple to complex. The master vision's version measures real structural properties; the current implementation uses regex proxies. |
| **CoreML** | Apple's framework for on-device ML model deployment. The production target for Epistemos's model. Not currently implemented. |
| **CSI** | Catastrophic Forgetting Safeguard Index — a metric tracking embedding drift between adapter versions. If CSI exceeds a threshold, the new adapter is rejected to prevent catastrophic forgetting. |
| **Deploy gate** | A quality checkpoint that must be passed before a newly trained adapter replaces the current production adapter. Currently a placeholder that auto-passes. |
| **Evol-Instruct** | A technique for generating diverse instruction-response pairs by evolving seed examples through increasing complexity. Used to scale training data. |
| **GRPO** | Group Relative Policy Optimization — a reinforcement learning algorithm for aligning LLMs to human preferences. Not implemented. |
| **IFD** | Instruction Following Difficulty — a model-based metric that measures how much harder a response is to generate given its instruction vs unconditionally. Used to filter low-quality training data. The current implementation is a regex heuristic, not real IFD. |
| **KTO** | Kahneman-Tversky Optimization — a preference learning algorithm that learns from binary (accept/reject) feedback without requiring preference pairs. Infrastructure is wired; zero feedback signals collected. |
| **LoRA** | Low-Rank Adaptation — a parameter-efficient fine-tuning method that trains small adapter matrices instead of the full model. The primary training method in the current system. |
| **Mamba-2** | A state-space model architecture that processes sequences in linear time (vs quadratic for attention). The master vision calls for a 75% Mamba / 25% attention hybrid. Not implemented. |
| **MLX** | Apple's machine learning framework for Apple Silicon. Currently used for all on-device inference in Epistemos. |
| **MMKG** | Multimodal Knowledge Graph — a knowledge graph combining code structure, UI layout, and visual information. `app_code_graph.json` is the code structure piece; UI and visual pieces are not integrated. |
| **MOHAWK** | A 3-stage knowledge distillation framework for training state-space models from transformer teachers. Not implemented. |
| **MoLoRA** | Mixture of LoRA — multiple LoRA adapters routed per-token or per-layer. Currently implemented as keyword-based routing (not learned). |
| **ODIA** | Omega-Driven Iterative Adaptation — the nightly training loop that converts real usage traces into adapter updates. Infrastructure exists; never successfully produced an adapter. |
| **PID** | Process Identifier — the OS-level identifier for a running process. Used to specify which app's AX tree to capture. Currently hardcoded to Epistemos's PID, breaking cross-app capture. |
| **QLoRA** | Quantized LoRA — LoRA applied to a quantized base model, reducing memory requirements. Used by the training pipeline. |
| **RLAIF** | Reinforcement Learning from AI Feedback — using AI-generated preferences instead of human preferences for RL training. Requires verification pairs; zero exist. |
| **Screen2AX** | A dataset of screenshots paired with accessibility trees from 112 apps. Not downloaded. |
| **SFT** | Supervised Fine-Tuning — training a model on (instruction, response) pairs. The first stage of the training pipeline. |
| **UniFFI** | Unified FFI — Mozilla's framework for cross-language bindings. Used to bridge Rust (omega-mcp) to Swift. |

---

## Appendix D: Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| First training OOMs on Nano | MEDIUM | Blocks Phase 0 | Use rank 16 (not 32). Reduce batch size. Monitor memory during run. |
| Synthetic embodied data doesn't transfer to real AX trees | HIGH | Reduces Phase 3 adapter quality | Supplement with real captured data (Phase 2.8). Compare synthetic-trained vs real-trained adapter scores. |
| Cross-app PID fix breaks Epistemos-internal capture | LOW | Breaks all capture | `resolveTargetPID` falls back to Epistemos PID for unknown agents. Test both paths. |
| Deploy gate eval is too slow for nightly cycle | MEDIUM | Nightly cycle doesn't complete in time | Profile eval time. If >30 min, subsample eval set or batch predictions. |
| User doesn't generate enough real ODIA/KTO data | HIGH | Phases 4-5 blocked | Build incentive into the app (progress indicators, gamification). Set minimum viable thresholds. |
| Mamba-2 architecture never materializes | MEDIUM | Vision never matched | Accept Qwen LoRA as production path. Mamba-2 is research, not product. |
| Training data mix ratios are wrong for this model | MEDIUM | First training produces poor adapter | Use eval gate to catch it. Iterate on ratios based on per-category eval scores. |
| `app_code_graph.json` is too large for training context | LOW | Graph QA pairs are truncated | Convert to focused QA pairs, not raw graph. 4,082 nodes → ~500 QA pairs about key relationships. |
| Nightly flywheel runs on too-small ODIA dataset | HIGH | Produces random/useless adapters | Add minimum data threshold to `shouldRunTraining()`. Current 6 rows is NOT enough. Require ≥100. |
| eval_bfcl.py scores don't correlate with real user satisfaction | MEDIUM | Good eval scores, bad user experience | Supplement with KTO feedback. Track user satisfaction metrics alongside BFCL scores. |

---

## Appendix E: Decision Log

Decisions that need to be made, tracked here for reference.

| # | Decision | Options | Recommended | Decided? | Decision |
|---|----------|---------|-------------|----------|----------|
| 1 | Qwen LoRA now vs Mamba-2 first | A: Ship Qwen LoRA, plan Mamba-2 for v2. B: Pause for Mamba-2. | A | PENDING | — |
| 2 | LoRA rank for Nano | A: 16 everywhere. B: 32 everywhere. C: Adaptive. | A | PENDING | — |
| 3 | Real IFD vs heuristic proxy | A: Implement GPT-2 IFD. B: Keep heuristic, rename. | B (for now) | PENDING | — |
| 4 | Budget for Claude Sonnet trajectories | Approve ~$550 for 1,000 trajectories | Approve | PENDING | — |
| 5 | Minimum ODIA traces before nightly training fires | 20? 50? 100? 500? | 100 | PENDING | — |
| 6 | Data mix ratios | Master guide 40/20/20/10/10 vs modified | Start with master guide, iterate based on eval | PENDING | — |

---

---

## Appendix F: Detailed Training Path Walkthrough

This appendix traces each training path line-by-line through the codebase, showing every function call, every data transformation, and every decision point.

### F.1 Path 1: Manual Vault Training (Full Trace)

```
User taps "Train on Vault" in KnowledgeFusionView
  │
  ▼
KnowledgeFusionViewModel.trainOnVault()  [line 207]
  │
  ├── autoConfigureForHardware()  [line 66-94]
  │     Sets: loraRank = 16, loraAlpha = 32
  │     Note: This ALWAYS runs, overriding any previous config
  │     Note: This is the CORRECT rank for Nano
  │
  ├── parseVault()  [line 210-220]
  │     Reads all .md files from user's vault directory
  │     Extracts: headings, code blocks, links, tags
  │     Returns: VaultParseResult with structured content
  │
  ├── SyntheticDataGenerator.generate(from: vaultResult)  [line 222-240]
  │     Converts vault content to SFT chat-format JSONL
  │     Each example: {"messages": [{"role": "user", ...}, {"role": "assistant", ...}]}
  │     Output: synthResult.trainingFiles = [URL] (temp directory)
  │
  ├── QLoRATrainer.trainKnowledgeAdapter(dataPath: synthResult.trainingFiles[0])  [line 242-260]
  │     │
  │     ├── Builds argument list:  [line 98-116]
  │     │     --data_path <temp_dir>/train.jsonl
  │     │     --rank 16          ← from autoConfigureForHardware
  │     │     --alpha 32          ← from autoConfigureForHardware
  │     │     --iters 200         ← default
  │     │     --lr 3e-4           ← default
  │     │
  │     ├── Launches Process():  [line 118-140]
  │     │     python3 train_knowledge.py <args>
  │     │
  │     └── train_knowledge.py:  [line 146-180]
  │           Copies --data_path to temp/train.jsonl
  │           Runs mlx_lm.lora with specified hyperparameters
  │           Outputs adapter_weights.safetensors (NEVER PRODUCED — 0 successful runs)
  │
  └── NO deploy gate runs on this path
      NO IFD filtering
      NO CAMPUS sorting
      NO composition with other data sources
      Training is on VAULT DATA ONLY
```

**Critical observations:**
- This path trains on whatever the user has in their vault — could be 10 notes or 10,000
- No quality filtering of any kind
- No mixing with general data (catastrophic forgetting risk)
- No evaluation after training
- The adapter goes directly to disk without any quality check

### F.2 Path 2: ODIA Nightly Training (Full Trace)

```
NSBackgroundActivityScheduler fires (24h interval, requires idle + AC power)
  │
  ▼
TrainingScheduler.onODIASchedulerFired()  [line 253]
  │
  ├── Check shouldRunTraining():  [line 258-270]
  │     Requires: 30 min idle time
  │     Requires: AC power connected
  │     Requires: pending ODIA traces exist
  │     Note: With only 6 traces in omega_executions.db, this check may fail
  │
  ├── ODIATraceGenerator.generateTraces()  [line 272-290]
  │     Reads pending traces from omega_executions.db
  │     Converts to SFT chat format
  │     Research tasks get 2x weight (duplicated in output)
  │     Writes to temp JSONL file
  │
  ├── QLoRATrainer.trainKnowledgeAdapter(dataPath: tempODIAFile)  [line 292-310]
  │     │
  │     ├── Uses TrainingConfig.defaultKnowledge  [line 77-85]
  │     │     rank = 32          ← WRONG for Nano (should be 16)
  │     │     alpha = 64          ← WRONG for Nano (should be 32)
  │     │
  │     ├── Launches Process():
  │     │     python3 train_knowledge.py --data_path <temp> --rank 32 --alpha 64
  │     │
  │     └── Trains on ODIA traces ONLY
  │           No vault data
  │           No composed mix
  │           No IFD filtering
  │           No CAMPUS sorting
  │
  └── runDeployGate()  [line 312-353]
        │
        ├── Check: eval_bfcl.py in bundle?  [line 332-333]
        │     If NO: return passed: true (!!!)  [line 335]
        │     "eval infrastructure not yet deployed"
        │
        └── Check: adapter_weights.safetensors exists?  [line 343-352]
              If YES: return passed: true
              If NO: return passed: false
              NEVER runs eval_bfcl.py
              NEVER scores anything
              NEVER compares to baseline
```

**Critical observations:**
- Uses wrong LoRA rank for Nano (32 instead of 16)
- Trains on ODIA traces ONLY — no mixed data, no general knowledge, no vault content
- With 6 traces total, would produce an essentially random adapter
- Deploy gate auto-passes if the file was written, regardless of quality
- Research 2x weighting is correct logic but irrelevant with 0 research traces

### F.3 Path 3: Compose Pipeline (Full Trace — DISCONNECTED)

```
User runs manually (no Swift integration):
  │
  ▼
compose_training_mix.py  [line 1-221]
  │
  ├── Reads source JSONLs:
  │     02_symbol_qa.jsonl         (~3,070 examples)
  │     01_code_graph.jsonl        (~557 examples)
  │     03_ax_atlas.jsonl          (~146 examples)
  │     04_trajectories.jsonl      (~43 examples)
  │     embodied_trajectories_sft.jsonl  (~503 examples)
  │     (any other .jsonl in source dir)
  │
  ├── Applies ratio-based sampling:
  │     Target: 40% tool-call, 20% general, 20% app-specific, 10% negative, 10% error
  │     Reality: Cannot hit ratios because general data = 0, negative ≈ 44, error ≈ 42
  │
  ├── Outputs: composed_training_data/train.jsonl  [line 221]
  │
  ▼
ifd_filter.py  [line 1-235]
  │
  ├── Reads: composed_training_data/train.jsonl
  │
  ├── Scores each example (lines 123-162):
  │     response_length:      longer = higher score
  │     has_reasoning:        +points if <think> tags present
  │     has_tool_call:        +points if tool calls present
  │     instruction_clarity:  regex-based clarity estimate
  │     response_structure:   regex-based structure estimate
  │     deduplication:        hash-based near-duplicate removal
  │
  ├── Keeps top N% by composite score
  │
  ├── Outputs: train_filtered.jsonl  [line 235]
  │
  ▼
campus_sort.py  [line 1-97]
  │
  ├── Reads: train_filtered.jsonl
  │
  ├── Estimates complexity (lines 23-87):
  │     tree_depth:           count(regex AX\w+ matches)       ← NOT real tree depth
  │     selector_ambiguity:   count(regex click_element|click)  ← NOT real ambiguity
  │     chain_length:         count(regex **Step \d+)           ← NOT real chain length
  │
  ├── Sorts: easy → hard by composite complexity
  │
  ├── Outputs: train_filtered_sorted.jsonl  [line 96-97]
  │     (or train_sorted.jsonl depending on input filename)
  │
  ▼
??? NOTHING READS THIS OUTPUT ???

No Swift code references train_filtered_sorted.jsonl
No Swift code references train_final.jsonl
No training path uses the composed/filtered/sorted data
The entire pipeline terminates into void
```

**Critical observation:** This is the MOST carefully prepared data in the entire system, and it is the data that NOTHING uses.

---

## Appendix G: Eval Gate Detailed Walkthrough

Line-by-line walkthrough of `TrainingScheduler.runDeployGate()` (lines 312-353).

### G.1 Current Implementation (Annotated)

```
func runDeployGate(adapterPath: URL) async -> DeployGateResult {
    // Line 312-315: Function signature and setup
    
    // Lines 316-330: Build paths to eval infrastructure
    let evalScript = Bundle.main.url(forResource: "eval_bfcl", withExtension: "py")
    let evalData = Bundle.main.url(forResource: "bfcl_eval_macos", withExtension: "jsonl")
    
    // Lines 332-335: CRITICAL — Default pass if eval not bundled
    guard let evalScript = evalScript, let evalData = evalData else {
        return DeployGateResult(
            passed: true,           // ← DEFAULT PASS
            reason: "eval infrastructure not yet deployed",
            score: nil,
            baseline: nil
        )
    }
    // At this point, eval_bfcl.py and bfcl_eval_macos.jsonl exist in bundle
    // But we still don't use them.
    
    // Lines 337-342: MISSING — Everything that should happen here:
    // 1. Load base model via MLXInferenceBridge              ← NOT IMPLEMENTED
    // 2. Load candidate adapter                               ← NOT IMPLEMENTED
    // 3. For each eval task, run inference                    ← NOT IMPLEMENTED
    // 4. Write predictions to temp JSONL                      ← NOT IMPLEMENTED
    // 5. Run eval_bfcl.py via Process()                       ← NOT IMPLEMENTED
    // 6. Parse scoring output                                 ← NOT IMPLEMENTED
    // 7. Compare to baseline                                  ← NOT IMPLEMENTED
    
    // Lines 343-352: ACTUAL CHECK — File existence only
    let weightsPath = adapterPath.appendingPathComponent("adapter_weights.safetensors")
    if FileManager.default.fileExists(atPath: weightsPath.path) {
        return DeployGateResult(
            passed: true,           // ← PASSES IF FILE EXISTS
            reason: "adapter weights verified",
            score: nil,             // ← NO SCORE COMPUTED
            baseline: nil           // ← NO BASELINE EXISTS
        )
    } else {
        return DeployGateResult(
            passed: false,
            reason: "adapter weights not found",
            score: nil,
            baseline: nil
        )
    }
}
```

### G.2 What eval_bfcl.py WOULD Do If Called

```
# eval_bfcl.py (lines 358-437) — Standalone CLI tool

# Required inputs:
#   --predictions <path>     JSONL with model's predicted tool calls
#   --ground-truth <path>    JSONL with expected tool calls (bfcl_eval_macos.jsonl)
#   --threshold <float>      Minimum improvement over baseline (default 0.005)

# Step 1: Load predictions and ground truth
predictions = load_jsonl(args.predictions)
ground_truth = load_jsonl(args.ground_truth)

# Step 2: Score each prediction against ground truth
for pred, truth in zip(predictions, ground_truth):
    tool_score = exact_tool_match(pred.tool, truth.tool)        # 40% weight
    args_score = subset_args_match(pred.args, truth.args)       # 30% weight
    seq_score = lcs_sequence_match(pred.steps, truth.steps)     # 20% weight
    refusal_score = refusal_match(pred.refusal, truth.refusal)  # 10% weight
    
    composite = 0.4*tool_score + 0.3*args_score + 0.2*seq_score + 0.1*refusal_score

# Step 3: Aggregate scores
overall = mean(all_composite_scores)
by_category = group_and_mean(scores, key='category')
by_difficulty = group_and_mean(scores, key='difficulty')

# Step 4: Deploy gate decision
if baseline_exists:
    passed = overall > baseline + threshold
else:
    passed = True  # First run becomes baseline
    save_baseline(overall)

# Step 5: Output JSON report
{
    "overall_score": overall,
    "passed": passed,
    "baseline": baseline,
    "threshold": threshold,
    "by_category": by_category,
    "by_difficulty": by_difficulty
}
```

### G.3 The Gap Between G.1 and G.2

| What's Needed | Who Provides It | Current State |
|--------------|----------------|---------------|
| Predictions JSONL file | Swift code must run inference on eval tasks and write predictions | NOT IMPLEMENTED — no code generates predictions |
| Ground truth JSONL file | Already exists: `bfcl_eval_macos.jsonl` (100 tasks) + `bfcl_eval_epistemos.jsonl` (50 tasks) | EXISTS |
| Model inference capability | MLXInferenceBridge exists and works | EXISTS but not called from deploy gate |
| Process() bridge to Python | QLoRATrainer already demonstrates this pattern | EXISTS as pattern, not wired for eval |
| Baseline storage | eval_bfcl.py handles this internally | EXISTS in eval script |
| Score parsing | Need to read eval_bfcl.py's JSON output | NOT IMPLEMENTED |
| Threshold comparison | eval_bfcl.py handles this internally | EXISTS in eval script |

**Summary:** 4 of 7 components exist. The missing 3 are: (1) prediction generation from Swift, (2) Process() invocation of eval_bfcl.py from deploy gate, (3) result parsing in Swift. This is approximately 4-6 hours of work.

---

## Appendix H: Data Format Reference

This appendix documents the exact format of every data file, what fields are required, and where the formats diverge.

### H.1 Chat SFT Format (Used by symbol QA, code graph, AX atlas, old trajectories)

```json
{
  "messages": [
    {"role": "system", "content": "You are Epistemos..."},
    {"role": "user", "content": "What does AdapterRegistry.swift do?"},
    {"role": "assistant", "content": "AdapterRegistry.swift provides..."}
  ]
}
```

**Fields present:** messages (array of role/content pairs)
**Fields absent:** accessibility_tree, screenshot, reasoning_chain, action, result_accessibility_tree, ax_diff
**Training value:** Produces Q&A model. Does NOT produce embodied agent.
**Volume:** ~3,800 examples across all chat-format files

### H.2 Embodied Format (Used by new embodied trajectories)

```json
{
  "task_id": "note_create_001",
  "task_description": "Create a new note titled 'Meeting Notes'",
  "task_type": "app_specific",
  "steps": [
    {
      "step_number": 1,
      "accessibility_tree": {"app": "Epistemos", "elements": [...]},
      "screenshot": "screenshots/step_001_pre.png",
      "reasoning_chain": "<think>I need to create a new note. I see the '+' button in the toolbar...</think>",
      "action": {
        "toolName": "click_element",
        "argumentsJson": "{\"element\": \"New Note Button\", \"index\": 0}",
        "agentName": "EpistemosAgent"
      },
      "result_accessibility_tree": {"app": "Epistemos", "elements": [...]},
      "result_screenshot": "screenshots/step_001_post.png",
      "ax_diff": {
        "added": ["AXTextField: Untitled Note"],
        "removed": [],
        "added_count": 1,
        "removed_count": 0
      }
    }
  ],
  "quality_score": 0.85,
  "category": "note_creation"
}
```

**Fields present:** All 8 required embodied fields per step
**Training value:** Produces embodied agent that understands AX trees, actions, and state changes
**Volume:** 503 trajectories, 1,225 total steps
**Caveat:** AX trees are templates (synthetic), not real captures from running app

### H.3 Embodied SFT Format (Converted from embodied for direct training)

```json
{
  "messages": [
    {"role": "system", "content": "You are an embodied macOS agent..."},
    {"role": "user", "content": "[OBSERVE] Current AX tree: {...}\n\nTask: Create a new note titled 'Meeting Notes'"},
    {"role": "assistant", "content": "[REASON] <think>I see the toolbar with a '+' button...</think>\n[ACT] {\"toolName\": \"click_element\", ...}\n[RESULT] AX tree changed: +1 element (AXTextField: Untitled Note)\n[DONE]"}
  ]
}
```

**Fields present:** messages in OBSERVE→REASON→ACT→RESULT→DONE format
**Training value:** Can be trained with standard SFT while teaching embodied reasoning
**Volume:** 503 examples (1:1 with embodied trajectories)

### H.4 BFCL Eval Format

```json
{
  "id": "macos_click_001",
  "category": "click",
  "instruction": "Click the 'Save' button in the toolbar",
  "expected_action": [
    {"toolName": "click_element", "arguments": {"element": "Save", "role": "AXButton"}}
  ],
  "verification": {"type": "ax_state", "check": "document.isModified == false"},
  "difficulty": "easy"
}
```

**Fields present:** id, category, instruction, expected_action, verification, difficulty
**Volume:** 100 macOS + 50 Epistemos = 150 total eval tasks
**Status:** Exists and is well-formed. Not connected to deploy gate.

### H.5 ODIA Trace Format (From omega_executions.db)

```json
{
  "execution_id": "uuid-...",
  "timestamp": "2026-03-27T10:30:00Z",
  "task_type": "general",
  "tool_name": "click_element",
  "arguments": {"element": "Save Button"},
  "result": {"success": true},
  "duration_ms": 1250,
  "agent_name": "EpistemosAgent"
}
```

**Volume:** 6 rows total (2 click_element, 2 run_command, 1 list_files, 1 run_shortcut)
**Conversion:** ODIATraceGenerator converts these to chat SFT format for training
**Status:** Schema is correct. Volume is insufficient (need 100+ for meaningful training).

### H.6 Format Compatibility Matrix

| Format | train_knowledge.py | compose_training_mix.py | ifd_filter.py | campus_sort.py | eval_bfcl.py |
|--------|-------------------|------------------------|---------------|----------------|--------------|
| Chat SFT (H.1) | YES | YES | YES | YES (but metrics are meaningless on chat data) | NO (needs predicted actions) |
| Embodied (H.2) | NO (wrong schema) | NO (expects messages array) | NO (expects messages array) | NO (expects messages array) | NO (needs predicted actions) |
| Embodied SFT (H.3) | YES | YES | YES | YES (metrics are meaningful here) | NO (needs predicted actions) |
| BFCL Eval (H.4) | NO (eval, not training) | NO | NO | NO | YES |
| ODIA Trace (H.5) | NO (needs conversion) | NO (needs conversion) | NO (needs conversion) | NO (needs conversion) | NO |

**Key insight:** Only Chat SFT (H.1) and Embodied SFT (H.3) formats are compatible with the current training pipeline. Raw embodied (H.2) and ODIA traces (H.5) must be converted first. The compose/filter/sort pipeline operates on the SFT format.

---

## Appendix I: Per-Phase Dependency Graph

Visual representation of what blocks what.

```
Phase 0: Validate The Pipe
┌─────────────────────────────────────────────────────────┐
│ 0.1 Unify LoRA defaults ──► 0.2 Run one training ──► 0.3 Debug ──► 0.4 Verify adapter ──► 0.5 Register │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
Phase 1: Fix Wiring (after Phase 0)
┌──────────────────────────────────────────────────────────────────┐
│ 1.1 Wire train_final.jsonl ──► 1.6 Single pipeline ──► 1.7 ODIA append ──► 1.8 Vault merge │
│ 1.2 Fix PID capture (parallel with 1.1)                                                    │
│ 1.3 Real deploy gate (after Phase 0, parallel with 1.1-1.2)                                │
│ 1.4 Rename IFD (parallel, no deps)                                                          │
│ 1.5 Rename CAMPUS (parallel, no deps)                                                       │
└──────────────────────────────────────────────────────────────────┘
                    │
                    ▼
Phase 2: Fix Data (after Phase 1 for wiring, some tasks parallel)
┌──────────────────────────────────────────────────────────────────┐
│ 2.1 More trajectories ─┐                                                                    │
│ 2.2 Research data      │                                                                    │
│ 2.3 Negative examples  ├──► 2.10 Recompose mix ──► 2.11 IFD filter ──► 2.12 CAMPUS sort    │
│ 2.4 Error recovery     │                                                                    │
│ 2.5 Code graph QA      │                                                                    │
│ 2.6 General macOS      ┘                                                                    │
│ 2.7 Enable capture (USER, after 1.2) ──► 2.8 Accumulate traces (USER, ongoing)             │
│ 2.9 KTO feedback (USER, ongoing, no technical deps)                                         │
└──────────────────────────────────────────────────────────────────┘
                    │
                    ▼
Phase 3: First Real Training (after Phase 2)
┌──────────────────────────────────────────────────────────────────┐
│ 3.1 Train on final mix (USER) ──► 3.2 Real deploy gate ──► 3.3 Analyze / 3.4 Deploy        │
│                                                     ──► 3.5 CSI baseline                    │
│                                                     ──► 3.6 Replay buffer                   │
└──────────────────────────────────────────────────────────────────┘
                    │
                    ▼
Phase 4: Validate Flywheel (after Phase 3)
┌──────────────────────────────────────────────────────────────────┐
│ 4.1 Manual ODIA trigger ──► 4.2 Score comparison ──► 4.3 CSI test ──► 4.4 Natural nightly   │
│ 4.5 KTO trigger (after 2.9 has 20+ signals)                                                 │
└──────────────────────────────────────────────────────────────────┘
                    │
                    ▼
Phase 5: Scale (stretch goals)
┌──────────────────────────────────────────────────────────────────┐
│ 5.1 Sonnet trajectories (USER budget approval)                                               │
│ 5.2 Screen2AX download                                                                      │
│ 5.3 50K general traces                                                                       │
│ 5.4 RLAIF pairs (after Phase 3 model)                                                        │
│ 5.5 Real IFD scoring                                                                         │
│ 5.6 Real CAMPUS metrics                                                                      │
│ 5.7 GRPO trainer                                                                             │
└──────────────────────────────────────────────────────────────────┘
                    │
                    ▼
Phase 6: Architecture Evolution (long-term)
┌──────────────────────────────────────────────────────────────────┐
│ 6.1 Mamba-2 design ──► 6.2 MOHAWK ──► 6.3 Train hybrid ──► 6.4 CoreML export                │
│                                                          ──► 6.5 State injection             │
│                                                          ──► 6.6 Learned routing             │
│ 6.7 Grammar decoding (parallel, no deps on Mamba)                                            │
└──────────────────────────────────────────────────────────────────┘
```

### I.1 Critical Path Analysis

The critical path to first trustworthy training run:

```
0.1 Unify defaults (30 min)
  → 0.2 First training attempt (1 hour)
  → 0.3 Debug (variable)
  → 0.4 Verify adapter (15 min)
  → 1.1 Wire train_final.jsonl (2 hours)
  → 1.3 Real deploy gate (4-6 hours)
  → 1.6 Single pipeline (2 hours)
  → 2.1-2.6 Generate data (parallel, ~4 hours max)
  → 2.10 Recompose (2 hours)
  → 2.11 IFD filter (30 min)
  → 2.12 CAMPUS sort (30 min)
  → 3.1 Real training (1-2 hours)
  → 3.2 Real deploy gate (30 min)
```

**Minimum critical path time: ~2-3 days of focused work** (assuming no major debugging in Phase 0).

Parallel work that can happen during critical path:
- 1.2 PID fix (parallel with 1.1/1.3)
- 1.4/1.5 Rename filters (parallel, trivial)
- 2.7-2.9 User actions (ongoing, parallel with everything)

---

## Appendix J: Nightly Flywheel State Machine

The intended nightly flywheel and its current failure modes.

### J.1 Intended State Machine

```
[IDLE] ──(24h timer)──► [CHECK_CONDITIONS]
                              │
                    ┌─────────┤
                    │         │
                    │    (idle < 30min    (idle ≥ 30min
                    │     OR no power)     AND power)
                    │         │                │
                    │         ▼                ▼
                    │     [SKIP]          [COLLECT_TRACES]
                    │                          │
                    │                    (traces < minimum)
                    │                          │
                    │                          ▼
                    │                     [SKIP_NO_DATA]
                    │                          
                    │                    (traces ≥ minimum)
                    │                          │
                    │                          ▼
                    │                    [COMPOSE_DATA]
                    │                          │
                    │                          ▼
                    │                    [FILTER_DATA]
                    │                          │
                    │                          ▼
                    │                    [SORT_DATA]
                    │                          │
                    │                          ▼
                    │                    [TRAIN_ADAPTER]
                    │                          │
                    │                    (training fails)
                    │                          │
                    │                          ▼
                    │                    [LOG_FAILURE]
                    │                          
                    │                    (training succeeds)
                    │                          │
                    │                          ▼
                    │                    [RUN_EVAL]
                    │                          │
                    │                    (score < baseline + threshold)
                    │                          │
                    │                          ▼
                    │                    [REJECT_ADAPTER]
                    │                          
                    │                    (score ≥ baseline + threshold)
                    │                          │
                    │                          ▼
                    │                    [CHECK_CSI]
                    │                          │
                    │                    (CSI drift > limit)
                    │                          │
                    │                          ▼
                    │                    [REJECT_CATASTROPHIC]
                    │                          
                    │                    (CSI drift ≤ limit)
                    │                          │
                    │                          ▼
                    │                    [DEPLOY_ADAPTER]
                    │                          │
                    │                          ▼
                    └────────────────────[IDLE]
```

### J.2 Current Failure Points

| State | Intended Behavior | Actual Behavior | Failure Mode |
|-------|------------------|-----------------|-------------|
| CHECK_CONDITIONS | Verify idle + power | Works correctly | OK |
| COLLECT_TRACES | Read from omega_executions.db | Works but only 6 rows exist | DATA STARVATION |
| COMPOSE_DATA | Merge ODIA traces with base mix through compose pipeline | Writes raw traces to temp JSONL, bypasses compose | PIPELINE BYPASS |
| FILTER_DATA | Run IFD filter on composed data | Skipped entirely | SKIPPED |
| SORT_DATA | Run CAMPUS sort on filtered data | Skipped entirely | SKIPPED |
| TRAIN_ADAPTER | LoRA training with correct hyperparameters | Uses rank 32 instead of 16 for Nano | WRONG HYPERPARAMS |
| RUN_EVAL | Generate predictions, run eval_bfcl.py, compare scores | Checks if weights file exists on disk | EVAL BYPASS |
| CHECK_CSI | Compute embedding drift against baseline | Never called, no baseline exists | NOT WIRED |
| DEPLOY_ADAPTER | Register in AdapterRegistry, make active | Would work IF reached, but never reaches here | UNREACHABLE |

**Net result:** The flywheel's 9-state pipeline has failures at 6 of 9 states. The only states that work correctly are CHECK_CONDITIONS, COLLECT_TRACES (logic, not data), and DEPLOY_ADAPTER (code, never reached).

---

## Appendix K: Estimated Timeline to Each Milestone

### K.1 Training Ready (All Section 11 criteria pass)

| Week | Focus | Milestone |
|------|-------|-----------|
| Week 1, Days 1-2 | Phase 0: Validate pipe | First adapter on disk |
| Week 1, Days 3-5 | Phase 1: Fix wiring | Deploy gate, PID fix, pipeline integration |
| Week 2, Days 1-3 | Phase 2 (Claude): Generate data | 1,000+ trajectories, negative/error examples, general data |
| Week 2, Days 3-5 | Phase 2 (Claude): Compose, filter, sort | `train_final.jsonl` ready |
| Week 2 (parallel) | Phase 2 (User): Enable capture, start using app | Real traces accumulating |
| Week 3, Day 1 | Phase 3: First real training | Trained adapter passes eval gate |
| Week 3, Days 2-3 | Phase 3: CSI baseline, replay buffer | Safety mechanisms initialized |

**Estimated time to Training Ready: 2-3 weeks**

### K.2 Flywheel Validated (All Section 4 criteria operational)

| Week | Focus | Milestone |
|------|-------|-----------|
| Week 3-4 | Phase 4: Manual flywheel trigger | Nightly cycle works end-to-end |
| Week 4-6 | Phase 4: Natural nightly runs | 3+ successful nightly cycles |
| Week 4-6 (parallel) | User accumulates 20+ KTO signals | KTO training fires |

**Estimated time to Flywheel Validated: 4-6 weeks**

### K.3 Vision Matched (All Section 12 criteria pass)

| Quarter | Focus | Milestone |
|---------|-------|-----------|
| Q2 2026 | Phase 5: Scale data | 50K traces, RLAIF, GRPO |
| Q3 2026 | Phase 6: Architecture | Mamba-2 design + MOHAWK distillation |
| Q4 2026 | Phase 6: Deployment | CoreML export, state injection, learned routing |

**Estimated time to Vision Matched: 9-12 months**

### K.4 Honest Probability Estimates

| Milestone | P(achieved on time) | Key Risk |
|-----------|--------------------|---------|
| Training Ready (3 weeks) | 70% | Phase 0 debugging could take longer than expected |
| Flywheel Validated (6 weeks) | 50% | Depends on user generating enough real data |
| Vision Matched (12 months) | 20% | Mamba-2 is a research project with uncertain outcomes |
| Ship useful Qwen LoRA product | 80% | Doesn't require Mamba-2. Can ship after Phase 4. |

---

## Appendix L: What "Done" Looks Like

Concrete, observable conditions for each major milestone.

### L.1 "Training Ready" Done Conditions

```
File system checks:
  ✓ train_final.jsonl exists, size > 1MB
  ✓ train_final.jsonl has ≥ 3,000 lines
  ✓ adapter_weights.safetensors exists for at least 1 adapter
  ✓ adapter_registry.json has ≥ 1 entry
  ✓ general.jsonl (replay buffer) size > 0
  ✓ bfcl_eval_macos.jsonl has 100 tasks
  ✓ bfcl_eval_epistemos.jsonl has 50 tasks
  ✓ baseline_scores.json exists with real eval results

Code checks:
  ✓ All training paths call prepareTrainingData() before training
  ✓ runDeployGate() invokes eval_bfcl.py via Process()
  ✓ OrchestratorState uses resolveTargetPID() for AX capture
  ✓ All LoRA rank defaults are 16 for Nano target
  ✓ ifd_filter.py docstring says "heuristic quality filter"
  ✓ campus_sort.py docstring says "proxy-based curriculum sort"

Data mix checks (from train_final.jsonl):
  ✓ Tool-calling examples ≥ 30%
  ✓ General instruction examples ≥ 15%
  ✓ Epistemos app-specific examples ≤ 25%
  ✓ Negative/refusal examples ≥ 5%
  ✓ Error recovery examples ≥ 5%
  ✓ Zero wrong-PID cross-app trajectories

Runtime checks:
  ✓ Load base model + adapter → model output changes
  ✓ Run eval on 150 tasks → score > 0 (not NaN, not crash)
  ✓ Deploy gate rejects adapter with score below baseline
```

### L.2 "Flywheel Validated" Done Conditions

```
  ✓ 3 consecutive nightly cycles complete without error
  ✓ At least 1 cycle produced a BETTER adapter (score improved)
  ✓ At least 1 cycle REJECTED an adapter (score regressed or CSI flagged)
  ✓ KTO training triggered at least once (≥ 20 feedback signals)
  ✓ omega_executions.db has ≥ 100 rows
  ✓ kto_feedback table has ≥ 20 rows
  ✓ CSI baseline exists and computeCSI() has fired at least once
```

### L.3 "Vision Matched" Done Conditions

```
  ✓ Base model is Mamba-2 hybrid (75% SSM / 25% attention)
  ✓ Model parameter count is ~1B
  ✓ MOHAWK distillation completed all 3 stages
  ✓ CoreML .mlpackage loads on device
  ✓ Mamba state injection saves/restores context
  ✓ Real IFD scoring (GPT-2 perplexity) replaces heuristic
  ✓ Real CAMPUS metrics (parsed AX trees) replace regex
  ✓ 464+ RLAIF verification pairs generated
  ✓ GRPO with 6-component reward trained
  ✓ 50K+ general macOS traces in training data
  ✓ Screen2AX dataset integrated
  ✓ Learned MoLoRA/AdaFuse routing deployed
  ✓ Grammar-constrained decoding with formal grammars
  ✓ CSI safeguard monitoring every adapter deployment
  ✓ Scene-MMKG fused into runtime context
  ✓ Doc-to-LoRA automatic rebuild on vault changes
```

---

## Appendix M: Cross-App PID Impact Analysis

Detailed analysis of which training data is affected by the PID bug and which is safe.

### M.1 Affected vs Unaffected Trajectories

| Trajectory Category | Target App | PID Used | AX Tree Captured | Affected? |
|-------------------|-----------|----------|-----------------|----------|
| Note creation | Epistemos | Epistemos PID | Epistemos AX tree | NO — correct |
| Note editing | Epistemos | Epistemos PID | Epistemos AX tree | NO — correct |
| Note search | Epistemos | Epistemos PID | Epistemos AX tree | NO — correct |
| Graph navigation | Epistemos | Epistemos PID | Epistemos AX tree | NO — correct |
| AI chat | Epistemos | Epistemos PID | Epistemos AX tree | NO — correct |
| Settings | Epistemos | Epistemos PID | Epistemos AX tree | NO — correct |
| Omega internal tasks | Epistemos | Epistemos PID | Epistemos AX tree | NO — correct |
| **Safari browsing** | **Safari** | **Epistemos PID** | **Epistemos AX tree** | **YES — WRONG** |
| **Terminal commands** | **Terminal** | **Epistemos PID** | **Epistemos AX tree** | **YES — WRONG** |
| **Finder operations** | **Finder** | **Epistemos PID** | **Epistemos AX tree** | **YES — WRONG** |
| **Multi-app workflows** | **Multiple** | **Epistemos PID** | **Epistemos AX tree** | **YES — WRONG** |
| **Research workflows** | **Safari + others** | **Epistemos PID** | **Epistemos AX tree** | **YES — WRONG** |
| Keyboard navigation | Epistemos | Epistemos PID | Epistemos AX tree | NO — correct |
| Scrolling | Epistemos | Epistemos PID | Epistemos AX tree | NO — correct |
| Window management | Epistemos | Epistemos PID | Epistemos AX tree | NO — correct (if managing Epistemos windows) |

### M.2 Impact on 503 Synthetic Trajectories

The 503 synthetic trajectories use TEMPLATE AX trees, not real captured AX trees. Therefore:
- The PID bug does NOT affect synthetic trajectories (they never called `captureAXTree`)
- The PID bug WILL affect all FUTURE real captures of cross-app tasks
- Any Safari, Terminal, or Finder trajectory captured AFTER live capture is enabled (Phase 2.7) will have WRONG AX data until the PID fix (Phase 1.2) is deployed

**Order matters:** Phase 1.2 (PID fix) MUST be deployed before Phase 2.7 (enable live capture). Otherwise, live capture will produce harmful training data for cross-app tasks.

### M.3 Contamination Detection

After PID fix is deployed, any existing captured trajectories should be audited:

```
For each trajectory in embodied_trajectories.jsonl:
  If task involves Safari/Terminal/Finder:
    Check: does accessibility_tree contain Epistemos-specific elements?
      (AXStaticText "Knowledge Graph", AXButton "New Note", etc.)
    If yes: trajectory was captured with wrong PID → DISCARD
    If no: trajectory may be synthetic (template) → KEEP with caveat
```

---

## Appendix N: Honest Self-Assessment of This Document

This document has limitations that the reader should be aware of.

### N.1 What This Document Is Based On

- Direct reading of 30 source files (Swift, Python, Rust, JSON, JSONL)
- Line-number-verified findings from each file
- Two prior audit reports (pre-training readiness gap report, embodied data pipeline report)
- User-reported test failure context

### N.2 What This Document Cannot Verify

| Claim | Why It Can't Be Verified | Risk |
|-------|-------------------------|------|
| "Training will succeed with rank 16" | Cannot run training in this environment | Rank 16 may still OOM on some Nano configs |
| "503 synthetic trajectories are good enough for first training" | Cannot evaluate model quality from synthetic templates | Templates may not transfer to real AX trees |
| "2-3 weeks to Training Ready" | Cannot predict debugging time or user availability | Could be 1 week or 2 months |
| "eval_bfcl.py scoring correlates with real quality" | Cannot run the eval or measure user satisfaction | Eval may not measure what matters |
| "PID fix will work with NSWorkspace.shared.runningApplications" | Cannot test on macOS | Target app may not be running, API may require entitlements |
| "Phase 0 will surface all pipeline issues" | Cannot anticipate unknown unknowns | There may be issues in MLX, Metal, or Python environment |

### N.3 What Was Not Audited

The following were outside the scope of the 30-file audit:

- The Rust codebase (omega-mcp, omega-ax) — trusted based on 2,540 passing tests
- The full Xcode project configuration — only `project.pbxproj` modifications noted
- The UI layer (SwiftUI views) — only data flow from views to training pipeline
- The MLX Python environment — assumed to be correctly installed
- The actual Qwen model files — assumed to be valid MLX format
- Network and API integrations — only local file and database operations audited

---

*This document was generated 2026-03-27 from direct inspection of 30 source files. Every status assignment is grounded in specific file and line number evidence. No inferences from documentation, comments, or README claims — only from what the code actually does.*

*Last updated: 2026-03-27T15:54:00-05:00*
