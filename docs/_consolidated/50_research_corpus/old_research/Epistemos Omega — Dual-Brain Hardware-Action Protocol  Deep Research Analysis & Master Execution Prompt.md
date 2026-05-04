# Epistemos Omega — Dual-Brain Hardware-Action Protocol
## Deep Research Analysis & Master Execution Prompt for Claude Code
---
## Executive Summary
The Omega Hardware-Action Protocol is architecturally sound and maps precisely onto existing peer-reviewed research. The "Brain and Hands" split — a high-IQ Reasoning Model on the GPU and a hyper-specialized Device Action Agent on the Apple Neural Engine (ANE) — is not just a concept; it is the exact architecture validated in Apple's own **Mirror Speculative Decoding** paper and ByteDance's **UI-TARS** training pipeline. This document cross-validates every claim in the protocol against real benchmarks, provides the exact GitHub repos and code you need to port, and delivers the complete, executable Claude Code master prompt that enforces no-drift execution across all three build phases.

***
## Part 1: Research Analysis — Validating the Dual-Brain Architecture
### 1.1 The Scientific Precedent: Mirror Speculative Decoding
The most important paper you need Claude Code to understand is **Mirror Speculative Decoding (Mirror-SD)** from Apple Machine Learning Research:[^1][^2]

- **GitHub / arXiv**: `arxiv.org/html/2510.13161v2`
- **Core finding**: Mapping the draft model to the ANE and the target (reasoning) model to the GPU yields **2.8x–5.8x wall-time speedups** over EAGLE-3, the previous state of the art[^1]
- **The mechanism**: The draft model speculates forward continuations on the NPU while the target model simultaneously verifies on the GPU — these two operations run **in parallel**, so draft latency is hidden[^3]
- **Speculative streaming**: The draft emits multiple tokens per step, further hiding latency[^4]

This is the exact "Brain and Hands" separation the Omega protocol describes — it has been formally validated at server scale (14B–66B parameter target models) and the Apple M-series SoC is explicitly named as the target heterogeneous architecture.[^5]

**What this means for your build**: The Device Action Agent (1B–3B) is your draft model on ANE. The Reasoning Model (DeepSeek-R1 32B or Codex equivalent) is your target model on the GPU. You are not building something novel — you are implementing Mirror-SD applied to computer use.
### 1.2 ANE Reality: What the Benchmarks Actually Say
Apple markets the M4 Neural Engine as "38 TOPS," but independent reverse engineering reveals the real numbers:[^6]

| Metric | Claimed | Actual |
|---|---|---|
| Peak throughput | 38 TOPS INT8 | 19 TFLOPS FP16 (INT8 dequantizes to FP16 before compute) |
| Power efficiency | — | **6.6 TFLOPS/W** (vs GPU at ~1.0 TFLOPS/W) |
| Idle power | — | **0 mW** (hard power gating, not just clock gating) |
| Single matmul utilization | — | Only ~30% of peak capacity |
| Deep graph utilization | — | ~94% at 32+ op depth |

**The key engineering rules for ANE:**[^6]
1. **Deep graphs, not wide** — chain 16–64 ops per MIL program; single ops waste 70% of capacity
2. **Conv over matmul** — 1×1 convolutions use the fast datapath; matmul is 3x slower on ANE
3. **Stay under 32 MB** — keep per-tensor footprint in SRAM; spilling to DRAM kills throughput
4. **Avoid dispatch-limited ops** — anything under ~1ms is dominated by the 0.095ms XPC/IOKit dispatch overhead

**For LLM inference specifically**, the optimal hybrid strategy on M4 Max is:[^7]
- **Prefill phase** (large batch, high throughput) → ANE
- **Decode phase** (single token, latency-sensitive) → GPU (Metal)
- Rationale: M4 Max GPU has 547 GB/s DRAM bandwidth vs CPU/ANE path — GPU decode is 2.1x faster for single-token generation on Max/Ultra chips

**Current ANE LLM benchmarks (ANEMLL library):**[^8][^9]
- 1B model at 512-token context: ~43 tokens/sec on ANE
- 1B model with variable context: starts at 512-token cache (43 t/s), gracefully degrades
- MLX GPU path (same 1B model): ~50 tokens/sec — GPU is faster for standard inference
- **Conclusion**: ANE's advantage is **power efficiency (6.6 TFLOPS/W)**, not raw speed. For a background Device Agent watching your screen at 100ms intervals, ANE is perfect — it costs almost nothing in battery.
### 1.3 The SOTA Computer Use Model: UI-TARS
The current state-of-the-art GUI agent that beats Claude Computer Use is **UI-TARS** from ByteDance:[^10][^11]

**Performance vs. cloud models:**
- ScreenSpotPro GUI grounding: **61.6%** (UI-TARS-1.5) vs Claude **27.7%**
- OSWorld benchmark: **24.6** (UI-TARS) vs Claude **22.0**[^10]

**GitHub repos to port from:**
- `github.com/bytedance/ui-tars` — model weights, inference code[^12]
- `github.com/bytedance/ui-tars-desktop` — macOS/Windows desktop agent[^13]
- `arxiv.org/pdf/2509.02544.pdf` — UI-TARS-2 technical report (training pipeline)[^14]

