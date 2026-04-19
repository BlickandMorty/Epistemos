# Master Model Stack Plan — 2026-04-18

Authoritative audit of Epistemos's model catalog. Everything that ships
locally or routes to cloud is captured here, grouped by **role** and
**status**. Anything that isn't in this doc either isn't in the stack or
is on deliberate deferral. Use this as the single reference whenever
you ask "why is this model here" or "where does X fit."

This document supersedes ad-hoc notes in `docs/AGENT_PROGRESS.md` for
model-stack questions.

---

## 1 · Role-First Stack (the user-facing shape)

The app exposes models by **what they're good at**, not by family name.
Each role maps to a first-class local model; cloud models fill the
agent + research + plain-chat tiers. TriageService's preferred-order
table in `Epistemos/Engine/TriageService.swift` is derived from this
table.

| Role | Primary (post-ship) | Fallback | Purpose |
|---|---|---|---|
| **Fast Local** | `Qwen/Qwen3-4B-MLX-4bit` | Bonsai 8B / 4B | Quick chat, routing, tool-calling |
| **Reasoning Local** | `mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit` | — | CoT, math, logic |
| **Coding Local** | `mlx-community/Qwen3-Coder-Next-4bit` | Qwen 2.5 Coder 7B | Code gen, debug, tool-heavy |
| **Flagship Coder** | `mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit` | Qwen 3.6 35B A3B | Large-surface code, MoE |
| **Function-Calling Local** | `leonsarmiento/Hermes-4.3-36B-4bit-mlx` | 3bit variant | On-device agent tool use |
| **Flagship Local** | `unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit` | `mlx-community/Qwen3.6-35B-A3B-4bit-DWQ` | Best local generalist |
| **Gemma 4 (Preview)** | `unsloth/gemma-4-E4B-it-UD-MLX-4bit` | — | NOT SHIPPABLE until MLX-Swift loader lands (tracked: `mlx-swift` issue #389) |
| **Fast Cloud** | GPT-5.4 Nano / Claude Haiku 3.5 | — | Quick cloud |
| **Pro Cloud** | GPT-5.4 / Claude Sonnet 4 | — | Default cloud |
| **Agent Cloud** | Claude Opus 4.7 / GPT-5.4 | — | Cloud-backed agent loops (OpenAI + Anthropic only per `supportsAgentTier`) |
| **Research Cloud** | Gemini 2.5 Pro / Perplexity Sonar | — | Long-context, web fetch |

---

## 2 · THIS SESSION (2026-04-18) — Shipped

### Catalog additions
Each is added as a new `LocalTextModelID` case with a full descriptor in
`LocalModelCatalog.textDescriptors` and a `capabilityRole` tag.

| Model | HF repo | Role | Memory | Why |
|---|---|---|---|---|
| Qwen3 4B MLX (official) | `Qwen/Qwen3-4B-MLX-4bit` | `.fastLocal` | 8 GB | Official Qwen MLX build; native tool-calling; clean fast tier that doesn't depend on Gemma 4 |
| Qwen3 Coder Next | `mlx-community/Qwen3-Coder-Next-4bit` | `.codingLocal` | 8–12 GB | Qwen3-generation coder; tool-calling native |
| Qwen3 Coder 30B A3B | `mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit` | `.codingLocal` | 24 GB | Flagship MoE coder |
| Hermes 4.3 36B (4bit) | `leonsarmiento/Hermes-4.3-36B-4bit-mlx` | `.functionCallingLocal` (new) | 24 GB | SOTA open-source function calling; based on ByteDance Seed 36B |
| Hermes 4.3 36B (3bit) | `leonsarmiento/Hermes-4.3-36B-3bit-mlx` | `.functionCallingLocal` | 18 GB | Same as above; 32GB-class Macs |
| Qwen 3.6 35B A3B — Unsloth UD | `unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit` | `.highEndLocal` | 24 GB | Unsloth Dynamic 4-bit = better quality at same size than `mlx-community/Qwen3.6-35B-A3B-4bit` |
| Qwen 3.6 35B A3B — DWQ | `mlx-community/Qwen3.6-35B-A3B-4bit-DWQ` | `.highEndLocal` | 24 GB | Dynamic Weight Quantization variant; ship alongside Unsloth UD so user can A/B compare |

### New capability role
- `ModelCapabilityRole.functionCallingLocal` — the tool-calling specialist
  tier (Hermes 4.3). Distinct from `.codingLocal` (code-heavy) and
  `.highEndLocal` (generalist flagship).

### Triage changes
`TriageService.preferredAutomaticLocalModel` preferredOrder rewritten:

```
.fast + coding/debug:     [qwen3CoderNext, qwen3Coder30BA3B, qwen25Coder7B, deepseekR1, bonsai8B]
.fast + synthesis etc:    [deepseekR1, qwen36_UD, qwen3_4B, bonsai8B, bonsai4B]
.fast + simpleAsk etc:    [qwen3_4B, bonsai4B, bonsai8B, deepseekR1, qwen36_UD]
.pro + coding:            [qwen3Coder30BA3B, qwen3CoderNext, qwen36_UD, deepseekR1]
.pro + default:           [qwen36_UD, qwen36_DWQ, deepseekR1, qwen25Coder7B]
.thinking + coding:       [deepseekR1, qwen3Coder30BA3B, qwen36_UD]
.thinking + default:      [deepseekR1, qwen36_UD, qwen36_DWQ]
.agent + coding:          [qwen3Coder30BA3B, qwen25Coder7B, hermes43_36B_4bit, deepseekR1]
.agent + default:         [hermes43_36B_4bit, hermes43_36B_3bit, qwen36_UD, qwen3Coder30BA3B, deepseekR1]
```

Gemma 4 remains excluded from every preferred-order list until the
Swift loader lands (see Deferred).

### Flag updates
- `canActAsAgent`: adds `qwen3_4B4Bit`, `qwen3CoderNext4Bit`,
  `qwen3Coder30BA3B4Bit`, `hermes43_36B4Bit`, `hermes43_36B3Bit`,
  `qwen36_35BA3B_DWQ4Bit`, `qwen36_35BA3B_Unsloth4Bit`.
- `supportsThinkingMode`: adds `qwen36_35BA3B_DWQ4Bit`,
  `qwen36_35BA3B_Unsloth4Bit`, `hermes43_36B4Bit`, `hermes43_36B3Bit`.
- `isEpistemosShippedLocalModel`: adds all seven new models; drops
  the `mlx-community/Qwen3.6-35B-A3B-4bit` plain variant from the
  preferred-order path (kept in the enum so existing installs still
  resolve but Unsloth UD takes the flagship slot).

### Stack simplification
The user-facing picker now exposes exactly these tiers for LOCAL:
- Fast Local (Qwen3-4B, Bonsai)
- Reasoning Local (DeepSeek R1 7B)
- Coding Local (Qwen3-Coder Next + 30B A3B, Qwen 2.5 Coder 7B)
- Function-Calling Local (Hermes 4.3 36B 4bit + 3bit)
- Flagship Local (Qwen 3.6 35B A3B — Unsloth UD / DWQ)
- Gemma 4 (Preview — coming when Swift loader ships)

Everything else in the catalog (LFM, Mamba2, Jamba, Falcon, SmolLM3,
Devstral, Mistral, Gemma 3, Llama 4 Scout, Qwopus) stays installable
but is flagged `isExperimentalForEpistemos` or not surfaced in the
auto-router. Users who know what they want can still pick them.

---

## 3 · NEXT SESSION — Queued Work

Every item here is a real workstream, not "maybe someday." Each has a
clear scope + verifiable completion signal.

### a. Port Gemma 4 Swift loader from `SharpAI/SwiftLM`
- **Source**: `SharpAI/SwiftLM` (MIT-licensed, working Gemma 4 Swift impl)
- **Target**: `LocalPackages/mlx-swift-lm/Libraries/MLXLLM/Models/Gemma4Text.swift`
- **Scope**: Port `Gemma4TextConfiguration` + `Gemma4Model` (E4B dense
  variant first). Port the MoE variant (`gemma-4-26b-a4b`) second.
  Register both in `LLMTypeRegistry` under `"gemma4"` and `"gemma4_text"`
  — replace the current alias-to-Gemma-3n hack in
  `LocalPackages/mlx-swift-lm/Libraries/MLXLLM/LLMModelFactory.swift`.
- **Verify**: `unsloth/gemma-4-E4B-it-UD-MLX-4bit` actually loads and
  generates coherent tokens. Run a "describe this sentence" smoke test.
- **Once green**: restore Gemma 4 tiers to triage preferredOrder, drop
  the triage-ready filter introduced in commit `f3e9c6d4`, switch
  catalog HF IDs from `mlx-community/gemma-4-*` to `unsloth/gemma-4-*-UD-MLX-4bit`.

### b. Convert OpenThinker3-7B to MLX 4-bit
- **Source**: `open-thoughts/OpenThinker3-7B` (Qwen2.5-7B-Instruct base)
- **Conversion**: run `mlx_lm.convert --hf-path open-thoughts/OpenThinker3-7B --quantize --q-bits 4`
- **Upload**: push to `epistemos/OpenThinker3-7B-MLX-4bit` or use an
  existing community fork once one appears.
- **Why**: 33% better reasoning than DeepSeek-R1-Distill-Qwen-7B per
  the OpenThoughts3 paper; same base model = no new arch support
  needed in mlx-swift-lm.
- **Catalog**: add as `openThinker3_7B4Bit`, role `.reasoningLocal`,
  replaces DeepSeek R1 7B as the primary reasoning tier once verified.

### c. Add QwQ-32B as flagship reasoning ✅ SHIPPED 2026-04-19 (`98897428`)
- **Source**: `mlx-community/QwQ-32B-4bit`
- **Memory**: 24 GB
- **Role**: `.reasoningLocal` (flagship tier, above DeepSeek R1 7B)
- **Why**: comparable to DeepSeek-R1 at 32B; existing Qwen arch.
- **Landed**: new `LocalTextModelID.qwqFlagship32B4Bit` case, full descriptor
  in `LocalModelInfrastructure.optionalBaselineModelIDs`, leads
  `TriageService.preferredOrder` for `.thinking` mode on both coding and
  default intents. Revision pinned to `main` pending automated SHA
  sweep via `scripts/pin_catalog_revisions.sh`.

### d. Qwen3-Coder (Flash variant if/when released)
- Track upstream `Qwen/Qwen3-Coder-*-Flash` for speculative-decoding-
  friendly variants. Not blocking.

### e. Optional: smaller Hermes for 16GB Macs
- `leonsarmiento/Hermes-4.3-36B-3bit-mlx` is the current smallest;
  check for a future 7B/8B Hermes release at 4bit that actually runs
  on 16GB class hardware.

---

## 4 · DEFERRED — Watchlist, not scheduled

Items that make sense long-term but have blockers we can't clear alone.

### DFlash (speculative decoding for Qwen)
- **What**: block-diffusion speculative decoder; 3-5x speedup on Qwen.
- **Status**: Python-only implementations (`Aryagm/dflash-mlx`,
  `z-lab/dflash`). No Swift port exists.
- **Blocker**: integrating into our Swift/macOS app would require
  either (a) a Python subprocess — violates the CLAUDE.md "no sidecar
  for inference" rule, or (b) a multi-week Swift port of DFlash's
  block-diffusion algorithm, or (c) waiting for mlx-swift-lm to
  upstream speculative-decoding support.
- **Current action**: none. Track only.
- **Revisit trigger**: a Swift MLX speculative-decoding library
  becomes available OR mlx-swift-lm adds a public speculative-decoding
  API.

### DDTree-MLX (tree-based speculative decoding)
- **What**: `humanrouter/ddtree-mlx` — 10-15% faster than DFlash on
  code; auto-extends to new model families.
- **Status**: same as DFlash — Python-only.
- **Action**: same watchlist treatment.

### Gemma 4 31B JANG
- `dealignai/Gemma-4-31B-JANG_4M-CRACK` — abliterated/mixed-precision
  variant. Keep in catalog behind the "Preview" gate with the rest of
  the Gemma 4 family; unblocks with the Swift loader port.

### Gemma 4 audio / vision modes
- Gemma 4 is multimodal (audio + vision). Post-loader, explore exposing
  audio ASR + image input as new capability roles. Probably a separate
  workstream from the base port.

---

## 5 · Verification Commands

After each session's work lands:

```
# Rust tests (currently 511 tests)
cargo test --manifest-path agent_core/Cargo.toml

# Swift build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' build

# Full Swift test suite (currently 3339 tests)
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' test -only-testing:EpistemosTests

# Runtime smoke test per role — each should produce coherent output:
#   Fast: "hi" → Qwen3 4B (or Bonsai fallback)
#   Reasoning: "what's 2x3x5 step by step" → DeepSeek R1
#   Coding: "write a Swift function that sorts" → Qwen3 Coder Next
#   Function-calling: "create a note about X" → Hermes 4.3 (local) OR
#                      cloud agent loop (OpenAI/Anthropic)
#   Flagship: long research prompt → Qwen 3.6 35B A3B UD
```

---

## 6 · Honesty Ledger

Things I want to say out loud so future-me doesn't forget the tradeoffs:

- **Hermes 4.3 36B is based on ByteDance Seed 36B.** That means
  `model_type` in its config.json isn't plain Llama-3 — verify once
  the weights are downloaded that `mlx-swift-lm`'s type registry
  actually resolves it. If not, we file an upstream issue and gate
  Hermes behind a "preview" flag same as Gemma 4 until resolved.
- **Qwen3-Coder-Next `model_type` should resolve to `qwen3` or a close
  variant** that mlx-swift-lm already supports; still verify on first
  load.
- **The "2-bit Qwen 3.6" the user asked about does not actually exist
  on Hugging Face as of this audit.** What does exist: Unsloth UD
  4-bit, DWQ 4-bit, MXFP4, BF16. We ship UD + DWQ so the user can
  compare; both are strictly better than the plain `mlx-community`
  4-bit the catalog was using.
- **Gemma 4 is not just "broken" — it's a fundamentally new
  architecture** (MatFormer-style with sliding/full attention mix,
  KV-shared layers, MoE variant with 128 experts). Cannot alias it
  to an existing Gemma 3 / 3n decoder and expect correct output.
  Either port properly or keep preview-gated.

---

*Last revised: 2026-04-18. Update this doc in the same PR as any
stack change so the audit trail stays self-consistent.*
