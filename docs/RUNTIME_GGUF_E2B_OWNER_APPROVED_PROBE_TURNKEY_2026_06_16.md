# Turnkey: owner-approved on-device E2B GGUF one-token probe

> Status: actionable runbook. This is the **owner action** that the
> `small_compressed_model_owner_approved_runtime_probe` gate (commit `9fd199063`)
> is fail-closed on. Running it on a signed build produces the first-token
> receipt that unlocks the next frontier
> (`..._first_token_owner_gated_frontier`) and is the fastest path to a GGUF
> model actually running on this Mac.

## Why this exists

The GGUF runtime lane (Gemma 4 QAT E2B/E4B/12B, the yuxinlu1 coder fine-tune) is
**Pro-gated research**. Today the only wired GGUF path is the OpenAI-compatible
`llama_cpp` provider (a llama.cpp **server** you run yourself). The in-process
loader (`mistral.rs`, see §4) is not built yet. Until it is, this `llama-cli`
one-token probe is the canonical, witness-backed way to prove the smallest model
loads and emits a token on this hardware — exactly what the canon's gate chain
(`small_compressed_model_*`) gates.

This is the **smallest eligible model first** (E2B), offline, one token, capped,
no server, no hidden download. Larger tiers (E4B/12B/coder) stay gated until E2B
proves.

## 1. Install llama.cpp (the visible command card)

```sh
brew install llama.cpp          # provides /opt/homebrew/bin/llama-cli
which llama-cli                 # must print /opt/homebrew/bin/llama-cli
```

The gate's command card pins `/opt/homebrew/bin/llama-cli` as the ONLY direct
probe binary. `/opt/homebrew/bin/llama-server` is denied-by-default (a sidecar).

## 2. Get the E2B QAT GGUF (the model-path readiness card)

- Repo: `google/gemma-4-E2B-it-qat-q4_0-gguf`
- File: `gemma-4-E2B_q4_0-it.gguf` (~3.35 GB)
- Revision: `1894d1fc0a19d86697abd40483f5983c867df03f`

Download it however you prefer (the gate never downloads for you — no hidden
HF/URL fetch). Note the absolute local path; call it `$MODEL_PATH`.

## 3. The exact one-token probe command

This is the gate's `REQUIRED_FLAGS` verbatim — offline, one token, ctx/batch
capped, deterministic, no mmap, no network, no display of the prompt:

```sh
PROMPT="Say the single word: ok"   # synthetic, non-user
llama-cli \
  --offline \
  --model "$MODEL_PATH" \
  --prompt "$PROMPT" \
  --predict 1 \
  --ctx-size 512 \
  --batch-size 32 \
  --ubatch-size 32 \
  --temp 0 \
  --seed 0 \
  --no-conversation \
  --single-turn \
  --simple-io \
  --no-display-prompt \
  --no-mmap \
  --log-disable
```

**Forbidden** (the gate rejects these): `--hf-repo`/`-hf`/`-hfr`, `--hf-file`,
`--model-url`, `--docker-repo`, `--hf-token`, `--server`, `--conversation`,
`--mmap`, `--mlock`. If you need any of those, you are off the gated path.

Expected: it loads E2B on Metal, emits **one** token, and exits. That single
(redacted) token + the before/after memory sample + clean cancellation is the
proof.

## 4. Owner approval (the gate phrase)

The gate (`small_compressed_model_owner_approved_runtime_probe`) stays
fail-closed until you explicitly approve with the phrase:

```
APPROVE_SMALL_COMPRESSED_E2B_LLAMA_CLI_ONE_TOKEN_PROBE_V0
```

When you've run §3 successfully and want the chain to advance, tell me that
phrase + the real `$MODEL_PATH` (and that the run succeeded). That lets me
materialize the first-token receipt artifact and build the next gate
(`..._first_token_owner_gated_frontier`) against real, signed evidence — no
fabrication.

## 5. The in-process loader (the real "models just run" path) — design

To make the QAT 12B + coder fine-tune run **without** a separate server,
the in-process runtime target is **`mistral.rs`** (pure Rust, async, Metal,
GGUF, already supports the Gemma/Qwen families). Chosen over:
- `llama-cpp-2` — C++ FFI bindings; works in-process but adds a libllama C++
  build dependency and sandbox/hardened-runtime friction.
- raw `candle` — the framework `mistral.rs` is built on; usable directly but
  `mistral.rs` already wraps the loader + sampler + KV cache.

Integration shape (Pro-gated, fail-closed, per the runtime-plural canon —
needs owner approval + RunEventLog + AnswerPacket + rollback + MAS/Pro boundary
review + harness witnesses before it leaves research):
1. A `#[cfg(feature = "pro-gguf-runtime")]` provider seam in `agent_core` that
   implements the same on-device provider trait as MLX — no hidden cloud
   fallback, no default-route mutation.
2. `mistral.rs` loads `$MODEL_PATH` on the Metal backend; one-token then
   streaming, every token forwarded to the delegate (STREAM EVERYTHING).
3. RunEventLog + AnswerPacket + rollback wired from the first probe; the
   RuntimeRouter admits the lane only after the witness chain is green.
4. Memory-budgeted for M2 Pro 16 GB: E2B/E4B/coder-Q4_K_M fit; 12B QAT is the
   Pro flagship after E2B/E4B prove; 26B-A4B MoE + 70B stay gated.

This is the next multi-session build slice; it pulls a heavy dependency, so it
should land in a build environment that won't thrash the 16 GB rig.
