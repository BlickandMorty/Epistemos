# Epistemos Omega — Research Prompts
> Use these prompts with Google Deep Research, Perplexity, or Claude to resolve open research stops.
> Each prompt is self-contained with full context about what Epistemos needs.
> Last updated: 2026-03-25

---

## R10: Cartesia Metal Kernels for Mamba-2 on Apple Silicon

### Context
We are building Epistemos, a macOS-native AI app that will run a custom Mamba-2 hybrid model (75% Mamba-2 layers + 25% attention layers, distilled via MOHAWK from Llama). The model is trained on cloud GPUs using PyTorch + `mamba-ssm`, producing standard PyTorch checkpoints. We need to run inference locally on Apple Silicon (M2 Pro 18GB) via either MLX or CoreML.

The critical gap: Mamba-2's selective state space (S6) scan operation is NOT a standard transformer op. `mlx-lm` and CoreML natively support transformer attention + MLP blocks but NOT the Mamba-2 selective scan. We need custom Metal kernels or a framework that provides them.

### Research Prompt

```
I need to run Mamba-2 (state space model) inference on Apple Silicon (M2 Pro, 18GB RAM) 
for a macOS-native app. The model is a hybrid: 75% Mamba-2 layers + 25% standard 
attention layers, trained with PyTorch mamba-ssm package.

Research the following:

1. **Cartesia AI Edge** (https://github.com/cartesia-ai/edge):
   - Does it provide Metal/MLX kernels for Mamba-2 selective scan?
   - Can it load PyTorch Mamba-2 checkpoints?
   - Does it run on Apple Silicon? What's the inference speed (tok/s)?
   - Is it production-ready or research-only?

2. **MLX Mamba support** (https://github.com/ml-explore/mlx-examples):
   - Does `mlx-lm` support Mamba-2 models natively?
   - Search the repo for "mamba", "ssm", "state space", "s6", "selective scan"
   - If not native, can a custom MLX op implement the selective scan?
   - Reference: the MLX selective scan would need to implement:
     ```python
     # Mamba-2 selective scan (simplified)
     def selective_scan(x, dt, A, B, C, D):
         # x: (batch, seq_len, d_inner)
         # dt: (batch, seq_len, d_inner) - data-dependent step sizes
         # A: (d_inner, d_state) - state transition
         # B: (batch, seq_len, d_state) - input projection
         # C: (batch, seq_len, d_state) - output projection
         h = zeros(batch, d_inner, d_state)
         outputs = []
         for t in range(seq_len):
             dA = exp(dt[:, t] * A)  # discretize
             dB = dt[:, t] * B[:, t]  # discretize
             h = dA * h + dB * x[:, t]  # state update
             y = (h @ C[:, t].T) + D * x[:, t]  # output
             outputs.append(y)
         return stack(outputs, dim=1)
     ```
   - This sequential scan is the bottleneck — can it be parallelized via 
     prefix-sum (Blelloch scan) on Metal?

3. **Jamba / Zamba models on MLX**:
   - Have any Mamba-hybrid models been ported to MLX already?
   - Check: ai21labs/Jamba, Zyphra/Zamba2-7B — any mlx-community ports?
   - If yes, how did they implement the Mamba layers?

4. **CoreML conversion**:
   - Can `coremltools` convert Mamba-2 ops to CoreML?
   - Which compute units work? (CPU, GPU, ANE)
   - Does the ANE support the scan operation at all?

5. **Fallback option**: 
   - If no framework supports Mamba-2 on Metal, could we:
     a) Write a custom Metal kernel for the selective scan?
     b) Use GGML/llama.cpp (check if Mamba-2 support exists)?
     c) Use the pure-Python mamba_ssm with MPS backend?

Deliverables I need:
- Which framework to use (Cartesia Edge vs MLX custom vs CoreML vs llama.cpp)
- Expected tok/s on M2 Pro 18GB for a 1B Mamba-2 hybrid
- Code snippet to load a Mamba-2 PyTorch checkpoint into the chosen framework
- Any missing gaps that would require custom kernel development
```

---

## R2 + R3: CoreML ANE Path + Dual-Model Memory Budget

### Context
Epistemos has a "dual-brain" architecture: Brain 1 (Reasoning, 3-4B params) runs on Metal GPU via MLX, Brain 2 (Device Actions, 1B params) should run on the Apple Neural Engine (ANE) via CoreML. Both need to run simultaneously on M2 Pro 18GB without exceeding memory. Currently both brains share a single GPU model — we need to validate that true dual-loading is feasible.

