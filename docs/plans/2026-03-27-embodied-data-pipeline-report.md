# Embodied Data Pipeline — Build Report

**Date:** 2026-03-27
**Purpose:** First real embodied data pipeline for Epistemos-Nano training
**Status:** Pipeline built and wired. 503 trajectories + 150 eval tasks on disk. Live capture integrated into OrchestratorState.

---

## What Was Built

### 1. Swift Live AX Capture Service

**File:** `Epistemos/KnowledgeFusion/SyntheticData/EmbodiedCaptureService.swift`

A `@MainActor` service that wraps `omega-ax` for live embodied data capture during Omega agent execution:

- **`captureAXTree(pid:)`** — calls `walkAxTreeJson()` from omega-ax, returns `AXTreeSnapshotData` with interactive element count and sparse detection
- **`captureScreenshot(label:)`** — captures PNG via `/usr/sbin/screencapture` to `~/Library/Application Support/Epistemos/embodied-data/screenshots/`
- **`captureSnapshot(pid:, label:)`** — atomic AX tree + screenshot capture
- **`buildTrajectoryStep(...)`** — assembles a single step from pre/post snapshots with computed AX diff
- **`buildTrajectory(...)`** — assembles a multi-step trajectory with quality scoring
- **`persistTrajectory(...)`** — appends JSONL to `embodied_trajectories.jsonl`
- **`executeWithCapture(agent:step:pid:taskDescription:)`** — drop-in wrapper for `OrchestratorState.executePlan()` that captures pre/post AX trees around every agent step, with 150ms post-action settling delay per training guide

**AX Diff:** Computes structural delta between pre/post trees using role+title+description signatures. Reports added/removed element counts and lists.

**Integration point:** `OrchestratorState.executePlan()` can replace its inner `agent.execute(step:)` call with `captureService.executeWithCapture(...)` to generate embodied training data from every real Omega execution.

### 2. Python Embodied Trajectory Generator

**File:** `Epistemos/KnowledgeFusion/MOHAWK/generate_embodied_trajectories.py`

Generates structured embodied trajectories grounded in real Epistemos UI:

- **24 trajectory categories** covering: note creation, search, graph navigation, AI chat operations, Omega tasks, settings, Safari research, file operations, note editing, error recovery, cross-app workflows, research workflows, keyboard navigation, scrolling, negative/refusal, multi-tab, vault sync, AX verification loops, complex multi-step workflows, discard/undo, direct tool calls, window management
- **Realistic AX tree templates** matching the `omega-ax` `AXTreeSnapshot` schema (role, title, value, description, position, size, is_interactive, children_count, parent_index)
- **Full embodied schema per step:**
  - `accessibility_tree` — pre-action AX tree JSON
  - `screenshot` — pre-action screenshot path
  - `reasoning_chain` — `<think>` tagged reasoning
  - `action` — structured `{toolName, argumentsJson, agentName}`
  - `result_accessibility_tree` — post-action AX tree JSON
  - `result_screenshot` — post-action screenshot path
  - `ax_diff` — structural delta (added/removed elements)
- **Dual output:** raw embodied JSONL + SFT chat-format JSONL for direct training
- **[OBSERVE]->[REASON]->[ACT]->[RESULT]->[DONE]** format in SFT output

### 3. 503 Embodied Trajectories (10.7 MB)

**Location:** `Epistemos/KnowledgeFusion/MOHAWK/embodied_data/`

| File | Lines | Description |
|------|-------|-------------|
| `embodied_trajectories.jsonl` | 503 | Raw embodied format with full AX trees (10.7 MB) |
| `embodied_trajectories_sft.jsonl` | 503 | Chat SFT format for training (0.6 MB) |
| `generation_report.json` | 1 | Generation statistics |

**Statistics:**
- 503 trajectories, 1,225 total steps
- Average 2.4 steps per trajectory
- 39 categories, 6 task types
- Task type distribution: app_specific 256, general 71, research 71, tool_call 54, error_recovery 27, negative 24

**Schema validation:** All 503 trajectories pass full schema validation — zero violations, every step has all 8 required fields, all AX trees parse as valid JSON with `elements` arrays.

### 3b. Live Capture Wired into OrchestratorState

