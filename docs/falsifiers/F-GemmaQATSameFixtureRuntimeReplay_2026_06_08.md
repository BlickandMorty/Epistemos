# F-GemmaQATSameFixtureRuntimeReplay - 2026-06-08

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 architecture witness.

Artifact: `artifacts/falsifiers/gemma_qat_same_fixture_runtime_replay/result.json`

Command: `Tools/falsifiers/f_gemma_qat_same_fixture_runtime_replay.sh`

Scope: metadata-only. No owner path was approved, canonicalized, opened, hashed, or read. No local model, runtime, provider, KV cache, cache state, raw prompt, raw token, tool JSON, quality benchmark, or user-facing Gemma route was loaded, captured, compared, or promoted. No command was armed or executed.

## What This Proves

`F-GemmaQATSameFixtureRuntimeReplay` consumes `F-GemmaQATRedactedFirstTokenProbe` and requires the Gemma E2B/E4B GGUF/LiteRT lanes to share one replay fixture and one proof surface before any future runtime lane comparison can count.

The witness accepts four cards:

- Gemma 4 E2B QAT GGUF / llama.cpp same-fixture replay.
- Gemma 4 E2B QAT LiteRT-LM same-fixture replay.
- Gemma 4 E4B QAT GGUF / llama.cpp same-fixture replay.
- Gemma 4 E4B QAT LiteRT-LM same-fixture replay.

It binds:

- one fixture id and fixture digest across all cards;
- source/search/body freshness;
- redacted prompt, tokenizer, chat-template, and tool-schema boundaries;
- memory sample and one-token replay bounds;
- cancellation, rollback, RunEventLog, AnswerPacket, and abstention refs;
- no cache reuse before lineage proof;
- hidden-chain denial;
- deterministic UAS address;
- next cursor `gemma_qat_held_out_quality_replay_packet`.

## Red Fixtures

The artifact rejects 45 red fixtures, including:

- 12B insertion into the E2B/E4B warmup replay pack;
- duplicate model/lane pairs;
- bad runtime lane;
- fixture digest or canonical digest drift;
- missing source/search/body freshness;
- missing prompt, tokenizer, chat-template, tool-schema, memory, one-token, cancellation, rollback, RunEventLog, AnswerPacket, or abstention proof;
- raw prompt or raw token permission;
- hidden chain allowance;
- cache reuse before lineage;
- runtime replay or quality comparison enablement;
- model/runtime/provider/command/benchmark/local-file/cache byte leaks;
- route mutation, hidden route authority, hidden cloud fallback;
- MAS/L2/L3/product/live-70B/SSD-as-RAM/quality/benchmark-fit claims;
- bad proof refs, metadata overflow, bad upstream ref, and wrong next cursor.

## Layer Truth

L1 architecture/canon: advanced for the Gemma side-ladder only. Same-fixture replay is addressable, witnessed, and schema-bound.

L1 guard-owned product cursor: unchanged. The global architecture guard still owns `small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.

L2 capability route: unchanged and red. This does not admit Gemma through RuntimeRouter/System G as a usable app route.

L3 user-facing / north star: unchanged and red. This does not wire Gemma into settings, onboarding, note chat, or user-visible runtime behavior.

Correct phrasing: "Gemma E2B/E4B same-fixture replay is L1 metadata-proofed; no Gemma model, prompt, token, cache, benchmark, runtime, quality result, or product route has been opened, captured, loaded, compared, or promoted."

## Why It Matters

Same-fixture replay prevents fake model progress. If E2B/E4B, GGUF/LiteRT, or later MLX lanes are compared on different body snapshots, prompt digests, tokenizer/chat templates, tool schemas, cache states, memory samples, or cancellation/logging surfaces, the result cannot safely steer RuntimeRouter/System G. This witness forces future runtime evidence to be comparable before it can become capability evidence.

## Next

Next Gemma side-ladder unit: `F-GemmaQATHeldOutQualityReplayPacket`.

The next unit must still avoid product promotion. It should bind held-out task families, scorer/version digests, final-output digest policy, refusal/tool/cache failure taxonomy, rollback, RunEventLog, AnswerPacket, abstention, and no-hidden-authority proof before any Gemma quality claim can matter.
