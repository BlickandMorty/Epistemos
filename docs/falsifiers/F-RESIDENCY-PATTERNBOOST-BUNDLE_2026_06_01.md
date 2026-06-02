---
state: candidate-falsifier-bundle
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source_doctrine: docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md
status: backlog gates; no runtime/product promotion until implemented and passing
---

# F-Residency-PatternBoost Bundle - 2026-06-01

This bundle turns `L20-Candidate: Pattern-Boosted Residency Law` into tests,
dry-run artifacts, and promotion gates. It protects the ambition that Epistemos
can learn reusable cold-residency assemblies while preventing hidden routing
authority, SSD-as-RAM claims, or offline oracle leakage.

## Bundle gates

| Falsifier | Purpose | Promotion gate |
|---|---|---|
| `F-AssemblyCandidatePool-Diversity` | Proves candidate generation creates diverse resident assembly genomes under a fixed seed and mission family. | Beats random/duplicate-heavy generation on unique valid candidates and source coverage. |
| `F-UASAssemblyGenome-Determinism` | Proves a genome serializes selected weights, KV, adapters, evidence, verifiers, depth policy, page runs, fallback, and rollback deterministically. | Round-trip digest is stable across runs and rejects missing UAS/runtime identities. |
| `F-ConstraintRepairKernel-Validity` | Proves invalid genomes are repaired or rejected before route admission. | Over-budget, incompatible KV, stale source, missing rollback, license-blocked, and unsupported transport fixtures fail closed. |
| `F-SparseAssemblyFingerprint-Collision` | Proves compact fingerprints cluster useful motifs without hiding too many distinct invalid assemblies. | Collision rate stays under declared budget on fixture pools and all collisions retain full digest backpointers. |
| `F-AssemblyTournamentTrace-Replay` | Proves generation, repair, scoring, selection, ablation, and distillation are replayable. | Replaying a tournament reproduces winner ids, scores, rejections, and patch metadata. |
| `F-EliteAssemblyArchive-HeldOut` | Proves elite assemblies improve held-out missions, not only the traces that created them. | Winners beat random, recency-only, embedding-only, and static-route baselines on held-out quality, bytes, latency, and verifier outcome. |
| `F-ResidencyPatternDistiller-RouteWin` | Proves distilled route/layout features improve a small scout or working-set plan. | Shadow scout improves held-out route choice while remaining cheaper than the controlled route. |
| `F-LatticeAbstentionGate-Soundness` | Proves lattice-state controller actions are monotone or explicitly abstain when conflict/uncertainty appears. | Wake/retrieve/continue/pause/resume/verify choices either improve declared state or produce visible abstention/escalation. |
| `F-ComputeResumeLease-Compatibility` | Proves pause/resume compute cannot corrupt KV, depth, verifier, or source state. | Resume requires compatible KV pages, weight pages, verifier state, transport manifest, expiry, and rollback. |
| `F-ColdRoutePolicyPatch-Rollback` | Proves tournament-derived policy patches are scoped, reversible, and kill-switchable. | Patch carries baseline, expected delta, held-out result, rollout scope, kill switch, and rollback artifact. |
| `F-AssemblyMotifLibrary-LicenseScope` | Proves source-mined motifs from Axplorer, UlamAI, Letta, LMCache, or other repos remain source-carded and license-scoped. | No repo code or vendor assumption enters product path without import gate, license note, setup proof, and rollback. |
| `F-PatternBoostedResidency-Ablation` | Proves the pattern-boost loop caused the improvement. | Removing repair, elite archive, fingerprinting, or distillation reduces held-out performance versus the full loop. |
| `F-70B-AssemblyPattern-Lite` | Proves the doctrine helps a 70B-cocktail-lite fixture without claiming full dense 70B residency. | Selected assembly beats raw local model, RAG-only, memory-optimized baseline, and static route under declared byte and latency budgets. |
| `F-NoOfflineOracleLeak` | Proves full-wake or proof-oracle labels do not become undeclared live dependencies. | Live route uses only distilled, inspectable features; oracle traces are marked training-only with provenance and split boundaries. |
| `F-ResidencyPatternBoost-NoHiddenAuthority` | Proves Residency PatternBoost cannot wake bytes, mutate live policy, bypass SCOPE-Rex/SovereignGate, or override RuntimeRouter alone. | Admission requires explicit route card, falsifier reference, RunEventLog span, AnswerPacket caveat, and rollback. |

## Required artifacts

Every promoted implementation slice must emit:

- `AssemblyCandidatePool` fixture with seed, mission family, candidates, and
  diversity metrics.
- `UASAssemblyGenome` fixture with deterministic digest and full backpointers.
- `ConstraintRepairKernel` report with accepted, repaired, and rejected units.
- `SparseAssemblyFingerprint` fixture with collision budget and full digest refs.
- `AssemblyTournamentTrace` with baseline, scores, winner ids, ablations,
  held-out result, and rollback.
- `ColdRoutePolicyPatch` only when the patch is shadowed, scoped, reversible,
  and tied to a kill switch.
- `AnswerPacket` or dry-run equivalent showing selected units, rejected units,
  byte budget, verifier/test/citation outcome, uncertainty, fallback, and
  rollback.

## Anti-overclaim locks

- Passing this bundle does not prove live 70B dense inference on 16 GB.
- Passing this bundle does not prove SSD behaves like RAM.
- Passing this bundle does not allow hidden base-weight mutation.
- Passing this bundle does not let X bookmarks, repo code, or blog claims become
  product authority.
- Passing this bundle only promotes the measured assembly pattern and policy
  scope named in the artifact.
