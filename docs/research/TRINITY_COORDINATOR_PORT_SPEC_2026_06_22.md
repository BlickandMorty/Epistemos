# TRINITY Coordinator — Native Port Spec (Swift 6 + Rust + MLX)

**Date:** 2026-06-22
**Goal:** Map every mechanic of `trinity_coordinator` precisely enough to port the WHOLE method
faithfully into Epistemos (System G `agent_runtime_v2` / `RuntimeRouter` / MLX), and to bundle the
real Sakana/TRINITY artifacts.
**Scope authority:** PLAN_V2 is authority. Do NOT commit this doc. This is a research/spec artifact.

## Anti-hallucination policy
Every fact below is labeled **[V]** VERIFIED (read from the primary source named), **[I]** INFERRED
(reasoned from verified facts — flagged as a design choice, not a source fact), or **[?]** COULD NOT
CONFIRM (looked, did not find — do NOT treat as fact). Source URLs are inline. Three independent
research passes (GitHub Elixir repo, arXiv paper, HuggingFace artifact API) were run and
cross-checked; their disagreements are called out explicitly in §0.1.

## 0. Source ledger

| # | Source | URL | Grounds |
|---|--------|-----|---------|
| G | trinity_coordinator (Elixir, MIT) | https://github.com/nshkrdotcom/trinity_coordinator | the WORKING reference impl — concrete mechanics + artifacts |
| P | TRINITY paper (Sakana AI / U-Mich, ICLR 2026) | https://arxiv.org/abs/2512.04695 · https://arxiv.org/html/2512.04695v3 | the METHOD (router + roles + sep-CMA-ES) |
| B | Sakana TRINITY blog | https://sakana.ai/trinity/ | sep-CMA-ES framing, pool description |
| H1 | Adapted-Qwen3 artifact (HF **dataset**) | https://huggingface.co/datasets/nshkrdotcom/trinity-coordinator-adapted-qwen3-0.6b | router head + SVF tensors + SHA-256 |
| H2 | Base router model (HF) | https://huggingface.co/Qwen/Qwen3-0.6B | Qwen3-0.6B base weights/tokenizer |

### 0.1 CRITICAL FRAMING — the paper and the Elixir port DIVERGE. Read before building.

The task brief's mental model ("Transformer²-style SVF as the core, z trained by RL/CE, explicit
`Σ ⊙ z` equations") is **substantially wrong for the paper** and only **partially true for the Elixir
port**. A faithful port must reconcile two different sources:

1. **The paper (P)** — TRINITY's *core method is a derivative-free evolutionary strategy
   (sep-CMA-ES)* that jointly optimizes a tiny coordinator (≤20K params = a ~10K linear head **plus**
   SVF singular-value scales on the SLM's second-to-last layer). **[V, P Abstract/§3.1/§4.1]**
   - SVF is a **minor, secondary** component; its scales are optimized **jointly with the head by
     sep-CMA-ES — NOT by RL, NOT by cross-entropy.** **[V, P §4.1]**
   - The paper gives **NO explicit SVF equations** — no `W=UΣVᵀ`, no `Σ'=Σ⊙z`, no z-dimension, no
     "expert" count. It describes SVF only in prose: "perform an SVD and only learn the singular
     value scales, keeping the orthogonal matrices fixed." **[V-ABSENT, P §3.1]** Do NOT invent them.
   - The paper releases **NO HuggingFace URL / model id / filename**; reproducibility statement only
     promises "source code and trained model weights" in supplementary material. **[V-ABSENT, P]**
     SakanaAI's HF org shows no TRINITY coordinator artifact. **[V — not found]**

2. **The Elixir port (G + H1)** — provides the *concrete, runnable mechanics the paper omits*: an
   actual SVF reconstruction formula in code, an actual `{10,1024}` linear head, and **downloadable
   artifacts with SHA-256** on HuggingFace. **BUT** its specifics (`layer 26`, the exact head shape,
   the SVF reconstruction normalization, the "ES vector iter_60") are **that port's engineering
   choices and artifacts, NOT paper-stated ground truth.** They are still the best concrete target
   we have, because they are real, verified, and downloadable.

**Consequence for the port:** We port the **Elixir port's concrete mechanics** (they are real and
testable) and consume **its** HF artifacts, while treating the paper as the conceptual frame. We must
NOT cite "layer 26" or the exact head shape as paper facts, and we must NOT fabricate paper equations.

---

## 1. Router mechanics (compact Qwen3-0.6B hidden-state extractor)

