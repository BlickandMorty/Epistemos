# Legendary Nano Model: Niche Scripts & Automated Pipelines for the 1B Hybrid Mamba-2/Attention Device Agent

## Executive Overview

Achieving "legendary" nano-model performance requires two compounding advantages beyond architecture and distillation: **data flywheel automation** (continuous collection → filtering → fine-tuning without human bottlenecks) and **Claude Code as an experimental co-pilot** (autonomous hyperparameter search, eval writing, and training orchestration). This playbook enumerates the niche tools, scripts, and techniques that give your 1B Mamba-2/Attention model an unfair edge — covering automated AX-tree data collection, GPU-efficient quality scoring, Claude Code training orchestration patterns, curriculum scheduling, constrained JSON decoding, and online RLVR with device execution rewards.

***

## 1. Automated macOS AX-Tree Data Collection

The single most important automation for a device-control model is a **continuous, zero-annotation data pipeline** from real macOS interactions.

### macapptree — The Core Harvester

**macapptree** (MacPaw, open source) is a Python package that extracts the full AXUIElement accessibility tree of any running macOS application as JSON, plus a cropped screenshot and a segmented screenshot with bounding-box overlays. A single function call gives you everything needed for one training example:[^1]

```python
from macapptree import get_tree, get_tree_screenshot, get_app_bundle

bundle = get_app_bundle("Safari")
tree, screenshot, segmented_screenshot = get_tree_screenshot(bundle)
# tree: full JSON AX hierarchy (roles, values, positions, bboxes, children)
# screenshot: PIL Image of app window
# segmented_screenshot: labeled bounding boxes per element type
```

Install via: `pip install macapptree` and `pip install macapptree[extras]` for screenshot support. The output JSON includes `id`, `name`, `role`, `value`, `absolute_position`, `size`, `enabled`, `bbox`, `visible_bbox`, and `children`. **This is your ground truth for every `click`, `type`, and `scroll` action label.** Run it on a 100ms poll loop during human demonstrations or replay sessions.[^1]

### viralmind ax-tree-parsers — Multi-Platform Extraction

For cross-platform completeness, **viralmind-ai/ax-tree-parsers** (GitHub) provides extraction scripts for macOS, Linux, and Windows desktops. The macOS module wraps `macapptree` and outputs `.jsonl` files that capture human behavior with comprehensive reasoning traces, structured for immediate fine-tuning. The viralmind platform also has a "Forge" that lets you define a training gym, collect human demonstrations, and export structured `.jsonl` training sets automatically.[^2][^3][^4]

### Screen2AX — Pre-Built Dataset + Fallback Generation

When native AX metadata is missing (roughly 33% of macOS apps provide incomplete support), **Screen2AX** (MacPaw, 2025) reconstructs the accessibility tree from a single screenshot using a YOLOv11 + VLM pipeline, achieving a 79% F1 score on full hierarchy reconstruction. Critically, Screen2AX delivers a **2.2× improvement** in GUI grounding accuracy over native AX metadata and surpasses OmniParser V2 on ScreenSpot.[^5][^6]

Three HuggingFace datasets are immediately usable as pre-training data for your model:[^7][^8]
- `macpaw-research/Screen2AX-Tree` — 1,127 screenshots × 112 apps with full annotated AX trees
- `macpaw-research/Screen2AX-Element` — filtered element detection annotations
- `macpaw-research/Screen2AX-Task` — 435 images with task commands + target elements (benchmark-ready)

**Implementation recipe**: Use `macapptree` during runtime for accurate live trees; use Screen2AX as a synthetic augmentation pass over screenshots where AX metadata is stale or empty.

### AgentTrek-Style Tutorial Mining for macOS

**AgentTrek** (ICLR 2025) demonstrated a three-stage pipeline that automatically generates GUI agent trajectories from web tutorials at $0.55 per trajectory — no human annotation:[^9][^10][^11]

1. **Harvest**: Crawl Apple Support articles, YouTube tutorial transcripts, and macOS How-To blogs. Use a FastText classifier to filter tutorial-like pages.[^12]
2. **Structure**: Feed filtered text to Claude/GPT-4o-mini to convert into `{platform, task_description, step_instructions, expected_outcomes}` JSON.[^12]
3. **Replay & verify**: A VLM agent executes each instruction in a live macOS environment. A second VLM evaluator scores trajectory correctness. Only verified trajectories enter your training set.[^11]

For macOS specifically, replace BrowserGym with a Python harness that calls `macapptree.get_tree()` before and after each action, diff-ing the trees to verify the action was effective. A trajectory is "verified" when the post-action AX tree matches the expected state described in the tutorial step. This yields realistic, diverse sequences: "Open Safari → navigate to site → click form field → type email → press Tab → type password → click Login."

### Nightly Collection Script

```python
#!/usr/bin/env python3
# nightly_ax_collector.py — cron job: 0 2 * * *
import json, time, subprocess, pathlib
from macapptree import get_tree, get_app_bundle
from datetime import datetime

APPS = ["Safari", "Finder", "Mail", "Calendar", "Notes", "Terminal"]
OUT_DIR = pathlib.Path("~/axdata").expanduser()
OUT_DIR.mkdir(exist_ok=True)

for app_name in APPS:
    try:
        bundle = get_app_bundle(app_name)
        tree = get_tree(bundle)
        out = OUT_DIR / f"{app_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        out.write_text(json.dumps(tree, indent=2))
    except Exception as e:
        print(f"[WARN] {app_name}: {e}")

print(f"[DONE] Collected {len(list(OUT_DIR.glob('*.json')))} trees")
```

Schedule with `crontab -e`: `0 2 * * * /usr/bin/python3 ~/axdata/nightly_ax_collector.py >> ~/axdata/collector.log 2>&1`

***

## 2. Data Quality Scoring Without a Big Teacher Model

### Superfiltering — GPT-2 as Your Quality Oracle

The most underused script in the nano-model toolkit is **Superfiltering** (ACL 2024). The key discovery: IFD (Instruction-Following Difficulty) scores are **consistent across model sizes**, meaning a 124M GPT-2 can rank your training data identically to a 7B model. With only 5% of your data selected by GPT-2 IFD scores, you match or beat models trained on the full 100% dataset.[^13][^14]

The formula for IFD is:

\[\text{IFD}_\theta(Q, A) = \frac{s_\theta(A)}{s_\theta(A \mid Q)}\]

