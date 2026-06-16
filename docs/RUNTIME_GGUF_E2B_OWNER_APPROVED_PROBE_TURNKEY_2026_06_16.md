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

## 6. What actually LANDED (2026-06-16) — the proven llama-cli seam, end to end

Ahead of the mistral.rs in-process target in §5, the **proven** hardened
`llama-cli` path was wired all the way into the app, Pro-gated and flag-OFF.
This is the "models just run" path that works today on the ship rig; §5 remains
the future zero-copy ideal that removes the subprocess.

End-to-end chain (all commits on `main`):
1. **Rust provider** — `agent_core/src/providers/gguf_cli.rs` `GgufCliProvider`
   (`#[cfg(feature = "pro-build")]`). Streams `llama-cli` stdout line-by-line;
   `runtime() == Local` so the agent loop refuses it (Gemma stays non-agent).
   Command mirrors the gate card: offline, temp=0, seed=0, single-turn, capped
   ctx/batch, no-mmap, log-disable; `harden_cli_subprocess` env-scrubs it.
2. **Provider factory** — `bridge.rs` maps a `gguf:/abs/path.gguf` slug to the
   provider, placed before the dynamic `name.contains('/')` arm, Pro-gated,
   empty path rejected, no hidden fallback.
3. **Non-agent FFI** — `run_local_gguf_generation(model_path, prompt,
   system_prompt, max_output_tokens, delegate)` (Pro-only). BYPASSES the agent
   loop (which refuses Local), drives `stream_message` directly, forwards each
   `TextDelta` to `on_text_delta` and the final `MessageStop` to `on_complete`.
4. **Swift engine builder** — `Epistemos/Bridge/LocalGgufRuntimeBridge.swift`
   (`#if !EPISTEMOS_APP_STORE`). `LocalGgufCliRuntime.engineBuilderIfEnabled()`
   returns a `LocalGGUFEngine` backed by the FFI when the
   `EPISTEMOS_LOCAL_GGUF_CLI_RUNTIME_V0` flag is armed, else `nil`.
5. **Injection** — `AppBootstrap.swift:1806` passes that builder into
   `LocalGGUFInProcessRuntime(engineBuilder:)`. The runtime's reserved
   `defaultEngineBuilder` (which throws `backendUnavailable` until the future
   in-process `GGUFRuntimeBridge` module lands) is left untouched.

**Default posture: OFF.** Flag unset ⇒ builder nil ⇒ `backendUnavailable`
(honest). On MAS the whole surface is compiled out. To arm an on-device
validation run on Pro: `EPISTEMOS_LOCAL_GGUF_CLI_RUNTIME_V0=1` (env) or the
matching `UserDefaults` bool, with a prepared GGUF in the model directory the
locator resolves. This is the seam the owner flips after the runtime-plural
witness chain (RunEventLog + AnswerPacket + rollback + MAS/Pro review) is green.