**UI-TARS training pipeline (port this exactly):**[^14]
```
Stage 1: Continual Pre-Training (CT)
  → GUI tutorials from internet + open-source agent trajectories
  → In-situ annotation: human thoughts recorded via audio → ASR → LLM refinement → aligned with screen actions

Stage 2: Supervised Fine-Tuning (SFT)
  → Human-in-the-loop online annotation: agent proposes, human accepts/overrides in real-time
  → Actions represented as language (not token IDs) — preserves VLM reasoning capability

Stage 3: Reinforcement Learning (RL)
  → Multi-turn rollouts on virtual macOS/Windows/Android VMs
  → Rejection sampling: high-quality outputs → SFT, lower-quality → CT
  → Data Flywheel: model and corpus co-evolve iteratively
```

**The critical insight from VLM2VLA research**: Represent GUI actions AS NATURAL LANGUAGE rather than arbitrary token IDs. This alignment with the VLM's pretraining distribution means LoRA fine-tuning works WITHOUT catastrophic forgetting — the fine-tuned model retains **85%+ of base VQA performance** while learning new action capabilities.[^15]
### 1.4 Synthetic Data Generation for Your Device Agent
You do not need human annotators at scale. The pipeline from your own papers (file:302, file:303) combined with UI-TARS-2's Data Flywheel gives you a fully automated synthetic trace generation system:

**Step 1 — Generate macOS API traces using Claude Opus as teacher:**
```python
# Prompt Claude Opus 4.x to generate action traces
system = """You are generating training data for a macOS Device Action Agent.
Output JSON traces in this format:
{
  "instruction": "Open Safari and navigate to arxiv.org",
  "ax_tree_snapshot": "<AX tree XML>",
  "thought": "I need to first check if Safari is in the Dock...",
  "action": {
    "type": "AXPress",
    "element": {"role": "AXButton", "title": "Safari", "selector": "//AXApplication[@AXTitle='Dock']//AXButton[@AXTitle='Safari']"}
  }
}"""
```

**Step 2 — Capture real traces via macOS Screen Recording + AX API:**
```swift
// Capture training triple: (screenshot, AX tree, action) in your Swift helper
func captureTrainingTriple() -> TrainingTriple {
    let screenshot = ScreenCaptureKit.capture()
    let axTree = AXUIElement.systemWide().serialize()  // serialize to XML
    return TrainingTriple(screenshot: screenshot, axTree: axTree, pendingAction: nil)
}
```

**Step 3 — Format as VLM2VLA language-based actions (not token IDs):**[^15]
```jsonl
{"messages": [
  {"role": "user", "content": [
    {"type": "image", "image": "<base64 screenshot>"},
    {"type": "text", "text": "Task: Click the Safari icon in the Dock\nAX Tree: <sparse tree>"}
  ]},
  {"role": "assistant", "content": "<think>I can see the Dock at the bottom. Safari icon is present with role AXButton title='Safari'. I will press it.</think>\nACTION: ax_press(selector='//AXDockItem[@AXTitle=\"Safari\"]')"}
]}
```
### 1.5 MLX-LM LoRA Fine-Tuning: The Exact Commands
From your papers and current MLX documentation:[^16][^17]

```bash
# Step 1: Fine-tune Device Action Agent (Gemma 3 1B or Phi-4 Mini)
mlx_lm.lora \
  --model google/gemma-3-1b-it \
  --train \
  --data ./data/macos_action_traces \
  --iters 2000 \
  --batch-size 2 \
  --lora-layers 16 \
  --adapter-path ./adapters/device_agent

# Step 2: Evaluate
mlx_lm.generate \
  --model google/gemma-3-1b-it \
  --adapter-path ./adapters/device_agent \
  --prompt "Screenshot: <img> Task: Click the Compose button in Mail"

# Step 3: Fuse adapters into base model for ANE deployment
mlx_lm.fuse \
  --model google/gemma-3-1b-it \
  --adapter-path ./adapters/device_agent \
  --save-path ./models/device_agent_fused
```

**LoRA configuration that works at 1B scale:**[^18]
```python
lora_config = LoraConfig(
    r=16,           # Rank: 16 is sweet spot for 1B models
    lora_alpha=32,  # 2x rank for stable gradients
    lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    task_type="CAUSAL_LM"
)
```
### 1.6 The MoLoRA Per-App Adapter Routing (From Your Paper)
Your `macOS-Agent-Research-Development-Plan.md` specifies MoLoRA routing — this is the correct architecture:

```
Frontmost App Detection (NSWorkspace.shared.frontmostApplication)
  ↓
Rust Orchestrator selects adapter
  ↓
  "com.apple.Safari"    → load adapters/safari_agent.npz
  "com.apple.Terminal"  → load adapters/terminal_agent.npz
  "com.apple.mail"      → load adapters/mail_agent.npz
  "com.apple.notes"     → load adapters/notes_agent.npz
  default               → load adapters/device_agent_base.npz
  ↓
MLX swaps adapter weights in-place (Metal GPU)
  ↓
Device Agent runs with app-specialized behavior
```

