<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

### 1. Where Models Agree

| Finding | GPT-5.4 Thinking | Claude Opus 4.6 Thinking | Gemini 3.1 Pro Thinking | Evidence |
| :-- | :-- | :-- | :-- | :-- |
| Your local stack should be **tiered by hardware**, not “one best model” | ✓ | ✓ | ✓ | 18GB vs 32GB+ constraints and different best fits per tier[^1] |
| **Gemma 4 31B** is generally **too large/tight for 18GB** at common 4-bit targets | ✓ | ✓ | ✓ | Gemma 4 31B needs ~20GB at 4-bit (guidance), while 26B-A4B is the “18GB @ 4-bit” sweet spot |
| **Qwopus3.5-27B-v3** is the best pick in your list for **coding / reasoning-heavy text** | ✓ | ✓ | ✓ | Qwopus v3 is positioned as reasoning + programming focused, with strong self-reported strict eval results[^2][^3] |
| **Qwopus-MoE-35B-A3B** is the best “big sparse brain” to include for **bigger machines**, but not for your 18GB Mac | ✓ | ✓ | ✓ | 35B total / ~3B active; GGUF Q4_K_M is ~20GB min VRAM, i.e., above 18GB headroom[^1][^4] |
| For broad compatibility, **standard GGUF (llama.cpp/Ollama)** artifacts are the safest defaults; exotic formats are optional | ✓ | ✓ | ✓ | Qwopus GGUF exists as the straightforward path; PolarQuant/TurboQuant require extra/runtime-specific support assumptions[^5][^6] |


***

### 2. Where Models Disagree

| Topic | GPT-5.4 Thinking | Claude Opus 4.6 Thinking | Gemini 3.1 Pro Thinking | Why They Differ |
| :-- | :-- | :-- | :-- | :-- |
| Best **general-purpose** model from your list for your Mac | Prefer Gemma-4-21B-A4B **REAP** overall | Uses **Qwopus 27B GGUF Q4** as “primary reasoning” + REAP as “fast multimodal” | Strongly prefers **REAP** as the best general-use for 18GB | GPT-5.4/Gemini weight MoE efficiency for your 18GB ceiling more heavily; Claude prioritizes “one daily driver” for coding/tool-calling[^7][^8] |
| Best Qwopus quant for your 18GB Mac | Favor **official GGUF** as default; TQ3_4S as optional | Suggests **Q4_K_M GGUF** as main; TQ3_4S for long-context | Pushes **TQ3_4S** as MVP because Q4_K_M is too tight | They assume different “usable RAM” on macOS and different tolerance for tight headroom vs stability[^5][^9] |
| How to treat **Gemma-4-31B-JANG_4M-CRACK** | “Optional uncensored, not default” | “Optional uncensored, not default” | Recommends it as a Tier-2 power-user option (32GB+) | All agree it’s not a default; Gemini is more positive about offering it to power users, while others emphasize UX/safety predictability[^10][^11] |
| Whether to include **NVIDIA NVFP4** in your catalog | Yes (for CUDA users), but not for Mac | Yes (GPU tier), warns it’s NVIDIA-only | Says “avoid for macOS,” keep for Nvidia PCs | Difference is framing: “include but gated” vs “avoid for your dev platform,” but practically they converge: it’s for Nvidia/vLLM class hardware[^12][^13] |


***

### 3. Unique Discoveries

| Model | Unique Finding | Why It Matters |
| :-- | :-- | :-- |
| Claude Opus 4.6 Thinking | Calls out **mudler/Qwopus-MoE-35B-A3B-APEX-GGUF** as a potentially better-calibrated MoE quant path | APEX/imatrix-style MoE-aware quants can be meaningfully better than generic Q4/Q5 for MoE reliability[^14] |
| GPT-5.4 Thinking | Recommends keeping **PolarQuant** as an “optional accelerated backend,” not a canonical distribution | Helps you avoid shipping a format that some users can’t run without extra deps (e.g., polarengine_vllm)[^6] |
| Gemini 3.1 Pro Thinking | Warns macOS effective “usable VRAM” can be lower than total unified memory, so “tight-fit” models can degrade badly via swap | Useful when deciding default downloads for 16–18GB Macs: stability beats theoretical fit |


