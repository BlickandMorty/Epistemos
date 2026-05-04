# On-Device Personal AI Training System — Claude Code Execution Prompt

## Epistemos · Knowledge Fusion Engine · macOS · Apple Silicon

---

> **READING INSTRUCTIONS FOR CLAUDE CODE**
>
> This document is an engineering specification for extending an EXISTING, production codebase. Read it in full before writing a single line of code. You are working in a MATURE application — Epistemos already has a V1 training pipeline, synthetic data generation, adapter management, autoresearch loop, evaluation framework, and a full SwiftUI training UI.
>
> Your job is to BUILD ON TOP of what exists. Every modification references exact file names, actor names, and type signatures from the codebase. If this spec says "extend `QLoRATrainer`", that actor already exists and you MUST read it before touching it.
>
> **Total estimated implementation time**: 60-80 hours across 10 phases.
> **Do not attempt to implement more than one phase per session.**

---

## SECTION 0: IDENTITY & CODEBASE ORIENTATION

You are Claude Code operating as the principal systems engineer for **Epistemos**, a local-first knowledge management engine built on macOS with the following technology stack:

| Layer | Technology | Role |
|:------|:-----------|:-----|
| UI | SwiftUI 6 | All user-facing views, training dashboard, settings |
| State | @MainActor @Observable classes | Bridge between views and services |
| Compute Backbone | Rust (via `graph-engine-bridge/graph_engine.h` FFI) | Graph physics, rendering, analysis, scheduling |
| GPU Compute | Metal compute shaders | Embedding generation, vector similarity |
| ML Training | MLX (Python, via `Process()` bridge from Swift) | QLoRA fine-tuning, inference, adapter management |
| Local Inference | MLX-LM + Apple Intelligence (TriageService) | Model loading, generation, adapter hot-swap |
| Data Sync | Loro CRDTs | Conflict-free replicated vault state |

### Hardware Constraints — M2 Pro 18GB (HARD LIMITS)

```
┌─────────────────────────────────────────────────────────────────┐
│  APPLE SILICON M2 PRO — 18GB UNIFIED MEMORY                    │
│                                                                 │
│  Total Unified Memory:     18,432 MB                            │
│  macOS + System Overhead:  ~3,500 MB                            │
│  Epistemos App Footprint:  ~1,500 MB                            │
│  ─────────────────────────────────────────────                  │
│  Available for Training:   ~13,400 MB                           │
│                                                                 │
│  Model Memory Budgets:                                          │
│    0.8B Q4:   ~600 MB  model + ~400 MB  training overhead       │
│    1.0B Q4:   ~800 MB  model + ~500 MB  training overhead       │
│    3.0B Q4:  ~2,200 MB model + ~1,500 MB training overhead      │
│    8.0B Q4:  ~5,500 MB model + ~3,000 MB training overhead      │
│                                                                 │
│  SAFE TRAINING CEILING: 11,500 MB (leaves 1,900 MB headroom)   │
│  ABSOLUTE MAXIMUM:      13,000 MB (risk of OOM kill)            │
│                                                                 │
│  Available Disk: Assume 50GB minimum for models + adapters      │
│  GPU Cores: 19 (16 performance + 3 efficiency)                  │
│  Neural Engine: 16-core (not used for MLX training)             │
│  Memory Bandwidth: 200 GB/s                                     │
└─────────────────────────────────────────────────────────────────┘
```

**Memory Rule**: Before any training run, compute `model_size_bytes + (lora_rank * num_layers * 2 * hidden_dim * dtype_size) + batch_size * seq_len * hidden_dim * 4`. If the result exceeds 11,500 MB, reduce batch size first, then LoRA rank, then sequence length. Never reduce below batch_size=1, rank=4, seq_len=512.

### Existing Architecture (from Engineering Bible — 08-CLAUDE-8.md)

```
User → SwiftUI Views → @Observable State → Services (Engine/) → Rust FFI (graph-engine/)
                                         → SwiftData (Models/)
                                         → Apple Intelligence (TriageService)
```

**Key Files by Subsystem**:

| Subsystem | Start Here | Then Read |
|-----------|-----------|-----------|
| AI Pipeline | `Engine/TriageService.swift` | `Engine/PipelineService.swift`, `Engine/LLMService.swift` |
| Graph | `Graph/GraphState.swift` | `Graph/GraphStore.swift`, `Graph/GraphBuilder.swift` |
| Graph Engine (Rust) | `graph-engine/src/lib.rs` | `src/renderer.rs`, `src/physics.rs`, `src/types.rs` |
| Environment | `App/AppEnvironment.swift` | `App/AppBootstrap.swift`, `App/EpistemosApp.swift` |
| Vault Sync | `Sync/VaultSyncService.swift` | `Sync/NoteFileStorage.swift` |
| Models | `Models/SDPage.swift` | `Models/SDGraphNode.swift`, `Models/GraphTypes.swift` |

### Existing File Layout

| Purpose | Location |
|---------|----------|
| App bootstrap + environment | `Epistemos/App/` |
| State classes (@Observable) | `Epistemos/State/` |
| Services (AI, pipeline, triage) | `Epistemos/Engine/` |
| Graph state + builder | `Epistemos/Graph/` |
| Graph engine (Rust) | `graph-engine/src/` |
| FFI bridge header | `graph-engine-bridge/graph_engine.h` |
| SwiftData models | `Epistemos/Models/` |
| Vault sync + file I/O | `Epistemos/Sync/` |
| Views | `Epistemos/Views/` |
| Theme + modifiers | `Epistemos/Theme/` |
| Tests (Swift) | `EpistemosTests/` |

### WHAT ALREADY EXISTS — V1 Training Pipeline

You MUST read and understand all of these before writing code. They are the foundation you extend.

**Swift Actors and Types** (read files 01-05):

| Actor / Type | File | Purpose |
|:-------------|:-----|:--------|
| `QLoRATrainer` actor | `01-current-training-pipeline.swift` | Swift→Python process bridge via `Process()`, parses mlx-lm stdout for progress |
| `TrainingProgressParser` | `01-current-training-pipeline.swift` | Parses `Iter N: train loss X.XXX, learning_rate X.Xe-XX` from stdout |
| `TrainingProgress` struct | `01-current-training-pipeline.swift` | `(iteration, totalIterations, loss, learningRate, estimatedTimeRemaining)` |
| `AdapterMetadata` struct | `01-current-training-pipeline.swift` | Codable metadata: adapterType, sourceVault, loraRank, loraAlpha, targetModules, lr, numExamples, numIters, trainingDurationSeconds, createdAt, baseModel, qualityScore |
| `TrainingProfileManager` | `01-current-training-pipeline.swift` | Analyzes JSONL content distribution → recommends knowledge/style/mixed profile |
| `TrainingProfile` enum | `01-current-training-pipeline.swift` | `.knowledge`, `.style`, `.mixed` |
| `SyntheticDataGenerator` actor | `02-synthetic-data-pipeline-2.swift` | Orchestrates backtranslation pipeline on `[TextChunk]` |
| `InstructionBacktranslator` actor | `02-synthetic-data-pipeline-2.swift` | 3-step Self-Instruct: query generation → response rewriting → quality scoring (1-5) |
| `KFInferenceProvider` protocol | `02-synthetic-data-pipeline-2.swift` | `generate(prompt:systemPrompt:maxTokens:) async throws -> String` |
| `QualityCurator` struct | `02-synthetic-data-pipeline-2.swift` | Quality filtering (≥3), SHA-256 dedup, classification (knowledge/style/tool by heuristics), 10% eval holdout |
| `GeneratedPair` struct | `02-synthetic-data-pipeline-2.swift` | `(question, answer, qualityScore: Int, sourceChunkId: UUID, sourceChunkText)` |
| `TrainingPair` struct | `02-synthetic-data-pipeline-2.swift` | `(messages: [ChatMessage], category: TrainingPairCategory, qualityScore, sourceChunkId)` |
| `TrainingPairCategory` enum | `02-synthetic-data-pipeline-2.swift` | `.knowledge`, `.style`, `.tool` (CaseIterable) |
| `AdapterRegistry` actor | `03-adapter-autoresearch-3.swift` | CRUD for `[AdapterRecord]`, persisted to `adapter_registry.json`, atomic write via temp file + rename |
| `AdapterRecord` struct | `03-adapter-autoresearch-3.swift` | `(id: UUID, name, type: AdapterType, adapterPath: URL, metadataPath, sourceVault, createdAt, qualityScore, isActive, baseModel, loraRank, parameterCount, trainingExamples)` |
| `AdapterType` enum | `03-adapter-autoresearch-3.swift` | `.knowledge`, `.style`, `.tool`, `.kto` |
| `AdapterRouter` struct | `03-adapter-autoresearch-3.swift` | Explicit/Automatic/MoLoRA routing modes (MoLoRA is scaffold only) |
| `AutoresearchLoop` actor | `03-adapter-autoresearch-3.swift` | PROPOSE→TRAIN→EVALUATE→KEEP/DISCARD, varies rank/lr/replay/curriculum |
| `MetricEvaluator` actor | `03-adapter-autoresearch-3.swift` | KUP Framework: direct probing + indirect probing + style evaluation (token overlap F1) |
| `EvaluationDataset` struct | `03-adapter-autoresearch-3.swift` | `(directProbes, indirectProbes, styleHeldOut)` |
| `EvaluationScore` struct | `03-adapter-autoresearch-3.swift` | `(directProbingScore, indirectProbingScore, styleScore, compositeScore)` — weights: 0.5/0.3/0.2 |
| `KnowledgeFusionViewModel` | `04-kf-viewmodel-ui-4.swift` | `@MainActor @Observable`, bridges all phases to SwiftUI, persistent detached training task |
| `TrainOnVaultView` | `04-kf-viewmodel-ui-4.swift` | Full SwiftUI training UI: vault selection, advanced settings, progress, environment setup |
| `VaultParser` actor | `05-ingestion-python-env-5.swift` | Parses .md, .pdf, .txt, .audio files from vault directories |
| `DocumentChunker` struct | `05-ingestion-python-env-5.swift` | Markdown header-based chunking, paragraph chunking for PDF/text, token estimation at 1.3x words |
| `TextChunk` struct | `05-ingestion-python-env-5.swift` | `(id: UUID, documentId, chunkIndex, text, heading, estimatedTokenCount, chunkType: ChunkType)` |
| `ParsedDocument` struct | `05-ingestion-python-env-5.swift` | `(id: UUID, sourceURL, fileType: DocumentFileType, rawText, metadata: DocumentMetadata)` |
| `PythonEnvironmentManager` | `05-ingestion-python-env-5.swift` | `@MainActor @Observable`, creates isolated venv, installs mlx/mlx-lm, deploys training scripts |

**Python Training Scripts** (read file 06):

| Script | File | Purpose |
|:-------|:-----|:--------|
| `train_knowledge.py` | `06-python-training-scripts-6.swift` | QLoRA targeting ALL 7 modules (q/k/v/o/gate/up/down_proj), rank=16, alpha=32, lr=2e-5 |
| `train_style.py` | `06-python-training-scripts-6.swift` | QLoRA targeting attention-only (q/k/v/o_proj), rank=8, alpha=16, lr=1e-5 |

**Supporting Types** (referenced but not shown in full):

- `ExperimentResult`, `ExperimentTracker`, `TrainingConfig` — used by `AutoresearchLoop`
- `TrainingScheduler`, `AdapterLoader`, `FeedbackLogger`, `FeedbackType` — used by `KnowledgeFusionViewModel`
- `MLXInferenceBridge` — conforms to `KFInferenceProvider`, wraps `TriageService`

### Existing Training Flow (V1 — what the user already has)

```
User clicks "Start Training" in TrainOnVaultView
  → KnowledgeFusionViewModel.startTrainingOnVault()
    → Detached Task (survives view navigation)
      → Phase 1: VaultParser.parseVault() → [ParsedDocument]
      → Phase 1: DocumentChunker.chunkAll() → [TextChunk]
      → Phase 2: SyntheticDataGenerator.generate(chunks:) → SyntheticDataResult
        → InstructionBacktranslator.backtranslate(chunk:) for each chunk
        → QualityCurator.curate(pairs:) → CurationResult
        → QualityCurator.writeJSONL() → training files by category
      → Phase 3: TrainingProfileManager.recommend() → TrainingProfileRecommendation
      → Phase 4: PythonEnvironmentManager.deployScripts()
      → Phase 4: QLoRATrainer.trainKnowledgeAdapter() or .trainStyleAdapter()
        → Process() invokes train_knowledge.py or train_style.py
        → TrainingProgressParser reads stdout in real-time
      → Phase 5: AdapterRegistry.register(record)
      → Phase 5: AdapterRegistry.setActive(record.id, active: true)
```

### WHAT NEEDS TO BE BUILT (the gaps)

The research document (`On-Device-AI-Training-System-Research.md`) and roadmap (`07-research-roadmap-7.md`) describe capabilities that DO NOT yet exist. Your job is to build these ON TOP of the existing infrastructure:

| Gap | What's Missing | Existing Foundation to Extend |
|:----|:---------------|:------------------------------|
| **GAP 1: Vault Content Analysis Engine** | Document classification (prose/code/technical/mixed), MTLD lexical diversity, dual-bound token estimation, vocabulary richness scoring | `VaultParser` only classifies by file extension; `DocumentChunker.estimateTokens()` uses simple 1.3x multiplier |
| **GAP 2: Data-Aware Hyperparameter Auto-Tuning** | Dynamic LoRA rank from MTLD + Fisher, automated epoch/batch/lr/weight-decay formulas | `TrainingProfileManager` uses static thresholds; rank is hardcoded (16 knowledge, 8 style) or user-configured via `KnowledgeFusionViewModel` |
| **GAP 3: Code Repository Analysis** | Tree-sitter AST parsing, function signature extraction, architectural pattern detection, boilerplate filtering | No code analysis exists — `VaultParser` only handles .md/.pdf/.txt/.audio |
| **GAP 4: Negative Example Generation** | Adversarial mutation of correct code, discriminator for contrastive learning | No negative example generation at all |
| **GAP 5: Skill File Generation** | YAML frontmatter + Markdown body skill files, 500-line limit, progressive disclosure | No skill file generation |
| **GAP 6: Dynamic System Prompt Composition** | Multi-retriever fan-out (BM25 + semantic), LightGBM ranking, priority ordering, context pruning | No retrieval or prompt composition system |
| **GAP 7: Auto-Learn Scheduled Training** | FSEvents monitoring, tiered schedule (continuous/nightly/weekly/user-triggered), DPO signals, energy-aware training | `AutoresearchLoop` exists but is manual-trigger only; `FeedbackLogger` collects signals but doesn't trigger training; `TrainingScheduler` is referenced but implementation unknown |

---

## SECTION 1: CORE IMPLEMENTATION — PHASED EXECUTION

Each phase is a self-contained unit of work. **Do not skip phases. Do not reorder phases.** Dependencies are explicit. Each phase specifies which EXISTING files to MODIFY and which NEW files to CREATE.

---

### PHASE 0: DEPENDENCY AUDIT & RUST WORKSPACE SETUP

#### OBJECTIVE
Establish the Rust crate for new compute-intensive features (vault analysis, auto-tuning, scheduling, BM25, skill engine) alongside the existing `graph-engine/` Rust crate. Set up the Python venv extensions for new training capabilities.

#### CRITICAL CONTEXT
Epistemos ALREADY has a Rust crate at `graph-engine/` with FFI via `graph-engine-bridge/graph_engine.h`. The new crate (`epistemos-core/`) is SEPARATE — it handles training-related compute, not graph rendering. Both crates coexist.

#### FILES TO CREATE (NEW)
```
epistemos-core/Cargo.toml
epistemos-core/src/lib.rs
epistemos-core/src/uniffi_exports.rs
epistemos-core/uniffi/epistemos_core.udl
```

#### FILES TO MODIFY (EXISTING)
- `Epistemos.xcodeproj` or `Package.swift` — add SPM dependencies for Tree-sitter grammars

#### DEPENDENCIES
- None (this is the root phase)

#### OPEN-SOURCE LEVERAGE

| Project | What to Use | How |
|:--------|:------------|:----|
| **bm25 crate** (docs.rs/bm25) | `bm25 = "0.4"` in Cargo.toml | Direct Rust dependency. No porting needed. |
| **Tree-sitter Swift SPM** | Add `SwiftTreeSitter`, `TreeSitterSwift`, `TreeSitterPython`, `TreeSitterRust`, `TreeSitterJavaScript`, `TreeSitterTypeScript` | Direct SPM dependency. |
| **mlx-lm-lora** (github.com/Goekdeniz-Guelmez/mlx-lm-lora) | Clone into `vendor/mlx-lm-lora/`. Add as editable pip install. | Import `mlx_lm_lora.trainer` directly. Do NOT wrap CLI. |
| **kristopherkyle/lexical_diversity** | Clone into `vendor/lexical_diversity/`. Test oracle only. | Rust MTLD port validates against this. |
| **meta-llama/synthetic-data-kit** | Clone into `vendor/synthetic-data-kit/`. Study `src/generators/qa.py`. | Extract QA generation patterns for vault-specific pair generation. |
| **notify crate** (docs.rs/notify) | `notify = "6"` in Cargo.toml | FSEvents wrapper for macOS file monitoring. |
| **sift** (Alexander Kwiatkowski) | BLAKE3 content-addressable manifest pattern | `blake3::hash()` for incremental vault analysis. |

#### CODE PATTERNS

**Cargo.toml** (new crate, separate from graph-engine):
```toml
[package]
name = "epistemos-core"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "staticlib"]
name = "epistemos_core"

[dependencies]
uniffi = { version = "0.28", features = ["cli"] }
regex = "1"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_yaml = "0.9"
bm25 = "0.4"
notify = "6"
chrono = { version = "0.4", features = ["serde"] }
blake3 = "1"
tokio = { version = "1", features = ["full"] }
tracing = "0.1"
tracing-subscriber = "0.3"
thiserror = "1"
walkdir = "2"
rand = "0.8"

[build-dependencies]
uniffi = { version = "0.28", features = ["build"] }
```

**IMPORTANT**: Do NOT add `pyo3` to the Rust crate. The existing codebase uses Swift `Process()` to invoke Python scripts, NOT PyO3. Follow the existing pattern. The bridge is `QLoRATrainer` → `Process(pythonPath, arguments)` → `train_knowledge.py` / `train_style.py`.

#### ANTI-PATTERNS
1. **DO NOT** install PyTorch. MLX is the only training framework on Apple Silicon.
2. **DO NOT** create a monolithic `main.rs`. Every subsystem gets its own module directory.
3. **DO NOT** hardcode file paths. Use the `PythonEnvironmentManager` pattern for path resolution.
4. **DO NOT** use `unwrap()` in production Rust code. Use `thiserror` for typed errors, `?` for propagation.
5. **DO NOT** use `pyo3` — the existing codebase uses `Process()` for Python interop and that pattern works.

#### VERIFICATION CHECKPOINT
```bash
# Rust crate compiles:
cd epistemos-core && cargo check 2>&1 | tail -1
# Expected: "Finished `dev` profile [unoptimized + debuginfo] target(s)"

# Existing graph-engine still compiles:
cd graph-engine && cargo test 2>&1 | tail -1
# Expected: all 549 tests pass

# Swift project builds with new SPM packages:
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -1
# Expected: "BUILD SUCCEEDED"
```

#### PHASE GATE
**Do not proceed to Phase 1 until:**
- [ ] `cargo check` passes for `epistemos-core` with zero errors
- [ ] `graph-engine` tests still pass (no regressions)
- [ ] Swift project builds with Tree-sitter SPM packages resolved
- [ ] UniFFI generates Swift bindings from the `.udl` file without errors
- [ ] `PythonEnvironmentManager.shared.isReady` returns true with mlx + mlx-lm installed

---

### PHASE 1: VAULT CONTENT ANALYSIS ENGINE

#### OBJECTIVE
Build the Rust-native vault analysis pipeline: document classification (prose/code/technical/mixed), dual-bound token estimation, and bi-directional MTLD lexical diversity scoring. This is the foundation for all downstream auto-tuning decisions. These capabilities EXTEND what `VaultParser` and `DocumentChunker` already do.

#### FILES TO CREATE (NEW)
```
epistemos-core/src/vault_analyzer/mod.rs
epistemos-core/src/vault_analyzer/classifier.rs
epistemos-core/src/vault_analyzer/token_estimator.rs
epistemos-core/src/vault_analyzer/mtld.rs
epistemos-core/src/vault_analyzer/boilerplate_filter.rs
epistemos-core/tests/vault_analyzer_tests.rs
```

#### FILES TO MODIFY (EXISTING)
- `DocumentChunker` — Replace `estimateTokens()` (currently `Double(words) * 1.3`) with a call to the Rust dual-bound heuristic via UniFFI, OR replicate the dual-bound formula in Swift: `max(chars / 3.5, words * 1.33)`
- `KnowledgeFusionViewModel.trainOnVault()` — Insert vault analysis step between `VaultParser.parseVault()` and `DocumentChunker.chunkAll()` to compute MTLD, classifications, and token estimates

#### DEPENDENCIES
- Phase 0 complete (Rust workspace compiles, UniFFI bridge available)

#### OPEN-SOURCE LEVERAGE

| Project | What to Extract | Implementation Notes |
|:--------|:----------------|:---------------------|
| **kristopherkyle/lexical_diversity** | `ld.mtld_ma_bid()` algorithm (~200 lines Python) | Port to Rust. Algorithm: (1) scan forward, track TTR in sliding window, (2) when TTR drops below 0.720 threshold, record factor length, (3) repeat backward, (4) average both directions. Use Python package as test oracle — must match within 1%. |
| **sift** (BLAKE3 manifest pattern) | Content-addressable caching | Use `blake3::hash()` on file content. If hash unchanged, skip re-analysis. Makes incremental analysis O(changed_files). |

#### CODE PATTERNS

**Document Classifier** (`classifier.rs`):
```rust
use regex::Regex;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum DocumentType {
    Prose,
    SourceCode,
    TechnicalDocs,
    MixedMedia,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClassificationResult {
    pub doc_type: DocumentType,
    pub code_prose_ratio: f64,
    pub confidence: f64,
    pub line_count: usize,
    pub has_frontmatter: bool,
}

pub struct DocumentClassifier {
    code_keywords: Regex,
    syntax_operators: Regex,
    markdown_headers: Regex,
    fenced_code: Regex,
    frontmatter: Regex,
    import_statements: Regex,
}

impl DocumentClassifier {
    pub fn new() -> Self {
        Self {
            code_keywords: Regex::new(
                r"\b(fn|func|def|class|struct|enum|import|use|let|var|const|return|if|else|for|while|match|switch|case|try|catch|throw|async|await|pub|private|internal|override|static|self|Self|super|where|protocol|extension|impl|trait|interface|type|namespace|module|package|from|as|in|of|new|delete|typeof|instanceof)\b"
            ).expect("valid regex"),
            syntax_operators: Regex::new(
                r"(->|=>|::|\.\.\.|\.\.|\?\.|<[A-Z]\w*>|\{\{|\}\}|\|>|&&|\|\||!=|==|>=|<=|\+=|-=|\*=|/=)"
            ).expect("valid regex"),
            markdown_headers: Regex::new(r"(?m)^#{1,6}\s").expect("valid regex"),
            fenced_code: Regex::new(r"(?m)^```").expect("valid regex"),
            frontmatter: Regex::new(r"(?s)\A---\n.*?\n---").expect("valid regex"),
            import_statements: Regex::new(
                r"(?m)^(import\s|from\s\S+\simport|use\s|#include|require\(|@import)"
            ).expect("valid regex"),
        }
    }

    pub fn classify(&self, content: &str) -> ClassificationResult {
        let lines: Vec<&str> = content.lines().collect();
        let total_lines = lines.len();
        let total_chars = content.len() as f64;
        if total_chars == 0.0 {
            return ClassificationResult {
                doc_type: DocumentType::Prose,
                code_prose_ratio: 0.0,
                confidence: 0.0,
                line_count: 0,
                has_frontmatter: false,
            };
        }

        let code_keyword_count = self.code_keywords.find_iter(content).count() as f64;
        let syntax_op_count = self.syntax_operators.find_iter(content).count() as f64;
        let header_count = self.markdown_headers.find_iter(content).count() as f64;
        let fenced_count = self.fenced_code.find_iter(content).count() as f64;
        let has_frontmatter = self.frontmatter.is_match(content);

        let punct_count = content.chars()
            .filter(|c| matches!(c, '.' | ',' | ';' | '!' | '?' | ':' | '"' | '\''))
            .count() as f64;
        let punct_density = punct_count / (total_chars / 100.0);

        let indented_lines = lines.iter()
            .filter(|l| l.starts_with("    ") || l.starts_with('\t'))
            .count() as f64;
        let indent_ratio = indented_lines / total_lines.max(1) as f64;

        let code_signal = code_keyword_count + syntax_op_count + (indent_ratio * 50.0);
        let prose_signal = (punct_density * 10.0) + (header_count * 3.0);
        let ratio = if prose_signal > 0.0 { code_signal / prose_signal } else { code_signal };

        let (doc_type, confidence) = if ratio > 3.0 && indent_ratio > 0.3 {
            (DocumentType::SourceCode, (ratio / 10.0).min(1.0))
        } else if ratio < 0.3 && header_count < 5.0 && punct_density > 2.0 {
            (DocumentType::Prose, ((1.0 - ratio) / 1.0).min(1.0))
        } else if header_count > 3.0 && fenced_count > 0.0 {
            (DocumentType::TechnicalDocs, 0.7 + (header_count / 50.0).min(0.3))
        } else {
            (DocumentType::MixedMedia, 0.5)
        };

        ClassificationResult { doc_type, code_prose_ratio: ratio, confidence, line_count: total_lines, has_frontmatter }
    }
}
```

**Token Estimator** (`token_estimator.rs`) — replaces `DocumentChunker.estimateTokens()`:
```rust
/// Dual-bound token estimation heuristic.
/// Uses max(chars/3.5, words*1.33) per document.
/// - chars/3.5 accounts for subword tokenization of dense text (code, math)
/// - words*1.33 accounts for natural language with longer words
///
/// The EXISTING DocumentChunker uses `Double(words) * 1.3` — this is the upgraded formula.
pub fn estimate_tokens(content: &str) -> usize {
    let char_estimate = (content.len() as f64 / 3.5).ceil() as usize;
    let word_count = content.split_whitespace().count();
    let word_estimate = (word_count as f64 * 1.33).ceil() as usize;
    char_estimate.max(word_estimate)
}
```

**Boilerplate Filter** (`boilerplate_filter.rs`) — filters low-value content before training:
```rust
use regex::Regex;

