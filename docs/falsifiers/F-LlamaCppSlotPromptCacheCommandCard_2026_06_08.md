# F-LlamaCppSlotPromptCacheCommandCard - 2026-06-08

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Status

PASS as a metadata-only T1/L1 primary witness.

- Command: `Tools/falsifiers/f_llama_cpp_slot_prompt_cache_command_card.sh`
- Artifact:
  `artifacts/falsifiers/llama_cpp_slot_prompt_cache_command_card/result.json`
- Rust primitive:
  `agent_core/src/uas/llama_cpp_slot_prompt_cache_command_card.rs`
- Falsifier binary:
  `agent_core/src/bin/falsify_llama_cpp_slot_prompt_cache_command_card.rs`
- Parent witness:
  `F-KVCacheIdentitySaltAndOffloadProofPacket`
- Deterministic address:
  `llama_cpp_slot_prompt_cache_command_card:3f3182846bc930483a6534cd708beef0482b625f66cf2a2f8d1dc5f1dd710a2b@1779158400000`

## What This Proves

This witness turns the official llama.cpp server slot prompt-cache endpoint
shape into an Epistemos command card before any runtime lane can cite prompt
cache reuse.

It binds:

- parent KV cache identity packet;
- official llama.cpp server source URL;
- save, restore, and erase actions;
- endpoint template `/slots/{id_slot}?action=<save|restore|erase>`;
- `--slot-save-path` cache-root policy;
- basename-only `.bin` filename policy;
- slot id bounds;
- expected response fields `id_slot`, `filename`, `n_saved`, `n_written`,
  `n_restored`, `n_read`, `n_erased`, `save_ms`, and `restore_ms`;
- session, prompt, tokenizer, chat-template, tool-schema, model artifact,
  adapter/modality, and cache-salt digests;
- owner approval pending;
- unarmed command envelope;
- denied server start;
- rollback, RunEventLog, AnswerPacket, abstention, and deletion policy.

## What This Does Not Prove

This is not a product runtime proof.

- No llama.cpp server was started.
- No command was armed or executed.
- No prompt-cache file was opened.
- No model, KV, runtime, provider, source-tree, product, or benchmark bytes were
  opened.
- No cache reuse was measured.
- No local model fit, output quality, first-token, speed, or WRV claim exists.
- No MAS, L2, L3, T4, live dense 70B, or SSD-as-RAM claim exists.

Correct phrasing: "L1 command-card architecture proof advanced; product
capability / user surface did not."

## Red Fixtures

The witness rejects 33 red fixtures, including:

- missing parent/source/action/endpoint evidence;
- invalid slot id bounds;
- path escape, absolute filename, shell metacharacter filename, hidden
  filename, and cache-root escape;
- missing prompt/tokenizer/tool-schema/cache-salt digests;
- missing response field, rollback, or AnswerPacket;
- owner approval not pending;
- command armed or server start allowed;
- prompt-cache bytes opened, model bytes loaded, or command armed count;
- raw prompt log, stdout/stderr capture, hidden route authority;
- cache-file presence as quality proof;
- restored cache as model-fit proof;
- MAS, L2, L3, live dense 70B, and SSD-as-RAM promotion.

## Promotion Truth

- T0 research/canon: superseded for this card by landed T1 witness.
- T1/L1 architecture proof: advanced as metadata-only command-card evidence.
- T2/L2 capability route: unchanged and red.
- T3/L3 WRV/user-facing runtime: unchanged and red.
- T4/T5 green: no.

## Next

The next KV/cache side-ladder unit is
`kivi_asymmetric_kv_stability_source_card`. The guard-owned product bottleneck
remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
