# Knowledge Fusion Architecture

> **Index status**: SUPERSEDED-HISTORICAL — Knowledge Fusion retired per IMPLEMENTATION_PLAN_FROM_ADVICE.
> **Superseded by**: IMPLEMENTATION_PLAN_FROM_ADVICE + MASTER_FUSION.md.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## Subsystem 1: Data Ingestion and Normalization Engine

**Input:** Raw markdown notes, PDF documents, voice recordings from the user's vault.
**Output:** Normalized, chunked text (`[TextChunk]`).

- Markdown files: split on H2/H3/H4 headers. Each chunk = heading + body until next heading.
- PDF files: text extracted via PDFKit, chunked at paragraph boundaries (300-700 words).
- Audio files: transcribed via mlx-whisper (or whisper.cpp fallback) with speaker diarization. Paralinguistic cues (hesitations, pacing) captured for stylometric DNA.
- Orphan chunks < 50 words merged with next section. Chunks > 1500 tokens split at paragraph boundaries.

**Files:**
- `Epistemos/KnowledgeFusion/DataIngestion/VaultParser.swift`
- `Epistemos/KnowledgeFusion/DataIngestion/DocumentChunker.swift`
- `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift`

## Subsystem 2: Synthetic Data Generation Pipeline

**Input:** Normalized text chunks from Subsystem 1.
**Output:** JSONL training pairs classified as knowledge, style, or tool-use.

Three-step Self-Instruct / Instruction Backtranslation loop:
1. **Query Generation:** Base model reads chunk, generates 3 hypothetical questions.
2. **Response Rewriting:** Model rewrites raw facts into clean instruction-response pairs.
3. **Quality Scoring:** Self-curation 1-5 scale; discard pairs scoring < 3.

Pairs classified by content heuristics (personal pronouns → style; API/function keywords → tool; else → knowledge). SHA-256 deduplication. 10% held out for evaluation.

**Files:**
- `Epistemos/KnowledgeFusion/SyntheticData/SyntheticDataGenerator.swift`
- `Epistemos/KnowledgeFusion/SyntheticData/InstructionBacktranslator.swift`
- `Epistemos/KnowledgeFusion/SyntheticData/QualityCurator.swift`

## Subsystem 3: Parameter-Efficient Fine-Tuning (QLoRA via MLX)

**Base weights:** Frozen in 4-bit precision. LoRA matrices A and B updated in 16-bit.
**Weight update:** W = W₀ + (α/r) × B × A

### Knowledge Absorption Profile
- rank=32, alpha=64
- Targets: q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj (attention + MLP)
- lr=2e-5

### Style Cloning Profile
- rank=8, alpha=16
- Targets: q_proj, k_proj, v_proj, o_proj (attention ONLY — no MLP)
- lr=1e-5

### Catastrophic Forgetting Mitigations
1. **Experience Replay:** 500-example general-purpose buffer, 10% interleaved per training run.
2. **Curriculum Learning:** Sort examples by complexity (definitions first, multi-hop reasoning last).
3. **Sharpness-Aware Minimization (SAM):** Flat minima for resilient weights.
4. **L2 Regularization:** weight_decay on adapter weights.

**Files:**
- `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift`
- `Epistemos/KnowledgeFusion/Training/TrainingProfileManager.swift`
- `Epistemos/KnowledgeFusion/Training/ExperienceReplayBuffer.swift`
- `Epistemos/KnowledgeFusion/Training/CurriculumSorter.swift`
- `Epistemos/KnowledgeFusion/Training/scripts/train_knowledge.py`
- `Epistemos/KnowledgeFusion/Training/scripts/train_style.py`

## Subsystem 4: Continuous Preference Alignment (KTO)

**Algorithm:** Kahneman-Tversky Optimization (binary, unpaired feedback).
**NOT DPO:** DPO requires paired responses + reference model in memory — too expensive on-device.

Feedback signals:
- Positive: user accepts ghost text, copies generated text, clicks thumbs-up.
- Negative: user deletes/overwrites within 3s, clicks discard, edits >50%.

Schedule: Batch overnight only. Minimum 20 feedback signals before running.

**Files:**
- `Epistemos/KnowledgeFusion/Alignment/FeedbackLogger.swift`
- `Epistemos/KnowledgeFusion/Alignment/KTOTrainer.swift`
- `Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift`
- `Epistemos/KnowledgeFusion/Alignment/scripts/train_kto.py`

## Subsystem 5: Dynamic Inference and Routing (MoLoRA scaffold)

Multiple adapters loaded into unified memory simultaneously. Routing selects which adapter(s) to apply per request.

**CRITICAL:** Adapters are NEVER fused permanently into base weights. Hot-swap only via `load_adapter()`. Fusion causes 3x MLX speed degradation (21→7 tok/s).

Routing modes:
- **Explicit:** User selects adapter from dropdown.
- **Automatic:** Classify prompt → route to knowledge/style/tool adapter.
- **MoLoRA (scaffold):** Swift per-token routing interface is source-preserved but returns nil until a custom MLX kernel exists. The optional Pro subprocess is prompt-level decide-once routing, not per-token routing.

**Files:**
- `Epistemos/KnowledgeFusion/Adapters/AdapterRegistry.swift`
- `Epistemos/KnowledgeFusion/Adapters/AdapterLoader.swift`
- `Epistemos/KnowledgeFusion/Adapters/AdapterRouter.swift`
- `Epistemos/KnowledgeFusion/Adapters/AdapterExporter.swift`

## Autoresearch Self-Improvement Loop

Adapted from Karpathy's autoresearch pattern. Autonomously varies training hyperparameters, runs fixed-budget experiments, evaluates via Direct+Indirect Probing, and keeps/discards based on score comparison.

**Files:**
- `Epistemos/KnowledgeFusion/Autoresearch/AutoresearchLoop.swift`
- `Epistemos/KnowledgeFusion/Autoresearch/ExperimentTracker.swift`
- `Epistemos/KnowledgeFusion/Autoresearch/MetricEvaluator.swift`
