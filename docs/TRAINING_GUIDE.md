# Epistemos Omega — Model Training Guide

> **Index status**: CANONICAL-RESEARCH — Quick-reference training guide — Hybrid Mamba/Attention 75/25 + 24-layer stack + model tiers; defers to NANO-MASTER-TRAINING-GUIDE for deep execution.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.



> **READ FIRST**: `docs/NANO-MASTER-TRAINING-GUIDE.md` is the deep-dive execution manual.
> This file is the quick-reference. When in doubt, the Master Guide wins.

## Architecture: Hybrid Mamba/Attention (NOT Pure SSM)

75% Mamba / 25% Attention. The ratio is correct regardless of Mamba generation.

- **Mamba layers**: linear-time sequence efficiency, constant memory
- **Attention layers**: exact token retrieval, JSON schema enforcement, multi-turn anchoring
- **Deploy on MLX/Metal GPU, NOT ANE** — Mamba selective scan cannot run on ANE
- Expected inference: 70-95 tok/s on M4 Max (4-bit quantized)

**Mamba-2 → Mamba-3 migration:** Build with Mamba-2 now (tooling validated). Swap to Mamba-3 layers in Month 2-3 when MOHAWK-3 recipe and MLX support land. The 6 attention layers never change — they do exact retrieval that no SSM can replace. See Master Guide for full migration plan.

### Layer Placement (24-layer stack, non-negotiable)

| Layers | Type | Role |
|--------|------|------|
| 1-4 | Mamba-2 | Initial sequence compression |
| 5 | Attention | Early retrieval anchor |
| 6-10 | Mamba-2 | Mid-level context integration |
| 11 | Attention | Schema enforcement (JSON structure) |
| 12-17 | Mamba-2 | Deep context distillation |
| 18-19 | Attention | Final retrieval (current AX state + app identity) |
| 20-24 | Mamba-2 | Output formation |

## Model Tiers

| Tier | Params | Memory (4-bit) | Training | Cost |
|------|--------|----------------|----------|------|
| Epistemos-Nano | 1B | ~1.5 GB | Cloud + on-device QLoRA | ~$150-300 |
| Epistemos-Base | 3B | ~3.5 GB | Cloud + on-device QLoRA | ~$1,500-2,500 |

## The Five Pillars of Training

### Pillar 1: MOHAWK Distillation (Week 1)

3-stage progressive distillation from Llama 3.2 1B teacher → hybrid student.

**Validated hyperparameters:**
```
Learning rate: ≤2e-4 (NOT 4e-4 — triggers NaN)
Optimizer: AdamW β=(0.9, 0.98)
Precision: BF16 training, FP32 parameter storage
Warmup: 500 steps
Schedule: WSD (Warmup-Stable-Decay), NOT cosine
  - Stable phase: 80% of total steps at peak LR
  - Decay phase: 20% — inject highest-quality traces here
Stage 3 loss: α=1.0 KL(teacher, student) + β=0.1 CE(student, labels)
Token budget: 8B tokens (D:N ratio = 8)
Gradient clip: norm 1.0
```

**WSD advantage**: Pre-decay checkpoints are reusable. New data → continue from stable checkpoint.

**Teacher**: Llama 3.2 1B Instruct (NOT 8B — same-scale distillation for Nano)

```bash
cd Epistemos/KnowledgeFusion/MOHAWK
./runpod_train_full.sh nano
```

### Pillar 2: App-Specific Meta-Training (THE COMPETITIVE MOAT)

A model trained on its own app's code, UI states, and workflows **recalls** mappings from weights: sub-1ms. No cloud model can replicate this.

**4 Layers of App Self-Knowledge:**

**Layer 0 — Code Graph Model (CGM)**
- Parse Swift ASTs → hierarchical graph: `AppDelegate → ViewController → UIButton → @IBAction → state`
- Node types: SwiftUI views, @Observable models, Rust structs, MCP tools, SQLite tables
- Edge types: calls, conformsTo, memberOf, UniFFI bridge, publishes/subscribes
- Output: `app_code_graph.json`

