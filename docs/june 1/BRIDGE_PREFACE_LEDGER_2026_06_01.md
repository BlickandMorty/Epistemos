---
state: duplicate-bridge-ledger
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
scope: repeated inline bridge preface inserted across live-scope legacy docs
status: snapshot
---

# Bridge Preface Ledger - June 1

The final PatternBoost drift sweep inserted the same bridge preface into 345
live-scope markdown/html files that still contained legacy substrate or
model-residency terminology. Copying all 345 historical files into this folder
would mostly duplicate old body text, so this ledger preserves the shared
inline bridge exactly and points to the copied audit that records the sweep.

Exact bridge text:

```markdown
> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.
```

Count check command:

```bash
rg -l '^> \*\*2026-06-01 current canon bridge \(JUNE1-PATTERNBOOST-LOCK\):' docs artifacts/lattice-coordinate-explainer/index.html | wc -l
```

Expected result: `345`.

Canonical copied receipt:

- `audits/RESIDENCY_PATTERNBOOST_DRIFT_SWEEP_2026_06_01.md`

The broader full-thread lock still remains:

- `JUNE1-CANON-FUSION-LOCK`

Use that broader lock when the goal is to recover the whole June 1 research
arc, not only the repeated PatternBoost bridge.
