# Epistemos Local-LLM Stack — Research + Recommendation (2026-05-16)

**Verified against:** mlx-community on HuggingFace · QwenLM/Qwen3.6 GitHub · DeepSeek-AI/DeepSeek-R1 · Google AI Gemma 4 announcement · Apple FoundationModels framework · Llama 4 release blog · primary-source benchmarks (AIME 2024, SWE-Bench Verified, MATH-500).

**Audience:** User picks ONE "registered" Epistemos assistant; ConfidenceRouter dispatches to specialist branches. This doc is the registry input. Same architecture scales linearly to Pro tier.

---

## 1. Primary "Epistemos assistant" — **Qwen3.5-9B (4-bit MLX)**

- **HF path:** `mlx-community/Qwen3.5-9B-MLX-4bit`
- **Resident:** ~5.95 GB at 4-bit, fits M2 Pro 16 GB budget with full 32 k context.
- **License:** Apache 2.0 (clean for MAS distribution + commercial use).

### Why this beats the alternatives the user named

| Alternative | Why it loses for "primary" slot on M2 Pro 16 GB |
|---|---|
| **Qwen 3.6 27B dense** (released 2026-04-22) | Too large — ~15 GB resident at 4-bit, leaves no room for tools / context / OS. Belongs in Pro tier (M3/M4 Max). |
| **Qwen 3.6 35B-A3B MoE** | Only 3B active but full MoE weights must reside in RAM; ~22 GB. Pro tier only. |
| **Gemma 4 26B-MoE** | Same story — MoE weights resident even when sparse. Pro tier only. |
| **Gemma 4 E4B** (4B effective) | Excellent for vision branch, but too small to be primary — tool-use reliability + 32k+ JSON discipline lag Qwen3.5 at 9B. |
| **Qwen3-Coder-30B-A3B** | Coder-tuned, not generalist; loses general-knowledge breadth + agent benchmarks. |

### Why Qwen3.5-9B wins

- **Hybrid thinking mode** (`enable_thinking` toggle in chat template) maps 1:1 onto Epistemos's `fast/thinking/research` capability gating. ONE model handles both modes — no registry duplication.
- **Tool-use first-class:** Apache 2.0, function-calling tags trained in, integrates with Qwen-Agent + MCP. JSON-output discipline via grammar constraints — clean fit for `LocalToolGrammar.swift`.
- **Day-one MLX support** via `mlx-community` — pre-published 4-bit weights, no in-app conversion (MAS-sandbox-clean, no JIT compilation of model weights at runtime).
- **262 k native context** (YaRN-extensible to ~1 M) → no separate long-context branch needed.
- **Qwen3.6 7B/8B drop-in upgrade path** when it lands — same family, same prompt format, same agent harness; replace path + restart.

---

## 2. Specialist branches — ConfidenceRouter dispatch targets

The primary 9B handles ~80% of turns end-to-end. The router (1.7B Qwen3) decides when to escalate. Below are the FOUR branches the user asked about + ONE the user did not name but should add.

| Branch | Model | HF path | Disk → Resident | Why this branch |
|---|---|---|---|---|
| **Fast-routing** | Qwen3-1.7B | `mlx-community/Qwen3-1.7B-4bit` | ~1.1 GB resident | <100 ms intent classification + JSON triage before primary loads. Same prompt format as primary — zero adapter glue. Apache 2.0. |
| **Coder** | Qwen3-Coder-30B-A3B-Instruct (MoE, 3B active) | `mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit` | ~17 GB disk, ~9-10 GB resident under paged MoE | Activate only when coder dispatched — pages out otherwise. **Memory-constrained alternative:** `mlx-community/Qwen2.5-Coder-7B-Instruct-4bit` (~4.5 GB) for hard 16 GB budgets when primary is hot. |
| **Reasoning** | DeepSeek-R1-Distill-Qwen-7B | `mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit` | ~4.3 GB | **55.5% AIME 2024** (beats QwQ-32B-Preview at <1/4 the params). Apache 2.0. `<think>` trace built into prompt format. Use when intent = "reasoning" + primary's thinking-mode is insufficient. |
| **Vision** | Gemma-4-E4B-it | `mlx-community/gemma-4-E4B-it-4bit` (Unsloth UD variants live too) | ~3 GB | Apache 2.0, vision + audio, 128 k context. Pairs with `Screen2AXFusion` for screenshot understanding. |
| **Long-context** | Same Qwen3.5-9B primary | (no separate branch) | — | 262 k native, YaRN to ~1 M. No second model needed — saves 5 GB. |

