---
state: backlog-falsifier-bundle
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source: docs/fusion/CACHE_LINEAGE_AUTORESEARCH_PARADIGM_2026_06_01.md
status: candidate tests; not implemented unless a later PR wires artifacts
---

# F-Cache-Lineage Autoresearch Bundle - 2026-06-01

This bundle converts the cache-lineage autoresearch doctrine into promotion
gates. It does not claim persistent KV, prompt caching, trace learning, or
autoresearch is live. It defines what must be proven before those mechanisms
can govern product behavior.

## Shared artifact contract

Every falsifier in this bundle emits a JSON artifact with:

```text
falsifier_id
source_doc
scenario_id
model_id_or_fixture_id
uas_addresses
privacy_class
input_digest
baseline_route
candidate_route
active_bytes
cold_bytes
kv_bytes
storage_bytes
latency_ms
cold_io_bytes
quality_or_correctness_score
compatibility_result
redaction_result
rollback_ref
answer_packet_visibility
pass
failure_reason
```

Promotion requires deterministic replay on fixtures, explicit failure reasons,
and no user-sensitive trace capture in the first implementation.

## Falsifier Matrix

| Falsifier | Pass condition | Rejects |
|---|---|---|
| `F-KVPrefixUnit-Lineage` | A fixture prefix/KV unit binds UAS address, model, tokenizer, adapter set, RoPE/window, prompt digest, token range, codec, privacy class, purge policy, byte accounting, hit/miss counters, and verifier caveat. | Any cache unit without lineage, byte count, privacy class, or purge policy. |
| `F-KVCompatibilityFence` | Compatible fixture restores pass; mismatched model, tokenizer, adapter, RoPE/window, system prompt, privacy context, codec, or stale source each fail with a named reason. | Blind cache restore, stale prefix reuse, cross-model reuse, and privacy boundary crossing. |
| `F-PrefixReuseRouter` | Compatible prefix reuse beats no-cache prefill and naive reuse on held-out fixture prompts by reporting lower latency/active bytes without correctness loss. | Cache routing that improves speed only by accepting wrong or stale answers. |
| `F-CacheAdmissionCard` | Persist/compress/evict/purge decisions include expected reuse, saved prefill/I/O, privacy class, storage wear, byte cost, purge deadline, and rollback. | Infinite cache growth, missing purge policy, and silent persistence of sensitive state. |
| `F-PersistentKV-ParkResume` | A fixture session parks a compatible KV/prefix unit, resumes through the compatibility fence, and reports visibility without exposing hidden chain-of-thought. | Treating preserved state as user-visible proof or restoring state outside policy. |
| `F-ExecutionTraceCapsule` | Synthetic browser/app/runtime traces capture ordered events, artifacts, redactions, integrity digests, and replayable failure signatures. | Unstructured logs, missing redaction, screenshot-only traces, and unreplayable failures. |
| `F-ParetoResidencyTournament` | Candidate prompt/cache/layout/route policies are evaluated against baseline on quality, latency, active bytes, cold I/O, privacy risk, and storage wear; winners form a Pareto front with rejected candidates preserved. | Single-metric optimization, no held-out tasks, and winner-only evidence. |
| `F-CacheMutationPatch-Rollback` | Every proposed prompt/cache/layout/route policy patch binds baseline, patch, ablation, observed delta, rollback, and promotion status. | Production mutation without rollback or ablation. |
| `F-TraceToPlanLearner` | Slow/failing trace fixtures produce bounded candidate `ColdAssemblyPlan` or cache-policy patches and mark the required falsifier before any promotion. | Autoresearch loop directly mutating live policy. |
| `F-CacheLineage-NoPoison` | Prompt-injection, privacy-boundary, stale-source, incompatible-cache, and corrupted-artifact fixtures cannot promote into reusable state. | Cache poisoning, privacy leaks, stale evidence reuse, and unverifiable trace promotion. |

## Required fixture families

1. **Compatible prefix.** Same model/tokenizer/adapter/window/system prompt and
   stable source digest.
2. **Model mismatch.** Same text prefix but changed model ID.
3. **Tokenizer mismatch.** Same text prefix but different tokenization.
4. **Adapter mismatch.** Same base model but changed adapter set.
5. **Window/RoPE mismatch.** Same token list but incompatible context policy.
6. **Privacy mismatch.** A private trace tries to feed a lower-trust route.
7. **Prompt-injection trace.** Browser text asks the system to preserve or
   reveal forbidden state.
8. **Stale source.** A source card digest changes after cache creation.
9. **Corrupted artifact.** Trace or KV digest does not match stored bytes.
10. **Slow route.** A synthetic route repeats a cold miss that should become a
    candidate cache/layout patch.

## Build order

1. Define schemas only, with synthetic fixtures.
2. Add artifact writer and deterministic replay command.
3. Wire `F-KVPrefixUnit-Lineage` and `F-KVCompatibilityFence`.
4. Add `F-ExecutionTraceCapsule` redaction and integrity fixtures.
5. Add `F-PrefixReuseRouter` and `F-CacheAdmissionCard` dry runs.
6. Add tournament and mutation-patch falsifiers.
7. Only after all synthetic gates pass, consider live opt-in trace capture.

## Product locks

- Persistent KV, prefix reuse, and trace learning are Pro Research until the
  relevant falsifiers pass.
- User-sensitive browser/app traces require redaction and purge policy before
  storage.
- Cache-derived output must be visible in RunEventLog and AnswerPacket when it
  materially changes an answer.
- The bundle does not authorize base-weight mutation.
- The bundle does not authorize SSD-as-RAM claims.
- The bundle does not authorize source-code import from public repos without
  license/setup/vendor review.

## Companion gates

- Semantic working-set compiler bundle:
  `docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md`
- Constructive residency bundle:
  `docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`
- Residency PatternBoost bundle:
  `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`
- Meta-control surfaces:
  `docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md`
- Neural importance atlas:
  `docs/fusion/NEURAL_IMPORTANCE_ROUTING_ATLAS_2026_05_31.md`