**Model id (production):** `Qwen/Qwen3-0.6B`, loaded via `Bumblebee.Text.Qwen3`,
`architecture: :for_causal_language_modeling`, `load_options: [type: :bf16]`, `expected_hidden_size: 1024`.
**[V, G `lib/trinity_coordinator/slm_profile.ex` `qwen_sakana_adapted/0`]**
(The default in `extractor.ex` is a CI stub `hf-internal-testing/tiny-random-gpt2` /
`Bumblebee.Text.Gpt2` — that is the test path, NOT production. Port the Qwen path.) **[V, G `extractor.ex`]**

**Input / prompt format:** messages are `%{role, content}` maps; `format_messages/1` renders each as
`"<role>: <content>"` joined by newlines into a single transcript string; tokenized with
`Bumblebee.apply_tokenizer(tokenizer, transcript)`. **[V, G `extractor.ex`]**

**Hidden-state extraction (the load-bearing call):** **[V, G `extractor.ex`]**
```elixir
Axon.predict(model_info.model, model_info.params, inputs,
  global_layer_options: [output_hidden_states: true])
# then take the PENULTIMATE token:
index = if seq_len <= 1, do: 0, else: seq_len - 2     # position -2
Nx.slice(hidden_states, [0, index, 0], [batch, 1, hidden_dim]) |> Nx.squeeze(axes: [1])
# output shape {1, 1024}
```
- **Token position:** penultimate (`seq_len - 2`, i.e. **-2**). The paper agrees: "the hidden state
  `h` corresponding to the **penultimate output token** as its sole input… directly after the SLM's
  final hidden layer." **[V, G `extractor.ex`] + [V, P Fig. 2 caption]** Rationale (paper): route
  before a full generation completes.
- **Hidden size:** d = 1024 (Qwen3-0.6B). **[V]**
- **Which LAYER's hidden state?** Paper says "directly after the SLM's final hidden layer" **[V, P]**.
  The Elixir artifact is named `adapted_qwen3_0_6b_layer26` and all SVF-adapted tensors are
  `model.layers.26.*` **[V, H1/G manifest]**. Whether the *extracted hidden state* is specifically
  layer-26's output vs. the final hidden state is **[?]** — the "layer 26" naming pertains to which
  weights were SVF-adapted (Qwen3-0.6B has 28 layers; layer 26 ≈ second-to-last). For the port,
  treat "read the final hidden state (which is shaped by the adapted layer-26 weights)" as the
  working hypothesis and **verify against a live forward pass** before locking.

**Feed into the coordination head:** the `{1,1024}` penultimate hidden state is the SOLE input to the
linear coordination head (§2). **[V, G + P]**

---

## 2. SVF / Coordination Head

### 2.1 Coordination head (the router projection) — VERIFIED concrete
- **Shape:** linear map ℝ^1024 → ℝ^10, **biasless**. The 10 outputs split into **7 agent logits + 3
  role logits** (paper writes it generically as `L+3`; here L=7). **[V, G `coordination_head.ex` /
  `sakana/head.ex`] + [V, P § "L+3 logits"]**
- **Build (Elixir/Axon):** **[V, G `coordination_head.ex`]**
  ```elixir
  Axon.input("hidden_state", shape: {nil, 1024})
  |> Axon.dense(10, name: "routing_head")   # total_outputs = num_agents(7) + num_roles(3)
  ```
- **Logit split:** `agent_logits = logits[0..6]`, `role_logits = logits[7..9]`. **[V, G]**
- **Biaslessness:** `head.ex` forces bias to a zero tensor; the head weight is stored `{10,1024}` and
  transposed into Axon's `{1024,10}` dense kernel layout at load. **[V, G `sakana/head.ex`]**
- **Param count:** ~10,250 with the (zeroed) bias slot, or 10,240 truly-used (`10*1024`). **[V]**
- **Role↔index mapping:** `0 → Worker, 1 → Thinker, 2 → Verifier`. **[V, G orchestrator + role_injector]**
- **Decision rule (argmax vs. sample):** the paper does NOT give the default rule as an equation
  **[?, P §4.7 only ablates an argmax variant]**. The Elixir port applies per-role/agent **margins**
  (e.g. the `:emily` profile sets `agent: 0.33, role: 0.82`) over the logits **[V, G `runtime_profile.ex`]**.
  **For the port: start with argmax over agent_logits and role_logits independently; expose the
  margin/threshold as config.** **[I — design choice]**

### 2.2 SVF (singular-value fine-tuning) — the math the Elixir port actually runs
**The paper has no equations; the Elixir port does. Port the Elixir formula (it is real and testable),
labeled as the reference impl's choice.**

