<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# Local Model Stack Audit: Per-Model Capability Profiles for Epistemos

## Where Models Agree

| Finding | GPT-5.4 Thinking | Claude Opus 4.6 Thinking | Gemini 3.1 Pro Thinking | Evidence |
| :-- | :-- | :-- | :-- | :-- |
| Infrastructure treats all 18 models identically — this is the root problem | ✓ | ✓ | ✓ | Same context limit, temperature, KV cache, no vision/tool extraction applied uniformly[^1][^2] |
| Each model family needs unique temperature settings | ✓ | ✓ | ✓ | DeepSeek R1 Distill needs 0.5-0.7[^3], Gemma 4 wants 1.0/top_k=64[^4], Qwen 3.5 wants 1.0/presence_penalty=1.5[^5] |
| Qwen 3.5 small models (0.8B/2B/4B/9B) default to non-thinking mode | ✓ | ✓ | ✓ | Must explicitly enable via `enable_thinking: true`[^6][^5][^7] |
| Context windows vary dramatically: 32K to 262K across the stack | ✓ | ✓ | ✓ | DeepSeek R1 Distill 7B: 32K[^8], Qwen 2.5 Coder: 32K default[^9], Qwen 3.5: 262K[^10][^11], Gemma 4: 128-256K[^4] |
| Vision capability must be enabled per-model, not blanket-disabled | ✓ | ✓ | ✓ | Gemma 4 all sizes have vision[^4][^12], Qwen 3.5 9B/27B/35B have vision[^13][^14], Devstral is text-only[^15] |
| Tool/function calling support varies by model and requires different formats | ✓ | ✓ | ✓ | Gemma 4 uses native format[^4], Qwen uses Qwen-style[^16][^17], DeepSeek R1 Distill has no native tool calling[^3] |

## Where Models Disagree

| Topic | GPT-5.4 Thinking | Claude Opus 4.6 Thinking | Gemini 3.1 Pro Thinking | Why They Differ |
| :-- | :-- | :-- | :-- | :-- |
| DeepSeek R1 Distill 7B context limit | 32K native | 128K with YaRN | 32K safe default | Claude weighs YaRN extension capability; others cite practical default[^8][^9] |
| Qwen 2.5 Coder 7B tool calling viability | Functional via Qwen-Agent | Unreliable without fine-tuning | Works with chatml template | Different testing frameworks; Ollama vs llama.cpp vs vLLM yield different results[^17][^18] |
| SmolLM3 tool calling capability | Supports tool calling | Limited/experimental | Supports via Jinja template | Hugging Face docs claim support[^19] but practical GGUF deployment needs custom template[^20] |
| Whether Qwopus inherits Qwen 3.5 multimodal | No — trained on 8K context, loses multimodal | Partial — may work but untested | No — distillation strips vision | Qwopus is a QLoRA distill focused on code/reasoning, not multimodal[^21][^22] |

## Unique Discoveries

| Model | Unique Finding | Why It Matters |
| :-- | :-- | :-- |
| GPT-5.4 Thinking | Qwen 3.5 27B has a known Ollama bug where tool calling is "completely non-functional"[^23] | Your Ollama routing for this model may silently fail on tool calls |
| Claude Opus 4.6 Thinking | Devstral Small has TWO versions: 1.0 (128K) and 2.0 (256K context)[^24][^25] — you need to specify which | Wrong version = half the context window |
| Gemini 3.1 Pro Thinking | Gemma 4 E2B/E4B support audio input natively[^4][^12] — no other model in your stack does | Potential unique capability for speech-to-text routing |

## Comprehensive Analysis

### High-Confidence Findings: The 18-Model Capability Map

The most critical finding across all three models is that your Rust `agent_core` OpenAICompatibleProvider is sending identical JSON payloads to 18 fundamentally different models. This is confirmed by your own session notes and validated by the research. Here is the **complete per-model capability descriptor** that Claude Code needs to implement — this is the synthesis document you asked for.[^2][^26]

**TIER 1 — Ultra-Light (Routing/Quick Tasks):**

**Gemma 4 2B (E2B):** Context 128K, sliding window 512, temperature 1.0, top_p 0.95, top_k 64[^4]. Supports vision, audio, thinking mode, function calling, system prompts natively. The "E" means 2.3B effective / 5.1B with embeddings due to Per-Layer Embeddings[^4]. Vision token budget configurable: 70/140/280/560/1120[^4]. This is your only audio-capable model alongside E4B. Enable thinking via `<|think|>` token in system prompt[^4].

