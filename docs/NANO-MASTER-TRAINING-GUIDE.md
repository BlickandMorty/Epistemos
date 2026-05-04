# EPISTEMOS NANO MODEL — MASTER TRAINING GUIDE FOR CLAUDE CODE

> **Index status**: CANONICAL-RESEARCH — Training data curation for Nano(1B)/Base(3B)/Pro(8B) tiers with data mix ratios + self-instruct patterns.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.


### Version 2.0 · March 25, 2026
### This document is the single source of truth for all training material decisions.
### Claude Code: Read this before touching any training pipeline. Ground every decision here.

---

> **This is not a research summary. This is an execution manual.**
> Every section ends with a concrete action. Every number is validated.
> Every pipeline has a script. If it's not here, don't do it.

---

## THE THREE PILLARS OF LEGENDARY NANO PERFORMANCE

Your 1B hybrid Mamba-2/Attention model must excel at three things simultaneously:

1. **General macOS device control** — Navigate any app via AX trees, execute tool calls, recover from errors
2. **Epistemos self-knowledge** — Know its own codebase, UI, workflows, and state transitions as reflexes baked into weights — not inference overhead
3. **Continuous self-improvement** — Get better every night through automated data flywheel, without forgetting what it already knows

These three pillars are not sequential phases. They are **concurrent training objectives** with shared infrastructure. Every dataset, every LoRA adapter, every eval harness must serve all three.

---

## PILLAR 1: ARCHITECTURE + DISTILLATION

### 1.1 The Hybrid Ratio: 75% Mamba-2 / 25% Attention

This ratio is validated but sits at a cliff edge. Do not go more aggressive without ablation on a 150M proxy first.

**Layer placement for 24-layer stack (non-negotiable):**

| Layers | Type | Role |
|--------|------|------|
| 1–4 | Mamba-2 | Initial sequence compression |
| 5 | Attention | Early retrieval anchor |
| 6–10 | Mamba-2 | Mid-level context integration |
| 11 | Attention | Schema enforcement (JSON structure) |
| 12–17 | Mamba-2 | Deep context distillation |
| 18–19 | Attention | Final retrieval (current AX state + app identity) |
| 20–24 | Mamba-2 | Output formation |

**Mamba-2 → Mamba-3 Migration Plan (March 2026):**

The hybrid ratio (75/25) is correct regardless of which Mamba generation is used. The 6 attention layers exist for three things no SSM variant can do:
1. **Exact AX tree retrieval** — verbatim token lookup for correct selectors (SSMs compress into fixed-size state)
2. **JSON schema enforcement** — attention layer 11 anchors structured output format
3. **Multi-turn context anchoring** — layers 18-19 provide exact recall of recent 512 tokens

Mamba-3 (Gu & Dao, ICLR 2026) fixes state-tracking ("which app am I in?") via complex-valued dynamics and exponential-trapezoidal discretization. This is **complementary** to attention, not a replacement. At 1.5B, it matches Mamba-2 perplexity with half the state size (64 vs 128).

**Timeline:**
- **Now (Week 1-4):** Build with Mamba-2. MOHAWK is validated, MLX v0.31.1 supports it, tooling exists. Mamba-3 has no MOHAWK recipe, no MLX training support, no quantization tooling yet.
- **Month 2-3:** Once community validates Mamba-3 distillation (watch `state-spaces/mamba` repo, GoombaLab blog), swap the 18 Mamba-2 layers for Mamba-3 layers. Attention layers stay. LoRA adapters stay. Nightly flywheel stays. Config change, not architecture rewrite.

**Design for this now:** Keep layer abstraction parameterized so `mamba2_layer` → `mamba3_layer` is a config swap. Complex-valued state matrices and exponential-trapezoidal discretization are internal to the layer — input/output interface is identical.

### 1.2 MOHAWK Distillation — Stability Recipe

**Known failure modes and fixes:**