***

### 4. Comprehensive Analysis

**High-Confidence Findings.** All three models converge on the key product decision: you should ship a **hardware-tiered local model catalog** rather than trying to crown one “best” model. Your 18GB M2 Pro target is a hard constraint (and macOS overhead makes “barely fits” models painful), while your users may have 32GB/64GB+ laptops where heavier models become viable. That means your app should: (1) detect RAM/VRAM constraints, (2) recommend a default per tier, and (3) offer “power user” downloads separately.

They also agree that **Gemma 4 31B** is generally not a comfortable fit for 18GB in typical 4-bit deployments. Unsloth’s sizing guidance is blunt: Gemma-4-26B-A4B is the “18GB @ 4-bit” class, while Gemma-4-31B tends to want ~20GB even at 4-bit. Practically, that means **don’t make 31B your default local experience** on your dev machine (and likely not on 16–18GB Macs in general).

For the “coding + reasoning text brain,” all three converge on **Qwopus3.5-27B-v3** as the standout from your list. Its model card explicitly frames the v3 training goal as improving reasoning stability/correctness and programming generalization, and it reports strong strict eval results (self-reported, but consistent across its repos). This makes it a strong candidate for: code generation, refactors, bug diagnosis, and agent loops that need coherent multi-step reasoning.[^2][^3]

Finally, they agree that **Qwopus-MoE-35B-A3B** belongs in your catalog for larger machines, but not as a “works everywhere” default. The GGUF quant table shows Q4_K_M at ~20GB minimum VRAM and larger quants above that, which makes it an excellent “32GB+ tier” model for fast agentic loops (3B active), but not an 18GB-safe default.[^1]

**Areas of Divergence.** The main disagreement is not about “which models are good,” but about **what is safe on your M2 Pro 18GB**. Claude Opus 4.6 Thinking is more willing to treat **Qwopus 27B GGUF Q4_K_M (~16.6GB)** as a primary local driver, while Gemini 3.1 Pro Thinking is more cautious and pushes **TQ3_4S (~12.9GB)** as the practical default to preserve headroom (KV cache + app memory + macOS overhead). If Epistemos is running a large UI + embeddings/RAG + background indexing, Gemini’s caution will likely translate into fewer “random slowdowns” and fewer OOM edge cases.[^5][^9]

A second divergence is how much to center **REAP** (gemma-4-21b-a4b-it-REAP). GPT-5.4 Thinking and Gemini 3.1 Pro Thinking treat REAP as the best “general assistant” option for your specific machine because it keeps MoE-style ~4B active compute while trimming total footprint. Claude still likes REAP, but frames Qwopus 27B as the primary reasoning/tool-calling brain and REAP as a fast multimodal companion. In practice you can reconcile this by routing: **Qwopus for coding/tool calls**, **REAP (or Gemma MoE) for general chat + multimodal**.[^7]

**Unique Insights Worth Noting.** Claude’s mention of **APEX-style MoE GGUFs** is worth taking seriously if your goal is “best possible local stack,” because MoE quantization quality can vary a lot, and MoE-aware calibration can improve stability. Meanwhile, GPT-5.4’s warning about **PolarQuant** being a backend-dependent format is a real product concern: it may be great for some GPU/vLLM users, but it’s risky as your “default downloadable model” if you want broad Ollama/llama.cpp compatibility.[^14][^6]

**Recommendations (actionable).** If you want the “best possible stack” *from the models you linked*, I’d implement these defaults:

- **Tier 1 (16–18GB Macs / your M2 Pro):**
    - **General assistant:** `0xSero/gemma-4-21b-a4b-it-REAP` via a good GGUF Q4 (~13GB class).[^8][^7]
    - **Coding / tool-calling:** `Qwopus3.5-27B-v3` in a smaller GGUF (TQ3_4S for headroom, or Q4_K_M if you confirm it’s stable in your app).[^9][^5]