**Qwen 3.5 0.8B:** Context 262K natively, temperature 1.0, top_p 0.95, top_k 20, presence_penalty 1.5 for thinking mode. **Thinking disabled by default** — must pass `enable_thinking: true`. Multimodal (text + vision). Uses hybrid Gated Delta Networks + Gated Attention architecture. Supports 201 languages. Tool calling works via Qwen-style format.[^10][^6][^5][^16]

**Qwen 3.5 2B:** Same profile as 0.8B — context 262K, thinking disabled by default, multimodal. Dense architecture, all params active. Same sampling params as 0.8B.[^27][^7]

**TIER 2 — Light (General Assistant):**

**Gemma 4 4B (E4B):** Context 128K, sliding window 512. Same capabilities as E2B but 4.5B effective / 8B with embeddings. Vision + audio + thinking + function calling + system prompts. Same sampling: temp 1.0, top_p 0.95, top_k 64.[^4]

**Qwen 3.5 4B:** Context 262K, thinking disabled by default. Multimodal. Best tool-calling pass rate of any local model at 97.5% per prior research. Same Qwen sampling params. Dense architecture.[^28][^6]

**SmolLM3 3B:** Context 128K. Supports thinking/no_think dual mode. 6 languages (EN/FR/ES/DE/IT/PT). Uses NoPE + YaRN for long context. Tool calling supported but **requires `--jinja` flag in llama.cpp and custom template for GGUF**. No vision. No audio. Temperature and sampling: follow standard defaults (no official recommendation found, use temp 0.7 as safe default).[^19][^29][^20]

**TIER 3 — Medium (Serious Work):**

**DeepSeek R1 Distill 7B:** Context 32K default (based on Qwen2.5-Math-7B). **Temperature MUST be 0.5-0.7 (0.6 recommended)** — outside this range causes endless repetition. **NO system prompt** — all instructions must go in user prompt. No native tool calling. No vision. Excels at math/reasoning: 92.8% MATH-500, 55.5% AIME 2024. Thinking is always on (R1-style CoT). For math, add "Please reason step by step, and put your final answer within \\boxed{}".[^9][^8][^30][^3]

**Qwen 2.5 Coder 7B:** Context 32K default, extensible to 128K via YaRN. Specialized for code. Tool calling works via Qwen-Agent framework but returns `finish_reason: 'stop'` instead of `'tool_calls'` in standard OpenAI-compatible mode — your Rust parser needs to handle this. No vision (text-only code model). Temperature: use 0.0 for code generation, 1.0 for general.[^31][^17][^32][^9]

**Qwen 3.5 9B:** Context 262K. Multimodal (text + vision). Thinking disabled by default — enable explicitly. Full tool calling support including MCP integration via Qwen-Agent. Same Qwen sampling params. This is the smallest Qwen 3.5 that comfortably handles vision tasks with sufficient quality.[^6][^13]

**Gemma 4 12B:** This maps to the Gemma 3 12B if you're running Gemma 3, or possibly a custom variant. If Gemma 4 family: there is no official 12B Gemma 4 — the sizes are E2B, E4B, 26B MoE, 31B Dense. **You may actually be running Gemma 3 12B** which has 128K context, vision, 5:1 local-to-global attention ratio, 1024-token local span. Verify which model file you actually have.[^33][^4]

**TIER 4 — Large (Frontier Local):**

**Gemma 4 27B MoE (26B A4B):** 25.2B total, 3.8B active, 8/128 experts + 1 shared. Context 256K, sliding window 1024. Vision (550M encoder), no audio. Function calling, thinking, system prompts. Temp 1.0, top_p 0.95, top_k 64. Runs nearly as fast as a 4B model despite 26B total.[^34][^4]

**Gemma 4 31B JANG (abliterated):** Same architecture as Gemma 4 31B Dense — 30.7B params, 256K context, 1024 sliding window, vision (550M encoder). Being abliterated means safety filters removed — same sampling/capability profile but uncensored output. Verify your quant fits in 18GB VRAM (Q4_0 needs ~17.4GB for base weights alone).[^35][^36][^4]

**Qwopus 27B v3:** Based on Qwen3.5-27B with reasoning distillation + tool-calling RL. **Critical: trained for tool-augmented agents specifically for OpenClaw**. 95.73% HumanEval. However: **loses Qwen 3.5 multimodal capability** and was likely trained on limited context despite Qwen3.5-27B's native 262K. Text-only. Use Qwen-style tool calling format. Context: treat as 262K native (inherited from base) but verify long-context quality.[^21][^28]

