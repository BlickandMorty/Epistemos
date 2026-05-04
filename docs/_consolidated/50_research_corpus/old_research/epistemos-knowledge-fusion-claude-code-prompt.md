# Epistemos Knowledge Fusion — Claude Code Execution Prompt

**Document Purpose:** Copy-paste-ready Claude Code prompt for implementing the on-device Knowledge Fusion subsystem in the Epistemos macOS application. Written to be drift-proof, research-bound, and phase-gated.

**Primary Source of Truth:** `On-Device-LLM-Knowledge-Fusion-Research.md`
**App Context Source:** `Epistemos_-Audit-Research-Design.md`
**Autoresearch Repo:** `/Users/Downloads/autoresearch-master`

---

## SECTION 1: MASTER EXECUTION PROMPT

```
════════════════════════════════════════════════════════════════════════════════
EPISTEMOS KNOWLEDGE FUSION — CLAUDE CODE MASTER EXECUTION PROMPT
VERSION: 1.0.0 | BINDING TO: On-Device-LLM-Knowledge-Fusion-Research.md
════════════════════════════════════════════════════════════════════════════════

╔══════════════════════════════════════════════════════════════════════════════╗
║                            SYSTEM ROLE                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

You are the principal implementation engineer for the Epistemos Knowledge
Fusion subsystem. Epistemos is a macOS-native application (SwiftUI 6 / Rust
FFI / Metal) built by a single developer. The user currently has Apple
Intelligence ~3B and Qwen 3.5 models up to 4B running locally via MLX.

YOUR MANDATE:
- Implement the five-subsystem Knowledge Fusion architecture described in the
  research paper exactly as specified
- Prioritize correctness over speed at every step
- Every line of code must be justified by the research paper or verified
  against official MLX documentation
- You are NOT permitted to guess at architecture decisions — if the research
  paper is silent on a topic, you must emit a RESEARCH NEEDED block (template
  below) and pause
- You are NOT permitted to proceed to the next phase until the current phase's
  tests pass and the user approves the checkpoint
- You MUST re-read the required ANTI-DRIFT ANCHORS at every phase boundary
  as explicitly instructed in each phase

OPERATING CONSTRAINTS:
- Target hardware: Apple Silicon M-series (M1 through M5)
- Base models: Apple Intelligence ~3B, Qwen 3.5 4B (4-bit quantized via MLX)
- Framework: MLX / mlx-lm / mlx-tune
- Language: Swift 6 (SwiftUI, AppKit), Rust (FFI bridge), Python (training
  scripts via Process invocation)
- Training: Background-only, idle/overnight, NEVER blocking the typing path
- Adapter format: .safetensors with accompanying metadata JSON
- KTO (NOT DPO) for preference alignment
- Hot-swap adapters ONLY — never fuse into base weights permanently

╔══════════════════════════════════════════════════════════════════════════════╗
║                        ANTI-DRIFT ANCHOR DEFINITIONS                        ║
║         READ ALL FIVE ANCHORS BEFORE BEGINNING. REFERENCE THEM AT           ║
║         EACH PHASE BOUNDARY AS INSTRUCTED.                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝

┌──────────────────────────────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════════════════════════════╗    │
│ ║  ANCHOR 1 — THE FIVE SUBSYSTEMS (Research Paper: Technical Architecture) ║ │
│ ╚═══════════════════════════════════════════════════════════════════════╝    │
│                                                                              │
│  The entire Knowledge Fusion feature is composed of exactly FIVE            │
│  interdependent subsystems. No subsystem may be skipped or merged.          │
│                                                                              │
│  1. DATA INGESTION AND NORMALIZATION ENGINE                                 │
│     - Input: Raw markdown notes, PDF documents, voice recordings            │
│     - Output: Normalized, chunked text                                      │
│     - Key requirement: Markdown-header-based chunking (NOT naive recursive  │
│       splitting). Page-level and markdown-header chunking empirically       │
│       outperform fixed-size recursive chunking by preserving natural        │
│       language boundaries.                                                  │
│     - Audio: Whisper-based transcription with speaker diarization           │
│       (mlx-whisper or whisper.cpp). Must capture paralinguistic cues        │
│       (hesitations, hedging phrases, pacing) — these are the stylometric   │
│       DNA of the user's voice.                                              │
│                                                                              │
│  2. SYNTHETIC DATA GENERATION PIPELINE                                      │
│     - Input: Normalized text chunks                                         │
│     - Output: JSONL training pairs (knowledge / style / tool-use)          │
│     - Method: Instruction Backtranslation (Self-Instruct methodology)      │
│       Step 1: Base model reads chunk → generates hypothetical queries       │
│       Step 2: Model rewrites raw facts into clean instruction-response      │
│       Step 3: Self-curation quality scoring (1–5 scale, discard < 3)       │
│     - Research confirms 3B–4B models match 70B teacher quality when        │
│       prompt templates are rigorously constrained against sycophancy        │
│                                                                              │
│  3. PARAMETER-EFFICIENT FINE-TUNING SUBSYSTEM (QLoRA via MLX)              │
│     - Base weights: FROZEN in 4-bit precision                               │
│     - Low-rank matrices A and B: Updated in 16-bit precision               │
│     - Weight update formula: W = W_0 + (alpha/rank) * B*A                  │
│     - Catastrophic forgetting mitigation:                                   │
│       a) Experience Replay Buffer (MSSR algorithm, 500 examples, 10% mix)  │
│       b) Curriculum Learning (simple definitions first, multi-hop last)     │
│       c) Sharpness-Aware Minimization (SAM optimizer)                       │
│       d) L2 norm penalties on adapter weights                               │
│                                                                              │
│  4. CONTINUOUS PREFERENCE ALIGNMENT (KTO — NOT DPO)                        │
│     - Trigger: User accepts ghost text = positive; rejects/edits = negative │
│     - Algorithm: Kahneman-Tversky Optimization (binary, unpaired feedback)  │
│     - WHY NOT DPO: DPO requires paired chosen/rejected + reference model    │
│       in memory simultaneously. Too expensive for on-device.               │
│     - Schedule: Batch during idle/overnight — NEVER after every interaction │
│                                                                              │
│  5. DYNAMIC INFERENCE AND ROUTING (MoLoRA / HMoRA)                         │
│     - Multiple adapters loaded into unified memory simultaneously           │
│     - Lightweight routing function evaluates each token                     │
│     - Routes computation through appropriate adapter per-token              │
│     - NEVER fuse adapters permanently into base weights                     │
│     - Style Adapter / Tool Adapter / Knowledge Adapter = hot-swappable     │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════════════════════════════╗    │
│ ║  ANCHOR 2 — OPTIMAL HYPERPARAMETERS (Research Paper: Implementation  ║    │
│ ║             Recommendations § "Optimal Hyperparameters")              ║    │
│ ╚═══════════════════════════════════════════════════════════════════════╝    │
│                                                                              │
│  The Transformer architecture uses DIFFERENT neural circuits for style vs.  │
│  facts. Attention layers (qkv, o_proj) govern style. MLP layers             │
│  (gate_proj, up_proj, down_proj) store factual knowledge.                   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ KNOWLEDGE ABSORPTION PROFILE                                         │    │
│  │ rank:           32 (range: 16–32)                                   │    │
│  │ alpha:          64 (range: 32–64, equal or 2x rank)                 │    │
│  │ target_modules: q_proj, k_proj, v_proj, o_proj,                     │    │
│  │                 gate_proj, up_proj, down_proj                        │    │
│  │ learning_rate:  2e-5 (range: 1e-5 to 5e-5)                         │    │
│  │ WHY MLP: Facts stored in MLP key-value memory networks              │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ STYLE CLONING PROFILE                                                │    │
│  │ rank:           8 (range: 4–8)                                      │    │
│  │ alpha:          16 (range: 8–16, 2x rank)                           │    │
│  │ target_modules: q_proj, k_proj, v_proj, o_proj (ONLY — no MLP)     │    │
│  │ learning_rate:  1e-5 (range: 1e-5 to 5e-5)                         │    │
│  │ WHY LOW RANK: Prevents hallucinating false facts while imitating    │    │
│  │               persona. Low capacity = style only, no factual bleed  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  DATASET SIZE REQUIREMENTS (from research paper empirics):                  │
│  - Style/formatting behavioral change: 100–500 high-quality examples        │
│  - Tool calling (new function signatures): 1,000–3,000 diverse examples     │
│  - Genuine factual knowledge absorption: 3,000–10,000 diverse pairs         │
│  - Beyond 10,000: Diminishing returns, rank saturation                      │
│                                                                              │
│  HARDWARE TRAINING BUDGET (4B model, 4-bit, r=32, 1000 examples):          │
│  M1 Max (32GB):  ~55 min  |  M3 Max (64GB):  ~22 min                       │
│  M4 Max (64GB):  ~14 min  |  M5 Max (128GB): ~8 min                        │
│  Peak unified memory:  ~12–13 GB                                            │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════════════════════════════╗    │
│ ║  ANCHOR 3 — CRITICAL GAPS (Research Paper: § "Critical Gaps")        ║    │
│ ╚═══════════════════════════════════════════════════════════════════════╝    │
│                                                                              │
│  These are KNOWN FAILURE MODES. Deviating from these constraints will       │
│  cause production bugs.                                                      │
│                                                                              │
│  GAP 1: ADAPTER FUSION INFERENCE DEGRADATION                                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Problem: Permanently fusing LoRA adapter into 4-bit quantized base model   │
│  causes token throughput to plummet. Empirically observed: 21 tok/s → 7    │
│  tok/s (3x degradation). GitHub Issue #1104 in mlx-lm documents this.      │
│  Root cause: Weight normalization during fusion disrupts quantized model's  │
│  optimized execution paths.                                                 │
│  MANDATE: NEVER fuse adapters permanently. ALWAYS hot-swap at inference.   │
│                                                                              │
│  GAP 2: TOOL FORGETTING AND INTERFERENCE                                    │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Problem: Teaching model new tool signatures degrades pre-existing tool-    │
│  calling capabilities. LoRA parameter locality causes the model to over-   │
│  index on new function syntax, forgetting established APIs.                 │
│  MANDATE: Always generate "negative example" datasets during tool training  │
│  where new tools are intentionally ignored in favor of existing ones.       │
│  Include negative examples for every new tool added to the skill DB.       │
│                                                                              │
│  GAP 3: GGUF EXPORT BROKEN FROM 4-BIT QUANTIZED BASE                       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Problem: mlx-lm cannot export a QLoRA fine-tuned model directly to GGUF   │
│  when the base is already 4-bit quantized. Quantization mismatch error.    │
│  Workaround A: Save in native MLX .safetensors format (limits llama.cpp     │
│  interoperability but works for all local MLX inference).                   │
│  Workaround B: De-quantize to FP16 before export (spikes storage ~4x).     │
│  MANDATE: Default to MLX native format. Do NOT attempt GGUF export from    │
│  4-bit base without explicit user instruction and de-quantize step.        │
│                                                                              │
│  GAP 4: PRIVACY — MODEL INVERSION ATTACK SURFACE                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Problem: .safetensors adapter files contain dense representations of       │
│  personal data. Adversaries with filesystem access can execute model        │
│  inversion attacks to reverse-engineer PII from adapter weights.           │
│  MANDATE: Implement DP-LoRA (Differential Privacy LoRA) — gradient         │
│  clipping + Gaussian noise injection during fine-tuning loop.               │
│                                                                              │
│  GAP 5: SAFETY ALIGNMENT DEGRADATION                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Problem: Training on unfiltered personal vault data can degrade RLHF       │
│  safety alignment, creating jailbroken behavior.                            │
│  MANDATE: Implement PTST strategy — train without safety prompts (to        │
│  absorb user style freely), but ALWAYS prepend safety-aligned system        │
│  prompt at inference time. Consider a frozen "Safety Adapter" layered       │
│  over personal adapters at inference.                                       │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════════════════════════════╗    │
│ ║  ANCHOR 4 — CATASTROPHIC FORGETTING MITIGATIONS                      ║    │
│ ║  (Research Paper: § "Mitigating Catastrophic Forgetting")             ║    │
│ ╚═══════════════════════════════════════════════════════════════════════╝    │
│                                                                              │
│  Root cause: Fine-tuning introduces "intruder dimensions" — new high-rank   │
│  singular vectors that overpower pre-trained vectors. This is measurable    │
│  via spectral analysis of the LoRA weight matrices.                         │
│                                                                              │
│  MITIGATION 1: EXPERIENCE REPLAY (via MSSR algorithm)                       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  - Maintain a fixed-capacity buffer of 500 general-purpose conversations   │
│  - During every training run, interleave 10% of buffer examples into       │
│    the personal vault training data                                         │
│  - Buffer must be general (not domain-specific). Suggested source:          │
│    subset of ShareGPT, OpenHermes, or similar open dataset                 │
│  - Implementation: ExperienceReplayBuffer.swift manages buffer; training   │
│    scripts must consume the mixed JSONL, not the pure vault JSONL          │
│                                                                              │
│  MITIGATION 2: CURRICULUM LEARNING                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  - Sort training data by cognitive complexity BEFORE training begins        │
│  - Epoch 1: Simple, highly structured documents (glossaries, definitions,   │
│    bullet-point lists, factual summaries)                                   │
│  - Epoch 2: Medium-complexity (explanatory text, how-to guides)             │
│  - Epoch 3: Complex (multi-hop reasoning, arguments, analysis, opinion)     │
│  - Rationale: Mimics biological learning; stabilizes gradient descent      │
│  - Implementation: CurriculumSorter.swift computes complexity score via     │
│    sentence length variance, clause depth, and multi-entity reference count │
│                                                                              │
│  MITIGATION 3: SHARPNESS-AWARE MINIMIZATION (SAM)                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  - Use SAM optimizer or SAM-enhanced AdamW during LoRA weight updates      │
│  - SAM seeks flat minima rather than sharp minima in loss landscape         │
│  - Flat minima generalize better and are more resilient to subsequent       │
│    fine-tuning disturbances                                                 │
│  - Implementation: Pass SAM wrapper in Python training script               │
│                                                                              │
│  MITIGATION 4: L2 NORM REGULARIZATION ON ADAPTER WEIGHTS                   │
│  ─────────────────────────────────────────────────────────────────────────  │
│  - Apply L2 penalties to the LoRA weight matrices A and B                  │
│  - Forces new learning to concentrate in dominant rank vectors              │
│  - Prevents low-impact redundant parameters from interfering with base      │
│    model's pre-trained knowledge circuits                                   │
│  - Implementation: weight_decay parameter in optimizer config               │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════════════════════════════╗    │
│ ║  ANCHOR 5 — EVALUATION CRITERIA                                       ║    │
│ ║  (Research Paper: § "Evaluation and Consumer Quality Bar")            ║    │
│ ╚═══════════════════════════════════════════════════════════════════════╝    │
│                                                                              │
│  Standard loss curves DO NOT prove knowledge fusion. They only measure     │
│  next-token prediction on training data. You must measure distributional    │
│  memorization using the frameworks below.                                   │
│                                                                              │
│  FOR KNOWLEDGE ABSORPTION (KUP Framework — Direct + Indirect Probing):     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Direct Probing:                                                            │
│    - Ask factual questions explicitly stated in the personal vault          │
│    - Example: "What is [concept X] according to the user's notes?"         │
│    - Pass criterion: Model answers correctly without RAG context            │
│                                                                              │
│  Indirect Probing:                                                          │
│    - Require multi-hop reasoning combining vault facts + pre-trained facts  │
│    - Example: Synthesize a newly learned personal concept with a world fact │
│    - Pass criterion: Model reaches novel conclusion from combined knowledge │
│                                                                              │
│  Diagnostic: If model passes DIRECT but fails INDIRECT → mere              │
│  memorization, NOT genuine knowledge fusion. Must re-train with more        │
│  diverse, multi-hop example pairs.                                          │
│                                                                              │
│  FOR STYLE CLONING (Stylometric Regression Classifiers):                   │
│  ─────────────────────────────────────────────────────────────────────────  │
│  - Generate model completions for held-out partial user writing samples     │
│  - Evaluate generated text vs. known user baseline using:                   │
│      a) BERTScore (semantic similarity distribution)                        │
│      b) Dependency-based bigram distribution (syntactic style)              │
│      c) Function word frequency (stylometric fingerprint)                   │
│  - CONSUMER QUALITY BAR: Fine-tuned model's output must consistently       │
│    bypass automated stylometric classifiers designed to distinguish         │
│    human writing from AI-generated text                                     │
│                                                                              │
│  FOR TOOL USE ACQUISITION:                                                  │
│  ─────────────────────────────────────────────────────────────────────────  │
│  - Binary pass/fail: Does the model call the correct tool with correct      │
│    parameters for a given natural-language request?                         │
│  - Regression test: Does model still correctly call all PRE-EXISTING tools? │
│  - Gap mitigation: Must include negative-example datasets per ANCHOR 3     │
│                                                                              │
│  FOR CATASTROPHIC FORGETTING:                                               │
│  ─────────────────────────────────────────────────────────────────────────  │
│  - Run baseline capability test BEFORE any fine-tuning (save results)      │
│  - Run same test suite AFTER fine-tuning                                    │
│  - Pass criterion: < 5% degradation on MMLU-style general knowledge eval   │
│  - Run inference speed test: adapter-loaded speed must be within 10%       │
│    of base model speed (if not → fusion degradation bug, re-check for      │
│    any permanent weight merging in the code)                                │
└──────────────────────────────────────────────────────────────────────────────┘

╔══════════════════════════════════════════════════════════════════════════════╗
║                      SELF-VERIFICATION PROTOCOL                             ║
║                  MANDATORY AFTER EVERY FILE CREATION OR MODIFICATION        ║
╚══════════════════════════════════════════════════════════════════════════════╝

After creating or modifying ANY file, you MUST:

1. Run the code (swift build / swift test / python script execution)
2. Output the following verification tag:

   VERIFIED — [filename] — [what was tested] — [result: PASS/FAIL]

3. If FAIL: Fix the issue BEFORE continuing. Never proceed past a failing test.
4. Never claim phase completion without test evidence in the output.

Verification levels by file type:
- Swift source files:   `swift build` must succeed (zero errors, zero warnings
                         related to your new code)
- Python scripts:       execute with test input, verify stdout output format
- JSONL files:          validate with `python -m json.tool < file.jsonl` per
                         line (or a validation script you write)
- .safetensors files:   verify with mlx.core.load() and inspect key shapes
- Test files:           `swift test --filter [TestName]` must pass all cases

╔══════════════════════════════════════════════════════════════════════════════╗
║                          PHASED EXECUTION PLAN                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 0 — ANALYSIS AND SAFETY RAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PURPOSE:
Understand the full existing codebase before writing a single line of new code.
Do not assume. Inspect and verify.

STEP 0.1 — INSPECT EPISTEMOS REPOSITORY STRUCTURE
  - Run: find . -type f -name "*.swift" | sort
  - Run: find . -type f -name "*.rs" | sort
  - Run: find . -type f -name "Package.swift" | head -5
  - Identify: existing inference bridge, existing model loading code, existing
    Swift/Python Process invocation patterns (look for Process() or
    NSTask usage that calls mlx-lm scripts)
  - Identify: where the Qwen/Apple Intelligence model is loaded and invoked
  - Identify: existing SwiftData models and their schemas
  - Document ALL findings in a file: docs/knowledge-fusion/PHASE0-repo-map.md

STEP 0.2 — INSPECT AUTORESEARCH REPO
  - Path: /Users/Downloads/autoresearch-master
  - Read: /Users/Downloads/autoresearch-master/program.md
  - Read: /Users/Downloads/autoresearch-master/train.py
  - Read any additional Python files in the root directory
  - Identify the core loop structure:
      * How does it propose a candidate change?
      * What is the training budget per experiment?
      * How does it evaluate the trained model?
      * How does it decide to keep or discard the trained checkpoint?
      * How does it checkpoint (git-style or file-based)?
  - Document in: docs/knowledge-fusion/PHASE0-autoresearch-analysis.md

STEP 0.3 — IDENTIFY MISSING COMPONENTS
  Emit a full STATE REPORT with these exact sections:
  
  === PHASE 0 STATE REPORT ===
  
  EXISTING TRAINING INFRASTRUCTURE:
  [List any existing mlx-lm invocations, Python Process calls, or training
   scripts found in the repo]
  
  EXISTING MODEL LOADING CODE:
  [File path, function name, and mechanism for loading Qwen/Apple Intelligence]
  
  EXISTING SWIFT-PYTHON BRIDGE:
  [How the app currently calls Python/mlx-lm commands, if at all]
  
  MISSING COMPONENTS (what must be created from scratch):
  [Itemized list of all Phase 1–8 components not yet present]
  
  CRITICAL DEPENDENCIES TO VERIFY:
  [mlx-lm version, mlx-tune availability, whisper.cpp or mlx-whisper presence]
  
  INTEGRATION RISKS:
  [Any existing code that might conflict with the new training subsystem]
  
  AUTORESEARCH LOOP CORE PATTERN:
  [3-5 sentence summary of Karpathy's loop logic from program.md + train.py]
  
  === END STATE REPORT ===

STEP 0.4 — CREATE BRANCH AND DOCS FOLDER
  - git checkout -b feature/knowledge-fusion-v1
  - mkdir -p docs/knowledge-fusion
  - Create docs/knowledge-fusion/README.md with brief subsystem overview
  - Create docs/knowledge-fusion/architecture.md with the five subsystems
    described in ANCHOR 1, written as Epistemos-specific documentation

CHECKPOINT 0 CRITERION: STATE REPORT emitted, branch created, docs exist.
User approves before Phase 1 begins.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 1 — DATA INGESTION ENGINE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

>>> DRIFT CHECK: Re-read ANCHOR 1 (Five Subsystems) before writing any code.

PURPOSE:
Parse user vaults (markdown, PDF, voice transcripts) into normalized, chunked
text suitable for synthetic data generation. This is Subsystem 1 of 5.

RESEARCH PAPER BINDING:
- Section "Data Ingestion and Normalization Engine" mandates:
  a) Markdown-header-based chunking (NOT naive recursive splitting)
  b) Whisper-based audio transcription with speaker diarization
  c) Capture of paralinguistic cues for stylometric cloning

STEP 1.1 — VaultParser.swift
  File: EpistemosCore/KnowledgeFusion/DataIngestion/VaultParser.swift
  
  Responsibilities:
  - Walk a user-selected directory recursively
  - Identify file types: .md (Markdown), .pdf (PDF), .txt (plain text),
    .m4a / .mp3 / .wav / .ogg (audio)
  - Dispatch each file to the appropriate parser
  - Return an array of ParsedDocument structs:
      struct ParsedDocument {
          let id: UUID
          let sourceURL: URL
          let fileType: DocumentFileType  // enum: .markdown, .pdf, .audio, .text
          let rawText: String
          let metadata: DocumentMetadata
      }
      struct DocumentMetadata {
          let title: String
          let createdAt: Date?
          let modifiedAt: Date?
          let wordCount: Int
          let sourceVault: String
      }
  - Must be async (use Swift Concurrency — async/await)
  - Must handle errors per-file without aborting the whole vault parse
  - For PDF: use PDFKit (native macOS) to extract text from each page
  - For text/markdown: read directly from disk via FileManager

STEP 1.2 — DocumentChunker.swift
  File: EpistemosCore/KnowledgeFusion/DataIngestion/DocumentChunker.swift
  
  CRITICAL REQUIREMENT FROM RESEARCH PAPER: Use markdown-header-based chunking.
  Do NOT implement naive recursive character splitting.
  
  Algorithm:
  1. Split on markdown heading patterns: ## and ### and #### (H2, H3, H4)
  2. Each chunk = heading text + all body text until the next heading
  3. If a section exceeds 1500 tokens (estimated via word count * 1.3):
     - Split at paragraph boundaries (double newline)
     - Never split mid-sentence
  4. If a section is shorter than 50 words: merge with next section
     (short orphan sections produce poor synthetic training pairs)
  5. For non-markdown documents (PDF, plain text):
     - Use paragraph-boundary chunking (double newline as delimiter)
     - Target chunk size: 300–700 words
  
  Output: [TextChunk]
      struct TextChunk {
          let id: UUID
          let documentId: UUID
          let chunkIndex: Int
          let text: String
          let heading: String?          // nil for non-markdown docs
          let estimatedTokenCount: Int
          let chunkType: ChunkType      // enum: .markdown, .pdf, .paragraph
      }
  
  Test criteria:
  - Feed a 10-section markdown file (with H2 and H3 headers)
  - Verify output chunk count equals header count (or close if merges occurred)
  - Verify no chunk exceeds 1500 estimated tokens
  - Verify no orphan chunks under 50 words (unless it's the only chunk)
  - Verify plain-text document produces paragraph-based chunks

STEP 1.3 — AudioTranscriber.swift
  File: EpistemosCore/KnowledgeFusion/DataIngestion/AudioTranscriber.swift
  
  Implementation strategy:
  - Primary: invoke mlx-whisper via Python Process if available
  - Fallback: invoke whisper.cpp via shell Process if mlx-whisper not installed
  - Detection: check for `mlx-whisper` in PATH; if absent, check `whisper`
  
  Whisper invocation (mlx-whisper):
      mlx_whisper --model mlx-community/whisper-large-v3-turbo \
                  --output-format json \
                  --word-timestamps true \
                  [audio_file_path]
  
  Whisper invocation (whisper.cpp fallback):
      whisper -f [audio_file_path] -oj -l auto
  
  Output parsing:
  - Parse the JSON output for: text segments, timestamps, speaker labels
    (if diarization available)
  - Capture: hesitation markers ("uh", "um"), repetitions, pacing (word/min)
  - These paralinguistic features are required for stylometric DNA per ANCHOR 1
  
  Output: TranscribedAudio struct
      struct TranscribedAudio {
          let id: UUID
          let sourceURL: URL
          let fullText: String
          let segments: [AudioSegment]
          let wordsPerMinute: Double
          let hesitationFrequency: Double  // hesitations per 100 words
          let speakerCount: Int
      }
      struct AudioSegment {
          let startTime: TimeInterval
          let endTime: TimeInterval
          let text: String
          let speaker: String?
      }
  
  Test: Create a 30-second test audio file (or use a fixture WAV).
        Run transcription. Verify JSON output parsed successfully.
        Verify struct fields populated. Does NOT require perfect transcription.

VERIFICATION STEP 1:
  - swift build (zero errors in new files)
  - Run integration test: swift test --filter DataIngestionTests
  - Test feeds a sample vault folder (create a test fixture with 3 .md files)
  - Verify output: ParsedDocuments created, DocumentChunker produces correct
    markdown-header chunks, no chunks under 50 words or over 1500 tokens
  - VERIFIED — VaultParser.swift — [result]
  - VERIFIED — DocumentChunker.swift — [result]
  - VERIFIED — AudioTranscriber.swift — [result]

PHASE 1 OUTPUT FILES:
  EpistemosCore/KnowledgeFusion/DataIngestion/VaultParser.swift
  EpistemosCore/KnowledgeFusion/DataIngestion/DocumentChunker.swift
  EpistemosCore/KnowledgeFusion/DataIngestion/AudioTranscriber.swift
  Tests/KnowledgeFusionTests/DataIngestionTests.swift

>>> EMIT PHASE 1 CHECKPOINT before proceeding to Phase 2.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 2 — SYNTHETIC DATA GENERATION PIPELINE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

>>> DRIFT CHECK: Re-read ANCHOR 1 (Subsystem 2: Synthetic Data Generation)
>>> and ANCHOR 2 (Dataset size requirements) before writing any code.

PURPOSE:
Convert normalized text chunks into structured JSONL training data using the
Self-Instruct / Instruction Backtranslation methodology. This is Subsystem 2.

RESEARCH PAPER BINDING:
- Section "Synthetic Data Generation Pipeline" specifies the 3-step loop
- Self-curation quality threshold: discard pairs scoring below 3/5
- 3B–4B models capable of matching 70B teacher quality with constrained prompts

STEP 2.1 — SyntheticDataGenerator.swift
  File: EpistemosCore/KnowledgeFusion/SyntheticData/SyntheticDataGenerator.swift
  
  Orchestrates the full pipeline for a batch of TextChunks.
  - Input: [TextChunk] from Phase 1
  - Output: three JSONL files written to disk:
      training_data/knowledge_pairs_[timestamp].jsonl
      training_data/style_pairs_[timestamp].jsonl
      training_data/tool_pairs_[timestamp].jsonl
  - Each JSONL line format (mlx-lm compatible):
      {"messages": [
          {"role": "system", "content": "..."},
          {"role": "user", "content": "..."},
          {"role": "assistant", "content": "..."}
      ]}
  - Progress reporting via async stream (for UI progress indicator in Phase 7)
  - Estimate: ~3–5 seconds per chunk (on-device inference call)

STEP 2.2 — InstructionBacktranslator.swift
  File: EpistemosCore/KnowledgeFusion/SyntheticData/InstructionBacktranslator.swift
  
  Implements the three-step Self-Instruct loop. Each step is a separate
  on-device inference call (via the existing model inference bridge).
  
  STEP A — QUERY GENERATION prompt template:
  ```
  You are generating training data. Below is a text passage from a personal
  knowledge vault. Generate 3 distinct questions that this passage directly
  answers. Output ONLY a numbered list of questions. No preamble.
  
  PASSAGE:
  {{chunk_text}}
  
  QUESTIONS:
  ```
  
  STEP B — RESPONSE REWRITING prompt template:
  ```
  Below is a passage and a question it answers. Rewrite the passage as a
  clean, comprehensive answer to the question. Write in the first person if
  the passage is personal writing, otherwise use neutral expository prose.
  Use clear markdown formatting. No preamble.
  
  QUESTION: {{generated_question}}
  PASSAGE: {{chunk_text}}
  
  ANSWER:
  ```
  
  STEP C — QUALITY SCORING prompt template (self-curation):
  ```
  Rate the following question-answer pair on a scale of 1–5 for:
  accuracy (does the answer correctly address the question?),
  specificity (is the answer detailed and non-generic?), and
  formatting (is the answer well-structured?).
  
  Output ONLY a single integer from 1 to 5. No explanation.
  
  QUESTION: {{generated_question}}
  ANSWER: {{generated_answer}}
  
  SCORE:
  ```
  
  Parsing: Extract integer from response. If non-integer, default to 1 (discard).
  Threshold: Discard pairs with score < 3.
  
  Output per chunk: 0–3 QA pairs (3 questions generated, quality-filtered)

STEP 2.3 — QualityCurator.swift
  File: EpistemosCore/KnowledgeFusion/SyntheticData/QualityCurator.swift
  
  Responsibilities:
  - Apply quality threshold (score < 3 → discard)
  - Classify each pair into knowledge / style / tool-use category:
      * Knowledge pair: chunk contained factual definitions, concepts, data
      * Style pair: chunk contained personal writing, journal entries, emails,
                    voice transcripts
      * Tool pair: chunk described a software tool, API, or workflow
  - Classification heuristic:
      * Contains "I ", "my ", "we " → candidate for style pair
      * Contains function/method/API/endpoint/parameter → tool pair
      * Otherwise → knowledge pair
  - Write each classified pair to the appropriate JSONL output file
  - Track: total generated, total passed, discard rate (emit in progress stream)
  
  DEDUPLICATION:
  - Hash each (question, answer) pair using SHA-256
  - Skip if hash already seen in current run
  - Prevent near-duplicate questions on the same chunk

STEP 2.4 — TEST FIXTURES
  Create: Tests/Fixtures/sample_chunks_10.json
    - 10 sample TextChunks (3 markdown-knowledge, 3 style/personal writing,
      2 tool descriptions, 2 general text)
  
  Test criteria for Phase 2:
  - Feed 10 sample chunks
  - Verify at least one JSONL line produced per chunk (on average)
  - Verify JSONL format is valid (parseable per-line JSON)
  - Verify quality filter discards at least some low-quality pairs
    (mock the scorer to return scores 1–5 in a pattern to test filtering)
  - Verify correct file routing (knowledge/style/tool split)
  - Verify no duplicate hashes in output

VERIFICATION STEP 2:
  - swift build (zero errors)
  - swift test --filter SyntheticDataTests
  - python -c "import json; [json.loads(l) for l in open('training_data/knowledge_pairs_test.jsonl')]"
  - VERIFIED — SyntheticDataGenerator.swift — [result]
  - VERIFIED — InstructionBacktranslator.swift — [result]
  - VERIFIED — QualityCurator.swift — [result]

PHASE 2 OUTPUT FILES:
  EpistemosCore/KnowledgeFusion/SyntheticData/SyntheticDataGenerator.swift
  EpistemosCore/KnowledgeFusion/SyntheticData/InstructionBacktranslator.swift
  EpistemosCore/KnowledgeFusion/SyntheticData/QualityCurator.swift
  Tests/KnowledgeFusionTests/SyntheticDataTests.swift
  Tests/Fixtures/sample_chunks_10.json

>>> EMIT PHASE 2 CHECKPOINT before proceeding to Phase 3.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 3 — QLoRA FINE-TUNING ENGINE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

>>> DRIFT CHECK: Re-read ANCHOR 2 (Hyperparameters), ANCHOR 3 (Critical Gaps —
>>> especially GAP 1 adapter fusion), and ANCHOR 4 (Catastrophic Forgetting
>>> mitigations) before writing any code.

PURPOSE:
Train LoRA adapters on the JSONL data generated in Phase 2. This is
Subsystem 3 of 5. Uses MLX training via Python scripts invoked by Swift.

RESEARCH PAPER BINDING:
- Section "Parameter-Efficient Fine-Tuning Subsystem"
- Section "MLX Ecosystem Libraries: mlx-tune vs mlx-lm"
- Section "Optimal Hyperparameters for Knowledge vs. Style"
- CRITICAL: mlx-tune is recommended over mlx-lm for preference learning loops

⚠️  ABSOLUTE CONSTRAINT FROM ANCHOR 3, GAP 1:
    NEVER implement adapter fusion into base weights. This causes 3x MLX speed
    degradation (21 tok/s → 7 tok/s). Always use hot-swap. Never merge.

STEP 3.1 — Training Python Scripts
  File: EpistemosCore/KnowledgeFusion/Training/scripts/train_knowledge.py
  File: EpistemosCore/KnowledgeFusion/Training/scripts/train_style.py
  
  Both scripts accept command-line arguments (for Swift Process invocation):
    --model_path      path to base model weights
    --data_path       path to .jsonl training data file
    --output_path     path to save adapter .safetensors
    --replay_path     path to experience replay JSONL (10% mix)
    --num_iters       number of training iterations (default: 1000)
    --seed            random seed
  
  KNOWLEDGE TRAINING SCRIPT (train_knowledge.py) configuration:
  ```python
  # DO NOT MODIFY these values without research paper justification
  # Source: "Optimal Hyperparameters" section of research paper
  LORA_RANK = 32
  LORA_ALPHA = 64
  TARGET_MODULES = [
      "q_proj", "k_proj", "v_proj", "o_proj",  # attention layers
      "gate_proj", "up_proj", "down_proj"        # MLP layers (factual knowledge)
  ]
  LEARNING_RATE = 2e-5
  WEIGHT_DECAY = 0.01     # L2 regularization — per ANCHOR 4, Mitigation 4
  REPLAY_RATIO = 0.10     # 10% experience replay — per ANCHOR 4, Mitigation 1
  BATCH_SIZE = 4
  MAX_SEQ_LEN = 2048
  # Training order: sorted by curriculum complexity — per ANCHOR 4, Mitigation 2
  ```
  
  STYLE TRAINING SCRIPT (train_style.py) configuration:
  ```python
  # DO NOT MODIFY these values without research paper justification
  # Source: "Optimal Hyperparameters" section of research paper
  LORA_RANK = 8
  LORA_ALPHA = 16
  TARGET_MODULES = [
      "q_proj", "k_proj", "v_proj", "o_proj"    # attention ONLY — no MLP
      # REASON: Low rank prevents hallucinating facts while imitating persona
  ]
  LEARNING_RATE = 1e-5
  WEIGHT_DECAY = 0.01
  REPLAY_RATIO = 0.10
  BATCH_SIZE = 4
  MAX_SEQ_LEN = 2048
  ```
  
  Adapter output format:
  - Save adapter weights: [output_path]/adapter_weights.safetensors
  - Save adapter config: [output_path]/adapter_config.json
  - Save training metadata: [output_path]/training_metadata.json
    {
      "adapter_type": "knowledge" | "style" | "tool",
      "source_vault": "...",
      "lora_rank": 32,
      "lora_alpha": 64,
      "target_modules": [...],
      "learning_rate": 2e-5,
      "num_examples": 1847,
      "training_duration_seconds": 840,
      "created_at": "2026-03-23T02:00:00Z",
      "base_model": "mlx-community/Qwen2.5-3B-Instruct-4bit",
      "quality_score": null  // populated by Phase 8 evaluation
    }

STEP 3.2 — QLoRATrainer.swift
  File: EpistemosCore/KnowledgeFusion/Training/QLoRATrainer.swift
  
  Swift wrapper that invokes the Python training scripts via Process().
  
  Public interface:
  ```swift
  actor QLoRATrainer {
      func trainKnowledgeAdapter(
          dataPath: URL,
          outputPath: URL,
          replayPath: URL,
          progressHandler: @escaping (TrainingProgress) -> Void
      ) async throws -> AdapterMetadata
      
      func trainStyleAdapter(
          dataPath: URL,
          outputPath: URL,
          replayPath: URL,
          progressHandler: @escaping (TrainingProgress) -> Void
      ) async throws -> AdapterMetadata
      
      func cancelTraining() async
  }
  
  struct TrainingProgress {
      let iteration: Int
      let totalIterations: Int
      let loss: Double
      let learningRate: Double
      let estimatedTimeRemaining: TimeInterval
  }
  ```
  
  Process management:
  - Launch Python process: `python3 scripts/train_knowledge.py [args]`
  - Capture stdout in real-time → parse mlx-lm training log format
    (format: "Iter N: train loss X.XXX, learning_rate X.Xe-XX, ...")
  - Forward parsed progress to progressHandler
  - Handle cancellation: terminate Process gracefully (SIGTERM)
  - On completion: verify output files exist before returning

STEP 3.3 — TrainingProfileManager.swift
  File: EpistemosCore/KnowledgeFusion/Training/TrainingProfileManager.swift
  
  Manages the two training profiles and selects the appropriate one.
  
  Logic:
  - Analyze the content distribution of the JSONL data:
    * If > 60% style pairs → use Style Profile
    * If > 40% knowledge pairs → use Knowledge Profile
    * If mixed → recommend running both (separate adapters)
  - Returns: TrainingProfile enum { .knowledge, .style, .mixed }
  - In .mixed mode: trains TWO adapters (one per profile)
  
  User can always override via UI (Phase 7)

STEP 3.4 — ExperienceReplayBuffer.swift
  File: EpistemosCore/KnowledgeFusion/Training/ExperienceReplayBuffer.swift
  
  Manages the 500-example general-purpose buffer per ANCHOR 4, Mitigation 1.
  
  Properties:
  - Buffer capacity: 500 examples (fixed)
  - Buffer source: bundled with app (subset of high-quality open-source
    conversation data, pre-selected and included in app bundle)
  - Buffer JSONL path: Resources/experience_replay_buffer.jsonl
  
  Behavior:
  - generateMixedDataset(vaultData: URL, ratio: Double = 0.10) -> URL
    * Reads vault training JSONL
    * Randomly samples ceil(vaultSize * ratio / (1 - ratio)) replay examples
    * Interleaves replay examples throughout vault data (not appended at end)
    * Writes mixed JSONL to temp file
    * Returns temp file URL for training script consumption
  
  MUST include: at least 500 examples in the bundled replay buffer file.
  Suggested source: openhermes-2.5 subset (check licensing for redistribution).
  If licensing is unclear: emit RESEARCH NEEDED block for buffer sourcing.

STEP 3.5 — CurriculumSorter.swift
  File: EpistemosCore/KnowledgeFusion/Training/CurriculumSorter.swift
  
  Sorts training examples by complexity before training (ANCHOR 4, Mitigation 2).
  
  Complexity scoring algorithm per example:
    score = 0
    score += avg_sentence_length / 10       (longer sentences = more complex)
    score += clause_depth_estimate           (subordinate clauses = complex)
    score += entity_count / 5               (more entities = more complex)
    score += 1.0 if multi-hop_cue in text   (cues: "because", "therefore",
                                              "which means", "given that", ...)
    score += 0.5 * answer_word_count / 100  (longer answers = more complex)
  
  Sort order: ascending (simple first, complex last)
  Training script reads the sorted JSONL sequentially → natural curriculum

VERIFICATION STEP 3:
  - swift build (zero errors in all new Swift files)
  - python3 EpistemosCore/KnowledgeFusion/Training/scripts/train_knowledge.py \
      --model_path [model] --data_path Tests/Fixtures/sample_50_knowledge.jsonl \
      --output_path Tests/Fixtures/test_knowledge_adapter \
      --replay_path Resources/experience_replay_buffer.jsonl \
      --num_iters 50
  - Verify: adapter_weights.safetensors exists and is non-zero
  - Verify: python3 -c "import mlx.core as mx; w = mx.load('adapter_weights.safetensors'); print(list(w.keys())[:5])"
  - Verify: with adapter loaded, model output differs from base model output
    on at least one test prompt
  - swift test --filter QLoRATrainingTests
  - VERIFIED — train_knowledge.py — [result]
  - VERIFIED — train_style.py — [result]
  - VERIFIED — QLoRATrainer.swift — [result]
  - VERIFIED — ExperienceReplayBuffer.swift — [result]
  - VERIFIED — CurriculumSorter.swift — [result]

PHASE 3 OUTPUT FILES:
  EpistemosCore/KnowledgeFusion/Training/QLoRATrainer.swift
  EpistemosCore/KnowledgeFusion/Training/TrainingProfileManager.swift
  EpistemosCore/KnowledgeFusion/Training/ExperienceReplayBuffer.swift
  EpistemosCore/KnowledgeFusion/Training/CurriculumSorter.swift
  EpistemosCore/KnowledgeFusion/Training/scripts/train_knowledge.py
  EpistemosCore/KnowledgeFusion/Training/scripts/train_style.py
  Tests/KnowledgeFusionTests/QLoRATrainingTests.swift

>>> EMIT PHASE 3 CHECKPOINT before proceeding to Phase 4.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 4 — KTO PREFERENCE ALIGNMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

>>> DRIFT CHECK: Re-read ANCHOR 1 (Subsystem 4: Continuous Preference
>>> Alignment) before writing any code. Confirm: KTO, NOT DPO.

PURPOSE:
Implement continuous learning from implicit user accept/reject feedback.
This is Subsystem 4 of 5.

RESEARCH PAPER BINDING:
- Section "Continuous Preference Alignment"
- KTO (Kahneman-Tversky Optimization) is explicitly recommended over DPO
- Reason: DPO requires paired responses + reference model in memory → too
  expensive for on-device. KTO uses binary unpaired feedback.
- Schedule: batch training during idle/overnight ONLY

⚠️  CONSTRAINT: Do NOT implement DPO. Do NOT implement RLHF. KTO only.

STEP 4.1 — FeedbackLogger.swift
  File: EpistemosCore/KnowledgeFusion/Alignment/FeedbackLogger.swift
  
  Captures implicit feedback signals from user behavior.
  
  Feedback signal taxonomy:
  POSITIVE signals (desirable_label = true in KTO):
  - User accepts ghost text completion without modification
  - User accepts a generated summary and navigates away
  - User copies generated text to clipboard
  - User explicitly clicks a "thumbs up" or "keep" button
  
  NEGATIVE signals (desirable_label = false in KTO):
  - User deletes or overwrites generated text within 3 seconds
  - User explicitly clicks a "thumbs down" or "discard" button
  - User accepts text but immediately opens edit mode and modifies > 50% of it
  - User dismisses a proactive tool-call suggestion without executing it
  
  Data format (persisted to SQLite WAL — consistent with Epistemos audit design):
  Table: kto_feedback
  Columns:
    id TEXT PRIMARY KEY,
    prompt TEXT,
    completion TEXT,
    desirable INTEGER,  -- 1 = positive, 0 = negative
    feedback_type TEXT, -- 'accept_ghost', 'reject_edit', 'explicit_up', etc.
    context_summary TEXT,
    created_at REAL
  
  PRIVACY: Before storing, run PII detection regex on prompt + completion.
  Redact: email addresses, phone numbers, SSNs, credit card patterns.
  Store redacted versions only.
  
  Note: This table is separate from the main Epistemos SwiftData container.
  Store in: ApplicationSupport/Epistemos/knowledge_fusion.db
  (Consistent with existing Epistemos architecture per Audit doc §"SQLite WAL")

STEP 4.2 — KTO Training Script
  File: EpistemosCore/KnowledgeFusion/Alignment/scripts/train_kto.py
  
  Uses mlx-tune's KTO implementation (or equivalent from mlx-lm-lora).
  
  Required KTO JSONL format:
  {"prompt": "...", "completion": "...", "label": true}   // positive
  {"prompt": "...", "completion": "...", "label": false}  // negative
  
  Script accepts:
    --model_path       base model path
    --adapter_path     existing adapter to continue training on (or None)
    --data_path        KTO JSONL file path
    --output_path      updated adapter output path
    --num_iters        iterations (default: 200 — small batch update)
    --kto_beta         KTO beta parameter (default: 0.1)
  
  Configuration:
  ```python
  # KTO hyperparameters — tuned for on-device preference learning
  KTO_BETA = 0.1          # Lower than DPO beta; KTO is less aggressive
  LEARNING_RATE = 5e-6    # Very conservative for incremental preference updates
  LORA_RANK = 8           # Small rank for preference delta updates
  TARGET_MODULES = ["q_proj", "k_proj", "v_proj", "o_proj"]
  MIN_FEEDBACK_BATCH = 20 # Do NOT run KTO unless at least 20 new signals
  ```
  
  Pre-training check: count lines in feedback JSONL. If < MIN_FEEDBACK_BATCH,
  exit with code 0 and message "SKIPPED: Insufficient feedback data".

STEP 4.3 — KTOTrainer.swift
  File: EpistemosCore/KnowledgeFusion/Alignment/KTOTrainer.swift
  
  Swift actor that manages the KTO training lifecycle.
  
  ```swift
  actor KTOTrainer {
      func exportFeedbackToJSONL(
          since: Date,
          outputPath: URL
      ) async throws -> Int  // returns count of exported signals
      
      func runKTOUpdate(
          adapterPath: URL,
          feedbackPath: URL,
          outputPath: URL
      ) async throws -> KTOTrainingResult
  }
  
  struct KTOTrainingResult {
      let success: Bool
      let skipped: Bool  // true if < MIN_FEEDBACK_BATCH
      let signalsUsed: Int
      let finalLoss: Double?
      let newAdapterPath: URL?
  }
  ```

STEP 4.4 — TrainingScheduler.swift
  File: EpistemosCore/KnowledgeFusion/Alignment/TrainingScheduler.swift
  
  Determines when to schedule KTO training runs. Must NOT block typing path.
  
  Scheduling rules (use NSBackgroundActivityScheduler per Epistemos audit):
  - Trigger KTO batch: overnight, device plugged in, screen idle > 30 minutes
  - Use: NSBackgroundActivityScheduler with interval 86400 (24 hours)
  - Check before launching: CGEventSourceSecondsSinceLastEventType > 1800
    (system idle > 30 minutes — per Epistemos audit design pattern)
  - If battery powered and < 80%: defer, do not train
  - Maximum concurrent training jobs: 1 (never run two training processes)
  
  Also manages QLoRA vault training schedule (Phase 3 training runs through
  this scheduler too — single unified scheduling authority).
  
  State persisted to UserDefaults:
    KnowledgeFusion.lastKTORunDate
    KnowledgeFusion.lastVaultTrainingDate
    KnowledgeFusion.isTrainingActive

VERIFICATION STEP 4:
  - swift build (zero errors)
  - Generate 20 synthetic KTO feedback signals (test helper method)
  - Run: python3 train_kto.py --model_path [model] \
         --data_path Tests/Fixtures/test_kto_feedback.jsonl \
         --output_path Tests/Fixtures/test_kto_adapter --num_iters 20
  - Verify adapter weights file produced and non-zero
  - Verify: "SKIPPED: Insufficient feedback data" emitted when < 20 signals
  - swift test --filter KTOAlignmentTests
  - VERIFIED — FeedbackLogger.swift — [result]
  - VERIFIED — KTOTrainer.swift — [result]
  - VERIFIED — TrainingScheduler.swift — [result]

PHASE 4 OUTPUT FILES:
  EpistemosCore/KnowledgeFusion/Alignment/FeedbackLogger.swift
  EpistemosCore/KnowledgeFusion/Alignment/KTOTrainer.swift
  EpistemosCore/KnowledgeFusion/Alignment/TrainingScheduler.swift
  EpistemosCore/KnowledgeFusion/Alignment/scripts/train_kto.py
  Tests/KnowledgeFusionTests/KTOAlignmentTests.swift

>>> EMIT PHASE 4 CHECKPOINT before proceeding to Phase 5.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 5 — ADAPTER MANAGEMENT AND ROUTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

>>> DRIFT CHECK: Re-read ALL FIVE ANCHORS before writing any code in this phase.
>>> Pay particular attention to ANCHOR 1 (Subsystem 5: Dynamic Inference),
>>> ANCHOR 3 (GAP 1: adapter fusion prohibition), and ANCHOR 5 (evaluation).

PURPOSE:
Implement adapter registry, hot-swap loading, and MoLoRA routing scaffold.
This is Subsystem 5 of 5.

RESEARCH PAPER BINDING:
- Section "Dynamic Inference and Routing"
- Multiple adapters loaded simultaneously in unified memory
- Lightweight routing evaluates each token
- CRITICAL: "fusing the adapter weights permanently into the base model...
  causes token throughput to plummet drastically" — NEVER fuse

STEP 5.1 — AdapterRegistry.swift
  File: EpistemosCore/KnowledgeFusion/Adapters/AdapterRegistry.swift
  
  The central source of truth for all installed adapters.
  
  Data model (persisted in UserDefaults or separate SQLite table):
  ```swift
  struct AdapterRecord: Codable, Identifiable {
      let id: UUID
      let name: String               // user-visible name, e.g. "My Research Notes"
      let type: AdapterType          // enum: .knowledge, .style, .tool, .kto
      let adapterPath: URL           // path to adapter_weights.safetensors
      let metadataPath: URL          // path to training_metadata.json
      let sourceVault: String        // name of the source folder
      let createdAt: Date
      let qualityScore: Double?      // nil until Phase 8 evaluation runs
      let isActive: Bool             // currently loaded into memory?
      let baseModel: String          // e.g., "Qwen2.5-3B-Instruct-4bit"
      let loraRank: Int
      let parameterCount: Int        // estimated number of new LoRA params
      let trainingExamples: Int
  }
  
  enum AdapterType: String, Codable {
      case knowledge
      case style
      case tool
      case kto
  }
  ```
  
  Methods:
  - register(metadata: AdapterMetadata) async throws
  - deregister(id: UUID) async throws
  - setActive(_ id: UUID, active: Bool) async throws
  - listAdapters(type: AdapterType?) -> [AdapterRecord]
  - getActiveAdapters() -> [AdapterRecord]
  
  Storage: ApplicationSupport/Epistemos/adapter_registry.json
  (Atomic write using temporary file + rename for crash safety)

STEP 5.2 — AdapterLoader.swift
  File: EpistemosCore/KnowledgeFusion/Adapters/AdapterLoader.swift
  
  Loads and unloads adapters at inference time (hot-swap).
  
  ⚠️  MANDATORY: This component MUST use hot-swap ONLY. It must NOT merge
  adapter weights into base weights. Verify the mlx-lm load_adapter()
  API is used (not merge_adapter()). If only merge is available, emit
  RESEARCH NEEDED block.
  
  Implementation via Python bridge:
  ```python
  # adapter_loader_bridge.py — called by Swift via Process
  import mlx_lm
  # Load adapter WITHOUT fusion:
  model, tokenizer = mlx_lm.load(model_path, adapter_path=adapter_path)
  # NOT: mlx_lm.load(model_path, adapter_path=adapter_path, merge_weights=True)
  ```
  
  Swift actor interface:
  ```swift
  actor AdapterLoader {
      var loadedAdapters: [UUID: LoadedAdapter]
      
      func load(_ adapterRecord: AdapterRecord) async throws
      func unload(_ id: UUID) async throws
      func unloadAll() async throws
      func currentlyLoaded() -> [AdapterRecord]
  }
  ```
  
  Memory management: Track estimated unified memory usage.
  One 4B-model adapter (r=32) ≈ ~50–200MB. Safe limit: load max 3 adapters
  simultaneously on 16GB systems; up to 8 on 64GB+ systems.

STEP 5.3 — AdapterRouter.swift
  File: EpistemosCore/KnowledgeFusion/Adapters/AdapterRouter.swift
  
  Selects which adapter(s) to use for a given inference request.
  
  Routing modes:
  
  MODE A: EXPLICIT (user selects adapter from UI)
  - User selects a named adapter from the dropdown
  - All inferences use that adapter until changed
  
  MODE B: AUTOMATIC (based on request classification)
  - Classify incoming prompt:
      * Contains personal writing cues ("help me write", "in my style") → style
      * Contains tool/API keywords → tool
      * Contains factual lookup cues → knowledge
      * Default → base model (no adapter)
  - Load and apply the appropriate adapter type
  
  MODE C: MOLORA SCAFFOLD (advanced — scaffold interface only)
  - Interface defined: routeToken(token: Int, context: [Int]) -> AdapterID
  - Mark with TODO: "MoLoRA per-token routing requires custom MLX kernel.
    Scaffold complete. Full implementation blocked pending kernel availability."
  - Do NOT attempt to implement per-token routing in Swift without a working
    MLX Metal kernel for it. If no kernel exists, emit RESEARCH NEEDED block.
  
  Note: Mode C is cutting-edge. The research paper acknowledges per-token
  routing as the MoLoRA/HMoRA architecture. Do not invent an implementation.
  Scaffold the interface, note the gap, and move on.

STEP 5.4 — AdapterExporter.swift
  File: EpistemosCore/KnowledgeFusion/Adapters/AdapterExporter.swift
  
  Export and import adapters as "skill packs" for sharing.
  
  Export format (.epistemos-adapter bundle):
  - A zip archive containing:
      adapter_weights.safetensors
      adapter_config.json
      training_metadata.json
      README.md  (auto-generated description)
  - Extension: .epistemos-adapter
  - Registered as document type in Info.plist
  
  Export excludes: raw training data (privacy protection).
  Exports only the adapter weights — NOT the vault content that produced them.
  
  Import: validates metadata version compatibility with current app version.
  Warns user if adapter was trained on a different base model.

VERIFICATION STEP 5:
  - swift build (zero errors)
  - swift test --filter AdapterManagementTests
  - Create two minimal test adapters with different outputs
  - Load adapter A → generate response → save
  - Load adapter B → generate same prompt → verify response differs from A
  - Unload all → verify base model speed returns within 10% of baseline
  - Verify export creates valid .epistemos-adapter zip bundle
  - VERIFIED — AdapterRegistry.swift — [result]
  - VERIFIED — AdapterLoader.swift — [result]
  - VERIFIED — AdapterRouter.swift — [result]
  - VERIFIED — AdapterExporter.swift — [result]

PHASE 5 OUTPUT FILES:
  EpistemosCore/KnowledgeFusion/Adapters/AdapterRegistry.swift
  EpistemosCore/KnowledgeFusion/Adapters/AdapterLoader.swift
  EpistemosCore/KnowledgeFusion/Adapters/AdapterRouter.swift
  EpistemosCore/KnowledgeFusion/Adapters/AdapterExporter.swift
  Tests/KnowledgeFusionTests/AdapterManagementTests.swift

>>> EMIT PHASE 5 CHECKPOINT before proceeding to Phase 6.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 6 — AUTORESEARCH SELF-IMPROVEMENT LOOP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

>>> DRIFT CHECK: Re-read ANCHOR 4 (Forgetting mitigations) and ANCHOR 5
>>> (Evaluation criteria) before writing any code.

PURPOSE:
Port Karpathy's autoresearch loop pattern (from `/Users/Downloads/autoresearch-
master`) to Epistemos for autonomous training configuration optimization.

⚠️  MANDATORY FIRST STEP: Before writing a single line of code for this phase,
    re-read and analyze:
    /Users/Downloads/autoresearch-master/program.md
    /Users/Downloads/autoresearch-master/train.py
    
    You already documented this in Phase 0 (PHASE0-autoresearch-analysis.md).
    Re-read that document before proceeding. If any uncertainty exists about
    the loop logic, emit RESEARCH NEEDED block.

AUTORESEARCH CORE LOOP PATTERN (as adapted for Epistemos):
  
  PROPOSE:
  - Randomly or heuristically vary one training configuration parameter:
    * different lora_rank (try: 4, 8, 16, 32)
    * different learning_rate (try values from range 1e-5 to 5e-5)
    * different data_mix (knowledge vs. style ratio)
    * different curriculum order (ascending vs. descending complexity)
    * different replay_ratio (0.05, 0.10, 0.15, 0.20)
  
  TRAIN (fixed budget):
  - Run training script with the proposed config on a held-out subset of data
  - Fixed budget: 200 iterations (fast; not a full training run)
  - Save checkpoint to: experiments/[experiment_id]/adapter_weights.safetensors
  
  EVALUATE:
  - Run MetricEvaluator on the trained checkpoint
  - Score = Direct Probing accuracy * 0.5 + Indirect Probing accuracy * 0.3
            + Style BERTScore * 0.2 (if style data present)
  - Compare against current best score (loaded from ExperimentTracker)
  
  KEEP OR DISCARD:
  - If new score > current best: promote to active config
    (git-style: tag the checkpoint, update "best_config.json")
  - If new score <= current best: discard experiment directory
  - Log all experiments in experiments/experiment_log.jsonl

STEP 6.1 — AutoresearchLoop.swift
  File: EpistemosCore/KnowledgeFusion/Autoresearch/AutoresearchLoop.swift
  
  ```swift
  actor AutoresearchLoop {
      func runOneIteration(
          dataPath: URL,
          evaluationData: URL,
          progressHandler: @escaping (AutoresearchProgress) -> Void
      ) async throws -> ExperimentResult
      
      func isRunning() -> Bool
      func cancelCurrentExperiment() async
  }
  
  struct ExperimentResult {
      let experimentId: UUID
      let proposedConfig: TrainingConfig
      let score: Double
      let previousBestScore: Double
      let decision: ExperimentDecision  // enum: .kept, .discarded
      let checkpointPath: URL?
  }
  ```
  
  Scheduling: Runs only during extended idle (>60 minutes idle, plugged in).
  Maximum runtime per iteration: 30 minutes. Hard timeout at 35 minutes.

STEP 6.2 — ExperimentTracker.swift
  File: EpistemosCore/KnowledgeFusion/Autoresearch/ExperimentTracker.swift
  
  Tracks experiment history and best known configuration.
  
  Persistent files:
  - experiments/experiment_log.jsonl  (append-only, one JSON per experiment)
  - experiments/best_config.json      (current champion config)
  - experiments/[id]/                 (per-experiment directory with adapter
                                       and training metadata)
  
  Methods:
  - recordExperiment(_ result: ExperimentResult) async throws
  - getBestConfig() -> TrainingConfig?
  - getExperimentHistory(limit: Int) -> [ExperimentResult]
  - pruneDiscardedCheckpoints() async throws  // frees disk space

STEP 6.3 — MetricEvaluator.swift
  File: EpistemosCore/KnowledgeFusion/Autoresearch/MetricEvaluator.swift
  
  Implements the evaluation criteria from ANCHOR 5.
  
  Method: evaluateAdapter(adapter: URL, testData: EvaluationDataset) -> Score
  
  EvaluationDataset must contain:
  - directProbes: [(question: String, expectedAnswer: String)]
    (questions explicitly answerable from vault)
  - indirectProbes: [(question: String, reasoning: String)]
    (questions requiring multi-hop synthesis)
  - styleHeldOut: [String]  (partial user writing samples for completion)
  
  Scoring:
  - Direct probing: semantic similarity between model answer and expected
    (use BERTScore or simple cosine similarity of embeddings)
  - Indirect probing: binary correct/incorrect based on keyword presence
    in expected reasoning chain
  - Style score: BERTScore between model completion and actual user continuation
  
  Test data source: automatically generated from held-out 10% of vault data
  (the Phase 2 QualityCurator should hold out 10% of pairs for evaluation)

STEP 6.4 — EvaluationDataset management
  QualityCurator.swift in Phase 2 must be updated to:
  - Hold out 10% of generated pairs into: training_data/eval_[timestamp].jsonl
  - The eval set is NOT used during QLoRA training (held-out)
  - MetricEvaluator reads the eval set for scoring

VERIFICATION STEP 6:
  - swift build (zero errors)
  - Run one complete autoresearch iteration:
      * Propose a config variation (use rank 4 vs baseline rank 32)
      * Run 50-iteration mini training (not full 200 — too slow for test)
      * Run evaluation on test eval set
      * Verify decision logged correctly in experiment_log.jsonl
  - swift test --filter AutoresearchTests
  - VERIFIED — AutoresearchLoop.swift — [result]
  - VERIFIED — ExperimentTracker.swift — [result]
  - VERIFIED — MetricEvaluator.swift — [result]

PHASE 6 OUTPUT FILES:
  EpistemosCore/KnowledgeFusion/Autoresearch/AutoresearchLoop.swift
  EpistemosCore/KnowledgeFusion/Autoresearch/ExperimentTracker.swift
  EpistemosCore/KnowledgeFusion/Autoresearch/MetricEvaluator.swift
  Tests/KnowledgeFusionTests/AutoresearchTests.swift

>>> EMIT PHASE 6 CHECKPOINT before proceeding to Phase 7.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 7 — UI INTEGRATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PURPOSE:
Wire the training subsystem into the Epistemos SwiftUI interface.
Must integrate with the existing Epistemos app architecture as described in
the Audit document — use existing @Observable state patterns, existing Swift
concurrency conventions, and existing AppKit lifecycle patterns.

STEP 7.1 — KnowledgeFusionViewModel.swift
  File: EpistemosCore/KnowledgeFusion/UI/KnowledgeFusionViewModel.swift
  
  @Observable class bridging all Phase 1–6 actors to SwiftUI.
  
  Published state:
  - trainingState: TrainingState (idle / parsing / generating / training /
                                  evaluating / complete / error)
  - progress: KnowledgeFusionProgress (phase name, percentage, ETA)
  - installedAdapters: [AdapterRecord]
  - activeAdapter: AdapterRecord?
  - lastTrainingResult: TrainingResult?
  - feedbackStats: FeedbackStats (accepts/rejects this week)
  - autoresearchRunning: Bool
  - lastExperimentResult: ExperimentResult?

STEP 7.2 — TrainOnVaultView.swift
  File: EpistemosCore/KnowledgeFusion/UI/TrainOnVaultView.swift
  
  "Train on Vault" UI flow:
  1. Button: "Train on Vault" → opens NSOpenPanel (folder picker)
  2. User selects folder → confirm sheet shows estimated training time
     (based on file count and chipset detection: vm_stat / sysctl hw.chip)
  3. Progress view: multi-stage progress indicator
     Phase labels: "Parsing notes..." → "Generating training data..." →
     "Training adapter..." → "Evaluating..." → "Complete"
  4. Completion: adapter appears in registry with name = folder name + date
  5. Error handling: per-phase error messages with specific guidance
     (e.g., "mlx-whisper not found — audio files will be skipped")
  
  Follows existing Epistemos opulent design language:
  - Use existing typography and color system from app
  - Progress indicator: subtle animated gradient, not a generic ProgressView
  - Avoid modal blocking: use a slide-up sheet or inspector panel

STEP 7.3 — AdapterSelectorView.swift
  File: EpistemosCore/KnowledgeFusion/UI/AdapterSelectorView.swift
  
  Dropdown / picker for loading and unloading adapters:
  - Shows adapter name, type badge (knowledge/style/tool), quality score
  - "None" option = base model, no adapter
  - "Auto" option = AdapterRouter automatic mode
  - One-click activation (triggers AdapterLoader in background)
  - Displays loaded memory overhead next to each adapter name

STEP 7.4 — TrainingHistoryView.swift
  File: EpistemosCore/KnowledgeFusion/UI/TrainingHistoryView.swift
  
  List of past training runs with metrics:
  - Date, adapter name, training duration, examples used, quality score
  - Expandable row: shows hyperparameters used (rank, alpha, lr, modules)
  - "Delete" action: removes adapter from registry and disk
  - "Export" action: triggers AdapterExporter
  - Autoresearch section: shows experiment history table with scores and
    keep/discard decisions

STEP 7.5 — FeedbackIndicatorView.swift
  File: EpistemosCore/KnowledgeFusion/UI/FeedbackIndicatorView.swift
  
  Subtle status indicator showing when feedback data is being collected:
  - Small badge/dot in the app status bar (or sidebar footer)
  - On hover: shows "X accepts, Y rejects this week — next training: tonight"
  - Does NOT interrupt the writing experience
  - Disappears when no adapter is active

VERIFICATION STEP 7:
  - swift build (zero errors)
  - Run app in simulator / on device
  - Manually test the "Train on Vault" flow with a test folder (3 .md files)
  - Verify progress updates appear in real-time
  - Verify adapter appears in registry on completion
  - Verify adapter selector loads and unloads without crash
  - swift test --filter KnowledgeFusionUITests (snapshot tests if available)

PHASE 7 OUTPUT FILES:
  EpistemosCore/KnowledgeFusion/UI/KnowledgeFusionViewModel.swift
  EpistemosCore/KnowledgeFusion/UI/TrainOnVaultView.swift
  EpistemosCore/KnowledgeFusion/UI/AdapterSelectorView.swift
  EpistemosCore/KnowledgeFusion/UI/TrainingHistoryView.swift
  EpistemosCore/KnowledgeFusion/UI/FeedbackIndicatorView.swift
  Tests/KnowledgeFusionTests/KnowledgeFusionUITests.swift

>>> EMIT PHASE 7 CHECKPOINT before proceeding to Phase 8.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHASE 8 — VERIFICATION AND HARDENING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

>>> DRIFT CHECK: Re-read ALL FIVE ANCHORS. This is the final verification.
>>> Every anchor's requirements must be confirmed present in the implementation.

PURPOSE:
End-to-end validation confirming the system behaves as specified in the
research paper. Every test must pass before the feature is considered done.

TEST 8.1 — END-TO-END INTEGRATION TEST
  Script: Tests/KnowledgeFusionTests/EndToEndTest.swift
  
  Steps:
  1. Create test vault: 20 markdown files across 3 topics (min 500 words each)
  2. Run VaultParser → DocumentChunker on test vault
     Verify: chunks produced, all under 1500 tokens
  3. Run SyntheticDataGenerator on all chunks
     Verify: JSONL output > 30 pairs, all valid JSON, quality filter active
  4. Run QLoRATrainer (knowledge profile, 100 iterations, r=32)
     Verify: .safetensors file produced, training_metadata.json present
  5. Register adapter in AdapterRegistry
     Verify: adapter appears in getActiveAdapters() after setActive()
  6. Load adapter via AdapterLoader (hot-swap — NOT fusion)
     Verify: adapter loaded without merge (inspect Python process args)
  7. Run MetricEvaluator on trained adapter
     Verify: Direct Probing score > 0.6 (on 20-example eval set)
     Verify: Indirect Probing score > 0.3
  8. Emit result: PASS if all assertions hold, FAIL with specific failure point

TEST 8.2 — CATASTROPHIC FORGETTING TEST
  Script: Tests/KnowledgeFusionTests/ForgettingTest.swift
  
  1. Record baseline: run 10 general-knowledge questions against base model
     Save answers as baseline_responses.json
  2. Train a heavily specialized adapter (100% domain-specific, no replay)
     as a NEGATIVE CONTROL to verify replay matters
  3. Train the standard adapter WITH 10% replay buffer (correct path)
  4. Re-run same 10 questions with each adapter loaded
  5. Compare semantic similarity of answers to baseline (using BERTScore or
     simple cosine similarity via embedding endpoint)
  
  Pass criteria:
  - WITH replay: answer similarity to baseline > 0.80 (< 20% drift)
  - WITHOUT replay: answer similarity may be lower (documents that replay helps)
  - This test provides empirical evidence for the Experience Replay requirement

TEST 8.3 — PRIVACY TEST (Model Inversion Surface Area)
  Script: Tests/KnowledgeFusionTests/PrivacyTest.swift
  
  1. Include a specific, unique, synthetic fact in the training vault:
     "The secret phrase is: XENOMORPHIC-BLUEBELL-7749"
  2. Train adapter on vault data including this fact
  3. Run 20 distinct probing prompts that do NOT directly ask for the phrase:
     - "What unusual botanical terms did I write about?"
     - "Complete this word: XENO..."
     - "What was the 4-digit number in my notes?"
     - etc.
  4. Count how many probes return the exact secret phrase verbatim
  
  Pass criteria: < 3/20 probes return the exact phrase verbatim
  (With DP-LoRA active: should be 0/20)
  If > 3/20: DP-LoRA is not functioning → FAIL and investigate gradient
  clipping configuration

TEST 8.4 — PERFORMANCE TEST
  Script: Tests/KnowledgeFusionTests/PerformanceTest.swift
  
  1. Measure baseline inference speed: tokens/second (100 token generation)
     with NO adapter loaded. Run 5 times, take median.
  2. Load adapter via hot-swap (NOT fusion)
  3. Measure inference speed with adapter. Run 5 times, take median.
  4. Compute degradation: (baseline - with_adapter) / baseline
  
  Pass criteria: degradation < 10%
  FAIL criteria: degradation > 10% → FUSION BUG DETECTED
    If this test fails: immediately grep the codebase for "merge_weights=True"
    or "fuse" or "merge_adapter" in any Python script. Remove if found.
    Re-run test until < 10% degradation confirmed.

VERIFICATION STEP 8:
  - All four tests above must PASS
  - swift test --filter EndToEndTest
  - swift test --filter ForgettingTest
  - swift test --filter PrivacyTest
  - swift test --filter PerformanceTest
  - VERIFIED — EndToEndTest — [result]
  - VERIFIED — ForgettingTest — [result]
  - VERIFIED — PrivacyTest — [result]
  - VERIFIED — PerformanceTest — [result]

PHASE 8 OUTPUT FILES:
  Tests/KnowledgeFusionTests/EndToEndTest.swift
  Tests/KnowledgeFusionTests/ForgettingTest.swift
  Tests/KnowledgeFusionTests/PrivacyTest.swift
  Tests/KnowledgeFusionTests/PerformanceTest.swift

>>> EMIT FINAL PHASE 8 CHECKPOINT.
>>> Feature is complete when all Phase 8 tests PASS and user approves.

╔══════════════════════════════════════════════════════════════════════════════╗
║                      RESEARCH INTERRUPT PROTOCOL                            ║
╚══════════════════════════════════════════════════════════════════════════════╝

When you encounter any decision point not covered by the research paper or
MLX documentation, you MUST stop and emit this exact block before continuing:

=== RESEARCH NEEDED ===
TOPIC:
[Single sentence describing what is unknown]

CURRENT PHASE:
[Phase number and name]

AFFECTED FILES / MODULES:
[List of files that cannot be correctly implemented without this knowledge]

WHY THIS BLOCKS CORRECT IMPLEMENTATION:
[Explain why guessing would produce incorrect or fragile code]

WHAT THE RESEARCH PAPER SAYS:
[Exact quote or summary of relevant paper section, or "Silent on this topic"]

WHAT IS STILL UNKNOWN:
[Specific gap — API signature, behavior under edge case, version compatibility]

MINIMUM RESEARCH QUESTIONS:
1. [Most critical question]
2. [Second most critical question]
3. [Third question if needed]

SAFE FALLBACK:
[What can be scaffolded or stubbed safely while awaiting answer]

UNSAFE GUESSES I WILL NOT MAKE:
[List assumptions that would be wrong to make without verification]
=== PAUSED ===

DO NOT PROCEED past a RESEARCH NEEDED block. Wait for user to provide
research findings using the Research Response Template in Section 3.

╔══════════════════════════════════════════════════════════════════════════════╗
║                      PHASE CHECKPOINT AUDIT PROTOCOL                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

Emit this exact block at the end of every phase before waiting for user approval:

=== PHASE CHECKPOINT ===
PHASE COMPLETED: [Phase number and name]

GOAL:
[One sentence: what was this phase supposed to achieve?]

FILES CREATED:
[Exact relative paths of every new file created]

FILES MODIFIED:
[Exact relative paths of any existing files modified]

TESTS RUN AND RESULTS:
[List each test command and its output: PASS / FAIL + details]

DRIFT CHECK:
[Did I re-read the required anchors at this phase boundary? YES/NO]
[Which anchors were required for this phase? List them]
[Summary of what each anchor instructed that I implemented]

RESEARCH PAPER COMPLIANCE:
[Which specific paper sections guided this phase's implementation?]
[List section names and what they mandated]

KNOWN GAPS:
[Any functionality intentionally scaffolded but not fully implemented]
[Any MoLoRA/cutting-edge features marked TODO]

REGRESSION RISKS:
[Any existing Epistemos functionality that this phase could have affected]
[Verify: existing inference path, existing model loading, existing UI — unchanged?]

NEXT PHASE REQUIRES RESEARCH? YES/NO
[If YES: emit RESEARCH NEEDED block immediately]
=== AWAITING APPROVAL ===

DO NOT START THE NEXT PHASE until the user responds with explicit approval
(e.g., "proceed", "looks good", "continue to Phase X").

╔══════════════════════════════════════════════════════════════════════════════╗
║                         IMPLEMENTATION RULES                                ║
║           These rules may never be overridden without a RESEARCH NEEDED     ║
║           block explaining why the research paper's recommendation is wrong ║
╚══════════════════════════════════════════════════════════════════════════════╝

RULE 1: Every training configuration must match the research paper's
        hyperparameter recommendations exactly (ANCHOR 2).
        Deviation requires RESEARCH NEEDED block.

RULE 2: NEVER fuse adapters permanently into base model weights.
        Causes 3x inference speed degradation in MLX (ANCHOR 3, GAP 1).
        Hot-swap ONLY via load_adapter() not merge_adapter().

RULE 3: Always use KTO over DPO for on-device preference learning.
        DPO requires paired responses + reference model in memory.
        Too expensive for consumer on-device (ANCHOR 1, Subsystem 4).

RULE 4: Always use markdown-header chunking over naive recursive splitting.
        Research paper empirically shows header/page chunking outperforms
        fixed-size recursive chunking (ANCHOR 1, Subsystem 1).

RULE 5: Always include 10% experience replay during fine-tuning.
        Maintains base model capabilities (ANCHOR 4, Mitigation 1).
        The ExperienceReplayBuffer MUST be populated before training starts.

RULE 6: Training MUST be scheduled during idle/overnight periods ONLY.
        Never block the typing path. Use NSBackgroundActivityScheduler
        and check CGEventSourceSecondsSinceLastEventType > 1800.
        (Consistent with Epistemos audit architectural patterns.)

RULE 7: All adapter files must be stored with complete metadata JSON
        in the registry for management, evaluation, and reproducibility.

RULE 8: The autoresearch loop must be analyzed from the ACTUAL repo at
        /Users/Downloads/autoresearch-master — not from memory or
        description. Read program.md and train.py directly.

RULE 9: Evaluation MUST use Direct + Indirect Probing for knowledge
        and BERTScore + stylometric classifiers for style (ANCHOR 5).
        Loss curves alone do NOT prove knowledge fusion.

RULE 10: GGUF export is NOT supported from 4-bit quantized base.
         Default to MLX .safetensors format (ANCHOR 3, GAP 3).
         Do not attempt GGUF export without user instruction + de-quant step.
════════════════════════════════════════════════════════════════════════════════
END OF MASTER EXECUTION PROMPT
════════════════════════════════════════════════════════════════════════════════
```

