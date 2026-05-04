# Epistemos — Master Upgrade Plan
## Compiled from 641 X Bookmarks, 70+ Retweets, and Current Model Research
**Date:** March 27, 2026

---

# PART 1: NEW LOCAL MODELS TO ADD

Your current `LocalTextModelID` enum supports only **Qwen 3.5 MLX variants** (0.8B, 2B, 4B, 9B, 27B, 35B-A3B) — all 4-bit via `mlx-community`. Below are the models you bookmarked, retweeted, or that the community unanimously considers best-in-class for local use. Each entry includes the HuggingFace ID, architecture, why it matters, and RAM requirements.

---

## Tier 1: Must-Add Models (Your Bookmarks + Community Consensus)

### 1. Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2 (GGUF)
- **HuggingFace:** [`Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF`](https://huggingface.co/Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF)
- **Architecture:** Qwen3.5-27B base, SFT + LoRA fine-tuned with 14,000 Claude Opus 4.6 reasoning trajectories
- **Why:** 96.91% HumanEval pass@1 (matches base), 24% shorter chain-of-thought, +31.6% more correct solutions per token. Thinks like Claude Opus but runs locally. You bookmarked this exact model.
- **Quants Available:** 4-bit, 5-bit, 6-bit, 8-bit GGUF
- **RAM:** ~16-20GB (Q4), ~48GB (Q8)
- **Downloads:** 71,132/month — community validated
- **Source:** [Reddit thread confirming "legendary" status](https://www.reddit.com/r/LocalLLM/comments/1rz86mm/qwen3527bclaude46opusreasoningdistilled_legendary/)

### 2. Qwen3.5-28B-A3B-REAP (MoE, Expert-Pruned)
- **HuggingFace:** [`0xSero/Qwen-3.5-28B-A3B-REAP`](https://huggingface.co/0xSero/Qwen-3.5-28B-A3B-REAP)
- **Architecture:** Qwen3.5-35B-A3B with 20% experts pruned via REAP (Router-weighted Expert Activation Pruning, ICLR 2026). 256 → 205 experts remaining. ~29B total params.
- **Why:** You literally linked this model. ~53GB bf16 (vs 71GB original), minimal benchmark degradation (-3% MMLU, -3% HumanEval), fits in less memory. The pruned MoE is faster to load and smaller on disk.
- **RAM:** ~53GB (bf16), ~20GB (Q4)
- **Benchmarks:** 80.89% MMLU, 73.2% HumanEval, competitive across ARC/BoolQ/HellaSwag
- **Source:** [ICLR 2026 paper: "REAP the Experts"](https://huggingface.co/0xSero/Qwen-3.5-28B-A3B-REAP)

### 3. Qwen3.5-40B-Claude-4.6-Opus-Uncensored-Thinking (GGUF)
- **HuggingFace:** [`mradermacher/Qwen3.5-40B-Claude-4.6-Opus-Deckard-Heretic-Uncensored-Thinking-GGUF`](https://huggingface.co/mradermacher/Qwen3.5-40B-Claude-4.6-Opus-Deckard-Heretic-Uncensored-Thinking-GGUF)
- **Architecture:** Qwen3.5-40B distilled with Opus 4.6 reasoning, uncensored thinking variant
- **Why:** You bookmarked @OliDietzel calling it "the real deal." Uncensored reasoning = no refusals during deep analysis. For a cognitive OS, unrestricted thinking is essential.
- **RAM:** ~24GB (Q4), ~64GB+ (Q8)
- **Source:** [Your bookmark — @OliDietzel tweet](https://x.com/OliDietzel/status/2037442084341215317)

### 4. Devstral Small 2 (24B) — Coding & Agentic Model
- **HuggingFace:** [`mistralai/devstral-small-2-2512`](https://huggingface.co/mistralai/devstral-small-2-2512)
- **Architecture:** 24B dense transformer, 256K context, Apache 2.0
- **Why:** 68% SWE-bench Verified (among models 5x its size), vision support, agentic tool use, 28x smaller than DeepSeek V3.2. Perfect for Epistemos code-related tasks and self-modification.
- **RAM:** ~16GB (Q4)
- **Source:** [Mistral announcement](https://mistral.ai/news/devstral-2-vibe-cli), [community praise on Reddit](https://www.reddit.com/r/LocalLLaMA/comments/1ry93gz/devstral_small_2_24b_severely_underrated/)

### 5. Gemma 3 27B QAT (Google)
- **HuggingFace:** [`google/gemma-3-27b-it-qat-q4_0-gguf`](https://huggingface.co/google/gemma-3-27b-it-qat-q4_0-gguf)
- **Architecture:** 27B, Google QAT (Quantization-Aware Training) — bfloat16 quality at int4 memory
- **Why:** Google's own QAT preserves quality at 4-bit far better than post-training quantization. Multimodal (vision). Strong non-coding intelligence — excellent for knowledge work, writing, analysis.
- **RAM:** ~16GB (Q4 QAT)
- **Source:** [Google Developers Blog](https://developers.googleblog.com/en/gemma-3-quantized-aware-trained-state-of-the-art-ai-to-consumer-gpus/)

### 6. Mistral Small 3.1 (24B) — Fast Conversational + Function Calling
- **HuggingFace:** [`mistralai/Mistral-Small-3.1-24B-Instruct-2503`](https://huggingface.co/mistralai/Mistral-Small-3.1-24B-Instruct-2503)
- **Architecture:** 24B, 128K context, multimodal, Apache 2.0
- **Why:** 150 tok/s inference, outperforms Gemma 3 and GPT-4o Mini, excellent for low-latency function calling within Epistemos's agent workflows. Runs on 32GB Mac.
- **RAM:** ~16GB (Q4)
- **Source:** [Mistral announcement](https://mistral.ai/news/mistral-small-3-1)

## Tier 2: Strong Additions (Community Consensus Best-in-Class)

### 7. Phi-4 (14B) — Microsoft Reasoning Specialist
- **Why:** 84.8% MMLU at only 14B params. MIT license. Reasoning-focused — ideal for the "thinking" mode in Epistemos at a fraction of the memory cost of 27B models.
- **RAM:** ~10GB (Q4)
- **Source:** [SLM Guide 2026](https://localaimaster.com/blog/small-language-models-guide-2026)

### 8. SmolLM3 (3B) — HuggingFace's Best Tiny Model
- **Architecture:** 3B, dual-mode reasoning (/think and /no_think), 128K context, 6 languages
- **Why:** Outperforms Llama 3.2 3B and Qwen2.5-3B. Fully open. Perfect as Epistemos's ultra-light fallback for 8GB machines. Dual-mode reasoning maps directly to your existing fast/thinking toggle.
- **RAM:** ~2GB (Q4)
- **Source:** [HuggingFace SmolLM3](https://huggingface.co/HuggingFaceTB/SmolLM3-3B)

### 9. Llama 4 Scout (109B, 17B active) — MoE Monster
- **HuggingFace:** [`mlx-community/meta-llama-Llama-4-Scout-17B-16E-4bit`](https://huggingface.co/mlx-community/meta-llama-Llama-4-Scout-17B-16E-4bit)
- **Architecture:** 109B total, 17B active (MoE, 16 experts), 10M token context
- **Why:** Meta's flagship MoE. Only 17B active params means it runs faster than you'd expect. 10M context is absurd — could ingest entire knowledge bases.
- **RAM:** ~64GB+ (Q4)
- **Source:** [Model comparison](https://till-freitag.com/en/blog/open-source-llm-comparison)

### 10. MiniMax M2.5 — SOTA Coding & Tool Calling
- **Why:** You bookmarked this — @akshay_pachaar called it "better than Opus 4.6 for coding, faster than Sonnet, SOTA for tool calling." Open source.
- **RAM:** Varies by quant
- **Source:** [Your bookmark](https://x.com/akshay_pachaar/status/2022574708051583120)

### 11. Chroma Context-1 (20B) — Agentic Search
- **Why:** You retweeted this. 20B parameter open-source agentic search engine. Apache 2.0. "Order of magnitude faster, order of magnitude cheaper" than existing solutions. Could power Epistemos's search features.
- **Source:** [Your retweet](https://x.com/trychroma)

---

# PART 2: APP FEATURE UPGRADES (From Your Bookmarks)

## A. Inference & Performance Upgrades

### 1. TurboQuant KV Cache Compression (Google Research)
- **What:** 6x KV cache memory reduction + up to 8x speedup, zero accuracy loss
- **Impact:** Your local 27B models would use 6x less memory for context and run up to 8x faster
- **Status:** Google paper published. Already running in Atomic Chat (you bookmarked @atomic_chat showing Qwen3.5-9B with 50K context on a MacBook Air M4 16GB using TurboQuant)
- **Action:** Integrate when available in MLX/llama.cpp, or integrate Atomic Chat's approach directly
- **Source:** [Google Research TurboQuant](https://x.com/GoogleResearch/status/2036533564158910740)

### 2. Prompt Repetition Technique
- **What:** Repeating the input prompt improves non-reasoning model output quality. Zero additional tokens, zero latency cost.
- **Paper:** Yaniv Leviathan et al. (Google Research) — works on Gemini, GPT, Claude, DeepSeek
- **Action:** Implement in `LLMService.swift` or `PipelineService.swift` — duplicate the user prompt in the system message for local model calls
- **Source:** [Your bookmark — Prompt Repetition paper](https://x.com/oliviscusAI)

### 3. omlx — LLM Inference Server with SSD Caching
- **Repo:** [`github.com/jundot/omlx`](https://github.com/jundot/omlx)
- **What:** LLM inference server with continuous batching and SSD caching, built for Apple Silicon
- **Impact:** Offloads model layers to SSD when memory is tight, enabling larger models on smaller Macs
- **Source:** [Your bookmark](https://x.com/loryoncloud/status/2031001521664749690)

### 4. Exo Distributed Inference
- **What:** Pipeline sharding across multiple Apple Silicon devices (MacBook + Mac Mini cluster)
- **Impact:** Run 27B+ models across multiple Macs in your network
- **Source:** [Your bookmark — @0xCVYH running Qwen3.5-27B on Exo cluster](https://x.com/0xCVYH/status/2036532395541733724)

## B. Voice & Audio Features

### 5. Voxtral 4B TTS — Local Voice Output
- **Repo:** Mistral's open-weight TTS
- **What:** 4B parameter text-to-speech, natural and expressive, runs fully locally
- **Impact:** Epistemos speaks. Full voice output without any cloud dependency.
- **Source:** [Your bookmark — @MistralAI Voxtral TTS](https://x.com/MistralAI/status/2037183026539483288)

### 6. Superwhisper-Style Voice Input
- **What:** macOS voice transcription (Karpathy uses it). Voice → text → note.
- **Impact:** Voice-to-note is the fastest input modality for PKM. Karpathy's endorsement carries weight.
- **Source:** [Your bookmark — @superwhisper Karpathy demo](https://x.com/superwhisper/status/2036533884414804199)

### 7. LuxTTS — Rapid Voice Cloning
- **Repo:** [`github.com/ysharma3501/LuxTTS`](https://github.com/ysharma3501/LuxTTS)
- **What:** High-quality rapid TTS with voice cloning
- **Impact:** Epistemos could speak in a custom voice — user's own voice, or a branded Epistemos voice
- **Source:** [Your bookmark](https://x.com/hasantoxr/status/2031846517586497857)

## C. Agent & Reasoning Architecture Upgrades

### 8. SOUL.md + Principles.md — Agent Identity Framework
- **What:** SOUL.md defines AI identity (personality, values, behavior). Principles.md defines ethical/behavioral constraints.
- **Impact:** Epistemos already has a "Greetings, Learner" identity. SOUL.md would formalize this into a persistent agent identity file that governs all reasoning.
- **Source:** [Your bookmark — soul.md](https://soul.md), [Principles.md article](https://x.com/AtlasForgeAI/status/2021773566341988758)

### 9. MoltBr — Long-Term Memory Layer
- **Repo:** [`github.com/nhevers/MoltBr`](https://github.com/nhevers/MoltBr)
- **What:** Persistent long-term memory layer for coding agents (OpenClaw, Claude Code)
- **Impact:** Epistemos is a PKM — persistent memory IS the product. MoltBr's architecture for memory persistence, retrieval, and context injection is directly transferable to your `TimeMachineService` and knowledge graph.
- **Source:** [Your bookmark](https://x.com/tom_doerr/status/2035646046106271983)

### 10. Hyperagents / Darwin Gödel Machine — Self-Improving AI
- **What:** Meta AI's system where AI improves how it improves itself. Arbitrary-order self-improvement.
- **Impact:** Epistemos's cognitive OS could implement meta-learning: the reasoning engine improves its own strategies based on what works. Your MOHAWK adapters could self-select and self-improve.
- **Source:** [Your bookmark — Jenny Zhang, Jeff Clune](https://x.com/jennyzhangzt/status/2036099935083618487)

### 11. Karpathy AutoResearch Pipeline
- **What:** Self-improving research loops where Claude/LLM auto-researches topics, evaluates quality, iterates
- **Tools:** `hf papers` CLI for semantic arxiv search, Paperzilla CLI for bioRxiv/medRxiv
- **Impact:** Epistemos could run autonomous background research on any topic the user is tracking. "Night Brain" could auto-research while user sleeps.
- **Source:** [Multiple bookmarks — @itsolelehmann, @_akhaliq](https://x.com/itsolelehmann/status/2033919415771713715)

### 12. Vectorless RAG System
- **What:** Hierarchical page index approach to RAG without vector embeddings
- **Impact:** Could complement or replace Epistemos's current HNSW vector search with a simpler, faster retrieval method for certain use cases
- **Source:** [Your feed — @ThevixhaI](https://x.com/ThevixhaI)

### 13. Code-Review-Graph for Context Optimization
- **What:** Builds a structural map of code with Tree-sitter, tracks changes incrementally, gives AI precise context instead of re-reading the entire codebase
- **Impact:** Epistemos has 242K LOC. This would dramatically reduce token usage when AI agents work on the codebase.
- **Source:** [Your bookmark — @akshay_pachaar](https://x.com/akshay_pachaar)

## D. Knowledge Management & Research Upgrades

### 14. Audio Summaries for Research Papers
- **What:** Generate audio summaries of research papers for on-the-go consumption
- **Impact:** Combined with Voxtral TTS, Epistemos could read paper summaries aloud. "Brief me on the latest neuroscience papers."
- **Source:** [Your bookmark — @TGUPJ](https://x.com/TGUPJ/status/2031140738243625057)

### 15. Spatial Organization (Beyond Tags)
- **What:** Kat the Poet Engineer's thesis: tagging misses half the point. Knowledge should be organized spatially — how ideas connect and relate, not just what category they belong to.
- **Impact:** Epistemos's knowledge graph already does this partially. The upgrade: make spatial organization the PRIMARY organizing principle, with tags as secondary metadata. Think "visual garden of ideas" with gesture-based symbol placement.
- **Source:** [Your bookmark — @poetengineer__](https://x.com/poetengineer__/status/1859717052304441511)

### 16. EurekaClaw — Scientific Research Agent
- **Repo:** EurekaClaw (open-source)
- **What:** Autonomous scientific research agent — "promises to be the king of scientific research"
- **Impact:** Integrate as Epistemos's research mode. Give it a topic, get back a full research summary with citations.
- **Source:** [Your bookmark — @ErickSky](https://x.com/ErickSky/status/2036593690437628327)

### 17. HKU AI-Researcher — End-to-End Research Lifecycle
- **What:** NeurIPS 2025 Spotlight paper. AI that does the entire scientific research lifecycle: ideation → experiment design → execution → paper writing
- **Impact:** The blueprint for Epistemos's most ambitious research feature — fully autonomous research synthesis.
- **Source:** [Your retweet — @ihtesham2005](https://x.com/ihtesham2005)

### 18. Sentient Local Deep Researcher
- **What:** Research agent that runs locally — "works like a PhD student with unlimited time and zero salary"
- **Impact:** Local, private research agent. Writes its own search queries, reads papers, synthesizes findings.
- **Source:** [Your retweet — @sentient_agency](https://x.com/sentient_agency)

## E. UI/UX & Design Upgrades

### 19. Apple Invites Splash Screens
- **Repo:** @1998design's repo
- **What:** Drop+Offset transitions and bold text effects identical to Apple's Invites app
- **Impact:** Epistemos already has a typewriter greeting. These splash transitions would make the boot sequence feel premium and Apple-native.
- **Source:** [Your bookmark — @ErickSky](https://x.com/ErickSky/status/2029555175396970901)

### 20. Skeuomorphism Navigation Revival
- **What:** @tubikstudio's creative navigation with physical-feeling categories
- **Impact:** Epistemos's pixel-art aesthetic + skeuomorphic navigation = a unique, tactile feel that no other PKM app has
- **Source:** [Your bookmark — @Aurelien_Gz](https://x.com/Aurelien_Gz)

### 21. Disappearing Interfaces (Future UX)
- **What:** "Interfaces of the future will disappear. Instead of buttons and menus, we will interact directly with intelligence."
- **Impact:** Epistemos's command palette and natural language interface already point this direction. Push further: make the chat/command interface the ONLY interface, with visual elements appearing contextually.
- **Source:** [Your retweet — @maximzhestkov](https://x.com/maximzhestkov)

### 22. Variantui — AI Design Generation
- **Website:** variantui.com
- **What:** "Enter an idea and get endless beautiful designs as you scroll"
- **Impact:** Could power Epistemos's theme/customization — generate custom UI themes on the fly
- **Source:** [Your bookmark — @bnj](https://x.com/bnj/status/2016595100714095039)

### 23. Procedural World Generation
- **What:** @StephenDDGames made "a game world that creates itself as you journey through it"
- **Impact:** Epistemos's knowledge graph could generate itself visually as you explore topics — nodes and connections appear as you navigate, creating a sense of discovery.
- **Source:** [Your bookmark](https://x.com/StephenDDGames/status/2034201517771677733)

### 24. React Bits (reactbits.dev)
- **What:** UI component library
- **Impact:** For the Epistemos web app (epistemos-site), these components could enhance the frontend
- **Source:** [Your retweet — @Abmankendrick](https://x.com/Abmankendrick)

## F. Agent Ecosystem & Tool Integration

### 25. Skills.sh — Agent Skills Directory (Vercel)
- **Website:** [skills.sh](https://skills.sh)
- **What:** Open ecosystem for finding and sharing agent skills
- **Impact:** Epistemos could both consume skills from this directory AND publish its own PKM-specific skills
- **Source:** [Your bookmark — @vercel](https://x.com/vercel/status/2013660091854000360)

### 26. Machina Directory — 9,000+ AI Agent Skills, 9,600+ MCP Servers
- **Website:** [machina.directory](https://machina.directory)
- **What:** Massive directory of pre-built AI agent skills and MCP servers
- **Impact:** Instead of building every capability from scratch, Epistemos could tap into this ecosystem for specialized skills
- **Source:** [Your bookmark — @xtomleex](https://x.com/oliviscusAI/status/2031415996553244898)

### 27. Anthropic's Internal Skills Library
- **Repo:** `github.com/anthropics/skills`
- **What:** The exact skills library Anthropic's own engineers use
- **Impact:** Battle-tested skill patterns for Claude integration — directly adoptable for Epistemos's agent workflows
- **Source:** [Your bookmark — @oliviscusAI](https://x.com/oliviscusAI/status/2031415996553244898)

### 28. DeerFlow — ByteDance SuperAgent Harness
- **Repo:** [`github.com/bytedance/deer-flow`](https://github.com/bytedance/deer-flow)
- **What:** Open-source SuperAgent that researches, codes, and synthesizes
- **Impact:** Architecture reference for Epistemos's multi-agent reasoning pipeline
- **Source:** [Your bookmark](https://x.com/KanikaBK/status/2035967343248187764)

### 29. AgentScope — Visual Agent Builder
- **What:** Python framework with visual agent building, MCP tools, memory, RAG, and reasoning
- **Impact:** Could serve as the backend orchestration layer for Epistemos's agent system
- **Source:** [Your bookmark — @oliviscusAI](https://x.com/oliviscusAI/status/2035762710424572330)

### 30. Moonshot.computer — AI Agent as macOS User
- **Website:** [moonshot.computer](https://moonshot.computer)
- **What:** First AI agent that runs as a separate macOS user alongside you. "2 users, 1 Mac."
- **Impact:** Architectural inspiration for MOHAWK — instead of MOHAWK controlling your UI, it could operate as a separate macOS user with its own workspace, then present results to you.
- **Source:** [Your bookmark — @ojaskandy](https://x.com/ojaskandy/status/2031801456718987765)

### 31. Alibaba Copaw — Free Local AI Agent
- **What:** Runs autonomously on your computer 24/7, long-term memory, works with Ollama + Qwen 3.5
- **Impact:** Architecture reference for Epistemos's autonomous background agent mode
- **Source:** [Your retweet — @JulianGoldieSEO](https://x.com/JulianGoldieSEO)

## G. Privacy & Offline Architecture

### 32. Project NOMAD — Self-Contained Offline AI Computer
- **Repo:** [`github.com/Crosstalk-Solutions/project-nomad`](https://github.com/Crosstalk-Solutions/project-nomad)
- **What:** Fully offline survival computer with AI, Wikipedia, maps — everything works without internet
- **Impact:** Blueprint for Epistemos's "fully offline" mode — should work completely air-gapped with local models, local embeddings, local search
- **Source:** [Your bookmark](https://x.com/godofprompt/status/2035432638157140385)

### 33. Private AI Inference (Columbia University)
- **What:** Paper proving that encrypting the full transformer (280GB, 60s latency) is the wrong approach. New lightweight private inference method.
- **Impact:** If Epistemos ever offers cloud-augmented inference, this is how to do it privately
- **Source:** [Your bookmark/retweet](https://x.com/godofprompt/status/2035697480227266950)

## H. Research & Neuroscience Content (For Epistemos Knowledge Base)

These bookmarks are content interests, not direct feature upgrades, but could inform Epistemos's default knowledge domains:

### 34. Behavioral Timescale Synaptic Plasticity (Nature Neuroscience 2026)
- Jeffrey C. Magee — how the brain actually learns
- **Source:** [Your bookmark — @DrDominicNg](https://x.com/DrDominicNg/status/2026206238930030931)

### 35. Quantum Microtubule Consciousness (2025)
- MRI evidence for macroscopic quantum entangled states in living human brains
- **Source:** [Your bookmark — @TheProjectUnity](https://x.com/TheProjectUnity/status/2017703149159489780)

### 36. MIT Miller Lab — Consciousness Research
- **Source:** [Your retweet — @MillerLabMIT](https://x.com/MillerLabMIT)

### 37. LeCun's LewWorldModel
- "Cracked world models wide open" — important for next-gen reasoning architectures
- **Source:** [Your bookmark — @alex_prompter](https://x.com/alex_prompter/status/2036547251363786873)

### 38. Apple Workshop on Reasoning and Planning 2025
- Jeff Clune's talk at Apple ML. Apple is actively investing in reasoning and planning research.
- **Source:** [Your bookmark — @jeffclune](https://x.com/jeffclune/status/2031471559639244912)

### 39. Agentic AI and the Next Intelligence Explosion (Google/UChicago)
- Key thesis: intelligence explosions are social, not individual. A network of specialized agents > one superintelligent system.
- **Impact:** Validates Epistemos's multi-agent architecture over single-model approaches.
- **Source:** [Your bookmark — arxiv 2603.20639](https://x.com/omarsar0/status/2034183128198348953)

---

# PART 3: IMPLEMENTATION PRIORITY MATRIX

## Do Now (Week 1-2)
| # | Upgrade | Effort | Impact |
|---|---------|--------|--------|
| 1 | Add Qwen3.5-27B-Opus-Distilled-v2 to `LocalTextModelID` | Low | Very High — Claude-level reasoning locally |
| 2 | Add Qwen3.5-28B-A3B-REAP to `LocalTextModelID` | Low | High — pruned MoE, smaller disk + memory |
| 3 | Add Devstral Small 2 (24B) to `LocalTextModelID` | Low | High — best local coding model |
| 4 | Add Gemma 3 27B QAT to `LocalTextModelID` | Low | High — best multimodal local model |
| 5 | Add Mistral Small 3.1 (24B) to `LocalTextModelID` | Low | High — fastest function calling |
| 6 | Implement Prompt Repetition in pipeline | Low | Medium — free quality boost |
| 7 | Add Phi-4 (14B) to `LocalTextModelID` | Low | Medium — great reasoning at low memory |
| 8 | Add SmolLM3 (3B) to `LocalTextModelID` | Low | Medium — best tiny fallback |

## Do Soon (Week 3-6)
| # | Upgrade | Effort | Impact |
|---|---------|--------|--------|
| 9 | Integrate Voxtral 4B TTS | Medium | Very High — Epistemos speaks |
| 10 | Build SOUL.md + Principles.md agent identity | Medium | High — formalized agent behavior |
| 11 | Study MoltBr memory architecture, adapt for Epistemos | Medium | High — persistent memory patterns |
| 12 | Build AutoResearch pipeline with `hf papers` CLI | Medium | High — autonomous research |
| 13 | Add Qwen3.5-40B-Opus-Uncensored-Thinking GGUF | Low | Medium — for power users with 64GB+ |
| 14 | Integrate Apple Invites splash transitions | Medium | Medium — premium boot experience |

## Do Later (Month 2-3)
| # | Upgrade | Effort | Impact |
|---|---------|--------|--------|
| 15 | TurboQuant KV cache compression | High | Very High — 8x speedup when available |
| 16 | Superwhisper-style voice input | High | Very High — voice-to-note |
| 17 | Spatial knowledge organization (beyond tags) | High | High — differentiating PKM feature |
| 18 | Procedural knowledge graph visualization | High | High — discovery-driven exploration |
| 19 | Self-improving reasoning (Hyperagents pattern) | Very High | Very High — long-term vision |
| 20 | Exo distributed inference support | High | Medium — multi-Mac clusters |

---

# PART 4: UPDATED LocalTextModelID ENUM (Proposed)

```swift
nonisolated enum LocalTextModelID: String, Codable, Sendable, CaseIterable {
    // === Qwen 3.5 Family (Current) ===
    case qwen35_0_8B4Bit = "mlx-community/Qwen3.5-0.8B-4bit"
    case qwen35_2B4Bit = "mlx-community/Qwen3.5-2B-4bit"
    case qwen35_4B4Bit = "mlx-community/Qwen3.5-4B-4bit"
    case qwen35_9B4Bit = "mlx-community/Qwen3.5-9B-4bit"
    case qwen35_27B4Bit = "mlx-community/Qwen3.5-27B-4bit"
    case qwen35_35BA3B4Bit = "mlx-community/Qwen3.5-35B-A3B-4bit"
    
    // === NEW: Qwen 3.5 Distilled / Pruned Variants ===
    case qwen35_27BOpusDistilled = "Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF"
    case qwen35_28BA3BREAP = "0xSero/Qwen-3.5-28B-A3B-REAP"
    case qwen35_40BOpusUncensored = "mradermacher/Qwen3.5-40B-Claude-4.6-Opus-Deckard-Heretic-Uncensored-Thinking-GGUF"
    
    // === NEW: Non-Qwen Best-in-Class ===
    case devstralSmall2_24B = "mistralai/devstral-small-2-2512"
    case gemma3_27BQAT = "google/gemma-3-27b-it-qat-q4_0-gguf"
    case mistralSmall31_24B = "mistralai/Mistral-Small-3.1-24B-Instruct-2503"
    case phi4_14B = "microsoft/phi-4"
    case smolLM3_3B = "HuggingFaceTB/SmolLM3-3B"
    
    var displayName: String {
        switch self {
        case .qwen35_0_8B4Bit: "Qwen 3.5 0.8B 4-bit"
        case .qwen35_2B4Bit: "Qwen 3.5 2B 4-bit"
        case .qwen35_4B4Bit: "Qwen 3.5 4B 4-bit"
        case .qwen35_9B4Bit: "Qwen 3.5 9B 4-bit"
        case .qwen35_27B4Bit: "Qwen 3.5 27B 4-bit"
        case .qwen35_35BA3B4Bit: "Qwen 3.5 35B-A3B 4-bit"
        case .qwen35_27BOpusDistilled: "Qwen 3.5 27B Opus-Distilled v2"
        case .qwen35_28BA3BREAP: "Qwen 3.5 28B-A3B REAP (Pruned)"
        case .qwen35_40BOpusUncensored: "Qwen 3.5 40B Opus Uncensored"
        case .devstralSmall2_24B: "Devstral Small 2 (24B)"
        case .gemma3_27BQAT: "Gemma 3 27B QAT"
        case .mistralSmall31_24B: "Mistral Small 3.1 (24B)"
        case .phi4_14B: "Phi-4 (14B)"
        case .smolLM3_3B: "SmolLM3 (3B)"
        }
    }

    var familyName: String {
        switch self {
        case .qwen35_0_8B4Bit, .qwen35_2B4Bit, .qwen35_4B4Bit,
             .qwen35_9B4Bit, .qwen35_27B4Bit, .qwen35_35BA3B4Bit,
             .qwen35_27BOpusDistilled, .qwen35_28BA3BREAP, .qwen35_40BOpusUncensored:
            "Qwen 3.5"
        case .devstralSmall2_24B: "Mistral"
        case .gemma3_27BQAT: "Gemma"
        case .mistralSmall31_24B: "Mistral"
        case .phi4_14B: "Phi"
        case .smolLM3_3B: "SmolLM"
        }
    }

    var minimumRecommendedMemoryGB: Int {
        switch self {
        case .qwen35_0_8B4Bit: 8
        case .qwen35_2B4Bit: 12
        case .smolLM3_3B: 8
        case .qwen35_4B4Bit: 16
        case .phi4_14B: 16
        case .qwen35_9B4Bit: 16
        case .devstralSmall2_24B: 24
        case .mistralSmall31_24B: 24
        case .gemma3_27BQAT: 24
        case .qwen35_27B4Bit: 48
        case .qwen35_27BOpusDistilled: 48
        case .qwen35_28BA3BREAP: 24  // MoE, only 3B active
        case .qwen35_35BA3B4Bit: 64
        case .qwen35_40BOpusUncensored: 64
        }
    }
}
```

**Note:** The GGUF models (Opus-Distilled, REAP, Uncensored) will require adding GGUF/llama.cpp inference alongside the existing MLX pipeline, or using community MLX conversions when available. The `ModelDownloadManager` and `MLXInferenceService` will need to handle both MLX and GGUF formats.

---

# PART 5: REPOS TO STAR / STUDY

| Repo | What | Priority |
|------|------|----------|
| [`unslothai/unsloth`](https://github.com/unslothai/unsloth) | RL fine-tuning (train Qwen for Epistemos-specific tasks) | High |
| [`nhevers/MoltBr`](https://github.com/nhevers/MoltBr) | Long-term memory layer architecture | High |
| [`bytedance/deer-flow`](https://github.com/bytedance/deer-flow) | SuperAgent research/coding harness | High |
| [`paperzilla-ai/pz`](https://github.com/paperzilla-ai/pz) | Research paper CLI browser | Medium |
| [`kyegomez/swarms`](https://github.com/kyegomez/swarms) | Multi-agent orchestration | Medium |
| [`Crosstalk-Solutions/project-nomad`](https://github.com/Crosstalk-Solutions/project-nomad) | Offline AI architecture | Medium |
| [`cerebras/reap`](https://github.com/cerebras/reap) | MoE expert pruning (how REAP model was made) | Medium |
| [`garrytan/gstack`](https://github.com/garrytan/gstack) | Opinionated Claude Code setup | Low |
| [`ysharma3501/LuxTTS`](https://github.com/ysharma3501/LuxTTS) | Rapid voice cloning TTS | Low |
| [`jundot/omlx`](https://github.com/jundot/omlx) | SSD-cached inference for Apple | Medium |

---

*This plan synthesizes 641 bookmarks, 70+ retweets, current model research, and the live Epistemos codebase (InferenceState.swift, LocalModelInfrastructure.swift). Every recommendation traces back to content you personally saved, retweeted, or that the local LLM community unanimously endorses.*
