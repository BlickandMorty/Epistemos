# Epistemos Omega — Model Training Guide

## Architecture: Hybrid Mamba-Attention (NOT Pure Mamba-2)

The Google Deep Research paper is definitive: pure Mamba-2 has "reasoning drift" and JSON formatting failures. Epistemos uses **Hybrid Mamba-Attention** with a 3:1 ratio (75% Mamba, 25% Attention layers).

- **Mamba layers**: linear-time sequence efficiency, constant memory
- **Attention layers**: global anchors for exact token retrieval, strict JSON schema adherence
- **Reference**: NVIDIA Nemotron 3 Super (Mamba-in-Llama pattern, NeurIPS 2024)

## Model Tiers

| Tier | Params | Memory (4-bit) | Training | Cost |
|------|--------|----------------|----------|------|
| Epistemos-Nano | 1B | ~1.5 GB | Cloud + on-device QLoRA | ~$800-1,200 |
| Epistemos-Base | 3B | ~3.5 GB | Cloud + on-device QLoRA | ~$1,500-2,500 |
| Epistemos-Pro | 8B | ~8 GB | Cloud only (inference on M2 Pro) | ~$2,500-3,500 |

## Training Data Composition (40/20/20/20)

| Category | % | Source |
|----------|---|--------|
| Synthetic Tool-Call Examples | 40% | ODIA traces from omega-mcp execution logs |
| General Language & Code | 20% | Open datasets (SlimPajama, StarCoder) |
| Multi-Step Reasoning Traces | 20% | Chain-of-thought with drift penalization |
| macOS-Specific Automation | 20% | AppleScript, JXA, AX tree JSON examples |

## Cloud GPU Training (MOHAWK Distillation)

### Hardware Requirements

| Model | GPUs | Time | Platform | Cost |
|-------|------|------|----------|------|
| 1B | 4x A100 80GB | ~2-3 days | RunPod | ~$800-1,200 |
| 3B | 8x A100 80GB | ~3-4 days | RunPod | ~$1,500-2,500 |
| 8B | 8x A100 80GB | ~5 days | RunPod | ~$2,500-3,500 |

### GPU Rental Platforms

- **RunPod** ($2.79/hr H100, per-second billing, API automation) — https://runpod.io
- **Vast.ai** (~$2.25/hr H100, marketplace, cheapest) — https://vast.ai
- **Lambda Labs** ($2.99/hr, pre-configured ML envs, simplest) — https://lambdalabs.com
- **EzEpoch** (automates deployment to Vast.ai/RunPod) — https://ezepoch.com

### MOHAWK 3-Stage Distillation

1. **Matrix Orientation** (~500M tokens): Align Mamba layer matrices to teacher attention patterns
2. **Hidden-State Alignment** (~5B tokens): Match intermediate representations
3. **Knowledge Distillation** (~6.5B tokens): Standard KD with teacher forcing

**Teacher model**: Llama 3.1 8B → distill into Hybrid Mamba-Attention student

### Config Template

```yaml
model:
  architecture: hybrid_mamba_attention
  mamba_ratio: 0.75  # 3:1 Mamba-to-Attention
  attention_ratio: 0.25
  total_layers: 32  # for 3B model
  mamba_layers: 24
  attention_layers: 8

distillation:
  method: mohawk
  teacher: meta-llama/Llama-3.1-8B-Instruct
  stages:
    - name: matrix_orientation
      tokens: 500_000_000
      learning_rate: 1e-4
    - name: hidden_state_alignment
      tokens: 5_000_000_000
      learning_rate: 5e-5
    - name: knowledge_distillation
      tokens: 6_500_000_000
      learning_rate: 2e-5

quantization:
  method: mixed_precision
  lm_head: 6bit
  embed_tokens: 6bit
  default: 4bit
```

### Post-Distillation Pipeline

```bash
# 1. Convert to MLX format
mlx_lm.convert --hf-path ./epistemos-3b-hybrid --mlx-path ./epistemos-3b-mlx

# 2. Mixed-precision quantization
mlx_lm.convert --hf-path ./epistemos-3b-mlx -q \
  --q-group-size 64 --q-bits 4 \
  --mlx-path ./epistemos-3b-mlx-4bit

# 3. Upload to HuggingFace
huggingface-cli upload epistemos/epistemos-base-3b-4bit ./epistemos-3b-mlx-4bit
```

