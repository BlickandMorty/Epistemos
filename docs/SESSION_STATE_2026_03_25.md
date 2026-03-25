# Epistemos Session State — March 25, 2026

## Start Here

Read these files in order:
1. `CLAUDE.md` — Engineering bible + Omega phase roadmap (Ω10-Ω24)
2. `docs/INSTANT_RECALL_ARCHITECTURE.md` — Ω18-Ω21 plan (vector memory + state injection)
3. `docs/TRAINING_GUIDE.md` — Model tiers, LoRA targets, training rules
4. This file — what's done, what's next, what's blocked

## Design Principles (from original research, non-negotiable)

### The Model is Hybrid Mamba-Attention (NOT pure anything)
- 75% Mamba-2 layers + 25% Attention layers (every 4th layer)
- Pure Mamba-2 has documented "reasoning drift" and JSON formatting failures
- Attention layers = global anchors for exact retrieval + strict JSON schema
- Reference: NVIDIA Nemotron 3 Super "Mamba-in-Llama" (NeurIPS 2024)
- Future: Mamba-3 MIMO when validated (4x arithmetic intensity)

### ANE Engineering Rules (from M4 reverse-engineering benchmarks)
- ANE actual: 19 TFLOPS FP16 (claimed 38 TOPS INT8 dequants to FP16)
- Power: 6.6 TFLOPS/W (vs GPU ~1.0), idle: 0 mW (hard power gating)
- **Deep graphs, not wide**: chain 16-64 ops per MIL program (single ops waste 70%)
- **Conv over matmul**: 1x1 convolutions use fast datapath, matmul is 3x slower
- **Stay under 32 MB per tensor**: keep in SRAM, DRAM spill kills throughput
- **Avoid dispatch-limited ops**: anything <1ms dominated by 0.095ms XPC overhead
- Prefill (large batch) → ANE; Decode (single token, latency) → GPU Metal

### Device Agent Training: VLM2VLA (actions as language)
- Per VLM2VLA paper (arXiv:2509.22195): represent GUI actions as NATURAL LANGUAGE
  descriptions, NOT arbitrary token IDs — preserves 85%+ base VQA performance
- Synthetic trace format: `ax_press(selector='//AXButton[@title="Submit"]')`
- Training pipeline: UI-TARS 3-stage (Continual PT → SFT → RL with data flywheel)
- Teacher: Claude Opus generates 50K-200K macOS action traces
- Fine-tune: Gemma 3 1B or Phi-4 Mini via mlx_lm.lora (2000 iters, rank 16)
- Per-app MoLoRA: Safari, Terminal, Mail, Notes, Finder (500 iters each)
- Convert to CoreML ANE: context 512, int8 quantization

### Memory Persona Files (injected into every reasoning session)
- `~/.epistemos/MEMORY.md` — curated long-term facts
- `~/.epistemos/SOUL.md` — persona, tone, boundaries
- `~/.epistemos/USER.md` — who the user is, preferences, hardware

### ANE vs GPU Decision Matrix
| Workload | Target | Reason |
|----------|--------|--------|
| 1B Device Agent, 100ms verify | ANE CoreML | 0mW idle, 6.6 TFLOPS/W |
| 1B Device Agent, fast decode | Metal GPU MLX | Higher DRAM bandwidth |
| 3B+ Reasoning Brain | Metal GPU MLX | Only GPU handles large decode |
| Text embeddings (128-dim) | ANE CoreML | Deep graph, stays in SRAM |
| OmniParser V2 (YOLO+Florence) | Metal GPU MPS | Too large for ANE SRAM |
| LoRA fine-tuning | Metal GPU MLX | Training needs FP16 backprop |
| CRDT shadow embedding | ANE CoreML | 500ms debounced, fits deep graph |

### Training Cost Clarification
- **Nano pipeline test** ($100-150): Quick validation run on RunPod, partial tokens
- **Nano full MOHAWK** ($800-1200): All 3 stages, 8B+ tokens, complete distillation
- **Base full MOHAWK** ($1500-2500): The real product model
- Strategy: $100-150 pipeline test first, then full Base when validated

