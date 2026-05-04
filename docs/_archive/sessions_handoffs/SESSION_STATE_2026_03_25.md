# Epistemos Session State — March 25, 2026 (Updated)

> **Index status**: TRANSIENT-CANDIDATE — Session state snapshot (2026-03-25); historical artifact superseded by NANO-MASTER-TRAINING-GUIDE.
> **Superseded by / Phase**: NANO-MASTER-TRAINING-GUIDE.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## Start Here (Read In Order)

1. `CLAUDE.md` — Engineering bible, Ω10-Ω24 roadmap, training non-negotiables
2. `docs/NANO-MASTER-TRAINING-GUIDE.md` — **THE training execution manual** (5 pillars, all scripts, all hyperparameters)
3. `docs/TRAINING_GUIDE.md` — Quick-reference training guide
4. `docs/INSTANT_RECALL_ARCHITECTURE.md` — Ω18-Ω21 plan (vector memory + state injection)
5. This file — what's done, what's next, what's blocked

### Training Research Papers (read for deep context when working on training)

| Topic | Path |
|-------|------|
| Niche scripts & pipelines | `@/Users/jojo/Downloads/Legendary Nano Model...` |
| App-specific training | `@/Users/jojo/Downloads/App-Specific Training...` |
| Fine-tuning for App UI | `@/Users/jojo/Downloads/Fine-Tuning LLMs For App UI.md` |
| Knowledge fusion roadmap | `@/Users/jojo/Downloads/On-Device Knowledge Fusion Research Roadmap.md` |
| Dual-brain deep research | `@/Users/jojo/Downloads/Epistemos Omega — Dual-Brain...` |
| Master execution prompt | `@/Users/jojo/Downloads/Epistemos Omega — Supreme Master Execution Prompt...` |
| Cognitive OS blueprint | `@/Users/jojo/Downloads/agents/Cognitive OS & Local Model Blueprint.md` |
| macOS agent orchestration | `@/Users/jojo/Downloads/agents/Native macOS Agent Orchestration...` |
| Instant recall research | `@/Users/jojo/Downloads/Epistemos Instant Recall...` |
| TurboQuant deep dive | `@/Users/jojo/Downloads/TurboQuant...` |
| MLX constrained decoding | `@/Users/jojo/Downloads/MLX Constrained Decoding Research.md` |
| Master training manifesto | `@/Users/jojo/Downloads/EPISTEMOS-NANO-MASTER-TRAINING-GUIDE.md` |

---

## Design Principles (non-negotiable)

### The Model is Hybrid Mamba/Attention (NOT pure anything)
- 75% Mamba layers + 25% Attention layers
- Pure SSMs have "reasoning drift" and JSON formatting failures
- Attention layers = exact retrieval + JSON schema enforcement + multi-turn anchoring
- The 6 attention layers do 3 things NO SSM can replace:
  1. Exact AX tree token retrieval for correct selectors
  2. JSON schema structural anchoring (layer 11)
  3. Multi-turn context recall of recent 512 tokens (layers 18-19)

### Mamba-2 Now, Mamba-3 When Tooling Lands
- **Build with Mamba-2** — MOHAWK validated, MLX v0.31.1 supports it, tooling exists
- **Swap to Mamba-3 in Month 2-3** — when MOHAWK-3 recipe + MLX support land
- Mamba-3 fixes state-tracking ("which app am I in?") via complex-valued dynamics
- This is **complementary** to attention, not a replacement
- Keep layer abstraction parameterized for clean swap (config change, not rewrite)
- Watch: `state-spaces/mamba` repo, GoombaLab blog

### Deploy on MLX/Metal GPU, NOT ANE
- Mamba selective scan CANNOT run on Apple Neural Engine
- Reserve ANE for: vision verification (100ms loop), text embeddings, intent classification
- Expected inference: 70-95 tok/s on M4 Max (1B, 4-bit)

### App-Specific Meta-Training (THE COMPETITIVE MOAT)
A model trained on its own app's code/UI/workflows **recalls** from weights (sub-1ms), not inference (10-50ms). 4 layers:
- **Layer 0**: Code Graph Model — Swift ASTs → symbol/call/state graph
- **Layer 1**: Xcode Symbol QA — forward ("create note" → method) + reverse (method → description)
- **Layer 2**: AX Atlas — differential snapshots (pre/post action AX diffs)
- **Layer 3**: Trajectories — 1,000 multi-turn workflows via Claude Sonnet
- **20% Epistemos data allocation is sacred** — below 15% reflexes degrade, above 25% general capability suffers

### Training Non-Negotiables
1. Deploy on MLX/Metal GPU, NOT ANE
2. WSD scheduler, never cosine (allows checkpoint reuse)
3. 20% Epistemos app-specific data is sacred
4. LoRA rank 16 for Nano (not 8, not 32)
5. Never fuse adapters into base — hot-swap via MoLoRA only
6. 4 layers of app self-knowledge
7. Version-triggered adapter regeneration on every build
8. One variable at a time in experiments
9. Mamba-2 now, Mamba-3 when tooling lands

---

## What Is Done