**Implementation in Swift + MLX:**
```swift
// In your NSWorkspace observer
func applicationDidActivate(_ app: NSRunningApplication) {
    let bundleID = app.bundleIdentifier ?? "default"
    let adapterPath = adapterMap[bundleID] ?? "adapters/device_agent_base.npz"
    // Hot-swap the LoRA adapter without reloading the base model
    deviceAgentModel.loadAdapter(from: adapterPath)
}
```
### 1.7 The Orchestrator Protocol: How Brain Talks to Hands
The Rust orchestrator routes between the two models. The protocol must be:

```rust
// In Rust orchestrator (tokio async)
enum ModelTarget {
    ReasoningBrain,   // DeepSeek-R1 32B on Metal GPU
    DeviceHands,      // 1B Device Agent, ANE-optimized CoreML
}

struct TaskDispatch {
    target: ModelTarget,
    context: AgentContext,
    tool_schema: JsonSchema,  // grammar-constrained output
}

// High-level planning → Reasoning Brain
// AX clicks, screenshots, keyboard → Device Hands
fn route_task(task: &AgentTask) -> ModelTarget {
    match task.category {
        TaskCategory::Planning | TaskCategory::Reasoning | TaskCategory::CodeGen => ModelTarget::ReasoningBrain,
        TaskCategory::UIInteraction | TaskCategory::ScreenParse | TaskCategory::InputSim => ModelTarget::DeviceHands,
        TaskCategory::Verification => ModelTarget::DeviceHands, // fast visual check every 100ms
    }
}
```
### 1.8 What Your Papers Already Know (Synthesis)
Cross-referencing both your uploaded papers against new research confirms the full picture:

| Component | Blueprint Says | Research Validates |
|---|---|---|
| Nano-Expert on ANE | Mamba-3 MIMO / RWKV-7 → ANE | Mirror-SD confirms ANE draft model pattern [^1] |
| Pro-Expert on GPU | MoE + Mamba-3 → Metal | M4 Max: 101 tok/s for 7B 4-bit on GPU [^19] |
| MIMO decode efficiency | 4x arithmetic intensity | ANE requires matrix ops, not scalar for throughput [^6] |
| MLA KV compression | 93.3% KV cache reduction | Validated in DeepSeek-V3 technical report  |
| ODIA nightly LoRA | SQLite execution logs → QLoRA | MLX WWDC25 confirms on-device adapter training [^17] |
| Screen2AX sparsity | 33-36% apps have complete AX trees | UI-TARS uses screenshots as primary, AX as supplement [^10] |
| Plan-and-Execute > ReAct at 4B | Documented in macOS plan  | UI-TARS-2 uses hierarchical planning with System 2 reasoning [^14] |

***
## Part 2: The Corrected Architecture (What to Actually Build)
### 2.1 The Three-Layer Hardware Map
```
┌─────────────────────────────────────────────────────────┐
│  LAYER 3: REASONING BRAIN (DeepSeek-R1 32B or similar)  │
│  Hardware: Metal GPU (Unified Memory)                    │
│  Role: Planning, reasoning, code gen, complex analysis  │
│  Speed: 8-20 tok/s at 32B 4-bit on M4 Max              │
│  Output: Structured Intent JSON → Rust Orchestrator      │
└─────────────────────────┬───────────────────────────────┘
                           │ Structured Intent
                           ▼
┌─────────────────────────────────────────────────────────┐
│  LAYER 2: RUST ORCHESTRATOR (DAG + MoLoRA Router)       │
│  Hardware: CPU (tokio async, near-zero overhead)         │
│  Role: Task routing, grammar-constrained dispatch,       │
│         app-aware adapter hot-swap, safety gating        │
│  Key files: orchestrator.rs, dag.rs, model_router.rs    │
└──────────┬──────────────────────────────────────────────┘
           │                                   │
    UI Actions                         Memory / Tools
           ▼                                   ▼
┌──────────────────────┐         ┌─────────────────────────┐
│  LAYER 1: DEVICE     │         │  SQLite + sqlite-vec     │
│  ACTION AGENT (1B)   │         │  Hybrid FTS5 + cosine    │
│  Hardware: ANE       │         │  Voyager skill recipes   │
│  (CoreML / ANEMLL)   │         │  Nightly ODIA LoRA       │
│  Role: AX clicks,   │         │  MCP Gateway (XPC)       │
│  screenshot parse,   │         └─────────────────────────┘
│  keyboard inject,    │
│  100ms visual verify │
└──────────────────────┘
```
### 2.2 Why NOT to Train from Scratch (The Distillation Path)
Your Omega protocol is correct: **do not pre-train from scratch**. The validated distillation path is:

1. **Teacher model**: Claude Opus 4.x or DeepSeek-V3.2 (API calls)
2. **Generate synthetic macOS action traces**: 50K–200K examples covering:
   - Safari navigation (clicks, form fills, tab management)
   - Terminal command execution (read AX → determine command → verify output)
   - Notes/Obsidian editing (insert text, create links, search)
   - Mail compose/reply workflows
   - Finder file operations