### Research Prompt

```
I'm building a macOS app on Apple Silicon (M2 Pro, 18GB unified memory) that needs to 
run TWO language models simultaneously:

- Brain 1: 3-4B parameter transformer (Qwen 2.5 4B or custom Mamba-2 3B), 4-bit 
  quantized (~3.5 GB), running on Metal GPU via MLX
- Brain 2: 1B parameter model (custom Mamba-2 1B or Gemma-3 1B), 4-bit quantized 
  (~1.5 GB), running on Apple Neural Engine (ANE) via CoreML

Research the following:

1. **CoreML ANE Loading**:
   - Step-by-step: how to convert a HuggingFace 1B model to `.mlpackage` with ANE support
   - Exact coremltools code:
     ```python
     import coremltools as ct
     from transformers import AutoModelForCausalLM, AutoTokenizer
     
     model = AutoModelForCausalLM.from_pretrained("google/gemma-3-1b-it", torch_dtype=torch.float16)
     tokenizer = AutoTokenizer.from_pretrained("google/gemma-3-1b-it")
     
     # What goes here to export for ANE?
     # ct.convert() with compute_units = ct.ComputeUnit.CPU_AND_NE?
     # What about the KV cache? Attention mask? 
     # Does autoregressive generation work on ANE?
     ```
   - Which ops are ANE-compatible? Which fall back to CPU/GPU?
   - Does the ANE support: matmul, softmax, layer norm, RMS norm, SiLU, rotary embeddings?
   - What's the max model size the ANE can handle on M2 Pro?

2. **Dual-Model Memory**:
   - When MLX loads a 4-bit 4B model (~3.5 GB on GPU) and CoreML loads a 4-bit 1B 
     model (~1.5 GB on ANE), do they share the unified memory pool?
   - Total expected memory: 3.5 + 1.5 + system = ?
   - On 18GB M2 Pro with ~4-5GB used by macOS, is there enough headroom?
   - Can both models generate tokens simultaneously (parallel inference)?
   - Is there memory contention between Metal (MLX) and ANE (CoreML)?

3. **Swift Loading Code**:
   - How to load a CoreML model targeting ANE in Swift:
     ```swift
     let config = MLModelConfiguration()
     config.computeUnits = .cpuAndNeuralEngine  // Force ANE
     let model = try MLModel(contentsOf: modelURL, configuration: config)
     ```
   - How to check if the model actually landed on ANE (not CPU fallback)?
   - How to do autoregressive token generation with a CoreML model?
   - Can you do KV-cache with CoreML, or does each generation recompute everything?

4. **Benchmark Expectations**:
   - What tok/s can we expect from a 1B model on the M2 Pro ANE?
   - Reference: Apple's own benchmarks for on-device LLMs
   - Does ANE inference block the GPU? (Can Brain 1 and Brain 2 truly run in parallel?)

5. **Alternative: Apple Intelligence / Foundation Models**:
   - Does macOS 26 expose on-device model inference APIs that could serve as Brain 2?
   - `@Generable` macro, `FoundationModels` framework — can these replace a custom 1B?
   - Limitations: is the output constrained? Can it generate arbitrary JSON?

Deliverables I need:
- Confirmed: yes/no, dual model loading works on M2 Pro 18GB
- Memory budget breakdown
- Swift code snippet for loading + generating with CoreML on ANE
- Expected tok/s for 1B on ANE
- Whether to use CoreML or Apple's built-in Foundation Models
```

---

## R12: RunPod Pilot Validation (Not a research prompt — this is an action checklist)

### What You're Validating
The `mohawk_train.py` script actually works end-to-end on a real GPU: teacher loads, student initializes, training loop runs, checkpoints save.

### Prerequisites
1. HuggingFace account with Llama 3.2 1B access: https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct
2. HuggingFace token: https://huggingface.co/settings/tokens
3. RunPod account with credits loaded

### Step-by-Step

```bash
# 1. From your Mac — launch the pod
cd ~/Downloads/Epistemos/Epistemos/KnowledgeFusion/MOHAWK
./runpod_train_full.sh nano

# If auto-SSH fails, the script prints manual instructions.
# Go to https://www.runpod.io/console/pods → Connect → copy SSH command.
```