1. **Gradient explosion** (GitHub #529, #353 on state-spaces/mamba): Reproducible at lr=4e-4, d_model=1024. Fix: store all params in fp32 via AMP, never zero-initialize Δ bias, gradient clip at norm 1.0.

2. **Stage 1 matrix orientation silent failure**: Post-initialization hooks can reset bias terms to zero, breaking Δ parameter initialization. Verify after init that convolution weights are identity-initialized and gate biases are 1.0.

3. **Attention-to-Mamba weight mapping**: Use SMART (Sensitivity Measure-Aware Replacement) from Zebra-Llama — measure each attention layer's output distribution shift before deciding which to convert. Replace the least-sensitive layers first.

**Distillation hyperparameters (validated):**

```
Learning rate: ≤2e-4 (NOT 4e-4 — that triggers NaN)
Optimizer: AdamW β=(0.9, 0.98)
Precision: BF16 for training, FP32 parameter storage
Warmup: 500 steps
Schedule: WSD (Warmup-Stable-Decay), NOT cosine
  - Stable phase: 80% of total steps at peak LR
  - Decay phase: 20% — inject highest-quality macOS + Epistemos traces here
Stage 3 loss: α=1.0 KL(teacher, student) + β=0.1 CE(student, labels)
Token budget: Target 8B tokens (D:N ratio = 8, per nanochat finding)
```

**The WSD advantage**: Pre-decay checkpoints are reusable. When new Epistemos app traces become available, continue training from any stable-phase checkpoint without cold restart.

### 1.3 Quantization — Hybrid-Aware Mixed Precision

**This is the most underappreciated gap.** No existing quantization tool handles hybrid models correctly. You must configure manually:

| Component | Precision | Why |
|-----------|-----------|-----|
| Mamba-2 SSM (A, B, C, dt) | FP16 | Scattered activation outliers, cumulative product stability |
| Mamba-2 conv1d kernel | FP16 | Small relative to projections, critical for accuracy |
| Mamba-2 in_proj, out_proj | INT4 | High redundancy, primary memory savings |
| Attention Q,K,V projections | INT4 | Standard aggressive quant |
| MLP gate/up/down | INT4 | Standard |
| Output logit layer | FP16 | Accuracy-critical |
| Embedding table | FP16 | Lookup precision |

Use KLT-Enhanced rotation (beyond Hadamard) for weight projection matrices per MambaQuant (ICLR 2025). Mamba output projections have up to 40% flush-to-zero rates at FP4.

### 1.4 Deployment — MLX on GPU, NOT ANE

**Critical correction: The Mamba-2 selective scan cannot execute on Apple Neural Engine.** The sequential state dependency fundamentally conflicts with ANE's parallelizable-operation requirement. ANEMLL has zero SSM support.

**Deploy entirely on MLX/Metal GPU:**
- mlx-lm v0.31.1 natively supports Mamba-1, Mamba-2, Nemotron-H, and Jamba
- Expected inference for 1B 4-bit on M4 Max: **70–95 tok/s generation**
- This is sufficient for interactive agent use (sub-200ms per action)

**Reserve ANE for:**
- The 100ms visual verification loop (screenshot classification — this IS a standard transformer/CNN)
- Text embedding (Model2Vec — small, static compute graph)
- Intent classification router (50M classifier, < 5ms)

---

## PILLAR 2: APP-SPECIFIC META-TRAINING — THE REFLEXIVE CORE

### Why This Changes Everything

A generic macOS agent sees an AX tree and reasons about what to do: 10–50ms of inference. A model trained on its own app's code, UI states, and workflows **recalls** the mapping from weights: sub-1ms. The difference is the gap between a tourist reading a map and a local who grew up on those streets.

This is not an optional enhancement. It is **the competitive moat**. No cloud model can replicate a model that has internalized your specific app's architecture, state machine, and UI graph.

### 2.1 Layer 0 — Code Graph Model (CGM)

Before any fine-tuning, represent the Epistemos codebase as a **code graph**, not flat text files. This is the CGM approach (NeurIPS 2025, CodeFuse-AI).

**What it does:**
1. Parses Swift ASTs to build hierarchical graph: `AppDelegate → ViewController → UIButton → @IBAction → state change`
2. Encodes each node (function, class, method, UI component) via text encoder
3. Replaces causal attention mask between node tokens with code graph adjacency matrix
4. Pre-trains via subgraph reconstruction: mask nodes, predict from graph neighbors

**Implementation:** `codefuse-ai/CodeFuse-CGM` on GitHub. Supports LoRA, QLoRA, full-parameter training. CGM with 7B backbone surpasses Agentless + Claude-3.5-Sonnet by 2.33% on SWE-bench Lite.

**For Epistemos specifically:**
```
Source graph: ~/Epistemos/Sources/**/*.swift + Rust crates via UniFFI boundary
Node types: SwiftUI views, @Observable models, Rust structs, MCP tools, SQLite tables
Edge types: calls, conformsTo, memberOf, UniFFI bridge, publishes/subscribes
Output: app_code_graph.json — structural input to CGM adapter
```

**The CGM adapter is separate from the AX-action LoRA and can be stacked.** The model receives code graph context at all times when Epistemos is the active app.

### 2.2 Layer 1 — Xcode Symbol Graph → QA Pairs

Use `xcodebuild -symbolGraph` to extract every symbol relationship in the Epistemos codebase. Generate two types of QA pairs per symbol:

- **Forward mapping**: "User wants to create a new note" → `{ class: 'NoteCoordinator', method: 'createNote(title:)', file: 'NoteCoordinator.swift' }`
- **Reverse mapping**: "What does `OmegaPlanningService.generatePlan()` do?" → "Generates a DAG execution plan from user intent, dispatching to specialist agents"

**Cross-file context is critical.** A button's handler in `ViewController.swift` only makes sense with the data model in `DocumentStore.swift` and navigation in `AppCoordinator.swift`. The symbol graph resolves these dependencies automatically.

**Curriculum within this layer:**
- Phase 1: API signatures, return types, parameter names
- Phase 2: Architecture — which coordinator owns which flow, dependency injection
- Phase 3: Runtime behavior — what happens when a method fails, error recovery paths

### 2.3 Layer 2 — AX Atlas with Differential Snapshots

Capture every screen state of Epistemos as an AX tree, then train on **diffs** — not just what elements exist, but what changed after each action.

```
For each workflow (create note, search, export, settings, etc.):
  1. Capture pre-action AX tree via macapptree
  2. Execute action
  3. Wait 150ms (Apple accessibility propagation delay)
  4. Capture post-action AX tree
  5. Compute structural diff (added/removed elements)
  6. Generate training example:
     instruction: "Step 2/5 of 'create new note'. What action should I take?"
     response: {"action": "click", "selector": "AXButton[name=Create]"}
     context: {pre_diff, post_diff, workflow_name, step_index}
```

**Include error states.** What does the AX tree look like when Epistemos shows an error dialog? A permission request? A loading spinner? These are the states where generic agents fail and app-specific training provides the biggest advantage.

### 2.4 Layer 3 — SFT → RLAIF Agentic Recipe

The SWE-QA-Pro finding (March 2026): RL after SFT gives larger gains than adding more SFT data for agentic tasks.

**Stage A — Generate 1,000 multi-turn trajectories via Claude Sonnet 4.5:**
Each trajectory is 3–8 steps through Epistemos, using the AX atlas and symbol QA as context. Format: [OBSERVE] → [REASON] → [ACT] → [RESULT] → [DONE].

**Stage B — RLAIF with 464 verification pairs:**
LLM judge evaluates on: correctness (verifiable via sandbox), completeness, relevance, clarity, reasoning quality. The key: "correctness" is whether executing the rollout's actions achieves the stated goal in a sandboxed macOS environment — ground truth, not speculation.

### 2.5 Doc-to-LoRA — Instant Adapter on App Ship

Sakana AI's Doc-to-LoRA (February 2026): A hypernetwork generates a LoRA adapter from your updated source code in a **single forward pass** — no gradient computation at deploy time.

**Integration with Epistemos build pipeline:**
1. Xcode post-build script triggers adapter generation
2. Feed Swift source + AX atlas JSON through frozen base LLM
3. Perceiver-style hypernetwork maps activations to rank-8 LoRA matrices
4. Total latency: sub-second from code → deployed adapter
5. KV-cache memory drops from >12GB (codebase in context) to <50MB (adapter only)

**Fallback when hypernetwork isn't trained yet:** Standard 200-iteration fine-tune on `app_atlas_differential.jsonl`, ~15 min on Apple Silicon.

**Make adapter generation a mandatory build step before QA.** If the app ships a UI change and the adapter hasn't been regenerated, the model will confidently emit stale selectors that fail silently.

### 2.6 Version-Aware Adapter Lifecycle

```
On every Xcode build:
  1. Check if adapter exists for current MARKETING_VERSION
  2. If not → regenerate (Doc-to-LoRA instant or standard fine-tune)
  3. Update symlink: yourapp_latest.lora → yourapp_v{X}.lora
  4. At runtime: ModelRouter loads yourapp_latest.lora when Epistemos is frontmost app
```

---

## PILLAR 3: GENERAL macOS DEVICE CONTROL

### 3.1 Training Data Composition — Validated Ratios

The validated SFT data composition for tool-calling at 1B scale:

| Category | Percentage | Source |
|----------|------------|--------|
| Tool-calling examples (AXPress actions) | 40% | Synthetic traces + ODIA logs |
| General instruction-following | 25% | SmolTalk, MMLU-aux |
| **Epistemos app-specific traces** | 20% | CGM, AX atlas, symbol QA, trajectories |
| Negative examples (when NOT to call a tool) | 10% | Hammer-style irrelevance augmentation |
| Error recovery examples | 5% | Intentionally injected failures |

**Critical: The 20% Epistemos allocation is not optional.** This is what transforms a generic macOS agent into one that controls its own app as reflex. But it must not exceed ~25% or the model overfits to Epistemos and degrades on other apps.

### 3.2 Tool-Calling Fine-Tuning

**Function masking (Hammer, ICLR 2025 Spotlight):** During training, randomly mask 33% of function names and parameter names. Forces the model to rely on descriptions rather than memorizing naming conventions.

**BalanceSFT SSB loss reweighting:** Standard SFT suffers from token-level imbalance — CoT reasoning tokens numerically dominate concise function-call tokens. The model learns plausible reasoning but imprecise tool calls. Apply Self-adjusted Signal Balancing loss.

**Constrained decoding on MLX:** Use Outlines (`pip install "outlines[mlxlm]"`) for JSON schema enforcement at inference time. Compile your AXPress schema once, enforce at every generation. ~40μs overhead per token.

### 3.3 AX Tree Representation

**Sparse, indented text format** — saves 40–60% tokens vs XML/JSON:

```
[Safari] (focused)
  [Window: arxiv.org - Safari] (frontmost)
    [Toolbar]
      [TextField: Address and Search Bar] value="https://arxiv.org"
      [Button: Reload this page]
    [ScrollArea]
      [StaticText] value="Subjects"
```

Filter criteria: only AXEnabled=true, only elements with title/value/description, depth ≤ 6, exclude AXGroup wrappers with no actionable children. For apps with sparse AX trees (<5 actionable elements), fall back to Screen2AX.

### 3.4 Data Sources

| Source | What | Volume Target |
|--------|------|---------------|
| macapptree (100ms poll loop) | Live AX trees during human use | 5,000 raw traces/week |
| Screen2AX datasets | Pre-built: 1,127 images × 112 apps | One-time download |
| AgentTrek-style tutorial mining | Apple Support articles → verified trajectories | 10,000 trajectories @ $0.55 each |
| Evol-Instruct evolution | Complexity mutations of seed traces | 50K–200K total |
| Superfiltering (GPT-2 IFD) | Quality scoring of all above | Keep top 15% |
| Epistemos CGM + AX atlas | App-specific code graph + differential snapshots | Regenerate every build |

---

## PILLAR 4: REINFORCEMENT LEARNING

### 4.1 GRPO — Decomposed Rewards Prevent Gradient Collapse

The #1 failure mode: all completions in a GRPO group receive the same binary reward, producing zero advantage signal.

**6-component decomposed reward (validated):**

| Component | Weight | Signal |
|-----------|--------|--------|
| Format correctness | 0.10 | Action is parseable, valid JSON structure |
| Element identification | 0.30 | Correct UI element targeted in AX tree |
| Action type correctness | 0.20 | Correct verb (click/type/scroll/press) |
| Parameter correctness | 0.20 | Correct text input, coordinates, modifiers |
| State progression | 0.10 | Environment state moved toward goal |
| Task completion | 0.10 | Final binary success signal |

**RC-GRPO (February 2026):** Append discrete reward tokens (`<|high_reward|>`, `<|low_reward|>`) to prompts, forcing diversity in rollouts even when the base policy is deterministic.

### 4.2 GRPO Hyperparameters for 1B Scale

```
Group size: 8 (minimum 4, marginal gains from 4→8)
Learning rate: 3e-6 to 5e-6, cosine decay, 10% warmup
Gradient clipping: 0.1 (tighter than standard)
Clip ratio ε: 0.2
Asymmetric clip-high: 0.28 (DAPO — prevents entropy collapse)
Loss aggregation: token-mean (NOT seq-mean)
Overlong filtering: mask truncated completions (don't assign negative reward)
Temperature: 0.7–1.0 for exploration
```

**Monitor entropy.** If it monotonically decreases, the model is collapsing. Calibrate task difficulty so the model succeeds 20–50% of the time.

### 4.3 MLX GRPO Implementation

Two community packages available:
- **mlx-lm-lora** (Gökdeniz Gülmez): 12 algorithms including GRPO, Dr. GRPO, DAPO. ~1 it/sec on M4 Pro.
- **MLX-GRPO** (Doriandarko): DeepSeek-R1-style GRPO. Config: `lr=5e-7, num_generations=64, clip_eps=0.2, kl_coeff=0.01`.

**Start GRPO only after SFT has converged.** Base model with no SFT leads to degenerate reward hacking.

### 4.4 KTO for Binary Feedback (ODIA Nightly Loop)

For the nightly self-improvement loop where feedback is binary (execution success/fail), use KTO instead of GRPO:
- KTO matches DPO at all scales 1B–30B with strictly less information per example
- Binary labels naturally (success = desirable, failure = undesirable)
- Robust to SFT-skipping — important for efficient ODIA loops
- Config: `beta=0.1, lr=1e-5, epochs=1, desirable_weight=1.0, undesirable_weight=1.0`

---

## PILLAR 5: CONTINUOUS SELF-IMPROVEMENT

### 5.1 Nightly Flywheel — Full Automation

```
┌─────────────────────────────────────────────────────────────┐
│  2:00 AM — COLLECT                                           │
│  Gather all execution traces from today's production logs    │
│  Include: AX trees, actions taken, success/fail outcomes     │
│  Include: Epistemos-specific traces (app-aware adapter)      │
├─────────────────────────────────────────────────────────────┤
│  2:15 AM — FILTER QUALITY                                    │
│  Superfiltering IFD scoring (GPT-2, CPU, ~5 min)            │
│  Keep top 15% by IFD score                                   │
│  Re-score IFD every 2 weeks using current production model   │
├─────────────────────────────────────────────────────────────┤
│  2:30 AM — CURRICULUM SORT                                   │
│  CAMPUS scheduler: multi-axis difficulty ordering             │
│  Axes: tree_depth, selector_ambiguity, chain_length, IFD     │
│  10% random injection of max-difficulty to prevent stalling   │
├─────────────────────────────────────────────────────────────┤
│  2:45 AM — COMPOSE DATA MIX                                  │
│  40% successful ODIA traces (today's real execution)         │
│  20% Epistemos app-specific traces (CGM + atlas)             │
│  20% synthetic reasoning (Evol-Instruct variations)          │
│  20% generic instruction-following (prevent forgetting)      │
├─────────────────────────────────────────────────────────────┤
│  3:00 AM — LoRA FINE-TUNE                                    │
│  mlx_lm.lora --iters 200 --lora-rank 16 --lr 3e-4           │
│  Warm-start from current production adapter                  │
│  LoRA-only updates: NEVER update base model weights nightly  │
├─────────────────────────────────────────────────────────────┤
│  3:30 AM — EVALUATE                                          │
│  Run BFCL-style holdout (100 standard macOS tasks)           │
│  Run Epistemos-specific holdout (50 app tasks)               │
│  Both must improve or adapter is rejected                    │
├─────────────────────────────────────────────────────────────┤
│  3:45 AM — CANARY DEPLOY                                     │
│  If new_score > baseline + 0.5%: deploy to production        │
│  If not: git reset --hard to previous adapter                │
│  Log everything to MLflow                                    │
├─────────────────────────────────────────────────────────────┤
│  MONTHLY — BASE MODEL MERGE                                  │
│  mlx_lm.fuse adapter into base model                         │
│  Retrain fresh adapters on top                               │
│  Prevents adapter weight drift accumulation                  │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Version-Triggered App Adapter Regeneration

Integrated into Xcode build pipeline. Every time Epistemos ships a UI change:
1. Post-build script detects new MARKETING_VERSION
2. Doc-to-LoRA generates fresh adapter in <1 second (or standard fine-tune in ~15 min)
3. New adapter deployed alongside app binary
4. Old adapter retained for rollback

### 5.3 DAgger with Uncertainty-Based Expert Querying

When the model encounters states it hasn't seen before:
1. Run inference 5× with dropout enabled (Monte Carlo uncertainty estimation)
2. If disagreement > 0.3: log state for nightly teacher labeling (Claude Opus API)
3. DADAgger reduces expert queries by 50–70% vs full DAgger

### 5.4 Anti-Forgetting Safeguards

1. **LoRA-only nightly updates**: Never touch base model weights during nightly loops
2. **40/20/20/20 data mix**: Always include general instruction-following
3. **CSI Safeguard**: If training loss improves >3% without proportional benchmark improvement → Goodhart violation → require human review
4. **Benchmarked checkpoints**: Evaluate on held-out set before committing; if success rate drops, rollback
5. **Monthly base merge**: Fuse adapter into base, retrain fresh adapters to prevent drift

---

## TRAINING DATA ANTI-PATTERNS — WHAT MAKES MODELS SLUGGISH

These are the validated failure modes that produce "heavy," "inaccurate," or "sluggish" 1B agents:

1. **Token-level imbalance**: CoT reasoning tokens dominate concise function-call tokens during SFT. Model learns to generate plausible reasoning but imprecise tool calls. Fix: SSB loss reweighting.

2. **Tool sequence pattern overfitting**: Tool definitions appear in consistent order. Model memorizes positions instead of semantic matching. Fix: randomize tool list order in every example.

3. **No negative examples**: Model calls tools for everything including casual conversation. Fix: 10% irrelevance-augmented data (Hammer pattern).

4. **Cross-file blindness in app training**: Training on individual Swift files without dependency context. Model names elements but can't predict downstream effects. Fix: CGM code graph or Xcode symbol graph.

5. **AX tree stale reads**: macapptree returns cached states for partially rendered windows. Fix: 150ms sleep after navigation actions before get_tree().

6. **Hard distribution cutoffs**: Abrupt data mixture changes between training stages destroy previously learned capabilities. Fix: gradual transitions.

7. **Homogeneous tool schemas**: Training only on your AXPress schema. Model fails on novel API patterns. Fix: include 3,000+ diverse APIs from xLAM-function-calling-60k.

8. **Version drift without adapter updates**: App ships UI change, adapter not regenerated. Model confidently emits stale selectors. Fix: mandatory Xcode post-build adapter generation.

---

## MASTER TRAINING SCHEDULE

| Week | Activity | Output |
|------|----------|--------|
| 1 | MOHAWK Stage 1–3 distillation from Llama 3.2 1B. WSD scheduler. BF16. | `mohawk_nano_base` (1B hybrid) |
| 2 | Build Epistemos code graph (CGM). Generate AX atlas + differential snapshots. Xcode symbol graph extraction. | `app_code_graph.json`, `app_atlas_differential.jsonl`, `app_symbol_qa.jsonl` |
| 3 | Generate 50K general macOS traces via Evol-Instruct + AgentTrek. Generate 1,000 Epistemos-specific trajectories via Claude Sonnet. | `axpress_general.jsonl`, `app_sft_trajectories.jsonl` |
| 4 | Superfilter all data (IFD). CAMPUS curriculum sort. Compose data mix (40/20/20/20). SFT via mlx_lm.lora. | `nano_axpress_v1.lora` |
| 5 | GRPO with 6-component decomposed reward. RC-GRPO for multi-turn. | Policy-improved adapter |
| 6 | RLAIF on Epistemos-specific trajectories (464 verification pairs). | App-aware improved adapter |
| 7 | Constrained decoding integration (Outlines + AXPress schema). End-to-end eval. | Production-ready model |
| 8+ | Nightly flywheel live. Version-triggered adapter regeneration. Monthly base merge. | Continuously improving |

---

## CLAUDE CODE BEST PRACTICES — NON-NEGOTIABLE

### When Upgrading Training Material:

1. **Always ground on all three pillars simultaneously.** Never optimize general device control at the expense of app-specific reflexes, or vice versa.

2. **The 20% Epistemos data allocation is sacred.** It ensures the model knows its own app. Below 15% and reflexive knowledge degrades. Above 25% and general macOS capability suffers.

3. **Regenerate app adapter on every build.** This is not a suggestion. It's a build step. Stale adapters are the #1 source of "the model used to work but now it doesn't."

4. **Test on BOTH benchmarks.** Every training change must pass the general macOS holdout (100 tasks) AND the Epistemos-specific holdout (50 tasks). If either degrades, reject.

5. **LoRA rank 16 for the nano model.** Not 8 (too constrained for structured output at 1B), not 32 (overfits with nightly data volumes). Target all linear layers per QLoRA paper finding.

6. **Deploy on MLX/GPU, not ANE.** Selective scan cannot run on ANE. Don't waste time trying.

7. **Use WSD scheduler, never cosine.** WSD allows checkpoint reuse when new data arrives. Cosine decay is terminal.

8. **Modify one variable at a time.** If you change LR schedule AND data mix AND LoRA rank and see +2% on BFCL, you've learned nothing. Run single-variable experiments.

9. **The code graph is the app's nervous system.** When Epistemos is the frontmost app, the CGM adapter should always be active alongside the AXPress adapter. Stack them.

10. **Monitor entropy during GRPO.** If it monotonically decreases, the model is collapsing. Stop, increase temperature, adjust difficulty calibration.

---

## VERIFICATION COMMANDS — RUN AFTER EVERY CHANGE

```bash
# After any training data modification
python superfilter_axpress.py && echo "IFD scoring complete"
python multi_scale_data_splitter.py && echo "Tier split complete"

# After any adapter training
python -m mlx_lm.lora --test --model mohawk_nano_base --adapter-path adapters/nano_latest
python eval_bfcl_holdout.py --adapter adapters/nano_latest && echo "General eval"
python eval_epistemos_holdout.py --adapter adapters/nano_latest && echo "App-specific eval"

# After any Epistemos UI change
python build_app_code_graph.py --source ~/Epistemos/Sources
python ax_differential_atlas.py --app Epistemos
python xcode_symbols_to_qa.py --project ~/Epistemos/Epistemos.xcodeproj

# Nightly flywheel health check
cat ~/axpress_logs/flywheel_$(date +%Y%m%d).log | tail -20
mlflow ui --port 5001  # inspect training curves
```

---

## THE COMPETITIVE MOAT — WHY THIS COMBINATION IS UNBEATABLE

No cloud model can replicate what this pipeline produces:

1. **It knows Epistemos from the inside** — not from documentation, not from screenshots, but from the actual code graph, symbol relationships, and state transitions baked into weights.

2. **It gets better every night** — the ODIA flywheel continuously improves on the user's actual usage patterns, not synthetic benchmarks.

3. **It runs entirely on-device** — zero cloud dependency, zero per-query cost, zero latency from network round-trips.

4. **It adapts to app updates instantly** — Doc-to-LoRA generates a fresh adapter in <1 second when the app ships a new version. No retraining required.

5. **It maintains general macOS competence** — the 40/20/20/20 data mix prevents overfitting to Epistemos while the CGM adapter provides deep app knowledge when needed.

This is not a better AI assistant. This is a **cognitive partner that understands its own body.**

---

*Version 2.0 · March 25, 2026*
*Synthesized from: Implementation Guide, North Star, Paradigm Paper, Niche Scripts Playbook, App-Specific Training Report, and March 2026 research update.*
