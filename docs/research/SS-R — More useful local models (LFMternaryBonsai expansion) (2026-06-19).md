---
id: 5B6A2EAF-DA92-43A7-97DD-40D44AFB25E1
title: SS-R — More useful local models (LFM/ternary/Bonsai expansion) (2026-06-19)
---

# SS-R — More useful local models (LFM/ternary/Bonsai expansion) (2026-06-19)

Read-only research (subagent, web). Feeds the MORE-LOCAL-MODELS ledger item; integrates with SS-AA  
(ModelCapabilityProfile) + SS-Z + the MODEL-INSTALL items. Owner: *"more useful local models, more LFM-like*  
*models like ternary Bonsai and other useful local models."* Target: 16GB Apple-Silicon M2 Pro, MLX-Swift  
(in-process, MAS-safe) + Pro GGUF/llama.cpp (subprocess). HONEST runnability flags throughout.

## Headline — landscape for 16GB Apple Silicon

Sweet spot = **0.35B–4B @ 4-bit** (~0.3–3 GB resident). Three honest tiers: **MLX-runnable (in-process,**  
**MAS-safe — preferred)** = LFM2, Qwen3, Gemma 4 (E2B/E4B), SmolLM3, Llama-3.2, OLMo2, Phi-4-mini, Granite 4;  
**GGUF/llama.cpp (Pro, subprocess)** = everything also as GGUF; **Ternary/BitNet (Research/Pro, separate**  
**runtime)** = NOT drop-in (needs `bitnet.cpp` fork or unmerged ggml types). **Naming correction (load-bearing):**  
**"Gemma 4" is REAL** (Google, Apr 2026, E2B/E4B/12B/26B-A4B/31B, **Apache-2.0**, day-0 MLX/GGUF/QAT) — the app  
catalog's "Gemma 4 (E2B/E4B/12B QAT)" naming is ACCURATE, not an internal alias.

## Per-family findings

- **LFM2 / LFM2.5 (Liquid) — the owner's anchor. ADD.** Sizes 350M/700M/1.2B/2.6B/8B-A1B(MoE); LFM2.5-1.2B. 32K  
ctx (8B-A1B 128K). **MLX checkpoints EXIST + GGUF → runs on BOTH lanes.** Tool-calling = **Pythonic function**  
**calls** (Python list between special tokens — its own dialect). **License = LFM Open License v1.0 (Apache-**  
**based BUT free commercial only under $10M revenue — NOT OSI-free; flag for legal).** 350M/700M=Fast, 1.2B=Fast/  
Tool.
- **Ternary/BitNet b1.58 (Microsoft) — RESEARCH/Pro only.** `bitnet-b1.58-2B-4T`, ternary {-1,0,1} @1.58 bit,  
~400MB, beats Llama-3.2-1B/Gemma-3-1B on GSM8K/PIQA. **Honest: needs** `bitnet.cpp` **(separate llama.cpp fork) —**  
**NOT mainline llama.cpp, NOT MLX in-process.** MLX ternary is experimental community only. Add as a flagged  
Research/Pro lane, NOT a default entry.
- **Bonsai (deepgrove) — interesting, NOT ship-ready.** 500M ternary, Llama arch + Mistral tokenizer. **Critical**  
**flags: (a) BASE model, NOT instruction-tuned (vendor says finetune before use); (b) ops in 16-bit today**  
**(ternary kernels not integrated → no memory win); (c) prism-ml Ternary-Bonsai-4B/8B GGUF FAILS to load**  
**("invalid ggml type 41", unmerged).** Keep as a labeled Research/ternary curiosity; do NOT advertise as usable.
- **SmolLM2/3 (HF) — ADD SmolLM3.** SmolLM2 135M/360M/1.7B; SmolLM3 3B, 64K→128K (YaRN), hybrid reasoning  
(think/no-think), **native tool-calling** (XML-Tools + Python-Tools template sections), **Apache-2.0**,  
llama.cpp+MLX+ONNX+MLC. SmolLM2-360M = ultra-Fast; SmolLM3-3B = clean-licensed Think.
- **Gemma 4 / 3n-lineage — KEEP/UPGRADE.** E2B/E4B (effective-param edge line) + 12B; 128K ctx; Apache-2.0 (G4  
dropped the restrictive Gemma ToU); day-0 MLX+GGUF+QAT. Ideal 16GB citizens.
- **Triage:** **Qwen3 0.6/1.7/4B** — Apache-2.0, MLX(`mlx-lm≥0.24`)+GGUF, think/no-think, strong tools, up to  
256K → **ADD (best all-rounder).** **Phi-4-mini 3.8B** — 128K, function-calling, MIT → ADD optional.  
**Granite 4 Nano 1B/Micro 3B** — Apache-2.0, tool/RAG-tuned → ADD Nano optional. **Llama-3.2 1B/3B** — Llama  
Community License (not OSI-free, &lt;700M MAU) → lower priority. **OLMo2 / MiniCPM / Helium / Falcon-small** →  
skip (no edge for 16GB).
- **Reasoning small (Think):** **VibeThinker-1.5B** (owner pick, Qwen2.5-Math base, math-RL, beats orig  
DeepSeek-R1 on AIME at 1/400th params; GGUF+MLX) — KEEP. **DeepSeek-R1-Distill-Qwen-1.5B** (MIT, GGUF+MLX) —  
KEEP as alt. SmolLM3-3B + Qwen3-4B(think) double as Think.

## SHORTLIST to add (ranked)