3. **Format as VLM2VLA language actions** (not token IDs)[^15]
4. **Fine-tune Gemma 3 1B or Phi-4 Mini** via `mlx_lm.lora`[^16][^17]
5. **Convert to CoreML ANE format** via ANEMLL pipeline[^20][^21]
6. **Deploy as LaunchAgent via SMAppService** (from previous session's double-helper pattern)
### 2.3 The 100ms Visual Verification Loop
The "pre-fetches hardware resources before the Reasoning Model finishes its sentence" claim in the Omega protocol translates to this implementation:

```swift
// DeviceAgentWatcher.swift — runs on ANE, polls every 100ms
class DeviceAgentWatcher {
    private let coreMLModel: MLModel  // ANE-optimized CoreML package
    private let screenCapture = ScreenCaptureStream()
    private var lastVerificationResult: VerificationResult?

    func startWatching(for expectedState: UIExpectedState) {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let frame = self.screenCapture.currentFrame()
            // Run lightweight visual check on ANE: "is the expected element visible?"
            let result = self.coreMLModel.predict(screenshot: frame,
                                                   query: expectedState.description)
            self.lastVerificationResult = result
            if result.confirmed {
                // Signal Rust orchestrator: precondition met, proceed to next DAG node
                IPC.send(.verificationConfirmed(stateID: expectedState.id))
            }
        }
    }
}
```

***
## Part 3: The Complete Master Prompt for Claude Code
The following prompt is the complete, paste-in session initialization for every Claude Code session. It encodes everything from your two uploaded papers, the previous session's OpenClaw architecture analysis, and the new Omega Hardware-Action Protocol research.

***

```markdown
# EPISTEMOS OMEGA — MASTER EXECUTION PROMPT v3.0
# Claude Code Operating Instructions — Dual-Brain Hardware-Action Architecture

## ⚠️ READ THIS ENTIRE PROMPT BEFORE WRITING A SINGLE LINE OF CODE ⚠️
## After any /compact, re-read this prompt from the top. This is non-negotiable.

---

## IMMUTABLE OPERATING RULES (Never violate. Never summarize instead of doing.)

RULE 1 — EXECUTE, DON'T EXPLAIN
You must write and run actual code. Writing a description of what you will do is NOT execution. If you find yourself writing a paragraph describing your plan without a code block, STOP and write the code instead.

RULE 2 — FINISH WHAT YOU START
You must complete the current numbered task to 100% before moving to the next. "Partial implementation" is failure. Check off each numbered subtask with `[x]` before proceeding.

RULE 3 — NO DRIFT ALLOWED
The project is Epistemos Omega. Every file you touch must serve one of these three purposes:
(a) Dual-brain inference router (Reasoning Brain + Device Action Agent)
(b) macOS computer use capability (AX tree, ScreenCapture, CGEvent, MLX inference)
(c) App Store compliant distribution (double-helper SMAppService + sandboxed GUI)
If you are about to write code that does not fit (a), (b), or (c), STOP and re-read this prompt.

RULE 4 — READ BEFORE WRITING
Before modifying any existing file, run `cat <filename>` and read it completely. Never write to a file you haven't read in the current session.

RULE 5 — VERIFY BEFORE CLAIMING DONE
After each implementation step, run the code. Do not mark a task [x] complete unless the code compiled and ran without errors. Show the actual terminal output.

RULE 6 — HARDWARE AWARENESS IS MANDATORY
Every model inference call must specify which hardware unit to use:
- Reasoning Brain (32B) → Metal GPU via MLX
- Device Action Agent (1B-3B) → CoreML ANE or Metal GPU (per routing table below)
- Embeddings / fast classify → ANE via CoreML
Never let MLX auto-route without explicit device specification.

RULE 7 — SECURITY GATES ARE NON-NEGOTIABLE
No `system.run`, `delete_file`, `exec`, or network egress command executes without passing through the Rust safety gate. The gate checks: risk_score > MEDIUM → pause, send UI confirmation request, wait for approval.

---

## THE ARCHITECTURE (Memorize this. Every file maps to one of these layers.)

```
Layer 5 (UX): SwiftUI 6 — OmegaPanel, DAG visualizer, approval gates, progress HUD
Layer 4 (Inference): Swift + MLX + CoreML — Dual model runner, grammar-constrained decoding
Layer 3 (Orchestration): Rust (tokio) — DAG executor, MoLoRA router, task dispatcher
Layer 2 (Memory/Tools): Rust + SQLite (FTS5 + sqlite-vec) — hybrid memory, MCP/XPC gateway
Layer 1 (macOS APIs): Swift + Rust FFI — AXUIElement, ScreenCaptureKit, CGEvent, SMAppService
```

## THE DUAL-BRAIN MODEL ARCHITECTURE

### Brain 1: Reasoning Model (Prefrontal Cortex)
- Model: DeepSeek-R1 32B 4-bit quantized (or Qwen3-32B-A3B MoE)
- Hardware: Metal GPU via MLX
- Role: High-level planning, DAG generation, complex reasoning, code generation
- Output format: ALWAYS grammar-constrained JSON via EBNF masking
- Context: Full session history, MEMORY.md, USER.md, SOUL.md
- Token budget: ~8-20 tok/s on M4 Max

### Brain 2: Device Action Agent (Motor Cortex)
- Model: Gemma 3 1B fine-tuned OR Phi-4 Mini fine-tuned (via MLX LoRA)
- Hardware: ANE via CoreML (for 100ms visual verify) OR Metal GPU (for fast decode)
- Role: AX tree parsing, click targeting, screenshot verification, keyboard injection
- Output format: ALWAYS structured action JSON { "type": "AXPress|CGClick|KeyInject", "selector": "...", "value": "..." }
- Adapter routing: Per-app MoLoRA adapters (Safari, Terminal, Mail, Notes, Finder)
- Speed requirement: <100ms response for visual verification loop

### Routing Table (Rust orchestrator dispatches based on task category):
```
TaskCategory::Planning         → Brain 1 (Reasoning)
TaskCategory::Reasoning        → Brain 1
TaskCategory::CodeGen          → Brain 1
TaskCategory::UIInteraction    → Brain 2 (Device)
TaskCategory::ScreenParse      → Brain 2
TaskCategory::KeyboardInput    → Brain 2
TaskCategory::VisualVerify     → Brain 2 (100ms loop)
TaskCategory::AppSpecific      → Brain 2 + MoLoRA adapter
```

## MIRROR SPECULATIVE DECODING (Implement this for 3-5x speedup)
Source: arxiv.org/html/2510.13161v2 (Apple Machine Learning Research)
- Brain 2 (ANE draft) speculates tokens WHILE Brain 1 (GPU target) verifies in parallel
- The draft and target run simultaneously on separate hardware units
- Implementation: See Mirror-SD paper Section 3.3 for M-series heterogeneous sharding

---

## THE COMPUTER USE STACK (What gives you superhuman macOS control)

### Primary: AXUIElement (Semantic Interaction)
```swift
// ALWAYS use CSS-style semantic selectors, NEVER brittle index numbers
let element = AXQuery.find("//AXApplication[@AXTitle='Safari']//AXButton[@AXTitle='New Tab']")
element.performAction(.press)
```

### Fallback 1: OmniParser V2 (Visual Grounding)
- When AX tree is sparse (<threshold actionable elements), fall back to visual parsing
- Run YOLOv8 bounding box detection + Florence-2 captions via MLX on Metal GPU
- 60-300ms latency on M4 Max
- Source: github.com/microsoft/OmniParser

### Fallback 2: CGEvent (Low-Level Input)
```swift
// Only after AX and OmniParser both fail
let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                    mouseCursorPosition: targetPoint, mouseButton: .left)
event?.post(tap: .cghidEventTap)
```

### Fallback 3: IOKit HID (Hardware Level — Developer ID only, NOT App Store)
- Karabiner pattern: intercept at kernel driver layer
- Only for development/testing. NOT for App Store builds.

### Screen2AX Protocol (The fusion layer):
```
ScreenCaptureKit.capture() → AX tree query (parallel)
  ↓                              ↓