- **Tier 2 (24–32GB):**
    - **Fast agent brain:** `samuelcardillo/Qwopus-MoE-35B-A3B-GGUF` (Q4_K_M or better).[^1]
- **Tier 3 (NVIDIA workstations / 48GB+ VRAM):**
    - **High-confidence Gemma 31B quant:** `nvidia/Gemma-4-31B-IT-NVFP4` (gated to Nvidia/vLLM users).[^12]
    - **Optional uncensored:** `Gemma-4-31B-JANG_4M-CRACK` as opt-in only.[^10][^11]

If you paste your **current local model list** (what you’re replacing) and tell me whether your local runtime is primarily **MLX**, **llama.cpp**, or **Ollama**, I can turn this into a concrete “model routing + download catalog + default quants per RAM tier” plan.
<span style="display:none">[^100][^101][^102][^103][^104][^105][^106][^107][^108][^109][^110][^111][^112][^113][^114][^115][^116][^117][^118][^119][^120][^121][^122][^123][^124][^125][^126][^127][^128][^129][^130][^131][^132][^133][^134][^135][^136][^137][^138][^139][^140][^141][^142][^143][^144][^145][^146][^147][^148][^149][^15][^150][^151][^152][^153][^154][^155][^156][^157][^158][^159][^16][^160][^161][^162][^163][^164][^165][^166][^167][^168][^169][^17][^170][^171][^172][^173][^174][^175][^176][^177][^178][^179][^18][^180][^181][^182][^183][^184][^185][^186][^187][^188][^189][^19][^190][^191][^192][^193][^194][^195][^196][^197][^198][^199][^20][^200][^201][^202][^203][^204][^205][^206][^207][^208][^209][^21][^210][^211][^212][^213][^214][^215][^216][^22][^23][^24][^25][^26][^27][^28][^29][^30][^31][^32][^33][^34][^35][^36][^37][^38][^39][^40][^41][^42][^43][^44][^45][^46][^47][^48][^49][^50][^51][^52][^53][^54][^55][^56][^57][^58][^59][^60][^61][^62][^63][^64][^65][^66][^67][^68][^69][^70][^71][^72][^73][^74][^75][^76][^77][^78][^79][^80][^81][^82][^83][^84][^85][^86][^87][^88][^89][^90][^91][^92][^93][^94][^95][^96][^97][^98][^99]</span>

<div align="center">⁂</div>

[^1]: https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B-GGUF

[^2]: https://huggingface.co/Jackrong/Qwopus3.5-27B-v3

[^3]: https://huggingface.co/Jackrong/Qwopus3.5-27B-v3-GGUF

[^4]: https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B-GGUF/blob/f920508e4900239d4e9db67e677494d017bdaff4/README.md

[^5]: https://huggingface.co/YTan2000/Qwopus3.5-27B-v3-TQ3_4S

[^6]: https://huggingface.co/caiovicentino1/Qwopus3.5-27B-v3-PolarQuant-Q5

[^7]: https://huggingface.co/0xSero/gemma-4-21b-a4b-it-REAP

[^8]: https://huggingface.co/saria-lh/gemma-4-21b-a4b-it-REAP-Q4_K_M-GGUF

[^9]: https://huggingface.co/mradermacher/Qwopus3.5-27B-v3-GGUF

[^10]: https://huggingface.co/dealignai/Gemma-4-31B-JANG_4M-CRACK

[^11]: https://huggingface.co/douyamv/Gemma-4-31B-JANG_4M-CRACK-GGUF

[^12]: https://huggingface.co/nvidia/Gemma-4-31B-IT-NVFP4

[^13]: https://www.reddit.com/r/LocalLLaMA/comments/1sbivxj/gemma431b_nvfp4_inference_numbers_on_1x_rtx_pro/

[^14]: https://huggingface.co/mudler/Qwopus-MoE-35B-A3B-APEX-GGUF

