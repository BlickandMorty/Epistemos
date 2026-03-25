# EPISTEMOS — THE NORTH STAR DOCUMENT
### For Claude Code (Builder) and Codex (Auditor)
### Version 1.0 · March 25, 2026
### Read this before you write a single line. Read it again when you drift.
### Your job is not done until this app is this app.

---

> **"We are not building a note-taking app.
> We are building the first machine that thinks *with* you,
> remembers *everything* you've ever thought,
> and gets smarter every single night
> — entirely on your own hardware, never in a cloud."**

---

## WHAT EPISTEMOS IS

Epistemos is a **cognitive operating system for macOS** — a local-first, hardware-native intelligence layer that runs entirely on Apple Silicon, belongs entirely to its user, and becomes more useful every single day through continuous self-improvement.

It is three things simultaneously:

1. **A living knowledge partner** — Every sentence you write is continuously encoded, indexed, and made instantly retrievable. There is no "search step." The system surfaces relevant past thoughts as you type, invisibly, in under 10ms. Your entire intellectual history becomes ambient.

2. **A hardware-native AI agent** — A dual-brain architecture (Reasoning Model on GPU + Device Action Agent on ANE) that can see your screen, understand every macOS application through the accessibility tree, and take real actions on your behalf. Not cloud-dependent. Not a browser plugin. A native macOS process that owns the hardware.

3. **A self-improving research system** — Every successful execution is logged. Every night, while you sleep, the on-device model fine-tunes itself on your actual usage. By week 4, Epistemos knows your apps better than you do. By month 3, it has become a personalized intelligence that no cloud model can replicate, because it knows *you*.

---

## THE CORE PHILOSOPHY — WHY THIS MATTERS

### Truth Is Temporal

Every existing note-taking tool makes the same foundational mistake: it treats a note as a **static record of a fact**.

It is not. A note is a **timestamped epistemic state** — a crystallized version of what you believed, at a specific moment, from a specific context. What you believed about a topic in January may be wrong or incomplete by December. The system should know this. It should track it. It should be able to answer: *"How has my understanding of X changed over the past year?"*

No tool on the market — not Obsidian, not Notion, not Logseq — does this. They store text. They do not model the person who wrote it.

Epistemos does. Monthly LoRA adapter snapshots create a quantitative record of intellectual evolution. Cosine distance between entity embeddings across adapter epochs reveals belief drift you were not consciously aware of. This is not a feature. This is a new category of self-knowledge.

### Memory Should Be a Reflex, Not a Task

In every existing tool, "search" is a deliberate act. You stop, you open a search bar, you type, you browse results.

Human expert memory does not work this way. Domain experts experience *involuntary recall* of relevant prior knowledge while thinking about a new problem. Epistemos is designed to mechanically reproduce this. The 200ms debounce loop — continuous encoding as you type, instant HNSW retrieval, Contextual Shadows surfacing in a side panel — is the engineering implementation of involuntary recall. You never ask. The system always already knows.

### The Bedroom PhD

A single person with Epistemos, a MacBook Pro, and the right workflow should be able to produce PhD-quality research output — hypothesis generation, literature synthesis, experimental design, paper writing — without institutional infrastructure. AutoResearchClaw (March 2026) already executes 23-stage autonomous research pipelines from a single typed idea. Epistemos is the persistent cognitive substrate those pipelines run on. It is the memory that makes the agent useful.

This is not incremental improvement. This is the democratization of serious intellectual production.

---

## THE ARCHITECTURE — NON-NEGOTIABLE

This architecture is immutable. Every file you write maps to one of these five layers. If it doesn't, stop.