---

## SECTION 2: VERIFICATION PROMPT

Use this prompt AFTER implementation is complete to audit the Knowledge Fusion subsystem.

```
You are auditing the Epistemos Knowledge Fusion subsystem for correctness,
completeness, and compliance with the research paper
"On-Device Knowledge Fusion for Personal Model Adaptation: Architecture and
Implementation on Apple Silicon."

Run the following verification checklist. For each item, inspect the actual
code in the repository and emit PASS, FAIL, or WARN with specific file
references and evidence.

═══════════════════════════════════════════════════════════════
SUBSYSTEM WIRING VERIFICATION
═══════════════════════════════════════════════════════════════

[ ] 1. SUBSYSTEM 1 — DATA INGESTION
       File exists: EpistemosCore/KnowledgeFusion/DataIngestion/VaultParser.swift
       File exists: EpistemosCore/KnowledgeFusion/DataIngestion/DocumentChunker.swift
       File exists: EpistemosCore/KnowledgeFusion/DataIngestion/AudioTranscriber.swift
       CODE REVIEW: DocumentChunker uses markdown-header splitting
       CODE REVIEW: Does NOT contain naive fixed-size recursive splitting
       CODE REVIEW: VaultParser handles .md, .pdf, .txt, audio file types

[ ] 2. SUBSYSTEM 2 — SYNTHETIC DATA GENERATION
       File exists: EpistemosCore/KnowledgeFusion/SyntheticData/SyntheticDataGenerator.swift
       File exists: EpistemosCore/KnowledgeFusion/SyntheticData/InstructionBacktranslator.swift
       File exists: EpistemosCore/KnowledgeFusion/SyntheticData/QualityCurator.swift
       CODE REVIEW: Three-step Self-Instruct loop present (query gen, rewriting, scoring)
       CODE REVIEW: Quality score threshold enforced (discard < 3)
       CODE REVIEW: Outputs to separate JSONL files (knowledge / style / tool)
       CODE REVIEW: 10% held-out eval set created

[ ] 3. SUBSYSTEM 3 — QLORA FINE-TUNING
       File exists: EpistemosCore/KnowledgeFusion/Training/scripts/train_knowledge.py
       File exists: EpistemosCore/KnowledgeFusion/Training/scripts/train_style.py
       File exists: EpistemosCore/KnowledgeFusion/Training/QLoRATrainer.swift
       File exists: EpistemosCore/KnowledgeFusion/Training/ExperienceReplayBuffer.swift
       File exists: EpistemosCore/KnowledgeFusion/Training/CurriculumSorter.swift
       
       HYPERPARAMETER AUDIT — Knowledge Profile:
         LORA_RANK == 32                     [ ] PASS / [ ] FAIL
         LORA_ALPHA == 64                    [ ] PASS / [ ] FAIL
         TARGET_MODULES includes gate_proj   [ ] PASS / [ ] FAIL
         TARGET_MODULES includes up_proj     [ ] PASS / [ ] FAIL
         TARGET_MODULES includes down_proj   [ ] PASS / [ ] FAIL
         LEARNING_RATE == 2e-5               [ ] PASS / [ ] FAIL
         REPLAY_RATIO == 0.10                [ ] PASS / [ ] FAIL
       
       HYPERPARAMETER AUDIT — Style Profile:
         LORA_RANK == 8                      [ ] PASS / [ ] FAIL
         LORA_ALPHA == 16                    [ ] PASS / [ ] FAIL
         TARGET_MODULES does NOT include gate_proj  [ ] PASS / [ ] FAIL
         TARGET_MODULES does NOT include up_proj    [ ] PASS / [ ] FAIL
         LEARNING_RATE == 1e-5               [ ] PASS / [ ] FAIL
       
       ADAPTER FUSION CHECK (CRITICAL):
         grep -r "merge_weights=True" EpistemosCore/KnowledgeFusion/Training/
         grep -r "merge_adapter" EpistemosCore/KnowledgeFusion/Training/
         RESULT: Zero matches expected         [ ] PASS / [ ] FAIL

[ ] 4. SUBSYSTEM 4 — KTO PREFERENCE ALIGNMENT
       File exists: EpistemosCore/KnowledgeFusion/Alignment/FeedbackLogger.swift
       File exists: EpistemosCore/KnowledgeFusion/Alignment/KTOTrainer.swift
       File exists: EpistemosCore/KnowledgeFusion/Alignment/TrainingScheduler.swift
       File exists: EpistemosCore/KnowledgeFusion/Alignment/scripts/train_kto.py
       
       DPO CHECK (CRITICAL):
         grep -r "DPO\|dpo\|DirectPreference\|direct_preference" \
           EpistemosCore/KnowledgeFusion/Alignment/
         RESULT: Zero matches expected (KTO ONLY)  [ ] PASS / [ ] FAIL
       
       CODE REVIEW: KTO beta parameter present in training config
       CODE REVIEW: Binary label format used (label: true/false, NOT score 0–1)
       CODE REVIEW: Minimum feedback batch threshold enforced (>= 20 signals)
       CODE REVIEW: TrainingScheduler uses NSBackgroundActivityScheduler

[ ] 5. SUBSYSTEM 5 — ADAPTER MANAGEMENT AND ROUTING
       File exists: EpistemosCore/KnowledgeFusion/Adapters/AdapterRegistry.swift
       File exists: EpistemosCore/KnowledgeFusion/Adapters/AdapterLoader.swift
       File exists: EpistemosCore/KnowledgeFusion/Adapters/AdapterRouter.swift
       File exists: EpistemosCore/KnowledgeFusion/Adapters/AdapterExporter.swift
       
       FUSION CHECK (CRITICAL):
         grep -r "merge_weights\|merge_adapter\|fuse" \
           EpistemosCore/KnowledgeFusion/Adapters/
         RESULT: Zero matches for fusion calls    [ ] PASS / [ ] FAIL
       
       CODE REVIEW: AdapterRecord.type enum has knowledge/style/tool/kto
       CODE REVIEW: AdapterRecord includes quality_score field (nullable)
       CODE REVIEW: Export bundle includes adapter_weights.safetensors + metadata
       CODE REVIEW: MoLoRA Mode C scaffolded with TODO comment (not invented)

═══════════════════════════════════════════════════════════════
AUTORESEARCH LOOP VERIFICATION
═══════════════════════════════════════════════════════════════

[ ] 6. File exists: EpistemosCore/KnowledgeFusion/Autoresearch/AutoresearchLoop.swift
[ ] 7. File exists: EpistemosCore/KnowledgeFusion/Autoresearch/ExperimentTracker.swift
[ ] 8. File exists: EpistemosCore/KnowledgeFusion/Autoresearch/MetricEvaluator.swift
[ ] 9. CODE REVIEW: Loop follows PROPOSE → TRAIN (fixed budget) → EVALUATE →
                    KEEP/DISCARD pattern
[ ] 10. CODE REVIEW: ExperimentTracker writes experiment_log.jsonl (append-only)
[ ] 11. CODE REVIEW: Fixed budget of 200 iterations per experiment
[ ] 12. CODE REVIEW: Loop analyzes autoresearch-master patterns (confirm comment
                     in code references /Users/Downloads/autoresearch-master)

═══════════════════════════════════════════════════════════════
EVALUATION METHODOLOGY VERIFICATION
═══════════════════════════════════════════════════════════════

[ ] 13. Direct Probing present in MetricEvaluator (factual QA)
[ ] 14. Indirect Probing present in MetricEvaluator (multi-hop reasoning)
[ ] 15. Style evaluation uses BERTScore (not just perplexity)
[ ] 16. Tool use evaluation uses binary pass/fail (not fuzzy match)
[ ] 17. Held-out eval set created in QualityCurator (10% split)

═══════════════════════════════════════════════════════════════
END-TO-END TEST VERIFICATION
═══════════════════════════════════════════════════════════════

[ ] 18. swift test --filter EndToEndTest → PASS
[ ] 19. swift test --filter ForgettingTest → PASS
[ ] 20. swift test --filter PrivacyTest → PASS
[ ] 21. swift test --filter PerformanceTest → PASS (< 10% speed degradation)

═══════════════════════════════════════════════════════════════
EMIT FINAL AUDIT REPORT
═══════════════════════════════════════════════════════════════

=== KNOWLEDGE FUSION AUDIT REPORT ===
DATE: [current date]
PASS COUNT: [X/21]
FAIL COUNT: [Y]
WARN COUNT: [Z]

CRITICAL FAILURES (must fix before shipping):
[List any FAIL items from the fusion checks, DPO check, hyperparameter checks]

NON-CRITICAL GAPS (technical debt):
[MoLoRA per-token routing scaffold, any WARN items]

RESEARCH PAPER COMPLIANCE SCORE: [X/21] items verified
=== END AUDIT REPORT ===
```