/// Identifies and filters boilerplate content that would degrade training quality.
/// Boilerplate includes: auto-generated code, import blocks, test fixtures,
/// license headers, and repetitive structural patterns.
pub struct BoilerplateFilter {
    auto_generated: Regex,
    license_header: Regex,
    import_block: Regex,
    test_fixture: Regex,
    min_content_lines: usize,
}

#[derive(Debug, Clone)]
pub struct FilterResult {
    pub original_lines: usize,
    pub filtered_lines: usize,
    pub removed_categories: Vec<String>,
    pub filtered_content: String,
}

impl BoilerplateFilter {
    pub fn new() -> Self {
        Self {
            auto_generated: Regex::new(
                r"(?i)(auto[- ]?generated|do not edit|generated by|machine generated|THIS FILE IS GENERATED)"
            ).expect("valid regex"),
            license_header: Regex::new(
                r"(?s)(^/\*\*?\s*\n(\s*\*.*\n)*\s*\*/|^//.*(?:license|copyright|MIT|Apache|GPL).*(?:\n//.*)*)"
            ).expect("valid regex"),
            import_block: Regex::new(
                r"(?m)^(import\s|from\s\S+\simport|use\s|#include|require\(|@import).*$"
            ).expect("valid regex"),
            test_fixture: Regex::new(
                r"(?i)(mock|stub|fake|fixture|test_data|sample_data)"
            ).expect("valid regex"),
            min_content_lines: 5,
        }
    }

    pub fn filter(&self, content: &str, file_path: &str) -> FilterResult {
        let original_lines = content.lines().count();
        let mut removed: Vec<String> = Vec::new();
        let mut filtered = content.to_string();

        // Check for auto-generated file marker in first 50 lines
        let first_50: String = content.lines().take(50).collect::<Vec<_>>().join("\n");
        if self.auto_generated.is_match(&first_50) {
            removed.push("auto-generated file".into());
            return FilterResult { original_lines, filtered_lines: 0, removed_categories: removed, filtered_content: String::new() };
        }

        // Remove license headers
        if let Some(m) = self.license_header.find(&filtered) {
            removed.push("license header".into());
            filtered = filtered[m.end()..].to_string();
        }

        // Remove dense import blocks (>5 consecutive imports)
        let import_lines: Vec<usize> = filtered.lines().enumerate()
            .filter(|(_, l)| self.import_block.is_match(l))
            .map(|(i, _)| i).collect();
        if import_lines.len() > 5 {
            removed.push(format!("import block ({} lines)", import_lines.len()));
            let lines: Vec<&str> = filtered.lines().enumerate()
                .filter(|(i, _)| !import_lines.contains(i))
                .map(|(_, l)| l).collect();
            filtered = lines.join("\n");
        }

        // Skip test fixtures
        if file_path.contains("test") || file_path.contains("spec") {
            if self.test_fixture.is_match(&filtered) {
                let density = self.test_fixture.find_iter(&filtered).count() as f64
                    / filtered.lines().count().max(1) as f64;
                if density > 0.1 {
                    removed.push("test fixture heavy".into());
                    filtered = String::new();
                }
            }
        }

        FilterResult {
            original_lines,
            filtered_lines: filtered.lines().count(),
            removed_categories: removed,
            filtered_content: filtered,
        }
    }
}
```

**Vault Analyzer Coordinator** (`mod.rs`) — orchestrates all analysis:
```rust
pub mod classifier;
pub mod token_estimator;
pub mod mtld;
pub mod boilerplate_filter;

use classifier::{DocumentClassifier, ClassificationResult};
use token_estimator::estimate_tokens;
use mtld::{mtld_ma_bid, tokenize_for_mtld, DEFAULT_MTLD_THRESHOLD};
use boilerplate_filter::BoilerplateFilter;
use std::collections::HashMap;
use std::path::Path;

#[derive(Debug, Clone, serde::Serialize)]
pub struct VaultAnalysis {
    pub total_files: usize,
    pub total_tokens: usize,
    pub mtld_score: f64,
    pub classifications: HashMap<String, ClassificationResult>,
    pub content_hashes: HashMap<String, String>,
    pub prose_ratio: f64,
    pub code_ratio: f64,
    pub technical_ratio: f64,
    pub mixed_ratio: f64,
}

pub struct VaultAnalyzer {
    classifier: DocumentClassifier,
    filter: BoilerplateFilter,
    cache: HashMap<String, (String, ClassificationResult)>,
}

impl VaultAnalyzer {
    pub fn new() -> Self {
        Self {
            classifier: DocumentClassifier::new(),
            filter: BoilerplateFilter::new(),
            cache: HashMap::new(),
        }
    }

    /// Analyze the entire vault. Uses BLAKE3 content hashing for incremental analysis.
    pub fn analyze_vault(&mut self, vault_path: &Path) -> Result<VaultAnalysis, VaultError> {
        let mut files: Vec<(String, String)> = Vec::new();
        let mut classifications: HashMap<String, ClassificationResult> = HashMap::new();
        let mut content_hashes: HashMap<String, String> = HashMap::new();
        let mut all_tokens: Vec<String> = Vec::new();

        for entry in walkdir::WalkDir::new(vault_path)
            .into_iter()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().is_file())
        {
            let path = entry.path();
            let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
            if !matches!(ext, "md" | "swift" | "rs" | "py" | "ts" | "js" | "tsx" | "jsx" | "txt") {
                continue;
            }

            let content = std::fs::read_to_string(path)
                .map_err(|e| VaultError::IoError(e.to_string()))?;
            let hash = blake3::hash(content.as_bytes()).to_hex().to_string();
            let rel_path = path.strip_prefix(vault_path)
                .unwrap_or(path).to_string_lossy().to_string();

            content_hashes.insert(rel_path.clone(), hash.clone());

            // Check cache — skip if unchanged
            if let Some((_, cached)) = self.cache.get(&hash) {
                classifications.insert(rel_path.clone(), cached.clone());
            } else {
                // Filter boilerplate for code files
                let analysis_content = if matches!(ext, "swift" | "rs" | "py" | "ts" | "js") {
                    self.filter.filter(&content, &rel_path).filtered_content
                } else {
                    content.clone()
                };
                let result = self.classifier.classify(&analysis_content);
                self.cache.insert(hash, (rel_path.clone(), result.clone()));
                classifications.insert(rel_path.clone(), result);
            }

            // Accumulate tokens for MTLD
            all_tokens.extend(tokenize_for_mtld(&content));
            files.push((rel_path, content));
        }

        let mtld_score = mtld_ma_bid(&all_tokens, DEFAULT_MTLD_THRESHOLD);
        let total_tokens: usize = files.iter().map(|(_, c)| estimate_tokens(c)).sum();
        let total = classifications.len() as f64;
        let count_type = |dt: &classifier::DocumentType| -> f64 {
            classifications.values().filter(|c| &c.doc_type == dt).count() as f64
        };

        Ok(VaultAnalysis {
            total_files: files.len(),
            total_tokens,
            mtld_score,
            classifications,
            content_hashes,
            prose_ratio: count_type(&classifier::DocumentType::Prose) / total.max(1.0),
            code_ratio: count_type(&classifier::DocumentType::SourceCode) / total.max(1.0),
            technical_ratio: count_type(&classifier::DocumentType::TechnicalDocs) / total.max(1.0),
            mixed_ratio: count_type(&classifier::DocumentType::MixedMedia) / total.max(1.0),
        })
    }
}

#[derive(Debug, thiserror::Error)]
pub enum VaultError {
    #[error("IO error: {0}")]
    IoError(String),
    #[error("Analysis error: {0}")]
    AnalysisError(String),
}
```

**MTLD Algorithm** (`mtld.rs`) — entirely new:
```rust
use std::collections::HashSet;

/// Bi-directional MTLD. Port of kristopherkyle/lexical_diversity.
/// High MTLD (>100) → high lexical diversity → higher intrinsic dimensionality → need more LoRA rank
/// Low MTLD (<50)   → low lexical diversity  → lower intrinsic dimensionality → less rank sufficient
pub fn mtld_ma_bid(tokens: &[String], threshold: f64) -> f64 {
    if tokens.is_empty() { return 0.0; }
    let forward = mtld_ma_one_direction(tokens, threshold);
    let reversed: Vec<String> = tokens.iter().rev().cloned().collect();
    let backward = mtld_ma_one_direction(&reversed, threshold);
    (forward + backward) / 2.0
}

pub const DEFAULT_MTLD_THRESHOLD: f64 = 0.720;

fn mtld_ma_one_direction(tokens: &[String], threshold: f64) -> f64 {
    let n = tokens.len();
    if n == 0 { return 0.0; }
    let mut factor_lengths: Vec<f64> = Vec::new();
    let mut i = 0;
    while i < n {
        let mut types: HashSet<&str> = HashSet::new();
        let mut j = i;
        loop {
            if j >= n {
                let token_count = (j - i) as f64;
                if token_count > 0.0 {
                    let ttr = types.len() as f64 / token_count;
                    if ttr < 1.0 && threshold < 1.0 {
                        let partial = (1.0 - ttr) / (1.0 - threshold);
                        if partial > 0.0 { factor_lengths.push(token_count / partial); }
                    }
                }
                i = j;
                break;
            }
            types.insert(&tokens[j]);
            let token_count = (j - i + 1) as f64;
            let ttr = types.len() as f64 / token_count;
            if ttr <= threshold && token_count > 1.0 {
                factor_lengths.push(token_count);
                i = j + 1;
                break;
            }
            j += 1;
        }
        if i >= n { break; }
    }
    if factor_lengths.is_empty() { return n as f64; }
    let sum: f64 = factor_lengths.iter().sum();
    sum / factor_lengths.len() as f64
}

pub fn tokenize_for_mtld(text: &str) -> Vec<String> {
    text.split_whitespace()
        .map(|w| w.chars().filter(|c| c.is_alphanumeric() || *c == '-' || *c == '\'').collect::<String>().to_lowercase())
        .filter(|w| !w.is_empty())
        .collect()
}
```

**Integration with existing Swift code** — modify `KnowledgeFusionViewModel.trainOnVault()`:
```swift
// EXISTING code in trainOnVault() after parsing:
let parser = VaultParser()
let parseResult = await parser.parseVault(at: vaultURL)
let chunker = DocumentChunker()
let chunks = chunker.chunkAll(documents: parseResult.documents)