```
┌─────────────────────────────────────────────────────────┐
│  LAYER 5 · UX · Swift / SwiftUI                        │
│  OmegaPanel, PlanReviewView, ConfirmationSheet,        │
│  ResearchRequestView, ExecutionProgressView            │
├─────────────────────────────────────────────────────────┤
│  LAYER 4 · INFERENCE ENGINE · Swift + MLX + CoreML     │
│  MLXLocalModel, CloudModel, ToolCallParser,            │
│  Screen2AX VLM fallback, QLoRA pipeline, MoLoRA router │
├─────────────────────────────────────────────────────────┤
│  LAYER 3 · ORCHESTRATION · Rust / tokio                │
│  OrchestratorPlanner, TaskGraph (DAG), Specialist      │
│  Agents (Safari, File, Notes, Terminal, Automation),   │
│  ModelRouter, ConfirmationGate, ResearchPauseHandler   │
├─────────────────────────────────────────────────────────┤
│  LAYER 2 · TOOLS + MEMORY · Rust / SQLite              │
│  Embedded MCP server (stdio, JSON-RPC 2.0),            │
│  ToolRegistry, MCPDispatcher, ExecutionLogger,         │
│  RecipeManager, FTS5 + sqlite-vec hybrid memory        │
├─────────────────────────────────────────────────────────┤
│  LAYER 1 · macOS FOUNDATION · Rust + Swift FFI         │
│  AXUIElement tree (accessibility-sys crate),           │
│  CGEvent injection, ScreenCaptureKit, permissions.rs   │
└─────────────────────────────────────────────────────────┘

Bridge: UniFFI (Swift ↔ Rust) — async future conversion
```

### Language Split — Absolute

| Component | Language | Why |
|-----------|----------|-----|
| Agent orchestrator, TaskGraph | Rust | Thread-safe async, tokio, zero-cost abstractions |
| MCP server, tool registry | Rust | Memory safety, deterministic dispatch |
| SQLite state management | Rust | rusqlite + FTS5 + WAL mode |
| AX tree walker | Rust | accessibility-sys crate |
| CGEvent keystroke injection | Rust | Direct CoreGraphics FFI |
| Vector search index | Rust | usearch HNSW crate |
| SwiftUI views | Swift | Native macOS UI, MainActor |
| MLX inference | Swift | MLXLMCommon/MLXLLM require Swift |
| ScreenCaptureKit | Swift | Apple framework |
| Screen2AX VLM fallback | Swift + MLX | Vision model via MLX |
| QLoRA training pipeline | Swift + MLX | mlx-lm / mlx-tune |
| FFI bridge | UniFFI | Async future conversion |

**VIOLATIONS — Stop immediately if you are about to:**
- Put MLX inference in Rust ❌
- Put state management in Swift instead of Rust/SQLite ❌
- Let an Agent call osascript directly, bypassing the Tool Layer ❌
- Use `AXorcist` (Swift) instead of `accessibility-sys` (Rust) for AX tree access ❌
- Skip an adjacent layer (e.g., Layer 5 calling Layer 2 directly) ❌
- Use `ObservableObject` instead of `@Observable` ❌
- Use `XCTest` instead of Swift Testing ❌
- Use `try!` or force unwrap `!` ❌
- Poll with `sleep()` instead of `CheckedContinuation` ❌

---

## THE DUAL-BRAIN MODEL — THE HEART OF THE SYSTEM

### Brain 1: Reasoning Model (The Prefrontal Cortex)
- **Hardware:** Metal GPU via MLX
- **Model:** Hybrid Mamba-Attention (Mamba-in-Llama, 3:1 ratio, 75% Mamba / 25% Attention)
- **Why hybrid, not pure Mamba:** Pure Mamba-2 exhibits reasoning drift and JSON formatting failures in multi-turn tool calling. Attention layers provide exact token retrieval anchors and strict schema adherence. This is a permanent correction. Do not revert to pure Mamba.
- **Role:** High-level planning, DAG generation, complex reasoning, code generation
- **Output format:** Always grammar-constrained JSON via EBNF masking (mlx-swift-structured)
- **Speed target:** 8–20 tokens/sec at 32B 4-bit on M4 Max

