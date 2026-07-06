---
id: 9F8E7CE1-8C06-4441-8811-A1D32401ABCF
title: "SS-AB — ModelCapabilityProfile: the DEFINITIVE hardened design (once and for all) + per-model profiles &amp; picker copy (2026-06-19)"
---

# SS-AB — ModelCapabilityProfile: the DEFINITIVE hardened design (once and for all) + per-model profiles &amp; picker copy (2026-06-19)

Synthesis (not a new survey) of SS-Z (the profile gap) + SS-AA (the OSS patterns) + SS-R (the model shortlist +  
per-model data) + SS-W (the crash). Owner: *"a deeply hardened COMBO of all the best ones — pick the best metric*  
*per dimension, make it work ONCE AND FOR ALL; each model gets a deeply-researched capability profile + benefits*  
*description; the picker shows a brief use-case description per model; the best models are advertised."*

## The definitive design — best-of-breed combo, hardened

ONE source of truth, **data-driven**, both model universes (MLX `LocalTextModelID` + GGUF `GemmaQATRuntime Candidate` + cloud `CloudModelProvider`) resolve to it. Best metric chosen per dimension (provenance in []):

```
struct ModelCapabilityProfile {            // bundled JSON, override-layered [Aider], keyed by model id
  id, displayName
  contextWindow: Int                       // [Ollama num_ctx / LiteLLM max_input_tokens] — replaces the MLX
                                           //   :708 ladder AND the GGUF hardcoded 4096 (SS-Z bug)
  maxOutputTokens: Int
  chatTemplate: TemplateRef {              // [llama.cpp] resolution order — RESOLVED, NEVER empty for GGUF:
                                           //   (a) embedded tokenizer.chat_template, (b) pinned .jinja file,
                                           //   (c) named builtin by family. Always passed as --chat-template-file
                                           //   → the SS-W common_chat_templates_apply crash is UNREACHABLE.
  }
  promptDialect: enum                      // chatml | llama3 | gemma | mistral | hermes | lfm-pythonic | phi | granite
  toolCallDialect: enum                    // AUTO-DETECTED from template [llama.cpp common_chat_format], not a
                                           //   hand-map; = none for reasoning-only models
  samplingDefaults { temp, top_p, top_k, repeat_penalty }   // [Ollama PARAMETER] — SS-Y determinism anchor
  stop: [String]                           // [Ollama] per-model stop tokens — MISSING today on GGUF (SS-Z/AA bug)
  capabilityTier: enum                     // [LiteLLM mode + Epistemos tier] agent-capable vs chat-only
  skillsEnabled { tools, vision, structuredOutput, promptCaching }   // [LiteLLM supports_*] — one gate local+cloud
  decoding { grammarEngine: llguidance, schemaSource }      // [llguidance MIT] THE equalizer across GGUF+MLX —
                                           //   build loop has ALREADY added the llguidance dep. Forced-valid
                                           //   JSON makes dialect differences moot (mandatory for Gemma = no
                                           //   native tool dialect).
  benefitsDescription: String             // deep per-model "what it's good at" (SS-R) — honest, real
  pickerUseCase: String                    // SHORT use-case line shown on the model picker (≤ ~60 chars)
  advertised: Bool                         // best models advertised; all installable (advertise-stack item)
  lane: enum { mlx, gguf, research }       // MLX=MAS-safe in-process; GGUF=Pro subprocess; research=experimental
}
```

**Three hardening decisions (make it work once and for all):**

1. **Profile-as-data, bundled offline + override-layered** — one JSON (LiteLLM offline-backup pattern, MAS-safe,  
 no network at load) as the floor; user/profile file merges on top (Aider). Collapses SS-Z's "two disconnected  
 universes."
2. **llguidance is the single grammar engine** (already a dep) — GGUF via `-DLLAMA_LLGUIDANCE=ON`, MLX via the  
 UniFFI boundary + a mask-glue applying llguidance's mask to MLX logits before sampling. One schema compiler,  
 one mask, both lanes. Satisfies SS-Y determinism.
3. **Template resolution that structurally prevents SS-W** — always pass the resolved `--chat-template-file`;  
 the empty-template path into `common_chat_templates_apply` becomes unreachable.

## Per-model profiles + picker use-case copy (the canon set + shortlist)

Each gets a profile (ctx/template/dialect) + a `benefitsDescription` + a short `pickerUseCase`. Honest, real.