| #                                                                                                          | Model                             | Size           | Lane                      | Tier        | License              | Why                                                         |
| ---------------------------------------------------------------------------------------------------------- | --------------------------------- | -------------- | ------------------------- | ----------- | -------------------- | ----------------------------------------------------------- |
| 1                                                                                                          | **Qwen3**                         | 0.6/1.7/4B     | MLX(+GGUF)                | Fast/Think  | Apache-2.0           | best all-round; think-toggle, strong tools, clean license   |
| 2                                                                                                          | **LFM2.5/LFM2**                   | 350M/700M/1.2B | MLX(+GGUF)                | Fast/Tool   | LFM Open (≤$10M rev) | owner anchor; fastest on-device; pythonic tools; both lanes |
| 3                                                                                                          | **Gemma 4 E2B/E4B QAT**           | E2B/E4B        | MLX(+GGUF)                | Fast/Think  | Apache-2.0           | already in catalog; day-0 MLX, 128K, now OSI-clean          |
| 4                                                                                                          | **SmolLM3-3B**                    | 3B             | MLX(+GGUF)                | Think       | Apache-2.0           | hybrid reasoning + native tools + 128K, fully open          |
| 5                                                                                                          | **VibeThinker-1.5B**              | 1.5B           | MLX/GGUF                  | Think       | verify*              | owner pick; top tiny math reasoning                         |
| 6                                                                                                          | **SmolLM2-360M**                  | 360M           | MLX(+GGUF)                | Fast(ultra) | Apache-2.0           | tiniest useful chat; near-zero RAM                          |
| 7                                                                                                          | **DeepSeek-R1-Distill-Qwen-1.5B** | 1.5B           | MLX/GGUF                  | Think       | MIT                  | general reasoning distill                                   |
| 8                                                                                                          | **Phi-4-mini**                    | 3.8B           | MLX(+GGUF)                | Think/Code  | MIT                  | 128K, function-calling                                      |
| 9                                                                                                          | **Granite 4 Nano**                | 1B             | MLX(+GGUF)                | Fast/Tool   | Apache-2.0           | enterprise-clean, tool/RAG (optional)                       |
| 10                                                                                                         | **Ternary-Bonsai / BitNet**       | 0.5B/2B        | Research/Pro (bitnet.cpp) | Research    | MIT/Apache           | ternary showcase ONLY — see gating                          |
| **VibeThinker-1.5B license string unverified** — confirm on HF card before advertising (base Qwen2.5-Math, |                                   |                |                           |             |                      |                                                             |
| usually Apache/Qwen-license).                                                                              |                                   |                |                           |             |                      |                                                             |


## Honest runnability gating

- **MLX (in-process, MAS-safe, default catalog):** Qwen3, LFM2/2.5, Gemma 4, SmolLM2/3, Llama-3.2, Phi-4-mini,  
Granite 4, OLMo2, R1-Distill-1.5B.
- **GGUF/llama.cpp (Pro, subprocess):** all also exist as GGUF — use for llama.cpp tool-grammar or unverified MLX  
conversions (e.g. VibeThinker).
- **Ternary/BitNet (Research/Pro, NOT in-process):** BitNet needs `bitnet.cpp`; Bonsai base-only+16-bit-only;  
Ternary-Bonsai GGUF fails to load. Advertise honestly as experimental; NOT on the Fast/Think happy path.

## Integration (SS-AA ModelCapabilityProfile per model)

- **Qwen3:** ctx 32K–256K (cap ~32K for 16GB KV); ChatML; toolDialect=qwen3_xml/Hermes + `enable_thinking`.
- **LFM2/2.5:** ctx 32K (MoE 128K); LFM template; **toolDialect=pythonic (own parser).**
- **Gemma 4 E2B/E4B:** ctx 128K (cap); Gemma `<start_of_turn>`; toolDialect=Gemma function-call JSON.
- **SmolLM3:** ctx 128K (YaRN); XML-Tools+Python-Tools template; toolDialect=xml or pythonic (selectable).
- **VibeThinker / R1-Distill-1.5B:** ctx ~32K/128K; `<think>` template; **toolCallDialect=none (reasoning, not**  
**tool models).**
- **Phi-4-mini:** ctx 128K; Phi-4 template; toolDialect=Phi JSON. **Granite 4:** Granite JSON tools.
- **BitNet/Bonsai:** `lane=research, toolCallDialect=none`, experimental flag.

## Honest takeaways

(1) "Gemma 4" is real (Apache-2.0, MLX/GGUF day-0). (2) LFM2 now has MLX (both lanes) — license is the catch
(≤$10M revenue, flag legal). (3) Bonsai + BitNet are honestly research/Pro-only (base-only/16-bit/load-fails/
separate runtime) — never on the happy path. (4) Cleanest adds (Apache-2.0 + MLX): Qwen3, SmolLM3, SmolLM2-360M,
Gemma 4 E2B/E4B, Granite 4 Nano; Phi-4-mini + R1-Distill are MIT. (5) Verify VibeThinker license before
advertising. Repo grounding: catalog/profile files exist (`A2UI/Catalog.swift`, `FineTunePackCatalog.swift`) +
`artifacts/falsifiers/` Gemma-QAT body — consistent with the model-install + per-model-framework work.

Sources (key): LiquidAI LFM2/LFM2.5 blog + model-library + license; microsoft/bitnet-b1.58-2B-4T + bitnet.cpp;
deepgrove-ai/Bonsai + prism-ml GGUF + lmstudio bug #1729; HF SmolLM3 blog + GGUF; Google Gemma 4 blog + model
card + ollama gemma4:e2b-mlx; Qwen3 blog + HF; Phi-4-mini + Granite 4 GGUF (unsloth); OLMo2 MLX; VibeThinker-1.5B
(emergentmind/arxiv 2511.06221/Mungert GGUF); DeepSeek-R1-Distill-Qwen-1.5B. Cross-ref SS-AA, SS-Z, MODEL-INSTALL.