Where \( s_\theta(A) \) is the model's cross-entropy loss generating answer \( A \) unconditionally, and \( s_\theta(A \mid Q) \) is the conditional loss given instruction \( Q \). High IFD = the instruction meaningfully changes what the model generates = a hard, high-value example.[^15]

**Implementation** (from Cherry_LLM + Superfiltering repos):[^16][^17]

```python
# superfilter_axpress.py
import torch
from transformers import GPT2LMHeadModel, GPT2Tokenizer
import json, pathlib

model = GPT2LMHeadModel.from_pretrained("gpt2")
tokenizer = GPT2Tokenizer.from_pretrained("gpt2")
tokenizer.pad_token = tokenizer.eos_token

def compute_ifd(instruction: str, response: str) -> float:
    def ce_loss(text):
        ids = tokenizer(text, return_tensors="pt", truncation=True, max_length=512).input_ids
        with torch.no_grad():
            out = model(ids, labels=ids)
        return out.loss.item()
    s_a = ce_loss(response)                      # unconditional
    s_a_given_q = ce_loss(instruction + response) # conditional
    return s_a / (s_a_given_q + 1e-8)

# Load your AXPRESS training dataset
data = json.loads(pathlib.Path("axpress_train.jsonl").read_text())
scored = []
for example in data:
    q = example["instruction"]
    a = example["response"]  # e.g. '{"action":"click","selector":"AXButton[Login]"}'
    ifd = compute_ifd(q, a)
    scored.append({**example, "ifd": ifd})

# Select top-k% by IFD score (below 1.0 threshold)
k_pct = 0.15  # top 15%
scored.sort(key=lambda x: x["ifd"], reverse=True)
cherry_count = int(len(scored) * k_pct)
cherries = [s for s in scored if s["ifd"] < 1.0][:cherry_count]
pathlib.Path("axpress_cherry.jsonl").write_text(
    "\n".join(json.dumps(c) for c in cherries)
)
print(f"Selected {len(cherries)}/{len(scored)} cherry examples")
```

This runs in minutes on CPU. For tool-call training data specifically, high IFD examples correspond to instructions where the correct action isn't obvious from the text alone (e.g., "submit the form" → model must infer which AXButton is the submit target from context), which is exactly the distribution you want.[^15]

### Token-Selective Hierarchical Scoring (NeurIPS 2025)

Beyond sample-level IFD, the **T-SHIRT** method (NeurIPS 2025) applies a hierarchical filtering that selects not just which examples to keep but which **tokens within an example** are most informative. For your AX-action training data, this matters: the `"selector": "AXButton[name=Login, parent=AXWindow]"` portion of a response is far more informative than the surrounding JSON boilerplate. Implement by computing per-token loss contribution and zero-masking low-information tokens during the training loss computation.[^18]

***

## 3. Claude Code as an Automated Training Co-Pilot

### The Self-Improving Loop Pattern

**MindStudio's binary eval architecture** (March 2026) demonstrated a fully automated skill improvement loop where Claude Code acts as both the experimenter and the fixer:[^19]

```
[Failing Eval] → Claude Code reads trace + rationale → 
                 proposes data/prompt fix → 
                 re-run evals → 
                 if pass, merge to training data
```

This is directly applicable to your MOHAWK pipeline. The recipe:

1. **Write binary evals** for your AX agent: each eval is a Python assertion that checks whether the model's output `<axpress>` action, when executed in a sandboxed macOS VM, produces the correct post-state AX tree.
2. **Let Claude Code see failing traces** via MLflow's tracing integration. MLflow logs every generation, the AX tree snapshot, and the action taken.[^20]
3. **Claude Code edits the `SKILL.md`** (the system prompt / few-shot examples for your training data generator), adding targeted corrections for the failure pattern it observed.

### Claude Code + MLflow Experiment Tracking

MLflow's integration with Claude Code (2026) enables automated hyperparameter sweeps for your LoRA adapters:[^21][^22]

```python
# claude_code_hparam_search.py
# Give this script to Claude Code with instruction:
# "Find the best LoRA rank and learning rate for axpress SFT.
#  Run 9 experiments, log all to MLflow, return the winning config."

import mlflow
import subprocess, json

search_space = {
    "lora_rank": [8, 16, 32],
    "lr": [1e-4, 3e-4, 1e-3]
}

best = {"bfcl_score": 0, "config": {}}

with mlflow.start_run(run_name="axpress_lora_sweep"):
    for rank in search_space["lora_rank"]:
        for lr in search_space["lr"]:
            with mlflow.start_run(run_name=f"rank={rank}_lr={lr}", nested=True):
                mlflow.log_params({"lora_rank": rank, "lr": lr})
                
                # Launch fine-tuning via mlx_lm (Apple Silicon)
                result = subprocess.run([
                    "python", "-m", "mlx_lm.lora",
                    "--model", "path/to/mohawk_base",
                    "--data", "axpress_cherry.jsonl",
                    "--lora-layers", "8",
                    "--lora-rank", str(rank),
                    "--learning-rate", str(lr),
                    "--iters", "500",
                    "--save-path", f"checkpoints/rank{rank}_lr{lr}"
                ], capture_output=True, text=True)
                
                # Eval on BFCL-style holdout
                score = evaluate_bfcl_holdout(f"checkpoints/rank{rank}_lr{lr}")
                mlflow.log_metric("bfcl_score", score)
                
                if score > best["bfcl_score"]:
                    best = {"bfcl_score": score, "config": {"rank": rank, "lr": lr}}

mlflow.log_dict(best, "best_config.json")
```

Claude Code can run this fully autonomously in a background terminal session. Feed it the script above plus a SKILL.md describing what "good BFCL performance" looks like, and it iterates without human involvement.[^23]

### Exporting Claude Code Sessions as Training Data

Every Claude Code session where you debugged training issues or wrote new eval functions is itself potential training data for your meta-learning loop. The `/export` slash command dumps the entire conversation as a structured markdown file. A post-processing script can extract:[^24]