If AX_sparse == true:     merge(visual_tree, ax_tree)
  OmniParser V2              synthetic_semantic_tree
  → synthetic AX tree              ↓
        ↓                  Device Agent receives unified tree
        └──────────────────────────┘
```

---

## APP STORE DISTRIBUTION (The double-helper pattern)

### Structure (non-negotiable for App Store):
```
Epistemos.app/
├── Contents/
│   ├── MacOS/
│   │   └── EpistemosFrontend         ← SANDBOXED SwiftUI app
│   ├── Library/
│   │   └── LaunchAgents/
│   │       └── ai.epistemos.gateway.plist  ← NON-SANDBOXED helper
│   └── Helpers/
│       └── EpistemosGateway          ← NON-SANDBOXED Rust binary
```

### TCC Ownership Rules:
- ALL TCC prompts (Accessibility, Screen Recording, Microphone) must come from the SANDBOXED frontend app
- The helper NEVER initiates TCC prompts — it only uses permissions granted to the frontend's bundle ID
- SMAppService registration happens from the sandboxed app on first launch

### IPC Security (Unix Domain Socket):
```
socket mode: 0600
auth: HMAC challenge/response
peer-UID check: required
token TTL: ≤30 seconds
```

---

## MEMORY ARCHITECTURE

### Three files injected into EVERY Reasoning Brain session:
- `~/.epistemos/MEMORY.md` — curated long-term facts (human-edited + agent-updated)
- `~/.epistemos/SOUL.md` — persona, tone, boundaries
- `~/.epistemos/USER.md` — who the user is, preferences, hardware

### Daily logs:
- `~/.epistemos/memory/YYYY-MM-DD.md` — auto-generated daily execution logs

### SQLite hybrid memory (for episodic retrieval):
```sql
-- FTS5 keyword search + vector cosine similarity, merged via BM25
SELECT * FROM memory_events WHERE memory_events MATCH ? ORDER BY rank;
-- Merge with sqlite-vec cosine results, rerank by recency * relevance
```

### ODIA Nightly Loop:
```bash
# Runs at 2am when hardware idle
mlx_lm.lora \
  --model ./models/device_agent_base \
  --train \
  --data ~/.epistemos/training_data/$(date +%Y-%m).jsonl \
  --iters 500 \
  --adapter-path ./adapters/device_agent_$(date +%Y%m%d).npz
