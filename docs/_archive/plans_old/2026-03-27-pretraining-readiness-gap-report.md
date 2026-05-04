# Pre-Training Readiness Gap Report

> **Index status**: SUPERSEDED-HISTORICAL — Older plan tree predecessor of `docs/plan/`; superseded by MASTER_FUSION.md + V1_5_IMPLEMENTATION_TRACKER.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



**Date:** 2026-03-27
**Auditor:** Claude Opus 4.6 against NANO-MASTER-TRAINING-GUIDE.md Sections 3-8
**Verdict:** NOT READY for serious training. Significant structural gaps remain.

---

## Ready Now

These are genuinely complete and usable today.

| Item | Evidence | Notes |
|------|----------|-------|
| Chat-style SFT data exists | `train.jsonl`: 3,772 examples (original), 3,192 (validated) | Layers 1-7 + gap fills |
| Symbol QA layer is large | 3,070 examples (2,425 validated) | Dominates the mix at ~68% |
| Code Graph layer exists | 557 examples | Covers codebase structure |
| Tool call examples exist | 144 examples | AXPress format, covers 50+ tools |
| Negative examples have `<think>` tags | 20 examples with reasoning | Hammer-style refusals |
| Research workflow layer exists | 48 examples (generator) + 12 (gap filler) | New Layer 16, not yet generated to disk |
| Omega tool registry has 26 tools | 19 original + 7 research | All registered with JSON schemas |
| Research orchestration is wired | OrchestratorState -> TaskGraph -> agents -> MCPBridge | Escalation gates synthesis step |
| ODIA trace pipeline is wired | OrchestratorState -> OmegaTrainingCoordinator -> KnowledgeFusionViewModel -> TrainingScheduler | taskType "research" gets 2x weight |
| KTO feedback path is wired | NoteDetailWorkspaceView accept/discard -> logFeedback() -> kto_feedback table | Table exists, schema correct |
| AdapterRegistry code is complete | actor with CRUD, atomic writes, MoLoRA config export | Never-fuse-into-base rule respected |
| Training scheduler infrastructure exists | NSBackgroundActivityScheduler, 24h interval, idle/power checks | KTO + Vault + ODIA schedulers |
| Constrained decoding service exists | ConstrainedDecodingService + MLXConstrainedGenerator | Soft EOS only, not grammar-guided yet |
| Rust omega-mcp builds clean | 89 cargo tests pass, `tool_get_page_text` added | UniFFI bindings ready |
| Swift builds clean | 139 tests pass (ThemePair + OmegaAgent + ResearchMode) | No regressions |

## Not Ready

These are required by the master guide but do not exist yet.