[^15]: https://huggingface.co/google/gemma-4-31B-it

[^16]: https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B

[^17]: https://unsloth.ai/docs/models/gemma-4

[^18]: https://huggingface.co/google/gemma-4-26B-A4B

[^19]: https://x.com/huggingface/status/2040033271237497056

[^20]: https://huggingface.co/nvidia/Gemma-4-31B-IT-NVFP4/discussions/3

[^21]: https://huggingface.co/Ayodele01/gemma-4-21b-a4b-it-REAP-GGUF

[^22]: https://huggingface.co/Intel/gemma-4-31B-it-int4-AutoRound

[^23]: https://forums.developer.nvidia.com/t/how-to-run-gemma-4-nvfp4-in-vllm-docker/365513

[^24]: https://x.com/0x0SojalSec/status/2040525896629858613

[^25]: https://sudoall.com/gemma-4-31b-apple-silicon-local-guide/

[^26]: https://kaitchup.substack.com/p/gemma-4-31b-and-26b-a4b-architecture

[^27]: https://www.millstoneai.com/inference-benchmark/gemma-4-31b-nvfp4-1x-rtx-pro-6000-blackwell

[^28]: https://forums.developer.nvidia.com/t/gemma-4-day-1-inference-on-nvidia-dgx-spark-preliminary-benchmarks/365503

[^29]: https://www.reddit.com/r/LocalLLaMA/comments/1sa7jo2/has_anyone_used/

[^30]: https://github.com/ollama/ollama/issues/14493

[^31]: https://huggingface.co/Qwen/Qwen3.5-27B

[^32]: https://x.com/TheExplorerecho?lang=ar

[^33]: https://www.reddit.com/r/LocalLLaMA/comments/1sarr9x/turbo_quant_qwopus35_in_action/

[^34]: https://www.theneuron.ai/explainer-articles/google-shipped-more-ai-in-one-day-than-most-companies-ship-in-a-quarter-heres-what-it-all-means-/

[^35]: https://huggingface.co/Qwen/Qwen3.5-35B-A3B

[^36]: https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B-GGUF/commit/b17d7c8eb29b3171fb6d66c820ffe0eca88b0f57

[^37]: https://dev.to/plasmon_imp/moe-beat-dense-27b-by-24x-on-8gb-vram-the-35b-a3b-benchmark-nobody-expected-24n

[^38]: https://vertu.com/ai-tools/qwen-3-5-27b-vs-qwen-3-5-35b-a3b-which-local-llm-reigns-supreme/

[^39]: https://x.com/coffeecup2020/status/2039789461521715646

[^40]: https://x.com/harshil1712/status/2039717963595399392

[^41]: https://huggingface.co/models?other=base_model%3Aquantized%3AJackrong%2FQwopus3.5-27B-v3

[^42]: https://x.com/BrianRoemmele/status/2040656830385586432

[^43]: https://x.com/HarshithLucky3/status/2040694241182277919

[^44]: https://huggingface.co/RedHatAI/gemma-4-31B-it-NVFP4

[^45]: https://huggingface.co/0xSero/gemma-4-21b-a4b-it-REAP/discussions/2

[^46]: https://x.com/ukint_vs/status/2041085867201315001

[^47]: https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B-GGUF/blob/main/Qwopus-MoE-35B-A3B-Q6_K.gguf

[^48]: https://huggingface.co/mlx-community/gemma-4-26b-a4b-it-4bit

[^49]: https://dev.to/dentity007/-gemma-4-after-24-hours-what-the-community-found-vs-what-google-promised-3a2f

[^50]: https://www.reddit.com/r/LocalLLaMA/comments/1scjoox/gemma4_26b_a4b_runs_easily_on_16gb_macs/

[^51]: https://benchlm.ai/compare/claude-4-1-opus-vs-qwen3-5-27b

[^52]: https://www.reddit.com/r/LocalLLM/comments/1sddegt/benchmarking_speculative_decoding_between/

