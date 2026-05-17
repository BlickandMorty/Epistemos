# F-VaultRecall-50 Current Run - 2026-05-17

Iteration: T4 iter 8, after Rust path-title recall lane, original-note distractor suppression, synthesis-side title seeding, RRF reason labels, and note-chat provenance cards.

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
| UI shows why notes were selected | Swift fallback + RRF provenance tests passing | visible for loaded notes | PASS |
| Synthesis cites >=2 distinct notes | 10/10 (100.0%) | 100% | PASS |
| Adversarial rejects distractor in top-5 | 10/10 (100.0%) | 85% | PASS |

Retrieval pass bars are now green on the F-VaultRecall-50 baseline, and the user-facing provenance surface is covered by focused Swift tests:

- `EpistemosTests/F_VaultRecall_50_RRFFusionTests.swift` verifies fused RRF results carry renderable match reasons.
- `EpistemosTests/F_VaultRecall_50_FallbackTests.swift` verifies indexed fallback answers emit per-hit `Why:` reasons and the note chat sidebar parser extracts those reasons for provenance cards.

Remaining contract work is deeper machine-readable tracing and rerank quality: candidate-pool trace fields, MMR decisions, graph proximity, confidence bands, and low-confidence enforcement.
