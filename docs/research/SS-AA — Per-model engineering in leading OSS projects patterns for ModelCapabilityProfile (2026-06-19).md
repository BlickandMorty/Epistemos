---
id: 9EAC7EE3-C758-4469-8E91-F70BA01FA169
title: "SS-AA — Per-model engineering in leading OSS projects: patterns for ModelCapabilityProfile (2026-06-19)"
---

# SS-AA — Per-model engineering in leading OSS projects: patterns for ModelCapabilityProfile (2026-06-19)

Read-only research (subagent, web-heavy). Feeds the GITHUB-PER-MODEL-STUDY ledger item; extends SS-Z (the
profile), SS-Y (determinism), SS-W (the `common_chat_templates_apply` crash). Owner: *"study how GitHub repos do
per-model engineering for local + cloud; harvest techniques/patterns; utilize GitHub."*

## Headline — the convergent pattern

Every serious multi-model OSS project independently converged on the **same two-layer split**:

1. **Per-model profile = DATA, keyed by model id** (not code branches) — Ollama Modelfile, LiteLLM
 `model_prices_and_context_window.json`, Aider `model-settings.yml`, LocalAI/Jan/GPT4All per-model configs,
 Cline/Roo `ModelInfo` tables. **This is exactly SS-Z's `ModelCapabilityProfile`, already proven by 6+
 projects.**
2. **Tool-call dialect chaos is solved by CONSTRAINED DECODING** (token-masking to a grammar/JSON-schema) — makes
 a model's native tool syntax irrelevant by forcing the output shape. The grammar engines (XGrammar,
 llguidance, GBNF, Outlines) are the SS-Y equalizer.
**Nuance every project hits:** constrained decoding solves output PARSING but NOT tool-definition INJECTION — you
still need the right per-model chat template to tell the model what tools exist. So you need BOTH layers.

## Per-project pattern + ADOPT

