# Session Checkpoint — 2026-06-19 (build loop)

A long autonomous build-loop session. Everything below is build/cargo-verified
(full-lib **5473/0**, `--features pro-build` **5736/0**, all Swift builds 0 errors)
and pushed to `main`. The high-value work is **flag-gated** and awaits your
**in-app verification** — flip the flags, confirm behaviour, then we tick the
ledger items.

## Shipped — model selection (the "everything routes to Qwen" multi-layer fix)

The re-diagnosis named four selection layers; all four are now fixed, each small,
flag-gated, pure-tested, and **un-ticked pending your in-app confirm**:

| Layer | Commit | Flag (default OFF = today's behaviour) |
|---|---|---|
| InferenceState model-pin (no silent Qwen substitute for an explicit pick) | `a645e6623` | `EPISTEMOS_AUTOSUBSTITUTE_LOCAL_MODEL` (OFF = honest) |
| Auto-mode recommends the foundation lineup, not Qwen-first | `71aecb122` | `EPISTEMOS_FOUNDATION_RECOMMEND_V0` |
| Honest unavailable specialist pick (no silent fall to Qwen) | `539577603` | `EPISTEMOS_HONEST_UNAVAILABLE_SPECIALIST_PICK_V0` |
| RuntimeRouter lane-level staging (shadow machinery + resolved→lane mapper) | `b7a0796af`, `6d22f0048` | `EPISTEMOS_RUNTIMEROUTER_LIVE_V0` |

**In-app check:** select a non-default model and confirm it answers. The RuntimeRouter
**STAGE-1c observe-only hot-path call** (at the `ResolvedRuntime` construction site) is
the documented remaining piece — all its pure primitives are shipped + tested.

## Shipped — three research-grounded fixes (from the deep-research audits)

- **D2 staging-purge defeats resume** (`96ea66805`) — `-resume` partials exempt from the
  30-min stale purge, so slow/large downloads resume instead of restarting (the
  "corrupted/incomplete" root). No flag (always-on, safe).
- **S4 cloud plain-chat tools on ALL providers** (`2377e8be9`) — flag
  `EPISTEMOS_CLOUD_CHAT_TOOLS_ALL_PROVIDERS_V0`. **Verifiable now** (cloud needs no model
  download): flip it on, plain-chat a non-OpenAI provider with a vault query → expect the
  vault.search tool box.
- **OQ-1 session-corpus mismatch** (`bc1fd0889`) — `session_search` surfaces an honest
  corpus layout + hint instead of a silent zero when conversations live in the
  shadow-indexed `/chats/` corpus.

## Shipped — GGUF-Gemma grammar tool-call foundation

Rust core + FFI (`01f88d9be`), Swift input builder (`cdd626fcf`), output parser
(`a5f420bf4`) — flag `EPISTEMOS_GGUF_TOOL_GRAMMAR_V0`. The loop integration (a new GGUF
tool-turn path) is the in-app-dependent follow-on.

## Shipped — the advertised-model "stack" (reqs 6/7) + req 11

Store (`532cbb699`) → picker visibility wiring (`6b26319fe`) → row assembler
(`fa9f17f59`) → Settings stack UI (`3f698a7ab`) → foundation-GGUF listing fix
(`8d120af0a`). Owner-controlled advertise toggles; canon-as-default; visibility-only
(never deletes). LFM/Gemma/VibeThinker now listed.

## Shipped — hardening

- Auto-route detector live-wiring (`6ba7a0418`) — flag `EPISTEMOS_AUTO_TOOL_ROUTE_V0`.
- All 4 S4 schema↔impl drifts closed (`0e0bee35c`, `92a48723a`) — every tool schema
  honestly declares the keys its handler reads.

## What's pending (owner-in-app or follow-on)

1. Flip the flags above and confirm in-app, then we tick the ledger items.
2. RuntimeRouter STAGE-1c observe-only hot-path call (documented; primitives ready).
3. GGUF-Gemma tool-loop integration (needs model download working first).
4. Model download/install end-to-end (the unblocker for the local-model items).