// INSERT NEW: Vault analysis step
// Option A: Call Rust via UniFFI for MTLD + classification
// Option B: Port the analysis to Swift (simpler, avoids UniFFI dependency for Phase 1)
let vaultAnalysis = VaultContentAnalyzer.analyze(documents: parseResult.documents)
// vaultAnalysis.mtldScore, vaultAnalysis.totalTokens, vaultAnalysis.classifications
// These feed into Phase 3 auto-tuning
```

#### ANTI-PATTERNS
1. **DO NOT** use Type-Token Ratio (TTR) instead of MTLD. TTR degrades with text length.
2. **DO NOT** invoke an LLM for document classification. Preserve GPU for actual training.
3. **DO NOT** read entire vault into memory simultaneously. Process files via iterator (follow `VaultParser` pattern).
4. **DO NOT** skip BLAKE3 content hashing — without incremental analysis, large vaults take minutes instead of seconds on repeat runs.

#### PHASE GATE
**Do not proceed to Phase 2 until:**
- [ ] Document classifier correctly classifies Swift source, prose markdown, and technical docs
- [ ] MTLD Rust output matches Python oracle within 1% on 3+ test cases
- [ ] Dual-bound token estimator produces higher estimates than the existing `DocumentChunker.estimateTokens()` for code-heavy content
- [ ] BLAKE3 caching skips unchanged files on second run

---

### PHASE 2: ENHANCED SYNTHETIC DATA GENERATOR

#### OBJECTIVE
Extend the EXISTING `SyntheticDataGenerator` / `InstructionBacktranslator` / `QualityCurator` pipeline with two new capabilities: (1) rule-based pair generation strategies that don't require inference (faster, cheaper), and (2) classification-aware strategy selection using Phase 1 vault analysis results.

#### EXISTING CODE TO EXTEND
- `SyntheticDataGenerator` actor (02-synthetic-data-pipeline-2.swift) — currently generates pairs only via LLM backtranslation
- `QualityCurator` (02-synthetic-data-pipeline-2.swift) — currently classifies by content heuristics only

#### FILES TO CREATE (NEW)
```
KnowledgeFusion/Training/RuleBasedPairGenerator.swift
KnowledgeFusion/Training/PairStrategies.swift
```

#### FILES TO MODIFY (EXISTING)
- `SyntheticDataGenerator` — Add a rule-based pre-pass before LLM backtranslation
- `QualityCurator.classifyPair()` — Improve heuristics using Phase 1 document classifications
- `KnowledgeFusionViewModel.trainOnVault()` — Pass vault analysis results to the generator

#### DEPENDENCIES
- Phase 1 complete (vault analysis with classifications available)

#### OPEN-SOURCE LEVERAGE

| Project | What to Extract | Implementation Notes |
|:--------|:----------------|:---------------------|
| **meta-llama/synthetic-data-kit** | QA generation patterns from `src/generators/qa.py` | Study chunking and QA pair extraction. Adapt for vault notes. Use rule-based templates first; LLM refinement in Tier 3. |
| **mlx-lm-lora** | JSONL format spec | Must match `{"messages": [{"role": "user", ...}, {"role": "assistant", ...}]}` — the existing `QualityCurator.writeJSONL()` already does this correctly. |

#### CODE PATTERNS

**Rule-Based Pair Generator** (`RuleBasedPairGenerator.swift`):
```swift
/// Generates training pairs WITHOUT inference — pure template-based extraction.
/// Runs before InstructionBacktranslator for fast initial data generation.
/// The existing SyntheticDataGenerator.generate() calls backtranslator for every chunk;
/// this pre-pass generates cheaper pairs from structured content (headers, code blocks).
nonisolated struct RuleBasedPairGenerator: Sendable {

    func generate(
        chunk: TextChunk,
        classification: DocumentType  // From Phase 1 vault analyzer
    ) -> [GeneratedPair] {
        var pairs: [GeneratedPair] = []

        switch classification {
        case .prose, .mixedMedia:
            pairs.append(contentsOf: generateExplanationPairs(chunk: chunk))
            pairs.append(contentsOf: generateContinuationPairs(chunk: chunk))
            pairs.append(contentsOf: generateHeaderQAPairs(chunk: chunk))
        case .sourceCode:
            pairs.append(contentsOf: generateCodeExplanationPairs(chunk: chunk))
        case .technicalDocs:
            pairs.append(contentsOf: generateExplanationPairs(chunk: chunk))
            pairs.append(contentsOf: generateHeaderQAPairs(chunk: chunk))
            pairs.append(contentsOf: generateCodeExplanationPairs(chunk: chunk))
        }

        return pairs
    }

    // Strategy 1: Note explanation from heading
    private func generateExplanationPairs(chunk: TextChunk) -> [GeneratedPair] {
        guard let heading = chunk.heading else { return [] }
        let stem = heading.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
        guard !stem.isEmpty, chunk.text.count > 200 else { return [] }

        return [GeneratedPair(
            question: "Explain the key concepts in my note about \(stem)",
            answer: "Based on your note about \(stem):\n\n\(String(chunk.text.prefix(3000)))",
            qualityScore: 3,  // Passes QualityCurator threshold
            sourceChunkId: chunk.id,
            sourceChunkText: chunk.text
        )]
    }

    // Strategy 2: Writing style continuation
    private func generateContinuationPairs(chunk: TextChunk) -> [GeneratedPair] {
        guard chunk.text.count > 500 else { return [] }
        let paragraphs = chunk.text.components(separatedBy: "\n\n")
        guard paragraphs.count >= 2 else { return [] }
        let mid = paragraphs.count / 2
        let prefix = paragraphs[..<mid].joined(separator: "\n\n")
        let suffix = paragraphs[mid...].joined(separator: "\n\n")
        guard suffix.count > 100 else { return [] }

        return [GeneratedPair(
            question: "Continue writing in my style:\n\n\(String(prefix.prefix(2000)))",
            answer: String(suffix.prefix(2000)),
            qualityScore: 3,
            sourceChunkId: chunk.id,
            sourceChunkText: chunk.text
        )]
    }

    // Strategy 3: Q&A from markdown headers (extracted from chunk's heading)
    private func generateHeaderQAPairs(chunk: TextChunk) -> [GeneratedPair] {
        guard let heading = chunk.heading else { return [] }
        let topic = heading.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
        guard chunk.text.count > 100 else { return [] }

        return [GeneratedPair(
            question: "What do I know about \(topic)?",
            answer: String(chunk.text.prefix(3000)),
            qualityScore: 3,
            sourceChunkId: chunk.id,
            sourceChunkText: chunk.text
        )]
    }

    // Strategy 4: Code block explanation
    private func generateCodeExplanationPairs(chunk: TextChunk) -> [GeneratedPair] {
        // Extract fenced code blocks from chunk text
        let pattern = try? NSRegularExpression(pattern: "```(\\w*)\\n([\\s\\S]*?)```")
        let range = NSRange(chunk.text.startIndex..., in: chunk.text)
        guard let matches = pattern?.matches(in: chunk.text, range: range) else { return [] }

        return matches.compactMap { match -> GeneratedPair? in
            guard match.numberOfRanges >= 3,
                  let langRange = Range(match.range(at: 1), in: chunk.text),
                  let codeRange = Range(match.range(at: 2), in: chunk.text) else { return nil }
            let lang = String(chunk.text[langRange])
            let code = String(chunk.text[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard code.count > 50, code.count < 5000 else { return nil }

            return GeneratedPair(
                question: "Explain this \(lang.isEmpty ? "code" : lang) and the design decisions behind it:\n\n```\(lang)\n\(code)\n```",
                answer: "This code implements:\n\n```\(lang)\n\(code)\n```",
                qualityScore: 2,  // Lower quality — template response
                sourceChunkId: chunk.id,
                sourceChunkText: chunk.text
            )
        }
    }
}
```

**Modify SyntheticDataGenerator.generate()** to use rule-based pre-pass:
```swift
// In SyntheticDataGenerator.generate(), BEFORE the backtranslation loop:
let ruleGen = RuleBasedPairGenerator()
var rulePairs: [GeneratedPair] = []
for chunk in chunks {
    let classification = vaultAnalysis?.classifications[chunk.documentId] ?? .prose
    rulePairs.append(contentsOf: ruleGen.generate(chunk: chunk, classification: classification))
}
// Merge rule-based pairs with LLM-generated pairs
allPairs.append(contentsOf: rulePairs)
```

#### ANTI-PATTERNS
1. **NEVER** train on raw vault content directly. Raw text trains memorization, not reasoning. Always structured pairs.
2. **NEVER** generate pairs where the assistant response is a generic template placeholder without vault content.
3. **NEVER** create pairs longer than the model's max sequence length. Truncate at natural boundaries.
4. **NEVER** include absolute file system paths in training pairs.

#### PHASE GATE
**Do not proceed to Phase 3 until:**
- [ ] Rule-based generator produces >50 training pairs from a 20-file test vault WITHOUT inference
- [ ] All 4 strategies produce at least one pair each
- [ ] Existing `QualityCurator.writeJSONL()` correctly writes the combined rule + LLM pairs
- [ ] Total pipeline time for a 20-file vault drops by >50% compared to LLM-only generation

---

### PHASE 3: DATA-AWARE AUTO-TUNING ENGINE

#### OBJECTIVE
Replace the static `TrainingProfileManager` recommendations and the hardcoded ranks in `train_knowledge.py` (rank=16) and `train_style.py` (rank=8) with data-driven hyperparameter selection using MTLD from Phase 1.

#### EXISTING CODE TO REPLACE/EXTEND
- `TrainingProfileManager.recommend()` — currently uses line-count ratios to recommend profiles
- `KnowledgeFusionViewModel` — currently exposes manual `loraRank`, `loraAlpha`, `batchSize`, `maxSeqLength`, `learningRate` as user-adjustable properties
- `train_knowledge.py` / `train_style.py` — currently use hardcoded DEFAULT_RANK, DEFAULT_ALPHA, DEFAULT_LR

#### FILES TO CREATE (NEW)
```
epistemos-core/src/auto_tuner/mod.rs
epistemos-core/src/auto_tuner/rank_selector.rs
epistemos-core/src/auto_tuner/hyperparams.rs
epistemos-core/tests/auto_tuner_tests.rs
```

#### FILES TO MODIFY (EXISTING)
- `KnowledgeFusionViewModel` — Replace manual hardware-based `autoConfigureForHardware()` with data-aware auto-tune
- `QLoRATrainer.trainKnowledgeAdapter()` / `.trainStyleAdapter()` — Pass auto-tuned rank/alpha/lr as CLI arguments (the Python scripts ALREADY accept `--lora_rank`, `--lora_alpha`, `--learning_rate` via argparse)
- `TrainingProfileManager` — Enhance with vault analysis data

#### CODE PATTERNS

**LoRA Rank Selector** (`rank_selector.rs`):
```rust
/// Data-aware LoRA rank selection using MTLD as proxy for intrinsic dimensionality.
/// Formula: r = clip(4, 64, round(log2(MTLD) * sqrt(total_tokens / 1000)))
///
/// Reference: LoRA-DA (arXiv:2510.24561), GeLoRA (arXiv:2412.09250v2)
pub fn select_lora_rank(mtld_score: f64, total_tokens: usize) -> u32 {
    if !mtld_score.is_finite() || mtld_score <= 0.0 || total_tokens == 0 {
        return 8; // Safe default
    }
    let log_mtld = mtld_score.log2();
    let token_factor = (total_tokens as f64 / 1000.0).sqrt();
    let raw_rank = (log_mtld * token_factor).round() as u32;
    raw_rank.clamp(4, 64)
}

pub fn select_lora_alpha(rank: u32, dataset_size: usize) -> u32 {
    if dataset_size < 100 { rank * 2 } else { rank }
}

// TODO: Phase 4+ — integrate Fisher Information Matrix estimation
// When available, run a small forward pass on target domain to estimate Fisher
// matrix using K-FAC. Refine MTLD-based rank with Fisher eigenspectrum.
```

**Hyperparameter Auto-Tuner** (`hyperparams.rs`):
```rust
use serde::{Deserialize, Serialize};
use super::rank_selector::{select_lora_rank, select_lora_alpha};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AutoTuneConfig {
    pub lora_rank: u32,
    pub lora_alpha: u32,
    pub epochs: u32,
    pub max_iters: u32,
    pub batch_size: u32,
    pub learning_rate: f64,
    pub warmup_ratio: f64,
    pub weight_decay: f64,
    pub max_seq_length: u32,
    pub estimated_memory_mb: u32,
    pub target_modules: Vec<String>,
    pub adapter_type: String,  // "knowledge" or "style"
}

/// Generate a complete auto-tuned config. Replaces KnowledgeFusionViewModel.autoConfigureForHardware().
pub fn auto_tune(
    dataset_size: usize,
    mtld_score: f64,
    total_tokens: usize,
    model_size_b: f64,
    available_memory_mb: u32,
    profile: &str,  // "knowledge" or "style"
) -> AutoTuneConfig {
    let lora_rank = select_lora_rank(mtld_score, total_tokens);
    let lora_alpha = select_lora_alpha(lora_rank, dataset_size);

    // Target modules follow existing train_knowledge.py / train_style.py patterns
    let target_modules = if profile == "style" {
        vec!["q_proj", "k_proj", "v_proj", "o_proj"]
            .into_iter().map(String::from).collect()
    } else {
        vec!["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"]
            .into_iter().map(String::from).collect()
    };

    let epochs = if dataset_size == 0 { 1 } else { (500 / dataset_size).clamp(1, 3) as u32 };
    let batch_size: u32 = if available_memory_mb >= 32000 { 2 } else { 1 };
    let max_iters = (epochs * dataset_size as u32 / batch_size.max(1)).max(100);

    let learning_rate = match profile {
        "style" => 1e-5,
        _ => match model_size_b as u32 {
            0..=1 => 5e-5,
            2..=3 => 2e-5,
            _ => 1e-5,
        },
    };

    let warmup_ratio = if dataset_size < 100 { 0.10 } else { 0.15 };
    let weight_decay = if dataset_size < 100 { 0.1 } else { 0.05 };
    let max_seq_length = if available_memory_mb < 20000 { 1024 } else { 2048 };

    let model_memory = (model_size_b * 1000.0 * 0.5) as u32; // 4-bit ≈ 0.5 bytes/param
    let lora_memory = (lora_rank * 32 * 2 * 128 * 2 / 1024) as u32;
    let estimated_memory_mb = model_memory + lora_memory + 500;

    AutoTuneConfig {
        lora_rank, lora_alpha, epochs, max_iters, batch_size,
        learning_rate, warmup_ratio, weight_decay, max_seq_length,
        estimated_memory_mb, target_modules,
        adapter_type: profile.to_string(),
    }
}
```

**Modify QLoRATrainer to accept auto-tuned config** — the existing `trainKnowledgeAdapter()` already passes args to `Process()`. Extend the arguments:
```swift
// In QLoRATrainer.runTraining(), extend the arguments array:
var arguments = [
    script.path,
    "--model_path", modelPath.path,
    "--data_path", dataPath.path,
    "--output_path", outputPath.path,
    "--num_iters", String(numIters),
    "--seed", String(seed),
    // NEW: Pass auto-tuned parameters (the Python scripts already accept these via argparse!)
    "--lora_rank", String(autoTuneConfig.loraRank),
    "--lora_alpha", String(autoTuneConfig.loraAlpha),
    "--learning_rate", String(autoTuneConfig.learningRate),
    "--batch_size", String(autoTuneConfig.batchSize),
    "--max_seq_len", String(autoTuneConfig.maxSeqLength),
]
```

**IMPORTANT**: The existing Python scripts (`train_knowledge.py`, `train_style.py`) ALREADY accept `--lora_rank`, `--lora_alpha`, `--batch_size`, `--max_seq_len`, `--learning_rate` as CLI arguments but currently default to hardcoded values. The auto-tuner just needs to pass the computed values.

#### PHASE GATE
**Do not proceed to Phase 4 until:**
- [ ] Auto-tuner produces valid configs for all model sizes (0.8B, 1.0B, 3.0B, 8.0B)
- [ ] Memory estimates never exceed `available_memory_mb`
- [ ] LoRA rank scales with MTLD (verify: higher MTLD → higher rank)
- [ ] Configs serialize to JSON that the Python scripts can consume
- [ ] `KnowledgeFusionViewModel.autoConfigureForHardware()` is replaced or enhanced with auto-tune output

---

### PHASE 4: ENHANCED MLX TRAINING PIPELINE

#### OBJECTIVE
Upgrade the existing Python training scripts to accept the full auto-tuned config, add early stopping via gradient norm monitoring, and improve the `TrainingProgressParser` to report richer metrics.

#### FILES TO MODIFY (EXISTING)
- `train_knowledge.py` — Accept auto-tuned config as JSON file, add early stopping, add warmup schedule
- `train_style.py` — Same enhancements
- `QLoRATrainer` actor — Extended argument passing, richer progress parsing
- `TrainingProgressParser` — Parse validation loss, gradient norm, memory usage

#### FILES TO CREATE (NEW)
```
KnowledgeFusion/Training/scripts/train_auto.py  — Unified training script accepting full JSON config
```

#### CODE PATTERNS

**Unified Training Script** (`train_auto.py`):
```python
#!/usr/bin/env python3
"""
Epistemos Knowledge Fusion — Unified Auto-Tuned Training Script

Replaces separate train_knowledge.py / train_style.py with a single script
that accepts a JSON config from the Rust auto-tuner via CLI.

Invoked by QLoRATrainer.swift via Process().
"""
import argparse
import json
import os
import sys
import time

def parse_args():
    parser = argparse.ArgumentParser(description="Auto-tuned QLoRA training")
    parser.add_argument("--model_path", required=True)
    parser.add_argument("--data_path", required=True)
    parser.add_argument("--output_path", required=True)
    parser.add_argument("--config_json", required=True, help="Path to auto-tuned config JSON")
    parser.add_argument("--seed", type=int, default=42)
    return parser.parse_args()

def main():
    args = parse_args()
    t_start = time.time()

    with open(args.config_json) as f:
        config = json.load(f)

    LORA_RANK = config["lora_rank"]
    LORA_ALPHA = config["lora_alpha"]
    TARGET_MODULES = config["target_modules"]
    LEARNING_RATE = config["learning_rate"]
    WEIGHT_DECAY = config.get("weight_decay", 0.01)
    BATCH_SIZE = config.get("batch_size", 1)
    MAX_SEQ_LEN = config.get("max_seq_length", 1024)
    MAX_ITERS = config.get("max_iters", 200)
    WARMUP_RATIO = config.get("warmup_ratio", 0.10)
    ADAPTER_TYPE = config.get("adapter_type", "knowledge")

    # ... (same training logic as existing train_knowledge.py but parameterized)
    # Key difference: all hyperparameters come from config, not hardcoded

    try:
        import mlx.core as mx
        from mlx_lm.utils import load as mlx_load
        from mlx_lm.tuner.utils import linear_to_lora_layers
        from mlx_lm.tuner.datasets import load_local_dataset, CacheDataset
        from mlx_lm.tuner.trainer import TrainingArgs, train as mlx_train
        import mlx.optimizers as optim
    except ImportError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    mx.random.seed(args.seed)

    # Count examples
    with open(args.data_path) as f:
        num_examples = sum(1 for line in f if line.strip())

    os.makedirs(args.output_path, exist_ok=True)

    # Load model
    print(f"Loading model from {args.model_path}...")
    model, tokenizer = mlx_load(args.model_path)

    # Apply LoRA
    num_layers = len(model.model.layers) if hasattr(model, 'model') else len(model.layers)
    lora_config = {
        "keys": TARGET_MODULES,
        "rank": LORA_RANK,
        "alpha": LORA_ALPHA,
        "dropout": 0.0,
        "scale": LORA_ALPHA / LORA_RANK,
    }
    linear_to_lora_layers(model, num_layers, lora_config)
    print(f"Applied LoRA: rank={LORA_RANK}, alpha={LORA_ALPHA}, targets={TARGET_MODULES}")

    # Prepare data (same pattern as existing scripts)
    from pathlib import Path
    import shutil
    data_dir = Path(args.output_path) / "_training_data"
    data_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.data_path, data_dir / "train.jsonl")

    from types import SimpleNamespace
    dataset_config = SimpleNamespace(max_seq_length=MAX_SEQ_LEN)
    train_set, valid_set, _ = load_local_dataset(
        data_path=data_dir, tokenizer=tokenizer, config=dataset_config)
    train_set = CacheDataset(train_set)
    if valid_set:
        valid_set = CacheDataset(valid_set)

    adapter_file = os.path.join(args.output_path, "adapter_weights.safetensors")
    training_args = TrainingArgs(
        batch_size=BATCH_SIZE,
        iters=MAX_ITERS,
        steps_per_report=10,
        steps_per_eval=0,
        steps_per_save=MAX_ITERS,
        adapter_file=adapter_file,
        max_seq_length=MAX_SEQ_LEN,
    )

    optimizer = optim.AdamW(learning_rate=LEARNING_RATE, weight_decay=WEIGHT_DECAY)

    print("Starting training...")
    model.train()
    mlx_train(model=model, optimizer=optimizer,
              train_dataset=train_set,
              val_dataset=valid_set if valid_set else None,
              args=training_args)

    duration = time.time() - t_start
    metadata = {
        "adapter_type": ADAPTER_TYPE,
        "source_vault": os.path.dirname(args.data_path),
        "lora_rank": LORA_RANK, "lora_alpha": LORA_ALPHA,
        "target_modules": TARGET_MODULES,
        "learning_rate": LEARNING_RATE, "weight_decay": WEIGHT_DECAY,
        "num_examples": num_examples, "num_iters": MAX_ITERS,
        "training_duration_seconds": round(duration, 1),
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "base_model": args.model_path,
        "quality_score": None,
    }
    with open(os.path.join(args.output_path, "training_metadata.json"), "w") as f:
        json.dump(metadata, f, indent=2)
    print(f"Training complete in {duration:.1f}s")

if __name__ == "__main__":
    main()
```

#### PHASE GATE
- [ ] `train_auto.py` accepts JSON config and produces identical output to existing scripts
- [ ] Existing `train_knowledge.py` and `train_style.py` still work (backward compatible)
- [ ] `QLoRATrainer` can invoke either old scripts or new `train_auto.py`
- [ ] Early stopping triggers when gradient norm spikes >3x running average

---

### PHASE 5: SKILL FILE GENERATOR

#### OBJECTIVE
Build the system that converts extracted vault patterns into structured skill files (YAML frontmatter + Markdown body) for dynamic system prompt injection at inference time.

#### FILES TO CREATE (NEW)
```
epistemos-core/src/skill_engine/mod.rs
epistemos-core/src/skill_engine/generator.rs
epistemos-core/src/skill_engine/progressive_disclosure.rs
KnowledgeFusion/Skills/SkillFileManager.swift
```

#### CODE PATTERNS

**Skill File Format**:
```yaml
---
name: error-handling-swift
version: 0.1.0
description: "Defines the user's Swift error handling patterns: do/catch with typed errors, guard let for optionals, never force unwrap."
triggers:
  - "*.swift"
  - error handling
  - guard let
  - do catch
priority: high
---

# Swift Error Handling Patterns

## Golden Rules
1. Always use `do/catch` — NEVER `try!`
2. Always use `guard let` / `if let` — NEVER force unwrap (`!`)
3. `Int(floatValue)` traps on NaN/Infinity — always guard with `.isFinite` first

## Error Types
Define custom error enums conforming to `Error` and `LocalizedError`:
```swift
enum MyError: Error, LocalizedError {
    case notFound(String)
    var errorDescription: String? {
        switch self { case .notFound(let id): return "Not found: \(id)" }
    }
}
```

## Examples
**DO:**
```swift
guard let value = optionalThing else { return }
```
**DO NOT:**
```swift
let value = optionalThing! // CRASH RISK
```
```

**500-line limit with progressive disclosure**: If a skill exceeds 500 lines, split into a primary file (`skill.md`) and reference files (`references/detail-1.md`). References are ONE level deep — no nested references.

#### PHASE GATE
- [ ] Generator produces valid YAML frontmatter + Markdown body
- [ ] All generated skill files are under 500 lines
- [ ] Skill files reflect actual patterns from the Engineering Bible (08-CLAUDE-8.md)

---

### PHASE 6: SYSTEM PROMPT COMPOSER

#### OBJECTIVE
Build the dynamic prompt composition system that selects, ranks, and assembles the most relevant skill files into the system prompt at inference time.

#### FILES TO CREATE (NEW)
```
epistemos-core/src/retrieval/mod.rs
epistemos-core/src/retrieval/bm25_index.rs
epistemos-core/src/retrieval/hybrid_retriever.rs
epistemos-core/src/retrieval/prompt_composer.rs
```

#### CODE PATTERNS

**Prompt Composition Zones**:
```
┌────────────────────────────────────────────────────┐
│  ZONE A: PINNED TOP (always present)               │
│  ├─ Identity and core capabilities                  │
│  ├─ Tool registry (API definitions)                 │
│  └─ Security guardrails                             │
├────────────────────────────────────────────────────┤
│  ZONE B: DYNAMIC MIDDLE (ranked by relevance)      │
│  ├─ Top-scored skill files (via BM25 + ranker)     │
│  ├─ Domain glossaries                               │
│  └─ Writing style profile                           │
├────────────────────────────────────────────────────┤
│  ZONE C: PINNED BOTTOM (always present)            │
│  ├─ Output format constraints                       │
│  └─ "Lost in the middle" anchor instructions       │
└────────────────────────────────────────────────────┘
```

Zone A and C are ALWAYS present. Zone B is dynamically composed from ranked skill files until the token budget is exhausted. This exploits the "lost in the middle" phenomenon — models pay most attention to the start and end of the context.

**BM25 Index** (`bm25_index.rs`):
Use the `bm25` crate directly for lexical keyword search over skill file descriptions and content.

**Hybrid Retrieval**: Fan out to BM25 (lexical) + cosine similarity (semantic) → merge with Reciprocal Rank Fusion → prune to token budget.

#### PHASE GATE
- [ ] BM25 index returns relevant skills for test queries
- [ ] Composed prompt fits within token budget (configurable, default 4096)
- [ ] Zone A and Zone C are always present regardless of query

---

### PHASE 7: CODE REPOSITORY ANALYZER

#### OBJECTIVE
Build the Tree-sitter-based code analysis system that extracts function signatures, error handling patterns, and architectural heuristics from Swift/Python/Rust/JS/TS source files.

#### FILES TO CREATE (NEW)
```
Epistemos/Engine/TreeSitterService.swift
epistemos-core/src/repo_analyzer/mod.rs
epistemos-core/src/repo_analyzer/pattern_detector.rs
epistemos-core/src/repo_analyzer/signature_extractor.rs
```

#### FILES TO MODIFY (EXISTING)
- `VaultParser` actor — Extend supported extensions to include `.swift`, `.rs`, `.py`, `.ts`, `.js`, `.tsx`, `.jsx`
- `DocumentChunker` — Add code-aware chunking (function boundaries, class boundaries)

#### CODE PATTERNS

Tree-sitter queries for Swift error handling (from Engineering Bible patterns):
```scheme
;; Extract do/catch blocks in Swift
(do_statement
  body: (code_block) @try_body
  (catch_clause
    pattern: (_)? @error_pattern
    body: (code_block) @catch_body))

;; Extract function declarations with types
(function_declaration
  name: (simple_identifier) @func_name
  parameters: (parameter_clause) @params
  return_type: (_)? @return_type
  body: (code_block) @body)
```

**Architectural Pattern Detection**:
- `@MainActor @Observable` class + corresponding View → MVVM pattern
- `Engine/` directory with service classes → Service layer
- `graph-engine/` Rust FFI → FFI bridge pattern
- These detections generate skill files automatically

#### PHASE GATE
- [ ] Tree-sitter correctly parses Swift, Python, Rust, JavaScript, TypeScript
- [ ] Function signatures extracted from test files match expected output
- [ ] Pattern detector identifies MVVM in the Epistemos codebase itself

---

### PHASE 8: NEGATIVE EXAMPLE GENERATOR

#### OBJECTIVE
Generate adversarial "hard negative" training pairs from correct code to teach the model what BAD code looks like in the user's codebase style.

#### FILES TO CREATE (NEW)
```
KnowledgeFusion/Training/NegativeExampleGenerator.swift
epistemos-core/src/training/negative_examples.rs
```

#### CODE PATTERNS

**Rule-based mutations** (Phase 1 — no ML required):
1. Variable swapping: Swap two variable names in assignments
2. Off-by-one: Change `<` to `<=` or vice versa in loop bounds
3. Operator toggle: Swap `&&` and `||`, `==` and `!=`
4. Force-unwrap injection: Replace `guard let x = y else { return }` with `let x = y!`
5. Error handling removal: Replace `do { try ... } catch { ... }` with `try! ...`

These mutations are paired with instructions asking the model to identify the error, creating contrastive training pairs.

**Integration with QualityCurator**: Negative pairs get `category: .tool` and are interleaved with positive tool-use pairs at a 1:3 negative:positive ratio.

#### PHASE GATE
- [ ] Generator produces mutations that are syntactically valid but semantically wrong
- [ ] Negative pairs follow the existing `TrainingPair` / `GeneratedPair` format
- [ ] Mutation 4 (force-unwrap injection) correctly targets guard/if-let patterns per Engineering Bible rules

---

### PHASE 9: AUTO-LEARN SCHEDULER

#### OBJECTIVE
Build the tiered automated training system that extends the EXISTING `AutoresearchLoop`, `TrainingScheduler`, and `FeedbackLogger` with FSEvents monitoring, energy-aware scheduling, and DPO signal collection.

#### EXISTING CODE TO EXTEND
- `AutoresearchLoop` actor (03-adapter-autoresearch-3.swift) — already implements PROPOSE→TRAIN→EVALUATE→KEEP/DISCARD
- `FeedbackLogger` — already collects accept/reject signals (referenced in `KnowledgeFusionViewModel`)
- `TrainingScheduler` — referenced in `KnowledgeFusionViewModel.init()` but implementation sparse
- `KnowledgeFusionViewModel` — already has `autoresearchRunning`, `lastExperimentResult` properties

#### FILES TO CREATE (NEW)
```
epistemos-core/src/scheduler/mod.rs
epistemos-core/src/scheduler/fs_watcher.rs
epistemos-core/src/scheduler/tier_scheduler.rs
KnowledgeFusion/AutoLearn/AutoLearnCoordinator.swift
```

#### FILES TO MODIFY (EXISTING)
- `KnowledgeFusionViewModel` — Add auto-learn state, tier display, DPO signal forwarding
- `AutoresearchLoop` — Extend `runOneIteration()` to accept auto-tuned configs from Phase 3

#### CODE PATTERNS

**Tier Architecture**:
```
┌───────────────────────────────────────────────────────────────────────┐
│                    AUTO-LEARN TIER ARCHITECTURE                       │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  TIER 1: CONTINUOUS OBSERVATION (Always On)                           │
│  ├─ FSEvents file watcher on vault directory (notify crate)           │
│  ├─ Dirty-file queue (new/modified files)                             │
│  ├─ Incremental BM25 + embedding index updates                       │
│  ├─ DPO signal collection (from existing FeedbackLogger)             │
│  └─ Trigger: every file save                                          │
│                                                                       │
│  TIER 2: NIGHTLY MICRO-TRAINING (Daily, 2-4 AM)                      │
│  ├─ Condition: dirty_files > 10 OR days_since_last > 3                │
│  ├─ Re-run vault analysis on changed files only (BLAKE3 incremental)  │
│  ├─ Generate new synthetic pairs from changed files                   │
│  ├─ Short LoRA training: 100-300 iters (~15-30 min on M2 Pro)        │
│  ├─ MetricEvaluator.evaluate() vs previous adapter                    │
│  └─ Promote if improved, discard if degraded                          │
│                                                                       │
│  TIER 3: DEEP RETRAINING (Weekly, Sunday 3 AM)                        │
│  ├─ Full vault re-analysis                                            │
│  ├─ Complete synthetic data regeneration                              │
│  ├─ AutoresearchLoop: 5-10 experiments using auto-tuned configs       │
│  ├─ Each experiment: 5 min training + MetricEvaluator.evaluate()      │
│  ├─ Keep best via EvaluationScore.compositeScore                      │
│  ├─ Regenerate skill files from newly discovered patterns             │
│  └─ Rebuild BM25 index                                                │
│                                                                       │
│  TIER 4: USER-TRIGGERED TRAINING (On Demand)                          │
│  ├─ User clicks "Start Training" in TrainOnVaultView                  │
│  ├─ Uses existing KnowledgeFusionViewModel.startTrainingOnVault()     │
│  ├─ Real-time progress via TrainingProgressParser                     │
│  └─ Can cancel via QLoRATrainer.cancelTraining()                      │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

**AutoLearnCoordinator** (Swift, follows `@MainActor @Observable` pattern):
```swift
@MainActor @Observable
final class AutoLearnCoordinator {
    static let shared = AutoLearnCoordinator()

    var currentTier: AutoLearnTier = .observing
    var dirtyFileCount: Int = 0
    var nextScheduledTraining: Date?
    var isTraining = false
    var lastTrainingResult: String?

    private let registry: AdapterRegistry
    private let evaluator: MetricEvaluator
    private var fsWatcherTask: Task<Void, Never>?

    enum AutoLearnTier: String {
        case observing = "Monitoring vault changes..."
        case microTraining = "Nightly micro-training"
        case deepRetraining = "Weekly deep retraining"
        case userTriggered = "Manual training"
    }

    func startMonitoring(vaultURL: URL) {
        // Start FSEvents watcher via Rust/UniFFI (notify crate)
        // or via Swift DispatchSource.makeFileSystemObjectSource
        fsWatcherTask = Task.detached { [weak self] in
            // Monitor vault directory for changes
            // When files change, increment dirtyFileCount
        }
    }

    /// Called periodically (e.g., every 30 minutes) to check if training should run
    func evaluateSchedule() async {
        guard !isTraining else { return }

        // Energy check: defer on battery
        guard isPluggedIn() else { return }

        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let weekday = Calendar.current.component(.weekday, from: now)

        // Tier 3: Weekly deep (Sunday 3 AM)
        if weekday == 1 && hour == 3 {
            await runDeepRetraining()
            return
        }

        // Tier 2: Nightly micro (2-4 AM, dirty threshold met)
        if (2...4).contains(hour) && dirtyFileCount > 10 {
            await runMicroTraining()
            return
        }
    }

    private func isPluggedIn() -> Bool {
        // Use IOKit or `pmset -g batt` to check power source
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "batt"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return !output.contains("Battery Power")
    }
}
```

**Experiment Runner for Tier 3 Deep Retraining** — extends `AutoresearchLoop`:
```swift
/// Runs a batch of autoresearch experiments during Tier 3 deep retraining.
/// Uses the EXISTING AutoresearchLoop but with auto-tuned base configs from Phase 3.
///
/// Inspired by Karpathy's autoresearch: 126 experiments, 11% improvement, zero human involvement.
/// Our version: 5-10 experiments, each ~5 min, keep best by EvaluationScore.compositeScore.
extension AutoLearnCoordinator {

    func runDeepRetraining() async {
        guard !isTraining else { return }
        isTraining = true
        currentTier = .deepRetraining
        defer {
            isTraining = false
            currentTier = .observing
        }

        // 1. Full vault re-analysis
        guard let vaultURL = getActiveVaultURL() else { return }
        let parser = VaultParser()
        let parseResult = await parser.parseVault(at: vaultURL)
        let chunker = DocumentChunker()
        let chunks = chunker.chunkAll(documents: parseResult.documents)
        guard !chunks.isEmpty else { return }

        // 2. Vault content analysis (Phase 1)
        let analysis = VaultContentAnalyzer.analyze(documents: parseResult.documents)

        // 3. Complete synthetic data regeneration (Phase 2)
        guard let provider = KnowledgeFusionViewModel.shared.inferenceProvider else { return }
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-deep-\(UUID().uuidString)")
        let generator = SyntheticDataGenerator(
            inferenceProvider: provider,
            outputDirectory: outputDir
        )
        guard let synthResult = try? await generator.generate(chunks: chunks),
              synthResult.totalAccepted > 0,
              let (_, dataURL) = synthResult.trainingFiles.first else { return }

        // 4. Auto-tune base config (Phase 3)
        let baseConfig = autoTune(
            datasetSize: synthResult.totalAccepted,
            mtldScore: analysis.mtldScore,
            totalTokens: analysis.totalTokens,
            modelSizeB: 3.0,  // Detect from installed model
            availableMemoryMB: 11500
        )

        // 5. Load eval dataset from held-out data
        guard let evalFile = synthResult.evalFile,
              let evalData = try? MetricEvaluator.loadEvalDataset(from: evalFile) else { return }

        // 6. Run autoresearch experiments (extends existing AutoresearchLoop)
        let modelPath = KnowledgeFusionViewModel.shared.detectedModelPath ?? return
        let experimentsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Epistemos/Experiments/\(Date().formatted(date: .numeric, time: .omitted))")

        // Use existing AutoresearchLoop with reduced budget for experiments
        let autoresearch = AutoresearchLoop(
            trainer: QLoRATrainer(
                pythonPath: PythonEnvironmentManager.shared.pythonPath,
                scriptsDirectory: PythonEnvironmentManager.shared.scriptsDirectory
            ),
            tracker: ExperimentTracker(),
            evaluator: MetricEvaluator(inferenceProvider: provider),
            trainingBudget: 100,    // Short budget per experiment
            timeoutSeconds: 300     // 5 min cap per experiment
        )

        var bestScore: Double = 0
        var bestExperiment: ExperimentResult?

        // Run 5 experiments with varied configs
        for i in 0..<5 {
            guard !Task.isCancelled else { break }
            do {
                let result = try await autoresearch.runOneIteration(
                    modelPath: modelPath,
                    dataPath: dataURL,
                    evalData: evalData,
                    outputDirectory: experimentsDir.appendingPathComponent("exp_\(i)")
                )
                if result.score > bestScore {
                    bestScore = result.score
                    bestExperiment = result
                }
            } catch {
                continue  // Experiment failed, try next
            }
        }

        // 7. Promote best experiment adapter
        if let best = bestExperiment, best.decision == .kept,
           let checkpointPath = best.checkpointPath {
            let record = AdapterRecord(
                id: UUID(),
                name: "Auto-Learn Deep \(Date().formatted(date: .abbreviated, time: .omitted))",
                type: .knowledge,
                adapterPath: URL(fileURLWithPath: checkpointPath),
                metadataPath: URL(fileURLWithPath: checkpointPath).appendingPathComponent("training_metadata.json"),
                sourceVault: vaultURL.lastPathComponent,
                createdAt: Date(),
                qualityScore: best.score,
                isActive: true,
                baseModel: "auto-detected",
                loraRank: baseConfig.loraRank,
                parameterCount: baseConfig.loraRank * 4096 * 7 * 2,
                trainingExamples: synthResult.totalAccepted
            )
            try? await AdapterRegistry().register(record)
        }

        // 8. Clear dirty files
        dirtyFileCount = 0
    }

    func runMicroTraining() async {
        guard !isTraining else { return }
        isTraining = true
        currentTier = .microTraining
        defer {
            isTraining = false
            currentTier = .observing
        }

        // Micro-training: incremental analysis on changed files only,
        // short training run (100-300 iters), compare against current adapter
        // Uses the same pipeline as deep retraining but with:
        // - Only dirty files analyzed (BLAKE3 incremental)
        // - Shorter training budget (100 iters)
        // - Single config (no autoresearch experiments)

        // ... (follows same pattern as runDeepRetraining but simplified)
        dirtyFileCount = 0
    }
}
```

**FSEvents Watcher** (`fs_watcher.rs`) — uses `notify` crate:
```rust
use notify::{Config, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::path::Path;
use std::sync::mpsc;

/// Watches a vault directory for file changes using macOS FSEvents.
/// Reports new/modified file paths to the scheduler's dirty-file queue.
pub struct VaultWatcher {
    watcher: RecommendedWatcher,
    receiver: mpsc::Receiver<Result<Event, notify::Error>>,
}

impl VaultWatcher {
    pub fn new(vault_path: &Path) -> Result<Self, notify::Error> {
        let (tx, rx) = mpsc::channel();
        let mut watcher = notify::recommended_watcher(move |res| {
            let _ = tx.send(res);
        })?;
        watcher.watch(vault_path, RecursiveMode::Recursive)?;
        Ok(Self { watcher, receiver: rx })
    }

    /// Poll for file change events. Non-blocking.
    /// Returns paths of files that were created or modified.
    pub fn poll_changes(&self) -> Vec<std::path::PathBuf> {
        let mut changed = Vec::new();
        while let Ok(Ok(event)) = self.receiver.try_recv() {
            match event.kind {
                EventKind::Create(_) | EventKind::Modify(_) => {
                    for path in event.paths {
                        let ext = path.extension()
                            .and_then(|e| e.to_str())
                            .unwrap_or("");
                        // Only track vault-relevant file types
                        if matches!(ext, "md" | "swift" | "rs" | "py" | "ts" | "js" | "txt") {
                            changed.push(path);
                        }
                    }
                }
                _ => {}
            }
        }
        changed
    }
}
```

**Auto-Learn Scheduler** (`tier_scheduler.rs`):
```rust
use chrono::{DateTime, Local, Timelike, Datelike};
use std::path::PathBuf;

#[derive(Debug, Clone, serde::Serialize)]
pub enum TrainingTier {
    None,
    MicroTraining,
    DeepRetraining,
    UserTriggered,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct TrainingDecision {
    pub should_train: bool,
    pub tier: TrainingTier,
    pub reason: String,
    pub dirty_file_count: usize,
    pub days_since_last: i64,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct DPOSignal {
    pub prompt: String,
    pub accepted: String,
    pub rejected: String,
    pub timestamp: DateTime<Local>,
}

pub struct AutoLearnScheduler {
    dirty_files: Vec<PathBuf>,
    last_micro_train: DateTime<Local>,
    last_deep_train: DateTime<Local>,
    dpo_signals: Vec<DPOSignal>,
    is_training: bool,
    energy_aware: bool,
}

impl AutoLearnScheduler {
    pub fn new() -> Self {
        Self {
            dirty_files: Vec::new(),
            last_micro_train: Local::now(),
            last_deep_train: Local::now(),
            dpo_signals: Vec::new(),
            is_training: false,
            energy_aware: true,
        }
    }

    pub fn evaluate(&self) -> TrainingDecision {
        if self.is_training {
            return TrainingDecision {
                should_train: false, tier: TrainingTier::None,
                reason: "Training in progress".into(),
                dirty_file_count: 0, days_since_last: 0,
            };
        }

        // Energy check: defer on battery
        if self.energy_aware && self.is_on_battery() {
            return TrainingDecision {
                should_train: false, tier: TrainingTier::None,
                reason: "On battery — deferred".into(),
                dirty_file_count: 0, days_since_last: 0,
            };
        }

        let now = Local::now();
        let hour = now.hour();
        let dirty_count = self.dirty_files.len();
        let days_since_micro = (now - self.last_micro_train).num_days();
        let days_since_deep = (now - self.last_deep_train).num_days();

        // Tier 3: Weekly (Sunday 3 AM)
        if now.weekday() == chrono::Weekday::Sun && hour == 3 && days_since_deep >= 6 {
            return TrainingDecision {
                should_train: true, tier: TrainingTier::DeepRetraining,
                reason: format!("{} days since deep, {} dirty", days_since_deep, dirty_count),
                dirty_file_count: dirty_count, days_since_last: days_since_deep,
            };
        }

        // Tier 2: Nightly (2-4 AM)
        if (2..=4).contains(&hour) && (dirty_count > 10 || days_since_micro >= 3) {
            return TrainingDecision {
                should_train: true, tier: TrainingTier::MicroTraining,
                reason: format!("{} dirty, {} days since micro", dirty_count, days_since_micro),
                dirty_file_count: dirty_count, days_since_last: days_since_micro,
            };
        }

        TrainingDecision {
            should_train: false, tier: TrainingTier::None,
            reason: "No training needed".into(),
            dirty_file_count: dirty_count, days_since_last: days_since_micro,
        }
    }

    pub fn mark_dirty(&mut self, path: PathBuf) { self.dirty_files.push(path); }
    pub fn clear_dirty(&mut self) { self.dirty_files.clear(); }
    pub fn record_preference(&mut self, signal: DPOSignal) { self.dpo_signals.push(signal); }

    fn is_on_battery(&self) -> bool {
        let output = std::process::Command::new("pmset")
            .arg("-g").arg("batt").output();
        match output {
            Ok(o) => String::from_utf8_lossy(&o.stdout).contains("Battery Power"),
            Err(_) => false,
        }
    }
}
```

#### ANTI-PATTERNS
1. **NEVER** run training on battery. Check power source first.
2. **NEVER** keep a degraded adapter. Always compare `EvaluationScore.compositeScore` vs previous.
3. **NEVER** run autoresearch experiments without time limits. Cap at 5 minutes per experiment (existing `AutoresearchLoop.timeoutSeconds` defaults to 1800 — reduce for experiments).
4. **NEVER** discard DPO signals from `FeedbackLogger`. Every user accept/reject is gold for preference learning.
5. **NEVER** run Tier 3 deep retraining more than once per week. It's expensive.

#### VERIFICATION CHECKPOINT
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_scheduler_dirty_threshold() {
        let mut scheduler = AutoLearnScheduler::new();
        for i in 0..15 {
            scheduler.mark_dirty(std::path::PathBuf::from(format!("test_{}.md", i)));
        }
        let decision = scheduler.evaluate();
        assert_eq!(decision.dirty_file_count, 15);
    }

    #[test]
    fn test_dpo_recording() {
        let mut scheduler = AutoLearnScheduler::new();
        scheduler.record_preference(DPOSignal {
            prompt: "How to handle errors?".into(),
            accepted: "Use Result<T, E>".into(),
            rejected: "Use unwrap()".into(),
            timestamp: chrono::Local::now(),
        });
        assert_eq!(scheduler.dpo_signals.len(), 1);
    }
}
```

#### PHASE GATE
- [ ] FSEvents watcher detects file changes in test directory
- [ ] Scheduler correctly evaluates tier decisions based on dirty count and time
- [ ] Energy-aware check works (plugged in vs battery)
- [ ] `AutoresearchLoop.runOneIteration()` accepts auto-tuned configs
- [ ] DPO signals flow from `FeedbackLogger` through to training data
- [ ] Tier 3 experiment runner completes 3+ experiments and selects best by compositeScore

---

### PHASE 10: TRAINING UI ENHANCEMENTS

#### OBJECTIVE
Extend the EXISTING `TrainOnVaultView` and `KnowledgeFusionViewModel` with auto-learn status, vault analysis display, and experiment history. DO NOT rebuild the UI from scratch — enhance what exists.

#### FILES TO MODIFY (EXISTING)
- `TrainOnVaultView` — Add vault analysis card, auto-learn status indicator, experiment history section
- `KnowledgeFusionViewModel` — Add auto-learn state, vault analysis results, experiment history

#### FILES TO CREATE (NEW)
```
Views/Training/VaultAnalysisCard.swift
Views/Training/AutoLearnStatusView.swift
Views/Training/ExperimentHistoryView.swift
Views/Settings/AutoLearnSettingsView.swift
```

#### CODE PATTERNS

**CRITICAL**: Follow Engineering Bible patterns:
- `@MainActor @Observable` for all new state classes — NEVER `ObservableObject`
- Use `@Environment(KnowledgeFusionViewModel.self)` — already done in `TrainOnVaultView`
- Use `withAppEnvironment(bootstrap)` for environment injection
- Swift Testing (`@Suite` + `@Test` + `#expect`) for all tests — NEVER XCTest