`lib/trinity_coordinator/sakana/svd.ex` reconstructs each adapted weight: **[V, G]**
```elixir
{u, s, v} = Nx.LinAlg.svd(W, full_matrices?: false)   # THIN/reduced SVD (memory-critical)
scaled_s      = Nx.multiply(s, Nx.add(scale_offsets, 1))   # S' = S ⊙ (1 + offset)
normalization = Nx.divide(Nx.sum(s), Nx.sum(scaled_s))      # n = Σ(S) / Σ(S')
W' = ( u * reshape(scaled_s, {1, k}) ) `Nx.dot` v ) * normalization
#    W' = U · diag(S·(1+offset)) · V  ·  ( ΣS / ΣS' )
```
So the SVF parameter is an **offset vector** added to 1.0, multiplying the singular values, with a
**sum-preserving normalization** so total spectral energy is conserved. **[V, G `sakana/svd.ex`]**
This matches Transformer²/SVF in spirit, but the **normalization term is the port's specific choice**
(not in the paper). **[I/V — code-verified, paper-absent]**

**Adapted tensors (9 total, all from the SVF offset vector, contiguous slices):** **[V, G/H1 manifests]**
The offset vector is a flat **9216-length** array (`selected_singular_value_count: 9216 = 9 × 1024`),
sliced per-tensor in manifest order; each tensor's `min(rows,cols)=1024` singular values get scaled.

| # | Qwen source name | Elixir name | shape | sing.vals | offset range |
|---|---|---|---|---|---|
| 1 | `model.embed_tokens.weight` | `embedder.token_embedding.kernel` | [151936,1024] | 1024 | 0–1024 |
| 2 | `model.layers.26.self_attn.q_proj.weight` | `decoder.blocks.26.self_attention.query.kernel` | [2048,1024] | 1024 | 1024–2048 |
| 3 | `model.layers.26.self_attn.k_proj.weight` | `…key.kernel` | [1024,1024] | 1024 | 2048–3072 |
| 4 | `model.layers.26.self_attn.v_proj.weight` | `…value.kernel` | [1024,1024] | 1024 | 3072–4096 |
| 5 | `model.layers.26.self_attn.o_proj.weight` | `…output.kernel` | [1024,2048] | 1024 | 4096–5120 |
| 6 | `model.layers.26.mlp.gate_proj.weight` | `…ffn.gate.kernel` | [3072,1024] | 1024 | 5120–6144 |
| 7 | `model.layers.26.mlp.up_proj.weight` | `…ffn.intermediate.kernel` | [3072,1024] | 1024 | 6144–7168 |
| 8 | `model.layers.26.mlp.down_proj.weight` | `…ffn.output.kernel` | [1024,3072] | 1024 | 7168–8192 |
| 9 | `lm_head.weight` | `language_modeling_head.output.kernel` | [151936,1024] | 1024 | 8192–9216 |

**Source z-vector:** the offset vector originates from `priv/sakana_trinity/artifacts/sakana_model_iter_60.npy`
(the Sakana evolution-strategy "iter 60" checkpoint) and/or `trinity_router_es_vector.safetensors`,
converted to the adapted tensors at build time. **[V, G priv tree]** Note: the reference manifest
lists 19,456-element / 9,216-element variants — see §7 discrepancy. **The `.npy` z-vector is NOT
published on HF** (build-time input only). **[?-on-HF, V-in-repo]**

> **PORT-CRITICAL SIMPLIFICATION:** The adapted weights are already materialized as safetensors in the
> HF dataset (§7). **We do NOT need to run SVD at load time** — we can bundle the pre-reconstructed
> adapted tensors and just patch them into the base Qwen3-0.6B. SVD-on-device is only needed if we
> want to *re-adapt* (re-run SVF with a new z), which is out of scope for a faithful port. This
> removes the single hardest math dependency from the runtime path. **[I — major de-risk]**

---

## 3. Role split — Thinker / Worker / Verifier