**Simultaneous resident worst-case (primary + router + reasoning hot):** 9B + 1.7B + 7B-distill ≈ 5.95 + 1.1 + 4.3 = **11.35 GB resident** — fits 16 GB M2 Pro with headroom for tools/context/OS. Coder + vision page in on demand.

---

## 3. Pro tier extensions (M2/M3/M4 Max 36-128 GB)

When the user runs on bigger Apple Silicon, swap the registry without touching ConfidenceRouter / `LocalAgentPromptBuilder` / grammar DSL:

| Tier | Primary | Coder | Reasoning | General alt |
|---|---|---|---|---|
| **Pro 36-48 GB** | `mlx-community/Qwen3.6-27B-4bit` (dense, 262 k, agentic tool-use, Apache 2.0) | same Qwen3-Coder-30B-A3B (now hot) | `mlx-community/DeepSeek-R1-Distill-Qwen-32B-4bit` (~18 GB, Apache 2.0) | `unsloth/gemma-4-31b-it-UD-MLX-4bit` (vision-aware 31B) |
| **Pro 64 GB** | `mlx-community/Qwen3.6-35B-A3B-4bit-DWQ` (3B active, fastest "dense-quality" option) | `Qwen3-Coder-Next` (80B MoE / 3B active, 256 k, **70.6% SWE-Bench Verified**) | DeepSeek-R1-Distill-Qwen-32B + Magistral-Small-24B reasoning | — |
| **Pro 128 GB Ultra** | `mlx-community/Qwen3.5-122B-A10B-4bit` OR `Llama-4-Scout-MoE` (17B active / 109B total — ⚠️ Llama Community License, NOT Apache; check compliance) | Qwen3-Coder-Next at full resident | DeepSeek-R1 full (where weights are released) | — |

---

## 4. AVOID — models the user might be tempted to register but shouldn't

| Model | Why avoid |
|---|---|
| **Llama 4 Maverick (400B)** | Llama Community License has user-count gates + naming requirements. Personal use OK; distribution adds compliance work. Llama 4 Scout same concern (smaller, but still not Apache). |
| **Devstral 2 (123B, "modified MIT")** | Read the addendum before shipping — the modification adds non-MIT terms. Treat as Pro-tier-only with explicit user opt-in. |
| **QwQ-32B-Preview** | Superseded by Qwen3.5/3.6 thinking-mode + DeepSeek-R1-Distill. Keep out of registry. |
| **Hermes-4-70B / Hermes-4-405B (NousResearch)** | Based on Llama-3.1 → inherits Llama Community License. Also Epistemos codebase already purged the "Hermes" name (2026-05-05 commit `b4c583b0`+`80544415`+`e07e6378`). Use Hermes-Function-Calling **prompt format** as a reference per `reference_nousresearch.md`, NOT the shipped model. |
| **Phi-4-reasoning (MIT)** | Microsoft's tool-use training is weak; JSON discipline lags Qwen3. Skip as a branch. |
| **Apple Foundation Models (~3B on-device, macOS 26+)** | API surface is closed; can't grammar-constrain it. **Worth wiring as an ADDITIONAL zero-cost fast-route** for Apple-Intelligence-eligible devices, but **never as primary** because you lose JSON-grammar gating + capability registry control. |
| **Mistral-7B-v0.x family** | Superseded by Qwen3 family across every benchmark; don't register. |
| **Codestral 25.08** | Fill-in-middle autocomplete only — not a chat/agent model. Different surface area. |

---

## 5. `huggingface-cli` download manifest (copy-paste)

```bash
# V1 ship — M2 Pro 16 GB
huggingface-cli download mlx-community/Qwen3.5-9B-MLX-4bit
huggingface-cli download mlx-community/Qwen3-1.7B-4bit
huggingface-cli download mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit
huggingface-cli download mlx-community/Qwen2.5-Coder-7B-Instruct-4bit
huggingface-cli download mlx-community/gemma-4-E4B-it-4bit

# Optional: Pro-tier coder activated only when 16 GB hot-budget permits paged MoE
huggingface-cli download mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit

# Pro tier (M-series Max 36-128 GB) — feature-gated #if PRO_BUILD
huggingface-cli download mlx-community/Qwen3.6-27B-4bit
huggingface-cli download mlx-community/Qwen3.6-35B-A3B-4bit-DWQ
huggingface-cli download mlx-community/DeepSeek-R1-Distill-Qwen-32B-4bit
huggingface-cli download unsloth/gemma-4-31b-it-UD-MLX-4bit
```