`EmbodiedCaptureService` is now integrated into `OrchestratorState.executePlan()`:
- Pre-action AX snapshot captured before every agent step (gated by `omega.embodiedCapture` UserDefault)
- 150ms post-action settling delay per training guide
- Post-action AX snapshot + diff computed
- Trajectory steps accumulated during task execution
- Full trajectory persisted to JSONL after task completion
- Cleanup on cancel/reset

### 3c. BFCL Evaluation Runner

**File:** `Epistemos/KnowledgeFusion/MOHAWK/eval_bfcl.py`

Scoring system with 4 dimensions:
- **Tool Match (40%):** exact tool name match, 0.5 partial credit for tool family
- **Args Match (30%):** subset matching with case-insensitive and substring partial credit
- **Sequence Match (20%):** LCS-based ordering score for multi-step tasks
- **Refusal Match (10%):** correct refusal for unsafe/out-of-scope tasks

Features:
- Deploy gate: `new_score > baseline + 0.5%` (configurable threshold)
- Category and difficulty breakdowns
- Baseline auto-save on first pass
- Template generation mode for model prediction collection

### 4. BFCL-Style Evaluation Task Sets

**Location:** `Epistemos/KnowledgeFusion/MOHAWK/embodied_data/`

| File | Tasks | Description |
|------|-------|-------------|
| `bfcl_eval_macos.jsonl` | 100 | Standard macOS tasks |
| `bfcl_eval_epistemos.jsonl` | 50 | Epistemos-specific tasks |

**macOS eval categories (100 tasks):**
- app_launch (5), click (5), type_text (3), keyboard (7), navigation (5), file_ops (5), scroll (5), multi_step (5), menu (5), form (5), text_edit (5), shortcut (5), drag_drop (2), accessibility (5), web (5), compound (8), window (5), error_recovery (5), refusal (5), multi_app (5)

**Epistemos eval categories (50 tasks):**
- note_create (3), note_search (3), note_edit (3), ai_chat (5), graph (5), omega (5), settings (5), navigation (5), complex (5), error (5), refusal (3), verify (3)

**Each eval task has:**
- `id` — unique identifier
- `category` — task category
- `instruction` — natural language instruction
- `expected_action` — ground truth tool call(s)
- `verification` — how to check success (AX tree state, file existence, etc.)
- `difficulty` — easy/medium/hard

---

## Files Created

| File | Purpose |
|------|---------|
| `Epistemos/KnowledgeFusion/SyntheticData/EmbodiedCaptureService.swift` | Live AX capture + screenshot + diff service |
| `Epistemos/KnowledgeFusion/MOHAWK/generate_embodied_trajectories.py` | Trajectory generator (39 categories, 503 trajectories) |
| `Epistemos/KnowledgeFusion/MOHAWK/eval_bfcl.py` | BFCL eval runner with deploy gate |
| `Epistemos/KnowledgeFusion/MOHAWK/embodied_data/embodied_trajectories.jsonl` | 503 raw embodied trajectories (10.7 MB) |
| `Epistemos/KnowledgeFusion/MOHAWK/embodied_data/embodied_trajectories_sft.jsonl` | 503 SFT chat-format trajectories (0.6 MB) |
| `Epistemos/KnowledgeFusion/MOHAWK/embodied_data/generation_report.json` | Generation statistics |
| `Epistemos/KnowledgeFusion/MOHAWK/embodied_data/bfcl_eval_macos.jsonl` | 100 macOS eval tasks |
| `Epistemos/KnowledgeFusion/MOHAWK/embodied_data/bfcl_eval_epistemos.jsonl` | 50 Epistemos eval tasks |
| `Epistemos/KnowledgeFusion/MOHAWK/embodied_data/predictions_template.jsonl` | Blank predictions template for eval |
| `Epistemos/Omega/Orchestrator/OrchestratorState.swift` | Modified: wired embodied capture into executePlan() |
| `Epistemos.xcodeproj/project.pbxproj` | Modified: added EmbodiedCaptureService to build |
| `docs/plans/2026-03-27-embodied-data-pipeline-report.md` | This report |

---

## How to Generate More Data

### Synthetic (immediate — no permissions needed)

```bash
# Generate all trajectories (currently 105)
cd Epistemos/KnowledgeFusion/MOHAWK
python3 generate_embodied_trajectories.py

# To add more, add generator functions in the script following the pattern:
# def gen_<category>_trajectories():
#     return [_trajectory(task_desc, [_step(...)], task_type)]
# Then add ("category_name", gen_<category>_trajectories) to the generators list.
```