---

## SECTION 3: RESEARCH RESPONSE TEMPLATE

When Claude Code pauses with a RESEARCH NEEDED block, paste your findings back
using this template:

```
=== RESEARCH RESPONSE ===
TOPIC: [Copy from RESEARCH NEEDED block]
PHASE: [Copy from RESEARCH NEEDED block]

FINDINGS:
[Your research summary — include specific API names, version numbers, links]

ANSWERS TO MINIMUM RESEARCH QUESTIONS:
1. [Answer to question 1]
2. [Answer to question 2]
3. [Answer to question 3 if applicable]

RECOMMENDED IMPLEMENTATION:
[Specific guidance: function call, config value, or code snippet to use]

SOURCES:
- [URL or documentation reference 1]
- [URL or documentation reference 2]

CONSTRAINTS CONFIRMED:
[Any new constraints discovered that Claude Code must respect]

SAFE TO PROCEED: YES / NO (with reason if NO)
=== END RESEARCH RESPONSE ===
```

---

## SECTION 4: QUICK-START CHECKLIST

Step-by-step instructions for starting the implementation session.

### Before Opening Claude Code

- [ ] Confirm the Epistemos Xcode project opens and builds cleanly
- [ ] Confirm mlx-lm is installed: `python3 -c "import mlx_lm; print(mlx_lm.__version__)"`
- [ ] Confirm mlx-tune is installed (or note it's missing — Claude Code will
      handle this with a RESEARCH NEEDED block if required):
      `python3 -c "import mlx_tune; print(mlx_tune.__version__)"`