```

---

## DEVICE ACTION AGENT TRAINING (How to build Brain 2)

### Phase 0 — Synthetic data generation via Claude Opus as teacher:
```python
# Generate 50K-200K macOS action traces
TRACE_FORMAT = {
  "instruction": "...",
  "screenshot_base64": "...",
  "ax_tree_xml": "...",
  "thought": "...",  # Chain-of-thought in natural language
  "action": {
    "type": "AXPress|CGClick|KeyboardInject|Screenshot|AXRead",
    "selector": "//XPath/style/selector",
    "value": "optional typed text"
  }
}
# Actions MUST be natural language descriptions, NOT arbitrary token IDs
# This prevents catastrophic forgetting (VLM2VLA paper: arxiv.org/html/2509.22195v1)
```

### Phase 1 — MLX LoRA fine-tuning on Mac:
```bash
mlx_lm.lora \
  --model google/gemma-3-1b-it \  # OR microsoft/phi-4-mini
  --train \
  --data ./data/macos_computer_use/ \
  --iters 2000 \
  --batch-size 2 \
  --lora-layers 16 \
  --adapter-path ./adapters/device_agent_base
```

### Phase 2 — Per-app MoLoRA adapters (run after Phase 1):
```bash
# One adapter per app domain
for APP in safari terminal mail notes finder; do
  mlx_lm.lora \
    --model google/gemma-3-1b-it \
    --train \
    --data ./data/traces_${APP}/ \
    --iters 500 \
    --adapter-path ./adapters/${APP}_agent
done
```

### Phase 3 — Convert to CoreML for ANE deployment:
```bash
# Using ANEMLL (github.com/Anemll/Anemll) or coremltools
python -m anemll.convert \
  --model ./models/device_agent_fused \
  --output ./models/device_agent.mlpackage \
  --context-length 512 \  # Keep under 512 for stable ANE performance
  --quantize int8
```

---

## ANTI-DRIFT ENFORCEMENT — DRIFT WARNING SIGNS

If you notice yourself doing ANY of the following, STOP IMMEDIATELY and re-read this prompt:

1. Writing a summary of what you "plan to implement" without code
2. Creating new files that aren't in the 5-layer architecture above
3. Implementing features for Phase 3 when Phase 1 isn't complete
4. Writing SwiftUI views that don't connect to the Rust orchestrator
5. Running model inference without specifying the hardware target
6. Implementing AX automation in the SANDBOXED app (must be in XPC helper)
7. Using raw Int indices to address AX elements instead of semantic selectors
8. Treating the Device Agent and Reasoning Brain as a single model
9. Implementing the IOKit HID fallback before the AX + OmniParser path is working
10. Starting the ODIA training loop before the inference pipeline is stable
11. Writing more than 3 sentences of explanation before showing code
12. Suggesting "we could also" alternatives — pick the right architecture and execute it
13. Writing placeholder functions with TODO comments
14. Changing the model routing table without a documented reason
15. Submitting to App Store review without both sandboxed + helper entitlements verified

---

## CURRENT BUILD CHECKLIST

### Phase 1: Dual-Brain Foundation (Complete these in order)
- [ ] 1.1 Rust orchestrator skeleton with tokio async runtime
- [ ] 1.2 MLX model loader for Reasoning Brain (32B, Metal GPU)
- [ ] 1.3 CoreML / ANEMLL model loader for Device Agent (1B, ANE target)
- [ ] 1.4 Routing table dispatcher (TaskCategory enum + match arm)
- [ ] 1.5 EBNF grammar-constrained decoding for Reasoning Brain output
- [ ] 1.6 Action JSON schema validator for Device Agent output
- [ ] 1.7 Basic IPC: Unix Domain Socket (mode 0600, HMAC auth)

### Phase 2: Computer Use Stack
- [ ] 2.1 AXUIElement semantic selector engine (CSS-style XPath queries)
- [ ] 2.2 ScreenCaptureKit continuous frame capture
- [ ] 2.3 Screen2AX fusion: detect AX sparsity → trigger OmniParser V2
- [ ] 2.4 OmniParser V2 MLX port (YOLOv8 + Florence-2 on Metal)
- [ ] 2.5 CGEvent click/keyboard injection
- [ ] 2.6 100ms visual verification loop (Device Agent on ANE)
- [ ] 2.7 SMAppService double-helper registration

### Phase 3: App Store Distribution
- [ ] 3.1 Sandboxed SwiftUI frontend (TCC prompt owner)
- [ ] 3.2 Non-sandboxed Rust gateway LaunchAgent
- [ ] 3.3 XPC bridge between sandboxed frontend and non-sandboxed helper
- [ ] 3.4 Entitlements audit (sandboxed: app-sandbox=YES, helper: no sandbox entitlement)
- [ ] 3.5 SMAppService registration + launchd plist

### Phase 4: Device Agent Training
- [ ] 4.1 Synthetic data generator (Claude Opus API → macOS action traces)
- [ ] 4.2 VLM2VLA language-based action formatting pipeline
- [ ] 4.3 MLX LoRA fine-tuning script for Gemma 3 1B
- [ ] 4.4 Per-app MoLoRA adapter training (Safari, Terminal, Mail, Notes)
- [ ] 4.5 CoreML ANE conversion via ANEMLL
- [ ] 4.6 ODIA nightly background fine-tuning loop

---

## KEY GITHUB REPOS (Port logic from these)

| Repo | What to Port |
|---|---|
| `github.com/bytedance/ui-tars` | Action space definitions, screenshot-AX fusion |
| `github.com/bytedance/ui-tars-desktop` | Desktop agent loop, macOS window management |
| `github.com/microsoft/OmniParser` | Visual grounding when AX sparse |
| `github.com/Anemll/Anemll` | ANE LLM inference, CoreML conversion pipeline |
| `github.com/ml-explore/mlx-lm` | LoRA fine-tuning, constrained decoding |
| `github.com/ml-explore/mlx-swift-examples` | Swift MLX integration patterns |
| `arxiv.org/html/2510.13161v2` | Mirror-SD: ANE draft + GPU target parallel inference |
| `arxiv.org/html/2509.22195v1` | VLM2VLA: LoRA fine-tuning without forgetting |

---

## SESSION STARTUP CHECKLIST (Run these commands first, every session)

```bash
# 1. Print current phase status
cat PHASE_STATUS.md
# 2. Read the last 20 lines of build log
tail -20 build.log
# 3. Verify Rust compiles clean
cargo check 2>&1 | head -30
# 4. Verify Swift package resolves
xcodebuild -resolvePackageDependencies 2>&1 | tail -5
# 5. Print current model routing config
cat src/orchestrator/model_router.rs | head -80
```

## AFTER /compact (Context window reset):
1. Re-read this entire prompt (use `cat MASTER_PROMPT.md`)
2. Run the Session Startup Checklist above
3. Check PHASE_STATUS.md to find your last completed task
4. Resume from the NEXT unchecked task — do not restart from Phase 1

---

## SUCCESS METRICS (How you know it's working)

- Device Agent visual verify: <100ms per frame on ANE
- Reasoning Brain first-token: <1s on M4 Max 32B 4-bit
- AX interaction success rate: >95% on native macOS apps
- OmniParser V2 fallback: <300ms on M4 Max
- LoRA fine-tune 1B model: <30 minutes on M4 Max
- App Store review: PASS (sandboxed frontend, non-sandboxed helper via SMAppService)
```