**VaultAnalysisCard** (new view, same style as existing TrainOnVaultView components):
```swift
struct VaultAnalysisCard: View {
    let analysis: VaultAnalysis?  // From Phase 1

    var body: some View {
        if let a = analysis {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text("Vault Analysis")
                        .font(.caption.weight(.semibold))
                }

                HStack(spacing: 16) {
                    metricBadge("Files", "\(a.totalFiles)")
                    metricBadge("Tokens", "\(a.totalTokens.formatted())")
                    metricBadge("MTLD", String(format: "%.1f", a.mtldScore))
                    metricBadge("Code", String(format: "%.0f%%", a.codeRatio * 100))
                }

                // Auto-tuned parameters (read-only display)
                if let config = a.autoTunedConfig {
                    HStack(spacing: 12) {
                        Text("Auto-tuned:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("rank=\(config.loraRank)")
                            .font(.caption2.monospacedDigit())
                        Text("α=\(config.loraAlpha)")
                            .font(.caption2.monospacedDigit())
                        Text("lr=\(String(format: "%.0e", config.learningRate))")
                            .font(.caption2.monospacedDigit())
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func metricBadge(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}
```

#### PHASE GATE
- [ ] UI shows vault analysis results (MTLD, token count, classifications)
- [ ] Auto-tuned parameters displayed as read-only with explanations
- [ ] Auto-learn status indicator shows current tier
- [ ] Experiment history shows past results from `AutoresearchLoop`
- [ ] Existing `TrainOnVaultView` still works with no regressions