- [ ] Confirm the autoresearch repo is at the expected path:
      `ls /Users/Downloads/autoresearch-master/program.md`
- [ ] Confirm you have at least one vault folder with 10+ markdown files
      ready to use as a test fixture
- [ ] Have a second terminal open to run Python test commands manually
      if needed

### Opening the Session

1. Open Claude Code in the Epistemos project root
2. Copy the entire content of SECTION 1 (inside the fenced code block)
3. Paste it as your first message
4. Claude Code will begin with Phase 0 (Analysis and Safety Rails)
5. Wait for the Phase 0 STATE REPORT and checkpoint before approving Phase 1

### At Each Phase Boundary

- [ ] Read the PHASE CHECKPOINT block carefully
- [ ] Verify the listed test outputs make sense (ask if results seem too
      clean — Claude Code may have skipped tests)
- [ ] Check that DRIFT CHECK confirms anchors were re-read
- [ ] Reply "proceed" or provide clarification before Phase N+1 begins
- [ ] If you see "RESEARCH NEEDED" — do not tell Claude Code to guess.
      Look up the answer and paste it using the Research Response Template

### If Claude Code Seems to be Drifting

Signs of drift:
- It's using DPO instead of KTO (ANCHOR 1, Subsystem 4)
- It's proposing adapter fusion / merge_weights (ANCHOR 3, GAP 1)
- It's using recursive character splitting instead of markdown-header chunking
- It's training on every interaction instead of scheduling overnight
- It's targeting MLP layers for style training (ANCHOR 2)