### Core App (pre-Omega)
- SwiftUI note editor with live Markdown highlighting
- Rust graph engine (2432 tests passing)
- AI pipeline: TriageService → Qwen 3.5 4B on Metal GPU via MLX
- Knowledge Fusion v2: QLoRA training, MoLoRA routing, KTO alignment
- Vault sync, SwiftData models, all views

### Omega Phases

| Phase | Status | What's Real |
|-------|--------|-------------|
| **Ω10** | ✅ Complete | NotesAgent, FileAgent, MCPBridge logging, ConfirmationGate |
| **Ω11** | ✅ Complete | ToolSchemaGrammar (EBNF), ConstrainedDecodingService (soft guidance, correctly labeled) |
| **Ω12** | ✅ Complete | HardwareTierManager, DeviceAgentService, DualBrainRouter |
| **Ω13** | ✅ Complete | AXSemanticSelector, VisualVerifyLoop, Screen2AXFusion |
| **Ω14** | ✅ Complete | AgentGraphMemory, RecipeGraphSkills, GhostBrainCoauthor |
| **Ω15** | ✅ Code ready | mohawk_train.py (Qwen 2.5 1.5B teacher, no license gate), runpod_train_full.sh. **Ready to run — needs RunPod funds only** |
| **Ω16** | ✅ Code ready | ODIATraceGenerator, TraceDataMixer, TrainingScheduler. **Blocked: needs trained model** |
| **Ω17** | ✅ Skeleton | AppStoreHelper, SMAppService. **Blocked: R17 research** |

### This Session's Work (March 25, 2026)

| What | Files | Status |
|------|-------|--------|
| **ReasoningLoop** (STaR + autoresearch) | `ReasoningLoopService.swift`, `ReasoningTraceLogger.swift`, `ReasoningLoopTests.swift` | ✅ Built, 16/16 tests pass |
| **Codex audit Finding 1** (constrained decoding) | Verified `isAvailable=false`, correctly Option B | ✅ Already truthful |
| **Codex audit Finding 2** (tool contracts) | Added `press_key` to test expectedMappings (18→19) | ✅ Fixed |
| **Codex audit Finding 3** (settings) | All 5 settings verified wired to runtime | ✅ Already wired |
| **Codex bug fix** | `AppBootstrap.swift:258` — reasoning loop was force-enabled, fixed to opt-in via UserDefaults | ✅ Fixed |
| **Training docs** | `NANO-MASTER-TRAINING-GUIDE.md` added, `TRAINING_GUIDE.md` rewritten, `CLAUDE.md` updated | ✅ Saved |
| **Mamba-2→3 plan** | Updated in Master Guide, Training Guide, CLAUDE.md | ✅ Documented |

### Build & Test Status
- `xcodebuild build` → **BUILD SUCCEEDED**
- Swift tests: 2402 tests, 2322 passed, 80 pre-existing failures (none from this session)
- Rust tests: 2611 all passing (graph-engine 2432, epistemos-core 80, omega-ax 10+89)
- ReasoningLoop: 16/16 passed (3 suites)
- ToolSchemaGrammar: passed (19 tools)

---

## What's Next (In Order)

### No Longer Blocked — Teacher Switched to Qwen 2.5 1.5B
- Llama license no longer needed — Qwen 2.5 is fully open (no gating)
- Only prerequisite: RunPod account with $150+ funds

### Training Sequence (ready to run NOW)
```bash
# 1. Verify token
echo $HF_TOKEN  # should print hf_...

# 2. Start MOHAWK distillation (~2-3 days on RunPod)
cd /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/MOHAWK
./runpod_train_full.sh nano

# 3. Monitor
POD_ID=$(cat .last_pod_id)
runpodctl pod ssh $POD_ID --command 'tail -30 /workspace/train.log'

# 4. Download when done
runpodctl pod ssh $POD_ID --command 'tar czf /workspace/model.tar.gz mohawk_nano/'

# 5. Stop billing
runpodctl pod stop $POD_ID

# 6. Convert to MLX locally
mlx_lm.convert --hf-path ./mohawk_nano --mlx-path ./mohawk_nano_mlx
mlx_lm.convert --hf-path ./mohawk_nano_mlx -q --q-bits 4 --mlx-path ./mohawk_nano_mlx_4bit

# 7. Deploy
mkdir -p ~/Library/Application\ Support/Epistemos/Models/text/active/
cp -r ./mohawk_nano_mlx_4bit ~/Library/Application\ Support/Epistemos/Models/text/active/epistemos-nano-1b
```

### Training Week-by-Week Schedule
| Week | Activity | Output |
|------|----------|--------|
| 1 | MOHAWK Stage 1-3 from Qwen 2.5 1.5B teacher (no license gate) | `mohawk_nano_base` |
| 2 | Build CGM + AX atlas + symbol QA | App-specific training data |
| 3 | 50K general traces + 1K Epistemos trajectories | Training datasets |
| 4 | Superfilter → CAMPUS sort → SFT | `nano_axpress_v1.lora` |
| 5 | GRPO with 6-component decomposed reward | Policy-improved adapter |
| 6 | RLAIF on Epistemos trajectories | App-aware adapter |
| 7 | Constrained decoding + end-to-end eval | Production-ready model |
| 8+ | Nightly flywheel live | Continuously improving |