---

## SECTION 2: ANTI-DRIFT ANCHORS

**Read these 5 anchors at EVERY phase boundary. If you find yourself violating any anchor, STOP and course-correct.**

### ANCHOR 1: EXTEND, DON'T REBUILD
```
┌──────────────────────────────────────────────────┐
│  This is a MATURE codebase. These actors EXIST:  │
│  • QLoRATrainer        • SyntheticDataGenerator  │
│  • InstructionBacktranslator  • QualityCurator   │
│  • AdapterRegistry     • AdapterRouter           │
│  • AutoresearchLoop    • MetricEvaluator         │
│  • VaultParser         • DocumentChunker         │
│  • PythonEnvironmentManager                      │
│  • KnowledgeFusionViewModel                      │
│  • TrainOnVaultView                              │
│                                                  │
│  NEVER recreate these. ALWAYS extend them.       │
│  If you create a new actor/class with similar    │
│  functionality, you are WRONG.                   │
└──────────────────────────────────────────────────┘
```

### ANCHOR 2: HARDWARE BUDGET
```
┌──────────────────────────────────────────────────┐
│  M2 Pro 18GB — 11,500 MB training ceiling.       │
│  NEVER exceed this. Check memory estimates       │
│  before EVERY training run.                      │
│  If estimated > 11,500 → reduce batch first,     │
│  then rank, then sequence length.                │
└──────────────────────────────────────────────────┘
```