## On-Device QLoRA Training (M2 Pro 18GB)

### Hyperparameters by Adaptation Type

| Type | Target Layers | Rank | Alpha | Examples |
|------|--------------|------|-------|----------|
| Knowledge | attention + MLP (gate/up/down_proj) | 32 | 64 | 3,000-10,000 |
| Style | attention only (q/k/v/o projections) | 8 | 16 | 100-500 |
| Tool Calling | attention + mixing layers | 16 | 32 | 1,000-3,000 |

### Training Performance

| Chipset | Memory BW | Time (1000 examples, r=32) | Peak Memory |
|---------|-----------|----------------------------|-------------|
| M2 Pro 18GB | 200 GB/s | ~45 min/epoch | ~11.5 GB |
| M3 Max 64GB | 400 GB/s | ~22 min/epoch | 11.5 GB |

### Critical Rules

- **NEVER fuse adapters** into base model (throughput collapse: 21→7 tok/s)
- **Hot-swap only** via MoLoRA per-token routing
- **Experience replay**: interleave 10% general data to prevent catastrophic forgetting
- **CSI safeguard**: halt if Cluster Separation Index drops below 0.3

## Autoresearch Loop (Overnight)

Runs ~100 experiments while sleeping:
1. Propose variation (rank, learning rate, data mix)
2. Train 5 minutes
3. Evaluate val_bpb (bits per byte)
4. If improved → keep adapter. If degraded → discard.

Budget: 30 min per experiment, 35 min hard timeout.

## RunPod Automation Script

```bash
#!/bin/bash
# 1. Rent GPU
INSTANCE_ID=$(runpodctl create pod --name epistemos-train \
  --gpuType "NVIDIA A100 80GB" --gpuCount 4 \
  --imageName runpod/pytorch:2.1.0-py3.10-cuda12.1.0 \
  --volumeSize 200 --ports "8888/http" | jq -r '.id')

# 2. Upload training code + data
runpodctl send $INSTANCE_ID ./training_code.tar.gz

# 3. Start distillation
runpodctl exec $INSTANCE_ID -- bash -c "cd /workspace && tar xzf training_code.tar.gz && python train_mohawk.py"

# 4. Monitor (poll every 5 min)
while true; do
  STATUS=$(runpodctl exec $INSTANCE_ID -- cat /workspace/status.json | jq -r '.stage')
  echo "Current stage: $STATUS"
  [ "$STATUS" = "complete" ] && break
  sleep 300
done

# 5. Download weights
runpodctl receive $INSTANCE_ID /workspace/output ./epistemos-3b-hybrid

# 6. Terminate
runpodctl remove pod $INSTANCE_ID

# 7. Convert to MLX locally
mlx_lm.convert --hf-path ./epistemos-3b-hybrid --mlx-path ./epistemos-3b-mlx -q
```

## Anti-Loop Training (Thinking Loop Prevention)

Models with `<think>` chain-of-thought can enter repetitive reasoning loops.
Mamba's SSM state decays exponentially (helping break very long loops), but the
25% attention layers can sustain short loops via their KV cache.

### Training-Side Fixes
- **Max think tokens**: Cap `<think>` blocks at 512 tokens in all training data.
  Prune any ODIA trace where think block exceeds this or contains >3 repeated phrases.
- **Repetition penalty examples**: Include training examples where the model
  correctly exits thinking after 2-3 reasoning steps (not 10+).
- **Diverse exit patterns**: Train on examples that exit `<think>` via different
  triggers — confidence threshold, tool call ready, answer found, max budget hit.

### Inference-Side Fixes (in LogitProcessor)
- **Sliding window detector**: Compare last 64 tokens against previous 64.
  If >50% n-gram overlap (trigram), force-emit `</think>` token.
- **Hard token budget**: After 512 think tokens, mask all tokens except `</think>`
  to negative infinity in the logit processor.
- **Exponential repetition penalty**: Track token frequency in a sliding window.
  Apply penalty `logit -= freq * alpha` where alpha increases with window position.

### Why Mamba Helps (but doesn't solve it)
- SSM hidden state decays exponentially — early loop content naturally fades
- But attention layers (every 4th) have perfect recall within their window
- The hybrid architecture means loops are shorter-lived than pure transformers
  but not eliminated — inference-side detection is still required