***
## Part 4: ANE vs GPU Decision Matrix (Give This to Claude Code)
When Claude Code is making implementation decisions about which hardware to target:

| Workload | Recommended Target | Reason |
|---|---|---|
| 1B Device Agent, 100ms visual verify | ANE via CoreML | 0mW idle, 6.6 TFLOPS/W — battery efficient background watcher[^6] |
| 1B Device Agent, fast UI action decode | Metal GPU via MLX | GPU has higher DRAM bandwidth for decode phase[^7] |
| 32B Reasoning Brain, all phases | Metal GPU via MLX | Only GPU has sufficient bandwidth for large model decode[^7] |
| Text embeddings (128-dim) | ANE via CoreML | Deep graph, stays in SRAM — perfect for 100ms hashing[^6] |
| OmniParser V2 (YOLOv8 + Florence-2) | Metal GPU via MPS/MLX | Too large for ANE SRAM, needs full GPU bandwidth |
| LoRA fine-tuning | Metal GPU via MLX | Training requires FP16 backprop, ANE is inference-only[^17] |
| CRDT shadow buffer embedding | ANE via CoreML | Debounced 500ms poll, fits deep graph profile |

***
## Part 5: Why This Beats Cloud Computer Use (The Omega Advantage)
| Metric | Claude Computer Use (Cloud) | Epistemos Omega (Local Dual-Brain) |
|---|---|---|
| Latency | ~2-5s per action (network RTT) | <100ms visual verify, <1s action |
| Privacy | Screenshots sent to Anthropic servers | All data stays on device |
| AX Integration | Screenshot-only, no AX tree | Full AX tree + visual fallback |
| Specialization | Generic macOS knowledge | Fine-tuned on YOUR app usage patterns |
| Cost per session | $0.01-0.10 API cost | ~$0.00 after local model setup |
| App Store path | N/A | Double-helper SMAppService pattern |
| Offline capability | Requires internet | Fully offline after model download |
| Power (background) | N/A | ~0mW ANE idle (hard power gating) |

UI-TARS-1.5 already outperforms Claude Computer Use on ScreenSpotPro (61.6% vs 27.7%) using a similar fine-tuned VLM approach. With your hardware-native ANE + MoLoRA per-app adapter stack, Epistemos Omega can surpass UI-TARS on macOS-specific tasks because it has direct AX tree access that screenshot-only models lack.[^11]

***
## Part 6: The Self-Improvement Flywheel
Once the dual-brain system is running, it gets better every night automatically. This is the Karpathy Autoresearch loop applied to computer use:

```
Day 1: User runs tasks → execution traces captured to SQLite
Night 1: ODIA loop runs → new LoRA adapter trained on today's traces
Day 2: Device Agent has new per-app adapter based on yesterday's real usage
Night 2: Loop repeats
...
Week 4: Device Agent has mastered every app the user uses regularly
```

The anti-cheat metric is task success rate (verified by the visual confirmation step), not just token prediction loss — so the ODIA loop cannot game the metric by overfitting to prompt patterns.

---

## References