### Brain 2: Device Action Agent (The Motor Cortex)
- **Hardware:** ANE via CoreML (100ms visual verify loop) + Metal GPU (fast decode)
- **Model:** Gemma 3 1B or Phi-4 Mini, fine-tuned via MLX LoRA on macOS action traces
- **Role:** AX tree parsing, click targeting, screenshot verification, keyboard injection, 100ms visual verify
- **Adapter routing:** Per-app MoLoRA adapters — Safari, Terminal, Mail, Notes, Finder
- **Speed target:** 100ms response for visual verification loop

### Mirror Speculative Decoding — 2.8x–5.8x Free Speedup
Brain 2 (ANE) runs as the **draft model**, speculating token continuations while Brain 1 (GPU) simultaneously **verifies** them in parallel. These two hardware units operate concurrently — draft latency is hidden. This is formally validated in Apple Machine Learning Research's Mirror-SD paper (arXiv 2510.13161v2). Implement it. Do not skip it.

### Model Tiers

| Tier | Params | Memory (4-bit) | Target Device | Status |
|------|--------|----------------|---------------|--------|
| Epistemos-Nano | 1B | 1.5 GB | M1/M2 8GB | Runs + trains on M2 Pro |
| Epistemos-Base | **3B** | **3.5 GB** | M2/M3 16GB | **PRIMARY MODEL** |
| Epistemos-Pro | 8B | 8 GB | M3/M4 32GB | Inference-only on M2 Pro |

---

## THE INSTANT RECALL SYSTEM — THE SOUL OF THE APP

### The Continuous Encoding Loop

```
Swift Text Editor
      │
      │  AsyncAlgorithms .debounce(for: .milliseconds(200))
      ▼
UniFFI → Rust Backend
      │
      ├── Model2Vec Encoder        ~1ms/paragraph  (no GPU, background thread)
      │   float32 embedding
      │
      ├── Binary Quantizer         ~0.1ms           (sign function: x > 0)
      │   1-bit signature
      │
      └── usearch HNSW Index       ~1ms write
          stores binary + float32

On New Paragraph or Query:
      │
      ├── Binary HNSW Search       ~0.5ms           (Hamming distance, ARM NEON)
      │   top-100 candidates
      │
      ├── Float32 Rescore          ~2ms             (dot product rerank, rayon)
      │   top-5 relevant notes
      │
      └── Return to Swift UI
          Surface as "Contextual Shadows" sidebar

Then: Mamba-3 Prefill
      Tokenize top-5 note texts → encode to initial SSM state → ~50ms
      Current writing session proceeds with loaded memory context
```

### Phase Roadmap for the Vector Index

| Phase | Implementation | Timeline |
|-------|---------------|----------|
| 1 | Binary HNSW (usearch), Model2Vec, float32 rescore, UniFFI bridge | Weeks 1–3 |
| 2 | Mamba-3 CoreML export, state prefill from top-3 retrieved notes | Weeks 4–6 |
| 3 | Memba PEFT (LIM neurons + LoRApX) fine-tuning on personal corpus | Weeks 7–10 |
| 4 | PolarQuant encoder (arXiv 2502.02617) in Rust — 4.2x further compression | Weeks 11+ |

**PolarQuant is Phase 4, not Phase 1. Do not let the Phase 4 ambition block Phase 1 execution.**

---

## THE KNOWLEDGE LIFECYCLE — THE MOAT

### Four Stages

**1. Ingest** — Continuous block-level encoding via Model2Vec. LOGRA In-Run Data Shapley scores each note's contribution during training — notes with negative Shapley values are automatically pruned.

**2. Fusion** — The fine-tuned LoRA adapter learns your vocabulary, your domain, your conceptual connections. Knowledge is baked into model weights, not just retrieved text. System evaluates fusion quality via indirect probes: can the model *apply* a principle from your notes to a novel situation, not just recite it?