**Layer 1 — Xcode Symbol Graph → QA Pairs**
- Forward: "User wants to create a note" → `{ class: 'NoteCoordinator', method: 'createNote()' }`
- Reverse: "What does OmegaPlanningService.generatePlan() do?" → description
- Cross-file context is critical — button handler + data model + navigation coordinator
- Output: `app_symbol_qa.jsonl`

**Layer 2 — AX Atlas with Differential Snapshots**
- Capture pre-action AX tree → execute action → wait 150ms → capture post-action AX tree
- Compute structural diff (added/removed elements)
- Include error states: dialogs, permissions, spinners
- Output: `app_atlas_differential.jsonl`

**Layer 3 — SFT → RLAIF Trajectories**
- 1,000 multi-turn trajectories via Claude Sonnet (3-8 steps each)
- Format: [OBSERVE] → [REASON] → [ACT] → [RESULT] → [DONE]
- 464 verification pairs for RLAIF judge scoring
- Output: `app_sft_trajectories.jsonl`

### Pillar 3: General macOS Device Control

**Training Data Composition (40/20/20/10/10):**

| Category | % | Source |
|----------|---|--------|
| Tool-calling examples (AXPress actions) | 40% | Synthetic traces + ODIA logs |
| General instruction-following | 20% | SmolTalk, MMLU-aux (prevents forgetting) |
| **Epistemos app-specific traces** | 20% | CGM, AX atlas, symbol QA, trajectories |
| Negative examples (when NOT to call a tool) | 10% | Hammer-style irrelevance augmentation |
| Error recovery examples | 10% | Intentionally injected failures |

**The 20% Epistemos allocation is sacred.** Below 15% = reflexes degrade. Above 25% = general capability suffers.

**AX Tree Format** (sparse indented text, saves 40-60% tokens vs JSON):
```
[Safari] (focused)
  [Window: arxiv.org] (frontmost)
    [Toolbar]
      [TextField: Address Bar] value="https://arxiv.org"
      [Button: Reload]
    [ScrollArea]
      [StaticText] value="Subjects"
```

**Tool-calling training tricks:**
- Function masking (Hammer, ICLR 2025): randomly mask 33% of function/param names
- BalanceSFT SSB loss: reweight to prevent CoT tokens dominating tool-call tokens
- Randomize tool list order in every example (prevent position memorization)
- Constrained decoding: Outlines (`pip install "outlines[mlxlm]"`) for JSON enforcement

### Pillar 4: Reinforcement Learning

**GRPO with 6-component decomposed reward:**

| Component | Weight | Signal |
|-----------|--------|--------|
| Format correctness | 0.10 | Parseable valid JSON |
| Element identification | 0.30 | Correct UI element targeted |
| Action type correctness | 0.20 | Correct verb (click/type/scroll/press) |
| Parameter correctness | 0.20 | Correct text input, coordinates, modifiers |
| State progression | 0.10 | Environment moved toward goal |
| Task completion | 0.10 | Final binary success |

```
Group size: 8
Learning rate: 3e-6 to 5e-6, cosine decay, 10% warmup
Gradient clipping: 0.1
Clip ratio ε: 0.2
Temperature: 0.7-1.0
Monitor entropy — if monotonically decreasing, model is collapsing
```

**KTO for nightly binary feedback** (success/fail from ODIA): `beta=0.1, lr=1e-5, epochs=1`

### Pillar 5: Continuous Self-Improvement (Nightly Flywheel)

```
2:00 AM  COLLECT — gather today's execution traces
2:15 AM  FILTER — Superfiltering IFD scoring (keep top 15%)
2:30 AM  SORT — CAMPUS multi-axis difficulty ordering
2:45 AM  COMPOSE — 40/20/20/20 data mix
3:00 AM  TRAIN — mlx_lm.lora --iters 200 --lora-rank 16 --lr 3e-4
3:30 AM  EVALUATE — BFCL holdout (100 tasks) + Epistemos holdout (50 tasks)
3:45 AM  DEPLOY — if score > baseline + 0.5%, deploy; else rollback
MONTHLY  MERGE — fuse adapter into base, retrain fresh adapters
```

**Anti-forgetting safeguards:**
- LoRA-only nightly updates (NEVER touch base weights)
- CSI Safeguard: loss improves >3% without benchmark improvement → Goodhart → human review
- Version-triggered adapter regeneration on every Epistemos build

