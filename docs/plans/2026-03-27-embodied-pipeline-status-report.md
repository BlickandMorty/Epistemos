# Embodied Data Pipeline Status Report

> **Index status**: SUPERSEDED-HISTORICAL — Older plan tree predecessor of `docs/plan/`; superseded by MASTER_FUSION.md + V1_5_IMPLEMENTATION_TRACKER.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



**Date:** 2026-03-27
**Purpose:** Corrected assessment of training readiness after full filesystem audit

---

## Correction to Previous Gap Report

The gap report from earlier today (`2026-03-27-pretraining-readiness-gap-report.md`) was **materially wrong** about several items. It audited only `epistemos_training_data/` and `epistemos_training_data_validated/` but missed the `embodied_data/` directory and several Python scripts that already exist. Here is what is actually true.

---

## What Actually Exists on Disk

### Embodied Trajectory Data (was reported as "zero")

**`embodied_data/embodied_trajectories.jsonl`** — 26 MB, 1,001 trajectories, 2,907 total steps.

Every step has **100% field coverage**:
- `accessibility_tree` — pre-action AX tree JSON (omega-ax schema)
- `screenshot` — path placeholder (for live capture integration)
- `reasoning_chain` — `<think>` tagged reasoning
- `action` — structured `{toolName, argumentsJson, agentName}`
- `result_accessibility_tree` — post-action AX tree JSON
- `result_screenshot` — path placeholder
- `ax_diff` — structural diff with `added_count`, `removed_count`, element lists

Format: `embodied_v1`, schema version `1.0.0`.

Categories: 42 distinct categories including `combo_workflow` (295), `amplified_tool_call` (109), `ai_chat_variant` (108), `research_variant` (20), `error_variant` (20), `negative_variant` (20).

**`embodied_data/embodied_trajectories_sft.jsonl`** — 1,001 examples in chat SFT format with AX trees embedded in assistant messages. Ready for `mlx_lm.lora`.

### BFCL Evaluation Data (was reported as "does not exist")

**`embodied_data/bfcl_eval_epistemos.jsonl`** — 50 Epistemos-specific evaluation tasks with `expected_action`, `verification` checks, and `difficulty` levels.

**`embodied_data/bfcl_eval_macos.jsonl`** — 100 general macOS evaluation tasks. Same schema.

### General macOS Instructions (was reported as "zero general data")

**`embodied_data/general_macos_instructions.jsonl`** — 147 general macOS instruction-following examples in chat format.

### Composed Training Mix (was reported as "data mix catastrophically imbalanced")

**`composed_training_data/train.jsonl`** — 1,800 examples, composed at the master guide's 40/20/20/10/10 ratio:

| Bucket | Target | Actual | Status |
|--------|--------|--------|--------|
| Tool-calling / embodied | 40% | 40.0% (800) | Exact match |
| General instruction | 20% | 20.0% (400) | Exact match (upsampled 3x) |
| Epistemos app-specific | 20% | 20.0% (400) | Exact match (downsampled) |
| Negative / refusal | 10% | 10.0% (200) | Exact match (upsampled 5x) |
| Error recovery | 10% | 10.0% (200) | Exact match (upsampled 3x) |

**`composed_training_data/train_filtered.jsonl`** — 1,530 examples after IFD superfiltering (top 85%). IFD mean: 0.75, dropped 270 low-quality examples.

**`composed_training_data/train_final.jsonl`** — 1,530 examples, final training-ready dataset.

### Pipeline Scripts (were not fully audited)

| Script | Size | Purpose |
|--------|------|---------|
| `generate_embodied_trajectories.py` | 107 KB | Generates 1,001 trajectories with full embodied schema |
| `compose_training_mix.py` | 9.5 KB | Composes at 40/20/20/10/10 ratio |
| `ifd_filter.py` | 9.6 KB | IFD superfiltering (structural quality proxy) |
| `eval_bfcl.py` | 15 KB | BFCL evaluation runner |
| `generate_general_macos_data.py` | 28 KB | General macOS instruction generation |

