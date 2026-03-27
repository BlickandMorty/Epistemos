# Epistemos Training Tracks — Separation of Concerns

Generated: 2026-03-27

## Three Distinct Training Tracks

### Track 1: MOHAWK Cloud Distillation (RunPod GPU)
**Purpose:** Create the base Hybrid Mamba-2 + Attention model from scratch via progressive distillation.
**Where:** `Epistemos/KnowledgeFusion/MOHAWK/mohawk_train.py`
**Data:** HuggingFace datasets (SlimPajama, C4, OpenOrca, hermes-function-calling) + local epistemos_training_data/ JSONL in Stage 3.
**Output:** Checkpoint files (.pt) on RunPod → download → convert to MLX.
**Schedule:** One-time (or on architecture changes).
**Status:** Running on RunPod now. Stage 1 in progress.

**Seed corpus** (`epistemos_training_data_validated/`):
- 4,190 validated examples across 15 categories
- Bootstrap quality — gets the model started on Epistemos knowledge
- NOT the final truth. Will be supplemented by Track 2 and Track 3.

### Track 2: Local Vault Fine-Tune (On-Device MLX)
**Purpose:** Specialize the base model on the user's personal vault content and writing style.
**Where:**
- `Epistemos/KnowledgeFusion/UI/KnowledgeFusionViewModel.swift` (UI coordinator)
- `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift` (training actor)
- `Epistemos/KnowledgeFusion/Training/scripts/train_knowledge.py` (MLX LoRA)
- `Epistemos/KnowledgeFusion/Training/scripts/train_style.py` (MLX LoRA)
**Data:** User's vault notes, processed through SyntheticDataGenerator → InstructionBacktranslator → QualityCurator.
**Output:** LoRA adapters in `~/Library/Application Support/Epistemos/Adapters/`
**Schedule:** On-demand via UI ("Train on Vault" button).
**Config:**
- Knowledge adapter: rank=32, alpha=64, all 7 projection modules
- Style adapter: rank=8, alpha=16, 4 attention modules only
- Experience replay: 10% general data mixed in (anti-forgetting)

### Track 3: Nightly ODIA Self-Improvement (On-Device MLX)
**Purpose:** Continuously improve from agent execution traces.
**Where:**
- `Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift` (NSBackgroundActivityScheduler)
- `Epistemos/Omega/Knowledge/ODIATraceGenerator.swift` (chat-format trace generator)
- `Epistemos/Omega/Inference/ReasoningTraceLogger.swift` (reasoning chain traces)
**Data:** Successful agent execution traces in ODIA format, converted to chat-style JSONL.
**Output:** Incremental LoRA adapter updates.
**Schedule:** Daily at 2am (gated by 30-min idle + battery level + thermal state).
**Status:** TrainingScheduler wired, ODIA generators produce data, but no trained adapter output yet.

## Canonical Trace Schema: Chat-Format (Track 3)

**Decision:** Use the Omega/Knowledge `ODIATraceGenerator` (chat-format) as canonical, NOT the SyntheticData version (raw struct Codable).

**Rationale:**
- mlx-lm expects `{"messages": [{"role": "system", ...}, {"role": "user", ...}, {"role": "assistant", ...}]}` format
- The chat format is directly consumable by both MOHAWK (Stage 3) and local MLX LoRA training
- The SyntheticData version's raw Codable output requires an additional conversion step

**Action items:**
- SyntheticData/ODIATraceGenerator should be adapted to produce chat-format output matching Omega/Knowledge
- OR SyntheticData pipeline should feed INTO the Omega/Knowledge generator for formatting
- The two `ODIATrace` types must be disambiguated (different modules, same name)

## What Does NOT Go Into MOHAWK Seed Corpus

The following should NOT dominate the MOHAWK seed. They are valid for Track 2/3 but premature for Track 1:
- Raw vault content (Track 2 handles this)
- Live AX tree captures (Track 3 handles this after model is deployed)
- Screenshot/visual data (no vision capability in base model yet)

## What DOES Go Into MOHAWK Seed Corpus

Validated, codebase-grounded examples that teach:
1. Epistemos architecture and code patterns (symbol_qa, code_graph)
2. macOS UI element vocabulary (ax_atlas)
3. Tool-calling format and semantics (tool_calls, axpress_schema)
4. Reasoning patterns with <think> tags (reasoning_chains)
5. When NOT to act (negative examples)
6. Error recovery strategies (error_recovery)

## Runtime Output Paths

| Artifact | Path | Status |
|----------|------|--------|
| Trained adapters | ~/Library/Application Support/Epistemos/Adapters/ | 6 adapters present |
| Adapter registry | Inside knowledge_fusion.db | Exists |
| Execution logs | ~/Library/Application Support/Epistemos/omega_executions.db | Exists |
| Training scripts | ~/Library/Application Support/Epistemos/training-scripts/ | Exists |
| Base models | ~/Library/Application Support/Epistemos/Models/text/active/ | Qwen 0.8B/2B/4B/9B |