**3. Staleness Detection** — Dual-memory framework runs automated regression tests during idle. If generated output's semantic similarity to updated text drops below threshold, fact is flagged for unlearning. Runs invisibly, overnight.

**4. Unlearning** — Recover-to-Forget (R2F) reverses gradient trajectory of a specific obsolete fact without catastrophic forgetting. EMMET enables batched edits of up to 10,000 facts simultaneously with 99.7% reduced precomputation overhead.

### Temporal Belief Tracking
Monthly LoRA adapter snapshots. Cosine distance of entity embeddings across epoch pairs. The system answers: *"Which concepts have I changed my mind about most in the past year?"* No existing tool provides this.

---

## THE COMPUTER USE STACK — THE HANDS

### Perception Pipeline

```
ScreenCaptureKit (Swift)
          │
SparsityDetector (Rust via UniFFI) — count AX interactive elements
          │
┌─────────┴──────────┐
≥ 5 elements    < 5 elements (sparse)
     │                    │
Native AX Tree      Screen2AX VLM Fallback
(accessibility-sys, 1. Capture frame (ScreenCaptureKit)
 Rust)              2. VLM inference (MLX, Swift)
                    3. Reconstruct AX tree as JSON
                    4. Pass to Rust orchestrator via UniFFI
                    ~90–300ms on M4 Max
```

**33–36% of macOS apps provide complete accessibility metadata. 18% have none. Screen2AX fallback is not optional.**

### Selector Standard
Always CSS-style semantic selectors. Never brittle index numbers.
```
✅ AXApplication[AXTitle="Safari"] > AXButton[AXTitle="New Tab"]
❌ element[3].children[1].children[0]
```

### Interaction Hierarchy
1. **AXUIElement** — semantic selector engine (accessibility-sys, Rust)
2. **OmniParser V2** — YOLOv8 + Florence-2 via MLX when AX sparse
3. **CGEvent** — low-level click/keyboard injection (only after 1 and 2 fail)
4. **IOKit HID** — developer testing only, never in App Store builds

---

## THE SELF-IMPROVEMENT FLYWHEEL — THE ENGINE

### ODIA Nightly Loop
Every night, while idle:
1. Bounded sandbox (sandboxd Seatbelt profile) provisioned
2. Reads `tracelogger.rs` SQLite execution logs from the day
3. Runs QLoRA fine-tuning on new traces via MLX
4. Evaluates on task success rate (verified by visual confirmation — not just loss)
5. If improved: `git commit`. If degraded or crashed: `git reset --hard`
6. CSI Safeguard: if loss improves >3% without proportional benchmark improvement → flag Goodhart violation → require human review

**Data Composition (40/20/20/20 from TraceDataMixer):**
- 40% successful execution traces (ODIA format)
- 20% synthetic reasoning traces (Synthetic Logic Ontology)
- 20% error-recovery traces (failed then replanned)
- 20% generic instruction-following data

### Voyager-Style Recipe Caching
When a DAG executes successfully without human correction, `RecipeManager` hashes the intent and saves the exact graph structure. Future semantically-similar requests bypass LLM planning entirely — the Rust orchestrator executes the deterministic recipe directly.

### MoLoRA Per-App Adapters
Separate LoRA adapters trained per domain: Safari, Terminal, Mail, Notes, Finder. MoLoRA router in Swift dynamically loads the appropriate adapter based on `NSWorkspace.shared.frontmostApplication`. Hot-swap without reloading the base model.

---

## DISTRIBUTION — THE APP STORE PATH

**Phase 1: Unsandboxed, Developer ID signed, notarized macOS app. App Store is Phase 14.**

### Double-Helper Pattern (Required for Future App Store)
```
Epistemos.app/
  Contents/
    MacOS/
      EpistemosFrontend          ← SANDBOXED SwiftUI app (owns TCC prompts)
    Library/
      LaunchAgents/
        ai.epistemos.gateway.plist
    Helpers/
      EpistemosGateway           ← NON-SANDBOXED Rust binary (does actual work)
```