**Roles (atoms `:worker`, `:thinker`, `:verifier`)** with these exact system prompts injected as a
leading `{role:"system"}` message by `role_injector.ex`: **[V, G `role_injector.ex`]**
- **Worker** (paper's "executes / Solver"): *"Execute the next concrete step of the plan. Write code,
  math, derivations, calculations, or concrete answer content that advances the solution."*
- **Thinker** ("strategizes"): *"Analyze the current state and provide high-level guidance, plans,
  decompositions, or critiques. Do not present unchecked final answers unless the transcript already
  contains enough evidence."*
- **Verifier** ("evaluates"): *"Check the current solution for correctness, completeness, and
  responsiveness. Start your response with exactly ACCEPT or REVISE. After REVISE, include a concise
  diagnosis."*

Paper definitions agree: Thinker = meta-level plans/decompositions/critiques; Worker = acts directly
to make concrete progress; Verifier = checks correct/complete/responsive. **[V, P §3]**

**Control flow / loop** — `lib/trinity_coordinator/orchestrator.ex`, `run_loop/4` →
tail-recursive `do_run_loop/8`. **[V, G `orchestrator.ex`]**
Per turn: extract hidden state → head → pick agent+role → inject role system prompt → dispatch to
provider → parse output → update transcript/state → check acceptance & budgets → recurse or return.
- **It is a FLAT turn loop, not nested recursion.** Depth = number of turns, not a recursion tree.
  **[V, G — single tail-recursive loop] + [V, P — "iterative over at most K turns"]** (The blog's
  "calls itself recursively" is Fugu marketing; the TRINITY loop is flat.)
- **Max turns K = 5** (default `max_turns`). **[V, G default + P "K=5"]**
- **Termination:** paper: `τ = min{k ≤ K : R_k = Verifier ∧ u_k = ACCEPT}`, else τ=K. **[V, P]**
  Elixir: Verifier output beginning with stop_token `"ACCEPT"` → `:accepted` → return
  `{:ok, response_text}`; else REVISE continues; also stops at max_turns or budget. **[V, G]**
- **Thinker can suggest the next route** (`suggested_role`/`suggested_role_id`), applied only if
  `respect_thinker_suggestions: true`. **[V, G]**
- **Objective (training):** `J(θ) = E_{τ~π_θ}[R(τ)]`, **binary terminal reward R∈{0,1}** (correct/
  incorrect). Sparse binary reward is *why* the paper uses ES over RL. **[V, P]**
- **Budgets (all optional, nil=unbounded):** `max_wall_time_ms`, `max_provider_calls`,
  `max_provider_latency_ms`, `max_verifier_revisions`, `max_estimated_cost_usd` (needs a cost
  estimator fn). Exceed → `{:error,{:budget_exceeded,kind,details}}` + `:run_failed` trace. **[V, G]**

---

## 4. Provider boundary

The downstream LLM calls go through an agent pool. **[V, G `agent_pool/*`]**
- **OpenAI adapter** (`agent_pool/openai.ex`): Req client; `url = <base>/chat/completions`, default base
  `https://api.openai.com/v1`; headers `Authorization: Bearer <key>` + `content-type: application/json`;
  `receive_timeout` default 30 000 ms; body defaults `max_tokens: 200`, `temperature: 0.2`. Response
  parse: `choices[0].message.content` (also handles a `text` field). **[V, G]**
- **OpenAI-compatible adapter** (`agent_pool/openai_compatible.ex`): body
  `%{model, messages, max_tokens(200), temperature(0.2)}`; same auth/headers; same `/chat/completions`
  path; delegates parsing to OpenAI adapter; non-200 → `{:error,{:http_error,status,body}}`. **[V, G]**
- **No streaming** in either adapter (no `stream` field, no chunk handling). **[V, G]**
- **Provider pool** (`provider_pool.ex`): default = **7 agents** (ids 0–6), all
  `provider: :openai, model: "gpt-4o-mini"` (names `:fast_openai, :default_reasoning,
  :compact_reasoning, :backup_openai, :fast_openai_2, :reasoner_2, :fallback_openai`). A **Gemini
  lane** exists (`gemini-3.1-flash-lite-preview`, `provider: :asm`, 180 s timeout). Agent index → spec
  via `spec_for_agent/2`. **[V, G]**
- Paper's actual pool was L=7 frontier models (GPT-5, Gemini-2.5-Pro, Claude-4-Sonnet, Gemma-3-27B-IT,
  DeepSeek-R1-Distill-Qwen-32B, Qwen-3-32B + 1 more); **the 7th id is [?]** — confirm against the
  paper's §4 table before relying on a specific pool. **[V-6/7, P]**
- Live providers gated behind `--allow-live` / governed authority; opaque auth refs, no secrets in
  traces. **[V, G README + `governed_authority.ex`]**

---

## 5. Trace persistence (JSONL)

`lib/trinity_coordinator/trace/{event,context,jsonl}.ex`. **[V, G]**
- **Event types:** `:run_started, :turn_started, :slm_extracted, :route_selected, :provider_called,
  :turn_completed, :run_completed, :run_failed`. **[V, G `trace/event.ex`]**
