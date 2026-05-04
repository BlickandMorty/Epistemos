# Epistemos Custom Model Blueprint: Non-Transformer SSM Architecture via MOHAWK Distillation

## The Big Picture

This document captures the complete vision for building a custom, non-transformer language model for Epistemos — from the theoretical motivation through cloud GPU training to local deployment on Apple Silicon. This is not about fine-tuning an existing model. This is about creating an entirely new model architecture that is purpose-built for on-device knowledge management and fundamentally outperforms transformer-based models in the deployment environment Epistemos targets.

### Why Not Transformers

Transformers have a structural problem for on-device knowledge management:

1. **Quadratic attention complexity** — Every token attends to every other token. A 4K context costs 16M attention computations. An 8K context costs 64M. This means inference slows down proportionally as context grows — exactly the wrong behavior for a note-taking app where the user's context gets longer and longer during a work session.

2. **Growing KV-cache** — Transformers must store key-value pairs for every token in the context window. On a 16GB MacBook, this memory consumption directly competes with the app itself, the OS, and the user's other applications. The KV-cache grows linearly with context length and cannot be compressed without quality loss.

3. **Memory-bandwidth bound generation** — On Apple Silicon, token generation speed is determined by how fast weights can be read from unified memory. Transformers waste bandwidth reading the full KV-cache at every generation step.

### The Alternative: State Space Models (Mamba)

State Space Models (SSMs) like Mamba solve all three problems:

1. **Linear time complexity** — Processing scales linearly with sequence length, not quadratically. A 4K context takes the same per-token time as an 8K context.

2. **Constant memory** — Instead of a growing KV-cache, SSMs maintain a fixed-size recurrent state. Memory usage does not increase as the context grows. On a 16GB MacBook, this means the model's memory footprint stays constant regardless of how long the user's work session is.

3. **Higher throughput on Apple Silicon** — Because there's no KV-cache to read, the model uses memory bandwidth more efficiently. Cartesia's Llamba-8B (a Mamba-2 model) demonstrated up to 12x higher token throughput than Llama-3.1-8B on an NVIDIA H100, and showed near-constant memory usage on Apple Silicon M3 Pro at 4-bit quantization via MLX.

### The Specific Architecture: Mamba-2 via MOHAWK Distillation

You don't need to train a Mamba model from scratch (that would require trillions of tokens and massive GPU clusters). Instead, you use **architecture distillation** — taking a pretrained transformer model and converting it into a Mamba-2 architecture while preserving its knowledge.

**MOHAWK** (Matrix Orientation, Hidden-state Alignment, Weight-transfer Knowledge distillation) is the framework that makes this possible. Published by Cartesia (the creators of Llamba), MOHAWK distills transformer knowledge into Mamba-2 with 1000x less training data than pretraining from scratch.

---

## The End-to-End Pipeline

### Phase 1: Choose Your Teacher Model

The "teacher" is a large, high-quality transformer that already has the knowledge and capabilities you want. Its knowledge will be transferred into your custom Mamba-2 student.

**Recommended teachers:**
- **Llama 3.1 8B Instruct** — For the Nano-Expert tier (your primary on-device model)
- **Llama 3.1 70B Instruct** — For the final distillation stage (higher-quality knowledge transfer)

