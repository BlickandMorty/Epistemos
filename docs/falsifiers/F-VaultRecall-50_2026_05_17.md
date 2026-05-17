# F-VaultRecall-50 Current Run - 2026-05-17

Iteration: T4 iter 18, after Rust path-title recall lane, original-note distractor suppression, synthesis-side title seeding, MMR rerank trace, recency decay, user-priority boost, graph-proximity signal, RRF reason labels, note-chat provenance cards, indexed fallback confidence threshold, prompt evidence threshold, fused confidence trace counts, explicit `Vault provenance:` block handling, and rank-only fused evidence rejection.

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
| UI shows why notes were selected | Swift fallback + RRF provenance + explicit block parser tests passing | visible for loaded notes | PASS |
| Synthesis cites >=2 distinct notes | 10/10 (100.0%) | 100% | PASS |
| Adversarial rejects distractor in top-5 | 10/10 (100.0%) | 85% | PASS |

Retrieval pass bars are now green on the F-VaultRecall-50 baseline, and the user-facing provenance surface is covered by focused Swift tests:

- `EpistemosTests/F_VaultRecall_50_RRFFusionTests.swift` verifies fused RRF results carry renderable match reasons, fused completion payloads expose confidence counts, low-confidence fused results fail the contract, and source-rank-only fused results are not contract-sufficient.
- `EpistemosTests/F_VaultRecall_50_FallbackTests.swift` verifies indexed fallback answers emit per-hit `Why:` reasons, source-rank-only matches are rejected, note chat sidebar provenance parsing accepts explicit `Vault provenance:` blocks, and prompt contracts reject low-confidence/source-rank-only synthesis claims.

Machine-readable tracing and rerank quality are now present in the Rust VaultStore path: candidate-pool trace fields, MMR decisions, recency decay, user priority, graph proximity, confidence bands, and validation violations. Swift fused search completion metadata now reports aggregate contract-sufficient, high-confidence, medium-confidence, and low-confidence hit counts so callers can refuse weak or rank-only evidence before prompt construction. Remaining deeper work is Shadow-first retrieval: dense note sketches/Model2Vec, residual exact escalation, and Cognitive DAG resonance once the owning substrates expose stable inputs.