```bash
# 2. On the pod — login to HuggingFace
huggingface-cli login
# Paste your token when prompted

# 3. Dry run first
cd /workspace
python mohawk_train.py --stage all --tier nano --dry-run
# Should print: 8.3B tokens, ~4573 steps, ~47 A100-hours, ~$56

# 4. Run ONLY Stage 1 with reduced tokens (pilot: 100M instead of 300M)
python mohawk_train.py --stage 1 --tier nano \
  --tokens 100M \
  --output-dir /workspace/mohawk_pilot

# Watch for:
#   ✅ "Loading teacher: meta-llama/Llama-3.2-1B-Instruct..."
#   ✅ "Teacher: X params"
#   ✅ "Student built: X params (1B target)"
#   ✅ "Stage 1: Matrix Orientation: steps 0 → N"
#   ✅ Training loss decreasing
#   ✅ "Checkpoint saved" messages
#
# Expect ~50K tok/s on A100 → 100M tokens ≈ 30 minutes
# Cost: ~$0.60 at Community A100 rate

# If it crashes, save the error:
# Ctrl+C, then: cat /workspace/mohawk_pilot/stage1/training_metadata.json

# 5. Verify checkpoint
ls -la /workspace/mohawk_pilot/stage1/checkpoint-*/
# Should see checkpoint.pt files

# 6. STOP THE POD immediately after
exit  # Leave SSH
runpodctl pod stop <POD_ID>
```

### What to Report Back
After the pilot, tell Claude Code:
- Did `mamba-ssm` Mamba2 import work? (some CUDA versions have issues)
- Did the teacher model load?
- Did the student model initialize? How many params?
- Did training loss decrease?
- Any OOM errors?
- tok/s achieved?

---

## R14: LoRA Fine-Tuning on Mamba-2 via MLX

### Context
After MOHAWK distillation produces our custom Mamba-2 hybrid model, users will fine-tune it on-device (M2 Pro) using QLoRA via `mlx_lm.lora`. Standard transformer LoRA targets attention projections (`q_proj`, `k_proj`, `v_proj`, `o_proj`). Mamba-2 has different trainable parameters — we need to know which ones to target.

### Research Prompt

```
I have a custom hybrid model: 75% Mamba-2 layers + 25% attention layers. After training 
on cloud GPUs, it will be converted to MLX format for on-device inference and fine-tuning 
on Apple Silicon (M2 Pro 18GB).

Research the following:

1. **Does `mlx_lm.lora` support Mamba-2?**
   - Check: https://github.com/ml-explore/mlx-examples/tree/main/llms/mlx_lm
   - Search for "mamba", "ssm", "state_space" in the lora module
   - The `mlx_lm.lora` default targets for transformers are:
     ```python
     # Default LoRA targets (transformer)
     lora_targets = ["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"]
     ```
   - Does it support custom target specification? Can I pass arbitrary layer names?

2. **Mamba-2 LoRA targets**:
   - In `mamba_ssm.modules.mamba2`, the trainable parameters are:
     ```python
     class Mamba2(nn.Module):
         self.in_proj = nn.Linear(d_model, 2 * d_inner + 2 * ngroups * d_state + nheads, ...)
         self.out_proj = nn.Linear(d_inner, d_model, ...)
         self.conv1d = nn.Conv1d(d_inner + 2 * ngroups * d_state, ..., groups=...)
         # dt_bias, A_log, D are small parameter vectors (not worth LoRA)
     ```
   - Which of these should LoRA target?
   - Research: has anyone published LoRA results on Mamba-2?
   - Google "LoRA Mamba-2" or "parameter-efficient fine-tuning state space models"
   - Check: https://arxiv.org/abs/2312.15597 (LoRA for Mamba)

3. **Hybrid model LoRA**:
   - For our 75/25 hybrid, the LoRA config would need dual targets:
     ```yaml
     lora_layers: 
       # For attention layers (every 4th)
       attention: ["q_proj", "k_proj", "v_proj", "o_proj"]
       # For Mamba-2 layers (the other 75%)  
       mamba: ["in_proj", "out_proj"]  # ← Is this correct?
     rank: 16
     alpha: 32
     ```
   - Does `mlx_lm` support heterogeneous LoRA targets (different targets for different layer types)?

4. **On-device QLoRA feasibility**:
   - Memory for QLoRA on 1B Mamba-2 hybrid (4-bit base + LoRA adapters):
     - Base model: ~1.5 GB
     - LoRA adapters (rank 16): ~?? MB
     - Optimizer states: ~?? MB  
     - Gradient activations: ~?? MB
     - Total: fits in 18GB?
   - Expected training speed: examples/sec on M2 Pro?

5. **Alternative: PEFT library**:
   - Does HuggingFace PEFT support Mamba-2 LoRA?
   - https://github.com/huggingface/peft — search for Mamba support
   - Could we use PEFT for fine-tuning and then convert LoRA weights to MLX format?

Deliverables I need:
- Confirmed LoRA target layers for Mamba-2 (in_proj, out_proj, and/or conv1d?)
- Whether mlx_lm.lora supports custom/heterogeneous targets
- Memory estimate for QLoRA on 1B hybrid model
- Any published benchmarks for Mamba LoRA fine-tuning quality
```