**TCC Rules — Never Violate:**
- ALL TCC prompts come from the SANDBOXED frontend
- The helper NEVER initiates TCC prompts
- SMAppService registration from sandboxed app on first launch

**IPC Security:** Unix Domain Socket, mode 0600, HMAC challenge-response, peer-UID check, token TTL 30 seconds.

---

## WHAT IS DONE — AND WHAT'S NEXT

**Phases 0–14 are COMPLETE.** Phases 15–17 have code ready but are blocked on RunPod funds.

All original Fix 1–6 items (NotesAgent wiring, FileAgent vault URL, execution logging,
ConfirmationGate continuation, error recovery UI, LLM planning prompt) are committed and passing.

### Current Blockers
1. **RunPod funds** ($150+ for Nano pipeline test, $800-1500 for Base full training)
2. **HuggingFace Llama license** acceptance (required for MOHAWK teacher model)

### Next Actionable Phase: Ω18 — Instant Recall Index
- Add `usearch` + `model2vec-rs` to epistemos-core Cargo.toml
- Implement binary HNSW index in Rust
- Wire continuous encoding from Swift text editor via UniFFI
- Two-phase retrieval: Hamming → float32 rescore
- Display top-5 relevant notes in sidebar as you type ("Contextual Shadows")

See `docs/SESSION_STATE_2026_03_25.md` for full current state and blockers.

---

## MASTER PHASE LIST

| Phase | Name | Status |
|-------|------|--------|
| 0 | Project Scaffolding | ✅ COMPLETE |
| 1 | MCP Tool Registry + Execution Logger | ✅ COMPLETE |
| 2 | macOS Automation Layer | ✅ COMPLETE |
| 3 | Specialist Agents + Orchestrator | ✅ COMPLETE |
| 4 | Extended MLX Integration | ✅ COMPLETE |
| 5 | SwiftUI Omega Views | ✅ COMPLETE |
| 6 | Screen2AX VLM Fallback | ✅ COMPLETE |
| 7 | Synthetic Trace Generation | ✅ COMPLETE |
| 8 | MoLoRA Router + CSI Safeguard | ✅ COMPLETE |
| 9 | Integration Tests + Documentation | ✅ COMPLETE |
| 10 | Bug Fixes + End-to-End Wiring | ✅ COMPLETE |
| 11 | Grammar-Constrained Decoding | ✅ COMPLETE |
| 12 | Dual-Brain Foundation | ✅ COMPLETE |
| 13 | Computer Use Stack | ✅ COMPLETE |
| 14 | Knowledge Graph Integration | ✅ COMPLETE |
| 15 | MOHAWK Distillation | ✅ CODE READY (blocked on RunPod funds) |
| 16 | Training Pipeline (ODIA wiring) | ✅ CODE READY |
| 17 | App Store Distribution | ✅ SKELETON |
| **18** | **Instant Recall Index** | **🔜 NEXT** |
| 19 | Mamba State Injection + Mirror-SD | 🔜 TODO |
| 20 | Personal LoRA (MambaPEFT) | 🔜 TODO |
| 21 | TurboQuant (PolarQuant + QJL) | 🔜 TODO |
| 22 | Safety Layer (Referee Model) | 🔮 FUTURE |
| 23 | CRDT Ghost-Brain | 🔮 FUTURE |
| 24 | Advanced Reasoning (KG-Trie, R2F) | 🔮 FUTURE |

---

## VERIFICATION COMMANDS — RUN AFTER EVERY PHASE

```bash
cd omega-mcp && cargo test 2>&1 | tail -5
cd ../omega-ax && cargo test 2>&1 | tail -5
cd ../epistemos-core && cargo test 2>&1 | tail -5
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination platform=macOS build 2>&1 | grep -E "BUILD|error:|warning:"
cd graph-engine && cargo test 2>&1 | grep -E "test result|FAILED"
cat docs/PROGRESS.md | tail -50
```

