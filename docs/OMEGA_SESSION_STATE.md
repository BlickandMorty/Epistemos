# Omega Session State
> Quick-read file for new Claude Code sessions. `cat` this first.
> Last updated: 2026-03-25

## Current Phase: Ω15 (MOHAWK Distillation) — READY TO TRAIN
**Teacher:** Qwen 2.5 1.5B (no license gate, instant download)
**NEEDS:** RunPod funded ($150+) at https://runpod.io
**THEN RUN:** `cd Epistemos/KnowledgeFusion/MOHAWK && ./runpod_train_full.sh nano`

### Completed Phases
- [x] Ω0-Ω9 — Scaffolding through integration tests
- [x] Ω10 — Bug fixes + wiring (ResearchPause, EditPlan, logging)
- [x] Ω11 — Constrained decoding (Tier 2 soft biasing — see AUDIT_INSIGHTS.md)
- [x] Ω12 — Dual-brain foundation (HardwareTierManager, DeviceAgentService, DualBrainRouter)
- [x] Ω13 — Computer use stack (AXSemanticSelector, VisualVerifyLoop, Screen2AXFusion)
- [x] Ω14 — Knowledge graph integration (AgentGraphMemory, RecipeGraphSkills, GhostBrainCoauthor)
- [x] Ω15 training script — `KnowledgeFusion/MOHAWK/mohawk_train.py` (complete with Mamba-2 student, 3 stages)

### Audit Fixes Applied (commit `51376895`)
- MLXConstrainedGenerator: LogitProcessor now threaded through TokenIterator
- Duration extensions consolidated into `OmegaExtensions.swift`
- TrainOnVaultView: vault analysis moved to `Task.detached`
- MLXInferenceService.container: `private(set)` for generator access

### New Files Since Last Session
- `docs/OPENCLAW_FEATURE_SPEC.md` — 6 safety features to build (from OpenClaw analysis)
- `docs/NEXT_SESSION_PROMPT.md` — paste into Claude Code to resume
- `docs/RESEARCH_PROMPTS.md` — research prompts for open stops R2/R3/R10/R12/R14/R17
- `KnowledgeFusion/MOHAWK/mohawk_train.py` — complete training script (was skeleton)
- `KnowledgeFusion/MOHAWK/runpod_train_full.sh` — one-shot pod automation
- `KnowledgeFusion/MOHAWK/setup_pod.sh` — pod dependency installer

### What Claude Should Work On (pick one)
1. **Build 6 OpenClaw safety features** — read `docs/OPENCLAW_FEATURE_SPEC.md`
2. **Write missing unit tests** — `AXSemanticSelector.parse()`, `ToolSchemaGrammar`
3. **Wire NotesAgent E2E tests** — real VaultSyncService integration

### Research Stops Status
| ID | Status | Phase |
|----|--------|-------|
| R1 | ✅ RESOLVED | Ω11 — Tier 2 soft biasing |
| R2 | 🔴 OPEN | Ω12 — CoreML ANE path |
| R3 | 🔴 OPEN | Ω12 — Dual-model memory |
| R4 | ✅ RESOLVED | Ω13 — Apple Vision OCR |
| R5 | ✅ RESOLVED | Ω13 — 91% apps have full AX |
| R9 | ✅ RESOLVED | Ω15 — Using Mamba-2 |
| R10 | 🟡 OPEN | Ω15 — Cartesia Metal kernels |
| R12 | 🟡 READY | Ω15 — RunPod pilot |
| R14 | 🔴 OPEN | Ω16 — LoRA on Mamba-2 |
| R17 | 🔴 OPEN | Ω17 — SMAppService |

### Build Command
```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5
# Expected: ** BUILD SUCCEEDED **
```

### Key Files to Read First
| What | File |
|------|------|
| Next session prompt | `docs/NEXT_SESSION_PROMPT.md` |
| Session log | `docs/PROGRESS.md` |
| Audit findings | `docs/OMEGA_AUDIT_INSIGHTS.md` |
| OpenClaw features | `docs/OPENCLAW_FEATURE_SPEC.md` |
| Research prompts | `docs/RESEARCH_PROMPTS.md` |
| Training guide | `docs/TRAINING_GUIDE.md` |

### Branch
`feature/knowledge-fusion-v1` — commit `75e1d1db` + audit fix `51376895`