**Qwopus MoE 35B:** Claude Opus 4.6 QLoRA distill of Qwen3.5-35B-A3B. 35B total, ~3B active, 256 experts (8 active). Context 262K inherited. **Text-only** (distillation likely stripped vision). Tool calling calibrated for agentic traces. Use Qwen 3.5 MoE sampling params.[^22]

**Qwen 3.5 27B:** 262K context, multimodal (text + vision), dense architecture. Thinking mode. Native tool calling but **Ollama has a known bug making tool calling non-functional** — use llama.cpp or vLLM instead for tool-calling workloads. 86.1% MMLU-Pro, 72.4% SWE-bench. Same Qwen sampling.[^11][^23]

**Qwen 3.5 35B MoE:** 35B total / 3B active, 256 experts. 262K context, multimodal. Hybrid attention: 3:1 linear-to-full ratio. Same sampling as other Qwen 3.5 models. Tool calling supported.[^37][^14]

**Devstral Small:** 24B params, **128K context** (v1.0/2507) or **256K context** (v2.0/2512). **Text-only** — vision encoder explicitly removed before fine-tuning. Mistral-style function calling. Agentic coding specialist. Temperature: 0.15 recommended for code. Supports system prompts. **Requires `--jinja` in llama.cpp for proper tool calling**.[^24][^38][^15][^39]

**Mistral Small 24B:** 128K context. Vision + text (Mistral Small 3.1 base). Native function calling + JSON output. Multilingual (EN/FR/DE/JA/KO/ZH+). Tekken tokenizer with 131K vocab. Standard sampling.[^40][^41]

### Areas of Divergence: Critical Implementation Gaps

The most dangerous disagreement concerns **Qwen 3.5 27B tool calling in Ollama**. GPT-5.4 Thinking uniquely flagged that this is a known, filed GitHub issue where tool calling is "completely non-functional and repetition" occurs. If your Rust agent_core routes tool-calling tasks to Qwen 3.5 27B through Ollama, those calls silently fail. The fix is either using llama.cpp/vLLM as the backend for this specific model, or routing tool-heavy tasks to Qwen 3.5 4B (97.5% tool-call pass rate) or Qwopus v3 (RL-trained for tool calling).[^23][^21][^28]

The DeepSeek R1 Distill 7B is the most sensitive model in your stack. All three council models agree it needs temp 0.5-0.7 and no system prompt, but your infrastructure currently sends a uniform temperature (likely 0.7 or 1.0) and likely includes a system prompt. Sending temp 1.0+ to this model will produce degenerate output — endless repetition or incoherent text. This is your **highest-priority single-model fix**.[^30][^3]

### Recommendations: What Claude Code Needs to Implement

