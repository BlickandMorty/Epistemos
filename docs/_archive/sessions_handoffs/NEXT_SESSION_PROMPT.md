# Epistemos Omega — Next Session Prompt

> **Index status**: TRANSIENT-CANDIDATE — Session continuation prompt; transient.
> **Superseded by / Phase**: MASTER_SESSION_PROMPT_v2.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## Paste this into Claude Code to start:

```
STEP 0 — Read the North Star (the vision — why we're building this):
0. EPISTEMOS-NORTH-STAR.md — The soul of the project. What Epistemos IS. Read this first, always.

STEP 1 — Read in-repo docs (these are the synthesized truth):
1. CLAUDE.md — Engineering bible, Ω10-Ω24 roadmap, training non-negotiables
2. docs/SESSION_STATE_2026_03_25.md — Current state, what's done/blocked/next
3. docs/NANO-MASTER-TRAINING-GUIDE.md — THE training execution manual (5 pillars, all scripts)
4. docs/TRAINING_GUIDE.md — Quick-reference training guide
5. docs/INSTANT_RECALL_ARCHITECTURE.md — Ω18-Ω21 vector memory + state injection

STEP 2 — Read research papers for deep context (when relevant to task):
6. @/Users/jojo/Downloads/EPISTEMOS-NANO-MASTER-TRAINING-GUIDE.md
   — Master training manifesto: 5 pillars, hyperparameters, app-specific meta-training, nightly flywheel
7. @/Users/jojo/Downloads/Legendary Nano Model  Niche Scripts & Automated Pipelines for the 1B Hybrid Mamba-2 Attention Device Agent.md
   — Niche scripts, automated pipelines, data curation details
8. @/Users/jojo/Downloads/App-Specific Training + Multi-Scale Model Family  Deep Nuanced Pipelines for Nano Base Pro Device Agents.md
   — App-specific training layers, multi-scale model family, CGM, AX atlas
9. @/Users/jojo/Downloads/Fine-Tuning LLMs For App UI.md
   — UI-specific fine-tuning techniques, AX tree training formats
10. @/Users/jojo/Downloads/Epistemos Omega — Dual-Brain Hardware-Action Protocol  Deep Research Analysis & Master Execution Prompt.md
   — Mirror-SD validation, ANE benchmarks, UI-TARS training, VLM2VLA, MoLoRA routing
11. @/Users/jojo/Downloads/Epistemos Omega — Supreme Master Execution Prompt for Claude Code.md
   — 7 anti-drift anchors, 5-layer architecture, all agent rules, phase checklists, Karpathy autoresearch
12. @/Users/jojo/Downloads/agents/Cognitive OS & Local Model Blueprint.md
   — Mamba-3 MIMO, RWKV-7, MoE sparsity, CRDT ghost-brain, Referee Model
13. @/Users/jojo/Downloads/agents/Native macOS Agent Orchestration_ Architecture, Visual Grounding, and System Implementation.md
   — DAG execution, Screen2AX protocol, Voyager skill caching, progressive permissions
14. @/Users/jojo/Downloads/On-Device Knowledge Fusion Research Roadmap.md
   — Autoresearch loop, LOGRA data Shapley, KG-Trie reasoning, speculative decoding
15. @/Users/jojo/Downloads/Epistemos Instant Recall  Mamba + Quantized Vector Memory on Swift Rust.md
   — Binary HNSW, model2vec, two-phase retrieval, Mamba state injection
16. @/Users/jojo/Downloads/TurboQuant (PolarQuant + QJL) — Technical Deep Dive for Implementation.md
   — PolarQuant recursive polar transforms, QJL 1-bit estimator, 3.5 bits/channel
17. @/Users/jojo/Downloads/MLX Constrained Decoding Research.md
   — LogitProcessor API, TokenIterator, mlx-swift-structured package

I am building Epistemos Omega — a local-first cognitive OS for macOS.
Branch: feature/knowledge-fusion-v1

The system is:
- A custom Hybrid Mamba-2 + Attention model (75/25 ratio, NOT pure Mamba)
  trained via MOHAWK distillation to REPLACE Qwen entirely
- Mamba-2 now, Mamba-3 when tooling lands (attention layers NEVER change)
- Deploy on MLX/Metal GPU, NOT ANE (selective scan can't run on ANE)
- App-specific meta-training: Code Graph + Symbol QA + AX Atlas + Trajectories
  (20% Epistemos data allocation is sacred — the competitive moat)
- Dual-brain: Base 3B on Metal GPU (reasoning) + Nano 1B on Metal GPU (device actions)
- Deep macOS automation via AXUIElement + CGEvent + Screen2AX VLM fallback
- Instant vault recall via binary HNSW + Mamba state injection (<3ms)
- Nightly ODIA self-improvement: execution traces → LoRA fine-tune → MoLoRA hot-swap
- ReasoningLoop (STaR + autoresearch) built and tested (opt-in via Settings)

Current status: Ω10-Ω14 complete. Ω15-Ω17 code ready.
ReasoningLoop built (16/16 tests pass). Codex audit findings all resolved.
Teacher switched to Qwen 2.5 1.5B (no license gate). Ready to train once RunPod funded.

Ω18 note:
- HNSW in `graph-engine/src/retrieval_index.rs` is already live.
- `Epistemos/KnowledgeFusion/InstantRecallService.swift` still fronts the separate `epistemos-core` flat binary recall path.
- Do not merge those paths casually.
- During the new model-stack work, explicitly decide whether the app-facing canonical recall engine remains `epistemos-core` instant recall or converges on prepared retrieval in `graph-engine`.
- Only after that decision should you wire continuous encoding + Contextual Shadows into the chosen path.

IMPORTANT RULES:
- This is a HYBRID Mamba-2 + Attention model, NOT pure Mamba-2
- Qwen is a TEMPORARY bridge — custom models replace it entirely
- Deploy on MLX/Metal GPU, NOT ANE — Mamba selective scan can't run on ANE
- All state in Rust/SQLite, all inference in Swift/MLX, connected via UniFFI
- @MainActor @Observable (never ObservableObject), Swift Testing (never XCTest)
- Device agent actions as NATURAL LANGUAGE (VLM2VLA), never token IDs
- READ docs/NANO-MASTER-TRAINING-GUIDE.md before ANY training work
- Read before writing. Execute, don't explain. Finish what you start.
```