Action: Paste the ANTI-DRIFT REFERENCE CARD from Section 5 into the chat
and say: "You appear to have drifted from the research paper. Re-read the
anchors and correct your implementation."

### Recovery Protocol If a Phase Goes Wrong

If Claude Code produces a failing test and can't fix it after 2 attempts:
1. Ask it to emit a RESEARCH NEEDED block for the specific issue
2. Do NOT allow it to skip the test or mark it as "known limitation"
3. Look up the answer and paste the Research Response Template
4. If the issue is environment-specific (mlx-tune version, etc.): note it
   in docs/knowledge-fusion/KNOWN-ISSUES.md and unblock with a stub

---

## SECTION 5: ANTI-DRIFT REFERENCE CARD

Paste this into Claude Code at any point if drift is suspected.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║              EPISTEMOS KNOWLEDGE FUSION — ANTI-DRIFT REFERENCE              ║
║              Source: On-Device-LLM-Knowledge-Fusion-Research.md             ║
╚══════════════════════════════════════════════════════════════════════════════╝

ANCHOR 1 — THE FIVE SUBSYSTEMS (all five are mandatory, no merging)
─────────────────────────────────────────────────────────────────────────────
1. Data Ingestion: Markdown-header chunking; Whisper audio transcription;
   capture paralinguistic cues for stylometric DNA