### Live capture (requires running Epistemos with accessibility permission)

1. Grant Epistemos accessibility permission in System Settings > Privacy > Accessibility
2. Wire `EmbodiedCaptureService` into `OrchestratorState.executePlan()`:
   ```swift
   // In executePlan(), replace:
   let result = try await agent.execute(step: enrichedStep)
   // With:
   let (result, trajectoryStep) = try await captureService.executeWithCapture(
       agent: agent, step: enrichedStep,
       pid: getEpistemosPid(), taskDescription: currentTaskDescription
   )
   ```
3. Every Omega task execution will now produce embodied training data in `~/Library/Application Support/Epistemos/embodied-data/`

### Scaling to 1,000+ trajectories

- **Option A: Expand the generator.** Each new category function adds 3-14 trajectories. Adding 15 more categories gets to 200+. Adding variant loops within categories (different note titles, different search queries) can reach 1,000.
- **Option B: Claude Sonnet generation.** Use the AX tree templates as grounding context and have Sonnet generate diverse trajectories. Budget: ~$550 for 1,000 at $0.55/trajectory.
- **Option C: Live capture accumulation.** Every real Omega execution produces 1 trajectory per task. After 100 real uses, you have 100 real trajectories.

---

## What Still Blocks First Serious Nano Training

### Resolved by this work

- [x] Embodied action schema defined and implemented
- [x] 503 trajectories with `accessibility_tree`, `screenshot`, `reasoning_chain`, `action` fields
- [x] Pre/post AX tree diffs computed
- [x] BFCL-format evaluation holdouts exist (100 macOS + 50 Epistemos)
- [x] BFCL eval runner with deploy gate, category/difficulty scoring
- [x] SFT chat format conversion for direct training
- [x] Live capture service wired into OrchestratorState.executePlan()
- [x] EmbodiedCaptureService added to Xcode build target
- [x] BUILD SUCCEEDED with all changes

### Still blocking

| Blocker | Status | What's needed |
|---------|--------|---------------|
| **Scale: 503 trajectories, ideally 1,000+** | Mostly addressed | Expand generator or use Claude Sonnet for final 500 |
| **Data mix still imbalanced** | Not addressed | Recompose at 40% tool-call / 20% general / 20% app-specific / 10% negative / 10% error-recovery |
| **50K general macOS traces** | Not addressed | Download Screen2AX + AgentTrek, or Evol-Instruct evolution |
| **IFD superfiltering** | Not addressed | GPT-2 perplexity scorer, keep top 15% |
| **CAMPUS curriculum sort** | Not addressed | Sort on tree_depth, selector_ambiguity, chain_length, IFD |
| **AST-based code graph** | Not addressed | Swift AST parse → `app_code_graph.json` with real node/edge types |
| **Xcode symbol graph extraction** | Not addressed | `xcodebuild -symbolGraph` → forward+reverse QA pairs |
| **Zero successful training runs** | Not addressed | Need one `adapter_weights.safetensors` on disk |
| **KTO feedback signals** | Not addressed | Need 20+ real accept/discard signals in `kto_feedback` table |
| **Real ODIA execution traces** | Not addressed | Need 100+ real traces in `omega_executions.db` |
| **Live AX capture wiring** | DONE | Wired into `OrchestratorState.executePlan()`, gated by `omega.embodiedCapture` UserDefault |

### Recommended next steps (in order)

1. **Wire `EmbodiedCaptureService` into `OrchestratorState.executePlan()`** — start accumulating real embodied data from every Omega task
2. **Scale synthetic trajectories to 500+** by expanding the generator with more variants
3. **Rebalance data mix** by composing the existing 3,192 chat-style examples + 105 embodied examples at the correct ratios
4. **Run one sanity-check LoRA training** on the embodied SFT data to verify the pipeline end-to-end
5. **Build the BFCL eval runner** that executes the 150 eval tasks and measures pass rate
6. **Collect real KTO feedback** by using the app's note editor accept/discard flow
7. **Then, and only then, start serious Nano SFT**

---

*This report describes artifacts created 2026-03-27. All file paths are relative to the Epistemos project root.*