| Requirement | Master Guide Section | Current State | Gap |
|-------------|---------------------|---------------|-----|
| **`app_code_graph.json` from Swift AST parsing** | Pillar 2, Layer 0 (CGM) | Does NOT exist on disk. `01_code_graph.jsonl` has 557 chat-style QA pairs about code, but these are NOT the graph adjacency structure the guide requires. | Need actual AST parse -> node/edge graph with `calls`, `conformsTo`, `memberOf`, `UniFFI bridge` edge types. |
| **`app_atlas_differential.jsonl`** | Pillar 2, Layer 2 | Does NOT exist. `03_ax_atlas.jsonl` has 146 chat-style examples. Zero have `accessibility_tree`, `screenshot`, or pre/post diff fields. | Need live AX capture with 150ms post-action delay, structural diff, error states. |
| **`app_symbol_qa.jsonl` from Xcode symbol graph** | Pillar 2, Layer 1 | Does NOT exist as separate artifact. `02_symbol_qa.jsonl` was generated from regex parsing, not `xcodebuild -symbolGraph`. No cross-file resolution. | Need Xcode symbol graph extraction with forward+reverse mappings and cross-file context. |
| **1,000 multi-turn trajectories** | Pillar 2, Layer 3 | `04_trajectories.jsonl` has 43 examples. Format is chat-style, not `[OBSERVE]->[REASON]->[ACT]->[RESULT]->[DONE]`. | Missing 957 trajectories. Wrong format. No Claude Sonnet generation. |
| **464 RLAIF verification pairs** | Pillar 2, Layer 3 | Zero exist. | Complete blocker for RL stage. |
| **50K general macOS traces** | Section 3.4 | Zero real traces. 144 synthetic tool_call examples. | Need AgentTrek mining + Evol-Instruct evolution. |
| **Superfiltering (IFD scoring)** | Section 3.1, 5.1 | Not implemented. No GPT-2 IFD scorer. All data used as-is. | Top 15% filtering required before any training. |
| **CAMPUS curriculum sort** | Section 5.1 | Not implemented. | Sort on 4 axes: tree_depth, selector_ambiguity, chain_length, IFD. |
| **Data mix at 40/20/20/20 ratio** | Section 5.1 | Current mix is ~68% symbol_qa, ~13% code_graph, ~4% tool_call, ~3% ax_atlas. Violates every ratio. | Complete rebalance needed. |
| **BFCL holdout (100 standard macOS tasks)** | Section 5.1 | Does NOT exist. `eval.jsonl` has 420 examples but dominated by symbol_qa (309). Not BFCL-format. | Need 100 real macOS task evaluations. |
| **Epistemos holdout (50 app tasks)** | Section 5.1 | Does NOT exist as separate artifact. | Need 50 app-specific evaluation tasks. |
| **6-component decomposed reward** | Section 4.1 | Not implemented. GRPO code does not exist in the codebase. | Need reward model with format/element/action/parameter/state/completion components. |
| **Screen2AX dataset** | Section 3.4 | Not downloaded. Zero screenshot-based examples. | 1,127 images x 112 apps, one-time download. |
| **Real ODIA execution traces** | Section 5.1 | `omega_executions.db` has 6 rows total. Zero research tool calls. | Need hundreds of real execution traces before nightly loop produces useful adapters. |
| **KTO feedback signals** | Section 4.4 | `kto_feedback` table: 0 rows. Wiring done but no user has clicked accept/discard since. | Need minimum 20 signals for first KTO run (code enforces `guard count >= 20`). |
| **Adapter weights on disk** | Nightly flywheel | 6 adapter directories, all have `adapter_config.json` only. Zero have `adapter_weights.safetensors` or `training_metadata.json`. | No successful training run has ever completed. |
| **`general.jsonl` replay buffer** | Section 5.4 | File exists, size 0 bytes. | Anti-forgetting buffer is empty. |
| **CSI Safeguard active** | Section 5.4 | `CSISafeguard.swift` exists but has never fired (no training runs). | Needs at least one successful training cycle to validate. |

## Hard Blockers

These must be resolved before ANY training run produces useful results.

### 1. No embodied action data exists

Every JSONL file is chat-style `{"messages": [...]}`. The master guide requires embodied action format with:
- `accessibility_tree` (pre-action AX snapshot)
- `action` (structured tool call)
- `result_ax_tree` (post-action AX snapshot)
- `screenshot` (optional but referenced)
- `reasoning_chain` (explicit `<think>` reasoning before action)

**Current state:** 4,192 total examples. 0 have `accessibility_tree`. 0 have `screenshot`. 0 have `reasoning_chain` as a field (232 have `<think>` tags embedded in assistant messages, which is close but not the structured field the guide specifies). 0 have pre/post AX diffs.

**Impact:** Training on chat-style-only data produces a Q&A model, not an embodied agent. The model will learn to answer questions about the codebase but will NOT learn to execute multi-step UI workflows through AX trees.

### 2. Data mix is catastrophically imbalanced

| Required (Master Guide) | Actual (train.jsonl) |
|--------------------------|---------------------|
| 40% tool-calling | 3.5% (134/3,772) |
| 25% general instruction | 0% (none included) |
| 20% Epistemos app-specific | 96% (nearly everything is app-specific) |
| 10% negative | 0.5% (18) |
| 5% error recovery | 0.4% (15) |

Training on this mix will catastrophically overfit to Epistemos symbol QA and degrade on every other task. The 20% sacred boundary is violated in the opposite direction — it's ~96%.

### 3. Zero successful adapter training runs on disk

6 adapter directories exist. All contain only `adapter_config.json` (LoRA layer configuration). None contain:
- `adapter_weights.safetensors` (the actual trained weights)
- `training_metadata.json` (training hyperparameters, loss curves, example counts)

The nightly flywheel code is wired but has never produced output. The `adapter_registry.json` is `[]`.

### 4. No evaluation benchmarks exist

The master guide requires:
- BFCL holdout: 100 standard macOS tasks (does not exist)
- Epistemos holdout: 50 app tasks (does not exist)
- Both must improve or adapter is rejected