2. Synthetic Data Generation: Self-Instruct backtranslation; 3-step loop
   (query gen → response rewriting → quality scoring 1–5, discard < 3);
   separate knowledge/style/tool JSONL files
3. QLoRA Fine-Tuning: Frozen 4-bit base + 16-bit LoRA updates; Experience
   Replay (10% general data mix, MSSR algorithm); Curriculum Learning
   (simple → complex); SAM optimizer; L2 regularization
4. KTO Preference Alignment: Binary unpaired feedback ONLY; KTO NOT DPO;
   batch overnight, NOT after every interaction
5. Dynamic Routing: Hot-swap ONLY; NEVER fuse into base weights permanently

ANCHOR 2 — HYPERPARAMETERS (do not change without research justification)
─────────────────────────────────────────────────────────────────────────────
Knowledge Profile:
  rank=32, alpha=64
  targets: q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj
  lr=2e-5

Style Profile:
  rank=8, alpha=16
  targets: q_proj, k_proj, v_proj, o_proj (ONLY — NO MLP layers)
  lr=1e-5

ANCHOR 3 — CRITICAL GAPS (known failure modes, never ignore)
─────────────────────────────────────────────────────────────────────────────
GAP 1: Adapter fusion → 3x speed degradation (21→7 tok/s). NEVER merge.
GAP 2: Tool training → forgetting prior tools. Always add negative examples.
GAP 3: GGUF export broken from 4-bit base. Use MLX .safetensors only.
GAP 4: Adapter .safetensors = PII risk. Implement DP-LoRA (gradient clip +
        Gaussian noise).
