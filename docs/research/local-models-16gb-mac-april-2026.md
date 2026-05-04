# Local LLMs for 16GB Apple Silicon Macs — April 2026

> **Index status**: CANONICAL-RESEARCH — Hermes integration research (Phase D + K reference).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/hermes_research/`.



Deep research on best local models for Epistemos running on a 16GB unified-memory Mac.
Focus: research, note analysis, summarization, plus fast/thinking/SSM variants and Apple-native options.

## Memory budget reality check

macOS (Tahoe 26) + Xcode + browsers + Epistemos typically consume 4–6 GB before you load a model. The GPU wiring budget caps at ~75% of total RAM by default (`iogpu.wired_limit_mb`), so on a 16 GB Mac you have roughly **10–11 GB** for weights, KV cache, and inference scratch. At long context, KV cache grows linearly — an 8B transformer at 8K ctx costs ~1.5–2 GB on top of weights. That means **a 4-bit 8B is the realistic ceiling** for comfortable daily use, and **7B at 4-bit is the sweet spot**. Anything 12B+ will thrash unless you're very disciplined about context length and close everything else.

---

## Tier 1 — Daily drivers for 16GB

### 1. Qwen3-8B-MLX-4bit (Qwen3, Apache 2.0)
- **Params:** 8.2B (6.95B non-embedding), 36 layers, GQA (32Q/8KV)
- **Weights on disk:** **4.35 GB** (native 4-bit MLX)
- **Memory in use:** ~5–6 GB weights + 1–2 GB KV at 8K ctx → fits comfortably
- **Context:** 32,768 native, 131,072 with YaRN
- **Speed:** ~25–40 tok/s on M2/M3 base, ~50–70 tok/s on M3 Pro/M4; faster than llama.cpp by 20–30% at this size
- **Strengths:** Best-in-class 8B reasoning as of Q2 2026. Dual-mode: `/think` turns on chain-of-thought, `/no_think` gives fast direct answers — ideal for Epistemos because the **same checkpoint covers both your fast path and thinking path**. Very strong instruction following, solid at structured output/tool use, strong on STEM and coding.
- **Weaknesses:** Thinking mode requires temp=0.6 / top-p 0.95; greedy decoding causes pathological repetition. YaRN scaling beyond 32K degrades quality noticeably.
- **Source:** `Qwen/Qwen3-8B-MLX-4bit` on HuggingFace (official Qwen MLX build; `mlx-lm ≥ 0.25.2` required).

### 2. Qwen3-4B-Instruct-2507-MLX-4bit (Qwen3, Apache 2.0)
- **Params:** 4B
- **Weights:** **2.26 GB**
- **Memory in use:** ~3 GB + KV — lots of headroom for context
- **Speed:** ~55–90 tok/s on M2/M3
- **Strengths:** The "2507" refresh closed most of the quality gap between Qwen3-4B and Qwen3-8B for non-reasoning tasks. With 2–3× the memory headroom of the 8B, you can push context to 32K+ for long-document note analysis without paging.
- **Weaknesses:** Still weaker than 8B on multi-hop reasoning and code. Use the 8B when you need depth.
- **Source:** `lmstudio-community/Qwen3-4B-Instruct-2507-MLX-4bit` and `mlx-community/Qwen3-4B-Instruct-2507-4bit`.

### 3. Mistral-7B-Instruct-v0.3 or Mistral-Nemo-Instruct-2407-4bit (Apache 2.0)
- **Params:** 7.2B / 12.2B (Nemo)
- **Weights (7B 4-bit):** ~4.0–4.5 GB; **Nemo 12B 4-bit ~6.5–7 GB** (tight but viable on 16GB if you close other apps)
- **Speed:** 7B at 40–60 tok/s on M2/M3
- **Strengths:** Boring, rock-solid, well-behaved prose. Excellent for plain summarization and note rewriting. Nemo extends context to 128K at 12B — the only ~12B that runs livably on 16GB, but only with short actual prompts.
- **Weaknesses:** Mistral 7B trails Qwen3-8B on reasoning and code by a lot in 2026. Use Mistral if you want polished writing, not if you want smart.
- **Source:** `mlx-community/Mistral-7B-Instruct-v0.3-4bit`, `mlx-community/Mistral-Nemo-Instruct-2407-4bit`.

### 4. Hermes-3-Llama-3.1-8B (Llama 3.1 Community License)
- **Params:** 8B
- **Weights (4-bit MLX):** ~4.8 GB (8-bit variant is ~8.5 GB — avoid on 16GB)
- **Strengths:** NousResearch's flagship. Strong agentic/tool-use training, clean XML and JSON outputs, notably better roleplay and multi-turn coherence than raw Llama 3.1. **Particularly relevant to Epistemos** given the NousResearch references in the user's memory and hermes-agent integration — this is the same family as your Python orchestrator.
- **Weaknesses:** Bound by Llama 3.1's ceiling — now beaten by Qwen3-8B on most public benchmarks. Llama license is more restrictive than Apache 2.0.
- **Source:** `mlx-community/Hermes-3-Llama-3.1-8B-4bit` and `-8bit`.

---

## Tier 2 — Specialized thinking / reasoning

### 5. Qwen3-4B-Thinking-2507-MLX-4bit (Apache 2.0)
- **Params:** 4B
- **Weights:** **2.26 GB**
- **Strengths:** This is the **sweet-spot reasoning model for 16GB**. It's the July 2025 thinking-track refresh — trained specifically for `<think>` traces. On math/logic benches it punches above its weight class and leaves plenty of room for long CoT chains in KV cache. Runs comfortably at 32K ctx on 16GB.
- **Weaknesses:** Thinking adds 3–10× latency vs instruct — plan for 30–90 sec responses on hard prompts. Mode-specific sampling (temp 0.6) matters.
- **Source:** `mlx-community/Qwen3-4B-Thinking-2507-4bit` and `lmstudio-community/Qwen3-4B-Thinking-2507-MLX-4bit`.

### 6. DeepSeek-R1-Distill-Qwen-7B (MIT, distill base is Qwen Apache 2.0)
- **Params:** 7B (distilled from R1 into Qwen2.5-Math-7B)
- **Weights (4-bit MLX):** ~4.5 GB; fits with ~9 GB total runtime footprint
- **Speed:** ~15–25 tok/s on M-series during reasoning passes
- **Strengths:** Much stronger math and multi-step reasoning than vanilla Qwen2.5-7B. Famously good at self-correction via long chains of thought. Practical on 16GB without drama.
- **Weaknesses:** Base is Qwen-Math-7B, so general chat quality is uneven — it's noticeably worse than Qwen3-4B-Thinking at everyday writing. Thinks at length even for simple questions; cap `max_tokens` aggressively.
- **Source:** `mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit`.

### 7. Phi-4-mini-reasoning-MLX-4bit (MIT)
- **Params:** ~3.8B (not 0.6B as the card erroneously lists — that's a metadata bug)
- **Weights:** **2.16 GB**
- **Strengths:** Microsoft's reasoning-tuned mini. Very fast, very small, surprisingly competitive on math benches given the size. Good fit for Epistemos' background triage/classification path where you need a reasoner that can answer in <1 sec.
- **Weaknesses:** Narrower world knowledge than Qwen3-4B; weaker on creative writing and long-form synthesis. The 14B full Phi-4 is too big for 16GB (~8 GB weights + KV puts you over).
- **Source:** `lmstudio-community/Phi-4-mini-reasoning-MLX-4bit` and `mlx-community/Phi-4-mini-reasoning-4bit`.

### 8. QwQ-32B — **NOT recommended on 16GB**
Even at 4-bit, QwQ is 18–20 GB of weights plus KV. Users explicitly report it needs 32 GB+ unified memory. Included here only as a reference for "don't try this." If a 32GB Mac is in the future, it's the best reasoner that fits.

---

## Tier 3 — Fast lightweight (iMessage routing, quick summaries, classifiers)

### 9. Llama-3.2-3B-Instruct-4bit (Llama 3.2 Community License)
- **Params:** 3.2B
- **Weights:** ~1.8–2.0 GB
- **Speed:** 80–120 tok/s on M2/M3; public benches have M4 Max at **1,100+ tok/s** throughput on this model
- **Strengths:** Extremely fast. Meta's instruction tuning is clean, good at formatting, reliable for triage and short-answer tasks. Great candidate for the "was this chat worth routing to a bigger model?" gate in `ConfidenceRouter`.
- **Weaknesses:** Knowledge ceiling is clearly 3B-shaped — it hallucinates more than Qwen3-4B. Writing is flatter. No thinking mode.
- **Source:** `mlx-community/Llama-3.2-3B-Instruct-4bit`.

### 10. Llama-3.2-1B-Instruct-4bit (Llama 3.2 Community License)
- **Params:** 1.2B, **weights ~700 MB**
- **Speed:** 150–250 tok/s on M2/M3
- **Strengths:** Essentially free to run. Perfect for classification, regex-worthy string tasks, "detect topic change," "extract entities from message."
- **Weaknesses:** Will confabulate on anything beyond the simplest prompt; not a summarizer.
- **Source:** `mlx-community/Llama-3.2-1B-Instruct-4bit`.

### 11. SmolLM2-1.7B-Instruct-MLX-4bit (Apache 2.0)
- **Params:** 1.7B, weights ~1 GB
- **Strengths:** HuggingFace's purpose-built small model, explicitly trained for on-device assistants. Stronger than Llama 3.2 1B at instruction following for structured tasks, and faster than 3B models. Great iMessage/notification-summary target.
- **Weaknesses:** Weaker tool calling than SmolLM3; world knowledge noticeably thinner than Qwen3-4B.
- **Source:** `mlx-community/SmolLM2-1.7B-Instruct-4bit`.

---

## Tier 4 — Experimental (SSM / hybrid)

### 12. Falcon-H1-1.5B-Instruct-4bit (TII, Apache 2.0-style)
- **Params:** 1.5B, weights ~900 MB
- **Architecture:** Hybrid attention + Mamba-2 heads *in parallel* within a single mixer block
- **Strengths:** Strong reasoning-per-parameter thanks to the hybrid mixer; inference-memory stays flat as context grows (the Mamba side has fixed state). Fits 16GB with room to spare.
- **Weaknesses:** Smaller ecosystem; tool-calling support is immature. `mlx-lm` had output-garbage bugs (issue #504) that were fixed but watch version compatibility.
- **Source:** `tiiuae/Falcon-H1-1.5B-Instruct` and `mlx-community/Falcon-H1-1.5B-Instruct-4bit`.

### 13. Falcon-H1R-7B-6bit (TII)
- **Params:** 7B hybrid (Mamba-2 + attention)
- **Weights:** ~5.5 GB at 6-bit. There's also a 4-bit build that lands ~4 GB.
- **Strengths:** Jan 2026 reasoning-tuned hybrid. Claims to out-reason transformer models 7× its size; reasoning throughput benefits from the SSM component at long CoT. Most promising "real" SSM-hybrid that fits 16GB.
- **Weaknesses:** KV-cache tooling assumptions in mlx-lm are still catching up; some runners assume pure-transformer cache.
- **Source:** `mlx-community/Falcon-H1R-7B-6bit` (check for a 4-bit variant).

### 14. AI21-Jamba-Reasoning-3B-4bit (Apache 2.0)
- **Params:** 3B hybrid Mamba/Transformer (Jamba architecture)
- **Weights:** **1.74 GB**
- **Strengths:** Genuine Jamba hybrid in a tiny form factor. Proves the architecture on MLX — AI21's reasoning tune. Excellent test case for "SSM viability" in Epistemos' cognitive architecture trajectory.
- **Weaknesses:** Low downloads so far (~58/mo), bleeding edge. BatchMambaCache is specific to certain runners; MLX Studio supports it, plain mlx-lm may or may not depending on version.
- **Source:** `mlx-community/AI21-Jamba-Reasoning-3B-4bit`.

### 15. RWKV-7 "Goose" (Apache 2.0) — **note of caution**
- RWKV-7 is the current frontier of attention-free models and has solid 1.5B and 3B checkpoints, but there is **no first-party MLX build** as of April 2026. You'd go through llama.cpp GGUF (which has working RWKV support) or a community PyTorch-MPS path. Not recommended as a daily driver on an MLX-first pipeline, but worth watching. No evidence of a production MLX port yet.

### 16. Mamba-2 / Zamba-2 pure SSMs
- `mamba.py_mlx` exists as a research implementation. There is **no production-ready pure-SSM MLX runtime** for mlx-lm. Treat pure Mamba/Mamba-2 as research-only on MLX today. Hybrid variants (Jamba, Falcon-H1) are the practical path.
- **Hymba** is research code out of NVIDIA — no MLX port.

---

## Tier 5 — Apple-specific

### 17. Apple Foundation Models framework (on-device LLM)
- **Params:** ~3B (Apple's on-device model shipped inside Apple Intelligence, exposed via the **Foundation Models framework** as of macOS 26 / WWDC 2025)
- **Memory:** Zero *added* cost — it's already resident when Apple Intelligence is enabled, and the OS pages it in/out
- **Access:** Pure Swift API (`FoundationModels` framework) with the `@Generable` macro for constrained structured output. Free, offline, private.
- **Strengths for Epistemos:** This is the **single best fit for many tasks**. For summarization, entity extraction, short rewrite, and structured outputs, it requires literally no model-management code — zero download, zero GB used from your own budget. Guided generation via `@Generable` gives you rich Swift structs back without JSON parsing. Epistemos already targets macOS 26 — wire it in behind a `SystemLanguageModel.availability` check.
- **Weaknesses:** Fixed at ~3B — no deep reasoning, no long context, no code generation, no tool use. Cannot stream thinking blocks (it doesn't have them). Only available on Apple Intelligence-compatible hardware with the feature enabled. Adapter support is limited.
- **Source:** `developer.apple.com/documentation/FoundationModels`, WWDC 2025 sessions 286 and 301.
- **Verdict:** Use it as a *first-choice fast path* for summarization and entity extraction when available. Fall back to Qwen3-4B for richer tasks.

### 18. Apple OpenELM (270M / 450M / 1.1B / 3B — Apple Sample Code License, some variants permissive)
- Weights tiny (OpenELM-3B 4-bit is ~1.6–1.8 GB)
- **Strengths:** Fully open training recipe, MLX-native reference implementation, Apple's own layer-wise parameter allocation. Excellent for experiments and education.
- **Weaknesses:** Quality is **meaningfully below** Llama-3.2-3B and Qwen3-4B on every public benchmark. It's a research artifact, not a daily driver.
- **Verdict:** Include as a "learning" curiosity or for fine-tuning experiments; don't ship as the default.

### 19. Apple DCLM-7B / DCLM-1B (Apple Sample Code License)
- **Params:** 7B / 1B
- **Strengths:** Demonstrates the DataComp-LM pretraining recipe. 7B is competitive with Mistral 7B on zero-shot benches.
- **Weaknesses:** **Base models only — not instruction-tuned**, not chat-formatted, no tool use. Not a drop-in for user-facing features. Great substrate for community finetunes, but don't use DCLM-7B-base as a chat model.

### 20. Apple FastVLM (CVPR 2025, MLX iOS/macOS demo)
- Vision-language model; not relevant to the research/summarization text-only task, but worth logging because Epistemos has a ScreenCaptureKit path. FastVLM's smallest variant has 85× faster Time-to-First-Token than LLaVA-OneVision-0.5B. If Epistemos ever wants fast local screen-understanding, this is the Apple-native choice.

---

## Why Gemma is hard on 16 GB (and whether Gemma 3 is viable)

### What happens architecturally
Gemma 2 and Gemma 3 both use **interleaved sliding-window attention (SWA) + periodic global attention**. Gemma 3 ships a **5:1 local-to-global ratio** (Gemma 2 was 1:1), with the last layer always global. On paper this should *reduce* KV-cache pressure. In practice three things bite:

1. **Large embedding / FFN widths.** Gemma models have unusually wide hidden dims and non-standard vocab sizes. Gemma 3 12B at Q4_K_M is ~7–7.5 GB of weights *before* KV cache. At 8K context with even the reduced-SWA cache, you cross the 10 GB practical ceiling on a 16GB Mac. Users report it "fills system RAM and eventually exhausts all memory and crashes" (Ollama issue #9791).
2. **Sliding-window implementation bugs.** llama.cpp shipped a Gemma 3 SWA fix in early 2026 (bartowski noted the fix in `lmstudio` runtime 1.120.0). Before that fix, long-context outputs degraded badly. MLX's implementation of interleaved SWA was initially less optimized than dense attention — the community 4-bit quants of Gemma 4 were outright reported broken in April 2026 (Ollama issue #15368), and that's the same code path as Gemma 3.
3. **QAT and tensor-type mismatches.** Gemma 3 ships QAT-trained (`-qat-4bit`) variants which expect specific dequantization paths; mixing these with generic mlx-lm converters occasionally produces garbled outputs.

### What currently works on 16 GB
- **Gemma-3-1B-it-4bit** — ~700 MB weights, fast, fine for trivial tasks. No real reasoning.
- **Gemma-3-4B-it-4bit** or **-qat-4bit** — 3.0 GB on disk. Works, ~7 GB runtime at 4K ctx. Multimodal via `mlx-vlm`. This is the **sensible Gemma to actually ship** on 16 GB.
- **Gemma-3n-E2B-it / E4B-it** — uses MatFormer (nested Matryoshka Transformer) + **Per-Layer Embeddings (PLE)** that **offload embedding weights to CPU RAM**, designed for edge devices. On a 16 GB Mac, E4B is the largest Gemma that fits with any headroom, and it was designed for this exact constraint. `mlx-lm` support caught up in early 2026.
- **Gemma 3 12B and Gemma 3 27B** — do not try on 16 GB. The 12B memory-leak crash under Ollama's MLX preview is well-documented. If you must, use llama.cpp with `mmap` paging from SSD and accept severe slowdowns.

### Concrete advice for making Gemma 3 work on 16 GB
1. **Pick Gemma-3-4B-it-qat-4bit or Gemma-3n-E4B-it-4bit.** Nothing bigger.
2. **Pin mlx-lm to a recent version** (≥ 0.26) and llama.cpp to a build after the March 2026 SWA fix.
3. **Cap context at 4K during initial integration**; raise to 8K only once verified no OOM over a long session.
4. **Disable Apple Intelligence on the same machine if you see memory pressure**; it holds its own 3B resident.
5. **Pass a chat template manually** for 3n models — the automatic apply_chat_template is flaky on some versions.
6. **Don't use Gemma for deep reasoning on 16 GB.** Use Qwen3-4B-Thinking for that. Use Gemma-3n-E4B for its multilingual breadth and vision (multimodal).

---

## Top 5 picks for this user

1. **Qwen3-8B-MLX-4bit** — The single best all-round local model that fits 16 GB; native `/think` + `/no_think` switching maps directly to Epistemos' fast/thinking/research capability gating.
2. **Qwen3-4B-Thinking-2507-4bit** — The reasoning workhorse that leaves room for long CoT traces; only 2.26 GB on disk so it coexists with other models in the cache.
3. **Llama-3.2-3B-Instruct-4bit** — The triage/classifier/iMessage-router at 80–120 tok/s; perfect fit for `ConfidenceRouter`.
4. **Apple Foundation Models (on-device, via `FoundationModels` framework)** — Free "0 GB" summarization and entity extraction on macOS 26 with `@Generable` structured output; the right default fast-path when Apple Intelligence is enabled.
5. **Falcon-H1R-7B-4bit (or AI21-Jamba-Reasoning-3B-4bit for lower risk)** — The SSM/hybrid experiment slot: genuine Mamba-2 + attention hybrid that fits 16 GB and lets you validate the architecture trajectory noted in project memory.

Keep Bonsai and the existing Qwen build. Add the five above and the coverage is: daily driver, reasoning, fast triage, free-with-OS, and experimental SSM — exactly the five use classes described.

---

## Sources

- [Best Local LLMs for Mac in 2026 — InsiderLLM](https://insiderllm.com/guides/best-local-llms-mac-2026/)
- [Best Local LLMs to Run On Every Apple Silicon Mac in 2026 — apxml](https://apxml.com/posts/best-local-llms-apple-silicon-mac)
- [What to Buy for Local LLMs (April 2026) — Julien Simon, Medium](https://julsimon.medium.com/what-to-buy-for-local-llms-april-2026-a4946a381a6a)
- [Your Mac's RAM is its GPU — SolidAITech](https://www.solidaitech.com/2026/04/mac-ram-requirements-local-llms-apple-silicon.html)
- [Ollama is now powered by MLX on Apple Silicon — Ollama Blog](https://ollama.com/blog/mlx)
- [Qwen3: Think Deeper, Act Faster — QwenLM](https://qwenlm.github.io/blog/qwen3/)
- [Qwen/Qwen3-8B-MLX-4bit — HuggingFace](https://huggingface.co/Qwen/Qwen3-8B-MLX-4bit)
- [lmstudio-community/Qwen3-8B-MLX-4bit — HuggingFace](https://huggingface.co/lmstudio-community/Qwen3-8B-MLX-4bit)
- [mlx-community/Qwen3-4B-Thinking-2507-4bit — HuggingFace](https://huggingface.co/mlx-community/Qwen3-4B-Thinking-2507-4bit)
- [lmstudio-community/Qwen3-4B-Thinking-2507-MLX-4bit — HuggingFace](https://huggingface.co/lmstudio-community/Qwen3-4B-Thinking-2507-MLX-4bit)
- [mlx-community/Qwen3-4B-Instruct-2507-4bit — HuggingFace](https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit)
- [DeepSeek-R1 Distill on Apple Silicon — Private LLM](https://privatellm.app/blog/deepseek-r1-distill-now-available-private-llm-ios-macos)
- [deepseek-ai/DeepSeek-R1-Distill-Qwen-7B — HuggingFace](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B)
- [lmstudio-community/Phi-4-mini-reasoning-MLX-4bit — HuggingFace](https://huggingface.co/lmstudio-community/Phi-4-mini-reasoning-MLX-4bit)
- [Welcome Gemma 3 — HuggingFace blog](https://huggingface.co/blog/gemma3)
- [Gemma 3 Technical Report — arXiv](https://arxiv.org/html/2503.19786v1)
- [mlx-community/gemma-3-4b-it-qat-4bit — HuggingFace](https://huggingface.co/mlx-community/gemma-3-4b-it-qat-4bit)
- [Gemma 3 12B Q4_K_M memory exhaustion — Ollama issue #10341](https://github.com/ollama/ollama/issues/10341)
- [Out of memory errors when running gemma3 — Ollama issue #9791](https://github.com/ollama/ollama/issues/9791)
- [Gemma 4 on Apple Silicon M5 Max — Ollama issue #15368](https://github.com/ollama/ollama/issues/15368)
- [Introducing Gemma 3n: Developer Guide — Google Developers Blog](https://developers.googleblog.com/en/introducing-gemma-3n-developer-guide/)
- [Understanding MatFormer in Gemma 3n — HuggingFace blog](https://huggingface.co/blog/rishiraj/matformer-in-gemma-3n)
- [Apple Foundation Models — Apple Newsroom](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/)
- [Updates to Apple's On-Device Foundation Language Models — Apple ML Research](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)
- [Foundation Models framework — Apple Developer Documentation](https://developer.apple.com/documentation/FoundationModels)
- [Meet the Foundation Models framework — WWDC25 session 286](https://developer.apple.com/videos/play/wwdc2025/286/)
- [Deep dive into the Foundation Models framework — WWDC25 session 301](https://developer.apple.com/videos/play/wwdc2025/301/)
- [OpenELM — Apple ML Research](https://machinelearning.apple.com/research/openelm)
- [apple/DCLM-7B — HuggingFace](https://huggingface.co/apple/DCLM-7B)
- [Welcome Falcon Mamba — HuggingFace blog](https://huggingface.co/blog/falconmamba)
- [Falcon-H1R 7B — Falcon LLM](https://falcon-lm.github.io/blog/falcon-h1r-7b/)
- [mlx-community/Falcon-H1R-7B-6bit — HuggingFace](https://huggingface.co/mlx-community/Falcon-H1R-7B-6bit)
- [mlx-community/AI21-Jamba-Reasoning-3B-4bit — HuggingFace](https://huggingface.co/mlx-community/AI21-Jamba-Reasoning-3B-4bit)
- [mlx-community/Hermes-3-Llama-3.1-8B-8bit — HuggingFace](https://huggingface.co/mlx-community/Hermes-3-Llama-3.1-8B-8bit)
- [NousResearch/Hermes-3-Llama-3.1-8B — HuggingFace](https://huggingface.co/NousResearch/Hermes-3-Llama-3.1-8B)
- [Production-Grade Local LLM Inference on Apple Silicon — arXiv 2511.05502](https://arxiv.org/abs/2511.05502)
- [MLX-LM GitHub — ml-explore](https://github.com/ml-explore/mlx-lm)