---

## R17: SMAppService App Store Distribution (Future — Low Priority)

### Research Prompt

```
I'm building a macOS app (Epistemos) that needs BOTH:
- A sandboxed SwiftUI main app (for App Store distribution)
- A non-sandboxed helper daemon (for AXUIElement automation, CGEvent injection, 
  ScreenCaptureKit, and local LLM inference via Metal)

Research the following:

1. **SMAppService pattern** (macOS 13+):
   - How to register a non-sandboxed LaunchDaemon/LoginItem from a sandboxed app
   - Code example:
     ```swift
     // In sandboxed main app:
     let service = SMAppService.agent(plistName: "com.epistemos.gateway.plist")
     try await service.register()
     ```
   - Where does the helper binary go? (Contents/Library/LaunchDaemons/?)
   - Does the helper inherit TCC permissions from the main app, or does it need its own?

2. **XPC communication**:
   - Best practice for sandboxed app ↔ non-sandboxed helper IPC
   - XPC Service vs Mach Service vs Unix Domain Socket
   - Authentication: how to verify the helper is our signed binary (not spoofed)?
   - Code snippet for bidirectional XPC with async/await:
     ```swift
     // Helper side
     let listener = NSXPCListener(machServiceName: "com.epistemos.gateway")
     
     // App side  
     let connection = NSXPCConnection(machServiceName: "com.epistemos.gateway")
     connection.remoteObjectInterface = NSXPCInterface(with: GatewayProtocol.self)
     connection.resume()
     ```

3. **App Store review**:
   - Will Apple approve an app that registers a non-sandboxed helper?
   - Precedents: which shipping Mac App Store apps use SMAppService + helper?
   - Entitlements needed for: accessibility API, screen recording, input monitoring
   - Do these TCC prompts need to be requested from the sandboxed app or the helper?

4. **Progressive permissions**:
   - How to request TCC permissions one at a time (not all on first launch)
   - Accessibility: AXIsProcessTrusted() — needs to be checked from the HELPER
   - Screen recording: CGPreflightScreenCaptureAccess() — same
   - Pattern: main app shows UI explaining why → helper requests permission

Deliverables I need:
- Confirmed: SMAppService + non-sandboxed helper is App Store legal
- Complete Xcode project structure (where each target goes)
- XPC protocol definition example
- TCC permission flow diagram
```

---

## Summary: Where You Are

```
Ω0-Ω9:   ✅ DONE (scaffolding → integration tests)
Ω10-Ω14: ✅ DONE (bug fixes → knowledge graph integration)
          ✅ AUDITED (logit processor fixed, duration consolidated, vault picker fixed)

Ω15:      🟡 TRAINING SCRIPT COMPLETE, AWAITING PILOT RUN
          → You: Run R12 pilot ($3), research R10 (Cartesia kernels)
          → Claude: Nothing until pilot results come back

Ω16:      ⬜ BLOCKED on Ω15 completion + R14 (LoRA on Mamba-2)
          → Training pipeline, MoLoRA, ODIA, autoresearch

Ω17:      ⬜ BLOCKED on R17 research
          → App Store distribution, SMAppService

PARALLEL WORK (Claude can do NOW):
  → Option A: Build 6 OpenClaw safety features (docs/OPENCLAW_FEATURE_SPEC.md)
  → Option B: Write missing unit tests (AXSemanticSelector, ToolSchemaGrammar)
  → Option C: Wire NotesAgent E2E tests with real VaultSyncService calls
```