- **Base required fields:** `schema_version` (int, currently **1**), `event` (atom),
  `run_id` (string, default `"run_<unique_int>"`), `timestamp_ms` (int). Optional `turn` (int ≥ 0;
  not required on `:run_started`). **[V, G]**
- **Sink:** `{:jsonl, path}` → append-only newline-delimited JSON. Atom keys → strings; tuples/lists/
  maps normalized recursively; fallback `inspect/1`. **[V, G `trace/jsonl.ex`]**
- **Tensors are serialized as** `%{tensor_shape, tensor_backend, hash}` (shape + backend + content
  hash, never raw values). **[V, G]**
- **Redaction:** `:content` setting — `:hash` (default) hashes content; `:full` keeps it. **[V, G]**

---

## 6. Runtime / deps (and what's needed to RUN the math)

From `mix.exs`: **[V, G]**
- **Nx** + **EXLA** pinned to monorepo commit `6424c8902380380cd7a8c282b0557d653aead018` (override).
  This is the README's "thin-SVD memory optimization" pin (avoids materializing a ~92 GB U matrix in
  full SVD). README calls it **PR #1753**; the **commit ref is [V] in mix.exs**, the literal "#1753"
  string is **[?]** (README-reported, not code-confirmed).
- **Bumblebee** pinned `d0774e8ab8c4d5ac60ade95ec8dc9e1f0efd7306` (override).
- **Axon** `~>0.7`, **Req** `~>0.5`, **hf_hub** `~>0.3`.
- **EMLX is deliberately NOT a direct dep** — added manually for Apple Silicon. **[V, G README]**

**Runtime profiles** (`runtime_profile.ex`), each sets an Nx backend: **[V, G]**
- `:cuda_exla` (default prod) → `{EXLA.Backend, client: :cuda}`
- `:host_exla` → `{EXLA.Backend, client: :host}`
- `:binary` → `Nx.BinaryBackend` (`qwen_runtime?: false`)
- `:emlx` (Apple Silicon) → `{EMLX.Backend, device: :gpu}`
- `:emily` (Apple research) → `{Emily.Backend, []}`, margins `agent: 0.33, role: 0.82`

**SVD on Apple Silicon:** the SVD call is `Nx.LinAlg.svd/2`, executed on whatever Nx backend is active.
The expensive *full reconstruction* is gated to CUDA (`XLA_TARGET=cuda12`). Whether EMLX provides a
native SVD kernel is **[?]** — the thin-SVD pin is what makes large-matrix SVD feasible at all.
**For our port this is largely MOOT** (we bundle pre-adapted tensors; see §2.2 de-risk).

**OS-env boundary:** `config/runtime.exs` is the SOLE env reader (enforced by tests); reads only HF
vars (`HF_TOKEN`, `HF_HUB_CACHE`, `HF_HOME`, `HF_HUB_OFFLINE`). **[V, G]**

---

## 7. Artifacts obtainability — ledger (URLs / SHA-256 / sizes / license)

### 7.1 Adapted-Qwen3 bundle — router head + SVF tensors
- **Repo:** `nshkrdotcom/trinity-coordinator-adapted-qwen3-0.6b` — a HuggingFace **DATASET** repo
  (the `/api/models/...` endpoint 401s; `/api/datasets/...` works). **[V, H1]**
- **URL:** https://huggingface.co/datasets/nshkrdotcom/trinity-coordinator-adapted-qwen3-0.6b
- **Revision pinned by the repo:** `v1.0.0`, layout `checkpoint_directory`. **[V, G `artifact_pin.json`]**
- **Gated:** NO (`gated:false`, `private:false`). **[V, H1 API]**  — publicly downloadable + bundleable.
- **License:** **[?]** — `license_tag` is `null`, "No dataset card yet", no LICENSE in the tree.
  Base Qwen weights are Apache-2.0, but the **adapted bundle declares no license** → **confirm
  redistribution rights with the author (nshkrdotcom) before shipping commercially.** **[V — absent]**
- **Total LFS payload ≈ 654 MB** (~624 MiB). **[V, H1 sizes]**

**File list (sizes = bytes; SHA-256 = git-LFS oid; all [V] from HF tree API + LFS pointer cross-check):**

