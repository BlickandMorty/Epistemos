---
name: june-deterministic-vault-safety
description: Use when adding, auditing, or hardening MAS June vault grounding, vault.search confidence floors, deterministic retrieval gates, vault.write mutations, reversible effect routing, or any June agent vault action that must be honest, reversible, bounded, and source/test guarded without loading local models.
---

# June Deterministic Vault Safety

## Purpose

Use this skill to promote existing deterministic substrate primitives into June's vault-native agent path. The reusable pattern is: retrieve deterministically, gate confidence honestly, mutate through reversible effects, and expose only non-secret evidence.

Do not use this skill to fake local tool capability, silently escalate weak vault matches to model guesses, bypass approval, return prior note bodies to the agent/UI, invoke subprocesses, or treat focused source tests as running MAS proof.

## Required Reads

1. `docs/research/DETERMINISTIC_SUBSTRATE_INFUSION.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `agent_core/src/tools/registry.rs`
4. `agent_core/src/tools/vault_search_ladder.rs`
5. `agent_core/src/storage/vault.rs`
6. `agent_core/src/eml_rerank.rs`
7. `agent_core/src/effect/mod.rs`
8. `agent_core/src/effect/vault_applier.rs`
9. `EpistemosTests/AppStoreJuneHardeningTests.swift`

## Method

1. Preserve retrieval truth.
   - Keep `vault.search` routed through the VariantLadder.
   - Compare confidence floors against bounded confidence, not raw BM25 magnitude.
   - Keep the honest no-confident-answer response when all tiers decline.
   - Display raw BM25 only as provenance, never as a calibrated confidence.

2. Compose deterministic gates instead of duplicating them.
   - Use schema-gated tool input before handlers mutate state.
   - Keep EML rerank default-on only with explicit rollback hatches.
   - Reuse existing RRF/EML/VariantLadder helpers before adding new ranking logic.

3. Route vault mutations through effects.
   - Convert `vault.write` work into `Intent::VaultWrite`.
   - Apply through `VaultIntentApplier` or the dispatcher, then compute the inverse.
   - Preserve existing approval, contradiction preflight, tag/append assembly, and readback verification.
   - Return only non-secret effect metadata: effect kind, reversible flag, inverse kind, path, hashes, and byte counts.
   - Never serialize `PriorState::WroteOverExisting.body_before` into a tool result, JS payload, or log.

4. Keep MAS boundaries intact.
   - No subprocess verifier, shell, stdio MCP, hidden local server, or local model load is needed for these slices.
   - Security-scoped vault access remains owned by the existing app vault path handoff.
   - Local lanes stay chat-tier unless a separate admitted deterministic runtime proves otherwise.

5. Verify sparsely but concretely on 16 GB machines.
   - First run focused Rust filters such as `vault_search_ladder`, `vault_write`, or the exact new test name with `CARGO_BUILD_JOBS=1 CARGO_INCREMENTAL=0`.
   - Run parser-only Swift source guards before any native App Store build.
   - Defer broad `swift test`, full `cargo test`, and `xcodebuild` to deliberate checkpoints.
   - Always record what is source-proven versus what still needs a running MAS vault task.

## Review Checklist

- `vault.search` cannot turn a merely non-empty result into high-confidence grounding.
- EML/schema gates stay default-on with explicit rollback values.
- `vault.write` uses `Intent::VaultWrite` plus `VaultIntentApplier` or `IntentDispatcher`.
- Existing append/tag/readback behavior remains intact.
- The tool result includes no prior note content, raw vault root, secret, or absolute private path.
- New behavior has a focused Rust test and an App Store source guard.
- Audit rows include file:line evidence and runtime-proof caveats.