[^53]: https://arxiv.org/pdf/2406.11409.pdf

[^54]: https://arxiv.org/html/2404.07839

[^55]: https://arxiv.org/pdf/2404.01331.pdf

[^56]: http://arxiv.org/pdf/2407.07726v1.pdf

[^57]: https://arxiv.org/pdf/2308.12950.pdf

[^58]: https://arxiv.org/pdf/2411.09543.pdf

[^59]: https://arxiv.org/pdf/2503.02656.pdf

[^60]: https://arxiv.org/pdf/2407.21772.pdf

[^61]: https://huggingface.co/0xSero/gemma-4-21b-a4b-it-REAP/discussions

[^62]: https://huggingface.co/models?other=base_model%3Aquantized%3A0xSero%2Fgemma-4-21b-a4b-it-REAP

[^63]: https://huggingface.co/0xSero/gemma-4-21b-a4b-it-REAP/tree/main

[^64]: https://nahornyi.ai/en/news/gemma-4-21b-reap-strong-open-weight-candidate

[^65]: https://llm-explorer.com/model/Jackrong%2FQwopus3.5-27B-v3,7u8dwQoGAeKlL9UbffJIjQ

[^66]: https://x.com/0xSero/status/2041151467306823717

[^67]: https://www.facebook.com/0xSojalSec/photos/new-king-of-local-uncensored-models-gemma-4-31b-jang_4m-crackfully-abliteration-/1484865943167804/

[^68]: https://www.reddit.com/r/LocalLLM/comments/1see8fg/gemma426ba4bitudq4_k_mgguf_imho_worst_model_ever/

[^69]: https://huggingface.co/botp/Gemma-4-31B-JANG_4M-CRACK/commit/be2970306fa4da1c6f1d7f9dfd1a4ec23feb435f

[^70]: https://huggingface.co/Jackrong/Qwopus3.5-27B-v3-GGUF/tree/main

[^71]: https://www.youtube.com/watch?v=wWtrAzLxJ4c

[^72]: https://www.facebook.com/0xSojalSec/posts/new-king-of-local-uncensored-models-gemma-4-31b-jang_4m-crackfully-abliteration-/1484869573167441/

[^73]: https://link.springer.com/10.1007/s12672-025-02911-7

[^74]: https://www.mdpi.com/2227-9032/13/20/2652

[^75]: https://arxiv.org/abs/2510.16091

[^76]: https://www.semanticscholar.org/paper/29db094f3bd4757300167efd94286fca04921d73

[^77]: https://ieeexplore.ieee.org/document/10756443/

[^78]: https://www.semanticscholar.org/paper/bff8eaaa567812ead73a9bf2cc815f6425d758a7

[^79]: https://ascopubs.org/doi/10.1200/CCI-25-00194

[^80]: https://www.semanticscholar.org/paper/13918bc58496a456153e9bf608572aa8c84c1c1f

[^81]: https://ieeexplore.ieee.org/document/11011410/

[^82]: https://ieeexplore.ieee.org/document/11203269/

[^83]: https://arxiv.org/pdf/2502.20868.pdf

[^84]: http://arxiv.org/pdf/2406.11775.pdf

[^85]: https://arxiv.org/pdf/2309.08448.pdf

[^86]: http://arxiv.org/pdf/2502.14382.pdf

[^87]: http://arxiv.org/pdf/2408.07990.pdf

[^88]: http://arxiv.org/pdf/2407.13511.pdf

[^89]: http://arxiv.org/pdf/2308.07317.pdf

[^90]: http://arxiv.org/pdf/2307.06281.pdf

[^91]: https://www.reddit.com/r/LocalLLaMA/comments/1sbbibz/has_anyone_tried_jackrongqwopus3527bv3_with_vllm/

[^92]: https://www.youtube.com/watch?v=fWBnJ_5U6A4

[^93]: https://composio.dev/content/qwq-32b-vs-gemma-3-mistral-small-vs-deepseek-r1

[^94]: https://benchlm.ai/compare/gemma-3-27b-vs-qwen3-5-27b