| Path | Size (bytes) | SHA-256 |
|---|---|---|
| `router_head.safetensors` | 41,050 | `7ff2db0e6659cac4dd68c5fff47a112768042b31321127aeb1412a6d8e6c09be` |
| `manifest.json` | 10,460 | (not LFS) — content hash `2a1476a4d2c7b66633232a564114dfb7ebe46f6bea624fc9ae9123678cafcbb9` |
| `checkpoints/0001_embedder.token_embedding.kernel.safetensors` | 311,165,039 | `09332ee11836e23b583a5336cbaf22b4d292527cbdb1adce245fa908f60a166c` |
| `checkpoints/0002_…self_attention.query.kernel.safetensors` | 4,194,425 | `2a7c181903bae8013a083dfc46df563b795a283dd26a48fcc04bae50876b8eb7` |
| `checkpoints/0003_…self_attention.key.kernel.safetensors` | 2,097,271 | `25b731084ffa3ef12bc94fcb7c9805c689d361fd051185ab9dbe35049c0437c8` |
| `checkpoints/0004_…self_attention.value.kernel.safetensors` | 2,097,273 | `c8238f211f6a733472ce2bd56729c358898427b05135436b3a04bc21c030166c` |
| `checkpoints/0005_…self_attention.output.kernel.safetensors` | 4,194,426 | `0736a3b878757ba594d19b5e283a5d35a6516249aa544e17456ae4fc1615074b` |
| `checkpoints/0006_…ffn.gate.kernel.safetensors` | 6,291,565 | `9ab06340d145dcf28aa6eb8f0c07d48562749e573f61da68f0e49b4c4ee897a2` |
| `checkpoints/0007_…ffn.intermediate.kernel.safetensors` | 6,291,573 | `88ee9f710c5eb4d0596be3da140c8ecbd6c40616727c3a6e43a2e71b0b9e07df` |
| `checkpoints/0008_…ffn.output.kernel.safetensors` | 6,291,567 | `07e112aa3778d010ede26f3eb2da5605035c3be79efb3e8e5d0facaf0f07853e` |
| `checkpoints/0009_language_modeling_head.output.kernel.safetensors` | 311,165,044 | `6608a2669a921201c5fe81b2ddb938764663d63f5ec612a855ab7d5f6dc6966c` |

(SHA-256 values above cross-corroborated: the Elixir `artifact_pin.json` [G] and the HF LFS pointers
[H1] agree on every hash.)

### 7.2 Base router model — Qwen3-0.6B
- **Repo/URL:** `Qwen/Qwen3-0.6B` — https://huggingface.co/Qwen/Qwen3-0.6B
- **License:** **Apache-2.0** — fully redistributable + bundleable. **[V, H2]**  **Gated:** NO. **[V]**
- Key files **[V, H2 API/LFS]:** `model.safetensors` 1,503,300,328 B
  sha256 `f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b`;
  `tokenizer.json` 11,422,654 B sha256 `aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4`;
  `config.json` 726 B; `generation_config.json` 239 B; `tokenizer_config.json` 9,732 B;
  `vocab.json` 2,776,833 B; `merges.txt` 1,671,853 B; `LICENSE` 11,343 B.
- ~1.5 GB. The base model is **still required** for the un-adapted layers; the adapted bundle only
  replaces 9 tensors (embeddings, layer-26, LM head). **[I, H1 manifest design]**

### 7.3 Fetch + verification logic (reference)
`artifact_fetch.ex` + `artifact_fetch/pin.ex`: loads `artifact_pin.json`, downloads each file via
`hf_hub_download(repo_id, filename, repo_type: :dataset, revision: pin.revision, verify_checksum:
true, expected_sha256)`, skips if local file already matches; SHA computed by streaming 65,536-byte
chunks into `:crypto.hash_init(:sha256)` → lowercase hex. Mix task `mix trinity.artifact.fetch`. **[V, G]**

### 7.4 Artifact discrepancy to resolve before bundling
The Elixir `manifest.json` references a single `adapted_tensors.safetensors` and a 19,456-element
z-vector (`sakana_model_iter_60.npy`), but the **actual HF tree** materializes the adapted tensors as
the 9 split `checkpoints/*.safetensors` (9,216 singular values). The single-file form is NOT in the
HF tree; the `.npy` z-vector is NOT on HF. **Use the 9 `checkpoints/` files + `router_head.safetensors`
+ `manifest.json` as the bundleable set.** The `19,456` figure may include other (non-SVF) components —
**[?]; resolve by reading the HF `manifest.json` directly during build.** **[V-discrepancy, G/H1]**

---

## 8. PORT PLAN → native Swift/Rust on Epistemos