- **llama.cpp (MIT) — chat-template resolution (fixes SS-W).** Model carries its format as a Jinja program in
GGUF `tokenizer.chat_template`, run by bundled **minja**; `--jinja` runs embedded, else maps to a named
built-in (`chatml/llama3/gemma/mistral-v1/v3/v7/phi3/4/deepseek/command-r/granite/gpt-oss`). Override
`--chat-template <name>` / `--chat-template-file <path>`; structured output `--json-schema`→GBNF. **SS-W root
CONFIRMED (issue #11400):** `common_chat_templates_apply` prints "falling back to chatml" but then EXITS
instead of reverting (exit 3221226505) — a bare GGUF with no template + no `--chat-template-file` triggers it.
**ADOPT [S]:** make `chatTemplate` a REQUIRED RESOLVED field; resolution order (a) embedded, (b) profile-pinned
`.jinja`, (c) named built-in by family; always pass `--chat-template-file` so the crash path is structurally
unreachable.
- **Ollama (MIT) — Modelfile = the canonical "profile as data".** `TEMPLATE` (Go text/template:
`.System/.Prompt/.Response/.Messages/.Tools/.ToolCalls`) + `PARAMETER` (temp/top_p/top_k/`num_ctx`/multiple
`stop`/repeat_penalty) + `SYSTEM` + `FROM`/`ADAPTER`. **ADOPT [M]:** mirror the field set into `ModelCapability Profile`; **add a per-model `stop` array (currently MISSING on Epistemos GGUF models — likely silent bug)**;
keep Jinja (llama.cpp speaks it) not Go templates, borrow the data shape.
- **vLLM / SGLang (Apache-2.0) — served config + guided decoding.** Template from HF `tokenizer_config.json`,
`--chat-template` override; **XGrammar default** structured-output backend (Outlines fallback);
`guided_json/regex/grammar/choice` + `response_format: json_schema`; tool dialects via `--tool-call-parser`
(hermes/mistral/llama3_json/granite/qwen3_xml). **ADOPT [M]:** lift the dialect→parser concept (replaces
Epistemos's dead map) but prefer llama.cpp's auto-detect-from-template over manual selection.
- **LiteLLM (MIT) — per-cloud-model capability table.** ONE JSON keyed by model id: `max_input_tokens`,
`max_output_tokens`, costs, `litellm_provider`, `mode`, `supports_function_calling/vision/tool_choice/ response_schema/prompt_caching/reasoning`; offline copy via `LITELLM_LOCAL_MODEL_COST_MAP`. **ADOPT [S→M]:**
this is the CLOUD half of `ModelCapabilityProfile` — borrow field names verbatim; ship a BUNDLED JSON
(offline, MAS-safe, no network at import); seed from their MIT data but maintain your own.
- **Outlines / XGrammar / llguidance — the tool-call equalizer.** Token-masking → one schema yields identical
parseable tool calls across all models + both lanes. Outlines = Python-first (weak FFI). XGrammar (Apache-2.0,
C++, default in vLLM/SGLang/MLC, has a Swift binding) — strong on MLX but C++ (awkward through UniFFI) + NOT in
llama.cpp → two engines. **llguidance (MIT, Microsoft, Rust, ~50µs/token, IN llama.cpp via
`-DLLAMA_LLGUIDANCE=ON` + in vLLM/SGLang/mistral.rs).** **ADOPT [M→L]: llguidance is the BEST fit** — the only
option that's (a) native in the GGUF/llama.cpp lane AND (b) a Rust crate that drops into Epistemos's Rust core
  - surfaces to Swift via the EXISTING UniFFI boundary → ONE grammar engine, one schema compiler, one mask across
  both lanes. (MLX lane has no built-in masking hook → own the glue applying llguidance's mask to MLX logits
  before sampling.)
- **Agent frameworks — per-model prompt tuning as DATA + user-override layering.** **Aider (Apache-2.0)** =
strongest: `model-settings.yml` per-model `edit_format/weak_model_name/examples_as_sys_msg/system_prompt_prefix/ use_temperature/extra_params/accepts_settings`, user overrides merged on top (o1→`use_temperature:false`).
**LocalAI (MIT)** = strongest local: per-model YAML `parameters{}`+`template{chat,completion,functions}`+
`roles{}`+`stopwords[]`+`context_size`. Cline/Roo typed `ModelInfo`; GPT4All `models3.json`; Jan (Apache-2.0).
**ADOPT [S]:** copy Aider's override layering (bundled floor + user/profile merge, later wins) + field names;
copy LocalAI's `template{}`+`stopwords[]`+`roles{}` for the local lane.

## Tool-call formats per model family (and normalization)


| Family                                                                                                           | Native syntax                                                 | Normalized by                                    |
| ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------ |
| Hermes 2/3, Qwen 2.5/3                                                                                           | `<tool_call>{"name","arguments"}</tool_call>` ChatML          | llama.cpp HERMES_2_PRO; vLLM hermes/qwen3_xml    |
| **Gemma 2/3**                                                                                                    | **NONE — no tool tokens** (prompt-engineered ````tool_code` ) | NO native parser → constrained-decoding REQUIRED |
| Llama 3.x                                                                                                        | `<|python_tag|>…` + JSON; pythonic `[f(x=1)]` in 3.2/3.3      | llama.cpp LLAMA_3_X; vLLM llama3_json/pythonic   |
| Mistral                                                                                                          | `[TOOL_CALLS] [{...}]`                                        | llama.cpp MISTRAL_NEMO; vLLM mistral             |
| Functionary                                                                                                      | `<|recipient|>NAME<|content|>{json}` / `>>>NAME`              | llama.cpp FUNCTIONARY_V3_x                       |
| FireFunction V2                                                                                                  | `functools[{...}]`                                            | llama.cpp FIREFUNCTION_V2                        |
| **KEY for Epistemos:** **Gemma (the model the GGUF Pro lane actually runs, SS-W) has NO native tool dialect** →  |                                                               |                                                  |
| constrained decoding is MANDATORY, not optional, for Gemma tool-calling. llama.cpp auto-detects format from      |                                                               |                                                  |
| template content (`common_chat_format`, PR #9639) → let the template drive detection, not a hand-maintained map. |                                                               |                                                  |


## Synthesized best design for Epistemos

**`ModelCapabilityProfile` = LiteLLM capability-table + Ollama-Modelfile data shape + Aider override-layering,
with llguidance as the universal decoding equalizer + llama.cpp `--chat-template-file` resolution.**

```
ModelCapabilityProfile {           // keyed by model id, DATA (bundled JSON), override-layered
  contextWindow, maxOutputTokens
  chatTemplate: TemplateRef        // embedded | pinned .jinja | named builtin — RESOLVED, never empty (kills SS-W)
  promptDialect: enum              // chatml|llama3|gemma|mistral|hermes
  toolCallDialect: enum            // AUTO-DETECTED from template (llama.cpp style), not a hand map
  samplingDefaults { temp, top_p, top_k, repeat_penalty }   // SS-Y anchor
  stop: [String]                   // per-model — MISSING today on GGUF
  capabilityTier: enum             // Gemma stays non-agent today
  skillsEnabled { tools, vision, structuredOutput, promptCaching }   // LiteLLM supports_*
  decoding { grammarEngine: llguidance, schemaSource }      // the equalizer
}
```

Three decisions: (1) **profile-as-data, bundled + override-layered** (one JSON, offline MAS-safe, Aider merge) —
unifies the two universes; (2) **llguidance** as the tool-call equalizer (one Rust crate spans GGUF + MLX) —
mandatory for Gemma; (3) **template resolution** that always passes `--chat-template-file` → SS-W unreachable.

## MAS-safe vs Pro

- **MAS-safe/in-process:** the profile registry (JSON), llguidance Rust crate (in-process mask, no subprocess),
MLX + llguidance masking, cloud providers, template resolution (data).
- **Pro-only:** the GGUF/llama.cpp lane (already `#[cfg(feature="pro-build")]`, shells `llama-cli`);
`--chat-template-file` + `-DLLAMA_LLGUIDANCE=ON` apply here. Profile DATA shared; only GGUF EXECUTION is Pro.

## Adopt now vs later

- **[S] Fix SS-W:** `chatTemplate` required+resolved; always pass `--chat-template-file`; add per-model `stop`.
- **[S] Profile schema:** define `ModelCapabilityProfile` as one bundled JSON (LiteLLM + Ollama field names +
Aider override-layering); seed cloud from LiteLLM MIT data.
- **[M] Kill the dead dialect map** → template-driven auto-detection; add a `get_model_info()`-style accessor
across both universes.
- **[M] Constrained decoding v1:** GGUF GBNF/`--json-schema` (zero new deps), mandatory for Gemma.
- **[L] Unify on llguidance** across GGUF (`-DLLAMA_LLGUIDANCE=ON`) + MLX (UniFFI mask glue) — one engine, MIT.

## Corrections from research

Jan is **Apache-2.0** (not AGPL); GPT4All `models3.json` has no dedicated context-length field (it's in
`description`).

Sources (key): llama.cpp templates wiki + issue #11400 + grammars/llguidance docs + PR #9639 · Ollama Modelfile

- tool-support + structured-outputs · vLLM/SGLang structured-outputs + tool_calling · LiteLLM
model_prices_and_context_window.json + get_model_cost_map · guidance-ai/llguidance + mlc-ai/xgrammar +
dottxt-ai/outlines · Aider model-settings.yml · LocalAI customize-model · Hermes/Qwen/Gemma/Llama/Mistral/
Functionary/FireFunction tool-format docs. (Full URL list in the subagent transcript.) Cross-ref SS-Z, SS-Y, SS-W.