[^95]: https://llm-stats.com/models/qwen3.5-27b

[^96]: https://x.com/search?q=CXOBE+Review+sharp+analysis.qpu

[^97]: https://www.labellerr.com/blog/gemma-4-open-weight-ai-model-overview/amp/

[^98]: https://x.com/CardilloSamuel/status/2041011451502952642

[^99]: https://artificialanalysis.ai/models/qwen3-5-27b

[^100]: https://dev.to/gaurav_vij137/i-ran-googles-latest-gemma-4-models-on-48gb-gpu-heres-what-actually-happened-5d3d

[^101]: https://arxiv.org/pdf/2406.12793.pdf

[^102]: http://arxiv.org/pdf/2409.11402.pdf

[^103]: https://arxiv.org/pdf/2306.00978.pdf

[^104]: https://arxiv.org/html/2503.12964v1

[^105]: https://arxiv.org/pdf/2408.00118.pdf

[^106]: http://arxiv.org/pdf/2503.06862.pdf

[^107]: https://huggingface.co/nvidia/Gemma-4-31B-IT-NVFP4/discussions

[^108]: https://huggingface.co/nvidia/Gemma-4-31B-IT-NVFP4/tree/main

[^109]: https://build.nvidia.com/google/gemma-4-31b-it/modelcard

[^110]: https://x.com/bnjmn_marie/status/2041163708945010902

[^111]: https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B/blob/0c8fa941350570eaeeb674f07ab2539e6b51fb6c/README.md

[^112]: https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B/tree/0c8fa941350570eaeeb674f07ab2539e6b51fb6c

[^113]: https://huggingface.co/nvidia/Gemma-4-31B-IT-NVFP4/commits/main

[^114]: https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B/tree/ef0e3a39f39a42f5222ef9fbb598fb7823ba3d1d

[^115]: https://huggingface.co/nvidia/Gemma-4-31B-IT-NVFP4/discussions/1

[^116]: https://x.com/TheAhmadOsman/status/2041302445171552743

[^117]: https://huggingface.co/caiovicentino1/Qwopus-MoE-35B-A3B-PolarQuant-Q5

[^118]: https://huggingface.co/caiovicentino1

[^119]: https://huggingface.co/caiovicentino1/Qwopus-MoE-35B-A3B-PolarQuant-Q5/tree/main

[^120]: https://huggingface.co/caiovicentino1/Huihui-Qwopus3.5-27B-v3-abliterated-PolarQuant-Q5

[^121]: https://huggingface.co/caiovicentino1/Huihui-Qwopus3.5-27B-v3-abliterated-PolarQuant-Q5/commits/main/assets

[^122]: https://www.reddit.com/r/LocalLLaMA/comments/1rgel19/new_qwen3535ba3b_unsloth_dynamic_ggufs_benchmarks/

[^123]: https://huggingface.co/caiovicentino1/Qwopus3.5-27B-v3-PolarQuant-Q5/commit/76f830c5bb4c8117446a261afaa8759241557d95

[^124]: https://huggingface.co/YTan2000/Qwopus3.5-27B-v3-TQ3_4S/tree/main

[^125]: https://huggingface.co/caiovicentino1/Qwopus3.5-27B-v3-PolarQuant-Q5/commits/main

[^126]: https://huggingface.co/models?apps=llama.cpp\&other=base_model%3Aquantized%3AJackrong%2FQwopus3.5-27B-v3

[^127]: https://arxiv.org/pdf/2403.08295.pdf

[^128]: https://arxiv.org/html/2504.01081v1

[^129]: https://huggingface.co/toby1991/gemma-4-21b-a4b-it-REAP-oQ4/tree/main

[^130]: http://arxiv.org/pdf/2312.11805.pdf

[^131]: http://arxiv.org/pdf/2408.00307.pdf

[^132]: https://arxiv.org/pdf/2311.18743.pdf

[^133]: http://arxiv.org/pdf/2407.06542.pdf

