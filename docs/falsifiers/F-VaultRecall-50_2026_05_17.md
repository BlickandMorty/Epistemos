# F-VaultRecall-50 Current Run - 2026-05-17

Iteration: T4 iter 6, after Rust path-title recall lane, original-note distractor suppression, and synthesis-side title seeding.

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
| UI shows why notes were selected | 0/50 | 50/50 | FAIL |
| Synthesis cites >=2 distinct notes | 10/10 (100.0%) | 100% | PASS |
| Adversarial rejects distractor in top-5 | 10/10 (100.0%) | 85% | PASS |

Remaining failure is provenance visibility. The next contract slices need to emit reason traces and surface them in UI provenance cards.
