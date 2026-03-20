# AI Stack Risks

## Top Risks

## 1. Wrong base model during adapter fusion

Severity: critical

Why it matters:

- PEFT adapters are useless if merged into the wrong base
- tokenizer/template mismatches can look like “model is bad” when the artifact is actually corrupt

Current safeguard:

- the new prep scripts read `adapter_config.json`
- they fail if `base_model_name_or_path` does not match the manifest expectation

## 2. Tokenizer and chat-template drift after merge/convert

Severity: critical

Why it matters:

- Qwen and DeepSeek are both sensitive to tokenizer/template drift
- conversion that drops `chat_template.jinja` or token metadata can recreate visible reasoning junk or malformed tool output

Current safeguard:

- tokenizer audit is mandatory in prep scripts
- adapter tokenizer/template files are copied over the merged output before MLX conversion

## 3. Qwen-only assumptions surviving into the new architecture

Severity: high

Why it matters:

- current app state and install flow assume local model = stock Qwen tier
- that will distort DeepSeek integration if not explicitly replaced

Affected code:

- [`InferenceState.swift`](/Users/jojo/Epistemos/Epistemos/State/InferenceState.swift)
- [`LocalModelInfrastructure.swift`](/Users/jojo/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift)
- [`TriageService.swift`](/Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift)

## 4. UI-process inference regressions

Severity: high

Why it matters:

- the current app already demonstrates that in-process local inference is the wrong long-term boundary
- coupling heavy reasoning to the UI process will reintroduce responsiveness problems

Required response:

- move heavy text generation behind a sidecar before broadening model scope

## 5. Retrieval over-scope

Severity: medium-high

Why it matters:

- the repo already has retrieval primitives
- replacing everything at once would create unnecessary risk

Required response:

- keep current GRDB/Rust query path alive
- add BGE-M3 + reranker surgically

## 6. Experimental MoE scope creep

Severity: medium-high

Why it matters:

- the MoE is interesting but not the main product win on the target machine
- exposing it too early will consume time better spent stabilizing DeepSeek + router + retrieval

Required response:

- isolate MoE behind an experimental/manual path only

## 7. Missing or drifting local assets

Severity: medium

Why it matters:

- trained adapters currently live in `~/Downloads`
- retrieval assets are not present locally
- ad hoc asset handling will turn the rollout brittle fast

Required response:

- canonical manifest
- canonical prepared-model root
- deterministic prep scripts

## Rollout Gate

Do not move beyond artifact prep until:

1. DeepSeek DPO prep succeeds
2. Qwen router 4B prep succeeds
3. tokenizer/template audits pass for both
4. manifest paths resolve cleanly
5. missing retrieval assets are downloaded into the prepared root