[^134]: https://www.youtube.com/watch?v=JmCiKKw6bMA

[^135]: https://artificialanalysis.ai/models/gemma-4-31b

[^136]: https://www.youtube.com/watch?v=-3DmzBdUVm4

[^137]: http://arxiv.org/pdf/2406.09904.pdf

[^138]: https://arxiv.org/pdf/2402.11295.pdf

[^139]: http://arxiv.org/pdf/2406.08155.pdf

[^140]: https://arxiv.org/html/2504.02658v1

[^141]: https://arxiv.org/pdf/2411.16158.pdf

[^142]: https://arxiv.org/pdf/2409.17066.pdf

[^143]: http://arxiv.org/pdf/2502.12346.pdf

[^144]: https://arxiv.org/pdf/2211.10438.pdf

[^145]: https://huggingface.co/models?other=base_model%3Aquantized%3Asamuelcardillo%2FQwopus-MoE-35B-A3B-GGUF

[^146]: https://huggingface.co/mudler/Qwopus-MoE-35B-A3B-APEX-GGUF/blob/main/README.md

[^147]: https://github.com/ggml-org/llama.cpp/discussions/20969

[^148]: https://huggingface.co/cpatonn/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-AWQ-4bit

[^149]: https://huggingface.co/Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-GGUF

[^150]: https://www.youtube.com/watch?v=mkayQBhJRfM

[^151]: https://www.facebook.com/0xSojalSec/posts/googles-turboquant-in-llamacpp-with-metal-kernels-for-apple-silicon49-kv-cache-c/1478375070483558/

[^152]: https://www.youtube.com/watch?v=_lXgq-U49Aw

[^153]: https://arxiv.org/html/2503.19786

[^154]: https://arxiv.org/pdf/2309.09308.pdf

[^155]: https://arxiv.org/html/2504.07277v1

[^156]: https://www.reddit.com/r/LocalLLaMA/comments/1scbvu3/any_good_uncensored_models_for_gemma_4_26b/

[^157]: https://huggingface.co/botp/Gemma-4-31B-JANG_4M-CRACK/blob/main/jang_config.json

[^158]: http://arxiv.org/pdf/2404.01549.pdf

[^159]: http://arxiv.org/pdf/2411.15399.pdf

[^160]: http://arxiv.org/pdf/2403.07714.pdf

[^161]: https://arxiv.org/pdf/2304.08244.pdf

[^162]: https://aclanthology.org/2023.emnlp-main.187.pdf

[^163]: http://arxiv.org/pdf/2409.04617.pdf

[^164]: https://arxiv.org/pdf/2402.04253.pdf

[^165]: https://arxiv.org/pdf/2412.16516.pdf

[^166]: https://huggingface.co/Jackrong/Qwopus3.5-27B-v3-FP8-vllm-ready

[^167]: https://forums.developer.nvidia.com/t/how-do-i-run-jackrong-qwen3-5-27b-claude-4-6-opus-reasoning-distilled-on-vllm-community-docker/363292

[^168]: https://www.youtube.com/watch?v=iB_r_cCQCwg

[^169]: https://x.com/KyleHessling1

[^170]: https://www.facebook.com/groups/miaigroup/posts/2165511200886807/

[^171]: https://www.facebook.com/nanobro.rit/posts/-gemma-4-benchmark-resultslocal-mlx-deployment-on-mac-prefill-speed-572-tokensse/1378896080932872/

[^172]: https://arxiv.org/html/2503.04222v1

[^173]: https://huggingface.co/Jackrong/Qwopus3.5-27B-v3-GGUF/commit/75a52b76bfa4457dc70936470077449e2c6e50cf

[^174]: https://huggingface.co/Jackrong/Qwopus3.5-27B-v3-GGUF/commit/2f5cb77d60fa4023ceff83a7d9d493e50a134eb7

[^175]: https://huggingface.co/Jackrong/Qwopus3.5-27B-v3-GGUF/commits/8a4b6ab4962c1c8f38c3632b5124c7dc5e3f55ab