**Why these specifically:**
- Llamba (Cartesia's proof) already demonstrated successful distillation from exactly these models
- Llama 3.1 has strong instruction-following, reasoning, and tool-use capabilities
- The license (Llama Community License) permits derivative works

### Phase 2: Design Your Student Architecture

The student is your custom Mamba-2 model. Based on the Llamba architecture:

**Llamba-style architecture modifications:**
- **Alternating MLP blocks** — Interleave Llama's gated MLP components with Mamba-2 mixing layers. This reduces the number of temporal mixing layers, increasing inference throughput and reducing memory usage by 2x compared to pure Mamba-2 without MLPs.
- **Untied multi-head design** — Unlike grouped-query attention with tied embeddings, use untied multi-head structure for state-size consistency in long-context scenarios.
- **Discrete-Mamba-2 variant** — Project input matrices directly, matching the discrete nature of attention without extra overhead. Remove unnecessary normalization and activation steps that hamper alignment.

**Target model sizes:**
| Model | Parameters | Memory (4-bit) | Target Device |
|-------|-----------|----------------|---------------|
| Epistemos-Nano | 1B | ~1.5 GB | M1/M2 8GB MacBooks |
| Epistemos-Base | 3B | ~3.5 GB | M2/M3 16GB MacBooks |
| Epistemos-Pro | 8B | ~8 GB | M3/M4 32GB+ MacBooks |

### Phase 3: MOHAWK Distillation (Cloud GPU Training)

This is the computationally intensive step that runs on rented cloud GPUs. MOHAWK has three stages:

**Stage 1: Matrix Orientation (~300M-500M tokens)**
- Initialize the Mamba block's convolution layer as an identity kernel
- Configure the multiplicative skip connection to pass input unchanged (identity function)
- Align the Mamba-2 mixing layers to match the transformer's attention patterns
- This stage requires the least data and establishes the structural alignment

**Stage 2: Hidden-State Alignment (~3B-5B tokens)**
- Match intermediate hidden representations between teacher (Llama) and student (Mamba-2)
- All parameters are trained (MLP weights, normalization layers, input embedding, output head are transferred from Llama)
- Uses the same learning rate for MLP and mixing components
- This stage requires more data and establishes the representational alignment

**Stage 3: Knowledge Distillation (~5B-6.5B tokens)**
- End-to-end alignment using cross-entropy loss on the teacher's output logits
- After loss saturation with the 8B teacher, switch to distilling from the 70B teacher for remaining tokens
- This final stage produces the highest quality transfer

**Total training data: ~8-12B tokens** depending on model size (Llamba-1B used 8B tokens; Llamba-8B used 12B tokens).

**Compute requirements:**
| Model Size | Hardware | Training Time | Estimated Cost (RunPod) |
|-----------|----------|---------------|------------------------|
| 1B | 4x A100 80GB | ~2-3 days | ~$800-1,200 |
| 3B | 8x A100 80GB | ~3-4 days | ~$1,500-2,500 |
| 8B | 8x A100 80GB | ~5 days | ~$2,500-3,500 |

**Where to rent GPUs:**
- **RunPod** ($2.79/hr for H100, per-second billing, API for automation) — Best for automation via API
- **Vast.ai** (~$2.25/hr for H100, marketplace model) — Cheapest option
- **Lambda Labs** ($2.99/hr, pre-configured ML environments) — Simplest setup

**Automation approach:**
All three platforms have APIs. The entire pipeline can be scripted:
1. Script rents GPU instance via API
2. Uploads training code and data configuration
3. Starts MOHAWK distillation
4. Monitors training (Perplexity Computer can check via browser on a schedule)
5. Downloads trained weights when complete
6. Terminates instance (zero idle cost)

EzEpoch (https://ezepoch.com) is a tool that automates deployment to Vast.ai/RunPod — handles dependency installation, crash recovery, checkpoint protection, and model export.

### Phase 4: Convert and Quantize for MLX

After distillation completes on the cloud GPU:

1. **Export trained weights** — Save as safetensors format from the training script
2. **Download to Mac** — Transfer the full-precision model (~16-32GB for 8B)
3. **Convert to MLX format:**
   ```
   mlx_lm.convert \
     --hf-path ./epistemos-mamba-3b \
     --mlx-path ./epistemos-mamba-3b-4bit \
     --quantize --q-bits 4 --q-group-size 64
   ```
4. **Mixed-precision quantization** (optional, for higher quality):
   ```python
   def epistemos_quantization(layer_path, layer, model_config):
       if "lm_head" in layer_path or "embed_tokens" in layer_path:
           return {"bits": 6, "group_size": 64}  # Higher precision for head/embeddings
       elif hasattr(layer, "to_quantized"):
           return {"bits": 4, "group_size": 64}  # 4-bit for everything else
       else:
           return False
   ```
5. **Upload to HuggingFace** (optional) — For distribution via mlx-community

**Critical: Cartesia already provides optimized Mamba-2 Metal kernels for Apple Silicon and MLX integration.** This means you are NOT writing custom GPU code from scratch — the inference path already exists and is proven to work with 4-bit quantization on constrained hardware.

### Phase 5: On-Device Deployment in Epistemos

The custom Mamba-2 model slots into the exact same MLX Swift inference path that currently runs your Qwen 3.5 models:

```swift
import MLX
import MLXLMCommon
import MLXLLM

let modelId = "epistemos/epistemos-mamba-3b-4bit"  // Your custom model
let configuration = ModelConfiguration(id: modelId)
let model = try await LLMModelFactory.shared.loadContainer(configuration: configuration)

try await model.perform { context in
    let input = try await context.processor.prepare(input: UserInput(prompt: prompt))
    let params = GenerateParameters(temperature: 0.0)
    let tokenStream = try generate(input: input, parameters: params, context: context)
    for await part in tokenStream {
        print(part.chunk ?? "", terminator: "")
    }
}
```

The user-facing experience is identical. The difference is under the hood:
- Constant memory regardless of context length
- Higher token throughput
- Faster time-to-first-token for long contexts
- The same Knowledge Fusion features (QLoRA adapters, KTO preference learning, autoresearch loop) work identically on the Mamba-2 base

### Phase 6: Local Fine-Tuning (LoRA Adapters on the Custom Model)

LoRA adapters work on any architecture MLX supports, including Mamba-2. Your users' "Train on My Vault" feature works the same way:

1. User selects vault → app generates JSONL via instruction backtranslation
2. QLoRA trains a LoRA adapter on top of the quantized Mamba-2 base
3. Adapter is saved as a .safetensors skill pack
4. Hot-swapped at inference time (NEVER fused permanently)

The hyperparameters change slightly because Mamba-2 doesn't have traditional attention projections (q/k/v/o). Instead, LoRA targets:
- **For knowledge absorption:** Mamba-2 mixing layers + MLP layers (gate_proj, up_proj, down_proj), rank=32
- **For style cloning:** Mamba-2 mixing layers only, rank=8

### Phase 7: Autoresearch Self-Improvement

The Karpathy autoresearch loop (from `/Users/Downloads/autoresearch-master`) applies identically:

1. Agent proposes a change (different LoRA config, different data mix, different curriculum order)
2. Trains with fixed time budget (~5 minutes)
3. Evaluates against held-out metric (Direct + Indirect Probing scores)
4. Keeps if improved (git commit), discards if not (git reset)
5. Repeats overnight (~100 experiments while you sleep)

---

## The Three-Tier Model Stack

This is the complete Epistemos model hierarchy:

| Tier | Architecture | Parameters | Memory | Purpose | Where It Runs |
|------|-------------|-----------|--------|---------|--------------|
| **Nano-Expert** | Custom Mamba-2 (distilled from Llama 3.2 1B) | 1B | ~1.5 GB (4-bit) | Ghost text, paragraph summarization, intent detection, fast completions | All Macs (8GB+) |
| **Base-Expert** | Custom Mamba-2 (distilled from Llama 3.1 8B) | 3B | ~3.5 GB (4-bit) | Map-Reduce synthesis, knowledge graph reasoning, multi-document analysis | 16GB+ Macs |
| **Pro-Expert** | Custom Mamba-2 (distilled from Llama 3.1 8B with 70B teacher) | 8B | ~8 GB (4-bit) | Deep multi-hop reasoning, complex tool orchestration, autoresearch loop evaluation | 32GB+ Macs |

All three tiers:
- Use the same MLX Swift inference path
- Support the same LoRA adapter ecosystem (knowledge, style, tool adapters)
- Have constant memory regardless of context length (no KV-cache)
- Were trained via MOHAWK distillation (not from scratch)
- Can be further personalized via on-device QLoRA fine-tuning

---

## How This Connects to Knowledge Fusion

The Knowledge Fusion feature (described in `epistemos-knowledge-fusion-claude-code-prompt.md`) works at two levels:

### Level 1: Today (Transformer Base)
Currently using Qwen 3.5 4B as the base model. Knowledge Fusion works via:
- QLoRA fine-tuning with Knowledge/Style profiles
- KTO preference alignment from accept/reject feedback
- Adapter hot-swapping and MoLoRA routing
- Autoresearch self-improvement loop

### Level 2: Future (Custom Mamba-2 Base)
After training the custom model, Knowledge Fusion upgrades:
- Same adapter infrastructure, better base model
- Constant memory means longer work sessions without degradation
- Higher throughput means faster training iterations (autoresearch does more experiments per night)
- No KV-cache means the autoresearch evaluation loop runs faster on long contexts
- LoRA targets shift from attention projections (q/k/v/o) to Mamba mixing layers

**The transition is seamless for the user.** They don't know or care whether the base is a transformer or SSM. They click "Train on My Vault" and it works. The only visible change: everything is faster and the model handles longer contexts without slowing down.

---

## The Visual Big Picture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    EPISTEMOS MODEL ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  CLOUD (One-Time)                    ON-DEVICE (Continuous)          │
│  ─────────────────                   ────────────────────            │
│                                                                      │
│  ┌─────────────────┐                 ┌───────────────────────────┐  │
│  │ Llama 3.1 70B   │ ──MOHAWK───▶   │  Custom Mamba-2 Base      │  │
│  │ (Teacher Model)  │  Distillation  │  (1B / 3B / 8B, 4-bit)   │  │
│  │ on rented GPUs   │                │  Constant memory, linear  │  │
│  │ ~5 days, ~$3K    │                │  complexity, MLX native    │  │
│  └─────────────────┘                 └───────────┬───────────────┘  │
│                                                   │                  │
│                                      ┌────────────┼────────────┐    │
│                                      │            │            │    │
│                                      ▼            ▼            ▼    │
│                              ┌──────────┐  ┌──────────┐  ┌───────┐ │
│                              │Knowledge │  │ Style    │  │ Tool  │ │
│                              │ Adapter  │  │ Adapter  │  │Adapter│ │
│                              │ (r=32)   │  │ (r=8)    │  │(r=16) │ │
│                              │ QLoRA    │  │ QLoRA    │  │QLoRA  │ │
│                              └────┬─────┘  └────┬─────┘  └───┬───┘ │
│                                   │             │             │     │
│                                   └──────┬──────┘             │     │
│                                          │                    │     │
│                                          ▼                    ▼     │
│                                  ┌───────────────────────────────┐  │
│                                  │       MoLoRA Router           │  │
│                                  │  Per-token adapter selection   │  │
│                                  │  Hot-swap only, never fuse    │  │
│                                  └──────────────┬────────────────┘  │
│                                                 │                   │
│                                                 ▼                   │
│                                  ┌───────────────────────────────┐  │
│                                  │     INFERENCE OUTPUT           │  │
│                                  │  Ghost text, summaries, tools  │  │
│                                  └──────────────┬────────────────┘  │
│                                                 │                   │
│                              ┌──────────────────┴──────────────┐   │
│                              │                                  │   │
│                              ▼                                  ▼   │
│                     ┌──────────────┐                ┌──────────────┐│
│                     │ User Accepts │                │ User Rejects ││
│                     │  (positive)  │                │  (negative)  ││
│                     └──────┬───────┘                └──────┬───────┘│
│                            │                               │        │
│                            └───────────┬───────────────────┘        │
│                                        │                            │
│                                        ▼                            │
│                            ┌───────────────────────┐                │
│                            │   KTO Preference       │                │
│                            │   Alignment Loop       │                │
│                            │   (overnight batch)    │                │
│                            └───────────┬───────────┘                │
│                                        │                            │
│                                        ▼                            │
│                            ┌───────────────────────┐                │
│                            │   Autoresearch Loop    │                │
│                            │   (Karpathy pattern)   │                │
│                            │   Propose → Train →    │                │
│                            │   Evaluate → Keep/     │                │
│                            │   Discard → Repeat     │                │
│                            └───────────────────────┘                │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                         USER-FACING FEATURES                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  "Train on My Vault"     → Generates JSONL → QLoRA → Knowledge      │
│                             Adapter saved as .safetensors            │
│                                                                      │
│  "Write Like Me"         → Extracts style from writing samples →     │
│                             QLoRA (r=8, attention-only) → Style      │
│                             Adapter                                  │
│                                                                      │
│  "Learn These Tools"     → Parses skill database → Generates tool    │
│                             call training data → QLoRA → Tool        │
│                             Adapter (with negative examples to       │
│                             prevent forgetting existing tools)        │
│                                                                      │
│  "Voice Clone"           → 3-6 sec audio → Qwen3-TTS / NeuTTS Air  │
│                             instant clone (no training needed)        │
│                                                                      │
│  Adapter Marketplace     → Share/download .safetensors skill packs   │
│                             Community-contributed domain adapters     │
│                                                                      │
│  Continuous Improvement  → Accept/reject → KTO overnight →           │
│                             Autoresearch experiments → model gets     │
│                             better while you sleep                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Key Technical References

| Technology | Purpose | Source |
|-----------|---------|--------|
| **Mamba-3** | Latest SSM architecture with complex-valued state tracking | https://arxiv.org/abs/2603.15569 (ICLR 2026) |
| **MOHAWK** | Architecture distillation framework (Transformer → Mamba-2) | https://arxiv.org/abs/2408.10189 |
| **Llamba** | Proof that MOHAWK works at scale (1B, 3B, 8B models) | https://arxiv.org/html/2502.14458v1 |
| **Mamba-in-Llama** | Hybrid distillation with partial attention retention | https://arxiv.org/abs/2408.15237 (NeurIPS 2024) |
| **MLX** | Apple's ML framework for Apple Silicon | https://github.com/ml-explore/mlx |
| **MLX Swift** | Swift API for on-device inference | https://github.com/ml-explore/mlx-swift |
| **mlx-tune** | Fine-tuning library (SFT, DPO, KTO, GRPO) on Apple Silicon | https://github.com/ARahim3/mlx-tune |
| **MoLoRA** | Per-token adapter routing for composable specialization | https://arxiv.org/abs/2603.15965 |
| **Cartesia Mamba-2 Metal kernels** | Optimized Mamba-2 inference on Apple Silicon via Metal | https://cartesia.ai/blog/llamba-distillation |
| **RunPod API** | GPU rental automation for training jobs | https://www.runpod.io |
| **Vast.ai** | Cheapest GPU marketplace | https://vast.ai |
| **EzEpoch** | Automated model training deployment to Vast.ai/RunPod | https://ezepoch.com |
| **Karpathy Autoresearch** | Autonomous experiment loop pattern | https://github.com/karpathy/autoresearch |
| **ReDrafter** | Apple's speculative decoding for MLX (2.3x speedup) | https://machinelearning.apple.com/research/recurrent-drafter |
| **MSSR** | Experience replay for continual learning (prevents forgetting) | https://arxiv.org/abs/2603.09892 |

---

## What Changes When You Have The Custom Model

| Aspect | Current (Qwen 3.5 4B Transformer) | Future (Custom Mamba-2 3B) |
|--------|-----------------------------------|---------------------------|
| **Context scaling** | Slows with longer context (quadratic attention) | Constant speed regardless of context length |
| **Memory usage** | KV-cache grows with context (~2GB at 8K tokens) | Fixed state (~100MB regardless of context) |
| **Token throughput** | ~50-70 tok/s on M4 Max | Expected ~100-150+ tok/s (12x improvement per Llamba benchmarks) |
| **Time-to-first-token** | Increases with prompt length | Nearly constant |
| **LoRA targets** | q_proj, k_proj, v_proj, o_proj (attention) | Mamba-2 mixing layers (SSM projections) |
| **Knowledge Fusion** | Works (current prompt) | Works identically, faster training iterations |
| **Adapter compatibility** | Qwen-specific adapters | Epistemos-specific adapters (your own ecosystem) |
| **Competitive moat** | Using same model as everyone else | Custom architecture nobody else has |

---

## Timeline and Dependencies

1. **Today** — Ship Knowledge Fusion on current Qwen 3.5 4B base (all the adapter infrastructure, KTO, autoresearch)
2. **Week 1-2** — Write MOHAWK distillation scripts, prepare training data configuration
3. **Week 2-3** — Rent GPUs, run distillation for Epistemos-Nano (1B), validate quality
4. **Week 3-4** — Run distillation for Epistemos-Base (3B), convert to MLX, validate
5. **Week 4-5** — Swap base model in Epistemos, retrain LoRA targets for Mamba-2 layers, verify all adapters work
6. **Week 5-6** — Run distillation for Epistemos-Pro (8B) if hardware budget allows
7. **Ongoing** — Autoresearch loop continuously improves all three tiers overnight

The key insight: **build the adapter infrastructure first (Knowledge Fusion), swap the base model later.** The user-facing features are identical either way. The Mamba-2 base just makes everything faster and more memory-efficient.