## Research Paper Library

When you need Claude to re-read research, tell it:
"Read @<path> for context on <topic>"

### Training & App-Specific (READ FIRST for training work)
| Topic | Path |
|-------|------|
| Master training manifesto | `@/Users/jojo/Downloads/EPISTEMOS-NANO-MASTER-TRAINING-GUIDE.md` |
| Niche scripts & pipelines | `@/Users/jojo/Downloads/Legendary Nano Model...` |
| App-specific training | `@/Users/jojo/Downloads/App-Specific Training...` |
| Fine-tuning for App UI | `@/Users/jojo/Downloads/Fine-Tuning LLMs For App UI.md` |
| Knowledge fusion roadmap | `@/Users/jojo/Downloads/On-Device Knowledge Fusion Research Roadmap.md` |

### Core Architecture
| Topic | Path |
|-------|------|
| Master execution prompt v3.0 | `@/Users/jojo/Downloads/Epistemos Omega — Supreme Master Execution Prompt for Claude Code.md` |
| Dual-brain deep research | `@/Users/jojo/Downloads/Epistemos Omega — Dual-Brain Hardware-Action Protocol...` |
| Cognitive OS blueprint | `@/Users/jojo/Downloads/agents/Cognitive OS & Local Model Blueprint.md` |
| macOS agent orchestration | `@/Users/jojo/Downloads/agents/Native macOS Agent Orchestration...` |

### Inference & Quantization
| Topic | Path |
|-------|------|
| Instant recall (Mamba + vectors) | `@/Users/jojo/Downloads/Epistemos Instant Recall...` |
| TurboQuant deep dive | `@/Users/jojo/Downloads/TurboQuant...` |
| MLX constrained decoding | `@/Users/jojo/Downloads/MLX Constrained Decoding Research.md` |

### In-Repo Docs
| Topic | Path |
|-------|------|
| Engineering bible + roadmap | `CLAUDE.md` |
| Session state | `docs/SESSION_STATE_2026_03_25.md` |
| **Training master guide** | **`docs/NANO-MASTER-TRAINING-GUIDE.md`** |
| Training quick-ref | `docs/TRAINING_GUIDE.md` |
| Instant recall architecture | `docs/INSTANT_RECALL_ARCHITECTURE.md` |
| Ω10-Ω14 audit handoff | `docs/AUDIT-HANDOFF-Ω10-Ω14.md` |
| Omega architecture | `docs/OMEGA_ARCHITECTURE.md` |

## Quick Commands

```bash
# Build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build

# Swift tests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test

# Rust tests
cd graph-engine && cargo test
cd ../epistemos-core && cargo test
cd ../omega-mcp && cargo test
cd ../omega-ax && cargo test

# Start Nano training (Qwen teacher, no license needed)
cd Epistemos/KnowledgeFusion/MOHAWK && ./runpod_train_full.sh nano

# Monitor training
POD_ID=$(cat .last_pod_id) && runpodctl pod ssh $POD_ID --command 'tail -30 /workspace/train.log'
```