[^176]: https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B/blob/main/README.md

[^177]: https://huggingface.co/Jackrong/Qwopus3.5-27B-v3-GGUF/commit/da7cec62491b3170aec8ca51f65774575fd56a18

[^178]: https://huggingface.co/Jackrong/Qwopus3.5-27B-v3-GGUF/commits/3f96a0c24eeeff11f4029d9d1ccebbcc014e744a/README.md

[^179]: https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B-GGUF/blame/be359f53a419f1737b0cb27733aaa1d87e93dbe3/README.md

[^180]: https://huggingface.co/DavidAU/gemma-4-31B-it-Mystery-Fine-Tune-HERETIC-UNCENSORED-Thinking

[^181]: https://huggingface.co/Jackrong/Qwopus3.5-27B-v3-GGUF/tree/866d14eef1dbace59c50e9bdb4c1ed816db94b70

[^182]: https://huggingface.co/samuelcardillo/Qwopus-MoE-35B-A3B-GGUF/tree/main

[^183]: http://arxiv.org/pdf/2312.11514.pdf

[^184]: https://arxiv.org/pdf/2306.07629.pdf

[^185]: http://arxiv.org/pdf/2411.17847.pdf

[^186]: https://arxiv.org/pdf/2407.10032.pdf

[^187]: https://arxiv.org/pdf/2311.00502.pdf

[^188]: http://arxiv.org/pdf/2406.09900.pdf

[^189]: https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF

[^190]: https://www.youtube.com/watch?v=eggkmAbii8M

[^191]: https://lmstudio.ai/models/google/gemma-4-26b-a4b

[^192]: https://pinggy.io/blog/top_5_local_llm_tools_and_models/

[^193]: https://dev.to/lightningdev123/top-5-local-llm-tools-and-models-in-2026-1ch5

[^194]: https://pub.towardsai.net/i-tested-all-4-gemma-4-models-the-26b-one-is-cheating-in-the-best-way-744e40d90d37

[^195]: https://sonusahani.com/blogs/qwen-27b-vs-qwen-35b

[^196]: https://www.hakunamatatatech.com/our-resources/blog/local-llm-for-coding

[^197]: https://news.ycombinator.com/item?id=47616361

[^198]: https://arxiv.org/pdf/2503.12524.pdf

[^199]: https://arxiv.org/pdf/2503.17793.pdf

[^200]: https://arxiv.org/pdf/2310.19902.pdf

[^201]: https://arxiv.org/pdf/2308.12966.pdf

[^202]: https://arxiv.org/html/2501.15570v1

[^203]: https://arxiv.org/pdf/2309.16609.pdf

[^204]: https://arxiv.org/pdf/2411.02265.pdf

[^205]: https://arxiv.org/html/2412.11990

[^206]: https://www.reddit.com/r/LocalLLaMA/comments/1rw338c/best_qwen35_27b_guffs_for_coding_q4q5/

[^207]: https://huggingface.co/unsloth/Qwen3.5-27B-GGUF/discussions

[^208]: https://www.reddit.com/r/LocalLLaMA/comments/1rianwb/running_qwen35_27b_dense_with_170k_context_at/

[^209]: https://techie007.substack.com/p/qwen-35-the-complete-guide-benchmarks

[^210]: https://ollama.com/library/qwen3.5:27b

[^211]: https://huggingface.co/Qwen/Qwen3.5-35B-A3B-Base

[^212]: https://huggingface.co/mudler/gemma-4-26B-A4B-it-APEX-GGUF

[^213]: https://unsloth.ai/docs/models/qwen3.5

[^214]: https://huggingface.co/HauhauCS/Qwen3.5-35B-A3B-Uncensored-HauhauCS-Aggressive

[^215]: https://huggingface.co/bartowski/Qwen_Qwen3.5-27B-GGUF

[^216]: https://huggingface.co/TheCluster/Qwen3.5-35B-A3B-Uncensored-HauhauCS-Aggressive-MLX-mxfp4