### 8.0 Where each piece lands (verified Epistemos targets)
| TRINITY component | Epistemos home (verified path) | Lang |
|---|---|---|
| Orchestration loop (turns, roles, accept/budgets) | `agent_core/src/agent_runtime_v2/` (System G: `mission_run.rs`, `system_g_runtime.rs`, `run_event_log.rs`) | Rust |
| Agent+role selection policy | `Epistemos/LocalAgent/RuntimeRouter.swift` (`route(_)->RouteVerdict`, per-role chains, escalation log) | Swift |
| Provider boundary | `agent_core/src/providers/{openai_compatible,openai,gemini,claude}.rs` + Swift `Epistemos/Engine/LLMService.swift` | Rust+Swift |
| Router model (Qwen3-0.6B forward + hidden state) | `Epistemos/Engine/MLXInferenceService.swift` via vmlx-swift `LocalPackages/vmlx-swift/` | Swift/MLX |
| SVF tensor patching | new code over mlx-swift-lm safetensors loader (`LocalPackages/mlx-swift-lm/`, `VMLXHub`) | Swift/MLX |
| Coordination head matmul | `LocalPackages/vmlx-swift/Source/MLXLinalg/` (or a plain MLX `matmul`) | Swift/MLX |
| SVD (only if re-adapting) | `MLXLinalg.svd(_)` (`LocalPackages/vmlx-swift/Source/MLXLinalg/Linalg.swift:186`) OR Accelerate `cblas`/LAPACK | Swift/MLX |
| Trace JSONL | `Epistemos/Harness/TraceCollector.swift` (`TraceEvent`, per-session `.jsonl`) + Rust `RunEventLog` | Swift+Rust |
| Model pool / catalog | `Epistemos/State/InferenceState.swift` (`LocalTextModelID`) + `config/model_manifest.json` | Swift |
| Artifact download + SHA verify | `Epistemos/Engine/ModelDownloadManager.swift` (HF download URLSession) | Swift |
| Local inference server (optional API surface) | `LocalPackages/osaurus/` (`/v1/chat/completions`) | Swift |

### 8.1 STRAIGHTFORWARD (low risk)
- **Orchestration loop:** System G `agent_runtime_v2` already has the exact shape — Blueprint →
  MissionPacket → event stream → AnswerPacket, budgets (`budget.rs`), a replayable root-hashed
  `RunEventLog`, concurrency cap 64. Add: a turn loop ≤K=5, role injection, Verifier ACCEPT/REVISE
  parse, and the 5 budget kinds. This is additive, not a rewrite. **[V — runtime exists]**
- **Role prompts:** literal strings from §3 — drop-in constants.
- **Provider boundary:** `OpenAICompatibleProvider` (Rust) is already the universal
  `/v1/chat/completions` Bearer client; the body `{model,messages,max_tokens,temperature}` matches the
  Elixir adapter exactly. Each pool member = one config instance. **[V — exists]**
- **Trace JSONL:** `TraceCollector.swift` already writes per-line JSON to per-session `.jsonl`. Add the
  8 TRINITY event kinds + `schema_version`. The tensor `{shape,backend,hash}` serialization is a small
  helper. **[V — exists]**
- **Coordination head:** a `{1024}·{1024,10}` biasless matmul + argmax — trivial in MLX or Accelerate.
- **Artifact bundling + SHA verify:** `ModelDownloadManager` already does HF download with
  cache-ignoring URLSession; add SHA-256 streaming verification against the §7 ledger. SVD-free path
  (§2.2) means we bundle pre-adapted safetensors. Note CLAUDE.md "do not COMMIT model files" — these
  ship via download-to-AppSupport / bundle-at-build, not git. **[V — exists]**

### 8.2 HARD (the real blockers)
1. **Hidden-state extraction from MLX — THE #1 BLOCKER.** Verified: **no hidden-state / activation
   tap exists anywhere** (`MLXInferenceService`, Osaurus `MLXService`, vmlx-swift, mlx-swift-lm grep:
   no `hiddenState`/`outputHiddenStates`/`lastHiddenState`). The current MLX path is **text-generation
   only**. **[V — gap]** We must add a forward-pass hook that returns the penultimate-token hidden
   state `{1,1024}` from a Qwen3-0.6B running on MLX. mlx-swift exposes the model graph so this is
   *buildable* (run the transformer stack, capture the residual stream after the final/adapted layer,
   slice token -2), but **no seam exists today** — this is net-new MLX code and the highest-risk item.
2. **SVF tensor patching into an MLX Qwen3.** We must load base Qwen3-0.6B in MLX, then replace the 9
   adapted tensors (embeddings, layer-26 Q/K/V/O + MLP gate/up/down, LM head) with the bundled
   safetensors. mlx-swift-lm loads Qwen3 + safetensors already; the patching is name-mapping work
   (Elixir names ↔ MLX module names ↔ Qwen HF names — the §2.2 table is the Rosetta stone). Risk:
   tensor layout/transpose + dtype (bf16) parity. **[I — medium]**
