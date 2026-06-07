---
falsifier: F-SameFixtureRuntimeReplayEnvelope
artifact: artifacts/falsifiers/same_fixture_runtime_replay_envelope/result.json
script: Tools/falsifiers/f_same_fixture_runtime_replay_envelope.sh
status: PASS
scope: metadata-only L1/T1 architecture witness
---

# F-SameFixtureRuntimeReplayEnvelope

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS
ships the safe floor, Pro contains the gated/research/vault/omega ladder, and
no claim promotes without visible proof.

## Result

`F-SameFixtureRuntimeReplayEnvelope` passes as a metadata-only same-fixture
runtime replay envelope. It turns the June 7 large-model research into a
minimal UAS primitive and falsifier for comparing runtime lanes without
loading model bytes, opening owner paths, starting endpoints, running commands,
or promoting product capability.

The witness accepts five lane cards:

- `gguf_llama_cpp`: Gemma 4 E2B QAT GGUF through `ggml-org/llama.cpp`, marked
  only as a future owner-approved probe candidate.
- `litert_lm_swift`: LiteRT-LM Swift, blocked until admission/package proof.
- `mlx_swift_candidate`: MLX Swift, blocked until the Gemma 4 loader caveat is
  resolved by local proof.
- `mlx_lm_python_research`: MLX-LM Python, kept as quarantine research and not
  a Swift/product lane.
- `no_runtime_abstention`: first-class abstention when no runtime lane can
  claim proof.

All lane cards bind the same fixture id, fixture digest, canonical digest,
source/search freshness, tokenizer/chat-template/tool-parser policy,
runtime-lane boundary, model-artifact boundary, cache/byte boundary,
rollback, RunEventLog, AnswerPacket, command-envelope, owner-approval, and
loader-caveat refs.

## Hardening

The artifact rejects invalid fixtures for missing abstention, fewer than two
lanes, fixture digest drift, missing body-read proof, missing search freshness,
missing tokenizer or chat-template digest, missing tool-parser policy, raw
prompt retention, raw tool JSON retention, missing cache salt, hidden cache
reuse, Python MLX being laundered as Swift runtime proof, LiteRT early-preview
being treated as live, server sidecar or local endpoint defaults,
missing command envelope, missing owner approval, missing declared bytes,
nonzero runtime/model/provider bytes, L2/L3/T4 promotion, MAS copy,
live dense 70B claims, and SSD-as-RAM claims.

## Non-Promotion

This witness does not choose a runtime winner, run `llama.cpp`, import
LiteRT-LM or MLX, open a model path, load tokenizer/KV/cache bytes, fetch a
repository, verify local artifact availability, prove Gemma 4 quality, prove
Apple Silicon fit, advance L2, advance L3, or make a user-facing large-model
capability green.

Correct phrasing:

> Architecture side-ladder advanced; product capability / user surface did not.

## Promotion Truth

- L1/T1: advanced. The same-fixture runtime replay envelope now exists as a
  metadata-only primitive and artifact.
- L2: unchanged. The capability kernel remains red on the product runtime
  harness.
- L3: unchanged. No runtime lane is wired, reachable, visible, and verified in
  product surfaces from this witness.
- T4/T5: not green.

## Next

The next same-fixture unit is
`same_fixture_runtime_replay_envelope_invalid_fixture_matrix`. The guard-owned
product cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