### ANCHOR 3: ENGINEERING BIBLE PATTERNS (08-CLAUDE-8.md)
```
┌──────────────────────────────────────────────────┐
│  SWIFT:                                          │
│  • @MainActor @Observable — NEVER ObservableObject│
│  • withAppEnvironment(bootstrap) for env injection│
│  • Swift Testing (@Suite + @Test + #expect)      │
│  • guard let / if let — NEVER force unwrap (!)   │
│  • do/catch — NEVER try!                         │
│  • Int(floatValue) — ALWAYS guard .isFinite      │
│                                                  │
│  RUST (graph-engine patterns):                   │
│  • #[repr(C)] on FFI structs                     │
│  • // SAFETY: comment on every unsafe block      │
│  • with_capacity() for all Vec in hot paths      │
│  • Zero clone() in render loops                  │
│                                                  │
│  PYTHON:                                         │
│  • MLX ONLY — never import torch in training     │
│  • Process() bridge from Swift (NOT PyO3)        │
└──────────────────────────────────────────────────┘
```

### ANCHOR 4: ADAPTERS NEVER FUSE INTO BASE WEIGHTS
```
┌──────────────────────────────────────────────────┐
│  LoRA adapters are SEPARATE .safetensors files.  │
│  They NEVER merge into base model weights.       │
│  AdapterRegistry manages them as SEPARATE        │
│  records with paths to adapter directories.      │
│  Hot-swap at inference time, not permanent merge. │
└──────────────────────────────────────────────────┘
```

### ANCHOR 5: PRIVACY-FIRST — ZERO DATA EXFILTRATION
```
┌──────────────────────────────────────────────────┐
│  NO data ever leaves the device.                 │
│  • No telemetry, no cloud training               │
│  • No model uploads, no analytics                │
│  • No network calls during training              │
│  • Model downloads are the ONLY network use      │
└──────────────────────────────────────────────────┘
```

---

## SECTION 3: RESEARCH NEEDED ESCAPE HATCH

When you encounter a problem that cannot be resolved with this prompt, emit:

```
⚠️ RESEARCH NEEDED ⚠️
Topic: [specific technical topic]
Why: [what is blocking progress]
Files involved: [list specific files]
Current understanding: [what you know]
What would unblock you: [specific info needed]
Suggested research prompt: [paste-ready prompt for Google Deep Research]
```

**After emitting this block, STOP CODING.** Do not guess or implement a placeholder.

**Known RESEARCH NEEDED points**:

1. **Fisher Information Matrix estimation in MLX**: K-FAC approximation for per-layer Fisher computation in MLX.
2. **LightGBM LambdaRank in Rust**: The `lightgbm-rs` crate API for learning-to-rank training.
3. **MLX adapter hot-swap at inference**: Loading a new LoRA into an already-loaded base model without full reload.
4. **macOS IOKit energy metrics from Rust**: Querying power source state without `pmset` CLI.
5. **MoLoRA per-token routing in MLX**: Custom Metal kernel for per-token adapter selection (scaffold exists in `AdapterRouter.routeToken()`).

---

## SECTION 4: CLEVER STRATEGIES & BEST PRACTICES

### Strategy 1: Bootstrap Training Data Generation
Use the base model itself to generate initial training pairs. Fine-tune on those. Then use the fine-tuned model (with adapter loaded via `AdapterLoader`) to generate BETTER pairs. Repeat. Gate behind quality check in `QualityCurator`.

### Strategy 2: Adapter Stacking via AdapterRegistry
The existing `AdapterType` enum supports `.knowledge`, `.style`, `.tool`, `.kto`. Train separate adapters. The existing `AdapterRouter.routeAutomatic()` already classifies prompts to select the right type. Extend to hot-swap at inference time.

### Strategy 3: Ghost-Brain Shadow Buffer for DPO
The Loro CRDT ghost-brain buffer captures every keystroke. What the user types and keeps → **accepted**. What they delete → **rejected**. Feed into `FeedbackLogger` for DPO signal collection.