Create a `LocalModelCapability` struct/JSON descriptor for each of the 18 models containing: `context_window`, `sliding_window`, `temperature`, `top_p`, `top_k`, `presence_penalty`, `supports_vision`, `supports_audio`, `supports_thinking` (+ default on/off), `supports_tool_calling` (+ format: qwen/gemma/mistral/none), `supports_system_prompt`, `modalities` array, `special_flags` (e.g., DeepSeek's no-system-prompt requirement), and `recommended_quant` for your 18GB M2 Pro. Route the correct descriptor through your Rust `OpenAICompatibleProvider` before every API call. This is the single change that will make all 18 models actually work as intended rather than operating at a fraction of their capability.
<span style="display:none">[^100][^101][^102][^103][^104][^105][^106][^107][^108][^109][^110][^111][^112][^113][^114][^115][^116][^117][^118][^119][^120][^121][^122][^123][^124][^125][^126][^127][^128][^129][^130][^131][^132][^133][^134][^135][^136][^137][^138][^139][^140][^141][^142][^143][^144][^145][^146][^147][^148][^149][^150][^151][^152][^153][^154][^155][^156][^157][^158][^159][^160][^161][^162][^163][^164][^165][^166][^167][^168][^169][^170][^171][^172][^173][^174][^175][^176][^177][^178][^179][^180][^181][^182][^183][^184][^185][^186][^187][^188][^189][^190][^191][^192][^193][^194][^195][^196][^197][^198][^199][^200][^201][^202][^203][^204][^205][^206][^207][^208][^209][^210][^211][^212][^213][^214][^215][^216][^217][^218][^219][^220][^221][^222][^223][^224][^225][^226][^227][^228][^229][^230][^231][^232][^233][^234][^235][^236][^237][^238][^239][^240][^241][^242][^243][^244][^245][^246][^42][^43][^44][^45][^46][^47][^48][^49][^50][^51][^52][^53][^54][^55][^56][^57][^58][^59][^60][^61][^62][^63][^64][^65][^66][^67][^68][^69][^70][^71][^72][^73][^74][^75][^76][^77][^78][^79][^80][^81][^82][^83][^84][^85][^86][^87][^88][^89][^90][^91][^92][^93][^94][^95][^96][^97][^98][^99]</span>

<div align="center">⁂</div>

[^1]: https://www.perplexity.ai/search/8d3b0586-9fb0-4b13-b98d-4501d3d3d763

[^2]: https://www.perplexity.ai/search/85857ea8-6703-4406-b401-ff672580b04f

[^3]: https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B

[^4]: https://ai.google.dev/gemma/docs/core/model_card_4

[^5]: https://huggingface.co/Qwen/Qwen3.5-0.8B

[^6]: https://unsloth.ai/docs/models/qwen3.5

[^7]: https://huggingface.co/Qwen/Qwen3.5-2B

[^8]: https://www.siliconflow.com/models/deepseek-r1-distill-qwen-7b

[^9]: https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct

[^10]: https://apxml.com/models/qwen35-08b

[^11]: https://apxml.com/models/qwen35-27b

[^12]: https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/

[^13]: https://huggingface.co/Qwen/Qwen3.5-9B

[^14]: https://huggingface.co/Qwen/Qwen3.5-35B-A3B

[^15]: https://huggingface.co/mistralai/Devstral-Small-2507_gguf

[^16]: https://qwen.readthedocs.io/en/latest/framework/function_call.html

[^17]: https://github.com/QwenLM/Qwen3-Coder/issues/180

[^18]: https://www.reddit.com/r/ollama/comments/1qyn1tc/help_qwen_25_coder_7b_stuck_on_json_responses/

[^19]: https://smollm3.com

[^20]: https://huggingface.co/unsloth/SmolLM3-3B-128K-GGUF/discussions/1

[^21]: https://huggingface.co/Jackrong/Qwopus3.5-27B-v3

[^22]: https://huggingface.co/mudler/Qwopus-MoE-35B-A3B-APEX-GGUF

[^23]: https://github.com/ollama/ollama/issues/14493

[^24]: https://huggingface.co/mistralai/Devstral-Small-2-24B-Instruct-2512

[^25]: https://mistral.ai/news/devstral-2-vibe-cli

[^26]: https://www.perplexity.ai/search/1e267ad7-c736-4db4-a472-c5917c7969a4

[^27]: https://apxml.com/models/qwen35-2b

[^28]: https://www.perplexity.ai/search/9f3b88a1-ac96-4253-9fce-287066eb0d2f

[^29]: https://huggingface.co/blog/smollm3

[^30]: https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-32B/discussions/6

[^31]: https://api-docs.deepseek.com/quick_start/parameter_settings

[^32]: https://www.reddit.com/r/LocalLLaMA/comments/1gpw8ls/bug_fixes_in_qwen_25_coder_128k_context_window/

[^33]: https://www.labellerr.com/blog/gemma-3/

[^34]: https://ollama.com/library/gemma4

[^35]: https://reeboot.fr/en/blog/gemma-4-31b

[^36]: https://ai.google.dev/gemma/docs/core

[^37]: https://huggingface.co/btbtyler09/Qwen3.5-35B-A3B-GPTQ-4bit

[^38]: https://hub.docker.com/r/ai/devstral-small

[^39]: https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md

[^40]: https://build.nvidia.com/mistralai/mistral-small-3_1-24b-instruct-2503/modelcard

[^41]: https://huggingface.co/mistralai/Mistral-Small-3.1-24B-Instruct-2503

[^42]: https://ai.google.dev/gemma/docs/capabilities/text/function-calling-gemma4

[^43]: https://github.com/vllm-project/recipes/blob/main/Google/Gemma4.md

[^44]: https://docs.vllm.ai/en/latest/api/vllm/tool_parsers/gemma4_tool_parser/

[^45]: https://www.reddit.com/r/LocalLLaMA/comments/1s3wlse/is_there_a_fix_to_tool_calling_issues_with_qwen/

[^46]: https://www.reddit.com/r/LocalLLaMA/comments/1rianwb/running_qwen35_27b_dense_with_170k_context_at/

[^47]: https://huggingface.co/mistralai/Mistral-Small-3.1-24B-Instruct-2503/discussions/63

[^48]: https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.3/discussions/35

[^49]: https://openrouter.ai/deepseek/deepseek-r1-distill-qwen-7b

[^50]: https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B/discussions/19

[^51]: https://www.reddit.com/r/LocalLLaMA/comments/1hl2rmk/where_is_qwen25_with_tool_training_and_128k/

[^52]: https://gemmai4.com/specs/

[^53]: https://huggingface.co/google/gemma-4-31B

[^54]: https://sonusahani.com/blogs/qwen-08b-vs-2b-vs-4b-vs-9b

[^55]: https://apxml.com/models/qwen35-35b-a3b

[^56]: https://www.digitalapplied.com/blog/qwen-3-5-medium-model-series-benchmarks-pricing-guide

[^57]: https://lmstudio.ai/models/deepseek/deepseek-r1-distill-qwen-7b

[^58]: https://github.com/deepseek-ai/DeepSeek-R1/issues/458

[^59]: https://developer.puter.com/ai/mistralai/devstral-small-2507/

[^60]: https://www.azion.com/en/documentation/products/ai/ai-inference/models/mistral-3-small/

[^61]: https://build.nvidia.com/mistralai/mistral-small-24b-instruct/modelcard

[^62]: https://trilogyai.substack.com/p/deep-dive-qwen-35-brings-native-multimodality

[^63]: https://arxiv.org/pdf/2501.12948.pdf

[^64]: http://arxiv.org/pdf/2407.07726v1.pdf

[^65]: https://arxiv.org/pdf/2404.01331.pdf

[^66]: https://arxiv.org/html/2504.01081v1

[^67]: https://arxiv.org/html/2503.19786

[^68]: https://arxiv.org/abs/2412.03555

[^69]: https://arxiv.org/pdf/2406.11409.pdf

[^70]: https://arxiv.org/html/2412.10893v1

[^71]: https://arxiv.org/pdf/2403.08295.pdf

[^72]: https://deepmind.google/models/gemma/gemma-4/

[^73]: https://www.mindstudio.ai/blog/gemma-4-e2b-e4b-edge-models-phone-local/

[^74]: https://www.techtarget.com/searchenterpriseai/definition/Gemma

[^75]: https://www.reddit.com/r/LocalLLaMA/comments/1ryc3w0/my_experience_with_qwen_35_35b/

[^76]: https://www.reddit.com/r/LocalLLaMA/comments/1sagulj/in_anticipation_of_gemma_4s_release_how_was_your/

[^77]: https://blog.salad.com/qwen-3-5-small-models-on-saladcloud-benchmarks-cost-and-why-you-dont-need-a-mac-mini/

[^78]: https://arxiv.org/abs/2505.19433

[^79]: https://arxiv.org/abs/2511.06719

[^80]: https://www.semanticscholar.org/paper/7bc7cd4b19f8bc827ba83f6202704158a9777c3a

[^81]: https://www.semanticscholar.org/paper/b15d3d78703a5a9b47b4ccc8fc0769257f69ab2b

[^82]: http://arc.aiaa.org/doi/10.2514/6.2002-5621

[^83]: http://arxiv.org/pdf/2404.18416.pdf

[^84]: http://arxiv.org/pdf/2402.16617.pdf

[^85]: http://arxiv.org/pdf/2405.09798.pdf

[^86]: http://arxiv.org/pdf/2407.11963.pdf

[^87]: https://huggingface.co/blog/gemma4

[^88]: https://www.linkedin.com/posts/addyosmani_introducing-gemma-4-googles-new-family-activity-7445501641933357056-8W6I

[^89]: https://docs.vllm.ai/projects/recipes/en/latest/Google/Gemma4.html

[^90]: https://wavespeed.ai/blog/posts/what-is-google-gemma-4/

[^91]: https://www.reddit.com/r/LocalLLaMA/comments/1sazp6w/google_strongly_implies_the_existence_of_large/

[^92]: https://www.instagram.com/reel/DWrJDYTGAn6/

[^93]: https://www.reddit.com/r/LocalLLaMA/comments/1rn59iv/testing_benchmarking_qwen35_2k400k_context_limit/

[^94]: http://arxiv.org/pdf/2404.14219.pdf

[^95]: https://arxiv.org/pdf/2502.13923.pdf

[^96]: http://arxiv.org/pdf/2502.16274.pdf

[^97]: https://arxiv.org/pdf/2309.16609.pdf

[^98]: https://arxiv.org/pdf/2412.15115.pdf

[^99]: https://arxiv.org/pdf/2407.10759.pdf

[^100]: https://arxiv.org/html/2403.04652v1

[^101]: https://huggingface.co/Qwen/Qwen3.5-27B

[^102]: https://qwen.ai/blog?id=qwen3.5

[^103]: https://llm-stats.com/models/compare/deepseek-r1-distill-qwen-7b-vs-deepseek-v3.2-exp

[^104]: https://docs.api.nvidia.com/nim/reference/deepseek-ai-deepseek-r1-distill-qwen-7b

[^105]: https://qwenlm.github.io/blog/qwen2.5-turbo/

[^106]: https://www.reddit.com/r/LocalLLaMA/comments/1rnwiyx/qwen_35_27b_is_the_real_deal_beat_gpt5_on_my/

[^107]: https://milvus.io/ai-quick-reference/what-is-the-context-window-size-of-deepseeks-models

[^108]: http://arxiv.org/pdf/2407.14482.pdf

[^109]: https://arxiv.org/html/2407.13739v1

[^110]: https://arxiv.org/pdf/2408.11775.pdf

[^111]: https://arxiv.org/pdf/2402.13753.pdf

[^112]: http://arxiv.org/pdf/2310.16450.pdf

[^113]: http://arxiv.org/pdf/2503.15450.pdf

[^114]: https://arxiv.org/pdf/2502.20082.pdf

[^115]: https://arxiv.org/pdf/2401.06951.pdf

[^116]: https://smollm3.org

[^117]: https://www.facebook.com/groups/DeepNetGroup/posts/2532652297127637/

[^118]: https://huggingface.co/HuggingFaceTB/SmolLM3-3B

[^119]: https://learnopencv.com/smollm3-explained/

[^120]: https://ollama.com/alibayram/smollm3

[^121]: https://mistral.ai/news/mistral-small-3-1

[^122]: https://mlops.substack.com/p/smollm3-from-huggingface

[^123]: https://unsloth.ai/docs/models/tutorials/devstral-2

[^124]: https://arxiv.org/pdf/2501.15383.pdf

[^125]: https://arxiv.org/pdf/2306.15595.pdf

[^126]: https://ollama.com/library/qwen3.5:27b-q4_K_M

[^127]: https://github.com/ollama/ollama/issues/10361

[^128]: https://composio.dev/content/qwq-32b-vs-gemma-3-mistral-small-vs-deepseek-r1

[^129]: https://developer.puter.com/ai/qwen/qwen3.5-35b-a3b/

[^130]: https://www.reddit.com/r/LocalLLaMA/comments/1red1u6/qwen3527b_dense_vs_35ba3b_moe_which_one_for_tool/

[^131]: https://www.latent.space/p/ainews-the-high-return-activity-of

[^132]: https://build.nvidia.com/google/gemma-4-31b-it/modelcard

[^133]: https://www.elvex.com/blog/context-length-comparison-ai-models-2026

[^134]: https://www.semanticscholar.org/paper/cfe33b869e5e1976f8294d1610ee9314698c38dd

[^135]: https://www.semanticscholar.org/paper/febb0d38c39219f39d5325345882b5148a84b79e

[^136]: https://arxiv.org/abs/2511.03728

[^137]: https://www.semanticscholar.org/paper/df9e2434b54de2163fe4f68cdf314c99dc6324cb

[^138]: https://arxiv.org/abs/2409.02141

[^139]: https://arxiv.org/abs/2508.04664

[^140]: https://arxiv.org/abs/2601.14351

[^141]: https://arxiv.org/html/2410.03439

[^142]: http://arxiv.org/pdf/2406.17465.pdf

[^143]: https://arxiv.org/pdf/2409.02141.pdf

[^144]: https://arxiv.org/pdf/2407.04997.pdf

[^145]: https://arxiv.org/pdf/2305.11554.pdf

[^146]: https://arxiv.org/pdf/2403.00839.pdf

[^147]: https://www.reddit.com/r/LocalLLaMA/comments/1lusr7l/smollm3_reasoning_long_context_and/

[^148]: https://www.linkedin.com/posts/jenweiprofile_smollm3-smol-multilingual-long-context-activity-7349090108039458817-3T2D

[^149]: https://www.secondstate.io/articles/smollm3/

[^150]: https://www.reddit.com/r/ollama/comments/1mn5uvk/devstral24b/

[^151]: https://arxiv.org/pdf/2406.12793.pdf

[^152]: https://arxiv.org/pdf/2404.12195.pdf

[^153]: http://arxiv.org/pdf/2412.08347.pdf

[^154]: http://arxiv.org/pdf/2404.06395.pdf

[^155]: http://arxiv.org/pdf/2405.20314.pdf

[^156]: http://arxiv.org/pdf/2502.15814.pdf

[^157]: https://arxiv.org/html/2504.05299v1

[^158]: https://arxiv.org/pdf/2309.11568.pdf

[^159]: https://huggingface.co/HuggingFaceTB/SmolLM3-3B-Base

[^160]: https://huggingface.co/HuggingFaceTB/SmolLM3-3B-ONNX

[^161]: https://huggingface.co/HuggingFaceTB/SmolLM3-3B/discussions/46

[^162]: https://huggingface.co/unsloth/SmolLM3-3B-128K-GGUF/blame/a97297cba456de0b81d32b416cc914ff51426406/SmolLM3-3B-128K-UD-IQ1_S.gguf

[^163]: https://huggingface.co/unsloth/Mistral-Small-3.1-24B-Base-2503

[^164]: https://huggingface.co/mistralai/Devstral-Small-2507

[^165]: https://huggingface.co/unsloth/SmolLM3-3B-128K-GGUF/blame/a97297cba456de0b81d32b416cc914ff51426406/SmolLM3-3B-128K-UD-Q8_K_XL.gguf

[^166]: https://rits.shanghai.nyu.edu/ai/exploring-devstral-small-1-1-2507-by-mistral-ai-a-new-leader-in-open-source-coding-models/

[^167]: https://huggingface.co/unsloth/SmolLM3-3B-128K-GGUF/blob/a97297cba456de0b81d32b416cc914ff51426406/SmolLM3-3B-128K-BF16.gguf

[^168]: https://docs.api.nvidia.com/nim/reference/mistralai-mistral-small-3_1-24b-instruct-2503

[^169]: https://arxiv.org/abs/2510.03847

[^170]: https://arxiv.org/abs/2506.01369

[^171]: https://arxiv.org/abs/2502.11164

[^172]: https://arxiv.org/pdf/2503.10460.pdf

[^173]: https://arxiv.org/pdf/2503.00624.pdf

[^174]: http://arxiv.org/pdf/2502.17807.pdf

[^175]: https://arxiv.org/html/2504.04713v2

[^176]: http://arxiv.org/pdf/2503.20783.pdf

[^177]: https://arxiv.org/html/2503.16385

[^178]: https://www.bentoml.com/blog/the-complete-guide-to-deepseek-models-from-v3-to-r1-and-beyond

[^179]: https://aws.amazon.com/blogs/machine-learning/optimize-hosting-deepseek-r1-distilled-models-with-hugging-face-tgi-on-amazon-sagemaker-ai/

[^180]: https://huggingface.co/Qwen/Qwen2.5-7B-Instruct

[^181]: https://huggingface.co/Qwen/Qwen3.5-4B

[^182]: https://ollama.com/MFDoom/deepseek-r1-tool-calling:7b-qwen-distill-q4_K_M/blobs/d86a077a82d0

[^183]: https://www.mdpi.com/2076-3417/16/7/3166

[^184]: https://pathsocjournals.onlinelibrary.wiley.com/doi/10.1002/path.70029

[^185]: https://www.semanticscholar.org/paper/2ae5c68749eb147c38806b93e64b058634dbdf85

[^186]: https://arxiv.org/pdf/2310.09478.pdf

[^187]: https://arxiv.org/pdf/2404.07654.pdf

[^188]: https://arxiv.org/pdf/2308.12950.pdf

[^189]: https://arxiv.org/pdf/2305.17126.pdf

[^190]: https://arxiv.org/pdf/2403.05525.pdf

[^191]: https://ollama.com/blog/tool-support

[^192]: https://ollama.com/unitythemaker/llama3.2-vision-tools/blobs/966de95ca8a6

[^193]: https://docs.ollama.com/capabilities/tool-calling

[^194]: https://www.reddit.com/r/openclaw/comments/1sbxygz/ollama_models_and_vision_capability/

[^195]: https://github.com/ollama/ollama/issues/9727

[^196]: https://www.reddit.com/r/LocalLLaMA/comments/1lph2zh/tool_calling_with_llamacpp/

[^197]: https://www.youtube.com/watch?v=bzpRIF2Q16c

[^198]: https://node-llama-cpp.withcat.ai/guide/chat-wrapper

[^199]: https://www.youtube.com/watch?v=tz_-fsxL3Js

[^200]: https://ollama.com/search?c=vision

[^201]: https://www.reddit.com/r/LocalLLaMA/comments/1r6m13c/qwencodernext_fp8_chat_template_for_llamacpp/

[^202]: https://docs.servicestack.net/ai-server/llama-server

[^203]: https://github.com/ggml-org/llama.cpp/issues/20198

[^204]: https://github.com/abetlen/llama-cpp-python/issues/1772

[^205]: https://arxiv.org/abs/2404.01549

[^206]: https://www.semanticscholar.org/paper/85ab9ad71791a251bec7c93a7a25c0824f04e22c

[^207]: https://linkinghub.elsevier.com/retrieve/pii/S0010465509002069

[^208]: https://www.semanticscholar.org/paper/9df0f86fe893272b39dfee92dcb8fe91f1c184de

[^209]: https://www.semanticscholar.org/paper/a6c4f99978d46ebfa71b1e7083d74496f2f691d2

[^210]: https://www.semanticscholar.org/paper/2ea6860b1c23b06b7cd789ede3e704b4c6bec18b

[^211]: https://www.semanticscholar.org/paper/983414696846293dec3723709a1d03801b18f0ec

[^212]: https://www.semanticscholar.org/paper/0876051722b46a18abe37c771e0e0c0b8f5a50c9

[^213]: http://link.springer.com/10.1007/978-1-4471-0929-7

[^214]: https://www.semanticscholar.org/paper/fe721a82fa6ad55ab0af4d355aef9026399c4103

[^215]: https://arxiv.org/pdf/2310.07075.pdf

[^216]: https://arxiv.org/pdf/2407.00121.pdf

[^217]: http://arxiv.org/pdf/2412.01130.pdf

[^218]: http://arxiv.org/pdf/2411.15399.pdf

[^219]: http://arxiv.org/pdf/2501.12432.pdf

[^220]: https://lushbinary.com/blog/build-ai-agent-gemma-4-function-calling-mcp-tool-use/

[^221]: https://ai.google.dev/gemma/docs/capabilities/function-calling

[^222]: https://www.reddit.com/r/LocalLLaMA/comments/1jauy8d/giving_native_tool_calling_to_gemma_3_or_really/

[^223]: https://www.distillabs.ai/blog/making-functiongemma-work-multi-turn-tool-calling-at-270m-parameters/

[^224]: https://www.linkedin.com/pulse/functiongemma-googles-tool-calling-model-makes-agents-gowtam-singulur-twuic

[^225]: https://www.youtube.com/watch?v=8jBX3RatIus

[^226]: https://www.philschmid.de/gemma-function-calling

[^227]: http://arxiv.org/pdf/2412.12735.pdf

[^228]: https://arxiv.org/pdf/2502.16137.pdf

[^229]: http://arxiv.org/pdf/2503.06692.pdf

[^230]: http://arxiv.org/pdf/2406.07588.pdf

[^231]: https://aclanthology.org/2023.acl-long.352.pdf

[^232]: https://qwenlm.github.io/blog/qwen3/

[^233]: https://www.reddit.com/r/LocalLLaMA/comments/1riyfg2/qwen35_model_series_thinking_onoff_does_it_matter/

[^234]: https://huggingface.co/docs/transformers/model_doc/qwen3_5_moe

[^235]: https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct

[^236]: https://huggingface.co/Qwen/Qwen3.5-27B/discussions/5

[^237]: https://huggingface.co/Qwen/Qwen3-235B-A22B

[^238]: https://www.reddit.com/r/LocalLLaMA/comments/1rirlyb/qwenqwen359b_hugging_face/

[^239]: https://www.reddit.com/r/LocalLLaMA/comments/1rdlbvc/qwenqwen3535ba3b_hugging_face/

[^240]: http://arxiv.org/pdf/2412.15660.pdf

[^241]: https://arxiv.org/pdf/2409.12186.pdf

[^242]: https://openrouter.ai/qwen/qwen2.5-coder-7b-instruct

[^243]: https://www.emergentmind.com/topics/qwen-2-5-7b-instruct-edce8707-861f-4786-9a31-d4dce966ad24

[^244]: https://apxml.com/models/qwen2-5-7b

[^245]: https://www.reddit.com/r/LocalLLaMA/comments/1sa7jo2/has_anyone_used/

[^246]: https://www.youtube.com/watch?v=fWBnJ_5U6A4