### After Training — Ω18 (Instant Recall, highest impact)
1. Add `usearch` + `model2vec-rs` to epistemos-core Cargo.toml
2. Implement binary HNSW index in Rust
3. Wire continuous encoding from Swift text editor via UniFFI
4. Two-phase retrieval: Hamming → float32 rescore
5. Display top-5 relevant notes in sidebar as you type

---

## Model Migration Plan

| Phase | Brain 1 (Reasoning, GPU) | Brain 2 (Device Actions, GPU) |
|-------|--------------------------|-------------------------------|
| **Now** | Qwen 3.5 4B (~4.5 GB) | Qwen shared (no dual-brain) |
| **After Nano trains** | Qwen 3.5 4B (unchanged) | **Epistemos-Nano 1B (~1.5 GB, MLX GPU)** |
| **After Base trains** | **Epistemos-Base 3B (~3.5 GB, MLX GPU)** | Epistemos-Nano 1B |
| **Final state** | **Qwen deleted. Custom models only.** | |

---

## Codex Audit Status

### Previous Findings — All Resolved
1. **Constrained decoding** — correctly Option B (soft guidance, `isAvailable=false`, logged)
2. **Tool contracts** — all 20 tools aligned across planner/schema/grammar/runtime. `press_key` test gap fixed.
3. **Settings** — all 5 wired (`autoExecuteLowRisk`, `maxRetries`, `screen2axEnabled`, `overnightTraining`, `terminalAllowList`)
4. **ReasoningLoop startup bug** — Codex force-enabled it; fixed to opt-in via UserDefaults

### Files for Next Audit
See `docs/CLAUDE_OMEGA_AUDIT_FIX_MANIFESTO_2026_03_25.md` for the full audit manifesto.
New code to audit: `ReasoningLoopService.swift`, `ReasoningTraceLogger.swift`, `ReasoningLoopTests.swift`

---

## Key Files Quick Reference

| Purpose | Path |
|---------|------|
| Engineering bible | `CLAUDE.md` |
| North star vision | `EPISTEMOS-NORTH-STAR.md` |
| **Training master guide** | **`docs/NANO-MASTER-TRAINING-GUIDE.md`** |
| Training quick-ref | `docs/TRAINING_GUIDE.md` |
| Instant recall arch | `docs/INSTANT_RECALL_ARCHITECTURE.md` |
| This session state | `docs/SESSION_STATE_2026_03_25.md` |
| Omega architecture | `docs/OMEGA_ARCHITECTURE.md` |
| Ω10-Ω14 audit handoff | `docs/AUDIT-HANDOFF-Ω10-Ω14.md` |
| ReasoningLoop | `Epistemos/Omega/Inference/ReasoningLoopService.swift` |
| MOHAWK training | `Epistemos/KnowledgeFusion/MOHAWK/mohawk_train.py` |
| RunPod automation | `Epistemos/KnowledgeFusion/MOHAWK/runpod_train_full.sh` |

---

## Git State

- **Branch**: `feature/knowledge-fusion-v1`
- **Not pushed** — run `git push origin feature/knowledge-fusion-v1` when ready
- **Main branch**: `main` (untouched, stable)

---

## Starting Prompt for Next Session

```
Read these files first:
1. CLAUDE.md (engineering bible + training non-negotiables + Ω10-Ω24 roadmap)
2. docs/SESSION_STATE_2026_03_25.md (current state, what's done/blocked/next)
3. docs/NANO-MASTER-TRAINING-GUIDE.md (THE training execution manual — 5 pillars)
4. docs/TRAINING_GUIDE.md (quick-reference training guide)
5. docs/INSTANT_RECALL_ARCHITECTURE.md (Ω18-Ω21 plan)

I am building Epistemos Omega — a local-first cognitive OS for macOS.
Branch: feature/knowledge-fusion-v1

The system is:
- A custom Hybrid Mamba-2 + Attention model (75/25 ratio, NOT pure Mamba)
  trained via MOHAWK distillation to REPLACE Qwen entirely
- Mamba-2 now, Mamba-3 when tooling lands (attention layers never change)
- Deploy on MLX/Metal GPU, NOT ANE (selective scan can't run on ANE)
- App-specific meta-training: Code Graph + Symbol QA + AX Atlas + Trajectories
- 20% Epistemos data allocation is sacred (the competitive moat)
- Nightly ODIA self-improvement flywheel
- ReasoningLoop (STaR + autoresearch) built and tested

Current status: Ω10-Ω14 complete. Ω15-Ω17 code ready.
ReasoningLoop built (16/16 tests pass). Codex audit findings all resolved.
Llama license pending → then run ./runpod_train_full.sh nano

IMPORTANT: Read docs/NANO-MASTER-TRAINING-GUIDE.md before ANY training work.
It has all 5 pillars, hyperparameters, scripts, anti-patterns, and schedules.

Pick up where we left off. Check what's blocked and what's actionable.
```