## Quantization — Hybrid-Aware Mixed Precision

| Component | Precision | Why |
|-----------|-----------|-----|
| Mamba-2 SSM (A, B, C, dt) | FP16 | Cumulative product stability |
| Mamba-2 conv1d kernel | FP16 | Small but accuracy-critical |
| Mamba-2 in_proj, out_proj | INT4 | High redundancy, memory savings |
| Attention Q,K,V projections | INT4 | Standard aggressive quant |
| MLP gate/up/down | INT4 | Standard |
| Output logit layer | FP16 | Accuracy-critical |
| Embedding table | FP16 | Lookup precision |

## On-Device QLoRA (Apple Silicon)

| Type | Target Layers | Rank | Alpha | Examples |
|------|--------------|------|-------|----------|
| Knowledge | attention + MLP (gate/up/down_proj) | 32 | 64 | 3,000-10,000 |
| Style | attention only (q/k/v/o projections) | 8 | 16 | 100-500 |
| Tool Calling | attention + mixing layers | 16 | 32 | 1,000-3,000 |
| Nightly ODIA | all linear layers | 16 | 32 | 200-500 |

**NEVER fuse adapters into base model** (throughput collapse). Hot-swap via MoLoRA routing.

## Training Schedule

| Week | Activity | Output |
|------|----------|--------|
| 1 | MOHAWK Stage 1-3 from Llama 3.2 1B | `mohawk_nano_base` |
| 2 | Build CGM + AX atlas + symbol QA | App-specific training data |
| 3 | 50K general traces + 1K Epistemos trajectories | `axpress_general.jsonl` |
| 4 | Superfilter → CAMPUS sort → SFT via mlx_lm.lora | `nano_axpress_v1.lora` |
| 5 | GRPO with decomposed reward | Policy-improved adapter |
| 6 | RLAIF on Epistemos trajectories | App-aware adapter |
| 7 | Constrained decoding + end-to-end eval | Production-ready model |
| 8+ | Nightly flywheel live | Continuously improving |

## RunPod Commands

```bash
# Start Nano training
cd Epistemos/KnowledgeFusion/MOHAWK
./runpod_train_full.sh nano

# Monitor
POD_ID=$(cat .last_pod_id)
runpodctl pod ssh $POD_ID --command 'tail -20 /workspace/train.log'

# Download trained model
runpodctl pod ssh $POD_ID --command 'tar czf /workspace/model.tar.gz mlx_model/'

# Stop billing
runpodctl pod stop $POD_ID
```

## Anti-Loop Training (Thinking Loop Prevention)

- **Max think tokens**: Cap `<think>` blocks at 512 tokens in training data
- **Sliding window detector**: >50% trigram overlap in last 64 tokens → force `</think>`
- **Hard budget**: After 512 think tokens, mask all except `</think>` to -inf
- Mamba SSM state decays exponentially (helps break loops) but attention layers sustain them

## Training Anti-Patterns (validated failure modes)

1. Token-level imbalance → SSB loss reweighting
2. Tool sequence position overfitting → randomize tool list order
3. No negative examples → 10% irrelevance-augmented data
4. Cross-file blindness → CGM code graph
5. AX tree stale reads → 150ms sleep after navigation
6. Hard distribution cutoffs → gradual transitions
7. Homogeneous schemas → include 3000+ diverse APIs from xLAM
8. Version drift without adapter updates → mandatory post-build generation

## Research References

For deep-dive details, read these in order:
1. `docs/NANO-MASTER-TRAINING-GUIDE.md` — THE execution manual (5 pillars, all scripts)
2. `@/Users/jojo/Downloads/Legendary Nano Model...` — Niche scripts and pipelines
3. `@/Users/jojo/Downloads/App-Specific Training...` — Multi-scale model family
4. `@/Users/jojo/Downloads/Fine-Tuning LLMs For App UI.md` — UI-specific fine-tuning
5. `@/Users/jojo/Downloads/On-Device Knowledge Fusion Research Roadmap.md` — Full roadmap
6. `@/Users/jojo/Downloads/Epistemos Omega — Dual-Brain...` — Mirror-SD, ANE benchmarks
