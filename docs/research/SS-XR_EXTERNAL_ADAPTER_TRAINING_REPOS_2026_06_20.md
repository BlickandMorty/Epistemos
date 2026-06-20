# SS-XR — External adapter/training/agent repos: don't be the sole primitive (2026-06-20)

Owner (verbatim): *"my app shouldn't be the sole primitive for adapter robustness — other apps have really robust,
proven training pipelines. Look on github, research other repos that have agent creation, agent training, model
training, modifying/tuning adapters, and the type of adapters that best work for my app based off my models and the
architecture of my app. Max out that research."* Web+code-grounded. Governing constraint: MAS-sandboxed/notarized →
**no Python subprocess at runtime** → anything Python = study/embed-the-PATTERN only, never shell out. Feeds SS-LS
(native trainer), SS-AD (adapter UX). Re-validate version/star claims at point of use (time-sensitive).

## 1. Training pipelines (Apple-Silicon / MLX)
A native MLX-Swift, Python-free, on-device trainer is feasible TODAY and **Apple ships a reference** (mlx-swift-examples
`LoRATrainingExample` + `Tools/llm-tool/LoraCommands.swift`: `Linear→LoRALinear`, `LoRATrain.train`, `saveLoRAWeights`,
`model.fuse`; PR #46 ported the Python loop to Swift). Epistemos already has `NativeLoRATrainer`/`LoRATrain`.
| Project | License | Algos | Embed? |
|---|---|---|---|
| **mlx-lm** (Apple) | MIT | lora/dora/full; QLoRA auto on quantized base; no DPO/ORPO/KTO | pattern (Python) |
| **mlx-examples/lora**, **mlx-swift-examples** (Apple) | MIT | LoRA/QLoRA reference; pure-Swift trainer skeleton | **YES — starting skeleton** |
| **mlx-lm-lora** (Gülmez) | **Apache-2.0** | SFT,DPO,CPO,ORPO,GRPO,GSPO,DAPO,Online-DPO,XPO,PPO,**QAT**; no KTO | **lift loss-logic (clean-room)** |
| **MLX-Swift** (Apple) | MIT | full autodiff + MLXOptimizers + MLXNN | **the in-process substrate** |
| axolotl / unsloth-core / LLaMA-Factory / PEFT / TRL | Apache-2.0 (unsloth `studio/` AGPL) | broad | study patterns only (Python) |
Gaps to port atop the Swift gradient stack: full-FT wiring (primitives exist), DoRA-Swift (small extension),
then DPO/ORPO/GRPO/QAT (loss + data pipeline — copy from Apache-2.0 mlx-lm-lora). **KTO exists nowhere** → Epistemos's
native KTO (SS-LS 1b) is genuinely net-new.

## 2. Agent creation/management UX — the field's BIGGEST GAP = Epistemos's edge
**Almost NO local desktop GUI lets a user attach a LoRA/adapter to a base model — it lives at CLI/config only.** Doing
it in-UI (per SS-AD) is the differentiator. Patterns to copy:
- **Ollama Modelfile** (MIT): declarative `FROM` base + `ADAPTER` + `PARAMETER` + `SYSTEM` → named baked model;
  enforces base↔adapter match. **← the declarative base+adapter binding to copy.**
- **llama.cpp server** (MIT): `--lora-scaled FNAME:SCALE` + runtime hot-swap `GET/POST /lora-adapters` (scale 0 = off)
  → **live A/B with a scale slider, no reload.**
- **Msty Persona Studio**: **versioned sandbox + side-by-side split compare before promoting** = best test-before-save.
- **OpenAI GPT Builder**: **three-zone layout** (Configure form | Capabilities/tools | always-on live Preview).
- **CrewAI** (MIT): structured persona **role/goal/backstory** → compiles to system prompt (not one blob).
- **LocalAI** (MIT): per-model YAML `lora_adapter`/`lora_base`/`lora_scale`.
- Convergence across LM Studio/Open WebUI/AnythingLLM: **MCP tools as toggleable capabilities + per-tool approval**.
**Recommended Epistemos agent-builder** (maps onto Companions/`CompanionCreationFlow`, SS-AD): three-zone +
structured persona + **base+adapter declarative binding with scale slider + hot-swap live preview** + params bundled
into the agent + versioned test-before-save split compare.

## 3. Adapter TYPE recommendation for SMALL on-device MLX models (1B–12B)
**Central tension:** base is quantized for memory, but convenient adapters train in fp16, and **merging an fp16 adapter
into a quantized base DEGRADES quality** (documented independently: MLX #654, llama.cpp #7062, Kaitchup; full-FT 0.26→
0.168 after NF4). "Train fp16 → merge → post-quantize" is the FAILURE path.
**→ RECOMMENDATION: default to DoRA trained on the already-quantized base (QDoRA-style), kept as a SEPARATE runtime
adapter — do NOT fuse.**
- DoRA is native in BOTH mlx-lm and MLX-Swift, best measured quality on small quantized bases (+1 to +4.4 pts, beats
  LoRA at half rank, ~0.01% extra params), and keeping it unmerged sidesteps merge degradation + stays MB-sized +
  hot-swappable (accept the small per-layer matmul overhead).
- **When you must fuse** (single fixed behavior, zero overhead): fuse to **fp16** then re-quantize ONLY after a quality
  witness, OR ship a **QAT base** (Gemma 3 QAT, Llama 3.2 1B/3B QAT — small models suffer most under 4-bit) and adapt
  on top.
- **Avoid:** fp16 LoRA → merge → post-quantize. **Watch:** QA-LoRA (quantized end-to-end + losslessly mergeable) is
  theoretically cleanest but has NO native PEFT/mlx-lm support → future port target.
**Algorithm priority (native MLX-Swift, no Python):** (1) SFT+LoRA/QLoRA (table stakes, Apple Swift ref exists),
(2) DoRA, (3) DPO (most-wanted alignment; port from Apache-2.0 mlx-lm-lora), (4) ORPO/GRPO, (5) QAT (or ship QAT bases).

## 4. Adapter explanation/metadata (for SS-AD explanation cards)
`adapter_config.json` is the richest source (PEFT auto-detects an adapter dir by it). Card lines → fields: Method
(`peft_type`), Rank (`r`), Scaling (effective `alpha/r`, or `alpha/√r` if `use_rslora`), Variant (`use_dora`/`use_rslora`),
Modifies (`target_modules`+`modules_to_save`), Base (`base_model_name_or_path`), Task (`task_type`), License/datasets/
tags (README YAML), Intended-use/limitations (model-card body). **GGUF degrades:** only `adapter.type` + `adapter.lora.alpha`
reliably present (no `r`/`target_modules`) — degrade gracefully. Canonical adapter signal: `base_model_relation: adapter`
in README YAML. Show EFFECTIVE scale, not raw alpha.

## Embed vs study (licensing)
- **Embeddable patterns (MIT/Apache):** mlx-lm, mlx-examples, MLX-Swift, mlx-swift-examples (MIT, Apple); **mlx-lm-lora
  (Apache-2.0 — the one place to lift DPO/ORPO/GRPO/QAT loss logic, clean-room)**; PEFT/TRL (Apache); axolotl/LLaMA-
  Factory/LocalAI/AnythingLLM/CrewAI/Ollama (MIT/Apache) for config/UX.
- **Study-only (copyleft):** Jan (AGPLv3), unsloth `studio/`+`unsloth_cli/` (AGPL; core `unsloth/` is Apache = liftable),
  Open WebUI (branding clause), LangGraph `langgraph-api` (Elastic-2.0). Inspiration, never copied code.

## Build directives (added to the plan)
- SS-LS native trainer: keep DoRA-on-quantized as the default adapter mode; do not auto-fuse; expose fuse-to-fp16 +
  re-quant-after-witness as an explicit advanced option; algo order SFT/LoRA→DoRA→DPO→ORPO/GRPO→QAT (loss logic from
  Apache-2.0 mlx-lm-lora, clean-room).
- SS-AD agent builder: declarative base+adapter binding + scale slider + hot-swap live preview + test-before-save split
  compare; validate adapter↔base match.
- Confidence caveats (carry honestly): QDoRA>full-FT is a single engineering blog (directional, not peer-reviewed);
  QA-LoRA wins at small/low-bit, ties at 65B; mlx-lm `--de-quantize` fuse has open bug #659 (validate before relying).

Sources: ml-explore/{mlx-lm,mlx-examples,mlx-swift,mlx-swift-examples} • Goekdeniz-Guelmez/mlx-lm-lora • HF PEFT/TRL •
docs.ollama.com/modelfile • llama.cpp server README + issues #7062/#659 + #654 • Msty Persona Studio • OpenAI GPT
Builder • CrewAI • LocalAI • arXiv: QLoRA 2305.14314, DoRA 2402.09353, QA-LoRA 2309.14717, rsLoRA 2312.03732, LoRA+
2402.12354, IA3 2205.05638, ReLoRA 2307.05695 • answer.ai QDoRA • Gemma-3/Llama-3.2 QAT blogs • Kaitchup
"don't merge LoRA into quantized" • ggml gguf.md. Cross-ref SS-LS, SS-AD, SS-AB, SS-Z.