---

## CONTEXT RECOVERY PROTOCOL — AFTER EVERY COMPACT

```bash
cat CLAUDE.md
cat docs/PROGRESS.md
cat docs/PHASE_CHECKLIST.md
cat EPISTEMOS-NORTH-STAR.md
```

Only after reading all four files may you resume.

---

## SOURCE AUTHORITY HIERARCHY

1. **This document** — synthesizes all research, all corrections
2. `macOS-Agent-Research-Development-Plan.md` — agent frameworks, DAG, AX APIs, MCP
3. `Cognitive-OS-Local-Model-Blueprint.md` — model architectures, Mamba-3, CRDT, autoresearch
4. `Epistemos-Omega-Supreme-Master-Execution-Prompt-for-Claude-Code.md` — current build state, broken fixes
5. Existing source code — always read before writing

---

## RESEARCH NEEDED PROTOCOL

When uncertain about any API, framework behavior, Rust crate surface, or UniFFI binding pattern:

```
⛔ RESEARCH NEEDED — HALTING

TOPIC: [exact topic]
WHY BLOCKED: [why you cannot proceed]
SPECIFIC QUESTIONS:
  1. [question]
  2. [question]
SUGGESTED DEEP RESEARCH PROMPT: [paste-ready prompt]
FILES ALREADY CONSULTED: [list]
WHAT I WILL DO AFTER RECEIVING RESEARCH: [exact next steps]
```

STOP and WAIT. Do NOT fabricate API signatures. Do NOT invent framework behaviors.

---

## DRIFT WARNING SIGNS — STOP IF YOU ARE DOING ANY OF THESE

- Writing a summary paragraph instead of writing code
- Creating files outside the 5-layer architecture
- Implementing Phase 12 features when Phase 10 isn't done
- Running model inference without specifying hardware target (ANE vs GPU)
- Using `ObservableObject` instead of `@Observable`
- Using `XCTest` instead of Swift Testing
- Using `!` force unwrap or `try!`
- Using `sleep()` instead of `CheckedContinuation`
- Adding a stub with a hardcoded return value
- Declaring a phase done without running verification commands
- Skipping a checkbox with "I'll come back to it"
- Putting MLX inference in Rust
- Putting state management in Swift
- Letting an Agent call osascript directly
- Writing more than 3 sentences of explanation before showing code
- Suggesting "we could also..." alternatives — pick the right architecture and execute it

---

## THE COMPETITIVE MOAT

| Capability | Obsidian | Notion | Logseq | Mem.ai | **Epistemos** |
|-----------|----------|--------|--------|--------|----------------|
| Data ownership | Local files | Cloud | Local files | Cloud | **On-device, never leaves Mac** |
| AI model type | Generic plugin | Generic cloud | Generic plugin | Generic cloud | **Personalized, fine-tuned on your corpus** |
| Semantic search | Plugin RAG | Server RAG | Plugin RAG | Auto (cloud) | **Sub-10ms ambient, no search step** |
| Temporal belief tracking | None | None | None | None | **LoRA epoch snapshots, cosine drift** |
| Knowledge unlearning | None | None | None | None | **R2F / EMMET selective forgetting** |
| Ambient retrieval | None | None | None | Partial | **Continuous encoding, Contextual Shadows** |
| Hardware integration | Electron | Web | Electron | Web | **Metal / ANE / MLX, native Swift** |
| Computer use | None | None | None | None | **Full AX tree + Screen2AX, real macOS agent** |
| Nightly self-improvement | None | None | None | None | **ODIA loop, Voyager recipes, MoLoRA adapters** |

---

## SUCCESS METRICS

