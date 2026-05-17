# F-VaultRecall-50 Current Run - 2026-05-17

Iteration: T4 iter 33, after Rust path-title recall lane, original-note distractor suppression, synthesis-side title seeding, MMR rerank trace, recency decay, user-priority boost, graph-proximity signal, RRF reason labels, note-chat provenance cards, indexed fallback confidence threshold, indexed fallback explicit provenance blocks, indexed fallback single-top margin rejection, prompt evidence threshold, fused confidence trace counts, Rust confidence count snapshots, Rust selected-context confidence count snapshots, metrics snapshot confidence counters, Swift RRF top-score margin tracing, explicit `Vault provenance:` block handling, Swift and Rust rank-only evidence rejection, Rust synthesis distinct-note validation, Rust selected-count consistency, Rust selected low-score rejection, Rust adversarial margin validation, insufficient-evidence fallback messaging, Shadow-first exact-escalation violation mapping, Shadow-first trace envelopes, Shadow-first top-score margin tracing, Shadow-first exact-escalation request payloads, Shadow-first snippet hints, Shadow-first bounded target lists, and low-margin prompt guards.

Command:

```bash
cargo test --manifest-path agent_core/Cargo.toml --test vault_recall_baseline -- --ignored --nocapture
```

Dataset manifest hash: `6272a00acfcb321f6bb5aa195603bb7498bce00a89870063f5b27f0b0ca077c8`

| Condition | Current | Pass bar | Status |
| --- | ---: | ---: | --- |
| Top-1 exact-title recall | 10/10 (100.0%) | 95% | PASS |
| Top-5 paraphrase recall | 9/10 (90.0%) | 90% | PASS |
| Agent context recall proxy | 48/50 (96.0%) | 90% | PASS |
| Zero first-7 enumeration failures | 0 observed | 0 | PASS |
| UI shows why notes were selected | Swift fallback per-hit reasons + explicit answer blocks + RRF provenance + explicit block parser tests passing | visible for loaded notes | PASS |
| Synthesis cites >=2 distinct notes | 10/10 (100.0%) | 100% | PASS |
| Adversarial rejects distractor in top-5 | 10/10 (100.0%) | 85% | PASS |

Retrieval pass bars are now green on the F-VaultRecall-50 baseline, and the user-facing provenance surface is covered by focused Swift tests:

- `EpistemosTests/F_VaultRecall_50_RRFFusionTests.swift` verifies fused RRF results carry renderable match reasons, fused completion payloads and metrics snapshots expose confidence counts, low-confidence fused results fail the contract, and source-rank-only fused results are not contract-sufficient.
- `EpistemosTests/F_VaultRecall_50_FallbackTests.swift` verifies indexed fallback answers emit per-hit `Why:` reasons plus a compact `Vault provenance:` block, source-rank-only matches are rejected with explicit insufficient-evidence messaging, single-result fallback rejects low top-score margin instead of silently promoting one note, note chat sidebar provenance parsing accepts explicit provenance blocks, and prompt contracts reject low-confidence/source-rank-only/low-margin synthesis claims.

Machine-readable tracing and rerank quality are now present in the Rust VaultStore path: candidate-pool trace fields, selected-count consistency, MMR decisions, recency decay, user priority, graph proximity, confidence bands/counts, and validation violations. Rust `VaultCandidateTrace` validation rejects selected candidates whose only visible reason is rank position, `VaultContextTrace::validate` rejects traces whose selected candidates have low fused scores, `VaultContextTrace::selected_confidence_counts` separates selected-context confidence from full-pool confidence, `VaultContextTrace::validate_synthesis_min_distinct_notes` reports `SynthesisUnderCited` when synthesis context has fewer than the required distinct selected notes, and `VaultContextTrace::validate_adversarial_margin` reports `AdversarialConfusion` when the top fused score is too close to its runner-up. Swift fused search completion metadata, Rust `VaultConfidenceCounts`, and SearchFusionMetrics snapshots now report aggregate contract-sufficient, high-confidence, medium-confidence, and low-confidence hit counts so callers can refuse weak or rank-only evidence before prompt construction; Swift fused-search completion payloads, metadata, and metrics snapshots also expose `top_score_margin` so adversarial ambiguity is observable without re-sorting results. Chat and local-agent prompt contracts now name low top-score margin as ambiguous vault retrieval evidence that must broaden, ask, or return insufficient evidence rather than silently choosing the top hit. `agent_core/src/retrieval/` now also carries the Shadow-first answerability contract: RRF/lexical Shadow hits with visible evidence and sufficient margin can proceed, `ShadowFirstTrace::top_score_margin` reports the same ordered top-two gap used by the answerability decision, `ShadowFirstTrace::exact_escalation_request` emits the trimmed query plus bounded ranked candidate hints, including non-blank snippets, for residual lexical/body verification, and dense-only, empty-query, ambiguous, low-score, or evidence-hidden traces require exact escalation and map to `ShadowExactEscalationRequired` in the shared violation vocabulary. Remaining deeper work is wiring that Shadow-first contract into live callers and adding Cognitive DAG resonance once the owning substrates expose stable inputs.