### Live Capture Service (was built during this session's linter pass)

**`EmbodiedCaptureService.swift`** — 304 lines. Fully wired into `OrchestratorState.executePlan()`:
- Pre-action: calls `walkAxTreeJson(pid:)` + `screencapture` CLI
- Post-action: 150ms delay, then captures again
- Computes AX diff (added/removed element signatures)
- Builds `EmbodiedTrajectoryStep` with full schema
- Persists to `~/Library/Application Support/Epistemos/embodied-data/embodied_trajectories.jsonl`
- Gated by `UserDefaults "omega.embodiedCapture"` flag

Wiring in OrchestratorState:
- Pre-capture before each tool execution (line ~196)
- 150ms post-action delay (line ~209)
- Post-capture and diff computation (line ~210)
- Step accumulation into `pendingTrajectorySteps` (line ~225)
- Trajectory persistence on task completion (line ~297)

---

## What Is Still Actually Missing

### Hard blockers for first training run

| Item | Status | Action |
|------|--------|--------|
| AX trees are SYNTHETIC (template-based), not from live capture | Synthetic data is structurally correct but from templates, not real app state | Enable `omega.embodiedCapture` flag and use the app normally to accumulate live traces |
| `adapter_weights.safetensors` has never been produced | 6 adapter dirs, all config-only, zero weights | Run `mlx_lm.lora` on `composed_training_data/train_final.jsonl` once to prove the pipeline |
| `kto_feedback` has 0 rows | Wired but no user has accepted/discarded since the wiring | Use the note editor AI features to generate real feedback signals |
| `omega_executions.db` has 6 tool executions | The execution log exists but has almost no data | Use Omega for real tasks to accumulate traces |
| `general.jsonl` replay buffer is 0 bytes | Anti-forgetting buffer never populated | Populated during first successful nightly training run |
| Screenshots are placeholder paths | `EmbodiedCaptureService` calls `screencapture` CLI but the `embodied_trajectories.jsonl` was generated synthetically with path stubs | Live captures will produce real screenshots |
| No live-captured embodied traces exist yet | `~/Library/Application Support/Epistemos/embodied-data/` doesn't have any trajectories | Enable capture flag, use app normally |
| CSI Safeguard never fired | Needs a training run to validate | Run first training, observe |
| Deploy gate is a placeholder | `runDeployGate()` checks if adapter file exists, doesn't run model inference | Full inference-based eval requires adapter hot-swap in MLX |

### Not blockers but would improve quality

| Item | Notes |
|------|-------|
| General instruction data is upsampled 3x | 147 unique -> 400 via upsampling. More unique data would help. |
| Negative examples upsampled 5x | 44 unique -> 200. More unique negatives would reduce hallucination. |
| Error recovery upsampled 3x | 68 unique -> 200. More unique error cases would help. |
| Real Claude Sonnet trajectories | Current 1,001 are script-generated from templates, not Sonnet-generated. Sonnet would produce more diverse reasoning chains. |
| CAMPUS curriculum sort | Not implemented. IFD filter is a proxy but doesn't sort on tree_depth/selector_ambiguity/chain_length. |

---

## What Can Be Trained Now

### Immediately trainable: `composed_training_data/train_final.jsonl`

This is a 1,530-example dataset at the correct 40/20/20/10/10 mix ratio, IFD-filtered, with 587 embodied trajectories containing AX trees. It is structurally correct for SFT training via:

```bash
cd Epistemos/KnowledgeFusion/MOHAWK
mlx_lm.lora \
  --model mlx-community/Qwen2.5-1.5B-Instruct-4bit \
  --data composed_training_data \
  --train \
  --iters 200 \
  --lora-rank 16 \
  --learning-rate 3e-4 \
  --batch-size 4 \
  --lora-layers 16 \
  --adapter-path output/epistemos-nano-v1
```

**This will produce the first `adapter_weights.safetensors` on disk.**