3. **SVD on MLX — LARGELY AVOIDED.** `MLXLinalg.svd` exists (`Linalg.swift:186`), and Accelerate
   LAPACK is available, so SVD is *possible* if we ever re-adapt. But because we bundle pre-adapted
   tensors (§2.2), **runtime SVD is not on the critical path.** Keep it out of v1. **[I — de-risk]**
4. **`Qwen3-0.6B` is not in the catalog.** `LocalTextModelID` has no 0.6B entry (only research docs
   mention it). Add a catalog entry + `model_manifest.json` role (or a dedicated "router model" slot
   that is NOT user-selectable as a chat model). **[V — gap]**
5. **Numerical parity proof.** Per ARCHITECTURE_TIER_PROMOTION_CANON, we must prove the Swift/MLX
   router reproduces the Elixir router's routing decisions on a fixture set (same transcript → same
   agent/role). Build a golden-vector test: feed N transcripts through the reference (or a captured
   trace) and assert the native head picks the same argmax. **[I — required gate]**
6. **License clearance on H1.** No declared license on the adapted bundle (§7.1). Shipping requires
   owner sign-off / author contact. **Blocker for release, not for prototyping.** **[V]**

### 8.3 Suggested build sequence (additive, gated)
1. Add `Qwen3-0.6B` router-model slot + artifact ledger (§7) to download/verify (SHA-256). No SVD.
2. Build the MLX hidden-state tap (§8.2.1) — penultimate `{1,1024}` from Qwen3-0.6B. Golden test vs a
   captured Elixir `slm_extracted` trace tensor (shape+hash). **[hardest — do first, prove it]**
3. Patch the 9 adapted tensors into the MLX model; verify forward-pass hidden state matches the
   adapted reference (not just base). 
4. Load `router_head.safetensors` `{10,1024}`, biasless matmul → 7 agent + 3 role logits → argmax.
   Golden test: transcript → (agent,role) parity with the reference.
5. Wire role injection + the ≤5-turn loop + Verifier ACCEPT/REVISE + 5 budgets into
   `agent_runtime_v2`; emit the 8 trace events through `TraceCollector` + `RunEventLog`.
6. Bind pool members to `RuntimeRouter` lanes (local MLX / cloud providers) — local-first ordering,
   honest escalation. Promote behind `EPISTEMOS_RUNTIMEROUTER_LIVE_V0` + Stage-2 parity gate.
7. (Optional) expose the whole orchestrator behind the loopback OpenAI-compatible server
   (`LocalModelServer` / Osaurus) as one virtual model id so act/work/chat converge on it.

### 8.4 Honest blockers (summary)
- **MLX hidden-state extraction does not exist** — must be built from scratch (highest risk). [V]
- **No Qwen3-0.6B in catalog** — must be added. [V]
- **H1 artifact license is undeclared** — release blocker until cleared. [V]
- **Paper ≠ port** — do not cite layer-26/head-shape/SVF-normalization as paper facts; they are the
  reference impl's choices (real & testable, but not authoritative). [V]
- **Numerical parity** between native MLX router and the Elixir/Sakana reference must be proven, not
  assumed (bf16, transpose, layer-index, decision-margin all can diverge). [I]
- **SVD on MLX/Apple Silicon** is unproven but **avoided** by bundling pre-adapted tensors. [I]

---

## 9. Open questions (need owner decision or live confirmation)
1. **Layer-index of the extracted hidden state** — final hidden state vs. specifically layer-26 output?
   Confirm against a live forward pass / the reference's `slm_extracted` trace. [?]
2. **Default decision rule** — argmax vs. sampling vs. the port's per-role margins (`agent 0.33 / role
   0.82`)? Paper does not state it. [?]
3. **The 7th model in the paper's pool** — confirm against §4 table. [?]
4. **`19,456` vs `9,216` z-vector length** — what are the extra components? Read HF `manifest.json`
   at build time. [?]
5. **H1 license** — contact nshkrdotcom / confirm redistribution rights before shipping. [V-needed]
6. **Re-adaptation scope** — do we ever want to re-run SVF with our own z (requires on-device SVD), or
   only consume the published adapted tensors? (Recommend: consume-only for v1.) [decision]
7. **Provider pool composition** — Epistemos local+cloud lanes vs. the paper's frontier pool; which
   models are the 7 agents in our deployment? [decision]