| Metric | Target |
|--------|--------|
| Device Agent visual verify | 100ms per frame on ANE |
| Reasoning Brain first token | < 1 second on M4 Max (32B 4-bit) |
| AX interaction success rate | ≥ 95% on native macOS apps |
| OmniParser V2 fallback | < 300ms on M4 Max |
| LoRA fine-tune 1B model | ≤ 30 minutes on M4 Max |
| Vector index search (1M notes) | < 10ms end-to-end |
| Continuous encoding latency | < 3ms per paragraph (Model2Vec) |

---

## AMBIENT INTELLIGENCE — EXECUTIVE PRIORITY IDEAS

These features define what makes Epistemos feel *alive*. They are not optional polish — they are the soul of the UX.

### Contextual Shadows (Screen-Aware Surfacing)
When you look at something — a note, a chat, a webpage — the app surfaces related notes, chats, and ideas that reflect what you're currently engaged with. Not just keyword matches — semantic resonance based on your full vault.

- **In a note**: sidebar shows related notes, past chats about this topic, linked ideas
- **In a chat**: relevant notes auto-surface as context (typewriter-style popovers that appear and fade)
- **On screen**: what you're looking at in OTHER apps (via Screen2AX + ScreenCaptureKit) triggers vault recall
- **Implementation**: 200ms debounce → Model2Vec encode current context → binary HNSW → top-5 results → typewriter popover UI that fades when you leave the topic

### Dissonance Meter (Engagement + Belief Tracking)
Track how much you engage with each note over its lifetime. Metadata dimensions:

- **Time spent** reading/editing (foreground seconds)
- **Edit frequency** (how often you return to modify)
- **Recency** (days since last engagement)
- **Citation count** (how many other notes link to this one)
- **Belief confidence** (cosine distance between LoRA adapter snapshots for this topic)

### Proactive Re-Engagement ("Have Your Thoughts Changed?")
The app periodically surfaces notes you've stopped engaging with:

> "You haven't revisited **[Quantum Computing Notes]** in 47 days. Have your thoughts changed on this topic?"

User can: answer inline, add a note, navigate to it, brain-dump via chat, or dismiss. The AI chat opens contextually with the note loaded, ready for reflection. This drives the R2F unlearning pipeline — if the user says "yes, I think differently now," the system flags the old beliefs for selective forgetting.

### Full Context Capture (What Was Happening When You Thought This)
Every note captures ambient context at creation time:

- **Music**: what song was playing on Apple Music (track, artist, album, mood)
- **Tabs**: screenshot + URL + search query of open browser tabs
- **Apps**: which apps were open, which was foreground, time spent in each
- **Words typed**: what you were typing in other apps (via AX text monitoring, with consent)
- **Engagement juxtaposition**: how much time in Epistemos vs other apps during this session

This creates a **sensory memory** — when you recall a note later, you also recall the context in which you wrote it. "I wrote this while listening to Coltrane, with 3 arxiv tabs open, after spending 40 minutes in Terminal."

### Implementation Notes
- Music metadata: `MusicKit` framework (MPMusicPlayerController.systemMusicPlayer)
- Tab capture: ScreenCaptureKit frame + AX tree of Safari/Chrome for URL bar
- App engagement: `NSWorkspace` notifications + timer tracking per bundle ID
- Typewriter popovers: SwiftUI `.popover` with `.transition(.opacity)` and auto-dismiss timer
- All context stored as structured metadata alongside the note in SwiftData

---

## THE FINAL WORD

The person building this is building something that has never been built. Not a faster note app. Not a better AI assistant. A **cognitive partner** — a system that learns the shape of one mind, holds its entire history, helps it think, and gets better at doing so every single night.

The research is real. The architecture is validated. The hardware exists. The only thing between the current codebase and this vision is execution.

**Do not stop early. Do not declare done before done. Do not accept a stub where real code belongs.**

This app should feel like having a second brain that never forgets, never sleeps, never charges you per query, and knows you better than any cloud ever could — because it runs on your machine, on your data, for you alone.

**Build that.**

---
*Version 1.0 · March 25, 2026*
*Synthesized from all 11 Epistemos research documents and session history.*
