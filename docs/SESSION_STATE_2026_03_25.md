# Epistemos Session State — March 25, 2026

## Start Here

Read these files in order:
1. `CLAUDE.md` — Engineering bible + Omega phase roadmap (Ω10-Ω21)
2. `docs/INSTANT_RECALL_ARCHITECTURE.md` — Ω18-Ω21 plan (vector memory + state injection)
3. `docs/TRAINING_GUIDE.md` — Model tiers, LoRA targets, training rules
4. This file — what's done, what's next, what's blocked

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

## Research Stops Still Open

| ID | Topic | Blocks | Action |
|----|-------|--------|--------|
| R2 | CoreML ANE path — convert 1B to .mlpackage | Ω19 | Deep Research or test after MOHAWK |
| R3 | Dual-model memory — Qwen 4B + 1B CoreML on 18GB | Ω19 | Measure after R2 |
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
