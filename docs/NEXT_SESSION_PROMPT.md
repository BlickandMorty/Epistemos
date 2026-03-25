# Epistemos Omega — Next Session Prompt

## Paste this into Claude Code to start:

```
Read these files IN ORDER before doing anything:

1. CLAUDE.md — Engineering bible, Ω10-Ω24 roadmap, all patterns
2. docs/SESSION_STATE_2026_03_25.md — Current state, what's done/blocked/next, design principles
3. docs/INSTANT_RECALL_ARCHITECTURE.md — Ω18-Ω21 vector memory + state injection
4. docs/TRAINING_GUIDE.md — Model tiers, MOHAWK stages, LoRA targets, training rules

I am building Epistemos Omega — a local-first cognitive OS for macOS.
Branch: feature/knowledge-fusion-v1

The system is:
- A custom Hybrid Mamba-2 + Attention model (75/25 ratio, NOT pure Mamba)
  trained via MOHAWK distillation to REPLACE Qwen entirely
- Dual-brain: Base 3B on Metal GPU (reasoning) + Nano 1B on ANE (device actions)
- Deep macOS automation via AXUIElement + CGEvent + Screen2AX VLM fallback
- Instant vault recall via binary HNSW + Mamba state injection
- Nightly ODIA self-improvement pipeline
- TurboQuant (PolarQuant + QJL) for advanced vector compression

Current status: Ω10-Ω14 complete. Ω15-Ω17 code ready (blocked on RunPod funds).
Pick up where we left off. Check what's blocked and what's actionable.

IMPORTANT RULES:
- This is a HYBRID Mamba-2 + Attention model, NOT pure Mamba-2
- Qwen is a TEMPORARY bridge — custom models replace it entirely
- All state in Rust/SQLite, all inference in Swift/MLX, connected via UniFFI
- @MainActor @Observable (never ObservableObject), Swift Testing (never XCTest)
- Read before writing. Execute, don't explain. Finish what you start.
```

## Research Paper Library

When you need Claude to re-read research, tell it:
"Read @<path> for context on <topic>"

### Core Architecture
| Topic | Path |
|-------|------|
| Master execution prompt v3.0 | `@/Users/jojo/Downloads/Epistemos Omega — Supreme Master Execution Prompt for Claude Code.md` |
| Dual-brain deep research | `@/Users/jojo/Downloads/Epistemos Omega — Dual-Brain Hardware-Action Protocol  Deep Research Analysis & Master Execution Prompt.md` |
| Cognitive OS blueprint | `@/Users/jojo/Downloads/agents/Cognitive OS & Local Model Blueprint.md` |
| macOS agent orchestration | `@/Users/jojo/Downloads/agents/Native macOS Agent Orchestration_ Architecture, Visual Grounding, and System Implementation.md` |

### Training & Models
| Topic | Path |
|-------|------|
| Knowledge fusion roadmap | `@/Users/jojo/Downloads/On-Device Knowledge Fusion Research Roadmap.md` |
| Instant recall (Mamba + vectors) | `@/Users/jojo/Downloads/Epistemos Instant Recall  Mamba + Quantized Vector Memory on Swift Rust.md` |
| TurboQuant deep dive | `@/Users/jojo/Downloads/TurboQuant (PolarQuant + QJL) — Technical Deep Dive for Implementation.md` |
| MLX constrained decoding | `@/Users/jojo/Downloads/MLX Constrained Decoding Research.md` |

### Additional Research
| Topic | Path |
|-------|------|
| AI auditor framework | `@/Users/jojo/Downloads/AI Auditor for Code Development.md` |
| Cognitive OS (older version) | `@/Users/jojo/Downloads/old research/Cognitive OS & Local Model Blueprint.md` |

### In-Repo Docs
| Topic | Path |
|-------|------|
| Engineering bible + roadmap | `CLAUDE.md` |
| Session state + design principles | `docs/SESSION_STATE_2026_03_25.md` |
| Instant recall architecture | `docs/INSTANT_RECALL_ARCHITECTURE.md` |
| Training guide | `docs/TRAINING_GUIDE.md` |
| Ω10-Ω14 audit handoff | `docs/AUDIT-HANDOFF-Ω10-Ω14.md` |
| Omega architecture | `docs/OMEGA_ARCHITECTURE.md` |

## Example Commands for Research

```
# When working on training:
"Read @/Users/jojo/Downloads/On-Device Knowledge Fusion Research Roadmap.md
for context on LOGRA data Shapley and autoresearch loop"

# When working on device agent:
"Read @/Users/jojo/Downloads/Epistemos Omega — Dual-Brain Hardware-Action Protocol  Deep Research Analysis & Master Execution Prompt.md
for context on UI-TARS training pipeline and VLM2VLA"

# When working on vector memory:
"Read @/Users/jojo/Downloads/TurboQuant (PolarQuant + QJL) — Technical Deep Dive for Implementation.md
for context on PolarQuant recursive polar transforms"

# When working on model architecture:
"Read @/Users/jojo/Downloads/agents/Cognitive OS & Local Model Blueprint.md
for context on Mamba-3 MIMO and custom Metal kernels"
```

## Quick Commands

```bash
# Build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build

# Rust tests
cd omega-mcp && cargo test && cd ../omega-ax && cargo test

# Graph engine guard
cd graph-engine && cargo test 2>&1 | grep "test result"

# RunPod
runpodctl pod list
cd Epistemos/KnowledgeFusion/MOHAWK && ./runpod_train_full.sh nano
```