Without these, the canary deploy gate (`new_score > baseline + 0.5%`) cannot function. There is no way to measure whether training helped or hurt.

## Misleading Green Lights

Things that look ready but aren't actually usable for training.

| What Looks Green | Why It's Misleading |
|-------------------|---------------------|
| `train.jsonl` has 3,772 examples | 73% is symbol_qa (codebase Q&A). Not action data. Not the right format. Not filtered. |
| `03_ax_atlas.jsonl` has 146 examples | These are chat-style descriptions of UI elements, not actual AX tree snapshots with pre/post diffs. |
| `04_trajectories.jsonl` has 43 examples | Format is chat-style, not `[OBSERVE]->[REASON]->[ACT]->[RESULT]->[DONE]`. Need 1,000. Have 43. |
| Research Layer 16 function generates 48 examples | Not yet generated to disk. Also chat-style, not embodied action format. |
| `omega_executions.db` exists | Has 6 rows (2 click_element, 2 run_command, 1 list_files, 1 run_shortcut). Zero research tool calls. Not enough to constitute training data. |
| KTO feedback path is wired | 0 rows in kto_feedback. Needs minimum 20 to trigger first KTO run. |
| TrainingScheduler has nightly loop | Has never fired successfully. `shouldRunTraining()` requires 30 min idle + power conditions. Even if it fires, there's nothing to train on. |
| Adapter directories exist (6 of them) | All are empty shells from failed/incomplete runs. No weights, no metadata. |
| `fill_training_gaps.py` fills low categories | Fills to 25+ per category in chat-style. Does not address embodied action format gap or overall mix ratio. |
| Research 2x weighting in ODIA | Correct logic, but 0 research traces exist to weight. |

## Minimum Pre-Training Checklist

Every item must be GREEN before starting the first serious training run.

- [ ] **Generate `app_code_graph.json`** from actual Swift AST parsing (not regex). Node types: SwiftUI views, @Observable models, Rust structs, MCP tools. Edge types: calls, conformsTo, memberOf, UniFFI bridge.
- [ ] **Extract symbol graph** via `xcodebuild -symbolGraph`. Generate forward+reverse QA pairs with cross-file context. Output: `app_symbol_qa.jsonl`.
- [ ] **Capture live AX atlas** via macapptree. Pre-action tree -> execute action -> wait 150ms -> post-action tree -> compute diff. Include error states. Output: `app_atlas_differential.jsonl`.
- [ ] **Generate 1,000 multi-turn trajectories** via Claude Sonnet 4.5. Format: `[OBSERVE]->[REASON]->[ACT]->[RESULT]->[DONE]`. 3-8 steps each.
- [ ] **Download Screen2AX dataset** (1,127 images x 112 apps).
- [ ] **Generate 50K general macOS traces** via Evol-Instruct + AgentTrek mining.
- [ ] **Implement IFD superfiltering** (GPT-2 based). Keep top 15%.
- [ ] **Implement CAMPUS curriculum sort** on 4 axes.
- [ ] **Recompose data mix** at 40/20/20/10/10 ratio.
- [ ] **Create BFCL holdout** (100 standard macOS tasks).
- [ ] **Create Epistemos holdout** (50 app-specific tasks).
- [ ] **Run one successful local LoRA training** producing `adapter_weights.safetensors` on disk.
- [ ] **Populate `adapter_registry.json`** with at least one successful adapter.
- [ ] **Collect 20+ KTO feedback signals** from real usage (accept/discard in note editor).
- [ ] **Collect 100+ real ODIA execution traces** in `omega_executions.db`.
- [ ] **Generate Layer 16 research data to disk** (run `generate_epistemos_training_data.py --layer research`).

## Exact Next 10 Tasks

Ordered by dependency chain. Cannot skip or parallelize across groups.

### Group A: Data format (must happen first)

**1. Build the AST-based Code Graph Model generator.**
Parse Swift ASTs from `Epistemos/` into `app_code_graph.json` with proper node/edge types. This is Layer 0 and everything else stacks on it. Currently the 557 code_graph examples are regex-generated QA pairs, not the actual graph structure.

**2. Build the live AX capture pipeline.**
Wrap macapptree (or the existing `omega_ax` Rust crate) into a capture loop: snapshot AX tree -> execute action -> wait 150ms -> snapshot again -> compute diff. Output format must include `accessibility_tree`, `action`, `result_ax_tree` fields per example. Without this, there is no embodied training data.