## What Is Truly Done (Committed, Builds, Passes)

### Core App (pre-Omega)
- SwiftUI note editor with live Markdown highlighting
- Rust graph engine (2432 tests, untouched)
- AI pipeline: TriageService → Qwen 3.5 4B on Metal GPU via MLX
- Knowledge Fusion v2: QLoRA training, MoLoRA routing, KTO alignment
- Vault sync, SwiftData models, all views

### Omega Phases (feature/knowledge-fusion-v1 branch)

| Phase | Status | What's Real |
|-------|--------|-------------|
| **Ω10** | ✅ Complete | NotesAgent wired to VaultSync, FileAgent vault URL, MCPBridge logging, ConfirmationGate uses CheckedContinuation, error recovery UI |
| **Ω11** | ✅ Complete | ToolSchemaGrammar (EBNF), ConstrainedDecodingService, MLXConstrainedGenerator threads LogitProcessor through TokenIterator, mlx-swift-structured @ 0.0.4 added as SPM dep |
| **Ω12** | ✅ Complete | HardwareTierManager (sysctl + Metal), DeviceAgentService (SharedGPUBackend), DualBrainRouter (Brain1 GPU / Brain2 ANE routing) |
| **Ω13** | ✅ Complete | AXSemanticSelector (CSS-style //Role[@Attr]), VisualVerifyLoop (Brain 2 LLM + diff fallback), Screen2AXFusion (AX-first, Vision OCR fallback, threshold=10) |
| **Ω14** | ✅ Complete | AgentGraphMemory (execution → graph nodes), RecipeGraphSkills (MCP recipes → graph), GhostBrainCoauthor (graph-based context for writing) |
| **Ω15** | ✅ Code ready | mohawk_train.py: real HybridMambaModel (75% Mamba-2 + 25% Attn), 3 training loops with gradient descent, dataset streaming, wandb, checkpoints. runpod_train_full.sh automation. **Blocked on: RunPod funds ($150+)** |
| **Ω16** | ✅ Code ready | ODIATraceGenerator, TraceDataMixer (40/20/20/20), TrainingScheduler has odiaScheduler wired to nightly QLoRA via trainKnowledgeAdapter(). **Blocked on: needs a trained model to fine-tune** |
| **Ω17** | ✅ Skeleton | AppStoreHelper: SMAppService registration, UDS socket path, HMAC auth, executeViaGateway(). GatewayConnection is stub — actual binary deferred. **Blocked on: R17 research (SMAppService pilot)** |

### Build Status
- `xcodebuild build` → **BUILD SUCCEEDED** (zero errors)
- `cargo test omega-mcp` → ok (0 tests — integration only)
- `cargo test omega-ax` → ok (0 tests — needs accessibility permission)
- `graph-engine` → untouched, 2432 tests passing

### Known Issues
- Vault picker for Knowledge Fusion: fixed 3 times, latest fix uses `withCheckedContinuation` wrapping `NSOpenPanel.begin()`. **Rebuild app (Cmd+R) to pick up fix.**
- omega-ax FFI functions (walkAxTreeJson, simulateClick, etc.) are UniFFI-generated — they exist in the built binary but not in source-visible Swift files. Build must include the "Build Omega Crates" phase.

## What's Next (In Order)

### Immediate (no blockers)
1. **Add RunPod funds** ($150+ at runpod.io → Billing)
2. **Accept Llama license** on huggingface.co (required for teacher model)
3. **Run training**: `HF_TOKEN=your_token ./runpod_train_full.sh nano`
4. **Test vault picker** fix: rebuild app, open Settings → Knowledge Fusion → Select Vault

### After Training Completes (~47 hours on A100)
5. Download MLX model from pod
6. Place in `~/Library/Application Support/Epistemos/Models/text/active/`
7. Verify on-device inference with the custom Mamba-2 hybrid
8. Run ODIA nightly loop to fine-tune on personal notes

### Then Ω18 (Instant Recall — highest impact remaining)
9. Add `usearch` + `model2vec-rs` to epistemos-core Cargo.toml
10. Implement binary HNSW index in Rust
11. Wire continuous encoding from Swift text editor via UniFFI
12. Two-phase retrieval: Hamming → float32 rescore
13. Display top-5 relevant notes in sidebar as you type

## Model Migration Plan (Qwen → Custom Mamba-2)

**The entire point of MOHAWK training is to replace Qwen with our own models.**

| Phase | Brain 1 (Reasoning, GPU) | Brain 2 (Device Actions, ANE) |
|-------|--------------------------|-------------------------------|
| **Now** | Qwen 3.5 4B (~4.5 GB) | Qwen shared (no dual-brain) |
| **After Nano trains** | Qwen 3.5 4B (unchanged) | Epistemos-Nano 1B (~1.5 GB, ANE) |
| **After Base trains** | **Epistemos-Base 3B (~3.5 GB)** | Epistemos-Nano 1B (~1.5 GB, ANE) |
| **Final state** | **Qwen deleted. Custom models only.** | |

Why Base replaces Qwen:
- Faster: ~60-80 tok/s vs Qwen's ~38 tok/s (no KV cache, linear-time)
- Smaller: 3.5 GB vs 4.5 GB (more room for vector index + app)
- Learns: ODIA nightly fine-tuning personalizes it to your vault
- Unique: no one else has this model — it's distilled for Epistemos specifically

Budget: Train Nano first ($100-150) to validate pipeline, then Base ($800-1500) is the real product.

## Research Stops Still Open

| ID | Topic | Blocks | Action |
|----|-------|--------|--------|
| R2 | CoreML ANE path — convert 1B to .mlpackage | Ω19 | Deep Research or test after MOHAWK |
| R3 | Dual-model memory — Base 3B + Nano 1B on 18GB | Ω19 | Measure after R2 |
| R9 | Mamba-3 MIMO for MOHAWK | Ω15 | Resolved: using Mamba-2 with mamba-ssm |
| R10 | Cartesia Metal kernels for Mamba-2 | Ω19 | Deep Research — most critical |
| R14 | LoRA on Mamba-2 mixing layers | Ω20 | Quick check: `mlx_lm.lora` targets |
| R17 | SMAppService pilot | Ω17 | Build test when ready |

## Key Architecture Docs to Re-Read

| Doc | Purpose |
|-----|---------|
| `CLAUDE.md` | Engineering bible + full Ω10-Ω21 roadmap |
| `docs/INSTANT_RECALL_ARCHITECTURE.md` | Ω18-Ω21: vector memory, state injection, TurboQuant |
| `docs/TRAINING_GUIDE.md` | Model tiers, LoRA targets, adapter rules |
| `docs/AUDIT-HANDOFF-Ω10-Ω14.md` | What was built in Ω10-Ω14, audit results |

## Git State

- **Branch**: `feature/knowledge-fusion-v1`
- **Latest commit**: `dd515045` — Add Instant Recall architecture
- **Not pushed** — run `git push origin feature/knowledge-fusion-v1` when ready
- **Main branch**: `main` (untouched, stable)

## Starting Prompt for Next Session

```
Read these files first:
1. CLAUDE.md (engineering bible + Ω10-Ω21 roadmap)
2. docs/SESSION_STATE_2026_03_25.md (current state, what's done/blocked/next)
3. docs/INSTANT_RECALL_ARCHITECTURE.md (Ω18-Ω21 plan)

I am building Epistemos Omega — a local-first cognitive OS for macOS.
Branch: feature/knowledge-fusion-v1

Current status: Ω10-Ω14 complete. Ω15-Ω17 code ready but blocked on
RunPod training (needs funds). Ω18 (instant recall) is the next buildable phase.

Pick up where we left off. Check what's blocked and what's actionable.
```