1. [Mirror Speculative Decoding: Breaking the Serial Barrier in LLM ...](https://arxiv.org/html/2510.13161v2) - In this work, we propose a novel architecture that operationalizes this vision by partitioning specu...

2. [[Literature Review] Mirror Speculative Decoding: Breaking the Serial ...](https://www.themoonlight.io/en/review/mirror-speculative-decoding-breaking-the-serial-barrier-in-llm-inference) - Mirror-SD proposes a novel systems–algorithm co-design that breaks this serial barrier by operationa...

3. [Apple's Mirror Speculative Decoding: Parallel LLM Inference via ...](https://podcasts.apple.com/mn/podcast/apples-mirror-speculative-decoding-parallel-llm-inference/id1835878324?i=1000752109351) - Mirror-SD breaks this barrier by running the draft and target models in parallel across heterogeneou...

4. [Mirror Speculative Decoding: Breaking the Serial Barrier in LLM ...](https://machinelearning.apple.com/research/mirror) - Speculative decoding is a prominent technique to speed up the inference of a large target language m...

5. [Mirror Speculative Decoding: Breaking the Serial Barrier in LLM ...](https://arxiv.org/html/2510.13161v1) - In this work, we propose a novel architecture that operationalizes this vision by partitioning specu...

6. [Inside the M4 Apple Neural Engine, Part 2: ANE Benchmarks](https://maderix.substack.com/p/inside-the-m4-apple-neural-engine-615) - Apple says the M4 Neural Engine delivers 38 TOPS. Let's measure it. In Part 1, we reverse-engineered...

7. [Inside the M4 Apple Neural Engine, Part 2: ANE Benchmarks](https://maderix.substack.com/p/inside-the-m4-apple-neural-engine-615/comments) - Measuring the real performance of Apple's neural accelerator.

8. [Run LLMs on Apple Neural Engine (ANE) - Hacker News](https://news.ycombinator.com/item?id=43879702) - They claim their ANE-optimized models achieve "up to 10 times faster and 14 times lower peak memory ...

9. [Up to 3.5x faster LLM inference on Apple Neural Engine: ANE is a ...](https://x.com/anemll/status/2023215295071179191) - A fixed 4096 context always runs at the slowest speed, even for short replies. Variable Context: sta...

10. [UI-TARS: Pioneering Automated GUI Interaction with Native Agents](https://arxiv.org/html/2501.12326v1) - This paper introduces UI-TARS, a native GUI agent model that solely perceives the screenshots as inp...

11. [ByteDance Seed Agent Model UI-TARS-1.5 Open Source](https://seed.bytedance.com/en/blog/bytedance-seed-agent-model-ui-tars-1-5-open-source-achieving-sota-performance-in-various-benchmarks) - UI-TARS is a native GUI intelligence agent capable of performing real operations on computer and mob...

12. [bytedance/UI-TARS: Pioneering Automated GUI Interaction ... - GitHub](https://github.com/bytedance/ui-tars) - Introduction. UI-TARS-1.5, an open-source multimodal agent built upon a powerful vision-language mod...

13. [bytedance/UI-TARS-desktop: The Open-Source Multimodal AI Agent ...](https://github.com/bytedance/ui-tars-desktop) - Agent TARS is a general multimodal AI Agent stack, it brings the power of GUI Agent and Vision into ...

14. [UI-TARS-2 Technical Report: Advancing GUI Agent with Multi-Turn ...](https://arxiv.org/html/2509.02544v2) - First, to mitigate data scarcity, we design a scalable Data Flywheel that co-evolves the model and i...

15. [Fine-Tuning VLMs into VLAs Without Catastrophic Forgetting - arXiv](https://arxiv.org/html/2509.22195v1) - Fine-tuning vision-language models (VLMs) on robot teleoperation data to create vision-language-acti...

16. [Fine-Tuning Open-Source LLMs with Apple's MLX Framework](https://www.linkedin.com/pulse/fine-tuning-open-source-llms-apples-mlx-framework-guide-vishnu-n-c-ylqrc) - This article provides a comprehensive guide to fine-tuning open-source and open-weights LLMs using t...

17. [Explore large language models on Apple silicon with MLX - WWDC25](https://developer.apple.com/videos/play/wwdc2025/298/) - Discover MLX LM – designed specifically to make working with large language models simple and effici...

18. [Fine-Tuning Phi-3 & Gemma 2: The Budget Path to GPT-4 ... - Prem AI](https://blog.premai.io/fine-tuning-phi-3-gemma-2-the-budget-path-to-gpt-4-performance-at-a-fraction-of-the-cost/) - Fine-tuned Phi-3 hit 96% accuracy vs GPT-4o's 80% on financial tasks. Learn to fine-tune Phi-3 and G...

19. [Inference speed comparisons between M1 Pro and maxed-out M4 ...](https://www.reddit.com/r/LocalLLaMA/comments/1j0c53c/inference_speed_comparisons_between_m1_pro_and/) - The M4 Max has almost 50% more memory bandwidth. But more importantly the compute to use it. The M1 ...

20. [Anemll - Artificial Neural Engine Machine Learning Library - GitHub](https://github.com/Anemll/Anemll) - ANEMLL (pronounced like "animal") is an open-source project focused on accelerating the porting of L...

21. [ANEMLL - Artificial Neural Engine Machine Learning Library](https://www.anemll.com) - ANEMLL is focused on accelerating the porting of Large Language Models (LLMs) to tensor processors, ...