**3. Generate 1,000 Claude Sonnet trajectories.**
Use the AX atlas + symbol QA as grounding context. Format each as `[OBSERVE]->[REASON]->[ACT]->[RESULT]->[DONE]`. 3-8 steps per trajectory. Budget: ~$550 at $0.55/trajectory. This is the core SFT data for app-specific training.

### Group B: General data (can parallel with A)

**4. Source 50K general macOS tool-calling traces.**
Options: (a) download Screen2AX + AgentTrek datasets, (b) Evol-Instruct evolution of seed traces, (c) mine Apple Support articles. The current 144 tool_call examples are 0.3% of what's needed.

**5. Implement IFD superfiltering.**
Run GPT-2 perplexity scoring on all data. Keep top 15% by IFD score. This is a hard prerequisite before composing any training mix.

### Group C: Evaluation (must happen before first training run)

**6. Create BFCL-format evaluation holdout.**
100 standard macOS tasks (open app, click button, type text, navigate, file operations). Must have ground truth verification (AX tree matches expected state after execution).

**7. Create Epistemos-specific evaluation holdout.**
50 app tasks (create note, search vault, run AI operation, navigate graph, use Omega). Same ground truth verification.

### Group D: First training run

**8. Compose the 40/20/20/10/10 data mix from all sources.**
40% tool-calling (from steps 2-4), 20% general instruction-following (from step 4), 20% Epistemos app-specific (from steps 1-3), 10% negative, 10% error recovery. Must pass IFD filtering first.

**9. Run first LoRA training to completion.**
`mlx_lm.lora --iters 200 --lora-rank 16 --lr 3e-4`. Validate against both holdouts (steps 6-7). Produce `adapter_weights.safetensors` + `training_metadata.json`. Register in `adapter_registry.json`.

**10. Validate the nightly flywheel end-to-end.**
Manually trigger `onODIASchedulerFired()` with real traces. Confirm: JSONL export works, QLoRA trainer completes, adapter registers, canary deploy gate evaluates against holdouts.

## What Can Be Trained Now vs What Must Wait

### Can train now (but limited value)

**Chat-style Symbol QA fine-tuning.** You have 3,070 symbol QA examples. You could LoRA-tune on these to produce a model that answers questions about the Epistemos codebase. This is useful as a developer tool but is NOT the embodied agent the master guide describes.

Requirements met:
- Data exists in chat format
- QLoRA infrastructure exists
- Adapter registry can store results
- MoLoRA routing can hot-swap

Limitations:
- No action execution capability
- No AX tree understanding
- No UI navigation
- Catastrophically overfit to one category
- No evaluation holdout to measure quality

**Verdict:** You could do this as a sanity check that the training pipeline works end-to-end, but do not treat the resulting adapter as production-quality or as progress toward the master guide's goals.

### Cannot train yet

| Capability | Blocker |
|-----------|---------|
| Embodied macOS agent (the actual goal) | No AX tree data, no pre/post diffs, no action format |
| Research workflow execution | 0 real research traces in execution DB, Layer 16 not generated to disk |
| GRPO reinforcement learning | No reward model, no decomposed reward components, no BFCL holdout |
| RLAIF alignment | 0 verification pairs (need 464) |
| KTO preference alignment | 0 feedback signals (need 20 minimum) |
| Nightly flywheel | No data to train on, no holdouts to evaluate against, no successful baseline adapter |
| Mamba-2 state injection | MOHAWK distillation not started, no CoreML export |

### Honest timeline estimate

| Milestone | Depends On | Realistic Duration |
|-----------|-----------|-------------------|
| AST code graph + symbol graph extraction | Developer tooling | 3-5 days |
| Live AX capture pipeline | omega_ax crate works, macOS permissions | 3-5 days |
| 1,000 Claude Sonnet trajectories | AX atlas exists, API budget | 2-3 days |
| 50K general traces (download + evolve) | Screen2AX + Evol-Instruct | 5-7 days |
| IFD superfiltering | GPT-2 setup | 1-2 days |
| Evaluation holdouts | AX capture works | 2-3 days |
| First real training run | All above | 1 day |
| **Total to first real training** | | **~3-4 weeks** |

---

*This report was generated from direct inspection of on-disk artifacts, not from code comments or documentation claims. Every "does not exist" statement was verified by filesystem and SQLite queries.*
