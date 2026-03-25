# KNOWLEDGE FUSION CONTINUATION PROMPT — Paste into new Claude Code session

## CONTEXT RECOVERY

You are continuing work on **Epistemos Knowledge Fusion** — a synthetic data pipeline that transforms a user's 710+ markdown vault notes into high-quality training data for a custom Hybrid Mamba-Attention model. Phases 0-1 are complete. Your job is to implement **Phases 2-5** (the core pipeline).

**First action in every session:**
```bash
cat CLAUDE.md && cat docs/PROGRESS.md && cat docs/DECISIONS.md && cat docs/knowledge-fusion/architecture.md && cat docs/ROADMAP_NEXT_3.md
```

## WHAT EXISTS (DO NOT REBUILD)

### Rust Crate: epistemos-core (47 tests passing)
| Module | What It Does |
|--------|-------------|
| `vault_analyzer.rs` | MTLD lexical diversity, token estimation, dual-bound estimator |
| `classifier.rs` | Document type classification (Prose/SourceCode/TechnicalDocs/MixedMedia) |
| `boilerplate_filter.rs` | Strips frontmatter, license blocks, TOC, HTML comments |
| `auto_tuner.rs` | Hyperparameter search (learning rate, LoRA rank) |
| `scheduler.rs` | Training job scheduling (idle detection, thermal awareness) |
| `skill_engine.rs` | Stub — adapter routing |
| `retrieval.rs` | Stub — RAG retrieval |
| `repo_analyzer.rs` | Stub — code repository analysis |
| `training.rs` | Stub — training orchestration |

### UniFFI Exports (16 functions, 4 types)
- `analyze_vault_content(text) → VaultAnalysis`
- `estimate_tokens(text) → u64`
- `classify_document(text) → DocumentClass`
- `filter_boilerplate(text) → BoilerplateResult`
- `compute_mtld(text, threshold) → f64`
- Plus auto_tuner, scheduler functions

### Swift Integration
- `AppBootstrap.swift` creates `OmegaTrainingCoordinator`
- `epistemos-core` UniFFI bindings generated at `build-rust/swift-bindings/epistemos_core.swift`
- Build script: `build-epistemos-core.sh`

## THE 5 SUBSYSTEMS TO BUILD

### Subsystem 1: Data Ingestion Engine (Phase 2)
**Goal**: Parse all vault notes into normalized, chunked documents ready for synthetic generation.

Files to create:
- `Epistemos/KnowledgeFusion/VaultParser.swift` — Reads all SDPage bodies, applies classifier + boilerplate filter
- `Epistemos/KnowledgeFusion/DocumentChunker.swift` — Markdown-header chunking (NOT recursive splitting)
- `epistemos-core/src/chunker.rs` — Rust-side chunking by markdown headers (# / ## / ###)

Key constraints:
- Chunk by markdown headers, not fixed token windows
- Each chunk keeps its header hierarchy as context prefix
- Minimum chunk size: 50 tokens. Maximum: 2048 tokens.
- Chunks reference their source page ID for provenance

### Subsystem 2: Synthetic Data Generation (Phase 3)
**Goal**: Generate high-quality instruction-response pairs from vault chunks.

Files to create:
- `Epistemos/KnowledgeFusion/SyntheticDataGenerator.swift` — Orchestrates generation using local Qwen
- `Epistemos/KnowledgeFusion/InstructionBacktranslator.swift` — Self-Instruct: given a passage, generate a question it answers
- `Epistemos/KnowledgeFusion/QualityCurator.swift` — Filters low-quality pairs (perplexity, diversity, dedup)
- `epistemos-core/src/quality_filter.rs` — Rust-side dedup (MinHash) and quality scoring

Data composition target (40/20/20/20):
- 40% Synthetic tool-call examples (from ODIA omega-mcp execution traces)
- 20% General language & code (reference SlimPajama/StarCoder subsets)
- 20% Multi-step reasoning traces (chain-of-thought from vault analysis)
- 20% macOS automation examples (AppleScript, JXA, AX tree JSON)

Output format: JSONL with fields `{instruction, input, output, source, quality_score}`

### Subsystem 3: QLoRA Fine-Tuning Pipeline (Phase 4)
**Goal**: Train LoRA adapters on the synthetic data using MLX on-device.

Files to create:
- `Epistemos/KnowledgeFusion/QLoRATrainer.swift` — Wraps MLX training loop
- `Epistemos/KnowledgeFusion/TrainingProfileManager.swift` — Manages adapter profiles (knowledge, style, agent)
- `Epistemos/KnowledgeFusion/ExperienceReplayBuffer.swift` — 10% replay buffer to prevent catastrophic forgetting

Key constraints:
- Training runs ONLY during idle + on power (use `scheduler.rs`)
- Base model frozen at 4-bit, LoRA adapters at 16-bit
- Never permanently fuse adapters (21→7 tok/s degradation risk)
- Auto-tuner selects learning rate + LoRA rank per profile
- Checkpoint every 100 steps, keep last 3

### Subsystem 4: KTO Preference Alignment (Phase 5)
**Goal**: Align model outputs with user preferences using binary feedback.

Files to create:
- `Epistemos/KnowledgeFusion/FeedbackLogger.swift` — Logs user accept/reject/edit signals
- `Epistemos/KnowledgeFusion/KTOTrainer.swift` — Kahneman-Tversky Optimization (NOT DPO)

Key constraints:
- KTO uses binary (good/bad) feedback, not pairwise preferences
- Feedback collected passively from: note chat accept/discard, AI context menu edits
- Training triggered when feedback buffer reaches 500+ examples
- Loss weighting: 70% positive, 30% negative (prevent mode collapse)

### Subsystem 5: Adapter Routing (Phase 6+)
**Goal**: Hot-swap the right LoRA adapter based on the task.

Already stubbed in `skill_engine.rs`. Wire to MoLoRA router from Omega.

## PRIORITY ORDER

1. **Phase 2: Document chunking** — Get vault notes into chunks
2. **Phase 3: Synthetic data generation** — Generate instruction-response pairs
3. **Phase 4: QLoRA training** — Train on-device with MLX
4. **Phase 5: KTO alignment** — Preference learning from user feedback
5. **Phase 6+: Routing, autoresearch** — Later

## VERIFICATION

After each phase:
```bash
# Rust tests
cd epistemos-core && cargo test

# Swift build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep "BUILD"

# Then manually test:
# 1. Open Settings > Knowledge Fusion
# 2. Trigger a vault analysis
# 3. Check that chunks are generated
# 4. Verify JSONL output format
```

## KEY FILES TO READ FIRST

```bash
cat docs/knowledge-fusion/architecture.md
cat epistemos-core/src/lib.rs
cat epistemos-core/src/vault_analyzer.rs
cat epistemos-core/src/classifier.rs
cat epistemos-core/src/boilerplate_filter.rs
cat epistemos-core/uniffi/epistemos_core.udl
cat Epistemos/Omega/Orchestrator/OmegaTrainingCoordinator.swift
```