- **Reasoning traces** (the thinking tokens, if logged) as chain-of-thought SFT examples
- **Bug fixes** (the model's action given a failing test) as DPO pairs (failing attempt = rejected, fix = chosen)
- **Architectural decisions** as rationale-augmented instructions

This creates a compound effect: every debugging session both fixes a bug AND adds a new high-quality training example.

### Kiln AI — Zero-Code Synthetic Data Generation

**Kiln AI** (MIT license, 3.5k GitHub stars) is the most practical tool for generating synthetic macOS automation traces at scale. It provides:[^25][^26]

- **Git-versioned dataset collaboration**: non-technical annotators can rate and label AX interaction traces via a GUI
- **Chain-of-thought data generation**: uses a large teacher model (Claude 3.7 Sonnet, GPT-4.1) with heavy prompting to generate training examples, then fine-tunes a smaller student on those examples[^26]
- **Reasoning model distillation**: built-in support for extracting `<think>...</think>` traces for direct distillation into your MOHAWK student
- **Python API** (`pip install kiln-ai`) for integration into your automated pipeline

```python
# kiln_synthetic_gen.py
from kiln_ai import KilnTask, generate_synthetic

task = KilnTask(
    name="macOS AX Action Selection",
    system_prompt="Given a macOS AX tree and a user intent, emit the correct AXPress action.",
    output_schema={"action": "string", "selector": "string", "value": "string | null"}
)

# Generate 1000 diverse examples with Claude as teacher
examples = generate_synthetic(
    task=task,
    model="claude-opus-4-5",
    n=1000,
    techniques=["chain_of_thought", "few_shot", "repair_and_feedback"],
    seed_examples=load_real_traces("axpress_cherry.jsonl")
)

examples.save("axpress_synthetic_1k.jsonl")
```

***

## 4. Dynamic Curriculum Scheduling for MOHAWK SFT

### CAMPUS — Competence-Aware Dynamic Curriculum

Static difficulty sorting (sort by prompt length and call it done) is suboptimal because a task that is "hard" at epoch 1 becomes "trivial" by epoch 3. **CAMPUS** (EMNLP 2025) solves this by maintaining multiple difficulty rankings simultaneously and selecting, at each training step, the sub-curriculum whose examples are just above the model's current competence level (minimum perplexity above a threshold). CAMPUS outperforms state-of-the-art static curriculum baselines by an average of +7% on instruction following benchmarks.[^27][^28]

For your AX agent, define these difficulty axes:

| Difficulty Axis | Easy Examples | Hard Examples |
|----------------|---------------|---------------|
| **AX tree depth** | Flat 1-level trees (menu bars) | Deep 5+ level nested dialogs |
| **Selector ambiguity** | Single matching element | 3+ elements with same role |
| **Action chain length** | Single click | 5-step sequences |
| **App familiarity** | Safari, Finder (common) | Obscure third-party apps |
| **AXPress IFD score** | Low IFD (action obvious) | High IFD (requires reasoning) |

```python
# campus_scheduler.py
import numpy as np
from dataclasses import dataclass

@dataclass
class Example:
    data: dict
    difficulty_scores: dict  # {"depth": 0.3, "ambiguity": 0.7, "chain_len": 0.5, "ifd": 0.8}

class CAMPUSScheduler:
    def __init__(self, examples: list[Example], axes: list[str]):
        self.examples = examples
        self.axes = axes
        # Pre-sort by each axis
        self.sorted_by_axis = {
            ax: sorted(examples, key=lambda e: e.difficulty_scores[ax])
            for ax in axes
        }
    
    def next_batch(self, model, batch_size: int) -> list[Example]:
        # Compute model's current perplexity on each axis sub-curriculum
        min_ppl_axis = None
        min_ppl = float("inf")
        for ax, sorted_examples in self.sorted_by_axis.items():
            # Sample from current competence tier (middle tercile)
            tier = sorted_examples[len(sorted_examples)//3 : 2*len(sorted_examples)//3]
            ppl = compute_perplexity(model, tier[:32])
            if ppl < min_ppl:
                min_ppl = ppl
                min_ppl_axis = ax
        
        # Select from the axis that is still learnable (not too easy, not too hard)
        candidates = self.sorted_by_axis[min_ppl_axis]
        return np.random.choice(candidates, size=batch_size, replace=False).tolist()
```

### DeepSpeed Curriculum Learning for Context Length

Your Mamba layers process sequences with O(L) memory but attention layers scale quadratically. Start MOHAWK Stage 2/3 SFT with short AX trees (1–3 levels, < 512 tokens) and progressively increase to full deep trees (1024–2048 tokens) over training. This single trick reduces peak GPU memory by ~40% in early training and stabilizes the Mamba state-decay learning by ensuring the model internalizes simple patterns before seeing complex cascaded sequences.[^29][^30]

```yaml
# deepspeed_curriculum.yaml — add to your MOHAWK SFT config
curriculum_learning:
  enabled: true
  curriculum_type: seqlen
  min_difficulty: 128
  max_difficulty: 2048
  schedule_type: linear
  total_curriculum_step: 5000
```

***

## 5. Constrained Decoding for 99%+ Tool-Call Reliability

### XGrammar — The Production Standard

**XGrammar** is the default structured generation backend for vLLM, SGLang, and TensorRT-LLM as of March 2026. It achieves under 40 microseconds per token overhead (negligible next to 10–50ms model inference), compiles schemas in advance and caches them, and has the lowest compilation error rate in the JSONSchemaBench evaluation.[^31][^32]

For your `<axpress>` action schema:

```python
# axpress_schema.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["action", "selector"],
  "properties": {
    "action": {
      "type": "string",
      "enum": ["click", "double_click", "type", "key", "scroll", "focus", "shortcut"]
    },
    "selector": { "type": "string", "minLength": 1 },
    "value": { "type": "string" },
    "modifiers": {
      "type": "array",
      "items": { "type": "string", "enum": ["cmd", "shift", "alt", "ctrl"] }
    }
  },
  "additionalProperties": false
}
```

```python
# inference with XGrammar constrained decoding
from xgrammar import GrammarEngine
from transformers import AutoTokenizer

tokenizer = AutoTokenizer.from_pretrained("path/to/mohawk_quantized")
engine = GrammarEngine.from_json_schema(
    open("axpress_schema.json").read(),
    tokenizer=tokenizer
)

# During generation, pass the logits processor
output = model.generate(
    input_ids,
    logits_processor=[engine.get_logits_processor()],
    max_new_tokens=128,
    do_sample=False  # greedy for reliability
)
```

**Critical note**: Constrained decoding guarantees syntactic validity but not semantic correctness. A selector string that is structurally valid (`AXButton[name=Submit]`) but targets the wrong element still passes the grammar. Combine constrained decoding with fine-tuning: the grammar prevents format failures at test time, but training quality determines semantic accuracy.[^32][^31]

### Fine-Tune First, Then Constrain

JSONSchemaBench (10K real schemas) found constrained decoding adds only +4% improvement on structured tasks when the model is already well-trained. The strategy: **achieve ~92% correct JSON via template fine-tuning first** (your `<axpress>` system prompt training), then layer constrained decoding on top to get from 92% to 99.9%. The combined approach eliminates both semantic errors (handled by fine-tuning) and formatting errors (handled by grammar constraints).[^31]

***

## 6. Nightly Training Loop — The Full Automation Script

The following `MAPE-K flywheel` pattern combines all pipeline components into a nightly cron job. The key insight from the NVIDIA Data Flywheel Blueprint: only deploy models that represent **net improvement**; use a canary rollout with SLO-based automatic rollback.[^33][^34][^35]

```python
# nightly_flywheel.py — runs every night at 2 AM
import pathlib, json, subprocess, mlflow
from datetime import datetime

LOG_DIR = pathlib.Path("~/axpress_logs").expanduser()
DATA_DIR = pathlib.Path("~/axdata").expanduser()
CHECKPOINT_DIR = pathlib.Path("~/checkpoints").expanduser()

def step1_collect():
    """Collect new AX traces from production usage logs."""
    traces = []
    for log_file in LOG_DIR.glob("*.jsonl"):
        with open(log_file) as f:
            for line in f:
                trace = json.loads(line)
                if trace.get("execution_result") is not None:  # has ground truth
                    traces.append(trace)
    return traces

def step2_filter_quality(traces):
    """Run Superfiltering IFD scoring. Keep top 15% by IFD."""
    from superfilter import compute_ifd_batch
    scored = compute_ifd_batch(traces)  # uses GPT-2, runs on CPU in ~5 min
    scored.sort(key=lambda x: x["ifd"], reverse=True)
    cherries = [s for s in scored if s["ifd"] < 1.0]
    return cherries[:int(len(cherries) * 0.15)]

def step3_campus_sort(cherries):
    """Sort by multi-axis curriculum for progressive training."""
    from campus_scheduler import CAMPUSScheduler
    scheduler = CAMPUSScheduler(cherries, axes=["depth","ambiguity","chain_len","ifd"])
    return scheduler.get_sorted_training_order()

def step4_lora_finetune(sorted_data, base_model_path):
    """Fine-tune with mlx_lm LoRA on Apple Silicon."""
    data_path = DATA_DIR / f"nightly_{datetime.now().strftime('%Y%m%d')}.jsonl"
    with open(data_path, "w") as f:
        for ex in sorted_data:
            f.write(json.dumps(ex) + "\n")
    
    result = subprocess.run([
        "python", "-m", "mlx_lm.lora",
        "--model", str(base_model_path),
        "--data", str(data_path),
        "--lora-rank", "16",
        "--learning-rate", "3e-4",
        "--iters", "200",  # short nightly incremental update
        "--save-path", str(CHECKPOINT_DIR / "nightly_adapter"),
        "--adapter-path", str(CHECKPOINT_DIR / "current_adapter"),  # warm start
    ], capture_output=True, text=True)
    return CHECKPOINT_DIR / "nightly_adapter"

def step5_evaluate(adapter_path):
    """Evaluate on holdout set. Return BFCL-style accuracy."""
    # Run your AX agent eval harness
    score = run_axpress_holdout_eval(adapter_path)
    return score

def step6_canary_deploy(adapter_path, new_score, baseline_score):
    """Deploy only if improvement. Rollback on SLO breach."""
    IMPROVEMENT_THRESHOLD = 0.005  # 0.5% gain required
    if new_score > baseline_score + IMPROVEMENT_THRESHOLD:
        import shutil
        shutil.copy(adapter_path, CHECKPOINT_DIR / "production_adapter")
        print(f"[DEPLOY] {new_score:.4f} vs baseline {baseline_score:.4f}")
        return True
    else:
        print(f"[SKIP] No improvement: {new_score:.4f} vs {baseline_score:.4f}")
        return False

if __name__ == "__main__":
    with mlflow.start_run(run_name=f"nightly_{datetime.now().date()}"):
        traces = step1_collect()
        cherries = step2_filter_quality(traces)
        sorted_data = step3_campus_sort(cherries)
        adapter_path = step4_lora_finetune(sorted_data, CHECKPOINT_DIR / "mohawk_base")
        new_score = step5_evaluate(adapter_path)
        baseline_score = step5_evaluate(CHECKPOINT_DIR / "production_adapter")
        mlflow.log_metrics({"new_bfcl": new_score, "baseline_bfcl": baseline_score})
        step6_canary_deploy(adapter_path, new_score, baseline_score)
```

***

## 7. RLVR / GRPO with Execution-Based Rewards

### Agent-RLVR Pattern for Device Control

Standard RLVR fails on multi-step device-control tasks because the reward is too sparse — most partial trajectories get reward 0 even when they're mostly correct. **Agent-RLVR** (2025) addresses this with "agent guidance": the system provides the model with high-level plans and error feedback when it fails, then re-attempts with guidance, and uses both guided and unguided trajectories for RLVR updates. This approach elevated Qwen-2.5-72B from 9.4% to 22.4% on SWE-Bench Verified.[^36]

For your device-control agent, implement a rubric-decomposed reward:

```python
# axpress_reward.py — multi-component verifiable reward
def compute_axpress_reward(
    generated_action: dict,
    expected_state: dict,
    pre_state: dict,
    execution_log: dict
) -> float:
    """
    Rubric-decomposed reward for AX device-control actions.
    Each component is independently verifiable — no model judge needed.
    """
    reward = 0.0
    
    # Component 1: JSON validity (0.1)
    if is_valid_json(generated_action, schema=AXPRESS_SCHEMA):
        reward += 0.1
    
    # Component 2: Selector resolves in AX tree (0.2)
    if resolve_selector(generated_action["selector"], pre_state["ax_tree"]) is not None:
        reward += 0.2
    
    # Component 3: Action type is contextually valid (0.1)
    element = resolve_selector(generated_action["selector"], pre_state["ax_tree"])
    if element and generated_action["action"] in VALID_ACTIONS_FOR_ROLE[element["role"]]:
        reward += 0.1
    
    # Component 4: Post-execution state matches expected (0.6)
    post_state = execute_action_in_sandbox(generated_action, pre_state)
    state_match = compute_ax_tree_similarity(post_state["ax_tree"], expected_state["ax_tree"])
    reward += 0.6 * state_match
    
    return reward
```

This decomposed reward prevents the most common failure mode: the model gaming the binary success signal by clicking in irrelevant areas that happen to trigger the expected state transition by accident.[^37]

### Unsloth GRPO Integration

**Unsloth** (2026) supports GRPO with custom reward functions, running efficiently on a single GPU or Apple Silicon. For 1B-scale models:[^38][^39]

```python
from trl import GRPOConfig, GRPOTrainer
from unsloth import FastLanguageModel

model, tokenizer = FastLanguageModel.from_pretrained(
    "path/to/mohawk_sft",
    max_seq_length=2048,
    load_in_4bit=True,
)

model = FastLanguageModel.get_peft_model(
    model, r=16, target_modules=["q_proj","v_proj","o_proj"],
    lora_alpha=16, lora_dropout=0,
)

config = GRPOConfig(
    num_generations=8,          # sample 8 actions per context
    loss_type="dr_grpo",        # more stable than vanilla GRPO for small models
    epsilon=0.2,
    epsilon_high=0.28,          # one-sided clipping
    mask_truncated_completions=True,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=8,
)

trainer = GRPOTrainer(
    model=model,
    reward_funcs=[compute_axpress_reward],
    args=config,
    train_dataset=grpo_dataset,  # each row: {"prompt": ax_context, "answer": expected_state}
)
trainer.train()
```

**Key tuning notes for 1B GRPO**:[^38]
- Use `loss_type="dr_grpo"` or `"dapo"` — vanilla GRPO becomes unstable at small scale due to high variance in group estimates
- Set `num_generations=8` minimum; `16` if GPU memory allows (better advantage estimates)
- Start GRPO only after SFT has converged — base model with no SFT leads to degenerate reward hacking

***

## 8. MLX Fine-Tuning on Apple Silicon — Practical Scripts

### Single-Command Adapter Training

**Apple's mlx-lm** (WWDC 2025) supports LoRA fine-tuning on quantized models directly on M-series chips. Critically, it supports adapter training on top of 4-bit quantized models, which means you can fine-tune your already-quantized MOHAWK inference model in-place on the same Mac you deploy it on:[^40][^41]

```bash
# One-command LoRA fine-tune on Apple Silicon
python -m mlx_lm.lora \
  --model ~/mohawk_4bit_quantized \
  --data axpress_cherry.jsonl \
  --lora-layers 8 \
  --lora-rank 16 \
  --learning-rate 3e-4 \
  --iters 1000 \
  --save-path ~/adapters/axpress_v2 \
  --test  # run eval after training
```

After training, fuse the adapter back into the quantized base model for a self-contained deployable artifact:[^40]

```bash
python -m mlx_lm.fuse \
  --model ~/mohawk_4bit_quantized \
  --adapter-path ~/adapters/axpress_v2 \
  --save-path ~/mohawk_axpress_fused \
  --de-quantize  # optionally return to float16 for ANE compatibility
```

### MLX Mamba Training

A full MLX implementation of Mamba (inference + training) for Apple Silicon exists at `alxndrTL/mamba.py`. This enables running your hybrid Mamba-2/Attention training loop directly on an M-series Mac for ablation experiments without needing cloud GPUs. For the Mamba-specific layers in your hybrid architecture, use this to validate that your custom state decay schedules work correctly before deploying to the full training cluster.[^42]

***

## 9. DSPy GEPA — Auto-Optimize Your System Prompt

After SFT, the system prompt for your device agent is still a source of significant variance. **DSPy GEPA** (Genetic-Pareto optimizer) can automatically improve it using only 50–150 evaluation calls:[^43]

```python
import dspy

# Task LM = your deployed MOHAWK model (via MLX inference server)
dspy.settings.configure(lm=dspy.LM("http://localhost:8080/v1/completions"))
# Reflection LM = Claude Opus or GPT-4.1 (analyzes failures)
reflection_lm = dspy.LM("claude-opus-4-5")

class AXPressAgent(dspy.Signature):
    """Given AX tree and user intent, emit the correct AXPress action."""
    ax_tree: str = dspy.InputField()
    user_intent: str = dspy.InputField()
    action: str = dspy.OutputField(desc="JSON AXPress action")

def axpress_metric(example, prediction, trace=None, pred_name=None, pred_trace=None):
    predicted_action = parse_axpress(prediction.action)
    executed_state = execute_action_in_sandbox(predicted_action, example.pre_state)
    score = compute_ax_tree_similarity(executed_state, example.expected_state)
    
    feedback = f"Score: {score:.2f}. "
    if score < 0.8:
        feedback += f"Expected selector targeting: {example.ground_truth_element}. "
        feedback += f"Model selected: {predicted_action.get('selector', 'none')}."
    return dspy.Prediction(score=score, feedback=feedback)

optimizer = dspy.GEPA(
    metric=axpress_metric,
    auto="medium",
    reflection_lm=reflection_lm,
    reflection_minibatch_size=16,
    num_threads=4,
)

program = dspy.ChainOfThought(AXPressAgent)
optimized = optimizer.compile(program, trainset=dspy_trainset)
print("Optimized system prompt:", optimized.predict.signature.instructions)
```

GEPA evolved a basic CoT program from 67% to 93% accuracy on MATH by discovering failure patterns across batches of errors. For AX tree grounding, where failure modes cluster by element type and app category, this reflective optimization can surface systematic gaps in your training data.[^44]

***

## 10. nanochat Architecture Pattern — Tool Use Mid-Training

Karpathy's **nanochat** (2025, ~8,000 lines) demonstrated the cleanest small-model pipeline for teaching tool use in mid-training:[^45][^46][^47]

- **Stage 1 (Base)**: Pretrain on FineWeb-EDU to establish language capability
- **Stage 2 (Mid-train)**: Mix conversations (SmolTalk), multiple-choice (MMLU aux), and **tool-use examples** (GSM8K with `<|python_start|>…<|python_end|>` blocks). Total: 568K rows[^48][^46]
- **Stage 3 (SFT)**: High-quality instruction-following, matching test-time format exactly to reduce train/inference mismatch[^46]
- **Stage 4 (RLVR)**: GRPO on verifiable tasks (GSM8K for math; your AX sandbox for device control)[^47]

Adapt the tool-use mid-training stage for your pipeline:

```python
# mid_train_mixture.py — nanochat-style data mixer for MOHAWK Stage 3
from datasets import Dataset, concatenate_datasets

smoltalk = load_smoltalk_conversations(n=460_000)      # general conversation
mmlu_aux = load_mmlu_auxiliary(n=100_000)              # world knowledge MC
axpress_tools = load_axpress_traces(n=50_000)          # ← YOUR TOOL-USE DATA
                                                        # with <axpress>...</axpress> tags

# Weight ratio: 60% conversation, 15% MC, 25% tool use
mixture = concatenate_datasets([
    smoltalk.select(range(300_000)),
    mmlu_aux.select(range(75_000)),
    axpress_tools.select(range(125_000))  # upsample your domain data
]).shuffle(seed=42)
```

The critical insight from nanochat: teaching tool use during mid-training (before SFT) is more effective than adding it only during SFT, because the model first learns the mechanical format of tool invocation on easy cases (calculator), then deepens semantic understanding via SFT.[^49][^46]

***

## 11. Smol Training Playbook — Key Rules for Nano-Model Quality

HuggingFace's 214-page **Smol Training Playbook** (2025) is the definitive reference for small model training. Its most actionable rules for your build:[^50][^51]

1. **Modify one thing at a time** — If you change LR schedule AND data mix AND LoRA rank and see +2% on BFCL, you've learned nothing. Claude Code is excellent at enforcing this: instruct it to run one-variable experiments.[^50]

2. **WSD scheduler over cosine**: Warmup-Stable-Decay allows you to safely continue training from any pre-decay checkpoint when new macOS traces become available. Cosine decay is terminal.[^52]

3. **Custom LR multipliers**: Embedding parameters benefit from 75× higher LR than linear layers; scalar parameters need only 5× the base rate. For your Mamba-2 layers, apply similar asymmetry: A/B matrices (input/output projections) can use the default LR, but the selective scan state parameters (`A_log`, `dt`) benefit from a 3–5× lower LR for stability.[^52]

4. **Proxy ablation before full runs**: Train a 150M proxy Mamba-2/Attention hybrid (same depth/width ratios as your 1B, but 4× smaller) for 10B tokens to validate architectural choices. If it hurts at 150M, discard it before burning GPU budget.[^50]

5. **Bits-per-byte over perplexity** for evaluation: BPB is tokenizer-invariant and enables fair comparison across checkpoints trained with different tokenizers.[^46]

***

## 12. LoRA Hot-Swap Routing for Multi-Skill Agents

For routing between specialized behaviors (UI navigation vs. text extraction vs. app launch vs. Shortcut execution), **Activated LoRA (aLoRA)** from HuggingFace PEFT provides the cleanest solution. aLoRA activates adapter weights only when a specific invocation token sequence is detected in the input, enabling **KV cache sharing** between the base model and all adapters up to the invocation point:[^53]

```python
# Train separate adapters for each macro skill
skills = {
    "ui_nav":     train_lora(data=ui_navigation_traces),
    "text_extract": train_lora(data=text_extraction_traces),
    "shortcut":   train_lora(data=shortcut_execution_traces),
}

# At inference: router injects skill token based on intent classification
intent = classify_intent(user_request)  # fast 50ms classifier
invocation_token = SKILL_TOKEN_MAP[intent]  # e.g., "<|ui_nav|>"

prompt = f"{system_prompt}\n{ax_tree}\n{invocation_token}\n{user_request}"
# aLoRA activates only the correct adapter after the invocation token
output = model_with_alora.generate(prompt, adapter_name=intent)
```

The routing classifier can itself be a tiny 50M model trained on intent labels from your macOS traces, running entirely on ANE (< 5ms latency). This pattern avoids the "expert collapse" failure mode that occurs when LoRA is applied to MoE expert FFN layers.[^54]

***

## Data Pipeline Architecture Summary

| Stage | Tool / Script | Input | Output | Automation Level |
|-------|--------------|-------|--------|-----------------|
| **Collection** | macapptree + cron | Live macOS sessions | Raw AX JSON + screenshots | Fully automated [^1] |
| **Augmentation** | Screen2AX | Screenshots | AX trees for incomplete apps | Automated [^6] |
| **Trajectory synthesis** | AgentTrek-style | macOS tutorials | Step-by-step annotated traces | Automated @ $0.55/trace [^10] |
| **Quality scoring** | Superfiltering (GPT-2) | Raw JSONL | IFD-scored, filtered JSONL | Automated, CPU-only [^13] |
| **Synthetic expansion** | Kiln AI | Cherry examples | Claude-distilled synthetic JSONL | Automated [^25] |
| **Curriculum sort** | CAMPUS scheduler | Filtered JSONL | Difficulty-ordered training batches | Automated [^28] |
| **SFT fine-tuning** | mlx_lm.lora | Sorted JSONL | LoRA adapter checkpoint | Automated, on-device [^40] |
| **RLVR** | Unsloth GRPO | Adapter + sandbox env | Policy-improved adapter | Automated [^38] |
| **Eval + gate** | MLflow + BFCL holdout | New adapter | Pass/fail decision | Automated [^21] |
| **Deploy** | mlx_lm.fuse + canary | Passing adapter | Fused quantized model | Automated with rollback [^34] |
| **Prompt optimization** | DSPy GEPA | Deployed model | Improved system prompt | Automated [^43] |

***

## Critical Failure Modes to Prevent

1. **Reward hacking in GRPO**: When the binary sandbox reward is too easy to game (clicking anywhere that dismisses a dialog counts as "success"), models quickly learn degenerate strategies. Use the rubric-decomposed reward above with the selector-resolution and post-state-match components.[^37]

2. **IFD score drift**: As your model improves via nightly fine-tuning, yesterday's "hard" examples become easy. Re-score IFD every 2 weeks using the current production model (not GPT-2) to recalibrate what "challenging" means.[^15]

3. **aLoRA cache contamination**: Once a LoRA adapter has modified KV values, those values cannot be shared with the base model or other adapters. Always `deepcopy` the cache before branching to multiple adapters in the same session.[^53]

4. **Mamba state collapse in long sequences**: If the model starts forgetting which app it is in after 10+ actions, the selective scan A_log parameters have learned near-zero state retention. Add a "context maintenance" reward component: +0.05 if the model correctly identifies the active app in its reasoning trace at each step, regardless of action correctness.

5. **CAMPUS perplexity stalling**: The competence-aware scheduler can get stuck if the model's perplexity on all sub-curricula drops simultaneously (plateau). Implement a 10% random injection of maximum-difficulty examples at all times to prevent "curriculum stalling."

---

## References

1. [MacPaw/macapptree: Repository for macos accessibility parser](https://github.com/MacPaw/macapptree) - macapptree is a Python package that extracts the accessibility tree of a macOS application's screen ...

2. [viralmind-ai/ax-tree-parsers: Accessibility tree parsing scripts for ...](https://github.com/viralmind-ai/accessibility-tree-parsers) - This repository contains scripts to extract the accessibility trees from three of the more popular o...

3. [Introduction | viralmind.ai](https://docs.viralmind.ai/the-forge/introduction) - Once an AI agent masters a set of skills, it can be deployed as a local automation tool, enterprise ...

4. [A decentralized AI training protocol leveraging large action models](https://www.mexc.co/en-NG/news/488) - Author: Emperor Osmo

Compiled by: Felix, PANews

**PANews Note:** **This article only represents th...

5. [Screen2AX: Vision-Based Approach for Automatic macOS ... - arXiv](https://arxiv.org/abs/2507.16704) - We introduce Screen2AX, the first framework to automatically create real-time, tree-structured acces...

6. [Vision-Based Approach for Automatic macOS Accessibility Generation](https://research.macpaw.com/publications/screen2axvisionbasedapproachautomatic) - Screen2AX is a vision-based framework that reconstructs macOS accessibility trees from screenshots, ...

7. [Repository for Screen2AX paper - GitHub](https://github.com/MacPaw/Screen2AX) - A research-driven project for generating accessibility of macOS applications using computer vision a...

8. [macpaw-research/Screen2AX-Tree · Datasets at Hugging Face](https://huggingface.co/datasets/macpaw-research/Screen2AX-Tree) - This dataset provides hierarchical accessibility annotations of macOS application screenshots, struc...

9. [AgentTrek: Agent Trajectory Synthesis via Guiding Replay with Web ...](https://agenttrek.github.io) - A scalable data synthesis pipeline that generates high-quality GUI agent trajectories by leveraging ...

10. [Agent Trajectory Synthesis via Guiding Replay with Web Tutorials](https://arxiv.org/abs/2412.09605) - We propose AgentTrek, a scalable data synthesis pipeline that generates web agent trajectories by le...

11. [Agent Trajectory Synthesis via Guiding Replay with Web Tutorials](https://proceedings.iclr.cc/paper_files/paper/2025/hash/c681fb2bf1d785fbc766f3ea14758aab-Abstract-Conference.html) - To address this challenge, we propose AgentTrek, a scalable data synthesis pipeline that generates h...

12. [Agent Trajectory Synthesis via Guiding Replay with Web Tutorials](https://www.themoonlight.io/en/review/agenttrek-agent-trajectory-synthesis-via-guiding-replay-with-web-tutorials) - AgentTrek encompasses a strategic, multifaceted approach to generating agent trajectory data through...

13. [Weak-to-Strong Data Filtering for Fast Instruction-Tuning - arXiv](https://arxiv.org/html/2402.00530v1) - Weak-to-strong superfiltering proposed by this paper, which utilizes a much smaller filter model, eg...

14. [Weak-to-Strong Data Filtering for Fast Instruction-Tuning - ACL ...](https://aclanthology.org/2024.acl-long.769/) - To reduce the filtering cost, we study Superfiltering: Can we use a smaller and weaker model to sele...

15. [Boosting LLM Performance with Self-Guided Data Selection ... - arXiv](https://arxiv.org/html/2308.12032v4) - We introduce the Instruction-Following Difficulty (IFD) metric as a tool to identify gaps in a model...

16. [GitHub - tianyi-lab/Cherry_LLM: [NAACL'24] Self-data filtering of ...](https://github.com/tianyi-lab/Cherry_LLM) - By calculating Instruction-Following Difficulty (IFD) scores, we quantify the challenge each sample ...

17. [Superfiltering: Weak-to-Strong Data Filtering (ACL'24) - GitHub](https://github.com/tianyi-lab/Superfiltering) - This is the repo for the Superfiltering project, which introduces a method astonishingly utilizes a ...

18. [NeurIPS Poster T-SHIRT: Token-Selective Hierarchical Data ...](https://neurips.cc/virtual/2025/poster/116042) - To improve training efficiency and reduce data redundancy, recent works use LLM-based scoring functi...

19. [How to Build Self-Improving AI Skills with Binary Evals and Claude ...](https://www.mindstudio.ai/blog/self-improving-ai-skills-binary-evals-claude-code) - This guide walks through the exact process: what binary evals are, how to write them, and how to wir...

20. [Testing and Refining Claude Code Skills with MLflow](https://mlflow.org/blog/evaluating-skills-mlflow) - This skill guides Claude through the full evaluation workflow: run the agent to understand its behav...

21. [5 Tips to Get More Out of Your Claude Code with MLflow](http://mlflow.org/blog/mlflow-claude-code) - Model Training. Manage the full machine learning and deep learning model lifecycle, with experiment ...

22. [A Complete End-to-End Coding Guide to MLflow Experiment ...](https://www.marktechpost.com/2026/03/01/a-complete-end-to-end-coding-guide-to-mlflow-experiment-tracking-hyperparameter-optimization-model-evaluation-and-live-model-deployment/) - We enable MLflow autologging, allowing automatic tracking of parameters, metrics, and model artifact...

23. [How to use Claude Code to automate model training IN MINUTES](https://www.youtube.com/watch?v=jP6tN9JTtxE) - ... training script: https://github.com/gradio-app/trackio/blob/main/autonomous-experiments/01_findi...

24. [/export: Get Receipts for Every AI Conversation - DEV Community](https://dev.to/rajeshroyal/export-get-receipts-for-every-ai-conversation-57ni) - /export transforms ephemeral conversations into permanent records. Your Claude Code sessions become ...

25. [GitHub - Kiln-AI/Kiln: Build, Evaluate, and Optimize AI Systems ...](https://github.com/Kiln-AI/kiln) - Our synthetic data generation tool can build datasets for evals and fine-tuning in minutes. Your mod...

26. [Kiln - Interactive LLM fine-tuning, dataset collab & synthetic data gen](https://news.ycombinator.com/item?id=42383284) - The demo shows starting a project from scratch, defining a task, generating synthetic training data,...

27. [[PDF] Teaching According to Talents! Instruction Tuning LLMs ... - arXiv.org](https://arxiv.org/pdf/2509.13790.pdf) - CAMPUS offers several advantages: (1) Dynamic selection for sub-curriculum. (2). Competency-aware ad...

28. [Teaching According to Talents! Instruction Tuning LLMs with ...](https://aclanthology.org/2025.findings-emnlp.629/) - CAMPUS offers several advantages: (1) Dynamic selection for sub-curriculum. (2) Competency-aware adj...

29. [Training Large Language Models with Curriculum Learning (2020 ...](https://aiwithmike.substack.com/p/training-large-language-models-with) - Curriculum learning (CL) is a training strategy in which data or tasks are presented in a structured...

30. [Curriculum Learning: A Regularization Method for Efficient and ...](https://www.deepspeed.ai/tutorials/curriculum-learning/) - Curriculum Learning: A Regularization Method for Efficient and Stable Billion-Scale GPT Model Pre-Tr...

31. [Generating Structured Outputs from Language Models: Benchmark ...](https://arxiv.org/html/2501.10868v1) - Constrained decoding frameworks have standardized around JSON Schema as a structured data format, wi...

32. [How Structured Outputs and Constrained Decoding Work](https://letsdatascience.com/blog/structured-outputs-making-llms-return-reliable-json) - Master structured outputs for LLMs using constrained decoding. Learn how logit processors and state ...

33. [Adaptive Data Flywheel: Applying MAPE Control Loops to AI Agent ...](https://arxiv.org/html/2510.27051v1) - We introduce a MAPE-K-aligned data flywheel architecture that consolidates monitoring, analysis, pla...

34. [How automated is your data flywheel, really? : r/mlops - Reddit](https://www.reddit.com/r/mlops/comments/1ojqudm/how_automated_is_your_data_flywheel_really/) - It's basically traditional software maintenance with fancier logging. The closest I've seen to actua...

35. [Build Continuous Refining AI Agents with Data Flywheels Blueprint ...](https://build.nvidia.com/nvidia/build-an-enterprise-data-flywheel) - The NVIDIA Data Flywheel Blueprint solves this by creating a self-reinforcing, automated loop that c...

36. [[2506.11425] Agent-RLVR: Training Software Engineering ... - arXiv](https://arxiv.org/abs/2506.11425) - In this work, we introduce Agent-RLVR, a framework that makes RLVR effective in challenging agentic ...

37. [Reward Hacking in RLVR Systems - Emergent Mind](https://www.emergentmind.com/topics/reward-hacking-in-reinforcement-learning-with-verifiable-rewards-rlvr) - Reward hacking in RLVR is the exploitation of loopholes in reward definitions that maximize formal r...

38. [Reinforcement Learning (RL) Guide | Unsloth Documentation](https://unsloth.ai/docs/get-started/reinforcement-learning-rl-guide) - The Reward Model is removed and replaced with just custom reward function which RLVR can be used. Th...

39. [Tutorial: Train your own Reasoning model with GRPO - Unsloth](https://unsloth.ai/docs/get-started/reinforcement-learning-rl-guide/tutorial-train-your-own-reasoning-model-with-grpo) - Beginner's Guide to transforming a model like Llama 3.1 (8B) into a reasoning model by using Unsloth...

40. [Explore large language models on Apple silicon with MLX - WWDC25](https://developer.apple.com/videos/play/wwdc2025/298/) - We'll cover how to fine-tune and run inference on state-of-the-art large language models on your Mac...

41. [FineTuning LLMs with MLX is Stupidly Easy - YouTube](https://www.youtube.com/watch?v=L9dLkeTborM) - Comments · Is MLX the best Fine Tuning Framework? · OWASP's Top 10 Ways to Attack LLMs: AI Vulnerabi...

42. [Mamba implementation in MLX! Includes inference and training.](https://www.reddit.com/r/LocalLLaMA/comments/1ac1f5f/mamba_implementation_in_mlx_includes_inference/) - This folder contains a complete MLX implementation of Mamba, which allows to train and do inference ...

43. [1. GEPA Overview - DSPy](https://dspy.ai/api/optimizers/GEPA/overview/) - GEPA is an evolutionary optimizer, which uses reflection to evolve text components of complex system...

44. [GitHub - gepa-ai/gepa: Optimize prompts, code, and more with AI ...](https://github.com/gepa-ai/gepa) - With DSPy (Recommended for AI Pipelines). The most powerful way to use GEPA for prompt optimization ...

45. [GitHub - karpathy/nanochat: The best ChatGPT that $100 can buy.](https://github.com/karpathy/nanochat) - ... model inference with KV Cache │ ├── execution.py # Allows the LLM to execute Python code as tool...

46. [Andrej Karpathy Releases 'nanochat': A Minimal, End-to-End ...](https://www.marktechpost.com/2025/10/14/andrej-karpathy-releases-nanochat-a-minimal-end-to-end-chatgpt-style-pipeline-you-can-train-in-4-hours-for-100/) - Mid-training, SFT, and tool use. After pretraining, mid-training adapts the base model to conversati...

47. [Excited to release new repo: nanochat! (it's among the most ...](https://x.com/karpathy/status/1977755427569111362) - - Efficient inference the model in an Engine with KV cache, simple prefill/decode, tool use (Python ...

48. [Introducing nanochat: The best ChatGPT that $100 can buy. #1](https://github.com/karpathy/nanochat/discussions/1) - Our Engine class also supports tool use (of Python interpreter), which will be useful when training ...

49. [Decoding the Magic Behind Andrej Karpathy's NanoChat - LinkedIn](https://www.linkedin.com/pulse/decoding-magic-behind-andrej-karpathys-nanochat-prashant-lakhera-ypbsc) - This stage teaches the model how to format conversations with user/assistant turns, how to use tools...

50. [The Smol Training Playbook: The Secrets to Building World-Class ...](https://kingy.ai/ai/the-smol-training-playbook-the-secrets-to-building-world-class-llms-book-and-review/) - The Smol Training Playbook: The Secrets to Building World-Class LLMs – Book And Review. Curtis Pyke ...

51. [Hugging Face's 214-Page Guide to Large Language Models](https://www.linkedin.com/posts/lioralex_hugging-face-just-dropped-a-214-page-masterclass-activity-7411464598354092032-0UYb) - Hugging Face just dropped a 214-page masterclass on how to train large language models, end-to-end. ...

52. [NanoGPT 124m from scratch using a 4090 and a billion tokens of ...](https://www.reddit.com/r/LocalLLaMA/comments/1ozre2i/nanogpt_124m_from_scratch_using_a_4090_and_a/) - I was recently doing some digging into NanoGPT, Karpathy's couple years old repo to recreate GPT-2 1...

53. [LoRA - Hugging Face](https://huggingface.co/docs/peft/developer_guides/lora) - LoRA is low-rank decomposition method to reduce the number of trainable parameters which speeds up f...

54. [Fine-Tuning OpenAI's GPT-OSS 20B: A Practitioner's Guide to LoRA ...](https://pub.towardsai.net/fine-tuning-openais-gpt-oss-20b-a-practitioner-s-guide-to-lora-on-moe-models-920171bf5258) - The expert FFN layers are the core of the MoE routing mechanism. Modifying them with LoRA risks “exp...