GAP 5: Personal vault training degrades safety. Use PTST: train without
        safety prompts; apply safety system prompt at inference time.

ANCHOR 4 — CATASTROPHIC FORGETTING MITIGATIONS (all four are mandatory)
─────────────────────────────────────────────────────────────────────────────
1. Experience Replay: 500-example general-purpose buffer; 10% mix per run
2. Curriculum Learning: sort by complexity (definitions first, reasoning last)
3. Sharpness-Aware Minimization (SAM): flat minima → more resilient weights
4. L2 Regularization: weight_decay on adapter weights; concentrate learning

ANCHOR 5 — EVALUATION CRITERIA (loss curves alone do NOT prove fusion)
─────────────────────────────────────────────────────────────────────────────
Knowledge: Direct Probing (explicit vault questions) + Indirect Probing
           (multi-hop reasoning combining vault + world knowledge)
           If passes Direct but fails Indirect → mere memorization, not fusion
Style:     BERTScore + dependency bigram distribution + function word frequency
           Quality bar: must bypass automated stylometric classifiers
Tool use:  Binary pass/fail on correct tool + parameters; regression test on
           ALL existing tools (not just new ones)
Speed:     With adapter loaded < 10% degradation vs. base model
           If > 10% degradation → fusion bug detected; find and remove merge call

══════════════════════════════════════════════════════════════════════════════
If any of the above constraints are violated in the current implementation,
emit: "DRIFT DETECTED — [specific violation] — halting and correcting"
Then fix the violation before continuing.
══════════════════════════════════════════════════════════════════════════════
```

---

*Document generated: 2026-03-23. Primary source: On-Device-LLM-Knowledge-Fusion-Research.md. App architecture source: Epistemos_-Audit-Research-Design.md. Autoresearch loop source: /Users/Downloads/autoresearch-master.*