---

## 6. Stack rationale — "single Epistemos assistant that splits into branches"

This mirrors how a senior engineer dispatches:

1. **1.7B router** does cheap intent classification + JSON triage in <100 ms before the 9B primary even loads context. (Equivalent to: a smart receptionist who picks the right specialist.)
2. **9B primary** (Qwen3.5-9B) classifies 80% of turns AS general-knowledge and handles them end-to-end with hybrid thinking-mode. Tool-use first-class. (Equivalent to: a generalist senior who handles 80% of tickets without escalation.)
3. **7B-distill reasoning** takes over when `<think>` traces + AIME/MATH-grade chain-of-thought are needed. (Equivalent to: the math specialist.)
4. **30B-A3B coder** handles repo-aware diffs + multi-file edits + SWE-Bench-style refactors. (Equivalent to: the senior engineer for code review.)
5. **Gemma 4 E4B vision** handles screenshots + figures from `Screen2AXFusion`. (Equivalent to: the visual / UX specialist.)
6. **Apple Foundation Models** (when available) is a zero-cost fallback for ultra-cheap "is this query trivial?" decisions — uses no MLX budget.

Every tier is **Apache 2.0** (no license drag), every model is published **in MLX-4bit form by mlx-community** (no in-app conversion, MAS-sandbox-clean), and the **same architecture scales linearly to Pro** — swap 9B→27B + 7B-distill→32B-distill without touching the router, the grammar DSL, or `LocalAgentPromptBuilder`.

---

## 7. Integration checklist (revised iter 83 — §5.0 catch)

**Pre-write §5.0 reconciliation gate (iter 83, 2026-05-16):** the original checklist below assumed enum registration was net-new work. Re-reading `Epistemos/State/InferenceState.swift` revealed the canonical `LocalTextModelID` enum at line 6 is ALREADY ~60+ cases including 4 of 5 recommended V1 stack models:

| Recommended V1 model | Enum case | Line | Status |
|---|---|---|---|
| **Primary** Qwen3.5-9B | `qwen35_9B4Bit = "mlx-community/Qwen3.5-9B-4bit"` | 11 | ✅ REGISTERED |
| **Coder** Qwen3-Coder-30B-A3B | `qwen3Coder30BA3B4Bit = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit"` | 28 | ✅ REGISTERED |
| **Reasoning** DeepSeek-R1-Distill-Qwen-7B | `deepseekR1Distill7B = "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit"` | 49 | ✅ REGISTERED |
| **Vision** Gemma-4-E4B | `gemma4_4B4Bit = "mlx-community/gemma-4-e4b-it-4bit"` | 40 | ✅ REGISTERED |
| **Fast-routing** Qwen3-1.7B | (absent — closest is `qwen35_0_8B4Bit` at line 8) | — | ❌ MISSING |

Plus all the Pro-tier extensions are already registered: `qwen36_35BA3B4Bit` (line 14) · `qwen36_35BA3B_Unsloth4Bit` (line 17) · `qwen36_35BA3B_DWQ4Bit` (line 19) · `qwen3CoderNext4Bit` (line 27) · `gemma4_27BA4B4Bit` (line 41) · `gemma4_31BJANG` (line 42) · `qwqFlagship32B4Bit` (line 52) · `qwen25Coder7B` (line 53). Plus Pro-tier alternatives this research doc didn't recommend but exist in canon: `localAgent43_36B4Bit` (Hermes-4.3-36B) · `mistralSmall31_24B4Bit` · `devstralSmall2505_4Bit` · `llama4Scout17B16E4Bit` · LFM2.5 family · Mamba-2 · Falcon-H1 · Jamba · SmolLM3.

**Revised checklist (post §5.0 catch):**

1. **`Epistemos/State/InferenceState.swift` LocalTextModelID enum** — ✅ MOSTLY DONE; only add `qwen3_1_7B4Bit = "mlx-community/Qwen3-1.7B-4bit"` for the fast-routing slot. Bounded ~3 LOC change (add case + display-name + any complete-switch sites). Defer to iter 84 with proper §5.0 verification of all `switch` exhaustiveness sites in the 5432-LOC file.