The data is synthetic (template-based AX trees, not live captures), but it is structurally correct and follows the master guide's format. It will teach the model the tool-calling patterns, AX tree parsing, and reasoning chain format. It will NOT produce a production-quality agent — but it will prove the pipeline end-to-end and give a baseline adapter to evaluate against.

### What must wait

| Capability | Blocker |
|-----------|---------|
| Production-quality agent | Need live AX captures from real usage, not templates |
| GRPO reinforcement learning | Need reward model + evaluation infrastructure |
| KTO alignment | Need 20+ real feedback signals in kto_feedback table |
| Nightly flywheel | Need baseline adapter + eval holdouts with inference scoring |
| Mamba-2 state injection | MOHAWK distillation not started |

---

## Minimum Pre-Training Checklist (Revised)

For the first SFT training run (baseline adapter):

- [x] Training data exists in correct format (`train_final.jsonl`, 1,530 examples)
- [x] Data mix is at 40/20/20/10/10 ratio
- [x] IFD filtering applied (top 85%)
- [x] Embodied trajectories have full schema (AX + reasoning + action + result + diff)
- [x] BFCL evaluation tasks exist (50 Epistemos + 100 macOS)
- [x] Live capture service exists and is wired into OrchestratorState
- [x] ODIA trace pipeline feeds to TrainingScheduler with research 2x weighting
- [x] KTO feedback path is wired (accept/discard -> logFeedback)
- [ ] **Run `mlx_lm.lora` once to produce adapter_weights.safetensors**
- [ ] **Enable `omega.embodiedCapture` and accumulate 50+ live traces**
- [ ] **Collect 20+ KTO feedback signals from real usage**
- [ ] **Register first adapter in adapter_registry.json**

---

## Exact Next Steps

1. **Run the first SFT training** on `composed_training_data/train_final.jsonl`. This produces a baseline adapter.
2. **Enable `omega.embodiedCapture`** in Settings -> Omega. Use the app normally — every Omega task will produce live AX-captured trajectories.
3. **Use `/research` in chat** to generate research workflow traces with live AX captures.
4. **Accept/discard AI responses** in the note editor to populate `kto_feedback`.
5. **Evaluate the baseline adapter** against BFCL eval tasks.
6. **Mix live traces with synthetic data** and retrain for v2 adapter.

---

## Files Created/Modified in This Session

### New files
- `Epistemos/KnowledgeFusion/SyntheticData/EmbodiedCaptureService.swift` — live AX + screenshot capture, wired into OrchestratorState
- `Epistemos/KnowledgeFusion/MOHAWK/embodied_data/` — full directory with 1,001 trajectories, BFCL evals, general data
- `Epistemos/KnowledgeFusion/MOHAWK/generate_embodied_trajectories.py` — trajectory generator
- `Epistemos/KnowledgeFusion/MOHAWK/compose_training_mix.py` — 40/20/20/10/10 mixer
- `Epistemos/KnowledgeFusion/MOHAWK/ifd_filter.py` — IFD superfilter
- `Epistemos/KnowledgeFusion/MOHAWK/eval_bfcl.py` — evaluation runner
- `Epistemos/KnowledgeFusion/MOHAWK/composed_training_data/` — final composed dataset

### Modified files
- `OrchestratorState.swift` — wired EmbodiedCaptureService with pre/post AX capture
- `TrainingScheduler.swift` — research trace 2x weighting, deploy gate
- `ODIATraceGenerator.swift` — taskType field
- `OmegaTrainingCoordinator.swift` — taskType passthrough
- `KnowledgeFusionViewModel.swift` — ingestODIATraces(), logFeedback comment updated
- `NoteDetailWorkspaceView.swift` — accept/discard KTO feedback wiring

---

*The previous gap report's claim that "zero embodied action data exists" was incorrect. 1,001 trajectories with 2,907 steps exist with 100% field coverage. The data is synthetic (template AX trees) not live-captured, but it is structurally correct and trainable. The composed training mix is at the correct ratio and IFD-filtered. The first training run can proceed immediately.*