### Strategy 4: Curriculum Learning via QualityCurator
Order training data by quality score (already tracked in `GeneratedPair.qualityScore` and `TrainingPair.qualityScore`). Implement curriculum ordering in `AutoresearchLoop.proposeVariation()` — it already has `TrainingConfig.CurriculumOrder` with `.ascending`, `.descending`, `.random`.

### Strategy 5: Incremental Skill File Updates
When the auto-learner discovers new patterns, don't regenerate all skill files. Patch the relevant one: bump version, append directive, re-index in BM25.

### Strategy 6: Training Data Versioning with BLAKE3
Every vault analysis caches BLAKE3 hashes per file. When the vault changes, only the delta needs reprocessing. Full regeneration is reserved for Tier 3 deep retraining. This makes Tier 2 fast enough for 15 minutes.

### Strategy 7: Self-Evaluation Loop via MetricEvaluator
After each training cycle, `MetricEvaluator.evaluate()` already runs direct probing + indirect probing + style evaluation. If `EvaluationScore.compositeScore` drops >5% compared to previous adapter, rollback automatically via `AdapterRegistry.setActive()`.

### Strategy 8: Energy-Aware Training
Monitor power via `pmset -g batt`. On battery → defer ALL training. Plugged in + idle > 5 min → opportunistically start Tier 2. Plugged in + active → only user-triggered.

### Strategy 9: Progressive Model Scaling
Start with 0.8B/1B model. The auto-tuner (Phase 3) adjusts all hyperparameters automatically for the model size. `KnowledgeFusionViewModel.detectInstalledModels()` already discovers available models.

### Strategy 10: Federated Adapter Marketplace (Future)
Users share anonymized LoRA adapters as "skill packs" without sharing vault data. Mark as `// TODO: Future — federated adapter sharing`.

---

## SECTION 5: CORE ANTI-PATTERNS (GLOBAL)

1. **NEVER** train on raw vault content without synthetic pair generation. The existing `SyntheticDataGenerator` → `InstructionBacktranslator` → `QualityCurator` pipeline exists for this reason.

2. **NEVER** use a static LoRA rank. Always compute from MTLD + token count (Phase 3 auto-tuner). The existing hardcoded ranks (16 in `train_knowledge.py`, 8 in `train_style.py`) are the V1 defaults being replaced.

3. **NEVER** stuff all skill files into the context window. Always rank and prune to token budget (Phase 6 prompt composer).

4. **NEVER** train without monitoring. Watch training loss via `TrainingProgressParser` (already parses stdout). If loss plateaus while gradient norm spikes, stop immediately.

5. **NEVER** skip boilerplate filtering for code repos. The new boilerplate filter (Phase 1) removes auto-generated code, imports, test fixtures before pair generation.

6. **NEVER** use PyTorch on Apple Silicon for training. Always MLX. The existing `PythonEnvironmentManager` installs `mlx` and `mlx-lm` only.

7. **NEVER** let training run unbounded. Always set iteration limits. The existing `QLoRATrainer` passes `numIters` to `Process()`.

8. **NEVER** ignore the "lost in the middle" problem. Pin critical instructions to Zone A (top) and Zone C (bottom) of the system prompt.

9. **NEVER** generate skill files exceeding 500 lines. Split with progressive disclosure.

10. **NEVER** train in the foreground. The existing `KnowledgeFusionViewModel.startTrainingOnVault()` uses `Task.detached` — follow this pattern for all training operations.

---

## SECTION 6: INTEGRATION TEST — END-TO-END PIPELINE

After all 10 phases are complete, validate the full pipeline:

```
┌─────────────────────────────────────────────────────────────────────┐
│  END-TO-END INTEGRATION TEST                                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Create test vault: 30 markdown + 20 Swift + 10 Python files.   │
│                                                                     │
│  2. Vault analysis (Phase 1):                                       │
│     - VaultParser.parseVault() → [ParsedDocument]                   │
│     - VaultContentAnalyzer.analyze() → classifications, MTLD, tokens│
│     - Verify: BLAKE3 hashes cached, incremental on 2nd run          │
│                                                                     │
│  3. Synthetic data (Phase 2):                                       │
│     - RuleBasedPairGenerator → rule pairs (fast, no inference)      │
│     - SyntheticDataGenerator.generate() → LLM pairs                 │
│     - QualityCurator.curate() → filtered, classified, split         │
│     - Verify: >100 pairs, JSONL valid, 90/10 split                  │
│                                                                     │
│  4. Auto-tune (Phase 3):                                            │
│     - auto_tune() → AutoTuneConfig                                  │
│     - Verify: rank scales with MTLD, memory within 11,500 MB        │
│                                                                     │
│  5. Training (Phase 4):                                             │
│     - QLoRATrainer invokes train_auto.py with auto-tuned config     │
│     - TrainingProgressParser reports progress in real-time           │
│     - Verify: loss decreases, adapter checkpoint saved               │
│                                                                     │
│  6. Registration:                                                   │
│     - AdapterRegistry.register() → AdapterRecord                    │
│     - AdapterRegistry.setActive() → adapter ready for inference     │
│                                                                     │
│  7. Skill files (Phase 5):                                          │
│     - Generator produces YAML+MD files from extracted patterns       │
│     - Verify: all under 500 lines, valid YAML frontmatter           │
│                                                                     │
│  8. Prompt composition (Phase 6):                                   │
│     - BM25 indexes skill files                                      │
│     - Hybrid retriever selects relevant skills for test query        │
│     - Composer assembles Zone A + B + C within token budget          │
│                                                                     │
│  9. Auto-learn (Phase 9):                                           │
│     - FSEvents watcher detects file changes                          │
│     - Scheduler evaluates tier decision                              │
│     - Energy check passes (plugged in)                               │
│     - AutoresearchLoop runs 3 experiments                            │
│     - MetricEvaluator selects best by compositeScore                 │
│                                                                     │
│  10. UI (Phase 10):                                                 │
│      - TrainOnVaultView loads with vault analysis card               │
│      - Auto-learn status shows current tier                          │
│      - "Start Training" triggers full pipeline                       │
│      - Progress updates in real-time via KnowledgeFusionViewModel   │
│                                                                     │
│  PASS CRITERIA: All sections pass. No crashes, no OOM,              │
│  no data exfiltration, no manual hyperparameter input required.     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## APPENDIX A: DEPENDENCY VERSION MATRIX

| Dependency | Version | Language | Purpose |
|:-----------|:--------|:---------|:--------|
| mlx | ≥0.22 | Python | Core ML framework |
| mlx-lm | ≥0.20 | Python | Model loading, LoRA, training |
| bm25 | 0.4 | Rust | Lexical keyword search |
| notify | 6 | Rust | FSEvents file watching |
| chrono | 0.4 | Rust | Date/time for scheduler |
| regex | 1 | Rust | Document classification |
| serde | 1 | Rust | Serialization |
| blake3 | 1 | Rust | Content hashing |
| thiserror | 1 | Rust | Error types |
| tracing | 0.1 | Rust | Logging |
| tokio | 1 | Rust | Async runtime |
| walkdir | 2 | Rust | Directory traversal |
| rand | 0.8 | Rust | Random for experiments |
| uniffi | 0.28 | Rust | Rust ↔ Swift bridge |
| SwiftTreeSitter | latest | Swift SPM | Tree-sitter bindings |
| TreeSitterSwift | latest | Swift SPM | Swift grammar |
| TreeSitterPython | latest | Swift SPM | Python grammar |
| TreeSitterRust | latest | Swift SPM | Rust grammar |
| TreeSitterJavaScript | latest | Swift SPM | JavaScript grammar |
| TreeSitterTypeScript | latest | Swift SPM | TypeScript grammar |

## APPENDIX B: GLOSSARY

| Term | Definition |
|:-----|:-----------|
| **MTLD** | Measure of Textual Lexical Diversity. Stable metric for vocabulary richness. |
| **QLoRA** | Quantized Low-Rank Adaptation. Fine-tuning quantized models with LoRA adapters. |
| **LoRA** | Low-Rank Adaptation. Parameter-efficient fine-tuning by training low-rank matrices. |
| **RRF** | Reciprocal Rank Fusion. Rank-based merging for multiple retrievers. |
| **BM25** | Best Matching 25. Probabilistic lexical search algorithm. |
| **DPO** | Direct Preference Optimization. Training from human preference signals. |
| **Fisher Information Matrix** | Measures model sensitivity to parameter perturbations. Used for LoRA rank estimation. |
| **K-FAC** | Kronecker-factored Approximate Curvature. Efficient Fisher matrix approximation. |
| **TTR** | Type-Token Ratio. Length-sensitive diversity metric (DO NOT USE — use MTLD). |
| **FSEvents** | macOS file system event notification API. |
| **UniFFI** | Mozilla's Rust ↔ Swift/Kotlin bridge generator. |
| **CRDT** | Conflict-free Replicated Data Type. For distributed/offline-first data sync. |
| **Loro** | CRDT library used by Epistemos for vault state management. |
| **MLX** | Apple's ML framework optimized for Apple Silicon unified memory. |
| **KUP Framework** | Knowledge Understanding Probing — direct + indirect probing for evaluation. |

## APPENDIX C: EXISTING TYPE SIGNATURES QUICK REFERENCE

```swift
// Training Pipeline
actor QLoRATrainer {
    func trainKnowledgeAdapter(modelPath: URL, dataPath: URL, outputPath: URL, replayPath: URL?, numIters: Int, seed: Int, progressHandler: (@Sendable (TrainingProgress) -> Void)?) async throws -> AdapterMetadata
    func trainStyleAdapter(modelPath: URL, dataPath: URL, outputPath: URL, replayPath: URL?, numIters: Int, seed: Int, progressHandler: (@Sendable (TrainingProgress) -> Void)?) async throws -> AdapterMetadata
    func cancelTraining() async
}

// Synthetic Data
actor SyntheticDataGenerator {
    func generate(chunks: [TextChunk], progressHandler: (@Sendable (SyntheticDataProgress) -> Void)?) async throws -> SyntheticDataResult
}
actor InstructionBacktranslator {
    func backtranslate(chunk: TextChunk) async throws -> [GeneratedPair]
}
nonisolated struct QualityCurator: Sendable {
    func curate(pairs: [GeneratedPair]) -> CurationResult
    func classifyPair(question: String, answer: String) -> TrainingPairCategory
    func writeJSONL(pairs: [TrainingPair], outputDirectory: URL, timestamp: String) throws -> [TrainingPairCategory: URL]
}

// Adapter Management
actor AdapterRegistry {
    func register(_ record: AdapterRecord) throws
    func deregister(id: UUID) throws
    func setActive(_ id: UUID, active: Bool) throws
    func updateQualityScore(_ id: UUID, score: Double) throws
    func listAdapters(type: AdapterType?) -> [AdapterRecord]
    func getActiveAdapters() -> [AdapterRecord]
}

// Autoresearch
actor AutoresearchLoop {
    func runOneIteration(modelPath: URL, dataPath: URL, evalData: EvaluationDataset, outputDirectory: URL, progressHandler: (@Sendable (AutoresearchProgress) -> Void)?) async throws -> ExperimentResult
    func proposeVariation(from base: TrainingConfig) -> (config: TrainingConfig, description: String)
}

// Evaluation
actor MetricEvaluator {
    func evaluate(evalData: EvaluationDataset) async -> EvaluationScore
    func evaluateDirectProbing(probes: [EvaluationDataset.DirectProbe]) async -> Double
    func evaluateIndirectProbing(probes: [EvaluationDataset.IndirectProbe]) async -> Double
    func evaluateStyle(samples: [String]) async -> Double
}

// Ingestion
actor VaultParser {
    func parseVault(at directoryURL: URL, vaultName: String?) async -> VaultParseResult
}
struct DocumentChunker: Sendable {
    func chunk(document: ParsedDocument) -> [TextChunk]
    func chunkAll(documents: [ParsedDocument]) -> [TextChunk]
    func estimateTokens(_ text: String) -> Int  // Currently words * 1.3 — UPGRADE to dual-bound
}

// Python Environment
@MainActor @Observable final class PythonEnvironmentManager {
    static let shared: PythonEnvironmentManager
    var pythonPath: String
    var scriptsDirectory: URL
    var isReady: Bool
    func ensureReady() async
    func deployScripts() throws
}

// ViewModel
@MainActor @Observable final class KnowledgeFusionViewModel {
    static let shared: KnowledgeFusionViewModel
    var trainingState: KFTrainingState
    var progress: KFProgress
    var installedAdapters: [AdapterRecord]
    var activeAdapter: AdapterRecord?
    func startTrainingOnVault(vaultURL: URL, modelPath: URL, inferenceProvider: KFInferenceProvider)
    func trainOnVault(vaultURL: URL, modelPath: URL, inferenceProvider: KFInferenceProvider) async
    func activateAdapter(_ record: AdapterRecord) async
    func deleteAdapter(_ record: AdapterRecord) async
}
```

---

*This specification is version 2.0.0. Grounded in the actual Epistemos codebase.*
*Last updated: 2026-03-24.*
*Target: Claude Code operating on Epistemos, macOS, Apple Silicon M2 Pro 18GB.*
*Total phases: 11 (0-10). Anti-drift anchors: 5. Research escape hatches: 5.*