| Model                        | Lane      | Tier        | ctx        | toolDialect                              | pickerUseCase (picker copy)                 | advertised              |
| ---------------------------- | --------- | ----------- | ---------- | ---------------------------------------- | ------------------------------------------- | ----------------------- |
| **Gemma 4 E2B**              | MLX       | Fast        | 128K       | gemma (constrained REQUIRED — no native) | "Fastest on-device · everyday chat"         | ✅                       |
| **Gemma 4 E4B**              | MLX       | Fast/Think  | 128K       | gemma (constrained)                      | "Fast on-device · 128K context"             | ✅                       |
| **Gemma 4 12B QAT**          | GGUF(Pro) | Code        | 128K       | gemma (constrained)                      | "Strongest local coder (Pro)"               | ✅                       |
| **Qwen3 4B**                 | MLX       | Fast/Think  | 32K*       | hermes/qwen3_xml + think-toggle          | "Best all-round · strong tools + reasoning" | ✅                       |
| **Qwen3 1.7B**               | MLX       | Fast        | 32K*       | hermes/qwen3_xml                         | "Quick all-round · low RAM"                 | ◻                       |
| **VibeThinker-1.5B**         | MLX/GGUF  | Think       | 32K        | none (reasoning)                         | "Tiny math/logic reasoning"                 | ✅                       |
| **DeepSeek-R1-Distill-1.5B** | MLX/GGUF  | Think       | 32K        | none (reasoning)                         | "General step-by-step reasoning"            | ◻                       |
| **SmolLM3-3B**               | MLX       | Think       | 128K(YaRN) | xml/pythonic + think                     | "Open reasoning + tools, 128K"              | ◻                       |
| **LFM2.5-1.2B**              | MLX/GGUF  | Fast/Tool   | 32K        | **lfm-pythonic**                         | "Ultra-fast on-device tool-caller"          | ◻                       |
| **SmolLM2-360M**             | MLX       | Fast(ultra) | —          | none/xml                                 | "Instant tiny chat · near-zero RAM"         | ◻                       |
| **Phi-4-mini 3.8B**          | MLX       | Think/Code  | 128K       | phi-json                                 | "128K reasoning + function-calling"         | ◻                       |
| **Granite 4 Nano 1B**        | MLX       | Fast/Tool   | long       | granite-json                             | "Enterprise-clean tool/RAG model"           | ◻                       |
| **Bonsai / BitNet**          | research  | —           | —          | none                                     | "Experimental ternary (research)"           | ◻ (honest experimental) |


 cap Qwen3's 256K to ~32K for the 16GB KV-cache budget. Cloud models (Claude/OpenAI/Gemini) get the same  
profile shape from the LiteLLM-seeded table (contextWindow/supports_*). **Picker rule:** advertised models show  
their `pickerUseCase` prominently; all models (incl. hidden/non-canon) remain installable + show their copy in  
the advertise-stack (per the keep-all-models + advertise-select items). NO empty/fake descriptions — every entry  
honest + real (no-fake).

## Honest gating + scope (chat-first, non-clashing)

- **MAS-safe/in-process:** the profile JSON, llguidance (in-process mask, no subprocess), MLX + llguidance,  
cloud providers, template resolution.
- **Pro:** the GGUF/llama.cpp lane (`#[cfg(feature="pro-build")]`, `--chat-template-file` + `-DLLAMA_LLGUIDANCE= ON`); ternary/BitNet (separate `bitnet.cpp` runtime, research).
- **CHAT-FIRST (owner constraint):** the profile + per-model engineering lands primarily on the Chat engine;  
Act(Osaurus)/Work(Goose) get only the non-clashing subset (engine-isolation: shared registry/memory, not  
shared logic) — respect each clone's own model marketplace, don't duplicate it.

## Ordered plan (build once-and-for-all)

1. **[S]** `chatTemplate` required + resolved + always pass `--chat-template-file` (kills SS-W) + per-model  
 `stop` array + per-model `contextWindow` across the FFI (replaces hardcoded 4096). [the loop is on this now]
2. **[S]** Define `ModelCapabilityProfile` as one bundled JSON; seed cloud from LiteLLM MIT data; add  
 `benefitsDescription` + `pickerUseCase` per model from SS-R.
3. **[M]** Wire llguidance as the single grammar engine (GGUF native + MLX mask-glue) → guaranteed-valid tool  
 calls both lanes (SS-Y); template-driven dialect auto-detect (kills the dead map, SS-Z).
4. **[M]** Surface `pickerUseCase` on the model picker (brief use-case per model; advertise the best) + the  
 per-model profile/benefits in Settings (the model-stack/advertise surface).
5. **[M]** Unify tiers + skills gate behind the profile so every model (incl. small GGUF) has one honest  
 skills-access answer (SS-H keystone).
6. **[L]** Migrate the MLX `LocalTextModelID` ladders to resolve from the profile — collapse the two universes.
7. **Tests (owner's tests-at-end):** `cargo test --lib` for the profile resolution + template-resolution  
 (no-empty-template) + llguidance mask; reasoned Swift-Testing for the picker copy; falsifier that no GGUF  
 model can reach `common_chat_templates_apply` with an empty template.

Cross-refs: SS-Z (profile gap + crash linkage), SS-AA (OSS patterns: llguidance/LiteLLM/Ollama/Aider + Gemma
no-native-dialect), SS-R (model shortlist + per-model data + licenses), SS-W (the crash), SS-Y (determinism),
SS-H (skills keystone), MODEL-INSTALL + advertise-stack items, CHAT-FIRST constraint.