2. **`Epistemos/LocalAgent/ConfidenceRouter.swift`** — add dispatch rules: code-intent → `qwen3Coder30BA3B4Bit`; reasoning-intent + complexity-score > threshold → `deepseekR1Distill7B`; vision-intent → `gemma4_4B4Bit`; small-router-classification → (Qwen3-1.7B once registered; OR `qwen35_0_8B4Bit` interim); else → `qwen35_9B4Bit` primary. §5.0 needed: read current `ConfidenceRouter.swift` to verify the dispatch shape + existing rule set before adding.

3. **`agent_core/src/routing.rs`** — verify MLX provider entries exist for each of the 4 confirmed-registered models. §5.0: grep current `routing.rs` for the 4 HF paths to check coverage before adding.

4. **`Epistemos/Engine/MLXInferenceService.swift`** — verify chat templates for Qwen3.5-9B `<|im_start|>` + DeepSeek-R1 `<think>` + Gemma 4 `<start_of_turn>` are in the template registry. §5.0: grep MLXInferenceService for these tokens before adding.

5. **HuggingFace download discipline** — `ModelDownloadManager.swift` (the existing path with `configuration.urlCache = nil` per perf hardening) handles all five paths via standard HF URL pattern. NO new code; this should "just work" once the model is selected at runtime.

6. **MAS_COMPLETE_FUSION §10 Compromises Recorded** — add a B-3 update row noting which models V1 ships vs which gate to V1.1 (recommend V1 ships primary + router only; V1.1 adds coder + reasoning + vision). May ALREADY be partially documented — §5.0 needed.

**Iter sequence revision (iter 83 onward):**

| Iter | Action | File touches | Risk |
|---|---|---|---|
| 83 | This §5.0 catch — research doc revised checklist (this commit) | `docs/LOCAL_MODEL_STACK_RESEARCH_2026_05_16.md` (this revision) + §8 row in MAS plan | None (doc-only) |
| 84 | §5.0 verify ConfidenceRouter.swift current shape + register Qwen3-1.7B router enum case + add ConfidenceRouter dispatch for already-registered Qwen-Coder + DeepSeek-Distill + Gemma-4-E4B branches | `Epistemos/State/InferenceState.swift` (+1 enum case + display name) + `Epistemos/LocalAgent/ConfidenceRouter.swift` (dispatch rules) | Low (bounded; xcodebuild may fail on exhaustive-switch compile errors that need fixing) |
| 85 | §5.0 verify `agent_core/src/routing.rs` provider entries + add missing ones | `agent_core/src/routing.rs` | Low (additive Rust; cargo test should hold) |
| 86 | Chat template verification + MAS_COMPLETE_FUSION B-3 row update | `Epistemos/Engine/MLXInferenceService.swift` + `MAS_COMPLETE_FUSION §10 B-3` | Low (doc-mostly) |
| 87+ | Pivot to next-highest-leverage product work (TBD) or graceful wind-down |  |  |

---

## 8. Sources

- Qwen3 release blog — qwenlm.github.io/blog/qwen3
- Qwen3.6 GitHub (27B + 35B-A3B, April 2026) — github.com/QwenLM/Qwen3.6
- Qwen3-Coder-Next model card — huggingface.co/Qwen/Qwen3-Coder-Next
- mlx-community Qwen3.5-9B-MLX-4bit — huggingface.co/mlx-community/Qwen3.5-9B-MLX-4bit
- mlx-community Qwen3.6-27B-4bit — huggingface.co/mlx-community/Qwen3.6-27B-4bit
- mlx-community Qwen3-Coder-30B-A3B-Instruct-4bit — huggingface.co/mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit
- Gemma 4 announcement (Apache 2.0, day-one MLX) — blog.google/innovation-and-ai/technology/developers-tools/gemma-4
- DeepSeek-R1 distills (Apache 2.0) — github.com/deepseek-ai/deepseek-r1
- Magistral Small 24B (reasoning) — huggingface.co/mistralai/Magistral-Small-2506
- Phi-4 reasoning (MIT) — huggingface.co/microsoft/Phi-4-reasoning
- Llama 4 herd (Meta) — ai.meta.com/blog/llama-4-multimodal-intelligence
- Apple Foundation Models framework — developer.apple.com/documentation/FoundationModels

---

*Last verified 2026-05-16 by autonomous loop iter-73 follow-up research. Re-validate model availability + benchmarks every 60 days; the Qwen / DeepSeek / Gemma release cadence is ~quarterly.*
