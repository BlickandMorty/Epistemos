# Canonical Tier Alignment + Metal ULP Witness - 2026-05-27

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Status: canonical check passed with one patchable drift found and fixed.

Branch: `codex/canonical-metal-artifact-gates-2026-05-27`

## Read Order Used

1. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
2. `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
3. `docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md`
4. `docs/fusion/ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md`
5. `docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md`
6. `docs/falsifiers/F-ULP-Oracle_2026_05_17.md`
7. `docs/falsifiers/F-PageGather-M2Pro_2026_05_17.md`
8. `docs/falsifiers/F-ControllerKernelPack_2026_05_17.md`

## Canonical Verdict

The recent Wave 4 / post-Wave 4 work is aligned with the full architecture
when read through the current MAS/Pro status split:

- MAS / CurrentApp: product-visible paths stay on local, typed, replayable
  surfaces. The open PR list remains preservation-only (`#81`, `#82`), not
  raw product work.
- Pro Vault-Preserved / VerifiedFloor: Eidos, VaultRecall, typed UAS retrieval, AcsAnchor
  addressing, PageGather trace visibility, and AnswerPacket provenance are
  wired as witnessed substrate motions.
- Pro Research / CapabilityCeiling: PageGather and ControllerKernelPack hardware
  throughput gates remain orange/pending until their primary Metal artifacts
  exist. They are not silently promoted by compile or smoke tests.
- Addressable neural substrate target: current work is still at the output
  schema / UAS / plane / residency rows of the ladder. The SSM-router,
  active-assembly, adapter, rank-one, and cross-layer-circuit rows remain
  research targets unless summoned by their codewords.

## Drift Caught

The docs had stale post-merge wording:

- The Living Index still referenced the older `334ce238b2` provenance-detail
  checkpoint and 4,042 cargo-test count.
- The post-Wave-4 roll-up still described `F-ULP-Oracle` as CPU-primary with
  Metal full-run pending.
- The Metal preflight audit correctly kept PageGather and ControllerKernelPack
  orange, but had not yet recorded the full `F-ULP-Oracle` promotion.

This slice fixes that drift without changing product runtime behavior.

## New Witness

`Tools/metal-witness-gates/fulp-metal-oracle-artifact.swift` emits the full
Metal `F-ULP-Oracle` artifact.

Current artifact:

- Path: `artifacts/falsifiers/ulp_oracle/result.json`
- Falsifier: `F-ULP-Oracle`
- Kernel: `Epistemos/Shaders/morph_eval_reduced.metal::morphOracleFp16`
- Points: 414,048 input pairs
- Evaluations: 1,242,144 half outputs (`exp`, `ln`, `eml`)
- Budget: max ULP <= 2, wall clock <= 90s on M2 Pro 16 GB
- Result: primary witness

This is a verified-floor hardware witness. It does not green-light
PageGather or ControllerKernelPack; those remain separate throughput/latency
gates.

## No-Orphan Check

- Motion: Project / Verify. The Morph source kernel is projected into a
  hardware witness artifact.
- UAS: no new UAS address is created; the artifact witnesses the verification
  plane for the existing `F-ULP-Oracle` falsifier.
- Plane: Verification plane.
- Residency: Apple Silicon UMA via shared Metal buffers in the harness.
- WBO/error: max ULP is explicit and bounded; failure emits a failure artifact
  path instead of overwriting the passing witness.
- Witness: `result.json`, tool script, falsifier doc, roll-up, and Living Index.
- Falsifier: `F-ULP-Oracle`.
- Tier: VerifiedFloor hardware evidence.
- Rollback: revert the artifact/doc/tool commit to return to the previous CPU
  witness state.

## Remaining Architecture Work

Do not start another broad product-floor wave. The next real codeword slices
are:

1. `RESUME METAL WITNESS GATES`
   - PageGather STREAM-on-Metal baseline plus scatter/gather ratios.
   - ControllerKernelPack p50/p99 latency and 100-cycle sequence wall.
2. `RESEARCH CONSTRUCTION`
   - Candidate-only research construction engine; no live product behavior.
3. `FORK V3`
   - Only after a post-v2.0 tag.
